// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

func defaultPlayerView(
    in level: Level,
    projection: PerspectiveProjection = .sourceDefault
) -> PlayerView {
    let binding = level.defaultPlayerBinding!
    let object = level.objects.first { $0.handle == binding.objectHandle }!
    let ship = level.shipDefinitions.first { $0.source == binding.ship }!
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("The validated default player start is indoor.")
    }
    return PlayerView(
        playerID: binding.playerID,
        objectHandle: object.handle,
        roomSourceIndex: roomSourceIndex,
        camera: RoomCamera(
            position: object.position,
            target: object.position + object.orientation.forward,
            up: object.orientation.up,
            projection: projection
        ),
        collisionRadius: ship.presentationSize * 0.8
    )
}

func rearPlayerView(_ playerView: PlayerView) -> PlayerView {
    let camera = playerView.camera
    return PlayerView(
        playerID: playerView.playerID,
        objectHandle: playerView.objectHandle,
        roomSourceIndex: playerView.roomSourceIndex,
        camera: RoomCamera(
            position: camera.position,
            target: camera.position - (camera.target - camera.position),
            up: camera.up,
            projection: camera.projection
        ),
        collisionRadius: playerView.collisionRadius
    )
}

func trainingGuidebotRoute(
    in level: Level,
    startRoomSourceIndex: Int,
    start: Vector3,
    startForward: Vector3,
    destinationRoomSourceIndex: Int,
    destination: Vector3,
    radius: Float
) -> Result<TrainingGuidebotRoute, TrainingGuidebotRouteError> {
    precondition(
        radius.isFinite && radius >= 0
            && startForward.x.isFinite
            && startForward.y.isFinite
            && startForward.z.isFinite
    )
    let boaRooms = trainingGuidebotBOARoomRoute(
        in: level,
        start: startRoomSourceIndex,
        destination: destinationRoomSourceIndex
    )
    guard let boaRooms else { return .failure(.noBOAPath) }
    if trainingGuidebotProbeIsClear(
        in: level,
        startRoomSourceIndex: startRoomSourceIndex,
        start: start,
        destination: destination,
        radius: radius
    ) {
        return .success(.init(
            mode: .direct,
            points: [destination],
            roomSourceIndices: boaRooms,
            nodeReferences: []
        ))
    }

    guard let graph = level.indoorNavigation,
          graph.sourceWasVerified else {
        return .failure(.unverifiedBoundaryNodes)
    }
    let navigationByRoom = Dictionary(
        uniqueKeysWithValues: graph.rooms.map { ($0.sourceIndex, $0) }
    )
    if startRoomSourceIndex != destinationRoomSourceIndex {
        let roomBySourceIndex = Dictionary(
            uniqueKeysWithValues: level.rooms.map {
                ($0.sourceIndex, $0)
            }
        )
        var portalPoints: [Vector3] = []
        for (roomSourceIndex, nextRoomSourceIndex) in zip(
            boaRooms,
            boaRooms.dropFirst()
        ) {
            guard let portal = roomBySourceIndex[roomSourceIndex]?
                .portals.first(where: {
                    $0.connectedRoom == nextRoomSourceIndex
                })
            else {
                return .failure(.noRoomPortalPath)
            }
            portalPoints.append(portal.pathPoint)
        }
        return .success(.init(
            mode: .roomPortals,
            points: portalPoints + [destination],
            roomSourceIndices: boaRooms,
            nodeReferences: []
        ))
    }
    guard let startNodes = navigationByRoom[startRoomSourceIndex]?.nodes,
          let destinationNodes =
            navigationByRoom[destinationRoomSourceIndex]?.nodes
    else {
        return .failure(.noVisibleBoundaryNode)
    }
    let probeRadius = min(radius / 4, 20)
    let visibleStartNodes = startNodes.indices.filter {
        trainingGuidebotDistance(start, startNodes[$0].position) < 800
            && trainingGuidebotProbeIsClear(
                in: level,
                startRoomSourceIndex: startRoomSourceIndex,
                start: start,
                destination: startNodes[$0].position,
                radius: probeRadius
            )
    }
    let forwardStartNodes = visibleStartNodes.filter {
        dot(
            startForward,
            normalized(startNodes[$0].position - start)
        ) > 0
    }
    let startReference = (forwardStartNodes.last ?? visibleStartNodes.last)
        .map {
            IndoorNavigationNodeReference(
                roomSourceIndex: startRoomSourceIndex,
                nodeIndex: $0
            )
        }
    let visibleDestinationNodes = destinationNodes.indices
        .filter {
            destinationNodes[$0].edges.contains {
                $0.maximumRadius >= probeRadius
            }
                &&
            trainingGuidebotProbeIsClear(
                in: level,
                startRoomSourceIndex: destinationRoomSourceIndex,
                start: destinationNodes[$0].position,
                destination: destination,
                radius: probeRadius
            )
        }
    let destinationReference = (
        visibleDestinationNodes.min {
            trainingGuidebotQuickDistance(
                destinationNodes[$0].position,
                destination
            ) < trainingGuidebotQuickDistance(
                destinationNodes[$1].position,
                destination
            )
        }
            ?? destinationNodes.indices
                .filter {
                    trainingGuidebotQuickDistance(
                        destinationNodes[$0].position,
                        destination
                    ) < 800
                }
                .min {
                    trainingGuidebotQuickDistance(
                        destinationNodes[$0].position,
                        destination
                    ) < trainingGuidebotQuickDistance(
                        destinationNodes[$1].position,
                        destination
                    )
                }
    )
        .map {
            IndoorNavigationNodeReference(
                roomSourceIndex: destinationRoomSourceIndex,
                nodeIndex: $0
            )
        }
    guard let startReference, let destinationReference else {
        return .failure(.noVisibleBoundaryNode)
    }
    guard let references = trainingGuidebotBoundaryNodePath(
        room: navigationByRoom[startRoomSourceIndex]!,
        start: startReference,
        destination: destinationReference
    ) else {
        return .failure(.noBoundaryNodePath)
    }
    let points = references.map {
        navigationByRoom[$0.roomSourceIndex]!.nodes[$0.nodeIndex].position
    } + [destination]
    var orderedRooms: [Int] = []
    for reference in references
    where orderedRooms.last != reference.roomSourceIndex {
        orderedRooms.append(reference.roomSourceIndex)
    }
    return .success(.init(
        mode: .boundaryNodes,
        points: points,
        roomSourceIndices: orderedRooms,
        nodeReferences: references
    ))
}

private func trainingGuidebotBOARoomRoute(
    in level: Level,
    start: Int,
    destination: Int
) -> [Int]? {
    guard level.rooms.contains(where: { $0.sourceIndex == start }),
          level.rooms.contains(where: {
              $0.sourceIndex == destination
          }) else {
        return nil
    }
    if start == destination { return [start] }
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    var queue = [start]
    var predecessor: [Int: Int] = [:]
    var visited: Set<Int> = [start]
    while !queue.isEmpty {
        let roomSourceIndex = queue.removeFirst()
        for portal in roomBySourceIndex[roomSourceIndex]!.portals {
            let next = portal.connectedRoom
            guard visited.insert(next).inserted else { continue }
            predecessor[next] = roomSourceIndex
            if next == destination {
                var result = [destination]
                while result.last != start {
                    result.append(predecessor[result.last!]!)
                }
                return Array(result.reversed())
            }
            queue.append(next)
        }
    }
    return nil
}

private func trainingGuidebotBoundaryNodePath(
    room: IndoorNavigationRoom,
    start: IndoorNavigationNodeReference,
    destination: IndoorNavigationNodeReference
) -> [IndoorNavigationNodeReference]? {
    guard start.roomSourceIndex == room.sourceIndex,
          destination.roomSourceIndex == room.sourceIndex else {
        return nil
    }
    var distances = [start.nodeIndex: 0]
    var predecessor: [Int: Int] = [:]
    var pending = [start.nodeIndex]
    var visited: Set<Int> = []
    while !pending.isEmpty {
        let current = pending.indices.min {
            let lhs = pending[$0]
            let rhs = pending[$1]
            let lhsDistance = distances[lhs, default: .max]
            let rhsDistance = distances[rhs, default: .max]
            return lhsDistance == rhsDistance
                ? $0 > $1
                : lhsDistance < rhsDistance
        }.map { pending.remove(at: $0) }!
        guard visited.insert(current).inserted else { continue }
        if current == destination.nodeIndex {
            var result = [current]
            while result.last != start.nodeIndex {
                result.append(predecessor[result.last!]!)
            }
            return result.reversed().map {
                IndoorNavigationNodeReference(
                    roomSourceIndex: room.sourceIndex,
                    nodeIndex: $0
                )
            }
        }
        for edge in room.nodes[current].edges
        where edge.destinationRoomSourceIndex == room.sourceIndex
            && room.nodes.indices.contains(edge.destinationNodeIndex) {
            let next = edge.destinationNodeIndex
            let candidate = distances[current]! + edge.cost
            if candidate <= distances[next, default: .max] {
                distances[next] = candidate
                predecessor[next] = current
                pending.append(next)
            }
        }
    }
    return nil
}

private func trainingGuidebotProbeIsClear(
    in level: Level,
    startRoomSourceIndex: Int,
    start: Vector3,
    destination: Vector3,
    radius: Float
) -> Bool {
    if case .noHit = traceIndoorMovement(
        in: level,
        startRoom: startRoomSourceIndex,
        start: start,
        end: destination,
        radius: radius
    ).outcome {
        return true
    }
    return false
}

private func trainingGuidebotDistance(
    _ lhs: Vector3,
    _ rhs: Vector3
) -> Float {
    let delta = lhs - rhs
    return sqrt(dot(delta, delta))
}

private func trainingGuidebotQuickDistance(
    _ lhs: Vector3,
    _ rhs: Vector3
) -> Float {
    abs(lhs.x - rhs.x)
        + abs(lhs.y - rhs.y)
        + abs(lhs.z - rhs.z)
}

private func trainingCameraMonitorGoalTarget(
    in level: Level
) -> PlacedObject? {
    guard let cameraChain = level.trainingCameraMonitorChain else {
        return nil
    }
    let activePrimaryIndices = level.goals.indices.filter { index in
        let status = level.goals[index].status
        return status & 0x0000_0004 != 0
            && status
                & (0x0000_0002 | 0x0000_0008 | 0x0000_0080)
                == 0
    }
    let minimumPriorityByList = Dictionary(
        activePrimaryIndices.map {
            (level.goals[$0].list, level.goals[$0].priority)
        },
        uniquingKeysWith: min
    )
    let firstActivePrimaryIndex = (Int8(0)...Int8(3))
        .lazy
        .compactMap { list in
            activePrimaryIndices.first { index in
                let goal = level.goals[index]
                return goal.list == list
                    && goal.priority == minimumPriorityByList[list]
            }
        }
        .first
    guard let firstActivePrimaryIndex else { return nil }
    let goal = level.goals[firstActivePrimaryIndex]
    guard goal.status & (0x0000_0020 | 0x0000_0040) == 0,
          goal.name == "Locate the Camera Monitor",
          goal.itemName == "Camera Monitor",
          goal.items.count == 1,
          let item = goal.items.first,
          item.type == 2,
          item.sourceHandle == cameraChain.pickupObjectHandle,
          item.objectHandle == cameraChain.pickupObjectHandle,
          !item.done,
          let target = trainingCameraMonitorObjectTarget(in: level)
    else {
        return nil
    }
    return target
}

private func trainingCameraMonitorObjectTarget(
    in level: Level
) -> PlacedObject? {
    guard let cameraChain = level.trainingCameraMonitorChain,
          cameraChain.returnToShip != nil,
          let target = level.objects.first(where: {
              $0.handle == cameraChain.pickupObjectHandle
          }),
          target.type == 7,
          target.location == .room(39)
    else {
        return nil
    }
    return target
}

private struct TrainingOpeningState: Codable, Equatable, Sendable {
    var timerRemaining: Float
    var welcomeWasPresented = false
    var forwardGoalWasReached = false
    var returnGoalWasReached: Bool? = nil
    var rightGoalWasReached: Bool? = nil
    var upGoalWasReached: Bool? = nil
    var downGoalWasReached: Bool? = nil
    var repeatForwardWasPresented: Bool? = nil
    var repeatForwardGoalWasPresented: Bool? = nil
    var repeatReturnLeftWasPresented: Bool? = nil
    var repeatReturnRightWasPresented: Bool? = nil
    var repeatReturnUpWasPresented: Bool? = nil
    var repeatReturnDownWasPresented: Bool? = nil
    var continueToCourseWasPresented: Bool? = nil
    var startCourseWasPresented: Bool? = nil
    var finishCourseWasPresented: Bool? = nil
    var script030Count: Int? = nil
    var enabledControls: PlayerControlMask = [.forward]
}

private struct TrainingGalleryBarrierState: Codable, Equatable, Sendable {
    var wasTriggered = false
    var markerLightDistance: Float
}

private struct TrainingRobotGuidebotState: Codable, Equatable, Sendable {
    var robotWasDestroyed = false
    var robotShields: Float
    var nextPrimaryFireTime: Float = 0
    var projectiles: [TrainingLaserProjectileState] = []
    var guidebotIsDeployed = false
    var guidebot: TrainingGuidebotRuntimeState?
    var guidebotContinuationWasPresented = false
    var activeGoalWasReached: Bool? = nil
    var guidebotMode: TrainingGuidebotMode? = nil
    var guidebotModeTime: Float? = nil
    var nextAmbientTime: Float? = nil
    var timeUntilNextPlayerVisibilityCheck: Float? = nil
    var timeUntilNextFlare: Float? = nil
    var yellowFlareGoalSlots:
        TrainingGuidebotYellowFlareGoalSlots? = nil
    var yellowFlares:
        [TrainingGuidebotYellowFlareState]? = nil
    var yellowFlareParticles:
        [TrainingGuidebotYellowFlareParticleState]? = nil
    var yellowFlareTimeoutExplosions:
        [TrainingGuidebotYellowFlareTimeoutExplosionState]? = nil
    var yellowFlareTimeoutSparks:
        [TrainingGuidebotYellowFlareTimeoutSparkState]? = nil
    var yellowFlareTimeoutSparkParticles:
        [TrainingGuidebotYellowFlareParticleState]? = nil
    var yellowFlareTimeoutReachedFollowingFrame: Bool? = nil
    var nextPowerupCheckTime: Float? = nil
    var lastMessageSoundTime: Float? = nil
    var returnTime: Float? = nil
    var returnGreetingWasPresented: Bool? = nil
    var returnWasRequested = false
    var guidebotEnteredShip = false
    var arrivalFeedbackWasPresented = false
    var controlsWereRestored = false
    var enabledControlHUDIsVisible = true
    var destructionTimerRemaining: Float?
    var destructionFeedbackWasPresented = false
}

private struct TrainingGuidebotYellowFlareGoalSlots:
    Codable, Equatable, Sendable
{
    var slot1IsUsed: Bool
    var slot2IsUsed: Bool
    var slot3IsUsed: Bool

    var isEligible: Bool {
        slot1IsUsed && !slot2IsUsed && !slot3IsUsed
    }
}

private struct TrainingGuidebotYellowFlareState:
    Codable, Equatable, Sendable
{
    var roomSourceIndex: Int
    var position: Vector3
    var orientation: Matrix3
    var velocity: Vector3
    var lifeRemaining: Float
    var lastParticleDropTime: Float
    var presentedLightDistance: Float
    var stuckObjectHandle: UInt32? = nil
    var stuckObjectOffset: Vector3? = nil
    var stuckObjectOrientation: Matrix3? = nil
    var sourceObjectSlot: Int? = nil
    var creationOrdinal: UInt64? = nil
    var parentObjectHandle: UInt32? = nil
}

private enum YellowFlareAdvanceSelection {
    case all
    case none
    case ordinal(UInt64)

    func includes(_ ordinal: UInt64?) -> Bool {
        switch self {
        case .all:
            true
        case .none:
            false
        case .ordinal(let selected):
            ordinal == selected
        }
    }
}

private struct TrainingGuidebotYellowFlareParticleState:
    Codable, Equatable, Sendable
{
    let roomSourceIndex: Int
    var position: Vector3
    var velocity: Vector3
    let size: Float
    let lifetime: Float
    var lifeRemaining: Float
    var creationTime: Float? = nil
    var generationOrdinal: UInt64? = nil
    var sourceAttemptIndex: Int? = nil
}

private struct TrainingGuidebotYellowFlareTimeoutExplosionState:
    Codable, Equatable, Sendable
{
    let roomSourceIndex: Int
    let position: Vector3
    let size: Float
    let lifetime: Float
    var lifeRemaining: Float
    var creationTime: Float? = nil
    var generationOrdinal: UInt64? = nil
}

private struct TrainingGuidebotYellowFlareTimeoutSparkState:
    Codable, Equatable, Sendable
{
    let sourceAttemptIndex: Int
    let sourceObjectSlot: Int
    let receivedControlOnCreationFrame: Bool
    var roomSourceIndex: Int
    var position: Vector3
    let orientation: Matrix3
    var velocity: Vector3
    var lifeRemaining: Float
    var lastParticleDropTime: Float
    var presentedLightDistance: Float
    var generationOrdinal: UInt64? = nil
}

private struct PlayerYellowFlareState: Codable, Equatable, Sendable {
    var nextCreationOrdinal: UInt64 = 0
    var nextFireTime: Float = 0
    var parents: [TrainingGuidebotYellowFlareState] = []
    var parentParticles: [TrainingGuidebotYellowFlareParticleState] = []
    var timeoutExplosions:
        [TrainingGuidebotYellowFlareTimeoutExplosionState] = []
    var timeoutSparks: [TrainingGuidebotYellowFlareTimeoutSparkState] = []
    var timeoutSparkParticles:
        [TrainingGuidebotYellowFlareParticleState] = []
}

private struct PlayerConcussionMissileState:
    Codable, Equatable, Sendable
{
    let creationOrdinal: UInt64
    var roomSourceIndex: Int
    var position: Vector3
    var orientation: Matrix3
    let velocity: Vector3
    var lifeRemaining: Float
}

private struct PlayerConcussionExplosionState:
    Codable, Equatable, Sendable
{
    let creationOrdinal: UInt64
    let roomSourceIndex: Int
    let position: Vector3
    var lifeRemaining: Float
    var shockwaveLifeRemaining: Float
    var damagedObjectHandles: Set<UInt32> = []
    var damagedPlayer = false
}

private struct PlayerConcussionSparkState:
    Codable, Equatable, Sendable
{
    let creationOrdinal: UInt64
    let roomSourceIndex: Int
    var position: Vector3
    var velocity: Vector3
    let size: Float
    let lifetime: Float
    var lifeRemaining: Float
}

private struct PlayerConcussionState: Codable, Equatable, Sendable {
    var ammo = 6
    var nextFireTime: Float = 0
    var nextFiringMaskIndex = 0
    var nextCreationOrdinal: UInt64 = 0
    var missiles: [PlayerConcussionMissileState] = []
    var explosions: [PlayerConcussionExplosionState] = []
    var sparks: [PlayerConcussionSparkState] = []
}

let trainingGuidebotYellowFlarePresentationCapacity = 6
let trainingGuidebotYellowFlareParticlePresentationCapacity = 64
let trainingGuidebotYellowFlareTimeoutExplosionPresentationCapacity = 1
let trainingGuidebotYellowFlareTimeoutSparkPresentationCapacity = 9
let trainingGuidebotYellowFlareTimeoutSparkParticlePresentationCapacity = 54
let playerYellowFlarePresentationCapacity = 16
let playerYellowFlareParticlePresentationCapacity = 208
let playerYellowFlareTimeoutExplosionPresentationCapacity = 16
let playerYellowFlareTimeoutSparkPresentationCapacity = 144
let playerYellowFlareTimeoutSparkParticlePresentationCapacity = 864
let combinedYellowFlarePresentationCapacity = 22
let combinedYellowFlareParticlePresentationCapacity = 272
let combinedYellowFlareTimeoutExplosionPresentationCapacity = 17
let combinedYellowFlareTimeoutSparkPresentationCapacity = 153
let combinedYellowFlareTimeoutSparkParticlePresentationCapacity = 918

private struct TrainingCameraMonitorState:
    Codable, Equatable, Sendable
{
    var isHeld = false
    var wasUsed = false
    var popupRemaining: Float?
    var completionTimerRemaining: Float?
    var completionTimerWasConsumed = false
    var returnMarkerLightDistance: Float = 0
    var script058WasPresented = false
}

private struct TrainingKillbotEntryState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
    var followupTimerRemaining: Float?
    var followupWasPresented = false
}

private struct TrainingRobotDeathState:
    Codable, Equatable, Sendable
{
    var wasDestroyed = false
    var shields: Float
}

private typealias TrainingRASBot1DeathState = TrainingRobotDeathState
private typealias TrainingRASBot2DeathState = TrainingRobotDeathState
private typealias TrainingRASBot3DeathState = TrainingRobotDeathState
private typealias TrainingRASBot4DeathState = TrainingRobotDeathState
private typealias TrainingLastBot1DeathState = TrainingRobotDeathState
private typealias TrainingLastBot2DeathState = TrainingRobotDeathState
private typealias TrainingLastBot3DeathState = TrainingRobotDeathState
private typealias TrainingLastBot4DeathState = TrainingRobotDeathState
private typealias TrainingLastBot5DeathState = TrainingRobotDeathState

private struct TrainingInvulnerabilityPickupState:
    Codable, Equatable, Sendable
{
    var scriptWasTriggered = false
    var wasConsumed = false
    var remainingDuration: Float?
}

private struct TrainingCloakPickupState:
    Codable, Equatable, Sendable
{
    var scriptWasTriggered = false
    var wasConsumed = false
    var phase: TrainingCloakPhase?
    var phaseRemaining: Float?
}

private struct TrainingLastRoomState: Codable, Equatable, Sendable {
    var wasTriggered = false
    var markerLightDistance: Float = 0
    var timerRemaining: Float?
    var wasPresented = false
}

private struct TrainingFinalBotsCompletionState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
    var markerLightDistance: Float = 0
    var timerRemaining: Float?
    var wasPresented = false
}

private struct TrainingFinalGoalState:
    Codable, Equatable, Sendable
{
    var endLevelWasRequested = false
    var scriptActionCounter = 0
}

private struct TrainingFinalRoomEntryState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
}

private enum TrainingGuidebotTask: String, Codable, Equatable, Sendable {
    case outbound
    case activeGoal
    case returnToPlayer
    case escortPlayer
    case returnToShip
}

private enum TrainingGuidebotMode: String, Codable, Equatable, Sendable {
    case birth
    case ambient
}

private enum TrainingGuidebotAdvanceEvent: Equatable {
    case reachedActiveGoal
    case returnedToPlayer
    case enteredShip
}

private struct TrainingGuidebotRuntimeState:
    Codable, Equatable, Sendable
{
    let spawnPosition: Vector3
    var roomSourceIndex: Int
    var position: Vector3
    let orientation: Matrix3
    let spawnVelocity: Vector3
    var velocity: Vector3
    var destination: Vector3
    var route: TrainingGuidebotRoute
    var routeFailure: TrainingGuidebotRouteError?
    var routePointIndex: Int
    var activeSteeringMode: TrainingGuidebotSteeringMode
    var task: TrainingGuidebotTask
    var allocationStartPosition: Vector3
    var allocationStartForward: Vector3
    var routeDestination: Vector3
    var routeDestinationRoomSourceIndex: Int

    var frame: TrainingGuidebotFrame {
        .init(
            spawnPosition: spawnPosition,
            roomSourceIndex: roomSourceIndex,
            position: position,
            orientation: orientation,
            spawnVelocity: spawnVelocity,
            velocity: velocity,
            destination: destination,
            route: route,
            routeFailure: routeFailure,
            activeSteeringMode: activeSteeringMode
        )
    }
}

private struct TrainingLaserProjectileState:
    Codable, Equatable, Sendable
{
    var roomSourceIndex: Int
    var position: Vector3
    let velocity: Vector3
    var lifeRemaining: Float
}

private struct TrainingDodgeProjectileState:
    Codable, Equatable, Sendable
{
    var roomSourceIndex: Int
    var position: Vector3
    let velocity: Vector3
    var lifeRemaining: Float
}

private struct TrainingDodgeAttemptState:
    Codable, Equatable, Sendable
{
    var script033Count = 0
    var script016Count = 0
    var script017Count = 0
    var script019Count: Int? = nil
    var script018Count = 0
    var script020Count = 0
    var triggerTimerRemaining: Float?
    var successTimerRemaining: Float?
    var almostDoneTimerRemaining: Float?
    var turretIsPowered = false
    var nextFireTime: Float = 0
    var firingMaskIndex = 0
    var turretAngles: [Float] = [0, 0]
    var turretDirections: [Int] = [0, 0]
    var retainedTargetPosition: Vector3?
    var lastVisibleTargetTime: Float = -14
    var nextVisibilityCheckTime: Float = 0
    var seesTarget = false
    var awareness: Float = 0
    var weaponSpeed: Float = 0
    var projectiles: [TrainingDodgeProjectileState] = []
    var markerLightDistance: Float = 0
}

private struct TrainingManeuverFollowState:
    Codable, Equatable, Sendable
{
    var script021Count = 0
    var script022Count = 0
    var script024Count = 0
    var script023Count = 0
    var script025Count = 0
    var script026Count = 0
    var levelTimerRemaining: Float?
    var objectTimerRemaining: Float?
    var followBotIsPowered = false
    var followBotTeamFlags: UInt32 = 0
    var roomSourceIndex: Int
    var position: Vector3
    var orientation: Matrix3
    var velocity = Vector3.zero
    var activePathIndex: Int?
    var pathNodeIndex = 0
    var pathFailure: TrainingFollowBotPathFailure?
    var destruction: TrainingFollowBotDestructionState? = nil

    var frame: TrainingFollowBotFrame {
        .init(
            isPowered: followBotIsPowered,
            teamFlags: followBotTeamFlags,
            roomSourceIndex: roomSourceIndex,
            position: position,
            orientation: orientation,
            velocity: velocity,
            activePathIndex: activePathIndex,
            pathNodeIndex: pathNodeIndex,
            objectTimerRemaining: objectTimerRemaining,
            pathFailure: pathFailure,
            script021Count: script021Count,
            script022Count: script022Count,
            script024Count: script024Count,
            script023Count: script023Count,
            script025Count: script025Count,
            script026Count: script026Count
        )
    }
}

private struct TrainingAuthoredPathMotion:
    Codable, Equatable, Sendable
{
    var roomSourceIndex: Int
    var position: Vector3
    var orientation: Matrix3
    var velocity = Vector3.zero
    var activePathIndex: Int?
    var pathNodeIndex = 0
    var pathFailure: TrainingFollowBotPathFailure?
}

private struct TrainingDestroyBot1DestructionState:
    Codable, Equatable, Sendable
{
    var destroyBot1Shields: Float
    var destroyBot1WasDestroyed = false
    var script028Count = 0
    var destroyBot2Motion: TrainingAuthoredPathMotion
}

private struct TrainingFollowBotDestructionState:
    Codable, Equatable, Sendable
{
    var followBotShields: Float
    var followBotWasDestroyed = false
    var script031Count = 0
    var script037Count = 0
    var script027Count = 0
    var levelTimer11Remaining: Float?
    var destroyBot2IsVisible = false
    var destroyBot1IsVisible = false
    var destroyBot2TeamFlags: UInt32 = 0
    var destroyBot1TeamFlags: UInt32 = 0
    var destroyBot1Motion: TrainingAuthoredPathMotion
    var destroyBot1Destruction:
        TrainingDestroyBot1DestructionState? = nil

    func movingTargetFrame(
        handoff: TrainingFollowBotDestructionHandoff
    ) -> TrainingMovingTargetFrame? {
        if let destroyBot1Destruction,
           destroyBot1Destruction.script028Count > 0,
           destroyBot2IsVisible,
           let activePathIndex =
            destroyBot1Destruction.destroyBot2Motion.activePathIndex
        {
            return .init(
                objectHandle: handoff.destroyBot2ObjectHandle,
                roomSourceIndex:
                    destroyBot1Destruction.destroyBot2Motion
                        .roomSourceIndex,
                activePathIndex: activePathIndex,
                pathNodeIndex:
                    destroyBot1Destruction.destroyBot2Motion
                        .pathNodeIndex,
                pathFailure:
                    destroyBot1Destruction.destroyBot2Motion
                        .pathFailure
            )
        }
        guard script027Count > 0,
              destroyBot1IsVisible,
              let activePathIndex =
                destroyBot1Motion.activePathIndex
        else {
            return nil
        }
        return .init(
            objectHandle: handoff.destroyBot1ObjectHandle,
            roomSourceIndex: destroyBot1Motion.roomSourceIndex,
            activePathIndex: activePathIndex,
            pathNodeIndex: destroyBot1Motion.pathNodeIndex,
            pathFailure: destroyBot1Motion.pathFailure
        )
    }
}

private func initialTrainingManeuverFollowState(
    level: Level,
    lesson: TrainingManeuverFollowLesson
) -> TrainingManeuverFollowState? {
    guard let followBot = level.objects.first(where: {
        $0.handle == lesson.followBotObjectHandle
    }),
          case let .room(roomSourceIndex) = followBot.location
    else {
        return nil
    }
    var state = TrainingManeuverFollowState(
        roomSourceIndex: roomSourceIndex,
        position: followBot.position,
        orientation: followBot.orientation
    )
    if let handoff = lesson.destructionHandoff,
       let destroyBot1 = level.objects.first(where: {
           $0.handle == handoff.destroyBot1ObjectHandle
       }),
       case let .room(destroyBot1Room) = destroyBot1.location {
        state.destruction = .init(
            followBotShields: handoff.combat.robotShields,
            destroyBot1Motion: .init(
                roomSourceIndex: destroyBot1Room,
                position: destroyBot1.position,
                orientation: destroyBot1.orientation
            )
        )
    }
    return state
}

private func initialTrainingDestroyBot1DestructionState(
    level: Level,
    handoff: TrainingFollowBotDestructionHandoff
) -> TrainingDestroyBot1DestructionState? {
    guard let destroyBot2 = level.objects.first(where: {
        $0.handle == handoff.destroyBot2ObjectHandle
    }),
          case let .room(roomSourceIndex) = destroyBot2.location
    else {
        return nil
    }
    return .init(
        destroyBot1Shields: handoff.combat.robotShields,
        destroyBot2Motion: .init(
            roomSourceIndex: roomSourceIndex,
            position: destroyBot2.position,
            orientation: destroyBot2.orientation
        )
    )
}

fileprivate struct PlayerRearViewState: Codable, Equatable, Sendable {
    var leaveMode: Bool
    let entryGameTime: Float
}

struct PlayerSimulationContinuation: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let levelKey: String
    let levelSHA256: String
    let playerLocation: SpatialLocation
    let playerPosition: Vector3
    let playerOrientation: Matrix3
    let frameDuration: Float
    let gameTime: Float
    let velocity: Vector3
    let angularVelocity: Vector3
    let turnrollFixedAngle: Float
    let indoorAutoLevelMode: IndoorAutoLevelMode
    let afterburnerFuel: Float
    let afterburnerIsActive: Bool
    let energy: Float
    let afterburnerMagnitude: Float
    let wiggleFalloff: Float
    let lastThrustTime: Float
    fileprivate let authoritativeRandomState: UInt32?
    fileprivate let shields: Float?
    fileprivate let playerHeadlightIsOn: Bool?
    fileprivate let playerRearViewState: PlayerRearViewState?
    fileprivate let trainingOpeningState: TrainingOpeningState?
    fileprivate let trainingDodgeAttemptState: TrainingDodgeAttemptState?
    fileprivate let trainingManeuverFollowState:
        TrainingManeuverFollowState?
    fileprivate let trainingGalleryBarrierState: TrainingGalleryBarrierState?
    fileprivate let trainingRobotGuidebotState: TrainingRobotGuidebotState?
    fileprivate let playerConcussionState: PlayerConcussionState?
    fileprivate let playerYellowFlareState: PlayerYellowFlareState?
    fileprivate let trainingCameraMonitorState: TrainingCameraMonitorState?
    fileprivate let trainingKillbotEntryState: TrainingKillbotEntryState?
    fileprivate let trainingRASBot1DeathState: TrainingRASBot1DeathState?
    fileprivate let trainingRASBot2DeathState: TrainingRASBot2DeathState?
    fileprivate let trainingRASBot3DeathState: TrainingRASBot3DeathState?
    fileprivate let trainingRASBot4DeathState: TrainingRASBot4DeathState?
    fileprivate let trainingLastBot1DeathState:
        TrainingLastBot1DeathState?
    fileprivate let trainingLastBot2DeathState:
        TrainingLastBot2DeathState?
    fileprivate let trainingLastBot3DeathState:
        TrainingLastBot3DeathState?
    fileprivate let trainingLastBot4DeathState:
        TrainingLastBot4DeathState?
    fileprivate let trainingLastBot5DeathState:
        TrainingLastBot5DeathState?
    fileprivate let trainingInvulnerabilityPickupState: TrainingInvulnerabilityPickupState?
    fileprivate let trainingCloakPickupState: TrainingCloakPickupState?
    fileprivate let trainingLastRoomState: TrainingLastRoomState?
    fileprivate let trainingFinalRoomEntryState:
        TrainingFinalRoomEntryState?
    fileprivate let trainingFinalBotsCompletionState:
        TrainingFinalBotsCompletionState?
    fileprivate let trainingFinalGoalState: TrainingFinalGoalState?
}

enum PlayerSimulationContinuationError: Error, Equatable {
    case unsupportedSchema
    case levelIdentityMismatch
    case invalidState
}

private func playerSimulationContinuationSchema(for level: Level) -> Int {
    if level.trainingRASBot1DeathChain != nil {
        return 7
    }
    if level.trainingCameraMonitorChain?.returnToShip?
        .killbotEntry != nil {
        return 6
    }
    if level.trainingCameraMonitorChain?.returnToShip != nil {
        return 5
    }
    return level.trainingCameraMonitorChain == nil ? 3 : 4
}

enum IndoorAutoLevelMode: Int, Codable, Sendable {
    case off = 0
    case standard = 1
    case newPlayer = 2
}

final class PlayerSimulation {
    private(set) var level: Level
    private(set) var frameDuration: Float = 0.1
    private(set) var gameTime: Float = 0
    private(set) var velocity = Vector3.zero
    private(set) var angularVelocity: Vector3
    private(set) var turnrollFixedAngle: Float = 0
    private(set) var indoorAutoLevelMode = IndoorAutoLevelMode.newPlayer
    private(set) var afterburnerFuel: Float = 5
    private(set) var afterburnerIsActive = false
    private(set) var energy: Float = 100
    private(set) var shields: Float = 100
    private(set) var trainingSessionOutcome: TrainingSessionOutcome?
    private(set) var afterburnerMagnitude: Float = 0
    private(set) var wiggleFalloff: Float = 0

    private var lastTimestamp: Double
    private var lastThrustTime: Float = 0
    private var authoritativeRandomState: UInt32
    private var playerHeadlightIsOn = false
    private var playerRearViewState: PlayerRearViewState?
    private var pauseDepth = 0
    private var pauseTimestamp: Double?
    private var trainingOpeningState: TrainingOpeningState?
    private var trainingDodgeAttemptState: TrainingDodgeAttemptState?
    private var trainingManeuverFollowState:
        TrainingManeuverFollowState?
    private var trainingGalleryBarrierState: TrainingGalleryBarrierState?
    private var trainingRobotGuidebotState: TrainingRobotGuidebotState?
    private var playerConcussionState: PlayerConcussionState?
    private var playerYellowFlareState: PlayerYellowFlareState?
    private var trainingCameraMonitorState: TrainingCameraMonitorState?
    private var trainingKillbotEntryState: TrainingKillbotEntryState?
    private var trainingRASBot1DeathState: TrainingRASBot1DeathState?
    private var trainingRASBot2DeathState: TrainingRASBot2DeathState?
    private var trainingRASBot3DeathState: TrainingRASBot3DeathState?
    private var trainingRASBot4DeathState: TrainingRASBot4DeathState?
    private var trainingLastBot1DeathState: TrainingLastBot1DeathState?
    private var trainingLastBot2DeathState: TrainingLastBot2DeathState?
    private var trainingLastBot3DeathState: TrainingLastBot3DeathState?
    private var trainingLastBot4DeathState: TrainingLastBot4DeathState?
    private var trainingLastBot5DeathState: TrainingLastBot5DeathState?
    private var trainingInvulnerabilityPickupState: TrainingInvulnerabilityPickupState?
    private var trainingCloakPickupState: TrainingCloakPickupState?
    private var trainingLastRoomState: TrainingLastRoomState?
    private var trainingFinalRoomEntryState:
        TrainingFinalRoomEntryState?
    private var trainingFinalBotsCompletionState:
        TrainingFinalBotsCompletionState?
    private var trainingFinalGoalState: TrainingFinalGoalState?
    private var trainingPostLevelResult: TrainingPostLevelResult?

    init(
        level: Level,
        presentationReadyTimestamp: Double,
        authoritativeRandomSeed: UInt32 = 1
    ) {
        precondition(presentationReadyTimestamp.isFinite)
        precondition(level.defaultPlayerBinding != nil)
        self.level = level
        authoritativeRandomState = authoritativeRandomSeed
        let binding = level.defaultPlayerBinding!
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        angularVelocity = ship.physics.initialAngularVelocity
        lastTimestamp = presentationReadyTimestamp
        trainingOpeningState = level.trainingOpeningLesson.map {
            TrainingOpeningState(timerRemaining: $0.welcomeDelay)
        }
        trainingDodgeAttemptState = level.trainingDodgeAttempt.map {
            _ in TrainingDodgeAttemptState()
        }
        trainingManeuverFollowState =
            level.trainingDodgeAttempt?.maneuverFollow.flatMap {
                initialTrainingManeuverFollowState(
                    level: level,
                    lesson: $0
                )
            }
        trainingGalleryBarrierState = level.trainingGalleryBarrier.map {
            TrainingGalleryBarrierState(
                markerLightDistance:
                    trainingGalleryBarrierRendersFaces(
                        in: level,
                        barrier: $0
                    )
                    ? 0
                    : $0.openMarkerLightDistance
            )
        }
        trainingRobotGuidebotState = level.trainingRobotGuidebotChain.map {
            TrainingRobotGuidebotState(
                robotShields: $0.combat.robotShields,
                yellowFlares: $0.yellowFlare == nil ? nil : [],
                yellowFlareParticles:
                    $0.yellowFlare == nil ? nil : [],
                yellowFlareTimeoutExplosions:
                    $0.yellowFlare?.timeout == nil ? nil : [],
                yellowFlareTimeoutSparks:
                    $0.yellowFlare?.timeout == nil ? nil : [],
                yellowFlareTimeoutSparkParticles:
                    $0.yellowFlare?.timeout == nil ? nil : [],
                yellowFlareTimeoutReachedFollowingFrame:
                    $0.yellowFlare?.timeout == nil ? nil : false,
                lastMessageSoundTime: 0
            )
        }
        playerConcussionState = ship.playerConcussion == nil ? nil : .init()
        playerYellowFlareState = level.shipDefinitions.first?
            .playerYellowFlare == nil ? nil : .init()
        trainingCameraMonitorState = level.trainingCameraMonitorChain.map {
            _ in TrainingCameraMonitorState()
        }
        trainingKillbotEntryState =
            level.trainingCameraMonitorChain?.returnToShip?.killbotEntry.map {
                _ in TrainingKillbotEntryState()
            }
        trainingRASBot1DeathState = level.trainingRASBot1DeathChain.map {
            TrainingRASBot1DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot2DeathState = level.trainingRASBot2DeathChain.map {
            TrainingRASBot2DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot3DeathState = level.trainingRASBot3DeathChain.map {
            TrainingRASBot3DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot4DeathState = level.trainingRASBot4DeathChain.map {
            TrainingRASBot4DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot1DeathState = level.trainingLastBot1DeathChain.map {
            TrainingLastBot1DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot2DeathState = level.trainingLastBot2DeathChain.map {
            TrainingLastBot2DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot3DeathState = level.trainingLastBot3DeathChain.map {
            TrainingLastBot3DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot4DeathState = level.trainingLastBot4DeathChain.map {
            TrainingLastBot4DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot5DeathState = level.trainingLastBot5DeathChain.map {
            TrainingLastBot5DeathState(shields: $0.combat.robotShields)
        }
        trainingInvulnerabilityPickupState =
            level.trainingInvulnerabilityPickupChain.map {
                _ in TrainingInvulnerabilityPickupState()
            }
        trainingCloakPickupState = level.trainingCloakPickupChain.map {
            _ in TrainingCloakPickupState()
        }
        trainingLastRoomState = level.trainingLastRoomChain.map {
            _ in TrainingLastRoomState()
        }
        trainingFinalRoomEntryState =
            level.trainingFinalRoomEntryChain.map {
                _ in TrainingFinalRoomEntryState()
            }
        trainingFinalBotsCompletionState =
            level.trainingFinalBotsCompletionChain.map {
                _ in TrainingFinalBotsCompletionState()
            }
        trainingFinalGoalState = level.trainingFinalGoalChain.map {
            _ in TrainingFinalGoalState()
        }
    }

    init(
        level: Level,
        continuation: PlayerSimulationContinuation,
        resumedAtTimestamp: Double
    ) throws {
        let expectedSchema = playerSimulationContinuationSchema(for: level)
        guard continuation.schemaVersion == expectedSchema else {
            throw PlayerSimulationContinuationError.unsupportedSchema
        }
        guard continuation.levelKey == level.levelKey,
              continuation.levelSHA256 == level.source.levelSHA256 else {
            throw PlayerSimulationContinuationError.levelIdentityMismatch
        }
        let hasPersistedAuthoritativeRandomState =
            continuation.authoritativeRandomState != nil
        authoritativeRandomState =
            continuation.authoritativeRandomState ?? 1
        var restoredRobotGuidebotState =
            continuation.trainingRobotGuidebotState
        var restoredPlayerConcussionState = continuation.playerConcussionState
        if level.shipDefinitions.first?.playerConcussion != nil,
           restoredPlayerConcussionState == nil {
            restoredPlayerConcussionState = .init()
        }
        var restoredPlayerYellowFlareState =
            continuation.playerYellowFlareState
        if level.shipDefinitions.first?.playerYellowFlare != nil,
           restoredPlayerYellowFlareState == nil {
            restoredPlayerYellowFlareState = .init()
            if var guidebotState = restoredRobotGuidebotState {
                let hasLegacyYellowFamily =
                    guidebotState.yellowFlares?.isEmpty == false
                    || guidebotState.yellowFlareParticles?.isEmpty == false
                    || guidebotState.yellowFlareTimeoutExplosions?.isEmpty
                        == false
                    || guidebotState.yellowFlareTimeoutSparks?.isEmpty
                        == false
                    || guidebotState.yellowFlareTimeoutSparkParticles?.isEmpty
                        == false
                if hasLegacyYellowFamily {
                    guidebotState.yellowFlares =
                        guidebotState.yellowFlares?.map { flare in
                        var flare = flare
                        flare.creationOrdinal = 0
                        flare.parentObjectHandle = level
                            .trainingRobotGuidebotChain?
                            .guidebotObjectHandle
                        return flare
                    }
                    guidebotState.yellowFlareParticles =
                        guidebotState.yellowFlareParticles?.map { particle in
                            var particle = particle
                            particle.generationOrdinal = 0
                            return particle
                        }
                    guidebotState.yellowFlareTimeoutExplosions =
                        guidebotState.yellowFlareTimeoutExplosions?.map {
                            explosion in
                            var explosion = explosion
                            explosion.generationOrdinal = 0
                            return explosion
                        }
                    guidebotState.yellowFlareTimeoutSparks =
                        guidebotState.yellowFlareTimeoutSparks?.map { spark in
                            var spark = spark
                            spark.generationOrdinal = 0
                            return spark
                        }
                    guidebotState.yellowFlareTimeoutSparkParticles =
                        guidebotState.yellowFlareTimeoutSparkParticles?.map {
                            particle in
                            var particle = particle
                            particle.generationOrdinal = 0
                            return particle
                        }
                    restoredPlayerYellowFlareState?.nextCreationOrdinal = 1
                    restoredRobotGuidebotState = guidebotState
                }
            }
        }
        if var state = restoredRobotGuidebotState {
            let hasReachedTimingState =
                state.guidebotMode != nil
                || state.guidebotModeTime != nil
                || state.nextAmbientTime != nil
                || state.timeUntilNextPlayerVisibilityCheck != nil
                || state.timeUntilNextFlare != nil
                || state.nextPowerupCheckTime != nil
                || state.lastMessageSoundTime != nil
                || state.returnTime != nil
                || state.returnGreetingWasPresented != nil
            if hasReachedTimingState
                && !hasPersistedAuthoritativeRandomState
            {
                throw PlayerSimulationContinuationError.invalidState
            }
            if (state.guidebot != nil || state.guidebotEnteredShip),
               state.guidebotMode == nil {
                guard !hasPersistedAuthoritativeRandomState,
                      !hasReachedTimingState,
                      state.guidebot?.task != .escortPlayer
                else {
                    throw PlayerSimulationContinuationError.invalidState
                }
                state.guidebotMode = .ambient
                state.guidebotModeTime = 0
                state.nextAmbientTime = continuation.gameTime + 1
                state.timeUntilNextPlayerVisibilityCheck = 0.5
                state.timeUntilNextFlare = 3
                state.nextPowerupCheckTime = continuation.gameTime + 2
                state.lastMessageSoundTime = continuation.gameTime
                state.returnTime = continuation.gameTime
                state.returnGreetingWasPresented = false
                restoredRobotGuidebotState = state
            }
        }
        let restoredCloakPickupState =
            continuation.trainingCloakPickupState
            ?? level.trainingCloakPickupChain.map {
                _ in TrainingCloakPickupState()
            }
        let restoredLastRoomState =
            continuation.trainingLastRoomState
            ?? level.trainingLastRoomChain.map {
                _ in TrainingLastRoomState()
            }
        let restoredFinalRoomEntryState =
            continuation.trainingFinalRoomEntryState
            ?? level.trainingFinalRoomEntryChain.map {
                _ in TrainingFinalRoomEntryState()
            }
        let restoredFinalBotsCompletionState =
            continuation.trainingFinalBotsCompletionState
            ?? level.trainingFinalBotsCompletionChain.map {
                _ in TrainingFinalBotsCompletionState()
            }
        let restoredFinalGoalState =
            continuation.trainingFinalGoalState
            ?? level.trainingFinalGoalChain.map {
                _ in TrainingFinalGoalState()
            }
        let restoredDodgeAttemptState =
            continuation.trainingDodgeAttemptState
            ?? level.trainingDodgeAttempt.map {
                _ in TrainingDodgeAttemptState()
            }
        var restoredManeuverFollowState =
            continuation.trainingManeuverFollowState
            ?? level.trainingDodgeAttempt?.maneuverFollow.flatMap {
                initialTrainingManeuverFollowState(
                    level: level,
                    lesson: $0
                )
            }
        if restoredManeuverFollowState?.destruction == nil,
           let lesson =
               level.trainingDodgeAttempt?.maneuverFollow,
           let initial = initialTrainingManeuverFollowState(
               level: level,
               lesson: lesson
           )?.destruction {
            restoredManeuverFollowState?.destruction = initial
        }
        let dodgeAttemptIsActive =
            restoredDodgeAttemptState?.script033Count == 1
            && restoredDodgeAttemptState?.script017Count == 0
        let dodgeAttemptHasSucceeded =
            restoredDodgeAttemptState?.script017Count == 1
        let dodgeExitWasReached =
            restoredDodgeAttemptState?.script019Count == 1
        let restoredLastBot1DeathState =
            continuation.trainingLastBot1DeathState
            ?? level.trainingLastBot1DeathChain.map {
                TrainingLastBot1DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot2DeathState =
            continuation.trainingLastBot2DeathState
            ?? level.trainingLastBot2DeathChain.map {
                TrainingLastBot2DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot3DeathState =
            continuation.trainingLastBot3DeathState
            ?? level.trainingLastBot3DeathChain.map {
                TrainingLastBot3DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot4DeathState =
            continuation.trainingLastBot4DeathState
            ?? level.trainingLastBot4DeathChain.map {
                TrainingLastBot4DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot5DeathState =
            continuation.trainingLastBot5DeathState
            ?? level.trainingLastBot5DeathChain.map {
                TrainingLastBot5DeathState(
                    shields: $0.combat.robotShields
                )
            }
        var routeAllocationLevel = level
        if continuation.trainingGalleryBarrierState?.wasTriggered == true {
            closeTrainingGalleryBarrier(in: &routeAllocationLevel)
        }
        var continuationLevel = routeAllocationLevel
        if continuation.trainingOpeningState?
            .continueToCourseWasPresented == true
        {
            guard let continueToCourse =
                    continuationLevel.trainingOpeningLesson?
                        .continueToCourse,
                  trainingContinueToCoursePortalsHaveRenderState(
                      in: continuationLevel,
                      lesson: continueToCourse,
                      rendersFaces: true
                  )
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            openTrainingContinueToCoursePortals(in: &continuationLevel)
        }
        if continuation.trainingOpeningState?
            .finishCourseWasPresented == true
        {
            guard let finishCourse =
                    continuationLevel.trainingOpeningLesson?.finishCourse,
                  trainingFinishCoursePortalsHaveRenderState(
                      in: continuationLevel,
                      lesson: finishCourse,
                      rendersFaces: true
                  )
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            openTrainingFinishCoursePortals(in: &continuationLevel)
        }
        if let cameraState = continuation.trainingCameraMonitorState,
           let chain = continuationLevel.trainingCameraMonitorChain {
            if cameraState.isHeld || cameraState.wasUsed {
                completeTrainingCameraMonitorLocateGoal(
                    in: &continuationLevel,
                    pickupObjectHandle: chain.pickupObjectHandle
                )
            }
            if cameraState.script058WasPresented {
                openTrainingGuidebotReturnBarrier(in: &continuationLevel)
            }
            if cameraState.wasUsed {
                continuationLevel.objects.removeAll {
                    $0.handle == chain.pickupObjectHandle
                }
            }
            if cameraState.isHeld || cameraState.wasUsed {
                setObjectPresentationVisibility(
                    in: &continuationLevel,
                    handle: chain.pickupObjectHandle,
                    isVisible: false
                )
            }
        }
        if continuation.trainingKillbotEntryState?.wasTriggered == true {
            closeTrainingKillbotEntryBarrier(in: &continuationLevel)
        }
        if continuation.trainingRASBot1DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot1DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot2DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot2DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot3DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot3DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot4DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot4DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot1DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot1DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot2DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot2DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot3DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot3DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot4DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot4DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot5DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot5DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingInvulnerabilityPickupState?
            .wasConsumed == true
        {
            guard
                let chain =
                    continuationLevel.trainingInvulnerabilityPickupChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &continuationLevel,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if restoredCloakPickupState?.wasConsumed == true {
            guard let chain = continuationLevel.trainingCloakPickupChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &continuationLevel,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if restoredLastRoomState?.wasTriggered == true {
            openTrainingLastRoomBarrier(in: &continuationLevel)
        }
        if restoredFinalRoomEntryState?.wasTriggered == true {
            closeTrainingLastRoomBarrier(in: &continuationLevel)
        }
        if restoredFinalBotsCompletionState?.wasTriggered == true {
            openTrainingFinalBotsBarrier(in: &continuationLevel)
        }
        guard
            validTrainingCameraMonitorContinuation(
                continuation.trainingCameraMonitorState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingKillbotEntryContinuation(
                continuation.trainingKillbotEntryState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot1DeathContinuation(
                continuation.trainingRASBot1DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot2DeathContinuation(
                continuation.trainingRASBot2DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot3DeathContinuation(
                continuation.trainingRASBot3DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot4DeathContinuation(
                continuation.trainingRASBot4DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot1DeathContinuation(
                restoredLastBot1DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot2DeathContinuation(
                restoredLastBot2DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot3DeathContinuation(
                restoredLastBot3DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot4DeathContinuation(
                restoredLastBot4DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot5DeathContinuation(
                restoredLastBot5DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingInvulnerabilityPickupContinuation(
                continuation.trainingInvulnerabilityPickupState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingCloakPickupContinuation(
                restoredCloakPickupState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastRoomContinuation(
                restoredLastRoomState,
                finalRoomEntryWasTriggered:
                    restoredFinalRoomEntryState?.wasTriggered == true,
                allProducersWereTriggered:
                    continuation.trainingRASBot1DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot2DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot3DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot4DeathState?
                        .wasDestroyed == true
                    && continuation.trainingInvulnerabilityPickupState?
                        .scriptWasTriggered == true
                    && restoredCloakPickupState?
                        .scriptWasTriggered == true,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalRoomEntryContinuation(
            restoredFinalRoomEntryState,
            lastRoomState: restoredLastRoomState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalBotsCompletionContinuation(
            restoredFinalBotsCompletionState,
            allProducersWereDestroyed:
                restoredLastBot1DeathState?.wasDestroyed == true
                && restoredLastBot2DeathState?.wasDestroyed == true
                && restoredLastBot3DeathState?.wasDestroyed == true
                && restoredLastBot4DeathState?.wasDestroyed == true
                && restoredLastBot5DeathState?.wasDestroyed == true,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalGoalContinuation(
            restoredFinalGoalState,
            finalBotsState: restoredFinalBotsCompletionState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        var restoredGuidebotRouteLevel =
            continuation.trainingCameraMonitorState?
                .script058WasPresented == true
                && restoredRobotGuidebotState?.guidebot?.task == .outbound
            ? continuationLevel
            : routeAllocationLevel
        if let binding = restoredGuidebotRouteLevel.defaultPlayerBinding,
           let playerIndex = restoredGuidebotRouteLevel.objects.firstIndex(
               where: { $0.handle == binding.objectHandle }
           ) {
            restoredGuidebotRouteLevel.objects[playerIndex].location =
                continuation.playerLocation
            restoredGuidebotRouteLevel.objects[playerIndex].position =
                continuation.playerPosition
            restoredGuidebotRouteLevel.objects[playerIndex].orientation =
                continuation.playerOrientation
        }
        if let guidebot = restoredRobotGuidebotState?.guidebot,
           let handle = restoredGuidebotRouteLevel
            .trainingRobotGuidebotChain?.guidebotObjectHandle,
           let guidebotIndex = restoredGuidebotRouteLevel.objects.firstIndex(
               where: { $0.handle == handle }
           ) {
            restoredGuidebotRouteLevel.objects[guidebotIndex].location =
                .room(guidebot.roomSourceIndex)
            restoredGuidebotRouteLevel.objects[guidebotIndex].position =
                guidebot.position
            restoredGuidebotRouteLevel.objects[guidebotIndex].orientation =
                guidebot.orientation
        }
        let guidebotContinuationIsValid =
            validTrainingRobotGuidebotContinuation(
                restoredRobotGuidebotState,
                galleryState: continuation.trainingGalleryBarrierState,
                cameraState: continuation.trainingCameraMonitorState,
                playerLocation: continuation.playerLocation,
                playerPosition: continuation.playerPosition,
                gameTime: continuation.gameTime,
                level: restoredGuidebotRouteLevel
            )
        let playerYellowContinuationIsValid =
            validPlayerYellowFlareContinuation(
                restoredPlayerYellowFlareState,
                guidebotState: restoredRobotGuidebotState,
                gameTime: continuation.gameTime,
                level: restoredGuidebotRouteLevel
            )
        let playerConcussionContinuationIsValid =
            validPlayerConcussionContinuation(
                restoredPlayerConcussionState,
                gameTime: continuation.gameTime,
                level: restoredGuidebotRouteLevel
            )
        guard
            validTrainingGalleryBarrierContinuation(
                continuation.trainingGalleryBarrierState,
            robotGuidebotState:
                restoredRobotGuidebotState,
            level: continuationLevel
        ),
        guidebotContinuationIsValid,
        playerConcussionContinuationIsValid,
        playerYellowContinuationIsValid else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard case .room(let restoredRoomSourceIndex)
                = continuation.playerLocation,
              level.rooms.contains(where: {
                  $0.sourceIndex == restoredRoomSourceIndex
              }),
              containingIndoorRoomSourceIndex(
                  in: level,
                  position: continuation.playerPosition,
                  candidates: [restoredRoomSourceIndex]
              ) == restoredRoomSourceIndex else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard resumedAtTimestamp.isFinite,
              continuation.frameDuration.isFinite,
              continuation.frameDuration >= 0,
              continuation.gameTime.isFinite,
              continuation.gameTime >= 0,
              continuation.playerRearViewState.map({ state in
                  continuation.schemaVersion == 7
                      && state.entryGameTime.isFinite
                      && state.entryGameTime >= 0
                      && state.entryGameTime <= continuation.gameTime
              }) ?? true,
              isCanonicalRigidTransform(
                  position: continuation.playerPosition,
                  orientation: continuation.playerOrientation
              ),
              continuation.velocity.x.isFinite,
              continuation.velocity.y.isFinite,
              continuation.velocity.z.isFinite,
              continuation.angularVelocity.x.isFinite,
              continuation.angularVelocity.y.isFinite,
              continuation.angularVelocity.z.isFinite,
              continuation.turnrollFixedAngle.isFinite,
              continuation.afterburnerFuel.isFinite,
              (0...5).contains(continuation.afterburnerFuel),
              continuation.energy.isFinite,
              continuation.energy >= 0,
              continuation.afterburnerMagnitude.isFinite,
              (0...1).contains(continuation.afterburnerMagnitude),
              continuation.wiggleFalloff.isFinite,
              (0...1).contains(continuation.wiggleFalloff),
              continuation.lastThrustTime.isFinite,
              continuation.trainingOpeningState.map({ state in
                  var expectedControls: [PlayerControlMask]
                  if state.upGoalWasReached == true {
                      if state.returnGoalWasReached == true {
                          guard state.forwardGoalWasReached else {
                              return false
                          }
                          expectedControls = [
                              [.up],
                              [.left, .up],
                          ]
                      } else if state.forwardGoalWasReached {
                          expectedControls = [[.reverse, .up]]
                      } else {
                          expectedControls = [[.forward, .up]]
                      }
                  } else if state.rightGoalWasReached == true {
                      if state.returnGoalWasReached == true {
                          guard state.forwardGoalWasReached else {
                              return false
                          }
                          expectedControls = [
                              [.right],
                              [.left, .right],
                          ]
                      } else if state.forwardGoalWasReached {
                          expectedControls = [[.reverse, .right]]
                      } else {
                          expectedControls = [[.forward, .right]]
                      }
                  } else if state.returnGoalWasReached == true {
                      guard state.forwardGoalWasReached else {
                          return false
                      }
                      expectedControls = [[.left]]
                  } else if state.forwardGoalWasReached {
                      expectedControls = [[.reverse]]
                  } else {
                      expectedControls = [[.forward]]
                  }
                  if state.downGoalWasReached == true {
                      let controlsBeforeReturnDown = expectedControls
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.up)
                          controls.insert(.down)
                          return controls
                      }
                      if state.upGoalWasReached == true {
                          expectedControls += controlsBeforeReturnDown.map {
                              controls in
                              var controls = controls
                              controls.insert(.down)
                              return controls
                          }
                      }
                  }
                  if state.repeatForwardWasPresented == true {
                      guard state.downGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.down)
                          controls.insert(.forward)
                          return controls
                      }
                  }
                  if state.repeatForwardGoalWasPresented == true {
                      guard state.repeatForwardWasPresented == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.forward)
                          controls.insert(.reverse)
                          return controls
                      }
                  }
                  if state.repeatReturnLeftWasPresented == true {
                      guard state.repeatForwardGoalWasPresented == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.reverse)
                          controls.insert(.left)
                          return controls
                      }
                  }
                  if state.repeatReturnRightWasPresented == true {
                      guard state.repeatReturnLeftWasPresented == true,
                            state.rightGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.left)
                          controls.insert(.right)
                          return controls
                      }
                  }
                  if state.repeatReturnUpWasPresented == true {
                      guard state.repeatReturnRightWasPresented == true,
                            state.rightGoalWasReached == true,
                            state.upGoalWasReached == true,
                            state.downGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.right)
                          controls.insert(.up)
                          return controls
                      }
                  }
                  if state.repeatReturnDownWasPresented == true {
                      guard state.repeatReturnUpWasPresented == true,
                            state.downGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.up)
                          controls.insert(.down)
                          return controls
                      }
                  }
                  if state.continueToCourseWasPresented == true {
                      guard state.repeatReturnDownWasPresented == true else {
                          return false
                      }
                  }
                  let dodgeExitControlMaskIsReachable: Bool = {
                      guard dodgeExitWasReached else {
                          return false
                      }
                      let lowBits =
                          state.enabledControls.rawValue & 63
                      if lowBits == 0 || lowBits == 1 {
                          return true
                      }
                      if dodgeAttemptIsActive && lowBits == 60 {
                          return true
                      }
                      return dodgeAttemptHasSucceeded
                          && (lowBits == 3 || lowBits == 63)
                  }()
                  let maneuverControlMaskIsReachable: Bool = {
                      guard let followState =
                              restoredManeuverFollowState,
                            followState.script021Count > 0,
                            let lesson =
                              level.trainingDodgeAttempt?
                                .maneuverFollow
                      else {
                          return false
                      }
                      let expected: UInt32
                      if followState.script026Count > 0 {
                          expected =
                              lesson.rotationalControlMask
                              | lesson.weaponControlMask
                      } else if followState.script023Count > 0 {
                          expected = lesson.rotationalControlMask
                      } else if followState.script024Count > 0 {
                          expected = lesson.bankControlMask
                      } else if followState.script022Count > 0 {
                          expected = lesson.pitchControlMask
                      } else {
                          expected = lesson.headingControlMask
                      }
                      return state.enabledControls.rawValue == expected
                  }()
                  if state.startCourseWasPresented == true {
                      guard let startCourse =
                              level.trainingOpeningLesson?.startCourse
                      else {
                          return false
                      }
                      if state.finishCourseWasPresented == true {
                          guard state.enabledControls.rawValue
                                  == startCourse.enabledControlMask
                              || state.enabledControls.rawValue == 32
                                  || (
                                  dodgeAttemptHasSucceeded
                                    && state.enabledControls.rawValue == 63
                              )
                              || dodgeExitControlMaskIsReachable
                              || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      } else {
                          guard state.enabledControls.rawValue
                                  & startCourse.enabledControlMask
                                    == startCourse.enabledControlMask
                                  || (
                                      dodgeAttemptIsActive
                                        && state.enabledControls.rawValue == 60
                                  )
                                  || dodgeExitControlMaskIsReachable
                                  || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      }
                  }
                  if state.finishCourseWasPresented == true {
                      guard let finishCourse =
                              level.trainingOpeningLesson?.finishCourse
                      else {
                          return false
                      }
                      if state.startCourseWasPresented == true {
                          guard state.enabledControls.rawValue
                                  == finishCourse.enabledControlMask
                              || state.enabledControls.rawValue == 63
                                  || (
                                  dodgeAttemptHasSucceeded
                                    && state.enabledControls.rawValue == 63
                              )
                              || dodgeExitControlMaskIsReachable
                              || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      } else {
                          guard state.enabledControls.rawValue
                                  == finishCourse.enabledControlMask
                                  || (
                                  dodgeAttemptHasSucceeded
                                    && state.enabledControls.rawValue == 63
                              )
                              || dodgeExitControlMaskIsReachable
                              || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      }
                  }
                  return state.timerRemaining.isFinite
                      && (
                          state.welcomeWasPresented
                            || state.timerRemaining > 0
                      )
                      && (state.returnGoalWasReached != true
                          || level.trainingOpeningLesson?.returnLeft != nil)
                      && (state.rightGoalWasReached != true
                          || level.trainingOpeningLesson?.returnRight != nil)
                      && (state.upGoalWasReached != true
                          || (
                              state.rightGoalWasReached == true
                                && level.trainingOpeningLesson?.returnUp != nil
                          ))
                      && (state.downGoalWasReached != true
                          || level.trainingOpeningLesson?.returnDown != nil)
                      && (state.repeatForwardWasPresented != true
                          || level.trainingOpeningLesson?.repeatForward != nil)
                      && (state.repeatForwardGoalWasPresented != true
                          || level.trainingOpeningLesson?.repeatForwardGoal
                            != nil)
                      && (state.repeatReturnLeftWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnLeft
                            != nil)
                      && (state.repeatReturnRightWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnRight
                            != nil)
                      && (state.repeatReturnUpWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnUp
                            != nil)
                      && (state.repeatReturnDownWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnDown
                            != nil)
                      && (state.continueToCourseWasPresented != true
                          || level.trainingOpeningLesson?.continueToCourse
                            != nil)
                      && (state.startCourseWasPresented != true
                          || level.trainingOpeningLesson?.startCourse != nil)
                      && (state.finishCourseWasPresented != true
                          || level.trainingOpeningLesson?.finishCourse != nil)
                      && (
                          state.startCourseWasPresented == true
                            || state.finishCourseWasPresented == true
                            || (dodgeAttemptIsActive
                                && state.enabledControls.rawValue == 60)
                            || (dodgeAttemptHasSucceeded
                                && state.enabledControls.rawValue == 63)
                            || dodgeExitControlMaskIsReachable
                            || maneuverControlMaskIsReachable
                            || expectedControls.contains(
                                state.enabledControls
                            )
                        )
              }) ?? true,
              (level.trainingOpeningLesson == nil)
                == (continuation.trainingOpeningState == nil) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        if continuation.trainingOpeningState?
            .startCourseWasPresented == true
        {
            guard continuationLevel.trainingOpeningLesson?.startCourse
                    != nil else {
                throw PlayerSimulationContinuationError.invalidState
            }
            closeTrainingStartCoursePortal(in: &continuationLevel)
        }
        if let continueToCourse =
                continuationLevel.trainingOpeningLesson?.continueToCourse,
           continuation.trainingOpeningState?
            .continueToCourseWasPresented == true {
            let startCourseWasPresented =
                continuation.trainingOpeningState?
                    .startCourseWasPresented == true
            let startCoursePortalIndex =
                continuationLevel.trainingOpeningLesson?
                    .startCourse?.portalIndex
            guard continueToCourse.orderedPortalIndices.allSatisfy({
                portalIndex in
                trainingPortalPairHasRenderState(
                    in: continuationLevel,
                    roomSourceIndex:
                        continueToCourse.portalRoomSourceIndex,
                    portalIndex: portalIndex,
                    rendersFaces:
                        startCourseWasPresented
                            && portalIndex == startCoursePortalIndex
                )
            }) else {
                throw PlayerSimulationContinuationError.invalidState
            }
        }
        if let startCourse =
                continuationLevel.trainingOpeningLesson?.startCourse,
           continuation.trainingOpeningState?
            .startCourseWasPresented == true {
            guard trainingStartCoursePortalHasRenderState(
                in: continuationLevel,
                lesson: startCourse,
                rendersFaces: true
            ) else {
                throw PlayerSimulationContinuationError.invalidState
            }
        }
        if let finishCourse =
                continuationLevel.trainingOpeningLesson?.finishCourse,
           continuation.trainingOpeningState?
            .finishCourseWasPresented == true {
            guard trainingFinishCoursePortalsHaveRenderState(
                in: continuationLevel,
                lesson: finishCourse,
                rendersFaces: false
            ) else {
                throw PlayerSimulationContinuationError.invalidState
            }
        }
        var restoredOpeningState = continuation.trainingOpeningState
        if restoredOpeningState?.startCourseWasPresented == true,
           !dodgeAttemptIsActive,
           !dodgeExitWasReached,
           restoredManeuverFollowState?.script021Count ?? 0 == 0,
           !(restoredOpeningState?.finishCourseWasPresented == true
                && restoredOpeningState?.enabledControls.rawValue == 32),
           let startCourse =
                continuationLevel.trainingOpeningLesson?.startCourse {
            restoredOpeningState?.enabledControls.formUnion(
                PlayerControlMask(
                    rawValue: startCourse.enabledControlMask
                )
            )
        }
        guard
            validTrainingDodgeAttemptContinuation(
                restoredDodgeAttemptState,
                maneuverState: restoredManeuverFollowState,
                shields: continuation.shields ?? 100,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingManeuverFollowContinuation(
            restoredManeuverFollowState,
            robotGuidebotState:
                restoredRobotGuidebotState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        if (
            restoredManeuverFollowState?.destruction?
                .script027Count ?? 0
        ) > 0,
           restoredManeuverFollowState?.destruction?
            .destroyBot1Destruction == nil,
           let handoff =
                continuationLevel.trainingDodgeAttempt?
                    .maneuverFollow?.destructionHandoff
        {
            restoredManeuverFollowState?.destruction?
                .destroyBot1Destruction =
                    initialTrainingDestroyBot1DestructionState(
                        level: continuationLevel,
                        handoff: handoff
                    )
        }
        var restoredLevel = continuationLevel
        if restoredDodgeAttemptState?.script033Count == 1 {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex:
                    restoredLevel.trainingDodgeAttempt!
                    .portalRoomTwoSourceIndex,
                portalIndices:
                    restoredLevel.trainingDodgeAttempt!
                    .orderedPortalIndices,
                rendersFaces: true
            )
        }
        if restoredDodgeAttemptState?.script017Count == 1 {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex:
                    restoredLevel.trainingDodgeAttempt!
                    .portalRoomThreeSourceIndex,
                portalIndices:
                    restoredLevel.trainingDodgeAttempt!
                    .orderedPortalIndices,
                rendersFaces: false
            )
        }
        if restoredDodgeAttemptState?.script019Count == 1,
            let exit = restoredLevel.trainingDodgeAttempt?.dodgeExit
        {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex: exit.portalRoomSourceIndex,
                portalIndices: exit.orderedPortalIndices,
                rendersFaces: false
            )
        }
        if restoredManeuverFollowState?.script021Count ?? 0 > 0,
           let lesson =
                restoredLevel.trainingDodgeAttempt?.maneuverFollow
        {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex: lesson.portalRoomSourceIndex,
                portalIndices: lesson.orderedPortalIndices,
                rendersFaces: true
            )
        }
        if let state = restoredManeuverFollowState,
           let lesson =
                restoredLevel.trainingDodgeAttempt?.maneuverFollow {
            if state.destruction?.followBotWasDestroyed == true {
                restoredLevel.objects.removeAll {
                    $0.handle == lesson.followBotObjectHandle
                }
                setObjectPresentationVisibility(
                    in: &restoredLevel,
                    handle: lesson.followBotObjectHandle,
                    isVisible: false
                )
            } else if let objectIndex =
                        restoredLevel.objects.firstIndex(where: {
                            $0.handle
                                == lesson.followBotObjectHandle
                        }) {
                restoredLevel.objects[objectIndex].location =
                    .room(state.roomSourceIndex)
                restoredLevel.objects[objectIndex].position =
                    state.position
                restoredLevel.objects[objectIndex].orientation =
                    state.orientation
            }
            if let handoff = lesson.destructionHandoff,
               let destruction = state.destruction {
                setObjectPresentationVisibility(
                    in: &restoredLevel,
                    handle: handoff.destroyBot2ObjectHandle,
                    isVisible: destruction.destroyBot2IsVisible
                )
                setObjectPresentationVisibility(
                    in: &restoredLevel,
                    handle: handoff.destroyBot1ObjectHandle,
                    isVisible: destruction.destroyBot1IsVisible
                )
                if destruction.destroyBot1Destruction?
                    .destroyBot1WasDestroyed == true
                {
                    restoredLevel.objects.removeAll {
                        $0.handle == handoff.destroyBot1ObjectHandle
                    }
                } else if let objectIndex =
                    restoredLevel.objects.firstIndex(where: {
                        $0.handle
                            == handoff.destroyBot1ObjectHandle
                    }) {
                    restoredLevel.objects[objectIndex].location =
                        .room(
                            destruction.destroyBot1Motion
                                .roomSourceIndex
                        )
                    restoredLevel.objects[objectIndex].position =
                        destruction.destroyBot1Motion.position
                    restoredLevel.objects[objectIndex].orientation =
                        destruction.destroyBot1Motion.orientation
                }
                if let destroyBot2Motion =
                    destruction.destroyBot1Destruction?
                        .destroyBot2Motion,
                   let objectIndex =
                    restoredLevel.objects.firstIndex(where: {
                        $0.handle
                            == handoff.destroyBot2ObjectHandle
                    })
                {
                    restoredLevel.objects[objectIndex].location =
                        .room(destroyBot2Motion.roomSourceIndex)
                    restoredLevel.objects[objectIndex].position =
                        destroyBot2Motion.position
                    restoredLevel.objects[objectIndex].orientation =
                        destroyBot2Motion.orientation
                }
            }
        }
        if continuation.trainingRobotGuidebotState?
            .robotWasDestroyed == true
        {
            let chain = restoredLevel.trainingRobotGuidebotChain!
            restoredLevel.objects.removeAll {
                $0.handle == chain.destroyRobotObjectHandle
            }
            setObjectPresentationVisibility(
                in: &restoredLevel,
                handle: chain.destroyRobotObjectHandle,
                isVisible: false
            )
            if continuation.trainingGalleryBarrierState?
                .wasTriggered == true,
               continuation.trainingGalleryBarrierState?
                .markerLightDistance == 0
            {
                closeTrainingGalleryBarrier(in: &restoredLevel)
            } else {
                openTrainingGalleryBarrier(in: &restoredLevel)
            }
        }
        let binding = restoredLevel.defaultPlayerBinding!
        let objectIndex = restoredLevel.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        restoredLevel.objects[objectIndex].location = continuation.playerLocation
        restoredLevel.objects[objectIndex].position = continuation.playerPosition
        restoredLevel.objects[objectIndex].orientation = continuation.playerOrientation
        self.level = restoredLevel
        frameDuration = continuation.frameDuration
        gameTime = continuation.gameTime
        velocity = continuation.velocity
        angularVelocity = continuation.angularVelocity
        turnrollFixedAngle = continuation.turnrollFixedAngle
        indoorAutoLevelMode = continuation.indoorAutoLevelMode
        afterburnerFuel = continuation.afterburnerFuel
        afterburnerIsActive = continuation.afterburnerIsActive
        energy = continuation.energy
        shields = continuation.shields ?? 100
        playerHeadlightIsOn = continuation.playerHeadlightIsOn ?? false
        playerRearViewState = continuation.playerRearViewState
        afterburnerMagnitude = continuation.afterburnerMagnitude
        wiggleFalloff = continuation.wiggleFalloff
        lastThrustTime = continuation.lastThrustTime
        lastTimestamp = resumedAtTimestamp
        trainingOpeningState = restoredOpeningState
        trainingDodgeAttemptState = restoredDodgeAttemptState
        trainingManeuverFollowState = restoredManeuverFollowState
        trainingGalleryBarrierState =
            continuation.trainingGalleryBarrierState
        trainingRobotGuidebotState =
            restoredRobotGuidebotState
        playerConcussionState = restoredPlayerConcussionState
        playerYellowFlareState = restoredPlayerYellowFlareState
        trainingCameraMonitorState =
            continuation.trainingCameraMonitorState
        trainingKillbotEntryState =
            continuation.trainingKillbotEntryState
        trainingRASBot1DeathState =
            continuation.trainingRASBot1DeathState
        trainingRASBot2DeathState =
            continuation.trainingRASBot2DeathState
        trainingRASBot3DeathState =
            continuation.trainingRASBot3DeathState
        trainingRASBot4DeathState =
            continuation.trainingRASBot4DeathState
        trainingLastBot1DeathState = restoredLastBot1DeathState
        trainingLastBot2DeathState = restoredLastBot2DeathState
        trainingLastBot3DeathState = restoredLastBot3DeathState
        trainingLastBot4DeathState = restoredLastBot4DeathState
        trainingLastBot5DeathState = restoredLastBot5DeathState
        trainingInvulnerabilityPickupState =
            continuation.trainingInvulnerabilityPickupState
        trainingCloakPickupState = restoredCloakPickupState
        trainingLastRoomState = restoredLastRoomState
        trainingFinalRoomEntryState = restoredFinalRoomEntryState
        trainingFinalBotsCompletionState =
            restoredFinalBotsCompletionState
        trainingFinalGoalState = restoredFinalGoalState
        if restoredFinalGoalState?.endLevelWasRequested == true {
            trainingPostLevelResult = makeTrainingPostLevelResult(
                elapsedTime: gameTime
            )
            trainingSessionOutcome = .awaitingResultAcknowledgement
        }
        restoreTrainingGuidebotPresentation()
        if trainingRobotGuidebotState?.guidebotEnteredShip == true,
           let handle =
            level.trainingRobotGuidebotChain?.guidebotObjectHandle {
            setObjectPresentationVisibility(
                in: &self.level,
                handle: handle,
                isVisible: false
            )
        }
    }

    var continuation: PlayerSimulationContinuation {
        let binding = level.defaultPlayerBinding!
        let player = level.objects.first { $0.handle == binding.objectHandle }!
        let schemaVersion = playerSimulationContinuationSchema(for: level)
        return PlayerSimulationContinuation(
            schemaVersion: schemaVersion,
            levelKey: level.levelKey,
            levelSHA256: level.source.levelSHA256,
            playerLocation: player.location,
            playerPosition: player.position,
            playerOrientation: player.orientation,
            frameDuration: frameDuration,
            gameTime: gameTime,
            velocity: velocity,
            angularVelocity: angularVelocity,
            turnrollFixedAngle: turnrollFixedAngle,
            indoorAutoLevelMode: indoorAutoLevelMode,
            afterburnerFuel: afterburnerFuel,
            afterburnerIsActive: afterburnerIsActive,
            energy: energy,
            afterburnerMagnitude: afterburnerMagnitude,
            wiggleFalloff: wiggleFalloff,
            lastThrustTime: lastThrustTime,
            authoritativeRandomState: authoritativeRandomState,
            shields: shields,
            playerHeadlightIsOn: playerHeadlightIsOn,
            playerRearViewState:
                schemaVersion == 7 ? playerRearViewState : nil,
            trainingOpeningState: trainingOpeningState,
            trainingDodgeAttemptState: trainingDodgeAttemptState,
            trainingManeuverFollowState:
                trainingManeuverFollowState,
            trainingGalleryBarrierState:
                trainingGalleryBarrierState,
            trainingRobotGuidebotState:
                trainingRobotGuidebotState,
            playerConcussionState: playerConcussionState,
            playerYellowFlareState: playerYellowFlareState,
            trainingCameraMonitorState:
                trainingCameraMonitorState,
            trainingKillbotEntryState:
                trainingKillbotEntryState,
            trainingRASBot1DeathState:
                trainingRASBot1DeathState,
            trainingRASBot2DeathState:
                trainingRASBot2DeathState,
            trainingRASBot3DeathState:
                trainingRASBot3DeathState,
            trainingRASBot4DeathState:
                trainingRASBot4DeathState,
            trainingLastBot1DeathState:
                trainingLastBot1DeathState,
            trainingLastBot2DeathState:
                trainingLastBot2DeathState,
            trainingLastBot3DeathState:
                trainingLastBot3DeathState,
            trainingLastBot4DeathState:
                trainingLastBot4DeathState,
            trainingLastBot5DeathState:
                trainingLastBot5DeathState,
            trainingInvulnerabilityPickupState:
                trainingInvulnerabilityPickupState,
            trainingCloakPickupState: trainingCloakPickupState,
            trainingLastRoomState: trainingLastRoomState,
            trainingFinalRoomEntryState:
                trainingFinalRoomEntryState,
            trainingFinalBotsCompletionState:
                trainingFinalBotsCompletionState,
            trainingFinalGoalState: trainingFinalGoalState
        )
    }

    private func assignTrainingFollowBotPath(
        _ pathIndex: Int,
        state: inout TrainingManeuverFollowState
    ) {
        var motion = TrainingAuthoredPathMotion(
            roomSourceIndex: state.roomSourceIndex,
            position: state.position,
            orientation: state.orientation,
            velocity: state.velocity,
            activePathIndex: state.activePathIndex,
            pathNodeIndex: state.pathNodeIndex,
            pathFailure: state.pathFailure
        )
        assignTrainingAuthoredPath(pathIndex, motion: &motion)
        state.activePathIndex = motion.activePathIndex
        state.pathNodeIndex = motion.pathNodeIndex
        state.velocity = motion.velocity
        state.pathFailure = motion.pathFailure
    }

    private func assignTrainingAuthoredPath(
        _ pathIndex: Int,
        motion: inout TrainingAuthoredPathMotion
    ) {
        guard level.paths.indices.contains(pathIndex),
              !level.paths[pathIndex].nodes.isEmpty
        else {
            motion.activePathIndex = nil
            motion.pathNodeIndex = 0
            motion.velocity = .zero
            motion.pathFailure = .invalidPath
            return
        }
        motion.activePathIndex = pathIndex
        motion.pathNodeIndex = 0
        motion.pathFailure = nil
    }

    private func advanceTrainingFollowBot(duration: Float) {
        guard duration > 0,
              var state = trainingManeuverFollowState,
              state.followBotIsPowered,
              let lesson =
                level.trainingDodgeAttempt?.maneuverFollow
        else {
            return
        }
        var motion = TrainingAuthoredPathMotion(
            roomSourceIndex: state.roomSourceIndex,
            position: state.position,
            orientation: state.orientation,
            velocity: state.velocity,
            activePathIndex: state.activePathIndex,
            pathNodeIndex: state.pathNodeIndex,
            pathFailure: state.pathFailure
        )
        advanceTrainingAuthoredPath(
            &motion,
            duration: duration,
            definition: lesson.followBot,
            loopingPathIndex: lesson.followPathIndex,
            orientsToPathNodes:
                state.activePathIndex == lesson.followPathIndex
        )
        state.roomSourceIndex = motion.roomSourceIndex
        state.position = motion.position
        state.orientation = motion.orientation
        state.velocity = motion.velocity
        state.activePathIndex = motion.activePathIndex
        state.pathNodeIndex = motion.pathNodeIndex
        state.pathFailure = motion.pathFailure
        trainingManeuverFollowState = state
        restoreTrainingFollowBotPresentation()
    }

    private func advanceTrainingMovingTarget(duration: Float) {
        guard duration > 0,
              var state = trainingManeuverFollowState,
              var destruction = state.destruction,
              let lesson =
                level.trainingDodgeAttempt?.maneuverFollow,
              let handoff = lesson.destructionHandoff
        else {
            return
        }
        let activeHandle: UInt32
        if var destroyBot1Destruction =
            destruction.destroyBot1Destruction,
           destroyBot1Destruction.script028Count > 0,
           destruction.destroyBot2IsVisible
        {
            advanceTrainingAuthoredPath(
                &destroyBot1Destruction.destroyBot2Motion,
                duration: duration,
                definition: lesson.followBot,
                loopingPathIndex: handoff.movingPathIndex,
                orientsToPathNodes: false
            )
            destruction.destroyBot1Destruction =
                destroyBot1Destruction
            activeHandle = handoff.destroyBot2ObjectHandle
        } else if destruction.destroyBot1IsVisible {
            advanceTrainingAuthoredPath(
                &destruction.destroyBot1Motion,
                duration: duration,
                definition: lesson.followBot,
                loopingPathIndex: handoff.movingPathIndex,
                orientsToPathNodes: false
            )
            activeHandle = handoff.destroyBot1ObjectHandle
        } else {
            return
        }
        state.destruction = destruction
        trainingManeuverFollowState = state
        if let objectIndex = level.objects.firstIndex(where: {
            $0.handle == activeHandle
        }) {
            let motion = activeHandle == handoff.destroyBot1ObjectHandle
                ? destruction.destroyBot1Motion
                : destruction.destroyBot1Destruction!
                    .destroyBot2Motion
            level.objects[objectIndex].location =
                .room(motion.roomSourceIndex)
            level.objects[objectIndex].position = motion.position
            level.objects[objectIndex].orientation = motion.orientation
        }
    }

    private func advanceTrainingAuthoredPath(
        _ motion: inout TrainingAuthoredPathMotion,
        duration: Float,
        definition: TrainingFollowBotDefinition,
        loopingPathIndex: Int,
        orientsToPathNodes: Bool
    ) {
        guard let pathIndex = motion.activePathIndex,
              level.paths.indices.contains(pathIndex)
        else {
            return
        }
        let path = level.paths[pathIndex]
        guard path.nodes.indices.contains(motion.pathNodeIndex) else {
            motion.activePathIndex = nil
            motion.pathNodeIndex = 0
            motion.velocity = .zero
            motion.pathFailure = .invalidPath
            return
        }
        func passedNode(_ nodeIndex: Int, at position: Vector3) -> Bool {
            let node = path.nodes[nodeIndex]
            let direction: Vector3
            if nodeIndex > 0 {
                direction =
                    node.position - path.nodes[nodeIndex - 1].position
            } else if path.nodes.count > 1 {
                direction = path.nodes[1].position - node.position
            } else {
                direction = node.forward
            }
            return dot(position - node.position, direction) >= 0
        }
        let movementNode = path.nodes[motion.pathNodeIndex]
        var completesAfterMovement = false
        if path.nodes.count > 1 {
            while passedNode(
                motion.pathNodeIndex,
                at: motion.position
            ) {
                if motion.pathNodeIndex + 1 < path.nodes.count {
                    motion.pathNodeIndex += 1
                } else if pathIndex == loopingPathIndex {
                    motion.pathNodeIndex = 0
                    break
                } else {
                    completesAfterMovement = true
                    break
                }
            }
        }
        let movementStart = motion.position
        let remaining = movementNode.position - movementStart
        let distance = sqrt(dot(remaining, remaining))
        let desiredVelocity =
            distance > 0
            ? remaining / distance
                * definition.maximumVelocity
            : Vector3.zero
        let velocityDelta = desiredVelocity - motion.velocity
        let deltaMagnitude = sqrt(dot(velocityDelta, velocityDelta))
        let maximumDelta =
            definition.maximumDeltaVelocity * duration
        if deltaMagnitude > maximumDelta, deltaMagnitude > 0 {
            motion.velocity = motion.velocity
                + velocityDelta / deltaMagnitude * maximumDelta
        } else {
            motion.velocity = desiredVelocity
        }
        let trace = traceIndoorMovement(
            in: level,
            startRoom: motion.roomSourceIndex,
            start: motion.position,
            end: motion.position + motion.velocity * duration,
            radius: definition.collisionRadius
        )
        motion.position = trace.finalPosition
        motion.roomSourceIndex = trace.containingRoomSourceIndex
        if path.nodes.count == 1,
           pathIndex != loopingPathIndex,
           dot(
               movementStart - movementNode.position,
               motion.position - movementNode.position
           ) <= 0 {
            completesAfterMovement = true
        }
        if case .wallHit = trace.outcome {
            motion.velocity = .zero
            motion.pathFailure = .movementBlocked
        } else {
            motion.pathFailure = nil
        }
        if orientsToPathNodes {
            var targetOrientation = motion.orientation
            var shouldTurn = true
            if motion.pathNodeIndex > 0 {
                let currentNode = path.nodes[motion.pathNodeIndex]
                let previousNode =
                    path.nodes[motion.pathNodeIndex - 1]
                let line =
                    currentNode.position - previousNode.position
                let lineLength = sqrt(dot(line, line))
                let projection = dot(
                    movementStart - previousNode.position,
                    line / lineLength
                )
                if projection > lineLength {
                    shouldTurn = false
                } else if projection > 0 {
                    let currentScale = projection / lineLength
                    let previousScale = 1 - currentScale
                    targetOrientation =
                        sourceOrientation(
                            forward:
                                currentNode.forward * currentScale
                                + previousNode.forward
                                    * previousScale,
                            up:
                                currentNode.up * currentScale
                                + previousNode.up * previousScale
                        )
                }
            }
            if shouldTurn {
                motion.orientation =
                    trainingTurnedTowardMatrix(
                        motion.orientation,
                        target: targetOrientation,
                        maximumTurnRate:
                            definition.maximumTurnRate,
                        duration: duration
                    )
            }
        } else {
            motion.orientation =
                trainingTurnedTowardDirection(
                    motion.orientation,
                    velocity: motion.velocity,
                    maximumTurnRate:
                        definition.maximumTurnRate,
                    duration: duration
                )
        }
        if completesAfterMovement {
            motion.activePathIndex = nil
            motion.pathNodeIndex = 0
            motion.velocity = .zero
        }
    }

    private func restoreTrainingFollowBotPresentation() {
        guard let state = trainingManeuverFollowState,
              let lesson =
                level.trainingDodgeAttempt?.maneuverFollow,
              let objectIndex = level.objects.firstIndex(where: {
                  $0.handle == lesson.followBotObjectHandle
              })
        else {
            return
        }
        level.objects[objectIndex].location =
            .room(state.roomSourceIndex)
        level.objects[objectIndex].position = state.position
        level.objects[objectIndex].orientation = state.orientation
    }

    var trainingGuidebotGoalCommandIsAvailable: Bool {
        trainingCameraMonitorActiveGoalTarget() != nil
    }

    var trainingGuidebotReturnToShipCommandIsAvailable: Bool {
        guard level.trainingCameraMonitorChain?.returnToShip != nil,
              let guidebotState = trainingRobotGuidebotState,
              guidebotState.guidebotContinuationWasPresented,
              guidebotState.guidebotIsDeployed,
              !guidebotState.guidebotEnteredShip,
              guidebotState.guidebotMode == .ambient,
              guidebotState.guidebot?.task == .escortPlayer,
              !guidebotState.returnWasRequested,
              let cameraState = trainingCameraMonitorState,
              !cameraState.isHeld,
              cameraState.wasUsed,
              !cameraState.script058WasPresented
        else {
            return false
        }
        return true
    }

    var trainingGuidebotReleaseCommandIsAvailable: Bool {
        guard level.trainingRobotGuidebotChain != nil,
              let state = trainingRobotGuidebotState
        else {
            return false
        }
        return state.guidebotEnteredShip
            && !state.guidebotIsDeployed
            && state.guidebot == nil
    }

    private func nextAuthoritativeRandomValue() -> UInt32 {
        authoritativeRandomState =
            authoritativeRandomState &* 214_013 &+ 2_531_011
        return (authoritativeRandomState >> 16) & 0x7fff
    }

    private func nextAuthoritativeRandomFraction() -> Float {
        Float(nextAuthoritativeRandomValue()) / 32_767
    }

    private func trainingDodgeSpreadDirection(
        _ forward: Vector3
    ) -> Vector3 {
        let difficultyScale = 1 / (5 - 1)
        let spreadScale =
            Float(16_768) * (1 - Float(difficultyScale))
            + Float(5_000) * Float(difficultyScale)
        let fireSpread = Int16(Float(0.15) * spreadScale)
        let halfFireSpread = fireSpread >> 1
        func angle() -> Int16 {
            Int16(truncatingIfNeeded:
                Int(nextAuthoritativeRandomValue() % UInt32(fireSpread))
                    - Int(halfFireSpread)
            )
        }
        return inverseTransform(
            forward,
            by: sourceRotationMatrix(
                pitch: angle(),
                yaw: angle(),
                roll: angle()
            )
        )
    }

    private func nextYellowFlareCreationOrdinal() -> UInt64? {
        guard var state = playerYellowFlareState,
              state.nextCreationOrdinal < UInt64.max - 1 else {
            return nil
        }
        let ordinal = state.nextCreationOrdinal
        state.nextCreationOrdinal += 1
        playerYellowFlareState = state
        return ordinal
    }

    private func reinitializeTrainingGuidebotAmbient(
        at gameTime: Float,
        state: inout TrainingRobotGuidebotState
    ) {
        state.nextAmbientTime = gameTime + 1
        _ = nextAuthoritativeRandomValue() % 6
    }

    private func setTrainingGuidebotMode(
        _ mode: TrainingGuidebotMode,
        at gameTime: Float,
        state: inout TrainingRobotGuidebotState
    ) {
        state.guidebotMode = mode
        state.guidebotModeTime = 0
        state.timeUntilNextFlare =
            3 + nextAuthoritativeRandomFraction()
        state.timeUntilNextPlayerVisibilityCheck =
            0.5 + 0.5 * nextAuthoritativeRandomFraction()
        state.returnTime = gameTime
        switch mode {
        case .birth:
            state.nextAmbientTime = gameTime + 1.2
        case .ambient:
            reinitializeTrainingGuidebotAmbient(
                at: gameTime,
                state: &state
            )
        }
    }

    private func advanceTrainingGuidebotTiming(
        duration: Float,
        gameTime: Float
    ) -> TrainingOpeningFeedback? {
        guard duration > 0,
              var state = trainingRobotGuidebotState,
              let guidebot = state.guidebot,
              let mode = state.guidebotMode,
              var modeTime = state.guidebotModeTime
        else {
            return nil
        }

        if mode == .ambient,
           (state.nextPowerupCheckTime ?? 0) <= gameTime {
            state.nextPowerupCheckTime =
                gameTime + 2 + nextAuthoritativeRandomFraction()
        }

        modeTime += duration
        state.guidebotModeTime = modeTime
        if mode == .birth {
            if modeTime > 1.2 {
                setTrainingGuidebotMode(
                    .ambient,
                    at: gameTime,
                    state: &state
                )
            }
            trainingRobotGuidebotState = state
            return nil
        }

        if gameTime > (state.nextAmbientTime ?? gameTime + 1) {
            reinitializeTrainingGuidebotAmbient(
                at: gameTime,
                state: &state
            )
        }

        var visibility =
            (state.timeUntilNextPlayerVisibilityCheck ?? 0.5)
                - duration
        if visibility <= 0 {
            visibility =
                0.5 + 0.5 * nextAuthoritativeRandomFraction()
        }
        state.timeUntilNextPlayerVisibilityCheck = visibility

        var flare = (state.timeUntilNextFlare ?? 3) - duration
        var feedback: TrainingOpeningFeedback?
        if flare <= 0 {
            flare = 3 + nextAuthoritativeRandomFraction()
            if state.yellowFlareGoalSlots?.isEligible == true,
               let definition =
                    level.trainingRobotGuidebotChain?.yellowFlare,
               state.yellowFlares != nil {
                feedback = .init(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName:
                        definition.fireSoundSourceName
                )
                if state.yellowFlares!.count
                    < trainingGuidebotYellowFlarePresentationCapacity {
                    let usesSharedCreationOrdinals =
                        playerYellowFlareState != nil
                    let creationOrdinal = usesSharedCreationOrdinals
                        ? nextYellowFlareCreationOrdinal()
                        : nil
                    guard !usesSharedCreationOrdinals
                        || creationOrdinal != nil else {
                        state.timeUntilNextFlare = flare
                        trainingRobotGuidebotState = state
                        return feedback
                    }
                    let orientation = sourceOrientation(
                        forward: guidebot.orientation.forward,
                        up: guidebot.orientation.up
                    )
                    let receivesTimeout = definition.timeout != nil
                        && state.yellowFlareTimeoutReachedFollowingFrame == false
                        && state.yellowFlareTimeoutSparks?.isEmpty == true
                        && !state.yellowFlares!.contains {
                            $0.sourceObjectSlot != nil
                        }
                    state.yellowFlares!.append(.init(
                        roomSourceIndex: guidebot.roomSourceIndex,
                        position: guidebot.position,
                        orientation: orientation,
                        velocity:
                            orientation.forward * definition.speed,
                        lifeRemaining: definition.lifetime,
                        lastParticleDropTime: 0,
                        presentedLightDistance:
                            definition.lightDistance,
                        // DestroyBot2's released slot 16 is the top of the
                        // LIFO free stack when this first retained flare is
                        // created.
                        sourceObjectSlot: receivesTimeout ? 16 : nil,
                        creationOrdinal: creationOrdinal,
                        parentObjectHandle:
                            level.trainingRobotGuidebotChain?
                                .guidebotObjectHandle
                    ))
                }
            }
        }
        state.timeUntilNextFlare = flare
        trainingRobotGuidebotState = state
        return feedback
    }

    private func trainingGuidebotFeedback(
        _ message: String,
        requestedSoundSourceName: String?,
        at gameTime: Float
    ) -> TrainingOpeningFeedback {
        var state = trainingRobotGuidebotState!
        var soundSourceName: String?
        if (state.lastMessageSoundTime ?? 0) + 2.5 < gameTime {
            state.lastMessageSoundTime = gameTime
            soundSourceName = requestedSoundSourceName
        }
        trainingRobotGuidebotState = state
        return .init(
            hudMessages: [message],
            voiceSourceName: "",
            voicePrecedesHUDMessages: true,
            soundSourceName: soundSourceName
        )
    }

    private func completeTrainingGuidebotReturn(
        at gameTime: Float
    ) -> TrainingOpeningFeedback? {
        guard var state = trainingRobotGuidebotState,
              state.guidebot?.task == .escortPlayer,
              state.returnGreetingWasPresented != true
        else {
            return nil
        }
        var feedback: TrainingOpeningFeedback?
        if state.activeGoalWasReached == true {
            let greeting = nextAuthoritativeRandomValue() % 100 > 50
                ? "GB: Come on!"
                : "GB: Let's go!"
            trainingRobotGuidebotState = state
            feedback = trainingGuidebotFeedback(
                greeting,
                requestedSoundSourceName:
                    level.trainingCameraMonitorChain?.returnToShip?
                        .greetingSoundSourceName,
                at: gameTime
            )
            state = trainingRobotGuidebotState!
        }
        state.timeUntilNextFlare =
            3 + nextAuthoritativeRandomFraction()
        state.yellowFlareGoalSlots?.slot2IsUsed = false
        state.returnTime = gameTime
        state.returnGreetingWasPresented = true
        trainingRobotGuidebotState = state
        return feedback
    }

    private func trainingCameraMonitorActiveGoalTarget()
        -> PlacedObject?
    {
        guard let state = trainingRobotGuidebotState,
              state.guidebotContinuationWasPresented,
              state.guidebotIsDeployed,
              !state.guidebotEnteredShip,
              state.guidebotMode == .ambient,
              state.guidebot?.task == .outbound,
              let cameraState = trainingCameraMonitorState,
              !cameraState.isHeld,
              !cameraState.wasUsed,
              !cameraState.script058WasPresented,
              let target = trainingCameraMonitorGoalTarget(in: level)
        else {
            return nil
        }
        return target
    }

    private func requestTrainingGuidebotActiveGoal(
        at gameTime: Float
    )
        -> TrainingOpeningFeedback?
    {
        guard let target = trainingCameraMonitorActiveGoalTarget(),
              case let .room(targetRoomSourceIndex) = target.location,
              var state = trainingRobotGuidebotState,
              var guidebot = state.guidebot,
              let definition = level.trainingRobotGuidebotChain?.guidebot,
              let soundSourceName =
                level.trainingCameraMonitorChain?.returnToShip?
                    .returnSoundSourceName
        else {
            return nil
        }
        let startForward = normalized(
            guidebot.velocity == .zero
                ? guidebot.orientation.forward
                : guidebot.velocity
        )
        guard case let .success(route) = trainingGuidebotRoute(
            in: level,
            startRoomSourceIndex: guidebot.roomSourceIndex,
            start: guidebot.position,
            startForward: startForward,
            destinationRoomSourceIndex: targetRoomSourceIndex,
            destination: target.position,
            radius: max(0, definition.collisionRadius - 0.1)
        ) else {
            return nil
        }
        guidebot.destination = target.position
        guidebot.route = route
        guidebot.routeFailure = nil
        guidebot.routePointIndex = 0
        guidebot.activeSteeringMode = .direct
        guidebot.task = .activeGoal
        guidebot.allocationStartPosition = guidebot.position
        guidebot.allocationStartForward = startForward
        guidebot.routeDestination = target.position
        guidebot.routeDestinationRoomSourceIndex =
            targetRoomSourceIndex
        state.activeGoalWasReached = false
        if state.yellowFlares != nil {
            state.yellowFlareGoalSlots = .init(
                slot1IsUsed: true,
                slot2IsUsed: true,
                slot3IsUsed: true
            )
        }
        state.guidebot = guidebot
        trainingRobotGuidebotState = state
        return trainingGuidebotFeedback(
            "GB: On my way!",
            requestedSoundSourceName: soundSourceName,
            at: gameTime
        )
    }

    private func deployTrainingGuidebot(
        from player: PlacedObject,
        playerVelocity: Vector3,
        gameTime: Float
    ) {
        guard var state = trainingRobotGuidebotState,
              !state.guidebotIsDeployed,
              !state.guidebotEnteredShip,
              let definition = level.trainingRobotGuidebotChain?.guidebot,
              case let .room(roomSourceIndex) = player.location
        else {
            return
        }
        let spawnVelocity = playerVelocity
            + player.orientation.forward * definition.birthForwardVelocity
        let destination = player.position
            + player.orientation.forward * definition.goalForwardDistance
        let allocated = trainingGuidebotRoute(
            in: level,
            startRoomSourceIndex: roomSourceIndex,
            start: player.position,
            startForward: player.orientation.forward,
            destinationRoomSourceIndex: roomSourceIndex,
            destination: destination,
            radius: max(0, definition.collisionRadius - 0.1)
        )
        let route: TrainingGuidebotRoute
        let failure: TrainingGuidebotRouteError?
        switch allocated {
        case .success(let allocatedRoute):
            route = allocatedRoute
            failure = nil
        case .failure(let error):
            route = .init(
                mode: .direct,
                points: [destination],
                roomSourceIndices: [roomSourceIndex],
                nodeReferences: []
            )
            failure = error
        }
        state.guidebotIsDeployed = true
        state.guidebot = .init(
            spawnPosition: player.position,
            roomSourceIndex: roomSourceIndex,
            position: player.position,
            orientation: player.orientation,
            spawnVelocity: spawnVelocity,
            velocity: spawnVelocity,
            destination: destination,
            route: route,
            routeFailure: failure,
            routePointIndex: 0,
            activeSteeringMode: .direct,
            task: .outbound,
            allocationStartPosition: player.position,
            allocationStartForward: player.orientation.forward,
            routeDestination: destination,
            routeDestinationRoomSourceIndex: roomSourceIndex
        )
        state.nextPowerupCheckTime =
            state.nextPowerupCheckTime ?? 0
        state.lastMessageSoundTime =
            state.lastMessageSoundTime ?? 0
        state.returnGreetingWasPresented = false
        if state.yellowFlares != nil {
            state.yellowFlareGoalSlots = .init(
                slot1IsUsed: true,
                slot2IsUsed: false,
                slot3IsUsed: false
            )
        }
        setTrainingGuidebotMode(
            .birth,
            at: gameTime,
            state: &state
        )
        trainingRobotGuidebotState = state
        restoreTrainingGuidebotPresentation()
    }

    private func releaseTrainingGuidebot(
        from player: PlacedObject,
        playerVelocity: Vector3,
        gameTime: Float
    ) -> TrainingOpeningFeedback? {
        guard trainingGuidebotReleaseCommandIsAvailable,
              var state = trainingRobotGuidebotState
        else {
            return nil
        }
        state.activeGoalWasReached = nil
        state.returnWasRequested = false
        state.guidebotEnteredShip = false
        state.arrivalFeedbackWasPresented = false
        trainingRobotGuidebotState = state
        deployTrainingGuidebot(
            from: player,
            playerVelocity: playerVelocity,
            gameTime: gameTime
        )
        guard trainingRobotGuidebotState?.guidebotIsDeployed == true,
              trainingRobotGuidebotState?.guidebot?.task == .outbound,
              trainingRobotGuidebotState?.guidebotMode == .birth,
              let soundSourceName =
                level.trainingRobotGuidebotChain?.releaseSoundSourceName
        else {
            return nil
        }
        return .init(
            hudMessages: [],
            voiceSourceName: "",
            voicePrecedesHUDMessages: true,
            soundSourceName: soundSourceName
        )
    }

    private func restoreTrainingGuidebotPresentation() {
        guard let guidebot =
                trainingRobotGuidebotState?.guidebot,
              let chain = level.trainingRobotGuidebotChain,
              let objectIndex = level.objects.firstIndex(where: {
                  $0.handle == chain.guidebotObjectHandle
              }),
              let presentationIndex =
                level.objectPresentations.firstIndex(where: {
                    $0.objectHandle == chain.guidebotObjectHandle
                })
        else {
            return
        }
        level.objects[objectIndex].location =
            .room(guidebot.roomSourceIndex)
        level.objects[objectIndex].position = guidebot.position
        level.objects[objectIndex].orientation = guidebot.orientation
        let presentation = level.objectPresentations[presentationIndex]
        level.objectPresentations[presentationIndex] = .init(
            objectHandle: presentation.objectHandle,
            primaryModel: presentation.primaryModel,
            mediumModel: presentation.mediumModel,
            lowModel: presentation.lowModel,
            dyingModel: presentation.dyingModel,
            mediumDistance: presentation.mediumDistance,
            lowDistance: presentation.lowDistance,
            isVisible: true
        )
    }

    private func advanceTrainingGuidebot(
        duration: Float,
        player: PlacedObject,
        playerRadius: Float
    ) -> TrainingGuidebotAdvanceEvent? {
        guard duration > 0,
              var state = trainingRobotGuidebotState,
              var guidebot = state.guidebot,
              let definition = level.trainingRobotGuidebotChain?.guidebot
        else {
            return nil
        }
        if guidebot.task == .escortPlayer {
            guidebot.velocity = .zero
            guidebot.destination = player.position
            guidebot.activeSteeringMode = .stopped
            state.guidebot = guidebot
            trainingRobotGuidebotState = state
            restoreTrainingGuidebotPresentation()
            return nil
        }
        if guidebot.task == .returnToPlayer
            || guidebot.task == .returnToShip
        {
            if case let .room(playerRoomSourceIndex) = player.location,
               playerRoomSourceIndex
                    != guidebot.routeDestinationRoomSourceIndex {
                let startForward = normalized(
                    guidebot.velocity == .zero
                        ? guidebot.orientation.forward
                        : guidebot.velocity
                )
                let allocated = trainingGuidebotRoute(
                    in: level,
                    startRoomSourceIndex: guidebot.roomSourceIndex,
                    start: guidebot.position,
                    startForward: startForward,
                    destinationRoomSourceIndex: playerRoomSourceIndex,
                    destination: player.position,
                    radius: max(
                        0,
                        definition.collisionRadius - 0.1
                    )
                )
                switch allocated {
                case .success(let route):
                    guidebot.route = route
                    guidebot.routeFailure = nil
                case .failure(let failure):
                    guidebot.route = .init(
                        mode: .direct,
                        points: [player.position],
                        roomSourceIndices: [
                            guidebot.roomSourceIndex
                        ],
                        nodeReferences: []
                    )
                    guidebot.routeFailure = failure
                }
                guidebot.routePointIndex = 0
                guidebot.activeSteeringMode = .direct
                guidebot.allocationStartPosition = guidebot.position
                guidebot.allocationStartForward = startForward
                guidebot.routeDestination = player.position
                guidebot.routeDestinationRoomSourceIndex =
                    playerRoomSourceIndex
            }
            guidebot.destination = player.position
        }
        let followsAllocatedRoute =
            guidebot.routeFailure == nil && guidebot.route.mode != .direct
        func passedRoutePoint(at position: Vector3) -> Bool {
            let index = guidebot.routePointIndex
            guard followsAllocatedRoute,
                  index < guidebot.route.points.count - 1 else {
                return false
            }
            let point = guidebot.route.points[index]
            let pathDirection = index == 0
                ? guidebot.route.points[index + 1] - point
                : point - guidebot.route.points[index - 1]
            return dot(position - point, pathDirection) >= 0
        }
        while passedRoutePoint(at: guidebot.position) {
            guidebot.routePointIndex += 1
        }
        let isFinalRoutePoint =
            guidebot.routePointIndex == guidebot.route.points.count - 1
        let target = followsAllocatedRoute
            ? ((guidebot.task == .returnToPlayer
                || guidebot.task == .returnToShip) && isFinalRoutePoint
                ? guidebot.destination
                : guidebot.route.points[guidebot.routePointIndex])
            : guidebot.destination
        let remaining = target - guidebot.position
        let distance = sqrt(dot(remaining, remaining))
        let goalCircleDistance: Float
        switch guidebot.task {
        case .outbound, .returnToShip:
            goalCircleDistance = definition.goalCircleDistance
        case .activeGoal:
            goalCircleDistance =
                20
                + definition.collisionRadius
                + (level.trainingCameraMonitorChain?
                    .pickupCollisionRadius ?? 0)
                + 0.1
        case .returnToPlayer:
            goalCircleDistance =
                30 + definition.collisionRadius + playerRadius + 0.1
        case .escortPlayer:
            goalCircleDistance = definition.goalCircleDistance
        }
        let reachedGoal =
            isFinalRoutePoint
                && distance <= goalCircleDistance
        let desiredVelocity = reachedGoal
            ? Vector3.zero
            : normalized(remaining) * definition.maximumVelocity
        let velocityDelta = desiredVelocity - guidebot.velocity
        let deltaMagnitude = sqrt(dot(velocityDelta, velocityDelta))
        let maximumDelta = definition.maximumDeltaVelocity * duration
        if deltaMagnitude > maximumDelta, deltaMagnitude > 0 {
            guidebot.velocity = guidebot.velocity
                + velocityDelta / deltaMagnitude * maximumDelta
        } else {
            guidebot.velocity = desiredVelocity
        }
        let movementStart = guidebot.position
        let trace = traceIndoorMovement(
            in: level,
            startRoom: guidebot.roomSourceIndex,
            start: guidebot.position,
            end: guidebot.position + guidebot.velocity * duration,
            radius: definition.collisionRadius
        )
        guidebot.position = trace.finalPosition
        guidebot.roomSourceIndex = trace.containingRoomSourceIndex
        if case .wallHit = trace.outcome {
            guidebot.velocity = .zero
        }
        while passedRoutePoint(at: guidebot.position) {
            guidebot.routePointIndex += 1
        }
        guidebot.activeSteeringMode = reachedGoal
            ? .stopped
            : followsAllocatedRoute ? .allocatedRoute : .direct
        if guidebot.task == .activeGoal, reachedGoal,
           case let .room(playerRoomSourceIndex) = player.location {
            let startForward = normalized(
                guidebot.velocity == .zero
                    ? guidebot.orientation.forward
                    : guidebot.velocity
            )
            let allocated = trainingGuidebotRoute(
                in: level,
                startRoomSourceIndex: guidebot.roomSourceIndex,
                start: guidebot.position,
                startForward: startForward,
                destinationRoomSourceIndex: playerRoomSourceIndex,
                destination: player.position,
                radius: max(
                    0,
                    definition.collisionRadius - 0.1
                )
            )
            switch allocated {
            case .success(let route):
                guidebot.route = route
                guidebot.routeFailure = nil
            case .failure(let failure):
                guidebot.route = .init(
                    mode: .direct,
                    points: [player.position],
                    roomSourceIndices: [
                        guidebot.roomSourceIndex
                    ],
                    nodeReferences: []
                )
                guidebot.routeFailure = failure
            }
            guidebot.destination = player.position
            guidebot.routePointIndex = 0
            guidebot.activeSteeringMode = .direct
            guidebot.task = .returnToPlayer
            guidebot.allocationStartPosition = guidebot.position
            guidebot.allocationStartForward = startForward
            guidebot.routeDestination = player.position
            guidebot.routeDestinationRoomSourceIndex =
                playerRoomSourceIndex
            state.activeGoalWasReached = true
            if state.yellowFlares != nil {
                state.yellowFlareGoalSlots = .init(
                    slot1IsUsed: true,
                    slot2IsUsed: true,
                    slot3IsUsed: false
                )
            }
            state.guidebot = guidebot
            trainingRobotGuidebotState = state
            restoreTrainingGuidebotPresentation()
            return .reachedActiveGoal
        }
        if guidebot.task == .returnToPlayer, reachedGoal {
            guidebot.velocity = .zero
            guidebot.destination = player.position
            guidebot.activeSteeringMode = .stopped
            guidebot.task = .escortPlayer
            state.guidebot = guidebot
            trainingRobotGuidebotState = state
            restoreTrainingGuidebotPresentation()
            return .returnedToPlayer
        }
        if guidebot.task == .returnToShip,
           case let .room(playerRoomSourceIndex) = player.location,
           guidebot.roomSourceIndex == playerRoomSourceIndex,
           segmentSphereHitFraction(
               start: movementStart,
               end: guidebot.position,
               center: player.position,
               radius: definition.collisionRadius + playerRadius
           ) != nil {
            state.guidebot = nil
            state.guidebotIsDeployed = false
            state.guidebotEnteredShip = true
            state.yellowFlareGoalSlots = nil
            trainingRobotGuidebotState = state
            let handle =
                level.trainingRobotGuidebotChain!.guidebotObjectHandle
            setObjectPresentationVisibility(
                in: &level,
                handle: handle,
                isVisible: false
            )
            return .enteredShip
        }
        if guidebot.task == .activeGoal {
            if state.yellowFlareGoalSlots?.slot3IsUsed == true {
                state.yellowFlareGoalSlots?.slot3IsUsed = false
            } else if state.yellowFlareGoalSlots?.slot2IsUsed == true {
                state.yellowFlareGoalSlots?.slot2IsUsed = false
            }
        } else if guidebot.task == .outbound, reachedGoal {
            state.yellowFlareGoalSlots?.slot1IsUsed = false
        }
        state.guidebot = guidebot
        trainingRobotGuidebotState = state
        restoreTrainingGuidebotPresentation()
        return nil
    }

    private func trainingGuidebotYellowFlareNormalizedVisualAge(
        creationTime: Float?,
        lifetime: Float,
        lifeRemaining: Float,
        gameTime: Float
    ) -> Float {
        guard lifetime > 0 else { return 1 }
        let age = creationTime.map { gameTime - $0 }
            ?? (lifetime - lifeRemaining)
        return max(0, min(1, age / lifetime))
    }

    private func trainingGuidebotYellowFlareVisualOpacity(
        creationTime: Float?,
        lifetime: Float,
        lifeRemaining: Float,
        gameTime: Float
    ) -> Float {
        let normalizedAge = trainingGuidebotYellowFlareNormalizedVisualAge(
            creationTime: creationTime,
            lifetime: lifetime,
            lifeRemaining: lifeRemaining,
            gameTime: gameTime
        )
        return normalizedAge <= 0.5
            ? 1
            : max(0, 1 - (normalizedAge - 0.5) / 0.5)
    }

    private func trainingGuidebotYellowFlareParticleTexture(
        timeout: TrainingGuidebotYellowFlareTimeoutDefinition?,
        creationTime: Float?,
        lifetime: Float,
        lifeRemaining: Float,
        gameTime: Float,
        fallback: SourceResource
    ) -> SourceResource {
        guard let frames = timeout?.childAnimationFrames,
              frames.count
                == trainingGuidebotYellowFlareAnimationFrames.count,
              timeout?.childSourceFrameTime != nil else {
            return fallback
        }
        let normalizedAge = trainingGuidebotYellowFlareNormalizedVisualAge(
            creationTime: creationTime,
            lifetime: lifetime,
            lifeRemaining: lifeRemaining,
            gameTime: gameTime
        )
        return frames[min(
            frames.count - 1,
            Int(Float(frames.count) * normalizedAge)
        )]
    }

    private func trainingGuidebotYellowFlareCarrierTexture(
        timeout: TrainingGuidebotYellowFlareTimeoutDefinition,
        gameTime: Float
    ) -> SourceResource {
        guard let frames = timeout.childAnimationFrames,
              frames.count
                == trainingGuidebotYellowFlareAnimationFrames.count,
              let sourceFrameTime = timeout.childSourceFrameTime else {
            return timeout.childTexture
        }
        return frames[Int(gameTime / sourceFrameTime) % frames.count]
    }

    private func appendTrainingGuidebotYellowFlareParticle(
        roomSourceIndex: Int,
        position: Vector3,
        particleSize: Float,
        particleLifetime: Float,
        gameTime: Float,
        capacity: Int,
        generationOrdinal: UInt64? = nil,
        sourceAttemptIndex: Int? = nil,
        to particles: inout [TrainingGuidebotYellowFlareParticleState]
    ) {
        guard particles.count < capacity else { return }
        let rawVelocity = Vector3(
            x: Float(Int(nextAuthoritativeRandomValue() % 100) - 50),
            y: Float(nextAuthoritativeRandomValue() % 100),
            z: Float(Int(nextAuthoritativeRandomValue() % 100) - 50)
        )
        let magnitude = sqrt(dot(rawVelocity, rawVelocity))
        let speed = Float(10 + nextAuthoritativeRandomValue() % 10)
        let velocity = magnitude > 0
            ? rawVelocity / magnitude * speed
            : .zero
        let sizeJitter = Float(
            Int(nextAuthoritativeRandomValue() % 11) - 5
        )
        let lifeJitter = Float(
            Int(nextAuthoritativeRandomValue() % 11) - 5
        )
        let size = particleSize + sizeJitter * (particleSize / 10)
        let lifetime = particleLifetime
            + lifeJitter * (particleLifetime / 10)
        particles.append(.init(
            roomSourceIndex: roomSourceIndex,
            position: position,
            velocity: velocity,
            size: size,
            lifetime: lifetime,
            lifeRemaining: lifetime,
            creationTime: gameTime,
            generationOrdinal: generationOrdinal,
            sourceAttemptIndex: sourceAttemptIndex
        ))
    }

    private func advanceTrainingGuidebotYellowFlareTimeoutSpark(
        _ spark: inout TrainingGuidebotYellowFlareTimeoutSparkState,
        duration: Float,
        gameTime: Float,
        definition: TrainingGuidebotYellowFlareTimeoutDefinition,
        particleCapacity: Int =
            trainingGuidebotYellowFlareTimeoutSparkParticlePresentationCapacity,
        particles: inout [TrainingGuidebotYellowFlareParticleState]
    ) -> Bool {
        spark.lifeRemaining -= duration
        if gameTime - spark.lastParticleDropTime
            > definition.childParticleInterval {
            appendTrainingGuidebotYellowFlareParticle(
                roomSourceIndex: spark.roomSourceIndex,
                position:
                    spark.position
                    - spark.orientation.forward
                        * definition.childCollisionRadius,
                particleSize: definition.childParticleSize,
                particleLifetime: definition.childParticleLifetime,
                gameTime: gameTime,
                capacity: particleCapacity,
                generationOrdinal: spark.generationOrdinal,
                sourceAttemptIndex: spark.sourceAttemptIndex,
                to: &particles
            )
            spark.lastParticleDropTime = gameTime
        }
        guard spark.lifeRemaining >= 0 else { return false }
        let motion = analyticLinearMotion(
            position: spark.position,
            velocity: spark.velocity,
            force: .init(
                x: 0,
                y: level.metadata.gravity * definition.childMass,
                z: 0
            ),
            mass: definition.childMass,
            drag: definition.childDrag,
            duration: duration
        )
        spark.position = motion.position
        spark.velocity = motion.velocity
        spark.presentedLightDistance = definition.childLightDistance
        return true
    }

    private func advanceTrainingGuidebotYellowFlares(
        duration: Float,
        gameTime: Float,
        selection: YellowFlareAdvanceSelection = .all,
        advancesPassiveState: Bool = true
    ) {
        guard duration > 0,
              let definition =
                level.trainingRobotGuidebotChain?.yellowFlare,
              var state = trainingRobotGuidebotState,
              let flares = state.yellowFlares,
              var particles = state.yellowFlareParticles
        else {
            return
        }

        var timeoutExplosions = state.yellowFlareTimeoutExplosions
        var timeoutSparks = state.yellowFlareTimeoutSparks
        var timeoutSparkParticles = state.yellowFlareTimeoutSparkParticles
        if let timeout = definition.timeout,
           let sparks = timeoutSparks,
           var sparkParticles = timeoutSparkParticles,
           !sparks.isEmpty {
            var advancedSparks = sparks.filter {
                !selection.includes($0.generationOrdinal)
            }
            advancedSparks.reserveCapacity(sparks.count)
            for var spark in sparks.sorted(by: {
                $0.sourceObjectSlot < $1.sourceObjectSlot
            }) {
                guard selection.includes(spark.generationOrdinal) else {
                    continue
                }
                if advanceTrainingGuidebotYellowFlareTimeoutSpark(
                    &spark,
                    duration: duration,
                    gameTime: gameTime,
                    definition: timeout,
                    particles: &sparkParticles
                ) {
                    advancedSparks.append(spark)
                }
            }
            timeoutSparks = advancedSparks.sorted {
                ($0.generationOrdinal ?? 0, $0.sourceAttemptIndex)
                    < ($1.generationOrdinal ?? 0, $1.sourceAttemptIndex)
            }
            timeoutSparkParticles = sparkParticles
        }

        var survivors: [TrainingGuidebotYellowFlareState] = []
        survivors.reserveCapacity(flares.count)
        for var flare in flares {
            guard selection.includes(flare.creationOrdinal) else {
                survivors.append(flare)
                continue
            }
            flare.lifeRemaining -= duration
            if gameTime - flare.lastParticleDropTime
                > definition.particleInterval {
                if particles.count
                    < trainingGuidebotYellowFlareParticlePresentationCapacity
                {
                    appendTrainingGuidebotYellowFlareParticle(
                        roomSourceIndex: flare.roomSourceIndex,
                        position:
                            flare.position
                            - flare.orientation.forward
                                * definition.collisionRadius,
                        particleSize: definition.particleSize,
                        particleLifetime: definition.particleLifetime,
                        gameTime: gameTime,
                        capacity:
                            trainingGuidebotYellowFlareParticlePresentationCapacity,
                        generationOrdinal: flare.creationOrdinal,
                        to: &particles
                    )
                }
                flare.lastParticleDropTime = gameTime
            }

            guard flare.lifeRemaining >= 0 else {
                if let timeout = definition.timeout,
                   let parentSlot = flare.sourceObjectSlot,
                   var explosions = timeoutExplosions,
                   var sparks = timeoutSparks,
                   var sparkParticles = timeoutSparkParticles {
                    if explosions.count
                        < trainingGuidebotYellowFlareTimeoutExplosionPresentationCapacity {
                        explosions.append(.init(
                            roomSourceIndex: flare.roomSourceIndex,
                            position: flare.position,
                            size: timeout.explosionSize,
                            lifetime: timeout.explosionLifetime,
                            lifeRemaining: timeout.explosionLifetime,
                            creationTime: gameTime,
                            generationOrdinal: flare.creationOrdinal
                        ))
                    }
                    let sourceSlots = [17, 8, 41, 42, 43, 44, 45, 46, 47]
                    let origin = flare.position
                        + flare.orientation.forward
                            * (definition.collisionRadius / 2)
                    for attempt in 0..<timeout.childCount {
                        guard attempt < sourceSlots.count,
                              sparks.count
                                < trainingGuidebotYellowFlareTimeoutSparkPresentationCapacity
                        else {
                            continue
                        }
                        let orientation: Matrix3
                        if attempt == 0 {
                            orientation = flare.orientation
                        } else {
                            let norm = Float(attempt - 1)
                                / Float(timeout.childCount - 1)
                            let ringAngle = norm * 2 * Float.pi
                            let pitch = sourceFixedAngleRadians(
                                cos(ringAngle) * Float.pi / 8
                            )
                            let yaw = sourceFixedAngleRadians(
                                sin(ringAngle) * Float.pi / 8
                            )
                            orientation = sourceOrthogonalized(
                                sourceMatrixMultiply(
                                    flare.orientation,
                                    sourceTransposed(sourceRotationMatrix(
                                        pitch: pitch,
                                        yaw: yaw,
                                        roll: 0
                                    ))
                                )
                            )
                        }
                        var spark = TrainingGuidebotYellowFlareTimeoutSparkState(
                            sourceAttemptIndex: attempt,
                            sourceObjectSlot: sourceSlots[attempt],
                            receivedControlOnCreationFrame:
                                sourceSlots[attempt] > parentSlot,
                            roomSourceIndex: flare.roomSourceIndex,
                            position: origin,
                            orientation: orientation,
                            velocity:
                                orientation.forward * timeout.childSpeed,
                            lifeRemaining: timeout.childLifetime,
                            lastParticleDropTime: 0,
                            presentedLightDistance:
                                timeout.childLightDistance,
                            generationOrdinal: flare.creationOrdinal
                        )
                        let survivesCreationFrame: Bool
                        if spark.receivedControlOnCreationFrame {
                            survivesCreationFrame =
                                advanceTrainingGuidebotYellowFlareTimeoutSpark(
                                &spark,
                                duration: duration,
                                gameTime: gameTime,
                                definition: timeout,
                                particles: &sparkParticles
                            )
                        } else {
                            survivesCreationFrame = true
                        }
                        if survivesCreationFrame {
                            sparks.append(spark)
                        }
                    }
                    timeoutExplosions = explosions
                    timeoutSparks = sparks
                    timeoutSparkParticles = sparkParticles
                    state.yellowFlareTimeoutReachedFollowingFrame = true
                }
                continue
            }
            if let handle = flare.stuckObjectHandle,
               let localPosition = flare.stuckObjectOffset,
               let localOrientation = flare.stuckObjectOrientation,
               let object = level.objects.first(where: {
                   $0.handle == handle
               }),
               case let .room(roomSourceIndex) = object.location {
                flare.position =
                    object.position
                    + transform(localPosition, by: object.orientation)
                flare.orientation = transform(
                    localOrientation,
                    by: object.orientation
                )
                flare.roomSourceIndex = roomSourceIndex
            }

            guard flare.stuckObjectHandle == nil,
                  flare.velocity != .zero else {
                flare.presentedLightDistance =
                    definition.lightDistance
                    + Float(
                        Int(nextAuthoritativeRandomValue() % 5) - 2
                    )
                survivors.append(flare)
                continue
            }
            let start = flare.position
            let end = start + flare.velocity * duration
            let trace = traceIndoorMovement(
                in: level,
                startRoom: flare.roomSourceIndex,
                start: start,
                end: end,
                radius: definition.collisionRadius
            )
            let distance = vectorDistance(start, end)
            let wallFraction = distance > 0
                ? vectorDistance(start, trace.finalPosition) / distance
                : 1
            let age = definition.lifetime - flare.lifeRemaining
            let parentHandle =
                flare.parentObjectHandle
                    ?? level.trainingRobotGuidebotChain!.guidebotObjectHandle
            let nearestObjectHit = level.objects.compactMap {
                object -> (object: PlacedObject, fraction: Float)? in
                guard case let .room(objectRoomSourceIndex) = object.location,
                      trace.visitedRoomSourceIndices.contains(
                          objectRoomSourceIndex
                      ),
                      age >= 3 || object.handle != parentHandle,
                      let presentation =
                        level.objectPresentations.first(where: {
                            $0.objectHandle == object.handle
                                && $0.isVisible
                        }),
                      let model = level.models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      let fraction = segmentSphereHitFraction(
                          start: start,
                          end: end,
                          center: object.position,
                          radius:
                            definition.collisionRadius
                                + model.collisionRadius
                      ) else {
                    return nil
                }
                return (object, fraction)
            }.min { $0.fraction < $1.fraction }
            if let hit = nearestObjectHit,
               hit.fraction <= wallFraction + 0.000_1 {
                flare.position =
                    start + (end - start) * hit.fraction
                flare.velocity = .zero
                flare.stuckObjectHandle = hit.object.handle
                flare.stuckObjectOffset =
                    inverseTransform(
                        flare.position - hit.object.position,
                        by: hit.object.orientation
                    )
                flare.stuckObjectOrientation = inverseTransform(
                    flare.orientation,
                    by: hit.object.orientation
                )
                if case let .room(roomSourceIndex) = hit.object.location {
                    flare.roomSourceIndex = roomSourceIndex
                }
            } else if case .wallHit = trace.outcome {
                flare.position = trace.finalPosition
                flare.roomSourceIndex =
                    trace.containingRoomSourceIndex
                flare.velocity = .zero
            } else {
                flare.position = trace.finalPosition
                flare.roomSourceIndex =
                    trace.containingRoomSourceIndex
            }
            flare.presentedLightDistance =
                definition.lightDistance
                + Float(
                    Int(nextAuthoritativeRandomValue() % 5) - 2
                )
            survivors.append(flare)
        }

        func advanceParticles(
            _ particles: [TrainingGuidebotYellowFlareParticleState]
        ) -> [TrainingGuidebotYellowFlareParticleState] {
            particles.compactMap { particle in
                var particle = particle
                particle.lifeRemaining -= duration
                guard particle.lifeRemaining >= 0 else { return nil }
                let motion = analyticLinearMotion(
                    position: particle.position,
                    velocity: particle.velocity,
                    force: .init(x: 0, y: -3_220, z: 0),
                    mass: 100,
                    drag: 0.1,
                    duration: duration
                )
                particle.position = motion.position
                particle.velocity = motion.velocity
                return particle
            }
        }
        if advancesPassiveState {
            particles = advanceParticles(particles)
            timeoutSparkParticles = timeoutSparkParticles.map(advanceParticles)
            timeoutExplosions = timeoutExplosions?.compactMap { explosion in
                var explosion = explosion
                explosion.lifeRemaining -= duration
                return explosion.lifeRemaining >= 0 ? explosion : nil
            }
        }
        state.yellowFlares = survivors
        state.yellowFlareParticles = particles
        state.yellowFlareTimeoutExplosions = timeoutExplosions
        state.yellowFlareTimeoutSparks = timeoutSparks
        state.yellowFlareTimeoutSparkParticles = timeoutSparkParticles
        trainingRobotGuidebotState = state
    }

    private func firePlayerYellowFlare(
        from player: PlacedObject,
        roomSourceIndex: Int,
        systemsFrameDuration: Float,
        systemsGameTime: Float
    ) -> TrainingOpeningFeedback? {
        guard let binding = level.shipDefinitions.first?.playerYellowFlare,
              let definition = level.trainingRobotGuidebotChain?.yellowFlare,
              var state = playerYellowFlareState,
              systemsGameTime >= state.nextFireTime else {
            return nil
        }
        let previousDeadline = state.nextFireTime
        let overdue = systemsGameTime - previousDeadline
        let continuityWindow = max(
            binding.fireWait,
            systemsFrameDuration * 1.5
        )
        state.nextFireTime = overdue >= 0 && overdue <= continuityWindow
            ? previousDeadline + binding.fireWait
            : systemsGameTime + binding.fireWait
        let muzzle = player.position
            + transform(
                binding.gunpointLocalPosition,
                by: player.orientation
            )
        let muzzleTrace = traceIndoorMovement(
            in: level,
            startRoom: roomSourceIndex,
            start: player.position,
            end: muzzle,
            radius: 0
        )
        guard case .noHit = muzzleTrace.outcome,
              state.parents.count < playerYellowFlarePresentationCapacity,
              state.nextCreationOrdinal < UInt64.max - 1
        else {
            playerYellowFlareState = state
            return nil
        }
        let forward = normalized(transform(
            binding.gunpointLocalForward,
            by: player.orientation
        ))
        let orientation = sourceOrientation(
            forward: forward,
            up: player.orientation.up
        )
        let ordinal = state.nextCreationOrdinal
        state.nextCreationOrdinal += 1
        state.parents.append(.init(
            roomSourceIndex: muzzleTrace.containingRoomSourceIndex,
            position: muzzle,
            orientation: orientation,
            velocity: forward * definition.speed,
            lifeRemaining: definition.lifetime,
            lastParticleDropTime:
                systemsGameTime - definition.particleInterval.nextUp,
            presentedLightDistance: definition.lightDistance,
            creationOrdinal: ordinal,
            parentObjectHandle: player.handle
        ))
        playerYellowFlareState = state
        return .init(
            hudMessages: [],
            voiceSourceName: "",
            voicePrecedesHUDMessages: true,
            soundSourceName: binding.fireSoundSourceName
        )
    }

    private struct PlayerConcussionImpact {
        let roomSourceIndex: Int
        let position: Vector3
        let directObjectHandle: UInt32?
        let explosionCreationOrdinal: UInt64
    }

    private func firePlayerConcussion(
        from player: PlacedObject,
        roomSourceIndex: Int,
        binding: PlayerConcussionBinding,
        state: inout PlayerConcussionState,
        frameDuration: Float,
        gameTime: Float
    ) -> TrainingOpeningFeedback? {
        guard state.ammo >= Int(binding.ammoUsage) else {
            return .init(
                hudMessages: ["Not enough projectiles available!"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: false
            )
        }
        guard gameTime >= state.nextFireTime,
              state.nextCreationOrdinal < UInt64.max,
              state.missiles.count < 6 else {
            return nil
        }
        let maskIndex = state.nextFiringMaskIndex
        let gunpoint = binding.gunpoints[maskIndex]
        let muzzlePosition = player.position
            + transform(gunpoint.localPosition, by: player.orientation)
        let wallTrace = traceIndoorMovement(
            in: level,
            startRoom: roomSourceIndex,
            start: player.position,
            end: muzzlePosition,
            radius: 0
        )
        let muzzleDistance = vectorDistance(player.position, muzzlePosition)
        let wallFraction = muzzleDistance > 0
            ? vectorDistance(player.position, wallTrace.finalPosition)
                / muzzleDistance
            : 1
        let objectObstructsMuzzle = level.objects.contains { object in
            guard object.handle != player.handle,
                  case let .room(objectRoom) = object.location,
                  wallTrace.visitedRoomSourceIndices.contains(objectRoom),
                  let presentation = level.objectPresentations.first(where: {
                      $0.objectHandle == object.handle && $0.isVisible
                  }),
                  let model = level.models.first(where: {
                      $0.source == presentation.primaryModel
                  }),
                  let fraction = segmentSphereHitFraction(
                      start: player.position,
                      end: muzzlePosition,
                      center: object.position,
                      radius: model.collisionRadius
                  ) else {
                return false
            }
            return fraction < min(1, wallFraction) - 0.000_1
        }
        guard case .noHit = wallTrace.outcome,
              !objectObstructsMuzzle else {
            return nil
        }

        let forward = normalized(
            transform(gunpoint.localForward, by: player.orientation)
        )
        state.missiles.append(.init(
            creationOrdinal: state.nextCreationOrdinal,
            roomSourceIndex: wallTrace.containingRoomSourceIndex,
            position: muzzlePosition,
            orientation: player.orientation,
            velocity: forward * binding.speed + velocity,
            lifeRemaining: binding.lifetime
        ))
        state.nextCreationOrdinal += 1
        state.ammo -= Int(binding.ammoUsage)
        state.nextFiringMaskIndex = (maskIndex + 1) % binding.firingMasks.count
        let wait = binding.fireWaits[maskIndex]
        let previousDeadline = state.nextFireTime
        let overdue = gameTime - previousDeadline
        let continuityWindow = max(wait, frameDuration * 1.5)
        if previousDeadline >= 0,
           overdue >= 0,
           overdue <= continuityWindow {
            state.nextFireTime = previousDeadline + wait
        } else {
            state.nextFireTime = gameTime + wait
        }
        return .init(
            hudMessages: [],
            voiceSourceName: "",
            voicePrecedesHUDMessages: false,
            soundSourceName: binding.fireSoundSourceName
        )
    }

    private func advancePlayerConcussionMissiles(
        duration: Float,
        playerHandle: UInt32,
        binding: PlayerConcussionBinding,
        state: inout PlayerConcussionState
    ) -> [PlayerConcussionImpact] {
        var impacts: [PlayerConcussionImpact] = []
        var survivors: [PlayerConcussionMissileState] = []
        for var missile in state.missiles {
            let spin = binding.rotationalVelocity
                / 65_536 * (2 * Float.pi) * duration
            missile.orientation = .init(
                right: rotate(
                    missile.orientation.right,
                    around: missile.orientation.forward,
                    angle: spin
                ),
                up: rotate(
                    missile.orientation.up,
                    around: missile.orientation.forward,
                    angle: spin
                ),
                forward: missile.orientation.forward
            )
            let start = missile.position
            let end = start + missile.velocity * duration
            let trace = traceIndoorMovement(
                in: level,
                startRoom: missile.roomSourceIndex,
                start: start,
                end: end,
                radius: binding.collisionRadius
            )
            let distance = vectorDistance(start, end)
            let wallFraction = distance > 0
                ? vectorDistance(start, trace.finalPosition) / distance
                : 1
            let objectHit = level.objects.compactMap {
                object -> (PlacedObject, Float)? in
                guard object.handle != playerHandle,
                      case let .room(objectRoom) = object.location,
                      trace.visitedRoomSourceIndices.contains(objectRoom),
                      let presentation = level.objectPresentations.first(where: {
                          $0.objectHandle == object.handle && $0.isVisible
                      }),
                      let model = level.models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      let fraction = segmentSphereHitFraction(
                          start: start,
                          end: end,
                          center: object.position,
                          radius: binding.collisionRadius
                            + model.collisionRadius
                      ) else {
                    return nil
                }
                return (object, fraction)
            }.min { $0.1 < $1.1 }

            let impactPosition: Vector3?
            let directObjectHandle: UInt32?
            if let objectHit, objectHit.1 <= wallFraction + 0.000_1 {
                impactPosition = start + (end - start) * objectHit.1
                directObjectHandle = objectHit.0.type == 2
                    ? objectHit.0.handle
                    : nil
            } else if case .noHit = trace.outcome {
                missile.position = trace.finalPosition
                missile.roomSourceIndex = trace.containingRoomSourceIndex
                missile.lifeRemaining -= duration
                if missile.lifeRemaining > 0 {
                    survivors.append(missile)
                    continue
                }
                impactPosition = missile.position
                directObjectHandle = nil
            } else {
                impactPosition = trace.finalPosition
                directObjectHandle = nil
            }
            let ordinal = state.nextCreationOrdinal
            state.nextCreationOrdinal += 1
            state.explosions.append(.init(
                creationOrdinal: ordinal,
                roomSourceIndex: trace.containingRoomSourceIndex,
                position: impactPosition!,
                lifeRemaining: binding.explosionLifetime,
                shockwaveLifeRemaining: binding.shockwaveDuration
            ))
            impacts.append(.init(
                roomSourceIndex: trace.containingRoomSourceIndex,
                position: impactPosition!,
                directObjectHandle: directObjectHandle,
                explosionCreationOrdinal: ordinal
            ))
        }
        state.missiles = survivors
        return impacts
    }

    private func advancePlayerYellowFlares(
        duration: Float,
        gameTime: Float,
        selection: YellowFlareAdvanceSelection = .all,
        advancesPassiveState: Bool = true
    ) {
        guard duration > 0,
              let definition =
                level.trainingRobotGuidebotChain?.yellowFlare,
              let timeout = definition.timeout,
              var state = playerYellowFlareState else {
            return
        }

        var advancedSparks = state.timeoutSparks.filter {
            !selection.includes($0.generationOrdinal)
        }
        for var spark in state.timeoutSparks.sorted(by: {
            ($0.generationOrdinal ?? 0, $0.sourceAttemptIndex)
                < ($1.generationOrdinal ?? 0, $1.sourceAttemptIndex)
        }) {
            guard selection.includes(spark.generationOrdinal) else {
                continue
            }
            if advanceTrainingGuidebotYellowFlareTimeoutSpark(
                &spark,
                duration: duration,
                gameTime: gameTime,
                definition: timeout,
                particleCapacity:
                    playerYellowFlareTimeoutSparkParticlePresentationCapacity,
                particles: &state.timeoutSparkParticles
            ) {
                advancedSparks.append(spark)
            }
        }
        state.timeoutSparks = advancedSparks

        var survivors: [TrainingGuidebotYellowFlareState] = []
        for var flare in state.parents.sorted(by: {
            ($0.creationOrdinal ?? 0) < ($1.creationOrdinal ?? 0)
        }) {
            guard selection.includes(flare.creationOrdinal) else {
                survivors.append(flare)
                continue
            }
            flare.lifeRemaining -= duration
            if gameTime - flare.lastParticleDropTime
                > definition.particleInterval {
                appendTrainingGuidebotYellowFlareParticle(
                    roomSourceIndex: flare.roomSourceIndex,
                    position: flare.position
                        - flare.orientation.forward
                            * definition.collisionRadius,
                    particleSize: definition.particleSize,
                    particleLifetime: definition.particleLifetime,
                    gameTime: gameTime,
                    capacity: playerYellowFlareParticlePresentationCapacity,
                    generationOrdinal: flare.creationOrdinal,
                    to: &state.parentParticles
                )
                flare.lastParticleDropTime = gameTime
            }
            guard flare.lifeRemaining >= 0 else {
                let ordinal = flare.creationOrdinal!
                if state.timeoutExplosions.count
                    < playerYellowFlareTimeoutExplosionPresentationCapacity {
                    state.timeoutExplosions.append(.init(
                        roomSourceIndex: flare.roomSourceIndex,
                        position: flare.position,
                        size: timeout.explosionSize,
                        lifetime: timeout.explosionLifetime,
                        lifeRemaining: timeout.explosionLifetime,
                        creationTime: gameTime,
                        generationOrdinal: ordinal
                    ))
                }
                let origin = flare.position
                    + flare.orientation.forward
                        * (definition.collisionRadius / 2)
                for attempt in 0..<timeout.childCount {
                    guard state.timeoutSparks.count
                        < playerYellowFlareTimeoutSparkPresentationCapacity
                    else { continue }
                    let orientation: Matrix3
                    if attempt == 0 {
                        orientation = flare.orientation
                    } else {
                        let norm = Float(attempt - 1)
                            / Float(timeout.childCount - 1)
                        let ringAngle = norm * 2 * Float.pi
                        orientation = sourceOrthogonalized(
                            sourceMatrixMultiply(
                                flare.orientation,
                                sourceTransposed(sourceRotationMatrix(
                                    pitch: sourceFixedAngleRadians(
                                        cos(ringAngle) * Float.pi / 8
                                    ),
                                    yaw: sourceFixedAngleRadians(
                                        sin(ringAngle) * Float.pi / 8
                                    ),
                                    roll: 0
                                ))
                            )
                        )
                    }
                    var spark = TrainingGuidebotYellowFlareTimeoutSparkState(
                        sourceAttemptIndex: attempt,
                        sourceObjectSlot: attempt,
                        receivedControlOnCreationFrame: true,
                        roomSourceIndex: flare.roomSourceIndex,
                        position: origin,
                        orientation: orientation,
                        velocity: orientation.forward * timeout.childSpeed,
                        lifeRemaining: timeout.childLifetime,
                        lastParticleDropTime: 0,
                        presentedLightDistance: timeout.childLightDistance,
                        generationOrdinal: ordinal
                    )
                    if advanceTrainingGuidebotYellowFlareTimeoutSpark(
                        &spark,
                        duration: duration,
                        gameTime: gameTime,
                        definition: timeout,
                        particleCapacity:
                            playerYellowFlareTimeoutSparkParticlePresentationCapacity,
                        particles: &state.timeoutSparkParticles
                    ) {
                        state.timeoutSparks.append(spark)
                    }
                }
                continue
            }

            if let handle = flare.stuckObjectHandle,
               let localPosition = flare.stuckObjectOffset,
               let localOrientation = flare.stuckObjectOrientation,
               let object = level.objects.first(where: {
                   $0.handle == handle
               }),
               case let .room(roomSourceIndex) = object.location {
                flare.position = object.position
                    + transform(localPosition, by: object.orientation)
                flare.orientation = transform(
                    localOrientation,
                    by: object.orientation
                )
                flare.roomSourceIndex = roomSourceIndex
            }
            if flare.stuckObjectHandle == nil, flare.velocity != .zero {
                let start = flare.position
                let end = start + flare.velocity * duration
                let trace = traceIndoorMovement(
                    in: level,
                    startRoom: flare.roomSourceIndex,
                    start: start,
                    end: end,
                    radius: definition.collisionRadius
                )
                let distance = vectorDistance(start, end)
                let wallFraction = distance > 0
                    ? vectorDistance(start, trace.finalPosition) / distance
                    : 1
                let age = definition.lifetime - flare.lifeRemaining
                let nearestObjectHit = level.objects.compactMap {
                    object -> (PlacedObject, Float)? in
                    guard case let .room(objectRoom) = object.location,
                          trace.visitedRoomSourceIndices.contains(objectRoom),
                          age >= 3
                            || object.handle != flare.parentObjectHandle,
                          let presentation =
                            level.objectPresentations.first(where: {
                                $0.objectHandle == object.handle
                                    && $0.isVisible
                            }),
                          let model = level.models.first(where: {
                              $0.source == presentation.primaryModel
                          }),
                          let fraction = segmentSphereHitFraction(
                              start: start,
                              end: end,
                              center: object.position,
                              radius: definition.collisionRadius
                                + model.collisionRadius
                          ) else { return nil }
                    return (object, fraction)
                }.min { $0.1 < $1.1 }
                if let hit = nearestObjectHit,
                   hit.1 <= wallFraction + 0.000_1 {
                    flare.position = start + (end - start) * hit.1
                    flare.velocity = .zero
                    flare.stuckObjectHandle = hit.0.handle
                    flare.stuckObjectOffset = inverseTransform(
                        flare.position - hit.0.position,
                        by: hit.0.orientation
                    )
                    flare.stuckObjectOrientation = inverseTransform(
                        flare.orientation,
                        by: hit.0.orientation
                    )
                    if case let .room(room) = hit.0.location {
                        flare.roomSourceIndex = room
                    }
                } else if case .wallHit = trace.outcome {
                    flare.position = trace.finalPosition
                    flare.roomSourceIndex = trace.containingRoomSourceIndex
                    flare.velocity = .zero
                } else {
                    flare.position = trace.finalPosition
                    flare.roomSourceIndex = trace.containingRoomSourceIndex
                }
            }
            flare.presentedLightDistance = definition.lightDistance
                + Float(Int(nextAuthoritativeRandomValue() % 5) - 2)
            survivors.append(flare)
        }
        state.parents = survivors

        func advanceParticles(
            _ particles: [TrainingGuidebotYellowFlareParticleState]
        ) -> [TrainingGuidebotYellowFlareParticleState] {
            particles.compactMap { value in
                var particle = value
                particle.lifeRemaining -= duration
                guard particle.lifeRemaining >= 0 else { return nil }
                let motion = analyticLinearMotion(
                    position: particle.position,
                    velocity: particle.velocity,
                    force: .init(x: 0, y: -3_220, z: 0),
                    mass: 100,
                    drag: 0.1,
                    duration: duration
                )
                particle.position = motion.position
                particle.velocity = motion.velocity
                return particle
            }
        }
        if advancesPassiveState {
            state.parentParticles = advanceParticles(state.parentParticles)
            state.timeoutSparkParticles =
                advanceParticles(state.timeoutSparkParticles)
            state.timeoutExplosions = state.timeoutExplosions.compactMap {
                value in
                var explosion = value
                explosion.lifeRemaining -= duration
                return explosion.lifeRemaining >= 0 ? explosion : nil
            }
        }
        playerYellowFlareState = state
    }

    private func advancePlayerAndGuidebotYellowFlares(
        duration systemsFrameDuration: Float,
        gameTime systemsGameTime: Float
    ) -> Void {
        if playerYellowFlareState == nil {
            advanceTrainingGuidebotYellowFlares(
                duration: systemsFrameDuration,
                gameTime: systemsGameTime
            )
        } else {
            let creationOrdinals = Set(
                (playerYellowFlareState?.parents.compactMap(\.creationOrdinal)
                    ?? [])
                + (playerYellowFlareState?.timeoutSparks.compactMap(
                    \.generationOrdinal
                ) ?? [])
                + (trainingRobotGuidebotState?.yellowFlares?.compactMap(
                    \.creationOrdinal
                ) ?? [])
                + (trainingRobotGuidebotState?.yellowFlareTimeoutSparks?
                    .compactMap(\.generationOrdinal) ?? [])
            ).sorted()
            for ordinal in creationOrdinals {
                advancePlayerYellowFlares(
                    duration: systemsFrameDuration,
                    gameTime: systemsGameTime,
                    selection: .ordinal(ordinal),
                    advancesPassiveState: false
                )
                advanceTrainingGuidebotYellowFlares(
                    duration: systemsFrameDuration,
                    gameTime: systemsGameTime,
                    selection: .ordinal(ordinal),
                    advancesPassiveState: false
                )
            }
            advancePlayerYellowFlares(
                duration: systemsFrameDuration,
                gameTime: systemsGameTime,
                selection: .none
            )
            advanceTrainingGuidebotYellowFlares(
                duration: systemsFrameDuration,
                gameTime: systemsGameTime,
                selection: .none
            )
        }
    }

    private func requestTrainingGuidebotReturn(
        to player: PlacedObject
    ) -> Bool {
        guard var state = trainingRobotGuidebotState,
              !state.returnWasRequested,
              !state.guidebotEnteredShip,
              var guidebot = state.guidebot,
              let definition = level.trainingRobotGuidebotChain?.guidebot,
              case let .room(playerRoomSourceIndex) = player.location
        else {
            return false
        }
        let startForward = normalized(
            guidebot.velocity == .zero
                ? guidebot.orientation.forward
                : guidebot.velocity
        )
        let allocated = trainingGuidebotRoute(
            in: level,
            startRoomSourceIndex: guidebot.roomSourceIndex,
            start: guidebot.position,
            startForward: startForward,
            destinationRoomSourceIndex: playerRoomSourceIndex,
            destination: player.position,
            radius: max(0, definition.collisionRadius - 0.1)
        )
        switch allocated {
        case .success(let route):
            guidebot.route = route
            guidebot.routeFailure = nil
        case .failure(let failure):
            guidebot.route = .init(
                mode: .direct,
                points: [player.position],
                roomSourceIndices: [guidebot.roomSourceIndex],
                nodeReferences: []
            )
            guidebot.routeFailure = failure
        }
        guidebot.destination = player.position
        guidebot.routePointIndex = 0
        guidebot.activeSteeringMode = .direct
        guidebot.task = .returnToShip
        guidebot.allocationStartPosition = guidebot.position
        guidebot.allocationStartForward = startForward
        guidebot.routeDestination = player.position
        guidebot.routeDestinationRoomSourceIndex =
            playerRoomSourceIndex
        state.guidebot = guidebot
        state.returnWasRequested = true
        if state.yellowFlares != nil {
            state.yellowFlareGoalSlots = .init(
                slot1IsUsed: true,
                slot2IsUsed: false,
                slot3IsUsed: false
            )
        }
        trainingRobotGuidebotState = state
        return true
    }

    func destroyTrainingRobot(handle: UInt32) {
        guard let chain = level.trainingRobotGuidebotChain,
              handle == chain.destroyRobotObjectHandle,
              var state = trainingRobotGuidebotState,
              !state.robotWasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        state.destructionTimerRemaining = chain.destructionDelay
        if var galleryState = trainingGalleryBarrierState {
            galleryState.markerLightDistance =
                level.trainingGalleryBarrier!.openMarkerLightDistance
            trainingGalleryBarrierState = galleryState
        }
        openTrainingGalleryBarrier(in: &level)
        state.controlsWereRestored = true
        state.robotShields = min(state.robotShields, -0.000_001)
        state.robotWasDestroyed = true
        trainingRobotGuidebotState = state

        if let handoff =
                level.trainingDodgeAttempt?.maneuverFollow?
                    .destructionHandoff,
           handle == handoff.destroyBot2ObjectHandle,
           var maneuverState = trainingManeuverFollowState,
           var destruction = maneuverState.destruction,
           var destroyBot1Destruction =
                destruction.destroyBot1Destruction
        {
            destruction.destroyBot2IsVisible = false
            destroyBot1Destruction.destroyBot2Motion.velocity = .zero
            destroyBot1Destruction.destroyBot2Motion.activePathIndex =
                nil
            destroyBot1Destruction.destroyBot2Motion.pathNodeIndex = 0
            destroyBot1Destruction.destroyBot2Motion.pathFailure = nil
            destruction.destroyBot1Destruction =
                destroyBot1Destruction
            maneuverState.destruction = destruction
            trainingManeuverFollowState = maneuverState
        }
        setObjectPresentationVisibility(
            in: &level,
            handle: handle,
            isVisible: false
        )
        level.objects.removeAll { $0.handle == handle }
    }

    func destroyTrainingRASBot1(handle: UInt32) {
        guard let chain = level.trainingRASBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot1DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot1DeathState = state
    }

    func destroyTrainingRASBot2(handle: UInt32) {
        guard let chain = level.trainingRASBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot2DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot2DeathState = state
    }

    func destroyTrainingRASBot3(handle: UInt32) {
        guard let chain = level.trainingRASBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot3DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot3DeathState = state
    }

    func destroyTrainingRASBot4(handle: UInt32) {
        guard let chain = level.trainingRASBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot4DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot4DeathState = state
    }

    func destroyTrainingLastBot1(handle: UInt32) {
        guard let chain = level.trainingLastBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot1DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot1DeathState = state
    }

    func destroyTrainingLastBot2(handle: UInt32) {
        guard let chain = level.trainingLastBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot2DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot2DeathState = state
    }

    func destroyTrainingLastBot3(handle: UInt32) {
        guard let chain = level.trainingLastBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot3DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot3DeathState = state
    }

    func destroyTrainingLastBot4(handle: UInt32) {
        guard let chain = level.trainingLastBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot4DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot4DeathState = state
    }

    func destroyTrainingLastBot5(handle: UInt32) {
        guard let chain = level.trainingLastBot5DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot5DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot5DeathState = state
    }

    private func destroyTrainingFollowBot(isDying: Bool) {
        guard isDying,
              let lesson =
                  level.trainingDodgeAttempt?.maneuverFollow,
              let handoff = lesson.destructionHandoff,
              var maneuverState = trainingManeuverFollowState,
              var destruction = maneuverState.destruction,
              !destruction.followBotWasDestroyed,
              level.objects.contains(where: {
                  $0.handle == handoff.followBotObjectHandle
              })
        else {
            return
        }
        level.objects.removeAll {
            $0.handle == handoff.followBotObjectHandle
        }
        setObjectPresentationVisibility(
            in: &level,
            handle: handoff.followBotObjectHandle,
            isVisible: false
        )
        destruction.followBotWasDestroyed = true
        destruction.followBotShields = min(
            destruction.followBotShields,
            -0.000_001
        )
        if destruction.script037Count < 1,
           maneuverState.script026Count > 0 {
            destruction.levelTimer11Remaining =
                handoff.destructionDelay
            destruction.script037Count = min(
                destruction.script037Count + 1,
                trainingScriptActionCounterMaximum
            )
        }
        maneuverState.destruction = destruction
        trainingManeuverFollowState = maneuverState
    }

    private func destroyTrainingDestroyBot1(isDying: Bool) {
        guard isDying,
              let lesson =
                level.trainingDodgeAttempt?.maneuverFollow,
              let handoff = lesson.destructionHandoff,
              var maneuverState = trainingManeuverFollowState,
              var destruction = maneuverState.destruction,
              destruction.script027Count > 0,
              var destroyBot1Destruction =
                destruction.destroyBot1Destruction,
              !destroyBot1Destruction.destroyBot1WasDestroyed,
              level.objects.contains(where: {
                  $0.handle == handoff.destroyBot1ObjectHandle
              })
        else {
            return
        }
        level.objects.removeAll {
            $0.handle == handoff.destroyBot1ObjectHandle
        }
        setObjectPresentationVisibility(
            in: &level,
            handle: handoff.destroyBot1ObjectHandle,
            isVisible: false
        )
        destroyBot1Destruction.destroyBot1WasDestroyed = true
        destroyBot1Destruction.destroyBot1Shields = min(
            destroyBot1Destruction.destroyBot1Shields,
            -0.000_001
        )
        if destroyBot1Destruction.script028Count < 1 {
            destruction.destroyBot1IsVisible = false
            destruction.destroyBot2IsVisible = true
            setObjectPresentationVisibility(
                in: &level,
                handle: handoff.destroyBot2ObjectHandle,
                isVisible: true
            )
            assignTrainingAuthoredPath(
                handoff.movingPathIndex,
                motion: &destroyBot1Destruction.destroyBot2Motion
            )
            destroyBot1Destruction.script028Count = min(
                destroyBot1Destruction.script028Count + 1,
                trainingScriptActionCounterMaximum
            )
        }
        destruction.destroyBot1Destruction =
            destroyBot1Destruction
        maneuverState.destruction = destruction
        trainingManeuverFollowState = maneuverState
    }

    private func fastPlayerHeadlight(
        from player: PlacedObject
    ) -> PlayerFastHeadlightFrame {
        guard case let .room(startRoomSourceIndex) = player.location else {
            preconditionFailure("The validated default player is indoor.")
        }
        let start = player.position
        let forward = player.orientation.forward
        let end = start + forward * 300
        let wallTrace = traceIndoorMovement(
            in: level,
            startRoom: startRoomSourceIndex,
            start: start,
            end: end,
            radius: 0
        )
        var selectedPosition = wallTrace.finalPosition
        var selectedRoomSourceIndex =
            wallTrace.containingRoomSourceIndex
        var selectedFraction = vectorDistance(start, selectedPosition) / 300
        let visitedRooms = Set(wallTrace.visitedRoomSourceIndices)
        let presentationByHandle = Dictionary(
            uniqueKeysWithValues: level.objectPresentations.map {
                ($0.objectHandle, $0)
            }
        )
        let modelBySource = Dictionary(
            uniqueKeysWithValues: level.models.map { ($0.source, $0) }
        )
        for object in level.objects {
            guard object.handle != player.handle,
                  case let .room(roomSourceIndex) = object.location,
                  visitedRooms.contains(roomSourceIndex),
                  let presentation = presentationByHandle[object.handle],
                  presentation.isVisible,
                  let model = modelBySource[presentation.primaryModel]
            else {
                continue
            }
            let radius = sourceObjectPresentationSize(
                model: model,
                objectType: object.type
            )
            guard let fraction = segmentSphereHitFraction(
                start: start,
                end: end,
                center: object.position,
                radius: radius
            ), fraction < selectedFraction else {
                continue
            }
            selectedFraction = fraction
            selectedPosition = start + (end - start) * fraction
            selectedRoomSourceIndex = roomSourceIndex
        }
        return PlayerFastHeadlightFrame(
            roomSourceIndex: selectedRoomSourceIndex,
            position: selectedPosition - forward / 4,
            lightDistance: 20
        )
    }

    private func updatePlayerRearView(
        input: InputSnapshot,
        systemsGameTime: Float
    ) {
        if input.rearViewPressed {
            if playerRearViewState != nil {
                playerRearViewState = nil
            } else {
                playerRearViewState = PlayerRearViewState(
                    leaveMode: false,
                    entryGameTime: systemsGameTime
                )
            }
            return
        }
        guard var state = playerRearViewState else { return }
        if state.leaveMode && !input.rearViewHeld {
            playerRearViewState = nil
        } else if input.rearViewHeld,
                  systemsGameTime - state.entryGameTime > 1.0 / 16.0 {
            state.leaveMode = true
            playerRearViewState = state
        }
    }

    func update(at timestamp: Double, input: InputSnapshot) -> PlayerSimulationFrame {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        precondition(pauseDepth == 0)
        let systemsFrameDuration = frameDuration
        let systemsGameTime = gameTime

        let binding = level.defaultPlayerBinding!
        let objectIndex = level.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        var object = level.objects[objectIndex]
        let controlsAreSuspended =
            trainingFinalGoalState?.endLevelWasRequested == true
        let currentEnabledControls = controlsAreSuspended
            ? PlayerControlMask(rawValue: 0)
            : trainingPlayerControlMask(
                galleryWasTriggered:
                    trainingGalleryBarrierState?.wasTriggered == true,
                controlsWereRestored:
                    trainingRobotGuidebotState?
                        .controlsWereRestored == true,
                openingControls: trainingOpeningState?.enabledControls
            )
        let input = controlsAreSuspended
            ? InputSnapshot.zero
            : input.applying(currentEnabledControls)
        var playerHeadlightFeedback: TrainingOpeningFeedback?
        var playerConcussionFeedback: [TrainingOpeningFeedback] = []
        if var state = trainingOpeningState,
           state.startCourseWasPresented == true,
           shields < 50 {
            shields = 50
            state.script030Count = min(
                (state.script030Count ?? 0) + 1,
                trainingScriptActionCounterMaximum
            )
            trainingOpeningState = state
        }
        if input.togglesHeadlight {
            playerHeadlightIsOn.toggle()
            playerHeadlightFeedback = TrainingOpeningFeedback(
                hudMessages: [
                    playerHeadlightIsOn
                        ? "Headlight turned on."
                        : "Headlight turned off.",
                ],
                voiceSourceName: "",
                voicePrecedesHUDMessages: false,
                soundSourceName: "Headlight1",
                soundEventVolume: 1
            )
        }
        let cameraMonitorWasUsedAtFrameStart =
            trainingCameraMonitorState?.wasUsed == true
        var guidebotReturnWasRequestedThisFrame = false
        var guidebotActiveGoalFeedback: TrainingOpeningFeedback?
        var guidebotReleaseFeedback: TrainingOpeningFeedback?
        var cameraMonitorWasUsedThisFrame = false
        if input.usesInventory,
           var state = trainingCameraMonitorState,
           state.isHeld,
           !state.wasUsed,
           let chain = level.trainingCameraMonitorChain {
            // Preserve the reached inventory item's typed effect before the
            // one-use callback removes its backing object.
            state.isHeld = false
            state.wasUsed = true
            state.popupRemaining = chain.popupDuration
            state.completionTimerRemaining =
                chain.completionTimerDuration
            trainingCameraMonitorState = state
            cameraMonitorWasUsedThisFrame = true
            level.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &level,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if input.deploysTrainingGuidebot {
            if trainingGuidebotReleaseCommandIsAvailable {
                guidebotReleaseFeedback = releaseTrainingGuidebot(
                    from: object,
                    playerVelocity: velocity,
                    gameTime: systemsGameTime
                )
            } else if cameraMonitorWasUsedAtFrameStart,
               trainingRobotGuidebotState?.guidebotIsDeployed == true {
                guidebotReturnWasRequestedThisFrame =
                    requestTrainingGuidebotReturn(to: object)
            } else {
                deployTrainingGuidebot(
                    from: object,
                    playerVelocity: velocity,
                    gameTime: systemsGameTime
                )
            }
        }
        if input.requestsTrainingGuidebotActiveGoal {
            guidebotActiveGoalFeedback =
                requestTrainingGuidebotActiveGoal(
                    at: systemsGameTime
                )
        }
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        guard case let .room(startRoom) = object.location else {
            preconditionFailure("The Slice 10 player simulation is indoor.")
        }
        let combatResult = advanceTrainingCombat(
            input: input,
            object: object,
            ship: ship,
            startRoom: startRoom,
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            playerConcussionFeedback: &playerConcussionFeedback
        )
        let followBotTimer11StartedThisFrame =
            combatResult.followBotTimer11StartedThisFrame
        let destroyBot2PathStartedThisFrame =
            combatResult.destroyBot2PathStartedThisFrame
        let destructionTimer12StartedThisFrame =
            combatResult.destructionTimer12StartedThisFrame
        let playerFlareFeedback = input.firesPlayerFlare
            ? firePlayerYellowFlare(
                from: object,
                roomSourceIndex: startRoom,
                systemsFrameDuration: systemsFrameDuration,
                systemsGameTime: systemsGameTime
            )
            : nil
        updatePlayerRearView(
            input: input,
            systemsGameTime: systemsGameTime
        )
        var guidebotEnteredShipThisFrame = false
        var orientation = object.orientation
        if input.directLookPitchRadians != 0 || input.directLookYawRadians != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: sourceFixedAngleRadians(
                        input.directLookPitchRadians
                    ),
                    yaw: sourceFixedAngleRadians(
                        input.directLookYawRadians
                    ),
                    roll: 0
                )
            )
        }
        let linearThrustOrientation = orientation
        var forwardControl = input.forward
        if input.afterburner > 0 {
            if afterburnerFuel > 0 {
                afterburnerIsActive = true
                forwardControl = sourceAfterburnerForwardControl(
                    afterburner: input.afterburner,
                    fuel: afterburnerFuel
                )
                afterburnerFuel -= systemsFrameDuration
                if afterburnerFuel < 0 {
                    afterburnerFuel = 0
                }
            } else {
                afterburnerIsActive = false
            }
        } else {
            afterburnerIsActive = false
            if afterburnerFuel < 5, energy > 5 {
                afterburnerFuel += systemsFrameDuration
                if afterburnerFuel > 5 {
                    afterburnerFuel = 5
                }
                energy -= systemsFrameDuration
            }
        }
        let force = Vector3(
            x: ship.physics.fullThrust * (
                linearThrustOrientation.forward.x * forwardControl
                    + linearThrustOrientation.up.x * input.vertical
                    + linearThrustOrientation.right.x * input.sideways
            ),
            y: ship.physics.fullThrust * (
                linearThrustOrientation.forward.y * forwardControl
                    + linearThrustOrientation.up.y * input.vertical
                    + linearThrustOrientation.right.y * input.sideways
            ),
            z: ship.physics.fullThrust * (
                linearThrustOrientation.forward.z * forwardControl
                    + linearThrustOrientation.up.z * input.vertical
                    + linearThrustOrientation.right.z * input.sideways
            )
        )
        let view = defaultPlayerView(in: level)
        var position = object.position
        var roomSourceIndex = startRoom
        var trainingForwardGoalWasReachedThisFrame = false
        var trainingStartGoalWasReachedThisFrame = false
        var trainingStartCourseWasReachedThisFrame = false
        var trainingFinishCourseWasReachedThisFrame = false
        var trainingLeftGoalWasReachedThisFrame = false
        var trainingDownGoalWasReachedThisFrame = false
        var trainingGalleryWasCrossedThisFrame = false
        var trainingKillbotEntryWasCrossedThisFrame = false
        var trainingFinalRoomEntryWasCrossedThisFrame = false
        var trainingCameraMonitorWasHitThisFrame = false
        var trainingInvulnerabilityPickupWasHitThisFrame = false
        var trainingCloakPickupWasHitThisFrame = false
        var trainingFinalGoalWasHitThisFrame = false
        if ship.physics.behaviors.contains(.wiggle) {
            if sqrt(dot(force, force)) < 0.1 {
                wiggleFalloff -= systemsFrameDuration / 2
            } else {
                wiggleFalloff += systemsFrameDuration / 2
            }
            wiggleFalloff = max(0, min(1, wiggleFalloff))
            let scale = max(0.1, 1 - wiggleFalloff)
            let wiggle = ship.physics.wiggleAmplitude * scale * (
                sourceFixedSine(
                    gameTime: systemsGameTime,
                    wigglesPerSecond: ship.physics.wigglesPerSecond
                )
                    - sourceFixedSine(
                        gameTime: systemsGameTime - systemsFrameDuration,
                        wigglesPerSecond: ship.physics.wigglesPerSecond
                    )
            )
            let traceStart = position
            let trace = traceIndoorMovement(
                in: level,
                startRoom: roomSourceIndex,
                start: position,
                end: position + linearThrustOrientation.up * wiggle,
                radius: view.collisionRadius
            )
            trainingCameraMonitorWasHitThisFrame =
                trainingCameraMonitorWasHitThisFrame
                || trainingCameraMonitorPickupWasHit(
                    in: level,
                    state: trainingCameraMonitorState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingInvulnerabilityPickupWasHitThisFrame =
                trainingInvulnerabilityPickupWasHitThisFrame
                || trainingInvulnerabilityPickupWasHit(
                    in: level,
                    state: trainingInvulnerabilityPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingCloakPickupWasHitThisFrame =
                trainingCloakPickupWasHitThisFrame
                || trainingCloakPickupWasHit(
                    in: level,
                    state: trainingCloakPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingFinalGoalWasHitThisFrame =
                trainingFinalGoalWasHitThisFrame
                || trainingFinalGoalWasHit(
                    in: level,
                    state: trainingFinalGoalState,
                    finalBotsState: trainingFinalBotsCompletionState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingGalleryWasCrossedThisFrame =
                trainingGalleryWasCrossedThisFrame
                || trainingGalleryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingKillbotEntryWasCrossedThisFrame =
                trainingKillbotEntryWasCrossedThisFrame
                || trainingKillbotEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingFinalRoomEntryWasCrossedThisFrame =
                trainingFinalRoomEntryWasCrossedThisFrame
                || trainingFinalRoomEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            if let lesson = level.trainingOpeningLesson {
                trainingForwardGoalWasReachedThisFrame =
                    trainingForwardGoalWasReached(
                        in: level,
                        lesson: lesson,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
                trainingStartGoalWasReachedThisFrame =
                    trainingStartGoalWasReached(
                        in: level,
                        lesson: lesson,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
                if let startCourse = lesson.startCourse {
                    trainingStartCourseWasReachedThisFrame =
                        trainingStartCourseWasReached(
                            in: level,
                            lesson: startCourse,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
                if let finishCourse = lesson.finishCourse {
                    trainingFinishCourseWasReachedThisFrame =
                        trainingFinishCourseWasReached(
                            in: level,
                            lesson: finishCourse,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
                if let returnRight = lesson.returnRight {
                    trainingLeftGoalWasReachedThisFrame =
                        trainingLeftGoalWasReached(
                            in: level,
                            lesson: returnRight,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
                if trainingOpeningState?.downGoalWasReached != true
                    || (
                        trainingOpeningState?
                            .repeatReturnDownWasPresented != true
                        && lesson.repeatReturnDown != nil
                    ),
                   let returnDown = lesson.returnDown {
                    trainingDownGoalWasReachedThisFrame =
                        trainingDownGoalWasReached(
                            in: level,
                            lesson: returnDown,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
            }
            if case .noHit = trace.outcome {
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
            }
        }
        advanceIndoorPlayerRotation(
            object: &object,
            binding: binding,
            orientation: &orientation,
            input: input,
            ship: ship,
            forwardControl: forwardControl,
            systemsFrameDuration: systemsFrameDuration
        )

        var remainingDuration = systemsFrameDuration
        var responseForce = force
        var wallContact: IndoorWallContact?
        var collisionCount = 0
        while remainingDuration > 0 && collisionCount < 9 {
            let integrated = analyticLinearMotion(
                position: position,
                velocity: velocity,
                force: responseForce,
                mass: ship.physics.mass,
                drag: ship.physics.drag,
                duration: remainingDuration
            )
            let traceStart = position
            let trace = traceIndoorMovement(
                in: level,
                startRoom: roomSourceIndex,
                start: position,
                end: integrated.position,
                radius: view.collisionRadius
            )
            trainingCameraMonitorWasHitThisFrame =
                trainingCameraMonitorWasHitThisFrame
                || trainingCameraMonitorPickupWasHit(
                    in: level,
                    state: trainingCameraMonitorState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingInvulnerabilityPickupWasHitThisFrame =
                trainingInvulnerabilityPickupWasHitThisFrame
                || trainingInvulnerabilityPickupWasHit(
                    in: level,
                    state: trainingInvulnerabilityPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingCloakPickupWasHitThisFrame =
                trainingCloakPickupWasHitThisFrame
                || trainingCloakPickupWasHit(
                    in: level,
                    state: trainingCloakPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingFinalGoalWasHitThisFrame =
                trainingFinalGoalWasHitThisFrame
                || trainingFinalGoalWasHit(
                    in: level,
                    state: trainingFinalGoalState,
                    finalBotsState: trainingFinalBotsCompletionState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingGalleryWasCrossedThisFrame =
                trainingGalleryWasCrossedThisFrame
                || trainingGalleryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingKillbotEntryWasCrossedThisFrame =
                trainingKillbotEntryWasCrossedThisFrame
                || trainingKillbotEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingFinalRoomEntryWasCrossedThisFrame =
                trainingFinalRoomEntryWasCrossedThisFrame
                || trainingFinalRoomEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            if !trainingForwardGoalWasReachedThisFrame,
               let lesson = level.trainingOpeningLesson {
                trainingForwardGoalWasReachedThisFrame =
                    trainingForwardGoalWasReached(
                        in: level,
                        lesson: lesson,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingStartGoalWasReachedThisFrame,
               let lesson = level.trainingOpeningLesson {
                trainingStartGoalWasReachedThisFrame =
                    trainingStartGoalWasReached(
                        in: level,
                        lesson: lesson,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingStartCourseWasReachedThisFrame,
               let startCourse =
                    level.trainingOpeningLesson?.startCourse {
                trainingStartCourseWasReachedThisFrame =
                    trainingStartCourseWasReached(
                        in: level,
                        lesson: startCourse,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingFinishCourseWasReachedThisFrame,
               let finishCourse =
                    level.trainingOpeningLesson?.finishCourse {
                trainingFinishCourseWasReachedThisFrame =
                    trainingFinishCourseWasReached(
                        in: level,
                        lesson: finishCourse,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingLeftGoalWasReachedThisFrame,
               let returnRight = level.trainingOpeningLesson?.returnRight {
                trainingLeftGoalWasReachedThisFrame =
                    trainingLeftGoalWasReached(
                        in: level,
                        lesson: returnRight,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingDownGoalWasReachedThisFrame,
               (
                   trainingOpeningState?.downGoalWasReached != true
                    || (
                        trainingOpeningState?
                            .repeatReturnDownWasPresented != true
                        && level.trainingOpeningLesson?
                            .repeatReturnDown != nil
                    )
               ),
               let returnDown = level.trainingOpeningLesson?.returnDown {
                trainingDownGoalWasReachedThisFrame =
                    trainingDownGoalWasReached(
                        in: level,
                        lesson: returnDown,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            guard case let .wallHit(contact) = trace.outcome else {
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
                velocity = integrated.velocity
                remainingDuration = 0
                break
            }

            wallContact = wallContact ?? contact
            let attemptedDistance = vectorDistance(position, integrated.position)
            let priorRemainingDuration = remainingDuration
            remainingDuration = attemptedDistance > 0
                ? priorRemainingDuration
                    * ((attemptedDistance - contact.distance) / attemptedDistance)
                : 0
            let movedTime = priorRemainingDuration - remainingDuration
            if movedTime > 0.0001 {
                velocity = Vector3(
                    x: (trace.finalPosition.x - position.x) / movedTime,
                    y: (trace.finalPosition.y - position.y) / movedTime,
                    z: (trace.finalPosition.z - position.z) / movedTime
                )
            }
            position = trace.finalPosition
            roomSourceIndex = trace.containingRoomSourceIndex

            let normalVelocity = dot(contact.normal, velocity)
            if surfacePhysicsBehavior(for: contact, in: level) == .forceField {
                velocity = velocity + contact.normal * (-4 * normalVelocity)
            } else {
                let speedBeforeResponse = sqrt(dot(velocity, velocity))
                let normalForce = dot(contact.normal, responseForce)
                responseForce = responseForce
                    + contact.normal * (-1.001 * normalForce)
                velocity = velocity
                    + contact.normal * (-1.001 * normalVelocity)
                if remainingDuration == priorRemainingDuration {
                    velocity = velocity + contact.normal
                }
                let projectedSpeed = sqrt(dot(velocity, velocity))
                if projectedSpeed > 0 {
                    velocity = velocity / projectedSpeed
                        * ((projectedSpeed + speedBeforeResponse) / 2)
                }
            }
            collisionCount += 1
        }
        if remainingDuration > 0 {
            velocity = .zero
        }
        let movedPlayerIndex = level.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        level.objects[movedPlayerIndex].position = position
        level.objects[movedPlayerIndex].location = .room(roomSourceIndex)
        let playerFastHeadlight = playerHeadlightIsOn
            ? fastPlayerHeadlight(from: level.objects[movedPlayerIndex])
            : nil
        advancePlayerAndGuidebotYellowFlares(
            duration: systemsFrameDuration,
            gameTime: systemsGameTime
        )
        let guidebotFlareFeedback = advanceTrainingGuidebotTiming(
            duration: systemsFrameDuration,
            gameTime: systemsGameTime
        )
        let guidebotAdvanceEvent = advanceTrainingGuidebot(
            duration: systemsFrameDuration,
            player: level.objects[movedPlayerIndex],
            playerRadius: ship.presentationSize * 0.8
        )
        guidebotEnteredShipThisFrame =
            guidebotAdvanceEvent == .enteredShip
        advanceTrainingFollowBot(duration: systemsFrameDuration)
        if !destroyBot2PathStartedThisFrame {
            advanceTrainingMovingTarget(duration: systemsFrameDuration)
        }

        var trainingOpeningFeedback: [TrainingOpeningFeedback] = []
        if let playerHeadlightFeedback {
            trainingOpeningFeedback.append(playerHeadlightFeedback)
        }
        if let guidebotReleaseFeedback {
            trainingOpeningFeedback.append(guidebotReleaseFeedback)
        }
        if let guidebotActiveGoalFeedback {
            trainingOpeningFeedback.append(guidebotActiveGoalFeedback)
        }
        trainingOpeningFeedback.append(contentsOf: playerConcussionFeedback)
        if let playerFlareFeedback {
            trainingOpeningFeedback.append(playerFlareFeedback)
        }
        if let guidebotFlareFeedback {
            trainingOpeningFeedback.append(guidebotFlareFeedback)
        }
        if guidebotAdvanceEvent == .reachedActiveGoal,
           let soundSourceName =
                level.trainingCameraMonitorChain?.returnToShip?
                    .returnSoundSourceName {
            trainingOpeningFeedback.append(
                trainingGuidebotFeedback(
                    "GB: I am at the goal, coming back to get you.",
                    requestedSoundSourceName: soundSourceName,
                    at: systemsGameTime
                )
            )
        }
        if guidebotAdvanceEvent == .returnedToPlayer,
           let greeting = completeTrainingGuidebotReturn(
               at: systemsGameTime
           ) {
            trainingOpeningFeedback.append(greeting)
        }
        advanceTrainingDodgeAndManeuverLesson(
            object: object,
            view: view,
            movedPlayerIndex: movedPlayerIndex,
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            followBotTimer11StartedThisFrame:
                followBotTimer11StartedThisFrame,
            trainingOpeningFeedback: &trainingOpeningFeedback
        )
        var trainingLastRoomWasTriggeredThisFrame = false
        var trainingFinalBotsWasTriggeredThisFrame = false
        if trainingFinalGoalWasHitThisFrame,
           var state = trainingFinalGoalState,
           !state.endLevelWasRequested {
            // TrainingMission.cpp Script 057 calls aEndLevel before it
            // increments ScriptActionCtr_057.
            state.endLevelWasRequested = true
            state.scriptActionCounter += 1
            trainingFinalGoalState = state
            trainingPostLevelResult = makeTrainingPostLevelResult(
                elapsedTime: systemsGameTime
            )
            trainingSessionOutcome = .awaitingResultAcknowledgement
        }
        if trainingInvulnerabilityPickupWasHitThisFrame,
            var state = trainingInvulnerabilityPickupState,
            let chain = level.trainingInvulnerabilityPickupChain
        {
            if !state.scriptWasTriggered {
                state.scriptWasTriggered = true
            }
            if state.remainingDuration == nil {
                state.wasConsumed = true
                state.remainingDuration = chain.duration
                level.objects.removeAll {
                    $0.handle == chain.pickupObjectHandle
                }
                setObjectPresentationVisibility(
                    in: &level,
                    handle: chain.pickupObjectHandle,
                    isVisible: false
                )
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [chain.activatedMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName:
                            chain.activatedSoundSourceName
                    ))
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName: chain.pickupSoundSourceName
                    ))
            }
            trainingInvulnerabilityPickupState = state
        }
        if trainingCloakPickupWasHitThisFrame,
            var state = trainingCloakPickupState,
            let chain = level.trainingCloakPickupChain
        {
            if !state.scriptWasTriggered {
                state.scriptWasTriggered = true
            }
            if !state.wasConsumed {
                state.wasConsumed = true
                state.phase = .fadingOut
                state.phaseRemaining = chain.fadeDuration
                level.objects.removeAll {
                    $0.handle == chain.pickupObjectHandle
                }
                setObjectPresentationVisibility(
                    in: &level,
                    handle: chain.pickupObjectHandle,
                    isVisible: false
                )
                trainingOpeningFeedback.append(.init(
                    hudMessages: [chain.activatedMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: chain.activatedSoundSourceName
                ))
                trainingOpeningFeedback.append(.init(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: chain.pickupSoundSourceName
                ))
            }
            trainingCloakPickupState = state
        }
        if var state = trainingLastRoomState,
            !state.wasTriggered,
            trainingRASBot1DeathState?.wasDestroyed == true,
            trainingRASBot2DeathState?.wasDestroyed == true,
            trainingRASBot3DeathState?.wasDestroyed == true,
            trainingRASBot4DeathState?.wasDestroyed == true,
            trainingInvulnerabilityPickupState?.scriptWasTriggered == true,
            trainingCloakPickupState?.scriptWasTriggered == true,
            let chain = level.trainingLastRoomChain
        {
            state.wasTriggered = true
            state.markerLightDistance = chain.openMarkerLightDistance
            state.timerRemaining = chain.timerDuration
            trainingLastRoomState = state
            trainingLastRoomWasTriggeredThisFrame = true
            openTrainingLastRoomBarrier(in: &level)
        }
        if var state = trainingFinalBotsCompletionState,
            !state.wasTriggered,
            trainingLastBot1DeathState?.wasDestroyed == true,
            trainingLastBot2DeathState?.wasDestroyed == true,
            trainingLastBot3DeathState?.wasDestroyed == true,
            trainingLastBot4DeathState?.wasDestroyed == true,
            trainingLastBot5DeathState?.wasDestroyed == true,
            let chain = level.trainingFinalBotsCompletionChain
        {
            state.wasTriggered = true
            state.markerLightDistance =
                chain.openMarkerLightDistance
            state.timerRemaining = chain.timerDuration
            trainingFinalBotsCompletionState = state
            trainingFinalBotsWasTriggeredThisFrame = true
            openTrainingFinalBotsBarrier(in: &level)
        }
        if guidebotReturnWasRequestedThisFrame,
            let chain = level.trainingCameraMonitorChain?.returnToShip
        {
            trainingOpeningFeedback.append(
                trainingGuidebotFeedback(
                    chain.returnMessage,
                    requestedSoundSourceName:
                        chain.returnSoundSourceName,
                    at: systemsGameTime
                )
            )
        }
        if guidebotEnteredShipThisFrame,
           let chain = level.trainingCameraMonitorChain?.returnToShip {
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.arrivalMessage],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ))
            if var cameraState = trainingCameraMonitorState,
               cameraState.wasUsed,
               !cameraState.script058WasPresented {
                cameraState.returnMarkerLightDistance =
                    chain.openMarkerLightDistance
                cameraState.script058WasPresented = true
                trainingCameraMonitorState = cameraState
                openTrainingGuidebotReturnBarrier(in: &level)
                trainingOpeningFeedback.append(.init(
                    hudMessages: [chain.successMessage],
                    voiceSourceName: chain.successVoiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
            }
            if var guidebotState = trainingRobotGuidebotState {
                guidebotState.arrivalFeedbackWasPresented = true
                trainingRobotGuidebotState = guidebotState
            }
        }
        if var state = trainingCameraMonitorState,
           !state.isHeld,
           !state.wasUsed,
           let chain = level.trainingCameraMonitorChain,
           trainingCameraMonitorWasHitThisFrame {
            state.isHeld = true
            trainingCameraMonitorState = state
            completeTrainingCameraMonitorLocateGoal(
                in: &level,
                pickupObjectHandle: chain.pickupObjectHandle
            )
            setObjectPresentationVisibility(
                in: &level,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.pickupMessage],
                voiceSourceName: chain.pickupVoiceSourceName,
                voicePrecedesHUDMessages: true,
                soundSourceName: chain.pickupSoundSourceName
            ))
        }
        if cameraMonitorWasUsedThisFrame,
           let chain = level.trainingCameraMonitorChain {
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.useMessage],
                voiceSourceName: chain.useVoiceSourceName,
                voicePrecedesHUDMessages: true
            ))
        }
        if var galleryState = trainingGalleryBarrierState,
           !galleryState.wasTriggered,
           trainingGalleryWasCrossedThisFrame,
           let barrier = level.trainingGalleryBarrier {
            trainingOpeningFeedback.append(.init(
                hudMessages: [
                    barrier.successMessage,
                    barrier.guidebotInstruction,
                ],
                voiceSourceName: barrier.voiceSourceName,
                voicePrecedesHUDMessages: true
            ))
            galleryState.markerLightDistance = 0
            closeTrainingGalleryBarrier(in: &level)
            if var robotState = trainingRobotGuidebotState {
                robotState.controlsWereRestored = false
                trainingRobotGuidebotState = robotState
            }
            galleryState.wasTriggered = true
            trainingGalleryBarrierState = galleryState
        }
        if var state = trainingKillbotEntryState,
           !state.wasTriggered,
           trainingKillbotEntryWasCrossedThisFrame,
           let returnChain =
                level.trainingCameraMonitorChain?.returnToShip,
           let chain = returnChain.killbotEntry {
            state.wasTriggered = true
            state.followupTimerRemaining = chain.followupDelay
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.entryMessage],
                voiceSourceName: chain.entryVoiceSourceName,
                voicePrecedesHUDMessages: false
            ))
            closeTrainingKillbotEntryBarrier(in: &level)
            trainingKillbotEntryState = state
        }
        if var state = trainingFinalRoomEntryState,
           !state.wasTriggered,
           trainingLastRoomState?.wasTriggered == true,
           trainingFinalRoomEntryWasCrossedThisFrame,
           let chain = level.trainingFinalRoomEntryChain
        {
            trainingLastRoomState?.markerLightDistance = 0
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.successMessage],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ))
            closeTrainingLastRoomBarrier(in: &level)
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.instructionMessage],
                voiceSourceName: chain.voiceSourceName,
                voicePrecedesHUDMessages: true
            ))
            state.wasTriggered = true
            trainingFinalRoomEntryState = state
        }
        if var state = trainingInvulnerabilityPickupState,
            var remaining = state.remainingDuration,
            let chain = level.trainingInvulnerabilityPickupChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                state.remainingDuration = nil
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [chain.expiredMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName: chain.expiredSoundSourceName
                    ))
            } else {
                state.remainingDuration = remaining
            }
            trainingInvulnerabilityPickupState = state
        }
        if var state = trainingCloakPickupState,
            let phase = state.phase,
            var remaining = state.phaseRemaining,
            let chain = level.trainingCloakPickupChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                switch phase {
                case .fadingOut:
                    state.phase = .cloaked
                    state.phaseRemaining = chain.cloakDuration
                case .cloaked:
                    state.phase = .fadingIn
                    state.phaseRemaining = chain.fadeDuration
                    trainingOpeningFeedback.append(.init(
                        hudMessages: [chain.expiredMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName: chain.expiredSoundSourceName
                    ))
                case .fadingIn:
                    state.phase = nil
                    state.phaseRemaining = nil
                }
            } else {
                state.phaseRemaining = remaining
            }
            trainingCloakPickupState = state
        }
        if var state = trainingLastRoomState,
            !trainingLastRoomWasTriggeredThisFrame,
            var remaining = state.timerRemaining,
            let chain = level.trainingLastRoomChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                state.timerRemaining = nil
                if !state.wasPresented {
                    state.wasPresented = true
                    trainingOpeningFeedback.append(.init(
                        hudMessages: chain.completionMessages,
                        voiceSourceName:
                            chain.completionVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                }
            } else {
                state.timerRemaining = remaining
            }
            trainingLastRoomState = state
        }
        if var state = trainingFinalBotsCompletionState,
            !trainingFinalBotsWasTriggeredThisFrame,
            var remaining = state.timerRemaining,
            let chain = level.trainingFinalBotsCompletionChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                state.timerRemaining = nil
                if !state.wasPresented {
                    state.wasPresented = true
                    trainingOpeningFeedback.append(.init(
                        hudMessages: [chain.completionMessage],
                        voiceSourceName:
                            chain.completionVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                }
            } else {
                state.timerRemaining = remaining
            }
            trainingFinalBotsCompletionState = state
        }
        if var state = trainingRobotGuidebotState,
            let chain = level.trainingRobotGuidebotChain
        {
            if !state.guidebotContinuationWasPresented,
               state.guidebotIsDeployed,
                trainingGalleryBarrierState?.wasTriggered == true
            {
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [chain.deployedGuidebotMessage],
                    voiceSourceName:
                        chain.deployedGuidebotVoiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
                state.guidebotContinuationWasPresented = true
                state.controlsWereRestored = true
            }
            if var timer = state.destructionTimerRemaining,
               !state.destructionFeedbackWasPresented {
                if !destructionTimer12StartedThisFrame {
                    timer -= systemsFrameDuration
                }
                if timer <= 0.000_001 {
                    trainingOpeningFeedback.append(.init(
                        hudMessages: [
                            chain.destructionMessage,
                            chain.exitInstruction,
                        ],
                        voiceSourceName:
                            chain.destructionVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                    state.destructionFeedbackWasPresented = true
                    state.enabledControlHUDIsVisible = false
                    state.destructionTimerRemaining = nil
                } else {
                    state.destructionTimerRemaining = timer
                }
            }
            trainingRobotGuidebotState = state
        }
        advanceTrainingOpeningLesson(
            systemsFrameDuration: systemsFrameDuration,
            trainingForwardGoalWasReachedThisFrame:
                trainingForwardGoalWasReachedThisFrame,
            trainingStartGoalWasReachedThisFrame:
                trainingStartGoalWasReachedThisFrame,
            trainingLeftGoalWasReachedThisFrame:
                trainingLeftGoalWasReachedThisFrame,
            trainingDownGoalWasReachedThisFrame:
                trainingDownGoalWasReachedThisFrame,
            trainingStartCourseWasReachedThisFrame:
                trainingStartCourseWasReachedThisFrame,
            trainingFinishCourseWasReachedThisFrame:
                trainingFinishCourseWasReachedThisFrame,
            trainingOpeningFeedback: &trainingOpeningFeedback
        )
        if var state = trainingKillbotEntryState,
           state.wasTriggered,
           !state.followupWasPresented,
           !trainingKillbotEntryWasCrossedThisFrame,
           let chain = level.trainingCameraMonitorChain?.returnToShip?
                .killbotEntry,
           var timer = state.followupTimerRemaining {
            timer -= systemsFrameDuration
            if timer <= 0.000_001 {
                state.followupTimerRemaining = nil
                state.followupWasPresented = true
                trainingOpeningFeedback.append(.init(
                    hudMessages: [chain.followupMessage],
                    voiceSourceName: chain.followupVoiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
            } else {
                state.followupTimerRemaining = timer
            }
            trainingKillbotEntryState = state
        }

        return finalizePlayerSimulationFrame(
            at: timestamp,
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            ship: ship,
            wallContact: wallContact,
            trainingOpeningFeedback: trainingOpeningFeedback,
            playerFastHeadlight: playerFastHeadlight
        )
    }

    func acknowledgeTrainingResult() -> TrainingSessionOutcome? {
        guard trainingPostLevelResult != nil else { return nil }
        trainingSessionOutcome = .completed
        return trainingSessionOutcome
    }

    private func makeTrainingPostLevelResult(
        elapsedTime: Float
    ) -> TrainingPostLevelResult {
        let enemyKills = [
            trainingRobotGuidebotState?.robotWasDestroyed == true,
            trainingRASBot1DeathState?.wasDestroyed == true,
            trainingRASBot2DeathState?.wasDestroyed == true,
            trainingRASBot3DeathState?.wasDestroyed == true,
            trainingRASBot4DeathState?.wasDestroyed == true,
            trainingLastBot1DeathState?.wasDestroyed == true,
            trainingLastBot2DeathState?.wasDestroyed == true,
            trainingLastBot3DeathState?.wasDestroyed == true,
            trainingLastBot4DeathState?.wasDestroyed == true,
            trainingLastBot5DeathState?.wasDestroyed == true,
        ].count(where: { $0 })
        return TrainingPostLevelResult(
            title: "Mission Successful",
            levelName: level.metadata.name,
            difficulty: .rookie,
            score:
                enemyKills
                * TrainingRobotCombatDefinition.stockTrainingScore,
            elapsedTime: elapsedTime,
            enemyKills: enemyKills,
            // Player damage, death, and restore ownership are later Phase 5
            // islands. The current normal Training path retains its source
            // initial ratings and has no admitted death or restore transition.
            shields: shields,
            energy: energy,
            deaths: 0,
            restores: 0,
            // Training's two camera goals do not carry LGF_TELCOM_LISTS, so
            // SinglePlayerPostLevelResults presents no objective rows.
            objectives: []
        )
    }

    func stopTime(at timestamp: Double) {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        if pauseDepth == 0 {
            pauseTimestamp = timestamp
        }
        pauseDepth += 1
    }

    func setIndoorAutoLevelMode(_ mode: IndoorAutoLevelMode) {
        indoorAutoLevelMode = mode
    }

    func startTime(at timestamp: Double) {
        precondition(timestamp.isFinite)
        guard pauseDepth > 0 else { return }
        pauseDepth -= 1
        if pauseDepth == 0 {
            let pausedAt = pauseTimestamp!
            precondition(timestamp >= pausedAt)
            lastTimestamp += timestamp - pausedAt
            pauseTimestamp = nil
        }
    }
}

private extension PlayerSimulation {
    private func advanceIndoorPlayerRotation(
        object: inout PlacedObject,
        binding: DefaultPlayerBinding,
        orientation: inout Matrix3,
        input: InputSnapshot,
        ship: CanonicalShipDefinition,
        forwardControl: Float,
        systemsFrameDuration: Float
    ) {
        if turnrollFixedAngle != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: 0,
                    yaw: 0,
                    roll: sourceFixedAngleUnits(-turnrollFixedAngle)
                )
            )
        }

        var rotationalThrust = Vector3(
            x: ship.physics.fullRotationalThrust
                * max(-0.75, min(0.75, input.pitch)),
            y: ship.physics.fullRotationalThrust * input.yaw,
            z: ship.physics.fullRotationalThrust * input.roll
        )
        if forwardControl != 0 || input.sideways != 0 || input.vertical != 0
            || rotationalThrust != .zero {
            lastThrustTime = gameTime
        }
        rotationalThrust = sourceIndoorAutoLevelThrust(
            rotationalThrust,
            orientation: orientation,
            storedOrientation: object.orientation,
            fullRotationalThrust: ship.physics.fullRotationalThrust,
            turnrollFixedAngle: turnrollFixedAngle,
            mode: indoorAutoLevelMode,
            gameTime: gameTime,
            lastThrustTime: lastThrustTime
        )
        angularVelocity = analyticAngularVelocity(
            velocity: angularVelocity,
            force: rotationalThrust,
            mass: ship.physics.mass,
            drag: ship.physics.rotationalDrag,
            duration: systemsFrameDuration
        )
        orientation = sourceMatrixMultiply(
            orientation,
            sourceRotationMatrix(
                pitch: sourceFixedAngleUnits(
                    angularVelocity.x * systemsFrameDuration
                ),
                yaw: sourceFixedAngleUnits(
                    angularVelocity.y * systemsFrameDuration
                ),
                roll: sourceFixedAngleUnits(
                    angularVelocity.z * systemsFrameDuration
                )
            )
        )
        if ship.physics.behaviors.contains(.turnroll) {
            let desired = max(
                -32_000,
                min(
                    32_000,
                    -angularVelocity.y * ship.physics.turnrollRatio
                )
            )
            let maximumChange = Float(
                Int(ship.physics.maximumTurnrollRate * systemsFrameDuration)
            )
            if abs(desired - turnrollFixedAngle) > maximumChange {
                turnrollFixedAngle += desired > turnrollFixedAngle
                    ? maximumChange
                    : -maximumChange
            } else {
                turnrollFixedAngle = Float(Int(desired))
            }
        }
        if turnrollFixedAngle != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: 0,
                    yaw: 0,
                    roll: sourceFixedAngleUnits(turnrollFixedAngle)
                )
            )
        }
        orientation = sourceOrthogonalized(orientation)
        object.orientation = orientation
        let orientedPlayerIndex = level.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        level.objects[orientedPlayerIndex].orientation = orientation
    }

    private func finalizePlayerSimulationFrame(
        at timestamp: Double,
        systemsFrameDuration: Float,
        systemsGameTime: Float,
        ship: CanonicalShipDefinition,
        wallContact: IndoorWallContact?,
        trainingOpeningFeedback: [TrainingOpeningFeedback],
        playerFastHeadlight: PlayerFastHeadlightFrame?
    ) -> PlayerSimulationFrame {
        if afterburnerIsActive {
            afterburnerMagnitude += 2 * systemsFrameDuration
        } else {
            afterburnerMagnitude -= 2 * systemsFrameDuration
        }
        afterburnerMagnitude = max(0, min(1, afterburnerMagnitude))
        let projection = PerspectiveProjection(
            horizontalFieldOfViewRadians:
                PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
                * (1 + afterburnerMagnitude * 0.08),
            aspectRatio: PerspectiveProjection.sourceDefault.aspectRatio
        )

        let cameraMonitorFrame = trainingCameraMonitorFrame(
            level: level,
            state: trainingCameraMonitorState
        )
        let finalGoalFrame: TrainingFinalGoalFrame? =
            trainingFinalGoalState.flatMap { state in
            guard state.endLevelWasRequested,
                  let postLevelResult = trainingPostLevelResult else {
                return nil
            }
            return TrainingFinalGoalFrame(
                endLevelState: .succeeded,
                scriptActionCounter: state.scriptActionCounter,
                controlsAreSuspended: true,
                presentation: .init(
                    title: "Mission Successful",
                    levelName: level.metadata.name,
                    difficulty: .rookie,
                    showsHUD: false,
                    playsGameplayAudio: false,
                    showsCockpit: false,
                    showsHeadlightIndicator: false
                ),
                postLevelResult: postLevelResult
            )
        }
        if var state = trainingCameraMonitorState {
            if var remaining = state.popupRemaining {
                remaining -= systemsFrameDuration
                state.popupRemaining = remaining < 0 ? nil : remaining
            }
            if var timer = state.completionTimerRemaining {
                timer -= systemsFrameDuration
                if timer <= 0.000_001 {
                    state.completionTimerRemaining = nil
                    state.completionTimerWasConsumed = true
                } else {
                    state.completionTimerRemaining = timer
                }
            }
            trainingCameraMonitorState = state
        }

        let yellowFlareParents: [TrainingGuidebotYellowFlareState]
        let yellowFlareParticles:
            [TrainingGuidebotYellowFlareParticleState]
        let yellowFlareTimeoutExplosions:
            [TrainingGuidebotYellowFlareTimeoutExplosionState]
        let yellowFlareTimeoutSparks:
            [TrainingGuidebotYellowFlareTimeoutSparkState]
        let yellowFlareTimeoutSparkParticles:
            [TrainingGuidebotYellowFlareParticleState]
        if let playerState = playerYellowFlareState {
            yellowFlareParents = (
                (trainingRobotGuidebotState?.yellowFlares ?? [])
                    + playerState.parents
            ).sorted {
                ($0.creationOrdinal ?? 0) < ($1.creationOrdinal ?? 0)
            }
            yellowFlareParticles = (
                (trainingRobotGuidebotState?.yellowFlareParticles ?? [])
                    + playerState.parentParticles
            ).sorted {
                ($0.generationOrdinal ?? 0, $0.sourceAttemptIndex ?? 0)
                    < ($1.generationOrdinal ?? 0, $1.sourceAttemptIndex ?? 0)
            }
            yellowFlareTimeoutExplosions = (
                (trainingRobotGuidebotState?
                    .yellowFlareTimeoutExplosions ?? [])
                    + playerState.timeoutExplosions
            ).sorted {
                ($0.generationOrdinal ?? 0) < ($1.generationOrdinal ?? 0)
            }
            yellowFlareTimeoutSparks = (
                (trainingRobotGuidebotState?.yellowFlareTimeoutSparks ?? [])
                    + playerState.timeoutSparks
            ).sorted {
                ($0.generationOrdinal ?? 0, $0.sourceAttemptIndex)
                    < ($1.generationOrdinal ?? 0, $1.sourceAttemptIndex)
            }
            yellowFlareTimeoutSparkParticles = (
                (trainingRobotGuidebotState?
                    .yellowFlareTimeoutSparkParticles ?? [])
                    + playerState.timeoutSparkParticles
            ).sorted {
                ($0.generationOrdinal ?? 0, $0.sourceAttemptIndex ?? 0)
                    < ($1.generationOrdinal ?? 0, $1.sourceAttemptIndex ?? 0)
            }
        } else {
            yellowFlareParents =
                trainingRobotGuidebotState?.yellowFlares ?? []
            yellowFlareParticles =
                trainingRobotGuidebotState?.yellowFlareParticles ?? []
            yellowFlareTimeoutExplosions = trainingRobotGuidebotState?
                .yellowFlareTimeoutExplosions ?? []
            yellowFlareTimeoutSparks =
                trainingRobotGuidebotState?.yellowFlareTimeoutSparks ?? []
            yellowFlareTimeoutSparkParticles = trainingRobotGuidebotState?
                .yellowFlareTimeoutSparkParticles ?? []
        }

        frameDuration = Float(timestamp - lastTimestamp)
        lastTimestamp = timestamp
        gameTime += frameDuration
        let presentsRearView =
            finalGoalFrame == nil && playerRearViewState != nil
        let forwardPlayerView = defaultPlayerView(
            in: level,
            projection: projection
        )

        return PlayerSimulationFrame(
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            storedFrameDuration: frameDuration,
            gameTime: gameTime,
            playerView:
                presentsRearView
                    ? rearPlayerView(forwardPlayerView)
                    : forwardPlayerView,
            rearViewIsActive: presentsRearView,
            velocity: velocity,
            angularVelocity: angularVelocity,
            turnrollFixedAngle: turnrollFixedAngle,
            wallContact: wallContact,
            enabledPlayerControls:
                finalGoalFrame == nil
                    ? trainingPlayerControlMask(
                        galleryWasTriggered:
                            trainingGalleryBarrierState?
                                .wasTriggered == true,
                        controlsWereRestored:
                            trainingRobotGuidebotState?
                                .controlsWereRestored == true,
                        openingControls:
                            trainingOpeningState?.enabledControls
                    )
                    : PlayerControlMask(rawValue: 0),
            showsEnabledPlayerControls:
                finalGoalFrame == nil
                    && (
                        trainingRobotGuidebotState?
                            .enabledControlHUDIsVisible
                            ?? (trainingOpeningState != nil)
                    ),
            trainingOpeningFeedback: trainingOpeningFeedback,
            playerFastHeadlight:
                finalGoalFrame == nil ? playerFastHeadlight : nil,
            shields: shields,
            trainingDodgeMarkerLightDistance:
                trainingDodgeAttemptState?.markerLightDistance,
            trainingDodgeTurretAngles:
                trainingDodgeAttemptState?.turretAngles ?? [],
            trainingDodgeProjectiles:
                trainingDodgeAttemptState?.projectiles.map {
                    .init(
                        position: $0.position,
                        velocity: $0.velocity,
                        roomSourceIndex: $0.roomSourceIndex,
                        model: level.trainingDodgeAttempt!
                            .turret.projectileModel
                    )
                } ?? [],
            trainingPrimaryProjectiles:
                level.trainingDodgeAttempt?.maneuverFollow?
                    .destructionHandoff.map { handoff in
                        trainingRobotGuidebotState?
                            .projectiles.map {
                                .init(
                                    position: $0.position,
                                    velocity: $0.velocity,
                                    roomSourceIndex:
                                        $0.roomSourceIndex,
                                    model:
                                        handoff.projectileModel
                                )
                            } ?? []
                    } ?? [],
            playerConcussionMissiles:
                ship.playerConcussion.map { concussion in
                    playerConcussionState?.missiles.map {
                        .init(
                            roomSourceIndex: $0.roomSourceIndex,
                            position: $0.position,
                            orientation: $0.orientation,
                            velocity: $0.velocity,
                            model: concussion.model,
                            lightDistance: concussion.lightDistance,
                            lightPresentation: concussion.lightPresentation
                        )
                    } ?? []
                } ?? [],
            playerConcussionExplosions:
                ship.playerConcussion.map { concussion in
                    playerConcussionState?.explosions.map { explosion in
                        let age = concussion.explosionLifetime
                            - explosion.lifeRemaining
                        let frameIndex = min(
                            concussion.explosionFrames.count - 1,
                            max(
                                0,
                                Int(age / concussion.explosionSourceFrameTime)
                            )
                        )
                        return .init(
                            roomSourceIndex: explosion.roomSourceIndex,
                            position: explosion.position,
                            size: concussion.explosionSize,
                            texture: concussion.explosionFrames[frameIndex]
                        )
                    } ?? []
                } ?? [],
            playerConcussionSparks:
                playerConcussionState?.sparks.map {
                    .init(
                        roomSourceIndex: $0.roomSourceIndex,
                        start: $0.position,
                        end: $0.position - normalized($0.velocity) * $0.size
                    )
                } ?? [],
            trainingGuidebotYellowFlares:
                level.trainingRobotGuidebotChain?.yellowFlare.map {
                    definition in
                    yellowFlareParents.map {
                        .init(
                            roomSourceIndex: $0.roomSourceIndex,
                            position: $0.position,
                            orientation: $0.orientation,
                            velocity: $0.velocity,
                            model: definition.model,
                            collisionRadius:
                                definition.collisionRadius,
                            lifeRemaining: $0.lifeRemaining,
                            sourceLightDistance:
                                definition.lightDistance,
                            lightDistance:
                                $0.presentedLightDistance,
                            lightPresentation:
                                definition.lightPresentation
                        )
                    }
                } ?? [],
            trainingGuidebotYellowFlareParticles:
                level.trainingRobotGuidebotChain?.yellowFlare.map {
                    definition in
                    yellowFlareParticles.map {
                            .init(
                                roomSourceIndex: $0.roomSourceIndex,
                                position: $0.position,
                                size: $0.size,
                                lifeRemaining: $0.lifeRemaining,
                                lifetime: $0.lifetime,
                                sourceSize: definition.particleSize,
                                sourceLifetime:
                                    definition.particleLifetime,
                                texture:
                                    trainingGuidebotYellowFlareParticleTexture(
                                        timeout: definition.timeout,
                                        creationTime: $0.creationTime,
                                        lifetime: $0.lifetime,
                                        lifeRemaining: $0.lifeRemaining,
                                        gameTime: systemsGameTime,
                                        fallback: definition.particleTexture
                                    ),
                                opacity:
                                    trainingGuidebotYellowFlareVisualOpacity(
                                        creationTime: $0.creationTime,
                                        lifetime: $0.lifetime,
                                        lifeRemaining: $0.lifeRemaining,
                                        gameTime: systemsGameTime
                                    )
                            )
                        }
                } ?? [],
            trainingGuidebotYellowFlareTimeoutExplosions:
                level.trainingRobotGuidebotChain?.yellowFlare?.timeout.map {
                    timeout in
                    yellowFlareTimeoutExplosions.map {
                            .init(
                                roomSourceIndex: $0.roomSourceIndex,
                                position: $0.position,
                                size: $0.size,
                                lifeRemaining: $0.lifeRemaining,
                                lifetime: $0.lifetime,
                                sourceSize: timeout.explosionSize,
                                sourceLifetime:
                                    timeout.explosionLifetime,
                                texture: timeout.explosionTexture,
                                opacity:
                                    trainingGuidebotYellowFlareVisualOpacity(
                                        creationTime: $0.creationTime,
                                        lifetime: $0.lifetime,
                                        lifeRemaining: $0.lifeRemaining,
                                        gameTime: systemsGameTime
                                    )
                            )
                        }
                } ?? [],
            trainingGuidebotYellowFlareTimeoutSparks:
                level.trainingRobotGuidebotChain?.yellowFlare?.timeout.map {
                    timeout in
                    yellowFlareTimeoutSparks.map {
                            .init(
                                sourceAttemptIndex: $0.sourceAttemptIndex,
                                sourceObjectSlot: $0.sourceObjectSlot,
                                receivedControlOnCreationFrame:
                                    $0.receivedControlOnCreationFrame,
                                roomSourceIndex: $0.roomSourceIndex,
                                position: $0.position,
                                orientation: $0.orientation,
                                velocity: $0.velocity,
                                collisionRadius:
                                    timeout.childCollisionRadius,
                                lifeRemaining: $0.lifeRemaining,
                                texture:
                                    trainingGuidebotYellowFlareCarrierTexture(
                                        timeout: timeout,
                                        gameTime: systemsGameTime
                                    ),
                                sourceLightDistance:
                                    timeout.childLightDistance,
                                lightDistance:
                                    $0.presentedLightDistance,
                                lightPresentation:
                                    timeout.childLightPresentation
                            )
                        }
                } ?? [],
            trainingGuidebotYellowFlareTimeoutSparkParticles:
                level.trainingRobotGuidebotChain?.yellowFlare?.timeout.map {
                    timeout in
                    yellowFlareTimeoutSparkParticles.map {
                            .init(
                                roomSourceIndex: $0.roomSourceIndex,
                                position: $0.position,
                                size: $0.size,
                                lifeRemaining: $0.lifeRemaining,
                                lifetime: $0.lifetime,
                                sourceSize:
                                    timeout.childParticleSize,
                                sourceLifetime:
                                    timeout.childParticleLifetime,
                                texture:
                                    trainingGuidebotYellowFlareParticleTexture(
                                        timeout: timeout,
                                        creationTime: $0.creationTime,
                                        lifetime: $0.lifetime,
                                        lifeRemaining: $0.lifeRemaining,
                                        gameTime: systemsGameTime,
                                        fallback: timeout.childTexture
                                    ),
                                opacity:
                                    trainingGuidebotYellowFlareVisualOpacity(
                                        creationTime: $0.creationTime,
                                        lifetime: $0.lifetime,
                                        lifeRemaining: $0.lifeRemaining,
                                        gameTime: systemsGameTime
                                    )
                            )
                        }
                } ?? [],
            trainingFollowBot:
                trainingManeuverFollowState?.frame,
            trainingMovingTarget:
                level.trainingDodgeAttempt?.maneuverFollow?
                    .destructionHandoff.flatMap { handoff in
                        trainingManeuverFollowState?
                            .destruction?.movingTargetFrame(
                                handoff: handoff
                            )
                    },
            trainingGalleryMarkerLightDistance:
                trainingGalleryBarrierState?.markerLightDistance,
            trainingGuidebotReturnMarkerLightDistance:
                trainingKillbotEntryState?.wasTriggered == true
                    ? level.trainingCameraMonitorChain?.returnToShip?
                        .killbotEntry?.closedMarkerLightDistance
                    : trainingCameraMonitorState?
                        .returnMarkerLightDistance,
            trainingGuidebot:
                trainingRobotGuidebotState?.guidebot?.frame,
            trainingGuidebotAmbientEngineIsActive:
                trainingRobotGuidebotState.map { state in
                    state.guidebotIsDeployed
                        && !state.guidebotEnteredShip
                        && state.guidebot != nil
                        && state.guidebotMode == .ambient
                        && (state.guidebotModeTime ?? 0) > 0
                } ?? false,
            trainingCameraMonitor: cameraMonitorFrame,
            trainingInvulnerabilityRemaining:
                trainingInvulnerabilityPickupState?.remainingDuration,
            trainingCloak: trainingCloakFrame(
                state: trainingCloakPickupState,
                chain: level.trainingCloakPickupChain
            ),
            trainingLastRoomMarkerLightDistance:
                trainingLastRoomState?.markerLightDistance,
            trainingFinalBotsMarkerLightDistance:
                trainingFinalBotsCompletionState?
                    .markerLightDistance,
            trainingFinalGoal: finalGoalFrame
        )
    }

    func advanceTrainingOpeningLesson(
        systemsFrameDuration: Float,
        trainingForwardGoalWasReachedThisFrame: Bool,
        trainingStartGoalWasReachedThisFrame: Bool,
        trainingLeftGoalWasReachedThisFrame: Bool,
        trainingDownGoalWasReachedThisFrame: Bool,
        trainingStartCourseWasReachedThisFrame: Bool,
        trainingFinishCourseWasReachedThisFrame: Bool,
        trainingOpeningFeedback: inout [TrainingOpeningFeedback]
    ) {
        if var openingState = trainingOpeningState,
           let lesson = level.trainingOpeningLesson {
            if !openingState.forwardGoalWasReached,
               trainingForwardGoalWasReachedThisFrame {
                openingState.forwardGoalWasReached = true
                openingState.enabledControls.remove(.forward)
                openingState.enabledControls.insert(.reverse)
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [lesson.successMessage],
                        voiceSourceName: lesson.successVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [lesson.reverseInstruction],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                ])
            }
            if openingState.repeatForwardWasPresented == true,
               openingState.repeatForwardGoalWasPresented != true,
               trainingForwardGoalWasReachedThisFrame,
               let repeatForwardGoal = lesson.repeatForwardGoal {
                openingState.enabledControls.remove(.forward)
                openingState.enabledControls.insert(.reverse)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [repeatForwardGoal.reverseInstruction],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: repeatForwardGoal.soundLogicalName
                ))
                openingState.repeatForwardGoalWasPresented = true
            }
            if openingState.forwardGoalWasReached,
               openingState.returnGoalWasReached != true,
               trainingStartGoalWasReachedThisFrame,
               let returnLeft = lesson.returnLeft {
                openingState.enabledControls.remove(.reverse)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [returnLeft.instruction],
                    voiceSourceName: returnLeft.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ))
                openingState.enabledControls.insert(.left)
                openingState.returnGoalWasReached = true
            }
            if openingState.rightGoalWasReached != true,
               trainingLeftGoalWasReachedThisFrame,
               let returnRight = lesson.returnRight {
                openingState.enabledControls.remove(.left)
                openingState.enabledControls.insert(.right)
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [returnRight.successMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [returnRight.instruction],
                        voiceSourceName: returnRight.voiceSourceName,
                        voicePrecedesHUDMessages: true
                    ),
                ])
                openingState.rightGoalWasReached = true
            }
            if openingState.rightGoalWasReached == true,
               openingState.upGoalWasReached != true,
               trainingStartGoalWasReachedThisFrame,
               let returnUp = lesson.returnUp {
                openingState.enabledControls.remove(.right)
                openingState.enabledControls.insert(.up)
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [returnUp.successMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [returnUp.instruction],
                        voiceSourceName: returnUp.voiceSourceName,
                        voicePrecedesHUDMessages: true
                    ),
                ])
                openingState.upGoalWasReached = true
            }
            if openingState.downGoalWasReached != true,
               trainingDownGoalWasReachedThisFrame,
               let returnDown = lesson.returnDown {
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [returnDown.successMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ))
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [returnDown.instruction],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ))
                openingState.enabledControls.remove(.up)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [],
                    voiceSourceName: returnDown.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ))
                openingState.enabledControls.insert(.down)
                openingState.downGoalWasReached = true
            }
            if openingState.downGoalWasReached == true,
               openingState.repeatForwardWasPresented != true,
               trainingStartGoalWasReachedThisFrame,
               let repeatForward = lesson.repeatForward {
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [repeatForward.successMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [repeatForward.repeatMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [repeatForward.forwardInstruction],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [],
                        voiceSourceName: repeatForward.voiceSourceName,
                        voicePrecedesHUDMessages: false
                    ),
                ])
                openingState.enabledControls.remove(.down)
                openingState.enabledControls.insert(.forward)
                openingState.repeatForwardWasPresented = true
            }
            if openingState.repeatReturnLeftWasPresented != true,
               openingState.repeatForwardGoalWasPresented == true,
               trainingStartGoalWasReachedThisFrame,
               let repeatReturnLeft = lesson.repeatReturnLeft {
                openingState.enabledControls.remove(.reverse)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [repeatReturnLeft.instruction],
                    voiceSourceName: repeatReturnLeft.voiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
                openingState.enabledControls.insert(.left)
                openingState.repeatReturnLeftWasPresented = true
            }
            if openingState.repeatReturnRightWasPresented != true,
               openingState.repeatReturnLeftWasPresented == true,
               trainingLeftGoalWasReachedThisFrame,
               let repeatReturnRight = lesson.repeatReturnRight {
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [repeatReturnRight.instruction],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: repeatReturnRight.soundLogicalName
                ))
                openingState.enabledControls.remove(.left)
                openingState.enabledControls.insert(.right)
                openingState.repeatReturnRightWasPresented = true
            }
            if openingState.repeatReturnUpWasPresented != true,
               openingState.repeatReturnRightWasPresented == true,
               trainingStartGoalWasReachedThisFrame,
               let repeatReturnUp = lesson.repeatReturnUp {
                openingState.enabledControls.remove(.right)
                openingState.enabledControls.insert(.up)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [repeatReturnUp.instruction],
                    voiceSourceName: repeatReturnUp.voiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
                openingState.repeatReturnUpWasPresented = true
            }
            if openingState.repeatReturnDownWasPresented != true,
               openingState.repeatReturnUpWasPresented == true,
               trainingDownGoalWasReachedThisFrame,
               let repeatReturnDown = lesson.repeatReturnDown {
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [repeatReturnDown.instruction],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: repeatReturnDown.soundLogicalName,
                    soundEventVolume: 1
                ))
                openingState.enabledControls.remove(.up)
                openingState.enabledControls.insert(.down)
                openingState.repeatReturnDownWasPresented = true
            }
            if openingState.continueToCourseWasPresented != true,
               openingState.repeatReturnDownWasPresented == true,
               trainingStartGoalWasReachedThisFrame,
               let continueToCourse = lesson.continueToCourse {
                openTrainingContinueToCoursePortals(in: &level)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [continueToCourse.instruction],
                    voiceSourceName: continueToCourse.voiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
                openingState.continueToCourseWasPresented = true
            }
            if openingState.startCourseWasPresented != true,
               trainingStartCourseWasReachedThisFrame,
               let startCourse = lesson.startCourse {
                closeTrainingStartCoursePortal(in: &level)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [startCourse.instruction],
                    voiceSourceName: startCourse.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ))
                openingState.enabledControls.formUnion(
                    PlayerControlMask(
                        rawValue: startCourse.enabledControlMask
                    )
                )
                openingState.startCourseWasPresented = true
            }
            if openingState.finishCourseWasPresented != true,
               trainingFinishCourseWasReachedThisFrame,
               let finishCourse = lesson.finishCourse {
                openingState.enabledControls = PlayerControlMask(
                    rawValue: finishCourse.enabledControlMask
                )
                openTrainingFinishCoursePortals(in: &level)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [finishCourse.successMessage],
                    voiceSourceName: finishCourse.voiceSourceName,
                    voicePrecedesHUDMessages: false,
                    trailingHUDMessages: [finishCourse.instruction]
                ))
                openingState.finishCourseWasPresented = true
            }
            if !openingState.welcomeWasPresented {
                openingState.timerRemaining -= systemsFrameDuration
                if openingState.timerRemaining <= 0.000_001 {
                    openingState.welcomeWasPresented = true
                    trainingOpeningFeedback.append(TrainingOpeningFeedback(
                        hudMessages: [
                            lesson.welcomeMessage,
                            lesson.forwardInstruction,
                        ],
                        voiceSourceName: lesson.welcomeVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                }
            }
            trainingOpeningState = openingState
        }
    }

    func advanceTrainingDodgeAndManeuverLesson(
        object: PlacedObject,
        view: PlayerView,
        movedPlayerIndex: Int,
        systemsFrameDuration: Float,
        systemsGameTime: Float,
        followBotTimer11StartedThisFrame: Bool,
        trainingOpeningFeedback: inout [TrainingOpeningFeedback]
    ) {
        if var dodgeState = trainingDodgeAttemptState,
            let dodge = level.trainingDodgeAttempt
        {
            let triggerTimerConsumesFrame =
                dodgeState.triggerTimerRemaining != nil
            var almostDoneTimerConsumesFrame =
                dodgeState.almostDoneTimerRemaining != nil
            var successTimerConsumesFrame =
                dodgeState.successTimerRemaining != nil
            let maneuverLevelTimerConsumesFrame =
                trainingManeuverFollowState?.levelTimerRemaining
                    != nil
            let followObjectTimerConsumesFrame =
                trainingManeuverFollowState?.objectTimerRemaining
                    != nil
            let player = level.objects[movedPlayerIndex]
            let turret = level.objects.first {
                $0.handle == dodge.dodgeTurretObjectHandle
            }!

            if dodgeState.turretIsPowered,
                dodgeState.script017Count == 0,
                case .room(let turretRoom) = turret.location,
                case .room(let playerRoom) = player.location
            {
                let connectedRooms = reciprocalPortalComponent(
                    rooms: level.rooms,
                    startRoomSourceIndex: turretRoom
                )
                let targetDistance = vectorDistance(
                    turret.position,
                    player.position
                )
                let crossRoomLimit: Float =
                    dodgeState.awareness > 0 ? 720 : 450
                let targetIsEligible =
                    connectedRooms.contains(playerRoom)
                    && (playerRoom == turretRoom
                        || targetDistance <= crossRoomLimit)
                if !targetIsEligible {
                    dodgeState.seesTarget = false
                } else if systemsGameTime
                    - dodgeState.lastVisibleTargetTime > 0.35,
                    systemsGameTime
                        >= dodgeState.nextVisibilityCheckTime
                {
                    let visibility = traceIndoorMovement(
                        in: level,
                        startRoom: turretRoom,
                        start: turret.position,
                        end: player.position,
                        radius: 0
                    )
                    dodgeState.seesTarget = false
                    if case .noHit = visibility.outcome {
                        let targetDirection = normalized(
                            player.position - turret.position
                        )
                        let closingSpeed =
                            dodgeState.weaponSpeed
                            - dot(targetDirection, velocity)
                        if dodgeState.weaponSpeed > 0,
                            closingSpeed > 0
                        {
                            dodgeState.retainedTargetPosition =
                                player.position
                                + velocity
                                * (targetDistance
                                    / closingSpeed
                                    * dodge.turret
                                    .fixedLeadAccuracy)
                        } else {
                            dodgeState.retainedTargetPosition =
                                player.position
                        }
                        dodgeState.lastVisibleTargetTime =
                            systemsGameTime
                        dodgeState.seesTarget = true
                        dodgeState.awareness = max(
                            dodgeState.awareness,
                            60
                        )
                    }
                    let interval: Float =
                        dodgeState.seesTarget
                            || systemsGameTime
                                - dodgeState.lastVisibleTargetTime < 7
                        ? 0.15
                        : 2
                    let draw = nextAuthoritativeRandomValue()
                    let fraction = Float(draw) / Float(32_767)
                    let scheduled =
                        (Double(systemsGameTime)
                            + 0.9 * Double(interval))
                        + (0.2 * Double(interval)) * Double(fraction)
                    dodgeState.nextVisibilityCheckTime = Float(scheduled)
                }
                let visibleAge =
                    systemsGameTime
                    - dodgeState.lastVisibleTargetTime
                if let retainedTarget =
                    dodgeState.retainedTargetPosition,
                    dodgeState.awareness > 15,
                    visibleAge < 4
                {
                    for jointIndex in dodge.turret.joints.indices {
                        let joint = dodge.turret.joints[jointIndex]
                        let still =
                            dodgeState.turretAngles[jointIndex]
                        let scaledRate =
                            Float(joint.rotationsPerSecond) * Float(0.7)
                        let right = constrainedTrainingTurretAngle(
                            still
                                - systemsFrameDuration
                                * scaledRate,
                            fieldOfView: joint.fieldOfView,
                            movesRight: true
                        )
                        let left = constrainedTrainingTurretAngle(
                            still
                                + systemsFrameDuration
                                * scaledRate,
                            fieldOfView: joint.fieldOfView,
                            movesRight: false
                        )
                        var candidates = dodgeState.turretAngles
                        candidates[jointIndex] = still
                        let stillDot = trainingDodgeAimDot(
                            level: level,
                            dodge: dodge,
                            turret: turret,
                            angles: candidates,
                            target: retainedTarget
                        )
                        candidates[jointIndex] = right
                        let rightDot = trainingDodgeAimDot(
                            level: level,
                            dodge: dodge,
                            turret: turret,
                            angles: candidates,
                            target: retainedTarget
                        )
                        candidates[jointIndex] = left
                        let leftDot = trainingDodgeAimDot(
                            level: level,
                            dodge: dodge,
                            turret: turret,
                            angles: candidates,
                            target: retainedTarget
                        )
                        var bestAngle = still
                        var bestDot = stillDot
                        if rightDot > bestDot {
                            bestAngle = right
                            bestDot = rightDot
                        }
                        if leftDot > bestDot {
                            bestAngle = left
                        }
                        dodgeState.turretAngles[jointIndex] =
                            bestAngle
                        dodgeState.turretDirections[jointIndex] =
                            rightDot > leftDot ? 1 : 2
                    }

                    let aim = trainingDodgeGunTransform(
                        level: level,
                        dodge: dodge,
                        turret: turret,
                        angles: dodgeState.turretAngles,
                        restPosition: dodge.turret.aimingGunpoint
                    )
                    let aimDirection = normalized(
                        retainedTarget - aim.position
                    )
                    if visibleAge < 2,
                        dot(aim.forward, aimDirection)
                            >= dodge.turret.fireAlignmentDot,
                        systemsGameTime >= dodgeState.nextFireTime
                    {
                        let fire = trainingDodgeGunTransform(
                            level: level,
                            dodge: dodge,
                            turret: turret,
                            angles: dodgeState.turretAngles,
                            restPosition: dodge.turret.gunpoints[
                                dodgeState.firingMaskIndex
                            ]
                        )
                        let fireDirection =
                            trainingDodgeSpreadDirection(fire.forward)
                        let muzzleTrace = traceIndoorMovement(
                            in: level,
                            startRoom: turretRoom,
                            start: turret.position,
                            end: fire.position,
                            radius: 0
                        )
                        if case .noHit = muzzleTrace.outcome {
                            dodgeState.projectiles.append(
                                .init(
                                    roomSourceIndex: turretRoom,
                                    position: fire.position,
                                    velocity:
                                        fireDirection
                                        * (dodge.turret.projectileSpeed
                                            * Float(0.75)),
                                    lifeRemaining:
                                        dodge.turret.projectileLifetime
                                ))
                            trainingOpeningFeedback.append(
                                .init(
                                    hudMessages: [],
                                    voiceSourceName: "",
                                    voicePrecedesHUDMessages: true,
                                    soundSourceName:
                                        dodge.turret.fireSoundSourceName
                                ))
                        }
                        let scheduledFireTime =
                            dodgeState.nextFireTime
                        let continuousWindow = max(
                            dodge.turret.fireWait,
                            systemsFrameDuration * 1.5
                        )
                        dodgeState.nextFireTime =
                            systemsGameTime - scheduledFireTime
                                <= continuousWindow
                            ? scheduledFireTime
                                + dodge.turret.fireWait
                            : systemsGameTime
                                + dodge.turret.fireWait
                        dodgeState.firingMaskIndex =
                            (dodgeState.firingMaskIndex + 1)
                            % dodge.turret.gunpoints.count
                        dodgeState.weaponSpeed =
                            dodge.turret.projectileSpeed
                    }
                }
            }

            var survivingProjectiles: [TrainingDodgeProjectileState] = []
            for var projectile in dodgeState.projectiles {
                let end =
                    projectile.position
                    + projectile.velocity * systemsFrameDuration
                let trace = traceIndoorMovement(
                    in: level,
                    startRoom: projectile.roomSourceIndex,
                    start: projectile.position,
                    end: end,
                    radius: dodge.turret.projectileRadius
                )
                let playerHit = segmentSphereHitFraction(
                    start: projectile.position,
                    end: end,
                    center: player.position,
                    radius:
                        dodge.turret.projectileRadius
                        + view.collisionRadius
                )
                let traceFraction =
                    vectorDistance(
                        projectile.position,
                        end
                    ) > 0
                    ? vectorDistance(
                        projectile.position,
                        trace.finalPosition
                    ) / vectorDistance(projectile.position, end)
                    : 1
                if let playerHit,
                    playerHit <= traceFraction + 0.000_1
                {
                    shields -= dodge.turret.projectileDamage
                    trainingOpeningFeedback.append(
                        .init(
                            hudMessages: [],
                            voiceSourceName: "",
                            voicePrecedesHUDMessages: true,
                            soundSourceName:
                                dodge.turret.impactSoundSourceName
                        ))
                    continue
                }
                guard case .noHit = trace.outcome else { continue }
                projectile.position = trace.finalPosition
                projectile.roomSourceIndex =
                    trace.containingRoomSourceIndex
                projectile.lifeRemaining -= systemsFrameDuration
                if projectile.lifeRemaining > 0 {
                    survivingProjectiles.append(projectile)
                }
            }
            dodgeState.projectiles = survivingProjectiles

            if dodgeState.script033Count < 1,
                case .room(35) = player.location,
                let startDodge = level.objects.first(where: {
                    $0.handle == dodge.startDodgeObjectHandle
                }),
                segmentSphereHitFraction(
                    start: object.position,
                    end: player.position,
                    center: startDodge.position,
                    radius:
                        dodge.startDodgeCollisionRadius
                        + view.collisionRadius
                ) != nil
            {
                if var openingState = trainingOpeningState {
                    let raw = openingState.enabledControls.rawValue
                    openingState.enabledControls = .init(
                        rawValue: (raw & ~dodge.disabledControlMask)
                            | dodge.enabledDodgeControlMask
                    )
                    trainingOpeningState = openingState
                }
                setTrainingDodgePortalRenderState(
                    in: &level,
                    roomSourceIndex: dodge.portalRoomTwoSourceIndex,
                    portalIndices: dodge.orderedPortalIndices,
                    rendersFaces: true
                )
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [dodge.introduction],
                        voiceSourceName:
                            dodge.introductionVoiceSourceName,
                        voicePrecedesHUDMessages: true
                    ))
                dodgeState.triggerTimerRemaining = dodge.triggerDelay
                dodgeState.script033Count += 1
            }

            if let exit = dodge.dodgeExit,
                (dodgeState.script019Count ?? 0) < 1,
                case .room(35) = player.location,
                let doneDodgeingGoal = level.objects.first(where: {
                    $0.handle == exit.objectHandle
                }),
                segmentSphereHitFraction(
                    start: object.position,
                    end: player.position,
                    center: doneDodgeingGoal.position,
                    radius:
                        exit.collisionRadius
                        + view.collisionRadius
                ) != nil
            {
                dodgeState.markerLightDistance =
                    exit.markerLightDistance
                setTrainingDodgePortalRenderState(
                    in: &level,
                    roomSourceIndex: exit.portalRoomSourceIndex,
                    portalIndices: exit.orderedPortalIndices,
                    rendersFaces: false
                )
                if var openingState = trainingOpeningState {
                    openingState.enabledControls = .init(
                        rawValue:
                            openingState.enabledControls.rawValue
                            & ~exit.disabledControlMask
                    )
                    trainingOpeningState = openingState
                }
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [exit.instruction],
                        voiceSourceName: exit.voiceSourceName,
                        voicePrecedesHUDMessages: true
                    ))
                dodgeState.script019Count =
                    min(
                        (dodgeState.script019Count ?? 0) + 1,
                        trainingScriptActionCounterMaximum
                    )
            }

            if var maneuverState = trainingManeuverFollowState,
               let lesson = dodge.maneuverFollow,
               maneuverState.script021Count < 1,
               dodgeState.script020Count > 0,
               case .room(37) = player.location,
               let maneuver = level.objects.first(where: {
                   $0.handle == lesson.maneuverObjectHandle
               }),
               segmentSphereHitFraction(
                   start: object.position,
                   end: player.position,
                   center: maneuver.position,
                   radius:
                       lesson.maneuverCollisionRadius
                       + view.collisionRadius
               ) != nil
            {
                dodgeState.markerLightDistance = 0
                if var openingState = trainingOpeningState {
                    openingState.enabledControls = .init(
                        rawValue: lesson.headingControlMask
                    )
                    trainingOpeningState = openingState
                }
                setTrainingDodgePortalRenderState(
                    in: &level,
                    roomSourceIndex: lesson.portalRoomSourceIndex,
                    portalIndices: lesson.orderedPortalIndices,
                    rendersFaces: true
                )
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [
                            lesson.maneuverIntroduction,
                        ],
                        voiceSourceName:
                            lesson.headingVoiceSourceName,
                        voicePrecedesHUDMessages: false,
                        trailingHUDMessages: [
                            lesson.headingInstruction,
                        ]
                    ))
                maneuverState.levelTimerRemaining =
                    lesson.headingDuration
                maneuverState.script021Count += 1
                trainingManeuverFollowState = maneuverState
            }

            if shields < dodge.restoredPlayerShields,
                dodgeState.script016Count > 0,
                dodgeState.script017Count == 0
            {
                dodgeState.almostDoneTimerRemaining =
                    dodge.almostDoneDelay
                dodgeState.successTimerRemaining = dodge.successDelay
                almostDoneTimerConsumesFrame = false
                successTimerConsumesFrame = false
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [dodge.hitInstruction],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true
                    ))
                shields = dodge.restoredPlayerShields
                if dodgeState.script018Count
                    < trainingScriptActionCounterMaximum
                {
                    dodgeState.script018Count += 1
                }
            }

            if var timer = dodgeState.triggerTimerRemaining {
                if triggerTimerConsumesFrame {
                    timer -= systemsFrameDuration
                }
                if timer <= 0.000_001,
                    dodgeState.script016Count < 1
                {
                    dodgeState.triggerTimerRemaining = nil
                    shields = dodge.restoredPlayerShields
                    trainingOpeningFeedback.append(
                        .init(
                            hudMessages: [dodge.instruction],
                            voiceSourceName: "",
                            voicePrecedesHUDMessages: true
                        ))
                    dodgeState.successTimerRemaining =
                        dodge.successDelay
                    dodgeState.almostDoneTimerRemaining =
                        dodge.almostDoneDelay
                    dodgeState.turretIsPowered = true
                    dodgeState.nextFireTime = systemsGameTime
                    dodgeState.script016Count += 1
                } else {
                    dodgeState.triggerTimerRemaining = timer
                }
            }
            if var timer = dodgeState.almostDoneTimerRemaining {
                if almostDoneTimerConsumesFrame {
                    timer -= systemsFrameDuration
                }
                if timer <= 0.000_001 {
                    dodgeState.almostDoneTimerRemaining = nil
                    trainingOpeningFeedback.append(
                        .init(
                            hudMessages: [dodge.almostDoneInstruction],
                            voiceSourceName:
                                dodge.almostDoneVoiceSourceName,
                            voicePrecedesHUDMessages: true
                        ))
                    if dodgeState.script020Count
                        < trainingScriptActionCounterMaximum
                    {
                        dodgeState.script020Count += 1
                    }
                } else {
                    dodgeState.almostDoneTimerRemaining = timer
                }
            }
            if var timer = dodgeState.successTimerRemaining {
                if successTimerConsumesFrame {
                    timer -= systemsFrameDuration
                }
                if timer <= 0.000_001,
                    dodgeState.script017Count < 1
                {
                    dodgeState.successTimerRemaining = nil
                    dodgeState.markerLightDistance =
                        dodge.successMarkerLightDistance
                    setTrainingDodgePortalRenderState(
                        in: &level,
                        roomSourceIndex:
                            dodge.portalRoomThreeSourceIndex,
                        portalIndices: dodge.orderedPortalIndices,
                        rendersFaces: false
                    )
                    dodgeState.turretIsPowered = false
                    if var openingState = trainingOpeningState {
                        openingState.enabledControls.formUnion(
                            .init(
                                rawValue: dodge.successControlMask
                            ))
                        trainingOpeningState = openingState
                    }
                    trainingOpeningFeedback.append(
                        .init(
                            hudMessages: [
                                dodge.successMessage,
                                dodge.leaveInstruction,
                            ],
                            voiceSourceName:
                                dodge.successVoiceSourceName,
                            voicePrecedesHUDMessages: true
                        ))
                    dodgeState.script017Count += 1
                } else {
                    dodgeState.successTimerRemaining = timer
                }
            }
            if var maneuverState = trainingManeuverFollowState,
               let lesson = dodge.maneuverFollow
            {
                var followObjectTimerWasRestarted = false
                if maneuverState.script023Count > 0,
                   maneuverState.script026Count == 0
                {
                    let followBotDirection =
                        maneuverState.position - player.position
                    let followBotIsVisible =
                        dot(followBotDirection, followBotDirection)
                            > 0.000_001
                        && Double(
                            dot(
                                player.orientation.forward,
                                normalized(followBotDirection)
                            )
                        ) > cos(Double.pi / 4)
                    if !followBotIsVisible {
                        maneuverState.objectTimerRemaining =
                            lesson.followDuration
                        followObjectTimerWasRestarted = true
                    }
                    if maneuverState.script025Count
                        < trainingScriptActionCounterMaximum
                    {
                        maneuverState.script025Count += 1
                    }
                }
                if maneuverState.script021Count > 0,
                   energy < 50,
                   var destruction = maneuverState.destruction {
                    energy = 50
                    destruction.script031Count = min(
                        destruction.script031Count + 1,
                        trainingScriptActionCounterMaximum
                    )
                    maneuverState.destruction = destruction
                }

                if var timer = maneuverState.levelTimerRemaining {
                    if maneuverLevelTimerConsumesFrame {
                        timer -= systemsFrameDuration
                    }
                    if timer <= 0.000_001 {
                        maneuverState.levelTimerRemaining = nil
                        // TrainingMission.cpp keeps the released level-timer
                        // handler order 023, 024, 022.
                        if maneuverState.script023Count < 1,
                           maneuverState.script024Count > 0
                        {
                            if var openingState =
                                    trainingOpeningState
                            {
                                openingState.enabledControls =
                                    .init(
                                        rawValue:
                                            lesson
                                            .rotationalControlMask
                                    )
                                trainingOpeningState = openingState
                            }
                            trainingOpeningFeedback.append(
                                .init(
                                    hudMessages: [
                                        lesson.followIntroduction,
                                        lesson.followInstruction,
                                    ],
                                    voiceSourceName:
                                        lesson.followVoiceSourceName,
                                    voicePrecedesHUDMessages: false
                                ))
                            maneuverState.followBotIsPowered = true
                            maneuverState.followBotTeamFlags =
                                lesson.friendlyTeamFlags
                            maneuverState.objectTimerRemaining =
                                lesson.followDuration
                            assignTrainingFollowBotPath(
                                lesson.followPathIndex,
                                state: &maneuverState
                            )
                            maneuverState.script023Count += 1
                        }
                        if maneuverState.script024Count < 1,
                           maneuverState.script022Count > 0
                        {
                            if var openingState =
                                    trainingOpeningState
                            {
                                openingState.enabledControls =
                                    .init(
                                        rawValue:
                                            lesson.bankControlMask
                                    )
                                trainingOpeningState = openingState
                            }
                            trainingOpeningFeedback.append(
                                .init(
                                    hudMessages: [
                                        lesson.bankInstruction,
                                    ],
                                    voiceSourceName:
                                        lesson.bankVoiceSourceName,
                                    voicePrecedesHUDMessages: false
                                ))
                            maneuverState.levelTimerRemaining =
                                lesson.bankDuration
                            maneuverState.script024Count += 1
                        }
                        if maneuverState.script022Count < 1,
                           maneuverState.script021Count > 0
                        {
                            if var openingState =
                                    trainingOpeningState
                            {
                                openingState.enabledControls =
                                    .init(
                                        rawValue:
                                            lesson.pitchControlMask
                                    )
                                trainingOpeningState = openingState
                            }
                            trainingOpeningFeedback.append(
                                .init(
                                    hudMessages: [
                                        lesson.successMessage,
                                        lesson.pitchInstruction,
                                    ],
                                    voiceSourceName:
                                        lesson.pitchVoiceSourceName,
                                    voicePrecedesHUDMessages: false
                                ))
                            maneuverState.levelTimerRemaining =
                                lesson.pitchDuration
                            maneuverState.script022Count += 1
                        }
                    } else {
                        maneuverState.levelTimerRemaining = timer
                    }
                }

                if let handoff = lesson.destructionHandoff,
                   var destruction = maneuverState.destruction,
                   var timer = destruction.levelTimer11Remaining {
                    if !followBotTimer11StartedThisFrame {
                        timer -= systemsFrameDuration
                    }
                    if timer <= 0.000_001,
                       destruction.script027Count < 1 {
                        destruction.levelTimer11Remaining = nil
                        trainingOpeningFeedback.append(
                            .init(
                                hudMessages: [handoff.successMessage],
                                voiceSourceName: "",
                                voicePrecedesHUDMessages: false
                            )
                        )
                        destruction.destroyBot2TeamFlags =
                            handoff.movingTeamFlags
                        destruction.destroyBot1TeamFlags =
                            handoff.movingTeamFlags
                        destruction.destroyBot1IsVisible = true
                        setObjectPresentationVisibility(
                            in: &level,
                            handle:
                                handoff.destroyBot1ObjectHandle,
                            isVisible: true
                        )
                        trainingOpeningFeedback.append(
                            .init(
                                hudMessages: [
                                    handoff.movingInstruction
                                ],
                                voiceSourceName:
                                    handoff.voiceSourceName,
                                voicePrecedesHUDMessages: false
                            )
                        )
                        assignTrainingAuthoredPath(
                            handoff.movingPathIndex,
                            motion:
                                &destruction
                                .destroyBot1Motion
                        )
                        destruction.destroyBot1Destruction =
                            initialTrainingDestroyBot1DestructionState(
                                level: level,
                                handoff: handoff
                            )
                        destruction.script027Count = min(
                            destruction.script027Count + 1,
                            trainingScriptActionCounterMaximum
                        )
                    } else {
                        destruction.levelTimer11Remaining = timer
                    }
                    maneuverState.destruction = destruction
                }

                if var timer = maneuverState.objectTimerRemaining {
                    if followObjectTimerConsumesFrame,
                       !followObjectTimerWasRestarted {
                        timer -= systemsFrameDuration
                    }
                    if timer <= 0.000_001 {
                        maneuverState.objectTimerRemaining = nil
                        if maneuverState.script025Count > 0 {
                            if var openingState =
                                    trainingOpeningState
                            {
                                openingState.enabledControls.formUnion(
                                    .init(
                                        rawValue:
                                            lesson.weaponControlMask
                                    ))
                                trainingOpeningState = openingState
                            }
                            assignTrainingFollowBotPath(
                                lesson.destroyPathIndex,
                                state: &maneuverState
                            )
                            trainingOpeningFeedback.append(
                                .init(
                                    hudMessages: [
                                        lesson.successMessage,
                                        lesson.weaponsEnabledInstruction,
                                    ],
                                    voiceSourceName:
                                        lesson.weaponVoiceSourceName,
                                    voicePrecedesHUDMessages: false,
                                    trailingHUDMessages: [
                                        lesson.destroyInstruction,
                                    ]
                                ))
                            maneuverState.script026Count = min(
                                maneuverState.script026Count + 1,
                                trainingScriptActionCounterMaximum
                            )
                        }
                    } else {
                        maneuverState.objectTimerRemaining = timer
                    }
                }
                trainingManeuverFollowState = maneuverState
                restoreTrainingFollowBotPresentation()
            }
            trainingDodgeAttemptState = dodgeState
        }
    }

    func advanceTrainingCombat(
        input: InputSnapshot,
        object: PlacedObject,
        ship: CanonicalShipDefinition,
        startRoom: Int,
        systemsFrameDuration: Float,
        systemsGameTime: Float,
        playerConcussionFeedback: inout [TrainingOpeningFeedback]
    ) -> (
        followBotTimer11StartedThisFrame: Bool,
        destroyBot2PathStartedThisFrame: Bool,
        destructionTimer12StartedThisFrame: Bool
    ) {
        var followBotTimer11StartedThisFrame = false
        var destroyBot2PathStartedThisFrame = false
        var destructionTimer12StartedThisFrame = false
        if var state = trainingRobotGuidebotState,
           let chain = level.trainingRobotGuidebotChain {
            let combat = chain.combat
            if input.firesPrimaryWeapon,
               systemsGameTime >= state.nextPrimaryFireTime,
               energy >= combat.batteryEnergyCost {
                for gunpoint in combat.gunpoints {
                    let position = object.position
                        + object.orientation.right * gunpoint.x
                        + object.orientation.up * gunpoint.y
                        + object.orientation.forward * gunpoint.z
                    state.projectiles.append(.init(
                        roomSourceIndex: startRoom,
                        position: position,
                        velocity:
                            object.orientation.forward
                                * combat.projectileSpeed,
                        lifeRemaining: combat.projectileLifetime
                    ))
                }
                energy -= combat.batteryEnergyCost
                let previousDeadline = state.nextPrimaryFireTime
                let overdue = systemsGameTime - previousDeadline
                let continuityWindow = max(
                    combat.batteryFireWait,
                    systemsFrameDuration * 1.5
                )
                if overdue >= 0, overdue <= continuityWindow {
                    state.nextPrimaryFireTime =
                        previousDeadline + combat.batteryFireWait
                } else {
                    state.nextPrimaryFireTime =
                        systemsGameTime + combat.batteryFireWait
                }
            }
            if input.firesSecondaryWeapon,
               let concussion = ship.playerConcussion,
               var concussionState = playerConcussionState {
                if let feedback = firePlayerConcussion(
                    from: object,
                    roomSourceIndex: startRoom,
                    binding: concussion,
                    state: &concussionState,
                    frameDuration: systemsFrameDuration,
                    gameTime: systemsGameTime
                ) {
                    playerConcussionFeedback.append(feedback)
                }
                playerConcussionState = concussionState
            }

            var maneuverState = trainingManeuverFollowState
            var followBotDestructionState =
                maneuverState?.destruction
            var destroyBot1DestructionState =
                followBotDestructionState?
                    .destroyBot1Destruction
            let handoff =
                level.trainingDodgeAttempt?.maneuverFollow?
                    .destructionHandoff
            let followBot: PlacedObject? = handoff.flatMap {
                handoff in
                guard maneuverState?.script026Count ?? 0 > 0,
                      followBotDestructionState?
                        .followBotWasDestroyed == false
                else {
                    return nil
                }
                return level.objects.first {
                    $0.handle == handoff.followBotObjectHandle
                }
            }
            let destroyBot1: PlacedObject? = handoff.flatMap {
                handoff in
                guard followBotDestructionState?
                        .script027Count ?? 0 > 0,
                      followBotDestructionState?
                        .destroyBot1IsVisible == true,
                      destroyBot1DestructionState?
                        .destroyBot1WasDestroyed == false
                else {
                    return nil
                }
                return level.objects.first {
                    $0.handle == handoff.destroyBot1ObjectHandle
                }
            }
            let robot = level.objects.first { robot in
                guard robot.handle
                        == chain.destroyRobotObjectHandle
                else {
                    return false
                }
                guard let handoff else {
                    return true
                }
                return robot.handle
                        == handoff.destroyBot2ObjectHandle
                    && destroyBot1DestructionState?
                        .script028Count ?? 0 > 0
                    && destroyBot1DestructionState?
                        .destroyBot1WasDestroyed == true
                    && followBotDestructionState?
                        .destroyBot2IsVisible == true
                    && destroyBot1DestructionState?
                        .destroyBot2Motion.activePathIndex
                        == handoff.movingPathIndex
            }
            let rasBot1Chain = level.trainingRASBot1DeathChain
            let rasBot1 = rasBot1Chain.flatMap { rasBot1Chain in
                level.objects.first {
                    $0.handle == rasBot1Chain.robotObjectHandle
                }
            }
            let rasBot2Chain = level.trainingRASBot2DeathChain
            let rasBot2 = rasBot2Chain.flatMap { rasBot2Chain in
                level.objects.first {
                    $0.handle == rasBot2Chain.robotObjectHandle
                }
            }
            let rasBot3Chain = level.trainingRASBot3DeathChain
            let rasBot3 = rasBot3Chain.flatMap { rasBot3Chain in
                level.objects.first {
                    $0.handle == rasBot3Chain.robotObjectHandle
                }
            }
            let rasBot4Chain = level.trainingRASBot4DeathChain
            let rasBot4 = rasBot4Chain.flatMap { rasBot4Chain in
                level.objects.first {
                    $0.handle == rasBot4Chain.robotObjectHandle
                }
            }
            let lastBot1Chain = level.trainingLastBot1DeathChain
            let lastBot1 = lastBot1Chain.flatMap { lastBot1Chain in
                level.objects.first {
                    $0.handle == lastBot1Chain.robotObjectHandle
                }
            }
            let lastBot2Chain = level.trainingLastBot2DeathChain
            let lastBot2 = lastBot2Chain.flatMap { lastBot2Chain in
                level.objects.first {
                    $0.handle == lastBot2Chain.robotObjectHandle
                }
            }
            let lastBot3Chain = level.trainingLastBot3DeathChain
            let lastBot3 = lastBot3Chain.flatMap { lastBot3Chain in
                level.objects.first {
                    $0.handle == lastBot3Chain.robotObjectHandle
                }
            }
            let lastBot4Chain = level.trainingLastBot4DeathChain
            let lastBot4 = lastBot4Chain.flatMap { lastBot4Chain in
                level.objects.first {
                    $0.handle == lastBot4Chain.robotObjectHandle
                }
            }
            let lastBot5Chain = level.trainingLastBot5DeathChain
            let lastBot5 = lastBot5Chain.flatMap { lastBot5Chain in
                level.objects.first {
                    $0.handle == lastBot5Chain.robotObjectHandle
                }
            }
            var rasBot1State = trainingRASBot1DeathState
            var rasBot2State = trainingRASBot2DeathState
            var rasBot3State = trainingRASBot3DeathState
            var rasBot4State = trainingRASBot4DeathState
            var lastBot1State = trainingLastBot1DeathState
            var lastBot2State = trainingLastBot2DeathState
            var lastBot3State = trainingLastBot3DeathState
            var lastBot4State = trainingLastBot4DeathState
            var lastBot5State = trainingLastBot5DeathState
            if let concussion = ship.playerConcussion,
               var concussionState = playerConcussionState {
                typealias ConcussionTarget = (
                    handle: UInt32,
                    roomSourceIndex: Int,
                    position: Vector3,
                    radius: Float
                )
                var targets: [ConcussionTarget] = []
                func addTarget(_ object: PlacedObject?, radius: Float?) {
                    guard let object, let radius,
                          case let .room(roomSourceIndex) = object.location
                    else { return }
                    targets.append((
                        object.handle,
                        roomSourceIndex,
                        object.position,
                        radius
                    ))
                }
                addTarget(robot, radius: combat.robotCollisionRadius)
                addTarget(followBot, radius: handoff?.combat.robotCollisionRadius)
                addTarget(destroyBot1, radius: handoff?.combat.robotCollisionRadius)
                addTarget(rasBot1, radius: rasBot1Chain?.combat.robotCollisionRadius)
                addTarget(rasBot2, radius: rasBot2Chain?.combat.robotCollisionRadius)
                addTarget(rasBot3, radius: rasBot3Chain?.combat.robotCollisionRadius)
                addTarget(rasBot4, radius: rasBot4Chain?.combat.robotCollisionRadius)
                addTarget(lastBot1, radius: lastBot1Chain?.combat.robotCollisionRadius)
                addTarget(lastBot2, radius: lastBot2Chain?.combat.robotCollisionRadius)
                addTarget(lastBot3, radius: lastBot3Chain?.combat.robotCollisionRadius)
                addTarget(lastBot4, radius: lastBot4Chain?.combat.robotCollisionRadius)
                addTarget(lastBot5, radius: lastBot5Chain?.combat.robotCollisionRadius)

                func applyDamage(to handle: UInt32, amount: Float) -> Bool {
                    if handle == robot?.handle {
                        state.robotShields -= amount
                    } else if handle == followBot?.handle {
                        followBotDestructionState?.followBotShields -= amount
                    } else if handle == destroyBot1?.handle {
                        destroyBot1DestructionState?.destroyBot1Shields -= amount
                    } else if handle == rasBot1?.handle {
                        rasBot1State?.shields -= amount
                    } else if handle == rasBot2?.handle {
                        rasBot2State?.shields -= amount
                    } else if handle == rasBot3?.handle {
                        rasBot3State?.shields -= amount
                    } else if handle == rasBot4?.handle {
                        rasBot4State?.shields -= amount
                    } else if handle == lastBot1?.handle {
                        lastBot1State?.shields -= amount
                    } else if handle == lastBot2?.handle {
                        lastBot2State?.shields -= amount
                    } else if handle == lastBot3?.handle {
                        lastBot3State?.shields -= amount
                    } else if handle == lastBot4?.handle {
                        lastBot4State?.shields -= amount
                    } else if handle == lastBot5?.handle {
                        lastBot5State?.shields -= amount
                    } else {
                        return false
                    }
                    return true
                }

                concussionState.sparks = concussionState.sparks.compactMap {
                    spark in
                    var spark = spark
                    spark.lifeRemaining -= systemsFrameDuration
                    guard spark.lifeRemaining >= 0 else { return nil }
                    let motion = analyticLinearMotion(
                        position: spark.position,
                        velocity: spark.velocity,
                        force: .init(
                            x: 0,
                            y: level.metadata.gravity * 500,
                            z: 0
                        ),
                        mass: 500,
                        drag: 0.001,
                        duration: systemsFrameDuration
                    )
                    spark.position = motion.position
                    spark.velocity = motion.velocity
                    return spark
                }
                let impacts = advancePlayerConcussionMissiles(
                    duration: systemsFrameDuration,
                    playerHandle: object.handle,
                    binding: concussion,
                    state: &concussionState
                )
                let newExplosionOrdinals = Set(
                    impacts.map(\.explosionCreationOrdinal)
                )

                // The released impact path creates the explosion object first,
                // then applies the direct hit. Its shockwave acts afterward.
                for impact in impacts {
                    playerConcussionFeedback.append(.init(
                        hudMessages: [],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false,
                        soundSourceName: concussion.impactSoundSourceName
                    ))
                    guard let handle = impact.directObjectHandle,
                          applyDamage(
                            to: handle,
                            amount: concussion.directRobotDamage
                          ) else {
                        continue
                    }
                    let sparkCount = 3
                        + Int(nextAuthoritativeRandomValue() % 6)
                    for _ in 0..<sparkCount {
                        let rawDirection = Vector3(
                            x: Float(Int(nextAuthoritativeRandomValue() % 100) - 50),
                            y: Float(nextAuthoritativeRandomValue() % 100),
                            z: Float(Int(nextAuthoritativeRandomValue() % 100) - 50)
                        )
                        let direction = rawDirection == .zero
                            ? Vector3(x: 1, y: 0, z: 0)
                            : normalized(rawDirection)
                        let speed = Float(
                            20 + nextAuthoritativeRandomValue() % 10
                        )
                        let size = 0.7
                            + Float(nextAuthoritativeRandomValue() % 10) * 0.04
                        let lifetime = 1
                            + Float(nextAuthoritativeRandomValue() % 10) * 0.15
                        concussionState.sparks.append(.init(
                            creationOrdinal:
                                concussionState.nextCreationOrdinal,
                            roomSourceIndex: impact.roomSourceIndex,
                            position: impact.position,
                            velocity: direction * speed,
                            size: size,
                            lifetime: lifetime,
                            lifeRemaining: lifetime
                        ))
                        concussionState.nextCreationOrdinal += 1
                    }
                }
                for index in concussionState.explosions.indices {
                    if !newExplosionOrdinals.contains(
                        concussionState.explosions[index].creationOrdinal
                    ) {
                        concussionState.explosions[index].lifeRemaining -=
                            systemsFrameDuration
                        concussionState.explosions[index]
                            .shockwaveLifeRemaining = max(
                                0,
                                concussionState.explosions[index]
                                    .shockwaveLifeRemaining
                                    - systemsFrameDuration
                            )
                    }
                    let explosion = concussionState.explosions[index]
                    let shockwaveProgress = max(
                        0,
                        min(
                            1,
                            1 - explosion.shockwaveLifeRemaining
                                / concussion.shockwaveDuration
                        )
                    )
                    let shockwaveRadius =
                        concussion.shockwaveRadius * shockwaveProgress
                    for target in targets where
                        !concussionState.explosions[index]
                            .damagedObjectHandles.contains(target.handle)
                            && max(
                                0,
                                vectorDistance(target.position, explosion.position)
                                    - target.radius
                            ) <= shockwaveRadius
                    {
                        concussionState.explosions[index]
                            .damagedObjectHandles.insert(target.handle)
                        let visibility = traceIndoorMovement(
                            in: level,
                            startRoom: explosion.roomSourceIndex,
                            start: explosion.position,
                            end: target.position,
                            radius: 0
                        )
                        guard case .noHit = visibility.outcome else { continue }
                        let surfaceDistance = max(
                            0,
                            vectorDistance(target.position, explosion.position)
                                - target.radius
                        )
                        let scale = max(
                            0,
                            1 - surfaceDistance / concussion.shockwaveRadius
                        )
                        _ = applyDamage(
                            to: target.handle,
                            amount: concussion.shockwaveDamage * scale * 1.5
                        )
                    }
                    let playerSurfaceDistance = max(
                        0,
                        vectorDistance(object.position, explosion.position)
                            - ship.presentationSize * 0.8
                    )
                    if !concussionState.explosions[index].damagedPlayer,
                       playerSurfaceDistance <= shockwaveRadius {
                        concussionState.explosions[index].damagedPlayer = true
                        let visibility = traceIndoorMovement(
                            in: level,
                            startRoom: explosion.roomSourceIndex,
                            start: explosion.position,
                            end: object.position,
                            radius: 0
                        )
                        if case .noHit = visibility.outcome {
                            let scale = max(
                                0,
                                1 - playerSurfaceDistance
                                    / concussion.shockwaveRadius
                            )
                            shields -= concussion.shockwaveDamage * scale
                            let away = object.position - explosion.position
                            if away != .zero {
                                velocity = velocity
                                    + normalized(away)
                                        * (concussion.shockwaveForce * scale
                                            / ship.physics.mass)
                            }
                        }
                    }
                }
                concussionState.explosions.removeAll {
                    $0.lifeRemaining <= 0
                }
                playerConcussionState = concussionState
            }
            var survivingProjectiles: [TrainingLaserProjectileState] = []
            for var projectile in state.projectiles {
                let end = projectile.position
                    + projectile.velocity * systemsFrameDuration
                let trace = traceIndoorMovement(
                    in: level,
                    startRoom: projectile.roomSourceIndex,
                    start: projectile.position,
                    end: end,
                    radius: combat.projectileRadius
                )
                let robotHit = robot.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex)
                    else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            combat.projectileRadius
                                + combat.robotCollisionRadius
                    )
                }
                let followBotHit = followBot.flatMap {
                    followBot -> Float? in
                    guard followBot.location
                            == SpatialLocation.room(
                                projectile.roomSourceIndex
                            ),
                          let handoff
                    else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: followBot.position,
                        radius:
                            handoff.combat.projectileRadius
                                + handoff.combat
                                    .robotCollisionRadius
                    )
                }
                let destroyBot1Hit = destroyBot1.flatMap {
                    destroyBot1 -> Float? in
                    guard destroyBot1.location
                            == SpatialLocation.room(
                                projectile.roomSourceIndex
                            ),
                          let handoff
                    else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: destroyBot1.position,
                        radius:
                            handoff.combat.projectileRadius
                                + handoff.combat
                                    .robotCollisionRadius
                    )
                }
                let rasBot1Hit = rasBot1.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot1Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot1Chain.combat.projectileRadius
                                + rasBot1Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let rasBot2Hit = rasBot2.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot2Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot2Chain.combat.projectileRadius
                                + rasBot2Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let rasBot3Hit = rasBot3.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot3Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot3Chain.combat.projectileRadius
                                + rasBot3Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let rasBot4Hit = rasBot4.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot4Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot4Chain.combat.projectileRadius
                                + rasBot4Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot1Hit = lastBot1.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot1Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot1Chain.combat.projectileRadius
                                + lastBot1Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot2Hit = lastBot2.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot2Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot2Chain.combat.projectileRadius
                                + lastBot2Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot3Hit = lastBot3.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot3Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot3Chain.combat.projectileRadius
                                + lastBot3Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot4Hit = lastBot4.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot4Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot4Chain.combat.projectileRadius
                        + lastBot4Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot5Hit = lastBot5.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot5Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot5Chain.combat.projectileRadius
                                + lastBot5Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let traceFraction = vectorDistance(
                    projectile.position,
                    end
                ) > 0
                    ? vectorDistance(
                        projectile.position,
                        trace.finalPosition
                    ) / vectorDistance(projectile.position, end)
                    : 1
                var nearestRASBotHit: (handle: UInt32, fraction: Float)?
                if let rasBot1Hit {
                    nearestRASBotHit = (
                        rasBot1Chain!.robotObjectHandle,
                        rasBot1Hit
                    )
                }
                if let rasBot2Hit,
                   rasBot2Hit < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        rasBot2Chain!.robotObjectHandle,
                        rasBot2Hit
                    )
                }
                if let rasBot3Hit,
                   rasBot3Hit < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        rasBot3Chain!.robotObjectHandle,
                        rasBot3Hit
                    )
                }
                if let rasBot4Hit,
                   rasBot4Hit < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        rasBot4Chain!.robotObjectHandle,
                        rasBot4Hit
                    )
                }
                if let lastBot1Hit,
                   lastBot1Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot1Chain!.robotObjectHandle,
                        lastBot1Hit
                    )
                }
                if let lastBot2Hit,
                   lastBot2Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot2Chain!.robotObjectHandle,
                        lastBot2Hit
                    )
                }
                if let lastBot3Hit,
                   lastBot3Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot3Chain!.robotObjectHandle,
                        lastBot3Hit
                    )
                }
                if let lastBot4Hit,
                   lastBot4Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot4Chain!.robotObjectHandle,
                        lastBot4Hit
                    )
                }
                if let lastBot5Hit,
                   lastBot5Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot5Chain!.robotObjectHandle,
                        lastBot5Hit
                    )
                }
                if let nearestRASBotHit,
                   nearestRASBotHit.fraction
                    <= traceFraction + 0.000_1,
                   robotHit.map({
                       nearestRASBotHit.fraction < $0
                   }) ?? true,
                   followBotHit.map({
                       nearestRASBotHit.fraction < $0
                   }) ?? true,
                   destroyBot1Hit.map({
                       nearestRASBotHit.fraction < $0
                   }) ?? true {
                    if nearestRASBotHit.handle
                        == rasBot1Chain?.robotObjectHandle {
                        rasBot1State?.shields -=
                            rasBot1Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == rasBot2Chain?.robotObjectHandle {
                        rasBot2State?.shields -=
                            rasBot2Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == rasBot3Chain?.robotObjectHandle {
                        rasBot3State?.shields -=
                            rasBot3Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == rasBot4Chain?.robotObjectHandle {
                        rasBot4State?.shields -=
                            rasBot4Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot1Chain?.robotObjectHandle {
                        lastBot1State?.shields -=
                            lastBot1Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot2Chain?.robotObjectHandle {
                        lastBot2State?.shields -=
                            lastBot2Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot3Chain?.robotObjectHandle {
                        lastBot3State?.shields -=
                            lastBot3Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot4Chain?.robotObjectHandle {
                        lastBot4State?.shields -=
                            lastBot4Chain!.combat.projectileDamage
                    } else {
                        lastBot5State?.shields -=
                            lastBot5Chain!.combat.projectileDamage
                    }
                    continue
                }
                if let followBotHit,
                   followBotHit <= traceFraction + 0.000_1,
                   robotHit.map({ followBotHit < $0 }) ?? true,
                   nearestRASBotHit.map({
                       followBotHit < $0.fraction
                   }) ?? true,
                   destroyBot1Hit.map({
                       followBotHit < $0
                   }) ?? true {
                    followBotDestructionState?
                        .followBotShields -=
                            handoff!.combat.projectileDamage
                    continue
                }
                if let destroyBot1Hit,
                   destroyBot1Hit <= traceFraction + 0.000_1,
                   robotHit.map({ destroyBot1Hit < $0 }) ?? true,
                   nearestRASBotHit.map({
                       destroyBot1Hit < $0.fraction
                   }) ?? true,
                   followBotHit.map({
                       destroyBot1Hit < $0
                   }) ?? true {
                    destroyBot1DestructionState?
                        .destroyBot1Shields -=
                            handoff!.combat.projectileDamage
                    continue
                }
                if let robotHit, robotHit <= traceFraction + 0.000_1 {
                    state.robotShields -= combat.projectileDamage
                    continue
                }
                guard case .noHit = trace.outcome else { continue }
                projectile.position = trace.finalPosition
                projectile.roomSourceIndex =
                    trace.containingRoomSourceIndex
                projectile.lifeRemaining -= systemsFrameDuration
                if projectile.lifeRemaining > 0 {
                    survivingProjectiles.append(projectile)
                }
            }
            state.projectiles = survivingProjectiles
            let followBotWasKilled =
                followBotDestructionState.map {
                    !$0.followBotWasDestroyed
                        && $0.followBotShields < 0
                } ?? false
            let destroyBot1WasKilled =
                destroyBot1DestructionState.map {
                    !$0.destroyBot1WasDestroyed
                        && $0.destroyBot1Shields < 0
                } ?? false
            let robotWasKilled =
                !state.robotWasDestroyed && state.robotShields < 0
            let rasBot1WasKilled =
                rasBot1State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let rasBot2WasKilled =
                rasBot2State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let rasBot3WasKilled =
                rasBot3State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let rasBot4WasKilled =
                rasBot4State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot1WasKilled =
                lastBot1State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot2WasKilled =
                lastBot2State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot3WasKilled =
                lastBot3State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot4WasKilled =
                lastBot4State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot5WasKilled =
                lastBot5State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            trainingRobotGuidebotState = state
            trainingRASBot1DeathState = rasBot1State
            trainingRASBot2DeathState = rasBot2State
            trainingRASBot3DeathState = rasBot3State
            trainingRASBot4DeathState = rasBot4State
            trainingLastBot1DeathState = lastBot1State
            trainingLastBot2DeathState = lastBot2State
            trainingLastBot3DeathState = lastBot3State
            trainingLastBot4DeathState = lastBot4State
            trainingLastBot5DeathState = lastBot5State
            followBotDestructionState?
                .destroyBot1Destruction =
                    destroyBot1DestructionState
            maneuverState?.destruction =
                followBotDestructionState
            trainingManeuverFollowState = maneuverState
            if followBotWasKilled {
                destroyTrainingFollowBot(isDying: true)
                followBotTimer11StartedThisFrame = true
            }
            if destroyBot1WasKilled {
                destroyTrainingDestroyBot1(isDying: true)
                destroyBot2PathStartedThisFrame = true
            }
            if robotWasKilled {
                destroyTrainingRobot(handle: chain.destroyRobotObjectHandle)
                destructionTimer12StartedThisFrame = true
            }
            if rasBot1WasKilled {
                destroyTrainingRASBot1(
                    handle: rasBot1Chain!.robotObjectHandle
                )
            }
            if rasBot2WasKilled {
                destroyTrainingRASBot2(
                    handle: rasBot2Chain!.robotObjectHandle
                )
            }
            if rasBot3WasKilled {
                destroyTrainingRASBot3(
                    handle: rasBot3Chain!.robotObjectHandle
                )
            }
            if rasBot4WasKilled {
                destroyTrainingRASBot4(
                    handle: rasBot4Chain!.robotObjectHandle
                )
            }
            if lastBot1WasKilled {
                destroyTrainingLastBot1(
                    handle: lastBot1Chain!.robotObjectHandle
                )
            }
            if lastBot2WasKilled {
                destroyTrainingLastBot2(
                    handle: lastBot2Chain!.robotObjectHandle
                )
            }
            if lastBot3WasKilled {
                destroyTrainingLastBot3(
                    handle: lastBot3Chain!.robotObjectHandle
                )
            }
            if lastBot4WasKilled {
                destroyTrainingLastBot4(
                    handle: lastBot4Chain!.robotObjectHandle
                )
            }
            if lastBot5WasKilled {
                destroyTrainingLastBot5(
                    handle: lastBot5Chain!.robotObjectHandle
                )
            }
        }
        return (
            followBotTimer11StartedThisFrame,
            destroyBot2PathStartedThisFrame,
            destructionTimer12StartedThisFrame
        )
    }
}

private func trainingGalleryTriggerWasCrossed(
    in level: Level,
    passedPortalFaces: [IndoorPortalCrossing]
) -> Bool {
    guard let barrier = level.trainingGalleryBarrier else {
        return false
    }
    return passedPortalFaces.contains {
        $0.roomSourceIndex == barrier.triggerRoomSourceIndex
            && $0.faceIndex == barrier.triggerFaceIndex
    }
}

private func trainingKillbotEntryTriggerWasCrossed(
    in level: Level,
    passedPortalFaces: [IndoorPortalCrossing]
) -> Bool {
    guard let entry =
            level.trainingCameraMonitorChain?.returnToShip?.killbotEntry
    else {
        return false
    }
    return passedPortalFaces.contains {
        $0.roomSourceIndex == entry.triggerRoomSourceIndex
            && $0.faceIndex == entry.triggerFaceIndex
    }
}

private func trainingFinalRoomEntryTriggerWasCrossed(
    in level: Level,
    passedPortalFaces: [IndoorPortalCrossing]
) -> Bool {
    guard let chain = level.trainingFinalRoomEntryChain else {
        return false
    }
    return passedPortalFaces.contains {
        $0.roomSourceIndex == chain.triggerRoomSourceIndex
            && $0.faceIndex == chain.triggerFaceIndex
    }
}

private func segmentSphereHitFraction(
    start: Vector3,
    end: Vector3,
    center: Vector3,
    radius: Float
) -> Float? {
    let movement = end - start
    let offset = start - center
    let a = dot(movement, movement)
    guard a > 0 else {
        return dot(offset, offset) <= radius * radius ? 0 : nil
    }
    let b = 2 * dot(offset, movement)
    let c = dot(offset, offset) - radius * radius
    if c <= 0 { return 0 }
    let discriminant = b * b - 4 * a * c
    guard discriminant >= 0 else { return nil }
    let root = sqrt(discriminant)
    let first = (-b - root) / (2 * a)
    let second = (-b + root) / (2 * a)
    if (0...1).contains(first) { return first }
    if (0...1).contains(second) { return second }
    return nil
}

private func trainingCameraMonitorPickupWasHit(
    in level: Level,
    state: TrainingCameraMonitorState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
          !state.isHeld,
          !state.wasUsed,
          let chain = level.trainingCameraMonitorChain,
          let pickup = level.objects.first(where: {
              $0.handle == chain.pickupObjectHandle
          }),
          case let .room(pickupRoomSourceIndex) = pickup.location,
          visitedRoomSourceIndices.contains(pickupRoomSourceIndex) else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: pickup.position,
        radius: playerRadius + chain.pickupCollisionRadius
    ) != nil
}

private func trainingInvulnerabilityPickupWasHit(
    in level: Level,
    state: TrainingInvulnerabilityPickupState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
        !state.wasConsumed,
        let chain = level.trainingInvulnerabilityPickupChain,
        let pickup = level.objects.first(where: {
            $0.handle == chain.pickupObjectHandle
        }),
        pickup.location == .room(chain.pickupRoomSourceIndex),
        visitedRoomSourceIndices.contains(
            chain.pickupRoomSourceIndex
        )
    else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: pickup.position,
        radius: playerRadius + chain.pickupCollisionRadius
    ) != nil
}

private func trainingCloakPickupWasHit(
    in level: Level,
    state: TrainingCloakPickupState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
        !state.wasConsumed,
        let chain = level.trainingCloakPickupChain,
        let pickup = level.objects.first(where: {
            $0.handle == chain.pickupObjectHandle
        }),
        pickup.location == .room(chain.pickupRoomSourceIndex),
        visitedRoomSourceIndices.contains(chain.pickupRoomSourceIndex)
    else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: pickup.position,
        radius: playerRadius + chain.pickupCollisionRadius
    ) != nil
}

private func trainingFinalGoalWasHit(
    in level: Level,
    state: TrainingFinalGoalState?,
    finalBotsState: TrainingFinalBotsCompletionState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
          !state.endLevelWasRequested,
          finalBotsState?.wasTriggered == true,
          let chain = level.trainingFinalGoalChain,
          let goal = level.objects.first(where: {
              $0.handle == chain.goalObjectHandle
          }),
          goal.location == .room(chain.goalRoomSourceIndex),
          visitedRoomSourceIndices.contains(
              chain.goalRoomSourceIndex
          )
    else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: goal.position,
        radius: playerRadius + chain.goalCollisionRadius
    ) != nil
}

private func trainingCloakFrame(
    state: TrainingCloakPickupState?,
    chain: TrainingCloakPickupChain?
) -> TrainingCloakFrame? {
    guard let phase = state?.phase,
        let remaining = state?.phaseRemaining,
        let chain
    else {
        return nil
    }
    return .init(
        phase: phase,
        phaseRemaining: remaining,
        phaseDuration:
            phase == .cloaked ? chain.cloakDuration : chain.fadeDuration
    )
}

private func trainingGalleryBarrierRendersFaces(
    in level: Level,
    barrier: TrainingGalleryBarrier
) -> Bool {
    let room = level.rooms.first {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    return barrier.orderedPortalIndices.allSatisfy {
        room.portals[$0].flags & 1 != 0
    }
}

private func validTrainingGalleryBarrierContinuation(
    _ state: TrainingGalleryBarrierState?,
    robotGuidebotState: TrainingRobotGuidebotState?,
    level: Level
) -> Bool {
    guard let barrier = level.trainingGalleryBarrier else {
        return state == nil
    }
    guard let state,
          state.markerLightDistance.isFinite else {
        return false
    }
    let robotDestructionIsLater =
        robotGuidebotState?.robotWasDestroyed == true
            && robotGuidebotState?.controlsWereRestored == true
            && (
                robotGuidebotState?
                    .guidebotContinuationWasPresented != true
                    || state.markerLightDistance
                        == barrier.openMarkerLightDistance
            )
    let expectedDistance =
        robotDestructionIsLater
            ? barrier.openMarkerLightDistance
            : state.wasTriggered
            || trainingGalleryBarrierRendersFaces(
                in: level,
                barrier: barrier
            )
        ? 0
        : barrier.openMarkerLightDistance
    return state.markerLightDistance == expectedDistance
}

private func validTrainingManeuverFollowContinuation(
    _ state: TrainingManeuverFollowState?,
    robotGuidebotState: TrainingRobotGuidebotState?,
    level: Level
) -> Bool {
    guard let lesson =
            level.trainingDodgeAttempt?.maneuverFollow,
          let followBot = level.objects.first(where: {
              $0.handle == lesson.followBotObjectHandle
          }),
          case let .room(followBotRoomSourceIndex) =
              followBot.location,
          let followBotRoom = level.rooms.first(where: {
              $0.sourceIndex == followBotRoomSourceIndex
          })
    else {
        return state == nil
    }
    guard let state else { return false }
    let levelTimerIsValid: Bool = {
        let maximum: Float?
        if state.script021Count == 0
            || state.script023Count > 0
        {
            maximum = nil
        } else if state.script024Count > 0 {
            maximum = lesson.bankDuration
        } else if state.script022Count > 0 {
            maximum = lesson.pitchDuration
        } else {
            maximum = lesson.headingDuration
        }
        guard let maximum else {
            return state.levelTimerRemaining == nil
        }
        guard let timer = state.levelTimerRemaining else {
            return false
        }
        return timer.isFinite && timer > 0 && timer <= maximum
    }()
    let objectTimerIsValid: Bool = {
        guard state.script023Count > 0,
              state.script026Count == 0 else {
            return state.objectTimerRemaining == nil
        }
        guard let timer = state.objectTimerRemaining else {
            return false
        }
        return timer.isFinite
            && timer > 0
            && timer <= lesson.followDuration
    }()
    let velocityMagnitude = sqrt(dot(state.velocity, state.velocity))
    let destructionIsValid =
        validTrainingFollowBotDestructionContinuation(
            state.destruction,
            maneuverState: state,
            lesson: lesson,
            robotGuidebotState: robotGuidebotState,
            level: level
        )
    guard [
              state.script021Count,
              state.script022Count,
              state.script024Count,
              state.script023Count,
              state.script025Count,
              state.script026Count,
          ].allSatisfy({
              (0...trainingScriptActionCounterMaximum).contains($0)
          }),
          state.script021Count <= 1,
          state.script022Count <= 1,
          state.script024Count <= 1,
          state.script023Count <= 1,
          state.script026Count <= 1,
          state.script022Count <= state.script021Count,
          state.script024Count <= state.script022Count,
          state.script023Count <= state.script024Count,
          state.script026Count == 0 || state.script025Count > 0,
          levelTimerIsValid,
          objectTimerIsValid,
          state.roomSourceIndex == followBotRoomSourceIndex,
          isCanonicalRigidTransform(
              position: state.position,
              orientation: state.orientation
          ),
          sourceConvexRoomContains(
              state.position,
              in: followBotRoom
          ),
          state.velocity.x.isFinite,
          state.velocity.y.isFinite,
          state.velocity.z.isFinite,
          velocityMagnitude.isFinite,
          velocityMagnitude
            <= lesson.followBot.maximumVelocity + 0.001,
          state.activePathIndex.map({
              $0 == lesson.followPathIndex
                || $0 == lesson.destroyPathIndex
          }) ?? true,
          state.pathNodeIndex >= 0,
          state.activePathIndex.map({
              level.paths[$0].nodes.indices.contains(
                  state.pathNodeIndex
              )
          }) ?? (state.pathNodeIndex == 0),
          state.followBotTeamFlags == 0
            || state.followBotTeamFlags == lesson.friendlyTeamFlags,
          destructionIsValid
    else {
        return false
    }
    if state.script023Count == 0 {
        return state.script025Count == 0
            && state.script026Count == 0
            && !state.followBotIsPowered
            && state.followBotTeamFlags == 0
            && state.activePathIndex == nil
    }
    return state.followBotIsPowered
        && state.followBotTeamFlags == lesson.friendlyTeamFlags
        && (
            state.script026Count == 0
                ? state.activePathIndex == lesson.followPathIndex
                : state.activePathIndex == lesson.destroyPathIndex
                    || state.activePathIndex == nil
        )
}

private func validTrainingDestroyBot1DestructionContinuation(
    _ state: TrainingDestroyBot1DestructionState?,
    script027Count: Int,
    lesson: TrainingManeuverFollowLesson,
    handoff: TrainingFollowBotDestructionHandoff,
    robotGuidebotState: TrainingRobotGuidebotState?,
    level: Level
) -> Bool {
    guard let state else {
        return true
    }
    guard script027Count > 0,
          let destroyBot2 = level.objects.first(where: {
              $0.handle == handoff.destroyBot2ObjectHandle
          }),
          case let .room(initialRoom) = destroyBot2.location,
          let destroyBot2Room = level.rooms.first(where: {
              $0.sourceIndex == initialRoom
          }),
          (0...trainingScriptActionCounterMaximum).contains(
              state.script028Count
          ),
          state.script028Count <= 1,
          state.destroyBot1Shields.isFinite,
          state.destroyBot1Shields <= handoff.combat.robotShields,
          state.destroyBot1WasDestroyed
            == (state.destroyBot1Shields < 0),
          state.destroyBot1WasDestroyed
            == (state.script028Count > 0),
          isCanonicalRigidTransform(
              position: state.destroyBot2Motion.position,
              orientation: state.destroyBot2Motion.orientation
          ),
          state.destroyBot2Motion.velocity.x.isFinite,
          state.destroyBot2Motion.velocity.y.isFinite,
          state.destroyBot2Motion.velocity.z.isFinite,
          sqrt(dot(
              state.destroyBot2Motion.velocity,
              state.destroyBot2Motion.velocity
          )) <= lesson.followBot.maximumVelocity + 0.001,
          state.destroyBot2Motion.roomSourceIndex == initialRoom,
          state.destroyBot2Motion.pathNodeIndex >= 0,
          state.destroyBot2Motion.activePathIndex.map({
              $0 == handoff.movingPathIndex
                && level.paths[$0].nodes.indices.contains(
                    state.destroyBot2Motion.pathNodeIndex
                )
          }) ?? (state.destroyBot2Motion.pathNodeIndex == 0)
    else {
        return false
    }
    if robotGuidebotState?.robotWasDestroyed == true {
        return state.script028Count > 0
            && state.destroyBot2Motion.activePathIndex == nil
            && state.destroyBot2Motion.pathNodeIndex == 0
            && state.destroyBot2Motion.velocity == .zero
            && state.destroyBot2Motion.pathFailure == nil
            && sourceConvexRoomContains(
                state.destroyBot2Motion.position,
                in: destroyBot2Room
            )
    }
    return state.script028Count > 0
        ? state.destroyBot2Motion.activePathIndex
            == handoff.movingPathIndex
            && sourceConvexRoomContains(
                state.destroyBot2Motion.position,
                in: destroyBot2Room
            )
        : state.destroyBot1Shields >= 0
            && state.destroyBot2Motion.activePathIndex == nil
            && state.destroyBot2Motion.position
                == destroyBot2.position
            && state.destroyBot2Motion.orientation
                == destroyBot2.orientation
            && state.destroyBot2Motion.velocity == .zero
            && state.destroyBot2Motion.pathFailure == nil
}

private func validTrainingFollowBotDestructionContinuation(
    _ state: TrainingFollowBotDestructionState?,
    maneuverState: TrainingManeuverFollowState,
    lesson: TrainingManeuverFollowLesson,
    robotGuidebotState: TrainingRobotGuidebotState?,
    level: Level
) -> Bool {
    guard let handoff = lesson.destructionHandoff else {
        return state == nil
    }
    guard let state,
          let destroyBot1 = level.objects.first(where: {
              $0.handle == handoff.destroyBot1ObjectHandle
          }),
          case let .room(initialRoom) = destroyBot1.location,
          let destroyBot1Room = level.rooms.first(where: {
              $0.sourceIndex == initialRoom
          }),
          [
              state.script031Count,
              state.script037Count,
              state.script027Count,
          ].allSatisfy({
              (0...trainingScriptActionCounterMaximum)
                .contains($0)
          }),
          state.script037Count <= 1,
          state.script027Count <= 1,
          state.script037Count == 0
            || (
                maneuverState.script026Count > 0
                    && state.followBotWasDestroyed
            ),
          state.followBotShields.isFinite,
          state.followBotShields <= handoff.combat.robotShields,
          state.followBotWasDestroyed
            == (state.followBotShields < 0),
          state.followBotWasDestroyed
            == (state.script037Count > 0),
          state.destroyBot2IsVisible
            == ((
                state.destroyBot1Destruction?
                    .script028Count ?? 0
            ) > 0
                && robotGuidebotState?.robotWasDestroyed != true),
          state.destroyBot1IsVisible
            == (
                state.script027Count > 0
                    && (
                        state.destroyBot1Destruction?
                            .script028Count ?? 0
                    ) == 0
            ),
          state.destroyBot2TeamFlags
            == (state.script027Count > 0
                ? handoff.movingTeamFlags
                : 0),
          state.destroyBot1TeamFlags
            == (state.script027Count > 0
                ? handoff.movingTeamFlags
                : 0),
          state.levelTimer11Remaining.map({
              $0.isFinite
                && $0 > 0
                && $0 <= handoff.destructionDelay
                && state.script027Count == 0
          }) ?? (
              state.script037Count == 0
                || state.script027Count > 0
          ),
          state.destroyBot1Motion.roomSourceIndex == initialRoom,
          isCanonicalRigidTransform(
              position: state.destroyBot1Motion.position,
              orientation: state.destroyBot1Motion.orientation
          ),
          state.destroyBot1Motion.velocity.x.isFinite,
          state.destroyBot1Motion.velocity.y.isFinite,
          state.destroyBot1Motion.velocity.z.isFinite,
          sqrt(dot(
              state.destroyBot1Motion.velocity,
              state.destroyBot1Motion.velocity
          )) <= lesson.followBot.maximumVelocity + 0.001,
          state.destroyBot1Motion.activePathIndex.map({
              $0 == handoff.movingPathIndex
          }) ?? true,
          state.destroyBot1Motion.pathNodeIndex >= 0,
          state.destroyBot1Motion.activePathIndex.map({
              level.paths[$0].nodes.indices.contains(
                  state.destroyBot1Motion.pathNodeIndex
              )
          }) ?? (state.destroyBot1Motion.pathNodeIndex == 0),
          validTrainingDestroyBot1DestructionContinuation(
              state.destroyBot1Destruction,
              script027Count: state.script027Count,
              lesson: lesson,
              handoff: handoff,
              robotGuidebotState: robotGuidebotState,
              level: level
          )
    else {
        return false
    }
    if let destroyBot1Destruction =
            state.destroyBot1Destruction
    {
        if robotGuidebotState?.robotWasDestroyed == true {
            guard destroyBot1Destruction.script028Count > 0,
                  destroyBot1Destruction
                    .destroyBot1WasDestroyed else {
                return false
            }
        } else if destroyBot1Destruction.script028Count == 0 {
            guard robotGuidebotState?.robotShields
                    == level.trainingRobotGuidebotChain?
                        .combat.robotShields else {
                return false
            }
        } else {
            guard let robotGuidebotState,
                  !robotGuidebotState.robotWasDestroyed,
                  robotGuidebotState.robotShields >= 0 else {
                return false
            }
        }
    } else if robotGuidebotState?.robotWasDestroyed == true {
        return false
    }
    return state.script027Count > 0
        ? state.destroyBot1Motion.activePathIndex
            == handoff.movingPathIndex
            && sourceConvexRoomContains(
                state.destroyBot1Motion.position,
                in: destroyBot1Room
            )
        : state.destroyBot1Motion.activePathIndex == nil
            && state.destroyBot1Motion.position
                == destroyBot1.position
            && state.destroyBot1Motion.orientation
                == destroyBot1.orientation
            && state.destroyBot1Motion.velocity == .zero
            && state.destroyBot1Motion.pathFailure == nil
}

private func validTrainingDodgeAttemptContinuation(
    _ state: TrainingDodgeAttemptState?,
    maneuverState: TrainingManeuverFollowState?,
    shields: Float,
    level: Level
) -> Bool {
    guard let dodge = level.trainingDodgeAttempt else {
        return state == nil && shields.isFinite && shields >= 0
    }
    guard let state,
        shields.isFinite,
        shields >= 0,
        state.script033Count == 0 || state.script033Count == 1,
        state.script016Count == 0 || state.script016Count == 1,
        state.script017Count == 0 || state.script017Count == 1,
        state.script019Count == nil
            || state.script019Count == 0
            || state.script019Count == 1,
        (0...trainingScriptActionCounterMaximum).contains(
            state.script018Count
        ),
        (0...trainingScriptActionCounterMaximum).contains(
            state.script020Count
        ),
        state.markerLightDistance.isFinite,
        state.markerLightDistance
            == (maneuverState?.script021Count ?? 0 > 0
                ? 0
                : state.script017Count == 1
                || state.script019Count == 1
                ? dodge.successMarkerLightDistance : 0),
        state.firingMaskIndex >= 0,
        state.firingMaskIndex < dodge.turret.gunpoints.count,
        state.nextFireTime.isFinite,
        state.nextFireTime >= 0,
        state.turretAngles.count == dodge.turret.joints.count,
        state.turretAngles.allSatisfy({
            $0.isFinite && $0 >= 0 && $0 <= 1
        }),
        state.turretDirections.count == dodge.turret.joints.count,
        state.turretDirections.allSatisfy({
            (0...2).contains($0)
        }),
        state.retainedTargetPosition.map({
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        }) ?? true,
        state.lastVisibleTargetTime.isFinite,
        state.lastVisibleTargetTime >= -14,
        state.nextVisibilityCheckTime.isFinite,
        state.nextVisibilityCheckTime >= 0,
        state.weaponSpeed == 0
            || state.weaponSpeed == dodge.turret.projectileSpeed,
        state.awareness.isFinite,
        (0...100).contains(state.awareness),
        state.triggerTimerRemaining.map({
            $0.isFinite && $0 > 0 && $0 <= dodge.triggerDelay
        }) ?? true,
        state.successTimerRemaining.map({
            $0.isFinite && $0 > 0 && $0 <= dodge.successDelay
        }) ?? true,
        state.almostDoneTimerRemaining.map({
            $0.isFinite && $0 > 0 && $0 <= dodge.almostDoneDelay
        }) ?? true,
        state.projectiles.count
            <= trainingDodgeProjectilePresentationCapacity,
        state.projectiles.allSatisfy({ projectile in
            level.rooms.contains {
                $0.sourceIndex == projectile.roomSourceIndex
            }
                && projectile.position.x.isFinite
                && projectile.position.y.isFinite
                && projectile.position.z.isFinite
                && projectile.velocity.x.isFinite
                && projectile.velocity.y.isFinite
                && projectile.velocity.z.isFinite
                && {
                    let speed = dot(
                        projectile.velocity,
                        projectile.velocity
                    ).squareRoot()
                    let rookieSpeed =
                        dodge.turret.projectileSpeed * Float(0.75)
                    return abs(speed - rookieSpeed) <= 0.001
                        || abs(speed - dodge.turret.projectileSpeed)
                            <= 0.001
                }()
                && projectile.lifeRemaining.isFinite
                && projectile.lifeRemaining > 0
                && projectile.lifeRemaining
                    <= dodge.turret.projectileLifetime
        })
    else {
        return false
    }
    if state.script019Count == 1 && dodge.dodgeExit == nil {
        return false
    }
    if maneuverState?.script021Count ?? 0 > 0,
       state.script020Count == 0 {
        return false
    }
    if state.script018Count > 0 && state.script016Count == 0 {
        return false
    }
    if state.script020Count > state.script018Count + 1
        || (state.script020Count > 0
            && state.script016Count == 0)
    {
        return false
    }
    if state.seesTarget,
        state.retainedTargetPosition == nil
            || state.awareness < 60
    {
        return false
    }
    if state.script017Count == 1 {
        return state.script033Count == 1
            && state.script016Count == 1
            && !state.turretIsPowered
            && state.successTimerRemaining == nil
            && state.almostDoneTimerRemaining == nil
    }
    if state.script016Count == 1 {
        return state.script033Count == 1
            && state.triggerTimerRemaining == nil
            && state.successTimerRemaining != nil
            && state.turretIsPowered
            && shields == dodge.restoredPlayerShields
    }
    guard state.script018Count == 0,
        state.script020Count == 0,
        !state.turretIsPowered,
        state.successTimerRemaining == nil,
        state.almostDoneTimerRemaining == nil,
        state.nextFireTime == 0,
        state.firingMaskIndex == 0,
        state.turretAngles.allSatisfy({ $0 == 0 }),
        state.turretDirections.allSatisfy({ $0 == 0 }),
        state.retainedTargetPosition == nil,
        state.lastVisibleTargetTime == -14,
        state.nextVisibilityCheckTime == 0,
        !state.seesTarget,
        state.awareness == 0,
        state.weaponSpeed == 0,
        state.projectiles.isEmpty,
        shields == dodge.restoredPlayerShields
    else {
        return false
    }
    return state.script033Count == 0
        ? state.triggerTimerRemaining == nil
        : state.triggerTimerRemaining != nil
}

private struct TrainingDodgeGunTransform {
    let position: Vector3
    let forward: Vector3
}

private func constrainedTrainingTurretAngle(
    _ value: Float,
    fieldOfView: Float,
    movesRight: Bool
) -> Float {
    var wrapped = value
    while wrapped < 0 { wrapped += 1 }
    while wrapped > 1 { wrapped -= 1 }
    guard fieldOfView < 0.5 else { return wrapped }
    let maximum = 1 - fieldOfView
    if wrapped > fieldOfView && wrapped < maximum {
        return movesRight ? maximum : fieldOfView
    }
    return wrapped
}

private func trainingDodgeGunTransform(
    level: Level,
    dodge: TrainingDodgeAttempt,
    turret: PlacedObject,
    angles: [Float],
    restPosition: Vector3
) -> TrainingDodgeGunTransform {
    let model = level.models.first {
        $0.source == dodge.turret.model
    }!
    var chain: [Int] = []
    var current: Int? =
        dodge.turret.gunpointParentSubmodelIndex
    while let index = current {
        chain.append(index)
        current = model.submodels[index].parentIndex
    }
    chain.reverse()

    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    var origin = Vector3.zero
    var orientation = identity
    for index in chain {
        let submodel = model.submodels[index]
        origin =
            origin
            + transform(
                submodel.offset,
                by: orientation
            )
        guard
            let jointIndex = dodge.turret.joints.firstIndex(
                where: { $0.submodelIndex == index }
            )
        else {
            continue
        }
        let joint = dodge.turret.joints[jointIndex]
        let angle = angles[jointIndex] * 2 * Float.pi
        let localOrientation = Matrix3(
            right: rotate(
                .init(x: 1, y: 0, z: 0),
                around: joint.rotationAxis,
                angle: angle
            ),
            up: rotate(
                .init(x: 0, y: 1, z: 0),
                around: joint.rotationAxis,
                angle: angle
            ),
            forward: rotate(
                .init(x: 0, y: 0, z: 1),
                around: joint.rotationAxis,
                angle: angle
            )
        )
        orientation = .init(
            right: transform(
                localOrientation.right,
                by: orientation
            ),
            up: transform(
                localOrientation.up,
                by: orientation
            ),
            forward: transform(
                localOrientation.forward,
                by: orientation
            )
        )
    }
    let modelPoint =
        origin
        + transform(
            restPosition,
            by: orientation
        )
    return .init(
        position:
            turret.position
            + transform(modelPoint, by: turret.orientation),
        forward: normalized(
            transform(
                transform(dodge.turret.gunpointForward, by: orientation),
                by: turret.orientation
            ))
    )
}

private func trainingDodgeAimDot(
    level: Level,
    dodge: TrainingDodgeAttempt,
    turret: PlacedObject,
    angles: [Float],
    target: Vector3
) -> Float {
    let aim = trainingDodgeGunTransform(
        level: level,
        dodge: dodge,
        turret: turret,
        angles: angles,
        restPosition: dodge.turret.aimingGunpoint
    )
    return dot(
        aim.forward,
        normalized(target - aim.position)
    )
}

private func validPlayerConcussionContinuation(
    _ state: PlayerConcussionState?,
    gameTime: Float,
    level: Level
) -> Bool {
    guard level.shipDefinitions.first?.playerConcussion != nil else {
        return state == nil
    }
    guard let state,
          (0...6).contains(state.ammo),
          state.nextFireTime.isFinite,
          state.nextFireTime >= 0,
          (0..<2).contains(state.nextFiringMaskIndex),
          state.missiles.count <= 6,
          state.explosions.count <= 6,
          state.ammo + state.missiles.count + state.explosions.count <= 6,
          state.sparks.count <= 48 else {
        return false
    }
    let maximumFutureCreationCount =
        state.ammo * 10 + state.missiles.count * 9
    guard state.nextCreationOrdinal
            <= UInt64.max - UInt64(maximumFutureCreationCount) else {
        return false
    }
    let ordinals = state.missiles.map(\.creationOrdinal)
        + state.explosions.map(\.creationOrdinal)
        + state.sparks.map(\.creationOrdinal)
    guard Set(ordinals).count == ordinals.count,
          ordinals.allSatisfy({ $0 < state.nextCreationOrdinal }) else {
        return false
    }
    let roomIndices = Set(level.rooms.map(\.sourceIndex))
    guard state.missiles.allSatisfy({ missile in
        roomIndices.contains(missile.roomSourceIndex)
            && isCanonicalRigidTransform(
                position: missile.position,
                orientation: missile.orientation
            )
            && missile.velocity.x.isFinite
            && missile.velocity.y.isFinite
            && missile.velocity.z.isFinite
            && missile.lifeRemaining.isFinite
            && missile.lifeRemaining > 0
            && missile.lifeRemaining <= 15
    }), state.explosions.allSatisfy({ explosion in
        roomIndices.contains(explosion.roomSourceIndex)
            && explosion.position.x.isFinite
            && explosion.position.y.isFinite
            && explosion.position.z.isFinite
            && explosion.lifeRemaining.isFinite
            && explosion.lifeRemaining > 0
            && explosion.lifeRemaining <= 0.5
            && explosion.shockwaveLifeRemaining.isFinite
            && explosion.shockwaveLifeRemaining >= 0
            && explosion.shockwaveLifeRemaining <= 0.1
    }), state.sparks.allSatisfy({ spark in
        roomIndices.contains(spark.roomSourceIndex)
            && spark.position.x.isFinite && spark.position.y.isFinite
            && spark.position.z.isFinite && spark.velocity.x.isFinite
            && spark.velocity.y.isFinite && spark.velocity.z.isFinite
            && spark.size.isFinite && spark.size >= 0.7 && spark.size <= 1.06
            && spark.lifetime.isFinite
            && spark.lifetime >= 1 && spark.lifetime <= 2.35
            && spark.lifeRemaining.isFinite
            && spark.lifeRemaining >= 0
            && spark.lifeRemaining <= spark.lifetime
    }) else {
        return false
    }
    let allowedDamageHandles = Set([
        level.trainingRobotGuidebotChain?.destroyRobotObjectHandle,
        level.trainingDodgeAttempt?.maneuverFollow?.destructionHandoff?
            .followBotObjectHandle,
        level.trainingDodgeAttempt?.maneuverFollow?.destructionHandoff?
            .destroyBot1ObjectHandle,
        level.trainingRASBot1DeathChain?.robotObjectHandle,
        level.trainingRASBot2DeathChain?.robotObjectHandle,
        level.trainingRASBot3DeathChain?.robotObjectHandle,
        level.trainingRASBot4DeathChain?.robotObjectHandle,
        level.trainingLastBot1DeathChain?.robotObjectHandle,
        level.trainingLastBot2DeathChain?.robotObjectHandle,
        level.trainingLastBot3DeathChain?.robotObjectHandle,
        level.trainingLastBot4DeathChain?.robotObjectHandle,
        level.trainingLastBot5DeathChain?.robotObjectHandle,
    ].compactMap { $0 })
    return state.explosions.allSatisfy {
        $0.damagedObjectHandles.isSubset(of: allowedDamageHandles)
    } && gameTime.isFinite
}

private func validPlayerYellowFlareContinuation(
    _ state: PlayerYellowFlareState?,
    guidebotState: TrainingRobotGuidebotState?,
    gameTime: Float,
    level: Level
) -> Bool {
    guard level.shipDefinitions.first?.playerYellowFlare != nil else {
        return state == nil
    }
    guard let state,
          let playerHandle = level.defaultPlayerBinding?.objectHandle,
          let definition = level.trainingRobotGuidebotChain?.yellowFlare,
          let timeout = definition.timeout,
          state.nextFireTime.isFinite,
          state.nextFireTime >= 0,
          state.parents.count <= playerYellowFlarePresentationCapacity,
          state.parentParticles.count
            <= playerYellowFlareParticlePresentationCapacity,
          state.timeoutExplosions.count
            <= playerYellowFlareTimeoutExplosionPresentationCapacity,
          state.timeoutSparks.count
            <= playerYellowFlareTimeoutSparkPresentationCapacity,
          state.timeoutSparkParticles.count
            <= playerYellowFlareTimeoutSparkParticlePresentationCapacity
    else {
        return false
    }
    let rooms = Set(level.rooms.map(\.sourceIndex))
    let parentOrdinals = state.parents.compactMap(\.creationOrdinal)
    guard parentOrdinals.count == state.parents.count,
          Set(parentOrdinals).count == parentOrdinals.count,
          state.parents.allSatisfy({ flare in
              rooms.contains(flare.roomSourceIndex)
                  && isCanonicalRigidTransform(
                      position: flare.position,
                      orientation: flare.orientation
                  )
                  && flare.velocity.x.isFinite
                  && flare.velocity.y.isFinite
                  && flare.velocity.z.isFinite
                  && (
                      flare.velocity == .zero
                        || abs(
                            sqrt(dot(flare.velocity, flare.velocity))
                                - definition.speed
                        ) <= 0.001
                  )
                  && flare.lifeRemaining.isFinite
                  && flare.lifeRemaining >= 0
                  && flare.lifeRemaining <= definition.lifetime
                  && flare.lastParticleDropTime.isFinite
                  && flare.lastParticleDropTime
                    >= -definition.particleInterval.nextUp
                  && flare.lastParticleDropTime <= gameTime
                  && flare.presentedLightDistance.isFinite
                  && flare.presentedLightDistance
                    >= definition.lightDistance - 2
                  && flare.presentedLightDistance
                    <= definition.lightDistance + 2
                  && flare.sourceObjectSlot == nil
                  && flare.parentObjectHandle == playerHandle
                  && (
                      flare.stuckObjectHandle == nil
                        && flare.stuckObjectOffset == nil
                        && flare.stuckObjectOrientation == nil
                      || flare.stuckObjectHandle.map { handle in
                          guard flare.velocity == .zero,
                                let localPosition = flare.stuckObjectOffset,
                                let localOrientation =
                                    flare.stuckObjectOrientation,
                                localPosition.x.isFinite,
                                localPosition.y.isFinite,
                                localPosition.z.isFinite,
                                isCanonicalRigidTransform(
                                    position: .zero,
                                    orientation: localOrientation
                                ),
                                let object = level.objects.first(where: {
                                    $0.handle == handle
                                }),
                                case let .room(objectRoom) = object.location,
                                objectRoom == flare.roomSourceIndex else {
                              return false
                          }
                          return vectorDistance(
                              flare.position,
                              object.position + transform(
                                  localPosition,
                                  by: object.orientation
                              )
                          ) <= 0.001
                              && vectorDistance(
                                  flare.orientation.right,
                                  transform(
                                      localOrientation,
                                      by: object.orientation
                                  ).right
                              ) <= 0.001
                              && vectorDistance(
                                  flare.orientation.up,
                                  transform(
                                      localOrientation,
                                      by: object.orientation
                                  ).up
                              ) <= 0.001
                              && vectorDistance(
                                  flare.orientation.forward,
                                  transform(
                                      localOrientation,
                                      by: object.orientation
                                  ).forward
                              ) <= 0.001
                      } == true
                  )
          }) else {
        return false
    }

    let playerGenerationOrdinals =
        parentOrdinals
        + state.parentParticles.compactMap(\.generationOrdinal)
        + state.timeoutExplosions.compactMap(\.generationOrdinal)
        + state.timeoutSparks.compactMap(\.generationOrdinal)
        + state.timeoutSparkParticles.compactMap(\.generationOrdinal)
    let guidebotGenerationOrdinals =
        (guidebotState?.yellowFlares?.compactMap(\.creationOrdinal) ?? [])
        + (guidebotState?.yellowFlareParticles?
            .compactMap(\.generationOrdinal) ?? [])
        + (guidebotState?.yellowFlareTimeoutExplosions?
            .compactMap(\.generationOrdinal) ?? [])
        + (guidebotState?.yellowFlareTimeoutSparks?
            .compactMap(\.generationOrdinal) ?? [])
        + (guidebotState?.yellowFlareTimeoutSparkParticles?
            .compactMap(\.generationOrdinal) ?? [])
    guard state.nextCreationOrdinal < UInt64.max,
    (playerGenerationOrdinals + guidebotGenerationOrdinals).allSatisfy({
        $0 < state.nextCreationOrdinal
    }),
    Set(playerGenerationOrdinals).isDisjoint(
        with: Set(guidebotGenerationOrdinals)
    ),
    guidebotState?.yellowFlares?.allSatisfy({
        $0.creationOrdinal != nil
    }) ?? true,
    guidebotState?.yellowFlareParticles?.allSatisfy({
        $0.generationOrdinal != nil
    }) ?? true,
    guidebotState?.yellowFlareTimeoutExplosions?.allSatisfy({
        $0.generationOrdinal != nil
    }) ?? true,
    guidebotState?.yellowFlareTimeoutSparks?.allSatisfy({
        $0.generationOrdinal != nil
    }) ?? true,
    guidebotState?.yellowFlareTimeoutSparkParticles?.allSatisfy({
        $0.generationOrdinal != nil
    }) ?? true else {
        return false
    }

    func validParticle(
        _ particle: TrainingGuidebotYellowFlareParticleState,
        sourceSize: Float,
        sourceLifetime: Float
    ) -> Bool {
        rooms.contains(particle.roomSourceIndex)
            && particle.position.x.isFinite
            && particle.position.y.isFinite
            && particle.position.z.isFinite
            && particle.velocity.x.isFinite
            && particle.velocity.y.isFinite
            && particle.velocity.z.isFinite
            && particle.size.isFinite
            && particle.size >= sourceSize * 0.5
            && particle.size <= sourceSize * 1.5
            && particle.lifetime.isFinite
            && particle.lifetime >= sourceLifetime * 0.5
            && particle.lifetime <= sourceLifetime * 1.5
            && particle.lifeRemaining.isFinite
            && particle.lifeRemaining >= 0
            && particle.lifeRemaining <= particle.lifetime
            && particle.creationTime.map {
                $0.isFinite && $0 >= 0 && $0 <= gameTime
            } == true
            && particle.generationOrdinal != nil
    }
    guard state.parentParticles.allSatisfy({
        validParticle(
            $0,
            sourceSize: definition.particleSize,
            sourceLifetime: definition.particleLifetime
        ) && $0.sourceAttemptIndex == nil
    }),
    state.timeoutSparkParticles.allSatisfy({
        validParticle(
            $0,
            sourceSize: timeout.childParticleSize,
            sourceLifetime: timeout.childParticleLifetime
        ) && $0.sourceAttemptIndex.map {
            (0..<timeout.childCount).contains($0)
        } == true
    }),
    state.timeoutExplosions.allSatisfy({ explosion in
        rooms.contains(explosion.roomSourceIndex)
            && explosion.position.x.isFinite
            && explosion.position.y.isFinite
            && explosion.position.z.isFinite
            && explosion.size == timeout.explosionSize
            && explosion.lifetime == timeout.explosionLifetime
            && explosion.lifeRemaining.isFinite
            && explosion.lifeRemaining >= 0
            && explosion.lifeRemaining <= explosion.lifetime
            && explosion.creationTime.map {
                $0.isFinite && $0 >= 0 && $0 <= gameTime
            } == true
            && explosion.generationOrdinal != nil
    }),
    state.timeoutSparks.allSatisfy({ spark in
        (0..<timeout.childCount).contains(spark.sourceAttemptIndex)
            && spark.sourceObjectSlot == spark.sourceAttemptIndex
            && spark.receivedControlOnCreationFrame
            && rooms.contains(spark.roomSourceIndex)
            && isCanonicalRigidTransform(
                position: spark.position,
                orientation: spark.orientation
            )
            && spark.velocity.x.isFinite
            && spark.velocity.y.isFinite
            && spark.velocity.z.isFinite
            && spark.lifeRemaining.isFinite
            && spark.lifeRemaining >= 0
            && spark.lifeRemaining <= timeout.childLifetime
            && spark.lastParticleDropTime.isFinite
            && spark.lastParticleDropTime >= 0
            && spark.lastParticleDropTime <= gameTime
            && spark.presentedLightDistance
                == timeout.childLightDistance
            && spark.generationOrdinal != nil
    }) else {
        return false
    }
    let groupedSparkAttempts = Dictionary(
        grouping: state.timeoutSparks,
        by: { $0.generationOrdinal! }
    ).values.map { $0.map(\.sourceAttemptIndex).sorted() }
    guard groupedSparkAttempts.allSatisfy({
        $0 == Array(0..<timeout.childCount)
    }) else {
        return false
    }
    return true
}

private func validTrainingRobotGuidebotContinuation(
    _ state: TrainingRobotGuidebotState?,
    galleryState: TrainingGalleryBarrierState?,
    cameraState: TrainingCameraMonitorState?,
    playerLocation: SpatialLocation,
    playerPosition: Vector3,
    gameTime: Float,
    level: Level
) -> Bool {
    guard let chain = level.trainingRobotGuidebotChain else {
        return state == nil
    }
    let roomSourceIndices = Set(level.rooms.map(\.sourceIndex))
    guard let state,
          state.robotShields.isFinite,
          state.robotShields <= chain.combat.robotShields,
          state.nextPrimaryFireTime.isFinite,
          state.nextPrimaryFireTime >= 0,
          state.projectiles.allSatisfy({
              roomSourceIndices.contains($0.roomSourceIndex)
                  && $0.position.x.isFinite
                  && $0.position.y.isFinite
                  && $0.position.z.isFinite
                  && containingIndoorRoomSourceIndex(
                      in: level,
                      position: $0.position,
                      candidates: [$0.roomSourceIndex]
                  ) == $0.roomSourceIndex
                  && $0.velocity.x.isFinite
                  && $0.velocity.y.isFinite
                  && $0.velocity.z.isFinite
                  && $0.lifeRemaining.isFinite
                  && $0.lifeRemaining > 0
                  && $0.lifeRemaining <= chain.combat.projectileLifetime
          }),
          state.guidebotIsDeployed == (state.guidebot != nil),
          state.guidebot.map({
              roomSourceIndices.contains($0.roomSourceIndex)
                  && isCanonicalRigidTransform(
                      position: $0.spawnPosition,
                      orientation: $0.orientation
                  )
                  && $0.allocationStartPosition.x.isFinite
                  && $0.allocationStartPosition.y.isFinite
                  && $0.allocationStartPosition.z.isFinite
                  && $0.allocationStartForward.x.isFinite
                  && $0.allocationStartForward.y.isFinite
                  && $0.allocationStartForward.z.isFinite
                  && abs(
                      dot(
                          $0.allocationStartForward,
                          $0.allocationStartForward
                      ) - 1
                  ) < 0.000_1
                  && $0.spawnVelocity.x.isFinite
                  && $0.spawnVelocity.y.isFinite
                  && $0.spawnVelocity.z.isFinite
                  && $0.position.x.isFinite
                  && $0.position.y.isFinite
                  && $0.position.z.isFinite
                  && (
                      containingIndoorRoomSourceIndex(
                          in: level,
                          position: $0.position,
                          candidates: [$0.roomSourceIndex]
                      ) == $0.roomSourceIndex
                        || (
                            cameraState?.script058WasPresented == true
                                && state.guidebotMode == .birth
                                && state.guidebotModeTime == 0
                                && $0.task == .outbound
                                && $0.position == $0.spawnPosition
                                && $0.spawnPosition == playerPosition
                                && $0.spawnPosition
                                    == $0.allocationStartPosition
                                && playerLocation
                                    == .room($0.roomSourceIndex)
                                && $0.roomSourceIndex
                                    == $0.route.roomSourceIndices.first
                        )
                        || validTrainingGuidebotReleaseOutboundPosition(
                            guidebot: $0,
                            mode: state.guidebotMode,
                            cameraState: cameraState,
                            level: level
                        )
                  )
                  && $0.velocity.x.isFinite
                  && $0.velocity.y.isFinite
                  && $0.velocity.z.isFinite
                  && $0.destination.x.isFinite
                  && $0.destination.y.isFinite
                  && $0.destination.z.isFinite
                  && $0.routeDestination.x.isFinite
                  && $0.routeDestination.y.isFinite
                  && $0.routeDestination.z.isFinite
                  && roomSourceIndices.contains(
                      $0.routeDestinationRoomSourceIndex
                  )
                  && !$0.route.points.isEmpty
                  && $0.route.points.allSatisfy {
                      $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
                  }
                  && !$0.route.roomSourceIndices.isEmpty
                  && $0.route.roomSourceIndices.allSatisfy(
                      roomSourceIndices.contains
                  )
                  && $0.route.points.indices.contains($0.routePointIndex)
                  && validTrainingGuidebotSteeringState($0)
                  && (
                      validTrainingGuidebotRoute(
                          guidebot: $0,
                          level: level,
                          collisionRadius: chain.guidebot.collisionRadius
                      )
                        || validTrainingGuidebotReleaseOutboundPosition(
                            guidebot: $0,
                            mode: state.guidebotMode,
                            cameraState: cameraState,
                            level: level
                        )
                        || (
                            cameraState?.script058WasPresented == true
                                && state.guidebotMode == .birth
                                && state.guidebotModeTime == 0
                                && $0.task == .outbound
                                && $0.position == $0.spawnPosition
                                && $0.routeFailure == nil
                                && $0.route.mode == .direct
                                && $0.route.points == [$0.destination]
                                && $0.route.roomSourceIndices
                                    == [$0.routeDestinationRoomSourceIndex]
                                && $0.route.nodeReferences.isEmpty
                        )
                  )
          }) ?? true,
          state.controlsWereRestored
            ? state.robotWasDestroyed
                || state.guidebotContinuationWasPresented
            : !state.guidebotContinuationWasPresented
                && (
                    !state.robotWasDestroyed
                        || galleryState?.wasTriggered == true
                ),
          state.enabledControlHUDIsVisible
            != state.destructionFeedbackWasPresented
    else {
        return false
    }
    if let definition = chain.yellowFlare {
        let usesLegacySilentState =
            state.yellowFlares == nil
                && state.yellowFlareParticles == nil
                && state.yellowFlareGoalSlots == nil
        if !usesLegacySilentState {
            guard let flares = state.yellowFlares,
                  let particles = state.yellowFlareParticles,
                  flares.count
                    <= trainingGuidebotYellowFlarePresentationCapacity,
                  particles.count
                    <= trainingGuidebotYellowFlareParticlePresentationCapacity,
                  flares.allSatisfy({ flare in
                      roomSourceIndices.contains(flare.roomSourceIndex)
                          && containingIndoorRoomSourceIndex(
                              in: level,
                              position: flare.position,
                              candidates: [flare.roomSourceIndex]
                          ) == flare.roomSourceIndex
                          && isCanonicalRigidTransform(
                              position: flare.position,
                              orientation: flare.orientation
                          )
                          && flare.velocity.x.isFinite
                          && flare.velocity.y.isFinite
                          && flare.velocity.z.isFinite
                          && (
                              flare.velocity == .zero
                                  || abs(
                                      sqrt(dot(
                                          flare.velocity,
                                          flare.velocity
                                      )) - definition.speed
                                  ) <= 0.001
                          )
                          && flare.lifeRemaining.isFinite
                          && flare.lifeRemaining >= 0
                          && flare.lifeRemaining <= definition.lifetime
                          && flare.lastParticleDropTime.isFinite
                          && flare.lastParticleDropTime >= 0
                          && flare.lastParticleDropTime <= gameTime
                          && flare.presentedLightDistance.isFinite
                          && flare.presentedLightDistance
                            >= definition.lightDistance - 2
                          && flare.presentedLightDistance
                            <= definition.lightDistance + 2
                          && (
                              flare.sourceObjectSlot == nil
                                  || flare.sourceObjectSlot == 16
                          )
                          && (
                              flare.creationOrdinal == nil
                                || flare.parentObjectHandle
                                    == chain.guidebotObjectHandle
                          )
                          && (
                              flare.stuckObjectHandle == nil
                                  && flare.stuckObjectOffset == nil
                                  && flare.stuckObjectOrientation == nil
                              || flare.stuckObjectHandle.map { handle in
                                  guard flare.velocity == .zero,
                                        let localPosition =
                                            flare.stuckObjectOffset,
                                        let localOrientation =
                                            flare.stuckObjectOrientation,
                                        localPosition.x.isFinite,
                                        localPosition.y.isFinite,
                                        localPosition.z.isFinite,
                                        isCanonicalRigidTransform(
                                            position: .zero,
                                            orientation: localOrientation
                                        ),
                                        let object = level.objects.first(
                                            where: { $0.handle == handle }
                                        ),
                                        case let .room(objectRoom) =
                                            object.location,
                                        objectRoom == flare.roomSourceIndex
                                  else {
                                      return false
                                  }
                                  let expectedPosition =
                                      object.position
                                      + transform(
                                          localPosition,
                                          by: object.orientation
                                      )
                                  let expectedOrientation = transform(
                                      localOrientation,
                                      by: object.orientation
                                  )
                                  return vectorDistance(
                                      flare.position,
                                      expectedPosition
                                  ) <= 0.001
                                      && vectorDistance(
                                          flare.orientation.right,
                                          expectedOrientation.right
                                      ) <= 0.001
                                      && vectorDistance(
                                          flare.orientation.up,
                                          expectedOrientation.up
                                      ) <= 0.001
                                      && vectorDistance(
                                          flare.orientation.forward,
                                          expectedOrientation.forward
                                      ) <= 0.001
                              } == true
                          )
                  }),
                  particles.allSatisfy({ particle in
                      roomSourceIndices.contains(
                          particle.roomSourceIndex
                      )
                          && particle.position.x.isFinite
                          && particle.position.y.isFinite
                          && particle.position.z.isFinite
                          && particle.velocity.x.isFinite
                          && particle.velocity.y.isFinite
                          && particle.velocity.z.isFinite
                          && particle.size.isFinite
                          && particle.size >= definition.particleSize * 0.5
                          && particle.size <= definition.particleSize * 1.5
                          && particle.lifetime.isFinite
                          && particle.lifetime
                            >= definition.particleLifetime * 0.5
                          && particle.lifetime
                            <= definition.particleLifetime * 1.5
                          && particle.lifeRemaining.isFinite
                          && particle.lifeRemaining >= 0
                          && particle.lifeRemaining <= particle.lifetime
                          && (
                              definition.timeout?.childAnimationFrames == nil
                                  || particle.creationTime.map {
                                      $0.isFinite
                                          && $0 >= 0
                                          && $0 <= gameTime
                                  } == true
                          )
                  }) else {
                return false
            }
            if let slots = state.yellowFlareGoalSlots {
                guard state.guidebot != nil,
                      !state.guidebotEnteredShip,
                      !slots.slot2IsUsed || slots.slot1IsUsed,
                      !slots.slot3IsUsed
                        || slots.slot1IsUsed && slots.slot2IsUsed
                else {
                    return false
                }
            } else if state.guidebot != nil {
                return false
            }
        }
        if let timeout = definition.timeout {
            let usesLegacySilentTimeoutState =
                state.yellowFlareTimeoutExplosions == nil
                    && state.yellowFlareTimeoutSparks == nil
                    && state.yellowFlareTimeoutSparkParticles == nil
                    && state.yellowFlareTimeoutReachedFollowingFrame == nil
            if !usesLegacySilentTimeoutState {
                guard let explosions = state.yellowFlareTimeoutExplosions,
                      let sparks = state.yellowFlareTimeoutSparks,
                      let sparkParticles =
                        state.yellowFlareTimeoutSparkParticles,
                      let reachedFollowingFrame =
                        state.yellowFlareTimeoutReachedFollowingFrame
                else {
                    return false
                }
                let sourceSlots = [17, 8, 41, 42, 43, 44, 45, 46, 47]
                let sortedSparkAttempts = sparks.map(\.sourceAttemptIndex)
                    .sorted()
                let lifecycleSubsetIsValid =
                    sortedSparkAttempts == Array(0..<timeout.childCount)
                        || sortedSparkAttempts == [1]
                        || sortedSparkAttempts.isEmpty
                let firstParentCount = state.yellowFlares?.filter {
                    $0.sourceObjectSlot != nil
                }.count ?? 0
                let generationStateIsValid: Bool
                if reachedFollowingFrame {
                    if sortedSparkAttempts
                        == Array(0..<timeout.childCount) {
                        generationStateIsValid = lifecycleSubsetIsValid
                            && explosions.count == 1
                            && sparkParticles.count >= 8
                    } else {
                        generationStateIsValid = lifecycleSubsetIsValid
                            && explosions.isEmpty
                    }
                } else {
                    generationStateIsValid = explosions.isEmpty
                        && sparks.isEmpty
                        && sparkParticles.isEmpty
                }
                guard generationStateIsValid,
                      firstParentCount <= 1,
                      !reachedFollowingFrame || firstParentCount == 0,
                      state.yellowFlares?.allSatisfy({
                          $0.sourceObjectSlot == nil
                              || (!reachedFollowingFrame
                                  && $0.sourceObjectSlot == 16)
                      }) == true,
                      explosions.count
                        <= trainingGuidebotYellowFlareTimeoutExplosionPresentationCapacity,
                      sparks.count
                        <= trainingGuidebotYellowFlareTimeoutSparkPresentationCapacity,
                      sparkParticles.count
                        <= trainingGuidebotYellowFlareTimeoutSparkParticlePresentationCapacity,
                      explosions.allSatisfy({
                          roomSourceIndices.contains($0.roomSourceIndex)
                              && containingIndoorRoomSourceIndex(
                                  in: level,
                                  position: $0.position,
                                  candidates: [$0.roomSourceIndex]
                              ) == $0.roomSourceIndex
                              && $0.size == timeout.explosionSize
                              && $0.lifetime == timeout.explosionLifetime
                              && $0.lifeRemaining.isFinite
                              && $0.lifeRemaining >= 0
                              && $0.lifeRemaining <= $0.lifetime
                              && (
                                  timeout.childAnimationFrames == nil
                                      || $0.creationTime.map {
                                          $0.isFinite
                                              && $0 >= 0
                                              && $0 <= gameTime
                                      } == true
                              )
                      }),
                      Set(sparks.map(\.sourceAttemptIndex)).count
                        == sparks.count,
                      Set(sparks.map(\.sourceObjectSlot)).count
                        == sparks.count,
                      sparks.allSatisfy({ spark in
                          (0..<timeout.childCount).contains(
                              spark.sourceAttemptIndex
                          )
                              && sourceSlots[
                                  spark.sourceAttemptIndex
                              ] == spark.sourceObjectSlot
                              && spark.receivedControlOnCreationFrame
                                == (spark.sourceObjectSlot > 16)
                              && roomSourceIndices.contains(
                                  spark.roomSourceIndex
                              )
                              && containingIndoorRoomSourceIndex(
                                  in: level,
                                  position: spark.position,
                                  candidates: [spark.roomSourceIndex]
                              ) == spark.roomSourceIndex
                              && isCanonicalRigidTransform(
                                  position: spark.position,
                                  orientation: spark.orientation
                              )
                              && spark.velocity.x.isFinite
                              && spark.velocity.y.isFinite
                              && spark.velocity.z.isFinite
                              && sqrt(dot(spark.velocity, spark.velocity))
                                <= timeout.childSpeed
                                    + abs(
                                        level.metadata.gravity
                                            * timeout.childMass
                                            / timeout.childDrag
                                    )
                              && spark.lifeRemaining.isFinite
                              && spark.lifeRemaining >= 0
                              && spark.lifeRemaining <= timeout.childLifetime
                              && spark.lastParticleDropTime.isFinite
                              && spark.lastParticleDropTime >= 0
                              && spark.lastParticleDropTime <= gameTime
                              && spark.presentedLightDistance
                                == timeout.childLightDistance
                      }),
                      sparkParticles.allSatisfy({ particle in
                          roomSourceIndices.contains(
                              particle.roomSourceIndex
                          )
                              && particle.position.x.isFinite
                              && particle.position.y.isFinite
                              && particle.position.z.isFinite
                              && particle.velocity.x.isFinite
                              && particle.velocity.y.isFinite
                              && particle.velocity.z.isFinite
                              && particle.size.isFinite
                              && particle.size
                                >= timeout.childParticleSize * 0.5
                              && particle.size
                                <= timeout.childParticleSize * 1.5
                              && particle.lifetime.isFinite
                              && particle.lifetime
                                >= timeout.childParticleLifetime * 0.5
                              && particle.lifetime
                                <= timeout.childParticleLifetime * 1.5
                              && particle.lifeRemaining.isFinite
                              && particle.lifeRemaining >= 0
                              && particle.lifeRemaining <= particle.lifetime
                              && (
                                  timeout.childAnimationFrames == nil
                                      || particle.creationTime.map {
                                          $0.isFinite
                                              && $0 >= 0
                                              && $0 <= gameTime
                                      } == true
                              )
                      }) else {
                    return false
                }
            }
        } else if state.yellowFlareTimeoutExplosions != nil
                    || state.yellowFlareTimeoutSparks != nil
                    || state.yellowFlareTimeoutSparkParticles != nil
                    || state.yellowFlareTimeoutReachedFollowingFrame != nil {
            return false
        }
    } else if state.yellowFlares != nil
                || state.yellowFlareParticles != nil
                || state.yellowFlareGoalSlots != nil
                || state.yellowFlareTimeoutExplosions != nil
                || state.yellowFlareTimeoutSparks != nil
                || state.yellowFlareTimeoutSparkParticles != nil
                || state.yellowFlareTimeoutReachedFollowingFrame != nil {
        return false
    }
    let hasAnyGuidebotTiming =
        state.guidebotMode != nil
        || state.guidebotModeTime != nil
        || state.nextAmbientTime != nil
        || state.timeUntilNextPlayerVisibilityCheck != nil
        || state.timeUntilNextFlare != nil
        || state.nextPowerupCheckTime != nil
        || state.returnTime != nil
        || state.returnGreetingWasPresented != nil
    if state.guidebot != nil
        || state.guidebotEnteredShip
        || hasAnyGuidebotTiming
    {
        guard state.guidebotMode != nil,
              let modeTime = state.guidebotModeTime,
              modeTime.isFinite,
              modeTime >= 0,
              let nextAmbientTime = state.nextAmbientTime,
              nextAmbientTime.isFinite,
              nextAmbientTime >= 0,
              let visibility =
                state.timeUntilNextPlayerVisibilityCheck,
              visibility.isFinite,
              visibility > 0,
              visibility <= 1,
              let flare = state.timeUntilNextFlare,
              flare.isFinite,
              flare > 0,
              flare <= 4,
              let nextPowerupTime = state.nextPowerupCheckTime,
              nextPowerupTime.isFinite,
              nextPowerupTime >= 0,
              let lastSoundTime = state.lastMessageSoundTime,
              lastSoundTime.isFinite,
              lastSoundTime >= 0,
              lastSoundTime <= gameTime,
              let returnTime = state.returnTime,
              returnTime.isFinite,
              returnTime >= 0,
              state.returnGreetingWasPresented != nil
        else {
            return false
        }
    } else if let lastSoundTime = state.lastMessageSoundTime,
              (
                !lastSoundTime.isFinite
                    || lastSoundTime < 0
                    || lastSoundTime > gameTime
              ) {
        return false
    }
    if state.guidebotContinuationWasPresented
        && (
            (!state.guidebotIsDeployed && !state.guidebotEnteredShip)
                || galleryState?.wasTriggered != true
        ) {
        return false
    }
    if state.returnWasRequested {
        guard cameraState?.wasUsed == true,
              state.guidebotEnteredShip
                || state.guidebot?.task == .returnToShip
        else {
            return false
        }
    } else if state.guidebotEnteredShip
                || state.arrivalFeedbackWasPresented
                || state.guidebot?.task == .returnToShip {
        return false
    }
    if let guidebot = state.guidebot {
        switch guidebot.task {
        case .outbound:
            break
        case .activeGoal:
            guard state.guidebotContinuationWasPresented,
                  state.activeGoalWasReached == false,
                  let cameraState,
                  !cameraState.wasUsed,
                  !cameraState.script058WasPresented,
                  let target = cameraState.isHeld
                    ? trainingCameraMonitorObjectTarget(in: level)
                    : trainingCameraMonitorGoalTarget(in: level),
                  case let .room(targetRoomSourceIndex) =
                    target.location,
                  guidebot.destination == target.position,
                  guidebot.routeDestination == target.position,
                  guidebot.routeDestinationRoomSourceIndex
                    == targetRoomSourceIndex
            else {
                return false
            }
        case .returnToPlayer:
            guard state.guidebotContinuationWasPresented,
                  state.activeGoalWasReached == true,
                  state.returnGreetingWasPresented == false,
                  cameraState?.script058WasPresented == false,
                  !state.returnWasRequested,
                  !state.guidebotEnteredShip,
                  case let .room(playerRoomSourceIndex) =
                    playerLocation,
                  guidebot.destination == playerPosition,
                  guidebot.routeDestinationRoomSourceIndex
                    == playerRoomSourceIndex
            else {
                return false
            }
        case .escortPlayer:
            guard state.guidebotContinuationWasPresented,
                  state.activeGoalWasReached == true,
                  state.returnGreetingWasPresented == true,
                  state.guidebotMode == .ambient,
                  !state.returnWasRequested,
                  !state.guidebotEnteredShip,
                  cameraState?.script058WasPresented == false,
                  guidebot.destination == playerPosition,
                  let flare = state.timeUntilNextFlare,
                  flare >= 3,
                  flare <= 4
            else {
                return false
            }
        case .returnToShip:
            break
        }
        if guidebot.task != .escortPlayer,
           state.returnGreetingWasPresented == true {
            return false
        }
    } else if state.returnGreetingWasPresented == true {
        return false
    }
    if state.guidebotEnteredShip {
        guard !state.guidebotIsDeployed,
              state.guidebot == nil,
              state.arrivalFeedbackWasPresented,
              cameraState?.script058WasPresented == true else {
            return false
        }
    } else if cameraState?.script058WasPresented == true {
        guard state.guidebotIsDeployed,
              let guidebot = state.guidebot,
              guidebot.task == .outbound,
              state.guidebotMode == .birth
                || state.guidebotMode == .ambient,
              guidebot.spawnPosition == guidebot.allocationStartPosition,
              guidebot.orientation.forward
                == guidebot.allocationStartForward,
              guidebot.destination
                == guidebot.allocationStartPosition
                    + guidebot.allocationStartForward
                        * chain.guidebot.goalForwardDistance,
              guidebot.routeDestination == guidebot.destination,
              guidebot.routeDestinationRoomSourceIndex
                == guidebot.route.roomSourceIndices.first
        else {
            return false
        }
        if state.guidebotMode == .birth,
           state.guidebotModeTime == 0 {
            guard guidebot.position == guidebot.spawnPosition,
                  guidebot.spawnPosition == playerPosition,
                  playerLocation == .room(guidebot.roomSourceIndex),
                  guidebot.roomSourceIndex
                    == guidebot.route.roomSourceIndices.first
            else {
                return false
            }
        }
    }
    if state.robotWasDestroyed {
        guard state.robotShields < 0,
              state.destructionFeedbackWasPresented
                == (state.destructionTimerRemaining == nil)
        else {
            return false
        }
        if let timer = state.destructionTimerRemaining {
            return timer.isFinite && timer > 0
                && timer <= chain.destructionDelay
        }
    } else if state.destructionTimerRemaining != nil
                || state.destructionFeedbackWasPresented
                || state.robotShields < 0 {
        return false
    }
    return true
}

private func validTrainingGuidebotReleaseOutboundPosition(
    guidebot: TrainingGuidebotRuntimeState,
    mode: TrainingGuidebotMode?,
    cameraState: TrainingCameraMonitorState?,
    level: Level
) -> Bool {
    guard cameraState?.script058WasPresented == true,
          mode == .ambient,
          guidebot.task == .outbound,
          guidebot.roomSourceIndex
            == guidebot.route.roomSourceIndices.first,
          guidebot.route.mode == .direct,
          guidebot.route.points == [guidebot.destination],
          guidebot.routeFailure == nil,
          guidebot.route.roomSourceIndices
            == [guidebot.routeDestinationRoomSourceIndex],
          guidebot.route.nodeReferences.isEmpty,
          guidebot.spawnPosition == guidebot.allocationStartPosition,
          let room = level.rooms.first(where: {
              $0.sourceIndex == guidebot.roomSourceIndex
          }),
          sourceConvexRoomContains(
              guidebot.allocationStartPosition,
              in: room
          )
    else {
        return false
    }
    let segment = guidebot.destination - guidebot.allocationStartPosition
    let segmentLengthSquared = dot(segment, segment)
    guard segmentLengthSquared > 0 else {
        return guidebot.position == guidebot.allocationStartPosition
    }
    let offset = guidebot.position - guidebot.allocationStartPosition
    let progress = dot(offset, segment) / segmentLengthSquared
    let residual = offset - segment * progress
    return progress >= 0
        && progress <= 1
        && dot(residual, residual) <= 0.000_001
}

private func validTrainingCameraMonitorContinuation(
    _ state: TrainingCameraMonitorState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingCameraMonitorChain else {
        return state == nil
    }
    guard let state,
          !(state.isHeld && state.wasUsed),
          state.popupRemaining.map({
              $0.isFinite && $0 >= 0 && $0 <= chain.popupDuration
          }) ?? true,
          state.completionTimerRemaining.map({
              $0.isFinite
                  && $0 > 0
                  && $0 <= chain.completionTimerDuration
          }) ?? true,
          state.returnMarkerLightDistance.isFinite,
          state.returnMarkerLightDistance >= 0 else {
        return false
    }
    if let returnChain = chain.returnToShip {
        guard state.script058WasPresented
                ? state.returnMarkerLightDistance
                    == returnChain.openMarkerLightDistance
                : state.returnMarkerLightDistance == 0
        else {
            return false
        }
    } else if state.script058WasPresented
                || state.returnMarkerLightDistance != 0 {
        return false
    }
    if state.wasUsed {
        return !state.isHeld
            && !level.objects.contains {
                $0.handle == chain.pickupObjectHandle
            }
            && (
                state.completionTimerRemaining != nil
                    || state.completionTimerWasConsumed
            )
    }
    return state.popupRemaining == nil
        && state.completionTimerRemaining == nil
        && !state.completionTimerWasConsumed
        && level.objects.contains {
            $0.handle == chain.pickupObjectHandle
        }
}

private func validTrainingKillbotEntryContinuation(
    _ state: TrainingKillbotEntryState?,
    level: Level
) -> Bool {
    guard let chain =
            level.trainingCameraMonitorChain?.returnToShip?.killbotEntry
    else {
        return state == nil
    }
    guard let state else { return false }
    if state.wasTriggered {
        guard trainingKillbotEntryBarrierRendersFaces(in: level),
              state.followupWasPresented
                == (state.followupTimerRemaining == nil) else {
            return false
        }
        return state.followupTimerRemaining.map {
            $0.isFinite && $0 > 0 && $0 <= chain.followupDelay
        } ?? true
    }
    return state.followupTimerRemaining == nil
        && !state.followupWasPresented
}

private func validTrainingRASBot1DeathContinuation(
    _ state: TrainingRASBot1DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot1DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingRASBot2DeathContinuation(
    _ state: TrainingRASBot2DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot2DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingRASBot3DeathContinuation(
    _ state: TrainingRASBot3DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot3DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingRASBot4DeathContinuation(
    _ state: TrainingRASBot4DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot4DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot1DeathContinuation(
    _ state: TrainingLastBot1DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot1DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot2DeathContinuation(
    _ state: TrainingLastBot2DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot2DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot3DeathContinuation(
    _ state: TrainingLastBot3DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot3DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot4DeathContinuation(
    _ state: TrainingLastBot4DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot4DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot5DeathContinuation(
    _ state: TrainingLastBot5DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot5DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingInvulnerabilityPickupContinuation(
    _ state: TrainingInvulnerabilityPickupState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingInvulnerabilityPickupChain else {
        return state == nil
    }
    guard let state,
        state.remainingDuration.map({
            $0.isFinite && $0 > 0 && $0 <= chain.duration
        }) ?? true,
        !state.wasConsumed || state.scriptWasTriggered,
        state.remainingDuration == nil || state.wasConsumed
    else {
        return false
    }
    let pickupIsPresent = level.objects.contains {
        $0.handle == chain.pickupObjectHandle
    }
    if state.wasConsumed {
        return !pickupIsPresent
    }
    return pickupIsPresent
        && state.remainingDuration == nil
}

private func validTrainingCloakPickupContinuation(
    _ state: TrainingCloakPickupState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingCloakPickupChain else {
        return state == nil
    }
    guard let state,
        !state.wasConsumed || state.scriptWasTriggered,
        (state.phase == nil) == (state.phaseRemaining == nil),
        state.phaseRemaining.map({
            $0.isFinite && $0 > 0
                && $0 <= (
                    state.phase == .cloaked
                        ? chain.cloakDuration
                        : chain.fadeDuration
                )
        }) ?? true,
        state.phase == nil || state.wasConsumed
    else {
        return false
    }
    let pickupIsPresent = level.objects.contains {
        $0.handle == chain.pickupObjectHandle
    }
    return state.wasConsumed ? !pickupIsPresent : pickupIsPresent
}

private func validTrainingLastRoomContinuation(
    _ state: TrainingLastRoomState?,
    finalRoomEntryWasTriggered: Bool,
    allProducersWereTriggered: Bool,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastRoomChain else {
        return state == nil
    }
    guard let state,
        state.markerLightDistance.isFinite,
        state.timerRemaining.map({
            $0.isFinite && $0 > 0 && $0 <= chain.timerDuration
        }) ?? true
    else {
        return false
    }
    if !state.wasTriggered {
        return state.markerLightDistance == 0
            && state.timerRemaining == nil
            && !state.wasPresented
    }
    guard allProducersWereTriggered else { return false }
    let room = level.rooms.first {
        $0.sourceIndex == chain.barrierRoomSourceIndex
    }!
    let expectedMarkerDistance: Float =
        finalRoomEntryWasTriggered ? 0 : chain.openMarkerLightDistance
    let expectedPortalFlag: UInt32 =
        finalRoomEntryWasTriggered ? 1 : 0
    return state.markerLightDistance == expectedMarkerDistance
        && chain.orderedPortalIndices.allSatisfy {
            room.portals[$0].flags & 1 == expectedPortalFlag
        }
        && (state.wasPresented
            ? state.timerRemaining == nil
            : state.timerRemaining != nil)
}

private func validTrainingFinalBotsCompletionContinuation(
    _ state: TrainingFinalBotsCompletionState?,
    allProducersWereDestroyed: Bool,
    level: Level
) -> Bool {
    guard let chain = level.trainingFinalBotsCompletionChain else {
        return state == nil
    }
    guard let state,
          state.markerLightDistance.isFinite,
          state.timerRemaining.map({
              $0.isFinite && $0 > 0
                  && $0 <= chain.timerDuration
          }) ?? true
    else {
        return false
    }
    if !state.wasTriggered {
        return state.markerLightDistance == 0
            && state.timerRemaining == nil
            && !state.wasPresented
    }
    guard allProducersWereDestroyed,
          state.markerLightDistance
            == chain.openMarkerLightDistance,
          let room = level.rooms.first(where: {
              $0.sourceIndex == chain.barrierRoomSourceIndex
          }),
          chain.orderedPortalIndices.allSatisfy({
              let portal = room.portals[$0]
              guard portal.flags & 1 == 0,
                    let connected = level.rooms.first(where: {
                        $0.sourceIndex == portal.connectedRoom
                    })
              else {
                  return false
              }
              return connected.portals[portal.connectedPortal].flags
                  & 1 == 0
          })
    else {
        return false
    }
    return state.wasPresented
        ? state.timerRemaining == nil
        : state.timerRemaining != nil
}

private func validTrainingFinalGoalContinuation(
    _ state: TrainingFinalGoalState?,
    finalBotsState: TrainingFinalBotsCompletionState?,
    level: Level
) -> Bool {
    guard level.trainingFinalGoalChain != nil else {
        return state == nil
    }
    guard let state else { return false }
    if state.endLevelWasRequested {
        return state.scriptActionCounter == 1
            && finalBotsState?.wasTriggered == true
    }
    return state.scriptActionCounter == 0
}

private func validTrainingFinalRoomEntryContinuation(
    _ state: TrainingFinalRoomEntryState?,
    lastRoomState: TrainingLastRoomState?,
    level: Level
) -> Bool {
    guard level.trainingFinalRoomEntryChain != nil else {
        return state == nil
    }
    guard let state else { return false }
    if !state.wasTriggered {
        return true
    }
    guard lastRoomState?.wasTriggered == true,
        lastRoomState?.markerLightDistance == 0,
        let lastRoom = level.trainingLastRoomChain,
        let room = level.rooms.first(where: {
            $0.sourceIndex == lastRoom.barrierRoomSourceIndex
        })
    else {
        return false
    }
    return lastRoom.orderedPortalIndices.allSatisfy { portalIndex in
        let portal = room.portals[portalIndex]
        guard portal.flags & 1 != 0,
            let connectedRoom = level.rooms.first(where: {
                $0.sourceIndex == portal.connectedRoom
            }),
            connectedRoom.portals.indices.contains(
                portal.connectedPortal
            )
        else {
            return false
        }
        return connectedRoom.portals[portal.connectedPortal].flags & 1
            != 0
    }
}

private func setObjectPresentationVisibility(
    in level: inout Level,
    handle: UInt32,
    isVisible: Bool
) {
    guard let index = level.objectPresentations.firstIndex(where: {
        $0.objectHandle == handle
    }) else {
        return
    }
    let presentation = level.objectPresentations[index]
    level.objectPresentations[index] = .init(
        objectHandle: presentation.objectHandle,
        primaryModel: presentation.primaryModel,
        mediumModel: presentation.mediumModel,
        lowModel: presentation.lowModel,
        dyingModel: presentation.dyingModel,
        mediumDistance: presentation.mediumDistance,
        lowDistance: presentation.lowDistance,
        isVisible: isVisible
    )
}

private func completeTrainingCameraMonitorLocateGoal(
    in level: inout Level,
    pickupObjectHandle: UInt32
) {
    guard let goalIndex = level.goals.firstIndex(where: { goal in
        goal.status & 0x0000_0400 != 0
            && goal.items.contains {
                $0.type == 2
                    && $0.objectHandle == pickupObjectHandle
            }
    }) else {
        return
    }
    let goal = level.goals[goalIndex]
    level.goals[goalIndex] = .init(
        status: goal.status | 0x0000_0008,
        priority: goal.priority,
        list: goal.list,
        name: goal.name,
        itemName: goal.itemName,
        description: goal.description,
        completionMessage: goal.completionMessage,
        items: goal.items.map { item in
            guard item.type == 2,
                  item.objectHandle == pickupObjectHandle else {
                return item
            }
            return .init(
                type: item.type,
                sourceHandle: item.sourceHandle,
                objectHandle: item.objectHandle,
                done: true
            )
        }
    )
}

private func trainingCameraMonitorFrame(
    level: Level,
    state: TrainingCameraMonitorState?
) -> TrainingCameraMonitorFrame? {
    guard let chain = level.trainingCameraMonitorChain,
          let remainingDuration = state?.popupRemaining,
          let cameraObject = level.objects.first(where: {
              $0.handle == chain.securityCameraObjectHandle
          }),
          case let .room(roomSourceIndex) = cameraObject.location else {
        return nil
    }
    let localPosition = chain.cameraLocalPosition
    let position = cameraObject.position
        + cameraObject.orientation.right * localPosition.x
        + cameraObject.orientation.up * localPosition.y
        + cameraObject.orientation.forward * localPosition.z
    let gunpointRoomSourceIndex = traceIndoorMovement(
        in: level,
        startRoom: roomSourceIndex,
        start: cameraObject.position,
        end: position,
        radius: 0
    ).containingRoomSourceIndex
    let localForward = chain.cameraLocalForward
    let forward = normalized(
        cameraObject.orientation.right * localForward.x
            + cameraObject.orientation.up * localForward.y
            + cameraObject.orientation.forward * localForward.z
    )
    let up: Vector3
    if forward.x == 0 && forward.z == 0 {
        up = .init(x: 0, y: 0, z: forward.y < 0 ? 1 : -1)
    } else {
        let right = normalized(.init(
            x: forward.z,
            y: 0,
            z: -forward.x
        ))
        up = cross(forward, right)
    }
    return .init(
        camera: .init(
            position: position,
            target: position + forward,
            up: up,
            projection: .sourceDefault
        ),
        roomSourceIndex: gunpointRoomSourceIndex,
        remainingDuration: remainingDuration
    )
}

private func validTrainingGuidebotSteeringState(
    _ guidebot: TrainingGuidebotRuntimeState
) -> Bool {
    switch guidebot.activeSteeringMode {
    case .direct:
        return guidebot.route.mode == .direct
    case .allocatedRoute:
        return guidebot.routeFailure == nil
            && guidebot.route.mode != .direct
    case .stopped:
        return guidebot.routePointIndex
            == guidebot.route.points.count - 1
    }
}

private func validTrainingGuidebotRoute(
    guidebot: TrainingGuidebotRuntimeState,
    level: Level,
    collisionRadius: Float
) -> Bool {
    guard let startRoomSourceIndex =
            guidebot.route.roomSourceIndices.first
    else {
        return false
    }
    let expected = trainingGuidebotRoute(
        in: level,
        startRoomSourceIndex: startRoomSourceIndex,
        start: guidebot.allocationStartPosition,
        startForward: guidebot.allocationStartForward,
        destinationRoomSourceIndex:
            guidebot.routeDestinationRoomSourceIndex,
        destination: guidebot.routeDestination,
        radius: max(0, collisionRadius - 0.1)
    )
    switch expected {
    case .success(let route):
        return guidebot.routeFailure == nil
            && guidebot.route == route
    case .failure(let failure):
        return guidebot.routeFailure == failure
            && guidebot.route.mode == .direct
            && guidebot.route.points == [guidebot.routeDestination]
            && guidebot.route.roomSourceIndices
                == [startRoomSourceIndex]
            && guidebot.route.nodeReferences.isEmpty
    }
}

private func closeTrainingGalleryBarrier(in level: inout Level) {
    guard let barrier = level.trainingGalleryBarrier else { return }
    let barrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    for portalIndex in barrier.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags |= 1
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags |= 1
    }
}

private func setTrainingDodgePortalRenderState(
    in level: inout Level,
    roomSourceIndex: Int,
    portalIndices: [Int],
    rendersFaces: Bool
) {
    let roomIndex = level.rooms.firstIndex {
        $0.sourceIndex == roomSourceIndex
    }!
    for portalIndex in portalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        if rendersFaces {
            level.rooms[roomIndex].portals[portalIndex].flags |= 1
        } else {
            level.rooms[roomIndex].portals[portalIndex].flags &= ~UInt32(1)
        }
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        if rendersFaces {
            level.rooms[connectedRoomIndex]
                .portals[portal.connectedPortal].flags |= 1
        } else {
            level.rooms[connectedRoomIndex]
                .portals[portal.connectedPortal].flags &= ~UInt32(1)
        }
    }
}

private func trainingContinueToCoursePortalsHaveRenderState(
    in level: Level,
    lesson: TrainingContinueToCourseLesson,
    rendersFaces: Bool
) -> Bool {
    return lesson.orderedPortalIndices.allSatisfy { portalIndex in
        trainingPortalPairHasRenderState(
            in: level,
            roomSourceIndex: lesson.portalRoomSourceIndex,
            portalIndex: portalIndex,
            rendersFaces: rendersFaces
        )
    }
}

private func openTrainingContinueToCoursePortals(in level: inout Level) {
    guard let lesson =
            level.trainingOpeningLesson?.continueToCourse,
          let roomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == lesson.portalRoomSourceIndex
          })
    else {
        return
    }
    for portalIndex in lesson.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func trainingFinishCoursePortalsHaveRenderState(
    in level: Level,
    lesson: TrainingFinishCourseLesson,
    rendersFaces: Bool
) -> Bool {
    lesson.orderedPortalIndices.allSatisfy { portalIndex in
        trainingPortalPairHasRenderState(
            in: level,
            roomSourceIndex: lesson.portalRoomSourceIndex,
            portalIndex: portalIndex,
            rendersFaces: rendersFaces
        )
    }
}

private func openTrainingFinishCoursePortals(in level: inout Level) {
    guard let lesson = level.trainingOpeningLesson?.finishCourse,
          let roomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == lesson.portalRoomSourceIndex
          })
    else {
        return
    }
    for portalIndex in lesson.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func trainingStartCoursePortalHasRenderState(
    in level: Level,
    lesson: TrainingStartCourseLesson,
    rendersFaces: Bool
) -> Bool {
    trainingPortalPairHasRenderState(
        in: level,
        roomSourceIndex: lesson.portalRoomSourceIndex,
        portalIndex: lesson.portalIndex,
        rendersFaces: rendersFaces
    )
}

private func trainingPortalPairHasRenderState(
    in level: Level,
    roomSourceIndex: Int,
    portalIndex: Int,
    rendersFaces: Bool
) -> Bool {
    guard let room = level.rooms.first(where: {
        $0.sourceIndex == roomSourceIndex
    }),
          room.portals.indices.contains(portalIndex)
    else {
        return false
    }
    let portal = room.portals[portalIndex]
    let expectedBit: UInt32 = rendersFaces ? 1 : 0
    guard portal.flags & 1 == expectedBit,
          let connectedRoom = level.rooms.first(where: {
              $0.sourceIndex == portal.connectedRoom
          }),
          connectedRoom.portals.indices.contains(portal.connectedPortal)
    else {
        return false
    }
    let reciprocal = connectedRoom.portals[portal.connectedPortal]
    return reciprocal.connectedRoom == room.sourceIndex
        && reciprocal.connectedPortal == portalIndex
        && reciprocal.flags & 1 == expectedBit
}

private func closeTrainingStartCoursePortal(in level: inout Level) {
    guard let lesson = level.trainingOpeningLesson?.startCourse,
          let roomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == lesson.portalRoomSourceIndex
          })
    else {
        return
    }
    let portal = level.rooms[roomIndex].portals[lesson.portalIndex]
    level.rooms[roomIndex].portals[lesson.portalIndex].flags |= 1
    let connectedRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == portal.connectedRoom
    }!
    level.rooms[connectedRoomIndex]
        .portals[portal.connectedPortal].flags |= 1
}

private func openTrainingGalleryBarrier(in level: inout Level) {
    guard let barrier = level.trainingGalleryBarrier else { return }
    let barrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    for portalIndex in barrier.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func openTrainingGuidebotReturnBarrier(in level: inout Level) {
    guard let barrier =
            level.trainingCameraMonitorChain?.returnToShip,
          let barrierRoomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == barrier.barrierRoomSourceIndex
          }) else {
        return
    }
    for portalIndex in barrier.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags
            &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func openTrainingLastRoomBarrier(in level: inout Level) {
    guard let chain = level.trainingLastRoomChain,
        let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == chain.barrierRoomSourceIndex
        })
    else {
        return
    }
    for portalIndex in chain.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func openTrainingFinalBotsBarrier(in level: inout Level) {
    guard let chain = level.trainingFinalBotsCompletionChain,
          let roomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == chain.barrierRoomSourceIndex
          })
    else {
        return
    }
    for portalIndex in chain.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags
            &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func closeTrainingLastRoomBarrier(in level: inout Level) {
    guard let chain = level.trainingLastRoomChain,
        let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == chain.barrierRoomSourceIndex
        })
    else {
        return
    }
    for portalIndex in chain.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags |= 1
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags |= 1
    }
}

private func trainingKillbotEntryBarrierRendersFaces(
    in level: Level
) -> Bool {
    guard let barrier =
            level.trainingCameraMonitorChain?.returnToShip,
          let entry = barrier.killbotEntry,
          let room = level.rooms.first(where: {
              $0.sourceIndex == barrier.barrierRoomSourceIndex
          }) else {
        return false
    }
    return entry.orderedPortalIndices.allSatisfy {
        room.portals[$0].flags & 1 != 0
    }
}

private func closeTrainingKillbotEntryBarrier(in level: inout Level) {
    guard let barrier =
            level.trainingCameraMonitorChain?.returnToShip,
          let entry = barrier.killbotEntry,
          let barrierRoomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == barrier.barrierRoomSourceIndex
          }) else {
        return
    }
    for portalIndex in entry.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags |= 1
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags |= 1
    }
}

private func trainingForwardGoalWasReached(
    in level: Level,
    lesson: TrainingOpeningLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.forwardGoalObjectHandle
    }!
    guard case let .room(targetRoomSourceIndex) = target.location,
          visitedRoomSourceIndices.contains(targetRoomSourceIndex) else {
        return false
    }
    let presentation = level.objectPresentations.first {
        $0.objectHandle == target.handle
    }!
    let model = level.models.first {
        $0.source == presentation.primaryModel
    }!
    let targetRadius = sourceObjectPresentationSize(
        model: model,
        objectType: target.type
    )
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: targetRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingStartGoalWasReached(
    in level: Level,
    lesson: TrainingOpeningLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let targetAndRadius: (UInt32, Float)?
    if let returnLeft = lesson.returnLeft {
        targetAndRadius = (
            returnLeft.startGoalObjectHandle,
            returnLeft.collisionRadius
        )
    } else if let returnUp = lesson.returnUp {
        targetAndRadius = (
            returnUp.startGoalObjectHandle,
            returnUp.collisionRadius
        )
    } else if let repeatForward = lesson.repeatForward {
        targetAndRadius = (
            repeatForward.startGoalObjectHandle,
            repeatForward.collisionRadius
        )
    } else if let repeatReturnLeft = lesson.repeatReturnLeft {
        targetAndRadius = (
            repeatReturnLeft.startGoalObjectHandle,
            repeatReturnLeft.collisionRadius
        )
    } else {
        targetAndRadius = nil
    }
    guard let (targetHandle, collisionRadius) = targetAndRadius else {
        return false
    }
    let target = level.objects.first {
        $0.handle == targetHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingLeftGoalWasReached(
    in level: Level,
    lesson: TrainingReturnRightLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.leftGoalObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingDownGoalWasReached(
    in level: Level,
    lesson: TrainingReturnDownLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.upGoalObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingStartCourseWasReached(
    in level: Level,
    lesson: TrainingStartCourseLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.startCourseObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingFinishCourseWasReached(
    in level: Level,
    lesson: TrainingFinishCourseLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.finishCourseObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingOpeningGoalWasReached(
    target: PlacedObject,
    targetRadius: Float,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard case let .room(targetRoomSourceIndex) = target.location,
          visitedRoomSourceIndices.contains(targetRoomSourceIndex) else {
        return false
    }
    let movement = playerEnd - playerStart
    let lengthSquared = dot(movement, movement)
    let fraction: Float
    if lengthSquared > 0 {
        fraction = max(
            0,
            min(
                1,
                dot(target.position - playerStart, movement) / lengthSquared
            )
        )
    } else {
        fraction = 0
    }
    let closest = playerStart + movement * fraction
    let separation = target.position - closest
    let collisionRadius = playerRadius + targetRadius
    return dot(separation, separation) <= collisionRadius * collisionRadius
}

func sourceAfterburnerForwardControl(
    afterburner: Float,
    fuel: Float
) -> Float {
    var punch: Float = 1
    if fuel > 4.5 {
        punch = 1.8
    } else if fuel > 4, fuel < 4.5 {
        var normalizedFuel = Float(Double(fuel) - 5.0 * 0.8)
        normalizedFuel = Float(Double(normalizedFuel) / (5.0 * 0.1))
        punch = Float(1.0 + Double(normalizedFuel) * 0.8)
    }
    return Float(Double(afterburner) * 1.6 * Double(punch))
}

private func sourceFixedSine(
    gameTime: Float,
    wigglesPerSecond: Float
) -> Float {
    let sourceValue = Int(gameTime * wigglesPerSecond * 65_535) % 65_535
    let angle = UInt16(truncatingIfNeeded: sourceValue)
    let index = Int(angle >> 8) & 0xff
    let fraction = Int(angle & 0xff)
    let sourcePi: Float = 3.141592654
    let firstRadians = Float(
        Double(index) / 256 * 2 * Double(sourcePi)
    )
    let secondRadians = Float(
        Double(index + 1) / 256 * 2 * Double(sourcePi)
    )
    let first = sin(firstRadians)
    let second = sin(secondRadians)
    return Float(
        Double(first)
            + Double(second - first) * Double(fraction) / 256
    )
}

private func sourceIndoorAutoLevelThrust(
    _ input: Vector3,
    orientation: Matrix3,
    storedOrientation: Matrix3,
    fullRotationalThrust: Float,
    turnrollFixedAngle: Float,
    mode: IndoorAutoLevelMode,
    gameTime: Float,
    lastThrustTime: Float
) -> Vector3 {
    guard mode != .off else { return input }
    var result = input
    let angles = sourceExtractAngles(orientation)
    let firedRecently = gameTime < 1.5
    var pitchWasLeveled = false

    if mode == .newPlayer,
       !firedRecently,
       lastThrustTime + 1.5 < gameTime {
        let bound = 750
        var pitch = angles.pitch
        if pitch > bound,
           pitch < 65_535 - bound,
           abs(pitch - 32_768) > bound {
            pitchWasLeveled = true
            if storedOrientation.up.y < 0 {
                pitch = (pitch + 16_384) & 0xffff
            }
            let scale = min(1, 1.05 - abs(storedOrientation.up.y))
            if pitch < 16_834 {
                result = Vector3(
                    x: result.x - scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else if pitch < 32_768 {
                result = Vector3(
                    x: result.x + scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else if pitch < 49_152 {
                result = Vector3(
                    x: result.x - scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else {
                result = Vector3(
                    x: result.x + scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            }
        }
    }

    guard !pitchWasLeveled, abs(result.z) < 100 else { return result }
    let maximumTilt: Float = mode == .newPlayer ? 13_750 : 11_000
    let pitchIsBeyondTilt: Bool
    if angles.pitch < 32_768 {
        pitchIsBeyondTilt =
            Float(abs(angles.pitch - 16_834)) > maximumTilt
    } else {
        pitchIsBeyondTilt =
            Float(abs(angles.pitch - 49_152)) > maximumTilt
    }
    guard pitchIsBeyondTilt else { return result }

    let turnrollBound = turnrollFixedAngle == 0
        ? 10
        : Int(abs(turnrollFixedAngle))
    guard angles.roll > turnrollBound,
          angles.roll < 65_535 - turnrollBound else {
        return result
    }

    var scale: Float
    if angles.pitch < 32_768 {
        scale = (
            Float(abs(16_834 - angles.pitch)) - maximumTilt
        ) / (16_384 - maximumTilt)
    } else {
        scale = (
            Float(abs(49_152 - angles.pitch)) - maximumTilt
        ) / (16_384 - maximumTilt)
    }
    if angles.roll < 32_768 {
        let bankDistance = angles.roll > 28_672
            ? 28_672 - 16_834
            : abs(16_834 - angles.roll)
        var bankScale = 1.04 - Float(bankDistance) / 16_384
        bankScale *= bankScale
        scale *= bankScale
        if firedRecently { scale *= 0.25 }
        result = Vector3(
            x: result.x,
            y: result.y,
            z: result.z - scale * 2 * fullRotationalThrust
        )
    } else {
        let bankDistance = angles.roll < 36_864
            ? 49_152 - 36_864
            : abs(49_152 - angles.roll)
        var bankScale = 1.04 - Float(bankDistance) / 16_384
        bankScale *= bankScale
        scale *= bankScale
        if firedRecently { scale *= 0.25 }
        result = Vector3(
            x: result.x,
            y: result.y,
            z: result.z + scale * 2 * fullRotationalThrust
        )
    }
    return result
}

private func sourceExtractAngles(
    _ matrix: Matrix3
) -> (pitch: Int, yaw: Int, roll: Int) {
    if abs(matrix.forward.x) < 0.000_01,
       abs(matrix.forward.z) < 0.000_01 {
        return (
            matrix.forward.y > 0 ? 0xc000 : 0x4000,
            sourceFixedAtan2(
                cosine: matrix.right.x,
                sine: -matrix.right.z
            ),
            0
        )
    }
    let yaw = sourceFixedAtan2(
        cosine: matrix.forward.z,
        sine: matrix.forward.x
    )
    let yawRadians = Float(yaw) * (2 * Float.pi / 65_536)
    let sinYaw = sin(yawRadians)
    let cosYaw = cos(yawRadians)
    let cosPitch = abs(sinYaw) > abs(cosYaw)
        ? matrix.forward.x / sinYaw
        : matrix.forward.z / cosYaw
    let pitch = sourceFixedAtan2(
        cosine: cosPitch,
        sine: -matrix.forward.y
    )
    let roll = sourceFixedAtan2(
        cosine: matrix.up.y / cosPitch,
        sine: matrix.right.y / cosPitch
    )
    return (pitch, yaw, roll)
}

private func sourceFixedAtan2(cosine: Float, sine: Float) -> Int {
    let radians = atan2(sine, cosine)
    let positive = radians < 0 ? radians + 2 * Float.pi : radians
    return Int(positive * (65_536 / (2 * Float.pi))) & 0xffff
}

private func analyticAngularVelocity(
    velocity: Vector3,
    force: Vector3,
    mass: Float,
    drag: Float,
    duration: Float
) -> Vector3 {
    precondition(mass > 0 && drag > 0 && duration >= 0)
    let oneOverDrag = 1.0 / Double(drag)
    let decay = exp(-(Double(drag) / Double(mass)) * Double(duration))
    func component(_ velocity: Float, _ force: Float) -> Float {
        let forceOverDrag = Double(force) * oneOverDrag
        return Float(
            (Double(velocity) - forceOverDrag) * decay + forceOverDrag
        )
    }
    return Vector3(
        x: component(velocity.x, force.x),
        y: component(velocity.y, force.y),
        z: component(velocity.z, force.z)
    )
}

private func sourceFixedAngleUnits(_ fixedAngleUnits: Float) -> Int16 {
    Int16(truncatingIfNeeded: Int64(fixedAngleUnits.rounded(.towardZero)))
}

private func sourceFixedAngleRadians(_ radians: Float) -> Int16 {
    sourceFixedAngleUnits(radians * (65_536 / (2 * Float.pi)))
}

private func sourceRotationMatrix(
    pitch: Int16,
    yaw: Int16,
    roll: Int16
) -> Matrix3 {
    let radiansPerUnit = 2 * Float.pi / 65_536
    let pitchRadians = Float(pitch) * radiansPerUnit
    let yawRadians = Float(yaw) * radiansPerUnit
    let rollRadians = Float(roll) * radiansPerUnit
    let sinPitch = sin(pitchRadians)
    let cosPitch = cos(pitchRadians)
    let sinRoll = sin(rollRadians)
    let cosRoll = cos(rollRadians)
    let sinYaw = sin(yawRadians)
    let cosYaw = cos(yawRadians)
    let sinRollSinYaw = sinRoll * sinYaw
    let cosRollCosYaw = cosRoll * cosYaw
    let cosRollSinYaw = cosRoll * sinYaw
    let sinRollCosYaw = sinRoll * cosYaw
    return Matrix3(
        right: Vector3(
            x: cosRollCosYaw + sinPitch * sinRollSinYaw,
            y: sinRoll * cosPitch,
            z: sinPitch * sinRollCosYaw - cosRollSinYaw
        ),
        up: Vector3(
            x: sinPitch * cosRollSinYaw - sinRollCosYaw,
            y: cosRoll * cosPitch,
            z: sinRollSinYaw + sinPitch * cosRollCosYaw
        ),
        forward: Vector3(
            x: sinYaw * cosPitch,
            y: -sinPitch,
            z: cosYaw * cosPitch
        )
    )
}

private func sourceMatrixMultiply(_ lhs: Matrix3, _ rhs: Matrix3) -> Matrix3 {
    Matrix3(
        right: sourceTransform(rhs.right, by: lhs),
        up: sourceTransform(rhs.up, by: lhs),
        forward: sourceTransform(rhs.forward, by: lhs)
    )
}

private func sourceTransposed(_ matrix: Matrix3) -> Matrix3 {
    Matrix3(
        right: Vector3(
            x: matrix.right.x,
            y: matrix.up.x,
            z: matrix.forward.x
        ),
        up: Vector3(
            x: matrix.right.y,
            y: matrix.up.y,
            z: matrix.forward.y
        ),
        forward: Vector3(
            x: matrix.right.z,
            y: matrix.up.z,
            z: matrix.forward.z
        )
    )
}

private func sourceTransform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    Vector3(
        x: matrix.right.x * value.x
            + matrix.up.x * value.y
            + matrix.forward.x * value.z,
        y: matrix.right.y * value.x
            + matrix.up.y * value.y
            + matrix.forward.y * value.z,
        z: matrix.right.z * value.x
            + matrix.up.z * value.y
            + matrix.forward.z * value.z
    )
}

private func sourceOrthogonalized(_ matrix: Matrix3) -> Matrix3 {
    let forward = sourceNormalized(matrix.forward)
    let right = sourceNormalized(cross(matrix.up, forward))
    return Matrix3(
        right: right,
        up: cross(forward, right),
        forward: forward
    )
}

private func sourceNormalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0)
    return value / magnitude
}

private func surfacePhysicsBehavior(
    for contact: IndoorWallContact,
    in level: Level
) -> SurfacePhysicsBehavior {
    let room = level.rooms.first { $0.sourceIndex == contact.roomSourceIndex }!
    let texture = room.faces[contact.faceIndex].texture
    return level.surfacePhysics.first { $0.texture == texture }!.behavior
}

private func analyticLinearMotion(
    position: Vector3,
    velocity: Vector3,
    force: Vector3,
    mass: Float,
    drag: Float,
    duration: Float
) -> (position: Vector3, velocity: Vector3) {
    precondition(mass > 0 && drag > 0 && duration >= 0)
    func component(_ p: Float, _ v: Float, _ force: Float) -> (Float, Float) {
        let p = Double(p)
        let v = Double(v)
        let force = Double(force)
        let mass = Double(mass)
        let drag = Double(drag)
        let duration = Double(duration)
        let q = force / drag
        let massOverDrag = mass / drag
        let decay = exp(-(drag / mass) * duration)
        return (
            Float(p + q * duration + massOverDrag * (v - q) * (1 - decay)),
            Float((v - q) * decay + q)
        )
    }
    let x = component(position.x, velocity.x, force.x)
    let y = component(position.y, velocity.y, force.y)
    let z = component(position.z, velocity.z, force.z)
    return (
        Vector3(x: x.0, y: y.0, z: z.0),
        Vector3(x: x.1, y: y.1, z: z.1)
    )
}

private func vectorDistance(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    let x = rhs.x - lhs.x
    let y = rhs.y - lhs.y
    let z = rhs.z - lhs.z
    return sqrt(x * x + y * y + z * z)
}

enum RoomRenderExtractionError: Error, Equatable {
    case missingRoom(Int)
    case missingMaterial(String)
    case missingLightmap(Int)
    case missingCoronaAsset(Int)
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil
    )
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    presentationGameTime: Float
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil,
        presentationGameTime: presentationGameTime
    )
}

func extractWorldForRendering(
    _ level: Level,
    playerView: PlayerView
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: playerView.camera,
        startRoomSourceIndex: playerView.roomSourceIndex,
        excludedObjectHandle: playerView.objectHandle
    )
}

func extractPreparedRoomDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int
) throws -> [RoomDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [RoomDrawItem] = []
    for room in level.rooms
        .filter({ component.contains($0.sourceIndex) })
        .sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        for faceIndex in room.faces.indices {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            items.append(
                try makeDrawItem(
                    room: room,
                    faceIndex: faceIndex,
                    material: material,
                    lightmaps: level.lightmaps
                )
            )
        }
    }
    return items
}

func extractPreparedModelDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> [ModelDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [ModelDrawItem] = []
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              case let .room(roomSourceIndex) = object.location,
              component.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle] else {
            continue
        }
        var seen: Set<SourceResource> = []
        for source in [
            presentation.primaryModel,
            presentation.mediumModel,
            presentation.lowModel,
        ].compactMap({ $0 }) where seen.insert(source).inserted {
            items += makeModelDrawItems(
                object: object,
                model: modelBySource[source]!,
                materialByTexture: materialByTexture,
                camera: .trainingRoom3,
                cullBackfaces: false
            )
        }
    }
    return items
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?,
    presentationGameTime: Float = 0,
    trainingDodgeTurretAngles: [Float] = []
) throws -> WorldRenderExtraction {
    let visibility = try extractSourceVisibleWorld(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        portalBlends: Dictionary(
            uniqueKeysWithValues: level.presentationMaterials.map {
                ($0.texture, $0.blend)
            }
        )
    )
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let view = CameraView(camera)

    var opaqueDrawItems: [RoomDrawItem] = []
    var translucentDrawItems: [(depth: Float, item: RoomDrawItem)] = []
    let facesByRoom = Dictionary(grouping: visibility.faces, by: \.roomSourceIndex)
    for roomSourceIndex in visibility.visibleRoomSourceIndices.reversed() {
        let room = roomBySourceIndex[roomSourceIndex]!
        for faceIndex in (facesByRoom[roomSourceIndex] ?? []).map(\.faceIndex).sorted() {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            let item = try makeDrawItem(
                room: room,
                faceIndex: faceIndex,
                material: material,
                lightmaps: level.lightmaps
            )
            if case .additiveSourceAlpha = material.blend {
                let depth = item.vertices.reduce(Float.zero) {
                    $0 + view.project($1.position).depth
                } / Float(item.vertices.count)
                translucentDrawItems.append((depth, item))
            } else {
                opaqueDrawItems.append(item)
            }
        }
    }
    translucentDrawItems.sort {
        if $0.depth != $1.depth { return $0.depth > $1.depth }
        if $0.item.roomSourceIndex != $1.item.roomSourceIndex {
            return $0.item.roomSourceIndex < $1.item.roomSourceIndex
        }
        return $0.item.faceIndex < $1.item.faceIndex
    }
    let lightCoronas = try extractSourceLightCoronas(
        level,
        camera: camera,
        visibility: visibility,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle
    )
    let objectPresentation = extractObjectPresentation(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        visibility: visibility,
        excludedObjectHandle: excludedObjectHandle,
        presentationGameTime: presentationGameTime,
        trainingDodgeTurretAngles:
            trainingDodgeTurretAngles
    )
    return WorldRenderExtraction(
        visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
        opaqueDrawItems: opaqueDrawItems,
        translucentDrawItems: translucentDrawItems.map(\.item),
        admittedObjectHandles: objectPresentation.handles,
        modelDrawItems: objectPresentation.drawItems,
        lightCoronas: lightCoronas,
        portalEdges: visibility.portalEdges
    )
}

private func extractObjectPresentation(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    visibility: SourceVisibleWorld,
    excludedObjectHandle: UInt32?,
    presentationGameTime: Float,
    trainingDodgeTurretAngles: [Float]
) -> (handles: [UInt32], drawItems: [ModelDrawItem]) {
    guard !level.objectPresentations.isEmpty else { return ([], []) }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let visibleRooms = Set(visibility.visibleRoomSourceIndices)
    let view = CameraView(camera)
    var accepted: [(depth: Float, ordinal: Int, object: PlacedObject,
                    presentation: ObjectPresentationReference, model: CanonicalModel)] = []
    for (ordinal, object) in level.objects.enumerated() {
        guard object.handle != excludedObjectHandle,
              let presentation = presentationByHandle[object.handle],
              presentation.isVisible,
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let primary = modelBySource[presentation.primaryModel] else {
            continue
        }
        let size = sourceObjectPresentationSize(model: primary, objectType: object.type)
        guard sourceObjectIsPortalSafe(
            object,
            size: size,
            startRoomSourceIndex: startRoomSourceIndex,
            clipWindowsByRoom: visibility.objectClipWindowsByRoom,
            view: view
        ), sourceSphereIsVisible(object.position, radius: size, view: view) else {
            continue
        }
        let depth = view.depth(of: object.position)
        let selectedSource = sourceLODModel(presentation, depth: depth)
        guard let model = modelBySource[selectedSource] else {
            preconditionFailure("validated object presentation references must resolve")
        }
        accepted.append((depth, ordinal, object, presentation, model))
    }
    accepted.sort {
        $0.depth == $1.depth ? $0.ordinal < $1.ordinal : $0.depth > $1.depth
    }
    return (
        accepted.map { $0.object.handle },
        accepted.flatMap {
            makeModelDrawItems(
                object: $0.object,
                model: $0.model,
                materialByTexture: materialByTexture,
                camera: camera,
                presentationGameTime: presentationGameTime,
                turretAnglesBySubmodel:
                    $0.object.handle
                    == level.trainingDodgeAttempt?
                    .dodgeTurretObjectHandle
                    ? Dictionary(
                        uniqueKeysWithValues: zip(
                            level.trainingDodgeAttempt!.turret.joints.map(
                                \.submodelIndex
                            ),
                            trainingDodgeTurretAngles
                        ))
                    : [:]
            )
        }
    )
}

func sourceObjectPresentationSize(
    model: CanonicalModel,
    objectType: UInt8
) -> Float {
    let offsets = accumulatedModelOffsets(model)
    var maximumDistanceSquared: Float = 0
    for submodel in model.submodels {
        let offset = offsets[submodel.sourceIndex]
        for vertex in submodel.vertices {
            let transformed = offset + vertex.position
            maximumDistanceSquared = max(
                maximumDistanceSquared,
                dot(transformed, transformed)
            )
        }
    }
    var size = sqrt(maximumDistanceSquared) + 0.01
    if objectType == 7 { size *= 2 }
    return size
}

private func sourceObjectIsPortalSafe(
    _ object: PlacedObject,
    size: Float,
    startRoomSourceIndex: Int,
    clipWindowsByRoom: [Int: [SourceClipWindow]],
    view: CameraView
) -> Bool {
    guard case let .room(roomSourceIndex) = object.location else { return false }
    if roomSourceIndex == startRoomSourceIndex { return true }
    return (clipWindowsByRoom[roomSourceIndex] ?? []).contains { window in
        sourceCubeIntersectsWindow(
            center: object.position,
            halfExtent: size,
            view: view,
            window: window
        )
    }
}

private func sourceCubeIntersectsWindow(
    center: Vector3,
    halfExtent: Float,
    view: CameraView,
    window: SourceClipWindow
) -> Bool {
    var combined = UInt8.max
    for x in [-halfExtent, halfExtent] {
        for y in [-halfExtent, halfExtent] {
            for z in [-halfExtent, halfExtent] {
                let point = view.project(center + .init(x: x, y: y, z: z))
                if point.depth <= 0 { return true }
                combined &= clipCode(point, window: window)
            }
        }
    }
    return combined == 0
}

private func sourceSphereIsVisible(
    _ position: Vector3,
    radius: Float,
    view: CameraView
) -> Bool {
    let relative = position - view.eye
    let horizontal = dot(relative, view.right)
    let vertical = dot(relative, view.up)
    let depth = dot(relative, view.forward)
    guard depth >= -radius else { return false }
    let horizontalHalfFOV = atan(1 / view.horizontalProjectionScale)
    let verticalHalfFOV = atan(1 / view.verticalProjectionScale)
    guard abs(horizontal) * cos(horizontalHalfFOV)
            - depth * sin(horizontalHalfFOV) <= radius,
          abs(vertical) * cos(verticalHalfFOV)
            - depth * sin(verticalHalfFOV) <= radius else {
        return false
    }
    return true
}

private func sourceLODModel(
    _ presentation: ObjectPresentationReference,
    depth: Float
) -> SourceResource {
    if let mediumDistance = presentation.mediumDistance,
       depth >= mediumDistance {
        if let lowDistance = presentation.lowDistance,
           depth >= lowDistance {
            return presentation.lowModel
                ?? presentation.mediumModel
                ?? presentation.primaryModel
        }
        return presentation.mediumModel ?? presentation.primaryModel
    }
    return presentation.primaryModel
}

private struct ModelSubmodelTransform {
    let origin: Vector3
    let orientation: Matrix3
}

private func modelSubmodelTransforms(
    _ model: CanonicalModel,
    presentationGameTime: Float,
    turretAnglesBySubmodel: [Int: Float] = [:]
) -> [ModelSubmodelTransform] {
    precondition(
        presentationGameTime.isFinite && presentationGameTime >= 0
    )
    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    var resolved = [ModelSubmodelTransform?](
        repeating: nil,
        count: model.submodels.count
    )
    func resolve(_ index: Int) -> ModelSubmodelTransform {
        if let result = resolved[index] { return result }
        let submodel = model.submodels[index]
        let parent = submodel.parentIndex.map(resolve)
            ?? .init(origin: .zero, orientation: identity)
        let localOrientation: Matrix3
        if case let .rotate(rate, axis) = submodel.presentation {
            let turns = presentationGameTime / rate
            let angle = (turns - floor(turns)) * 2 * Float.pi
            localOrientation = .init(
                right: rotate(
                    .init(x: 1, y: 0, z: 0),
                    around: axis,
                    angle: angle
                ),
                up: rotate(
                    .init(x: 0, y: 1, z: 0),
                    around: axis,
                    angle: angle
                ),
                forward: rotate(
                    .init(x: 0, y: 0, z: 1),
                    around: axis,
                    angle: angle
                )
            )
        } else if case .turret(_, _, _, let axis) = submodel.presentation,
            let turns = turretAnglesBySubmodel[
                submodel.sourceIndex
            ]
        {
            let angle = turns * 2 * Float.pi
            localOrientation = .init(
                right: rotate(
                    .init(x: 1, y: 0, z: 0),
                    around: axis,
                    angle: angle
                ),
                up: rotate(
                    .init(x: 0, y: 1, z: 0),
                    around: axis,
                    angle: angle
                ),
                forward: rotate(
                    .init(x: 0, y: 0, z: 1),
                    around: axis,
                    angle: angle
                )
            )
        } else {
            localOrientation = identity
        }
        let orientation = Matrix3(
            right: transform(
                localOrientation.right,
                by: parent.orientation
            ),
            up: transform(
                localOrientation.up,
                by: parent.orientation
            ),
            forward: transform(
                localOrientation.forward,
                by: parent.orientation
            )
        )
        let result = ModelSubmodelTransform(
            origin: parent.origin
                + transform(submodel.offset, by: parent.orientation),
            orientation: orientation
        )
        resolved[index] = result
        return result
    }
    return model.submodels.indices.map(resolve)
}

private func rotate(
    _ value: Vector3,
    around axis: Vector3,
    angle: Float
) -> Vector3 {
    let cosine = cos(angle)
    let sine = sin(angle)
    return value * cosine
        + cross(axis, value) * sine
        + axis * (dot(axis, value) * (1 - cosine))
}

private func makeModelDrawItems(
    object: PlacedObject,
    model: CanonicalModel,
    materialByTexture: [SourceResource: PresentationMaterial],
    camera: RoomCamera,
    presentationGameTime: Float = 0,
    turretAnglesBySubmodel: [Int: Float] = [:],
    cullBackfaces: Bool = true
) -> [ModelDrawItem] {
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("model presentation is indoor in the Slice 6 island")
    }
    let transforms = modelSubmodelTransforms(
        model,
        presentationGameTime: presentationGameTime,
        turretAnglesBySubmodel: turretAnglesBySubmodel
    )
    let view = CameraView(camera)
    var opaque: [ModelDrawItem] = []
    var alpha: [ModelDrawItem] = []
    for submodel in model.submodels.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        if submodel.presentation == .facing {
            guard let face = submodel.faces.first,
                  case let .texture(texture) = face.material,
                  let material = materialByTexture[texture]
            else {
                preconditionFailure("validated facing presentation must resolve")
            }
            let localPoints = face.corners.map {
                submodel.vertices[$0.vertexIndex].position
            }
            let area = (1..<(localPoints.count - 1)).reduce(Float.zero) {
                $0 + sqrt(dot(
                    cross(
                        localPoints[$1] - localPoints[0],
                        localPoints[$1 + 1] - localPoints[0]
                    ),
                    cross(
                        localPoints[$1] - localPoints[0],
                        localPoints[$1 + 1] - localPoints[0]
                    )
                )) / 2
            }
            let halfWidth = sqrt(area) / 2
            let halfHeight = halfWidth
                * Float(material.image.height)
                / Float(material.image.width)
            let center = object.position
                + transform(
                    transforms[submodel.sourceIndex].origin,
                    by: object.orientation
                )
            let vertices = [
                (center - view.right * halfWidth + view.up * halfHeight, 0, 0),
                (center + view.right * halfWidth + view.up * halfHeight, 1, 0),
                (center + view.right * halfWidth - view.up * halfHeight, 1, 1),
                (center - view.right * halfWidth - view.up * halfHeight, 0, 1),
            ].map {
                WorldRenderVertex(
                    position: $0.0,
                    u: Float($0.1),
                    v: Float($0.2),
                    lightmapU: 0,
                    lightmapV: 0,
                    alpha: 1
                )
            }
            let item = ModelDrawItem(
                objectHandle: object.handle,
                roomSourceIndex: roomSourceIndex,
                model: model.source,
                submodelIndex: submodel.sourceIndex,
                faceIndex: 0,
                material: face.material,
                blend: material.blend,
                vertices: vertices,
                triangleIndices: [0, 1, 2, 0, 2, 3]
            )
            switch material.blend {
            case .opaque: opaque.append(item)
            case .sourceAlpha, .additiveSourceAlpha: alpha.append(item)
            }
            continue
        }
        switch submodel.presentation {
        case .standard, .rotate, .turret:
            break
        case .custom, .facing, .glow:
            continue
        }
        let submodelTransform = transforms[submodel.sourceIndex]
        for (faceIndex, face) in submodel.faces.enumerated() {
            let transformedNormal = transform(
                transform(face.normal, by: submodelTransform.orientation),
                by: object.orientation
            )
            let firstLocal = submodelTransform.origin + transform(
                submodel.vertices[face.corners[0].vertexIndex].position,
                by: submodelTransform.orientation
            )
            let firstWorld = object.position + transform(firstLocal, by: object.orientation)
            guard !cullBackfaces
                    || dot(camera.position - firstWorld, transformedNormal) >= 0 else {
                continue
            }
            let vertices = face.corners.map { corner in
                let source = submodel.vertices[corner.vertexIndex]
                let local = submodelTransform.origin
                    + transform(
                        source.position,
                        by: submodelTransform.orientation
                    )
                return WorldRenderVertex(
                    position: object.position + transform(local, by: object.orientation),
                    u: corner.u,
                    v: corner.v,
                    lightmapU: 0,
                    lightmapV: 0,
                    alpha: source.alpha
                )
            }
            var indices: [UInt32] = []
            for index in 1..<(vertices.count - 1) {
                indices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
            }
            let blend: PresentationBlend
            switch face.material {
            case let .texture(texture):
                guard let material = materialByTexture[texture] else {
                    preconditionFailure("validated model materials must resolve")
                }
                blend = material.blend
            case .sourceColor:
                blend = .sourceAlpha(opacity: 255)
            }
            let item = ModelDrawItem(
                objectHandle: object.handle,
                roomSourceIndex: roomSourceIndex,
                model: model.source,
                submodelIndex: submodel.sourceIndex,
                faceIndex: faceIndex,
                material: face.material,
                blend: blend,
                vertices: vertices,
                triangleIndices: indices
            )
            switch blend {
            case .opaque: opaque.append(item)
            case .sourceAlpha, .additiveSourceAlpha: alpha.append(item)
            }
        }
    }
    return opaque + alpha
}

private let trainingDodgeProjectilePresentationCapacity = 8
private let trainingScriptActionCounterMaximum = 100_000

func extractPreparedTrainingDodgeProjectileDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
    guard let dodge = level.trainingDodgeAttempt,
        let turret = level.objects.first(where: {
            $0.handle == dodge.dodgeTurretObjectHandle
        }),
        case .room(let roomSourceIndex) = turret.location
    else {
        return []
    }
    return extractTrainingDodgeProjectileDrawItems(
        level,
        projectiles: (0..<trainingDodgeProjectilePresentationCapacity)
            .map { _ in
                .init(
                    position: turret.position,
                    velocity:
                        turret.orientation.forward
                        * dodge.turret.projectileSpeed,
                    roomSourceIndex: roomSourceIndex,
                    model: dodge.turret.projectileModel
                )
            },
        camera: .trainingRoom3
    )
}

func extractTrainingDodgeProjectileDrawItems(
    _ level: Level,
    projectiles: [TrainingDodgeProjectileFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let dodge = level.trainingDodgeAttempt,
        let model = level.models.first(where: {
            $0.source == dodge.turret.projectileModel
        })
    else {
        return []
    }
    precondition(
        projectiles.count <= trainingDodgeProjectilePresentationCapacity
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return projectiles.enumerated().flatMap { slot, projectile in
        let forward = normalized(projectile.velocity)
        let referenceUp =
            abs(forward.y) < 0.99
            ? Vector3(x: 0, y: 1, z: 0)
            : Vector3(x: 1, y: 0, z: 0)
        let right = normalized(cross(referenceUp, forward))
        let up = cross(forward, right)
        let object = PlacedObject(
            handle: UInt32.max - UInt32(slot),
            type: 5,
            storedID: 0,
            definition: nil,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(projectile.roomSourceIndex),
            position: projectile.position,
            orientation: .init(
                right: right,
                up: up,
                forward: forward
            ),
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

private let trainingBlueLaserPresentationCapacity = 40
let playerConcussionMissilePresentationCapacity = 6

func extractPreparedTrainingBlueLaserDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
    guard let handoff =
            level.trainingDodgeAttempt?.maneuverFollow?
                .destructionHandoff,
          let destroyBot1 = level.objects.first(where: {
              $0.handle == handoff.destroyBot1ObjectHandle
          }),
          case let .room(roomSourceIndex) = destroyBot1.location
    else {
        return []
    }
    return extractTrainingBlueLaserDrawItems(
        level,
        projectiles:
            (0..<trainingBlueLaserPresentationCapacity).map {
                _ in
                .init(
                    position: destroyBot1.position,
                    velocity:
                        destroyBot1.orientation.forward
                            * handoff.combat.projectileSpeed,
                    roomSourceIndex: roomSourceIndex,
                    model: handoff.projectileModel
                )
            },
        camera: .trainingRoom3
    )
}

func extractTrainingBlueLaserDrawItems(
    _ level: Level,
    projectiles: [TrainingBlueLaserProjectileFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let handoff =
            level.trainingDodgeAttempt?.maneuverFollow?
                .destructionHandoff,
          let model = level.models.first(where: {
              $0.source == handoff.projectileModel
          })
    else {
        return []
    }
    precondition(
        projectiles.count
            <= trainingBlueLaserPresentationCapacity
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return projectiles.enumerated().flatMap {
        slot, projectile in
        let forward = normalized(projectile.velocity)
        let referenceUp =
            abs(forward.y) < 0.99
            ? Vector3(x: 0, y: 1, z: 0)
            : Vector3(x: 1, y: 0, z: 0)
        let right = normalized(cross(referenceUp, forward))
        let up = cross(forward, right)
        let object = PlacedObject(
            handle:
                UInt32.max
                    - UInt32(
                        trainingBlueLaserPresentationCapacity
                    )
                    - UInt32(slot),
            type: 5,
            storedID: 0,
            definition: nil,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(projectile.roomSourceIndex),
            position: projectile.position,
            orientation: .init(
                right: right,
                up: up,
                forward: forward
            ),
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

func extractPreparedPlayerConcussionMissileDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
    guard let binding = level.shipDefinitions.first?.playerConcussion,
          let player = level.objects.first(where: {
              $0.handle == level.defaultPlayerBinding?.objectHandle
          }),
          case let .room(roomSourceIndex) = player.location else {
        return []
    }
    return extractPlayerConcussionMissileDrawItems(
        level,
        missiles: (0..<playerConcussionMissilePresentationCapacity).map {
            _ in .init(
                roomSourceIndex: roomSourceIndex,
                position: player.position,
                orientation: player.orientation,
                velocity: player.orientation.forward * binding.speed,
                model: binding.model,
                lightDistance: binding.lightDistance,
                lightPresentation: binding.lightPresentation
            )
        },
        camera: .trainingRoom3
    )
}

func extractPlayerConcussionMissileDrawItems(
    _ level: Level,
    missiles: [PlayerConcussionMissileFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let binding = level.shipDefinitions.first?.playerConcussion,
          let model = level.models.first(where: {
              $0.source == binding.model
          }) else {
        return []
    }
    precondition(missiles.count <= playerConcussionMissilePresentationCapacity)
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return missiles.enumerated().flatMap { slot, missile in
        let object = PlacedObject(
            handle: UInt32.max - 6_000 - UInt32(slot),
            type: 5,
            storedID: binding.weapon.storedIndex,
            definition: binding.weapon,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(missile.roomSourceIndex),
            position: missile.position,
            orientation: missile.orientation,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

func extractPreparedTrainingGuidebotYellowFlareDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
    guard let definition =
            level.trainingRobotGuidebotChain?.yellowFlare,
          let guidebot = level.objects.first(where: {
              $0.handle
                == level.trainingRobotGuidebotChain?
                    .guidebotObjectHandle
          }),
          case let .room(roomSourceIndex) = guidebot.location
    else {
        return []
    }
    return extractTrainingGuidebotYellowFlareDrawItems(
        level,
        flares:
            (0..<combinedYellowFlarePresentationCapacity).map {
                _ in .init(
                    roomSourceIndex: roomSourceIndex,
                    position: guidebot.position,
                    orientation: guidebot.orientation,
                    velocity:
                        guidebot.orientation.forward
                            * definition.speed,
                    model: definition.model,
                    collisionRadius: definition.collisionRadius,
                    lifeRemaining: definition.lifetime,
                    sourceLightDistance:
                        definition.lightDistance,
                    lightDistance: definition.lightDistance,
                    lightPresentation:
                        definition.lightPresentation
                )
            },
        camera: .trainingRoom3
    )
}

func extractTrainingGuidebotYellowFlareDrawItems(
    _ level: Level,
    flares: [TrainingGuidebotYellowFlareFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let definition =
            level.trainingRobotGuidebotChain?.yellowFlare,
          let model = level.models.first(where: {
              $0.source == definition.model
          })
    else {
        return []
    }
    precondition(
        flares.count
            <= combinedYellowFlarePresentationCapacity
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return flares.enumerated().flatMap { slot, flare in
        let object = PlacedObject(
            handle: UInt32.max - 1_000 - UInt32(slot),
            type: 5,
            storedID: definition.source.storedIndex,
            definition: definition.source,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(flare.roomSourceIndex),
            position: flare.position,
            orientation: flare.orientation,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: flare.lifeRemaining,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

private func accumulatedModelOffsets(_ model: CanonicalModel) -> [Vector3] {
    var offsets = [Vector3?](repeating: nil, count: model.submodels.count)

    func resolve(_ sourceIndex: Int) -> Vector3 {
        if let offset = offsets[sourceIndex] { return offset }

        let submodel = model.submodels[sourceIndex]
        let parentOffset = submodel.parentIndex.map(resolve) ?? .zero
        let offset = parentOffset + submodel.offset
        offsets[sourceIndex] = offset
        return offset
    }

    return model.submodels.indices.map(resolve)
}

func extractSourceLightCoronas(
    _ level: Level,
    camera: RoomCamera,
    visibility: SourceVisibleWorld,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32? = nil
) throws -> [WorldLightCorona] {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var result: [WorldLightCorona] = []
    for visibleFace in visibility.faces {
        let room = roomBySourceIndex[visibleFace.roomSourceIndex]!
        let face = room.faces[visibleFace.faceIndex]
        guard face.portalIndex == nil,
              face.allowsLightCorona,
              let corona = materialByTexture[face.texture]?.lightCorona else {
            continue
        }
        guard level.presentationCoronaAssets.indices.contains(corona.assetIndex) else {
            throw RoomRenderExtractionError.missingCoronaAsset(corona.assetIndex)
        }
        let geometry = sourceFaceCoronaGeometry(room: room, face: face)
        let eyeOffset = geometry.center - camera.position
        let distance = sqrt(dot(eyeOffset, eyeOffset))
        guard distance >= geometry.size * 5 else { continue }
        guard !sourceCoronaRayIsOccluded(
            from: camera.position,
            to: geometry.center,
            level: level,
            visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
            startRoomSourceIndex: startRoomSourceIndex,
            excludedObjectHandle: excludedObjectHandle
        ) else {
            continue
        }
        result.append(
            WorldLightCorona(
                roomSourceIndex: room.sourceIndex,
                faceIndex: visibleFace.faceIndex,
                assetIndex: corona.assetIndex,
                center: geometry.center,
                size: geometry.size,
                firstVertex: room.vertices[face.corners[0].vertexIndex],
                normal: faceNormal(room, face: face),
                tint: corona.tint,
                blend: corona.blend
            )
        )
    }
    return result
}

private func sourceFaceCoronaGeometry(
    room: LevelRoom,
    face: LevelFace
) -> (center: Vector3, size: Float) {
    let first = room.vertices[face.corners[0].vertexIndex]
    var totalArea: Float = 0
    var weightedX: Float = 0
    var weightedY: Float = 0
    var weightedZ: Float = 0
    for index in 1..<(face.corners.count - 1) {
        let second = room.vertices[face.corners[index].vertexIndex]
        let third = room.vertices[face.corners[index + 1].vertexIndex]
        let perpendicular = cross(second - first, third - first)
        let area = sqrt(dot(perpendicular, perpendicular)) / 2
        totalArea += area
        weightedX += ((first.x + second.x + third.x) / 3) * area
        weightedY += ((first.y + second.y + third.y) / 3) * area
        weightedZ += ((first.z + second.z + third.z) / 3) * area
    }
    precondition(totalArea > 0, "validated corona faces must have positive area")
    let normal = faceNormal(room, face: face)
    return (
        Vector3(
            x: weightedX / totalArea + normal.x / 4,
            y: weightedY / totalArea + normal.y / 4,
            z: weightedZ / totalArea + normal.z / 4
        ),
        2 * sqrt(totalArea)
    )
}

private func sourceCoronaRayIsOccluded(
    from origin: Vector3,
    to destination: Vector3,
    level: Level,
    visibleRoomSourceIndices: [Int],
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> Bool {
    let ray = destination - origin
    let distance = sqrt(dot(ray, ray))
    let direction = ray / distance
    let visibleRooms = Set(visibleRoomSourceIndices)
    if case let .wallHit(contact) = traceIndoorMovement(
        in: level,
        startRoom: startRoomSourceIndex,
        start: origin,
        end: destination,
        radius: 0
    ).outcome, contact.distance < distance - 0.000_1 {
        return true
    }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              object.type == 2 || object.type == 4,
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle],
              presentation.isVisible,
              let model = modelBySource[presentation.primaryModel] else {
            continue
        }
        let radius = sourceObjectPresentationSize(
            model: model,
            objectType: object.type
        )
        let originToCenter = object.position - origin
        let projectedDistance = dot(originToCenter, direction)
        guard projectedDistance > 0, projectedDistance < distance else { continue }
        let closest = origin + direction * projectedDistance
        let centerOffset = object.position - closest
        if dot(centerOffset, centerOffset) <= radius * radius {
            return true
        }
    }
    return false
}

func extractSourceVisibleWorld(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    portalBlends: [SourceResource: PresentationBlend]
) throws -> SourceVisibleWorld {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    guard roomBySourceIndex[startRoomSourceIndex] != nil else {
        throw RoomRenderExtractionError.missingRoom(startRoomSourceIndex)
    }
    let view = CameraView(camera)
    var roomDepth = [startRoomSourceIndex: 0]
    var seenRooms: Set<Int> = []
    var visibleRoomSourceIndices: [Int] = []
    var visibleFacesByRoom: [Int: Set<Int>] = [:]
    var portalEdges: [RenderPortalEdge] = []
    var objectClipWindowsByRoom: [Int: [SourceClipWindow]] = [:]

    func renderPastPortal(_ room: LevelRoom, portalIndex: Int) throws -> Bool {
        let portal = room.portals[portalIndex]
        guard portal.flags & 0x0000_0001 != 0 else { return true }
        let face = room.faces[portal.faceIndex]
        guard let blend = portalBlends[face.texture] else {
            throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
        }
        if case .additiveSourceAlpha = blend { return true }
        return false
    }

    func visit(_ roomSourceIndex: Int, window: ClipWindow, depth: Int) throws {
        guard let room = roomBySourceIndex[roomSourceIndex] else {
            throw RoomRenderExtractionError.missingRoom(roomSourceIndex)
        }
        if seenRooms.insert(roomSourceIndex).inserted {
            visibleRoomSourceIndices.append(roomSourceIndex)
        }
        objectClipWindowsByRoom[roomSourceIndex, default: []].append(window)
        if visibleFacesByRoom[roomSourceIndex] == nil {
            visibleFacesByRoom[roomSourceIndex] = depth == 0
                ? Set(room.faces.indices.filter {
                    faceIsFrontFacing(room, faceIndex: $0, eye: camera.position)
                })
                : []
        }

        for (portalIndex, portal) in room.portals.enumerated() {
            portalEdges.append(
                RenderPortalEdge(
                    roomSourceIndex: roomSourceIndex,
                    portalIndex: portalIndex,
                    faceIndex: portal.faceIndex,
                    connectedRoom: portal.connectedRoom,
                    connectedPortal: portal.connectedPortal,
                    presentation: portal.flags & 0x0000_0001 != 0
                        ? .renderedSurface
                        : .openBoundary
                )
            )
            if let connectedDepth = roomDepth[portal.connectedRoom], connectedDepth < depth {
                continue
            }
            guard faceIsFrontFacing(room, faceIndex: portal.faceIndex, eye: camera.position),
                  let portalWindow = projectedPortalWindow(
                      room,
                      faceIndex: portal.faceIndex,
                      view: view,
                      parent: window
                  ) else {
                continue
            }
            guard try renderPastPortal(room, portalIndex: portalIndex) else { continue }
            guard let connected = roomBySourceIndex[portal.connectedRoom] else {
                throw RoomRenderExtractionError.missingRoom(portal.connectedRoom)
            }
            var marked = visibleFacesByRoom[portal.connectedRoom] ?? []
            for faceIndex in connected.faces.indices where
                faceIsFrontFacing(connected, faceIndex: faceIndex, eye: camera.position)
                && faceIntersectsWindow(
                    connected,
                    faceIndex: faceIndex,
                    view: view,
                    window: portalWindow
                ) {
                marked.insert(faceIndex)
            }
            visibleFacesByRoom[portal.connectedRoom] = marked
            roomDepth[portal.connectedRoom] = depth + 1
            try visit(portal.connectedRoom, window: portalWindow, depth: depth + 1)
            roomDepth[portal.connectedRoom] = 255
        }
    }

    try visit(
        startRoomSourceIndex,
        window: .init(left: -1, top: 1, right: 1, bottom: -1),
        depth: 0
    )
    return SourceVisibleWorld(
        visibleRoomSourceIndices: visibleRoomSourceIndices,
        faces: visibleRoomSourceIndices.flatMap { roomSourceIndex in
            let room = roomBySourceIndex[roomSourceIndex]!
            return (visibleFacesByRoom[roomSourceIndex] ?? []).sorted().compactMap {
                faceIsRenderable(room, face: room.faces[$0])
                    ? SourceVisibleFace(roomSourceIndex: roomSourceIndex, faceIndex: $0)
                    : nil
            }
        },
        portalEdges: portalEdges,
        objectClipWindowsByRoom: objectClipWindowsByRoom
    )
}

func sourceRoomThreeContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    precondition(
        room.sourceIndex == 3,
        "Slice 3 camera containment is defined only for source room 3"
    )
    return sourceConvexRoomContains(point, in: room)
}

func sourceConvexRoomContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    room.faces.allSatisfy { face in
        let first = room.vertices[face.corners[0].vertexIndex]
        return dot(point - first, faceNormal(room, face: face)) >= 0
    }
}

private func faceIsRenderable(_ room: LevelRoom, face: LevelFace) -> Bool {
    guard let portalIndex = face.portalIndex else { return true }
    return room.portals[portalIndex].flags & 0x0000_0001 != 0
}

private func makeDrawItem(
    room: LevelRoom,
    faceIndex: Int,
    material: PresentationMaterial,
    lightmaps: LightmapCatalog
) throws -> RoomDrawItem {
    let face = room.faces[faceIndex]
    let lightmapPageIndex: Int?
    if let infoIndex = face.lightmapInfoIndex {
        let pageIndex = lightmaps.infos[infoIndex].pageIndex
        let page = lightmaps.pages[pageIndex]
        guard page.rgba8?.count == page.width * page.height * 4 else {
            throw RoomRenderExtractionError.missingLightmap(pageIndex)
        }
        lightmapPageIndex = pageIndex
    } else {
        lightmapPageIndex = nil
    }
    let vertices = face.corners.map { corner in
        WorldRenderVertex(
            position: room.vertices[corner.vertexIndex],
            u: corner.u,
            v: corner.v,
            lightmapU: corner.lightmapU ?? 0,
            lightmapV: corner.lightmapV ?? 0,
            alpha: Float(corner.alpha) / 255
        )
    }
    var triangleIndices: [UInt32] = []
    for index in 1..<(vertices.count - 1) {
        triangleIndices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
    }
    return RoomDrawItem(
        roomSourceIndex: room.sourceIndex,
        faceIndex: faceIndex,
        texture: face.texture,
        blend: material.blend,
        lightmapBlend: material.lightmapBlend,
        lightmapPageIndex: lightmapPageIndex,
        vertices: vertices,
        triangleIndices: triangleIndices
    )
}

private struct CameraView {
    let eye: Vector3
    let right: Vector3
    let up: Vector3
    let forward: Vector3
    let horizontalProjectionScale: Float
    let verticalProjectionScale: Float

    init(_ camera: RoomCamera) {
        eye = camera.position
        forward = normalized(camera.target - camera.position)
        right = normalized(cross(forward, camera.up))
        up = cross(right, forward)
        precondition(
            camera.projection.horizontalFieldOfViewRadians.isFinite
                && camera.projection.aspectRatio.isFinite
                && camera.projection.horizontalFieldOfViewRadians > 0
                && camera.projection.horizontalFieldOfViewRadians < .pi
                && camera.projection.aspectRatio > 0,
            "camera projection must be finite and positive"
        )
        horizontalProjectionScale = 1 / tan(
            camera.projection.horizontalFieldOfViewRadians / 2
        )
        verticalProjectionScale = horizontalProjectionScale * camera.projection.aspectRatio
    }

    func project(_ point: Vector3) -> ProjectedPoint {
        let relative = point - eye
        let depth = dot(relative, forward)
        return ProjectedPoint(
            x: dot(relative, right) * horizontalProjectionScale / depth,
            y: dot(relative, up) * verticalProjectionScale / depth,
            depth: depth
        )
    }

    func depth(of point: Vector3) -> Float {
        dot(point - eye, forward)
    }
}

private struct ProjectedPoint {
    let x: Float
    let y: Float
    let depth: Float
}

private typealias ClipWindow = SourceClipWindow

private func projectedPortalWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    parent: ClipWindow
) -> ClipWindow? {
    guard faceIntersectsWindow(room, faceIndex: faceIndex, view: view, window: parent) else {
        return nil
    }
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    guard points.allSatisfy({ $0.depth > 0 }) else { return nil }
    let left = max(parent.left, points.map(\.x).min()!)
    let right = min(parent.right, points.map(\.x).max()!)
    let bottom = max(parent.bottom, points.map(\.y).min()!)
    let top = min(parent.top, points.map(\.y).max()!)
    guard left <= right, bottom <= top else { return nil }
    return ClipWindow(left: left, top: top, right: right, bottom: bottom)
}

private func faceIntersectsWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    window: ClipWindow
) -> Bool {
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    let codes = points.map { clipCode($0, window: window) }
    let combinedAnd = codes.reduce(UInt8.max, &)
    if combinedAnd != 0 { return false }
    let combinedOr = codes.reduce(UInt8.zero, |)
    if combinedOr == 0 { return true }
    for index in points.indices {
        let start = points[index]
        let end = points[(index + 1) % points.count]
        if lineIntersectsLine(start, end, window.left, window.top, window.right, window.top)
            || lineIntersectsLine(start, end, window.right, window.top, window.right, window.bottom)
            || lineIntersectsLine(start, end, window.right, window.bottom, window.left, window.bottom)
            || lineIntersectsLine(start, end, window.left, window.bottom, window.left, window.top) {
            return true
        }
    }
    return false
}

private func clipCode(_ point: ProjectedPoint, window: ClipWindow) -> UInt8 {
    guard point.depth > 0 else { return 0x10 }
    var code: UInt8 = 0
    if point.x < window.left { code |= 0x01 }
    if point.x > window.right { code |= 0x02 }
    if point.y > window.top { code |= 0x04 }
    if point.y < window.bottom { code |= 0x08 }
    return code
}

private func lineIntersectsLine(
    _ start: ProjectedPoint,
    _ end: ProjectedPoint,
    _ x1: Float,
    _ y1: Float,
    _ x2: Float,
    _ y2: Float
) -> Bool {
    var numerator = (start.y - y1) * (x2 - x1) - (start.x - x1) * (y2 - y1)
    let denominator = (end.x - start.x) * (y2 - y1) - (end.y - start.y) * (x2 - x1)
    let r = numerator / denominator
    if (0...1).contains(r) { return true }
    numerator = (start.y - y1) * (end.x - start.x) - (start.x - x1) * (end.y - start.y)
    let s = numerator / denominator
    return (0...1).contains(s)
}

private func faceIsFrontFacing(_ room: LevelRoom, faceIndex: Int, eye: Vector3) -> Bool {
    let face = room.faces[faceIndex]
    let normal = faceNormal(room, face: face)
    let first = room.vertices[face.corners[0].vertexIndex]
    return dot(eye - first, normal) > 0
}

private func faceNormal(_ room: LevelRoom, face: LevelFace) -> Vector3 {
    guard let normal = canonicalFaceNormal(room: room, face: face) else {
        preconditionFailure("validated faces must have a usable normal")
    }
    return normal
}

private func normalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0, "camera basis vectors must be nonzero")
    return value / magnitude
}

private func sourceOrientation(
    forward targetForward: Vector3,
    up targetUp: Vector3
) -> Matrix3 {
    let forward = normalized(targetForward)
    let right = normalized(cross(targetUp, forward))
    return .init(
        right: right,
        up: normalized(cross(forward, right)),
        forward: forward
    )
}

private func trainingTurnedTowardMatrix(
    _ orientation: Matrix3,
    target: Matrix3,
    maximumTurnRate: Float,
    duration: Float
) -> Matrix3 {
    let relative = sourceMatrixMultiply(
        sourceTransposed(orientation),
        target
    )
    let angles = sourceExtractAngles(relative)
    let bankDistance = Float(
        angles.roll > 32_768
            ? 65_536 - angles.roll : angles.roll
    )
    let headingDistance = Float(
        angles.yaw > 32_768
            ? 65_536 - angles.yaw : angles.yaw
    )
    let pitchDistance = Float(
        angles.pitch > 32_768
            ? 65_536 - angles.pitch : angles.pitch
    )
    let distance = Vector3(
        x: bankDistance,
        y: headingDistance,
        z: pitchDistance
    )
    let angleMagnitude = sqrt(dot(distance, distance))
    let maximumAngle = maximumTurnRate * duration
    if angleMagnitude <= maximumAngle {
        return sourceOrthogonalized(target)
    }

    let scale = angleMagnitude > 0
        ? maximumAngle / angleMagnitude : 0
    func scaledAngle(
        _ original: Int,
        distance: Float
    ) -> Int16 {
        let scaled = distance * scale
        let sourceValue = original > 32_768
            ? Int(65_535 - scaled) : Int(scaled)
        return Int16(
            bitPattern: UInt16(truncatingIfNeeded: sourceValue)
        )
    }
    let increment = sourceRotationMatrix(
        pitch: scaledAngle(
            angles.pitch,
            distance: pitchDistance
        ),
        yaw: scaledAngle(
            angles.yaw,
            distance: headingDistance
        ),
        roll: scaledAngle(
            angles.roll,
            distance: bankDistance
        )
    )
    return sourceOrthogonalized(
        sourceMatrixMultiply(orientation, increment)
    )
}

private func trainingTurnedTowardDirection(
    _ orientation: Matrix3,
    velocity: Vector3,
    maximumTurnRate: Float,
    duration: Float
) -> Matrix3 {
    let speed = sqrt(dot(velocity, velocity))
    guard speed > 0.1 else { return orientation }
    let target = velocity / speed
    let cosine = max(
        -1,
        min(1, dot(orientation.forward, target))
    )
    guard cosine < 0.999_85 else { return orientation }
    let angle = acos(cosine)
    let maximumAngle =
        maximumTurnRate * duration * (2 * Float.pi / 65_536)
    let forward: Vector3
    if angle <= maximumAngle {
        forward = target
    } else {
        let sine = sin(angle)
        if abs(sine) <= 0.000_001 {
            forward = normalized(
                orientation.forward * cos(maximumAngle)
                    + orientation.right * sin(maximumAngle)
            )
        } else {
            let blend = maximumAngle / angle
            forward = normalized(
                orientation.forward
                    * (sin((1 - blend) * angle) / sine)
                    + target * (sin(blend * angle) / sine)
            )
        }
    }
    var right = cross(orientation.up, forward)
    if dot(right, right) <= 0.000_001 {
        right = orientation.right
    } else {
        right = normalized(right)
    }
    return sourceOrthogonalized(
        .init(
            right: right,
            up: cross(forward, right),
            forward: forward
        )
    )
}

private func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private func transform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    matrix.right * value.x + matrix.up * value.y + matrix.forward * value.z
}

private func transform(_ value: Matrix3, by matrix: Matrix3) -> Matrix3 {
    .init(
        right: transform(value.right, by: matrix),
        up: transform(value.up, by: matrix),
        forward: transform(value.forward, by: matrix)
    )
}

private func inverseTransform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    .init(
        x: dot(value, matrix.right),
        y: dot(value, matrix.up),
        z: dot(value, matrix.forward)
    )
}

private func inverseTransform(_ value: Matrix3, by matrix: Matrix3) -> Matrix3 {
    .init(
        right: inverseTransform(value.right, by: matrix),
        up: inverseTransform(value.up, by: matrix),
        forward: inverseTransform(value.forward, by: matrix)
    )
}

private func * (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

private func / (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
}

private func dot(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

private func cross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}
