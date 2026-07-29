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
                "roomVertexEdits",
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
    func testTrainingScript005HasDiagnosticNamedUndoAndDisposablePlayOwnership()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        let immutableBase = makeTrainingDodgeAttemptLevel()
        try writeCanonicalPackage(immutableBase, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        let leftGoal = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == 12_299
            }
        )
        let startGoal = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == 12_300
            }
        )
        let upGoal = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == 18_441
            }
        )
        let forwardGoal = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == 12_301
            }
        )
        let finishCourse = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == 6_150
            }
        )
        XCTAssertEqual(
            document.project.trainingReturnUpSourceDiagnostic,
            "TrainingMission.cpp Script 005 / StartGoal handle 12300 / up1.osf"
        )
        XCTAssertEqual(
            document.project.trainingReturnDownSourceDiagnostic,
            "TrainingMission.cpp Script 006 / UpGoal handle 18441 / return3.osf"
        )
        XCTAssertEqual(
            document.project.trainingRepeatForwardSourceDiagnostic,
            "TrainingMission.cpp Script 007 / StartGoal handle 12300 / repeat.osf"
        )
        XCTAssertEqual(
            document.project.trainingRepeatForwardGoalSourceDiagnostic,
            "TrainingMission.cpp Script 008 / ForwardGoal handle 12301 / MenuBeepEnter"
        )
        XCTAssertEqual(
            document.project.trainingRepeatReturnLeftSourceDiagnostic,
            "TrainingMission.cpp Script 009 / StartGoal handle 12300 / lright.osf"
        )
        XCTAssertEqual(
            document.project.trainingRepeatReturnRightSourceDiagnostic,
            "TrainingMission.cpp Script 010 / LeftGoal handle 12299 / MenuBeepEnter"
        )
        XCTAssertEqual(
            document.project.trainingRepeatReturnUpSourceDiagnostic,
            "TrainingMission.cpp Script 011 / StartGoal handle 12300 / udown.osf"
        )
        XCTAssertEqual(
            document.project.trainingRepeatReturnDownSourceDiagnostic,
            "TrainingMission.cpp Script 012 / UpGoal handle 18441 / MenuBeepEnter"
        )
        XCTAssertEqual(
            document.project.trainingContinueToCourseSourceDiagnostic,
            "TrainingMission.cpp Script 013 / StartGoal handle 12300 / PortalRoom1 portals 0,1 / proceed1.osf"
        )
        XCTAssertEqual(
            document.project.trainingStartCourseSourceDiagnostic,
            "TrainingMission.cpp Script 014 / StartCourse handle 6147 / PortalRoom1 portal 1 / Intro1.osf"
        )
        XCTAssertEqual(
            document.project.trainingFinishCourseSourceDiagnostic,
            "TrainingMission.cpp Script 015 / FinishCourse handle 6150 / PortalRoom2 portals 0,1 / proceed2.osf"
        )
        XCTAssertEqual(
            document.project.trainingDodgeAttemptSourceDiagnostic,
            "TrainingMission.cpp Scripts 033,016,017,018,020 / StartDodge 4106 / DoneDodgeingGoal 12302 / DodgeTurrett 8199 / FlashLight-1 4120 / PortalRoom2+3 portals 0,1 / intro2.osf+almost.osf+proceed3.osf"
        )
        XCTAssertEqual(
            document.project.trainingReturnRightSourceDiagnostic,
            "TrainingMission.cpp Script 004 / LeftGoal handle 12299 / return2.osf"
        )
        XCTAssertEqual(
            document.project.trainingReturnLeftSourceDiagnostic,
            "TrainingMission.cpp Script 003 / StartGoal handle 12300 / left1.osf"
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 005 / StartGoal handle 12300 / up1.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 006 / UpGoal handle 18441 / return3.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 008 / ForwardGoal handle 12301 / MenuBeepEnter"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 009 / StartGoal handle 12300 / lright.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 010 / LeftGoal handle 12299 / MenuBeepEnter"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 011 / StartGoal handle 12300 / udown.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 012 / UpGoal handle 18441 / MenuBeepEnter"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 013 / StartGoal handle 12300 / PortalRoom1 portals 0,1 / proceed1.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 014 / StartCourse handle 6147 / PortalRoom1 portal 1 / Intro1.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 015 / FinishCourse handle 6150 / PortalRoom2 portals 0,1 / proceed2.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Scripts 033,016,017,018,020 / StartDodge 4106"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 007 / StartGoal handle 12300 / repeat.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 004 / LeftGoal handle 12299 / return2.osf"
            )
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: document.project,
                selection: document.editorSelection
            ).contains(
                "TrainingMission.cpp Script 003 / StartGoal handle 12300 / left1.osf"
            )
        )

        try document.selectRoom(sourceIndex: 2)
        for portalIndex in [0, 1] {
            try document.selectPortal(portalIndex)
            try document.setSelectedPortalRendersFaces(false)
            XCTAssertEqual(
                document.undoManager?.undoActionName,
                "Set Portal Rendering"
            )
            document.undoManager?.undo()
            let restoredRoom = try XCTUnwrap(
                document.project.level.rooms.first {
                    $0.sourceIndex == 2
                }
            )
            XCTAssertNotEqual(
                restoredRoom.portals[portalIndex].flags & 1,
                0
            )
            document.undoManager?.redo()
            let openedRoom = try XCTUnwrap(
                document.project.level.rooms.first {
                    $0.sourceIndex == 2
                }
            )
            XCTAssertEqual(openedRoom.portals[portalIndex].flags & 1, 0)
        }
        try document.selectRoom(sourceIndex: 49)
        for portalIndex in [0, 1] {
            try document.selectPortal(portalIndex)
            try document.setSelectedPortalRendersFaces(false)
            XCTAssertEqual(
                document.undoManager?.undoActionName,
                "Set Portal Rendering"
            )
            document.undoManager?.undo()
            let restoredRoom = try XCTUnwrap(
                document.project.level.rooms.first {
                    $0.sourceIndex == 49
                }
            )
            XCTAssertNotEqual(
                restoredRoom.portals[portalIndex].flags & 1,
                0
            )
            document.undoManager?.redo()
            let openedRoom = try XCTUnwrap(
                document.project.level.rooms.first {
                    $0.sourceIndex == 49
                }
            )
            XCTAssertEqual(openedRoom.portals[portalIndex].flags & 1, 0)
        }

        try document.rotateObjectQuarterTurn(handle: upGoal.handle)
        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Transform Object"
        )
        XCTAssertNotEqual(
            document.project.level.objects.first {
                $0.handle == upGoal.handle
            }?.orientation,
            upGoal.orientation
        )
        let rotatedOrientation = document.project.level.objects.first {
            $0.handle == upGoal.handle
        }?.orientation
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == upGoal.handle
            }?.orientation,
            upGoal.orientation
        )
        document.undoManager?.redo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == upGoal.handle
            }?.orientation,
            rotatedOrientation
        )
        try document.rotateObjectQuarterTurn(handle: startGoal.handle)
        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Transform Object"
        )
        let rotatedStartGoalOrientation =
            document.project.level.objects.first {
                $0.handle == startGoal.handle
            }?.orientation
        XCTAssertNotEqual(rotatedStartGoalOrientation, startGoal.orientation)
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == startGoal.handle
            }?.orientation,
            startGoal.orientation
        )
        document.undoManager?.redo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == startGoal.handle
            }?.orientation,
            rotatedStartGoalOrientation
        )
        try document.rotateObjectQuarterTurn(handle: forwardGoal.handle)
        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Transform Object"
        )
        let rotatedForwardGoalOrientation =
            document.project.level.objects.first {
                $0.handle == forwardGoal.handle
            }?.orientation
        XCTAssertNotEqual(
            rotatedForwardGoalOrientation,
            forwardGoal.orientation
        )
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == forwardGoal.handle
            }?.orientation,
            forwardGoal.orientation
        )
        document.undoManager?.redo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == forwardGoal.handle
            }?.orientation,
            rotatedForwardGoalOrientation
        )
        try document.rotateObjectQuarterTurn(handle: leftGoal.handle)
        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Transform Object"
        )
        let rotatedLeftGoalOrientation =
            document.project.level.objects.first {
                $0.handle == leftGoal.handle
            }?.orientation
        XCTAssertNotEqual(rotatedLeftGoalOrientation, leftGoal.orientation)
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == leftGoal.handle
            }?.orientation,
            leftGoal.orientation
        )
        document.undoManager?.redo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == leftGoal.handle
            }?.orientation,
            rotatedLeftGoalOrientation
        )
        try document.rotateObjectQuarterTurn(handle: finishCourse.handle)
        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Transform Object"
        )
        let rotatedFinishCourseOrientation =
            document.project.level.objects.first {
                $0.handle == finishCourse.handle
            }?.orientation
        XCTAssertNotEqual(
            rotatedFinishCourseOrientation,
            finishCourse.orientation
        )
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == finishCourse.handle
            }?.orientation,
            finishCourse.orientation
        )
        document.undoManager?.redo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == finishCourse.handle
            }?.orientation,
            rotatedFinishCourseOrientation
        )

        let firstWrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let secondWrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            firstWrapper.fileWrappers?["project.json"]?.regularFileContents,
            secondWrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: firstWrapper,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(reopened.project, document.project)
        XCTAssertEqual(
            immutableBase.objects.first {
                $0.handle == upGoal.handle
            }?.orientation,
            upGoal.orientation
        )
        XCTAssertEqual(
            immutableBase.objects.first {
                $0.handle == startGoal.handle
            }?.orientation,
            startGoal.orientation
        )
        XCTAssertEqual(
            immutableBase.objects.first {
                $0.handle == forwardGoal.handle
            }?.orientation,
            forwardGoal.orientation
        )
        XCTAssertEqual(
            immutableBase.objects.first {
                $0.handle == leftGoal.handle
            }?.orientation,
            leftGoal.orientation
        )
        XCTAssertEqual(
            immutableBase.objects.first {
                $0.handle == finishCourse.handle
            }?.orientation,
            finishCourse.orientation
        )

        let playSession = reopened.makePlaySession()
        reopened.commitPlaySession(playSession, renderingWorld: false)
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.returnUp?
                .startGoalObjectHandle,
            startGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.returnRight?
                .leftGoalObjectHandle,
            leftGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.returnDown?
                .upGoalObjectHandle,
            upGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.repeatForward?
                .startGoalObjectHandle,
            startGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.repeatForwardGoal?
                .forwardGoalObjectHandle,
            forwardGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.repeatReturnLeft?
                .startGoalObjectHandle,
            startGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.repeatReturnRight?
                .leftGoalObjectHandle,
            leftGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.repeatReturnUp?
                .startGoalObjectHandle,
            startGoal.handle
        )
        XCTAssertEqual(
            playSession.level.trainingOpeningLesson?.finishCourse?
                .finishCourseObjectHandle,
            finishCourse.handle
        )
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == upGoal.handle
            }?.orientation,
            rotatedOrientation
        )
        XCTAssertEqual(
            playSession.level.objects.first {
                $0.handle == upGoal.handle
            }?.orientation,
            rotatedOrientation
        )
        XCTAssertEqual(
            playSession.level.objects.first {
                $0.handle == startGoal.handle
            }?.orientation,
            rotatedStartGoalOrientation
        )
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == forwardGoal.handle
            }?.orientation,
            rotatedForwardGoalOrientation
        )
        XCTAssertEqual(
            playSession.level.objects.first {
                $0.handle == forwardGoal.handle
            }?.orientation,
            rotatedForwardGoalOrientation
        )
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == leftGoal.handle
            }?.orientation,
            rotatedLeftGoalOrientation
        )
        XCTAssertEqual(
            playSession.level.objects.first {
                $0.handle == leftGoal.handle
            }?.orientation,
            rotatedLeftGoalOrientation
        )
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == upGoal.handle
            }?.orientation,
            rotatedOrientation
        )
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == startGoal.handle
            }?.orientation,
            rotatedStartGoalOrientation
        )
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == forwardGoal.handle
            }?.orientation,
            rotatedForwardGoalOrientation
        )
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == leftGoal.handle
            }?.orientation,
            rotatedLeftGoalOrientation
        )
    }

    @MainActor
    func testTrainingGalleryBarrierEditsAtomicallyPersistUndoAndStayOutOfPlayReturn() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        let trainingLevel = makeTrainingRobotGuidebotLevel()
        let unverifiedNavigationLevel = replacing(
            trainingLevel,
            indoorNavigation: .init(
                sourceHighestRoomPlusTerrainRegions:
                    trainingLevel.rooms.map(\.sourceIndex).max()! + 8,
                sourceWasVerified: false,
                rooms: []
            )
        )
        try writeCanonicalPackage(unverifiedNavigationLevel, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )

        XCTAssertTrue(document.project.trainingGalleryBarrierIsOpen)
        XCTAssertEqual(
            document.project.trainingGalleryBarrierSourceDiagnostic,
            "TrainingMission.cpp Script 032 / Portal2"
        )
        XCTAssertEqual(
            document.project.trainingRobotGuidebotSourceDiagnostic,
            "TrainingMission.cpp Scripts 036 + 060 / DestroyBot2 + Guidebot / NODE/BOA route radius 5.5594406, unverified 0 room records"
        )
        let editorStatus = editorIdleStatusMessage(
            project: document.project,
            selection: document.editorSelection
        )
        XCTAssertTrue(
            editorStatus.contains("TrainingMission.cpp Script 032 / Portal2")
        )
        XCTAssertTrue(
            editorStatus.contains(
                "TrainingMission.cpp Scripts 036 + 060 / DestroyBot2 + Guidebot"
            )
        )
        XCTAssertTrue(
            editorStatus.contains(
                "NODE/BOA route radius 5.5594406"
            )
        )
        XCTAssertTrue(editorStatus.contains("unverified 0 room records"))
        try document.selectRoom(sourceIndex: 2)
        try document.selectPortal(1)
        try document.setSelectedPortalRendersFaces(true)
        assertTrainingGalleryBarrierRendering(
            in: document.project.level,
            rendersFaces: true
        )
        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Set Training Gallery Barrier"
        )

        document.undoManager?.undo()
        assertTrainingGalleryBarrierRendering(
            in: document.project.level,
            rendersFaces: false
        )
        XCTAssertEqual(
            document.undoManager?.redoActionName,
            "Set Training Gallery Barrier"
        )
        document.undoManager?.redo()
        assertTrainingGalleryBarrierRendering(
            in: document.project.level,
            rendersFaces: true
        )

        let firstWrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let secondWrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            firstWrapper.fileWrappers?["project.json"]?.regularFileContents,
            secondWrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: firstWrapper,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(reopened.project, document.project)
        assertTrainingGalleryBarrierRendering(
            in: reopened.project.level,
            rendersFaces: true
        )

        try reopened.setTrainingGalleryBarrierOpen(true)
        let playSession = reopened.makePlaySession()
        reopened.commitPlaySession(playSession, renderingWorld: false)
        let simulation = playSession.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        var didTrigger = false
        for frameIndex in 1...20 {
            let frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                didTrigger = true
                break
            }
        }
        XCTAssertTrue(didTrigger)
        assertTrainingGalleryBarrierRendering(
            in: simulation.level,
            rendersFaces: true
        )
        assertTrainingGalleryBarrierRendering(
            in: reopened.project.level,
            rendersFaces: false
        )
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        assertTrainingGalleryBarrierRendering(
            in: reopened.project.level,
            rendersFaces: false
        )
    }

    @MainActor
    func testCameraMonitorSecurityCameraEditRoundTripsIntoDisposablePlay() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        let base = makeTrainingCameraMonitorLevel()
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false
        let chain = try XCTUnwrap(
            document.project.level.trainingCameraMonitorChain
        )
        XCTAssertEqual(
            document.project.trainingGuidebotReturnSourceDiagnostic,
            "TrainingMission.cpp Script 058 / FlashLight-3 + PortalRoom5"
        )
        try document.selectRoom(sourceIndex: 2)
        try document.selectPortal(0)
        document.undoManager?.beginUndoGrouping()
        try document.setSelectedPortalRendersFaces(true)
        document.undoManager?.endUndoGrouping()
        assertTrainingGuidebotReturnBarrierRendering(
            in: document.project.level,
            rendersFaces: true
        )
        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Set Training Guidebot Return Barrier"
        )
        document.undoManager?.undo()
        assertTrainingGuidebotReturnBarrierRendering(
            in: document.project.level,
            rendersFaces: false
        )
        document.undoManager?.redo()
        let camera = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == chain.securityCameraObjectHandle
            }
        )
        let movedPosition = Vector3(
            x: camera.position.x + 0.05,
            y: camera.position.y,
            z: camera.position.z
        )

        document.undoManager?.beginUndoGrouping()
        let result = try document.moveObject(
            handle: camera.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()

        XCTAssertEqual(
            result.diagnostic,
            "Moved TrainingMission.cpp Script 059 SecurityCamera handle \(camera.handle) for the Camera Monitor popup. Undo action: Move Object."
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        XCTAssertEqual(
            activation.level.objects.first {
                $0.handle == camera.handle
            }?.position,
            camera.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )

        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == camera.handle
            }?.position,
            result.committedPosition
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 0.1, input: .zero)
        let used = simulation.update(
            at: 0.2,
            input: .init(usesInventory: true)
        )
        XCTAssertNotNil(used.trainingCameraMonitor)
        XCTAssertNotEqual(simulation.level, reopened.project.level)
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == camera.handle
            }?.position,
            result.committedPosition
        )
    }

    @MainActor
    func testKillbotEntryBarrierHasSourceDiagnosticAndNamedUndo()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingKillbotEntryLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingKillbotEntrySourceDiagnostic,
            "TrainingMission.cpp Scripts 042 + 039 / Portal3 + PortalRoom5"
        )
        try document.selectRoom(sourceIndex: 2)
        try document.selectPortal(0)
        document.undoManager?.beginUndoGrouping()
        try document.setSelectedPortalRendersFaces(true)
        document.undoManager?.endUndoGrouping()

        XCTAssertEqual(
            document.undoManager?.undoActionName,
            "Set Training Killbot Entry Barrier"
        )
        document.undoManager?.undo()
        assertTrainingGuidebotReturnBarrierRendering(
            in: document.project.level,
            rendersFaces: false
        )
        document.undoManager?.redo()
        assertTrainingGuidebotReturnBarrierRendering(
            in: document.project.level,
            rendersFaces: true
        )
        document.undoManager?.undo()
        assertTrainingGuidebotReturnBarrierRendering(
            in: document.project.level,
            rendersFaces: false
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        assertTrainingGuidebotReturnBarrierRendering(
            in: reopened.project.level,
            rendersFaces: false
        )

        let playSession = reopened.makePlaySession()
        reopened.commitPlaySession(playSession, renderingWorld: false)
        let simulation = playSession.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        var didEnter = false
        for frameIndex in 1...40 {
            let frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "intro6.osf"
            }) {
                didEnter = true
                break
            }
        }
        XCTAssertTrue(didEnter)
        assertTrainingGuidebotReturnBarrierRendering(
            in: simulation.level,
            rendersFaces: true
        )
        assertTrainingGuidebotReturnBarrierRendering(
            in: reopened.project.level,
            rendersFaces: false
        )
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        assertTrainingGuidebotReturnBarrierRendering(
            in: reopened.project.level,
            rendersFaces: false
        )
    }

    @MainActor
    func testRASBot1DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingRASBot1DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingRASBot1DeathSourceDiagnostic,
            "TrainingMission.cpp Script 043 / RASBot1 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_074
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingRASBot1DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingRASBot1(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testRASBot2DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingRASBot2DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingRASBot2DeathSourceDiagnostic,
            "TrainingMission.cpp Script 044 / RASBot2 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_075
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingRASBot2DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingRASBot2(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testRASBot3DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingRASBot3DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingRASBot3DeathSourceDiagnostic,
            "TrainingMission.cpp Script 045 / RASBot3 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_077
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingRASBot3DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingRASBot3(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testRASBot4DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingRASBot4DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingRASBot4DeathSourceDiagnostic,
            "TrainingMission.cpp Script 046 / RASBot4 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_078
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingRASBot4DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingRASBot4(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testLastBot1DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingLastBot1DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingLastBot1DeathSourceDiagnostic,
            "TrainingMission.cpp Script 051 / LastBot1 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 4_127
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingLastBot1DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingLastBot1(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testLastBot2DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingLastBot2DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingLastBot2DeathSourceDiagnostic,
            "TrainingMission.cpp Script 052 / LastBot2 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_080
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingLastBot2DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingLastBot2(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testLastBot3DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingLastBot3DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingLastBot3DeathSourceDiagnostic,
            "TrainingMission.cpp Script 053 / LastBot3 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_081
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingLastBot3DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingLastBot3(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testLastBot4DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingLastBot4DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingLastBot4DeathSourceDiagnostic,
            "TrainingMission.cpp Script 054 / LastBot4 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_082
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingLastBot4DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingLastBot4(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testLastBot5DeathChainHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingLastBot5DeathLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingLastBot5DeathSourceDiagnostic,
            "TrainingMission.cpp Script 055 / LastBot5 death"
        )
        let robot = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 2_083
        })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: robot.position.x + 1,
            y: robot.position.y,
            z: robot.position.z
        )
        try document.moveObject(
            handle: robot.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == robot.handle
            }?.position,
            robot.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingLastBot5DeathChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingLastBot5(handle: robot.handle)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == robot.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == robot.handle
        })
    }

    @MainActor
    func testFinalBotsCompletionHasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingFinalBotsCompletionLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingFinalBotsCompletionSourceDiagnostic,
            "TrainingMission.cpp Scripts 035/056 / PortalRoom7 completion"
        )
        let marker = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 4_118
        })
        document.undoManager?.beginUndoGrouping()
        try document.moveObject(
            handle: marker.handle,
            to: .init(
                x: marker.position.x + 0.5,
                y: marker.position.y,
                z: marker.position.z
            )
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == marker.handle
            }?.position,
            marker.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingFinalBotsCompletionChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingLastBot1(handle: 4_127)
        simulation.destroyTrainingLastBot2(handle: 2_080)
        simulation.destroyTrainingLastBot3(handle: 2_081)
        simulation.destroyTrainingLastBot4(handle: 2_082)
        simulation.destroyTrainingLastBot5(handle: 2_083)
        _ = simulation.update(at: 0.1, input: .zero)
        let playBarrier = try XCTUnwrap(simulation.level.rooms.first {
            $0.sourceIndex == 16
        })
        let projectBarrier = try XCTUnwrap(
            reopened.project.level.rooms.first {
                $0.sourceIndex == 16
            }
        )
        XCTAssertEqual(playBarrier.portals[0].flags & 1, 0)
        XCTAssertNotEqual(projectBarrier.portals[0].flags & 1, 0)

        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertNotEqual(
            reopened.project.level.rooms.first {
                $0.sourceIndex == 16
            }?.portals[0].flags ?? 0,
            0
        )
    }

    @MainActor
    func testScript057FinalGoalHasDiagnosticUndoAndAutomaticPlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingFinalGoalLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingFinalGoalSourceDiagnostic,
            "TrainingMission.cpp Script 057 / FinalGoal collision and successful level end"
        )
        let goal = try XCTUnwrap(document.project.level.objects.first {
            $0.handle == 6_180
        })
        let goalRoom = try XCTUnwrap(
            document.project.level.rooms.first {
                $0.sourceIndex == 17
            }
        )
        let divisor = Float(goalRoom.vertices.count)
        let editPosition = Vector3(
            x: goalRoom.vertices.reduce(0) { $0 + $1.x } / divisor,
            y: goalRoom.vertices.reduce(0) { $0 + $1.y } / divisor,
            z: goalRoom.vertices.reduce(0) { $0 + $1.z } / divisor
        )
        document.undoManager?.beginUndoGrouping()
        try document.moveObject(
            handle: goal.handle,
            to: editPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == goal.handle
            }?.position,
            goal.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(reopened.project.level.trainingFinalGoalChain)

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let simulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        simulation.destroyTrainingLastBot1(handle: 4_127)
        simulation.destroyTrainingLastBot2(handle: 2_080)
        simulation.destroyTrainingLastBot3(handle: 2_081)
        simulation.destroyTrainingLastBot4(handle: 2_082)
        simulation.destroyTrainingLastBot5(handle: 2_083)
        _ = simulation.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        ready["playerLocation"] = ["room": ["_0": 17]]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        let collisionSimulation = try PlayerSimulation(
            level: session.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: ready)
            ),
            resumedAtTimestamp: 0
        )
        let frame = collisionSimulation.update(at: 0.2, input: .zero)
        XCTAssertTrue(
            reopened.finishPlaySessionIfLevelEnded(
                frame,
                renderingWorld: false
            )
        )
        XCTAssertNil(reopened.playSession)
        XCTAssertEqual(
            reopened.project.level.objects.first {
                $0.handle == goal.handle
            }?.position,
            goal.position
        )
        XCTAssertFalse(
            reopened.project.level.objectPresentations.first {
                $0.objectHandle == goal.handle
            }?.isVisible ?? true
        )
    }

    @MainActor
    func testInvulnPowerup2HasDiagnosticUndoAndDisposablePlayReturn()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingInvulnerabilityPickupLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingInvulnerabilityPickupSourceDiagnostic,
            "TrainingMission.cpp Script 047 / InvulnPowerup2 pickup"
        )
        let pickup = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == 2_076
            })
        document.undoManager?.beginUndoGrouping()
        let movedPosition = Vector3(
            x: pickup.position.x + 0.25,
            y: pickup.position.y,
            z: pickup.position.z
        )
        try document.moveObject(
            handle: pickup.handle,
            to: movedPosition
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == pickup.handle
            }?.position,
            pickup.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(
            reopened.project.level.trainingInvulnerabilityPickupChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let initialSimulation = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    initialSimulation.continuation
                )
            ) as? [String: Any]
        )
        let room = try XCTUnwrap(
            session.level.rooms.first { $0.sourceIndex == 12 }
        )
        var playerLocation = try XCTUnwrap(
            continuationObject["playerLocation"] as? [String: Any]
        )
        playerLocation["room"] = ["_0": 12]
        continuationObject["playerLocation"] = playerLocation
        continuationObject["playerPosition"] = [
            "x": room.pathPoint.x,
            "y": room.pathPoint.y,
            "z": room.pathPoint.z,
        ]
        let simulation = try PlayerSimulation(
            level: session.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: continuationObject
                )
            ),
            resumedAtTimestamp: 0
        )
        let frame = simulation.update(at: 0.1, input: .init())
        XCTAssertEqual(
            try XCTUnwrap(
                frame.trainingInvulnerabilityRemaining
            ),
            29.9,
            accuracy: 0.000_1
        )
        XCTAssertFalse(
            simulation.level.objects.contains {
                $0.handle == pickup.handle
            })
        XCTAssertTrue(
            reopened.project.level.objects.contains {
                $0.handle == pickup.handle
            })
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(
            reopened.project.level.objects.contains {
                $0.handle == pickup.handle
            })
    }

    @MainActor
    func testCloakLastRoomAndScript050HaveEditorOwnership()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(
                path: "library",
                directoryHint: .isDirectory
            )
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        try writeCanonicalPackage(
            makeTrainingFinalRoomEntryLevel(),
            to: candidate
        )
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        document.undoManager?.groupsByEvent = false

        XCTAssertEqual(
            document.project.trainingCloakPickupSourceDiagnostic,
            "TrainingMission.cpp Script 048 / CloakPowerup2 pickup"
        )
        XCTAssertEqual(
            document.project.trainingLastRoomSourceDiagnostic,
            "TrainingMission.cpp Scripts 034/049 / PortalRoom6 completion"
        )
        XCTAssertEqual(
            document.project.trainingFinalRoomEntrySourceDiagnostic,
            "TrainingMission.cpp Script 050 / Portal4 final combat entry"
        )
        let pickup = try XCTUnwrap(
            document.project.level.objects.first {
                $0.handle == 2_073
            })
        document.undoManager?.beginUndoGrouping()
        try document.moveObject(
            handle: pickup.handle,
            to: .init(
                x: pickup.position.x + 0.25,
                y: pickup.position.y,
                z: pickup.position.z
            )
        )
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first {
                $0.handle == pickup.handle
            }?.position,
            pickup.position
        )

        let first = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let second = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )
        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: first,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertNotNil(reopened.project.level.trainingCloakPickupChain)
        XCTAssertNotNil(reopened.project.level.trainingLastRoomChain)
        XCTAssertNotNil(
            reopened.project.level.trainingFinalRoomEntryChain
        )

        let session = reopened.makePlaySession()
        reopened.commitPlaySession(session, renderingWorld: false)
        let initial = session.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initial.continuation)
            ) as? [String: Any]
        )
        continuationObject["playerLocation"] = [
            "room": ["_0": 11]
        ]
        continuationObject["playerPosition"] = [
            "x": pickup.position.x,
            "y": pickup.position.y,
            "z": pickup.position.z,
        ]
        let simulation = try PlayerSimulation(
            level: session.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: continuationObject
                )
            ),
            resumedAtTimestamp: 0
        )
        let frame = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(frame.trainingCloak?.phase, .fadingOut)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == pickup.handle
        })
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == pickup.handle
        })

        let script050 = try PlayerSimulation(
            level: session.level,
            continuation: try script050ReadyContinuation(in: session.level),
            resumedAtTimestamp: 0
        )
        let entryFrame = script050.update(at: 0.1, input: .zero)
        XCTAssertEqual(
            entryFrame.trainingOpeningFeedback.suffix(2).last?
                .voiceSourceName,
            "intro7.osf"
        )
        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertTrue(reopened.project.level.objects.contains {
            $0.handle == pickup.handle
        })
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
                .invalidObjectTransformEdit(6_147)
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
                .invalidPlayerStartTransformEdit(playerID: 0, handle: 2_048)
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
        object["schemaVersion"] = 4
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
            XCTAssertEqual($0 as? RevivalProjectError, .unsupportedSchema(4))
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
        let initialPlaySession = document.makePlaySession()
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
        XCTAssertEqual(
            document.playSession?.camera,
            defaultPlayerView(in: document.project.level).camera
        )
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
        XCTAssertEqual(document.camera, .trainingRoom3)
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 3 }?.name,
            "Course Revised"
        )
    }

    @MainActor
    func testPlayerBoundPlaySessionUsesCanonicalViewWithoutReplacingEditorCamera() throws {
        let base = makeSliceSixObjectRenderLevel()
        let binding = try XCTUnwrap(base.defaultPlayerBinding)
        var objects = base.objects
        let playerIndex = try XCTUnwrap(
            objects.firstIndex { $0.handle == binding.objectHandle }
        )
        let player = objects[playerIndex]
        objects[playerIndex] = PlacedObject(
            handle: player.handle,
            type: player.type,
            storedID: player.storedID,
            definition: player.definition,
            instanceName: player.instanceName,
            flags: player.flags,
            doorShields: player.doorShields,
            location: .room(3),
            position: RoomCamera.trainingRoom3.position,
            orientation: player.orientation,
            containsType: player.containsType,
            containsID: player.containsID,
            containsCount: player.containsCount,
            lifeLeft: player.lifeLeft,
            soundSource: player.soundSource,
            inertScriptName: player.inertScriptName,
            inertModuleName: player.inertModuleName,
            lightmapSubmodels: player.lightmapSubmodels
        )
        let project = try makeProject(
            importedBase: replacing(base, objects: objects)
        )
        let document = RevivalProjectDocument(
            project: project
        )
        let editorCamera = document.camera

        let staged = document.makePlaySession()

        XCTAssertEqual(staged.playerView, defaultPlayerView(in: staged.level))
        XCTAssertEqual(staged.level, document.project.level)
        document.commitPlaySession(staged)
        document.returnToEditor()
        XCTAssertEqual(document.camera, editorCamera)
    }

    @MainActor
    func testDisposablePlaySessionTracesRenderedAndOpenRoomThreePortal() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeEditableProjectLevel())
        )
        let room = try XCTUnwrap(
            document.project.level.rooms.first { $0.sourceIndex == 3 }
        )
        let face = room.faces[0]
        let points = face.corners.map { room.vertices[$0.vertexIndex] }
        let center = points.reduce(Vector3.zero) {
            .init(x: $0.x + $1.x, y: $0.y + $1.y, z: $0.z + $1.z)
        }
        let faceCenter = Vector3(
            x: center.x / Float(points.count),
            y: center.y / Float(points.count),
            z: center.z / Float(points.count)
        )
        let normal = try XCTUnwrap(canonicalFaceNormal(room: room, face: face))
        let start = Vector3(
            x: faceCenter.x + normal.x * 0.5,
            y: faceCenter.y + normal.y * 0.5,
            z: faceCenter.z + normal.z * 0.5
        )
        let end = Vector3(
            x: faceCenter.x - normal.x * 0.5,
            y: faceCenter.y - normal.y * 0.5,
            z: faceCenter.z - normal.z * 0.5
        )

        try document.selectPortal(0)
        document.commitPlaySession(document.makePlaySession())
        let blocked = try document.tracePlayIndoorMovement(
            startRoom: 3,
            start: start,
            end: end,
            radius: 0
        )
        guard case .wallHit(let contact) = blocked.outcome else {
            return XCTFail("Rendered room 3 portal 0 must block")
        }
        XCTAssertEqual(contact.roomSourceIndex, 3)
        XCTAssertEqual(contact.faceIndex, 0)
        XCTAssertEqual(blocked.containingRoomSourceIndex, 3)
        let blockedDiagnostic = try document.traceSelectedPlayPortal(radius: 0.25)
        XCTAssertEqual(
            indoorMovementDiagnosticMessage(blockedDiagnostic),
            "Blocked at source room 3 face 0; resulting room 3."
        )

        document.returnToEditor()
        try document.selectPortal(0)
        try document.setSelectedPortalRendersFaces(false)
        document.commitPlaySession(document.makePlaySession())
        let open = try document.tracePlayIndoorMovement(
            startRoom: 3,
            start: start,
            end: end,
            radius: 0
        )
        XCTAssertEqual(open.outcome, .noHit)
        XCTAssertEqual(open.containingRoomSourceIndex, 2)
        XCTAssertEqual(open.visitedRoomSourceIndices, [3, 2])
        let openDiagnostic = try document.traceSelectedPlayPortal(radius: 0.25)
        XCTAssertEqual(
            indoorMovementDiagnosticMessage(openDiagnostic),
            "Crossed selected portal; resulting room 2."
        )
    }

    @MainActor
    func testPlayReturnPreservesEditorSelectionAndPlayerCameraIdentity() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeConnectedRoomProjectLevel())
        )
        try document.selectPortal(0)
        document.followSelectedPortal()
        try document.selectPortal(0)
        document.followSelectedPortal()
        let selectionBeforePlay = document.editorSelection

        let staged = document.makePlaySession()
        XCTAssertEqual(staged.camera, defaultPlayerView(in: staged.level).camera)
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
        XCTAssertEqual(document.camera, .trainingRoom3)
    }

    @MainActor
    func testDisposablePlayBuildsTheSameCoreSimulationWithoutMutatingAuthoredLevel() throws {
        let base = makeSliceSixObjectRenderLevel()
        let project = try makeProject(importedBase: base)
        let staged = project.makePlayerPlaySession()
        let authoredPosition = defaultPlayerView(in: project.level).camera.position
        let simulation = staged.makePlayerSimulation(
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(afterburner: 1)
        )

        XCTAssertNotEqual(frame.playerView.camera.position, authoredPosition)
        XCTAssertTrue(simulation.afterburnerIsActive)
        XCTAssertLessThan(simulation.afterburnerFuel, 5)
        XCTAssertGreaterThan(
            frame.playerView.camera.projection.horizontalFieldOfViewRadians,
            PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
        )
        XCTAssertEqual(
            defaultPlayerView(in: project.level).camera.position,
            authoredPosition
        )
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

        let staged = document.makePlaySession()
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
        document.commitPlaySession(document.makePlaySession())
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

    @MainActor
    func testTypedVertexMutationAndPointSnapPreserveIdentityValidationAndNamedUndo() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeGeometryProjectLevel())
        )
        let original = document.project.level.rooms.first {
            $0.sourceIndex == 40
        }!.vertices[0]
        let typedPosition = Vector3(x: 0.25, y: 0.125, z: 0)

        try document.setRoomVertex(
            roomSourceIndex: 40,
            vertexIndex: 0,
            to: typedPosition
        )
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 40 }!.vertices[0],
            typedPosition
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Set Room Vertex")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 40 }!.vertices[0],
            original
        )

        let target = document.project.level.rooms.first {
            $0.sourceIndex == 41
        }!.vertices[0]
        try document.snapRoomVertex(
            roomSourceIndex: 40,
            vertexIndex: 0,
            toRoomSourceIndex: 41,
            toVertexIndex: 0
        )
        XCTAssertEqual(
            document.project.level.rooms.first { $0.sourceIndex == 40 }!.vertices[0],
            target
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Snap Room Vertex")
        try document.project.validate()
    }

    @MainActor
    func testObjectAndPlayerPlacementUseIndoorTraceRelinkAndOwnerDiagnostics() throws {
        let document = RevivalProjectDocument(
            project: try makeProject(importedBase: makeEditableProjectLevel())
        )
        document.undoManager?.groupsByEvent = false
        let room3 = document.project.level.rooms.first { $0.sourceIndex == 3 }!
        let face = room3.faces[0]
        let points = face.corners.map { room3.vertices[$0.vertexIndex] }
        let center = points.reduce(Vector3.zero) {
            .init(x: $0.x + $1.x, y: $0.y + $1.y, z: $0.z + $1.z)
        }
        let portalCenter = Vector3(
            x: center.x / Float(points.count),
            y: center.y / Float(points.count),
            z: center.z / Float(points.count)
        )
        let normal = try XCTUnwrap(canonicalFaceNormal(room: room3, face: face))
        let room2Point = Vector3(
            x: portalCenter.x - normal.x * 0.5,
            y: portalCenter.y - normal.y * 0.5,
            z: portalCenter.z - normal.z * 0.5
        )
        let room3Point = Vector3(
            x: portalCenter.x + normal.x * 0.5,
            y: portalCenter.y + normal.y * 0.5,
            z: portalCenter.z + normal.z * 0.5
        )

        try document.selectPortal(0)
        document.undoManager?.beginUndoGrouping()
        try document.setSelectedPortalRendersFaces(false)
        document.undoManager?.endUndoGrouping()
        document.undoManager?.beginUndoGrouping()
        let room3Result = try document.moveObject(handle: 6_147, to: room3Point)
        document.undoManager?.endUndoGrouping()
        document.undoManager?.beginUndoGrouping()
        let objectResult = try document.moveObject(handle: 6_147, to: room2Point)
        document.undoManager?.endUndoGrouping()
        XCTAssertEqual(objectResult.committedLocation, .room(2))
        XCTAssertNil(objectResult.diagnostic)
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 }?.location,
            .room(2)
        )
        XCTAssertEqual(document.undoManager?.undoActionName, "Move Object")
        document.undoManager?.undo()
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 }?.position,
            room3Result.committedPosition
        )
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 }?.location,
            .room(3)
        )
        XCTAssertEqual(document.undoManager?.redoActionName, "Move Object")
        document.undoManager?.redo()
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 }?.position,
            objectResult.committedPosition
        )
        XCTAssertEqual(
            document.project.level.objects.first { $0.handle == 6_147 }?.location,
            .room(2)
        )

        let beforeRefusal = document.project
        XCTAssertThrowsError(
            try document.moveObject(
                handle: 6_147,
                to: .init(x: room2Point.x, y: room2Point.y, z: room2Point.z + 100)
            )
        ) {
            XCTAssertEqual(
                $0 as? RevivalProjectError,
                .placementHasNoContainingRoom(owner: "Object 6147")
            )
        }
        XCTAssertEqual(document.project, beforeRefusal)

        let closed = RevivalProjectDocument(
            project: try makeProject(importedBase: makeClosedRoomProjectLevel())
        )
        let player = try XCTUnwrap(
            closed.project.level.objects.first {
                $0.type == D3SourceIdentity.playerObjectType && $0.storedID == 0
            }
        )
        let result = try closed.movePlayerStart(
            playerID: 0,
            handle: player.handle,
            to: .init(x: player.position.x - 10, y: player.position.y, z: player.position.z)
        )
        XCTAssertEqual(result.committedLocation, .room(3))
        XCTAssertNotNil(result.diagnostic)
        XCTAssertEqual(closed.undoManager?.undoActionName, "Move Player Start")
        closed.undoManager?.undo()
        XCTAssertEqual(
            closed.project.level.objects.first { $0.handle == player.handle }?.position,
            player.position
        )
        XCTAssertEqual(
            closed.project.level.objects.first { $0.handle == player.handle }?.location,
            player.location
        )
        XCTAssertEqual(closed.undoManager?.redoActionName, "Move Player Start")
        closed.undoManager?.redo()
        XCTAssertEqual(
            closed.project.level.objects.first { $0.handle == player.handle }?.position,
            result.committedPosition
        )
        XCTAssertEqual(
            closed.project.level.objects.first { $0.handle == player.handle }?.location,
            result.committedLocation
        )
    }

    @MainActor
    func testNewAuthoredValuesRoundTripByteStablyAndPlayThroughSeparateCopy() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        let base = makeGeometryProjectLevel()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )

        try document.setRoomVertex(
            roomSourceIndex: 40,
            vertexIndex: 0,
            to: .init(x: 0.25, y: 0.125, z: 0)
        )
        let room3 = document.project.level.rooms.first { $0.sourceIndex == 3 }!
        let portalFace = room3.faces[0]
        let portalPoints = portalFace.corners.map {
            room3.vertices[$0.vertexIndex]
        }
        let portalSum = portalPoints.reduce(Vector3.zero) {
            .init(x: $0.x + $1.x, y: $0.y + $1.y, z: $0.z + $1.z)
        }
        let portalCenter = Vector3(
            x: portalSum.x / Float(portalPoints.count),
            y: portalSum.y / Float(portalPoints.count),
            z: portalSum.z / Float(portalPoints.count)
        )
        let portalNormal = try XCTUnwrap(
            canonicalFaceNormal(room: room3, face: portalFace)
        )
        try document.selectRoom(sourceIndex: 3)
        try document.selectPortal(0)
        try document.setSelectedPortalRendersFaces(false)
        _ = try document.moveObject(
            handle: 6_147,
            to: .init(
                x: portalCenter.x + portalNormal.x * 0.5,
                y: portalCenter.y + portalNormal.y * 0.5,
                z: portalCenter.z + portalNormal.z * 0.5
            )
        )
        _ = try document.moveObject(
            handle: 6_147,
            to: .init(
                x: portalCenter.x - portalNormal.x * 0.5,
                y: portalCenter.y - portalNormal.y * 0.5,
                z: portalCenter.z - portalNormal.z * 0.5
            )
        )
        let player = try XCTUnwrap(
            document.project.level.objects.first { $0.handle == 2_048 }
        )
        _ = try document.movePlayerStart(
            playerID: 0,
            handle: player.handle,
            to: .init(
                x: player.position.x + 0.05,
                y: player.position.y,
                z: player.position.z
            )
        )
        XCTAssertTrue(
            document.project.semanticDiff.map(\.summary).contains {
                $0.contains("room 3 → room 2")
            }
        )
        let first = try document.fileWrapper(ofType: RevivalProjectDocument.projectType)
        let second = try document.fileWrapper(ofType: RevivalProjectDocument.projectType)
        XCTAssertEqual(
            first.fileWrappers?["project.json"]?.regularFileContents,
            second.fileWrappers?["project.json"]?.regularFileContents
        )

        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(from: first, ofType: RevivalProjectDocument.projectType)
        XCTAssertEqual(
            reopened.project.level.objects.first { $0.handle == 6_147 }?.location,
            .room(2)
        )
        XCTAssertEqual(
            reopened.project.level.objects.first { $0.handle == 2_048 }?.position,
            .init(
                x: player.position.x + 0.05,
                y: player.position.y,
                z: player.position.z
            )
        )
        XCTAssertEqual(reopened.project.semanticDiff, document.project.semanticDiff)
        let selection = reopened.editorSelection
        let camera = reopened.camera
        let authored = reopened.project.level
        let staged = reopened.makePlaySession()
        XCTAssertEqual(staged.level, authored)
        reopened.commitPlaySession(staged)
        reopened.returnToEditor()
        XCTAssertEqual(reopened.project.level, authored)
        XCTAssertEqual(reopened.editorSelection, selection)
        XCTAssertEqual(reopened.camera, camera)
        XCTAssertEqual(try library.load(activation.reference), base)
    }

    func testProjectBoundaryRejectsPlacementWhoseRecordedRoomDoesNotContainIt() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let base = makeGeometryProjectLevel()
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        var source = RevivalProjectSource(base: activation.reference)
        let object = try XCTUnwrap(base.objects.first { $0.handle == 6_147 })
        source.objectTransformEdits = [
            .init(
                handle: object.handle,
                location: .room(2),
                transform: .init(
                    position: .init(
                        x: object.position.x + 0.05,
                        y: object.position.y,
                        z: object.position.z
                    ),
                    orientation: object.orientation
                )
            ),
        ]

        XCTAssertThrowsError(try RevivalProject(source: source, library: library)) {
            XCTAssertEqual(
                $0 as? RevivalProjectError,
                .placementHasNoContainingRoom(owner: "Object 6147")
            )
        }
    }

    func testProjectBoundaryValidatesGeometryBeforeContainment() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let base = makeClosedRoomProjectLevel()
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let room = try XCTUnwrap(base.rooms.first { $0.sourceIndex == 3 })
        var source = RevivalProjectSource(base: activation.reference)
        source.roomVertexEdits = [3, 4, 7].map {
            .init(
                roomSourceIndex: room.sourceIndex,
                vertexIndex: $0,
                position: room.vertices[0]
            )
        }

        XCTAssertThrowsError(try RevivalProject(source: source, library: library)) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidFace(room: 3, face: 0)
            )
        }
    }

    func testProjectBoundaryRejectsDeferredTerrainPlacement() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(path: "candidate.revival", directoryHint: .isDirectory)
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory)
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let base = makeGeometryProjectLevel()
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let object = try XCTUnwrap(base.objects.first { $0.handle == 6_147 })
        var source = RevivalProjectSource(base: activation.reference)
        source.objectTransformEdits = [
            .init(
                handle: object.handle,
                location: .terrainCell(0),
                transform: .init(
                    position: object.position,
                    orientation: object.orientation
                )
            ),
        ]

        XCTAssertThrowsError(try RevivalProject(source: source, library: library)) {
            XCTAssertEqual(
                $0 as? RevivalProjectError,
                .placementHasNoContainingRoom(owner: "Object 6147")
            )
        }
    }

    func testReachedPhysicsObjectPlacementUsesCanonicalModelRadius() throws {
        var project = try makeProject(importedBase: makeGeometryProjectLevel())
        let object = try XCTUnwrap(project.level.objects.first { $0.handle == 6_147 })
        let end = Vector3(
            x: object.position.x - 10,
            y: object.position.y,
            z: object.position.z
        )

        XCTAssertThrowsError(try project.moveObject(handle: object.handle, to: end)) {
            guard case .placementBlocked(
                owner: "Object 6147",
                roomSourceIndex: 3,
                faceIndex: _
            ) = $0 as? RevivalProjectError else {
                return XCTFail("Expected the canonical object radius to refuse a near-wall move")
            }
        }
    }
}

private func assertTrainingGalleryBarrierRendering(
    in level: Level,
    rendersFaces: Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let barrier = level.trainingGalleryBarrier!
    let room = level.rooms.first {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    for portalIndex in barrier.orderedPortalIndices {
        let portal = room.portals[portalIndex]
        XCTAssertEqual(
            portal.flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
        let reciprocalRoom = level.rooms.first {
            $0.sourceIndex == portal.connectedRoom
        }!
        XCTAssertEqual(
            reciprocalRoom.portals[portal.connectedPortal].flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
    }
}

private func assertTrainingGuidebotReturnBarrierRendering(
    in level: Level,
    rendersFaces: Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let barrier = level.trainingCameraMonitorChain!.returnToShip!
    let room = level.rooms.first {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    for portalIndex in barrier.orderedPortalIndices {
        let portal = room.portals[portalIndex]
        XCTAssertEqual(
            portal.flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
        let reciprocalRoom = level.rooms.first {
            $0.sourceIndex == portal.connectedRoom
        }!
        XCTAssertEqual(
            reciprocalRoom.portals[portal.connectedPortal].flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
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
        surfacePhysics: base.surfacePhysics + [
            .init(texture: alternateTexture, behavior: .blocking),
        ],
        presentationMaterials: base.presentationMaterials + [alternateMaterial],
        presentationCoronaAssets: base.presentationCoronaAssets,
        models: base.models,
        shipDefinitions: base.shipDefinitions,
        defaultPlayerBinding: base.defaultPlayerBinding,
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

private func makeGeometryProjectLevel() -> Level {
    let base = makeEditableProjectLevel()
    let texture = base.presentationMaterials[0].texture
    let face: ([Int]) -> LevelFace = { indices in
        LevelFace(
            corners: indices.enumerated().map { offset, vertexIndex in
                FaceCorner(
                    vertexIndex: vertexIndex,
                    u: offset == 1 ? 1 : 0,
                    v: offset == 2 ? 1 : 0,
                    alpha: 255
                )
            },
            flags: 0,
            portalIndex: nil,
            texture: texture
        )
    }
    let rooms = [
        LevelRoom(
            sourceIndex: 40,
            vertices: [
                .init(x: 0, y: 0, z: 0),
                .init(x: 2, y: 0, z: 0),
                .init(x: 0, y: 2, z: 0),
            ],
            faces: [face([0, 1, 2])],
            portals: []
        ),
        LevelRoom(
            sourceIndex: 41,
            vertices: [
                .init(x: 0.5, y: 0.25, z: 0),
                .init(x: 2.5, y: 0.25, z: 0),
                .init(x: 0.5, y: 2.25, z: 0),
            ],
            faces: [face([0, 1, 2])],
            portals: []
        ),
    ]
    var objects = base.objects
    for index in objects.indices {
        guard objects[index].handle == 2_048 || objects[index].handle == 6_147 else {
            continue
        }
        objects[index].location = .room(3)
        objects[index].position = RoomCamera.trainingRoom3.position
    }
    var presentations = base.objectPresentations
    if !presentations.contains(where: { $0.objectHandle == 6_147 }),
       let model = base.models.first {
        presentations.append(.init(
            objectHandle: 6_147,
            primaryModel: model.source,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        ))
    }
    return replacing(
        base,
        rooms: base.rooms + rooms,
        objects: objects,
        objectPresentations: presentations
    )
}
