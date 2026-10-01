import XCTest

// The popup views (Descent3/SmallViews.cpp): the saved view they cover,
// the viewer's gun point and room, and the AI's sight of the player
// through them.
final class SmallViewsTests: XCTestCase {
    /// The cloak level with no level module.
    private func pickupWorld() -> (GameWorld, Level) {
        let level = makeTrainingCloakPickupLevel()
        return (GameWorld(level: level), level)
    }

    /// The small views render after the main view (DrawSmallViews calls
    /// GameRenderWorld, SmallViews.cpp:332), so their AI objects join
    /// AI_RenderedList (renderobject.cpp:1239), and the next AIFrameAll tells them the player sees them
    /// (AImain.cpp:6225). A robot behind the player is seen only through a
    /// popup view that looks back.
    func testARobotSeenOnlyThroughThePopupViewHearsThePlayerSeesIt()
        throws
    {
        func session(popup: Bool) throws -> (GameSession, ObjectHandle) {
            let level = try dodgeLevelWithRoomyPlayerRoom()
            let session = GameSession(level: level, presentationReadyTimestamp: 0)
            let turret = level.findObjectName("DodgeTurrett")
            session.world.aAISetState(1, turret)
            let player = session.world.testPlayerObject
            var object = try XCTUnwrap(session.world.objects[turret])
            object.location = player.location
            object.position = player.position - player.orientation.forward * 30
            session.world.objects[turret] = object
            if popup {
                let viewer = try XCTUnwrap(session.world.objects.first {
                    $0.type == .powerup
                }).handle
                session.world.objects[viewer]?.location = player.location
                session.world.objects[viewer]?.position = player.position
                session.world.objects[viewer]?.orientation = .init(
                    right: player.orientation.right * -1,
                    up: player.orientation.up,
                    forward: player.orientation.forward * -1
                )
                session.world.aCreatePopupView(-1, viewer, 10, 1)
            }
            return (session, turret)
        }

        // A robot in both views joins the list for each view: each
        // GameRenderWorld marks its rooms' objects OF_SAFE_TO_RENDER again
        // (render.cpp:1126).
        let (both, bothTurret) = try session(popup: true)
        let bothPlayer = both.world.testPlayerObject
        both.world.objects[bothTurret]?.position =
            bothPlayer.position + bothPlayer.orientation.forward * 30
        let bothViewer = try XCTUnwrap(both.world.smallViews.first?.viewer)
        both.world.objects[bothViewer]?.orientation = bothPlayer.orientation
        _ = both.update(at: 0.1, input: .zero)
        XCTAssertEqual(both.world.aiRenderedList, [bothTurret, bothTurret])

        let (unseen, unseenTurret) = try session(popup: false)
        _ = unseen.update(at: 0.1, input: .zero)
        XCTAssertFalse(unseen.world.aiRenderedList.contains(unseenTurret))

        let (seen, turret) = try session(popup: true)
        _ = seen.update(at: 0.1, input: .zero)
        XCTAssertEqual(seen.world.aiRenderedList, [turret])
        XCTAssertEqual(seen.world.objects[turret]?.ai?.lastRenderTime, -1)
        let gameTime = seen.world.gameTime
        _ = seen.update(at: 0.2, input: .zero)
        XCTAssertEqual(seen.world.objects[turret]?.ai?.lastRenderTime, gameTime)
    }

    /// A popup over a non-popup view saves it, and closing the popup brings
    /// it back (SmallViews.cpp:223, :542); ClosePopupView leaves a
    /// non-popup view (:566). A time of 0 keeps a window up.
    func testPopupViewSavesAndRestoresTheViewItCovers() {
        var (world, _) = pickupWorld()
        let viewer = ObjectHandle(2_074)
        world.createSmallView(window: 0, viewer: viewer, flags: 0, time: 0,
                              zoom: SmallView.defaultZoom, gun: -1)
        world.closePopupView()
        XCTAssertTrue(world.smallViews[0].isActive)
        world.smallViewsRenderFrame(frameTime: 10)
        XCTAssertTrue(world.smallViews[0].isActive)

        world.aCreatePopupView(-1, ObjectHandle(2_075), 1, 1)
        XCTAssertEqual(world.smallViews[0].viewer, ObjectHandle(2_075))
        XCTAssertEqual(world.savedSmallViews[0].viewer, viewer)

        world.aClosePopupView()
        XCTAssertEqual(world.smallViews[0].viewer, viewer)
        XCTAssertFalse(world.savedSmallViews[0].isActive)

        // A stale viewer opens nothing.
        XCTAssertEqual(
            world.createSmallView(window: 0, viewer: .none, flags: 1,
                                  time: 1, zoom: 1, gun: -1),
            -1
        )
    }

    /// aCreatePopupView's gun view (SmallViews.cpp:490-497): the camera is
    /// the gun point looking along the gun's normal, in the room
    /// GetGunRoom traces from the viewer to the gun point.
    func testPopupViewLooksFromTheViewersGunInTheTracedRoom() throws {
        var level = makeTrainingCameraMonitorLevel()
        let model = try XCTUnwrap(level.models.first {
            $0.source.sourceName == "monitor.OOF"
        }).source
        level.objectPresentations.append(.fixture(6_183, model))
        level = level.settingModelGuns(
            model,
            gunpoints: [.init(
                parent: 0, position: .init(x: 0, y: 1, z: 2),
                normal: .init(x: 0, y: 0, z: 1)
            )],
            batteries: []
        )
        var world = GameWorld(level: level)
        let camera = ObjectHandle(6_183)
        world.aCreatePopupView(0, camera, 10, 2)
        let object = try XCTUnwrap(world.objects[camera])
        let gun = world.weaponCalcGun(
            object, gunpoint: 0,
            model: try XCTUnwrap(level.placedObjectModel(camera))
        )
        guard case let .room(room) = object.location else {
            return XCTFail("The camera is indoor")
        }

        let frame = try XCTUnwrap(world.smallViewFrames(level: level).first)

        XCTAssertEqual(world.smallViews[0].zoom, SmallView.defaultZoom / 2)
        XCTAssertEqual(frame.camera.position, gun.point)
        XCTAssertEqual(
            frame.camera.target, gun.point + sourceVectorNormalized(gun.normal)
        )
        XCTAssertEqual(
            frame.roomSourceIndex,
            traceIndoorMovement(
                in: level, roomStates: world.rooms, startRoom: room,
                start: object.position, end: gun.point, radius: 0
            ).containingRoomSourceIndex
        )
        XCTAssertLessThan(
            frame.camera.projection.horizontalFieldOfViewRadians,
            PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
        )
        // A gone viewer shows static for STATIC_TIME, then the window
        // closes (DrawSmallViews, :427-438).
        world.objects.delete(camera)
        world.smallViewsRenderFrame(frameTime: 0.1)
        XCTAssertNotEqual(
            world.smallViews[0].flags & SmallView.Flag.staticPicture, 0
        )
        XCTAssertTrue(world.smallViewFrames(level: level).isEmpty)
        world.smallViewsRenderFrame(frameTime: 0.1)
        world.smallViewsRenderFrame(frameTime: 0.1)
        XCTAssertFalse(world.smallViews[0].isActive)
    }
}
