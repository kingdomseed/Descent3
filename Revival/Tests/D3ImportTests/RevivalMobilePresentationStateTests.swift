// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

final class RevivalMobilePresentationStateTests: XCTestCase {
    func testSceneURLBatchesHaveAStablePackageOrder() {
        let alpha = URL(fileURLWithPath: "/tmp/Alpha.revival")
        let beta = URL(fileURLWithPath: "/tmp/Beta.revival")

        XCTAssertEqual(
            orderedRevivalMobileContentURLs([beta, alpha]),
            [alpha, beta]
        )
        XCTAssertEqual(
            orderedRevivalMobileContentURLs([alpha, beta]),
            [alpha, beta]
        )
    }

    @MainActor
    func testApplicationContentCoordinatorContinuesFIFOAfterSceneRelease() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-mobile-coordinator-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let coordinator = RevivalMobileContentCoordinator(
            library: CanonicalPackageLibrary(rootURL: rootURL)
        )
        try coordinator.prepareForUse()

        var state = RevivalMobilePresentationState()
        let request = try XCTUnwrap(state.willEnterForeground())
        final class SceneOwner {}
        var firstScene: SceneOwner? = SceneOwner()
        weak let releasedScene = firstScene
        var completionOrder: [String] = []
        let secondCompletion = expectation(
            description: "second application-owned package request completes"
        )

        coordinator.enqueue(.loadActive(request)) { [weak firstScene] _, _ in
            XCTAssertNil(firstScene)
            completionOrder.append("first")
        }
        firstScene = nil
        coordinator.enqueue(.loadActive(request)) { _, _ in
            completionOrder.append("second")
            secondCompletion.fulfill()
        }

        await fulfillment(of: [secondCompletion], timeout: 2)
        XCTAssertNil(releasedScene)
        XCTAssertEqual(completionOrder, ["first", "second"])
    }

    func testForegroundRequestsRemainOrderedWithinLifecycleEpoch() {
        var state = RevivalMobilePresentationState()

        let activeReload = state.willEnterForeground()
        XCTAssertNotNil(activeReload)
        state.didBecomeActive()

        let queuedInstall = state.beginPresentationRequest()
        XCTAssertNotNil(queuedInstall)
        XCTAssertTrue(state.accepts(activeReload!))
        XCTAssertTrue(state.didReplacePresentation(for: activeReload!))
        XCTAssertTrue(
            state.didFailReplacement(
                for: queuedInstall!,
                presentationRemainsAvailable: true
            )
        )
        XCTAssertTrue(state.hasPresentation)
        XCTAssertFalse(state.submissionsShouldBePaused)
    }

    func testMobilePresentationStateAcceptsOnlyCurrentForegroundReplacement() {
        var state = RevivalMobilePresentationState()

        XCTAssertTrue(state.submissionsShouldBePaused)

        let launchRequest = state.willEnterForeground()
        XCTAssertNotNil(launchRequest)
        state.didBecomeActive()
        XCTAssertTrue(state.submissionsShouldBePaused)
        XCTAssertTrue(state.didReplacePresentation(for: launchRequest!))
        XCTAssertFalse(state.submissionsShouldBePaused)

        let failedRequest = state.beginPresentationRequest()
        XCTAssertNotNil(failedRequest)
        XCTAssertTrue(
            state.didFailReplacement(
                for: failedRequest!,
                presentationRemainsAvailable: true
            )
        )
        XCTAssertTrue(state.hasPresentation)

        state.willResignActive()
        XCTAssertTrue(state.submissionsShouldBePaused)
        let inactiveRequest = state.beginPresentationRequest()
        XCTAssertNotNil(inactiveRequest)
        state.didEnterBackground()
        XCTAssertFalse(state.accepts(inactiveRequest!))
        XCTAssertFalse(state.hasPresentation)

        let foregroundRequest = state.willEnterForeground()
        XCTAssertNotNil(foregroundRequest)
        state.didBecomeActive()
        state.didReceiveMemoryWarning()
        XCTAssertFalse(state.accepts(foregroundRequest!))
        XCTAssertTrue(state.submissionsShouldBePaused)

        let finalRequest = state.beginPresentationRequest()
        XCTAssertNotNil(finalRequest)
        state.disconnect()
        XCTAssertFalse(state.accepts(finalRequest!))
        XCTAssertTrue(state.submissionsShouldBePaused)
    }
}
