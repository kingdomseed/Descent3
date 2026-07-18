// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import MetalKit

@MainActor
final class RevivalEditorWindowController: NSWindowController, NSWindowDelegate {
    private enum CameraMotion: Int {
        case left = 1
        case right
        case forward
        case backward
        case lookLeft
        case lookRight
    }

    private unowned let projectDocument: RevivalProjectDocument
    private let renderer: MetalWorldRenderer?
    private let selectedRoomHeading: NSTextField
    private let roomPopup: NSPopUpButton
    private let facePopup: NSPopUpButton
    private let portalPopup: NSPopUpButton
    private let followPortalButton: NSButton
    private let roomNameField: NSTextField
    private let renameButton: NSButton
    private let playButton: NSButton
    private let cameraButtons: [NSButton]
    private let statusLabel: NSTextField
    private var rendererError: String?

    init(document: RevivalProjectDocument) {
        projectDocument = document

        let metalView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
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

        portalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        portalPopup.setAccessibilityLabel("Selected portal")
        portalPopup.setAccessibilityHelp(
            "Selects a portal and its owning face in the current source room."
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

        playButton = NSButton(title: "Play Disposable Copy", target: nil, action: nil)
        playButton.bezelStyle = .rounded
        playButton.setAccessibilityLabel("Play disposable copy")

        let cameraButtonDefinitions: [(String, CameraMotion)] = [
            ("Move Left", .left),
            ("Move Right", .right),
            ("Move Forward", .forward),
            ("Move Back", .backward),
            ("Look Left", .lookLeft),
            ("Look Right", .lookRight),
        ]
        cameraButtons = cameraButtonDefinitions.map { title, motion in
            let button = NSButton(title: title, target: nil, action: nil)
            button.tag = motion.rawValue
            button.setAccessibilityLabel(title)
            button.setAccessibilityHelp(
                "Moves the disposable play camera only when the canonical presentation closure remains complete."
            )
            return button
        }

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
        sidebar.addArrangedSubview(NSTextField(labelWithString: "Portal"))
        sidebar.addArrangedSubview(portalPopup)
        sidebar.addArrangedSubview(followPortalButton)
        sidebar.addArrangedSubview(roomNameField)
        sidebar.addArrangedSubview(renameButton)
        let editSeparator = NSBox()
        editSeparator.boxType = .separator
        sidebar.addArrangedSubview(editSeparator)
        sidebar.addArrangedSubview(playButton)

        let cameraHeading = NSTextField(labelWithString: "Play Camera")
        cameraHeading.font = .preferredFont(forTextStyle: .headline)
        sidebar.addArrangedSubview(cameraHeading)
        for button in cameraButtons {
            sidebar.addArrangedSubview(button)
        }
        let statusSeparator = NSBox()
        statusSeparator.boxType = .separator
        sidebar.addArrangedSubview(statusSeparator)
        sidebar.addArrangedSubview(statusLabel)

        root.addSubview(sidebar)
        root.addSubview(metalView)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 270),
            roomPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            facePopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            portalPopup.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            roomNameField.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),
            statusLabel.widthAnchor.constraint(equalTo: sidebar.widthAnchor, constant: -36),

            metalView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            metalView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            metalView.topAnchor.constraint(equalTo: root.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            metalView.widthAnchor.constraint(greaterThanOrEqualToConstant: 480),
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_070, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RevivalEditor"
        window.contentMinSize = NSSize(width: 750, height: 520)
        window.contentView = root

        super.init(window: window)

        window.delegate = self
        window.initialFirstResponder = roomNameField
        roomNameField.target = self
        roomNameField.action = #selector(commitRoomName(_:))
        renameButton.target = self
        renameButton.action = #selector(commitRoomName(_:))
        roomPopup.target = self
        roomPopup.action = #selector(selectRoom(_:))
        facePopup.target = self
        facePopup.action = #selector(selectFace(_:))
        portalPopup.target = self
        portalPopup.action = #selector(selectPortal(_:))
        followPortalButton.target = self
        followPortalButton.action = #selector(followPortal(_:))
        playButton.target = self
        playButton.action = #selector(togglePlay(_:))
        for button in cameraButtons {
            button.target = self
            button.action = #selector(movePlayCamera(_:))
        }

        refreshFromDocument()
        renderCurrentWorld()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func refreshFromDocument() {
        let selection = projectDocument.editorSelection
        let level = projectDocument.project.level
        let room = projectDocument.project.level.rooms.first {
            $0.sourceIndex == selection.room.sourceIndex
        }
        selectedRoomHeading.stringValue = "Selected Source Room \(selection.room.sourceIndex)"
        populateSelectionControls(level: level, selection: selection)
        roomNameField.stringValue = room?.name ?? ""

        let isPlaying = projectDocument.playSession != nil
        roomPopup.isEnabled = !isPlaying
        facePopup.isEnabled = !isPlaying
        portalPopup.isEnabled = !isPlaying && !(room?.portals.isEmpty ?? true)
        followPortalButton.isEnabled = !isPlaying && selection.portal != nil
        roomNameField.isEnabled = !isPlaying
        renameButton.isEnabled = !isPlaying
        playButton.title = isPlaying ? "Return to Editor" : "Play Disposable Copy"
        playButton.setAccessibilityLabel(playButton.title)
        for button in cameraButtons {
            button.isEnabled = isPlaying
        }

        if let rendererError {
            setStatus(rendererError, isError: true)
        } else if isPlaying {
            setStatus(
                "Playing a separately owned complete-level copy. Camera moves are accepted only while the imported presentation closure remains usable.",
                isError: false
            )
        } else {
            setStatus(
                "Editing \(level.metadata.name) — \(level.rooms.count) complete resident rooms — source room \(selection.room.sourceIndex), face \(selection.face.faceIndex) selected.",
                isError: false
            )
        }
    }

    func windowWillClose(_ notification: Notification) {
        renderer?.shutdown()
    }

    @objc private func commitRoomName(_ sender: Any?) {
        do {
            try projectDocument.renameSelectedRoom(to: roomNameField.stringValue)
            window?.makeFirstResponder(nil)
            roomNameField.stringValue = projectDocument.project.level.rooms.first {
                $0.sourceIndex == projectDocument.selectedRoomSourceIndex
            }?.name ?? ""
            setStatus(
                "Renamed source room \(projectDocument.selectedRoomSourceIndex). Undo action: Rename Room.",
                isError: false
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

    @objc private func selectPortal(_ sender: NSPopUpButton) {
        performSelectionChange {
            guard let portalIndex = sender.selectedItem?.representedObject as? Int else {
                return
            }
            try projectDocument.selectPortal(portalIndex)
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
                let candidate = try projectDocument.makePlaySession()
                try replaceRenderedWorld(
                    level: candidate.level,
                    camera: candidate.camera
                )
                projectDocument.commitPlaySession(candidate)
                setStatus("Playing a disposable complete-level copy.", isError: false)
            } else if let playSession = projectDocument.playSession {
                try replaceRenderedWorld(
                    level: projectDocument.project.level,
                    camera: playSession.camera
                )
                projectDocument.returnToEditor()
                window?.makeFirstResponder(roomNameField)
                setStatus("Returned to the unchanged editor document state.", isError: false)
            }
        } catch {
            setStatus(error.localizedDescription, isError: true)
            NSSound.beep()
        }
    }

    @objc private func movePlayCamera(_ sender: NSButton) {
        guard let motion = CameraMotion(rawValue: sender.tag),
              let session = projectDocument.playSession else {
            return
        }

        let proposedCamera = movedCamera(session.camera, motion: motion)
        do {
            let candidate = try projectDocument.makePlaySession(
                movingCameraTo: proposedCamera
            )
            try replaceRenderedWorld(
                level: candidate.level,
                camera: candidate.camera
            )
            projectDocument.commitPlaySession(candidate)
            setStatus("Moved the disposable play camera through the shared render path.", isError: false)
        } catch {
            setStatus(
                "That camera move left the imported presentation closure: \(error.localizedDescription)",
                isError: true
            )
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
        let level: Level
        let camera: RoomCamera
        if let session = projectDocument.playSession {
            level = session.level
            camera = session.camera
        } else {
            level = projectDocument.project.level
            camera = projectDocument.camera
        }

        try replaceRenderedWorld(level: level, camera: camera)
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

        portalPopup.removeAllItems()
        for portalIndex in room.portals.indices {
            portalPopup.addItem(withTitle: "Portal \(portalIndex)")
            portalPopup.lastItem?.representedObject = portalIndex
        }
        if let portal = selection.portal {
            portalPopup.selectItem(withTitle: "Portal \(portal.portalIndex)")
        } else {
            portalPopup.select(nil)
        }
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

    private func movedCamera(
        _ camera: RoomCamera,
        motion: CameraMotion
    ) -> RoomCamera {
        let moveX: Float
        let moveY: Float
        let lookX: Float
        switch motion {
        case .left:
            (moveX, moveY, lookX) = (-0.25, 0, 0)
        case .right:
            (moveX, moveY, lookX) = (0.25, 0, 0)
        case .forward:
            (moveX, moveY, lookX) = (0, 0.25, 0)
        case .backward:
            (moveX, moveY, lookX) = (0, -0.25, 0)
        case .lookLeft:
            (moveX, moveY, lookX) = (0, 0, -0.25)
        case .lookRight:
            (moveX, moveY, lookX) = (0, 0, 0.25)
        }

        return RoomCamera(
            position: .init(
                x: camera.position.x + moveX,
                y: camera.position.y + moveY,
                z: camera.position.z
            ),
            target: .init(
                x: camera.target.x + moveX + lookX,
                y: camera.target.y + moveY,
                z: camera.target.z
            ),
            up: camera.up,
            projection: camera.projection
        )
    }
}
