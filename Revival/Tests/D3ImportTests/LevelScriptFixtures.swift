import XCTest

/// The Training messages the synthetic fixtures use for Script 002.
let fixtureTrainingMessages = [
    LevelScriptMessage(
        name: "Welcome",
        text: "Welcome to the Descent 3 Training session."
    ),
    LevelScriptMessage(name: "GoForward", text: "Move forward until you stop."),
]

/// The level with Training script data (package schema 12), so the world
/// loads the Training level module. Every scriptable object gets a binding,
/// as D3Import writes one. The level keeps every other field. It validates
/// only when the level holds the clips the Training module names.
func addingTrainingMissionScripting(
    _ level: Level,
    messages: [LevelScriptMessage] = fixtureTrainingMessages
) -> Level {
    let level = withTrainingStreamPadding(level)
    let bindings = level.objects
        .filter { LevelScripting.scriptableObjectTypes.contains($0.type) }
        .map { object in
            let customOnly = object.type == LevelScripting.customOnlyObjectType
            return ObjectScriptBinding(
                objectHandle: object.handle,
                name: object.instanceName,
                defaultModuleName: customOnly ? nil : "aigame",
                defaultScriptName: customOnly ? nil : "Fixture"
            )
        }
    return level.addingScripting(
        LevelScripting(
            levelScript: "trainingmission",
            objects: bindings,
            messages: messages,
            streamedAudio: TrainingMissionScript.streamedAudioNames.map {
                LevelScriptAudioReference(name: $0, key: $0.lowercased())
            },
            sounds: TrainingMissionScript.soundNames.map {
                LevelScriptAudioReference(name: $0, key: $0)
            }
        )
    )
}

/// The source SHA-256 that marks a fixture padding clip.
private let paddingClipSHA256 = String(repeating: "f", count: 64)

/// The level with silent padding clips for every stream the Training module
/// names and the level lacks, so a scripted fixture validates. Earlier
/// padding is dropped first, so a fixture that later adds a real clip of the
/// same name keeps only the real one.
func withTrainingStreamPadding(_ level: Level) -> Level {
    func isPadding(_ record: DependencyRecord) -> Bool {
        record.category == "voice"
            && record.provenance.hasSuffix(paddingClipSHA256)
    }
    let kept = level.voiceClips.filter { $0.sourceSHA256 != paddingClipSHA256 }
    let keptDependencies = level.dependencyManifest.current.filter {
        !isPadding($0)
    }
    // A test that removes a real clip but keeps its dependency record gets
    // no padding for it, so its own validation error still shows.
    let recordedVoices = Set(keptDependencies.filter {
        $0.category == "voice"
    }.map { $0.source.sourceName.lowercased() })
    let padding = fixtureTrainingStreamClips(excluding: kept).filter {
        !recordedVoices.contains($0.sourceName)
    }
    let dependencies = keptDependencies + padding.map {
        DependencyRecord(
            category: "voice",
            source: .init(
                storedIndex: $0.sourceEntryIndex,
                sourceName: $0.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance: "\($0.sourceArchive) \($0.sourceSHA256)"
        )
    }
    // Schema 11 here, so `replacing` does not bind scripts again; the
    // caller adds the script data.
    return replacing(
        level,
        schemaVersion: 11,
        voiceClips: kept + padding,
        dependencyManifest: .init(
            current: dependencies,
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
}

private func fixtureTrainingStreamClips(
    excluding existing: [CanonicalVoiceClip]
) -> [CanonicalVoiceClip] {
    let pcm = Data(repeating: 0, count: 2)
    let present = Set(existing.map { $0.sourceName.lowercased() })
    return TrainingMissionScript.streamedAudioNames
        .map { $0.lowercased() }
        .filter { !present.contains($0) }
        .enumerated()
        .map { offset, name in
            CanonicalVoiceClip(
                sourceName: name,
                sourceEntryIndex: 900 + offset,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: paddingClipSHA256
            )
        }
}

/// A copy of a placed object with another name.
func renamed(_ object: PlacedObject, _ name: String?) -> PlacedObject {
    PlacedObject(
        handle: object.handle,
        type: object.type,
        storedID: object.storedID,
        definition: object.definition,
        instanceName: name,
        flags: object.flags,
        doorShields: object.doorShields,
        location: object.location,
        position: object.position,
        orientation: object.orientation,
        containsType: object.containsType,
        containsID: object.containsID,
        containsCount: object.containsCount,
        lifeLeft: object.lifeLeft,
        soundSource: object.soundSource,
        inertScriptName: object.inertScriptName,
        inertModuleName: object.inertModuleName,
        lightmapSubmodels: object.lightmapSubmodels
    )
}

extension GameWorld {
    /// The Training module state, or `nil` when another module is loaded.
    var testTrainingMission: TrainingMissionState? {
        guard case let .trainingMission(state) = levelModule else {
            return nil
        }
        return state
    }
}

/// Moves every pending Osiris timer in a test world object to Gametime
/// `time`, so a test that starts mid-lesson does not see Script 002.
func deferringOsirisTimers(
    _ object: inout [String: Any],
    to time: Float
) throws {
    var timers = try XCTUnwrap(object["osirisTimers"] as? [String: Any])
    var entries = try XCTUnwrap(timers["entries"] as? [[String: Any]])
    for index in entries.indices where entries[index]["isUsed"] as? Bool == true {
        entries[index]["nextSignal"] = time
        entries[index]["end"] = time
    }
    timers["entries"] = entries
    object["osirisTimers"] = timers
}

/// A fixture level whose objects changed after it got Training script
/// data: the bindings are made again from its objects, as D3Import would.
func rescriptedTrainingLevel(_ level: Level) -> Level {
    guard let scripting = level.scripting else { return level }
    return addingTrainingMissionScripting(level, messages: scripting.messages)
}
