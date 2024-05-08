//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

public protocol SignalAccountStore {
    func fetchSignalAccount(for rowId: SignalAccount.RowId, tx: DBReadTransaction) -> SignalAccount?
}

public class SignalAccountStoreImpl: SignalAccountStore {
    public init() {}

    public func fetchSignalAccount(for rowId: SignalAccount.RowId, tx: DBReadTransaction) -> SignalAccount? {
        return SDSCodableModelDatabaseInterfaceImpl().fetchModel(modelType: SignalAccount.self, rowId: rowId, tx: tx)
    }
}

#if TESTABLE_BUILD

class MockSignalAccountStore: SignalAccountStore {
    var signalAccounts = [SignalAccount]()

    func fetchSignalAccount(for rowId: SignalAccount.RowId, tx: DBReadTransaction) -> SignalAccount? {
        return signalAccounts.first(where: { $0.id == rowId })
    }
}

#endif
