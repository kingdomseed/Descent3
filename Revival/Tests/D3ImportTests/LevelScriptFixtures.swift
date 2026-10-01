import XCTest

/// The Training messages the synthetic fixtures use (retail text of
/// TrainingMission.msg for the names the module shows).
let fixtureTrainingMessages = [
    ("GoodJob", "Excellent!"),
    ("GoBackwards", "Now use the reverse Key to return to where you started!"),
    ("Welcome", "Welcome to the Descent 3 Training session."),
    ("GoForward", "Move forward until you stop."),
    ("GoLeft", "Now Go Left until you stop."),
    ("GoRight", "Now Slide right until you return to the start position."),
    ("GoUp", "Now Slide up  until you stop."),
    ("GoDown", "Now Slide down until you return to the start position."),
    ("Repeat", "Let's repeat the exercise we just did."),
    ("ContinueToCourse", "Continue Sliding down to start the next step."),
    (
        "CourseInstructions",
        "Now, manuever through this tunnel using the sliding skills you just learned."
    ),
    ("DodgeIntro", "Next you are going to practice dodging."),
    ("Dodge30", "To complete this step, dodge the turrett fire for 20 seconds."),
    (
        "LeaveDodge",
        "Now using your sliding skills, proceed forward to the flashing green light."
    ),
    ("FollowIntro", "Now you will use the rotational skills you just learned to follow one of the two robots that are circling this room"),
    (
        "FollowInstructions",
        "Keep one of the robots on your screen for 20 seconds using only your rotational controls to complete this step."
    ),
    ("KeepDodging", "Oops, you were hit! Keep moving!"),
    ("KeepMovingOutofDodging", "Now keep moving forward into the next room."),
    ("BankIntro", "Now your bank controls are enabled. Try them out by banking to the left and right."),
    ("AlmostDoneDodge", "You are almost done! Keep up the good work!"),
    ("ManuverIntro", "Now you are going to learn the other controls, which are pitch, heading and bank."),
    ("HeadingIntro", "Now your heading controls are enabled. Try them out by rotating to the left and right."),
    ("PitchIntro", "Now your pitch controls are enabled. Try them out by pitching up and down."),
    ("WeaponsEnabled", "Now your weapons have been enabled. There is a primary and a secondary."),
    ("DestroyFollowbot", "Now, destroy the robot."),
    ("Movingbotintro", "Now destroy 2 more robots. This time they will be moving."),
    ("ProceedtoLastRoom", "Now proceed through the doorway that just opened to begin the last stage of your training."),
    ("AllDone", "Great Job! Now fly through the opened doorway to end your training. Good job Recruit!"),
    ("UseCameraMonitor", "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!"),
    ("KillBotIntro", "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots."),
    ("KillBot2", "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup."),
    ("FinalSessionIntro", "Now for your final and most difficult task. Locate and destroy the last 5 robots."),
    ("GBExtra", "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns."),
].map { LevelScriptMessage(name: $0.0, text: $0.1) }

/// The level with Training script data (package schema 13), so the world
/// loads the Training level module. Every scriptable object gets a binding,
/// as D3Import writes one. The level keeps every other field. It validates
/// only when the level holds the clips the Training module names.
func addingTrainingMissionScripting(
    _ level: Level, messages: [LevelScriptMessage] = fixtureTrainingMessages
) -> Level {
    var level = withTrainingStreamPadding(level)
    // Silent clips for the module's sounds the level lacks.
    let pcm = Data(repeating: 0, count: 2)
    let missingSounds = TrainingMissionScript.soundNames.enumerated()
        .filter { _, name in
            !level.soundClips.contains { $0.logicalName == name }
        }
        .map { offset, name in
            CanonicalSoundClip.silent(
                logicalName: name, sourceName: "\(name) padding.wav",
                index: 30_000 + offset,
                sourceSHA256: String(repeating: "b", count: 64)
            )
        }
    if !missingSounds.isEmpty {
        level = replacing(
            level,
            soundClips: level.soundClips + missingSounds,
            dependencyManifest: .init(
                current: level.dependencyManifest.current
                    + missingSounds.map {
                        DependencyRecord(
                            category: "sound",
                            source: .init(
                                storedIndex: $0.sourceEntryIndex,
                                sourceName: $0.sourceName
                            ),
                            state: "canonical-pcm-imported",
                            provenance: "synthetic canonical fixture"
                        )
                    },
                historicalEagerBaseline:
                    level.dependencyManifest.historicalEagerBaseline
            )
        )
    }

    let bindings = level.objects
        .filter { LevelScripting.scriptableObjectTypes.contains($0.type) }
        .map { object in
            let customOnly = object.type == LevelScripting.customOnlyObjectType
            // A page that names a module binds it, as D3Import binds the
            // page's module and name.
            let page = level.objectInfos?.first {
                $0.moduleName != nil
                    && $0.name.caseInsensitiveCompare(
                        object.definition?.sourceName ?? ""
                    ) == .orderedSame
            }
            return ObjectScriptBinding(
                objectHandle: object.handle,
                name: object.instanceName,
                defaultModuleName: customOnly
                    ? nil : page?.moduleName ?? "aigame",
                defaultScriptName: customOnly
                    ? nil : page?.name ?? "Fixture"
            )
        }
    return withFixtureGameModules(level.addingScripting(
        LevelScripting(
            levelScript: "trainingmission",
            objects: bindings,
            messages: messages,
            streamedAudio: TrainingMissionScript.streamedAudioNames.map {
                LevelScriptAudioReference(name: $0, key: $0.lowercased())
            },
            sounds: TrainingMissionScript.soundNames.map {
                LevelScriptAudioReference(name: $0, key: $0)
            }
        )
    ))
}

/// The source SHA-256 that marks a fixture padding clip.
private let paddingClipSHA256 = String(repeating: "f", count: 64)

/// The level with silent padding clips for every stream the Training module
/// names and the level lacks, so a scripted fixture validates. Earlier
/// padding is dropped first, so a fixture that later adds a real clip of the
/// same name keeps only the real one.
func withTrainingStreamPadding(_ level: Level) -> Level {
    func isPadding(_ record: DependencyRecord) -> Bool {
        record.category == "voice"
            && record.provenance.hasSuffix(paddingClipSHA256)
    }

    let kept = level.voiceClips.filter { $0.sourceSHA256 != paddingClipSHA256 }
    let keptDependencies = level.dependencyManifest.current.filter {
        !isPadding($0)
    }
    // A test that removes a real clip but keeps its dependency record gets
    // no padding for it, so its own validation error still shows.
    let recordedVoices = Set(keptDependencies.filter {
        $0.category == "voice"
    }.map { $0.source.sourceName.lowercased() })
    let padding = fixtureTrainingStreamClips(excluding: kept).filter {
        !recordedVoices.contains($0.sourceName)
    }

    let dependencies = keptDependencies + padding.map {
        DependencyRecord(
            category: "voice",
            source: .init(
                storedIndex: $0.sourceEntryIndex, sourceName: $0.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance: "\($0.sourceArchive) \($0.sourceSHA256)"
        )
    }
    // Schema 11 here, so `replacing` does not bind scripts again; the
    // caller adds the script data.
    return replacing(
        level,
        schemaVersion: 11,
        voiceClips: kept + padding,
        dependencyManifest: .init(
            current: dependencies,
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
}

private func fixtureTrainingStreamClips(
    excluding existing: [CanonicalVoiceClip]
) -> [CanonicalVoiceClip] {
    let pcm = Data(repeating: 0, count: 2)
    let present = Set(existing.map { $0.sourceName.lowercased() })
    return TrainingMissionScript.streamedAudioNames
        .map { $0.lowercased() }
        .filter { !present.contains($0) }
        .enumerated()
        .map { offset, name in
            CanonicalVoiceClip.silent(
                name, index: 900 + offset, sourceSHA256: paddingClipSHA256
            )
        }
}

/// A copy of a placed object with another name.
func renamed(_ object: PlacedObject, _ name: String?) -> PlacedObject {
    PlacedObject.fixture(
        handle: object.handle, type: object.type, storedID: object.storedID,
        definition: object.definition, name: name, flags: object.flags,
        doorShields: object.doorShields, location: object.location,
        position: object.position, orientation: object.orientation,
        containsType: object.containsType, containsID: object.containsID,
        containsCount: object.containsCount, lifeLeft: object.lifeLeft,
        soundSource: object.soundSource,
        inertScriptName: object.inertScriptName,
        inertModuleName: object.inertModuleName,
        lightmapSubmodels: object.lightmapSubmodels
    )
}

/// The world with its Training action counters changed, as a script that
/// already ran leaves them.
func settingTrainingCounters(
    _ world: GameWorld, _ change: (inout TrainingMissionState) -> Void
) -> GameWorld {
    var world = world
    var state = world.testTrainingMission!
    change(&state)
    world.levelModule = .trainingMission(state)
    return world
}

extension GameWorld {
    /// The Training module state, or `nil` when another module is loaded.
    var testTrainingMission: TrainingMissionState? {
        guard case let .trainingMission(state) = levelModule else {
            return nil
        }
        return state
    }
}

/// Moves every pending Osiris timer in a test world object to Gametime
/// `time`, so a test that starts mid-lesson does not see Script 002.
func deferringOsirisTimers(
    _ object: inout [String: Any], to time: Float
) throws {
    var timers = try XCTUnwrap(object["osirisTimers"] as? [String: Any])
    var entries = try XCTUnwrap(timers["entries"] as? [[String: Any]])
    for index in entries.indices where entries[index]["isUsed"] as? Bool == true {
        entries[index]["nextSignal"] = time
        entries[index]["end"] = time
    }
    timers["entries"] = entries
    object["osirisTimers"] = timers
}

/// A fixture level whose objects changed after it got Training script
/// data: the bindings are made again from its objects, as D3Import would.
func rescriptedTrainingLevel(_ level: Level) -> Level {
    guard let scripting = level.scripting else { return level }
    return addingTrainingMissionScripting(level, messages: scripting.messages)
}

/// The powerups whose EVT_COLLIDE the Training opening scripts handle.
let trainingOpeningGoalNames = [
    "ForwardGoal", "StartGoal", "LeftGoal", "UpGoal", "StartCourse",
    "FinishCourse", "StartDodge",
]

extension GameSession {
    /// Moves every Training opening goal 2,000 units behind the player, so
    /// no move reaches one.
    func parkTrainingGoals() {
        let player = world.testPlayerObject
        for name in trainingOpeningGoalNames {
            let handle = level.findObjectName(name)
            guard var goal = world.objects[handle] else { continue }
            goal.location = player.location
            goal.position = player.position
                + Vector3(x: 0, y: 0, z: -2_000)
            world.objects[handle] = goal
        }
    }

    /// Flies the player into the named object in the frame at `timestamp`:
    /// the object waits 3 units ahead in the player's room, and the player
    /// moves toward it at 30 units per second. The other opening goals are
    /// parked first. A player at rest hits nothing
    /// (check_vector_to_sphere_1, findintersection.cpp:1194).
    @discardableResult
    func touch(_ name: String, at timestamp: Double) -> PlayerSimulationFrame {
        parkTrainingGoals()
        let player = world.testPlayerObject
        let handle = level.findObjectName(name)
        var goal = world.objects[handle]!
        goal.location = player.location
        goal.position = player.position + Vector3(x: 0, y: 0, z: 3)
        world.objects[handle] = goal
        world.velocity = Vector3(x: 0, y: 0, z: 30)
        let frame = update(at: timestamp, input: .zero)
        world.velocity = .zero
        parkTrainingGoals()
        return frame
    }
}

/// A frame's presentation as `hud:`, `voice:`, and `sound:` entries, in
/// request order.
func presentationLog(_ frame: PlayerSimulationFrame) -> [String] {
    frame.presentationFeedback.flatMap { feedback -> [String] in
        var log = feedback.soundSourceName.map { ["sound:\($0)"] } ?? []
        let voice = feedback.voiceSourceName.isEmpty
            ? [] : ["voice:\(feedback.voiceSourceName)"]
        let hud = feedback.hudMessages.map { "hud:\($0)" }
        log += feedback.voicePrecedesHUDMessages ? voice + hud : hud + voice
        return log + feedback.trailingHUDMessages.map { "hud:\($0)" }
    }
}

/// The retail text of a Training message name (`fixtureTrainingMessages`).
func trainingText(_ name: String) -> String {
    fixtureTrainingMessages.first { $0.name == name }!.text
}

extension GameSession {
    /// The collide_two_objects call (collide.cpp:2493) that the player's
    /// move into the named object makes. Tests that start the player on a
    /// goal at rest use it: a move that does not close in hits nothing.
    func collidePlayer(with name: String) {
        world.collideTwoObjects(
            world.testPlayerObject.handle, level.findObjectName(name),
            level: level
        )
    }
}

/// Sets one Training action counter in a test world object, as a script
/// that already ran leaves it.
func setTrainingCounter(
    _ object: inout [String: Any], _ name: String, _ value: Int
) throws {
    var module = try XCTUnwrap(object["levelModule"] as? [String: Any])
    var training = try XCTUnwrap(module["trainingMission"] as? [String: Any])
    var state = try XCTUnwrap(training["_0"] as? [String: Any])
    state[name] = value
    training["_0"] = state
    module["trainingMission"] = training
    object["levelModule"] = module
}

/// The used Osiris timer 8 on StartDodge (Script 033,
/// TrainingMission.cpp:1860), if any.
func startDodgeTimer(_ session: GameSession) -> OsirisTimer? {
    let startDodge = session.level.findObjectName("StartDodge")
    return session.world.osirisTimers.entries.first {
        $0.isUsed && $0.owner == .object(startDodge) && $0.id == 8
    }
}

extension GameSession {
    /// Kills each object as the player's weapons would: KillObject with the
    /// player as the killer (damage.cpp:1175), so the player scores the
    /// page's score. ObjDeleteDead runs at the end of the next object frame.
    func killRobotsAsPlayer(_ handles: [UInt32]) {
        for handle in handles {
            world.killObject(
                ObjectHandle(handle), killer: world.testPlayerObject.handle,
                damage: 1, level: level
            )
        }
    }
}

/// The gallery barrier that Scripts 032 and 036 open and close in a
/// Training level (TrainingMission.cpp:2040-2046, :2325-2340): the room of
/// the Portal2 trigger, its portals 1 and 0 in script order, and
/// FlashLight-2, the marker light. Test data derived from the level.
struct TrainingGalleryBarrierFixture: Equatable {
    let triggerName: String
    let triggerRoomSourceIndex: Int
    let triggerFaceIndex: Int
    let barrierRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let markerLightObjectHandle: UInt32
}

extension Level {
    /// The level's Training gallery barrier, if it has the Portal2 trigger
    /// and FlashLight-2.
    var trainingGalleryBarrier: TrainingGalleryBarrierFixture? {
        guard let trigger = triggers.first(where: { $0.name == "Portal2" }),
              let marker = objects.first(where: {
                  $0.instanceName == "FlashLight-2"
              })
        else {
            return nil
        }
        return .init(
            triggerName: trigger.name,
            triggerRoomSourceIndex: trigger.roomIndex,
            triggerFaceIndex: trigger.faceIndex,
            barrierRoomSourceIndex: trigger.roomIndex,
            orderedPortalIndices: [1, 0], markerLightObjectHandle: marker.handle
        )
    }
}

extension GameSession {
    /// The world Script 036 leaves when DestroyBot2 dies
    /// (TrainingMission.cpp:2040-2046), for an unscripted fixture: the robot
    /// is gone, FlashLight-2 is lit, the gallery barrier is open, and every
    /// control is on. The scripted path is in TrainingMissionScriptTests+Robots.
    func applyTrainingScript036Outcome() {
        world.objects.delete(ObjectHandle(4_112))
        if let barrier = level.trainingGalleryBarrier {
            world.setObjectLightDistance(
                ObjectHandle(barrier.markerLightObjectHandle), 50
            )
        }
        if let barrier = level.trainingGalleryBarrier {
            for portal in barrier.orderedPortalIndices {
                world.setPortalRender(
                    room: barrier.barrierRoomSourceIndex, portal: portal,
                    state: false, doubleSided: true, level: level
                )
            }
        }
        world.aToggleAllPlayerControls(1, 0, level: level)
    }

    /// FlashLight-3's script light distance (the Guide-Bot return marker,
    /// Object_handles[2]), or 0.
    var returnMarkerLightDistance: Float {
        world.objects[level.findObjectName("FlashLight-3")]?
            .localLighting?.lightDistance ?? 0
    }

    /// FlashLight-2's script light distance (the gallery marker), or 0.
    var galleryMarkerLightDistance: Float {
        level.trainingGalleryBarrier.flatMap {
            world.objects[ObjectHandle($0.markerLightObjectHandle)]?
                .localLighting?.lightDistance
        } ?? 0
    }
}

/// A fixture page of the generic module (scripts/generic.cpp): a powerup
/// whose default script is GenericScript.
func fixtureGenericPowerupInfo(_ name: String) -> CanonicalObjectInfo {
    var info = CanonicalObjectInfo(
        name: name, type: 7, flags: 0x6, size: 3, hitPoints: 100,
        lightDistance: 0, lighting: fixtureNoLight, ai: nil, weaponBatteries: []
    )
    info.moduleName = GenericModule.moduleName
    return info
}

/// The level with the game module entries its pages and bindings reach,
/// keeping the ones it has: the generic module has no strings or sounds.
func withFixtureGameModules(_ level: Level) -> Level {
    var level = level
    var modules = level.gameModules ?? []
    if level.reachedGameModules.contains(GenericModule.moduleName),
       !modules.contains(where: { $0.module == GenericModule.moduleName }) {
        modules.append(.init(
            module: GenericModule.moduleName, strings: [], sounds: []
        ))
    }
    level.gameModules = modules.sorted { $0.module < $1.module }
    return level
}

/// The level with more voice and sound clips (the ones it lacks), and their
/// dependency records.
func addingFixtureAudio(
    _ level: Level, voiceClips: [CanonicalVoiceClip] = [],
    soundClips: [CanonicalSoundClip] = []
) -> Level {
    level.addingAudioClips(
        voiceClips: voiceClips.filter { clip in
            !level.voiceClips.contains {
                $0.sourceName.caseInsensitiveCompare(clip.sourceName)
                    == .orderedSame
            }
        },
        soundClips: soundClips.filter { clip in
            !level.soundClips.contains { $0.logicalName == clip.logicalName }
        }
    )
}

/// The level with "object-definition" dependency records for these pages,
/// as D3Import records each placed object's definition.
func addingFixtureObjectDefinitions(
    _ level: Level, _ definitions: [SourceResource]
) -> Level {
    let added = definitions.filter { source in
        !level.dependencyManifest.current.contains {
            $0.category == "object-definition" && $0.source == source
        }
    }.map {
        DependencyRecord(
            category: "object-definition", source: $0,
            state: "canonical-object-definition",
            provenance: "synthetic canonical fixture"
        )
    }
    return replacing(
        level,
        dependencyManifest: .init(
            current: level.dependencyManifest.current + added,
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
}

extension GameSession {
    /// Takes the Camera Monitor (Script 040, TrainingMission.cpp:2062) in
    /// the frame at `timestamp` and uses it (Script 059, :2075) in the
    /// next; returns the use frame, which shows the popup view. The level
    /// needs the Training module.
    func takeAndUseCameraMonitor(at timestamp: Double) -> PlayerSimulationFrame {
        _ = touch("CameraMonitor", at: timestamp)
        return update(at: timestamp + 0.1, input: .init(usesInventory: true))
    }
}

/// A synthetic level as a package holds it (schema 13): the Training level
/// script data, bound again to the level's objects.
func packageLevel(_ level: Level) -> Level {
    // Drop the audio records of clips a rebuilt level no longer holds, so
    // the padding is added once.
    let clipNames = Set(level.voiceClips.map { $0.sourceName.lowercased() })
        .union(level.soundClips.map { $0.sourceName.lowercased() })
    let records = level.dependencyManifest.current.filter {
        !["voice", "sound"].contains($0.category)
            || clipNames.contains($0.source.sourceName.lowercased())
    }
    return addingTrainingMissionScripting(
        replacing(
            level,
            dependencyManifest: .init(
                current: records,
                historicalEagerBaseline:
                    level.dependencyManifest.historicalEagerBaseline
            )
        ),
        messages: level.scripting?.messages ?? fixtureTrainingMessages
    )
}

extension GameSession {
    /// Turns every player control on, as the Training lessons do: a package
    /// level loads the Training module, whose Script 000 leaves only
    /// forward on (TrainingMission.cpp:1461).
    func enableAllPlayerControls() {
        world.aToggleAllPlayerControls(1, 0, level: level)
    }
}

/// The session as a save at this point leaves it: the world through JSON,
/// resumed at `timestamp`.
func restored(_ session: GameSession, at timestamp: Double) throws
    -> GameSession
{
    try GameSession(
        level: session.level,
        world: JSONDecoder().decode(
            GameWorld.self, from: JSONEncoder().encode(session.world)
        ),
        resumedAtTimestamp: timestamp
    )
}
