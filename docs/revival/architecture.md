# Architecture

Status: core design. Updated 2026-09-29. It replaces the old `architecture.md`, `world-loading.md`, `behavior-system.md`, `content-pipeline.md`, `creator-suite.md`, and `adaptive-music.md`.

Legacy line numbers refer to the pinned source `156cba8a`.

## 1. Modules

| Module (source dir) | Owns | Must not |
|---|---|---|
| **D3Import** | Reading every retail format. Writing the canonical package. | Be linked into a player app. |
| **RevivalCore** | Canonical content types, `GameWorld` (all mutable game state), the object table, frame loop, physics, AI, weapons, the Osiris/DALLAS script API, level scripts, saves. | Import AppKit, UIKit, Metal, AVFoundation, or retail formats. |
| **RevivalMetal** | The one Metal 4 renderer and MSL shaders. It draws values that Core extracts. | Hold game state. Have a second backend. |
| **RevivalAppKit / RevivalMac** | Window, `MTKView`, display loop, input sampling, `AVAudioEngine` audio, movies, menus, HUD view, file locations, first-run import UX. | Contain game rules. |
| **RevivalMobile** | UIKit shell (post-1.0 feature work, but kept compiling). | Read retail data. |
| **RevivalEditor** | NSDocument creator tool (post-1.0 feature work, but kept compiling). | Have its own renderer or loader. |

Each module is currently a source folder compiled into the app targets. Split one out into a real build target only if measured build time needs it. The likely first split is `RevivalScripts` for the level scripts.

## 2. Runtime owners

```
Level (immutable, canonical)  ─┐
GameTables (immutable pages)  ─┼─►  GameWorld (struct, all mutable state, Codable = save)
                               │        objects: ObjectTable   players   rooms (mutable parts)
                               │        timers   goals   matcens   visEffects   levelModule   rng   clock
GameSession (class, per app) ──┘   owns `var world`, wall clock, pause depth, input queue, presentation queue
```

- **`GameWorld`** is a struct mutated only through `mutating` methods on one `inout` path. A Codable snapshot of it **is** the save file. An editor play-test copies it later, which costs nothing because it is a value.
- **`GameSession`** replaces the old `PlayerSimulation` class. It holds only non-authoritative wall-clock, pause, and presentation state.
- **`Level`** holds initial placement and geometry only. Runtime objects live in the `ObjectTable`, never in `level.objects`.
- **`GameTables`** are the imported pages: objinfo (generic), robot, weapon, ship, powerup, sound, door, and texture.

## 3. Object table (translated from `object.h` and `object.cpp`)

- 1,500 slots (`MAX_OBJECTS`). Keep the legacy **last-freed-first-reused** free list and allocation (`object.cpp:1605–1639`). Iterate in ascending slot order. Guide-Bot evidence already depends on exact slot numbers.
- `ObjectHandle` is the slot plus a signature (`object.h:642–644`), with the handle count and wrap from `object.cpp:1704–1707`. `world.objects[handle]` checks the signature, so a stale handle returns `nil` (as `ObjGet`, `object.cpp:3231`).
- `GameObject` translates `object_external_struct.h:401`: type, id, flags, name, room or terrain cell, position, orientation, size, shields, lifeleft, parent, attach, movement info, control info, AI frame, effects, weapon batteries, polymodel state, and scripts. C unions become enums with associated values. Multiplayer-only fields are dropped until P3.

## 4. Frame order (`GameLoop.cpp` `GameFrame`, :2869)

`GameWorld.gameFrame(controls:)` runs once per frame in this order. Rendering is outside the world, except for step 13.

1. `ProcessKeys` and `ProcessButtons` (:2956) → apply the input snapshot.
2. `AIFrameAll` (:2964 → `AImain.cpp:6211`).
3. `ObjDoFrameAll` (:2973 → `object.cpp:2926`). See the per-object order below.
4. `DoMatcensFrame` (:2977).
5. `Level_goals.DoFrame` (:2982).
6. `DoorwayDoFrame` (:2987).
7. `DoPlayerFrame` (:2992).
8. Weather, ambient sounds, and terrain sound (:2997–3006). These emit sound requests.
9. Level `EVT_INTERVAL` (:3013).
10. `Osiris_ProcessTimers` (:3014).
11. `Cinematic_Frame` (:3017).
12. `GameProcessMusic` (:3025). This runs even when paused.
13. Render (:3051). **The render pass feeds AI**: it produces `AI_RenderedList` and `OF_RENDERED`. So the room/portal visibility pass runs in Core, and Metal consumes its result.
14. `ProcessNormalEvents` (:3059).
15. `CalcFrameTime`, then `Gametime += Frametime` (:3087–3090). See the timing contract.
16. Destroyed lights and LOD reset (:3095–3098).

**Per object** (`ObjDoFrame`, ascending slots): lifeleft decrement → control (AI, weapon, explosion, debris, dying) → animation → lifeleft timeout and dead flag → movement (physics, then `ObjCheckTriggers`) → effects → special player work (fuel, secret, room damage) → object `EVT_INTERVAL` → object light. After the loop: physics-linked objects → `VisEffectMoveAll` → `ObjDeleteDead`. For each dead object, `ObjDeleteDead` (`object.cpp:2004`) informs level goals, removes inventory, sends `EVT_CHILD_DIED` to the parent, and **then** sends `EVT_DESTROY`. Keep that order.

## 5. Timing contract (ratified; keep)

One explicit variable-delta scheduler. No fixed-step mode.

1. Frame systems and `EVT_INTERVAL` get the **previous** `Frametime` and the **pre-update** `Gametime`.
2. The frame-cap wait happens first. Then `CalcFrameTime` stores the **new** duration, and `Gametime` advances **before** the tail work.
3. The initial `Frametime` is 0.1 s at static/`InitGame` time only, so a 1-second timer fires on the 11th frame.
4. Pause, focus loss, and suspension rebase the clock with no catch-up.
5. The display timestamp is sampled after the renderer admits the frame and before simulation.

**RNG:** one authoritative stream, `state = state &* 214013 &+ 2531011`, stored in `GameWorld`. All translated code draws from it in source order, including the presentation sparks that the original also took from it.

## 6. Scripts (Osiris and DALLAS)

### Legacy shape

- Each level has a script module (`scripts/<Level>.cpp`). Most of it is generated by the DALLAS editor, plus hand-written custom blocks. It calls three API layers: `DallasFuncs.cpp` (~230 `aXxx` actions and `qXxx` queries), which calls `osiris_predefs.cpp` (108 `osipf_*` functions) and `multisafe.cpp` (132 `MSAFE_*` ops).
- The game module (`AIGame.cpp`, `AIGame3.cpp`, `generic.cpp`, `clutter.cpp`) provides default per-object scripts: Guide-Bot, thief, and robot behaviors.
- Scope for 1.0: 27 level scripts with ~117,500 executable C++ lines and ~2,800 DALLAS scripts, plus 26,553 lines of game module. Training uses 31 distinct DALLAS functions. The campaigns use 243.

### Native shape

- **Engine API:** `extension GameWorld` methods translated from `osiris_predefs.cpp` and `multisafe.cpp`, with plain domain names (for example `setPortalRender(room:portal:state:doubleSided:)`). The `MSAFE_*` opcode multiplexing becomes named methods.
- **DALLAS API:** `extension GameWorld` methods that **keep the DALLAS names** (`aObjGhostSet`, `qObjShields`, and so on), so each translation can be diffed line by line against the C++. The `dfInit`/`dfSave` state becomes `struct DallasState: Codable`, held in each level module's state (each module DLL had its own copy). Actions that the app presents (HUD messages, streamed sounds) append to `GameWorld.presentationRequests`. `GameSession` moves them into the frame's presentation list before the update returns, so a save never holds any.
- **Level scripts:** a closed, compiled-in set:
  `enum LevelModule: Codable { case none, trainingMission(TrainingMissionState), level1(Level1State), … }`, with `switch` dispatch. Every script is known at compile time. Codable gives the save for free. There is no protocol, registry, or dynamic loading.
- **Game-module scripts:** `enum DefaultScript: Codable { case guideBot(GuideBotState), … }`, stored on the object. This replaces Osiris instance memory.
- **Files:** `RevivalCore/Scripts/Levels/<LegacyName>.swift`, one per legacy script. A large script splits by legacy class range (`Merc3.swift`, `Merc3+Custom.swift`), each file ≤ 4,000 lines. Each file starts with its legacy source path and a GPL notice.
- **Level-specific code lives only in these files.** Generic systems never name a level, a script, or a named object. The one exception is the `LevelModule` and `DefaultScript` case lists and their dispatch `switch` (in `Scripts/LevelModule.swift` and `Scripts/DefaultScript.swift`). They may name each script, but they contain no behavior.

### Dispatch (translated from `Osiris_CallEvent`, `OsirisLoadandBind.cpp:2111`)

- Object events go to the slots in this order: custom (level module, per object) → level (by page name) → mission → default (game module). `ObjectScripts` holds the custom and level slots now. The default slot joins with the `AIGame` scripts (M1 step 8). No mission module exists yet. Each slot stops the chain unless it returns `continueChain`. A separate `continueDefault` result (`OsirisLoadandBind.cpp:2251`) tells the engine whether to run its own default action. For example, inventory use removes the item only when the script returns `continueDefault` (`Inventory.cpp:819`). Carry both flags.
- An `EVT_AI_NOTIFY` first sends the derived `EVT_AIN_*` sub-event to the same slot.
- Level events go to the one level module. Trigger events go to the trigger scripts. An `EVT_AI_NOTIFY` to a level or trigger script sends the event first and then the goal child event, whose result wins (`OsirisLoadandBind.cpp:1988`).
- A module resolves its names (`Object_handles`, `Message_strings`) from the immutable `Level` at each use. That gives the values `InitializeDLL` resolved once, and keeps them out of the save.
- Level start (`GameWorld.init`): reset the timers, load the module, send `EVT_LEVELSTART`, then bind every object in slot order and send `EVT_AI_INIT` (AI objects) and `EVT_CREATED` (`gamesequence.cpp:1584-1600`, `Mission.cpp:1687`, `ObjScript.cpp:164`). A restored save does none of this.
- The level `EVT_INTERVAL` goes out after `DoPlayerFrame` with the previous `Frametime` and the pre-update `Gametime` (`GameLoop.cpp:3013`).
- An object hit by a move gets `EVT_COLLIDE` from `collide_two_objects`: first the mover (it = the other object), then the other object. The move hits a powerup only while it closes on it, as `check_vector_to_sphere_1` does; a player at rest hits nothing, and the wiggle move ignores powerups (`physics.cpp:796`). Each hit is the nearest of the walls and the objects: the player stops at it, `collide_two_objects` runs, the powerup goes on the frame's ignore list, and the rest of the move is traced again against the current portal flags, so a portal a script changes in the callback takes effect in the same move (`physics.cpp:1503-1560`). A powerup hit does not use up one of the loop's iterations (`count--`, `:1556`). A mover with `OF_NO_OBJECT_COLLISIONS` checks no objects (`:1012`).
- Timers are a Codable array. Their semantics come from `Osiris_CreateTimer`, `Osiris_ProcessTimers`, and `Osiris_CancelTimer`, including `EVT_TIMERCANCEL` on object death. They run after the level `EVT_INTERVAL` with the pre-update `Gametime`. The dying-player detonator check arrives with player death (M1 step 7).
- Save/restore events are dropped, because Codable replaces them.

The event producers to reach, with their sites: collide (`collide.cpp:2493`; reached in `Collide.swift` for the player's physics move and powerups, the pair whose response is the script alone, `collide.cpp:2519`), damaged (`damage.cpp:1342`), destroy (`object.cpp:2040`), created and AI-init (`ObjScript.cpp:206`), AI-notify (`AImain.cpp:2992–3264`), AI-frame (`AImain.cpp:5528`), use (`Inventory.cpp:819`), change-seg (`object.cpp:3163`), doors (`doorway.cpp:293/474`), matcen (`matcen.cpp:439`), goals (`levelgoal.cpp:195/1134/1274`), player dies and respawn (`damage.cpp:770`, `Player.cpp:2472`), movies (`gamecinematics.cpp`), level start and end (`Mission.cpp:1696/1706`), and timers.

**Reentrancy rule:** scripts re-enter the engine and each other synchronously (`osipf_CallObjectEvent`, and the timer and destroy paths). Handlers are `static func (event, inout GameWorld, Level) -> ChainFlags`; the `Level` is immutable content. Read module state from the world each time. Never hold a local copy across an action call, because Swift exclusivity forbids it and the C++ always saw the latest value.

### Translation volume

A disposable, non-shipping **DALLAS translator** may convert the generated action blocks into Swift source that is reviewed and committed. It is a dev tool under `tools/`, is never linked into a product, and is deleted once the campaign scripts are done. Hand-written custom blocks are translated by hand.

## 7. Content package, saves, and audio state

- Format and rules: see the `d3-content-import` skill. It is deterministic JSON plus Apple-readable media. Each level is complete.
- Current package schema: **12**. It adds `Level.scripting`: the level script name (the lowercased level file stem, `OsirisLoadandBind.cpp:893`), one binding per scriptable object (name, default module as a lowercased stem, default page name, `OsirisLoadandBind.cpp:1427`), the `.msg` table, and the stream and sound names the compiled level script lists, mapped to canonical clip keys. It also adds two optional object tables (`ObjectInfo.swift`, read by `D3Import/GenericPage.swift`): `objectInfos`, one `object_info` per generic page a placed object uses (size, hit points, light, the full `t_ai_info`, and weapon batteries; `ObjInit`, `objinit.cpp:807`), and `weapons`, the weapons those batteries fire (`weaponpage.cpp`). Models gain their gun points and weapon batteries (the `GPNT` and `WBAT` chunks). A placed object gets its page by definition name at level load. Schema 11 packages still load, with no script data, until M1 step 10 deletes the Training-specific fields added in schemas 7–11. Game tables and model and texture keys come later.
- Other schemas today: `GameSave` 2 (a Codable `GameWorld` plus the package reference and the pilot; it replaced player save 1 and continuation 7 in M1 step 2), pilot profile 1, package record 1, creator project 4.
- During development the only migration is reimport. Pre-M1 quicksaves stop loading after M1, which is acceptable because nothing has shipped.

### Saves

- `GameSave` = Codable `GameWorld` plus the package fingerprint and the pilot. It holds only logical state: no Metal, audio, or AppKit objects, no audio buffers, and no playback positions.
- Load validates structure once: slots and handles are consistent, room, path, and object references are in range, and floats are finite. A package fingerprint mismatch is refused with a diagnostic.
- **Continuation contract.** A world saved at frame N, loaded, and advanced with the same inputs must match the uninterrupted world at every later frame. Test this for each state family you add (objects, AI, scripts, timers, RNG, inventory, and so on).
- **Durable write.** Write to a temporary file in the same folder, then atomically replace. An interrupted write leaves the previous save readable.
- Save slots, names, and thumbnails are M4 work. Quicksave and quickload use a fixed per-pilot slot until then.

### Audio and music ownership

- Core emits **sound requests** (play, stop, 3D position, volume, looping, priority) and holds the **logical music state**: the current region, the pending transition, and the theme, as in `d3music.cpp` and `music/`. That logical state is part of `GameWorld` and the save.
- RevivalMac owns the `AVAudioEngine` graph, the buffers, streaming, and playback positions. None of these are saved. On load, the music restarts from the saved logical region.
- The sound bump and rate-limit corrections in `sources.md` apply in the request layer.

## 8. Level load and lifetime

- The load unit is one complete level, as in the original. The whole level stays resident. There is no streaming, cells, or LRU.
- Eager working set = the `PageInAllData` set (ship, static effects and sounds, room textures, terrain, placed-object dependencies). Later-reached assets load from canonical content and stay until level exit.
- Replacement: validate the new content on the CPU → stop submissions → wait for the last GPU use → release the old world → build the new `GameWorld` → prepare Metal resources → activate. A failure before release keeps the old world. A failure after it leaves an explicit "unloaded" error.
- Visibility: indoor uses the translated room/portal traversal and clipping. Outdoor uses the translated terrain geometry LOD, texture-segment selection, and UV/tile/rotation. Megacells are editor data, not a runtime LOD.

## 9. Intentional differences from the original

| Area | Original | Revival | Why |
|---|---|---|---|
| Content | Reads HOG/D3L at runtime and pages lazily | Canonical package, dependencies resolved at import | One-way importer; runtime has no retail readers |
| Saves | Binary `SaveGameState` plus script save events | Codable `GameWorld`, validated structurally at load, written atomically | Simpler; the old engine trusted its saves |
| Opacity | Byte-truncated | `Float` | No visible loss |
| Renderer | OpenGL/Direct3D immediate mode | Retained Metal 4 renderer, same visual contract | Platform |
| HUD text (pre-M4) | Font-based colored text | Green monospaced text (red when low) | Temporary until the HUD port in M4 |
| F1 help (pre-M4) | Help screen | Native alert listing the implemented controls | Temporary until the menus port in M4 |
| AI dynamic paths (Guide-Bot route) | `AIPathAllocPath` builds its nodes from the BNode lists (`AIGenerateBNodePath`, `AIGenerateAltBNodePath`); the straight-line and path-update probes check walls and objects | The room route, the no-route check, and the alternate-path decision (too small, blockage, locked door, closed portal, then `AIFindAltPath` with its draws) follow the BOA tables (`BOATables.swift`, `AIPath.swift`). Only the node geometry differs: a cross-room or alternate path goes through each portal's path point, a blocked same-room path follows the verified boundary nodes, and the probes trace walls only; a blocked same-room allocation takes the route, not the `AISR_SEES_GOAL` shortcut | Accepted correction |
| BOA tables | `MakeBOA` remakes the tables at load when the stored mine checksum does not match (`BOA.cpp:2029`); the stored tables are trusted | D3Import stores the CBOA tables when `BOAGetMineChecksum` matches (retail Training does); a loaded table must also end every next-room chain within the room count. Otherwise `MakeBOA` runs at load (`BOATables+Make.swift`), and on retail Training it remakes the stored tables exactly. It leaves out the mine and terrain-region passes (their rows serve outdoor routes, M3), and `IsPathPointValid` traces the room's faces only. A FindPath step through a portal with no passable way back is skipped (the original reads `BOA_cost_array[next][-1]`, undefined; `AIFindAltPath` skips it too), and a loaded cost must be -1 or a distance | Terrain arrives in M3; full `fvi` in M2; the original's read is undefined |
| Fixes | Known bugs | Corrections listed in `sources.md` | Adopted fork fixes |
| Save range | Binary save of float `Gametime` with no range check | A save is rejected when any saved value exceeds ±1e6 (about 11.6 days of game time) | Float32 time loses sub-frame precision near 1e6 s in both versions; the bound keeps untrusted saves from crashing the game |
| Handle wrap | `ObjCreate` hits a debug break (`Int3`) when a slot's handle count is about to wrap (`object.cpp:1707`), then wraps | The count skips 0 on wrap, so a wrapped handle is never mistaken for an old one | Unreachable in practice (about 2 million reuses of one slot); avoids a stale-handle alias |
| AI visibility (pre-M2) | `BOA_IsVisible` reads the cached BOA tables | Two rooms see each other when they are in the same reciprocal-portal component | BOA arrives with general AI in M2 |
| AI turning | `AITurnTowardsDir` passes an unset up axis to `vm_DeltaAngVecNorm` (`AImain.cpp:2130`) | The turn is about the axis at right angles to the forward vector and the goal direction | The C++ value is undefined |
| AI scope (pre-M2) | Every AI type fires; every goal type, enabler, and avoidance moves the object | Every enabled AI object runs its memory, target, vision, register, goal, and movement steps (with their `ps_rand` draws); only stationary turrets fire. The goal types are follow-path, get-to-object, get-to-position, guard-area, move-relative-object(-vector), and get-around-object; `AIF_AVOID_WALLS` is not applied; auto-avoid-friends takes its near list (players and AI objects, at most 10) from the object's room and then the rooms it sees, by box overlap, not the room object lists and portal boxes; the emotion enablers (`AIE_FEAR`...) are refused; `AIInit`'s `GoalInitTypeGoals` gives the Evader types' goals, and for Stalker and Melee1 only clears the goals | The other goal types, wall avoidance, `AIDoFreud`, and firing arrive with the rest of `ai_move` in M2 |
| AI render list | `AI_RenderedList` comes from the frame the renderer draws, at the window's aspect ratio (`renderobject.cpp:1239`) | Core runs the same room, portal, and object admission for the player view with the default projection | The Metal view's aspect ratio stays outside Core; only objects at the side edges can differ |
| Polygon collision pose | `PolyCollideObject` uses the keyframe angles `SetModelAnglesAndPos` sets and the rotator and turret angles the last render left, and skips `SOF_SHELL`/`SOF_FRONTFACE` submodels and fly-through textures | The model's rest pose, with every textured face | The package does not carry those flags or poses yet; only doors, see-through textures, and animated models use them |
| Difficulty (pre-M4) | `DIFF_LEVEL` from the pilot's choice | Fixed at Rookie (`Difficulty.swift`) | The options menu arrives in M4 |
| Death effects (pre-M2) | `DestroyObject`, `DoDyingFrame`, and their debris, splinters, rings, spew, and delayed explosions are drawn and heard | All their objects, visual effects, events, and `ps_rand` draws happen in source order; only drawing them and their sounds, flash, and shake are deferred. Debris smoke uses the C library's `rand()`, so its puffs are not made. That takes no `ps_rand` draw directly, but a puff holds a visual-effect slot, so near the list's capacity it can change which later effects are made and therefore which conditional draws follow | The fireball, debris, and static sound presentation arrives in M2 |
| Death details (pre-M2) | `DSF_ONLY_IF_PLAYER_HAS_OBJ_1` checks the ship's spew powerups; `CreateDeadObject` sets the dead model on the ground (`ground_slots`); a falling object turns with its rotational drag; placed generic objects move by their page physics | The first check is skipped (no Training page sets it); the dead object takes the robot's position; only fixed-rate rotation turns an object; only objects made at run time use page physics | Ship spew powerups, model ground slots, and the full object movement arrive in M2 |
| Player death (pre-M2) | `InitiatePlayerDeath`, then `DoNewPlayerDeathFrame` each frame (death camera, breakup, smoke, `PlayerShipExplode` with its spew), `PLAYER_FLAGS_DEAD`, and `EndPlayerDeath` on a key press | The logical death runs: `EVT_PLAYER_DIES`, `PLAYER_FLAGS_DYING`, firing cleared, the death counted, the fate chosen with its draw, controls off, more damage refused, and dying-player detonators cancelled. The dying frames, explosion, death camera, and respawn do not run, so the player stays dying | The death sequence and respawn are M2; no Training script reacts to a death |
| `ObjDeleteDead` (pre-step 9) | Informs level goals (`OF_INFORM_DESTROY_TO_LG`) and removes inventory objects (`OF_INPLAYERINVENTORY`) before `EVT_CHILD_DIED` and `EVT_DESTROY` | Those two steps do not run yet | Level goals and inventory arrive in M1 step 9; no object sets those flags before then |
| Weapon flight (pre-M2) | Homing, gravity, thrust, bounces off ordinary walls, sticking, spawning, weapon-to-weapon hits, volatile and lava surfaces, and model spin | Fixed-velocity and drag flight, wall and object hits, and energy weapons bouncing off force fields (the bounce sound is a static sound, M2) | The rest of the physics arrives in M2 |
| Concussive force (pre-M2) | Pushes every physics object. A polygon object's distance uses the model's `wall_size` and `wall_sphere_offset`. Each object's own `PF_IGNORE_*` flags apply | Pushes only the player. The distance uses the object size. The ignore flags are read for weapons only | Robot physics and model wall spheres are not imported yet |
| Render events | Render events (a blast ring's flash, the damage effect) share the `MAX_EVENTS` slots with normal events | Only normal events are kept | They are presentation; 500 slots are never full in Training |
| `EVT_DAMAGED` | A script can change the damage in the event data | The damage is passed by value | No translated script changes it |
| Weapon explosion images | Every weapon page's explosion image | Only the images of weapons with imported explosion frames (the Concussion); other custom explosions exist but draw nothing | The other explosion textures are imported with the weapon tables in M2 |
| C library `rand()` state | If the released DLL shares the engine's C library, the engine's own `rand()` calls (debris smoke) interleave with the module's | The module's `rand()` has its own state (sources.md section 1); the engine's `rand()` users are not made | The engine's `rand()` users are presentation (debris smoke) |
| Guide-Bot searches (`AIFindAltPath`, reachability) | `AIFindAltPath` also crosses terrain regions; `BOA_LockedDoor` reads the live door and `Global_keys`; `AIGetNearbyObjs` walks the room object lists; `fvi` ray casts check objects too | `AIFindAltPath`, `BOA_ComputeMinDist`, and reachability are translated with their `ps_rand` draws, indoor only (an external room is skipped); a door keeps its level-start position and `Global_keys` is 0; object searches go in slot order; the Guide-Bot's ray casts check walls only | Terrain arrives in M3, doors and full `fvi` in M2 |
| Guide-Bot presentation (pre-M2/M4) | Colored `GB:` HUD text; animation frames; napalm and object effects; spark and lightning effects | HUD color codes are stripped; the animation frame reads 0; `Obj_IsEffect` reads false; the extinguish and lightning effects are not drawn | Object effects arrive in M2, the HUD in M4 |
| Robot-player contact (pre-M2) | `collide_two_objects` bumps both objects and sends `EVT_COLLIDE` to both | Either mover stops at the contact and both get `EVT_COLLIDE`; there is no bump | The full collision response arrives in M2 |
| 3D sound handles | `Play3dSound` returns a sound slot and unique id | A counter in `GameWorld.soundSystem`; only linked looping sounds are kept, as object loops the app plays | Playback belongs to RevivalMac |
| Guide-Bot object (pre-step 10) | `AIInitAll` makes the Guide-Bot object when a player exists | It takes over the imported Guide-Bot placed in Training, and moves it to the player | The Training-specific placement goes with the import cleanup in step 10 |
| Level goal list | `Level_goals` is filled at level load | The active goals are read from the level scripting when a Guide-Bot menu is built | Level goals arrive in step 9 |
| Buddy menu (pre-step 8c) | F4 builds the menu through `EVT_AI_NOTIFY`/`COM_GET_MENU` in the game UI | Core calls the Guide-Bot's `COM_GET_MENU` and `COM_DO_ACTION` directly; Training's release goes through a behavior-free bridge | The menu UI arrives in step 8c |
| Platform | Win32, SDL, DLL scripts, OpenGL | AppKit, UIKit, compiled Swift scripts, Metal | Apple-native |
