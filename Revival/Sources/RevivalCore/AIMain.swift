// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/AImain.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): AIPowerSwitch (:6231), reached from
// scripts through osipf_AIPowerSwitch (Descent3/osiris_predefs.cpp:589).
// Attached children arrive with the attach system; until then no object has
// any.

extension GameWorld {
    /// osipf_AIPowerSwitch and AIPowerSwitch: a CT_AI object sets or clears
    /// AIF_DISABLED. Any other object is left alone.
    mutating func aiPowerSwitch(_ handle: ObjectHandle, on: Bool) {
        guard var object = objects[handle], var ai = object.ai else {
            return
        }
        if on {
            ai.flags &= ~ObjectAIFrame.disabledFlag
        } else {
            ai.flags |= ObjectAIFrame.disabledFlag
        }
        object.ai = ai
        objects[handle] = object
    }
}
