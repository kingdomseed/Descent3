// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit

@main
@MainActor
enum RevivalMacApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = RevivalMacApplicationDelegate()

        application.delegate = delegate
        application.setActivationPolicy(.regular)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
private final class RevivalMacApplicationDelegate: NSObject,
    NSApplicationDelegate,
    NSWindowDelegate
{
    private enum ContentRequest: Sendable {
        case loadActive
        case install(URL)
    }

    private let library = CanonicalPackageLibrary.revivalMac
    private let profileLibrary = PilotProfileLibrary.revivalMac
    private var window: NSWindow?
    private var renderer: MetalWorldRenderer?
    private var gameplayView: RevivalGameplayView?
    private var simulation: PlayerSimulation?
    private var profileRecord: PilotProfileLibraryRecord?
    private var activeProfileID: UUID?
    private var pendingTrainingProgressPackage: CanonicalPackageReference?
    private var playerInput = PlayerInputState()
    private var statusLabel: NSTextField?
    private var contentRequests = CanonicalPackageRequestQueue<ContentRequest>()
    private var libraryPreparationError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()

        guard let device = MTLCreateSystemDefaultDevice() else {
            showWindow(rendererView: nil, message: "No Metal device is available.")
            return
        }
        let metalView = RevivalGameplayView(frame: .zero, device: device)
        do {
            renderer = try MetalWorldRenderer(view: metalView)
            showWindow(
                rendererView: metalView,
                message: "Open a canonical Revival package to begin."
            )
        } catch {
            showWindow(rendererView: nil, message: error.localizedDescription)
        }

        do {
            try library.prepareForUse()
        } catch {
            libraryPreparationError = error.localizedDescription
            setStatus(
                "Could not prepare installed content: \(error.localizedDescription)",
                isError: true
            )
        }

        do {
            let record = try profileLibrary.load()
            profileRecord = record
            gameplayView?.presentPilotProfileSelection(
                profiles: record.profiles.map { ($0.id, $0.name) },
                defaultProfileID: record.defaultProfileID,
                selectedProfileID: record.defaultProfileID
            )
            setStatus(
                record.profiles.isEmpty
                    ? "Create and confirm a named pilot before Training."
                    : "Confirm a pilot for this Training session.",
                isError: false
            )
        } catch {
            setStatus(
                "Could not load pilot profiles: \(error.localizedDescription)",
                isError: true
            )
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if window == nil {
            for url in urls {
                contentRequests.append(.install(url))
            }
        } else {
            for url in urls {
                enqueueInstall(url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        renderer?.shutdown()
        renderer = nil
    }

    func applicationDidResignActive(_ notification: Notification) {
        updateGameplayActivity()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateGameplayActivity()
    }

    func windowDidResignKey(_ notification: Notification) {
        updateGameplayActivity()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updateGameplayActivity()
    }

    func windowWillClose(_ notification: Notification) {
        renderer?.shutdown()
        renderer = nil
    }

    @objc private func chooseCanonicalPackage(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Open Canonical Revival Content"
        panel.message = "Choose a package produced by D3Import."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        enqueueInstall(url)
    }

    private func enqueueInstall(_ packageURL: URL) {
        guard libraryPreparationError == nil else {
            setStatus(
                "New installs are blocked until abandoned staging is recovered. Relaunch Revival to retry preparation.",
                isError: true
            )
            return
        }
        enqueue(.install(packageURL))
    }

    private func enqueue(_ request: ContentRequest) {
        contentRequests.append(request)
        if activeProfileID != nil {
            processNextContentRequest()
        }
    }

    private func processNextContentRequest() {
        guard let renderer else {
            if !contentRequests.isEmpty {
                contentRequests.removeAllPending()
                setStatus("The Metal renderer is unavailable.", isError: true)
            }
            return
        }
        guard let request = contentRequests.startNextIfIdle() else { return }
        switch request {
        case .loadActive:
            setStatus("Loading the active canonical base…", isError: false)
        case let .install(packageURL):
            setStatus("Installing \(packageURL.lastPathComponent)…", isError: false)
        }
        gameplayView?.setTrainingRestartAvailable(false)

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.contentRequests.finishCurrent()
                self.processNextContentRequest()
            }
            do {
                let library = self.library
                let activation = try await Task.detached(priority: .userInitiated) {
                    switch request {
                    case .loadActive:
                        try library.loadActive()
                    case let .install(candidateURL):
                        try library.installAndActivate(from: candidateURL)
                    }
                }.value
                guard self.renderer === renderer else { return }
                guard let activation else {
                    if let preparationError = self.libraryPreparationError {
                        self.setStatus(
                            "Could not recover abandoned staging: \(preparationError)",
                            isError: true
                        )
                    } else {
                        self.setStatus(
                            "Open a canonical Revival package to begin.",
                            isError: false
                        )
                    }
                    self.gameplayView?.setTrainingRestartAvailable(true)
                    return
                }
                try self.present(activation, with: renderer)
            } catch {
                let operation: String
                switch request {
                case .loadActive:
                    operation = "load the active base"
                case let .install(packageURL):
                    operation = "open \(packageURL.lastPathComponent)"
                }
                self.setStatus(
                    "Could not \(operation): \(error.localizedDescription)",
                    isError: true
                )
                self.gameplayView?.setTrainingRestartAvailable(true)
            }
        }
    }

    private func present(
        _ activation: ActivatedCanonicalPackage,
        with renderer: MetalWorldRenderer
    ) throws {
        try renderer.replace(
            level: activation.level,
            playerView: defaultPlayerView(in: activation.level)
        )
        let presentationReadyTimestamp = ProcessInfo.processInfo.systemUptime
        let simulation = PlayerSimulation(
            level: activation.level,
            presentationReadyTimestamp: presentationReadyTimestamp
        )
        gameplayView?.prepareForTrainingSession()
        self.simulation = simulation
        playerInput = PlayerInputState()
        playerInput.setGameplayActive(
            NSApplication.shared.isActive && window?.isKeyWindow == true,
            simulation: simulation,
            at: presentationReadyTimestamp
        )
        gameplayView?.setGameplayActive(playerInput.gameplayIsActive)
        renderer.setFrameUpdate { [weak self, weak renderer] timestamp in
            guard let self, let renderer, self.simulation === simulation else { return }
            guard self.playerInput.gameplayIsActive else { return }
            let mouse = self.gameplayView?.drainMouseDelta() ?? (0, 0)
            self.playerInput.accumulateMouseDelta(x: mouse.0, y: mouse.1)
            let input = self.playerInput.snapshot(
                frameDuration: simulation.frameDuration
            )
            let frame = simulation.update(at: timestamp, input: input)
            var completionStatus: (message: String, isError: Bool)?
            if frame.trainingFinalGoal != nil {
                do {
                    try self.persistTrainingProgress(
                        package: activation.reference
                    )
                    completionStatus = (
                        "Training progress saved. Acknowledge the result to complete the session.",
                        false
                    )
                } catch {
                    self.pendingTrainingProgressPackage =
                        activation.reference
                    completionStatus = (
                        "Training completed, but progress was not saved: \(error.localizedDescription) Fix storage access, then acknowledge again to retry.",
                        true
                    )
                }
            }
            do {
                try self.gameplayView?.presentTrainingOpening(
                    frame: frame,
                    voiceClips: simulation.level.voiceClips,
                    soundClips: simulation.level.soundClips
                )
                try renderer.update(level: simulation.level, frame: frame)
                if frame.trainingFinalGoal != nil {
                    renderer.setFrameUpdate(nil)
                    if let completionStatus {
                        self.setStatus(
                            completionStatus.message,
                            isError: completionStatus.isError
                        )
                    }
                }
            } catch {
                renderer.setFrameUpdate(nil)
                self.setStatus(error.localizedDescription, isError: true)
            }
        }
        let contentSummary = "\(activation.level.metadata.name) — \(activation.level.rooms.count) rooms — player 0 source room 1"
        if let preparationError = libraryPreparationError {
            setStatus(
                "\(contentSummary) — new installs blocked: \(preparationError)",
                isError: true
            )
        } else {
            setStatus(contentSummary, isError: false)
        }
        renderer.drawNow()
    }

    private func showWindow(rendererView: MTKView?, message: String) {
        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.cgColor

        if let rendererView {
            rendererView.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(rendererView)
            NSLayoutConstraint.activate([
                rendererView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                rendererView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                rendererView.topAnchor.constraint(equalTo: content.topAnchor),
                rendererView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }

        let label = NSTextField(labelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.72)
        label.drawsBackground = true
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.setAccessibilityLabel("Revival content status")
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
        ])
        statusLabel = label

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Descent 3 Revival"
        window.contentMinSize = NSSize(width: 480, height: 480)
        window.contentView = content
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        if let gameplayView = rendererView as? RevivalGameplayView {
            gameplayView.heldInputChanged = {
                [weak self] in self?.playerInput.setHeld($0)
            }
            gameplayView.controllerInputChanged = {
                [weak self] in self?.playerInput.setController($0)
            }
            gameplayView.guidebotDeployRequested = {
                [weak self] in self?.playerInput.requestGuidebotDeployment()
            }
            gameplayView.primaryFireRequested = {
                [weak self] in self?.playerInput.requestPrimaryFire()
            }
            gameplayView.inventoryUseRequested = {
                [weak self] in self?.playerInput.requestInventoryUse()
            }
            gameplayView.trainingResultAcknowledgementRequested = {
                [weak self] in self?.acknowledgeTrainingResult()
            }
            gameplayView.trainingRestartRequested = {
                [weak self] in self?.restartTrainingSession()
            }
            gameplayView.pilotProfileCreationRequested = {
                [weak self] in self?.createPilotProfile(named: $0)
            }
            gameplayView.pilotProfileConfirmationRequested = {
                [weak self] in self?.confirmPilotProfile($0)
            }
            gameplayView.pilotProfileCancellationRequested = {
                [weak self] in self?.cancelPilotProfileSelection()
            }
            window.makeFirstResponder(gameplayView)
            self.gameplayView = gameplayView
        }
        self.window = window
    }

    private func updateGameplayActivity() {
        let active =
            NSApplication.shared.isActive
            && window?.isKeyWindow == true
            && simulation?.trainingSessionOutcome != .completed
        playerInput.setGameplayActive(
            active,
            simulation: simulation,
            at: ProcessInfo.processInfo.systemUptime
        )
        gameplayView?.setGameplayActive(active && simulation != nil)
    }

    private func acknowledgeTrainingResult() {
        guard let simulation else { return }
        if let pendingTrainingProgressPackage {
            do {
                try persistTrainingProgress(
                    package: pendingTrainingProgressPackage
                )
                setStatus(
                    "Training progress saved. Completing the session.",
                    isError: false
                )
            } catch {
                setStatus(
                    "Training progress is still unsaved: \(error.localizedDescription) Fix storage access, then acknowledge again to retry.",
                    isError: true
                )
                return
            }
        }
        guard
              simulation.acknowledgeTrainingResult() == .completed else {
            return
        }
        let timestamp = ProcessInfo.processInfo.systemUptime
        playerInput.setGameplayActive(
            false,
            simulation: simulation,
            at: timestamp
        )
        gameplayView?.setGameplayActive(false)
        let completedLevelName = simulation.level.metadata.name
        renderer?.unload()
        self.simulation = nil
        gameplayView?.presentTrainingContentReadyState(
            completedLevelName: completedLevelName
        )
        setStatus(
            "Training completed. Play again, open canonical content, or quit.",
            isError: false
        )
    }

    private func restartTrainingSession() {
        guard simulation == nil else { return }
        enqueue(.loadActive)
    }

    private func createPilotProfile(named name: String) {
        do {
            let record = try profileLibrary.createProfile(named: name)
            profileRecord = record
            let createdID = record.profiles.last?.id
            gameplayView?.presentPilotProfileSelection(
                profiles: record.profiles.map { ($0.id, $0.name) },
                defaultProfileID: record.defaultProfileID,
                selectedProfileID: createdID
            )
            setStatus(
                "Pilot created. Confirm the selected pilot to begin Training.",
                isError: false
            )
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func confirmPilotProfile(_ profileID: UUID) {
        do {
            let record = try profileLibrary.confirmProfile(profileID)
            profileRecord = record
            activeProfileID = profileID
            finishPilotProfileSelection()
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func cancelPilotProfileSelection() {
        guard let record = profileRecord,
              let defaultProfileID = record.defaultProfileID,
              record.profiles.contains(where: {
                  $0.id == defaultProfileID
              }) else {
            setStatus(
                "Create and confirm a named pilot before Training.",
                isError: true
            )
            return
        }
        activeProfileID = defaultProfileID
        finishPilotProfileSelection()
    }

    private func finishPilotProfileSelection() {
        gameplayView?.hidePilotProfileSelection()
        setStatus("Loading Training for the selected pilot…", isError: false)
        if contentRequests.isEmpty {
            enqueue(.loadActive)
        } else if libraryPreparationError == nil {
            processNextContentRequest()
        } else {
            contentRequests.removeAllPending()
        }
    }

    private func persistTrainingProgress(
        package: CanonicalPackageReference
    ) throws {
        guard let activeProfileID else {
            throw PilotProfileLibraryError.unknownProfile
        }
        profileRecord = try profileLibrary.recordTrainingCompletion(
            profileID: activeProfileID,
            package: package
        )
        pendingTrainingProgressPackage = nil
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel?.stringValue = message
        statusLabel?.textColor = isError ? .systemRed : .white
    }

    private func installMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Descent 3 Revival",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        let openItem = fileMenu.addItem(
            withTitle: "Open Canonical Content…",
            action: #selector(chooseCanonicalPackage(_:)),
            keyEquivalent: "o"
        )
        openItem.target = self
        fileItem.submenu = fileMenu
        NSApplication.shared.mainMenu = mainMenu
    }
}
