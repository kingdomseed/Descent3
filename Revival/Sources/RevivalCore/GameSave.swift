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
/// The largest effect creation ordinal a save may hold. A session creates
/// far fewer effects, and the per-frame increments cannot overflow from it.
private let maximumSavedCreationOrdinal: UInt64 = 1 << 48

struct GameSave: Codable, Equatable, Sendable {
    /// Schema 2 replaces player save schema 1, which wrapped continuation
    /// schema 7.
    static let currentSchemaVersion = 2

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
                  saved.items.count == canonical.items.count
                      && zip(saved.items, canonical.items).allSatisfy {
                          $0.objectHandle == $1.objectHandle
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

        let sweep = NestedStateSweep(roomSourceIndices: roomSourceIndices)
        for child in Mirror(reflecting: self).children
        where !["objects", "rooms", "goals"].contains(child.label) {
            try sweep.visit(child.value, label: child.label ?? "")
        }
        try validateStateDefinitions(level: level)
        try validateScriptState(level: level)
        try validateObjectRuntimeState(level: level)
        try validateIndicesAndCapacities(level: level)
        try validateNumericDomains(level: level)
    }

    /// Script and weapon state exists only when the level or ship defines
    /// it, as `GameWorld(level:)` creates it. The runtime force-unwraps the
    /// definition of any state it finds.
    private func validateStateDefinitions(
        level: Level
    ) throws(GameWorldValidationError) {
        let pairs: [(String, Bool, Bool)] = [
            ("playerYellowFlareState", playerYellowFlareState != nil,
             level.shipDefinitions.first?.playerYellowFlare != nil),
            ("trainingGalleryBarrierState",
             trainingGalleryBarrierState != nil,
             level.trainingGalleryBarrier != nil),
            ("trainingRobotGuidebotState",
             trainingRobotGuidebotState != nil,
             level.trainingRobotGuidebotChain != nil),
            ("trainingCameraMonitorState",
             trainingCameraMonitorState != nil,
             level.trainingCameraMonitorChain != nil),
            ("trainingKillbotEntryState", trainingKillbotEntryState != nil,
             level.trainingCameraMonitorChain?.returnToShip?.killbotEntry
                != nil),
            ("trainingInvulnerabilityPickupState",
             trainingInvulnerabilityPickupState != nil,
             level.trainingInvulnerabilityPickupChain != nil),
            ("trainingCloakPickupState", trainingCloakPickupState != nil,
             level.trainingCloakPickupChain != nil),
            ("trainingFinalRoomEntryState",
             trainingFinalRoomEntryState != nil,
             level.trainingFinalRoomEntryChain != nil),
            ("trainingFinalGoalState", trainingFinalGoalState != nil,
             level.trainingFinalGoalChain != nil),
        ]
        for (name, hasState, hasDefinition) in pairs
        where hasState && !hasDefinition {
            throw .unexpectedState(name)
        }
    }

    /// Osiris and object script state: the level module is the one the
    /// level names, timer handles name their entries, ghost and lighting
    /// fields are consistent, and no presentation request is pending.
    private func validateScriptState(
        level: Level
    ) throws(GameWorldValidationError) {
        func require(_ condition: Bool, _ name: String)
            throws(GameWorldValidationError)
        {
            if !condition { throw .unexpectedState(name) }
        }
        try require(presentationRequests.isEmpty, "presentationRequests")
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
            // Bound scripts are exactly the ones the level module gives.
            try require(
                object.scripts == osirisScripts(for: object, level: level),
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
        // The player flare timeout reads the parent's creation ordinal
        // without a check.
        try require(
            playerYellowFlareState?.parents.allSatisfy {
                $0.creationOrdinal != nil
            } ?? true,
            "playerYellowFlareState.parents.creationOrdinal"
        )
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
        if let state = playerYellowFlareState {
            try limit(
                state.parents.count,
                playerYellowFlarePresentationCapacity,
                "playerYellowFlareState.parents"
            )
            try limit(
                state.parentParticles.count,
                playerYellowFlareParticlePresentationCapacity,
                "playerYellowFlareState.parentParticles"
            )
            try limit(
                state.timeoutExplosions.count,
                playerYellowFlareTimeoutExplosionPresentationCapacity,
                "playerYellowFlareState.timeoutExplosions"
            )
            try limit(
                state.timeoutSparks.count,
                playerYellowFlareTimeoutSparkPresentationCapacity,
                "playerYellowFlareState.timeoutSparks"
            )
            try limit(
                state.timeoutSparkParticles.count,
                playerYellowFlareTimeoutSparkParticlePresentationCapacity,
                "playerYellowFlareState.timeoutSparkParticles"
            )
        }
        if let state = trainingRobotGuidebotState {
            try limit(
                state.yellowFlares?.count ?? 0,
                trainingGuidebotYellowFlarePresentationCapacity,
                "trainingRobotGuidebotState.yellowFlares"
            )
            try limit(
                state.yellowFlareParticles?.count ?? 0,
                trainingGuidebotYellowFlareParticlePresentationCapacity,
                "trainingRobotGuidebotState.yellowFlareParticles"
            )
            try limit(
                state.yellowFlareTimeoutExplosions?.count ?? 0,
                trainingGuidebotYellowFlareTimeoutExplosionPresentationCapacity,
                "trainingRobotGuidebotState.yellowFlareTimeoutExplosions"
            )
            try limit(
                state.yellowFlareTimeoutSparks?.count ?? 0,
                trainingGuidebotYellowFlareTimeoutSparkPresentationCapacity,
                "trainingRobotGuidebotState.yellowFlareTimeoutSparks"
            )
            try limit(
                state.yellowFlareTimeoutSparkParticles?.count ?? 0,
                trainingGuidebotYellowFlareTimeoutSparkParticlePresentationCapacity,
                "trainingRobotGuidebotState.yellowFlareTimeoutSparkParticles"
            )
            if let guidebot = state.guidebot {
                try require(
                    guidebot.route.points.indices
                        .contains(guidebot.routePointIndex),
                    "guidebot.routePointIndex"
                )
                let navigation = Dictionary(
                    (level.indoorNavigation?.rooms ?? []).map {
                        ($0.sourceIndex, $0.nodes.count)
                    },
                    uniquingKeysWith: { first, _ in first }
                )
                try require(
                    guidebot.route.nodeReferences.allSatisfy {
                        (0..<(navigation[$0.roomSourceIndex] ?? 0))
                            .contains($0.nodeIndex)
                    },
                    "guidebot.route.nodeReferences"
                )
            }
        }
    }

    /// The per-object runtime state: object_info and weapon indices name
    /// the level's tables, an AI frame belongs to a CT_AI page and keeps its
    /// fixed arrays, goal and path nodes name game path nodes, weapon
    /// batteries match the model, turret angles stay in 0...1 (ai_fire
    /// wraps them), and every float and vector is finite and in range.
    private func validateObjectRuntimeState(
        level: Level
    ) throws(GameWorldValidationError) {
        func require(_ condition: Bool, _ name: String)
            throws(GameWorldValidationError)
        {
            if !condition { throw .indexOutOfRange(name) }
        }
        let sweep = NestedStateSweep(
            roomSourceIndices: Set(level.rooms.map(\.sourceIndex))
        )
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
        for object in objects {
            let name = "object \(object.handle.slot)"
            try sweep.visit(object.size, label: name)
            try sweep.visit(object.shields, label: name)
            try sweep.visit(object.velocity, label: name)
            try sweep.visit(object.lastPosition, label: name)
            try sweep.visit(object.creationTime, label: name)
            try require(object.size >= 0, name)
            // Stored handles are well formed; they may name an object that
            // has since been deleted, which the runtime looks up optionally.
            for handle in [object.parent, object.attachUltimateHandle]
            where handle != .none {
                guard D3SourceIdentity.isValidHandle(handle.rawValue) else {
                    throw .objectReference(handle.rawValue)
                }
            }
            try require(
                (object.shockwave != nil) == (object.type == .shockwave)
                    && (object.shockwave?.damagedList.count
                        ?? ShockwaveInfo.damagedListWordCount)
                        == ShockwaveInfo.damagedListWordCount,
                "\(name) shockwave"
            )
            if let shockwave = object.shockwave {
                try sweep.visit(shockwave, label: name)
            }
            if let dying = object.dying {
                try sweep.visit(dying, label: name)
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
                try sweep.visit(lifeLeft, label: name)
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
            let modelBatteries = object.info == nil
                ? []
                : level.placedObjectModel(object.handle)?.weaponBatteries
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
                try sweep.visit(battery.lastFireTime, label: name)
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
                    try sweep.visit(time, label: name)
                }
            }
            guard let ai = object.ai else { continue }
            try require(
                object.info.flatMap({ level.objectInfos?[$0].ai }) != nil,
                "\(name) ai"
            )
            try sweep.visit(ai, label: name)
            try require(
                ai.goals.count == ObjectAIFrame.maximumGoals
                    && ai.memory.count == ObjectAIFrame.memoryDepth,
                "\(name) ai arrays"
            )
            for goal in ai.goals where goal.used {
                try require(
                    goal.type == AIGoal.followPathType
                        && pathNodeIsValid(
                            goal.pathID,
                            goal.staticPathCurrentNode
                        )
                        && pathNodeIsValid(
                            goal.pathID,
                            goal.staticPathStartNode
                        )
                        && pathNodeIsValid(goal.pathID, goal.staticPathEndNode),
                    "\(name) goal"
                )
            }
            let path = ai.path
            try require(
                (0...1).contains(path.numberOfPaths),
                "\(name) path"
            )
            if path.numberOfPaths == 1 {
                try require(
                    pathNodeIsValid(path.pathID, path.currentNode)
                        && pathNodeIsValid(path.pathID, path.startNode)
                        && pathNodeIsValid(path.pathID, path.endNode)
                        && path.startNode <= path.endNode
                        && (0..<ObjectAIFrame.maximumGoals)
                            .contains(path.goalIndex),
                    "\(name) path"
                )
            }
        }
    }
}

/// One reflective pass over the nested saved state. It checks what the
/// runtime assumes of every value of a kind, wherever the value lives:
/// orientations are orthonormal bases, vectors and floats are finite, room
/// references name a level room, and stored object handles are well formed.
/// Stored handles may name an object that has since been deleted, because
/// the runtime looks them up optionally.
private struct NestedStateSweep {
    let roomSourceIndices: Set<Int>

    func visit(_ value: Any, label: String) throws(GameWorldValidationError) {
        switch value {
        case let orientation as Matrix3:
            guard isCanonicalRigidTransform(
                position: .zero,
                orientation: orientation
            ) else {
                throw .orientation(label)
            }
            return
        case let vector as Vector3:
            guard isFinite(vector) else { throw .nonFiniteValue(label) }
            guard abs(vector.x) <= maximumSavedMagnitude,
                  abs(vector.y) <= maximumSavedMagnitude,
                  abs(vector.z) <= maximumSavedMagnitude
            else {
                throw .outOfDomain(label)
            }
            return
        case let scalar as Float:
            guard scalar.isFinite else { throw .nonFiniteValue(label) }
            guard abs(scalar) <= maximumSavedMagnitude else {
                throw .outOfDomain(label)
            }
            return
        case let room as Int
            where label == "roomSourceIndex" || label.hasSuffix("RoomSourceIndex"):
            guard roomSourceIndices.contains(room) else {
                throw .roomReference(label)
            }
            return
        case let rooms as [Int] where label == "roomSourceIndices":
            guard rooms.allSatisfy(roomSourceIndices.contains) else {
                throw .roomReference(label)
            }
            return
        case let counter as Int where label.wholeMatch(
            of: /script\d+Count|scriptActionCounter/
        ) != nil:
            // Released scripts cap action counters at MAX_ACTION_CTR_VALUE
            // (TrainingMission.cpp:251).
            guard (0...trainingScriptActionCounterMaximum).contains(counter)
            else {
                throw .outOfDomain(label)
            }
            return
        case let ordinal as UInt64
            where label == "nextCreationOrdinal":
            guard ordinal <= maximumSavedCreationOrdinal else {
                throw .outOfDomain(label)
            }
            return
        case let handle as UInt32 where label.hasSuffix("Handle"):
            guard D3SourceIdentity.isValidHandle(handle) else {
                throw .objectReference(handle)
            }
            return
        case let handles as Set<UInt32> where label.hasSuffix("Handles"):
            for handle in handles.sorted()
            where !D3SourceIdentity.isValidHandle(handle) {
                throw .objectReference(handle)
            }
            return
        default:
            break
        }
        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            // Optional and collection elements keep their field's label.
            let childLabel = mirror.displayStyle == .optional
                || mirror.displayStyle == .collection
                || mirror.displayStyle == .set
                ? label
                : child.label ?? label
            try visit(child.value, label: childLabel)
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
