//
// Copyright 2017 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

@class AnyPromise;
@class AuthedAccount;
@class BadgeStore;
@class ModelReadCacheSizeLease;
@class OWSAES256Key;
@class OWSUserProfile;
@class OWSUserProfileBadgeInfo;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;
@class SignalRecipient;
@class SignalServiceAddress;
@class TSThread;

NS_ASSUME_NONNULL_BEGIN

// This enum is serialized.
typedef NS_ENUM(NSUInteger, UserProfileWriter) {
    UserProfileWriter_LocalUser = 0,
    UserProfileWriter_ProfileFetch = 1,
    UserProfileWriter_StorageService = 2,
    UserProfileWriter_SyncMessage = 3,
    UserProfileWriter_Registration = 4,
    UserProfileWriter_Linking = 5,
    UserProfileWriter_GroupState = 6,
    UserProfileWriter_Reupload = 7,
    UserProfileWriter_AvatarDownload = 8,
    UserProfileWriter_MetadataUpdate = 9,
    UserProfileWriter_Debugging = 10,
    UserProfileWriter_Tests = 11,
    UserProfileWriter_Unknown = 12,
    UserProfileWriter_SystemContactsFetch = 13,
    UserProfileWriter_ChangePhoneNumber = 14,
    UserProfileWriter_MessageBackupRestore = 15,
};

#pragma mark -

@protocol ProfileManagerProtocol <NSObject>

@property (nonatomic, readonly) BadgeStore *badgeStore;

- (OWSAES256Key *)localProfileKey;
// localUserProfileExists is true if there is _ANY_ local profile.
- (BOOL)localProfileExistsWithTransaction:(SDSAnyReadTransaction *)transaction;
// hasLocalProfile is true if there is a local profile with a name or avatar.
- (BOOL)hasLocalProfile;
- (nullable NSString *)localGivenName;
- (nullable NSString *)localFamilyName;
- (nullable NSString *)localFullName;
- (nullable UIImage *)localProfileAvatarImage;
- (nullable NSData *)localProfileAvatarData;
- (nullable NSArray<OWSUserProfileBadgeInfo *> *)localProfileBadgeInfo;

- (nullable NSString *)fullNameForAddress:(SignalServiceAddress *)address
                              transaction:(SDSAnyReadTransaction *)transaction;

- (nullable OWSUserProfile *)getUserProfileForAddress:(SignalServiceAddress *)addressParam
                                          transaction:(SDSAnyReadTransaction *)transaction;
- (nullable NSData *)profileKeyDataForAddress:(SignalServiceAddress *)address
                                  transaction:(SDSAnyReadTransaction *)transaction;
- (nullable OWSAES256Key *)profileKeyForAddress:(SignalServiceAddress *)address
                                    transaction:(SDSAnyReadTransaction *)transaction;

- (BOOL)hasProfileAvatarData:(SignalServiceAddress *)address transaction:(SDSAnyReadTransaction *)transaction;
- (nullable NSData *)profileAvatarDataForAddress:(SignalServiceAddress *)address
                                     transaction:(SDSAnyReadTransaction *)transaction;
- (nullable NSString *)profileAvatarURLPathForAddress:(SignalServiceAddress *)address
                                          transaction:(SDSAnyReadTransaction *)transaction;

- (BOOL)isUserInProfileWhitelist:(SignalServiceAddress *)address transaction:(SDSAnyReadTransaction *)transaction;

- (void)normalizeRecipientInProfileWhitelist:(SignalRecipient *)recipient
                                          tx:(SDSAnyWriteTransaction *)tx
    NS_SWIFT_NAME(normalizeRecipientInProfileWhitelist(_:tx:));

- (BOOL)isThreadInProfileWhitelist:(TSThread *)thread transaction:(SDSAnyReadTransaction *)transaction;

- (void)addThreadToProfileWhitelist:(TSThread *)thread transaction:(SDSAnyWriteTransaction *)transaction;

- (void)addUserToProfileWhitelist:(SignalServiceAddress *)address
                userProfileWriter:(UserProfileWriter)userProfileWriter
                      transaction:(SDSAnyWriteTransaction *)transaction;

- (void)addUsersToProfileWhitelist:(NSArray<SignalServiceAddress *> *)addresses
                 userProfileWriter:(UserProfileWriter)userProfileWriter
                       transaction:(SDSAnyWriteTransaction *)transaction;

- (void)removeUserFromProfileWhitelist:(SignalServiceAddress *)address;
- (void)removeUserFromProfileWhitelist:(SignalServiceAddress *)address
                     userProfileWriter:(UserProfileWriter)userProfileWriter
                           transaction:(SDSAnyWriteTransaction *)transaction;

- (BOOL)isGroupIdInProfileWhitelist:(NSData *)groupId transaction:(SDSAnyReadTransaction *)transaction;
- (void)addGroupIdToProfileWhitelist:(NSData *)groupId
                   userProfileWriter:(UserProfileWriter)userProfileWriter
                         transaction:(SDSAnyWriteTransaction *)transaction;
- (void)removeGroupIdFromProfileWhitelist:(NSData *)groupId
                        userProfileWriter:(UserProfileWriter)userProfileWriter
                              transaction:(SDSAnyWriteTransaction *)transaction;

- (void)warmCaches;

@property (nonatomic, readonly) BOOL hasProfileName;

// This is an internal implementation detail and should only be used by OWSUserProfile.
- (void)localProfileWasUpdated:(OWSUserProfile *)localUserProfile;

- (void)reuploadLocalProfileWithAuthedAccount:(AuthedAccount *)authedAccount
    NS_SWIFT_NAME(reuploadLocalProfile(authedAccount:));

- (nullable ModelReadCacheSizeLease *)leaseCacheSize:(NSInteger)size;

- (NSArray<SignalServiceAddress *> *)allWhitelistedRegisteredAddressesWithTx:(SDSAnyReadTransaction *)tx
    NS_SWIFT_NAME(allWhitelistedRegisteredAddresses(tx:));

/**
 * Rotates the local profile key. Intended specifically for the
 * use case of recipient hiding.
 *
 * @param tx The transaction to use for this operation.
 */
- (void)rotateProfileKeyUponRecipientHideWithTx:(SDSAnyWriteTransaction *)tx;

/// Rotating the profile key is expensive, and should be done as infrequently as possible.
/// You probably want `rotateLocalProfileKeyIfNecessary` which checks for whether
/// a rotation is necessary given whitelist/blocklist and other conditions.
/// This method exists solely for when we leave a group that had a blocked user in it; when we call
/// this we already determined we need a rotation based on _group+blocked_ state and will
/// force a rotation independently of whitelist state.
- (void)forceRotateLocalProfileKeyForGroupDepartureWithTransaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
