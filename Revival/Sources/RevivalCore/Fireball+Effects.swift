// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/fireball.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the effects of a death, in the
// order DestroyObject (:1344) and DoDyingFrame (:1428) make them, with all
// their object allocations and ps_rand draws: CreateSubobjectDebrisDirected
// (:893) and CreateSubobjectDebris (:958), CreateExtraFireballs (:971),
// BreakApartModel (:1033), CreateSplintersFromBody (:1044), DoDeathSpew
// (:1134), CreateObjectFireball (:1197), DoDebrisFrame (:1207),
// CreateElectricalBolts (:1249), PlayObjectExplosionSound (:1294),
// CreateDeadObject (:1316), DoExplosionFrame (:1710), CreateBlueBlastRing
// (:1934), CreateBlastRing (:1972), and CreateObjectBlastRing (:2012); with
// DoSplinterFrame (Descent3/splinter.cpp:74), ObjInitGeneric's first draw
// (Descent3/ObjInit.cpp:728), and SetFallingPhysics and SetFlyingPhysics
// (Descent3/damage.cpp:1086, :1121).
//
// What is deferred is presentation: sounds (the static sound table, M2),
// the screen flash and shake, and drawing debris, splinters, rings, and
// the fireball, spark, smoke, and lightning effects the renderer does not
// draw yet. Debris smoke uses the C library's rand(), not ps_rand, so its
// smoke puffs are not made (architecture.md section 9).

import Foundation

extension GameWorld {
    /// DAMAGE_RING_TIME (fireball.h:176).
    static let damageRingTime: Float = 1.5
    /// DEBRIS_LIFE (fireball.h:161).
    private static let debrisLife: Float = 2
    /// MAX_SPLINTERS_PER_OBJECT (fireball.cpp:1041).
    private static let maximumSplinters = 10
    /// ELECTRICAL_DEATH_TIME (fireball.cpp:1426).
    private static let electricalDeathTime: Float = 3

    /// The polygon model an object draws: its own model (debris, a dying
    /// model), the ship, or its placed presentation.
    func objectModel(_ object: GameObject, level: Level) -> CanonicalModel? {
        if let source = object.model {
            return level.models.first { $0.source == source }
        }
        return level.polygonModel(of: object)
    }

    // MARK: Fireballs and rings

    /// CreateObjectFireball (fireball.cpp:1197): an explosion picked by the
    /// explosion's size, twice as big as that size.
    @discardableResult
    mutating func createObjectFireball(
        _ handle: ObjectHandle,
        sizeScale: Float = 1,
        level: Level
    ) -> Int? {
        guard let object = objects[handle],
              case let .room(room) = object.location
        else {
            return nil
        }
        let id = randomExplosion(size: object.size * sizeScale)
        guard let index = createFireball(
            position: object.position,
            id: id,
            roomSourceIndex: room,
            level: level
        ) else {
            return nil
        }
        visEffects[index].size = object.size * sizeScale * 2
        return index
    }

    /// CreateExtraFireballs (fireball.cpp:971) indoors: 0 to 3 extra
    /// explosions (plus one per 15 units of size), sparks, and the
    /// explosions as events 0.3 to 0.8 s later.
    mutating func createExtraFireballs(
        _ handle: ObjectHandle,
        sizeScale: Float,
        level: Level
    ) {
        guard let object = objects[handle],
              case let .room(room) = object.location
        else {
            return
        }
        let explosionSize = object.size * sizeScale
        let sizeAdd = Int(explosionSize / 15)
        let extras = min(12, sizeAdd + Int(psRand() % 4))
        createRandomSparks(
            extras,
            position: object.position,
            roomSourceIndex: room,
            level: level
        )
        func offset(_ draw: Int32) -> Float {
            (Float(draw % 100) / 50 - 1) * (object.size / 2)
        }
        for _ in 0..<extras {
            let dx = offset(psRand())
            let dy = offset(psRand())
            let dz = offset(psRand())
            let position = object.position + Vector3(x: dx, y: dy, z: dz)
            let addTime = Float(0.3 + Double(psRand() % 100) / 200)
            let id: UInt8
            if sizeAdd > 0 {
                id = psRand() % 2 != 0
                    ? VisEffect.bigExplosionID : randomMediumExplosion()
            } else {
                id = randomMediumExplosion()
            }
            createNewEvent(
                length: addTime,
                action: .explosion(
                    position: position,
                    fireballID: id,
                    roomSourceIndex: room,
                    size: explosionSize,
                    upwardsVelocity: 0
                )
            )
        }
    }

    /// CreateObjectBlastRing (fireball.cpp:2012) indoors.
    @discardableResult
    mutating func createObjectBlastRing(
        _ handle: ObjectHandle,
        level: Level
    ) -> ObjectHandle? {
        guard let object = objects[handle],
              case let .room(room) = object.location
        else {
            return nil
        }
        return createBlastRing(
            position: object.position,
            id: VisEffect.blastRingID,
            lifetime: Self.damageRingTime,
            maximumSize: object.size,
            roomSourceIndex: room,
            level: level
        )
    }

    /// The viewer object (Viewer_object): the player in single player.
    private func viewerObject(level: Level) -> GameObject? {
        level.defaultPlayerBinding.flatMap {
            objects[ObjectHandle($0.objectHandle)]
        }
    }

    /// ObjCreate of an OBJ_FIREBALL with ObjInitFireball (ObjInit.cpp:1034):
    /// CT_EXPLOSION, the Fireballs[] size and life.
    private mutating func createFireballObject(
        id: UInt8,
        roomSourceIndex: Int,
        position: Vector3
    ) -> ObjectHandle? {
        guard let created = objects.create(
            type: .fireball,
            renderType: .none,
            location: .room(roomSourceIndex),
            position: position,
            orientation: .identity
        ) else {
            return nil
        }
        let table = VisEffect.table(id: id)
        objects[created]?.creationTime = gameTime
        objects[created]?.size = table.size
        objects[created]?.lifeLeft = table.life
        objects[created]?.fireball = FireballObjectInfo(
            id: id,
            maximumSize: 0,
            lifetime: table.life
        )
        return created
    }

    /// CreateBlastRing (fireball.cpp:1972). The flash it draws when the
    /// viewer can see the spot is a render event.
    @discardableResult
    mutating func createBlastRing(
        position: Vector3,
        id: UInt8,
        lifetime: Float,
        maximumSize: Float,
        roomSourceIndex: Int,
        forceBlue: Bool = false,
        level: Level
    ) -> ObjectHandle? {
        guard viewerObject(level: level) != nil,
              let ring = createFireballObject(
                  id: id,
                  roomSourceIndex: roomSourceIndex,
                  position: position
              )
        else {
            return nil
        }
        objects[ring]?.size = maximumSize
        objects[ring]?.lifeLeft = lifetime
        objects[ring]?.fireball = FireballObjectInfo(
            id: id,
            maximumSize: maximumSize,
            lifetime: lifetime
        )
        if psRand() % 2 != 0 {
            objects[ring]?.orientation = .identity
            if psRand() % 3 == 0 || forceBlue {
                createBlueBlastRing(
                    position: position,
                    id: id,
                    lifetime: lifetime,
                    maximumSize: maximumSize,
                    roomSourceIndex: roomSourceIndex,
                    ring: nil,
                    forceUp: forceBlue,
                    level: level
                )
            }
        } else {
            createBlueBlastRing(
                position: position,
                id: id,
                lifetime: lifetime,
                maximumSize: maximumSize,
                roomSourceIndex: roomSourceIndex,
                ring: ring,
                forceUp: forceBlue,
                level: level
            )
        }
        return ring
    }

    /// CreateBlueBlastRing (fireball.cpp:1934): a new ring, or `ring`,
    /// pointing up or at the viewer, for half the lifetime.
    private mutating func createBlueBlastRing(
        position: Vector3,
        id: UInt8,
        lifetime: Float,
        maximumSize: Float,
        roomSourceIndex: Int,
        ring: ObjectHandle?,
        forceUp: Bool,
        level: Level
    ) {
        guard let viewer = viewerObject(level: level) else { return }
        var handle = ring
        if handle == nil {
            guard let created = createFireballObject(
                id: id,
                roomSourceIndex: roomSourceIndex,
                position: position
            ) else {
                return
            }
            objects[created]?.size = 1
            objects[created]?.fireball?.maximumSize = maximumSize
            handle = created
        }
        guard let handle else { return }
        if psRand() % 2 != 0 || forceUp {
            objects[handle]?.orientation = Matrix3(
                right: Vector3(x: 1, y: 0, z: 0),
                up: Vector3(x: 0, y: 0, z: -1),
                forward: Vector3(x: 0, y: 1, z: 0)
            )
        } else {
            let toViewer = viewer.position - position
            let facing = toViewer == .zero
                ? toViewer : sourceVectorNormalized(toViewer)
            if sqrt(dot(facing, facing)) < 0.5 { return }
            objects[handle]?.orientation = sourceVectorToMatrix(
                forward: facing,
                up: .zero
            )
        }
        objects[handle]?.lifeLeft = lifetime / 2
        objects[handle]?.fireball?.lifetime = lifetime / 2
    }

    // MARK: Sound, spew, and remains

    /// PlayObjectExplosionSound (fireball.cpp:1294): a generic object whose
    /// page has no explode sound, other than a building, picks one of the
    /// two robot explosion sounds with a draw.
    mutating func playObjectExplosionSound(
        _ object: GameObject,
        level: Level
    ) {
        guard object.type != .door else { return }
        let info = object.info.flatMap { level.objectInfos?[$0] }
        if let sound = info?.explodeSound, !sound.isEmpty {
            play3DSound(sound)
            return
        }
        if object.type != .building {
            // SOUND_ROBOT_EXPLODE_1 or _2 (static sounds, M2).
            _ = psRand() > GameWorld.randMax / 2
        }
    }

    /// DoDeathSpew (fireball.cpp:1134) in single player: each spew type
    /// draws once per possible object, and each object spewed is made
    /// (ObjInitGeneric draws first) and thrown with three more draws. A
    /// spew the object table cannot hold ends the spew.
    mutating func doDeathSpew(_ handle: ObjectHandle, level: Level) {
        guard let parent = objects[handle],
              case let .room(room) = parent.location,
              let infoIndex = parent.info,
              let spew = level.objectInfos?[infoIndex].deathSpew
        else {
            return
        }
        var countOfLastType = 0
        for (index, entry) in spew.entries.enumerated() {
            guard let spewedIndex = level.objectInfos?.firstIndex(where: {
                $0.name.caseInsensitiveCompare(entry.pageName) == .orderedSame
            }), let spewed = level.objectInfos?[spewedIndex] else {
                continue
            }
            // DSF_ONLY_IF_PLAYER_HAS_OBJ_1 compares the ship's spew
            // powerups, which are not imported (architecture.md section 9).
            if index == 1,
               spew.flags & CanonicalDeathSpew.onlyIfNoFirstFlag != 0,
               countOfLastType != 0 {
                continue
            }
            countOfLastType = 0
            let threshold = Int32(Float(GameWorld.randMax) * entry.percent)
            for _ in 0..<entry.number where psRand() <= threshold {
                countOfLastType += 1
                guard let created = createGenericObject(
                    infoIndex: spewedIndex,
                    info: spewed,
                    roomSourceIndex: room,
                    position: parent.position,
                    orientation: .identity,
                    level: level
                ) else {
                    return
                }
                func throwSpeed(_ draw: Int32) -> Float {
                    (Float(draw) / Float(GameWorld.randMax) - 0.5) * 35
                }
                let vx = throwSpeed(psRand())
                let vz = throwSpeed(psRand())
                let vy = throwSpeed(psRand())
                objects[created]?.velocity = Vector3(x: vx, y: vy, z: vz)
                initObjectScripts(created, level: level)
            }
        }
    }

    /// ObjCreate of a generic object at run time: ObjInitGeneric
    /// (ObjInit.cpp:718) draws first (:728), then sets the page's values.
    /// A page with a polymodel makes a polygon object of the model's size
    /// (ObjSetRenderPolyobj and PageInPolymodel, :779-789).
    mutating func createGenericObject(
        infoIndex: Int,
        info: CanonicalObjectInfo,
        roomSourceIndex: Int,
        position: Vector3,
        orientation: Matrix3,
        level: Level
    ) -> ObjectHandle? {
        guard let type = ObjectType(rawValue: info.type),
              let created = objects.create(
                  type: type,
                  renderType: .none,
                  location: .room(roomSourceIndex),
                  position: position,
                  orientation: orientation
              )
        else {
            return nil
        }
        _ = psRand()
        guard var object = objects[created] else { return nil }
        object.creationTime = gameTime
        let model = info.presentation.flatMap { page in
            level.models.first { $0.source == page.primaryModel }
        }
        if model != nil {
            object.renderType = .polyobj
        }
        object = Self.initialGenericObject(
            object,
            info: info,
            infoIndex: infoIndex,
            model: model
        )
        if let physics = info.physics,
           info.flags & CanonicalObjectInfo.usesPhysicsFlag != 0 {
            object.physics = physics
        }
        objects[created] = object
        return created
    }

    /// InitObjectScripts (ObjScript.cpp) for an object made at run time:
    /// its scripts are bound, a CT_AI object hears EVT_AI_INIT, and it
    /// hears EVT_CREATED.
    mutating func initObjectScripts(_ handle: ObjectHandle, level: Level) {
        osirisBindScriptsToObject(handle, level: level)
        if objects[handle]?.ai != nil {
            osirisCallEvent(handle, .aiInit, level: level)
        }
        osirisCallEvent(handle, .created, level: level)
    }

    /// CreateDeadObject (fireball.cpp:1316): the robots with a dead model
    /// page leave that object behind. The ground point needs the model's
    /// ground slots, which are not imported; the dead object takes the
    /// robot's position (architecture.md section 9).
    mutating func createDeadObject(_ handle: ObjectHandle, level: Level) {
        let deadObjectTypes = [
            ("swatter", "swatter(deadmodel)"),
            ("Hangturret", "Securityturret(DEAD)"),
            ("Lance", "Lance(DEAD)"),
            ("L10 swatter", "swatter(deadmodel)"),
        ]
        guard let object = objects[handle],
              object.type == .robot,
              case let .room(room) = object.location,
              let name = object.info.flatMap({ level.objectInfos?[$0].name })
        else {
            return
        }
        for (living, dead) in deadObjectTypes
        where living.caseInsensitiveCompare(name) == .orderedSame {
            if let deadIndex = level.objectInfos?.firstIndex(where: {
                $0.name.caseInsensitiveCompare(dead) == .orderedSame
            }), let info = level.objectInfos?[deadIndex],
               let created = createGenericObject(
                   infoIndex: deadIndex,
                   info: info,
                   roomSourceIndex: room,
                   position: object.position,
                   orientation: object.orientation,
                   level: level
               ) {
                initObjectScripts(created, level: level)
            }
            return
        }
    }

    // MARK: Debris and splinters

    /// BreakApartModel (fireball.cpp:1033): each submodel past the first
    /// flies off as debris.
    mutating func breakApartModel(
        _ handle: ObjectHandle,
        explosionMagnitude: Float,
        deathFlags: UInt32,
        level: Level
    ) {
        guard let object = objects[handle],
              let model = objectModel(object, level: level),
              model.submodels.count > 1
        else {
            return
        }
        for index in 1..<model.submodels.count {
            createSubobjectDebris(
                handle,
                submodel: index,
                model: model,
                explosionMagnitude: explosionMagnitude,
                deathFlags: deathFlags,
                level: level
            )
        }
        let bodyRadius = submodelRadius(model.submodels[0])
        objects[handle]?.size = bodyRadius
    }

    /// A submodel's `rad`: imported from its SOBJ chunk, or, for a synthetic
    /// model without it, its farthest vertex.
    private func submodelRadius(_ submodel: ModelSubmodel) -> Float {
        if let radius = submodel.radius { return radius }
        return submodel.vertices.map {
            sqrt(dot($0.position, $0.position))
        }.max() ?? 0
    }

    /// CreateSubobjectDebris (fireball.cpp:958) and
    /// CreateSubobjectDebrisDirected (:893).
    private mutating func createSubobjectDebris(
        _ parentHandle: ObjectHandle,
        submodel: Int,
        model: CanonicalModel,
        explosionMagnitude: Float,
        deathFlags: UInt32,
        level: Level
    ) {
        let half = Float(GameWorld.randMax / 2)
        var direction = Vector3(
            x: half - Float(psRand()),
            y: half - Float(psRand()) + 0.2 * Float(GameWorld.randMax),
            z: half - Float(psRand())
        )
        direction = direction == .zero
            ? direction : sourceVectorNormalized(direction)
        let magnitude = explosionMagnitude
            * (1 + (half - Float(psRand())) / half * 0.05)
        guard let parent = objects[parentHandle],
              case let .room(room) = parent.location,
              let created = objects.create(
                  type: .debris,
                  renderType: .polyobj,
                  location: .room(room),
                  position: parent.position,
                  orientation: parent.orientation
              )
        else {
            return
        }
        var debris = objects[created]!
        debris.creationTime = gameTime
        debris.flags |= GameObject.polygonObjectFlag
        debris.model = model.source
        debris.submodel = submodel
        let raw = direction * magnitude
        debris.velocity = Vector3(
            x: min(100_000, max(-100_000, raw.x)),
            y: min(100_000, max(-100_000, raw.y)),
            z: min(100_000, max(-100_000, raw.z))
        )
        debris.size = submodelRadius(model.submodels[submodel]) * 0.5
        var physics = ObjectPhysics(
            flags: ObjectPhysics.gravityFlag | ObjectPhysics.bounceFlag
                | ObjectPhysics.fixedRotationalVelocityFlag,
            mass: 40,
            drag: 0.001,
            restitution: 0.2
        )
        physics.rotationalVelocity = Vector3(
            x: 60_000 * (half - Float(psRand())) / half,
            y: 60_000 * (half - Float(psRand())) / half,
            z: 60_000 * (half - Float(psRand())) / half
        )
        if deathFlags & DeathFlags.debrisRemains != 0 {
            physics.numberOfBounces = 8
            physics.flags |= ObjectPhysics.stickFlag
            debris.lifeLeft = nil
        } else {
            physics.numberOfBounces = 2
            debris.lifeLeft = 2 + Float(psRand() % 50) * 0.05
        }
        debris.physics = physics
        debris.debris = DebrisInfo(deathFlags: deathFlags)
        objects[created] = debris
    }

    /// CreateSplintersFromBody (fireball.cpp:1044): up to 10 faces of the
    /// body fly off as splinters. Past 10 faces the faces are drawn at
    /// random; a splinter the table cannot hold ends the splintering.
    mutating func createSplintersFromBody(
        _ handle: ObjectHandle,
        lifetime: Float,
        level: Level
    ) {
        guard let object = objects[handle],
              case let .room(room) = object.location,
              let model = objectModel(object, level: level),
              // IsNonRenderableSubmodel (model/polymodel.cpp:3207): a body
              // with no faces makes none. Shell and front-face submodels
              // ($shell, $frontface) are door parts, which import rejects
              // until doors arrive (M2).
              let body = model.submodels.first,
              !body.faces.isEmpty
        else {
            return
        }
        var faces: [Int]
        if body.faces.count < Self.maximumSplinters {
            faces = Array(body.faces.indices)
        } else {
            faces = (0..<Self.maximumSplinters).map { _ in
                Int(psRand()) % body.faces.count
            }
        }
        for face in faces {
            // MAX_VERTS_PER_SPLINTER (object_external_struct.h:110).
            let corners = body.faces[face].corners.prefix(4)
            var center = Vector3.zero
            for corner in corners {
                center = center + sourceTransform(
                    body.vertices[corner.vertexIndex].position,
                    by: object.orientation
                )
            }
            center = center / Float(corners.count)
            let destination = center + object.position
            guard let created = objects.create(
                type: .splinter,
                renderType: .none,
                location: .room(room),
                position: destination,
                orientation: .identity
            ) else {
                return
            }
            var splinter = objects[created]!
            splinter.creationTime = gameTime
            splinter.model = model.source
            splinter.splinterFace = face
            let away = destination - object.position
            let outward = away == .zero ? away : sourceVectorNormalized(away)
            var velocity = object.velocity
                + ((outward * object.size) / lifetime) * 4
            var physics = ObjectPhysics(
                flags: ObjectPhysics.fixedRotationalVelocityFlag
                    | ObjectPhysics.gravityFlag | ObjectPhysics.bounceFlag,
                mass: 2_500,
                drag: 0.01
            )
            physics.rotationalVelocity = velocity * 400
            velocity = velocity
                * Float(1 + (Double(psRand() % 100 - 50) / 50) * 0.2)
            physics.rotationalVelocity = physics.rotationalVelocity
                * Float(1 + (Double(psRand() % 100 - 50) / 50) * 0.2)
            physics.numberOfBounces = 0
            splinter.velocity = velocity
            splinter.size = 0.5
            splinter.physics = physics
            var life = lifetime + Float(Double(psRand() % 9 - 4) * 0.1)
            if created.slot % 14 == 0 {
                life += Float(psRand() % 3) * 0.5
            }
            splinter.lifeLeft = life
            objects[created] = splinter
        }
    }

    // MARK: Frames of the made objects

    /// DoDebrisFrame (fireball.cpp:1207): a piece whose life or bounces are
    /// used up explodes if it is flagged to, and dies or goes inert.
    mutating func doDebrisFrame(_ handle: ObjectHandle, level: Level) {
        guard let object = objects[handle], let debris = object.debris
        else {
            return
        }
        let lifeUsed = (object.lifeLeft ?? 1) <= 0
        let bouncesUsed = (object.physics?.numberOfBounces ?? 0) < 1
        guard lifeUsed || bouncesUsed else { return }
        if debris.deathFlags & DeathFlags.debrisFireball != 0 {
            createObjectFireball(handle, level: level)
        }
        if debris.deathFlags & DeathFlags.debrisBlastRing != 0 {
            createObjectBlastRing(handle, level: level)
        }
        if debris.deathFlags & DeathFlags.debrisRemains == 0 {
            objects[handle]?.flags |= GameObject.deadFlag
        } else {
            objects[handle]?.debris = nil
        }
    }

    /// DoSplinterFrame (splinter.cpp:74).
    mutating func doSplinterFrame(_ handle: ObjectHandle, level: Level) {
        guard let object = objects[handle],
              case let .room(room) = object.location
        else {
            return
        }
        if (object.lifeLeft ?? 1) <= 0, psRand() % 2 == 0 {
            objects[handle]?.flags |= GameObject.deadFlag
        } else if handle.slot % 8 == 0, psRand() % 4 != 0 {
            let id = handle.slot % 2 != 0
                ? randomSmallExplosion() : VisEffect.blackSmokeID
            createFireball(
                position: object.position,
                id: id,
                roomSourceIndex: room,
                level: level
            )
        }
    }

    /// DoExplosionFrame (fireball.cpp:1710) for a fireball object other
    /// than the gravity field: it dies of old age.
    mutating func doExplosionFrame(_ handle: ObjectHandle) {
        guard let lifeLeft = objects[handle]?.lifeLeft, lifeLeft <= 0 else {
            return
        }
        objects[handle]?.flags |= GameObject.deadFlag
        objects[handle]?.lifeLeft = 0
    }

    // MARK: Delayed deaths

    /// SetFallingPhysics (damage.cpp:1083) for an object that does not walk:
    /// gravity, one bounce, almost no drag, and, if it is barely spinning,
    /// a random spin.
    mutating func setFallingPhysics(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle] else { return }
        let page = object.info.flatMap { level.objectInfos?[$0].physics }
        var physics = object.physics ?? page ?? ObjectPhysics(
            flags: 0, mass: 0, drag: 0
        )
        physics.flags = ObjectPhysics.gravityFlag | ObjectPhysics.bounceFlag
        physics.numberOfBounces = 0
        physics.restitution = 0.03
        if physics.mass < 20 { physics.mass = 20 }
        physics.drag = 0.000_01
        let spin = physics.rotationalVelocity
        if sqrt(dot(spin, spin)) < 4_000 {
            let half = Float(GameWorld.randMax / 2)
            physics.rotationalVelocity = Vector3(
                x: 60_000 * (half - Float(psRand())) / half,
                y: 60_000 * (half - Float(psRand())) / half,
                z: 60_000 * (half - Float(psRand())) / half
            )
        }
        object.physics = physics
        objects[handle] = object
    }

    /// SetFlyingPhysics (damage.cpp:1121).
    mutating func setFlyingPhysics(_ handle: ObjectHandle, tumbles: Bool) {
        guard var object = objects[handle] else { return }
        var physics = ObjectPhysics(
            flags: ObjectPhysics.gravityFlag | ObjectPhysics.noCollideFlag,
            mass: 50_000,
            drag: 0.01,
            restitution: 0.03
        )
        physics.rotationalVelocity =
            object.physics?.rotationalVelocity ?? .zero
        if tumbles {
            let half = Float(GameWorld.randMax / 2)
            physics.rotationalVelocity = Vector3(
                x: 40_000 * (half - Float(psRand())) / half,
                y: 60_000 * (half - Float(psRand())) / half,
                z: 40_000 * (half - Float(psRand())) / half
            )
        }
        if object.orientation.up.y == 1 {
            object.velocity = Vector3(
                x: 0,
                y: (Float(3 * (psRand() % 15)) + 20) * 2,
                z: 0
            )
        } else {
            object.velocity = object.orientation.up
                * (Float(2 * (psRand() % 15)) + 7)
        }
        object.physics = physics
        objects[handle] = object
    }

    /// DoDyingFrame's effects while the delay runs (fireball.cpp:1446-1507):
    /// electrical bolts, trailing explosions, and smoke.
    mutating func doDyingEffects(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle],
              var dying = object.dying,
              case let .room(room) = object.location
        else {
            return
        }
        let flags = dying.deathFlags
        if flags & DeathFlags.delaySparks != 0 {
            let norm = min(1, dying.delayTime / Self.electricalDeathTime)
            let chance = Int32(norm * 10) + 1
            if gameTime - dying.lastSparkTime > 0.01 {
                if psRand() % chance == 0 {
                    createElectricalBolts(
                        handle,
                        count: Int((1 - norm) * 5) + 3,
                        level: level
                    )
                }
                dying.lastSparkTime = gameTime
                objects[handle]?.dying = dying
            }
        }
        if flags & DeathFlags.delayFireball != 0 {
            if gameTime - dying.lastFireballTime > 0.01, psRand() % 3 == 0 {
                guard object.flags & GameObject.polygonObjectFlag != 0 else {
                    return
                }
                dying.lastFireballTime = gameTime
                objects[handle]?.dying = dying
                if let model = objectModel(object, level: level),
                   let body = model.submodels.first,
                   !body.vertices.isEmpty {
                    let vertex = Int(psRand()) % body.vertices.count
                    let point = object.position + sourceTransform(
                        body.vertices[vertex].position,
                        by: object.orientation
                    )
                    let id = randomSmallExplosion()
                    if let index = createFireball(
                        position: point,
                        id: id,
                        roomSourceIndex: room,
                        level: level
                    ) {
                        visEffects[index].size +=
                            Float(psRand() % 20) / 20 * 3
                        if psRand() % 2 != 0 {
                            visEffects[index].usesPhysics = true
                            visEffects[index].velocity = object.velocity
                            visEffects[index].mass =
                                object.physics?.mass ?? 0
                            visEffects[index].drag =
                                object.physics?.drag ?? 0
                        }
                    }
                }
            }
        }
        object = objects[handle] ?? object
        dying = object.dying ?? dying
        if flags & DeathFlags.delaySmokes != 0,
           gameTime - dying.lastSmokeTime > 0.01, psRand() % 3 == 0 {
            dying.lastSmokeTime = gameTime
            objects[handle]?.dying = dying
            // Indoors, half the time.
            if psRand() % 2 == 0 {
                createFireball(
                    position: object.position,
                    id: VisEffect.blackSmokeID,
                    roomSourceIndex: room,
                    level: level
                )
            }
        }
    }

    /// CreateElectricalBolts (fireball.cpp:1249): each bolt picks a
    /// submodel, and one that gets a list entry spans two of its vertices.
    private mutating func createElectricalBolts(
        _ handle: ObjectHandle,
        count: Int,
        level: Level
    ) {
        guard let object = objects[handle],
              case let .room(room) = object.location,
              let model = objectModel(object, level: level),
              !model.submodels.isEmpty
        else {
            return
        }
        for _ in 0..<count {
            let submodel = Int(psRand()) % model.submodels.count
            let vertices = model.submodels[submodel].vertices.count
            guard vertices > 0,
                  let index = visEffectCreate(
                      id: VisEffect.lightningBoltID,
                      roomSourceIndex: room,
                      position: object.position,
                      level: level
                  )
            else {
                continue
            }
            var bolt = visEffects[index]
            bolt.lifeLeft = 1
            bolt.lifetime = 1
            bolt.endPosition = object.position
            bolt.velocity = Vector3(x: 0.15, y: 3, z: 0)
            bolt.attachedObject = handle
            bolt.attachedSubmodel = submodel
            bolt.attachedVertex = Int(psRand()) % vertices
            bolt.attachedEndVertex = Int(psRand()) % vertices
            bolt.flags = VisEffect.usesLifeLeftFlag | VisEffect.expandFlag
                | VisEffect.attachedFlag
            visEffects[index] = bolt
        }
    }
}

extension Matrix3 {
    /// Identity_matrix.
    static let identity = Matrix3(
        right: Vector3(x: 1, y: 0, z: 0),
        up: Vector3(x: 0, y: 1, z: 0),
        forward: Vector3(x: 0, y: 0, z: 1)
    )
}
