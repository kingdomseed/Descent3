# Engineering principles

- Status: accepted, amended
- Date: July 16, 2026
- Authority: binding implementation rules

## Objective

Write the least project-owned code that can faithfully transfer and then improve the complete required game and creator experience. Minimal code means fewer concepts, paths, dependencies, and states a maintainer must understand. It does not mean compressed syntax, hidden behavior, or reduced scope.

The recorded M4 Mac has ample capacity for a late-1990s game, so Mac/shared implementation leads. The available physical devices recorded in the current plan provide mobile-development evidence when mobile composition begins; exact release-floor hardware is a later public-beta or release certification concern, not a rewrite-start gate. Keep the first implementation direct on every target. Optimize and redesign only after a representative optimized build shows the problem.

These are enduring implementation rules. The active slice, separate Mac/shared and mobile checkpoints, and two-developer ownership live in the [current implementation plan](current-plan.md); update that file rather than duplicating a live task queue here.

## Translation guardrail

The source is allowed to influence semantics without dictating native structure.

- Preserve reachable data flow, ordering, formulas, dependency discovery and lifetime, and observable results before changing them.
- Account for every involved source file and record deliberate differences.
- Combine or split source responsibilities when that produces clearer Swift ownership.
- Replace platform APIs and ABI machinery directly; do not wrap them to resemble C++.
- Do not carry dead branches, duplicated paths, defensive checks after a trusted boundary, or fixed-capacity accidents merely for fidelity.
- Do not call a redesign a port. Baseline, change, and verification are separate records.

Before fixing a new phase, island, subsystem, or material code-group boundary, run the bounded [fog-of-war preflight](source-translation.md#fog-of-war-preflight). Treat the existing plan and seeded source rows as hypotheses to check against the relevant source and current native path. The goal is enough evidence for the next direct contract, not exhaustive program analysis. Finding no correction is a normal result.

Work one dependency island at a time and keep the real editor and player runnable. A large layer of stubs is not progress merely because many source filenames have Swift counterparts.

## Default choices

- One implementation is a concrete type, not a protocol hierarchy.
- One caller uses a direct call, not an event bus.
- Each concrete application shell uses its framework directly: AppKit for RevivalMac and RevivalEditor, UIKit for RevivalMobile. Multiple shells do not justify a generic platform, application-host, input, file-system or renderer abstraction.
- One renderer uses explicit passes, not a render graph.
- Domain object families use direct collections, not an ECS.
- The current behavior slice uses canonical direct typed functions, not a predesigned general VM or forced future rewrite.
- One complete resident level world and its growing presentation set use one owner, not a resource manager.
- A directory plus a simple manifest is a package until a real distribution need proves otherwise.
- A measured slow loop earns optimization. A hypothetical slow loop does not.

## Functional-completeness guardrail

KISS changes how a capability is built, never whether it exists. Each gameplay capability gains its applicable runtime, authoring, validation, playtest, and publishing paths as its roadmap slice matures.

Prefer one clear editor operation over several historical dialogs, one native content representation over legacy page variants, and one safe creator behavior workflow once its real authoring requirements are known. Do not claim simplification by omitting editor functions, multiplayer, replay, presentation tools, or content types in the [functional-completeness contract](functional-completeness.md).

Ambiguous source behavior goes into a ledger with evidence and one decision. It is not silently preserved or silently deleted.

## Abstraction gate

Add an abstraction only when at least one condition is true:

1. two current production implementations need the same contract;
2. a nondeterministic production boundary must be controlled in tests;
3. ownership or safety cannot be expressed clearly without the boundary;
4. measured duplication is larger than the abstraction and likely to remain so.

Every new subsystem proposal names the current feature that needs it, the direct approach considered, and the code or risk it removes.

Do not create Common, Shared, Engine, Manager, Service, Provider, or Factory modules as holding areas. Name code after the game concept or Apple service it implements. Target count is not a quality metric.

## Data and ownership

- The simulation has one mutable owner.
- Start with Swift structs, enums, ContiguousArray, and straightforward array-of-structs storage.
- Use stable IDs only where identity must survive collection movement, editor selection, save, or references.
- Prefer value semantics. Reserve classes for framework objects and genuine shared identity.
- Do not rely on Dictionary or Set iteration order for observable game behavior.
- Keep renderer objects out of simulation, canonical project, save, replay, and network types.
- Pass the historical prior-frame elapsed value and input explicitly; do not recreate global `Frametime` or global function-mode state.
- Own the complete resident level world, its eager working set, and every later canonical presentation preparation through one level owner until exit.
- Validate retail, project, package, save, and network boundaries before constructing trusted canonical values. Internal code relies on those invariants instead of rechecking impossible states.

Use finite Float32 where the original semantics and Metal path require it. Reject NaN and infinity at untrusted boundaries. Preserve operation order where current behavior depends on it. Do not build a deterministic math library, fixed-point layer, fused-operation policy, or semantic-revision hierarchy before replay or multiplayer evidence requires one.

Unsafe memory access, Unmanaged, unchecked concurrency, forced inlining, specialization, and custom allocation require a measured reason, a written invariant, and focused tests. Do not enable unchecked optimization for the project.

## Loading and resource lifetime

The first loading path is intentionally direct:

1. validate the successor's canonical manifest and structural CPU content;
2. at the commit boundary, stop old submissions, wait for final GPU use, and release the old presentation owner;
3. build the successor's authoritative world values;
4. prepare the source-evidenced eager working set and activate the world;
5. prepare later source-reachable assets only from its validated canonical package and current reachable dependency manifest, then retain them until exit.

Failure before commit preserves the current world; failure after commit enters an explicit unloaded error state. Loading may move one bounded operation off the main actor when measured latency warrants it. An iOS or iPadOS memory warning may trigger the ordinary drain-and-release path and an explicit unloaded or recoverable error state; it does not authorize partial eviction. Do not add a task per asset, stream cell, spatial demand calculation, prefetch policy, LRU, alternate memory-pressure residency mode, cache hierarchy, or resident/streaming switch.

If applicable optimized evidence after the complete playable Training Mission proves the resident path inadequate, follow the amendment rule in [World loading and residency](world-loading.md). Mac/shared evidence may trigger that investigation without waiting for release-floor certification; the replacement still leaves one production lifetime path that is verified through mobile composition before the affected overall milestone closes.

## Concurrency

The game loop has one mutable owner. Swift concurrency is appropriate for operations that really block:

- retail import;
- file reads and writes;
- image, audio, font, and movie conversion;
- Metal resource preparation when measurement shows it should leave the main actor;
- actual editor lighting, navigation, media, validation, and publication work.

Do not create actors or tasks for players, robots, projectiles, doors, AI goals, physics contacts, draw items, or individual assets. Do not add a job system until Instruments attributes a missed budget to CPU work that can be separated safely.

## Rendering

- RevivalMetal is the renderer. There is no renderer interface.
- Use a small explicit pass order and a small known pipeline set.
- Build the first source-faithful image before adding visual improvements.
- Translate room/portal visibility and terrain presentation before simplifying either.
- Treat mirrors, specular response, decals, procedural textures, volume lighting, animated textures, destroyable faces, and blend semantics as concrete content requirements.
- Keep resource creation and destruction owned by the loaded level and safe through final GPU use.
- Use rotating frame resources only where Metal synchronization requires them; do not generalize them into a resource framework.
- Do not add GPU-driven culling, bindless scene machinery, MetalFX, deferred lighting, ray tracing, sparse resources, or a second visibility path without a measured amendment.

## Editor discipline

RevivalEditor uses AppKit document architecture directly: one NSDocument, one main-actor editing owner, one canonical project value, one UndoManager history, and one primary window per project. Views call concrete edit operations. Do not add a reactive store, command bus, service layer, or protocol solely to connect panes.

The first editor proves the shared world model and production paths:

- derive, open, and render the editable project value through the canonical resident-world model;
- select and inspect source-backed elements;
- make one real edit with named undo and redo;
- save, close, and reopen;
- play a disposable session copy through the shipping simulation and renderer;
- return to the document.

Stable identity is added to elements that actually need durable selection or references. Long operations consume immutable input and reject stale results when the first real operation can race with editing. Do not prebuild a universal generation protocol, preview package cache, fixed overlay-slice system, job scheduler, or background-document residency choreography.

Local UI state such as tabs, split positions, selection, and viewport cameras stays outside canonical source. Authored camera bookmarks remain content.

The editor is human-first. MCP, headless authoring, public command protocols, training recorders, telemetry, and agent-only paths do not enter the current roadmap.

## Dependencies

Prefer Apple frameworks and the Swift standard library. Narrow project-owned import decoders cover only the retail variants verified in the owned source profile and never enter the runtime.

Before adding a dependency, document:

- the maintained code it replaces;
- binary and runtime cost;
- license and redistribution obligations;
- update and security ownership;
- why a small local implementation is not clearer.

Developer tools and skills are not runtime dependencies, but executable tools still need pinned revisions and audit.

## Test-driven implementation without architecture theatre

Every new or changed shipping behavior follows [Test-driven development](test-driven-development.md). The red test names the next observable contract before implementation spreads. Testability comes from explicit inputs and direct values, not protocol wrappers.

Characterization evidence protects source semantics at an observable boundary. It does not require a test for every C++ function, branch, guard, or data member. When canonical validation makes a state unreachable, test the boundary and delete downstream defensive handling.

A disposable research spike may inspect an unknown format, capture a trace, or answer an API question. It stays outside product targets and is removed or archived before shipping implementation begins. Once the product contract is known, red-first production work resumes.

## Performance discipline

Performance work follows this order:

1. measure an optimized build on every recorded development device affected by the implementation claim, and on selected floor devices before making a public support-floor claim;
2. identify the responsible function, allocation, GPU pass, transfer, or wait;
3. make the smallest change that addresses it;
4. verify behavior and measure again;
5. keep the complexity only when evidence supports it.

Track frame time, update time, render encoding, GPU time, allocations, memory high-water, import time, load time, thermal state, lifecycle recovery and editor responsiveness for representative milestones as applicable to each target.

Zero steady-state allocations, a fixed tick rate, specialized math, direct Metal I/O, and spatial streaming are possible conclusions from measurements, not Phase 1 architecture theatre. The complete Training Mission establishes the first credible product budgets.

## Review questions

- Did the bounded fog-of-war preflight test the proposed boundary, record real corrections, and stop when the next contract was stable, including a valid clean result when no gap appeared?
- Which source behavior or ledgered capability does this code serve now?
- Is the source disposition and any deliberate difference recorded?
- Did the focused production test fail for the intended reason?
- Does each test exercise a reachable path and prevent a distinct regression?
- Did test convenience add a production seam or alternate path?
- Does the feature have the applicable editor and publishing path?
- Did we validate once at the boundary or repeat defensive checks internally?
- Did we add a second mode where one current implementation would work?
- Is a generic abstraction hiding one concrete implementation?
- Are legacy semantics being confused with prohibited legacy APIs or ABI?
- Can direct data, a switch, a table, or an Apple framework remove code?
- Is the performance claim measured on representative content and every device needed for that claim, without turning later release-floor certification into a Mac/shared implementation gate?
- Can any new type, target, dependency, or layer be deleted?

Subtraction is valuable when fidelity and capability remain intact.
