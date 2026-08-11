import AppKit
import CryptoKit
import XCTest

extension EditorProjectTests {
    @MainActor
    func testMovingTargetHandoffExtendsReadOnlySourceDiagnostic()
        throws
    {
        let level = makeTrainingMovingTargetHandoffLevel()
        let project = try makeProject(importedBase: level)

        XCTAssertEqual(
            project.trainingManeuverFollowSourceDiagnostic,
            "TrainingMission.cpp Scripts 021,022,024,023,025,026,031,037,027,028 / ManuverRoomCenter 2063 / FollowBot1 8200 / DestroyBot1 4113 then DestroyBot2 4112 / timer 11 = 2.0s / stock orientation-editable FollowLoop1 path 0 nodes 13 flags 0x801100 + GoToDie path 1 nodes 1 flags 0x1100 / goal -1 priority 3 / Laser Level 2 - Blue via bluelaser.OOF / runtime path failure: invalidPath|movementBlocked"
        )
    }

    @MainActor
    func testManeuverFollowDiagnosticKeepsStockPathsReadOnlyAndSurfacesFailure()
        throws
    {
        let level = makeTrainingManeuverFollowLevel()
        let project = try makeProject(importedBase: level)
        XCTAssertEqual(
            project.trainingManeuverFollowSourceDiagnostic,
            "TrainingMission.cpp Scripts 021,022,024,023,025,026 / ManuverRoomCenter 2063 / FollowBot1 8200 / stock orientation-editable FollowLoop1 path 0 nodes 13 flags 0x900104 + GoToDie path 1 nodes 1 flags 0x1100 / slot 0 priority 3 / runtime path failure: invalidPath|movementBlocked"
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let frame = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(
            project.trainingManeuverFollowRuntimeDiagnostic(
                frame: frame
            ),
            "\(project.trainingManeuverFollowSourceDiagnostic!) / active path none node 0 room 37 failure none"
        )
        let selection = try RevivalEditorSelection(
            roomSourceIndex: 37,
            in: level
        )
        XCTAssertTrue(
            editorIdleStatusMessage(
                project: project,
                selection: selection
            ).contains(
                project.trainingManeuverFollowSourceDiagnostic!
            )
        )
        XCTAssertEqual(
            editorPlayStatusMessage(
                project: project,
                frame: frame
            ),
            "Playing a separately owned complete-level copy. Use W/S to thrust and A/D to slide.\nRuntime: \(project.trainingManeuverFollowRuntimeDiagnostic(frame: frame)!)"
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
            "TrainingMission.cpp Scripts 033,016,017,018,020,019 / StartDodge 4106 / DoneDodgeingGoal 12302 / DodgeTurrett 8199 / FlashLight-1 4120 / PortalRoom2+3 portals 0,1 / intro2.osf+almost.osf+proceed3.osf+proceed4.osf"
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
                "TrainingMission.cpp Scripts 033,016,017,018,020,019 / StartDodge 4106"
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
        for sourceIndex in [49, 36] {
            let boundPortalRoom = try XCTUnwrap(
                document.project.level.rooms.first {
                    $0.sourceIndex == sourceIndex
                }
            )
            XCTAssertEqual(boundPortalRoom.portals.count, 2)
            for portalIndex in [0, 1] {
                XCTAssertNotEqual(
                    boundPortalRoom.portals[portalIndex].flags & 1,
                    0
                )
            }
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
            reopened.project.trainingDodgeAttemptSourceDiagnostic,
            document.project.trainingDodgeAttemptSourceDiagnostic
        )
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
            playSession.level.trainingDodgeAttempt?.dodgeExit,
            reopened.project.level.trainingDodgeAttempt?.dodgeExit
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
    func testFollowLoop1NodeOrientationAuthoringPersistsAndChangesDisposablePlay()
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
        let base = makeTrainingManeuverFollowLevel()
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let installedBaseHash = pathNodeOrientationTestHash(
            try canonicalJSONData(library.load(activation.reference))
        )
        let document = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        XCTAssertEqual(document.project.persistedSource.schemaVersion, 4)
        XCTAssertTrue(
            document.project.persistedSource.pathNodeOrientationEdits.isEmpty
        )

        func descendants(of view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        let controller = RevivalEditorWindowController(document: document)
        document.addWindowController(controller)
        defer {
            document.removeWindowController(controller)
            controller.close()
        }
        let views = descendants(
            of: try XCTUnwrap(controller.window?.contentView)
        )
        let pathPopup = try XCTUnwrap(views.compactMap { $0 as? NSPopUpButton }
            .first { $0.accessibilityLabel() == "Selected game path" })
        let nodePopup = try XCTUnwrap(views.compactMap { $0 as? NSPopUpButton }
            .first { $0.accessibilityLabel() == "Selected path node" })
        let forwardLabel = try XCTUnwrap(views.compactMap { $0 as? NSTextField }
            .first { $0.accessibilityLabel() == "Selected path node forward" })
        let upLabel = try XCTUnwrap(views.compactMap { $0 as? NSTextField }
            .first { $0.accessibilityLabel() == "Selected path node up" })
        let orientButton = try XCTUnwrap(views.compactMap { $0 as? NSButton }
            .first { $0.title == "Orient Node to Editor View" })
        XCTAssertEqual(pathPopup.selectedItem?.representedObject as? Int, 0)
        XCTAssertEqual(pathPopup.titleOfSelectedItem, "FollowLoop1 — Path 0")
        XCTAssertEqual(nodePopup.selectedItem?.representedObject as? Int, 1)
        let baseNode = base.paths[0].nodes[1]
        XCTAssertEqual(
            forwardLabel.stringValue,
            "Forward: (\(baseNode.forward.x), \(baseNode.forward.y), \(baseNode.forward.z))"
        )
        XCTAssertEqual(
            upLabel.stringValue,
            "Up: (\(baseNode.up.x), \(baseNode.up.y), \(baseNode.up.z))"
        )
        XCTAssertEqual(forwardLabel.maximumNumberOfLines, 0)
        XCTAssertEqual(forwardLabel.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(upLabel.maximumNumberOfLines, 0)
        XCTAssertEqual(upLabel.lineBreakMode, .byWordWrapping)
        pathPopup.selectItem(at: 1)
        pathPopup.sendAction(pathPopup.action, to: pathPopup.target)
        XCTAssertEqual(pathPopup.titleOfSelectedItem, "GoToDie — Path 1")
        XCTAssertFalse(orientButton.isEnabled)
        pathPopup.selectItem(at: 0)
        pathPopup.sendAction(pathPopup.action, to: pathPopup.target)
        nodePopup.selectItem(at: 1)
        nodePopup.sendAction(nodePopup.action, to: nodePopup.target)
        XCTAssertTrue(orientButton.isEnabled)

        orientButton.performClick(nil)
        let viewOrientation = sourceOrientation(
            forward: document.camera.target - document.camera.position,
            up: document.camera.up
        )
        var authored = base
        replacePathNodeOrientationForTest(
            in: &authored,
            pathIndex: 0,
            nodeIndex: 1,
            forward: viewOrientation.forward,
            up: viewOrientation.up
        )
        XCTAssertEqual(document.project.level, authored)
        XCTAssertEqual(forwardLabel.stringValue, "Forward: (0.0, 1.0, 0.0)")
        XCTAssertEqual(upLabel.stringValue, "Up: (0.0, -0.0, 1.0)")
        XCTAssertEqual(document.undoManager?.undoActionName, "Orient Path Node")
        XCTAssertEqual(
            pathNodeOrientationTestHash(
                try canonicalJSONData(library.load(activation.reference))
            ),
            installedBaseHash
        )

        document.undoManager?.undo()
        XCTAssertEqual(document.project.level, base)
        XCTAssertTrue(
            document.project.persistedSource.pathNodeOrientationEdits.isEmpty
        )
        XCTAssertEqual(document.undoManager?.redoActionName, "Orient Path Node")
        document.undoManager?.redo()
        XCTAssertEqual(document.project.level, authored)

        let wrapper = try document.fileWrapper(
            ofType: RevivalProjectDocument.projectType
        )
        let projectJSON = try XCTUnwrap(
            wrapper.fileWrappers?["project.json"]?.regularFileContents
        )
        let savedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: projectJSON) as? [String: Any]
        )
        XCTAssertEqual(savedObject["schemaVersion"] as? Int, 4)
        let savedDeltas = try XCTUnwrap(
            savedObject["pathNodeOrientationEdits"] as? [[String: Any]]
        )
        XCTAssertEqual(savedDeltas.count, 1)
        XCTAssertEqual(savedDeltas[0]["pathIndex"] as? Int, 0)
        XCTAssertEqual(savedDeltas[0]["nodeIndex"] as? Int, 1)

        let reopened = RevivalProjectDocument(
            project: try RevivalProject(activatedBase: activation),
            library: library
        )
        try reopened.read(
            from: wrapper,
            ofType: RevivalProjectDocument.projectType
        )
        XCTAssertEqual(reopened.project.level, authored)
        XCTAssertEqual(
            reopened.project.persistedSource.pathNodeOrientationEdits.count,
            1
        )

        let session = reopened.makePlaySession()
        XCTAssertEqual(session.level, authored)
        reopened.commitPlaySession(session, renderingWorld: false)
        XCTAssertEqual(reopened.playSession?.level, authored)
        let lesson = try XCTUnwrap(
            session.level.trainingDodgeAttempt?.maneuverFollow
        )
        XCTAssertEqual(lesson.followPathGoalFlags, 0x900104)
        let runtimeLevel = try makePathNodeOrientationRuntimeLevel(
            session.level
        )
        let baseRuntimeLevel = try makePathNodeOrientationRuntimeLevel(base)
        let simulation = try makeScript021ReadySimulation(level: runtimeLevel)
        let script021 = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(script021.trainingFollowBot?.script021Count, 1)
        _ = simulation.update(at: 20.1, input: .zero)
        let script022 = simulation.update(at: 20.2, input: .zero)
        XCTAssertEqual(script022.trainingFollowBot?.script022Count, 1)
        _ = simulation.update(at: 32.2, input: .zero)
        let script024 = simulation.update(at: 32.3, input: .zero)
        XCTAssertEqual(script024.trainingFollowBot?.script024Count, 1)
        _ = simulation.update(at: 47.3, input: .zero)
        let script023 = simulation.update(at: 47.4, input: .zero)
        XCTAssertEqual(script023.trainingFollowBot?.script023Count, 1)
        XCTAssertEqual(
            script023.trainingFollowBot?.activePathIndex,
            lesson.followPathIndex
        )
        XCTAssertEqual(
            script023.trainingFollowBot?.teamFlags,
            lesson.friendlyTeamFlags
        )

        let node0 = authored.paths[0].nodes[0]
        let node1 = authored.paths[0].nodes[1]
        let midpoint = (node0.position + node1.position) * 0.5
        let node0Orientation = sourceOrientation(
            forward: node0.forward,
            up: node0.up
        )
        var midpointObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        midpointObject["frameDuration"] = 0.1
        var midpointState = try XCTUnwrap(
            midpointObject["trainingManeuverFollowState"] as? [String: Any]
        )
        midpointState["position"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(midpoint)
        )
        midpointState["orientation"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(node0Orientation)
        )
        midpointState["velocity"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(Vector3.zero)
        )
        midpointState["activePathIndex"] = 0
        midpointState["pathNodeIndex"] = 1
        midpointObject["trainingManeuverFollowState"] = midpointState
        let midpointContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: midpointObject)
        )
        let editedInterpolation = try PlayerSimulation(
            level: runtimeLevel,
            continuation: midpointContinuation,
            resumedAtTimestamp: 47.4
        )
        let baseInterpolation = try PlayerSimulation(
            level: baseRuntimeLevel,
            continuation: midpointContinuation,
            resumedAtTimestamp: 47.4
        )
        let editedFrame = editedInterpolation.update(
            at: 47.5,
            input: .zero
        )
        let baseFrame = baseInterpolation.update(at: 47.5, input: .zero)
        XCTAssertEqual(editedFrame.trainingFollowBot?.pathNodeIndex, 1)
        XCTAssertEqual(
            editedFrame.trainingFollowBot?.position,
            baseFrame.trainingFollowBot?.position
        )
        XCTAssertNotEqual(
            editedFrame.trainingFollowBot?.orientation,
            baseFrame.trainingFollowBot?.orientation
        )
        XCTAssertGreaterThan(
            dot(
                try XCTUnwrap(
                    editedFrame.trainingFollowBot?.orientation.forward
                ),
                node1.forward
            ),
            dot(
                try XCTUnwrap(
                    baseFrame.trainingFollowBot?.orientation.forward
                ),
                node1.forward
            )
        )

        let editedPlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: editedInterpolation.level,
                playerView: editedFrame.playerView
            ),
            level: editedInterpolation.level,
            frame: editedFrame,
            drawableAspect: 1
        )
        let basePlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: baseInterpolation.level,
                playerView: baseFrame.playerView
            ),
            level: baseInterpolation.level,
            frame: baseFrame,
            drawableAspect: 1
        )
        let editedDraw = try XCTUnwrap(editedPlan.draws.first {
            $0.objectHandle == lesson.followBotObjectHandle
        })
        let baseDraw = try XCTUnwrap(basePlan.draws.first {
            $0.objectHandle == lesson.followBotObjectHandle
        })
        XCTAssertEqual(editedDraw.model, baseDraw.model)
        XCTAssertNotEqual(editedDraw.vertices, baseDraw.vertices)

        let savedContinuation = editedInterpolation.continuation
        XCTAssertEqual(savedContinuation.schemaVersion, 7)
        let restored = try PlayerSimulation(
            level: runtimeLevel,
            continuation: savedContinuation,
            resumedAtTimestamp: 47.5
        )
        let liveNext = editedInterpolation.update(at: 47.6, input: .zero)
        let restoredNext = restored.update(at: 47.6, input: .zero)
        XCTAssertEqual(
            restoredNext.trainingFollowBot?.position,
            liveNext.trainingFollowBot?.position
        )
        XCTAssertEqual(
            restoredNext.trainingFollowBot?.orientation,
            liveNext.trainingFollowBot?.orientation
        )
        XCTAssertEqual(
            restoredNext.trainingFollowBot?.pathNodeIndex,
            liveNext.trainingFollowBot?.pathNodeIndex
        )
        XCTAssertEqual(
            restoredNext.trainingOpeningFeedback,
            liveNext.trainingOpeningFeedback
        )
        XCTAssertTrue(restoredNext.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            restored.continuation.authoritativeRandomState,
            editedInterpolation.continuation.authoritativeRandomState
        )

        reopened.returnToEditor(renderingWorld: false)
        XCTAssertNil(reopened.playSession)
        XCTAssertEqual(reopened.project.level, authored)
        XCTAssertEqual(
            pathNodeOrientationTestHash(
                try canonicalJSONData(library.load(activation.reference))
            ),
            installedBaseHash
        )
    }

    func testPathNodeOrientationProjectBoundaryRejectsHostileDeltas()
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
        let base = makeTrainingManeuverFollowLevel()
        try writeCanonicalPackage(base, to: candidate)
        let activation = try library.installAndActivate(from: candidate)
        let validA = RevivalPathNodeOrientationEdit(
            pathIndex: 0,
            nodeIndex: 1,
            forward: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let validB = RevivalPathNodeOrientationEdit(
            pathIndex: 0,
            nodeIndex: 2,
            forward: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let cases: [[RevivalPathNodeOrientationEdit]] = [
            [.init(
                pathIndex: 1,
                nodeIndex: 0,
                forward: validA.forward,
                up: validA.up
            )],
            [.init(
                pathIndex: 99,
                nodeIndex: 0,
                forward: validA.forward,
                up: validA.up
            )],
            [.init(
                pathIndex: 0,
                nodeIndex: 99,
                forward: validA.forward,
                up: validA.up
            )],
            [validA, .init(
                pathIndex: validA.pathIndex,
                nodeIndex: validA.nodeIndex,
                forward: validB.forward,
                up: validB.up
            )],
            [validB, validA],
            [.init(
                pathIndex: 0,
                nodeIndex: 1,
                forward: .init(x: .infinity, y: 0, z: 0),
                up: validA.up
            )],
            [.init(
                pathIndex: 0,
                nodeIndex: 1,
                forward: .zero,
                up: validA.up
            )],
            [.init(
                pathIndex: 0,
                nodeIndex: 1,
                forward: .init(x: 1, y: 0, z: 0),
                up: .init(x: 2, y: 0, z: 0)
            )],
            [.init(
                pathIndex: 0,
                nodeIndex: 1,
                forward: base.paths[0].nodes[1].forward,
                up: base.paths[0].nodes[1].up
            )],
        ]
        for edits in cases {
            var source = RevivalProjectSource(base: activation.reference)
            source.pathNodeOrientationEdits = edits
            XCTAssertThrowsError(
                try RevivalProject(source: source, library: library)
            ) {
                XCTAssertNotNil($0 as? RevivalProjectError)
            }
        }
    }
}

private func makePathNodeOrientationRuntimeLevel(
    _ source: Level
) throws -> Level {
    var level = source
    let lesson = try XCTUnwrap(level.trainingDodgeAttempt?.maneuverFollow)
    let maneuver = try XCTUnwrap(level.objects.first {
        $0.handle == lesson.maneuverObjectHandle
    })
    let playerIndex = try XCTUnwrap(level.objects.firstIndex {
        $0.handle == level.defaultPlayerBinding?.objectHandle
    })
    level.objects[playerIndex].location = maneuver.location
    level.objects[playerIndex].position = maneuver.position
    level.objects[playerIndex].orientation = maneuver.orientation
    let roomIndex = try XCTUnwrap(level.rooms.firstIndex {
        $0.sourceIndex == 37
    })
    let originalRoom = level.rooms[roomIndex]
    let containmentRoom = makeSourceContainmentRoom(
        center: maneuver.position,
        texture: level.surfacePhysics[0].texture,
        sourceIndex: originalRoom.sourceIndex,
        halfExtent: 500
    )
    var containmentFaces = containmentRoom.faces
    let containmentPortals = originalRoom.portals.enumerated().map {
        portalIndex,
        portal in
        let face = containmentFaces[portalIndex]
        containmentFaces[portalIndex] = .init(
            corners: face.corners,
            flags: face.flags,
            portalIndex: portalIndex,
            texture: face.texture,
            lightmapInfoIndex: face.lightmapInfoIndex,
            allowsLightCorona: face.allowsLightCorona,
            lightMultiple: face.lightMultiple,
            special: face.special
        )
        return LevelPortal(
            flags: portal.flags,
            faceIndex: portalIndex,
            connectedRoom: portal.connectedRoom,
            connectedPortal: portal.connectedPortal,
            boundaryNodeIndex: portal.boundaryNodeIndex,
            pathPoint: portal.pathPoint,
            combineMaster: portal.combineMaster
        )
    }
    level.rooms[roomIndex] = replacing(
        originalRoom,
        vertices: containmentRoom.vertices,
        faces: containmentFaces,
        portals: containmentPortals
    )
    // The full Training package uses this existing carrier for schema 7.
    let schemaSevenCarrier = makeTrainingRASBot1DeathLevel()
    let rasBot = try XCTUnwrap(schemaSevenCarrier.objects.first {
        $0.handle == 2_074
    })
    let rasPresentation = try XCTUnwrap(
        schemaSevenCarrier.objectPresentations.first {
            $0.objectHandle == rasBot.handle
        }
    )
    if !level.models.contains(where: {
        $0.source == rasPresentation.primaryModel
    }) {
        level = replacing(
            level,
            models: level.models + [try XCTUnwrap(
                schemaSevenCarrier.models.first {
                    $0.source == rasPresentation.primaryModel
                }
            )]
        )
    }
    level.objects.append(rasBot)
    level.objectPresentations.append(rasPresentation)
    level = level.addingTrainingRASBot1DeathChain(
        try XCTUnwrap(schemaSevenCarrier.trainingRASBot1DeathChain)
    )
    level = replacing(
        level,
        trainingDodgeAttempt: source.trainingDodgeAttempt
    )
    return level
}

private func makeScript021ReadySimulation(
    level: Level
) throws -> PlayerSimulation {
    let seed = PlayerSimulation(level: level, presentationReadyTimestamp: 0)
    var object = try XCTUnwrap(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(seed.continuation)
        ) as? [String: Any]
    )
    var dodge = try XCTUnwrap(
        object["trainingDodgeAttemptState"] as? [String: Any]
    )
    dodge["script033Count"] = 1
    dodge["script016Count"] = 1
    dodge["script017Count"] = 1
    dodge["script018Count"] = 0
    dodge["script020Count"] = 1
    dodge["triggerTimerRemaining"] = nil
    dodge["successTimerRemaining"] = nil
    dodge["almostDoneTimerRemaining"] = nil
    dodge["turretIsPowered"] = false
    dodge["markerLightDistance"] = 50
    object["trainingDodgeAttemptState"] = dodge
    var opening = try XCTUnwrap(
        object["trainingOpeningState"] as? [String: Any]
    )
    opening["enabledControls"] = 63
    opening["timerRemaining"] = Float(1_000)
    opening["welcomeWasPresented"] = false
    object["trainingOpeningState"] = opening
    return try PlayerSimulation(
        level: level,
        continuation: JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: object)
        ),
        resumedAtTimestamp: 0
    )
}

private func replacePathNodeOrientationForTest(
    in level: inout Level,
    pathIndex: Int,
    nodeIndex: Int,
    forward: Vector3,
    up: Vector3
) {
    let path = level.paths[pathIndex]
    let node = path.nodes[nodeIndex]
    var nodes = path.nodes
    nodes[nodeIndex] = .init(
        position: node.position,
        location: node.location,
        flags: node.flags,
        forward: forward,
        up: up
    )
    level.paths[pathIndex] = .init(
        name: path.name,
        flags: path.flags,
        nodes: nodes
    )
}

private func pathNodeOrientationTestHash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
