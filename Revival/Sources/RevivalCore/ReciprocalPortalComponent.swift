// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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
