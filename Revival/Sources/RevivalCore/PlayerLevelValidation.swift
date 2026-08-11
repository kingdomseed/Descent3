import Foundation

extension Level {
    func validatePlayerShipBinding() throws {
        let playerZero = objects.first {
            $0.type == D3SourceIdentity.playerObjectType && $0.storedID == 0
        }
        if shipDefinitions.isEmpty && defaultPlayerBinding == nil {
            return
        }
        guard let playerZero,
              shipDefinitions.count == 1,
              let binding = defaultPlayerBinding,
              binding.playerID == 0,
              binding.objectHandle == playerZero.handle,
              binding.ship == shipDefinitions[0].source,
              case .room = playerZero.location else {
            throw LevelValidationError.invalidDependency("default player ship binding")
        }
        let ship = shipDefinitions[0]
        guard D3SourceIdentity.isValidSourceResource(
            ship.source,
            category: "ship-definition"
        ),
              models.contains(where: { $0.source == ship.primaryModel }),
              objectPresentations.contains(where: {
                  $0.objectHandle == binding.objectHandle
                      && $0.primaryModel == ship.primaryModel
              }),
              ship.presentationSize.isFinite,
              ship.presentationSize > 0,
              Set(ship.physics.behaviors).count == ship.physics.behaviors.count,
              ship.physics.behaviors == [.turnroll, .wiggle, .usesThrust] else {
            throw LevelValidationError.invalidDependency("default player ship definition")
        }
        let values = [
            ship.physics.mass,
            ship.physics.drag,
            ship.physics.fullThrust,
            ship.physics.rotationalDrag,
            ship.physics.fullRotationalThrust,
            ship.physics.initialForwardVelocity,
            ship.physics.initialAngularVelocity.x,
            ship.physics.initialAngularVelocity.y,
            ship.physics.initialAngularVelocity.z,
            ship.physics.wiggleAmplitude,
            ship.physics.wigglesPerSecond,
            ship.physics.coefficientOfRestitution,
            ship.physics.hitDieDot,
            ship.physics.maximumTurnrollRate,
            ship.physics.turnrollRatio,
        ]
        guard values.allSatisfy(\.isFinite),
              ship.physics.mass > 0,
              ship.physics.drag > 0,
              ship.physics.fullThrust >= 0,
              ship.physics.rotationalDrag >= 0,
              ship.physics.fullRotationalThrust >= 0 else {
            throw LevelValidationError.invalidDependency("default player ship physics")
        }
        if let concussion = ship.playerConcussion {
            let fireSound = soundClips.first {
                $0.logicalName == concussion.fireSoundLogicalNames.first
                    && $0.sourceName == concussion.fireSoundSourceName
            }
            let impactSound = soundClips.first {
                $0.logicalName == concussion.impactSoundLogicalName
                    && $0.sourceName == concussion.impactSoundSourceName
            }
            let expectedExplosionNames = ["ExplosionE"]
                + (1..<15).map { "ExplosionE.oaf frame \($0)" }
            let forwardLengths = concussion.gunpoints.map {
                sqrt(levelDot($0.localForward, $0.localForward))
            }
            guard schemaVersion == 11,
                  concussion.batteryIndex == 10,
                  concussion.firingMasks == [1, 2],
                  concussion.weapon.sourceName == "Concussion",
                  concussion.model.sourceName
                    .caseInsensitiveCompare("ConcussionMissile.OOF")
                    == .orderedSame,
                  models.contains(where: { $0.source == concussion.model }),
                  concussion.fireSoundLogicalNames
                    == ["concmissilefire71", "concmissilefire71"],
                  concussion.fireSoundSourceName == "concmissilefire7.wav",
                  concussion.impactSoundLogicalName == "Explode1",
                  concussion.impactSoundSourceName == "Explode1.wav",
                  fireSound != nil,
                  impactSound != nil,
                  concussion.fireWaits == [0.5, 0.5],
                  concussion.energyUsage == 0,
                  concussion.ammoUsage == 1,
                  concussion.fireFlags == 0,
                  concussion.weaponFlags == 0,
                  concussion.gunpoints.map(\.index) == [1, 2],
                  concussion.gunpoints.map(\.parentSubmodelIndex) == [0, 0],
                  concussion.gunpoints[0].localPosition.x.bitPattern
                    == Float(2.792_412_5).bitPattern,
                  concussion.gunpoints[0].localPosition.y.bitPattern
                    == Float(-1.186_958_9).bitPattern,
                  concussion.gunpoints[0].localPosition.z.bitPattern
                    == Float(2.687_090_9).bitPattern,
                  concussion.gunpoints[1].localPosition.x.bitPattern
                    == Float(-2.804_046_4).bitPattern,
                  concussion.gunpoints[1].localPosition.y.bitPattern
                    == Float(-1.186_885_0).bitPattern,
                  concussion.gunpoints[1].localPosition.z.bitPattern
                    == Float(2.687_135_2).bitPattern,
                  concussion.gunpoints[0].localForward.x.bitPattern
                    == Float(0.000_007_629_434_5).bitPattern,
                  concussion.gunpoints[0].localForward.y.bitPattern
                    == Float(0.000_003_337_758_7).bitPattern,
                  concussion.gunpoints[0].localForward.z.bitPattern
                    == Float(1).bitPattern,
                  concussion.gunpoints[1].localForward.x.bitPattern
                    == Float(0.000_008_106_278).bitPattern,
                  concussion.gunpoints[1].localForward.y.bitPattern
                    == Float(0.000_003_814_590_4).bitPattern,
                  concussion.gunpoints[1].localForward.z.bitPattern
                    == Float(1).bitPattern,
                  forwardLengths.allSatisfy({
                      $0.isFinite && abs($0 - 1) < 0.000_1
                  }),
                  concussion.collisionRadius == 1,
                  concussion.speed == 175,
                  concussion.lifetime == 15,
                  concussion.rotationalVelocity == 35_000,
                  concussion.lightDistance == 12.5,
                  concussion.lightPresentation.primaryColor
                    == .init(x: 1, y: 0.5, z: 0),
                  concussion.explosionFrames.map(\.sourceName)
                    == expectedExplosionNames,
                  Set(concussion.explosionFrames.map(\.storedIndex)).count == 1,
                  concussion.explosionFrames.allSatisfy({ frame in
                      presentationMaterials.contains { $0.texture == frame }
                  }),
                  concussion.explosionSourceFrameTime.bitPattern
                    == (Float(0.5) / 15).bitPattern,
                  concussion.explosionSize == 10,
                  concussion.explosionLifetime == 0.5,
                  concussion.directRobotDamage == 9,
                  concussion.shockwaveDuration == 0.1,
                  concussion.shockwaveRadius == 32,
                  concussion.shockwaveDamage == 19,
                  concussion.shockwaveForce == 3_000 else {
                throw LevelValidationError.invalidDependency(
                    "default player Concussion binding"
                )
            }
        }
        if let flare = ship.playerYellowFlare {
            let yellow = trainingRobotGuidebotChain?.yellowFlare
            let sound = soundClips.first {
                $0.logicalName == flare.fireSoundLogicalName
                    && $0.sourceName == flare.fireSoundSourceName
            }
            let forwardLength = sqrt(levelDot(
                flare.gunpointLocalForward,
                flare.gunpointLocalForward
            ))
            guard schemaVersion == 11,
                  flare.batteryIndex == 20,
                  flare.firingMask == 1,
                  flare.weapon == yellow?.source,
                  flare.fireSoundLogicalName == "Flare",
                  flare.fireSoundSourceName == yellow?.fireSoundSourceName,
                  sound != nil,
                  flare.fireWait == 1,
                  flare.energyUsage == 0,
                  flare.ammoUsage == 0,
                  flare.fireFlags == 0,
                  flare.weaponFlags == 0,
                  flare.gunpointIndex == 0,
                  flare.gunpointParentSubmodelIndex == 0,
                  flare.gunpointLocalPosition.x.bitPattern
                    == Float(0.000_000_444_4).bitPattern,
                  flare.gunpointLocalPosition.y.bitPattern
                    == Float(-1.046_244_4).bitPattern,
                  flare.gunpointLocalPosition.z.bitPattern
                    == Float(3.179_825_1).bitPattern,
                  flare.gunpointLocalForward.x.bitPattern
                    == Float(0.000_007_629_6).bitPattern,
                  flare.gunpointLocalForward.y.bitPattern
                    == Float(-0.000_015_258_7).bitPattern,
                  flare.gunpointLocalForward.z.bitPattern
                    == Float(1).bitPattern,
                  forwardLength.isFinite,
                  abs(forwardLength - 1) < 0.000_1 else {
                throw LevelValidationError.invalidDependency(
                    "default player Yellow flare binding"
                )
            }
        }
    }

    func validatePlayerPresentationClosure(allowIncomplete: Bool) throws {
        if allowIncomplete && presentationMaterials.isEmpty && presentationCoronaAssets.isEmpty {
            return
        }

        let roomBySourceIndex = Dictionary(
            uniqueKeysWithValues: rooms.map { ($0.sourceIndex, $0) }
        )
        let presentationFaces: [SourceVisibleFace]
        if let binding = defaultPlayerBinding,
           let player = objects.first(where: { $0.handle == binding.objectHandle }),
           case .room(let playerRoomSourceIndex) = player.location {
            let presentationRoomIndices = reciprocalPortalComponent(
                rooms: rooms,
                startRoomSourceIndex: playerRoomSourceIndex
            )
            presentationFaces = rooms
                .filter { presentationRoomIndices.contains($0.sourceIndex) }
                .flatMap { room in
                    room.faces.indices.map {
                        SourceVisibleFace(roomSourceIndex: room.sourceIndex, faceIndex: $0)
                    }
                }
        } else if rooms.contains(where: { $0.sourceIndex == 3 }) {
            do {
                presentationFaces = try extractSourceVisibleWorld(
                    self,
                    camera: .trainingRoom3,
                    startRoomSourceIndex: 3,
                    portalBlends: Dictionary(
                        uniqueKeysWithValues: presentationMaterials.map {
                            ($0.texture, $0.blend)
                        }
                    )
                ).faces
            } catch {
                throw LevelValidationError.invalidDependency("reference presentation view")
            }
        } else {
            guard presentationMaterials.isEmpty,
                  presentationCoronaAssets.isEmpty,
                  lightmaps.pages.allSatisfy({ $0.rgba8 == nil }),
                  dependencyManifest.current.allSatisfy({
                      $0.state != "presentation-payload-imported"
                  }) else {
                throw LevelValidationError.invalidDependency("orphan presentation payload")
            }
            return
        }
        let requiredRoomTextures = Set(presentationFaces.map {
            roomBySourceIndex[$0.roomSourceIndex]!.faces[$0.faceIndex].texture
        })
        let requiredModelTextures = referencedModelTextures(in: models)
        let requiredTextures = requiredRoomTextures
            .union(requiredModelTextures)
            .union(
                trainingRobotGuidebotChain?.yellowFlare.map {
                    [$0.particleTexture]
                        + ($0.timeout.map {
                            [$0.explosionTexture]
                                + ($0.childAnimationFrames
                                    ?? [$0.childTexture])
                        } ?? [])
                } ?? []
            )
            .union(
                shipDefinitions.first?.playerConcussion?.explosionFrames
                    ?? []
            )
        guard Set(presentationMaterials.map(\.texture)) == requiredTextures else {
            throw LevelValidationError.invalidDependency("player-component textures")
        }
        let materialByTexture = Dictionary(
            uniqueKeysWithValues: presentationMaterials.map { ($0.texture, $0) }
        )
        var requiredCoronaAssetIndices: Set<Int> = []
        for reference in presentationFaces {
            let face = roomBySourceIndex[reference.roomSourceIndex]!.faces[reference.faceIndex]
            guard face.allowsLightCorona,
                  let corona = materialByTexture[face.texture]?.lightCorona else { continue }
            requiredCoronaAssetIndices.insert(corona.assetIndex)
        }
        guard requiredCoronaAssetIndices == Set(presentationCoronaAssets.indices) else {
            throw LevelValidationError.invalidDependency("player-component corona assets")
        }

        let requiredLightmapPages = Set(presentationFaces.compactMap { reference -> Int? in
            let face = roomBySourceIndex[reference.roomSourceIndex]!.faces[reference.faceIndex]
            return face.lightmapInfoIndex.map { lightmaps.infos[$0].pageIndex }
        })
        let importedLightmapPages = Set(lightmaps.pages.indices.filter { index in
            lightmaps.pages[index].rgba8 != nil
        })
        guard importedLightmapPages == requiredLightmapPages else {
            throw LevelValidationError.invalidDependency("player-component lightmaps")
        }

        let importedDependencies = Set(dependencyManifest.current.compactMap {
            $0.state == "presentation-payload-imported"
                ? DependencyIdentity(category: $0.category, source: $0.source)
                : nil
        })
        let requiredDependencies = Set(requiredTextures.map {
            DependencyIdentity(category: "texture", source: $0)
        }).union(models.map {
            DependencyIdentity(category: "model", source: $0.source)
        }).union(requiredLightmapPages.map {
            DependencyIdentity(
                category: "lightmap-page",
                source: .init(storedIndex: $0, sourceName: "lightmap-page-\($0)")
            )
        }).union(requiredCoronaAssetIndices.map {
            DependencyIdentity(
                category: "presentation-effect",
                source: presentationCoronaAssets[$0].source
            )
        })
        guard importedDependencies == requiredDependencies else {
            throw LevelValidationError.invalidDependency("player-component presentation state")
        }

        if defaultPlayerBinding != nil {
            do {
                _ = try extractWorldForRendering(self, playerView: defaultPlayerView(in: self))
            } catch {
                throw LevelValidationError.invalidDependency("player initial view")
            }
        }
    }
}
