# Plan

Status: the only live plan. Updated 2026-09-30. It replaces `roadmap.md`, `current-plan.md`, and both ledgers.

Keep this file short. When you finish an item, tick it and edit "Current state". Do not add history. Git has the history.

## Current state

- **Milestone:** M1, Runtime foundation. Steps 1, 1b, 2, 2b, 3, 4, 5, 6, and 7 are done. Step 8 is in progress: 8a (generic AI goals, paths, BOA), 8b (the translated GuideBot and GBPowerup classes in `Scripts/AIGame*.swift`, dispatched through `Scripts/DefaultScript.swift`), and 8c (the buddy menu in `BuddyMenu.swift` with its native AppKit menu, generic triggers in `Trigger.swift`, and Scripts 032, 058, and 060 in `TrainingMission.swift`) are in. Still to do for step 8: generic flares with the deletion of `TrainingGuidebotSimulation.swift` (8d). M0 (reset) is done on branch `revival/replan-2026-09`.
- **Game today:** Training is playable to completion in RevivalMac from imported content. Flight, collision, timing, the indoor Metal renderer, Guide-Bot, Training scripts, pause, HUD text, quicksave, F1 help, and pilot profiles work. Scripts 000-031, 033-037, 043-049, and 051-056 run through the Osiris runtime (`Scripts/OsirisLoadandBind*.swift`, `LevelModule.trainingMission`, DALLAS functions in `Scripts/DallasFuncs*.swift`). Contacts are `EVT_COLLIDE` from the physics moves (`Collide.swift`: player with powerup, and player with weapon against the ship's polygon model, `PolyCollide.swift`). Each frame runs AIFrameAll, then one ascending-slot object loop that includes the player. Placed objects get their object page (`ObjectInfo.swift`, imported by `GenericPage.swift`), and CT_AI objects get an AI frame before Script 000 (`AIMain*.swift`, `AIGoal.swift`, `AIPath.swift`). The dodge turret and the player fire real weapon objects (`RobotFire.swift`, `WeaponFire.swift`, `WeaponFire+Player.swift`), and FollowBot1 flies the FollowLoop1 goal. Weapons hit, explode (`VisEffect.swift`, shockwaves in `Fireball.swift`), bounce off force fields, and damage every object (`Damage.swift`); deaths go through `KillObject`, `DoDyingFrame` (with their debris, splinters, rings, spew, and events: `Fireball+Effects.swift`, `ObjectPhysics.swift`, `GameEvent.swift`), and `ObjDeleteDead` to `EVT_DESTROY`. A killed player starts dying (the death sequence is M2). The Guide-Bot is the translated AIGame default script: `AIInitAll` takes over the placed GuideBotB (ghosted in the ship), and its birth, ambient mode, messages, commands, goal routes, return to the ship, powerup fetch, flares, and engine sound loop run through the Osiris, multisafe, AI goal, and BOA calls (`Scripts/OsirisPredefs.swift`, `SoundSystem.swift`, `Inventory.swift`). D3Import adds each reached game module's `aigame.str`, sounds, weapons, and object pages (`StringTableImport.swift`, `GameModuleImport.swift`), and the level's stored BOA tables when their checksum matches (`BOATables.swift`: `AIFindAltPath`, `BOA_ComputeMinDist`, and the room route). The module's `rand()` has its own state; every object gets its EVT_INTERVAL. F4 opens the buddy menu: the game pauses, the Guide-Bot's `COM_GET_MENU` list shows, and the chosen command (with the rename text) goes to it as `COM_DO_ACTION`. The player's move checks trigger faces (`CheckTrigger`), so Portal2 sends `EVT_COLLIDE` to Script 032. The flare particles and Scripts 038-042, 050, 057, and 059 are still bespoke Swift; the bespoke Camera Monitor use sends the item's `EVT_USE`, whose translated Script 059 handler only counts `ScriptActionCtr_059` so far (step 9 adds its actions). Training needs a schema 12 package (reimport).
- **Code:** ~50.3k Swift lines in `Revival/Sources` and ~38.0k in `Revival/Tests`, most of it still Training-specific. All mutable state is in `GameWorld` (objects in `ObjectTable`), owned by `GameSession`; quicksave is `GameSave` schema 2. `GameWorld` also holds the level module state, `OsirisTimers`, the player control flags, and per-object scripts, ghost, lighting, and AI fields. Package schema 12 adds `Level.scripting`, and optional `objectInfos` and `weapons` tables. No file is over 4,000 lines. The largest is `D3ImportOperation.swift` at ~2,810.
- **Last commit:** `0d13db46` (step 8b). Step 8c is uncommitted. `origin` has up to `ff4ca602` (M0); the M1 commits are local.
- **Toolchain:** Xcode 27.0 release, Swift 6.4, macOS 27 dev machine, deployment floor macOS/iOS 26.
- **Test baseline (Release, full suite):** 530 tests: 522 pass, 2 fail, 6 skipped (they need `REVIVAL_TRAINING_PACKAGE`; with a fresh schema 12 import they pass: level start, the timed dodge, DestroyBot1 shot down, the translated Guide-Bot release, MakeBOA remaking the stored BOA tables, and Portal2 with the buddy menu release). The two failures need local owned content (`testOwnedGuidebotGreetingPackagePinsCoupledSoundBoundary` and `testTrainingMessagesRequireScript006GoDown`).
- **Blockers:** None. The Metal Toolchain is installed, and RevivalMac, RevivalEditor, and RevivalMobile build.

## Milestones

| # | Milestone | Exit (all must hold) |
|---|---|---|
| M0 | **Reset** ✅ | Core docs rewritten. Old docs retired (preserved at tag `revival-docs-v1`). Skills updated for Xcode 27 release. Upstream and forks checked. |
| M1 | **Runtime foundation** | Training plays to completion as before, now through `GameWorld`, `ObjectTable`, Osiris dispatch, the DALLAS API, and `Scripts/Levels/TrainingMission.swift`. There are no `training*` fields or functions outside that script file and the Guide-Bot game-module script. Package schema 12. `GameSave` replaces continuation schema 7. Tests consolidated, with every file under 4,000 lines. Sol verification passes. |
| M2 | **Campaign systems** | Game tables imported. The full object frame (all movement and control types), all weapons, damage, powerups, inventory, countermeasures, player death and respawn, and difficulty. General robot AI (AIMain, AIGoal, paths, BOA, robot fire, ambient, AIGame robots). Doors, triggers, matcens, level goals, fuel centers, force fields. Sound through `AVAudioEngine` (3D, ambient, voice). Proof: Training's RASBot1 attacks and can kill the player, and the player respawns, all through general code. |
| M3 | **Outdoor and mission flow** | Terrain (simulation, collision, LOD renderer, sky, weather, AI on terrain). Mission sequence, level transitions, and ship carry-over. In-game cinematics and popup views. The DALLAS translator tool works. **Level 1 plays start to finish.** |
| M4 | **Presentation and shell** | Real HUD with retail fonts, gauges, cockpit, reticle, and the Guide-Bot menu. Main menu, pilots, options and controls, TelCom briefings, automap and markers. Movies (MVE converted by D3Import, played with AVFoundation). Music (the original region and OMF system). Save and load across levels. |
| M5 | **Base campaign** | Levels 2–17 and secret levels S1 and S2 play start to finish, bosses included, on all difficulty levels. |
| M6 | **Mercenary** | `AIGame3` and Merc 1–7 play start to finish. Confirm which game module Mercenary binds to. |
| M7 | **1.0 release (Mac)** | First-run import UX. Release build on the M4 at 1920×1080: 99th-percentile frame time ≤ 16.7 ms and no frame over 33 ms outside level load, in Training, the largest indoor level, and the largest outdoor level. Every level in the checklist is at `V`, with the executed playthrough results recorded. Every item in the `product.md` acceptance list is checked. Signed and notarized app. No open P1/P2 defects. |

M2 game-tables note: Texture slot order: legacy dependency loading (manage/texpage.cpp:1006) can allocate a later texture early; D3Import uses table ordinal order. Translate the allocation order when the full page tables are imported.

After 1.0: P1 iPhone/iPad, P2 creator suite, P3 multiplayer, P4 replay/demos, P5 enhanced graphics (see `product.md`).

At the start of every milestone: recheck the upstream and fork heads (`sources.md` section 1), and run a Sonnet sweep of the legacy files the milestone touches, looking for missed callers and dependencies. At the end of every milestone: a Codex `gpt-6-astra` high verification of the exit criteria (`engineering.md` section 6), then tag `revival-mN` when the owner authorizes it.

## Next work: M1 Runtime foundation

Each step lands green: the build passes, Training is playable in RevivalMac, and quicksave/quickload still work. A behavior step adds a focused test first. A behavior-neutral move uses the existing suite as its guard. Each step deletes the bespoke Training code it replaces. The detailed design is in `architecture.md`, sections 2–7.

- [x] **1. Split oversized test files.** A behavior-neutral split of the four test files over 4,000 lines, done before they grow further. Fixtures go to helper files. Guard: the existing suite.
- [x] **1b. Green baseline.** Install the Metal Toolchain. Fix or re-scope the four real failures above, so every later step starts from a known-green suite.
- [x] **2. `GameWorld` + object table + save, in one slice.** Add `ObjectHandle`, `GameObject`, and `ObjectTable` (translated from `object.h:642` and `object.cpp:1605–1707`, LIFO free list, signature wrap). Move game time, frame duration, RNG, players, mutable room and portal state, the object table, **and the existing Training state structs** into `struct GameWorld` in the same change. Move **every** reader and writer of `level.objects` (for example `PlayerSimulationUpdate.swift:60` and `PlayerSimulation.swift:1634`) to the table at once. `PlayerSimulation` becomes `GameSession { var world }`. `GameSave` = Codable `GameWorld` plus the package fingerprint and pilot. It replaces continuation schema 7 and its `validTraining*Continuation` functions, so quicksave stays complete through every later step. Tests: allocation order, stale-handle rejection, and save round-trip then advance (`architecture.md` section 7).
- [x] **2b. Fixture defect (found in step 2).** A real concussion missile that kills robot 4112 in `makePlayerConcussionLevel()` crashed in `setPortalRenderFaces` (`GameWorld.swift:129`) when `openTrainingGalleryBarrier` ran. Cause: `makeTrainingGuidebotYellowFlareLevel()` rebuilt room 1 with no portals, so room 2 portal 0 had no reciprocal. `Level.validate()` already rejects this (`invalidPortal`), and every package load validates, so it was a fixture bug only. The fixture now keeps room 1 and adds the shell.
- [x] **3. Generic script data in the package (additive).** D3Import adds the level script name, object script names and custom data, the `.msg` string table, and canonical sound and voice keys (package schema 12). The old Training fields stay until their steps below delete them. Test: the synthetic D3L produces these fields.
- [x] **4. Osiris dispatch, timers, level start.** Add `ScriptEvent`, `ObjectScripts`, the `continueChain` and `continueDefault` results, `callObjectEvent`/`callLevelEvent`/`callTriggerEvent`, and `OsirisTimers`. Add `LevelModule.trainingMission` with `EVT_LEVELSTART` (Script 000) and timer 0 (Script 002). Add the DALLAS functions those need (`aObjHide`, `aSetLevelTimer`, `aShowHUDMessage`, `aSoundPlaySteamingText`, `aToggle*PlayerControl`, `aObjSetLighting*`, `aAISetState`). Test: at 0.1 s frames, the 1.0 s timer fires on the 11th frame; then "Welcome", `welcome.osf`, and "GoForward", in that order (`TrainingMission.cpp:1506-1508`). Open for later steps: the Guide-Bot HUD token (step 8), the dying-player timer detonator (step 7), and readers of the new object lighting, AI power, and player invulnerability state (steps 5-7).
- [x] **5. Opening and return lessons** (Scripts 001–015, 030, 033). Goal contacts become `EVT_COLLIDE` from `Collide.swift`. Delete `TrainingOpeningLesson` and its validators and import adder.
- [x] **6. Dodge and maneuver** (Scripts 016–026). Object pages, AI frames, the follow-path goal, turret fire, and weapon objects. Delete the bespoke dodge and maneuver types.
- [x] **7. Weapon → damage → death.** `WeaponFire` and `Damage` apply shields. Shields below 0 go through `KillObject` → dead flag → `ObjDeleteDead`. Keep its order (`object.cpp:2004`): inform goals, remove inventory, send `EVT_CHILD_DIED`, then `EVT_DESTROY`. Custom handlers replace the robot and destroy chains (Scripts 028, 029, 036, 043–046, 051–055). Delete the 10 `destroyTraining*` methods and the 9 death-chain types. The goal and inventory steps of `ObjDeleteDead` move to step 9, and player death to M2 (`architecture.md` section 9).
- [ ] **8. Guide-Bot as the `AIGame` default script.** Translate `AIGame.cpp:4517–6855` onto `AIGoal`, `BOA`, and `WeaponFire`. Keep the accepted route correction (`architecture.md` section 9). Event routes follow the C++: Script 032 is a trigger `EVT_COLLIDE` (`TrainingMission.cpp:2325`). Script 060 runs in the level `EVT_INTERVAL` (`TrainingMission.cpp:1431`). F4 opens the Buddy (Guide-Bot) menu (`GameLoop.cpp:1493`), whose exit command sends the Guide-Bot `EVT_USE` (`AIGame.cpp:5243`). Delete `TrainingGuidebotSimulation.swift`.
  - [x] **8a. Generic AI goal, path and route layer.** `GoalAddGoal`/`GoalDoFrame`/`GoalPathComplete`/enablers (`AIGoal.cpp`), dynamic paths (`aipath.cpp:977`), generic `BOA.swift` room route (the accepted route difference now lives here), avoid-friends and orientation cases, notify payloads.
  - [x] **8b. GuideBot class.** `Scripts/DefaultScript.swift`, `AIGame.swift`, `AIGame+GuideBot.swift` (DoInit, SetMode/SubMode, the 2.5 s DoMessage gate, commands, collide, use, notify, frame); the Osiris/multisafe calls it needs; `AIInitAll` taking over the Guide-Bot object (`AImain.cpp:3833`); import `aigame.str`, the GBot sounds, and the Yellow flare and spark weapons.
  - [x] **8c. Buddy menu and Guide-Bot scripts.** Core buddy menu state and the F4 AppKit list (with rename); generic player trigger collide; Scripts 032, 058 and 060 in `TrainingMission.swift` (settle the Script 058/059 Camera Monitor seam with step 9).
  - [ ] **8d. Generic flares and deletion.** Flares as weapon objects (particles, timeout spawn, sticking, flicker light, `FireFlareFromPlayer`); delete `TrainingGuidebotSimulation.swift`, the bespoke flare state, and their fields, validators, adders, diagnostics and presentation paths; migrate the Guide-Bot and flare tests.
- [ ] **9. Camera Monitor, pickups, last room, final goal** (Scripts 037–042, 047–050, 056–059; Script 059 is the Camera Monitor `EVT_USE` handler, `CustomObjectScript_080E`: its translated handler now only counts `ScriptActionCtr_059`; step 9 adds its actions and replaces the bespoke use in `PlayerSimulationUpdate.swift`). `Inventory` (use removes the item only when the script returns `continueDefault`, `Inventory.cpp:819`), the powerup path (`multisafe.cpp:2467`), `aCreatePopupView`, `aEndLevel`, and level goals. Delete the remaining chain types.
- [ ] **10. Import cleanup.** Delete the Training-specific package fields and import code, and split `runD3Import` by stage.
- [ ] **11. Test consolidation.** Per-API-family unit tests on synthetic worlds, one `TrainingMissionScriptTests` that drives events into a synthetic level, and one retail-gated playthrough trace using a single `REVIVAL_TRAINING_PACKAGE` variable. Target: about 8k test lines, every file under 4,000. Replace GameSave's NestedStateSweep (field-name convention) with typed validation once the Training state structs are gone.
- [ ] **12. Editor and mobile still compile.** Remove the Training-specific editor edits (the barrier edit, FollowLoop1 node orientation) or re-home them on generic objects and paths. RevivalMobile builds.
- [ ] **13. M1 verification.** Play Training in RevivalMac from a fresh import, and check each Training checkpoint below. Full suite green. Astra high verification of the M1 exit criteria. Tag `revival-m1` when the owner authorizes it.

**Training checkpoints** (M1 verification and later regressions): the welcome lesson and controls lessons (Scripts 000–015); the timed dodge; the maneuver and follow-bot (016–026); DestroyBot1 and DestroyBot2 (028, 029, 036); Portal2 and Guide-Bot release (032); the Guide-Bot goal command and return to ship; Camera Monitor use (059); the invulnerability and cloak pickups (047, 048); RASBot1–4 and LastBot1–5 deaths; the final bots and final goal (035, 056, 057); level end with the success result; quicksave and quickload mid-level.

Expected net change: about −29k lines (Sources ~+10k/−17k, Tests ~+8k/−30k).

## Level checklist (1.0)

Status: `—` not started, `S` script translated, `P` plays start to finish, `V` verified (full playthrough plus Codex verification).

| Level | Legacy script | Status | Notes |
|---|---|---|---|
| Pilot Training | `TrainingMission.cpp` | P (bespoke) | M1 moves it onto the runtime |
| Level 1 | `level1.cpp` | — | Needs terrain (`TerrainAccessRoom`) |
| Level 2 | `level2.cpp` | — | |
| Level 3 | `level3.cpp` | — | Adopt the lava-room fog fix |
| Level 4 | `level4.cpp` | — | |
| Level 5 | `level5.cpp` | — | |
| Level 6 | `Level6.cpp` | — | |
| Level 7 | `level7.cpp` | — | |
| Level 8 | `level8.cpp` | — | |
| Level 9 | `Level9.cpp` | — | |
| Level 10 | `level10.cpp` | — | |
| Level 11 | `level11.cpp` | — | |
| Level 12 | `Level12.cpp` | — | Adopt the sun/earth blend fix |
| Level 13 | `level13.cpp` | — | |
| Level 14 | `level14.cpp` | — | Mirror-node arc (Piccu #79) |
| Level 15 | `LEVEL15.cpp` | — | |
| Level 16 | `Level16.cpp` | — | |
| Level 17 | `level17.cpp` | — | |
| Secret S1 | `LevelS1.cpp` | — | |
| Secret S2 | `levelS2.cpp` | — | |
| Merc 1–7 | `Merc1.cpp`, `Merc02.cpp`, `Merc3.cpp`, `Merc4.cpp`, `merc5.cpp`, `Merc6.cpp`, `Merc7.cpp` | — | `AIGame3.cpp`; `Merc3.cpp` has a 685-line custom block |

## Open questions

- Which game module does Mercenary bind to (`AIGame3` only, or `AIGame3` plus `AIGame`)? Answer this before M6.
- Should the level scripts move to their own `RevivalScripts` build target? Decide from measured build time in M3.
- Movie format: convert MVE to HEVC/ProRes in D3Import, or decode MVE natively? Decide in M4.
