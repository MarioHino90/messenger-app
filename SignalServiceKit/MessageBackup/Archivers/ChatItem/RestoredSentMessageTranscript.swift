//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import LibSignalClient

/// Restoring an outgoing message from a backup isn't any different from learning about
/// an outgoing message sent on a linked device and synced to the local device.
///
/// So we represent restored messages as "transcripts" that we can plug into the same
/// transcript processing pipes as synced message transcripts.
internal class RestoredSentMessageTranscript: SentMessageTranscript {

    private let messageParams: SentMessageTranscriptType.Message

    var type: SentMessageTranscriptType {
        return .message(messageParams)
    }

    let timestamp: UInt64

    // Not applicable
    var requiredProtocolVersion: UInt32? { nil }

    let recipientStates: [MessageBackup.InteropAddress: TSOutgoingMessageRecipientState]

    internal static func from(
        chatItem: BackupProto.ChatItem,
        contents: MessageBackup.RestoredMessageContents,
        outgoingDetails: BackupProto.ChatItem.OutgoingMessageDetails,
        context: MessageBackup.ChatRestoringContext,
        thread: MessageBackup.ChatThread
    ) -> MessageBackup.RestoreInteractionResult<RestoredSentMessageTranscript> {

        let expirationToken: DisappearingMessageToken = .token(forProtoExpireTimerMillis: chatItem.expiresInMs)

        let target: SentMessageTranscriptTarget
        switch thread {
        case .contact(let contactThread):
            target = .contact(contactThread, expirationToken)
        case .groupV2(let groupThread):
            target = .group(groupThread)
        }

        // TODO: handle attachments in quotes
        let quotedMessageBuilder = contents.quotedMessage.map {
            return OwnedAttachmentBuilder<QuotedMessageInfo>.withoutFinalizer(.init(
                quotedMessage: $0,
                renderingFlag: .default
            ))
        }

        let messageParams = SentMessageTranscriptType.Message(
            target: target,
            body: contents.body?.text,
            bodyRanges: contents.body?.ranges,
            // TODO: attachments
            attachmentPointerProtos: [],
            quotedMessageBuilder: quotedMessageBuilder,
            // TODO: contact message
            contactBuilder: nil,
            // TODO: linkPreview message
            linkPreviewBuilder: nil,
            // TODO: gift badge message
            giftBadge: nil,
            // TODO: sticker message
            messageStickerBuilder: nil,
            // TODO: isViewOnceMessage
            isViewOnceMessage: false,
            expirationStartedAt: chatItem.expireStartDate,
            expirationDurationSeconds: expirationToken.durationSeconds,
            // We never restore stories.
            storyTimestamp: nil,
            storyAuthorAci: nil
        )

        var partialErrors = [MessageBackup.RestoreFrameError<MessageBackup.ChatItemId>]()

        var recipientStates = [MessageBackup.InteropAddress: TSOutgoingMessageRecipientState]()
        for sendStatus in outgoingDetails.sendStatus {
            let recipientAddress: MessageBackup.InteropAddress
            let recipientID = sendStatus.destinationRecipientId
            switch context.recipientContext[recipientID] {
            case .contact(let address):
                recipientAddress = address.asInteropAddress()
            case .none:
                // Missing recipient! Fail this one recipient but keep going.
                partialErrors.append(.restoreFrameError(
                    .invalidProtoData(.recipientIdNotFound(recipientID)),
                    chatItem.id
                ))
                continue
            case .localAddress, .group:
                // Recipients can only be contacts.
                partialErrors.append(.restoreFrameError(
                    .invalidProtoData(.outgoingNonContactMessageRecipient),
                    chatItem.id
                ))
                continue
            }

            guard
                let recipientState = recipientState(
                    for: sendStatus,
                    partialErrors: &partialErrors,
                    chatItemId: chatItem.id
                )
            else {
                continue
            }

            recipientStates[recipientAddress] = recipientState
        }

        if recipientStates.isEmpty && outgoingDetails.sendStatus.isEmpty.negated {
            // We put up with some failures, but if we get no recipients at all
            // fail the whole thing.
            return .messageFailure(partialErrors)
        }

        let transcript = RestoredSentMessageTranscript(
            messageParams: messageParams,
            timestamp: chatItem.dateSent,
            recipientStates: recipientStates
        )
        if partialErrors.isEmpty {
            return .success(transcript)
        } else {
            return .partialRestore(transcript, partialErrors)
        }
    }

    private static func recipientState(
        for sendStatus: BackupProto.SendStatus,
        partialErrors: inout [MessageBackup.RestoreFrameError<MessageBackup.ChatItemId>],
        chatItemId: MessageBackup.ChatItemId
    ) -> TSOutgoingMessageRecipientState? {
        guard let recipientState = TSOutgoingMessageRecipientState() else {
            partialErrors.append(.restoreFrameError(
                .databaseInsertionFailed(OWSAssertionError("Unable to create recipient state!")),
                chatItemId
            ))
            return nil
        }

        recipientState.wasSentByUD = sendStatus.sealedSender.negated

        switch sendStatus.deliveryStatus {
        case nil, .UNKNOWN:
            partialErrors.append(.restoreFrameError(.invalidProtoData(.unrecognizedMessageSendStatus), chatItemId))
            return nil
        case .PENDING:
            recipientState.state = .pending
            recipientState.errorCode = nil
            return recipientState
        case .SENT:
            recipientState.state = .sent
            recipientState.errorCode = nil
            return recipientState
        case .DELIVERED:
            recipientState.state = .sent
            recipientState.deliveryTimestamp = NSNumber(value: sendStatus.lastStatusUpdateTimestamp)
            recipientState.errorCode = nil
            return recipientState
        case .READ:
            recipientState.state = .sent
            recipientState.readTimestamp = NSNumber(value: sendStatus.lastStatusUpdateTimestamp)
            recipientState.errorCode = nil
            return recipientState
        case .VIEWED:
            recipientState.state = .sent
            recipientState.viewedTimestamp = NSNumber(value: sendStatus.lastStatusUpdateTimestamp)
            recipientState.errorCode = nil
            return recipientState
        case .SKIPPED:
            recipientState.state = .skipped
            recipientState.errorCode = nil
            return recipientState
        case .FAILED:
            recipientState.state = .failed
            if sendStatus.identityKeyMismatch {
                // We want to explicitly represent identity key errors.
                // Other types we don't really care about.
                recipientState.errorCode = NSNumber(value: UntrustedIdentityError.errorCode)
            } else {
                recipientState.errorCode = NSNumber(value: OWSErrorCode.genericFailure.rawValue)
            }
            return recipientState
        }
    }

    private init(
        messageParams: SentMessageTranscriptType.Message,
        timestamp: UInt64,
        recipientStates: [MessageBackup.InteropAddress: TSOutgoingMessageRecipientState]
    ) {
        self.messageParams = messageParams
        self.timestamp = timestamp
        self.recipientStates = recipientStates
    }
}
