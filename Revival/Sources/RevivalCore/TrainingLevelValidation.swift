import Foundation

func validateStockTrainingRobotGuidebotPackage(
    chain: TrainingRobotGuidebotChain?,
    guidebotB: CanonicalVoiceClip?,
    proceed5: CanonicalVoiceClip?,
    releaseSound: CanonicalSoundClip? = nil,
    ambientEngineSound: CanonicalSoundClip? = nil,
    flareSound: CanonicalSoundClip? = nil
) throws {
    guard let chain,
          chain.guidebotObjectHandle == 6_164,
          chain.deployedGuidebotObjectType == 2,
          chain.deployedGuidebotMessage
            == "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
          chain.deployedGuidebotVoiceSourceName == "guidebotb.osf",
          (
              chain.releaseSoundSourceName == nil
                  || chain.releaseSoundSourceName == "GBExpulsionA.wav"
                    && releaseSound?.logicalName == "GBExpulsionA"
                    && releaseSound?.sourceName == "GBExpulsionA.wav"
                    && releaseSound?.sourceEntryIndex == 1_246
                    && releaseSound?.sampleRate == 22_050
                    && releaseSound?.channelCount == 1
                    && releaseSound?.frameCount == 22_475
                    && releaseSound?.pcm16LittleEndian.count == 44_950
                    && releaseSound?.pcmSHA256
                        == "24a95adeb0b468f3c677007e00f9d8fd73919d60128646bedaa29db5f3f56f6e"
                    && releaseSound?.sourceArchive == "d3.hog"
                    && releaseSound?.sourceSHA256
                        == "ae030e17bd5fc5724b7b3aac6604299005d35adffc0b5d9620430d191e1ef288"
                    && releaseSound?.importVolume == 0.5
          ),
          (
              chain.ambientEngineSoundSourceName == nil
                  || chain.ambientEngineSoundSourceName == "GBotEngineB.wav"
                    && ambientEngineSound?.logicalName == "GBotEngineB1"
                    && ambientEngineSound?.sourceName == "GBotEngineB.wav"
                    && ambientEngineSound?.sourceEntryIndex == 1_262
                    && ambientEngineSound?.sampleRate == 22_050
                    && ambientEngineSound?.channelCount == 1
                    && ambientEngineSound?.frameCount == 8_080
                    && ambientEngineSound?.pcm16LittleEndian.count == 16_160
                    && ambientEngineSound?.pcmSHA256
                        == "2a9c63eb02ea72e256cbaff7e87c575cce415ad11ef1d753123fe8a97b7da528"
                    && ambientEngineSound?.sourceArchive == "d3.hog"
                    && ambientEngineSound?.sourceSHA256
                        == "35eaf843ad66e61a1f5c46f68ced68d5fbec8580dc8e1c8d115e374349f5a96f"
                    && ambientEngineSound?.importVolume == 0.1
          ),
          (
              chain.yellowFlare == nil
                  || chain.yellowFlare.map { flare in
                      flare.source == .init(
                          storedIndex: 3,
                          sourceName: "Yellow flare"
                      )
                          && flare.model.sourceName
                            == "FlareYellowBright.OOF"
                          && flare.particleTexture == .init(
                              storedIndex: 878,
                              sourceName: "yellowspark"
                          )
                          && flare.fireSoundSourceName == "Flare.wav"
                          && flare.weaponFlags == 0x8001_0000
                          && flare.physicsFlags == 0x2000_0810
                          && flare.modelPageSize.bitPattern
                            == 0x405f_d5ea
                          && flare.collisionRadius == 0.1
                          && flare.speed == 100
                          && flare.lifetime == 15
                          && flare.mass == 0.1
                          && flare.drag == 0.0001
                          && flare.coefficientOfRestitution == 1
                          && flare.lightDistance == 35
                          && flare.lightPresentation == .init(
                              primaryColor: .init(x: 1, y: 1, z: 0.8),
                              secondaryColor: .zero,
                              timeInterval: 0.2,
                              flickerDistance: 5,
                              directionalDot: 0,
                              flags: 16,
                              timebits: UInt32.max,
                              angle: 0,
                              lightingRenderType: 0
                          )
                          && flare.particleCount == 25
                          && flare.particleInterval == 0.04
                          && flare.particleSize.bitPattern
                            == Float(0.2).bitPattern
                          && flare.particleLifetime.bitPattern
                            == Float(0.3).bitPattern
                          && (
                              flare.timeout == nil
                                  || flare.timeout.map { timeout in
                                      timeout.explosionTexture == .init(
                                          storedIndex: 900,
                                          sourceName: "FlarePuff"
                                      )
                                          && timeout.explosionLifetime == 0.2
                                          && timeout.explosionSize == 2
                                          && timeout.childSource == .init(
                                              storedIndex: 54,
                                              sourceName: "YellowFlareSparks"
                                          )
                                          && timeout.childTexture == .init(
                                              storedIndex: 878,
                                              sourceName: "yellowspark"
                                          )
                                          && timeout.childCount == 9
                                          && timeout.childWeaponFlags == 1_056
                                          && timeout.childPhysicsFlags
                                            == 2_556_032
                                          && timeout.childCollisionRadius == 0.2
                                          && timeout.childSpeed == 17
                                          && timeout.childLifetime == 0.2
                                          && timeout.childMass == 0.1
                                          && timeout.childDrag == 0.1
                                          && timeout.childCoefficientOfRestitution == 1
                                          && timeout.childLightDistance == 6
                                          && timeout.childLightPresentation == .init(
                                              primaryColor: .init(x: 1, y: 1, z: 0.5),
                                              secondaryColor: .zero,
                                              timeInterval: 0,
                                              flickerDistance: 0,
                                              directionalDot: 0,
                                              flags: 0,
                                              timebits: 0,
                                              angle: 0,
                                              lightingRenderType: 0
                                          )
                                          && timeout.childParticleCount == 25
                                          && timeout.childParticleInterval == 0.04
                                          && timeout.childParticleSize == 0.3
                                          && timeout.childParticleLifetime == 0.3
                                          && timeout
                                            .hasCoherentChildAnimationBinding
                                  } == true
                          )
                  } == true
                  && flareSound?.logicalName == "Flare"
                  && flareSound?.sourceName == "Flare.wav"
                  && flareSound?.sourceEntryIndex == 1_158
                  && flareSound?.sampleRate == 22_050
                  && flareSound?.channelCount == 1
                  && flareSound?.frameCount == 25_086
                  && flareSound?.pcm16LittleEndian.count == 50_172
                  && flareSound?.pcmSHA256
                    == "98aa8dc4652268a3f512c995dcc8cc3f6ef3abe62947f839167bd809f9423452"
                  && flareSound?.sourceArchive == "d3.hog"
                  && flareSound?.sourceSHA256
                    == "79cb319f84c4cfdcdb6ca2ab853767df3f1e128f516ff007dc9febf8f5a988b7"
                  && flareSound?.importVolume.bitPattern
                    == Float(0.300_000_07).bitPattern
          ),
          chain.guidebot == .stockTraining,
          guidebotB?.sourceName.caseInsensitiveCompare("guidebotb.osf")
            == .orderedSame,
          guidebotB?.sourceEntryIndex == 5,
          guidebotB?.sampleRate == 22_050,
          guidebotB?.channelCount == 1,
          guidebotB?.frameCount == 299_701,
          guidebotB?.pcmSHA256
            == "11ac67df4f4fe234104ca32b97299539e590a6e6d7a826e85d3c1a10ccc52fe4",
          guidebotB?.sourceArchive == "missions/training.mn3",
          guidebotB?.sourceSHA256
            == "0238e793083d875d233d18eaf018aa4526d34cf0c6bed0e659e4725ff8c7ffda",
          proceed5?.sourceName.caseInsensitiveCompare("proceed5.osf")
            == .orderedSame,
          proceed5?.sourceEntryIndex == 25,
          proceed5?.sampleRate == 22_050,
          proceed5?.channelCount == 1,
          proceed5?.frameCount == 136_341,
          proceed5?.pcmSHA256
            == "3ec85db25577616344f6289a319ad01b8fa6406e49f4452ef39f268ddf830490",
          proceed5?.sourceArchive == "missions/training.mn3",
          proceed5?.sourceSHA256
            == "4bbb54d28b38ae48d665e16493c67a82c59ec213c23527a100aa67db671c477c"
    else {
        throw LevelValidationError.invalidDependency(
            "Training robot and Guidebot package"
        )
    }
}

func validateStockTrainingFinalRoomEntryPackage(
    chain: TrainingFinalRoomEntryChain?,
    intro7: CanonicalVoiceClip?
) throws {
    guard let chain,
        chain.triggerName == "Portal4",
        chain.triggerRoomSourceIndex == 44,
        chain.triggerFaceIndex == 1,
        chain.successMessage == "Excellent!",
        chain.instructionMessage
            == "Now for your final and most difficult task. Locate and destroy the last 5 robots.",
        chain.voiceSourceName == "intro7.osf",
        intro7?.sourceName.caseInsensitiveCompare("intro7.osf")
            == .orderedSame,
        intro7?.sourceEntryIndex == 16,
        intro7?.sampleRate == 22_050,
        intro7?.channelCount == 1,
        intro7?.frameCount == 469_201,
        intro7?.pcmSHA256
            == "381ce960f6a266b1014cdcfdfc2cc3607a053d3c4b062215e5512127e7bd2711",
        intro7?.sourceArchive == "missions/training.mn3",
        intro7?.sourceSHA256
            == "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 050 package"
        )
    }
}

func validateStockTrainingFinalBotsCompletionPackage(
    chain: TrainingFinalBotsCompletionChain?,
    done: CanonicalVoiceClip?,
    level: Level,
    requiresExactVoice: Bool = true
) throws {
    let expectedPresentation = ObjectLightPresentation(
        primaryColor: .init(x: 1, y: 0.25, z: 0),
        secondaryColor: .zero,
        timeInterval: 0.5,
        flickerDistance: 0.2,
        directionalDot: 0,
        flags: 4,
        timebits: .max,
        angle: 0,
        lightingRenderType: 2
    )
    guard let chain,
          chain.barrierRoomSourceIndex == 16,
          chain.orderedPortalIndices == [0, 1],
          chain.markerLightObjectHandle == 4_118,
          chain.markerLightPresentation == expectedPresentation,
          chain.openMarkerLightDistance == 50,
          chain.timerDuration == 2,
          chain.completionMessage
            == "Great Job! Now fly through the opened doorway to end your training. Good job Recruit!",
          chain.completionVoiceSourceName == "done.osf",
          let room = level.rooms.first(where: {
              $0.sourceIndex == chain.barrierRoomSourceIndex
          }),
          room.name == "PortalRoom7",
          chain.orderedPortalIndices.allSatisfy(
              room.portals.indices.contains
          ),
          let marker = level.objects.first(where: {
              $0.handle == chain.markerLightObjectHandle
          }),
          marker.type == 11,
          marker.storedID == 205,
          marker.definition?.sourceName == "Blinking Red Light-DM",
          marker.instanceName == "FlashLight-5",
          marker.flags == 4_096,
          marker.location == .room(16),
          done?.sourceName.caseInsensitiveCompare("done.osf")
            == .orderedSame,
          done?.sampleRate == 22_050,
          done?.channelCount == 1,
          done?.sourceArchive == "missions/training.mn3",
          !requiresExactVoice || (
              done?.sourceEntryIndex == 2
                  && done?.frameCount == 234_609
                  && done?.pcmSHA256
                    == "87efaee428868cf09d74ae72ded48f91ce6f9db55ee823c82fcbf37c07487953"
                  && done?.sourceSHA256
                    == "a14ce32c2b72fb222c9dfdfdbc277b062ebbb6774e5757c4fe1602b87630383c"
          ),
          chain.orderedPortalIndices.allSatisfy({ portalIndex in
              let portal = room.portals[portalIndex]
              guard portal.flags & 1 != 0,
                    let connected = level.rooms.first(where: {
                        $0.sourceIndex == portal.connectedRoom
                    }),
                    connected.portals.indices.contains(
                        portal.connectedPortal
                    )
              else {
                  return false
              }
              let reciprocal =
                  connected.portals[portal.connectedPortal]
              return reciprocal.connectedRoom == room.sourceIndex
                  && reciprocal.connectedPortal == portalIndex
                  && reciprocal.flags & 1 != 0
          })
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 035/056 completion"
        )
    }
}

func validateStockTrainingFinalGoalPackage(
    chain: TrainingFinalGoalChain?,
    level: Level
) throws {
    guard let chain,
          chain.goalObjectHandle == 6_180,
          chain.goalRoomSourceIndex == 17,
          chain.goalObjectFlags == 4_096,
          chain.goalCollisionRadius.bitPattern == 0x40a0_84bf,
          level.trainingFinalBotsCompletionChain != nil,
          let goal = level.objects.first(where: {
              $0.handle == chain.goalObjectHandle
          }),
          goal.type == 7,
          goal.storedID == 67,
          goal.definition?.storedIndex == 67,
          goal.definition?.sourceName == "Invisiblepowerup",
          goal.definition?.referenceRuntimeIndex == nil
            || goal.definition?.referenceRuntimeIndex == 68,
          goal.instanceName == "FinalGoal",
          goal.flags == chain.goalObjectFlags,
          goal.location == .room(chain.goalRoomSourceIndex),
          let presentation = level.objectPresentations.first(where: {
              $0.objectHandle == chain.goalObjectHandle
          }),
          presentation.primaryModel.sourceName
            .caseInsensitiveCompare("invisiblepowerup.OOF")
                == .orderedSame,
          presentation.mediumModel == nil,
          presentation.lowModel == nil,
          presentation.dyingModel == nil,
          presentation.mediumDistance == nil,
          presentation.lowDistance == nil,
          !presentation.isVisible,
          let model = level.models.first(where: {
              $0.source == presentation.primaryModel
          }),
          model.collisionRadius == chain.goalCollisionRadius,
          level.rooms.contains(where: {
              $0.sourceIndex == chain.goalRoomSourceIndex
          })
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 057 FinalGoal chain"
        )
    }
}

func validateStockTrainingRobotGuidebotPresentation(
    chain: TrainingRobotGuidebotChain,
    modelSources: [SourceResource],
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    let buddybotModels = modelSources.filter {
        $0.sourceName.caseInsensitiveCompare("Buddybot.oof") == .orderedSame
    }
    let gyroModels = modelSources.filter {
        $0.sourceName.caseInsensitiveCompare("gyro.oof") == .orderedSame
    }
    guard buddybotModels.count == 1,
          gyroModels.count == 1,
          objects.contains(where: {
              $0.handle == chain.guidebotObjectHandle
                  && $0.type == 2
                  && $0.storedID == 0
                  && $0.definition?.sourceName == "GuideBot"
                  && $0.instanceName == "GuideBotB"
                  && $0.flags == 0x110f
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == chain.guidebotObjectHandle
                  && $0.primaryModel == buddybotModels[0]
                  && !$0.isVisible
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == 4_112
                  && $0.primaryModel == gyroModels[0]
                  && $0.mediumModel == nil
                  && $0.lowModel == nil
                  && $0.dyingModel == nil
                  && $0.mediumDistance == nil
                  && $0.lowDistance == nil
                  && $0.isVisible
          }) else {
        throw LevelValidationError.invalidDependency(
            "Training robot and Guidebot presentation"
        )
    }
}

func validateTrainingGuidebotYellowFlareAnimationBinding(
    timeout: TrainingGuidebotYellowFlareTimeoutDefinition?,
    materials: [PresentationMaterial],
    dependencies: [DependencyRecord]
) throws {
    guard let timeout else { return }
    let dependencyIdentities = Set(dependencies.map {
        DependencyIdentity(category: $0.category, source: $0.source)
    })
    guard timeout.hasCoherentChildAnimationBinding else {
        throw LevelValidationError.invalidDependency(
            "Training Guidebot Yellow flare animation binding"
        )
    }
    guard let frames = timeout.childAnimationFrames else { return }
    guard frames.allSatisfy({ frame in
        materials.first { $0.texture == frame }.map {
            $0.bitmapSourceName == "yellowspark.oaf"
                && $0.sourceArchive == "d3.hog"
                && $0.sourceSHA256
                    == "eabf95db1e5c17235b65a7b938081d40e44736456112acbc4a1ff99126051194"
        } == true
            && dependencyIdentities.contains(.init(
                category: "texture",
                source: frame
            ))
    }) else {
        throw LevelValidationError.invalidDependency(
            "Training Guidebot Yellow flare animation binding"
        )
    }
}

func validateTrainingGuidebotYellowFlareBinding(
    chain: TrainingRobotGuidebotChain,
    models: [CanonicalModel],
    materials: [PresentationMaterial],
    sounds: [CanonicalSoundClip],
    dependencies: [DependencyRecord]
) throws {
    guard let flare = chain.yellowFlare else { return }
    try validateTrainingGuidebotYellowFlareAnimationBinding(
        timeout: flare.timeout,
        materials: materials,
        dependencies: dependencies
    )
    let exactMaterialHashes = [
        "energy":
            "5c6e2eb6cde4b1592f4ff8bc9540ab858655da77607e07328db8cd12cfd7376f",
        "YellowFlareCorona":
            "4944668e9096eb632ae8716061946c2d558a86da4ffb5fdd493d5ea260c95cbe",
        "FlarePuff":
            "9416910ac344a0e3a9dd35ef596300147b7014972c73974a88546351ca92835c",
        "FlarePuffAlt":
            "8ad50ce9c0f198d49d1131ffd4c0a15df80c01c20105bf89094bc715f57a21f7",
        "yellowspark":
            "eabf95db1e5c17235b65a7b938081d40e44736456112acbc4a1ff99126051194",
    ]
    let materialsByName = Dictionary(
        grouping: materials,
        by: { $0.texture.sourceName }
    )
    let model = models.first { $0.source == flare.model }
    let modelTextures = Set(model?.submodels.flatMap { submodel in
        submodel.faces.compactMap { face -> String? in
            guard case let .texture(texture) = face.material else {
                return nil
            }
            return texture.sourceName
        }
    } ?? [])
    let sound = sounds.first {
        $0.sourceName == flare.fireSoundSourceName
    }
    let soundDependency = sound.map {
        DependencyIdentity(
            category: "sound",
            source: .init(
                storedIndex: $0.sourceEntryIndex,
                sourceName: $0.sourceName
            )
        )
    }
    let dependencyIdentities = Set(dependencies.map {
        DependencyIdentity(category: $0.category, source: $0.source)
    })
    guard model?.source.sourceName == "FlareYellowBright.OOF",
          model?.collisionRadius.bitPattern == 0x405f_d5ea,
          model?.submodels.count == 4,
          model?.submodels.map(\.presentation)
            == [.standard, .facing, .facing, .facing],
          model?.sourceArchive == "d3.hog",
          model?.sourceSHA256
            == "fa0f92ba8d3ea0d348766c2cf56897935a0a1afe211378729b5781d773fb9ed4",
          modelTextures
            == Set(["energy", "YellowFlareCorona", "FlarePuff", "FlarePuffAlt"]),
          exactMaterialHashes.allSatisfy({ name, hash in
              materialsByName[name]?.count == 1
                  && materialsByName[name]?.first?.sourceArchive == "d3.hog"
                  && materialsByName[name]?.first?.sourceSHA256 == hash
          }),
          materialsByName["yellowspark"]?.count == 1,
          materialsByName["yellowspark"]?.first?.texture
            == flare.particleTexture,
          sound?.sourceEntryIndex == 1_158,
          sound?.pcmSHA256
            == "98aa8dc4652268a3f512c995dcc8cc3f6ef3abe62947f839167bd809f9423452",
          dependencyIdentities.contains(.init(
              category: "weapon-definition",
              source: flare.source
          )),
          dependencyIdentities.contains(.init(
              category: "model",
              source: flare.model
          )),
          dependencyIdentities.contains(.init(
              category: "texture",
              source: flare.particleTexture
          )),
          soundDependency.map(dependencyIdentities.contains) == true else {
        throw LevelValidationError.invalidDependency(
            "Training Guidebot Yellow flare binding"
        )
    }
}

func validateStockTrainingCameraMonitorPackage(
    chain: TrainingCameraMonitorChain?,
    guidebotC: CanonicalVoiceClip?,
    guidebotD: CanonicalVoiceClip?,
    proceed6: CanonicalVoiceClip? = nil,
    intro6: CanonicalVoiceClip? = nil,
    guidebotF: CanonicalVoiceClip? = nil,
    pickupSound: CanonicalSoundClip?,
    returnSound: CanonicalSoundClip? = nil,
    greetingSound: CanonicalSoundClip? = nil,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    guard let chain,
          chain == .init(
            pickupObjectHandle: 6_167,
            securityCameraObjectHandle: 6_183,
            pickupCollisionRadius: 3.682_004,
            pickupMessage:
                "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!",
            pickupVoiceSourceName: "guidebotc.osf",
            pickupSoundSourceName: "PupC.wav",
            useMessage:
                "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
            useVoiceSourceName: "guidebotd.osf",
            popupDuration: 10,
            popupZoom: 1,
            cameraGunpointIndex: 0,
            cameraLocalPosition: .init(
                x: -0.092_777_25,
                y: 0.791_976,
                z: 5.571_280_5
            ),
            cameraLocalForward: .init(
                x: -2.880_202e-7,
                y: -0.017_452_003,
                z: 0.999_847_7
            ),
            completionTimerDuration: 2,
            returnToShip: .init(
                markerLightObjectHandle: 10_245,
                markerLightPresentation: .init(
                    primaryColor: .init(x: 1, y: 0.25, z: 0),
                    secondaryColor: .zero,
                    timeInterval: 0.5,
                    flickerDistance: 0.2,
                    directionalDot: 0,
                    flags: 4,
                    timebits: .max,
                    angle: 0,
                    lightingRenderType: 2
                ),
                barrierRoomSourceIndex: 40,
                orderedPortalIndices: [0, 1],
                openMarkerLightDistance: 50,
                returnMessage: "GB: Returning to ship.",
                returnSoundSourceName: "GBotAcceptOrder.wav",
                greetingSoundSourceName:
                    chain.returnToShip?.greetingSoundSourceName,
                arrivalMessage: "GB: Entering ship!",
                successMessage: "Excellent!",
                successVoiceSourceName: "proceed6.osf",
                killbotEntry: .init(
                    triggerName: "Portal3",
                    triggerRoomSourceIndex: 40,
                    triggerFaceIndex: 1,
                    orderedPortalIndices: [1, 0],
                    closedMarkerLightDistance: 0,
                    entryMessage:
                        "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots.",
                    entryVoiceSourceName: "intro6.osf",
                    followupDelay: 13,
                    followupMessage:
                        "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup.",
                    followupVoiceSourceName: "guidebotf.osf"
                )
            )
          ),
          guidebotC?.sourceEntryIndex == 6,
          guidebotC?.sampleRate == 22_050,
          guidebotC?.channelCount == 1,
          guidebotC?.frameCount == 273_181,
          guidebotC?.pcmSHA256
            == "b5d968ac310d7d95780f2abd58933e7fdce20d284a9ef614e18e9f8eea3e18de",
          guidebotC?.sourceArchive == "missions/training.mn3",
          guidebotC?.sourceSHA256
            == "20d0d1e82f56c7c4d326788ac9caa1dc39ec81d4a022be52967776ec5fa85dc1",
          guidebotD?.sourceEntryIndex == 7,
          guidebotD?.sampleRate == 22_050,
          guidebotD?.channelCount == 1,
          guidebotD?.frameCount == 149_653,
          guidebotD?.pcmSHA256
            == "d97e6efaa106fbe9c4dff0affe155e04db18938e842be494292d0008b10f2a71",
          guidebotD?.sourceArchive == "missions/training.mn3",
          guidebotD?.sourceSHA256
            == "afffa8e1a39b1c6e8956105c52db8fa372a33b763aa44e18980f2e22884795d1",
          proceed6?.sourceEntryIndex == 26,
          proceed6?.sampleRate == 22_050,
          proceed6?.channelCount == 1,
          proceed6?.frameCount == 141_237,
          proceed6?.pcmSHA256
            == "ccc21ee44f4e965806904dfbd4aa95be1510e8cbe633ab43f0808b7f3026b06d",
          proceed6?.sourceArchive == "missions/training.mn3",
          proceed6?.sourceSHA256
            == "b3cd5455401af0f387d8cde20c3c869897aef55070cf8cfadd141c0f291bc403",
          intro6?.sourceName == "intro6.osf",
          intro6?.sourceEntryIndex == 15,
          intro6?.sampleRate == 22_050,
          intro6?.channelCount == 1,
          intro6?.frameCount == 212_125,
          intro6?.pcmSHA256
            == "5ee0e98d12a0648b8ce0e239ff5df36da37b4e9d6634a846d6a91fa849a1cf79",
          intro6?.sourceArchive == "missions/training.mn3",
          intro6?.sourceSHA256
            == "e8e955dd608942543f5442d1c187018286ea060fcc7440a4e180df24e602fc4a",
          guidebotF?.sourceName == "guidebotf.osf",
          guidebotF?.sourceEntryIndex == 9,
          guidebotF?.sampleRate == 22_050,
          guidebotF?.channelCount == 1,
          guidebotF?.frameCount == 91_221,
          guidebotF?.pcmSHA256
            == "244adc2baaeab1ccdf69a676a4b7cb5b81561db53a1fce1f50bd9b899c077c49",
          guidebotF?.sourceArchive == "missions/training.mn3",
          guidebotF?.sourceSHA256
            == "bc15f7be1b1a9203d1fbc264649d9d8b23d24daf522df70c9460e9007904e2f2",
          pickupSound?.logicalName == "PupC1",
          pickupSound?.sourceName == "PupC.wav",
          pickupSound?.sourceEntryIndex == 130,
          pickupSound?.sampleRate == 22_050,
          pickupSound?.channelCount == 1,
          pickupSound?.frameCount == 16_759,
          pickupSound?.pcmSHA256
            == "6cc9a2c4853f3575838d8ef16f51847e4c990140d5206158a582abddf130f099",
          pickupSound?.sourceArchive == "d3.hog",
          pickupSound?.sourceSHA256
            == "d3e8e7515facfd6c1b540e70cf7f1019c3d1f13f24140bee76337e5bb37de7d0",
          pickupSound?.importVolume == 1,
          returnSound?.logicalName == "GBotAcceptOrder1",
          returnSound?.sourceName == "GBotAcceptOrder.wav",
          returnSound?.sourceEntryIndex == 1_257,
          returnSound?.sampleRate == 22_050,
          returnSound?.channelCount == 1,
          returnSound?.frameCount == 21_652,
          returnSound?.pcmSHA256
            == "d1d068fbd7950adeaffe5a2cf3c6c56b59d488f9c53b3460f88adfb7178183b1",
          returnSound?.sourceArchive == "d3.hog",
          returnSound?.sourceSHA256
            == "47e38dfcb285be1b8d19d59929fef1b1122c1772a0cca2e6fe2b1721e5876b17",
          returnSound?.importVolume == 0.45,
          (
              chain.returnToShip?.greetingSoundSourceName == nil
                  && greetingSound == nil
              || chain.returnToShip?.greetingSoundSourceName
                    == "GBotGreetB.wav"
                  && greetingSound?.logicalName == "GBotGreetB1"
                  && greetingSound?.sourceName == "GBotGreetB.wav"
                  && greetingSound?.sourceEntryIndex == 1_268
                  && greetingSound?.sampleRate == 22_050
                  && greetingSound?.channelCount == 1
                  && greetingSound?.frameCount == 16_046
                  && greetingSound?.pcmSHA256
                    == "ec585e440bb7cc07550cd9402b6b1dc69831dd00ade8052572a5cb2383fcb2fe"
                  && greetingSound?.sourceArchive == "d3.hog"
                  && greetingSound?.sourceSHA256
                    == "5e2aee56e77e39592295759705671c37259ff8ca8cc9357ebac1bb38d7c004ca"
                  && greetingSound?.importVolume == 1
          ),
          objects.contains(where: {
              $0.handle == 6_167
                  && $0.type == 7
                  && $0.storedID == 91
                  && $0.definition?.sourceName == "Camera Monitor"
                  && $0.instanceName == "CameraMonitor"
                  && $0.flags == 4_096
          }),
          objects.contains(where: {
              $0.handle == 6_183
                  && $0.type == 2
                  && $0.storedID == 114
                  && $0.definition?.sourceName == "new wall cam"
                  && $0.instanceName == "SecurityCamera"
                  && $0.flags == 5_120
          }),
          objects.contains(where: {
              $0.handle == 10_245
                  && $0.type == 11
                  && $0.storedID == 205
                  && $0.definition?.sourceName == "Blinking Red Light-DM"
                  && $0.instanceName == "FlashLight-3"
                  && $0.location == .room(40)
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == 6_167
                  && $0.primaryModel.sourceName
                    .caseInsensitiveCompare("camerapowerup.OOF")
                    == .orderedSame
                  && $0.isVisible
          }) else {
        throw LevelValidationError.invalidDependency(
            "Training Camera Monitor package"
        )
    }
}

func validateStockTrainingCloakSoundPackage(
    _ soundClips: [CanonicalSoundClip]
) throws {
    let pickupSound = soundClips.first {
        $0.logicalName == "Powerup pickup"
    }
    let activatedSound = soundClips.first {
        $0.logicalName == "Cloak on"
    }
    let expiredSound = soundClips.first {
        $0.logicalName == "Cloak off"
    }
    guard pickupSound?.sourceName == "Power03.wav",
        pickupSound?.sourceEntryIndex == 2_657,
        pickupSound?.sampleRate == 22_050,
        pickupSound?.channelCount == 1,
        pickupSound?.frameCount == 15_189,
        pickupSound?.sourceArchive == "d3.hog",
        pickupSound?.sourceSHA256
            == "1e16aae37b233dd724d4baa001f48b83681fbc33eb16d21269cd52c5b7e8cea3",
        pickupSound?.pcmSHA256
            == "48908714345e648ce9e713d24b9aa66bfe763a82d961a83ca9543852bca8aadc",
        pickupSound?.importVolume == 1,
        activatedSound?.sourceName == "ShpCloakOn.wav",
        activatedSound?.sourceEntryIndex == 3_247,
        activatedSound?.sampleRate == 22_050,
        activatedSound?.channelCount == 1,
        activatedSound?.frameCount == 33_046,
        activatedSound?.sourceArchive == "d3.hog",
        activatedSound?.sourceSHA256
            == "27d19947e58370b18722fbcbe2fba64bf5094e3752a069bd1d2e1ed76e70c58e",
        activatedSound?.pcmSHA256
            == "61b52e468bfbe6bf5bd96ac158ef3ab7fd0d048fa375896c80de83df2129cdb2",
        activatedSound?.importVolume == 0.5,
        expiredSound?.sourceName == "ShpCloakOffBeep.wav",
        expiredSound?.sourceEntryIndex == 3_246,
        expiredSound?.sampleRate == 22_050,
        expiredSound?.channelCount == 1,
        expiredSound?.frameCount == 45_609,
        expiredSound?.sourceArchive == "d3.hog",
        expiredSound?.sourceSHA256
            == "29c9bb2fe254a9c2e75b8ae0f13b60627088294f075fbd74eae449e76c767154",
        expiredSound?.pcmSHA256
            == "8ca941f9d4a30f4b3431af4b86ff153b955885a23c686fa56fb7a8d0bfa0e87d",
        expiredSound?.importVolume == 0.5
    else {
        throw LevelValidationError.invalidDependency(
            "Training CloakPowerup2 package"
        )
    }
}
