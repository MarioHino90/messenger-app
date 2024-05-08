//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

extension MessageBackup {

    internal enum InteractionArchiverType: Equatable {
        case incomingMessage
        case outgoingMessage
        case groupUpdateInfoMessage
        // TODO: remove once all types are implemented
        case unimplemented
    }
}

extension TSInteraction {

    internal func archiverType(
        localIdentifiers: LocalIdentifiers
    ) -> MessageBackup.InteractionArchiverType {
        if self is TSIncomingMessage {
            return .incomingMessage
        }
        if self is TSOutgoingMessage {
            return .outgoingMessage
        }
        if let infoMessage = self as? TSInfoMessage {
            switch infoMessage.groupUpdateMetadata(localIdentifiers: localIdentifiers) {
            case .nonGroupUpdate:
                // TODO: other info message types
                break
            case .legacyRawString:
                // Declare that we can archive this, so that its not unhandled.
                // We won't actually archive it though; we just drop these.
                return .groupUpdateInfoMessage
            case .precomputed, .modelDiff, .newGroup:
                return .groupUpdateInfoMessage
            }
        }
        return .unimplemented
    }
}

extension BackupProto.ChatItem {

    internal var archiverType: MessageBackup.InteractionArchiverType {
        switch directionalDetails {
        case .incoming:
            return .incomingMessage
        case .outgoing:
            return .outgoingMessage
        case nil, .directionless:
            break
        }

        switch item {
        case .updateMessage(let chatUpdateMessage):
            switch chatUpdateMessage.update {
            case .groupChange:
                return .groupUpdateInfoMessage
            default:
                break
            }
        default:
            break
        }

        return .unimplemented
    }
}
