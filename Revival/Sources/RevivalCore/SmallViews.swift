// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/SmallViews.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the small view windows' state,
// CreateSmallView (:207), the timer and dead-viewer steps of
// DrawSmallViews (:398, run in the render step of the frame), the view
// from a gun (WeaponCalcGun and GetGunRoom, :371, :490-497),
// CloseSmallView (:542), and ClosePopupView (:566); and the
// MSAFE_MISC_POPUP_CAMERA and MSAFE_MISC_CLOSE_POPUP calls
// (multisafe.cpp:2082-2089). The window's place, size, outline, label, and
// static picture are presentation: RevivalMac draws the one popup view it
// gets in the frame (architecture.md section 9).

import Foundation

/// One small view window (`small_view`, SmallViews.cpp:171).
struct SmallView: Codable, Equatable, Sendable {
    /// SVF_ flags (SmallViews.h:77-82).
    enum Flag {
        static let popup: UInt32 = 1
        static let bigger: UInt32 = 2
        static let rearView: UInt32 = 4
        static let timed: UInt32 = 8
        static let crosshairs: UInt32 = 16
        static let staticPicture: UInt32 = 32
    }

    /// NUM_SMALL_VIEWS.
    static let count = 3
    /// SVW_LEFT.
    static let leftWindow = 0
    /// STATIC_TIME (SmallViews.cpp:267).
    static let staticTime: Float = 0.25
    /// D3_DEFAULT_ZOOM (descent.h:179).
    static let defaultZoom: Float = 0.726

    /// `objhandle`, or OBJECT_HANDLE_NONE when the window is not active.
    var viewer: ObjectHandle = .none
    var flags: UInt32 = 0
    /// How much longer a SVF_TIMED window stays.
    var timer: Float = 0
    var zoom: Float = SmallView.defaultZoom
    /// The gun to view from, or -1 for the viewer's center.
    var gun: Int = -1

    var isActive: Bool { viewer != .none }
}

/// A small view the app draws this frame: the camera, its room, and the
/// object it views from (which it does not draw).
struct SmallViewFrame: Equatable, Sendable {
    let window: Int
    let camera: RoomCamera
    let roomSourceIndex: Int
    let viewerObjectHandle: UInt32
    let remainingDuration: Float
    let isPopup: Bool
}

extension GameWorld {
    /// CreateSmallView (SmallViews.cpp:207). A popup over a non-popup view
    /// saves the old view, which comes back when the popup closes. A time
    /// of 0 keeps the window up. Returns the window, or -1 when the object
    /// does not exist.
    @discardableResult
    mutating func createSmallView(
        window: Int,
        viewer: ObjectHandle,
        flags: UInt32,
        time: Float,
        zoom: Float,
        gun: Int
    ) -> Int {
        let window = (0..<SmallView.count).contains(window)
            ? window : SmallView.leftWindow
        guard objects[viewer] != nil else { return -1 }
        let current = smallViews[window]
        if flags & SmallView.Flag.popup != 0, current.isActive,
           current.flags & SmallView.Flag.popup == 0 {
            savedSmallViews[window] = current
        }
        var view = SmallView(
            viewer: viewer,
            flags: flags,
            timer: time,
            zoom: zoom,
            gun: gun
        )
        if time != 0 {
            view.flags |= SmallView.Flag.timed
        }
        smallViews[window] = view
        return window
    }

    /// MSAFE_MISC_POPUP_CAMERA (multisafe.cpp:2082): a bigger left popup
    /// window from the object's gun, at D3_DEFAULT_ZOOM / `scalar`.
    mutating func createPopupView(
        viewer: ObjectHandle,
        time: Float,
        scalar: Float,
        gun: Int
    ) {
        createSmallView(
            window: SmallView.leftWindow,
            viewer: viewer,
            flags: SmallView.Flag.popup | SmallView.Flag.bigger,
            time: time,
            zoom: SmallView.defaultZoom / scalar,
            gun: gun
        )
    }

    /// CloseSmallView (SmallViews.cpp:542): a saved view comes back.
    mutating func closeSmallView(_ window: Int) {
        smallViews[window].viewer = .none
        if savedSmallViews[window].isActive {
            smallViews[window] = savedSmallViews[window]
            savedSmallViews[window].viewer = .none
        }
    }

    /// ClosePopupView (SmallViews.cpp:566), MSAFE_MISC_CLOSE_POPUP.
    mutating func closePopupView(_ window: Int = SmallView.leftWindow) {
        if smallViews[window].flags & SmallView.Flag.popup != 0 {
            closeSmallView(window)
        }
    }

    /// The state steps of DrawSmallViews (SmallViews.cpp:398), run when
    /// the frame renders: a window whose viewer is gone or ghosted shows
    /// static for STATIC_TIME, and a timed window counts down with the
    /// previous Frametime and closes below 0.
    mutating func smallViewsRenderFrame(frameTime: Float) {
        for window in 0..<SmallView.count where smallViews[window].isActive {
            let viewer = objects[smallViews[window].viewer]
            let killsViewer = viewer == nil || viewer?.type == .dummy
            if killsViewer,
               smallViews[window].flags & SmallView.Flag.staticPicture == 0 {
                smallViews[window].flags |=
                    SmallView.Flag.staticPicture | SmallView.Flag.timed
                smallViews[window].timer = SmallView.staticTime
                smallViews[window].gun = -1
            }
            if smallViews[window].flags & SmallView.Flag.timed != 0 {
                smallViews[window].timer -= frameTime
                if smallViews[window].timer < 0 {
                    closeSmallView(window)
                }
            }
        }
    }

    /// The view each active small view shows (DrawSmallViews :490-509):
    /// from a gun, the gun point looking along the gun's normal
    /// (vm_VectorToMatrix with no up vector) in the room GetGunRoom finds;
    /// otherwise the viewer's own place. A window that shows static has no
    /// view.
    func smallViewFrames(level: Level) -> [SmallViewFrame] {
        (0..<SmallView.count).compactMap { window -> SmallViewFrame? in
            let view = smallViews[window]
            guard view.isActive,
                  view.flags & SmallView.Flag.staticPicture == 0,
                  let viewer = objects[view.viewer],
                  case let .room(room) = viewer.location
            else {
                return nil
            }
            let projection = view.zoom == SmallView.defaultZoom
                ? PerspectiveProjection.sourceDefault
                : PerspectiveProjection(
                    horizontalFieldOfViewRadians: 2 * atan(
                        tan(PerspectiveProjection.sourceDefault
                            .horizontalFieldOfViewRadians / 2)
                            * view.zoom / SmallView.defaultZoom
                    ),
                    aspectRatio: PerspectiveProjection.sourceDefault
                        .aspectRatio
                )
            let camera: RoomCamera
            let cameraRoom: Int
            if view.gun != -1,
               let model = level.placedObjectModel(viewer.handle) {
                let gun = weaponCalcGun(viewer, gunpoint: view.gun,
                                        model: model)
                let forward = sourceVectorNormalized(gun.normal)
                camera = RoomCamera(
                    position: gun.point,
                    target: gun.point + forward,
                    up: Self.vectorToMatrixUp(forward),
                    projection: projection
                )
                // GetGunRoom (SmallViews.cpp:371): the room the line from
                // the viewer to its gun point ends in.
                cameraRoom = traceIndoorMovement(
                    in: level,
                    roomStates: rooms,
                    startRoom: room,
                    start: viewer.position,
                    end: gun.point,
                    radius: 0
                ).containingRoomSourceIndex
            } else {
                camera = RoomCamera(
                    position: viewer.position,
                    target: viewer.position + viewer.orientation.forward,
                    up: viewer.orientation.up,
                    projection: projection
                )
                cameraRoom = room
            }
            return SmallViewFrame(
                window: window,
                camera: camera,
                roomSourceIndex: cameraRoom,
                viewerObjectHandle: viewer.handle.rawValue,
                remainingDuration: view.timer,
                isPopup: view.flags & SmallView.Flag.popup != 0
            )
        }
    }

    /// The up vector vm_VectorToMatrix makes from a forward vector alone:
    /// straight up or down looks along z; otherwise the right vector is
    /// level (y = 0) and up is forward x right.
    static func vectorToMatrixUp(_ forward: Vector3) -> Vector3 {
        if forward.x == 0 && forward.z == 0 {
            return .init(x: 0, y: 0, z: forward.y < 0 ? 1 : -1)
        }
        let right = sourceVectorNormalized(.init(
            x: forward.z,
            y: 0,
            z: -forward.x
        ))
        return sourceVectorCross(forward, right)
    }
}
