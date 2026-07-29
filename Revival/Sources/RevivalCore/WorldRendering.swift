// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct PerspectiveProjection: Codable, Equatable, Sendable {
    let horizontalFieldOfViewRadians: Float
    let aspectRatio: Float

    static let sourceDefault = PerspectiveProjection(
        horizontalFieldOfViewRadians: 3.14 * 72 / 180,
        aspectRatio: 4.0 / 3.0
    )

    static let squareNinetyDegrees = PerspectiveProjection(
        horizontalFieldOfViewRadians: .pi / 2,
        aspectRatio: 1
    )

    func withAspectRatio(_ aspectRatio: Float) -> PerspectiveProjection {
        precondition(aspectRatio.isFinite && aspectRatio > 0)
        let verticalTangent = tan(horizontalFieldOfViewRadians / 2) / self.aspectRatio
        return PerspectiveProjection(
            horizontalFieldOfViewRadians: 2 * atan(verticalTangent * aspectRatio),
            aspectRatio: aspectRatio
        )
    }
}

struct RoomCamera: Codable, Equatable, Sendable {
    let position: Vector3
    let target: Vector3
    let up: Vector3
    let projection: PerspectiveProjection

    init(
        position: Vector3,
        target: Vector3,
        up: Vector3,
        projection: PerspectiveProjection = .sourceDefault
    ) {
        self.position = position
        self.target = target
        self.up = up
        self.projection = projection
    }

    static let trainingRoom3 = RoomCamera(
        position: .init(x: 2_061.7124, y: -220.75536, z: 2_206.3005),
        target: .init(x: 2_061.7124, y: -200, z: 2_206.3005),
        up: .init(x: 0, y: 0, z: 1)
    )
}

struct InputSnapshot: Equatable, Sendable {
    let forward: Float
    let sideways: Float
    let vertical: Float
    let pitch: Float
    let yaw: Float
    let roll: Float
    let afterburner: Float
    let directLookPitchRadians: Float
    let directLookYawRadians: Float
    let firesPrimaryWeapon: Bool
    let deploysTrainingGuidebot: Bool
    let usesInventory: Bool

    static let zero = InputSnapshot()

    init(
        forward: Float = 0,
        sideways: Float = 0,
        vertical: Float = 0,
        pitch: Float = 0,
        yaw: Float = 0,
        roll: Float = 0,
        afterburner: Float = 0,
        directLookPitchRadians: Float = 0,
        directLookYawRadians: Float = 0,
        firesPrimaryWeapon: Bool = false,
        deploysTrainingGuidebot: Bool = false,
        usesInventory: Bool = false
    ) {
        precondition(
            directLookPitchRadians.isFinite && directLookYawRadians.isFinite
        )
        self.forward = max(-1, min(1, forward))
        self.sideways = max(-1, min(1, sideways))
        self.vertical = max(-1, min(1, vertical))
        self.pitch = max(-1, min(1, pitch))
        self.yaw = max(-1, min(1, yaw))
        self.roll = max(-1, min(1, roll))
        self.afterburner = max(0, min(1, afterburner))
        self.directLookPitchRadians = directLookPitchRadians
        self.directLookYawRadians = directLookYawRadians
        self.firesPrimaryWeapon = firesPrimaryWeapon
        self.deploysTrainingGuidebot = deploysTrainingGuidebot
        self.usesInventory = usesInventory
    }
}

struct PlayerControlMask: OptionSet, Codable, Equatable, Sendable {
    let rawValue: UInt32

    static let forward = Self(rawValue: 1 << 0)
    static let reverse = Self(rawValue: 1 << 1)
    static let left = Self(rawValue: 1 << 2)
    static let right = Self(rawValue: 1 << 3)
    static let up = Self(rawValue: 1 << 4)
    static let down = Self(rawValue: 1 << 5)
    static let pitchUp = Self(rawValue: 1 << 6)
    static let pitchDown = Self(rawValue: 1 << 7)
    static let headingLeft = Self(rawValue: 1 << 8)
    static let headingRight = Self(rawValue: 1 << 9)
    static let bankLeft = Self(rawValue: 1 << 10)
    static let bankRight = Self(rawValue: 1 << 11)
    static let primaryWeapon = Self(rawValue: 1 << 12)
    static let secondaryWeapon = Self(rawValue: 1 << 13)
    static let afterburner = Self(rawValue: 1 << 14)
    static let all = Self(rawValue: .max)
}

func trainingPlayerControlMask(
    galleryWasTriggered: Bool,
    controlsWereRestored: Bool,
    openingControls: PlayerControlMask?
) -> PlayerControlMask {
    if galleryWasTriggered {
        return controlsWereRestored
            ? .all
            : PlayerControlMask(rawValue: 0)
    }
    return openingControls ?? .all
}

private extension InputSnapshot {
    func applying(_ controls: PlayerControlMask) -> InputSnapshot {
        InputSnapshot(
            forward: forward >= 0
                ? (controls.contains(.forward) ? forward : 0)
                : (controls.contains(.reverse) ? forward : 0),
            sideways: sideways >= 0
                ? (controls.contains(.right) ? sideways : 0)
                : (controls.contains(.left) ? sideways : 0),
            vertical: vertical >= 0
                ? (controls.contains(.up) ? vertical : 0)
                : (controls.contains(.down) ? vertical : 0),
            pitch: pitch >= 0
                ? (controls.contains(.pitchDown) ? pitch : 0)
                : (controls.contains(.pitchUp) ? pitch : 0),
            yaw: yaw >= 0
                ? (controls.contains(.headingRight) ? yaw : 0)
                : (controls.contains(.headingLeft) ? yaw : 0),
            roll: roll >= 0
                ? (controls.contains(.bankRight) ? roll : 0)
                : (controls.contains(.bankLeft) ? roll : 0),
            afterburner: controls.contains(.afterburner) ? afterburner : 0,
            directLookPitchRadians:
                controls.contains(.pitchUp) || controls.contains(.pitchDown)
                    ? directLookPitchRadians
                    : 0,
            directLookYawRadians:
                controls.contains(.headingLeft) || controls.contains(.headingRight)
                    ? directLookYawRadians
                    : 0,
            firesPrimaryWeapon:
                controls.contains(.primaryWeapon) && firesPrimaryWeapon,
            deploysTrainingGuidebot: deploysTrainingGuidebot,
            usesInventory: usesInventory
        )
    }
}

struct PlayerInputRamp: Sendable {
    let rampDuration: Float

    private var state = InputSnapshot.zero
    private var previousHeld = InputSnapshot.zero

    init(rampDuration: Float = 0.35) {
        precondition(rampDuration.isFinite && rampDuration >= 0)
        self.rampDuration = rampDuration
    }

    mutating func snapshot(
        held: InputSnapshot,
        frameDuration: Float,
        gameplayIsActive: Bool
    ) -> InputSnapshot {
        precondition(frameDuration.isFinite && frameDuration >= 0)
        guard gameplayIsActive else {
            state = .zero
            previousHeld = .zero
            return .zero
        }
        guard rampDuration > 0 else {
            state = .zero
            previousHeld = held
            return InputSnapshot(
                forward: inputSign(held.forward),
                sideways: inputSign(held.sideways),
                vertical: inputSign(held.vertical),
                pitch: inputSign(held.pitch),
                yaw: inputSign(held.yaw),
                roll: inputSign(held.roll),
                afterburner: held.afterburner,
                directLookPitchRadians: 0,
                directLookYawRadians: 0
            )
        }

        state = InputSnapshot(
            forward: ramped(held.forward, state.forward, previousHeld.forward, frameDuration),
            sideways: ramped(held.sideways, state.sideways, previousHeld.sideways, frameDuration),
            vertical: ramped(held.vertical, state.vertical, previousHeld.vertical, frameDuration),
            pitch: ramped(held.pitch, state.pitch, previousHeld.pitch, frameDuration),
            yaw: ramped(held.yaw, state.yaw, previousHeld.yaw, frameDuration),
            roll: ramped(held.roll, state.roll, previousHeld.roll, frameDuration),
            afterburner: held.afterburner,
            directLookPitchRadians: 0,
            directLookYawRadians: 0
        )
        previousHeld = held
        return state
    }

    private func ramped(
        _ held: Float,
        _ current: Float,
        _ previous: Float,
        _ frameDuration: Float
    ) -> Float {
        guard held != 0 else { return 0 }
        var ramp = current * rampDuration
        if previous != 0, held.sign != previous.sign {
            ramp = -ramp
        }
        ramp += inputSign(held) * frameDuration
        return max(-rampDuration, min(rampDuration, ramp)) / rampDuration
    }

    private func inputSign(_ value: Float) -> Float {
        value < 0 ? -1 : value > 0 ? 1 : 0
    }
}

struct PlayerInputState: Sendable {
    private var ramp: PlayerInputRamp
    private var held = InputSnapshot.zero
    private var controller = InputSnapshot.zero
    private var mouseDeltaX: Float = 0
    private var mouseDeltaY: Float = 0
    private var guidebotDeploymentIsPending = false
    private var primaryFireIsPending = false
    private var inventoryUseIsPending = false
    private(set) var gameplayIsActive = true
    var mouseLookEnabled = false

    init(rampDuration: Float = 0.35) {
        ramp = PlayerInputRamp(rampDuration: rampDuration)
    }

    mutating func setHeld(_ snapshot: InputSnapshot) {
        held = gameplayIsActive ? snapshot : .zero
    }

    mutating func setController(_ snapshot: InputSnapshot) {
        controller = gameplayIsActive ? snapshot : .zero
    }

    mutating func accumulateMouseDelta(x: Float, y: Float) {
        precondition(x.isFinite && y.isFinite)
        guard gameplayIsActive else { return }
        mouseDeltaX += x
        mouseDeltaY += y
    }

    mutating func requestGuidebotDeployment() {
        guard gameplayIsActive else { return }
        guidebotDeploymentIsPending = true
    }

    mutating func requestPrimaryFire() {
        guard gameplayIsActive else { return }
        primaryFireIsPending = true
    }

    mutating func requestInventoryUse() {
        guard gameplayIsActive else { return }
        inventoryUseIsPending = true
    }

    mutating func snapshot(frameDuration: Float) -> InputSnapshot {
        let keyboard = ramp.snapshot(
            held: held,
            frameDuration: frameDuration,
            gameplayIsActive: gameplayIsActive
        )
        guard gameplayIsActive else {
            mouseDeltaX = 0
            mouseDeltaY = 0
            return .zero
        }
        let deltaX = mouseDeltaX
        let deltaY = mouseDeltaY
        let deploysTrainingGuidebot = guidebotDeploymentIsPending
        let firesPrimaryWeapon = primaryFireIsPending
        let usesInventory = inventoryUseIsPending
        mouseDeltaX = 0
        mouseDeltaY = 0
        guidebotDeploymentIsPending = false
        primaryFireIsPending = false
        inventoryUseIsPending = false
        let mouseNormalizer = 10_000 * max(frameDuration, 0.005)
        let mouseYaw = mouseLookEnabled ? 0 : deltaX / mouseNormalizer
        let mousePitch = mouseLookEnabled ? 0 : -deltaY / mouseNormalizer
        let directScale = 2 * Float.pi / 10_000
        return InputSnapshot(
            forward: keyboard.forward + controller.forward,
            sideways: keyboard.sideways + controller.sideways,
            vertical: keyboard.vertical + controller.vertical,
            pitch: max(
                -0.75,
                min(0.75, keyboard.pitch + controller.pitch + mousePitch)
            ),
            yaw: keyboard.yaw + controller.yaw + mouseYaw,
            roll: keyboard.roll + controller.roll,
            afterburner: max(keyboard.afterburner, controller.afterburner),
            directLookPitchRadians: mouseLookEnabled ? -deltaY * directScale : 0,
            directLookYawRadians: mouseLookEnabled ? deltaX * directScale : 0,
            firesPrimaryWeapon: firesPrimaryWeapon,
            deploysTrainingGuidebot: deploysTrainingGuidebot,
            usesInventory: usesInventory
        )
    }

    mutating func setGameplayActive(
        _ active: Bool,
        simulation: PlayerSimulation?,
        at timestamp: Double
    ) {
        precondition(timestamp.isFinite)
        if !active {
            held = .zero
            controller = .zero
            mouseDeltaX = 0
            mouseDeltaY = 0
            guidebotDeploymentIsPending = false
            primaryFireIsPending = false
            inventoryUseIsPending = false
            _ = ramp.snapshot(
                held: .zero,
                frameDuration: simulation?.frameDuration ?? 0,
                gameplayIsActive: false
            )
        }
        guard active != gameplayIsActive else { return }
        if active {
            simulation?.startTime(at: timestamp)
        } else {
            simulation?.stopTime(at: timestamp)
        }
        gameplayIsActive = active
    }
}

struct PlayerView: Equatable, Sendable {
    let playerID: Int
    let objectHandle: UInt32
    let roomSourceIndex: Int
    let camera: RoomCamera
    let collisionRadius: Float
}

func reciprocalPortalComponent(
    rooms: [LevelRoom],
    startRoomSourceIndex: Int
) -> Set<Int> {
    let roomsBySourceIndex = Dictionary(
        uniqueKeysWithValues: rooms.map { ($0.sourceIndex, $0) }
    )
    guard roomsBySourceIndex[startRoomSourceIndex] != nil else {
        return []
    }

    var reached: Set<Int> = [startRoomSourceIndex]
    var pending = [startRoomSourceIndex]
    while let sourceIndex = pending.popLast() {
        let room = roomsBySourceIndex[sourceIndex]!
        for (portalIndex, portal) in room.portals.enumerated() {
            guard let destination = roomsBySourceIndex[portal.connectedRoom],
                  destination.portals.indices.contains(portal.connectedPortal)
            else {
                continue
            }
            let reciprocal = destination.portals[portal.connectedPortal]
            guard reciprocal.connectedRoom == sourceIndex,
                  reciprocal.connectedPortal == portalIndex,
                  reached.insert(destination.sourceIndex).inserted
            else {
                continue
            }
            pending.append(destination.sourceIndex)
        }
    }
    return reached
}

func defaultPlayerView(
    in level: Level,
    projection: PerspectiveProjection = .sourceDefault
) -> PlayerView {
    let binding = level.defaultPlayerBinding!
    let object = level.objects.first { $0.handle == binding.objectHandle }!
    let ship = level.shipDefinitions.first { $0.source == binding.ship }!
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("The validated default player start is indoor.")
    }
    return PlayerView(
        playerID: binding.playerID,
        objectHandle: object.handle,
        roomSourceIndex: roomSourceIndex,
        camera: RoomCamera(
            position: object.position,
            target: object.position + object.orientation.forward,
            up: object.orientation.up,
            projection: projection
        ),
        collisionRadius: ship.presentationSize * 0.8
    )
}

struct PlayerSimulationFrame: Equatable, Sendable {
    let systemsFrameDuration: Float
    let systemsGameTime: Float
    let storedFrameDuration: Float
    let gameTime: Float
    let playerView: PlayerView
    let velocity: Vector3
    let angularVelocity: Vector3
    let turnrollFixedAngle: Float
    let wallContact: IndoorWallContact?
    let enabledPlayerControls: PlayerControlMask
    let showsEnabledPlayerControls: Bool
    let trainingOpeningFeedback: [TrainingOpeningFeedback]
    let trainingGalleryMarkerLightDistance: Float?
    let trainingGuidebotReturnMarkerLightDistance: Float?
    let trainingGuidebot: TrainingGuidebotFrame?
    let trainingCameraMonitor: TrainingCameraMonitorFrame?
    let trainingInvulnerabilityRemaining: Float?
    let trainingCloak: TrainingCloakFrame?
    let trainingLastRoomMarkerLightDistance: Float?
    let trainingFinalBotsMarkerLightDistance: Float?
    let trainingFinalGoal: TrainingFinalGoalFrame?
}

enum TrainingEndLevelState: String, Codable, Equatable, Sendable {
    case succeeded
}

enum TrainingDifficulty: String, Codable, Equatable, Sendable {
    case rookie = "Rookie"
}

struct TrainingEndLevelPresentation: Equatable, Sendable {
    let title: String
    let levelName: String
    let difficulty: TrainingDifficulty
    let showsHUD: Bool
    let playsGameplayAudio: Bool
    let showsCockpit: Bool
    let showsHeadlightIndicator: Bool
}

struct TrainingPostLevelResult: Equatable, Sendable {
    let title: String
    let levelName: String
    let difficulty: TrainingDifficulty
    let score: Int
    let elapsedTime: Float
    let enemyKills: Int
    let shields: Float
    let energy: Float
    let deaths: Int
    let restores: Int
    let objectives: [String]
}

enum TrainingSessionOutcome: Equatable, Sendable {
    case awaitingResultAcknowledgement
    case completed
}

struct TrainingFinalGoalFrame: Equatable, Sendable {
    let endLevelState: TrainingEndLevelState
    let scriptActionCounter: Int
    let controlsAreSuspended: Bool
    let presentation: TrainingEndLevelPresentation
    let postLevelResult: TrainingPostLevelResult
}

enum TrainingCloakPhase: String, Codable, Equatable, Sendable {
    case fadingOut
    case cloaked
    case fadingIn
}

struct TrainingCloakFrame: Equatable, Sendable {
    let phase: TrainingCloakPhase
    let phaseRemaining: Float
    let phaseDuration: Float

    var objectAlpha: Float {
        switch phase {
        case .fadingOut:
            0.08 + 0.92 * phaseRemaining / phaseDuration
        case .cloaked:
            0.13
        case .fadingIn:
            0.08 + 0.92 * (1 - phaseRemaining / phaseDuration)
        }
    }

    var objectDeformationRange: Float {
        phase == .cloaked ? 0.1 : 0
    }
}

struct TrainingOpeningFeedback: Equatable, Sendable {
    let hudMessages: [String]
    let voiceSourceName: String
    let voicePrecedesHUDMessages: Bool
    let soundSourceName: String?

    init(
        hudMessages: [String],
        voiceSourceName: String,
        voicePrecedesHUDMessages: Bool,
        soundSourceName: String? = nil
    ) {
        self.hudMessages = hudMessages
        self.voiceSourceName = voiceSourceName
        self.voicePrecedesHUDMessages = voicePrecedesHUDMessages
        self.soundSourceName = soundSourceName
    }
}

struct TrainingCameraMonitorFrame: Equatable, Sendable {
    let camera: RoomCamera
    let roomSourceIndex: Int
    let remainingDuration: Float
}

enum TrainingGuidebotRouteMode: String, Codable, Equatable, Sendable {
    case direct
    case boundaryNodes
    case roomPortals
}

struct IndoorNavigationNodeReference:
    Codable, Equatable, Hashable, Sendable
{
    let roomSourceIndex: Int
    let nodeIndex: Int
}

struct TrainingGuidebotRoute: Codable, Equatable, Sendable {
    let mode: TrainingGuidebotRouteMode
    let points: [Vector3]
    let roomSourceIndices: [Int]
    let nodeReferences: [IndoorNavigationNodeReference]
}

enum TrainingGuidebotSteeringMode:
    String, Codable, Equatable, Sendable
{
    case direct
    case allocatedRoute
    case stopped
}

struct TrainingGuidebotFrame: Equatable, Sendable {
    let spawnPosition: Vector3
    let position: Vector3
    let orientation: Matrix3
    let spawnVelocity: Vector3
    let velocity: Vector3
    let destination: Vector3
    let route: TrainingGuidebotRoute
    let routeFailure: TrainingGuidebotRouteError?
    let activeSteeringMode: TrainingGuidebotSteeringMode
}

enum TrainingGuidebotRouteError:
    String, Error, Codable, Equatable, Sendable
{
    case noBOAPath
    case unverifiedBoundaryNodes
    case noVisibleBoundaryNode
    case noBoundaryNodePath
    case noRoomPortalPath
}

func trainingGuidebotRoute(
    in level: Level,
    startRoomSourceIndex: Int,
    start: Vector3,
    startForward: Vector3,
    destinationRoomSourceIndex: Int,
    destination: Vector3,
    radius: Float
) -> Result<TrainingGuidebotRoute, TrainingGuidebotRouteError> {
    precondition(
        radius.isFinite && radius >= 0
            && startForward.x.isFinite
            && startForward.y.isFinite
            && startForward.z.isFinite
    )
    let boaRooms = trainingGuidebotBOARoomRoute(
        in: level,
        start: startRoomSourceIndex,
        destination: destinationRoomSourceIndex
    )
    guard let boaRooms else { return .failure(.noBOAPath) }
    if trainingGuidebotProbeIsClear(
        in: level,
        startRoomSourceIndex: startRoomSourceIndex,
        start: start,
        destination: destination,
        radius: radius
    ) {
        return .success(.init(
            mode: .direct,
            points: [destination],
            roomSourceIndices: boaRooms,
            nodeReferences: []
        ))
    }

    guard let graph = level.indoorNavigation,
          graph.sourceWasVerified else {
        return .failure(.unverifiedBoundaryNodes)
    }
    let navigationByRoom = Dictionary(
        uniqueKeysWithValues: graph.rooms.map { ($0.sourceIndex, $0) }
    )
    if startRoomSourceIndex != destinationRoomSourceIndex {
        let roomBySourceIndex = Dictionary(
            uniqueKeysWithValues: level.rooms.map {
                ($0.sourceIndex, $0)
            }
        )
        var portalPoints: [Vector3] = []
        for (roomSourceIndex, nextRoomSourceIndex) in zip(
            boaRooms,
            boaRooms.dropFirst()
        ) {
            guard let portal = roomBySourceIndex[roomSourceIndex]?
                .portals.first(where: {
                    $0.connectedRoom == nextRoomSourceIndex
                })
            else {
                return .failure(.noRoomPortalPath)
            }
            portalPoints.append(portal.pathPoint)
        }
        return .success(.init(
            mode: .roomPortals,
            points: portalPoints + [destination],
            roomSourceIndices: boaRooms,
            nodeReferences: []
        ))
    }
    guard let startNodes = navigationByRoom[startRoomSourceIndex]?.nodes,
          let destinationNodes =
            navigationByRoom[destinationRoomSourceIndex]?.nodes
    else {
        return .failure(.noVisibleBoundaryNode)
    }
    let probeRadius = min(radius / 4, 20)
    let visibleStartNodes = startNodes.indices.filter {
        trainingGuidebotDistance(start, startNodes[$0].position) < 800
            && trainingGuidebotProbeIsClear(
                in: level,
                startRoomSourceIndex: startRoomSourceIndex,
                start: start,
                destination: startNodes[$0].position,
                radius: probeRadius
            )
    }
    let forwardStartNodes = visibleStartNodes.filter {
        dot(
            startForward,
            normalized(startNodes[$0].position - start)
        ) > 0
    }
    let startReference = (forwardStartNodes.last ?? visibleStartNodes.last)
        .map {
            IndoorNavigationNodeReference(
                roomSourceIndex: startRoomSourceIndex,
                nodeIndex: $0
            )
        }
    let visibleDestinationNodes = destinationNodes.indices
        .filter {
            destinationNodes[$0].edges.contains {
                $0.maximumRadius >= probeRadius
            }
                &&
            trainingGuidebotProbeIsClear(
                in: level,
                startRoomSourceIndex: destinationRoomSourceIndex,
                start: destinationNodes[$0].position,
                destination: destination,
                radius: probeRadius
            )
        }
    let destinationReference = (
        visibleDestinationNodes.min {
            trainingGuidebotQuickDistance(
                destinationNodes[$0].position,
                destination
            ) < trainingGuidebotQuickDistance(
                destinationNodes[$1].position,
                destination
            )
        }
            ?? destinationNodes.indices
                .filter {
                    trainingGuidebotQuickDistance(
                        destinationNodes[$0].position,
                        destination
                    ) < 800
                }
                .min {
                    trainingGuidebotQuickDistance(
                        destinationNodes[$0].position,
                        destination
                    ) < trainingGuidebotQuickDistance(
                        destinationNodes[$1].position,
                        destination
                    )
                }
    )
        .map {
            IndoorNavigationNodeReference(
                roomSourceIndex: destinationRoomSourceIndex,
                nodeIndex: $0
            )
        }
    guard let startReference, let destinationReference else {
        return .failure(.noVisibleBoundaryNode)
    }
    guard let references = trainingGuidebotBoundaryNodePath(
        room: navigationByRoom[startRoomSourceIndex]!,
        start: startReference,
        destination: destinationReference
    ) else {
        return .failure(.noBoundaryNodePath)
    }
    let points = references.map {
        navigationByRoom[$0.roomSourceIndex]!.nodes[$0.nodeIndex].position
    } + [destination]
    var orderedRooms: [Int] = []
    for reference in references
    where orderedRooms.last != reference.roomSourceIndex {
        orderedRooms.append(reference.roomSourceIndex)
    }
    return .success(.init(
        mode: .boundaryNodes,
        points: points,
        roomSourceIndices: orderedRooms,
        nodeReferences: references
    ))
}

private func trainingGuidebotBOARoomRoute(
    in level: Level,
    start: Int,
    destination: Int
) -> [Int]? {
    guard level.rooms.contains(where: { $0.sourceIndex == start }),
          level.rooms.contains(where: {
              $0.sourceIndex == destination
          }) else {
        return nil
    }
    if start == destination { return [start] }
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    var queue = [start]
    var predecessor: [Int: Int] = [:]
    var visited: Set<Int> = [start]
    while !queue.isEmpty {
        let roomSourceIndex = queue.removeFirst()
        for portal in roomBySourceIndex[roomSourceIndex]!.portals {
            let next = portal.connectedRoom
            guard visited.insert(next).inserted else { continue }
            predecessor[next] = roomSourceIndex
            if next == destination {
                var result = [destination]
                while result.last != start {
                    result.append(predecessor[result.last!]!)
                }
                return Array(result.reversed())
            }
            queue.append(next)
        }
    }
    return nil
}

private func trainingGuidebotBoundaryNodePath(
    room: IndoorNavigationRoom,
    start: IndoorNavigationNodeReference,
    destination: IndoorNavigationNodeReference
) -> [IndoorNavigationNodeReference]? {
    guard start.roomSourceIndex == room.sourceIndex,
          destination.roomSourceIndex == room.sourceIndex else {
        return nil
    }
    var distances = [start.nodeIndex: 0]
    var predecessor: [Int: Int] = [:]
    var pending = [start.nodeIndex]
    var visited: Set<Int> = []
    while !pending.isEmpty {
        let current = pending.indices.min {
            let lhs = pending[$0]
            let rhs = pending[$1]
            let lhsDistance = distances[lhs, default: .max]
            let rhsDistance = distances[rhs, default: .max]
            return lhsDistance == rhsDistance
                ? $0 > $1
                : lhsDistance < rhsDistance
        }.map { pending.remove(at: $0) }!
        guard visited.insert(current).inserted else { continue }
        if current == destination.nodeIndex {
            var result = [current]
            while result.last != start.nodeIndex {
                result.append(predecessor[result.last!]!)
            }
            return result.reversed().map {
                IndoorNavigationNodeReference(
                    roomSourceIndex: room.sourceIndex,
                    nodeIndex: $0
                )
            }
        }
        for edge in room.nodes[current].edges
        where edge.destinationRoomSourceIndex == room.sourceIndex
            && room.nodes.indices.contains(edge.destinationNodeIndex) {
            let next = edge.destinationNodeIndex
            let candidate = distances[current]! + edge.cost
            if candidate <= distances[next, default: .max] {
                distances[next] = candidate
                predecessor[next] = current
                pending.append(next)
            }
        }
    }
    return nil
}

private func trainingGuidebotProbeIsClear(
    in level: Level,
    startRoomSourceIndex: Int,
    start: Vector3,
    destination: Vector3,
    radius: Float
) -> Bool {
    if case .noHit = traceIndoorMovement(
        in: level,
        startRoom: startRoomSourceIndex,
        start: start,
        end: destination,
        radius: radius
    ).outcome {
        return true
    }
    return false
}

private func trainingGuidebotDistance(
    _ lhs: Vector3,
    _ rhs: Vector3
) -> Float {
    let delta = lhs - rhs
    return sqrt(dot(delta, delta))
}

private func trainingGuidebotQuickDistance(
    _ lhs: Vector3,
    _ rhs: Vector3
) -> Float {
    abs(lhs.x - rhs.x)
        + abs(lhs.y - rhs.y)
        + abs(lhs.z - rhs.z)
}

private struct TrainingOpeningState: Codable, Equatable, Sendable {
    var timerRemaining: Float
    var welcomeWasPresented = false
    var forwardGoalWasReached = false
    var returnGoalWasReached: Bool? = nil
    var rightGoalWasReached: Bool? = nil
    var upGoalWasReached: Bool? = nil
    var downGoalWasReached: Bool? = nil
    var repeatForwardWasPresented: Bool? = nil
    var repeatForwardGoalWasPresented: Bool? = nil
    var enabledControls: PlayerControlMask = [.forward]
}

private struct TrainingGalleryBarrierState: Codable, Equatable, Sendable {
    var wasTriggered = false
    var markerLightDistance: Float
}

private struct TrainingRobotGuidebotState: Codable, Equatable, Sendable {
    var robotWasDestroyed = false
    var robotShields: Float
    var nextPrimaryFireTime: Float = 0
    var projectiles: [TrainingLaserProjectileState] = []
    var guidebotIsDeployed = false
    var guidebot: TrainingGuidebotRuntimeState?
    var guidebotContinuationWasPresented = false
    var returnWasRequested = false
    var guidebotEnteredShip = false
    var arrivalFeedbackWasPresented = false
    var controlsWereRestored = false
    var enabledControlHUDIsVisible = true
    var destructionTimerRemaining: Float?
    var destructionFeedbackWasPresented = false
}

private struct TrainingCameraMonitorState:
    Codable, Equatable, Sendable
{
    var isHeld = false
    var wasUsed = false
    var popupRemaining: Float?
    var completionTimerRemaining: Float?
    var completionTimerWasConsumed = false
    var returnMarkerLightDistance: Float = 0
    var script058WasPresented = false
}

private struct TrainingKillbotEntryState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
    var followupTimerRemaining: Float?
    var followupWasPresented = false
}

private struct TrainingRobotDeathState:
    Codable, Equatable, Sendable
{
    var wasDestroyed = false
    var shields: Float
}

private typealias TrainingRASBot1DeathState = TrainingRobotDeathState
private typealias TrainingRASBot2DeathState = TrainingRobotDeathState
private typealias TrainingRASBot3DeathState = TrainingRobotDeathState
private typealias TrainingRASBot4DeathState = TrainingRobotDeathState
private typealias TrainingLastBot1DeathState = TrainingRobotDeathState
private typealias TrainingLastBot2DeathState = TrainingRobotDeathState
private typealias TrainingLastBot3DeathState = TrainingRobotDeathState
private typealias TrainingLastBot4DeathState = TrainingRobotDeathState
private typealias TrainingLastBot5DeathState = TrainingRobotDeathState

private struct TrainingInvulnerabilityPickupState:
    Codable, Equatable, Sendable
{
    var scriptWasTriggered = false
    var wasConsumed = false
    var remainingDuration: Float?
}

private struct TrainingCloakPickupState:
    Codable, Equatable, Sendable
{
    var scriptWasTriggered = false
    var wasConsumed = false
    var phase: TrainingCloakPhase?
    var phaseRemaining: Float?
}

private struct TrainingLastRoomState: Codable, Equatable, Sendable {
    var wasTriggered = false
    var markerLightDistance: Float = 0
    var timerRemaining: Float?
    var wasPresented = false
}

private struct TrainingFinalBotsCompletionState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
    var markerLightDistance: Float = 0
    var timerRemaining: Float?
    var wasPresented = false
}

private struct TrainingFinalGoalState:
    Codable, Equatable, Sendable
{
    var endLevelWasRequested = false
    var scriptActionCounter = 0
}

private struct TrainingFinalRoomEntryState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
}

private enum TrainingGuidebotTask: String, Codable, Equatable, Sendable {
    case outbound
    case returnToShip
}

private struct TrainingGuidebotRuntimeState:
    Codable, Equatable, Sendable
{
    let spawnPosition: Vector3
    var roomSourceIndex: Int
    var position: Vector3
    let orientation: Matrix3
    let spawnVelocity: Vector3
    var velocity: Vector3
    var destination: Vector3
    var route: TrainingGuidebotRoute
    var routeFailure: TrainingGuidebotRouteError?
    var routePointIndex: Int
    var activeSteeringMode: TrainingGuidebotSteeringMode
    var task: TrainingGuidebotTask
    var allocationStartPosition: Vector3
    var allocationStartForward: Vector3
    var routeDestination: Vector3
    var routeDestinationRoomSourceIndex: Int

    var frame: TrainingGuidebotFrame {
        .init(
            spawnPosition: spawnPosition,
            position: position,
            orientation: orientation,
            spawnVelocity: spawnVelocity,
            velocity: velocity,
            destination: destination,
            route: route,
            routeFailure: routeFailure,
            activeSteeringMode: activeSteeringMode
        )
    }
}

private struct TrainingLaserProjectileState:
    Codable, Equatable, Sendable
{
    var roomSourceIndex: Int
    var position: Vector3
    let velocity: Vector3
    var lifeRemaining: Float
}

struct PlayerSimulationContinuation: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let levelKey: String
    let levelSHA256: String
    let playerLocation: SpatialLocation
    let playerPosition: Vector3
    let playerOrientation: Matrix3
    let frameDuration: Float
    let gameTime: Float
    let velocity: Vector3
    let angularVelocity: Vector3
    let turnrollFixedAngle: Float
    let indoorAutoLevelMode: IndoorAutoLevelMode
    let afterburnerFuel: Float
    let afterburnerIsActive: Bool
    let energy: Float
    let afterburnerMagnitude: Float
    let wiggleFalloff: Float
    let lastThrustTime: Float
    fileprivate let trainingOpeningState: TrainingOpeningState?
    fileprivate let trainingGalleryBarrierState: TrainingGalleryBarrierState?
    fileprivate let trainingRobotGuidebotState: TrainingRobotGuidebotState?
    fileprivate let trainingCameraMonitorState: TrainingCameraMonitorState?
    fileprivate let trainingKillbotEntryState: TrainingKillbotEntryState?
    fileprivate let trainingRASBot1DeathState: TrainingRASBot1DeathState?
    fileprivate let trainingRASBot2DeathState: TrainingRASBot2DeathState?
    fileprivate let trainingRASBot3DeathState: TrainingRASBot3DeathState?
    fileprivate let trainingRASBot4DeathState: TrainingRASBot4DeathState?
    fileprivate let trainingLastBot1DeathState:
        TrainingLastBot1DeathState?
    fileprivate let trainingLastBot2DeathState:
        TrainingLastBot2DeathState?
    fileprivate let trainingLastBot3DeathState:
        TrainingLastBot3DeathState?
    fileprivate let trainingLastBot4DeathState:
        TrainingLastBot4DeathState?
    fileprivate let trainingLastBot5DeathState:
        TrainingLastBot5DeathState?
    fileprivate let trainingInvulnerabilityPickupState: TrainingInvulnerabilityPickupState?
    fileprivate let trainingCloakPickupState: TrainingCloakPickupState?
    fileprivate let trainingLastRoomState: TrainingLastRoomState?
    fileprivate let trainingFinalRoomEntryState:
        TrainingFinalRoomEntryState?
    fileprivate let trainingFinalBotsCompletionState:
        TrainingFinalBotsCompletionState?
    fileprivate let trainingFinalGoalState: TrainingFinalGoalState?
}

enum PlayerSimulationContinuationError: Error, Equatable {
    case unsupportedSchema
    case levelIdentityMismatch
    case invalidState
}

private func playerSimulationContinuationSchema(for level: Level) -> Int {
    if level.trainingRASBot1DeathChain != nil {
        return 7
    }
    if level.trainingCameraMonitorChain?.returnToShip?
        .killbotEntry != nil {
        return 6
    }
    if level.trainingCameraMonitorChain?.returnToShip != nil {
        return 5
    }
    return level.trainingCameraMonitorChain == nil ? 3 : 4
}

enum IndoorAutoLevelMode: Int, Codable, Sendable {
    case off = 0
    case standard = 1
    case newPlayer = 2
}

final class PlayerSimulation {
    private(set) var level: Level
    private(set) var frameDuration: Float = 0.1
    private(set) var gameTime: Float = 0
    private(set) var velocity = Vector3.zero
    private(set) var angularVelocity: Vector3
    private(set) var turnrollFixedAngle: Float = 0
    private(set) var indoorAutoLevelMode = IndoorAutoLevelMode.newPlayer
    private(set) var afterburnerFuel: Float = 5
    private(set) var afterburnerIsActive = false
    private(set) var energy: Float = 100
    private(set) var trainingSessionOutcome: TrainingSessionOutcome?
    private(set) var afterburnerMagnitude: Float = 0
    private(set) var wiggleFalloff: Float = 0

    private var lastTimestamp: Double
    private var lastThrustTime: Float = 0
    private var pauseDepth = 0
    private var pauseTimestamp: Double?
    private var trainingOpeningState: TrainingOpeningState?
    private var trainingGalleryBarrierState: TrainingGalleryBarrierState?
    private var trainingRobotGuidebotState: TrainingRobotGuidebotState?
    private var trainingCameraMonitorState: TrainingCameraMonitorState?
    private var trainingKillbotEntryState: TrainingKillbotEntryState?
    private var trainingRASBot1DeathState: TrainingRASBot1DeathState?
    private var trainingRASBot2DeathState: TrainingRASBot2DeathState?
    private var trainingRASBot3DeathState: TrainingRASBot3DeathState?
    private var trainingRASBot4DeathState: TrainingRASBot4DeathState?
    private var trainingLastBot1DeathState: TrainingLastBot1DeathState?
    private var trainingLastBot2DeathState: TrainingLastBot2DeathState?
    private var trainingLastBot3DeathState: TrainingLastBot3DeathState?
    private var trainingLastBot4DeathState: TrainingLastBot4DeathState?
    private var trainingLastBot5DeathState: TrainingLastBot5DeathState?
    private var trainingInvulnerabilityPickupState: TrainingInvulnerabilityPickupState?
    private var trainingCloakPickupState: TrainingCloakPickupState?
    private var trainingLastRoomState: TrainingLastRoomState?
    private var trainingFinalRoomEntryState:
        TrainingFinalRoomEntryState?
    private var trainingFinalBotsCompletionState:
        TrainingFinalBotsCompletionState?
    private var trainingFinalGoalState: TrainingFinalGoalState?
    private var trainingPostLevelResult: TrainingPostLevelResult?

    init(level: Level, presentationReadyTimestamp: Double) {
        precondition(presentationReadyTimestamp.isFinite)
        precondition(level.defaultPlayerBinding != nil)
        self.level = level
        let binding = level.defaultPlayerBinding!
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        angularVelocity = ship.physics.initialAngularVelocity
        lastTimestamp = presentationReadyTimestamp
        trainingOpeningState = level.trainingOpeningLesson.map {
            TrainingOpeningState(timerRemaining: $0.welcomeDelay)
        }
        trainingGalleryBarrierState = level.trainingGalleryBarrier.map {
            TrainingGalleryBarrierState(
                markerLightDistance:
                    trainingGalleryBarrierRendersFaces(
                        in: level,
                        barrier: $0
                    )
                    ? 0
                    : $0.openMarkerLightDistance
            )
        }
        trainingRobotGuidebotState = level.trainingRobotGuidebotChain.map {
            TrainingRobotGuidebotState(robotShields: $0.combat.robotShields)
        }
        trainingCameraMonitorState = level.trainingCameraMonitorChain.map {
            _ in TrainingCameraMonitorState()
        }
        trainingKillbotEntryState =
            level.trainingCameraMonitorChain?.returnToShip?.killbotEntry.map {
                _ in TrainingKillbotEntryState()
            }
        trainingRASBot1DeathState = level.trainingRASBot1DeathChain.map {
            TrainingRASBot1DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot2DeathState = level.trainingRASBot2DeathChain.map {
            TrainingRASBot2DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot3DeathState = level.trainingRASBot3DeathChain.map {
            TrainingRASBot3DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot4DeathState = level.trainingRASBot4DeathChain.map {
            TrainingRASBot4DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot1DeathState = level.trainingLastBot1DeathChain.map {
            TrainingLastBot1DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot2DeathState = level.trainingLastBot2DeathChain.map {
            TrainingLastBot2DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot3DeathState = level.trainingLastBot3DeathChain.map {
            TrainingLastBot3DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot4DeathState = level.trainingLastBot4DeathChain.map {
            TrainingLastBot4DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot5DeathState = level.trainingLastBot5DeathChain.map {
            TrainingLastBot5DeathState(shields: $0.combat.robotShields)
        }
        trainingInvulnerabilityPickupState =
            level.trainingInvulnerabilityPickupChain.map {
                _ in TrainingInvulnerabilityPickupState()
            }
        trainingCloakPickupState = level.trainingCloakPickupChain.map {
            _ in TrainingCloakPickupState()
        }
        trainingLastRoomState = level.trainingLastRoomChain.map {
            _ in TrainingLastRoomState()
        }
        trainingFinalRoomEntryState =
            level.trainingFinalRoomEntryChain.map {
                _ in TrainingFinalRoomEntryState()
            }
        trainingFinalBotsCompletionState =
            level.trainingFinalBotsCompletionChain.map {
                _ in TrainingFinalBotsCompletionState()
            }
        trainingFinalGoalState = level.trainingFinalGoalChain.map {
            _ in TrainingFinalGoalState()
        }
    }

    init(
        level: Level,
        continuation: PlayerSimulationContinuation,
        resumedAtTimestamp: Double
    ) throws {
        let expectedSchema = playerSimulationContinuationSchema(for: level)
        guard continuation.schemaVersion == expectedSchema else {
            throw PlayerSimulationContinuationError.unsupportedSchema
        }
        guard continuation.levelKey == level.levelKey,
              continuation.levelSHA256 == level.source.levelSHA256 else {
            throw PlayerSimulationContinuationError.levelIdentityMismatch
        }
        let restoredCloakPickupState =
            continuation.trainingCloakPickupState
            ?? level.trainingCloakPickupChain.map {
                _ in TrainingCloakPickupState()
            }
        let restoredLastRoomState =
            continuation.trainingLastRoomState
            ?? level.trainingLastRoomChain.map {
                _ in TrainingLastRoomState()
            }
        let restoredFinalRoomEntryState =
            continuation.trainingFinalRoomEntryState
            ?? level.trainingFinalRoomEntryChain.map {
                _ in TrainingFinalRoomEntryState()
            }
        let restoredFinalBotsCompletionState =
            continuation.trainingFinalBotsCompletionState
            ?? level.trainingFinalBotsCompletionChain.map {
                _ in TrainingFinalBotsCompletionState()
            }
        let restoredFinalGoalState =
            continuation.trainingFinalGoalState
            ?? level.trainingFinalGoalChain.map {
                _ in TrainingFinalGoalState()
            }
        let restoredLastBot1DeathState =
            continuation.trainingLastBot1DeathState
            ?? level.trainingLastBot1DeathChain.map {
                TrainingLastBot1DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot2DeathState =
            continuation.trainingLastBot2DeathState
            ?? level.trainingLastBot2DeathChain.map {
                TrainingLastBot2DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot3DeathState =
            continuation.trainingLastBot3DeathState
            ?? level.trainingLastBot3DeathChain.map {
                TrainingLastBot3DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot4DeathState =
            continuation.trainingLastBot4DeathState
            ?? level.trainingLastBot4DeathChain.map {
                TrainingLastBot4DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot5DeathState =
            continuation.trainingLastBot5DeathState
            ?? level.trainingLastBot5DeathChain.map {
                TrainingLastBot5DeathState(
                    shields: $0.combat.robotShields
                )
            }
        var routeAllocationLevel = level
        if continuation.trainingGalleryBarrierState?.wasTriggered == true {
            closeTrainingGalleryBarrier(in: &routeAllocationLevel)
        }
        var continuationLevel = routeAllocationLevel
        if continuation.trainingRobotGuidebotState?.robotWasDestroyed == true {
            let chain = continuationLevel.trainingRobotGuidebotChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.destroyRobotObjectHandle
            }
            openTrainingGalleryBarrier(in: &continuationLevel)
        }
        if let cameraState = continuation.trainingCameraMonitorState,
           let chain = continuationLevel.trainingCameraMonitorChain {
            if cameraState.isHeld || cameraState.wasUsed {
                completeTrainingCameraMonitorLocateGoal(
                    in: &continuationLevel,
                    pickupObjectHandle: chain.pickupObjectHandle
                )
            }
            if cameraState.script058WasPresented {
                openTrainingGuidebotReturnBarrier(in: &continuationLevel)
            }
            if cameraState.wasUsed {
                continuationLevel.objects.removeAll {
                    $0.handle == chain.pickupObjectHandle
                }
            }
            if cameraState.isHeld || cameraState.wasUsed {
                setObjectPresentationVisibility(
                    in: &continuationLevel,
                    handle: chain.pickupObjectHandle,
                    isVisible: false
                )
            }
        }
        if continuation.trainingKillbotEntryState?.wasTriggered == true {
            closeTrainingKillbotEntryBarrier(in: &continuationLevel)
        }
        if continuation.trainingRASBot1DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot1DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot2DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot2DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot3DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot3DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot4DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot4DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot1DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot1DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot2DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot2DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot3DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot3DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot4DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot4DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot5DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot5DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingInvulnerabilityPickupState?
            .wasConsumed == true
        {
            guard
                let chain =
                    continuationLevel.trainingInvulnerabilityPickupChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &continuationLevel,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if restoredCloakPickupState?.wasConsumed == true {
            guard let chain = continuationLevel.trainingCloakPickupChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &continuationLevel,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if restoredLastRoomState?.wasTriggered == true {
            openTrainingLastRoomBarrier(in: &continuationLevel)
        }
        if restoredFinalRoomEntryState?.wasTriggered == true {
            closeTrainingLastRoomBarrier(in: &continuationLevel)
        }
        if restoredFinalBotsCompletionState?.wasTriggered == true {
            openTrainingFinalBotsBarrier(in: &continuationLevel)
        }
        guard
            validTrainingCameraMonitorContinuation(
                continuation.trainingCameraMonitorState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingKillbotEntryContinuation(
                continuation.trainingKillbotEntryState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot1DeathContinuation(
                continuation.trainingRASBot1DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot2DeathContinuation(
                continuation.trainingRASBot2DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot3DeathContinuation(
                continuation.trainingRASBot3DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot4DeathContinuation(
                continuation.trainingRASBot4DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot1DeathContinuation(
                restoredLastBot1DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot2DeathContinuation(
                restoredLastBot2DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot3DeathContinuation(
                restoredLastBot3DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot4DeathContinuation(
                restoredLastBot4DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot5DeathContinuation(
                restoredLastBot5DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingInvulnerabilityPickupContinuation(
                continuation.trainingInvulnerabilityPickupState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingCloakPickupContinuation(
                restoredCloakPickupState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastRoomContinuation(
                restoredLastRoomState,
                finalRoomEntryWasTriggered:
                    restoredFinalRoomEntryState?.wasTriggered == true,
                allProducersWereTriggered:
                    continuation.trainingRASBot1DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot2DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot3DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot4DeathState?
                        .wasDestroyed == true
                    && continuation.trainingInvulnerabilityPickupState?
                        .scriptWasTriggered == true
                    && restoredCloakPickupState?
                        .scriptWasTriggered == true,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalRoomEntryContinuation(
            restoredFinalRoomEntryState,
            lastRoomState: restoredLastRoomState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalBotsCompletionContinuation(
            restoredFinalBotsCompletionState,
            allProducersWereDestroyed:
                restoredLastBot1DeathState?.wasDestroyed == true
                && restoredLastBot2DeathState?.wasDestroyed == true
                && restoredLastBot3DeathState?.wasDestroyed == true
                && restoredLastBot4DeathState?.wasDestroyed == true
                && restoredLastBot5DeathState?.wasDestroyed == true,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalGoalContinuation(
            restoredFinalGoalState,
            finalBotsState: restoredFinalBotsCompletionState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingGalleryBarrierContinuation(
                continuation.trainingGalleryBarrierState,
            robotGuidebotState:
                continuation.trainingRobotGuidebotState,
            level: continuationLevel
        ),
        validTrainingRobotGuidebotContinuation(
            continuation.trainingRobotGuidebotState,
            galleryState: continuation.trainingGalleryBarrierState,
            cameraState: continuation.trainingCameraMonitorState,
            level: routeAllocationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard case .room(let restoredRoomSourceIndex)
                = continuation.playerLocation,
              level.rooms.contains(where: {
                  $0.sourceIndex == restoredRoomSourceIndex
              }),
              containingIndoorRoomSourceIndex(
                  in: level,
                  position: continuation.playerPosition,
                  candidates: [restoredRoomSourceIndex]
              ) == restoredRoomSourceIndex else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard resumedAtTimestamp.isFinite,
              continuation.frameDuration.isFinite,
              continuation.frameDuration >= 0,
              continuation.gameTime.isFinite,
              continuation.gameTime >= 0,
              isCanonicalRigidTransform(
                  position: continuation.playerPosition,
                  orientation: continuation.playerOrientation
              ),
              continuation.velocity.x.isFinite,
              continuation.velocity.y.isFinite,
              continuation.velocity.z.isFinite,
              continuation.angularVelocity.x.isFinite,
              continuation.angularVelocity.y.isFinite,
              continuation.angularVelocity.z.isFinite,
              continuation.turnrollFixedAngle.isFinite,
              continuation.afterburnerFuel.isFinite,
              (0...5).contains(continuation.afterburnerFuel),
              continuation.energy.isFinite,
              continuation.energy >= 0,
              continuation.afterburnerMagnitude.isFinite,
              (0...1).contains(continuation.afterburnerMagnitude),
              continuation.wiggleFalloff.isFinite,
              (0...1).contains(continuation.wiggleFalloff),
              continuation.lastThrustTime.isFinite,
              continuation.trainingOpeningState.map({ state in
                  var expectedControls: [PlayerControlMask]
                  if state.upGoalWasReached == true {
                      if state.returnGoalWasReached == true {
                          guard state.forwardGoalWasReached else {
                              return false
                          }
                          expectedControls = [
                              [.up],
                              [.left, .up],
                          ]
                      } else if state.forwardGoalWasReached {
                          expectedControls = [[.reverse, .up]]
                      } else {
                          expectedControls = [[.forward, .up]]
                      }
                  } else if state.rightGoalWasReached == true {
                      if state.returnGoalWasReached == true {
                          guard state.forwardGoalWasReached else {
                              return false
                          }
                          expectedControls = [
                              [.right],
                              [.left, .right],
                          ]
                      } else if state.forwardGoalWasReached {
                          expectedControls = [[.reverse, .right]]
                      } else {
                          expectedControls = [[.forward, .right]]
                      }
                  } else if state.returnGoalWasReached == true {
                      guard state.forwardGoalWasReached else {
                          return false
                      }
                      expectedControls = [[.left]]
                  } else if state.forwardGoalWasReached {
                      expectedControls = [[.reverse]]
                  } else {
                      expectedControls = [[.forward]]
                  }
                  if state.downGoalWasReached == true {
                      let controlsBeforeReturnDown = expectedControls
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.up)
                          controls.insert(.down)
                          return controls
                      }
                      if state.upGoalWasReached == true {
                          expectedControls += controlsBeforeReturnDown.map {
                              controls in
                              var controls = controls
                              controls.insert(.down)
                              return controls
                          }
                      }
                  }
                  if state.repeatForwardWasPresented == true {
                      guard state.downGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.down)
                          controls.insert(.forward)
                          return controls
                      }
                  }
                  if state.repeatForwardGoalWasPresented == true {
                      guard state.repeatForwardWasPresented == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.forward)
                          controls.insert(.reverse)
                          return controls
                      }
                  }
                  return state.timerRemaining.isFinite
                      && (
                          state.welcomeWasPresented
                            || state.timerRemaining > 0
                      )
                      && (state.returnGoalWasReached != true
                          || level.trainingOpeningLesson?.returnLeft != nil)
                      && (state.rightGoalWasReached != true
                          || level.trainingOpeningLesson?.returnRight != nil)
                      && (state.upGoalWasReached != true
                          || (
                              state.rightGoalWasReached == true
                                && level.trainingOpeningLesson?.returnUp != nil
                          ))
                      && (state.downGoalWasReached != true
                          || level.trainingOpeningLesson?.returnDown != nil)
                      && (state.repeatForwardWasPresented != true
                          || level.trainingOpeningLesson?.repeatForward != nil)
                      && (state.repeatForwardGoalWasPresented != true
                          || level.trainingOpeningLesson?.repeatForwardGoal
                            != nil)
                      && expectedControls.contains(state.enabledControls)
              }) ?? true,
              (level.trainingOpeningLesson == nil)
                == (continuation.trainingOpeningState == nil) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        var restoredLevel = continuationLevel
        let binding = restoredLevel.defaultPlayerBinding!
        let objectIndex = restoredLevel.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        restoredLevel.objects[objectIndex].location = continuation.playerLocation
        restoredLevel.objects[objectIndex].position = continuation.playerPosition
        restoredLevel.objects[objectIndex].orientation = continuation.playerOrientation
        self.level = restoredLevel
        frameDuration = continuation.frameDuration
        gameTime = continuation.gameTime
        velocity = continuation.velocity
        angularVelocity = continuation.angularVelocity
        turnrollFixedAngle = continuation.turnrollFixedAngle
        indoorAutoLevelMode = continuation.indoorAutoLevelMode
        afterburnerFuel = continuation.afterburnerFuel
        afterburnerIsActive = continuation.afterburnerIsActive
        energy = continuation.energy
        afterburnerMagnitude = continuation.afterburnerMagnitude
        wiggleFalloff = continuation.wiggleFalloff
        lastThrustTime = continuation.lastThrustTime
        lastTimestamp = resumedAtTimestamp
        trainingOpeningState = continuation.trainingOpeningState
        trainingGalleryBarrierState =
            continuation.trainingGalleryBarrierState
        trainingRobotGuidebotState =
            continuation.trainingRobotGuidebotState
        trainingCameraMonitorState =
            continuation.trainingCameraMonitorState
        trainingKillbotEntryState =
            continuation.trainingKillbotEntryState
        trainingRASBot1DeathState =
            continuation.trainingRASBot1DeathState
        trainingRASBot2DeathState =
            continuation.trainingRASBot2DeathState
        trainingRASBot3DeathState =
            continuation.trainingRASBot3DeathState
        trainingRASBot4DeathState =
            continuation.trainingRASBot4DeathState
        trainingLastBot1DeathState = restoredLastBot1DeathState
        trainingLastBot2DeathState = restoredLastBot2DeathState
        trainingLastBot3DeathState = restoredLastBot3DeathState
        trainingLastBot4DeathState = restoredLastBot4DeathState
        trainingLastBot5DeathState = restoredLastBot5DeathState
        trainingInvulnerabilityPickupState =
            continuation.trainingInvulnerabilityPickupState
        trainingCloakPickupState = restoredCloakPickupState
        trainingLastRoomState = restoredLastRoomState
        trainingFinalRoomEntryState = restoredFinalRoomEntryState
        trainingFinalBotsCompletionState =
            restoredFinalBotsCompletionState
        trainingFinalGoalState = restoredFinalGoalState
        if restoredFinalGoalState?.endLevelWasRequested == true {
            trainingPostLevelResult = makeTrainingPostLevelResult(
                elapsedTime: gameTime
            )
            trainingSessionOutcome = .awaitingResultAcknowledgement
        }
        restoreTrainingGuidebotPresentation()
        if trainingRobotGuidebotState?.guidebotEnteredShip == true,
           let handle =
            level.trainingRobotGuidebotChain?.guidebotObjectHandle {
            setObjectPresentationVisibility(
                in: &self.level,
                handle: handle,
                isVisible: false
            )
        }
    }

    var continuation: PlayerSimulationContinuation {
        let binding = level.defaultPlayerBinding!
        let player = level.objects.first { $0.handle == binding.objectHandle }!
        return PlayerSimulationContinuation(
            schemaVersion: playerSimulationContinuationSchema(for: level),
            levelKey: level.levelKey,
            levelSHA256: level.source.levelSHA256,
            playerLocation: player.location,
            playerPosition: player.position,
            playerOrientation: player.orientation,
            frameDuration: frameDuration,
            gameTime: gameTime,
            velocity: velocity,
            angularVelocity: angularVelocity,
            turnrollFixedAngle: turnrollFixedAngle,
            indoorAutoLevelMode: indoorAutoLevelMode,
            afterburnerFuel: afterburnerFuel,
            afterburnerIsActive: afterburnerIsActive,
            energy: energy,
            afterburnerMagnitude: afterburnerMagnitude,
            wiggleFalloff: wiggleFalloff,
            lastThrustTime: lastThrustTime,
            trainingOpeningState: trainingOpeningState,
            trainingGalleryBarrierState:
                trainingGalleryBarrierState,
            trainingRobotGuidebotState:
                trainingRobotGuidebotState,
            trainingCameraMonitorState:
                trainingCameraMonitorState,
            trainingKillbotEntryState:
                trainingKillbotEntryState,
            trainingRASBot1DeathState:
                trainingRASBot1DeathState,
            trainingRASBot2DeathState:
                trainingRASBot2DeathState,
            trainingRASBot3DeathState:
                trainingRASBot3DeathState,
            trainingRASBot4DeathState:
                trainingRASBot4DeathState,
            trainingLastBot1DeathState:
                trainingLastBot1DeathState,
            trainingLastBot2DeathState:
                trainingLastBot2DeathState,
            trainingLastBot3DeathState:
                trainingLastBot3DeathState,
            trainingLastBot4DeathState:
                trainingLastBot4DeathState,
            trainingLastBot5DeathState:
                trainingLastBot5DeathState,
            trainingInvulnerabilityPickupState:
                trainingInvulnerabilityPickupState,
            trainingCloakPickupState: trainingCloakPickupState,
            trainingLastRoomState: trainingLastRoomState,
            trainingFinalRoomEntryState:
                trainingFinalRoomEntryState,
            trainingFinalBotsCompletionState:
                trainingFinalBotsCompletionState,
            trainingFinalGoalState: trainingFinalGoalState
        )
    }

    private func deployTrainingGuidebot(
        from player: PlacedObject,
        playerVelocity: Vector3
    ) {
        guard var state = trainingRobotGuidebotState,
              !state.guidebotIsDeployed,
              !state.guidebotEnteredShip,
              let definition = level.trainingRobotGuidebotChain?.guidebot,
              case let .room(roomSourceIndex) = player.location
        else {
            return
        }
        let spawnVelocity = playerVelocity
            + player.orientation.forward * definition.birthForwardVelocity
        let destination = player.position
            + player.orientation.forward * definition.goalForwardDistance
        let allocated = trainingGuidebotRoute(
            in: level,
            startRoomSourceIndex: roomSourceIndex,
            start: player.position,
            startForward: player.orientation.forward,
            destinationRoomSourceIndex: roomSourceIndex,
            destination: destination,
            radius: max(0, definition.collisionRadius - 0.1)
        )
        let route: TrainingGuidebotRoute
        let failure: TrainingGuidebotRouteError?
        switch allocated {
        case .success(let allocatedRoute):
            route = allocatedRoute
            failure = nil
        case .failure(let error):
            route = .init(
                mode: .direct,
                points: [destination],
                roomSourceIndices: [roomSourceIndex],
                nodeReferences: []
            )
            failure = error
        }
        state.guidebotIsDeployed = true
        state.guidebot = .init(
            spawnPosition: player.position,
            roomSourceIndex: roomSourceIndex,
            position: player.position,
            orientation: player.orientation,
            spawnVelocity: spawnVelocity,
            velocity: spawnVelocity,
            destination: destination,
            route: route,
            routeFailure: failure,
            routePointIndex: 0,
            activeSteeringMode: .direct,
            task: .outbound,
            allocationStartPosition: player.position,
            allocationStartForward: player.orientation.forward,
            routeDestination: destination,
            routeDestinationRoomSourceIndex: roomSourceIndex
        )
        trainingRobotGuidebotState = state
        restoreTrainingGuidebotPresentation()
    }

    private func restoreTrainingGuidebotPresentation() {
        guard let guidebot =
                trainingRobotGuidebotState?.guidebot,
              let chain = level.trainingRobotGuidebotChain,
              let objectIndex = level.objects.firstIndex(where: {
                  $0.handle == chain.guidebotObjectHandle
              }),
              let presentationIndex =
                level.objectPresentations.firstIndex(where: {
                    $0.objectHandle == chain.guidebotObjectHandle
                })
        else {
            return
        }
        level.objects[objectIndex].location =
            .room(guidebot.roomSourceIndex)
        level.objects[objectIndex].position = guidebot.position
        level.objects[objectIndex].orientation = guidebot.orientation
        let presentation = level.objectPresentations[presentationIndex]
        level.objectPresentations[presentationIndex] = .init(
            objectHandle: presentation.objectHandle,
            primaryModel: presentation.primaryModel,
            mediumModel: presentation.mediumModel,
            lowModel: presentation.lowModel,
            dyingModel: presentation.dyingModel,
            mediumDistance: presentation.mediumDistance,
            lowDistance: presentation.lowDistance,
            isVisible: true
        )
    }

    private func advanceTrainingGuidebot(
        duration: Float,
        player: PlacedObject,
        playerRadius: Float
    ) -> Bool {
        guard duration > 0,
              var state = trainingRobotGuidebotState,
              var guidebot = state.guidebot,
              let definition = level.trainingRobotGuidebotChain?.guidebot
        else {
            return false
        }
        if guidebot.task == .returnToShip {
            if case let .room(playerRoomSourceIndex) = player.location,
               playerRoomSourceIndex
                    != guidebot.routeDestinationRoomSourceIndex {
                let startForward = normalized(
                    guidebot.velocity == .zero
                        ? guidebot.orientation.forward
                        : guidebot.velocity
                )
                let allocated = trainingGuidebotRoute(
                    in: level,
                    startRoomSourceIndex: guidebot.roomSourceIndex,
                    start: guidebot.position,
                    startForward: startForward,
                    destinationRoomSourceIndex: playerRoomSourceIndex,
                    destination: player.position,
                    radius: max(
                        0,
                        definition.collisionRadius - 0.1
                    )
                )
                switch allocated {
                case .success(let route):
                    guidebot.route = route
                    guidebot.routeFailure = nil
                case .failure(let failure):
                    guidebot.route = .init(
                        mode: .direct,
                        points: [player.position],
                        roomSourceIndices: [
                            guidebot.roomSourceIndex
                        ],
                        nodeReferences: []
                    )
                    guidebot.routeFailure = failure
                }
                guidebot.routePointIndex = 0
                guidebot.activeSteeringMode = .direct
                guidebot.allocationStartPosition = guidebot.position
                guidebot.allocationStartForward = startForward
                guidebot.routeDestination = player.position
                guidebot.routeDestinationRoomSourceIndex =
                    playerRoomSourceIndex
            }
            guidebot.destination = player.position
        }
        let followsAllocatedRoute =
            guidebot.routeFailure == nil && guidebot.route.mode != .direct
        func passedRoutePoint(at position: Vector3) -> Bool {
            let index = guidebot.routePointIndex
            guard followsAllocatedRoute,
                  index < guidebot.route.points.count - 1 else {
                return false
            }
            let point = guidebot.route.points[index]
            let pathDirection = index == 0
                ? guidebot.route.points[index + 1] - point
                : point - guidebot.route.points[index - 1]
            return dot(position - point, pathDirection) >= 0
        }
        while passedRoutePoint(at: guidebot.position) {
            guidebot.routePointIndex += 1
        }
        let isFinalRoutePoint =
            guidebot.routePointIndex == guidebot.route.points.count - 1
        let target = followsAllocatedRoute
            ? (guidebot.task == .returnToShip && isFinalRoutePoint
                ? guidebot.destination
                : guidebot.route.points[guidebot.routePointIndex])
            : guidebot.destination
        let remaining = target - guidebot.position
        let distance = sqrt(dot(remaining, remaining))
        let reachedGoal =
            isFinalRoutePoint
                && distance <= definition.goalCircleDistance
        let desiredVelocity = reachedGoal
            ? Vector3.zero
            : normalized(remaining) * definition.maximumVelocity
        let velocityDelta = desiredVelocity - guidebot.velocity
        let deltaMagnitude = sqrt(dot(velocityDelta, velocityDelta))
        let maximumDelta = definition.maximumDeltaVelocity * duration
        if deltaMagnitude > maximumDelta, deltaMagnitude > 0 {
            guidebot.velocity = guidebot.velocity
                + velocityDelta / deltaMagnitude * maximumDelta
        } else {
            guidebot.velocity = desiredVelocity
        }
        let movementStart = guidebot.position
        let trace = traceIndoorMovement(
            in: level,
            startRoom: guidebot.roomSourceIndex,
            start: guidebot.position,
            end: guidebot.position + guidebot.velocity * duration,
            radius: definition.collisionRadius
        )
        guidebot.position = trace.finalPosition
        guidebot.roomSourceIndex = trace.containingRoomSourceIndex
        if case .wallHit = trace.outcome {
            guidebot.velocity = .zero
        }
        while passedRoutePoint(at: guidebot.position) {
            guidebot.routePointIndex += 1
        }
        guidebot.activeSteeringMode = reachedGoal
            ? .stopped
            : followsAllocatedRoute ? .allocatedRoute : .direct
        if guidebot.task == .returnToShip,
           case let .room(playerRoomSourceIndex) = player.location,
           guidebot.roomSourceIndex == playerRoomSourceIndex,
           segmentSphereHitFraction(
               start: movementStart,
               end: guidebot.position,
               center: player.position,
               radius: definition.collisionRadius + playerRadius
           ) != nil {
            state.guidebot = nil
            state.guidebotIsDeployed = false
            state.guidebotEnteredShip = true
            trainingRobotGuidebotState = state
            let handle =
                level.trainingRobotGuidebotChain!.guidebotObjectHandle
            setObjectPresentationVisibility(
                in: &level,
                handle: handle,
                isVisible: false
            )
            return true
        }
        state.guidebot = guidebot
        trainingRobotGuidebotState = state
        restoreTrainingGuidebotPresentation()
        return false
    }

    private func requestTrainingGuidebotReturn(
        to player: PlacedObject
    ) -> Bool {
        guard var state = trainingRobotGuidebotState,
              !state.returnWasRequested,
              !state.guidebotEnteredShip,
              var guidebot = state.guidebot,
              let definition = level.trainingRobotGuidebotChain?.guidebot,
              case let .room(playerRoomSourceIndex) = player.location
        else {
            return false
        }
        let startForward = normalized(
            guidebot.velocity == .zero
                ? guidebot.orientation.forward
                : guidebot.velocity
        )
        let allocated = trainingGuidebotRoute(
            in: level,
            startRoomSourceIndex: guidebot.roomSourceIndex,
            start: guidebot.position,
            startForward: startForward,
            destinationRoomSourceIndex: playerRoomSourceIndex,
            destination: player.position,
            radius: max(0, definition.collisionRadius - 0.1)
        )
        switch allocated {
        case .success(let route):
            guidebot.route = route
            guidebot.routeFailure = nil
        case .failure(let failure):
            guidebot.route = .init(
                mode: .direct,
                points: [player.position],
                roomSourceIndices: [guidebot.roomSourceIndex],
                nodeReferences: []
            )
            guidebot.routeFailure = failure
        }
        guidebot.destination = player.position
        guidebot.routePointIndex = 0
        guidebot.activeSteeringMode = .direct
        guidebot.task = .returnToShip
        guidebot.allocationStartPosition = guidebot.position
        guidebot.allocationStartForward = startForward
        guidebot.routeDestination = player.position
        guidebot.routeDestinationRoomSourceIndex =
            playerRoomSourceIndex
        state.guidebot = guidebot
        state.returnWasRequested = true
        trainingRobotGuidebotState = state
        return true
    }

    func destroyTrainingRobot(handle: UInt32) {
        guard let chain = level.trainingRobotGuidebotChain,
              handle == chain.destroyRobotObjectHandle,
              var state = trainingRobotGuidebotState,
              !state.robotWasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        openTrainingGalleryBarrier(in: &level)
        if var galleryState = trainingGalleryBarrierState {
            galleryState.markerLightDistance =
                level.trainingGalleryBarrier!.openMarkerLightDistance
            trainingGalleryBarrierState = galleryState
        }
        state.robotWasDestroyed = true
        state.robotShields = min(state.robotShields, -0.000_001)
        state.controlsWereRestored = true
        state.destructionTimerRemaining = chain.destructionDelay
        trainingRobotGuidebotState = state
    }

    func destroyTrainingRASBot1(handle: UInt32) {
        guard let chain = level.trainingRASBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot1DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot1DeathState = state
    }

    func destroyTrainingRASBot2(handle: UInt32) {
        guard let chain = level.trainingRASBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot2DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot2DeathState = state
    }

    func destroyTrainingRASBot3(handle: UInt32) {
        guard let chain = level.trainingRASBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot3DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot3DeathState = state
    }

    func destroyTrainingRASBot4(handle: UInt32) {
        guard let chain = level.trainingRASBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot4DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot4DeathState = state
    }

    func destroyTrainingLastBot1(handle: UInt32) {
        guard let chain = level.trainingLastBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot1DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot1DeathState = state
    }

    func destroyTrainingLastBot2(handle: UInt32) {
        guard let chain = level.trainingLastBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot2DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot2DeathState = state
    }

    func destroyTrainingLastBot3(handle: UInt32) {
        guard let chain = level.trainingLastBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot3DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot3DeathState = state
    }

    func destroyTrainingLastBot4(handle: UInt32) {
        guard let chain = level.trainingLastBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot4DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot4DeathState = state
    }

    func destroyTrainingLastBot5(handle: UInt32) {
        guard let chain = level.trainingLastBot5DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot5DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot5DeathState = state
    }

    func update(at timestamp: Double, input: InputSnapshot) -> PlayerSimulationFrame {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        precondition(pauseDepth == 0)
        let systemsFrameDuration = frameDuration
        let systemsGameTime = gameTime

        let binding = level.defaultPlayerBinding!
        let objectIndex = level.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        var object = level.objects[objectIndex]
        let controlsAreSuspended =
            trainingFinalGoalState?.endLevelWasRequested == true
        let currentEnabledControls = controlsAreSuspended
            ? PlayerControlMask(rawValue: 0)
            : trainingPlayerControlMask(
                galleryWasTriggered:
                    trainingGalleryBarrierState?.wasTriggered == true,
                controlsWereRestored:
                    trainingRobotGuidebotState?
                        .controlsWereRestored == true,
                openingControls: trainingOpeningState?.enabledControls
            )
        let input = controlsAreSuspended
            ? InputSnapshot.zero
            : input.applying(currentEnabledControls)
        let cameraMonitorWasUsedAtFrameStart =
            trainingCameraMonitorState?.wasUsed == true
        var guidebotReturnWasRequestedThisFrame = false
        var cameraMonitorWasUsedThisFrame = false
        if input.usesInventory,
           var state = trainingCameraMonitorState,
           state.isHeld,
           !state.wasUsed,
           let chain = level.trainingCameraMonitorChain {
            // Preserve the reached inventory item's typed effect before the
            // one-use callback removes its backing object.
            state.isHeld = false
            state.wasUsed = true
            state.popupRemaining = chain.popupDuration
            state.completionTimerRemaining =
                chain.completionTimerDuration
            trainingCameraMonitorState = state
            cameraMonitorWasUsedThisFrame = true
            level.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &level,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if input.deploysTrainingGuidebot {
            if cameraMonitorWasUsedAtFrameStart,
               trainingRobotGuidebotState?.guidebotIsDeployed == true {
                guidebotReturnWasRequestedThisFrame =
                    requestTrainingGuidebotReturn(to: object)
            } else {
                deployTrainingGuidebot(from: object, playerVelocity: velocity)
            }
        }
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        guard case let .room(startRoom) = object.location else {
            preconditionFailure("The Slice 10 player simulation is indoor.")
        }
        if var state = trainingRobotGuidebotState,
           let chain = level.trainingRobotGuidebotChain {
            let combat = chain.combat
            if input.firesPrimaryWeapon,
               systemsGameTime >= state.nextPrimaryFireTime,
               energy >= combat.batteryEnergyCost {
                for gunpoint in combat.gunpoints {
                    let position = object.position
                        + object.orientation.right * gunpoint.x
                        + object.orientation.up * gunpoint.y
                        + object.orientation.forward * gunpoint.z
                    state.projectiles.append(.init(
                        roomSourceIndex: startRoom,
                        position: position,
                        velocity:
                            object.orientation.forward
                                * combat.projectileSpeed,
                        lifeRemaining: combat.projectileLifetime
                    ))
                }
                energy -= combat.batteryEnergyCost
                state.nextPrimaryFireTime =
                    systemsGameTime + combat.batteryFireWait
            }

            let robot = level.objects.first {
                $0.handle == chain.destroyRobotObjectHandle
            }
            let rasBot1Chain = level.trainingRASBot1DeathChain
            let rasBot1 = rasBot1Chain.flatMap { rasBot1Chain in
                level.objects.first {
                    $0.handle == rasBot1Chain.robotObjectHandle
                }
            }
            let rasBot2Chain = level.trainingRASBot2DeathChain
            let rasBot2 = rasBot2Chain.flatMap { rasBot2Chain in
                level.objects.first {
                    $0.handle == rasBot2Chain.robotObjectHandle
                }
            }
            let rasBot3Chain = level.trainingRASBot3DeathChain
            let rasBot3 = rasBot3Chain.flatMap { rasBot3Chain in
                level.objects.first {
                    $0.handle == rasBot3Chain.robotObjectHandle
                }
            }
            let rasBot4Chain = level.trainingRASBot4DeathChain
            let rasBot4 = rasBot4Chain.flatMap { rasBot4Chain in
                level.objects.first {
                    $0.handle == rasBot4Chain.robotObjectHandle
                }
            }
            let lastBot1Chain = level.trainingLastBot1DeathChain
            let lastBot1 = lastBot1Chain.flatMap { lastBot1Chain in
                level.objects.first {
                    $0.handle == lastBot1Chain.robotObjectHandle
                }
            }
            let lastBot2Chain = level.trainingLastBot2DeathChain
            let lastBot2 = lastBot2Chain.flatMap { lastBot2Chain in
                level.objects.first {
                    $0.handle == lastBot2Chain.robotObjectHandle
                }
            }
            let lastBot3Chain = level.trainingLastBot3DeathChain
            let lastBot3 = lastBot3Chain.flatMap { lastBot3Chain in
                level.objects.first {
                    $0.handle == lastBot3Chain.robotObjectHandle
                }
            }
            let lastBot4Chain = level.trainingLastBot4DeathChain
            let lastBot4 = lastBot4Chain.flatMap { lastBot4Chain in
                level.objects.first {
                    $0.handle == lastBot4Chain.robotObjectHandle
                }
            }
            let lastBot5Chain = level.trainingLastBot5DeathChain
            let lastBot5 = lastBot5Chain.flatMap { lastBot5Chain in
                level.objects.first {
                    $0.handle == lastBot5Chain.robotObjectHandle
                }
            }
            var rasBot1State = trainingRASBot1DeathState
            var rasBot2State = trainingRASBot2DeathState
            var rasBot3State = trainingRASBot3DeathState
            var rasBot4State = trainingRASBot4DeathState
            var lastBot1State = trainingLastBot1DeathState
            var lastBot2State = trainingLastBot2DeathState
            var lastBot3State = trainingLastBot3DeathState
            var lastBot4State = trainingLastBot4DeathState
            var lastBot5State = trainingLastBot5DeathState
            var survivingProjectiles: [TrainingLaserProjectileState] = []
            for var projectile in state.projectiles {
                let end = projectile.position
                    + projectile.velocity * systemsFrameDuration
                let trace = traceIndoorMovement(
                    in: level,
                    startRoom: projectile.roomSourceIndex,
                    start: projectile.position,
                    end: end,
                    radius: combat.projectileRadius
                )
                let robotHit = robot.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex)
                    else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            combat.projectileRadius
                                + combat.robotCollisionRadius
                    )
                }
                let rasBot1Hit = rasBot1.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot1Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot1Chain.combat.projectileRadius
                                + rasBot1Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let rasBot2Hit = rasBot2.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot2Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot2Chain.combat.projectileRadius
                                + rasBot2Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let rasBot3Hit = rasBot3.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot3Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot3Chain.combat.projectileRadius
                                + rasBot3Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let rasBot4Hit = rasBot4.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let rasBot4Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            rasBot4Chain.combat.projectileRadius
                                + rasBot4Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot1Hit = lastBot1.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot1Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot1Chain.combat.projectileRadius
                                + lastBot1Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot2Hit = lastBot2.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot2Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot2Chain.combat.projectileRadius
                                + lastBot2Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot3Hit = lastBot3.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot3Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot3Chain.combat.projectileRadius
                                + lastBot3Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot4Hit = lastBot4.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot4Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot4Chain.combat.projectileRadius
                        + lastBot4Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let lastBot5Hit = lastBot5.flatMap { robot -> Float? in
                    guard robot.location
                            == .room(projectile.roomSourceIndex),
                          let lastBot5Chain else {
                        return nil
                    }
                    return segmentSphereHitFraction(
                        start: projectile.position,
                        end: end,
                        center: robot.position,
                        radius:
                            lastBot5Chain.combat.projectileRadius
                                + lastBot5Chain.combat
                                    .robotCollisionRadius
                    )
                }
                let traceFraction = vectorDistance(
                    projectile.position,
                    end
                ) > 0
                    ? vectorDistance(
                        projectile.position,
                        trace.finalPosition
                    ) / vectorDistance(projectile.position, end)
                    : 1
                var nearestRASBotHit: (handle: UInt32, fraction: Float)?
                if let rasBot1Hit {
                    nearestRASBotHit = (
                        rasBot1Chain!.robotObjectHandle,
                        rasBot1Hit
                    )
                }
                if let rasBot2Hit,
                   rasBot2Hit < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        rasBot2Chain!.robotObjectHandle,
                        rasBot2Hit
                    )
                }
                if let rasBot3Hit,
                   rasBot3Hit < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        rasBot3Chain!.robotObjectHandle,
                        rasBot3Hit
                    )
                }
                if let rasBot4Hit,
                   rasBot4Hit < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        rasBot4Chain!.robotObjectHandle,
                        rasBot4Hit
                    )
                }
                if let lastBot1Hit,
                   lastBot1Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot1Chain!.robotObjectHandle,
                        lastBot1Hit
                    )
                }
                if let lastBot2Hit,
                   lastBot2Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot2Chain!.robotObjectHandle,
                        lastBot2Hit
                    )
                }
                if let lastBot3Hit,
                   lastBot3Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot3Chain!.robotObjectHandle,
                        lastBot3Hit
                    )
                }
                if let lastBot4Hit,
                   lastBot4Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot4Chain!.robotObjectHandle,
                        lastBot4Hit
                    )
                }
                if let lastBot5Hit,
                   lastBot5Hit
                    < (nearestRASBotHit?.fraction ?? .infinity) {
                    nearestRASBotHit = (
                        lastBot5Chain!.robotObjectHandle,
                        lastBot5Hit
                    )
                }
                if let nearestRASBotHit,
                   nearestRASBotHit.fraction
                    <= traceFraction + 0.000_1,
                   robotHit.map({
                       nearestRASBotHit.fraction < $0
                   }) ?? true {
                    if nearestRASBotHit.handle
                        == rasBot1Chain?.robotObjectHandle {
                        rasBot1State?.shields -=
                            rasBot1Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == rasBot2Chain?.robotObjectHandle {
                        rasBot2State?.shields -=
                            rasBot2Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == rasBot3Chain?.robotObjectHandle {
                        rasBot3State?.shields -=
                            rasBot3Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == rasBot4Chain?.robotObjectHandle {
                        rasBot4State?.shields -=
                            rasBot4Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot1Chain?.robotObjectHandle {
                        lastBot1State?.shields -=
                            lastBot1Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot2Chain?.robotObjectHandle {
                        lastBot2State?.shields -=
                            lastBot2Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot3Chain?.robotObjectHandle {
                        lastBot3State?.shields -=
                            lastBot3Chain!.combat.projectileDamage
                    } else if nearestRASBotHit.handle
                        == lastBot4Chain?.robotObjectHandle {
                        lastBot4State?.shields -=
                            lastBot4Chain!.combat.projectileDamage
                    } else {
                        lastBot5State?.shields -=
                            lastBot5Chain!.combat.projectileDamage
                    }
                    continue
                }
                if let robotHit, robotHit <= traceFraction + 0.000_1 {
                    state.robotShields -= combat.projectileDamage
                    continue
                }
                guard case .noHit = trace.outcome else { continue }
                projectile.position = trace.finalPosition
                projectile.roomSourceIndex =
                    trace.containingRoomSourceIndex
                projectile.lifeRemaining -= systemsFrameDuration
                if projectile.lifeRemaining > 0 {
                    survivingProjectiles.append(projectile)
                }
            }
            state.projectiles = survivingProjectiles
            let robotWasKilled =
                !state.robotWasDestroyed && state.robotShields < 0
            let rasBot1WasKilled =
                rasBot1State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let rasBot2WasKilled =
                rasBot2State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let rasBot3WasKilled =
                rasBot3State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let rasBot4WasKilled =
                rasBot4State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot1WasKilled =
                lastBot1State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot2WasKilled =
                lastBot2State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot3WasKilled =
                lastBot3State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot4WasKilled =
                lastBot4State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            let lastBot5WasKilled =
                lastBot5State.map {
                    !$0.wasDestroyed && $0.shields < 0
                } ?? false
            trainingRobotGuidebotState = state
            trainingRASBot1DeathState = rasBot1State
            trainingRASBot2DeathState = rasBot2State
            trainingRASBot3DeathState = rasBot3State
            trainingRASBot4DeathState = rasBot4State
            trainingLastBot1DeathState = lastBot1State
            trainingLastBot2DeathState = lastBot2State
            trainingLastBot3DeathState = lastBot3State
            trainingLastBot4DeathState = lastBot4State
            trainingLastBot5DeathState = lastBot5State
            if robotWasKilled {
                destroyTrainingRobot(handle: chain.destroyRobotObjectHandle)
            }
            if rasBot1WasKilled {
                destroyTrainingRASBot1(
                    handle: rasBot1Chain!.robotObjectHandle
                )
            }
            if rasBot2WasKilled {
                destroyTrainingRASBot2(
                    handle: rasBot2Chain!.robotObjectHandle
                )
            }
            if rasBot3WasKilled {
                destroyTrainingRASBot3(
                    handle: rasBot3Chain!.robotObjectHandle
                )
            }
            if rasBot4WasKilled {
                destroyTrainingRASBot4(
                    handle: rasBot4Chain!.robotObjectHandle
                )
            }
            if lastBot1WasKilled {
                destroyTrainingLastBot1(
                    handle: lastBot1Chain!.robotObjectHandle
                )
            }
            if lastBot2WasKilled {
                destroyTrainingLastBot2(
                    handle: lastBot2Chain!.robotObjectHandle
                )
            }
            if lastBot3WasKilled {
                destroyTrainingLastBot3(
                    handle: lastBot3Chain!.robotObjectHandle
                )
            }
            if lastBot4WasKilled {
                destroyTrainingLastBot4(
                    handle: lastBot4Chain!.robotObjectHandle
                )
            }
            if lastBot5WasKilled {
                destroyTrainingLastBot5(
                    handle: lastBot5Chain!.robotObjectHandle
                )
            }
        }
        var guidebotEnteredShipThisFrame = false
        var orientation = object.orientation
        if input.directLookPitchRadians != 0 || input.directLookYawRadians != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: sourceFixedAngleRadians(
                        input.directLookPitchRadians
                    ),
                    yaw: sourceFixedAngleRadians(
                        input.directLookYawRadians
                    ),
                    roll: 0
                )
            )
        }
        let linearThrustOrientation = orientation
        var forwardControl = input.forward
        if input.afterburner > 0 {
            if afterburnerFuel > 0 {
                afterburnerIsActive = true
                forwardControl = sourceAfterburnerForwardControl(
                    afterburner: input.afterburner,
                    fuel: afterburnerFuel
                )
                afterburnerFuel -= systemsFrameDuration
                if afterburnerFuel < 0 {
                    afterburnerFuel = 0
                }
            } else {
                afterburnerIsActive = false
            }
        } else {
            afterburnerIsActive = false
            if afterburnerFuel < 5, energy > 5 {
                afterburnerFuel += systemsFrameDuration
                if afterburnerFuel > 5 {
                    afterburnerFuel = 5
                }
                energy -= systemsFrameDuration
            }
        }
        let force = Vector3(
            x: ship.physics.fullThrust * (
                linearThrustOrientation.forward.x * forwardControl
                    + linearThrustOrientation.up.x * input.vertical
                    + linearThrustOrientation.right.x * input.sideways
            ),
            y: ship.physics.fullThrust * (
                linearThrustOrientation.forward.y * forwardControl
                    + linearThrustOrientation.up.y * input.vertical
                    + linearThrustOrientation.right.y * input.sideways
            ),
            z: ship.physics.fullThrust * (
                linearThrustOrientation.forward.z * forwardControl
                    + linearThrustOrientation.up.z * input.vertical
                    + linearThrustOrientation.right.z * input.sideways
            )
        )
        let view = defaultPlayerView(in: level)
        var position = object.position
        var roomSourceIndex = startRoom
        var trainingForwardGoalWasReachedThisFrame = false
        var trainingReturnGoalWasReachedThisFrame = false
        var trainingRightGoalWasReachedThisFrame = false
        var trainingUpGoalWasReachedThisFrame = false
        var trainingDownGoalWasReachedThisFrame = false
        var trainingRepeatForwardWasReachedThisFrame = false
        var trainingGalleryWasCrossedThisFrame = false
        var trainingKillbotEntryWasCrossedThisFrame = false
        var trainingFinalRoomEntryWasCrossedThisFrame = false
        var trainingCameraMonitorWasHitThisFrame = false
        var trainingInvulnerabilityPickupWasHitThisFrame = false
        var trainingCloakPickupWasHitThisFrame = false
        var trainingFinalGoalWasHitThisFrame = false
        if ship.physics.behaviors.contains(.wiggle) {
            if sqrt(dot(force, force)) < 0.1 {
                wiggleFalloff -= systemsFrameDuration / 2
            } else {
                wiggleFalloff += systemsFrameDuration / 2
            }
            wiggleFalloff = max(0, min(1, wiggleFalloff))
            let scale = max(0.1, 1 - wiggleFalloff)
            let wiggle = ship.physics.wiggleAmplitude * scale * (
                sourceFixedSine(
                    gameTime: systemsGameTime,
                    wigglesPerSecond: ship.physics.wigglesPerSecond
                )
                    - sourceFixedSine(
                        gameTime: systemsGameTime - systemsFrameDuration,
                        wigglesPerSecond: ship.physics.wigglesPerSecond
                    )
            )
            let traceStart = position
            let trace = traceIndoorMovement(
                in: level,
                startRoom: roomSourceIndex,
                start: position,
                end: position + linearThrustOrientation.up * wiggle,
                radius: view.collisionRadius
            )
            trainingCameraMonitorWasHitThisFrame =
                trainingCameraMonitorWasHitThisFrame
                || trainingCameraMonitorPickupWasHit(
                    in: level,
                    state: trainingCameraMonitorState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingInvulnerabilityPickupWasHitThisFrame =
                trainingInvulnerabilityPickupWasHitThisFrame
                || trainingInvulnerabilityPickupWasHit(
                    in: level,
                    state: trainingInvulnerabilityPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingCloakPickupWasHitThisFrame =
                trainingCloakPickupWasHitThisFrame
                || trainingCloakPickupWasHit(
                    in: level,
                    state: trainingCloakPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingFinalGoalWasHitThisFrame =
                trainingFinalGoalWasHitThisFrame
                || trainingFinalGoalWasHit(
                    in: level,
                    state: trainingFinalGoalState,
                    finalBotsState: trainingFinalBotsCompletionState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingGalleryWasCrossedThisFrame =
                trainingGalleryWasCrossedThisFrame
                || trainingGalleryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingKillbotEntryWasCrossedThisFrame =
                trainingKillbotEntryWasCrossedThisFrame
                || trainingKillbotEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingFinalRoomEntryWasCrossedThisFrame =
                trainingFinalRoomEntryWasCrossedThisFrame
                || trainingFinalRoomEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            if let lesson = level.trainingOpeningLesson {
                trainingForwardGoalWasReachedThisFrame =
                    trainingForwardGoalWasReached(
                        in: level,
                        lesson: lesson,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
                if trainingOpeningState?.forwardGoalWasReached == true,
                   trainingOpeningState?.returnGoalWasReached != true,
                   let returnLeft = lesson.returnLeft {
                    trainingReturnGoalWasReachedThisFrame =
                        trainingReturnGoalWasReached(
                            in: level,
                            lesson: returnLeft,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
                if trainingOpeningState?.rightGoalWasReached != true,
                   let returnRight = lesson.returnRight {
                    trainingRightGoalWasReachedThisFrame =
                        trainingRightGoalWasReached(
                            in: level,
                            lesson: returnRight,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
                if trainingOpeningState?.rightGoalWasReached == true,
                   trainingOpeningState?.upGoalWasReached != true,
                   let returnUp = lesson.returnUp {
                    trainingUpGoalWasReachedThisFrame =
                        trainingUpGoalWasReached(
                            in: level,
                            lesson: returnUp,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
                if trainingOpeningState?.downGoalWasReached != true,
                   let returnDown = lesson.returnDown {
                    trainingDownGoalWasReachedThisFrame =
                        trainingDownGoalWasReached(
                            in: level,
                            lesson: returnDown,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
                if trainingOpeningState?.downGoalWasReached == true,
                   trainingOpeningState?.repeatForwardWasPresented != true,
                   let repeatForward = lesson.repeatForward {
                    trainingRepeatForwardWasReachedThisFrame =
                        trainingRepeatForwardWasReached(
                            in: level,
                            lesson: repeatForward,
                            playerStart: traceStart,
                            playerEnd: trace.finalPosition,
                            playerRadius: view.collisionRadius,
                            visitedRoomSourceIndices:
                                trace.visitedRoomSourceIndices
                        )
                }
            }
            if case .noHit = trace.outcome {
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
            }
        }
        if turnrollFixedAngle != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: 0,
                    yaw: 0,
                    roll: sourceFixedAngleUnits(-turnrollFixedAngle)
                )
            )
        }

        var rotationalThrust = Vector3(
            x: ship.physics.fullRotationalThrust
                * max(-0.75, min(0.75, input.pitch)),
            y: ship.physics.fullRotationalThrust * input.yaw,
            z: ship.physics.fullRotationalThrust * input.roll
        )
        if forwardControl != 0 || input.sideways != 0 || input.vertical != 0
            || rotationalThrust != .zero {
            lastThrustTime = gameTime
        }
        rotationalThrust = sourceIndoorAutoLevelThrust(
            rotationalThrust,
            orientation: orientation,
            storedOrientation: object.orientation,
            fullRotationalThrust: ship.physics.fullRotationalThrust,
            turnrollFixedAngle: turnrollFixedAngle,
            mode: indoorAutoLevelMode,
            gameTime: gameTime,
            lastThrustTime: lastThrustTime
        )
        angularVelocity = analyticAngularVelocity(
            velocity: angularVelocity,
            force: rotationalThrust,
            mass: ship.physics.mass,
            drag: ship.physics.rotationalDrag,
            duration: systemsFrameDuration
        )
        orientation = sourceMatrixMultiply(
            orientation,
            sourceRotationMatrix(
                pitch: sourceFixedAngleUnits(
                    angularVelocity.x * systemsFrameDuration
                ),
                yaw: sourceFixedAngleUnits(
                    angularVelocity.y * systemsFrameDuration
                ),
                roll: sourceFixedAngleUnits(
                    angularVelocity.z * systemsFrameDuration
                )
            )
        )
        if ship.physics.behaviors.contains(.turnroll) {
            let desired = max(
                -32_000,
                min(
                    32_000,
                    -angularVelocity.y * ship.physics.turnrollRatio
                )
            )
            let maximumChange = Float(
                Int(ship.physics.maximumTurnrollRate * systemsFrameDuration)
            )
            if abs(desired - turnrollFixedAngle) > maximumChange {
                turnrollFixedAngle += desired > turnrollFixedAngle
                    ? maximumChange
                    : -maximumChange
            } else {
                turnrollFixedAngle = Float(Int(desired))
            }
        }
        if turnrollFixedAngle != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: 0,
                    yaw: 0,
                    roll: sourceFixedAngleUnits(turnrollFixedAngle)
                )
            )
        }
        orientation = sourceOrthogonalized(orientation)
        object.orientation = orientation
        let orientedPlayerIndex = level.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        level.objects[orientedPlayerIndex].orientation = orientation

        var remainingDuration = systemsFrameDuration
        var responseForce = force
        var wallContact: IndoorWallContact?
        var collisionCount = 0
        while remainingDuration > 0 && collisionCount < 9 {
            let integrated = analyticLinearMotion(
                position: position,
                velocity: velocity,
                force: responseForce,
                mass: ship.physics.mass,
                drag: ship.physics.drag,
                duration: remainingDuration
            )
            let traceStart = position
            let trace = traceIndoorMovement(
                in: level,
                startRoom: roomSourceIndex,
                start: position,
                end: integrated.position,
                radius: view.collisionRadius
            )
            trainingCameraMonitorWasHitThisFrame =
                trainingCameraMonitorWasHitThisFrame
                || trainingCameraMonitorPickupWasHit(
                    in: level,
                    state: trainingCameraMonitorState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingInvulnerabilityPickupWasHitThisFrame =
                trainingInvulnerabilityPickupWasHitThisFrame
                || trainingInvulnerabilityPickupWasHit(
                    in: level,
                    state: trainingInvulnerabilityPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingCloakPickupWasHitThisFrame =
                trainingCloakPickupWasHitThisFrame
                || trainingCloakPickupWasHit(
                    in: level,
                    state: trainingCloakPickupState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingFinalGoalWasHitThisFrame =
                trainingFinalGoalWasHitThisFrame
                || trainingFinalGoalWasHit(
                    in: level,
                    state: trainingFinalGoalState,
                    finalBotsState: trainingFinalBotsCompletionState,
                    playerStart: traceStart,
                    playerEnd: trace.finalPosition,
                    playerRadius: view.collisionRadius,
                    visitedRoomSourceIndices:
                        trace.visitedRoomSourceIndices
                )
            trainingGalleryWasCrossedThisFrame =
                trainingGalleryWasCrossedThisFrame
                || trainingGalleryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingKillbotEntryWasCrossedThisFrame =
                trainingKillbotEntryWasCrossedThisFrame
                || trainingKillbotEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            trainingFinalRoomEntryWasCrossedThisFrame =
                trainingFinalRoomEntryWasCrossedThisFrame
                || trainingFinalRoomEntryTriggerWasCrossed(
                    in: level,
                    passedPortalFaces: trace.passedPortalFaces
                )
            if !trainingForwardGoalWasReachedThisFrame,
               let lesson = level.trainingOpeningLesson {
                trainingForwardGoalWasReachedThisFrame =
                    trainingForwardGoalWasReached(
                        in: level,
                        lesson: lesson,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingReturnGoalWasReachedThisFrame,
               trainingOpeningState?.forwardGoalWasReached == true,
               trainingOpeningState?.returnGoalWasReached != true,
               let returnLeft = level.trainingOpeningLesson?.returnLeft {
                trainingReturnGoalWasReachedThisFrame =
                    trainingReturnGoalWasReached(
                        in: level,
                        lesson: returnLeft,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingRightGoalWasReachedThisFrame,
               trainingOpeningState?.rightGoalWasReached != true,
               let returnRight = level.trainingOpeningLesson?.returnRight {
                trainingRightGoalWasReachedThisFrame =
                    trainingRightGoalWasReached(
                        in: level,
                        lesson: returnRight,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingUpGoalWasReachedThisFrame,
               trainingOpeningState?.rightGoalWasReached == true,
               trainingOpeningState?.upGoalWasReached != true,
               let returnUp = level.trainingOpeningLesson?.returnUp {
                trainingUpGoalWasReachedThisFrame =
                    trainingUpGoalWasReached(
                        in: level,
                        lesson: returnUp,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingDownGoalWasReachedThisFrame,
               trainingOpeningState?.downGoalWasReached != true,
               let returnDown = level.trainingOpeningLesson?.returnDown {
                trainingDownGoalWasReachedThisFrame =
                    trainingDownGoalWasReached(
                        in: level,
                        lesson: returnDown,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            if !trainingRepeatForwardWasReachedThisFrame,
               trainingOpeningState?.downGoalWasReached == true,
               trainingOpeningState?.repeatForwardWasPresented != true,
               let repeatForward =
                    level.trainingOpeningLesson?.repeatForward {
                trainingRepeatForwardWasReachedThisFrame =
                    trainingRepeatForwardWasReached(
                        in: level,
                        lesson: repeatForward,
                        playerStart: traceStart,
                        playerEnd: trace.finalPosition,
                        playerRadius: view.collisionRadius,
                        visitedRoomSourceIndices:
                            trace.visitedRoomSourceIndices
                    )
            }
            guard case let .wallHit(contact) = trace.outcome else {
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
                velocity = integrated.velocity
                remainingDuration = 0
                break
            }

            wallContact = wallContact ?? contact
            let attemptedDistance = vectorDistance(position, integrated.position)
            let priorRemainingDuration = remainingDuration
            remainingDuration = attemptedDistance > 0
                ? priorRemainingDuration
                    * ((attemptedDistance - contact.distance) / attemptedDistance)
                : 0
            let movedTime = priorRemainingDuration - remainingDuration
            if movedTime > 0.0001 {
                velocity = Vector3(
                    x: (trace.finalPosition.x - position.x) / movedTime,
                    y: (trace.finalPosition.y - position.y) / movedTime,
                    z: (trace.finalPosition.z - position.z) / movedTime
                )
            }
            position = trace.finalPosition
            roomSourceIndex = trace.containingRoomSourceIndex

            let normalVelocity = dot(contact.normal, velocity)
            if surfacePhysicsBehavior(for: contact, in: level) == .forceField {
                velocity = velocity + contact.normal * (-4 * normalVelocity)
            } else {
                let speedBeforeResponse = sqrt(dot(velocity, velocity))
                let normalForce = dot(contact.normal, responseForce)
                responseForce = responseForce
                    + contact.normal * (-1.001 * normalForce)
                velocity = velocity
                    + contact.normal * (-1.001 * normalVelocity)
                if remainingDuration == priorRemainingDuration {
                    velocity = velocity + contact.normal
                }
                let projectedSpeed = sqrt(dot(velocity, velocity))
                if projectedSpeed > 0 {
                    velocity = velocity / projectedSpeed
                        * ((projectedSpeed + speedBeforeResponse) / 2)
                }
            }
            collisionCount += 1
        }
        if remainingDuration > 0 {
            velocity = .zero
        }
        let movedPlayerIndex = level.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        level.objects[movedPlayerIndex].position = position
        level.objects[movedPlayerIndex].location = .room(roomSourceIndex)
        guidebotEnteredShipThisFrame = advanceTrainingGuidebot(
            duration: systemsFrameDuration,
            player: level.objects[movedPlayerIndex],
            playerRadius: ship.presentationSize * 0.8
        )

        var trainingOpeningFeedback: [TrainingOpeningFeedback] = []
        var trainingLastRoomWasTriggeredThisFrame = false
        var trainingFinalBotsWasTriggeredThisFrame = false
        if trainingFinalGoalWasHitThisFrame,
           var state = trainingFinalGoalState,
           !state.endLevelWasRequested {
            // TrainingMission.cpp Script 057 calls aEndLevel before it
            // increments ScriptActionCtr_057.
            state.endLevelWasRequested = true
            state.scriptActionCounter += 1
            trainingFinalGoalState = state
            trainingPostLevelResult = makeTrainingPostLevelResult(
                elapsedTime: systemsGameTime
            )
            trainingSessionOutcome = .awaitingResultAcknowledgement
        }
        if trainingInvulnerabilityPickupWasHitThisFrame,
            var state = trainingInvulnerabilityPickupState,
            let chain = level.trainingInvulnerabilityPickupChain
        {
            if !state.scriptWasTriggered {
                state.scriptWasTriggered = true
            }
            if state.remainingDuration == nil {
                state.wasConsumed = true
                state.remainingDuration = chain.duration
                level.objects.removeAll {
                    $0.handle == chain.pickupObjectHandle
                }
                setObjectPresentationVisibility(
                    in: &level,
                    handle: chain.pickupObjectHandle,
                    isVisible: false
                )
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [chain.activatedMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName:
                            chain.activatedSoundSourceName
                    ))
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName: chain.pickupSoundSourceName
                    ))
            }
            trainingInvulnerabilityPickupState = state
        }
        if trainingCloakPickupWasHitThisFrame,
            var state = trainingCloakPickupState,
            let chain = level.trainingCloakPickupChain
        {
            if !state.scriptWasTriggered {
                state.scriptWasTriggered = true
            }
            if !state.wasConsumed {
                state.wasConsumed = true
                state.phase = .fadingOut
                state.phaseRemaining = chain.fadeDuration
                level.objects.removeAll {
                    $0.handle == chain.pickupObjectHandle
                }
                setObjectPresentationVisibility(
                    in: &level,
                    handle: chain.pickupObjectHandle,
                    isVisible: false
                )
                trainingOpeningFeedback.append(.init(
                    hudMessages: [chain.activatedMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: chain.activatedSoundSourceName
                ))
                trainingOpeningFeedback.append(.init(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: chain.pickupSoundSourceName
                ))
            }
            trainingCloakPickupState = state
        }
        if var state = trainingLastRoomState,
            !state.wasTriggered,
            trainingRASBot1DeathState?.wasDestroyed == true,
            trainingRASBot2DeathState?.wasDestroyed == true,
            trainingRASBot3DeathState?.wasDestroyed == true,
            trainingRASBot4DeathState?.wasDestroyed == true,
            trainingInvulnerabilityPickupState?.scriptWasTriggered == true,
            trainingCloakPickupState?.scriptWasTriggered == true,
            let chain = level.trainingLastRoomChain
        {
            state.wasTriggered = true
            state.markerLightDistance = chain.openMarkerLightDistance
            state.timerRemaining = chain.timerDuration
            trainingLastRoomState = state
            trainingLastRoomWasTriggeredThisFrame = true
            openTrainingLastRoomBarrier(in: &level)
        }
        if var state = trainingFinalBotsCompletionState,
            !state.wasTriggered,
            trainingLastBot1DeathState?.wasDestroyed == true,
            trainingLastBot2DeathState?.wasDestroyed == true,
            trainingLastBot3DeathState?.wasDestroyed == true,
            trainingLastBot4DeathState?.wasDestroyed == true,
            trainingLastBot5DeathState?.wasDestroyed == true,
            let chain = level.trainingFinalBotsCompletionChain
        {
            state.wasTriggered = true
            state.markerLightDistance =
                chain.openMarkerLightDistance
            state.timerRemaining = chain.timerDuration
            trainingFinalBotsCompletionState = state
            trainingFinalBotsWasTriggeredThisFrame = true
            openTrainingFinalBotsBarrier(in: &level)
        }
        if guidebotReturnWasRequestedThisFrame,
            let chain = level.trainingCameraMonitorChain?.returnToShip
        {
            trainingOpeningFeedback.append(
                .init(
                    hudMessages: [chain.returnMessage],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: chain.returnSoundSourceName
            ))
        }
        if guidebotEnteredShipThisFrame,
           let chain = level.trainingCameraMonitorChain?.returnToShip {
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.arrivalMessage],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ))
            if var cameraState = trainingCameraMonitorState,
               cameraState.wasUsed,
               !cameraState.script058WasPresented {
                cameraState.returnMarkerLightDistance =
                    chain.openMarkerLightDistance
                cameraState.script058WasPresented = true
                trainingCameraMonitorState = cameraState
                openTrainingGuidebotReturnBarrier(in: &level)
                trainingOpeningFeedback.append(.init(
                    hudMessages: [chain.successMessage],
                    voiceSourceName: chain.successVoiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
            }
            if var guidebotState = trainingRobotGuidebotState {
                guidebotState.arrivalFeedbackWasPresented = true
                trainingRobotGuidebotState = guidebotState
            }
        }
        if var state = trainingCameraMonitorState,
           !state.isHeld,
           !state.wasUsed,
           let chain = level.trainingCameraMonitorChain,
           trainingCameraMonitorWasHitThisFrame {
            state.isHeld = true
            trainingCameraMonitorState = state
            completeTrainingCameraMonitorLocateGoal(
                in: &level,
                pickupObjectHandle: chain.pickupObjectHandle
            )
            setObjectPresentationVisibility(
                in: &level,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.pickupMessage],
                voiceSourceName: chain.pickupVoiceSourceName,
                voicePrecedesHUDMessages: true,
                soundSourceName: chain.pickupSoundSourceName
            ))
        }
        if cameraMonitorWasUsedThisFrame,
           let chain = level.trainingCameraMonitorChain {
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.useMessage],
                voiceSourceName: chain.useVoiceSourceName,
                voicePrecedesHUDMessages: true
            ))
        }
        if var galleryState = trainingGalleryBarrierState,
           !galleryState.wasTriggered,
           trainingGalleryWasCrossedThisFrame,
           let barrier = level.trainingGalleryBarrier {
            trainingOpeningFeedback.append(.init(
                hudMessages: [
                    barrier.successMessage,
                    barrier.guidebotInstruction,
                ],
                voiceSourceName: barrier.voiceSourceName,
                voicePrecedesHUDMessages: true
            ))
            galleryState.markerLightDistance = 0
            closeTrainingGalleryBarrier(in: &level)
            galleryState.wasTriggered = true
            trainingGalleryBarrierState = galleryState
        }
        if var state = trainingKillbotEntryState,
           !state.wasTriggered,
           trainingKillbotEntryWasCrossedThisFrame,
           let returnChain =
                level.trainingCameraMonitorChain?.returnToShip,
           let chain = returnChain.killbotEntry {
            state.wasTriggered = true
            state.followupTimerRemaining = chain.followupDelay
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.entryMessage],
                voiceSourceName: chain.entryVoiceSourceName,
                voicePrecedesHUDMessages: false
            ))
            closeTrainingKillbotEntryBarrier(in: &level)
            trainingKillbotEntryState = state
        }
        if var state = trainingFinalRoomEntryState,
           !state.wasTriggered,
           trainingLastRoomState?.wasTriggered == true,
           trainingFinalRoomEntryWasCrossedThisFrame,
           let chain = level.trainingFinalRoomEntryChain
        {
            trainingLastRoomState?.markerLightDistance = 0
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.successMessage],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ))
            closeTrainingLastRoomBarrier(in: &level)
            trainingOpeningFeedback.append(.init(
                hudMessages: [chain.instructionMessage],
                voiceSourceName: chain.voiceSourceName,
                voicePrecedesHUDMessages: true
            ))
            state.wasTriggered = true
            trainingFinalRoomEntryState = state
        }
        if var state = trainingInvulnerabilityPickupState,
            var remaining = state.remainingDuration,
            let chain = level.trainingInvulnerabilityPickupChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                state.remainingDuration = nil
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [chain.expiredMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName: chain.expiredSoundSourceName
                    ))
            } else {
                state.remainingDuration = remaining
            }
            trainingInvulnerabilityPickupState = state
        }
        if var state = trainingCloakPickupState,
            let phase = state.phase,
            var remaining = state.phaseRemaining,
            let chain = level.trainingCloakPickupChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                switch phase {
                case .fadingOut:
                    state.phase = .cloaked
                    state.phaseRemaining = chain.cloakDuration
                case .cloaked:
                    state.phase = .fadingIn
                    state.phaseRemaining = chain.fadeDuration
                    trainingOpeningFeedback.append(.init(
                        hudMessages: [chain.expiredMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: true,
                        soundSourceName: chain.expiredSoundSourceName
                    ))
                case .fadingIn:
                    state.phase = nil
                    state.phaseRemaining = nil
                }
            } else {
                state.phaseRemaining = remaining
            }
            trainingCloakPickupState = state
        }
        if var state = trainingLastRoomState,
            !trainingLastRoomWasTriggeredThisFrame,
            var remaining = state.timerRemaining,
            let chain = level.trainingLastRoomChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                state.timerRemaining = nil
                if !state.wasPresented {
                    state.wasPresented = true
                    trainingOpeningFeedback.append(.init(
                        hudMessages: chain.completionMessages,
                        voiceSourceName:
                            chain.completionVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                }
            } else {
                state.timerRemaining = remaining
            }
            trainingLastRoomState = state
        }
        if var state = trainingFinalBotsCompletionState,
            !trainingFinalBotsWasTriggeredThisFrame,
            var remaining = state.timerRemaining,
            let chain = level.trainingFinalBotsCompletionChain
        {
            remaining -= systemsFrameDuration
            if remaining <= 0.000_001 {
                state.timerRemaining = nil
                if !state.wasPresented {
                    state.wasPresented = true
                    trainingOpeningFeedback.append(.init(
                        hudMessages: [chain.completionMessage],
                        voiceSourceName:
                            chain.completionVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                }
            } else {
                state.timerRemaining = remaining
            }
            trainingFinalBotsCompletionState = state
        }
        if var state = trainingRobotGuidebotState,
            let chain = level.trainingRobotGuidebotChain
        {
            if !state.guidebotContinuationWasPresented,
               state.guidebotIsDeployed,
                trainingGalleryBarrierState?.wasTriggered == true
            {
                trainingOpeningFeedback.append(
                    .init(
                        hudMessages: [chain.deployedGuidebotMessage],
                    voiceSourceName:
                        chain.deployedGuidebotVoiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
                state.guidebotContinuationWasPresented = true
                state.controlsWereRestored = true
            }
            if var timer = state.destructionTimerRemaining,
               !state.destructionFeedbackWasPresented {
                timer -= systemsFrameDuration
                if timer <= 0.000_001 {
                    trainingOpeningFeedback.append(.init(
                        hudMessages: [
                            chain.destructionMessage,
                            chain.exitInstruction,
                        ],
                        voiceSourceName:
                            chain.destructionVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                    state.destructionFeedbackWasPresented = true
                    state.enabledControlHUDIsVisible = false
                    state.destructionTimerRemaining = nil
                } else {
                    state.destructionTimerRemaining = timer
                }
            }
            trainingRobotGuidebotState = state
        }
        if var openingState = trainingOpeningState,
           let lesson = level.trainingOpeningLesson {
            if !openingState.forwardGoalWasReached,
               trainingForwardGoalWasReachedThisFrame {
                openingState.forwardGoalWasReached = true
                openingState.enabledControls.remove(.forward)
                openingState.enabledControls.insert(.reverse)
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [lesson.successMessage],
                        voiceSourceName: lesson.successVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [lesson.reverseInstruction],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                ])
            }
            if openingState.repeatForwardWasPresented == true,
               openingState.repeatForwardGoalWasPresented != true,
               trainingForwardGoalWasReachedThisFrame,
               let repeatForwardGoal = lesson.repeatForwardGoal {
                openingState.enabledControls.remove(.forward)
                openingState.enabledControls.insert(.reverse)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [repeatForwardGoal.reverseInstruction],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: repeatForwardGoal.soundLogicalName
                ))
                openingState.repeatForwardGoalWasPresented = true
            }
            if openingState.forwardGoalWasReached,
               openingState.returnGoalWasReached != true,
               trainingReturnGoalWasReachedThisFrame,
               let returnLeft = lesson.returnLeft {
                openingState.enabledControls.remove(.reverse)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [returnLeft.instruction],
                    voiceSourceName: returnLeft.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ))
                openingState.enabledControls.insert(.left)
                openingState.returnGoalWasReached = true
            }
            if openingState.rightGoalWasReached != true,
               trainingRightGoalWasReachedThisFrame,
               let returnRight = lesson.returnRight {
                openingState.enabledControls.remove(.left)
                openingState.enabledControls.insert(.right)
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [returnRight.successMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [returnRight.instruction],
                        voiceSourceName: returnRight.voiceSourceName,
                        voicePrecedesHUDMessages: true
                    ),
                ])
                openingState.rightGoalWasReached = true
            }
            if openingState.rightGoalWasReached == true,
               openingState.upGoalWasReached != true,
               trainingUpGoalWasReachedThisFrame,
               let returnUp = lesson.returnUp {
                openingState.enabledControls.remove(.right)
                openingState.enabledControls.insert(.up)
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [returnUp.successMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [returnUp.instruction],
                        voiceSourceName: returnUp.voiceSourceName,
                        voicePrecedesHUDMessages: true
                    ),
                ])
                openingState.upGoalWasReached = true
            }
            if openingState.downGoalWasReached != true,
               trainingDownGoalWasReachedThisFrame,
               let returnDown = lesson.returnDown {
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [returnDown.successMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ))
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [returnDown.instruction],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ))
                openingState.enabledControls.remove(.up)
                trainingOpeningFeedback.append(TrainingOpeningFeedback(
                    hudMessages: [],
                    voiceSourceName: returnDown.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ))
                openingState.enabledControls.insert(.down)
                openingState.downGoalWasReached = true
            }
            if openingState.downGoalWasReached == true,
               openingState.repeatForwardWasPresented != true,
               trainingRepeatForwardWasReachedThisFrame,
               let repeatForward = lesson.repeatForward {
                trainingOpeningFeedback.append(contentsOf: [
                    TrainingOpeningFeedback(
                        hudMessages: [repeatForward.successMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [repeatForward.repeatMessage],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [repeatForward.forwardInstruction],
                        voiceSourceName: "",
                        voicePrecedesHUDMessages: false
                    ),
                    TrainingOpeningFeedback(
                        hudMessages: [],
                        voiceSourceName: repeatForward.voiceSourceName,
                        voicePrecedesHUDMessages: false
                    ),
                ])
                openingState.enabledControls.remove(.down)
                openingState.enabledControls.insert(.forward)
                openingState.repeatForwardWasPresented = true
            }
            if !openingState.welcomeWasPresented {
                openingState.timerRemaining -= systemsFrameDuration
                if openingState.timerRemaining <= 0.000_001 {
                    openingState.welcomeWasPresented = true
                    trainingOpeningFeedback.append(TrainingOpeningFeedback(
                        hudMessages: [
                            lesson.welcomeMessage,
                            lesson.forwardInstruction,
                        ],
                        voiceSourceName: lesson.welcomeVoiceSourceName,
                        voicePrecedesHUDMessages: false
                    ))
                }
            }
            trainingOpeningState = openingState
        }
        if var state = trainingKillbotEntryState,
           state.wasTriggered,
           !state.followupWasPresented,
           !trainingKillbotEntryWasCrossedThisFrame,
           let chain = level.trainingCameraMonitorChain?.returnToShip?
                .killbotEntry,
           var timer = state.followupTimerRemaining {
            timer -= systemsFrameDuration
            if timer <= 0.000_001 {
                state.followupTimerRemaining = nil
                state.followupWasPresented = true
                trainingOpeningFeedback.append(.init(
                    hudMessages: [chain.followupMessage],
                    voiceSourceName: chain.followupVoiceSourceName,
                    voicePrecedesHUDMessages: true
                ))
            } else {
                state.followupTimerRemaining = timer
            }
            trainingKillbotEntryState = state
        }

        if afterburnerIsActive {
            afterburnerMagnitude += 2 * systemsFrameDuration
        } else {
            afterburnerMagnitude -= 2 * systemsFrameDuration
        }
        afterburnerMagnitude = max(0, min(1, afterburnerMagnitude))
        let projection = PerspectiveProjection(
            horizontalFieldOfViewRadians:
                PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
                * (1 + afterburnerMagnitude * 0.08),
            aspectRatio: PerspectiveProjection.sourceDefault.aspectRatio
        )

        let cameraMonitorFrame = trainingCameraMonitorFrame(
            level: level,
            state: trainingCameraMonitorState
        )
        let finalGoalFrame: TrainingFinalGoalFrame? =
            trainingFinalGoalState.flatMap { state in
            guard state.endLevelWasRequested,
                  let postLevelResult = trainingPostLevelResult else {
                return nil
            }
            return TrainingFinalGoalFrame(
                endLevelState: .succeeded,
                scriptActionCounter: state.scriptActionCounter,
                controlsAreSuspended: true,
                presentation: .init(
                    title: "Mission Successful",
                    levelName: level.metadata.name,
                    difficulty: .rookie,
                    showsHUD: false,
                    playsGameplayAudio: false,
                    showsCockpit: false,
                    showsHeadlightIndicator: false
                ),
                postLevelResult: postLevelResult
            )
        }
        if var state = trainingCameraMonitorState {
            if var remaining = state.popupRemaining {
                remaining -= systemsFrameDuration
                state.popupRemaining = remaining < 0 ? nil : remaining
            }
            if var timer = state.completionTimerRemaining {
                timer -= systemsFrameDuration
                if timer <= 0.000_001 {
                    state.completionTimerRemaining = nil
                    state.completionTimerWasConsumed = true
                } else {
                    state.completionTimerRemaining = timer
                }
            }
            trainingCameraMonitorState = state
        }

        frameDuration = Float(timestamp - lastTimestamp)
        lastTimestamp = timestamp
        gameTime += frameDuration

        return PlayerSimulationFrame(
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            storedFrameDuration: frameDuration,
            gameTime: gameTime,
            playerView: defaultPlayerView(in: level, projection: projection),
            velocity: velocity,
            angularVelocity: angularVelocity,
            turnrollFixedAngle: turnrollFixedAngle,
            wallContact: wallContact,
            enabledPlayerControls:
                finalGoalFrame == nil
                    ? trainingPlayerControlMask(
                        galleryWasTriggered:
                            trainingGalleryBarrierState?
                                .wasTriggered == true,
                        controlsWereRestored:
                            trainingRobotGuidebotState?
                                .controlsWereRestored == true,
                        openingControls:
                            trainingOpeningState?.enabledControls
                    )
                    : PlayerControlMask(rawValue: 0),
            showsEnabledPlayerControls:
                finalGoalFrame == nil
                    && (
                        trainingRobotGuidebotState?
                            .enabledControlHUDIsVisible
                            ?? (trainingOpeningState != nil)
                    ),
            trainingOpeningFeedback: trainingOpeningFeedback,
            trainingGalleryMarkerLightDistance:
                trainingGalleryBarrierState?.markerLightDistance,
            trainingGuidebotReturnMarkerLightDistance:
                trainingKillbotEntryState?.wasTriggered == true
                    ? level.trainingCameraMonitorChain?.returnToShip?
                        .killbotEntry?.closedMarkerLightDistance
                    : trainingCameraMonitorState?
                        .returnMarkerLightDistance,
            trainingGuidebot:
                trainingRobotGuidebotState?.guidebot?.frame,
            trainingCameraMonitor: cameraMonitorFrame,
            trainingInvulnerabilityRemaining:
                trainingInvulnerabilityPickupState?.remainingDuration,
            trainingCloak: trainingCloakFrame(
                state: trainingCloakPickupState,
                chain: level.trainingCloakPickupChain
            ),
            trainingLastRoomMarkerLightDistance:
                trainingLastRoomState?.markerLightDistance,
            trainingFinalBotsMarkerLightDistance:
                trainingFinalBotsCompletionState?
                    .markerLightDistance,
            trainingFinalGoal: finalGoalFrame
        )
    }

    func acknowledgeTrainingResult() -> TrainingSessionOutcome? {
        guard trainingPostLevelResult != nil else { return nil }
        trainingSessionOutcome = .completed
        return trainingSessionOutcome
    }

    private func makeTrainingPostLevelResult(
        elapsedTime: Float
    ) -> TrainingPostLevelResult {
        let enemyKills = [
            trainingRobotGuidebotState?.robotWasDestroyed == true,
            trainingRASBot1DeathState?.wasDestroyed == true,
            trainingRASBot2DeathState?.wasDestroyed == true,
            trainingRASBot3DeathState?.wasDestroyed == true,
            trainingRASBot4DeathState?.wasDestroyed == true,
            trainingLastBot1DeathState?.wasDestroyed == true,
            trainingLastBot2DeathState?.wasDestroyed == true,
            trainingLastBot3DeathState?.wasDestroyed == true,
            trainingLastBot4DeathState?.wasDestroyed == true,
            trainingLastBot5DeathState?.wasDestroyed == true,
        ].count(where: { $0 })
        return TrainingPostLevelResult(
            title: "Mission Successful",
            levelName: level.metadata.name,
            difficulty: .rookie,
            score:
                enemyKills
                * TrainingRobotCombatDefinition.stockTrainingScore,
            elapsedTime: elapsedTime,
            enemyKills: enemyKills,
            // Player damage, death, and restore ownership are later Phase 5
            // islands. The current normal Training path retains its source
            // initial ratings and has no admitted death or restore transition.
            shields: 100,
            energy: energy,
            deaths: 0,
            restores: 0,
            // Training's two camera goals do not carry LGF_TELCOM_LISTS, so
            // SinglePlayerPostLevelResults presents no objective rows.
            objectives: []
        )
    }

    func stopTime(at timestamp: Double) {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        if pauseDepth == 0 {
            pauseTimestamp = timestamp
        }
        pauseDepth += 1
    }

    func setIndoorAutoLevelMode(_ mode: IndoorAutoLevelMode) {
        indoorAutoLevelMode = mode
    }

    func startTime(at timestamp: Double) {
        precondition(timestamp.isFinite)
        guard pauseDepth > 0 else { return }
        pauseDepth -= 1
        if pauseDepth == 0 {
            let pausedAt = pauseTimestamp!
            precondition(timestamp >= pausedAt)
            lastTimestamp += timestamp - pausedAt
            pauseTimestamp = nil
        }
    }
}

private func trainingGalleryTriggerWasCrossed(
    in level: Level,
    passedPortalFaces: [IndoorPortalCrossing]
) -> Bool {
    guard let barrier = level.trainingGalleryBarrier else {
        return false
    }
    return passedPortalFaces.contains {
        $0.roomSourceIndex == barrier.triggerRoomSourceIndex
            && $0.faceIndex == barrier.triggerFaceIndex
    }
}

private func trainingKillbotEntryTriggerWasCrossed(
    in level: Level,
    passedPortalFaces: [IndoorPortalCrossing]
) -> Bool {
    guard let entry =
            level.trainingCameraMonitorChain?.returnToShip?.killbotEntry
    else {
        return false
    }
    return passedPortalFaces.contains {
        $0.roomSourceIndex == entry.triggerRoomSourceIndex
            && $0.faceIndex == entry.triggerFaceIndex
    }
}

private func trainingFinalRoomEntryTriggerWasCrossed(
    in level: Level,
    passedPortalFaces: [IndoorPortalCrossing]
) -> Bool {
    guard let chain = level.trainingFinalRoomEntryChain else {
        return false
    }
    return passedPortalFaces.contains {
        $0.roomSourceIndex == chain.triggerRoomSourceIndex
            && $0.faceIndex == chain.triggerFaceIndex
    }
}

private func segmentSphereHitFraction(
    start: Vector3,
    end: Vector3,
    center: Vector3,
    radius: Float
) -> Float? {
    let movement = end - start
    let offset = start - center
    let a = dot(movement, movement)
    guard a > 0 else {
        return dot(offset, offset) <= radius * radius ? 0 : nil
    }
    let b = 2 * dot(offset, movement)
    let c = dot(offset, offset) - radius * radius
    if c <= 0 { return 0 }
    let discriminant = b * b - 4 * a * c
    guard discriminant >= 0 else { return nil }
    let root = sqrt(discriminant)
    let first = (-b - root) / (2 * a)
    let second = (-b + root) / (2 * a)
    if (0...1).contains(first) { return first }
    if (0...1).contains(second) { return second }
    return nil
}

private func trainingCameraMonitorPickupWasHit(
    in level: Level,
    state: TrainingCameraMonitorState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
          !state.isHeld,
          !state.wasUsed,
          let chain = level.trainingCameraMonitorChain,
          let pickup = level.objects.first(where: {
              $0.handle == chain.pickupObjectHandle
          }),
          case let .room(pickupRoomSourceIndex) = pickup.location,
          visitedRoomSourceIndices.contains(pickupRoomSourceIndex) else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: pickup.position,
        radius: playerRadius + chain.pickupCollisionRadius
    ) != nil
}

private func trainingInvulnerabilityPickupWasHit(
    in level: Level,
    state: TrainingInvulnerabilityPickupState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
        !state.wasConsumed,
        let chain = level.trainingInvulnerabilityPickupChain,
        let pickup = level.objects.first(where: {
            $0.handle == chain.pickupObjectHandle
        }),
        pickup.location == .room(chain.pickupRoomSourceIndex),
        visitedRoomSourceIndices.contains(
            chain.pickupRoomSourceIndex
        )
    else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: pickup.position,
        radius: playerRadius + chain.pickupCollisionRadius
    ) != nil
}

private func trainingCloakPickupWasHit(
    in level: Level,
    state: TrainingCloakPickupState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
        !state.wasConsumed,
        let chain = level.trainingCloakPickupChain,
        let pickup = level.objects.first(where: {
            $0.handle == chain.pickupObjectHandle
        }),
        pickup.location == .room(chain.pickupRoomSourceIndex),
        visitedRoomSourceIndices.contains(chain.pickupRoomSourceIndex)
    else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: pickup.position,
        radius: playerRadius + chain.pickupCollisionRadius
    ) != nil
}

private func trainingFinalGoalWasHit(
    in level: Level,
    state: TrainingFinalGoalState?,
    finalBotsState: TrainingFinalBotsCompletionState?,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard let state,
          !state.endLevelWasRequested,
          finalBotsState?.wasTriggered == true,
          let chain = level.trainingFinalGoalChain,
          let goal = level.objects.first(where: {
              $0.handle == chain.goalObjectHandle
          }),
          goal.location == .room(chain.goalRoomSourceIndex),
          visitedRoomSourceIndices.contains(
              chain.goalRoomSourceIndex
          )
    else {
        return false
    }
    return segmentSphereHitFraction(
        start: playerStart,
        end: playerEnd,
        center: goal.position,
        radius: playerRadius + chain.goalCollisionRadius
    ) != nil
}

private func trainingCloakFrame(
    state: TrainingCloakPickupState?,
    chain: TrainingCloakPickupChain?
) -> TrainingCloakFrame? {
    guard let phase = state?.phase,
        let remaining = state?.phaseRemaining,
        let chain
    else {
        return nil
    }
    return .init(
        phase: phase,
        phaseRemaining: remaining,
        phaseDuration:
            phase == .cloaked ? chain.cloakDuration : chain.fadeDuration
    )
}

private func trainingGalleryBarrierRendersFaces(
    in level: Level,
    barrier: TrainingGalleryBarrier
) -> Bool {
    let room = level.rooms.first {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    return barrier.orderedPortalIndices.allSatisfy {
        room.portals[$0].flags & 1 != 0
    }
}

private func validTrainingGalleryBarrierContinuation(
    _ state: TrainingGalleryBarrierState?,
    robotGuidebotState: TrainingRobotGuidebotState?,
    level: Level
) -> Bool {
    guard let barrier = level.trainingGalleryBarrier else {
        return state == nil
    }
    guard let state,
          state.markerLightDistance.isFinite else {
        return false
    }
    let expectedDistance =
        robotGuidebotState?.robotWasDestroyed == true
            ? barrier.openMarkerLightDistance
            : state.wasTriggered
            || trainingGalleryBarrierRendersFaces(
                in: level,
                barrier: barrier
            )
        ? 0
        : barrier.openMarkerLightDistance
    return state.markerLightDistance == expectedDistance
}

private func validTrainingRobotGuidebotContinuation(
    _ state: TrainingRobotGuidebotState?,
    galleryState: TrainingGalleryBarrierState?,
    cameraState: TrainingCameraMonitorState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRobotGuidebotChain else {
        return state == nil
    }
    let roomSourceIndices = Set(level.rooms.map(\.sourceIndex))
    guard let state,
          state.robotShields.isFinite,
          state.robotShields <= chain.combat.robotShields,
          state.nextPrimaryFireTime.isFinite,
          state.nextPrimaryFireTime >= 0,
          state.projectiles.allSatisfy({
              roomSourceIndices.contains($0.roomSourceIndex)
                  && $0.position.x.isFinite
                  && $0.position.y.isFinite
                  && $0.position.z.isFinite
                  && containingIndoorRoomSourceIndex(
                      in: level,
                      position: $0.position,
                      candidates: [$0.roomSourceIndex]
                  ) == $0.roomSourceIndex
                  && $0.velocity.x.isFinite
                  && $0.velocity.y.isFinite
                  && $0.velocity.z.isFinite
                  && $0.lifeRemaining.isFinite
                  && $0.lifeRemaining > 0
                  && $0.lifeRemaining <= chain.combat.projectileLifetime
          }),
          state.guidebotIsDeployed == (state.guidebot != nil),
          state.guidebot.map({
              roomSourceIndices.contains($0.roomSourceIndex)
                  && isCanonicalRigidTransform(
                      position: $0.spawnPosition,
                      orientation: $0.orientation
                  )
                  && $0.allocationStartPosition.x.isFinite
                  && $0.allocationStartPosition.y.isFinite
                  && $0.allocationStartPosition.z.isFinite
                  && $0.allocationStartForward.x.isFinite
                  && $0.allocationStartForward.y.isFinite
                  && $0.allocationStartForward.z.isFinite
                  && abs(
                      dot(
                          $0.allocationStartForward,
                          $0.allocationStartForward
                      ) - 1
                  ) < 0.000_1
                  && $0.spawnVelocity.x.isFinite
                  && $0.spawnVelocity.y.isFinite
                  && $0.spawnVelocity.z.isFinite
                  && $0.position.x.isFinite
                  && $0.position.y.isFinite
                  && $0.position.z.isFinite
                  && containingIndoorRoomSourceIndex(
                      in: level,
                      position: $0.position,
                      candidates: [$0.roomSourceIndex]
                  ) == $0.roomSourceIndex
                  && $0.velocity.x.isFinite
                  && $0.velocity.y.isFinite
                  && $0.velocity.z.isFinite
                  && $0.destination.x.isFinite
                  && $0.destination.y.isFinite
                  && $0.destination.z.isFinite
                  && $0.routeDestination.x.isFinite
                  && $0.routeDestination.y.isFinite
                  && $0.routeDestination.z.isFinite
                  && roomSourceIndices.contains(
                      $0.routeDestinationRoomSourceIndex
                  )
                  && !$0.route.points.isEmpty
                  && $0.route.points.allSatisfy {
                      $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
                  }
                  && !$0.route.roomSourceIndices.isEmpty
                  && $0.route.roomSourceIndices.allSatisfy(
                      roomSourceIndices.contains
                  )
                  && $0.route.points.indices.contains($0.routePointIndex)
                  && validTrainingGuidebotSteeringState($0)
                  && validTrainingGuidebotRoute(
                      guidebot: $0,
                      level: level,
                      collisionRadius: chain.guidebot.collisionRadius
                  )
          }) ?? true,
          state.controlsWereRestored
            == (state.robotWasDestroyed
                || state.guidebotContinuationWasPresented),
          state.enabledControlHUDIsVisible
            != state.destructionFeedbackWasPresented
    else {
        return false
    }
    if state.guidebotContinuationWasPresented
        && (
            (!state.guidebotIsDeployed && !state.guidebotEnteredShip)
                || galleryState?.wasTriggered != true
        ) {
        return false
    }
    if state.returnWasRequested {
        guard cameraState?.wasUsed == true,
              state.guidebotEnteredShip
                || state.guidebot?.task == .returnToShip
        else {
            return false
        }
    } else if state.guidebotEnteredShip
                || state.arrivalFeedbackWasPresented
                || state.guidebot?.task == .returnToShip {
        return false
    }
    if state.guidebotEnteredShip {
        guard !state.guidebotIsDeployed,
              state.guidebot == nil,
              state.arrivalFeedbackWasPresented,
              cameraState?.script058WasPresented == true else {
            return false
        }
    } else if cameraState?.script058WasPresented == true {
        return false
    }
    if state.robotWasDestroyed {
        guard state.robotShields < 0,
              state.destructionFeedbackWasPresented
                == (state.destructionTimerRemaining == nil)
        else {
            return false
        }
        if let timer = state.destructionTimerRemaining {
            return timer.isFinite && timer > 0
                && timer <= chain.destructionDelay
        }
    } else if state.destructionTimerRemaining != nil
                || state.destructionFeedbackWasPresented
                || state.robotShields < 0 {
        return false
    }
    return true
}

private func validTrainingCameraMonitorContinuation(
    _ state: TrainingCameraMonitorState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingCameraMonitorChain else {
        return state == nil
    }
    guard let state,
          !(state.isHeld && state.wasUsed),
          state.popupRemaining.map({
              $0.isFinite && $0 >= 0 && $0 <= chain.popupDuration
          }) ?? true,
          state.completionTimerRemaining.map({
              $0.isFinite
                  && $0 > 0
                  && $0 <= chain.completionTimerDuration
          }) ?? true,
          state.returnMarkerLightDistance.isFinite,
          state.returnMarkerLightDistance >= 0 else {
        return false
    }
    if let returnChain = chain.returnToShip {
        guard state.script058WasPresented
                ? state.returnMarkerLightDistance
                    == returnChain.openMarkerLightDistance
                : state.returnMarkerLightDistance == 0
        else {
            return false
        }
    } else if state.script058WasPresented
                || state.returnMarkerLightDistance != 0 {
        return false
    }
    if state.wasUsed {
        return !state.isHeld
            && !level.objects.contains {
                $0.handle == chain.pickupObjectHandle
            }
            && (
                state.completionTimerRemaining != nil
                    || state.completionTimerWasConsumed
            )
    }
    return state.popupRemaining == nil
        && state.completionTimerRemaining == nil
        && !state.completionTimerWasConsumed
        && level.objects.contains {
            $0.handle == chain.pickupObjectHandle
        }
}

private func validTrainingKillbotEntryContinuation(
    _ state: TrainingKillbotEntryState?,
    level: Level
) -> Bool {
    guard let chain =
            level.trainingCameraMonitorChain?.returnToShip?.killbotEntry
    else {
        return state == nil
    }
    guard let state else { return false }
    if state.wasTriggered {
        guard trainingKillbotEntryBarrierRendersFaces(in: level),
              state.followupWasPresented
                == (state.followupTimerRemaining == nil) else {
            return false
        }
        return state.followupTimerRemaining.map {
            $0.isFinite && $0 > 0 && $0 <= chain.followupDelay
        } ?? true
    }
    return state.followupTimerRemaining == nil
        && !state.followupWasPresented
}

private func validTrainingRASBot1DeathContinuation(
    _ state: TrainingRASBot1DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot1DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingRASBot2DeathContinuation(
    _ state: TrainingRASBot2DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot2DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingRASBot3DeathContinuation(
    _ state: TrainingRASBot3DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot3DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingRASBot4DeathContinuation(
    _ state: TrainingRASBot4DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingRASBot4DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot1DeathContinuation(
    _ state: TrainingLastBot1DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot1DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot2DeathContinuation(
    _ state: TrainingLastBot2DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot2DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot3DeathContinuation(
    _ state: TrainingLastBot3DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot3DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot4DeathContinuation(
    _ state: TrainingLastBot4DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot4DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingLastBot5DeathContinuation(
    _ state: TrainingLastBot5DeathState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastBot5DeathChain else {
        return state == nil
    }
    guard let state,
          state.shields.isFinite,
          state.shields <= chain.combat.robotShields else {
        return false
    }
    let robotIsPresent = level.objects.contains {
        $0.handle == chain.robotObjectHandle
    }
    return state.wasDestroyed
        ? state.shields < 0 && !robotIsPresent
        : state.shields >= 0 && robotIsPresent
}

private func validTrainingInvulnerabilityPickupContinuation(
    _ state: TrainingInvulnerabilityPickupState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingInvulnerabilityPickupChain else {
        return state == nil
    }
    guard let state,
        state.remainingDuration.map({
            $0.isFinite && $0 > 0 && $0 <= chain.duration
        }) ?? true,
        !state.wasConsumed || state.scriptWasTriggered,
        state.remainingDuration == nil || state.wasConsumed
    else {
        return false
    }
    let pickupIsPresent = level.objects.contains {
        $0.handle == chain.pickupObjectHandle
    }
    if state.wasConsumed {
        return !pickupIsPresent
    }
    return pickupIsPresent
        && state.remainingDuration == nil
}

private func validTrainingCloakPickupContinuation(
    _ state: TrainingCloakPickupState?,
    level: Level
) -> Bool {
    guard let chain = level.trainingCloakPickupChain else {
        return state == nil
    }
    guard let state,
        !state.wasConsumed || state.scriptWasTriggered,
        (state.phase == nil) == (state.phaseRemaining == nil),
        state.phaseRemaining.map({
            $0.isFinite && $0 > 0
                && $0 <= (
                    state.phase == .cloaked
                        ? chain.cloakDuration
                        : chain.fadeDuration
                )
        }) ?? true,
        state.phase == nil || state.wasConsumed
    else {
        return false
    }
    let pickupIsPresent = level.objects.contains {
        $0.handle == chain.pickupObjectHandle
    }
    return state.wasConsumed ? !pickupIsPresent : pickupIsPresent
}

private func validTrainingLastRoomContinuation(
    _ state: TrainingLastRoomState?,
    finalRoomEntryWasTriggered: Bool,
    allProducersWereTriggered: Bool,
    level: Level
) -> Bool {
    guard let chain = level.trainingLastRoomChain else {
        return state == nil
    }
    guard let state,
        state.markerLightDistance.isFinite,
        state.timerRemaining.map({
            $0.isFinite && $0 > 0 && $0 <= chain.timerDuration
        }) ?? true
    else {
        return false
    }
    if !state.wasTriggered {
        return state.markerLightDistance == 0
            && state.timerRemaining == nil
            && !state.wasPresented
    }
    guard allProducersWereTriggered else { return false }
    let room = level.rooms.first {
        $0.sourceIndex == chain.barrierRoomSourceIndex
    }!
    let expectedMarkerDistance: Float =
        finalRoomEntryWasTriggered ? 0 : chain.openMarkerLightDistance
    let expectedPortalFlag: UInt32 =
        finalRoomEntryWasTriggered ? 1 : 0
    return state.markerLightDistance == expectedMarkerDistance
        && chain.orderedPortalIndices.allSatisfy {
            room.portals[$0].flags & 1 == expectedPortalFlag
        }
        && (state.wasPresented
            ? state.timerRemaining == nil
            : state.timerRemaining != nil)
}

private func validTrainingFinalBotsCompletionContinuation(
    _ state: TrainingFinalBotsCompletionState?,
    allProducersWereDestroyed: Bool,
    level: Level
) -> Bool {
    guard let chain = level.trainingFinalBotsCompletionChain else {
        return state == nil
    }
    guard let state,
          state.markerLightDistance.isFinite,
          state.timerRemaining.map({
              $0.isFinite && $0 > 0
                  && $0 <= chain.timerDuration
          }) ?? true
    else {
        return false
    }
    if !state.wasTriggered {
        return state.markerLightDistance == 0
            && state.timerRemaining == nil
            && !state.wasPresented
    }
    guard allProducersWereDestroyed,
          state.markerLightDistance
            == chain.openMarkerLightDistance,
          let room = level.rooms.first(where: {
              $0.sourceIndex == chain.barrierRoomSourceIndex
          }),
          chain.orderedPortalIndices.allSatisfy({
              let portal = room.portals[$0]
              guard portal.flags & 1 == 0,
                    let connected = level.rooms.first(where: {
                        $0.sourceIndex == portal.connectedRoom
                    })
              else {
                  return false
              }
              return connected.portals[portal.connectedPortal].flags
                  & 1 == 0
          })
    else {
        return false
    }
    return state.wasPresented
        ? state.timerRemaining == nil
        : state.timerRemaining != nil
}

private func validTrainingFinalGoalContinuation(
    _ state: TrainingFinalGoalState?,
    finalBotsState: TrainingFinalBotsCompletionState?,
    level: Level
) -> Bool {
    guard level.trainingFinalGoalChain != nil else {
        return state == nil
    }
    guard let state else { return false }
    if state.endLevelWasRequested {
        return state.scriptActionCounter == 1
            && finalBotsState?.wasTriggered == true
    }
    return state.scriptActionCounter == 0
}

private func validTrainingFinalRoomEntryContinuation(
    _ state: TrainingFinalRoomEntryState?,
    lastRoomState: TrainingLastRoomState?,
    level: Level
) -> Bool {
    guard level.trainingFinalRoomEntryChain != nil else {
        return state == nil
    }
    guard let state else { return false }
    if !state.wasTriggered {
        return true
    }
    guard lastRoomState?.wasTriggered == true,
        lastRoomState?.markerLightDistance == 0,
        let lastRoom = level.trainingLastRoomChain,
        let room = level.rooms.first(where: {
            $0.sourceIndex == lastRoom.barrierRoomSourceIndex
        })
    else {
        return false
    }
    return lastRoom.orderedPortalIndices.allSatisfy { portalIndex in
        let portal = room.portals[portalIndex]
        guard portal.flags & 1 != 0,
            let connectedRoom = level.rooms.first(where: {
                $0.sourceIndex == portal.connectedRoom
            }),
            connectedRoom.portals.indices.contains(
                portal.connectedPortal
            )
        else {
            return false
        }
        return connectedRoom.portals[portal.connectedPortal].flags & 1
            != 0
    }
}

private func setObjectPresentationVisibility(
    in level: inout Level,
    handle: UInt32,
    isVisible: Bool
) {
    guard let index = level.objectPresentations.firstIndex(where: {
        $0.objectHandle == handle
    }) else {
        return
    }
    let presentation = level.objectPresentations[index]
    level.objectPresentations[index] = .init(
        objectHandle: presentation.objectHandle,
        primaryModel: presentation.primaryModel,
        mediumModel: presentation.mediumModel,
        lowModel: presentation.lowModel,
        dyingModel: presentation.dyingModel,
        mediumDistance: presentation.mediumDistance,
        lowDistance: presentation.lowDistance,
        isVisible: isVisible
    )
}

private func completeTrainingCameraMonitorLocateGoal(
    in level: inout Level,
    pickupObjectHandle: UInt32
) {
    guard let goalIndex = level.goals.firstIndex(where: { goal in
        goal.status & 0x0000_0400 != 0
            && goal.items.contains {
                $0.type == 2
                    && $0.objectHandle == pickupObjectHandle
            }
    }) else {
        return
    }
    let goal = level.goals[goalIndex]
    level.goals[goalIndex] = .init(
        status: goal.status | 0x0000_0008,
        priority: goal.priority,
        list: goal.list,
        name: goal.name,
        itemName: goal.itemName,
        description: goal.description,
        completionMessage: goal.completionMessage,
        items: goal.items.map { item in
            guard item.type == 2,
                  item.objectHandle == pickupObjectHandle else {
                return item
            }
            return .init(
                type: item.type,
                sourceHandle: item.sourceHandle,
                objectHandle: item.objectHandle,
                done: true
            )
        }
    )
}

private func trainingCameraMonitorFrame(
    level: Level,
    state: TrainingCameraMonitorState?
) -> TrainingCameraMonitorFrame? {
    guard let chain = level.trainingCameraMonitorChain,
          let remainingDuration = state?.popupRemaining,
          let cameraObject = level.objects.first(where: {
              $0.handle == chain.securityCameraObjectHandle
          }),
          case let .room(roomSourceIndex) = cameraObject.location else {
        return nil
    }
    let localPosition = chain.cameraLocalPosition
    let position = cameraObject.position
        + cameraObject.orientation.right * localPosition.x
        + cameraObject.orientation.up * localPosition.y
        + cameraObject.orientation.forward * localPosition.z
    let gunpointRoomSourceIndex = traceIndoorMovement(
        in: level,
        startRoom: roomSourceIndex,
        start: cameraObject.position,
        end: position,
        radius: 0
    ).containingRoomSourceIndex
    let localForward = chain.cameraLocalForward
    let forward = normalized(
        cameraObject.orientation.right * localForward.x
            + cameraObject.orientation.up * localForward.y
            + cameraObject.orientation.forward * localForward.z
    )
    let up: Vector3
    if forward.x == 0 && forward.z == 0 {
        up = .init(x: 0, y: 0, z: forward.y < 0 ? 1 : -1)
    } else {
        let right = normalized(.init(
            x: forward.z,
            y: 0,
            z: -forward.x
        ))
        up = cross(forward, right)
    }
    return .init(
        camera: .init(
            position: position,
            target: position + forward,
            up: up,
            projection: .sourceDefault
        ),
        roomSourceIndex: gunpointRoomSourceIndex,
        remainingDuration: remainingDuration
    )
}

private func validTrainingGuidebotSteeringState(
    _ guidebot: TrainingGuidebotRuntimeState
) -> Bool {
    switch guidebot.activeSteeringMode {
    case .direct:
        return guidebot.route.mode == .direct
    case .allocatedRoute:
        return guidebot.routeFailure == nil
            && guidebot.route.mode != .direct
    case .stopped:
        return guidebot.routePointIndex
            == guidebot.route.points.count - 1
    }
}

private func validTrainingGuidebotRoute(
    guidebot: TrainingGuidebotRuntimeState,
    level: Level,
    collisionRadius: Float
) -> Bool {
    guard let startRoomSourceIndex =
            guidebot.route.roomSourceIndices.first
    else {
        return false
    }
    let expected = trainingGuidebotRoute(
        in: level,
        startRoomSourceIndex: startRoomSourceIndex,
        start: guidebot.allocationStartPosition,
        startForward: guidebot.allocationStartForward,
        destinationRoomSourceIndex:
            guidebot.routeDestinationRoomSourceIndex,
        destination: guidebot.routeDestination,
        radius: max(0, collisionRadius - 0.1)
    )
    switch expected {
    case .success(let route):
        return guidebot.routeFailure == nil
            && guidebot.route == route
    case .failure(let failure):
        return guidebot.routeFailure == failure
            && guidebot.route.mode == .direct
            && guidebot.route.points == [guidebot.routeDestination]
            && guidebot.route.roomSourceIndices
                == [startRoomSourceIndex]
            && guidebot.route.nodeReferences.isEmpty
    }
}

private func closeTrainingGalleryBarrier(in level: inout Level) {
    guard let barrier = level.trainingGalleryBarrier else { return }
    let barrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    for portalIndex in barrier.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags |= 1
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags |= 1
    }
}

private func openTrainingGalleryBarrier(in level: inout Level) {
    guard let barrier = level.trainingGalleryBarrier else { return }
    let barrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    for portalIndex in barrier.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func openTrainingGuidebotReturnBarrier(in level: inout Level) {
    guard let barrier =
            level.trainingCameraMonitorChain?.returnToShip,
          let barrierRoomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == barrier.barrierRoomSourceIndex
          }) else {
        return
    }
    for portalIndex in barrier.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags
            &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func openTrainingLastRoomBarrier(in level: inout Level) {
    guard let chain = level.trainingLastRoomChain,
        let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == chain.barrierRoomSourceIndex
        })
    else {
        return
    }
    for portalIndex in chain.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func openTrainingFinalBotsBarrier(in level: inout Level) {
    guard let chain = level.trainingFinalBotsCompletionChain,
          let roomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == chain.barrierRoomSourceIndex
          })
    else {
        return
    }
    for portalIndex in chain.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags
            &= ~UInt32(1)
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags &= ~UInt32(1)
    }
}

private func closeTrainingLastRoomBarrier(in level: inout Level) {
    guard let chain = level.trainingLastRoomChain,
        let roomIndex = level.rooms.firstIndex(where: {
            $0.sourceIndex == chain.barrierRoomSourceIndex
        })
    else {
        return
    }
    for portalIndex in chain.orderedPortalIndices {
        let portal = level.rooms[roomIndex].portals[portalIndex]
        level.rooms[roomIndex].portals[portalIndex].flags |= 1
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags |= 1
    }
}

private func trainingKillbotEntryBarrierRendersFaces(
    in level: Level
) -> Bool {
    guard let barrier =
            level.trainingCameraMonitorChain?.returnToShip,
          let entry = barrier.killbotEntry,
          let room = level.rooms.first(where: {
              $0.sourceIndex == barrier.barrierRoomSourceIndex
          }) else {
        return false
    }
    return entry.orderedPortalIndices.allSatisfy {
        room.portals[$0].flags & 1 != 0
    }
}

private func closeTrainingKillbotEntryBarrier(in level: inout Level) {
    guard let barrier =
            level.trainingCameraMonitorChain?.returnToShip,
          let entry = barrier.killbotEntry,
          let barrierRoomIndex = level.rooms.firstIndex(where: {
              $0.sourceIndex == barrier.barrierRoomSourceIndex
          }) else {
        return
    }
    for portalIndex in entry.orderedPortalIndices {
        let portal =
            level.rooms[barrierRoomIndex].portals[portalIndex]
        level.rooms[barrierRoomIndex].portals[portalIndex].flags |= 1
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex]
            .portals[portal.connectedPortal].flags |= 1
    }
}

private func trainingForwardGoalWasReached(
    in level: Level,
    lesson: TrainingOpeningLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.forwardGoalObjectHandle
    }!
    guard case let .room(targetRoomSourceIndex) = target.location,
          visitedRoomSourceIndices.contains(targetRoomSourceIndex) else {
        return false
    }
    let presentation = level.objectPresentations.first {
        $0.objectHandle == target.handle
    }!
    let model = level.models.first {
        $0.source == presentation.primaryModel
    }!
    let targetRadius = sourceObjectPresentationSize(
        model: model,
        objectType: target.type
    )
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: targetRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingReturnGoalWasReached(
    in level: Level,
    lesson: TrainingReturnLeftLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.startGoalObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingRightGoalWasReached(
    in level: Level,
    lesson: TrainingReturnRightLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.leftGoalObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingUpGoalWasReached(
    in level: Level,
    lesson: TrainingReturnUpLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.startGoalObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingDownGoalWasReached(
    in level: Level,
    lesson: TrainingReturnDownLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.upGoalObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingRepeatForwardWasReached(
    in level: Level,
    lesson: TrainingRepeatForwardLesson,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    let target = level.objects.first {
        $0.handle == lesson.startGoalObjectHandle
    }!
    return trainingOpeningGoalWasReached(
        target: target,
        targetRadius: lesson.collisionRadius,
        playerStart: playerStart,
        playerEnd: playerEnd,
        playerRadius: playerRadius,
        visitedRoomSourceIndices: visitedRoomSourceIndices
    )
}

private func trainingOpeningGoalWasReached(
    target: PlacedObject,
    targetRadius: Float,
    playerStart: Vector3,
    playerEnd: Vector3,
    playerRadius: Float,
    visitedRoomSourceIndices: [Int]
) -> Bool {
    guard case let .room(targetRoomSourceIndex) = target.location,
          visitedRoomSourceIndices.contains(targetRoomSourceIndex) else {
        return false
    }
    let movement = playerEnd - playerStart
    let lengthSquared = dot(movement, movement)
    let fraction: Float
    if lengthSquared > 0 {
        fraction = max(
            0,
            min(
                1,
                dot(target.position - playerStart, movement) / lengthSquared
            )
        )
    } else {
        fraction = 0
    }
    let closest = playerStart + movement * fraction
    let separation = target.position - closest
    let collisionRadius = playerRadius + targetRadius
    return dot(separation, separation) <= collisionRadius * collisionRadius
}

func sourceAfterburnerForwardControl(
    afterburner: Float,
    fuel: Float
) -> Float {
    var punch: Float = 1
    if fuel > 4.5 {
        punch = 1.8
    } else if fuel > 4, fuel < 4.5 {
        var normalizedFuel = Float(Double(fuel) - 5.0 * 0.8)
        normalizedFuel = Float(Double(normalizedFuel) / (5.0 * 0.1))
        punch = Float(1.0 + Double(normalizedFuel) * 0.8)
    }
    return Float(Double(afterburner) * 1.6 * Double(punch))
}

private func sourceFixedSine(
    gameTime: Float,
    wigglesPerSecond: Float
) -> Float {
    let sourceValue = Int(gameTime * wigglesPerSecond * 65_535) % 65_535
    let angle = UInt16(truncatingIfNeeded: sourceValue)
    let index = Int(angle >> 8) & 0xff
    let fraction = Int(angle & 0xff)
    let sourcePi: Float = 3.141592654
    let firstRadians = Float(
        Double(index) / 256 * 2 * Double(sourcePi)
    )
    let secondRadians = Float(
        Double(index + 1) / 256 * 2 * Double(sourcePi)
    )
    let first = sin(firstRadians)
    let second = sin(secondRadians)
    return Float(
        Double(first)
            + Double(second - first) * Double(fraction) / 256
    )
}

private func sourceIndoorAutoLevelThrust(
    _ input: Vector3,
    orientation: Matrix3,
    storedOrientation: Matrix3,
    fullRotationalThrust: Float,
    turnrollFixedAngle: Float,
    mode: IndoorAutoLevelMode,
    gameTime: Float,
    lastThrustTime: Float
) -> Vector3 {
    guard mode != .off else { return input }
    var result = input
    let angles = sourceExtractAngles(orientation)
    let firedRecently = gameTime < 1.5
    var pitchWasLeveled = false

    if mode == .newPlayer,
       !firedRecently,
       lastThrustTime + 1.5 < gameTime {
        let bound = 750
        var pitch = angles.pitch
        if pitch > bound,
           pitch < 65_535 - bound,
           abs(pitch - 32_768) > bound {
            pitchWasLeveled = true
            if storedOrientation.up.y < 0 {
                pitch = (pitch + 16_384) & 0xffff
            }
            let scale = min(1, 1.05 - abs(storedOrientation.up.y))
            if pitch < 16_834 {
                result = Vector3(
                    x: result.x - scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else if pitch < 32_768 {
                result = Vector3(
                    x: result.x + scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else if pitch < 49_152 {
                result = Vector3(
                    x: result.x - scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else {
                result = Vector3(
                    x: result.x + scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            }
        }
    }

    guard !pitchWasLeveled, abs(result.z) < 100 else { return result }
    let maximumTilt: Float = mode == .newPlayer ? 13_750 : 11_000
    let pitchIsBeyondTilt: Bool
    if angles.pitch < 32_768 {
        pitchIsBeyondTilt =
            Float(abs(angles.pitch - 16_834)) > maximumTilt
    } else {
        pitchIsBeyondTilt =
            Float(abs(angles.pitch - 49_152)) > maximumTilt
    }
    guard pitchIsBeyondTilt else { return result }

    let turnrollBound = turnrollFixedAngle == 0
        ? 10
        : Int(abs(turnrollFixedAngle))
    guard angles.roll > turnrollBound,
          angles.roll < 65_535 - turnrollBound else {
        return result
    }

    var scale: Float
    if angles.pitch < 32_768 {
        scale = (
            Float(abs(16_834 - angles.pitch)) - maximumTilt
        ) / (16_384 - maximumTilt)
    } else {
        scale = (
            Float(abs(49_152 - angles.pitch)) - maximumTilt
        ) / (16_384 - maximumTilt)
    }
    if angles.roll < 32_768 {
        let bankDistance = angles.roll > 28_672
            ? 28_672 - 16_834
            : abs(16_834 - angles.roll)
        var bankScale = 1.04 - Float(bankDistance) / 16_384
        bankScale *= bankScale
        scale *= bankScale
        if firedRecently { scale *= 0.25 }
        result = Vector3(
            x: result.x,
            y: result.y,
            z: result.z - scale * 2 * fullRotationalThrust
        )
    } else {
        let bankDistance = angles.roll < 36_864
            ? 49_152 - 36_864
            : abs(49_152 - angles.roll)
        var bankScale = 1.04 - Float(bankDistance) / 16_384
        bankScale *= bankScale
        scale *= bankScale
        if firedRecently { scale *= 0.25 }
        result = Vector3(
            x: result.x,
            y: result.y,
            z: result.z + scale * 2 * fullRotationalThrust
        )
    }
    return result
}

private func sourceExtractAngles(
    _ matrix: Matrix3
) -> (pitch: Int, yaw: Int, roll: Int) {
    if abs(matrix.forward.x) < 0.000_01,
       abs(matrix.forward.z) < 0.000_01 {
        return (
            matrix.forward.y > 0 ? 0xc000 : 0x4000,
            sourceFixedAtan2(
                cosine: matrix.right.x,
                sine: -matrix.right.z
            ),
            0
        )
    }
    let yaw = sourceFixedAtan2(
        cosine: matrix.forward.z,
        sine: matrix.forward.x
    )
    let yawRadians = Float(yaw) * (2 * Float.pi / 65_536)
    let sinYaw = sin(yawRadians)
    let cosYaw = cos(yawRadians)
    let cosPitch = abs(sinYaw) > abs(cosYaw)
        ? matrix.forward.x / sinYaw
        : matrix.forward.z / cosYaw
    let pitch = sourceFixedAtan2(
        cosine: cosPitch,
        sine: -matrix.forward.y
    )
    let roll = sourceFixedAtan2(
        cosine: matrix.up.y / cosPitch,
        sine: matrix.right.y / cosPitch
    )
    return (pitch, yaw, roll)
}

private func sourceFixedAtan2(cosine: Float, sine: Float) -> Int {
    let radians = atan2(sine, cosine)
    let positive = radians < 0 ? radians + 2 * Float.pi : radians
    return Int(positive * (65_536 / (2 * Float.pi))) & 0xffff
}

private func analyticAngularVelocity(
    velocity: Vector3,
    force: Vector3,
    mass: Float,
    drag: Float,
    duration: Float
) -> Vector3 {
    precondition(mass > 0 && drag > 0 && duration >= 0)
    let oneOverDrag = 1.0 / Double(drag)
    let decay = exp(-(Double(drag) / Double(mass)) * Double(duration))
    func component(_ velocity: Float, _ force: Float) -> Float {
        let forceOverDrag = Double(force) * oneOverDrag
        return Float(
            (Double(velocity) - forceOverDrag) * decay + forceOverDrag
        )
    }
    return Vector3(
        x: component(velocity.x, force.x),
        y: component(velocity.y, force.y),
        z: component(velocity.z, force.z)
    )
}

private func sourceFixedAngleUnits(_ fixedAngleUnits: Float) -> Int16 {
    Int16(truncatingIfNeeded: Int64(fixedAngleUnits.rounded(.towardZero)))
}

private func sourceFixedAngleRadians(_ radians: Float) -> Int16 {
    sourceFixedAngleUnits(radians * (65_536 / (2 * Float.pi)))
}

private func sourceRotationMatrix(
    pitch: Int16,
    yaw: Int16,
    roll: Int16
) -> Matrix3 {
    let radiansPerUnit = 2 * Float.pi / 65_536
    let pitchRadians = Float(pitch) * radiansPerUnit
    let yawRadians = Float(yaw) * radiansPerUnit
    let rollRadians = Float(roll) * radiansPerUnit
    let sinPitch = sin(pitchRadians)
    let cosPitch = cos(pitchRadians)
    let sinRoll = sin(rollRadians)
    let cosRoll = cos(rollRadians)
    let sinYaw = sin(yawRadians)
    let cosYaw = cos(yawRadians)
    let sinRollSinYaw = sinRoll * sinYaw
    let cosRollCosYaw = cosRoll * cosYaw
    let cosRollSinYaw = cosRoll * sinYaw
    let sinRollCosYaw = sinRoll * cosYaw
    return Matrix3(
        right: Vector3(
            x: cosRollCosYaw + sinPitch * sinRollSinYaw,
            y: sinRoll * cosPitch,
            z: sinPitch * sinRollCosYaw - cosRollSinYaw
        ),
        up: Vector3(
            x: sinPitch * cosRollSinYaw - sinRollCosYaw,
            y: cosRoll * cosPitch,
            z: sinRollSinYaw + sinPitch * cosRollCosYaw
        ),
        forward: Vector3(
            x: sinYaw * cosPitch,
            y: -sinPitch,
            z: cosYaw * cosPitch
        )
    )
}

private func sourceMatrixMultiply(_ lhs: Matrix3, _ rhs: Matrix3) -> Matrix3 {
    Matrix3(
        right: sourceTransform(rhs.right, by: lhs),
        up: sourceTransform(rhs.up, by: lhs),
        forward: sourceTransform(rhs.forward, by: lhs)
    )
}

private func sourceTransform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    Vector3(
        x: matrix.right.x * value.x
            + matrix.up.x * value.y
            + matrix.forward.x * value.z,
        y: matrix.right.y * value.x
            + matrix.up.y * value.y
            + matrix.forward.y * value.z,
        z: matrix.right.z * value.x
            + matrix.up.z * value.y
            + matrix.forward.z * value.z
    )
}

private func sourceOrthogonalized(_ matrix: Matrix3) -> Matrix3 {
    let forward = sourceNormalized(matrix.forward)
    let right = sourceNormalized(cross(matrix.up, forward))
    return Matrix3(
        right: right,
        up: cross(forward, right),
        forward: forward
    )
}

private func sourceNormalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0)
    return value / magnitude
}

private func surfacePhysicsBehavior(
    for contact: IndoorWallContact,
    in level: Level
) -> SurfacePhysicsBehavior {
    let room = level.rooms.first { $0.sourceIndex == contact.roomSourceIndex }!
    let texture = room.faces[contact.faceIndex].texture
    return level.surfacePhysics.first { $0.texture == texture }!.behavior
}

private func analyticLinearMotion(
    position: Vector3,
    velocity: Vector3,
    force: Vector3,
    mass: Float,
    drag: Float,
    duration: Float
) -> (position: Vector3, velocity: Vector3) {
    precondition(mass > 0 && drag > 0 && duration >= 0)
    func component(_ p: Float, _ v: Float, _ force: Float) -> (Float, Float) {
        let p = Double(p)
        let v = Double(v)
        let force = Double(force)
        let mass = Double(mass)
        let drag = Double(drag)
        let duration = Double(duration)
        let q = force / drag
        let massOverDrag = mass / drag
        let decay = exp(-(drag / mass) * duration)
        return (
            Float(p + q * duration + massOverDrag * (v - q) * (1 - decay)),
            Float((v - q) * decay + q)
        )
    }
    let x = component(position.x, velocity.x, force.x)
    let y = component(position.y, velocity.y, force.y)
    let z = component(position.z, velocity.z, force.z)
    return (
        Vector3(x: x.0, y: y.0, z: z.0),
        Vector3(x: x.1, y: y.1, z: z.1)
    )
}

private func vectorDistance(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    let x = rhs.x - lhs.x
    let y = rhs.y - lhs.y
    let z = rhs.z - lhs.z
    return sqrt(x * x + y * y + z * z)
}

enum PortalPresentation: String, Codable, Equatable, Sendable {
    case renderedSurface
    case openBoundary
}

struct RenderPortalEdge: Codable, Equatable, Sendable {
    let roomSourceIndex: Int
    let portalIndex: Int
    let faceIndex: Int
    let connectedRoom: Int
    let connectedPortal: Int
    let presentation: PortalPresentation
}

struct WorldRenderVertex: Equatable, Sendable {
    let position: Vector3
    let u: Float
    let v: Float
    let lightmapU: Float
    let lightmapV: Float
    let alpha: Float
}

struct RoomDrawItem: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let texture: SourceResource
    let blend: PresentationBlend
    let lightmapBlend: PresentationLightmapBlend
    let lightmapPageIndex: Int?
    let vertices: [WorldRenderVertex]
    let triangleIndices: [UInt32]
}

struct ModelDrawItem: Equatable, Sendable {
    let objectHandle: UInt32
    let roomSourceIndex: Int
    let model: SourceResource
    let submodelIndex: Int
    let faceIndex: Int
    let material: ModelFaceMaterial
    let blend: PresentationBlend
    let vertices: [WorldRenderVertex]
    let triangleIndices: [UInt32]
}

struct WorldLightCorona: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let assetIndex: Int
    let center: Vector3
    let size: Float
    let firstVertex: Vector3
    let normal: Vector3
    let tint: Vector3
    let blend: PresentationBlend
}

struct WorldRenderExtraction: Equatable, Sendable {
    let visibleRoomSourceIndices: [Int]
    let opaqueDrawItems: [RoomDrawItem]
    let translucentDrawItems: [RoomDrawItem]
    let admittedObjectHandles: [UInt32]
    let modelDrawItems: [ModelDrawItem]
    let lightCoronas: [WorldLightCorona]
    let portalEdges: [RenderPortalEdge]
}

struct SourceVisibleFace: Equatable, Hashable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
}

struct SourceVisibleWorld: Equatable, Sendable {
    let visibleRoomSourceIndices: [Int]
    let faces: [SourceVisibleFace]
    let portalEdges: [RenderPortalEdge]
    let objectClipWindowsByRoom: [Int: [SourceClipWindow]]
}

enum RoomRenderExtractionError: Error, Equatable {
    case missingRoom(Int)
    case missingMaterial(String)
    case missingLightmap(Int)
    case missingCoronaAsset(Int)
}

struct WaterProceduralEvaluator: Sendable {
    private static let dimension = 128
    private static let pixelCount = dimension * dimension

    private let sourceRGBA8: [UInt8]
    private let definition: WaterProceduralDefinition
    private var current = [Int16](repeating: 0, count: pixelCount)
    private var previous = [Int16](repeating: 0, count: pixelCount)
    private var output = Data(repeating: 0, count: pixelCount * 4)
    private var lastVisualTick: Int?

    init(
        image: CanonicalRGBA8Image,
        definition: WaterProceduralDefinition
    ) {
        precondition(
            image.width == Self.dimension
                && image.height == Self.dimension
                && image.rgba8.count == Self.pixelCount * 4
                && definition.lightingShift < 16
                && definition.dampingShift < 16
                && definition.elements.count <= 64
                && definition.evaluationIntervalSeconds.isFinite
                && definition.evaluationIntervalSeconds >= 0,
            "Water evaluators require validated canonical inputs."
        )
        sourceRGBA8 = [UInt8](image.rgba8)
        self.definition = definition
    }

    mutating func rgba8(visualTick: Int) -> Data {
        if lastVisualTick == visualTick { return output }

        let elapsedTicks = lastVisualTick.map { visualTick - $0 } ?? 1
        let stepCount = (1...8).contains(elapsedTicks) ? elapsedTicks : 1
        for step in stride(from: stepCount - 1, through: 0, by: -1) {
            injectStaticElements(frameCount: visualTick - step)
            output = renderCurrentWater()
            calculateNextWater()
            swap(&current, &previous)
        }
        lastVisualTick = visualTick
        return output
    }

    private mutating func injectStaticElements(frameCount: Int) {
        for (elementIndex, element) in definition.elements.enumerated() {
            guard element.kind == .heightBlob else { continue }
            let frequency = Int(element.frequency)
            if frequency != 0 && (frameCount + elementIndex) % frequency != 0 {
                continue
            }
            injectHeightBlob(element)
        }
    }

    private mutating func injectHeightBlob(_ element: WaterProceduralElement) {
        let centerX = Int(element.x1)
        let centerY = Int(element.y1)
        let radius = Int(element.size)
        let radiusSquared = radius * radius
        var left = -radius
        var top = -radius
        var right = radius
        var bottom = radius
        if centerX - radius < 1 { left -= centerX - radius - 1 }
        if centerY - radius < 1 { top -= centerY - radius - 1 }
        if centerX + radius > Self.dimension - 1 {
            right -= centerX + radius - Self.dimension + 1
        }
        if centerY + radius > Self.dimension - 1 {
            bottom -= centerY + radius - Self.dimension + 1
        }
        guard left < right, top < bottom else { return }
        let height = Int16(element.speed)
        for y in top..<bottom {
            let ySquared = y * y
            for x in left..<right where x * x + ySquared < radiusSquared {
                let index = (centerY + y) * Self.dimension + centerX + x
                current[index] = current[index] &+ height
            }
        }
    }

    private func renderCurrentWater() -> Data {
        var rgba8 = [UInt8](repeating: 0, count: Self.pixelCount * 4)
        for y in 0..<Self.dimension {
            let previousY = y == 0 ? Self.dimension - 1 : y - 1
            let nextY = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let previousX = x == 0 ? Self.dimension - 1 : x - 1
                let nextX = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                let dx = Int(current[y * Self.dimension + previousX])
                    - Int(current[y * Self.dimension + nextX])
                let dy = Int(current[previousY * Self.dimension + x])
                    - Int(current[nextY * Self.dimension + x])
                let sampleX = (x + (dx >> 3)) & (Self.dimension - 1)
                let sampleY = (y + (dy >> 3)) & (Self.dimension - 1)
                let sample = (sampleY * Self.dimension + sampleX) * 4
                let shade = min(
                    63,
                    max(0, 32 - (dx >> Int(definition.lightingShift)))
                )
                let destination = index * 4
                let shaded = shadedRGB(
                    red: sourceRGBA8[sample] >> 3,
                    green: sourceRGBA8[sample + 1] >> 3,
                    blue: sourceRGBA8[sample + 2] >> 3,
                    shade: shade
                )
                rgba8[destination] = expandFiveBits(shaded.red)
                rgba8[destination + 1] = expandFiveBits(shaded.green)
                rgba8[destination + 2] = expandFiveBits(shaded.blue)
                rgba8[destination + 3] = 255
            }
        }
        return Data(rgba8)
    }

    private func shadedRGB(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        shade: Int
    ) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let normalized = Float(shade) / 63
        let low = min(normalized / 0.5, 1)
        let high = max((normalized - 0.5) / 0.5, 0)
        let shadedRed = min(Int(Float(red) * low + 31 * high), 31)
        let shadedBlue = min(Int(Float(blue) * low + 31 * high), 31)
        let lowGreen = min(Int(Float(green & 0x07) * low + 7 * high), 7)
        let highGreen = min(Int(Float(green & 0x18) * low + 24 * high), 24)
        return (
            UInt8(shadedRed),
            UInt8(lowGreen + highGreen),
            UInt8(shadedBlue)
        )
    }

    private mutating func calculateNextWater() {
        for y in 0..<Self.dimension {
            let north = y == 0 ? Self.dimension - 1 : y - 1
            let south = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let west = x == 0 ? Self.dimension - 1 : x - 1
                let east = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                var next = (
                    Int(current[north * Self.dimension + x])
                        + Int(current[south * Self.dimension + x])
                        + Int(current[y * Self.dimension + west])
                        + Int(current[y * Self.dimension + east])
                ) >> 1
                next -= Int(previous[index])
                next -= next >> Int(definition.dampingShift)
                previous[index] = Int16(truncatingIfNeeded: next)
            }
        }
    }
}

private func expandFiveBits(_ value: UInt8) -> UInt8 {
    value << 3 | value >> 2
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil
    )
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    presentationGameTime: Float
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil,
        presentationGameTime: presentationGameTime
    )
}

func extractWorldForRendering(
    _ level: Level,
    playerView: PlayerView
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: playerView.camera,
        startRoomSourceIndex: playerView.roomSourceIndex,
        excludedObjectHandle: playerView.objectHandle
    )
}

func extractPreparedRoomDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int
) throws -> [RoomDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [RoomDrawItem] = []
    for room in level.rooms
        .filter({ component.contains($0.sourceIndex) })
        .sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        for faceIndex in room.faces.indices {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            items.append(
                try makeDrawItem(
                    room: room,
                    faceIndex: faceIndex,
                    material: material,
                    lightmaps: level.lightmaps
                )
            )
        }
    }
    return items
}

func extractPreparedModelDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> [ModelDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [ModelDrawItem] = []
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              case let .room(roomSourceIndex) = object.location,
              component.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle] else {
            continue
        }
        var seen: Set<SourceResource> = []
        for source in [
            presentation.primaryModel,
            presentation.mediumModel,
            presentation.lowModel,
        ].compactMap({ $0 }) where seen.insert(source).inserted {
            items += makeModelDrawItems(
                object: object,
                model: modelBySource[source]!,
                materialByTexture: materialByTexture,
                camera: .trainingRoom3,
                cullBackfaces: false
            )
        }
    }
    return items
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?,
    presentationGameTime: Float = 0
) throws -> WorldRenderExtraction {
    let visibility = try extractSourceVisibleWorld(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        portalBlends: Dictionary(
            uniqueKeysWithValues: level.presentationMaterials.map {
                ($0.texture, $0.blend)
            }
        )
    )
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let view = CameraView(camera)

    var opaqueDrawItems: [RoomDrawItem] = []
    var translucentDrawItems: [(depth: Float, item: RoomDrawItem)] = []
    let facesByRoom = Dictionary(grouping: visibility.faces, by: \.roomSourceIndex)
    for roomSourceIndex in visibility.visibleRoomSourceIndices.reversed() {
        let room = roomBySourceIndex[roomSourceIndex]!
        for faceIndex in (facesByRoom[roomSourceIndex] ?? []).map(\.faceIndex).sorted() {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            let item = try makeDrawItem(
                room: room,
                faceIndex: faceIndex,
                material: material,
                lightmaps: level.lightmaps
            )
            if case .additiveSourceAlpha = material.blend {
                let depth = item.vertices.reduce(Float.zero) {
                    $0 + view.project($1.position).depth
                } / Float(item.vertices.count)
                translucentDrawItems.append((depth, item))
            } else {
                opaqueDrawItems.append(item)
            }
        }
    }
    translucentDrawItems.sort {
        if $0.depth != $1.depth { return $0.depth > $1.depth }
        if $0.item.roomSourceIndex != $1.item.roomSourceIndex {
            return $0.item.roomSourceIndex < $1.item.roomSourceIndex
        }
        return $0.item.faceIndex < $1.item.faceIndex
    }
    let lightCoronas = try extractSourceLightCoronas(
        level,
        camera: camera,
        visibility: visibility,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle
    )
    let objectPresentation = extractObjectPresentation(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        visibility: visibility,
        excludedObjectHandle: excludedObjectHandle,
        presentationGameTime: presentationGameTime
    )
    return WorldRenderExtraction(
        visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
        opaqueDrawItems: opaqueDrawItems,
        translucentDrawItems: translucentDrawItems.map(\.item),
        admittedObjectHandles: objectPresentation.handles,
        modelDrawItems: objectPresentation.drawItems,
        lightCoronas: lightCoronas,
        portalEdges: visibility.portalEdges
    )
}

private func extractObjectPresentation(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    visibility: SourceVisibleWorld,
    excludedObjectHandle: UInt32?,
    presentationGameTime: Float
) -> (handles: [UInt32], drawItems: [ModelDrawItem]) {
    guard !level.objectPresentations.isEmpty else { return ([], []) }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let visibleRooms = Set(visibility.visibleRoomSourceIndices)
    let view = CameraView(camera)
    var accepted: [(depth: Float, ordinal: Int, object: PlacedObject,
                    presentation: ObjectPresentationReference, model: CanonicalModel)] = []
    for (ordinal, object) in level.objects.enumerated() {
        guard object.handle != excludedObjectHandle,
              let presentation = presentationByHandle[object.handle],
              presentation.isVisible,
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let primary = modelBySource[presentation.primaryModel] else {
            continue
        }
        let size = sourceObjectPresentationSize(model: primary, objectType: object.type)
        guard sourceObjectIsPortalSafe(
            object,
            size: size,
            startRoomSourceIndex: startRoomSourceIndex,
            clipWindowsByRoom: visibility.objectClipWindowsByRoom,
            view: view
        ), sourceSphereIsVisible(object.position, radius: size, view: view) else {
            continue
        }
        let depth = view.depth(of: object.position)
        let selectedSource = sourceLODModel(presentation, depth: depth)
        guard let model = modelBySource[selectedSource] else {
            preconditionFailure("validated object presentation references must resolve")
        }
        accepted.append((depth, ordinal, object, presentation, model))
    }
    accepted.sort {
        $0.depth == $1.depth ? $0.ordinal < $1.ordinal : $0.depth > $1.depth
    }
    return (
        accepted.map { $0.object.handle },
        accepted.flatMap {
            makeModelDrawItems(
                object: $0.object,
                model: $0.model,
                materialByTexture: materialByTexture,
                camera: camera,
                presentationGameTime: presentationGameTime
            )
        }
    )
}

func sourceObjectPresentationSize(
    model: CanonicalModel,
    objectType: UInt8
) -> Float {
    let offsets = accumulatedModelOffsets(model)
    var maximumDistanceSquared: Float = 0
    for submodel in model.submodels {
        let offset = offsets[submodel.sourceIndex]
        for vertex in submodel.vertices {
            let transformed = offset + vertex.position
            maximumDistanceSquared = max(
                maximumDistanceSquared,
                dot(transformed, transformed)
            )
        }
    }
    var size = sqrt(maximumDistanceSquared) + 0.01
    if objectType == 7 { size *= 2 }
    return size
}

private func sourceObjectIsPortalSafe(
    _ object: PlacedObject,
    size: Float,
    startRoomSourceIndex: Int,
    clipWindowsByRoom: [Int: [SourceClipWindow]],
    view: CameraView
) -> Bool {
    guard case let .room(roomSourceIndex) = object.location else { return false }
    if roomSourceIndex == startRoomSourceIndex { return true }
    return (clipWindowsByRoom[roomSourceIndex] ?? []).contains { window in
        sourceCubeIntersectsWindow(
            center: object.position,
            halfExtent: size,
            view: view,
            window: window
        )
    }
}

private func sourceCubeIntersectsWindow(
    center: Vector3,
    halfExtent: Float,
    view: CameraView,
    window: SourceClipWindow
) -> Bool {
    var combined = UInt8.max
    for x in [-halfExtent, halfExtent] {
        for y in [-halfExtent, halfExtent] {
            for z in [-halfExtent, halfExtent] {
                let point = view.project(center + .init(x: x, y: y, z: z))
                if point.depth <= 0 { return true }
                combined &= clipCode(point, window: window)
            }
        }
    }
    return combined == 0
}

private func sourceSphereIsVisible(
    _ position: Vector3,
    radius: Float,
    view: CameraView
) -> Bool {
    let relative = position - view.eye
    let horizontal = dot(relative, view.right)
    let vertical = dot(relative, view.up)
    let depth = dot(relative, view.forward)
    guard depth >= -radius else { return false }
    let horizontalHalfFOV = atan(1 / view.horizontalProjectionScale)
    let verticalHalfFOV = atan(1 / view.verticalProjectionScale)
    guard abs(horizontal) * cos(horizontalHalfFOV)
            - depth * sin(horizontalHalfFOV) <= radius,
          abs(vertical) * cos(verticalHalfFOV)
            - depth * sin(verticalHalfFOV) <= radius else {
        return false
    }
    return true
}

private func sourceLODModel(
    _ presentation: ObjectPresentationReference,
    depth: Float
) -> SourceResource {
    if let mediumDistance = presentation.mediumDistance,
       depth >= mediumDistance {
        if let lowDistance = presentation.lowDistance,
           depth >= lowDistance {
            return presentation.lowModel
                ?? presentation.mediumModel
                ?? presentation.primaryModel
        }
        return presentation.mediumModel ?? presentation.primaryModel
    }
    return presentation.primaryModel
}

private struct ModelSubmodelTransform {
    let origin: Vector3
    let orientation: Matrix3
}

private func modelSubmodelTransforms(
    _ model: CanonicalModel,
    presentationGameTime: Float
) -> [ModelSubmodelTransform] {
    precondition(
        presentationGameTime.isFinite && presentationGameTime >= 0
    )
    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    var resolved = [ModelSubmodelTransform?](
        repeating: nil,
        count: model.submodels.count
    )
    func resolve(_ index: Int) -> ModelSubmodelTransform {
        if let result = resolved[index] { return result }
        let submodel = model.submodels[index]
        let parent = submodel.parentIndex.map(resolve)
            ?? .init(origin: .zero, orientation: identity)
        let localOrientation: Matrix3
        if case let .rotate(rate, axis) = submodel.presentation {
            let turns = presentationGameTime / rate
            let angle = (turns - floor(turns)) * 2 * Float.pi
            localOrientation = .init(
                right: rotate(
                    .init(x: 1, y: 0, z: 0),
                    around: axis,
                    angle: angle
                ),
                up: rotate(
                    .init(x: 0, y: 1, z: 0),
                    around: axis,
                    angle: angle
                ),
                forward: rotate(
                    .init(x: 0, y: 0, z: 1),
                    around: axis,
                    angle: angle
                )
            )
        } else {
            localOrientation = identity
        }
        let orientation = Matrix3(
            right: transform(
                localOrientation.right,
                by: parent.orientation
            ),
            up: transform(
                localOrientation.up,
                by: parent.orientation
            ),
            forward: transform(
                localOrientation.forward,
                by: parent.orientation
            )
        )
        let result = ModelSubmodelTransform(
            origin: parent.origin
                + transform(submodel.offset, by: parent.orientation),
            orientation: orientation
        )
        resolved[index] = result
        return result
    }
    return model.submodels.indices.map(resolve)
}

private func rotate(
    _ value: Vector3,
    around axis: Vector3,
    angle: Float
) -> Vector3 {
    let cosine = cos(angle)
    let sine = sin(angle)
    return value * cosine
        + cross(axis, value) * sine
        + axis * (dot(axis, value) * (1 - cosine))
}

private func makeModelDrawItems(
    object: PlacedObject,
    model: CanonicalModel,
    materialByTexture: [SourceResource: PresentationMaterial],
    camera: RoomCamera,
    presentationGameTime: Float = 0,
    cullBackfaces: Bool = true
) -> [ModelDrawItem] {
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("model presentation is indoor in the Slice 6 island")
    }
    let transforms = modelSubmodelTransforms(
        model,
        presentationGameTime: presentationGameTime
    )
    let view = CameraView(camera)
    var opaque: [ModelDrawItem] = []
    var alpha: [ModelDrawItem] = []
    for submodel in model.submodels.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        if submodel.presentation == .facing {
            guard let face = submodel.faces.first,
                  case let .texture(texture) = face.material,
                  let material = materialByTexture[texture]
            else {
                preconditionFailure("validated facing presentation must resolve")
            }
            let localPoints = face.corners.map {
                submodel.vertices[$0.vertexIndex].position
            }
            let area = (1..<(localPoints.count - 1)).reduce(Float.zero) {
                $0 + sqrt(dot(
                    cross(
                        localPoints[$1] - localPoints[0],
                        localPoints[$1 + 1] - localPoints[0]
                    ),
                    cross(
                        localPoints[$1] - localPoints[0],
                        localPoints[$1 + 1] - localPoints[0]
                    )
                )) / 2
            }
            let halfWidth = sqrt(area) / 2
            let halfHeight = halfWidth
                * Float(material.image.height)
                / Float(material.image.width)
            let center = object.position
                + transform(
                    transforms[submodel.sourceIndex].origin,
                    by: object.orientation
                )
            let vertices = [
                (center - view.right * halfWidth + view.up * halfHeight, 0, 0),
                (center + view.right * halfWidth + view.up * halfHeight, 1, 0),
                (center + view.right * halfWidth - view.up * halfHeight, 1, 1),
                (center - view.right * halfWidth - view.up * halfHeight, 0, 1),
            ].map {
                WorldRenderVertex(
                    position: $0.0,
                    u: Float($0.1),
                    v: Float($0.2),
                    lightmapU: 0,
                    lightmapV: 0,
                    alpha: 1
                )
            }
            let item = ModelDrawItem(
                objectHandle: object.handle,
                roomSourceIndex: roomSourceIndex,
                model: model.source,
                submodelIndex: submodel.sourceIndex,
                faceIndex: 0,
                material: face.material,
                blend: material.blend,
                vertices: vertices,
                triangleIndices: [0, 1, 2, 0, 2, 3]
            )
            switch material.blend {
            case .opaque: opaque.append(item)
            case .sourceAlpha, .additiveSourceAlpha: alpha.append(item)
            }
            continue
        }
        switch submodel.presentation {
        case .standard, .rotate:
            break
        case .custom, .facing, .glow:
            continue
        }
        let submodelTransform = transforms[submodel.sourceIndex]
        for (faceIndex, face) in submodel.faces.enumerated() {
            let transformedNormal = transform(
                transform(face.normal, by: submodelTransform.orientation),
                by: object.orientation
            )
            let firstLocal = submodelTransform.origin + transform(
                submodel.vertices[face.corners[0].vertexIndex].position,
                by: submodelTransform.orientation
            )
            let firstWorld = object.position + transform(firstLocal, by: object.orientation)
            guard !cullBackfaces
                    || dot(camera.position - firstWorld, transformedNormal) >= 0 else {
                continue
            }
            let vertices = face.corners.map { corner in
                let source = submodel.vertices[corner.vertexIndex]
                let local = submodelTransform.origin
                    + transform(
                        source.position,
                        by: submodelTransform.orientation
                    )
                return WorldRenderVertex(
                    position: object.position + transform(local, by: object.orientation),
                    u: corner.u,
                    v: corner.v,
                    lightmapU: 0,
                    lightmapV: 0,
                    alpha: source.alpha
                )
            }
            var indices: [UInt32] = []
            for index in 1..<(vertices.count - 1) {
                indices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
            }
            let blend: PresentationBlend
            switch face.material {
            case let .texture(texture):
                guard let material = materialByTexture[texture] else {
                    preconditionFailure("validated model materials must resolve")
                }
                blend = material.blend
            case .sourceColor:
                blend = .sourceAlpha(opacity: 255)
            }
            let item = ModelDrawItem(
                objectHandle: object.handle,
                roomSourceIndex: roomSourceIndex,
                model: model.source,
                submodelIndex: submodel.sourceIndex,
                faceIndex: faceIndex,
                material: face.material,
                blend: blend,
                vertices: vertices,
                triangleIndices: indices
            )
            switch blend {
            case .opaque: opaque.append(item)
            case .sourceAlpha, .additiveSourceAlpha: alpha.append(item)
            }
        }
    }
    return opaque + alpha
}

private func accumulatedModelOffsets(_ model: CanonicalModel) -> [Vector3] {
    var offsets = [Vector3?](repeating: nil, count: model.submodels.count)

    func resolve(_ sourceIndex: Int) -> Vector3 {
        if let offset = offsets[sourceIndex] { return offset }

        let submodel = model.submodels[sourceIndex]
        let parentOffset = submodel.parentIndex.map(resolve) ?? .zero
        let offset = parentOffset + submodel.offset
        offsets[sourceIndex] = offset
        return offset
    }

    return model.submodels.indices.map(resolve)
}

func extractSourceLightCoronas(
    _ level: Level,
    camera: RoomCamera,
    visibility: SourceVisibleWorld,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32? = nil
) throws -> [WorldLightCorona] {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var result: [WorldLightCorona] = []
    for visibleFace in visibility.faces {
        let room = roomBySourceIndex[visibleFace.roomSourceIndex]!
        let face = room.faces[visibleFace.faceIndex]
        guard face.portalIndex == nil,
              face.allowsLightCorona,
              let corona = materialByTexture[face.texture]?.lightCorona else {
            continue
        }
        guard level.presentationCoronaAssets.indices.contains(corona.assetIndex) else {
            throw RoomRenderExtractionError.missingCoronaAsset(corona.assetIndex)
        }
        let geometry = sourceFaceCoronaGeometry(room: room, face: face)
        let eyeOffset = geometry.center - camera.position
        let distance = sqrt(dot(eyeOffset, eyeOffset))
        guard distance >= geometry.size * 5 else { continue }
        guard !sourceCoronaRayIsOccluded(
            from: camera.position,
            to: geometry.center,
            level: level,
            visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
            startRoomSourceIndex: startRoomSourceIndex,
            excludedObjectHandle: excludedObjectHandle
        ) else {
            continue
        }
        result.append(
            WorldLightCorona(
                roomSourceIndex: room.sourceIndex,
                faceIndex: visibleFace.faceIndex,
                assetIndex: corona.assetIndex,
                center: geometry.center,
                size: geometry.size,
                firstVertex: room.vertices[face.corners[0].vertexIndex],
                normal: faceNormal(room, face: face),
                tint: corona.tint,
                blend: corona.blend
            )
        )
    }
    return result
}

private func sourceFaceCoronaGeometry(
    room: LevelRoom,
    face: LevelFace
) -> (center: Vector3, size: Float) {
    let first = room.vertices[face.corners[0].vertexIndex]
    var totalArea: Float = 0
    var weightedX: Float = 0
    var weightedY: Float = 0
    var weightedZ: Float = 0
    for index in 1..<(face.corners.count - 1) {
        let second = room.vertices[face.corners[index].vertexIndex]
        let third = room.vertices[face.corners[index + 1].vertexIndex]
        let perpendicular = cross(second - first, third - first)
        let area = sqrt(dot(perpendicular, perpendicular)) / 2
        totalArea += area
        weightedX += ((first.x + second.x + third.x) / 3) * area
        weightedY += ((first.y + second.y + third.y) / 3) * area
        weightedZ += ((first.z + second.z + third.z) / 3) * area
    }
    precondition(totalArea > 0, "validated corona faces must have positive area")
    let normal = faceNormal(room, face: face)
    return (
        Vector3(
            x: weightedX / totalArea + normal.x / 4,
            y: weightedY / totalArea + normal.y / 4,
            z: weightedZ / totalArea + normal.z / 4
        ),
        2 * sqrt(totalArea)
    )
}

private func sourceCoronaRayIsOccluded(
    from origin: Vector3,
    to destination: Vector3,
    level: Level,
    visibleRoomSourceIndices: [Int],
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> Bool {
    let ray = destination - origin
    let distance = sqrt(dot(ray, ray))
    let direction = ray / distance
    let visibleRooms = Set(visibleRoomSourceIndices)
    if case let .wallHit(contact) = traceIndoorMovement(
        in: level,
        startRoom: startRoomSourceIndex,
        start: origin,
        end: destination,
        radius: 0
    ).outcome, contact.distance < distance - 0.000_1 {
        return true
    }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              object.type == 2 || object.type == 4,
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle],
              presentation.isVisible,
              let model = modelBySource[presentation.primaryModel] else {
            continue
        }
        let radius = sourceObjectPresentationSize(
            model: model,
            objectType: object.type
        )
        let originToCenter = object.position - origin
        let projectedDistance = dot(originToCenter, direction)
        guard projectedDistance > 0, projectedDistance < distance else { continue }
        let closest = origin + direction * projectedDistance
        let centerOffset = object.position - closest
        if dot(centerOffset, centerOffset) <= radius * radius {
            return true
        }
    }
    return false
}

func extractSourceVisibleWorld(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    portalBlends: [SourceResource: PresentationBlend]
) throws -> SourceVisibleWorld {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    guard roomBySourceIndex[startRoomSourceIndex] != nil else {
        throw RoomRenderExtractionError.missingRoom(startRoomSourceIndex)
    }
    let view = CameraView(camera)
    var roomDepth = [startRoomSourceIndex: 0]
    var seenRooms: Set<Int> = []
    var visibleRoomSourceIndices: [Int] = []
    var visibleFacesByRoom: [Int: Set<Int>] = [:]
    var portalEdges: [RenderPortalEdge] = []
    var objectClipWindowsByRoom: [Int: [SourceClipWindow]] = [:]

    func renderPastPortal(_ room: LevelRoom, portalIndex: Int) throws -> Bool {
        let portal = room.portals[portalIndex]
        guard portal.flags & 0x0000_0001 != 0 else { return true }
        let face = room.faces[portal.faceIndex]
        guard let blend = portalBlends[face.texture] else {
            throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
        }
        if case .additiveSourceAlpha = blend { return true }
        return false
    }

    func visit(_ roomSourceIndex: Int, window: ClipWindow, depth: Int) throws {
        guard let room = roomBySourceIndex[roomSourceIndex] else {
            throw RoomRenderExtractionError.missingRoom(roomSourceIndex)
        }
        if seenRooms.insert(roomSourceIndex).inserted {
            visibleRoomSourceIndices.append(roomSourceIndex)
        }
        objectClipWindowsByRoom[roomSourceIndex, default: []].append(window)
        if visibleFacesByRoom[roomSourceIndex] == nil {
            visibleFacesByRoom[roomSourceIndex] = depth == 0
                ? Set(room.faces.indices.filter {
                    faceIsFrontFacing(room, faceIndex: $0, eye: camera.position)
                })
                : []
        }

        for (portalIndex, portal) in room.portals.enumerated() {
            portalEdges.append(
                RenderPortalEdge(
                    roomSourceIndex: roomSourceIndex,
                    portalIndex: portalIndex,
                    faceIndex: portal.faceIndex,
                    connectedRoom: portal.connectedRoom,
                    connectedPortal: portal.connectedPortal,
                    presentation: portal.flags & 0x0000_0001 != 0
                        ? .renderedSurface
                        : .openBoundary
                )
            )
            if let connectedDepth = roomDepth[portal.connectedRoom], connectedDepth < depth {
                continue
            }
            guard faceIsFrontFacing(room, faceIndex: portal.faceIndex, eye: camera.position),
                  let portalWindow = projectedPortalWindow(
                      room,
                      faceIndex: portal.faceIndex,
                      view: view,
                      parent: window
                  ) else {
                continue
            }
            guard try renderPastPortal(room, portalIndex: portalIndex) else { continue }
            guard let connected = roomBySourceIndex[portal.connectedRoom] else {
                throw RoomRenderExtractionError.missingRoom(portal.connectedRoom)
            }
            var marked = visibleFacesByRoom[portal.connectedRoom] ?? []
            for faceIndex in connected.faces.indices where
                faceIsFrontFacing(connected, faceIndex: faceIndex, eye: camera.position)
                && faceIntersectsWindow(
                    connected,
                    faceIndex: faceIndex,
                    view: view,
                    window: portalWindow
                ) {
                marked.insert(faceIndex)
            }
            visibleFacesByRoom[portal.connectedRoom] = marked
            roomDepth[portal.connectedRoom] = depth + 1
            try visit(portal.connectedRoom, window: portalWindow, depth: depth + 1)
            roomDepth[portal.connectedRoom] = 255
        }
    }

    try visit(
        startRoomSourceIndex,
        window: .init(left: -1, top: 1, right: 1, bottom: -1),
        depth: 0
    )
    return SourceVisibleWorld(
        visibleRoomSourceIndices: visibleRoomSourceIndices,
        faces: visibleRoomSourceIndices.flatMap { roomSourceIndex in
            let room = roomBySourceIndex[roomSourceIndex]!
            return (visibleFacesByRoom[roomSourceIndex] ?? []).sorted().compactMap {
                faceIsRenderable(room, face: room.faces[$0])
                    ? SourceVisibleFace(roomSourceIndex: roomSourceIndex, faceIndex: $0)
                    : nil
            }
        },
        portalEdges: portalEdges,
        objectClipWindowsByRoom: objectClipWindowsByRoom
    )
}

func sourceRoomThreeContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    precondition(
        room.sourceIndex == 3,
        "Slice 3 camera containment is defined only for source room 3"
    )
    return sourceConvexRoomContains(point, in: room)
}

func sourceConvexRoomContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    room.faces.allSatisfy { face in
        let first = room.vertices[face.corners[0].vertexIndex]
        return dot(point - first, faceNormal(room, face: face)) >= 0
    }
}

private func faceIsRenderable(_ room: LevelRoom, face: LevelFace) -> Bool {
    guard let portalIndex = face.portalIndex else { return true }
    return room.portals[portalIndex].flags & 0x0000_0001 != 0
}

private func makeDrawItem(
    room: LevelRoom,
    faceIndex: Int,
    material: PresentationMaterial,
    lightmaps: LightmapCatalog
) throws -> RoomDrawItem {
    let face = room.faces[faceIndex]
    let lightmapPageIndex: Int?
    if let infoIndex = face.lightmapInfoIndex {
        let pageIndex = lightmaps.infos[infoIndex].pageIndex
        let page = lightmaps.pages[pageIndex]
        guard page.rgba8?.count == page.width * page.height * 4 else {
            throw RoomRenderExtractionError.missingLightmap(pageIndex)
        }
        lightmapPageIndex = pageIndex
    } else {
        lightmapPageIndex = nil
    }
    let vertices = face.corners.map { corner in
        WorldRenderVertex(
            position: room.vertices[corner.vertexIndex],
            u: corner.u,
            v: corner.v,
            lightmapU: corner.lightmapU ?? 0,
            lightmapV: corner.lightmapV ?? 0,
            alpha: Float(corner.alpha) / 255
        )
    }
    var triangleIndices: [UInt32] = []
    for index in 1..<(vertices.count - 1) {
        triangleIndices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
    }
    return RoomDrawItem(
        roomSourceIndex: room.sourceIndex,
        faceIndex: faceIndex,
        texture: face.texture,
        blend: material.blend,
        lightmapBlend: material.lightmapBlend,
        lightmapPageIndex: lightmapPageIndex,
        vertices: vertices,
        triangleIndices: triangleIndices
    )
}

private struct CameraView {
    let eye: Vector3
    let right: Vector3
    let up: Vector3
    let forward: Vector3
    let horizontalProjectionScale: Float
    let verticalProjectionScale: Float

    init(_ camera: RoomCamera) {
        eye = camera.position
        forward = normalized(camera.target - camera.position)
        right = normalized(cross(forward, camera.up))
        up = cross(right, forward)
        precondition(
            camera.projection.horizontalFieldOfViewRadians.isFinite
                && camera.projection.aspectRatio.isFinite
                && camera.projection.horizontalFieldOfViewRadians > 0
                && camera.projection.horizontalFieldOfViewRadians < .pi
                && camera.projection.aspectRatio > 0,
            "camera projection must be finite and positive"
        )
        horizontalProjectionScale = 1 / tan(
            camera.projection.horizontalFieldOfViewRadians / 2
        )
        verticalProjectionScale = horizontalProjectionScale * camera.projection.aspectRatio
    }

    func project(_ point: Vector3) -> ProjectedPoint {
        let relative = point - eye
        let depth = dot(relative, forward)
        return ProjectedPoint(
            x: dot(relative, right) * horizontalProjectionScale / depth,
            y: dot(relative, up) * verticalProjectionScale / depth,
            depth: depth
        )
    }

    func depth(of point: Vector3) -> Float {
        dot(point - eye, forward)
    }
}

private struct ProjectedPoint {
    let x: Float
    let y: Float
    let depth: Float
}

struct SourceClipWindow: Equatable, Sendable {
    let left: Float
    let top: Float
    let right: Float
    let bottom: Float
}

private typealias ClipWindow = SourceClipWindow

private func projectedPortalWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    parent: ClipWindow
) -> ClipWindow? {
    guard faceIntersectsWindow(room, faceIndex: faceIndex, view: view, window: parent) else {
        return nil
    }
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    guard points.allSatisfy({ $0.depth > 0 }) else { return nil }
    let left = max(parent.left, points.map(\.x).min()!)
    let right = min(parent.right, points.map(\.x).max()!)
    let bottom = max(parent.bottom, points.map(\.y).min()!)
    let top = min(parent.top, points.map(\.y).max()!)
    guard left <= right, bottom <= top else { return nil }
    return ClipWindow(left: left, top: top, right: right, bottom: bottom)
}

private func faceIntersectsWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    window: ClipWindow
) -> Bool {
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    let codes = points.map { clipCode($0, window: window) }
    let combinedAnd = codes.reduce(UInt8.max, &)
    if combinedAnd != 0 { return false }
    let combinedOr = codes.reduce(UInt8.zero, |)
    if combinedOr == 0 { return true }
    for index in points.indices {
        let start = points[index]
        let end = points[(index + 1) % points.count]
        if lineIntersectsLine(start, end, window.left, window.top, window.right, window.top)
            || lineIntersectsLine(start, end, window.right, window.top, window.right, window.bottom)
            || lineIntersectsLine(start, end, window.right, window.bottom, window.left, window.bottom)
            || lineIntersectsLine(start, end, window.left, window.bottom, window.left, window.top) {
            return true
        }
    }
    return false
}

private func clipCode(_ point: ProjectedPoint, window: ClipWindow) -> UInt8 {
    guard point.depth > 0 else { return 0x10 }
    var code: UInt8 = 0
    if point.x < window.left { code |= 0x01 }
    if point.x > window.right { code |= 0x02 }
    if point.y > window.top { code |= 0x04 }
    if point.y < window.bottom { code |= 0x08 }
    return code
}

private func lineIntersectsLine(
    _ start: ProjectedPoint,
    _ end: ProjectedPoint,
    _ x1: Float,
    _ y1: Float,
    _ x2: Float,
    _ y2: Float
) -> Bool {
    var numerator = (start.y - y1) * (x2 - x1) - (start.x - x1) * (y2 - y1)
    let denominator = (end.x - start.x) * (y2 - y1) - (end.y - start.y) * (x2 - x1)
    let r = numerator / denominator
    if (0...1).contains(r) { return true }
    numerator = (start.y - y1) * (end.x - start.x) - (start.x - x1) * (end.y - start.y)
    let s = numerator / denominator
    return (0...1).contains(s)
}

private func faceIsFrontFacing(_ room: LevelRoom, faceIndex: Int, eye: Vector3) -> Bool {
    let face = room.faces[faceIndex]
    let normal = faceNormal(room, face: face)
    let first = room.vertices[face.corners[0].vertexIndex]
    return dot(eye - first, normal) > 0
}

private func faceNormal(_ room: LevelRoom, face: LevelFace) -> Vector3 {
    guard let normal = canonicalFaceNormal(room: room, face: face) else {
        preconditionFailure("validated faces must have a usable normal")
    }
    return normal
}

private func normalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0, "camera basis vectors must be nonzero")
    return value / magnitude
}

private func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private func transform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    matrix.right * value.x + matrix.up * value.y + matrix.forward * value.z
}

private func * (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

private func / (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
}

private func dot(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

private func cross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}
