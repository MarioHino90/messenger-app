//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

// TODO: actually define this class; just a placeholder for now.
/// Represents an attachment stored on disk.
public class Attachment {

    public typealias IDType = Int64

    /// SQLite row id.
    public private(set) var id: IDType!

    /// Nil for:
    /// * non-visual-media attachments
    /// * undownloaded attachments where the sender didn't include the value.
    /// Otherwise this contains the value from the sender for undownloaded attachments,
    /// and our locally computed blurhash value for downloading attachments.
    public let blurHash: String?

    /// MIME type we get from the attachment's sender, known even before downloading the attachment.
    /// **If undownloaded, unverified and may not match the type of the actual bytes.**
    /// Validated once downloaded.
    public let mimeType: String

    /// Information for the "stream" (the attachment downloaded and locally available).
    public struct StreamInfo {
        /// Sha256 hash of the plaintext of the media content. Used to deduplicate incoming media.
        public let contentHash: String

        /// Byte count of the encrypted fullsize resource
        public let encryptedByteCount: UInt32
        ///  Byte count of the decrypted fullsize resource
        public let unencryptedByteCount: UInt32

        /// For downloaded attachments, the validated type of content in the actual file.
        public let contentType: ContentType

        /// Encryption key used for the local file AND media tier.
        /// If from an incoming message, we get this from the proto, and can reuse it for local and media backup encryption.
        /// If outgoing, we generate the key ourselves when we create the attachment..
        public let encryptionKey: Data

        /// File digest info.
        ///
        /// SHA256Hash(iv + cyphertext + hmac),
        /// (iv + cyphertext + hmac) is the thing we actually upload to the CDN server, which uses
        /// the ``localEncryptionKey`` field.
        ///
        /// Generated locally for outgoing attachments.
        /// Validated for downloaded attachments.
        public let encryptedFileSha256Digest: Data
    }

    public let streamInfo: StreamInfo?

    public struct TransitTierInfo {
        /// CDN number for the upload in the transit tier (or nil if not uploaded).
        public let cdnNumber: UInt32

        /// CDN key for the upload in the transit tier (or nil if not uploaded).
        public let cdnKey: String

        /// If outgoing: Local time the attachment was uploaded to the transit tier, or nil if not uploaded.
        /// If incoming: timestamp on the message the attachment came in on.
        /// Used to determine whether reuploading is necessary for e.g. forwarding.
        public let uploadTimestamp: UInt64

        /// Encryption key used on this transit tier upload.
        /// May be the same as the local stream encryption key, or may have been rotated for sending.
        public let encryptionKey: Data

        /// Byte count of the resource encrypted using the ``TransitTierInfo.encryptionKey``.
        public let encryptedByteCount: UInt32

        /// SHA256Hash(iv + cyphertext + hmac),
        /// (iv + cyphertext + hmac) is the thing we actually upload to the CDN server, which uses
        /// the ``TransitTierInfo.encryptionKey`` field.
        ///
        /// Generated locally for outgoing attachments.
        /// For incoming attachments, taken off the service proto. If validation fails, the download is rejected.
        public let encryptedFileSha256Digest: Data

        /// Timestamp we last tried (and failed) to download from the transit tier.
        /// Nil if we have not tried or have successfully downloaded.
        public let lastDownloadAttemptTimestamp: UInt64?
    }

    /// Information for the transit tier upload, if known to be uploaded.
    public let transitTierInfo: TransitTierInfo?

    /// MediaName used for backups (but assigned even if backups disabled).
    public let mediaName: String

    public struct MediaTierInfo {
        /// CDN number for the fullsize upload in the media tier.
        public let cdnNumber: UInt32

        /// If the value in this column doesn’t match the current Backup Subscription Era,
        /// it should also be considered un-uploaded.
        /// Set to the current era when uploaded.
        public let uploadEra: UInt64

        /// Timestamp we last tried (and failed) to download from the media tier.
        /// Nil if we have not tried or have successfully downloaded.
        public let lastDownloadAttemptTimestamp: UInt64?
    }

    /// If null, the resource has not been uploaded to the media tier.
    public let mediaTierInfo: MediaTierInfo?

    public struct ThumbnailMediaTierInfo {
        /// CDN number for the thumbnail upload in the media tier.
        public let cdnNumber: UInt32

        /// If the value in this column doesn’t match the current Backup Subscription Era,
        /// it should also be considered un-uploaded.
        /// Set to the current era when uploaded.
        public let uploadEra: UInt64

        /// Timestamp we last tried (and failed) to download the thumbnail from the media tier.
        /// Nil if we have not tried or have successfully downloaded.
        public let lastDownloadAttemptTimestamp: UInt64?
    }

    /// Not to be confused with thumbnails used for rendering, or those created for quoted message replies.
    /// This thumbnail is exclusively used for backup purposes.
    /// If null, the thumbnail resource has not been uploaded to the media tier.
    public let thumbnailMediaTierInfo: ThumbnailMediaTierInfo?

    /// Filepath to the encrypted fullsize media file on local disk.
    public let localRelativeFilePath: String?
    /// Filepath to the encrypted thumbnail file on local disk.
    /// Not to be confused with thumbnails used for rendering, or those created for quoted message replies.
    /// This thumbnail is exclusively used for backup purposes.
    public let localRelativeFilePathThumbnail: String?

    internal init(
        id: Int64!,
        blurHash: String?,
        contentHash: String?,
        encryptedByteCount: UInt32?,
        unencryptedByteCount: UInt32?,
        mimeType: String,
        contentType: ContentType?,
        encryptionKey: Data?,
        encryptedFileSha256Digest: Data?,
        transitCdnNumber: UInt32?,
        transitCdnKey: String?,
        transitUploadTimestamp: UInt64?,
        transitEncryptionKey: Data?,
        transitEncryptedByteCount: UInt32?,
        transitEncryptedFileSha256Digest: Data?,
        lastTransitDownloadAttemptTimestamp: UInt64?,
        mediaName: String,
        mediaCdnNumber: UInt32?,
        mediaTierUploadEra: UInt64?,
        lastMediaDownloadAttemptTimestamp: UInt64?,
        thumbnailCdnNumber: UInt32?,
        thumbnailUploadEra: UInt64?,
        lastThumbnailDownloadAttemptTimestamp: UInt64?,
        localRelativeFilePath: String?,
        localRelativeFilePathThumbnail: String?
    ) {
        if !CurrentAppContext().isRunningTests {
            fatalError("No instances should exist yet!")
        }
        self.id = id
        self.blurHash = blurHash
        self.mimeType = mimeType
        self.streamInfo = StreamInfo(
            contentHash: contentHash,
            encryptedByteCount: encryptedByteCount,
            unencryptedByteCount: unencryptedByteCount,
            contentType: contentType,
            encryptionKey: encryptionKey,
            encryptedFileSha256Digest: encryptedFileSha256Digest
        )
        self.transitTierInfo = TransitTierInfo(
            cdnNumber: transitCdnNumber,
            cdnKey: transitCdnKey,
            uploadTimestamp: transitUploadTimestamp,
            encryptionKey: transitEncryptionKey,
            encryptedByteCount: transitEncryptedByteCount,
            encryptedFileSha256Digest: transitEncryptedFileSha256Digest,
            lastDownloadAttemptTimestamp: lastTransitDownloadAttemptTimestamp
        )
        self.mediaName = mediaName
        self.mediaTierInfo = MediaTierInfo(
           cdnNumber: mediaCdnNumber,
           uploadEra: mediaTierUploadEra,
           lastDownloadAttemptTimestamp: lastMediaDownloadAttemptTimestamp
       )
       self.thumbnailMediaTierInfo = ThumbnailMediaTierInfo(
           cdnNumber: thumbnailCdnNumber,
           uploadEra: thumbnailUploadEra,
           lastDownloadAttemptTimestamp: lastThumbnailDownloadAttemptTimestamp
       )
        self.localRelativeFilePath = localRelativeFilePath
        self.localRelativeFilePathThumbnail = localRelativeFilePathThumbnail
    }

    public var isUploadedToTransitTier: Bool {
        return transitTierInfo != nil
    }

    func asStream() -> AttachmentStream? {
        return AttachmentStream(attachment: self)
    }

    public enum TransitUploadStrategy {
        case reuseExistingUpload(TransitTierInfo)
        case reuseStreamEncryption(Upload.LocalUploadMetadata)
        case freshUpload(AttachmentStream)
        case cannotUpload
    }

    public func transitUploadStrategy(dateProvider: DateProvider) -> TransitUploadStrategy {
        // We never allow uploads of data we don't have locally.
        guard let stream = self.asStream() else {
            return .cannotUpload
        }
        if
            // We have a prior upload
            let transitTierInfo,
            // And we are still in the window to reuse it
            dateProvider().timeIntervalSince(
                Date(millisecondsSince1970: transitTierInfo.uploadTimestamp)
            ) <= Upload.Constants.uploadReuseWindow
        {
            // We have unexpired transit tier info. Reuse that upload.
            return .reuseExistingUpload(transitTierInfo)
        } else if
            // This device has never uploaded
            transitTierInfo == nil,
            // No media tier info either
            mediaTierInfo == nil
        {
            // Reuse our local encryption for sending.
            // Without this, we'd have to reupload all our outgoing attacments
            // in order to copy them to the media tier.
            return .reuseStreamEncryption(.init(
                fileUrl: stream.fileURL,
                key: stream.info.encryptionKey,
                digest: stream.info.encryptedFileSha256Digest,
                encryptedDataLength: stream.info.encryptedByteCount,
                plaintextDataLength: stream.info.unencryptedByteCount
            ))
        } else {
            // Upload from scratch
            return .freshUpload(stream)
        }
    }
}

extension Attachment.StreamInfo {
    fileprivate init?(
        contentHash: String?,
        encryptedByteCount: UInt32?,
        unencryptedByteCount: UInt32?,
        contentType: Attachment.ContentType?,
        encryptionKey: Data?,
        encryptedFileSha256Digest: Data?
    ) {
        guard
            let contentHash,
            let encryptedByteCount,
            let unencryptedByteCount,
            let contentType,
            let encryptionKey,
            let encryptedFileSha256Digest
        else {
            owsAssertDebug(
                contentHash == nil
                && encryptedByteCount == nil
                && unencryptedByteCount == nil
                && contentType == nil
                && encryptionKey == nil
                && encryptedFileSha256Digest == nil,
                "Have partial stream info!"
            )
            return nil
        }
        self.contentHash = contentHash
        self.encryptedByteCount = encryptedByteCount
        self.unencryptedByteCount = unencryptedByteCount
        self.contentType = contentType
        self.encryptionKey = encryptionKey
        self.encryptedFileSha256Digest = encryptedFileSha256Digest
    }
}

extension Attachment.TransitTierInfo {
    fileprivate init?(
        cdnNumber: UInt32?,
        cdnKey: String?,
        uploadTimestamp: UInt64?,
        encryptionKey: Data?,
        encryptedByteCount: UInt32?,
        encryptedFileSha256Digest: Data?,
        lastDownloadAttemptTimestamp: UInt64?
    ) {
        guard
            let cdnNumber,
            let cdnKey,
            let uploadTimestamp,
            let encryptionKey,
            let encryptedByteCount,
            let encryptedFileSha256Digest
        else {
            owsAssertDebug(
                cdnNumber == nil
                && cdnKey == nil
                && uploadTimestamp == nil
                && encryptionKey == nil
                && encryptedByteCount == nil
                && encryptedFileSha256Digest == nil,
                "Have partial transit cdn info!"
            )
            return nil
        }
        self.cdnNumber = cdnNumber
        self.cdnKey = cdnKey
        self.uploadTimestamp = uploadTimestamp
        self.lastDownloadAttemptTimestamp = lastDownloadAttemptTimestamp
        self.encryptionKey = encryptionKey
        self.encryptedByteCount = encryptedByteCount
        self.encryptedFileSha256Digest = encryptedFileSha256Digest
    }
}

extension Attachment.MediaTierInfo {
    fileprivate init?(
        cdnNumber: UInt32?,
        uploadEra: UInt64?,
        lastDownloadAttemptTimestamp: UInt64?
    ) {
        guard
            let cdnNumber,
            let uploadEra
        else {
            owsAssertDebug(
                cdnNumber == nil
                && uploadEra == nil,
                "Have partial media cdn info!"
            )
            return nil
        }
        self.cdnNumber = cdnNumber
        self.uploadEra = uploadEra
        self.lastDownloadAttemptTimestamp = lastDownloadAttemptTimestamp
    }
}

extension Attachment.ThumbnailMediaTierInfo {
    fileprivate init?(
        cdnNumber: UInt32?,
        uploadEra: UInt64?,
        lastDownloadAttemptTimestamp: UInt64?
    ) {
        guard
            let cdnNumber,
            let uploadEra
        else {
            owsAssertDebug(
                cdnNumber == nil
                && uploadEra == nil,
                "Have partial thumbnail media cdn info!"
            )
            return nil
        }
        self.cdnNumber = cdnNumber
        self.uploadEra = uploadEra
        self.lastDownloadAttemptTimestamp = lastDownloadAttemptTimestamp
    }
}
