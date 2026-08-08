// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension PlayerSimulation {
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
                            : sourceVectorNormalized(rawDirection)
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
                                    + sourceVectorNormalized(away)
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
