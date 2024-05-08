//
// Copyright 2021 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import LibSignalClient
import SignalCoreKit

public protocol ChatConnectionManager {
    func waitForIdentifiedConnectionToOpen() async throws
    var identifiedConnectionState: OWSChatConnectionState { get }
    var hasEmptiedInitialQueue: Bool { get }

    func canMakeRequests(connectionType: OWSChatConnectionType) -> Bool
    func makeRequest(_ request: TSRequest) async throws -> HTTPResponse

    func didReceivePush()
}

public class ChatConnectionManagerImpl: ChatConnectionManager {
    private let connectionIdentified: OWSChatConnection
    private let connectionUnidentified: OWSChatConnection
    private var connections: [OWSChatConnection] { [ connectionIdentified, connectionUnidentified ]}

    public init(appExpiry: AppExpiry, db: DB, libsignalNet: Net, userDefaults: UserDefaults) {
        AssertIsOnMainThread()

        connectionIdentified = OWSChatConnectionUsingSSKWebSocket(
            type: .identified,
            appExpiry: appExpiry,
            db: db
        )

        let chatService = libsignalNet.createChatService(username: "", password: "")
        if userDefaults.bool(forKey: Self.shouldUseLibsignalDefaultsKey) {
            connectionUnidentified = OWSChatConnectionUsingLibSignal(chatService: chatService, type: .unidentified, appExpiry: appExpiry, db: db)
        } else if userDefaults.bool(forKey: Self.enableShadowingDefaultsKey) {
            let shadowingConnection = OWSChatConnectionWithLibSignalShadowing(
                chatService: chatService,
                type: .unidentified,
                appExpiry: appExpiry,
                db: db,
                shadowingFrequency: 0.0
            )
            // RemoteConfig isn't available while we're still setting up singletons,
            // so we might not shadow the first few requests.
            AppReadiness.runNowOrWhenAppDidBecomeReadyAsync {
                let frequency = RemoteConfig.experimentalTransportShadowingHigh ? 1.0 : 0.1
                Logger.info("Using unauth OWSChatConnectionWithLibSignalShadowing, shadowing frequency \(frequency)")
                shadowingConnection.updateShadowingFrequency(frequency)
            }
            connectionUnidentified = shadowingConnection
        } else {
            connectionUnidentified = OWSChatConnectionUsingSSKWebSocket(type: .unidentified, appExpiry: appExpiry, db: db)
        }

        SwiftSingletons.register(self)
    }

    private func connection(ofType type: OWSChatConnectionType) -> OWSChatConnection {
        switch type {
        case .identified:
            return connectionIdentified
        case .unidentified:
            return connectionUnidentified
        }
    }

    public func canMakeRequests(connectionType: OWSChatConnectionType) -> Bool {
        connection(ofType: connectionType).canMakeRequests
    }

    public typealias RequestSuccess = OWSChatConnection.RequestSuccess
    public typealias RequestFailure = OWSChatConnection.RequestFailure

    public func waitForIdentifiedConnectionToOpen() async throws {
        try await self.connectionIdentified.waitForOpen()
    }

    private func waitForSocketToOpenIfItShouldBeOpen(
        connectionType: OWSChatConnectionType
    ) async {
        let connection = self.connection(ofType: connectionType)
        guard connection.shouldSocketBeOpen else {
            // The socket wants to be open, but isn't.
            // Proceed even though we will probably fail.
            return
        }
        // After 30 seconds, we try anyways. We'll probably fail.
        let maxWaitInterval = 30 * kSecondInterval
        return await withTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            // For both tasks, treat cancellation as success (or at least "go ahead").
            group.addTask {
                _ = try? await connection.waitForOpen()
            }
            group.addTask {
                _ = try? await Task.sleep(nanoseconds: UInt64(maxWaitInterval) * NSEC_PER_SEC)
            }
            await group.next()!
        }
    }

    // This method can be called from any thread.
    public func makeRequest(_ request: TSRequest) async throws -> HTTPResponse {
        let connectionType: OWSChatConnectionType = {
            if request.isUDRequest {
                return .unidentified
            } else if !request.shouldHaveAuthorizationHeaders {
                return .unidentified
            } else {
                return .identified
            }
        }()

        // connectionType, isUDRequest and shouldHaveAuthorizationHeaders
        // should be (mostly?) aligned.
        switch connectionType {
        case .identified:
            owsAssertDebug(!request.isUDRequest)
            owsAssertDebug(request.shouldHaveAuthorizationHeaders)
            if request.isUDRequest || !request.shouldHaveAuthorizationHeaders {
                Logger.info("request: \(request.description), isUDRequest: \(request.isUDRequest), shouldHaveAuthorizationHeaders: \(request.shouldHaveAuthorizationHeaders)")
            }
        case .unidentified:
            owsAssertDebug(request.isUDRequest || !request.shouldHaveAuthorizationHeaders)
            if !request.isUDRequest && request.shouldHaveAuthorizationHeaders {
                Logger.info("request: \(request.description), isUDRequest: \(request.isUDRequest), shouldHaveAuthorizationHeaders: \(request.shouldHaveAuthorizationHeaders)")
            }
        }

        // Request that the websocket open to make this request, if necessary.
        let unsubmittedRequestToken = connection(ofType: connectionType).makeUnsubmittedRequestToken()

        await self.waitForSocketToOpenIfItShouldBeOpen(connectionType: connectionType)

        return try await connection(ofType: connectionType).makeRequest(request, unsubmittedRequestToken: unsubmittedRequestToken)
    }

    // This method can be called from any thread.
    public func didReceivePush() {
        for connection in connections {
            connection.didReceivePush()
        }
    }

    public var identifiedConnectionState: OWSChatConnectionState {
        connectionIdentified.currentState
    }

    public var hasEmptiedInitialQueue: Bool {
        connectionIdentified.hasEmptiedInitialQueue
    }

    // MARK: -

    private static var enableShadowingDefaultsKey: String = "EnableShadowingForUnidentifiedWebsocket"

    /// We cache this in UserDefaults because it's used too early to access the RemoteConfig object.
    static func saveEnableShadowingForUnidentifiedWebsocket(
        _ enableShadowingForUnidentifiedWebsocket: Bool,
        in defaults: UserDefaults
    ) {
        defaults.set(enableShadowingForUnidentifiedWebsocket, forKey: enableShadowingDefaultsKey)
    }

    private static var shouldUseLibsignalDefaultsKey: String = "UseLibsignalForUnidentifiedWebsocket"

    /// We cache this in UserDefaults because it's used too early to access the RemoteConfig object.
    ///
    /// It also makes it possible to override the setting in Xcode via the Scheme settings:
    /// add the arguments "-UseLibsignalForUnidentifiedWebsocket YES" to the invocation of the app.
    static func saveShouldUseLibsignalForUnidentifiedWebsocket(
        _ shouldUseLibsignalForUnidentifiedWebsocket: Bool,
        in defaults: UserDefaults
    ) {
        defaults.set(shouldUseLibsignalForUnidentifiedWebsocket, forKey: shouldUseLibsignalDefaultsKey)
    }
}

#if TESTABLE_BUILD

public class ChatConnectionManagerMock: ChatConnectionManager {

    public init() {}

    public var hasEmptiedInitialQueue: Bool = false

    public func waitForIdentifiedConnectionToOpen() async throws {
    }

    public var identifiedConnectionState: OWSChatConnectionState = .closed

    public var canMakeRequestsPerType = [OWSChatConnectionType: Bool]()

    public func canMakeRequests(connectionType: OWSChatConnectionType) -> Bool {
        return canMakeRequestsPerType[connectionType] ?? true
    }

    public var requestHandler: (_ request: TSRequest) async throws -> HTTPResponse = { _ in
        fatalError("must override for tests")
    }

    public func makeRequest(_ request: TSRequest) async throws -> HTTPResponse {
        return try await requestHandler(request)
    }

    public func didReceivePush() {
        // Do nothing
    }
}

#endif
