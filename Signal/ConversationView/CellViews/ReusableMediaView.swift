//
// Copyright 2021 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import SignalCoreKit
import SignalServiceKit
import SignalUI
import YYImage

// MARK: -

// The loadState property allows us to:
//
// * Make sure we only have one load attempt
//   enqueued at a time for a given piece of media.
// * We never retry media that can't be loaded.
// * We skip media loads which are no longer
//   necessary by the time they reach the front
//   of the queue.

private enum LoadState {
    case unloaded
    case loading
    case loaded
    case failed
}

// MARK: -

public protocol MediaViewAdapter {
    var mediaView: UIView { get }
    var isLoaded: Bool { get }
    var cacheKey: CVMediaCache.CacheKey { get }
    var shouldBeRenderedByYY: Bool { get }

    func applyMedia(_ media: AnyObject)
    func unloadMedia()
}

// MARK: -

public protocol MediaViewAdapterSwift: MediaViewAdapter {
    func loadMedia() -> Promise<AnyObject>
}

// MARK: -

public enum ReusableMediaError: Error {
    case invalidMedia
    case redundantLoad
}

// MARK: -

public class ReusableMediaView: NSObject {

    private let mediaViewAdapter: MediaViewAdapterSwift
    private let mediaCache: CVMediaCache

    public var mediaView: UIView {
        mediaViewAdapter.mediaView
    }

    var isVideo: Bool {
        mediaViewAdapter as? MediaViewAdapterVideo != nil
    }

    // MARK: - LoadState

    // Thread-safe access to load state.
    //
    // We use a "box" class so that we can capture a reference
    // to this box (rather than self) and a) safely access
    // if off the main thread b) not prevent deallocation of
    // self.
    private let _loadState = AtomicValue(LoadState.unloaded, lock: .sharedGlobal)
    private var loadState: LoadState {
        get {
            return _loadState.get()
        }
        set {
            _loadState.set(newValue)
        }
    }

    // MARK: - Ownership

    public weak var owner: NSObject?

    // MARK: - Initializers

    public init(mediaViewAdapter: MediaViewAdapter,
                mediaCache: CVMediaCache) {
        self.mediaViewAdapter = mediaViewAdapter as! MediaViewAdapterSwift
        self.mediaCache = mediaCache
    }

    deinit {
        AssertIsOnMainThread()

        loadState = .unloaded
    }

    // MARK: - Initializers

    public func load() {
        AssertIsOnMainThread()

        switch loadState {
        case .unloaded:
            loadState = .loading

            tryToLoadMedia()
        case .loading, .loaded, .failed:
            break
        }
    }

    public func unload() {
        AssertIsOnMainThread()

        loadState = .unloaded

        mediaViewAdapter.unloadMedia()
    }

    // TODO: It would be preferable to figure out some way to use ReverseDispatchQueue.
    private static let serialQueue = DispatchQueue(label: "org.signal.reusable-media-view")

    private func tryToLoadMedia() {
        AssertIsOnMainThread()

        guard !mediaViewAdapter.isLoaded else {
            // Already loaded.
            return
        }
        guard let loadOwner = self.owner else {
            owsFailDebug("Missing owner for load.")
            return
        }

        // It's critical that we update loadState once
        // our load attempt is complete.
        let loadCompletion: (AnyObject?) -> Void = { [weak self] (possibleMedia) in
            AssertIsOnMainThread()

            guard let self = self else {
                return
            }
            guard loadOwner == self.owner else {
                // Owner has changed; ignore.
                return
            }
            guard self.loadState == .loading else {
                return
            }
            guard let media = possibleMedia else {
                self.loadState = .failed
                return
            }

            self.mediaViewAdapter.applyMedia(media)

            self.loadState = .loaded
        }

        guard loadState == .loading else {
            owsFailDebug("Unexpected load state: \(loadState)")
            return
        }

        let mediaViewAdapter = self.mediaViewAdapter
        let cacheKey = mediaViewAdapter.cacheKey
        let mediaCache = self.mediaCache
        if let media = mediaCache.getMedia(cacheKey, isAnimated: mediaViewAdapter.shouldBeRenderedByYY) {
            loadCompletion(media)
            return
        }

        let loadState = self._loadState

        firstly(on: Self.serialQueue) { () -> Promise<AnyObject> in
            guard loadState.get() == .loading else {
                throw ReusableMediaError.redundantLoad
            }
            return mediaViewAdapter.loadMedia()
        }.done(on: DispatchQueue.main) { (media: AnyObject) in
            mediaCache.setMedia(media, forKey: cacheKey, isAnimated: mediaViewAdapter.shouldBeRenderedByYY)

            loadCompletion(media)
        }.catch(on: DispatchQueue.main) { (error: Error) in
            switch error {
            case ReusableMediaError.redundantLoad,
                 ReusableMediaError.invalidMedia:
                Logger.warn("Error: \(error)")
            default:
                owsFailDebug("Error: \(error)")
            }
            loadCompletion(nil)
        }
    }
}

// MARK: -

class MediaViewAdapterBlurHash: MediaViewAdapterSwift {

    public let shouldBeRenderedByYY = false
    let blurHash: String
    let imageView = CVImageView()

    init(blurHash: String) {
        self.blurHash = blurHash
    }

    var mediaView: UIView {
        imageView
    }

    var isLoaded: Bool {
        imageView.image != nil
    }

    var cacheKey: CVMediaCache.CacheKey {
        // NOTE: in the blurhash case, we use the blurHash itself as the
        // cachekey to avoid conflicts with the actual attachment contents.
        .blurHash(blurHash)
    }

    func loadMedia() -> Promise<AnyObject> {
        guard let image = BlurHash.image(for: blurHash) else {
            return Promise(error: OWSAssertionError("Missing image for blurHash."))
        }
        return Promise.value(image)
    }

    func applyMedia(_ media: AnyObject) {
        AssertIsOnMainThread()

        guard let image = media as? UIImage else {
            owsFailDebug("Media has unexpected type: \(type(of: media))")
            return
        }
        imageView.image = image
    }

    func unloadMedia() {
        AssertIsOnMainThread()

        imageView.image = nil
    }
}

// MARK: - MediaViewAdapterLoopingVideo

class MediaViewAdapterLoopingVideo: MediaViewAdapterSwift {
    let attachmentStream: TSResourceStream
    let videoView = LoopingVideoView()

    init(attachmentStream: TSResourceStream) {
        self.attachmentStream = attachmentStream
    }

    let shouldBeRenderedByYY = false
    var mediaView: UIView { videoView }
    var isLoaded: Bool { videoView.video != nil }
    var cacheKey: CVMediaCache.CacheKey { .attachment(attachmentStream.resourceId) }

    func loadMedia() -> Promise<AnyObject> {
        guard let path = attachmentStream.bridgeStream.originalFilePath,
              let video = LoopingVideo(url: URL(fileURLWithPath: path)) else {
            return Promise(error: ReusableMediaError.invalidMedia)
        }
        return Promise.value(video)
    }

    func applyMedia(_ media: AnyObject) {
        AssertIsOnMainThread()

        guard let video = media as? LoopingVideo else {
            owsFailDebug("Media has unexpected type: \(type(of: media))")
            return
        }
        videoView.video = video
    }

    func unloadMedia() {
        AssertIsOnMainThread()

        videoView.video = nil
    }
}

// MARK: -

class MediaViewAdapterAnimated: MediaViewAdapterSwift {

    public let shouldBeRenderedByYY = true
    let attachmentStream: TSResourceStream
    let imageView = CVAnimatedImageView()

    init(attachmentStream: TSResourceStream) {
        self.attachmentStream = attachmentStream
    }

    var mediaView: UIView {
        imageView
    }

    var isLoaded: Bool {
        imageView.image != nil
    }

    var cacheKey: CVMediaCache.CacheKey {
        .attachment(attachmentStream.resourceId)
    }

    func loadMedia() -> Promise<AnyObject> {
        guard attachmentStream.computeContentType().isAnimatedImage else {
            return Promise(error: ReusableMediaError.invalidMedia)
        }
        guard let filePath = attachmentStream.bridgeStream.originalFilePath else {
            return Promise(error: OWSAssertionError("Attachment stream missing original file path."))
        }
        guard let animatedImage = YYImage(contentsOfFile: filePath) else {
            return Promise(error: OWSAssertionError("Invalid animated image."))
        }
        return Promise.value(animatedImage)
    }

    func applyMedia(_ media: AnyObject) {
        AssertIsOnMainThread()

        guard let image = media as? YYImage else {
            owsFailDebug("Media has unexpected type: \(type(of: media))")
            return
        }
        imageView.image = image
    }

    func unloadMedia() {
        AssertIsOnMainThread()

        imageView.image = nil
    }
}

// MARK: -

class MediaViewAdapterStill: MediaViewAdapterSwift {

    public let shouldBeRenderedByYY = false
    let attachmentStream: TSResourceStream
    let imageView = CVImageView()
    let thumbnailQuality: AttachmentThumbnailQuality

    init(
        attachmentStream: TSResourceStream,
        thumbnailQuality: AttachmentThumbnailQuality
    ) {
        self.attachmentStream = attachmentStream
        self.thumbnailQuality = thumbnailQuality
    }

    var mediaView: UIView {
        imageView
    }

    var isLoaded: Bool {
        imageView.image != nil
    }

    var cacheKey: CVMediaCache.CacheKey {
        .attachmentThumbnail(attachmentStream.resourceId, quality: thumbnailQuality)
    }

    func loadMedia() -> Promise<AnyObject> {
        guard attachmentStream.computeContentType().isImage else {
            return Promise(error: ReusableMediaError.invalidMedia)
        }
        return Promise.wrapAsync {
            let image = await self.attachmentStream.thumbnailImage(quality: self.thumbnailQuality)
            guard let image else {
                throw OWSAssertionError("Could not load thumbnail")
            }
            return image
        }
    }

    func applyMedia(_ media: AnyObject) {
        AssertIsOnMainThread()

        guard let image = media as? UIImage else {
            owsFailDebug("Media has unexpected type: \(type(of: media))")
            return
        }
        imageView.image = image
    }

    func unloadMedia() {
        AssertIsOnMainThread()

        imageView.image = nil
    }
}

// MARK: -

class MediaViewAdapterVideo: MediaViewAdapterSwift {

    public let shouldBeRenderedByYY = false
    let attachmentStream: TSResourceStream
    let imageView = CVImageView()
    let thumbnailQuality: AttachmentThumbnailQuality

    init(
        attachmentStream: TSResourceStream,
        thumbnailQuality: AttachmentThumbnailQuality
    ) {
        self.attachmentStream = attachmentStream
        self.thumbnailQuality = thumbnailQuality
    }

    var mediaView: UIView {
        imageView
    }

    var isLoaded: Bool {
        imageView.image != nil
    }

    var cacheKey: CVMediaCache.CacheKey {
        .attachmentThumbnail(attachmentStream.resourceId, quality: thumbnailQuality)
    }

    func loadMedia() -> Promise<AnyObject> {
        guard attachmentStream.computeContentType().isVideo else {
            return Promise(error: ReusableMediaError.invalidMedia)
        }
        return Promise.wrapAsync {
            let image = await self.attachmentStream.thumbnailImage(quality: self.thumbnailQuality)
            guard let image else {
                throw OWSAssertionError("Could not load thumbnail")
            }
            return image
        }
    }

    func applyMedia(_ media: AnyObject) {
        AssertIsOnMainThread()

        guard let image = media as? UIImage else {
            owsFailDebug("Media has unexpected type: \(type(of: media))")
            return
        }
        imageView.image = image
    }

    func unloadMedia() {
        AssertIsOnMainThread()

        imageView.image = nil
    }
}

// MARK: -

public class MediaViewAdapterSticker: NSObject, MediaViewAdapterSwift {

    public let shouldBeRenderedByYY: Bool
    let attachmentStream: TSResourceStream
    let imageView: UIImageView

    public init(attachmentStream: TSResourceStream) {
        self.shouldBeRenderedByYY = attachmentStream.computeContentType().isAnimatedImage
        self.attachmentStream = attachmentStream

        if shouldBeRenderedByYY {
            imageView = CVAnimatedImageView()
        } else {
            imageView = CVImageView()
        }

        imageView.contentMode = .scaleAspectFit
    }

    public var mediaView: UIView {
        imageView
    }

    public var isLoaded: Bool {
        imageView.image != nil
    }

    public var cacheKey: CVMediaCache.CacheKey {
        .attachment(attachmentStream.resourceId)
    }

    public func loadMedia() -> Promise<AnyObject> {
        switch attachmentStream.computeContentType() {
        case .image, .animatedImage:
            break
        case .video, .audio, .file:
            return Promise(error: ReusableMediaError.invalidMedia)
        }
        guard let filePath = attachmentStream.bridgeStream.originalFilePath else {
            return Promise(error: OWSAssertionError("Attachment stream missing original file path."))
        }
        if shouldBeRenderedByYY {
            guard let animatedImage = YYImage(contentsOfFile: filePath) else {
                return Promise(error: OWSAssertionError("Invalid animated image."))
            }
            return Promise.value(animatedImage)
        } else {
            guard let image = UIImage(contentsOfFile: filePath) else {
                return Promise(error: OWSAssertionError("Invalid image."))
            }
            return Promise.value(image)
        }
    }

    public func applyMedia(_ media: AnyObject) {
        AssertIsOnMainThread()

        if shouldBeRenderedByYY {
            guard let image = media as? YYImage else {
                owsFailDebug("Media has unexpected type: \(type(of: media))")
                return
            }
            imageView.image = image
        } else {
            guard let image = media as? UIImage else {
                owsFailDebug("Media has unexpected type: \(type(of: media))")
                return
            }
            imageView.image = image
        }
    }

    public func unloadMedia() {
        AssertIsOnMainThread()

        imageView.image = nil
    }
}
