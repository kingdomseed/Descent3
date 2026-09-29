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
- **DALLAS API:** `extension GameWorld` methods that **keep the DALLAS names** (`aObjGhostSet`, `qObjShields`, and so on), so each translation can be diffed line by line against the C++. The `dfInit`/`dfSave` state becomes `struct DallasState: Codable`.
- **Level scripts:** a closed, compiled-in set:
  `enum LevelModule: Codable { case none, trainingMission(TrainingMissionState), level1(Level1State), … }`, with `switch` dispatch. Every script is known at compile time. Codable gives the save for free. There is no protocol, registry, or dynamic loading.
- **Game-module scripts:** `enum DefaultScript: Codable { case guideBot(GuideBotState), … }`, stored on the object. This replaces Osiris instance memory.
- **Files:** `RevivalCore/Scripts/Levels/<LegacyName>.swift`, one per legacy script. A large script splits by legacy class range (`Merc3.swift`, `Merc3+Custom.swift`), each file ≤ 4,000 lines. Each file starts with its legacy source path and a GPL notice.
- **Level-specific code lives only in these files.** Generic systems never name a level, a script, or a named object. The one exception is the `LevelModule` and `DefaultScript` case lists and their dispatch `switch` (in `Scripts/LevelModule.swift` and `Scripts/DefaultScript.swift`). They may name each script, but they contain no behavior.

### Dispatch (translated from `Osiris_CallEvent`, `OsirisLoadandBind.cpp:2111`)

- Object events go to the slots in this order: custom (level module, per object) → level (by page name) → mission → default (game module). Each slot stops the chain unless it returns `continueChain`. A separate `continueDefault` result (`OsirisLoadandBind.cpp:2251`) tells the engine whether to run its own default action. For example, inventory use removes the item only when the script returns `continueDefault` (`Inventory.cpp:819`). Carry both flags.
- An `EVT_AI_NOTIFY` first sends the derived `EVT_AIN_*` sub-event to the same slot.
- Level events go to the one level module. Trigger events go to the trigger scripts.
- Timers are a Codable array. Their semantics come from `Osiris_CreateTimer`, `Osiris_ProcessTimers`, and `Osiris_CancelTimer`, including `EVT_TIMERCANCEL` on object death.
- Save/restore events are dropped, because Codable replaces them.

The event producers to reach, with their sites: collide (`collide.cpp:2493`), damaged (`damage.cpp:1342`), destroy (`object.cpp:2040`), created and AI-init (`ObjScript.cpp:206`), AI-notify (`AImain.cpp:2992–3264`), AI-frame (`AImain.cpp:5528`), use (`Inventory.cpp:819`), change-seg (`object.cpp:3163`), doors (`doorway.cpp:293/474`), matcen (`matcen.cpp:439`), goals (`levelgoal.cpp:195/1134/1274`), player dies and respawn (`damage.cpp:770`, `Player.cpp:2472`), movies (`gamecinematics.cpp`), level start and end (`Mission.cpp:1696/1706`), and timers.

**Reentrancy rule:** scripts re-enter the engine and each other synchronously (`osipf_CallObjectEvent`, and the timer and destroy paths). Handlers are `static func (event, inout GameWorld)`. Read module state from the world each time. Never hold a local copy across an action call, because Swift exclusivity forbids it and the C++ always saw the latest value.

### Translation volume

A disposable, non-shipping **DALLAS translator** may convert the generated action blocks into Swift source that is reviewed and committed. It is a dev tool under `tools/`, is never linked into a product, and is deleted once the campaign scripts are done. Hand-written custom blocks are translated by hand.

## 7. Content package, saves, and audio state

- Format and rules: see the `d3-content-import` skill. It is deterministic JSON plus Apple-readable media. Each level is complete.
- Current package schema: **11**. The Training-specific fields added in schemas 7–11 are removed in M1, and the package moves to **schema 12** with generic data: game tables, script names, object script bindings, message tables, and canonical sound, model, and texture keys.
- Other schemas today: player save 1, continuation 7 (replaced by `GameSave` over `GameWorld` in M1), pilot profile 1, package record 1, creator project 4.
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
| Guide-Bot route | Cached CBOA/NODE tables | Route derived from reciprocal portals; a blocked same-room allocation takes the route, not the `AISR_SEES_GOAL` shortcut | Accepted correction |
| Fixes | Known bugs | Corrections listed in `sources.md` | Adopted fork fixes |
| Platform | Win32, SDL, DLL scripts, OpenGL | AppKit, UIKit, compiled Swift scripts, Metal | Apple-native |
