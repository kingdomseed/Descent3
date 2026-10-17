---
name: revival-source-translation
description: Translate a piece of the pinned Descent 3 C++ source into native Swift/MSL faithfully — trace the legacy code and its callers, apply known fork corrections, map files, and avoid the bespoke-per-case trap. Use before implementing any gameplay, engine, or script behavior.
---

# Revival source translation

Read first: `docs/revival/engineering.md` (sections 4 and 7), `docs/revival/sources.md`, `docs/revival/architecture.md`.

## The one lesson from the first attempt

The first port hand-built a bespoke Swift type for every Training script ("death chain 1–9", "opening lesson", and so on). It stored that behavior in the level schema, and wrote a validator and update function for each type. It worked for one level and could not scale to 27. **Translate the general mechanism the C++ uses, then express the specific case through it.** When you are about to add a type, field, or function named after one level, script number, or named object, stop: the general system is missing.

## Workflow for one work item

1. **Name the observable result.** For example: "RASBot1 fires red lasers every 2.4 s, then 3 × 0.2 s, and the player loses 6.75 shields per hit."
2. **Find the legacy entry point** and trace forward: callees, globals read and written, the frame-order position (`architecture.md` section 4), init and teardown, and save state.
3. **Trace callers backward** for the entry point and for any state it owns. Stop at shared helpers that cannot reach your result.
4. **Check the forks:** look in `sources.md` section 2, and `git log -p` in the fork clones for the files you touch. Adopt a correction directly. Do not reproduce the bug first.
5. **Pick native owners** from the file map in `architecture.md`, and `engineering.md` section 7. One Swift file per legacy file, keeping the legacy name. Level logic only in `Scripts/Levels/<Level>.swift`.
6. **Write the failing test**, then translate. Keep the order, formulas, Float32 behavior, and RNG draws in source order.
7. **Before commit, read your diff for:** level-specific names in generic code, placeholder returns, empty branches, `TODO`, disabled paths, reduced limits, or files over 4,000 lines.

A bounded GPT-6.1 Sol sweep of callers and dependencies (step 2 and step 3) is fine for large items. Record only real findings, in `plan.md` or a code comment. Do not start a ledger.

## Semantic hazards to check

- Evaluation order and Float32 operation order.
- Integer truncation, signedness, sentinel values (`-1`, `OBJECT_HANDLE_NONE`).
- Iteration order (ascending slots), and the LIFO object free list.
- Reentrancy: scripts call back into the engine mid-event (`architecture.md` section 6).
- Render-to-simulation feedback (`AI_RenderedList`, `OF_RENDERED`).
- Shared RNG draws, including presentation sparks.
- Frame-time handoff (previous `Frametime`, pre-update `Gametime`).

## Translate directly

- Replace platform mechanisms (Win32, MFC, SDL, OpenGL, DLL loading, `Osiris_AllocateMemory`, page locks, memory wrappers, compile variants) with Swift values and Apple frameworks.
- C unions become enums with associated values. Globals become `GameWorld` fields. `#define` flags become `OptionSet`s.
- Keep legacy names where they aid diffing: DALLAS `aXxx`/`qXxx` names, `ObjDoFrame`, and so on.
- For the DALLAS-generated action blocks, the disposable translator tool (`architecture.md` section 6) may emit Swift. Review every generated file like hand-written code.
- Cite the source at each translated type or function: `// object.cpp:1605 ObjAllocate` or `// 3MASTERED dbd611e4`.

## Workaround comments

When legacy code says "hack", "kludge", "temp", "fixme", or works around another subsystem, find what it works around. Then translate the intended behavior, and record the difference in `architecture.md` section 9.

## Done means

- The result works in RevivalMac from imported content, not only in a test.
- Tests cover the translated behavior, and the full suite passes.
- The bespoke code this replaces is deleted in the same change.
- Codex review is done (`engineering.md` section 6), and processes are cleaned up (`engineering.md` section 3).
