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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
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
        if let concussion = ship.playerConcussion {
            for texture in concussion.explosionFrames
            where !dependencies.contains(where: {
                $0.category == "texture" && $0.source == texture
            }) {
                dependencies.append(.init(
                    category: "texture",
                    source: texture,
                    state: "presentation-payload-imported",
                    provenance:
                        "manage/weaponpage.cpp:653-901; Descent3/WeaponFire.cpp:3058-3201"
                ))
            }
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingOpeningLesson(
        _ lesson: TrainingOpeningLesson,
        voiceClips: [CanonicalVoiceClip],
        soundClips addedSoundClips: [CanonicalSoundClip] = []
    ) -> Level {
        let lessonPresentations = objectPresentations.map { presentation in
            let hiddenHandles = [
                lesson.forwardGoalObjectHandle,
                lesson.returnLeft?.startGoalObjectHandle,
                lesson.returnRight?.leftGoalObjectHandle,
                lesson.returnUp?.startGoalObjectHandle,
                lesson.returnDown?.upGoalObjectHandle,
                lesson.repeatForwardGoal?.forwardGoalObjectHandle,
                lesson.repeatReturnLeft?.startGoalObjectHandle,
                lesson.repeatReturnRight?.leftGoalObjectHandle,
                lesson.repeatReturnUp?.startGoalObjectHandle,
                lesson.repeatReturnDown?.upGoalObjectHandle,
                lesson.startCourse?.startCourseObjectHandle,
                lesson.finishCourse?.finishCourseObjectHandle,
            ]
            guard hiddenHandles.contains(presentation.objectHandle) else {
                return presentation
            }
            return ObjectPresentationReference(
                objectHandle: presentation.objectHandle,
                primaryModel: presentation.primaryModel,
                mediumModel: presentation.mediumModel,
                lowModel: presentation.lowModel,
                dyingModel: presentation.dyingModel,
                mediumDistance: presentation.mediumDistance,
                lowDistance: presentation.lowDistance,
                isVisible: false
            )
        }
        var dependencies = dependencyManifest.current
        for clip in voiceClips {
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
            objectPresentations: lessonPresentations,
            trainingOpeningLesson: lesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingGalleryBarrier(
        _ barrier: TrainingGalleryBarrier,
        voiceClip: CanonicalVoiceClip
    ) -> Level {
        let dependency = DependencyRecord(
            category: "voice",
            source: .init(
                storedIndex: voiceClip.sourceEntryIndex,
                sourceName: voiceClip.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance:
                "\(voiceClip.sourceArchive) \(voiceClip.sourceSHA256)"
        )
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: barrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips + [voiceClip],
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencyManifest.current + [dependency],
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRobotGuidebotChain(
        _ chain: TrainingRobotGuidebotChain,
        voiceClips addedVoiceClips: [CanonicalVoiceClip],
        soundClips addedSoundClips: [CanonicalSoundClip] = []
    ) -> Level {
        var dependencies = addedVoiceClips.map { clip in
            DependencyRecord(
                category: "voice",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
        }
        if !dependencyManifest.current.contains(where: {
            $0.category.caseInsensitiveCompare("object-definition")
                == .orderedSame
                && $0.source.sourceName.caseInsensitiveCompare("GuideBot")
                    == .orderedSame
        }) {
            dependencies.append(.init(
                category: "object-definition",
                source: .init(storedIndex: 0, sourceName: "GuideBot"),
                state: "canonical-reserved-object",
                provenance: "scripts/AIGame.cpp:4668-4728"
            ))
        }
        dependencies += addedSoundClips.map { clip in
            DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
        }
        if let flare = chain.yellowFlare {
            dependencies.append(.init(
                category: "weapon-definition",
                source: flare.source,
                state: "canonical-page-bound",
                provenance:
                    "manage/weaponpage.cpp:653-901; scripts/AIGame.cpp:6086-6115"
            ))
            if !dependencyManifest.current.contains(where: {
                $0.category == "texture"
                    && $0.source == flare.particleTexture
            }) {
                dependencies.append(.init(
                    category: "texture",
                    source: flare.particleTexture,
                    state: "presentation-payload-imported",
                    provenance:
                        "manage/weaponpage.cpp:653-901; viseffect.cpp:899-933"
                ))
            }
            if let timeout = flare.timeout {
                dependencies.append(.init(
                    category: "weapon-definition",
                    source: timeout.childSource,
                    state: "canonical-page-bound",
                    provenance:
                        "manage/weaponpage.cpp:653-901; Descent3/WeaponFire.cpp:3162-3201"
                ))
                for texture in [timeout.explosionTexture]
                    + (timeout.childAnimationFrames
                        ?? [timeout.childTexture])
                where !dependencyManifest.current.contains(where: {
                    $0.category == "texture" && $0.source == texture
                }) && !dependencies.contains(where: {
                    $0.category == "texture" && $0.source == texture
                }) {
                    dependencies.append(.init(
                        category: "texture",
                        source: texture,
                        state: "presentation-payload-imported",
                        provenance:
                            "manage/weaponpage.cpp:653-901; Descent3/WeaponFire.cpp:3058-3201"
                    ))
                }
            }
        }
        let player = objects.first {
            $0.handle == defaultPlayerBinding?.objectHandle
        }!
        let guidebotModel = models.first {
            $0.source.sourceName.caseInsensitiveCompare("Buddybot.oof")
                == .orderedSame
        }!
        let guidebotObject = PlacedObject(
            handle: chain.guidebotObjectHandle,
            type: 2,
            storedID: 0,
            definition: .init(storedIndex: 0, sourceName: "GuideBot"),
            instanceName: "GuideBotB",
            flags: 0x110f,
            doorShields: nil,
            location: player.location,
            position: player.position,
            orientation: player.orientation,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        let guidebotPresentation = ObjectPresentationReference(
            objectHandle: chain.guidebotObjectHandle,
            primaryModel: guidebotModel.source,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects + [guidebotObject],
            retiredObjectHandles: retiredObjectHandles.filter {
                $0 != chain.guidebotObjectHandle
            },
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
            objectPresentations:
                objectPresentations + [guidebotPresentation],
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: chain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips + addedVoiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencyManifest.current + dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingCameraMonitorChain(
        _ chain: TrainingCameraMonitorChain,
        voiceClips addedVoiceClips: [CanonicalVoiceClip],
        soundClips addedSoundClips: [CanonicalSoundClip]
    ) -> Level {
        var dependencies = dependencyManifest.current
        let reachedDependencies = addedVoiceClips.map { clip in
            DependencyRecord(
                category: "voice",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
        } + addedSoundClips.map { soundClip in DependencyRecord(
            category: "sound",
            source: .init(
                storedIndex: soundClip.sourceEntryIndex,
                sourceName: soundClip.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance:
                "\(soundClip.sourceArchive) \(soundClip.sourceSHA256)"
        )}
        for reached in reachedDependencies {
            if let index = dependencies.firstIndex(where: {
                $0.category == reached.category
                    && $0.source == reached.source
            }) {
                dependencies[index] = reached
            } else {
                dependencies.append(reached)
            }
        }
        return Level(
            schemaVersion: 10,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: chain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips + addedVoiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot1DeathChain(
        _ chain: TrainingRASBot1DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: chain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot2DeathChain(
        _ chain: TrainingRASBot2DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: chain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot3DeathChain(
        _ chain: TrainingRASBot3DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: chain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot4DeathChain(
        _ chain: TrainingRASBot4DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: chain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingLastBot1DeathChain(
        _ chain: TrainingLastBot1DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: chain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: trainingLastRoomChain,
            trainingFinalRoomEntryChain: trainingFinalRoomEntryChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingLastBot2DeathChain(
        _ chain: TrainingLastBot2DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot2DeathChain = chain
        return level
    }

    func addingTrainingLastBot3DeathChain(
        _ chain: TrainingLastBot3DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot3DeathChain = chain
        return level
    }

    func addingTrainingLastBot4DeathChain(
        _ chain: TrainingLastBot4DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot4DeathChain = chain
        return level
    }

    func addingTrainingLastBot5DeathChain(
        _ chain: TrainingLastBot5DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot5DeathChain = chain
        return level
    }

    func addingTrainingFinalBotsCompletionChain(
        _ chain: TrainingFinalBotsCompletionChain,
        voiceClip: CanonicalVoiceClip
    ) -> Level {
        let dependency = DependencyRecord(
            category: "voice",
            source: .init(
                storedIndex: voiceClip.sourceEntryIndex,
                sourceName: voiceClip.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance:
                "\(voiceClip.sourceArchive) \(voiceClip.sourceSHA256)"
        )
        var level = Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: trainingLastRoomChain,
            trainingFinalRoomEntryChain: trainingFinalRoomEntryChain,
            trainingFinalBotsCompletionChain: chain,
            voiceClips: voiceClips + [voiceClip],
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencyManifest.current + [dependency],
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
        level.trainingLastBot2DeathChain =
            trainingLastBot2DeathChain
        level.trainingLastBot3DeathChain =
            trainingLastBot3DeathChain
        level.trainingLastBot4DeathChain =
            trainingLastBot4DeathChain
        level.trainingLastBot5DeathChain =
            trainingLastBot5DeathChain
        return level
    }

    func addingTrainingFinalGoalChain(
        _ chain: TrainingFinalGoalChain
    ) -> Level {
        var level = self
        level.trainingFinalGoalChain = chain
        return level
    }

    func addingTrainingInvulnerabilityPickupChain(
        _ chain: TrainingInvulnerabilityPickupChain,
        soundClips addedSoundClips: [CanonicalSoundClip]
    ) -> Level {
        var dependencies = dependencyManifest.current
        let objectDefinition = DependencyRecord(
            category: "object-definition",
            source: .init(
                storedIndex: 3,
                sourceName: "Invulnerability"
            ),
            state: "canonical-object-definition",
            provenance:
                "training.mn3/TrainingMission.d3l handle 2076"
        )
        if !dependencies.contains(where: {
            $0.category == objectDefinition.category
                && $0.source == objectDefinition.source
        }) {
            dependencies.append(objectDefinition)
        }
        for clip in addedSoundClips {
            let reached = DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
            if let index = dependencies.firstIndex(where: {
                $0.category == reached.category
                    && $0.source == reached.source
            }) {
                dependencies[index] = reached
            } else {
                dependencies.append(reached)
            }
        }
        return Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain: chain,
            voiceClips: voiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingCloakPickupChain(
        _ chain: TrainingCloakPickupChain,
        soundClips addedSoundClips: [CanonicalSoundClip]
    ) -> Level {
        var dependencies = dependencyManifest.current
        let objectDefinition = DependencyRecord(
            category: "object-definition",
            source: .init(storedIndex: 4, sourceName: "Cloak"),
            state: "canonical-object-definition",
            provenance:
                "training.mn3/TrainingMission.d3l handle 2073"
        )
        if !dependencies.contains(where: {
            $0.category == objectDefinition.category
                && $0.source == objectDefinition.source
        }) {
            dependencies.append(objectDefinition)
        }
        for clip in addedSoundClips {
            let reached = DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
            if let index = dependencies.firstIndex(where: {
                $0.category == reached.category
                    && $0.source == reached.source
            }) {
                dependencies[index] = reached
            } else {
                dependencies.append(reached)
            }
        }
        return Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: chain,
            voiceClips: voiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingLastRoomChain(
        _ chain: TrainingLastRoomChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: chain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingFinalRoomEntryChain(
        _ chain: TrainingFinalRoomEntryChain,
        voiceClip: CanonicalVoiceClip
    ) -> Level {
        let dependency = DependencyRecord(
            category: "voice",
            source: .init(
                storedIndex: voiceClip.sourceEntryIndex,
                sourceName: voiceClip.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance:
                "\(voiceClip.sourceArchive) \(voiceClip.sourceSHA256)"
        )
        return Level(
            schemaVersion: 11,
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
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: trainingLastRoomChain,
            trainingFinalRoomEntryChain: chain,
            voiceClips: voiceClips + [voiceClip],
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencyManifest.current + [dependency],
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }
}
