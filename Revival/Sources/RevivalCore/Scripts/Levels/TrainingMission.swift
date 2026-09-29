// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/TrainingMission.cpp (Descent 3,
// Copyright (C) 2024 Parallax Software, GPL-3.0-or-later).
//
// M1 step 3 holds only the names this script looks up at run time, so that
// D3Import can resolve them into canonical keys. The event handlers arrive
// in M1 step 4 and later steps.

enum TrainingMissionScript {
    /// TrainingMission.cpp:853 Sound_names (resolved by Scrpt_FindSoundName).
    static let soundNames = ["MenuBeepEnter", "PupC1"]

    /// The file names passed to aSoundPlaySteamingText, in first-use source
    /// order (TrainingMission.cpp:1434 to :2377). Spelling kept as written.
    static let streamedAudioNames = [
        "GuideBotB.osf", "proceed6.osf", "welcome.osf", "follow.osf",
        "bank.osf", "pitch.osf", "kill1.osf", "proceed5.osf",
        "GuidebotF.osf", "done.osf", "return1.osf", "left1.osf",
        "up1.osf", "repeat.osf", "lright.osf", "udown.osf",
        "proceed1.osf", "return2.osf", "return3.osf", "Intro1.osf",
        "proceed2.osf", "intro2.osf", "proceed4.osf", "proceed3.osf",
        "almost.osf", "intro3.osf", "intro4.osf", "GuideBotC.osf",
        "GuideBotD.osf", "GuideBotA.osf", "intro6.osf", "intro7.osf",
    ]

    static let references = LevelScriptReferences(
        soundNames: soundNames,
        streamedAudioNames: streamedAudioNames
    )
}
