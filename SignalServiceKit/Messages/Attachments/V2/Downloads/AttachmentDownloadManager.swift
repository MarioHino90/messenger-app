//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

public enum AttachmentDownloads {

    public static let attachmentDownloadProgressNotification = Notification.Name("AttachmentDownloadProgressNotification")

    /// Key for a CGFloat progress value from 0 to 1
    public static var attachmentDownloadProgressKey: String { "attachmentDownloadProgressKey" }

    /// Key for a ``Attachment.IdType`` value.
    public static var attachmentDownloadAttachmentIDKey: String { "attachmentDownloadAttachmentIDKey" }

    public struct DownloadMetadata: Equatable {
        public let cdnNumber: UInt32
        public let cdnKey: String
        public let encryptionKey: Data
        public let digest: Data
        public let plaintextLength: UInt32

        public init(
            cdnNumber: UInt32,
            cdnKey: String,
            encryptionKey: Data,
            digest: Data,
            plaintextLength: UInt32
        ) {
            self.cdnNumber = cdnNumber
            self.cdnKey = cdnKey
            self.encryptionKey = encryptionKey
            self.digest = digest
            self.plaintextLength = plaintextLength
        }
    }
}

public protocol AttachmentDownloadManager {

    func downloadBackup(
        metadata: MessageBackupRemoteInfo,
        authHeaders: [String: String]
    ) -> Promise<URL>

    func downloadTransientAttachment(
        metadata: AttachmentDownloads.DownloadMetadata
    ) -> Promise<URL>

    @discardableResult
    func enqueueDownloadOfAttachmentsForMessage(
        _ message: TSMessage,
        priority: AttachmentDownloadPriority,
        tx: DBWriteTransaction
    ) -> Promise<Void>

    @discardableResult
    func enqueueDownloadOfAttachmentsForStoryMessage(
        _ message: StoryMessage,
        priority: AttachmentDownloadPriority,
        tx: DBWriteTransaction
    ) -> Promise<Void>

    func cancelDownload(for attachmentId: Attachment.IDType, tx: DBWriteTransaction)

    func downloadProgress(for attachmentId: Attachment.IDType, tx: DBReadTransaction) -> CGFloat?
}

extension AttachmentDownloadManager {

    @discardableResult
    public func enqueueDownloadOfAttachmentsForMessage(
        _ message: TSMessage,
        tx: DBWriteTransaction
    ) -> Promise<Void> {
        return enqueueDownloadOfAttachmentsForMessage(message, priority: .default, tx: tx)
    }

    @discardableResult
    public func enqueueDownloadOfAttachmentsForStoryMessage(
        _ message: StoryMessage,
        tx: DBWriteTransaction
    ) -> Promise<Void> {
        return enqueueDownloadOfAttachmentsForStoryMessage(message, priority: .default, tx: tx)
    }
}
