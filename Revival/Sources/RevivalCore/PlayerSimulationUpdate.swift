// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension GameSession {
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
    func update(at timestamp: Double, input: InputSnapshot) -> PlayerSimulationFrame {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        precondition(pauseDepth == 0)
        let systemsFrameDuration = frameDuration
        let systemsGameTime = gameTime

        let binding = level.defaultPlayerBinding!
        let playerHandle = ObjectHandle(binding.objectHandle)
        var object = world.objects[playerHandle]!
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
                controllerBitflags: world.playerControllerBitflags
            )
        let input = controlsAreSuspended
            ? InputSnapshot.zero
            : input.applying(currentEnabledControls)
        var playerHeadlightFeedback: TrainingOpeningFeedback?
        var playerConcussionFeedback: [TrainingOpeningFeedback] = []
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
            world.objects.delete(ObjectHandle(chain.pickupObjectHandle))
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
        let view = defaultPlayerView(in: level, objects: world.objects)
        var position = object.position
        var roomSourceIndex = startRoom
        // The objects hit this frame (ignore_obj_list, physics.cpp:1535).
        var collidedObjects: [ObjectHandle] = []
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
                roomStates: world.rooms,
                startRoom: roomSourceIndex,
                start: position,
                end: position + linearThrustOrientation.up * wiggle,
                radius: view.collisionRadius
            )
            trainingCameraMonitorWasHitThisFrame =
                trainingCameraMonitorWasHitThisFrame
                || trainingCameraMonitorPickupWasHit(
                    in: level,
                    objects: world.objects,
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
                    objects: world.objects,
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
                    objects: world.objects,
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
                    objects: world.objects,
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
            // fvi_FindIntersection returns the nearest hit, a wall or an
            // object (physics.cpp:986-1080). The walls come from the
            // current portal flags, so a script that changed them during an
            // earlier object hit of this frame is seen here.
            let wallTrace = traceIndoorMovement(
                in: level,
                roomStates: world.rooms,
                startRoom: roomSourceIndex,
                start: position,
                end: integrated.position,
                radius: view.collisionRadius
            )
            let objectHit = world.nearestMoveObjectHit(
                playerHandle,
                start: traceStart,
                end: wallTrace.finalPosition,
                radius: view.collisionRadius,
                visitedRoomSourceIndices: wallTrace.visitedRoomSourceIndices,
                ignored: collidedObjects,
                level: level
            )
            let trace = objectHit.map { hit in
                let move = wallTrace.finalPosition - traceStart
                let length = sqrt(dot(move, move))
                return traceIndoorMovement(
                    in: level,
                    roomStates: world.rooms,
                    startRoom: roomSourceIndex,
                    start: traceStart,
                    end: traceStart + move * (hit.distance / length),
                    radius: view.collisionRadius
                )
            } ?? wallTrace
            trainingCameraMonitorWasHitThisFrame =
                trainingCameraMonitorWasHitThisFrame
                || trainingCameraMonitorPickupWasHit(
                    in: level,
                    objects: world.objects,
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
                    objects: world.objects,
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
                    objects: world.objects,
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
                    objects: world.objects,
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
            // HIT_OBJECT (physics.cpp:1503-1560): the player stops at the
            // hit point, the remaining time shrinks by the distance moved,
            // collide_two_objects runs, and a powerup goes on the ignore list.
            // The count-- (:1556) means a powerup hit does not use up a loop.
            // The wiggle move ignores powerups (FQ_IGNORE_POWERUPS, :796).
            if let objectHit {
                let attemptedDistance =
                    vectorDistance(position, integrated.position)
                let movedDistance = vectorDistance(
                    position,
                    trace.finalPosition
                )
                let priorRemainingDuration = remainingDuration
                remainingDuration = priorRemainingDuration
                    * ((attemptedDistance - movedDistance) / attemptedDistance)
                let movedTime = priorRemainingDuration - remainingDuration
                if movedTime > 0.0001 {
                    velocity = (trace.finalPosition - position) / movedTime
                }
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
                world.objects[playerHandle]!.position = position
                world.objects[playerHandle]!.location = .room(roomSourceIndex)
                collidedObjects.append(objectHit.handle)
                world.collideTwoObjects(
                    playerHandle,
                    objectHit.handle,
                    level: level
                )
                continue
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
        world.objects[playerHandle]!.position = position
        world.objects[playerHandle]!.location = .room(roomSourceIndex)
        let playerFastHeadlight = playerHeadlightIsOn
            ? fastPlayerHeadlight(from: world.objects[playerHandle]!)
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
            player: world.objects[playerHandle]!,
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
            playerHandle: playerHandle,
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
                world.objects.delete(ObjectHandle(chain.pickupObjectHandle))
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
                world.objects.delete(ObjectHandle(chain.pickupObjectHandle))
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
            openTrainingLastRoomBarrier(in: &world, level: level)
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
            openTrainingFinalBotsBarrier(in: &world, level: level)
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
                openTrainingGuidebotReturnBarrier(in: &world, level: level)
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
                in: &world,
                pickupObjectHandle: chain.pickupObjectHandle
            )
            world.setObjectRendered(chain.pickupObjectHandle, false)
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
            closeTrainingGalleryBarrier(in: &world, level: level)
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
            closeTrainingKillbotEntryBarrier(in: &world, level: level)
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
            closeTrainingLastRoomBarrier(in: &world, level: level)
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
        // DoPlayerFrame, the level EVT_INTERVAL, then Osiris_ProcessTimers
        // (GameLoop.cpp:2992, :3013-3014), with the previous Frametime and
        // the pre-update Gametime.
        world.doPlayerInvulnerabilityFrame(frameTime: systemsFrameDuration)
        world.osirisCallLevelEvent(
            .interval(
                frameTime: systemsFrameDuration,
                gameTime: systemsGameTime
            ),
            level: level
        )
        world.osirisProcessTimers(level: level)
        trainingOpeningFeedback.append(
            contentsOf: takeScriptPresentation()
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
    private func advanceIndoorPlayerRotation(
        object: inout GameObject,
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
        world.objects[ObjectHandle(binding.objectHandle)]!.orientation =
            orientation
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
            world: world,
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
            objects: world.objects,
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
                        controllerBitflags:
                            world.playerControllerBitflags
                    )
                    : PlayerControlMask(rawValue: 0),
            showsEnabledPlayerControls:
                finalGoalFrame == nil
                    && (
                        trainingRobotGuidebotState?
                            .enabledControlHUDIsVisible
                            ?? world.hudShowControls
                    ),
            trainingOpeningFeedback: trainingOpeningFeedback,
            playerFastHeadlight:
                finalGoalFrame == nil ? playerFastHeadlight : nil,
            shields: shields,
            energy: energy,
            afterburnerFuel: afterburnerFuel,
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
                    playerConcussionState?.explosions.filter(\.isPresented)
                        .map { explosion in
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
                        end: $0.position - sourceVectorNormalized($0.velocity) * $0.size
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

    func advanceTrainingDodgeAndManeuverLesson(
        object: GameObject,
        view: PlayerView,
        playerHandle: ObjectHandle,
        systemsFrameDuration: Float,
        systemsGameTime: Float,
        followBotTimer11StartedThisFrame: Bool,
        trainingOpeningFeedback: inout [TrainingOpeningFeedback]
    ) {
        if var dodgeState = trainingDodgeAttemptState,
            let dodge = level.trainingDodgeAttempt
        {
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
            let player = world.objects[playerHandle]!
            let turret = world.objects[ObjectHandle(dodge.dodgeTurretObjectHandle)]!

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
                        roomStates: world.rooms,
                        startRoom: turretRoom,
                        start: turret.position,
                        end: player.position,
                        radius: 0
                    )
                    dodgeState.seesTarget = false
                    if case .noHit = visibility.outcome {
                        let targetDirection = sourceVectorNormalized(
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
                    let aimDirection = sourceVectorNormalized(
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
                            roomStates: world.rooms,
                            startRoom: turretRoom,
                            start: turret.position,
                            end: fire.position,
                            radius: 0
                        )
                        // A full list drops the new projectile, as a
                        // failed ObjCreate does (object.cpp:1605).
                        if case .noHit = muzzleTrace.outcome,
                           dodgeState.projectiles.count
                            < trainingDodgeProjectilePresentationCapacity {
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
                    roomStates: world.rooms,
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

            if let exit = dodge.dodgeExit,
                (dodgeState.script019Count ?? 0) < 1,
                case .room(35) = player.location,
                let doneDodgeingGoal =
                    world.objects[ObjectHandle(exit.objectHandle)],
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
                    in: &world,
                    level: level,
                    roomSourceIndex: exit.portalRoomSourceIndex,
                    portalIndices: exit.orderedPortalIndices,
                    rendersFaces: false
                )
                if world.levelModule != .none {
                    world.playerControllerBitflags = .init(
                        rawValue:
                            world.playerControllerBitflags.rawValue
                            & ~exit.disabledControlMask
                    )
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
               let maneuver =
                   world.objects[ObjectHandle(lesson.maneuverObjectHandle)],
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
                if world.levelModule != .none {
                    world.playerControllerBitflags = .init(
                        rawValue: lesson.headingControlMask
                    )
                }
                setTrainingDodgePortalRenderState(
                    in: &world,
                    level: level,
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
                        in: &world,
                        level: level,
                        roomSourceIndex:
                            dodge.portalRoomThreeSourceIndex,
                        portalIndices: dodge.orderedPortalIndices,
                        rendersFaces: false
                    )
                    dodgeState.turretIsPowered = false
                    if world.levelModule != .none {
                        world.playerControllerBitflags.formUnion(
                            .init(
                                rawValue: dodge.successControlMask
                            ))
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
                                sourceVectorNormalized(followBotDirection)
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
                            if world.levelModule != .none {
                                world.playerControllerBitflags =
                                    .init(
                                        rawValue:
                                            lesson
                                            .rotationalControlMask
                                    )
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
                            if world.levelModule != .none {
                                world.playerControllerBitflags =
                                    .init(
                                        rawValue:
                                            lesson.bankControlMask
                                    )
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
                            if world.levelModule != .none {
                                world.playerControllerBitflags =
                                    .init(
                                        rawValue:
                                            lesson.pitchControlMask
                                    )
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
                        // Script 027 unghosts DestroyBot1, which Script 000
                        // ghosted (TrainingMission.cpp:1563).
                        world.aObjGhostSet(
                            0,
                            ObjectHandle(handoff.destroyBot1ObjectHandle)
                        )
                        world.setObjectRendered(
                                handoff.destroyBot1ObjectHandle,
                                true
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
                                objects: world.objects,
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
                            if world.levelModule != .none {
                                world.playerControllerBitflags.formUnion(
                                    .init(
                                        rawValue:
                                            lesson.weaponControlMask
                                    ))
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
                syncTrainingFollowBotObject()
            }
            trainingDodgeAttemptState = dodgeState
        }
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
private func trainingCameraMonitorPickupWasHit(
    in level: Level,
    objects: ObjectTable,
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
          let pickup = objects[ObjectHandle(chain.pickupObjectHandle)],
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
    objects: ObjectTable,
    state: TrainingInvulnerabilityPickupState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
        !state.wasConsumed,
        let chain = level.trainingInvulnerabilityPickupChain,
        let pickup = objects[ObjectHandle(chain.pickupObjectHandle)],
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
    objects: ObjectTable,
    state: TrainingCloakPickupState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
        !state.wasConsumed,
        let chain = level.trainingCloakPickupChain,
        let pickup = objects[ObjectHandle(chain.pickupObjectHandle)],
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
    objects: ObjectTable,
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
          let goal = objects[ObjectHandle(chain.goalObjectHandle)],
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
    turret: GameObject,
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
        forward: sourceVectorNormalized(
            transform(
                transform(dodge.turret.gunpointForward, by: orientation),
                by: turret.orientation
            ))
    )
}

private func trainingDodgeAimDot(
    level: Level,
    dodge: TrainingDodgeAttempt,
    turret: GameObject,
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
        sourceVectorNormalized(target - aim.position)
    )
}
func closeTrainingGalleryBarrier(in world: inout GameWorld, level: Level) {
    guard let barrier = level.trainingGalleryBarrier else { return }
    for portalIndex in barrier.orderedPortalIndices {
        world.setPortalRenderFaces(
            true,
            roomSourceIndex: barrier.barrierRoomSourceIndex,
            portalIndex: portalIndex,
            level: level
        )
    }
}

func setTrainingDodgePortalRenderState(
    in world: inout GameWorld,
    level: Level,
    roomSourceIndex: Int,
    portalIndices: [Int],
    rendersFaces: Bool
) {
    for portalIndex in portalIndices {
        world.setPortalRenderFaces(
            rendersFaces,
            roomSourceIndex: roomSourceIndex,
            portalIndex: portalIndex,
            level: level
        )
    }
}

func openTrainingGalleryBarrier(in world: inout GameWorld, level: Level) {
    guard let barrier = level.trainingGalleryBarrier else { return }
    setTrainingDodgePortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: barrier.barrierRoomSourceIndex,
        portalIndices: barrier.orderedPortalIndices,
        rendersFaces: false
    )
}

func openTrainingGuidebotReturnBarrier(
    in world: inout GameWorld,
    level: Level
) {
    guard let barrier = level.trainingCameraMonitorChain?.returnToShip else {
        return
    }
    setTrainingDodgePortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: barrier.barrierRoomSourceIndex,
        portalIndices: barrier.orderedPortalIndices,
        rendersFaces: false
    )
}

func openTrainingLastRoomBarrier(in world: inout GameWorld, level: Level) {
    guard let chain = level.trainingLastRoomChain else { return }
    setTrainingDodgePortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: chain.barrierRoomSourceIndex,
        portalIndices: chain.orderedPortalIndices,
        rendersFaces: false
    )
}

func openTrainingFinalBotsBarrier(in world: inout GameWorld, level: Level) {
    guard let chain = level.trainingFinalBotsCompletionChain else { return }
    setTrainingDodgePortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: chain.barrierRoomSourceIndex,
        portalIndices: chain.orderedPortalIndices,
        rendersFaces: false
    )
}

func closeTrainingLastRoomBarrier(in world: inout GameWorld, level: Level) {
    guard let chain = level.trainingLastRoomChain else { return }
    setTrainingDodgePortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: chain.barrierRoomSourceIndex,
        portalIndices: chain.orderedPortalIndices,
        rendersFaces: true
    )
}

func closeTrainingKillbotEntryBarrier(
    in world: inout GameWorld,
    level: Level
) {
    guard let barrier = level.trainingCameraMonitorChain?.returnToShip,
          let entry = barrier.killbotEntry
    else {
        return
    }
    setTrainingDodgePortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: barrier.barrierRoomSourceIndex,
        portalIndices: entry.orderedPortalIndices,
        rendersFaces: true
    )
}

extension GameWorld {
    /// The bespoke dodge lesson's start, until M1 step 6 translates Script
    /// 016 (TrainingMission.cpp:1870-1880). The Training module calls it
    /// from StartDodge's EVT_TIMER 8, the timer Script 033 sets, so it runs
    /// at Osiris_ProcessTimers (GameLoop.cpp:3014).
    mutating func startTrainingDodgeAttempt(level: Level) {
        guard var state = trainingDodgeAttemptState,
              let dodge = level.trainingDodgeAttempt,
              state.script016Count < 1
        else {
            return
        }
        shields = dodge.restoredPlayerShields
        addHUDMessage(dodge.instruction)
        state.successTimerRemaining = dodge.successDelay
        state.almostDoneTimerRemaining = dodge.almostDoneDelay
        state.turretIsPowered = true
        state.nextFireTime = gameTime
        state.script016Count += 1
        trainingDodgeAttemptState = state
    }
}
