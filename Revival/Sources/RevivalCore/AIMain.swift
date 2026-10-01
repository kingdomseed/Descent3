// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/AImain.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): AIDetermineObjVisLevel (:1645),
// ai_target_valid (:1680), AISetTarget (:1696), AIDetermineAimPoint
// (:2766), AIDetermineFovVec (:2814), AISeeTarget (:2836), AINotify
// (:2877, the notify types reached so far), AIInit (:3650), AIInitAll
// (:3810), AICheckTargetVis (:3868), AIStatusCircleFrame (:4028),
// ai_update_registers (:4062), ai_decrease_awareness (:5504),
// ai_do_script_stuff (:5526), AIGetTeam (:5572), AIObjEnemy (:5675),
// AITargetCheck (:5751), AIDetermineTarget (:5828), AIDoMemFrame (:5963),
// AIDoFrame (:6024), and AIPowerSwitch (:6231); and ObjInitGeneric's control
// setup (Descent3/ObjInit.cpp:807). ai_move is in AIMain+Move.swift and
// ai_fire in AIMain+Fire.swift.
//
// Scope (M1 step 6). AIDoFrame runs its memory, target, vision, register,
// goal, and movement steps for every enabled AI object, with their ps_rand
// draws; only stationary turrets (AIT_STATIONARY_TURRET) fire, and the
// other AI types fire with the rest of ai_move in M2. Not yet here: animation
// (ai_do_animation) and walking, the render feedback AIFrameAll gives
// (AI_RenderedList, AIN_PLAYER_SEES_YOU), AI sounds, AIDoTrackFrame
// (flocks and tracked friends), AIDoFreud, attached children, and
// multiplayer. BOA_IsVisible is the reciprocal-portal component of the
// room (architecture.md section 9).

import Foundation

extension GameWorld {
    // AImain.cpp:1546-1554.
    static let maximumSeeTargetDistance: Float = 500
    static let maximumTrackTargetDistance: Float = 800
    static let minimumVisibilityRecentCheckInterval: Float = 0.35
    static let minimumVisibilityCheckInterval: Float = 0.15
    static let checkVisibilityInfrequentlyTime: Float = 7
    static let checkVisibilityInfrequentlyInterval: Float = 2
    static let minimumTargetUpdateInterval: Float = 2
    static let maximumTargetUpdateInterval: Float = 4.5
    /// MAX_FLUCTUATION_PERCENT (AImain.cpp:3577).
    static let maximumFluctuationPercent: Float = 0.08
    // AIN_ notify types (aistruct_external.h:286-314).
    static let seeTargetNotify = 4
    static let playerSeesYouNotify = 5
    static let weaponHitObjectNotify = 6
    static let hitByWeaponNotify = 14
    // AIVIS_ levels (AImain.cpp:1639-1642).
    static let aiVisibilityBarely: Float = 1
    static let aiVisibilityMostly: Float = 2
    static let aiVisibilityFull: Float = 3
    // Awareness falloff (aistruct_external.h:329-336).
    static let awarenessFalloff: Float = 100 / 5
    static let awarenessRenderRecentlyFalloff: Float = 100 / 120
    static let awarenessRenderRecentlyInterval: Float = 20
    static let awarenessSeeTargetRecentlyInterval: Float = 25

    /// A random fraction `ps_rand() / D3_RAND_MAX`.
    mutating func psRandFraction() -> Float {
        Float(psRand()) / Float(Self.randMax)
    }

    /// The velocity of an object: the player's is the ship's.
    func objectVelocity(_ object: GameObject) -> Vector3 {
        object.type == .player ? velocity : object.velocity
    }

    // MARK: Level start

    /// ObjInitGeneric's control setup (ObjInit.cpp:807): a page with
    /// OIF_CONTROL_AI and `ai_info` makes the object CT_AI with its page AI
    /// values and cleared weapon batteries. Its AIInit runs in AIInitAll.
    static func initialGenericObject(
        _ object: GameObject,
        info: CanonicalObjectInfo,
        infoIndex: Int,
        model: CanonicalModel?
    ) -> GameObject {
        var object = object
        object.info = infoIndex
        // PageInPolymodel computes the size from the model
        // (ObjInit.cpp:788-789, ComputeDefaultSize).
        object.size = model.map {
            sourceObjectPresentationSize(
                model: $0,
                objectType: object.type.rawValue
            )
        } ?? info.size
        object.shields = Float(info.hitPoints)
        // ObjInitGeneric's flags (ObjInit.cpp:766-771).
        if info.flags & CanonicalObjectInfo.destroyableFlag != 0 {
            object.flags |= GameObject.destroyableFlag
        }
        if info.flags & CanonicalObjectInfo.aiScriptedDeathFlag != 0 {
            object.flags |= GameObject.aiDoDeathFlag
        }
        if info.flags & CanonicalObjectInfo.doCeilingCheckFlag != 0 {
            object.flags |= GameObject.forceCeilingCheckFlag
        }
        // ObjSetRenderPolyobj (ObjInit.cpp:779).
        object.flags |= GameObject.polygonObjectFlag
        // OIF_USES_PHYSICS (objinfo.h:334).
        object.usesPhysics = info.flags & 0x02 != 0
        if let ai = info.ai,
           info.flags & CanonicalObjectInfo.controlAIFlag != 0 {
            object.ai = ObjectAIFrame(info: ai)
            object.weaponBatteries = clearedWeaponBatteries(
                count: model?.weaponBatteries?.count ?? 0
            )
        }
        return object
    }

    /// AIInitAll (AImain.cpp:3810), run by StartLevel before the level
    /// script starts (gamesequence.cpp:1482): AIInit for every AI object in
    /// slot order, then, in single player, the Guide-Bot: ObjCreate of
    /// ROBOT_GUIDEBOT at the player with the player as parent, ghosted, as
    /// Buddy_handle (:3833-3839). Then ResetPlayerObject gives the player
    /// the Guide-Bot in the inventory while it is not out (Player.cpp:1451).
    /// The random draws of level load come before the seed.
    ///
    /// Until objects are created at level start (M1 step 10), the level's
    /// imported object with the Guide-Bot page stands in for the one
    /// ObjCreate makes: it keeps its slot and handle.
    mutating func aiInitAll(level: Level) {
        buddyHandle = .none
        let guideBotPage = objectFindID(
            CanonicalObjectInfo.guideBotPageName, level: level
        )
        let buddy = objects.first {
            guideBotPage >= 0 && $0.info == guideBotPage && $0.ai != nil
        }?.handle
        for slot in 0..<ObjectTable.capacity {
            guard let object = objects.slots[slot], object.ai != nil,
                  object.handle != buddy
            else {
                continue
            }
            aiInit(object.handle, level: level)
        }
        let player = playerObjectHandle(slot: 0, level: level)
        if let buddy, let playerObject = objects[player],
           var object = objects[buddy] {
            // ObjCreate(OBJ_ROBOT, ROBOT_GUIDEBOT, player room, player
            // position, NULL, player handle): identity orientation, the
            // polygon render type, the creation time, and ObjInitGeneric's
            // draw (ObjInit.cpp:728) before its AIInit.
            object.location = playerObject.location
            object.position = playerObject.position
            object.orientation = Self.identityOrientation
            object.renderType = .polyobj
            object.parent = player
            object.creationTime = gameTime
            object.velocity = .zero
            objects[buddy] = object
            _ = psRand()
            aiInit(buddy, level: level)
            buddyHandle = buddy
            ghostObject(buddy)
        }
        if objects[player] != nil,
           !playerInventory.checkItem(type: ObjectType.robot.rawValue,
                                      id: guideBotPage),
           objects[buddyHandle].map({ $0.type != .robot }) ?? false {
            playerInventory.add(
                type: ObjectType.robot.rawValue,
                id: guideBotPage,
                pageFlags: objectPageFlags(guideBotPage, level: level)
            )
        }
    }

    /// AIInit (AImain.cpp:3650) for a placed object: the page AI values,
    /// the random memory, animation, and vision times, the speed
    /// fluctuation, and the difficulty scaling.
    mutating func aiInit(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle],
              let infoIndex = object.info,
              let page = level.objectInfos?[infoIndex].ai
        else {
            return
        }
        let info = level.objectInfos![infoIndex]
        var ai = ObjectAIFrame(info: page)
        let noScale =
            info.flags & CanonicalObjectInfo.noDifficultyScaleMoveFlag != 0
            || ai.flags & ObjectAIFrame.teamMask == ObjectAIFrame.teamRebel
        ai.memoryTimeUntilNextUpdate = 3 + psRandFraction() * 2
        ai.memory = Array(repeating: AIMemory(), count: ai.memory.count)
        ai.memory[0].shields = object.shields
        ai.statusRegister = 0
        ai.weaponSpeed = 0
        ai.vecToTargetPerceived = object.orientation.forward
        // An object a player (or a dead player's ghost) made is on the
        // rebel team (AImain.cpp:3690-3697).
        if let parent = objects[object.parent],
           parent.type == .player || parent.type == .ghost {
            ai.flags &= ~ObjectAIFrame.teamMask
            ai.flags |= ObjectAIFrame.teamRebel
        }
        // The idle or alert animation starts at a random frame. The
        // animation itself arrives with ai_do_animation.
        _ = psRand()
        // AISetTarget(obj, OBJECT_HANDLE_NONE).
        ai.targetHandle = .none
        ai.lastSeeTargetPosition = object.position
        ai.nextCheckSeeTargetTime = gameTime + psRandFraction()
        ai.lastSeeTargetTime =
            gameTime - Self.checkVisibilityInfrequentlyTime * 2
        ai.lastHearTargetTime =
            gameTime - Self.checkVisibilityInfrequentlyTime * 2
        ai.lastRenderTime = -1
        ai.nextTargetUpdateTime = gameTime
        if ai.flags & ObjectAIFrame.fluctuateSpeedFlag != 0 {
            func fluctuation(_ world: inout GameWorld) -> Float {
                let half = Float(Self.randMax) * 0.5
                return 1 + ((Float(world.psRand()) - half) / half)
                    * Self.maximumFluctuationPercent
            }
            ai.maxVelocity *= fluctuation(&self)
            ai.maxDeltaVelocity *= fluctuation(&self)
            ai.maxTurnRate *= fluctuation(&self)
        }
        ai.awareness = ObjectAIFrame.awareNone
        let difficulty = Difficulty.level
        ai.dodgeVelocityPercent *=
            noScale ? 1 : Difficulty.aiDodgeSpeed[difficulty]
        ai.maxVelocity *= noScale ? 1 : Difficulty.aiSpeed[difficulty]
        ai.maxTurnRate *= noScale ? 1 : Difficulty.aiRotationSpeed[difficulty]
        ai.circleDistance *=
            noScale ? 1 : Difficulty.aiCircleDistance[difficulty]
        ai.lastSeeTargetPosition = object.position
        ai.vecToTargetActual = object.orientation.forward
        ai.vecToTargetPerceived = object.orientation.forward
        ai.distToTargetActual = 1
        ai.distToTargetPerceived = 10_000
        ai.goals = Array(repeating: AIGoal(), count: ai.goals.count)
        ai.path.free()
        object.ai = ai
        objects[handle] = object
        // Clear out the goals and give the type's goals
        // (AImain.cpp:3799, GoalInitTypeGoals AIGoal.cpp:1295).
        goalInitTypeGoals(handle, type: ai.aiType, level: level)
        // IS_GUIDEBOT (objinfo.h:363): the Guide-Bot dodges (:3801).
        let pages = [
            CanonicalObjectInfo.guideBotPageName,
            CanonicalObjectInfo.guideBotRedPageName,
        ].map { objectFindID($0, level: level) }
        if pages.contains(where: { $0 >= 0 && $0 == infoIndex }) {
            objects[handle]?.ai?.flags |= ObjectAIFrame.dodgeFlag
        }
    }

    // MARK: Power and team

    /// osipf_AIPowerSwitch and AIPowerSwitch (AImain.cpp:6231): a CT_AI
    /// object sets or clears AIF_DISABLED. Attached children arrive with the
    /// attach system; until then no object has any.
    mutating func aiPowerSwitch(_ handle: ObjectHandle, on: Bool) {
        guard var ai = objects[handle]?.ai else { return }
        if on {
            ai.flags &= ~ObjectAIFrame.disabledFlag
        } else {
            ai.flags |= ObjectAIFrame.disabledFlag
        }
        objects[handle]?.ai = ai
    }

    /// AIGetTeam (AImain.cpp:5572) in single player: the player is on its
    /// own rebel sub-team.
    func aiGetTeam(_ object: GameObject) -> UInt32 {
        if object.type == .player {
            return ObjectAIFrame.teamRebel + 1
        }
        guard let ai = object.ai else { return ObjectAIFrame.teamPTMC }
        if ai.flags & ObjectAIFrame.actAsNeutralUntilShotFlag != 0 {
            return ObjectAIFrame.teamNeutral
        }
        return ai.flags & ObjectAIFrame.teamMask
    }

    /// AIObjEnemy (AImain.cpp:5675) in single player.
    func aiObjEnemy(_ object: GameObject, _ target: GameObject,
                    level: Level) -> Bool {
        guard target.type == .player || target.ai != nil,
              object.type == .player || object.ai != nil,
              object.type != .ghost, object.type != .powerup
        else {
            return false
        }
        let team = aiGetTeam(object)
        let targetTeam = aiGetTeam(target)
        if let targetAI = target.ai, targetAI.targetHandle == object.handle {
            return true
        }
        if target.ai != nil, !target.usesPhysics,
           (level.placedObjectModel(target.handle)?.weaponBatteries?.count
                ?? 0) == 0 {
            return false
        }
        if team != ObjectAIFrame.teamHostile,
           targetTeam == ObjectAIFrame.teamNeutral,
           target.ai?.targetHandle != object.handle {
            return false
        }
        if object.parent == target.handle || target.parent == object.handle {
            return false
        }
        switch team {
        case ObjectAIFrame.teamPTMC:
            return targetTeam != ObjectAIFrame.teamPTMC
        case ObjectAIFrame.teamHostile:
            return true
        case ObjectAIFrame.teamNeutral:
            return object.ai?.targetHandle == target.handle
        default:
            return targetTeam == ObjectAIFrame.teamPTMC
                || targetTeam == ObjectAIFrame.teamHostile
                || (targetTeam != ObjectAIFrame.teamRebel
                    && team != ObjectAIFrame.teamRebel
                    && targetTeam != team)
        }
    }

    // MARK: Frame

    /// AIDoFrame (AImain.cpp:6024) for one CT_AI object. See the file notes
    /// for the steps translated so far.
    mutating func aiDoFrame(_ handle: ObjectHandle, level: Level) {
        guard let object = objects[handle], var ai = object.ai,
              object.type != .dummy,
              ai.flags & ObjectAIFrame.disabledFlag == 0
        else {
            return
        }
        if ai.flags & ObjectAIFrame.forceAwarenessFlag != 0,
           ai.awareness < ObjectAIFrame.awareMostly {
            ai.awareness = ObjectAIFrame.awareMostly
            objects[handle]?.ai = ai
        }
        if object.flags & GameObject.deadFlag != 0 {
            return
        }
        aiDoMemFrame(handle)
        if ai.flags & ObjectAIFrame.determineTargetFlag != 0 {
            aiDetermineTarget(handle, level: level)
        }
        if ai.notifies(Self.seeTargetNotify) {
            aiCheckTargetVis(handle, level: level)
        }
        aiUpdateRegisters(handle, level: level)
        // Scope (M1 step 6): only stationary turrets fire; the other AI
        // types fire with the rest of ai_move in M2.
        let fires = ai.aiType == ObjectAIFrame.stationaryTurretType
        guard let current = objects[handle]?.ai else { return }
        if current.awareness != 0
            || current.flags & ObjectAIFrame.persistentFlag != 0 {
            // ai_do_script_stuff (AImain.cpp:5526).
            osirisCallEvent(handle, .aiFrame, level: level)
            goalDoFrame(handle, level: level)
            aiMove(handle, level: level)
            if fires, let fire = objects[handle]?.ai,
               fire.statusRegister & ObjectAIFrame.meleeStatus == 0,
               fire.flags & ObjectAIFrame.disableFiringFlag == 0 {
                aiFire(handle, level: level)
            }
        }
        aiDecreaseAwareness(handle)
    }

    /// AIDoMemFrame (AImain.cpp:5963): every 3 to 5 seconds the memory
    /// slots shift and the current shields are kept. The near friend and
    /// enemy counts feed only AIDoFreud, whose fear goals need
    /// AIG_WANDER_AROUND (M2); its checks draw no random number until a
    /// robot is damaged (M1 step 7).
    private mutating func aiDoMemFrame(_ handle: ObjectHandle) {
        guard let object = objects[handle], var ai = object.ai else { return }
        ai.memoryTimeUntilNextUpdate -= frameDuration
        if ai.memoryTimeUntilNextUpdate <= 0 {
            ai.memoryTimeUntilNextUpdate = 3 + psRandFraction() * 2
            ai.memory[0].shields = object.shields
            for index in stride(from: ai.memory.count - 1, to: 0, by: -1) {
                ai.memory[index] = ai.memory[index - 1]
            }
            ai.memory[0].numberOfTimesHit = 0
            ai.memory[0].numberOfHitEnemy = 0
            ai.memory[0].shields = object.shields
        }
        objects[handle]?.ai = ai
    }

    /// ai_target_valid (AImain.cpp:1680): a target that no longer exists
    /// sends AIN_TARGET_DIED and is cleared.
    private mutating func aiTargetValid(_ handle: ObjectHandle,
                                        level: Level) -> Bool {
        guard let target = objects[handle]?.ai?.targetHandle,
              target != .none
        else {
            return false
        }
        if objects[target] != nil { return true }
        aiNotifyObject(handle, .other, it: target, level: level)
        objects[handle]?.ai?.targetHandle = .none
        return false
    }

    /// AISetTarget (AImain.cpp:1696).
    @discardableResult
    private mutating func aiSetTarget(_ handle: ObjectHandle,
                                      _ target: ObjectHandle,
                                      level: Level) -> Bool {
        guard let object = objects[handle] else { return false }
        objects[handle]?.ai?.targetHandle = target
        if target == .none {
            objects[handle]?.ai?.lastSeeTargetPosition = object.position
        }
        return aiTargetValid(handle, level: level)
    }

    /// AIDetermineTarget (AImain.cpp:5828) in single player.
    private mutating func aiDetermineTarget(_ handle: ObjectHandle,
                                            level: Level) {
        guard var ai = objects[handle]?.ai,
              gameTime >= ai.nextTargetUpdateTime
        else {
            return
        }
        let spread =
            Self.maximumTargetUpdateInterval - Self.minimumTargetUpdateInterval
        if ai.awareness >= ObjectAIFrame.awareBarely {
            ai.nextTargetUpdateTime = gameTime
                + Self.minimumTargetUpdateInterval + psRandFraction() * spread
        } else {
            ai.nextTargetUpdateTime = gameTime
                + 2 * Self.minimumTargetUpdateInterval
                + psRandFraction() * 2 * spread
        }
        objects[handle]?.ai = ai
        let team = ai.flags & ObjectAIFrame.teamMask
        var best: ObjectHandle = .none
        if team == ObjectAIFrame.teamNeutral
            || ai.flags & ObjectAIFrame.actAsNeutralUntilShotFlag != 0 {
            best = .none
        } else if team != ObjectAIFrame.teamPTMC {
            best = aiBestVisibleEnemy(handle, level: level)
        } else {
            var forgiveFriend = false
            if let target = objects[ai.targetHandle],
               let targetAI = target.ai,
               targetAI.flags & ObjectAIFrame.teamMask
                == ObjectAIFrame.teamPTMC,
               Float(psRand()) / 1.2 > ai.aggression * Float(Self.randMax) {
                forgiveFriend = true
            }
            // A robot that targets the Guide-Bot goes back to the player
            // (AImain.cpp:5883-5891).
            let target = objects[handle]?.ai?.targetHandle ?? .none
            let targetsBuddy = target != .none && target == buddyHandle
            if forgiveFriend || !aiTargetValid(handle, level: level)
                || (targetsBuddy && objects[buddyHandle]?.type != .ghost) {
                let player = playerObjectHandle(slot: 0, level: level)
                if objects[player]?.type != .ghost {
                    best = player
                } else if buddyHandle != .none,
                          let buddy = objects[buddyHandle],
                          buddy.type != .ghost {
                    best = buddy.handle
                } else {
                    best = .none
                }
            } else {
                best = objects[handle]?.ai?.targetHandle ?? .none
            }
        }
        aiSetTarget(handle, best, level: level)
    }

    /// AITargetCheck over the objects near a non-PTMC AI object
    /// (AImain.cpp:5751, :5850): the nearest (or best-faced, with
    /// AIF_TARGET_BY_DIST) visible enemy within MAX_SEE_TARGET_DIST. The
    /// door check of its line of sight arrives with doors.
    private func aiBestVisibleEnemy(_ handle: ObjectHandle,
                                    level: Level) -> ObjectHandle {
        guard let object = objects[handle], let ai = object.ai else {
            return .none
        }
        let useDot = ai.flags & ObjectAIFrame.targetByDistanceFlag != 0
        var bestDot: Float = -1
        var bestDistance = Self.maximumSeeTargetDistance + 1
        var best: ObjectHandle = .none
        let look = aiDetermineFovVec(object, level: level)
        for target in objects where target.handle != handle {
            guard aiObjEnemy(object, target, level: level),
                  boaIsVisible(object.location, target.location, level: level),
                  aiDetermineObjVisLevel(object, target) > 0
            else {
                continue
            }
            let toTarget = target.position - object.position
            let distance = sqrt(dot(toTarget, toTarget))
            guard distance <= Self.maximumSeeTargetDistance, distance > 0
            else {
                continue
            }
            let facing = dot(toTarget / distance, look)
            if useDot ? facing <= bestDot : distance >= bestDistance {
                continue
            }
            bestDot = facing
            bestDistance = distance
            best = target.handle
        }
        return best
    }

    /// AIDetermineObjVisLevel (AImain.cpp:1645): a cloaked target is not
    /// seen, unless it is a player whose afterburner is on or whose
    /// headlight points at the looker; each adds one level. The napalm
    /// effect arrives with the object effects (M2).
    func aiDetermineObjVisLevel(_ object: GameObject,
                                _ target: GameObject) -> Float {
        var visibility = Self.aiVisibilityFull
        if let flags = target.effect?.typeFlags,
           flags & ObjectEffectInfo.cloakedFlag != 0 {
            visibility = 0
            if target.type == .player, afterburnerIsActive {
                visibility += 1
            }
            if target.type == .player, playerHeadlightIsOn {
                let fromTarget = sourceVectorNormalized(
                    object.position - target.position
                )
                if dot(target.orientation.forward, fromTarget) > 0.965 {
                    visibility += 1
                }
            }
        }
        return max(0, min(Self.aiVisibilityFull, visibility))
    }

    /// AIDetermineFovVec (AImain.cpp:2814).
    func aiDetermineFovVec(_ object: GameObject, level: Level) -> Vector3 {
        guard let ai = object.ai else { return object.orientation.forward }
        if ai.flags & ObjectAIFrame.aimPointFOVFlag != 0,
           let model = level.placedObjectModel(object.handle),
           let battery = model.weaponBatteries?.first,
           let info = object.info.flatMap({ level.objectInfos?[$0] }),
           let wb = info.weaponBatteries.first,
           battery.gunpoints.indices.contains(wb.aimingGunpointIndex) {
            return weaponCalcGun(
                object,
                gunpoint: battery.gunpoints[wb.aimingGunpointIndex],
                model: model
            ).normal
        }
        if ai.flags & ObjectAIFrame.upVectorFOVFlag != 0 {
            return object.orientation.up
        }
        return object.orientation.forward
    }

    /// AIDetermineAimPoint (AImain.cpp:2766) with the object's own weapon
    /// speed: the target's position led by its velocity. Returns the aim
    /// point.
    func aiDetermineAimPoint(_ robot: GameObject,
                             _ target: GameObject) -> Vector3 {
        guard let ai = robot.ai else { return target.position }
        let rebel =
            ai.flags & ObjectAIFrame.teamMask == ObjectAIFrame.teamRebel
        if Difficulty.level == Difficulty.trainee, !rebel {
            return target.position
        }
        let visibility = aiDetermineObjVisLevel(robot, target)
        var toTarget = target.position - robot.position
        let distance = sqrt(dot(toTarget, toTarget))
        toTarget = distance > 0 ? toTarget / distance : toTarget
        let weaponSpeed = ai.weaponSpeed
        guard weaponSpeed != 0 else { return target.position }
        let targetVelocity = objectVelocity(target)
        let closingSpeed = weaponSpeed - dot(toTarget, targetVelocity)
        guard closingSpeed > 0, visibility >= Self.aiVisibilityBarely else {
            return target.position
        }
        let time = distance / closingSpeed
        // The constant-force lead (ApplyConstantForce) is used only against
        // a fully visible player at Hotshot and above.
        return target.position + targetVelocity * time * ai.leadAccuracy
    }

    /// AISeeTarget (AImain.cpp:2836). The see sound needs AI sounds, which
    /// are not imported yet.
    private mutating func aiSeeTarget(_ handle: ObjectHandle, see: Bool) {
        guard var ai = objects[handle]?.ai else { return }
        if ai.awareness < ObjectAIFrame.awareMostly {
            ai.awareness = ObjectAIFrame.awareMostly
        }
        if let robot = objects[handle], let target = objects[ai.targetHandle] {
            if see {
                ai.lastSeeTargetTime = gameTime
            } else {
                ai.lastHearTargetTime = gameTime
            }
            var aimed = robot
            aimed.ai = ai
            ai.lastSeeTargetPosition = aiDetermineAimPoint(aimed, target)
        }
        objects[handle]?.ai = ai
    }

    /// AICheckTargetVis (AImain.cpp:3868). The line of sight is traced
    /// against the walls; objects in the way arrive with general fvi object
    /// checks.
    private mutating func aiCheckTargetVis(_ handle: ObjectHandle,
                                           level: Level) {
        guard let object = objects[handle], var ai = object.ai else { return }
        guard let target = objects[ai.targetHandle] else {
            ai.statusRegister &= ~ObjectAIFrame.seesGoalStatus
            ai.lastSeeTargetPosition = object.position
            objects[handle]?.ai = ai
            return
        }
        func noSee(_ world: inout GameWorld, _ ai: ObjectAIFrame) {
            var ai = ai
            ai.statusRegister &= ~ObjectAIFrame.seesGoalStatus
            world.objects[handle]?.ai = ai
        }
        guard boaIsVisible(object.location, target.location, level: level)
        else {
            noSee(&self, ai)
            return
        }
        let aim = aiDetermineAimPoint(object, target)
        var toTarget = aim - object.position
        let length = sqrt(dot(toTarget, toTarget))
        toTarget = length > 0 ? toTarget / length : toTarget
        ai.vecToTargetActual = toTarget
        ai.distToTargetActual = max(0, length - (object.size + target.size))
        let fovVector = aiDetermineFovVec(object, level: level)
        let visibilityScale =
            Difficulty.aiVisibilityDistance[Difficulty.level]
        let sameRoom = object.location == target.location
        if dot(ai.vecToTargetActual, fovVector) < ai.fov
            || (ai.distToTargetActual
                > Self.maximumTrackTargetDistance * visibilityScale
                && !sameRoom)
            || (ai.awareness == ObjectAIFrame.awareNone && !sameRoom
                && ai.distToTargetActual
                    > Self.maximumSeeTargetDistance * visibilityScale)
            || (ai.distToTargetActual
                > Self.maximumSeeTargetDistance * visibilityScale
                && ai.awareness <= ObjectAIFrame.awareBarely && !sameRoom)
            || target.type == .ghost
            || aiDetermineObjVisLevel(object, target) == 0 {
            noSee(&self, ai)
            return
        }
        objects[handle]?.ai = ai

        if gameTime - ai.lastSeeTargetTime
            > Self.minimumVisibilityRecentCheckInterval,
           gameTime >= ai.nextCheckSeeTargetTime,
           case let .room(room) = object.location {
            let sight = traceIndoorMovement(
                in: level,
                roomStates: rooms,
                startRoom: room,
                start: object.position,
                end: target.position,
                radius: 0
            )
            if case .noHit = sight.outcome {
                objects[handle]?.ai?.statusRegister |=
                    ObjectAIFrame.seesGoalStatus
                aiNotifySeeTarget(handle, target: target.handle,
                                  level: level)
            }
            guard var checked = objects[handle]?.ai else { return }
            let interval = checked.statusRegister
                & ObjectAIFrame.seesGoalStatus != 0
                || gameTime - checked.lastSeeTargetTime
                    < Self.checkVisibilityInfrequentlyTime
                ? Self.minimumVisibilityCheckInterval
                : Self.checkVisibilityInfrequentlyInterval
            // The C++ adds in double: Gametime + .9 * interval +
            // .2 * interval * fraction.
            let fraction = Double(psRand()) / Double(Self.randMax)
            checked.nextCheckSeeTargetTime = Float(
                Double(gameTime) + 0.9 * Double(interval)
                    + 0.2 * Double(interval) * fraction
            )
            objects[handle]?.ai = checked
        }
        if var seen = objects[handle]?.ai,
           seen.statusRegister & ObjectAIFrame.seesGoalStatus != 0 {
            seen.vecToTargetPerceived = seen.vecToTargetActual
            seen.distToTargetPerceived = seen.distToTargetActual
            objects[handle]?.ai = seen
        }
    }

    /// ai_update_registers (AImain.cpp:4062) with AIStatusCircleFrame
    /// (:4028).
    private mutating func aiUpdateRegisters(_ handle: ObjectHandle,
                                            level: Level) {
        guard var ai = objects[handle]?.ai else { return }
        if let target = objects[ai.targetHandle] {
            var status = ai.statusRegister
            aiStatusCircleFrame(
                handle,
                goalObject: target.handle,
                distance: ai.distToTargetPerceived,
                circleDistance: ai.circleDistance,
                status: &status,
                level: level
            )
            ai = objects[handle]?.ai ?? ai
            ai.statusRegister = status
        } else {
            ai.statusRegister &= ~ObjectAIFrame.circleDistanceStatus
        }
        ai.statusRegister &= ~ObjectAIFrame.meleeStatus
        objects[handle]?.ai = ai
    }

    /// ai_decrease_awareness (AImain.cpp:5504).
    private mutating func aiDecreaseAwareness(_ handle: ObjectHandle) {
        guard var ai = objects[handle]?.ai else { return }
        if ai.awareness == ObjectAIFrame.awareNone,
           ai.flags & ObjectAIFrame.persistentFlag == 0 {
            ai.path.free()
        }
        if gameTime - ai.lastRenderTime < Self.awarenessRenderRecentlyInterval
            || gameTime - ai.lastSeeTargetTime
                < Self.awarenessSeeTargetRecentlyInterval
            || gameTime - ai.lastHearTargetTime
                < Self.awarenessSeeTargetRecentlyInterval {
            ai.awareness -= Self.awarenessRenderRecentlyFalloff * frameDuration
        } else {
            ai.awareness -= Self.awarenessFalloff * frameDuration
        }
        if ai.awareness < ObjectAIFrame.awareNone {
            ai.awareness = ObjectAIFrame.awareNone
        }
        objects[handle]?.ai = ai
    }

    // MARK: AINotify (AImain.cpp:2877)

    /// Whether AINotify reaches the object at all: a dummy or a disabled AI
    /// object hears nothing (AImain.cpp:2900-2904).
    private func aiNotifyReaches(_ handle: ObjectHandle) -> Bool {
        guard let object = objects[handle], object.type != .dummy else {
            return false
        }
        return object.ai.map {
            $0.flags & ObjectAIFrame.disabledFlag == 0
        } ?? true
    }

    /// The end of AINotify: EVT_AI_NOTIFY to the object's scripts.
    @discardableResult
    private mutating func aiNotifyObject(
        _ handle: ObjectHandle,
        _ type: AINotifyType,
        it: ObjectHandle,
        level: Level
    ) -> Bool {
        guard aiNotifyReaches(handle) else { return false }
        return osirisCallEvent(handle, .aiNotify(type, it: it), level: level)
    }

    /// AINotify(AIN_SEE_TARGET).
    private mutating func aiNotifySeeTarget(_ handle: ObjectHandle,
                                            target: ObjectHandle,
                                            level: Level) {
        guard aiNotifyReaches(handle) else { return }
        if objects[handle]?.ai?.notifies(Self.seeTargetNotify) == true {
            aiSeeTarget(handle, see: true)
        }
        osirisCallEvent(handle, .aiNotify(.seeTarget, it: target),
                        level: level)
    }

    /// AIFrameAll (AImain.cpp:6211) in single player: each object the last
    /// frame's render drew hears AIN_PLAYER_SEES_YOU. GameFrame runs it
    /// before ObjDoFrameAll (GameLoop.cpp:2964).
    mutating func aiFrameAll(level: Level) {
        for handle in aiRenderedList {
            aiNotifyPlayerSeesYou(handle, level: level)
        }
    }

    /// AINotify(AIN_PLAYER_SEES_YOU) (AImain.cpp:2943): the object becomes
    /// at least barely aware and records the render time. The script event
    /// names no other object.
    private mutating func aiNotifyPlayerSeesYou(_ handle: ObjectHandle,
                                                level: Level) {
        guard aiNotifyReaches(handle), var ai = objects[handle]?.ai else {
            return
        }
        if ai.notifies(Self.playerSeesYouNotify) {
            if ai.awareness < ObjectAIFrame.awareBarely {
                ai.awareness = ObjectAIFrame.awareBarely
            }
            ai.lastRenderTime = gameTime
            objects[handle]?.ai = ai
        }
        osirisCallEvent(handle, .aiNotify(.other, it: .none), level: level)
    }

    /// AINotify(AIN_WHIT_OBJECT): the object's weapon hit something, so it
    /// is aware and knows where its target is.
    mutating func aiNotifyWeaponHitObject(_ handle: ObjectHandle,
                                          target hit: ObjectHandle,
                                          level: Level) {
        guard aiNotifyReaches(handle), var ai = objects[handle]?.ai else {
            return
        }
        ai.memory[0].numberOfHitEnemy &+= 1
        if ai.awareness < ObjectAIFrame.awareMostly {
            ai.awareness = ObjectAIFrame.awareMostly
        }
        if let robot = objects[handle], let target = objects[ai.targetHandle] {
            ai.lastSeeTargetTime = gameTime
            var aimed = robot
            aimed.ai = ai
            ai.lastSeeTargetPosition = aiDetermineAimPoint(aimed, target)
        }
        objects[handle]?.ai = ai
        osirisCallEvent(handle, .aiNotify(.other, it: hit), level: level)
    }

    /// AINotify(AIN_HIT_BY_WEAPON) (AImain.cpp:3148): the object counts
    /// the hit and becomes fully aware; it may flinch; a neutral-until-shot
    /// object stays neutral only toward a friend; and it may turn on the
    /// weapon's parent (20% per hit for the player it already knows about).
    /// Flinching needs AIG_SET_ANIM and the angry sound needs the AI sounds
    /// (M2), so only their random draw remains.
    mutating func aiNotifyHitByWeapon(_ handle: ObjectHandle,
                                      weapon: ObjectHandle,
                                      level: Level) {
        guard aiNotifyReaches(handle), var ai = objects[handle]?.ai else {
            return
        }
        ai.memory[0].numberOfTimesHit &+= 1
        if ai.notifies(Self.hitByWeaponNotify) {
            ai.awareness = ObjectAIFrame.awareFully
            if gameTime > ai.nextFlinchTime {
                _ = psRand() % 10
            }
        }
        objects[handle]?.ai = ai
        let newEnemy = objects[weapon].flatMap { objects[$0.parent] }
        if ai.flags & ObjectAIFrame.actAsNeutralUntilShotFlag != 0 {
            ai.flags &= ~ObjectAIFrame.actAsNeutralUntilShotFlag
            objects[handle]?.ai = ai
            if let object = objects[handle],
               !(newEnemy.map { aiObjEnemy(object, $0, level: level) }
                   ?? false) {
                ai.flags |= ObjectAIFrame.actAsNeutralUntilShotFlag
                objects[handle]?.ai = ai
            }
        }
        guard let object = objects[handle] else { return }
        let isEnemy = newEnemy.map {
            aiObjEnemy(object, $0, level: level)
        } ?? false
        let randomValue = psRandFraction()
        if let enemy = newEnemy, enemy.handle != handle {
            let sameKind = enemy.info == object.info
                && enemy.type == object.type
            let switches: Bool
            if let enemyAI = enemy.ai {
                switches = enemyAI.targetHandle == handle
                    || (!isEnemy && sameKind && randomValue < ai.fightSame)
                    || (!isEnemy && !sameKind && randomValue < ai.fightTeam)
            } else {
                switches = false
            }
            if switches
                || (isEnemy && enemy.type == .player
                    && (ai.awareness <= ObjectAIFrame.awareBarely
                        || randomValue > 0.8
                        || ai.targetHandle == .none)) {
                ai.flags |= ObjectAIFrame.determineTargetFlag
                let spread = Self.maximumTargetUpdateInterval
                    - Self.minimumTargetUpdateInterval
                ai.nextTargetUpdateTime = gameTime
                    + Self.minimumTargetUpdateInterval
                    + psRandFraction() * spread
                objects[handle]?.ai = ai
                aiSetTarget(handle, enemy.handle, level: level)
            }
        }
        osirisCallEvent(handle, .aiNotify(.other, it: weapon), level: level)
    }

    /// AINotify for a goal (AIN_GOAL_COMPLETE, AIN_GOAL_INVALID,
    /// AIN_GOAL_FAIL, AIN_GOAL_ERROR): the level script hears it first,
    /// then the object. Returns the object's CONTINUE_DEFAULT.
    mutating func aiNotifyGoal(_ handle: ObjectHandle,
                               _ type: AINotifyType,
                               goalIndex: Int,
                               level: Level) -> Bool {
        guard aiNotifyReaches(handle),
              let guid = objects[handle]?.ai?.goals[goalIndex].guid
        else {
            return false
        }
        let event = ScriptEvent.aiNotify(
            type, it: handle, info: .goal(index: goalIndex, guid: guid)
        )
        osirisCallLevelEvent(event, level: level)
        return osirisCallEvent(handle, event, level: level)
    }

    /// AINotify(AIN_NEAR_TARGET): the object reached its circle distance
    /// from `target`.
    mutating func aiNotifyNearTarget(_ handle: ObjectHandle,
                                     target: ObjectHandle, level: Level) {
        aiNotifyObject(handle, .other, it: target, level: level)
    }

    /// AINotify(AIN_SCRIPTED_ENABLER) (AImain.cpp:2913): the scripts decide
    /// whether the enabler holds.
    mutating func aiNotifyScriptedEnabler(_ handle: ObjectHandle,
                                          goalIndex: Int, enablerIndex: Int,
                                          level: Level) -> Bool {
        guard aiNotifyReaches(handle) else { return false }
        return osirisCallEvent(
            handle,
            .aiNotify(.scriptedEnabler, it: .none,
                      info: .goal(index: goalIndex, guid: -1,
                                  enabler: enablerIndex)),
            level: level
        )
    }

    /// AINotify(AIN_SCRIPTED_ORIENT) (AImain.cpp:3113-3124): the level
    /// script hears it first, then the object.
    mutating func aiNotifyScriptedOrient(_ handle: ObjectHandle,
                                         goalIndex: Int, level: Level) {
        guard aiNotifyReaches(handle),
              let guid = objects[handle]?.ai?.goals[goalIndex].guid
        else {
            return
        }
        let event = ScriptEvent.aiNotify(
            .scriptedOrient, it: handle,
            info: .goal(index: goalIndex, guid: guid)
        )
        osirisCallLevelEvent(event, level: level)
        osirisCallEvent(handle, event, level: level)
    }

    /// AINotify(AIN_USER_DEFINED) (AImain.cpp:3250): the command goes to the
    /// object's scripts, even a ghosted object's (:2900). Returns the
    /// script result.
    @discardableResult
    mutating func aiNotifyUserDefined(_ handle: ObjectHandle,
                                      command: GuideBotCommand,
                                      it: ObjectHandle = .none,
                                      level: Level) -> Bool {
        guard let object = objects[handle],
              object.ai.map({
                  $0.flags & ObjectAIFrame.disabledFlag == 0
              }) ?? true
        else {
            return false
        }
        return osirisCallEvent(
            handle,
            .aiNotify(.userDefined, it: it, info: .command(command)),
            level: level
        )
    }
}
