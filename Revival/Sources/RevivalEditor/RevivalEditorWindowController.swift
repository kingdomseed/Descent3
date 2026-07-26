// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit

@MainActor
final class RevivalEditorWindowController: NSWindowController, NSWindowDelegate {
    private unowned let projectDocument: RevivalProjectDocument
    private let gameplayView: RevivalGameplayView
    private let renderer: MetalWorldRenderer?
    private let selectedRoomHeading: NSTextField
    private let roomPopup: NSPopUpButton
    private let facePopup: NSPopUpButton
    private let vertexPopup: NSPopUpButton
    private let vertexXField: NSTextField
    private let vertexYField: NSTextField
    private let vertexZField: NSTextField
    private let setVertexButton: NSButton
    private let snapRoomField: NSTextField
    private let snapVertexField: NSTextField
    private let snapVertexButton: NSButton
    private let faceMaterialPopup: NSPopUpButton
    private let portalPopup: NSPopUpButton
    private let portalRenderingCheckbox: NSButton
    private let followPortalButton: NSButton
    private let roomNameField: NSTextField
    private let renameButton: NSButton
    private let objectPopup: NSPopUpButton
    private let rotateObjectButton: NSButton
    private let playerStartPopup: NSPopUpButton
    private let rotatePlayerStartButton: NSButton
    private let placementXField: NSTextField
    private let placementYField: NSTextField
    private let placementZField: NSTextField
    private let moveObjectButton: NSButton
    private let movePlayerStartButton: NSButton
    private let changesLabel: NSTextField
    private let playButton: NSButton
    private let collisionDiagnosticButton: NSButton
    private let statusLabel: NSTextField
    private var rendererError: String?
    private var selectedVertexIndex: Int?
    private var selectedObjectHandle: UInt32?
    private var selectedPlayerStartHandle: UInt32?
    private var placementOwner = RevivalEditorPlacementOwner.object
    private var playSimulation: PlayerSimulation?
    private var playerInput = PlayerInputState()

    init(document: RevivalProjectDocument) {
        projectDocument = document

        let metalView = RevivalGameplayView(
            frame: .zero,
            device: MTLCreateSystemDefaultDevice()
        )
        gameplayView = metalView
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.setAccessibilityLabel("Training level viewport")
        metalView.setAccessibilityHelp(
            "Shows the fixed source room 3 portal closure. Editor selection can move independently without recentering this camera."
        )
        do {
            renderer = try MetalWorldRenderer(view: metalView)
        } catch {
            renderer = nil
            rendererError = error.localizedDescription
        }

        selectedRoomHeading = NSTextField(labelWithString: "Selected Source Room 3")
        selectedRoomHeading.font = .preferredFont(forTextStyle: .headline)

        roomPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        roomPopup.setAccessibilityLabel("Selected source room")
        roomPopup.setAccessibilityHelp("Selects a room in the complete canonical Training level.")

        facePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        facePopup.setAccessibilityLabel("Selected face")
        facePopup.setAccessibilityHelp("Selects a face in the current source room.")

        vertexPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        vertexPopup.setAccessibilityLabel("Selected room vertex")
        vertexXField = NSTextField(string: "")
        vertexYField = NSTextField(string: "")
        vertexZField = NSTextField(string: "")
        setVertexButton = NSButton(title: "Set Vertex Position", target: nil, action: nil)
        snapRoomField = NSTextField(string: "")
        snapRoomField.placeholderString = "Target room"
        snapVertexField = NSTextField(string: "")
        snapVertexField.placeholderString = "Target vertex"
        snapVertexButton = NSButton(title: "Snap Vertex to Target", target: nil, action: nil)

        faceMaterialPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        faceMaterialPopup.setAccessibilityLabel("Selected face material")
        faceMaterialPopup.setAccessibilityHelp(
            "Applies one of the complete level's prepared canonical materials to the selected face."
        )

        portalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        portalPopup.setAccessibilityLabel("Selected portal")
        portalPopup.setAccessibilityHelp(
            "Selects a portal and its owning face in the current source room."
        )

        portalRenderingCheckbox = NSButton(
            checkboxWithTitle: "Render portal face",
            target: nil,
            action: nil
        )
        portalRenderingCheckbox.setAccessibilityHelp(
            "Changes the selected portal's source-backed render-faces property without changing topology."
        )

        followPortalButton = NSButton(title: "Follow Portal", target: nil, action: nil)
        followPortalButton.setAccessibilityLabel("Follow selected portal")
        followPortalButton.setAccessibilityHelp(
            "Navigates to the connected room and reciprocal portal reference."
        )

        let roomNameField = NSTextField(string: "")
        roomNameField.placeholderString = "Room name"
        roomNameField.setAccessibilityLabel("Selected room name")
        roomNameField.setAccessibilityHelp(
            "Enter a user-authored name for the selected source room and press Return."
        )
        self.roomNameField = roomNameField

        renameButton = NSButton(title: "Rename Room", target: nil, action: nil)
        renameButton.setAccessibilityLabel("Rename selected room")

        objectPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        objectPopup.setAccessibilityLabel("Reached object")
        objectPopup.setAccessibilityHelp("Selects a reached non-player object by stable handle.")
        rotateObjectButton = NSButton(title: "Rotate Object 90°", target: nil, action: nil)
        rotateObjectButton.setAccessibilityHelp(
            "Applies a direct rigid quarter-turn without collision or room-membership changes."
        )

        playerStartPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        playerStartPopup.setAccessibilityLabel("Player start")
        playerStartPopup.setAccessibilityHelp("Selects a player start by player ID and stable handle.")
        rotatePlayerStartButton = NSButton(
            title: "Rotate Player Start 90°",
            target: nil,
            action: nil
        )
        rotatePlayerStartButton.setAccessibilityHelp(
            "Applies a direct rigid quarter-turn to the authoritative player-start object."
        )
        placementXField = NSTextField(string: "")
        placementYField = NSTextField(string: "")
        placementZField = NSTextField(string: "")
        moveObjectButton = NSButton(title: "Move Object", target: nil, action: nil)
        movePlayerStartButton = NSButton(title: "Move Player Start", target: nil, action: nil)

        changesLabel = NSTextField(wrappingLabelWithString: "No authored changes")
        changesLabel.setAccessibilityLabel("Semantic project changes")
        changesLabel.textColor = .secondaryLabelColor
        changesLabel.maximumNumberOfLines = 1

        playButton = NSButton(title: "Play Disposable Copy", target: nil, action: nil)
        playButton.bezelStyle = .rounded
        playButton.setAccessibilityLabel("Play disposable copy")

        collisionDiagnosticButton = NSButton(
            title: "Probe Selected Portal",
            target: nil,
            action: nil
        )
        collisionDiagnosticButton.setAccessibilityLabel("Probe selected portal collision")
        collisionDiagnosticButton.setAccessibilityHelp(
            "Reports whether the disposable play copy crosses the selected portal and which source room owns the result."
        )

        let statusLabel = NSTextField(wrappingLabelWithString: "")
        statusLabel.setAccessibilityLabel("Editor status")
        statusLabel.textColor = .secondaryLabelColor
        self.statusLabel = statusLabel

        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let sidebar = NSStackView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 10
        sidebar.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        sidebar.addArrangedSubview(selectedRoomHeading)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Room"))
        sidebar.addArrangedSubview(roomPopup)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Face"))
        sidebar.addArrangedSubview(facePopup)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Room Vertex"))
        sidebar.addArrangedSubview(vertexPopup)
        let vertexCoordinates = NSStackView(views: [vertexXField, vertexYField, vertexZField])
        vertexCoordinates.orientation = .horizontal
        vertexCoordinates.distribution = .fillEqually
        vertexCoordinates.spacing = 4
        sidebar.addArrangedSubview(vertexCoordinates)
        sidebar.addArrangedSubview(setVertexButton)
        let snapTarget = NSStackView(views: [snapRoomField, snapVertexField])
        snapTarget.orientation = .horizontal
        snapTarget.distribution = .fillEqually
        snapTarget.spacing = 4
        sidebar.addArrangedSubview(snapTarget)
        sidebar.addArrangedSubview(snapVertexButton)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Face Material"))
        sidebar.addArrangedSubview(faceMaterialPopup)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Portal"))
        sidebar.addArrangedSubview(portalPopup)
        sidebar.addArrangedSubview(portalRenderingCheckbox)
        sidebar.addArrangedSubview(followPortalButton)
        sidebar.addArrangedSubview(roomNameField)
        sidebar.addArrangedSubview(renameButton)
        let editSeparator = NSBox()
        editSeparator.boxType = .separator
        sidebar.addArrangedSubview(editSeparator)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Reached Object"))
        sidebar.addArrangedSubview(objectPopup)
        sidebar.addArrangedSubview(rotateObjectButton)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Player Start"))
        sidebar.addArrangedSubview(playerStartPopup)
        sidebar.addArrangedSubview(rotatePlayerStartButton)
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Placement X / Y / Z"))
        let placementCoordinates = NSStackView(
            views: [placementXField, placementYField, placementZField]
        )
        placementCoordinates.orientation = .horizontal
        placementCoordinates.distribution = .fillEqually
        placementCoordinates.spacing = 4
        sidebar.addArrangedSubview(placementCoordinates)
        let placementButtons = NSStackView(views: [moveObjectButton, movePlayerStartButton])
        placementButtons.orientation = .horizontal
        placementButtons.spacing = 4
        sidebar.addArrangedSubview(placementButtons)
        let changesHeading = NSTextField(labelWithString: "Changes")
        changesHeading.font = .preferredFont(forTextStyle: .headline)
        sidebar.addArrangedSubview(changesHeading)
        sidebar.addArrangedSubview(changesLabel)
        let playSeparator = NSBox()
        playSeparator.boxType = .separator
        sidebar.addArrangedSubview(playSeparator)
        sidebar.addArrangedSubview(playButton)
        sidebar.addArrangedSubview(collisionDiagnosticButton)

        let statusSeparator = NSBox()
        statusSeparator.boxType = .separator
        sidebar.addArrangedSubview(statusSeparator)
        sidebar.addArrangedSubview(statusLabel)

        let sidebarScroll = NSScrollView()
        sidebarScroll.translatesAutoresizingMaskIntoConstraints = false
        sidebarScroll.drawsBackground = false
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.autohidesScrollers = true
        sidebarScroll.documentView = sidebar
        root.addSubview(sidebarScroll)
        root.addSubview(metalView)
        NSLayoutConstraint.activate([
            sidebarScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebarScroll.topAnchor.constraint(equalTo: root.topAnchor),
            sidebarScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebarScroll.widthAnchor.constraint(equalToConstant: 300),
            sidebar.leadingAnchor.constraint(equalTo: sidebarScroll.contentView.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: sidebarScroll.contentView.trailingAnchor),
            sidebar.topAnchor.constraint(equalTo: sidebarScroll.contentView.topAnchor),
            sidebar.bottomAnchor.constraint(
                greaterThanOrEqualTo: sidebarScroll.contentView.bottomAnchor
            ),
            roomPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            facePopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            vertexPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            vertexCoordinates.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            snapTarget.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            faceMaterialPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            portalPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            roomNameField.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            objectPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            playerStartPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            placementCoordinates.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            changesLabel.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            statusLabel.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),

            metalView.leadingAnchor.constraint(equalTo: sidebarScroll.trailingAnchor),
            metalView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            metalView.topAnchor.constraint(equalTo: root.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            metalView.widthAnchor.constraint(greaterThanOrEqualToConstant: 480),
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_100, height: 1_180),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RevivalEditor"
        window.contentMinSize = NSSize(width: 780, height: 720)
        window.contentView = root

        super.init(window: window)

        window.delegate = self
        metalView.heldInputChanged = {
            [weak self] in self?.playerInput.setHeld($0)
        }
        metalView.controllerInputChanged = {
            [weak self] in self?.playerInput.setController($0)
        }
        metalView.guidebotDeployRequested = {
            [weak self] in self?.playerInput.requestGuidebotDeployment()
        }
        metalView.primaryFireRequested = {
            [weak self] in self?.playerInput.requestPrimaryFire()
        }
        metalView.inventoryUseRequested = {
            [weak self] in self?.playerInput.requestInventoryUse()
        }
        window.initialFirstResponder = roomNameField
        roomNameField.target = self
        roomNameField.action = #selector(commitRoomName(_:))
        renameButton.target = self
        renameButton.action = #selector(commitRoomName(_:))
        roomPopup.target = self
        roomPopup.action = #selector(selectRoom(_:))
        facePopup.target = self
        facePopup.action = #selector(selectFace(_:))
        vertexPopup.target = self
        vertexPopup.action = #selector(selectVertex(_:))
        setVertexButton.target = self
        setVertexButton.action = #selector(setVertexPosition(_:))
        snapVertexButton.target = self
        snapVertexButton.action = #selector(snapVertex(_:))
        faceMaterialPopup.target = self
        faceMaterialPopup.action = #selector(setFaceMaterial(_:))
        portalPopup.target = self
        portalPopup.action = #selector(selectPortal(_:))
        portalRenderingCheckbox.target = self
        portalRenderingCheckbox.action = #selector(setPortalRendering(_:))
        followPortalButton.target = self
        followPortalButton.action = #selector(followPortal(_:))
        objectPopup.target = self
        objectPopup.action = #selector(selectObject(_:))
        rotateObjectButton.target = self
        rotateObjectButton.action = #selector(rotateObject(_:))
        playerStartPopup.target = self
        playerStartPopup.action = #selector(selectPlayerStart(_:))
        rotatePlayerStartButton.target = self
        rotatePlayerStartButton.action = #selector(rotatePlayerStart(_:))
        moveObjectButton.target = self
        moveObjectButton.action = #selector(moveObject(_:))
        movePlayerStartButton.target = self
        movePlayerStartButton.action = #selector(movePlayerStart(_:))
        playButton.target = self
        playButton.action = #selector(togglePlay(_:))
        collisionDiagnosticButton.target = self
        collisionDiagnosticButton.action = #selector(probeSelectedPortal(_:))
        refreshFromDocument()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func refreshFromDocument(renderWorld: Bool = true) {
        let selection = projectDocument.editorSelection
        let level = projectDocument.project.level
        let room = projectDocument.project.level.rooms.first {
            $0.sourceIndex == selection.room.sourceIndex
        }
        selectedRoomHeading.stringValue = "Selected Source Room \(selection.room.sourceIndex)"
        populateSelectionControls(level: level, selection: selection)
        populateObjectControls(level: level)
        let differences = projectDocument.project.semanticDiff
        changesLabel.stringValue = boundedSemanticChangesText(
            differences.map(\.summary)
        )
        roomNameField.stringValue = room?.name ?? ""

        let isPlaying = projectDocument.playSession != nil
        roomPopup.isEnabled = !isPlaying
        facePopup.isEnabled = !isPlaying
        vertexPopup.isEnabled = !isPlaying
        vertexXField.isEnabled = !isPlaying
        vertexYField.isEnabled = !isPlaying
        vertexZField.isEnabled = !isPlaying
        setVertexButton.isEnabled = !isPlaying
        snapRoomField.isEnabled = !isPlaying
        snapVertexField.isEnabled = !isPlaying
        snapVertexButton.isEnabled = !isPlaying
        faceMaterialPopup.isEnabled = !isPlaying
        portalPopup.isEnabled = !isPlaying && !(room?.portals.isEmpty ?? true)
        portalRenderingCheckbox.isEnabled = !isPlaying && selection.portal != nil
        followPortalButton.isEnabled = !isPlaying && selection.portal != nil
        roomNameField.isEnabled = !isPlaying
        renameButton.isEnabled = !isPlaying
        objectPopup.isEnabled = !isPlaying && objectPopup.numberOfItems > 0
        rotateObjectButton.isEnabled = objectPopup.isEnabled
        playerStartPopup.isEnabled = !isPlaying && playerStartPopup.numberOfItems > 0
        rotatePlayerStartButton.isEnabled = playerStartPopup.isEnabled
        placementXField.isEnabled = !isPlaying
        placementYField.isEnabled = !isPlaying
        placementZField.isEnabled = !isPlaying
        moveObjectButton.isEnabled = objectPopup.isEnabled && placementOwner == .object
        movePlayerStartButton.isEnabled =
            playerStartPopup.isEnabled && placementOwner == .playerStart
        playButton.title = isPlaying ? "Return to Editor" : "Play Disposable Copy"
        playButton.setAccessibilityLabel(playButton.title)
        collisionDiagnosticButton.isEnabled = isPlaying && selection.portal != nil
        if let rendererError {
            setStatus(rendererError, isError: true)
        } else if isPlaying {
            setStatus(
                "Playing a separately owned complete-level copy. Use W/S to thrust and A/D to slide.",
                isError: false
            )
        } else {
            setStatus(
                editorIdleStatusMessage(
                    project: projectDocument.project,
                    selection: selection
                ),
                isError: false
            )
        }
        if renderWorld {
            renderCurrentWorld()
        }
    }

    func windowWillClose(_ notification: Notification) {
        renderer?.shutdown()
    }

    func windowDidResignKey(_ notification: Notification) {
        playerInput.setGameplayActive(
            false,
            simulation: playSimulation,
            at: ProcessInfo.processInfo.systemUptime
        )
        gameplayView.setGameplayActive(false)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard playSimulation != nil else { return }
        playerInput.setGameplayActive(
            true,
            simulation: playSimulation,
            at: ProcessInfo.processInfo.systemUptime
        )
        gameplayView.setGameplayActive(true)
        window?.makeFirstResponder(gameplayView)
    }

    @objc private func commitRoomName(_ sender: Any?) {
        do {
            try projectDocument.renameSelectedRoom(to: roomNameField.stringValue)
            window?.makeFirstResponder(nil)
            roomNameField.stringValue = projectDocument.project.level.rooms.first {
                $0.sourceIndex == projectDocument.selectedRoomSourceIndex
            }?.name ?? ""
            setSuccessStatus(
                "Renamed source room \(projectDocument.selectedRoomSourceIndex). Undo action: Rename Room."
            )
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func selectRoom(_ sender: NSPopUpButton) {
        performSelectionChange {
            guard let sourceIndex = sender.selectedItem?.representedObject as? Int else {
                return
            }
            try projectDocument.selectRoom(sourceIndex: sourceIndex)
        }
    }

    @objc private func selectFace(_ sender: NSPopUpButton) {
        performSelectionChange {
            guard let faceIndex = sender.selectedItem?.representedObject as? Int else {
                return
            }
            try projectDocument.selectFace(faceIndex)
        }
    }

    @objc private func selectVertex(_ sender: NSPopUpButton) {
        selectedVertexIndex = sender.selectedItem?.representedObject as? Int
        refreshVertexCoordinates()
    }

    @objc private func setVertexPosition(_ sender: Any?) {
        do {
            let identity = try selectedVertexIdentity()
            try projectDocument.setRoomVertex(
                roomSourceIndex: identity.room,
                vertexIndex: identity.vertex,
                to: try coordinates(
                    x: vertexXField,
                    y: vertexYField,
                    z: vertexZField
                )
            )
            setSuccessStatus(
                "Set source room \(identity.room) vertex \(identity.vertex). Undo action: Set Room Vertex."
            )
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func snapVertex(_ sender: Any?) {
        do {
            let identity = try selectedVertexIdentity()
            guard let targetRoom = Int(snapRoomField.stringValue),
                  let targetVertex = Int(snapVertexField.stringValue) else {
                throw RevivalProjectError.invalidRoomVertexEdit(
                    roomSourceIndex: identity.room,
                    vertexIndex: identity.vertex
                )
            }
            try projectDocument.snapRoomVertex(
                roomSourceIndex: identity.room,
                vertexIndex: identity.vertex,
                toRoomSourceIndex: targetRoom,
                toVertexIndex: targetVertex
            )
            setSuccessStatus(
                "Snapped source room \(identity.room) vertex \(identity.vertex) to room \(targetRoom) vertex \(targetVertex). Undo action: Snap Room Vertex."
            )
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func selectPortal(_ sender: NSPopUpButton) {
        performSelectionChange {
            guard let portalIndex = sender.selectedItem?.representedObject as? Int else {
                return
            }
            try projectDocument.selectPortal(portalIndex)
        }
    }

    @objc private func setFaceMaterial(_ sender: NSPopUpButton) {
        do {
            guard sender.indexOfSelectedItem >= 0 else { return }
            let texture = projectDocument.project.level.presentationMaterials[
                sender.indexOfSelectedItem
            ].texture
            try projectDocument.setSelectedFaceMaterial(to: texture)
            setSuccessStatus("Set the selected face material. Undo action: Set Face Material.")
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func setPortalRendering(_ sender: NSButton) {
        do {
            try projectDocument.setSelectedPortalRendersFaces(sender.state == .on)
            setSuccessStatus("Set the selected portal rendering property. Undo action: Set Portal Rendering.")
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func selectObject(_ sender: NSPopUpButton) {
        selectedObjectHandle = sender.selectedItem?.representedObject as? UInt32
        placementOwner = .object
        refreshPlacementCoordinates(handle: selectedObjectHandle)
        refreshFromDocument(renderWorld: false)
    }

    @objc private func rotateObject(_ sender: Any?) {
        do {
            let handle = selectedObjectHandle!
            try projectDocument.rotateObjectQuarterTurn(handle: handle)
            setSuccessStatus("Rotated object handle \(handle). Undo action: Transform Object.")
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func selectPlayerStart(_ sender: NSPopUpButton) {
        selectedPlayerStartHandle = sender.selectedItem?.representedObject as? UInt32
        placementOwner = .playerStart
        refreshPlacementCoordinates(handle: selectedPlayerStartHandle)
        refreshFromDocument(renderWorld: false)
    }

    @objc private func rotatePlayerStart(_ sender: Any?) {
        do {
            let handle = selectedPlayerStartHandle!
            try projectDocument.rotatePlayerStartQuarterTurn(handle: handle)
            setSuccessStatus(
                "Rotated player start handle \(handle). Undo action: Transform Player Start."
            )
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func moveObject(_ sender: Any?) {
        do {
            let handle = selectedObjectHandle!
            let result = try projectDocument.moveObject(
                handle: handle,
                to: try coordinates(
                    x: placementXField,
                    y: placementYField,
                    z: placementZField
                )
            )
            setSuccessStatus(
                result.diagnostic
                    ?? "Moved object \(handle) to \(result.committedLocation). Undo action: Move Object."
            )
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func movePlayerStart(_ sender: Any?) {
        do {
            let handle = selectedPlayerStartHandle!
            let playerID = projectDocument.project.level.objects.first {
                $0.handle == handle
            }!.storedID
            let result = try projectDocument.movePlayerStart(
                playerID: playerID,
                handle: handle,
                to: try coordinates(
                    x: placementXField,
                    y: placementYField,
                    z: placementZField
                )
            )
            setSuccessStatus(
                result.diagnostic
                    ?? "Moved player \(playerID) start \(handle) to \(result.committedLocation). Undo action: Move Player Start."
            )
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func followPortal(_ sender: Any?) {
        performSelectionChange {
            projectDocument.followSelectedPortal()
        }
    }

    @objc private func togglePlay(_ sender: Any?) {
        do {
            if projectDocument.playSession == nil {
                let candidate = projectDocument.makePlaySession()
                try replaceRenderedWorld(session: candidate)
                let simulation = candidate.makePlayerSimulation(
                    presentationReadyTimestamp: ProcessInfo.processInfo.systemUptime
                )
                playSimulation = simulation
                playerInput = PlayerInputState()
                playerInput.setGameplayActive(
                    window?.isKeyWindow == true,
                    simulation: simulation,
                    at: ProcessInfo.processInfo.systemUptime
                )
                gameplayView.setGameplayActive(playerInput.gameplayIsActive)
                renderer?.setFrameUpdate { [weak self, weak renderer] timestamp in
                    guard let self, let renderer,
                          self.playSimulation === simulation,
                          self.playerInput.gameplayIsActive else {
                        return
                    }
                    let mouse = self.gameplayView.drainMouseDelta()
                    self.playerInput.accumulateMouseDelta(x: mouse.x, y: mouse.y)
                    let input = self.playerInput.snapshot(
                        frameDuration: simulation.frameDuration
                    )
                    let frame = simulation.update(at: timestamp, input: input)
                    do {
                        try self.gameplayView.presentTrainingOpening(
                            frame: frame,
                            voiceClips: simulation.level.voiceClips,
                            soundClips: simulation.level.soundClips
                        )
                        try renderer.update(
                            level: simulation.level,
                            frame: frame
                        )
                    } catch {
                        renderer.setFrameUpdate(nil)
                        self.setStatus(error.localizedDescription, isError: true)
                    }
                }
                projectDocument.commitPlaySession(candidate, renderingWorld: false)
                window?.makeFirstResponder(gameplayView)
                setSuccessStatus("Playing a disposable complete-level copy.")
            } else if projectDocument.playSession != nil {
                renderer?.setFrameUpdate(nil)
                playSimulation = nil
                gameplayView.setGameplayActive(false)
                playerInput = PlayerInputState()
                try replaceRenderedWorld(
                    level: projectDocument.project.level,
                    camera: projectDocument.camera
                )
                projectDocument.returnToEditor(renderingWorld: false)
                window?.makeFirstResponder(roomNameField)
                setSuccessStatus("Returned to the unchanged editor document state.")
            }
        } catch {
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func probeSelectedPortal(_ sender: Any?) {
        do {
            let trace = try projectDocument.traceSelectedPlayPortal(radius: 0.25)
            setSuccessStatus(indoorMovementDiagnosticMessage(trace))
        } catch {
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    private func renderCurrentWorld() {
        do {
            try replaceRenderedWorld()
        } catch {
            rendererError = error.localizedDescription
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func replaceRenderedWorld() throws {
        if let session = projectDocument.playSession {
            try replaceRenderedWorld(session: session)
        } else {
            try replaceRenderedWorld(
                level: projectDocument.project.level,
                camera: projectDocument.camera
            )
        }
    }

    private func replaceRenderedWorld(session: RevivalPlaySession) throws {
        guard let renderer else {
            throw MetalWorldRendererError.metalUnavailable
        }
        try renderer.replace(level: session.level, playerView: session.playerView)
        renderer.drawNow()
        rendererError = nil
    }

    private func replaceRenderedWorld(
        level: Level,
        camera: RoomCamera
    ) throws {
        guard let renderer else {
            throw MetalWorldRendererError.metalUnavailable
        }
        try renderer.replace(
            level: level,
            camera: camera,
            startRoomSourceIndex: projectDocument.cameraContainingRoomSourceIndex
        )
        renderer.drawNow()
        rendererError = nil
    }

    private func populateSelectionControls(
        level: Level,
        selection: RevivalEditorSelection
    ) {
        roomPopup.removeAllItems()
        for room in level.rooms.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
            roomPopup.addItem(withTitle: "Source Room \(room.sourceIndex)")
            roomPopup.lastItem?.representedObject = room.sourceIndex
        }
        roomPopup.selectItem(withTitle: "Source Room \(selection.room.sourceIndex)")

        let room = level.rooms.first { $0.sourceIndex == selection.room.sourceIndex }!
        facePopup.removeAllItems()
        for faceIndex in room.faces.indices {
            facePopup.addItem(withTitle: "Face \(faceIndex)")
            facePopup.lastItem?.representedObject = faceIndex
        }
        facePopup.selectItem(withTitle: "Face \(selection.face.faceIndex)")
        let faceVertexIndices = room.faces[selection.face.faceIndex].corners.map(\.vertexIndex)
        if !faceVertexIndices.contains(where: { $0 == selectedVertexIndex }) {
            selectedVertexIndex = faceVertexIndices.first
        }
        vertexPopup.removeAllItems()
        for vertexIndex in faceVertexIndices {
            vertexPopup.addItem(withTitle: "Vertex \(vertexIndex)")
            vertexPopup.lastItem?.representedObject = vertexIndex
        }
        if let selectedVertexIndex {
            vertexPopup.selectItem(withTitle: "Vertex \(selectedVertexIndex)")
        }
        refreshVertexCoordinates()
        faceMaterialPopup.removeAllItems()
        for material in level.presentationMaterials {
            faceMaterialPopup.addItem(withTitle: material.texture.sourceName)
        }
        let selectedTexture = room.faces[selection.face.faceIndex].texture
        if let materialIndex = level.presentationMaterials.firstIndex(where: {
            $0.texture == selectedTexture
        }) {
            faceMaterialPopup.selectItem(at: materialIndex)
        }

        portalPopup.removeAllItems()
        for portalIndex in room.portals.indices {
            portalPopup.addItem(withTitle: "Portal \(portalIndex)")
            portalPopup.lastItem?.representedObject = portalIndex
        }
        if let portal = selection.portal {
            portalPopup.selectItem(withTitle: "Portal \(portal.portalIndex)")
            portalRenderingCheckbox.state = room.portals[portal.portalIndex].flags & 1 != 0
                ? .on
                : .off
        } else {
            portalPopup.select(nil)
            portalRenderingCheckbox.state = .off
        }
    }

    private func populateObjectControls(level: Level) {
        let presentedHandles = Set(level.objectPresentations.map(\.objectHandle))
        let objects = level.objects.filter {
            $0.type != D3SourceIdentity.playerObjectType
                && (presentedHandles.isEmpty || presentedHandles.contains($0.handle))
        }.sorted { $0.handle < $1.handle }
        if !objects.contains(where: { $0.handle == selectedObjectHandle }) {
            selectedObjectHandle = objects.first?.handle
        }
        objectPopup.removeAllItems()
        for object in objects {
            let label = object.instanceName.map { "\($0) — \(object.handle)" }
                ?? "Object \(object.handle)"
            objectPopup.addItem(withTitle: label)
            objectPopup.lastItem?.representedObject = object.handle
        }
        if let handle = selectedObjectHandle,
           let index = objects.firstIndex(where: { $0.handle == handle }) {
            objectPopup.selectItem(at: index)
        }

        let players = level.objects.filter {
            $0.type == D3SourceIdentity.playerObjectType
        }.sorted { ($0.storedID, $0.handle) < ($1.storedID, $1.handle) }
        if !players.contains(where: { $0.handle == selectedPlayerStartHandle }) {
            selectedPlayerStartHandle = players.first?.handle
        }
        playerStartPopup.removeAllItems()
        for player in players {
            playerStartPopup.addItem(
                withTitle: "Player \(player.storedID) — \(player.handle)"
            )
            playerStartPopup.lastItem?.representedObject = player.handle
        }
        if let handle = selectedPlayerStartHandle,
           let index = players.firstIndex(where: { $0.handle == handle }) {
            playerStartPopup.selectItem(at: index)
        }
        refreshPlacementCoordinates(
            handle: placementOwner == .object
                ? selectedObjectHandle
                : selectedPlayerStartHandle
        )
    }

    private func selectedVertexIdentity() throws -> (room: Int, vertex: Int) {
        guard let vertex = selectedVertexIndex else {
            throw RevivalEditorInputError.invalidCoordinates
        }
        return (projectDocument.selectedRoomSourceIndex, vertex)
    }

    private func refreshVertexCoordinates() {
        guard let selectedVertexIndex,
              let room = projectDocument.project.level.rooms.first(where: {
                  $0.sourceIndex == projectDocument.selectedRoomSourceIndex
              }),
              room.vertices.indices.contains(selectedVertexIndex) else {
            return
        }
        let position = room.vertices[selectedVertexIndex]
        vertexXField.stringValue = String(position.x)
        vertexYField.stringValue = String(position.y)
        vertexZField.stringValue = String(position.z)
        if snapRoomField.stringValue.isEmpty {
            snapRoomField.stringValue = String(room.sourceIndex)
        }
    }

    private func refreshPlacementCoordinates(handle: UInt32?) {
        guard let handle,
              let object = projectDocument.project.level.objects.first(where: {
                  $0.handle == handle
              }) else {
            return
        }
        placementXField.stringValue = String(object.position.x)
        placementYField.stringValue = String(object.position.y)
        placementZField.stringValue = String(object.position.z)
    }

    private func coordinates(
        x: NSTextField,
        y: NSTextField,
        z: NSTextField
    ) throws -> Vector3 {
        guard let x = Float(x.stringValue),
              let y = Float(y.stringValue),
              let z = Float(z.stringValue),
              x.isFinite, y.isFinite, z.isFinite else {
            throw RevivalEditorInputError.invalidCoordinates
        }
        return .init(x: x, y: y, z: z)
    }

    private func performSelectionChange(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            refreshFromDocument()
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func setSuccessStatus(_ message: String) {
        guard rendererError == nil else { return }
        setStatus(message, isError: false)
    }

}

private enum RevivalEditorInputError: Error, LocalizedError {
    case invalidCoordinates

    var errorDescription: String? {
        "Enter finite numeric X, Y, and Z coordinates."
    }
}

private enum RevivalEditorPlacementOwner {
    case object
    case playerStart
}

func boundedSemanticChangesText(_ summaries: [String]) -> String {
    guard let first = summaries.first else { return "No authored changes" }
    guard summaries.count > 1 else { return first }
    return "\(first) (+\(summaries.count - 1) more)"
}

func editorIdleStatusMessage(
    project: RevivalProject,
    selection: RevivalEditorSelection
) -> String {
    let level = project.level
    let status =
        "Editing \(level.metadata.name) — \(level.rooms.count) complete resident rooms — source room \(selection.room.sourceIndex), face \(selection.face.faceIndex) selected — \(project.semanticDiff.count) authored changes."
    let sourceDiagnostics = [
        project.trainingGalleryBarrierSourceDiagnostic,
        project.trainingRobotGuidebotSourceDiagnostic,
        project.trainingGuidebotReturnSourceDiagnostic,
    ].compactMap { $0 }
    guard !sourceDiagnostics.isEmpty else { return status }
    return "\(status)\nSource: \(sourceDiagnostics.joined(separator: "; "))"
}

func indoorMovementDiagnosticMessage(_ trace: IndoorMovementTrace) -> String {
    switch trace.outcome {
    case .noHit:
        "Crossed selected portal; resulting room \(trace.containingRoomSourceIndex)."
    case .wallHit(let contact):
        "Blocked at source room \(contact.roomSourceIndex) face \(contact.faceIndex); resulting room \(trace.containingRoomSourceIndex)."
    }
}
