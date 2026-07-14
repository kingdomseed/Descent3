# Behavior translation and authoring

- Status: accepted, amended
- Date: July 14, 2026
- Authority: binding current behavior-transfer and eventual creator contract

## Historical boundary

Osiris was Descent 3's native compiled-module behavior runtime. It loaded game, mission, level, and object modules; dispatched events; exposed engine functions; managed timers; and persisted module-owned state.

DALLAS was the visual event, condition, and action editor layered over Osiris. It stored a structured tree, generated C++ and message tables, invoked a compiler, and permitted handwritten code around generated ranges.

The revival must preserve useful event, condition, action, timer, state, debugging, persistence, and authoring capability. It does not preserve DLL loading, native package code, ABI tables, generated C++, compiler invocation, or unrestricted engine access.

## Current decision

Do not design the complete replacement interpreter before a real stock behavior runs.

Phase 4 translates the first Training door, trigger, robot, weapon, goal, message, and presentation chain into ordinary typed Swift functions and small explicit state values inside RevivalCore. This is the canonical current runtime form, not predeclared disposable scaffolding. It keeps event order, conditions, variables, timers, engine calls, and handwritten ranges visible.

The direct translation is tracked in the source-translation ledger and remains valid unless concrete human-authoring cases prove it inadequate. Before proposing a different source representation or executor, working translated evidence must cover:

- at least one generated DALLAS chain;
- at least one handwritten or custom range;
- at least one timer or persistent-state chain;
- at least one presentation-oriented chain.

One chain may cover several categories. If that evidence exposes a real authoring or safety limitation, the project may ratify the smallest replacement that can:

- express the verified stock chains without special cases;
- be authored and debugged by people;
- serialize safely in native projects and packages;
- grow beyond stock campaign operations;
- execute without native code or unrestricted platform access;
- preserve the current tests and observable checkpoints.

An accepted replacement migrates the working chains and removes the superseded runtime path. The project does not require that rewrite in advance or keep direct and interpreted execution as permanent parallel modes.

BehaviorGraph and BehaviorProgram remain possible names if the evidence eventually calls for source and compiled forms, not preapproved types, a complete VM, instruction set, scheduler, collection model, or operation budget.

## Translation unit

Translate one complete behavior dependency chain at a time:

1. identify its module, DALLAS block, custom ranges, handwritten ranges, messages, bindings, and engine functions;
2. trace event producers, dispatch order, conditions, state, timers, and side effects;
3. capture observable checkpoints in the reference engine or source;
4. implement the smallest typed Swift state and functions that reproduce the chain;
5. expose the current configuration and diagnostics in RevivalEditor;
6. save, reload, play, and verify it;
7. record every deliberate difference and close the involved source ranges.

Do not translate generated DALLAS control flow while ignoring handwritten code outside the block. Do not add an operation merely because it exists in the global function table; add it when a real translated or creator scenario needs it.

## Current semantics

The first translated chains use:

- explicit typed events for the events they actually consume;
- ordinary Swift values for booleans, integers, finite Float32 values, vectors, content references, entity references, and current timers;
- direct validated RevivalCore queries and commands;
- explicit stable dispatch order copied from the source path;
- one simulation owner and no task, actor, or thread inside behavior execution;
- the simulation-owned random source when the original chain uses randomness;
- explicit state included in new saves when that state affects continuation.

Do not prebuild:

- a universal event bus or complete event enumeration;
- synchronous request and reply machinery;
- a general stable collection value;
- entity generations for references that do not need them;
- a 4,096-operation ceiling or speculative call, loop, timer, and storage budgets;
- a complete multiplayer authority type system;
- a bytecode optimizer or generalized compiler pipeline.

Add a bound when an actual untrusted creator construct or reproduced cycle needs one. The bound protects the reachable operation and receives a focused test.

## Timing

Historical interval handlers run once per historical frame and receive elapsed-time semantics through the surrounding engine.

During the explicit-delta translation phase:

- pass the historical old `Frametime` and pre-update `Gametime` directly to translated interval logic, preserving the later post-cap time update and pause ordering;
- preserve source ordering, rate multiplication, timer boundaries, and observable drift;
- record frame-count behavior that is distinct from elapsed-time behavior;
- keep presentation-only work outside authoritative state where that distinction already exists.

After Phase 3 selects the final timing model, translate every existing interval consumer once:

- bounded variable-delta remains explicit; or
- elapsed-time rates and timers become the chosen fixed-tick equivalents.

Delete the superseded scheduler and its behavior adapters. Do not retain a legacy timing mode or claim fixed-tick parity without reference evidence.

## Engine queries and commands

Queries read typed RevivalCore state. Commands request named validated state changes. Start with the operations required by the current chain: objects, players, rooms, doors, triggers, AI, paths, goals, inventory, weapons, sound, messages, cameras, cinematics, score state, campaign flow, and difficulty as they appear.

Prefer composition from existing operations. Add a direct domain operation when composition would obscure source behavior, duplicate substantial logic, or prevent useful validation. Never add arbitrary Swift, file, socket, process, pointer, reflection, framework, or native-module access to project content.

Presentation loading and residency are not behavior state. Behaviors may request a teleport, spawn, camera, or cinematic once those are real domain commands; they never inspect resource readiness or memory.

## Stock evidence

The pinned GPL source is the default stock behavior baseline. Retail execution is comparison evidence for ambiguities.

The retained tree includes 48 generated campaign sources with reloadable SCRIPT_BLOCK structure among 55 built modules, plus custom and handwritten ranges. DallasFuncs metadata describes a broad action, query, and enum vocabulary, but metadata presence does not prove a reachable stock use.

A nonshipping extractor may recover DALLAS structure and source ranges into a review report. Its output is draft evidence, not canonical product behavior. It does not run inside D3Import or RevivalEditor, mark translations approved, or generate shipping code.

Every translated chain records:

| Field | Purpose |
| --- | --- |
| Scope and owner | Level, campaign, object, trigger, game, or mode responsibility |
| Source paths and hashes | Generated, custom, and handwritten provenance |
| Baseline commit | Default inspectable semantics |
| Events and order | Producers, handlers, default behavior, and ordering |
| State and timers | Values that affect continuation |
| Queries and commands | Actual engine surface used |
| Content bindings | Durable references required by the chain |
| Observable checkpoints | Runtime and editor evidence |
| Deliberate differences | Approved correction or modernization |
| Native form | Direct typed functions or a later evidence-ratified representation |
| Status | Not started, translated, playable, or verified |

Known defects and dormant fields do not transfer automatically. Each correction records a decision and checkpoint.

## Authoring evolution

The first editor behavior surface may be a direct typed inspector and trace over the translated Swift chain. It does not need a graph canvas before graph structure has real operations.

As working chains establish a reusable authored behavior model, RevivalEditor provides:

- typed events, values, conditions, actions, variables, timers, functions, and composition as real needs establish them;
- source and content reference validation;
- search, documentation, traces, breakpoints, watched values, and source-linked errors;
- save, reopen, playtest, publishing, and deterministic scenario evidence;
- explicit authoritative and presentation roles when multiplayer work reaches those chains.

The authored form is the truth. If the accepted design later has compiled or generated data, that output is derived and never hand-edited; authors do not invoke a native compiler.

## Persistence, replay, and multiplayer

Save the smallest behavior state required to continue the current translated world: relevant variables, execution counts, timers, durable operation state, and content identity. Do not store interpreter pointers, call stacks, framework objects, or opaque legacy payloads.

Replay and multiplayer semantics are ratified after the final timing and behavior models exist. The host remains authoritative for game-changing behavior; clients may later execute explicitly presentation-only work. Historical game-side and client-side events are classified one by one rather than inherited from their names or numeric IDs.

Add compatibility revisions when a released save, replay, behavior project, or package creates a real promise. During development, reimport or republish may replace unreleased formats.

## Extensibility

The complete mod SDK eventually documents the canonical behavior source, safe domain surface, validation, debugging, packages, and publishing used by first-party content.

If a later creator capability cannot be expressed safely, extend the typed domain model. Do not restore native modules or create a privileged project-only escape hatch.

## Verification

For each current chain, tests and evidence cover:

- complete generated and handwritten source-range accounting;
- event order, conditions, state changes, timers, random choices, and engine effects;
- explicit-delta behavior followed by the selected final-timing conversion;
- save/load continuation and source-linked failure;
- editor configuration, trace, playtest, and package closure;
- the exact checkpoint that justifies each deliberate difference;
- migration and deletion evidence if an accepted authored executor replaces direct typed functions.

Compiler, graph, budget, authority, and debug tests are added with the production mechanisms they protect, not as speculative coverage of an imagined complete language.
