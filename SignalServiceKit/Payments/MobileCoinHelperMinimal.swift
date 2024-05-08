//
// Copyright 2021 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

public enum MobileCoinHelperMinimalError: Error {
    case invalidReceipt
}

public class MobileCoinHelperMinimal: MobileCoinHelper {
    public init() { }

    public func info(forReceiptData receiptData: Data) throws -> MobileCoinReceiptInfo {
        guard let proto = try? External_Receipt(serializedData: receiptData) else {
            Logger.warn("Couldn't decode MobileCoin receipt")
            throw MobileCoinHelperMinimalError.invalidReceipt
        }
        let txOutPublicKey = proto.publicKey.data
        return MobileCoinReceiptInfo(txOutPublicKey: txOutPublicKey)
    }

    public func isValidMobileCoinPublicAddress(_ addressData: Data) -> Bool {
        guard let proto = try? External_PublicAddress(serializedData: addressData) else {
            Logger.warn("Couldn't decode MobileCoin public address")
            return false
        }
        return true
    }
}
