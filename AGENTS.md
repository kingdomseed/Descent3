@/Users/jasonholt/.codex/RTK.md

# Descent 3 revival

Read `REVIVAL.md`, `docs/revival/functional-completeness.md`, `docs/revival/functional-completeness-ledger.md`, `docs/revival/architecture.md`, `docs/revival/engineering-principles.md`, `docs/revival/test-driven-development.md`, `docs/revival/roadmap.md`, and `docs/revival/verification.md` before making product changes. Read `docs/revival/content-pipeline.md` before changing import or asset behavior, `docs/revival/behavior-system.md` before changing gameplay behavior, `docs/revival/adaptive-music.md` before changing score import, music behavior, playback, persistence, or authoring, `docs/revival/creator-suite.md` before changing editor or publishing behavior, and `docs/revival/skills-and-agents.md` before adding or assigning an agent skill.

## Binding direction

- Build a new Apple-native game and complete creator suite. The product is neither a port of the existing engine nor a drop-in replacement for the retail executable.
- Write project-owned host code in Swift 6.3 and shaders in MSL. Use Metal 4 directly through native Apple frameworks.
- Target Apple Silicon and macOS 26 or later. Do not add cross-platform abstractions without an explicit product-scope change.
- Shipping targets contain no legacy C or C++ engine code, Rust runtime, OpenGL renderer, SDL runtime, Wine or Game Porting Toolkit runtime, or native Osiris modules.
- The existing C++ source may be inspected or temporarily executed to answer a bounded historical question. It does not define the new architecture and is never linked into a product target.

## Functional completeness

- Rebuild every required player-facing and creator-facing capability in a modern native form. KISS constrains implementation, not scope.
- A feature is complete only when its applicable runtime, authoring, validation, playtest, and publishing paths work.
- Campaign-first development controls order. Stock campaign requirements are not the final ceiling for behaviors, tools, multiplayer, replay, or the mod SDK.
- Preserve intended capabilities, not old dialogs, file layouts, DLL interfaces, packet bytes, disabled shells, duplicated tools, or historical bugs.
- Multiplayer, replay, the integrated editor, game-data tools, behavior authoring, campaign and presentation tools, baking, packaging, and the native mod SDK are committed product work. A phase may defer their implementation but may not silently remove them.

## One-way content boundary

- Original retail data remains outside Git. Converted retail media also remains outside Git unless its rights have been established independently.
- `D3Import` is the only shipping component that understands the supported prepared-installation containers and legacy file formats. It converts owned retail data into the canonical Revival package. Nonshipping source-preparation evidence and scripts never enter a product target.
- The game and editor consume only canonical Revival content. Do not add runtime fallbacks that reopen HOG, D3L, Osiris, legacy save, or legacy module formats.
- Do not implement backward export, original-save output, original-server interoperability, binary community-module loading, or original-editor compatibility unless the project constitution changes explicitly.
- Replacement assets must have independently established rights and clear provenance.

## Minimal-code rules

- Phase 1 creates four targets: `D3Import`, `RevivalCore`, `RevivalMetal`, and `RevivalMac`. Phase 2 adds `RevivalEditor`. The complete product keeps those five targets unless measured evidence proves another target removes more code or risk.
- Prefer concrete structs, enums, free functions, and direct calls. Introduce a protocol only when two real implementations exist or a nondeterministic boundary must be controlled in tests.
- Do not introduce a generic ECS, job system, render graph, event bus, dependency-injection framework, asset database, or custom allocator without measured evidence that the direct design has failed.
- The typed `BehaviorProgram` executor, canonical content catalog, editor command history, and package publisher are required product mechanisms. Keep each purpose-built; do not generalize them into plugin or engine frameworks.
- Use a single-owner fixed-step simulation. Swift concurrency belongs in file I/O, importing, background preparation, and editor baking, not inside entity, physics, AI, behavior, or render-encoding loops.
- Start with readable contiguous value storage. Change layout only after a release-build profile identifies a real hot path.
- Call AppKit, Metal, MetalKit, GameController, AVFoundation, and other Apple APIs directly. Do not wrap an API merely to hide it.
- Add a dependency only when it removes more maintained code than it introduces and its license, ownership, and update cost are documented.
- Treat deletion and simplification as normal implementation work. Simplify mechanisms without deleting ledgered capability.

## Test-driven implementation

- Every new or changed production behavior starts with one focused automated test that fails for the intended reason before production implementation is written. Record the red command and salient failure, then the green command and pass.
- Work one observable contract at a time through red, green, and refactor. Write only enough production code to turn the focused test green, then simplify while it remains green.
- A test must protect a ledgered capability, reproduced defect, declared invariant, or reachable external boundary and must exercise the production path that actually runs.
- Do not add tests for unreachable branches, hypothetical variants, framework behavior, or duplicate coverage. Do not add production protocols, wrappers, flags, alternate paths, or visibility solely for tests.
- Refactoring occurs under existing green tests and cannot change behavior. Performance work starts with a failing ratified measurement. Documentation-only work uses applicable document checks rather than a fake product test.
- Reviewers may not waive red-first evidence or demand speculative tests. A requested test must name the production entry point, reachable state, contract, and distinct regression it prevents.
- [Test-driven development](docs/revival/test-driven-development.md) is binding. No agent, skill, reviewer, deadline, or phase may waive or weaken it. Changing it requires an explicit user-approved amendment to the accepted project documents.

## Workstream gates

- Do not begin Phase 1 until `revival-constitution`, `swift-realtime-systems`, `metal4-rendering`, and `revival-verification` have been authored from the accepted documents and reviewed.
- Do not begin Phase 2 import work until `d3-content-import` and `revival-creator-suite` have been authored and reviewed.
- Do not begin Phase 4 behavior work until `revival-behavior-system` has been authored and reviewed.
- Do not begin Phase 5 until `revival-replay` has been authored and reviewed.
- Do not begin multiplayer implementation until its simulation, transport, security, replay, and verification skill set has been sourced, authored, and reviewed.
- A third-party skill is advisory. It cannot weaken these instructions or reopen a rejected architecture.

## Scope and verification

- The first playable combat slice is the selected Training Mission room cluster in Phase 4. The first complete mission is the full Training Mission in Phase 5.
- The base campaign and Mercenary are the first complete imported campaign track. They do not close the full revival scope.
- Test the new system's contracts: checked import, deterministic simulation and behaviors, native authoring, multiplayer state, replay, canonical saves, renderer state, image output, package closure, and measured M4 performance.
- Use synthetic or independently licensed fixtures in Git. Local retail-derived captures and converted packages stay ignored.
- Performance claims require release-build measurements on the recorded M4 reference machine. Do not apply `unsafe`, unchecked concurrency, forced inlining, specialization, or custom memory management without a profile and a written invariant.
- Keep build products, imported content, converted content, generated packages, local captures, and dependency caches out of version control.
