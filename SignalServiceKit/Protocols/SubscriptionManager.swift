//
// Copyright 2021 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

@objc
public protocol SubscriptionManager {
    func reconcileBadgeStates(transaction: SDSAnyWriteTransaction)
    func hasCurrentSubscription(transaction: SDSAnyReadTransaction) -> Bool
    func timeSinceLastSubscriptionExpiration(transaction: SDSAnyReadTransaction) -> TimeInterval

    func userManuallyCancelledSubscription(transaction: SDSAnyReadTransaction) -> Bool
    func setUserManuallyCancelledSubscription(_ userCancelled: Bool, updateStorageService: Bool, transaction: SDSAnyWriteTransaction)
    var displayBadgesOnProfile: Bool { get }
    func displayBadgesOnProfile(transaction: SDSAnyReadTransaction) -> Bool
    func setDisplayBadgesOnProfile(_ displayBadgesOnProfile: Bool, updateStorageService: Bool, transaction: SDSAnyWriteTransaction)

    func getSubscriberCurrencyCode(transaction: SDSAnyReadTransaction) -> String?
    func setSubscriberCurrencyCode(_ currencyCode: Currency.Code?, transaction: SDSAnyWriteTransaction)

    func getSubscriberID(transaction: SDSAnyReadTransaction) -> Data?
    func setSubscriberID(_ subscriberID: Data?, transaction: SDSAnyWriteTransaction)
}
