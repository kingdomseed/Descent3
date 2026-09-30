// SPDX-License-Identifier: GPL-3.0-or-later
//
// The bespoke Training code that the Guide-Bot's scripts still leave to
// Swift: the Guide-Bot's flares (M1 step 8d) and the Camera Monitor
// presentation (M1 step 9).
// The Guide-Bot itself is the AIGame GuideBot script
// (Scripts/AIGame+GuideBot.swift).

import Foundation

extension GameWorld {
    /// The bespoke flare path of MSAFE_OBJECT_FIRE_WEAPON: a weapon the
    /// level's bespoke flare definition names becomes a flare shot at the
    /// firing object's place. Returns whether it took the weapon.
    mutating func fireBespokeFlareFromObject(
        _ handle: ObjectHandle,
        weaponName: String,
        level: Level
    ) -> Bool {
        guard let definition = level.trainingRobotGuidebotChain?.yellowFlare,
              definition.source.sourceName
                .caseInsensitiveCompare(weaponName) == .orderedSame,
              trainingRobotGuidebotState?.yellowFlares != nil,
              let object = objects[handle],
              case let .room(room) = object.location
        else {
            return false
        }
        trainingGuidebotFlareShots.append(.init(
            parent: handle,
            roomSourceIndex: room,
            position: object.position,
            orientation: object.orientation
        ))
        return true
    }
}

extension GameSession {
    func nextAuthoritativeRandomValue() -> UInt32 {
        authoritativeRandomState =
            authoritativeRandomState &* 214_013 &+ 2_531_011
        return (authoritativeRandomState >> 16) & 0x7fff
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

    /// Makes the bespoke flares the Guide-Bot fired this update, after the
    /// flares moved, from the Guide-Bot's place at the shot.
    func createTrainingGuidebotFlareShots(gameTime: Float) {
        let shots = world.trainingGuidebotFlareShots
        world.trainingGuidebotFlareShots = []
        guard let definition = level.trainingRobotGuidebotChain?.yellowFlare
        else {
            return
        }
        for shot in shots {
            guard var state = trainingRobotGuidebotState,
                  state.yellowFlares != nil,
                  state.yellowFlares!.count
                    < trainingGuidebotYellowFlarePresentationCapacity
            else {
                continue
            }
            let usesSharedCreationOrdinals = playerYellowFlareState != nil
            let creationOrdinal = usesSharedCreationOrdinals
                ? nextYellowFlareCreationOrdinal()
                : nil
            guard !usesSharedCreationOrdinals || creationOrdinal != nil else {
                continue
            }
            state = trainingRobotGuidebotState!
            let orientation = sourceOrientation(
                forward: shot.orientation.forward,
                up: shot.orientation.up
            )
            let receivesTimeout = definition.timeout != nil
                && state.yellowFlareTimeoutReachedFollowingFrame == false
                && state.yellowFlareTimeoutSparks?.isEmpty == true
                && !state.yellowFlares!.contains {
                    $0.sourceObjectSlot != nil
                }
            state.yellowFlares!.append(.init(
                roomSourceIndex: shot.roomSourceIndex,
                position: shot.position,
                orientation: orientation,
                velocity: orientation.forward * definition.speed,
                lifeRemaining: definition.lifetime,
                lastParticleDropTime: 0,
                presentedLightDistance: definition.lightDistance,
                // DestroyBot2's released slot 16 is the top of the LIFO
                // free stack when this first retained flare is created.
                sourceObjectSlot: receivesTimeout ? 16 : nil,
                creationOrdinal: creationOrdinal,
                parentObjectHandle: shot.parent.rawValue
            ))
            trainingRobotGuidebotState = state
        }
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
               let object = world.objects[ObjectHandle(handle)],
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
            let parentHandle =
                flare.parentObjectHandle
                    ?? level.trainingRobotGuidebotChain!.guidebotObjectHandle
            let nearestObjectHit = world.objects.compactMap {
                object -> (object: GameObject, fraction: Float)? in
                guard case let .room(objectRoomSourceIndex) = object.location,
                      trace.visitedRoomSourceIndices.contains(
                          objectRoomSourceIndex
                      ),
                      age >= 3 || object.handle.rawValue != parentHandle,
                      // A weapon does not collide with OBJ_DUMMY (a ghosted
                      // object, such as the Guide-Bot in the ship) or a
                      // powerup (CollideInit, collide.cpp:2585-2640).
                      object.type != .dummy, object.type != .powerup,
                      // fvi skips an object with the same parent
                      // (ObjectsAreRelated, findintersection.cpp:3364).
                      object.parent.rawValue != parentHandle
                        || object.parent == .none,
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
                flare.stuckObjectHandle = hit.object.handle.rawValue
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
}

func completeTrainingCameraMonitorLocateGoal(
    in world: inout GameWorld,
    pickupObjectHandle: UInt32
) {
    guard let goalIndex = world.goals.firstIndex(where: { goal in
        goal.status & 0x0000_0400 != 0
            && goal.items.contains {
                $0.type == 2
                    && $0.objectHandle == pickupObjectHandle
            }
    }) else {
        return
    }
    let goal = world.goals[goalIndex]
    world.goals[goalIndex] = .init(
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
    world: GameWorld,
    state: TrainingCameraMonitorState?
) -> TrainingCameraMonitorFrame? {
    guard let chain = level.trainingCameraMonitorChain,
          let remainingDuration = state?.popupRemaining,
          let cameraObject =
              world.objects[ObjectHandle(chain.securityCameraObjectHandle)],
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
        roomStates: world.rooms,
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
