// SPDX-License-Identifier: GPL-3.0-or-later
//
// The save file: a Codable `GameWorld` plus the package fingerprint and the
// pilot (architecture.md section 7). It replaces the legacy binary
// SaveGameState and the script save events.

import Foundation

private let maximumGameSaveByteCount = 8 * 1_024 * 1_024
private let quicksaveName = "quicksave.json"
/// The largest magnitude of any saved number or vector component: game
/// times, deadlines, timers, lifetimes, positions, and velocities. As a time
/// it is about eleven days. It keeps every time-derived integer conversion,
/// wrap loop, and squared vector length in range. The bound is symmetric
/// because the source keeps some deadlines negative (for example the dodge
/// turret's initial last-visible time of -14 s).
private let maximumSavedMagnitude: Float = 1_000_000
private let maximumSavedTime = maximumSavedMagnitude

struct GameSave: Codable, Equatable, Sendable {
    /// Schema 2 replaced player save schema 1, which wrapped continuation
    /// schema 7. Schema 3 (M1 step 9) adds the inventory's object items,
    /// the level goal state, the small views, the object effects, and the
    /// game state request.
    static let currentSchemaVersion = 3

    let schemaVersion: Int
    /// The pilot.
    let profileID: UUID
    /// The package fingerprint.
    let package: CanonicalPackageReference
    let world: GameWorld

    init(
        profileID: UUID,
        package: CanonicalPackageReference,
        world: GameWorld
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.profileID = profileID
        self.package = package
        self.world = world
    }
}

enum GameSaveError: Error, Equatable, LocalizedError {
    case missingSave
    case malformedSave
    case unsupportedSaveSchema(Int)
    case profileMismatch
    case packageMismatch
    case nonRegularFile
    case tooLarge
    case invalidWorld(GameWorldValidationError)
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingSave:
            "No quicksave exists for the selected pilot."
        case .malformedSave:
            "The quicksave is corrupt."
        case let .unsupportedSaveSchema(version):
            "The quicksave uses unsupported save schema \(version)."
        case .profileMismatch:
            "The quicksave belongs to a different pilot."
        case .packageMismatch:
            "The quicksave belongs to a different canonical package."
        case .nonRegularFile:
            "The quicksave is not a regular owned file."
        case .tooLarge:
            "The quicksave is larger than 8 MiB."
        case .invalidWorld:
            "The quicksave contains invalid game state."
        case let .readFailed(message):
            "Could not read the quicksave: \(message)"
        case let .writeFailed(message):
            "Could not write the quicksave: \(message)"
        }
    }
}

enum GameWorldValidationError: Error, Equatable, Sendable {
    case objectTableShape
    case objectHandle(slot: Int)
    case freeList
    case objectLocation(slot: Int)
    case nonFiniteValue(String)
    case missingPlayer
    case roomState
    case goals
    case orientation(String)
    case roomReference(String)
    case objectReference(UInt32)
    case indexOutOfRange(String)
    case capacity(String)
    case unexpectedState(String)
    case outOfDomain(String)
}

extension GameWorld {
    /// Structural validation, done once when a world crosses the save
    /// boundary: slots and handles agree, the free list holds exactly the
    /// free slots, required objects exist, room and object references are in
    /// range, indices and array lengths fit what the runtime indexes, floats
    /// are finite, and every saved orientation is an orthonormal basis.
    func validate(against level: Level) throws(GameWorldValidationError) {
        let capacity = ObjectTable.capacity
        guard objects.slots.count == capacity,
              objects.handles.count == capacity
        else {
            throw .objectTableShape
        }
        let roomSourceIndices = Set(level.rooms.map(\.sourceIndex))
        for slot in 0..<capacity {
            let handle = objects.handles[slot]
            guard handle.slot == slot else {
                throw .objectHandle(slot: slot)
            }
            guard let object = objects.slots[slot] else { continue }
            guard object.handle == handle,
                  handle.rawValue & ObjectHandle.countMask != 0
            else {
                throw .objectHandle(slot: slot)
            }
            switch object.location {
            case let .room(room):
                guard roomSourceIndices.contains(room) else {
                    throw .objectLocation(slot: slot)
                }
            case let .terrainCell(cell):
                guard (0..<65_536).contains(cell) else {
                    throw .objectLocation(slot: slot)
                }
            }
            guard isFinite(object.position) else {
                throw .nonFiniteValue("object \(slot)")
            }
            guard abs(object.position.x) <= maximumSavedMagnitude,
                  abs(object.position.y) <= maximumSavedMagnitude,
                  abs(object.position.z) <= maximumSavedMagnitude
            else {
                throw .outOfDomain("object \(slot)")
            }
            guard isCanonicalRigidTransform(
                position: object.position,
                orientation: object.orientation
            ) else {
                throw .orientation("object \(slot)")
            }
        }
        let freeSlots = Set(objects.freeSlots)
        guard freeSlots.count == objects.freeSlots.count,
              freeSlots == Set(
                  (0..<capacity).filter { objects.slots[$0] == nil }
              )
        else {
            throw .freeList
        }

        guard let binding = level.defaultPlayerBinding,
              let player = objects[ObjectHandle(binding.objectHandle)],
              player.type == .player,
              case .room = player.location
        else {
            throw .missingPlayer
        }

        guard rooms.count == level.rooms.count,
              zip(rooms, level.rooms).allSatisfy({
                  $0.portalFlags.count == $1.portals.count
              })
        else {
            throw .roomState
        }
        guard goals.count == level.goals.count,
              zip(goals, level.goals).allSatisfy({ saved, canonical in
                  saved.priority == canonical.priority
                      && saved.list == canonical.list
                      && saved.name == canonical.name
                      && saved.itemName == canonical.itemName
                      && saved.description == canonical.description
                      && saved.completionMessage
                          == canonical.completionMessage
                      && saved.items.count == canonical.items.count
                      && zip(saved.items, canonical.items).allSatisfy {
                          $0.type == $1.type
                              && $0.sourceHandle == $1.sourceHandle
                              && $0.objectHandle == $1.objectHandle
                      }
              })
        else {
            throw .goals
        }

        let scalars: [(String, Float)] = [
            ("frameDuration", frameDuration),
            ("gameTime", gameTime),
            ("turnrollFixedAngle", turnrollFixedAngle),
            ("afterburnerFuel", afterburnerFuel),
            ("energy", energy),
            ("shields", shields),
            ("afterburnerMagnitude", afterburnerMagnitude),
            ("wiggleFalloff", wiggleFalloff),
            ("lastThrustTime", lastThrustTime),
        ]
        for (name, value) in scalars where !value.isFinite {
            throw .nonFiniteValue(name)
        }
        guard frameDuration >= 0, gameTime >= 0 else {
            throw .nonFiniteValue("clock")
        }
        guard frameDuration <= maximumSavedTime else {
            throw .outOfDomain("frameDuration")
        }
        guard gameTime <= maximumSavedTime else {
            throw .outOfDomain("gameTime")
        }
        // The turnroll update keeps the angle within +/-32000.
        guard abs(turnrollFixedAngle) <= 32_000 else {
            throw .outOfDomain("turnrollFixedAngle")
        }
        guard isFinite(velocity), isFinite(angularVelocity) else {
            throw .nonFiniteValue("player velocity")
        }

        let rules = SavedValueRules(roomSourceIndices: roomSourceIndices)
        try validateWorldValues(rules)
        // The object_info and weapon indices are checked before the script
        // bindings resolve pages through them.
        try validateObjectRuntimeState(level: level, rules: rules)
        try validateScriptState(level: level, rules: rules)
        try validateIndicesAndCapacities(level: level)
        try validateNumericDomains(level: level)
    }

    /// Osiris and object script state: the level module is the one the
    /// level names, timer handles name their entries, ghost and lighting
    /// fields are consistent, and no presentation request is pending.
    private func validateScriptState(
        level: Level,
        rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        func require(_ condition: Bool, _ name: String)
            throws(GameWorldValidationError)
        {
            if !condition { throw .unexpectedState(name) }
        }
        try require(presentationRequests.isEmpty, "presentationRequests")
        // A level a script ended is over; the session saves no ended level.
        try require(gameStateRequest == nil, "gameStateRequest")
        // SGSTriggers saves one flags value per level trigger
        // (gamesave.cpp:951).
        try require(
            triggerFlags.count == level.triggers.count,
            "triggerFlags"
        )
        // The frame's link list and lights are consumed within the update.
        try require(physicsLinkList.isEmpty, "physicsLinkList")
        try require(objectLights.isEmpty, "objectLights")
        try require(
            levelModule.isValidSavedState(
                forLoaded: LevelModule.load(level: level)
            ),
            "levelModule"
        )
        try require(
            osirisTimers.entries.count == OsirisTimers.capacity,
            "osirisTimers"
        )
        for (index, timer) in osirisTimers.entries.enumerated() {
            // Osiris_CreateTimer takes repeat counts of -1 (endless) or
            // more; the processor decrements them.
            try require(timer.repeatCount >= -1, "osirisTimers.repeatCount")
            if case let .trigger(number) = timer.owner {
                try require(
                    level.triggers.indices.contains(number),
                    "osirisTimers.trigger"
                )
            }
            if timer.isUsed {
                try require(
                    OsirisTimers.slot(of: timer.handle) == index,
                    "osirisTimers.handle"
                )
            }
        }
        for object in objects {
            try require(
                (object.type == .dummy) == (object.dummyType != nil)
                    && object.dummyType != .dummy,
                "object \(object.handle.slot) dummyType"
            )
            // A default script's state is finite and in range.
            try object.scripts?.defaultScript?.validateSavedValues(rules)
            // Bound scripts are exactly the ones the modules give.
            try require(
                object.scripts.map {
                    $0.hasSameBinding(
                        as: osirisScripts(for: object, level: level)
                    ) && ($0.defaultScript?.isValidSavedState ?? true)
                } ?? (osirisScripts(for: object, level: level) == nil),
                "object \(object.handle.slot) scripts"
            )
            if let lighting = object.localLighting {
                let distance = lighting.lightDistance ?? 0
                guard distance.isFinite,
                      distance >= 0,
                      distance <= maximumSavedMagnitude,
                      lighting.color.map(isFinite) ?? true
                else {
                    throw .nonFiniteValue("object \(object.handle.slot)")
                }
                if let color = lighting.color {
                    try rules.vector(color, "object \(object.handle.slot)")
                }
            }
        }
    }

    /// Values the runtime normalizes, wraps, or converts to integers keep
    /// the ranges the runtime itself produces.
    private func validateNumericDomains(
        level: Level
    ) throws(GameWorldValidationError) {
        func require(_ condition: Bool, _ name: String)
            throws(GameWorldValidationError)
        {
            if !condition { throw .outOfDomain(name) }
        }
        func nonzero(_ vector: Vector3) -> Bool {
            levelDot(vector, vector) > 0
        }
        // Visual effects: a live effect ages (VF_USES_LIFELEFT), has life
        // left between 0 and its lifetime (VisEffectMoveAll marks it dead
        // below 0), and carries only the VF_ flags the runtime sets.
        let knownFlags = VisEffect.usesLifeLeftFlag | VisEffect.planarFlag
            | VisEffect.expandFlag | VisEffect.attachedFlag
        for effect in visEffects {
            try require(
                effect.lifetime > 0
                    && effect.lifeLeft >= 0
                    && effect.lifeLeft <= effect.lifetime
                    && effect.flags & VisEffect.usesLifeLeftFlag != 0
                    && effect.flags & ~knownFlags == 0
                    && effect.mass >= 0 && effect.drag >= 0,
                "visEffects.lifeLeft"
            )
        }
        for object in objects {
            let name = "object \(object.handle.slot)"
            if let shockwave = object.shockwave {
                // DoConcussiveForce divides by the impact time and size.
                try require(
                    shockwave.time > 0 && shockwave.size > 0,
                    "\(name) shockwave"
                )
            }
            if let dying = object.dying {
                try require(dying.killerPlayer.map { $0 == 0 } ?? true,
                            "\(name) dying")
            }
            if let effect = object.effect {
                // Every time is finite and in the save range, and
                // fade_max_time is not negative. The flag and timer
                // combinations are the runtime's: overlapping cloaks leave
                // both fades on one timer (object.cpp:2464-2486), and the
                // draw clamps its alpha (ObjectCloakFrame).
                let known = ObjectEffectInfo.fadingInFlag
                    | ObjectEffectInfo.fadingOutFlag
                    | ObjectEffectInfo.cloakedFlag
                    | ObjectEffectInfo.cloakWithMessageFlag
                let times = [effect.cloakTime, effect.fadeTime,
                             effect.fadeMaxTime]
                try require(
                    effect.typeFlags & ~known == 0
                        && times.allSatisfy {
                            $0.isFinite && abs($0) <= maximumSavedTime
                        }
                        && effect.fadeMaxTime >= 0,
                    "\(name) effect"
                )
            }
        }
        try require(
            playerWeapons.allSatisfy { $0.firingTime >= 0 },
            "playerWeapons.firingTime"
        )
        // Rendered rooms and object physics hold values the runtime makes.
        try require(
            rooms.allSatisfy { $0.lastRenderTime <= gameTime },
            "rooms.lastRenderTime"
        )
        for object in objects {
            if let physics = object.physics {
                // Every scalar and the spin stay finite and within the save
                // bound, as the integrator divides by mass and drag and
                // converts spin times Frametime to an angle.
                func bounded(_ value: Float) -> Bool {
                    value.isFinite && abs(value) <= 1e6
                }
                let spin = physics.rotationalVelocity
                try require(
                    bounded(physics.mass) && physics.mass >= 0
                        && bounded(physics.drag) && physics.drag >= 0
                        && bounded(physics.restitution)
                        && bounded(spin.x) && bounded(spin.y)
                        && bounded(spin.z)
                        && physics.numberOfBounces >= -1,
                    "object \(object.handle.slot) physics"
                )
            }
        }
        for event in gameEvents.compactMap({ $0 }) {
            try require(event.endTime >= event.startTime, "gameEvents.time")
        }
        // The player's death started at or before the saved game time.
        try require(
            playerDeath.map { $0.initialDeathTime <= gameTime } ?? true,
            "playerDeath.initialDeathTime"
        )
        try require(
            playerWeaponAmmo.allSatisfy { (0...Int(UInt16.max)).contains($0) },
            "playerWeaponAmmo"
        )
    }

    /// Indices and array lengths that the runtime and the renderer's
    /// fixed-capacity draw lists use directly.
    private func validateIndicesAndCapacities(
        level: Level
    ) throws(GameWorldValidationError) {
        func require(_ condition: Bool, _ name: String)
            throws(GameWorldValidationError)
        {
            if !condition { throw .indexOutOfRange(name) }
        }
        func limit(_ count: Int, _ capacity: Int, _ name: String)
            throws(GameWorldValidationError)
        {
            if count > capacity { throw .capacity(name) }
        }
        try limit(visEffects.count, VisEffect.capacity, "visEffects")
        for effect in visEffects {
            // NUM_FIREBALLS (fireball.cpp:622-674).
            try require(effect.id < 52, "visEffects.id")
            // An attached effect names a well-formed object handle
            // (VisEffectMoveOne reads its slot) and in-range attach fields.
            try require(
                effect.attachedSubmodel >= 0 && effect.attachedVertex >= 0
                    && effect.attachedEndVertex >= 0
                    && effect.attachedSubmodel < 1_000
                    && effect.attachedVertex < 100_000
                    && effect.attachedEndVertex < 100_000
                    && (effect.flags & VisEffect.attachedFlag == 0
                        || effect.attachedObject.map {
                            $0.slot < ObjectTable.capacity
                        } == true),
                "visEffects.attached"
            )
            if let weapon = effect.customWeapon {
                try require(
                    level.weapons?.indices.contains(weapon) == true,
                    "visEffects.customWeapon"
                )
            }
        }
        // Pending events: MAX_EVENTS slots, each in a real room with a
        // Fireballs[] id.
        try require(
            gameEvents.count == GameEvent.capacity,
            "gameEvents"
        )
        let roomSources = Set(level.rooms.map(\.sourceIndex))
        for event in gameEvents.compactMap({ $0 }) {
            switch event.action {
            case let .explosion(_, id, room, _, _):
                try require(
                    id < 52 && roomSources.contains(room),
                    "gameEvents.explosion"
                )
            case let .blastRing(_, _, room):
                try require(roomSources.contains(room), "gameEvents.blastRing")
            }
        }
        // The objects a death made: their model, submodel, and face.
        for object in objects {
            let name = "object \(object.handle.slot)"
            if let source = object.model {
                guard let model = level.models.first(where: {
                    $0.source == source
                }) else {
                    throw .indexOutOfRange("\(name) model")
                }
                try require(
                    object.submodel.map {
                        model.submodels.indices.contains($0)
                    } ?? true,
                    "\(name) submodel"
                )
                try require(
                    object.splinterFace.map {
                        model.submodels[0].faces.indices.contains($0)
                    } ?? true,
                    "\(name) splinter"
                )
            } else {
                try require(
                    object.submodel == nil && object.splinterFace == nil,
                    "\(name) model"
                )
            }
            if let fireball = object.fireball {
                try require(
                    fireball.id < 52 && object.type == .fireball,
                    "\(name) fireball"
                )
            }
        }
        // Players[0].weapon indexes the ship batteries and the ammo.
        try require(
            playerWeapons.count == 2
                && playerWeapons.allSatisfy {
                    (0..<PlayerWeaponState.maximumPlayerWeapons)
                        .contains($0.index)
                }
                && playerWeaponAmmo.count
                    == PlayerWeaponState.maximumPlayerWeapons,
            "playerWeapons"
        )
        // The sound system's loops name a level sound and have distinct
        // handles.
        try require(
            soundSystem.nextHandle >= 0
                && Set(soundSystem.objectLoops.map(\.handle)).count
                    == soundSystem.objectLoops.count
                && soundSystem.objectLoops.allSatisfy {
                    level.soundClips.indices.contains($0.soundIndex)
                        && $0.handle >= 0
                },
            "soundSystem"
        )
        try limit(
            playerInventory.items.count,
            PlayerInventory.maximumUniqueItems,
            "playerInventory"
        )
        try require(
            playerInventory.isValidSavedState
                && playerInventory.items.allSatisfy {
                    level.objectInfos?.indices.contains($0.id) == true
                        && $0.object.map { objects[$0] != nil } ?? true
                },
            "playerInventory"
        )
        // The small views: three windows and their saved copies, each
        // with an object handle and the SVF_ flags the runtime sets.
        try limit(smallViews.count, SmallView.count, "smallViews")
        try limit(savedSmallViews.count, SmallView.count, "savedSmallViews")
        try require(
            smallViews.count == SmallView.count
                && savedSmallViews.count == SmallView.count
                && (smallViews + savedSmallViews).allSatisfy {
                    $0.flags & ~UInt32(0x3f) == 0 && $0.zoom > 0
                        && $0.gun >= -1
                },
            "smallViews"
        )
        try require(playerGuideBotName.count <= 7, "playerGuideBotName")
    }

    /// The per-object runtime state: object_info and weapon indices name
    /// the level's tables, an AI frame belongs to a CT_AI page and keeps its
    /// fixed arrays, goal and path nodes name game path nodes, weapon
    /// batteries match the model, turret angles stay in 0...1 (ai_fire
    /// wraps them), and every float and vector is finite and in range.
    private func validateObjectRuntimeState(
        level: Level,
        rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        func require(_ condition: Bool, _ name: String)
            throws(GameWorldValidationError)
        {
            if !condition { throw .indexOutOfRange(name) }
        }
        func pathNodeIsValid(_ path: Int, _ node: Int) -> Bool {
            level.paths.indices.contains(path)
                && level.paths[path].nodes.indices.contains(node)
        }
        // AI_RenderedList holds object numbers (AImain.cpp:1624). A listed
        // object deleted since the render is skipped by AIFrameAll.
        try require(
            aiRenderedList.count <= ObjectTable.capacity
                && aiRenderedList.allSatisfy {
                    $0.slot < ObjectTable.capacity
                },
            "aiRenderedList"
        )
        // The last rendered view is a proper camera: IsPointVisible builds
        // its basis and projection from it.
        if let camera = lastRenderCamera {
            try rules.vector(camera.position, "lastRenderCamera")
            try rules.vector(camera.target, "lastRenderCamera")
            try rules.vector(camera.up, "lastRenderCamera")
            let forward = camera.target - camera.position
            let side = sourceVectorCross(camera.up, forward)
            let fov = camera.projection.horizontalFieldOfViewRadians
            let aspect = camera.projection.aspectRatio
            try require(
                levelDot(forward, forward) > 0.000_001
                    && levelDot(side, side) > 0.000_001
                    && fov.isFinite && fov > 0.01 && fov < 3
                    && aspect.isFinite && aspect > 0.01 && aspect < 100,
                "lastRenderCamera"
            )
        }
        for object in objects {
            let name = "object \(object.handle.slot)"
            try rules.number(object.size, name)
            try rules.number(object.shields, name)
            try rules.vector(object.velocity, name)
            try rules.vector(object.lastPosition, name)
            try rules.number(object.creationTime, name)
            try require(object.size >= 0, name)
            // Stored handles are well formed; they may name an object that
            // has since been deleted, which the runtime looks up optionally.
            try rules.handleShape(object.parent)
            try rules.handleShape(object.attachUltimateHandle)
            if let debris = object.debris {
                try rules.number(debris.lastSmokeTime, name)
            }
            if let fireball = object.fireball {
                try rules.number(fireball.maximumSize, name)
                try rules.number(fireball.lifetime, name)
            }
            try require(
                (object.shockwave != nil) == (object.type == .shockwave)
                    && (object.shockwave?.damagedList.count
                        ?? ShockwaveInfo.damagedListWordCount)
                        == ShockwaveInfo.damagedListWordCount,
                "\(name) shockwave"
            )
            if let shockwave = object.shockwave {
                try shockwave.validateSavedValues(rules)
            }
            if let dying = object.dying {
                try dying.validateSavedValues(rules)
                try require(
                    object.flags & GameObject.dyingFlag != 0,
                    "\(name) dying"
                )
            }
            // A weapon keeps its lifetime (OF_USES_LIFELEFT), which the
            // object frame counts down.
            if object.type == .weapon {
                try require(object.lifeLeft != nil, "\(name) lifeleft")
            }
            if let lifeLeft = object.lifeLeft {
                try rules.number(lifeLeft, name)
            }
            if let info = object.info {
                try require(
                    level.objectInfos?.indices.contains(info) == true,
                    "\(name) info"
                )
            }
            if let weapon = object.weapon {
                try require(
                    object.type == .weapon
                        && level.weapons?.indices.contains(weapon) == true,
                    "\(name) weapon"
                )
            }
            // A weapon's particle clock, its link to the object it stuck
            // to (a well-formed handle, a submodel DoPhysLinkedFrame checks,
            // and a nonzero heading), and the portal it stuck on (a level
            // room's portal, with OF_STUCK_ON_PORTAL).
            if let dropTime = object.lastDropTime {
                try rules.number(dropTime, name)
            }
            if let link = object.objectLink {
                try rules.vector(link.position, name)
                try rules.vector(link.forward, name)
                try rules.vector(link.up, name)
                guard D3SourceIdentity.isValidHandle(link.parentHandle.rawValue)
                else {
                    throw .objectReference(link.parentHandle.rawValue)
                }
                try require(
                    object.type == .weapon && !object.usesPhysics
                        && link.submodel >= 0
                        && levelDot(link.forward, link.forward) > 0,
                    "\(name) objectLink"
                )
            }
            try require(
                (object.stuckPortal != nil)
                    == (object.flags & GameObject.stuckOnPortalFlag != 0)
                    && object.stuckPortal.map { stuck in
                        level.rooms.first {
                            $0.sourceIndex == stuck.roomSourceIndex
                        }.map { $0.portals.indices.contains(stuck.portal) }
                            == true
                    } != false,
                "\(name) stuckPortal"
            )
            let modelBatteries = object.info == nil
                ? []
                : level.polygonModel(of: object)?.weaponBatteries
                    ?? []
            // An AI object has one dynamic battery per model battery
            // (WBClearInfo, ObjInit.cpp:815-817), which ai_fire indexes;
            // the player has MAX_WBS_PER_OBJ, one per ship battery, which
            // its fire indexes; any other object has none.
            let isBoundPlayer = object.handle.rawValue
                == level.defaultPlayerBinding?.objectHandle
            let pageBatteries = object.info.flatMap {
                level.objectInfos?[$0].weaponBatteries
            } ?? []
            let shipBatteries = level.defaultPlayerBinding.flatMap { binding in
                level.shipDefinitions.first { $0.source == binding.ship }
            }?.weaponBatteries ?? []
            func fireMaskCount(_ index: Int) -> Int {
                if isBoundPlayer {
                    return shipBatteries.first { $0.index == index }?
                        .battery.fireMasks.count ?? 1
                }
                return pageBatteries.indices.contains(index)
                    ? pageBatteries[index].fireMasks.count : 1
            }
            try require(
                isBoundPlayer
                    ? object.weaponBatteries.count
                        == PlayerWeaponState.maximumPlayerWeapons
                    : object.ai != nil
                        ? object.weaponBatteries.count == modelBatteries.count
                        : object.weaponBatteries.isEmpty,
                "\(name) weaponBatteries"
            )
            for (index, battery) in object.weaponBatteries.enumerated() {
                try rules.number(battery.lastFireTime, name)
                try require(
                    battery.turretAngles.count
                        == DynamicWeaponBattery.maximumTurrets
                        && battery.turretNextThinkTimes.count
                            == DynamicWeaponBattery.maximumTurrets
                        && battery.turretDirections.count
                            == DynamicWeaponBattery.maximumTurrets
                        && battery.turretAngles.allSatisfy {
                            (0...1).contains($0)
                        }
                        && battery.turretDirections.allSatisfy { $0 <= 2 }
                        && battery.currentFiringMask >= 0
                        && battery.currentFiringMask
                            < max(1, fireMaskCount(index)),
                    "\(name) weapon battery \(index)"
                )
                for time in battery.turretNextThinkTimes {
                    try rules.number(time, name)
                }
            }
            guard let ai = object.ai else { continue }
            try require(
                object.info.flatMap({ level.objectInfos?[$0].ai }) != nil,
                "\(name) ai"
            )
            try ai.validateSavedValues(rules)
            try require(
                ai.goals.count == ObjectAIFrame.maximumGoals
                    && ai.memory.count == ObjectAIFrame.memoryDepth,
                "\(name) ai arrays"
            )
            for goal in ai.goals where goal.used {
                let translatedTypes: [UInt32] = [
                    AIGoal.followPathType, AIGoal.getToObjectType,
                    AIGoal.getToPositionType, Self.guardAreaGoalType,
                    AIGoal.moveRelativeObjectType,
                    AIGoal.moveRelativeObjectVectorType,
                    AIGoal.getAroundObjectType,
                ]
                // A circle distance of 0 is valid page data; ai_move's
                // blend handles the 0/0 it gives (AImain.cpp:4649, :4980).
                try require(
                    translatedTypes.contains(goal.type)
                        && goal.circleDistance.isFinite
                        && goal.enablers.count <= AIGoal.maximumEnablers
                        && goal.enablers.allSatisfy {
                            (AIGoalEnabler.near...AIGoalEnabler.clearTime)
                                .contains($0.type)
                                && ![AIGoalEnabler.fear, AIGoalEnabler.angry,
                                     AIGoalEnabler.curious,
                                     AIGoalEnabler.frustrated]
                                    .contains($0.type)
                        }
                        && (goal.type != AIGoal.followPathType
                            || (pathNodeIsValid(
                                    goal.pathID,
                                    goal.staticPathCurrentNode
                                )
                                && pathNodeIsValid(
                                    goal.pathID,
                                    goal.staticPathStartNode
                                )
                                && pathNodeIsValid(
                                    goal.pathID,
                                    goal.staticPathEndNode
                                ))),
                    "\(name) goal"
                )
            }
            let path = ai.path
            try require(
                (0...1).contains(path.numberOfPaths)
                    && (path.numberOfPaths == 1 || !path.isDynamic),
                "\(name) path"
            )
            if path.numberOfPaths == 1 {
                let nodesAreValid = path.isDynamic
                    ? path.dynamicNodes.indices.contains(path.currentNode)
                        && path.dynamicNodes.indices.contains(path.startNode)
                        && path.dynamicNodes.indices.contains(path.endNode)
                    : pathNodeIsValid(path.pathID, path.currentNode)
                        && pathNodeIsValid(path.pathID, path.startNode)
                        && pathNodeIsValid(path.pathID, path.endNode)
                try require(
                    nodesAreValid
                        && path.startNode <= path.endNode
                        && (0..<ObjectAIFrame.maximumGoals)
                            .contains(path.goalIndex),
                    "\(name) path"
                )
            }
        }
    }
}

struct SavedValueRules {
    let roomSourceIndices: Set<Int>

    func number(
        _ value: Float,
        _ name: String
    ) throws(GameWorldValidationError) {
        guard value.isFinite else { throw .nonFiniteValue(name) }
        guard abs(value) <= maximumSavedMagnitude else {
            throw .outOfDomain(name)
        }
    }

    func vector(
        _ value: Vector3,
        _ name: String
    ) throws(GameWorldValidationError) {
        guard isFinite(value) else { throw .nonFiniteValue(name) }
        guard abs(value.x) <= maximumSavedMagnitude,
              abs(value.y) <= maximumSavedMagnitude,
              abs(value.z) <= maximumSavedMagnitude
        else {
            throw .outOfDomain(name)
        }
    }

    func room(_ value: Int, _ name: String) throws(GameWorldValidationError) {
        guard roomSourceIndices.contains(value) else {
            throw .roomReference(name)
        }
    }

    func handleShape(_ value: ObjectHandle) throws(GameWorldValidationError) {
        guard value == .none
                || D3SourceIdentity.isValidHandle(value.rawValue)
        else {
            throw .objectReference(value.rawValue)
        }
    }
}

extension GameWorld {
    fileprivate func validateWorldValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        try rules.number(frameDuration, "frameDuration")
        try rules.number(gameTime, "gameTime")
        for room in rooms {
            try rules.number(room.lastRenderTime, "lastRenderTime")
        }
        try rules.vector(velocity, "velocity")
        try rules.vector(angularVelocity, "angularVelocity")
        try rules.number(turnrollFixedAngle, "turnrollFixedAngle")
        try rules.number(afterburnerFuel, "afterburnerFuel")
        try rules.number(energy, "energy")
        try rules.number(shields, "shields")
        try rules.number(afterburnerMagnitude, "afterburnerMagnitude")
        try rules.number(wiggleFalloff, "wiggleFalloff")
        try rules.number(lastThrustTime, "lastThrustTime")
        if let rearView = playerRearViewState {
            try rules.number(rearView.entryGameTime, "entryGameTime")
        }
        for weapon in playerWeapons {
            try rules.number(weapon.firingTime, "firingTime")
        }
        for effect in visEffects {
            try effect.validateSavedValues(rules)
        }
        for event in gameEvents {
            try event?.validateSavedValues(rules)
        }
        if let time = playerInvulnerableTime {
            try rules.number(time, "playerInvulnerableTime")
        }
        if let death = playerDeath {
            try rules.handleShape(death.killer)
            try rules.number(death.initialDeathTime, "initialDeathTime")
        }
        for item in playerInventory.items {
            if let object = item.object { try rules.handleShape(object) }
        }
        try rules.handleShape(buddyHandle)
        for loop in soundSystem.objectLoops {
            try rules.handleShape(loop.object)
        }
        for handle in aiRenderedList {
            try rules.handleShape(handle)
        }
        if let camera = lastRenderCamera {
            try rules.vector(camera.position, "position")
            try rules.vector(camera.target, "target")
            try rules.vector(camera.up, "up")
            try rules.number(
                camera.projection.horizontalFieldOfViewRadians,
                "horizontalFieldOfViewRadians"
            )
            try rules.number(camera.projection.aspectRatio, "aspectRatio")
        }
        try levelModule.validateSavedValues(rules)
        for timer in osirisTimers.entries {
            try timer.validateSavedValues(rules)
        }
        for view in smallViews + savedSmallViews {
            try view.validateSavedValues(rules)
        }
    }
}

extension VisEffect {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        try rules.room(roomSourceIndex, "roomSourceIndex")
        try rules.vector(position, "position")
        try rules.vector(endPosition, "endPosition")
        try rules.vector(velocity, "velocity")
        try rules.number(mass, "mass")
        try rules.number(drag, "drag")
        try rules.number(size, "size")
        try rules.number(lifeLeft, "lifeLeft")
        try rules.number(lifetime, "lifetime")
        try rules.number(creationTime, "creationTime")
        if let attachedObject { try rules.handleShape(attachedObject) }
    }
}

extension GameEvent {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        try rules.number(startTime, "startTime")
        try rules.number(endTime, "endTime")
        if let detonator { try rules.handleShape(detonator) }
        switch action {
        case let .explosion(position, _, room, size, upwardsVelocity):
            try rules.vector(position, "position")
            try rules.room(room, "roomSourceIndex")
            try rules.number(size, "size")
            try rules.number(upwardsVelocity, "upwardsVelocity")
        case let .blastRing(position, size, room):
            try rules.vector(position, "position")
            try rules.number(size, "size")
            try rules.room(room, "roomSourceIndex")
        }
    }
}

extension OsirisTimer {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        if let detonator { try rules.handleShape(detonator) }
        if isUsed, case let .object(handle) = owner {
            try rules.handleShape(handle)
        }
        try rules.number(interval, "interval")
        try rules.number(nextSignal, "nextSignal")
        try rules.number(end, "end")
    }
}

extension SmallView {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        try rules.handleShape(viewer)
        try rules.number(timer, "timer")
        try rules.number(zoom, "zoom")
    }
}

extension ShockwaveInfo {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        try rules.number(size, "size")
        try rules.number(time, "time")
        try rules.number(playerDamage, "playerDamage")
        try rules.number(genericDamage, "genericDamage")
        try rules.number(force, "force")
    }
}

extension ObjectDyingInfo {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        try rules.number(delayTime, "delayTime")
        try rules.number(lastSparkTime, "lastSparkTime")
        try rules.number(lastFireballTime, "lastFireballTime")
        try rules.number(lastSmokeTime, "lastSmokeTime")
    }
}

extension ObjectAIFrame {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        for node in path.dynamicNodes {
            try rules.vector(node.position, "position")
            try rules.room(node.roomSourceIndex, "roomSourceIndex")
        }
        try rules.number(maxVelocity, "maxVelocity")
        try rules.number(maxDeltaVelocity, "maxDeltaVelocity")
        try rules.number(maxTurnRate, "maxTurnRate")
        try rules.number(maxDeltaTurnRate, "maxDeltaTurnRate")
        try rules.number(circleDistance, "circleDistance")
        for goal in goals {
            try goal.validateSavedValues(rules)
        }
        try rules.handleShape(targetHandle)
        try rules.number(nextTargetUpdateTime, "nextTargetUpdateTime")
        try rules.number(distToTargetActual, "distToTargetActual")
        try rules.number(distToTargetPerceived, "distToTargetPerceived")
        try rules.vector(vecToTargetActual, "vecToTargetActual")
        try rules.vector(vecToTargetPerceived, "vecToTargetPerceived")
        try rules.number(nextCheckSeeTargetTime, "nextCheckSeeTargetTime")
        try rules.vector(lastSeeTargetPosition, "lastSeeTargetPosition")
        try rules.number(lastSeeTargetTime, "lastSeeTargetTime")
        try rules.number(lastHearTargetTime, "lastHearTargetTime")
        try rules.number(weaponSpeed, "weaponSpeed")
        try rules.number(lastRenderTime, "lastRenderTime")
        try rules.number(fov, "fov")
        try rules.number(aggression, "aggression")
        try rules.number(lifePreservation, "lifePreservation")
        try rules.number(
            memoryTimeUntilNextUpdate, "memoryTimeUntilNextUpdate"
        )
        for slot in memory {
            try rules.number(slot.shields, "shields")
        }
        try rules.number(fireSpread, "fireSpread")
        try rules.number(leadAccuracy, "leadAccuracy")
        try rules.number(attackVelocityPercent, "attackVelocityPercent")
        try rules.number(dodgeVelocityPercent, "dodgeVelocityPercent")
        try rules.number(fleeVelocityPercent, "fleeVelocityPercent")
        try rules.number(fightTeam, "fightTeam")
        try rules.number(fightSame, "fightSame")
        try rules.number(nextFlinchTime, "nextFlinchTime")
        try rules.vector(movementDirection, "movementDirection")
        try rules.number(awareness, "awareness")
        try rules.number(avoidFriendsDistance, "avoidFriendsDistance")
    }
}

extension AIGoal {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        try rules.number(influence, "influence")
        try rules.number(creationTime, "creationTime")
        try rules.number(startTime, "startTime")
        try rules.number(circleDistance, "circleDistance")
        try rules.number(nextPathTime, "nextPathTime")
        try rules.number(distanceToGoal, "distanceToGoal")
        try rules.handleShape(objectHandle)
        try rules.vector(position, "position")
        if let roomSourceIndex {
            try rules.room(roomSourceIndex, "roomSourceIndex")
        }
        for enabler in enablers {
            try rules.number(enabler.value, "value")
            try rules.number(enabler.percent, "percent")
            try rules.number(enabler.checkInterval, "checkInterval")
            try rules.number(enabler.lastCheckTime, "lastCheckTime")
        }
    }
}

extension DallasState {
    func validateSavedValues(
        _ rules: SavedValueRules
    ) throws(GameWorldValidationError) {
        for userVar in userVars {
            if case let .float(value) = userVar {
                try rules.number(value, "userVars")
            }
        }
        for handle in savedObjectHandles {
            try rules.handleShape(handle)
        }
    }
}

struct GameSaveFile: Sendable {
    let rootURL: URL

    static let revivalMac = Self(
        rootURL: URL.applicationSupportDirectory
            .appending(path: "Descent3Revival", directoryHint: .isDirectory)
            .appending(path: "RevivalMac", directoryHint: .isDirectory)
            .appending(path: "Saves", directoryHint: .isDirectory)
    )

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func quicksaveURL(profileID: UUID) -> URL {
        profileDirectoryURL(profileID: profileID).appending(path: quicksaveName)
    }

    /// Writes the save durably: the bytes go to a temporary file in the same
    /// folder, are flushed, and then atomically replace the previous save.
    /// An interrupted write leaves the previous save readable.
    func save(
        profileID: UUID,
        package: CanonicalPackageReference,
        world: GameWorld,
        level: Level
    ) throws {
        do {
            try package.validate()
        } catch {
            throw GameSaveError.packageMismatch
        }
        guard level.levelKey == package.levelKey else {
            throw GameSaveError.packageMismatch
        }
        do {
            try world.validate(against: level)
        } catch {
            throw GameSaveError.invalidWorld(error)
        }

        let profileURL = profileDirectoryURL(profileID: profileID)
        let saveURL = quicksaveURL(profileID: profileID)
        let temporaryURL = profileURL.appending(
            path: ".\(quicksaveName).\(UUID().uuidString).tmp"
        )
        do {
            try ensureOwnedDirectory(rootURL, createIntermediates: true)
            try ensureOwnedDirectory(profileURL, createIntermediates: false)
            if FileManager.default.fileExists(atPath: saveURL.path) {
                try requireRegularSaveFile(saveURL)
            }
            let data = try canonicalJSONData(GameSave(
                profileID: profileID,
                package: package,
                world: world
            ))
            guard data.count <= maximumGameSaveByteCount else {
                throw GameSaveError.tooLarge
            }
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            try data.write(to: temporaryURL, options: .withoutOverwriting)
            let handle = try FileHandle(forWritingTo: temporaryURL)
            try handle.synchronize()
            try handle.close()
            guard rename(temporaryURL.path, saveURL.path) == 0 else {
                throw GameSaveError.writeFailed(
                    String(cString: strerror(errno))
                )
            }
        } catch let error as GameSaveError {
            throw error
        } catch {
            throw GameSaveError.writeFailed(error.localizedDescription)
        }
    }

    func load(
        profileID: UUID,
        package: CanonicalPackageReference,
        baseLevel: Level,
        resumedAtTimestamp: Double
    ) throws -> GameSession {
        let profileURL = profileDirectoryURL(profileID: profileID)
        let saveURL = quicksaveURL(profileID: profileID)
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            throw GameSaveError.missingSave
        }
        do {
            try requireOwnedDirectory(rootURL)
            try requireOwnedDirectory(profileURL)
            try requireRegularSaveFile(saveURL)
        } catch let error as GameSaveError {
            throw error
        } catch {
            throw GameSaveError.readFailed(error.localizedDescription)
        }

        let data: Data
        do {
            data = try Data(contentsOf: saveURL)
        } catch {
            throw GameSaveError.readFailed(error.localizedDescription)
        }
        guard data.count <= maximumGameSaveByteCount else {
            throw GameSaveError.tooLarge
        }
        struct SchemaHeader: Decodable {
            let schemaVersion: Int
        }
        let decoder = JSONDecoder()
        let header: SchemaHeader
        do {
            header = try decoder.decode(SchemaHeader.self, from: data)
        } catch {
            throw GameSaveError.malformedSave
        }
        guard header.schemaVersion == GameSave.currentSchemaVersion else {
            throw GameSaveError.unsupportedSaveSchema(header.schemaVersion)
        }

        let save: GameSave
        do {
            save = try decoder.decode(GameSave.self, from: data)
            try save.package.validate()
        } catch {
            throw GameSaveError.malformedSave
        }
        guard save.profileID == profileID else {
            throw GameSaveError.profileMismatch
        }
        guard save.package == package,
              baseLevel.levelKey == package.levelKey
        else {
            throw GameSaveError.packageMismatch
        }
        do {
            return try GameSession(
                level: baseLevel,
                world: save.world,
                resumedAtTimestamp: resumedAtTimestamp
            )
        } catch let GameSessionRestoreError.invalidWorld(error) {
            throw GameSaveError.invalidWorld(error)
        }
    }

    private func profileDirectoryURL(profileID: UUID) -> URL {
        rootURL.appending(
            path: profileID.uuidString.lowercased(),
            directoryHint: .isDirectory
        )
    }

    private func ensureOwnedDirectory(
        _ url: URL,
        createIntermediates: Bool
    ) throws {
        do {
            // A second save for the same pilot finds the folder in place.
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: createIntermediates
                )
            }
            try requireOwnedDirectory(url)
        } catch let error as GameSaveError {
            throw error
        } catch {
            throw GameSaveError.writeFailed(error.localizedDescription)
        }
    }

    private func requireOwnedDirectory(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true,
              values.isSymbolicLink != true else {
            throw GameSaveError.nonRegularFile
        }
    }

    private func requireRegularSaveFile(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        )
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let byteCount = values.fileSize else {
            throw GameSaveError.nonRegularFile
        }
        guard byteCount <= maximumGameSaveByteCount else {
            throw GameSaveError.tooLarge
        }
    }
}
