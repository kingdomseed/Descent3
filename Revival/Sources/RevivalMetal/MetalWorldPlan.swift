// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct MetalWorldVertex: Equatable, Sendable {
    let position: SIMD4<Float>
    let textureAndLightmapUV: SIMD4<Float>
    let presentation: SIMD4<Float>
    let surfaceColor: SIMD4<Float>
    let dynamicLight: SIMD4<Float>
}

struct MetalWorldDraw: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let objectHandle: UInt32?
    let model: SourceResource?
    let submodelIndex: Int?
    let texture: SourceResource?
    let sourceColor: SIMD3<Float>?
    let blend: PresentationBlend
    let writesDepth: Bool
    let lightmapBlend: PresentationLightmapBlend
    let lightmapPageIndex: Int?
    let vertices: [MetalWorldVertex]
    let indices: [UInt32]
}

struct MetalPresentationFrame: Equatable, Sendable {
    let systemsFrameDuration: Float
    let systemsGameTime: Float

    var visualTick: Int {
        max(0, Int(floor(systemsGameTime * 60)))
    }
}

struct MetalLightCoronaState: Equatable, Sendable {
    let corona: WorldLightCorona
    let scalar: Float
}

struct MetalLightCoronaDraw: Equatable, Sendable {
    let corona: WorldLightCorona
    let opacity: Float
}

struct MetalWorldPlan: Equatable, Sendable {
    let level: Level
    let camera: RoomCamera
    let startRoomSourceIndex: Int
    let excludedObjectHandle: UInt32?
    let visibleRoomSourceIndices: [Int]
    let preparedLightCoronaCandidates: [WorldLightCorona]
    let lightCoronaStates: [MetalLightCoronaState]
    let lightCoronaDraws: [MetalLightCoronaDraw]
    let presentationVisualTick: Int
    let preparedDraws: [MetalWorldDraw]
    let activeDrawIndices: [Int]
    let draws: [MetalWorldDraw]
    let auxiliaryCamera: RoomCamera?
    let auxiliaryStartRoomSourceIndex: Int?
    let auxiliaryActiveDrawIndices: [Int]
    let auxiliaryDraws: [MetalWorldDraw]
}

func makeMetalWorldPlan(
    level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int
) throws -> MetalWorldPlan {
    let extraction = try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex
    )
    return try makeMetalWorldPlan(
        level: level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil,
        extraction: extraction
    )
}

func makeMetalWorldPlan(
    level: Level,
    playerView: PlayerView
) throws -> MetalWorldPlan {
    let extraction = try extractWorldForRendering(level, playerView: playerView)
    return try makeMetalWorldPlan(
        level: level,
        camera: playerView.camera,
        startRoomSourceIndex: playerView.roomSourceIndex,
        excludedObjectHandle: playerView.objectHandle,
        extraction: extraction
    )
}

private func makeMetalWorldPlan(
    level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?,
    extraction: WorldRenderExtraction
) throws -> MetalWorldPlan {
    let opaqueRoomDraws = extraction.opaqueDrawItems.map(makeMetalWorldDraw)
    let translucentRoomDraws = extraction.translucentDrawItems.map(makeMetalWorldDraw)
    let objectDraws = extraction.modelDrawItems.map(makeMetalWorldDraw)
    let preparedRoomDraws = try extractPreparedRoomDrawItems(
        level,
        startRoomSourceIndex: startRoomSourceIndex
    ).map(makeMetalWorldDraw)
    let preparedObjectDraws = extractPreparedModelDrawItems(
        level,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil
    ).map(makeMetalWorldDraw)
    let preparedDodgeProjectileDraws =
        extractPreparedTrainingDodgeProjectileDrawItems(level)
        .map(makeMetalWorldDraw)
    let preparedBlueLaserDraws =
        extractPreparedTrainingBlueLaserDrawItems(level)
        .map(makeMetalWorldDraw)
    let preparedYellowFlareDraws =
        extractPreparedTrainingGuidebotYellowFlareDrawItems(level)
        .map(makeMetalWorldDraw)
    let preparedYellowFlareParticleDraws =
        makePreparedTrainingGuidebotYellowFlareParticleDraws(level)
    let preparedYellowFlareTimeoutExplosionDraws =
        makePreparedTrainingGuidebotYellowFlareTimeoutExplosionDraws(level)
    let preparedYellowFlareTimeoutSparkDraws =
        makePreparedTrainingGuidebotYellowFlareTimeoutSparkDraws(level)
    let preparedYellowFlareTimeoutSparkParticleDraws =
        makePreparedTrainingGuidebotYellowFlareTimeoutSparkParticleDraws(level)
    let preparedRoomIndexByIdentity = Dictionary(
        uniqueKeysWithValues: preparedRoomDraws.enumerated().map {
            (MetalRoomDrawIdentity($0.element), $0.offset)
        }
    )
    let initialRoomDraws = opaqueRoomDraws + translucentRoomDraws
    let initialRoomIndices = initialRoomDraws.map {
        preparedRoomIndexByIdentity[MetalRoomDrawIdentity($0)]!
    }
    let preparedObjectIndexByIdentity = Dictionary(
        uniqueKeysWithValues: preparedObjectDraws.enumerated().map {
            (MetalModelDrawIdentity($0.element), $0.offset)
        }
    )
    let objectOffset = preparedRoomDraws.count
    let activeDrawIndices =
        Array(initialRoomIndices.prefix(opaqueRoomDraws.count))
        + objectDraws.map {
            objectOffset + preparedObjectIndexByIdentity[MetalModelDrawIdentity($0)]!
        }
        + Array(initialRoomIndices.dropFirst(opaqueRoomDraws.count))
    let preparedDraws =
        preparedRoomDraws
        + preparedObjectDraws
        + preparedObjectDraws
        + preparedDodgeProjectileDraws
        + preparedBlueLaserDraws
        + preparedYellowFlareDraws
        + preparedYellowFlareParticleDraws
        + preparedYellowFlareTimeoutExplosionDraws
        + preparedYellowFlareTimeoutSparkDraws
        + preparedYellowFlareTimeoutSparkParticleDraws
    let draws = activeDrawIndices.map { preparedDraws[$0] }
    let lightCoronaStates = extraction.lightCoronas.map {
        MetalLightCoronaState(corona: $0, scalar: 0)
    }
    return MetalWorldPlan(
        level: level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle,
        visibleRoomSourceIndices: extraction.visibleRoomSourceIndices,
        preparedLightCoronaCandidates: extraction.lightCoronas,
        lightCoronaStates: lightCoronaStates,
        lightCoronaDraws: lightCoronaStates.map {
            MetalLightCoronaDraw(corona: $0.corona, opacity: 0)
        },
        presentationVisualTick: 0,
        preparedDraws: preparedDraws,
        activeDrawIndices: Array(activeDrawIndices),
        draws: draws,
        auxiliaryCamera: nil,
        auxiliaryStartRoomSourceIndex: nil,
        auxiliaryActiveDrawIndices: [],
        auxiliaryDraws: []
    )
}

func updateMetalWorldPlan(
    _ prepared: MetalWorldPlan,
    level: Level,
    playerView: PlayerView,
    presentationFrame: MetalPresentationFrame? = nil,
    trainingCameraMonitor: TrainingCameraMonitorFrame? = nil,
    trainingCloak: TrainingCloakFrame? = nil,
    trainingDodgeTurretAngles: [Float] = [],
    trainingDodgeProjectiles: [TrainingDodgeProjectileFrame] = [],
    trainingPrimaryProjectiles:
        [TrainingBlueLaserProjectileFrame] = [],
    trainingGuidebotYellowFlares:
        [TrainingGuidebotYellowFlareFrame] = [],
    trainingGuidebotYellowFlareParticles:
        [TrainingGuidebotYellowFlareParticleFrame] = [],
    trainingGuidebotYellowFlareTimeoutExplosions:
        [TrainingGuidebotYellowFlareParticleFrame] = [],
    trainingGuidebotYellowFlareTimeoutSparks:
        [TrainingGuidebotYellowFlareTimeoutSparkFrame] = [],
    trainingGuidebotYellowFlareTimeoutSparkParticles:
        [TrainingGuidebotYellowFlareParticleFrame] = [],
    trainingDodgeMarkerLightDistance: Float? = nil,
    trainingGuidebotReturnMarkerLightDistance: Float? = nil,
    trainingLastRoomMarkerLightDistance: Float? = nil,
    trainingFinalBotsMarkerLightDistance: Float? = nil
) throws -> MetalWorldPlan {
    try updateMetalWorldPlan(
        prepared,
        level: level,
        camera: playerView.camera,
        startRoomSourceIndex: playerView.roomSourceIndex,
        excludedObjectHandle: playerView.objectHandle,
        presentationFrame: presentationFrame,
        trainingCameraMonitor: trainingCameraMonitor,
        trainingCloak: trainingCloak,
        trainingDodgeTurretAngles: trainingDodgeTurretAngles,
        trainingDodgeProjectiles: trainingDodgeProjectiles,
        trainingPrimaryProjectiles:
            trainingPrimaryProjectiles,
        trainingGuidebotYellowFlares:
            trainingGuidebotYellowFlares,
        trainingGuidebotYellowFlareParticles:
            trainingGuidebotYellowFlareParticles,
        trainingGuidebotYellowFlareTimeoutExplosions:
            trainingGuidebotYellowFlareTimeoutExplosions,
        trainingGuidebotYellowFlareTimeoutSparks:
            trainingGuidebotYellowFlareTimeoutSparks,
        trainingGuidebotYellowFlareTimeoutSparkParticles:
            trainingGuidebotYellowFlareTimeoutSparkParticles,
        trainingDodgeMarkerLightDistance:
            trainingDodgeMarkerLightDistance,
        trainingGuidebotReturnMarkerLightDistance:
            trainingGuidebotReturnMarkerLightDistance,
        trainingLastRoomMarkerLightDistance:
            trainingLastRoomMarkerLightDistance,
        trainingFinalBotsMarkerLightDistance:
            trainingFinalBotsMarkerLightDistance
    )
}

func updateMetalWorldPlan(
    _ prepared: MetalWorldPlan,
    camera: RoomCamera,
    presentationFrame: MetalPresentationFrame? = nil
) throws -> MetalWorldPlan {
    try updateMetalWorldPlan(
        prepared,
        level: prepared.level,
        camera: camera,
        startRoomSourceIndex: prepared.startRoomSourceIndex,
        excludedObjectHandle: prepared.excludedObjectHandle,
        presentationFrame: presentationFrame,
        trainingCameraMonitor: nil,
        trainingCloak: nil,
        trainingDodgeTurretAngles: [],
        trainingDodgeProjectiles: [],
        trainingPrimaryProjectiles: [],
        trainingGuidebotYellowFlares: [],
        trainingGuidebotYellowFlareParticles: [],
        trainingGuidebotYellowFlareTimeoutExplosions: [],
        trainingGuidebotYellowFlareTimeoutSparks: [],
        trainingGuidebotYellowFlareTimeoutSparkParticles: [],
        trainingDodgeMarkerLightDistance: nil,
        trainingGuidebotReturnMarkerLightDistance: nil,
        trainingLastRoomMarkerLightDistance: nil,
        trainingFinalBotsMarkerLightDistance: nil
    )
}

private func updateMetalWorldPlan(
    _ prepared: MetalWorldPlan,
    level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?,
    presentationFrame: MetalPresentationFrame?,
    trainingCameraMonitor: TrainingCameraMonitorFrame?,
    trainingCloak: TrainingCloakFrame?,
    trainingDodgeTurretAngles: [Float],
    trainingDodgeProjectiles: [TrainingDodgeProjectileFrame],
    trainingPrimaryProjectiles:
        [TrainingBlueLaserProjectileFrame],
    trainingGuidebotYellowFlares:
        [TrainingGuidebotYellowFlareFrame],
    trainingGuidebotYellowFlareParticles:
        [TrainingGuidebotYellowFlareParticleFrame],
    trainingGuidebotYellowFlareTimeoutExplosions:
        [TrainingGuidebotYellowFlareParticleFrame],
    trainingGuidebotYellowFlareTimeoutSparks:
        [TrainingGuidebotYellowFlareTimeoutSparkFrame],
    trainingGuidebotYellowFlareTimeoutSparkParticles:
        [TrainingGuidebotYellowFlareParticleFrame],
    trainingDodgeMarkerLightDistance: Float?,
    trainingGuidebotReturnMarkerLightDistance: Float?,
    trainingLastRoomMarkerLightDistance: Float?,
    trainingFinalBotsMarkerLightDistance: Float?
) throws -> MetalWorldPlan {
    let extraction = try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle,
        presentationGameTime:
            presentationFrame?.systemsGameTime ?? 0,
        trainingDodgeTurretAngles: trainingDodgeTurretAngles
    )
    let opaqueRoomDraws = extraction.opaqueDrawItems.map(makeMetalWorldDraw)
    let translucentRoomDraws = extraction.translucentDrawItems.map(makeMetalWorldDraw)
    let objectDraws = extraction.modelDrawItems.map(makeMetalWorldDraw)
    let dodgeProjectileDraws =
        extractTrainingDodgeProjectileDrawItems(
            level,
            projectiles: trainingDodgeProjectiles,
            camera: camera
        ).map(makeMetalWorldDraw)
    let blueLaserDraws =
        extractTrainingBlueLaserDrawItems(
            level,
            projectiles: trainingPrimaryProjectiles,
            camera: camera
        ).map(makeMetalWorldDraw)
    let yellowFlareDraws =
        extractTrainingGuidebotYellowFlareDrawItems(
            level,
            flares: trainingGuidebotYellowFlares,
            camera: camera
        ).map(makeMetalWorldDraw)
    let yellowFlareParticleDraws =
        makeTrainingGuidebotYellowFlareParticleDraws(
            level,
            particles: trainingGuidebotYellowFlareParticles,
            camera: camera
        )
    let yellowFlareTimeoutExplosionDraws =
        makeTrainingGuidebotYellowFlareQuadDraws(
            level,
            particles: trainingGuidebotYellowFlareTimeoutExplosions,
            camera: camera,
            capacity:
                trainingGuidebotYellowFlareTimeoutExplosionPresentationCapacity,
            handleBase: UInt32.max - 3_000
        )
    let yellowFlareTimeoutSparkDraws =
        makeTrainingGuidebotYellowFlareQuadDraws(
            level,
            particles: trainingGuidebotYellowFlareTimeoutSparks.map {
                .init(
                    roomSourceIndex: $0.roomSourceIndex,
                    position: $0.position,
                    size: $0.collisionRadius,
                    lifeRemaining: $0.lifeRemaining,
                    lifetime:
                        level.trainingRobotGuidebotChain!.yellowFlare!
                            .timeout!.childLifetime,
                    sourceSize: $0.collisionRadius,
                    sourceLifetime:
                        level.trainingRobotGuidebotChain!.yellowFlare!
                            .timeout!.childLifetime,
                    texture: $0.texture
                )
            },
            camera: camera,
            capacity:
                trainingGuidebotYellowFlareTimeoutSparkPresentationCapacity,
            handleBase: UInt32.max - 4_000
        )
    let yellowFlareTimeoutSparkParticleDraws =
        makeTrainingGuidebotYellowFlareQuadDraws(
            level,
            particles:
                trainingGuidebotYellowFlareTimeoutSparkParticles,
            camera: camera,
            capacity:
                trainingGuidebotYellowFlareTimeoutSparkParticlePresentationCapacity,
            handleBase: UInt32.max - 5_000
        )
    let roomIndexByIdentity = Dictionary(
        uniqueKeysWithValues: prepared.preparedDraws.enumerated()
            .filter { $0.element.objectHandle == nil }
            .map { (MetalRoomDrawIdentity($0.element), $0.offset) }
    )
    let objectIndicesByIdentity = Dictionary(
        grouping: prepared.preparedDraws.enumerated()
            .filter { $0.element.objectHandle != nil },
        by: { MetalModelDrawIdentity($0.element) }
    )
    let opaqueIndices = opaqueRoomDraws.map {
        roomIndexByIdentity[MetalRoomDrawIdentity($0)]!
    }
    let objectIndices = objectDraws.map {
        objectIndicesByIdentity[MetalModelDrawIdentity($0)]!.first!.offset
    }
    let dodgeProjectileIndices = dodgeProjectileDraws.map {
        objectIndicesByIdentity[MetalModelDrawIdentity($0)]!.first!.offset
    }
    let blueLaserIndices = blueLaserDraws.map {
        objectIndicesByIdentity[
            MetalModelDrawIdentity($0)
        ]!.first!.offset
    }
    let yellowFlareIndices = yellowFlareDraws.map {
        objectIndicesByIdentity[
            MetalModelDrawIdentity($0)
        ]!.first!.offset
    }
    let yellowFlareParticleIndices =
        yellowFlareParticleDraws.map {
            objectIndicesByIdentity[
                MetalModelDrawIdentity($0)
            ]!.first!.offset
        }
    let yellowFlareTimeoutExplosionIndices =
        yellowFlareTimeoutExplosionDraws.map {
            objectIndicesByIdentity[
                MetalModelDrawIdentity($0)
            ]!.first!.offset
        }
    let yellowFlareTimeoutSparkIndices =
        yellowFlareTimeoutSparkDraws.map {
            objectIndicesByIdentity[
                MetalModelDrawIdentity($0)
            ]!.first!.offset
        }
    let yellowFlareTimeoutSparkParticleIndices =
        yellowFlareTimeoutSparkParticleDraws.map {
            objectIndicesByIdentity[
                MetalModelDrawIdentity($0)
            ]!.first!.offset
        }
    var updatedPreparedDraws = prepared.preparedDraws
    let translucentIndices = translucentRoomDraws.map {
        roomIndexByIdentity[MetalRoomDrawIdentity($0)]!
    }
    let activeDrawIndices = opaqueIndices + objectIndices
        + dodgeProjectileIndices + blueLaserIndices
        + yellowFlareIndices + yellowFlareParticleIndices
        + yellowFlareTimeoutExplosionIndices
        + yellowFlareTimeoutSparkIndices
        + yellowFlareTimeoutSparkParticleIndices
        + translucentIndices
    let auxiliaryExtraction = try trainingCameraMonitor.map {
        try extractWorldForRendering(
            level,
            camera: $0.camera,
            startRoomSourceIndex: $0.roomSourceIndex,
            excludedObjectHandle:
                level.trainingCameraMonitorChain?
                    .securityCameraObjectHandle,
            presentationGameTime:
                presentationFrame?.systemsGameTime ?? 0,
            trainingDodgeTurretAngles:
                trainingDodgeTurretAngles
        )
    }
    let auxiliaryOpaque = auxiliaryExtraction?.opaqueDrawItems
        .map(makeMetalWorldDraw) ?? []
    let auxiliaryObjects: [MetalWorldDraw] =
        (auxiliaryExtraction?.modelDrawItems ?? [])
        .map(makeMetalWorldDraw)
        .map { draw in
            guard draw.objectHandle == excludedObjectHandle,
                let trainingCloak,
                let player = level.objects.first(where: {
                    $0.handle == excludedObjectHandle
                })
            else {
                return draw
            }
            return applyingObjectCloak(
                to: draw,
                alpha: trainingCloak.objectAlpha,
                deformationRange:
                    trainingCloak.objectDeformationRange,
                center: player.position,
                visualTick:
                    presentationFrame?.visualTick ?? 0
            )
        }
    let auxiliaryTranslucent =
        auxiliaryExtraction?.translucentDrawItems
            .map(makeMetalWorldDraw) ?? []
    let auxiliaryObjectIndices = auxiliaryObjects.map {
        objectIndicesByIdentity[MetalModelDrawIdentity($0)]!.last!.offset
    }
    let auxiliaryOpaqueIndices = auxiliaryOpaque.map {
        roomIndexByIdentity[MetalRoomDrawIdentity($0)]!
    }
    let auxiliaryTranslucentIndices = auxiliaryTranslucent.map {
        roomIndexByIdentity[MetalRoomDrawIdentity($0)]!
    }
    let auxiliaryActiveDrawIndices =
        auxiliaryOpaqueIndices
        + auxiliaryObjectIndices
        + auxiliaryTranslucentIndices
    for (index, draw) in zip(objectIndices, objectDraws) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(opaqueIndices, opaqueRoomDraws) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        dodgeProjectileIndices,
        dodgeProjectileDraws
    ) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        blueLaserIndices,
        blueLaserDraws
    ) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        yellowFlareIndices,
        yellowFlareDraws
    ) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        yellowFlareParticleIndices,
        yellowFlareParticleDraws
    ) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        yellowFlareTimeoutExplosionIndices,
        yellowFlareTimeoutExplosionDraws
    ) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        yellowFlareTimeoutSparkIndices,
        yellowFlareTimeoutSparkDraws
    ) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        yellowFlareTimeoutSparkParticleIndices,
        yellowFlareTimeoutSparkParticleDraws
    ) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(translucentIndices, translucentRoomDraws) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(auxiliaryObjectIndices, auxiliaryObjects) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(auxiliaryOpaqueIndices, auxiliaryOpaque) {
        updatedPreparedDraws[index] = draw
    }
    for (index, draw) in zip(
        auxiliaryTranslucentIndices,
        auxiliaryTranslucent
    ) {
        updatedPreparedDraws[index] = draw
    }
    if let distance = trainingDodgeMarkerLightDistance,
        distance > 0,
        let dodge = level.trainingDodgeAttempt,
        let marker = level.objects.first(where: {
            $0.handle == dodge.flashLightObjectHandle
        }),
        let gameTime = presentationFrame?.systemsGameTime
    {
        let light = sourceTrainingMarkerLight(
            dodge.markerLightPresentation,
            gameTime: gameTime
        )
        if light.distanceScale > 0 {
            for index in Set(
                activeDrawIndices + auxiliaryActiveDrawIndices
            ) {
                updatedPreparedDraws[index] =
                    applyingTrainingMarkerLight(
                        to: updatedPreparedDraws[index],
                        position: marker.position,
                        distance: distance * light.distanceScale,
                        color: light.color
                    )
            }
        }
    }
    if let distance = trainingGuidebotReturnMarkerLightDistance,
       distance > 0,
       let returnChain =
            level.trainingCameraMonitorChain?.returnToShip,
       let presentation = returnChain.markerLightPresentation,
       let marker = level.objects.first(where: {
           $0.handle == returnChain.markerLightObjectHandle
       }),
       let gameTime = presentationFrame?.systemsGameTime {
        let light = sourceTrainingMarkerLight(
            presentation,
            gameTime: gameTime
        )
        if light.distanceScale > 0 {
            for index in Set(
                activeDrawIndices + auxiliaryActiveDrawIndices
            ) {
                updatedPreparedDraws[index] =
                    applyingTrainingMarkerLight(
                        to: updatedPreparedDraws[index],
                        position: marker.position,
                        distance: distance * light.distanceScale,
                        color: light.color
                    )
            }
        }
    }
    if let distance = trainingLastRoomMarkerLightDistance,
       distance > 0,
       let chain = level.trainingLastRoomChain,
       let marker = level.objects.first(where: {
           $0.handle == chain.markerLightObjectHandle
       }),
       let gameTime = presentationFrame?.systemsGameTime {
        let light = sourceTrainingMarkerLight(
            chain.markerLightPresentation,
            gameTime: gameTime
        )
        if light.distanceScale > 0 {
            for index in Set(
                activeDrawIndices + auxiliaryActiveDrawIndices
            ) {
                updatedPreparedDraws[index] =
                    applyingTrainingMarkerLight(
                        to: updatedPreparedDraws[index],
                        position: marker.position,
                        distance: distance * light.distanceScale,
                        color: light.color
                    )
            }
        }
    }
    if let distance = trainingFinalBotsMarkerLightDistance,
       distance > 0,
       let chain = level.trainingFinalBotsCompletionChain,
       let marker = level.objects.first(where: {
           $0.handle == chain.markerLightObjectHandle
       }),
       let gameTime = presentationFrame?.systemsGameTime {
        let light = sourceTrainingMarkerLight(
            chain.markerLightPresentation,
            gameTime: gameTime
        )
        if light.distanceScale > 0 {
            for index in Set(
                activeDrawIndices + auxiliaryActiveDrawIndices
            ) {
                updatedPreparedDraws[index] =
                    applyingTrainingMarkerLight(
                        to: updatedPreparedDraws[index],
                        position: marker.position,
                        distance: distance * light.distanceScale,
                        color: light.color
                    )
            }
        }
    }
    for flare in trainingGuidebotYellowFlares
    where flare.lightDistance > 0 {
        let color = SIMD3<Float>(
            flare.lightPresentation.primaryColor.x,
            flare.lightPresentation.primaryColor.y,
            flare.lightPresentation.primaryColor.z
        )
        for index in Set(
            activeDrawIndices + auxiliaryActiveDrawIndices
        ) {
            updatedPreparedDraws[index] =
                applyingTrainingMarkerLight(
                    to: updatedPreparedDraws[index],
                    position: flare.position,
                    distance: flare.lightDistance,
                    color: color
                )
        }
    }
    for spark in trainingGuidebotYellowFlareTimeoutSparks
    where spark.lightDistance > 0 {
        let color = SIMD3<Float>(
            spark.lightPresentation.primaryColor.x,
            spark.lightPresentation.primaryColor.y,
            spark.lightPresentation.primaryColor.z
        )
        for index in Set(
            activeDrawIndices + auxiliaryActiveDrawIndices
        ) {
            updatedPreparedDraws[index] = applyingTrainingMarkerLight(
                to: updatedPreparedDraws[index],
                position: spark.position,
                distance: spark.lightDistance,
                color: color
            )
        }
    }
    let coronaPresentation = presentationFrame.map {
        advanceLightCoronas(
            prepared.lightCoronaStates,
            candidates: extraction.lightCoronas,
            camera: camera,
            frameDuration: $0.systemsFrameDuration
        )
    }
    return MetalWorldPlan(
        level: level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle,
        visibleRoomSourceIndices: extraction.visibleRoomSourceIndices,
        preparedLightCoronaCandidates: prepared.preparedLightCoronaCandidates,
        lightCoronaStates: coronaPresentation?.states
            ?? prepared.lightCoronaStates,
        lightCoronaDraws: coronaPresentation?.draws
            ?? prepared.lightCoronaDraws,
        presentationVisualTick: presentationFrame?.visualTick
            ?? prepared.presentationVisualTick,
        preparedDraws: updatedPreparedDraws,
        activeDrawIndices: activeDrawIndices,
        draws: activeDrawIndices.map { updatedPreparedDraws[$0] },
        auxiliaryCamera: trainingCameraMonitor?.camera,
        auxiliaryStartRoomSourceIndex:
            trainingCameraMonitor?.roomSourceIndex,
        auxiliaryActiveDrawIndices: auxiliaryActiveDrawIndices,
        auxiliaryDraws: auxiliaryActiveDrawIndices.map {
            updatedPreparedDraws[$0]
        }
    )
}

private func applyingObjectCloak(
    to draw: MetalWorldDraw,
    alpha: Float,
    deformationRange: Float,
    center: Vector3,
    visualTick: Int
) -> MetalWorldDraw {
    precondition(alpha.isFinite && (0...1).contains(alpha))
    precondition(
        deformationRange.isFinite
            && (0...0.1).contains(deformationRange)
    )
    let opacity = UInt8((alpha * 255).rounded())
    return MetalWorldDraw(
        roomSourceIndex: draw.roomSourceIndex,
        faceIndex: draw.faceIndex,
        objectHandle: draw.objectHandle,
        model: draw.model,
        submodelIndex: draw.submodelIndex,
        texture: draw.texture,
        sourceColor: draw.sourceColor,
        blend: .sourceAlpha(opacity: opacity),
        writesDepth: draw.writesDepth,
        lightmapBlend: draw.lightmapBlend,
        lightmapPageIndex: draw.lightmapPageIndex,
        vertices: draw.vertices.enumerated().map {
            vertexIndex, vertex in
            let seed =
                UInt32(truncatingIfNeeded: vertexIndex)
                &* 1_103_515_245
                &+ UInt32(truncatingIfNeeded: visualTick)
                &* 12_345
            let sourceVariation =
                (Float(Int(seed % 1_000)) - 500) / 500
            let scale =
                1 + deformationRange * sourceVariation
            let deformedPosition = SIMD4<Float>(
                center.x + (vertex.position.x - center.x) * scale,
                center.y + (vertex.position.y - center.y) * scale,
                center.z + (vertex.position.z - center.z) * scale,
                vertex.position.w
            )
            return MetalWorldVertex(
                position: deformedPosition,
                textureAndLightmapUV: vertex.textureAndLightmapUV,
                presentation: SIMD4<Float>(
                    alpha,
                    vertex.presentation.y,
                    vertex.presentation.z,
                    vertex.presentation.w
                ),
                surfaceColor: vertex.surfaceColor,
                dynamicLight: vertex.dynamicLight
            )
        },
        indices: draw.indices
    )
}

private func sourceTrainingMarkerLight(
    _ presentation: TrainingMarkerLightPresentation,
    gameTime: Float
) -> (color: SIMD3<Float>, distanceScale: Float) {
    let primary = SIMD3<Float>(
        presentation.primaryColor.x,
        presentation.primaryColor.y,
        presentation.primaryColor.z
    )
    let secondary = SIMD3<Float>(
        presentation.secondaryColor.x,
        presentation.secondaryColor.y,
        presentation.secondaryColor.z
    )
    guard presentation.timeInterval > 0 else {
        return (primary, 1)
    }
    let period = presentation.timeInterval
    let cycle = Int(gameTime / (period * 2))
    let elapsed = gameTime - Float(cycle) * period * 2
    var normalizedTime = elapsed / period
    if presentation.flags & 0x02 != 0 {
        let slice = min(7, max(0, Int(elapsed / (period / 8))))
        guard presentation.timebits & (1 << UInt32(slice)) != 0
        else {
            return (.zero, 0)
        }
    }
    if presentation.flags & 0x08 != 0 {
        if normalizedTime > 1 {
            normalizedTime -= 1
            return (
                secondary * (1 - normalizedTime)
                    + primary * normalizedTime,
                1
            )
        }
        return (
            primary * (1 - normalizedTime)
                + secondary * normalizedTime,
            1
        )
    }
    if presentation.flags & 0x04 != 0 {
        let scalar = normalizedTime > 1
            ? 1 - (normalizedTime - 1)
            : normalizedTime
        return (primary, max(
            0,
            presentation.flickerDistance
                + scalar * (1 - presentation.flickerDistance)
        ))
    }
    return (primary, 1)
}

private func applyingTrainingMarkerLight(
    to draw: MetalWorldDraw,
    position: Vector3,
    distance: Float,
    color: SIMD3<Float>
) -> MetalWorldDraw {
    let vertices = draw.vertices.map { vertex in
        let delta = SIMD3<Float>(
            vertex.position.x - position.x,
            vertex.position.y - position.y,
            vertex.position.z - position.z
        )
        let vertexDistance = sqrt(
            delta.x * delta.x
                + delta.y * delta.y
                + delta.z * delta.z
        )
        let scalar = max(0, 1 - vertexDistance / distance)
        return MetalWorldVertex(
            position: vertex.position,
            textureAndLightmapUV: vertex.textureAndLightmapUV,
            presentation: vertex.presentation,
            surfaceColor: vertex.surfaceColor,
            dynamicLight: SIMD4<Float>(
                SIMD3<Float>(
                    vertex.dynamicLight.x,
                    vertex.dynamicLight.y,
                    vertex.dynamicLight.z
                ) + color * scalar,
                0
            )
        )
    }
    return MetalWorldDraw(
        roomSourceIndex: draw.roomSourceIndex,
        faceIndex: draw.faceIndex,
        objectHandle: draw.objectHandle,
        model: draw.model,
        submodelIndex: draw.submodelIndex,
        texture: draw.texture,
        sourceColor: draw.sourceColor,
        blend: draw.blend,
        writesDepth: draw.writesDepth,
        lightmapBlend: draw.lightmapBlend,
        lightmapPageIndex: draw.lightmapPageIndex,
        vertices: vertices,
        indices: draw.indices
    )
}

private func advanceLightCoronas(
    _ previous: [MetalLightCoronaState],
    candidates: [WorldLightCorona],
    camera: RoomCamera,
    frameDuration: Float
) -> (states: [MetalLightCoronaState], draws: [MetalLightCoronaDraw]) {
    struct Identity: Hashable {
        let roomSourceIndex: Int
        let faceIndex: Int
    }
    var candidateByIdentity: [Identity: WorldLightCorona] = [:]
    for candidate in candidates {
        candidateByIdentity[
            Identity(
                roomSourceIndex: candidate.roomSourceIndex,
                faceIndex: candidate.faceIndex
            )
        ] = candidate
    }
    var states = previous.map { state in
        let identity = Identity(
            roomSourceIndex: state.corona.roomSourceIndex,
            faceIndex: state.corona.faceIndex
        )
        return MetalLightCoronaState(
            corona: candidateByIdentity[identity] ?? state.corona,
            scalar: state.scalar
        )
    }
    let existing = Set(states.map {
        Identity(
            roomSourceIndex: $0.corona.roomSourceIndex,
            faceIndex: $0.corona.faceIndex
        )
    })
    states += candidates.filter {
        !existing.contains(
            Identity(
                roomSourceIndex: $0.roomSourceIndex,
                faceIndex: $0.faceIndex
            )
        )
    }.map {
        MetalLightCoronaState(corona: $0, scalar: 0)
    }

    let draws = states.map { state in
        MetalLightCoronaDraw(
            corona: state.corona,
            opacity: sourceLightCoronaOpacity(
                state.corona,
                camera: camera,
                scalar: state.scalar
            )
        )
    }
    let step = max(0, frameDuration) * 4
    states = states.compactMap { state in
        let identity = Identity(
            roomSourceIndex: state.corona.roomSourceIndex,
            faceIndex: state.corona.faceIndex
        )
        let nextScalar = candidateByIdentity[identity] == nil
            ? state.scalar - step
            : min(1, state.scalar + step)
        guard nextScalar >= 0 else { return nil }
        return MetalLightCoronaState(
            corona: state.corona,
            scalar: nextScalar
        )
    }
    return (states, draws)
}

private func sourceLightCoronaOpacity(
    _ corona: WorldLightCorona,
    camera: RoomCamera,
    scalar: Float
) -> Float {
    var toEye = subtract(camera.position, corona.firstVertex)
    let toEyeLength = sqrt(dot3(toEye, toEye))
    guard toEyeLength > 0 else { return 0 }
    toEye = Vector3(
        x: toEye.x / toEyeLength,
        y: toEye.y / toEyeLength,
        z: toEye.z / toEyeLength
    )
    var scale = dot3(toEye, corona.normal) * 2
    guard scale >= 0 else { return 0 }

    let offset = subtract(corona.center, camera.position)
    let distance = sqrt(dot3(offset, offset))
    guard distance >= corona.size * 5 else { return 0 }
    if distance < corona.size * 20 {
        scale *= (distance - corona.size * 5) / (corona.size * 15)
    }
    scale = min(scale * scalar, 1)
    let sourceOpacity: Float
    switch corona.blend {
    case .opaque:
        sourceOpacity = 1
    case let .sourceAlpha(opacity), let .additiveSourceAlpha(opacity):
        sourceOpacity = Float(opacity) / 255
    }
    return max(0, scale * sourceOpacity)
}

private func subtract(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func dot3(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

func makeMetalLightCoronaVertices(
    _ corona: WorldLightCorona,
    camera: RoomCamera,
    imageWidth: Int,
    imageHeight: Int,
    opacity: Float
) -> [MetalWorldVertex] {
    let forward = normalized(subtract(camera.target, camera.position))
    let right = normalized(cross3(forward, camera.up))
    let up = normalized(cross3(right, forward))
    let halfWidth = corona.size
    let halfHeight = corona.size * Float(imageHeight) / Float(imageWidth)
    let rightExtent = multiplied(right, halfWidth)
    let upExtent = multiplied(up, halfHeight)
    let positions = [
        added(subtract(corona.center, rightExtent), upExtent),
        added(added(corona.center, rightExtent), upExtent),
        subtract(added(corona.center, rightExtent), upExtent),
        subtract(subtract(corona.center, rightExtent), upExtent),
    ]
    let uvs = [
        SIMD4<Float>(0, 0, 0, 0),
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(1, 1, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
    ]
    let maximumTint = max(corona.tint.x, corona.tint.y, corona.tint.z)
    let divisor = max(1, maximumTint)
    let tint = SIMD4<Float>(
        corona.tint.x / divisor,
        corona.tint.y / divisor,
        corona.tint.z / divisor,
        0
    )
    return positions.indices.map { index in
        MetalWorldVertex(
            position: SIMD4<Float>(
                positions[index].x,
                positions[index].y,
                positions[index].z,
                1
            ),
            textureAndLightmapUV: uvs[index],
            presentation: SIMD4<Float>(opacity, 0, 1, 0),
            surfaceColor: tint,
            dynamicLight: .zero
        )
    }
}

private func normalized(_ vector: Vector3) -> Vector3 {
    let length = sqrt(dot3(vector, vector))
    precondition(length > 0)
    return multiplied(vector, 1 / length)
}

private func cross3(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}

private func multiplied(_ vector: Vector3, _ scalar: Float) -> Vector3 {
    Vector3(x: vector.x * scalar, y: vector.y * scalar, z: vector.z * scalar)
}

private func added(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private struct MetalRoomDrawIdentity: Hashable {
    let roomSourceIndex: Int
    let faceIndex: Int

    init(_ draw: MetalWorldDraw) {
        roomSourceIndex = draw.roomSourceIndex
        faceIndex = draw.faceIndex
    }
}

private struct MetalModelDrawIdentity: Hashable {
    let objectHandle: UInt32
    let model: SourceResource?
    let texture: SourceResource?
    let submodelIndex: Int?
    let faceIndex: Int

    init(_ draw: MetalWorldDraw) {
        objectHandle = draw.objectHandle!
        model = draw.model
        texture = draw.texture
        submodelIndex = draw.submodelIndex
        faceIndex = draw.faceIndex
    }
}

private func makeMetalWorldDraw(_ item: RoomDrawItem) -> MetalWorldDraw {
    let blendOpacity: Float
    switch item.blend {
    case .opaque:
        blendOpacity = 1
    case let .sourceAlpha(opacity):
        blendOpacity = Float(opacity) / 255
    case let .additiveSourceAlpha(opacity):
        blendOpacity = Float(opacity) / 255
    }
    let writesDepth: Bool
    switch item.blend {
    case .additiveSourceAlpha:
        writesDepth = false
    case .opaque, .sourceAlpha:
        writesDepth = true
    }
    return MetalWorldDraw(
        roomSourceIndex: item.roomSourceIndex,
        faceIndex: item.faceIndex,
        objectHandle: nil,
        model: nil,
        submodelIndex: nil,
        texture: item.texture,
        sourceColor: nil,
        blend: item.blend,
        writesDepth: writesDepth,
        lightmapBlend: item.lightmapBlend,
        lightmapPageIndex: item.lightmapPageIndex,
        vertices: item.vertices.map {
            MetalWorldVertex(
                position: SIMD4<Float>($0.position.x, $0.position.y, $0.position.z, 1),
                textureAndLightmapUV: SIMD4<Float>(
                    $0.u,
                    $0.v,
                    $0.lightmapU,
                    $0.lightmapV
                ),
                presentation: SIMD4<Float>(
                    blendOpacity,
                    $0.alpha,
                    0,
                    0
                ),
                surfaceColor: SIMD4<Float>(1, 1, 1, 0),
                dynamicLight: .zero
            )
        },
        indices: item.triangleIndices
    )
}

private func makeMetalWorldDraw(_ item: ModelDrawItem) -> MetalWorldDraw {
    let blendOpacity: Float
    switch item.blend {
    case .opaque:
        blendOpacity = 1
    case let .sourceAlpha(opacity), let .additiveSourceAlpha(opacity):
        blendOpacity = Float(opacity) / 255
    }
    let texture: SourceResource?
    let sourceColor: SIMD3<Float>?
    switch item.material {
    case let .texture(source):
        texture = source
        sourceColor = nil
    case let .sourceColor(red, green, blue):
        texture = nil
        sourceColor = SIMD3<Float>(
            Float(red) / 255,
            Float(green) / 255,
            Float(blue) / 255
        )
    }
    return MetalWorldDraw(
        roomSourceIndex: item.roomSourceIndex,
        faceIndex: item.faceIndex,
        objectHandle: item.objectHandle,
        model: item.model,
        submodelIndex: item.submodelIndex,
        texture: texture,
        sourceColor: sourceColor,
        blend: item.blend,
        writesDepth: true,
        lightmapBlend: .none,
        lightmapPageIndex: nil,
        vertices: item.vertices.map {
            MetalWorldVertex(
                position: SIMD4<Float>($0.position.x, $0.position.y, $0.position.z, 1),
                textureAndLightmapUV: SIMD4<Float>($0.u, $0.v, 0, 0),
                presentation: SIMD4<Float>(blendOpacity, $0.alpha, 0, 0),
                surfaceColor: sourceColor.map {
                    SIMD4<Float>($0.x, $0.y, $0.z, 1)
                } ?? SIMD4<Float>(1, 1, 1, 0),
                dynamicLight: .zero
            )
        },
        indices: item.triangleIndices
    )
}

private func makePreparedTrainingGuidebotYellowFlareParticleDraws(
    _ level: Level
) -> [MetalWorldDraw] {
    guard let definition =
            level.trainingRobotGuidebotChain?.yellowFlare,
          let guidebot = level.objects.first(where: {
              $0.handle
                == level.trainingRobotGuidebotChain?
                    .guidebotObjectHandle
          }),
          case let .room(roomSourceIndex) = guidebot.location
    else {
        return []
    }
    return makeTrainingGuidebotYellowFlareParticleDraws(
        level,
        particles:
            (0..<trainingGuidebotYellowFlareParticlePresentationCapacity)
                .map { _ in .init(
                    roomSourceIndex: roomSourceIndex,
                    position: guidebot.position,
                    size: definition.particleSize,
                    lifeRemaining: definition.particleLifetime,
                    lifetime: definition.particleLifetime,
                    sourceSize: definition.particleSize,
                    sourceLifetime: definition.particleLifetime,
                    texture: definition.particleTexture
                ) },
        camera: .trainingRoom3
    )
}

private func makePreparedTrainingGuidebotYellowFlareTimeoutExplosionDraws(
    _ level: Level
) -> [MetalWorldDraw] {
    makePreparedTrainingGuidebotYellowFlareTimeoutQuadDraws(
        level,
        count: trainingGuidebotYellowFlareTimeoutExplosionPresentationCapacity,
        texture: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .explosionTexture,
        size: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .explosionSize,
        lifetime: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .explosionLifetime,
        handleBase: UInt32.max - 3_000
    )
}

private func makePreparedTrainingGuidebotYellowFlareTimeoutSparkDraws(
    _ level: Level
) -> [MetalWorldDraw] {
    makePreparedTrainingGuidebotYellowFlareTimeoutQuadDraws(
        level,
        count: trainingGuidebotYellowFlareTimeoutSparkPresentationCapacity,
        texture: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .childTexture,
        size: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .childCollisionRadius,
        lifetime: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .childLifetime,
        handleBase: UInt32.max - 4_000
    )
}

private func makePreparedTrainingGuidebotYellowFlareTimeoutSparkParticleDraws(
    _ level: Level
) -> [MetalWorldDraw] {
    makePreparedTrainingGuidebotYellowFlareTimeoutQuadDraws(
        level,
        count:
            trainingGuidebotYellowFlareTimeoutSparkParticlePresentationCapacity,
        texture: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .childTexture,
        size: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .childParticleSize,
        lifetime: level.trainingRobotGuidebotChain?.yellowFlare?.timeout?
            .childParticleLifetime,
        handleBase: UInt32.max - 5_000
    )
}

private func makePreparedTrainingGuidebotYellowFlareTimeoutQuadDraws(
    _ level: Level,
    count: Int,
    texture: SourceResource?,
    size: Float?,
    lifetime: Float?,
    handleBase: UInt32
) -> [MetalWorldDraw] {
    guard let texture, let size, let lifetime,
          let guidebot = level.objects.first(where: {
              $0.handle
                == level.trainingRobotGuidebotChain?
                    .guidebotObjectHandle
          }),
          case let .room(roomSourceIndex) = guidebot.location else {
        return []
    }
    return makeTrainingGuidebotYellowFlareQuadDraws(
        level,
        particles: (0..<count).map { _ in .init(
            roomSourceIndex: roomSourceIndex,
            position: guidebot.position,
            size: size,
            lifeRemaining: lifetime,
            lifetime: lifetime,
            sourceSize: size,
            sourceLifetime: lifetime,
            texture: texture
        ) },
        camera: .trainingRoom3,
        capacity: count,
        handleBase: handleBase
    )
}

private func makeTrainingGuidebotYellowFlareParticleDraws(
    _ level: Level,
    particles: [TrainingGuidebotYellowFlareParticleFrame],
    camera: RoomCamera
) -> [MetalWorldDraw] {
    makeTrainingGuidebotYellowFlareQuadDraws(
        level,
        particles: particles,
        camera: camera,
        capacity: trainingGuidebotYellowFlareParticlePresentationCapacity,
        handleBase: UInt32.max - 2_000
    )
}

private func makeTrainingGuidebotYellowFlareQuadDraws(
    _ level: Level,
    particles: [TrainingGuidebotYellowFlareParticleFrame],
    camera: RoomCamera,
    capacity: Int,
    handleBase: UInt32
) -> [MetalWorldDraw] {
    precondition(particles.count <= capacity)
    let cameraForward = normalized(
        subtract(camera.target, camera.position)
    )
    let right = normalized(cross3(cameraForward, camera.up))
    let up = normalized(cross3(right, cameraForward))
    return particles.enumerated().map { slot, particle in
        let material = level.presentationMaterials.first {
            $0.texture == particle.texture
        }!
        let blendOpacity: Float
        switch material.blend {
        case .opaque:
            blendOpacity = 1
        case let .sourceAlpha(opacity),
             let .additiveSourceAlpha(opacity):
            blendOpacity = Float(opacity) / 255
        }
        let rightExtent = multiplied(right, particle.size)
        let aspect = Float(material.image.height)
            / Float(material.image.width)
        let upExtent = multiplied(up, particle.size * aspect)
        let positions = [
            added(subtract(particle.position, rightExtent), upExtent),
            added(added(particle.position, rightExtent), upExtent),
            subtract(added(particle.position, rightExtent), upExtent),
            subtract(subtract(particle.position, rightExtent), upExtent),
        ]
        let uvs = [
            SIMD4<Float>(0, 0, 0, 0),
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(1, 1, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
        ]
        let opacity = blendOpacity
            * max(0, min(1, particle.lifeRemaining / particle.lifetime))
        return MetalWorldDraw(
            roomSourceIndex: particle.roomSourceIndex,
            faceIndex: 0,
            objectHandle: handleBase - UInt32(slot),
            model: nil,
            submodelIndex: nil,
            texture: particle.texture,
            sourceColor: nil,
            blend: material.blend,
            writesDepth: false,
            lightmapBlend: .none,
            lightmapPageIndex: nil,
            vertices: positions.indices.map { index in
                MetalWorldVertex(
                    position: SIMD4<Float>(
                        positions[index].x,
                        positions[index].y,
                        positions[index].z,
                        1
                    ),
                    textureAndLightmapUV: uvs[index],
                    presentation: SIMD4<Float>(opacity, 0, 0, 0),
                    surfaceColor: SIMD4<Float>(1, 1, 1, 0),
                    dynamicLight: .zero
                )
            },
            indices: [0, 1, 2, 0, 2, 3]
        )
    }
}
