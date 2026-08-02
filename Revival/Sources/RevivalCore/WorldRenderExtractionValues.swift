// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum PortalPresentation: String, Codable, Equatable, Sendable {
    case renderedSurface
    case openBoundary
}

struct RenderPortalEdge: Codable, Equatable, Sendable {
    let roomSourceIndex: Int
    let portalIndex: Int
    let faceIndex: Int
    let connectedRoom: Int
    let connectedPortal: Int
    let presentation: PortalPresentation
}

struct WorldRenderVertex: Equatable, Sendable {
    let position: Vector3
    let u: Float
    let v: Float
    let lightmapU: Float
    let lightmapV: Float
    let alpha: Float
}

struct RoomDrawItem: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let texture: SourceResource
    let blend: PresentationBlend
    let lightmapBlend: PresentationLightmapBlend
    let lightmapPageIndex: Int?
    let vertices: [WorldRenderVertex]
    let triangleIndices: [UInt32]
}

struct ModelDrawItem: Equatable, Sendable {
    let objectHandle: UInt32
    let roomSourceIndex: Int
    let model: SourceResource
    let submodelIndex: Int
    let faceIndex: Int
    let material: ModelFaceMaterial
    let blend: PresentationBlend
    let vertices: [WorldRenderVertex]
    let triangleIndices: [UInt32]
}

struct WorldLightCorona: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let assetIndex: Int
    let center: Vector3
    let size: Float
    let firstVertex: Vector3
    let normal: Vector3
    let tint: Vector3
    let blend: PresentationBlend
}

struct WorldRenderExtraction: Equatable, Sendable {
    let visibleRoomSourceIndices: [Int]
    let opaqueDrawItems: [RoomDrawItem]
    let translucentDrawItems: [RoomDrawItem]
    let admittedObjectHandles: [UInt32]
    let modelDrawItems: [ModelDrawItem]
    let lightCoronas: [WorldLightCorona]
    let portalEdges: [RenderPortalEdge]
}

struct SourceVisibleFace: Equatable, Hashable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
}

struct SourceVisibleWorld: Equatable, Sendable {
    let visibleRoomSourceIndices: [Int]
    let faces: [SourceVisibleFace]
    let portalEdges: [RenderPortalEdge]
    let objectClipWindowsByRoom: [Int: [SourceClipWindow]]
}

struct SourceClipWindow: Equatable, Sendable {
    let left: Float
    let top: Float
    let right: Float
    let bottom: Float
}
