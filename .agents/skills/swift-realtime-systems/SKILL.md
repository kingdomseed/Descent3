---
name: swift-realtime-systems
description: Translate and implement Descent 3 frame timing, the game loop, simulation ownership, numeric fidelity, and hot data paths in direct Swift 6.4. Use for scheduler, physics, object update order, RNG, or performance work.
---

# Swift realtime systems

Read first: `docs/revival/architecture.md` (runtime, timing contract), `docs/revival/engineering.md`.

## Toolchain

- Swift 6.4 compiler in Swift 6 language mode (`SWIFT_VERSION = 6.0`), from Xcode 27.0 release. "Swift 6.4 language mode" is not a thing: the compiler version and the language mode are separate.
- Use 6.4 features only when they simplify a real contract:
  - `weak let` and `~Sendable` where they state an invariant.
  - Awaited cleanup in `defer`, and `withTaskCancellationShield`, only at import and editor async boundaries. Never in simulation.
  - `Span`, `InlineArray`, and `UniqueArray` only after a Release profile shows a hot path.
  - SE-0508 changed `init` accessors. Fix any source break directly.
- Swift Testing: XCTest and Swift Testing assertions now interoperate. Use `--repeat-until` to prove or disprove a flaky timing test.

## Translate the game loop faithfully

The primary spec is `Descent3/GameLoop.cpp` (`GameFrame`) and the systems it calls, in their order. Keep that order in the single simulation owner (`GameWorld`, see `architecture.md`).

Before code:
1. Name the result, and trace its legacy entry point, callers, call order, time reads, globals, and side effects.
2. Note only the numeric hazards actually present: evaluation order, Float32 order, truncation, signedness, sentinel values, iteration order, aliasing.
3. Write one failing test through the production step, then implement.

## Timing contract (ratified; keep)

One explicit variable-delta scheduler. No fixed-step mode, and no second mode.

1. Frame systems and `EVT_INTERVAL` receive the **previous** `Frametime` and the **pre-update** `Gametime`, passed explicitly.
2. The frame-cap wait happens at the source point.
3. `CalcFrameTime` stores the **new** duration after the wait.
4. `GameFrame` advances `Gametime` by the new duration **before** the remaining tail work.
5. The initial `Frametime` is 0.1 s at static/`InitGame` time only, not on every level reset.
6. Nested `StopTime`/`StartTime`, focus loss, and suspension rebase the monotonic clock. There is no catch-up delta.
7. The display timestamp is sampled after the renderer admits the frame (drawable ready) and before simulation. A rejected frame does not advance the simulation.

No system reads a mutable global time, input, or mode. Pass time and one `InputSnapshot` through the owner.

Weapon fire cadence uses the corrected rule in `sources.md` (inclusive readiness, overshoot kept only within one continuous burst). Check it against this timing contract.

## Random numbers

One authoritative simulation RNG: the released `state = state &* 214013 &+ 2531011` LCG. It is seeded by the simulation and saved with the game. Keep the original coupling between presentation and gameplay random calls unless `architecture.md` lists a difference.

## Numeric fidelity

- Use `Float` (Float32) where the original does. Convert platform `Double` durations at the boundary.
- Keep operation order. Record any deliberate change to rounding, fusing, or accumulation.
- Reject NaN, infinity, and bad indices when data becomes canonical. Trusted code does not re-check.
- Never depend on `Dictionary` or `Set` order for behavior.

## Ownership and data

- One mutable simulation owner. Direct calls in source order.
- Structs, enums, free functions, `ContiguousArray`, array-of-structs. Use classes only for framework objects or real shared identity.
- The object table follows `object.h`: handle = index plus signature. Do not add a new identity system.
- No Metal, AppKit, UIKit, or audio objects in simulation or save values.
- Concurrency only for blocking I/O, import, media, and long editor jobs.
- Do not add: actors per entity, a simulation thread, a job system, ECS, an event bus, dependency injection, a custom allocator, or protocols with one implementation.
- Do not use `@unchecked Sendable`, `nonisolated(unsafe)`, `Unmanaged`, unsafe pointers, or forced inlining without a measured need, a written invariant, and a test.

## Verify and profile

- Controlled-clock tests: previous-`Frametime` use, post-cap storage, `Gametime` advance order, 0.1 s init, and pause rebasing.
- Characterization tolerances used so far: exact, 1e-6, 1e-5, 2e-4, 1e-3. The room 3 → 4 flight replay matches the C++ reference (crossing at frame 17, contact with room 4 face 26 at frame 28).
- Profile only Release builds on the M4, with Instruments. In Swift host code, look for `memmove`, copy-on-write copies, retain and release traffic, exclusivity checks, unspecialized generics, and closure allocation. These are leads, not proof of a defect.
- Review by Codex (see `engineering.md`, section 6).

## Sources

- [Swift 6.4 released](https://www.swift.org/blog/swift-6.4-released/)
- [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [Adopting strict concurrency in Swift 6 apps](https://developer.apple.com/documentation/swift/adoptingswift6)
- WWDC24 [Explore Swift performance](https://developer.apple.com/videos/play/wwdc2024/10217/), and WWDC25 [Improve memory usage and performance with Swift](https://developer.apple.com/videos/play/wwdc2025/312/)
