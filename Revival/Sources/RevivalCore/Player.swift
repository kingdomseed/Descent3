// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/Player.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): MakePlayerInvulnerable (:1576),
// MakePlayerVulnerable (:1597), and the invulnerability part of
// DoPlayerFrameForOne (:1816-1823). The HUD texts TXT_INVULNON and
// TXT_INVULNOFF (stringtable.h:663, :671) are their English text until the
// engine string table arrives (M4).

/// The engine HUD texts the translated engine shows.
enum EngineText {
    /// TXT_INVULNON (stringtable.h:671).
    static let invulnerabilityOn = "Invulnerability On"
    /// TXT_INVULNOFF (stringtable.h:663).
    static let invulnerabilityOff = "Invulnerability Off"
    /// TXT_INVULNALREADY (stringtable.h:672).
    static let invulnerabilityAlready = "You're already invulnerable"
    /// TXT_CLOAKON (stringtable.h:673).
    static let cloakOn = "Cloak On"
    /// TXT_MSG_CLOAKOFF (stringtable.h:665).
    static let cloakOff = "Cloak Off"
    /// TXT_CLOAKALREADY (stringtable.h:674).
    static let cloakAlready = "You already are cloaked"
}

extension GameWorld {
    /// MakePlayerInvulnerable (Player.cpp:1576) for player 0. With
    /// `playSoundAndMessage`, the player gets
    /// PLAYER_FLAGS_PLAYSOUNDMSGFORINVULN, which is never cleared, and hears
    /// "Invulnerability on" at half volume with TXT_INVULNON.
    mutating func makePlayerInvulnerable(
        time: Float,
        playSoundAndMessage: Bool = false
    ) {
        playerInvulnerableTime = time
        if playSoundAndMessage {
            playerInvulnerabilityAnnounces = true
            play3DSound(EngineSound.invulnerabilityOn, volume: 0.5)
            addHUDMessage(EngineText.invulnerabilityOn)
        }
    }

    /// MakePlayerVulnerable (Player.cpp:1597) for player 0: a player whose
    /// invulnerability once came with its sound and message hears
    /// "Invulnerability off" at half volume with TXT_INVULNOFF.
    mutating func makePlayerVulnerable() {
        playerInvulnerableTime = nil
        if playerInvulnerabilityAnnounces {
            play3DSound(EngineSound.invulnerabilityOff, volume: 0.5)
            addHUDMessage(EngineText.invulnerabilityOff)
        }
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
