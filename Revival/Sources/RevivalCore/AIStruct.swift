// SPDX-License-Identifier: GPL-3.0-or-later
//
// The per-object AI state. Translated from Descent3/aistruct.h (ai_frame
// :737, goal :625, ai_path_info :488, ai_mem, the AIC_/AIT_/MC_ values
// :441-446) and Descent3/aistruct_external.h (the AIF_, AIN_, AIG_, GF_,
// AISR_, and AWARE_ values, :178-401). Only the fields that the translated
// AI reads or writes are here; the others arrive with the code that uses
// them.

import Foundation

/// `ai_frame` of a CT_AI object.
struct ObjectAIFrame: Codable, Equatable, Sendable {
    // AIF_ flags (aistruct_external.h:345-382).
    static let fireFlag: UInt32 = 0x0000_0100
    static let determineTargetFlag: UInt32 = 0x0000_0400
    static let persistentFlag: UInt32 = 0x0000_0040
    static let disabledFlag: UInt32 = 0x0000_4000
    static let fluctuateSpeedFlag: UInt32 = 0x0000_8000
    static let teamMask: UInt32 = 0x0003_0000
    static let teamPTMC: UInt32 = 0x0000_0000
    static let teamRebel: UInt32 = 0x0001_0000
    static let teamHostile: UInt32 = 0x0002_0000
    static let teamNeutral: UInt32 = 0x0003_0000
    static let orientToVelocityFlag: UInt32 = 0x0008_0000
    static let targetByDistanceFlag: UInt32 = 0x0040_0000
    static let disableFiringFlag: UInt32 = 0x0080_0000
    static let forceAwarenessFlag: UInt32 = 0x2000_0000
    static let upVectorFOVFlag: UInt32 = 0x4000_0000
    static let aimPointFOVFlag: UInt32 = 0x8000_0000
    static let actAsNeutralUntilShotFlag: UInt32 = 0x0000_0020

    // AISR_ status bits (aistruct_external.h:394-400).
    static let circleDistanceStatus: UInt32 = 0x04
    static let meleeStatus: UInt32 = 0x10
    static let rangedAttackStatus: UInt32 = 0x20
    static let seesGoalStatus: UInt32 = 0x40

    // AWARE_ levels (aistruct_external.h:323-327).
    static let awareFully: Float = 100
    static let awareMostly: Float = 60
    static let awareBarely: Float = 15
    static let awareNone: Float = 0

    // AIT_ types (aistruct_external.h:74-82).
    static let stationaryTurretType: UInt8 = 4

    /// MAX_GOALS (aistruct_external.h:178).
    static let maximumGoals = 10
    /// NUM_ACTIVATION_LEVELS (aistruct_external.h:279).
    static let activationLevels = 4
    /// AI_MEM_DEPTH (aistruct.h:715).
    static let memoryDepth = 5

    var aiClass: UInt8
    var aiType: UInt8
    var path = AIPathInfo()
    var maxVelocity: Float
    var maxDeltaVelocity: Float
    var maxTurnRate: Float
    var maxDeltaTurnRate: Float
    var circleDistance: Float
    var movementType: UInt8
    var movementSubtype: UInt8
    var goals: [AIGoal] = Array(repeating: AIGoal(), count: maximumGoals)
    var targetHandle: ObjectHandle = .none
    var nextTargetUpdateTime: Float = 0
    var distToTargetActual: Float = 0
    var distToTargetPerceived: Float = 0
    var vecToTargetActual = Vector3.zero
    var vecToTargetPerceived = Vector3.zero
    var nextCheckSeeTargetTime: Float = 0
    var lastSeeTargetPosition = Vector3.zero
    var lastSeeTargetTime: Float = 0
    var lastHearTargetTime: Float = 0
    var weaponSpeed: Float = 0
    var lastRenderTime: Float = -1
    var statusRegister: UInt32 = 0
    /// The AIF_ flags.
    var flags: UInt32
    var notifyFlags: UInt32
    var fov: Float
    var aggression: Float
    var lifePreservation: Float
    var memoryTimeUntilNextUpdate: Float = 0
    var memory: [AIMemory] = Array(repeating: AIMemory(), count: memoryDepth)
    var fireSpread: Float
    var leadAccuracy: Float
    var attackVelocityPercent: Float
    var dodgeVelocityPercent: Float
    var fleeVelocityPercent: Float
    /// `fight_team` and `fight_same`: the chance a hit by a friend turns
    /// the object on it.
    var fightTeam: Float
    var fightSame: Float
    /// `next_flinch_time`: AIInit sets it to the Gametime of level start.
    var nextFlinchTime: Float = 0
    /// `movement_dir`: ai_move's blended movement direction.
    var movementDirection = Vector3.zero
    var awareness: Float = 0

    /// ObjSetAIInfo (AImain.cpp:3587): the page values an object starts
    /// with.
    init(info: CanonicalAIInfo) {
        aiClass = info.aiClass
        aiType = info.aiType
        maxVelocity = info.maxVelocity
        maxDeltaVelocity = info.maxDeltaVelocity
        maxTurnRate = info.maxTurnRate
        maxDeltaTurnRate = info.maxDeltaTurnRate
        circleDistance = info.circleDistance
        movementType = info.movementType
        movementSubtype = info.movementSubtype
        flags = info.flags
        notifyFlags = info.notifyFlags
        fov = info.fov
        aggression = info.aggression
        lifePreservation = info.lifePreservation
        fireSpread = info.fireSpread
        leadAccuracy = info.leadAccuracy
        attackVelocityPercent = info.attackVelocityPercent
        dodgeVelocityPercent = info.dodgeVelocityPercent
        fleeVelocityPercent = info.fleeVelocityPercent
        fightTeam = info.fightTeam
        fightSame = info.fightSame
    }

    /// `ai_info->notify_flags & (1 << type)`.
    func notifies(_ type: Int) -> Bool {
        notifyFlags & (UInt32(1) << UInt32(type)) != 0
    }
}

/// `ai_mem` (aistruct.h): one memory slot. Only the fields the translated
/// code keeps.
struct AIMemory: Codable, Equatable, Sendable {
    var shields: Float = 0
    /// int16_t, as in ai_mem (aistruct.h:724-726); the increments wrap.
    var numberOfTimesHit: Int16 = 0
    var numberOfHitEnemy: Int16 = 0
}

/// `goal` (aistruct.h:625) for the goal types the runtime translates.
struct AIGoal: Codable, Equatable, Sendable {
    // AIG_ types (aistruct_external.h:181-208).
    static let followPathType: UInt32 = 0x0000_4000

    // GF_ flags (aistruct_external.h:216-252).
    static let nonflushableFlag: UInt32 = 0x0000_0001
    static let keepAtCompletionFlag: UInt32 = 0x0000_0004
    static let forceAwarenessFlag: UInt32 = 0x0000_0100
    static let orientVelocityFlag: UInt32 = 0x0000_1000
    static let orientTargetFlag: UInt32 = 0x0001_0000
    static let orientPathNodeFlag: UInt32 = 0x0010_0000
    static let pathReverseAtEndFlag: UInt32 = 0x0040_0000
    static let pathCircleAtEndFlag: UInt32 = 0x0080_0000
    static let pathMoveReverseFlag: UInt32 = 0x0100_0000
    static let inClearFlag: UInt32 = 0x0200_0000
    static let clearIfNotCurrentFlag: UInt32 = 0x0800_0000
    static let speedMask: UInt32 = 0xc000_0000
    /// GFM_END_OF_PATH.
    static let endOfPathMask: UInt32 = pathReverseAtEndFlag
        | pathCircleAtEndFlag

    var used = false
    var type: UInt32 = 0
    var influence: Float = 0
    var creationTime: Float = 0
    var startTime: Float = 0
    var circleDistance: Float = 0
    var statusRegister: UInt32 = 0
    var nextPathTime: Float = 0
    var flags: UInt32 = 0
    /// Designer-assigned id (`guid`).
    var guid: Int32 = -1
    /// `goal_uid`, from AI_unique_goal_id.
    var uniqueID: Int32 = 0
    /// `g_info.id`: the game path of a follow-path goal.
    var pathID: Int = 0
    /// `g_info.static_path_info`.
    var staticPathStartNode: Int = 0
    var staticPathEndNode: Int = 0
    var staticPathCurrentNode: Int = 0
}

/// `ai_path_info` (aistruct.h:488) for one static game path, the only path
/// kind the runtime makes (AIPathAddStaticPath, aipath.cpp:590). Dynamic
/// paths arrive with AIPathAllocPath and BOA in M2.
struct AIPathInfo: Codable, Equatable, Sendable {
    var currentNode: Int = 0
    /// `num_paths`: 0 or 1.
    var numberOfPaths: Int = 0
    var goalUniqueID: Int32 = -1
    var goalIndex: Int = -1
    var pathID: Int = 0
    var startNode: Int = 0
    var endNode: Int = 0
}
