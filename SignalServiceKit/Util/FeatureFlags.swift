//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalCoreKit

enum FeatureBuild: Int {
    case dev
    case `internal`
    case beta
    case production
}

private extension FeatureBuild {
    func includes(_ level: FeatureBuild) -> Bool {
        return self.rawValue <= level.rawValue
    }
}

private let build = FeatureBuild.current

// MARK: -

@objc
public enum StorageMode: Int {
    // Use GRDB.
    case grdb
    // These modes can be used while running tests.
    // They are more permissive than the release modes.
    //
    // The build shepherd should be running the test
    // suites in .grdbTests mode before each release.
    case grdbTests
}

// MARK: -

extension StorageMode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .grdb:
            return ".grdb"
        case .grdbTests:
            return ".grdbTests"
        }
    }
}

// MARK: -

/// By centralizing feature flags here and documenting their rollout plan, it's easier to review
/// which feature flags are in play.
@objc(SSKFeatureFlags)
public class FeatureFlags: NSObject {

    public static let choochoo = build.includes(.internal)

    public static let linkedPhones = build.includes(.internal)

    public static let preRegDeviceTransfer = build.includes(.dev)

    @objc
    public static let supportAnimatedStickers_Lottie = false

    public static let paymentsScrubDetails = false

    public static let deprecateREST = false

    public static let isPrerelease = build.includes(.beta)

    public static let useCallMemberComposableViewsForRemoteUsersInGroupCalls = false
    public static let useCallMemberComposableViewsForRemoteUserInIndividualCalls = false

    public static let useLibSignalNetForCdsi = build.includes(.internal)

    @objc
    public static var notificationServiceExtension: Bool {
        // The CallKit APIs for the NSE are only available from iOS 14.5 and on,
        // however there is a significant bug in iOS 14 where the NSE will not
        // launch properly after a crash so we only support it in iOS 15.
        if #available(iOS 15, *) { return true }
        return false
    }

    /// If we ever need to internally detect database corruption again in the
    /// future, we can re-enable this.
    public static let periodicallyCheckDatabaseIntegrity: Bool = false

    public static let doNotSendGroupChangeMessagesOnProfileKeyRotation = false

    public static let messageBackupFileAlpha = build.includes(.internal)
    public static let messageBackupFileAlphaRegistrationFlow = build.includes(.dev)

    public static let readV2Attachments = false
    public static let newAttachmentsUseV2 = false

    public static let callLinkJoin = build.includes(.dev)

    public static let callReactionReceiveSupport = build.includes(.production)
    public static let callReactionSendSupport = build.includes(.production)

    public static let callRaiseHandReceiveSupport = build.includes(.dev)
}

// MARK: -

extension FeatureFlags {
    public static var buildVariantString: String? {
        // Leaving this internal only for now. If we ever move this to
        // HelpSettings we need to localize these strings
        guard DebugFlags.internalSettings else {
            owsFailDebug("Incomplete implementation. Needs localization")
            return nil
        }

        let featureFlagString: String?
        switch build {
        case .dev:
            featureFlagString = LocalizationNotNeeded("Dev")
        case .internal:
            featureFlagString = LocalizationNotNeeded("Internal")
        case .beta:
            featureFlagString = LocalizationNotNeeded("Beta")
        case .production:
            // Production can be inferred from the lack of flag
            featureFlagString = nil
        }

        let configuration: String? = {
            #if DEBUG
            LocalizationNotNeeded("Debug")
            #elseif TESTABLE_BUILD
            LocalizationNotNeeded("Testable")
            #else
            // RELEASE can be inferred from the lack of configuration. This will only be hit if the outer #if is removed.
            nil
            #endif
        }()

        // If we're Production+Release, this will return nil and won't show up in Help Settings
        return [featureFlagString, configuration]
            .compactMap { $0 }
            .joined(separator: " — ")
            .nilIfEmpty
    }

    @objc
    public static var storageMode: StorageMode {
        if CurrentAppContext().isRunningTests {
            return .grdbTests
        } else {
            return .grdb
        }
    }

    @objc
    public static var storageModeDescription: String {
        return "\(storageMode)"
    }
}

// MARK: -

/// Flags that we'll leave in the code base indefinitely that are helpful for
/// development should go here, rather than cluttering up FeatureFlags.
@objc(SSKDebugFlags)
public class DebugFlags: NSObject {
    @objc
    public static let internalLogging = build.includes(.internal)

    public static let betaLogging = build.includes(.beta)

    public static let testPopulationErrorAlerts = build.includes(.beta)

    public static let audibleErrorLogging = build.includes(.internal)

    public static let internalSettings = build.includes(.internal)

    public static let internalMegaphoneEligible = build.includes(.internal)

    @objc
    public static let reduceLogChatter: Bool = {
        // This is a little verbose to make it easy to change while developing.
        if CurrentAppContext().isRunningTests {
            return true
        }
        return false
    }()

    public static let aggressiveProfileFetching = TestableFlag(
        false,
        title: LocalizationNotNeeded("Aggressive profile fetching"),
        details: LocalizationNotNeeded("Client will update profiles aggressively.")
    )

    // Currently this flag is only honored by NetworkManager,
    // but we could eventually honor in other places as well:
    //
    // * The socket manager.
    // * Places we make requests using tasks.
    public static let logCurlOnSuccess = false

    public static let verboseNotificationLogging = build.includes(.internal)

    public static let deviceTransferVerboseProgressLogging = build.includes(.internal)

    public static let messageDetailsExtraInfo = build.includes(.internal)

    public static let exposeCensorshipCircumvention = build.includes(.internal)

    public static let dontSendContactOrGroupSyncMessages = TestableFlag(
        false,
        title: LocalizationNotNeeded("Don't send contact or group sync messages"),
        details: LocalizationNotNeeded("Client will not send contact or group info to linked devices.")
    )

    public static let forceAttachmentDownloadFailures = TestableFlag(
        false,
        title: LocalizationNotNeeded("Force attachment download failures."),
        details: LocalizationNotNeeded("All attachment downloads will fail.")
    )

    public static let forceAttachmentDownloadPendingMessageRequest = TestableFlag(
        false,
        title: LocalizationNotNeeded("Attachment download vs. message request."),
        details: LocalizationNotNeeded("Attachment downloads will be blocked by pending message request.")
    )

    public static let forceAttachmentDownloadPendingManualDownload = TestableFlag(
        false,
        title: LocalizationNotNeeded("Attachment download vs. manual download."),
        details: LocalizationNotNeeded("Attachment downloads will be blocked by manual download.")
    )

    public static let fastPerfTests = false

    public static let extraDebugLogs = build.includes(.internal)

    @objc
    public static let paymentsIgnoreBlockTimestamps = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Ignore ledger block timestamps"),
        details: LocalizationNotNeeded("Payments will not fill in missing ledger block timestamps")
    )

    public static let paymentsIgnoreCurrencyConversions = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Ignore currency conversions"),
        details: LocalizationNotNeeded("App will behave as though currency conversions are unavailable")
    )

    public static let paymentsHaltProcessing = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Halt Processing"),
        details: LocalizationNotNeeded("Processing of payments will pause")
    )

    public static let paymentsIgnoreBadData = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Ignore bad data"),
        details: LocalizationNotNeeded("App will skip asserts for invalid data")
    )

    public static let paymentsFailOutgoingSubmission = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Fail outgoing submission"),
        details: LocalizationNotNeeded("Submission of outgoing transactions will always fail")
    )

    public static let paymentsFailOutgoingVerification = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Fail outgoing verification"),
        details: LocalizationNotNeeded("Verification of outgoing transactions will always fail")
    )

    public static let paymentsFailIncomingVerification = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Fail incoming verification"),
        details: LocalizationNotNeeded("Verification of incoming receipts will always fail")
    )

    public static let paymentsDoubleNotify = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Double notify"),
        details: LocalizationNotNeeded("App will send two payment notifications and sync messages for each outgoing payment")
    )

    public static let paymentsNoRequestsComplete = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: No requests complete"),
        details: LocalizationNotNeeded("MC SDK network activity never completes")
    )

    public static let paymentsMalformedMessages = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Malformed messages"),
        details: LocalizationNotNeeded("Payment notifications and sync messages are malformed.")
    )

    public static let paymentsSkipSubmissionAndOutgoingVerification = TestableFlag(
        false,
        title: LocalizationNotNeeded("Payments: Skip Submission And Verification"),
        details: LocalizationNotNeeded("Outgoing payments won't be submitted or verified.")
    )

    public static let messageSendsFail = TestableFlag(
        false,
        title: LocalizationNotNeeded("Message Sends Fail"),
        details: LocalizationNotNeeded("All outgoing message sends will fail.")
    )

    public static let disableUD = TestableFlag(
        false,
        title: LocalizationNotNeeded("Disable sealed sender"),
        details: LocalizationNotNeeded("Sealed sender will be disabled for all messages.")
    )

    public static let callingUseTestSFU = TestableFlag(
        false,
        title: LocalizationNotNeeded("Calling: Use Test SFU"),
        details: LocalizationNotNeeded("Group calls will connect to sfu.test.voip.signal.org.")
    )

    public static let delayedMessageResend = TestableFlag(
        false,
        title: LocalizationNotNeeded("Sender Key: Delayed message resend"),
        details: LocalizationNotNeeded("Waits 10s before responding to a resend request.")
    )

    @objc
    public static let showFailedDecryptionPlaceholders = TestableFlag(
        false,
        title: LocalizationNotNeeded("Sender Key: Show failed decryption placeholders"),
        details: LocalizationNotNeeded("Shows placeholder interactions in the conversation list.")
    )

    @objc
    public static let fastPlaceholderExpiration = TestableFlag(
        false,
        title: LocalizationNotNeeded("Sender Key: Early placeholder expiration"),
        details: LocalizationNotNeeded("Shortens the valid window for message resend+recovery."),
        toggleHandler: { _ in
            NSObject.messageDecrypter.cleanUpExpiredPlaceholders()
        }
    )

    public static func allTestableFlags() -> [TestableFlag] {
        return [
            aggressiveProfileFetching,
            callingUseTestSFU,
            delayedMessageResend,
            disableUD,
            dontSendContactOrGroupSyncMessages,
            fastPlaceholderExpiration,
            forceAttachmentDownloadFailures,
            forceAttachmentDownloadPendingManualDownload,
            forceAttachmentDownloadPendingMessageRequest,
            messageSendsFail,
            paymentsDoubleNotify,
            paymentsFailIncomingVerification,
            paymentsFailOutgoingSubmission,
            paymentsFailOutgoingVerification,
            paymentsHaltProcessing,
            paymentsIgnoreBadData,
            paymentsIgnoreBlockTimestamps,
            paymentsIgnoreCurrencyConversions,
            paymentsMalformedMessages,
            paymentsNoRequestsComplete,
            paymentsSkipSubmissionAndOutgoingVerification,
            showFailedDecryptionPlaceholders,
        ]
    }
}

// MARK: -

@objc
public class TestableFlag: NSObject {
    private let defaultValue: Bool
    private let affectsCapabilities: Bool
    private let flag: AtomicBool
    public let title: String
    public let details: String
    public let toggleHandler: ((Bool) -> Void)?

    fileprivate init(_ defaultValue: Bool,
                     title: String,
                     details: String,
                     affectsCapabilities: Bool = false,
                     toggleHandler: ((Bool) -> Void)? = nil) {
        self.defaultValue = defaultValue
        self.title = title
        self.details = details
        self.affectsCapabilities = affectsCapabilities
        self.flag = AtomicBool(defaultValue, lock: .sharedGlobal)
        self.toggleHandler = toggleHandler

        super.init()

        // Normally we'd store the observer here and remove it in deinit.
        // But TestableFlags are always static; they don't *get* deinitialized except in testing.
        NotificationCenter.default.addObserver(forName: Self.ResetAllTestableFlagsNotification,
                                               object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }
            self.set(self.defaultValue)
        }
    }

    @objc
    @available(swift, obsoleted: 1.0)
    public var value: Bool {
        self.get()
    }

    @objc
    public func get() -> Bool {
        guard build.includes(.internal) else {
            return defaultValue
        }
        return flag.get()
    }

    public func set(_ value: Bool) {
        flag.set(value)

        if affectsCapabilities {
            updateCapabilities()
        }

        toggleHandler?(value)
    }

    @objc
    public func switchDidChange(_ sender: UISwitch) {
        set(sender.isOn)
    }

    @objc
    public var switchSelector: Selector {
        #selector(switchDidChange(_:))
    }

    @objc
    public static let ResetAllTestableFlagsNotification = NSNotification.Name("ResetAllTestableFlags")

    private func updateCapabilities() {
        firstly(on: DispatchQueue.global()) { () -> Promise<Void> in
            return Promise.wrapAsync {
                try await DependenciesBridge.shared.accountAttributesUpdater.updateAccountAttributes(authedAccount: .implicit())
            }
        }.done {
            Logger.info("")
        }.catch { error in
            owsFailDebug("Error: \(error)")
        }
    }
}
