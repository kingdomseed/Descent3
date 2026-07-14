# Engineering principles

- Status: accepted
- Date: July 13, 2026
- Authority: binding implementation rules

## Objective

Write the least project-owned code that can deliver the complete required game and creator experience with the required performance and reliability. Minimal code does not mean compressed syntax, hidden behavior, or reduced scope. It means fewer concepts, fewer paths, fewer dependencies, and fewer states a maintainer must understand.

The M4 has ample CPU and GPU capacity for a late-1990s game. Spend that capacity to keep the design direct. Optimize after release-build measurements show a missed budget.

## Default choices

- One concrete implementation is a type, not a protocol hierarchy.
- One caller uses a direct function call, not an event bus.
- One platform uses the platform API, not a wrapper.
- One renderer uses explicit passes, not a render graph.
- A handful of object families use domain collections, not an ECS framework.
- A small AI slice uses a switch, not a behavior-tree system. Expand when a ledgered capability requires it.
- World streaming uses one coordinator and fixed cells, not a job scheduler or task per asset.
- A directory and manifest are a package. One typed content catalog resolves project references; it is not a general asset database.
- A measured slow loop earns optimization. A hypothetical slow loop does not.

## Functional-completeness guardrail

KISS changes how a capability is built. It does not decide whether the capability exists.

Each gameplay capability must acquire its applicable runtime, authoring, validation, playtest, and publishing paths in the same roadmap phase. Prefer one editor operation that replaces several historical dialogs, one behavior language that replaces DALLAS and Osiris, and one publisher that replaces the packaging utilities. Do not claim a code reduction by leaving out editor functions, multiplayer, replay, presentation tools, or content types listed in the [functional-completeness contract](functional-completeness.md).

The historical source contains dead UI shells and partially implemented commands. Rebuild intended working capability, not the defect or obsolete interaction pattern. Ambiguous cases go into the completeness ledger for an explicit decision.

## Abstraction gate

Add an abstraction only when at least one condition is true:

1. two current production implementations need the same contract;
2. a nondeterministic external boundary must be controlled in tests;
3. ownership or safety cannot be expressed clearly without the boundary;
4. measured duplication is larger than the abstraction and likely to remain so.

Every proposal for a new subsystem must identify the current feature that needs it, the simpler direct approach that was considered, and the code or risk the subsystem removes.

Do not create `Common`, `Shared`, `Engine`, `Manager`, `Service`, `Provider`, or `Factory` modules as holding areas. Name code after the game concept or Apple service it implements. The six-target product graph is fixed for the planned work, not a reason to pile unrelated code into one file.

## Data and ownership

- The simulation has one mutable owner.
- Entities use stable small integer IDs. Pointers and reference cycles do not cross subsystem boundaries.
- Start with Swift structs, enums, `ContiguousArray`, and straightforward array-of-structs storage.
- Prefer value semantics in the simulation. Reserve classes for framework objects and genuinely shared identity.
- Do not rely on `Dictionary` or `Set` iteration order for simulation behavior, saves, or hashes.
- Use one explicit seeded random-number generator for game behavior.
- Use finite `Float32` for simulation quantities that are not integral. Reject NaN and infinity at content and command boundaries, normalize negative zero before canonical encoding and hashing, and apply declared domain bounds. Keep operation order stable and do not enable fast-math transformations.
- Install loaded assets only at defined frame boundaries.
- Keep renderer resources out of simulation and save types.
- Retain the complete finite authoritative `WorldSpine` through level exit. Stream only immutable presentation records through the single fixed-cell `WorldStreamer`; simulation, behaviors, saves, replay, and multiplayer cannot observe I/O or residency. The editor's one bounded noncanonical `DraftOverlay` is the sole live-geometry exception and never enters game, save, replay, package, or multiplayer state. A custom allocator remains subject to the measured profile and written invariant required by `AGENTS.md` and may not create a second residency path or test-only observability.

Every authoritative multiply-add explicitly uses either fused `addingProduct` or separately rounded multiply and add. System and SIMD transcendental functions do not write authoritative state. A required transcendental becomes one named, versioned project operation or table with exact vectors; it does not justify a general math framework.

Unsafe memory access, `Unmanaged`, `@unchecked Sendable`, `nonisolated(unsafe)`, `@inline(always)`, and `@specialize` require a measured reason, a documented invariant, and focused tests. Do not enable `-Ounchecked` for the project.

## Concurrency

The initial game loop is single-owner and main-actor isolated. This is the simplest correct architecture for the accepted runtime.

Use asynchronous work for operations that can block for milliseconds or more:

- retail import;
- disk reads and writes;
- image, audio, and movie conversion;
- world-cell Metal I/O directly into final private buffers and textures;
- pipeline compilation or cache preparation when the Metal API supports it cleanly;
- editor lighting, navigation, media, and package builds.

Use one streaming coordinator, not a task per cell or resource. Do not use actors or tasks for players, robots, projectiles, doors, AI goals, physics contacts, draw items, or individual assets. Do not add a job system until Instruments attributes a missed frame budget to CPU work that can be separated safely.

## Rendering

- `RevivalMetal` is the renderer. There is no renderer interface.
- Use a small explicit pass order and a small known pipeline set.
- Build the first correct image before adding visual systems.
- Treat mirrors, specular response, scorch decals, procedural textures, volumetrics, and declared blend semantics as concrete content requirements. Implement each directly when its first verified scene needs it; do not hide the inventory behind a three-material summary.
- Keep CPU render extraction predictable and free of project-owned steady-state heap allocation after warm-up.
- Use three rotating frame-resource slots where Metal synchronization requires them; do not generalize that into a resource framework.
- Use one app-lifetime and one dynamic world Metal residency set. Stage whole-resource additions and removals on the render owner; install only complete batches at frame boundaries and retire only after final GPU use. Every level, content-stack, or key-document handoff cuts off old submissions, drains all committed old-generation Metal I/O and final render use, and retires its allocations and file handles before loading a successor. Only the key editor document owns live world residency; background-document viewports pause and release it through that teardown.
- Use one orientation-independent spatial demand envelope and one lead-time-derived prefetch shell around every live camera. Use CPU room-and-portal traversal with room-frustum rejection only for drawing and ordinary GPU backface rejection. Do not let orientation or dynamic occlusion change residency, recreate legacy face-by-face portal clipping, or add an occlusion subsystem.
- Build outdoor terrain as fixed 32-by-32-quad authored-resolution cells. Do not port or replace the historical terrain LOD system.
- Do not add sparse resources, mip streaming, an LRU, memory-pressure quality modes, a general resource manager, a resident-only fallback, or a second cell or visibility architecture. [World streaming](world-streaming.md) is the only resource-lifetime model.
- Do not add GPU-driven culling, bindless scene machinery, MetalFX, deferred lighting, or ray tracing to the accepted product architecture. Reopening one requires an explicit architecture amendment.

## Editor discipline

`RevivalEditor` uses AppKit's document architecture directly: one `NSDocument`, one `@MainActor EditorSession`, one primary project window, one canonical project value, and one `UndoManager` history per open project. Views call concrete typed edit operations on that session. Do not add a generic reactive store, command bus, editor service layer, or protocol solely to connect panes.

Stable element IDs, named inverse edits, and structured source-linked diagnostics serve human selection, undo, validation, and repair. They are not a public automation protocol. Each edit, undo, redo, revert, accepted recovery, or source-changing asynchronous result advances one transient `ProjectEditGeneration` that identifies an unsaved snapshot and remains separate from persisted semantic revisions. Long editor work consumes an immutable snapshot and reports that generation. A stale or cancelled result remains diagnostic history only: it cannot enter or clear active validation, report publish success, become playable output, or replace the last good derived product. Cancellation and failure leave source and last-good derived products unchanged. Use one cancellable task per user-requested USD or native-media ingress, preview-record build, bake, validation, or publish operation rather than a scheduler.

Local interface state such as open tabs, split positions, selection, and viewport cameras stays outside canonical project source. Authored camera bookmarks remain canonical content. Play-in-editor runs a snapshot through the shipping simulation, streamer, and renderer and returns to the exact document, selection, viewport, and workspace state.

One logical render-owner `DraftOverlay` uses exactly three preallocated slices aligned with the three rotating frame-resource slots. Each slice holds the maximum visible dirty-geometry union across all four supported editor viewports; all three physical slices count toward high-water. Write only an available slice and retain every in-flight slice unchanged through its final render use. Pointer samples update only transient gesture state and the next available slice. Commit advances canonical source, named undo, and `ProjectEditGeneration` exactly once; cancel advances none. The matching background preview replaces the overlay records without a second renderer or per-sample build.

The current product is human-first. Do not implement an MCP server, headless authoring process, public command wire format, training recorder, telemetry, or agent-only edit path before Phase 10 ships the complete human creator suite. Future automation must adapt the same mature editing session rather than introduce a second mutation, validation, playtest, or publishing path.

## Dependencies

The product has no third-party runtime dependencies. Apple frameworks and the Swift standard library cover the applications, renderer, input, Model I/O USD ingestion, Network-framework QUIC, canonical font use, audio and movie encoding and playback, serialization, and tests. Narrow project-owned Swift decoders in `D3Import` handle the verified retail bitmap-font, OSF-with-ACM stream, WAV, and MVE inputs; no legacy decoder enters a runtime target.

Before adding a dependency, document:

- the maintained project-owned code it replaces;
- binary size and runtime cost;
- license and redistribution obligations;
- update and security ownership;
- whether a small local implementation would be clearer.

Developer tools and agent skills are not runtime dependencies, but executable tools still require pinned revisions and an audit.

## Code budget

Track project-owned Swift and MSL lines, target count, runtime dependency count, and executable-tool count at each playable milestone. The report exists to expose growth, not reward code golf.

New code should correspond to a visible capability, required content, safety invariant, or measured improvement. When a milestone adds much more infrastructure than playable behavior, stop and simplify before continuing. Refactoring may reduce line count, target count, or concepts even when no feature changes.

Do not set an arbitrary lifetime line limit before the complete Training Mission exists. Phase 5 establishes the first credible size baseline. Phase 1 has four product targets; Phase 2 adds `RevivalEditor`; Phase 9 adds the isolated `RevivalRelay` operational target; the complete planned product has six. Third-party runtime dependencies remain at zero.

Track functional ledger coverage beside line count. Falling line count while required capabilities disappear is a regression, not an improvement.

## Test-driven implementation without architecture theatre

Every new or changed production behavior follows the binding [red-green-refactor protocol](test-driven-development.md). The red test is design pressure: it names the next observable contract before implementation can spread. If a behavior needs a large harness to state, narrow the slice or simplify the production boundary before adding machinery.

Testability comes from explicit inputs and pure or deterministic operations, not from wrapping every type in a protocol.

Examples:

- the importer decodes a byte buffer into a canonical value;
- the simulation steps from a world plus `InputFrame` to the next state;
- behavior compilation turns a typed graph into a checked program;
- behavior execution consumes an ordered event and updates typed state;
- adaptive-score selection advances from logical state and emits typed presentation commands without depending on an audio device;
- render extraction turns world state into a render snapshot;
- a save snapshot encodes and decodes without live framework objects;
- an editor command mutates, validates, undoes, redoes, saves, reopens, and plays a canonical document.

Use small synthetic fixtures in Git. Parameterized tests and property tests are preferred for checked binary parsing and deterministic state transitions. GPU tests use controlled scenes and declared image tolerances.

Tests are maintained code. Each test must protect reachable behavior through the real production path and add distinct regression protection. Do not optimize for test count, coverage percentage, mockability, or symmetric testing of impossible branches. When a supported path disappears, delete its obsolete tests. When a path cannot be reached after canonical validation, test the validation boundary and delete downstream dead handling instead of constructing an impossible state.

The evidence chain is focused red, focused green, affected suite, then the phase-specific matrix or device evidence. A test written after implementation, a failure caused by broken setup, and a test-only production route do not satisfy that chain.

## Performance discipline

Performance work follows this order:

1. measure a release build on the recorded M4;
2. identify the CPU function, allocation, GPU pass, memory transfer, or wait responsible;
3. make the smallest change that addresses it;
4. verify behavior and measure again;
5. keep the optimization only if the evidence supports it.

Track frame time, simulation time, render-encoding time, GPU time, allocations, memory high-water mark, import time, and startup time. Do not infer performance from code shape alone.

After warm-up, each declared production scenario performs zero project-owned heap allocations inside `RevivalCore.step` and render extraction. Initialization, level-transition installation, and Apple-framework work outside those boundaries are measured separately. Phase 1 establishes an automated release-build allocation-budget command over the real production path: it warms the scenario, measures allocation events only inside the declared step and extraction intervals, and exits nonzero on any project-owned allocation. Its first valid nonzero result is the red evidence; zero is green. Every gameplay slice extends that same command. An Instruments Allocations trace supplies attribution and corroboration but does not replace the automated red-green gate. Do not add allocator protocols, malloc hooks to shipping code, or test-only production entry points to prove the invariant.

The 120 Hz simulation target is a product choice. The current reference display is 60 Hz, so a 120 frames-per-second presentation claim requires a 120 Hz test display. An offscreen test may establish at least 120 frames per second of render throughput, but not presentation pacing or latency. The first renderer gate is consistent 60 Hz presentation on the current reference display with clean Metal validation.

Phase 1 ratifies the safety and capacity constants required to freeze the world-streaming schema: resident spine and schema counts; stack-global, level-pinned, cell, simultaneous-camera and discontinuous-destination bytes; render radius; maximum continuous speed; maximum demand-evaluation interval; `LoadWave` and `T_wave`; prefetch shell; queue, command-buffer and submitted-stale caps; intra-level overlap; I/O latency; and active-memory high-water mark. Those are measured foundation limits, not optimization guesses. Phase 5 establishes broader gameplay and editor performance budgets from the complete Training Mission.

## Review questions

Every implementation review should ask:

- Does this code serve a ledgered capability in the current milestone?
- Did the focused test first fail for the intended product reason?
- Does each new test exercise a reachable production path and prevent a distinct regression?
- Did test convenience add a production seam or alternate path that the product does not need?
- Does the feature have its applicable authoring, validation, playtest, and publishing paths?
- Can an Apple framework or standard-library feature remove it?
- Did we add a second path where one would work?
- Is a generic abstraction hiding one concrete implementation?
- Is legacy compatibility leaking into the runtime?
- Can data replace code?
- Can a direct switch or table replace a framework?
- Can any new type, dependency, or layer be deleted?
- Does a proposed deletion remove machinery or remove functionality?
- Is the performance claim measured?
- Are the tests checking our product contract rather than the old engine's internals?

Subtraction is valuable when the capability remains intact.
