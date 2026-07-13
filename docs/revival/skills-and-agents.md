# Skills and agents

- Status: planning baseline
- Date: July 13, 2026
- Authority: skill selection and agent operating rules

## Principle

Skills encode methods and constraints. They do not turn an agent into the named author or reproduce the judgment of a famous engineer. Prefer official material, real authors with inspectable work, executable evidence, and narrow project-specific instructions over generic “expert” personas.

No external skill is part of the product architecture. Project decisions in `AGENTS.md`, the accepted architecture document, and [Test-driven development](test-driven-development.md) override every imported skill.

## External sources

### Apple Metal skills

- Repository: [apple/game-porting-toolkit](https://github.com/apple/game-porting-toolkit/tree/main/game-porting-skills/skills)
- License: Apache-2.0
- Use: selective reference and future project adaptation

The useful native topics are Metal 4 resources, synchronization, pipeline creation, drawable presentation, validation, capture, rendering diagnosis, macOS windows, and GameController. Exclude Windows evaluation, Direct3D translation, Metal Shader Converter, Metal-cpp lifetime guidance, and any workflow that chooses a C++ host architecture.

The repository name does not make the Game Porting Toolkit a runtime dependency. Only audited Markdown guidance relevant to direct native Metal is in scope.

On the recorded macOS 26 and Xcode 26 host, use Instruments, `xctrace`, Xcode Metal capture, validation, and the supported Metal tools actually installed. Game Porting Toolkit 4 skill sections built around the newer `gpucapture` or `gpudebug` command-line environment are documentation-only until this project deliberately upgrades and verifies that toolchain.

### Scott Perry and Apple's TrueType migration

- Source: [Swift at Apple: Migrating the TrueType Hinting Interpreter](https://www.swift.org/blog/migrating-truetype-hinting-to-swift/)
Reference code: [apple/truetype-hinting-interpreter-example](https://github.com/apple/truetype-hinting-interpreter-example)

Use this as a method for low-level Swift: clear ownership, value types, borrowing, spans, small audited unsafe regions, corpus tests, and profile-guided optimization. Do not treat a font interpreter as a game-engine architecture or assume its benchmark result predicts this project.

### Paul Hudson

- Repository: [twostraws/Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill)
License: MIT

Use as a review checklist for Swift 6 isolation, `Sendable`, task lifetime, cancellation, and asynchronous loading boundaries. Project rules prohibit actor-heavy simulation designs even if a general application example recommends them.

### Kristijan Šimić

- Repository: [Kr1sso/xtrace-skill](https://github.com/Kr1sso/xtrace-skill)
License: MIT

This is the strongest identified candidate for repeatable Instruments and `xctrace` work, including Time Profiler, Metal System Trace, memory, leaks, shader timelines, GPU traces, and before/after reports. Pin a reviewed commit and audit every executable script before use. Cross-check important conclusions in Instruments and Xcode.

### XcodeBuildMCP

- Repository: [getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)
License: MIT

Defer installation until the Swift workspace exists. It can automate builds, tests, launches, logs, and LLDB, but direct `swift test`, `xcodebuild`, and reproducible CI remain the source of truth. Review telemetry behavior before enabling it.

### Harold Serrano's Untold Engine

- Repository: [untoldengine/UntoldEngine](https://github.com/untoldengine/UntoldEngine)
License: MPL-2.0

Untold Engine is a useful comparative Swift and Metal codebase. Study concrete solutions and test approaches. Do not adopt it as a dependency, inherit its architecture wholesale, or copy implementation files without handling MPL obligations.

### Additional measurement reference

[Philip Turner's Metal benchmarks](https://github.com/philipturner/metal-benchmarks) can suggest experiments about Apple GPU behavior. Re-run every relevant measurement on the project's M4 and defer API correctness to Apple's documentation.

## Rejected sources

Do not make core decisions from:

- unsupported “Weta,” “Pixar,” or similar persona prompts;
- generic `cpp-pro`, CMake, OpenGL, SDL, Rust, Unity, Unreal, Godot, or browser-game skill packs;
- broad marketplaces installed without file-by-file review;
- skills whose performance claims have no reproducible source;
- tools that silently add runtime dependencies or reopen platform choices.

No trustworthy elite game-engine C++ skill was identified. C++ expertise for this project comes from reading the actual released source to answer bounded content questions, not from installing a generic persona.

## Project-authored skills

Author these skills before their workstream begins:

| Skill | Purpose |
| --- | --- |
| `revival-constitution` | Enforce Swift/Metal-only scope, functional completeness, one-way import, red-first TDD, non-goals, and the five-target product graph |
| `d3-content-import` | Safe checked parsing, provenance, canonical conversion, and retail-data isolation |
| `revival-behavior-system` | Typed visual authoring, checked compilation, deterministic Float32 execution, interval translation, adaptive-score commands, debugging, persistence, and stock translation |
| `revival-creator-suite` | Canonical projects, AppKit editing, geometry and data tools, undo, validation, baking, play-in-editor, and publishing |
| `swift-realtime-systems` | Single-owner simulation, ownership, allocation, fixed ticks, Float32 normalization and state hashing, simulation revisions, and measured CPU optimization |
| `metal4-rendering` | Direct Swift/Metal 4 resources, passes, presentation, validation, and GPU evidence |
| `revival-multiplayer` | Authoritative simulation, transport selection, simulation and content negotiation, hostile-input and custom-media limits, hosting, modes, replay evidence, and network tests |
| `revival-replay` | Deterministic authoritative recording and state hashes, declared observer and client evidence, desync diagnosis, persistence, and one playback architecture |
| `revival-verification` | Red and green evidence, reachable production paths, numeric and revision contracts, deterministic tests, editor round trips, network matrices, images, Instruments traces, performance gates, and claim falsification |

Keep each skill narrow. A skill should contain enforceable rules, examples from this project, validation commands, prohibited patterns, and links to primary sources. Avoid a single large “game engine expert” prompt. Skills may share the product constitution but must not duplicate their technical playbooks.

Every project-authored and imported skill inherits the binding red-green-refactor protocol and test-value gate. A skill may not permit implementation-first testing, weaken required red evidence, demand tests for unreachable or speculative paths, or introduce production seams solely for tests.

The creator and behavior skills are Phase 2 and Phase 4 gates, not post-release additions. The replay skill is researched and reviewed before Phase 5. The multiplayer skill is researched and reviewed before Phase 9 design begins. Their later implementation dates do not make the capabilities optional.

## Supply-chain record

Before adding an external skill or executable tool, record:

- canonical repository and exact commit;
- author or organization;
- license;
- imported files;
- scripts or binaries it executes;
- audit result and date;
- allowed scope;
- prohibited sections or uses;
- local modifications and project overrides.

Do not auto-update skills. Review upstream changes before moving the pin.

## Agent roles

The root agent is the integration and architecture owner. With three child slots, work runs in focused waves.

### Foundation wave

1. Swift realtime specialist: simulation, ownership, data layout, behavior execution, and CPU profiling.
2. Metal specialist: renderer, MSL, game and editor presentation, resource lifetime, and GPU profiling.
3. Content and creator specialist: retail formats, canonical projects, editor operations, publishing, and campaign translation.

### Behavior and campaign wave

1. Behavior-language specialist: types, compiler, executor, limits, persistence, debugging, and authoring UX.
2. Gameplay specialist: AI, weapons, goals, campaign systems, and concrete domain operations.
3. Creator-tools specialist: world editing, content definitions, presentation, baking, validation, undo, and play-in-editor.

### Multiplayer and replay wave

1. Networked-simulation specialist: authority, replication, prediction only where measured play requires it, and desync evidence.
2. Network security and transport specialist: current Apple APIs, session lifecycle, negotiation, hostile-input bounds, and dedicated hosting.
3. Multiplayer creator and verification specialist: modes, maps, session behaviors, local multi-instance tests, network matrices, replay, and packaging.

### Verification wave

One implementation specialist rotates out for an independent verifier who owns acceptance criteria, attempts to falsify claims, and checks that retail or legacy dependencies have not leaked into runtime, editor, multiplayer, replay, or published packages.

The root agent keeps the functional-completeness ledger and assigns each phase's three child slots to its current highest-risk specialties. Do not keep an idle standing persona. Do not postpone creator expertise until the runtime is complete; editor and runtime work advance together from Phase 2.

## Operating rules

- Give each subagent one bounded output and one owner.
- Separate verified fact, inference, recommendation, and unknown.
- Require primary-source or local-code evidence for technical claims.
- Require the focused red command and intended failure before production implementation, followed by focused green and affected-suite results.
- Reject both missing red evidence and speculative tests that cannot name a reachable production path and distinct regression.
- Project architecture is closed unless the user explicitly reopens it.
- A content archaeologist may explain old behavior but may not solve a problem by linking old code into the product.
- A creator-tools specialist must preserve useful capability without copying MFC dialog structure, legacy export, or the page database.
- A behavior specialist may extend the typed language but may not add native-code escape hatches or cap it at stock-campaign operations.
- A multiplayer specialist may not inherit the original protocol merely because source exists.
- A Metal specialist may not add an alternate renderer.
- A systems specialist may not add a job system, ECS, or concurrency layer without a profile.
- The verifier owns completion evidence and does not merely review code after the fact. The verifier cannot waive red-first evidence or convert coverage pressure into tests for paths the product never runs.
- Every feature owner is responsible for applicable runtime, authoring, validation, playtest, and publishing evidence.
- The root agent resolves conflicts and keeps the documents consistent.
