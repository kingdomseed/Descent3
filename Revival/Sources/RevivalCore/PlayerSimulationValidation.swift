// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

func trainingGalleryBarrierRendersFaces(
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

func validTrainingGalleryBarrierContinuation(
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

func validTrainingManeuverFollowContinuation(
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
            && state.position == followBot.position
            && state.orientation == followBot.orientation
            && state.velocity == .zero
            && state.pathFailure == nil
    }
    return state.followBotIsPowered
        && state.followBotTeamFlags == lesson.friendlyTeamFlags
        && sourceConvexRoomContains(state.position, in: followBotRoom)
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

func validTrainingDodgeAttemptContinuation(
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
func validPlayerConcussionContinuation(
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

func validPlayerYellowFlareContinuation(
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

func validTrainingRobotGuidebotContinuation(
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

func validTrainingCameraMonitorContinuation(
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

func validTrainingKillbotEntryContinuation(
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

func validTrainingRASBot1DeathContinuation(
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

func validTrainingRASBot2DeathContinuation(
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

func validTrainingRASBot3DeathContinuation(
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

func validTrainingRASBot4DeathContinuation(
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

func validTrainingLastBot1DeathContinuation(
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

func validTrainingLastBot2DeathContinuation(
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

func validTrainingLastBot3DeathContinuation(
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

func validTrainingLastBot4DeathContinuation(
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

func validTrainingLastBot5DeathContinuation(
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

func validTrainingInvulnerabilityPickupContinuation(
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

func validTrainingCloakPickupContinuation(
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

func validTrainingLastRoomContinuation(
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

func validTrainingFinalBotsCompletionContinuation(
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

func validTrainingFinalGoalContinuation(
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

func validTrainingFinalRoomEntryContinuation(
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
func setObjectPresentationVisibility(
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
