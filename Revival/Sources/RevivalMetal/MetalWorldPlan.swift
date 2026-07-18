// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum MetalWorldPlanError: Error, Equatable, LocalizedError {
    case nonzeroLightCorona(roomSourceIndex: Int, faceIndex: Int)

    var errorDescription: String? {
        switch self {
        case let .nonzeroLightCorona(roomSourceIndex, faceIndex):
            "Source room \(roomSourceIndex) face \(faceIndex) reaches temporal light-corona behavior outside Slice 3."
        }
    }
}

struct MetalWorldVertex: Equatable, Sendable {
    let position: SIMD4<Float>
    let textureAndLightmapUV: SIMD4<Float>
    let presentation: SIMD4<Float>
}

struct MetalWorldDraw: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let texture: SourceResource
    let blend: PresentationBlend
    let lightmapBlend: PresentationLightmapBlend
    let lightmapPageIndex: Int?
    let vertices: [MetalWorldVertex]
    let indices: [UInt32]
}

struct MetalWorldPlan: Equatable, Sendable {
    let level: Level
    let camera: RoomCamera
    let visibleRoomSourceIndices: [Int]
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
    if let corona = extraction.lightCoronas.first {
        throw MetalWorldPlanError.nonzeroLightCorona(
            roomSourceIndex: corona.roomSourceIndex,
            faceIndex: corona.faceIndex
        )
    }
    let orderedDraws = extraction.opaqueDrawItems + extraction.translucentDrawItems
    return MetalWorldPlan(
        level: level,
        camera: camera,
        visibleRoomSourceIndices: extraction.visibleRoomSourceIndices,
        draws: orderedDraws.map(makeMetalWorldDraw)
    )
}

private func makeMetalWorldDraw(_ item: RoomDrawItem) -> MetalWorldDraw {
    let blendOpacity: Float
    switch item.blend {
    case .opaque:
        blendOpacity = 1
    case let .additiveSourceAlpha(opacity):
        blendOpacity = Float(opacity) / 255
    }
    return MetalWorldDraw(
        roomSourceIndex: item.roomSourceIndex,
        faceIndex: item.faceIndex,
        texture: item.texture,
        blend: item.blend,
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
                )
            )
        },
        indices: item.triangleIndices
    )
}
