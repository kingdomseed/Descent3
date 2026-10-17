import XCTest

// Sphere and polygon-model hits (Descent3/findintersection.cpp and
// newstyle_fi.cpp, PolyCollide.swift): the vector-to-sphere check, the
// player's move into a weapon, and a weapon against the ship's hull.
final class PolyCollideTests: XCTestCase {
    /// check_vector_to_sphere_1 with initial collisions
    /// (findintersection.cpp:1174-1245).
    func testVectorToSphereHitsOnEntryOrAtAnInsideStart() {
        let origin = Vector3.zero
        let ahead = Vector3(x: 0, y: 0, z: 10)
        // Entry: the center is 8 ahead, the radius 2.
        XCTAssertEqual(
            checkVectorToSphere(
                start: origin, end: ahead,
                center: Vector3(x: 0, y: 0, z: 8), radius: 2
            ),
            6
        )
        // A start inside the sphere hits at 0 while the move closes in.
        XCTAssertEqual(
            checkVectorToSphere(
                start: origin, end: ahead,
                center: Vector3(x: 0, y: 0, z: 1), radius: 2
            ),
            0
        )
        // No move, a move away, a pass to the side, and a stop short miss.
        XCTAssertNil(checkVectorToSphere(
            start: origin, end: origin,
            center: Vector3(x: 0, y: 0, z: 1), radius: 2
        ))
        XCTAssertNil(checkVectorToSphere(
            start: origin, end: Vector3(x: 0, y: 0, z: -10),
            center: Vector3(x: 0, y: 0, z: 1), radius: 2
        ))
        XCTAssertNil(checkVectorToSphere(
            start: origin, end: ahead,
            center: Vector3(x: 3, y: 0, z: 5), radius: 2
        ))
        XCTAssertNil(checkVectorToSphere(
            start: origin, end: ahead,
            center: Vector3(x: 0, y: 0, z: 13), radius: 2
        ))
    }
}
