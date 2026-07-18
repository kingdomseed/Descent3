// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum RevivalMobileContentRequest: Sendable {
    case loadActive(RevivalMobilePresentationRequest)
    case install(URL, RevivalMobilePresentationRequest)

    var presentationRequest: RevivalMobilePresentationRequest {
        switch self {
        case let .loadActive(request), let .install(_, request):
            request
        }
    }
}

enum RevivalMobileContentOutcome: Sendable {
    case loaded(ActivatedCanonicalPackage?)
    case failed(String)
}

func orderedRevivalMobileContentURLs<URLs: Sequence>(
    _ urls: URLs
) -> [URL] where URLs.Element == URL {
    urls.sorted { $0.absoluteString < $1.absoluteString }
}

private func performMobileContentRequest(
    _ request: RevivalMobileContentRequest,
    library: CanonicalPackageLibrary
) -> RevivalMobileContentOutcome {
    do {
        switch request {
        case .loadActive:
            return .loaded(try library.loadActive())
        case let .install(candidateURL, _):
            guard candidateURL.startAccessingSecurityScopedResource() else {
                return .failed(
                    "The selected file provider did not grant access. Choose the canonical package again from Files."
                )
            }
            defer { candidateURL.stopAccessingSecurityScopedResource() }
            return .loaded(try library.installAndActivate(from: candidateURL))
        }
    } catch {
        return .failed(error.localizedDescription)
    }
}

@MainActor
final class RevivalMobileContentCoordinator {
    typealias Completion = @MainActor (
        RevivalMobileContentOutcome,
        RevivalMobileContentRequest
    ) -> Void

    private struct PendingRequest {
        let request: RevivalMobileContentRequest
        let completion: Completion
    }

    private let library: CanonicalPackageLibrary
    private var requests = CanonicalPackageRequestQueue<PendingRequest>()

    init(library: CanonicalPackageLibrary = .revivalMobile) {
        self.library = library
    }

    func prepareForUse() throws {
        try library.prepareForUse()
        try library.excludeReimportableContentFromBackup()
    }

    func enqueue(
        _ request: RevivalMobileContentRequest,
        completion: @escaping Completion
    ) {
        requests.append(.init(request: request, completion: completion))
        processNextRequest()
    }

    private func processNextRequest() {
        guard let pending = requests.startNextIfIdle() else { return }
        let library = library
        let request = pending.request
        Task { @MainActor [weak self, library, pending, request] in
            let outcome = await Task.detached(priority: .userInitiated) {
                performMobileContentRequest(request, library: library)
            }.value
            guard let self else { return }
            defer {
                requests.finishCurrent()
                processNextRequest()
            }
            pending.completion(outcome, request)
        }
    }
}

struct RevivalMobilePresentationRequest: Equatable, Sendable {
    fileprivate let lifecycleEpoch: UInt64
}

struct RevivalMobilePresentationState: Sendable {
    private enum Phase: Sendable {
        case background
        case foregroundInactive
        case active
        case disconnected
    }

    private var phase: Phase = .background
    private var lifecycleEpoch: UInt64 = 0
    private(set) var hasPresentation = false

    var submissionsShouldBePaused: Bool {
        phase != .active || !hasPresentation
    }

    mutating func willEnterForeground() -> RevivalMobilePresentationRequest? {
        guard phase != .disconnected else {
            return nil
        }
        phase = .foregroundInactive
        return beginPresentationRequest()
    }

    mutating func didBecomeActive() {
        guard phase == .foregroundInactive else {
            return
        }
        phase = .active
    }

    mutating func willResignActive() {
        guard phase == .active else {
            return
        }
        phase = .foregroundInactive
    }

    mutating func didEnterBackground() {
        guard phase != .disconnected else {
            return
        }
        phase = .background
        invalidatePresentation()
    }

    mutating func didReceiveMemoryWarning() {
        guard phase != .disconnected else {
            return
        }
        invalidatePresentation()
    }

    mutating func disconnect() {
        phase = .disconnected
        invalidatePresentation()
    }

    mutating func beginPresentationRequest() -> RevivalMobilePresentationRequest? {
        switch phase {
        case .foregroundInactive, .active:
            return RevivalMobilePresentationRequest(
                lifecycleEpoch: lifecycleEpoch
            )
        case .background, .disconnected:
            return nil
        }
    }

    func accepts(_ request: RevivalMobilePresentationRequest) -> Bool {
        switch phase {
        case .foregroundInactive, .active:
            request.lifecycleEpoch == lifecycleEpoch
        case .background, .disconnected:
            false
        }
    }

    mutating func didReplacePresentation(
        for request: RevivalMobilePresentationRequest
    ) -> Bool {
        guard accepts(request) else {
            return false
        }
        hasPresentation = true
        return !submissionsShouldBePaused
    }

    mutating func didFailReplacement(
        for request: RevivalMobilePresentationRequest,
        presentationRemainsAvailable: Bool
    ) -> Bool {
        guard accepts(request) else {
            return false
        }
        hasPresentation = presentationRemainsAvailable
        return !submissionsShouldBePaused
    }

    private mutating func invalidatePresentation() {
        lifecycleEpoch += 1
        hasPresentation = false
    }
}
