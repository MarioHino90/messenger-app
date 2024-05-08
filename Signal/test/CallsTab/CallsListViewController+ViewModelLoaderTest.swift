//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
import SignalServiceKit

@testable import Signal

final class CallsListViewControllerViewModelLoaderTest: XCTestCase {
    typealias CallViewModel = CallsListViewController.CallViewModel
    typealias ViewModelLoader = CallsListViewController.ViewModelLoader

    private var viewModelLoader: ViewModelLoader!

    private var mockDB: MockDB!
    private var mockCallRecordLoader: MockCallRecordLoader!
    private lazy var createCallViewModelBlock: ViewModelLoader.CreateCallViewModelBlock! = {
        self.createCallViewModel(primaryCallRecord: $0, coalescedCallRecords: $1, tx: $2)
    }
    private lazy var fetchCallRecordBlock: ViewModelLoader.FetchCallRecordBlock! = { (callRecordId, tx) -> CallRecord? in
        return self.mockCallRecordLoader.callRecordsById[callRecordId]
    }

    private func createCallViewModel(
        primaryCallRecord: CallRecord,
        coalescedCallRecords: [CallRecord],
        tx: DBReadTransaction
    ) -> CallViewModel {
        let recipientType: CallViewModel.RecipientType = {
            switch primaryCallRecord.callStatus {
            case .individual:
                return .individual(type: .audio, contactThread: TSContactThread(
                    contactUUID: UUID().uuidString,
                    contactPhoneNumber: nil
                ))
            case .group:
                return .group(groupThread: TSGroupThread.forUnitTest())
            }
        }()

        let direction: CallViewModel.Direction = {
            if primaryCallRecord.callStatus.isMissedCall {
                return .missed
            }

            switch primaryCallRecord.callDirection {
            case .incoming: return .incoming
            case .outgoing: return .outgoing
            }
        }()

        return CallViewModel(
            primaryCallRecord: primaryCallRecord,
            coalescedCallRecords: coalescedCallRecords,
            title: "Hey, I just met you, and this is crazy, but here's my number, so call me maybe?",
            recipientType: recipientType,
            direction: direction,
            state: .ended
        )
    }

    private func setUpViewModelLoader(
        viewModelPageSize: UInt,
        maxCachedViewModelCount: Int,
        maxCoalescedCallsInOneViewModel: UInt = 100
    ) {
        viewModelLoader = ViewModelLoader(
            callRecordLoader: mockCallRecordLoader,
            createCallViewModelBlock: { self.createCallViewModelBlock($0, $1, $2) },
            fetchCallRecordBlock: { self.fetchCallRecordBlock($0, $1) },
            viewModelPageSize: viewModelPageSize,
            maxCachedViewModelCount: maxCachedViewModelCount,
            maxCoalescedCallsInOneViewModel: maxCoalescedCallsInOneViewModel
        )
    }

    private var loadedCallIds: [[UInt64]] {
        return viewModelLoader.loadedViewModelReferences.allElements.map { reference -> [UInt64] in
            return reference.containedIds.map { $0.callId }
        }
    }

    private func loadMore(direction: ViewModelLoader.LoadDirection) -> Bool {
        return mockDB.read { viewModelLoader.loadMore(direction: direction, tx: $0) }
    }

    private func loadUntilCached(loadedViewModelReferenceIndex: Int) {
        mockDB.read {
            viewModelLoader.loadUntilCached(loadedViewModelReferenceIndex: loadedViewModelReferenceIndex, tx: $0)
        }
    }

    private func assertCached(loadedViewModelReferenceIndices: Range<Int>) {
        XCTAssertFalse(
            viewModelLoader.hasCachedViewModel(loadedViewModelReferenceIndex: loadedViewModelReferenceIndices.lowerBound - 1),
            "Had cached view model outside given range! Idx: \(loadedViewModelReferenceIndices.lowerBound - 1)"
        )
        XCTAssertFalse(
            viewModelLoader.hasCachedViewModel(loadedViewModelReferenceIndex: loadedViewModelReferenceIndices.upperBound),
            "Had cached view model outside given range! Idx: \(loadedViewModelReferenceIndices.upperBound)"
        )

        for index in loadedViewModelReferenceIndices {
            XCTAssertTrue(
                viewModelLoader.hasCachedViewModel(loadedViewModelReferenceIndex: index),
                "Missing cached view model for index \(index)!"
            )
        }
    }

    private func assertCachedCallIds(
        _ callIds: [UInt64],
        atLoadedViewModelReferenceIndex loadedViewModelReferenceIndex: Int
    ) {
        guard let cachedViewModel = viewModelLoader.getCachedViewModel(loadedViewModelReferenceIndex: loadedViewModelReferenceIndex) else {
            XCTFail("Missing cached view model entirely!")
            return
        }

        XCTAssertEqual(callIds, cachedViewModel.allCallRecords.map { $0.callId })
    }

    private func assertLoadedCallIds(_ callIdsByReference: [UInt64]...) {
        var callIdsByReference = callIdsByReference

        for reference in viewModelLoader.loadedViewModelReferences.allElements {
            let expectedCallIds = callIdsByReference.popFirst()
            XCTAssertEqual(expectedCallIds, reference.containedIds.map { $0.callId })
        }
        XCTAssertTrue(callIdsByReference.isEmpty)
    }

    override func setUp() {
        mockDB = MockDB()
        mockCallRecordLoader = MockCallRecordLoader()
    }

    func testLoadingNoCallRecords() {
        setUpViewModelLoader(viewModelPageSize: 10, maxCachedViewModelCount: 30)

        XCTAssertFalse(loadMore(direction: .older))
        XCTAssertTrue(viewModelLoader.loadedViewModelReferences.isEmpty)
        XCTAssertFalse(viewModelLoader.hasCachedViewModel(loadedViewModelReferenceIndex: 0))

        XCTAssertFalse(loadMore(direction: .newer))
        XCTAssertTrue(viewModelLoader.loadedViewModelReferences.isEmpty)
        XCTAssertFalse(viewModelLoader.hasCachedViewModel(loadedViewModelReferenceIndex: 0))
    }

    func testBasicCoalescingRules() {
        setUpViewModelLoader(viewModelPageSize: 100, maxCachedViewModelCount: 300)

        var timestamp = SequentialTimestampBuilder()

        mockCallRecordLoader.callRecords = [
            /// Yes coalescing if inside time window, same thread, same direction, same missed-call status.
            .fixture(callId: 99, timestamp: timestamp.uncoalescable(), threadRowId: 0, direction: .incoming, status: .group(.ringingMissed)),
            .fixture(callId: 98, timestamp: timestamp.coalescable(), threadRowId: 0, direction: .incoming, status: .group(.ringingMissed)),
            .fixture(callId: 97, timestamp: timestamp.coalescable(), threadRowId: 0, direction: .incoming, status: .group(.ringingMissed)),
            .fixture(callId: 96, timestamp: timestamp.coalescable(), threadRowId: 0, direction: .incoming, status: .group(.ringingMissed)),
            .fixture(callId: 95, timestamp: timestamp.coalescable(), threadRowId: 1, direction: .outgoing, status: .group(.ringingAccepted)),
            .fixture(callId: 94, timestamp: timestamp.coalescable(), threadRowId: 1, direction: .outgoing, status: .group(.ringingAccepted)),
            .fixture(callId: 93, timestamp: timestamp.coalescable(), threadRowId: 1, direction: .outgoing, status: .group(.ringingAccepted)),
            .fixture(callId: 92, timestamp: timestamp.coalescable(), threadRowId: 1, direction: .outgoing, status: .group(.ringingAccepted)),

            /// No coalescing outside of the time window.
            .fixture(callId: 0, timestamp: timestamp.uncoalescable(), threadRowId: 0, direction: .incoming, status: .group(.joined)),
            .fixture(callId: 1, timestamp: timestamp.uncoalescable(), threadRowId: 0, direction: .incoming, status: .group(.joined)),

            /// No coalescing across threads.
            .fixture(callId: 2, timestamp: timestamp.uncoalescable(), threadRowId: 1, direction: .incoming, status: .group(.joined)),
            .fixture(callId: 3, timestamp: timestamp.coalescable(), threadRowId: 2, direction: .incoming, status: .group(.joined)),

            /// No coalescing across direction.
            .fixture(callId: 4, timestamp: timestamp.uncoalescable(), threadRowId: 1, direction: .incoming, status: .group(.joined)),
            .fixture(callId: 5, timestamp: timestamp.coalescable(), threadRowId: 2, direction: .incoming, status: .group(.joined)),

            /// No coalescing across missed-call status.
            .fixture(callId: 6, timestamp: timestamp.uncoalescable(), threadRowId: 3, direction: .incoming, status: .individual(.incomingMissed)),
            .fixture(callId: 7, timestamp: timestamp.coalescable(), threadRowId: 3, direction: .incoming, status: .individual(.accepted)),

            /// No coalsecing if there's an intervening call.
            .fixture(callId: 8, timestamp: timestamp.uncoalescable(), threadRowId: 3, direction: .incoming, status: .individual(.incomingMissed)),
            .fixture(callId: 9, timestamp: timestamp.coalescable(), threadRowId: 3, direction: .incoming, status: .individual(.accepted)),
            .fixture(callId: 10, timestamp: timestamp.coalescable(), threadRowId: 3, direction: .incoming, status: .individual(.incomingMissed)),
        ]

        XCTAssertTrue(loadMore(direction: .older))
        XCTAssertEqual(loadedCallIds, [
            [99, 98, 97, 96],
            [95, 94, 93, 92],
            [0], [1], [2], [3], [4], [5], [6], [7], [8], [9], [10],
        ])
        assertCached(loadedViewModelReferenceIndices: 0..<viewModelLoader.loadedViewModelReferences.count)
    }

    func testScrollingBackAndForthThroughMultiplePages() {
        var timestamp = SequentialTimestampBuilder()

        /// Add 9 call view models' worth of call records to the mock. The 0th,
        /// 3rd, and 6th will be a coalesced call view model.
        mockCallRecordLoader.callRecords = (1...9).flatMap { idx -> [CallRecord] in
            if idx % 3 == 0 {
                /// Add a coalescable pair of calls.
                return [
                    .fixture(callId: UInt64(idx), timestamp: timestamp.uncoalescable(), threadRowId: Int64(idx)),
                    .fixture(callId: UInt64(idx * 1000), timestamp: timestamp.coalescable(), threadRowId: Int64(idx))
                ]
            } else {
                /// Add a single uncoalescable call.
                return [
                    .fixture(callId: UInt64(idx), timestamp: timestamp.uncoalescable(), threadRowId: Int64(idx))
                ]
            }
        }

        setUpViewModelLoader(viewModelPageSize: 3, maxCachedViewModelCount: 6)

        /// Scroll backwards three pages, thereby dropping the first-loaded view
        /// models.

        XCTAssertTrue(loadMore(direction: .older))
        assertLoadedCallIds([1], [2], [3, 3000])
        assertCached(loadedViewModelReferenceIndices: 0..<3)
        assertCachedCallIds([1], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([2], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([3, 3000], atLoadedViewModelReferenceIndex: 2)

        XCTAssertTrue(loadMore(direction: .older))
        assertLoadedCallIds([1], [2], [3, 3000], [4], [5], [6, 6000])
        assertCached(loadedViewModelReferenceIndices: 0..<6)
        assertCachedCallIds([1], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([2], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([3, 3000], atLoadedViewModelReferenceIndex: 2)
        assertCachedCallIds([4], atLoadedViewModelReferenceIndex: 3)
        assertCachedCallIds([5], atLoadedViewModelReferenceIndex: 4)
        assertCachedCallIds([6, 6000], atLoadedViewModelReferenceIndex: 5)

        XCTAssertTrue(loadMore(direction: .older))
        assertLoadedCallIds([1], [2], [3, 3000], [4], [5], [6, 6000], [7], [8], [9, 9000])
        assertCached(loadedViewModelReferenceIndices: 3..<9)
        assertCachedCallIds([4], atLoadedViewModelReferenceIndex: 3)
        assertCachedCallIds([5], atLoadedViewModelReferenceIndex: 4)
        assertCachedCallIds([6, 6000], atLoadedViewModelReferenceIndex: 5)
        assertCachedCallIds([7], atLoadedViewModelReferenceIndex: 6)
        assertCachedCallIds([8], atLoadedViewModelReferenceIndex: 7)
        assertCachedCallIds([9, 9000], atLoadedViewModelReferenceIndex: 8)

        XCTAssertFalse(loadMore(direction: .older))
        assertLoadedCallIds([1], [2], [3, 3000], [4], [5], [6, 6000], [7], [8], [9, 9000])
        assertCached(loadedViewModelReferenceIndices: 3..<9)
        assertCachedCallIds([4], atLoadedViewModelReferenceIndex: 3)
        assertCachedCallIds([5], atLoadedViewModelReferenceIndex: 4)
        assertCachedCallIds([6, 6000], atLoadedViewModelReferenceIndex: 5)
        assertCachedCallIds([7], atLoadedViewModelReferenceIndex: 6)
        assertCachedCallIds([8], atLoadedViewModelReferenceIndex: 7)
        assertCachedCallIds([9, 9000], atLoadedViewModelReferenceIndex: 8)

        /// Now, scroll forwards, thereby dropping the last-loaded view models.
        /// These loads won't load any brand-new calls, and will instead
        /// rehydrate already-loaded view model references.
        XCTAssertFalse(loadMore(direction: .newer))
        assertLoadedCallIds([1], [2], [3, 3000], [4], [5], [6, 6000], [7], [8], [9, 9000])
        assertCached(loadedViewModelReferenceIndices: 0..<6)
        assertCachedCallIds([1], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([2], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([3, 3000], atLoadedViewModelReferenceIndex: 2)
        assertCachedCallIds([4], atLoadedViewModelReferenceIndex: 3)
        assertCachedCallIds([5], atLoadedViewModelReferenceIndex: 4)
        assertCachedCallIds([6, 6000], atLoadedViewModelReferenceIndex: 5)

        XCTAssertFalse(loadMore(direction: .newer))
        assertLoadedCallIds([1], [2], [3, 3000], [4], [5], [6, 6000], [7], [8], [9, 9000])
        assertCached(loadedViewModelReferenceIndices: 0..<6)
        assertCachedCallIds([1], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([2], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([3, 3000], atLoadedViewModelReferenceIndex: 2)
        assertCachedCallIds([4], atLoadedViewModelReferenceIndex: 3)
        assertCachedCallIds([5], atLoadedViewModelReferenceIndex: 4)
        assertCachedCallIds([6, 6000], atLoadedViewModelReferenceIndex: 5)
    }

    /// Load a ton of calls, such that the cached view models have long ago
    /// dropped the first-loaded calls, and then simulate a super-fast scroll to
    /// the top, then the bottom, by loading until the first, then the last,
    /// calls are cached.
    func testLoadUntilCached() {
        setUpViewModelLoader(viewModelPageSize: 100, maxCachedViewModelCount: 300)
        var timestamp = SequentialTimestampBuilder()

        mockCallRecordLoader.callRecords = (1...5000).flatMap { idx -> [CallRecord] in
            if idx % 4 == 0 {
                /// Add a coalescable triplet of calls.
                return [
                    .fixture(callId: UInt64(idx), timestamp: timestamp.uncoalescable(), threadRowId: Int64(idx)),
                    .fixture(callId: UInt64(idx * 5000), timestamp: timestamp.coalescable(), threadRowId: Int64(idx)),
                    .fixture(callId: UInt64(idx * 5001), timestamp: timestamp.coalescable(), threadRowId: Int64(idx)),
                ]
            } else {
                /// Add a single uncoalescable call.
                return [
                    .fixture(callId: UInt64(idx), timestamp: timestamp.uncoalescable(), threadRowId: Int64(idx))
                ]
            }
        }

        for _ in 0..<50 {
            XCTAssertTrue(loadMore(direction: .older))
        }
        XCTAssertFalse(loadMore(direction: .older))
        assertCached(loadedViewModelReferenceIndices: 4700..<5000)

        loadUntilCached(loadedViewModelReferenceIndex: 0)
        assertCached(loadedViewModelReferenceIndices: 0..<300)

        loadUntilCached(loadedViewModelReferenceIndex: 4999)
        assertCached(loadedViewModelReferenceIndices: 4700..<5000)
    }

    func testNewerCallInserted() {
        setUpViewModelLoader(viewModelPageSize: 2, maxCachedViewModelCount: 4)
        var timestamp = SequentialTimestampBuilder()

        let timestampToInsert0 = timestamp.uncoalescable()
        let timestampToInsert1 = timestamp.coalescable()
        let timestampToInsert2 = timestamp.coalescable()

        mockCallRecordLoader.callRecords = [
            .fixture(callId: 3, timestamp: timestamp.coalescable()),
            .fixture(callId: 4, timestamp: timestamp.coalescable()),
            .fixture(callId: 5, timestamp: timestamp.coalescable()),
            .fixture(callId: 6, timestamp: timestamp.uncoalescable())
        ]

        XCTAssertTrue(loadMore(direction: .newer))
        assertCached(loadedViewModelReferenceIndices: 0..<2)
        assertCachedCallIds([3, 4, 5], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([6], atLoadedViewModelReferenceIndex: 1)

        XCTAssertFalse(loadMore(direction: .newer))
        assertCached(loadedViewModelReferenceIndices: 0..<2)
        assertCachedCallIds([3, 4, 5], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([6], atLoadedViewModelReferenceIndex: 1)

        /// If we insert a single new call record that can be coalesced into the
        /// existing first view model, it should be merged into the existing
        /// view model.
        mockCallRecordLoader.callRecords.insert(.fixture(callId: 2, timestamp: timestampToInsert2), at: 0)
        XCTAssertTrue(loadMore(direction: .newer))
        assertCached(loadedViewModelReferenceIndices: 0..<2)
        assertCachedCallIds([2, 3, 4, 5], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([6], atLoadedViewModelReferenceIndex: 1)

        /// If we then insert multiple new call records that can be coalesced,
        /// those should *not* be merged into the existing view model. That's a
        /// quirk of how the view model loader works – see comments in the
        /// implementation about it – but since it's an intentional behavior
        /// let's test it.
        mockCallRecordLoader.callRecords.insert(.fixture(callId: 1, timestamp: timestampToInsert1), at: 0)
        mockCallRecordLoader.callRecords.insert(.fixture(callId: 0, timestamp: timestampToInsert0), at: 0)
        XCTAssertTrue(loadMore(direction: .newer))
        assertCached(loadedViewModelReferenceIndices: 0..<4)
        assertCachedCallIds([0], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([1], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([2, 3, 4, 5], atLoadedViewModelReferenceIndex: 2)
        assertCachedCallIds([6], atLoadedViewModelReferenceIndex: 3)

        /// And now, finally, there's nothing new to load.
        XCTAssertFalse(loadMore(direction: .newer))
        assertCached(loadedViewModelReferenceIndices: 0..<4)
        assertCachedCallIds([0], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([1], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([2, 3, 4, 5], atLoadedViewModelReferenceIndex: 2)
        assertCachedCallIds([6], atLoadedViewModelReferenceIndex: 3)
    }

    func testRefreshingViewModels() {
        // Cache the default block, since we're gonna override it.
        let defaultFetchCallRecordBlock = fetchCallRecordBlock!

        setUpViewModelLoader(viewModelPageSize: 2, maxCachedViewModelCount: 2)
        var timestamp = SequentialTimestampBuilder()

        mockCallRecordLoader.callRecords = [
            .fixture(callId: 0, timestamp: timestamp.uncoalescable()),
            .fixture(callId: 1, timestamp: timestamp.coalescable()),

            .fixture(callId: 2, timestamp: timestamp.uncoalescable()),

            .fixture(callId: 3, timestamp: timestamp.uncoalescable()),
        ]

        XCTAssertTrue(loadMore(direction: .older))
        assertCached(loadedViewModelReferenceIndices: 0..<2)
        assertCachedCallIds([0, 1], atLoadedViewModelReferenceIndex: 0)
        assertCachedCallIds([2], atLoadedViewModelReferenceIndex: 1)

        var fetchedCallIds = [UInt64]()
        fetchCallRecordBlock = { callRecordId, tx -> CallRecord? in
            fetchedCallIds.append(callRecordId.callId)
            return defaultFetchCallRecordBlock(callRecordId, tx)
        }

        mockDB.read { tx in
            let firstViewModelIds: [CallRecord.ID] = [
                .fixture(callId: 0),
                .fixture(callId: 1),
            ]

            for callRecordId in firstViewModelIds {
                /// Asking to recreate for either call record ID in a coalesced
                /// view model should re-fetch all the calls in the view model.
                XCTAssertEqual(
                    viewModelLoader.refreshViewModels(
                        callRecordIds: [callRecordId], tx: tx
                    ),
                    [
                        .coalescedCalls(
                            primary: .fixture(callId: 0),
                            coalesced: [.fixture(callId: 1)]
                        )
                    ]
                )
                XCTAssertEqual(fetchedCallIds, [0, 1])
                fetchedCallIds = []
            }

            XCTAssertEqual(
                viewModelLoader.refreshViewModels(callRecordIds: [.fixture(callId: 2)], tx: tx),
                [.singleCall(.fixture(callId: 2))]
            )
            XCTAssertEqual(fetchedCallIds, [2])
            fetchedCallIds = []
        }

        /// Load across a partial page and drop that first coalesced view model.
        XCTAssertTrue(loadMore(direction: .older))
        assertCached(loadedViewModelReferenceIndices: 1..<3)
        assertCachedCallIds([2], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([3], atLoadedViewModelReferenceIndex: 2)

        /// If we ask to recreate for a call record ID that's not part of
        /// any cached view models, nothing should happen.
        fetchCallRecordBlock = { (_, _) in XCTFail("Unexpectedly tried to fetch!"); return nil }
        mockDB.read { tx in
            XCTAssertEqual(
                viewModelLoader.refreshViewModels(callRecordIds: [.fixture(callId: 0)], tx: tx),
                []
            )
            XCTAssertEqual(fetchedCallIds, [])
        }
    }

    func testDroppingViewModels() {
        setUpViewModelLoader(viewModelPageSize: 6, maxCachedViewModelCount: 6)
        var timestamp = SequentialTimestampBuilder()

        mockCallRecordLoader.callRecords = [
            /// We won't delete this one, but it'll have been paged out.
            .fixture(callId: 99, timestamp: timestamp.uncoalescable()),

            /// We'll page this out before deleting it.
            .fixture(callId: 98, timestamp: timestamp.uncoalescable()),

            /// We'll have this paged in and won't delete it; see the next one.
            .fixture(callId: 0, timestamp: timestamp.uncoalescable()),

            /// We'll delete this (while having it paged in), which will
            /// technically make `callId: 0`  coalescable with
            /// `callIds: [1, 2, 3]` below, since there won't be any intervening
            /// calls. However, deleting does not prompt re-coalescing.
            .fixture(callId: 97, timestamp: timestamp.coalescable(), threadRowId: 1),

            /// We'll delete the primary call record from this view model.
            .fixture(callId: 1, timestamp: timestamp.coalescable()),
            .fixture(callId: 2, timestamp: timestamp.coalescable()),
            .fixture(callId: 3, timestamp: timestamp.coalescable()),

            /// We'll delete a coalesced call record from this view model.
            .fixture(callId: 4, timestamp: timestamp.uncoalescable()),
            .fixture(callId: 5, timestamp: timestamp.coalescable()),
            .fixture(callId: 6, timestamp: timestamp.coalescable()),

            /// We'll delete all the call records from this view model.
            .fixture(callId: 7, timestamp: timestamp.uncoalescable()),
            .fixture(callId: 8, timestamp: timestamp.coalescable()),
            .fixture(callId: 9, timestamp: timestamp.coalescable()),

            /// We won't delete this one :)
            .fixture(callId: 10, timestamp: timestamp.uncoalescable()),
            .fixture(callId: 11, timestamp: timestamp.coalescable()),
        ]

        XCTAssertTrue(loadMore(direction: .older))
        assertLoadedCallIds([99], [98], [0], [97], [1, 2, 3], [4, 5, 6])
        assertCached(loadedViewModelReferenceIndices: 0..<6)

        XCTAssertTrue(loadMore(direction: .older))
        assertLoadedCallIds([99], [98], [0], [97], [1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11])
        assertCached(loadedViewModelReferenceIndices: 2..<8)

        mockDB.read { tx in
            viewModelLoader.dropCalls(
                matching: [
                    .fixture(callId: 98),
                    .fixture(callId: 97, threadRowId: 1),
                    .fixture(callId: 1),
                    .fixture(callId: 5),
                    .fixture(callId: 7),
                    .fixture(callId: 8),
                    .fixture(callId: 9),
                ],
                tx: tx
            )
        }

        assertLoadedCallIds(
            [99],
            [0],
            [2, 3],
            [4, 6],
            [10, 11]
        )
        assertCached(loadedViewModelReferenceIndices: 1..<5)
        assertCachedCallIds([0], atLoadedViewModelReferenceIndex: 1)
        assertCachedCallIds([2, 3], atLoadedViewModelReferenceIndex: 2)
        assertCachedCallIds([4, 6], atLoadedViewModelReferenceIndex: 3)
        assertCachedCallIds([10, 11], atLoadedViewModelReferenceIndex: 4)
    }

    func testMaxCoalescedCallsInOneViewModel() {
        setUpViewModelLoader(viewModelPageSize: 3, maxCachedViewModelCount: 3, maxCoalescedCallsInOneViewModel: 3)
        var timestamp = SequentialTimestampBuilder()

        mockCallRecordLoader.callRecords = [
            .fixture(callId: 1, timestamp: timestamp.uncoalescable()),
            .fixture(callId: 2, timestamp: timestamp.coalescable()),
            .fixture(callId: 3, timestamp: timestamp.coalescable()),
            .fixture(callId: 4, timestamp: timestamp.coalescable()),
            .fixture(callId: 5, timestamp: timestamp.coalescable()),
            .fixture(callId: 6, timestamp: timestamp.coalescable()),
            .fixture(callId: 7, timestamp: timestamp.coalescable()),
        ]

        XCTAssertTrue(loadMore(direction: .older))
        assertLoadedCallIds([1, 2, 3], [4, 5, 6], [7])
        assertCached(loadedViewModelReferenceIndices: 0..<3)
    }
}

// MARK: - Mocks

private struct SequentialTimestampBuilder {
    private var current: UInt64 = Date().ows_millisecondsSince1970

    /// Generates a timestamp that is earlier than and coalescable with the
    /// previously-generated one.
    mutating func coalescable() -> UInt64 {
        current -= 1
        return current
    }

    /// Generates a timestamp earlier that is than and not coalescable with the
    /// previously-generated one.
    mutating func uncoalescable() -> UInt64 {
        let millisecondsOutsideCoalesceWindow = 4 * 1000 * UInt64(kHourInterval) + 1
        current -= millisecondsOutsideCoalesceWindow
        return current
    }
}

private extension CallRecord.ID {
    static func fixture(callId: UInt64, threadRowId: Int64 = 0) -> CallRecord.ID {
        return CallRecord.ID(
            callId: callId,
            threadRowId: threadRowId
        )
    }
}

private extension CallRecord {
    static func fixture(
        callId: UInt64,
        timestamp: UInt64,
        callType: CallRecord.CallType? = nil,
        threadRowId: Int64 = 0,
        direction: CallRecord.CallDirection = .incoming,
        status: CallRecord.CallStatus = .group(.joined)
    ) -> CallRecord {
        return CallRecord(
            callId: callId,
            interactionRowId: 0,
            threadRowId: threadRowId,
            callType: callType ?? {
                switch status {
                case .individual: return .audioCall
                case .group: return .groupCall
                }
            }(),
            callDirection: direction,
            callStatus: status,
            callBeganTimestamp: timestamp
        )
    }
}

private class MockCallRecordLoader: CallRecordLoader {
    private class Cursor: CallRecordCursor {
        private var callRecords: [CallRecord] = []

        init(_ callRecords: [CallRecord], direction: LoadDirection) {
            self.callRecords = callRecords
        }

        func next() throws -> CallRecord? { return callRecords.popFirst() }
    }

    var callRecords: [CallRecord] {
        get { callRecordsDescending }
        set {
            callRecordsDescending = newValue.sorted { $0.callBeganTimestamp > $1.callBeganTimestamp }
            callRecordsAscending = newValue.sorted { $0.callBeganTimestamp < $1.callBeganTimestamp }
            callRecordsById = Dictionary(
                newValue.map { ($0.id, $0) },
                uniquingKeysWith: { new, _ in return new}
            )
        }
    }

    private(set) var callRecordsById: [CallRecord.ID: CallRecord] = [:]
    private var callRecordsDescending: [CallRecord] = []
    private var callRecordsAscending: [CallRecord] = []

    private func applyLoadDirection(_ direction: LoadDirection) -> [CallRecord] {
        switch direction {
        case .olderThan(oldestCallTimestamp: nil):
            return callRecordsDescending
        case .olderThan(.some(let oldestCallTimestamp)):
            return callRecordsDescending.filter { $0.callBeganTimestamp < oldestCallTimestamp }
        case .newerThan(let newestCallTimestamp):
            return callRecordsAscending.filter { $0.callBeganTimestamp > newestCallTimestamp }
        }
    }

    func loadCallRecords(loadDirection: LoadDirection, tx: DBReadTransaction) -> CallRecordCursor {
        return Cursor(applyLoadDirection(loadDirection), direction: loadDirection)
    }
}
