// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import AVFoundation
import CoreGraphics
@preconcurrency import GameController
import MetalKit

enum TrainingOpeningPresentationError: LocalizedError {
    case voicePlaybackFailed(String)
    case soundPlaybackFailed(String)

    var errorDescription: String? {
        switch self {
        case .voicePlaybackFailed(let sourceName):
            "Training voice playback failed for \(sourceName)"
        case .soundPlaybackFailed(let sourceName):
            "Training sound playback failed for \(sourceName)"
        }
    }
}

@MainActor
private final class NoninteractiveTrainingOverlay: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
final class RevivalGameplayView: MTKView {
    var heldInputChanged: ((InputSnapshot) -> Void)?
    var controllerInputChanged: ((InputSnapshot) -> Void)?
    var guidebotDeployRequested: (() -> Void)?
    var primaryFireRequested: (() -> Void)?
    var inventoryUseRequested: (() -> Void)?
    var trainingResultAcknowledgementRequested: (() -> Void)?

    private var heldKeys: Set<UInt16> = []
    private var pendingMouseX: Float = 0
    private var pendingMouseY: Float = 0
    private var activeController: GCController?
    private var gameplayIsActive = false
    private var mouseIsCaptured = false
    private var afterburnerIsHeld = false
    private let trainingMessageLabel = NSTextField(labelWithString: "")
    private let enabledControlsLabel = NSTextField(labelWithString: "")
    private let invulnerabilityStatusLabel =
        NSTextField(labelWithString: "")
    private let cloakShipMonitor = NoninteractiveTrainingOverlay()
    private let cloakShipMonitorShape = CAShapeLayer()
    private let cloakStatusLabel = NSTextField(labelWithString: "")
    private let invulnerabilityMonitorRing = NoninteractiveTrainingOverlay()
    private let cameraMonitorBorder = NoninteractiveTrainingOverlay()
    private let trainingEndLevelOverlay = NoninteractiveTrainingOverlay()
    private let trainingEndLevelLabel = NSTextField(labelWithString: "")
    private var trainingVoicePlayer: AVAudioPlayer?
    private var trainingSoundPlayers: [AVAudioPlayer] = []
    private var trainingMessageExpiresAt: Float?
    private var trainingResultIsPresented = false
    private var trainingResultPresentedAt: TimeInterval?
    private var pendingTrainingResultKeyAcknowledgement = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect, device: (any MTLDevice)?) {
        super.init(frame: frameRect, device: device)
        configureTrainingOverlay()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Revival gameplay views are created programmatically.")
    }

    deinit {
        activeController?.extendedGamepad?.valueChangedHandler = nil
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func layout() {
        super.layout()
        let virtualWidth = min(bounds.width, bounds.height * 4 / 3)
        let left = (bounds.width - virtualWidth) / 2 + 24
        let width = max(0, virtualWidth - 48)
        enabledControlsLabel.frame = NSRect(
            x: left,
            y: max(16, bounds.height * 0.1),
            width: width,
            height: 24
        )
        trainingMessageLabel.frame = NSRect(
            x: left,
            y: enabledControlsLabel.frame.maxY + 8,
            width: width,
            height: CGFloat(trainingMessageLabel.maximumNumberOfLines) * 28
        )
        invulnerabilityStatusLabel.frame = NSRect(
            x: left,
            y: max(
                trainingMessageLabel.frame.maxY + 8,
                bounds.height - 52
            ),
            width: max(0, width - 104),
            height: 28
        )
        cloakStatusLabel.frame = NSRect(
            x: left + max(0, width - 96),
            y: invulnerabilityStatusLabel.frame.minY,
            width: 96,
            height: 28
        )
        cloakShipMonitor.frame = cloakStatusLabel.frame
        cloakShipMonitorShape.frame = cloakShipMonitor.bounds
        cloakShipMonitorShape.path = Self.cloakShipMonitorPath(
            in: cloakShipMonitor.bounds
        )
        cameraMonitorBorder.frame = Self.cameraMonitorFrame(
            drawableWidth: bounds.width,
            drawableHeight: bounds.height
        )
        trainingEndLevelOverlay.frame = bounds
        trainingEndLevelLabel.frame = NSRect(
            x: max(24, bounds.midX - 240),
            y: max(24, bounds.midY - 180),
            width: min(480, max(0, bounds.width - 48)),
            height: min(360, max(0, bounds.height - 48))
        )
    }

    override func keyDown(with event: NSEvent) {
        if trainingResultIsPresented,
           Self.isTrainingResultAcknowledgementKey(event.keyCode) {
            pendingTrainingResultKeyAcknowledgement = true
            requestTrainingResultAcknowledgement()
            return
        }
        if event.keyCode == 53 {
            releaseMouse()
            return
        }
        if Self.requestsGuidebotDeployment(
            keyCode: event.keyCode,
            gameplayIsActive: gameplayIsActive
        ) {
            guidebotDeployRequested?()
            return
        }
        if Self.requestsInventoryUse(
            keyCode: event.keyCode,
            isRepeat: event.isARepeat,
            gameplayIsActive: gameplayIsActive
        ) {
            inventoryUseRequested?()
            return
        }
        guard Self.gameplayKeyCodes.contains(event.keyCode) else {
            super.keyDown(with: event)
            return
        }
        heldKeys.insert(event.keyCode)
        publishHeldInput()
    }

    override func keyUp(with event: NSEvent) {
        guard Self.gameplayKeyCodes.contains(event.keyCode) else {
            super.keyUp(with: event)
            return
        }
        heldKeys.remove(event.keyCode)
        publishHeldInput()
    }

    override func flagsChanged(with event: NSEvent) {
        guard event.keyCode == 56 || event.keyCode == 60 else {
            super.flagsChanged(with: event)
            return
        }
        afterburnerIsHeld = event.modifierFlags.contains(.shift)
        publishHeldInput()
    }

    override func mouseDown(with event: NSEvent) {
        if trainingResultIsPresented {
            requestTrainingResultAcknowledgement()
            return
        }
        guard gameplayIsActive else {
            super.mouseDown(with: event)
            return
        }
        captureMouse()
        primaryFireRequested?()
    }

    override func mouseMoved(with event: NSEvent) {
        guard gameplayIsActive && mouseIsCaptured else {
            super.mouseMoved(with: event)
            return
        }
        pendingMouseX += Float(event.deltaX)
        pendingMouseY += Float(event.deltaY)
    }

    func setGameplayActive(_ active: Bool) {
        gameplayIsActive = active
        if active {
            publishHeldInput()
            connectController(GCController.controllers().first)
        } else {
            disconnectController()
            clearInput()
            trainingMessageLabel.stringValue = ""
            enabledControlsLabel.stringValue = ""
            invulnerabilityStatusLabel.stringValue = ""
            cloakShipMonitor.isHidden = true
            cloakStatusLabel.stringValue = ""
            invulnerabilityMonitorRing.isHidden = true
            trainingMessageExpiresAt = nil
            trainingVoicePlayer?.stop()
            trainingVoicePlayer = nil
            trainingSoundPlayers.forEach { $0.stop() }
            trainingSoundPlayers.removeAll()
            cameraMonitorBorder.isHidden = true
        }
    }

    func presentTrainingOpening(
        frame: PlayerSimulationFrame,
        voiceClips: [CanonicalVoiceClip],
        soundClips: [CanonicalSoundClip] = []
    ) throws {
        if let finalGoal = frame.trainingFinalGoal {
            trainingMessageLabel.stringValue = ""
            enabledControlsLabel.stringValue = ""
            invulnerabilityStatusLabel.stringValue = ""
            cloakShipMonitor.isHidden = true
            cloakStatusLabel.stringValue = ""
            invulnerabilityMonitorRing.isHidden = true
            cameraMonitorBorder.isHidden = true
            trainingMessageExpiresAt = nil
            trainingVoicePlayer?.stop()
            trainingVoicePlayer = nil
            trainingSoundPlayers.forEach { $0.stop() }
            trainingSoundPlayers.removeAll()
            trainingEndLevelLabel.stringValue =
                Self.trainingPostLevelResultText(
                    finalGoal.postLevelResult
                )
            if !trainingResultIsPresented {
                trainingResultPresentedAt =
                    ProcessInfo.processInfo.systemUptime
                perform(
                    #selector(trainingResultAdmissionDidOpen),
                    with: nil,
                    afterDelay: 2
                )
            }
            trainingResultIsPresented = true
            trainingEndLevelOverlay.isHidden = false
            trainingEndLevelLabel.isHidden = false
            return
        }
        trainingResultIsPresented = false
        trainingResultPresentedAt = nil
        pendingTrainingResultKeyAcknowledgement = false
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(trainingResultAdmissionDidOpen),
            object: nil
        )
        trainingEndLevelOverlay.isHidden = true
        trainingEndLevelLabel.isHidden = true
        cameraMonitorBorder.isHidden = frame.trainingCameraMonitor == nil
        invulnerabilityStatusLabel.stringValue =
            Self.invulnerabilityStatusText(
                remaining: frame.trainingInvulnerabilityRemaining
            )
        let cloakStatus = Self.cloakStatusPresentation(
            frame.trainingCloak
        )
        cloakShipMonitor.isHidden = false
        cloakShipMonitor.alphaValue = cloakStatus.shipOpacity
        cloakStatusLabel.stringValue = cloakStatus.cloakText
        cloakStatusLabel.alphaValue = cloakStatus.cloakOpacity
        if let pulse = Self.invulnerabilityMonitorPulse(
            remaining: frame.trainingInvulnerabilityRemaining,
            gameTime: frame.gameTime,
            drawableWidth: bounds.width,
            drawableHeight: bounds.height
        ) {
            invulnerabilityMonitorRing.frame = pulse.frame
            invulnerabilityMonitorRing.alphaValue = pulse.alpha
            invulnerabilityMonitorRing.layer?.cornerRadius =
                pulse.frame.width / 2
            invulnerabilityMonitorRing.isHidden = false
        } else {
            invulnerabilityMonitorRing.isHidden = true
        }
        guard !voiceClips.isEmpty else {
            trainingMessageLabel.stringValue = ""
            enabledControlsLabel.stringValue = ""
            trainingMessageExpiresAt = nil
            trainingVoicePlayer?.stop()
            trainingVoicePlayer = nil
            return
        }
        enabledControlsLabel.stringValue =
            frame.showsEnabledPlayerControls
                ? Self.controlSummary(frame.enabledPlayerControls)
                : ""
        guard !frame.trainingOpeningFeedback.isEmpty else {
            if let expiry = trainingMessageExpiresAt,
               frame.gameTime >= expiry {
                trainingMessageLabel.stringValue = ""
                trainingMessageExpiresAt = nil
            }
            return
        }
        var presentedHUDMessages: [String] = []
        Self.presentTrainingFeedbackSequence(
            frame.trainingOpeningFeedback,
            attemptVoice: {
                try self.playTrainingVoice(named: $0, from: voiceClips)
            },
            attemptSound: {
                try self.playTrainingSound(named: $0, from: soundClips)
            },
            presentHUDMessages: { messages in
                presentedHUDMessages.append(contentsOf: messages)
                self.trainingMessageLabel.maximumNumberOfLines =
                    Self.trainingMessageLineCount(
                        for: frame.trainingOpeningFeedback
                    )
                self.needsLayout = true
                self.trainingMessageLabel.stringValue =
                    presentedHUDMessages.joined(separator: "\n")
                self.trainingMessageExpiresAt = frame.gameTime + 5
            }
        )
    }

    static func presentTrainingFeedback(
        voicePrecedesHUDMessages: Bool,
        attemptVoice: () throws -> Void,
        attemptSound: () throws -> Void = {},
        presentHUDMessages: () -> Void
    ) {
        if voicePrecedesHUDMessages {
            try? attemptVoice()
        }
        try? attemptSound()
        presentHUDMessages()
        if !voicePrecedesHUDMessages {
            try? attemptVoice()
        }
    }

    static func presentTrainingFeedbackSequence(
        _ feedback: [TrainingOpeningFeedback],
        attemptVoice: (String) throws -> Void,
        attemptSound: (String) throws -> Void,
        presentHUDMessages: ([String]) -> Void
    ) {
        let selectedVoiceIndex = feedback.indices.last {
            !feedback[$0].voiceSourceName.isEmpty
        }
        for (index, event) in feedback.enumerated() {
            presentTrainingFeedback(
                voicePrecedesHUDMessages:
                    event.voicePrecedesHUDMessages,
                attemptVoice: {
                    guard index == selectedVoiceIndex,
                          !event.voiceSourceName.isEmpty else {
                        return
                    }
                    try attemptVoice(event.voiceSourceName)
                },
                attemptSound: {
                    guard let soundSourceName =
                            event.soundSourceName else {
                        return
                    }
                    try attemptSound(soundSourceName)
                },
                presentHUDMessages: {
                    presentHUDMessages(event.hudMessages)
                }
            )
        }
    }

    private func playTrainingSound(
        named soundSourceName: String,
        from soundClips: [CanonicalSoundClip]
    ) throws {
        do {
            trainingSoundPlayers.removeAll { !$0.isPlaying }
            guard
                let clip = soundClips.first(where: {
                    $0.sourceName.caseInsensitiveCompare(soundSourceName)
                    == .orderedSame
                    || $0.logicalName.caseInsensitiveCompare(soundSourceName)
                        == .orderedSame
                })
            else {
                throw TrainingOpeningPresentationError.soundPlaybackFailed(
                    soundSourceName
                )
            }
            let player = try AVAudioPlayer(data: Self.waveData(for: clip))
            trainingSoundPlayers.append(player)
            player.volume = clip.importVolume
            player.prepareToPlay()
            guard player.play() else {
                throw TrainingOpeningPresentationError.soundPlaybackFailed(
                    soundSourceName
                )
            }
        } catch {
            throw TrainingOpeningPresentationError.soundPlaybackFailed(
                soundSourceName
            )
        }
    }

    private func playTrainingVoice(
        named voiceSourceName: String,
        from voiceClips: [CanonicalVoiceClip]
    ) throws {
        do {
            trainingVoicePlayer?.stop()
            let clip = voiceClips.first(where: {
                $0.sourceName.caseInsensitiveCompare(voiceSourceName)
                    == .orderedSame
            })!
            let player = try AVAudioPlayer(data: Self.waveData(for: clip))
            trainingVoicePlayer = player
            player.prepareToPlay()
            guard player.play() else {
                throw TrainingOpeningPresentationError.voicePlaybackFailed(
                    voiceSourceName
                )
            }
        } catch {
            trainingVoicePlayer?.stop()
            trainingVoicePlayer = nil
            throw TrainingOpeningPresentationError.voicePlaybackFailed(
                voiceSourceName
            )
        }
    }

    func drainMouseDelta() -> (x: Float, y: Float) {
        let result = (pendingMouseX, pendingMouseY)
        pendingMouseX = 0
        pendingMouseY = 0
        return result
    }

    func clearInput() {
        heldKeys.removeAll()
        afterburnerIsHeld = false
        pendingMouseX = 0
        pendingMouseY = 0
        heldInputChanged?(.zero)
        controllerInputChanged?(.zero)
        releaseMouse()
    }

    nonisolated static func heldInput(
        for keyCodes: Set<UInt16>,
        afterburner: Bool = false
    ) -> InputSnapshot {
        InputSnapshot(
            forward: direction(positive: 13, negative: 1, in: keyCodes),
            sideways: direction(positive: 2, negative: 0, in: keyCodes),
            vertical: direction(positive: 15, negative: 3, in: keyCodes),
            pitch: direction(positive: 125, negative: 126, in: keyCodes),
            yaw: direction(positive: 124, negative: 123, in: keyCodes),
            roll: direction(positive: 12, negative: 14, in: keyCodes),
            afterburner: afterburner ? 1 : 0
        )
    }

    nonisolated static func requestsGuidebotDeployment(
        keyCode: UInt16,
        gameplayIsActive: Bool
    ) -> Bool {
        gameplayIsActive && keyCode == 118
    }

    nonisolated static func requestsInventoryUse(
        keyCode: UInt16,
        isRepeat: Bool,
        gameplayIsActive: Bool
    ) -> Bool {
        gameplayIsActive && !isRepeat && keyCode == 42
    }

    nonisolated static func cameraMonitorFrame(
        drawableWidth: CGFloat,
        drawableHeight: CGFloat
    ) -> CGRect {
        let viewport = cameraMonitorMetalViewport(
            drawableWidth: Double(drawableWidth),
            drawableHeight: Double(drawableHeight)
        )
        return CGRect(
            x: viewport.originX,
            y: Double(drawableHeight) - viewport.originY - viewport.height,
            width: viewport.width,
            height: viewport.height
        )
    }

    nonisolated static func invulnerabilityStatusText(
        remaining: Float?
    ) -> String {
        guard let remaining, remaining > 0 else { return "" }
        let tenths = Int((remaining * 10).rounded())
        return "INVULNERABLE \(tenths / 10).\(abs(tenths % 10))"
    }

    nonisolated static func cloakStatusPresentation(
        _ cloak: TrainingCloakFrame?
    ) -> (
        cloakText: String,
        shipOpacity: CGFloat,
        cloakOpacity: CGFloat
    ) {
        guard let cloak, cloak.phase == .cloaked else {
            return ("", 1, 0)
        }
        guard cloak.phaseRemaining < 3 else {
            return ("CLK", 0, 1)
        }
        let fraction =
            cloak.phaseRemaining - floor(cloak.phaseRemaining)
        let shipAlpha =
            128 - 127 * cos(2 * Float.pi * fraction)
        let shipOpacity = CGFloat(shipAlpha / 255)
        return ("CLK", shipOpacity, 1 - shipOpacity)
    }

    nonisolated static func cloakShipMonitorPath(
        in rect: CGRect
    ) -> CGPath {
        let drawingRect = rect.insetBy(dx: 4, dy: 3)
        guard drawingRect.width > 0, drawingRect.height > 0 else {
            return CGMutablePath()
        }
        let points: [(CGFloat, CGFloat)] = [
            (0.50, 0.95),
            (0.60, 0.62),
            (0.88, 0.25),
            (0.64, 0.34),
            (0.58, 0.10),
            (0.50, 0.23),
            (0.42, 0.10),
            (0.36, 0.34),
            (0.12, 0.25),
            (0.40, 0.62),
        ]
        let path = CGMutablePath()
        for (index, point) in points.enumerated() {
            let position = CGPoint(
                x: drawingRect.minX + point.0 * drawingRect.width,
                y: drawingRect.minY + point.1 * drawingRect.height
            )
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }
        path.closeSubpath()
        return path
    }

    nonisolated static func invulnerabilityMonitorPulse(
        remaining: Float?,
        gameTime: Float,
        drawableWidth: CGFloat,
        drawableHeight: CGFloat
    ) -> (frame: CGRect, alpha: CGFloat)? {
        guard let remaining, remaining > 0,
            drawableWidth > 0, drawableHeight > 0
        else {
            return nil
        }
        let virtualWidth = min(
            drawableWidth,
            drawableHeight * 4 / 3
        )
        let left = (drawableWidth - virtualWidth) / 2
        let side = max(48, min(88, virtualWidth * 0.075))
        let margin = max(18, virtualWidth * 0.02)
        let phase = CGFloat(gameTime - floor(gameTime))
        let expansion = side * phase * 0.06
        return (
            CGRect(
                x: left + virtualWidth - margin - side - expansion,
                y: drawableHeight - margin - side - expansion,
                width: side + expansion * 2,
                height: side + expansion * 2
            ),
            1 - phase / 2
        )
    }

    nonisolated static func controllerInput(
        leftX: Float,
        leftY: Float,
        rightX: Float,
        rightY: Float,
        leftTrigger: Float,
        rightTrigger: Float,
        leftShoulder: Float,
        rightShoulder: Float,
        afterburner: Float = 0
    ) -> InputSnapshot {
        InputSnapshot(
            forward: adjusted(leftY),
            sideways: adjusted(leftX),
            vertical: adjusted(rightTrigger) - adjusted(leftTrigger),
            pitch: -adjusted(rightY),
            yaw: adjusted(rightX),
            roll: leftShoulder - rightShoulder,
            afterburner: afterburner
        )
    }

    private func publishHeldInput() {
        heldInputChanged?(
            Self.heldInput(for: heldKeys, afterburner: afterburnerIsHeld)
        )
    }

    private func configureTrainingOverlay() {
        invulnerabilityMonitorRing.wantsLayer = true
        invulnerabilityMonitorRing.layer?.borderColor =
            NSColor.systemRed.cgColor
        invulnerabilityMonitorRing.layer?.borderWidth = 4
        invulnerabilityMonitorRing.layer?.shadowColor =
            NSColor.systemRed.cgColor
        invulnerabilityMonitorRing.layer?.shadowOpacity = 0.8
        invulnerabilityMonitorRing.layer?.shadowRadius = 5
        invulnerabilityMonitorRing.layer?.shadowOffset = .zero
        invulnerabilityMonitorRing.isHidden = true
        invulnerabilityMonitorRing.setAccessibilityLabel(
            "Invulnerability ship monitor pulse"
        )
        addSubview(invulnerabilityMonitorRing)
        cameraMonitorBorder.wantsLayer = true
        cameraMonitorBorder.layer?.borderColor = NSColor.systemRed.cgColor
        cameraMonitorBorder.layer?.borderWidth = 2
        cameraMonitorBorder.isHidden = true
        cameraMonitorBorder.setAccessibilityLabel(
            "Training Camera Monitor view"
        )
        addSubview(cameraMonitorBorder)
        cloakShipMonitor.wantsLayer = true
        cloakShipMonitorShape.fillColor =
            NSColor.systemBlue.withAlphaComponent(0.25).cgColor
        cloakShipMonitorShape.strokeColor = NSColor.systemBlue.cgColor
        cloakShipMonitorShape.lineWidth = 2
        cloakShipMonitor.layer?.addSublayer(cloakShipMonitorShape)
        cloakShipMonitor.isHidden = true
        cloakShipMonitor.setAccessibilityLabel("Player ship monitor")
        addSubview(cloakShipMonitor)
        for label in [
            enabledControlsLabel,
            trainingMessageLabel,
            invulnerabilityStatusLabel,
            cloakStatusLabel,
        ] {
            label.isHidden = false
            label.isEditable = false
            label.isSelectable = false
            label.drawsBackground = true
            label.backgroundColor = NSColor.black.withAlphaComponent(0.72)
            label.textColor = .systemGreen
            label.alignment = .center
            label.lineBreakMode = .byWordWrapping
            addSubview(label)
        }
        enabledControlsLabel.setAccessibilityLabel(
            "Enabled Training controls"
        )
        trainingMessageLabel.maximumNumberOfLines = 2
        trainingMessageLabel.setAccessibilityLabel("Training instruction")
        invulnerabilityStatusLabel.textColor = .systemRed
        invulnerabilityStatusLabel.setAccessibilityLabel(
            "Invulnerability status"
        )
        cloakStatusLabel.textColor = .systemBlue
        cloakStatusLabel.setAccessibilityLabel("Cloak status")
        trainingEndLevelOverlay.wantsLayer = true
        trainingEndLevelOverlay.layer?.backgroundColor =
            NSColor.black.cgColor
        trainingEndLevelOverlay.isHidden = true
        trainingEndLevelOverlay.setAccessibilityLabel(
            "Training mission result"
        )
        addSubview(trainingEndLevelOverlay)
        trainingEndLevelLabel.isEditable = false
        trainingEndLevelLabel.isSelectable = false
        trainingEndLevelLabel.drawsBackground = false
        trainingEndLevelLabel.textColor = .white
        trainingEndLevelLabel.alignment = .center
        trainingEndLevelLabel.maximumNumberOfLines = 14
        trainingEndLevelLabel.font = .boldSystemFont(ofSize: 20)
        trainingEndLevelLabel.isHidden = true
        trainingEndLevelLabel.setAccessibilityLabel(
            "Training mission result text"
        )
        addSubview(trainingEndLevelLabel)
    }

    nonisolated static func trainingEndLevelText(
        _ presentation: TrainingEndLevelPresentation
    ) -> String {
        [
            presentation.title,
            presentation.levelName,
            "Difficulty: \(presentation.difficulty.rawValue)",
        ].joined(separator: "\n")
    }

    nonisolated static func trainingPostLevelResultText(
        _ result: TrainingPostLevelResult
    ) -> String {
        let elapsedSeconds = max(0, Int(result.elapsedTime))
        var lines = [
            result.title,
            result.levelName,
            "Difficulty: \(result.difficulty.rawValue)",
            "Score: \(result.score)",
            "Time: \(elapsedSeconds / 60):"
                + String(format: "%02d", elapsedSeconds % 60),
            "Enemies Killed: \(result.enemyKills)",
            "Shields: \(Int(result.shields.rounded()))",
            "Energy: \(Int(result.energy.rounded()))",
            "Deaths: \(result.deaths)",
            "Restores: \(result.restores)",
        ]
        if !result.objectives.isEmpty {
            lines.append("Objectives")
            lines.append(contentsOf: result.objectives)
        }
        return lines.joined(separator: "\n")
    }

    nonisolated static func requestsTrainingResultAcknowledgement(
        keyCode: UInt16,
        resultIsPresented: Bool,
        presentationElapsedTime: TimeInterval
    ) -> Bool {
        requestsTrainingResultAcknowledgement(
            resultIsPresented: resultIsPresented,
            presentationElapsedTime: presentationElapsedTime,
            queuedKey: isTrainingResultAcknowledgementKey(keyCode),
            mouseButtonIsPressed: false,
            controllerButtonIsPressed: false
        )
    }

    nonisolated static func requestsTrainingResultAcknowledgement(
        resultIsPresented: Bool,
        presentationElapsedTime: TimeInterval,
        queuedKey: Bool,
        mouseButtonIsPressed: Bool,
        controllerButtonIsPressed: Bool
    ) -> Bool {
        resultIsPresented
            && presentationElapsedTime >= 2
            && (
                queuedKey
                || mouseButtonIsPressed
                || controllerButtonIsPressed
            )
    }

    nonisolated private static func isTrainingResultAcknowledgementKey(
        _ keyCode: UInt16
    ) -> Bool {
        [36, 49, 53].contains(keyCode)
    }

    nonisolated private static func controlSummary(
        _ controls: PlayerControlMask
    ) -> String {
        var names: [String] = []
        if controls.contains(.forward) { names.append("Forward") }
        if controls.contains(.reverse) { names.append("Reverse") }
        if controls.contains(.left) || controls.contains(.right) {
            names.append("Slide")
        }
        if controls.contains(.up) || controls.contains(.down) {
            names.append("Vertical")
        }
        if controls.contains(.pitchUp) || controls.contains(.pitchDown) {
            names.append("Pitch")
        }
        if controls.contains(.headingLeft) || controls.contains(.headingRight) {
            names.append("Heading")
        }
        if controls.contains(.bankLeft) || controls.contains(.bankRight) {
            names.append("Bank")
        }
        if controls.contains(.afterburner) { names.append("Afterburner") }
        return names.isEmpty ? "" : "Enabled: " + names.joined(separator: ", ")
    }

    nonisolated static func trainingMessageLineCount(
        for feedback: [TrainingOpeningFeedback]
    ) -> Int {
        min(4, max(2, feedback.reduce(0) { $0 + $1.hudMessages.count }))
    }

    nonisolated static func waveData(for clip: CanonicalVoiceClip) -> Data {
        waveData(
            sampleRate: clip.sampleRate,
            channelCount: clip.channelCount,
            pcm16LittleEndian: clip.pcm16LittleEndian
        )
    }

    nonisolated static func waveData(for clip: CanonicalSoundClip) -> Data {
        waveData(
            sampleRate: clip.sampleRate,
            channelCount: clip.channelCount,
            pcm16LittleEndian: clip.pcm16LittleEndian
        )
    }

    nonisolated private static func waveData(
        sampleRate: Int,
        channelCount: Int,
        pcm16LittleEndian: Data
    ) -> Data {
        var result = Data()
        let dataSize = UInt32(pcm16LittleEndian.count)
        result.append(contentsOf: "RIFF".utf8)
        result.append(contentsOf: littleEndian(dataSize + 36))
        result.append(contentsOf: "WAVEfmt ".utf8)
        result.append(contentsOf: littleEndian(UInt32(16)))
        result.append(contentsOf: littleEndian(UInt16(1)))
        result.append(contentsOf: littleEndian(UInt16(channelCount)))
        result.append(contentsOf: littleEndian(UInt32(sampleRate)))
        let byteRate = UInt32(sampleRate * channelCount * 2)
        result.append(contentsOf: littleEndian(byteRate))
        result.append(contentsOf: littleEndian(UInt16(channelCount * 2)))
        result.append(contentsOf: littleEndian(UInt16(16)))
        result.append(contentsOf: "data".utf8)
        result.append(contentsOf: littleEndian(dataSize))
        result.append(pcm16LittleEndian)
        return result
    }

    nonisolated private static func littleEndian<T: FixedWidthInteger>(
        _ value: T
    ) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }

    private func publishControllerInput() {
        guard gameplayIsActive,
              let gamepad = activeController?.extendedGamepad else {
            controllerInputChanged?(.zero)
            return
        }
        controllerInputChanged?(
            Self.controllerInput(
                leftX: gamepad.leftThumbstick.xAxis.value,
                leftY: gamepad.leftThumbstick.yAxis.value,
                rightX: gamepad.rightThumbstick.xAxis.value,
                rightY: gamepad.rightThumbstick.yAxis.value,
                leftTrigger: gamepad.leftTrigger.value,
                rightTrigger: gamepad.rightTrigger.value,
                leftShoulder: gamepad.leftShoulder.value,
                rightShoulder: gamepad.rightShoulder.value,
                afterburner: gamepad.buttonA.value
            )
        )
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard gameplayIsActive,
              activeController == nil,
              let controller = notification.object as? GCController else {
            return
        }
        connectController(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard notification.object as? GCController === activeController else {
            return
        }
        connectController(
            GCController.controllers().first { $0 !== activeController }
        )
    }

    private func connectController(_ controller: GCController?) {
        guard gameplayIsActive else { return }
        activeController?.extendedGamepad?.valueChangedHandler = nil
        activeController = controller
        controller?.handlerQueue = .main
        controller?.extendedGamepad?.valueChangedHandler = {
            [weak self] _, element in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.trainingResultIsPresented,
                   let button = element as? GCControllerButtonInput,
                   button.isPressed {
                    self.requestTrainingResultAcknowledgement()
                    return
                }
                self.publishControllerInput()
            }
        }
        publishControllerInput()
    }

    private func requestTrainingResultAcknowledgement() {
        guard Self.requestsTrainingResultAcknowledgement(
            resultIsPresented: trainingResultIsPresented,
            presentationElapsedTime:
                trainingResultPresentationElapsedTime,
            queuedKey: pendingTrainingResultKeyAcknowledgement,
            mouseButtonIsPressed: NSEvent.pressedMouseButtons != 0,
            controllerButtonIsPressed:
                controllerHasPressedButton
        ) else {
            return
        }
        trainingResultIsPresented = false
        trainingResultPresentedAt = nil
        pendingTrainingResultKeyAcknowledgement = false
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(trainingResultAdmissionDidOpen),
            object: nil
        )
        trainingResultAcknowledgementRequested?()
    }

    @objc private func trainingResultAdmissionDidOpen() {
        requestTrainingResultAcknowledgement()
    }

    private var trainingResultPresentationElapsedTime: TimeInterval {
        guard let trainingResultPresentedAt else { return 0 }
        return ProcessInfo.processInfo.systemUptime
            - trainingResultPresentedAt
    }

    private var controllerHasPressedButton: Bool {
        guard let gamepad = activeController?.extendedGamepad else {
            return false
        }
        var buttons = [
            gamepad.buttonA,
            gamepad.buttonB,
            gamepad.buttonX,
            gamepad.buttonY,
            gamepad.buttonMenu,
            gamepad.leftShoulder,
            gamepad.rightShoulder,
            gamepad.leftTrigger,
            gamepad.rightTrigger,
            gamepad.dpad.up,
            gamepad.dpad.down,
            gamepad.dpad.left,
            gamepad.dpad.right,
        ]
        if let button = gamepad.buttonOptions {
            buttons.append(button)
        }
        if let button = gamepad.buttonHome {
            buttons.append(button)
        }
        if let button = gamepad.leftThumbstickButton {
            buttons.append(button)
        }
        if let button = gamepad.rightThumbstickButton {
            buttons.append(button)
        }
        return buttons.contains(where: \.isPressed)
    }

    private func disconnectController() {
        activeController?.extendedGamepad?.valueChangedHandler = nil
        activeController = nil
    }

    private func captureMouse() {
        guard !mouseIsCaptured else { return }
        mouseIsCaptured = true
        NSCursor.hide()
        CGAssociateMouseAndMouseCursorPosition(0)
    }

    private func releaseMouse() {
        guard mouseIsCaptured else { return }
        mouseIsCaptured = false
        pendingMouseX = 0
        pendingMouseY = 0
        CGAssociateMouseAndMouseCursorPosition(1)
        NSCursor.unhide()
    }

    nonisolated private static func direction(
        positive: UInt16,
        negative: UInt16,
        in keyCodes: Set<UInt16>
    ) -> Float {
        (keyCodes.contains(positive) ? 1 : 0)
            - (keyCodes.contains(negative) ? 1 : 0)
    }

    nonisolated private static func adjusted(_ value: Float) -> Float {
        let deadzone: Float = 0.2
        if value > deadzone {
            return min(1, (value - deadzone) / (1 - deadzone))
        }
        if value < -deadzone {
            return max(-1, (value + deadzone) / (1 - deadzone))
        }
        return 0
    }

    private static let gameplayKeyCodes: Set<UInt16> = [
        0, 1, 2, 3, 12, 13, 14, 15, 123, 124, 125, 126,
    ]
}
