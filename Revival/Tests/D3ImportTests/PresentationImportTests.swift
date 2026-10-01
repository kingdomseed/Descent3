import XCTest

// The presentation import stage (D3Import/PresentationImport.swift): the
// reached OOF models (polymodel.cpp ReadNewModelFile) with their gun
// points and properties, the ship pages' physics and batteries
// (shippage.cpp), the sound pages and PCM16 WAV payloads, and the texture
// names.
final class PresentationImportTests: XCTestCase {
    func testCanonicalizesStockEnergyTextureName() {
        XCTAssertEqual(
            canonicalPresentationTextureLogicalName("energy.TGA1"), "energy"
        )
        XCTAssertEqual(
            canonicalPresentationTextureLogicalName("FlarePuff"), "FlarePuff"
        )
    }

    func testParsesReachedShipPhysicsInReleasedFieldOrderAndTypesFlags() throws {
        let pages = try resolveRetailModelPages(
            table: makeRetailShipTablePage(includeBatteries: true)
                + makeRetailGenericModelTablePage(),
            overlay: Data()
        )
        XCTAssertNotNil(pages["invisiblepowerup"])
        let definition = try XCTUnwrap(
            pages[defaultShipPageName.lowercased()]?.shipDefinition
        )

        XCTAssertEqual(definition.name, "Pyro-GL")
        XCTAssertEqual(definition.presentationSize, 6.676084041595459)
        XCTAssertEqual(definition.physics.mass, 30)
        XCTAssertEqual(definition.physics.drag, 90)
        XCTAssertEqual(definition.physics.fullThrust, 5_400)
        XCTAssertEqual(
            definition.physics.behaviors, [.turnroll, .wiggle, .usesThrust]
        )
        XCTAssertEqual(definition.physics.rotationalDrag, 225)
        XCTAssertEqual(definition.physics.fullRotationalThrust, 6_860_000)
        XCTAssertEqual(definition.physics.numberOfBounces, -1)
        XCTAssertEqual(definition.physics.initialForwardVelocity, 0)
        XCTAssertEqual(definition.physics.initialAngularVelocity, .zero)
        XCTAssertEqual(definition.physics.wiggleAmplitude, 0.17)
        XCTAssertEqual(definition.physics.wigglesPerSecond, 0.9)
        XCTAssertEqual(definition.physics.coefficientOfRestitution, 1)
        XCTAssertEqual(definition.physics.hitDieDot, -1)
        XCTAssertEqual(definition.physics.maximumTurnrollRate, 8_000)
        XCTAssertEqual(definition.physics.turnrollRatio, 0.13)
        // The flare battery (FLARE_INDEX) is battery 20 of the 21.
        XCTAssertEqual(
            definition.weaponBatteries?[20].weaponNames.first, "Yellow flare"
        )
        XCTAssertEqual(definition.weaponBatteries?[20].fireMasks, [1])
        XCTAssertEqual(definition.weaponBatteries?[20].fireWaits, [1])
        XCTAssertEqual(
            definition.weaponBatteries?[20].fireSoundNames, ["Flare"]
        )
        // All 21 batteries, each with its first num_masks masks and waits.
        XCTAssertEqual(definition.weaponBatteries?.count, 21)
        XCTAssertEqual(
            definition.weaponBatteries?[10],
            .init(
                index: 10,
                fireFlags: 0,
                energyUsage: 0,
                ammoUsage: 1,
                fireMasks: [1, 2],
                fireWaits: [0.5, 0.5],
                flags: 0,
                fireSoundNames: ["concmissilefire71", "concmissilefire71"],
                weaponNames: ["Concussion", "Concussion", "", "", "", "",
                              "", ""]
            )
        )
    }

    func testReachedOOFPreservesCustomFacingAndRotationAndRejectsUnreachedPresentationProperties() throws {
        let texture = SourceResource(storedIndex: 0, sourceName: "Synthetic")
        let custom = try parseReachedOutrageModel(
            makeReachedOOFFixture(properties: "$custom"),
            sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
            textureResources: [texture]
        )

        XCTAssertEqual(custom.submodels[1].presentation, .custom)
        let facing = try parseReachedOutrageModel(
            makeReachedOOFFixture(properties: "$facing"),
            sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
            textureResources: [texture]
        )
        XCTAssertEqual(facing.submodels[1].presentation, .facing)
        // SOBJ's rad, and for a facing submodel half the square root of its
        // face's area (model/polymodel.cpp:1383, :1963-1972): the 31-gon
        // of radius 1 has area 31/2 sin(2 pi / 31).
        XCTAssertEqual(custom.submodels[1].radius, 1)
        let area = Float(31) / 2 * sin(2 * Float.pi / 31)
        XCTAssertEqual(
            try XCTUnwrap(facing.submodels[1].radius), sqrt(area) / 2,
            accuracy: 0.000_1
        )
        let rotating = try parseReachedOutrageModel(
            makeReachedOOFFixture(properties: "$rotate=1"),
            sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
            textureResources: [texture]
        )
        XCTAssertEqual(
            rotating.submodels[1].presentation,
            .rotate(rate: 1, axis: .init(x: 0, y: 1, z: 0))
        )
        let turret = try parseReachedOutrageModel(
            makeReachedOOFFixture(properties: "$fov=90.0,8.0,10.0\r\n"),
            sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
            textureResources: [texture]
        )
        XCTAssertEqual(
            turret.submodels[1].presentation,
            .turret(
                fieldOfView: 0.125, rotationsPerSecond: 0.125,
                thinkInterval: 10, axis: .init(x: 0, y: 1, z: 0)
            )
        )
        for properties in ["$thruster=1, 0.5, 0.25, 2"] {
            XCTAssertThrowsError(
                try parseReachedOutrageModel(
                    makeReachedOOFFixture(properties: properties),
                    sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
                    textureResources: [texture]
                )
            ) {
                XCTAssertEqual(
                    $0 as? OutrageModelImportError,
                    .unsupportedPresentation(properties)
                )
            }
        }
    }

    func testReachedOOFUsesFirstActualTransformedVertexAndDynamicGlowGeometry() throws {
        let sourceRadius = Float(bitPattern: 0x40d9_5869)
        let data = makeReachedOOFFixture(collisionRadius: sourceRadius)

        let model = try parseReachedOutrageModel(
            data, sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
            textureResources: [.init(storedIndex: 0, sourceName: "Synthetic")]
        )

        XCTAssertEqual(model.bounds.minimum.x, 104.00513, accuracy: 0.0001)
        XCTAssertEqual(model.bounds.maximum.x, 106, accuracy: 0.0001)
        XCTAssertEqual(model.bounds.minimum.y, -0.9987165, accuracy: 0.0001)
        XCTAssertEqual(model.bounds.maximum.y, 0.9987165, accuracy: 0.0001)
        XCTAssertEqual(model.collisionRadius.bitPattern, sourceRadius.bitPattern)
        XCTAssertNotEqual(model.collisionRadius, 200)
        XCTAssertEqual(model.submodels[0].vertices, [])
        XCTAssertEqual(model.submodels[1].faces[0].corners.count, 31)
        XCTAssertEqual(
            model.submodels[1].presentation,
            .glow(color: .init(x: 1, y: 0.5, z: 0.25), size: 2)
        )
        XCTAssertEqual(
            model.submodels[1].faces[0].material,
            .texture(.init(storedIndex: 0, sourceName: "Synthetic"))
        )
        XCTAssertEqual(model.sourceSHA256, canonicalSHA256(data))
        let decoded = try JSONDecoder().decode(
            CanonicalModel.self, from: JSONEncoder().encode(model)
        )
        XCTAssertEqual(decoded.collisionRadius.bitPattern, sourceRadius.bitPattern)
    }

    func testReachedOOFDiscardsUnreachedVertexNormalsAndRejectsMissingFaceTexture() throws {
        let data = makeReachedOOFWithNonfiniteVertexNormal()
        let texture = SourceResource(storedIndex: 0, sourceName: "Synthetic")

        let model = try parseReachedOutrageModel(
            data, sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
            textureResources: [texture]
        )
        let encoded = try JSONEncoder().encode(model)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let submodels = try XCTUnwrap(object["submodels"] as? [[String: Any]])
        let vertices = try XCTUnwrap(submodels[0]["vertices"] as? [[String: Any]])
        XCTAssertNil(vertices[0]["normal"])

        XCTAssertThrowsError(
            try parseReachedOutrageModel(
                data, sourceName: "Synthetic.OOF", sourceArchive: "d3.hog",
                textureResources: [nil]
            )
        ) {
            XCTAssertEqual(
                $0 as? OutrageModelImportError,
                .invalidIndex("missing texture slot")
            )
        }
    }

    func testReachedOOFResolvesSecurityCameraGunpointThroughItsParentChain() throws {
        let data = makeReachedOOFFixture(
            gunpoint: .init(
                parentSubmodelIndex: 1, position: .init(x: 1, y: 2, z: 3),
                forward: .init(x: 0, y: 0, z: -1)
            )
        )
        let gunpoint = try reachedOutrageModelGunpoint(data, index: 0)

        XCTAssertEqual(gunpoint.localPosition, .init(x: 1, y: 2, z: 3))
        XCTAssertEqual(gunpoint.position, .init(x: 101, y: 2, z: 3))
        XCTAssertEqual(gunpoint.forward, .init(x: 0, y: 0, z: -1))
    }

    func testReachedOOFGunpointRejectsUnsupportedContainerBeforeChunks() {
        let data = makeReachedOOFFixture(
            gunpoint: .init(
                parentSubmodelIndex: 1, position: .init(x: 1, y: 2, z: 3),
                forward: .init(x: 0, y: 0, z: -1)
            )
        )
        var badMagic = data
        badMagic[0] = Array("X".utf8)[0]
        XCTAssertThrowsError(
            try reachedOutrageModelGunpoint(badMagic, index: 0)
        ) {
            XCTAssertEqual($0 as? OutrageModelImportError, .invalidHeader)
        }

        var badVersion = data
        badVersion[4] = 0
        badVersion[5] = 0
        badVersion[6] = 0
        badVersion[7] = 0
        XCTAssertThrowsError(
            try reachedOutrageModelGunpoint(badVersion, index: 0)
        ) {
            XCTAssertEqual(
                $0 as? OutrageModelImportError, .unsupportedVersion(0)
            )
        }
    }

    func testRetailSoundPageResolvesPupCAndCanonicalizesPCM16WAV() throws {
        let page = makeRetailSoundTablePage(
            logicalName: "PupC1", sourceName: "PupC.wav", importVolume: 0.75
        )
        let resolved = try resolveRetailSoundPage(
            table: page, overlay: Data(), named: "PupC1"
        )
        XCTAssertEqual(resolved.logicalName, "PupC1")
        XCTAssertEqual(resolved.sourceName, "PupC.wav")
        XCTAssertEqual(resolved.flags, 0)
        XCTAssertEqual(resolved.loopStart, 0)
        XCTAssertEqual(resolved.loopEnd, 0)
        XCTAssertEqual(resolved.outerConeVolume, 360)
        XCTAssertEqual(resolved.innerConeAngle, 360)
        XCTAssertEqual(resolved.outerConeAngle, 360)
        XCTAssertEqual(resolved.maximumDistance, 1_000)
        XCTAssertEqual(resolved.minimumDistance, 0)
        XCTAssertEqual(resolved.importVolume, 0.75)

        let decoded = try decodeReachedPCM16WAV(
            makePCM16WAV(samples: [-32_768, 0, 32_767])
        )
        XCTAssertEqual(decoded.sampleRate, 22_050)
        XCTAssertEqual(decoded.channelCount, 1)
        XCTAssertEqual(decoded.frameCount, 3)
        XCTAssertEqual(
            decoded.pcm16LittleEndian,
            Data([0x00, 0x80, 0x00, 0x00, 0xff, 0x7f])
        )
    }

    func testReachedWAVRejectsTruncatedRIFFDeclaration() {
        var data = makePCM16WAV(samples: [-1, 0, 1])
        let declaredSize = UInt32(data.count - 8 + 4)
        data[4] = UInt8(declaredSize & 0xff)
        data[5] = UInt8((declaredSize >> 8) & 0xff)
        data[6] = UInt8((declaredSize >> 16) & 0xff)
        data[7] = UInt8((declaredSize >> 24) & 0xff)

        XCTAssertThrowsError(try decodeReachedPCM16WAV(data)) {
            XCTAssertEqual($0 as? ReachedWAVDecodeError, .truncated)
        }
    }
}

private func makeReachedOOFFixture(
    properties: String = "$glow=1, 0.5, 0.25, 2", collisionRadius: Float = 200,
    gunpoint: ReachedModelGunpoint? = nil
) -> Data {
    var data = Data("PSPO".utf8)
    data.appendInt32(2_300)

    var header = Data()
    header.appendInt32(2)
    header.appendFloat(collisionRadius)
    header.appendVector(.zero)
    header.appendVector(.zero)
    header.appendInt32(0)
    data.appendChunk("OHDR", body: header)

    var textures = Data()
    textures.appendInt32(1)
    textures.appendModelString("SAMPLE TEXTURE")
    data.appendChunk("TXTR", body: textures)

    data.appendChunk(
        "SOBJ",
        body: makeReachedSOBJ(
            index: 0, parent: -1, offset: .init(x: 100, y: 0, z: 0),
            properties: "", vertices: [], faceVertexIndices: []
        )
    )
    let vertices = (0..<31).map { index -> Vector3 in
        let angle = Float(index) * 2 * .pi / 31
        return .init(x: 5 + cos(angle), y: sin(angle), z: 2)
    }
    data.appendChunk(
        "SOBJ",
        body: makeReachedSOBJ(
            index: 1, parent: 0, offset: .init(x: 0, y: 0, z: 0),
            properties: properties, vertices: vertices,
            faceVertexIndices: Array(vertices.indices)
        )
    )
    var rotation = Data()
    for submodelIndex in 0..<2 {
        rotation.appendInt32(2)
        rotation.appendInt32(0)
        rotation.appendInt32(1)
        rotation.appendInt32(0)
        rotation.appendVector(.init(x: 1, y: 0, z: 0))
        rotation.appendInt32(0)
        rotation.appendInt32(1)
        rotation.appendVector(
            submodelIndex == 1
                ? .init(x: 0, y: 2, z: 0)
                : .init(x: 1, y: 0, z: 0)
        )
        rotation.appendInt32(0)
    }
    data.appendChunk("RANI", body: rotation)
    if let gunpoint {
        var body = Data()
        body.appendInt32(1)
        body.appendInt32(Int32(gunpoint.parentSubmodelIndex))
        body.appendVector(gunpoint.position)
        body.appendVector(gunpoint.forward)
        data.appendChunk("GPNT", body: body)
    }
    return data
}

private func makeRetailSoundTablePage(
    logicalName: String, sourceName: String, importVolume: Float
) -> Data {
    var body = Data()
    body.appendUInt16(1)
    body.appendCString(logicalName)
    body.appendCString(sourceName)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendFloat(360)
    body.appendInt32(360)
    body.appendInt32(360)
    body.appendFloat(1_000)
    body.appendFloat(0)
    body.appendFloat(importVolume)
    var table = Data([7])
    table.appendUInt32(UInt32(body.count + 4))
    table.append(body)
    return table
}

private func makePCM16WAV(samples: [Int16]) -> Data {
    var pcm = Data()
    for sample in samples {
        pcm.append(UInt8(truncatingIfNeeded: sample))
        pcm.append(UInt8(truncatingIfNeeded: sample >> 8))
    }

    var data = Data("RIFF".utf8)
    data.appendUInt32(UInt32(36 + pcm.count))
    data.append(Data("WAVEfmt ".utf8))
    data.appendUInt32(16)
    data.appendUInt16(1)
    data.appendUInt16(1)
    data.appendUInt32(22_050)
    data.appendUInt32(44_100)
    data.appendUInt16(2)
    data.appendUInt16(16)
    data.append(Data("data".utf8))
    data.appendUInt32(UInt32(pcm.count))
    data.append(pcm)
    return data
}

private func makeRetailShipTablePage(includeBatteries: Bool = false) -> Data {
    var body = Data()
    body.appendUInt16(6)
    body.appendCString("Pyro-GL")
    body.appendCString("PyroCockpit")
    body.appendCString("PyroHUD")
    body.appendCString("PyroGL.OOF")
    body.appendCString("PyroGLDying.OOF")
    body.appendCString("PyroGLMed.OOF")
    body.appendCString("PyroGLLow.OOF")
    body.appendFloat(70)
    body.appendFloat(120)
    body.appendFloat(30)
    body.appendFloat(90)
    body.appendFloat(5_400)
    body.appendInt32(0x49)
    body.appendFloat(225)
    body.appendFloat(6_860_000)
    body.appendInt32(-1)
    body.appendFloat(0)
    body.appendVector(.zero)
    body.appendFloat(0.17)
    body.appendFloat(0.9)
    body.appendFloat(1)
    body.appendFloat(-1)
    body.appendFloat(8_000)
    body.appendFloat(0.13)
    body.appendFloat(6.676084041595459)
    body.appendFloat(1)
    body.appendInt32(1)
    if includeBatteries {
        for batteryIndex in 0..<21 {
            body.append(0)
            body.appendCString("")
            body.appendCString("")
            body.appendCString("")
            body.appendInt32(0)
            body.appendFloat(0)
            body.appendFloat(batteryIndex == 10 ? 1 : 0)
            for _ in 0..<8 { body.appendUInt16(0) }
            for maskIndex in 0..<8 {
                body.append(
                    batteryIndex == 10 && maskIndex == 1
                        ? 2
                        : maskIndex == 0 ? 1 : 0
                )
                body.appendFloat(
                    batteryIndex == 10 && maskIndex < 2
                        ? 0.5
                        : maskIndex == 0 ? 1 : 0
                )
                for _ in 0..<4 { body.appendFloat(0) }
            }
            body.append(batteryIndex == 10 ? 2 : 1)
            body.appendUInt16(0)
            body.append(0)
            body.appendFloat(0)
            body.appendFloat(0)
            body.appendFloat(0)
            body.appendUInt16(0)
            body.append(0)
            for maskIndex in 0..<8 {
                body.appendCString(
                    batteryIndex == 10 && maskIndex < 2
                        ? "concmissilefire71"
                        : batteryIndex == 20 && maskIndex == 0
                        ? "Flare"
                        : ""
                )
            }
            for maskIndex in 0..<8 {
                body.appendCString(
                    batteryIndex == 10 && maskIndex < 2
                        ? "Concussion"
                        : batteryIndex == 20 && maskIndex == 0
                        ? "Yellow flare"
                        : ""
                )
            }
        }
    }

    var table = Data([6])
    table.appendUInt32(UInt32(body.count + 4))
    table.append(body)
    return table
}

private func makeRetailGenericModelTablePage() -> Data {
    var body = Data()
    body.appendUInt16(25)
    body.append(7)
    body.appendCString("Invisiblepowerup")
    body.appendCString("invisiblepowerup.OOF")
    body.appendCString("")
    body.appendCString("")
    body.append(Data(repeating: 0, count: 16))
    body.appendCString("")
    body.appendCString("")
    body.appendCString("")
    body.append(0)
    body.appendCString("")
    body.appendFloat(0)
    body.appendFloat(0)
    body.append(Data(repeating: 0, count: 68))
    body.appendFloat(1)
    body.appendFloat(0)
    body.appendVector(.init(x: 1, y: 1, z: 1))
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendVector(.zero)
    body.appendUInt32(0)
    body.appendUInt32(0)
    body.append(0)
    body.append(0)
    body.appendInt32(0)
    body.appendUInt32(0)
    body.appendUInt32(0)
    body.append(0)
    body.append(0)
    body.append(0)
    body.append(0)
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendUInt32(0)
    body.appendFloat(0)
    body.appendFloat(0)

    var table = Data([10])
    table.appendUInt32(UInt32(body.count + 4))
    table.append(body)
    return table
}

private func makeReachedOOFWithNonfiniteVertexNormal() -> Data {
    var data = Data("PSPO".utf8)
    data.appendInt32(2_300)

    var header = Data()
    header.appendInt32(1)
    header.appendFloat(1)
    header.appendVector(.zero)
    header.appendVector(.zero)
    header.appendInt32(0)
    data.appendChunk("OHDR", body: header)

    var textures = Data()
    textures.appendInt32(1)
    textures.appendModelString("Synthetic")
    data.appendChunk("TXTR", body: textures)
    data.appendChunk(
        "SOBJ",
        body: makeReachedSOBJ(
            index: 0,
            parent: -1,
            offset: .zero,
            properties: "",
            vertices: [
                .init(x: 0, y: 0, z: 0), .init(x: 1, y: 0, z: 0),
                .init(x: 0, y: 1, z: 0), .init(x: 2, y: 2, z: 2),
            ],
            normals: [
                .init(x: .nan, y: .nan, z: .nan), .init(x: 0, y: 0, z: 1),
                .init(x: 0, y: 0, z: 1), .init(x: .nan, y: .nan, z: .nan),
            ],
            faceVertexIndices: [0, 1, 2]
        )
    )
    return data
}

private func makeReachedSOBJ(
    index: Int32, parent: Int32, offset: Vector3, properties: String,
    vertices: [Vector3], normals: [Vector3]? = nil, faceVertexIndices: [Int]
) -> Data {
    var body = Data()
    body.appendInt32(index)
    body.appendInt32(parent)
    body.appendVector(.zero)
    body.appendFloat(0)
    body.appendVector(.zero)
    body.appendVector(offset)
    body.appendFloat(1)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendVector(.zero)
    body.appendModelString("submodel-\(index)")
    body.appendModelString(properties)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendInt32(0)
    body.appendInt32(Int32(vertices.count))
    vertices.forEach { body.appendVector($0) }
    (normals ?? vertices.map { _ in .init(x: 0, y: 0, z: 1) })
        .forEach { body.appendVector($0) }
    vertices.forEach { _ in body.appendFloat(1) }
    body.appendInt32(faceVertexIndices.isEmpty ? 0 : 1)
    if !faceVertexIndices.isEmpty {
        body.appendVector(.init(x: 0, y: 0, z: 1))
        body.appendInt32(Int32(faceVertexIndices.count))
        body.appendInt32(1)
        body.appendInt32(0)
        for index in faceVertexIndices {
            body.appendInt32(Int32(index))
            body.appendFloat(0)
            body.appendFloat(0)
        }
        body.appendFloat(0)
        body.appendFloat(0)
    }
    return body
}

private extension Data {
    mutating func appendChunk(_ name: String, body: Data) {
        append(contentsOf: name.utf8)
        appendInt32(Int32(body.count))
        append(body)
    }

    mutating func appendInt32(_ value: Int32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendFloat(_ value: Float) {
        appendInt32(Int32(bitPattern: value.bitPattern))
    }

    mutating func appendVector(_ value: Vector3) {
        appendFloat(value.x)
        appendFloat(value.y)
        appendFloat(value.z)
    }

    mutating func appendModelString(_ value: String) {
        appendInt32(Int32(value.utf8.count + 1))
        append(contentsOf: value.utf8)
        append(0)
    }

    mutating func appendCString(_ value: String) {
        append(contentsOf: value.utf8)
        append(0)
    }
}
