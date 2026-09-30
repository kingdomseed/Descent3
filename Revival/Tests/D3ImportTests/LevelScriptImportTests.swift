// Tests for the generic level script data in the canonical package
// (package schema 12). Legacy sources: Descent3/Mission.cpp:1686
// InitLevelScript, Descent3/OsirisLoadandBind.cpp:884 and :1427,
// Descent3/LoadLevel.cpp:1718, manage/generic.cpp:1083,
// manage/doorpage.cpp:261, and the message-file reader generated in every
// DALLAS level script (scripts/TrainingMission.cpp:743 ReadMessageFile).

import Foundation
import XCTest

final class LevelScriptImportTests: XCTestCase {
    func testImportsGenericScriptDataFromSyntheticLevelAndArchives() throws {
        let level = try makeLevelScriptImportLevel()

        let scripting = try importLevelScripting(
            level: level,
            levelFileName: "Synthetic.D3L",
            archives: makeLevelScriptArchives(),
            table: makeLevelScriptTable(),
            overlay: makeLevelScriptOverlay(),
            references: .init(
                soundNames: ["beep"],
                streamedAudioNames: ["HELLO.osf"]
            )
        )

        XCTAssertEqual(scripting.levelScript, "synthetic")
        XCTAssertEqual(
            scripting.objects,
            [
                // The extra.gam page replaces the table page, name included.
                .init(
                    objectHandle: 0x800,
                    name: "Guard1",
                    defaultModuleName: "aigame3",
                    defaultScriptName: "TUBBS"
                ),
                .init(
                    objectHandle: 0x801,
                    name: nil,
                    defaultModuleName: "custommod",
                    defaultScriptName: "CustomPage"
                ),
                .init(
                    objectHandle: 0x802,
                    name: "Lamp1",
                    defaultModuleName: nil,
                    defaultScriptName: "LampScript"
                ),
                .init(
                    objectHandle: 0x803,
                    name: "MainDoor",
                    defaultModuleName: "doormod",
                    defaultScriptName: "MainDoorPage"
                ),
                .init(
                    objectHandle: 0x804,
                    name: "Cam",
                    defaultModuleName: nil,
                    defaultScriptName: nil
                ),
            ]
        )
        XCTAssertEqual(
            scripting.messages,
            [
                .init(name: "Welcome", text: "Hello pilot"),
                .init(name: "Spaced ", text: " text with = sign"),
                .init(name: "Empty", text: ""),
            ]
        )
        XCTAssertEqual(
            scripting.streamedAudio,
            [.init(name: "HELLO.osf", key: "hello.osf")]
        )
        XCTAssertEqual(scripting.sounds, [.init(name: "beep", key: "Beep")])

        let scripted = level.addingScripting(scripting)
        XCTAssertEqual(scripted.schemaVersion, 12)
        XCTAssertEqual(scripted.scripting, scripting)
    }

    func testRejectsUnresolvedLevelScriptInputs() throws {
        let level = try makeLevelScriptImportLevel()
        func run(
            levelFileName: String = "Synthetic.d3l",
            archives: [LevelScriptArchive]? = nil,
            table: Data? = nil,
            references: LevelScriptReferences = .init(
                soundNames: [],
                streamedAudioNames: []
            )
        ) throws {
            _ = try importLevelScripting(
                level: level,
                levelFileName: levelFileName,
                archives: archives ?? makeLevelScriptArchives(),
                table: table ?? makeLevelScriptTable(),
                overlay: Data(),
                references: references
            )
        }

        XCTAssertThrowsError(
            try run(table: makeLevelScriptTable(tubbsModule: "bad name"))
        ) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .invalidModuleName(handle: 0x800, moduleName: "bad name")
            )
        }
        XCTAssertThrowsError(try run(levelFileName: "Other.d3l")) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .missingMessageFile("other.msg")
            )
        }
        XCTAssertThrowsError(
            try run(references: .init(soundNames: [], streamedAudioNames: ["gone.osf"]))
        ) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .unresolvedStreamedAudio("gone.osf")
            )
        }
        XCTAssertThrowsError(
            try run(references: .init(soundNames: [], streamedAudioNames: ["NoClip.osf"]))
        ) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .unresolvedStreamedAudio("NoClip.osf")
            )
        }
        XCTAssertThrowsError(
            try run(references: .init(soundNames: ["Missing"], streamedAudioNames: []))
        ) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .unresolvedSound("Missing")
            )
        }
        // cfopen searches the mission archive first (cfile.cpp:264), so a
        // mission copy of the WAV hides the base-archive clip.
        var shadowed = makeLevelScriptArchives()
        shadowed[0] = makeLevelScriptArchive(
            relativePath: "missions/synthetic.mn3",
            entries: [("BeepSrc.wav", Data([5])), ("Synthetic.msg", Data("A=1".utf8))]
        )
        XCTAssertThrowsError(
            try run(
                archives: shadowed,
                references: .init(soundNames: ["Beep"], streamedAudioNames: [])
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .unresolvedSound("Beep")
            )
        }
        XCTAssertThrowsError(
            try run(table: makeRetailPage(type: 7, body: makeSoundPageBody("Beep", "BeepSrc.wav")))
        ) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .missingObjectPage(handle: 0x800, pageName: "Tubbs")
            )
        }
    }

    func testMessageFileFollowsLegacyReaderRules() throws {
        // cfgetc (cfile.cpp:627) turns CR, CRLF, and LF into one newline.
        // cf_ReadString (cfile.cpp:783) keeps at most 1,023 bytes of a line
        // and drops the rest. AddMessageToList stores an empty name too.
        let long = "L=" + String(repeating: "a", count: 1_100)
        let lateSeparator = "M" + String(repeating: "b", count: 1_100) + "=z"
        let source = "//c\r\n\r\nA=1\r\n  B =  2  \r\nA=dup\r\nnone\r\n=x\r\n=y\n"
            + "C=3\rD=4\r\(long)\n\(lateSeparator)\nE=5"
        let messages = try parseLevelScriptMessages(
            Data(source.utf8),
            fileName: "x.msg"
        )
        XCTAssertEqual(
            messages,
            [
                .init(name: "A", text: "1"),
                .init(name: "B ", text: "  2"),
                .init(name: "", text: "x"),
                .init(name: "C", text: "3"),
                .init(name: "D", text: "4"),
                .init(name: "L", text: String(repeating: "a", count: 1_021)),
                .init(name: "E", text: "5"),
            ]
        )
        XCTAssertThrowsError(
            try parseLevelScriptMessages(Data([0x41, 0x3d, 0xff]), fileName: "x.msg")
        ) {
            XCTAssertEqual(
                $0 as? LevelScriptImportError,
                .malformedMessageFile("x.msg")
            )
        }
        let many = (0..<300).map { "M\($0)=t\n" }.joined()
        XCTAssertEqual(
            try parseLevelScriptMessages(Data(many.utf8), fileName: "x.msg").count,
            256
        )
    }

    func testCompiledTrainingScriptListsEveryNameItReferences() throws {
        let references = try XCTUnwrap(
            LevelModule.scriptReferences(forLevelScript: "trainingmission")
        )
        XCTAssertEqual(references.soundNames, ["MenuBeepEnter", "PupC1"])
        XCTAssertEqual(references.streamedAudioNames.count, 32)
        XCTAssertEqual(
            Set(references.streamedAudioNames.map { $0.lowercased() }).count,
            32
        )
        XCTAssertTrue(references.streamedAudioNames.contains("welcome.osf"))
        XCTAssertNil(LevelModule.scriptReferences(forLevelScript: "none"))
    }

    func testSchemaTwelveRoundTripsThroughCanonicalPackage() throws {
        let (base, scripting) = try makeScriptedTrainingLevel()
        let level = base.addingScripting(scripting)
        try level.validate()

        let decoded = try JSONDecoder().decode(
            Level.self,
            from: canonicalJSONData(level)
        )
        XCTAssertEqual(decoded, level)
        XCTAssertEqual(decoded.scripting, scripting)

        let root = FileManager.default.temporaryDirectory
            .appending(path: "revival-scripting-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try writeCanonicalPackage(level, to: root)
        XCTAssertEqual(try loadCanonicalLevel(from: root), level)
    }

    func testSchemaElevenLoadsWithoutScriptData() throws {
        let level = makeTrainingFinalRoomEntryLevel()
        XCTAssertEqual(level.schemaVersion, 11)
        let data = try canonicalJSONData(level)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(object["scripting"])
        let decoded = try JSONDecoder().decode(Level.self, from: data)
        XCTAssertNil(decoded.scripting)
        XCTAssertNoThrow(try decoded.validate())
    }

    func testSchemaTwelveRequiresStructurallyValidScriptData() throws {
        let (base, valid) = try makeScriptedTrainingLevel()
        let level = base.addingScripting(valid)
        XCTAssertNoThrow(try level.validate())

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: canonicalJSONData(level))
                as? [String: Any]
        )
        object["scripting"] = nil
        let missing = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertThrowsError(try missing.validate()) {
            XCTAssertEqual($0 as? LevelValidationError, .invalidIdentity)
        }

        func scripting(
            levelScript: String = "trainingmission",
            objects: [ObjectScriptBinding]? = nil,
            messages: [LevelScriptMessage]? = nil,
            streamedAudio: [LevelScriptAudioReference]? = nil,
            sounds: [LevelScriptAudioReference]? = nil
        ) -> LevelScripting {
            LevelScripting(
                levelScript: levelScript,
                objects: objects ?? valid.objects,
                messages: messages ?? valid.messages,
                streamedAudio: streamedAudio ?? valid.streamedAudio,
                sounds: sounds ?? valid.sounds
            )
        }
        func assertInvalid(_ value: LevelScripting, line: UInt = #line) {
            XCTAssertThrowsError(
                try base.addingScripting(value).validate(),
                line: line
            ) {
                guard case .invalidScripting = $0 as? LevelValidationError else {
                    return XCTFail("\($0)", line: line)
                }
            }
        }

        // GetMessage("") finds a stored empty name (TrainingMission.cpp:811).
        XCTAssertNoThrow(try base.addingScripting(scripting(
            messages: [.init(name: "", text: "x"), .init(name: "A", text: "")]
        )).validate())

        assertInvalid(scripting(levelScript: ""))
        assertInvalid(scripting(levelScript: "TrainingMission"))
        // No compiled level script lists its references.
        assertInvalid(scripting(levelScript: "other"))
        assertInvalid(scripting(objects: valid.objects + [.init(
            objectHandle: 0xffff_ffff,
            name: nil,
            defaultModuleName: nil,
            defaultScriptName: nil
        )]))
        assertInvalid(scripting(objects: Array(valid.objects.dropLast())))
        assertInvalid(scripting(objects: valid.objects.map {
            .init(
                objectHandle: $0.objectHandle,
                name: $0.name,
                defaultModuleName: $0.defaultModuleName,
                defaultScriptName: ""
            )
        }))
        assertInvalid(scripting(
            messages: [.init(name: "A", text: ""), .init(name: "A", text: "")]
        ))
        // Every name the compiled script lists must be present (P2-2).
        assertInvalid(scripting(streamedAudio: []))
        assertInvalid(scripting(sounds: []))
        assertInvalid(scripting(streamedAudio: Array(valid.streamedAudio.dropFirst())))
        // Keys must be the requested file or page, not another clip (P2-1).
        assertInvalid(scripting(streamedAudio: valid.streamedAudio.map {
            $0.name == "welcome.osf" ? .init(name: $0.name, key: "done.osf") : $0
        }))
        assertInvalid(scripting(sounds: valid.sounds.map {
            $0.name == "PupC1" ? .init(name: $0.name, key: "MenuBeepEnter") : $0
        }))
        assertInvalid(scripting(streamedAudio: valid.streamedAudio.map {
            $0.name == "welcome.osf" ? .init(name: $0.name, key: "missing.osf") : $0
        }))
    }

    /// Hull collision keeps one edge bit per corner in a 32-bit mask
    /// (findintersection.cpp:1600 asserts nv <= 32), so a package model
    /// face with more corners is rejected at the canonical boundary.
    func testModelFaceWithMoreThan32CornersIsRejected() throws {
        var (level, _) = try makeScriptedTrainingLevel()
        XCTAssertNoThrow(try level.validate())
        let modelIndex = try XCTUnwrap(level.models.firstIndex {
            $0.submodels.contains { !$0.faces.isEmpty }
        })
        let model = level.models[modelIndex]
        let submodelIndex = try XCTUnwrap(
            model.submodels.firstIndex { !$0.faces.isEmpty }
        )
        func replacingFirstFace(cornerCount: Int) -> CanonicalModel {
            var submodels = model.submodels
            let submodel = submodels[submodelIndex]
            let face = submodel.faces[0]
            let corners = (0..<cornerCount).map {
                face.corners[$0 % face.corners.count]
            }
            var faces = submodel.faces
            faces[0] = ModelFace(
                normal: face.normal,
                corners: corners,
                material: face.material
            )
            submodels[submodelIndex] = ModelSubmodel(
                sourceIndex: submodel.sourceIndex,
                parentIndex: submodel.parentIndex,
                offset: submodel.offset,
                vertices: submodel.vertices,
                faces: faces,
                presentation: submodel.presentation
            )
            var replaced = CanonicalModel(
                source: model.source,
                collisionRadius: model.collisionRadius,
                submodels: submodels,
                bounds: model.bounds,
                sourceArchive: model.sourceArchive,
                sourceSHA256: model.sourceSHA256
            )
            replaced.gunpoints = model.gunpoints
            replaced.weaponBatteries = model.weaponBatteries
            return replaced
        }
        level.models[modelIndex] = replacingFirstFace(cornerCount: 32)
        XCTAssertNoThrow(try level.validate())
        level.models[modelIndex] = replacingFirstFace(cornerCount: 33)
        XCTAssertThrowsError(try level.validate())
    }
}

// MARK: - Synthetic fixtures

private let levelScriptTestSource = LevelSource(
    profileIdentifier: "synthetic",
    profileFiles: [
        .init(
            relativePath: "missions/synthetic.mn3",
            byteCount: 1,
            sha256: String(repeating: "a", count: 64)
        ),
        .init(
            relativePath: "base.hog",
            byteCount: 1,
            sha256: String(repeating: "e", count: 64)
        ),
    ],
    archiveSHA256: String(repeating: "b", count: 64),
    levelSHA256: String(repeating: "c", count: 64),
    d3lvVersion: 127
)

private func makeLevelScriptImportLevel() throws -> Level {
    let d3l = makeSyntheticD3LV127(
        objectTypes: [2, 7, 11, 17, 9, 1],
        objectStoredIDs: [0, 1, 2, 0, 0, 0],
        objectNames: ["Guard1", "", "Lamp1", "MainDoor", "Cam", "Spark"],
        objectScriptOverrides: [
            ("", ""), ("CustomPage", "CustomMod"), ("", ""),
            ("", ""), ("", ""), ("", ""),
        ],
        genericNamesPayload: levelScriptNameTable(["Tubbs", "Shield", "Lamp"]),
        doorNamesPayload: levelScriptNameTable(["MainDoorPage"])
    )
    let parsed = try parseD3LV127(d3l, source: levelScriptTestSource)
    let pcm = Data(repeating: 0, count: 2)
    return Level(
        missionKey: parsed.missionKey,
        levelKey: parsed.levelKey,
        source: parsed.source,
        metadata: parsed.metadata,
        rooms: parsed.rooms,
        terrain: parsed.terrain,
        objects: parsed.objects,
        paths: parsed.paths,
        goals: parsed.goals,
        triggers: parsed.triggers,
        playerStartFlags: parsed.playerStartFlags,
        lightmaps: parsed.lightmaps,
        voiceClips: [
            .init(
                sourceName: "hello.osf",
                sourceEntryIndex: 0,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/synthetic.mn3",
                sourceSHA256: String(repeating: "d", count: 64)
            ),
        ],
        soundClips: [
            .init(
                logicalName: "Beep",
                sourceName: "BeepSrc.wav",
                sourceEntryIndex: 0,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "base.hog",
                sourceSHA256: String(repeating: "f", count: 64),
                importVolume: 1
            ),
        ],
        dependencyManifest: parsed.dependencyManifest,
        sourceChunks: parsed.sourceChunks
    )
}

/// Mission archive first, as cfile searches the most recently opened library
/// first (cfile.cpp:264, Mission.cpp:1803).
private func makeLevelScriptArchives() -> [LevelScriptArchive] {
    let messages = """
        // comment
        Welcome=Hello pilot
          Spaced = text with = sign   \r
        Empty=
        Welcome=Duplicate ignored
        NoSeparatorLine

        """
    return [
        makeLevelScriptArchive(
            relativePath: "missions/synthetic.mn3",
            entries: [
                ("Hello.OSF", Data([1])),
                ("NoClip.osf", Data([2])),
                ("Synthetic.msg", Data(messages.utf8)),
            ]
        ),
        makeLevelScriptArchive(
            relativePath: "base.hog",
            entries: [("hello.osf", Data([3])), ("beepsrc.WAV", Data([4]))]
        ),
    ]
}

func makeLevelScriptArchive(
    relativePath: String,
    entries: [(String, Data)]
) -> LevelScriptArchive {
    let sorted = entries.sorted {
        $0.0.lowercased().utf8.lexicographicallyPrecedes($1.0.lowercased().utf8)
    }
    var data = Data("HOG2".utf8)
    data.appendLevelScriptUInt32(UInt32(sorted.count))
    data.appendLevelScriptUInt32(UInt32(68 + sorted.count * 48))
    data.append(Data(repeating: 0, count: 56))
    for (name, payload) in sorted {
        var field = Data(name.utf8)
        field.append(Data(repeating: 0, count: 36 - field.count))
        data.append(field)
        data.appendLevelScriptUInt32(0)
        data.appendLevelScriptUInt32(UInt32(payload.count))
        data.appendLevelScriptUInt32(0)
    }
    for (_, payload) in sorted { data.append(payload) }
    return .init(
        relativePath: relativePath,
        data: data,
        archive: try! parseHOG2(data)
    )
}

private func makeLevelScriptTable(tubbsModule: String = "AIGame") -> Data {
    makeRetailPage(type: 10, body: makeGenericPageBody("Tubbs", module: tubbsModule, override: ""))
        + makeRetailPage(type: 10, body: makeGenericPageBody("Shield", type: 7, module: "GenericMod", override: ""))
        + makeRetailPage(type: 10, body: makeGenericPageBody("Lamp", type: 11, module: "", override: "LampScript"))
        + makeRetailPage(type: 5, body: makeDoorPageBody("MainDoorPage", module: "DoorMod"))
        + makeRetailPage(type: 7, body: makeSoundPageBody("Beep", "BeepSrc.wav"))
}

/// extra.gam replaces base pages by name.
private func makeLevelScriptOverlay() -> Data {
    makeRetailPage(type: 10, body: makeGenericPageBody("TUBBS", module: "AIGame3.dll", override: ""))
}

private func makeRetailPage(type: UInt8, body: Data) -> Data {
    var page = Data([type])
    page.appendLevelScriptUInt32(UInt32(body.count + 4))
    page.append(body)
    return page
}

/// manage/generic.cpp:1083 mng_ReadNewGenericPage, version 27.
private func makeGenericPageBody(
    _ name: String,
    type: UInt8 = 2,
    module: String,
    override: String
) -> Data {
    var body = Data()
    body.appendLevelScriptUInt16(27)
    body.append(type)
    for value in [name, "model.oof", "", ""] { body.appendLevelScriptCString(value) }
    body.append(Data(repeating: 0, count: 12))
    body.appendLevelScriptUInt16(0)
    if type == 7 { body.appendLevelScriptUInt16(0) }
    for value in ["", module, override] { body.appendLevelScriptCString(value) }
    body.append(0)
    body.append(Data(repeating: 0xaa, count: 16))
    return body
}

/// manage/doorpage.cpp:261 mng_ReadNewDoorPage, version 3.
private func makeDoorPageBody(_ name: String, module: String) -> Data {
    var body = Data()
    body.appendLevelScriptUInt16(3)
    body.appendLevelScriptCString(name)
    body.appendLevelScriptCString("door.oof")
    body.append(Data(repeating: 0, count: 12))
    body.append(0)
    body.appendLevelScriptUInt16(0)
    for value in ["", "", module] { body.appendLevelScriptCString(value) }
    return body
}

private func makeSoundPageBody(_ name: String, _ source: String) -> Data {
    var body = Data()
    body.appendLevelScriptUInt16(1)
    body.appendLevelScriptCString(name)
    body.appendLevelScriptCString(source)
    // flags, loop start and end, outer cone volume, inner and outer cone
    // angles, maximum and minimum distance (soundpage.cpp).
    body.append(Data(repeating: 0, count: 32))
    body.appendLevelScriptUInt32(Float(1).bitPattern)
    return body
}

private func levelScriptNameTable(_ names: [String]) -> Data {
    var data = Data()
    data.appendLevelScriptUInt32(UInt32(names.count))
    for name in names { data.appendLevelScriptCString(name) }
    return data
}

private extension Data {
    mutating func appendLevelScriptUInt16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func appendLevelScriptUInt32(_ value: UInt32) {
        appendLevelScriptUInt16(UInt16(truncatingIfNeeded: value))
        appendLevelScriptUInt16(UInt16(truncatingIfNeeded: value >> 16))
    }

    mutating func appendLevelScriptCString(_ value: String) {
        append(contentsOf: value.utf8)
        append(0)
    }
}


/// A schema 11 Training fixture with every clip the compiled Training script
/// names, plus the scripting that binds them.
private func makeScriptedTrainingLevel() throws -> (Level, LevelScripting) {
    let base = makeTrainingFinalRoomEntryLevel()
    let references = try XCTUnwrap(
        LevelModule.scriptReferences(forLevelScript: "trainingmission")
    )
    var object = try XCTUnwrap(
        JSONSerialization.jsonObject(with: canonicalJSONData(base))
            as? [String: Any]
    )
    func json(_ value: some Encodable) throws -> Any {
        try JSONSerialization.jsonObject(with: canonicalJSONData(value))
    }
    let pcm = Data(repeating: 0, count: 2)
    var voices = object["voiceClips"] as? [Any] ?? []
    var sounds = object["soundClips"] as? [Any] ?? []
    var manifest = try XCTUnwrap(object["dependencyManifest"] as? [String: Any])
    var records = manifest["current"] as? [Any] ?? []
    let archive = base.source.profileFiles[0].relativePath
    var nextIndex = 60_000
    let voiceNames = Set(base.voiceClips.map(\.sourceName))
    for name in references.streamedAudioNames
    where !voiceNames.contains(name.lowercased()) {
        nextIndex += 1
        let clip = CanonicalVoiceClip(
            sourceName: name.lowercased(),
            sourceEntryIndex: nextIndex,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: archive,
            sourceSHA256: String(repeating: "9", count: 64)
        )
        voices.append(try json(clip))
        records.append(try json(DependencyRecord(
            category: "voice",
            source: .init(storedIndex: nextIndex, sourceName: clip.sourceName),
            state: "canonical-pcm-imported",
            provenance: "synthetic"
        )))
    }
    let soundNames = Set(base.soundClips.map { $0.logicalName.lowercased() })
    for name in references.soundNames
    where !soundNames.contains(name.lowercased()) {
        nextIndex += 1
        let clip = CanonicalSoundClip(
            logicalName: name,
            sourceName: "\(name)Synthetic.wav",
            sourceEntryIndex: nextIndex,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: archive,
            sourceSHA256: String(repeating: "8", count: 64),
            importVolume: 1
        )
        sounds.append(try json(clip))
        records.append(try json(DependencyRecord(
            category: "sound",
            source: .init(storedIndex: nextIndex, sourceName: clip.sourceName),
            state: "canonical-pcm-imported",
            provenance: "synthetic"
        )))
    }
    object["voiceClips"] = voices
    object["soundClips"] = sounds
    manifest["current"] = records
    object["dependencyManifest"] = manifest
    let level = try JSONDecoder().decode(
        Level.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
    try level.validate()

    let scripting = LevelScripting(
        levelScript: "trainingmission",
        objects: level.objects
            .filter { LevelScripting.scriptableObjectTypes.contains($0.type) }
            .map {
                .init(
                    objectHandle: $0.handle,
                    name: $0.instanceName,
                    defaultModuleName: $0.type == 9 ? nil : "aigame",
                    defaultScriptName: $0.type == 9 ? nil : "Page"
                )
            },
        messages: [.init(name: "Welcome", text: "Hi")],
        streamedAudio: references.streamedAudioNames.map {
            .init(name: $0, key: $0.lowercased())
        },
        sounds: try references.soundNames.map { name in
            let clip = try XCTUnwrap(level.soundClips.first {
                $0.logicalName.caseInsensitiveCompare(name) == .orderedSame
            })
            return .init(name: name, key: clip.logicalName)
        }
    )
    return (level, scripting)
}
