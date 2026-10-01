// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/object_lighting.cpp (Descent 3, Copyright (C)
// 2024 Parallax Software, GPL-3.0-or-later): DoObjectLight (:171) for a
// weapon, with IsLightPointVisible (:126), and MakeObjectInvisible (:572)
// and MakeObjectVisible (:598); and from Descent3/renderobject.cpp,
// IsPointVisible (:1779) and the cloak fade of the polygon object draw
// (:1499-1512).
//
// DoObjectLight runs at the end of each object's ObjDoFrame. A weapon casts
// its page light (lighting_info) when its light sphere is in the last
// rendered view: OLF_FLICKER_SLIGHTLY moves the distance by a ps_rand
// draw, OLF_PULSE scales it, OLF_PULSE_TO_SECOND blends the colors,
// OLF_FLICKERING draws whether it is off this frame, and OLF_TIMEBITS turns
// it off by the time slice. ApplyLightingToRooms is the renderer's: the
// light goes to `objectLights`, which the session moves to the frame's
// presentation, so a saved world has none. Dynamic lighting and Katmai are
// on in the released game (init.cpp:1224, descent.cpp:429), so every light
// distance is 1.5 times the page's. The other object types' lights stay
// presentation-only (architecture.md section 9).

import Foundation

/// One light ApplyLightingToRooms casts this frame: its place, room,
/// distance, color, and, for OLF_DIRECTIONAL, its cone.
struct ObjectLightRequest: Codable, Equatable, Sendable {
    let roomSourceIndex: Int
    let position: Vector3
    let distance: Float
    let color: Vector3
    let direction: Vector3?
    let directionalDot: Float
}

/// The OLF_ light flags (object.h:671-676).
enum ObjectLightFlag {
    static let flickering: UInt32 = 1
    static let timebits: UInt32 = 2
    static let pulse: UInt32 = 4
    static let pulseToSecond: UInt32 = 8
    static let flickerSlightly: UInt32 = 16
    static let directional: UInt32 = 32
}

extension GameWorld {
    /// DoObjectLight (object_lighting.cpp:171) for an OBJ_WEAPON. A dead or
    /// unrendered object casts nothing.
    mutating func doObjectLight(_ handle: ObjectHandle, level: Level) {
        guard let object = objects[handle],
              object.flags & GameObject.deadFlag == 0,
              object.renderType != .none,
              object.type == .weapon,
              let weaponIndex = object.weapon,
              let li = level.weapons?[weaponIndex].lighting,
              var lightDistance = level.weapons?[weaponIndex].lightDistance,
              case let .room(room) = object.location
        else {
            return
        }
        // Make katmai lights bigger (object_lighting.cpp:368).
        lightDistance *= 1.5
        guard lightDistance > 0 else { return }
        guard isLightPointVisible(object.position, size: lightDistance)
        else {
            return
        }
        let direction = li.flags & ObjectLightFlag.directional != 0
            ? object.orientation.forward : nil
        if li.flags & ObjectLightFlag.flickerSlightly != 0 {
            // `int factor = li->flicker_distance;`
            let factor = Int32(sourceInt(li.flickerDistance))
            guard factor != 0 else { return }
            lightDistance += Float(psRand() % factor - factor / 2)
            if lightDistance < 0 { return }
        }
        var color = li.primaryColor
        var scalar: Float = 1
        if li.flags & ObjectLightFlag.pulse != 0, li.timeInterval > 0 {
            let ptime = li.timeInterval
            let intTime = sourceInt(gameTime / (ptime * 2))
            let leftTime = gameTime - Float(intTime) * ptime * 2
            var normTime = leftTime / ptime
            if !normTime.isFinite { normTime = 0 }
            scalar = normTime > 1 ? 1 - (normTime - 1) : normTime
            scalar = li.flickerDistance + scalar * (1 - li.flickerDistance)
        }
        if li.flags & ObjectLightFlag.pulseToSecond != 0,
           li.timeInterval > 0 {
            let ptime = li.timeInterval
            let intTime = sourceInt(gameTime / (ptime * 2))
            let leftTime = gameTime - Float(intTime) * ptime * 2
            var normTime = leftTime / ptime
            if !normTime.isFinite { normTime = 0 }
            if normTime > 1 {
                normTime -= 1
                color = li.secondaryColor * (1 - normTime)
                    + li.primaryColor * normTime
            } else {
                color = li.primaryColor * (1 - normTime)
                    + li.secondaryColor * normTime
            }
        }
        if scalar < 0 { scalar = 0 }
        if li.flags & ObjectLightFlag.flickering != 0, psRand() % 2 == 1 {
            return
        }
        if li.flags & ObjectLightFlag.timebits != 0 {
            let intTime = sourceInt(gameTime / li.timeInterval)
            let leftTime = gameTime - Float(intTime) * li.timeInterval
            let sliceTime = li.timeInterval / 8
            let bit = sourceInt(leftTime / sliceTime)
            guard (0..<32).contains(bit),
                  li.timebits & (UInt32(1) << UInt32(bit)) != 0
            else {
                return
            }
        }
        objectLights.append(.init(
            roomSourceIndex: room,
            position: object.position,
            distance: lightDistance * scalar,
            color: color,
            direction: direction,
            directionalDot: li.directionalDot
        ))
    }

    /// IsLightPointVisible (object_lighting.cpp:126) for an object: its
    /// light sphere is in the view the last frame rendered
    /// (IsPointVisible). OF_RENDERED also passes in the C++; an object the
    /// last frame drew has its center in that view, so for a light no
    /// smaller than the object the test is the same.
    func isLightPointVisible(_ position: Vector3, size: Float) -> Bool {
        guard let camera = lastRenderCamera else { return false }
        return isPointVisible(position, size: size, camera: camera)
    }
}

/// `(int)value` (a C float-to-int cast). A value an int cannot hold, which
/// is undefined in C, clamps to the int range, and NaN gives 0; the package
/// checks keep the light values that reach these casts in range
/// (ObjectInfo.swift).
func sourceInt(_ value: Float) -> Int {
    guard !value.isNaN else { return 0 }
    let wide = Int(max(-2_147_483_648, min(2_147_483_647, value)))
    return min(Int(Int32.max), max(Int(Int32.min), wide))
}

/// IsPointVisible (renderobject.cpp:1779): the point is in the view's
/// frustum (g3_CodePoint), or its sphere of `size` reaches over each plane
/// it is off. The side planes turn by half of Render_FOV in whole
/// 65536/360 steps, for the top and bottom too, as in the C++. Far_clip_z
/// is unset indoors.
func isPointVisible(_ position: Vector3, size: Float,
                    camera: RoomCamera) -> Bool {
    let forward = sourceVectorNormalized(camera.target - camera.position)
    let right = sourceVectorNormalized(sourceVectorCross(camera.up, forward))
    let up = sourceVectorCross(forward, right)
    let relative = position - camera.position
    let view = Vector3(
        x: dot(relative, right),
        y: dot(relative, up),
        z: dot(relative, forward)
    )
    let horizontalTangent = tan(camera.projection.horizontalFieldOfViewRadians
        / 2)
    let verticalTangent = horizontalTangent / camera.projection.aspectRatio
    let scaledX = view.x / horizontalTangent
    let scaledY = view.y / verticalTangent
    let offRight = scaledX > view.z
    let offLeft = scaledX < -view.z
    let offTop = scaledY > view.z
    let offBottom = scaledY < -view.z
    let behind = view.z < 0
    guard offRight || offLeft || offTop || offBottom || behind else {
        return true
    }
    if view.z < -size { return false }
    let fovDegrees = camera.projection.horizontalFieldOfViewRadians
        * 180 / 3.14
    let angleAdjust = Int((fovDegrees / 2) * Float(65_536 / 360))
    func normal(_ vector: Vector3, p: Int, h: Int) -> Vector3 {
        FixMath.rotate(vector, FixMath.matrix(
            p: UInt16(truncatingIfNeeded: p),
            h: UInt16(truncatingIfNeeded: h),
            b: 0
        ))
    }
    let rightNormal = normal(.init(x: 1, y: 0, z: 0), p: 0,
                             h: 65_536 - angleAdjust)
    let leftNormal = normal(.init(x: -1, y: 0, z: 0), p: 0, h: angleAdjust)
    let bottomNormal = normal(.init(x: 0, y: -1, z: 0),
                              p: 65_536 - angleAdjust, h: 0)
    let topNormal = normal(.init(x: 0, y: 1, z: 0), p: angleAdjust, h: 0)
    if offRight, dot(rightNormal, view) > size { return false }
    if offLeft, dot(leftNormal, view) > size { return false }
    if offTop, dot(topNormal, view) > size { return false }
    if offBottom, dot(bottomNormal, view) > size { return false }
    return true
}

extension GameWorld {
    /// MakeObjectInvisible (object_lighting.cpp:572): the object fades out
    /// over `fadeTime` and then stays cloaked for `time`. A player hears
    /// "Cloak on" at half volume and sees TXT_CLOAKON, unless
    /// `noHUDMessage`, and its cloak ends with a message.
    mutating func makeObjectInvisible(
        _ handle: ObjectHandle,
        time: Float,
        fadeTime: Float = 1,
        noHUDMessage: Bool = false
    ) {
        guard var object = objects[handle] else { return }
        var effect = object.effect ?? ObjectEffectInfo()
        effect.cloakTime = time
        effect.typeFlags |= ObjectEffectInfo.fadingOutFlag
        effect.fadeTime = fadeTime
        effect.fadeMaxTime = fadeTime
        object.effect = effect
        objects[handle] = object
        if object.type == .player, !noHUDMessage {
            play3DSound(EngineSound.cloakOn, volume: 0.5)
            addHUDMessage(EngineText.cloakOn)
            objects[handle]?.effect?.typeFlags |=
                ObjectEffectInfo.cloakWithMessageFlag
        }
    }

    /// MakeObjectVisible (object_lighting.cpp:598): the object fades back
    /// in. A player cloaked with a message hears "Cloak off" at half volume
    /// and sees TXT_MSG_CLOAKOFF.
    mutating func makeObjectVisible(_ handle: ObjectHandle) {
        guard let object = objects[handle] else { return }
        if var effect = object.effect {
            effect.typeFlags &= ~ObjectEffectInfo.cloakedFlag
            effect.typeFlags |= ObjectEffectInfo.fadingInFlag
            effect.fadeTime = effect.fadeMaxTime
            effect.cloakTime = 0
            objects[handle]?.effect = effect
        }
        if object.type == .player,
           let flags = object.effect?.typeFlags,
           flags & ObjectEffectInfo.cloakWithMessageFlag != 0 {
            play3DSound(EngineSound.cloakOff, volume: 0.5)
            addHUDMessage(EngineText.cloakOff)
        }
    }

    /// The cloak part of ObjDoEffects (object.cpp:2447): a fade in ends, a
    /// cloak counts down and ends with MakeObjectVisible, and a fade out
    /// ends cloaked, in that order, with the frame's Frametime.
    mutating func objDoEffects(_ handle: ObjectHandle) {
        guard objects[handle]?.effect != nil else { return }
        if var effect = objects[handle]?.effect,
           effect.typeFlags & ObjectEffectInfo.fadingInFlag != 0 {
            effect.fadeTime -= frameDuration
            if effect.fadeTime <= 0 {
                effect.typeFlags &= ~ObjectEffectInfo.fadingInFlag
            }
            objects[handle]?.effect = effect
        }
        if var effect = objects[handle]?.effect,
           effect.typeFlags & ObjectEffectInfo.cloakedFlag != 0 {
            effect.cloakTime -= frameDuration
            objects[handle]?.effect = effect
            if effect.cloakTime <= 0 {
                makeObjectVisible(handle)
            }
        }
        if var effect = objects[handle]?.effect,
           effect.typeFlags & ObjectEffectInfo.fadingOutFlag != 0 {
            effect.fadeTime -= frameDuration
            if effect.fadeTime <= 0 {
                effect.typeFlags &= ~ObjectEffectInfo.fadingOutFlag
                effect.typeFlags |= ObjectEffectInfo.cloakedFlag
            }
            objects[handle]?.effect = effect
        }
    }
}

/// The cloak a polygon object draws with (renderobject.cpp:1499-1512): the
/// alpha of a fade, and the deform range of a cloaked object.
struct ObjectCloakFrame: Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case fadingOut
        case cloaked
        case fadingIn
    }

    let phase: Phase
    /// The fade time left, or the cloak time left while cloaked.
    let phaseRemaining: Float
    /// `fade_max_time` (the cloak frame does not read it).
    let phaseDuration: Float

    /// The frame of an object's effect, or `nil` when it draws normally.
    init?(_ effect: ObjectEffectInfo?) {
        guard let effect else { return nil }
        // The draw sets the fade out, then the fade in, then the cloak, so
        // the last one set wins.
        if effect.typeFlags & ObjectEffectInfo.cloakedFlag != 0 {
            phase = .cloaked
            phaseRemaining = effect.cloakTime
        } else if effect.typeFlags & ObjectEffectInfo.fadingInFlag != 0 {
            phase = .fadingIn
            phaseRemaining = effect.fadeTime
        } else if effect.typeFlags & ObjectEffectInfo.fadingOutFlag != 0 {
            phase = .fadingOut
            phaseRemaining = effect.fadeTime
        } else {
            return nil
        }
        phaseDuration = effect.fadeMaxTime
    }

    init(phase: Phase, phaseRemaining: Float, phaseDuration: Float) {
        self.phase = phase
        self.phaseRemaining = phaseRemaining
        self.phaseDuration = phaseDuration
    }

    /// The draw's alpha (renderobject.cpp:1499-1512). The source divides
    /// by fade_max_time even when it is 0; Revival takes that ratio as 0.
    /// Overlapping fades can leave the time outside 0...fade_max_time, so
    /// the alpha is clamped to 0...1 (architecture.md section 9).
    var objectAlpha: Float {
        let ratio = phaseDuration > 0 ? phaseRemaining / phaseDuration : 0
        let alpha: Float
        switch phase {
        case .fadingOut:
            alpha = 0.08 + 0.92 * ratio
        case .cloaked:
            alpha = 0.13
        case .fadingIn:
            alpha = 0.08 + 0.92 * (1 - ratio)
        }
        return min(1, max(0, alpha))
    }

    var objectDeformationRange: Float {
        phase == .cloaked ? 0.1 : 0
    }
}
