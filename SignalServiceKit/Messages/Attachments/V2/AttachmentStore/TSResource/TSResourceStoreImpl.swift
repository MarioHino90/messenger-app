//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

public class TSResourceStoreImpl: TSResourceStore {

    private let attachmentStore: AttachmentStoreImpl
    private let tsAttachmentStore: TSAttachmentStore

    public init(attachmentStore: AttachmentStoreImpl) {
        self.attachmentStore = attachmentStore
        self.tsAttachmentStore = TSAttachmentStore()
    }

    public func fetch(_ ids: [TSResourceId], tx: DBReadTransaction) -> [TSResource] {
        var legacyIds = [String]()
        var v2Ids = [Attachment.IDType]()
        ids.forEach {
            switch $0 {
            case .legacy(let uniqueId):
                legacyIds.append(uniqueId)
            case .v2(let rowId):
                v2Ids.append(rowId)
            }
        }
        var resources: [TSResource] = tsAttachmentStore.attachments(
            withAttachmentIds: legacyIds,
            tx: SDSDB.shimOnlyBridge(tx)
        )
        if v2Ids.isEmpty.negated {
            resources.append(contentsOf: attachmentStore.fetch(ids: v2Ids, tx: tx))
        }
        return resources
    }

    // MARK: - Message Attachment fetching

    public func allAttachments(for message: TSMessage, tx: DBReadTransaction) -> [TSResourceReference] {
        let v2References: [TSResourceReference]

        if FeatureFlags.readV2Attachments {
            guard let messageRowId = message.sqliteRowId else {
                owsFailDebug("Fetching attachments for an un-inserted message!")
                return []
            }
            v2References = attachmentStore
                .fetchReferences(
                    owners: AttachmentReference.OwnerTypeRaw.allMessageCases.map {
                        $0.with(ownerId: messageRowId)
                    },
                    tx: tx
                )
        } else {
            v2References = []
        }

        let legacyReferences: [TSResourceReference] = tsAttachmentStore.allAttachments(
            for: message,
            tx: SDSDB.shimOnlyBridge(tx)
        )

        if !v2References.isEmpty && !legacyReferences.isEmpty {
            // This isn't broken per se, things _should_ work, but it is unexpected.
            owsFailDebug("Have both legacy and v2 references on the same attachment!")
        }

        return v2References + legacyReferences
    }

    public func bodyAttachments(for message: TSMessage, tx: DBReadTransaction) -> [TSResourceReference] {
        if FeatureFlags.newAttachmentsUseV2, message.attachmentIds.isEmpty {
            guard let messageRowId = message.sqliteRowId else {
                owsFailDebug("Fetching attachments for an un-inserted message!")
                return []
            }
            // For legacy reasons, an oversized text attachment is considered a "body" attachment.
            return attachmentStore.fetchReferences(
                owners: [
                    .messageBodyAttachment(messageRowId: messageRowId),
                    .messageOversizeText(messageRowId: messageRowId)
                ],
                tx: tx
            )
        } else {
            let attachments = tsAttachmentStore.attachments(withAttachmentIds: message.attachmentIds, tx: SDSDB.shimOnlyBridge(tx))
            let attachmentMap = Dictionary(uniqueKeysWithValues: attachments.map { ($0.uniqueId, $0) })
            return message.attachmentIds.map { uniqueId in
                TSAttachmentReference(uniqueId: uniqueId, attachment: attachmentMap[uniqueId])
            }
        }
    }

    public func bodyMediaAttachments(for message: TSMessage, tx: DBReadTransaction) -> [TSResourceReference] {
        if FeatureFlags.newAttachmentsUseV2, message.attachmentIds.isEmpty {
            guard let messageRowId = message.sqliteRowId else {
                owsFailDebug("Fetching attachments for an un-inserted message!")
                return []
            }
            return attachmentStore.fetchReferences(owner: .messageBodyAttachment(messageRowId: messageRowId), tx: tx)
        } else {
            let attachments = tsAttachmentStore.attachments(
                withAttachmentIds: message.attachmentIds,
                ignoringContentType: MimeType.textXSignalPlain.rawValue,
                tx: SDSDB.shimOnlyBridge(tx)
            )
            // If we fail to fetch any attachments, we don't know if theyre media or
            // oversize text, so we can't return them even as a reference.
            return attachments.map {
                TSAttachmentReference(uniqueId: $0.uniqueId, attachment: $0)
            }
        }
    }

    public func oversizeTextAttachment(for message: TSMessage, tx: DBReadTransaction) -> TSResourceReference? {
        if FeatureFlags.newAttachmentsUseV2, message.attachmentIds.isEmpty {
            guard let messageRowId = message.sqliteRowId else {
                owsFailDebug("Fetching attachments for an un-inserted message!")
                return nil
            }
            return attachmentStore.fetchFirstReference(owner: .messageOversizeText(messageRowId: messageRowId), tx: tx)
        } else {
            guard
                let attachment = tsAttachmentStore.attachments(
                    withAttachmentIds: message.attachmentIds,
                    matchingContentType: MimeType.textXSignalPlain.rawValue,
                    tx: SDSDB.shimOnlyBridge(tx)
                ).first
            else {
                /// We can't tell from the unique id if its an oversized text attachment, so if the attachment
                /// lookup fails for any reason, we return nil.
                return nil
            }
            return TSAttachmentReference(uniqueId: attachment.uniqueId, attachment: attachment)
        }
    }

    public func contactShareAvatarAttachment(for message: TSMessage, tx: DBReadTransaction) -> TSResourceReference? {
        if
            FeatureFlags.readV2Attachments,
            let contactShare = message.contactShare,
            contactShare.legacyAvatarAttachmentId == nil
        {
            guard let messageRowId = message.sqliteRowId else {
                owsFailDebug("Fetching attachments for an un-inserted message!")
                return nil
            }
            return attachmentStore.fetchFirstReference(owner: .messageContactAvatar(messageRowId: messageRowId), tx: tx)
        }
        return legacyReference(uniqueId: message.contactShare?.legacyAvatarAttachmentId, tx: tx)
    }

    public func linkPreviewAttachment(for message: TSMessage, tx: DBReadTransaction) -> TSResourceReference? {
        guard let linkPreview = message.linkPreview else {
            return nil
        }
        if FeatureFlags.readV2Attachments, linkPreview.usesV2AttachmentReference {
            guard let messageRowId = message.sqliteRowId else {
                owsFailDebug("Fetching attachments for an un-inserted message!")
                return nil
            }
            return attachmentStore.fetchFirstReference(owner: .messageLinkPreview(messageRowId: messageRowId), tx: tx)
        } else {
            return legacyReference(uniqueId: linkPreview.legacyImageAttachmentId, tx: tx)
        }
    }

    public func stickerAttachment(for message: TSMessage, tx: DBReadTransaction) -> TSResourceReference? {
        guard let messageSticker = message.messageSticker else {
            return nil
        }
        if let legacyAttachmentId = messageSticker.legacyAttachmentId {
            return legacyReference(uniqueId: legacyAttachmentId, tx: tx)
        } else if FeatureFlags.readV2Attachments {
            guard let messageRowId = message.sqliteRowId else {
                owsFailDebug("Fetching attachments for an un-inserted message!")
                return nil
            }
            return attachmentStore.fetchFirstReference(owner: .messageSticker(messageRowId: messageRowId), tx: tx)
        } else {
            return nil
        }
    }

    // MARK: - Quoted Messages

    public func quotedAttachmentReference(
        from info: OWSAttachmentInfo,
        parentMessage: TSMessage,
        tx: DBReadTransaction
    ) -> TSQuotedMessageResourceReference? {
        switch info.attachmentType {
        case .V2:
            return attachmentStore.quotedAttachmentReference(
                from: info,
                parentMessage: parentMessage,
                tx: tx
            )?.tsReference
        case .unset, .original, .originalForSend, .thumbnail, .untrustedPointer:
            fallthrough
        @unknown default:
            if let reference = self.legacyReference(uniqueId: info.attachmentId, tx: tx) {
                return .thumbnail(reference)
            } else if let stub = TSQuotedMessageResourceReference.Stub(info) {
                return .stub(stub)
            } else {
                return nil
            }
        }
    }

    public func attachmentToUseInQuote(
        originalMessage: TSMessage,
        tx: DBReadTransaction
    ) -> TSResourceReference? {
        if
            FeatureFlags.readV2Attachments,
            let attachment = attachmentStore.attachmentToUseInQuote(originalMessage: originalMessage, tx: tx)
        {
            return attachment
        } else {
            guard
                let attachment = tsAttachmentStore.attachmentToUseInQuote(
                    originalMessage: originalMessage,
                    tx: SDSDB.shimOnlyBridge(tx)
                )
            else {
                return nil
            }
            return TSAttachmentReference(uniqueId: attachment.uniqueId, attachment: attachment)
        }
    }

    // MARK: - Story Message Attachment Fetching

    public func mediaAttachment(
        for storyMessage: StoryMessage,
        tx: DBReadTransaction
    ) -> TSResourceReference? {
        switch storyMessage.attachment {
        case .text:
            return nil
        case .file(let storyMessageFileAttachment):
            return tsAttachmentStore.storyAttachmentReference(storyMessageFileAttachment, tx: SDSDB.shimOnlyBridge(tx))
        case .foreignReferenceAttachment:
            guard FeatureFlags.readV2Attachments else {
                return nil
            }
            guard let storyMessageRowId = storyMessage.id else {
                owsFailDebug("Fetching attachments for an un-inserted story message!")
                return nil
            }
            return attachmentStore.fetchFirstReference(
                owner: .storyMessageMedia(storyMessageRowId: storyMessageRowId),
                tx: tx
            )
        }
    }

    public func linkPreviewAttachment(
        for storyMessage: StoryMessage,
        tx: DBReadTransaction
    ) -> TSResourceReference? {
        switch storyMessage.attachment {
        case .file, .foreignReferenceAttachment:
            return nil
        case .text(let textAttachment):
            guard let linkPreview = textAttachment.preview else {
                return nil
            }
            if FeatureFlags.readV2Attachments, linkPreview.usesV2AttachmentReference {
                guard let storyMessageRowId = storyMessage.id else {
                    owsFailDebug("Fetching attachments for an un-inserted story message!")
                    return nil
                }
                return attachmentStore.fetchFirstReference(
                    owner: .storyMessageLinkPreview(storyMessageRowId: storyMessageRowId),
                    tx: tx
                )
            } else {
                return legacyReference(uniqueId: linkPreview.legacyImageAttachmentId, tx: tx)
            }
        }
    }
}

// MARK: - TSResourceUploadStore

extension TSResourceStoreImpl: TSResourceUploadStore {

    public func updateAsUploaded(
        attachmentStream: TSResourceStream,
        encryptionKey: Data,
        encryptedByteLength: UInt32,
        digest: Data,
        cdnKey: String,
        cdnNumber: UInt32,
        uploadTimestamp: UInt64,
        tx: DBWriteTransaction
    ) {
        switch attachmentStream.concreteStreamType {
        case .legacy(let tSAttachment):
            tSAttachment.updateAsUploaded(
                withEncryptionKey: encryptionKey,
                digest: digest,
                serverId: 0, // Only used in cdn0 uploads, which aren't supported here.
                cdnKey: cdnKey,
                cdnNumber: cdnNumber,
                uploadTimestamp: uploadTimestamp,
                transaction: SDSDB.shimOnlyBridge(tx)
            )
        case .v2(let attachment):
            attachmentStore.markUploadedToTransitTier(
                attachmentStream: attachment,
                encryptionKey: encryptionKey,
                encryptedByteLength: encryptedByteLength,
                digest: digest,
                cdnKey: cdnKey,
                cdnNumber: cdnNumber,
                uploadTimestamp: uploadTimestamp,
                tx: tx
            )
        }
    }
}

// MARK: - Helpers
extension TSResourceStoreImpl {

    private func legacyReference(uniqueId: String?, tx: DBReadTransaction) -> TSResourceReference? {
        guard let uniqueId else {
            return nil
        }
        let attachment = tsAttachmentStore.attachments(withAttachmentIds: [uniqueId], tx: SDSDB.shimOnlyBridge(tx)).first
        return TSAttachmentReference(uniqueId: uniqueId, attachment: attachment)
    }
}
