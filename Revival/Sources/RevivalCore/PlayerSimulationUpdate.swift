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
        // A dying or dead player has CT_NONE (StartPlayerDeath,
        // Player.cpp:2191), so its controls do nothing.
        let controlsAreSuspended =
            trainingFinalGoalState?.endLevelWasRequested == true
                || world.playerDeath != nil
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
        // ProcessKeys (GameLoop.cpp:1493): a buddy menu command goes to the
        // Guide-Bot (BuddyProcessCommand, buddymenu.cpp:452). Until the buddy
        // menu (M1 step 8c), the two Guide-Bot inputs pick the command.
        sendTrainingGuidebotMenuCommand(input)
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        guard case let .room(startRoom) = object.location else {
            preconditionFailure("The Slice 10 player simulation is indoor.")
        }
        // GameFrame (GameLoop.cpp:2964-2973): AIFrameAll, then
        // ObjDoFrameAll's slot loop up to the player's slot. The player's
        // own ObjDoFrame is the move below; the loop's later slots follow
        // it.
        world.aiFrameAll(level: level)
        world.objDoFrameSlots(0..<playerHandle.slot, level: level)
        // The player's ObjDoFrame fires its weapons before it moves
        // (object.cpp:2431-2436).
        world.fireWeaponFromPlayer(
            playerHandle,
            weaponType: PlayerWeaponState.primary,
            isDown: input.firesPrimaryWeapon,
            downTime: input.firesPrimaryWeapon ? systemsFrameDuration : 0,
            level: level
        )
        world.fireWeaponFromPlayer(
            playerHandle,
            weaponType: PlayerWeaponState.secondary,
            isDown: input.firesSecondaryWeapon,
            downTime: input.firesSecondaryWeapon ? systemsFrameDuration : 0,
            level: level
        )
        object = world.objects[playerHandle]!
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
                    world: world,
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
                    world: world,
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
        // The player's EVT_INTERVAL ends its ObjDoFrame (object.cpp:2868).
        world.objectIntervalEvent(playerHandle, level: level)
        // The rest of ObjDoFrameAll's loop, then ObjDeleteDead
        // (object.cpp:2969-3004).
        world.objDoFrameSlots(
            (playerHandle.slot + 1)..<ObjectTable.capacity,
            level: level
        )
        world.objDoFrameAllTail(level: level)
        let playerFastHeadlight = playerHeadlightIsOn
            ? fastPlayerHeadlight(from: world.objects[playerHandle]!)
            : nil
        advancePlayerAndGuidebotYellowFlares(
            duration: systemsFrameDuration,
            gameTime: systemsGameTime
        )
        createTrainingGuidebotFlareShots(gameTime: systemsGameTime)

        var trainingOpeningFeedback: [TrainingOpeningFeedback] = []
        if let playerHeadlightFeedback {
            trainingOpeningFeedback.append(playerHeadlightFeedback)
        }
        if let playerFlareFeedback {
            trainingOpeningFeedback.append(playerFlareFeedback)
        }
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
        // Script 058 (TrainingMission.cpp:1443, the level EVT_INTERVAL): the
        // Guide-Bot is not a robot (in the ship, or none) after the Camera
        // Monitor was used. EVT_USE (Script 059) comes first in the frame,
        // from the keys.
        // It moves to TrainingMission.swift in M1 step 8c.
        if let chain = level.trainingCameraMonitorChain?.returnToShip,
           var cameraState = trainingCameraMonitorState,
           cameraState.wasUsed,
           !cameraState.script058WasPresented,
           world.objectType(world.buddyHandle) != .robot {
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
            // Script 032's aObjSetLightingDist(Object_handles[1], 0)
            // (TrainingMission.cpp:2331).
            world.setObjectLightDistance(
                ObjectHandle(barrier.markerLightObjectHandle),
                0
            )
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
           let lastRoom = level.trainingLastRoomChain,
           trainingBarrierIsOpen(
               world,
               level: level,
               roomSourceIndex: lastRoom.barrierRoomSourceIndex,
               portalIndices: lastRoom.orderedPortalIndices
           ),
           trainingFinalRoomEntryWasCrossedThisFrame,
           let chain = level.trainingFinalRoomEntryChain
        {
            // The bespoke Script 050 (TrainingMission.cpp:2371-2383): the
            // trigger lies past the portals Script 034 opened.
            world.setObjectLightDistance(
                ObjectHandle(lastRoom.markerLightObjectHandle),
                0
            )
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
        if var state = trainingRobotGuidebotState,
            let chain = level.trainingRobotGuidebotChain
        {
            // Script 060 (TrainingMission.cpp:1431): the Guide-Bot is out
            // (qObjIsType(qGetBuddyObj(0), OBJ_ROBOT)) after Script 032. It
            // moves to TrainingMission.swift in M1 step 8c.
            if !state.guidebotContinuationWasPresented,
               world.objectType(world.buddyHandle) == .robot,
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
        // The sound frame stops the linked sounds of gone or ghosted objects
        // (hlsoundlib.cpp:722).
        world.stopSoundsOfGoneObjects()
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

        let frame = finalizePlayerSimulationFrame(
            at: timestamp,
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            ship: ship,
            wallContact: wallContact,
            trainingOpeningFeedback: trainingOpeningFeedback,
            playerFastHeadlight: playerFastHeadlight
        )
        // GameRenderFrame (GameLoop.cpp:3051) marks the rooms it draws and
        // fills AI_RenderedList from that view (renderobject.cpp:1239); then
        // ProcessNormalEvents runs (:3059). Both happen before Gametime
        // advances (:3090).
        let rendered = renderedRoomsAndAIObjects(
            level,
            objects: world.objects,
            roomStates: world.rooms,
            camera: frame.playerView.camera,
            startRoomSourceIndex: frame.playerView.roomSourceIndex,
            excludedObjectHandle: frame.playerView.objectHandle
        )
        world.aiRenderedList = rendered.aiObjects
        let advancedGameTime = world.gameTime
        world.gameTime = systemsGameTime
        for roomSourceIndex in rendered.rooms {
            if let room = level.rooms.firstIndex(where: {
                $0.sourceIndex == roomSourceIndex
            }) {
                world.rooms[room].lastRenderTime = systemsGameTime
            }
        }
        world.processNormalEvents(level: level)
        world.gameTime = advancedGameTime
        return frame
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
                    && world.hudShowControls,
            trainingOpeningFeedback: trainingOpeningFeedback,
            playerFastHeadlight:
                finalGoalFrame == nil ? playerFastHeadlight : nil,
            shields: shields,
            energy: energy,
            afterburnerFuel: afterburnerFuel,
            visEffectExplosions: visEffectExplosionFrames(
                level,
                effects: world.visEffects
            ),
            visEffectLineSparks: visEffectLineSparkFrames(world.visEffects),
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
            trainingGuidebotReturnMarkerLightDistance:
                trainingKillbotEntryState?.wasTriggered == true
                    ? level.trainingCameraMonitorChain?.returnToShip?
                        .killbotEntry?.closedMarkerLightDistance
                    : trainingCameraMonitorState?
                        .returnMarkerLightDistance,
            objectSoundLoops: world.soundSystem.objectLoops.compactMap { loop in
                guard let object = world.objects[loop.object],
                      case let .room(room) = object.location
                else {
                    return nil
                }
                return ObjectSoundLoopFrame(
                    handle: loop.handle,
                    soundName: level.soundClips[loop.soundIndex].logicalName,
                    roomSourceIndex: room,
                    position: object.position
                )
            },
            trainingCameraMonitor: cameraMonitorFrame,
            trainingInvulnerabilityRemaining:
                trainingInvulnerabilityPickupState?.remainingDuration,
            trainingCloak: trainingCloakFrame(
                state: trainingCloakPickupState,
                chain: level.trainingCloakPickupChain
            ),
            trainingFinalGoal: finalGoalFrame
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
    world: GameWorld,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
          !state.endLevelWasRequested,
          // FinalGoal lies past the portals Script 035 opened.
          let finalBots = level.trainingFinalBotsCompletionChain,
          trainingBarrierIsOpen(
              world,
              level: level,
              roomSourceIndex: finalBots.barrierRoomSourceIndex,
              portalIndices: finalBots.orderedPortalIndices
          ),
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

/// Whether every listed portal of the room has PF_RENDER_FACES clear.
func trainingBarrierIsOpen(
    _ world: GameWorld,
    level: Level,
    roomSourceIndex: Int,
    portalIndices: [Int]
) -> Bool {
    guard let room = level.rooms.firstIndex(where: {
        $0.sourceIndex == roomSourceIndex
    }) else {
        return false
    }
    return portalIndices.allSatisfy {
        world.rooms[room].portalFlags[$0] & LevelPortal.renderFacesFlag == 0
    }
}

func setTrainingPortalRenderState(
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
    setTrainingPortalRenderState(
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
    setTrainingPortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: barrier.barrierRoomSourceIndex,
        portalIndices: barrier.orderedPortalIndices,
        rendersFaces: false
    )
}

func openTrainingLastRoomBarrier(in world: inout GameWorld, level: Level) {
    guard let chain = level.trainingLastRoomChain else { return }
    setTrainingPortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: chain.barrierRoomSourceIndex,
        portalIndices: chain.orderedPortalIndices,
        rendersFaces: false
    )
}

func openTrainingFinalBotsBarrier(in world: inout GameWorld, level: Level) {
    guard let chain = level.trainingFinalBotsCompletionChain else { return }
    setTrainingPortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: chain.barrierRoomSourceIndex,
        portalIndices: chain.orderedPortalIndices,
        rendersFaces: false
    )
}

func closeTrainingLastRoomBarrier(in world: inout GameWorld, level: Level) {
    guard let chain = level.trainingLastRoomChain else { return }
    setTrainingPortalRenderState(
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
    setTrainingPortalRenderState(
        in: &world,
        level: level,
        roomSourceIndex: barrier.barrierRoomSourceIndex,
        portalIndices: entry.orderedPortalIndices,
        rendersFaces: true
    )
}
