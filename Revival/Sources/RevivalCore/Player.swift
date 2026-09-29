// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/Player.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): MakePlayerInvulnerable (:1576),
// MakePlayerVulnerable (:1597), and the invulnerability part of
// DoPlayerFrameForOne (:1816-1823). The sound and message option of
// MakePlayerInvulnerable is left out: scripts call it with the default
// `false` (multisafe.cpp:1774).

extension GameWorld {
    /// MakePlayerInvulnerable (Player.cpp:1576) for player 0.
    mutating func makePlayerInvulnerable(time: Float) {
        playerInvulnerableTime = time
    }

    /// MakePlayerVulnerable (Player.cpp:1597) for player 0.
    mutating func makePlayerVulnerable() {
        playerInvulnerableTime = nil
    }

    /// DoPlayerFrameForOne's invulnerability countdown
    /// (Player.cpp:1816-1823). It uses the previous Frametime, as every
    /// frame system does.
    mutating func doPlayerInvulnerabilityFrame(frameTime: Float) {
        guard var time = playerInvulnerableTime else { return }
        time -= frameTime
        if time <= 0 {
            makePlayerVulnerable()
        } else {
            playerInvulnerableTime = time
        }
    }
}
