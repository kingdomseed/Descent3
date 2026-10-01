// SPDX-License-Identifier: GPL-3.0-or-later
//
// The engine functions the game-module scripts call through Osiris.
// Translated from Descent3/osiris_predefs.cpp (Descent 3, Copyright (C)
// 2024 Parallax Software, GPL-3.0-or-later): osipf_CallObjectEvent
// (:481), osipf_RoomValue (:616, the path, face, and damage values),
// osipf_PlayerValue (:731, the flags and buddy handle), osipf_ObjectFindID
// (:919), osipf_WeaponFindID (:933), osipf_AIValue (:947, the flags and
// speeds), osipf_ObjectValue (:1355, the fields the scripts read and set),
// osipf_AITurnTowardsVectors (:1636), osipf_AISetType (:1655),
// osipf_AIGoalAdd (:1730), osipf_AIFindObjOfType (:1925) with
// AIFindObjOfType (AImain.cpp:6307), osipf_ObjMakeListOfType (:1940),
// osipf_AIFindEnergyCenter (:2000) with AIFindRoomWithFlag
// (AImain.cpp:6256), osipf_AISetGoalCircleDist (:2058), osipf_RayCast
// (:2398), osipf_ObjCreate (:2570), osipf_ObjWBValue (:2637, the dynamic
// flags), osipf_PlayerAddHudMessage (:2830), osipf_ObjGhost (:2841),
// osipf_SoundPlay2d and osipf_SoundPlay3d (:2918, :2939), osipf_SoundFindId
// (:2956), osipf_AIIsObjEnemy (:2968), osipf_AIGoalValue (:2978, the used
// flag, circle distance, and status), osipf_AIGetNearbyObjs (:3319) with
// fvi_QuickDistObjectList (physics/findintersection.cpp:2108),
// osipf_LGoalValue (:3482) with levelgoals::GetNumActivePrimaryGoals and
// GetNumActiveSecondaryGoals (Descent3/levelgoal.cpp:955, :1010), and
// osipf_AIIsDestReachable and osipf_AIIsObjReachable (:3644, :3653) with
// AIFindAltPath (Descent3/aipath.cpp:62).
//
// Accepted differences (architecture.md section 9): reachability and the
// nearest-object searches use the reciprocal-portal room route of BOA.swift
// with portal path point distances, not the cached BOA cost tables, so
// AIFindAltPath's cost jitter draws no ps_rand; a ray cast traces the walls
// only; and the quick object list takes a room's objects in slot order.

import Foundation

extension GameWorld {
    /// The identity matrix, as an object with a NULL orientation gets.
    static let identityOrientation = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )

    // MARK: Names

    /// osipf_ObjectFindID (:919): the object page with this name (stricmp),
    /// or -1. The level's object tables hold the pages it can use.
    func objectFindID(_ name: String, level: Level) -> Int {
        level.objectInfos?.firstIndex {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        } ?? -1
    }

    /// osipf_WeaponFindID (:933): the weapon page with this name, or -1.
    func weaponFindID(_ name: String, level: Level) -> Int {
        level.weapons?.firstIndex {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        } ?? -1
    }

    /// osipf_SoundFindId (:2956): the sound with this page name, or -1.
    func soundFindID(_ name: String, level: Level) -> Int {
        level.findSoundName(name)
    }

    // MARK: Object values (osipf_ObjectValue, :1355)

    /// OBJV_I_TYPE: the type, or nil (OBJ_NONE) for a stale handle.
    func objectType(_ handle: ObjectHandle) -> ObjectType? {
        objects[handle]?.type
    }

    /// OBJV_US_ID: a generic object's page, a weapon's weapon page, or the
    /// player number (single player: 0). Nil for a stale handle or an
    /// object with no id.
    func objectID(_ handle: ObjectHandle) -> Int? {
        guard let object = objects[handle] else { return nil }
        if object.type == .player || object.dummyType == .player { return 0 }
        return object.info ?? object.weapon
    }

    /// OBJV_I_ROOMNUM set: ObjSetPos in the new room.
    mutating func setObjectRoom(_ handle: ObjectHandle, _ room: Int) {
        objects[handle]?.location = .room(room)
    }

    /// OBJV_V_POS set: ObjSetPos in the object's room.
    mutating func setObjectPosition(_ handle: ObjectHandle, _ position: Vector3) {
        objects[handle]?.position = position
    }

    /// OBJV_M_ORIENT set.
    mutating func setObjectOrientation(
        _ handle: ObjectHandle,
        _ orientation: Matrix3
    ) {
        objects[handle]?.orientation = orientation
    }

    /// OBJV_V_VELOCITY: `mtype.phys_info.velocity`. The player's velocity
    /// is the ship's.
    func objectVelocity(_ handle: ObjectHandle) -> Vector3 {
        objects[handle].map(objectVelocity) ?? .zero
    }

    /// OBJV_V_VELOCITY set.
    mutating func setObjectVelocity(_ handle: ObjectHandle, _ velocity: Vector3) {
        guard let object = objects[handle] else { return }
        if object.type == .player {
            self.velocity = velocity
        } else {
            objects[handle]?.velocity = velocity
        }
    }

    /// OBJV_F_CREATION_TIME set (MSAFE_OBJECT_CREATION_TIME,
    /// multisafe.cpp:2287).
    mutating func setObjectCreationTime(_ handle: ObjectHandle, _ time: Float) {
        objects[handle]?.creationTime = time
    }

    /// OBJV_I_PARENT_HANDLE set (MSAFE_OBJECT_PARENT, multisafe.cpp:2308).
    mutating func setObjectParent(_ handle: ObjectHandle, _ parent: ObjectHandle) {
        objects[handle]?.parent = parent
    }

    /// OBJV_I_FLAGS set, set flags, or clear flags (MSAFE_OBJECT_FLAGS,
    /// multisafe.cpp:2261).
    mutating func setObjectFlags(_ handle: ObjectHandle, _ flags: UInt32) {
        objects[handle]?.flags = flags
    }

    /// The distance between two objects' centers, less both sizes when
    /// `subtractingSizes` (AIGame's Obj_GetObjDist, scripts/AIGame.cpp:2728,
    /// built from OBJV_V_POS and OBJV_F_SIZE; a stale handle reads zeros).
    func objectDistance(
        _ a: ObjectHandle,
        _ b: ObjectHandle,
        subtractingSizes: Bool
    ) -> Float {
        var distance = vectorDistance(objectPosition(a), objectPosition(b))
        if subtractingSizes {
            distance -= objects[a]?.size ?? 0
            distance -= objects[b]?.size ?? 0
        }
        return distance
    }

    /// osipf_ObjGhost (:2841): MSAFE_OBJECT_GHOST or MSAFE_OBJECT_UNGHOST.
    /// The Black Pyro's red Guide-Bot model swap is Mercenary content (M6).
    mutating func objGhost(_ handle: ObjectHandle, _ ghost: Bool) {
        guard objects[handle] != nil else { return }
        if ghost {
            ghostObject(handle)
        } else {
            unghostObject(handle)
        }
    }

    /// osipf_ObjWBValue (:2637) WBV_I_DYNAMIC_FLAGS: set or clear flags of
    /// one dynamic weapon battery of an AI object or the player.
    mutating func objSetWeaponBatteryFlags(
        _ handle: ObjectHandle,
        battery: Int,
        _ flags: UInt32,
        set: Bool
    ) {
        guard let object = objects[handle],
              object.ai != nil || object.type == .player,
              object.weaponBatteries.indices.contains(battery)
        else {
            return
        }
        if set {
            objects[handle]?.weaponBatteries[battery].flags |= flags
        } else {
            objects[handle]?.weaponBatteries[battery].flags &= ~flags
        }
    }

    /// osipf_ObjCreate (:2570) of a generic object: ObjCreate, the parent,
    /// then InitObjectScripts. An id of -1 (65535), a room that does not
    /// exist, or a full object table gives OBJECT_HANDLE_NONE. The page's
    /// ambient sound (GSI_AMBIENT) is not imported; no object a script makes
    /// before M2 has one.
    mutating func objCreate(
        type: ObjectType,
        id: Int,
        room: Int,
        position: Vector3,
        orientation: Matrix3?,
        parent: ObjectHandle,
        level: Level
    ) -> ObjectHandle {
        guard id >= 0,
              let infos = level.objectInfos,
              infos.indices.contains(id),
              level.rooms.contains(where: { $0.sourceIndex == room }),
              [.robot, .powerup, .clutter, .building].contains(type),
              let created = createGenericObject(
                  infoIndex: id,
                  info: infos[id],
                  roomSourceIndex: room,
                  position: position,
                  orientation: orientation ?? Self.identityOrientation,
                  level: level
              )
        else {
            return .none
        }
        objects[created]?.parent = parent
        initObjectScripts(created, level: level)
        return created
    }

    /// osipf_ObjIsEffect (:2893) with EF_NAPALMED. The object effects
    /// (effect_info: burning, cloaking, and the rest) arrive in M2; no object
    /// carries them before then, so none burns (architecture.md section 9).
    func objIsNapalmed(_ handle: ObjectHandle) -> Bool {
        false
    }

    /// OBJV_F_ANIM_FRAME (:1523). The animations arrive with
    /// ai_do_animation (M2); until then every object stays at frame 0, as
    /// AIInit leaves an object with no animation (AImain.cpp:3676).
    func objectAnimationFrame(_ handle: ObjectHandle) -> Float {
        0
    }

    /// osipf_CallObjectEvent (:481): Osiris_CallEvent for the object.
    @discardableResult
    mutating func callObjectEvent(
        _ handle: ObjectHandle,
        _ event: ScriptEvent,
        level: Level
    ) -> Bool {
        guard objects[handle] != nil else { return false }
        return osirisCallEvent(handle, event, level: level)
    }

    // MARK: AI values (osipf_AIValue, :947)

    /// AIV_I_FLAGS set flags.
    mutating func aiSetFlags(_ handle: ObjectHandle, _ flags: UInt32) {
        objects[handle]?.ai?.flags |= flags
    }

    /// AIV_I_FLAGS clear flags.
    mutating func aiClearFlags(_ handle: ObjectHandle, _ flags: UInt32) {
        objects[handle]?.ai?.flags &= ~flags
    }

    /// AIV_F_MAX_SPEED.
    func aiMaxSpeed(_ handle: ObjectHandle) -> Float {
        objects[handle]?.ai?.maxVelocity ?? 0
    }

    mutating func setAIMaxSpeed(_ handle: ObjectHandle, _ speed: Float) {
        objects[handle]?.ai?.maxVelocity = speed
    }

    /// AIV_F_MAX_DELTA_SPEED.
    func aiMaxDeltaSpeed(_ handle: ObjectHandle) -> Float {
        objects[handle]?.ai?.maxDeltaVelocity ?? 0
    }

    mutating func setAIMaxDeltaSpeed(_ handle: ObjectHandle, _ speed: Float) {
        objects[handle]?.ai?.maxDeltaVelocity = speed
    }

    /// AIV_I_TARGET_HANDLE set.
    mutating func setAITarget(_ handle: ObjectHandle, _ target: ObjectHandle) {
        objects[handle]?.ai?.targetHandle = target
    }

    // MARK: AI goals

    /// osipf_AISetType (:1655): a CT_AI object gets its type's goals
    /// (GoalInitTypeGoals). The type itself does not change.
    mutating func aiSetType(_ handle: ObjectHandle, _ type: UInt8, level: Level) {
        guard objects[handle]?.ai != nil, type < ObjectAIFrame.typeCount
        else {
            return
        }
        goalInitTypeGoals(handle, type: type, level: level)
    }

    /// osipf_AIGoalAdd (:1730) for the goal types AIGoal.swift translates.
    /// Returns the goal slot, or -1 for an object with no AI.
    @discardableResult
    mutating func aiGoalAdd(
        _ handle: ObjectHandle,
        type: UInt32,
        level slot: Int,
        influence: Float,
        guid: Int32,
        flags: UInt32,
        _ argument: AIGoalArgument,
        subtype: Int8 = 0,
        world level: Level
    ) -> Int {
        guard objects[handle]?.ai != nil else { return -1 }
        return goalAddGoal(
            handle,
            type: type,
            argument,
            level: slot,
            influence: influence,
            flags: flags,
            guid: guid,
            subtype: subtype,
            world: level
        )
    }

    /// osipf_AISetGoalCircleDist (:2058), and AIGV_F_CIRCLE_DIST set: a
    /// used goal's circle distance.
    mutating func aiSetGoalCircleDistance(
        _ handle: ObjectHandle,
        _ slot: Int,
        _ distance: Float
    ) {
        guard (0..<ObjectAIFrame.maximumGoals).contains(slot),
              objects[handle]?.ai?.goals[slot].used == true
        else {
            return
        }
        objects[handle]?.ai?.goals[slot].circleDistance = distance
    }

    /// AIGV_I_FLAGS set flags of a used goal.
    mutating func aiSetGoalFlags(_ handle: ObjectHandle, _ slot: Int,
                                 _ flags: UInt32) {
        guard aiGoalIsUsed(handle, slot) else { return }
        objects[handle]?.ai?.goals[slot].flags |= flags
    }

    /// AIGV_B_USED (:2992).
    func aiGoalIsUsed(_ handle: ObjectHandle, _ slot: Int) -> Bool {
        guard (0..<ObjectAIFrame.maximumGoals).contains(slot) else {
            return false
        }
        return objects[handle]?.ai?.goals[slot].used == true
    }

    /// AIGV_I_STATUS_REG get of a used goal; 0 otherwise.
    func aiGoalStatusRegister(_ handle: ObjectHandle, _ slot: Int) -> UInt32 {
        guard aiGoalIsUsed(handle, slot) else { return 0 }
        return objects[handle]?.ai?.goals[slot].statusRegister ?? 0
    }

    /// osipf_AITurnTowardsVectors (:1636): turn toward the orientation the
    /// two vectors make, at the object's turn rate.
    mutating func aiTurnTowardsVectors(
        _ handle: ObjectHandle,
        forward: Vector3,
        up: Vector3
    ) {
        guard var object = objects[handle], let ai = object.ai else { return }
        aiTurnTowardsMatrix(
            &object,
            turnRate: ai.maxTurnRate,
            goal: sourceVectorToMatrix(forward: forward, up: up)
        )
        objects[handle] = object
    }

    /// osipf_AIIsObjEnemy (:2968).
    func aiIsObjectEnemy(
        _ handle: ObjectHandle,
        _ other: ObjectHandle,
        level: Level
    ) -> Bool {
        guard let object = objects[handle], let target = objects[other] else {
            return false
        }
        return aiObjEnemy(object, target, level: level)
    }

    // MARK: Reachability and searches

    /// osipf_AIIsObjReachable (:3653): AIFindAltPath from the object's
    /// room to the target's, with its draws.
    mutating func aiIsObjectReachable(
        _ handle: ObjectHandle,
        _ target: ObjectHandle,
        level: Level
    ) -> Bool {
        guard let object = objects[handle], let goal = objects[target],
              case let .room(room) = object.location,
              case let .room(goalRoom) = goal.location
        else {
            return false
        }
        return aiFindAltPath(handle, from: room, to: goalRoom,
                             level: level) != nil
    }

    /// osipf_AIIsDestReachable (:3644).
    mutating func aiIsDestinationReachable(
        _ handle: ObjectHandle,
        room destination: Int,
        level: Level
    ) -> Bool {
        guard let object = objects[handle],
              case let .room(room) = object.location
        else {
            return false
        }
        return aiFindAltPath(handle, from: room, to: destination,
                             level: level) != nil
    }

    /// AIFindObjOfType (AImain.cpp:6307) through osipf_AIFindObjOfType
    /// (:1925): the reachable object of the type (a robot search takes
    /// buildings too) with the shortest route, skipping the object itself,
    /// invisible objects, inactive robots, and robots with no or only
    /// camera weapon batteries.
    mutating func aiFindObjectOfType(
        _ handle: ObjectHandle,
        type: ObjectType,
        id: Int,
        ignoringInitialRoom: Bool,
        parent: ObjectHandle,
        level: Level
    ) -> ObjectHandle {
        guard let object = objects[handle],
              case let .room(room) = object.location
        else {
            return .none
        }
        var best: (handle: ObjectHandle, distance: Float)?
        for candidate in objects {
            guard candidate.type == type
                    || (type == .robot && candidate.type == .building),
                  candidate.handle != handle,
                  !(ignoringInitialRoom
                    && candidate.location == object.location),
                  id == -1 || objectID(candidate.handle) == id,
                  parent == .none || candidate.parent == parent,
                  candidate.renderType != .none,
                  !(candidate.type == .robot && candidate.ai == nil),
                  case let .room(candidateRoom) = candidate.location
            else {
                continue
            }
            if candidate.type == .robot {
                let batteries = level.placedObjectModel(candidate.handle)?
                    .weaponBatteries?.count ?? 0
                if batteries == 0 { continue }
                if batteries == 1,
                   let info = candidate.info.flatMap({
                       level.objectInfos?[$0]
                   }),
                   let battery = info.weaponBatteries.first,
                   battery.fireMasks.count == 1,
                   battery.fireMasks[0] == 0 {
                    continue
                }
            }
            // BOA_ComputeMinDist first; then AIFindAltPath, with its
            // draws, for a candidate that may be nearer.
            guard let minimum = boaComputeMinDist(room, candidateRoom,
                                                  level: level),
                  best == nil || minimum < best!.distance
            else {
                continue
            }
            if let path = aiFindAltPath(handle, from: room, to: candidateRoom,
                                        level: level),
               best == nil || path.length < best!.distance {
                best = (candidate.handle, path.length)
            }
        }
        return best?.handle ?? .none
    }

    /// osipf_ObjMakeListOfType (:1940): up to `maximum` objects of the
    /// type in slot order, other than the object itself.
    func objMakeListOfType(
        _ handle: ObjectHandle,
        type: ObjectType,
        id: Int,
        ignoringInitialRoom: Bool,
        parent: ObjectHandle,
        maximum: Int
    ) -> [ObjectHandle] {
        guard let object = objects[handle] else { return [] }
        var list: [ObjectHandle] = []
        for candidate in objects {
            guard candidate.type == type,
                  candidate.handle != handle,
                  !(ignoringInitialRoom
                    && candidate.location == object.location),
                  parent == .none || candidate.parent == parent,
                  id == -1 || objectID(candidate.handle) == id
            else {
                continue
            }
            list.append(candidate.handle)
            if list.count >= maximum { break }
        }
        return list
    }

    /// osipf_AIFindEnergyCenter (:2000) with AIFindRoomWithFlag
    /// (AImain.cpp:6256): the reachable RF_FUELCEN room with the shortest
    /// route, or -1.
    mutating func aiFindEnergyCenter(_ handle: ObjectHandle, level: Level) -> Int {
        guard let object = objects[handle],
              case let .room(room) = object.location
        else {
            return -1
        }
        let fuelCenter: UInt32 = 1
        var best: (room: Int, distance: Float)?
        for candidate in level.rooms.sorted(by: {
            $0.sourceIndex < $1.sourceIndex
        }) where candidate.flags & fuelCenter != 0 {
            guard let minimum = boaComputeMinDist(
                room, candidate.sourceIndex, level: level
            ),
                best == nil || minimum < best!.distance
            else {
                continue
            }
            if let path = aiFindAltPath(handle, from: room,
                                        to: candidate.sourceIndex,
                                        level: level),
               best == nil || path.length < best!.distance {
                best = (candidate.sourceIndex, path.length)
            }
        }
        return best?.room ?? -1
    }

    /// osipf_AIGetNearbyObjs (:3319) with fvi_QuickDistObjectList
    /// (findintersection.cpp:2108) in a room: the rooms reached through
    /// portals whose face box meets the query box (not through a closed
    /// portal when `stopAtClosedDoors`), and in each room its objects whose
    /// box meets the query box, at most `maximum` in all. The objects a ray
    /// can hit count, or every object with `includeNonCollideObjects`;
    /// only players and AI objects with `onlyPlayersAndAIs`; only
    /// lightmapped objects with `lightmapOnly`. Dead and invisible objects
    /// are then dropped. A room's objects come in slot order.
    func aiGetNearbyObjects(
        position: Vector3,
        room startRoom: Int,
        radius: Float,
        maximum: Int,
        lightmapOnly: Bool,
        onlyPlayersAndAIs: Bool,
        includeNonCollideObjects: Bool,
        stopAtClosedDoors: Bool,
        level: Level
    ) -> [ObjectHandle] {
        let roomBySourceIndex = Dictionary(
            uniqueKeysWithValues: level.rooms.enumerated().map {
                ($1.sourceIndex, $0)
            }
        )
        guard let startIndex = roomBySourceIndex[startRoom] else { return [] }
        let low = position - Vector3(x: radius, y: radius, z: radius)
        let high = position + Vector3(x: radius, y: radius, z: radius)
        func boxesMeet(_ min: Vector3, _ max: Vector3) -> Bool {
            min.x <= high.x && max.x >= low.x
                && min.y <= high.y && max.y >= low.y
                && min.z <= high.z && max.z >= low.z
        }
        let rayCollidingTypes: Set<ObjectType> = [
            .robot, .player, .weapon, .powerup, .clutter, .building, .door,
            .room,
        ]
        var found: [ObjectHandle] = []
        var queue = [startIndex]
        var visited: Set<Int> = [startIndex]
        var head = 0
        while head < queue.count, found.count < maximum {
            let roomIndex = queue[head]
            head += 1
            let room = level.rooms[roomIndex]
            for object in objects {
                guard found.count < maximum else { break }
                guard object.location == .room(room.sourceIndex),
                      includeNonCollideObjects
                        || rayCollidingTypes.contains(object.type),
                      !onlyPlayersAndAIs
                        || object.type == .player || object.ai != nil,
                      !lightmapOnly
                        || object.info.flatMap({
                            level.objectInfos?[$0].lighting
                                .lightingRenderType
                        }) == 2
                else {
                    continue
                }
                let size = Vector3(x: object.size, y: object.size,
                                   z: object.size)
                if boxesMeet(object.position - size, object.position + size) {
                    found.append(object.handle)
                }
            }
            guard found.count < maximum else { break }
            // A closed door attenuates everything (DoorwayGetPosition).
            if stopAtClosedDoors, let door = room.door, door.position == 0 {
                continue
            }
            for (portalIndex, portal) in room.portals.enumerated() {
                if stopAtClosedDoors {
                    let flags = rooms[roomIndex].portalFlags[portalIndex]
                    if (flags & 1 != 0 && flags & 2 == 0) || flags & 32 != 0 {
                        continue
                    }
                }
                let face = room.faces[portal.faceIndex]
                let corners = face.corners.map { room.vertices[$0.vertexIndex] }
                guard let first = corners.first else { continue }
                var faceMin = first
                var faceMax = first
                for corner in corners {
                    faceMin = Vector3(x: Swift.min(faceMin.x, corner.x),
                                      y: Swift.min(faceMin.y, corner.y),
                                      z: Swift.min(faceMin.z, corner.z))
                    faceMax = Vector3(x: Swift.max(faceMax.x, corner.x),
                                      y: Swift.max(faceMax.y, corner.y),
                                      z: Swift.max(faceMax.z, corner.z))
                }
                guard boxesMeet(faceMin, faceMax),
                      let next = roomBySourceIndex[portal.connectedRoom],
                      visited.insert(next).inserted
                else {
                    continue
                }
                queue.append(next)
            }
        }
        return found.filter { handle in
            guard let object = objects[handle] else { return false }
            return object.flags & GameObject.deadFlag == 0
                && object.renderType != .none
        }
    }

    /// osipf_RayCast (:2398) from a room: whether the ray (a sphere of
    /// `radius`) reaches its end (HIT_NONE). The walls stop it; the object
    /// checks arrive with general fvi object queries (M2).
    func rayCastIsClear(
        from start: Vector3,
        to end: Vector3,
        room: Int,
        radius: Float,
        level: Level
    ) -> Bool {
        boaProbeIsClear(room: room, start: start, end: end, radius: radius,
                        level: level)
    }

    // MARK: Rooms (osipf_RoomValue, :616)

    /// RMV_F_DAMAGE.
    func roomDamage(_ room: Int, level: Level) -> Float {
        level.rooms.first { $0.sourceIndex == room }?.damage ?? 0
    }

    /// RMSV_V_PATH_PNT.
    func roomPathPoint(_ room: Int, level: Level) -> Vector3 {
        level.rooms.first { $0.sourceIndex == room }?.pathPoint ?? .zero
    }

    /// RMSV_V_PORTAL_PATH_PNT.
    func roomPortalPathPoint(_ room: Int, portal: Int, level: Level) -> Vector3 {
        guard let found = level.rooms.first(where: { $0.sourceIndex == room }),
              found.portals.indices.contains(portal)
        else {
            return .zero
        }
        return found.portals[portal].pathPoint
    }

    /// RMSV_V_FACE_CENTER_PNT: the average of the face's vertices, or the
    /// room's path point for a face that does not exist.
    func roomFaceCenter(_ room: Int, face: Int, level: Level) -> Vector3 {
        guard let found = level.rooms.first(where: { $0.sourceIndex == room })
        else {
            return .zero
        }
        guard found.faces.indices.contains(face),
              !found.faces[face].corners.isEmpty
        else {
            return found.pathPoint
        }
        var sum = Vector3.zero
        for corner in found.faces[face].corners {
            sum = sum + found.vertices[corner.vertexIndex]
        }
        return sum / Float(found.faces[face].corners.count)
    }

    /// RMSV_V_FACE_NORMAL.
    func roomFaceNormal(_ room: Int, face: Int, level: Level) -> Vector3 {
        guard let found = level.rooms.first(where: { $0.sourceIndex == room }),
              found.faces.indices.contains(face)
        else {
            return .zero
        }
        return canonicalFaceNormal(room: found, face: found.faces[face])
            ?? .zero
    }

    // MARK: Players (osipf_PlayerValue, :731)

    /// PLYV_I_BUDDY_HANDLE: Buddy_handle of the player (single player: 0).
    func playerBuddyHandle(_ player: ObjectHandle) -> ObjectHandle {
        objects[player]?.type == .player ? buddyHandle : .none
    }

    /// PLYV_I_FLAGS & PLAYER_FLAGS_DEAD.
    func playerIsDead(_ player: ObjectHandle) -> Bool {
        objects[player]?.type == .player && playerDeath?.isDead == true
    }

    /// osipf_PlayerAddHudMessage (:2830): MSAFE_MISC_HUD_MESSAGE for the
    /// player the handle names.
    mutating func playerAddHUDMessage(_ player: ObjectHandle, _ message: String) {
        guard objects[player]?.type == .player else { return }
        addHUDMessage(message)
    }

    // MARK: Sounds

    /// osipf_SoundPlay3d (:2939): MSAFE_SOUND_OBJECT (multisafe.cpp:1973).
    /// Returns the sound handle, or -1.
    @discardableResult
    mutating func soundPlay3D(
        _ object: ObjectHandle,
        _ soundIndex: Int,
        level: Level
    ) -> Int32 {
        playObjectSound3D(soundIndex, object: object, level: level)
    }

    /// osipf_SoundPlay2d (:2918) with an object: MSAFE_SOUND_2D for the
    /// player the object names (GetPlayerSlot, multisafe.cpp:1258). An
    /// object that names no player plays nothing. Returns -1; the 2D
    /// sounds have no handle before the audio port (M2).
    @discardableResult
    mutating func soundPlay2D(
        _ object: ObjectHandle,
        _ soundIndex: Int,
        volume: Float = 1,
        level: Level
    ) -> Int32 {
        guard let found = objects[object] else { return -1 }
        let owner = found.type == .weapon ? objects[found.parent] : found
        guard owner?.type == .player else { return -1 }
        playSound2D(soundIndex, volume: volume, level: level)
        return -1
    }

    // MARK: Level goals (osipf_LGoalValue, :3482)

    /// levelgoals::GetNumActivePrimaryGoals (levelgoal.cpp:955) and
    /// GetNumActiveSecondaryGoals (:1010): in each goal list, the enabled
    /// goals that are not completed or failed and have the list's lowest
    /// priority, list by list. The original reads the list the last count
    /// made (levelgoals::DoFrame counts every frame); this counts when read.
    func levelGoalActiveGoals(secondary: Bool) -> [Int] {
        let maximumLists = 4
        var best = Array(repeating: Int32(-1), count: maximumLists)
        var candidates: [[(goal: Int, priority: Int32)]] =
            Array(repeating: [], count: maximumLists)
        for (index, goal) in goals.enumerated() {
            let flags = goal.status
            guard flags & (LevelGoalFlag.completed | LevelGoalFlag.failed) == 0,
                  (flags & LevelGoalFlag.secondaryGoal != 0) == secondary,
                  flags & LevelGoalFlag.enabled != 0,
                  (0..<maximumLists).contains(Int(goal.list))
            else {
                continue
            }
            let list = Int(goal.list)
            if best[list] == -1 || goal.priority <= best[list] {
                best[list] = goal.priority
                candidates[list].append((index, goal.priority))
            }
        }
        var active: [Int] = []
        for list in 0..<maximumLists {
            for candidate in candidates[list]
            where candidate.priority == best[list] {
                active.append(candidate.goal)
            }
        }
        return active
    }
}
