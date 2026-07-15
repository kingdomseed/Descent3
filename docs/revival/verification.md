# Verification

- Status: accepted, amended
- Date: July 15, 2026
- Authority: binding evidence and acceptance contract

## Principle

Verify two things without confusing them:

1. translation fidelity: the native path preserves the source-supported observable behavior or records a deliberate difference;
2. product correctness: the accepted native game and creator contract works through the real shipping path.

The C++ source, reference executable, retail content, revision history, and historical notes are systematic translation evidence. They do not become permanent CI dependencies or require byte, file, ABI, packet, or UI parity.

Every new or changed shipping behavior follows [Test-driven development](test-driven-development.md). Documentation-only work uses link, consistency, and evidence checks. Disposable research captures unknown behavior but does not enter product targets.

## Evidence layers

Use the cheapest layer that can falsify the claim:

- source and call-path inspection for ownership, ordering, dependencies, and reachability;
- small synthetic fixtures for parsing, canonical values, state transitions, and failure boundaries;
- local retail-derived fixtures and captures for owned campaign translation;
- controlled renderer scenes and image comparisons;
- editor save, reopen, undo, play, and return workflows;
- optimized M4 profiling for performance and architecture decisions;
- end-to-end application, campaign, multiplayer, signing, and clean-account tests.

Do not duplicate the same assertion at every layer. Add an integration test only when composition can fail independently.

## Source translation evidence

Each dependency island records:

- every involved legacy file and relevant symbol;
- historical callers, global state, order, and dependency flow;
- observable runtime and editor checkpoints;
- native owner and disposition;
- deliberate differences;
- focused red and green evidence for shipping behavior;
- reference captures or fixtures where useful;
- license and provenance;
- deletion or archive status for any actual temporary scaffold.

A closed island has no unexplained source file, generated block, or handwritten range. This does not mean one test or Swift file per C++ file.

Build, link, and entry-point success prove only those named claims; they do not prove feature behavior or composition.

No island closes with a stubbed implementation, stand-in constant, disabled production path, temporary compatibility fallback, or TODO serving in place of a ledgered contract.

Closure evidence names every affected suite and every skipped, disabled, quarantined, deleted, weakened, or replaced case. A test protecting the claimed current contract must execute and pass. Any other nonexecuted case must be inapplicable under an approved `deferred`, `excluded`, or `replaced` disposition with replacement or removal evidence; an explanation alone is insufficient.

Reference comparisons use tolerances or structural checkpoints appropriate to the behavior. Exact values are required only where exactness is itself the accepted contract. When the native result intentionally differs, the evidence records the old result, new decision, and test that protects it.

## Import and canonical content

Import tests use the production D3Import parsers and cover the version 1.0 user-owned prepared retail profile:

- recognized source profile and archive precedence;
- checked little-endian fields, ranges, names, case collisions, duplicates, and references;
- the source structures required by the current room, level, campaign, or media slice;
- complete included-level topology, with the eager `PageInAllData` working set distinguished from lazy-page dependencies reached by the currently translated product path;
- source-faithful rooms, portals, terrain, objects, models, textures, lightmaps, paths, goals, strings, and current behavior bindings;
- malformed input, unknown used features, missing dependencies, and destination failure;
- atomic destination promotion and preservation of the previous valid package;
- provenance, hashes, imported scope, and explicit ignored or deferred entries;
- proof that the player and editor never open retail formats.

Synthetic fixtures enter Git. Owned retail packages, converted media, and captures remain local and ignored.

Do not test stream cells, stream blobs, spatial envelopes, package-layer locators, semantic revision hierarchies, or external marketplace threats before those production boundaries exist.

## Resident world loading

The current resource-lifetime path proves:

- the complete canonical Level and current dependency manifest validate before the commit boundary;
- the source-accounted eager working set is ready at activation and later reachable assets resolve only from the canonical package;
- RevivalMac and RevivalEditor resolve and render the same dependencies;
- room/portal and terrain visibility do not change the authoritative resident world;
- pre-commit failure preserves the prior stable state;
- post-commit preparation failure enters an explicit unloaded error state rather than requiring two complete GPU worlds;
- no partially constructed authoritative world becomes active;
- repeated load, restart, editor play, return, document replacement, and shutdown do not produce unbounded CPU or GPU memory growth;
- new submissions stop and final GPU use completes before the level owner releases resources and file handles;
- there is one loader and one renderer, with no resident/streaming switch or legacy fallback;
- optimized M4 startup, transition, memory, and editor costs are recorded at each representative milestone.

After the complete playable Training Mission, run the broader evidence gate in [World loading and residency](world-loading.md). A future amendment receives tests for its real production mechanism; no hypothetical streamer tests exist now.

## Simulation and timing

During the translation phase, controlled-clock tests prove:

- systems and `EVT_INTERVAL` receive the old `Frametime` and pre-update `Gametime` values explicitly;
- the static/`InitGame` 0.1-second initialization, without falsely assigning it to every level reset;
- source-supported update and event order, including post-cap new-delta storage, `Gametime` advance, and remaining tail work;
- nested pause, focus loss, suspension, and resume clock rebasing without a giant catch-up delta;
- input ramps, flight, collision, portal ownership, timers, animation, and interval behavior against reference traces;
- no hidden read of a global Frametime value.

Phase 3 chooses one final scheduler. Its amendment adds the exact tests for bounded variable delta or fixed ticks, including input sampling, catch-up, interpolation, timers, replay, and pause behavior as applicable. If it replaces the source scheduler, the amendment deletes production adapters and product tests that require the superseded scheduler.

Do not assert fixed 120 Hz, an eight-tick ceiling, exact Float32 hash semantics, fused-operation policy, or zero step allocations before the selected scheduler and replay requirements make them real contracts.

## Gameplay

Focused gameplay tests protect the current source-supported rule:

- six-degree-of-freedom input, ramps, simultaneous axes, mouselook, autoleveling, afterburner, turn roll, ship wiggle, and cockpit shake;
- thrust, mass, drag, forces, collision, wall slide, bounce, corners, portals, and room ownership;
- doors, triggers, keys, room roles, refueling, objects, pickups, inventory, weapons, projectiles, damage, and death;
- robot state, room and node routing, clearance, steering, blockage, and recovery;
- goals, difficulty, GuideBot, campaign state, saves, and progression;
- HUD, cockpit, automap, markers, cameras, cinematics, messages, results, and approved commands.

The functional-completeness ledger determines when each family enters. Tests do not anticipate every later family during Phase 1's selected acceptance room.

## Behavior

For each translated behavior chain, evidence covers:

- generated DALLAS structure plus custom and handwritten ranges;
- event producers, order, conditions, queries, commands, variables, timers, random choices, messages, and content bindings;
- reference checkpoints and deliberate differences;
- behavior under the selected final scheduler, with source explicit-delta semantics captured as characterization evidence and every deliberate timing difference recorded;
- save/load continuation where state persists;
- editor configuration, trace, error navigation, playtest, and package closure;
- migration and removal of direct typed functions only if a later evidence-ratified executor actually replaces them.

Tests for the version 1.0 authored representation and executor arrive when working evidence selects those actual production mechanisms; later operation limits, authority rules, and replay semantics arrive with the mechanisms they protect, not with a speculative full language.

## Rendering

CPU tests validate current render extraction, transforms, room-and-portal traversal, terrain visibility, geometry LOD, and texture-segment/UV/tile/rotation behavior when the outdoor island arrives, plus material and blend selection, ordering, cameras, and buffer bounds.

GPU tests render controlled scenes for:

- flat, textured, and lightmapped world geometry;
- models and animation;
- alpha, additive, saturating, fog, gamma, and vertex lighting behavior;
- each ledgered mirror, specular, decal, procedural, volumetric-lighting, animated-texture, destroyable-surface, effect, cockpit, HUD, automap, and camera path as it arrives.

Reference images first establish source-faithful output. A deliberate visual modernization records before, after, environment, metric, threshold, and review.

Metal validation must be clean. Fixed images record macOS, SDK, compiler, GPU, resolution, settings, and content identity. Baselines never regenerate automatically. Tests protect project decisions, not Metal or AppKit framework behavior.

## Editor

The Phase 1 integration test opens the complete canonical Training Level in RevivalEditor, focuses the selected acceptance room, and proves the smallest real edit selected from the traced historical editor/runtime workflow:

- read-only base to editable project to disposable play-session flow;
- shared world types, loading rules, and renderer with RevivalMac, without shared mutable ownership;
- selection and inspection;
- one project edit, named undo, redo, save, close, and reopen;
- play through the shipping simulation and renderer;
- return to useful document, selection, and viewport state;
- clean replacement and shutdown of complete-level world resources.

Later workspace tests cover each actual operation's reference integrity, validation, undo, save/reopen, playtest, and publishing. Human evidence covers focus, discoverability, keyboard, VoiceOver, diagnostics, recovery, and M4 responsiveness at the phase where the surface exists.

When a real background operation can race with editing, prove immutable input, cancellation where supported, stale-result rejection, source-linked failure, and preservation of newer source. Do not test a universal generation counter, preview package cache, fixed overlay slices, or streaming diagnostics unless they become accepted production mechanisms.

## Saves and replay

Save tests round-trip every durable state family that the current milestone owns, then step the original and loaded native worlds under the same future inputs and compare the accepted authoritative checkpoints.

Replay tests begin after the final scheduler is selected. They cover current input, configuration, random seeds, behavior state, commands, content identity, and checkpoints required for repeatable playback and diagnosis.

Do not compare legacy save or demo bytes. Do not add a full semantic revision hierarchy until a public compatibility promise exists.

## Audio, music, fonts, and movies

Import tests cover the exact FNT, OSF-with-ACM, WAV, OMF, and MVE constructs reached by current owned content plus malformed bounds and missing dependencies.

Runtime tests cover current positional sound, ambient behavior, voice queueing, adaptive-score state and transitions, font metrics and images, movie timing, interruption, device change, and missing output devices. Exact audio waveform timing is presentation evidence, not authoritative gameplay state.

Creator evidence covers the corresponding import, preview, validation, rights, save, play, and package path as each medium arrives.

## Multiplayer and untrusted boundaries

Phase 9 verification uses the final simulation and behavior models plus the one affordable native Internet topology accepted from the Phase 0 study. It covers:

- each stock mode at its source-supported player count, the released 32 network/player-slot infrastructure, historical listen-host and dedicated-server slot accounting, four-player campaign co-op, live observers, and join/leave/recovery;
- content and simulation agreement;
- prediction, reconciliation, interpolation, weapon policy, replay, and desync evidence;
- Bonjour LAN plus the selected Internet discovery, reachability, authorization, security, privacy, abuse, operating-cost, continuity, and explicit outage results; no relay or project-operated service is assumed unless the accepted topology contains one;
- authenticated encryption or provider-equivalent protection, sequencing, replay rejection, bounded records, rate limits, and malformed input at the selected topology's actual transport and trust boundaries, using Network or CryptoKit only where applicable;
- chat, moderation, host commands, player media, and privacy;
- multiplayer authoring, validation, local multi-instance play, publishing, and install.

Security checks concentrate at untrusted decode and authority boundaries. Trusted simulation values do not repeat packet validation defensively.

## Application and release

Application tests cover current input and settings, window and display lifecycle, files, import helper invocation, level loading, audio, movies, controllers, haptics, chat and commands when present, clean termination, signing, and failure recovery.

Archives prove the expected signed D3Import helper is bundled and launched successfully under Gatekeeper. Complete releases prove signed and notarized player and editor apps on a clean account.

## Reference machine

The pre-product environment snapshot used for current archaeology and documentation checks is:

- Mac mini Mac16,10;
- Apple M4 with 10 CPU and 10 GPU cores;
- 16 GB unified memory;
- macOS 26.5.2;
- Xcode 26.6 and Apple Swift 6.3.3;
- Metal 4;
- 1920 by 1080 at 60 Hz on the current display.

Phase 1 product builds and optimized measurements use Xcode 27 and the Swift 6.4 compiler in Swift 6 language mode: the current beta until the stable release, then stable Xcode 27. Xcode 26.6 and Swift 6.3.3 are not a supported product lane. Record toolchain, OS, display, content hash, build configuration, and settings beside every result. Do not record local identifiers or serial numbers.

## Performance method

Measure optimized builds with Instruments, Metal System Trace, Metal capture, and focused signposts. Track:

- startup and level-transition time;
- frame-time distribution, high-percentile hitches, and the slowest frames in a recorded representative run;
- simulation update, render extraction, Metal encoding, GPU execution, and wait time separately;
- CPU, GPU, and unified-memory high-water;
- allocation and copy hot spots, including unexpected copy-on-write events and `memmove` weight;
- Swift ownership and access work such as `swift_retain`, `swift_release`, `swift_beginAccess`, and `swift_endAccess` when it appears in a hot call tree;
- unspecialized generic calls, protocol witness dispatch, and closure or task allocation in a measured frame path;
- import and media conversion;
- editor command and playtest latency;
- repeated load/restart and long-session stability.

These symbols and compiler constructs are diagnostic leads, not failures by themselves. The Swift 6.4 `PerformanceHints` diagnostics may be enabled as warnings for a focused performance investigation; they are not a project-wide error policy or a reason to ban protocols, generics, collections, or classes outside a measured path. Attribute a missed budget or regression to the responsible function, allocation, copy, pass, transfer, or wait before changing code.

The first source-sensitive profiles cover the paths recorded in [Swift engine-code feasibility evidence](discovery.md#swift-engine-code-feasibility-evidence): collision and FVI, object and behavior update, room/portal and terrain extraction, dynamic lighting when reached, and the editor-to-play world-copy boundary. Compare the same accepted observable path before and after a change. Do not substitute a language headline or unrelated microbenchmark for product evidence.

The selected acceptance room within the complete resident `Level` records a baseline, not a global budget. The connected cluster and flight slice expand it. The complete playable Training Mission establishes the first credible product budgets and the resident-resource decision.

An optimization starts with a reproducible missed budget or regression. Keep it only when before/after measurements support it. Zero steady-state project allocations may become a targeted hot-loop contract; it is not a Phase 1 requirement.

## Milestone gates

### Phase 1: complete Level with selected-room acceptance

Phase 1 passes when:

1. D3Import converts the complete owned Training Level topology through production parsers and emits the current reachable dependency manifest, distinguishing the eager dependencies reached by `PageInAllData` from later canonical preparations;
2. RevivalMac and RevivalEditor each construct the complete resident canonical `Level` from the package with no retail archive mounted;
3. both applications render the same selected lightmapped room through direct Metal;
4. the editor derives a project value from the read-only base, changes one real value, undoes, redoes, saves, and reopens it;
5. editor preview creates a disposable play-session copy, enters the shared shipping paths, and returns;
6. the eager working set is ready at activation, later reachable assets resolve only from the canonical package, and replacement follows the pre-commit/post-commit failure contract before final-use release;
7. every source row reached by this result satisfies the ledger's Phase 1 terminal-state rule, and red/green results, clean Metal validation, and first M4 measurements are recorded.

### First playable combat slice

Phase 4 passes when the selected connected Training cluster supports:

- flight and collision through the selected final scheduler;
- one door and trigger;
- one robot route and AI chain;
- one weapon, projectile, damage path, and pickup;
- required HUD, cockpit, sound, messaging, difficulty, save, and reload;
- complete generated and handwritten behavior accounting;
- authoring, validation, playtest, save/reopen, and package proof for the interaction;
- clean tests, Metal validation, and optimized M4 profile.

### Complete playable Training Mission

Training passes when every required runtime, behavior, presentation, save, replay, editor, validation, and publishing path works. It also closes the resident-level evidence gate after the complete playable Training Mission with a recorded keep-or-amend decision.

### Campaign and creator gates

A campaign level is complete when its source and import dependency accounting closes, a player can start/progress/complete/save/reload/replay it, every required capability works, and every introduced canonical type has its applicable creator path.

The creator gate requires a non-bundled independent certification campaign from an empty native project, covering indoor and outdoor levels, definitions, behaviors, presentation, saves, replay, validation, playtest, and publishing without a legacy tool or hand-edited generated file. It proves the creator suite and does not provide replacement retail content.

### Multiplayer gate

Multiplayer passes the declared local, LAN, selected-Internet-topology, 32-slot-infrastructure, mode-specific-count, four-player-co-op, observer, dedicated-host, outage, security, replay, authoring, and published-package matrices.

### Complete revival

The product is complete only when:

- Training, the base campaign and every secret, and Mercenary pass;
- the non-bundled independent certification campaign and multiplayer package pass creator gates;
- multiplayer, dedicated hosting, and every service or operational boundary selected by the accepted Internet topology pass;
- save and replay matrices pass;
- every capability ledger row and relevant source file/range is verified, deliberately replaced, or explicitly excluded;
- signed and notarized applications pass clean-account and Gatekeeper checks;
- no product path requires a legacy executable, editor, format reader, ABI, or protocol.

## Documentation gate

Before Phase 1 production begins, active documents must agree on:

- the Swift 6.4 compiler toolchain in Swift 6 language mode, using Xcode 27 beta until stable Xcode 27 replaces it, plus MSL, direct Metal 4, Apple Silicon, and macOS 26+;
- source-accounted semantic translation with recorded differences;
- no shipping C++, OpenGL, SDL, MFC, native module, or compatibility backend;
- one-way import and retail-data isolation;
- one complete resident Level world, source-accounted eager working-set preparation, and canonical lazy paging added with each reachable translated path as the current implementation;
- no speculative stream cells, stream blobs, spatial demand, or resident/streaming switch;
- one explicit source-faithful old/new variable-time scheduler followed by a single Phase 3 timing decision;
- RevivalEditor in Phase 1 sharing world types, dependency rules, renderer, level I/O, and play path with RevivalMac while owning separate editor and play-session values;
- complete human creator, campaign, replay, multiplayer, and mod-SDK scope through the evidenced shipped-game and creator-tool capability;
- version 1.0 retail ownership and the one supported prepared-installation profile, with additional profiles and replacement assets left to later decisions;
- affordable native Internet multiplayer as a required outcome, with the operational topology held as a Phase 0 research question rather than a preselected project-operated service;
- focused red-first shipping implementation plus bounded disposable research;
- evidence-driven modernization that deletes the superseded production path.

The Phase 1 environment check must also show Xcode 27 selected, Swift 6.4 in Swift 6 language mode, the recorded SDK and macOS 26 deployment target, and no Swift 6.3 compatibility branch. During the beta window it records the exact beta build; after release it records stable Xcode 27 and deletes any beta-only workaround.

A consistency search must find no active instruction that makes fixed-cell streaming, fixed 120 Hz, exact target counts, a complete speculative behavior VM, a fixed editor overlay protocol, or a provisional lightmap atlas a Phase 1 prerequisite.
