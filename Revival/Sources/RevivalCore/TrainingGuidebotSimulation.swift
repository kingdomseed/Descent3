// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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
            sourceVectorNormalized(startNodes[$0].position - start)
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

func trainingCameraMonitorGoalTarget(
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

func trainingCameraMonitorObjectTarget(
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

extension PlayerSimulation {
    func assignTrainingFollowBotPath(
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

    func assignTrainingAuthoredPath(
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

    func advanceTrainingFollowBot(duration: Float) {
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

    func advanceTrainingMovingTarget(duration: Float) {
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

    func restoreTrainingFollowBotPresentation() {
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

    func nextAuthoritativeRandomValue() -> UInt32 {
        authoritativeRandomState =
            authoritativeRandomState &* 214_013 &+ 2_531_011
        return (authoritativeRandomState >> 16) & 0x7fff
    }

    private func nextAuthoritativeRandomFraction() -> Float {
        Float(nextAuthoritativeRandomValue()) / 32_767
    }

    func trainingDodgeSpreadDirection(
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

    func advanceTrainingGuidebotTiming(
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

    func trainingGuidebotFeedback(
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

    func completeTrainingGuidebotReturn(
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

    func requestTrainingGuidebotActiveGoal(
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
        let startForward = sourceVectorNormalized(
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

    func deployTrainingGuidebot(
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

    func releaseTrainingGuidebot(
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

    func restoreTrainingGuidebotPresentation() {
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

    func advanceTrainingGuidebot(
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
                let startForward = sourceVectorNormalized(
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
            : sourceVectorNormalized(remaining) * definition.maximumVelocity
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
            let startForward = sourceVectorNormalized(
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

    func trainingGuidebotYellowFlareVisualOpacity(
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

    func trainingGuidebotYellowFlareParticleTexture(
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

    func trainingGuidebotYellowFlareCarrierTexture(
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

    func appendTrainingGuidebotYellowFlareParticle(
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

    func advanceTrainingGuidebotYellowFlareTimeoutSpark(
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

    func advanceTrainingGuidebotYellowFlares(
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
    func requestTrainingGuidebotReturn(
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
        let startForward = sourceVectorNormalized(
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
}

func completeTrainingCameraMonitorLocateGoal(
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

func trainingCameraMonitorFrame(
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
    let forward = sourceVectorNormalized(
        cameraObject.orientation.right * localForward.x
            + cameraObject.orientation.up * localForward.y
            + cameraObject.orientation.forward * localForward.z
    )
    let up: Vector3
    if forward.x == 0 && forward.z == 0 {
        up = .init(x: 0, y: 0, z: forward.y < 0 ? 1 : -1)
    } else {
        let right = sourceVectorNormalized(.init(
            x: forward.z,
            y: 0,
            z: -forward.x
        ))
        up = sourceVectorCross(forward, right)
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
            forward = sourceVectorNormalized(
                orientation.forward * cos(maximumAngle)
                    + orientation.right * sin(maximumAngle)
            )
        } else {
            let blend = maximumAngle / angle
            forward = sourceVectorNormalized(
                orientation.forward
                    * (sin((1 - blend) * angle) / sine)
                    + target * (sin(blend * angle) / sine)
            )
        }
    }
    var right = sourceVectorCross(orientation.up, forward)
    if dot(right, right) <= 0.000_001 {
        right = orientation.right
    } else {
        right = sourceVectorNormalized(right)
    }
    return sourceOrthogonalized(
        .init(
            right: right,
            up: sourceVectorCross(forward, right),
            forward: forward
        )
    )
}
