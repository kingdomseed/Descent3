import Foundation

private func canonicalPCM16ByteCount(
    frameCount: Int,
    channelCount: Int
) -> Int? {
    let (sampleCount, sampleOverflow) =
        frameCount.multipliedReportingOverflow(by: channelCount)
    guard !sampleOverflow else { return nil }
    let (byteCount, byteOverflow) =
        sampleCount.multipliedReportingOverflow(by: 2)
    return byteOverflow ? nil : byteCount
}
struct Level: Codable, Equatable, Sendable {
    private(set) var schemaVersion: Int
    let missionKey: String
    let levelKey: String
    let source: LevelSource
    let metadata: LevelMetadata
    var rooms: [LevelRoom]
    let terrain: LevelTerrain
    var objects: [PlacedObject]
    let retiredObjectHandles: [UInt32]
    var paths: [GamePath]
    var goals: [LevelGoal]
    let goalFlags: UInt32
    let triggers: [LevelTrigger]
    let playerStartFlags: [UInt32]
    let indoorNavigation: IndoorNavigationGraph?
    let lightmaps: LightmapCatalog
    var surfacePhysics: [SurfacePhysicsEntry]
    let presentationMaterials: [PresentationMaterial]
    let presentationCoronaAssets: [PresentationCoronaAsset]
    var models: [CanonicalModel]
    var shipDefinitions: [CanonicalShipDefinition]
    let defaultPlayerBinding: DefaultPlayerBinding?
    var objectPresentations: [ObjectPresentationReference]
    let trainingGalleryBarrier: TrainingGalleryBarrier?
    let trainingRobotGuidebotChain: TrainingRobotGuidebotChain?
    let trainingCameraMonitorChain: TrainingCameraMonitorChain?
    var trainingFinalBotsCompletionChain:
        TrainingFinalBotsCompletionChain? = nil
    var trainingFinalGoalChain: TrainingFinalGoalChain? = nil
    let trainingInvulnerabilityPickupChain: TrainingInvulnerabilityPickupChain?
    let trainingCloakPickupChain: TrainingCloakPickupChain?
    let trainingLastRoomChain: TrainingLastRoomChain?
    let trainingFinalRoomEntryChain: TrainingFinalRoomEntryChain?
    let voiceClips: [CanonicalVoiceClip]
    @SchemaCompatibleSoundClips
    private(set) var soundClips: [CanonicalSoundClip]
    private(set) var dependencyManifest: DependencyManifest
    let sourceChunks: [SourceChunkRecord]
    /// Schema 12 generic script data (LevelScripting.swift). Absent before 12.
    private(set) var scripting: LevelScripting? = nil
    /// Object_info for the generic pages the placed objects use
    /// (ObjectInfo.swift). Optional in schema 12; absent means no object
    /// has AI.
    var objectInfos: [CanonicalObjectInfo]? = nil
    /// Weapons[] for the weapons those pages fire (ObjectInfo.swift).
    var weapons: [CanonicalWeapon]? = nil
    /// The data of each compiled game module the objects reach
    /// (`reachedGameModules`, LevelScripting.swift), in module name order.
    /// Absent before M1 step 8b.
    var gameModules: [GameModuleScripting]? = nil
    /// The BOA tables the level file stores (the CBOA chunk,
    /// BOATables.swift), when they match the level. Absent before M1 step
    /// 8b; the runtime then makes them as MakeBOA would.
    var boaTables: BOATables? = nil

    init(
        schemaVersion: Int = 9,
        missionKey: String,
        levelKey: String,
        source: LevelSource,
        metadata: LevelMetadata,
        rooms: [LevelRoom],
        terrain: LevelTerrain,
        objects: [PlacedObject],
        retiredObjectHandles: [UInt32] = [],
        paths: [GamePath],
        goals: [LevelGoal],
        goalFlags: UInt32 = 0,
        triggers: [LevelTrigger],
        playerStartFlags: [UInt32],
        indoorNavigation: IndoorNavigationGraph? = nil,
        lightmaps: LightmapCatalog,
        surfacePhysics: [SurfacePhysicsEntry]? = nil,
        presentationMaterials: [PresentationMaterial] = [],
        presentationCoronaAssets: [PresentationCoronaAsset] = [],
        models: [CanonicalModel] = [],
        shipDefinitions: [CanonicalShipDefinition] = [],
        defaultPlayerBinding: DefaultPlayerBinding? = nil,
        objectPresentations: [ObjectPresentationReference] = [],
        trainingGalleryBarrier: TrainingGalleryBarrier? = nil,
        trainingRobotGuidebotChain: TrainingRobotGuidebotChain? = nil,
        trainingCameraMonitorChain: TrainingCameraMonitorChain? = nil,
        trainingInvulnerabilityPickupChain:
            TrainingInvulnerabilityPickupChain? = nil,
        trainingCloakPickupChain: TrainingCloakPickupChain? = nil,
        trainingLastRoomChain: TrainingLastRoomChain? = nil,
        trainingFinalRoomEntryChain: TrainingFinalRoomEntryChain? = nil,
        trainingFinalBotsCompletionChain:
            TrainingFinalBotsCompletionChain? = nil,
        trainingFinalGoalChain: TrainingFinalGoalChain? = nil,
        voiceClips: [CanonicalVoiceClip] = [],
        soundClips: [CanonicalSoundClip] = [],
        dependencyManifest: DependencyManifest,
        sourceChunks: [SourceChunkRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.missionKey = missionKey
        self.levelKey = levelKey
        self.source = source
        self.metadata = metadata
        self.rooms = rooms
        self.terrain = terrain
        self.objects = objects
        self.retiredObjectHandles = retiredObjectHandles
        self.paths = paths
        self.goals = goals
        self.goalFlags = goalFlags
        self.triggers = triggers
        self.playerStartFlags = playerStartFlags
        self.indoorNavigation = indoorNavigation
        self.lightmaps = lightmaps
        self.surfacePhysics = surfacePhysics ?? Self.defaultSurfacePhysics(for: rooms)
        self.presentationMaterials = presentationMaterials
        self.presentationCoronaAssets = presentationCoronaAssets
        self.models = models
        self.shipDefinitions = shipDefinitions
        self.defaultPlayerBinding = defaultPlayerBinding
        self.objectPresentations = objectPresentations
        self.trainingGalleryBarrier = trainingGalleryBarrier
        self.trainingRobotGuidebotChain = trainingRobotGuidebotChain
        self.trainingCameraMonitorChain = trainingCameraMonitorChain
        self.trainingInvulnerabilityPickupChain =
            trainingInvulnerabilityPickupChain
        self.trainingCloakPickupChain = trainingCloakPickupChain
        self.trainingLastRoomChain = trainingLastRoomChain
        self.trainingFinalRoomEntryChain = trainingFinalRoomEntryChain
        self.trainingFinalBotsCompletionChain =
            trainingFinalBotsCompletionChain
        self.trainingFinalGoalChain = trainingFinalGoalChain
        self.voiceClips = voiceClips
        self.soundClips = soundClips
        self.dependencyManifest = dependencyManifest
        self.sourceChunks = sourceChunks
    }

    /// Package schema 12: adds the generic level script data.
    func addingScripting(_ scripting: LevelScripting) -> Level {
        var level = self
        level.schemaVersion = 12
        level.scripting = scripting
        return level
    }

    func validate() throws {
        try validate(
            allowImportStagingPresentation: false,
            enforceStockSourceInvariants: true
        )
    }

    func validateForAuthoring() throws {
        try validate(
            allowImportStagingPresentation: false,
            enforceStockSourceInvariants: false
        )
    }

    func validateForImportStaging() throws {
        try validate(
            allowImportStagingPresentation: true,
            enforceStockSourceInvariants: true
        )
    }

    private func validate(
        allowImportStagingPresentation: Bool,
        enforceStockSourceInvariants: Bool
    ) throws {
        guard (
            schemaVersion == 9
                && trainingCameraMonitorChain == nil
                && trainingFinalBotsCompletionChain == nil
            || schemaVersion == 10
                && trainingCameraMonitorChain != nil
                && trainingFinalBotsCompletionChain == nil
                && _soundClips.wasPresent
            || schemaVersion == 11
                && trainingCameraMonitorChain != nil
                && _soundClips.wasPresent
            || schemaVersion == 12 && _soundClips.wasPresent
        ),
              (scripting != nil) == (schemaVersion == 12),
              source.d3lvVersion == 127,
              !missionKey.isEmpty, !levelKey.isEmpty else {
            throw LevelValidationError.invalidIdentity
        }
        try validateSource(source)
        try validateLightmaps(lightmaps)
        try validatePresentation(
            materials: presentationMaterials,
            coronaAssets: presentationCoronaAssets,
            source: source
        )
        try validateModels(
            models,
            objectPresentations: objectPresentations,
            materials: presentationMaterials,
            objects: objects,
            source: source,
            dynamicallyPresentedModelNames: (
                trainingRobotGuidebotChain == nil
                    ? []
                    : ["Buddybot.oof"])
                + (weapons ?? []).compactMap(\.model?.sourceName)
        )
        guard rooms.count <= 400,
              rooms.allSatisfy({ (0..<400).contains($0.sourceIndex) }) else {
            throw LevelValidationError.invalidCount("rooms")
        }
        guard Set(rooms.map(\.sourceIndex)).count == rooms.count else {
            throw LevelValidationError.duplicateRoom
        }
        // compute_costs asserts num_portals <= MAX_PATH_PORTALS
        // (BOA.cpp:883); BOA_cost_array has that many columns.
        guard rooms.allSatisfy({
            $0.portals.count <= BOATables.maximumPathPortals
        }) else {
            throw LevelValidationError.invalidCount("room portals")
        }
        try validateSurfacePhysics(
            surfacePhysics,
            rooms: rooms,
            allowIncomplete: allowImportStagingPresentation
        )
        try validatePlayerShipBinding()
        guard objects.count <= 1_500 else {
            throw LevelValidationError.invalidCount("objects")
        }
        guard paths.count <= 300 else {
            throw LevelValidationError.invalidCount("paths")
        }
        guard goals.count <= 32 else {
            throw LevelValidationError.invalidCount("goals")
        }
        guard playerStartFlags.count <= 32 else {
            throw LevelValidationError.invalidCount("player start flags")
        }
        let roomMap = Dictionary(uniqueKeysWithValues: rooms.map { ($0.sourceIndex, $0) })
        try validateIndoorNavigation(indoorNavigation, rooms: roomMap)

        for room in rooms {
            guard room.vertices.count <= 10_000, room.faces.count <= 3_000 else {
                throw LevelValidationError.invalidCount("room \(room.sourceIndex)")
            }
            if let mirrorFaceIndex = room.mirrorFaceIndex,
               !room.faces.indices.contains(mirrorFaceIndex) {
                throw LevelValidationError.invalidMirrorFace(room: room.sourceIndex)
            }
            if let volumeLights = room.volumeLights {
                guard (0...Int(Int16.max)).contains(volumeLights.width),
                      (0...Int(Int16.max)).contains(volumeLights.height),
                      (0...Int(Int16.max)).contains(volumeLights.depth) else {
                    throw LevelValidationError.invalidVolumeLights(room: room.sourceIndex)
                }
                let count = volumeLights.width * volumeLights.height * volumeLights.depth
                guard count == volumeLights.values.count else {
                    throw LevelValidationError.invalidVolumeLights(room: room.sourceIndex)
                }
            }
            for (faceIndex, face) in room.faces.enumerated() {
                guard (3...64).contains(face.corners.count),
                      face.corners.allSatisfy({ room.vertices.indices.contains($0.vertexIndex) }) else {
                    throw LevelValidationError.invalidFace(room: room.sourceIndex, face: faceIndex)
                }
                let cornerIndices = face.corners.map(\.vertexIndex)
                guard Set(cornerIndices).count == cornerIndices.count else {
                    throw LevelValidationError.degenerateFace(
                        room: room.sourceIndex,
                        face: faceIndex
                    )
                }
                guard let normal = canonicalFaceNormal(room: room, face: face) else {
                    throw LevelValidationError.invalidFace(room: room.sourceIndex, face: faceIndex)
                }
                guard faceIsPlanar(room: room, face: face, normal: normal) else {
                    throw LevelValidationError.nonplanarFace(
                        room: room.sourceIndex,
                        face: faceIndex
                    )
                }
                guard !faceIsConcave(room: room, face: face, normal: normal) else {
                    throw LevelValidationError.concaveFace(
                        room: room.sourceIndex,
                        face: faceIndex
                    )
                }
                let hasLightmap = face.flags & 0x0001 != 0
                let hasAnyLightmapUV = face.corners.contains {
                    $0.lightmapU != nil || $0.lightmapV != nil
                }
                let hasCompleteLightmapUV = face.corners.allSatisfy {
                    $0.lightmapU != nil && $0.lightmapV != nil
                }
                guard hasLightmap
                    ? (face.lightmapInfoIndex != nil && hasCompleteLightmapUV)
                    : (face.lightmapInfoIndex == nil && !hasAnyLightmapUV) else {
                    throw LevelValidationError.invalidFace(room: room.sourceIndex, face: faceIndex)
                }
                if let special = face.special {
                    guard special.smoothedVertexNormals.isEmpty
                        || special.smoothedVertexNormals.count == face.corners.count else {
                        throw LevelValidationError.invalidSpecialFace(
                            room: room.sourceIndex,
                            face: faceIndex
                        )
                    }
                }
                if let portalIndex = face.portalIndex {
                    guard room.portals.indices.contains(portalIndex),
                          room.portals[portalIndex].faceIndex == faceIndex else {
                        throw LevelValidationError.invalidFacePortal(room: room.sourceIndex, face: faceIndex)
                    }
                }
                if let lightmap = face.lightmapInfoIndex,
                   !lightmaps.infos.indices.contains(lightmap) {
                    throw LevelValidationError.invalidLightmapReference(lightmap)
                }
            }
            for (portalIndex, portal) in room.portals.enumerated() {
                guard room.faces.indices.contains(portal.faceIndex),
                      room.faces[portal.faceIndex].portalIndex == portalIndex,
                      let connected = roomMap[portal.connectedRoom],
                      connected.portals.indices.contains(portal.connectedPortal) else {
                    throw LevelValidationError.invalidPortal(room: room.sourceIndex, portal: portalIndex)
                }
                let inverse = connected.portals[portal.connectedPortal]
                guard inverse.connectedRoom == room.sourceIndex,
                      inverse.connectedPortal == portalIndex else {
                    throw LevelValidationError.nonreciprocalPortal(room: room.sourceIndex, portal: portalIndex)
                }
                if portal.flags & 0x0000_0008 != 0 {
                    guard room.portals.indices.contains(portal.combineMaster) else {
                        throw LevelValidationError.invalidCombinedPortal(
                            room: room.sourceIndex,
                            portal: portalIndex
                        )
                    }
                    let master = room.portals[portal.combineMaster]
                    guard master.flags & 0x0000_0008 != 0,
                          master.combineMaster == portal.combineMaster,
                          master.connectedRoom == portal.connectedRoom,
                          (master.flags & 0x0000_0001) == (portal.flags & 0x0000_0001) else {
                        throw LevelValidationError.invalidCombinedPortal(
                            room: room.sourceIndex,
                            portal: portalIndex
                        )
                    }
                }
            }
        }

        for room in rooms {
            for (portalIndex, portal) in room.portals.enumerated() {
                let connected = roomMap[portal.connectedRoom]!
                let inverse = connected.portals[portal.connectedPortal]
                guard reciprocalPortalGeometryMatches(
                    room: room,
                    portal: portal,
                    connectedRoom: connected,
                    connectedPortal: inverse
                ) else {
                    throw LevelValidationError.mismatchedPortalGeometry(
                        room: room.sourceIndex,
                        portal: portalIndex
                    )
                }
            }
        }

        guard terrain.heights.count == 65_536,
              terrain.textureCells.count == 1_024,
              terrain.flags.count == 65_536,
              terrain.light.count == 65_536,
              terrain.red.count == 65_536,
              terrain.green.count == 65_536,
              terrain.blue.count == 65_536,
              terrain.dynamicLight.count == 65_536,
              terrain.occlusionMap.count == 8_192 else {
            throw LevelValidationError.invalidTerrain
        }
        if let sky = terrain.sky {
            guard sky.satellites.count <= 5 else {
                throw LevelValidationError.invalidCount("terrain satellites")
            }
        }

        var handles = Set<UInt32>()
        var objectSlots = Set<Int>()
        var playerIDs = Set<Int>()
        for object in objects {
            guard handles.insert(object.handle).inserted,
                  D3SourceIdentity.isValidHandle(object.handle),
                  objectSlots.insert(object.slot).inserted else {
                throw LevelValidationError.invalidObjectHandle(object.handle)
            }
            guard D3SourceIdentity.isSerializedObjectType(object.type) else {
                throw LevelValidationError.invalidObjectType(object.type)
            }
            guard D3SourceIdentity.isValidStoredID(object.storedID) else {
                throw LevelValidationError.invalidObjectStoredID(
                    handle: object.handle,
                    storedID: object.storedID
                )
            }
            if object.type == D3SourceIdentity.playerObjectType {
                guard (0..<D3SourceIdentity.maximumPlayers).contains(object.storedID) else {
                    throw LevelValidationError.invalidPlayerID(
                        handle: object.handle,
                        playerID: object.storedID
                    )
                }
                guard playerIDs.insert(object.storedID).inserted else {
                    throw LevelValidationError.duplicatePlayerID(
                        handle: object.handle,
                        playerID: object.storedID
                    )
                }
            }
            guard D3SourceIdentity.definitionBearingObjectTypes.contains(object.type)
                    == (object.definition != nil) else {
                throw LevelValidationError.invalidObjectDefinition(object.handle)
            }
            if let definition = object.definition {
                guard definition.storedIndex == object.storedID else {
                    throw LevelValidationError.invalidObjectDefinition(object.handle)
                }
            }
            try validateObjectLocation(object.location, rooms: roomMap)
            guard isFinite(object.position) else {
                throw LevelValidationError.invalidObjectPosition(object.handle)
            }
            guard isOrthonormal(object.orientation) else {
                throw LevelValidationError.invalidObjectOrientation(object.handle)
            }
            for submodel in object.lightmapSubmodels {
                for face in submodel.faces {
                    guard lightmaps.infos.indices.contains(face.lightmapInfoIndex) else {
                        throw LevelValidationError.invalidLightmapReference(face.lightmapInfoIndex)
                    }
                }
            }
        }
        if let barrier = trainingGalleryBarrier {
            let oneShotFlag: UInt16 = 8
            let playerActivator: UInt16 = 1
            let rendersFaces: UInt32 = 1
            let clipNames = Set(voiceClips.map {
                $0.sourceName.lowercased()
            })
            guard isNonempty(barrier.triggerName),
                  isNonempty(barrier.successMessage),
                  isNonempty(barrier.guidebotInstruction),
                  isNonempty(barrier.voiceSourceName),
                  barrier.openMarkerLightDistance.isFinite,
                  barrier.openMarkerLightDistance > 0,
                  barrier.orderedPortalIndices.count == 2,
                  Set(barrier.orderedPortalIndices).count == 2,
                  let markerLight = objects.first(where: {
                      $0.handle == barrier.markerLightObjectHandle
                  }),
                  markerLight.type == 11,
                  markerLight.instanceName == "FlashLight-2",
                  clipNames.contains(barrier.voiceSourceName.lowercased()),
                  triggers.contains(where: {
                      $0.name == barrier.triggerName
                          && $0.roomIndex
                              == barrier.triggerRoomSourceIndex
                          && $0.faceIndex == barrier.triggerFaceIndex
                          && $0.flags == oneShotFlag
                          && $0.activator == playerActivator
                  }),
                  let triggerRoom =
                    roomMap[barrier.triggerRoomSourceIndex],
                  triggerRoom.faces.indices.contains(
                      barrier.triggerFaceIndex
                  ),
                  let barrierRoom =
                    roomMap[barrier.barrierRoomSourceIndex]
            else {
                throw LevelValidationError.invalidDependency(
                    "Training gallery barrier"
                )
            }
            var portalRenderingStates: [Bool] = []
            for portalIndex in barrier.orderedPortalIndices {
                guard barrierRoom.portals.indices.contains(portalIndex)
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training gallery barrier"
                    )
                }
                let portal = barrierRoom.portals[portalIndex]
                guard barrierRoom.faces.indices.contains(portal.faceIndex),
                      barrierRoom.faces[portal.faceIndex].portalIndex
                          == portalIndex,
                      let physics = surfacePhysics.first(where: {
                          $0.texture
                              == barrierRoom.faces[portal.faceIndex].texture
                      }),
                      physics.behavior == .forceField,
                      presentationMaterials.contains(where: {
                          $0.texture
                              == barrierRoom.faces[portal.faceIndex].texture
                              && $0.waterProcedural != nil
                      }),
                      let connectedRoom = roomMap[portal.connectedRoom],
                      connectedRoom.portals.indices.contains(
                          portal.connectedPortal
                      )
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training gallery barrier"
                    )
                }
                let reciprocal =
                    connectedRoom.portals[portal.connectedPortal]
                guard reciprocal.connectedRoom
                        == barrier.barrierRoomSourceIndex,
                      reciprocal.connectedPortal == portalIndex,
                      connectedRoom.faces.indices.contains(
                          reciprocal.faceIndex
                      ),
                      connectedRoom.faces[reciprocal.faceIndex].portalIndex
                          == portal.connectedPortal,
                      let reciprocalPhysics =
                        surfacePhysics.first(where: {
                            $0.texture
                                == connectedRoom.faces[
                                    reciprocal.faceIndex
                                ].texture
                        }),
                      reciprocalPhysics.behavior == .forceField,
                      presentationMaterials.contains(where: {
                          $0.texture
                              == connectedRoom.faces[
                                  reciprocal.faceIndex
                              ].texture
                              && $0.waterProcedural != nil
                      })
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training gallery barrier"
                    )
                }
                portalRenderingStates.append(
                    barrierRoom.portals[portalIndex].flags
                        & rendersFaces != 0
                )
                portalRenderingStates.append(
                    reciprocal.flags & rendersFaces != 0
                )
            }
            guard Set(portalRenderingStates).count == 1 else {
                throw LevelValidationError.invalidDependency(
                    "Training gallery barrier"
                )
            }
        }
        if let chain = trainingRobotGuidebotChain {
            let clipNames = Set(voiceClips.map {
                $0.sourceName.lowercased()
            })
            let soundNames = Set(soundClips.flatMap {
                [$0.logicalName.lowercased(), $0.sourceName.lowercased()]
            })
            let releaseSoundIsResolved =
                chain.releaseSoundSourceName.map {
                    soundNames.contains($0.lowercased())
                } ?? true
            let ambientEngineSoundIsResolved =
                chain.ambientEngineSoundSourceName.map {
                    soundNames.contains($0.lowercased())
                } ?? true
            guard trainingGalleryBarrier != nil,
                  isNonempty(chain.deployedGuidebotMessage),
                  isNonempty(chain.deployedGuidebotVoiceSourceName),
                  chain.deployedGuidebotObjectType == 2,
                  chain.guidebot == .stockTraining,
                  clipNames.contains(
                    chain.deployedGuidebotVoiceSourceName.lowercased()
                  ),
                  releaseSoundIsResolved,
                  ambientEngineSoundIsResolved else {
                throw LevelValidationError.invalidDependency(
                    "Training robot Guidebot chain"
                )
            }
        }
        if let chain = trainingCameraMonitorChain {
            let clipNames = Set(voiceClips.map {
                $0.sourceName.lowercased()
            })
            let soundNames = Set(soundClips.map {
                $0.sourceName.lowercased()
            })
            let returnToShipIsValid = chain.returnToShip.map({
                returnChain in
                let killbotEntryIsValid =
                    returnChain.killbotEntry.map { entry in
                        guard entry.triggerRoomSourceIndex
                                == returnChain.barrierRoomSourceIndex,
                              returnChain.orderedPortalIndices.contains(
                                where: { portalIndex in
                                    guard let room = rooms.first(where: {
                                        $0.sourceIndex
                                            == entry.triggerRoomSourceIndex
                                    }),
                                    room.portals.indices.contains(
                                        portalIndex
                                    ) else {
                                        return false
                                    }
                                    return room.portals[portalIndex].faceIndex
                                        == entry.triggerFaceIndex
                                }
                              ),
                              Set(entry.orderedPortalIndices)
                                == Set(returnChain.orderedPortalIndices),
                              entry.orderedPortalIndices.count
                                == returnChain.orderedPortalIndices.count,
                              triggers.contains(where: {
                                  $0.name == entry.triggerName
                                      && $0.roomIndex
                                        == entry.triggerRoomSourceIndex
                                      && $0.faceIndex
                                        == entry.triggerFaceIndex
                                      && $0.flags == 8
                                      && $0.activator == 1
                              }),
                              entry.closedMarkerLightDistance.isFinite,
                              entry.closedMarkerLightDistance >= 0,
                              entry.followupDelay.isFinite,
                              entry.followupDelay > 0,
                              isNonempty(entry.entryMessage),
                              isNonempty(entry.followupMessage),
                              clipNames.contains(
                                entry.entryVoiceSourceName.lowercased()
                              ),
                              clipNames.contains(
                                entry.followupVoiceSourceName.lowercased()
                              ) else {
                            return false
                        }
                        return true
                    } ?? true
                return validTrainingGuidebotReturnBarrier(
                    returnChain,
                    in: self
                )
                    && killbotEntryIsValid
                    && clipNames.contains(
                        returnChain.successVoiceSourceName.lowercased()
                    )
                    && soundNames.contains(
                        returnChain.returnSoundSourceName.lowercased()
                    )
                    && (
                        returnChain.greetingSoundSourceName.map {
                            soundNames.contains($0.lowercased())
                        } ?? true
                    )
                    && isNonempty(returnChain.returnMessage)
                    && isNonempty(returnChain.arrivalMessage)
                    && isNonempty(returnChain.successMessage)
            }) ?? true
            guard trainingRobotGuidebotChain != nil,
                  chain.pickupObjectHandle
                    != chain.securityCameraObjectHandle,
                  chain.pickupCollisionRadius.isFinite,
                  chain.pickupCollisionRadius > 0,
                  chain.popupDuration.isFinite,
                  chain.popupDuration > 0,
                  chain.popupZoom.isFinite,
                  chain.popupZoom > 0,
                  chain.cameraGunpointIndex >= 0,
                  isFinite(chain.cameraLocalPosition),
                  abs(
                    levelDot(
                        chain.cameraLocalForward,
                        chain.cameraLocalForward
                    ) - 1
                  ) < 0.000_1,
                  chain.completionTimerDuration.isFinite,
                  chain.completionTimerDuration > 0,
                  isNonempty(chain.pickupMessage),
                  isNonempty(chain.useMessage),
                  let pickup = objects.first(where: {
                      $0.handle == chain.pickupObjectHandle
                  }),
                  pickup.type == 7,
                  pickup.storedID == 91,
                  pickup.definition?.sourceName == "Camera Monitor",
                  pickup.instanceName == "CameraMonitor",
                  pickup.flags == 4_096,
                  let camera = objects.first(where: {
                      $0.handle == chain.securityCameraObjectHandle
                  }),
                  camera.type == 2,
                  camera.storedID == 114,
                  camera.definition?.sourceName == "new wall cam",
                  camera.instanceName == "SecurityCamera",
                  camera.flags == 5_120,
                  clipNames.contains(
                    chain.pickupVoiceSourceName.lowercased()
                  ),
                  clipNames.contains(
                    chain.useVoiceSourceName.lowercased()
                  ),
                  soundNames.contains(
                    chain.pickupSoundSourceName.lowercased()
                  ),
                  returnToShipIsValid,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.pickupObjectHandle
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training Camera Monitor chain"
                )
            }
        }
        if let chain = trainingInvulnerabilityPickupChain {
            let presentation = objectPresentations.first {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
            let model = presentation.flatMap { presentation in
                models.first {
                    $0.source == presentation.primaryModel
                }
            }
            let reachedSoundNames = Set(soundClips.map(\.sourceName))
            guard chain.pickupObjectHandle == 2_076,
                chain.pickupRoomSourceIndex == 12,
                chain.pickupObjectFlags == 5_120,
                chain.pickupCollisionRadius.isFinite,
                chain.pickupCollisionRadius > 0,
                chain.duration == 30,
                chain.activatedMessage == "Invulnerability On",
                chain.expiredMessage == "Invulnerability Off",
                chain.pickupSoundSourceName == "Power03.wav",
                chain.activatedSoundSourceName == "Invon.wav",
                chain.expiredSoundSourceName == "Invoff.wav",
                let pickup = objects.first(where: {
                    $0.handle == chain.pickupObjectHandle
                }),
                pickup.type == 7,
                pickup.storedID == 3,
                pickup.definition
                    == .init(
                        storedIndex: 3,
                        sourceName: "Invulnerability"
                    ),
                pickup.instanceName == "InvulnPowerup2",
                pickup.flags == chain.pickupObjectFlags,
                pickup.location == .room(chain.pickupRoomSourceIndex),
                model?.collisionRadius == chain.pickupCollisionRadius,
                reachedSoundNames.contains(
                    chain.pickupSoundSourceName
                ),
                reachedSoundNames.contains(
                    chain.activatedSoundSourceName
                ),
                reachedSoundNames.contains(
                    chain.expiredSoundSourceName
                )
            else {
                throw LevelValidationError.invalidDependency(
                    "Training InvulnPowerup2 pickup chain"
                )
            }
        }
        if let chain = trainingCloakPickupChain {
            let presentation = objectPresentations.first {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
            let model = presentation.flatMap { presentation in
                models.first { $0.source == presentation.primaryModel }
            }
            let mediumModel = presentation?.mediumModel.flatMap {
                source in models.first { $0.source == source }
            }
            let lowModel = presentation?.lowModel.flatMap {
                source in models.first { $0.source == source }
            }
            let reachedSoundNames = Set(soundClips.map(\.sourceName))
            guard trainingInvulnerabilityPickupChain != nil,
                chain.pickupObjectHandle == 2_073,
                chain.pickupRoomSourceIndex == 11,
                chain.pickupObjectFlags == 5_120,
                chain.pickupCollisionRadius.isFinite,
                chain.pickupCollisionRadius > 0,
                chain.fadeDuration == 1,
                chain.cloakDuration == 30,
                chain.activatedMessage == "Cloak On",
                chain.expiredMessage == "Cloak Off",
                chain.pickupSoundSourceName == "Power03.wav",
                chain.activatedSoundSourceName == "ShpCloakOn.wav",
                chain.expiredSoundSourceName == "ShpCloakOffBeep.wav",
                let pickup = objects.first(where: {
                    $0.handle == chain.pickupObjectHandle
                }),
                pickup.type == 7,
                pickup.storedID == 4,
                pickup.definition
                    == .init(storedIndex: 4, sourceName: "Cloak"),
                pickup.instanceName == "CloakPowerup2",
                pickup.flags == chain.pickupObjectFlags,
                pickup.location == .room(chain.pickupRoomSourceIndex),
                presentation?.primaryModel.sourceName == "cloak.OOF",
                presentation?.mediumModel?.sourceName
                    == "CloakMed.OOF",
                presentation?.lowModel?.sourceName
                    == "CloakLow.OOF",
                presentation?.dyingModel == nil,
                presentation?.mediumDistance == 35,
                presentation?.lowDistance == 50,
                model?.sourceArchive == "d3.hog",
                model?.sourceSHA256
                    == "ccce90c9dbc266c0a22ab00339689059888719b212116191049ef4396ebc5baa",
                mediumModel?.sourceArchive == "d3.hog",
                mediumModel?.sourceSHA256
                    == "7b6e66b1ad23328b43dc007de7cb2b8806397f69bab95647e350554f479e0c6b",
                lowModel?.sourceArchive == "d3.hog",
                lowModel?.sourceSHA256
                    == "38754663d76df10a7d6d41e241cfe2fc08b9f7fb99addb41cb5ed1fc205f119f",
                model?.collisionRadius == chain.pickupCollisionRadius,
                reachedSoundNames.contains(chain.pickupSoundSourceName),
                reachedSoundNames.contains(chain.activatedSoundSourceName),
                reachedSoundNames.contains(chain.expiredSoundSourceName)
            else {
                throw LevelValidationError.invalidDependency(
                    "Training CloakPowerup2 pickup chain"
                )
            }
        }
        if let chain = trainingLastRoomChain {
            let room = rooms.first {
                $0.sourceIndex == chain.barrierRoomSourceIndex
            }
            let marker = objects.first {
                $0.handle == chain.markerLightObjectHandle
            }
            guard trainingCloakPickupChain != nil,
                chain.barrierRoomSourceIndex == 44,
                chain.orderedPortalIndices == [1, 0],
                chain.markerLightObjectHandle == 4_117,
                chain.openMarkerLightDistance == 50,
                chain.timerDuration == 2,
                chain.completionMessages == [
                    "Excellent!",
                    "Now proceed through the doorway that just opened to begin the last stage of your training.",
                ],
                chain.completionVoiceSourceName == "proceed5.osf",
                let room,
                chain.orderedPortalIndices.allSatisfy(
                    room.portals.indices.contains
                ),
                marker?.type == 11,
                marker?.storedID == 205,
                marker?.definition == .init(
                    storedIndex: 205,
                    sourceName: "Blinking Red Light-DM"
                ),
                marker?.instanceName == "FlashLight-4",
                marker?.flags == 4_096,
                marker?.location
                    == .room(chain.barrierRoomSourceIndex),
                chain.markerLightPresentation == .init(
                    primaryColor: .init(x: 1, y: 0.25, z: 0),
                    secondaryColor: .zero,
                    timeInterval: 0.5,
                    flickerDistance: 0.2,
                    directionalDot: 0,
                    flags: 4,
                    timebits: .max,
                    angle: 0,
                    lightingRenderType: 2
                ),
                chain.orderedPortalIndices.allSatisfy({ portalIndex in
                    let portal = room.portals[portalIndex]
                    guard portal.flags & 1 != 0,
                        let connectedRoom = rooms.first(where: {
                            $0.sourceIndex == portal.connectedRoom
                        }),
                        connectedRoom.portals.indices.contains(
                            portal.connectedPortal
                        )
                    else {
                        return false
                    }
                    let reciprocal =
                        connectedRoom.portals[portal.connectedPortal]
                    return reciprocal.connectedRoom == room.sourceIndex
                        && reciprocal.connectedPortal == portalIndex
                        && reciprocal.flags & 1 != 0
                }),
                voiceClips.contains(where: {
                    $0.sourceName.caseInsensitiveCompare(
                        chain.completionVoiceSourceName
                    ) == .orderedSame
                })
            else {
                throw LevelValidationError.invalidDependency(
                    "Training Script 034 / 049 last-room chain"
                )
            }
        }
        if let chain = trainingFinalRoomEntryChain {
            let trigger = triggers.first {
                $0.name == chain.triggerName
            }
            let triggerRoom = rooms.first {
                $0.sourceIndex == chain.triggerRoomSourceIndex
            }
            let barrierPortals = trainingLastRoomChain.flatMap { lastRoom in
                rooms.first {
                    $0.sourceIndex == lastRoom.barrierRoomSourceIndex
                }.map { room in
                    lastRoom.orderedPortalIndices.map {
                        room.portals[$0]
                    }
                }
            }
            let voice = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare(
                    chain.voiceSourceName
                ) == .orderedSame
            }
            guard trainingLastRoomChain != nil,
                chain.triggerName == "Portal4",
                chain.triggerRoomSourceIndex == 44,
                chain.triggerFaceIndex == 1,
                chain.successMessage == "Excellent!",
                chain.instructionMessage
                    == "Now for your final and most difficult task. Locate and destroy the last 5 robots.",
                chain.voiceSourceName == "intro7.osf",
                trigger?.roomIndex == chain.triggerRoomSourceIndex,
                trigger?.faceIndex == chain.triggerFaceIndex,
                trigger?.flags == 8,
                trigger?.activator == 1,
                triggerRoom?.faces.indices.contains(
                    chain.triggerFaceIndex
                ) == true,
                triggerRoom?.faces[chain.triggerFaceIndex].portalIndex
                    == 1,
                barrierPortals?.count == 2,
                barrierPortals?[0].connectedRoom == 45,
                barrierPortals?[0].connectedPortal == 0,
                barrierPortals?[1].connectedRoom == 41,
                barrierPortals?[1].connectedPortal == 3,
                voice?.sourceEntryIndex == 16,
                voice?.sourceArchive == "missions/training.mn3",
                voice?.sourceSHA256
                    == "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
            else {
                throw LevelValidationError.invalidDependency(
                    "Training Script 050 final-room entry"
                )
            }
        }
        if trainingFinalBotsCompletionChain != nil {
            try validateStockTrainingFinalBotsCompletionPackage(
                chain: trainingFinalBotsCompletionChain,
                done: voiceClips.first {
                    $0.sourceName.caseInsensitiveCompare("done.osf")
                        == .orderedSame
                },
                level: self,
                requiresExactVoice: false
            )
        }
        if trainingFinalGoalChain != nil {
            try validateStockTrainingFinalGoalPackage(
                chain: trainingFinalGoalChain,
                level: self
            )
        }
        var voiceNames = Set<String>()
        for clip in voiceClips {
            let voiceSource = SourceResource(
                storedIndex: clip.sourceEntryIndex,
                sourceName: clip.sourceName
            )
            guard D3SourceIdentity.isValidSourceResource(
                    voiceSource,
                    category: "voice"
                  ),
                  voiceNames.insert(clip.sourceName.lowercased()).inserted,
                  (4_096...192_000).contains(clip.sampleRate),
                  (1...2).contains(clip.channelCount),
                  clip.frameCount > 0,
                  canonicalPCM16ByteCount(
                    frameCount: clip.frameCount,
                    channelCount: clip.channelCount
                  ) == clip.pcm16LittleEndian.count,
                  isSHA256(clip.pcmSHA256),
                  canonicalSHA256(clip.pcm16LittleEndian)
                    == clip.pcmSHA256,
                  isSafeRelativePath(clip.sourceArchive),
                  source.profileFiles.contains(where: {
                      $0.relativePath == clip.sourceArchive
                  }),
                  isSHA256(clip.sourceSHA256),
                  dependencyManifest.current.contains(where: {
                      $0.category == "voice" && $0.source == voiceSource
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Canonical voice clip"
                )
            }
        }
        var soundNames = Set<String>()
        for clip in soundClips {
            let soundSource = SourceResource(
                storedIndex: clip.sourceEntryIndex,
                sourceName: clip.sourceName
            )
            guard D3SourceIdentity.isValidSourceResource(
                    soundSource,
                    category: "sound"
                  ),
                  soundNames.insert(clip.sourceName.lowercased()).inserted,
                  isNonempty(clip.logicalName),
                  (4_096...192_000).contains(clip.sampleRate),
                  (1...2).contains(clip.channelCount),
                  clip.frameCount > 0,
                  canonicalPCM16ByteCount(
                    frameCount: clip.frameCount,
                    channelCount: clip.channelCount
                  ) == clip.pcm16LittleEndian.count,
                  isSHA256(clip.pcmSHA256),
                  canonicalSHA256(clip.pcm16LittleEndian)
                    == clip.pcmSHA256,
                  isSafeRelativePath(clip.sourceArchive),
                  source.profileFiles.contains(where: {
                      $0.relativePath == clip.sourceArchive
                  }),
                  isSHA256(clip.sourceSHA256),
                  clip.importVolume.isFinite,
                  clip.importVolume >= 0,
                  dependencyManifest.current.contains(where: {
                      $0.category == "sound" && $0.source == soundSource
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Canonical sound clip"
                )
            }
            if clip.logicalName.caseInsensitiveCompare("Headlight1")
                == .orderedSame
                || clip.sourceName.caseInsensitiveCompare("Headlight.wav")
                    == .orderedSame
            {
                guard clip.logicalName == "Headlight1",
                      clip.sourceName == "Headlight.wav",
                      clip.sourceEntryIndex == 1_407,
                      clip.sampleRate == 22_050,
                      clip.channelCount == 1,
                      clip.frameCount == 10_623,
                      clip.pcm16LittleEndian.count == 21_246,
                      clip.pcmSHA256
                        == "7886b286bf1897c59c04bc5b80460d975ee5979ba21dae8e8f3596c5f0b23417",
                      clip.sourceArchive == "d3.hog",
                      clip.sourceSHA256
                        == "cc05bbed03cf33ef705613d5a237d5c1879c83df49dc03bca01960cf5a20384a",
                      clip.importVolume == 1
                else {
                    throw LevelValidationError.invalidDependency(
                        "Headlight1 canonical sound binding"
                    )
                }
            }
        }
        let hasStockTrainingSource =
            source.archiveSHA256
                == "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54"
            && source.levelSHA256
                == "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
        if enforceStockSourceInvariants,
           hasStockTrainingSource,
           !allowImportStagingPresentation {
            let welcome = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("welcome.osf")
                    == .orderedSame
            }
            let return1 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("return1.osf")
                    == .orderedSame
            }
            let guidebotA = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebota.osf")
                    == .orderedSame
            }
            let guidebotB = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotb.osf")
                    == .orderedSame
            }
            let proceed5 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("proceed5.osf")
                    == .orderedSame
            }
            let guidebotC = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotc.osf")
                    == .orderedSame
            }
            let guidebotD = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotd.osf")
                    == .orderedSame
            }
            let proceed6 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("proceed6.osf")
                    == .orderedSame
            }
            let intro6 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("intro6.osf")
                    == .orderedSame
            }
            let guidebotF = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotf.osf")
                    == .orderedSame
            }
            let intro7 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("intro7.osf")
                    == .orderedSame
            }
            let done = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("done.osf")
                    == .orderedSame
            }
            guard missionKey == "descent3.mission.pilot-training",
                  levelKey == "descent3.level.training-mission",
                  welcome?.sourceEntryIndex == 38,
                  welcome?.sampleRate == 22_050,
                  welcome?.channelCount == 1,
                  welcome?.frameCount == 417_957,
                  welcome?.pcmSHA256
                    == "116eda34ab4af47c9a59e514af6ba111ef41e344fadeadb8120ad76728b81fe9",
                  welcome?.sourceArchive == "missions/training.mn3",
                  welcome?.sourceSHA256
                    == "35e31517adb824f3637b877d500e12625b99d1a7044a2ce743087505c88ece36",
                  return1?.sourceEntryIndex == 28,
                  return1?.sampleRate == 22_050,
                  return1?.channelCount == 1,
                  return1?.frameCount == 83_929,
                  return1?.pcmSHA256
                    == "95ffd4396b10462438ed10fb9ed9f7e5ff01a37ff1ad93481c989b047dae9dc3",
                  return1?.sourceArchive == "missions/training.mn3",
                  return1?.sourceSHA256
                    == "048067398846141f61a2d503f6ec582f0dbbc5f3bf3feead48047eab808e540f"
            else {
                throw LevelValidationError.invalidDependency(
                    "Training opening package"
                )
            }
            // The opening and return lesson streams of Scripts 003-015
            // (left1, return2, up1, return3, repeat, lright, udown,
            // proceed1, Intro1, and proceed2).
            let openingVoiceCount = 10
            // The dodge, maneuver, and follow-bot lesson streams of Scripts
            // 033-026 and 027 that the package holds.
            let dodgeVoiceCount = [
                "intro2.osf", "almost.osf", "proceed3.osf", "proceed4.osf",
                "intro3.osf", "pitch.osf", "bank.osf", "follow.osf",
                "intro4.osf", "kill1.osf",
            ].filter { name in
                voiceClips.contains {
                    $0.sourceName.caseInsensitiveCompare(name) == .orderedSame
                }
            }.count
            guard let barrier = trainingGalleryBarrier,
                  barrier.triggerName == "Portal2",
                  barrier.triggerRoomSourceIndex == 38,
                  barrier.triggerFaceIndex == 1,
                  barrier.barrierRoomSourceIndex == 38,
                  barrier.orderedPortalIndices == [1, 0],
                  barrier.markerLightObjectHandle == 6_163,
                  barrier.openMarkerLightDistance == 50,
                  barrier.successMessage == "Excellent!",
                  barrier.guidebotInstruction
                    == "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4.",
                  barrier.voiceSourceName == "guidebota.osf",
                  voiceClips.count == (
                    trainingFinalBotsCompletionChain != nil
                        ? 12
                            + openingVoiceCount
                        : trainingFinalRoomEntryChain != nil
                            ? 11
                                + openingVoiceCount
                        : (
                            trainingCameraMonitorChain == nil ? 5 : 10
                        )
                            + openingVoiceCount
                    )
                    + dodgeVoiceCount,
                  guidebotA?.sourceEntryIndex == 4,
                  guidebotA?.sampleRate == 22_050,
                  guidebotA?.channelCount == 1,
                  guidebotA?.frameCount == 354_793,
                  guidebotA?.pcmSHA256
                    == "c806147adb0ceb7c2bd8eac0853ba107da49012f5de8685f915d3e3a80f51b4f",
                  guidebotA?.sourceArchive == "missions/training.mn3",
                  guidebotA?.sourceSHA256
                    == "dde58be4bd488cc7a009068afd15ddb18f8cf64dd1ff44fd5a3f8ae816277cad"
            else {
                throw LevelValidationError.invalidDependency(
                    "Training gallery package"
                )
            }
            try validateStockTrainingRobotGuidebotPackage(
                chain: trainingRobotGuidebotChain,
                guidebotB: guidebotB,
                proceed5: proceed5,
                releaseSound: soundClips.first {
                    $0.logicalName == "GBExpulsionA"
                },
                ambientEngineSound: soundClips.first {
                    $0.logicalName == "GBotEngineB1"
                }
            )
            try validateStockTrainingRobotGuidebotPresentation(
                chain: trainingRobotGuidebotChain!,
                modelSources: models.map(\.source),
                objects: objects,
                objectPresentations: objectPresentations
            )
            if trainingCameraMonitorChain != nil {
                try validateStockTrainingCameraMonitorPackage(
                    chain: trainingCameraMonitorChain,
                    guidebotC: guidebotC,
                    guidebotD: guidebotD,
                    proceed6: proceed6,
                    intro6: intro6,
                    guidebotF: guidebotF,
                    pickupSound: soundClips.first {
                        $0.logicalName == "PupC1"
                    },
                    returnSound: soundClips.first {
                        $0.logicalName == "GBotAcceptOrder1"
                    },
                    greetingSound: soundClips.first {
                        $0.logicalName == "GBotGreetB1"
                    },
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingFinalRoomEntryChain != nil {
                try validateStockTrainingFinalRoomEntryPackage(
                    chain: trainingFinalRoomEntryChain,
                    intro7: intro7
                )
            }
            if trainingFinalBotsCompletionChain != nil {
                guard let room = rooms.first(where: {
                    $0.sourceIndex == 16
                }),
                      room.portals.count == 2,
                      room.portals[0].faceIndex == 0,
                      room.portals[0].connectedRoom == 45,
                      room.portals[0].connectedPortal == 9,
                      room.portals[1].faceIndex == 1,
                      room.portals[1].connectedRoom == 17,
                      room.portals[1].connectedPortal == 1,
                      let marker = objects.first(where: {
                          $0.handle == 4_118
                      }),
                      marker.position == .init(
                          x: 2_061.565_4,
                          y: -745.747_4,
                          z: 3_661.294_2
                      )
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Scripts 035/056 stock topology"
                    )
                }
                try validateStockTrainingFinalBotsCompletionPackage(
                    chain: trainingFinalBotsCompletionChain,
                    done: done,
                    level: self
                )
            }
            if trainingFinalGoalChain != nil {
                guard let room = rooms.first(where: {
                    $0.sourceIndex == 17
                }),
                      let goal = objects.first(where: {
                          $0.handle == 6_180
                      }),
                      goal.definition?.referenceRuntimeIndex == 68,
                      goal.containsType == 255,
                      goal.containsID == 0,
                      goal.containsCount == 0,
                      goal.position == .init(
                          x: 2_061.773_4,
                          y: -756.230_65,
                          z: 3_681.408_2
                      ),
                      goal.orientation == .init(
                          right: .init(x: -1, y: 0, z: 0),
                          up: .init(x: 0, y: 1, z: 0),
                          forward: .init(x: 0, y: 0, z: -1)
                      ),
                      room.portals.count == 2,
                      room.portals[0].connectedRoom == 18,
                      room.portals[0].connectedPortal == 0,
                      room.portals[1].connectedRoom == 16,
                      room.portals[1].connectedPortal == 1
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 057 stock topology"
                    )
                }
                try validateStockTrainingFinalGoalPackage(
                    chain: trainingFinalGoalChain,
                    level: self
                )
            }
            if trainingInvulnerabilityPickupChain != nil {
                let pickupSound = soundClips.first {
                    $0.logicalName == "Powerup pickup"
                }
                let activatedSound = soundClips.first {
                    $0.logicalName == "Invulnerability on"
                }
                let expiredSound = soundClips.first {
                    $0.logicalName == "Invulnerability off"
                }
                guard pickupSound?.sourceName == "Power03.wav",
                    activatedSound?.sourceName == "Invon.wav",
                    activatedSound?.importVolume == 0.5,
                    expiredSound?.sourceName == "Invoff.wav",
                    expiredSound?.importVolume == 0.5
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training InvulnPowerup2 package"
                    )
                }
            }
            if trainingCloakPickupChain != nil {
                try validateStockTrainingCloakSoundPackage(
                    soundClips
                )
            }
        }
        var retiredSlots = Set<Int>()
        for handle in retiredObjectHandles {
            let slot = Int(handle & 0x7ff)
            guard D3SourceIdentity.isValidHandle(handle),
                  !handles.contains(handle),
                  !objectSlots.contains(slot),
                  retiredSlots.insert(slot).inserted else {
                throw LevelValidationError.invalidObjectHandle(handle)
            }
        }
        for path in paths {
            guard path.nodes.count <= 100 else {
                throw LevelValidationError.invalidCount("path nodes")
            }
            for node in path.nodes {
                try validateLocation(node.location, rooms: roomMap)
            }
        }
        for goal in goals {
            guard goal.items.count <= 12 else {
                throw LevelValidationError.invalidCount("goal items")
            }
            for item in goal.items {
                guard item.type == 2,
                      let objectHandle = item.objectHandle,
                      objectHandle == item.sourceHandle,
                      handles.contains(objectHandle) else {
                    throw LevelValidationError.invalidGoalObject(item.sourceHandle)
                }
            }
        }
        guard triggers.count <= 100 else {
            throw LevelValidationError.invalidCount("triggers")
        }
        for trigger in triggers {
            guard let room = roomMap[trigger.roomIndex],
                  room.faces.indices.contains(trigger.faceIndex),
                  room.faces[trigger.faceIndex].flags & 0x0010 != 0 else {
                throw LevelValidationError.invalidTrigger(trigger.name)
            }
        }

        var dependencyNames = Set<String>()
        var dependencyStoredIndices = Set<String>()
        var availableDependencies = Set<DependencyIdentity>()
        for dependency in dependencyManifest.current {
            guard isNonempty(dependency.category),
                  isNonempty(dependency.source.sourceName),
                  isNonempty(dependency.state),
                  isNonempty(dependency.provenance) else {
                throw LevelValidationError.invalidDependency(dependency.category)
            }
            try validateSourceResource(dependency.source, category: dependency.category)
            let category = dependency.category.lowercased()
            let nameIdentity = "\(category):\(dependency.source.sourceName.lowercased())"
            let storedIdentity = "\(category):\(dependency.source.storedIndex)"
            guard dependencyNames.insert(nameIdentity).inserted else {
                throw LevelValidationError.duplicateDependency
            }
            if !allowsDuplicateDependencyStoredIndex(
                category: dependency.category,
                sourceName: dependency.source.sourceName
            ) && !dependencyStoredIndices.insert(storedIdentity).inserted {
                throw LevelValidationError.duplicateDependency
            }
            availableDependencies.insert(.init(category: dependency.category, source: dependency.source))
        }
        if let baseline = dependencyManifest.historicalEagerBaseline {
            guard baseline.textureCount >= 0,
                  baseline.soundCount >= 0,
                  baseline.modelCount >= 0,
                  baseline.lightmapInfoCount >= 0 else {
                throw LevelValidationError.invalidDependency("historical eager baseline")
            }
        }
        try validateDependencyClosure(availableDependencies)
        try validatePlayerPresentationClosure(
            allowIncomplete: allowImportStagingPresentation
        )

        guard !sourceChunks.isEmpty else {
            throw LevelValidationError.invalidSourceChunk("missing")
        }
        var chunkNames = Set<String>()
        for chunk in sourceChunks {
            guard chunk.name.utf8.count == 4,
                  chunk.name.utf8.allSatisfy({ $0 >= 0x20 && $0 <= 0x7e }),
                  chunk.byteCount >= 0,
                  isSHA256(chunk.sha256),
                  isNonempty(chunk.disposition),
                  chunkNames.insert(chunk.name.lowercased()).inserted else {
                throw LevelValidationError.invalidSourceChunk(chunk.name)
            }
        }
        try validateObjectTables()
        // Script data last: it names content the checks above cover.
        try validateScripting()
        try validateGameModules()
        if let boaTables, !boaTables.isValid(for: self) {
            throw LevelValidationError.invalidCount("boaTables")
        }
    }

    private static func defaultSurfacePhysics(for rooms: [LevelRoom]) -> [SurfacePhysicsEntry] {
        let textures = Set(rooms.flatMap { $0.faces.map(\.texture) })
        return textures.sorted(by: sourceResourceIsOrdered).map {
            .init(texture: $0, behavior: .blocking)
        }
    }

}
private func validateIndoorNavigation(
    _ graph: IndoorNavigationGraph?,
    rooms: [Int: LevelRoom]
) throws {
    guard let graph else { return }
    guard let highestRoomSourceIndex = rooms.keys.max(),
          graph.sourceHighestRoomPlusTerrainRegions
            == highestRoomSourceIndex + 8,
          Set(graph.rooms.map(\.sourceIndex)).count == graph.rooms.count
    else {
        throw LevelValidationError.invalidDependency(
            "Indoor navigation graph"
        )
    }
    let navigationByRoom = Dictionary(
        uniqueKeysWithValues: graph.rooms.map { ($0.sourceIndex, $0) }
    )
    for navigationRoom in graph.rooms {
        if navigationRoom.sourceIndex > highestRoomSourceIndex {
            guard navigationRoom.nodes.isEmpty else {
                throw LevelValidationError.invalidDependency(
                    "Indoor navigation graph"
                )
            }
            continue
        }
        guard let room = rooms[navigationRoom.sourceIndex],
              room.flags & 0x0000_0004 == 0,
              navigationRoom.nodes.count <= 127
        else {
            throw LevelValidationError.invalidDependency(
                "Indoor navigation graph"
            )
        }
        for (nodeIndex, node) in navigationRoom.nodes.enumerated() {
            guard isFinite(node.position), node.edges.count <= 127 else {
                throw LevelValidationError.invalidDependency(
                    "Indoor navigation graph"
                )
            }
            for edge in node.edges {
                guard edge.cost >= 1,
                      edge.maximumRadius.isFinite,
                      edge.maximumRadius >= 0,
                      let destinationRoom =
                        navigationByRoom[
                            edge.destinationRoomSourceIndex
                        ],
                      destinationRoom.nodes.indices.contains(
                          edge.destinationNodeIndex
                      ),
                      destinationRoom.nodes[
                          edge.destinationNodeIndex
                      ].edges.contains(where: {
                          $0.destinationRoomSourceIndex
                                == navigationRoom.sourceIndex
                              && $0.destinationNodeIndex == nodeIndex
                      })
                else {
                    throw LevelValidationError.invalidDependency(
                        "Indoor navigation graph"
                    )
                }
            }
        }
        for portal in room.portals where portal.boundaryNodeIndex >= 0 {
            guard navigationRoom.nodes.indices.contains(
                portal.boundaryNodeIndex
            ) else {
                throw LevelValidationError.invalidDependency(
                    "Indoor navigation graph"
                )
            }
        }
    }
}

enum LevelValidationError: Error, Equatable {
    case invalidIdentity
    case duplicateRoom
    case invalidFace(room: Int, face: Int)
    case degenerateFace(room: Int, face: Int)
    case nonplanarFace(room: Int, face: Int)
    case concaveFace(room: Int, face: Int)
    case invalidFacePortal(room: Int, face: Int)
    case invalidMirrorFace(room: Int)
    case invalidSpecialFace(room: Int, face: Int)
    case invalidPortal(room: Int, portal: Int)
    case invalidCombinedPortal(room: Int, portal: Int)
    case nonreciprocalPortal(room: Int, portal: Int)
    case mismatchedPortalGeometry(room: Int, portal: Int)
    case invalidLightmapReference(Int)
    case invalidSurfacePhysics
    case invalidLightmapPage(Int)
    case invalidLightmapInfo(Int)
    case invalidVolumeLights(room: Int)
    case invalidTerrain
    case invalidObjectHandle(UInt32)
    case invalidObjectType(UInt8)
    case invalidObjectStoredID(handle: UInt32, storedID: Int)
    case invalidPlayerID(handle: UInt32, playerID: Int)
    case duplicatePlayerID(handle: UInt32, playerID: Int)
    case invalidObjectDefinition(UInt32)
    case invalidObjectPosition(UInt32)
    case invalidObjectOrientation(UInt32)
    case invalidObjectPresentation(UInt32)
    case invalidModel(String)
    case invalidLocation
    case invalidGoalObject(UInt32)
    case invalidTrigger(String)
    case invalidDependency(String)
    case invalidSourceResource(category: String, storedIndex: Int)
    case duplicateDependency
    case invalidSourceChunk(String)
    case invalidCount(String)
    case invalidScripting(String)
    case invalidObjectTables(String)
}

struct DependencyIdentity: Hashable {
    let category: String
    let source: SourceResource
}

private func reciprocalPortalGeometryMatches(
    room: LevelRoom,
    portal: LevelPortal,
    connectedRoom: LevelRoom,
    connectedPortal: LevelPortal
) -> Bool {
    let face = room.faces[portal.faceIndex]
    let connectedFace = connectedRoom.faces[connectedPortal.faceIndex]
    guard face.corners.count == connectedFace.corners.count else { return false }
    let points = face.corners.map { room.vertices[$0.vertexIndex] }
    let connectedPoints = connectedFace.corners.map {
        connectedRoom.vertices[$0.vertexIndex]
    }
    for start in connectedPoints.indices where pointsMatch(points[0], connectedPoints[start]) {
        if points.indices.dropFirst().allSatisfy({ offset in
            pointsMatch(
                points[offset],
                connectedPoints[(start - offset + connectedPoints.count) % connectedPoints.count]
            )
        }) {
            return true
        }
    }
    return false
}

private func pointsMatch(_ lhs: Vector3, _ rhs: Vector3) -> Bool {
    let x = lhs.x - rhs.x
    let y = lhs.y - rhs.y
    let z = lhs.z - rhs.z
    return x * x + y * y + z * z < 0.01
}

private func faceIsPlanar(
    room: LevelRoom,
    face: LevelFace,
    normal: Vector3
) -> Bool {
    guard face.corners.count > 3 else { return true }
    let distances = face.corners.map {
        levelDot(room.vertices[$0.vertexIndex], normal)
    }
    let average = distances.reduce(0, +) / Float(distances.count)
    return distances.allSatisfy { abs($0 - average) <= 0.1 }
}

private func faceIsConcave(
    room: LevelRoom,
    face: LevelFace,
    normal: Vector3
) -> Bool {
    let points = face.corners.map { room.vertices[$0.vertexIndex] }
    let (i, j) = faceProjectionAxes(normal)
    var previousEdge = levelSubtract(points[0], points[points.count - 1])
    for index in points.indices {
        let current = points[index]
        let next = points[(index + 1) % points.count]
        let nextEdge = levelSubtract(next, current)
        let previousI = component(previousEdge, at: i)
        let previousJ = component(previousEdge, at: j)
        let nextI = component(nextEdge, at: i)
        let nextJ = component(nextEdge, at: j)
        let denominator = sqrt(previousI * previousI + previousJ * previousJ)
            * sqrt(nextI * nextI + nextJ * nextJ)
        guard denominator > 0 else { return true }
        let turn = (-previousJ * nextI + previousI * nextJ) / denominator
        if turn > 0.05 { return true }
        previousEdge = nextEdge
    }
    return false
}

private func faceProjectionAxes(_ normal: Vector3) -> (Int, Int) {
    if abs(normal.x) > abs(normal.y) {
        if abs(normal.x) > abs(normal.z) {
            return normal.x > 0 ? (2, 1) : (1, 2)
        }
        return normal.z > 0 ? (1, 0) : (0, 1)
    }
    if abs(normal.y) > abs(normal.z) {
        return normal.y > 0 ? (0, 2) : (2, 0)
    }
    return normal.z > 0 ? (1, 0) : (0, 1)
}

private func component(_ vector: Vector3, at index: Int) -> Float {
    switch index {
    case 0: vector.x
    case 1: vector.y
    default: vector.z
    }
}

func levelSubtract(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func validateSourceResource(_ source: SourceResource, category: String) throws {
    guard D3SourceIdentity.isValidSourceResource(source, category: category) else {
        throw LevelValidationError.invalidSourceResource(
            category: category,
            storedIndex: source.storedIndex
        )
    }
}

func allowsDuplicateDependencyStoredIndex(
    category: String,
    sourceName: String
) -> Bool {
    category.caseInsensitiveCompare("texture") == .orderedSame
        && sourceName.lowercased().contains(".oaf frame ")
}

private func validateSurfacePhysics(
    _ entries: [SurfacePhysicsEntry],
    rooms: [LevelRoom],
    allowIncomplete: Bool
) throws {
    if allowIncomplete && entries.isEmpty {
        return
    }
    let residentTextures = Set(rooms.flatMap { $0.faces.map(\.texture) })
    let entryTextures = entries.map(\.texture)
    guard entries.count == residentTextures.count,
          Set(entryTextures).count == entries.count,
          Set(entryTextures) == residentTextures,
          entries.map(\.texture) == entryTextures.sorted(by: sourceResourceIsOrdered) else {
        throw LevelValidationError.invalidSurfacePhysics
    }
    for entry in entries {
        try validateSourceResource(entry.texture, category: "texture")
    }
}

func sourceResourceIsOrdered(_ lhs: SourceResource, _ rhs: SourceResource) -> Bool {
    if lhs.storedIndex != rhs.storedIndex {
        return lhs.storedIndex < rhs.storedIndex
    }
    if lhs.sourceName != rhs.sourceName {
        return lhs.sourceName < rhs.sourceName
    }
    return (lhs.referenceRuntimeIndex ?? -1) < (rhs.referenceRuntimeIndex ?? -1)
}

private func validateSource(_ source: LevelSource) throws {
    guard isNonempty(source.profileIdentifier),
          !source.profileFiles.isEmpty,
          isSHA256(source.archiveSHA256),
          isSHA256(source.levelSHA256) else {
        throw LevelValidationError.invalidIdentity
    }
    var profilePaths = Set<String>()
    for file in source.profileFiles {
        guard isSafeRelativePath(file.relativePath),
              file.byteCount >= 0,
              isSHA256(file.sha256),
              profilePaths.insert(file.relativePath.lowercased()).inserted else {
            throw LevelValidationError.invalidIdentity
        }
    }
    if source.archiveEntryName != nil
        || source.archiveEntryOffset != nil
        || source.archiveEntryByteCount != nil {
        guard let archiveEntryName = source.archiveEntryName,
              isNonempty(archiveEntryName),
              let archiveEntryOffset = source.archiveEntryOffset,
              archiveEntryOffset >= 0,
              let archiveEntryByteCount = source.archiveEntryByteCount,
              archiveEntryByteCount >= 0 else {
            throw LevelValidationError.invalidIdentity
        }
    }
    if let referenceChecksum = source.referenceChecksum {
        guard isLowercaseHex(referenceChecksum, count: 32),
              source.referenceChecksumBasis
                == "pinned-source-provenance-implied-by-exact-level-sha256" else {
            throw LevelValidationError.invalidIdentity
        }
    } else if source.referenceChecksumBasis != nil {
        throw LevelValidationError.invalidIdentity
    }
}

extension Level {
    /// This level with more sound clips and their dependency records. Every
    /// other field is kept, which the assembly steps that rebuild a level
    /// from its fields do not do.
    /// This level with an imported-texture dependency record for each
    /// texture that has none yet: the explosion frames of its weapons
    /// (manage/weaponpage.cpp, WeaponFire.cpp:3058).
    func appendingTextureDependencies(
        _ textures: [SourceResource],
        provenance: String
    ) -> Level {
        var level = self
        var current = dependencyManifest.current
        for texture in textures where !current.contains(where: {
            $0.category == "texture" && $0.source == texture
        }) {
            current.append(.init(
                category: "texture",
                source: texture,
                state: "presentation-payload-imported",
                provenance: provenance
            ))
        }
        level.dependencyManifest = .init(
            current: current,
            historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
        )
        return level
    }

    func appendingSoundClips(_ added: [CanonicalSoundClip]) -> Level {
        var level = self
        level.soundClips += added
        level.dependencyManifest = .init(
            current: dependencyManifest.current + added.map { clip in
                DependencyRecord(
                    category: "sound",
                    source: .init(
                        storedIndex: clip.sourceEntryIndex,
                        sourceName: clip.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "\(clip.sourceArchive) \(clip.sourceSHA256)"
                )
            },
            historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
        )
        return level
    }
}

extension Level {
    private func validateDependencyClosure(_ available: Set<DependencyIdentity>) throws {
        var required = Set<DependencyIdentity>()
        func require(_ category: String, _ source: SourceResource) {
            required.insert(.init(category: category, source: source))
        }

        for room in rooms {
            for face in room.faces { require("texture", face.texture) }
            if let door = room.door { require("door-definition", door.definition) }
        }
        for cell in terrain.textureCells { require("texture", cell.texture) }
        if let sky = terrain.sky {
            require("texture", sky.domeTexture)
            for satellite in sky.satellites { require("texture", satellite.texture) }
        }
        for object in objects {
            guard let definition = object.definition else { continue }
            require(object.type == 17 ? "door-definition" : "object-definition", definition)
        }
        for model in models {
            require("model", model.source)
        }
        for texture in referencedModelTextures(in: models) {
            require("texture", texture)
        }
        for index in lightmaps.pages.indices {
            require(
                "lightmap-page",
                .init(storedIndex: index, sourceName: "lightmap-page-\(index)")
            )
        }
        for index in lightmaps.infos.indices {
            require(
                "lightmap-info",
                .init(storedIndex: index, sourceName: "lightmap-info-\(index)")
            )
        }
        let missing = required.filter { !available.contains($0) }.sorted {
            ($0.category, $0.source.storedIndex, $0.source.sourceName)
                < ($1.category, $1.source.storedIndex, $1.source.sourceName)
        }
        if let dependency = missing.first {
            throw LevelValidationError.invalidDependency(
                "missing \(dependency.category):\(dependency.source.sourceName)"
            )
        }
    }
}

private func validateModels(
    _ models: [CanonicalModel],
    objectPresentations: [ObjectPresentationReference],
    materials: [PresentationMaterial],
    objects: [PlacedObject],
    source: LevelSource,
    dynamicallyPresentedModelNames: [String]
) throws {
    let acceptedSourcePaths = Set(source.profileFiles.map(\.relativePath))
    guard models.count <= 256,
          Set(models.map(\.source)).count == models.count,
          Set(objectPresentations.map(\.objectHandle)).count == objectPresentations.count else {
        throw LevelValidationError.invalidCount("models")
    }
    let materialSources = Set(materials.map(\.texture))
    var modelBySource: [SourceResource: CanonicalModel] = [:]
    for model in models {
        guard D3SourceIdentity.isValidSourceResource(model.source, category: "model"),
              model.collisionRadius.isFinite,
              model.collisionRadius > 0,
              isSafeRelativePath(model.sourceArchive),
              acceptedSourcePaths.contains(model.sourceArchive),
              isSHA256(model.sourceSHA256),
              !model.submodels.isEmpty,
              model.submodels.count <= 1_000 else {
            throw LevelValidationError.invalidModel("\(model.source.sourceName): identity")
        }
        let faceTextures = Set(model.submodels.flatMap { submodel in
            submodel.faces.compactMap { face -> SourceResource? in
                if case .texture(let texture) = face.material { return texture }
                return nil
            }
        })
        for texture in faceTextures {
            guard D3SourceIdentity.isValidSourceResource(texture, category: "texture"),
                  materialSources.contains(texture) else {
                throw LevelValidationError.invalidDependency(
                    "missing texture:\(texture.sourceName)"
                )
            }
        }
        let indices = Set(model.submodels.map(\.sourceIndex))
        guard indices == Set(model.submodels.indices),
              model.submodels.allSatisfy({ submodel in
                  submodel.radius.map { $0.isFinite && $0 >= 0 } ?? true
              })
        else {
            throw LevelValidationError.invalidModel("\(model.source.sourceName): submodel indices")
        }
        var transformedBounds: ModelBounds?
        var accumulatedOffsets = [Vector3?](repeating: nil, count: model.submodels.count)
        func resolvedOffset(_ index: Int, visiting: inout Set<Int>) throws -> Vector3 {
            if let resolved = accumulatedOffsets[index] { return resolved }
            guard visiting.insert(index).inserted else {
                throw LevelValidationError.invalidModel("\(model.source.sourceName): cyclic hierarchy")
            }
            let submodel = model.submodels[index]
            let parentOffset: Vector3
            if let parent = submodel.parentIndex {
                guard model.submodels.indices.contains(parent) else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): invalid parent")
                }
                parentOffset = try resolvedOffset(parent, visiting: &visiting)
            } else {
                parentOffset = .zero
            }
            visiting.remove(index)
            let resolved = adding(parentOffset, submodel.offset)
            accumulatedOffsets[index] = resolved
            return resolved
        }
        for submodel in model.submodels.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
            var visiting: Set<Int> = []
            let accumulatedOffset = try resolvedOffset(submodel.sourceIndex, visiting: &visiting)
            guard submodel.vertices.count <= 100_000,
                  submodel.faces.count <= 100_000 else {
                throw LevelValidationError.invalidModel("\(model.source.sourceName): geometry count")
            }
            for vertex in submodel.vertices {
                guard isFinite(vertex.position) else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): vertex position")
                }
                guard vertex.alpha.isFinite, (0...1).contains(vertex.alpha) else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): vertex alpha")
                }
                let transformed = adding(
                    accumulatedOffset,
                    vertex.position
                )
                transformedBounds = expanding(transformedBounds, toInclude: transformed)
            }
            for face in submodel.faces {
                // Hull collision keeps one edge bit per corner in a 32-bit
                // mask: check_sphere_to_face asserts nv <= 32
                // (findintersection.cpp:1600).
                guard isFinite(face.normal),
                      face.corners.count >= 3,
                      face.corners.count <= 32 else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): face")
                }
                for corner in face.corners {
                    guard submodel.vertices.indices.contains(corner.vertexIndex),
                          corner.u.isFinite, corner.v.isFinite else {
                        throw LevelValidationError.invalidModel("\(model.source.sourceName): face corner")
                    }
                }
            }
            switch submodel.presentation {
            case .glow(let color, let size):
                guard isFinite(color), size.isFinite, size > 0 else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): presentation")
                }
            case .rotate(let rate, let axis):
                let magnitudeSquared = levelDot(axis, axis)
                guard rate.isFinite,
                      rate > 0,
                      magnitudeSquared.isFinite,
                      abs(magnitudeSquared - 1) <= 0.000_1 else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): presentation")
                }
            case .turret(
                let
                    fieldOfView,
                let
                    rotationsPerSecond,
                let
                    thinkInterval,
                let
                    axis
            ):
                let magnitudeSquared = levelDot(axis, axis)
                guard fieldOfView.isFinite,
                    (0...0.5).contains(fieldOfView),
                    rotationsPerSecond.isFinite,
                    rotationsPerSecond > 0,
                    thinkInterval.isFinite,
                    (0...10).contains(thinkInterval),
                    magnitudeSquared.isFinite,
                    abs(magnitudeSquared - 1) <= 0.000_1
                else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): presentation")
                }
            case .standard, .custom, .facing:
                break
            }
        }
        guard let transformedBounds,
              approximatelyEqual(model.bounds.minimum, transformedBounds.minimum),
              approximatelyEqual(model.bounds.maximum, transformedBounds.maximum) else {
            throw LevelValidationError.invalidModel("\(model.source.sourceName): bounds")
        }
        modelBySource[model.source] = model
    }

    let objectHandles = Set(objects.map(\.handle))
    var referencedModels = Set<SourceResource>()
    for presentation in objectPresentations {
        guard objectHandles.contains(presentation.objectHandle) else {
            throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
        }
        let choices = [
            presentation.primaryModel,
            presentation.mediumModel,
            presentation.lowModel,
            presentation.dyingModel,
        ].compactMap { $0 }
        guard choices.allSatisfy({ modelBySource[$0] != nil }) else {
            throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
        }
        referencedModels.formUnion(choices)
        let hasMedium = presentation.mediumModel != nil
        let hasLow = presentation.lowModel != nil
        guard hasMedium == (presentation.mediumDistance != nil),
              hasLow == (presentation.lowDistance != nil) else {
            throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
        }
        if let medium = presentation.mediumDistance {
            guard medium.isFinite, medium > 0 else {
                throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
            }
        }
        if let low = presentation.lowDistance {
            guard low.isFinite,
                  low > (presentation.mediumDistance ?? 0) else {
                throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
            }
        }
    }
    for name in dynamicallyPresentedModelNames {
        if let source = models.first(where: {
            $0.source.sourceName.caseInsensitiveCompare(name)
                == .orderedSame
        })?.source {
            referencedModels.insert(source)
        }
    }
    guard referencedModels == Set(models.map(\.source)) else {
        throw LevelValidationError.invalidDependency("orphan model")
    }
}

func referencedModelTextures(in models: [CanonicalModel]) -> Set<SourceResource> {
    Set(models.flatMap { model in
        model.submodels.flatMap { submodel in
            submodel.faces.compactMap { face -> SourceResource? in
                if case .texture(let texture) = face.material { return texture }
                return nil
            }
        }
    })
}

private func adding(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private func expanding(_ bounds: ModelBounds?, toInclude point: Vector3) -> ModelBounds {
    guard let bounds else { return .init(minimum: point, maximum: point) }
    return .init(
        minimum: .init(
            x: min(bounds.minimum.x, point.x),
            y: min(bounds.minimum.y, point.y),
            z: min(bounds.minimum.z, point.z)
        ),
        maximum: .init(
            x: max(bounds.maximum.x, point.x),
            y: max(bounds.maximum.y, point.y),
            z: max(bounds.maximum.z, point.z)
        )
    )
}

func isFinite(_ value: Vector3) -> Bool {
    value.x.isFinite && value.y.isFinite && value.z.isFinite
}

private func approximatelyEqual(_ lhs: Vector3, _ rhs: Vector3) -> Bool {
    abs(lhs.x - rhs.x) <= 0.0001
        && abs(lhs.y - rhs.y) <= 0.0001
        && abs(lhs.z - rhs.z) <= 0.0001
}

private func validateLightmaps(_ lightmaps: LightmapCatalog) throws {
    guard lightmaps.pages.count <= 65_534 else {
        throw LevelValidationError.invalidCount("lightmap pages")
    }
    guard lightmaps.infos.count < 65_534 else {
        throw LevelValidationError.invalidCount("lightmap infos")
    }
    for (pageIndex, page) in lightmaps.pages.enumerated() {
        guard (1...128).contains(page.width),
              (1...128).contains(page.height),
              page.rgba8 == nil || page.rgba8?.count == page.width * page.height * 4 else {
            throw LevelValidationError.invalidLightmapPage(pageIndex)
        }
    }
    for (infoIndex, info) in lightmaps.infos.enumerated() {
        guard lightmaps.pages.indices.contains(info.pageIndex),
              info.width >= 2,
              info.height >= 2,
              info.x >= 0,
              info.y >= 0 else {
            throw LevelValidationError.invalidLightmapInfo(infoIndex)
        }
        let page = lightmaps.pages[info.pageIndex]
        guard info.x <= page.width,
              info.y <= page.height,
              info.width <= page.width - info.x,
              info.height <= page.height - info.y else {
            throw LevelValidationError.invalidLightmapInfo(infoIndex)
        }
    }
}

private func validatePresentation(
    materials: [PresentationMaterial],
    coronaAssets: [PresentationCoronaAsset],
    source: LevelSource
) throws {
    let acceptedSourcePaths = Set(source.profileFiles.map(\.relativePath))
    guard Set(materials.map(\.texture)).count == materials.count,
          Set(coronaAssets.map(\.source)).count == coronaAssets.count else {
        throw LevelValidationError.invalidCount("presentation materials")
    }
    for (index, asset) in coronaAssets.enumerated() {
        guard asset.source.storedIndex == index,
              D3SourceIdentity.isValidSourceResource(
                asset.source,
                category: "presentation-effect"
              ),
              asset.source.sourceName == asset.bitmapSourceName,
              !asset.bitmapSourceName.isEmpty,
              asset.bitmapSourceName.utf8.allSatisfy({ $0 < 0x80 }),
              (1...256).contains(asset.image.width),
              (1...256).contains(asset.image.height),
              asset.image.rgba8.count == asset.image.width * asset.image.height * 4,
              isSafeRelativePath(asset.sourceArchive),
              acceptedSourcePaths.contains(asset.sourceArchive),
              isSHA256(asset.sourceSHA256) else {
            throw LevelValidationError.invalidCount("presentation corona asset")
        }
    }
    for material in materials {
        guard D3SourceIdentity.isValidSourceResource(material.texture, category: "texture"),
              !material.bitmapSourceName.isEmpty,
              material.bitmapSourceName.utf8.allSatisfy({ $0 < 0x80 }),
              (1...256).contains(material.image.width),
              (1...256).contains(material.image.height),
              material.image.rgba8.count == material.image.width * material.image.height * 4,
              isSafeRelativePath(material.sourceArchive),
              acceptedSourcePaths.contains(material.sourceArchive),
              isSHA256(material.sourceSHA256) else {
            throw LevelValidationError.invalidCount("presentation material")
        }
        if case .additiveSourceAlpha = material.blend {
            guard material.lightmapBlend == .none else {
                throw LevelValidationError.invalidCount("presentation material")
            }
        }
        if let water = material.waterProcedural {
            guard material.image.width == 128,
                  material.image.height == 128,
                  water.lightingShift < 16,
                  water.dampingShift < 16,
                  water.elements.count <= 64,
                  water.evaluationIntervalSeconds.isFinite,
                  water.evaluationIntervalSeconds >= 0 else {
                throw LevelValidationError.invalidCount("water procedural")
            }
        }
        if let corona = material.lightCorona {
            guard coronaAssets.indices.contains(corona.assetIndex),
                  corona.tint.x.isFinite,
                  corona.tint.y.isFinite,
                  corona.tint.z.isFinite,
                  corona.tint.x >= 0,
                  corona.tint.y >= 0,
                  corona.tint.z >= 0,
                  corona.blend == .additiveSourceAlpha(opacity: 102) else {
                throw LevelValidationError.invalidCount("presentation light corona")
            }
        }
    }
}

private func isOrthonormal(_ matrix: Matrix3) -> Bool {
    let tolerance: Float = 0.001
    let right = matrix.right
    let up = matrix.up
    let forward = matrix.forward
    guard abs(levelDot(right, right) - 1) <= tolerance,
          abs(levelDot(up, up) - 1) <= tolerance,
          abs(levelDot(forward, forward) - 1) <= tolerance,
          abs(levelDot(right, up)) <= tolerance,
          abs(levelDot(right, forward)) <= tolerance,
          abs(levelDot(up, forward)) <= tolerance else {
        return false
    }
    let expectedRight = levelCross(up, forward)
    return abs(expectedRight.x - right.x) <= tolerance
        && abs(expectedRight.y - right.y) <= tolerance
        && abs(expectedRight.z - right.z) <= tolerance
}

func isCanonicalRigidTransform(
    position: Vector3,
    orientation: Matrix3
) -> Bool {
    isFinite(position) && isOrthonormal(orientation)
}

func levelDot(_ a: Vector3, _ b: Vector3) -> Float {
    a.x * b.x + a.y * b.y + a.z * b.z
}

func levelCross(_ a: Vector3, _ b: Vector3) -> Vector3 {
    .init(
        x: a.y * b.z - a.z * b.y,
        y: a.z * b.x - a.x * b.z,
        z: a.x * b.y - a.y * b.x
    )
}

private func validateLocation(_ location: SpatialLocation, rooms: [Int: LevelRoom]) throws {
    switch location {
    case .room(let index):
        guard rooms[index] != nil else { throw LevelValidationError.invalidLocation }
    case .terrainCell(let index):
        guard (0..<65_536).contains(index) else { throw LevelValidationError.invalidLocation }
    }
}

private func validateObjectLocation(_ location: SpatialLocation, rooms: [Int: LevelRoom]) throws {
    try validateLocation(location, rooms: rooms)
    if case .room(let index) = location,
       let room = rooms[index],
       room.flags & 0x0000_0004 != 0 {
        throw LevelValidationError.invalidLocation
    }
}

private func isNonempty(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func isSHA256(_ value: String) -> Bool {
    isLowercaseHex(value, count: 64)
}

private func isLowercaseHex(_ value: String, count: Int) -> Bool {
    value.utf8.count == count && value.utf8.allSatisfy {
        ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66)
    }
}

private func isSafeRelativePath(_ path: String) -> Bool {
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    return !components.isEmpty
        && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
}
