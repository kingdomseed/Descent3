# Skills and agents

- Status: accepted, amended
- Date: August 5, 2026
- Authority: skill selection and agent operating rules

## Principle

Skills encode methods and constraints. They do not make an agent the named author or substitute a generic expert persona for source evidence.

The [roadmap](roadmap.md) and accepted contracts govern scope and phase order. The [current implementation plan](current-plan.md) is the single living record of active state, near-term work, lane ownership, and blockers beneath them. Every contributor reads it before selecting work. One integration owner updates it when work lands or the active sequence changes; agents do not maintain competing plans or edit its live state concurrently. The project-local documentation steward restores and reconciles this record at material packet boundaries, but it routes each fact to the existing canonical owner instead of creating another plan, findings file, progress journal, or agent ledger. After ordinary review consolidation, the independent completion gate decides once whether remaining work is required now, one bounded correction, later work, or ceremony; it is not another implementation lane or recursive reviewer.

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

### Maintained descendants

Pinned PiccuEngine and DESCENT 3MASTERED commits are a source-cited patch history over the released baseline. When a mapped change intersects the current island, read its exact before/after diff before translating the older path. Extract the problem already diagnosed, corrected observable result, invariant or ordering, useful regression case, and direct Swift/MSL mapping. Clear reached defect corrections and restorations belong in the native contract without first reproducing the old bug; quality-of-life and deliberate-modernization changes remain subject to their existing product owner and evidence rule.

The descendant's Windows, OpenGL, OpenAL, SDL, legacy Osiris, ABI, cache, or compatibility mechanism is not Revival architecture. That is a mechanism decision made after semantic extraction, not a reason to ignore work that has already clarified the old system. Exact pins, evidentiary limits, and lineage live in the [primary source index](primary-source-index.md); adopted semantics and GPL provenance live in the existing source ledger or deliberate-difference owner.

### Historical development evidence

Use original Outrage notes, retained source logs, and the 1999 postmortem to understand process:

- editor and runtime evolved together;
- designers built rooms to exercise the room engine;
- real content invalidated engine, terrain, lighting, and tool assumptions;
- fragmented tools and programmer-centered UI imposed large costs;
- uncontrolled engine/content churn destroyed work.

These sources support an early shared editor/player loop, representative content, and stabilizing proven slices. They do not prove a completed editor came first, prescribe literal 1997 source order, or decide modern resource lifetime.

### Apple Metal and application sources

Use Apple's documentation for direct Metal 4 queues and command buffers, MetalKit presentation, resource lifetime, capture, validation, AppKit documents, UIKit scenes and lifecycle, GameController physical-controller input and candidate touch-control APIs, AVFoundation and AVAudioSession, platform file picking and app-owned storage, local-network privacy, Network, and CryptoKit. Phase 8 selects the touch-gameplay mechanism against the working product; an available API does not preselect it.

Start with the maintained [Primary technical source index](primary-source-index.md) before repeating web research. Domain skills keep narrower operational references, while the index records the key source, the question it answers, and what it cannot prove.

Apple's pinned Game Porting Toolkit skill bundle is installed as audited advisory material. Its direct Metal 4 API, resource, synchronization, presentation, validation, capture, and debugging guidance is applicable, as are direct GameController API facts after applying the project's single input-snapshot ownership. Its porting workflow, Objective-C++ window scaffold, dedicated engine-thread prescription, C++, Metal-cpp, Direct3D, Vulkan, Shader Converter, compatibility-backend, and macOS 27-only baseline routes are prohibited by the project boundary. Installation is not runtime adoption.

Use concrete AppKit and UIKit shells over the same RevivalCore, RevivalMetal, world, scheduler, input snapshot, and canonical-package paths. UIKit owns RevivalMobile's lifecycle and is its default UI toolkit. A bounded SwiftUI view is allowed only when a current component has a concrete technical or product advantage and remains hosted inside the UIKit lifecycle, navigation, state, and Metal-view path. Call platform APIs directly in the shell that owns them. Do not turn shared game semantics into a generic platform, input, view, file-picker, or filesystem abstraction. RevivalMobile imports only a Mac-produced canonical package through the platform picker and copies it into app-owned storage; D3Import and all retail-format knowledge remain macOS-only.

Use the smallest explicit resource-residency declarations required by the direct Metal 4 submission contract in Phase 1; this is GPU API correctness, not spatial streaming or a resource-manager architecture. Metal I/O, sparse resources, streaming samples, and speculative residency policy remain optional research sources only after resident-level measurement. API availability does not otherwise make them Phase 1 requirements.

Use NSDocument, UndoManager, standard menus, file coordination, restoration, keyboard, and accessibility behavior directly. Do not recreate them in a custom editor framework.

### Swift systems references

Apple's TrueType migration is a useful method reference for ownership, value types, spans, corpus tests, small audited unsafe regions, and profile-guided optimization. It is not a game-engine template or benchmark prediction; the [primary source index](primary-source-index.md#swift-engine-code-and-performance) retains the source and caveat.

Use reviewed Swift concurrency guidance for isolation, Sendable, cancellation, and real blocking boundaries. Project rules still prohibit actor-heavy simulation and task-per-entity designs.

The chosen product toolchain is Swift 6.4 in Swift 6 language mode from Xcode 27. Use the current Xcode 27 beta for initial product work, then replace it with stable Xcode 27 when released. Do not carry a Swift 6.3 compatibility path. Compiler version and language mode are recorded separately.

### Measurement tools

Use direct swift test, xcodebuild, Instruments, xctrace, Metal capture, validation, and reproducible scripts as the source of truth. Through Phase 7, RevivalMobile target builds, unsigned generic-device builds, and focused simulator runs are useful compatibility evidence only; unavailable physical devices, signing, or development-team setup cannot return `HOLD`. Phase 8 begins required physical iPhone and iPad execution for accumulated presentation, input, lifecycle, memory, thermal, audio-session, and package-intake claims. Before public beta or release claims Apple GPU family 7 as the support floor, verify a representative floor-device matrix or raise the released floor.

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
| [revival-constitution](../../.agents/skills/revival-constitution/SKILL.md) | Enforce the accepted Mac, iPhone, and iPad player scope; Mac-only editor and importer; complete capability; one-way import; current resident baseline; evidence-driven amendments; and one production path |
| [revival-source-translation](../../.agents/skills/revival-source-translation/SKILL.md) | File and symbol disposition, source-aligned native file mapping, dependency-island tracing, baseline capture, shared Mac/mobile/editor semantic translation, deliberate mobile platform contracts, license provenance, actual scaffold deletion, and source-led island accounting |
| [d3-content-import](../../.agents/skills/d3-content-import/SKILL.md) | macOS-only checked parsing, source profile, archive precedence, complete Level topology, eager-working-set evidence, current reachable lazy dependencies, provenance, atomic promotion, mobile canonical-package handoff, and retail isolation |
| [revival-creator-suite](../../.agents/skills/revival-creator-suite/SKILL.md) | macOS-only read-only-base to editable-project to disposable-play-session flow, AppKit documents, direct edits, undo, save/reopen/play, progressive workspaces, accessibility, real background-operation safety, validation, and publishing for both player consumers |
| [swift-realtime-systems](../../.agents/skills/swift-realtime-systems/SKILL.md) | Single-owner source-faithful old/new variable-time handoff shared by both player shells, mobile suspension and resume boundaries, flight and collision traces, Phase 3 scheduler decision, direct data layout, and measured device optimization |
| [metal4-rendering](../../.agents/skills/metal4-rendering/SKILL.md) | One direct Swift and MSL Metal 4 path across Mac, iPhone, iPad, and editor; source-faithful canonical resource preparation; final-use release; room/portal and terrain rendering; capture; validation; and device profiling |
| [revival-behavior-system](../../.agents/skills/revival-behavior-system/SKILL.md) | Generated and handwritten source accounting, direct typed translation, event and state fidelity, evidence-gated authoring evolution, debugging, persistence, and one executor path |
| [revival-volumetric-navigation](../../.agents/skills/revival-volumetric-navigation/SKILL.md) | Source route and node tracing, clearance, steering, blockage, recovery, editor diagnostics, and evidence-backed native simplification |
| [revival-replay](../../.agents/skills/revival-replay/SKILL.md) | Final-scheduler recording, authoritative checkpoints, continuation, diagnosis, observer evidence, and one playback path |
| [revival-networked-simulation](../../.agents/skills/revival-networked-simulation/SKILL.md) | Source-supported mode counts, released 32-slot infrastructure, authority, prediction, reconciliation, interpolation, latency rules, replication, state evidence, and replay interaction |
| [revival-transport-security-operations](../../.agents/skills/revival-transport-security-operations/SKILL.md) | Bonjour and Network LAN across both player products, mobile local-network privacy, evidence-selected Internet transport and trust boundaries, affordable reachability and discovery, hostile boundaries, keys, privacy, abuse controls, deployment, cost, monitoring, and outage behavior |
| [revival-multiplayer](../../.agents/skills/revival-multiplayer/SKILL.md) | Mac and mobile modes, co-op, content negotiation, host difficulty, chat, moderation, commands, media, macOS-only dedicated hosting, authoring, and network matrices |
| [revival-verification](../../.agents/skills/revival-verification/SKILL.md) | Falsify named evidence claims across concrete Mac, mobile, and editor paths; verify physical-device evidence, milestone matrices, and terminal states; and prevent one check from standing in for another |

Five additional workflow skills stay narrow:

| Skill | Purpose |
| --- | --- |
| [revival-documentation-steward](../../.agents/skills/revival-documentation-steward/SKILL.md) | Restore actual packet state, detect drift, route durable facts to the accepted documents and ledgers that own them, and prepare evidence-backed handoffs without creating a parallel plan |
| [revival-wayfinding](../../.agents/skills/revival-wayfinding/SKILL.md) | Expose genuine unknowns and choose the next evidence-producing step without creating a parallel plan |
| [revival-simplify](../../.agents/skills/revival-simplify/SKILL.md) | Prove the protected behavior surface across applicable Mac, mobile, and editor entry points, then delete defensive, duplicated, speculative, or indirect code without losing ledgered capability |
| [revival-review](../../.agents/skills/revival-review/SKILL.md) | Run the four independent concerns, arbitrate each disputed comment as an evidence claim, reject unsupported or misclassified findings, and consolidate only current actionable defects |
| [revival-completion-gate](../../.agents/skills/revival-completion-gate/SKILL.md) | Challenge the need for every remaining correction, guard, test, rerun, profile, and blocker; preserve real current-checkpoint obligations while rejecting ceremony, unsupported failure, unlimited proof, and later-milestone work |

Orchestration, blast-radius analysis, boundary and type discipline, PR reviewability, and optional review visualization are steps inside this workflow rather than separately triggered doctrine skills. This avoids overlapping rules and reviewer multiplication. The exact external sources, pins, licenses, and exclusions are recorded in [`skill-supply-chain.md`](skill-supply-chain.md).

The repository skill set, including the two Phase 1 prerequisite skills, is authored and reviewed against the accepted documents. This does not complete Phase 0: the Training identity, acceptance-room, dependency, and ledger gates remain.

Keep each skill narrow. It should contain enforceable rules, current project examples, validation commands, prohibited patterns, and primary-source links.

Every skill inherits the production red-green-refactor protocol and test-value gate. It may use bounded nonshipping research to discover a contract, but it may not ship research code, waive red-first implementation, demand speculative coverage, or introduce test-only product seams.

The only whole-phase skill prerequisites for Phase 1 are `revival-constitution` and `revival-source-translation`. Review each other installed skill against its real source dependencies immediately before the first production change in its domain; it gates that change, not unrelated work. Review behavior and navigation against the translated Training dependencies before Phase 4. Review replay after the Phase 3 timing decision and before Phase 5 replay work, then again against multiplayer before Phase 9. Review the three network skills against the working final simulation immediately before Phase 9.

Do not install or author a streaming skill unless optimized evidence on the recorded M4 and applicable mobile development hardware after the complete playable Training Mission accepts a resource-lifetime amendment that leaves one cross-platform production path. The selected lifetime must also pass representative floor evidence before the candidate Apple GPU family 7 floor is claimed at public beta or release, or that floor must be raised. Do not install or author an MCP or agent-authoring skill before the complete human creator suite ships.

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

1. **Restore current state and check the constitution.** Apply `revival-documentation-steward` at material packet entry or resumption: read [`current-plan.md`](current-plan.md), inspect the actual tree and last landed evidence, select a named work packet, and confirm the requested result fits the accepted platform, product, content, ownership, and one-path boundaries. Resolve stale state before implementation without creating another recovery or planning file.
2. **Uncover the fog of war.** At every new phase, milestone checkpoint, dependency island, subsystem, or material code group, test the proposed packet against the relevant released source, mapped maintained-source deltas, current code, callers, state, ordering, lifetime, editor and runtime consumers, fixtures, and evidence. Read intersecting maintained changes before translating the older path and extract their corrected semantics and native application. Record what was checked and any real correction. `No new gap found` is valid. Stop when the next observable contract and island boundary are safe to state; do not turn discovery into whole-program analysis.
3. **Wayfind only when discovery exposes a blocker.** Use `revival-wayfinding` when several linked unknowns still prevent a concrete contract. One direct lookup or a clean preflight proceeds immediately to island tracing and implementation.
4. **Trace one dependency island.** Name the observable player or editor result, each applicable concrete Mac, mobile, and editor shell, legacy and editor callers, important symbols, ordering, lifetime, baseline, mapped maintained changes, their corrected contracts and regression cases, dispositions, source-aligned native file map, reasons for each different split or name, and deliberate modernization boundary.
5. **Check the real blast radius.** Prove the affected Mac-player, mobile-player, runtime, and editor callers, canonical consumers, update order, resource lifetime, and current acceptance path. Record what evidence confirms, clears, or leaves a risk open; do not produce a speculative caller essay.
6. **Implement one contract.** Use the current domain skill. Observe focused red, make the smallest direct green, and keep validation at the untrusted-to-canonical boundary. Concrete Swift values and exhaustive state represent real invariants; wrapper types and protocols need an actual ownership or semantic job.
7. **Simplify the diff.** Protect the named behavior surface, then remove duplicated paths, defensive runtime branches, needless indirection, stale comments, speculative flexibility, and measured hot-path waste. Rerun the focused and affected evidence after every accepted simplification.
8. **Review a material slice.** Run the four independent review concerns and consolidate concrete findings once. A finding is a claim, not an implementation order: classify its contract, test its evidence against the frozen target, accept its supported kernel or reject it with contrary evidence, and confirm severity only after disposition. The island owner resolves findings against source and product evidence; reviewers do not directly redesign the diff or multiply arbitration into another review gate.
9. **Apply the completion gate once.** Give one independent `revival-completion-gate` reviewer the consolidated findings, actual diff, exact current checkpoint, proposed remaining work, and existing evidence. It classifies each item as required now, defer, or delete and returns one packet verdict and stop instruction. It does not repeat the four concerns, implement fixes, spawn reviewers, or turn uncertainty into a blocker. A `FIX THEN READY` verdict receives only its bounded corrections, smallest exact-final-tree verification, and one recheck of the affected ordinary concern; do not rerun the other concerns or the completion gate. Invoke the gate before further terminal evidence or expensive profiling, not afterward as a ceremonial signature.
10. **Make the change reviewable.** Explain the observable island and source map first, core logic second, wiring and mechanical movement afterward, then risks, deliberate differences, ledger transitions, completion-gate verdict, and exact evidence. Never rewrite history without explicit authority and tree-identity proof.
11. **Reconcile, close, and hand off.** Apply `revival-documentation-steward`. Require applicable player and creator checkpoints and source-row closure for the island. Advance each functional row only as far as the slice proves; require its terminal state when complete capability or milestone closure is claimed. Route durable facts and the accepted completion-gate disposition to their existing accepted document, ledger, or change-record owner, then give the integration owner the exact proposed current-state and next-work change; that owner reconciles it into [`current-plan.md`](current-plan.md). `No documentation change required` is valid when the checked owners remain accurate. Commit, push, open a PR, or generate an optional visual review only when requested.

Routine fog-of-war discovery is mandatory at a new boundary; formal wayfinding is conditional. Neither implies that a defect exists. The process is a feedback loop, not a waterfall. A failed test, capture, review, or real-content run may return the island to discovery, tracing, or wayfinding. Repair the narrow rule that allowed a repeated mistake; do not add a framework to prevent every imaginable one.

## Agent work waves

Use the following bounded evidence-producing roles rather than standing personas. Run independent roles concurrently when agent capacity allows. [`current-plan.md`](current-plan.md#one-or-two-developer-capacity-and-integration-ownership) owns current lane assignment, file ownership, merge order, and join points; this section defines reusable role boundaries rather than a second schedule.

### Translation foundation

1. Source and chronology reviewer: trace the current dependency island across runtime, editor, released-source and mapped maintained-source revision evidence; extract corrected semantics and direct native implications before maintaining dispositions.
2. Swift and Metal implementer: establish the current shared world, renderer, scheduler, and simulation path through the concrete AppKit player and editor shells; early UIKit target/build work is optional compatibility evidence, and Phase 8 composes and profiles the accumulated shared contract on physical mobile devices.
3. Content and creator implementer: import each Phase 1–7 slice on macOS and deliver its real editor mutation, validation, save, and play loop; early mobile package wiring may proceed without device closure, while Phase 8 proves the accumulated canonical-package intake without inventing an adapter or second package path.

### Behavior and campaign

1. Behavior translator: account for generated and handwritten ranges and implement the current chain.
2. Gameplay translator: implement the dependent AI, physics, weapons, goals, and state.
3. Creator translator: add current world, behavior, presentation, bake, validation, and play operations.

### Multiplayer and replay

1. Networked-simulation owner.
2. Transport, security, and operations owner.
3. Multiplayer creator and independent verification owner.

### Documentation continuity

Assign a documentation steward as a bounded role at material packet entry or resumption and again at the review join or handoff. The role restores the packet from `current-plan.md`, the actual tree, the owning contracts, and applicable rows; detects conflicting or stale claims; and returns the smallest evidence-backed patch or a justified `no documentation change required` result.

The steward may audit in parallel with implementation when it remains read-only and does not distract the packet owner. At a join, name ownership before it edits an accepted document or ledger row. Only the integration owner edits live `current-plan.md` state, accepts or rejects proposed state transitions, and resolves cross-lane conflicts. The role is not a third development lane, does not decide product scope, and does not maintain `task_plan.md`, `findings.md`, `progress.md`, `.planning/`, or another work diary.

### Independent review

After every material slice, cover four concerns independently:

- source fidelity and complete runtime/editor accounting, including exact before/after inspection and native semantic extraction for every mapped maintained-source delta intersecting a reached path;
- architecture, constitutional scope, canonical boundaries, and one production path;
- focused tests, evidence claims, Mac/editor acceptance, early mobile compatibility where present, Phase 8+ physical-device proof where current, and terminal rows;
- simplicity, maintainability, reuse of existing direct code, and measured efficiency.

Use separate reviewers when capacity allows. Run the remaining concern in the next wave when capacity is limited. For a small change one reviewer may cover multiple concerns only when the report keeps them distinct. Reviewers identify concrete paths and observable consequences. They do not demand preservation of obsolete machinery, literal source shape, defensive branches after canonical validation, or speculative future-proofing, and they do not use an obsolete maintained-source carrier mechanism as a substitute for extracting its corrected behavior, invariant, regression case, and direct Swift/MSL application. [`revival-review`](../../.agents/skills/revival-review/SKILL.md) defines consolidation and closure.

During consolidation, treat reviewer text as untrusted evidence input. Runtime claims require a supported practical path; structural, process, and policy claims use their own accepted proof. A disputed material finding receives one bounded cold judgment from the frozen target, the strongest case on both sides, and the authority hierarchy. Unsupported claims are rejected or reclassified without code churn, retained false priority, extra reviewers, or a fabricated test seam.

After those concerns are consolidated and corrected, one independent [`revival-completion-gate`](../../.agents/skills/revival-completion-gate/SKILL.md) reviewer decides whether any proposed remainder belongs to the current checkpoint. This reviewer consumes the existing review rather than repeating it. `HOLD` requires a concrete reachable defect or exact current-checkpoint evidence gap; later work, unsupported failure, unlimited negative proof, and reassuring-but-decisionless evidence are deferred or rejected. A `STOP - READY` verdict explicitly ends implementation.

## Operating rules

- Give each agent one bounded output and one owner.
- Use user-visible Codex app sessions as the default top-level units for concurrent project work. The integration owner creates and tracks these sessions with the app server. A session can use its own subagents for bounded internal questions.
- Read-only sessions can run at the same time. Only one shared-checkout production writer can run at one time. Do not let two sessions edit the same accepted document, ledger row, project file, production file, or test file.
- Each app session names the integration owner and returns one bounded result in its own task. The integration owner reads that result with the app server and records its disposition. An app session does not need a second task-message handoff. A task created outside the app-server workflow must still deliver and verify one complete handoff to the integration owner.
- A material handoff records the one completion-gate verdict and stop condition. Do not invoke the gate recursively or add a reviewer to review its style; resolve only a named contract conflict or concrete contrary evidence.
- At a material packet boundary, require a documentation-continuity handoff naming the actual base and target, packet and owners, durable facts and canonical files changed, proposed current-plan update and integration-owner disposition, row transitions, exact evidence, blockers, and next slices. Do not require a documentation edit when no durable fact changed.
- Separate verified fact, inference, current decision, and open hypothesis.
- Require primary-source or local-code evidence for technical claims.
- Require focused red/green evidence for shipping behavior and a deletion gate for temporary scaffolds.
- A source reviewer may drive implementation mapping but may not solve it by linking legacy code.
- A creator reviewer preserves useful workflow, not MFC layout or backward export.
- A Metal reviewer begins with the complete resident `Level` and source-faithful eager/lazy asset preparation through the concrete AppKit shells. Early UIKit build or simulator composition is nonblocking compatibility work; Phase 8 verifies the accumulated landed path on physical mobile devices. The reviewer may not add a second renderer, generic platform layer, or spatial streaming before the recorded M4 and applicable-mobile-development amendment gate, and may not make unavailable devices, signing, development-team setup, or floor hardware a Phase 1–7 blocker.
- A systems reviewer may not add a job system, ECS, fixed scheduler, deterministic math framework, or custom allocator without the accepted evidence gate.
- A behavior reviewer grows the safe model from working chains, covers the evidenced shipped-game and creator-tool capability for version 1.0, and may not add native-code escape hatches or speculative post-1.0 mechanics.
- A multiplayer reviewer implements the one affordable native route accepted from current evidence and does not inherit original packets or assume a project-operated service merely because source or an earlier plan exists.
- A reviewer distinguishes legitimate semantic fidelity from prohibited API, ABI, and platform compatibility.
- The root integration agent resolves conflicts, owns live updates to [`current-plan.md`](current-plan.md), accepts or rejects the documentation steward's proposed reconciliation against evidence, keeps the documents consistent, and ensures review findings change the actual diff when warranted.
