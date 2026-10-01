import XCTest

// The generic powerup pickup (scripts/generic.cpp:310 and
// Descent3/multisafe.cpp:2467), the player's invulnerability
// (Player.cpp:1576-1610, :1816), the cloak (object_lighting.cpp:572-616,
// object.cpp:2447, AImain.cpp:1645), the small views (SmallViews.cpp), and
// the end of the level (multisafe.cpp:2075, gamesequence.cpp:1240) on
// synthetic worlds, with the save continuation of their state.
final class PowerupEffectTests: XCTestCase {
    private let invulnerability = ObjectHandle(2_076)
    private let cloak = ObjectHandle(2_073)

    /// The cloak level with no level module: the two pickups bind the
    /// generic module's powerup script through their pages.
    private func pickupWorld() -> (GameWorld, Level) {
        let level = makeTrainingCloakPickupLevel()
        return (GameWorld(level: level), level)
    }

    func testGenericPowerupGivesInvulnerabilityOnceWithSoundAndMessage()
        throws
    {
        var (world, level) = pickupWorld()
        let player = world.testPlayerObject.handle
        XCTAssertEqual(
            world.objects[invulnerability]?.scripts?.defaultScript,
            .genericPowerup
        )

        world.collideTwoObjects(player, invulnerability, level: level)

        XCTAssertEqual(world.playerInvulnerableTime, 30)
        XCTAssertTrue(world.playerInvulnerabilityAnnounces)
        XCTAssertEqual(world.presentationRequests, [
            .sound(name: "Invulnerability on", volume: 0.5),
            .hudMessage("Invulnerability On"),
            .sound(name: "Powerup pickup", volume: 1),
        ])
        XCTAssertNotEqual(
            (world.objects[invulnerability]?.flags ?? 0)
                & GameObject.deadFlag,
            0
        )

        // A second Invulnerability powerup is refused while it lasts.
        let page = try XCTUnwrap(level.objectInfos?.firstIndex {
            $0.name == "Invulnerability"
        })
        guard case let .room(room) = world.testPlayerObject.location else {
            return XCTFail("The player is indoor")
        }
        let second = world.objCreate(
            type: .powerup,
            id: page,
            room: room,
            position: world.testPlayerObject.position,
            orientation: nil,
            parent: .none,
            level: level
        )
        world.presentationRequests = []
        world.collideTwoObjects(player, second, level: level)
        XCTAssertEqual(world.presentationRequests, [
            .hudMessage("You're already invulnerable"),
        ])
        XCTAssertEqual(
            (world.objects[second]?.flags ?? 0) & GameObject.deadFlag,
            0
        )

        // DoPlayerFrame counts the time down with Frametime; the sound and
        // message flag stays, so a later script invulnerability also ends
        // with them (Player.cpp:1603).
        world.presentationRequests = []
        world.doPlayerInvulnerabilityFrame(frameTime: 29.95)
        XCTAssertEqual(
            try XCTUnwrap(world.playerInvulnerableTime),
            0.05,
            accuracy: 0.000_1
        )
        world.doPlayerInvulnerabilityFrame(frameTime: 0.1)
        XCTAssertNil(world.playerInvulnerableTime)
        XCTAssertEqual(world.presentationRequests, [
            .sound(name: "Invulnerability off", volume: 0.5),
            .hudMessage("Invulnerability Off"),
        ])
        world.presentationRequests = []
        world.aObjMakeInvuln(player, 1)
        XCTAssertTrue(world.presentationRequests.isEmpty)
        world.doPlayerInvulnerabilityFrame(frameTime: 1)
        XCTAssertEqual(world.presentationRequests, [
            .sound(name: "Invulnerability off", volume: 0.5),
            .hudMessage("Invulnerability Off"),
        ])
    }

    func testGenericPowerupCloaksThePlayerThroughFadeCloakAndFadeIn()
        throws
    {
        var (world, level) = pickupWorld()
        let player = world.testPlayerObject.handle

        world.collideTwoObjects(player, cloak, level: level)

        XCTAssertEqual(world.presentationRequests, [
            .sound(name: "Cloak on", volume: 0.5),
            .hudMessage("Cloak On"),
            .sound(name: "Powerup pickup", volume: 1),
        ])
        var effect = try XCTUnwrap(world.objects[player]?.effect)
        XCTAssertEqual(
            effect.typeFlags,
            ObjectEffectInfo.fadingOutFlag
                | ObjectEffectInfo.cloakWithMessageFlag
        )
        XCTAssertEqual(effect.cloakTime, 30)
        XCTAssertEqual(effect.fadeMaxTime, 1)

        // Cloaking again is refused while it fades or lasts.
        let page = try XCTUnwrap(level.objectInfos?.firstIndex {
            $0.name == "Cloak"
        })
        guard case let .room(room) = world.testPlayerObject.location else {
            return XCTFail("The player is indoor")
        }
        let second = world.objCreate(
            type: .powerup, id: page, room: room,
            position: world.testPlayerObject.position, orientation: nil,
            parent: .none, level: level
        )
        world.presentationRequests = []
        world.collideTwoObjects(player, second, level: level)
        XCTAssertEqual(world.presentationRequests, [
            .hudMessage("You already are cloaked"),
        ])

        world.presentationRequests = []
        world.frameDuration = 0.5
        world.objDoEffects(player)
        XCTAssertEqual(ObjectCloakFrame(world.objects[player]?.effect)?.objectAlpha,
                       0.08 + 0.92 * 0.5)
        world.objDoEffects(player)
        effect = try XCTUnwrap(world.objects[player]?.effect)
        XCTAssertEqual(
            effect.typeFlags & ~ObjectEffectInfo.cloakWithMessageFlag,
            ObjectEffectInfo.cloakedFlag
        )
        let cloaked = try XCTUnwrap(ObjectCloakFrame(effect))
        XCTAssertEqual(cloaked.objectAlpha, 0.13)
        XCTAssertEqual(cloaked.objectDeformationRange, 0.1)

        // The robots do not see a cloaked player, unless its afterburner
        // is on or its headlight faces them.
        let robot = try XCTUnwrap(world.objects[ObjectHandle(2_074)])
        XCTAssertEqual(
            world.aiDetermineObjVisLevel(robot, world.testPlayerObject),
            0
        )
        world.afterburnerIsActive = true
        XCTAssertEqual(
            world.aiDetermineObjVisLevel(robot, world.testPlayerObject),
            1
        )
        world.afterburnerIsActive = false
        world.playerHeadlightIsOn = true
        var facing = world.testPlayerObject
        facing.orientation = .init(
            right: sourceVectorCross(
                facing.orientation.up,
                sourceVectorNormalized(robot.position - facing.position)
            ),
            up: facing.orientation.up,
            forward: sourceVectorNormalized(robot.position - facing.position)
        )
        XCTAssertEqual(world.aiDetermineObjVisLevel(robot, facing), 1)
        world.playerHeadlightIsOn = false

        world.frameDuration = 30
        world.objDoEffects(player)
        effect = try XCTUnwrap(world.objects[player]?.effect)
        XCTAssertNotEqual(effect.typeFlags & ObjectEffectInfo.fadingInFlag, 0)
        XCTAssertEqual(effect.typeFlags & ObjectEffectInfo.cloakedFlag, 0)
        XCTAssertEqual(world.presentationRequests, [
            .sound(name: "Cloak off", volume: 0.5),
            .hudMessage("Cloak Off"),
        ])
        XCTAssertEqual(
            world.aiDetermineObjVisLevel(robot, world.testPlayerObject),
            3
        )
        world.frameDuration = 1
        world.objDoEffects(player)
        XCTAssertNil(ObjectCloakFrame(world.objects[player]?.effect))

        // A cloak with no HUD message (a robot) ends with no message.
        world.presentationRequests = []
        world.makeObjectInvisible(ObjectHandle(2_074), time: 1)
        world.frameDuration = 1
        world.objDoEffects(ObjectHandle(2_074))
        world.objDoEffects(ObjectHandle(2_074))
        XCTAssertTrue(world.presentationRequests.isEmpty)
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

    /// The continuation contract (architecture.md section 7) for the new
    /// state: a world saved with the monitor held and the popup up, and
    /// with the player invulnerable and cloaked, continues exactly as the
    /// uninterrupted world.
    func testPickupPopupAndEffectStateContinueAcrossASave() throws {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingCloakPickupLevel(),
            guideBot: false
        )
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        session.world.trainingMission.script002Count = 1
        _ = session.touch("InvulnPowerup2", at: 0.1)
        _ = session.touch("CloakPowerup2", at: 0.2)
        _ = session.takeAndUseCameraMonitor(at: 0.3)
        XCTAssertNotNil(session.world.playerInvulnerableTime)
        XCTAssertNotNil(session.world.testPlayerObject.effect)
        XCTAssertTrue(session.world.smallViews[0].isActive)

        let saved = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(session.world)
        )
        let resumed = try GameSession(
            level: level,
            world: saved,
            resumedAtTimestamp: session.lastTimestamp
        )
        var timestamp = session.lastTimestamp
        for _ in 1...60 {
            timestamp += 0.1
            let uninterrupted = session.update(at: timestamp, input: .zero)
            let continued = resumed.update(at: timestamp, input: .zero)
            XCTAssertEqual(continued.popupView, uninterrupted.popupView)
            XCTAssertEqual(continued.playerCloak, uninterrupted.playerCloak)
            XCTAssertEqual(
                presentationLog(continued),
                presentationLog(uninterrupted)
            )
        }
        XCTAssertEqual(resumed.world, session.world)
    }

    /// A saved effect needs only finite times in the save range and a
    /// fade_max_time of at least 0; the flag and timer combinations are the
    /// runtime's. A second cloak while the first fades in
    /// (HandleCommonPowerups refuses only a fading-out or cloaked player,
    /// multisafe.cpp:2789) leaves both fade flags on one timer, which
    /// ObjDoEffects counts twice and can leave at or below 0 with
    /// EF_FADING_IN set (object.cpp:2464-2486). That world saves, loads, and
    /// continues as the uninterrupted one.
    func testOverlappingCloaksSaveAndContinue() throws {
        var (world, level) = pickupWorld()
        let player = world.testPlayerObject.handle
        world.makeObjectInvisible(player, time: 0.5)
        world.frameDuration = 1
        world.objDoEffects(player)      // the fade out ends: cloaked
        world.objDoEffects(player)      // the cloak ends: fading in
        world.frameDuration = 0.4
        world.objDoEffects(player)      // fade time 0.6
        world.makeObjectInvisible(player, time: 5)
        world.frameDuration = 0.6
        world.objDoEffects(player)      // 1 - 0.6 - 0.6 = -0.2
        let effect = try XCTUnwrap(world.objects[player]?.effect)
        XCTAssertNotEqual(effect.typeFlags & ObjectEffectInfo.fadingInFlag, 0)
        XCTAssertNotEqual(effect.typeFlags & ObjectEffectInfo.cloakedFlag, 0)
        XCTAssertLessThanOrEqual(effect.fadeTime, 0)
        world.presentationRequests = []
        XCTAssertNoThrow(try world.validate(against: level))

        var restored = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(world)
        )
        XCTAssertNoThrow(try restored.validate(against: level))
        for _ in 1...10 {
            world.objDoEffects(player)
            restored.objDoEffects(player)
        }
        XCTAssertEqual(restored, world)

        // The save refuses only times that are not finite or out of range.
        func refuses(_ change: (inout ObjectEffectInfo) -> Void) {
            var hostile = world
            hostile.presentationRequests = []
            change(&hostile.objects[player]!.effect!)
            XCTAssertThrowsError(try hostile.validate(against: level))
        }
        refuses { $0.fadeTime = .nan }
        refuses { $0.cloakTime = .infinity }
        refuses { $0.cloakTime = 2_000_000 }
        refuses { $0.fadeMaxTime = -1 }
    }

    /// The draw's alpha (renderobject.cpp:1499-1512): the fade out sets
    /// .08 + .92 * fade_time / fade_max_time, the fade in .08 + .92 *
    /// (1 - fade_time / fade_max_time), and the cloak .13, in that order.
    /// A fade_max_time of 0 divides by zero in the source; Revival takes
    /// the ratio as 0 and clamps the alpha to 0...1 (architecture.md
    /// section 9), so a cloak of fade time 0 ends without a bad alpha.
    func testCloakAlphaStaysInRangeForAnyFadeTimes() {
        var (world, _) = pickupWorld()
        let player = world.testPlayerObject.handle
        world.makeObjectInvisible(player, time: 0.05, fadeTime: 0)
        world.frameDuration = 0.1
        world.objDoEffects(player)      // the fade out ends at once
        world.objDoEffects(player)      // the cloak expires: fade in of 0
        let frame = ObjectCloakFrame(world.objects[player]?.effect)
        XCTAssertEqual(frame?.phase, .fadingIn)
        XCTAssertEqual(frame?.objectAlpha, 1)
        for (phase, remaining, duration) in [
            (ObjectCloakFrame.Phase.fadingOut, Float(0), Float(0)),
            (.fadingOut, 2, 1), (.fadingIn, -0.5, 1), (.fadingIn, 0.5, 1),
        ] {
            let alpha = ObjectCloakFrame(
                phase: phase,
                phaseRemaining: remaining,
                phaseDuration: duration
            ).objectAlpha
            XCTAssertTrue(alpha.isFinite && (0...1).contains(alpha),
                          "\(phase) \(remaining) \(duration)")
        }
        XCTAssertEqual(
            ObjectCloakFrame(phase: .fadingIn, phaseRemaining: 0.5,
                             phaseDuration: 1).objectAlpha,
            0.08 + 0.92 * 0.5
        )
    }

    /// EndLevel(0) after aFailLevel shows a failed result; only EndLevel(1)
    /// records the Training completion (gamesequence.cpp:1240-1262), and the
    /// app's ready state says which.
    @MainActor
    func testOnlyASuccessfulLevelEndRecordsCompletion() throws {
        let level = makeTrainingCameraMonitorLevel()
        let failing = GameSession(level: level, presentationReadyTimestamp: 0)
        failing.world.aFailLevel()
        let failed = try XCTUnwrap(failing.update(at: 0.1, input: .zero).levelEnd)
        XCTAssertFalse(failed.recordsMissionProgress)
        let winning = GameSession(level: level, presentationReadyTimestamp: 0)
        winning.world.aEndLevel()
        let won = try XCTUnwrap(winning.update(at: 0.1, input: .zero).levelEnd)
        XCTAssertTrue(won.recordsMissionProgress)

        let view = RevivalGameplayView(frame: .zero, device: nil)
        view.presentTrainingContentReadyState(
            completedLevelName: "Training Mission",
            succeeded: false
        )
        XCTAssertTrue(view.subviews.compactMap { $0 as? NSTextField }.contains {
            $0.stringValue.hasPrefix("Training Mission failed.")
        })
        view.presentTrainingContentReadyState(
            completedLevelName: "Training Mission",
            succeeded: true
        )
        XCTAssertTrue(view.subviews.compactMap { $0 as? NSTextField }.contains {
            $0.stringValue.hasPrefix("Training Mission completed.")
        })
    }
}
