import XCTest

/// The Training yellow flare level (makeTrainingGuidebotYellowFlareLevel),
/// whose ship fires the flare from its FLARE_INDEX battery.
func makePlayerYellowFlareLevel() throws -> Level {
    makeTrainingGuidebotYellowFlareLevel()
}

/// The Training yellow flare level with the player's laser and Concussion
/// (WeaponFixtures.swift), with their sounds.
func makePlayerConcussionLevel() throws -> Level {
    try makePlayerYellowFlareLevel()
        .addingFixturePlayerWeapons(concussionSounds: true)
}

func makeSliceTenContactLevel(clearance: Float = 20) -> Level {
    let level = makeSliceSixObjectRenderLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let contactRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = contactRoom
    return replacing(level, rooms: rooms)
}

func makeSliceThirteenWiggleLevel(blocked: Bool = false) -> Level {
    let base = makeSliceSixObjectRenderLevel()
    let radius = defaultPlayerView(in: base).collisionRadius
    let level = blocked
        ? makeSliceTenContactLevel(clearance: radius + 0.01)
        : base
    var objects = level.objects
    let playerIndex = objects.firstIndex { $0.handle == 2_048 }!
    objects[playerIndex].orientation = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 0, z: 1),
        forward: .init(x: 0, y: -1, z: 0)
    )
    return replacing(level, objects: objects)
}

func makeSliceThirteenPortalWiggleLevel() -> Level {
    let level = makeSliceThirteenWiggleLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + 0.04
    let portalVertices = [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let corners = (0..<4).map {
        FaceCorner(
            vertexIndex: firstVertex + $0,
            u: 0,
            v: 0,
            alpha: 255
        )
    }
    let portalFace = LevelFace(
        corners: corners,
        flags: 0,
        portalIndex: room.portals.count,
        texture: room.faces[0].texture
    )
    let sourceRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + portalVertices,
        faces: room.faces + [portalFace],
        portals: room.portals + [
            .init(
                faceIndex: room.faces.count,
                connectedRoom: 99,
                connectedPortal: 0
            ),
        ],
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    let connectedRoom = LevelRoom(
        sourceIndex: 99,
        vertices: portalVertices,
        faces: [
            .init(
                corners: corners.reversed().map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex - firstVertex,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: room.faces[0].texture
            ),
        ],
        portals: [
            .init(faceIndex: 0, connectedRoom: 1, connectedPortal: room.portals.count),
        ]
    )
    var rooms = level.rooms
    rooms[roomIndex] = sourceRoom
    rooms.append(connectedRoom)
    return replacing(level, rooms: rooms)
}

func makeSliceElevenCornerLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let x = player.position.x + clearance
    let vertices = room.vertices + [
        Vector3(x: x, y: player.position.y - 20, z: player.position.z - 20),
        Vector3(x: x, y: player.position.y - 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z - 20),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let cornerRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = cornerRoom
    return replacing(level, rooms: rooms)
}

func makeSliceElevenForceFieldLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let texture = level.rooms.first { $0.sourceIndex == 1 }!.faces.last!.texture
    return replacing(
        level,
        surfacePhysics: level.surfacePhysics.map {
            $0.texture == texture
                ? .init(texture: $0.texture, behavior: .forceField)
                : $0
        }
    )
}

func makeSliceElevenTrappedLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z - clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let trappedRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = trappedRoom
    return replacing(level, rooms: rooms)
}

/// Decodes a `GameWorld` JSON object for a test. The optional keys
/// `playerLocation`, `playerPosition`, and `playerOrientation` place the
/// player object, so a test can start a saved world with the player anywhere.
func decodeTestWorld(_ object: [String: Any]) throws -> GameWorld {
    var object = object
    let placement = [
        ("playerLocation", "location"),
        ("playerPosition", "position"),
        ("playerOrientation", "orientation"),
    ]
    if placement.contains(where: { object[$0.0] != nil }) {
        var objects = try XCTUnwrap(object["objects"] as? [String: Any])
        var slots = try XCTUnwrap(objects["slots"] as? [Any])
        let playerSlot = try XCTUnwrap(slots.firstIndex {
            ($0 as? [String: Any])?["type"] as? Int
                == Int(ObjectType.player.rawValue)
        })
        var player = try XCTUnwrap(slots[playerSlot] as? [String: Any])
        for (key, field) in placement {
            if let value = object.removeValue(forKey: key) {
                player[field] = value
            }
        }
        slots[playerSlot] = player
        objects["slots"] = slots
        object["objects"] = objects
    }
    return try JSONDecoder().decode(
        GameWorld.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
}

extension GameWorld {
    /// The single player object of a Training test world.
    var testPlayerObject: GameObject {
        objects.first { $0.type == .player }!
    }
    var playerLocation: SpatialLocation { testPlayerObject.location }
    var playerPosition: Vector3 { testPlayerObject.position }
    var playerOrientation: Matrix3 { testPlayerObject.orientation }
}

extension GameSession {
    /// The canonical level with this session's world applied: current object
    /// placement (deleted objects dropped), render types, portal flags, and
    /// goals. Tests read runtime state through it; the runtime never does.
    var runtimeLevel: Level {
        var composed = level
        composed.objects = level.objects.compactMap { placed in
            guard let object = world.objects[ObjectHandle(placed.handle)] else {
                return nil
            }
            var placed = placed
            placed.location = object.location
            placed.position = object.position
            placed.orientation = object.orientation
            return placed
        }
        for roomIndex in composed.rooms.indices {
            for portalIndex in composed.rooms[roomIndex].portals.indices {
                composed.rooms[roomIndex].portals[portalIndex].flags =
                    world.rooms[roomIndex].portalFlags[portalIndex]
            }
        }
        composed.objectPresentations = level.objectPresentations.map {
            ObjectPresentationReference(
                objectHandle: $0.objectHandle,
                primaryModel: $0.primaryModel,
                mediumModel: $0.mediumModel,
                lowModel: $0.lowModel,
                dyingModel: $0.dyingModel,
                mediumDistance: $0.mediumDistance,
                lowDistance: $0.lowDistance,
                isVisible: world.objects[ObjectHandle($0.objectHandle)]?
                    .renderType == .polyobj
            )
        }
        composed.goals = world.goals
        return composed
    }
}

extension GameWorld {
    /// A saved Training world restored into a test level whose placement or
    /// goals a test edited (for example a goal moved into contact). Static
    /// objects take the level's placement. The player, the Guide-Bot, and
    /// the AI objects, whose motion the runtime owns, keep the saved
    /// placement. Deleted objects stay deleted.
    func rebased(onto level: Level) -> GameWorld {
        var world = self
        let moving = Set([
            level.defaultPlayerBinding?.objectHandle,
            level.trainingRobotGuidebotChain?.guidebotObjectHandle,
        ].compactMap { $0 })
        for placed in level.objects where !moving.contains(placed.handle) {
            let handle = ObjectHandle(placed.handle)
            guard var object = world.objects[handle], object.ai == nil
            else { continue }
            object.location = placed.location
            object.position = placed.position
            object.orientation = placed.orientation
            world.objects[handle] = object
        }
        // Goals are level data a test may edit; the saved completion stays
        // when the goals keep their shape.
        if world.goals.count != level.goals.count {
            world.goals = level.goals
        }
        return world
    }
}

/// Encodes a `GameWorld` as a JSON object for a test to edit. It adds the
/// player object's placement as `playerLocation`, `playerPosition`, and
/// `playerOrientation`, which `decodeTestWorld` reads back.
func testWorldObject(_ world: GameWorld) throws -> [String: Any]? {
    guard var object = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(world)
    ) as? [String: Any] else {
        return nil
    }
    let player = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(world.testPlayerObject)
    ) as? [String: Any]
    object["playerLocation"] = player?["location"]
    object["playerPosition"] = player?["position"]
    object["playerOrientation"] = player?["orientation"]
    return object
}
