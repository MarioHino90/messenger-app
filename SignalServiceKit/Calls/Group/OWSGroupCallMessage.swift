//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

extension OWSGroupCallMessage {
    /// Explicitly delete any ``CallRecord`` associated with this interaction.
    ///
    /// These records would be deleted automatically due to their foreign key
    /// reference to this interaction, but that auto-deletion would skip the
    /// rest of the "delete a call record" machinery.
    ///
    /// We want to send a sync message since we want the Calls Tab to be
    /// identical across linked devices, and this may delete a ``CallRecord``.
    /// Callers who care not to send a sync message should ensure any call
    /// records associated with this interaction are deleted before we get here.
    ///
    /// - SeeAlso ``TSCall/anyWillRemove(with:)``.
    override open func anyWillRemove(with tx: SDSAnyWriteTransaction) {
        DependenciesBridge.shared.callRecordDeleteManager.deleteCallRecord(
            associatedGroupCallInteraction: self,
            sendSyncMessageOnDelete: true,
            tx: tx.asV2Write
        )
    }
}

// MARK: - OWSReadTracking

@objc
extension OWSGroupCallMessage: OWSReadTracking {
    public var expireStartedAt: UInt64 {
        return 0
    }

    public func markAsRead(
        atTimestamp readTimestamp: UInt64,
        thread: TSThread,
        circumstance: OWSReceiptCircumstance,
        shouldClearNotifications: Bool,
        transaction tx: SDSAnyWriteTransaction
    ) {
        if wasRead {
            return
        }

        anyUpdateGroupCallMessage(transaction: tx) { groupCallMessage in
            groupCallMessage.wasRead = true
        }

        switch circumstance {
        case .onThisDevice, .onThisDeviceWhilePendingMessageRequest:
            let callRecordStore = DependenciesBridge.shared.callRecordStore
            let missedCallManager = DependenciesBridge.shared.callRecordMissedCallManager

            if
                let sqliteRowId = sqliteRowId,
                let associatedCallRecord = callRecordStore.fetch(
                    interactionRowId: sqliteRowId, tx: tx.asV2Read
                )
            {
                missedCallManager.markUnreadCallsInConversationAsRead(
                    beforeCallRecord: associatedCallRecord,
                    sendSyncMessage: true,
                    tx: tx.asV2Write
                )
            }
        case .onLinkedDevice, .onLinkedDeviceWhilePendingMessageRequest:
            break
        @unknown default:
            break
        }
    }
}
