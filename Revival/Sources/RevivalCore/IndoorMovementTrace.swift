import Foundation

func canonicalFaceNormal(room: LevelRoom, face: LevelFace) -> Vector3? {
    var best = Vector3.zero
    var bestMagnitudeSquared: Float = 0
    for index in face.corners.indices {
        let a = room.vertices[face.corners[index].vertexIndex]
        let b = room.vertices[face.corners[(index + 1) % face.corners.count].vertexIndex]
        let c = room.vertices[face.corners[(index + 2) % face.corners.count].vertexIndex]
        let candidate = levelCross(
            .init(x: b.x - a.x, y: b.y - a.y, z: b.z - a.z),
            .init(x: c.x - b.x, y: c.y - b.y, z: c.z - b.z)
        )
        let magnitudeSquared = levelDot(candidate, candidate)
        guard magnitudeSquared.isFinite else { return nil }
        if magnitudeSquared > bestMagnitudeSquared {
            best = candidate
            bestMagnitudeSquared = magnitudeSquared
        }
    }
    let magnitude = sqrt(bestMagnitudeSquared)
    guard magnitude >= 0.035 else { return nil }
    let normal = Vector3(
        x: best.x / magnitude,
        y: best.y / magnitude,
        z: best.z / magnitude
    )
    guard normal.x.isFinite, normal.y.isFinite, normal.z.isFinite else { return nil }
    return normal
}

struct IndoorWallContact: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let contactPoint: Vector3
    let normal: Vector3
    let distance: Float
}

enum IndoorMovementTraceOutcome: Equatable, Sendable {
    case noHit
    case wallHit(IndoorWallContact)
}

struct IndoorPortalCrossing: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
}

struct IndoorMovementTrace: Equatable, Sendable {
    let outcome: IndoorMovementTraceOutcome
    let finalPosition: Vector3
    let containingRoomSourceIndex: Int
    let visitedRoomSourceIndices: [Int]
    let passedPortalFaces: [IndoorPortalCrossing]
}

func traceIndoorMovement(
    in level: Level,
    startRoom: Int,
    start: Vector3,
    end: Vector3,
    radius: Float
) -> IndoorMovementTrace {
    precondition(radius.isFinite && radius >= 0)
    precondition(isFinite(start) && isFinite(end))

    let rooms = Dictionary(uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) })
    let surfacePhysics = Dictionary(
        uniqueKeysWithValues: level.surfacePhysics.map { ($0.texture, $0.behavior) }
    )
    precondition(rooms[startRoom] != nil)

    let movement = levelSubtract(end, start)
    let movementLength = sqrt(levelDot(movement, movement))
    var visited: [Int] = []
    var visitedSet: Set<Int> = []
    var passedPortalFaces: [IndoorPortalCrossing] = []
    var nearest: IndoorWallContact?
    var nearestNormalCount = 0

    func visit(_ roomIndex: Int) {
        guard visitedSet.insert(roomIndex).inserted else { return }
        let room = rooms[roomIndex]!
        visited.append(roomIndex)

        var reachedPortals: [Int: Float] = [:]
        for (faceIndex, face) in room.faces.enumerated() {
            guard let hit = sweptSphereFaceHit(
                room: room,
                face: face,
                start: start,
                movement: movement,
                radius: radius
            ) else {
                continue
            }

            let portalIndex = face.portalIndex
            let portal = portalIndex.map { room.portals[$0] }
            if indoorFaceIsPassable(
                portal: portal,
                face: face,
                surfacePhysics: surfacePhysics
            ) {
                if let portalIndex {
                    reachedPortals[portalIndex] = min(
                        reachedPortals[portalIndex] ?? 1,
                        hit.fraction
                    )
                }
                continue
            }

            let candidate = IndoorWallContact(
                roomSourceIndex: roomIndex,
                faceIndex: faceIndex,
                contactPoint: hit.contactPoint,
                normal: hit.normal,
                distance: movementLength * hit.fraction
            )
            if nearest == nil || candidate.distance < nearest!.distance {
                nearest = candidate
                nearestNormalCount = 1
            } else if candidate.distance == nearest!.distance,
                      nearestNormalCount < 2 {
                nearest = IndoorWallContact(
                    roomSourceIndex: nearest!.roomSourceIndex,
                    faceIndex: nearest!.faceIndex,
                    contactPoint: nearest!.contactPoint,
                    normal: normalized(add(nearest!.normal, candidate.normal))!,
                    distance: nearest!.distance
                )
                nearestNormalCount += 1
            }
        }

        for (portalIndex, portal) in room.portals.enumerated() {
            guard let fraction = reachedPortals[portalIndex],
                  movementLength * fraction
                    <= (nearest?.distance ?? movementLength)
            else {
                continue
            }
            if let centerHit = sweptSphereFaceHit(
                room: room,
                face: room.faces[portal.faceIndex],
                start: start,
                movement: movement,
                radius: 0
            ), movementLength * centerHit.fraction
                <= (nearest?.distance ?? movementLength) {
                passedPortalFaces.append(.init(
                    roomSourceIndex: roomIndex,
                    faceIndex: portal.faceIndex
                ))
            }
            visit(portal.connectedRoom)
        }
    }

    visit(startRoom)

    if let nearest {
        let fraction = movementLength > 0 ? nearest.distance / movementLength : 0
        let finalPosition = add(start, scaled(movement, fraction))
        let containingRoom = radius == 0
            ? nearest.roomSourceIndex
            : visited.first {
                indoorRoomContains(finalPosition, room: rooms[$0]!)
            } ?? startRoom
        return IndoorMovementTrace(
            outcome: .wallHit(nearest),
            finalPosition: finalPosition,
            containingRoomSourceIndex: containingRoom,
            visitedRoomSourceIndices: visited,
            passedPortalFaces: passedPortalFaces
        )
    }

    let containingRoom = visited.first {
        indoorRoomContains(end, room: rooms[$0]!)
    } ?? startRoom
    return IndoorMovementTrace(
        outcome: .noHit,
        finalPosition: end,
        containingRoomSourceIndex: containingRoom,
        visitedRoomSourceIndices: visited,
        passedPortalFaces: passedPortalFaces
    )
}

func containingIndoorRoomSourceIndex(
    in level: Level,
    position: Vector3,
    candidates: [Int]? = nil
) -> Int? {
    guard isFinite(position) else { return nil }
    let rooms = Dictionary(uniqueKeysWithValues: level.rooms.map {
        ($0.sourceIndex, $0)
    })
    let sourceIndices = candidates ?? level.rooms.map(\.sourceIndex).sorted()
    return sourceIndices.first {
        rooms[$0].map { indoorRoomContains(position, room: $0) } == true
    }
}

private func indoorFaceIsPassable(
    portal: LevelPortal?,
    face: LevelFace,
    surfacePhysics: [SourceResource: SurfacePhysicsBehavior]
) -> Bool {
    if surfacePhysics[face.texture]! == .passThrough {
        return true
    }
    guard let portal else { return false }
    let rendersFaces: UInt32 = 0x0000_0001
    let renderedFlythrough: UInt32 = 0x0000_0002
    return portal.flags & rendersFaces == 0
        || portal.flags & renderedFlythrough != 0
}

private struct IndoorFaceHit {
    let fraction: Float
    let contactPoint: Vector3
    let normal: Vector3
}

private func sweptSphereFaceHit(
    room: LevelRoom,
    face: LevelFace,
    start: Vector3,
    movement: Vector3,
    radius: Float
) -> IndoorFaceHit? {
    let normal = canonicalFaceNormal(room: room, face: face)!
    let planeVertexIndex = face.corners.map(\.vertexIndex).min()!
    let planePoint = room.vertices[planeVertexIndex]
    let projectedMovement = levelDot(movement, normal)
    guard projectedMovement < 0 else { return nil }

    let startDistance = levelDot(levelSubtract(planePoint, start), normal)
    guard startDistance <= 0 else { return nil }
    let shiftedDistance = startDistance + radius
    let planeFraction: Float
    if shiftedDistance > 0 {
        planeFraction = 0
    } else {
        guard shiftedDistance > projectedMovement else { return nil }
        planeFraction = shiftedDistance / projectedMovement
    }

    var nearest: IndoorFaceHit?
    let centerAtPlane = add(start, scaled(movement, planeFraction))
    let planeContact = levelSubtract(centerAtPlane, scaled(normal, radius))
    if pointIsInsideFace(planeContact, room: room, face: face, normal: normal) {
        nearest = .init(
            fraction: planeFraction,
            contactPoint: planeContact,
            normal: normal
        )
    }

    guard radius > 0 else { return nearest }
    for cornerIndex in face.corners.indices {
        let a = room.vertices[face.corners[cornerIndex].vertexIndex]
        let b = room.vertices[
            face.corners[(cornerIndex + 1) % face.corners.count].vertexIndex
        ]
        guard let edgeHit = sweptSphereSegmentHit(
            start: start,
            movement: movement,
            radius: radius,
            a: a,
            b: b
        ) else {
            continue
        }
        if nearest == nil || edgeHit.fraction < nearest!.fraction {
            nearest = edgeHit
        }
    }
    return nearest
}

private func sweptSphereSegmentHit(
    start: Vector3,
    movement: Vector3,
    radius: Float,
    a: Vector3,
    b: Vector3
) -> IndoorFaceHit? {
    let edge = levelSubtract(b, a)
    let edgeLengthSquared = levelDot(edge, edge)
    precondition(edgeLengthSquared > 0)

    let fromA = levelSubtract(start, a)
    let startAlong = levelDot(fromA, edge) / edgeLengthSquared
    let movementAlong = levelDot(movement, edge) / edgeLengthSquared
    let perpendicularStart = levelSubtract(fromA, scaled(edge, startAlong))
    let perpendicularMovement = levelSubtract(movement, scaled(edge, movementAlong))
    let quadraticA = levelDot(perpendicularMovement, perpendicularMovement)
    let quadraticB = 2 * levelDot(perpendicularStart, perpendicularMovement)
    let quadraticC = levelDot(perpendicularStart, perpendicularStart) - radius * radius

    var candidates: [IndoorFaceHit] = []
    if let fraction = firstUnitIntervalRoot(
        a: quadraticA,
        b: quadraticB,
        c: quadraticC
    ) {
        let along = startAlong + movementAlong * fraction
        if (0...1).contains(along) {
            let center = add(start, scaled(movement, fraction))
            let contactPoint = add(a, scaled(edge, along))
            if let normal = normalized(levelSubtract(center, contactPoint)) {
                candidates.append(
                    .init(
                        fraction: fraction,
                        contactPoint: contactPoint,
                        normal: normal
                    )
                )
            }
        }
    }
    if let aHit = sweptSpherePointHit(
        start: start,
        movement: movement,
        radius: radius,
        point: a
    ) {
        candidates.append(aHit)
    }
    if let bHit = sweptSpherePointHit(
        start: start,
        movement: movement,
        radius: radius,
        point: b
    ) {
        candidates.append(bHit)
    }
    return candidates.min { $0.fraction < $1.fraction }
}

private func sweptSpherePointHit(
    start: Vector3,
    movement: Vector3,
    radius: Float,
    point: Vector3
) -> IndoorFaceHit? {
    let relative = levelSubtract(start, point)
    guard let fraction = firstUnitIntervalRoot(
        a: levelDot(movement, movement),
        b: 2 * levelDot(relative, movement),
        c: levelDot(relative, relative) - radius * radius
    ) else {
        return nil
    }
    let center = add(start, scaled(movement, fraction))
    guard let normal = normalized(levelSubtract(center, point)) else { return nil }
    return .init(fraction: fraction, contactPoint: point, normal: normal)
}

private func firstUnitIntervalRoot(a: Float, b: Float, c: Float) -> Float? {
    if c <= 0 {
        return b < 0 ? 0 : nil
    }
    guard a > 0 else { return nil }
    let discriminant = b * b - 4 * a * c
    guard discriminant >= 0 else { return nil }
    let root = (-b - sqrt(discriminant)) / (2 * a)
    return (0...1).contains(root) ? root : nil
}

private func pointIsInsideFace(
    _ point: Vector3,
    room: LevelRoom,
    face: LevelFace,
    normal: Vector3
) -> Bool {
    let tolerance: Float = 0.0001
    for cornerIndex in face.corners.indices {
        let a = room.vertices[face.corners[cornerIndex].vertexIndex]
        let b = room.vertices[
            face.corners[(cornerIndex + 1) % face.corners.count].vertexIndex
        ]
        let edge = levelSubtract(b, a)
        let fromEdge = levelSubtract(point, a)
        if levelDot(levelCross(edge, fromEdge), normal) < -tolerance {
            return false
        }
    }
    return true
}

private func indoorRoomContains(_ point: Vector3, room: LevelRoom) -> Bool {
    let directions = [
        Vector3(x: 0.811_107, y: 0.324_443, z: 0.486_664),
        Vector3(x: -0.811_107, y: -0.324_443, z: -0.486_664),
    ]
    for direction in directions {
        var nearest: (fraction: Float, frontFacing: Bool)?
        for face in room.faces {
            let normal = canonicalFaceNormal(room: room, face: face)!
            let planeVertexIndex = face.corners.map(\.vertexIndex).min()!
            let denominator = levelDot(direction, normal)
            guard abs(denominator) > 0.000_001 else { continue }
            let planePoint = room.vertices[planeVertexIndex]
            let fraction = levelDot(levelSubtract(planePoint, point), normal) / denominator
            guard fraction >= 0 else { continue }
            let intersection = add(point, scaled(direction, fraction))
            guard pointIsInsideFace(
                intersection,
                room: room,
                face: face,
                normal: normal
            ) else {
                continue
            }
            if nearest == nil || fraction < nearest!.fraction {
                nearest = (fraction, denominator < 0)
            }
        }
        if let nearest {
            return nearest.frontFacing
        }
    }
    return false
}

private func add(_ a: Vector3, _ b: Vector3) -> Vector3 {
    .init(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
}

private func scaled(_ vector: Vector3, _ scalar: Float) -> Vector3 {
    .init(x: vector.x * scalar, y: vector.y * scalar, z: vector.z * scalar)
}

private func normalized(_ vector: Vector3) -> Vector3? {
    let magnitude = sqrt(levelDot(vector, vector))
    guard magnitude > 0 else { return nil }
    return scaled(vector, 1 / magnitude)
}
