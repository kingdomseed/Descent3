import Foundation

extension Level {
    func addingPresentationMaterials(
        _ materials: [PresentationMaterial],
        retainingLightmapPages retainedPageIndices: Set<Int>,
        coronaAssets: [PresentationCoronaAsset] = []
    ) -> Level {
        let retainedLightmaps = LightmapCatalog(
            pages: lightmaps.pages.enumerated().map { index, page in
                LightmapPageMetadata(
                    width: page.width,
                    height: page.height,
                    rgba8: retainedPageIndices.contains(index) ? page.rgba8 : nil
                )
            },
            infos: lightmaps.infos
        )
        let materialSources = Set(materials.map(\.texture))
        let coronaSources = Set(coronaAssets.map(\.source))
        var dependencies = dependencyManifest.current.map { dependency in
            let preparedTexture = dependency.category == "texture"
                && materialSources.contains(dependency.source)
            let preparedLightmapPage = dependency.category == "lightmap-page"
                && retainedPageIndices.contains(dependency.source.storedIndex)
            let preparedCorona = dependency.category == "presentation-effect"
                && coronaSources.contains(dependency.source)
            guard preparedTexture || preparedLightmapPage || preparedCorona else {
                if dependency.state == "presentation-payload-imported" {
                    return DependencyRecord(
                        category: dependency.category,
                        source: dependency.source,
                        state: "payload-validated-preparation-deferred",
                        provenance: dependency.provenance
                    )
                }
                return dependency
            }
            return DependencyRecord(
                category: dependency.category,
                source: dependency.source,
                state: "presentation-payload-imported",
                provenance: dependency.provenance
            )
        }
        let existingDependencies = Set(dependencies.map {
            DependencyIdentity(category: $0.category, source: $0.source)
        })
        for asset in coronaAssets where !existingDependencies.contains(
            DependencyIdentity(category: "presentation-effect", source: asset.source)
        ) {
            dependencies.append(
                DependencyRecord(
                    category: "presentation-effect",
                    source: asset.source,
                    state: "presentation-payload-imported",
                    provenance: "D3Import-resolved face-light corona"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: retainedLightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: materials,
            presentationCoronaAssets: coronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: objectPresentations,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        ).preservingScripting(of: self)
    }

    func addingObjectPresentation(
        models newModels: [CanonicalModel],
        objectPresentations newObjectPresentations: [ObjectPresentationReference],
        materials newMaterials: [PresentationMaterial]
    ) -> Level {
        let combinedMaterials = presentationMaterials + newMaterials.filter { candidate in
            !presentationMaterials.contains(where: { $0.texture == candidate.texture })
        }
        let reachedModelSources = Set(newModels.map(\.source))
        let reachedTextureSources = referencedModelTextures(in: newModels)
        var dependencies = dependencyManifest.current.map { dependency in
            let reached = dependency.category == "model"
                ? reachedModelSources.contains(dependency.source)
                : dependency.category == "texture"
                    && reachedTextureSources.contains(dependency.source)
            guard reached else { return dependency }
            return DependencyRecord(
                category: dependency.category,
                source: dependency.source,
                state: "presentation-payload-imported",
                provenance: dependency.provenance
            )
        }
        var identities = Set(dependencies.map {
            DependencyIdentity(category: $0.category, source: $0.source)
        })
        for model in newModels where identities.insert(
            .init(category: "model", source: model.source)
        ).inserted {
            dependencies.append(
                .init(
                    category: "model",
                    source: model.source,
                    state: "presentation-payload-imported",
                    provenance: "D3Import-resolved reached object model"
                )
            )
        }
        for texture in reachedTextureSources.sorted(by: sourceResourceIsOrdered)
        where identities.insert(.init(category: "texture", source: texture)).inserted {
            dependencies.append(
                .init(
                    category: "texture",
                    source: texture,
                    state: "presentation-payload-imported",
                    provenance: "D3Import-resolved reached model material"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: combinedMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: newModels,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: newObjectPresentations,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        ).preservingScripting(of: self)
    }

    var hasPlayerPresentation: Bool {
        !presentationMaterials.isEmpty
            && defaultPlayerBinding != nil
    }

    func addingSurfacePhysics(_ entries: [SurfacePhysicsEntry]) -> Level {
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: entries,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: objectPresentations,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        ).preservingScripting(of: self)
    }

    func addingDefaultPlayerShip(
        _ ship: CanonicalShipDefinition,
        binding: DefaultPlayerBinding
    ) -> Level {
        var dependencies = dependencyManifest.current
        let identity = DependencyIdentity(category: "ship-definition", source: ship.source)
        if !dependencies.contains(where: {
            DependencyIdentity(category: $0.category, source: $0.source) == identity
        }) {
            dependencies.append(
                .init(
                    category: "ship-definition",
                    source: ship.source,
                    state: "canonical-typed-definition",
                    provenance: "D3Import-resolved default player ship"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: [ship],
            defaultPlayerBinding: binding,
            objectPresentations: objectPresentations,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        ).preservingScripting(of: self)
    }

    /// This level with more imported voice and sound clips and their
    /// dependency records.
    func addingAudioClips(
        voiceClips addedVoiceClips: [CanonicalVoiceClip],
        soundClips addedSoundClips: [CanonicalSoundClip] = []
    ) -> Level {
        var dependencies = dependencyManifest.current
        for clip in addedVoiceClips {
            dependencies.append(
                .init(
                    category: "voice",
                    source: .init(
                        storedIndex: clip.sourceEntryIndex,
                        sourceName: clip.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "\(clip.sourceArchive) \(clip.sourceSHA256)"
                )
            )
        }
        for clip in addedSoundClips {
            dependencies.append(
                .init(
                    category: "sound",
                    source: .init(
                        storedIndex: clip.sourceEntryIndex,
                        sourceName: clip.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "\(clip.sourceArchive) \(clip.sourceSHA256)"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: objectPresentations,
            voiceClips: voiceClips + addedVoiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        ).preservingScripting(of: self)
    }
}
