// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension GameSession {
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
            world.gameStateRequest != nil || world.playerDeath != nil
        let currentEnabledControls = controlsAreSuspended
            ? PlayerControlMask(rawValue: 0)
            : world.playerControllerBitflags
        let input = controlsAreSuspended
            ? InputSnapshot.zero
            : input.applying(currentEnabledControls)
        var playerHeadlightFeedback: PresentationFeedback?
        if input.togglesHeadlight {
            playerHeadlightIsOn.toggle()
            playerHeadlightFeedback = PresentationFeedback(
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
        // The use-inventory key of ProcessKeys and the controls
        // (Controls.cpp:1215): UseInventoryItem (Inventory.cpp:1485).
        if input.usesInventory {
            world.useInventoryItem(level: level)
        }
        // ProcessNormalKey (GameLoop.cpp:1493): F4 asks for the buddy menu
        // (Game_interface_mode = GAME_BUDDY_INTERFACE), which RunGameMenu
        // opens after this frame (BuddyMenu.swift). A dying or dead player's
        // keys stop before it (:1433-1440); its input is zero here.
        if input.opensBuddyMenu {
            buddyMenuIsRequested = true
        }
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
        // Then the flare (object.cpp:2438-2440).
        if input.firesPlayerFlare {
            world.fireFlareFromPlayer(playerHandle, level: level)
        }
        object = world.objects[playerHandle]!
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
        // Fvi_recorded_faces: do_physics_sim clears the list (physics.cpp:685),
        // and each move of the sim records the trigger faces it passes
        // (FQ_RECORD, :796, :986) for ObjCheckTriggers.
        var recordedFaces: [IndoorPortalCrossing] = []
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
            let trace = traceIndoorMovement(
                in: level,
                roomStates: world.rooms,
                startRoom: roomSourceIndex,
                start: position,
                end: position + linearThrustOrientation.up * wiggle,
                radius: view.collisionRadius
            )
            // Only a wiggle that hits nothing moves the ship and keeps its
            // recorded faces (physics.cpp:809); otherwise the main move
            // starts a new record list (FQ_NEW_RECORD_LIST, :986).
            if case .noHit = trace.outcome {
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
                recordedFaces += trace.passedPortalFaces
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
            recordedFaces += trace.passedPortalFaces
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
                    link: objectHit.link,
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
            // collide_player_and_wall checks a trigger on the wall it hit
            // (collide.cpp:1295).
            world.objects[playerHandle]!.position = trace.finalPosition
            world.objects[playerHandle]!.location =
                .room(trace.containingRoomSourceIndex)
            world.checkTrigger(
                room: contact.roomSourceIndex,
                face: contact.faceIndex,
                object: playerHandle,
                eventType: .collide,
                level: level
            )
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
        // ObjCheckTriggers follows do_physics_sim (object.cpp:2807).
        world.objCheckTriggers(
            playerHandle,
            recordedFaces: recordedFaces,
            level: level
        )
        // ObjDoEffects (object.cpp:2841).
        world.objDoEffects(playerHandle)
        // The player's EVT_INTERVAL ends its ObjDoFrame (object.cpp:2868).
        world.objectIntervalEvent(playerHandle, level: level)
        // The rest of ObjDoFrameAll's loop, then ObjDeleteDead
        // (object.cpp:2969-3004).
        world.objDoFrameSlots(
            (playerHandle.slot + 1)..<ObjectTable.capacity,
            level: level
        )
        world.objDoFrameAllTail(level: level)
        // DoMatcensFrame arrives with the matcens (M2); then
        // Level_goals.DoFrame (GameLoop.cpp:2982).
        world.levelGoalsDoFrame(level: level)
        let playerFastHeadlight = playerHeadlightIsOn
            ? fastPlayerHeadlight(from: world.objects[playerHandle]!)
            : nil

        var presentationFeedback: [PresentationFeedback] = []
        if let playerHeadlightFeedback {
            presentationFeedback.append(playerHeadlightFeedback)
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
        presentationFeedback.append(
            contentsOf: takeScriptPresentation()
        )

        var frame = finalizePlayerSimulationFrame(
            at: timestamp,
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            ship: ship,
            wallContact: wallContact,
            presentationFeedback: presentationFeedback,
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
        // DrawSmallViews (SmallViews.cpp:398) after the main view: each
        // window that shows a view runs GameRenderWorld (:332), whose
        // objects join AI_RenderedList (renderobject.cpp:1239) again, as
        // each view marks its rooms' objects OF_SAFE_TO_RENDER
        // (render.cpp:1126), and whose rooms take the render time; then the
        // windows' timers count.
        var aiRenderedList = rendered.aiObjects
        var renderedRooms = rendered.rooms
        for view in world.smallViewFrames(level: level) {
            let smallView = renderedRoomsAndAIObjects(
                level,
                objects: world.objects,
                roomStates: world.rooms,
                camera: view.camera,
                startRoomSourceIndex: view.roomSourceIndex,
                excludedObjectHandle: view.viewerObjectHandle
            )
            aiRenderedList += smallView.aiObjects
            renderedRooms += smallView.rooms
        }
        world.aiRenderedList = aiRenderedList
        world.lastRenderCamera = frame.playerView.camera
        world.smallViewsRenderFrame(frameTime: systemsFrameDuration)
        let advancedGameTime = world.gameTime
        world.gameTime = systemsGameTime
        for roomSourceIndex in renderedRooms {
            if let room = level.rooms.firstIndex(where: {
                $0.sourceIndex == roomSourceIndex
            }) {
                world.rooms[room].lastRenderTime = systemsGameTime
            }
        }
        world.processNormalEvents(level: level)
        world.gameTime = advancedGameTime
        // GameSequencer (gamesequence.cpp:1240-1262): a level that a script
        // ended this frame ends now.
        frame.levelEnd = sequenceLevelEnd(elapsedTime: systemsGameTime)
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
        presentationFeedback: [PresentationFeedback],
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

        let smallViewFrames = world.smallViewFrames(level: level)
        // A level a script ended this frame shows no more gameplay.
        let levelIsEnding = world.gameStateRequest != nil
        let playerObject = world.objects[ObjectHandle(
            level.defaultPlayerBinding!.objectHandle
        )]

        let objectLights = world.objectLights
        world.objectLights = []

        frameDuration = Float(timestamp - lastTimestamp)
        lastTimestamp = timestamp
        gameTime += frameDuration
        let presentsRearView =
            !levelIsEnding && playerRearViewState != nil
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
                levelIsEnding
                    ? PlayerControlMask(rawValue: 0)
                    : world.playerControllerBitflags,
            showsEnabledPlayerControls:
                !levelIsEnding && world.hudShowControls,
            presentationFeedback: presentationFeedback,
            playerFastHeadlight:
                levelIsEnding ? nil : playerFastHeadlight,
            shields: shields,
            energy: energy,
            afterburnerFuel: afterburnerFuel,
            visEffectBillboards: visEffectBillboardFrames(
                level,
                effects: world.visEffects,
                gameTime: systemsGameTime
            ),
            visEffectLineSparks: visEffectLineSparkFrames(world.visEffects),
            weaponBillboards: weaponBillboardFrames(
                level,
                objects: world.objects,
                gameTime: systemsGameTime
            ),
            objectLights: objectLights,
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
            popupView: smallViewFrames.first { $0.isPopup },
            playerInvulnerabilityRemaining: world.playerInvulnerableTime,
            playerCloak: ObjectCloakFrame(playerObject?.effect),
            levelEnd: nil
        )
    }

}
