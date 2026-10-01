import Foundation

func validateStockTrainingRobotGuidebotPackage(
    chain: TrainingRobotGuidebotChain?,
    guidebotB: CanonicalVoiceClip?,
    proceed5: CanonicalVoiceClip?,
    releaseSound: CanonicalSoundClip? = nil,
    ambientEngineSound: CanonicalSoundClip? = nil
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
