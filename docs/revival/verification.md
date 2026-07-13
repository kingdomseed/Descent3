# Verification

- Status: accepted
- Date: July 13, 2026
- Authority: binding completion and performance evidence

## Purpose

Tests prove the contracts of the new game and creator suite. They do not require byte parity, frame parity, or back-and-forth compatibility with the original executable or tools.

The released source and old executable may help answer a focused question about campaign, editor, behavior, multiplayer, replay, or tool intent. They are not continuous integration dependencies and do not define success for the new renderer, timing model, saves, behaviors, multiplayer, editor, or platform behavior.

## Evidence classes

### Import

`D3Import` must demonstrate:

- bounded reads and useful errors for malformed input;
- byte-deterministic structured output for the same source profile, importer version, and package schema;
- deterministic normalized decoded pixels, PCM samples, frame timing, and project metadata for transcoded media;
- recorded OS, SDK, codec path, and encoder settings, with media-container hashes treated as per-import integrity rather than cross-toolchain equality;
- validated archive bounds, duplicate names, case collisions, and references;
- complete source and output hashes in the import report;
- atomic destination promotion;
- requested-scope closure for partial imports and full closure for release-complete imports;
- bounded synthetic ACM and MVE decode cases, including malformed and unsupported variants;
- bounded OMF parsing into canonical regions, roles, loops, stream references and transition rules, including malformed instructions, invalid branches, missing streams, and loop failures;
- failed reimport leaving the active package, saves, replays, projects, and native packages untouched;
- compatible reimport preserving durable keys and semantic revisions;
- release-blocking detection of save-relevant canonical changes without the required semantic revision, plus reviewed semantic-equivalence assertions and encoding-only changes that correctly preserve revisions;
- no execution or copying of native retail code;
- no retail-derived fixture committed to Git.

Synthetic containers cover parser edge cases in repository tests. The verified owned CD-derived profile provides local end-to-end import evidence.

### Simulation

`RevivalCore` tests use explicit initial state, input frames, seeds, tick counts, and `simulationSemanticRevision`. Exact equality is expected for integer state, IDs, rule order, RNG state, objectives, damage, inventory, timers, and canonical normalized Float32 bits. Boundary tests reject NaN and infinity and normalize negative zero and subnormal persisted or hashed values as declared. Tolerances apply only to approximate higher-level regression claims, never to repeated authoritative replay state under one simulation revision.

The same replay must produce the same canonical state hash in repeated release-build runs on the supported architecture. Collection iteration order may not affect that hash.

### Behaviors

Each graph value, expression, event, query, command, branch, timer, function, scope, persistence rule, compiler diagnostic, and instruction family has focused synthetic tests. Type errors and invalid references fail before play. Float32 boundaries, adaptive-score region and role commands, and translated `EVT_INTERVAL` rules have focused cases. Interval-heavy fixtures verify rate equivalence, timer boundaries, long-run drift, and measured operation counts at 120 Hz. While 4,096 is the active development ceiling, direct and multi-handler cycles fail at exactly that operation without hanging or advancing another tick.

Compiler tests prove stable observable semantics, source-map accuracy, and deterministic operation accounting. Debug tests prove breakpoints, traces, watched values, and runtime errors resolve to the authoring graph.

Phase 5, Phase 8, and Phase 9 measure the operation ceiling against stock campaign and object behavior, an independent campaign, multiplayer modes, and adversarial cycle fixtures. Before release, the project ratifies or raises one platform ceiling and reruns the exact-limit suite. The limit may not be used to exclude a ledgered behavior.

Each required stock behavior scope has local checkpoints: levels cover objectives, doors, timers, spawns, messages, set pieces, adaptive-score commands, and completion; reusable/default objects and archetypes cover lifecycle and domain behavior; campaigns cover transitions and persistent state; game modes and sessions cover lifecycle, rules, scoring, results, and failure paths. Declared community fixes, retail observations, and approved native divergences receive their own checkpoints. A scope is not translated because its content loads. It is translated when its required behavior completes in the new runtime and its ledger has no unexplained generated or handwritten source behavior.

Import tests verify the signed `StockBehaviorCatalog` version and manifest hash, source-provenance entries, scope closure, graph hashes, declared bindings, compile results, and package report. Removing any required level, campaign, module-role, package-default, owner, archetype, game-mode, or session entry must make the applicable import scope fail before promotion.

### Saves and replay

New saves must:

- encode a version and content identity;
- bind one `simulationSemanticRevision` and reject or explicitly migrate incompatible authoritative state;
- round-trip canonical world, behavior, campaign, automap discovery, player-marker, and logical adaptive-score state;
- reject corrupt or incompatible data without partially mutating the live world;
- omit renderer, framework, pointer, and transient task state;
- bind durable campaign, level, behavior-graph, multiplayer-mode, and session-definition keys and their separate semantic revisions rather than package-local IDs or byte hashes;
- remain deterministic for the same snapshot where the encoder guarantees stable ordering.

Replays record resolved tick input, content identity, simulation revision, configuration, seeds, and controlled nondeterministic boundary results. Repeated authoritative release-build playback on the supported architecture must produce the same declared state hashes and completion result. A multiplayer recording may also carry client, observer, transport, or presentation evidence with separately declared checkpoints; it need not recreate packet timing or prediction history unless the Phase 9 contract explicitly makes one of those values authoritative. Corrupt, incompatible, truncated, and hostile replay data fails without mutating live state.

No test requires the original game to read a new save or replay.

### Creator projects and publishing

`RevivalEditor` tests cover:

- creation, mutation, undo, redo, save, close, reopen, migration, and reference integrity for every canonical document family;
- copy-on-write derivation of an imported document into an editable source replacement while proving that the base package remains byte-identical;
- atomic autosave, crash simulation, recovery preview, acceptance or rejection, and protection of the last explicitly saved project state;
- deterministic project decoding and publishing where the selected encoding promises it;
- content-catalog resolution, declared replacement order, duplicate ownership, missing dependencies, orphan detection, and destructive-change impact reports;
- behavior compilation, lighting and navigation bake invalidation, failure safety, and stale-product detection;
- adaptive-score authoring and preview, region and transition validation, logical save and replay round trips, and complete score-audio dependency closure;
- missed semantic-revision detection, explicit compatible-change acknowledgment, encoding-only preservation, and narrowly scoped invalidation;
- play-in-editor using the shipping simulation and return to the same document state;
- publisher refusal of broken references, invalid rights metadata where required, executable payloads, and incomplete dependency closure;
- package install, reopen, replay, and removal through the player application.

Each gameplay feature's verification row names its applicable authoring operation, validation failure case, playtest scenario, and package round trip. A working imported instance does not prove creator support.

### Multiplayer

Multiplayer tests cover the selected transport and session contracts, authoritative state, exact simulation-revision agreement, content and version negotiation, join and leave, reconnection policy, invalid and hostile inputs, rate and size limits, dedicated-host lifecycle, game-mode rules, results, replay, and clean failure. Player pictures, ship logos, and audio taunts have format whitelists and caps for encoded bytes, decoded dimensions, sample rate, duration, transfer rate, cooldown, and aggregate session storage. Tests cover hash identity, app-controlled paths, malformed media, active-payload rejection, mute and disable controls, consent where required, host policy, and abuse-resistant failure.

Deterministic local multi-instance tests establish repeatable state and desync evidence before network variability is introduced. Network tests then exercise latency, jitter, loss, duplication, reordering where the transport permits it, disconnection, host failure, and content mismatch. No test requires an original client, packet, server, or game module.

### Rendering

Renderer tests have two layers:

- CPU tests validate render-item extraction, transforms, culling, material and blend selection, lightmap bindings, mirror visibility and recursion bounds, procedural time, view ownership, ordering, and buffer bounds.
- GPU tests render controlled synthetic scenes for opaque and lightmapped surfaces, declared alpha and additive variants, specular faces, mirrors, procedural textures, volumetrics, scorch decals, cockpit and every supported auxiliary view, then compare images with a declared tolerance.

Metal validation must be clean. Fixed images are pinned to the recorded OS, SDK, shader compiler, GPU, resolution, and settings. Cross-OS or cross-GPU comparisons use tolerances rather than a promise of bit-identical rasterization.

### Application

Application tests cover input mapping, pause and resume, display resize, full-screen transitions, file locations, controller connect and disconnect, haptic capability detection and unsupported-device fallback, haptic enable and gain, audio and adaptive-score lifecycle, interruption and resume, movie playback, animated cockpit transitions, automap entry and discovery display, marker entry and view, rear and auxiliary camera selection, player-media selection and mute controls, project and package selection, signed-helper invocation, staging-path validation and cleanup without a report, every helper-contract exit class, cancellation before and racing with promotion, malformed or missing reports, import failure recovery, package activation, and clean player and editor termination.

Every `RevivalMac` archive and combined player distribution must contain one arm64 `Contents/Helpers/D3Import` built from the expected target. `RevivalEditor` does not carry a second copy. Nested-code signature verification must pass, the helper must carry the expected signing identity and entitlements, and Gatekeeper testing must exercise an actual import launch from the notarized player app rather than merely inspect the archive.

Fixed-loop tests use a controlled monotonic clock. They prove the eight-tick catch-up ceiling, excess-time drop accounting, accumulator reset across lifecycle suspension, held-state reuse, and exactly-once delivery of button edges and relative mouse/scroll impulses when a display callback produces zero, one, or multiple simulation ticks.

## Reference machine

Initial measurements use:

- Mac mini `Mac16,10`;
- Apple M4 with 10 CPU cores and 10 GPU cores;
- 16 GB unified memory;
- macOS 26.5.2;
- Xcode 26.6 and Apple Swift 6.3.3;
- Metal 4;
- 1920 by 1080 at 60 Hz for the current attached display.

Record toolchain, OS, display, content hash, build configuration, and settings beside every published performance result. Do not include device serial numbers or local identifiers.

## Performance method

Measure optimized builds. Use Instruments, Metal System Trace, Metal capture, and signposts around import, simulation, render extraction, command encoding, GPU passes, audio submission, and save operations.

The initial product targets:

- a fixed 120 Hz simulation without sustained backlog;
- stable presentation at the current display refresh;
- no avoidable steady-state allocation in measured simulation and render-extraction hot paths;
- no Metal validation errors;
- bounded memory growth across repeated level loads and restarts.

The Phase 4 combat slice records the first CPU, GPU, memory, startup, and import baselines. The complete Training Mission in Phase 5 establishes numeric budgets from a representative finished workload. Do not invent thresholds before then. A claim of 120 frames per second of presentation requires a 120 Hz display; an offscreen result may be reported only as render throughput. A 120 Hz simulation alone is neither claim.

Every optimization report includes before and after measurements and the exact change. Revert complexity that does not produce a meaningful improvement.

## First playable combat slice

The first playable milestone must use only Swift, MSL, Metal 4, and native Apple frameworks at runtime. It passes when the new engine can:

1. import the required owned retail dependency closure into a canonical package;
2. start from that package with no retail archive mounted;
3. render the selected indoor room cluster with textures, lightmaps, models, animated cockpit, HUD, and correct portal traversal;
4. fly the Pyro with keyboard, mouse, and a controller through a fixed 120 Hz simulation;
5. collide with walls and pass through connected rooms without instability;
6. operate one animated door and one mission trigger;
7. run one robot's minimal AI;
8. fire one weapon, create a projectile, apply damage, and collect one pickup;
9. play positional sound and required instructional messaging;
10. pause, restart, save, reload, and complete the defined slice objective;
11. create or change the slice's rooms, objects, door, trigger, robot, weapon, pickup, and behavior through `RevivalEditor`;
12. validate, play, save, reopen, package, reinstall, and complete that authored interaction;
13. pass Swift tests, Metal validation, image checks, and the first recorded M4 profile.

## First complete mission

The complete Training Mission milestone extends the same path to every object, behavior, briefing, adaptive-score cue, cockpit, automap, marker, auxiliary view, and completion condition used by that mission. It includes campaign and presentation authoring, behavior debugging, package publishing, install, save, and replay. It is the first complete mission, not the first moment at which the new engine is playable.

## Campaign gates

A campaign level is complete when:

- import reports a closed and validated content graph;
- its behavior translation ledger is complete;
- a player can start, progress, complete, save, and reload it;
- required controls, AI, weapons, audio, adaptive music, movies, HUD, cockpit, automap, markers, camera views, haptics, and transitions work;
- relevant synthetic and local content tests pass;
- every introduced capability has its applicable native authoring, validation, playtest, and publishing path;
- no unexplained crash, leak, validation error, or performance regression remains.

Campaign completion means every reachable mainline and secret level meets that gate, every secret entry and return transition works, and a fresh profile can reach the ending through a valid campaign path. Visiting and testing every stock secret level is mandatory for the base-campaign release gate even when a normal playthrough may skip it. A menu entry or load screen is not campaign support.

A release-complete import must also report every required campaign movie, briefing, audio asset, and transition present. A deliberately partial development package cannot satisfy a campaign or release gate.

## Campaign and content creator gate

Campaign and content creator completion requires an independently authored campaign that begins with an empty native project. It must include indoor and outdoor levels, custom definitions, typed behaviors, campaign branches, adaptive music, cockpit and HUD presentation, automap and markers, auxiliary views, localization, lighting and navigation products, saves, replay, and a published dependency-closed package. The complete workflow uses `RevivalEditor`, the native mod SDK, and `RevivalMac`; it uses no legacy tool and no hand-edited generated file.

Every applicable non-multiplayer row in the functional-completeness ledger must carry creation, validation, playtest, and package evidence. Closing a campaign runtime row does not close its creator row automatically.

## Multiplayer gate

Multiplayer completion requires every committed stock map and game mode and every dedicated-host lifecycle to pass the declared local and network matrices. Dedicated-host tests launch `RevivalMac` in its no-window host mode and prove that it does not initialize the renderer, audio, or player UI. A newly authored multiplayer package must be created, validated, published, installed, hosted, joined, completed, and replayed through native tools. Security limits and failure behavior are release criteria, not later hardening work.

The campaign and content creator gate plus the newly authored multiplayer package satisfy the complete creator-suite gate.

## Complete revival gate

The product is complete only when:

- Training, the base campaign and every secret, and Mercenary pass their campaign gates;
- the independent native campaign passes the campaign and content creator gate;
- multiplayer and dedicated hosting pass the multiplayer gate;
- the combined campaign and multiplayer authoring evidence passes the complete creator-suite gate;
- save and replay matrices pass for imported and native content;
- every ledger row is verified, replaced by an approved native counterpart, or excluded by an explicit product-scope amendment;
- signed and notarized player and editor applications pass clean-account and Gatekeeper tests;
- no production target or published package requires legacy code, executables, editors, formats, modules, or protocols.

## Documentation gate

Before implementation begins, active documents must agree on Swift 6.3, direct Metal 4, Apple Silicon, one-way import, new saves and replay, typed behavior data, the complete creator and multiplayer scope, no legacy runtime, four Phase 1 targets, and the five-target complete product. A consistency search must find no active instruction to preserve OpenGL, C++, SDL, the Osiris ABI, original saves or demos, original network interoperability, backward export, or a stock-campaign-only feature ceiling.
