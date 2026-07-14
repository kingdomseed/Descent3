# Skills and agents

- Status: planning baseline, amended
- Date: July 14, 2026
- Authority: skill selection and agent operating rules

## Principle

Skills encode methods and constraints. They do not make an agent the named author or substitute a generic expert persona for source evidence.

Prefer:

- the pinned released source and runnable reference engine;
- verified retail content and local captures;
- original developer notes, revision history, and the Descent 3 postmortem;
- official Apple API and tool documentation;
- narrow project-specific playbooks with executable checks.

Project decisions in AGENTS.md and the accepted revival documents override imported skills. A skill cannot promote a research hypothesis into architecture.

## Primary sources

### Released Descent 3 source

The pinned source is the main translation source for formats, data flow, order, algorithms, resource dependencies, gameplay, rendering, tools, multiplayer, replay, and behavior.

Use it systematically, not only to answer isolated questions. Trace both runtime and editor callers. Account for generated and handwritten behavior ranges. Record platform replacement, evidence-only, exclusion, and deliberate differences in the source-translation ledger.

Do not link it into a product target or mirror mixed legacy file boundaries blindly.

### Historical development evidence

Use original Outrage notes, retained source logs, and the 1999 postmortem to understand process:

- editor and runtime evolved together;
- designers built rooms to exercise the room engine;
- real content invalidated engine, terrain, lighting, and tool assumptions;
- fragmented tools and programmer-centered UI imposed large costs;
- uncontrolled engine/content churn destroyed work.

These sources support an early shared editor/player loop, representative content, and stabilizing proven slices. They do not prove a completed editor came first, prescribe literal 1997 source order, or decide modern resource lifetime.

### Apple Metal and application sources

Use Apple's documentation for direct Metal 4 queues and command buffers, MetalKit presentation, resource lifetime, capture, validation, AppKit documents, GameController, AVFoundation, Network, and CryptoKit.

Metal I/O, residency sets, sparse resources, and streaming samples are optional research sources after resident-level measurement. API availability does not make them Phase 1 requirements.

Use NSDocument, UndoManager, standard menus, file coordination, restoration, keyboard, and accessibility behavior directly. Do not recreate them in a custom editor framework.

### Swift systems references

Apple's TrueType migration is a useful method reference for ownership, value types, spans, corpus tests, small audited unsafe regions, and profile-guided optimization. It is not a game-engine template or benchmark prediction.

Use reviewed Swift concurrency guidance for isolation, Sendable, cancellation, and real blocking boundaries. Project rules still prohibit actor-heavy simulation and task-per-entity designs.

### Measurement tools

Use direct swift test, xcodebuild, Instruments, xctrace, Metal capture, validation, and reproducible scripts as the source of truth.

XcodeBuildMCP or another automation helper may be evaluated after the workspace exists. Pin and audit executable tooling, review telemetry, and keep direct commands reproducible.

## Rejected source patterns

Do not make core decisions from:

- unsupported famous-engineer personas;
- generic game-engine, C++, OpenGL, SDL, Rust, Unity, Unreal, Godot, or browser skill packs;
- broad marketplaces installed without file review;
- performance claims without reproducible measurements;
- tools that silently add runtime dependencies or reopen the platform direction;
- a single modern engine opinion averaged together with incompatible designs.

The best C++ expertise here is careful reading of this C++ source, not a generic persona.

## Project-authored skills

Author each skill immediately before its workstream:

| Skill | Purpose |
| --- | --- |
| revival-constitution | Enforce Apple-native scope, complete capability, one-way import, human-first editor, current resident baseline, evidence-driven amendments, and one production path |
| revival-source-translation | File and symbol disposition, dependency-island tracing, baseline capture, semantic translation, deliberate differences, license provenance, actual scaffold deletion, and source-led review |
| d3-content-import | Checked parsing, source profile, archive precedence, complete Level topology, eager-working-set evidence, current reachable lazy dependencies, provenance, atomic promotion, and retail isolation |
| revival-creator-suite | Read-only base to editable project to disposable play-session flow, AppKit documents, direct edits, undo, save/reopen/play, progressive workspaces, accessibility, real background-operation safety, validation, and publishing |
| swift-realtime-systems | Single-owner source-order variable-time translation, old/new timing handoff, flight and collision traces, Phase 3 scheduler decision, direct data layout, and measured optimization |
| metal4-rendering | Direct Swift Metal 4, source-faithful eager and lazy canonical resource preparation, final-use release, room/portal and terrain rendering, game/editor identity, capture, validation, and M4 profiling |
| revival-behavior-system | Generated and handwritten source accounting, canonical direct typed translation, event and state fidelity, evidence-gated authoring evolution, debugging, persistence, and removal only of an actually superseded path |
| revival-volumetric-navigation | Source route and node tracing, clearance, steering, blockage, recovery, editor diagnostics, and evidence-backed native simplification |
| revival-replay | Final-scheduler recording, authoritative checkpoints, continuation, diagnosis, observer evidence, and one playback path |
| revival-networked-simulation | 2–32 humans, authority, prediction, reconciliation, interpolation, latency rules, replication, state evidence, and replay interaction |
| revival-transport-security-operations | Network QUIC, CryptoKit records, Bonjour, public discovery and relay, hostile boundaries, keys, privacy, abuse controls, deployment, monitoring, and outage behavior |
| revival-multiplayer | Modes, co-op, content negotiation, host difficulty, chat, moderation, commands, media, dedicated hosting, authoring, and network matrices |
| revival-verification | Translation accounting, red/green evidence, resident load/release, editor round trips, image review, M4 profiling, campaign and network gates, and claim falsification |

Keep each skill narrow. It should contain enforceable rules, current project examples, validation commands, prohibited patterns, and primary-source links.

Every skill inherits the production red-green-refactor protocol and test-value gate. It may use bounded nonshipping research to discover a contract, but it may not ship research code, waive red-first implementation, demand speculative coverage, or introduce test-only product seams.

The only whole-phase prerequisites for Phase 1 are revival-constitution and revival-source-translation. Author each other skill immediately before the first production change in its domain; it gates that change, not unrelated workspace, importer, renderer, or editor work. Behavior and navigation skills are written from actual source dependencies before Phase 4. Replay follows the timing decision. Network skills are reviewed against the working final simulation immediately before Phase 9.

Do not author a streaming skill unless the post-Training M4 evidence gate accepts a resource-lifetime amendment. Do not author an MCP or agent-authoring skill before the complete human creator suite ships.

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

Do not auto-update skills. Review upstream changes before moving a pin.

## Agent work waves

With three child slots, assign bounded evidence-producing tasks rather than standing personas.

### Translation foundation

1. Source and chronology reviewer: trace the current dependency island across runtime, editor, and revision evidence; maintain dispositions.
2. Swift and Metal implementer: translate the current world/render/simulation path directly and profile it.
3. Content and creator implementer: import the same slice and deliver its real editor mutation, validation, save, and play loop.

### Behavior and campaign

1. Behavior translator: account for generated and handwritten ranges and implement the current chain.
2. Gameplay translator: implement the dependent AI, physics, weapons, goals, and state.
3. Creator translator: add current world, behavior, presentation, bake, validation, and play operations.

### Multiplayer and replay

1. Networked-simulation owner.
2. Transport, security, and operations owner.
3. Multiplayer creator and independent verification owner.

### Independent review

After every material slice, use separate reviewers for:

- maintainability and unnecessary abstraction;
- fidelity to source behavior and editor/runtime relationships;
- acceptance evidence and unclosed source dispositions.

Reviewers identify concrete paths and observable consequences. They do not demand preservation of obsolete machinery, literal source shape, defensive branches after canonical validation, or speculative future-proofing.

## Operating rules

- Give each agent one bounded output and one owner.
- Separate verified fact, inference, current decision, and open hypothesis.
- Require primary-source or local-code evidence for technical claims.
- Require focused red/green evidence for shipping behavior and a deletion gate for temporary scaffolds.
- A source reviewer may drive implementation mapping but may not solve it by linking legacy code.
- A creator reviewer preserves useful workflow, not MFC layout or backward export.
- A Metal reviewer begins with the complete resident Level and source-faithful eager/lazy asset preparation, and may not add spatial streaming before the M4 amendment gate.
- A systems reviewer may not add a job system, ECS, fixed scheduler, deterministic math framework, or custom allocator without the accepted evidence gate.
- A behavior reviewer grows the safe model from working chains and may not add native-code escape hatches or cap the final creator surface at stock behavior.
- A multiplayer reviewer implements the selected native route and does not inherit original packets merely because source exists.
- A reviewer distinguishes legitimate semantic fidelity from prohibited API, ABI, and platform compatibility.
- The root agent resolves conflicts, keeps the documents consistent, and ensures review findings change the actual diff when warranted.
