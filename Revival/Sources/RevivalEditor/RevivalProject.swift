// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum RevivalProjectError: Error, Equatable, LocalizedError {
    case unsupportedSchema(Int)
    case baseIdentityMismatch
    case roomMissing(Int)
    case faceMissing(roomSourceIndex: Int, faceIndex: Int)
    case portalMissing(roomSourceIndex: Int, portalIndex: Int)
    case materialUnavailable(SourceResource)
    case objectMissing(UInt32)
    case objectIsPlayer(UInt32)
    case playerStartMissing(playerID: Int, handle: UInt32)
    case vertexMissing(roomSourceIndex: Int, vertexIndex: Int)
    case invalidRoomVertexEdit(roomSourceIndex: Int, vertexIndex: Int)
    case roomVertexEditRejected(roomSourceIndex: Int, vertexIndex: Int, reason: String)
    case placementHasNoContainingRoom(owner: String)
    case placementBlocked(owner: String, roomSourceIndex: Int, faceIndex: Int)
    case invalidRoomNameEdit(Int)
    case invalidFaceMaterialEdit(roomSourceIndex: Int, faceIndex: Int)
    case invalidPortalRenderingEdit(roomSourceIndex: Int, portalIndex: Int)
    case combinedPortalRenderingEditDeferred(roomSourceIndex: Int, portalIndex: Int)
    case trainingGalleryBarrierUnavailable
    case trainingGalleryBarrierEditRejected
    case trainingGuidebotReturnBarrierUnavailable
    case trainingGuidebotReturnBarrierEditRejected
    case invalidObjectTransformEdit(UInt32)
    case invalidPlayerStartTransformEdit(playerID: Int, handle: UInt32)
    case faceEditRejected(roomSourceIndex: Int, faceIndex: Int)
    case portalEditRejected(roomSourceIndex: Int, portalIndex: Int)
    case authoredDependencyCombinationRejected(
        faceRoomSourceIndex: Int,
        faceIndex: Int,
        portalRoomSourceIndex: Int,
        portalIndex: Int
    )
    case invalidRoomName
    case roomNameTooLong
    case unchangedRoomName
    case unchangedProperty
    case duplicateRoomName(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            "Revival project schema \(version) is not supported."
        case .baseIdentityMismatch:
            "The project base reference does not match the complete canonical level."
        case let .roomMissing(sourceIndex):
            "Source room \(sourceIndex) is missing from the complete project level."
        case let .faceMissing(roomSourceIndex, faceIndex):
            "Source room \(roomSourceIndex) has no face \(faceIndex) to edit."
        case let .portalMissing(roomSourceIndex, portalIndex):
            "Source room \(roomSourceIndex) has no portal \(portalIndex) to edit."
        case let .materialUnavailable(texture):
            "Face material ‘\(texture.sourceName)’ is not in the complete level's prepared dependencies."
        case let .objectMissing(handle):
            "Object handle \(handle) is missing from the complete project level."
        case let .objectIsPlayer(handle):
            "Object handle \(handle) is a player start and must be edited by player identity."
        case let .playerStartMissing(playerID, handle):
            "Player \(playerID) does not own player-start object handle \(handle)."
        case let .vertexMissing(roomSourceIndex, vertexIndex):
            "Source room \(roomSourceIndex) has no vertex \(vertexIndex) to edit."
        case let .invalidRoomVertexEdit(roomSourceIndex, vertexIndex):
            "The project contains an invalid or redundant vertex edit for source room \(roomSourceIndex) vertex \(vertexIndex)."
        case let .roomVertexEditRejected(roomSourceIndex, vertexIndex, reason):
            "Source room \(roomSourceIndex) vertex \(vertexIndex) was not changed: \(reason)"
        case let .placementHasNoContainingRoom(owner):
            "\(owner) was not moved because no indoor room owns the proposed position."
        case let .placementBlocked(owner, roomSourceIndex, faceIndex):
            "\(owner) was not moved because source room \(roomSourceIndex) face \(faceIndex) blocks it at the current position."
        case let .invalidRoomNameEdit(sourceIndex):
            "The project contains an invalid or redundant name edit for source room \(sourceIndex)."
        case let .invalidFaceMaterialEdit(roomSourceIndex, faceIndex):
            "The project contains an invalid or redundant material edit for source room \(roomSourceIndex) face \(faceIndex)."
        case let .invalidPortalRenderingEdit(roomSourceIndex, portalIndex):
            "The project contains an invalid or redundant rendering edit for source room \(roomSourceIndex) portal \(portalIndex)."
        case let .combinedPortalRenderingEditDeferred(roomSourceIndex, portalIndex):
            "Source room \(roomSourceIndex) portal \(portalIndex) belongs to a combined portal group; group-wide portal authoring is deferred."
        case .trainingGalleryBarrierUnavailable:
            "TrainingMission.cpp Script 032 / Portal2 is not bound to this canonical level."
        case .trainingGalleryBarrierEditRejected:
            "TrainingMission.cpp Script 032 / Portal2 could not update its two-sided barrier without breaking the canonical trigger, portal, collision, or presentation contract."
        case .trainingGuidebotReturnBarrierUnavailable:
            "TrainingMission.cpp Script 058 / PortalRoom5 is not bound to this canonical level."
        case .trainingGuidebotReturnBarrierEditRejected:
            "TrainingMission.cpp Script 058 / PortalRoom5 could not update its two-sided barrier without breaking the canonical portal, collision, or presentation contract."
        case let .invalidObjectTransformEdit(handle):
            "The project contains an invalid or redundant transform edit for object handle \(handle)."
        case let .invalidPlayerStartTransformEdit(playerID, handle):
            "The project contains an invalid or redundant transform edit for player \(playerID) handle \(handle)."
        case let .faceEditRejected(roomSourceIndex, faceIndex):
            "Source room \(roomSourceIndex) face \(faceIndex) cannot use that material because it would break the complete level's reached presentation dependencies."
        case let .portalEditRejected(roomSourceIndex, portalIndex):
            "Source room \(roomSourceIndex) portal \(portalIndex) cannot use that rendering state because it would break the complete level's topology or reached presentation closure."
        case let .authoredDependencyCombinationRejected(
            faceRoomSourceIndex,
            faceIndex,
            portalRoomSourceIndex,
            portalIndex
        ):
            "Source room \(faceRoomSourceIndex) face \(faceIndex) and source room \(portalRoomSourceIndex) portal \(portalIndex) together break the complete level's reached presentation closure."
        case .invalidRoomName:
            "Room names cannot contain only whitespace or surrounding whitespace."
        case .roomNameTooLong:
            "Room names must use at most 19 UTF-8 bytes."
        case .unchangedRoomName:
            "The selected room already has that name."
        case .unchangedProperty:
            "The selected value is already set."
        case let .duplicateRoomName(name):
            "A room named ‘\(name)’ already exists. Room names are compared without case."
        }
    }
}

enum RevivalEditorSelectionError: Error, Equatable, LocalizedError {
    case roomMissing(Int)
    case faceMissing(roomSourceIndex: Int, faceIndex: Int)
    case portalMissing(roomSourceIndex: Int, portalIndex: Int)

    var errorDescription: String? {
        switch self {
        case let .roomMissing(sourceIndex):
            "Source room \(sourceIndex) is not present in the complete level."
        case let .faceMissing(roomSourceIndex, faceIndex):
            "Source room \(roomSourceIndex) has no face \(faceIndex)."
        case let .portalMissing(roomSourceIndex, portalIndex):
            "Source room \(roomSourceIndex) has no portal \(portalIndex)."
        }
    }
}

struct RevivalRoomSelection: Equatable, Sendable {
    let sourceIndex: Int

    init(sourceIndex: Int, in level: Level) throws {
        guard level.rooms.contains(where: { $0.sourceIndex == sourceIndex }) else {
            throw RevivalEditorSelectionError.roomMissing(sourceIndex)
        }
        self.sourceIndex = sourceIndex
    }

    fileprivate init(trustedSourceIndex: Int) {
        sourceIndex = trustedSourceIndex
    }
}

struct RevivalFaceSelection: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int

    init(roomSourceIndex: Int, faceIndex: Int, in level: Level) throws {
        guard let room = level.rooms.first(where: {
            $0.sourceIndex == roomSourceIndex
        }) else {
            throw RevivalEditorSelectionError.roomMissing(roomSourceIndex)
        }
        guard room.faces.indices.contains(faceIndex) else {
            throw RevivalEditorSelectionError.faceMissing(
                roomSourceIndex: roomSourceIndex,
                faceIndex: faceIndex
            )
        }
        self.roomSourceIndex = roomSourceIndex
        self.faceIndex = faceIndex
    }

    fileprivate init(trustedRoomSourceIndex: Int, faceIndex: Int) {
        roomSourceIndex = trustedRoomSourceIndex
        self.faceIndex = faceIndex
    }
}

struct RevivalPortalSelection: Equatable, Sendable {
    let roomSourceIndex: Int
    let portalIndex: Int

    init(roomSourceIndex: Int, portalIndex: Int, in level: Level) throws {
        guard let room = level.rooms.first(where: {
            $0.sourceIndex == roomSourceIndex
        }) else {
            throw RevivalEditorSelectionError.roomMissing(roomSourceIndex)
        }
        guard room.portals.indices.contains(portalIndex) else {
            throw RevivalEditorSelectionError.portalMissing(
                roomSourceIndex: roomSourceIndex,
                portalIndex: portalIndex
            )
        }
        self.roomSourceIndex = roomSourceIndex
        self.portalIndex = portalIndex
    }

    fileprivate init(trustedRoomSourceIndex: Int, portalIndex: Int) {
        roomSourceIndex = trustedRoomSourceIndex
        self.portalIndex = portalIndex
    }
}

struct RevivalEditorSelection: Equatable, Sendable {
    private(set) var room: RevivalRoomSelection
    private(set) var face: RevivalFaceSelection
    private(set) var portal: RevivalPortalSelection?

    init(roomSourceIndex: Int, in level: Level) throws {
        room = try RevivalRoomSelection(sourceIndex: roomSourceIndex, in: level)
        face = try RevivalFaceSelection(
            roomSourceIndex: roomSourceIndex,
            faceIndex: 0,
            in: level
        )
        portal = nil
    }

    mutating func selectRoom(sourceIndex: Int, in level: Level) throws {
        let selectedRoom = try RevivalRoomSelection(sourceIndex: sourceIndex, in: level)
        let selectedFace = try RevivalFaceSelection(
            roomSourceIndex: sourceIndex,
            faceIndex: 0,
            in: level
        )
        room = selectedRoom
        face = selectedFace
        portal = nil
    }

    mutating func selectFace(_ faceIndex: Int, in level: Level) throws {
        face = try RevivalFaceSelection(
            roomSourceIndex: room.sourceIndex,
            faceIndex: faceIndex,
            in: level
        )
        portal = nil
    }

    mutating func selectPortal(_ portalIndex: Int, in level: Level) throws {
        let selectedPortal = try RevivalPortalSelection(
            roomSourceIndex: room.sourceIndex,
            portalIndex: portalIndex,
            in: level
        )
        let currentRoom = level.rooms.first {
            $0.sourceIndex == room.sourceIndex
        }!
        let selectedFace = RevivalFaceSelection(
            trustedRoomSourceIndex: room.sourceIndex,
            faceIndex: currentRoom.portals[portalIndex].faceIndex
        )
        face = selectedFace
        portal = selectedPortal
    }

    mutating func followSelectedPortal(in level: Level) {
        let portal = portal!
        let sourceRoom = level.rooms.first {
            $0.sourceIndex == portal.roomSourceIndex
        }!
        let sourcePortal = sourceRoom.portals[portal.portalIndex]
        let destinationRoom = RevivalRoomSelection(
            trustedSourceIndex: sourcePortal.connectedRoom
        )
        let destinationPortal = RevivalPortalSelection(
            trustedRoomSourceIndex: sourcePortal.connectedRoom,
            portalIndex: sourcePortal.connectedPortal
        )
        let destination = level.rooms.first {
            $0.sourceIndex == sourcePortal.connectedRoom
        }!
        let destinationFace = RevivalFaceSelection(
            trustedRoomSourceIndex: sourcePortal.connectedRoom,
            faceIndex: destination.portals[sourcePortal.connectedPortal].faceIndex
        )
        room = destinationRoom
        face = destinationFace
        self.portal = destinationPortal
    }
}

struct RevivalPlaySession: Equatable, Sendable {
    let level: Level
    var playerView: PlayerView
    let cameraContainingRoomSourceIndex: Int

    init(level: Level, playerView: PlayerView) {
        self.level = level
        self.playerView = playerView
        cameraContainingRoomSourceIndex = playerView.roomSourceIndex
    }

    var camera: RoomCamera {
        get { playerView.camera }
        set {
            playerView = PlayerView(
                playerID: playerView.playerID,
                objectHandle: playerView.objectHandle,
                roomSourceIndex: playerView.roomSourceIndex,
                camera: newValue,
                collisionRadius: playerView.collisionRadius
            )
        }
    }

    func makePlayerSimulation(
        presentationReadyTimestamp: Double
    ) -> PlayerSimulation {
        PlayerSimulation(
            level: level,
            presentationReadyTimestamp: presentationReadyTimestamp
        )
    }
}

struct RevivalRoomNameEdit: Codable, Equatable, Sendable {
    let sourceIndex: Int
    let name: String?
}

struct RevivalFaceMaterialEdit: Codable, Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let texture: SourceResource
}

struct RevivalPortalRenderingEdit: Codable, Equatable, Sendable {
    let roomSourceIndex: Int
    let portalIndex: Int
    let rendersFace: Bool
}

struct RevivalRoomVertexEdit: Codable, Equatable, Sendable {
    let roomSourceIndex: Int
    let vertexIndex: Int
    let position: Vector3
}

struct RevivalRigidTransform: Codable, Equatable, Sendable {
    let position: Vector3
    let orientation: Matrix3
}

func quarterTurnedProjectOrientation(_ orientation: Matrix3) -> Matrix3 {
    .init(
        right: orientation.up,
        up: .init(
            x: -orientation.right.x,
            y: -orientation.right.y,
            z: -orientation.right.z
        ),
        forward: orientation.forward
    )
}

struct RevivalObjectTransformEdit: Codable, Equatable, Sendable {
    let handle: UInt32
    let location: SpatialLocation
    let transform: RevivalRigidTransform
}

struct RevivalPlayerStartTransformEdit: Codable, Equatable, Sendable {
    let playerID: Int
    let handle: UInt32
    let location: SpatialLocation
    let transform: RevivalRigidTransform
}

struct RevivalPlacementResult: Equatable, Sendable {
    let committedLocation: SpatialLocation
    let committedPosition: Vector3
    let diagnostic: String?
}

enum RevivalProjectDifference: Equatable, Sendable {
    case roomName(sourceIndex: Int, before: String?, after: String?)
    case faceMaterial(
        roomSourceIndex: Int,
        faceIndex: Int,
        before: SourceResource,
        after: SourceResource
    )
    case portalRendering(
        roomSourceIndex: Int,
        portalIndex: Int,
        before: Bool,
        after: Bool
    )
    case roomVertex(
        roomSourceIndex: Int,
        vertexIndex: Int,
        before: Vector3,
        after: Vector3
    )
    case objectTransform(
        handle: UInt32,
        beforeLocation: SpatialLocation,
        afterLocation: SpatialLocation,
        before: RevivalRigidTransform,
        after: RevivalRigidTransform
    )
    case playerStartTransform(
        playerID: Int,
        handle: UInt32,
        beforeLocation: SpatialLocation,
        afterLocation: SpatialLocation,
        before: RevivalRigidTransform,
        after: RevivalRigidTransform
    )

    var summary: String {
        switch self {
        case let .roomName(sourceIndex, before, after):
            "Room \(sourceIndex) name: \(before ?? "unnamed") → \(after ?? "unnamed")"
        case let .faceMaterial(roomSourceIndex, faceIndex, before, after):
            "Room \(roomSourceIndex) face \(faceIndex) material: \(before.sourceName) → \(after.sourceName)"
        case let .portalRendering(roomSourceIndex, portalIndex, before, after):
            "Room \(roomSourceIndex) portal \(portalIndex) renders face: \(before) → \(after)"
        case let .roomVertex(roomSourceIndex, vertexIndex, _, _):
            "Room \(roomSourceIndex) vertex \(vertexIndex) position changed"
        case let .objectTransform(handle, beforeLocation, afterLocation, _, _):
            "Object \(handle) transform changed; \(locationSummary(beforeLocation)) → \(locationSummary(afterLocation))"
        case let .playerStartTransform(
            playerID,
            handle,
            beforeLocation,
            afterLocation,
            _,
            _
        ):
            "Player \(playerID) start \(handle) transform changed; \(locationSummary(beforeLocation)) → \(locationSummary(afterLocation))"
        }
    }
}

struct RevivalProjectSource: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let base: CanonicalPackageReference
    var roomNameEdits: [RevivalRoomNameEdit]
    var faceMaterialEdits: [RevivalFaceMaterialEdit]
    var portalRenderingEdits: [RevivalPortalRenderingEdit]
    var roomVertexEdits: [RevivalRoomVertexEdit]
    var objectTransformEdits: [RevivalObjectTransformEdit]
    var playerStartTransformEdits: [RevivalPlayerStartTransformEdit]

    init(base: CanonicalPackageReference) {
        schemaVersion = 3
        self.base = base
        roomNameEdits = []
        faceMaterialEdits = []
        portalRenderingEdits = []
        roomVertexEdits = []
        objectTransformEdits = []
        playerStartTransformEdits = []
    }
}

struct RevivalProject: Equatable, Sendable {
    private(set) var source: RevivalProjectSource
    private let importedBase: Level
    private(set) var level: Level

    var baseReference: CanonicalPackageReference { source.base }
    var persistedSource: RevivalProjectSource { source }
    var trainingGalleryBarrierSourceDiagnostic: String? {
        level.trainingGalleryBarrier.map {
            "TrainingMission.cpp Script 032 / \($0.triggerName)"
        }
    }
    var trainingRobotGuidebotSourceDiagnostic: String? {
        level.trainingRobotGuidebotChain.map { chain in
            let robotName = level.objects.first {
                $0.handle == chain.destroyRobotObjectHandle
            }?.instanceName ?? "DestroyBot2"
            let navigation = level.indoorNavigation.map {
                "\($0.sourceWasVerified ? "verified" : "unverified") \($0.rooms.count) room records"
            } ?? "navigation unavailable"
            let radius = chain.guidebot.collisionRadius - 0.1
            return "TrainingMission.cpp Scripts 036 + 060 / \(robotName) + Guidebot / NODE/BOA route radius \(radius), \(navigation)"
        }
    }
    var trainingGuidebotReturnSourceDiagnostic: String? {
        guard let chain = level.trainingCameraMonitorChain?.returnToShip,
              let marker = level.objects.first(where: {
                  $0.handle == chain.markerLightObjectHandle
              }),
              let room = level.rooms.first(where: {
                  $0.sourceIndex == chain.barrierRoomSourceIndex
              }) else {
            return nil
        }
        return "TrainingMission.cpp Script 058 / \(marker.instanceName ?? "FlashLight-3") + \(room.name ?? "PortalRoom5")"
    }
    var trainingKillbotEntrySourceDiagnostic: String? {
        guard let returnChain =
                level.trainingCameraMonitorChain?.returnToShip,
              let entry = returnChain.killbotEntry,
              let room = level.rooms.first(where: {
                  $0.sourceIndex == returnChain.barrierRoomSourceIndex
              }) else {
            return nil
        }
        return "TrainingMission.cpp Scripts 042 + 039 / \(entry.triggerName) + \(room.name ?? "PortalRoom5")"
    }
    var trainingRASBot1DeathSourceDiagnostic: String? {
        guard let chain = level.trainingRASBot1DeathChain,
              let robot = level.objects.first(where: {
                  $0.handle == chain.robotObjectHandle
              }) else {
            return nil
        }
        return "TrainingMission.cpp Script 043 / \(robot.instanceName ?? "RASBot1") death"
    }
    var trainingRASBot2DeathSourceDiagnostic: String? {
        guard let chain = level.trainingRASBot2DeathChain,
              let robot = level.objects.first(where: {
                  $0.handle == chain.robotObjectHandle
              }) else {
            return nil
        }
        return "TrainingMission.cpp Script 044 / \(robot.instanceName ?? "RASBot2") death"
    }
    var trainingRASBot3DeathSourceDiagnostic: String? {
        guard let chain = level.trainingRASBot3DeathChain,
              let robot = level.objects.first(where: {
                  $0.handle == chain.robotObjectHandle
              }) else {
            return nil
        }
        return "TrainingMission.cpp Script 045 / \(robot.instanceName ?? "RASBot3") death"
    }
    var trainingRASBot4DeathSourceDiagnostic: String? {
        guard let chain = level.trainingRASBot4DeathChain,
              let robot = level.objects.first(where: {
                  $0.handle == chain.robotObjectHandle
              }) else {
            return nil
        }
        return "TrainingMission.cpp Script 046 / \(robot.instanceName ?? "RASBot4") death"
    }
    var trainingLastBot1DeathSourceDiagnostic: String? {
        guard let chain = level.trainingLastBot1DeathChain,
              let robot = level.objects.first(where: {
                  $0.handle == chain.robotObjectHandle
              }) else {
            return nil
        }
        return "TrainingMission.cpp Script 051 / \(robot.instanceName ?? "LastBot1") death"
    }
    var trainingLastBot2DeathSourceDiagnostic: String? {
        guard let chain = level.trainingLastBot2DeathChain,
              let robot = level.objects.first(where: {
                  $0.handle == chain.robotObjectHandle
              }) else {
            return nil
        }
        return "TrainingMission.cpp Script 052 / \(robot.instanceName ?? "LastBot2") death"
    }
    var trainingInvulnerabilityPickupSourceDiagnostic: String? {
        guard let chain = level.trainingInvulnerabilityPickupChain,
            let pickup = level.objects.first(where: {
                $0.handle == chain.pickupObjectHandle
            })
        else {
            return nil
        }
        return "TrainingMission.cpp Script 047 / \(pickup.instanceName ?? "InvulnPowerup2") pickup"
    }
    var trainingCloakPickupSourceDiagnostic: String? {
        guard let chain = level.trainingCloakPickupChain,
            let pickup = level.objects.first(where: {
                $0.handle == chain.pickupObjectHandle
            })
        else {
            return nil
        }
        return "TrainingMission.cpp Script 048 / \(pickup.instanceName ?? "CloakPowerup2") pickup"
    }
    var trainingLastRoomSourceDiagnostic: String? {
        guard let chain = level.trainingLastRoomChain,
            level.rooms.contains(where: {
                $0.sourceIndex == chain.barrierRoomSourceIndex
            })
        else {
            return nil
        }
        return "TrainingMission.cpp Scripts 034/049 / PortalRoom6 completion"
    }
    var trainingFinalRoomEntrySourceDiagnostic: String? {
        guard let chain = level.trainingFinalRoomEntryChain,
            level.triggers.contains(where: {
                $0.name == chain.triggerName
                    && $0.roomIndex == chain.triggerRoomSourceIndex
                    && $0.faceIndex == chain.triggerFaceIndex
            })
        else {
            return nil
        }
        return "TrainingMission.cpp Script 050 / Portal4 final combat entry"
    }
    var trainingGalleryBarrierIsOpen: Bool {
        guard let barrier = level.trainingGalleryBarrier,
              let room = level.rooms.first(where: {
                  $0.sourceIndex == barrier.barrierRoomSourceIndex
              }),
              let portalIndex = barrier.orderedPortalIndices.first else {
            return false
        }
        return room.portals[portalIndex].flags & 1 == 0
    }
    var trainingGuidebotReturnBarrierIsOpen: Bool {
        guard let barrier =
                level.trainingCameraMonitorChain?.returnToShip,
              let room = level.rooms.first(where: {
                  $0.sourceIndex == barrier.barrierRoomSourceIndex
              }),
              let portalIndex = barrier.orderedPortalIndices.first else {
            return false
        }
        return room.portals[portalIndex].flags & 1 == 0
    }
    var semanticDiff: [RevivalProjectDifference] {
        var differences = source.roomNameEdits.map { edit in
            RevivalProjectDifference.roomName(
                sourceIndex: edit.sourceIndex,
                before: importedBase.rooms.first {
                    $0.sourceIndex == edit.sourceIndex
                }!.name,
                after: edit.name
            )
        }
        differences.append(contentsOf: source.faceMaterialEdits.map { edit in
            .faceMaterial(
                roomSourceIndex: edit.roomSourceIndex,
                faceIndex: edit.faceIndex,
                before: importedBase.rooms.first {
                    $0.sourceIndex == edit.roomSourceIndex
                }!.faces[edit.faceIndex].texture,
                after: edit.texture
            )
        })
        differences.append(contentsOf: source.portalRenderingEdits.map { edit in
            .portalRendering(
                roomSourceIndex: edit.roomSourceIndex,
                portalIndex: edit.portalIndex,
                before: importedBase.rooms.first {
                    $0.sourceIndex == edit.roomSourceIndex
                }!.portals[edit.portalIndex].flags & 1 != 0,
                after: edit.rendersFace
            )
        })
        differences.append(contentsOf: source.roomVertexEdits.map { edit in
            .roomVertex(
                roomSourceIndex: edit.roomSourceIndex,
                vertexIndex: edit.vertexIndex,
                before: importedBase.rooms.first {
                    $0.sourceIndex == edit.roomSourceIndex
                }!.vertices[edit.vertexIndex],
                after: edit.position
            )
        })
        differences.append(contentsOf: source.objectTransformEdits.map { edit in
            .objectTransform(
                handle: edit.handle,
                beforeLocation: importedBase.objects.first {
                    $0.handle == edit.handle
                }!.location,
                afterLocation: edit.location,
                before: rigidTransform(of: importedBase.objects.first {
                    $0.handle == edit.handle
                }!),
                after: edit.transform
            )
        })
        differences.append(contentsOf: source.playerStartTransformEdits.map { edit in
            .playerStartTransform(
                playerID: edit.playerID,
                handle: edit.handle,
                beforeLocation: importedBase.objects.first {
                    $0.handle == edit.handle
                }!.location,
                afterLocation: edit.location,
                before: rigidTransform(of: importedBase.objects.first {
                    $0.handle == edit.handle
                }!),
                after: edit.transform
            )
        })
        return differences
    }

    init(activatedBase: ActivatedCanonicalPackage) throws {
        let importedBase = activatedBase.level
        let baseReference = activatedBase.reference
        source = RevivalProjectSource(base: baseReference)
        self.importedBase = importedBase
        level = importedBase
        try validate()
    }

    init(
        source: RevivalProjectSource,
        library: CanonicalPackageLibrary
    ) throws {
        guard source.schemaVersion == 3 else {
            throw RevivalProjectError.unsupportedSchema(source.schemaVersion)
        }
        let importedBase = try library.load(source.base)

        var previousSourceIndex: Int?
        var materializedLevel = importedBase
        for edit in source.roomNameEdits {
            guard previousSourceIndex.map({ $0 < edit.sourceIndex }) ?? true,
                  let roomIndex = materializedLevel.rooms.firstIndex(where: {
                      $0.sourceIndex == edit.sourceIndex
                  }),
                  let baseRoom = importedBase.rooms.first(where: {
                      $0.sourceIndex == edit.sourceIndex
                  }),
                  baseRoom.name != edit.name else {
                throw RevivalProjectError.invalidRoomNameEdit(edit.sourceIndex)
            }
            try validateRoomName(edit.name)
            materializedLevel.rooms[roomIndex].name = edit.name
            previousSourceIndex = edit.sourceIndex
        }
        var previousFaceIdentity: (Int, Int)?
        for edit in source.faceMaterialEdits {
            let identity = (edit.roomSourceIndex, edit.faceIndex)
            guard previousFaceIdentity.map({ $0 < identity }) ?? true,
                  let roomIndex = materializedLevel.rooms.firstIndex(where: {
                      $0.sourceIndex == edit.roomSourceIndex
                  }),
                  materializedLevel.rooms[roomIndex].faces.indices.contains(edit.faceIndex),
                  let baseRoom = importedBase.rooms.first(where: {
                      $0.sourceIndex == edit.roomSourceIndex
                  }),
                  baseRoom.faces[edit.faceIndex].texture != edit.texture,
                  materializedLevel.presentationMaterials.contains(where: {
                      $0.texture == edit.texture
                  }) else {
                throw RevivalProjectError.invalidFaceMaterialEdit(
                    roomSourceIndex: edit.roomSourceIndex,
                    faceIndex: edit.faceIndex
                )
            }
            materializedLevel.rooms[roomIndex].faces[edit.faceIndex].texture = edit.texture
            previousFaceIdentity = identity
        }
        var previousPortalIdentity: (Int, Int)?
        for edit in source.portalRenderingEdits {
            let identity = (edit.roomSourceIndex, edit.portalIndex)
            guard previousPortalIdentity.map({ $0 < identity }) ?? true,
                  let roomIndex = materializedLevel.rooms.firstIndex(where: {
                      $0.sourceIndex == edit.roomSourceIndex
                  }),
                  materializedLevel.rooms[roomIndex].portals.indices.contains(edit.portalIndex),
                  let baseRoom = importedBase.rooms.first(where: {
                      $0.sourceIndex == edit.roomSourceIndex
                  }),
                  (baseRoom.portals[edit.portalIndex].flags & 1 != 0) != edit.rendersFace else {
                throw RevivalProjectError.invalidPortalRenderingEdit(
                    roomSourceIndex: edit.roomSourceIndex,
                    portalIndex: edit.portalIndex
                )
            }
            guard baseRoom.portals[edit.portalIndex].flags & combinedPortalFlag == 0 else {
                throw RevivalProjectError.combinedPortalRenderingEditDeferred(
                    roomSourceIndex: edit.roomSourceIndex,
                    portalIndex: edit.portalIndex
                )
            }
            materializedLevel.rooms[roomIndex].portals[edit.portalIndex].flags =
                portalFlags(
                    materializedLevel.rooms[roomIndex].portals[edit.portalIndex].flags,
                    rendersFace: edit.rendersFace
                )
            previousPortalIdentity = identity
        }
        var previousVertexIdentity: (Int, Int)?
        for edit in source.roomVertexEdits {
            let identity = (edit.roomSourceIndex, edit.vertexIndex)
            guard previousVertexIdentity.map({ $0 < identity }) ?? true,
                  let roomIndex = materializedLevel.rooms.firstIndex(where: {
                      $0.sourceIndex == edit.roomSourceIndex
                  }),
                  materializedLevel.rooms[roomIndex].vertices.indices.contains(edit.vertexIndex),
                  let baseRoom = importedBase.rooms.first(where: {
                      $0.sourceIndex == edit.roomSourceIndex
                  }),
                  baseRoom.vertices[edit.vertexIndex] != edit.position,
                  isFiniteProjectPosition(edit.position) else {
                throw RevivalProjectError.invalidRoomVertexEdit(
                    roomSourceIndex: edit.roomSourceIndex,
                    vertexIndex: edit.vertexIndex
                )
            }
            materializedLevel.rooms[roomIndex].vertices[edit.vertexIndex] = edit.position
            previousVertexIdentity = identity
        }
        var previousObjectHandle: UInt32?
        for edit in source.objectTransformEdits {
            guard previousObjectHandle.map({ $0 < edit.handle }) ?? true,
                  let objectIndex = materializedLevel.objects.firstIndex(where: {
                      $0.handle == edit.handle
                  }),
                  materializedLevel.objects[objectIndex].type != D3SourceIdentity.playerObjectType,
                  let baseObject = importedBase.objects.first(where: {
                      $0.handle == edit.handle
                  }),
                  (baseObject.location != edit.location
                    || rigidTransform(of: baseObject) != edit.transform),
                  isValidRigidTransform(edit.transform) else {
                throw RevivalProjectError.invalidObjectTransformEdit(edit.handle)
            }
            materializedLevel.objects[objectIndex].location = edit.location
            materializedLevel.objects[objectIndex].position = edit.transform.position
            materializedLevel.objects[objectIndex].orientation = edit.transform.orientation
            previousObjectHandle = edit.handle
        }
        var previousPlayerIdentity: (Int, UInt32)?
        for edit in source.playerStartTransformEdits {
            let identity = (edit.playerID, edit.handle)
            guard previousPlayerIdentity.map({ $0 < identity }) ?? true,
                  let objectIndex = materializedLevel.objects.firstIndex(where: {
                      $0.handle == edit.handle
                  }),
                  materializedLevel.objects[objectIndex].type == D3SourceIdentity.playerObjectType,
                  materializedLevel.objects[objectIndex].storedID == edit.playerID,
                  let baseObject = importedBase.objects.first(where: {
                      $0.handle == edit.handle
                  }),
                  (baseObject.location != edit.location
                    || rigidTransform(of: baseObject) != edit.transform),
                  isValidRigidTransform(edit.transform) else {
                throw RevivalProjectError.invalidPlayerStartTransformEdit(
                    playerID: edit.playerID,
                    handle: edit.handle
                )
            }
            materializedLevel.objects[objectIndex].location = edit.location
            materializedLevel.objects[objectIndex].position = edit.transform.position
            materializedLevel.objects[objectIndex].orientation = edit.transform.orientation
            previousPlayerIdentity = identity
        }
        self.source = source
        self.importedBase = importedBase
        level = materializedLevel
        do {
            try validate()
        } catch let error as LevelValidationError {
            throw attributedProjectValidationError(
                error,
                level: materializedLevel,
                importedBase: importedBase,
                source: source
            )
        }
    }

    @discardableResult
    mutating func renameRoom(
        sourceIndex: Int,
        to proposedName: String
    ) throws -> String? {
        guard let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == sourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(sourceIndex)
        }

        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? nil : trimmedName
        try validateRoomName(name)
        let previousName = level.rooms[roomIndex].name
        guard previousName != name else {
            throw RevivalProjectError.unchangedRoomName
        }
        if let name, level.rooms.enumerated().contains(where: { index, room in
            index != roomIndex && room.name?.caseInsensitiveCompare(name) == .orderedSame
        }) {
            throw RevivalProjectError.duplicateRoomName(name.lowercased())
        }

        level.rooms[roomIndex].name = name
        updateRoomNameEdit(sourceIndex: sourceIndex)
        return previousName
    }

    @discardableResult
    mutating func setFaceMaterial(
        roomSourceIndex: Int,
        faceIndex: Int,
        to texture: SourceResource
    ) throws -> SourceResource {
        guard let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == roomSourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(roomSourceIndex)
        }
        guard level.rooms[roomIndex].faces.indices.contains(faceIndex) else {
            throw RevivalProjectError.faceMissing(
                roomSourceIndex: roomSourceIndex,
                faceIndex: faceIndex
            )
        }
        guard level.presentationMaterials.contains(where: { $0.texture == texture }) else {
            throw RevivalProjectError.materialUnavailable(texture)
        }
        let previous = level.rooms[roomIndex].faces[faceIndex].texture
        guard previous != texture else { throw RevivalProjectError.unchangedProperty }
        var candidate = level
        candidate.rooms[roomIndex].faces[faceIndex].texture = texture
        do {
            try candidate.validate()
        } catch let error as LevelValidationError {
            if case .invalidDependency = error {
                throw RevivalProjectError.faceEditRejected(
                    roomSourceIndex: roomSourceIndex,
                    faceIndex: faceIndex
                )
            }
            preconditionFailure("Validated face edit broke an unrelated level invariant: \(error)")
        }
        level = candidate
        updateFaceMaterialEdit(roomSourceIndex: roomSourceIndex, faceIndex: faceIndex)
        return previous
    }

    @discardableResult
    mutating func setPortalRendersFace(
        roomSourceIndex: Int,
        portalIndex: Int,
        to rendersFace: Bool
    ) throws -> Bool {
        guard let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == roomSourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(roomSourceIndex)
        }
        guard level.rooms[roomIndex].portals.indices.contains(portalIndex) else {
            throw RevivalProjectError.portalMissing(
                roomSourceIndex: roomSourceIndex,
                portalIndex: portalIndex
            )
        }
        guard level.rooms[roomIndex].portals[portalIndex].flags & combinedPortalFlag == 0 else {
            throw RevivalProjectError.combinedPortalRenderingEditDeferred(
                roomSourceIndex: roomSourceIndex,
                portalIndex: portalIndex
            )
        }
        let previous = level.rooms[roomIndex].portals[portalIndex].flags & 1 != 0
        guard previous != rendersFace else { throw RevivalProjectError.unchangedProperty }
        var candidate = level
        candidate.rooms[roomIndex].portals[portalIndex].flags = portalFlags(
            candidate.rooms[roomIndex].portals[portalIndex].flags,
            rendersFace: rendersFace
        )
        do {
            try candidate.validate()
        } catch let error as LevelValidationError {
            switch error {
            case .invalidDependency:
                throw RevivalProjectError.portalEditRejected(
                    roomSourceIndex: roomSourceIndex,
                    portalIndex: portalIndex
                )
            default:
                preconditionFailure("Validated portal edit broke an unrelated level invariant: \(error)")
            }
        }
        level = candidate
        updatePortalRenderingEdit(roomSourceIndex: roomSourceIndex, portalIndex: portalIndex)
        return previous
    }

    func isTrainingGalleryBarrierPortal(
        roomSourceIndex: Int,
        portalIndex: Int
    ) -> Bool {
        guard let barrier = level.trainingGalleryBarrier,
              let room = level.rooms.first(where: {
                  $0.sourceIndex == barrier.barrierRoomSourceIndex
              }) else {
            return false
        }
        for barrierPortalIndex in barrier.orderedPortalIndices {
            if roomSourceIndex == room.sourceIndex,
               portalIndex == barrierPortalIndex {
                return true
            }
            let portal = room.portals[barrierPortalIndex]
            if roomSourceIndex == portal.connectedRoom,
               portalIndex == portal.connectedPortal {
                return true
            }
        }
        return false
    }

    func isTrainingGuidebotReturnBarrierPortal(
        roomSourceIndex: Int,
        portalIndex: Int
    ) -> Bool {
        guard let barrier =
                level.trainingCameraMonitorChain?.returnToShip,
              let room = level.rooms.first(where: {
                  $0.sourceIndex == barrier.barrierRoomSourceIndex
              }) else {
            return false
        }
        for barrierPortalIndex in barrier.orderedPortalIndices {
            if roomSourceIndex == room.sourceIndex,
               portalIndex == barrierPortalIndex {
                return true
            }
            let portal = room.portals[barrierPortalIndex]
            if roomSourceIndex == portal.connectedRoom,
               portalIndex == portal.connectedPortal {
                return true
            }
        }
        return false
    }

    @discardableResult
    mutating func setTrainingGalleryBarrierOpen(
        _ isOpen: Bool
    ) throws -> Bool {
        guard let barrier = level.trainingGalleryBarrier,
              let barrierRoomIndex = level.rooms.firstIndex(where: {
                  $0.sourceIndex == barrier.barrierRoomSourceIndex
              }) else {
            throw RevivalProjectError.trainingGalleryBarrierUnavailable
        }
        let previous = trainingGalleryBarrierIsOpen
        guard previous != isOpen else {
            throw RevivalProjectError.unchangedProperty
        }

        var candidate = level
        var editedPortals: [(roomSourceIndex: Int, portalIndex: Int)] = []
        for portalIndex in barrier.orderedPortalIndices {
            let portal = candidate.rooms[barrierRoomIndex].portals[portalIndex]
            candidate.rooms[barrierRoomIndex].portals[portalIndex].flags =
                portalFlags(portal.flags, rendersFace: !isOpen)
            editedPortals.append((
                roomSourceIndex: barrier.barrierRoomSourceIndex,
                portalIndex: portalIndex
            ))

            let connectedRoomIndex = candidate.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            }!
            let reciprocal = candidate.rooms[connectedRoomIndex]
                .portals[portal.connectedPortal]
            candidate.rooms[connectedRoomIndex]
                .portals[portal.connectedPortal].flags = portalFlags(
                    reciprocal.flags,
                    rendersFace: !isOpen
                )
            editedPortals.append((
                roomSourceIndex: portal.connectedRoom,
                portalIndex: portal.connectedPortal
            ))
        }
        do {
            try candidate.validate()
        } catch {
            throw RevivalProjectError.trainingGalleryBarrierEditRejected
        }
        level = candidate
        for portal in editedPortals {
            updatePortalRenderingEdit(
                roomSourceIndex: portal.roomSourceIndex,
                portalIndex: portal.portalIndex
            )
        }
        return previous
    }

    @discardableResult
    mutating func setTrainingGuidebotReturnBarrierOpen(
        _ isOpen: Bool
    ) throws -> Bool {
        guard let barrier =
                level.trainingCameraMonitorChain?.returnToShip,
              let barrierRoomIndex = level.rooms.firstIndex(where: {
                  $0.sourceIndex == barrier.barrierRoomSourceIndex
              }) else {
            throw RevivalProjectError
                .trainingGuidebotReturnBarrierUnavailable
        }
        let previous = trainingGuidebotReturnBarrierIsOpen
        guard previous != isOpen else {
            throw RevivalProjectError.unchangedProperty
        }
        var candidate = level
        var editedPortals: [(Int, Int)] = []
        for portalIndex in barrier.orderedPortalIndices {
            let portal =
                candidate.rooms[barrierRoomIndex].portals[portalIndex]
            candidate.rooms[barrierRoomIndex].portals[portalIndex].flags =
                portalFlags(portal.flags, rendersFace: !isOpen)
            editedPortals.append((
                barrier.barrierRoomSourceIndex,
                portalIndex
            ))
            let connectedRoomIndex = candidate.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            }!
            let reciprocal = candidate.rooms[connectedRoomIndex]
                .portals[portal.connectedPortal]
            candidate.rooms[connectedRoomIndex]
                .portals[portal.connectedPortal].flags = portalFlags(
                    reciprocal.flags,
                    rendersFace: !isOpen
                )
            editedPortals.append((
                portal.connectedRoom,
                portal.connectedPortal
            ))
        }
        do {
            try candidate.validate()
        } catch {
            throw RevivalProjectError
                .trainingGuidebotReturnBarrierEditRejected
        }
        level = candidate
        for portal in editedPortals {
            updatePortalRenderingEdit(
                roomSourceIndex: portal.0,
                portalIndex: portal.1
            )
        }
        return previous
    }

    @discardableResult
    mutating func setRoomVertex(
        roomSourceIndex: Int,
        vertexIndex: Int,
        to position: Vector3
    ) throws -> Vector3 {
        guard let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == roomSourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(roomSourceIndex)
        }
        guard level.rooms[roomIndex].vertices.indices.contains(vertexIndex) else {
            throw RevivalProjectError.vertexMissing(
                roomSourceIndex: roomSourceIndex,
                vertexIndex: vertexIndex
            )
        }
        guard isFiniteProjectPosition(position) else {
            throw RevivalProjectError.invalidRoomVertexEdit(
                roomSourceIndex: roomSourceIndex,
                vertexIndex: vertexIndex
            )
        }
        let previous = level.rooms[roomIndex].vertices[vertexIndex]
        guard previous != position else { throw RevivalProjectError.unchangedProperty }
        var candidate = level
        candidate.rooms[roomIndex].vertices[vertexIndex] = position
        do {
            try candidate.validate()
        } catch let error as LevelValidationError {
            throw RevivalProjectError.roomVertexEditRejected(
                roomSourceIndex: roomSourceIndex,
                vertexIndex: vertexIndex,
                reason: String(describing: error)
            )
        }
        try validateAuthoredIndoorOwnership(
            in: candidate,
            editedRoomSourceIndices: Set([roomSourceIndex]),
            editedObjectHandles: []
        )
        level = candidate
        updateRoomVertexEdit(
            roomSourceIndex: roomSourceIndex,
            vertexIndex: vertexIndex
        )
        return previous
    }

    @discardableResult
    mutating func snapRoomVertex(
        roomSourceIndex: Int,
        vertexIndex: Int,
        toRoomSourceIndex: Int,
        toVertexIndex: Int
    ) throws -> Vector3 {
        guard let targetRoom = level.rooms.first(where: {
            $0.sourceIndex == toRoomSourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(toRoomSourceIndex)
        }
        guard targetRoom.vertices.indices.contains(toVertexIndex) else {
            throw RevivalProjectError.vertexMissing(
                roomSourceIndex: toRoomSourceIndex,
                vertexIndex: toVertexIndex
            )
        }
        return try setRoomVertex(
            roomSourceIndex: roomSourceIndex,
            vertexIndex: vertexIndex,
            to: targetRoom.vertices[toVertexIndex]
        )
    }

    @discardableResult
    mutating func setObjectTransform(
        handle: UInt32,
        to transform: RevivalRigidTransform
    ) throws -> RevivalRigidTransform {
        guard let objectIndex = level.objects.firstIndex(where: { $0.handle == handle }) else {
            throw RevivalProjectError.objectMissing(handle)
        }
        guard level.objects[objectIndex].type != D3SourceIdentity.playerObjectType else {
            throw RevivalProjectError.objectIsPlayer(handle)
        }
        let previous = rigidTransform(of: level.objects[objectIndex])
        guard previous != transform else { throw RevivalProjectError.unchangedProperty }
        guard previous.position == transform.position else {
            throw RevivalProjectError.invalidObjectTransformEdit(handle)
        }
        guard isValidRigidTransform(transform) else {
            throw RevivalProjectError.invalidObjectTransformEdit(handle)
        }
        var candidate = level
        candidate.objects[objectIndex].position = transform.position
        candidate.objects[objectIndex].orientation = transform.orientation
        do {
            try candidate.validate()
        } catch let error as LevelValidationError {
            preconditionFailure("Validated object orientation broke an unrelated level invariant: \(error)")
        }
        level = candidate
        updateObjectTransformEdit(handle: handle)
        return previous
    }

    @discardableResult
    mutating func rotateObjectQuarterTurn(handle: UInt32) throws -> RevivalRigidTransform {
        guard let object = level.objects.first(where: { $0.handle == handle }) else {
            throw RevivalProjectError.objectMissing(handle)
        }
        return try setObjectTransform(
            handle: handle,
            to: .init(
                position: object.position,
                orientation: quarterTurnedProjectOrientation(object.orientation)
            )
        )
    }

    @discardableResult
    mutating func setPlayerStartTransform(
        playerID: Int,
        handle: UInt32,
        to transform: RevivalRigidTransform
    ) throws -> RevivalRigidTransform {
        guard let objectIndex = level.objects.firstIndex(where: { $0.handle == handle }),
              level.objects[objectIndex].type == D3SourceIdentity.playerObjectType,
              level.objects[objectIndex].storedID == playerID else {
            throw RevivalProjectError.playerStartMissing(playerID: playerID, handle: handle)
        }
        let previous = rigidTransform(of: level.objects[objectIndex])
        guard previous != transform else { throw RevivalProjectError.unchangedProperty }
        guard previous.position == transform.position else {
            throw RevivalProjectError.invalidPlayerStartTransformEdit(
                playerID: playerID,
                handle: handle
            )
        }
        guard isValidRigidTransform(transform) else {
            throw RevivalProjectError.invalidPlayerStartTransformEdit(
                playerID: playerID,
                handle: handle
            )
        }
        var candidate = level
        candidate.objects[objectIndex].position = transform.position
        candidate.objects[objectIndex].orientation = transform.orientation
        do {
            try candidate.validate()
        } catch let error as LevelValidationError {
            preconditionFailure("Validated player-start orientation broke an unrelated level invariant: \(error)")
        }
        level = candidate
        updatePlayerStartTransformEdit(playerID: playerID, handle: handle)
        return previous
    }

    @discardableResult
    mutating func rotatePlayerStartQuarterTurn(
        playerID: Int,
        handle: UInt32
    ) throws -> RevivalRigidTransform {
        guard let playerStart = level.objects.first(where: { $0.handle == handle }) else {
            throw RevivalProjectError.objectMissing(handle)
        }
        return try setPlayerStartTransform(
            playerID: playerID,
            handle: handle,
            to: .init(
                position: playerStart.position,
                orientation: quarterTurnedProjectOrientation(playerStart.orientation)
            )
        )
    }

    @discardableResult
    mutating func moveObject(
        handle: UInt32,
        to proposedPosition: Vector3
    ) throws -> RevivalPlacementResult {
        guard let objectIndex = level.objects.firstIndex(where: {
            $0.handle == handle
        }) else {
            throw RevivalProjectError.objectMissing(handle)
        }
        guard level.objects[objectIndex].type != D3SourceIdentity.playerObjectType else {
            throw RevivalProjectError.objectIsPlayer(handle)
        }
        return try moveObject(
            at: objectIndex,
            owner: "Object \(handle)",
            proposedPosition: proposedPosition,
            radius: editorPlacementRadius(
                for: level.objects[objectIndex],
                in: level
            )
        )
    }

    @discardableResult
    mutating func movePlayerStart(
        playerID: Int,
        handle: UInt32,
        to proposedPosition: Vector3
    ) throws -> RevivalPlacementResult {
        guard let objectIndex = level.objects.firstIndex(where: {
            $0.handle == handle
                && $0.type == D3SourceIdentity.playerObjectType
                && $0.storedID == playerID
        }) else {
            throw RevivalProjectError.playerStartMissing(
                playerID: playerID,
                handle: handle
            )
        }
        let radius = level.defaultPlayerBinding.map { binding in
            binding.objectHandle == handle
                ? level.shipDefinitions.first { $0.source == binding.ship }!.presentationSize * 0.8
                : 0
        } ?? 0
        return try moveObject(
            at: objectIndex,
            owner: "Player \(playerID) start \(handle)",
            proposedPosition: proposedPosition,
            radius: radius
        )
    }

    func validate() throws {
        guard source.schemaVersion == 3 else {
            throw RevivalProjectError.unsupportedSchema(source.schemaVersion)
        }
        guard importedBase.missionKey == source.base.missionKey,
              importedBase.levelKey == source.base.levelKey,
              level.missionKey == source.base.missionKey,
              level.levelKey == source.base.levelKey else {
            throw RevivalProjectError.baseIdentityMismatch
        }

        var roomNames: [String] = []
        for room in level.rooms {
            guard let name = room.name else { continue }
            try validateRoomName(name)
            guard !roomNames.contains(where: {
                $0.caseInsensitiveCompare(name) == .orderedSame
            }) else {
                throw RevivalProjectError.duplicateRoomName(name.lowercased())
            }
            roomNames.append(name)
        }

        var expectedEdits: [RevivalRoomNameEdit] = []
        for room in level.rooms {
            guard let baseRoom = importedBase.rooms.first(where: {
                $0.sourceIndex == room.sourceIndex
            }) else {
                throw RevivalProjectError.roomMissing(room.sourceIndex)
            }
            if baseRoom.name != room.name {
                expectedEdits.append(.init(sourceIndex: room.sourceIndex, name: room.name))
            }
        }
        expectedEdits.sort { $0.sourceIndex < $1.sourceIndex }
        guard source.roomNameEdits == expectedEdits else {
            let sourceIndex = source.roomNameEdits.first?.sourceIndex
                ?? expectedEdits.first?.sourceIndex
                ?? -1
            throw RevivalProjectError.invalidRoomNameEdit(sourceIndex)
        }

        var expectedFaceEdits: [RevivalFaceMaterialEdit] = []
        var expectedPortalEdits: [RevivalPortalRenderingEdit] = []
        var expectedVertexEdits: [RevivalRoomVertexEdit] = []
        for room in level.rooms {
            guard let baseRoom = importedBase.rooms.first(where: {
                $0.sourceIndex == room.sourceIndex
            }) else {
                throw RevivalProjectError.roomMissing(room.sourceIndex)
            }
            for faceIndex in room.faces.indices
                where room.faces[faceIndex].texture != baseRoom.faces[faceIndex].texture {
                expectedFaceEdits.append(.init(
                    roomSourceIndex: room.sourceIndex,
                    faceIndex: faceIndex,
                    texture: room.faces[faceIndex].texture
                ))
            }
            for portalIndex in room.portals.indices {
                let rendersFace = room.portals[portalIndex].flags & 1 != 0
                let baseRendersFace = baseRoom.portals[portalIndex].flags & 1 != 0
                if rendersFace != baseRendersFace {
                    expectedPortalEdits.append(.init(
                        roomSourceIndex: room.sourceIndex,
                        portalIndex: portalIndex,
                        rendersFace: rendersFace
                    ))
                }
            }
            for vertexIndex in room.vertices.indices
            where room.vertices[vertexIndex] != baseRoom.vertices[vertexIndex] {
                expectedVertexEdits.append(.init(
                    roomSourceIndex: room.sourceIndex,
                    vertexIndex: vertexIndex,
                    position: room.vertices[vertexIndex]
                ))
            }
        }
        expectedFaceEdits.sort { ($0.roomSourceIndex, $0.faceIndex) < ($1.roomSourceIndex, $1.faceIndex) }
        expectedPortalEdits.sort { ($0.roomSourceIndex, $0.portalIndex) < ($1.roomSourceIndex, $1.portalIndex) }
        expectedVertexEdits.sort {
            ($0.roomSourceIndex, $0.vertexIndex) < ($1.roomSourceIndex, $1.vertexIndex)
        }
        guard source.faceMaterialEdits == expectedFaceEdits else {
            let identity = source.faceMaterialEdits.first ?? expectedFaceEdits.first!
            throw RevivalProjectError.invalidFaceMaterialEdit(
                roomSourceIndex: identity.roomSourceIndex,
                faceIndex: identity.faceIndex
            )
        }
        guard source.portalRenderingEdits == expectedPortalEdits else {
            let identity = source.portalRenderingEdits.first ?? expectedPortalEdits.first!
            throw RevivalProjectError.invalidPortalRenderingEdit(
                roomSourceIndex: identity.roomSourceIndex,
                portalIndex: identity.portalIndex
            )
        }
        guard source.roomVertexEdits == expectedVertexEdits else {
            let identity = source.roomVertexEdits.first ?? expectedVertexEdits.first!
            throw RevivalProjectError.invalidRoomVertexEdit(
                roomSourceIndex: identity.roomSourceIndex,
                vertexIndex: identity.vertexIndex
            )
        }
        var expectedObjectEdits: [RevivalObjectTransformEdit] = []
        var expectedPlayerEdits: [RevivalPlayerStartTransformEdit] = []
        for object in level.objects {
            guard let baseObject = importedBase.objects.first(where: {
                $0.handle == object.handle
            }) else {
                throw RevivalProjectError.objectMissing(object.handle)
            }
            let transform = rigidTransform(of: object)
            guard object.location != baseObject.location
                    || transform != rigidTransform(of: baseObject) else {
                continue
            }
            if object.type == D3SourceIdentity.playerObjectType {
                expectedPlayerEdits.append(.init(
                    playerID: object.storedID,
                    handle: object.handle,
                    location: object.location,
                    transform: transform
                ))
            } else {
                expectedObjectEdits.append(.init(
                    handle: object.handle,
                    location: object.location,
                    transform: transform
                ))
            }
        }
        expectedObjectEdits.sort { $0.handle < $1.handle }
        expectedPlayerEdits.sort { ($0.playerID, $0.handle) < ($1.playerID, $1.handle) }
        guard source.objectTransformEdits == expectedObjectEdits else {
            let handle = source.objectTransformEdits.first?.handle
                ?? expectedObjectEdits.first?.handle
                ?? 0
            throw RevivalProjectError.invalidObjectTransformEdit(handle)
        }
        guard source.playerStartTransformEdits == expectedPlayerEdits else {
            let identity = source.playerStartTransformEdits.first
                ?? expectedPlayerEdits.first!
            throw RevivalProjectError.invalidPlayerStartTransformEdit(
                playerID: identity.playerID,
                handle: identity.handle
            )
        }
        try level.validate()
        try validateAuthoredIndoorOwnership(
            in: level,
            editedRoomSourceIndices: Set(source.roomVertexEdits.map(\.roomSourceIndex)),
            editedObjectHandles: placementEditedHandles(
                source: source,
                importedBase: importedBase
            )
        )
    }

    @discardableResult
    mutating func restoreRoomName(
        sourceIndex: Int,
        to name: String?
    ) throws -> String? {
        guard let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == sourceIndex
        }) else {
            throw RevivalProjectError.roomMissing(sourceIndex)
        }

        let previousName = level.rooms[roomIndex].name
        try validateRoomName(name)
        level.rooms[roomIndex].name = name
        updateRoomNameEdit(sourceIndex: sourceIndex)
        return previousName
    }

    func makePlayerPlaySession() -> RevivalPlaySession {
        RevivalPlaySession(level: level, playerView: defaultPlayerView(in: level))
    }

    private mutating func updateRoomNameEdit(sourceIndex: Int) {
        let baseName = importedBase.rooms.first {
            $0.sourceIndex == sourceIndex
        }!.name
        let currentName = level.rooms.first {
            $0.sourceIndex == sourceIndex
        }!.name
        source.roomNameEdits.removeAll { $0.sourceIndex == sourceIndex }
        if baseName != currentName {
            source.roomNameEdits.append(.init(sourceIndex: sourceIndex, name: currentName))
            source.roomNameEdits.sort { $0.sourceIndex < $1.sourceIndex }
        }
    }

    private mutating func moveObject(
        at objectIndex: Int,
        owner: String,
        proposedPosition: Vector3,
        radius: Float
    ) throws -> RevivalPlacementResult {
        guard isFiniteProjectPosition(proposedPosition),
              case let .room(startRoom) = level.objects[objectIndex].location else {
            throw RevivalProjectError.placementHasNoContainingRoom(owner: owner)
        }
        let object = level.objects[objectIndex]
        guard object.position != proposedPosition else {
            throw RevivalProjectError.unchangedProperty
        }
        let trace = traceIndoorMovement(
            in: level,
            startRoom: startRoom,
            start: object.position,
            end: proposedPosition,
            radius: radius
        )
        if case let .wallHit(contact) = trace.outcome,
           contact.distance < 0.1 {
            throw RevivalProjectError.placementBlocked(
                owner: owner,
                roomSourceIndex: contact.roomSourceIndex,
                faceIndex: contact.faceIndex
            )
        }
        let containingRoom: Int
        switch trace.outcome {
        case .noHit:
            guard let ownerRoom = containingIndoorRoomSourceIndex(
                in: level,
                position: trace.finalPosition,
                candidates: trace.visitedRoomSourceIndices
            ) else {
                throw RevivalProjectError.placementHasNoContainingRoom(owner: owner)
            }
            containingRoom = ownerRoom
        case .wallHit:
            containingRoom = trace.containingRoomSourceIndex
        }

        var candidate = level
        candidate.objects[objectIndex].location = .room(containingRoom)
        candidate.objects[objectIndex].position = trace.finalPosition
        try candidate.validate()
        level = candidate
        if object.type == D3SourceIdentity.playerObjectType {
            updatePlayerStartTransformEdit(
                playerID: object.storedID,
                handle: object.handle
            )
        } else {
            updateObjectTransformEdit(handle: object.handle)
        }
        let diagnostic: String?
        if case let .wallHit(contact) = trace.outcome {
            diagnostic = "\(owner) stopped at source room \(contact.roomSourceIndex) face \(contact.faceIndex) and remains owned by source room \(containingRoom)."
        } else if object.handle
                    == level.trainingCameraMonitorChain?
                        .securityCameraObjectHandle {
            diagnostic =
                "Moved TrainingMission.cpp Script 059 SecurityCamera handle \(object.handle) for the Camera Monitor popup. Undo action: Move Object."
        } else {
            diagnostic = nil
        }
        return RevivalPlacementResult(
            committedLocation: .room(containingRoom),
            committedPosition: trace.finalPosition,
            diagnostic: diagnostic
        )
    }

    private mutating func updateFaceMaterialEdit(roomSourceIndex: Int, faceIndex: Int) {
        let base = importedBase.rooms.first { $0.sourceIndex == roomSourceIndex }!.faces[faceIndex]
        let current = level.rooms.first { $0.sourceIndex == roomSourceIndex }!.faces[faceIndex]
        source.faceMaterialEdits.removeAll {
            $0.roomSourceIndex == roomSourceIndex && $0.faceIndex == faceIndex
        }
        if base.texture != current.texture {
            source.faceMaterialEdits.append(.init(
                roomSourceIndex: roomSourceIndex,
                faceIndex: faceIndex,
                texture: current.texture
            ))
            source.faceMaterialEdits.sort {
                ($0.roomSourceIndex, $0.faceIndex) < ($1.roomSourceIndex, $1.faceIndex)
            }
        }
    }

    private mutating func updatePortalRenderingEdit(roomSourceIndex: Int, portalIndex: Int) {
        let base = importedBase.rooms.first { $0.sourceIndex == roomSourceIndex }!.portals[portalIndex]
        let current = level.rooms.first { $0.sourceIndex == roomSourceIndex }!.portals[portalIndex]
        source.portalRenderingEdits.removeAll {
            $0.roomSourceIndex == roomSourceIndex && $0.portalIndex == portalIndex
        }
        let baseRendersFace = base.flags & 1 != 0
        let rendersFace = current.flags & 1 != 0
        if baseRendersFace != rendersFace {
            source.portalRenderingEdits.append(.init(
                roomSourceIndex: roomSourceIndex,
                portalIndex: portalIndex,
                rendersFace: rendersFace
            ))
            source.portalRenderingEdits.sort {
                ($0.roomSourceIndex, $0.portalIndex) < ($1.roomSourceIndex, $1.portalIndex)
            }
        }
    }

    private mutating func updateRoomVertexEdit(
        roomSourceIndex: Int,
        vertexIndex: Int
    ) {
        let base = importedBase.rooms.first {
            $0.sourceIndex == roomSourceIndex
        }!.vertices[vertexIndex]
        let current = level.rooms.first {
            $0.sourceIndex == roomSourceIndex
        }!.vertices[vertexIndex]
        source.roomVertexEdits.removeAll {
            $0.roomSourceIndex == roomSourceIndex && $0.vertexIndex == vertexIndex
        }
        if base != current {
            source.roomVertexEdits.append(.init(
                roomSourceIndex: roomSourceIndex,
                vertexIndex: vertexIndex,
                position: current
            ))
            source.roomVertexEdits.sort {
                ($0.roomSourceIndex, $0.vertexIndex) < ($1.roomSourceIndex, $1.vertexIndex)
            }
        }
    }

    private mutating func updateObjectTransformEdit(handle: UInt32) {
        let base = importedBase.objects.first { $0.handle == handle }!
        let current = level.objects.first { $0.handle == handle }!
        source.objectTransformEdits.removeAll { $0.handle == handle }
        let transform = rigidTransform(of: current)
        if base.location != current.location || rigidTransform(of: base) != transform {
            source.objectTransformEdits.append(.init(
                handle: handle,
                location: current.location,
                transform: transform
            ))
            source.objectTransformEdits.sort { $0.handle < $1.handle }
        }
    }

    private mutating func updatePlayerStartTransformEdit(playerID: Int, handle: UInt32) {
        let base = importedBase.objects.first { $0.handle == handle }!
        let current = level.objects.first { $0.handle == handle }!
        source.playerStartTransformEdits.removeAll {
            $0.playerID == playerID && $0.handle == handle
        }
        let transform = rigidTransform(of: current)
        if base.location != current.location || rigidTransform(of: base) != transform {
            source.playerStartTransformEdits.append(.init(
                playerID: playerID,
                handle: handle,
                location: current.location,
                transform: transform
            ))
            source.playerStartTransformEdits.sort {
                ($0.playerID, $0.handle) < ($1.playerID, $1.handle)
            }
        }
    }
}

private let combinedPortalFlag: UInt32 = 0x0000_0008

private func portalFlags(_ flags: UInt32, rendersFace: Bool) -> UInt32 {
    rendersFace ? flags | 1 : flags & ~UInt32(1)
}

private func rigidTransform(of object: PlacedObject) -> RevivalRigidTransform {
    .init(position: object.position, orientation: object.orientation)
}

private func isValidRigidTransform(_ transform: RevivalRigidTransform) -> Bool {
    isCanonicalRigidTransform(
        position: transform.position,
        orientation: transform.orientation
    )
}

private func isFiniteProjectPosition(_ position: Vector3) -> Bool {
    position.x.isFinite && position.y.isFinite && position.z.isFinite
}

private func locationSummary(_ location: SpatialLocation) -> String {
    switch location {
    case .room(let sourceIndex):
        "room \(sourceIndex)"
    case .terrainCell(let cell):
        "terrain cell \(cell)"
    }
}

private func editorPlacementRadius(
    for object: PlacedObject,
    in level: Level
) -> Float {
    guard let presentation = level.objectPresentations.first(where: {
        $0.objectHandle == object.handle
    }),
          let model = level.models.first(where: {
              $0.source == presentation.primaryModel
          }) else {
        return 0
    }
    return sourceObjectPresentationSize(model: model, objectType: object.type)
}

private func validateAuthoredIndoorOwnership(
    in level: Level,
    editedRoomSourceIndices: Set<Int>,
    editedObjectHandles: Set<UInt32>
) throws {
    for object in level.objects {
        let editedRoomContainsObject = if case let .room(roomSourceIndex) = object.location {
            editedRoomSourceIndices.contains(roomSourceIndex)
        } else {
            false
        }
        guard editedRoomContainsObject || editedObjectHandles.contains(object.handle) else {
            continue
        }
        let owner = object.type == D3SourceIdentity.playerObjectType
            ? "Player \(object.storedID) start \(object.handle)"
            : "Object \(object.handle)"
        guard case let .room(roomSourceIndex) = object.location,
              containingIndoorRoomSourceIndex(
            in: level,
            position: object.position,
            candidates: [roomSourceIndex]
        ) == roomSourceIndex else {
            throw RevivalProjectError.placementHasNoContainingRoom(owner: owner)
        }
    }
}

private func placementEditedHandles(
    source: RevivalProjectSource,
    importedBase: Level
) -> Set<UInt32> {
    let edits = source.objectTransformEdits.map {
        ($0.handle, $0.location, $0.transform.position)
    } + source.playerStartTransformEdits.map {
        ($0.handle, $0.location, $0.transform.position)
    }
    return Set(edits.compactMap { handle, location, position in
        guard let base = importedBase.objects.first(where: {
            $0.handle == handle
        }),
              base.location != location || base.position != position else {
            return nil
        }
        return handle
    })
}

private func attributedProjectValidationError(
    _ error: LevelValidationError,
    level: Level,
    importedBase: Level,
    source: RevivalProjectSource
) -> Error {
    switch error {
    case .invalidDependency:
        for edit in source.faceMaterialEdits {
            var withoutEdit = level
            let roomIndex = withoutEdit.rooms.firstIndex {
                $0.sourceIndex == edit.roomSourceIndex
            }!
            let baseRoom = importedBase.rooms.first {
                $0.sourceIndex == edit.roomSourceIndex
            }!
            withoutEdit.rooms[roomIndex].faces[edit.faceIndex].texture =
                baseRoom.faces[edit.faceIndex].texture
            if (try? withoutEdit.validate()) != nil {
                return RevivalProjectError.faceEditRejected(
                    roomSourceIndex: edit.roomSourceIndex,
                    faceIndex: edit.faceIndex
                )
            }
        }
        for edit in source.portalRenderingEdits {
            var withoutEdit = level
            let roomIndex = withoutEdit.rooms.firstIndex {
                $0.sourceIndex == edit.roomSourceIndex
            }!
            let baseRoom = importedBase.rooms.first {
                $0.sourceIndex == edit.roomSourceIndex
            }!
            withoutEdit.rooms[roomIndex].portals[edit.portalIndex].flags =
                baseRoom.portals[edit.portalIndex].flags
            if (try? withoutEdit.validate()) != nil {
                return RevivalProjectError.portalEditRejected(
                    roomSourceIndex: edit.roomSourceIndex,
                    portalIndex: edit.portalIndex
                )
            }
        }
        if let face = source.faceMaterialEdits.first,
           let portal = source.portalRenderingEdits.first {
            return RevivalProjectError.authoredDependencyCombinationRejected(
                faceRoomSourceIndex: face.roomSourceIndex,
                faceIndex: face.faceIndex,
                portalRoomSourceIndex: portal.roomSourceIndex,
                portalIndex: portal.portalIndex
            )
        }
        if let edit = source.faceMaterialEdits.first {
            return RevivalProjectError.faceEditRejected(
                roomSourceIndex: edit.roomSourceIndex,
                faceIndex: edit.faceIndex
            )
        }
        if let edit = source.portalRenderingEdits.first {
            return RevivalProjectError.portalEditRejected(
                roomSourceIndex: edit.roomSourceIndex,
                portalIndex: edit.portalIndex
            )
        }
        return error
    default:
        return error
    }
}

private func validateRoomName(_ name: String?) throws {
    guard let name else { return }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, trimmedName == name else {
        throw RevivalProjectError.invalidRoomName
    }
    guard name.utf8.count <= 19 else {
        throw RevivalProjectError.roomNameTooLong
    }
}
