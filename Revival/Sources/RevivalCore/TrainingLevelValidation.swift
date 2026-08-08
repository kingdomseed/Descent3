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
          chain.destroyRobotObjectHandle == 4_112,
          chain.guidebotObjectHandle == 6_164,
          chain.destroyRobotRoomSourceIndex == 37,
          chain.destroyRobotFlags == 5_121,
          chain.destructionDelay == 2,
          chain.destructionMessage == "Excellent!",
          chain.exitInstruction
            == "Now go through the open doorway, and into the next room.",
          chain.destructionVoiceSourceName == "proceed5.osf",
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
          chain.combat == .stockTraining,
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

func validateStockTrainingRepeatForwardGoalPackage(
    lesson: TrainingRepeatForwardGoalLesson?,
    forwardGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    menuBeep: CanonicalSoundClip?
) throws {
    guard let lesson,
          lesson.forwardGoalObjectHandle == 12_301,
          lesson.collisionRadius == 10.052_409,
          lesson.reverseInstruction
            == "Now use the reverse Key to return to where you started!",
          lesson.soundLogicalName == "MenuBeepEnter",
          forwardGoal?.type == 7,
          forwardGoal?.storedID == 67,
          forwardGoal?.definition?.storedIndex == 67,
          forwardGoal?.definition?.referenceRuntimeIndex == 68,
          forwardGoal?.definition?.sourceName == "Invisiblepowerup",
          forwardGoal?.instanceName == "ForwardGoal",
          forwardGoal?.flags == 36_864,
          forwardGoal?.location == .room(1),
          forwardGoal?.position
            == .init(
                x: 2_060.4836,
                y: -131.22517,
                z: 2_310.928
            ),
          forwardGoal?.orientation
            == .init(
                right: .init(
                    x: -0.997_518_1,
                    y: 0,
                    z: 0.070_410_63
                ),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(
                    x: -0.070_410_63,
                    y: 0,
                    z: -0.997_518_1
                )
            ),
          forwardGoal?.containsType == 255,
          forwardGoal?.containsID == 0,
          forwardGoal?.containsCount == 0,
          forwardGoal?.lifeLeft == 0,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.isVisible == false,
          menuBeep?.sourceName == "MenuBeepSelectC.wav",
          menuBeep?.sourceEntryIndex == 2_079,
          menuBeep?.sampleRate == 22_050,
          menuBeep?.channelCount == 1,
          menuBeep?.frameCount == 2_321,
          menuBeep?.pcmSHA256
            == "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
          menuBeep?.sourceArchive == "d3.hog",
          menuBeep?.sourceSHA256
            == "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
          menuBeep?.importVolume == 0.7
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 008 package"
        )
    }
}

func validateStockTrainingRepeatReturnLeftPackage(
    lesson: TrainingRepeatReturnLeftLesson?,
    startGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    lright: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startGoalObjectHandle == 12_300,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction == "Now Go Left until you stop.",
          lesson.voiceSourceName == "lright.osf",
          startGoal?.type == 7,
          startGoal?.storedID == 67,
          startGoal?.definition?.storedIndex == 67,
          startGoal?.definition?.referenceRuntimeIndex == 68,
          startGoal?.definition?.sourceName == "Invisiblepowerup",
          startGoal?.instanceName == "StartGoal",
          startGoal?.flags == 36_864,
          startGoal?.location == .room(1),
          startGoal?.position
            == .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
          startGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startGoal?.containsType == 255,
          startGoal?.containsID == 0,
          startGoal?.containsCount == 0,
          startGoal?.lifeLeft == 0,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.isVisible == false,
          lright?.sourceName.caseInsensitiveCompare("lright.osf")
            == .orderedSame,
          lright?.sourceEntryIndex == 19,
          lright?.sampleRate == 22_050,
          lright?.channelCount == 1,
          lright?.frameCount == 43_289,
          lright?.pcmSHA256
            == "db92df633fdc0010fe9c5cc89f452ea79107e0abdfd4a1ff1e845220abf8b7b5",
          lright?.sourceArchive == "missions/training.mn3",
          lright?.sourceSHA256
            == "234c82a439232af1072a7cb6aef8e6d14b6432a2c7a642f7a8e4904a01e88294"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 009 package"
        )
    }
}

func validateStockTrainingRepeatReturnRightPackage(
    lesson: TrainingRepeatReturnRightLesson?,
    leftGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    menuBeep: CanonicalSoundClip?
) throws {
    guard let lesson,
          lesson.leftGoalObjectHandle == 12_299,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction
            == "Now Slide right until you return to the start position.",
          lesson.soundLogicalName == "MenuBeepEnter",
          leftGoal?.type == 7,
          leftGoal?.storedID == 67,
          leftGoal?.definition?.storedIndex == 67,
          leftGoal?.definition?.referenceRuntimeIndex == 68,
          leftGoal?.definition?.sourceName == "Invisiblepowerup",
          leftGoal?.instanceName == "LeftGoal",
          leftGoal?.flags == 4_352,
          leftGoal?.location == .room(1),
          leftGoal?.position
            == .init(
                x: 1_958.2805,
                y: -131.22517,
                z: 2_205.8071
            ),
          leftGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            ),
          leftGoal?.containsType == 255,
          leftGoal?.containsID == 0,
          leftGoal?.containsCount == 0,
          leftGoal?.lifeLeft == 0,
          leftGoal?.soundSource == nil,
          leftGoal?.inertScriptName == nil,
          leftGoal?.inertModuleName == nil,
          leftGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          menuBeep?.sourceName == "MenuBeepSelectC.wav",
          menuBeep?.sourceEntryIndex == 2_079,
          menuBeep?.sampleRate == 22_050,
          menuBeep?.channelCount == 1,
          menuBeep?.frameCount == 2_321,
          menuBeep?.pcmSHA256
            == "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
          menuBeep?.sourceArchive == "d3.hog",
          menuBeep?.sourceSHA256
            == "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
          menuBeep?.importVolume == 0.7
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 010 package"
        )
    }
}

func validateStockTrainingRepeatReturnUpPackage(
    lesson: TrainingRepeatReturnUpLesson?,
    startGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    udown: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startGoalObjectHandle == 12_300,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction == "Now Slide up  until you stop.",
          lesson.voiceSourceName == "udown.osf",
          startGoal?.type == 7,
          startGoal?.storedID == 67,
          startGoal?.definition?.storedIndex == 67,
          startGoal?.definition?.referenceRuntimeIndex == 68,
          startGoal?.definition?.sourceName == "Invisiblepowerup",
          startGoal?.instanceName == "StartGoal",
          startGoal?.flags == 36_864,
          startGoal?.location == .room(1),
          startGoal?.position
            == .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
          startGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startGoal?.containsType == 255,
          startGoal?.containsID == 0,
          startGoal?.containsCount == 0,
          startGoal?.lifeLeft == 0,
          startGoal?.soundSource == nil,
          startGoal?.inertScriptName == nil,
          startGoal?.inertModuleName == nil,
          startGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          udown?.sourceName.caseInsensitiveCompare("udown.osf")
            == .orderedSame,
          udown?.sourceEntryIndex == 36,
          udown?.sampleRate == 22_050,
          udown?.channelCount == 1,
          udown?.frameCount == 37_257,
          udown?.pcmSHA256
            == "e54d74f7e18603ad90015cef1e7c15cce693e35a394be4a0a45943c07740af2a",
          udown?.sourceArchive == "missions/training.mn3",
          udown?.sourceSHA256
            == "f9596f8edb16be0821bb7b846b81432b27aa95f08ac621f1ac1f15eb1279aa43"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 011 package"
        )
    }
}

func validateStockTrainingRepeatReturnDownPackage(
    lesson: TrainingRepeatReturnDownLesson?,
    upGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    menuBeep: CanonicalSoundClip?
) throws {
    guard let lesson,
          lesson.upGoalObjectHandle == 18_441,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction
            == "Now Slide down until you return to the start position.",
          lesson.soundLogicalName == "MenuBeepEnter",
          upGoal?.type == 7,
          upGoal?.storedID == 67,
          upGoal?.definition?.storedIndex == 67,
          upGoal?.definition?.referenceRuntimeIndex == 68,
          upGoal?.definition?.sourceName == "Invisiblepowerup",
          upGoal?.instanceName == "UpGoal",
          upGoal?.flags == 4_352,
          upGoal?.location == .room(1),
          upGoal?.position
            == .init(
                x: 2_060.6682,
                y: -25.897_497,
                z: 2_204.6843
            ),
          upGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          upGoal?.containsType == 255,
          upGoal?.containsID == 0,
          upGoal?.containsCount == 0,
          upGoal?.lifeLeft == 0,
          upGoal?.soundSource == nil,
          upGoal?.inertScriptName == nil,
          upGoal?.inertModuleName == nil,
          upGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          menuBeep?.sourceName == "MenuBeepSelectC.wav",
          menuBeep?.sourceEntryIndex == 2_079,
          menuBeep?.sampleRate == 22_050,
          menuBeep?.channelCount == 1,
          menuBeep?.frameCount == 2_321,
          menuBeep?.pcmSHA256
            == "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
          menuBeep?.sourceArchive == "d3.hog",
          menuBeep?.sourceSHA256
            == "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
          menuBeep?.importVolume == 0.7
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 012 package"
        )
    }
}

func validateStockTrainingContinueToCoursePackage(
    lesson: TrainingContinueToCourseLesson?,
    startGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    portalRoom: LevelRoom?,
    connectedRooms: [Int: LevelRoom],
    proceed1: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startGoalObjectHandle == 12_300,
          lesson.collisionRadius == 10.052_409,
          lesson.portalRoomSourceIndex == 2,
          lesson.orderedPortalIndices == [0, 1],
          lesson.instruction
            == "Continue Sliding down to start the next step.",
          lesson.voiceSourceName == "proceed1.osf",
          startGoal?.type == 7,
          startGoal?.storedID == 67,
          startGoal?.definition?.storedIndex == 67,
          startGoal?.definition?.referenceRuntimeIndex == 68,
          startGoal?.definition?.sourceName == "Invisiblepowerup",
          startGoal?.instanceName == "StartGoal",
          startGoal?.flags == 36_864,
          startGoal?.location == .room(1),
          startGoal?.position
            == .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
          startGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startGoal?.containsType == 255,
          startGoal?.containsID == 0,
          startGoal?.containsCount == 0,
          startGoal?.lifeLeft == 0,
          startGoal?.soundSource == nil,
          startGoal?.inertScriptName == nil,
          startGoal?.inertModuleName == nil,
          startGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          let portalRoom,
          portalRoom.name == "PortalRoom1",
          portalRoom.sourceIndex == 2,
          portalRoom.portals.count == 2,
          portalRoom.faces.indices.contains(0),
          portalRoom.faces.indices.contains(1),
          portalRoom.portals[0].faceIndex == 0,
          portalRoom.portals[0].connectedRoom == 1,
          portalRoom.portals[0].connectedPortal == 0,
          portalRoom.portals[0].flags & 1 != 0,
          portalRoom.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          portalRoom.portals[1].faceIndex == 1,
          portalRoom.portals[1].connectedRoom == 3,
          portalRoom.portals[1].connectedPortal == 0,
          portalRoom.portals[1].flags & 1 != 0,
          portalRoom.faces[1].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoomOne = connectedRooms[1],
          connectedRoomOne.portals.indices.contains(0),
          connectedRoomOne.faces.indices.contains(73),
          connectedRoomOne.portals[0].faceIndex == 73,
          connectedRoomOne.portals[0].connectedRoom == 2,
          connectedRoomOne.portals[0].connectedPortal == 0,
          connectedRoomOne.portals[0].flags & 1 != 0,
          connectedRoomOne.faces[73].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoomThree = connectedRooms[3],
          connectedRoomThree.portals.indices.contains(0),
          connectedRoomThree.faces.indices.contains(0),
          connectedRoomThree.portals[0].faceIndex == 0,
          connectedRoomThree.portals[0].connectedRoom == 2,
          connectedRoomThree.portals[0].connectedPortal == 1,
          connectedRoomThree.portals[0].flags & 1 != 0,
          connectedRoomThree.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          proceed1?.sourceName.caseInsensitiveCompare("proceed1.osf")
            == .orderedSame,
          proceed1?.sourceEntryIndex == 21,
          proceed1?.sampleRate == 22_050,
          proceed1?.channelCount == 1,
          proceed1?.frameCount == 120_753,
          proceed1?.pcmSHA256
            == "5eba5487d90f946a876eaa500d3a27e496fe280d9fadcd633b8f505c58ccb477",
          proceed1?.sourceArchive == "missions/training.mn3",
          proceed1?.sourceSHA256
            == "9f869718d68d56902ee634b47a1f8cafa83f79036fe39216d190cebf0803081a"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 013 package"
        )
    }
}

func validateStockTrainingStartCoursePackage(
    lesson: TrainingStartCourseLesson?,
    startCourse: PlacedObject?,
    presentation: ObjectPresentationReference?,
    portalRoom: LevelRoom?,
    connectedRoom: LevelRoom?,
    intro1: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startCourseObjectHandle == 6_147,
          lesson.collisionRadius == 10.052_409,
          lesson.portalRoomSourceIndex == 2,
          lesson.portalIndex == 1,
          lesson.instruction
            == "Now, manuever through this tunnel using the sliding skills you just learned.",
          lesson.voiceSourceName == "intro1.osf",
          lesson.enabledControlMask == 63,
          startCourse?.type == 7,
          startCourse?.storedID == 67,
          startCourse?.definition?.storedIndex == 67,
          startCourse?.definition?.referenceRuntimeIndex == 68,
          startCourse?.definition?.sourceName == "Invisiblepowerup",
          startCourse?.instanceName == "StartCourse",
          startCourse?.flags == 4_096,
          startCourse?.location == .room(3),
          startCourse?.position
            == .init(
                x: 2_061.4604,
                y: -230.09009,
                z: 2_203.0276
            ),
          startCourse?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startCourse?.containsType == 255,
          startCourse?.containsID == 0,
          startCourse?.containsCount == 0,
          startCourse?.lifeLeft == 0,
          startCourse?.soundSource == nil,
          startCourse?.inertScriptName == nil,
          startCourse?.inertModuleName == nil,
          startCourse?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          let portalRoom,
          portalRoom.name == "PortalRoom1",
          portalRoom.sourceIndex == 2,
          portalRoom.portals.indices.contains(1),
          portalRoom.faces.indices.contains(1),
          portalRoom.portals[1].faceIndex == 1,
          portalRoom.portals[1].connectedRoom == 3,
          portalRoom.portals[1].connectedPortal == 0,
          portalRoom.portals[1].flags & 1 != 0,
          portalRoom.faces[1].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoom,
          connectedRoom.sourceIndex == 3,
          connectedRoom.portals.indices.contains(0),
          connectedRoom.faces.indices.contains(0),
          connectedRoom.portals[0].faceIndex == 0,
          connectedRoom.portals[0].connectedRoom == 2,
          connectedRoom.portals[0].connectedPortal == 1,
          connectedRoom.portals[0].flags & 1 != 0,
          connectedRoom.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          intro1?.sourceName == "intro1.osf",
          intro1?.sourceEntryIndex == 10,
          intro1?.sampleRate == 22_050,
          intro1?.channelCount == 1,
          intro1?.frameCount == 475_785,
          intro1?.pcmSHA256
            == "7a91932d2f083bbb498247a0cac427ea5e4fdacb7b7eb7e3d9653b43b6f87c6c",
          intro1?.sourceArchive == "missions/training.mn3",
          intro1?.sourceSHA256
            == "d4f0a217c401899acbbf64e25f0d013542acae82e667bb2330be5770e35d200f"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 014 package"
        )
    }
}

func validateStockTrainingFinishCoursePackage(
    lesson: TrainingFinishCourseLesson?,
    finishCourse: PlacedObject?,
    presentation: ObjectPresentationReference?,
    portalRoom: LevelRoom?,
    connectedRooms: [Int: LevelRoom],
    proceed2: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.finishCourseObjectHandle == 6_150,
          lesson.collisionRadius == 10.052_409,
          lesson.portalRoomSourceIndex == 49,
          lesson.orderedPortalIndices == [0, 1],
          lesson.successMessage == "Excellent!",
          lesson.instruction
            == "Continue Sliding down to start the next step.",
          lesson.voiceSourceName == "proceed2.osf",
          lesson.enabledControlMask == 32,
          finishCourse?.type == 7,
          finishCourse?.storedID == 67,
          finishCourse?.definition?.storedIndex == 67,
          finishCourse?.definition?.referenceRuntimeIndex == 68,
          finishCourse?.definition?.sourceName == "Invisiblepowerup",
          finishCourse?.instanceName == "FinishCourse",
          finishCourse?.flags == 4_096,
          finishCourse?.location == .room(50),
          finishCourse?.position
            == .init(
                x: 2_062.5024,
                y: -650.74756,
                z: 2_206.0369
            ),
          finishCourse?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          finishCourse?.containsType == 255,
          finishCourse?.containsID == 0,
          finishCourse?.containsCount == 0,
          finishCourse?.lifeLeft == 0,
          finishCourse?.soundSource == nil,
          finishCourse?.inertScriptName == nil,
          finishCourse?.inertModuleName == nil,
          finishCourse?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          let portalRoom,
          portalRoom.name == "PortalRoom2",
          portalRoom.sourceIndex == 49,
          portalRoom.portals.count == 2,
          portalRoom.faces.indices.contains(0),
          portalRoom.faces.indices.contains(1),
          portalRoom.portals[0].faceIndex == 1,
          portalRoom.portals[0].connectedRoom == 35,
          portalRoom.portals[0].connectedPortal == 0,
          portalRoom.portals[0].flags & 1 != 0,
          portalRoom.faces[1].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          portalRoom.portals[1].faceIndex == 0,
          portalRoom.portals[1].connectedRoom == 50,
          portalRoom.portals[1].connectedPortal == 0,
          portalRoom.portals[1].flags & 1 != 0,
          portalRoom.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoom35 = connectedRooms[35],
          connectedRoom35.portals.indices.contains(0),
          connectedRoom35.faces.indices.contains(20),
          connectedRoom35.portals[0].faceIndex == 20,
          connectedRoom35.portals[0].connectedRoom == 49,
          connectedRoom35.portals[0].connectedPortal == 0,
          connectedRoom35.portals[0].flags & 1 != 0,
          connectedRoom35.faces[20].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoom50 = connectedRooms[50],
          connectedRoom50.portals.indices.contains(0),
          connectedRoom50.faces.indices.contains(0),
          connectedRoom50.portals[0].faceIndex == 0,
          connectedRoom50.portals[0].connectedRoom == 49,
          connectedRoom50.portals[0].connectedPortal == 1,
          connectedRoom50.portals[0].flags & 1 != 0,
          connectedRoom50.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          proceed2?.sourceName.caseInsensitiveCompare("proceed2.osf")
            == .orderedSame,
          proceed2?.sourceEntryIndex == 22,
          proceed2?.sampleRate == 22_050,
          proceed2?.channelCount == 1,
          proceed2?.frameCount == 136_901,
          proceed2?.pcmSHA256
            == "78c63a73ed1ddbd12a5974ef74c31bc6bfd10295f96ddf345fb15b2565586fca",
          proceed2?.sourceArchive == "missions/training.mn3",
          proceed2?.sourceSHA256
            == "65c51f7e7bf15091ac59c9c3186a9269bf885311b6aada57f74628d497e87f14"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 015 package"
        )
    }
}

func validateStockTrainingDodgeAttemptPackage(
    _ dodge: TrainingDodgeAttempt?,
    level: Level
) throws {
    let turretModel = dodge.flatMap { definition in
        level.models.first {
            $0.source == definition.turret.model
        }
    }
    let projectileModel = dodge.flatMap { definition in
        level.models.first {
            $0.source == definition.turret.projectileModel
        }
    }
    let intro = level.voiceClips.first {
        $0.sourceName == "intro2.osf"
    }
    let almost = level.voiceClips.first {
        $0.sourceName == "almost.osf"
    }
    let proceed = level.voiceClips.first {
        $0.sourceName == "proceed3.osf"
    }
    let proceed4 = level.voiceClips.first {
        $0.sourceName == "proceed4.osf"
    }
    let fire = level.soundClips.first {
        $0.logicalName == "WpmLaserBlueFire"
    }
    let impact = level.soundClips.first {
        $0.logicalName == "LazorHitshrt"
    }
    guard let dodge,
        level.objects.first(where: {
            $0.handle == dodge.startDodgeObjectHandle
        })?.definition?.referenceRuntimeIndex == 68,
        level.objects.first(where: {
            $0.handle == dodge.doneDodgeingGoalObjectHandle
        })?.definition?.referenceRuntimeIndex == 68,
        dodge.turret.collisionRadius == 5.402_855_4,
        dodge.turret.fieldOfViewDot == -1,
        dodge.turret.maximumTargetDistance == 1_000,
        dodge.turret.fireAlignmentDot == 0.93,
        dodge.turret.fixedLeadAccuracy == 0.81,
        dodge.turret.fireWait == 1,
        dodge.turret.gunpoints == [
            .init(
                x: 1.706_505_8,
                y: -2.224_015_2,
                z: 2.190_463_5
            ),
            .init(
                x: 0.457_947_73,
                y: -2.224_015_2,
                z: 2.190_463_5
            ),
        ],
        dodge.turret.aimingGunpoint
            == .init(
                x: 1.085_584_6,
                y: -2.224_015_2,
                z: 2.190_463_5
            ),
        dodge.turret.gunpointForward
            == .init(x: 0, y: -0.707_105_7, z: 0.707_107_84),
        dodge.turret.gunpointParentSubmodelIndex == 2,
        dodge.turret.joints == [
            .init(
                submodelIndex: 1,
                parentSubmodelIndex: 0,
                rotationAxis: .init(x: 0, y: -1, z: 0),
                fieldOfView: 0.5,
                rotationsPerSecond: 0.125,
                thinkInterval: 10
            ),
            .init(
                submodelIndex: 2,
                parentSubmodelIndex: 1,
                rotationAxis: .init(
                    x: 1,
                    y: -3.410_774_8e-16,
                    z: -4.371_139e-8
                ),
                fieldOfView: 0.125,
                rotationsPerSecond: 0.125,
                thinkInterval: 10
            ),
        ],
        dodge.turret.projectileSourceName == "Laser Level 1 - Red",
        dodge.turret.projectileDamage == 6.75,
        dodge.turret.projectileRadius == 0.5,
        dodge.turret.projectileSpeed == 200,
        dodge.turret.projectileLifetime == 5,
        dodge.turret.fireSoundSourceName == "WpmLaserBlueFire",
        dodge.turret.impactSoundSourceName == "LazorHitshrt",
        turretModel?.collisionRadius == 5.552_946,
        turretModel?.submodels.count == 3,
        turretModel?.submodels[1].parentIndex == 0,
        turretModel?.submodels[1].offset
            == .init(
                x: -0.079_373_36,
                y: -1.241_355_9,
                z: 0.097_942_59
            ),
        turretModel?.submodels[1].presentation
            == .turret(
                fieldOfView: 0.5,
                rotationsPerSecond: 0.125,
                thinkInterval: 10,
                axis: .init(x: 0, y: -1, z: 0)
            ),
        turretModel?.submodels[2].parentIndex == 1,
        turretModel?.submodels[2].offset
            == .init(
                x: -1.132_905,
                y: -1.353_618_6,
                z: 0.311_014_4
            ),
        turretModel?.submodels[2].presentation
            == .turret(
                fieldOfView: 0.125,
                rotationsPerSecond: 0.125,
                thinkInterval: 10,
                axis: .init(
                    x: 1,
                    y: -3.410_774_8e-16,
                    z: -4.371_139e-8
                )
            ),
        turretModel?.sourceSHA256
            == "41c69958947ddc7673ddfe2ffb6f559c6892eafed8b759a02b47c05b22f137e4",
        projectileModel?.collisionRadius == 4.878_135,
        projectileModel?.sourceSHA256
            == "67e6ff8f84fbcbc60b33a61b222e04be6cfbd4b53ad367ac14f82cca2a76a1ab",
        intro?.sampleRate == 22_050,
        intro?.channelCount == 1,
        intro?.frameCount == 419_497,
        intro?.pcmSHA256
            == "c43858617c694a1c41dbcc2b9b0c31e0b0f73ff7e33423ef3b80bcf501ef9def",
        intro?.sourceArchive == "missions/training.mn3",
        intro?.sourceSHA256
            == "46d1947fad72e9fb33bd6e912bf45fc7f20e5095f27b8a0516f24e2a8077f880",
        almost?.sampleRate == 22_050,
        almost?.channelCount == 1,
        almost?.frameCount == 68_977,
        almost?.pcmSHA256
            == "4d90c15e4c1f9a22fb9b4a3808739d6eecd8590b688b10a84abe7bf641ef8017",
        almost?.sourceArchive == "missions/training.mn3",
        almost?.sourceSHA256
            == "2f40177e347bb942bbacb3a54fc8ba5a91410132fdaf79e69fca862f2c4d8d93",
        proceed?.sampleRate == 22_050,
        proceed?.channelCount == 1,
        proceed?.frameCount == 149_913,
        proceed?.pcmSHA256
            == "abc67c37d716253959d0ec615b364b6ff59b896179fc3f93256be3870ed3dabd",
        proceed?.sourceArchive == "missions/training.mn3",
        proceed?.sourceSHA256
            == "3f7050b78bce76e370847b89e824b11db618f1b2d7c0d35de2f579e8edb67460",
        fire?.sourceName == "LaserAHitB.wav",
        fire?.sampleRate == 22_050,
        fire?.channelCount == 1,
        fire?.frameCount == 22_048,
        fire?.pcmSHA256
            == "150811e7fee88f8ad68a7cff7eb64c1a3cbaa89ba3a5a3330debf2a1f5e0c84a",
        fire?.sourceArchive == "d3.hog",
        fire?.sourceSHA256
            == "c76cb4a9608b4e57613c1b5438dcbd9af4618ad87c57f0c747de61aa7f810208",
        fire?.importVolume == 1,
        impact?.sourceName == "Lazor1Hit.wav",
        impact?.sampleRate == 22_050,
        impact?.channelCount == 1,
        impact?.frameCount == 17_728,
        impact?.pcmSHA256
            == "8b5154fa71e2fded239c6415ba4d77511a90bb4ab72aed8ea2e3bd231cf52b99",
        impact?.sourceArchive == "d3.hog",
        impact?.sourceSHA256
            == "7fe72d116e223068a55af61e6484f3604d6f07e6ae8d3ff3d5ca83016660f470",
        impact?.importVolume == 0.200_000_02
    else {
        throw LevelValidationError.invalidDependency(
            "Training timed dodge stock package"
        )
    }
    if let exit = dodge.dodgeExit {
        guard exit.objectHandle == dodge.doneDodgeingGoalObjectHandle,
            exit.collisionRadius
                == dodge.doneDodgeingGoalCollisionRadius,
            exit.markerLightObjectHandle
                == dodge.flashLightObjectHandle,
            exit.markerLightDistance == 50,
            exit.portalRoomSourceIndex
                == dodge.portalRoomThreeSourceIndex,
            exit.orderedPortalIndices == dodge.orderedPortalIndices,
            exit.disabledControlMask == 62,
            exit.instruction
                == "Now keep moving forward into the next room.",
            exit.voiceSourceName == "proceed4.osf",
            proceed4?.sourceEntryIndex == 24,
            proceed4?.sampleRate == 22_050,
            proceed4?.channelCount == 1,
            proceed4?.frameCount == 99_405,
            proceed4?.pcmSHA256
                == "92228006e3a802cc067a1650f735cc1a04865bf68d35ab3bc94343049e3dadc7",
            proceed4?.sourceArchive == "missions/training.mn3",
            proceed4?.sourceSHA256
                == "d7442b4192e34ed6b7b529f3b3d555be64ef3437c000611ff7fa57d6989550e9"
        else {
            throw LevelValidationError.invalidDependency(
                "Training Script 019 stock package"
            )
        }
    }
    if let lesson = dodge.maneuverFollow {
        try validateStockTrainingManeuverFollowPackage(
            lesson,
            dodge: dodge,
            level: level
        )
    }
}

func validateStockTrainingManeuverFollowPackage(
    _ lesson: TrainingManeuverFollowLesson,
    dodge: TrainingDodgeAttempt,
    level: Level
) throws {
    let maneuver = level.objects.first {
        $0.handle == lesson.maneuverObjectHandle
    }
    let followBot = level.objects.first {
        $0.handle == lesson.followBotObjectHandle
    }
    let presentation = level.objectPresentations.first {
        $0.objectHandle == lesson.followBotObjectHandle
    }
    let model = level.models.first {
        $0.source == lesson.followBot.model
    }
    let pathsSHA256 = canonicalSHA256(
        try canonicalJSONData(level.paths)
    )
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map {
            ($0.sourceIndex, $0)
        }
    )
    let portalRoom = roomBySourceIndex[
        lesson.portalRoomSourceIndex
    ]
    let reciprocalConnections = lesson.orderedPortalIndices.compactMap {
        portalIndex -> (Int, Int)? in
        guard let portalRoom,
              portalRoom.portals.indices.contains(portalIndex)
        else {
            return nil
        }
        let portal = portalRoom.portals[portalIndex]
        guard let reciprocalRoom =
                roomBySourceIndex[portal.connectedRoom],
              reciprocalRoom.portals.indices.contains(
                  portal.connectedPortal
              ),
              reciprocalRoom.portals[portal.connectedPortal]
                .connectedRoom == lesson.portalRoomSourceIndex,
              reciprocalRoom.portals[portal.connectedPortal]
                .connectedPortal == portalIndex
        else {
            return nil
        }
        return (
            portal.connectedRoom,
            portal.connectedPortal
        )
    }
    let requiredVoices = [
        lesson.headingVoiceSourceName,
        lesson.pitchVoiceSourceName,
        lesson.bankVoiceSourceName,
        lesson.followVoiceSourceName,
        lesson.weaponVoiceSourceName,
    ]
    guard lesson.maneuverObjectHandle == 2_063,
          lesson.maneuverCollisionRadius == 10.052_409,
          lesson.flashLightObjectHandle
            == dodge.flashLightObjectHandle,
          lesson.portalRoomSourceIndex == 36,
          lesson.orderedPortalIndices == [1, 0],
          reciprocalConnections.map(\.0) == [37, 35],
          reciprocalConnections.map(\.1) == [0, 1],
          lesson.headingControlMask == 768,
          lesson.pitchControlMask == 192,
          lesson.bankControlMask == 3_072,
          lesson.rotationalControlMask == 4_032,
          lesson.weaponControlMask == 12_288,
          lesson.headingDuration == 20,
          lesson.pitchDuration == 12,
          lesson.bankDuration == 15,
          lesson.followDuration == 20,
          lesson.followBotObjectHandle == 8_200,
          lesson.friendlyTeamFlags == 65_536,
          lesson.followPathIndex == 0,
          lesson.followPathGoalFlags == 9_437_444,
          lesson.destroyPathIndex == 1,
          lesson.destroyPathGoalFlags == 4_352,
          lesson.goalSlot == 0,
          lesson.goalPriority == 3,
          lesson.maneuverIntroduction
            == "Now you are going to learn the other controls, which are pitch, heading and bank.",
          lesson.headingInstruction
            == "Now your heading controls are enabled. Try them out by rotating to the left and right.",
          lesson.successMessage == "Excellent!",
          lesson.pitchInstruction
            == "Now your pitch controls are enabled. Try them out by pitching up and down.",
          lesson.bankInstruction
            == "Now your bank controls are enabled. Try them out by banking to the left and right.",
          lesson.followIntroduction
            == "Now you will use the rotational skills you just learned to follow one of the two robots that are circling this room",
          lesson.followInstruction
            == "Keep one of the robots on your screen for 20 seconds using only your rotational controls to complete this step.",
          lesson.weaponsEnabledInstruction
            == "Now your weapons have been enabled. There is a primary and a secondary.",
          lesson.destroyInstruction == "Now, destroy the robot.",
          requiredVoices == [
              "intro3.osf",
              "pitch.osf",
              "bank.osf",
              "follow.osf",
              "intro4.osf",
          ],
          requiredVoices.allSatisfy({ sourceName in
              guard let voice = level.voiceClips.first(where: {
                  $0.sourceName == sourceName
              }),
                    voice.sampleRate == 22_050,
                    voice.channelCount == 1,
                    voice.pcm16LittleEndian.count
                        == voice.frameCount * 2,
                    voice.sourceArchive == "missions/training.mn3"
              else {
                  return false
              }
              switch sourceName {
              case "intro3.osf":
                  return voice.sourceEntryIndex == 12
                    && voice.frameCount == 340_641
                    && voice.pcmSHA256
                        == "66aa8390a210046b75a9c60fbdcff9b10acb8ba1e0b5bd650dd8f46e137ba119"
                    && voice.sourceSHA256
                        == "d2632c6e360d1d683c381c86155c7d8280a9880f4a8e6554e1884e82cff35036"
              case "pitch.osf":
                  return voice.sourceEntryIndex == 20
                    && voice.frameCount == 160_393
                    && voice.pcmSHA256
                        == "a717bd60b81636c17980a5ec742b44d60e091e0c768719b2d8bfd0713d29761b"
                    && voice.sourceSHA256
                        == "6b238a3d0301fcf34046c458632bb6fc88efeb26caa79dac5bce01c5c0ce6773"
              case "bank.osf":
                  return voice.sourceEntryIndex == 1
                    && voice.frameCount == 180_229
                    && voice.pcmSHA256
                        == "32d6968a855f0bc5a5e50da9cf57faf40089264d9777f6abb1e2f398b0f317da"
                    && voice.sourceSHA256
                        == "97949ad89610d02f8eb027c06daf8dc388e9d3159cc10fed85d62c6aaf7df703"
              case "follow.osf":
                  return voice.sourceEntryIndex == 3
                    && voice.frameCount == 163_749
                    && voice.pcmSHA256
                        == "92f90622166a1d27858510a2d3d1b0a5f1cf4d2690e204752927ca3bb4ff69a9"
                    && voice.sourceSHA256
                        == "6ec65e7e1aa1a6a5ec6c28b67e2c3f714925deaa4d910a152ec8d6f6ad908b5f"
              case "intro4.osf":
                  return voice.sourceEntryIndex == 13
                    && voice.frameCount == 750_221
                    && voice.pcmSHA256
                        == "2b874c0f3c704f3f029cac8d0ace36578b5141fc93aabc52ae2d9231975670ed"
                    && voice.sourceSHA256
                        == "325b1bcf073a24042836fca4fb6b1e1fcb4975a3cc3c3b3560db86b06af36b9e"
              default:
                  return false
              }
          }),
          maneuver?.type == 7,
          maneuver?.storedID == 67,
          maneuver?.definition?.storedIndex == 67,
          maneuver?.definition?.referenceRuntimeIndex == 68,
          maneuver?.definition?.sourceName == "Invisiblepowerup",
          maneuver?.instanceName == "ManuverRoomCenter",
          maneuver?.flags == 4_096,
          maneuver?.location == .room(37),
          maneuver?.position
            == .init(
                x: 2_061.7336,
                y: -755.4103,
                z: 2_566.1135
            ),
          maneuver?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            ),
          maneuver?.containsType == 255,
          maneuver?.containsID == 0,
          maneuver?.containsCount == 0,
          maneuver?.lifeLeft == 0,
          maneuver?.soundSource == nil,
          maneuver?.inertScriptName == nil,
          maneuver?.inertModuleName == nil,
          maneuver?.lightmapSubmodels.isEmpty == true,
          followBot?.type == 2,
          followBot?.storedID == 106,
          followBot?.definition?.storedIndex == 106,
          followBot?.definition?.sourceName
            == "RAS1 Light Security Flyer",
          followBot?.instanceName == "FollowBot1",
          followBot?.flags == 5_121,
          followBot?.location == .room(37),
          followBot?.position
            == .init(
                x: 2_059.3496,
                y: -723.2588,
                z: 2_469.1072
            ),
          followBot?.orientation
            == .init(
                right: .init(
                    x: -0.999_645_05,
                    y: -0.010_065_023,
                    z: 0.024_667_98
                ),
                up: .init(
                    x: -0.008_759_673,
                    y: 0.998_584_4,
                    z: 0.052_465_245
                ),
                forward: .init(
                    x: -0.025_161_121,
                    y: 0.052_230_537,
                    z: -0.998_318_1
                )
            ),
          followBot?.containsType == 255,
          followBot?.containsID == 0,
          followBot?.containsCount == 0,
          followBot?.lifeLeft == 0,
          followBot?.soundSource == nil,
          followBot?.inertScriptName == nil,
          followBot?.inertModuleName == nil,
          followBot?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel == lesson.followBot.model,
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.isVisible == true,
          model?.source.sourceName == "gyro.OOF",
          model?.collisionRadius == 3.841_456_2,
          model?.sourceArchive == "d3.hog",
          model?.sourceSHA256
            == "896cc33ba0c7ec00fd2fd693a0e8f10868a47076eda0b7914cc90a790e87eb61",
          lesson.followBot.collisionRadius == 4.576_441_8,
          lesson.followBot.maximumVelocity == 40,
          lesson.followBot.maximumDeltaVelocity == 80,
          lesson.followBot.maximumTurnRate == 12_000,
          lesson.followBot.maximumDeltaTurnRate == 16_000,
          lesson.followBot.circleDistance == 25,
          level.paths.indices.contains(lesson.followPathIndex),
          level.paths.indices.contains(lesson.destroyPathIndex),
          pathsSHA256
            == "56997a7e05b017a65778bd48badf453f72bdf5f3f34d60fbd1d6cd8b4fdcdbe5"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 021-026 stock package"
        )
    }
    if let handoff = lesson.destructionHandoff {
        try validateStockTrainingFollowBotDestructionHandoff(
            handoff,
            lesson: lesson,
            level: level
        )
    }
}

func validateStockTrainingFollowBotDestructionHandoff(
    _ handoff: TrainingFollowBotDestructionHandoff,
    lesson: TrainingManeuverFollowLesson,
    level: Level
) throws {
    try validateTrainingFollowBotDestructionHandoff(
        handoff,
        lesson: lesson,
        level: level
    )
    let followBot = level.objects.first {
        $0.handle == handoff.followBotObjectHandle
    }
    let destroyBot2 = level.objects.first {
        $0.handle == handoff.destroyBot2ObjectHandle
    }
    let destroyBot1 = level.objects.first {
        $0.handle == handoff.destroyBot1ObjectHandle
    }
    let destroyBot2Presentation = level.objectPresentations.first {
        $0.objectHandle == handoff.destroyBot2ObjectHandle
    }
    let destroyBot1Presentation = level.objectPresentations.first {
        $0.objectHandle == handoff.destroyBot1ObjectHandle
    }
    let projectileModel = level.models.first {
        $0.source == handoff.projectileModel
    }
    let voice = level.voiceClips.first {
        $0.sourceName == handoff.voiceSourceName
    }
    guard handoff.followBotObjectHandle
            == lesson.followBotObjectHandle,
          handoff.destroyBot2ObjectHandle == 4_112,
          handoff.destroyBot1ObjectHandle == 4_113,
          handoff.combat == .stockTraining,
          handoff.projectileModel.sourceName
            .caseInsensitiveCompare("bluelaser.OOF")
            == .orderedSame,
          handoff.destructionDelay == 2,
          handoff.levelTimerID == 11,
          handoff.movingTeamFlags == 65_536,
          handoff.movingPathIndex == lesson.followPathIndex,
          handoff.movingPathGoalFlags == 8_392_960,
          handoff.goalID == -1,
          handoff.goalPriority == 3,
          handoff.successMessage == "Excellent!",
          handoff.movingInstruction
            == "Now destroy 2 more robots. This time they will be moving.",
          handoff.voiceSourceName == "kill1.osf",
          followBot?.handle == 8_200,
          followBot?.storedID == 106,
          followBot?.location == .room(37),
          destroyBot2?.type == 2,
          destroyBot2?.storedID == 106,
          destroyBot2?.definition?.sourceName
            == "RAS1 Light Security Flyer",
          destroyBot2?.instanceName == "DestroyBot2",
          destroyBot2?.flags == 5_121,
          destroyBot2?.location == .room(37),
          destroyBot2?.position
            == .init(
                x: 2_121.0835,
                y: -787.4891,
                z: 2_556.6667
            ),
          destroyBot2?.orientation
            == .init(
                right: .init(
                    x: 0.060_053_87,
                    y: -0.047_255_82,
                    z: -0.997_076
                ),
                up: .init(
                    x: 0.142_230_26,
                    y: 0.989_091_93,
                    z: -0.038_310_897
                ),
                forward: .init(
                    x: 0.988_010_17,
                    y: -0.139_513_64,
                    z: 0.066_12
                )
            ),
          destroyBot1?.type == 2,
          destroyBot1?.storedID == 106,
          destroyBot1?.definition?.sourceName
            == "RAS1 Light Security Flyer",
          destroyBot1?.instanceName == "DestroyBot1",
          destroyBot1?.flags == 5_121,
          destroyBot1?.location == .room(37),
          destroyBot1?.position
            == .init(
                x: 1_998.6289,
                y: -789.663_15,
                z: 2_556.2332
            ),
          destroyBot1?.orientation
            == .init(
                right: .init(
                    x: -0.004_710_059,
                    y: 0.044_023_126,
                    z: 0.999_019_44
                ),
                up: .init(
                    x: -0.180_763_14,
                    y: 0.982_535_3,
                    z: -0.044_148_97
                ),
                forward: .init(
                    x: -0.983_515_4,
                    y: -0.180_793_82,
                    z: 0.003_329_959
                )
            ),
          destroyBot2Presentation?.primaryModel
            == lesson.followBot.model,
          destroyBot2Presentation?.isVisible == false,
          destroyBot1Presentation?.primaryModel
            == lesson.followBot.model,
          destroyBot1Presentation?.isVisible == false,
          projectileModel?.sourceArchive == "d3.hog",
          projectileModel?.collisionRadius == 4.920_813,
          projectileModel?.sourceSHA256
            == "717a9a2ac254eba76c7992fc834e3a5bc3992f86674af972afd9cf0c2967b31b",
          voice?.sourceEntryIndex == 17,
          voice?.sampleRate == 22_050,
          voice?.channelCount == 1,
          voice?.frameCount == 172_565,
          voice?.pcm16LittleEndian.count
            == (voice?.frameCount ?? -1) * 2,
          voice?.pcmSHA256
            == "0b1eae26d812929a08faa05efde07926dc4a96ac3873320b6f39805f69877b06",
          voice?.sourceArchive == "missions/training.mn3",
          voice?.sourceSHA256
            == "d2ea757ac472b40781ce62a7dbd45649e3abce3f4884edf1303048e3cf36be7e"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 031,037,027 stock package"
        )
    }
}

func validateTrainingFollowBotDestructionHandoff(
    _ handoff: TrainingFollowBotDestructionHandoff,
    lesson: TrainingManeuverFollowLesson,
    level: Level
) throws {
    let handles = [
        handoff.followBotObjectHandle,
        handoff.destroyBot2ObjectHandle,
        handoff.destroyBot1ObjectHandle,
    ]
    let objectsByHandle = Dictionary(
        uniqueKeysWithValues: level.objects.map {
            ($0.handle, $0)
        }
    )
    let presentationsByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map {
            ($0.objectHandle, $0)
        }
    )
    guard Set(handles).count == handles.count,
          handoff.followBotObjectHandle
            == lesson.followBotObjectHandle,
          handles.allSatisfy({ objectsByHandle[$0] != nil }),
          handles.allSatisfy({
              presentationsByHandle[$0]?.primaryModel
                == lesson.followBot.model
          }),
          presentationsByHandle[
            handoff.destroyBot2ObjectHandle
          ]?.isVisible == false,
          presentationsByHandle[
            handoff.destroyBot1ObjectHandle
          ]?.isVisible == false,
          handoff.combat == .stockTraining,
          level.models.contains(where: {
              $0.source == handoff.projectileModel
          }),
          handoff.projectileModel.sourceName
            .caseInsensitiveCompare("bluelaser.OOF")
            == .orderedSame,
          handoff.destructionDelay == 2,
          handoff.levelTimerID == 11,
          handoff.movingTeamFlags == 65_536,
          handoff.movingPathIndex == lesson.followPathIndex,
          level.paths.indices.contains(
            handoff.movingPathIndex
          ),
          handoff.movingPathGoalFlags == 8_392_960,
          handoff.goalID == -1,
          handoff.goalPriority == 3,
          handoff.successMessage == "Excellent!",
          handoff.movingInstruction
            == "Now destroy 2 more robots. This time they will be moving.",
          handoff.voiceSourceName == "kill1.osf",
          level.voiceClips.contains(where: {
              $0.sourceName.caseInsensitiveCompare(
                  handoff.voiceSourceName
              ) == .orderedSame
          })
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 031,037,027 handoff"
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
    let expectedPresentation = TrainingMarkerLightPresentation(
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
          level.trainingLastBot1DeathChain != nil,
          level.trainingLastBot2DeathChain != nil,
          level.trainingLastBot3DeathChain != nil,
          level.trainingLastBot4DeathChain != nil,
          level.trainingLastBot5DeathChain != nil,
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
    objectPresentations: [ObjectPresentationReference],
    destroyRobotIsInitiallyVisible: Bool = true
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
                    == destroyRobotIsInitiallyVisible
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

private func validateStockTrainingRASBotDeathPackage(
    chain: TrainingRobotDeathChain?,
    expectedHandle: UInt32,
    expectedRoomSourceIndex: Int,
    expectedInstanceName: String,
    dependencyName: String,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    let gyroModels = Set(
        objectPresentations.compactMap { presentation in
            presentation.primaryModel.sourceName.caseInsensitiveCompare(
                "gyro.oof"
            ) == .orderedSame
                ? presentation.primaryModel
                : nil
        }
    )
    guard let chain,
          chain.robotObjectHandle == expectedHandle,
          chain.robotRoomSourceIndex == expectedRoomSourceIndex,
          chain.robotFlags == 5_121,
          chain.combat == .stockTraining,
          gyroModels.count == 1,
          objects.contains(where: {
              $0.handle == chain.robotObjectHandle
                  && $0.type == 2
                  && $0.storedID == 106
                  && $0.definition?.sourceName
                    == "RAS1 Light Security Flyer"
                  && $0.instanceName == expectedInstanceName
                  && $0.flags == chain.robotFlags
                  && $0.location == .room(chain.robotRoomSourceIndex)
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == chain.robotObjectHandle
                  && $0.primaryModel == gyroModels.first
                  && $0.mediumModel == nil
                  && $0.lowModel == nil
                  && $0.dyingModel == nil
                  && $0.mediumDistance == nil
                  && $0.lowDistance == nil
                  && $0.isVisible
          }) else {
        throw LevelValidationError.invalidDependency(dependencyName)
    }
}

func validateStockTrainingRASBot1DeathPackage(
    chain: TrainingRASBot1DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_074,
        expectedRoomSourceIndex: 11,
        expectedInstanceName: "RASBot1",
        dependencyName: "Training RASBot1 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingRASBot2DeathPackage(
    chain: TrainingRASBot2DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_075,
        expectedRoomSourceIndex: 12,
        expectedInstanceName: "RASBot2",
        dependencyName: "Training RASBot2 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingRASBot3DeathPackage(
    chain: TrainingRASBot3DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_077,
        expectedRoomSourceIndex: 42,
        expectedInstanceName: "RASBot3",
        dependencyName: "Training RASBot3 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingRASBot4DeathPackage(
    chain: TrainingRASBot4DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_078,
        expectedRoomSourceIndex: 0,
        expectedInstanceName: "RASBot4",
        dependencyName: "Training RASBot4 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot1DeathPackage(
    chain: TrainingLastBot1DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 4_127,
        expectedRoomSourceIndex: 14,
        expectedInstanceName: "LastBot1",
        dependencyName: "Training LastBot1 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot2DeathPackage(
    chain: TrainingLastBot2DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_080,
        expectedRoomSourceIndex: 46,
        expectedInstanceName: "LastBot2",
        dependencyName: "Training LastBot2 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot3DeathPackage(
    chain: TrainingLastBot3DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_081,
        expectedRoomSourceIndex: 47,
        expectedInstanceName: "LastBot3",
        dependencyName: "Training LastBot3 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot4DeathPackage(
    chain: TrainingLastBot4DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_082,
        expectedRoomSourceIndex: 47,
        expectedInstanceName: "LastBot4",
        dependencyName: "Training LastBot4 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot5DeathPackage(
    chain: TrainingLastBot5DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_083,
        expectedRoomSourceIndex: 48,
        expectedInstanceName: "LastBot5",
        dependencyName: "Training LastBot5 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
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
