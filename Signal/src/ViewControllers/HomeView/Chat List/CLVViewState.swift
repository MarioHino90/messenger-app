//
// Copyright 2021 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import SignalServiceKit
import SignalUI

class CLVViewState {

    let tableDataSource = CLVTableDataSource()

    let multiSelectState = MultiSelectState()

    let loadCoordinator = CLVLoadCoordinator()

    // MARK: - Caches

    let threadViewModelCache = LRUCache<String, ThreadViewModel>(maxSize: 32)
    let cellContentCache = LRUCache<String, CLVCellContentToken>(maxSize: 256)
    var conversationCellHeightCache: CGFloat?

    var spoilerAnimationManager = SpoilerAnimationManager()

    // MARK: - Views

    private(set) lazy var searchController = UISearchController(searchResultsController: searchResultsController)
    var searchBar: UISearchBar { searchController.searchBar }
    let searchResultsController = ConversationSearchViewController()
    let reminderViews = CLVReminderViews()
    let settingsButtonCreator = ChatListSettingsButtonState()
    let proxyButtonCreator = ChatListProxyButtonCreator(chatConnectionManager: DependenciesBridge.shared.chatConnectionManager)

    // MARK: - State

    let chatListMode: ChatListMode

    var shouldBeUpdatingView = false

    var shouldFocusSearchOnAppear = false

    var isViewVisible = false
    var hasEverAppeared = false

    var unreadPaymentNotificationsCount: UInt = 0 {
        didSet { settingsButtonCreator.updateState(hasUnreadPaymentNotification: unreadPaymentNotificationsCount > 0) }
    }
    var firstUnreadPaymentModel: TSPaymentModel?
    var lastKnownTableViewContentOffset: CGPoint?

    // MARK: - Initializer

    init(chatListMode: ChatListMode) {
        self.chatListMode = chatListMode
    }

    func configure() {
        tableDataSource.configure(viewState: self)
    }
}

// MARK: -

extension ChatListViewController {

    var tableDataSource: CLVTableDataSource { viewState.tableDataSource }

    var loadCoordinator: CLVLoadCoordinator { viewState.loadCoordinator }

    // MARK: - Caches

    var threadViewModelCache: LRUCache<String, ThreadViewModel> { viewState.threadViewModelCache }

    var cellContentCache: LRUCache<String, CLVCellContentToken> { viewState.cellContentCache }

    var conversationCellHeightCache: CGFloat? {
        get { viewState.conversationCellHeightCache }
        set { viewState.conversationCellHeightCache = newValue }
    }

    // MARK: - Views

    var tableView: CLVTableView { tableDataSource.tableView }
    var searchBar: UISearchBar { viewState.searchBar }
    var searchResultsController: ConversationSearchViewController { viewState.searchResultsController }

    // MARK: - State

    var renderState: CLVRenderState { viewState.tableDataSource.renderState }

    var numberOfInboxThreads: UInt { renderState.inboxCount }
    var numberOfArchivedThreads: UInt { renderState.archiveCount }

    var chatListMode: ChatListMode { viewState.chatListMode }

    var hasEverAppeared: Bool {
        get { viewState.hasEverAppeared }
        set { viewState.hasEverAppeared = newValue }
    }

    var lastKnownTableViewContentOffset: CGPoint? {
        get { viewState.lastKnownTableViewContentOffset }
        set { viewState.lastKnownTableViewContentOffset = newValue }
    }
}
