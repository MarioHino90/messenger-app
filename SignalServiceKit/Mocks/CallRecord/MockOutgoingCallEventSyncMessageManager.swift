//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import SignalCoreKit

#if TESTABLE_BUILD

class MockOutgoingCallEventSyncMessageManager: OutgoingCallEventSyncMessageManager {
    var expectedCallEvent: CallEvent?
    var syncMessageSendCount: UInt = 0

    func sendSyncMessage(
        conversationId: ConversationId,
        callRecord: CallRecord,
        callEvent: CallEvent,
        callEventTimestamp: UInt64,
        tx: DBWriteTransaction
    ) {
        owsAssert(expectedCallEvent == callEvent)
        syncMessageSendCount += 1
    }

    func sendSyncMessage(
        contactThread: TSContactThread,
        callRecord: CallRecord,
        callEvent: CallEvent,
        tx: DBWriteTransaction
    ) {
        owsAssert(expectedCallEvent == callEvent)
        syncMessageSendCount += 1
    }
}

#endif
