//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import LibSignalClient

extension MessageBackup {

    public struct RecipientId: Hashable {
        let value: UInt64

        public init(value: UInt64) {
            self.value = value
        }

        fileprivate init(recipient: BackupProto.Recipient) {
            self.init(value: recipient.id)
        }

        fileprivate init(chat: BackupProto.Chat) {
            self.init(value: chat.recipientId)
        }

        fileprivate init(chatItem: BackupProto.ChatItem) {
            self.init(value: chatItem.authorId)
        }

        fileprivate init(reaction: BackupProto.Reaction) {
            self.init(value: reaction.authorId)
        }

        fileprivate init(quote: BackupProto.Quote) {
            self.init(value: quote.authorId)
        }

        fileprivate init(sendStatus: BackupProto.SendStatus) {
            self.init(value: sendStatus.recipientId)
        }
    }

    public typealias GroupId = Data

    /**
     * As we go archiving recipients, we use this object to track mappings from the addressing we use in the app
     * to the ID addressing system of the backup protos.
     *
     * For example, we will assign a ``BackupRecipientId`` to each ``SignalRecipient`` as we
     * insert them. Later, when we create the ``BackupProto.Chat`` corresponding to the ``TSContactThread``
     * for that recipient, we will need to add the corresponding ``BackupRecipientId``, which we look up
     * using the contact's Aci/Pni/e164, from the map this context keeps.
     */
    public class RecipientArchivingContext {
        public enum Address {

            case contact(ContactAddress)
            case group(GroupId)
        }

        public let localRecipientId: RecipientId

        internal let localIdentifiers: LocalIdentifiers

        private var currentRecipientId: RecipientId
        private let groupIdMap = SharedMap<GroupId, RecipientId>()
        private let contactAciMap = SharedMap<Aci, RecipientId>()
        private let contactPniMap = SharedMap<Pni, RecipientId>()
        private let contactE164ap = SharedMap<E164, RecipientId>()

        internal init(
            localIdentifiers: LocalIdentifiers,
            localRecipientId: RecipientId
        ) {
            self.localIdentifiers = localIdentifiers
            self.localRecipientId = localRecipientId

            // Start after the local recipient id.
            currentRecipientId = RecipientId(value: localRecipientId.value + 1)

            // Also insert the local identifiers, just in case we try and look
            // up the local recipient by .contact enum case.
            contactAciMap[localIdentifiers.aci] = localRecipientId
            if let pni = localIdentifiers.pni {
                contactPniMap[pni] = localRecipientId
            }
            if let e164 = E164(localIdentifiers.phoneNumber) {
                contactE164ap[e164] = currentRecipientId
            }
        }

        internal func assignRecipientId(to address: Address) -> RecipientId {
            defer {
                currentRecipientId = RecipientId(value: currentRecipientId.value + 1)
            }
            switch address {
            case .group(let groupId):
                groupIdMap[groupId] = currentRecipientId
            case .contact(let contactAddress):
                // Create mappings for every identifier we know about
                if let aci = contactAddress.aci {
                    contactAciMap[aci] = currentRecipientId
                }
                if let pni = contactAddress.pni {
                    contactPniMap[pni] = currentRecipientId
                }
                if let e164 = contactAddress.e164 {
                    contactE164ap[e164] = currentRecipientId
                }
            }
            return currentRecipientId
        }

        internal subscript(_ address: Address) -> RecipientId? {
            // swiftlint:disable:next implicit_getter
            get {
                switch address {
                case .group(let groupId):
                    return groupIdMap[groupId]
                case .contact(let contactAddress):
                    // Go down identifiers in priority order, return the first we have.
                    if let aci = contactAddress.aci {
                        return contactAciMap[aci]
                    } else if let e164 = contactAddress.e164 {
                        return contactE164ap[e164]
                    } else if let pni = contactAddress.pni {
                        return contactPniMap[pni]
                    } else {
                        return nil
                    }
                }
            }
        }
    }

    public class RecipientRestoringContext {
        public enum Address {
            case localAddress
            case contact(ContactAddress)
            case group(GroupId)
        }

        internal let localIdentifiers: LocalIdentifiers

        private let map = SharedMap<RecipientId, Address>()

        internal init(localIdentifiers: LocalIdentifiers) {
            self.localIdentifiers = localIdentifiers
        }

        internal subscript(_ id: RecipientId) -> Address? {
            get { map[id] }
            set(newValue) { map[id] = newValue }
        }
    }
}

extension MessageBackup.RecipientId: MessageBackupLoggableId {
    public var typeLogString: String { "BackupProto.Recipient" }

    public var idLogString: String { "\(self.value)" }
}

extension MessageBackup.RecipientArchivingContext.Address: MessageBackupLoggableId {
    public var typeLogString: String {
        switch self {
        case .contact(let address):
            return address.typeLogString
        case .group:
            return "TSGroupThread"
        }
    }

    public var idLogString: String {
        switch self {
        case .contact(let contactAddress):
            return contactAddress.idLogString
        case .group(let groupId):
            // Rely on the scrubber to scrub the id.
            return groupId.base64EncodedString()
        }
    }
}

extension BackupProto.Recipient {

    public var recipientId: MessageBackup.RecipientId {
        return MessageBackup.RecipientId(recipient: self)
    }
}

extension BackupProto.Chat {

    public var typedRecipientId: MessageBackup.RecipientId {
        return MessageBackup.RecipientId(chat: self)
    }
}

extension BackupProto.ChatItem {

    public var authorRecipientId: MessageBackup.RecipientId {
        return MessageBackup.RecipientId(chatItem: self)
    }
}

extension BackupProto.Reaction {

    public var authorRecipientId: MessageBackup.RecipientId {
        return MessageBackup.RecipientId(reaction: self)
    }
}

extension BackupProto.Quote {

    public var authorRecipientId: MessageBackup.RecipientId {
        return MessageBackup.RecipientId(quote: self)
    }
}

extension BackupProto.SendStatus {
    public var destinationRecipientId: MessageBackup.RecipientId {
        return MessageBackup.RecipientId(sendStatus: self)
    }
}
