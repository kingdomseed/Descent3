// SPDX-License-Identifier: GPL-3.0-or-later
//
// The bespoke player yellow flare, which shares its state with the
// Guide-Bot's flares until the Guide-Bot moves onto the AIGame default
// script and FireFlareFromPlayer (WeaponFire.cpp:3023) in M1 step 8.

import Foundation

extension GameSession {
    func firePlayerYellowFlare(
        from player: GameObject,
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
            roomStates: world.rooms,
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
        let forward = sourceVectorNormalized(transform(
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
            parentObjectHandle: player.handle.rawValue
        ))
        playerYellowFlareState = state
        return .init(
            hudMessages: [],
            voiceSourceName: "",
            voicePrecedesHUDMessages: true,
            soundSourceName: binding.fireSoundSourceName
        )
    }

    func advancePlayerYellowFlares(
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
               let object = world.objects[ObjectHandle(handle)],
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
                    roomStates: world.rooms,
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
                let nearestObjectHit = world.objects.compactMap {
                    object -> (GameObject, Float)? in
                    guard case let .room(objectRoom) = object.location,
                          trace.visitedRoomSourceIndices.contains(objectRoom),
                          age >= 3
                            || object.handle.rawValue
                                != flare.parentObjectHandle,
                          let presentation =
                            level.objectPresentations.first(where: {
                                $0.objectHandle == object.handle.rawValue
                            }),
                          object.renderType == .polyobj,
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
                    flare.stuckObjectHandle = hit.0.handle.rawValue
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
}
