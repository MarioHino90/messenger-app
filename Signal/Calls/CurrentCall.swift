//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit

struct CurrentCall {
    private let rawValue: AtomicValue<SignalCall?>

    init(rawValue: AtomicValue<SignalCall?>) {
        self.rawValue = rawValue
    }

    func get() -> SignalCall? { rawValue.get() }
}

extension CurrentCall: CurrentCallThreadProvider {
    var currentCallThread: TSThread? { self.get()?.thread }
}
