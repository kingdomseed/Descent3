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
    func testProjectPersistsOnlyAnInstalledBaseReferenceAndSelectedValueDeltas() throws {
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
        XCTAssertEqual(
            Set(object.keys),
            [
                "base",
                "faceMaterialEdits",
                "objectTransformEdits",
                "playerStartTransformEdits",
                "portalRenderingEdits",
                "roomNameEdits",
                "schemaVersion",
            ]
        )
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
    func testFaceMaterialAndPortalRenderingEditsRegisterNamedUndo() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeEditableProjectLevel())
        )
        let alternateTexture = document.project.level.presentationMaterials[0].texture

        try document.selectFace(1)
        try document.setSelectedFaceMaterial(to: alternateTexture)
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 3 }?.faces[1].texture,
            alternateTexture
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Set Face Material")
        document.undoManager?.undo()
        XCTAssertNotEqual(
            document.project.level.rooms.first { $0.sourceIndex == 3 }?.faces[1].texture,
            alternateTexture
        )
        document.undoManager?.redo()

        try document.selectPortal(0)
        try document.setSelectedPortalRendersFaces(false)
        XCTAssertEqual(
            try XCTUnwrap(document.project.level.rooms.first { $0.sourceIndex == 3 }).portals[0].flags & 1,
            UInt32(0)
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Set Portal Rendering")
        document.undoManager?.undo()
        XCTAssertEqual(
            try XCTUnwrap(document.project.level.rooms.first { $0.sourceIndex == 3 }).portals[0].flags & 1,
            UInt32(1)
        )
    }

    @MainActor
    func testObjectAndPlayerStartTransformsUseStableIdentitiesAndNamedUndo() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeEditableProjectLevel())
        )
        let quarterTurn = Matrix3(
            right: .init(x: 0, y: 1, z: 0),
            up: .init(x: -1, y: 0, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )

        let objectBefore = try XCTUnwrap(
            document.project.level.objects.first { $0.handle == 6_147 }
        )
        XCTAssertThrowsError(
            try document.setObjectTransform(
                handle: 6_147,
                to: .init(
                    position: .init(
                        x: objectBefore.position.x + 0.25,
                        y: objectBefore.position.y,
                        z: objectBefore.position.z
                    ),
                    orientation: objectBefore.orientation
                )
            )
        ) {
            XCTAssertEqual(
                $0 as? RevivalProjectError,
                .objectPositionEditDeferred(6_147)
            )
        }
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 },
            objectBefore
        )
        try document.rotateObjectQuarterTurn(handle: 6_147)
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 }?.orientation,
            quarterTurn
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Transform Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 }?.orientation,
            objectBefore.orientation
        )

        let playerBefore = try XCTUnwrap(
            document.project.level.objects.first { $0.handle == 2_048 }
        )
        XCTAssertThrowsError(
            try document.setPlayerStartTransform(
                playerID: 0,
                handle: 2_048,
                to: .init(
                    position: .init(
                        x: playerBefore.position.x + 0.25,
                        y: playerBefore.position.y,
                        z: playerBefore.position.z
                    ),
                    orientation: playerBefore.orientation
                )
            )
        ) {
            XCTAssertEqual(
                $0 as? RevivalProjectError,
                .playerStartPositionEditDeferred(playerID: 0, handle: 2_048)
            )
        }
        try document.rotatePlayerStartQuarterTurn(handle: 2_048)
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 2_048 }?.orientation,
            quarterTurn
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Transform Player Start")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 2_048 }?.orientation,
            playerBefore.orientation
        )
    }

    @MainActor
    func testSelectedValueDeltasRoundTripDeterministicallyWithSemanticDiff() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        let importedBase = makeEditableProjectLevel()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(importedBase, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        let quarterTurn = Matrix3(
            right: .init(x: 0, y: 1, z: 0),
            up: .init(x: -1, y: 0, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )

        try document.selectRoom(sourceIndex: 1)
        try document.renameSelectedRoom(to: "Generator Annex")
        try document.selectRoom(sourceIndex: 3)
        try document.selectFace(1)
        try document.setSelectedFaceMaterial(to: importedBase.presentationMaterials[0].texture)
        try document.selectPortal(0)
        try document.setSelectedPortalRendersFaces(false)
        let object = try XCTUnwrap(importedBase.objects.first { $0.handle == 6_147 })
        try document.setObjectTransform(
            handle: object.handle,
            to: .init(position: object.position, orientation: quarterTurn)
        )
        let player = try XCTUnwrap(importedBase.objects.first { $0.handle == 2_048 })
        try document.setPlayerStartTransform(
            playerID: player.storedID,
            handle: player.handle,
            to: .init(position: player.position, orientation: quarterTurn)
        )

        let first = try document.fileWrapper(ofType: RevivalProjectDocument.projectType)
        let second = try document.fileWrapper(ofType: RevivalProjectDocument.projectType)
        let firstJSON = try XCTUnwrap(first.fileWrappers?["project.json"]?.regularFileContents)
        XCTAssertEqual(
            firstJSON,
            try XCTUnwrap(second.fileWrappers?["project.json"]?.regularFileContents)
        )
        XCTAssertEqual(document.project.semanticDiff.count, 5)

        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(from: first, ofType: RevivalProjectDocument.projectType)
        XCTAssertEqual(reopened.project, document.project)
        XCTAssertEqual(reopened.project.semanticDiff, document.project.semanticDiff)
        XCTAssertEqual(try library.load(activation.reference), importedBase)
    }

    func testCanonicalBoundaryRejectsMismatchedReciprocalPortalGeometry() throws {
        var level = makeConnectedRoomProjectLevel()
        let roomIndex = try XCTUnwrap(level.rooms.firstIndex { $0.sourceIndex == 2 })
        let room = level.rooms[roomIndex]
        var faces = room.faces
        let portalFaceIndex = room.portals[1].faceIndex
        let portalFace = faces[portalFaceIndex]
        faces[portalFaceIndex] = LevelFace(
            corners: Array(portalFace.corners.reversed()),
            flags: portalFace.flags,
            portalIndex: portalFace.portalIndex,
            texture: portalFace.texture,
            lightmapInfoIndex: portalFace.lightmapInfoIndex,
            allowsLightCorona: portalFace.allowsLightCorona,
            lightMultiple: portalFace.lightMultiple,
            special: portalFace.special
        )
        level.rooms[roomIndex] = LevelRoom(
            sourceIndex: room.sourceIndex,
            name: room.name,
            pathPoint: room.pathPoint,
            vertices: room.vertices,
            faces: faces,
            portals: room.portals,
            flags: room.flags,
            pulseTime: room.pulseTime,
            pulseOffset: room.pulseOffset,
            mirrorFaceIndex: room.mirrorFaceIndex,
            door: room.door,
            volumeLights: room.volumeLights,
            fog: room.fog,
            ambientSoundPattern: room.ambientSoundPattern,
            reverb: room.reverb,
            damage: room.damage,
            damageType: room.damageType
        )

        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .mismatchedPortalGeometry(room: 3, portal: 0)
            )
        }
    }

    func testCanonicalBoundaryValidatesConnectedFaceBeforeMatchingGeometry() throws {
        var level = makeConnectedRoomProjectLevel()
        let roomIndex = try XCTUnwrap(level.rooms.firstIndex { $0.sourceIndex == 2 })
        let portal = level.rooms[roomIndex].portals[1]
        level.rooms[roomIndex].portals[1] = LevelPortal(
            flags: portal.flags,
            faceIndex: level.rooms[roomIndex].faces.count,
            connectedRoom: portal.connectedRoom,
            connectedPortal: portal.connectedPortal,
            boundaryNodeIndex: portal.boundaryNodeIndex,
            pathPoint: portal.pathPoint,
            combineMaster: portal.combineMaster
        )

        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidFacePortal(room: 2, face: 1)
            )
        }
    }

    func testCanonicalBoundaryRejectsReachedMalformedFaceStructure() throws {
        let texture = makeMinimalCanonicalPackageLevel().presentationMaterials[0].texture
        func levelWithFace(vertices: [Vector3], indices: [Int]) -> Level {
            var level = makeMinimalCanonicalPackageLevel()
            level.rooms.append(
                LevelRoom(
                    sourceIndex: 10,
                    vertices: vertices,
                    faces: [
                        .init(
                            corners: indices.map {
                                .init(vertexIndex: $0, u: 0, v: 0, alpha: 255)
                            },
                            flags: 0,
                            portalIndex: nil,
                            texture: texture
                        ),
                    ],
                    portals: []
                )
            )
            return level
        }

        let degenerate = levelWithFace(
            vertices: [.zero, .init(x: 1, y: 0, z: 0), .init(x: 0, y: 1, z: 0)],
            indices: [0, 1, 0]
        )
        XCTAssertThrowsError(try degenerate.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .degenerateFace(room: 10, face: 0)
            )
        }

        let lowPrecisionNormal = levelWithFace(
            vertices: [
                .zero,
                .init(x: 0.01, y: 0, z: 0),
                .init(x: 0, y: 0.01, z: 0),
            ],
            indices: [0, 1, 2]
        )
        XCTAssertThrowsError(try lowPrecisionNormal.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidFace(room: 10, face: 0)
            )
        }

        let nonplanar = levelWithFace(
            vertices: [
                .zero,
                .init(x: 1, y: 0, z: 0),
                .init(x: 1, y: 1, z: 0.5),
                .init(x: 0, y: 1, z: 0),
            ],
            indices: [0, 1, 2, 3]
        )
        XCTAssertThrowsError(try nonplanar.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .nonplanarFace(room: 10, face: 0)
            )
        }

        let concave = levelWithFace(
            vertices: [
                .zero,
                .init(x: 2, y: 0, z: 0),
                .init(x: 1, y: 0.5, z: 0),
                .init(x: 2, y: 2, z: 0),
                .init(x: 0, y: 2, z: 0),
            ],
            indices: [0, 1, 2, 3, 4]
        )
        XCTAssertThrowsError(try concave.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .concaveFace(room: 10, face: 0)
            )
        }

        let sourceToleranceConcave = levelWithFace(
            vertices: [
                .zero,
                .init(x: 1.2037811, y: 1.5971571, z: 0),
                .init(x: 1.7434071, y: 1.1602463, z: -0.70276165),
                .init(x: 2.3259587, y: 0.75136924, z: -1.4231515),
                .init(x: 1.1221776, y: -0.8457879, z: -1.4231515),
            ],
            indices: [0, 1, 2, 3, 4]
        )
        XCTAssertThrowsError(try sourceToleranceConcave.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .concaveFace(room: 10, face: 0)
            )
        }
    }

    func testEditorQuarterTurnPreservesRigidOrientation() throws {
        let identity = Matrix3(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )

        XCTAssertEqual(
            quarterTurnedProjectOrientation(identity),
            Matrix3(
                right: .init(x: 0, y: 1, z: 0),
                up: .init(x: -1, y: 0, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            )
        )
        let sourceObjectOrientation = Matrix3(
            right: .init(x: -1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: -1)
        )
        XCTAssertEqual(
            quarterTurnedProjectOrientation(sourceObjectOrientation),
            Matrix3(
                right: .init(x: 0, y: 1, z: 0),
                up: .init(x: 1, y: 0, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            )
        )
    }


    func testCombinedPortalRenderingEditIsRefusedWithoutChangingProject() throws {
        var level = makeEditableProjectLevel()
        for (roomSourceIndex, portalIndex) in [(3, 0), (2, 1)] {
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == roomSourceIndex }
            )
            let portal = level.rooms[roomIndex].portals[portalIndex]
            level.rooms[roomIndex].portals[portalIndex] = LevelPortal(
                flags: portal.flags | 0x0000_0008,
                faceIndex: portal.faceIndex,
                connectedRoom: portal.connectedRoom,
                connectedPortal: portal.connectedPortal,
                boundaryNodeIndex: portal.boundaryNodeIndex,
                pathPoint: portal.pathPoint,
                combineMaster: portalIndex
            )
        }
        var project = try makeProject(importedBase: level)
        let before = project

        XCTAssertThrowsError(
            try project.setPortalRendersFace(
                roomSourceIndex: 3,
                portalIndex: 0,
                to: false
            )
        ) {
            XCTAssertEqual(
                $0 as? RevivalProjectError,
                .combinedPortalRenderingEditDeferred(
                    roomSourceIndex: 3,
                    portalIndex: 0
                )
            )
        }
        XCTAssertEqual(project, before)
    }

    func testSemanticChangesSummaryStaysBoundedForTheEditorSidebar() {
        XCTAssertEqual(
            boundedSemanticChangesText([]),
            "No authored changes"
        )
        XCTAssertEqual(
            boundedSemanticChangesText(["Room 3 face 9 material changed"]),
            "Room 3 face 9 material changed"
        )
        XCTAssertEqual(
            boundedSemanticChangesText([
                "Room 3 face 9 material changed",
                "Room 3 portal 0 rendering changed",
                "Object 6147 transform changed",
                "Player 0 start 2048 transform changed",
            ]),
            "Room 3 face 9 material changed (+3 more)"
        )
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
        object["schemaVersion"] = 3
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
            XCTAssertEqual($0 as? RevivalProjectError, .unsupportedSchema(3))
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
    func testEditedValuesPlayThroughSeparateCopyAndReturnToSameDocumentState() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeEditableProjectLevel())
        )
        try document.selectFace(1)
        let selectionBeforePlay = document.editorSelection
        let editedTexture = document.project.level.presentationMaterials[0].texture
        try document.setSelectedFaceMaterial(to: editedTexture)
        let object = try XCTUnwrap(
            document.project.level.objects.first { $0.handle == 6_147 }
        )
        let editedOrientation = quarterTurnedProjectOrientation(object.orientation)
        try document.setObjectTransform(
            handle: object.handle,
            to: .init(position: object.position, orientation: editedOrientation)
        )
        let diffBeforePlay = document.project.semanticDiff

        let staged = try document.makePlaySession()
        XCTAssertEqual(staged.level.rooms.first { $0.sourceIndex == 3 }?.faces[1].texture, editedTexture)
        XCTAssertEqual(
            staged.level.objects.first { $0.handle == object.handle }?.orientation,
            editedOrientation
        )
        document.commitPlaySession(staged)
        document.returnToEditor()

        XCTAssertEqual(document.editorSelection, selectionBeforePlay)
        XCTAssertEqual(document.camera, .trainingRoom3)
        XCTAssertEqual(document.project.semanticDiff, diffBeforePlay)
        XCTAssertEqual(document.project.level, staged.level)
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
    let portalFace: ([Int], Int?) -> LevelFace = { indices, portalIndex in
        LevelFace(
            corners: indices.enumerated().map { offset, vertexIndex in
                FaceCorner(
                    vertexIndex: vertexIndex,
                    u: offset == 1 || offset == 2 ? 1 : 0,
                    v: offset >= 2 ? 1 : 0,
                    alpha: 255
                )
            },
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
    let room3PortalPoints = level.rooms[room3Index].faces[0].corners.map {
        level.rooms[room3Index].vertices[$0.vertexIndex]
    }
    let room1PortalPoints = room3PortalPoints.map {
        Vector3(x: $0.x - 2, y: $0.y, z: $0.z)
    }
    let room2Vertices = room3PortalPoints + room1PortalPoints
    level.rooms.removeAll { $0.sourceIndex == 2 || $0.sourceIndex == 4 }
    level.rooms.append(
        LevelRoom(
            sourceIndex: 2,
            vertices: room2Vertices,
            faces: [
                portalFace([4, 5, 6, 7], 0),
                portalFace([0, 3, 2, 1], 1),
            ],
            portals: [
                .init(faceIndex: 0, connectedRoom: 1, connectedPortal: 0),
                .init(faceIndex: 1, connectedRoom: 3, connectedPortal: 0),
            ]
        )
    )
    level.rooms.append(
        LevelRoom(
            sourceIndex: 1,
            vertices: room1PortalPoints,
            faces: [portalFace([0, 3, 2, 1], 0)],
            portals: [.init(faceIndex: 0, connectedRoom: 2, connectedPortal: 0)]
        )
    )
    return level
}

private func makeEditableProjectLevel() -> Level {
    let base = makeConnectedRoomProjectLevel()
    let alternateTexture = SourceResource(storedIndex: 1, sourceName: "alternate-wall")
    let alternateMaterial = PresentationMaterial(
        texture: alternateTexture,
        bitmapSourceName: "alternate-wall.ogf",
        image: .init(width: 1, height: 1, rgba8: Data([128, 128, 128, 255])),
        blend: .opaque,
        lightmapBlend: .multiply,
        waterProcedural: nil,
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "e", count: 64)
    )
    var rooms = base.rooms
    let roomIndex = rooms.firstIndex { $0.sourceIndex == 3 }!
    let room = rooms[roomIndex]
    let faces = room.faces.enumerated().map { index, face in
        LevelFace(
            corners: face.corners,
            flags: face.flags,
            portalIndex: face.portalIndex,
            texture: index == 1 || index == 2 ? alternateTexture : face.texture,
            lightmapInfoIndex: face.lightmapInfoIndex,
            allowsLightCorona: face.allowsLightCorona,
            lightMultiple: face.lightMultiple,
            special: face.special
        )
    }
    rooms[roomIndex] = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices,
        faces: faces,
        portals: room.portals.map {
            LevelPortal(
                flags: $0.flags | 1,
                faceIndex: $0.faceIndex,
                connectedRoom: $0.connectedRoom,
                connectedPortal: $0.connectedPortal,
                boundaryNodeIndex: $0.boundaryNodeIndex,
                pathPoint: $0.pathPoint,
                combineMaster: $0.combineMaster
            )
        },
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    func object(
        handle: UInt32,
        type: UInt8,
        storedID: Int,
        room: Int,
        position: Vector3
    ) -> PlacedObject {
        PlacedObject(
            handle: handle,
            type: type,
            storedID: storedID,
            definition: nil,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(room),
            position: position,
            orientation: identity,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
    }
    return Level(
        schemaVersion: base.schemaVersion,
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: rooms,
        terrain: base.terrain,
        objects: [
            object(
                handle: 2_048,
                type: D3SourceIdentity.playerObjectType,
                storedID: 0,
                room: 1,
                position: .init(x: 0.25, y: 0.25, z: 0)
            ),
            object(
                handle: 6_147,
                type: 6,
                storedID: 0,
                room: 3,
                position: RoomCamera.trainingRoom3.target
            ),
        ],
        retiredObjectHandles: base.retiredObjectHandles,
        paths: base.paths,
        goals: base.goals,
        goalFlags: base.goalFlags,
        triggers: base.triggers,
        playerStartFlags: base.playerStartFlags,
        lightmaps: base.lightmaps,
        presentationMaterials: base.presentationMaterials + [alternateMaterial],
        presentationCoronaAssets: base.presentationCoronaAssets,
        models: base.models,
        objectPresentations: base.objectPresentations,
        dependencyManifest: .init(
            current: base.dependencyManifest.current + [
                .init(
                    category: "texture",
                    source: alternateTexture,
                    state: "presentation-payload-imported",
                    provenance: "synthetic editable project fixture"
                ),
            ],
            historicalEagerBaseline: base.dependencyManifest.historicalEagerBaseline
        ),
        sourceChunks: base.sourceChunks
    )
}
