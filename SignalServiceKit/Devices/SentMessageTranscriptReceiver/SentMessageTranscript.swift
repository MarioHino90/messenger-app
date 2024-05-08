//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import LibSignalClient

public enum SentMessageTranscriptTarget {
    case group(TSGroupThread)
    case contact(TSContactThread, DisappearingMessageToken)

    var thread: TSThread {
        switch self {
        case .group(let thread):
            return thread
        case .contact(let thread, _):
            return thread
        }
    }

    var threadUniqueId: String { thread.uniqueId }
}

public enum SentMessageTranscriptType {

    public struct Message {
        public let target: SentMessageTranscriptTarget

        public let body: String?
        public let bodyRanges: MessageBodyRanges?

        // TODO: generalize to cover attachments from backups
        public let attachmentPointerProtos: [SSKProtoAttachmentPointer]

        public let quotedMessageBuilder: OwnedAttachmentBuilder<QuotedMessageInfo>?

        public let contactBuilder: OwnedAttachmentBuilder<OWSContact>?

        public let linkPreviewBuilder: OwnedAttachmentBuilder<OWSLinkPreview>?

        public let giftBadge: OWSGiftBadge?

        public let messageStickerBuilder: OwnedAttachmentBuilder<MessageSticker>?

        public let isViewOnceMessage: Bool

        public let expirationStartedAt: UInt64?
        public let expirationDurationSeconds: UInt32?

        public let storyTimestamp: UInt64?
        public let storyAuthorAci: Aci?
    }

    public struct PaymentNotification {
        public let target: SentMessageTranscriptTarget
        public let serverTimestamp: UInt64
        public let notification: TSPaymentNotification
    }

    case message(Message)
    case recipientUpdate(TSGroupThread)
    case expirationTimerUpdate(SentMessageTranscriptTarget)
    case endSessionUpdate(TSContactThread)
    case paymentNotification(PaymentNotification)
}

/// A transcript for a message that has already been sent, and which came in either
/// as a sync message from a linked device, or from a backup.
public protocol SentMessageTranscript {

    var type: SentMessageTranscriptType { get }

    var timestamp: UInt64 { get }

    var requiredProtocolVersion: UInt32? { get }

    var recipientStates: [SignalServiceAddress: TSOutgoingMessageRecipientState] { get }
}

extension SentMessageTranscript {

    public var threadForDataMessage: TSThread? {
        switch type {
        case .endSessionUpdate, .expirationTimerUpdate:
            return nil
        case .message(let messageParams):
            return messageParams.target.thread
        case .paymentNotification(let notification):
            return notification.target.thread
        case .recipientUpdate(let thread):
            return thread
        }
    }
}
