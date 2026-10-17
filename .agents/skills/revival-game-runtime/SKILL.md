---
name: revival-game-runtime
description: Build and extend the general Descent 3 game runtime in RevivalCore — GameWorld, the object table, the frame loop, Osiris event dispatch and timers, the DALLAS/osiris_predefs script API, level scripts, game-module scripts (AIGame Guide-Bot/robots), robot AI and navigation (AIMain, AIGoal, aipath, BOA, robotfire), weapons, damage, and saves. Use for any gameplay, AI, script, or level-behavior work.
---

# Revival game runtime

Read first: `docs/revival/architecture.md` (sections 2–6 are the design), `docs/revival/plan.md` (current step), and the `revival-source-translation` skill.

## Shape (do not deviate without updating `architecture.md`)

- `GameWorld` is a struct that holds **all** mutable game state. It is mutated through `mutating` methods, and it is Codable because it is the save file.
- `GameSession` (per app) owns `var world` plus wall clock, pause, and presentation queues.
- `ObjectTable` has 1,500 slots: a LIFO free list, `ObjectHandle` = slot + signature, and ascending iteration.
- `gameFrame(controls:)` follows `GameFrame` (`GameLoop.cpp:2869`) step by step. `objDoFrameAll()` follows `ObjDoFrame` (`object.cpp:2926`).
- Events: `ScriptEvent` enum. `callObjectEvent` goes to the custom → level → mission → default slots, with the `continueChain` and `continueDefault` results (`OsirisLoadandBind.cpp:2111`, `:2251`).
- Script API: `extension GameWorld` files. Engine functions come from `osiris_predefs.cpp` and `multisafe.cpp`, with domain names. DALLAS functions come from `DallasFuncs.cpp`, and **keep their names** (`aObjGhostSet`).
- Level scripts: `enum LevelModule` cases, one file per legacy script in `Scripts/Levels/`. Game-module scripts: `enum DefaultScript` cases on objects (`AIGame+GuideBot.swift`, and so on).

## Adding behavior

1. Find where the C++ does it. Is it in a level script, the game module (`AIGame*.cpp`), or the engine?
2. Put it in the matching Swift layer. **Never put level-specific logic in engine or AI code.** (The behavior-free `LevelModule`/`DefaultScript` case lists and dispatch switch are the only place outside `Scripts/Levels/` that names a script.) If a level script needs an engine capability, add the general DALLAS or predef function it calls, translated from the C++.
3. Add the missing event producer at its legacy call site (for example `EVT_DAMAGED` in `Damage.swift`, translated from `damage.cpp:1342`), not in the script.
4. Test at two levels:
   - **API tests** on a small synthetic `GameWorld`: "`aObjGhostSet(false, h)` clears `OF_GHOST` and the object renders".
   - **Script scenario tests**: drive events into a synthetic level, and assert the script's observable effects (timers, HUD messages, sounds, object state).
   A retail-gated playthrough trace covers real content.

## Reentrancy and exclusivity

Script handlers are `static func (ScriptEvent, inout GameWorld) -> ChainFlags`. The engine may re-enter scripts synchronously (`osipf_CallObjectEvent`, destroy, timers). **Read module state from `world` each time. Never keep a local copy across an engine call.** Do this: read into a local, call the action, then write back through `world`. Never hold `inout` access to `world.training` during a `world.aX(...)` call.

## AI and navigation

- The translation order is `AIFrameAll` → `AIDoFrame` → `AINotify` → `AIGoal` → `aipath` → `BOA` → `robotfire` → `aiambient` → the `AIGame` robot classes.
- AI visibility depends on the render visibility pass (`AI_RenderedList`, `OF_RENDERED`). Compute room/portal visibility in Core, and let Metal consume it. Do not create a second visibility truth.
- Keep the selection order, cost and clearance formulas, and the points where routes are recomputed. Navigation must agree with the translated collision code.
- Robot fire uses the corrected cadence from `sources.md` (`dbd611e4`).
- Accepted difference: the Guide-Bot route is derived from reciprocal portals, not cached CBOA/NODE tables (`architecture.md` section 9).

## RNG

All gameplay and presentation code that the original fed from `ps_rand` draws from `world.rng`, in source order. Adding or removing a draw changes every later result. Treat that as a behavior change, and test it.

## Saves

The save is `GameSave` = Codable `GameWorld` plus the package fingerprint and pilot. Load validates structure once: slots and handles are consistent, room, path, and object references are in range, and floats are finite. There are no per-script "continuation" validators. Each new state family needs a continuation test: save, load, advance with the same inputs, and match the uninterrupted run. Writes are atomic.

## Do not add

An ECS, event bus, script VM or bytecode, dynamic script loading, protocols for scripts, a component registry, actors or tasks per object, a second simulation path, or per-level fields on `Level` or `GameWorld`.

## Verify

Focused test red then green, the API and scenario tests, the full suite, and Training in RevivalMac (and later the affected level). Review by Codex (`engineering.md` section 6). Quit any app you launched.
