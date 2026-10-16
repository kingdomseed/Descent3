# Plan

Status: the only live plan. Updated 2026-10-16. It replaces `roadmap.md`, `current-plan.md`, and both ledgers.

Keep this file short. When you finish an item, tick it and edit "Current state". Do not add history. Git has the history.

## Current state

- **Milestone:** M1 runtime foundation is complete and pushed on `codex/finish-m1`. M2 continues from `22bbadba` on `codex/m2-game-tables`; table identities and ship armor are complete. The original checkout and its local changes are preserved.
- **Runtime:** Training uses the general object table, Osiris events, DALLAS API, AI, weapons, inventory, and goals. Package schema is 14 and requires the ship armor scalar. GameSave schema is 3. There are no bespoke Training package fields.
- **Verified:** 561 Release tests pass with a fresh schema-14 retail import, with no failures or skips. This includes general non-animated robot burst fire, projectile damage, save/load continuation, and the canonical Training trace. Sol xhigh found no actionable defects. Mac, editor, and unsigned mobile builds pass for this change. The table-and-armor slice is committed as `ee188bc1`.
- **M1 native proof:** the M1 fresh-import run completed Training through ordinary controls and app-written saves. All Training checkpoints passed, including Guide-Bot return, Camera Monitor use, both powerups, RASBot1–4, LastBot1–5, and the final goal. The app showed "Mission Successful" with 2,400 points, 12 enemies killed, and zero deaths. Pilot completion was saved and the result acknowledged. The app is closed and the original app state is restored.
- **Next:** trace and translate the RAS1 `EvaderModA` default-script path and its remaining dependencies. Body and battery animation, full combat, world systems, and native attack/death/respawn proof remain open. The three fetched source heads are unchanged. Push and tags require owner authorization. M2 evidence is in ignored `runtime-data/revival-evidence/m2-game-tables-20261016/` and `m2-robot-fire-20261016/`; M1 native proof remains in `m1-close-20261016/` on its delivery worktree.
- **M1 rendering evidence:** native creation and deletion ran with Metal API and shader validation and no logged errors. A separate five-frame GPU capture records pipelines, bindings, and residency calls. Its replay image has missing surfaces compared with the live view; the cause is unresolved, so the replay image is not visual proof.
- **Toolchain:** Xcode 27.1 release, build 27A9275, Swift 6.4, macOS 27.0.1. The Metal component is installed. The deployment floor remains macOS and iOS 26.

## Milestones

| # | Milestone | Exit (all must hold) |
|---|---|---|
| M0 | **Reset** ✅ | Core docs rewritten. Old docs retired (preserved at tag `revival-docs-v1`). Skills updated for Xcode 27 release. Upstream and forks checked. |
| M1 | **Runtime foundation** ✅ | Training plays to completion as before, now through `GameWorld`, `ObjectTable`, Osiris dispatch, the DALLAS API, and `Scripts/Levels/TrainingMission.swift`. There are no `training*` fields or functions outside that script file and the Guide-Bot game-module script. Package schema 13. `GameSave` replaces continuation schema 7. Tests consolidated, with every file under 4,000 lines. Astra high milestone verification passes. |
| M2 | **Campaign systems** | Game tables imported. The full object frame (all movement and control types), all weapons, damage, powerups, inventory, countermeasures, player death and respawn, and difficulty. General robot AI (AIMain, AIGoal, paths, BOA, robot fire, ambient, AIGame robots). Doors, triggers, matcens, level goals, fuel centers, force fields. Sound through `AVAudioEngine` (3D, ambient, voice). Proof: Training's RASBot1 attacks and can kill the player, and the player respawns, all through general code. |
| M3 | **Outdoor and mission flow** | Terrain (simulation, collision, LOD renderer, sky, weather, AI on terrain). Mission sequence, level transitions, and ship carry-over. In-game cinematics and popup views. The DALLAS translator tool works. **Level 1 plays start to finish.** |
| M4 | **Presentation and shell** | Real HUD with retail fonts, gauges, cockpit, reticle, and the Guide-Bot menu. Main menu, pilots, options and controls, TelCom briefings, automap and markers. Movies (MVE converted by D3Import, played with AVFoundation). Music (the original region and OMF system). Save and load across levels. |
| M5 | **Base campaign** | Levels 2–17 and secret levels S1 and S2 play start to finish, bosses included, on all difficulty levels. |
| M6 | **Mercenary** | `AIGame3` and Merc 1–7 play start to finish. Confirm which game module Mercenary binds to. |
| M7 | **1.0 release (Mac)** | First-run import UX. Release build on the M4 at 1920×1080: 99th-percentile frame time ≤ 16.7 ms and no frame over 33 ms outside level load, in Training, the largest indoor level, and the largest outdoor level. Every level in the checklist is at `V`, with the executed playthrough results recorded. Every item in the `product.md` acceptance list is checked. Signed and notarized app. No open P1/P2 defects. |

M2 game-table fields stay in the existing concrete definition tables. Import each missing field with its consumer.

After 1.0: P1 iPhone/iPad, P2 creator suite, P3 multiplayer, P4 replay/demos, P5 enhanced graphics (see `product.md`).

At the start of every milestone: recheck the upstream and fork heads (`sources.md` section 1), and run a bounded GPT-6.1 Sol sweep of the legacy files the milestone touches, looking for missed callers and dependencies. At the end of every milestone: a Codex `gpt-6-astra` high verification of the exit criteria (`engineering.md` section 6), then tag `revival-mN` when the owner authorizes it.

## Next work: M2 campaign systems

First unit exit: the importer assigns texture identities in the legacy dependency-allocation order, preserves base and overlay precedence, and loads the resulting Training package through the canonical consumer. Focused tests fail before and pass after. The full suite and all three app builds pass before commit. No retail input enters product targets or Git.

- [x] **1. Source refresh and caller scan.** Recheck the three source heads and open work. Trace table allocation and import dependencies before changing the package shape.
- [x] **2. Table identities.** Replace texture table ordinals with the source allocation order. Keep the current concrete page types and canonical consumer.
- [x] **2a. Ship armor.** Preserve the retail ship armor scalar and apply it through the existing player-damage path. Change the required package schema with the data contract; reimport, with no compatibility decoder.
- [x] **2b. General non-animated robot fire.** Dispatch fire after movement for every eligible AI type. Verify unturreted sequential burst masks, ordinary projectile damage, and save/load continuation through session frames. No new package or save fields.
- [ ] **3. Full game tables.** Import the remaining page data required by general weapons, objects, ships, powerups, sound, and doors. Add each consumer with its data; do not build unused tables first.
- [ ] **4. General combat and object frame.** Complete movement/control, collision, robot fire, player death and respawn, inventory, and difficulty in source order.
- [ ] **5. World systems and audio.** Complete doors, triggers, matcens, goals, fuel centers, force fields, and sound.
- [ ] **6. M2 exit.** RASBot1 attacks and can kill the player, and the player respawns, through general code. Full suite, native proof, and Astra high exit verification pass.

## Completed M1 runtime foundation

Each step lands green: the build passes, Training is playable in RevivalMac, and quicksave/quickload still work. A behavior step adds a focused test first. A behavior-neutral move uses the existing suite as its guard. Each step deletes the bespoke Training code it replaces. The detailed design is in `architecture.md`, sections 2–7.

- [x] **1. Split oversized test files.** A behavior-neutral split of the four test files over 4,000 lines, done before they grow further. Fixtures go to helper files. Guard: the existing suite.
- [x] **1b. Green baseline.** Install the Metal Toolchain. Fix the pre-existing test failures, so every later step starts from a known-green suite.
- [x] **2. `GameWorld` + object table + save, in one slice.** Add `ObjectHandle`, `GameObject`, and `ObjectTable` (translated from `object.h:642` and `object.cpp:1605–1707`, LIFO free list, signature wrap). Move game time, frame duration, RNG, players, mutable room and portal state, the object table, **and the existing Training state structs** into `struct GameWorld` in the same change. Move **every** reader and writer of `level.objects` (for example `PlayerSimulationUpdate.swift:60` and `PlayerSimulation.swift:1634`) to the table at once. `PlayerSimulation` becomes `GameSession { var world }`. `GameSave` = Codable `GameWorld` plus the package fingerprint and pilot. It replaces continuation schema 7 and its `validTraining*Continuation` functions, so quicksave stays complete through every later step. Tests: allocation order, stale-handle rejection, and save round-trip then advance (`architecture.md` section 7).
- [x] **2b. Fixture defect (found in step 2).** A real concussion missile that kills robot 4112 in `makePlayerConcussionLevel()` crashed in `setPortalRenderFaces` (`GameWorld.swift:129`) when `openTrainingGalleryBarrier` ran. Cause: `makeTrainingGuidebotYellowFlareLevel()` rebuilt room 1 with no portals, so room 2 portal 0 had no reciprocal. `Level.validate()` already rejects this (`invalidPortal`), and every package load validates, so it was a fixture bug only. The fixture now keeps room 1 and adds the shell.
- [x] **3. Generic script data in the package (additive).** D3Import adds the level script name, object script names and custom data, the `.msg` string table, and canonical sound and voice keys (package schema 12). The old Training fields stay until their steps below delete them. Test: the synthetic D3L produces these fields.
- [x] **4. Osiris dispatch, timers, level start.** Add `ScriptEvent`, `ObjectScripts`, the `continueChain` and `continueDefault` results, `callObjectEvent`/`callLevelEvent`/`callTriggerEvent`, and `OsirisTimers`. Add `LevelModule.trainingMission` with `EVT_LEVELSTART` (Script 000) and timer 0 (Script 002). Add the DALLAS functions those need (`aObjHide`, `aSetLevelTimer`, `aShowHUDMessage`, `aSoundPlaySteamingText`, `aToggle*PlayerControl`, `aObjSetLighting*`, `aAISetState`). Test: at 0.1 s frames, the 1.0 s timer fires on the 11th frame; then "Welcome", `welcome.osf`, and "GoForward", in that order (`TrainingMission.cpp:1506-1508`). Open for later steps: the Guide-Bot HUD token (step 8), the dying-player timer detonator (step 7), and readers of the new object lighting, AI power, and player invulnerability state (steps 5-7).
- [x] **5. Opening and return lessons** (Scripts 001–015, 030, 033). Goal contacts become `EVT_COLLIDE` from `Collide.swift`. Delete `TrainingOpeningLesson` and its validators and import adder.
- [x] **6. Dodge and maneuver** (Scripts 016–026). Object pages, AI frames, the follow-path goal, turret fire, and weapon objects. Delete the bespoke dodge and maneuver types.
- [x] **7. Weapon → damage → death.** `WeaponFire` and `Damage` apply shields. Shields below 0 go through `KillObject` → dead flag → `ObjDeleteDead`. Keep its order (`object.cpp:2004`): inform goals, remove inventory, send `EVT_CHILD_DIED`, then `EVT_DESTROY`. Custom handlers replace the robot and destroy chains (Scripts 028, 029, 036, 043–046, 051–055). Delete the 10 `destroyTraining*` methods and the 9 death-chain types. The goal and inventory steps of `ObjDeleteDead` move to step 9, and player death to M2 (`architecture.md` section 9).
- [x] **8. Guide-Bot as the `AIGame` default script.** Translate `AIGame.cpp:4517–6855` onto `AIGoal`, `BOA`, and `WeaponFire`. Keep the accepted route correction (`architecture.md` section 9). Event routes follow the C++: Script 032 is a trigger `EVT_COLLIDE` (`TrainingMission.cpp:2325`). Script 060 runs in the level `EVT_INTERVAL` (`TrainingMission.cpp:1431`). F4 opens the Buddy (Guide-Bot) menu (`GameLoop.cpp:1493`), whose exit command sends the Guide-Bot `EVT_USE` (`AIGame.cpp:5243`). Delete `TrainingGuidebotSimulation.swift`.
  - [x] **8a. Generic AI goal, path and route layer.** `GoalAddGoal`/`GoalDoFrame`/`GoalPathComplete`/enablers (`AIGoal.cpp`), dynamic paths (`aipath.cpp:977`), generic `BOA.swift` room route (the accepted route difference now lives here), avoid-friends and orientation cases, notify payloads.
  - [x] **8b. GuideBot class.** `Scripts/DefaultScript.swift`, `AIGame.swift`, `AIGame+GuideBot.swift` (DoInit, SetMode/SubMode, the 2.5 s DoMessage gate, commands, collide, use, notify, frame); the Osiris/multisafe calls it needs; `AIInitAll` taking over the Guide-Bot object (`AImain.cpp:3833`); import `aigame.str`, the GBot sounds, and the Yellow flare and spark weapons.
  - [x] **8c. Buddy menu and Guide-Bot scripts.** Core buddy menu state and the F4 AppKit list (with rename); generic player trigger collide; Scripts 032, 058 and 060 in `TrainingMission.swift` (settle the Script 058/059 Camera Monitor seam with step 9).
  - [x] **8d. Generic flares and deletion.** Flares as weapon objects (particles, timeout spawn, sticking, flicker light, `FireFlareFromPlayer`); delete `TrainingGuidebotSimulation.swift`, the bespoke flare state, and their fields, validators, adders, diagnostics and presentation paths; migrate the Guide-Bot and flare tests.
- [x] **9. Camera Monitor, pickups, last room, final goal** (Scripts 037–042, 047–050, 056–059). The Camera Monitor `EVT_USE` handler, `CustomObjectScript_1817`, plays the voice, shows the message and popup, and increments `ScriptActionCtr_059`. `Inventory` (use removes the item only when the script returns `continueDefault`, `Inventory.cpp:819`), the powerup path (`multisafe.cpp:2467`), `aCreatePopupView`, `aEndLevel`, and level goals. Delete the remaining chain types.
- [x] **10. Import cleanup.** Delete the Training-specific package fields and import code, and split `runD3Import` by stage.
- [x] **11. Test consolidation.** Per-API-family unit tests on synthetic worlds, one `TrainingMissionScriptTests` that drives events into a synthetic level, and one retail-gated playthrough trace using a single `REVIVAL_TRAINING_PACKAGE` variable. The consolidated suite has about 30.9k test lines, with every file under 4,000. The earlier 8k estimate did not fit the required behavior coverage. Replace GameSave's NestedStateSweep (field-name convention) with typed validation once the Training state structs are gone. Move every synthetic package fixture to schema 13 (with level script data) and delete `CanonicalPackageSchemaPolicy.includingScriptFreeTestSchemas`, a temporary test-only option added in step 10 (engineering §8 forbids test-only flags in production code).
- [x] **11b. Typed save validation.** Replace GameSave's `NestedStateSweep` (field-name convention) with typed validation of each state family, now that the Training state structs are gone (left open by step 11).
- [x] **12. Editor and mobile still compile.** Remove the Training-specific editor edits (the barrier edit, FollowLoop1 node orientation) or re-home them on generic objects and paths. RevivalMobile builds.
- [x] **12b. Models for runtime-created objects.** Objects made after level start (death spew, dead models, game-module objects such as the Guide-Bot's helpers) get their page models packaged and drawn. D3Import reaches every model a reachable page can create (spew, dead model, timeout spawn, game-module `ObjCreate`). Fix the OOF parser rejecting `securityturretdeadmodel.OOF` (a turret submodel with no rotation keyframes; follow the legacy polymodel loader). The obsolete §9 limitation is removed. Real import also required the legacy unversioned OAF header used by `shield.oaf`.
- [x] **12c. Correct native camera and auto-level behavior.** Match `renderer/HardwarePoints.cpp` and the player orientation in the CPU projection, Metal view matrix, and camera-facing billboards. Native flight also exposed the missing recent-weapon-fire check in pitch auto-leveling (`physics.cpp:498–507`). The camera geometry and recent-fire gameplay regressions failed before their fixes and passed after. The corrected horizontal view was observed in native flight. Sustained recent-fire suppression is verified by the gameplay regression; the native tool sends short clicks.
- [x] **13. M1 verification.** Play Training in RevivalMac from a fresh import, and check each Training checkpoint below. Full suite green. Astra high verification of the M1 exit criteria. Tag `revival-m1` when the owner authorizes it.

**Training checkpoints** (M1 verification and later regressions): the welcome lesson and controls lessons (Scripts 000–015); the timed dodge; the maneuver and follow-bot (016–026); DestroyBot1 and DestroyBot2 (028, 029, 036); Portal2 and Guide-Bot release (032); the Guide-Bot goal command and return to ship; Camera Monitor use (059); the invulnerability and cloak pickups (047, 048); RASBot1–4 and LastBot1–5 deaths; the final bots and final goal (035, 056, 057); level end with the success result; quicksave and quickload mid-level.

The original net-line estimate is retired. Use the final diff and file-size check to measure the completed migration.

## Level checklist (1.0)

Status: `—` not started, `S` script translated, `P` plays start to finish, `V` verified (full playthrough plus Codex verification).

| Level | Legacy script | Status | Notes |
|---|---|---|---|
| Pilot Training | `TrainingMission.cpp` | V | Native playthrough completed with the success result and saved pilot progress. Astra high granted the M1 exit pass. |
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
