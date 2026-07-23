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

struct MetalWorldPlan: Equatable, Sendable {
    let level: Level
    let camera: RoomCamera
    let visibleRoomSourceIndices: [Int]
    let preparedLightCoronaCandidates: [WorldLightCorona]
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
        extraction: extraction
    )
}

private func makeMetalWorldPlan(
    level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    extraction: WorldRenderExtraction
) throws -> MetalWorldPlan {
    let opaqueRoomDraws = extraction.opaqueDrawItems.map(makeMetalWorldDraw)
    let translucentRoomDraws = extraction.translucentDrawItems.map(makeMetalWorldDraw)
    let objectDraws = extraction.modelDrawItems.map(makeMetalWorldDraw)
    let preparedRoomDraws = try extractPreparedRoomDrawItems(
        level,
        startRoomSourceIndex: startRoomSourceIndex
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
    let objectOffset = preparedRoomDraws.count
    let activeDrawIndices =
        Array(initialRoomIndices.prefix(opaqueRoomDraws.count))
        + objectDraws.indices.map { objectOffset + $0 }
        + Array(initialRoomIndices.dropFirst(opaqueRoomDraws.count))
    let preparedDraws = preparedRoomDraws + objectDraws
    let draws = activeDrawIndices.map { preparedDraws[$0] }
    return MetalWorldPlan(
        level: level,
        camera: camera,
        visibleRoomSourceIndices: extraction.visibleRoomSourceIndices,
        preparedLightCoronaCandidates: extraction.lightCoronas,
        preparedDraws: preparedDraws,
        activeDrawIndices: Array(activeDrawIndices),
        draws: draws
    )
}

private struct MetalRoomDrawIdentity: Hashable {
    let roomSourceIndex: Int
    let faceIndex: Int

    init(_ draw: MetalWorldDraw) {
        roomSourceIndex = draw.roomSourceIndex
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
