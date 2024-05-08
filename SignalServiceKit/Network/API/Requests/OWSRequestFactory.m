//
// Copyright 2018 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

#import "OWSRequestFactory.h"
#import "OWS2FAManager.h"
#import "ProfileManagerProtocol.h"
#import "SignedPrekeyRecord.h"
#import <SignalCoreKit/Cryptography.h>
#import <SignalCoreKit/NSData+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

static NSString *const kSenderKeySendRequestBodyContentType = @"application/vnd.signal-messenger.mrm";

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSRequestKey_AuthKey = @"AuthKey";

@implementation OWSRequestFactory

+ (TSRequest *)disable2FARequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:self.textSecure2FAAPI] method:@"DELETE" parameters:@{}];
}

+ (TSRequest *)acknowledgeMessageDeliveryRequestWithServerGuid:(NSString *)serverGuid
{
    OWSAssertDebug(serverGuid.length > 0);

    NSString *path = [NSString stringWithFormat:@"v1/messages/uuid/%@", serverGuid];

    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"DELETE" parameters:@{}];
}

+ (TSRequest *)getDevicesRequest
{
    NSString *path = [NSString stringWithFormat:self.textSecureDevicesAPIFormat, @""];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)getMessagesRequest
{
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:@"v1/messages"] method:@"GET" parameters:@{}];
    [StoryManager appendStoryHeadersToRequest:request];
    request.shouldCheckDeregisteredOn401 = YES;
    return request;
}

+ (TSRequest *)getUnversionedProfileRequestWithServiceId:(ServiceIdObjC *)serviceId
                                             udAccessKey:(nullable SMKUDAccessKey *)udAccessKey
                                                    auth:(ChatServiceAuth *)auth
{
    NSString *path = [NSString stringWithFormat:@"v1/profile/%@", serviceId.serviceIdString];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
    if (udAccessKey != nil) {
        [self useUDAuthWithRequest:request accessKey:udAccessKey];
    } else {
        [request setAuth:auth];
    }
    return request;
}

+ (TSRequest *)getVersionedProfileRequestWithAci:(AciObjC *)aci
                               profileKeyVersion:(nullable NSString *)profileKeyVersion
                               credentialRequest:(nullable NSData *)credentialRequest
                                     udAccessKey:(nullable SMKUDAccessKey *)udAccessKey
                                            auth:(ChatServiceAuth *)auth
{
    NSString *aciString = aci.serviceIdString;
    NSString *_Nullable profileKeyVersionParam = profileKeyVersion.lowercaseString;
    NSString *_Nullable credentialRequestParam = credentialRequest.hexadecimalString;

    // GET /v1/profile/{aci}/{version}/{profile_key_credential_request}
    NSString *path;
    if (profileKeyVersion.length > 0 && credentialRequest.length > 0) {
        path = [NSString stringWithFormat:@"v1/profile/%@/%@/%@?credentialType=expiringProfileKey",
                         aciString,
                         profileKeyVersionParam,
                         credentialRequestParam];
    } else if (profileKeyVersion.length > 0) {
        path = [NSString stringWithFormat:@"v1/profile/%@/%@", aciString, profileKeyVersionParam];
    } else {
        path = [NSString stringWithFormat:@"v1/profile/%@", aciString];
    }

    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
    if (udAccessKey != nil) {
        [self useUDAuthWithRequest:request accessKey:udAccessKey];
    } else {
        [request setAuth:auth];
    }
    return request;
}

+ (TSRequest *)turnServerInfoRequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v1/calling/relays"] method:@"GET" parameters:@{}];
}

+ (TSRequest *)allocAttachmentRequestV4
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v4/attachments/form/upload"] method:@"GET" parameters:@{}];
}

+ (TSRequest *)availablePreKeysCountRequestForIdentity:(OWSIdentity)identity
{
    NSString *path = self.textSecureKeysAPI;
    NSString *queryParam = [OWSRequestFactory queryParamFor:identity];
    if (queryParam != nil) {
        path = [path stringByAppendingFormat:@"?%@", queryParam];
    }
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)currentSignedPreKeyRequest
{
    NSString *path = self.textSecureSignedKeysAPI;
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)profileAvatarUploadFormRequest
{
    NSString *path = self.textSecureProfileAvatarFormAPI;
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (TSRequest *)recipientPreKeyRequestWithServiceId:(ServiceIdObjC *)serviceId
                                          deviceId:(uint32_t)deviceId
                                       udAccessKey:(nullable SMKUDAccessKey *)udAccessKey
{
    NSString *format = @"%@/%@/%u";
    NSString *path = [NSString stringWithFormat:format, self.textSecureKeysAPI, serviceId.serviceIdString, deviceId];

    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
    if (udAccessKey != nil) {
        [self useUDAuthWithRequest:request accessKey:udAccessKey];
    }
    return request;
}

+ (TSRequest *)registerForPushRequestWithPushIdentifier:(NSString *)identifier
                                         voipIdentifier:(nullable NSString *)voipId
{
    OWSAssertDebug(identifier.length > 0);

    NSString *path = [NSString stringWithFormat:@"%@/%@", self.textSecureAccountsAPI, @"apn"];

    NSMutableDictionary *parameters = [@{ @"apnRegistrationId" : identifier } mutableCopy];
    if (voipId.length > 0) {
        parameters[@"voipRegistrationId"] = voipId;
    } else {
        OWSAssertDebug(SSKFeatureFlags.notificationServiceExtension);
    }

    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:parameters];
}

+ (TSRequest *)unregisterAccountRequest
{
    NSString *path = [NSString stringWithFormat:@"%@/%@", self.textSecureAccountsAPI, @"me"];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"DELETE" parameters:@{}];
}

+ (TSRequest *)currencyConversionRequest NS_SWIFT_NAME(currencyConversionRequest())
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v1/payments/conversions"] method:@"GET" parameters:@{}];
}

+ (TSRequest *)submitMessageRequestWithServiceId:(ServiceIdObjC *)serviceId
                                        messages:(NSArray<DeviceMessage *> *)messages
                                       timestamp:(uint64_t)timestamp
                                     udAccessKey:(nullable SMKUDAccessKey *)udAccessKey
                                        isOnline:(BOOL)isOnline
                                        isUrgent:(BOOL)isUrgent
                                         isStory:(BOOL)isStory
{
    // NOTE: messages may be empty; See comments in OWSDeviceManager.
    OWSAssertDebug(timestamp > 0);

    NSString *path = [self.textSecureMessagesAPI stringByAppendingString:serviceId.serviceIdString];

    path = [path stringByAppendingFormat:@"?story=%@", isStory ? @"true" : @"false"];

    // Returns the per-account-message parameters used when submitting a message to
    // the Signal Web Service.
    // See
    // <https://github.com/signalapp/Signal-Server/blob/65da844d70369cb8b44966cfb2d2eb9b925a6ba4/service/src/main/java/org/whispersystems/textsecuregcm/entities/IncomingMessageList.java>.
    NSDictionary *parameters = @{
        @"messages" : [messages map:^id _Nonnull(DeviceMessage *_Nonnull item) { return [item requestParameters]; }],
        @"timestamp" : @(timestamp),
        @"online" : @(isOnline),
        @"urgent" : @(isUrgent)
    };

    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"PUT" parameters:parameters];
    if (udAccessKey != nil) {
        [self useUDAuthWithRequest:request accessKey:udAccessKey];
    }
    return request;
}

+ (TSRequest *)submitMultiRecipientMessageRequestWithCiphertext:(NSData *)ciphertext
                                           compositeUDAccessKey:(SMKUDAccessKey *)udAccessKey
                                                      timestamp:(uint64_t)timestamp
                                                       isOnline:(BOOL)isOnline
                                                       isUrgent:(BOOL)isUrgent
                                                        isStory:(BOOL)isStory
{
    OWSAssertDebug(ciphertext);
    OWSAssertDebug(udAccessKey);
    OWSAssertDebug(timestamp > 0);

    // We build the URL by hand instead of passing the query parameters into the query parameters
    // AFNetworking won't handle both query parameters and an httpBody (which we need here)
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:self.textSecureMultiRecipientMessageAPI];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"ts" value:[@(timestamp) stringValue]],
        [NSURLQueryItem queryItemWithName:@"online" value:isOnline ? @"true" : @"false"],
        [NSURLQueryItem queryItemWithName:@"urgent" value:isUrgent ? @"true" : @"false"],
        [NSURLQueryItem queryItemWithName:@"story" value:isStory ? @"true" : @"false"],
    ];
    NSURL *url = [components URL];

    TSRequest *request = [TSRequest requestWithUrl:url method:@"PUT" parameters:nil];
    [request setValue:kSenderKeySendRequestBodyContentType forHTTPHeaderField:@"Content-Type"];
    if (udAccessKey != nil) {
        [self useUDAuthWithRequest:request accessKey:udAccessKey];
    }
    request.HTTPBody = [ciphertext copy];
    return request;
}

+ (TSRequest *)registerSignedPrekeyRequestForIdentity:(OWSIdentity)identity
                                         signedPreKey:(SignedPreKeyRecord *)signedPreKey
{
    OWSAssertDebug(signedPreKey);

    NSString *path = self.textSecureSignedKeysAPI;
    NSString *queryParam = [OWSRequestFactory queryParamFor:identity];
    if (queryParam != nil) {
        path = [path stringByAppendingFormat:@"?%@", queryParam];
    }
    return [TSRequest requestWithUrl:[NSURL URLWithString:path]
                              method:@"PUT"
                          parameters:[self signedPreKeyRequestParameters:signedPreKey]];
}

#pragma mark - Storage Service

+ (TSRequest *)storageAuthRequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v1/storage/auth"] method:@"GET" parameters:@{}];
}

#pragma mark - Remote Attestation

+ (TSRequest *)remoteAttestationAuthRequestForKeyBackup
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v1/backup/auth"] method:@"GET" parameters:@{}];
}

+ (TSRequest *)remoteAttestationAuthRequestForCDSI
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v2/directory/auth"] method:@"GET" parameters:@{}];
}

+ (TSRequest *)remoteAttestationAuthRequestForSVR2
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"v2/backup/auth"] method:@"GET" parameters:@{}];
}

#pragma mark - UD

+ (TSRequest *)udSenderCertificateRequestWithUuidOnly:(BOOL)uuidOnly
{
    NSString *path = @"v1/certificate/delivery";
    if (uuidOnly) {
        path = [path stringByAppendingString:@"?includeE164=false"];
    }
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

+ (void)useUDAuthWithRequest:(TSRequest *)request accessKey:(SMKUDAccessKey *)udAccessKey
{
    OWSAssertDebug(request);
    OWSAssertDebug(udAccessKey);

    // Suppress normal auth headers.
    request.shouldHaveAuthorizationHeaders = NO;

    // Add UD auth header.
    [request setValue:[udAccessKey.keyData base64EncodedString] forHTTPHeaderField:@"Unidentified-Access-Key"];

    request.isUDRequest = YES;
}

#pragma mark - Profiles

+ (TSRequest *)profileNameSetRequestWithEncryptedPaddedName:(NSData *)encryptedPaddedName
{
    const NSUInteger kEncodedNameLength = 108;

    NSString *base64EncodedName = [encryptedPaddedName base64EncodedString];
    NSString *urlEncodedName;
    // name length must match exactly
    if (base64EncodedName.length == kEncodedNameLength) {
        urlEncodedName = base64EncodedName.encodeURIComponent;
    } else {
        // if name length doesn't match exactly, use a blank name.
        // Since names are required, the server will reject this with HTTP405,
        // which is desirable - we want this request to fail rather than upload
        // a broken name.
        OWSFailDebug(@"Couldn't encode name.");
        OWSAssertDebug(encryptedPaddedName == nil);
        urlEncodedName = @"";
    }
    NSString *urlString = [NSString stringWithFormat:@"v1/profile/name/%@", urlEncodedName];

    NSURL *url = [NSURL URLWithString:urlString];
    TSRequest *request = [[TSRequest alloc] initWithURL:url];
    request.HTTPMethod = @"PUT";

    return request;
}

#pragma mark - Remote Config

+ (TSRequest *)getRemoteConfigRequest
{
    NSURL *url = [NSURL URLWithString:@"/v1/config/"];
    return [TSRequest requestWithUrl:url method:@"GET" parameters:@{}];
}

#pragma mark - Groups v2

+ (TSRequest *)groupAuthenticationCredentialRequestWithFromRedemptionSeconds:(uint64_t)fromRedemptionSeconds
                                                         toRedemptionSeconds:(uint64_t)toRedemptionSeconds
{
    OWSAssertDebug(fromRedemptionSeconds > 0);
    OWSAssertDebug(toRedemptionSeconds > 0);

    NSString *path = [NSString
        stringWithFormat:
            @"v1/certificate/auth/group?redemptionStartSeconds=%llu&redemptionEndSeconds=%llu&zkcCredential=true",
        (unsigned long long)fromRedemptionSeconds,
        (unsigned long long)toRedemptionSeconds];
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

#pragma mark - Payments

+ (TSRequest *)paymentsAuthenticationCredentialRequest
{
    NSString *path = @"/v1/payments/auth";
    return [TSRequest requestWithUrl:[NSURL URLWithString:path] method:@"GET" parameters:@{}];
}

#pragma mark - Spam

+ (TSRequest *)pushChallengeRequest
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"/v1/challenge/push"] method:@"POST" parameters:@{}];
}

+ (TSRequest *)pushChallengeResponseWithToken:(NSString *)challengeToken
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"/v1/challenge"]
                              method:@"PUT"
                          parameters:@{ @"type" : @"rateLimitPushChallenge", @"challenge" : challengeToken }];
}

+ (TSRequest *)recaptchChallengeResponseWithToken:(NSString *)serverToken captchaToken:(NSString *)captchaToken
{
    return [TSRequest requestWithUrl:[NSURL URLWithString:@"/v1/challenge"]
                              method:@"PUT"
                          parameters:@{ @"type" : @"captcha", @"token" : serverToken, @"captcha" : captchaToken }];
}

@end

NS_ASSUME_NONNULL_END
