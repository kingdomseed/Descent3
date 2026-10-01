import XCTest

// Synthetic object and weapon tables for the fixtures. The values follow
// the page fields D3Import reads (manage/generic.cpp:1083,
// manage/weaponpage.cpp:782); no retail bytes are stored.

/// A light_info with no light.
let fixtureNoLight = ObjectLightPresentation(
    primaryColor: .zero, secondaryColor: .zero, timeInterval: 0,
    flickerDistance: 0, directionalDot: 0, flags: 0, timebits: 0, angle: 0,
    lightingRenderType: 0
)

/// An AI page with every field zero but the given ones.
func fixtureAIInfo(
    flags: UInt32, aiType: UInt8, movementType: UInt8, fov: Float,
    maxVelocity: Float = 0, maxDeltaVelocity: Float = 0, maxTurnRate: Float = 0,
    maxDeltaTurnRate: Float = 0, notifyFlags: UInt32, circleDistance: Float = 0,
    leadAccuracy: Float = 1, fireSpread: Float = 0, aggression: Float = 0.5,
    lifePreservation: Float = 0, attackVelocityPercent: Float = 1,
    dodgeVelocityPercent: Float = 1, fleeVelocityPercent: Float = 1
) -> CanonicalAIInfo {
    CanonicalAIInfo(
        flags: flags, aiClass: 0, aiType: aiType, movementType: movementType,
        movementSubtype: 0, fov: fov, maxVelocity: maxVelocity,
        maxDeltaVelocity: maxDeltaVelocity, maxTurnRate: maxTurnRate,
        notifyFlags: notifyFlags | aiNotifiesAlwaysOn,
        maxDeltaTurnRate: maxDeltaTurnRate, circleDistance: circleDistance,
        attackVelocityPercent: attackVelocityPercent, dodgePercent: 0,
        dodgeVelocityPercent: dodgeVelocityPercent,
        fleeVelocityPercent: fleeVelocityPercent, meleeDamage: [0, 0],
        meleeLatency: [0, 0], curiosity: 0.5, nightVision: 0.68,
        fogVision: 0.68, leadAccuracy: leadAccuracy, leadVariance: 0,
        fireSpread: fireSpread, fightTeam: 0, fightSame: 0,
        aggression: aggression, hearing: 1, frustration: 0.5, roaming: 0,
        lifePreservation: lifePreservation, avoidFriendsDistance: 4,
        biasedFlightImportance: 0.5, biasedFlightMinimum: 10,
        biasedFlightMaximum: 50
    )
}

/// A stationary turret page like Training's Hangturret: AIT_STATIONARY_TURRET,
/// AIF_FIRE | AIF_DETERMINE_TARGET | AIF_AIM | AIF_TARGET_BY_DIST |
/// AIF_UVEC_FOV, a -1 field of view, lead accuracy 0.81, and one battery
/// firing gun points 0 and 1 in turn, once a second.
let fixtureTurretInfo = CanonicalObjectInfo(
    name: "Hangturret",
    type: 2,
    flags: 0x5,
    size: 5.402_855_4,
    hitPoints: 35,
    lightDistance: 0,
    lighting: fixtureNoLight,
    ai: fixtureAIInfo(
        flags: 0x4040_0d01, aiType: 4, movementType: 0, fov: -1,
        notifyFlags: 0x1150, leadAccuracy: 0.81, attackVelocityPercent: 0,
        dodgeVelocityPercent: 0, fleeVelocityPercent: 0
    ),
    weaponBatteries: [
        .init(
            gunpointWeapons: ["Laser Level 1 - Red", "Laser Level 1 - Red", ""],
            fireMasks: [1, 2], fireWaits: [1, 1],
            fireSounds: ["WpmLaserBlueFire", "WpmLaserBlueFire"],
            aimingGunpointIndex: 2, aimingFlags: 0, aiming3DDot: 0.9,
            aiming3DDistance: 1_000, aimingXZDot: 0.9, flags: 0, quadFireMask: 0
        ),
    ]
)

/// A flying robot page like the RAS1 Light Security Flyer: AIT_EVADER1,
/// MC_FLYING, uses physics, and AIF_FLUCTUATE_SPEED_PROPERTIES among its
/// flags.
let fixtureFlyerInfo = CanonicalObjectInfo(
    name: "RAS1 Light Security Flyer",
    type: 2,
    flags: 0x207,
    size: 4.576_441_8,
    hitPoints: 55,
    lightDistance: 0,
    lighting: fixtureNoLight,
    ai: fixtureAIInfo(
        flags: 0x0200_8f80, aiType: 2, movementType: 1, fov: 0, maxVelocity: 40,
        maxDeltaVelocity: 80, maxTurnRate: 12_000, maxDeltaTurnRate: 16_000,
        notifyFlags: 0x5150, circleDistance: 25, fireSpread: 0.05,
        lifePreservation: 0.21, dodgeVelocityPercent: 0.9
    ),
    weaponBatteries: [],
    score: 200,
    impact: .init(size: 0, time: 0, damage: 0),
    deathTypes: fixtureFlyerDeathTypes
)

/// A flashing light clutter page like Blinking Red Light-DM.
let fixtureFlashLightInfo = CanonicalObjectInfo(
    name: "Blinking Red Light-DM",
    type: 11,
    flags: 0,
    size: 3.611_371_3,
    hitPoints: 100,
    lightDistance: 60,
    lighting: .init(
        primaryColor: .init(x: 1, y: 0.25, z: 0), secondaryColor: .zero,
        timeInterval: 0.5, flickerDistance: 0.2, directionalDot: 0, flags: 4,
        timebits: .max, angle: 0, lightingRenderType: 2
    ),
    ai: nil,
    weaponBatteries: []
)

/// A red laser like Laser Level 1 - Red: 200 units per second, 5 s of life,
/// 6.75 player damage, a custom size of 0.5, and a wall impact sound.
func fixtureRedLaser(model: SourceResource) -> CanonicalWeapon {
    CanonicalWeapon(
        name: "Laser Level 1 - Red", flags: 0x8002_0000, model: model,
        size: 3.862_672, customSize: 0.5, mass: 0.1, drag: 0.1,
        physicsFlags: 0x20_1800, speed: 200, fullThrust: 0, lifetime: 5,
        playerDamage: 6.75, genericDamage: 6.75,
        sounds: ["", "LazorHitshrt", "", "", "", "", ""]
    )
}

/// The turret model's gun points (on submodel 2) and its one battery with
/// turrets 1 and 2.
let fixtureTurretGunpoints = [
    ModelGunpoint(
        parent: 2,
        position: .init(x: 1.706_505_8, y: -2.224_015_2, z: 2.190_463_5),
        normal: .init(x: 0, y: -0.707_105_7, z: 0.707_107_84)
    ),
    ModelGunpoint(
        parent: 2,
        position: .init(x: 0.457_947_73, y: -2.224_015_2, z: 2.190_463_5),
        normal: .init(x: 0, y: -0.707_105_7, z: 0.707_107_84)
    ),
    ModelGunpoint(
        parent: 2,
        position: .init(x: 1.085_584_6, y: -2.224_015_2, z: 2.190_463_5),
        normal: .init(x: 0, y: -0.707_105_7, z: 0.707_107_84)
    ),
]
let fixtureTurretBatteries = [
    ModelWeaponBattery(gunpoints: [0, 1, 2], turrets: [1, 2]),
]

extension Level {
    /// This level with `info` in its object tables, replacing a page of the
    /// same name.
    func addingObjectInfo(_ info: CanonicalObjectInfo) -> Level {
        var level = self
        var infos = (objectInfos ?? []).filter {
            $0.name.caseInsensitiveCompare(info.name) != .orderedSame
        }
        infos.append(info)
        level.objectInfos = infos
        return level
    }

    /// This level with `weapon` in its weapon table.
    func addingWeapon(_ weapon: CanonicalWeapon) -> Level {
        var level = self
        level.weapons = (weapons ?? []).filter {
            $0.name.caseInsensitiveCompare(weapon.name) != .orderedSame
        } + [weapon]
        return level
    }

    /// This level with the model's gun points and batteries set.
    func settingModelGuns(
        _ source: SourceResource, gunpoints: [ModelGunpoint],
        batteries: [ModelWeaponBattery]
    ) -> Level {
        var level = self
        level.models = models.map { model in
            guard model.source == source else { return model }
            var model = model
            model.gunpoints = gunpoints
            model.weaponBatteries = batteries
            return model
        }
        return level
    }
}

/// The path of the object's first used follow-path goal, or nil.
func activeFollowPath(_ world: GameWorld, _ handle: UInt32) -> Int? {
    world.objects[ObjectHandle(handle)]?.ai?.goals.first {
        $0.used && $0.type == AIGoal.followPathType
    }?.pathID
}
