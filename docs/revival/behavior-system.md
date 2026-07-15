# Behavior translation and authoring

- Status: accepted, amended
- Date: July 15, 2026
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

Any later source or executor types are named only when an evidence-backed amendment selects their real responsibilities. Possible future names are not current architecture.

## Translation unit

Translate one complete behavior dependency chain at a time:

1. identify its module, DALLAS block, custom ranges, handwritten ranges, messages, bindings, and engine functions;
2. trace event producers, dispatch order, conditions, state, timers, and side effects;
3. capture observable checkpoints in the reference engine or source;
4. write one focused automated contract and observe its intended failure;
5. implement the smallest typed Swift state and functions that make that contract pass;
6. expose the current configuration and diagnostics in RevivalEditor;
7. save, reload, play, and verify it through the applicable integrated paths;
8. refactor without changing the protected result, record every deliberate difference, and close the involved source ranges.

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

Historical interval handlers run once per historical frame and receive the old `Frametime` and pre-update `Gametime` through the surrounding engine. Phase 3 captures that ordering, rate multiplication, timer boundaries, frame-count behavior, and observable drift before selecting the one final scheduler.

The first Phase 4 behavior chain implements that selected scheduler directly:

- bounded variable delta receives the ratified explicit values and ordering; or
- fixed-tick logic uses the accepted elapsed-time, rate, and timer equivalents.

No production behavior path precedes that decision. Phase 3 timing characterization may use a disposable nonshipping harness, which is removed before Phase 4. Presentation-only work remains outside authoritative state where the source already supports that distinction.

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
| Ledger state | Use the source-translation ledger states: seed, traced, translating, native-running, verified, replaced, excluded, or deferred |

Known defects and dormant fields do not transfer automatically. Each correction records a decision and checkpoint.

## Authoring evolution

The first editor behavior surface configures the bindings, parameters, and explicit state consumed by the translated Swift chain and provides source-linked inspection, trace, and failure navigation. Its control flow remains canonical direct typed Swift. It does not introduce a graph canvas or claim a complete authored language.

If working human-authoring cases establish the need for a reusable authored behavior model, RevivalEditor adds:

- typed events, values, conditions, actions, variables, timers, functions, and composition as real needs establish them;
- source and content reference validation;
- search, documentation, traces, breakpoints, watched values, and source-linked errors;
- save, reopen, playtest, publishing, and deterministic scenario evidence;
- explicit authoritative and presentation roles when multiplayer work reaches those chains.

When an authored form is accepted, it is the truth. If that design has compiled or generated data, the output is derived and never hand-edited; authors do not invoke a native compiler.

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
- behavior under the selected final scheduler, with the historical explicit-delta result retained as characterization evidence and every deliberate timing difference recorded;
- save/load continuation and source-linked failure;
- editor configuration, trace, playtest, and package closure;
- the exact checkpoint that justifies each deliberate difference;
- migration and deletion evidence if an accepted authored executor replaces direct typed functions.

Tests for any later authored representation, executor, limits, authority rules, and debugging tools arrive with the production mechanisms they protect, not as speculative coverage of an imagined complete language.
