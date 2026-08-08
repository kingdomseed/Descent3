// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum RoomRenderExtractionError: Error, Equatable {
    case missingRoom(Int)
    case missingMaterial(String)
    case missingLightmap(Int)
    case missingCoronaAsset(Int)
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil
    )
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    presentationGameTime: Float
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil,
        presentationGameTime: presentationGameTime
    )
}

func extractWorldForRendering(
    _ level: Level,
    playerView: PlayerView
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: playerView.camera,
        startRoomSourceIndex: playerView.roomSourceIndex,
        excludedObjectHandle: playerView.objectHandle
    )
}

func extractPreparedRoomDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int
) throws -> [RoomDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [RoomDrawItem] = []
    for room in level.rooms
        .filter({ component.contains($0.sourceIndex) })
        .sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        for faceIndex in room.faces.indices {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            items.append(
                try makeDrawItem(
                    room: room,
                    faceIndex: faceIndex,
                    material: material,
                    lightmaps: level.lightmaps
                )
            )
        }
    }
    return items
}

func extractPreparedModelDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> [ModelDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [ModelDrawItem] = []
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              case let .room(roomSourceIndex) = object.location,
              component.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle] else {
            continue
        }
        var seen: Set<SourceResource> = []
        for source in [
            presentation.primaryModel,
            presentation.mediumModel,
            presentation.lowModel,
        ].compactMap({ $0 }) where seen.insert(source).inserted {
            items += makeModelDrawItems(
                object: object,
                model: modelBySource[source]!,
                materialByTexture: materialByTexture,
                camera: .trainingRoom3,
                cullBackfaces: false
            )
        }
    }
    return items
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?,
    presentationGameTime: Float = 0,
    trainingDodgeTurretAngles: [Float] = []
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
        visibility: visibility,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle
    )
    let objectPresentation = extractObjectPresentation(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        visibility: visibility,
        excludedObjectHandle: excludedObjectHandle,
        presentationGameTime: presentationGameTime,
        trainingDodgeTurretAngles:
            trainingDodgeTurretAngles
    )
    return WorldRenderExtraction(
        visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
        opaqueDrawItems: opaqueDrawItems,
        translucentDrawItems: translucentDrawItems.map(\.item),
        admittedObjectHandles: objectPresentation.handles,
        modelDrawItems: objectPresentation.drawItems,
        lightCoronas: lightCoronas,
        portalEdges: visibility.portalEdges
    )
}

private func extractObjectPresentation(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    visibility: SourceVisibleWorld,
    excludedObjectHandle: UInt32?,
    presentationGameTime: Float,
    trainingDodgeTurretAngles: [Float]
) -> (handles: [UInt32], drawItems: [ModelDrawItem]) {
    guard !level.objectPresentations.isEmpty else { return ([], []) }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let visibleRooms = Set(visibility.visibleRoomSourceIndices)
    let view = CameraView(camera)
    var accepted: [(depth: Float, ordinal: Int, object: PlacedObject,
                    presentation: ObjectPresentationReference, model: CanonicalModel)] = []
    for (ordinal, object) in level.objects.enumerated() {
        guard object.handle != excludedObjectHandle,
              let presentation = presentationByHandle[object.handle],
              presentation.isVisible,
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let primary = modelBySource[presentation.primaryModel] else {
            continue
        }
        let size = sourceObjectPresentationSize(model: primary, objectType: object.type)
        guard sourceObjectIsPortalSafe(
            object,
            size: size,
            startRoomSourceIndex: startRoomSourceIndex,
            clipWindowsByRoom: visibility.objectClipWindowsByRoom,
            view: view
        ), sourceSphereIsVisible(object.position, radius: size, view: view) else {
            continue
        }
        let depth = view.depth(of: object.position)
        let selectedSource = sourceLODModel(presentation, depth: depth)
        guard let model = modelBySource[selectedSource] else {
            preconditionFailure("validated object presentation references must resolve")
        }
        accepted.append((depth, ordinal, object, presentation, model))
    }
    accepted.sort {
        $0.depth == $1.depth ? $0.ordinal < $1.ordinal : $0.depth > $1.depth
    }
    return (
        accepted.map { $0.object.handle },
        accepted.flatMap {
            makeModelDrawItems(
                object: $0.object,
                model: $0.model,
                materialByTexture: materialByTexture,
                camera: camera,
                presentationGameTime: presentationGameTime,
                turretAnglesBySubmodel:
                    $0.object.handle
                    == level.trainingDodgeAttempt?
                    .dodgeTurretObjectHandle
                    ? Dictionary(
                        uniqueKeysWithValues: zip(
                            level.trainingDodgeAttempt!.turret.joints.map(
                                \.submodelIndex
                            ),
                            trainingDodgeTurretAngles
                        ))
                    : [:]
            )
        }
    )
}

func sourceObjectPresentationSize(
    model: CanonicalModel,
    objectType: UInt8
) -> Float {
    let offsets = accumulatedModelOffsets(model)
    var maximumDistanceSquared: Float = 0
    for submodel in model.submodels {
        let offset = offsets[submodel.sourceIndex]
        for vertex in submodel.vertices {
            let transformed = offset + vertex.position
            maximumDistanceSquared = max(
                maximumDistanceSquared,
                dot(transformed, transformed)
            )
        }
    }
    var size = sqrt(maximumDistanceSquared) + 0.01
    if objectType == 7 { size *= 2 }
    return size
}

private func sourceObjectIsPortalSafe(
    _ object: PlacedObject,
    size: Float,
    startRoomSourceIndex: Int,
    clipWindowsByRoom: [Int: [SourceClipWindow]],
    view: CameraView
) -> Bool {
    guard case let .room(roomSourceIndex) = object.location else { return false }
    if roomSourceIndex == startRoomSourceIndex { return true }
    return (clipWindowsByRoom[roomSourceIndex] ?? []).contains { window in
        sourceCubeIntersectsWindow(
            center: object.position,
            halfExtent: size,
            view: view,
            window: window
        )
    }
}

private func sourceCubeIntersectsWindow(
    center: Vector3,
    halfExtent: Float,
    view: CameraView,
    window: SourceClipWindow
) -> Bool {
    var combined = UInt8.max
    for x in [-halfExtent, halfExtent] {
        for y in [-halfExtent, halfExtent] {
            for z in [-halfExtent, halfExtent] {
                let point = view.project(center + .init(x: x, y: y, z: z))
                if point.depth <= 0 { return true }
                combined &= clipCode(point, window: window)
            }
        }
    }
    return combined == 0
}

private func sourceSphereIsVisible(
    _ position: Vector3,
    radius: Float,
    view: CameraView
) -> Bool {
    let relative = position - view.eye
    let horizontal = dot(relative, view.right)
    let vertical = dot(relative, view.up)
    let depth = dot(relative, view.forward)
    guard depth >= -radius else { return false }
    let horizontalHalfFOV = atan(1 / view.horizontalProjectionScale)
    let verticalHalfFOV = atan(1 / view.verticalProjectionScale)
    guard abs(horizontal) * cos(horizontalHalfFOV)
            - depth * sin(horizontalHalfFOV) <= radius,
          abs(vertical) * cos(verticalHalfFOV)
            - depth * sin(verticalHalfFOV) <= radius else {
        return false
    }
    return true
}

private func sourceLODModel(
    _ presentation: ObjectPresentationReference,
    depth: Float
) -> SourceResource {
    if let mediumDistance = presentation.mediumDistance,
       depth >= mediumDistance {
        if let lowDistance = presentation.lowDistance,
           depth >= lowDistance {
            return presentation.lowModel
                ?? presentation.mediumModel
                ?? presentation.primaryModel
        }
        return presentation.mediumModel ?? presentation.primaryModel
    }
    return presentation.primaryModel
}

private struct ModelSubmodelTransform {
    let origin: Vector3
    let orientation: Matrix3
}

private func modelSubmodelTransforms(
    _ model: CanonicalModel,
    presentationGameTime: Float,
    turretAnglesBySubmodel: [Int: Float] = [:]
) -> [ModelSubmodelTransform] {
    precondition(
        presentationGameTime.isFinite && presentationGameTime >= 0
    )
    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    var resolved = [ModelSubmodelTransform?](
        repeating: nil,
        count: model.submodels.count
    )
    func resolve(_ index: Int) -> ModelSubmodelTransform {
        if let result = resolved[index] { return result }
        let submodel = model.submodels[index]
        let parent = submodel.parentIndex.map(resolve)
            ?? .init(origin: .zero, orientation: identity)
        let localOrientation: Matrix3
        if case let .rotate(rate, axis) = submodel.presentation {
            let turns = presentationGameTime / rate
            let angle = (turns - floor(turns)) * 2 * Float.pi
            localOrientation = .init(
                right: rotate(
                    .init(x: 1, y: 0, z: 0),
                    around: axis,
                    angle: angle
                ),
                up: rotate(
                    .init(x: 0, y: 1, z: 0),
                    around: axis,
                    angle: angle
                ),
                forward: rotate(
                    .init(x: 0, y: 0, z: 1),
                    around: axis,
                    angle: angle
                )
            )
        } else if case .turret(_, _, _, let axis) = submodel.presentation,
            let turns = turretAnglesBySubmodel[
                submodel.sourceIndex
            ]
        {
            let angle = turns * 2 * Float.pi
            localOrientation = .init(
                right: rotate(
                    .init(x: 1, y: 0, z: 0),
                    around: axis,
                    angle: angle
                ),
                up: rotate(
                    .init(x: 0, y: 1, z: 0),
                    around: axis,
                    angle: angle
                ),
                forward: rotate(
                    .init(x: 0, y: 0, z: 1),
                    around: axis,
                    angle: angle
                )
            )
        } else {
            localOrientation = identity
        }
        let orientation = Matrix3(
            right: transform(
                localOrientation.right,
                by: parent.orientation
            ),
            up: transform(
                localOrientation.up,
                by: parent.orientation
            ),
            forward: transform(
                localOrientation.forward,
                by: parent.orientation
            )
        )
        let result = ModelSubmodelTransform(
            origin: parent.origin
                + transform(submodel.offset, by: parent.orientation),
            orientation: orientation
        )
        resolved[index] = result
        return result
    }
    return model.submodels.indices.map(resolve)
}

func rotate(
    _ value: Vector3,
    around axis: Vector3,
    angle: Float
) -> Vector3 {
    let cosine = cos(angle)
    let sine = sin(angle)
    return value * cosine
        + sourceVectorCross(axis, value) * sine
        + axis * (dot(axis, value) * (1 - cosine))
}

private func makeModelDrawItems(
    object: PlacedObject,
    model: CanonicalModel,
    materialByTexture: [SourceResource: PresentationMaterial],
    camera: RoomCamera,
    presentationGameTime: Float = 0,
    turretAnglesBySubmodel: [Int: Float] = [:],
    cullBackfaces: Bool = true
) -> [ModelDrawItem] {
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("model presentation is indoor in the Slice 6 island")
    }
    let transforms = modelSubmodelTransforms(
        model,
        presentationGameTime: presentationGameTime,
        turretAnglesBySubmodel: turretAnglesBySubmodel
    )
    let view = CameraView(camera)
    var opaque: [ModelDrawItem] = []
    var alpha: [ModelDrawItem] = []
    for submodel in model.submodels.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        if submodel.presentation == .facing {
            guard let face = submodel.faces.first,
                  case let .texture(texture) = face.material,
                  let material = materialByTexture[texture]
            else {
                preconditionFailure("validated facing presentation must resolve")
            }
            let localPoints = face.corners.map {
                submodel.vertices[$0.vertexIndex].position
            }
            let area = (1..<(localPoints.count - 1)).reduce(Float.zero) {
                $0 + sqrt(dot(
                    sourceVectorCross(
                        localPoints[$1] - localPoints[0],
                        localPoints[$1 + 1] - localPoints[0]
                    ),
                    sourceVectorCross(
                        localPoints[$1] - localPoints[0],
                        localPoints[$1 + 1] - localPoints[0]
                    )
                )) / 2
            }
            let halfWidth = sqrt(area) / 2
            let halfHeight = halfWidth
                * Float(material.image.height)
                / Float(material.image.width)
            let center = object.position
                + transform(
                    transforms[submodel.sourceIndex].origin,
                    by: object.orientation
                )
            let vertices = [
                (center - view.right * halfWidth + view.up * halfHeight, 0, 0),
                (center + view.right * halfWidth + view.up * halfHeight, 1, 0),
                (center + view.right * halfWidth - view.up * halfHeight, 1, 1),
                (center - view.right * halfWidth - view.up * halfHeight, 0, 1),
            ].map {
                WorldRenderVertex(
                    position: $0.0,
                    u: Float($0.1),
                    v: Float($0.2),
                    lightmapU: 0,
                    lightmapV: 0,
                    alpha: 1
                )
            }
            let item = ModelDrawItem(
                objectHandle: object.handle,
                roomSourceIndex: roomSourceIndex,
                model: model.source,
                submodelIndex: submodel.sourceIndex,
                faceIndex: 0,
                material: face.material,
                blend: material.blend,
                vertices: vertices,
                triangleIndices: [0, 1, 2, 0, 2, 3]
            )
            switch material.blend {
            case .opaque: opaque.append(item)
            case .sourceAlpha, .additiveSourceAlpha: alpha.append(item)
            }
            continue
        }
        switch submodel.presentation {
        case .standard, .rotate, .turret:
            break
        case .custom, .facing, .glow:
            continue
        }
        let submodelTransform = transforms[submodel.sourceIndex]
        for (faceIndex, face) in submodel.faces.enumerated() {
            let transformedNormal = transform(
                transform(face.normal, by: submodelTransform.orientation),
                by: object.orientation
            )
            let firstLocal = submodelTransform.origin + transform(
                submodel.vertices[face.corners[0].vertexIndex].position,
                by: submodelTransform.orientation
            )
            let firstWorld = object.position + transform(firstLocal, by: object.orientation)
            guard !cullBackfaces
                    || dot(camera.position - firstWorld, transformedNormal) >= 0 else {
                continue
            }
            let vertices = face.corners.map { corner in
                let source = submodel.vertices[corner.vertexIndex]
                let local = submodelTransform.origin
                    + transform(
                        source.position,
                        by: submodelTransform.orientation
                    )
                return WorldRenderVertex(
                    position: object.position + transform(local, by: object.orientation),
                    u: corner.u,
                    v: corner.v,
                    lightmapU: 0,
                    lightmapV: 0,
                    alpha: source.alpha
                )
            }
            var indices: [UInt32] = []
            for index in 1..<(vertices.count - 1) {
                indices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
            }
            let blend: PresentationBlend
            switch face.material {
            case let .texture(texture):
                guard let material = materialByTexture[texture] else {
                    preconditionFailure("validated model materials must resolve")
                }
                blend = material.blend
            case .sourceColor:
                blend = .sourceAlpha(opacity: 255)
            }
            let item = ModelDrawItem(
                objectHandle: object.handle,
                roomSourceIndex: roomSourceIndex,
                model: model.source,
                submodelIndex: submodel.sourceIndex,
                faceIndex: faceIndex,
                material: face.material,
                blend: blend,
                vertices: vertices,
                triangleIndices: indices
            )
            switch blend {
            case .opaque: opaque.append(item)
            case .sourceAlpha, .additiveSourceAlpha: alpha.append(item)
            }
        }
    }
    return opaque + alpha
}

let trainingDodgeProjectilePresentationCapacity = 8
let trainingScriptActionCounterMaximum = 100_000

func extractPreparedTrainingDodgeProjectileDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
    guard let dodge = level.trainingDodgeAttempt,
        let turret = level.objects.first(where: {
            $0.handle == dodge.dodgeTurretObjectHandle
        }),
        case .room(let roomSourceIndex) = turret.location
    else {
        return []
    }
    return extractTrainingDodgeProjectileDrawItems(
        level,
        projectiles: (0..<trainingDodgeProjectilePresentationCapacity)
            .map { _ in
                .init(
                    position: turret.position,
                    velocity:
                        turret.orientation.forward
                        * dodge.turret.projectileSpeed,
                    roomSourceIndex: roomSourceIndex,
                    model: dodge.turret.projectileModel
                )
            },
        camera: .trainingRoom3
    )
}

func extractTrainingDodgeProjectileDrawItems(
    _ level: Level,
    projectiles: [TrainingDodgeProjectileFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let dodge = level.trainingDodgeAttempt,
        let model = level.models.first(where: {
            $0.source == dodge.turret.projectileModel
        })
    else {
        return []
    }
    precondition(
        projectiles.count <= trainingDodgeProjectilePresentationCapacity
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return projectiles.enumerated().flatMap { slot, projectile in
        let forward = sourceVectorNormalized(projectile.velocity)
        let referenceUp =
            abs(forward.y) < 0.99
            ? Vector3(x: 0, y: 1, z: 0)
            : Vector3(x: 1, y: 0, z: 0)
        let right = sourceVectorNormalized(sourceVectorCross(referenceUp, forward))
        let up = sourceVectorCross(forward, right)
        let object = PlacedObject(
            handle: UInt32.max - UInt32(slot),
            type: 5,
            storedID: 0,
            definition: nil,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(projectile.roomSourceIndex),
            position: projectile.position,
            orientation: .init(
                right: right,
                up: up,
                forward: forward
            ),
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

private let trainingBlueLaserPresentationCapacity = 40
let playerConcussionMissilePresentationCapacity = 6

func extractPreparedTrainingBlueLaserDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
    guard let handoff =
            level.trainingDodgeAttempt?.maneuverFollow?
                .destructionHandoff,
          let destroyBot1 = level.objects.first(where: {
              $0.handle == handoff.destroyBot1ObjectHandle
          }),
          case let .room(roomSourceIndex) = destroyBot1.location
    else {
        return []
    }
    return extractTrainingBlueLaserDrawItems(
        level,
        projectiles:
            (0..<trainingBlueLaserPresentationCapacity).map {
                _ in
                .init(
                    position: destroyBot1.position,
                    velocity:
                        destroyBot1.orientation.forward
                            * handoff.combat.projectileSpeed,
                    roomSourceIndex: roomSourceIndex,
                    model: handoff.projectileModel
                )
            },
        camera: .trainingRoom3
    )
}

func extractTrainingBlueLaserDrawItems(
    _ level: Level,
    projectiles: [TrainingBlueLaserProjectileFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let handoff =
            level.trainingDodgeAttempt?.maneuverFollow?
                .destructionHandoff,
          let model = level.models.first(where: {
              $0.source == handoff.projectileModel
          })
    else {
        return []
    }
    precondition(
        projectiles.count
            <= trainingBlueLaserPresentationCapacity
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return projectiles.enumerated().flatMap {
        slot, projectile in
        let forward = sourceVectorNormalized(projectile.velocity)
        let referenceUp =
            abs(forward.y) < 0.99
            ? Vector3(x: 0, y: 1, z: 0)
            : Vector3(x: 1, y: 0, z: 0)
        let right = sourceVectorNormalized(sourceVectorCross(referenceUp, forward))
        let up = sourceVectorCross(forward, right)
        let object = PlacedObject(
            handle:
                UInt32.max
                    - UInt32(
                        trainingBlueLaserPresentationCapacity
                    )
                    - UInt32(slot),
            type: 5,
            storedID: 0,
            definition: nil,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(projectile.roomSourceIndex),
            position: projectile.position,
            orientation: .init(
                right: right,
                up: up,
                forward: forward
            ),
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

func extractPreparedPlayerConcussionMissileDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
    guard let binding = level.shipDefinitions.first?.playerConcussion,
          let player = level.objects.first(where: {
              $0.handle == level.defaultPlayerBinding?.objectHandle
          }),
          case let .room(roomSourceIndex) = player.location else {
        return []
    }
    return extractPlayerConcussionMissileDrawItems(
        level,
        missiles: (0..<playerConcussionMissilePresentationCapacity).map {
            _ in .init(
                roomSourceIndex: roomSourceIndex,
                position: player.position,
                orientation: player.orientation,
                velocity: player.orientation.forward * binding.speed,
                model: binding.model,
                lightDistance: binding.lightDistance,
                lightPresentation: binding.lightPresentation
            )
        },
        camera: .trainingRoom3
    )
}

func extractPlayerConcussionMissileDrawItems(
    _ level: Level,
    missiles: [PlayerConcussionMissileFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let binding = level.shipDefinitions.first?.playerConcussion,
          let model = level.models.first(where: {
              $0.source == binding.model
          }) else {
        return []
    }
    precondition(missiles.count <= playerConcussionMissilePresentationCapacity)
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return missiles.enumerated().flatMap { slot, missile in
        let object = PlacedObject(
            handle: UInt32.max - 6_000 - UInt32(slot),
            type: 5,
            storedID: binding.weapon.storedIndex,
            definition: binding.weapon,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(missile.roomSourceIndex),
            position: missile.position,
            orientation: missile.orientation,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

func extractPreparedTrainingGuidebotYellowFlareDrawItems(
    _ level: Level
) -> [ModelDrawItem] {
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
    return extractTrainingGuidebotYellowFlareDrawItems(
        level,
        flares:
            (0..<combinedYellowFlarePresentationCapacity).map {
                _ in .init(
                    roomSourceIndex: roomSourceIndex,
                    position: guidebot.position,
                    orientation: guidebot.orientation,
                    velocity:
                        guidebot.orientation.forward
                            * definition.speed,
                    model: definition.model,
                    collisionRadius: definition.collisionRadius,
                    lifeRemaining: definition.lifetime,
                    sourceLightDistance:
                        definition.lightDistance,
                    lightDistance: definition.lightDistance,
                    lightPresentation:
                        definition.lightPresentation
                )
            },
        camera: .trainingRoom3
    )
}

func extractTrainingGuidebotYellowFlareDrawItems(
    _ level: Level,
    flares: [TrainingGuidebotYellowFlareFrame],
    camera: RoomCamera
) -> [ModelDrawItem] {
    guard let definition =
            level.trainingRobotGuidebotChain?.yellowFlare,
          let model = level.models.first(where: {
              $0.source == definition.model
          })
    else {
        return []
    }
    precondition(
        flares.count
            <= combinedYellowFlarePresentationCapacity
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map {
            ($0.texture, $0)
        }
    )
    return flares.enumerated().flatMap { slot, flare in
        let object = PlacedObject(
            handle: UInt32.max - 1_000 - UInt32(slot),
            type: 5,
            storedID: definition.source.storedIndex,
            definition: definition.source,
            instanceName: nil,
            flags: 0,
            doorShields: nil,
            location: .room(flare.roomSourceIndex),
            position: flare.position,
            orientation: flare.orientation,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: flare.lifeRemaining,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        return makeModelDrawItems(
            object: object,
            model: model,
            materialByTexture: materialByTexture,
            camera: camera,
            cullBackfaces: false
        )
    }
}

private func accumulatedModelOffsets(_ model: CanonicalModel) -> [Vector3] {
    var offsets = [Vector3?](repeating: nil, count: model.submodels.count)

    func resolve(_ sourceIndex: Int) -> Vector3 {
        if let offset = offsets[sourceIndex] { return offset }

        let submodel = model.submodels[sourceIndex]
        let parentOffset = submodel.parentIndex.map(resolve) ?? .zero
        let offset = parentOffset + submodel.offset
        offsets[sourceIndex] = offset
        return offset
    }

    return model.submodels.indices.map(resolve)
}

func extractSourceLightCoronas(
    _ level: Level,
    camera: RoomCamera,
    visibility: SourceVisibleWorld,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32? = nil
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
            visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
            startRoomSourceIndex: startRoomSourceIndex,
            excludedObjectHandle: excludedObjectHandle
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
                firstVertex: room.vertices[face.corners[0].vertexIndex],
                normal: faceNormal(room, face: face),
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
        let perpendicular = sourceVectorCross(second - first, third - first)
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
    visibleRoomSourceIndices: [Int],
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> Bool {
    let ray = destination - origin
    let distance = sqrt(dot(ray, ray))
    let direction = ray / distance
    let visibleRooms = Set(visibleRoomSourceIndices)
    if case let .wallHit(contact) = traceIndoorMovement(
        in: level,
        startRoom: startRoomSourceIndex,
        start: origin,
        end: destination,
        radius: 0
    ).outcome, contact.distance < distance - 0.000_1 {
        return true
    }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              object.type == 2 || object.type == 4,
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle],
              presentation.isVisible,
              let model = modelBySource[presentation.primaryModel] else {
            continue
        }
        let radius = sourceObjectPresentationSize(
            model: model,
            objectType: object.type
        )
        let originToCenter = object.position - origin
        let projectedDistance = dot(originToCenter, direction)
        guard projectedDistance > 0, projectedDistance < distance else { continue }
        let closest = origin + direction * projectedDistance
        let centerOffset = object.position - closest
        if dot(centerOffset, centerOffset) <= radius * radius {
            return true
        }
    }
    return false
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
    var objectClipWindowsByRoom: [Int: [SourceClipWindow]] = [:]

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
        objectClipWindowsByRoom[roomSourceIndex, default: []].append(window)
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
        portalEdges: portalEdges,
        objectClipWindowsByRoom: objectClipWindowsByRoom
    )
}

func sourceRoomThreeContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    precondition(
        room.sourceIndex == 3,
        "Slice 3 camera containment is defined only for source room 3"
    )
    return sourceConvexRoomContains(point, in: room)
}

func sourceConvexRoomContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    room.faces.allSatisfy { face in
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
        forward = sourceVectorNormalized(camera.target - camera.position)
        right = sourceVectorNormalized(sourceVectorCross(forward, camera.up))
        up = sourceVectorCross(right, forward)
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

    func depth(of point: Vector3) -> Float {
        dot(point - eye, forward)
    }
}

private struct ProjectedPoint {
    let x: Float
    let y: Float
    let depth: Float
}

private typealias ClipWindow = SourceClipWindow

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
