import XCTest

/// CheckTrigger (Descent3/trigger.cpp:185) and ObjCheckTriggers
/// (object.cpp:2584): which object, event, and trigger state reach the
/// trigger's script. The level module is the one the fixture loads; the
/// rules are the engine's.
final class TriggerTests: XCTestCase {
    private func session() throws -> (GameSession, trigger: Int) {
        let level = makeScriptedTrainingGalleryLevel()
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let trigger = try XCTUnwrap(level.triggers.firstIndex {
            $0.name == "Portal2"
        })
        return (session, trigger)
    }

    private func check(
        _ session: GameSession, _ trigger: Int, object: ObjectHandle,
        _ type: TriggerEventType
    ) {
        let info = session.level.triggers[trigger]
        session.world.checkTrigger(
            room: info.roomIndex, face: info.faceIndex, object: object,
            eventType: type, level: session.level
        )
    }

    private func fired(_ session: GameSession) -> Bool {
        session.world.testTrainingMission?.script032Count == 1
    }

    /// A portal trigger fires only on a pass-through (trigger.cpp:208).
    func testAPortalTriggerIgnoresACollide() throws {
        let (simulation, trigger) = try session()
        let player = simulation.world.testPlayerObject.handle
        check(simulation, trigger, object: player, .collide)
        XCTAssertFalse(fired(simulation))
        XCTAssertEqual(simulation.world.triggerFlags[trigger] & TriggerFlag.dead, 0)
    }

    /// The object must be one of the trigger's activators
    /// (trigger.cpp:211-240): Portal2 takes the player (AF_PLAYER), not a
    /// robot.
    func testOnlyAnActivatorFiresTheTrigger() throws {
        let (simulation, trigger) = try session()
        XCTAssertEqual(
            simulation.level.triggers[trigger].activator,
            TriggerActivator.player
        )
        simulation.world.objGhost(simulation.world.buddyHandle, false)
        check(simulation, trigger, object: simulation.world.buddyHandle,
              .passThrough)
        XCTAssertFalse(fired(simulation))
        check(simulation, trigger,
              object: simulation.world.testPlayerObject.handle,
              .passThrough)
        XCTAssertTrue(fired(simulation))
    }

    /// A disabled trigger does nothing (trigger.cpp:204); a one-shot
    /// trigger dies when it fires, and a dead one does nothing
    /// (:244-248).
    func testDisabledAndDeadTriggersDoNothing() throws {
        let (simulation, trigger) = try session()
        let player = simulation.world.testPlayerObject.handle
        simulation.world.triggerFlags[trigger] |= TriggerFlag.disabled
        check(simulation, trigger, object: player, .passThrough)
        XCTAssertFalse(fired(simulation))
        simulation.world.triggerFlags[trigger] &= ~TriggerFlag.disabled
        XCTAssertNotEqual(
            simulation.level.triggers[trigger].flags & TriggerFlag.oneShot, 0
        )
        check(simulation, trigger, object: player, .passThrough)
        XCTAssertTrue(fired(simulation))
        XCTAssertNotEqual(
            simulation.world.triggerFlags[trigger] & TriggerFlag.dead, 0
        )
        simulation.world.trainingMission.script032Count = 0
        check(simulation, trigger, object: player, .passThrough)
        XCTAssertFalse(fired(simulation))
    }

    /// A trigger without TF_ONESHOT stays live after it fires.
    func testATriggerThatIsNotOneShotStaysLive() throws {
        let (simulation, trigger) = try session()
        simulation.world.triggerFlags[trigger] &= ~TriggerFlag.oneShot
        check(simulation, trigger,
              object: simulation.world.testPlayerObject.handle,
              .passThrough)
        XCTAssertTrue(fired(simulation))
        XCTAssertEqual(simulation.world.triggerFlags[trigger] & TriggerFlag.dead, 0)
    }

    /// A saved world must hold one flags value per level trigger
    /// (SGSTriggers, gamesave.cpp:951).
    func testTheSaveValidatesTheTriggerFlags() throws {
        let (simulation, _) = try session()
        var world = simulation.world
        world.triggerFlags.removeLast()
        XCTAssertThrowsError(try world.validate(against: simulation.level)) {
            XCTAssertEqual(
                $0 as? GameWorldValidationError,
                .unexpectedState("triggerFlags")
            )
        }
    }

    /// do_physics_sim keeps the wiggle move's recorded faces only when the
    /// wiggle hits nothing (physics.cpp:809); otherwise the main move
    /// starts a new record list (FQ_NEW_RECORD_LIST, :986). Here the ship
    /// rests in room 2 under Portal2 (room 2's +y face, a portal to room
    /// 3); its first wiggle goes up through Portal2 and hits room 3's far
    /// wall, so the ship does not move and the trigger does not fire.
    func testADiscardedWiggleRecordsNoTriggerFace() throws {
        let base = makeScriptedTrainingGalleryLevel()
        let texture = try XCTUnwrap(base.surfacePhysics.first {
            $0.behavior == .blocking
        }?.texture)
        let start = Vector3(x: 0, y: 0, z: 0)
        let above = Vector3(x: 0, y: 200, z: 0)
        let far = Vector3(x: 2_000, y: 0, z: 0)
        func portalFace(_ face: LevelFace, trigger: Bool) -> LevelFace {
            .init(
                corners: face.corners,
                flags: face.flags | (trigger ? LevelFace.hasTriggerFlag : 0),
                portalIndex: 0, texture: face.texture
            )
        }

        let box2 = makeSourceContainmentRoom(
            center: start, texture: texture, sourceIndex: 2, halfExtent: 100
        )
        let room2 = LevelRoom(
            sourceIndex: 2,
            pathPoint: start,
            vertices: box2.vertices,
            faces: box2.faces.enumerated().map {
                $0.offset == 3 ? portalFace($0.element, trigger: true)
                    : $0.element
            },
            portals: [.init(faceIndex: 3, connectedRoom: 3,
                            connectedPortal: 0, pathPoint: .init(x: 0, y: 100, z: 0))]
        )
        let box3 = makeSourceContainmentRoom(
            center: above, texture: texture, sourceIndex: 3, halfExtent: 100
        )
        let room3 = LevelRoom(
            sourceIndex: 3,
            pathPoint: above,
            vertices: box3.vertices,
            faces: box3.faces.enumerated().map {
                $0.offset == 2 ? portalFace($0.element, trigger: false)
                    : $0.element
            },
            portals: [.init(faceIndex: 2, connectedRoom: 2,
                            connectedPortal: 0, pathPoint: .init(x: 0, y: 100, z: 0))]
        )
        let room1 = makeSourceContainmentRoom(
            center: far, texture: texture, sourceIndex: 1, halfExtent: 100
        )
        let player = try XCTUnwrap(base.defaultPlayerBinding?.objectHandle)
        let objects = base.objects.map { object -> PlacedObject in
            var object = object
            object.location = .room(object.handle == player ? 2 : 1)
            object.position = object.handle == player ? start : far
            object.orientation = .init(
                right: .init(x: 1, y: 0, z: 0), up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            )
            return object
        }

        let ship = base.shipDefinitions[0]
        let physics = ship.physics
        XCTAssertTrue(physics.behaviors.contains(.wiggle))
        let bigWiggle = CanonicalShipPhysics(
            mass: physics.mass, drag: physics.drag,
            fullThrust: physics.fullThrust, behaviors: physics.behaviors,
            rotationalDrag: physics.rotationalDrag,
            fullRotationalThrust: physics.fullRotationalThrust,
            numberOfBounces: physics.numberOfBounces, initialForwardVelocity: 0,
            initialAngularVelocity: .zero, wiggleAmplitude: 100_000,
            wigglesPerSecond: physics.wigglesPerSecond,
            coefficientOfRestitution: physics.coefficientOfRestitution,
            hitDieDot: physics.hitDieDot,
            maximumTurnrollRate: physics.maximumTurnrollRate,
            turnrollRatio: physics.turnrollRatio
        )
        var level = replacing(
            base,
            rooms: [room1, room2, room3],
            objects: objects,
            triggers: [.init(name: "Portal2", roomIndex: 2, faceIndex: 3,
                             flags: TriggerFlag.oneShot, activator: 1)],
            indoorNavigation: .init(
                sourceHighestRoomPlusTerrainRegions: 11,
                sourceWasVerified: true, rooms: []
            )
        )
        level = replacing(level, shipDefinitions: [.init(
            source: ship.source, primaryModel: ship.primaryModel,
            presentationSize: ship.presentationSize, physics: bigWiggle,
            weaponBatteries: ship.weaponBatteries
        )])
        let simulation = GameSession(level: level, presentationReadyTimestamp: 0)
        simulation.world.velocity = .zero
        let before = simulation.world.testPlayerObject.position
        _ = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(simulation.world.testTrainingMission?.script032Count, 0)
        XCTAssertEqual(simulation.world.testPlayerObject.position, before)
        XCTAssertEqual(simulation.world.triggerFlags, [TriggerFlag.oneShot])
    }
}
