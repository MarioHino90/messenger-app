//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

// MARK: - Enqueue messages

public final class ThreadUtil: Dependencies {

    public typealias PersistenceCompletion = () -> Void

    // A serial queue that ensures that messages are sent in the
    // same order in which they are enqueued.
    public static var enqueueSendQueue: DispatchQueue { .sharedUserInitiated }

    public static func enqueueSendAsyncWrite(_ block: @escaping (SDSAnyWriteTransaction) -> Void) {
        enqueueSendQueue.async {
            Self.databaseStorage.write { transaction in
                block(transaction)
            }
        }
    }

    private static func applyDisappearingMessagesConfiguration(to builder: TSOutgoingMessageBuilder, tx: DBReadTransaction) {
        let dmConfigurationStore = DependenciesBridge.shared.disappearingMessagesConfigurationStore
        builder.expiresInSeconds = dmConfigurationStore.durationSeconds(for: builder.thread, tx: tx)
    }

    public class func enqueueMessagePromise(
        message: PreparedOutgoingMessage,
        limitToCurrentProcessLifetime: Bool = false,
        isHighPriority: Bool = false,
        transaction: SDSAnyWriteTransaction
    ) -> Promise<Void> {
        let promise = SSKEnvironment.shared.messageSenderJobQueueRef.add(
            .promise,
            message: message,
            limitToCurrentProcessLifetime: limitToCurrentProcessLifetime,
            isHighPriority: isHighPriority,
            transaction: transaction
        )
        if let messageForIntent = message.messageForIntentDonation(tx: transaction) {
            messageForIntent.thread(tx: transaction)?.donateSendMessageIntent(for: messageForIntent, transaction: transaction)
        }
        return promise
    }
}

// MARK: - Contact Shares

public extension ThreadUtil {

    @discardableResult
    class func enqueueMessage(
        withContactShare contactShareDraft: ContactShareDraft,
        thread: TSThread
    ) -> TSOutgoingMessage {
        AssertIsOnMainThread()
        assert(contactShareDraft.ows_isValid)

        let builder = TSOutgoingMessageBuilder(thread: thread)

        let message: TSOutgoingMessage = databaseStorage.read { tx in
            applyDisappearingMessagesConfiguration(to: builder, tx: tx.asV2Read)
            return builder.build(transaction: tx)
        }

        let unpreparedMessage = UnpreparedOutgoingMessage.forMessage(
            message,
            contactShareDraft: contactShareDraft
        )

        Self.enqueueSendAsyncWrite { transaction in
            guard let preparedMessage = try? unpreparedMessage.prepare(tx: transaction) else {
                owsFailDebug("Unable to build message for sending!")
                return
            }
            SSKEnvironment.shared.messageSenderJobQueueRef.add(message: preparedMessage, transaction: transaction)
            if
                let messageForIntent = preparedMessage.messageForIntentDonation(tx: transaction),
                let thread = messageForIntent.thread(tx: transaction)
            {
                thread.donateSendMessageIntent(for: messageForIntent, transaction: transaction)
            }
        }

        return message
    }
}

// MARK: - Stickers

public extension ThreadUtil {

    @discardableResult
    class func enqueueMessage(withInstalledSticker stickerInfo: StickerInfo, thread: TSThread) -> TSOutgoingMessage {
        AssertIsOnMainThread()

        let builder = TSOutgoingMessageBuilder.outgoingMessageBuilder(thread: thread)
        let message = databaseStorage.read { tx in
            applyDisappearingMessagesConfiguration(to: builder, tx: tx.asV2Read)
            return builder.build(transaction: tx)
        }

        enqueueSendAsyncWrite { tx in
            guard let stickerMetadata = StickerManager.installedStickerMetadata(stickerInfo: stickerInfo, transaction: tx) else {
                owsFailDebug("Could not find sticker file.")
                return
            }

            guard let stickerData = try? Data(contentsOf: stickerMetadata.stickerDataUrl) else {
                owsFailDebug("Couldn't load sticker data.")
                return
            }

            let stickerDraft = MessageStickerDraft(
                info: stickerInfo,
                stickerData: stickerData,
                stickerType: stickerMetadata.stickerType,
                emoji: stickerMetadata.firstEmoji
            )
            self.enqueueMessage(message, stickerDraft: stickerDraft, thread: thread, tx: tx)
        }

        return message
    }

    @discardableResult
    class func enqueueMessage(
        withUninstalledSticker stickerMetadata: StickerMetadata,
        stickerData: Data,
        thread: TSThread
    ) -> TSOutgoingMessage {
        AssertIsOnMainThread()

        let builder = TSOutgoingMessageBuilder.outgoingMessageBuilder(thread: thread)
        let message = databaseStorage.read { tx in
            applyDisappearingMessagesConfiguration(to: builder, tx: tx.asV2Read)
            return builder.build(transaction: tx)
        }

        let stickerDraft = MessageStickerDraft(
            info: stickerMetadata.stickerInfo,
            stickerData: stickerData,
            stickerType: stickerMetadata.stickerType,
            emoji: stickerMetadata.firstEmoji
        )

        enqueueSendAsyncWrite { tx in
            self.enqueueMessage(message, stickerDraft: stickerDraft, thread: thread, tx: tx)
        }

        return message
    }

    private class func enqueueMessage(
        _ message: TSOutgoingMessage,
        stickerDraft: MessageStickerDraft,
        thread: TSThread,
        tx: SDSAnyWriteTransaction
    ) {
        AssertNotOnMainThread()

        let unpreparedMessage = UnpreparedOutgoingMessage.forMessage(
            message,
            messageStickerDraft: stickerDraft
        )
        let preparedMessage: PreparedOutgoingMessage
        do {
            preparedMessage = try unpreparedMessage.prepare(tx: tx)
        } catch {
            return owsFailDebug("Couldn't prepare message: \(error)")
        }

        SSKEnvironment.shared.messageSenderJobQueueRef.add(message: preparedMessage, transaction: tx)

        if let messageForIntent = preparedMessage.messageForIntentDonation(tx: tx) {
            thread.donateSendMessageIntent(for: messageForIntent, transaction: tx)
        }
    }
}

// MARK: - Profile Whitelist

extension ThreadUtil {
    private static func shouldSetUniversalTimer(for thread: TSThread, tx: SDSAnyReadTransaction) -> Bool {
        ThreadFinder().shouldSetDefaultDisappearingMessageTimer(thread: thread, transaction: tx)
    }

    private static func setUniversalTimer(for thread: TSThread, tx: SDSAnyWriteTransaction) {
        let dmConfigurationStore = DependenciesBridge.shared.disappearingMessagesConfigurationStore
        let dmUniversalToken = dmConfigurationStore.fetchOrBuildDefault(for: .universal, tx: tx.asV2Read).asToken
        let dmResult = dmConfigurationStore.set(token: dmUniversalToken, for: .thread(thread), tx: tx.asV2Write)
        OWSDisappearingConfigurationUpdateInfoMessage(
            thread: thread,
            configuration: dmResult.newConfiguration,
            createdByRemoteName: nil,
            createdInExistingGroup: false
        ).anyInsert(transaction: tx)
    }

    private static func shouldAddThreadToProfileWhitelist(_ thread: TSThread, tx: SDSAnyReadTransaction) -> Bool {
        let hasPendingMessageRequest = thread.hasPendingMessageRequest(transaction: tx)

        // If we're creating this thread or we have a pending message request,
        // any action we trigger should share our profile.
        return !thread.shouldThreadBeVisible || hasPendingMessageRequest
    }

    @discardableResult
    public class func addThreadToProfileWhitelistIfEmptyOrPendingRequestAndSetDefaultTimerWithSneakyTransaction(
        _ thread: TSThread
    ) -> Bool {
        let (shouldSetUniversalTimer, shouldAddToProfileWhitelist) = databaseStorage.read { tx in
            (Self.shouldSetUniversalTimer(for: thread, tx: tx), shouldAddThreadToProfileWhitelist(thread, tx: tx))
        }
        if shouldSetUniversalTimer {
            databaseStorage.write { tx in setUniversalTimer(for: thread, tx: tx) }
        }
        if shouldAddToProfileWhitelist {
            databaseStorage.write { tx in profileManager.addThread(toProfileWhitelist: thread, transaction: tx) }
        }
        return shouldAddToProfileWhitelist
    }

    @discardableResult
    public class func addThreadToProfileWhitelistIfEmptyOrPendingRequest(
        _ thread: TSThread,
        setDefaultTimerIfNecessary: Bool,
        tx: SDSAnyWriteTransaction
    ) -> Bool {
        if shouldSetUniversalTimer(for: thread, tx: tx) {
            setUniversalTimer(for: thread, tx: tx)
        }
        let shouldAddToProfileWhitelist = shouldAddThreadToProfileWhitelist(thread, tx: tx)
        if shouldAddToProfileWhitelist {
            profileManager.addThread(toProfileWhitelist: thread, transaction: tx)
        }
        return shouldAddToProfileWhitelist
    }
}

// MARK: - Delete all content

extension ThreadUtil {
    public static func deleteAllContentWithSneakyTransaction() {
        Logger.info("")

        databaseStorage.write { transaction in
            TSThread.anyEnumerate(transaction: transaction, batched: true) { thread, _ in
                thread.softDelete(with: transaction)
            }

            TSInteraction.anyRemoveAllWithInstantiation(transaction: transaction)
            StoryMessage.anyRemoveAllWithInstantiation(transaction: transaction)
            TSAttachment.anyRemoveAllWithInstantiation(transaction: transaction)

            // Deleting attachments above should be enough to remove any gallery items, but
            // we redunantly clean up *all* gallery items to be safe.
            MediaGalleryRecordManager.didRemoveAllContent(transaction: transaction)
        }

        TSAttachmentStream.deleteAttachmentsFromDisk()
    }
}

// MARK: - Sharing Suggestions

import Intents

extension TSThread {

    /// This function should be called every time the user
    /// initiates message sending via the UI. It should *not*
    /// be called for messages we send automatically, like
    /// receipts.
    public func donateSendMessageIntent(for outgoingMessage: TSOutgoingMessage, transaction: SDSAnyReadTransaction) {
        // Never donate for story sends or replies, we don't want them as share suggestions
        guard
            !(outgoingMessage is OutgoingStoryMessage),
            !outgoingMessage.isGroupStoryReply
        else {
            return
        }

        guard SSKPreferences.areIntentDonationsEnabled(transaction: transaction) else { return }
        guard let sendMessageIntent = generateSendMessageIntent(context: .outgoingMessage(outgoingMessage), transaction: transaction) else { return }

        let interaction = INInteraction(intent: sendMessageIntent, response: nil)
        interaction.groupIdentifier = uniqueId
        interaction.direction = .outgoing
        interaction.donate(completion: { error in
            guard let error = error else { return }
            owsFailDebug("Failed to donate message intent for \(self.uniqueId) \(error)")
        })
    }

    public enum IntentContext {
        case senderAddress(SignalServiceAddress)
        case incomingMessage(TSIncomingMessage)
        case outgoingMessage(TSOutgoingMessage)
    }

    public func generateSendMessageIntent(context: IntentContext, transaction: SDSAnyReadTransaction) -> INSendMessageIntent? {
        guard SSKPreferences.areIntentDonationsEnabled(transaction: transaction) else { return nil }

        guard let localAddress = DependenciesBridge.shared.tsAccountManager.localIdentifiers(tx: transaction.asV2Read)?.aciAddress else {
            owsFailDebug("Missing local address")
            return nil
        }

        let senderAddress: SignalServiceAddress
        let message: TSMessage?
        let recipients: [INPerson]?
        switch context {
        case .outgoingMessage(let outgoingMessage):
            senderAddress = localAddress
            message = outgoingMessage

            // For 1:1 outgoing messages, we must populate the recipient of the message,
            // otherwise sharing suggestions won't be populated correctly.
            if !isGroupThread {
                recipients = outgoingMessage.recipientAddresses().map { inPersonForRecipient($0, transaction: transaction) }
            } else {
                recipients = nil
            }
        case .incomingMessage(let incomingMessage):
            senderAddress = incomingMessage.authorAddress
            message = incomingMessage
            recipients = nil
        case .senderAddress(let address):
            senderAddress = address
            message = nil
            recipients = nil
        }

        var conversationIdentifier = uniqueId
        var threadName = contactsManager.displayName(for: self, transaction: transaction)
        if isGroupThread && message?.isGroupStoryReply == true {
            threadName = String(
                format: OWSLocalizedString(
                    "QUOTED_REPLY_STORY_AUTHOR_INDICATOR_FORMAT",
                    comment: "Message header when you are quoting a story. Embeds {{ story author name }}"
                ),
                threadName
            )

            // Uniquely namespace the notifications for group stories.
            conversationIdentifier += "_groupStory"
        }
        let inSender = inPersonForRecipient(senderAddress, transaction: transaction)

        let sendMessageIntent = INSendMessageIntent(
            recipients: recipients,
            outgoingMessageType: .outgoingMessageText,
            content: nil,
            speakableGroupName: isGroupThread ? INSpeakableString(spokenPhrase: threadName) : nil,
            conversationIdentifier: conversationIdentifier,
            serviceName: nil,
            sender: inSender,
            attachments: nil
        )

        if isGroupThread {
            if #available(iOS 15, *) {
                let donationMetadata = INSendMessageIntentDonationMetadata()
                donationMetadata.recipientCount = recipientAddresses(with: transaction).count

                if let message = message {
                    let mentionedAddresses = MentionFinder.mentionedAddresses(for: message, transaction: transaction.unwrapGrdbRead)
                    donationMetadata.mentionsCurrentUser = mentionedAddresses.contains(localAddress)
                    donationMetadata.isReplyToCurrentUser = message.quotedMessage?.authorAddress.isEqualToAddress(localAddress) ?? false
                }

                sendMessageIntent.donationMetadata = donationMetadata
            }

            if let image = intentThreadAvatarImage(transaction: transaction) {
                sendMessageIntent.setImage(image, forParameterNamed: \.speakableGroupName)
            }
        }

        return sendMessageIntent
    }

    public func generateIncomingCallIntent(callerAddress: SignalServiceAddress) -> INIntent? {
        databaseStorage.read { transaction in
            guard !self.isGroupThread else {
                // Fall back to a "send message" intent for group calls,
                // because the "start call" intent makes the notification look too much like a 1:1 call.
                return self.generateSendMessageIntent(context: .senderAddress(callerAddress),
                                                      transaction: transaction)
            }

            guard SSKPreferences.areIntentDonationsEnabled(transaction: transaction) else { return nil }

            let caller = inPersonForRecipient(callerAddress, transaction: transaction)

            let startCallIntent = INStartCallIntent(audioRoute: .unknown,
                                                    destinationType: .normal,
                                                    contacts: [caller],
                                                    recordTypeForRedialing: .unknown,
                                                    callCapability: .unknown)

            return startCallIntent
        }
    }

    private func inPersonForRecipient(
        _ recipient: SignalServiceAddress,
        transaction: SDSAnyReadTransaction
    ) -> INPerson {

        // Generate recipient name
        let displayName = contactsManager.displayName(for: recipient, tx: transaction)

        let nameComponents: PersonNameComponents?
        switch displayName {
        case .nickname(let nickname):
            nameComponents = nickname.nameComponents
        case .systemContactName(let systemContactName):
            nameComponents = systemContactName.nameComponents
        case .profileName(let profileNameComponents):
            nameComponents = profileNameComponents
        case .phoneNumber, .username, .deletedAccount, .unknown:
            nameComponents = nil
        }

        var filteredNameComponents = PersonNameComponents()
        filteredNameComponents.givenName = nameComponents?.givenName?.filterForDisplay
        filteredNameComponents.familyName = nameComponents?.familyName?.filterForDisplay
        filteredNameComponents.nickname = nameComponents?.nickname?.filterForDisplay

        // Generate contact handle
        let handle: INPersonHandle
        let suggestionType: INPersonSuggestionType
        if let phoneNumber = recipient.phoneNumber {
            handle = INPersonHandle(value: phoneNumber, type: .phoneNumber, label: nil)
            suggestionType = .none
        } else {
            handle = INPersonHandle(value: recipient.serviceIdUppercaseString, type: .unknown, label: nil)
            suggestionType = .instantMessageAddress
        }

        // Generate avatar
        let image = intentRecipientAvatarImage(recipient: recipient, transaction: transaction)
        if #available(iOS 15, *) {
            return INPerson(personHandle: handle, nameComponents: nameComponents, displayName: displayName.resolvedValue(), image: image, contactIdentifier: nil, customIdentifier: nil, isMe: false, suggestionType: suggestionType)
        } else {
            return INPerson(personHandle: handle, nameComponents: nameComponents, displayName: displayName.resolvedValue(), image: image, contactIdentifier: nil, customIdentifier: nil, isMe: false)
        }
    }

    // Use the same point size as chat list avatars, so it's likely cached and ready for the NSE.
    // The NSE cannot read the device scale, so we rely on a cached scale to correctly calculate
    // the appropriate pixel size for our avatars.
    private static let intentAvatarDiameterPixels: CGFloat = 56 * preferences.cachedDeviceScale

    public func intentStoryAvatarImage(tx: SDSAnyReadTransaction) -> INImage? {
        if let storyThread = self as? TSPrivateStoryThread {
            if storyThread.isMyStory {
                guard let localAddress = DependenciesBridge.shared.tsAccountManager.localIdentifiers(tx: tx.asV2Read)?.aciAddress else {
                    Logger.warn("Missing local address")
                    return nil
                }
                return intentRecipientAvatarImage(recipient: localAddress, transaction: tx)
            } else {
                let rawImage = UIImage(named: "custom-story-light-36")
                return rawImage?.pngData().map(INImage.init(imageData:))
            }
        } else {
            return intentThreadAvatarImage(transaction: tx)
        }
    }

    private func intentRecipientAvatarImage(recipient: SignalServiceAddress, transaction: SDSAnyReadTransaction) -> INImage? {
        // Generate avatar
        let image: INImage
        if let contactAvatar = avatarBuilder.avatarImage(
            forAddress: recipient,
            diameterPixels: Self.intentAvatarDiameterPixels,
            localUserDisplayMode: .asUser,
            transaction: transaction
        ),
           let contactAvatarPNG = contactAvatar.pngData() {
            image = INImage(imageData: contactAvatarPNG)
        } else {
            image = INImage(named: "profile-placeholder-56")
        }
        return image
    }

    private func intentThreadAvatarImage(transaction: SDSAnyReadTransaction) -> INImage? {
        let image: INImage
        if let threadAvatar = avatarBuilder.avatarImage(
            forThread: self,
            diameterPixels: Self.intentAvatarDiameterPixels,
            localUserDisplayMode: .noteToSelf,
            transaction: transaction
        ),
           let threadAvatarPng = threadAvatar.pngData() {
            image = INImage(imageData: threadAvatarPng)
        } else {
            image = INImage(named: isGroupThread ? "group-placeholder-56" : "profile-placeholder-56")
        }
        return image
    }
}
