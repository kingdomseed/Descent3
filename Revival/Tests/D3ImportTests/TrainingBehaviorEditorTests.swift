import AppKit
import CryptoKit
import XCTest

extension EditorProjectTests {
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
            rootURL: root.appending(path: "library", directoryHint: .isDirectory),
            schemaPolicy: .includingScriptFreeTestSchemas
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        let immutableBase = makeTrainingDodgeAttemptLevel()
        try writeCanonicalPackage(immutableBase, to: candidate, schemaPolicy: .includingScriptFreeTestSchemas)
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
        // The object tables come from the package unchanged.
        XCTAssertEqual(
            document.project.level.objectInfos,
            immutableBase.objectInfos
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
        // The Training module finds its goals by name in the play level.
        for (name, goal) in [
            ("StartGoal", startGoal), ("LeftGoal", leftGoal),
            ("UpGoal", upGoal), ("ForwardGoal", forwardGoal),
            ("FinishCourse", finishCourse),
        ] {
            XCTAssertEqual(
                playSession.level.findObjectName(name),
                ObjectHandle(goal.handle),
                name
            )
        }
        XCTAssertEqual(
            playSession.level.objectInfos,
            reopened.project.level.objectInfos
        )
        XCTAssertEqual(
            playSession.level.weapons,
            reopened.project.level.weapons
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
    func testPathNodeOrientationAuthoringPersistsAndChangesDisposablePlay()
        throws
    {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let candidate = root.appending(
            path: "candidate.revival",
            directoryHint: .isDirectory
        )
        let library = CanonicalPackageLibrary(
            rootURL: root.appending(path: "library", directoryHint: .isDirectory),
            schemaPolicy: .includingScriptFreeTestSchemas
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        let base = makeTrainingManeuverFollowLevel()
        try writeCanonicalPackage(base, to: candidate, schemaPolicy: .includingScriptFreeTestSchemas)
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
        // Any game path's nodes can be oriented.
        pathPopup.selectItem(at: 1)
        pathPopup.sendAction(pathPopup.action, to: pathPopup.target)
        XCTAssertEqual(pathPopup.titleOfSelectedItem, "GoToDie — Path 1")
        XCTAssertTrue(orientButton.isEnabled)
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
        let followBot = session.level.findObjectName("FollowBot1")
        let runtimeLevel = try makePathNodeOrientationRuntimeLevel(
            session.level
        )
        let baseRuntimeLevel = try makePathNodeOrientationRuntimeLevel(base)
        let simulation = try makeScript021ReadySimulation(level: runtimeLevel)
        // Scripts 021, 022, 024, and 023 through level timer 4
        // (TrainingMission.cpp:1515-1556, :1943-1966).
        simulation.collidePlayer(with: "ManuverRoomCenter")
        _ = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(simulation.world.testTrainingMission?.script021Count, 1)
        // Osiris_ProcessTimers reads the Gametime before the frame, so each
        // timer fires on the frame after the one that passes its end.
        _ = simulation.update(at: 20.1, input: .zero)
        _ = simulation.update(at: 20.2, input: .zero)
        XCTAssertEqual(simulation.world.testTrainingMission?.script022Count, 1)
        _ = simulation.update(at: 32.2, input: .zero)
        _ = simulation.update(at: 32.3, input: .zero)
        XCTAssertEqual(simulation.world.testTrainingMission?.script024Count, 1)
        _ = simulation.update(at: 47.3, input: .zero)
        _ = simulation.update(at: 47.4, input: .zero)
        XCTAssertEqual(simulation.world.testTrainingMission?.script023Count, 1)
        let followAI = try XCTUnwrap(simulation.world.objects[followBot]?.ai)
        XCTAssertEqual(followAI.goals[3].type, AIGoal.followPathType)
        XCTAssertEqual(followAI.goals[3].pathID, 0)
        XCTAssertEqual(followAI.goals[3].flags, 0x900104)
        XCTAssertEqual(
            followAI.flags & ObjectAIFrame.teamMask,
            ObjectAIFrame.teamRebel
        )

        // The follow bot halfway between nodes 0 and 1, heading for node 1,
        // turns toward the blend of the nodes' orientations
        // (AIDoOrient, GF_ORIENT_PATH_NODE, AImain.cpp:4421-4457).
        let node0 = authored.paths[0].nodes[0]
        let node1 = authored.paths[0].nodes[1]
        let midpoint = (node0.position + node1.position) * 0.5
        var midpointWorld = simulation.world
        var bot = try XCTUnwrap(midpointWorld.objects[followBot])
        bot.position = midpoint
        bot.orientation = sourceOrientation(
            forward: node0.forward,
            up: node0.up
        )
        bot.velocity = .zero
        bot.ai?.path.currentNode = 1
        bot.ai?.goals[3].staticPathCurrentNode = 1
        midpointWorld.objects[followBot] = bot
        let editedInterpolation = try GameSession(
            level: runtimeLevel,
            world: midpointWorld,
            resumedAtTimestamp: 47.1
        )
        let baseInterpolation = try GameSession(
            level: baseRuntimeLevel,
            world: midpointWorld,
            resumedAtTimestamp: 47.1
        )
        let editedFrame = editedInterpolation.update(at: 47.2, input: .zero)
        let baseFrame = baseInterpolation.update(at: 47.2, input: .zero)
        let editedBot = try XCTUnwrap(editedInterpolation.world.objects[followBot])
        let baseBot = try XCTUnwrap(baseInterpolation.world.objects[followBot])
        XCTAssertEqual(editedBot.ai?.path.currentNode, 1)
        XCTAssertEqual(editedBot.position, baseBot.position)
        XCTAssertNotEqual(editedBot.orientation, baseBot.orientation)
        XCTAssertGreaterThan(
            dot(editedBot.orientation.forward, node1.forward),
            dot(baseBot.orientation.forward, node1.forward)
        )

        let editedPlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: editedInterpolation.runtimeLevel,
                playerView: editedFrame.playerView
            ),
            level: editedInterpolation.level,
            world: editedInterpolation.world,
            frame: editedFrame,
            drawableAspect: 1
        )
        let basePlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: baseInterpolation.runtimeLevel,
                playerView: baseFrame.playerView
            ),
            level: baseInterpolation.level,
            world: baseInterpolation.world,
            frame: baseFrame,
            drawableAspect: 1
        )
        let editedDraw = try XCTUnwrap(editedPlan.draws.first {
            $0.objectHandle == followBot.rawValue
        })
        let baseDraw = try XCTUnwrap(basePlan.draws.first {
            $0.objectHandle == followBot.rawValue
        })
        XCTAssertEqual(editedDraw.model, baseDraw.model)
        XCTAssertNotEqual(editedDraw.vertices, baseDraw.vertices)

        let savedContinuation = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(editedInterpolation.world)
        )
        let restored = try GameSession(
            level: runtimeLevel,
            world: savedContinuation,
            resumedAtTimestamp: 47.2
        )
        let liveNext = editedInterpolation.update(at: 47.3, input: .zero)
        let restoredNext = restored.update(at: 47.3, input: .zero)
        XCTAssertEqual(restored.world, editedInterpolation.world)
        XCTAssertEqual(
            restoredNext.presentationFeedback,
            liveNext.presentationFeedback
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
            rootURL: root.appending(path: "library", directoryHint: .isDirectory),
            schemaPolicy: .includingScriptFreeTestSchemas
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        let base = makeTrainingManeuverFollowLevel()
        try writeCanonicalPackage(base, to: candidate, schemaPolicy: .includingScriptFreeTestSchemas)
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
    let maneuver = try XCTUnwrap(level.objects.first {
        $0.handle == level.findObjectName("ManuverRoomCenter").rawValue
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
    return level
}

/// A session past the dodge (Scripts 033, 016, 017, and 020 ran) with no
/// pending timer, the six slide controls on, and the turret off.
private func makeScript021ReadySimulation(
    level: Level
) throws -> GameSession {
    let seed = GameSession(level: level, presentationReadyTimestamp: 0)
    var object = try XCTUnwrap(testWorldObject(seed.world))
    for name in ["script033Count", "script016Count", "script017Count",
                 "script020Count"] {
        try setTrainingCounter(&object, name, 1)
    }
    object["playerControllerBitflags"] = 63
    try deferringOsirisTimers(&object, to: 1_000)
    return try GameSession(
        level: level,
        world: decodeTestWorld(object),
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
