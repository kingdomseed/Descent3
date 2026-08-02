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
    var primaryFireHeldChanged: ((Bool) -> Void)?
    var playerFlareRequested: (() -> Void)?
    var playerFlareRequestCancelled: (() -> Void)?
    var inventoryUseRequested: (() -> Void)?
    var headlightToggleRequested: (() -> Void)?
    var rearViewInputChanged: ((Bool, Bool) -> Void)?
    var rearViewInputCancelled: (() -> Void)?
    var trainingResultAcknowledgementRequested: (() -> Void)?
    var trainingRestartRequested: (() -> Void)?
    var pilotProfileCreationRequested: ((String) -> Void)?
    var pilotProfileConfirmationRequested: ((UUID) -> Void)?
    var pilotProfileCancellationRequested: (() -> Void)?

    private var heldKeys: Set<UInt16> = []
    private var pendingMouseX: Float = 0
    private var pendingMouseY: Float = 0
    private var activeController: GCController?
    private var gameplayIsActive = false
    private var mouseIsCaptured = false
    private var primaryFireIsHeld = false
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
    private let trainingRestartButton = NSButton(
        title: "Play Training Again",
        target: nil,
        action: nil
    )
    private let pilotProfileOverlay = NSView()
    private let pilotProfileTitle = NSTextField(
        labelWithString: "Choose Pilot"
    )
    private let pilotProfilePopup = NSPopUpButton()
    private let pilotProfileNameField = NSTextField()
    private let pilotProfileCreateButton = NSButton(
        title: "Create",
        target: nil,
        action: nil
    )
    private let pilotProfileConfirmButton = NSButton(
        title: "Confirm",
        target: nil,
        action: nil
    )
    private let pilotProfileCancelButton = NSButton(
        title: "Cancel",
        target: nil,
        action: nil
    )
    private var pilotProfileIDs: [UUID] = []
    private var trainingVoicePlayer: AVAudioPlayer?
    private var trainingSoundPlayers: [AVAudioPlayer] = []
    private var trainingGuidebotAmbientEnginePlayer: AVAudioPlayer?
    private var trainingMessageExpiresAt: Float?
    private var trainingResultIsPresented = false
    private var trainingResultPresentedAt: TimeInterval?
    private var pendingTrainingResultKeyAcknowledgement = false
    private var trainingGuidebotGoalWasSelected = false
    private var trainingGuidebotReturnToShipWasSelected = false
    private var trainingGuidebotReleaseWasSelected = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect, device: (any MTLDevice)?) {
        super.init(frame: frameRect, device: device)
        configureTrainingOverlay()
        configurePilotProfileOverlay()
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
        trainingRestartButton.sizeToFit()
        trainingRestartButton.frame.origin = NSPoint(
            x: max(
                24,
                bounds.midX - trainingRestartButton.frame.width / 2
            ),
            y: max(24, bounds.midY - 150)
        )
        let profileWidth = min(420, max(280, bounds.width - 64))
        let profileLeft = (bounds.width - profileWidth) / 2
        let profileBottom = max(40, (bounds.height - 230) / 2)
        pilotProfileOverlay.frame = bounds
        pilotProfileTitle.frame = NSRect(
            x: profileLeft,
            y: profileBottom + 185,
            width: profileWidth,
            height: 32
        )
        pilotProfilePopup.frame = NSRect(
            x: profileLeft,
            y: profileBottom + 140,
            width: profileWidth,
            height: 30
        )
        pilotProfileNameField.frame = NSRect(
            x: profileLeft,
            y: profileBottom + 92,
            width: profileWidth - 100,
            height: 28
        )
        pilotProfileCreateButton.frame = NSRect(
            x: profileLeft + profileWidth - 88,
            y: profileBottom + 91,
            width: 88,
            height: 30
        )
        let buttonWidth: CGFloat = 96
        let buttonGap: CGFloat = 12
        let buttonLeft =
            profileLeft + (profileWidth - buttonWidth * 2 - buttonGap) / 2
        pilotProfileCancelButton.frame = NSRect(
            x: buttonLeft,
            y: profileBottom + 32,
            width: buttonWidth,
            height: 32
        )
        pilotProfileConfirmButton.frame = NSRect(
            x: buttonLeft + buttonWidth + buttonGap,
            y: profileBottom + 32,
            width: buttonWidth,
            height: 32
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
        if Self.requestsHeadlightToggle(
            keyCode: event.keyCode,
            isRepeat: event.isARepeat,
            gameplayIsActive: gameplayIsActive
        ) {
            headlightToggleRequested?()
            return
        }
        if Self.requestsPlayerFlare(
            keyCode: event.keyCode,
            isRepeat: event.isARepeat,
            gameplayIsActive: gameplayIsActive
        ) {
            playerFlareRequested?()
            return
        }
        if event.keyCode == 9, gameplayIsActive {
            if Self.requestsRearView(
                keyCode: event.keyCode,
                isRepeat: event.isARepeat,
                gameplayIsActive: gameplayIsActive
            ) {
                rearViewInputChanged?(true, true)
            }
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
        if event.keyCode == 9 {
            rearViewInputChanged?(false, false)
            return
        }
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
        setPrimaryFireHeld(true)
    }

    override func mouseUp(with event: NSEvent) {
        setPrimaryFireHeld(false)
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
            stopTrainingGuidebotAmbientEngine()
            cameraMonitorBorder.isHidden = true
        }
    }

    func presentTrainingOpening(
        frame: PlayerSimulationFrame,
        voiceClips: [CanonicalVoiceClip],
        soundClips: [CanonicalSoundClip] = [],
        guidebotAmbientEngineSoundSourceName: String? = nil,
        rooms: [LevelRoom] = []
    ) throws {
        if let finalGoal = frame.trainingFinalGoal {
            clearInput()
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
            stopTrainingGuidebotAmbientEngine()
            trainingEndLevelLabel.stringValue =
                Self.trainingPostLevelResultText(
                    finalGoal.postLevelResult
                )
            trainingRestartButton.isEnabled = false
            trainingRestartButton.isHidden = true
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
        trainingRestartButton.isHidden = true
        let showsOrdinaryGameplayOverlays =
            Self.showsOrdinaryGameplayOverlays(
                rearViewIsActive: frame.rearViewIsActive
            )
        trainingMessageLabel.isHidden = !showsOrdinaryGameplayOverlays
        enabledControlsLabel.isHidden = !showsOrdinaryGameplayOverlays
        invulnerabilityStatusLabel.isHidden = !showsOrdinaryGameplayOverlays
        cloakStatusLabel.isHidden = !showsOrdinaryGameplayOverlays
        cameraMonitorBorder.isHidden = frame.trainingCameraMonitor == nil
        invulnerabilityStatusLabel.stringValue =
            Self.invulnerabilityStatusText(
                remaining: frame.trainingInvulnerabilityRemaining
            )
        let cloakStatus = Self.cloakStatusPresentation(
            frame.trainingCloak
        )
        cloakShipMonitor.isHidden = !showsOrdinaryGameplayOverlays
        cloakShipMonitor.alphaValue = cloakStatus.shipOpacity
        cloakStatusLabel.stringValue = cloakStatus.cloakText
        cloakStatusLabel.alphaValue = cloakStatus.cloakOpacity
        if showsOrdinaryGameplayOverlays,
           let pulse = Self.invulnerabilityMonitorPulse(
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
        updateTrainingGuidebotAmbientEngine(
            frame: frame,
            soundSourceName: guidebotAmbientEngineSoundSourceName,
            soundClips: soundClips,
            rooms: rooms
        )
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
                try self.playTrainingSound(
                    named: $0,
                    eventVolume: $1,
                    from: soundClips
                )
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
        attemptSound: (String, Float?) throws -> Void,
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
                    try attemptSound(
                        soundSourceName,
                        event.soundEventVolume
                    )
                },
                presentHUDMessages: {
                    guard !event.hudMessages.isEmpty else { return }
                    presentHUDMessages(event.hudMessages)
                }
            )
            if !event.trailingHUDMessages.isEmpty {
                presentHUDMessages(event.trailingHUDMessages)
            }
        }
    }

    private func playTrainingSound(
        named soundSourceName: String,
        eventVolume: Float?,
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
            player.volume = clip.importVolume * (eventVolume ?? 1)
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

    private func updateTrainingGuidebotAmbientEngine(
        frame: PlayerSimulationFrame,
        soundSourceName: String?,
        soundClips: [CanonicalSoundClip],
        rooms: [LevelRoom]
    ) {
        guard frame.trainingGuidebotAmbientEngineIsActive,
              let soundSourceName,
              let mix = Self.trainingGuidebotAmbientEngineSpatialMix(
                frame: frame,
                rooms: rooms
              ),
              let clip = soundClips.first(where: {
                  $0.sourceName.caseInsensitiveCompare(soundSourceName)
                    == .orderedSame
                    || $0.logicalName.caseInsensitiveCompare(soundSourceName)
                        == .orderedSame
              }) else {
            stopTrainingGuidebotAmbientEngine()
            return
        }

        if let player = trainingGuidebotAmbientEnginePlayer {
            player.volume = clip.importVolume * mix.volumeScale
            player.pan = mix.pan
            if !player.isPlaying, !player.play() {
                player.stop()
                trainingGuidebotAmbientEnginePlayer = nil
            }
            return
        }

        do {
            let player = try AVAudioPlayer(data: Self.waveData(for: clip))
            player.numberOfLoops = -1
            player.volume = clip.importVolume * mix.volumeScale
            player.pan = mix.pan
            player.prepareToPlay()
            guard player.play() else { return }
            trainingGuidebotAmbientEnginePlayer = player
        } catch {
            trainingGuidebotAmbientEnginePlayer = nil
        }
    }

    private func stopTrainingGuidebotAmbientEngine() {
        trainingGuidebotAmbientEnginePlayer?.stop()
        trainingGuidebotAmbientEnginePlayer = nil
    }

    static func trainingGuidebotAmbientEngineSpatialMix(
        frame: PlayerSimulationFrame,
        rooms: [LevelRoom]
    ) -> (volumeScale: Float, pan: Float)? {
        guard frame.trainingGuidebotAmbientEngineIsActive,
              let guidebot = frame.trainingGuidebot else {
            return nil
        }
        return trainingGuidebotAmbientEngineSpatialMix(
            sourcePosition: guidebot.position,
            sourceRoomSourceIndex: guidebot.roomSourceIndex,
            listener: frame.playerView,
            rooms: rooms
        )
    }

    static func trainingGuidebotAmbientEngineSpatialMix(
        sourcePosition: Vector3,
        sourceRoomSourceIndex: Int,
        listener: PlayerView,
        rooms: [LevelRoom]
    ) -> (volumeScale: Float, pan: Float)? {
        let camera = listener.camera
        guard let routed = trainingGuidebotAmbientEngineSpatialRoute(
            sourcePosition: sourcePosition,
            sourceRoomSourceIndex: sourceRoomSourceIndex,
            listener: listener,
            rooms: rooms
        ) else {
            return nil
        }
        let distance = routed.distance
        let direction = routed.direction
        let forward = Vector3(
            x: camera.target.x - camera.position.x,
            y: camera.target.y - camera.position.y,
            z: camera.target.z - camera.position.z
        )
        let right = Vector3(
            x: camera.up.y * forward.z - camera.up.z * forward.y,
            y: camera.up.z * forward.x - camera.up.x * forward.z,
            z: camera.up.x * forward.y - camera.up.y * forward.x
        )
        let rightLength = (
            right.x * right.x + right.y * right.y + right.z * right.z
        ).squareRoot()
        let pan = rightLength > 0
            ? max(-1, min(1,
                (direction.x * right.x
                    + direction.y * right.y
                    + direction.z * right.z) / rightLength
            ))
            : 0
        let volumeScale: Float
        if distance >= 100 {
            volumeScale = 0
        } else if distance > 10 {
            volumeScale = 1 - (distance - 10) / 90
        } else {
            volumeScale = 1
        }
        return (volumeScale * routed.doorVolumeScale, pan)
    }

    private static func trainingGuidebotAmbientEngineSpatialRoute(
        sourcePosition: Vector3,
        sourceRoomSourceIndex: Int,
        listener: PlayerView,
        rooms: [LevelRoom]
    ) -> (
        distance: Float,
        direction: Vector3,
        doorVolumeScale: Float
    )? {
        let roomBySourceIndex = Dictionary(
            uniqueKeysWithValues: rooms.map { ($0.sourceIndex, $0) }
        )
        guard roomBySourceIndex[sourceRoomSourceIndex] != nil,
              roomBySourceIndex[listener.roomSourceIndex] != nil else {
            return nil
        }
        let listenerPosition = listener.camera.position
        let directOffset = difference(sourcePosition, listenerPosition)
        if sourceRoomSourceIndex == listener.roomSourceIndex {
            let distance = length(directOffset)
            return (
                distance,
                normalizedAmbientEngineDirection(
                    directOffset,
                    fallback: difference(
                        listener.camera.target,
                        listenerPosition
                    )
                ),
                1
            )
        }

        var pending = [sourceRoomSourceIndex]
        var predecessor: [Int: Int] = [:]
        var visited: Set<Int> = [sourceRoomSourceIndex]
        while !pending.isEmpty
            && !visited.contains(listener.roomSourceIndex) {
            let roomSourceIndex = pending.removeFirst()
            let room = roomBySourceIndex[roomSourceIndex]!
            for (portalIndex, portal) in room.portals.enumerated() {
                guard let destination = roomBySourceIndex[
                    portal.connectedRoom
                ],
                    destination.portals.indices.contains(
                        portal.connectedPortal
                    )
                else {
                    continue
                }
                let reciprocal = destination.portals[
                    portal.connectedPortal
                ]
                guard reciprocal.connectedRoom == roomSourceIndex,
                      reciprocal.connectedPortal == portalIndex,
                      visited.insert(destination.sourceIndex).inserted
                else {
                    continue
                }
                predecessor[destination.sourceIndex] = roomSourceIndex
                pending.append(destination.sourceIndex)
            }
        }
        guard visited.contains(listener.roomSourceIndex) else { return nil }
        var route = [listener.roomSourceIndex]
        while route.last != sourceRoomSourceIndex {
            guard let prior = predecessor[route.last!] else { return nil }
            route.append(prior)
        }
        route.reverse()

        if route.count == 2 {
            let distance = length(directOffset)
            return (
                distance,
                normalizedAmbientEngineDirection(
                    directOffset,
                    fallback: difference(
                        listener.camera.target,
                        listenerPosition
                    )
                ),
                1
            )
        }

        var points = [sourcePosition]
        var listenerPortalPoint: Vector3?
        for (roomSourceIndex, nextRoomSourceIndex) in zip(
            route,
            route.dropFirst()
        ) {
            guard let portalIndex = roomBySourceIndex[roomSourceIndex]?
                .portals.firstIndex(where: {
                    $0.connectedRoom == nextRoomSourceIndex
                }),
                let portal = roomBySourceIndex[roomSourceIndex]?
                    .portals[portalIndex],
                let destination = roomBySourceIndex[nextRoomSourceIndex],
                destination.portals.indices.contains(
                    portal.connectedPortal
                )
            else {
                return nil
            }
            let reciprocal = destination.portals[portal.connectedPortal]
            points.append(portal.pathPoint)
            points.append(reciprocal.pathPoint)
            if nextRoomSourceIndex == listener.roomSourceIndex {
                listenerPortalPoint = reciprocal.pathPoint
            }
        }
        points.append(listenerPosition)
        var distance: Float = 0
        for (start, end) in zip(points, points.dropFirst()) {
            distance += length(difference(end, start))
        }
        var doorVolumeScale: Float = 1
        for roomSourceIndex in route.dropFirst().dropLast() {
            guard let door = roomBySourceIndex[roomSourceIndex]?.door else {
                continue
            }
            doorVolumeScale *= door.position == 0
                ? 0.2
                : 0.6 + 0.4 * door.position
        }
        let directionOffset = difference(
            listenerPortalPoint ?? sourcePosition,
            listenerPosition
        )
        return (
            distance,
            normalizedAmbientEngineDirection(
                directionOffset,
                fallback: difference(
                    listener.camera.target,
                    listenerPosition
                )
            ),
            doorVolumeScale
        )
    }

    private static func normalizedAmbientEngineDirection(
        _ vector: Vector3,
        fallback: Vector3
    ) -> Vector3 {
        let vectorLength = length(vector)
        if vectorLength > 0 { return scaled(vector, by: 1 / vectorLength) }
        let fallbackLength = length(fallback)
        return fallbackLength > 0
            ? scaled(fallback, by: 1 / fallbackLength)
            : .init(x: 0, y: 0, z: 1)
    }

    private static func difference(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
        .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    private static func scaled(_ vector: Vector3, by scale: Float) -> Vector3 {
        .init(
            x: vector.x * scale,
            y: vector.y * scale,
            z: vector.z * scale
        )
    }

    private static func length(_ vector: Vector3) -> Float {
        (
            vector.x * vector.x
                + vector.y * vector.y
                + vector.z * vector.z
        ).squareRoot()
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

    func presentTrainingGuidebotGoalMenu() -> Bool {
        trainingGuidebotGoalWasSelected = false
        let menu = Self.trainingGuidebotGoalMenu(
            target: self,
            action: #selector(selectTrainingGuidebotGoal)
        )
        let eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            guard Self.cancelsTrainingGuidebotGoalMenu(
                keyCode: event.keyCode
            ) else {
                return event
            }
            menu.cancelTracking()
            return nil
        }
        defer {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: bounds.midX, y: bounds.midY),
            in: self
        )
        return trainingGuidebotGoalWasSelected
    }

    @objc private func selectTrainingGuidebotGoal(_ sender: NSMenuItem) {
        guard sender.tag == 3 else { return }
        trainingGuidebotGoalWasSelected = true
    }

    func presentTrainingGuidebotReturnToShipMenu() -> Bool {
        trainingGuidebotReturnToShipWasSelected = false
        let menu = Self.trainingGuidebotReturnToShipMenu(
            target: self,
            action: #selector(selectTrainingGuidebotReturnToShip)
        )
        let eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            guard Self.cancelsTrainingGuidebotReturnToShipMenu(
                keyCode: event.keyCode
            ) else {
                return event
            }
            menu.cancelTracking()
            return nil
        }
        defer {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: bounds.midX, y: bounds.midY),
            in: self
        )
        return trainingGuidebotReturnToShipWasSelected
    }

    @objc private func selectTrainingGuidebotReturnToShip(
        _ sender: NSMenuItem
    ) {
        guard sender.tag == 43 else { return }
        trainingGuidebotReturnToShipWasSelected = true
    }

    func presentTrainingGuidebotReleaseMenu() -> Bool {
        trainingGuidebotReleaseWasSelected = false
        let menu = Self.trainingGuidebotReleaseMenu(
            target: self,
            action: #selector(selectTrainingGuidebotRelease)
        )
        let eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            guard Self.cancelsTrainingGuidebotReleaseMenu(
                keyCode: event.keyCode
            ) else {
                return event
            }
            menu.cancelTracking()
            return nil
        }
        defer {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: bounds.midX, y: bounds.midY),
            in: self
        )
        return trainingGuidebotReleaseWasSelected
    }

    @objc private func selectTrainingGuidebotRelease(
        _ sender: NSMenuItem
    ) {
        guard sender.tag == 0 else { return }
        trainingGuidebotReleaseWasSelected = true
    }

    func presentTrainingContentReadyState(completedLevelName: String) {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(trainingResultAdmissionDidOpen),
            object: nil
        )
        trainingResultIsPresented = false
        trainingResultPresentedAt = nil
        pendingTrainingResultKeyAcknowledgement = false
        trainingEndLevelLabel.stringValue = """
        \(completedLevelName) completed.

        Play Training Again, open canonical content, or quit.
        """
        trainingEndLevelOverlay.isHidden = false
        trainingEndLevelLabel.isHidden = false
        trainingRestartButton.isHidden = false
        setTrainingRestartAvailable(true)
    }

    func prepareForTrainingSession() {
        trainingRestartButton.isEnabled = false
        trainingRestartButton.isHidden = true
        trainingEndLevelOverlay.isHidden = true
        trainingEndLevelLabel.isHidden = true
    }

    func setTrainingRestartAvailable(_ available: Bool) {
        guard !trainingRestartButton.isHidden else { return }
        trainingRestartButton.isEnabled = available
    }

    func presentPilotProfileSelection(
        profiles: [(id: UUID, name: String)],
        defaultProfileID: UUID?,
        selectedProfileID: UUID?
    ) {
        pilotProfileIDs = profiles.map(\.id)
        pilotProfilePopup.removeAllItems()
        pilotProfilePopup.addItems(withTitles: profiles.map(\.name))
        let selection =
            selectedProfileID
            ?? defaultProfileID
            ?? profiles.first?.id
        if let selection,
           let index = pilotProfileIDs.firstIndex(of: selection) {
            pilotProfilePopup.selectItem(at: index)
        }
        pilotProfileConfirmButton.isEnabled = !pilotProfileIDs.isEmpty
        pilotProfileCancelButton.isEnabled = defaultProfileID != nil
        pilotProfileNameField.stringValue = ""
        pilotProfileOverlay.isHidden = false
        needsLayout = true
    }

    func hidePilotProfileSelection() {
        pilotProfileOverlay.isHidden = true
    }

    @objc func requestPilotProfileCreation() {
        pilotProfileCreationRequested?(pilotProfileNameField.stringValue)
    }

    @objc func requestPilotProfileConfirmation() {
        let index = pilotProfilePopup.indexOfSelectedItem
        guard pilotProfileIDs.indices.contains(index) else { return }
        pilotProfileConfirmationRequested?(pilotProfileIDs[index])
    }

    @objc func requestPilotProfileCancellation() {
        guard pilotProfileCancelButton.isEnabled else { return }
        pilotProfileCancellationRequested?()
    }

    @objc func requestTrainingRestart() {
        guard !trainingRestartButton.isHidden,
              trainingRestartButton.isEnabled else {
            return
        }
        setTrainingRestartAvailable(false)
        trainingRestartRequested?()
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

    static func trainingGuidebotGoalMenu(
        target: AnyObject?,
        action: Selector?
    ) -> NSMenu {
        let menu = NSMenu(title: "GB Command Menu")
        let item = NSMenuItem(
            title: "1. Get to Camera Monitor",
            action: action,
            keyEquivalent: "1"
        )
        item.target = target
        item.tag = 3
        item.keyEquivalentModifierMask = []
        menu.addItem(item)
        return menu
    }

    static func trainingGuidebotReturnToShipMenu(
        target: AnyObject?,
        action: Selector?
    ) -> NSMenu {
        let menu = NSMenu(title: "GB Command Menu")
        let item = NSMenuItem(
            title: "1. Return to ship",
            action: action,
            keyEquivalent: "1"
        )
        item.target = target
        item.tag = 43
        item.keyEquivalentModifierMask = []
        menu.addItem(item)
        return menu
    }

    static func trainingGuidebotReleaseMenu(
        target: AnyObject?,
        action: Selector?
    ) -> NSMenu {
        let menu = NSMenu(title: "GB Command Menu")
        let item = NSMenuItem(
            title: "1. Release Guidebot",
            action: action,
            keyEquivalent: "1"
        )
        item.target = target
        item.tag = 0
        item.keyEquivalentModifierMask = []
        menu.addItem(item)
        return menu
    }

    nonisolated static func cancelsTrainingGuidebotGoalMenu(
        keyCode: UInt16
    ) -> Bool {
        keyCode == 118 || keyCode == 53
    }

    nonisolated static func cancelsTrainingGuidebotReturnToShipMenu(
        keyCode: UInt16
    ) -> Bool {
        keyCode == 118 || keyCode == 53
    }

    nonisolated static func cancelsTrainingGuidebotReleaseMenu(
        keyCode: UInt16
    ) -> Bool {
        keyCode == 118 || keyCode == 53
    }

    nonisolated static func requestsInventoryUse(
        keyCode: UInt16,
        isRepeat: Bool,
        gameplayIsActive: Bool
    ) -> Bool {
        gameplayIsActive && !isRepeat && keyCode == 42
    }

    nonisolated static func requestsHeadlightToggle(
        keyCode: UInt16,
        isRepeat: Bool,
        gameplayIsActive: Bool
    ) -> Bool {
        gameplayIsActive && !isRepeat && keyCode == 4
    }

    nonisolated static func requestsPlayerFlare(
        keyCode: UInt16,
        isRepeat: Bool,
        gameplayIsActive: Bool
    ) -> Bool {
        gameplayIsActive && !isRepeat && keyCode == 5
    }

    nonisolated static func requestsRearView(
        keyCode: UInt16,
        isRepeat: Bool,
        gameplayIsActive: Bool
    ) -> Bool {
        gameplayIsActive && !isRepeat && keyCode == 9
    }

    nonisolated static func showsOrdinaryGameplayOverlays(
        rearViewIsActive: Bool
    ) -> Bool {
        !rearViewIsActive
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
        trainingRestartButton.target = self
        trainingRestartButton.action = #selector(requestTrainingRestart)
        trainingRestartButton.isHidden = true
        trainingRestartButton.setAccessibilityLabel(
            "Play Training Again"
        )
        addSubview(trainingRestartButton)
    }

    private func configurePilotProfileOverlay() {
        pilotProfileOverlay.wantsLayer = true
        pilotProfileOverlay.layer?.backgroundColor =
            NSColor.black.withAlphaComponent(0.94).cgColor
        pilotProfileOverlay.isHidden = true
        pilotProfileOverlay.setAccessibilityLabel("Pilot profile selection")
        addSubview(pilotProfileOverlay)

        pilotProfileTitle.alignment = .center
        pilotProfileTitle.font = .boldSystemFont(ofSize: 24)
        pilotProfileTitle.textColor = .white
        pilotProfileOverlay.addSubview(pilotProfileTitle)

        pilotProfilePopup.setAccessibilityLabel("Available pilots")
        pilotProfileOverlay.addSubview(pilotProfilePopup)

        pilotProfileNameField.placeholderString = "Pilot name"
        pilotProfileNameField.setAccessibilityLabel("New pilot name")
        pilotProfileOverlay.addSubview(pilotProfileNameField)

        pilotProfileCreateButton.target = self
        pilotProfileCreateButton.action =
            #selector(requestPilotProfileCreation)
        pilotProfileOverlay.addSubview(pilotProfileCreateButton)

        pilotProfileConfirmButton.target = self
        pilotProfileConfirmButton.action =
            #selector(requestPilotProfileConfirmation)
        pilotProfileOverlay.addSubview(pilotProfileConfirmButton)

        pilotProfileCancelButton.target = self
        pilotProfileCancelButton.action =
            #selector(requestPilotProfileCancellation)
        pilotProfileOverlay.addSubview(pilotProfileCancelButton)
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
        min(4, max(2, feedback.reduce(0) {
            $0 + $1.hudMessages.count + $1.trailingHUDMessages.count
        }))
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
        setPrimaryFireHeld(false)
        playerFlareRequestCancelled?()
        rearViewInputCancelled?()
        guard mouseIsCaptured else { return }
        mouseIsCaptured = false
        pendingMouseX = 0
        pendingMouseY = 0
        CGAssociateMouseAndMouseCursorPosition(1)
        NSCursor.unhide()
    }

    private func setPrimaryFireHeld(_ isHeld: Bool) {
        guard primaryFireIsHeld != isHeld else { return }
        primaryFireIsHeld = isHeld
        primaryFireHeldChanged?(isHeld)
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
