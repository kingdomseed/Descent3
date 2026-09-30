import XCTest

// Synthetic Guide-Bot data for the translated AIGame GuideBot script
// (scripts/AIGame.cpp:4517-6855). The page values follow the GuideBot and
// Invisiblepowerup generic pages the importer reads (manage/generic.cpp:1083);
// the strings are the English texts the source comments give for each TXT()
// index (scripts/AIGame.cpp:59-203). No retail bytes are stored.

let fixtureAIGameStrings: [String] = [
    "Rename GB Unit", // 0 TXT_GBM_RENAME
    "Repair GB", // 1 TXT_GBM_REPAIR
    "Exit ship", // 2 TXT_GBM_EXITSHIP
    "P0", // 3 TXT_GBM_P0
    "P1", // 4 TXT_GBM_P1
    "P2", // 5 TXT_GBM_P2
    "P3", // 6 TXT_GBM_P3
    "P4", // 7 TXT_GBM_P4
    "P5", // 8 TXT_GBM_P5
    "P6", // 9 TXT_GBM_P6
    "P7", // 10 TXT_GBM_P7
    "S0", // 11 TXT_GBM_S0
    "S1", // 12 TXT_GBM_S1
    "S2", // 13 TXT_GBM_S2
    "S3", // 14 TXT_GBM_S3
    "S4", // 15 TXT_GBM_S4
    "S5", // 16 TXT_GBM_S5
    "S6", // 17 TXT_GBM_S6
    "S7", // 18 TXT_GBM_S7
    "Find my powerups", // 19 TXT_GBM_FINDPOWERUPS
    "Find powerup", // 20 TXT_GBM_FINEPOWERUP
    "Find energy", // 21 TXT_GBM_FINDENERGY
    "Find robot", // 22 TXT_GBM_FINDROBOT
    "Find Thief", // 23 TXT_GBM_FINDTHIEF
    "Find an exit to the mine", // 24 TXT_GBM_FINDEXIT
    "Find a mine", // 25 TXT_GBM_FINDMINE
    "Find closest marker", // 26 TXT_GBM_FINDCMARK
    "Find Marker 0", // 27 TXT_GBM_M0
    "Find Marker 1", // 28 TXT_GBM_M1
    "Find Marker 2", // 29 TXT_GBM_M2
    "Find Marker 3", // 30 TXT_GBM_M3
    "Find Marker 4", // 31 TXT_GBM_M4
    "Find Marker 5", // 32 TXT_GBM_M5
    "Find Marker 6", // 33 TXT_GBM_M6
    "Find Marker 7", // 34 TXT_GBM_M7
    "Escort ship", // 35 TXT_GBM_ESCORT
    "Use fire extinguisher", // 36 TXT_GBM_USEEXTIN
    "Use Go Wingnut Powerup", // 37 TXT_GBM_WINGNUT
    "Use Manual Pilot Powerup", // 38 TXT_GBM_PILOTPOWER
    "Use Guardian Powerup", // 39 TXT_GBM_GUARDIAN
    "Use Anti-Virus Powerup", // 40 TXT_GBM_ANTIVIRUS
    "Allow GB chatter", // 41 TXT_GBM_ALLOWCHAT
    "Disallow GB chatter", // 42 TXT_GBM_DISALLOWCHAT
    "Return to ship", // 43 TXT_GBM_RETURNTOSHIP
    "Entering ship!", // 44 TXT_GB_ENTERINGSHIP
    "HELP! I am about to die...", // 45 TXT_GB_HELPMSG
    "This goal is not location based.", // 46 TXT_GB_NOTLOCATION
    "I do not have nav. data on this goal.", // 47 TXT_GB_NONAV
    "On my way!", // 48 TXT_GB_ONMYWAY
    "The goal isn't currently reachable.", // 49 TXT_GB_NOTREACH
    "Returning to ship.", // 50 TXT_GB_ENTERSHIP
    "Escorting ship...", // 51 TXT_GB_ESCORT
    "Finding a robot.", // 52 TXT_GB_FINDROBOT
    "No robots are reachable.", // 53 TXT_GB_NOROBOT
    "Finding a powerup.", // 54 TXT_GB_FINDPOWERUP
    "No powerups are reachable.", // 55 TXT_GB_NOPOWERUP
    "Going to the '%s' marker.", // 56 TXT_GB_GOMARKER
    "None of your markers are reachable.", // 57 TXT_GB_NOMARKER
    "The marker is not reachable.", // 58 TXT_GB_NOMARK
    "Finding the Thief.", // 59 TXT_GB_FINDTHIEF
    "Let's get him!", // 60 TXT_GB_FOUNDTHIEF
    "The Thief is not reachable.", // 61 TXT_GB_NOTHIEF
    "Finding your powerups.", // 62 TXT_GB_FINDPOWERUPS
    "No spew reachable.", // 63 TXT_GB_NOMESSAGE
    "Message Processor off.", // 64 TXT_GB_CHATOFF
    "Message Processor On.", // 65 TXT_GB_CHATON
    "Finding energy.", // 66 TXT_GB_FINDENERGY
    "No energy centers are reachable.", // 67 TXT_GB_NOENERGY
    "Repaired!", // 68 TXT_GB_REPAIRED
    "NOt eNougH shIelDs to do rePAir...", // 69 TXT_GB_NOTENSH
    "Thank you for the new name!", // 70 TXT_GB_NEWNAME
    "No way!", // 71 TXT_GB_NOWAY
    "I am on strike!  I won't do task %d", // 72 TXT_GB_STRIKE
    "GB Command Menu", // 73 TXT_GB_MENUTITLE
    "Find marker: '%s'", // 74 TXT_GB_FINDMARKMENU
    "Get to %s", // 75 TXT_GB_GETTO
    " (%d shields)", // 76 TXT_GB_SHIELDAMOUNT
    "Enter GuideBot name:", // 77 TXT_GB_ENTERNAME
    "Stop shooting me!", // 78 TXT_GBHIT1
    "You hit me!", // 79 TXT_GBHIT2
    "Stop it!", // 80 TXT_GBHIT3
    "Im getting attacked!", // 81 TXT_GBHIT4
    "Ouch!", // 82 TXT_GBHIT5
    "T?o Dama.xgf.ed to exit.  NExfvD rEpair.", // 83 TXT_GBDAMAGED
    "Oops...  Sorry about that!", // 84 TXT_GB_OOPS
    "Take that!", // 85 TXT_GB_SHOOTROBOT
    "I am at the goal, coming back to get you.", // 86 TXT_GB_GOAL1
    "Come on!", // 87 TXT_GB_GOAL2
    "Let's go!", // 88 TXT_GB_GOAL3
    "I am coming back to get you.", // 89 TXT_GB_COMINGBACK
    "The thief stole your %s!", // 90 TXT_THIEFSTEAL
    "The thief stole a %s!", // 91 TXT_THIEFSTEAL1
    "The thief stole %d of your %ss!", // 92 TXT_THIEFSTEAL2
    "This powerup is for the GuideBot.", // 93 TXT_GB_POWERUP
    "The Super Thief stole a %s!", // 94 TXT_STHIEFSTEAL
    "The Super Thief stole %d of your %ss!", // 95 TXT_STHIEFSTEAL2
    "Putting out fires!", // 96 TXT_GBP_PUTOUTFIRE
    "Cowabunga!", // 97 TXT_GBP_COWABUNGA
    "Be gental...", // 98 TXT_GBP_BEGENTAL
    "Let's do it!", // 99 TXT_GBP_LETSDOIT
    "I will convert the infidal!", // 100 TXT_GBP_CONVERTEN
    "Accelerator!!!!!!!", // 101 TXT_GBP_ACCELERATOR
    "No fires to put out!", // 102 TXT_GBPN_NOFIRE
    "I don't want to fight!", // 103 TXT_GBPN_NOFIGHT
    "Go play with yourself...", // 104 TXT_GBPN_GOPLAY
    "Too dissy...", // 105 TXT_GBPN_TOODISSY
    "No enemies are near!", // 106 TXT_GBPN_NOENEMY
    "I am sick of coffee...", // 107 TXT_GBPN_NOCOFFEE
    "I got an extinguisher!", // 108 TXT_GBPP_EXTIN
    "I got the Wingnut Powerup!", // 109 TXT_GBPP_WINGNUT
    "I got the Manual Control Powerup!", // 110 TXT_GBPP_MANCON
    "I got the Guardian Powerup!", // 111 TXT_GBPP_GUARD
    "I got a temporary Anti-Virus!", // 112 TXT_GBPP_ANTIV
    "I got the Accelerator!!!!!!", // 113 TXT_GBPP_ACCEL
    "TXT_WEAP_LASERS", // 114 TXT_WEAP_LASERS
    "TXT_WEAP_VAUSS", // 115 TXT_WEAP_VAUSS
    "TXT_WEAP_MICROWAVE", // 116 TXT_WEAP_MICROWAVE
    "TXT_WEAP_PLASMA", // 117 TXT_WEAP_PLASMA
    "TXT_WEAP_FUSION", // 118 TXT_WEAP_FUSION
    "TXT_WEAP_SUPER", // 119 TXT_WEAP_SUPER
    "TXT_WEAP_MASS", // 120 TXT_WEAP_MASS
    "TXT_WEAP_NAPALM", // 121 TXT_WEAP_NAPALM
    "TXT_WEAP_EMD", // 122 TXT_WEAP_EMD
    "TXT_WEAP_OMEGA", // 123 TXT_WEAP_OMEGA
    "TXT_WEAP_CONCUSSION", // 124 TXT_WEAP_CONCUSSION
    "TXT_WEAP_HOMING", // 125 TXT_WEAP_HOMING
    "TXT_WEAP_IMPACT", // 126 TXT_WEAP_IMPACT
    "TXT_WEAP_SMART", // 127 TXT_WEAP_SMART
    "TXT_WEAP_MEGA", // 128 TXT_WEAP_MEGA
    "TXT_WEAP_FRAG", // 129 TXT_WEAP_FRAG
    "TXT_WEAP_GUIDED", // 130 TXT_WEAP_GUIDED
    "TXT_WEAP_NAPALMR", // 131 TXT_WEAP_NAPALMR
    "TXT_WEAP_CYCLONE", // 132 TXT_WEAP_CYCLONE
    "TXT_WEAP_BLACKSHARK", // 133 TXT_WEAP_BLACKSHARK
    "TXT_WEAP_AUTOMAP", // 134 TXT_WEAP_AUTOMAP
    "TXT_WEAP_HEADLIGHT", // 135 TXT_WEAP_HEADLIGHT
    "TXT_WEAP_ETSCONVERTER", // 136 TXT_WEAP_ETSCONVERTER
    "TXT_WEAP_CLOAK", // 137 TXT_WEAP_CLOAK
    "TXT_WEAP_INVULNERABILITY", // 138 TXT_WEAP_INVULNERABILITY
    "TXT_WEAP_RAPIDFIRE", // 139 TXT_WEAP_RAPIDFIRE
    "TXT_WEAP_QUADLASERS", // 140 TXT_WEAP_QUADLASERS
    "TXT_GB_FIFTEEN_SEC_TO_GO", // 141 TXT_GB_FIFTEEN_SEC_TO_GO
    "TXT_GB_POW_DEPLETED", // 142 TXT_GB_POW_DEPLETED
    "TXT_GB_POW_ACC_ALMOST_DONE", // 143 TXT_GB_POW_ACC_ALMOST_DONE
    "TXT_GB_DONT_HAVE_POWERUP", // 144 TXT_GB_DONT_HAVE_POWERUP
    "TXT_GB_I_FOUND_A_GB_POWERUP", // 145 TXT_GB_I_FOUND_A_GB_POWERUP
]

/// The GuideBot page: AIT_AIS, flying, persistent, rebel, orient to
/// velocity, and auto-avoid friends; 60 units per second.
let fixtureGuideBotInfo: CanonicalObjectInfo = {
    var ai = fixtureAIInfo(
        flags: 0x0209_2c40,
        aiType: 5,
        movementType: 1,
        fov: -1,
        maxVelocity: 60,
        maxDeltaVelocity: 200,
        maxTurnRate: 60_000,
        maxDeltaTurnRate: 600_000,
        notifyFlags: 0x1ffb_fbf2,
        circleDistance: 10,
        aggression: 1
    )
    ai.avoidFriendsDistance = 10
    return CanonicalObjectInfo(
        name: "GuideBot",
        type: 2,
        flags: 0x110f,
        size: 5.659_440_5,
        hitPoints: 500,
        lightDistance: 25,
        lighting: fixtureNoLight,
        ai: ai,
        weaponBatteries: [],
        physics: .init(flags: 0x0002_0000, mass: 5, drag: 10, restitution: 1)
    )
}()

/// The Invisiblepowerup page that the Guide-Bot's helper objects use.
let fixtureInvisiblePowerupInfo = CanonicalObjectInfo(
    name: "Invisiblepowerup",
    type: 7,
    flags: 0x2,
    size: 10.052_408,
    hitPoints: 100,
    lightDistance: 0,
    lighting: fixtureNoLight,
    ai: nil,
    weaponBatteries: [],
    physics: .init(flags: 0x1fa0_0120, mass: 1, drag: 0.1, restitution: 1)
)

/// The SPF_ flags of the Guide-Bot's sound pages: the engine loops and
/// follows its object; the others follow the listener.
let fixtureGuideBotSoundFlags: [String: Int32] = [
    "GBExpulsionA": 128, "GBotAcceptOrder1": 132, "GBotConcern1": 132,
    "GBotEngineB1": 165, "GBotEuphoria1": 132, "GBotExcited1": 132,
    "GBotGreetB1": 132, "GBotHurt1": 133, "GBotPlayerKillBot1": 132,
    "Flare": 132, "Powerup pickup": 128,
]

/// The level with the translated Guide-Bot: the GuideBot page naming the
/// AIGame module (so AIInitAll's Guide-Bot binds the GuideBot script, as
/// the page binds an object made at run time), the Invisiblepowerup page,
/// the module's strings and sound references, a silent clip for each
/// Guide-Bot sound the level lacks, and, when the level has script data, the
/// Guide-Bot object's binding.
func withTrainingGuideBot(
    _ source: Level,
    guideBotHandle: UInt32 = 6_164
) -> Level {
    var guideBotInfo = fixtureGuideBotInfo
    guideBotInfo.moduleName = "aigame"
    var level = source
        .addingObjectInfo(guideBotInfo)
        .addingObjectInfo(fixtureInvisiblePowerupInfo)
    let pcm = Data(repeating: 0, count: 2)
    // The added clips come from the archive the level's other clips name, so
    // the package's source profile lists it.
    let archiveClip = level.soundClips.first
    let profileFile = level.source.profileFiles.first
    let missing = AIGame.references.soundNames.enumerated().filter { _, name in
        !level.soundClips.contains { $0.logicalName == name }
    }.map { offset, name in
        CanonicalSoundClip(
            logicalName: name,
            sourceName: "gbfixture_\(name).wav",
            sourceEntryIndex: 31_000 + offset,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: archiveClip?.sourceArchive
                ?? profileFile?.relativePath ?? "d3.hog",
            sourceSHA256: archiveClip?.sourceSHA256
                ?? String(repeating: "9", count: 64),
            importVolume: 1
        )
    }
    level = level.appendingSoundClips(missing)
    // The module's "Yellow flare" weapon page (Wpn_FindID), on the flare
    // model of the level's bespoke flare (M1 step 8d replaces that flare).
    if let flare = level.trainingRobotGuidebotChain?.yellowFlare,
       !(level.weapons ?? []).contains(where: {
           $0.name.caseInsensitiveCompare("Yellow flare") == .orderedSame
       }) {
        level = level.addingWeapon(fixtureRenamedWeapon(
            fixtureBlueLaser(model: flare.model),
            name: "Yellow flare"
        ))
    }
    level.gameModules = [
        .init(
            module: "aigame",
            strings: fixtureAIGameStrings,
            sounds: AIGame.references.soundNames.map {
                .init(
                    name: $0,
                    key: $0,
                    flags: fixtureGuideBotSoundFlags[$0] ?? 0
                )
            }
        ),
    ]
    guard let scripting = level.scripting else { return level }
    return level.addingScripting(LevelScripting(
        levelScript: scripting.levelScript,
        objects: scripting.objects.map { binding in
            guard binding.objectHandle == guideBotHandle else { return binding }
            return ObjectScriptBinding(
                objectHandle: binding.objectHandle,
                name: binding.name,
                defaultModuleName: "aigame",
                defaultScriptName: "GuideBot"
            )
        },
        messages: scripting.messages,
        streamedAudio: scripting.streamedAudio,
        sounds: scripting.sounds
    ))
}

extension GameWorld {
    /// The Guide-Bot's script memory.
    var testGuideBot: GuideBotMemory? {
        guideBot(buddyHandle)
    }

    /// The Guide-Bot object.
    var testGuideBotObject: GameObject? {
        objects[buddyHandle]
    }
}

extension GameWorld {
    /// Puts the Guide-Bot in the ship without its script's side effects:
    /// ghosted (OBJ_DUMMY, so no AI frame) and in GBM_IN_SHIP, so its
    /// script frame makes no draw.
    mutating func parkTestGuideBotInShip() {
        let me = buddyHandle
        objGhost(me, true)
        updateGuideBot(me) { $0.mode = GuideBotScript.inShipMode }
    }

    /// Undoes `parkTestGuideBotInShip`: the Guide-Bot is a robot in
    /// GBM_AMBIENT again.
    mutating func unparkTestGuideBot() {
        let me = buddyHandle
        objGhost(me, false)
        updateGuideBot(me) { $0.mode = GuideBotScript.ambientMode }
    }

    /// Makes the translated Guide-Bot's flare due in GBM_AMBIENT
    /// (AIGame.cpp:6106-6120): goal slot 1 used, and slots 2 and 3 used when
    /// `helperSlotsAreUsed`. The other timed checks wait, and the bespoke
    /// flares are cleared.
    mutating func prepareTestGuideBotFlare(
        helperSlotsAreUsed: Bool,
        clearsFlares: Bool = true,
        level: Level
    ) {
        let me = buddyHandle
        XCTAssertEqual(guideBot(me)?.mode, GuideBotScript.ambientMode)
        let time = gameTime
        updateGuideBot(me) {
            $0.nextAmbientTime = time + 100
            $0.timeUntilNextFlare = 0.05
            $0.nextPowerupCheckTime = time + 100
            $0.timeUntilNextPlayerVisibilityCheck = 100
            $0.returnTime = time + 100
        }
        let player = testPlayerObject.handle
        for slot in 1...3 {
            objects[me]?.ai?.goals[slot].used = false
            if slot == 1 || helperSlotsAreUsed {
                aiGoalAdd(
                    me, type: AIGoal.getToObjectType, level: slot,
                    influence: 1, guid: -1, flags: 0,
                    .object(player), world: level
                )
            }
        }
        XCTAssertTrue(aiGoalIsUsed(me, 1))
        XCTAssertEqual(aiGoalIsUsed(me, 2), helperSlotsAreUsed)
        if clearsFlares {
            trainingRobotGuidebotState?.yellowFlares = []
        }
    }
}

extension GameSession {
    /// Deploys the Guide-Bot and runs until it is in GBM_AMBIENT (35
    /// frames of 0.1 s).
    func runToTestGuideBotAmbient() {
        var timestamp = 0.0
        runFrames(
            35,
            from: &timestamp,
            firstInput: .init(deploysTrainingGuidebot: true)
        )
    }

    /// Runs `frames` updates of 0.1 s with `input` on the first, and returns
    /// every frame.
    @discardableResult
    func runFrames(
        _ frames: Int,
        from timestamp: inout Double,
        firstInput: InputSnapshot = .zero
    ) -> [PlayerSimulationFrame] {
        var result: [PlayerSimulationFrame] = []
        for index in 0..<frames {
            timestamp += 0.1
            result.append(update(
                at: timestamp,
                input: index == 0 ? firstInput : .zero
            ))
        }
        return result
    }
}

/// Every HUD message of the frames, in order.
func hudMessages(_ frames: [PlayerSimulationFrame]) -> [String] {
    frames.flatMap { $0.trainingOpeningFeedback.flatMap(\.hudMessages) }
}

/// Every sound of the frames, in order.
func soundNames(_ frames: [PlayerSimulationFrame]) -> [String] {
    frames.flatMap {
        $0.trainingOpeningFeedback.compactMap(\.soundSourceName)
    }
}

/// `weapon` under another page name.
func fixtureRenamedWeapon(_ weapon: CanonicalWeapon,
                          name: String) -> CanonicalWeapon {
    let encoded = try! JSONEncoder().encode(weapon)
    var object = try! JSONSerialization.jsonObject(with: encoded)
        as! [String: Any]
    object["name"] = name
    return try! JSONDecoder().decode(
        CanonicalWeapon.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
}
