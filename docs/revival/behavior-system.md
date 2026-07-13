# Behavior system

- Status: accepted
- Date: July 13, 2026
- Authority: binding gameplay-behavior and authoring contract

## Historical boundary

Osiris was Descent 3's native compiled-module scripting runtime. It loaded game, mission, and level modules; bound scripts to objects; dispatched object, trigger, and level events; managed timers; exposed a large engine function table; and persisted script-owned state. It was not a bytecode virtual machine or a level editor.

DALLAS was the visual event, condition, and action editor layered over Osiris. It authored structured logic, generated C++ and message tables, invoked a compiler, and produced native modules. Handwritten code could extend the generated output.

The revival replaces both systems. It preserves their useful behavior and authoring power without preserving native modules, function tables, generated C++, calling conventions, memory callbacks, or compiler integration.

## Decision

`BehaviorGraph` is the canonical visual source representation. A checked compiler turns it into a compact immutable `BehaviorProgram`. `RevivalCore` executes that program deterministically inside the fixed-step simulation.

Content packages contain data and instructions from the project-defined behavior language. They never contain native executable code.

```text
BehaviorGraph source
        |
        v
 validate and compile
        |
        v
BehaviorProgram + debug map
        |
        v
deterministic RevivalCore executor
```

This is a small purpose-built interpreter. It is not an Osiris-compatible virtual machine. The instruction model exists because complete creator functionality requires more expressive power than a closed enum list of stock-campaign actions.

## Language surface

The behavior language supports:

- typed values, variables, constants, references, and expressions;
- event handlers, conditions, branching, sequencing, and bounded iteration;
- reusable functions and typed subgraphs;
- integer-tick timers and scheduled events;
- deterministic random choices through the simulation-owned seeded generator;
- object, trigger, level, campaign, game-mode, and session scopes;
- persistent state explicitly declared by the author;
- engine queries and commands for the complete supported game domain;
- structured errors, source locations, debug metadata, tracing, breakpoints, and inspection.

Initial value families include booleans, signed integers, finite `Float32` values, vectors and orientations built from `Float32`, ticks, strings or localization keys, enums including the fixed five-case `Difficulty`, and typed `ContentKey` or runtime-entity references. Difficulty is immutable authoritative session configuration: behavior may query it but may not mutate it. Each floating domain declares its valid range, conversions, comparison semantics, and out-of-range behavior. Import, authoring, behavior commands, saves, replays, and network inputs reject NaN and infinity. Canonical encoding and hashing normalize negative zero. An operation that produces an invalid result fails deterministically at its source node; it does not leak an exceptional value into state. The type checker rejects mismatched scopes and reference kinds before play.

The language has one bounded stable-order collection value for typed query results. A runtime entity reference carries an ID and generation. A stale or destroyed reference becomes `.none`; an existence query can branch on it, and a command that requires a live entity fails with a deterministic source-linked error unless that command explicitly defines missing-target behavior. An active iteration captures its ordered membership when it begins. New entities do not join it, and destroyed entries become `.none`. Saves and replays preserve reference generations and collection order.

The language does not expose pointers, arbitrary memory, files, sockets, threads, process execution, dynamic library loading, Swift reflection, unrestricted calls into Apple frameworks, or world-streaming demand, progress, residency, memory, or I/O state. Behaviors can declare typed teleports, spawns, cameras, and cinematics whose destinations become publisher-validated destination envelopes, but execution never branches on whether their presentation payload happens to be resident.

## Events and ownership

Events are typed data delivered through one ordered FIFO owned by `RevivalCore`. The ledger defines payloads and native counterparts for fixed-tick and AI updates; room and portal transitions; timer fire, cancellation, repetition, and owner loss; trigger, use, and collision; object creation, child death, destruction, respawn, and player death; damage; AI notifications; goals and goal items; matcens; inventory and doors; refueling and room roles; adaptive-score region, role, transition, and completion state; in-game cinematic start, stop, completion and interruption; movie, briefing, and presentation state; level and campaign progress; multiplayer lifecycle and bounded game-mode command input; and custom project-defined events.

Behavior can be attached at several scopes:

- an object instance or archetype;
- a trigger;
- a level;
- a campaign;
- a multiplayer game mode or session.

Dispatch order is explicit in compiled content. An event may name an ordered chain such as instance, archetype, level, campaign or game mode, and engine default. Each handler returns a typed disposition with two independent decisions: continue or stop the remaining handlers, and preserve or suppress the engine default action. Default suppression is sticky for that event. Events without an engine default ignore the second decision. This restores interception and composition without copying Osiris flags or module order.

Ordinary emitted events enter the FIFO and return no value. A typed targeted request is a separate bounded operation for behavior that needs an immediate accept, reject, or typed reply. It addresses one declared owner, executes its handler chain synchronously under the same operation and call-depth budgets, and returns the reply and disposition. Requests cannot bypass scope, authority, or type checks.

## Queries and commands

Queries read typed simulation state. Commands request validated changes through `RevivalCore`. A successful command changes logical world state immediately, so later instructions, targeted requests, and lower-priority handlers in the same dispatch observe it. Structural storage changes commit at the event boundary, but queries use the logical overlay and active collection iterations keep their captured membership. This preserves deterministic visibility without mutating a collection during traversal.

The domain surface grows with completed runtime and creator capabilities and must ultimately cover the functional-completeness ledger: objects, players, five-level difficulty queries, rooms and typed room roles, terrain, doors, AI, paths, matcens, goals, inventory, weapons, effects, audio, typed adaptive-score region and role commands, player markers, in-game cinematics, presentation, camera modes, campaign flow, and multiplayer rules and declared command events.

The public language surface is not limited to operations found in the stock campaign. Stock translation determines implementation order and provides regression cases. Creator completeness determines the final language boundary.

Prefer composition from existing operations. Add a domain operation when composition would be unclear, slow, impossible to validate, or substantially larger than the direct operation. Do not add arbitrary native-code escape hatches.

## Execution semantics

Historical `EVT_INTERVAL` logic follows one translation rule. Continuous authoritative logic executes once per 120 Hz simulation tick. Multiplication by historical `Frametime` becomes a declared rate applied to one tick or an integer-tick duration. Lower-frequency polling becomes an explicit integer-tick schedule. Historical frame counters are translated from their intended elapsed time and observable behavior. Equivalent event polling becomes a typed event, and presentation-only work leaves authoritative behavior state. The language exposes no variable delta and no emulated legacy frame cadence. Every affected stock translation records the chosen mapping and its checkpoint evidence.

- Behavior execution runs on the single simulation owner at the fixed 120 Hz tick.
- Handlers and instructions run in declared deterministic order.
- Newly emitted ordinary events enter the FIFO after the current event; only explicit targeted requests use the bounded synchronous request path.
- Timers use integer simulation ticks and support one-shot or repeating schedules, explicit cancellation, and declared cancel-on-owner-loss or cancel-on-owner-death notification.
- A handler has a declared run policy of once, exact count, or repeat. The compiler stores and persists its execution count.
- Iteration requires a statically or dynamically enforced finite bound and a stable item order.
- Development begins with a fixed ceiling of 4,096 behavior operations per simulation tick. Event dequeue, targeted request, query, command, branch, function call, and loop step consume declared costs.
- Exceeding the ceiling stops the scenario with a deterministic error containing the tick, behavior key, source node, call trace, and last event. Work never spills silently into another tick.
- Call depth, collection size, persistent storage, emitted-event count, and timer count have explicit validated limits.

The compiler may flatten graphs, intern constants, resolve `ContentKey` values to dense package-local IDs, and select compact instructions. Those changes cannot alter declared order or observable behavior.

Phase 5, Phase 8, and Phase 9 stress tests measure the 4,096-operation ceiling against stock behavior, reusable object behavior, an independently authored campaign, and multiplayer modes. The project either ratifies or raises one deterministic platform ceiling before release. The ceiling is a runtime safety constant, not serialized package semantics, and cannot justify deleting a ledgered capability.

## Multiplayer authority

Solo play and the multiplayer host both own authoritative simulation. Object, trigger, level, campaign, and game-mode behaviors that can mutate game state execute only on that authority. Clients receive replicated results and may run separately declared presentation-only behavior that cannot issue authoritative commands. Any prediction uses explicit built-in simulation rules and is corrected against authority; a content graph never gains hidden client-side mutation rights.

Every historical `EVT_GAME_*` and `EVT_CLIENT_*` use receives an explicit native classification: authoritative simulation event, replicated presentation event, local application input or UI event, or excluded obsolete mechanism with a recorded reason. The client prefix does not automatically make an event safe or presentation-only. The stock translation manifest records the classification and the required replication or local-input boundary. No raw historical event number enters canonical content.

These rules sit above the selected Phase 9 Network-framework QUIC transport. They fix behavior ownership so transport work cannot create a second scripting model.

## Authoring and debugging

`RevivalEditor` edits `BehaviorGraph` directly. Nodes, ports, variables, queries, commands, events, scopes, handler disposition, and once, count, or repeat run policy are typed. The editor provides searchable operation documentation, validation at edit time, copy and paste, reusable subgraphs, source-level breakpoints, step and continue controls, event traces, watched values, and links from runtime errors to graph nodes.

The graph is the source of truth. Generated `BehaviorProgram` files are derived build products and are never hand-edited. Textual diff and merge support may accompany the visual view, but the project does not require authors to maintain generated code.

## Stock translation

The GPL-released DALLAS-generated and handwritten C++ sources are behavioral evidence for Training, base, secret, Mercenary, reusable and default object behavior, and stock multiplayer game modes. The normative default is pinned community commit `156cba8aafd997d27deb0902ba6026bcdcc1cfaf`, the same source baseline that supplied the successful M4 reference modules. Retail 1.4 executable behavior is comparison evidence for ambiguous cases, not a second semantic baseline. Translation inspects complete generated and handwritten sources, including native game modules, not only the DALLAS block for a level.

All 48 generated level-script sources contain a versioned `$$SCRIPT_BLOCK` tree that DALLAS itself reloaded, plus explicit custom-script ranges. `DallasFuncs.cpp` carries the global action, query, and enum metadata; `DallasFuncs.h` carries tagged aliases; level-local custom blocks add their own declarations. A nonshipping source-analysis tool parses those pinned GPL inputs into explicitly noncanonical draft `BehaviorGraph` data and an unresolved-operation, binding, message, and source-range report. Deterministic extraction is covered by synthetic fixtures and exact source hashes.

The extractor makes no authority, interval, defect, error, or semantic decisions. It never runs in `D3Import`, never becomes a public legacy import format, and never adds a production target. Reviewers compare each draft with generated C++, custom blocks, handwritten modules, message and localization references, active runtime behavior, and the approved native rules. Only a reviewed graph with complete generated-node coverage, accounted custom and handwritten ranges, resolved operations and bindings, and observable checkpoints may enter `StockBehaviorCatalog`.

Known defects do not become requirements automatically. Every intentional community fix, retail difference, or new native correction receives one explicit ledger decision and observable checkpoint. The importer never loads retail DLLs to resolve a disagreement.

Difficulty translation follows active producer-consumer paths, not comments or unused globals. In particular, the historical `aObjApplyDamage` documentation says its damage is difficulty-scaled while its implementation emits `GD_SCRIPTED`, and the generic damage path excludes scripted damage from scaling. That conflict requires an approved native decision and checkpoint before translation. `Diff_player_damage` and the stale global `Difficulty_level` path receive no production code or tests unless further source or runtime evidence establishes a reachable contract.

Every translated behavior records:

| Field | Purpose |
| --- | --- |
| Scope identity | Campaign and level, module role, package, behavior owner, object archetype, or multiplayer game mode |
| Retail content hash | Exact proprietary input when applicable |
| Historical source path and hash | Behavioral provenance |
| Baseline commit | Default source semantics used by the translation |
| Observed retail or community difference | Conflicting evidence, if any |
| Approved native decision | One selected behavior and its rationale |
| Generated DALLAS ranges | Structured behavior covered |
| Handwritten ranges | Logic requiring direct analysis |
| Events, values, queries, and commands | Language coverage |
| Authority and historical event side | Authoritative, replicated presentation, local application, or explicitly excluded mapping for every server/client event used by the scope |
| `ContentKey` bindings | Durable canonical references |
| Observable checkpoints | Translation evidence |
| Status | Not started, translated, playable, or verified |

Translated sources may enter Git only when their license permits it and they contain no proprietary media. Dialogue, briefing text, movies, audio, textures, and other retail media remain in local imported packages.

Reviewed stock translations form the versioned `StockBehaviorCatalog` bundled and signed with `D3Import`. Its manifest covers every required level, campaign, module role, package default, owner, object archetype, game mode, and session scope and records source and graph hashes. Import resolves its declared `ContentKey` bindings against the owned canonical content and writes compiled programs; it never accepts an external executable or behavior-source path.

## Persistence and replay

Save snapshots store declared behavior variables, handler execution counts, active timers, durable operation handles, authoritative difficulty, logical cinematic and adaptive-score state, campaign and session state, and the simulation tick. A long-running engine operation returns a typed durable handle and later emits completion or cancellation; behavior execution never suspends an interpreter stack across ticks. Saves do not store call continuations, interpreter pointers, editor state, native memory, audio-engine or decoder state, or opaque script payloads.

Each behavior graph has a durable `ContentKey` and semantic revision. A save or replay binds those values and one `simulationSemanticRevision` rather than package-local IDs or incidental encoding bytes. Published creator formats receive deliberate versioning and migrations after public release.

Replay records resolved tick inputs, authoritative difficulty and other session configuration, game-affecting player or host commands, content identities, seeds, and nondeterministic boundary results. Ordinary chat text is presentation data and is excluded from authoritative hashes and recordings by default. Authoritative simulation re-execution must reproduce the same declared canonical state hashes on the supported architecture. Multiplayer transport timing, client prediction history, and presentation traces reproduce only the session evidence declared by the Phase 9 design; they are not silently promoted into canonical state. One replay container and playback path carry both kinds of evidence.

## Extensibility

The mod SDK is the documented creator contract for canonical projects, behaviors, packages, validation, and publishing. Game-team content and third-party content use the same behavior language. There is no binary plugin ABI and no privileged project-only scripting path.

If a future capability cannot be expressed safely, extend the typed language or `RevivalCore` domain surface. Do not bypass the package sandbox with native modules.

## Verification

Tests cover draft-source extraction, unresolved-operation reporting, parsing, type checking, graph validation, compiler output, handler disposition, command visibility, targeted requests, timer lifetime, run policies, authority and historical server/client event classification, stale references, stable collections, Float32 boundaries, focused five-level difficulty queries, in-game cinematic commands, adaptive-score commands, historical interval translation, bounded multiplayer command events, durable operations, operation accounting, cycles, bounded iteration, call limits, persistence, errors, debug source maps, and deterministic replay. Interval-heavy tests cover rate equivalence, timer boundaries, long-run drift, and measured operation counts. While 4,096 is the active ceiling, direct and multi-handler event cycles must fail at exactly that operation without hanging or advancing another tick.

Every runtime operation has focused synthetic tests. Stock levels, reusable and default object behaviors, stock game modes, and independently authored projects add end-to-end checkpoints. A behavior is complete only when the editor can author it, the compiler can reject invalid forms, the runtime can execute it, the debugger can identify failure, and a package can publish it.
