//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import GRDB

public protocol NicknameManager {
    func fetchNickname(for recipient: SignalRecipient, tx: DBReadTransaction) -> NicknameRecord?
    func createOrUpdate(
        nicknameRecord: NicknameRecord,
        updateStorageServiceFor accountId: AccountId?,
        tx: DBWriteTransaction
    )
    func deleteNickname(
        recipientRowID: Int64,
        updateStorageServiceFor accountId: AccountId?,
        tx: DBWriteTransaction
    )
}

public struct NicknameManagerImpl: NicknameManager {
    private let nicknameRecordStore: any NicknameRecordStore
    private let searchableNameIndexer: any SearchableNameIndexer
    private let storageServiceManager: any StorageServiceManager
    private let schedulers: any Schedulers

    public init(
        nicknameRecordStore: any NicknameRecordStore,
        searchableNameIndexer: any SearchableNameIndexer,
        storageServiceManager: any StorageServiceManager,
        schedulers: any Schedulers
    ) {
        self.nicknameRecordStore = nicknameRecordStore
        self.searchableNameIndexer = searchableNameIndexer
        self.storageServiceManager = storageServiceManager
        self.schedulers = schedulers
    }

    private func notifyContactChanges(tx: DBWriteTransaction) {
        tx.addAsyncCompletion(on: self.schedulers.main) {
            NotificationCenter.default.postNotificationNameAsync(.OWSContactsManagerSignalAccountsDidChange, object: nil)
        }
    }

    // MARK: Read

    public func fetchNickname(
        for recipient: SignalRecipient,
        tx: DBReadTransaction
    ) -> NicknameRecord? {
        recipient.id.flatMap { nicknameRecordStore.fetch(recipientRowID: $0, tx: tx) }
    }

    // MARK: Write

    public func createOrUpdate(
        nicknameRecord: NicknameRecord,
        updateStorageServiceFor accountId: AccountId?,
        tx: DBWriteTransaction
    ) {
        if self.nicknameRecordStore.nicknameExists(
            recipientRowID: nicknameRecord.recipientRowID,
            tx: tx
        ) {
            self.update(nicknameRecord, tx: tx)
        } else {
            self.insert(nicknameRecord, tx: tx)
        }

        if let accountId {
            self.storageServiceManager.recordPendingUpdates(updatedAccountIds: [accountId])
        }
    }

    private func insert(_ nicknameRecord: NicknameRecord, tx: DBWriteTransaction) {
        self.nicknameRecordStore.insert(nicknameRecord, tx: tx)
        self.searchableNameIndexer.insert(nicknameRecord, tx: tx)
        self.notifyContactChanges(tx: tx)
    }

    private func update(_ nicknameRecord: NicknameRecord, tx: DBWriteTransaction) {
        self.nicknameRecordStore.update(nicknameRecord, tx: tx)
        self.searchableNameIndexer.update(nicknameRecord, tx: tx)
        self.notifyContactChanges(tx: tx)
    }

    public func deleteNickname(
        recipientRowID: Int64,
        updateStorageServiceFor accountId: AccountId?,
        tx: DBWriteTransaction
    ) {
        guard let nicknameRecord = self.nicknameRecordStore.fetch(
            recipientRowID: recipientRowID,
            tx: tx
        ) else { return }
        self.delete(nicknameRecord, tx: tx)

        if let accountId {
            self.storageServiceManager.recordPendingUpdates(updatedAccountIds: [accountId])
        }
    }

    private func delete(_ nicknameRecord: NicknameRecord, tx: DBWriteTransaction) {
        self.searchableNameIndexer.delete(nicknameRecord, tx: tx)
        self.nicknameRecordStore.delete(nicknameRecord, tx: tx)
        self.notifyContactChanges(tx: tx)
    }
}
