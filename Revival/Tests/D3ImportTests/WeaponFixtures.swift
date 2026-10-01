import XCTest

// Synthetic weapon and ship battery tables for the player's weapons. The
// values follow the retail pages D3Import reads (the Pyro-GL ship page's
// batteries 0 and 10, and the Laser Level 2 - Blue and Concussion weapon
// pages); no retail bytes are stored.

/// A blue laser like Laser Level 2 - Blue: fixed velocity 225, 5 s of life,
/// 7.5 damage, a custom size of 1.25, and a light of distance 15.
func fixtureBlueLaser(model: SourceResource) -> CanonicalWeapon {
    CanonicalWeapon(
        name: "Laser Level 2 - Blue",
        flags: 0x8002_0000,
        model: model,
        size: 4.930_813,
        customSize: 1.25,
        mass: 0.1,
        drag: 0.1,
        physicsFlags: 0x20_1800,
        speed: 225,
        fullThrust: 0,
        lifetime: 5,
        playerDamage: 7.5,
        genericDamage: 7.5,
        sounds: Array(repeating: "", count: 7),
        impact: .init(
            size: 0, time: 0, playerDamage: 2, genericDamage: 2, force: 750
        ),
        explosion: .init(hasImage: true, frames: [], lifetime: 0.36, size: 2.7),
        lightDistance: 15,
        lighting: .init(
            primaryColor: .init(x: 0.25, y: 0.25, z: 1),
            secondaryColor: .init(x: 0.25, y: 0.5, z: 1),
            timeInterval: 0,
            flickerDistance: 0,
            directionalDot: 0,
            flags: 0,
            timebits: 0,
            angle: 0,
            lightingRenderType: 0
        )
    )
}

/// A Concussion missile: a matter weapon that slows with drag 0.05, lives
/// 15 s, does 6 damage, and explodes into a 0.1 s shockwave of radius 32
/// and 19 damage.
func fixtureConcussion(
    model: SourceResource,
    explosionFrames: [SourceResource],
    impactWallSound: String = ""
) -> CanonicalWeapon {
    CanonicalWeapon(
        name: "Concussion",
        flags: 0x8000_0008,
        model: model,
        size: 1.284_937_1,
        customSize: 1,
        mass: 1,
        drag: 0.05,
        physicsFlags: 0x20_1400,
        speed: 175,
        fullThrust: 50,
        lifetime: 15,
        playerDamage: 6,
        genericDamage: 6,
        sounds: ["", impactWallSound, "", "", "", "", ""],
        impact: .init(
            size: 32, time: 0.1, playerDamage: 19, genericDamage: 19,
            force: 3_000
        ),
        explosion: .init(
            hasImage: true,
            frames: explosionFrames,
            lifetime: 0.5,
            size: 10
        ),
        lightDistance: 12.5,
        lighting: .init(
            primaryColor: .init(x: 1, y: 0.5, z: 0.25),
            secondaryColor: .init(x: 1, y: 0.75, z: 0.25),
            timeInterval: 0,
            flickerDistance: 0,
            directionalDot: 0,
            flags: 0,
            timebits: 0,
            angle: 0,
            lightingRenderType: 0
        )
    )
}

/// The Pyro-GL batteries InitPlayerNewShip gives: battery 0 fires the blue
/// laser from gun points 1 and 2 together every 0.25 s for 0.15 energy, and
/// battery 10 fires a Concussion from gun point 1, then 2, every 0.5 s for
/// one missile.
func fixturePlayerShipBatteries(
    concussionFireSound: String = ""
) -> [CanonicalShipWeaponBattery] {
    let laser = "Laser Level 2 - Blue"
    return [
        .init(
            index: 0,
            battery: .init(
                gunpointWeapons: ["", laser, laser],
                fireMasks: [6],
                fireWaits: [0.25],
                fireSounds: [""],
                aimingGunpointIndex: 0,
                aimingFlags: 0,
                aiming3DDot: 0,
                aiming3DDistance: 0,
                aimingXZDot: 0,
                flags: 0,
                quadFireMask: 0
            ),
            energyUsage: 0.15,
            ammoUsage: 0,
            fireFlags: 0
        ),
        .init(
            index: 10,
            battery: .init(
                gunpointWeapons: ["", "Concussion", "Concussion"],
                fireMasks: [2, 4],
                fireWaits: [0.5, 0.5],
                fireSounds: [concussionFireSound, concussionFireSound],
                aimingGunpointIndex: 0,
                aimingFlags: 0,
                aiming3DDot: 0,
                aiming3DDistance: 0,
                aimingXZDot: 0,
                flags: 0,
                quadFireMask: 0
            ),
            energyUsage: 0,
            ammoUsage: 1,
            fireFlags: 0
        ),
    ]
}

/// The Pyro-GL's gun points 0 to 2 on its main submodel: the flare's, then
/// the two wing guns.
let fixturePlayerShipGunpoints = [
    ModelGunpoint(
        parent: 0,
        position: .init(x: 0.000_000_444_4, y: -1.046_244_4, z: 3.179_825_1),
        normal: .init(x: 0, y: 0, z: 1)
    ),
    ModelGunpoint(
        parent: 0,
        position: .init(x: 2.792_412_5, y: -1.186_958_9, z: 2.687_090_9),
        normal: .init(x: 0.000_007_629_434_5, y: 0.000_003_337_758_7, z: 1)
    ),
    ModelGunpoint(
        parent: 0,
        position: .init(x: -2.804_046_4, y: -1.186_885, z: 2.687_135_2),
        normal: .init(x: 0.000_008_106_278, y: 0.000_003_814_590_4, z: 1)
    ),
]

/// The RAS1 Light Security Flyer's death (death type 0: DF_FIREBALL,
/// DF_BREAKS_APART, and DF_DEBRIS_SMOKES, with no delay, always), its score,
/// and its empty impact.
let fixtureFlyerDeathTypes = [
    CanonicalDeathType(
        flags: 0x1_0060, delayMinimum: 0, delayMaximum: 0, probability: 100
    ),
] + Array(
    repeating: CanonicalDeathType(
        flags: 0, delayMinimum: 0, delayMaximum: 0, probability: 0
    ),
    count: 3
)

/// A robot page with no AI, destroyable, with the RAS1 flyer's hit points,
/// death, and score: a target the player can shoot down.
let fixtureTargetRobotInfo = CanonicalObjectInfo(
    name: "RAS1 Light Security Flyer",
    type: 2,
    flags: 0x204,
    size: 4.576_441_8,
    hitPoints: 55,
    lightDistance: 0,
    lighting: fixtureNoLight,
    ai: nil,
    weaponBatteries: [],
    score: 200,
    impact: .init(size: 0, time: 0, damage: 0),
    deathTypes: fixtureFlyerDeathTypes
)

extension Level {
    /// This level with the player's laser and Concussion: their weapons,
    /// models, and explosion textures, the ship batteries, and the ship
    /// model's gun points. `concussionSounds` adds the Concussion fire and
    /// wall impact clips.
    func addingFixturePlayerWeapons(concussionSounds: Bool = false) -> Level {
        var level = self
        let template = level.models[0]
        // Stored indices past every model the level already records.
        let nextModelIndex = (
            level.models.map(\.source.storedIndex)
                + level.dependencyManifest.current
                    .filter { $0.category == "model" }
                    .map(\.source.storedIndex)
        ).max().map { $0 + 1 } ?? 0
        let laserModel = SourceResource(
            storedIndex: nextModelIndex,
            sourceName: "bluelaser.OOF"
        )
        let missileModel = SourceResource(
            storedIndex: nextModelIndex + 1,
            sourceName: "ConcussionMissile.OOF"
        )
        let newModels = [laserModel, missileModel].filter { source in
            !level.models.contains { $0.source.sourceName == source.sourceName }
        }.map { source in
            CanonicalModel(
                source: source,
                collisionRadius: 1,
                submodels: template.submodels,
                bounds: template.bounds,
                sourceArchive: template.sourceArchive,
                sourceSHA256: String(repeating: "c", count: 64)
            )
        }
        // A level that has the weapons keeps its explosion frames.
        let existingFrames = level.weapon(named: "Concussion")?
            .explosion?.frames ?? []
        let firstExplosionIndex = (
            level.presentationMaterials.map(\.texture.storedIndex)
                + level.dependencyManifest.current
                    .filter { $0.category == "texture" }
                    .map(\.source.storedIndex)
        ).max().map { $0 + 1 } ?? 0
        let explosionFrames = !existingFrames.isEmpty ? existingFrames : [
            SourceResource(
                storedIndex: firstExplosionIndex,
                sourceName: "ExplosionE"
            ),
        ] + (1..<15).map {
            SourceResource(
                storedIndex: firstExplosionIndex,
                sourceName: "ExplosionE.oaf frame \($0)"
            )
        }
        let newFrames = existingFrames.isEmpty ? explosionFrames : []
        let materialTemplate = level.presentationMaterials[0]
        let explosionMaterials = newFrames.map { frame in
            PresentationMaterial(
                texture: frame,
                bitmapSourceName: "ExplosionE.oaf",
                image: materialTemplate.image,
                blend: .additiveSourceAlpha(opacity: 255),
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: materialTemplate.sourceArchive,
                sourceSHA256: String(repeating: "e", count: 64)
            )
        }
        var soundClips = level.soundClips
        if concussionSounds {
            let soundTemplate = level.soundClips[0]
            for (logical, source, entry) in [
                ("concmissilefire71", "concmissilefire7.wav", 20_000),
                ("Explode1", "Explode1.wav", 20_001),
            ] where !soundClips.contains(where: { $0.logicalName == logical }) {
                soundClips.append(.init(
                    logicalName: logical,
                    sourceName: source,
                    sourceEntryIndex: entry,
                    sampleRate: soundTemplate.sampleRate,
                    channelCount: soundTemplate.channelCount,
                    frameCount: soundTemplate.frameCount,
                    pcm16LittleEndian: soundTemplate.pcm16LittleEndian,
                    pcmSHA256: soundTemplate.pcmSHA256,
                    sourceArchive: soundTemplate.sourceArchive,
                    sourceSHA256: soundTemplate.sourceSHA256,
                    importVolume: 1
                ))
            }
        }
        let dependencies = newModels.map {
            DependencyRecord(
                category: "model",
                source: $0.source,
                state: "presentation-payload-imported",
                provenance: "synthetic canonical fixture"
            )
        } + newFrames.map {
            DependencyRecord(
                category: "texture",
                source: $0,
                state: "presentation-payload-imported",
                provenance: "synthetic canonical fixture"
            )
        } + soundClips.dropFirst(level.soundClips.count).map {
            DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: $0.sourceEntryIndex,
                    sourceName: $0.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance: "synthetic canonical fixture"
            )
        }
        var ship = level.shipDefinitions[0]
        // A flare battery the level has stays.
        ship.weaponBatteries = fixturePlayerShipBatteries(
            concussionFireSound: concussionSounds ? "concmissilefire71" : ""
        ) + (ship.weaponBatteries ?? []).filter {
            $0.index == PlayerWeaponState.flareIndex
        }
        level = replacing(
            level,
            presentationMaterials:
                level.presentationMaterials + explosionMaterials,
            models: level.models + newModels,
            shipDefinitions: [ship],
            soundClips: soundClips,
            dependencyManifest: .init(
                current: level.dependencyManifest.current + dependencies,
                historicalEagerBaseline:
                    level.dependencyManifest.historicalEagerBaseline
            )
        )
        let laserSource = level.models.first {
            $0.source.sourceName == "bluelaser.OOF"
        }!.source
        let missileSource = level.models.first {
            $0.source.sourceName == "ConcussionMissile.OOF"
        }!.source
        return level
            .addingWeapon(fixtureBlueLaser(model: laserSource))
            .addingWeapon(fixtureConcussion(
                model: missileSource,
                explosionFrames: explosionFrames,
                impactWallSound: concussionSounds ? "Explode1" : ""
            ))
            .settingModelGuns(
                ship.primaryModel,
                gunpoints: fixturePlayerShipGunpoints,
                batteries: [ModelWeaponBattery(gunpoints: [0, 1, 2], turrets: [])]
            )
    }
}

/// The frames of the yellow spark texture (TF_ANIMATED): the texture, then
/// the later frames of its vclip `yellowspark.oaf`.
let fixtureYellowSparkFrames = [
    SourceResource(storedIndex: 878, sourceName: "yellowspark"),
] + (1...5).map {
    SourceResource(
        storedIndex: 878,
        sourceName: "yellowspark.oaf frame \($0)"
    )
}

/// The retail "Yellow flare" page (WF_CUSTOM_SIZE | WF_SPAWNS_TIMEOUT;
/// PF_FIXED_VELOCITY | PF_STICK): a model weapon of size 0.1 that flies
/// at 100 for 15 s, sticks, drops 25 yellow sparks a second, flickers its
/// light of 35 by up to 2, and times out into a FlarePuff and 9
/// YellowFlareSparks.
func fixtureYellowFlare(
    model: SourceResource,
    explosion: SourceResource
) -> CanonicalWeapon {
    CanonicalWeapon(
        name: "Yellow flare",
        flags: 0x8001_0000,
        model: model,
        size: 3.497_431_3,
        customSize: 0.1,
        mass: 0.1,
        drag: 0.000_1,
        physicsFlags: 0x2000_0810,
        speed: 100,
        fullThrust: 0,
        lifetime: 15,
        playerDamage: 1,
        genericDamage: 1,
        sounds: Array(repeating: "", count: 7),
        impact: .init(
            size: 0, time: 0, playerDamage: 1, genericDamage: 1, force: 100
        ),
        explosion: .init(
            hasImage: true,
            frames: [explosion],
            lifetime: 0.2,
            size: 2
        ),
        lightDistance: 35,
        lighting: .init(
            primaryColor: .init(x: 1, y: 1, z: 0.8),
            secondaryColor: .zero,
            timeInterval: 0.2,
            flickerDistance: 5,
            directionalDot: 0,
            flags: 16,
            timebits: UInt32.max,
            angle: 0,
            lightingRenderType: 0
        ),
        particles: .init(
            count: 25,
            lifetime: 0.3,
            size: 0.2,
            frames: fixtureYellowSparkFrames
        ),
        spawn: .init(
            weapon: "YellowFlareSparks",
            count: 9,
            alternateWeapon: "",
            alternateChance: 0
        )
    )
}

/// The retail "YellowFlareSparks" page (WF_IMAGE_VCLIP | WF_SATURATE;
/// PF_GRAVITY | PF_NO_COLLIDE | PF_NO_ROBOT_COLLISIONS |
/// PF_POINT_COLLIDE_WALLS | PF_IGNORE_CONCUSSIVE_FORCES): a 0.2 s vclip
/// spark that falls with drag 0.1, drops its own sparks, and casts a light
/// of 6.
func fixtureYellowFlareSparks() -> CanonicalWeapon {
    CanonicalWeapon(
        name: "YellowFlareSparks",
        flags: 1_056,
        model: nil,
        size: 0.2,
        customSize: 0,
        mass: 0.1,
        drag: 0.1,
        physicsFlags: 2_556_032,
        speed: 17,
        fullThrust: 0,
        lifetime: 0.2,
        playerDamage: 0,
        genericDamage: 0,
        sounds: Array(repeating: "", count: 7),
        impact: .init(
            size: 0, time: 0, playerDamage: 0, genericDamage: 0, force: 0
        ),
        explosion: .init(
            hasImage: true,
            frames: fixtureYellowSparkFrames,
            lifetime: 0.2,
            size: 0.07
        ),
        lightDistance: 6,
        lighting: .init(
            primaryColor: .init(x: 1, y: 1, z: 0.5),
            secondaryColor: .zero,
            timeInterval: 0,
            flickerDistance: 0,
            directionalDot: 0,
            flags: 0,
            timebits: 0,
            angle: 0,
            lightingRenderType: 0
        ),
        fireImage: .init(frames: fixtureYellowSparkFrames, frameTime: 0.07),
        particles: .init(
            count: 25,
            lifetime: 0.3,
            size: 0.3,
            frames: fixtureYellowSparkFrames
        )
    )
}

/// The ship's flare battery (FLARE_INDEX): gun point 0 fires one Yellow
/// flare each second, with the Flare sound, for no energy.
let fixtureFlareShipBattery = CanonicalShipWeaponBattery(
    index: PlayerWeaponState.flareIndex,
    battery: .init(
        gunpointWeapons: ["Yellow flare", "", ""],
        fireMasks: [1],
        fireWaits: [1],
        fireSounds: ["Flare"],
        aimingGunpointIndex: 0,
        aimingFlags: 0,
        aiming3DDot: 0,
        aiming3DDistance: 0,
        aimingXZDot: 0,
        flags: 0,
        quadFireMask: 0
    ),
    energyUsage: 0,
    ammoUsage: 0,
    fireFlags: 0
)

extension Level {
    /// This level with the Yellow flare and its sparks: the flare model,
    /// the spark and FlarePuff textures, the Flare sound, both weapons, and
    /// the ship's flare battery. The level already has the player's
    /// weapons and the ship model's guns (`addingFixturePlayerWeapons`).
    func addingFixtureYellowFlare() -> Level {
        var level = self
        let templateModel = level.models.first {
            $0.source.sourceName.caseInsensitiveCompare("Buddybot.oof")
                == .orderedSame
        } ?? level.models[0]
        let nextModelIndex = (
            level.models.map(\.source.storedIndex)
                + level.dependencyManifest.current
                    .filter { $0.category == "model" }
                    .map(\.source.storedIndex)
        ).max().map { $0 + 1 } ?? 0
        let modelSource = SourceResource(
            storedIndex: nextModelIndex,
            sourceName: "FlareYellowBright.OOF"
        )
        let flareModel = CanonicalModel(
            source: modelSource,
            collisionRadius: Float(bitPattern: 0x405f_d5ea),
            submodels: templateModel.submodels,
            bounds: templateModel.bounds,
            sourceArchive: templateModel.sourceArchive,
            sourceSHA256: String(repeating: "f", count: 64)
        )
        let templateMaterial = level.presentationMaterials[0]
        let sparkMaterials = fixtureYellowSparkFrames.map { frame in
            PresentationMaterial(
                texture: frame,
                bitmapSourceName: "yellowspark.oaf",
                image: templateMaterial.image,
                blend: .additiveSourceAlpha(opacity: 255),
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: templateMaterial.sourceArchive,
                sourceSHA256: String(repeating: "e", count: 64)
            )
        }
        let explosionTexture = SourceResource(
            storedIndex: 900,
            sourceName: "FlarePuff"
        )
        let explosionMaterial = PresentationMaterial(
            texture: explosionTexture,
            bitmapSourceName: "FlarePuff.oaf",
            image: templateMaterial.image,
            blend: .additiveSourceAlpha(opacity: 102),
            lightmapBlend: .none,
            waterProcedural: nil,
            sourceArchive: templateMaterial.sourceArchive,
            sourceSHA256: String(repeating: "d", count: 64)
        )
        var soundClips = level.soundClips
        if !soundClips.contains(where: { $0.logicalName == "Flare" }) {
            let pcm = Data(repeating: 0, count: 2)
            soundClips.append(.init(
                logicalName: "Flare",
                sourceName: "Flare.wav",
                sourceEntryIndex: 1_158,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: templateModel.sourceArchive,
                sourceSHA256: String(repeating: "f", count: 64),
                importVolume: 0.300_000_07
            ))
        }
        let addedSounds = soundClips.dropFirst(level.soundClips.count)
        let dependencies = [
            DependencyRecord(
                category: "model",
                source: modelSource,
                state: "presentation-payload-imported",
                provenance: "synthetic Yellow flare fixture"
            ),
        ] + (fixtureYellowSparkFrames + [explosionTexture]).map {
            DependencyRecord(
                category: "texture",
                source: $0,
                state: "presentation-payload-imported",
                provenance: "synthetic Yellow flare fixture"
            )
        } + addedSounds.map {
            DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: $0.sourceEntryIndex,
                    sourceName: $0.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance: "synthetic Yellow flare fixture"
            )
        }
        var ship = level.shipDefinitions[0]
        ship.weaponBatteries = (ship.weaponBatteries ?? []).filter {
            $0.index != PlayerWeaponState.flareIndex
        } + [fixtureFlareShipBattery]
        level = replacing(
            level,
            presentationMaterials: level.presentationMaterials
                + sparkMaterials + [explosionMaterial],
            models: level.models + [flareModel],
            shipDefinitions: [ship],
            soundClips: soundClips,
            dependencyManifest: .init(
                current: level.dependencyManifest.current + dependencies,
                historicalEagerBaseline:
                    level.dependencyManifest.historicalEagerBaseline
            )
        )
        return level
            .addingWeapon(fixtureYellowFlare(
                model: modelSource,
                explosion: explosionTexture
            ))
            .addingWeapon(fixtureYellowFlareSparks())
    }
}
