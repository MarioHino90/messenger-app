//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension AttachmentReference {

    /// What "owns" this attachment, as stored in the sql table column.
    public enum OwnerTypeRaw: Int, Codable {
        case messageBodyAttachment = 0
        case messageOversizeText = 1
        case messageLinkPreview = 2
        case quotedReplyAttachment = 3
        case messageSticker = 4
        case messageContactAvatar = 5
        case storyMessageMedia = 6
        case storyMessageLinkPreview = 7
        case threadWallpaperImage = 8

        static var allMessageCases: [OwnerTypeRaw] {
            [
                .messageBodyAttachment,
                .messageOversizeText,
                .messageLinkPreview,
                .quotedReplyAttachment,
                .messageSticker,
                .messageContactAvatar,
            ]
        }
    }

    /// What "owns" this attachment, as stored in the sql table column.
    public enum OwnerId: Hashable, Equatable {
        case messageBodyAttachment(messageRowId: Int64)
        case messageOversizeText(messageRowId: Int64)
        case messageLinkPreview(messageRowId: Int64)
        /// Note that the row id is for the parent message containing the quoted reply,
        /// not the original message being quoted.
        case quotedReplyAttachment(messageRowId: Int64)
        case messageSticker(messageRowId: Int64)
        case messageContactAvatar(messageRowId: Int64)
        case storyMessageMedia(storyMessageRowId: Int64)
        case storyMessageLinkPreview(storyMessageRowId: Int64)
        case threadWallpaperImage(threadRowId: Int64)
    }

    /// A builder for the "owner" metadata of the attachment, with per-type
    /// metadata required for construction.
    ///
    /// Note: some metadata is generically available on the source (proto or in-memory draft);
    /// this enum contains only type-specific fields.
    public enum OwnerBuilder: Equatable {
        case messageBodyAttachment(MessageBodyAttachmentBuilder)

        case messageOversizeText(messageRowId: Int64)
        case messageLinkPreview(messageRowId: Int64)
        /// Note that the row id is for the parent message containing the quoted reply,
        /// not the original message being quoted.
        case quotedReplyAttachment(MessageQuotedReplyAttachmentBuilder)
        case messageSticker(MessageStickerBuilder)
        case messageContactAvatar(messageRowId: Int64)
        case storyMessageMedia(StoryMediaBuilder)
        case storyMessageLinkPreview(storyMessageRowId: Int64)
        case threadWallpaperImage(threadRowId: Int64)

        public struct MessageBodyAttachmentBuilder: Equatable {
            public let messageRowId: Int64
            public let renderingFlag: AttachmentReference.RenderingFlag

            /// Note: index/orderInOwner is inferred from the order of the provided array at creation time.

            /// Note: at time of writing message captions are unused; not taken as input here.

            public init(
                messageRowId: Int64,
                renderingFlag: AttachmentReference.RenderingFlag
            ) {
                self.messageRowId = messageRowId
                self.renderingFlag = renderingFlag
            }
        }

        public struct MessageQuotedReplyAttachmentBuilder: Equatable {
            public let messageRowId: Int64
            public let renderingFlag: AttachmentReference.RenderingFlag

            public init(
                messageRowId: Int64,
                renderingFlag: AttachmentReference.RenderingFlag
            ) {
                self.messageRowId = messageRowId
                self.renderingFlag = renderingFlag
            }
        }

        public struct MessageStickerBuilder: Equatable {
            public let messageRowId: Int64
            public let stickerPackId: Data
            public let stickerId: UInt32

            public init(
                messageRowId: Int64,
                stickerPackId: Data,
                stickerId: UInt32
            ) {
                self.messageRowId = messageRowId
                self.stickerPackId = stickerPackId
                self.stickerId = stickerId
            }
        }

        public struct StoryMediaBuilder: Equatable {
            public let storyMessageRowId: Int64
            public let caption: StyleOnlyMessageBody?
            public let shouldLoop: Bool

            public init(
                storyMessageRowId: Int64,
                caption: StyleOnlyMessageBody?,
                shouldLoop: Bool
            ) {
                self.storyMessageRowId = storyMessageRowId
                self.caption = caption
                self.shouldLoop = shouldLoop
            }
        }
    }

    /// A more friendly in-memory representation of the "owner" of the attachment
    /// with any associated metadata.
    public enum Owner {
        case message(MessageSource)
        case storyMessage(StoryMessageSource)
        case thread(ThreadMetadata)

        // MARK: - Message

        public enum MessageSource {
            case bodyAttachment(BodyAttachmentMetadata)

            /// Always assumed to have a text content type.
            case oversizeText(Metadata)

            /// Always assumed to have an image content type.
            case linkPreview(Metadata)

            /// Note that the row id is for the parent message containing the quoted reply,
            /// not the original message being quoted.
            case quotedReply(QuotedReplyMetadata)

            case sticker(StickerMetadata)

            /// Always assumed to have an image content type.
            case contactAvatar(Metadata)

            // MARK: - Message Metadata

            public class Metadata: AttachmentReference.Metadata {
                public var messageRowId: Int64 { _ownerRowId }
            }

            public class BodyAttachmentMetadata: Metadata {
                public var contentType: ContentType? { _contentType }
                /// Read-only in practice; we never set this for new message body attachments but
                /// it may be set for older messages.
                public var caption: MessageBody? { _caption }
                public var renderingFlag: RenderingFlag { _renderingFlag }
                public var index: UInt32 { _orderInOwner! }

                override class var requiredFields: [AnyKeyPath] { [\Self._orderInOwner] }
            }

            public class QuotedReplyMetadata: Metadata {
                public var contentType: ContentType? { _contentType }
                public var renderingFlag: RenderingFlag { _renderingFlag }
            }

            public class StickerMetadata: Metadata {
                public var stickerPackId: Data { _stickerPackId! }
                public var stickerId: UInt32 { _stickerId! }

                override class var requiredFields: [AnyKeyPath] { [\Self._stickerPackId, \Self._stickerId] }
            }

            public var messageRowId: Int64 {
                switch self {
                case .bodyAttachment(let metadata):
                    return metadata.messageRowId
                case .oversizeText(let metadata):
                    return metadata.messageRowId
                case .linkPreview(let metadata):
                    return metadata.messageRowId
                case .quotedReply(let metadata):
                    return metadata.messageRowId
                case .sticker(let metadata):
                    return metadata.messageRowId
                case .contactAvatar(let metadata):
                    return metadata.messageRowId
                }
            }
        }

        // MARK: - Story Message

        public enum StoryMessageSource {
            case media(MediaMetadata)
            case textStoryLinkPreview(Metadata)

            // MARK: - Story Message Metadata

            public class Metadata: AttachmentReference.Metadata {
                public var storyMessageRowId: Int64 { _ownerRowId }
            }

            public class MediaMetadata: Metadata {
                public var contentType: ContentType? { _contentType }
                public var caption: StyleOnlyMessageBody? { _caption.map(StyleOnlyMessageBody.init(messageBody:)) }
                public var shouldLoop: Bool { _renderingFlag == .shouldLoop }
            }

            public var storyMsessageRowId: Int64 {
                switch self {
                case .media(let metadata):
                    return metadata.storyMessageRowId
                case .textStoryLinkPreview(let metadata):
                    return metadata.storyMessageRowId
                }
            }
        }

        // MARK: - Thread Metadata

        public class ThreadMetadata: AttachmentReference.Metadata {
            public var threadRowId: Int64 { _ownerRowId }
        }
    }

    // MARK: - Metadata

    /// Every AttachmentReference keeps all the metadata provided when it is initialized (or updated).
    /// However, we only expose (and use) each field on specific cases; these are represented by
    /// subclasses of this class defined in this file.
    public class Metadata {
        /// The sqlite row id of the owner, which could be a message, story message, thread, etc.
        /// Required in all cases.
        fileprivate let _ownerRowId: Int64

        /// Order on the containing message.
        /// Message body attachments only, but required in that case.
        fileprivate let _orderInOwner: UInt32?

        /// Flag from the sender giving us a hint for how it should be rendered.
        /// Used for:
        /// * message body attachments
        /// * quoted reply attachment
        /// * story media, but only the "shouldLoop" case is respected.
        /// Even in those cases the default value is allowed.
        fileprivate let _renderingFlag: RenderingFlag

        /// For message sources, the row id for the thread containing that message.
        /// Required for message sources.
        ///
        /// Confusingly, this is NOT the foreign reference used when the source type is thread
        /// (that's just set in ``sourceRowId``!).
        /// This isn't exposed to consumers of this object; its used for indexing/filtering
        /// when we want to e.g. get all files sent on messages in a thread.
        fileprivate let _threadRowId: UInt64?

        /// Caption on the attachment.
        /// Used for:
        /// * message body attachments
        ///   * legacy only; the ability to set captions on message
        ///     attachments was removed long ago. We maintain them
        ///     for existing messages. New message attachments always
        ///     inherit their "caption" from their parent message.
        /// * story media
        /// But even in those cases its optional.
        fileprivate let _caption: MessageBody?

        /// Sticker pack info, only used (and required) for sticker messages.
        fileprivate let _stickerPackId: Data?
        fileprivate let _stickerId: UInt32?

        /// Validated type of the actual file content on disk, if we have it.
        /// Mirrors `Attachment.contentType`.
        ///
        /// We _write_ and keep this value if available for all attachments,
        /// but only _read_ it for:
        /// * message body attachments
        /// * quoted reply attachment (note some types are disallowed)
        /// * story media (note some types are disallowed)
        /// Null if the attachment is undownloaded.
        /// 
        /// Note: if you want to know if an attachment is, say, a video,
        /// even if you are ok using the mimeType for that if undownloaded,
        /// you must fetch the full attachment object and use its mimeType.
        fileprivate let _contentType: ContentType?

        fileprivate class var requiredFields: [AnyKeyPath] { [] }

        class MissingRequiredFieldError: Error {}

        public required init(
            ownerRowId: Int64,
            orderInOwner: UInt32?,
            renderingFlag: RenderingFlag,
            threadRowId: UInt64?,
            caption: MessageBody?,
            stickerPackId: Data?,
            stickerId: UInt32?,
            contentType: AttachmentReference.ContentType?
        ) throws {
            self._ownerRowId = ownerRowId
            self._orderInOwner = orderInOwner
            self._renderingFlag = renderingFlag
            self._threadRowId = threadRowId
            self._caption = caption
            self._stickerPackId = stickerPackId
            self._stickerId = stickerId
            self._contentType = contentType

            for keyPath in type(of: self).requiredFields {
                guard self[keyPath: keyPath] != nil else {
                    throw MissingRequiredFieldError()
                }
            }
        }
    }
}

// MARK: - Validation

extension AttachmentReference.Owner {

    internal static func validateAndBuild(
        ownerId: AttachmentReference.OwnerId,
        orderInOwner: UInt32?,
        renderingFlag: AttachmentReference.RenderingFlag,
        threadRowId: UInt64?,
        caption: String?,
        captionBodyRanges: MessageBodyRanges,
        stickerPackId: Data?,
        stickerId: UInt32?,
        contentType: AttachmentReference.ContentType?
    ) -> AttachmentReference.Owner? {

        func buildAndValidateMetadata<MetadataType: AttachmentReference.Metadata>() throws -> MetadataType {
            let captionBody = caption.map { MessageBody(text: $0, ranges: captionBodyRanges) }
            return try MetadataType.init(
                ownerRowId: ownerId.rowId,
                orderInOwner: orderInOwner,
                renderingFlag: renderingFlag,
                threadRowId: threadRowId,
                caption: captionBody,
                stickerPackId: stickerPackId,
                stickerId: stickerId,
                contentType: contentType
            )
        }

        do {
            switch ownerId {
            case .messageBodyAttachment:
                return .message(.bodyAttachment(try buildAndValidateMetadata()))
            case .messageOversizeText:
                return .message(.oversizeText(try buildAndValidateMetadata()))
            case .messageLinkPreview:
                return .message(.linkPreview(try buildAndValidateMetadata()))
            case .quotedReplyAttachment:
                return .message(.quotedReply(try buildAndValidateMetadata()))
            case .messageSticker:
                return .message(.sticker(try buildAndValidateMetadata()))
            case .messageContactAvatar:
                return .message(.contactAvatar(try buildAndValidateMetadata()))
            case .storyMessageMedia:
                return .storyMessage(.media(try buildAndValidateMetadata()))
            case .storyMessageLinkPreview:
                return .storyMessage(.textStoryLinkPreview(try buildAndValidateMetadata()))
            case .threadWallpaperImage:
                return .thread(try buildAndValidateMetadata())
            }
        } catch {
            return nil
        }
    }
}

// MARK: - Converters

extension AttachmentReference.Owner {

    public var id: AttachmentReference.OwnerId {
        switch self {
        case .message(.bodyAttachment(let metadata)):
            return .messageBodyAttachment(messageRowId: metadata._ownerRowId)
        case .message(.oversizeText(let metadata)):
            return .messageOversizeText(messageRowId: metadata._ownerRowId)
        case .message(.linkPreview(let metadata)):
            return .messageLinkPreview(messageRowId: metadata._ownerRowId)
        case .message(.quotedReply(let metadata)):
            return .quotedReplyAttachment(messageRowId: metadata._ownerRowId)
        case .message(.sticker(let metadata)):
            return .messageSticker(messageRowId: metadata._ownerRowId)
        case .message(.contactAvatar(let metadata)):
            return .messageContactAvatar(messageRowId: metadata._ownerRowId)
        case .storyMessage(.media(let metadata)):
            return .storyMessageMedia(storyMessageRowId: metadata._ownerRowId)
        case .storyMessage(.textStoryLinkPreview(let metadata)):
            return .storyMessageLinkPreview(storyMessageRowId: metadata._ownerRowId)
        case .thread(let metadata):
            return .threadWallpaperImage(threadRowId: metadata._ownerRowId)
        }
    }
}

extension AttachmentReference.OwnerBuilder {

    internal var id: AttachmentReference.OwnerId {
        switch self {
        case .messageBodyAttachment(let bodyOwnerBuilder):
            return .messageBodyAttachment(messageRowId: bodyOwnerBuilder.messageRowId)
        case .messageOversizeText(let messageRowId):
            return .messageOversizeText(messageRowId: messageRowId)
        case .messageLinkPreview(let messageRowId):
            return .messageLinkPreview(messageRowId: messageRowId)
        case .quotedReplyAttachment(let builder):
            return .quotedReplyAttachment(messageRowId: builder.messageRowId)
        case .messageSticker(let stickerOwnerBuilder):
            return .messageSticker(messageRowId: stickerOwnerBuilder.messageRowId)
        case .messageContactAvatar(let messageRowId):
            return .messageContactAvatar(messageRowId: messageRowId)
        case .storyMessageMedia(let mediaOwnerBuilder):
            return .storyMessageMedia(storyMessageRowId: mediaOwnerBuilder.storyMessageRowId)
        case .storyMessageLinkPreview(let storyMessageRowId):
            return .storyMessageLinkPreview(storyMessageRowId: storyMessageRowId)
        case .threadWallpaperImage(let threadRowId):
            return .threadWallpaperImage(threadRowId: threadRowId)
        }
    }
}

extension AttachmentReference.OwnerId {

    internal var raw: AttachmentReference.OwnerTypeRaw {
        switch self {
        case .messageBodyAttachment:
            return .messageBodyAttachment
        case .messageOversizeText:
            return .messageOversizeText
        case .messageLinkPreview:
            return .messageLinkPreview
        case .quotedReplyAttachment:
            return .quotedReplyAttachment
        case .messageSticker:
            return .messageSticker
        case .messageContactAvatar:
            return .messageContactAvatar
        case .storyMessageMedia:
            return .storyMessageMedia
        case .storyMessageLinkPreview:
            return .storyMessageLinkPreview
        case .threadWallpaperImage:
            return .threadWallpaperImage
        }
    }

    fileprivate var rowId: Int64 {
        switch self {
        case
                .messageBodyAttachment(let rowId),
                .messageOversizeText(let rowId),
                .messageLinkPreview(let rowId),
                .quotedReplyAttachment(let rowId),
                .messageSticker(let rowId),
                .messageContactAvatar(let rowId),
                .storyMessageMedia(let rowId),
                .storyMessageLinkPreview(let rowId),
                .threadWallpaperImage(let rowId):
            return rowId
        }
    }
}

extension AttachmentReference.OwnerTypeRaw {

    internal func with(ownerId: Int64) -> AttachmentReference.OwnerId {
        switch self {
        case .messageBodyAttachment:
            return .messageBodyAttachment(messageRowId: ownerId)
        case .messageOversizeText:
            return .messageOversizeText(messageRowId: ownerId)
        case .messageLinkPreview:
            return .messageLinkPreview(messageRowId: ownerId)
        case .quotedReplyAttachment:
            return .quotedReplyAttachment(messageRowId: ownerId)
        case .messageSticker:
            return .messageSticker(messageRowId: ownerId)
        case .messageContactAvatar:
            return .messageContactAvatar(messageRowId: ownerId)
        case .storyMessageMedia:
            return .storyMessageMedia(storyMessageRowId: ownerId)
        case .storyMessageLinkPreview:
            return .storyMessageLinkPreview(storyMessageRowId: ownerId)
        case .threadWallpaperImage:
            return .threadWallpaperImage(threadRowId: ownerId)
        }
    }
}
