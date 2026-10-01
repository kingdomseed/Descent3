import XCTest

// Builders for the synthetic levels. They name the fields a fixture sets
// and give the other stored fields their empty values.

extension PlacedObject {
    /// A placed object as the level file stores it.
    static func fixture(
        handle: UInt32, type: UInt8, storedID: Int,
        definition: SourceResource? = nil, name: String? = nil,
        flags: UInt32 = 0, doorShields: Int16? = nil, location: SpatialLocation,
        position: Vector3, orientation: Matrix3, containsType: UInt8 = 0,
        containsID: UInt8 = 0, containsCount: UInt8 = 0, lifeLeft: Float = 0,
        soundSource: ObjectSoundSource? = nil, inertScriptName: String? = nil,
        inertModuleName: String? = nil,
        lightmapSubmodels: [ObjectLightmapSubmodel] = []
    ) -> PlacedObject {
        PlacedObject(
            handle: handle, type: type, storedID: storedID,
            definition: definition, instanceName: name, flags: flags,
            doorShields: doorShields, location: location, position: position,
            orientation: orientation, containsType: containsType,
            containsID: containsID, containsCount: containsCount,
            lifeLeft: lifeLeft, soundSource: soundSource,
            inertScriptName: inertScriptName, inertModuleName: inertModuleName,
            lightmapSubmodels: lightmapSubmodels
        )
    }
}

extension ObjectPresentationReference {
    /// An object drawn with one model and no level of detail.
    static func fixture(
        _ objectHandle: UInt32, _ model: SourceResource, isVisible: Bool = true
    ) -> ObjectPresentationReference {
        ObjectPresentationReference(
            objectHandle: objectHandle, primaryModel: model, mediumModel: nil,
            lowModel: nil, dyingModel: nil, mediumDistance: nil,
            lowDistance: nil, isVisible: isVisible
        )
    }
}

/// One silent 16-bit sample.
let silentPCM = Data(repeating: 0, count: 2)

extension CanonicalVoiceClip {
    /// A silent one-frame mono stream.
    static func silent(
        _ sourceName: String, index: Int,
        archive: String = "missions/training.mn3", sourceSHA256: String
    ) -> CanonicalVoiceClip {
        CanonicalVoiceClip(
            sourceName: sourceName, sourceEntryIndex: index, sampleRate: 22_050,
            channelCount: 1, frameCount: 1, pcm16LittleEndian: silentPCM,
            pcmSHA256: canonicalSHA256(silentPCM), sourceArchive: archive,
            sourceSHA256: sourceSHA256
        )
    }
}

extension CanonicalSoundClip {
    /// A silent one-frame mono sound page clip.
    static func silent(
        logicalName: String, sourceName: String, index: Int,
        archive: String = "missions/training.mn3", sourceSHA256: String,
        importVolume: Float = 1
    ) -> CanonicalSoundClip {
        CanonicalSoundClip(
            logicalName: logicalName, sourceName: sourceName,
            sourceEntryIndex: index, sampleRate: 22_050, channelCount: 1,
            frameCount: 1, pcm16LittleEndian: silentPCM,
            pcmSHA256: canonicalSHA256(silentPCM), sourceArchive: archive,
            sourceSHA256: sourceSHA256, importVolume: importVolume
        )
    }
}

/// The room with some fields changed. A double optional changes an
/// optional field (`.some(nil)` clears it).
func replacing(
    _ room: LevelRoom, sourceIndex: Int? = nil, name: String?? = nil,
    pathPoint: Vector3? = nil, vertices: [Vector3]? = nil,
    faces: [LevelFace]? = nil, portals: [LevelPortal]? = nil,
    flags: UInt32? = nil, pulseTime: UInt8? = nil, pulseOffset: UInt8? = nil,
    mirrorFaceIndex: Int?? = nil, door: RoomDoor?? = nil,
    volumeLights: VolumeLightGrid?? = nil, fog: RoomFog? = nil,
    ambientSoundPattern: String?? = nil, reverb: UInt8? = nil,
    damage: Float? = nil, damageType: UInt8? = nil
) -> LevelRoom {
    LevelRoom(
        sourceIndex: sourceIndex ?? room.sourceIndex, name: name ?? room.name,
        pathPoint: pathPoint ?? room.pathPoint,
        vertices: vertices ?? room.vertices, faces: faces ?? room.faces,
        portals: portals ?? room.portals, flags: flags ?? room.flags,
        pulseTime: pulseTime ?? room.pulseTime,
        pulseOffset: pulseOffset ?? room.pulseOffset,
        mirrorFaceIndex: mirrorFaceIndex ?? room.mirrorFaceIndex,
        door: door ?? room.door,
        volumeLights: volumeLights ?? room.volumeLights, fog: fog ?? room.fog,
        ambientSoundPattern: ambientSoundPattern ?? room.ambientSoundPattern,
        reverb: reverb ?? room.reverb, damage: damage ?? room.damage,
        damageType: damageType ?? room.damageType
    )
}

/// The face with some fields changed (`portalIndex: .some(nil)` makes it a
/// plain face).
func replacing(
    _ face: LevelFace, corners: [FaceCorner]? = nil, flags: UInt16? = nil,
    portalIndex: Int?? = nil, texture: SourceResource? = nil,
    lightmapInfoIndex: Int?? = nil, allowsLightCorona: Bool? = nil,
    lightMultiple: UInt8? = nil, special: SpecialFace?? = nil
) -> LevelFace {
    LevelFace(
        corners: corners ?? face.corners, flags: flags ?? face.flags,
        portalIndex: portalIndex ?? face.portalIndex,
        texture: texture ?? face.texture,
        lightmapInfoIndex: lightmapInfoIndex ?? face.lightmapInfoIndex,
        allowsLightCorona: allowsLightCorona ?? face.allowsLightCorona,
        lightMultiple: lightMultiple ?? face.lightMultiple,
        special: special ?? face.special
    )
}
