// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from physics/newstyle_fi.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): PolyCollideObject (:354),
// CollidePolygonModel (:330), CollideSubmodel (:307), and
// CollideSubmodelFacesUnsorted (:148); and from physics/findintersection.cpp,
// find_plane_line_intersection (:1004), check_point_to_face (:1093),
// check_vector_to_sphere_1 (:1174), IsPointInCylinder (:1260),
// check_vector_to_cylinder (:1284), check_sphere_to_face (:1596), and
// check_line_to_face (:1685). This is the sphere against polygon-model
// check of RESULT_CHECK_SPHERE_POLY and RESULT_CHECK_POLY_SPHERE
// (findintersection.cpp:3459-3548).
//
// Scope (M1 step 6): the model is at its rest pose. Submodel offsets
// accumulate, and animation, rotator, and turret angles are 0; the C++ uses
// the keyframe angles SetModelAnglesAndPos sets and the angles the last
// render left (architecture.md section 9). The package does not carry the
// SOF_SHELL and SOF_FRONTFACE submodel flags or the TF_FLY_THRU and
// TF_PASS_THRU texture flags, which only doors and see-through textures
// use; every textured face collides. A face with no texture (texnum -1, a
// flat color) never collides (:172), as in the C++. The movement AABB tests
// (:156, :159) only skip work and are left out.

import Foundation

/// A sphere's contact with a face: the sphere center at contact
/// (`intersection`), the touched point (`contact`), the distance moved to
/// it, and the wall normal.
struct PolygonHit: Equatable, Sendable {
    let intersection: Vector3
    let contact: Vector3
    let distance: Float
    let normal: Vector3
}

/// PolyCollideObject (newstyle_fi.cpp:354) for one object: the nearest hit
/// of a sphere of `radius` moving from `p0` to `p1` (world space) on `model`
/// placed at `position` with `orientation`, within the move, or `nil`.
func polyCollideObject(
    model: CanonicalModel,
    position: Vector3,
    orientation: Matrix3,
    p0: Vector3,
    p1: Vector3,
    radius: Float
) -> PolygonHit? {
    // newstyle_StartInstanceMatrix (:236): into the object's frame.
    func toModel(_ point: Vector3) -> Vector3 {
        let delta = point - position
        return Vector3(
            x: dot(delta, orientation.right),
            y: dot(delta, orientation.up),
            z: dot(delta, orientation.forward)
        )
    }
    func toWorld(_ point: Vector3) -> Vector3 {
        position + orientation.right * point.x + orientation.up * point.y
            + orientation.forward * point.z
    }
    func toWorldDirection(_ vector: Vector3) -> Vector3 {
        orientation.right * vector.x + orientation.up * vector.y
            + orientation.forward * vector.z
    }
    let modelP0 = toModel(p0)
    let modelP1 = toModel(p1)
    // fvi_FindIntersection starts with the move's length (:2727).
    var nearestDistance = vectorDistance(p0, p1) + 0.000_000_1
    var nearest: PolygonHit?
    let offsets = accumulatedModelOffsets(model)
    for (index, submodel) in model.submodels.enumerated() {
        // CollideSubmodel (:307) with the rest pose: the submodel frame is
        // the model frame moved by the accumulated offsets.
        let offset = offsets[index]
        let localP0 = modelP0 - offset
        let localP1 = modelP1 - offset
        for face in submodel.faces {
            guard case .texture = face.material, face.corners.count >= 3
            else {
                continue
            }
            let vertices = face.corners.map {
                submodel.vertices[$0.vertexIndex].position
            }
            // check_line_to_face (:1685) takes its plane point from the
            // vertex stored first in the submodel.
            let planeVertex = face.corners.indices.min {
                face.corners[$0].vertexIndex < face.corners[$1].vertexIndex
            }!
            guard let hit = checkLineToFace(
                p0: localP0,
                p1: localP1,
                faceNormal: face.normal,
                vertices: vertices,
                planePoint: vertices[planeVertex],
                radius: radius
            ), hit.distance < nearestDistance else {
                continue
            }
            nearestDistance = hit.distance
            nearest = PolygonHit(
                intersection: toWorld(hit.intersection + offset),
                contact: toWorld(hit.contact + offset),
                distance: hit.distance,
                normal: toWorldDirection(hit.normal)
            )
        }
    }
    return nearest
}

/// check_line_to_face (findintersection.cpp:1685).
private func checkLineToFace(
    p0: Vector3,
    p1: Vector3,
    faceNormal: Vector3,
    vertices: [Vector3],
    planePoint: Vector3,
    radius: Float
) -> PolygonHit? {
    guard let plane = findPlaneLineIntersection(
        planePoint: planePoint,
        planeNormal: faceNormal,
        p0: p0,
        p1: p1,
        radius: radius
    ) else {
        return nil
    }
    return checkSphereToFace(
        contact: plane.contact,
        intersection: plane.intersection,
        p0: p0,
        p1: p1,
        faceNormal: faceNormal,
        vertices: vertices,
        radius: radius
    )
}

/// find_plane_line_intersection (findintersection.cpp:1004): where the
/// sphere's center meets the face plane, and the touched point.
private func findPlaneLineIntersection(
    planePoint: Vector3,
    planeNormal: Vector3,
    p0: Vector3,
    p1: Vector3,
    radius: Float
) -> (intersection: Vector3, contact: Vector3)? {
    let line = p1 - p0
    let projectedLine = dot(planeNormal, line)
    if projectedLine >= 0 { return nil }
    var projectedPoint = dot(planeNormal, planePoint - p0)
    if projectedPoint > 0 { return nil }
    projectedPoint += radius
    if projectedPoint > 0, projectedLine < 0 {
        return (p0, p0 + planeNormal * (-radius + projectedPoint))
    }
    if projectedPoint <= projectedLine { return nil }
    let intersection: Vector3
    if abs(projectedLine) <= 0.000_000_000_01 {
        let planeDistance = dot(p1 - planePoint, planeNormal)
        if planeDistance >= radius { return nil }
        intersection = p1 + planeNormal * (radius - planeDistance)
    } else {
        intersection = p0 + line * (projectedPoint / projectedLine)
    }
    return (intersection, intersection + planeNormal * -radius)
}

/// check_point_to_face (findintersection.cpp:1093): a bit per edge the
/// point is outside of, in the plane of the normal's largest component.
private func checkPointToFace(
    _ point: Vector3,
    faceNormal: Vector3,
    vertices: [Vector3]
) -> UInt32 {
    func component(_ vector: Vector3, _ index: Int) -> Float {
        index == 0 ? vector.x : index == 1 ? vector.y : vector.z
    }
    let magnitudes = [abs(faceNormal.x), abs(faceNormal.y), abs(faceNormal.z)]
    let biggest: Int
    if magnitudes[0] > magnitudes[1] {
        biggest = magnitudes[0] > magnitudes[2] ? 0 : 2
    } else {
        biggest = magnitudes[1] > magnitudes[2] ? 1 : 2
    }
    // ij_table (:1086).
    let table = [(2, 1), (0, 2), (1, 0)]
    let (i, j) = component(faceNormal, biggest) > 0
        ? table[biggest]
        : (table[biggest].1, table[biggest].0)
    let checkI = component(point, i)
    let checkJ = component(point, j)
    var edgemask: UInt32 = 0
    for edge in vertices.indices {
        let v0 = vertices[edge]
        let v1 = vertices[(edge + 1) % vertices.count]
        let edgeI = component(v1, i) - component(v0, i)
        let edgeJ = component(v1, j) - component(v0, j)
        let toCheckI = checkI - component(v0, i)
        let toCheckJ = checkJ - component(v0, j)
        if toCheckI * edgeJ - toCheckJ * edgeI < 0 {
            edgemask |= 1 << UInt32(edge)
        }
    }
    return edgemask
}

/// check_sphere_to_face (findintersection.cpp:1596): inside the face, or
/// the nearest edge cylinder the sphere meets.
private func checkSphereToFace(
    contact: Vector3,
    intersection: Vector3,
    p0: Vector3,
    p1: Vector3,
    faceNormal: Vector3,
    vertices: [Vector3],
    radius: Float
) -> PolygonHit? {
    var edgemask = checkPointToFace(
        contact,
        faceNormal: faceNormal,
        vertices: vertices
    )
    if edgemask == 0 {
        return PolygonHit(
            intersection: intersection,
            contact: contact,
            distance: vectorDistance(p0, intersection),
            normal: faceNormal
        )
    }
    if radius == 0 { return nil }
    var hit: PolygonHit?
    var end = p1
    for edge in vertices.indices {
        if edgemask & 1 != 0,
           let edgeHit = checkVectorToCylinder(
               p0: p0,
               p1: end,
               radius: radius,
               edgeStart: vertices[edge],
               edgeEnd: vertices[(edge + 1) % vertices.count]
           ) {
            end = edgeHit.intersection
            hit = edgeHit
        }
        edgemask >>= 1
    }
    return hit
}

/// vm_NormalizeVector (vecmat/vector.cpp:175): a zero vector becomes
/// (1, 0, 0) and its length is 0.
private func sourceNormalize(_ vector: inout Vector3) -> Float {
    let length = sqrt(dot(vector, vector))
    if length > 0 {
        vector = vector / length
    } else {
        vector = Vector3(x: 1, y: 0, z: 0)
        return 0
    }
    return length
}

/// IsPointInCylinder (findintersection.cpp:1260): whether the start point
/// is already inside the edge's cylinder, and whether it moves further in.
private func isPointInCylinder(
    cylinderPoint: Vector3,
    direction: Vector3,
    length: Float,
    radius: Float,
    point: Vector3,
    moveDirection: Vector3
) -> (normal: Vector3, collides: Bool)? {
    let along = dot(point - cylinderPoint, direction)
    if along < 0 || along > length { return nil }
    var normal = point - (cylinderPoint + direction * along)
    if sourceNormalize(&normal) >= radius { return nil }
    return (normal, dot(normal, moveDirection) < 0)
}

/// check_vector_to_cylinder (findintersection.cpp:1284): the sphere's
/// nearest contact with an edge, its sides or its end points.
private func checkVectorToCylinder(
    p0: Vector3,
    p1: Vector3,
    radius: Float,
    edgeStart: Vector3,
    edgeEnd: Vector3
) -> PolygonHit? {
    var edge = edgeEnd - edgeStart
    var move3 = p1 - p0
    let moveLength3 = sourceNormalize(&move3)
    let edgeLength = sourceNormalize(&edge)
    if let initial = isPointInCylinder(
        cylinderPoint: edgeStart,
        direction: edge,
        length: edgeLength,
        radius: radius,
        point: p0,
        moveDirection: move3
    ) {
        guard initial.collides else { return nil }
        return PolygonHit(
            intersection: p0,
            contact: p0 - initial.normal * radius,
            distance: 0,
            normal: initial.normal
        )
    }
    // vm_VectorToMatrix(&edge_orient, &edgevec, NULL, NULL).
    let frame = forwardOnlyMatrix(edge)
    func project(_ vector: Vector3) -> Vector3 {
        Vector3(x: dot(vector, frame.right), y: dot(vector, frame.up), z: 0)
    }
    let po0 = project(p0 - edgeStart)
    let po1 = project(p1 - edgeStart)
    var move = po1 - po0
    let moveLength = sourceNormalize(&move)
    let along = -dot(move, po0)
    let closest = po0 + move * along
    let distanceFromOrigin = sqrt(dot(closest, closest))
    if distanceFromOrigin >= radius { return nil }
    let toIntersection = sqrt(
        radius * radius - distanceFromOrigin * distanceFromOrigin
    )
    var t: [Float] = [
        (along + toIntersection) / moveLength,
        (along - toIntersection) / moveLength,
        0, 0,
    ]
    var valid = [t[0] >= 0 && t[0] <= 1, t[1] >= 0 && t[1] <= 1, false, false]
    var intersections = [Vector3](repeating: .zero, count: 4)
    var contacts = [Vector3](repeating: .zero, count: 4)
    var distances = [Float](repeating: 0, count: 4)
    var validHit = false
    for index in 0..<2 where valid[index] {
        intersections[index] = p0 + move3 * (moveLength3 * t[index])
        let edgeT = dot(intersections[index] - edgeStart, edge) / edgeLength
        if edgeT >= 0, edgeT <= 1 {
            distances[index] = moveLength3 * t[index]
            contacts[index] = edgeStart
                + edge * dot(intersections[index] - edgeStart, edge)
            validHit = true
        } else {
            valid[index] = false
        }
    }
    // The end spheres. The C++ aims both contacts at the edge's end point
    // (:1396, :1405).
    for (index, center) in [(2, edgeStart), (3, edgeEnd)] {
        if let sphere = checkVectorToSphere1(
            p0: p0,
            p1: p1,
            center: center,
            radius: radius
        ) {
            intersections[index] = sphere.intersection
            distances[index] = sphere.distance
            t[index] = sphere.distance / moveLength3
            valid[index] = true
            validHit = true
            var toEnd = edgeEnd - sphere.intersection
            _ = sourceNormalize(&toEnd)
            contacts[index] = sphere.intersection + toEnd * radius
        }
    }
    guard validHit else { return nil }
    var best = -1
    for index in 0..<4 where valid[index] {
        if best == -1 || distances[index] < distances[best] {
            best = index
        }
    }
    var normal = intersections[best] - contacts[best]
    _ = sourceNormalize(&normal)
    return PolygonHit(
        intersection: intersections[best],
        contact: contacts[best],
        distance: distances[best],
        normal: normal
    )
}

/// DoVectorToMatrix with only a forward vector (vecmat/vector.cpp:474,
/// the bad_vector2 path).
private func forwardOnlyMatrix(_ forward: Vector3) -> Matrix3 {
    var z = forward
    _ = sourceNormalize(&z)
    if z.x == 0, z.z == 0 {
        return Matrix3(
            right: Vector3(x: 1, y: 0, z: 0),
            up: Vector3(x: 0, y: 0, z: z.y < 0 ? 1 : -1),
            forward: z
        )
    }
    var x = Vector3(x: z.z, y: 0, z: -z.x)
    _ = sourceNormalize(&x)
    return Matrix3(right: x, up: sourceVectorCross(z, x), forward: z)
}

/// check_vector_to_sphere_1 (findintersection.cpp:1174) with f_correcting
/// false and f_init_collisions true, as check_vector_to_cylinder calls it.
private func checkVectorToSphere1(
    p0: Vector3,
    p1: Vector3,
    center: Vector3,
    radius: Float
) -> (intersection: Vector3, distance: Float)? {
    guard let distance = checkVectorToSphere(
        start: p0,
        end: p1,
        center: center,
        radius: radius
    ) else {
        return nil
    }
    let line = p1 - p0
    let length = sqrt(dot(line, line))
    return (p0 + line * (distance / length), distance)
}
