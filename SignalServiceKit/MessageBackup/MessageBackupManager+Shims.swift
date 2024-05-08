//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import GRDB
import LibSignalClient

public enum MessageBackup {}

extension MessageBackup {
    public enum Shims {
        public typealias BlockingManager = _MessageBackup_BlockingManagerShim
        public typealias ProfileManager = _MessageBackup_ProfileManagerShim
    }

    public enum Wrappers {
        public typealias BlockingManager = _MessageBackup_BlockingManagerWrapper
        public typealias ProfileManager = _MessageBackup_ProfileManagerWrapper
    }
}

// MARK: - BlockingManager

public protocol _MessageBackup_BlockingManagerShim {

    func blockedAddresses(tx: DBReadTransaction) -> Set<SignalServiceAddress>

    func addBlockedAddress(_ address: SignalServiceAddress, tx: DBWriteTransaction)
}

public class _MessageBackup_BlockingManagerWrapper: _MessageBackup_BlockingManagerShim {

    private let blockingManager: BlockingManager

    public init(_ blockingManager: BlockingManager) {
        self.blockingManager = blockingManager
    }

    public func blockedAddresses(tx: DBReadTransaction) -> Set<SignalServiceAddress> {
        return blockingManager.blockedAddresses(transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func addBlockedAddress(_ address: SignalServiceAddress, tx: DBWriteTransaction) {
        blockingManager.addBlockedAddress(address, blockMode: .localShouldNotLeaveGroups, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - ProfileManager

public protocol _MessageBackup_ProfileManagerShim {

    func getUserProfile(for address: SignalServiceAddress, tx: DBReadTransaction) -> OWSUserProfile?

    func getLocalUsersProfile(tx: DBReadTransaction) -> OWSUserProfile?

    func getProfileKeyData(for address: SignalServiceAddress, tx: DBReadTransaction) -> Data?

    func allWhitelistedRegisteredAddresses(tx: DBReadTransaction) -> [SignalServiceAddress]

    func isThread(inProfileWhitelist thread: TSThread, tx: DBReadTransaction) -> Bool

    func addToWhitelist(_ address: SignalServiceAddress, tx: DBWriteTransaction)

    func addToWhitelist(_ thread: TSGroupThread, tx: DBWriteTransaction)

    func setProfileKey(
        _ profileKey: OWSAES256Key,
        forAci aci: Aci,
        localIdentifiers: LocalIdentifiers,
        tx: DBWriteTransaction
    )

    func insertOtherUserProfile(
        givenName: String?,
        familyName: String?,
        profileKey: OWSAES256Key?,
        address: OWSUserProfile.Address,
        tx: DBWriteTransaction
    )
}

public class _MessageBackup_ProfileManagerWrapper: _MessageBackup_ProfileManagerShim {
    private var userProfileWriter: UserProfileWriter {
        // [Backups] TODO: add a dedicated profile writer case
        return .storageService
    }

    private let profileManager: ProfileManager

    public init(_ profileManager: ProfileManager) {
        self.profileManager = profileManager
    }

    public func getUserProfile(for address: SignalServiceAddress, tx: DBReadTransaction) -> OWSUserProfile? {
        profileManager.getUserProfile(for: address, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func getLocalUsersProfile(tx: DBReadTransaction) -> OWSUserProfile? {
        return OWSUserProfile.getUserProfileForLocalUser(tx: SDSDB.shimOnlyBridge(tx))
    }

    public func getProfileKeyData(for address: SignalServiceAddress, tx: DBReadTransaction) -> Data? {
        profileManager.profileKeyData(for: address, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func allWhitelistedRegisteredAddresses(tx: DBReadTransaction) -> [SignalServiceAddress] {
        profileManager.allWhitelistedRegisteredAddresses(tx: SDSDB.shimOnlyBridge(tx))
    }

    public func isThread(inProfileWhitelist thread: TSThread, tx: DBReadTransaction) -> Bool {
        profileManager.isThread(inProfileWhitelist: thread, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func addToWhitelist(_ address: SignalServiceAddress, tx: DBWriteTransaction) {
        profileManager.addUser(
            toProfileWhitelist: address,
            userProfileWriter: userProfileWriter,
            transaction: SDSDB.shimOnlyBridge(tx)
        )
    }

    public func addToWhitelist(_ thread: TSGroupThread, tx: DBWriteTransaction) {
        profileManager.addThread(toProfileWhitelist: thread, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func setProfileKey(
        _ profileKey: OWSAES256Key,
        forAci aci: Aci,
        localIdentifiers: LocalIdentifiers,
        tx: DBWriteTransaction
    ) {
        profileManager.setProfileKeyData(
            profileKey.keyData,
            for: aci,
            onlyFillInIfMissing: false,
            shouldFetchProfile: false,
            userProfileWriter: userProfileWriter,
            localIdentifiers: localIdentifiers,
            authedAccount: .implicit(),
            tx: tx
        )
    }

    public func insertOtherUserProfile(
        givenName: String?,
        familyName: String?,
        profileKey: OWSAES256Key?,
        address: OWSUserProfile.Address,
        tx: DBWriteTransaction
    ) {
        guard case .otherUser = address else {
            owsFail("Must pass .otherUser to this method.")
        }
        OWSUserProfile(
            address: address,
            givenName: givenName,
            familyName: familyName,
            profileKey: profileKey
        ).anyInsert(transaction: SDSDB.shimOnlyBridge(tx))
    }
}

extension MessageBackup {
    public enum AccountData {}
}

extension MessageBackup.AccountData {
    public enum Shims {
        public typealias ReceiptManager = _MessageBackup_AccountData_ReceiptManagerShim
        public typealias TypingIndicators = _MessageBackup_AccountData_TypingIndicatorsShim
        public typealias Preferences = _MessageBackup_AccountData_PreferencesShim
        public typealias SSKPreferences = _MessageBackup_AccountData_SSKPreferencesShim
        public typealias SubscriptionManager = _MessageBackup_AccountData_SubscriptionManagerShim
        public typealias StoryManager = _MessageBackup_AccountData_StoryManagerShim
        public typealias SystemStoryManager = _MessageBackup_AccountData_SystemStoryManagerShim
        public typealias ReactionManager = _MessageBackup_AccountData_ReactionManagerShim
        public typealias UDManager = _MessageBackup_AccountData_UDManagerShim
        public typealias UserProfile = _MessageBackup_AccountData_UserProfileShim
    }

    public enum Wrappers {
        public typealias ReceiptManager = _MessageBackup_AccountData_ReceiptManagerWrapper
        public typealias TypingIndicators = _MessageBackup_AccountData_TypingIndicatorsWrapper
        public typealias Preferences = _MessageBackup_AccountData_PreferencesWrapper
        public typealias SSKPreferences = _MessageBackup_AccountData_SSKPreferencesWrapper
        public typealias SubscriptionManager = _MessageBackup_AccountData_SubscriptionManagerWrapper
        public typealias StoryManager = _MessageBackup_AccountData_StoryManagerWrapper
        public typealias SystemStoryManager = _MessageBackup_AccountData_SystemStoryManagerWrapper
        public typealias ReactionManager = _MessageBackup_AccountData_ReactionManagerWrapper
        public typealias UDManager = _MessageBackup_AccountData_UDManagerWrapper
        public typealias UserProfile = _MessageBackup_AccountData_UserProfileWrapper
    }
}

// MARK: - RecipientManager

public protocol _MessageBackup_AccountData_ReceiptManagerShim {
    func areReadReceiptsEnabled(tx: DBReadTransaction) -> Bool
    func setAreReadReceiptsEnabled(value: Bool, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_ReceiptManagerWrapper: _MessageBackup_AccountData_ReceiptManagerShim {
    let receiptManager: OWSReceiptManager
    init(receiptManager: OWSReceiptManager) {
        self.receiptManager = receiptManager
    }

    public func areReadReceiptsEnabled(tx: DBReadTransaction) -> Bool {
        receiptManager.areReadReceiptsEnabled(transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func setAreReadReceiptsEnabled(value: Bool, tx: DBWriteTransaction) {
        receiptManager.setAreReadReceiptsEnabled(value, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - TypingIndicators

public protocol _MessageBackup_AccountData_TypingIndicatorsShim {
    func areTypingIndicatorsEnabled() -> Bool
    func setTypingIndicatorsEnabled(value: Bool, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_TypingIndicatorsWrapper: _MessageBackup_AccountData_TypingIndicatorsShim {
    let typingIndicators: TypingIndicators
    init(typingIndicators: TypingIndicators) {
        self.typingIndicators = typingIndicators
    }

    public func areTypingIndicatorsEnabled() -> Bool {
        typingIndicators.areTypingIndicatorsEnabled()
    }

    public func setTypingIndicatorsEnabled(value: Bool, tx: DBWriteTransaction) {
        typingIndicators.setTypingIndicatorsEnabled(value: value, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - Preferences

public protocol _MessageBackup_AccountData_PreferencesShim {
    func shouldShowUnidentifiedDeliveryIndicators(tx: DBReadTransaction) -> Bool
    func setShouldShowUnidentifiedDeliveryIndicators(value: Bool, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_PreferencesWrapper: _MessageBackup_AccountData_PreferencesShim {
    let preferences: Preferences
    init(preferences: Preferences) {
        self.preferences = preferences
    }

    public func shouldShowUnidentifiedDeliveryIndicators(tx: DBReadTransaction) -> Bool {
        preferences.shouldShowUnidentifiedDeliveryIndicators(transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func setShouldShowUnidentifiedDeliveryIndicators(value: Bool, tx: DBWriteTransaction) {
        preferences.setShouldShowUnidentifiedDeliveryIndicators(value, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - SSKPreferences

public protocol _MessageBackup_AccountData_SSKPreferencesShim {
    func areLinkPreviewsEnabled(tx: DBReadTransaction) -> Bool
    func setAreLinkPreviewsEnabled(value: Bool, tx: DBWriteTransaction)

    func preferContactAvatars(tx: DBReadTransaction) -> Bool
    func setPreferContactAvatars(value: Bool, tx: DBWriteTransaction)

    func shouldKeepMutedChatsArchived(tx: DBReadTransaction) -> Bool
    func setShouldKeepMutedChatsArchived(value: Bool, tx: DBWriteTransaction)

}
public class _MessageBackup_AccountData_SSKPreferencesWrapper: _MessageBackup_AccountData_SSKPreferencesShim {
    public func areLinkPreviewsEnabled(tx: DBReadTransaction) -> Bool {
        SSKPreferences.areLinkPreviewsEnabled(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setAreLinkPreviewsEnabled(value: Bool, tx: DBWriteTransaction) {
        SSKPreferences.setAreLinkPreviewsEnabled(value, sendSyncMessage: false, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func preferContactAvatars(tx: DBReadTransaction) -> Bool {
        SSKPreferences.preferContactAvatars(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setPreferContactAvatars(value: Bool, tx: DBWriteTransaction) {
        SSKPreferences.setPreferContactAvatars(value, updateStorageService: false, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func shouldKeepMutedChatsArchived(tx: DBReadTransaction) -> Bool {
        SSKPreferences.shouldKeepMutedChatsArchived(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setShouldKeepMutedChatsArchived(value: Bool, tx: DBWriteTransaction) {
        SSKPreferences.setShouldKeepMutedChatsArchived(value, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - SubscriptionManager

public protocol _MessageBackup_AccountData_SubscriptionManagerShim {
    func displayBadgesOnProfile(tx: DBReadTransaction) -> Bool
    func setDisplayBadgesOnProfile(value: Bool, tx: DBWriteTransaction)
    func getSubscriberID(tx: DBReadTransaction) -> Data?
    func setSubscriberID(subscriberID: Data, tx: DBWriteTransaction)
    func getSubscriberCurrencyCode(tx: DBReadTransaction) -> String?
    func setSubscriberCurrencyCode(currencyCode: Currency.Code?, tx: DBWriteTransaction)
    func userManuallyCancelledSubscription(tx: DBReadTransaction) -> Bool
    func setUserManuallyCancelledSubscription(value: Bool, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_SubscriptionManagerWrapper: _MessageBackup_AccountData_SubscriptionManagerShim {
    let subscriptionManager: SubscriptionManager
    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    public func displayBadgesOnProfile(tx: DBReadTransaction) -> Bool {
        subscriptionManager.displayBadgesOnProfile(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setDisplayBadgesOnProfile(value: Bool, tx: DBWriteTransaction) {
        subscriptionManager.setDisplayBadgesOnProfile(value, updateStorageService: false, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func getSubscriberID(tx: DBReadTransaction) -> Data? {
        subscriptionManager.getSubscriberID(transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func setSubscriberID(subscriberID: Data, tx: DBWriteTransaction) {
        subscriptionManager.setSubscriberID(subscriberID, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func getSubscriberCurrencyCode(tx: DBReadTransaction) -> String? {
        subscriptionManager.getSubscriberCurrencyCode(transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func setSubscriberCurrencyCode(currencyCode: Currency.Code?, tx: DBWriteTransaction) {
        subscriptionManager.setSubscriberCurrencyCode(currencyCode, transaction: SDSDB.shimOnlyBridge(tx))
    }

    public func userManuallyCancelledSubscription(tx: DBReadTransaction) -> Bool {
        subscriptionManager.userManuallyCancelledSubscription(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setUserManuallyCancelledSubscription(value: Bool, tx: DBWriteTransaction) {
        subscriptionManager.setUserManuallyCancelledSubscription(value, updateStorageService: false, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - StoryManager

public protocol _MessageBackup_AccountData_StoryManagerShim {
    func hasSetMyStoriesPrivacy(tx: DBReadTransaction) -> Bool
    func setHasSetMyStoriesPrivacy(value: Bool, tx: DBWriteTransaction)
    func areStoriesEnabled(tx: DBReadTransaction) -> Bool
    func setAreStoriesEnabled(value: Bool, tx: DBWriteTransaction)
    func areViewReceiptsEnabled(tx: DBReadTransaction) -> Bool
    func setAreViewReceiptsEnabled(value: Bool, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_StoryManagerWrapper: _MessageBackup_AccountData_StoryManagerShim {
    public func hasSetMyStoriesPrivacy(tx: DBReadTransaction) -> Bool {
        StoryManager.hasSetMyStoriesPrivacy(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setHasSetMyStoriesPrivacy(value: Bool, tx: DBWriteTransaction) {
        StoryManager.setHasSetMyStoriesPrivacy(value, transaction: SDSDB.shimOnlyBridge(tx), shouldUpdateStorageService: false)
    }
    public func areStoriesEnabled(tx: DBReadTransaction) -> Bool {
        StoryManager.areStoriesEnabled(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setAreStoriesEnabled(value: Bool, tx: DBWriteTransaction) {
        StoryManager.setAreStoriesEnabled(value, transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func areViewReceiptsEnabled(tx: DBReadTransaction) -> Bool {
        StoryManager.areViewReceiptsEnabled(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setAreViewReceiptsEnabled(value: Bool, tx: DBWriteTransaction) {
        StoryManager.setAreViewReceiptsEnabled(value, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - SystemStoryManager

public protocol _MessageBackup_AccountData_SystemStoryManagerShim {
    func isOnboardingStoryViewed(tx: DBReadTransaction) -> Bool
    func setHasViewedOnboardingStory(value: Bool, tx: DBWriteTransaction)
    func hasSeenGroupStoryEducationSheet(tx: DBReadTransaction) -> Bool
    func setHasSeenGroupStoryEducationSheet(value: Bool, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_SystemStoryManagerWrapper: _MessageBackup_AccountData_SystemStoryManagerShim {
    let systemStoryManager: SystemStoryManagerProtocol
    init(systemStoryManager: SystemStoryManagerProtocol) {
        self.systemStoryManager = systemStoryManager
    }
    public func isOnboardingStoryViewed(tx: DBReadTransaction) -> Bool {
        systemStoryManager.isOnboardingStoryViewed(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setHasViewedOnboardingStory(value: Bool, tx: DBWriteTransaction) {
        let source: OnboardingStoryViewSource = .local(
            timestamp: Date.distantPast.ows_millisecondsSince1970,
            shouldUpdateStorageService: false
        )
        try? systemStoryManager.setHasViewedOnboardingStory(source: source, transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func hasSeenGroupStoryEducationSheet(tx: DBReadTransaction) -> Bool {
        systemStoryManager.isOnboardingOverlayViewed(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setHasSeenGroupStoryEducationSheet(value: Bool, tx: DBWriteTransaction) {
        systemStoryManager.setOnboardingOverlayViewed(value: value, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - ReactionManager

public protocol _MessageBackup_AccountData_ReactionManagerShim {
    func customEmojiSet(tx: DBReadTransaction) -> [String]?
    func setCustomEmojiSet(emojis: [String]?, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_ReactionManagerWrapper: _MessageBackup_AccountData_ReactionManagerShim {
    public func customEmojiSet(tx: DBReadTransaction) -> [String]? {
        ReactionManager.customEmojiSet(transaction: SDSDB.shimOnlyBridge(tx))
    }
    public func setCustomEmojiSet(emojis: [String]?, tx: DBWriteTransaction) {
        ReactionManager.setCustomEmojiSet(emojis, transaction: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - UDManager

public protocol _MessageBackup_AccountData_UDManagerShim {
    func phoneNumberSharingMode(tx: DBReadTransaction) -> PhoneNumberSharingMode?
    func setPhoneNumberSharingMode(_ mode: PhoneNumberSharingMode, tx: DBWriteTransaction)
}
public class _MessageBackup_AccountData_UDManagerWrapper: _MessageBackup_AccountData_UDManagerShim {
    let udManager: OWSUDManager
    init(udManager: OWSUDManager) {
        self.udManager = udManager
    }
    public func phoneNumberSharingMode(tx: DBReadTransaction) -> PhoneNumberSharingMode? {
        udManager.phoneNumberSharingMode(tx: tx)
    }
    public func setPhoneNumberSharingMode(_ mode: PhoneNumberSharingMode, tx: DBWriteTransaction) {
        udManager.setPhoneNumberSharingMode(mode, updateStorageServiceAndProfile: false, tx: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - UserProfile

public protocol _MessageBackup_AccountData_UserProfileShim {
    func getLocalProfile(tx: DBReadTransaction) -> OWSUserProfile?
    func insertLocalProfile(
        givenName: String,
        familyName: String?,
        avatarUrlPath: String?,
        profileKey: OWSAES256Key,
        tx: DBWriteTransaction
    )
}
public class _MessageBackup_AccountData_UserProfileWrapper: _MessageBackup_AccountData_UserProfileShim {
    public func getLocalProfile(tx: DBReadTransaction) -> OWSUserProfile? {
        return OWSUserProfile.getUserProfileForLocalUser(tx: SDSDB.shimOnlyBridge(tx))
    }

    public func insertLocalProfile(
        givenName: String,
        familyName: String?,
        avatarUrlPath: String?,
        profileKey: OWSAES256Key,
        tx: DBWriteTransaction
    ) {
        OWSUserProfile(
            address: .localUser,
            givenName: givenName,
            familyName: familyName,
            profileKey: profileKey,
            avatarUrlPath: avatarUrlPath
        ).anyInsert(transaction: SDSDB.shimOnlyBridge(tx))
    }
}
