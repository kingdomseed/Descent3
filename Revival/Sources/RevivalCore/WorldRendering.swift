// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct PerspectiveProjection: Codable, Equatable, Sendable {
    let horizontalFieldOfViewRadians: Float
    let aspectRatio: Float

    static let squareNinetyDegrees = PerspectiveProjection(
        horizontalFieldOfViewRadians: .pi / 2,
        aspectRatio: 1
    )
}

struct RoomCamera: Codable, Equatable, Sendable {
    let position: Vector3
    let target: Vector3
    let up: Vector3
    let projection: PerspectiveProjection

    init(
        position: Vector3,
        target: Vector3,
        up: Vector3,
        projection: PerspectiveProjection = .squareNinetyDegrees
    ) {
        self.position = position
        self.target = target
        self.up = up
        self.projection = projection
    }

    static let trainingRoom3 = RoomCamera(
        position: .init(x: 2_061.7124, y: -220.75536, z: 2_206.3005),
        target: .init(x: 2_061.7124, y: -200, z: 2_206.3005),
        up: .init(x: 0, y: 0, z: 1)
    )
}

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

struct WorldLightCorona: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let assetIndex: Int
    let center: Vector3
    let size: Float
    let tint: Vector3
    let blend: PresentationBlend
}

struct WorldRenderExtraction: Equatable, Sendable {
    let visibleRoomSourceIndices: [Int]
    let opaqueDrawItems: [RoomDrawItem]
    let translucentDrawItems: [RoomDrawItem]
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
}

enum RoomRenderExtractionError: Error, Equatable {
    case missingRoom(Int)
    case missingMaterial(String)
    case missingLightmap(Int)
    case missingCoronaAsset(Int)
}

struct WaterProceduralEvaluator: Sendable {
    private static let dimension = 128
    private static let pixelCount = dimension * dimension

    private let sourceRGBA8: [UInt8]
    private let definition: WaterProceduralDefinition
    private var current = [Int16](repeating: 0, count: pixelCount)
    private var previous = [Int16](repeating: 0, count: pixelCount)
    private var output = Data(repeating: 0, count: pixelCount * 4)
    private var lastFrameCount: Int?
    private var lastEvaluationTime: Float = 0

    init(
        image: CanonicalRGBA8Image,
        definition: WaterProceduralDefinition
    ) {
        precondition(
            image.width == Self.dimension
                && image.height == Self.dimension
                && image.rgba8.count == Self.pixelCount * 4
                && definition.lightingShift < 16
                && definition.dampingShift < 16
                && definition.elements.count <= 64
                && definition.evaluationIntervalSeconds.isFinite
                && definition.evaluationIntervalSeconds >= 0,
            "Water evaluators require validated canonical inputs."
        )
        sourceRGBA8 = [UInt8](image.rgba8)
        self.definition = definition
    }

    mutating func rgba8(frameCount: Int, timeSeconds: Float) -> Data {
        if lastFrameCount == frameCount { return output }
        if timeSeconds < lastEvaluationTime + definition.evaluationIntervalSeconds {
            return output
        }

        injectStaticElements(frameCount: frameCount)
        output = renderCurrentWater()
        calculateNextWater()
        swap(&current, &previous)
        lastFrameCount = frameCount
        lastEvaluationTime = timeSeconds
        return output
    }

    private mutating func injectStaticElements(frameCount: Int) {
        for (elementIndex, element) in definition.elements.enumerated() {
            guard element.kind == .heightBlob else { continue }
            let frequency = Int(element.frequency)
            if frequency != 0 && (frameCount + elementIndex) % frequency != 0 {
                continue
            }
            injectHeightBlob(element)
        }
    }

    private mutating func injectHeightBlob(_ element: WaterProceduralElement) {
        let centerX = Int(element.x1)
        let centerY = Int(element.y1)
        let radius = Int(element.size)
        let radiusSquared = radius * radius
        var left = -radius
        var top = -radius
        var right = radius
        var bottom = radius
        if centerX - radius < 1 { left -= centerX - radius - 1 }
        if centerY - radius < 1 { top -= centerY - radius - 1 }
        if centerX + radius > Self.dimension - 1 {
            right -= centerX + radius - Self.dimension + 1
        }
        if centerY + radius > Self.dimension - 1 {
            bottom -= centerY + radius - Self.dimension + 1
        }
        guard left < right, top < bottom else { return }
        let height = Int16(element.speed)
        for y in top..<bottom {
            let ySquared = y * y
            for x in left..<right where x * x + ySquared < radiusSquared {
                let index = (centerY + y) * Self.dimension + centerX + x
                current[index] = current[index] &+ height
            }
        }
    }

    private func renderCurrentWater() -> Data {
        var rgba8 = [UInt8](repeating: 0, count: Self.pixelCount * 4)
        for y in 0..<Self.dimension {
            let previousY = y == 0 ? Self.dimension - 1 : y - 1
            let nextY = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let previousX = x == 0 ? Self.dimension - 1 : x - 1
                let nextX = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                let dx = Int(current[y * Self.dimension + previousX])
                    - Int(current[y * Self.dimension + nextX])
                let dy = Int(current[previousY * Self.dimension + x])
                    - Int(current[nextY * Self.dimension + x])
                let sampleX = (x + (dx >> 3)) & (Self.dimension - 1)
                let sampleY = (y + (dy >> 3)) & (Self.dimension - 1)
                let sample = (sampleY * Self.dimension + sampleX) * 4
                let shade = min(
                    63,
                    max(0, 32 - (dx >> Int(definition.lightingShift)))
                )
                let destination = index * 4
                let shaded = shadedRGB(
                    red: sourceRGBA8[sample] >> 3,
                    green: sourceRGBA8[sample + 1] >> 3,
                    blue: sourceRGBA8[sample + 2] >> 3,
                    shade: shade
                )
                rgba8[destination] = expandFiveBits(shaded.red)
                rgba8[destination + 1] = expandFiveBits(shaded.green)
                rgba8[destination + 2] = expandFiveBits(shaded.blue)
                rgba8[destination + 3] = 255
            }
        }
        return Data(rgba8)
    }

    private func shadedRGB(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        shade: Int
    ) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let normalized = Float(shade) / 63
        let low = min(normalized / 0.5, 1)
        let high = max((normalized - 0.5) / 0.5, 0)
        let shadedRed = min(Int(Float(red) * low + 31 * high), 31)
        let shadedBlue = min(Int(Float(blue) * low + 31 * high), 31)
        let lowGreen = min(Int(Float(green & 0x07) * low + 7 * high), 7)
        let highGreen = min(Int(Float(green & 0x18) * low + 24 * high), 24)
        return (
            UInt8(shadedRed),
            UInt8(lowGreen + highGreen),
            UInt8(shadedBlue)
        )
    }

    private mutating func calculateNextWater() {
        for y in 0..<Self.dimension {
            let north = y == 0 ? Self.dimension - 1 : y - 1
            let south = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let west = x == 0 ? Self.dimension - 1 : x - 1
                let east = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                var next = (
                    Int(current[north * Self.dimension + x])
                        + Int(current[south * Self.dimension + x])
                        + Int(current[y * Self.dimension + west])
                        + Int(current[y * Self.dimension + east])
                ) >> 1
                next -= Int(previous[index])
                next -= next >> Int(definition.dampingShift)
                previous[index] = Int16(truncatingIfNeeded: next)
            }
        }
    }
}

private func expandFiveBits(_ value: UInt8) -> UInt8 {
    value << 3 | value >> 2
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int
) throws -> WorldRenderExtraction {
    let visibility = try extractSourceVisibleWorld(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        portalBlends: Dictionary(
            uniqueKeysWithValues: level.presentationMaterials.map {
                ($0.texture, $0.blend)
            }
        )
    )
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let view = CameraView(camera)

    var opaqueDrawItems: [RoomDrawItem] = []
    var translucentDrawItems: [(depth: Float, item: RoomDrawItem)] = []
    let facesByRoom = Dictionary(grouping: visibility.faces, by: \.roomSourceIndex)
    for roomSourceIndex in visibility.visibleRoomSourceIndices.reversed() {
        let room = roomBySourceIndex[roomSourceIndex]!
        for faceIndex in (facesByRoom[roomSourceIndex] ?? []).map(\.faceIndex).sorted() {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            let item = try makeDrawItem(
                room: room,
                faceIndex: faceIndex,
                material: material,
                lightmaps: level.lightmaps
            )
            if case .additiveSourceAlpha = material.blend {
                let depth = item.vertices.reduce(Float.zero) {
                    $0 + view.project($1.position).depth
                } / Float(item.vertices.count)
                translucentDrawItems.append((depth, item))
            } else {
                opaqueDrawItems.append(item)
            }
        }
    }
    translucentDrawItems.sort {
        if $0.depth != $1.depth { return $0.depth > $1.depth }
        if $0.item.roomSourceIndex != $1.item.roomSourceIndex {
            return $0.item.roomSourceIndex < $1.item.roomSourceIndex
        }
        return $0.item.faceIndex < $1.item.faceIndex
    }
    let lightCoronas = try extractSourceLightCoronas(
        level,
        camera: camera,
        visibility: visibility
    )
    return WorldRenderExtraction(
        visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
        opaqueDrawItems: opaqueDrawItems,
        translucentDrawItems: translucentDrawItems.map(\.item),
        lightCoronas: lightCoronas,
        portalEdges: visibility.portalEdges
    )
}

func extractSourceLightCoronas(
    _ level: Level,
    camera: RoomCamera,
    visibility: SourceVisibleWorld
) throws -> [WorldLightCorona] {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var result: [WorldLightCorona] = []
    for visibleFace in visibility.faces {
        let room = roomBySourceIndex[visibleFace.roomSourceIndex]!
        let face = room.faces[visibleFace.faceIndex]
        guard face.portalIndex == nil,
              face.allowsLightCorona,
              let corona = materialByTexture[face.texture]?.lightCorona else {
            continue
        }
        guard level.presentationCoronaAssets.indices.contains(corona.assetIndex) else {
            throw RoomRenderExtractionError.missingCoronaAsset(corona.assetIndex)
        }
        let geometry = sourceFaceCoronaGeometry(room: room, face: face)
        let eyeOffset = geometry.center - camera.position
        let distance = sqrt(dot(eyeOffset, eyeOffset))
        guard distance >= geometry.size * 5 else { continue }
        guard !sourceCoronaRayIsOccluded(
            from: camera.position,
            to: geometry.center,
            level: level,
            visibleRoomSourceIndices: visibility.visibleRoomSourceIndices
        ) else {
            continue
        }
        result.append(
            WorldLightCorona(
                roomSourceIndex: room.sourceIndex,
                faceIndex: visibleFace.faceIndex,
                assetIndex: corona.assetIndex,
                center: geometry.center,
                size: geometry.size,
                tint: corona.tint,
                blend: corona.blend
            )
        )
    }
    return result
}

private func sourceFaceCoronaGeometry(
    room: LevelRoom,
    face: LevelFace
) -> (center: Vector3, size: Float) {
    let first = room.vertices[face.corners[0].vertexIndex]
    var totalArea: Float = 0
    var weightedX: Float = 0
    var weightedY: Float = 0
    var weightedZ: Float = 0
    for index in 1..<(face.corners.count - 1) {
        let second = room.vertices[face.corners[index].vertexIndex]
        let third = room.vertices[face.corners[index + 1].vertexIndex]
        let perpendicular = cross(second - first, third - first)
        let area = sqrt(dot(perpendicular, perpendicular)) / 2
        totalArea += area
        weightedX += ((first.x + second.x + third.x) / 3) * area
        weightedY += ((first.y + second.y + third.y) / 3) * area
        weightedZ += ((first.z + second.z + third.z) / 3) * area
    }
    precondition(totalArea > 0, "validated corona faces must have positive area")
    let normal = faceNormal(room, face: face)
    return (
        Vector3(
            x: weightedX / totalArea + normal.x / 4,
            y: weightedY / totalArea + normal.y / 4,
            z: weightedZ / totalArea + normal.z / 4
        ),
        2 * sqrt(totalArea)
    )
}

private func sourceCoronaRayIsOccluded(
    from origin: Vector3,
    to destination: Vector3,
    level: Level,
    visibleRoomSourceIndices: [Int]
) -> Bool {
    let ray = destination - origin
    let distance = sqrt(dot(ray, ray))
    let direction = ray / distance
    let visibleRooms = Set(visibleRoomSourceIndices)
    for room in level.rooms where visibleRooms.contains(room.sourceIndex) {
        for face in room.faces where sourceFaceBlocksCoronaRay(room: room, face: face) {
            let first = room.vertices[face.corners[0].vertexIndex]
            for index in 1..<(face.corners.count - 1) {
                let second = room.vertices[face.corners[index].vertexIndex]
                let third = room.vertices[face.corners[index + 1].vertexIndex]
                if let hitDistance = rayTriangleDistance(
                    origin: origin,
                    direction: direction,
                    first: first,
                    second: second,
                    third: third
                ), hitDistance < distance - 0.000_1 {
                    return true
                }
            }
        }
    }
    return false
}

private func sourceFaceBlocksCoronaRay(room: LevelRoom, face: LevelFace) -> Bool {
    guard let portalIndex = face.portalIndex else { return true }
    let flags = room.portals[portalIndex].flags
    let explicitlyBlocked = flags & 0x0000_0020 != 0
    let renderedAndNotFlyThrough = flags & 0x0000_0001 != 0
        && flags & 0x0000_0002 == 0
    return explicitlyBlocked || renderedAndNotFlyThrough
}

private func rayTriangleDistance(
    origin: Vector3,
    direction: Vector3,
    first: Vector3,
    second: Vector3,
    third: Vector3
) -> Float? {
    let epsilon: Float = 0.000_01
    let firstEdge = second - first
    let secondEdge = third - first
    let determinantVector = cross(direction, secondEdge)
    let determinant = dot(firstEdge, determinantVector)
    guard abs(determinant) > epsilon else { return nil }
    let inverseDeterminant = 1 / determinant
    let originOffset = origin - first
    let firstCoordinate = dot(originOffset, determinantVector) * inverseDeterminant
    guard firstCoordinate >= -epsilon, firstCoordinate <= 1 + epsilon else {
        return nil
    }
    let secondCoordinateVector = cross(originOffset, firstEdge)
    let secondCoordinate = dot(direction, secondCoordinateVector) * inverseDeterminant
    guard secondCoordinate >= -epsilon,
          firstCoordinate + secondCoordinate <= 1 + epsilon else {
        return nil
    }
    let distance = dot(secondEdge, secondCoordinateVector) * inverseDeterminant
    return distance > epsilon ? distance : nil
}

func extractSourceVisibleWorld(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    portalBlends: [SourceResource: PresentationBlend]
) throws -> SourceVisibleWorld {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    guard roomBySourceIndex[startRoomSourceIndex] != nil else {
        throw RoomRenderExtractionError.missingRoom(startRoomSourceIndex)
    }
    let view = CameraView(camera)
    var roomDepth = [startRoomSourceIndex: 0]
    var seenRooms: Set<Int> = []
    var visibleRoomSourceIndices: [Int] = []
    var visibleFacesByRoom: [Int: Set<Int>] = [:]
    var portalEdges: [RenderPortalEdge] = []

    func renderPastPortal(_ room: LevelRoom, portalIndex: Int) throws -> Bool {
        let portal = room.portals[portalIndex]
        guard portal.flags & 0x0000_0001 != 0 else { return true }
        let face = room.faces[portal.faceIndex]
        guard let blend = portalBlends[face.texture] else {
            throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
        }
        if case .additiveSourceAlpha = blend { return true }
        return false
    }

    func visit(_ roomSourceIndex: Int, window: ClipWindow, depth: Int) throws {
        guard let room = roomBySourceIndex[roomSourceIndex] else {
            throw RoomRenderExtractionError.missingRoom(roomSourceIndex)
        }
        if seenRooms.insert(roomSourceIndex).inserted {
            visibleRoomSourceIndices.append(roomSourceIndex)
        }
        if visibleFacesByRoom[roomSourceIndex] == nil {
            visibleFacesByRoom[roomSourceIndex] = depth == 0
                ? Set(room.faces.indices.filter {
                    faceIsFrontFacing(room, faceIndex: $0, eye: camera.position)
                })
                : []
        }

        for (portalIndex, portal) in room.portals.enumerated() {
            portalEdges.append(
                RenderPortalEdge(
                    roomSourceIndex: roomSourceIndex,
                    portalIndex: portalIndex,
                    faceIndex: portal.faceIndex,
                    connectedRoom: portal.connectedRoom,
                    connectedPortal: portal.connectedPortal,
                    presentation: portal.flags & 0x0000_0001 != 0
                        ? .renderedSurface
                        : .openBoundary
                )
            )
            if let connectedDepth = roomDepth[portal.connectedRoom], connectedDepth < depth {
                continue
            }
            guard faceIsFrontFacing(room, faceIndex: portal.faceIndex, eye: camera.position),
                  let portalWindow = projectedPortalWindow(
                      room,
                      faceIndex: portal.faceIndex,
                      view: view,
                      parent: window
                  ) else {
                continue
            }
            guard try renderPastPortal(room, portalIndex: portalIndex) else { continue }
            guard let connected = roomBySourceIndex[portal.connectedRoom] else {
                throw RoomRenderExtractionError.missingRoom(portal.connectedRoom)
            }
            var marked = visibleFacesByRoom[portal.connectedRoom] ?? []
            for faceIndex in connected.faces.indices where
                faceIsFrontFacing(connected, faceIndex: faceIndex, eye: camera.position)
                && faceIntersectsWindow(
                    connected,
                    faceIndex: faceIndex,
                    view: view,
                    window: portalWindow
                ) {
                marked.insert(faceIndex)
            }
            visibleFacesByRoom[portal.connectedRoom] = marked
            roomDepth[portal.connectedRoom] = depth + 1
            try visit(portal.connectedRoom, window: portalWindow, depth: depth + 1)
            roomDepth[portal.connectedRoom] = 255
        }
    }

    try visit(
        startRoomSourceIndex,
        window: .init(left: -1, top: 1, right: 1, bottom: -1),
        depth: 0
    )
    return SourceVisibleWorld(
        visibleRoomSourceIndices: visibleRoomSourceIndices,
        faces: visibleRoomSourceIndices.flatMap { roomSourceIndex in
            let room = roomBySourceIndex[roomSourceIndex]!
            return (visibleFacesByRoom[roomSourceIndex] ?? []).sorted().compactMap {
                faceIsRenderable(room, face: room.faces[$0])
                    ? SourceVisibleFace(roomSourceIndex: roomSourceIndex, faceIndex: $0)
                    : nil
            }
        },
        portalEdges: portalEdges
    )
}

func sourceRoomThreeContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    precondition(
        room.sourceIndex == 3,
        "Slice 3 camera containment is defined only for source room 3"
    )
    return room.faces.allSatisfy { face in
        let first = room.vertices[face.corners[0].vertexIndex]
        return dot(point - first, faceNormal(room, face: face)) >= 0
    }
}

private func faceIsRenderable(_ room: LevelRoom, face: LevelFace) -> Bool {
    guard let portalIndex = face.portalIndex else { return true }
    return room.portals[portalIndex].flags & 0x0000_0001 != 0
}

private func makeDrawItem(
    room: LevelRoom,
    faceIndex: Int,
    material: PresentationMaterial,
    lightmaps: LightmapCatalog
) throws -> RoomDrawItem {
    let face = room.faces[faceIndex]
    let lightmapPageIndex: Int?
    if let infoIndex = face.lightmapInfoIndex {
        let pageIndex = lightmaps.infos[infoIndex].pageIndex
        let page = lightmaps.pages[pageIndex]
        guard page.rgba8?.count == page.width * page.height * 4 else {
            throw RoomRenderExtractionError.missingLightmap(pageIndex)
        }
        lightmapPageIndex = pageIndex
    } else {
        lightmapPageIndex = nil
    }
    let vertices = face.corners.map { corner in
        WorldRenderVertex(
            position: room.vertices[corner.vertexIndex],
            u: corner.u,
            v: corner.v,
            lightmapU: corner.lightmapU ?? 0,
            lightmapV: corner.lightmapV ?? 0,
            alpha: Float(corner.alpha) / 255
        )
    }
    var triangleIndices: [UInt32] = []
    for index in 1..<(vertices.count - 1) {
        triangleIndices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
    }
    return RoomDrawItem(
        roomSourceIndex: room.sourceIndex,
        faceIndex: faceIndex,
        texture: face.texture,
        blend: material.blend,
        lightmapBlend: material.lightmapBlend,
        lightmapPageIndex: lightmapPageIndex,
        vertices: vertices,
        triangleIndices: triangleIndices
    )
}

private struct CameraView {
    let eye: Vector3
    let right: Vector3
    let up: Vector3
    let forward: Vector3
    let horizontalProjectionScale: Float
    let verticalProjectionScale: Float

    init(_ camera: RoomCamera) {
        eye = camera.position
        forward = normalized(camera.target - camera.position)
        right = normalized(cross(forward, camera.up))
        up = cross(right, forward)
        precondition(
            camera.projection.horizontalFieldOfViewRadians.isFinite
                && camera.projection.aspectRatio.isFinite
                && camera.projection.horizontalFieldOfViewRadians > 0
                && camera.projection.horizontalFieldOfViewRadians < .pi
                && camera.projection.aspectRatio > 0,
            "camera projection must be finite and positive"
        )
        horizontalProjectionScale = 1 / tan(
            camera.projection.horizontalFieldOfViewRadians / 2
        )
        verticalProjectionScale = horizontalProjectionScale * camera.projection.aspectRatio
    }

    func project(_ point: Vector3) -> ProjectedPoint {
        let relative = point - eye
        let depth = dot(relative, forward)
        return ProjectedPoint(
            x: dot(relative, right) * horizontalProjectionScale / depth,
            y: dot(relative, up) * verticalProjectionScale / depth,
            depth: depth
        )
    }
}

private struct ProjectedPoint {
    let x: Float
    let y: Float
    let depth: Float
}

private struct ClipWindow {
    let left: Float
    let top: Float
    let right: Float
    let bottom: Float
}

private func projectedPortalWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    parent: ClipWindow
) -> ClipWindow? {
    guard faceIntersectsWindow(room, faceIndex: faceIndex, view: view, window: parent) else {
        return nil
    }
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    guard points.allSatisfy({ $0.depth > 0 }) else { return nil }
    let left = max(parent.left, points.map(\.x).min()!)
    let right = min(parent.right, points.map(\.x).max()!)
    let bottom = max(parent.bottom, points.map(\.y).min()!)
    let top = min(parent.top, points.map(\.y).max()!)
    guard left <= right, bottom <= top else { return nil }
    return ClipWindow(left: left, top: top, right: right, bottom: bottom)
}

private func faceIntersectsWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    window: ClipWindow
) -> Bool {
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    let codes = points.map { clipCode($0, window: window) }
    let combinedAnd = codes.reduce(UInt8.max, &)
    if combinedAnd != 0 { return false }
    let combinedOr = codes.reduce(UInt8.zero, |)
    if combinedOr == 0 { return true }
    for index in points.indices {
        let start = points[index]
        let end = points[(index + 1) % points.count]
        if lineIntersectsLine(start, end, window.left, window.top, window.right, window.top)
            || lineIntersectsLine(start, end, window.right, window.top, window.right, window.bottom)
            || lineIntersectsLine(start, end, window.right, window.bottom, window.left, window.bottom)
            || lineIntersectsLine(start, end, window.left, window.bottom, window.left, window.top) {
            return true
        }
    }
    return false
}

private func clipCode(_ point: ProjectedPoint, window: ClipWindow) -> UInt8 {
    guard point.depth > 0 else { return 0x10 }
    var code: UInt8 = 0
    if point.x < window.left { code |= 0x01 }
    if point.x > window.right { code |= 0x02 }
    if point.y > window.top { code |= 0x04 }
    if point.y < window.bottom { code |= 0x08 }
    return code
}

private func lineIntersectsLine(
    _ start: ProjectedPoint,
    _ end: ProjectedPoint,
    _ x1: Float,
    _ y1: Float,
    _ x2: Float,
    _ y2: Float
) -> Bool {
    var numerator = (start.y - y1) * (x2 - x1) - (start.x - x1) * (y2 - y1)
    let denominator = (end.x - start.x) * (y2 - y1) - (end.y - start.y) * (x2 - x1)
    let r = numerator / denominator
    if (0...1).contains(r) { return true }
    numerator = (start.y - y1) * (end.x - start.x) - (start.x - x1) * (end.y - start.y)
    let s = numerator / denominator
    return (0...1).contains(s)
}

private func faceIsFrontFacing(_ room: LevelRoom, faceIndex: Int, eye: Vector3) -> Bool {
    let face = room.faces[faceIndex]
    let normal = faceNormal(room, face: face)
    let first = room.vertices[face.corners[0].vertexIndex]
    return dot(eye - first, normal) > 0
}

private func faceNormal(_ room: LevelRoom, face: LevelFace) -> Vector3 {
    guard let normal = canonicalFaceNormal(room: room, face: face) else {
        preconditionFailure("validated faces must have a usable normal")
    }
    return normal
}

private func normalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0, "camera basis vectors must be nonzero")
    return value / magnitude
}

private func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func / (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
}

private func dot(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

private func cross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}
