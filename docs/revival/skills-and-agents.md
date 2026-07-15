# Skills and agents

- Status: accepted, amended
- Date: July 15, 2026
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

Start with the maintained [Primary technical source index](primary-source-index.md) before repeating web research. Domain skills keep narrower operational references, while the index records the key source, the question it answers, and what it cannot prove.

Apple's pinned Game Porting Toolkit skill bundle is installed as audited advisory material. Its direct Metal 4 API, resource, synchronization, presentation, validation, capture, and debugging guidance is applicable, as are direct GameController API facts after applying the project's single input-snapshot ownership. Its porting workflow, Objective-C++ window scaffold, dedicated engine-thread prescription, C++, Metal-cpp, Direct3D, Vulkan, Shader Converter, compatibility-backend, and macOS 27-only baseline routes are prohibited by the project boundary. Installation is not runtime adoption.

Use the smallest explicit resource-residency declarations required by the direct Metal 4 submission contract in Phase 1; this is GPU API correctness, not spatial streaming or a resource-manager architecture. Metal I/O, sparse resources, streaming samples, and speculative residency policy remain optional research sources only after resident-level measurement. API availability does not otherwise make them Phase 1 requirements.

Use NSDocument, UndoManager, standard menus, file coordination, restoration, keyboard, and accessibility behavior directly. Do not recreate them in a custom editor framework.

### Swift systems references

Apple's TrueType migration is a useful method reference for ownership, value types, spans, corpus tests, small audited unsafe regions, and profile-guided optimization. It is not a game-engine template or benchmark prediction; the [primary source index](primary-source-index.md#swift-engine-code-and-performance) retains the source and caveat.

Use reviewed Swift concurrency guidance for isolation, Sendable, cancellation, and real blocking boundaries. Project rules still prohibit actor-heavy simulation and task-per-entity designs.

The chosen product toolchain is Swift 6.4 in Swift 6 language mode from Xcode 27. Use the current Xcode 27 beta for initial product work, then replace it with stable Xcode 27 when released. Do not carry a Swift 6.3 compatibility path. Compiler version and language mode are recorded separately.

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

The complete current skill set is installed in the repository so the process can be reviewed as one system. Installation does not freeze a later-domain design. Immediately before a skill's first production use, review it against the current translated source and working native path, then amend the existing skill if evidence changed its assumptions.

| Skill | Purpose |
| --- | --- |
| [revival-constitution](../../.agents/skills/revival-constitution/SKILL.md) | Enforce Apple-native scope, complete capability, one-way import, human-first editor, current resident baseline, evidence-driven amendments, and one production path |
| [revival-source-translation](../../.agents/skills/revival-source-translation/SKILL.md) | File and symbol disposition, dependency-island tracing, baseline capture, semantic translation, deliberate differences, license provenance, actual scaffold deletion, and source-led island accounting |
| [d3-content-import](../../.agents/skills/d3-content-import/SKILL.md) | Checked parsing, source profile, archive precedence, complete Level topology, eager-working-set evidence, current reachable lazy dependencies, provenance, atomic promotion, and retail isolation |
| [revival-creator-suite](../../.agents/skills/revival-creator-suite/SKILL.md) | Read-only base to editable project to disposable play-session flow, AppKit documents, direct edits, undo, save/reopen/play, progressive workspaces, accessibility, real background-operation safety, validation, and publishing |
| [swift-realtime-systems](../../.agents/skills/swift-realtime-systems/SKILL.md) | Single-owner source-faithful old/new variable-time handoff, flight and collision traces, Phase 3 scheduler decision, direct data layout, and measured optimization |
| [metal4-rendering](../../.agents/skills/metal4-rendering/SKILL.md) | Direct Swift and MSL Metal 4, source-faithful canonical resource preparation, final-use release, room/portal and terrain rendering, player/editor identity, capture, validation, and M4 profiling |
| [revival-behavior-system](../../.agents/skills/revival-behavior-system/SKILL.md) | Generated and handwritten source accounting, direct typed translation, event and state fidelity, evidence-gated authoring evolution, debugging, persistence, and one executor path |
| [revival-volumetric-navigation](../../.agents/skills/revival-volumetric-navigation/SKILL.md) | Source route and node tracing, clearance, steering, blockage, recovery, editor diagnostics, and evidence-backed native simplification |
| [revival-replay](../../.agents/skills/revival-replay/SKILL.md) | Final-scheduler recording, authoritative checkpoints, continuation, diagnosis, observer evidence, and one playback path |
| [revival-networked-simulation](../../.agents/skills/revival-networked-simulation/SKILL.md) | 2–32 humans, authority, prediction, reconciliation, interpolation, latency rules, replication, state evidence, and replay interaction |
| [revival-transport-security-operations](../../.agents/skills/revival-transport-security-operations/SKILL.md) | Network QUIC, CryptoKit records, Bonjour, public discovery and relay, hostile boundaries, keys, privacy, abuse controls, deployment, monitoring, and outage behavior |
| [revival-multiplayer](../../.agents/skills/revival-multiplayer/SKILL.md) | Modes, co-op, content negotiation, host difficulty, chat, moderation, commands, media, dedicated hosting, authoring, and network matrices |
| [revival-verification](../../.agents/skills/revival-verification/SKILL.md) | Falsify named evidence claims, verify milestone matrices and terminal states, and prevent one check from standing in for another |

Three additional workflow skills stay narrow:

| Skill | Purpose |
| --- | --- |
| [revival-wayfinding](../../.agents/skills/revival-wayfinding/SKILL.md) | Expose genuine unknowns and choose the next evidence-producing step without creating a parallel plan |
| [revival-simplify](../../.agents/skills/revival-simplify/SKILL.md) | Prove the protected behavior surface, then delete defensive, duplicated, speculative, or indirect code without losing ledgered capability |
| [revival-review](../../.agents/skills/revival-review/SKILL.md) | Run and consolidate the four independent concerns for a material slice: source fidelity, architecture and scope, tests and evidence, and simplicity and maintainability |

Orchestration, blast-radius analysis, boundary and type discipline, PR reviewability, and optional review visualization are steps inside this workflow rather than separately triggered doctrine skills. This avoids overlapping rules and reviewer multiplication. The exact external sources, pins, licenses, and exclusions are recorded in [`skill-supply-chain.md`](skill-supply-chain.md).

The repository skill set, including the two Phase 1 prerequisite skills, is authored and reviewed against the accepted documents. This does not complete Phase 0: the Training identity, acceptance-room, dependency, and ledger gates remain.

Keep each skill narrow. It should contain enforceable rules, current project examples, validation commands, prohibited patterns, and primary-source links.

Every skill inherits the production red-green-refactor protocol and test-value gate. It may use bounded nonshipping research to discover a contract, but it may not ship research code, waive red-first implementation, demand speculative coverage, or introduce test-only product seams.

The only whole-phase skill prerequisites for Phase 1 are `revival-constitution` and `revival-source-translation`. Review each other installed skill against its real source dependencies immediately before the first production change in its domain; it gates that change, not unrelated work. Review behavior and navigation against the translated Training dependencies before Phase 4. Review replay after the Phase 3 timing decision and before Phase 5 replay work, then again against multiplayer before Phase 9. Review the three network skills against the working final simulation immediately before Phase 9.

Do not install or author a streaming skill unless the M4 evidence gate after the complete playable Training Mission accepts a resource-lifetime amendment. Do not install or author an MCP or agent-authoring skill before the complete human creator suite ships.

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

Do not auto-update skills. Review upstream changes before moving a pin. The current record is [`skill-supply-chain.md`](skill-supply-chain.md).

## Step-by-step workflow

Use only the steps the current work needs:

1. **Constitution check.** Confirm the requested result fits the accepted platform, product, content, ownership, and one-path boundaries.
2. **Wayfind when genuinely foggy.** State what is known, unknown, and decision-relevant; choose the next source trace, experiment, capture, or question that can collapse uncertainty. Write accepted results back to the owning document or ledger immediately.
3. **Trace one dependency island.** Name the observable player or editor result, legacy and editor callers, important symbols, ordering, lifetime, baseline, dispositions, and deliberate modernization boundary.
4. **Check the real blast radius.** Prove the affected runtime and editor callers, canonical consumers, update order, resource lifetime, and current acceptance path. Record what evidence confirms, clears, or leaves a risk open; do not produce a speculative caller essay.
5. **Implement one contract.** Use the current domain skill. Observe focused red, make the smallest direct green, and keep validation at the untrusted-to-canonical boundary. Concrete Swift values and exhaustive state represent real invariants; wrapper types and protocols need an actual ownership or semantic job.
6. **Simplify the diff.** Protect the named behavior surface, then remove duplicated paths, defensive runtime branches, needless indirection, stale comments, speculative flexibility, and measured hot-path waste. Rerun the focused and affected evidence after every accepted simplification.
7. **Review a material slice.** Run the four independent review concerns and consolidate concrete findings once. The island owner resolves them against source and product evidence; reviewers do not directly redesign the diff.
8. **Make the change reviewable.** Explain the observable island and source map first, core logic second, wiring and mechanical movement afterward, then risks, deliberate differences, ledger transitions, and exact evidence. Never rewrite history without explicit authority and tree-identity proof.
9. **Close and hand off.** Require applicable player and creator checkpoints and source-row closure for the island. Advance each functional row only as far as the slice proves; require its terminal state when complete capability or milestone closure is claimed. Commit, push, open a PR, or generate an optional visual review only when requested.

The process is a feedback loop, not a waterfall. A failed test, capture, review, or real-content run may return the island to tracing or wayfinding. Repair the narrow rule that allowed a repeated mistake; do not add a framework to prevent every imaginable one.

## Agent work waves

Use the following bounded evidence-producing roles rather than standing personas. Run independent roles concurrently when agent capacity allows.

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

After every material slice, cover four concerns independently:

- source fidelity and complete runtime/editor accounting;
- architecture, constitutional scope, canonical boundaries, and one production path;
- focused tests, evidence claims, player/editor acceptance, and terminal rows;
- simplicity, maintainability, reuse of existing direct code, and measured efficiency.

Use separate reviewers when capacity allows. Run the remaining concern in the next wave when capacity is limited. For a small change one reviewer may cover multiple concerns only when the report keeps them distinct. Reviewers identify concrete paths and observable consequences; they do not demand preservation of obsolete machinery, literal source shape, defensive branches after canonical validation, or speculative future-proofing. [`revival-review`](../../.agents/skills/revival-review/SKILL.md) defines consolidation and closure.

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
