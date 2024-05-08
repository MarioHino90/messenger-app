//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import LibSignalClient
import SignalServiceKit
import SignalRingRTC
import SignalUI

enum CallMemberErrorState {
    case blocked(SignalServiceAddress)
    case noMediaKeys(SignalServiceAddress)
}

protocol CallMemberErrorPresenter: AnyObject {
    func presentErrorSheet(for error: CallMemberErrorState)
}

class GroupCallMemberView: UIView, CallMemberView_GroupBridge {
    weak var errorPresenter: CallMemberErrorPresenter?
    let noVideoView = UIView()

    let backgroundAvatarView = UIImageView()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    let muteIndicatorImage = UIImageView()

    lazy var muteLeadingConstraint = muteIndicatorImage.autoPinEdge(toSuperviewEdge: .leading, withInset: muteInsets)
    lazy var muteBottomConstraint = muteIndicatorImage.autoPinEdge(toSuperviewEdge: .bottom, withInset: muteInsets)
    lazy var muteHeightConstraint = muteIndicatorImage.autoSetDimension(.height, toSize: muteHeight)

    var muteInsets: CGFloat {
        layoutIfNeeded()

        if width > 102 {
            return 9
        } else {
            return 4
        }
    }

    var muteHeight: CGFloat {
        layoutIfNeeded()

        if width > 200 && UIDevice.current.isIPad {
            return 20
        } else {
            return 16
        }
    }

    init() {
        super.init(frame: .zero)

        backgroundColor = .ows_gray90
        clipsToBounds = true

        addSubview(noVideoView)
        noVideoView.autoPinEdgesToSuperviewEdges()

        let overlayView = UIView()
        overlayView.backgroundColor = .ows_blackAlpha40
        noVideoView.addSubview(overlayView)
        overlayView.autoPinEdgesToSuperviewEdges()

        backgroundAvatarView.contentMode = .scaleAspectFill
        noVideoView.addSubview(backgroundAvatarView)
        backgroundAvatarView.autoPinEdgesToSuperviewEdges()

        noVideoView.addSubview(blurView)
        blurView.autoPinEdgesToSuperviewEdges()

        muteIndicatorImage.contentMode = .scaleAspectFit
        muteIndicatorImage.setTemplateImageName("mic-slash-fill-28", tintColor: .ows_white)
        addSubview(muteIndicatorImage)
        muteIndicatorImage.autoMatch(.width, to: .height, of: muteIndicatorImage)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateOrientationForPhone),
                                               name: CallService.phoneOrientationDidChange,
                                               object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func updateOrientationForPhone(_ notification: Notification) {
        let rotationAngle = notification.object as! CGFloat

        if window == nil {
            rotateForPhoneOrientation(rotationAngle)
        } else {
            UIView.animate(withDuration: 0.3) {
                self.rotateForPhoneOrientation(rotationAngle)
            }
        }
    }

    fileprivate func rotateForPhoneOrientation(_ rotationAngle: CGFloat) {
        self.muteIndicatorImage.transform = CGAffineTransform(rotationAngle: rotationAngle)
    }

    // MARK: - CallMemberView_GroupBridge

    // Protocol methods used while migrating from `GroupCallMemberView`
    // to unified `CallMemberView`.

    var associatedCallMemberVideoView: CallMemberVideoView? { return nil }
    var isCallMinimized: Bool = false
    func cleanupVideoViews() { /* Implemented by subclass if applicable */ }
    func applyChangesToCallMemberViewAndVideoView(startWithVideoView: Bool = false, apply: (UIView) -> Void) {
        apply(self)
    }
    func configureRemoteVideo(device: RemoteDeviceState, context: CallMemberVisualContext) { /* Implemented by subclass if applicable */ }
    func clearConfiguration() { /* Implemented by subclass if applicable */ }
}

class GroupCallRemoteMemberView: GroupCallMemberView {
    private weak var videoView: GroupCallRemoteVideoView?

    var deferredReconfigTimer: Timer?
    let errorView = GroupCallErrorView()
    let spinner = UIActivityIndicatorView(style: .large)
    let avatarView = ConversationAvatarView(localUserDisplayMode: .asUser, badged: false)

    override var isCallMinimized: Bool {
        didSet {
            // Currently only updated for the speaker view, since that's the only visible cell
            // while minimized.
            errorView.forceCompactAppearance = isCallMinimized
            errorView.isUserInteractionEnabled = !isCallMinimized
        }
    }

    override var bounds: CGRect {
        didSet {
            let didChange = bounds != oldValue
            if didChange {
                updateDimensions()
            }
        }
    }

    override var frame: CGRect {
        didSet {
            let didChange = frame != oldValue
            if didChange {
                updateDimensions()
            }
        }
    }

    var avatarDiameter: UInt {
        // This must not call layoutIfNeeded(); it should pick a diameter based on the most recent width.
        // Otherwise, we can end up re-layout-ing multiple times when reconfiguring,
        // and avatarView may try to open a read transaction while we're already in one.

        if width > 180 {
            return 112
        } else if width > 102 {
            return 96
        } else if width > 48 {
            return UInt(width) - 36
        } else {
            return 16
        }
    }

    let context: CallMemberVisualContext

    init(context: CallMemberVisualContext) {
        self.context = context
        super.init()

        noVideoView.insertSubview(avatarView, belowSubview: muteIndicatorImage)
        noVideoView.insertSubview(errorView, belowSubview: muteIndicatorImage)
        noVideoView.insertSubview(spinner, belowSubview: muteIndicatorImage)

        avatarView.autoCenterInSuperview()
        errorView.autoPinEdgesToSuperviewEdges()
        spinner.autoCenterInSuperview()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var hasBeenConfigured = false
    func configure(call: SignalCall, device: RemoteDeviceState) {
        hasBeenConfigured = true
        deferredReconfigTimer?.invalidate()

        let (profileImage, isRemoteDeviceBlocked) = databaseStorage.read { transaction -> (UIImage?, Bool) in
            let updatedSize = avatarDiameter
            avatarView.update(transaction) { config in
                config.dataSource = .address(device.address)
                config.sizeClass = .customDiameter(updatedSize)
            }

            let profileImage = self.contactsManagerImpl.avatarImage(forAddress: device.address,
                                                                    shouldValidate: true,
                                                                    transaction: transaction)
            let isBlocked = blockingManager.isAddressBlocked(device.address, transaction: transaction)
            return (profileImage, isBlocked)
        }

        backgroundAvatarView.image = profileImage

        muteIndicatorImage.isHidden = context == .speaker || device.audioMuted != true
        muteLeadingConstraint.constant = muteInsets
        muteBottomConstraint.constant = -muteInsets
        muteHeightConstraint.constant = muteHeight

        noVideoView.backgroundColor = AvatarTheme.forAddress(device.address).backgroundColor

        configureRemoteVideo(device: device, context: context)
        let errorDeferralInterval: TimeInterval = 5.0
        let addedDate = Date(millisecondsSince1970: device.addedTime)
        let connectionDuration = -addedDate.timeIntervalSinceNow

        // Hide these views. They'll be unhidden below.
        [errorView, avatarView, videoView, spinner].forEach { $0?.isHidden = true }

        if !device.mediaKeysReceived, !isRemoteDeviceBlocked, connectionDuration < errorDeferralInterval {
            // No media keys, but that's expected since we just joined the call.
            // Schedule a timer to re-check and show a spinner in the meantime
            spinner.isHidden = false
            if !spinner.isAnimating { spinner.startAnimating() }

            let configuredDemuxId = device.demuxId
            let scheduledInterval = errorDeferralInterval - connectionDuration
            deferredReconfigTimer = Timer.scheduledTimer(
                withTimeInterval: scheduledInterval,
                repeats: false,
                block: { [weak self] _ in
                guard let self = self else { return }
                guard call.isGroupCall, let groupCall = call.groupCall else { return }
                guard let updatedState = groupCall.remoteDeviceStates.values
                        .first(where: { $0.demuxId == configuredDemuxId }) else { return }
                self.configure(call: call, device: updatedState)
            })

        } else if !device.mediaKeysReceived {
            // No media keys. Display error view
            errorView.isHidden = false
            configureErrorView(for: device.address, isBlocked: isRemoteDeviceBlocked)

        } else if let videoView = videoView, device.videoTrack != nil {
            // We have a video track! If we don't know the mute state, show both.
            // Otherwise, show one or the other.
            videoView.isHidden = (device.videoMuted == true)
            avatarView.isHidden = (device.videoMuted == false)

        } else {
            // No video. Display avatar
            avatarView.isHidden = false
        }
    }

    override func clearConfiguration() {
        deferredReconfigTimer?.invalidate()

        cleanupVideoViews()

        noVideoView.backgroundColor = .ows_black
        backgroundAvatarView.image = nil
        avatarView.reset()

        [errorView, spinner, muteIndicatorImage].forEach { $0.isHidden = true }
    }

    private func updateDimensions() {
        guard hasBeenConfigured else { return }
        videoView?.frame = bounds
        muteLeadingConstraint.constant = muteInsets
        muteBottomConstraint.constant = -muteInsets
        muteHeightConstraint.constant = muteHeight

        avatarView.updateWithSneakyTransactionIfNecessary { config in
            config.sizeClass = .customDiameter(avatarDiameter)
        }
    }

    override func cleanupVideoViews() {
        if videoView?.superview == self { videoView?.removeFromSuperview() }
        videoView = nil
    }

    override func configureRemoteVideo(device: RemoteDeviceState, context: CallMemberVisualContext) {
        if videoView?.superview == self { videoView?.removeFromSuperview() }
        let callService = AppEnvironment.shared.callService!
        let newVideoView = callService.groupCallRemoteVideoManager.remoteVideoView(for: device, context: context)
        insertSubview(newVideoView, belowSubview: muteIndicatorImage)
        newVideoView.frame = bounds
        newVideoView.isScreenShare = device.sharingScreen == true
        videoView = newVideoView
        owsAssertDebug(videoView != nil, "Missing remote video view")
    }

    func configureErrorView(for address: SignalServiceAddress, isBlocked: Bool) {
        let displayName: String
        if address.isLocalAddress {
            displayName = OWSLocalizedString(
                "GROUP_CALL_YOU_ON_ANOTHER_DEVICE",
                comment: "Text describing the local user in the group call members sheet when connected from another device.")
        } else {
            displayName = databaseStorage.read { tx in self.contactsManager.displayName(for: address, tx: tx).resolvedValue() }
        }

        let blockFormat = OWSLocalizedString(
            "GROUP_CALL_BLOCKED_USER_FORMAT",
            comment: "String displayed in group call grid cell when a user is blocked. Embeds {user's name}")
        let missingKeyFormat = OWSLocalizedString(
            "GROUP_CALL_MISSING_MEDIA_KEYS_FORMAT",
            comment: "String displayed in cell when media from a user can't be displayed in group call grid. Embeds {user's name}")

        let labelFormat = isBlocked ? blockFormat : missingKeyFormat
        let label = String(format: labelFormat, arguments: [displayName])
        let image = isBlocked ? UIImage(named: "block") : UIImage(named: "error-circle-fill")

        errorView.iconImage = image
        errorView.labelText = label
        errorView.userTapAction = { [weak self] _ in
            guard let self = self else { return }

            if isBlocked {
                self.errorPresenter?.presentErrorSheet(for: .blocked(address))
            } else {
                self.errorPresenter?.presentErrorSheet(for: .noMediaKeys(address))
            }
        }
    }

    fileprivate override func rotateForPhoneOrientation(_ rotationAngle: CGFloat) {
        super.rotateForPhoneOrientation(rotationAngle)
        self.avatarView.transform = CGAffineTransform(rotationAngle: rotationAngle)
    }
}

extension RemoteDeviceState {
    var aci: Aci { Aci(fromUUID: userId) }
    var address: SignalServiceAddress { SignalServiceAddress(aci) }
}
