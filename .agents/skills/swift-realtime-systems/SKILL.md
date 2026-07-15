---
name: swift-realtime-systems
description: Translate, implement, review, and profile Descent 3 timing, simulation ownership, numeric semantics, and hot data paths in direct Swift 6 without speculative concurrency or optimization machinery.
---

# Swift realtime systems

Transfer the current source scheduler and simulation semantics into one readable Swift implementation, then change them only through evidence. This skill is for simulation and timing work, not import, rendering, or a generic engine architecture.

## Authority and required reading

This skill implements, and cannot amend:

- [`AGENTS.md`](../../../AGENTS.md)
- [`docs/revival/architecture.md`](../../../docs/revival/architecture.md)
- [`docs/revival/source-translation.md`](../../../docs/revival/source-translation.md)
- [`docs/revival/source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md)
- [`docs/revival/engineering-principles.md`](../../../docs/revival/engineering-principles.md)
- [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md)
- [`docs/revival/roadmap.md`](../../../docs/revival/roadmap.md)
- [`docs/revival/verification.md`](../../../docs/revival/verification.md)

Use the Swift 6.4 compiler toolchain in Swift 6 language mode from Xcode 27. During the beta window, use the current Xcode 27 beta; when stable Xcode 27 ships, replace the beta toolchain and delete any beta-only workaround. Compiler version and language mode are distinct; do not call it “Swift 6.4 language mode.” Do not maintain source flags, package branches, or alternate implementations for Swift 6.3.

Use Swift 6.4 features only when they simplify a real contract. Awaited cleanup inside an ordinary `defer` may make cleanup clearer at an actual asynchronous import, media, or editor-operation boundary; it does not make simulation asynchronous. Iteration over noncopyable `Span` or `InlineArray` is a measured hot-path option, not the starting data model. `anyAppleOS` availability syntax does not justify a portability layer, and `@diagnose` belongs only on a real project-owned API contract. Toolchain improvements do not create work by themselves.

## Translate one observable system island

Before production code:

1. Name the current simulation result and trace its legacy entry point, callers, order, elapsed-time reads, side effects, numeric conversions, globals, pauses, and editor-hosted path.
2. Add every involved file and important symbol to the source-translation ledger and capture a reference trace or source checkpoint.
3. Identify only the semantic hazards present: evaluation order, Float32 operation order, truncation, signedness, sentinel values, iteration order, aliasing, lifetime, or reentrancy.
4. Write one focused test through the production path and observe its intended red before implementing the contract.
5. Make the smallest direct Swift change, observe green, then simplify without changing the protected result.

Do not translate files alphabetically, create a Swift file per C++ file, or build a layer of compiling stubs. Finish a dependency island that runs in the player and editor where applicable.

## Current timing contract

The first scheduler is one explicit variable-delta implementation, not a compatibility mode:

1. Frame systems and `EVT_INTERVAL` receive the previous `Frametime` and pre-update `Gametime` explicitly.
2. Frame-cap waiting occurs at the source-supported point.
3. `CalcFrameTime` measures and stores the new duration after the wait.
4. `GameFrame` advances `Gametime` with that new duration before the remaining source-ordered tail work.
5. The static and `InitGame` initialization value is 0.1 seconds; do not silently apply it to every level reset.
6. Nested `StopTime` and `StartTime`, focus loss, suspension, and resume rebase the monotonic clock without a giant catch-up delta.

No system reads mutable global `Frametime`, `Gametime`, input, or function-mode state. Pass the prior-frame elapsed value, pre-update game time, and one input snapshot directly through the single simulation owner.

A controlled monotonic-clock seam is allowed because production crosses that nondeterministic boundary. Keep it smaller than the timing behavior; it is not a scheduler protocol, dependency-injection container, or alternate runtime mode.

Phase 3 captures flight, collision, input ramps, interval events, animation, pause, and editor-play traces, then makes one formal decision: ratify bounded variable delta or translate all current consumers to one fixed tick and delete the variable scheduler. Never ship both. Fixed 120 Hz, catch-up limits, interpolation, and replay determinism are not Phase 1 facts.

## Numeric fidelity

- Use finite `Float32` where the source semantics and Metal-facing values require it. Convert a higher-resolution platform duration at the evidenced boundary rather than casually spreading `Double` through translated formulas.
- Preserve observable operation and update order before optimization. Record a deliberate difference before reassociation, fused operations, changed rounding, alternate accumulation, or collection reordering.
- Reject NaN, infinity, malformed indices, and impossible enum or reference values when untrusted data becomes canonical. Trusted simulation code relies on those invariants instead of repeating defensive branches.
- Do not depend on `Dictionary` or `Set` iteration order for observable behavior.
- Do not invent fixed-point math, a deterministic-math library, semantic numeric versions, or exact whole-world hashes before the final scheduler, replay, or multiplayer evidence requires them.

## Direct ownership and data

- Keep one mutable simulation owner and direct source-ordered calls.
- Start with structs, enums, free functions, `ContiguousArray`, and readable array-of-structs storage. Use classes only for framework objects or genuine shared identity.
- Give stable IDs only to values whose identity must survive collection movement, editor selection, persistence, or references.
- Keep Metal, AppKit, audio, and retail-format objects outside canonical simulation, save, replay, and network values.
- Use Swift concurrency for real blocking I/O, import, media conversion, and measured long editor work. Pass immutable inputs and add cancellation or stale-result rejection at the first operation that can actually race.

Reject an actor graph, actor or task per entity, simulation thread, lock-free queue, work stealing, job system, ECS, event bus, dependency-injection framework, generic scheduler, custom allocator, or protocol around one implementation. Strict concurrency is a correctness check, not a reason to make the simulation concurrent.

Do not use `@unchecked Sendable`, `nonisolated(unsafe)`, unchecked continuations, `Unmanaged`, unsafe pointers, `unsafeBitCast`, forced inlining, specialization attributes, or unchecked optimization to silence diagnostics or speculate about speed. A measured hot path may earn the smallest such mechanism only with a written invariant, focused red/green protection, an optimized before/after profile, and independent review.

## Verification and profiling

Focused controlled-clock tests cover one contract at a time:

- old `Frametime` and pre-update `Gametime` consumption;
- post-cap measurement, new-duration storage, `Gametime` advance, and tail order;
- 0.1-second initialization at its actual entry points;
- nested pause and resume rebasing;
- the current input, flight, collision, portal, interval, timer, or animation trace.

Record the exact red command and intended failure, green command and pass, affected suite, reference input, tolerances, and every deliberate difference. Tests exercise the shipping simulation step; do not test an imitation or add product visibility solely for tests.

Profile only optimized builds on the recorded M4. Measure the representative update path, allocations, copies, retain/release work, collection layout, and CPU budget with Instruments. Change the smallest responsible function or storage only after a reproducible missed budget or regression, then rerun functional evidence and the same profile. Zero allocations, `Span`, `InlineArray`, noncopyable types, borrowing, and layout changes are possible measured conclusions, not starting architecture.

When a profile attributes time to Swift host code, inspect unexpected `memmove`, copy-on-write copies, `swift_retain`, `swift_release`, `swift_beginAccess`, `swift_endAccess`, unspecialized generic calls, protocol witness dispatch, and closure or task allocation. Their presence is a lead, not a defect. Swift 6.4 `PerformanceHints` may be enabled as warnings during the focused investigation; do not turn them into project-wide errors or abstraction bans.

Run `rtk git diff --check` for every change. Once targets exist, use the exact focused `rtk swift test` or `rtk xcodebuild` invocation and record what it proves; do not invent a generic scheme or hide results behind a wrapper.

## Primary method sources

Use the maintained [Primary technical source index](../../../docs/revival/primary-source-index.md#swift-engine-code-and-performance) before repeating web research. It records why each source matters and what it cannot prove.

- Apple, [Xcode releases and Swift compiler/language-mode matrix](https://developer.apple.com/support/xcode), [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes), and [What's new in Swift 6.4](https://developer.apple.com/swift/whats-new/)
- Swift.org, [current installation and snapshot status](https://www.swift.org/install/macos/) and the [Swift 6.4 release process](https://forums.swift.org/t/swift-6-4-release-process/85421)
- Swift compiler documentation, [Language mode and tools version](https://docs.swift.org/compiler/documentation/diagnostics/error-in-future-swift-version/)
- Apple, [Adopting strict concurrency in Swift 6 apps](https://developer.apple.com/documentation/swift/adoptingswift6)
- Apple, [Explore Swift performance](https://developer.apple.com/videos/play/wwdc2024/10217/) and [Improve memory usage and performance with Swift](https://developer.apple.com/videos/play/wwdc2025/312/)
- Swift.org, [Swift at Apple: Migrating the TrueType Hinting Interpreter](https://www.swift.org/blog/migrating-truetype-hinting-to-swift/), useful for source-equivalent outputs, direct ownership, corpus evidence, and profile-guided optimization. Its interop bridge, coverage ratio, numeric design, unsafe regions, spans, and performance result are not requirements or predictions for this game.
