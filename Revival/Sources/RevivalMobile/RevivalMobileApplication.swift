// SPDX-License-Identifier: GPL-3.0-or-later

import MetalKit
import UIKit
import UniformTypeIdentifiers

private let canonicalContentTypeIdentifier =
    "org.descent3.revival.canonical-content"

@main
@MainActor
final class RevivalMobileApplicationDelegate: UIResponder, UIApplicationDelegate {
    let contentCoordinator = RevivalMobileContentCoordinator()
    private(set) var contentPreparationError: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]?
    ) -> Bool {
        do {
            try contentCoordinator.prepareForUse()
        } catch {
            contentPreparationError = error.localizedDescription
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "RevivalMobile",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = RevivalMobileSceneDelegate.self
        return configuration
    }
}

@MainActor
final class RevivalMobileSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var pendingContentURLs: [URL] = []

    private var viewController: RevivalMobileViewController? {
        window?.rootViewController as? RevivalMobileViewController
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        guard let applicationDelegate = UIApplication.shared.delegate
            as? RevivalMobileApplicationDelegate else {
            preconditionFailure("RevivalMobile application ownership is missing")
        }
        pendingContentURLs.append(
            contentsOf: orderedRevivalMobileContentURLs(
                connectionOptions.urlContexts.lazy.map(\.url)
            )
        )

        let viewController = RevivalMobileViewController(
            contentCoordinator: applicationDelegate.contentCoordinator,
            contentPreparationError: applicationDelegate.contentPreparationError
        )
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        viewController?.willEnterForeground()
        forwardPendingContentURLs()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        viewController?.didBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        viewController?.willResignActive()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        viewController?.didEnterBackground()
    }

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        pendingContentURLs.append(
            contentsOf: orderedRevivalMobileContentURLs(
                URLContexts.lazy.map(\.url)
            )
        )
        forwardPendingContentURLs()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        viewController?.shutdown()
        pendingContentURLs.removeAll()
        window = nil
    }

    private func forwardPendingContentURLs() {
        guard let viewController else { return }
        pendingContentURLs = pendingContentURLs.filter {
            !viewController.acceptCanonicalPackage(at: $0)
        }
    }
}

@MainActor
final class RevivalMobileViewController: UIViewController,
    UIDocumentPickerDelegate
{
    private let contentCoordinator: RevivalMobileContentCoordinator
    private let contentPreparationError: String?
    private let metalView = MTKView(frame: .zero)
    private let statusLabel = UILabel()
    private let importButton = UIButton(type: .system)
    private var presentationState = RevivalMobilePresentationState()
    private var libraryIsReady = false

    #if !targetEnvironment(simulator)
    private var renderer: MetalWorldRenderer?
    #endif

    init(
        contentCoordinator: RevivalMobileContentCoordinator,
        contentPreparationError: String?
    ) {
        self.contentCoordinator = contentCoordinator
        self.contentPreparationError = contentPreparationError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("RevivalMobile uses programmatic UIKit ownership")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureRenderer()
        prepareCanonicalLibrary()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        presentationState.didReceiveMemoryWarning()
        pausePresentation()
        #if !targetEnvironment(simulator)
        renderer?.unload()
        #endif
        setStatus(
            "The room presentation was unloaded for memory pressure. Installed content will reload after the next foreground transition.",
            isError: false
        )
    }

    func willEnterForeground() {
        guard libraryIsReady,
              let request = presentationState.willEnterForeground() else {
            return
        }
        enqueue(.loadActive(request))
    }

    func didBecomeActive() {
        presentationState.didBecomeActive()
        applyPresentationSubmissionState()
        #if !targetEnvironment(simulator)
        if !presentationState.submissionsShouldBePaused {
            renderer?.drawNow()
        }
        #endif
    }

    func willResignActive() {
        presentationState.willResignActive()
        pausePresentation()
    }

    func didEnterBackground() {
        presentationState.didEnterBackground()
        pausePresentation()
        #if !targetEnvironment(simulator)
        renderer?.unload()
        #endif
    }

    func shutdown() {
        presentationState.disconnect()
        pausePresentation()
        importButton.isEnabled = false
        libraryIsReady = false
        #if !targetEnvironment(simulator)
        renderer?.shutdown()
        renderer = nil
        #endif
    }

    @discardableResult
    func acceptCanonicalPackage(at packageURL: URL) -> Bool {
        guard libraryIsReady,
              let request = presentationState.beginPresentationRequest() else {
            return false
        }
        enqueue(.install(packageURL, request))
        return true
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let packageURL = urls.first else { return }
        guard acceptCanonicalPackage(at: packageURL) else {
            setStatus(
                "Revival cannot import content while this scene is in the background.",
                isError: true
            )
            return
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        setStatus(
            "Import cancelled. Previously installed content was left unchanged.",
            isError: false
        )
    }

    @objc private func chooseCanonicalPackage() {
        guard let canonicalContentType = UTType(canonicalContentTypeIdentifier) else {
            preconditionFailure("The canonical-content type is missing")
        }
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [canonicalContentType],
            asCopy: false
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func configureViews() {
        view.backgroundColor = .black

        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.autoResizeDrawable = true
        metalView.isPaused = true
        view.addSubview(metalView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Preparing installed canonical content…"
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        statusLabel.accessibilityLabel = "Revival content status"
        view.addSubview(statusLabel)

        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.setTitle("Choose Canonical Content", for: .normal)
        importButton.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        importButton.accessibilityHint =
            "Choose a canonical package produced by D3Import on a Mac."
        importButton.isEnabled = false
        importButton.addTarget(
            self,
            action: #selector(chooseCanonicalPackage),
            for: .touchUpInside
        )
        view.addSubview(importButton)

        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalView.topAnchor.constraint(equalTo: view.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 16
            ),
            statusLabel.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            statusLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            importButton.centerXAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.centerXAnchor
            ),
            importButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -12
            ),
            importButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    private func configureRenderer() {
        #if targetEnvironment(simulator)
        setStatus(
            "Choose canonical content to validate the mobile shell. Metal 4 room presentation requires a physical device.",
            isError: false
        )
        #else
        do {
            renderer = try MetalWorldRenderer(view: metalView)
            metalView.isPaused = true
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
        #endif
    }

    private func prepareCanonicalLibrary() {
        if let contentPreparationError {
            setStatus(
                "Could not prepare installed content: \(contentPreparationError). Relaunch Revival to retry recovery.",
                isError: true
            )
            return
        }
        libraryIsReady = true
        importButton.isEnabled = true
    }

    private func enqueue(_ request: RevivalMobileContentRequest) {
        switch request {
        case .loadActive:
            setStatus("Loading installed canonical content…", isError: false)
        case let .install(packageURL, _):
            setStatus(
                "Importing \(packageURL.lastPathComponent)…",
                isError: false
            )
        }

        contentCoordinator.enqueue(request) { [weak self] outcome, request in
            self?.handle(outcome, for: request)
        }
    }

    private func handle(
        _ outcome: RevivalMobileContentOutcome,
        for request: RevivalMobileContentRequest
    ) {
        guard presentationState.accepts(request.presentationRequest) else {
            return
        }

        switch outcome {
        case let .failed(message):
            let remainsAvailable: Bool
            #if targetEnvironment(simulator)
            remainsAvailable = false
            #else
            remainsAvailable = renderer?.hasPresentation ?? false
            #endif
            let shouldResume = presentationState.didFailReplacement(
                for: request.presentationRequest,
                presentationRemainsAvailable: remainsAvailable
            )
            metalView.isPaused = !shouldResume
            setStatus(
                "Could not acquire canonical content: \(message) Previously active content was left unchanged.",
                isError: true
            )

        case .loaded(nil):
            _ = presentationState.didFailReplacement(
                for: request.presentationRequest,
                presentationRemainsAvailable: false
            )
            pausePresentation()
            setStatus(
                "Choose a canonical package produced by D3Import on a Mac.",
                isError: false
            )

        case let .loaded(activation?):
            present(activation, for: request.presentationRequest)
        }
    }

    private func present(
        _ activation: ActivatedCanonicalPackage,
        for request: RevivalMobilePresentationRequest
    ) {
        let playerView = defaultPlayerView(in: activation.level)
        let summary =
            "\(activation.level.metadata.name) — \(activation.level.rooms.count) rooms — source room \(playerView.roomSourceIndex) — \(activation.reference.identitySHA256.prefix(12))"

        #if targetEnvironment(simulator)
        _ = presentationState.didFailReplacement(
            for: request,
            presentationRemainsAvailable: false
        )
        pausePresentation()
        setStatus(
            "\(summary) — canonical content is ready; Metal 4 presentation requires a physical device.",
            isError: false
        )
        #else
        guard let renderer else {
            _ = presentationState.didFailReplacement(
                for: request,
                presentationRemainsAvailable: false
            )
            pausePresentation()
            setStatus(
                "\(summary) — the Metal renderer is unavailable.",
                isError: true
            )
            return
        }
        do {
            try renderer.replace(
                level: activation.level,
                playerView: playerView
            )
            let shouldResume = presentationState.didReplacePresentation(for: request)
            metalView.isPaused = !shouldResume
            setStatus(summary, isError: false)
            if shouldResume {
                renderer.drawNow()
            }
        } catch {
            let shouldResume = presentationState.didFailReplacement(
                for: request,
                presentationRemainsAvailable: renderer.hasPresentation
            )
            metalView.isPaused = !shouldResume
            setStatus(
                "Could not present source room \(playerView.roomSourceIndex): \(error.localizedDescription)",
                isError: true
            )
        }
        #endif
    }

    private func pausePresentation() {
        metalView.isPaused = true
    }

    private func applyPresentationSubmissionState() {
        metalView.isPaused = presentationState.submissionsShouldBePaused
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .white
        if viewIfLoaded?.window != nil {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
