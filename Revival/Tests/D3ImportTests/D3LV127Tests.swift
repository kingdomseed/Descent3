import Foundation
import XCTest

final class D3LV127Tests: XCTestCase {
    func testTranslatesEveryResidentFaceTextureFlythroughFlagIntoSurfacePhysics() throws {
        let wall = SourceResource(storedIndex: 20, sourceName: "wall")
        let flythrough = SourceResource(storedIndex: 21, sourceName: "flythrough")
        let table = makeSimpleTextureTablePage(
            name: "wall",
            bitmapSourceName: "wall.ogf",
            flags: 0
        ) + makeSimpleTextureTablePage(
            name: "flythrough",
            bitmapSourceName: "flythrough.ogf",
            flags: 0x0001_0000
        )

        let physics = try resolveRetailSurfacePhysics(
            table: table,
            overlay: Data(),
            textures: [wall, flythrough]
        )

        XCTAssertEqual(
            physics,
            [
                .init(texture: wall, behavior: .blocking),
                .init(texture: flythrough, behavior: .passThrough),
            ]
        )
    }

    func testClassifiesUnpagedSourceDefaultTexturesAsBlocking() throws {
        let sample = SourceResource(storedIndex: 0, sourceName: "SAMPLE TEXTURE")
        let rainbow = SourceResource(storedIndex: 1, sourceName: "Rainbow Texture")

        XCTAssertEqual(
            try resolveRetailSurfacePhysics(
                table: Data(),
                overlay: Data(),
                textures: [sample, rainbow]
            ),
            [
                .init(texture: sample, behavior: .blocking),
                .init(texture: rainbow, behavior: .blocking),
            ]
        )
    }

    func testDecodesReachedOutrage1555FirstMip() throws {
        var ogf = Data([0, 0, 122])
        ogf.appendCString("slice3.ogf")
        ogf.append(1)
        ogf.append(Data(repeating: 0, count: 9))
        ogf.appendLittleEndian(UInt16(2))
        ogf.appendLittleEndian(UInt16(1))
        ogf.append(32)
        ogf.append(40)
        ogf.append(0)
        ogf.appendLittleEndian(UInt16(0xfc00))
        ogf.append(0)
        ogf.appendLittleEndian(UInt16(0x83e0))

        let image = try decodeReachedOutrage16OGF(ogf)

        XCTAssertEqual(image.width, 2)
        XCTAssertEqual(image.height, 1)
        XCTAssertEqual(
            image.rgba8,
            Data([255, 0, 0, 255, 0, 255, 0, 255])
        )
    }

    func testDecodesReachedOutrage4444FirstMip() throws {
        var ogf = Data([0, 0, 121])
        ogf.appendCString("slice3-4444.ogf")
        ogf.append(1)
        ogf.append(Data(repeating: 0, count: 9))
        ogf.appendLittleEndian(UInt16(1))
        ogf.appendLittleEndian(UInt16(1))
        ogf.append(32)
        ogf.append(40)
        ogf.append(0)
        ogf.appendLittleEndian(UInt16(0xf0f0))

        let image = try decodeReachedOutrage16OGF(ogf)

        XCTAssertEqual(image.rgba8, Data([0, 255, 0, 255]))
    }

    func testTranslatesV7TextureFlagsIntoTypedWaterAndCoronaDefinitions() throws {
        let table = makeTextureTablePage(
            name: "Alien Force Field_1",
            bitmapSourceName: "ForceField.ogf",
            red: 0.25,
            green: 0.5,
            blue: 0.75,
            alpha: 0.7,
            coronaType: 0,
            flags: 0x0368_0020,
            proceduralLighting: 8,
            proceduralThickness: 6,
            evaluationIntervalSeconds: 0,
            elements: [
                (type: 1, frequency: 20, speed: 40, size: 100, x1: 127, y1: 58, x2: 186, y2: 13),
                (type: 1, frequency: 20, speed: 40, size: 100, x1: 0, y1: 59, x2: 13, y2: 240),
                (type: 1, frequency: 20, speed: 40, size: 100, x1: 0, y1: 58, x2: 240, y2: 173),
                (type: 1, frequency: 20, speed: 40, size: 100, x1: 62, y1: 1, x2: 173, y2: 186),
                (type: 1, frequency: 20, speed: 40, size: 100, x1: 62, y1: 126, x2: 186, y2: 13),
                (type: 1, frequency: 20, speed: 40, size: 100, x1: 62, y1: 3, x2: 13, y2: 240),
                (type: 0, frequency: 0, speed: 1, size: 1, x1: 91, y1: 38, x2: 240, y2: 173),
            ]
        )

        let definition = try XCTUnwrap(
            resolveRetailTextureDefinitions(
                table: table,
                overlay: Data(),
                names: ["alien force field_1"]
            ).first
        )

        XCTAssertEqual(definition.blend, .additiveSourceAlpha(opacity: 178))
        XCTAssertEqual(definition.lightmapBlend, .none)
        XCTAssertEqual(
            definition.waterProcedural,
            .init(
                evaluationIntervalSeconds: 0,
                lightingShift: 7,
                dampingShift: 6,
                elements: [
                    .init(
                        kind: .heightBlob,
                        frequency: 20,
                        speed: 40,
                        size: 100,
                        x1: 127,
                        y1: 58,
                        x2: 186,
                        y2: 13
                    ),
                    .init(
                        kind: .heightBlob,
                        frequency: 20,
                        speed: 40,
                        size: 100,
                        x1: 0,
                        y1: 59,
                        x2: 13,
                        y2: 240
                    ),
                    .init(
                        kind: .heightBlob,
                        frequency: 20,
                        speed: 40,
                        size: 100,
                        x1: 0,
                        y1: 58,
                        x2: 240,
                        y2: 173
                    ),
                    .init(
                        kind: .heightBlob,
                        frequency: 20,
                        speed: 40,
                        size: 100,
                        x1: 62,
                        y1: 1,
                        x2: 173,
                        y2: 186
                    ),
                    .init(
                        kind: .heightBlob,
                        frequency: 20,
                        speed: 40,
                        size: 100,
                        x1: 62,
                        y1: 126,
                        x2: 186,
                        y2: 13
                    ),
                    .init(
                        kind: .heightBlob,
                        frequency: 20,
                        speed: 40,
                        size: 100,
                        x1: 62,
                        y1: 3,
                        x2: 13,
                        y2: 240
                    ),
                    .init(
                        kind: .noOp,
                        frequency: 0,
                        speed: 1,
                        size: 1,
                        x1: 91,
                        y1: 38,
                        x2: 240,
                        y2: 173
                    ),
                ]
            )
        )
        XCTAssertEqual(definition.lightCorona?.bitmapSourceName, "StarFlare6.ogf")
        XCTAssertEqual(definition.lightCorona?.tint, .init(x: 0.25, y: 0.5, z: 0.75))
        XCTAssertEqual(
            definition.lightCorona?.blend,
            .additiveSourceAlpha(opacity: 102)
        )
    }

    func testRejectsWaterWithoutSaturateBeforeCanonicalization() {
        let table = makeTextureTablePage(
            name: "unsupported-water-blend",
            bitmapSourceName: "water.ogf",
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0.7,
            coronaType: 0,
            flags: 0x0348_0020,
            proceduralLighting: 8,
            proceduralThickness: 6,
            evaluationIntervalSeconds: 0,
            elements: [
                (type: 0, frequency: 0, speed: 1, size: 1, x1: 1, y1: 1, x2: 1, y2: 1),
            ]
        )

        XCTAssertThrowsError(
            try resolveRetailTextureDefinitions(
                table: table,
                overlay: Data(),
                names: ["unsupported-water-blend"]
            )
        ) { error in
            XCTAssertEqual(
                error as? RetailTextureTableError,
                .unsupportedPresentation("unsupported-water-blend")
            )
        }
    }

    func testRejectsOscillatingWaterBeforeCanonicalization() {
        let table = makeTextureTablePage(
            name: "unsupported-water-oscillation",
            bitmapSourceName: "water.ogf",
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0.7,
            coronaType: 0,
            flags: 0x0368_0020,
            proceduralLighting: 8,
            proceduralThickness: 6,
            evaluationIntervalSeconds: 0,
            oscillationTimeSeconds: 1,
            elements: [
                (type: 0, frequency: 0, speed: 1, size: 1, x1: 1, y1: 1, x2: 1, y2: 1),
            ]
        )

        XCTAssertThrowsError(
            try resolveRetailTextureDefinitions(
                table: table,
                overlay: Data(),
                names: ["unsupported-water-oscillation"]
            )
        ) { error in
            XCTAssertEqual(
                error as? RetailTextureTableError,
                .unsupportedPresentation("unsupported-water-oscillation")
            )
        }
    }

    func testRejectsUnsupportedV7WaterElementBeforeCanonicalization() {
        let table = makeTextureTablePage(
            name: "unsupported-water",
            bitmapSourceName: "water.ogf",
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0.7,
            coronaType: 0,
            flags: 0x0368_0020,
            proceduralLighting: 8,
            proceduralThickness: 6,
            evaluationIntervalSeconds: 0,
            elements: [
                (type: 2, frequency: 1, speed: 1, size: 1, x1: 1, y1: 1, x2: 1, y2: 1),
            ]
        )

        XCTAssertThrowsError(
            try resolveRetailTextureDefinitions(
                table: table,
                overlay: Data(),
                names: ["unsupported-water"]
            )
        ) { error in
            XCTAssertEqual(
                error as? RetailTextureTableError,
                .unsupportedPresentation("unsupported-water")
            )
        }
    }

    func testConvertsNLMPPixelsToCanonicalRGBAInD3Import() throws {
        let level = try parseD3LV127(
            makeSyntheticD3LV127(
                lightmapPayload: makeLightmapPayload(
                    width: 2,
                    height: 1,
                    pixels: [0xfc00, 0x83e0]
                )
            ),
            source: syntheticSource
        )

        XCTAssertEqual(
            level.lightmaps.pages.first?.rgba8,
            Data([255, 0, 0, 255, 0, 255, 0, 255])
        )
        XCTAssertNoThrow(try level.validateForImportStaging())
        XCTAssertThrowsError(try level.validate()) { error in
            XCTAssertEqual(error as? LevelValidationError, .invalidSurfacePhysics)
        }
        let surfaceComplete = level.addingSurfacePhysics([
            .init(texture: level.rooms[0].faces[0].texture, behavior: .blocking),
        ])
        XCTAssertThrowsError(try surfaceComplete.validate()) { error in
            XCTAssertEqual(
                error as? LevelValidationError,
                .invalidDependency("orphan presentation payload")
            )
        }
    }

    func testRejectsEveryVersionExcept127() {
        for version in [126, 128] {
            var data = Data("D3LV".utf8)
            data.appendLittleEndian(Int32(version))

            XCTAssertThrowsError(try walkD3LV127Chunks(data)) { error in
                XCTAssertEqual(error as? D3LV127Error, .unsupportedVersion(version))
            }
        }
    }

    func testWalksCheckedChunkSizesInSourceOrder() throws {
        var data = Data("D3LV".utf8)
        data.appendLittleEndian(Int32(127))
        data.appendChunk("PATH", payload: Data([1, 2]))
        data.appendChunk("TSND", payload: Data([3]))

        let chunks = try walkD3LV127Chunks(data)

        XCTAssertEqual(chunks.map(\.name), ["PATH", "TSND"])
        XCTAssertEqual(chunks.map { data.subdata(in: $0.payloadRange) }, [Data([1, 2]), Data([3])])
    }

    func testRejectsChunkPayloadThatRunsPastTheContainer() {
        var data = Data("D3LV".utf8)
        data.appendLittleEndian(Int32(127))
        data.append(contentsOf: "PATH".utf8)
        data.appendLittleEndian(UInt32(12))
        data.append(contentsOf: [1, 2])

        XCTAssertThrowsError(try walkD3LV127Chunks(data)) { error in
            XCTAssertEqual(error as? D3LV127Error, .chunkOutOfBounds(name: "PATH"))
        }
    }

    func testRejectsDuplicateAndOutOfOrderTopLevelChunks() {
        var duplicate = Data("D3LV".utf8)
        duplicate.appendLittleEndian(Int32(127))
        duplicate.appendChunk("PATH", payload: Data())
        duplicate.appendChunk("PATH", payload: Data())
        XCTAssertThrowsError(try walkD3LV127Chunks(duplicate)) { error in
            XCTAssertEqual(error as? D3LV127Error, .duplicateChunk("PATH"))
        }

        var level = makeSyntheticD3LV127()
        let pathPayload = payload(named: "PATH", in: level)
        let pathRange = chunkRange(named: "PATH", in: level)
        level.removeSubrange(pathRange)
        level.appendChunk("PATH", payload: pathPayload)
        XCTAssertThrowsError(try parseD3LV127(level, source: syntheticSource)) { error in
            XCTAssertEqual(
                error as? D3LV127DecodeError,
                .unexpectedChunkOrder([
                    "TSND", "NLMP", "PSTR", "TXNM", "GNNM", "DRNM", "ROOM", "TERR",
                    "OHND", "OBJS", "TRIG", "CNBS", "CBOA", "NODE", "AABB", "MTCN",
                    "LVLG", "LIFE", "INFO", "EDIT", "PATH",
                ])
            )
        }
    }

    func testRejectsLightmapPageAboveSourceDimensionLimit() {
        for (width, height) in [(UInt16(129), UInt16(1)), (UInt16(1), UInt16(129))] {
            XCTAssertThrowsError(
                try parseD3LV127(
                    makeSyntheticD3LV127(
                        lightmapPayload: makeLightmapPayload(width: width, height: height)
                    ),
                    source: syntheticSource
                )
            ) { error in
                XCTAssertEqual(
                    error as? D3LV127DecodeError,
                    .invalidCount(section: "NLMP pages")
                )
            }
        }
    }

    func testRejectsLightmapInfoBelowSourceMinimumDimensions() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(
                    lightmapPayload: makeLightmapPayload(
                        width: 4,
                        height: 4,
                        infoWidth: 1,
                        infoHeight: 2
                    )
                ),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(error as? D3LV127DecodeError, .invalidReference("NLMP page"))
        }
    }

    func testRejectsTruncatedCompressedLightmapCommands() {
        var lightmaps = Data()
        lightmaps.appendLittleEndian(UInt32(1))
        lightmaps.appendLittleEndian(UInt16(8))
        lightmaps.appendLittleEndian(UInt16(8))
        lightmaps.append(UInt8(1))
        lightmaps.append(UInt8(0))
        lightmaps.appendLittleEndian(UInt16(7))

        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(lightmapPayload: lightmaps),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(
                error as? D3LV127DecodeError,
                .malformed(section: "NLMP", offset: 12)
            )
        }
    }

    func testRejectsRoomFaceCountAboveSourceCeilingBeforeAllocation() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(roomFaceCount: 3_001),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(error as? D3LV127DecodeError, .invalidCount(section: "ROOM"))
        }
    }

    func testRejectsUInt32MaxRoomPortalCountBeforeAllocation() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(roomPortalCount: .max),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(error as? D3LV127DecodeError, .invalidCount(section: "ROOM"))
        }
    }

    func testRejectsVolumeLightDimensionOutsideSourceStorageBeforeAllocation() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(volumeLightWidth: 32_768),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(
                error as? D3LV127DecodeError,
                .invalidCount(section: "ROOM volume lights")
            )
        }
    }

    func testRejectsNonfiniteFloatAtTheD3LBoundary() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(gravity: .infinity),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(
                error as? D3LV127DecodeError,
                .malformed(section: "INFO", offset: 26)
            )
        }
    }

    func testRejectsUInt16MaxObjectLightmapFaceCountBeforeAllocation() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(
                    objectTypes: [1],
                    objectLightmapFaceCount: .max
                ),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(error as? D3LV127DecodeError, .invalidCount(section: "OBJS"))
        }
    }

    func testRejectsImpossibleObjectSourceIdentities() {
        let cases: [(handle: UInt32, type: UInt8, storedID: UInt16)] = [
            (0, 6, 0),
            (1, 6, 0),
            (0x800, 18, 0),
            (0x800, 26, 0),
            (0x800, 255, 0),
            (0x800, 6, 0x8000),
            (0x800, 2, 910),
            (0x800, 17, 60),
        ]

        for value in cases {
            XCTAssertThrowsError(
                try parseD3LV127(
                    makeSyntheticD3LV127(
                        objectTypes: [value.type],
                        objectHandles: [value.handle],
                        objectStoredIDs: [value.storedID]
                    ),
                    source: syntheticSource
                )
            ) { error in
                XCTAssertEqual(
                    error as? D3LV127DecodeError,
                    .invalidReference("OBJS identity"),
                    "identity \(value)"
                )
            }
        }
    }

    func testRejectsMalformedAndOverrunningUInt16RLECommands() {
        for (command, expected) in [
            (UInt8(1), D3LV127DecodeError.malformed(section: "NLMP", offset: 9)),
            (UInt8(2), D3LV127DecodeError.invalidCount(section: "NLMP compressed UInt16")),
        ] {
            var lightmaps = Data()
            lightmaps.appendLittleEndian(UInt32(1))
            lightmaps.appendLittleEndian(UInt16(1))
            lightmaps.appendLittleEndian(UInt16(1))
            lightmaps.append(UInt8(1))
            lightmaps.append(command)
            lightmaps.appendLittleEndian(UInt16(7))

            XCTAssertThrowsError(
                try parseD3LV127(
                    makeSyntheticD3LV127(lightmapPayload: lightmaps),
                    source: syntheticSource
                )
            ) { error in
                XCTAssertEqual(error as? D3LV127DecodeError, expected)
            }
        }
    }

    func testRejectsImpossibleMalformedAndOverrunningUInt8RLE() {
        var impossible = Data([1])
        impossible.append(contentsOf: [0, 7])

        var malformed = Data([1, 1, 7])
        for _ in 1..<263 { malformed.append(contentsOf: [250, 7]) }

        var overrun = Data([1])
        for _ in 0..<262 { overrun.append(contentsOf: [250, 7]) }
        overrun.append(contentsOf: [250, 7])

        let cases: [(Data, D3LV127DecodeError)] = [
            (impossible, .invalidCount(section: "TERH compressed UInt8")),
            (malformed, .malformed(section: "TERH", offset: 1)),
            (overrun, .invalidCount(section: "TERH compressed UInt8")),
        ]
        for (heightPayload, expected) in cases {
            XCTAssertThrowsError(
                try parseD3LV127(
                    makeSyntheticD3LV127(terrainHeightPayload: heightPayload),
                    source: syntheticSource
                )
            ) { error in
                XCTAssertEqual(error as? D3LV127DecodeError, expected)
            }
        }
    }

    func testRecordsOnlySourceBackedObjectDefinitionsAndDeferredLightmapPages() throws {
        let level = try parseD3LV127(
            makeSyntheticD3LV127(
                lightmapPayload: makeLightmapPayload(width: 1, height: 1),
                objectTypes: [1, 2, 17]
            ),
            source: syntheticSource
        )

        XCTAssertEqual(
            level.dependencyManifest.current.filter { $0.category == "object-definition" }.map(\.source.sourceName),
            ["object"]
        )
        XCTAssertEqual(
            level.dependencyManifest.current.filter { $0.category == "door-definition" }.map(\.source.sourceName),
            ["door"]
        )
        XCTAssertFalse(
            level.dependencyManifest.current.contains {
                $0.source.sourceName == "object-type-1-id-0"
            }
        )
        XCTAssertEqual(
            level.dependencyManifest.current.filter { $0.category == "lightmap-page" },
            [
                .init(
                    category: "lightmap-page",
                    source: .init(storedIndex: 0, sourceName: "lightmap-page-0"),
                    state: "payload-validated-preparation-deferred",
                    provenance: "NLMP page metadata"
                ),
            ]
        )
    }

    func testRejectsUsedTerrainSoundAndMovingTextureFeatures() {
        let cases: [(UInt32, UInt32, String)] = [(1, 0, "TSND"), (0, 1, "MTCN")]
        for (terrainSoundCount, movingTextureCount, section) in cases {
            XCTAssertThrowsError(
                try parseD3LV127(
                    makeSyntheticD3LV127(
                        terrainSoundCount: terrainSoundCount,
                        movingTextureCount: movingTextureCount
                    ),
                    source: syntheticSource
                )
            ) { error in
                XCTAssertEqual(error as? D3LV127DecodeError, .unsupportedUsedFeature(section))
            }
        }
    }

    func testRejectsUnresolvedFaceTexture() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(roomTextureIndex: 1),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(
                error as? D3LV127DecodeError,
                .unresolvedResource(table: "TXNM", index: 1)
            )
        }
    }

    func testRejectsSourceFixedTranslationTableCounts() {
        let cases: [(String, UInt32)] = [
            ("TXNM", 3_101),
            ("GNNM", 911),
            ("DRNM", 61),
        ]
        for (section, count) in cases {
            var oversized = Data()
            oversized.appendLittleEndian(count)
            oversized.append(Data(repeating: 0, count: Int(count)))
            XCTAssertThrowsError(
                try parseD3LV127(
                    makeSyntheticD3LV127(
                        textureNamesPayload: section == "TXNM" ? oversized : nil,
                        genericNamesPayload: section == "GNNM" ? oversized : nil,
                        doorNamesPayload: section == "DRNM" ? oversized : nil
                    ),
                    source: syntheticSource
                )
            ) { error in
                XCTAssertEqual(error as? D3LV127DecodeError, .invalidCount(section: section))
            }
        }
    }

    func testDecodesACompleteSyntheticResidentLevel() throws {
        let level = try parseD3LV127(
            makeSyntheticD3LV127(),
            source: syntheticSource
        )

        XCTAssertEqual(level.rooms.map(\.sourceIndex), [2])
        XCTAssertEqual(level.rooms[0].vertices.count, 3)
        XCTAssertEqual(level.rooms[0].faces.count, 1)
        XCTAssertNil(level.rooms[0].faces[0].portalIndex)
        XCTAssertEqual(level.rooms[0].faces[0].texture.sourceName, "wall")
        XCTAssertEqual(level.terrain.heights.count, 65_536)
        let dispositions = Dictionary(uniqueKeysWithValues: level.sourceChunks.map { ($0.name, $0.disposition) })
        XCTAssertEqual(
            dispositions["NLMP"],
            "canonical-metadata"
        )
        XCTAssertEqual(dispositions["NODE"], "deferred-phase-4-training-navigation-ai-reimport")
        XCTAssertEqual(dispositions["LIFE"], "evidence-only-future-opportunity-f-001")
        XCTAssertEqual(dispositions["OHND"], "canonical-retired-handle-continuity")
        XCTAssertEqual(dispositions["INFO"], "canonical")
        XCTAssertEqual(dispositions["EDIT"], "evidence-only-phase-1-slice-3-native-editor-state")
        XCTAssertTrue(level.surfacePhysics.isEmpty)
        XCTAssertNoThrow(try level.validateForImportStaging())
        XCTAssertThrowsError(try level.validate()) {
            XCTAssertEqual($0 as? LevelValidationError, .invalidSurfacePhysics)
        }
    }

    func testAcceptsZeroAlignmentPaddingAfterNameTables() throws {
        let level = try parseD3LV127(
            makeSyntheticD3LV127(padNameTables: true),
            source: syntheticSource
        )

        XCTAssertEqual(level.rooms.count, 1)
    }

    func testAcceptsZeroAlignmentPaddingAfterLightmaps() throws {
        let level = try parseD3LV127(
            makeSyntheticD3LV127(lightmapPaddingCount: 1),
            source: syntheticSource
        )

        XCTAssertEqual(level.lightmaps, .init(pages: [], infos: []))
    }

    func testAcceptsSourceAlignmentPaddingInNestedTerrainChunks() throws {
        let level = try parseD3LV127(
            makeSyntheticD3LV127(terrainHeightPaddingCount: 1),
            source: syntheticSource
        )

        XCTAssertEqual(level.terrain.heights.count, 65_536)
    }

    func testRejectsMoreThanThreeAlignmentBytes() {
        XCTAssertThrowsError(
            try parseD3LV127(
                makeSyntheticD3LV127(lightmapPaddingCount: 4),
                source: syntheticSource
            )
        ) { error in
            XCTAssertEqual(
                error as? D3LV127DecodeError,
                .malformed(section: "NLMP", offset: 8)
            )
        }
    }

    func testPreservesCeilingCollisionAndRetiredHandleState() throws {
        let level = try parseD3LV127(
            makeSyntheticD3LV127(
                alwaysCheckCeiling: true,
                retiredObjectHandles: [6_164]
            ),
            source: syntheticSource
        )

        XCTAssertTrue(level.metadata.alwaysCheckCeiling)
        XCTAssertEqual(level.retiredObjectHandles, [6_164])
    }
}

private func makeSyntheticD3LV127(
    padNameTables: Bool = false,
    lightmapPaddingCount: Int = 0,
    terrainHeightPaddingCount: Int = 0,
    alwaysCheckCeiling: Bool = false,
    retiredObjectHandles: [UInt32] = [],
    lightmapPayload: Data? = nil,
    objectTypes: [UInt8] = [],
    objectHandles: [UInt32]? = nil,
    objectStoredIDs: [UInt16]? = nil,
    terrainSoundCount: UInt32 = 0,
    movingTextureCount: UInt32 = 0,
    roomTextureIndex: UInt16 = 0,
    roomFaceCount: UInt32 = 1,
    roomPortalCount: UInt32 = 0,
    terrainHeightPayload: Data? = nil,
    textureNamesPayload: Data? = nil,
    genericNamesPayload: Data? = nil,
    doorNamesPayload: Data? = nil,
    objectLightmapFaceCount: UInt16? = nil,
    volumeLightWidth: Int32? = nil,
    gravity: Float = -32.2
) -> Data {
    var level = Data("D3LV".utf8)
    level.appendLittleEndian(Int32(127))

    var path = Data()
    path.appendLittleEndian(UInt16(0))
    level.appendChunk("PATH", payload: path)

    var terrainSounds = Data()
    terrainSounds.appendLittleEndian(terrainSoundCount)
    level.appendChunk("TSND", payload: terrainSounds)

    var lightmaps = lightmapPayload ?? makeEmptyLightmapPayload()
    if lightmapPayload == nil { lightmaps.append(Data(repeating: 0, count: lightmapPaddingCount)) }
    level.appendChunk("NLMP", payload: lightmaps)

    var playerStarts = Data()
    playerStarts.appendLittleEndian(UInt16(0))
    level.appendChunk("PSTR", payload: playerStarts)

    var textureNames = textureNamesPayload ?? makeNameTable(["wall"])
    if padNameTables { textureNames.append(contentsOf: [0, 0, 0]) }
    level.appendChunk("TXNM", payload: textureNames)
    level.appendChunk("GNNM", payload: genericNamesPayload ?? makeNameTable(["object"]))
    level.appendChunk("DRNM", payload: doorNamesPayload ?? makeNameTable(["door"]))
    level.appendChunk(
        "ROOM",
        payload: makeSyntheticRoom(
            textureIndex: roomTextureIndex,
            faceCount: roomFaceCount,
            portalCount: roomPortalCount,
            volumeLightWidth: volumeLightWidth
        )
    )
    level.appendChunk(
        "TERR",
        payload: makeSyntheticTerrain(
            heightPaddingCount: terrainHeightPaddingCount,
            heightPayload: terrainHeightPayload
        )
    )

    var retiredHandlesData = Data()
    retiredHandlesData.appendLittleEndian(UInt32(retiredObjectHandles.count))
    for handle in retiredObjectHandles { retiredHandlesData.appendLittleEndian(handle) }
    level.appendChunk("OHND", payload: retiredHandlesData)
    var emptyCount = Data()
    emptyCount.appendLittleEndian(UInt32(0))
    level.appendChunk(
        "OBJS",
        payload: makeSyntheticObjects(
            types: objectTypes,
            handles: objectHandles,
            storedIDs: objectStoredIDs,
            lightmapFaceCount: objectLightmapFaceCount
        )
    )
    level.appendChunk("TRIG", payload: emptyCount)
    level.appendChunk("CNBS", payload: Data())
    level.appendChunk("CBOA", payload: Data())
    level.appendChunk("NODE", payload: Data())
    level.appendChunk("AABB", payload: Data())
    var movingTextures = Data()
    movingTextures.appendLittleEndian(movingTextureCount)
    level.appendChunk("MTCN", payload: movingTextures)

    var goals = Data()
    goals.appendLittleEndian(UInt16(4))
    goals.appendLittleEndian(UInt16(0))
    goals.appendLittleEndian(UInt32(0))
    level.appendChunk("LVLG", payload: goals)
    level.appendChunk("LIFE", payload: Data())

    var info = Data()
    info.appendCString("Synthetic")
    info.appendCString("Revival tests")
    info.appendCString("")
    info.appendCString("")
    info.appendFloat(gravity)
    info.appendLittleEndian(Int32(alwaysCheckCeiling ? 1 : 0))
    info.appendFloat(2_000)
    level.appendChunk("INFO", payload: info)
    level.appendChunk("EDIT", payload: Data())
    return level
}

private func makeNameTable(_ names: [String]) -> Data {
    var data = Data()
    data.appendLittleEndian(UInt32(names.count))
    for name in names { data.appendCString(name) }
    return data
}

private func makeSyntheticRoom(
    textureIndex: UInt16 = 0,
    faceCount: UInt32 = 1,
    portalCount: UInt32 = 0,
    volumeLightWidth: Int32? = nil
) -> Data {
    var data = Data()
    data.appendLittleEndian(UInt32(1))
    for count in [UInt32(3), faceCount, faceCount * 3, portalCount] {
        data.appendLittleEndian(count)
    }
    data.appendLittleEndian(Int16(2))
    data.appendLittleEndian(UInt32(3))
    data.appendLittleEndian(faceCount)
    data.appendLittleEndian(portalCount)
    data.appendCString("Room 2")
    data.appendVector(.zero)
    data.appendVector(.zero)
    data.appendVector(.init(x: 1, y: 0, z: 0))
    data.appendVector(.init(x: 0, y: 1, z: 0))
    for _ in 0..<faceCount {
        data.append(UInt8(3))
        for index in [0, 1, 2] { data.appendLittleEndian(UInt16(index)) }
        for (u, v) in [(0 as Float, 0 as Float), (1, 0), (0, 1)] {
            data.appendFloat(u)
            data.appendFloat(v)
            data.append(UInt8(255))
        }
        data.appendLittleEndian(UInt16(0))
        data.append(UInt8(255))
        data.appendLittleEndian(textureIndex)
        data.append(UInt8(4))
        data.append(UInt8(0))
    }
    data.appendLittleEndian(UInt32(0))
    data.append(contentsOf: [0, 0])
    data.appendLittleEndian(Int16(-1))
    if let volumeLightWidth {
        data.append(UInt8(1))
        data.appendLittleEndian(volumeLightWidth)
        data.appendLittleEndian(Int32(0))
        data.appendLittleEndian(Int32(0))
        data.append(UInt8(0))
    } else {
        data.append(UInt8(0))
    }
    for _ in 0..<4 { data.appendFloat(0) }
    data.appendCString("")
    data.append(UInt8(0))
    data.appendFloat(0)
    data.append(UInt8(0))
    return data
}

private func makeEmptyLightmapPayload() -> Data {
    var data = Data()
    data.appendLittleEndian(UInt32(0))
    data.appendLittleEndian(UInt32(0))
    return data
}

private func makeLightmapPayload(
    width: UInt16,
    height: UInt16,
    infoWidth: UInt16? = nil,
    infoHeight: UInt16? = nil,
    pixels: [UInt16]? = nil
) -> Data {
    var data = Data()
    data.appendLittleEndian(UInt32(1))
    data.appendLittleEndian(width)
    data.appendLittleEndian(height)
    data.append(UInt8(0))
    let pixels = pixels ?? [UInt16](repeating: 0, count: Int(width) * Int(height))
    precondition(pixels.count == Int(width) * Int(height))
    for pixel in pixels { data.appendLittleEndian(pixel) }
    if let infoWidth, let infoHeight {
        data.appendLittleEndian(UInt32(1))
        data.appendLittleEndian(UInt16(0))
        data.appendLittleEndian(infoWidth)
        data.appendLittleEndian(infoHeight)
        data.append(UInt8(0))
        data.appendLittleEndian(Int16(0))
        data.appendLittleEndian(Int16(0))
        data.append(contentsOf: [0, 0])
        data.appendVector(.zero)
        data.appendVector(.zero)
    } else {
        data.appendLittleEndian(UInt32(0))
    }
    return data
}

private func makeTextureTablePage(
    name: String,
    bitmapSourceName: String,
    red: Float,
    green: Float,
    blue: Float,
    alpha: Float,
    coronaType: UInt8,
    flags: UInt32,
    proceduralLighting: UInt8,
    proceduralThickness: UInt8,
    evaluationIntervalSeconds: Float,
    proceduralHeat: UInt8 = 128,
    oscillationTimeSeconds: Float = 0,
    oscillationValue: UInt8 = 8,
    elements: [(
        type: UInt8,
        frequency: UInt8,
        speed: UInt8,
        size: UInt8,
        x1: UInt8,
        y1: UInt8,
        x2: UInt8,
        y2: UInt8
    )]
) -> Data {
    var body = Data()
    body.appendLittleEndian(UInt16(7))
    body.appendCString(name)
    body.appendCString(bitmapSourceName)
    body.appendCString("")
    body.appendFloat(red)
    body.appendFloat(green)
    body.appendFloat(blue)
    body.appendFloat(alpha)
    body.appendFloat(1)
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendFloat(0.5)
    body.append(coronaType)
    body.appendLittleEndian(UInt32(0))
    body.appendLittleEndian(flags)
    body.append(Data(repeating: 0, count: 255 * 2))
    body.append(proceduralHeat)
    body.append(proceduralLighting)
    body.append(proceduralThickness)
    body.appendFloat(evaluationIntervalSeconds)
    body.appendFloat(oscillationTimeSeconds)
    body.append(oscillationValue)
    body.appendLittleEndian(UInt16(elements.count))
    for element in elements {
        body.append(contentsOf: [
            element.type,
            element.frequency,
            element.speed,
            element.size,
            element.x1,
            element.y1,
            element.x2,
            element.y2,
        ])
    }
    body.appendCString("")
    body.appendFloat(1)

    var page = Data([1])
    page.appendLittleEndian(UInt32(body.count + 4))
    page.append(body)
    return page
}

private func makeSimpleTextureTablePage(
    name: String,
    bitmapSourceName: String,
    flags: UInt32
) -> Data {
    var body = Data()
    body.appendLittleEndian(UInt16(7))
    body.appendCString(name)
    body.appendCString(bitmapSourceName)
    body.appendCString("")
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendFloat(1)
    body.appendFloat(1)
    body.appendFloat(0)
    body.appendFloat(0)
    body.appendFloat(0.5)
    body.append(0)
    body.appendLittleEndian(UInt32(0))
    body.appendLittleEndian(flags)
    body.appendCString("")
    body.appendFloat(1)

    var page = Data([1])
    page.appendLittleEndian(UInt32(body.count + 4))
    page.append(body)
    return page
}

private func makeSyntheticObjects(
    types: [UInt8],
    handles: [UInt32]? = nil,
    storedIDs: [UInt16]? = nil,
    lightmapFaceCount: UInt16? = nil
) -> Data {
    precondition(handles == nil || handles?.count == types.count)
    precondition(storedIDs == nil || storedIDs?.count == types.count)
    var data = Data()
    data.appendLittleEndian(UInt32(types.count))
    for (index, type) in types.enumerated() {
        data.appendLittleEndian(handles?[index] ?? UInt32(0x800 + index))
        data.append(type)
        data.appendLittleEndian(storedIDs?[index] ?? UInt16(0))
        data.appendCString("")
        data.appendLittleEndian(UInt32(0))
        if type == 17 { data.appendLittleEndian(Int16(0)) }
        data.appendLittleEndian(Int32(2))
        data.appendVector(.zero)
        data.appendVector(.init(x: 1, y: 0, z: 0))
        data.appendVector(.init(x: 0, y: 1, z: 0))
        data.appendVector(.init(x: 0, y: 0, z: 1))
        data.append(contentsOf: [0, 0, 0])
        data.appendFloat(0)
        data.append(contentsOf: [0, 0])
        if let lightmapFaceCount {
            data.append(UInt8(1))
            data.append(UInt8(1))
            data.appendLittleEndian(lightmapFaceCount)
        } else {
            data.append(UInt8(0))
        }
    }
    return data
}

private let syntheticSource = LevelSource(
    profileIdentifier: "synthetic",
    profileFiles: [
        .init(
            relativePath: "synthetic.hog",
            byteCount: 1,
            sha256: String(repeating: "a", count: 64)
        ),
    ],
    archiveSHA256: String(repeating: "b", count: 64),
    levelSHA256: String(repeating: "c", count: 64),
    d3lvVersion: 127
)

private func chunkRange(named target: String, in data: Data) -> Range<Int> {
    let chunks = try! walkD3LV127Chunks(data)
    let chunk = chunks.first { $0.name == target }!
    return (chunk.payloadRange.lowerBound - 8)..<chunk.payloadRange.upperBound
}

private func payload(named target: String, in data: Data) -> Data {
    let chunk = try! walkD3LV127Chunks(data).first { $0.name == target }!
    return data.subdata(in: chunk.payloadRange)
}

private func makeSyntheticTerrain(
    heightPaddingCount: Int = 0,
    heightPayload: Data? = nil
) -> Data {
    var terrain = Data()
    var heights = heightPayload ?? rawCompressedBytes(count: 65_536)
    heights.append(Data(repeating: 0, count: heightPaddingCount))
    terrain.appendChunk("TERH", payload: heights)

    var textureMap = Data()
    textureMap.append(UInt8(0))
    for _ in 0..<1_024 { textureMap.appendLittleEndian(UInt16(0)) }
    textureMap.append(rawCompressedBytes(count: 1_024))
    textureMap.append(rawCompressedBytes(count: 65_536))
    terrain.appendChunk("TETM", payload: textureMap)

    var sky = Data()
    sky.appendFloat(0)
    sky.appendFloat(0)
    sky.append(UInt8(0))
    sky.appendLittleEndian(UInt16(0))
    for _ in 0..<4 { sky.appendLittleEndian(UInt32(0)) }
    sky.appendFloat(2_000)
    sky.appendFloat(0)
    sky.appendLittleEndian(UInt32(0))
    for _ in 0..<5 { sky.append(rawCompressedBytes(count: 65_536)) }
    sky.appendLittleEndian(UInt32(0))
    sky.append(rawCompressedBytes(count: 8_192))
    terrain.appendChunk("TSKY", payload: sky)
    terrain.appendChunk("TEND", payload: Data())
    return terrain
}

private func rawCompressedBytes(count: Int) -> Data {
    var data = Data([0])
    data.append(Data(repeating: 0, count: count))
    return data
}

private extension Data {
    mutating func appendLittleEndian(_ value: Int32) {
        appendLittleEndian(UInt32(bitPattern: value))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }

    mutating func appendLittleEndian(_ value: Int16) {
        appendLittleEndian(UInt16(bitPattern: value))
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func appendFloat(_ value: Float) {
        appendLittleEndian(value.bitPattern)
    }

    mutating func appendVector(_ value: Vector3) {
        appendFloat(value.x)
        appendFloat(value.y)
        appendFloat(value.z)
    }

    mutating func appendCString(_ value: String) {
        append(contentsOf: value.utf8)
        append(0)
    }

    mutating func appendChunk(_ name: String, payload: Data) {
        precondition(name.utf8.count == 4)
        append(contentsOf: name.utf8)
        appendLittleEndian(UInt32(payload.count + 4))
        append(payload)
    }
}
