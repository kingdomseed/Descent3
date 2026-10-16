import XCTest

// The generic page and model gun readers of D3Import (GenericPage.swift)
// against synthetic table and OOF bytes laid out as
// mng_ReadNewGenericPage (manage/generic.cpp:1083) and ReadNewModelFile
// (model/polymodel.cpp:1618, :1686) read them.
final class GenericPageImportTests: XCTestCase {
    /// Versions below 26 carry a third, obsolete object sound, which the
    /// reader must consume (generic.cpp:1278-1281); otherwise every later
    /// sound name shifts by one.
    func testVersion24And25PagesSkipTheObsoleteThirdObjectSound() throws {
        for version in [24, 25, 26] {
            let pages = try parseRetailGenericPages(
                syntheticGenericPageTable(version: UInt16(version))
            )
            let page = try XCTUnwrap(pages.first, "version \(version)")
            XCTAssertEqual(page.name, "Synthetic Robot", "version \(version)")
            XCTAssertEqual(
                page.fireSoundNames[0][0], "FireSound", "version \(version)"
            )
            XCTAssertEqual(
                page.fireSoundNames[20][7], "LastFireSound",
                "version \(version)"
            )
            // mng_ReadPhysicsChunk, the death spew, and sounds[GSI_EXPLODE]
            // (generic.cpp:1237-1244, :1274).
            XCTAssertEqual(page.physics.mass, 40)
            XCTAssertEqual(page.physics.drag, 60)
            XCTAssertEqual(page.physics.flags, 0x3)
            XCTAssertEqual(page.physics.numberOfBounces, -1)
            XCTAssertEqual(page.physics.restitution, 0.5)
            XCTAssertEqual(
                page.physics.rotationalVelocity, .init(x: 1, y: 2, z: 3)
            )
            XCTAssertEqual(page.deathSpew, CanonicalDeathSpew(
                flags: 0,
                entries: [
                    .init(pageName: "Energy", percent: 0.3, number: 2),
                    .init(pageName: "Shield", percent: 0.4, number: 1),
                ]
            ))
            XCTAssertEqual(page.explodeSoundName, "ExplodeSound")
        }
    }

    /// A model may hold at most MAX_WBS_PER_OBJ (21) weapon batteries
    /// (robotfirestruct.h:32): the page's static_wb and the runtime's
    /// dynamic batteries are fixed arrays of that size.
    func testModelWithMoreThan21WeaponBatteriesIsRejected() throws {
        XCTAssertEqual(
            try readOutrageModelGuns(syntheticModel(batteries: 21), name: "ok")
                .batteries.count,
            21
        )
        XCTAssertThrowsError(
            try readOutrageModelGuns(
                syntheticModel(batteries: 22), name: "too many"
            )
        ) {
            XCTAssertEqual(
                $0 as? GenericPageImportError, .invalidModelGuns("too many")
            )
        }
    }
}

/// One PAGETYPE_GENERIC page of `version` in a table file.
func syntheticGenericPageTable(
    version: UInt16, name: String = "Synthetic Robot", model: String = "robot.oof",
    spew: String? = nil, explodeSound: String = "ExplodeSound", module: String = "",
    flags: UInt32 = 0, weapon: String = ""
) -> Data {
    var page = Data()
    func u8(_ value: UInt8) { page.append(value) }
    func u16(_ value: UInt16) {
        page.append(UInt8(value & 0xff))
        page.append(UInt8(value >> 8))
    }

    func u32(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            page.append(UInt8((value >> UInt32(shift)) & 0xff))
        }
    }

    func f32(_ value: Float) { u32(value.bitPattern) }
    func string(_ value: String) {
        page.append(contentsOf: Array(value.utf8))
        page.append(0)
    }

    func zeros(_ count: Int) { page.append(Data(count: count)) }

    u16(version)
    u8(2)                                   // OBJ_ROBOT
    string(name)
    string(model)
    string("")
    string("")
    zeros(12)                               // impact size, time, damage
    zeros(2)                                // score
    string("")                              // script name
    string(module)                          // version >= 18
    string("")                              // version >= 19
    u8(0)                                   // no description
    string("")                              // icon name
    zeros(8)                                // LOD distances
    // Physics chunk: mass, drag, full_thrust, flags, rotdrag,
    // full_rotthrust, num_bounces, velocity.z, rotvel, wiggle, coeff,
    // hit_die_dot, turnroll.
    f32(40); f32(60); f32(0); u32(0x3); f32(115); f32(0)
    u32(UInt32(bitPattern: -1)); f32(0); f32(1); f32(2); f32(3)
    f32(0); f32(0); f32(0.5); f32(0); f32(0); f32(0)
    f32(5)                                  // size
    zeros(4 + 12 + 4 + 4 + 4 + 12 + 4 + 4 + 1 + 1) // lighting chunk
    zeros(4)                                // hit points
    u32(flags)                              // flags
    zeros(4 + 4)                            // AI flags, class, types
    zeros(4 * 4)                            // fov, velocities, turn rate
    u32(0)                                  // notify flags
    zeros(4 * 27)                           // the other AI floats
    for (percent, number, name) in [       // death spew
        (Float(0.3), UInt16(2), "Energy"), (Float(0.4), UInt16(1), "Shield"),
    ] {
        u8(0)
        f32(percent)
        u16(number)
        string(spew ?? name)
    }
    zeros(5 * 24 * (2 + 2 + 4))             // animations (version >= 20)
    for _ in 0..<21 {                       // weapon battery chunk, v2
        zeros(8 + 16)
        zeros(8 * (1 + 4 + 16))
        zeros(1 + 2 + 1 + 4 + 4 + 4 + 2 + 1)
    }
    for _ in 0..<(21 * 8) { string(weapon) } // weapon names
    string("Sound0")
    string(explodeSound)
    if version < 26 { string("ObsoleteSound") }
    for index in 0..<5 { string("AISound\(index)") }
    for battery in 0..<21 {
        for mask in 0..<8 {
            string(
                battery == 0 && mask == 0 ? "FireSound"
                    : battery == 20 && mask == 7 ? "LastFireSound" : ""
            )
        }
    }
    for _ in 0..<(5 * 24) { string("") }    // animation sounds
    zeros(4)                                // respawn scalar
    u16(0)                                  // no death types

    var table = Data([10])
    let length = UInt32(page.count + 4)
    for shift in stride(from: 0, to: 32, by: 8) {
        table.append(UInt8((length >> UInt32(shift)) & 0xff))
    }
    table.append(page)
    return table
}

/// An OOF with one gun point and `batteries` WBAT batteries that each fire
/// it.
private func syntheticModel(batteries: Int) -> Data {
    var data = Data("PSPO".utf8)
    func i32(_ value: Int32, into target: inout Data) {
        let bits = UInt32(bitPattern: value)
        for shift in stride(from: 0, to: 32, by: 8) {
            target.append(UInt8((bits >> UInt32(shift)) & 0xff))
        }
    }

    func chunk(_ name: String, _ body: Data) {
        data.append(Data(name.utf8))
        i32(Int32(body.count), into: &data)
        data.append(body)
    }
    i32(2_300, into: &data)
    var guns = Data()
    i32(1, into: &guns)
    i32(0, into: &guns)                    // parent
    for _ in 0..<6 { i32(0, into: &guns) } // position and normal
    chunk("GPNT", guns)
    var wbat = Data()
    i32(Int32(batteries), into: &wbat)
    for _ in 0..<batteries {
        i32(1, into: &wbat)
        i32(0, into: &wbat)
        i32(0, into: &wbat)
    }
    chunk("WBAT", wbat)
    return data
}
