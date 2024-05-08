//
// Copyright 2022 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import GRDB
import Intents
import SignalServiceKit
import SignalUI
import WebRTC

enum LaunchPreflightError {
    case unknownDatabaseVersion
    case couldNotRestoreTransferredData
    case databaseCorruptedAndMightBeRecoverable
    case databaseUnrecoverablyCorrupted
    case lastAppLaunchCrashed
    case lowStorageSpaceAvailable
    case possibleReadCorruptionCrashed

    var supportTag: String {
        switch self {
        case .unknownDatabaseVersion:
            return "LaunchFailure_UnknownDatabaseVersion"
        case .couldNotRestoreTransferredData:
            return "LaunchFailure_CouldNotRestoreTransferredData"
        case .databaseCorruptedAndMightBeRecoverable:
            return "LaunchFailure_DatabaseCorruptedAndMightBeRecoverable"
        case .databaseUnrecoverablyCorrupted:
            return "LaunchFailure_DatabaseUnrecoverablyCorrupted"
        case .lastAppLaunchCrashed:
            return "LaunchFailure_LastAppLaunchCrashed"
        case .lowStorageSpaceAvailable:
            return "LaunchFailure_NoDiskSpaceAvailable"
        case .possibleReadCorruptionCrashed:
            return "LaunchFailure_PossibleReadCorruption"
        }
    }
}

private func uncaughtExceptionHandler(_ exception: NSException) {
    if DebugFlags.internalLogging {
        Logger.error("exception: \(exception)")
        Logger.error("name: \(exception.name)")
        Logger.error("reason: \(String(describing: exception.reason))")
        Logger.error("userInfo: \(String(describing: exception.userInfo))")
    } else {
        let reason = exception.reason ?? ""
        let reasonData = reason.data(using: .utf8) ?? Data()
        let reasonHash = Cryptography.computeSHA256Digest(reasonData)?.base64EncodedString() ?? ""

        var truncatedReason = reason.prefix(20)
        if let spaceIndex = truncatedReason.lastIndex(of: " ") {
            truncatedReason = truncatedReason[..<spaceIndex]
        }
        let maybeEllipsis = (truncatedReason.endIndex < reason.endIndex) ? "..." : ""
        Logger.error("\(exception.name): \(truncatedReason)\(maybeEllipsis) (hash: \(reasonHash))")
    }
    Logger.error("callStackSymbols: \(exception.callStackSymbols.joined(separator: "\n"))")
    Logger.flush()
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: - Constants

    private enum Constants {
        static let appLaunchesAttemptedKey = "AppLaunchesAttempted"
    }

    // MARK: - Lifecycle

    func applicationWillEnterForeground(_ application: UIApplication) {
        Logger.info("")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AssertIsOnMainThread()
        if CurrentAppContext().isRunningTests {
            return
        }

        Logger.warn("")

        if didAppLaunchFail {
            return
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadySync { self.handleActivation() }

        // Clear all notifications whenever we become active.
        // When opening the app from a notification,
        // AppDelegate.didReceiveLocalNotification will always
        // be called _before_ we become active.
        clearAllNotificationsAndRestoreBadgeCount()

        // On every activation, clear old temp directories.
        ClearOldTemporaryDirectories()

        // Ensure that all windows have the correct frame.
        WindowManager.shared.updateWindowFrames()
    }

    private let flushQueue = DispatchQueue(label: "org.signal.flush", qos: .utility)

    func applicationWillResignActive(_ application: UIApplication) {
        AssertIsOnMainThread()

        if didAppLaunchFail {
            return
        }

        Logger.warn("")

        clearAllNotificationsAndRestoreBadgeCount()

        let backgroundTask = OWSBackgroundTask(label: #function)
        flushQueue.async {
            defer { backgroundTask.end() }
            Logger.flush()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Logger.info("")

        if shouldKillAppWhenBackgrounded {
            Logger.flush()
            exit(0)
        }
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Logger.info("")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Logger.info("")
        Logger.flush()
    }

    // MARK: - App Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let launchStartedAt = CACurrentMediaTime()

        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler(_:))

        // This should be the first thing we do.
        let mainAppContext = MainAppContext()
        SetCurrentAppContext(mainAppContext, false)

        let debugLogger = DebugLogger.shared
        debugLogger.enableTTYLoggingIfNeeded()

        if mainAppContext.isRunningTests {
            _ = initializeWindow(mainAppContext: mainAppContext, rootViewController: UIViewController())
            return true
        }

        debugLogger.setUpFileLoggingIfNeeded(appContext: mainAppContext, canLaunchInBackground: true)
        debugLogger.wipeLogsIfDisabled(appContext: mainAppContext)
        DebugLogger.configureSwiftLogging()
        if DebugFlags.audibleErrorLogging {
            debugLogger.enableErrorReporting()
        }

        Logger.warn("Synchronous launch started")
        defer { Logger.info("Synchronous launch finished") }

        BenchEventStart(title: "Presenting HomeView", eventId: "AppStart", logInProduction: true)
        AppReadiness.runNowOrWhenUIDidBecomeReadySync { BenchEventComplete(eventId: "AppStart") }

        Cryptography.seedRandom()

        MessageFetchBGRefreshTask.register()

        // This *must* happen before we try and access or verify the database,
        // since we may be in a state where the database has been partially
        // restored from transfer (e.g. the key was replaced, but the database
        // files haven't been moved into place)
        let didDeviceTransferRestoreSucceed = Bench(
            title: "Slow device transfer service launch",
            logIfLongerThan: 0.01,
            logInProduction: true,
            block: { DeviceTransferService.shared.launchCleanup() }
        )

        let keychainStorage = KeychainStorageImpl(isUsingProductionService: TSConstants.isUsingProductionService)
        let databaseStorage: SDSDatabaseStorage
        do {
            databaseStorage = try SDSDatabaseStorage(
                databaseFileUrl: SDSDatabaseStorage.grdbDatabaseFileUrl,
                keychainStorage: keychainStorage
            )
        } catch KeychainError.notAllowed where application.applicationState == .background {
            notifyThatPhoneMustBeUnlocked()
        } catch let error as DatabaseError where error.resultCode == .SQLITE_CORRUPT {
            // It's so corrupt that we can't even try to repair it.
            didAppLaunchFail = true
            Logger.error("Couldn't launch with corrupt database")
            let viewController = terminalErrorViewController()
            _ = initializeWindow(mainAppContext: mainAppContext, rootViewController: viewController)
            presentDatabaseUnrecoverablyCorruptedError(from: viewController, action: .submitDebugLogsAndCrash)
            return true
        } catch {
            owsFail("Couldn't load database: \(error.grdbErrorForLogging)")
        }

        // This must happen in appDidFinishLaunching or earlier to ensure we don't
        // miss notifications. Setting the delegate also seems to prevent us from
        // getting the legacy notification notification callbacks upon launch e.g.
        // 'didReceiveLocalNotification'
        UNUserNotificationCenter.current().delegate = self

        // If there's a notification, queue it up for processing. (This processing
        // may happen immediately, after a short delay, or never.)
        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Logger.info("Application was launched by tapping a push notification.")
            processRemoteNotification(remoteNotification, completion: {})
        }

        // Do this even if `appVersion` isn't used -- there's side effects.
        let appVersion = AppVersionImpl.shared

        let launchContext = LaunchContext(
            appContext: mainAppContext,
            databaseStorage: databaseStorage,
            keychainStorage: keychainStorage,
            launchStartedAt: launchStartedAt
        )

        // Ensure this exists on the main thread before attempting database
        // restore. Otherwise it may try to access it for the first time in the
        // background and crash.
        _ = OWSBackgroundTaskManager.shared()

        // We need to do this _after_ we set up logging, when the keychain is unlocked,
        // but before we access the database or files on disk.
        let preflightError = checkIfAllowedToLaunch(
            mainAppContext: mainAppContext,
            appVersion: appVersion,
            didDeviceTransferRestoreSucceed: didDeviceTransferRestoreSucceed
        )

        if let preflightError {
            didAppLaunchFail = true
            let viewController = terminalErrorViewController()
            let window = initializeWindow(mainAppContext: mainAppContext, rootViewController: viewController)
            showPreflightErrorUI(
                preflightError,
                launchContext: launchContext,
                window: window,
                viewController: viewController
            )
            return true
        }

        // If this is a regular launch, increment the "launches attempted" counter.
        // If repeatedly start launching but never finish them (ie the app is
        // crashing while launching), we'll notice in `checkIfAllowedToLaunch`.
        let userDefaults = mainAppContext.appUserDefaults()
        let appLaunchesAttempted = userDefaults.integer(forKey: Constants.appLaunchesAttemptedKey)
        userDefaults.set(appLaunchesAttempted + 1, forKey: Constants.appLaunchesAttemptedKey)

        // Show LoadingViewController until the database migrations are complete.
        let window = initializeWindow(mainAppContext: mainAppContext, rootViewController: LoadingViewController())
        self.launchApp(in: window, launchContext: launchContext)
        return true
    }

    var window: UIWindow?

    private func initializeWindow(mainAppContext: MainAppContext, rootViewController: UIViewController) -> UIWindow {
        let window = OWSWindow()
        self.window = window
        mainAppContext.mainWindow = window
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        return window
    }

    private struct LaunchContext {
        var appContext: MainAppContext
        var databaseStorage: SDSDatabaseStorage
        var keychainStorage: any KeychainStorage
        var launchStartedAt: CFTimeInterval
    }

    private func launchApp(
        in window: UIWindow,
        launchContext: LaunchContext
    ) {
        assert(window.rootViewController is LoadingViewController)
        configureGlobalUI(in: window)
        setUpMainAppEnvironment(
            launchContext: launchContext
        ).done(on: DispatchQueue.main) { (finalContinuation, sleepBlockObject) in
            self.didLoadDatabase(
                finalContinuation: finalContinuation,
                launchContext: launchContext,
                sleepBlockObject: sleepBlockObject,
                window: window
            )
        }
    }

    private func configureGlobalUI(in window: UIWindow) {
        Theme.setupSignalAppearance()

        let screenLockUI = ScreenLockUI.shared
        screenLockUI.setupWithRootWindow(window)
        WindowManager.shared.setupWithRootWindow(window, screenBlockingWindow: screenLockUI.screenBlockingWindow)
        screenLockUI.startObserving()
    }

    private func setUpMainAppEnvironment(launchContext: LaunchContext) -> Guarantee<(AppSetup.FinalContinuation, NSObject)> {
        let sleepBlockObject = NSObject()
        DeviceSleepManager.shared.addBlock(blockObject: sleepBlockObject)

        let _currentCall = AtomicValue<SignalCall?>(nil, lock: .init())
        let currentCall = CurrentCall(rawValue: _currentCall)

        let databaseContinuation = AppSetup().start(
            appContext: launchContext.appContext,
            databaseStorage: launchContext.databaseStorage,
            paymentsEvents: PaymentsEventsMainApp(),
            mobileCoinHelper: MobileCoinHelperSDK(),
            callMessageHandler: WebRTCCallMessageHandler(),
            currentCallThreadProvider: currentCall,
            notificationPresenter: NotificationPresenterImpl()
        )
        setupNSEInteroperation()
        SUIEnvironment.shared.setup()
        AppEnvironment.shared.setUp(callService: CallService(
            appContext: launchContext.appContext,
            groupCallPeekClient: NSObject.groupCallManager.groupCallPeekClient,
            mutableCurrentCall: _currentCall
        ))
        let result = databaseContinuation.prepareDatabase()
        return result.map(on: SyncScheduler()) { ($0, sleepBlockObject) }
    }

    private func checkSomeDiskSpaceAvailable() -> Bool {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .path
        let succeededCreatingDir = OWSFileSystem.ensureDirectoryExists(tempDir)

        // Best effort at deleting temp dir, which shouldn't ever fail
        if succeededCreatingDir && !OWSFileSystem.deleteFile(tempDir) {
            owsFailDebug("Failed to delete temp dir used for checking disk space!")
        }

        return succeededCreatingDir
    }

    private func setupNSEInteroperation() {
        // We immediately post a notification letting the NSE know the main app has launched.
        // If it's running it should take this as a sign to terminate so we don't unintentionally
        // try and fetch messages from two processes at once.
        DarwinNotificationCenter.post(.mainAppLaunched)

        // We listen to this notification for the lifetime of the application, so we don't
        // record the returned observer token.
        DarwinNotificationCenter.addObserver(
            for: .nseDidReceiveNotification,
            queue: DispatchQueue.global(qos: .userInitiated)
        ) { token in
            // Immediately let the NSE know we will handle this notification so that it
            // does not attempt to process messages while we are active.
            DarwinNotificationCenter.post(.mainAppHandledNotification)

            AppReadiness.runNowOrWhenAppDidBecomeReadySync {
                self.messageFetcherJob.run()
            }
        }
    }

    private func didLoadDatabase(
        finalContinuation: AppSetup.FinalContinuation,
        launchContext: LaunchContext,
        sleepBlockObject: NSObject,
        window: UIWindow
    ) {
        AssertIsOnMainThread()

        // First thing; clean up any transfer state in case we are launching after a transfer.
        // This needs to happen before we check any registration state.
        DependenciesBridge.shared.registrationStateChangeManager.cleanUpTransferStateOnAppLaunchIfNeeded()

        let regLoader = RegistrationCoordinatorLoaderImpl(dependencies: .from(self))

        // Before we mark ready, block message processing on any pending change numbers.
        let hasPendingChangeNumber = databaseStorage.read { transaction in
            regLoader.hasPendingChangeNumber(transaction: transaction.asV2Read)
        }
        if hasPendingChangeNumber {
            // The registration loader will clear the suspension later on.
            messagePipelineSupervisor.suspendMessageProcessingWithoutHandle(for: .pendingChangeNumber)
        }

        let launchInterface = buildLaunchInterface(regLoader: regLoader)

        let hasInProgressRegistration: Bool
        switch launchInterface {
        case .registration, .secondaryProvisioning:
            hasInProgressRegistration = true
        case .chatList:
            hasInProgressRegistration = false
        }

        switch finalContinuation.finish(willResumeInProgressRegistration: hasInProgressRegistration) {
        case .corruptRegistrationState:
            let viewController = terminalErrorViewController()
            window.rootViewController = viewController
            presentLaunchFailureActionSheet(
                from: viewController,
                supportTag: "CorruptRegistrationState",
                title: OWSLocalizedString(
                    "APP_LAUNCH_FAILURE_CORRUPT_REGISTRATION_TITLE",
                    comment: "Title for an error indicating that the app couldn't launch because some unexpected error happened with the user's registration status."
                ),
                message: OWSLocalizedString(
                    "APP_LAUNCH_FAILURE_CORRUPT_REGISTRATION_MESSAGE",
                    comment: "Message for an error indicating that the app couldn't launch because some unexpected error happened with the user's registration status."
                ),
                actions: [.submitDebugLogsAndCrash]
            )
        case nil:
            firstly {
                LaunchJobs.run(
                    tsAccountManager: DependenciesBridge.shared.tsAccountManager,
                    databaseStorage: databaseStorage
                )
            }.done(on: DispatchQueue.main) {
                self.setAppIsReady(
                    launchInterface: launchInterface,
                    launchContext: launchContext
                )
                DeviceSleepManager.shared.removeBlock(blockObject: sleepBlockObject)
            }
        }
    }

    private func setAppIsReady(
        launchInterface: LaunchInterface,
        launchContext: LaunchContext
    ) {
        Logger.info("")
        AssertIsOnMainThread()
        owsAssert(!AppReadiness.isAppReady)
        owsAssert(!CurrentAppContext().isRunningTests)

        let appContext = launchContext.appContext

        if DebugFlags.internalLogging {
            DispatchQueue.global().async { SDSKeyValueStore.logCollectionStatistics() }
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            // This runs every 24 hours or so.
            let messageSendLog = SSKEnvironment.shared.messageSendLogRef
            messageSendLog.cleanUpAndScheduleNextOccurrence(on: DispatchQueue.global(qos: .utility))
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            OWSOrphanDataCleaner.auditOnLaunchIfNecessary()
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            Task.detached(priority: .low) {
                await FullTextSearchOptimizer(
                    appContext: appContext,
                    db: DependenciesBridge.shared.db,
                    keyValueStoreFactory: DependenciesBridge.shared.keyValueStoreFactory
                ).run()
            }
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            Task.detached(priority: .low) {
                await AuthorMergeHelperBuilder(
                    appContext: appContext,
                    authorMergeHelper: DependenciesBridge.shared.authorMergeHelper,
                    db: DependenciesBridge.shared.db,
                    dbFromTx: { tx in SDSDB.shimOnlyBridge(tx).unwrapGrdbRead.database },
                    modelReadCaches: AuthorMergeHelperBuilder.Wrappers.ModelReadCaches(ModelReadCaches.shared),
                    recipientDatabaseTable: DependenciesBridge.shared.recipientDatabaseTable
                ).buildTableIfNeeded()
            }
        }

        // Disable phone number sharing when rolling out PNP.
        //
        // TODO: Remove this once all builds are PNP-enabled.
        //
        // Once all builds are PNP enabled, we can remove this explicit migration
        // and simply treat the default as "nobody". The migration exists to ensure
        // old linked devices respect the setting before they upgrade.
        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            let db = DependenciesBridge.shared.db
            guard db.read(block: self.udManager.phoneNumberSharingMode(tx:)) == nil else {
                return
            }
            db.write { tx in
                guard self.udManager.phoneNumberSharingMode(tx: tx) == nil else {
                    return
                }
                self.udManager.setPhoneNumberSharingMode(
                    .nobody,
                    updateStorageServiceAndProfile: true,
                    tx: SDSDB.shimOnlyBridge(tx)
                )
            }
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            StaleProfileFetcher(
                db: DependenciesBridge.shared.db,
                profileFetcher: SSKEnvironment.shared.profileFetcherRef,
                tsAccountManager: DependenciesBridge.shared.tsAccountManager
            ).scheduleProfileFetches()
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            Task.detached(priority: .low) {
                YDBStorage.deleteYDBStorage()
                SSKPreferences.clearLegacyDatabaseFlags(from: appContext.appUserDefaults())
                try? launchContext.keychainStorage.removeValue(service: "TSKeyChainService", key: "TSDatabasePass")
                try? launchContext.keychainStorage.removeValue(service: "TSKeyChainService", key: "OWSDatabaseCipherKeySpec")
            }
        }

        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            RemoteMegaphoneFetcher(
                databaseStorage: NSObject.databaseStorage,
                signalService: NSObject.signalService
            ).syncRemoteMegaphonesIfNecessary()
        }

        // Note that this does much more than set a flag; it will also run all deferred blocks.
        AppReadiness.setAppIsReadyUIStillPending()

        appContext.appUserDefaults().removeObject(forKey: Constants.appLaunchesAttemptedKey)

        let tsAccountManager = DependenciesBridge.shared.tsAccountManager
        let tsRegistrationState: TSRegistrationState = databaseStorage.read { tx in
            let registrationState = tsAccountManager.registrationState(tx: tx.asV2Read)
            if registrationState.isRegistered, let localIdentifiers = tsAccountManager.localIdentifiers(tx: tx.asV2Read) {
                let deviceId = tsAccountManager.storedDeviceId(tx: tx.asV2Read)
                let deviceCount = OWSDevice.anyCount(transaction: tx)
                let linkedDeviceMessage = deviceCount > 1 ? "\(deviceCount) devices including the primary" : "no linked devices"
                Logger.info("localAci: \(localIdentifiers.aci), deviceId: \(deviceId) (\(linkedDeviceMessage))")
            }
            return registrationState
        }

        if tsRegistrationState.isRegistered {
            // This should happen at any launch, background or foreground.
            SyncPushTokensJob.run()
        }

        if tsRegistrationState.isRegistered {
            APNSRotationStore.rotateIfNeededOnAppLaunchAndReadiness(performRotation: {
                SyncPushTokensJob.run(mode: .rotateIfEligible)
            }).map {
                // If the method returns a closure, run it after message processing.
                _ = messageProcessor.waitForFetchingAndProcessing().done($0)
            }
        }

        if tsRegistrationState.isRegistered {
            Task { [profileManager] in
                do {
                    _ = try await profileManager.fetchLocalUsersProfile(
                        mainAppOnly: true,
                        authedAccount: .implicit()
                    ).awaitable()
                    try await profileManager.downloadAndDecryptLocalUserAvatarIfNeeded(
                        authedAccount: .implicit()
                    )
                } catch {
                    Logger.warn("Couldn't fetch local user profile or avatar: \(error)")
                }
            }
        }

        DebugLogger.shared.postLaunchLogCleanup(appContext: appContext)
        AppVersionImpl.shared.mainAppLaunchDidComplete()

        scheduleBgAppRefresh()
        Self.updateApplicationShortcutItems(isRegistered: tsRegistrationState.isRegistered)

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(registrationStateDidChange),
            name: .registrationStateDidChange,
            object: nil
        )

        if !preferences.hasGeneratedThumbnails {
            databaseStorage.asyncRead(
                block: { transaction in
                    // TODO: remove this one TSAttachment is killed.
                    TSAttachment.anyEnumerate(transaction: transaction, batched: true) { (_, _) in
                        // no-op. It's sufficient to initWithCoder: each object.
                    }
                },
                completion: {
                    self.preferences.setHasGeneratedThumbnails(true)
                }
            )
        }

        checkDatabaseIntegrityIfNecessary(isRegistered: tsRegistrationState.isRegistered)

        SignalApp.shared.showLaunchInterface(launchInterface, launchStartedAt: launchContext.launchStartedAt)
    }

    private func scheduleBgAppRefresh() {
        MessageFetchBGRefreshTask.shared?.scheduleTask()
    }

    /// The user must unlock the device once after reboot before the database encryption key can be accessed.
    private func notifyThatPhoneMustBeUnlocked() -> Never {
        Logger.warn("Exiting because we are in the background and the database password is not accessible.")

        let notificationContent = UNMutableNotificationContent()
        notificationContent.body = String(
            format: OWSLocalizedString(
                "NOTIFICATION_BODY_PHONE_LOCKED_FORMAT",
                comment: "Lock screen notification text presented after user powers on their device without unlocking. Embeds {{device model}} (either 'iPad' or 'iPhone')"
            ),
            UIDevice.current.localizedModel
        )

        let notificationRequest = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notificationContent,
            trigger: nil
        )

        let application: UIApplication = .shared
        let userNotificationCenter: UNUserNotificationCenter = .current()

        userNotificationCenter.removeAllPendingNotificationRequests()
        application.applicationIconBadgeNumber = 0

        userNotificationCenter.add(notificationRequest)
        application.applicationIconBadgeNumber = 1

        // Wait a few seconds for XPC calls to finish and for rate limiting purposes.
        Thread.sleep(forTimeInterval: 3)
        Logger.flush()
        exit(0)
    }

    // MARK: - Registration

    private func buildLaunchInterface(regLoader: RegistrationCoordinatorLoader) -> LaunchInterface {
        let (
            tsRegistrationState,
            lastMode
        ) = databaseStorage.read { tx in
            return (
                DependenciesBridge.shared.tsAccountManager.registrationState(tx: tx.asV2Read),
                regLoader.restoreLastMode(transaction: tx.asV2Read)
            )
        }

        if let lastMode {
            Logger.info("Found ongoing registration; continuing")
            return .registration(regLoader, lastMode)
        }
        switch tsRegistrationState {
        case .registered, .provisioned:
            // We're already registered.
            return .chatList

        case .reregistering(let reregNumber, let reregAci):
            if let reregE164 = E164(reregNumber), let reregAci {
                Logger.info("Found legacy re-registration; continuing in new registration")
                // A user who started re-registration before the new
                // registration flow shipped; kick them to new re-reg.
                return .registration(regLoader, .reRegistering(.init(e164: reregE164, aci: reregAci)))
            } else {
                // If we're missing the e164 or aci, drop into normal reg.
                Logger.info("Found legacy initial registration; continuing in new registration")
                return .registration(regLoader, .registering)
            }

        case .relinking:
            return .secondaryProvisioning

        case .deregistered:
            // If we are deregistered, go to the chat list in the deregistered state.
            // The user can kick of re-registration from there, which will set the
            // 'lastMode' var and short circuit before we get here next time around.
            return .chatList

        case .delinked:
            // If we are delinked, go to the chat list in the delinked state.
            // The user can kick of re-linking from there.
            return .chatList

        case
                .transferringIncoming,
                .transferringPrimaryOutgoing,
                .transferringLinkedOutgoing,
                .transferred:
            fallthrough

        case .unregistered:
            if UIDevice.current.isIPad {
                return .secondaryProvisioning
            } else {
                return .registration(regLoader, .registering)
            }
        }
    }

    // MARK: - Launch Failures

    private var didAppLaunchFail: Bool = false {
        didSet {
            if !didAppLaunchFail {
                self.shouldKillAppWhenBackgrounded = false
            }
        }
    }

    private var shouldKillAppWhenBackgrounded: Bool = false

    private func checkIfAllowedToLaunch(
        mainAppContext: MainAppContext,
        appVersion: AppVersion,
        didDeviceTransferRestoreSucceed: Bool
    ) -> LaunchPreflightError? {
        guard checkSomeDiskSpaceAvailable() else {
            return .lowStorageSpaceAvailable
        }

        guard didDeviceTransferRestoreSucceed else {
            return .couldNotRestoreTransferredData
        }

        // Prevent:
        // * Users with an unknown GRDB schema revert to using an earlier GRDB schema.
        if SSKPreferences.hasUnknownGRDBSchema() {
            return .unknownDatabaseVersion
        }

        let userDefaults = mainAppContext.appUserDefaults()

        let databaseCorruptionState = DatabaseCorruptionState(userDefaults: userDefaults)
        switch databaseCorruptionState.status {
        case .notCorrupted, .readCorrupted:
            break
        case .corrupted, .corruptedButAlreadyDumpedAndRestored:
            guard !UIDevice.current.isIPad else {
                // Database recovery theoretically works on iPad,
                // but we haven't built the UI for it.
                return .databaseUnrecoverablyCorrupted
            }
            guard databaseCorruptionState.count <= 3 else {
                return .databaseUnrecoverablyCorrupted
            }
            return .databaseCorruptedAndMightBeRecoverable
        }

        let launchAttemptFailureThreshold = DebugFlags.betaLogging ? 2 : 3
        if
            appVersion.lastAppVersion == appVersion.currentAppVersion,
            userDefaults.integer(forKey: Constants.appLaunchesAttemptedKey) >= launchAttemptFailureThreshold
        {
            if case .readCorrupted = databaseCorruptionState.status {
                return .possibleReadCorruptionCrashed
            }
            return .lastAppLaunchCrashed
        }

        return nil
    }

    private func showPreflightErrorUI(
        _ preflightError: LaunchPreflightError,
        launchContext: LaunchContext,
        window: UIWindow,
        viewController: UIViewController
    ) {
        Logger.warn("preflightError: \(preflightError)")

        let title: String
        let message: String
        let actions: [LaunchFailureActionSheetAction]

        switch preflightError {
        case .databaseCorruptedAndMightBeRecoverable, .possibleReadCorruptionCrashed:
            presentDatabaseRecovery(
                from: viewController,
                launchContext: launchContext,
                window: window
            )
            return

        case .databaseUnrecoverablyCorrupted:
            presentDatabaseUnrecoverablyCorruptedError(
                from: viewController,
                action: .submitDebugLogsWithDatabaseIntegrityCheckAndCrash(databaseStorage: launchContext.databaseStorage)
            )
            return

        case .unknownDatabaseVersion:
            title = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_INVALID_DATABASE_VERSION_TITLE",
                comment: "Error indicating that the app could not launch without reverting unknown database migrations."
            )
            message = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_INVALID_DATABASE_VERSION_MESSAGE",
                comment: "Error indicating that the app could not launch without reverting unknown database migrations."
            )
            actions = [.submitDebugLogsAndCrash]

        case .couldNotRestoreTransferredData:
            title = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_RESTORE_FAILED_TITLE",
                comment: "Error indicating that the app could not restore transferred data."
            )
            message = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_RESTORE_FAILED_MESSAGE",
                comment: "Error indicating that the app could not restore transferred data."
            )
            actions = [.submitDebugLogsAndCrash]

        case .lastAppLaunchCrashed:
            title = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_LAST_LAUNCH_CRASHED_TITLE",
                comment: "Error indicating that the app crashed during the previous launch."
            )
            message = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_LAST_LAUNCH_CRASHED_MESSAGE",
                comment: "Error indicating that the app crashed during the previous launch."
            )
            actions = [
                .submitDebugLogsAndLaunchApp(window: window, launchContext: launchContext),
                .launchApp(window: window, launchContext: launchContext)
            ]

        case .lowStorageSpaceAvailable:
            shouldKillAppWhenBackgrounded = true
            title = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_LOW_STORAGE_SPACE_AVAILABLE_TITLE",
                comment: "Error title indicating that the app crashed because there was low storage space available on the device."
            )
            message = OWSLocalizedString(
                "APP_LAUNCH_FAILURE_LOW_STORAGE_SPACE_AVAILABLE_MESSAGE",
                comment: "Error description indicating that the app crashed because there was low storage space available on the device."
            )
            actions = []
        }

        presentLaunchFailureActionSheet(
            from: viewController,
            supportTag: preflightError.supportTag,
            title: title,
            message: message,
            actions: actions
        )
    }

    private func presentDatabaseRecovery(
        from viewController: UIViewController,
        launchContext: LaunchContext,
        window: UIWindow
    ) {
        var launchContext = launchContext
        let recoveryViewController = DatabaseRecoveryViewController<(AppSetup.FinalContinuation, NSObject)>(
            corruptDatabaseStorage: launchContext.databaseStorage,
            keychainStorage: launchContext.keychainStorage,
            setupSskEnvironment: { databaseStorage in
                firstly(on: DispatchQueue.main) {
                    launchContext.databaseStorage = databaseStorage
                    return self.setUpMainAppEnvironment(launchContext: launchContext)
                }
            },
            launchApp: { (finalContinuation, sleepBlockObject) in
                // Pretend we didn't fail!
                self.didAppLaunchFail = false
                self.configureGlobalUI(in: window)
                self.didLoadDatabase(
                    finalContinuation: finalContinuation,
                    launchContext: launchContext,
                    sleepBlockObject: sleepBlockObject,
                    window: window
                )
            }
        )

        // Prevent dismissal.
        recoveryViewController.isModalInPresentation = true

        // Show as a half-sheet on iOS 15+. On older versions, the sheet fills the screen, which is okay.
        if #available(iOS 15, *), let presentationController = recoveryViewController.presentationController as? UISheetPresentationController {
            presentationController.detents = [.medium()]
            presentationController.prefersEdgeAttachedInCompactHeight = true
            presentationController.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }

        viewController.present(recoveryViewController, animated: true)
    }

    private func presentDatabaseUnrecoverablyCorruptedError(
        from viewController: UIViewController,
        action: LaunchFailureActionSheetAction
    ) {
        presentLaunchFailureActionSheet(
            from: viewController,
            supportTag: LaunchPreflightError.databaseUnrecoverablyCorrupted.supportTag,
            title: OWSLocalizedString(
                "APP_LAUNCH_FAILURE_COULD_NOT_LOAD_DATABASE",
                comment: "Error indicating that the app could not launch because the database could not be loaded."
            ),
            message: OWSLocalizedString(
                "APP_LAUNCH_FAILURE_ALERT_MESSAGE",
                comment: "Default message for the 'app launch failed' alert."
            ),
            actions: [action]
        )
    }

    private enum LaunchFailureActionSheetAction {
        case submitDebugLogsAndCrash
        case submitDebugLogsAndLaunchApp(window: UIWindow, launchContext: LaunchContext)
        case submitDebugLogsWithDatabaseIntegrityCheckAndCrash(databaseStorage: SDSDatabaseStorage)
        case launchApp(window: UIWindow, launchContext: LaunchContext)
    }

    private func presentLaunchFailureActionSheet(
        from viewController: UIViewController,
        supportTag: String,
        title: String,
        message: String,
        actions: [LaunchFailureActionSheetAction]
    ) {
        let actionSheet = ActionSheetController(title: title, message: message)

        if DebugFlags.internalSettings {
            actionSheet.addAction(.init(title: "Export Database (internal)") { [unowned viewController] _ in
                SignalApp.showExportDatabaseUI(from: viewController) {
                    self.presentLaunchFailureActionSheet(
                        from: viewController,
                        supportTag: supportTag,
                        title: title,
                        message: message,
                        actions: actions
                    )
                }
            })
        }

        func addSubmitDebugLogsAction(handler: @escaping () -> Void) {
            let actionTitle = OWSLocalizedString("SETTINGS_ADVANCED_SUBMIT_DEBUGLOG", comment: "")
            actionSheet.addAction(.init(title: actionTitle) { _ in
                handler()
            })
        }

        func ignoreErrorAndLaunchApp(in window: UIWindow, launchContext: LaunchContext) {
            // Pretend we didn't fail!
            self.didAppLaunchFail = false
            window.rootViewController = LoadingViewController()
            self.launchApp(in: window, launchContext: launchContext)
        }

        for action in actions {
            switch action {
            case .submitDebugLogsAndCrash:
                addSubmitDebugLogsAction {
                    DebugLogs.submitLogsWithSupportTag(supportTag) {
                        owsFail("Exiting after submitting debug logs")
                    }
                }
            case .submitDebugLogsAndLaunchApp(let window, let launchContext):
                addSubmitDebugLogsAction { [unowned window] in
                    DebugLogs.submitLogsWithSupportTag(supportTag) {
                        ignoreErrorAndLaunchApp(in: window, launchContext: launchContext)
                    }
                }
            case .submitDebugLogsWithDatabaseIntegrityCheckAndCrash(let databaseStorage):
                addSubmitDebugLogsAction { [unowned viewController] in
                    SignalApp.showDatabaseIntegrityCheckUI(from: viewController, databaseStorage: databaseStorage) {
                        DebugLogs.submitLogsWithSupportTag(supportTag) {
                            owsFail("Exiting after submitting debug logs")
                        }
                    }
                }
            case .launchApp(let window, let launchContext):
                actionSheet.addAction(.init(
                    title: OWSLocalizedString(
                        "APP_LAUNCH_FAILURE_CONTINUE",
                        comment: "Button to try launching the app even though the last launch failed"
                    ),
                    style: .cancel, // Use a cancel-style button to draw attention.
                    handler: { [unowned window] _ in
                        ignoreErrorAndLaunchApp(in: window, launchContext: launchContext)
                    }
                ))
            }
        }

        viewController.presentActionSheet(actionSheet)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            // We need to respect the in-app notification sound preference. This method, which is called
            // for modern UNUserNotification users, could be a place to do that, but since we'd still
            // need to handle this behavior for legacy UINotification users anyway, we "allow" all
            // notification options here, and rely on the shared logic in NotificationPresenterImpl to
            // honor notification sound preferences for both modern and legacy users.
            let options: UNNotificationPresentationOptions = [.badge, .banner, .list, .sound]
            completionHandler(options)
        }
    }

    private func terminalErrorViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "Launch Screen", bundle: nil)
        guard let viewController = storyboard.instantiateInitialViewController() else {
            owsFail("No initial view controller")
        }
        return viewController
    }

    // MARK: - Activation

    private var hasActivated = false

    private func handleActivation() {
        AssertIsOnMainThread()

        defer {
            Logger.info("Synchronous handleActivation finished")
        }

        let tsRegistrationState: TSRegistrationState = DependenciesBridge.shared.db.read { tx in
            // Always check prekeys after app launches, and sometimes check on app activation.
            let registrationState = DependenciesBridge.shared.tsAccountManager.registrationState(tx: tx)
            if registrationState.isRegistered {
                DependenciesBridge.shared.preKeyManager.checkPreKeysIfNecessary(tx: tx)
            }
            return registrationState
        }

        if !hasActivated {
            hasActivated = true

            RTCInitializeSSL()

            // Clean up any messages that expired since last launch and continue
            // cleaning in the background.
            self.disappearingMessagesJob.startIfNecessary()

            if !tsRegistrationState.isRegistered {
                // Unregistered user should have no unread messages. e.g. if you delete your account.
                NSObject.notificationPresenter.clearAllNotifications()
            }
        }

        // Every time we become active...
        if tsRegistrationState.isRegistered {
            // At this point, potentially lengthy DB locking migrations could be running.
            // Avoid blocking app launch by putting all further possible DB access in async block
            DispatchQueue.main.async {
                AppEnvironment.shared.contactsManagerImpl.fetchSystemContactsOnceIfAlreadyAuthorized()

                // TODO: Should we run this immediately even if we would like to process
                // already decrypted envelopes handed to us by the NSE?
                self.messageFetcherJob.run()

                if !UIApplication.shared.isRegisteredForRemoteNotifications {
                    Logger.info("Retrying to register for remote notifications since user hasn't registered yet.")
                    // Push tokens don't normally change while the app is launched, so checking once during launch is
                    // usually sufficient, but e.g. on iOS11, users who have disabled "Allow Notifications" and disabled
                    // "Background App Refresh" will not be able to obtain an APN token. Enabling those settings does not
                    // restart the app, so we check every activation for users who haven't yet registered.
                    SyncPushTokensJob.run()
                }
            }
        }

        // We want to defer this so that we never call this method until
        // [UIApplicationDelegate applicationDidBecomeActive:] is complete.
        let identityManager = DependenciesBridge.shared.identityManager
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { identityManager.tryToSyncQueuedVerificationStates() }
    }

    // MARK: - Orientation

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if CurrentAppContext().isRunningTests || didAppLaunchFail {
            return .portrait
        }

        // The call-banner window is only suitable for portrait display on iPhone
        if CurrentAppContext().hasActiveCall, !UIDevice.current.isIPad {
            return .portrait
        }

        guard let rootViewController = self.window?.rootViewController else {
            return UIDevice.current.defaultSupportedOrientations
        }

        return rootViewController.supportedInterfaceOrientations
    }

    // MARK: - Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AssertIsOnMainThread()

        if didAppLaunchFail {
            return
        }

        Logger.info("")
        pushRegistrationManager.didReceiveVanillaPushToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AssertIsOnMainThread()

        if didAppLaunchFail {
            return
        }

        Logger.warn("")
        #if DEBUG
        pushRegistrationManager.didReceiveVanillaPushToken(Data(count: 32))
        #else
        pushRegistrationManager.didFailToReceiveVanillaPushToken(error: error)
        #endif
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        AssertIsOnMainThread()

        if DebugFlags.verboseNotificationLogging {
            Logger.info("")
        }

        // Mark down that the APNS token is working because we got a push.
        AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
            self.databaseStorage.asyncWrite { tx in
                APNSRotationStore.didReceiveAPNSPush(transaction: tx)
            }
        }

        processRemoteNotification(userInfo) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                completionHandler(.newData)
            }
        }
    }

    private enum HandleSilentPushContentResult {
        case handled
        case notHandled
    }

    // TODO: NSE Lifecycle, is this invoked when the NSE wakes the main app?
    private func processRemoteNotification(_ remoteNotification: [AnyHashable: Any], completion: @escaping () -> Void) {
        AssertIsOnMainThread()

        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            // TODO: Wait to invoke this until we've finished fetching messages.
            defer { completion() }

            switch self.handleSilentPushContent(remoteNotification) {
            case .handled:
                break
            case .notHandled:
                let tsAccountManager = DependenciesBridge.shared.tsAccountManager
                guard tsAccountManager.registrationStateWithMaybeSneakyTransaction.isRegistered else {
                    Logger.info("Ignoring remote notification; user is not registered.")
                    return
                }
                self.messageFetcherJob.run()
                // If the main app gets woken to process messages in the background, check
                // for any pending NSE requests to fulfill.
                _ = self.syncManager.syncAllContactsIfFullSyncRequested()
            }
        }
    }

    private func handleSilentPushContent(_ remoteNotification: [AnyHashable: Any]) -> HandleSilentPushContentResult {
        if let spamChallengeToken = remoteNotification["rateLimitChallenge"] as? String {
            spamChallengeResolver.handleIncomingPushChallengeToken(spamChallengeToken)
            return .handled
        }

        if let preAuthChallengeToken = remoteNotification["challenge"] as? String {
            pushRegistrationManager.didReceiveVanillaPreAuthChallengeToken(preAuthChallengeToken)
            return .handled
        }

        return .notHandled
    }

    private func clearAllNotificationsAndRestoreBadgeCount() {
        AssertIsOnMainThread()

        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            let oldBadgeValue = UIApplication.shared.applicationIconBadgeNumber
            NSObject.notificationPresenter.clearAllNotifications()
            UIApplication.shared.applicationIconBadgeNumber = oldBadgeValue
        }
    }

    // MARK: - Handoff

    /// Among other things, this is used by "call back" CallKit dialog and calling from the Contacts app.
    ///
    /// We always return true if we are going to try to handle the user activity
    /// since we never want iOS to contact us again using a URL.
    ///
    /// From https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623072-application?language=objc:
    ///
    /// If you do not implement this method or if your implementation returns
    /// false, iOS tries to create a document for your app to open using a URL.
    @available(iOS, deprecated: 13.0) // hack to mute deprecation warnings; this is not deprecated
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AssertIsOnMainThread()

        if didAppLaunchFail {
            return false
        }

        Logger.info("\(userActivity.activityType)")

        switch userActivity.activityType {
        case "INSendMessageIntent":
            let intent = userActivity.interaction?.intent
            guard let intent = intent as? INSendMessageIntent else {
                owsFailDebug("Wrong type for intent: \(type(of: intent))")
                return false
            }
            guard let threadUniqueId = intent.conversationIdentifier else {
                owsFailDebug("Missing threadUniqueId for intent")
                return false
            }
            AppReadiness.runNowOrWhenAppDidBecomeReadySync {
                let tsAccountManager = DependenciesBridge.shared.tsAccountManager
                guard tsAccountManager.registrationStateWithMaybeSneakyTransaction.isRegistered else {
                    Logger.warn("Ignoring user activity; not registered.")
                    return
                }
                SignalApp.shared.presentConversationAndScrollToFirstUnreadMessage(forThreadId: threadUniqueId, animated: false)
            }
            return true
        case "INStartVideoCallIntent":
            let intent = userActivity.interaction?.intent
            guard let intent = intent as? INStartVideoCallIntent else {
                owsFailDebug("Wrong type for intent: \(type(of: intent))")
                return false
            }
            guard let handle = intent.contacts?.first?.personHandle?.value else {
                owsFailDebug("Missing handle for intent")
                return false
            }
            AppReadiness.runNowOrWhenAppDidBecomeReadySync {
                let tsAccountManager = DependenciesBridge.shared.tsAccountManager
                guard tsAccountManager.registrationStateWithMaybeSneakyTransaction.isRegistered else {
                    Logger.warn("Ignoring user activity; not registered.")
                    return
                }
                guard let thread = CallKitCallManager.threadForHandleWithSneakyTransaction(handle) else {
                    Logger.warn("Ignoring user activity; unknown user.")
                    return
                }

                // This intent can be received from more than one user interaction.
                //
                // * It can be received if the user taps the "video" button in the CallKit UI for an
                //   an ongoing call.  If so, the correct response is to try to activate the local
                //   video for that call.
                // * It can be received if the user taps the "video" button for a contact in the
                //   contacts app.  If so, the correct response is to try to initiate a new call
                //   to that user - unless there already is another call in progress.
                let callService = AppEnvironment.shared.callService!
                if let currentCall = callService.currentCall {
                    if currentCall.isIndividualCall, thread.uniqueId == currentCall.thread.uniqueId {
                        Logger.info("Upgrading existing call to video")
                        callService.individualCallService.handleCallKitStartVideo()
                    } else {
                        Logger.warn("Ignoring user activity; on another call.")
                    }
                    return
                }
                callService.initiateCall(thread: thread, isVideo: true)
            }
            return true
        case "INStartAudioCallIntent":
            let intent = userActivity.interaction?.intent
            guard let intent = intent as? INStartAudioCallIntent else {
                owsFailDebug("Wrong type for intent: \(type(of: intent))")
                return false
            }
            guard let handle = intent.contacts?.first?.personHandle?.value else {
                owsFailDebug("Missing handle for intent")
                return false
            }
            AppReadiness.runNowOrWhenAppDidBecomeReadySync {
                let tsAccountManager = DependenciesBridge.shared.tsAccountManager
                guard tsAccountManager.registrationStateWithMaybeSneakyTransaction.isRegistered else {
                    Logger.warn("Ignoring user activity; not registered.")
                    return
                }
                guard let thread = CallKitCallManager.threadForHandleWithSneakyTransaction(handle) else {
                    Logger.warn("Ignoring user activity; unknown user.")
                    return
                }
                let callService = AppEnvironment.shared.callService!
                if callService.currentCall != nil {
                    Logger.warn("Ignoring user activity; on another call.")
                    return
                }
                callService.initiateCall(thread: thread, isVideo: false)
            }
            return true
        case "INStartCallIntent":
            let intent = userActivity.interaction?.intent
            guard let intent = intent as? INStartCallIntent else {
                owsFailDebug("Wrong type for intent: \(type(of: intent))")
                return false
            }
            guard let handle = intent.contacts?.first?.personHandle?.value else {
                owsFailDebug("Missing handle for intent")
                return false
            }
            let isVideo = intent.callCapability == .videoCall
            AppReadiness.runNowOrWhenAppDidBecomeReadySync {
                let tsAccountManager = DependenciesBridge.shared.tsAccountManager
                guard tsAccountManager.registrationStateWithMaybeSneakyTransaction.isRegistered else {
                    Logger.warn("Ignoring user activity; not registered.")
                    return
                }
                guard let thread = CallKitCallManager.threadForHandleWithSneakyTransaction(handle) else {
                    Logger.warn("Ignoring user activity; unknown user.")
                    return
                }
                let callService = AppEnvironment.shared.callService!
                if callService.currentCall != nil {
                    Logger.warn("Ignoring user activity; on another call.")
                    return
                }
                callService.initiateCall(thread: thread, isVideo: isVideo)
            }
            return true
        case NSUserActivityTypeBrowsingWeb:
            guard let webpageUrl = userActivity.webpageURL else {
                owsFailDebug("Missing webpageUrl.")
                return false
            }
            return handleOpenUrl(webpageUrl)
        default:
            return false
        }
    }

    // MARK: - Events

    @objc
    private func registrationStateDidChange() {
        AssertIsOnMainThread()

        Logger.info("")

        scheduleBgAppRefresh()

        let tsAccountManager = DependenciesBridge.shared.tsAccountManager
        let isRegistered = tsAccountManager.registrationStateWithMaybeSneakyTransaction.isRegistered
        if isRegistered {
            AppReadiness.runNowOrWhenAppDidBecomeReadySync {
                self.databaseStorage.write { transaction in
                    let localAddress = tsAccountManager.localIdentifiers(tx: transaction.asV2Read)?.aciAddress
                    Logger.info("localAddress: \(String(describing: localAddress))")

                    ExperienceUpgradeFinder.markAllCompleteForNewUser(transaction: transaction.unwrapGrdbWrite)
                }
            }
        }

        Self.updateApplicationShortcutItems(isRegistered: isRegistered)
    }

    // MARK: - Shortcut Items

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        AssertIsOnMainThread()

        if didAppLaunchFail {
            completionHandler(false)
            return
        }

        AppReadiness.runNowOrWhenUIDidBecomeReadySync {
            let tsAccountManager = DependenciesBridge.shared.tsAccountManager
            guard tsAccountManager.registrationStateWithMaybeSneakyTransaction.isRegistered else {
                let controller = ActionSheetController(
                    title: OWSLocalizedString("REGISTER_CONTACTS_WELCOME", comment: ""),
                    message: OWSLocalizedString("REGISTRATION_RESTRICTED_MESSAGE", comment: "")
                )
                controller.addAction(ActionSheetAction(title: CommonStrings.okButton))
                UIApplication.shared.frontmostViewController?.present(controller, animated: true, completion: {
                    completionHandler(false)
                })
                return
            }
            SignalApp.shared.showNewConversationView()
            completionHandler(true)
        }
    }

    public static func updateApplicationShortcutItems(isRegistered: Bool) {
        guard CurrentAppContext().isMainApp else { return }
        UIApplication.shared.shortcutItems = applicationShortcutItems(isRegistered: isRegistered)
    }

    static func applicationShortcutItems(isRegistered: Bool) -> [UIApplicationShortcutItem] {
        guard isRegistered else { return [] }
        return [.init(
            type: "\(Bundle.main.bundleIdPrefix).quickCompose",
            localizedTitle: OWSLocalizedString(
                "APPLICATION_SHORTCUT_NEW_MESSAGE",
                comment: "On the iOS home screen, if you tap and hold the Signal icon, this shortcut will appear. Tapping it will let users send a new message. You may want to refer to similar behavior in other iOS apps, such as Messages, for equivalent strings."
            ),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: .compose)
        )]
    }

    // MARK: - URL Handling

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AssertIsOnMainThread()
        return handleOpenUrl(url)
    }

    private func handleOpenUrl(_ url: URL) -> Bool {
        AssertIsOnMainThread()

        if didAppLaunchFail {
            return false
        }

        guard let parsedUrl = UrlOpener.parseUrl(url) else {
            return false
        }
        AppReadiness.runNowOrWhenUIDidBecomeReadySync {
            let urlOpener = UrlOpener(
                databaseStorage: self.databaseStorage,
                tsAccountManager: DependenciesBridge.shared.tsAccountManager
            )

            urlOpener.openUrl(parsedUrl, in: self.window!)
        }
        return true
    }

    // MARK: - Database integrity checks

    private func checkDatabaseIntegrityIfNecessary(
        isRegistered: Bool
    ) {
        guard isRegistered, FeatureFlags.periodicallyCheckDatabaseIntegrity else { return }

        DispatchQueue.sharedUtility.async { [databaseStorage] in
            switch GRDBDatabaseStorageAdapter.checkIntegrity(databaseStorage: databaseStorage) {
            case .ok: break
            case .notOk:
                AppReadiness.runNowOrWhenUIDidBecomeReadySync {
                    OWSActionSheets.showActionSheet(
                        title: "Database corrupted!",
                        message: "We have detected database corruption on your device. Please submit debug logs to the iOS team."
                    )
                }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // The method will be called on the delegate when the user responded to the notification by opening the application,
    // dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application
    // returns from application:didFinishLaunchingWithOptions:.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            NotificationActionHandler.handleNotificationResponse(response, completionHandler: completionHandler)
        }
    }
}
