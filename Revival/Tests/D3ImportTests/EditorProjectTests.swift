import AppKit
import XCTest

final class EditorProjectTests: XCTestCase {
    func testEditorSelectionValidatesRoomFaceAndPortalAgainstCanonicalLevel() throws {
        let level = makeConnectedRoomProjectLevel()

        XCTAssertEqual(
            try RevivalRoomSelection(sourceIndex: 3, in: level).sourceIndex,
            3
        )
        let face = try RevivalFaceSelection(
            roomSourceIndex: 3,
            faceIndex: 0,
            in: level
        )
        XCTAssertEqual(face.roomSourceIndex, 3)
        XCTAssertEqual(face.faceIndex, 0)
        let portal = try RevivalPortalSelection(
            roomSourceIndex: 3,
            portalIndex: 0,
            in: level
        )
        XCTAssertEqual(portal.roomSourceIndex, 3)
        XCTAssertEqual(portal.portalIndex, 0)

        XCTAssertThrowsError(try RevivalRoomSelection(sourceIndex: 99, in: level)) {
            XCTAssertEqual($0 as? RevivalEditorSelectionError, .roomMissing(99))
        }
        XCTAssertThrowsError(
            try RevivalFaceSelection(roomSourceIndex: 3, faceIndex: 99, in: level)
        ) {
            XCTAssertEqual(
                $0 as? RevivalEditorSelectionError,
                .faceMissing(roomSourceIndex: 3, faceIndex: 99)
            )
        }
        XCTAssertThrowsError(
            try RevivalPortalSelection(roomSourceIndex: 3, portalIndex: 99, in: level)
        ) {
            XCTAssertEqual(
                $0 as? RevivalEditorSelectionError,
                .portalMissing(roomSourceIndex: 3, portalIndex: 99)
            )
        }
    }

    func testEditorSelectionFollowsReciprocalPortalReferences() throws {
        let level = makeConnectedRoomProjectLevel()
        var selection = try RevivalEditorSelection(
            roomSourceIndex: 3,
            in: level
        )

        try selection.selectPortal(0, in: level)
        selection.followSelectedPortal(in: level)
        XCTAssertEqual(selection.room.sourceIndex, 2)
        XCTAssertEqual(selection.face.faceIndex, 1)
        XCTAssertEqual(selection.portal?.portalIndex, 1)

        try selection.selectPortal(0, in: level)
        selection.followSelectedPortal(in: level)
        XCTAssertEqual(selection.room.sourceIndex, 1)
        XCTAssertEqual(selection.face.faceIndex, 0)
        XCTAssertEqual(selection.portal?.portalIndex, 0)

        selection.followSelectedPortal(in: level)
        XCTAssertEqual(selection.room.sourceIndex, 2)
        XCTAssertEqual(selection.portal?.portalIndex, 0)
        try selection.selectPortal(1, in: level)
        selection.followSelectedPortal(in: level)
        XCTAssertEqual(selection.room.sourceIndex, 3)
        XCTAssertEqual(selection.portal?.portalIndex, 0)
    }

    @MainActor
    func testProjectPersistsOnlyAnInstalledBaseReferenceAndRoomNameDelta() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try document.renameSelectedRoom(to: "Course Start")

        let wrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let json = try XCTUnwrap(
            wrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: json) as? [String: Any]
        )
        XCTAssertEqual(Set(object.keys), ["base", "roomNameEdits", "schemaVersion"])
        XCTAssertNil(object["level"])
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("presentationMaterials"))

        try FileManager.default.removeItem(at: candidate)
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(from: wrapper, ofType: RevivalProjectDocument.projectType)

        XCTAssertEqual(reopened.project, document.project)
        XCTAssertEqual(reopened.project.baseReference, activation.reference)
        XCTAssertEqual(
            reopened.project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "Course Start"
        )
        XCTAssertNil(activation.level.rooms.first { $0.sourceIndex == 3 }?.name)
        XCTAssertEqual(try library.load(activation.reference), activation.level)
    }

    @MainActor
    func testProjectRoundTripCanClearANameOwnedByTheInstalledBase() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        var base = makeMinimalCanonicalPackageLevel()
        let roomIndex = try XCTUnwrap(base.rooms.firstIndex { $0.sourceIndex == 3 })
        base.rooms[roomIndex].name = "Training Start"
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )

        try document.renameSelectedRoom(to: " \n\t ")
        let wrapper = try document.fileWrapper(ofType: RevivalProjectDocument.projectType)
        let projectJSON = try XCTUnwrap(
            wrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        let source = try JSONDecoder().decode(RevivalProjectSource.self, from: projectJSON)
        XCTAssertEqual(
            source.roomNameEdits,
            [.init(sourceIndex: 3, name: nil)]
        )

        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(from: wrapper, ofType: RevivalProjectDocument.projectType)

        XCTAssertNil(reopened.project.level.rooms.first { $0.sourceIndex == 3 }?.name)
        XCTAssertEqual(
            try library.load(activation.reference).rooms.first { $0.sourceIndex == 3 }?.name,
            "Training Start"
        )
    }

    func testRoutesMalformedProjectPackagesToTheProjectDocumentBoundary() {
        XCTAssertEqual(
            revivalEditorOpenKind(
                for: URL(fileURLWithPath: "/tmp/Malformed.revivalproject")
            ),
            .project
        )
        XCTAssertEqual(
            revivalEditorOpenKind(
                for: URL(fileURLWithPath: "/tmp/Training.revival")
            ),
            .canonicalContent
        )
    }

    func testRenameEditsTheCompleteProjectWithoutChangingImportedBase() throws {
        let importedBase = makeMinimalCanonicalPackageLevel()
        var project = try makeProject(importedBase: importedBase)

        let previousName = try project.renameRoom(
            sourceIndex: 3,
            to: "Course Start"
        )

        XCTAssertNil(previousName)
        XCTAssertNil(importedBase.rooms.first { $0.sourceIndex == 3 }?.name)
        XCTAssertEqual(
            project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "Course Start"
        )
        XCTAssertEqual(
            project.level.presentationCoronaAssets,
            importedBase.presentationCoronaAssets
        )
        XCTAssertEqual(project.level.rooms.count, importedBase.rooms.count)
        try project.validate()
    }

    func testRenameRejectsCaseInsensitiveDuplicateWithoutChangingProject() throws {
        var project = try makeProject(importedBase: makeMinimalCanonicalPackageLevel())

        try project.renameRoom(sourceIndex: 2, to: "Control Room")
        let beforeDuplicate = project
        XCTAssertThrowsError(try project.renameRoom(sourceIndex: 3, to: "  control room  ")) {
            XCTAssertEqual($0 as? RevivalProjectError, .duplicateRoomName("control room"))
        }
        XCTAssertEqual(project, beforeDuplicate)
    }

    func testRenameWhitespaceClearsAnExistingSourceRoomName() throws {
        var project = try makeProject(importedBase: makeMinimalCanonicalPackageLevel())
        try project.renameRoom(sourceIndex: 3, to: "Course Start")

        let previousName = try project.renameRoom(sourceIndex: 3, to: " \n\t ")

        XCTAssertEqual(previousName, "Course Start")
        XCTAssertNil(project.level.rooms.first { $0.sourceIndex == 3 }?.name)
        try project.validate()
    }

    func testRenameRejectsNamesBeyondTheSourceBoundWithoutChangingProject() throws {
        var project = try makeProject(importedBase: makeMinimalCanonicalPackageLevel())
        let before = project

        XCTAssertThrowsError(
            try project.renameRoom(sourceIndex: 3, to: String(repeating: "x", count: 20))
        ) {
            XCTAssertEqual($0 as? RevivalProjectError, .roomNameTooLong)
        }
        XCTAssertEqual(project, before)
    }

    func testProjectBoundaryErrorsProvideActionableDiagnostics() {
        XCTAssertEqual(
            RevivalProjectError.duplicateRoomName("control room").errorDescription,
            "A room named ‘control room’ already exists. Room names are compared without case."
        )
        XCTAssertEqual(
            RevivalProjectError.roomNameTooLong.errorDescription,
            "Room names must use at most 19 UTF-8 bytes."
        )
        XCTAssertEqual(
            RevivalProjectDocumentError.unexpectedPackageContents.errorDescription,
            "A Revival project package must contain exactly one regular project.json file."
        )
    }

    @MainActor
    func testProjectURLReadRejectsAnOversizedMemberWithoutReplacingTheProject() throws {
        let projectPackage = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).revivalproject", directoryHint: .isDirectory)
        let projectJSON = projectPackage.appending(path: "project.json")
        let original = try makeProject(importedBase: makeMinimalCanonicalPackageLevel())
        let document = RevivalProjectDocument(project: original)
        defer { try? FileManager.default.removeItem(at: projectPackage) }

        try FileManager.default.createDirectory(
            at: projectPackage,
            withIntermediateDirectories: false
        )
        XCTAssertTrue(FileManager.default.createFile(atPath: projectJSON.path, contents: nil))
        let handle = try FileHandle(forWritingTo: projectJSON)
        try handle.truncate(atOffset: UInt64(64 * 1_024 * 1_024 + 1))
        try handle.close()

        XCTAssertThrowsError(
            try document.read(
                from: projectPackage,
                ofType: RevivalProjectDocument.projectType
            )
        ) {
            XCTAssertEqual(
                $0 as? RevivalProjectDocumentError,
                .projectFileTooLarge
            )
        }
        XCTAssertEqual(document.project, original)
    }

    @MainActor
    func testRenameSelectedRoomRegistersNamedUndoAndRedo() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeMinimalCanonicalPackageLevel())
        )

        try document.renameSelectedRoom(to: "Course Start")
        XCTAssertEqual(document.project.level.rooms.first { $0.sourceIndex == 3 }?.name, "Course Start")
        XCTAssertEqual(document.undoManager?.undoActionName, "Rename Room")

        document.undoManager?.undo()
        XCTAssertNil(document.project.level.rooms.first { $0.sourceIndex == 3 }?.name)
        XCTAssertEqual(document.undoManager?.redoActionName, "Rename Room")

        document.undoManager?.redo()
        XCTAssertEqual(document.project.level.rooms.first { $0.sourceIndex == 3 }?.name, "Course Start")
    }

    @MainActor
    func testNonRoomThreeRenameUndoAndProjectReopenPreserveImmutableBase() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        let importedBase = makeConnectedRoomProjectLevel()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(importedBase, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )

        try document.selectRoom(sourceIndex: 1)
        try document.renameSelectedRoom(to: "Generator Annex")
        XCTAssertEqual(document.editorSelection.room.sourceIndex, 1)
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 1 }?.name,
            "Generator Annex"
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Rename Room")
        document.undoManager?.undo()
        XCTAssertNil(document.project.level.rooms.first { $0.sourceIndex == 1 }?.name)
        XCTAssertEqual(document.undoManager?.redoActionName, "Rename Room")
        document.undoManager?.redo()

        let wrapper = try document.fileWrapper(ofType: RevivalProjectDocument.projectType)
        let json = try XCTUnwrap(
            wrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        let source = try JSONDecoder().decode(RevivalProjectSource.self, from: json)
        XCTAssertEqual(
            source.roomNameEdits,
            [.init(sourceIndex: 1, name: "Generator Annex")]
        )

        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(from: wrapper, ofType: RevivalProjectDocument.projectType)
        XCTAssertEqual(reopened.editorSelection.room.sourceIndex, 3)
        XCTAssertEqual(
            reopened.project.level.rooms.first { $0.sourceIndex == 1 }?.name,
            "Generator Annex"
        )
        XCTAssertNil(importedBase.rooms.first { $0.sourceIndex == 1 }?.name)
        XCTAssertNil(
            try library.load(activation.reference).rooms.first {
                $0.sourceIndex == 1
            }?.name
        )
    }

    @MainActor
    func testCaseOnlyRenameSupportsUndoRedoAndProjectRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false
        document.undoManager?.beginUndoGrouping()
        try document.renameSelectedRoom(to: "Course Start")
        document.undoManager?.endUndoGrouping()

        document.undoManager?.beginUndoGrouping()
        try document.renameSelectedRoom(to: "course start")
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "course start"
        )

        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "Course Start"
        )
        document.undoManager?.redo()
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "course start"
        )

        let wrapper = try document.fileWrapper(ofType: RevivalProjectDocument.projectType)
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(from: wrapper, ofType: RevivalProjectDocument.projectType)
        XCTAssertEqual(
            reopened.project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "course start"
        )
    }

    @MainActor
    func testProjectWrapperIsDeterministicAndRestoresDefaultViewState() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try document.renameSelectedRoom(to: "Course Start")

        let firstWrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let firstJSON = try XCTUnwrap(
            firstWrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        let secondWrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let secondJSON = try XCTUnwrap(
            secondWrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        XCTAssertEqual(secondJSON, firstJSON)

        let expectedProject = document.project
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: firstWrapper,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(reopened.project, expectedProject)
        XCTAssertEqual(reopened.selectedRoomSourceIndex, 3)
        XCTAssertEqual(reopened.camera, .trainingRoom3)
        try reopened.project.validate()
    }

    @MainActor
    func testProjectReadRejectsInvalidRoomNamesWithoutReplacingLoadedProject() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = temporaryRoot.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: temporaryRoot.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(makeMinimalCanonicalPackageLevel(), to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let original = try RevivalProject(activatedBase: activation)
        let document = RevivalProjectDocument(project: original, library: library)
        let encoded = try canonicalJSONData(original.persistedSource)
        var root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        root["roomNameEdits"] = [
            ["sourceIndex": 2, "name": "Control Room"],
            ["sourceIndex": 3, "name": "control room"],
        ]
        let hostileJSON = try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys]
        )
        let hostileWrapper = FileWrapper(directoryWithFileWrappers: [
            "project.json": FileWrapper(regularFileWithContents: hostileJSON),
        ])

        XCTAssertThrowsError(
            try document.read(
                from: hostileWrapper,
                ofType: RevivalProjectDocument.projectType
            )
        ) {
            XCTAssertEqual(
                $0 as? RevivalProjectError,
                .duplicateRoomName("control room")
            )
        }
        XCTAssertEqual(document.project, original)

        root["roomNameEdits"] = [
            ["sourceIndex": 2, "name": "  "],
        ]
        let whitespaceJSON = try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys]
        )
        let whitespaceWrapper = FileWrapper(directoryWithFileWrappers: [
            "project.json": FileWrapper(regularFileWithContents: whitespaceJSON),
        ])
        XCTAssertThrowsError(
            try document.read(
                from: whitespaceWrapper,
                ofType: RevivalProjectDocument.projectType
            )
        ) {
            XCTAssertEqual($0 as? RevivalProjectError, .invalidRoomName)
        }
        XCTAssertEqual(document.project, original)

        root["roomNameEdits"] = [
            ["sourceIndex": 999, "name": "Unknown Room"],
        ]
        let unknownRoomJSON = try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys]
        )
        let unknownRoomWrapper = FileWrapper(directoryWithFileWrappers: [
            "project.json": FileWrapper(regularFileWithContents: unknownRoomJSON),
        ])
        XCTAssertThrowsError(
            try document.read(
                from: unknownRoomWrapper,
                ofType: RevivalProjectDocument.projectType
            )
        ) {
            XCTAssertEqual($0 as? RevivalProjectError, .invalidRoomNameEdit(999))
        }
        XCTAssertEqual(document.project, original)
    }

    @MainActor
    func testUnsupportedProjectSchemaWinsBeforeMissingBaseResolution() throws {
        let original = try makeProject(importedBase: makeMinimalCanonicalPackageLevel())
        let document = RevivalProjectDocument(project: original)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: canonicalJSONData(original.persistedSource)
            ) as? [String: Any]
        )
        object["schemaVersion"] = 2
        var base = try XCTUnwrap(object["base"] as? [String: Any])
        base["identitySHA256"] = String(repeating: "b", count: 64)
        object["base"] = base
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            "project.json": FileWrapper(
                regularFileWithContents: try JSONSerialization.data(
                    withJSONObject: object,
                    options: [.sortedKeys]
                )
            ),
        ])

        XCTAssertThrowsError(
            try document.read(
                from: wrapper,
                ofType: RevivalProjectDocument.projectType
            )
        ) {
            XCTAssertEqual($0 as? RevivalProjectError, .unsupportedSchema(2))
        }
        XCTAssertEqual(document.project, original)
    }

    @MainActor
    func testPlaySessionIsSeparateAndReturnRestoresDocumentState() throws {
        let importedBase = makeClosedRoomProjectLevel()
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: importedBase)
        )
        try document.renameSelectedRoom(to: "Course Start")
        let initialPlaySession = try document.makePlaySession()
        XCTAssertNil(document.playSession)
        document.commitPlaySession(initialPlaySession)

        let movedCamera = RoomCamera(
            position: .init(
                x: RoomCamera.trainingRoom3.position.x + 0.25,
                y: RoomCamera.trainingRoom3.position.y,
                z: RoomCamera.trainingRoom3.position.z
            ),
            target: .init(
                x: RoomCamera.trainingRoom3.target.x + 0.25,
                y: RoomCamera.trainingRoom3.target.y,
                z: RoomCamera.trainingRoom3.target.z
            ),
            up: RoomCamera.trainingRoom3.up
        )
        let movedPlaySession = try document.makePlaySession(movingCameraTo: movedCamera)
        XCTAssertEqual(document.playSession?.camera, .trainingRoom3)
        document.commitPlaySession(movedPlaySession)
        try document.renameSelectedRoom(to: "Course Revised")

        XCTAssertEqual(
            document.playSession?.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "Course Start"
        )
        XCTAssertEqual(document.playSession?.camera, movedCamera)
        XCTAssertNil(importedBase.rooms.first { $0.sourceIndex == 3 }?.name)

        document.returnToEditor()
        XCTAssertNil(document.playSession)
        XCTAssertEqual(document.selectedRoomSourceIndex, 3)
        XCTAssertEqual(document.camera, movedCamera)
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "Course Revised"
        )
    }

    @MainActor
    func testPlayReturnPreservesEditorSelectionAndFixedCameraIdentity() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeConnectedRoomProjectLevel())
        )
        try document.selectPortal(0)
        document.followSelectedPortal()
        try document.selectPortal(0)
        document.followSelectedPortal()
        let selectionBeforePlay = document.editorSelection

        let staged = try document.makePlaySession()
        XCTAssertEqual(staged.camera, .trainingRoom3)
        document.commitPlaySession(staged)
        XCTAssertEqual(document.editorSelection, selectionBeforePlay)

        let movedCamera = RoomCamera(
            position: .init(
                x: staged.camera.position.x + 0.25,
                y: staged.camera.position.y,
                z: staged.camera.position.z
            ),
            target: .init(
                x: staged.camera.target.x + 0.25,
                y: staged.camera.target.y,
                z: staged.camera.target.z
            ),
            up: staged.camera.up,
            projection: staged.camera.projection
        )
        document.commitPlaySession(
            try document.makePlaySession(movingCameraTo: movedCamera)
        )

        document.returnToEditor()
        XCTAssertEqual(document.editorSelection, selectionBeforePlay)
        XCTAssertEqual(document.cameraContainingRoomSourceIndex, 3)
        XCTAssertEqual(document.camera, movedCamera)
    }

    @MainActor
    func testPlayCameraRejectsAnOutsideEndpointWithoutChangingTheSession() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeClosedRoomProjectLevel())
        )
        document.commitPlaySession(try document.makePlaySession())
        let before = try XCTUnwrap(document.playSession)
        let proposed = RoomCamera(
            position: .init(
                x: before.camera.position.x - 2,
                y: before.camera.position.y,
                z: before.camera.position.z
            ),
            target: .init(
                x: before.camera.target.x - 2,
                y: before.camera.target.y,
                z: before.camera.target.z
            ),
            up: before.camera.up,
            projection: before.camera.projection
        )

        XCTAssertThrowsError(try document.makePlaySession(movingCameraTo: proposed)) {
            XCTAssertEqual(
                $0 as? RevivalProjectDocumentError,
                .cameraOutsideRoom(3)
            )
        }
        XCTAssertEqual(document.playSession, before)
    }
}

private func makeProject(importedBase: Level) throws -> RevivalProject {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
    let library = CanonicalPackageLibrary(
        rootURL: root.appending(path: "library", directoryHint: .isDirectory)
    )
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    try writeCanonicalPackage(importedBase, to: candidate)
    return try RevivalProject(
        activatedBase: library.installAndActivate(from: candidate)
    )
}

private func makeClosedRoomProjectLevel() -> Level {
    var level = makeMinimalCanonicalPackageLevel()
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 3 }!
    level.rooms[roomIndex] = makeSourceContainmentRoom(
        center: RoomCamera.trainingRoom3.position,
        texture: level.presentationMaterials[0].texture
    )
    return level
}

private func makeConnectedRoomProjectLevel() -> Level {
    var level = makeClosedRoomProjectLevel()
    let texture = level.presentationMaterials[0].texture
    let corners = [
        FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 1, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 0, v: 1, alpha: 255),
    ]
    let vertices = [
        Vector3.zero,
        Vector3(x: 1, y: 0, z: 0),
        Vector3(x: 0, y: 1, z: 0),
    ]
    let portalFace: (Int?) -> LevelFace = { portalIndex in
        LevelFace(
            corners: corners,
            flags: 0,
            portalIndex: portalIndex,
            texture: texture
        )
    }

    let room3Index = level.rooms.firstIndex { $0.sourceIndex == 3 }!
    let room3 = level.rooms[room3Index]
    level.rooms[room3Index] = LevelRoom(
        sourceIndex: room3.sourceIndex,
        name: room3.name,
        pathPoint: room3.pathPoint,
        vertices: room3.vertices,
        faces: room3.faces.enumerated().map { index, face in
            guard index == 0 else { return face }
            return LevelFace(
                corners: face.corners,
                flags: face.flags,
                portalIndex: 0,
                texture: face.texture,
                lightmapInfoIndex: face.lightmapInfoIndex,
                allowsLightCorona: face.allowsLightCorona,
                lightMultiple: face.lightMultiple,
                special: face.special
            )
        },
        portals: [.init(faceIndex: 0, connectedRoom: 2, connectedPortal: 1)],
        flags: room3.flags,
        pulseTime: room3.pulseTime,
        pulseOffset: room3.pulseOffset,
        mirrorFaceIndex: room3.mirrorFaceIndex,
        door: room3.door,
        volumeLights: room3.volumeLights,
        fog: room3.fog,
        ambientSoundPattern: room3.ambientSoundPattern,
        reverb: room3.reverb,
        damage: room3.damage,
        damageType: room3.damageType
    )
    level.rooms.removeAll { $0.sourceIndex == 2 || $0.sourceIndex == 4 }
    level.rooms.append(
        LevelRoom(
            sourceIndex: 2,
            vertices: vertices,
            faces: [portalFace(0), portalFace(1)],
            portals: [
                .init(faceIndex: 0, connectedRoom: 1, connectedPortal: 0),
                .init(faceIndex: 1, connectedRoom: 3, connectedPortal: 0),
            ]
        )
    )
    level.rooms.append(
        LevelRoom(
            sourceIndex: 1,
            vertices: vertices,
            faces: [portalFace(0)],
            portals: [.init(faceIndex: 0, connectedRoom: 2, connectedPortal: 0)]
        )
    )
    return level
}
