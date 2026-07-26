// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Synchronization

enum RevivalEditorOpenKind: Equatable {
    case project
    case canonicalContent
}

func revivalEditorOpenKind(for url: URL) -> RevivalEditorOpenKind {
    url.pathExtension.caseInsensitiveCompare("revivalproject") == .orderedSame
        ? .project
        : .canonicalContent
}

enum RevivalProjectDocumentError: Error, Equatable, LocalizedError {
    case unsupportedType(String)
    case projectNotLoaded
    case unexpectedPackageContents
    case projectFileTooLarge
    case playNotActive
    case cameraOutsideRoom(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedType(type):
            "The document type ‘\(type)’ is not a Revival authoring project."
        case .projectNotLoaded:
            "The Revival project has not finished loading."
        case .unexpectedPackageContents:
            "A Revival project package must contain exactly one regular project.json file."
        case .projectFileTooLarge:
            "project.json exceeds the 64 MiB Revival project limit."
        case .playNotActive:
            "Start a disposable play session before moving its camera."
        case let .cameraOutsideRoom(sourceIndex):
            "The free camera must remain inside source room \(sourceIndex) for this presentation slice."
        }
    }
}

@objc(RevivalProjectDocument)
@MainActor
final class RevivalProjectDocument: NSDocument {
    nonisolated static let projectType = "org.descent3.revival.project"
    private nonisolated static let projectMemberName = "project.json"
    private nonisolated static let maximumProjectJSONBytes = 64 * 1_024 * 1_024

    private nonisolated let projectStorage = Mutex<RevivalProject?>(nil)
    private nonisolated let library: CanonicalPackageLibrary
    private var selection: RevivalEditorSelection?
    let cameraContainingRoomSourceIndex = 3
    private(set) var camera = RoomCamera.trainingRoom3
    private(set) var playSession: RevivalPlaySession?

    override init() {
        library = .revivalEditor
        super.init()
        hasUndoManager = true
    }

    init(
        project: RevivalProject,
        library: CanonicalPackageLibrary = .revivalEditor
    ) {
        self.library = library
        super.init()
        projectStorage.withLock { $0 = project }
        fileType = Self.projectType
        hasUndoManager = true
    }

    override func makeWindowControllers() {
        addWindowController(RevivalEditorWindowController(document: self))
    }

    override nonisolated func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        guard typeName == Self.projectType else {
            throw RevivalProjectDocumentError.unsupportedType(typeName)
        }
        guard let project = projectStorage.withLock({ $0 }) else {
            throw RevivalProjectDocumentError.projectNotLoaded
        }
        try project.validate()

        let json = try canonicalJSONData(project.persistedSource)
        guard json.count <= Self.maximumProjectJSONBytes else {
            throw RevivalProjectDocumentError.projectFileTooLarge
        }
        let projectFile = FileWrapper(regularFileWithContents: json)
        projectFile.preferredFilename = Self.projectMemberName
        return FileWrapper(directoryWithFileWrappers: [Self.projectMemberName: projectFile])
    }

    override nonisolated func read(
        from url: URL,
        ofType typeName: String
    ) throws {
        guard typeName == Self.projectType else {
            throw RevivalProjectDocumentError.unsupportedType(typeName)
        }
        let packageValues = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard packageValues.isDirectory == true,
              packageValues.isSymbolicLink != true else {
            throw RevivalProjectDocumentError.unexpectedPackageContents
        }
        let members = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
            ]
        )
        guard members.count == 1,
              let projectURL = members.first,
              projectURL.lastPathComponent == Self.projectMemberName else {
            throw RevivalProjectDocumentError.unexpectedPackageContents
        }
        let projectValues = try projectURL.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        )
        guard projectValues.isRegularFile == true,
              projectValues.isSymbolicLink != true,
              let projectFileSize = projectValues.fileSize else {
            throw RevivalProjectDocumentError.unexpectedPackageContents
        }
        guard projectFileSize <= Self.maximumProjectJSONBytes else {
            throw RevivalProjectDocumentError.projectFileTooLarge
        }

        let handle = try FileHandle(forReadingFrom: projectURL)
        let json = try handle.read(
            upToCount: Self.maximumProjectJSONBytes + 1
        ) ?? Data()
        try handle.close()
        try readProjectJSON(json)
    }

    override nonisolated func read(
        from fileWrapper: FileWrapper,
        ofType typeName: String
    ) throws {
        guard typeName == Self.projectType else {
            throw RevivalProjectDocumentError.unsupportedType(typeName)
        }
        guard fileWrapper.isDirectory,
              let children = fileWrapper.fileWrappers,
              children.count == 1,
              let projectFile = children[Self.projectMemberName],
              projectFile.isRegularFile,
              let json = projectFile.regularFileContents else {
            throw RevivalProjectDocumentError.unexpectedPackageContents
        }
        guard json.count <= Self.maximumProjectJSONBytes else {
            throw RevivalProjectDocumentError.projectFileTooLarge
        }
        try readProjectJSON(json)
    }

    private nonisolated func readProjectJSON(_ json: Data) throws {
        guard json.count <= Self.maximumProjectJSONBytes else {
            throw RevivalProjectDocumentError.projectFileTooLarge
        }
        let source = try JSONDecoder().decode(RevivalProjectSource.self, from: json)
        let project = try RevivalProject(source: source, library: library)
        projectStorage.withLock { $0 = project }
    }

    var project: RevivalProject {
        guard let project = projectStorage.withLock({ $0 }) else {
            preconditionFailure("Revival project accessed before loading")
        }
        return project
    }

    var editorSelection: RevivalEditorSelection {
        if let selection {
            return selection
        }
        do {
            let initialSelection = try RevivalEditorSelection(
                roomSourceIndex: 3,
                in: project.level
            )
            selection = initialSelection
            return initialSelection
        } catch {
            preconditionFailure("The canonical Training level must contain source room 3 face 0: \(error)")
        }
    }

    var selectedRoomSourceIndex: Int {
        editorSelection.room.sourceIndex
    }

    func selectRoom(sourceIndex: Int) throws {
        var candidate = editorSelection
        try candidate.selectRoom(sourceIndex: sourceIndex, in: project.level)
        selection = candidate
        refreshWindowControllers()
    }

    func selectFace(_ faceIndex: Int) throws {
        var candidate = editorSelection
        try candidate.selectFace(faceIndex, in: project.level)
        selection = candidate
        refreshWindowControllers()
    }

    func selectPortal(_ portalIndex: Int) throws {
        var candidate = editorSelection
        try candidate.selectPortal(portalIndex, in: project.level)
        selection = candidate
        refreshWindowControllers()
    }

    func followSelectedPortal() {
        var candidate = editorSelection
        candidate.followSelectedPortal(in: project.level)
        selection = candidate
        refreshWindowControllers()
    }

    func renameSelectedRoom(to proposedName: String) throws {
        let sourceIndex = editorSelection.room.sourceIndex
        var previousName: String?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previousName = try project.renameRoom(
                sourceIndex: sourceIndex,
                to: proposedName
            )
            storedProject = project
        }

        registerRoomNameUndo(
            sourceIndex: sourceIndex,
            name: previousName
        )
        undoManager?.setActionName("Rename Room")
        refreshWindowControllers()
    }

    func setSelectedFaceMaterial(to texture: SourceResource) throws {
        let selection = editorSelection.face
        var previous: SourceResource?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous = try project.setFaceMaterial(
                roomSourceIndex: selection.roomSourceIndex,
                faceIndex: selection.faceIndex,
                to: texture
            )
            storedProject = project
        }
        registerFaceMaterialUndo(selection: selection, texture: previous!)
        undoManager?.setActionName("Set Face Material")
        refreshWindowControllers()
    }

    func setSelectedPortalRendersFaces(_ rendersFace: Bool) throws {
        guard let selection = editorSelection.portal else {
            preconditionFailure("A portal must be selected before editing its rendering state")
        }
        if project.isTrainingGuidebotReturnBarrierPortal(
            roomSourceIndex: selection.roomSourceIndex,
            portalIndex: selection.portalIndex
        ) {
            try setTrainingGuidebotReturnBarrierOpen(!rendersFace)
            return
        }
        if project.isTrainingGalleryBarrierPortal(
            roomSourceIndex: selection.roomSourceIndex,
            portalIndex: selection.portalIndex
        ) {
            try setTrainingGalleryBarrierOpen(!rendersFace)
            return
        }
        var previous = false
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous = try project.setPortalRendersFace(
                roomSourceIndex: selection.roomSourceIndex,
                portalIndex: selection.portalIndex,
                to: rendersFace
            )
            storedProject = project
        }
        registerPortalRenderingUndo(selection: selection, rendersFace: previous)
        undoManager?.setActionName("Set Portal Rendering")
        refreshWindowControllers()
    }

    func setTrainingGalleryBarrierOpen(_ isOpen: Bool) throws {
        var previous = false
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous = try project.setTrainingGalleryBarrierOpen(isOpen)
            storedProject = project
        }
        registerTrainingGalleryBarrierUndo(isOpen: previous)
        undoManager?.setActionName("Set Training Gallery Barrier")
        refreshWindowControllers()
    }

    func setTrainingGuidebotReturnBarrierOpen(_ isOpen: Bool) throws {
        var previous = false
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous =
                try project.setTrainingGuidebotReturnBarrierOpen(isOpen)
            storedProject = project
        }
        registerTrainingGuidebotReturnBarrierUndo(isOpen: previous)
        undoManager?.setActionName(
            project.level.trainingCameraMonitorChain?.returnToShip?
                .killbotEntry == nil
                ? "Set Training Guidebot Return Barrier"
                : "Set Training Killbot Entry Barrier"
        )
        refreshWindowControllers()
    }

    func setRoomVertex(
        roomSourceIndex: Int,
        vertexIndex: Int,
        to position: Vector3
    ) throws {
        try applyRoomVertex(
            roomSourceIndex: roomSourceIndex,
            vertexIndex: vertexIndex,
            to: position,
            actionName: "Set Room Vertex"
        )
    }

    func snapRoomVertex(
        roomSourceIndex: Int,
        vertexIndex: Int,
        toRoomSourceIndex: Int,
        toVertexIndex: Int
    ) throws {
        guard let targetRoom = project.level.rooms.first(where: {
            $0.sourceIndex == toRoomSourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(toRoomSourceIndex)
        }
        guard targetRoom.vertices.indices.contains(toVertexIndex) else {
            throw RevivalProjectError.vertexMissing(
                roomSourceIndex: toRoomSourceIndex,
                vertexIndex: toVertexIndex
            )
        }
        try applyRoomVertex(
            roomSourceIndex: roomSourceIndex,
            vertexIndex: vertexIndex,
            to: targetRoom.vertices[toVertexIndex],
            actionName: "Snap Room Vertex"
        )
    }

    func setObjectTransform(
        handle: UInt32,
        to transform: RevivalRigidTransform
    ) throws {
        var previous: RevivalRigidTransform?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous = try project.setObjectTransform(handle: handle, to: transform)
            storedProject = project
        }
        registerObjectTransformUndo(handle: handle, transform: previous!)
        undoManager?.setActionName("Transform Object")
        refreshWindowControllers()
    }

    func rotateObjectQuarterTurn(handle: UInt32) throws {
        var previous: RevivalRigidTransform?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous = try project.rotateObjectQuarterTurn(handle: handle)
            storedProject = project
        }
        registerObjectTransformUndo(handle: handle, transform: previous!)
        undoManager?.setActionName("Transform Object")
        refreshWindowControllers()
    }

    func setPlayerStartTransform(
        playerID: Int,
        handle: UInt32,
        to transform: RevivalRigidTransform
    ) throws {
        var previous: RevivalRigidTransform?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous = try project.setPlayerStartTransform(
                playerID: playerID,
                handle: handle,
                to: transform
            )
            storedProject = project
        }
        registerPlayerStartTransformUndo(
            playerID: playerID,
            handle: handle,
            transform: previous!
        )
        undoManager?.setActionName("Transform Player Start")
        refreshWindowControllers()
    }

    func rotatePlayerStartQuarterTurn(handle: UInt32) throws {
        var playerID: Int?
        var previous: RevivalRigidTransform?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            guard let playerStart = project.level.objects.first(where: {
                $0.handle == handle && $0.type == D3SourceIdentity.playerObjectType
            }) else {
                throw RevivalProjectError.objectMissing(handle)
            }
            playerID = playerStart.storedID
            previous = try project.rotatePlayerStartQuarterTurn(
                playerID: playerStart.storedID,
                handle: handle
            )
            storedProject = project
        }
        registerPlayerStartTransformUndo(
            playerID: playerID!,
            handle: handle,
            transform: previous!
        )
        undoManager?.setActionName("Transform Player Start")
        refreshWindowControllers()
    }

    @discardableResult
    func moveObject(
        handle: UInt32,
        to position: Vector3
    ) throws -> RevivalPlacementResult {
        let previous = try project.level.objects.first {
            $0.handle == handle
        }.map(\.position) ?? { throw RevivalProjectError.objectMissing(handle) }()
        var result: RevivalPlacementResult?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            result = try project.moveObject(handle: handle, to: position)
            storedProject = project
        }
        registerObjectPlacementUndo(handle: handle, position: previous)
        undoManager?.setActionName("Move Object")
        refreshWindowControllers()
        return result!
    }

    @discardableResult
    func movePlayerStart(
        playerID: Int,
        handle: UInt32,
        to position: Vector3
    ) throws -> RevivalPlacementResult {
        let previous = try project.level.objects.first {
            $0.handle == handle
        }.map(\.position) ?? {
            throw RevivalProjectError.playerStartMissing(
                playerID: playerID,
                handle: handle
            )
        }()
        var result: RevivalPlacementResult?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            result = try project.movePlayerStart(
                playerID: playerID,
                handle: handle,
                to: position
            )
            storedProject = project
        }
        registerPlayerStartPlacementUndo(
            playerID: playerID,
            handle: handle,
            position: previous
        )
        undoManager?.setActionName("Move Player Start")
        refreshWindowControllers()
        return result!
    }

    func makePlaySession() -> RevivalPlaySession {
        project.makePlayerPlaySession()
    }

    func makePlaySession(
        movingCameraTo proposedCamera: RoomCamera
    ) throws -> RevivalPlaySession {
        guard var session = playSession else {
            throw RevivalProjectDocumentError.playNotActive
        }
        try validateCameraRoom(proposedCamera, session: session)
        session.camera = proposedCamera
        return session
    }

    func commitPlaySession(
        _ session: RevivalPlaySession,
        renderingWorld: Bool = true
    ) {
        playSession = session
        refreshWindowControllers(renderWorld: renderingWorld)
    }

    func tracePlayIndoorMovement(
        startRoom: Int,
        start: Vector3,
        end: Vector3,
        radius: Float
    ) throws -> IndoorMovementTrace {
        guard let playSession else {
            throw RevivalProjectDocumentError.playNotActive
        }
        return traceIndoorMovement(
            in: playSession.level,
            startRoom: startRoom,
            start: start,
            end: end,
            radius: radius
        )
    }

    func traceSelectedPlayPortal(radius: Float) throws -> IndoorMovementTrace {
        guard let playSession else {
            throw RevivalProjectDocumentError.playNotActive
        }
        let selection = editorSelection.portal!
        let room = playSession.level.rooms.first {
            $0.sourceIndex == selection.roomSourceIndex
        }!
        let face = room.faces[room.portals[selection.portalIndex].faceIndex]
        let points = face.corners.map { room.vertices[$0.vertexIndex] }
        let sum = points.reduce(Vector3.zero) {
            .init(x: $0.x + $1.x, y: $0.y + $1.y, z: $0.z + $1.z)
        }
        let center = Vector3(
            x: sum.x / Float(points.count),
            y: sum.y / Float(points.count),
            z: sum.z / Float(points.count)
        )
        let normal = canonicalFaceNormal(room: room, face: face)!
        let probeDistance = radius + 0.5
        let start = Vector3(
            x: center.x + normal.x * probeDistance,
            y: center.y + normal.y * probeDistance,
            z: center.z + normal.z * probeDistance
        )
        let end = Vector3(
            x: center.x - normal.x * probeDistance,
            y: center.y - normal.y * probeDistance,
            z: center.z - normal.z * probeDistance
        )
        return traceIndoorMovement(
            in: playSession.level,
            startRoom: selection.roomSourceIndex,
            start: start,
            end: end,
            radius: radius
        )
    }

    private func validateCameraRoom(
        _ proposedCamera: RoomCamera,
        session: RevivalPlaySession
    ) throws {
        let room = session.level.rooms.first {
            $0.sourceIndex == session.cameraContainingRoomSourceIndex
        }!
        guard sourceConvexRoomContains(proposedCamera.position, in: room) else {
            throw RevivalProjectDocumentError.cameraOutsideRoom(
                session.cameraContainingRoomSourceIndex
            )
        }
    }

    func returnToEditor(renderingWorld: Bool = true) {
        guard playSession != nil else {
            preconditionFailure("A play session must be active before returning to the editor")
        }
        playSession = nil
        refreshWindowControllers(renderWorld: renderingWorld)
    }

    private func restoreRoomName(
        sourceIndex: Int,
        to name: String?
    ) throws {
        var previousName: String?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previousName = try project.restoreRoomName(sourceIndex: sourceIndex, to: name)
            storedProject = project
        }

        registerRoomNameUndo(sourceIndex: sourceIndex, name: previousName)
        undoManager?.setActionName("Rename Room")
        refreshWindowControllers()
    }

    private func registerRoomNameUndo(
        sourceIndex: Int,
        name: String?
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.restoreRoomName(sourceIndex: sourceIndex, to: name)
            } catch {
                preconditionFailure("Room-name undo invariant failed: \(error)")
            }
        }
    }

    private func registerFaceMaterialUndo(
        selection: RevivalFaceSelection,
        texture: SourceResource
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.selectRoom(sourceIndex: selection.roomSourceIndex)
                try document.selectFace(selection.faceIndex)
                try document.setSelectedFaceMaterial(to: texture)
            } catch {
                preconditionFailure("Face-material undo invariant failed: \(error)")
            }
        }
    }

    private func registerPortalRenderingUndo(
        selection: RevivalPortalSelection,
        rendersFace: Bool
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.selectRoom(sourceIndex: selection.roomSourceIndex)
                try document.selectPortal(selection.portalIndex)
                try document.setSelectedPortalRendersFaces(rendersFace)
            } catch {
                preconditionFailure("Portal-rendering undo invariant failed: \(error)")
            }
        }
    }

    private func registerTrainingGalleryBarrierUndo(isOpen: Bool) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.setTrainingGalleryBarrierOpen(isOpen)
            } catch {
                preconditionFailure(
                    "Training-gallery barrier undo invariant failed: \(error)"
                )
            }
        }
    }

    private func registerTrainingGuidebotReturnBarrierUndo(
        isOpen: Bool
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document
                    .setTrainingGuidebotReturnBarrierOpen(isOpen)
            } catch {
                preconditionFailure(
                    "Training Guidebot return-barrier undo invariant failed: \(error)"
                )
            }
        }
    }

    private func applyRoomVertex(
        roomSourceIndex: Int,
        vertexIndex: Int,
        to position: Vector3,
        actionName: String
    ) throws {
        var previous: Vector3?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previous = try project.setRoomVertex(
                roomSourceIndex: roomSourceIndex,
                vertexIndex: vertexIndex,
                to: position
            )
            storedProject = project
        }
        registerRoomVertexUndo(
            roomSourceIndex: roomSourceIndex,
            vertexIndex: vertexIndex,
            position: previous!,
            actionName: actionName
        )
        undoManager?.setActionName(actionName)
        refreshWindowControllers()
    }

    private func registerRoomVertexUndo(
        roomSourceIndex: Int,
        vertexIndex: Int,
        position: Vector3,
        actionName: String
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.applyRoomVertex(
                    roomSourceIndex: roomSourceIndex,
                    vertexIndex: vertexIndex,
                    to: position,
                    actionName: actionName
                )
            } catch {
                preconditionFailure("Room-vertex undo invariant failed: \(error)")
            }
        }
    }

    private func registerObjectTransformUndo(
        handle: UInt32,
        transform: RevivalRigidTransform
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.setObjectTransform(handle: handle, to: transform)
            } catch {
                preconditionFailure("Object-transform undo invariant failed: \(error)")
            }
        }
    }

    private func registerPlayerStartTransformUndo(
        playerID: Int,
        handle: UInt32,
        transform: RevivalRigidTransform
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.setPlayerStartTransform(
                    playerID: playerID,
                    handle: handle,
                    to: transform
                )
            } catch {
                preconditionFailure("Player-start transform undo invariant failed: \(error)")
            }
        }
    }

    private func registerObjectPlacementUndo(handle: UInt32, position: Vector3) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.moveObject(handle: handle, to: position)
            } catch {
                preconditionFailure("Object-placement undo invariant failed: \(error)")
            }
        }
    }

    private func registerPlayerStartPlacementUndo(
        playerID: Int,
        handle: UInt32,
        position: Vector3
    ) {
        undoManager?.registerUndo(withTarget: self) { document in
            do {
                try document.movePlayerStart(
                    playerID: playerID,
                    handle: handle,
                    to: position
                )
            } catch {
                preconditionFailure("Player-start placement undo invariant failed: \(error)")
            }
        }
    }

    private func refreshWindowControllers(renderWorld: Bool = true) {
        for case let controller as RevivalEditorWindowController in windowControllers {
            controller.refreshFromDocument(renderWorld: renderWorld)
        }
    }
}
