// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct MetalWorldVertex: Equatable, Sendable {
    let position: SIMD4<Float>
    let textureAndLightmapUV: SIMD4<Float>
    let presentation: SIMD4<Float>
    let surfaceColor: SIMD4<Float>
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
        excludedObjectHandle: excludedObjectHandle
    ).map(makeMetalWorldDraw)
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
    let preparedDraws = preparedRoomDraws + preparedObjectDraws
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
        draws: draws
    )
}

func updateMetalWorldPlan(
    _ prepared: MetalWorldPlan,
    level: Level,
    playerView: PlayerView,
    presentationFrame: MetalPresentationFrame? = nil
) throws -> MetalWorldPlan {
    try updateMetalWorldPlan(
        prepared,
        level: level,
        camera: playerView.camera,
        startRoomSourceIndex: playerView.roomSourceIndex,
        excludedObjectHandle: playerView.objectHandle,
        presentationFrame: presentationFrame
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
        presentationFrame: presentationFrame
    )
}

private func updateMetalWorldPlan(
    _ prepared: MetalWorldPlan,
    level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?,
    presentationFrame: MetalPresentationFrame?
) throws -> MetalWorldPlan {
    let extraction = try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle
    )
    let opaqueRoomDraws = extraction.opaqueDrawItems.map(makeMetalWorldDraw)
    let translucentRoomDraws = extraction.translucentDrawItems.map(makeMetalWorldDraw)
    let objectDraws = extraction.modelDrawItems.map(makeMetalWorldDraw)
    let roomIndexByIdentity = Dictionary(
        uniqueKeysWithValues: prepared.preparedDraws.enumerated()
            .filter { $0.element.objectHandle == nil }
            .map { (MetalRoomDrawIdentity($0.element), $0.offset) }
    )
    let objectIndexByIdentity = Dictionary(
        uniqueKeysWithValues: prepared.preparedDraws.enumerated()
            .filter { $0.element.objectHandle != nil }
            .map { (MetalModelDrawIdentity($0.element), $0.offset) }
    )
    let opaqueIndices = opaqueRoomDraws.map {
        roomIndexByIdentity[MetalRoomDrawIdentity($0)]!
    }
    let objectIndices = objectDraws.map {
        objectIndexByIdentity[MetalModelDrawIdentity($0)]!
    }
    let translucentIndices = translucentRoomDraws.map {
        roomIndexByIdentity[MetalRoomDrawIdentity($0)]!
    }
    let activeDrawIndices = opaqueIndices + objectIndices + translucentIndices
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
        preparedDraws: prepared.preparedDraws,
        activeDrawIndices: activeDrawIndices,
        draws: activeDrawIndices.map { prepared.preparedDraws[$0] }
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
            surfaceColor: tint
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
    let model: SourceResource
    let submodelIndex: Int
    let faceIndex: Int

    init(_ draw: MetalWorldDraw) {
        objectHandle = draw.objectHandle!
        model = draw.model!
        submodelIndex = draw.submodelIndex!
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
                surfaceColor: SIMD4<Float>(1, 1, 1, 0)
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
                } ?? SIMD4<Float>(1, 1, 1, 0)
            )
        },
        indices: item.triangleIndices
    )
}
