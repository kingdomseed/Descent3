# Verification

- Status: accepted
- Date: July 13, 2026
- Authority: binding completion and performance evidence

## Purpose

Tests prove the contracts of the new game and creator suite. They do not require byte parity, frame parity, or back-and-forth compatibility with the original executable or tools.

The released source and old executable may help answer a focused question about campaign, editor, behavior, multiplayer, replay, or tool intent. They are not continuous integration dependencies and do not define success for the new renderer, timing model, saves, behaviors, multiplayer, editor, or platform behavior.

## Development protocol

[Test-driven development](test-driven-development.md) governs every new or changed production behavior. Before implementation, write the smallest automated test for the next observable contract and run it to a failure caused by the missing behavior or reproduced defect. Then make the smallest production change that passes it, refactor while green, run the affected suite, and complete the broader evidence required below. An implementation-first test is not TDD.

Each change record names:

- the ledger row, reproduced defect, declared invariant, or reachable external boundary;
- the focused red command and salient expected failure;
- the focused green command and pass;
- the directly affected suite and result;
- any required image, device, performance, security, package, or end-to-end evidence.

A typo, missing fixture, unavailable retail file, unrelated failure, misconfigured environment, or generally broken target is not red evidence. When a behavior-neutral refactor needs new protection for existing behavior, the test first demonstrates sensitivity through a temporary controlled mutation or reproduced defect, returns to green, and only then protects the refactor.

The test-value gate is binding. Tests exercise supported production paths and protect distinct observable contracts. Coverage percentages, impossible internal states, Apple-framework behavior, duplicate assertions, speculative variants, and test-only production seams do not qualify. A reviewer requesting another test must identify the production entry point, reachable state, observable contract, plausible regression, why current tests miss it, and the lowest useful test layer.

## Evidence classes

### Import

`D3Import` must demonstrate:

- bounded reads and useful errors for malformed input;
- explicit source-endian decoding with bounds checked before every field interpretation;
- byte-deterministic structured output for the same source profile, importer version, and package schema;
- deterministic normalized decoded pixels, PCM samples, frame timing, and project metadata for transcoded media;
- recorded OS, SDK, codec path, and encoder settings, with media-container hashes treated as per-import integrity rather than cross-toolchain equality;
- validated archive bounds, duplicate names, ASCII case-fold collisions, references, exact source spelling in provenance, and profile-declared canonical keys;
- complete source and output hashes in the import report;
- atomic destination promotion;
- requested-scope closure for partial imports and full closure for release-complete imports;
- deterministic `WorldSpine`, one-room indoor cells, positive-multiple-of-32 terrain grids and fixed 32-by-32-quad cells, checked layer/blob locators, ranges, closed descriptors and hashes, stack-global, level-pinned and per-cell GPU costs, spatial camera and discontinuous-destination envelopes, movement lead-time proof, and refusal outside the ratified stack-global, spine, count, level-pinned, cell, simultaneous-camera, destination, `LoadWave`, queue, stale-work, high-water, or lead-time limits;
- deterministic per-room repacking of legacy lightmap texels, rewritten canonical UV2, two-texel chart dilation, a provisional nonmipmapped 1024-square `rgba8Unorm` output pending Phase 2 whole-retail packed-area ratification, measured overflow diagnostics that do not silently reject an entire source profile, and local imported-room image proof;
- bounded synthetic OSF-with-ACM and MVE decode cases for score streams, mission voice, and taunts, plus WAV SFX cases, including malformed and unsupported variants;
- bounded retail `.fnt` cases for magic, flags, dimensions, glyph ranges, proportional widths, kerned and unkerned forms, bounds-derived payload lengths, and 4-4-4-4 alpha and color translation, plus canonical metrics and atlas images for every selected production role;
- one explicit production or superseded decision for each of the seven recognized retail font files, with no packaged orphan font;
- bounded OMF parsing into canonical regions, roles, loops, stream references and transition rules, including malformed instructions, invalid branches, missing streams, and loop failures;
- failed reimport leaving the active package, saves, replays, projects, and native packages untouched;
- compatible reimport preserving durable keys and semantic revisions;
- release-blocking detection of save-relevant canonical changes without the required semantic revision, plus reviewed semantic-equivalence assertions and encoding-only changes that correctly preserve revisions;
- no execution or copying of native retail code;
- no retail-derived fixture committed to Git.

Synthetic containers cover parser edge cases in repository tests. The verified owned CD-derived profile provides local end-to-end import evidence.

### Simulation

`RevivalCore` tests use explicit initial state, input frames, seeds, tick counts, and `simulationSemanticRevision`. Exact equality is expected for integer state, IDs, rule order, RNG state, objectives, damage, inventory, timers, and canonical normalized Float32 bits. Boundary tests reject NaN and infinity and normalize negative zero and subnormal persisted or hashed values as declared. Tolerances apply only to approximate higher-level regression claims, never to repeated authoritative replay state under one simulation revision.

The same replay must produce the same canonical state hash in repeated release-build runs on the supported architecture. Collection iteration order may not affect that hash. The authoritative arithmetic corpus contains exact Float32 vectors for normalization, every declared fused and separately rounded multiply-add form, and every named approximation or table. The corpus and same-revision replay hashes must remain exact before adopting a new OS, Swift compiler, SDK, optimization setting, or supported Apple-Silicon generation.

Flight tests cover the profile-persisted keyboard ramp-duration setting, transient held-key ramp timing and the new native reset-on-focus-loss/pause/load/remap rules, simultaneous translation axes and trichording, mouse and controller response, mass, thrust, exponential per-axis drag, rotational thrust and drag, turn roll, afterburner, `PF_WIGGLE` ship bob versus cockpit shake with the recorded authority decision, outdoor thrust scalar, and related impulse forces at 120 Hz. Replays and multiplayer consume resolved tick `InputFrame` values rather than serializing the live ramp accumulator. Collision tests cover swept contacts, wall slide, bounce and restitution, tangential motion, corners, portal crossing, and room ownership. Ratified native trajectory curves are the automated contract; old-executable captures remain non-normative local decision evidence and never become a CI dependency.

Navigation tests cover deterministic room and outdoor-region connectivity, sparse 3D nodes, clearance by robot size, disconnected rooms, portal and terrain transitions, locked or blocked doors, stable A* ties, route following, bounded replan, stuck recovery, authored path round trips, and diagnostics. No fixture constructs a generic floor-navmesh path the product does not run.

Difficulty table and branch tests cover all five named values for active rules with difficulty-dependent outcomes: AI motion and aim, weapon behavior, energy and shield pickup amounts, AI energy drops, non-scripted generic damage, and the typed behavior query. When two values intentionally share an outcome, the focused owning test names that equality. Separate focused tests prove the real authorable opt-outs at one scaling-sensitive value, the Rookie solo default, selected-value persistence, host-to-client binding before the first simulation tick, and rejection of out-of-range persisted or network values. Add only stock checkpoints that branch on difficulty; do not multiply every campaign test by five. Unused historical fields and contradicted comments receive no test until a reachable native decision exists.

Room-role tests cover canonical import and authoring plus the distinct runtime effects they own. Refueling tests prove fixed-tick rate, cap, sound and AI notification without frame-rate dependence. Cinematic tests prove logical timing, camera and target paths, control and AI policy, interruption, completion and state restoration. Cheat, easter-egg, and diagnostic tests cover each approved native effect, its solo/multiplayer availability, cheated-state and progression consequence where applicable, and authoritative replay treatment without reproducing the old encrypted-string implementation.

### Behaviors

Each graph value, expression, event, query, command, branch, timer, function, scope, persistence rule, compiler diagnostic, and instruction family has focused synthetic tests. Type errors and invalid references fail before play. Float32 boundaries, difficulty queries, cinematic commands, adaptive-score region and role commands, bounded multiplayer command events, historical server/client event classification, and translated `EVT_INTERVAL` rules have focused cases. Interval-heavy fixtures verify rate equivalence, timer boundaries, long-run drift, and measured operation counts at 120 Hz. While 4,096 is the active development ceiling, direct and multi-handler cycles fail at exactly that operation without hanging or advancing another tick.

Compiler tests prove stable observable semantics, source-map accuracy, and deterministic operation accounting. Debug tests prove breakpoints, traces, watched values, and runtime errors resolve to the authoring graph.

Phase 5, Phase 8, and Phase 9 measure the operation ceiling against stock campaign and object behavior, an independent campaign, multiplayer modes, and adversarial cycle fixtures. Before release, the project ratifies or raises one platform ceiling and reruns the exact-limit suite. The limit may not be used to exclude a ledgered behavior.

Each required stock behavior scope has local checkpoints: levels cover objectives, doors, timers, spawns, messages, set pieces, adaptive-score commands, and completion; reusable/default objects and archetypes cover lifecycle and domain behavior; campaigns cover transitions and persistent state; game modes and sessions cover lifecycle, rules, scoring, results, and failure paths. Declared community fixes, retail observations, and approved native divergences receive their own checkpoints. A scope is not translated because its content loads. It is translated when its required behavior completes in the new runtime and its ledger has no unexplained generated or handwritten source behavior.

Import tests verify the signed `StockBehaviorCatalog` version and manifest hash, source-provenance entries, scope closure, graph hashes, declared bindings, authoritative or client-presentation event roles, compile results, and package report. Removing any required level, campaign, module-role, package-default, owner, archetype, game-mode, client-presentation role, or session entry must make the applicable import scope fail before promotion.

Nonshipping DALLAS extraction tests use synthetic and GPL source fixtures to prove versioned tree recovery, operation metadata recovery, stable draft output, custom and handwritten range accounting, and unresolved-operation and binding reports. A draft cannot satisfy catalog coverage or import closure until human review promotes it.

### Saves and replay

New saves must:

- encode a version and content identity;
- bind one `simulationSemanticRevision` and reject or explicitly migrate incompatible authoritative state;
- round-trip authoritative difficulty plus canonical world, behavior, campaign, automap discovery, player-marker, logical cinematic, and logical adaptive-score state;
- reject corrupt or incompatible data without partially mutating the live world;
- omit renderer, framework, pointer, and transient task state;
- bind durable campaign, level, behavior-graph, multiplayer-mode, and session-definition keys and their separate semantic revisions rather than package-local IDs or byte hashes;
- remain deterministic for the same snapshot where the encoder guarantees stable ordering.

For each future-affecting state family, record world A's canonical hash at tick T, create the snapshot, and prove that snapshot creation did not mutate A. Load world B, compare A and B immediately, then drive both with identical resolved inputs and controlled boundary results for the smallest declared duration that reaches that field's next effect. Compare canonical hashes after every step. Focused fixtures cover RNG, timers, AI and navigation progress, behavior state, campaign state, and other durable fields; one phase-gate scenario crosses all state families used by the current playable slice.

Replays record resolved tick input, content identity, simulation revision, authoritative difficulty and other configuration, game-affecting player and host commands, seeds, and controlled nondeterministic boundary results. Ordinary chat text is excluded from authoritative hashes and replay by default. Repeated authoritative release-build playback on the supported architecture must produce the same declared state hashes and completion result. A multiplayer recording may also carry client, observer, transport, or presentation evidence with separately declared checkpoints; replay does not recreate packet timing or prediction history because those are non-authoritative presentation and diagnosis data. Corrupt, incompatible, truncated, and hostile replay data fails without mutating live state.

No test requires the original game to read a new save or replay.

### Creator projects and publishing

`RevivalEditor` tests cover:

- creation, mutation, undo, redo, save, close, reopen, migration, and reference integrity for every canonical document family;
- copy-on-write derivation of an imported document into an editable source replacement while proving that the base package remains byte-identical;
- atomic autosave, crash simulation, recovery preview, acceptance or rejection, and protection of the last explicitly saved project state;
- deterministic project decoding and publishing where the selected encoding promises it;
- content-catalog resolution, declared replacement order, duplicate ownership, missing dependencies, orphan detection, and destructive-change impact reports;
- Blender-exported USD import and stable reimport through Model I/O, fixed units and axes, room and portal assignment, topology and winding rejection, primary and secondary UV validation, provenance, destructive-change preview, and canonical save/reopen;
- deterministic planar lightmap charts for editor faces; provisional fixed 1024-square normalized bounds pending Phase 2 retail ratification; rejection of overlapping, out-of-bounds, under-guttered, or overflowing imported UV2; two-texel chart dilation; one nonmipmapped room-local `rgba8Unorm` output with no resolution or atlas-count fallback for native authoring after ratification; same-toolchain exact bake hashes; bake-revision review on toolchain drift; lighting-solve invalidation; failure safety; seam diagnostics; and preview;
- deterministic room, portal, outdoor-region, clearance and sparse 3D-node navigation baking, stable ties, invalidation, failure safety, unreachable-region diagnostics and preview;
- complete stack-global, resident-spine, level-pinned, cell, shared-resource, spatial camera-envelope, simultaneous-game-camera, conservative four-viewport, discontinuous-destination, `LoadWave`, queue, submitted-stale, active-high-water, and movement-lead-time accounting with source-linked publication refusal outside each supported envelope and no refusal based only on aggregate streamed presentation bytes;
- behavior compilation and stale-product detection;
- typed room-role editing, difficulty-selectable playtest, difficulty-scaling opt-outs, cinematic sequence authoring and declared multiplayer command and event roles;
- canonical font metrics, kerning, atlas generation, glyph coverage and replacement-font preview without any editor `.fnt` reader;
- adaptive-score authoring and preview, region and transition validation, logical save and replay round trips, and complete score-audio dependency closure;
- missed semantic-revision detection, explicit compatible-change acknowledgment, encoding-only preservation, and narrowly scoped invalidation;
- play-in-editor using the shipping simulation and return to the same document state;
- publisher refusal of broken references, invalid rights metadata where required, executable payloads, and incomplete dependency closure;
- package install, reopen, replay, and removal through the player application.

Human workflow evidence also covers synchronized selection and focus across the Project Navigator, Outliner, viewport, Inspector, references and Problems; direct and numeric editing; named undo and redo with gesture coalescing; standard menus and shortcuts; local layout restoration; Full Keyboard Access; VoiceOver navigation for nonspatial controls; long-operation progress and cancellation; stale-result refusal; key-document streaming handoff; and exact editor-state restoration after playtest. Automated tests protect project-owned edit, selection, source-location, save, transient `ProjectEditGeneration`, cancellation, stale-result and restoration contracts. They also prove that edit, undo, redo, save, revert and close drive `NSDocument` edited state correctly; local UI-state changes produce zero project-byte differences; one isolated edit rewrites only its owning canonical source and any strictly required manifest field; save/reopen remains byte-stable; the ignored preview overlay uses the shipping layer/blob schema and changes only for a matching generation; background-document viewports release live residency; and stale or cancelled results never enter or clear active Problems, report publish success, become playable, or replace the last good derived product. Cancellation and failure leave source and last-good derived outputs unchanged. Manual evidence covers AppKit focus behavior, accessibility, precision input and end-to-end workflow where testing Apple itself would add no value.

Task-based creator reviews include:

1. create an empty project and reach a playable connected room cluster;
2. derive an imported level, change it without mutating the base, and publish the replacement;
3. select a broken reference in Problems, navigate to its exact owner, repair it, and clear the diagnostic;
4. author, trace, pause, inspect, and fix a behavior through its source graph;
5. bake, play, publish, install, reopen, and replay one project;
6. interrupt an edit session and preview, accept or reject recovery without losing the last saved source.

Each gameplay feature's verification row names its applicable authoring operation, validation failure case, playtest scenario, and package round trip. A working imported instance does not prove creator support.

### Multiplayer

Multiplayer tests cover the fixed Network-framework QUIC transport and inner CryptoKit record contracts, authoritative state, and 2–32 connected human slots. Active combat and live observer modes each consume one slot; a listen host consumes one; no-window authority and relay processes consume none. A 32-slot session must join, exercise observer transitions, play, complete, and report measured authority and relay budgets. Tests also cover host-selected difficulty bound identically on every participating client before the first simulation tick, out-of-range difficulty rejection, exact simulation-revision agreement, content and version negotiation, join and leave, reconnection policy, invalid and hostile inputs, rate and size limits, dedicated-host lifecycle, game-mode rules, results, replay, and clean failure. Player pictures, ship logos, and audio taunts have format whitelists and caps for encoded bytes, decoded dimensions, sample rate, duration, transfer rate, cooldown, and aggregate session storage. Tests cover hash identity, app-controlled paths, malformed media, active-payload rejection, mute and disable controls, consent where required, host policy, and abuse-resistant failure.

Text-chat tests cover bounded UTF-8 input, sender identity, public, team and private routing, disconnected recipients, rate limiting, mute and block, host moderation, logging and privacy policy, malformed input, and abuse-resistant failure. Game-mode commands use declared typed events rather than raw chat execution. Dedicated-host tests run the same typed operator commands through local input and an authenticated encrypted remote-administration boundary, with authorization, audit, replay of game-affecting results, cancellation, invalid commands and connection loss. No shell or arbitrary process execution is exposed.

Deterministic local multi-instance tests establish repeatable state and desync evidence before network variability is introduced. Connectivity tests cover Bonjour LAN discovery; authority proof of possession; unguessable route handles; public registration, browse and join; short lease and registration expiry; single-use client-key-, route-, session- and expiry-bound join tokens; relay-only reachability from representative NATs; outbound-only host and client connections; certificate and key rotation; pre-allocation size limits; per-source and per-session connection and byte-rate quotas; amplification bounds; and authority-owned gameplay admission. Inner-record tests cover X25519 exchange, signed transcript, HKDF context, directional ChaChaPoly keys, one global sequence per directional key across streams, datagrams and channels, unique epoch-plus-sequence nonces, associated routing headers, key-bound sender and recipient identity, allowed channel roles, duplicate and stale rejection, reconnect rekey, session-key fingerprint comparison, and proof that relay processes receive no session key.

Outage tests bind the expected result: a discovery-control-plane outage blocks registration, browse and new joins while established relay data connections continue; loss of one client relay leg disconnects only that human and invokes bounded reconnect; loss of the authority leg or route-carrying relay worker ends the Internet match explicitly; LAN sessions continue; and no case falls back to direct-IP, Game Center, ICE, STUN, TURN, or automatic region migration. Privacy and retention tests cover only metadata visible to the relay. Encrypted chat and media moderation tests remain at the host and clients.

Movement tests drive tick- and sequence-numbered resolved six-degree-of-freedom `InputFrame` values through local prediction. Authority snapshots acknowledge the highest processed input and carry the full future-affecting movement state. Reconciliation restores that state, replays every later unacknowledged input through the production movement path, smooths presentation only, and hard-resyncs when an acknowledgment falls outside the fixed 256-input history. The matrix covers remote interpolation and bounded extrapolation, portals, room and outdoor-region ownership, wall contacts, collision flags, corrections, listen-host and dedicated-host bias, RTT, jitter, loss, duplication, reordering, burst loss, and recovery. Each weapon family declares separately whether it predicts presentation, predicts a reversible launch, or waits for authority; pickups, damage, deaths, collision outcomes, and gameplay-affecting weapon results remain authoritative. The 120 Hz simulation rate does not imply a 120 Hz network send rate.

Other network tests exercise disconnection, host failure, content mismatch, malformed envelopes, and relay capacity. No test requires an original client, packet, server, game module, or Linux service.

### Rendering

Renderer tests have two layers:

- CPU tests validate render-item extraction, transforms, room-and-portal traversal, room-frustum rejection, material and blend selection, lightmap bindings, mirror visibility and recursion bounds, procedural time, view ownership, cinematic camera and fade state, ordering, and buffer bounds.
- GPU tests render controlled synthetic scenes for opaque and lightmapped surfaces, declared alpha and additive variants, specular faces, mirrors, procedural textures, volumetrics, scorch decals, selected canonical stock-font atlases, cockpit, cinematics and every supported auxiliary view, then compare images with a declared tolerance.

Metal validation must be clean. Fixed images are pinned to the recorded OS, SDK, shader compiler, GPU, resolution, and settings. Cross-OS or cross-GPU comparisons use tolerances rather than a promise of bit-identical rasterization.

Every scene records its comparison metric, threshold, environment metadata, and any narrowly justified mask. A failure retains expected, actual, and diff artifacts. Baselines never regenerate automatically: a reviewed source change, visual inspection, clean Metal validation, and recorded reviewer approval are required. Begin with simple pixel and error metrics. SSIM, perceptual masks, or another comparison dependency enters only through an explicit verification-contract amendment; ordinary OS churn does not add it silently.

Repository font-rendering fixtures are synthetic or independently licensed. Selected imported retail fonts receive owned local atlas and fixed-scene evidence; neither their pixels nor retail-derived reference images enter Git.

### World streaming

Streaming tests use the production `WorldSpine`, resolved package-layer locators, cell tables, spatial demand calculation, retained command buffers from the bounded concurrent `MTLIOCommandQueue`, final private Metal resources, active world residency set, argument-table installation, and final-frame retirement path. A synthetic independently licensed package keeps stack-global and level-pinned records under their separate caps, makes the cell-referenced portion of `world.stream` at least three times larger than maximum resident cell demand, and has total GPU bytes above the active high-water so accidental whole-level retention fails.

Focused and integration evidence covers:

- deterministic indoor and positive-multiple-of-32 terrain cell tables, shared-resource dependencies, layer/blob locators, checked offsets, lengths, alignments, construction hashes, complete buffer and texture descriptors, and discontinuous destinations;
- conservative presentation-demand bounds containing every assigned static drawable, including an overhanging no-pop edge fixture, plus malformed, nonfinite and out-of-bound presentation refusal;
- external-package materialization into unique app-controlled staging, source close, whole-blob CryptoKit verification of staged bytes, and atomic promotion of that exact directory, including symlink, Finder-alias, special-file, hard-link, escaping-path, source-mutation, malformed-table, corruption and hash-mismatch refusal without promotion;
- stack-global, level-pinned and cell-referenced classification; orientation- and dynamic-occluder-independent spatial demand from every supported game and editor camera; the fixed render radius and lead-time shell; mirror dependency expansion through the fixed reflection depth; every simultaneous-camera profile; and teleport, spawn, cinematic and auxiliary-view destinations;
- retained `loadBuffer` and `loadTexture` submission with no Foundation payload read or shared-event alternate; bounded queue depth, command buffers, records, bytes and submitted-stale work; out-of-order and stale completion; successful-status render-owner handoff; complete next-frame installation; no render exposure before readiness; no retirement before the final referencing frame; and cutoff plus full drain of committed old-generation I/O, destination allocations, and retained file handles before a level, content-stack, or key-document successor begins loading;
- once-per-active-display-callback demand with a ratified maximum evaluation interval; initial and discontinuous readiness; maximum-speed portal and terrain traversal satisfying `prefetchShellDistance >= maximumContinuousCameraSpeed * (maximumDemandEvaluationInterval + T_wave)`; instant turns and door changes without new residency demand; repeated forward/backward churn; and a bounded CPU/GPU memory plateau;
- valid late work producing only the declared solo/replay/editor stall or network leave; missing, short, malformed-descriptor, out-of-range, unavailable-resource and Metal-I/O-error work producing terminal activation failure, safe partial-allocation retirement, actionable identity, no partial install, and return to the prior stable game/editor state without an infinite stall;
- clean Metal validation, Metal System Trace, I/O latency and throughput, residency-update cost, `recommendedMaxWorkingSetSize`, current allocation and high-water evidence on the recorded M4;
- identical authoritative simulation and replay hashes under different legal completion and stale-work orders;
- editor/runtime demand identity; generation-bound preview-layer resolution; key-document and content-stack handoff that stops old presentation and simulation, drains committed I/O and final GPU use, clears the dynamic set, releases overlay, level, spine, and streamer state, retires old stack globals, and only then installs and activates the successor; edit-viewport suspension and game-profile replacement during play-in-editor; exact editor-state/envelope restoration on exit; overlay and byte-report accuracy; diagnostic navigation; playtest; and publisher refusal;
- `DraftOverlay` slice capacity equal to the maximum visible dirty-geometry union across all four viewports; exactly three physical slices counted in key-editor residency and high-water; bounded editor memory plateau; no write to an in-flight slice; retention through final render use; stable-ID suppression and multi-dirty-cell visibility; invisible large-selection geometry consuming no capacity; pointer, drag and scrub samples changing only transient draft state; commit producing exactly one canonical edit, named undo action, `ProjectEditGeneration` advance and candidate build; cancel changing none; matching preview retirement; and stale-candidate refusal leaving all newer visible dirty records overlaid;
- streaming-stall accumulator, pending-edge, relative-delta, held-ramp, clock-rebase and no-catch-up behavior; current held-state resampling on resume; network-client leave semantics; and delayed old-generation I/O completion installing nothing, retiring safely, and never overlapping new-spine or initial-envelope activation;
- seam-free full-resolution borders between fixed terrain cells and proof that no sparse-resource, mip-streaming, runtime-LOD, LRU, memory-pressure, resident-only, or alternate-loader path exists.

Phase 1 ratifies the numeric stack-global, spine, count, level-pinned, cell, camera-envelope, simultaneous-camera, transition-overlap, render-radius, maximum-continuous-speed, demand-evaluation interval, `LoadWave`, `T_wave`, shell, queue, command-buffer, submitted-stale, I/O-latency, and active-memory limits before Phase 2 freezes canonical cell data. Later phases may tighten those measured constants but do not reopen the cell model or resource lifetime. A stock level that happens to fit in memory is not streaming proof.

### Application

Application tests cover input mapping, difficulty selection and persistence, pause and resume, cinematic control suspension and restoration, display resize, full-screen transitions, file locations, controller connect and disconnect, haptic capability detection and unsupported-device fallback, haptic enable and gain, audio and adaptive-score lifecycle, interruption and resume, movie playback, animated cockpit transitions, automap entry and discovery display, marker entry and view, rear and auxiliary camera selection, initial and discontinuous streaming progress and failure presentation, chat entry and mute/block controls, approved cheat, easter-egg, and diagnostic input with per-command session policy, player-media selection and mute controls, project and package selection, signed-helper invocation, staging-path validation and cleanup without a report, every helper-contract exit class, cancellation before and racing with promotion, malformed or missing reports, import failure recovery, package activation, and clean player and editor termination.

Every `RevivalMac` archive and combined player distribution must contain one arm64 `Contents/Helpers/D3Import` built from the expected target. `RevivalEditor` does not carry a second copy. Nested-code signature verification must pass, the helper must carry the expected signing identity and entitlements, and Gatekeeper testing must exercise an actual import launch from the notarized player app rather than merely inspect the archive.

Fixed-loop tests use a controlled monotonic clock. They prove the eight-tick catch-up ceiling, excess-time drop accounting, accumulator reset across lifecycle or streaming suspension, held-state reuse, exactly-once delivery of button edges and relative mouse/scroll impulses when a display callback produces zero, one, or multiple simulation ticks, and the streaming-stall reset and resume contract without catch-up or pre-stall impulse delivery.

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

Measure optimized builds. Use Instruments, Metal System Trace, Metal capture, and signposts around import, simulation, render extraction, command encoding, GPU passes, audio submission, and save operations. The allocation budget is also an automated release-build test command over the real production step and extraction path: after warm-up it exits nonzero for any project-owned allocation event inside the declared intervals. Record its failing red before the first production fix and its zero-allocation green afterward; retain an Instruments Allocations trace as supplementary attribution evidence.

The initial product targets:

- a fixed 120 Hz simulation without sustained backlog;
- stable presentation at the current display refresh;
- zero project-owned heap allocations inside warmed-up `RevivalCore.step` and render extraction for each declared production scenario;
- no Metal validation errors;
- bounded memory growth across repeated world-cell churn, level loads and restarts.

Phase 1 ratifies only the measured safety and capacity limits required by the fixed world-streaming schema. The Phase 4 combat slice records the first broader CPU, GPU, memory, startup, and import baselines. The complete Training Mission in Phase 5 establishes gameplay and editor performance budgets from a representative finished workload. Do not invent other thresholds before then. A claim of 120 frames per second of presentation requires a 120 Hz display; an offscreen result may be reported only as render throughput. A 120 Hz simulation alone is neither claim.

Every optimization report includes before and after measurements and the exact change. Revert complexity that does not produce a meaningful improvement.

## First playable combat slice

The first playable milestone must use only Swift, MSL, Metal 4, and native Apple frameworks at runtime. It passes when the new engine can:

1. import the required owned retail dependency closure into a canonical package;
2. start from that package with no retail archive mounted;
3. render the selected indoor room cluster with textures, lightmaps, models, animated cockpit, HUD, and correct portal traversal;
4. fly the Pyro with keyboard, mouse, and a controller through a fixed 120 Hz simulation;
5. collide with walls and pass through connected rooms without instability;
6. operate one animated door and one mission trigger;
7. run one robot's minimal AI through one deterministic room/portal and sparse 3D-node route with clearance and bounded replan;
8. fire one weapon, create a projectile, apply damage, and collect one pickup;
9. play positional sound and required instructional messaging;
10. pause, restart, save, reload, and complete the defined slice objective;
11. create or change the slice's rooms, objects, door, trigger, robot, weapon, pickup, and behavior through `RevivalEditor`;
12. validate, play, save, reopen, package, reinstall, and complete that authored interaction;
13. pass Swift tests, Metal validation, image checks, and the first recorded M4 profile.
14. traverse a presentation data set larger than the active spatial envelope through the shipping Metal I/O and residency path without changing authoritative hashes, exceeding the memory plateau, or exposing an unready cell.

## First complete mission

The complete Training Mission milestone extends the same path to every object, behavior, difficulty branch, selected production font, in-game cinematic, briefing, adaptive-score cue, cockpit, automap, marker, auxiliary view, and completion condition used by that mission. It includes campaign and presentation authoring, behavior debugging, package publishing, install, save, and replay. It is the first complete mission, not the first moment at which the new engine is playable.

## Campaign gates

A campaign level is complete when:

- import reports a closed and validated content graph;
- its behavior translation ledger is complete;
- a player can start, progress, complete, save, and reload it;
- required controls, difficulty rules, room roles and refueling, AI, weapons, fonts, audio, adaptive music, in-game cinematics, movies, HUD, cockpit, automap, markers, camera views, haptics, and transitions work;
- relevant synthetic and local content tests pass;
- every introduced capability has its applicable native authoring, validation, playtest, and publishing path;
- no unexplained crash, leak, validation error, or performance regression remains.

Campaign completion means every reachable mainline and secret level meets that gate, every secret entry and return transition works, and a fresh profile can reach the ending through a valid campaign path. Visiting and testing every stock secret level is mandatory for the base-campaign release gate even when a normal playthrough may skip it. A menu entry or load screen is not campaign support.

A release-complete import must also report every required campaign movie, briefing, selected production font, audio asset, and transition present, plus an explicit superseded decision for every recognized unused retail font. A deliberately partial development package cannot satisfy a campaign or release gate.

## Campaign and content creator gate

Campaign and content creator completion requires an independently authored campaign that begins with an empty native project. It must include indoor and outdoor levels, custom definitions, typed behaviors, campaign branches, adaptive music, cockpit and HUD presentation, automap and markers, auxiliary views, localization, lighting and navigation products, saves, replay, and a published dependency-closed package. The complete workflow uses `RevivalEditor`, the native mod SDK, and `RevivalMac`; it uses no legacy tool and no hand-edited generated file.

Every applicable non-multiplayer row in the functional-completeness ledger must carry creation, validation, playtest, and package evidence. Closing a campaign runtime row does not close its creator row automatically.

The human creator gate also requires the native document lifecycle, synchronized and accessible interaction model, undo, diagnostics, revision-safe background work, recovery, streaming inspection, task-based workflow reviews, and measured M4 responsiveness declared above. MCP, headless authoring, training capture, telemetry, and agent-specific workflows are not part of this gate and receive no speculative product tests.

## Multiplayer gate

Multiplayer completion requires every committed stock map and game mode, the declared 2–32 connected-human-slot range including live observer mode, every dedicated-host lifecycle, and the public relay deployment to pass the declared local, Internet, full-load and outage matrices. Dedicated-host tests launch `RevivalMac` in its no-window host mode and prove that it does not initialize the renderer, audio, or player UI or consume a human slot. Relay tests launch `RevivalRelay` without game content or simulation and prove registration, discovery, authorization, opaque routing, expiry, recovery and operational controls without consuming a human slot. A newly authored multiplayer package must be created, validated, published, installed, hosted, joined, completed, and replayed through native tools. Security limits and failure behavior are release criteria, not later hardening work.

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

Before implementation begins, active documents must agree on Swift 6.3, direct Metal 4, Apple Silicon, the single fixed-cell world streamer and resident authoritative spine, Metal I/O and one dynamic world residency set, finite stack-global/spine/level-pinned/cell/simultaneous-envelope/destination/`LoadWave`/lead-time limits, one-way import, USD creator ingress, purpose-built volumetric navigation, fixed room-local lightmaps, new saves and replay, typed behavior data, the human-first AppKit document editor, Network-framework QUIC plus inner CryptoKit records, 2–32 connected human slots with live observers consuming a slot, the project-operated relay and its fail-closed outage behavior, the complete creator and multiplayer scope, no legacy runtime, four Phase 1 targets, `RevivalEditor` as the fifth target in Phase 2, `RevivalRelay` as the sixth and final target in Phase 9, and binding red-first TDD with the test-value gate. A consistency search must find no active instruction to preserve OpenGL, C++, SDL, the Osiris ABI, original saves or demos, original network interoperability, backward export, whole-level presentation residency, sparse resources, runtime terrain LOD, a general asset manager, an early MCP or agent-only editor path, Game Center matchmaking, direct-IP Internet hosting, a stock-campaign-only feature ceiling, implementation-first testing, speculative coverage, or test-only production paths.
