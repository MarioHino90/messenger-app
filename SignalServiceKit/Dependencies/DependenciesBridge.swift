//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalCoreKit

/// Temporary bridge between [legacy code that uses global accessors for manager instances]
/// and [new code that expects references to instances to be explicitly passed around].
///
/// Ideally, all references to dependencies (singletons or otherwise) are passed to a class
/// in its initializer. Most existing code is not written that way, and expects to pull dependencies
/// from global static state (e.g. `SSKEnvironment` and `Dependencies`)
///
/// This lets you put off piping through references many layers deep to the usage site,
/// and access global state but with a few advantages over legacy methods:
/// 1) Not a protocol + extension; you must explicitly access members via the shared instance
/// 2) Swift-only, no need for @objc
/// 3) Classes within this container should themselves adhere to modern design principles: NOT accessing
///   global state or `Dependencies`, being protocolized, taking all dependencies
///   explicitly on initialization, and encapsulated for easy testing.
///
/// It is preferred **NOT** to use this class, and to take dependencies on init instead, but it is
/// better to use this class than to use `Dependencies`.
public class DependenciesBridge {

    /// Only available after calling `setupSingleton(...)`.
    public static var shared: DependenciesBridge {
        guard let _shared else {
            owsFail("DependenciesBridge has not yet been set up!")
        }

        return _shared
    }
    private static var _shared: DependenciesBridge?

    static func setShared(_ dependenciesBridge: DependenciesBridge) {
        Self._shared = dependenciesBridge
    }

    public let accountAttributesUpdater: AccountAttributesUpdater
    public let appExpiry: AppExpiry
    public let attachmentCloner: SignalAttachmentCloner
    public let attachmentDownloadManager: AttachmentDownloadManager
    public let attachmentManager: AttachmentManager
    public let attachmentStore: AttachmentStore
    public let attachmentUploadManager: AttachmentUploadManager
    public let audioWaveformManager: AudioWaveformManager
    public let authorMergeHelper: AuthorMergeHelper
    public let badgeCountFetcher: BadgeCountFetcher
    public let callRecordDeleteManager: CallRecordDeleteManager
    public let callRecordMissedCallManager: CallRecordMissedCallManager
    public let callRecordQuerier: CallRecordQuerier
    public let callRecordStore: CallRecordStore
    public let changePhoneNumberPniManager: ChangePhoneNumberPniManager
    public let chatColorSettingStore: ChatColorSettingStore
    public let contactShareManager: ContactShareManager
    public let db: DB
    public let deletedCallRecordCleanupManager: DeletedCallRecordCleanupManager
    let deletedCallRecordStore: DeletedCallRecordStore
    public let deviceManager: OWSDeviceManager
    public let deviceStore: OWSDeviceStore
    public let disappearingMessagesConfigurationStore: DisappearingMessagesConfigurationStore
    public let editManager: EditManager
    public let editMessageStore: EditMessageStore
    public let externalPendingIDEALDonationStore: ExternalPendingIDEALDonationStore
    public let groupCallRecordManager: GroupCallRecordManager
    public let groupMemberStore: GroupMemberStore
    public let groupMemberUpdater: GroupMemberUpdater
    public let groupUpdateInfoMessageInserter: GroupUpdateInfoMessageInserter
    public let identityManager: OWSIdentityManager
    public let inactiveLinkedDeviceFinder: InactiveLinkedDeviceFinder
    let incomingCallEventSyncMessageManager: IncomingCallEventSyncMessageManager
    let incomingCallLogEventSyncMessageManager: IncomingCallLogEventSyncMessageManager
    public let incomingPniChangeNumberProcessor: IncomingPniChangeNumberProcessor
    public let individualCallRecordManager: IndividualCallRecordManager
    public let interactionStore: InteractionStore
    public let keyValueStoreFactory: KeyValueStoreFactory
    public let learnMyOwnPniManager: LearnMyOwnPniManager
    public let linkedDevicePniKeyManager: LinkedDevicePniKeyManager
    public let linkPreviewManager: LinkPreviewManager
    let localProfileChecker: LocalProfileChecker
    public let localUsernameManager: LocalUsernameManager
    public let masterKeySyncManager: MasterKeySyncManager
    public let mediaBandwidthPreferenceStore: MediaBandwidthPreferenceStore
    public let mediaGalleryResourceManager: MediaGalleryResourceManager
    public let messageBackupManager: MessageBackupManager
    public let messageStickerManager: MessageStickerManager
    public let nicknameManager: any NicknameManager
    public let phoneNumberDiscoverabilityManager: PhoneNumberDiscoverabilityManager
    public let phoneNumberVisibilityFetcher: any PhoneNumberVisibilityFetcher
    public let pinnedThreadManager: PinnedThreadManager
    public let pinnedThreadStore: PinnedThreadStore
    public let pniHelloWorldManager: PniHelloWorldManager
    public let preKeyManager: PreKeyManager
    public let quotedReplyManager: QuotedReplyManager
    public let receiptCredentialResultStore: ReceiptCredentialResultStore
    public let recipientDatabaseTable: RecipientDatabaseTable
    public let recipientFetcher: RecipientFetcher
    public let recipientHidingManager: RecipientHidingManager
    public let recipientIdFinder: RecipientIdFinder
    public let recipientManager: any SignalRecipientManager
    public let recipientMerger: RecipientMerger
    public let registrationSessionManager: RegistrationSessionManager
    public let registrationStateChangeManager: RegistrationStateChangeManager
    public let schedulers: Schedulers
    public let searchableNameIndexer: SearchableNameIndexer
    public let sentMessageTranscriptReceiver: SentMessageTranscriptReceiver
    public let signalProtocolStoreManager: SignalProtocolStoreManager
    public let chatConnectionManager: ChatConnectionManager
    public let svr: SecureValueRecovery
    public let svrCredentialStorage: SVRAuthCredentialStorage
    public let threadAssociatedDataStore: ThreadAssociatedDataStore
    public let threadRemover: ThreadRemover
    public let threadReplyInfoStore: ThreadReplyInfoStore
    public let threadStore: ThreadStore
    public let tsAccountManager: TSAccountManager
    public let tsResourceCloner: SignalTSResourceCloner
    public let tsResourceDownloadManager: TSResourceDownloadManager
    public let tsResourceManager: TSResourceManager
    public let tsResourceStore: TSResourceStore
    public let tsResourceUploadManager: TSResourceUploadManager
    public let usernameApiClient: UsernameApiClient
    public let usernameEducationManager: UsernameEducationManager
    public let usernameLinkManager: UsernameLinkManager
    public let usernameLookupManager: UsernameLookupManager
    public let usernameValidationManager: UsernameValidationManager
    public let videoDurationHelper: VideoDurationHelper
    public let wallpaperStore: WallpaperStore

    init(
        accountAttributesUpdater: AccountAttributesUpdater,
        appExpiry: AppExpiry,
        attachmentCloner: SignalAttachmentCloner,
        attachmentDownloadManager: AttachmentDownloadManager,
        attachmentManager: AttachmentManager,
        attachmentStore: AttachmentStore,
        attachmentUploadManager: AttachmentUploadManager,
        audioWaveformManager: AudioWaveformManager,
        authorMergeHelper: AuthorMergeHelper,
        badgeCountFetcher: BadgeCountFetcher,
        callRecordDeleteManager: CallRecordDeleteManager,
        callRecordMissedCallManager: CallRecordMissedCallManager,
        callRecordQuerier: CallRecordQuerier,
        callRecordStore: CallRecordStore,
        changePhoneNumberPniManager: ChangePhoneNumberPniManager,
        chatColorSettingStore: ChatColorSettingStore,
        chatConnectionManager: ChatConnectionManager,
        contactShareManager: ContactShareManager,
        db: DB,
        deletedCallRecordCleanupManager: DeletedCallRecordCleanupManager,
        deletedCallRecordStore: DeletedCallRecordStore,
        deviceManager: OWSDeviceManager,
        deviceStore: OWSDeviceStore,
        disappearingMessagesConfigurationStore: DisappearingMessagesConfigurationStore,
        editManager: EditManager,
        editMessageStore: EditMessageStore,
        externalPendingIDEALDonationStore: ExternalPendingIDEALDonationStore,
        groupCallRecordManager: GroupCallRecordManager,
        groupMemberStore: GroupMemberStore,
        groupMemberUpdater: GroupMemberUpdater,
        groupUpdateInfoMessageInserter: GroupUpdateInfoMessageInserter,
        identityManager: OWSIdentityManager,
        inactiveLinkedDeviceFinder: InactiveLinkedDeviceFinder,
        incomingCallEventSyncMessageManager: IncomingCallEventSyncMessageManager,
        incomingCallLogEventSyncMessageManager: IncomingCallLogEventSyncMessageManager,
        incomingPniChangeNumberProcessor: IncomingPniChangeNumberProcessor,
        individualCallRecordManager: IndividualCallRecordManager,
        interactionStore: InteractionStore,
        keyValueStoreFactory: KeyValueStoreFactory,
        learnMyOwnPniManager: LearnMyOwnPniManager,
        linkedDevicePniKeyManager: LinkedDevicePniKeyManager,
        linkPreviewManager: LinkPreviewManager,
        localProfileChecker: LocalProfileChecker,
        localUsernameManager: LocalUsernameManager,
        masterKeySyncManager: MasterKeySyncManager,
        mediaBandwidthPreferenceStore: MediaBandwidthPreferenceStore,
        mediaGalleryResourceManager: MediaGalleryResourceManager,
        messageBackupManager: MessageBackupManager,
        messageStickerManager: MessageStickerManager,
        nicknameManager: any NicknameManager,
        phoneNumberDiscoverabilityManager: PhoneNumberDiscoverabilityManager,
        phoneNumberVisibilityFetcher: any PhoneNumberVisibilityFetcher,
        pinnedThreadManager: PinnedThreadManager,
        pinnedThreadStore: PinnedThreadStore,
        pniHelloWorldManager: PniHelloWorldManager,
        preKeyManager: PreKeyManager,
        quotedReplyManager: QuotedReplyManager,
        receiptCredentialResultStore: ReceiptCredentialResultStore,
        recipientDatabaseTable: RecipientDatabaseTable,
        recipientFetcher: RecipientFetcher,
        recipientHidingManager: RecipientHidingManager,
        recipientIdFinder: RecipientIdFinder,
        recipientManager: any SignalRecipientManager,
        recipientMerger: RecipientMerger,
        registrationSessionManager: RegistrationSessionManager,
        registrationStateChangeManager: RegistrationStateChangeManager,
        schedulers: Schedulers,
        searchableNameIndexer: SearchableNameIndexer,
        sentMessageTranscriptReceiver: SentMessageTranscriptReceiver,
        signalProtocolStoreManager: SignalProtocolStoreManager,
        svr: SecureValueRecovery,
        svrCredentialStorage: SVRAuthCredentialStorage,
        threadAssociatedDataStore: ThreadAssociatedDataStore,
        threadRemover: ThreadRemover,
        threadReplyInfoStore: ThreadReplyInfoStore,
        threadStore: ThreadStore,
        tsAccountManager: TSAccountManager,
        tsResourceCloner: SignalTSResourceCloner,
        tsResourceDownloadManager: TSResourceDownloadManager,
        tsResourceManager: TSResourceManager,
        tsResourceStore: TSResourceStore,
        tsResourceUploadManager: TSResourceUploadManager,
        usernameApiClient: UsernameApiClient,
        usernameEducationManager: UsernameEducationManager,
        usernameLinkManager: UsernameLinkManager,
        usernameLookupManager: UsernameLookupManager,
        usernameValidationManager: UsernameValidationManager,
        videoDurationHelper: VideoDurationHelper,
        wallpaperStore: WallpaperStore
    ) {
        self.accountAttributesUpdater = accountAttributesUpdater
        self.appExpiry = appExpiry
        self.attachmentCloner = attachmentCloner
        self.attachmentDownloadManager = attachmentDownloadManager
        self.attachmentManager = attachmentManager
        self.attachmentStore = attachmentStore
        self.attachmentUploadManager = attachmentUploadManager
        self.audioWaveformManager = audioWaveformManager
        self.authorMergeHelper = authorMergeHelper
        self.badgeCountFetcher = badgeCountFetcher
        self.callRecordDeleteManager = callRecordDeleteManager
        self.callRecordMissedCallManager = callRecordMissedCallManager
        self.callRecordQuerier = callRecordQuerier
        self.callRecordStore = callRecordStore
        self.changePhoneNumberPniManager = changePhoneNumberPniManager
        self.chatColorSettingStore = chatColorSettingStore
        self.contactShareManager = contactShareManager
        self.db = db
        self.deletedCallRecordCleanupManager = deletedCallRecordCleanupManager
        self.deletedCallRecordStore = deletedCallRecordStore
        self.deviceManager = deviceManager
        self.deviceStore = deviceStore
        self.disappearingMessagesConfigurationStore = disappearingMessagesConfigurationStore
        self.editManager = editManager
        self.editMessageStore = editMessageStore
        self.externalPendingIDEALDonationStore = externalPendingIDEALDonationStore
        self.groupCallRecordManager = groupCallRecordManager
        self.groupMemberStore = groupMemberStore
        self.groupMemberUpdater = groupMemberUpdater
        self.groupUpdateInfoMessageInserter = groupUpdateInfoMessageInserter
        self.identityManager = identityManager
        self.inactiveLinkedDeviceFinder = inactiveLinkedDeviceFinder
        self.incomingCallEventSyncMessageManager = incomingCallEventSyncMessageManager
        self.incomingCallLogEventSyncMessageManager = incomingCallLogEventSyncMessageManager
        self.incomingPniChangeNumberProcessor = incomingPniChangeNumberProcessor
        self.individualCallRecordManager = individualCallRecordManager
        self.interactionStore = interactionStore
        self.keyValueStoreFactory = keyValueStoreFactory
        self.learnMyOwnPniManager = learnMyOwnPniManager
        self.linkedDevicePniKeyManager = linkedDevicePniKeyManager
        self.linkPreviewManager = linkPreviewManager
        self.localProfileChecker = localProfileChecker
        self.localUsernameManager = localUsernameManager
        self.masterKeySyncManager = masterKeySyncManager
        self.mediaBandwidthPreferenceStore = mediaBandwidthPreferenceStore
        self.mediaGalleryResourceManager = mediaGalleryResourceManager
        self.messageBackupManager = messageBackupManager
        self.messageStickerManager = messageStickerManager
        self.nicknameManager = nicknameManager
        self.phoneNumberDiscoverabilityManager = phoneNumberDiscoverabilityManager
        self.phoneNumberVisibilityFetcher = phoneNumberVisibilityFetcher
        self.pinnedThreadManager = pinnedThreadManager
        self.pinnedThreadStore = pinnedThreadStore
        self.pniHelloWorldManager = pniHelloWorldManager
        self.preKeyManager = preKeyManager
        self.quotedReplyManager = quotedReplyManager
        self.receiptCredentialResultStore = receiptCredentialResultStore
        self.recipientDatabaseTable = recipientDatabaseTable
        self.recipientFetcher = recipientFetcher
        self.recipientHidingManager = recipientHidingManager
        self.recipientIdFinder = recipientIdFinder
        self.recipientManager = recipientManager
        self.recipientMerger = recipientMerger
        self.registrationSessionManager = registrationSessionManager
        self.registrationStateChangeManager = registrationStateChangeManager
        self.schedulers = schedulers
        self.searchableNameIndexer = searchableNameIndexer
        self.sentMessageTranscriptReceiver = sentMessageTranscriptReceiver
        self.signalProtocolStoreManager = signalProtocolStoreManager
        self.chatConnectionManager = chatConnectionManager
        self.svr = svr
        self.svrCredentialStorage = svrCredentialStorage
        self.threadAssociatedDataStore = threadAssociatedDataStore
        self.threadRemover = threadRemover
        self.threadReplyInfoStore = threadReplyInfoStore
        self.threadStore = threadStore
        self.tsAccountManager = tsAccountManager
        self.tsResourceCloner = tsResourceCloner
        self.tsResourceDownloadManager = tsResourceDownloadManager
        self.tsResourceManager = tsResourceManager
        self.tsResourceStore = tsResourceStore
        self.tsResourceUploadManager = tsResourceUploadManager
        self.usernameApiClient = usernameApiClient
        self.usernameEducationManager = usernameEducationManager
        self.usernameLinkManager = usernameLinkManager
        self.usernameLookupManager = usernameLookupManager
        self.usernameValidationManager = usernameValidationManager
        self.videoDurationHelper = videoDurationHelper
        self.wallpaperStore = wallpaperStore
    }
}
