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
    private(set) var selectedRoomSourceIndex = 3
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

    func renameSelectedRoom(to proposedName: String) throws {
        var previousName: String?
        try projectStorage.withLock { storedProject in
            guard var project = storedProject else {
                throw RevivalProjectDocumentError.projectNotLoaded
            }
            previousName = try project.renameRoom(
                sourceIndex: selectedRoomSourceIndex,
                to: proposedName
            )
            storedProject = project
        }

        registerRoomNameUndo(
            sourceIndex: selectedRoomSourceIndex,
            name: previousName
        )
        undoManager?.setActionName("Rename Room")
        refreshWindowControllers()
    }

    func makePlaySession() throws -> RevivalPlaySession {
        let session = try project.makePlaySession(
            selectedRoomSourceIndex: selectedRoomSourceIndex,
            camera: camera
        )
        try validateCameraRoom(session.camera, session: session)
        return session
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

    func commitPlaySession(_ session: RevivalPlaySession) {
        precondition(
            session.selectedRoomSourceIndex == selectedRoomSourceIndex,
            "A staged play session must match the document selection"
        )
        playSession = session
        refreshWindowControllers()
    }

    private func validateCameraRoom(
        _ proposedCamera: RoomCamera,
        session: RevivalPlaySession
    ) throws {
        guard let room = session.level.rooms.first(where: {
            $0.sourceIndex == session.selectedRoomSourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(session.selectedRoomSourceIndex)
        }
        guard sourceRoomThreeContains(proposedCamera.position, in: room) else {
            throw RevivalProjectDocumentError.cameraOutsideRoom(
                session.selectedRoomSourceIndex
            )
        }
    }

    func returnToEditor() {
        playSession = nil
        refreshWindowControllers()
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

    private func refreshWindowControllers() {
        for case let controller as RevivalEditorWindowController in windowControllers {
            controller.refreshFromDocument()
        }
    }
}
