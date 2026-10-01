import Foundation

struct TrainingGalleryBarrier: Codable, Equatable, Sendable {
    let triggerName: String
    let triggerRoomSourceIndex: Int
    let triggerFaceIndex: Int
    let barrierRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let markerLightObjectHandle: UInt32
    let openMarkerLightDistance: Float
    let successMessage: String
    let guidebotInstruction: String
    let voiceSourceName: String
}

struct TrainingRobotGuidebotChain: Codable, Equatable, Sendable {
    let guidebotObjectHandle: UInt32
    let deployedGuidebotObjectType: UInt8
    let deployedGuidebotMessage: String
    let deployedGuidebotVoiceSourceName: String
    var releaseSoundSourceName: String? = nil
    var ambientEngineSoundSourceName: String? = nil
    let guidebot: TrainingGuidebotDefinition
}

struct TrainingGuidebotDefinition: Codable, Equatable, Sendable {
    let collisionRadius: Float
    let maximumVelocity: Float
    let maximumDeltaVelocity: Float
    let birthForwardVelocity: Float
    let goalForwardDistance: Float
    let goalCircleDistance: Float
}

extension TrainingGuidebotDefinition {
    static let stockTraining = Self(
        collisionRadius: 5.659_440_5,
        maximumVelocity: 60,
        maximumDeltaVelocity: 199.999_98,
        birthForwardVelocity: 40,
        goalForwardDistance: 200,
        goalCircleDistance: 1
    )
}

struct CanonicalVoiceClip: Codable, Equatable, Sendable {
    let sourceName: String
    let sourceEntryIndex: Int
    let sampleRate: Int
    let channelCount: Int
    let frameCount: Int
    let pcm16LittleEndian: Data
    let pcmSHA256: String
    let sourceArchive: String
    let sourceSHA256: String
}

struct CanonicalSoundClip: Codable, Equatable, Sendable {
    let logicalName: String
    let sourceName: String
    let sourceEntryIndex: Int
    let sampleRate: Int
    let channelCount: Int
    let frameCount: Int
    let pcm16LittleEndian: Data
    let pcmSHA256: String
    let sourceArchive: String
    let sourceSHA256: String
    let importVolume: Float
}

@propertyWrapper
struct SchemaCompatibleSoundClips:
    Codable, Equatable, Sendable
{
    var wrappedValue: [CanonicalSoundClip]
    let wasPresent: Bool

    init(wrappedValue: [CanonicalSoundClip]) {
        self.wrappedValue = wrappedValue
        wasPresent = true
    }

    fileprivate init(missing: Void) {
        wrappedValue = []
        wasPresent = false
    }

    init(from decoder: Decoder) throws {
        wrappedValue = try decoder.singleValueContainer()
            .decode([CanonicalSoundClip].self)
        wasPresent = true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    func decode(
        _ type: SchemaCompatibleSoundClips.Type,
        forKey key: Key
    ) throws -> SchemaCompatibleSoundClips {
        try decodeIfPresent(type, forKey: key)
            ?? SchemaCompatibleSoundClips(missing: ())
    }
}

