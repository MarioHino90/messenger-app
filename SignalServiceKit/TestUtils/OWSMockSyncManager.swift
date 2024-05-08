//
// Copyright 2018 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalCoreKit

#if TESTABLE_BUILD

@objc
public class OWSMockSyncManager: NSObject, SyncManagerProtocol {
    @objc
    public func sendConfigurationSyncMessage() {
        Logger.info("")
    }

    @objc
    public func sendAllSyncRequestMessagesIfNecessary() -> AnyPromise {
        Logger.info("")

        return AnyPromise(Promise.value(()))
    }

    @objc
    public func sendAllSyncRequestMessages(timeout: TimeInterval) -> AnyPromise {
        Logger.info("")

        return AnyPromise(Promise.value(()))
    }

    public func sendFetchLatestProfileSyncMessage(tx: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func sendFetchLatestStorageManifestSyncMessage() {
        Logger.info("")
    }

    public func sendFetchLatestSubscriptionStatusSyncMessage() {
        Logger.info("")
    }

    public func sendKeysSyncMessage() {
        Logger.info("")
    }

    public func sendKeysSyncMessage(tx: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func processIncomingConfigurationSyncMessage(_ syncMessage: SSKProtoSyncMessageConfiguration, transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func processIncomingFetchLatestSyncMessage(_ syncMessage: SSKProtoSyncMessageFetchLatest, transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func processIncomingContactsSyncMessage(_ syncMessage: SSKProtoSyncMessageContacts, transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func processIncomingKeysSyncMessage(_ syncMessage: SSKProtoSyncMessageKeys, transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func sendKeysSyncRequestMessage(transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func processIncomingMessageRequestResponseSyncMessage(_ syncMessage: SSKProtoSyncMessageMessageRequestResponse, transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    public func sendMessageRequestResponseSyncMessage(thread: TSThread, responseType: OWSSyncMessageRequestResponseType) {
        Logger.info("")
    }

    public func sendMessageRequestResponseSyncMessage(thread: TSThread, responseType: OWSSyncMessageRequestResponseType, transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    @objc
    public func syncAllContacts() -> AnyPromise {
        Logger.info("")

        return AnyPromise()
    }

    @objc
    public func syncAllContactsIfFullSyncRequested() -> AnyPromise {
        Logger.info("")

        return AnyPromise()
    }
}

#endif
