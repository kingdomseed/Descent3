import XCTest

// DALLAS actions (scripts/DallasFuncs.cpp and the multisafe calls they
// make) that no single level script owns: ghosting and the end of the
// level.
final class DallasFuncsTests: XCTestCase {
    /// RenderObject draws no OBJ_DUMMY object (renderobject.cpp:1214). A
    /// ghost keeps its render type, so unghosting shows it again.
    func testGhostedObjectIsNotRenderedAndUnghostingShowsIt() throws {
        let level = makeSliceSixObjectRenderLevel()
        let view = defaultPlayerView(in: level)
        var world = GameWorld(level: level)
        func admitted() throws -> [UInt32] {
            try extractWorldForRendering(
                level, objects: world.objects, roomStates: world.rooms,
                camera: view.camera, startRoomSourceIndex: view.roomSourceIndex,
                excludedObjectHandle: view.objectHandle
            ).admittedObjectHandles
        }
        XCTAssertTrue(try admitted().contains(12_301))
        world.aObjGhostSet(1, ObjectHandle(12_301))
        XCTAssertEqual(world.objects[ObjectHandle(12_301)]?.renderType, .polyobj)
        XCTAssertFalse(try admitted().contains(12_301))
        world.aObjGhostSet(0, ObjectHandle(12_301))
        XCTAssertTrue(try admitted().contains(12_301))
    }

    /// aEndLevel sets GAMESTATE_LVLEND; after the frame the session ends
    /// the level once: the results, the suspended controls, and the level
    /// EVT_LEVELEND. aFailLevel ends it in failure.
    func testEndLevelRequestEndsTheLevelAfterTheFrameOnce() throws {
        let level = makeTrainingCameraMonitorLevel()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        XCTAssertNil(session.update(at: 0.1, input: .zero).levelEnd)
        session.world.aEndLevel()

        let ended = session.update(at: 0.2, input: .init(forward: 1))

        let end = try XCTUnwrap(ended.levelEnd)
        XCTAssertEqual(end.endLevelState, .succeeded)
        XCTAssertEqual(end.postLevelResult.title, "Mission Successful")
        XCTAssertEqual(ended.enabledPlayerControls, [])
        XCTAssertEqual(ended.velocity, .zero)
        XCTAssertEqual(session.levelOutcome, .awaitingResultAcknowledgement)
        let result = session.postLevelResult
        XCTAssertEqual(
            session.update(at: 0.3, input: .zero).levelEnd?.postLevelResult,
            result
        )

        let failing = GameSession(level: level, presentationReadyTimestamp: 0)
        failing.world.aFailLevel()
        let failed = try XCTUnwrap(
            failing.update(at: 0.1, input: .zero).levelEnd
        )
        XCTAssertEqual(failed.endLevelState, .failed)
        XCTAssertEqual(failed.postLevelResult.title, "Mission Failed")
    }
}
