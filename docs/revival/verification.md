# Verification

- Status: accepted, amended
- Date: July 18, 2026
- Authority: binding evidence and acceptance contract

## Principle

Verify two things without confusing them:

1. translation fidelity: the native path preserves the source-supported observable behavior or records a deliberate difference;
2. product correctness: the accepted native game and creator contract works through the real shipping path.

The C++ source, reference executable, retail content, revision history, and historical notes are systematic translation evidence. They do not become permanent CI dependencies or require byte, file, ABI, packet, or UI parity.

Every new or changed shipping behavior follows [Test-driven development](test-driven-development.md). Documentation-only work uses link, consistency, and evidence checks. Disposable research captures unknown behavior but does not enter product targets.

After ordinary review is consolidated and before a material packet is declared `READY` or `HOLD`, handed off, or sent into additional terminal evidence, apply the independent [Revival completion gate](../../.agents/skills/revival-completion-gate/SKILL.md) once. Evidence is required only for the exact claim being made. Missing evidence for a later, broader, mobile, complete-mission, soak, support-floor, or release claim leaves that claim open; it does not automatically block a narrower current checkpoint.

## Evidence layers

Use the cheapest layer that can falsify the claim:

- source and call-path inspection for ownership, ordering, dependencies, and reachability;
- small synthetic fixtures for parsing, canonical values, state transitions, and failure boundaries;
- local retail-derived fixtures and captures for owned campaign translation;
- controlled renderer scenes and image comparisons;
- editor save, reopen, undo, play, and return workflows;
- optimized profiling on the recorded M4 Mac for Phase 1–7 claims, on recorded physical development iPhone and iPad devices beginning with Phase 8 mobile integration claims, and on representative floor devices before a public beta or release claims the candidate mobile support floor;
- end-to-end application, campaign, multiplayer, signing, and clean-account tests.

Do not duplicate the same assertion at every layer. Add an integration test only when composition can fail independently.

## Source translation evidence

Island-readiness evidence identifies the entry points and source or code areas inspected by the bounded fog-of-war preflight, newly exposed dependencies or unknowns, and any plan or ledger correction. If none are found, record that concise result with the inspected boundary. This proves that the pass occurred; it does not prove that the program has no undiscovered edge.

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

When a generated relationship view supports a claim, record the pinned source, extractor and version, compilation configuration, exact command, normalized output hash, and every unresolved edge class. Reproducible file, symbol, reference, or statically resolved call edges can direct review; they cannot by themselves prove runtime reachability, evaluation order, ownership, lifetime, indirect dispatch, or semantic fidelity. The view is optional evidence and never a closure gate unless a later accepted amendment gives one concrete artifact that role.

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
- proof that RevivalMac, RevivalMobile and RevivalEditor never open retail formats.

Synthetic fixtures enter Git. Owned retail packages, converted media, and captures remain local and ignored.

When an authorized exact-final owned import reaches the production importer and exposes a concrete current-scope defect before promotion, the smallest source-supported correction may receive one necessary affected-importer build and one fresh owned import without another user authorization. Each fresh run requires a distinct confirmed defect and an intervening correction; unchanged, exploratory, or precautionary reruns are prohibited. Only successful promotion unlocks one directly associated package-admission selector. This bounded recovery does not authorize another build matrix, unrelated selector, review, completion-gate invocation, launch, broad suite, profile, soak, or later dependency island, and it stops when correction would require a new product decision or wider packet.

Do not test stream cells, stream blobs, spatial envelopes, package-layer locators, semantic revision hierarchies, or external marketplace threats before those production boundaries exist.

Native-package tests begin with the shared `T-016` validator, destination-adjacent staging, atomic promotion and failure-preservation path plus the minimum `T-017` base activation and prior-set recovery path required by the later Mac-to-mobile handoff. Mac/shared work establishes and grows those canonical boundaries before required mobile integration. `T-016` proves every field and hostile case reachable in the initial canonical schema, including identity and revision, rights metadata, hashes, declared dependencies, path escape and unexpected special files, bounded media and destination failure; the same validator grows only when later packages add real schema. With the first publishing workflow, `T-017` expands to explicit base/replacement ordering, duplicate and conflict diagnostics, enable/disable, compatible replacement and removal. A post-promotion activation failure leaves the candidate inactive and the prior set active. `T-018` separately proves enumeration, actionable status, known save/profile associations, confirmation before orphaning and completion of an installed certification campaign. Focused production-boundary automation may cover `T-019` cancellation, hostile paths, low storage, interrupted copy, duplicate and replacement behavior early through those shared paths. Phase 8 physical runs on the recorded available development iPhone and iPad prove the OS-specific picker/provider grant and loss, representative install and activation, suspension and abrupt-death/relaunch recovery, abandoned-staging removal, prior-set preservation, backup-exclusion metadata for reimportable packages, and the separate durable policy for saves and profiles. Representative floor-device runs are added before public beta or release claims the candidate floor. Missing devices, signing, or development-team setup cannot turn Phase 1–7 package work into `HOLD`. These tests do not create a temporary mobile-only installer, mobile legacy reader, marketplace, cloud account, automatic updater, generic dependency solver or mandatory signature scheme.

## Resident world loading

The current resource-lifetime path proves:

- the complete canonical Level and current dependency manifest validate before the commit boundary;
- the source-accounted eager working set is ready at activation and later reachable assets resolve only from the canonical package;
- RevivalMac, RevivalMobile and RevivalEditor resolve and render the same dependencies;
- room/portal and terrain visibility do not change the authoritative resident world;
- pre-commit failure preserves the prior stable state;
- post-commit preparation failure enters an explicit unloaded error state rather than requiring two complete GPU worlds;
- no partially constructed authoritative world becomes active;
- repeated load, restart, editor play, return, document replacement, and shutdown do not produce unbounded CPU or GPU memory growth;
- new submissions stop and final GPU use completes before the level owner releases resources and file handles;
- there is one loader and one renderer, with no resident/streaming switch or legacy fallback;
- optimized startup, transition, memory, lifecycle and editor costs are recorded on the M4 at representative Phase 1–7 milestones; the applicable physical mobile, thermal and lifecycle costs are added at Phase 8 and later mobile gates.

After the complete playable Training Mission, run the broader evidence gate in [World loading and residency](world-loading.md). A future amendment receives tests for its real production mechanism; no hypothetical streamer tests exist now.

## Simulation and timing

During the translation phase, controlled-clock tests prove:

- systems and `EVT_INTERVAL` receive the old `Frametime` and pre-update `Gametime` values explicitly;
- the static/`InitGame` 0.1-second initialization, without falsely assigning it to every level reset;
- source-supported update and event order, including post-cap new-delta storage, `Gametime` advance, and remaining tail work;
- nested pause, focus loss, UIKit inactive/background/foreground transitions, suspension and resume clock rebasing without a giant catch-up delta;
- input ramps, flight, collision, portal ownership, timers, animation, and interval behavior against reference traces;
- no hidden read of a global Frametime value.

Phase 3 selected one explicit variable-delta scheduler. Controlled tests compare jittered admitted-display intervals with a bounded 120 Hz research cadence over equal elapsed systems time. Constant forward flight uses `1e-5` velocity and `3e-4` position bounds. The carrier/contact case retains exact ramp endpoint, wall identity and room ownership while declaring the measured cadence-sensitive bounds of `2.6` velocity and `0.24` lateral position; afterburner/wiggle uses `4e-6` fuel, `1e-4` velocity and `1.6e-3` position while retaining falloff and portal ownership exactly. These are sensitivity comparisons, not source-native traces or universal cadence-invariance claims. Existing characterization tests separately protect source formulas and use their own exact, `1e-6`, `1e-5`, `2e-4` and `1e-3` tolerances.

The separate source-native comparison uses an ignored released C++ Training trace and an ignored shipping-Swift replay with the same measured deltas and controls. The controlled path starts at `(2061.7126,-220.75536,2206.3005)` in room 3, crosses to room 4 on frame 17 and first contacts room 4 face 26 on frame 28 in both implementations. Frames 0–27 differ by at most `0.001128` position, `0.006272` velocity and `0.000098` forward orientation per component; all 30 frames, including two response frames, differ by at most `0.092799`, `0.136762` and `0.000111`. Old/new frame duration differs by at most `1e-9`, pre/post game time by `2.7e-8`, fuel by `2.2e-7`, and wiggle falloff by `2.1e-8`. The released traces also retain interval-event order/values and the reached animation field as Phase 4 handoff evidence; Phase 3 makes no false Swift-executor or gameplay-animation parity claim before those owners exist. Phase 4 must consume those records when it translates its first behavior and animation chain. The raw 120-frame released traces, 30-frame Swift replay and comparison JSON live under ignored `runtime-data/revival-evidence/`; their SHA-256 values are recorded in the source ledger. The trace-only source instrumentation and local-package test were removed, and the clean native `Descent3` target was rebuilt.

Focus/lifecycle pause rebases without catch-up. The renderer samples time only after presentation, a reusable frame slot, drawable and render-pass descriptor are available; a callback rejected at that admission guard does not advance simulation. The sample precedes simulation, procedural updates and command encoding, and its interval becomes the next stored duration while systems and procedural presentation consume the prior duration and pre-update game time. Current water visual output uses the maintained canonical 60 Hz tick with exact hashes, explicit two-through-eight sequential-equivalence evidence and the greater-than-eight discontinuity rule. Replay later records explicit selected deltas through the same model. No fixed-step adapter, compatibility flag or alternative scheduler is tested or shipped.

The 120 Hz cadence is only a bounded comparison, not a production tick. Do not infer a fixed update rate, a general eight-tick simulation ceiling, fused-operation policy, or zero step allocations from the selected scheduler.

## Gameplay

Focused gameplay tests protect the current source-supported rule:

- six-degree-of-freedom input, ramps, simultaneous axes, mouselook, autoleveling, afterburner, turn roll, ship wiggle, and cockpit shake;
- thrust, mass, drag, forces, collision, wall slide, bounce, corners, portals, and room ownership;
- doors, triggers, keys, room roles, refueling, damaging rooms, volatile/lava/water surfaces, the headlight and its stolen/recovery state, objects, inventory, ordinary fire, homing, player-guided, charge/release, continuous/spray, single-target electrical, zoom, child-spawn, persistent-effect and player-triggered timeout/detonation weapon mechanics, resource and weapon-grant pickups, cloak, invulnerability, immediately activated quad fire with drop bookkeeping, converter, afterburner cooler, timed RapidFire, countermeasure inventory and the Seeker, Betty, Chaff, Gunboy and Proximity Mine families, projectiles, damage, and death;
- robot state, room and node routing, clearance, steering, blockage and recovery, plus source-supported thief and SuperThief inventory interactions;
- goals, difficulty, GuideBot, campaign state, saves, and progression;
- HUD, cockpit, automap, markers, cameras, cinematics, messages, results, and approved commands;
- TelCom goal status, ship status and mission ship selection as separate surfaces, each covering its applicable state, navigation, localization and campaign transition behavior.

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

Controlled overlapping scenes separately prove far-to-near composition across translucent faces, models, effects and terrain, including depth-write, fog and mirror interaction. Dynamic object-emitted lights prove the reached player, weapon, powerup, robot and building families indoors and outdoors. Runtime attachment tests cover aligned and radial nesting, transforms, mass, room reassignment, parent lifetime and save/replay/network state independently from attachment-point import.

Reference images first establish source-faithful output. A deliberate visual modernization records before, after, environment, metric, threshold, and review.

Metal validation must be clean. Fixed images record application target, OS, exact device, SDK, compiler, GPU, drawable size and scale, safe-area geometry, orientation, settings and content identity. Baselines never regenerate automatically. Tests protect project decisions, not Metal, AppKit or UIKit framework behavior.

## Editor

The Phase 1 integration test opens the complete canonical Training Level in RevivalEditor, focuses the selected acceptance room, and proves the smallest real edit selected from the traced historical editor/runtime workflow:

- read-only base to editable project to disposable play-session flow;
- shared world types, loading rules and renderer with RevivalMac and RevivalMobile, without shared mutable ownership;
- selection and inspection;
- one project edit, named undo, redo, save, close, and reopen;
- play through the shipping simulation and renderer;
- return to useful document, selection, and viewport state;
- clean replacement and shutdown of complete-level world resources.

Later workspace tests cover each actual operation's reference integrity, validation, undo, save/reopen, playtest, and publishing. Independently failing creator families include goal targets and completion rules; briefing navigation, conditions and media effects; TelCom goal-status, ship-status and mission-ship-selection preview and applicable campaign authoring; behavior-message catalogs and localization; modern-font glyph/metrics/kerning/atlas work; sound, ambient/reverb and terrain-audio definitions; adaptive-score graphs; and native package publishing. Human evidence covers focus, discoverability, keyboard, VoiceOver, diagnostics, recovery and M4 responsiveness at the phase where the surface exists. Publishing closure additionally installs and completes the certification package through both player applications.

When a real background operation can race with editing, prove immutable input, cancellation where supported, stale-result rejection, source-linked failure, and preservation of newer source. Do not test a universal generation counter, preview package cache, fixed overlay slices, or streaming diagnostics unless they become accepted production mechanisms.

## Saves and replay

Save tests round-trip every durable state family that the current milestone owns, then step the original and loaded native worlds under the same future inputs and compare the accepted authoritative checkpoints.

Player save-workflow tests separately cover named slots and thumbnails, empty and corrupt entries, restrictions, overwrite confirmation, quicksave selection and fallback, campaign/package identity, load failure and actionable recovery. A controlled interrupted or failed write must leave the prior valid save readable; canonical state round-trip does not substitute for durable-storage proof.

Replay tests begin after the final scheduler is selected. They cover current input, configuration, authoritative random seeds and consumption order, behavior state, commands, content identity, and checkpoints required for repeatable playback and diagnosis. Source tracing accounts for presentation call sites that historically reseed or consume the shared RNG. Any accepted authoritative/presentation split records the coupled historical result, the new result and the test protecting the deliberate difference; presentation randomness never silently perturbs or enters authoritative hashes.

Do not compare legacy save or demo bytes. Do not add a full semantic revision hierarchy until a public compatibility promise exists.

## Audio, music, fonts, and movies

Import tests cover the exact FNT, OSF-with-ACM, WAV, OMF, and MVE constructs reached by current owned content plus malformed bounds and missing dependencies.

Runtime tests independently cover UI/2D sound, point and object source lifetime, room/portal propagation and door attenuation where source-supported, ambient probabilities and delay ranges, per-room reverb, terrain-altitude bands and fades, voice queueing, adaptive-score state and transitions, font metrics and images, movie timing, interruption, device change, channel priority/voice stealing and missing output devices. RevivalMobile also proves its declared AVAudioSession category, mode, mixing and silent-switch policy, activation, route changes, interruption and foreground/background recovery without duplicate playback. Exact audio waveform timing is presentation evidence, not authoritative gameplay state.

Creator evidence covers the corresponding definition/import, placement, preview, validation, rights, save/reopen/play, font-atlas build and package path as each independently failing medium arrives.

## Multiplayer and untrusted boundaries

Phase 9 verification uses the final simulation and behavior models plus the one affordable native Internet topology accepted from the Phase 0 study. It covers:

- each stock mode at its source-supported player count, the released 32 network/player-slot infrastructure, historical listen-host and dedicated-server slot accounting, four-player campaign co-op, live observers, and join/leave/recovery;
- content and simulation agreement;
- prediction, reconciliation, interpolation, weapon policy, replay, and desync evidence;
- Bonjour LAN plus the selected Internet discovery, reachability, authorization, security, privacy, abuse, operating-cost, continuity, and explicit outage results; physical iPhone and iPad runs cover local-network declarations, permission denial and recovery, mobile suspension and listen-host limits; no relay or project-operated service is assumed unless the accepted topology contains one;
- authenticated encryption or provider-equivalent protection, sequencing, replay rejection, bounded records, rate limits, and malformed input at the selected topology's actual transport and trust boundaries, using Network or CryptoKit only where applicable;
- chat, moderation, host commands, interactive and dedicated host-configuration presets, modern player-media ingress and preview, and privacy;
- multiplayer authoring, validation, local multi-instance play, publishing, and install.

Security checks concentrate at untrusted decode and authority boundaries. Trusted simulation values do not repeat packet validation defensively.

## Application and release

Application tests use the Phase 1–7 Mac/shared matrix and the accumulated Phase 8+ physical mobile matrices over the same Core contracts. They cover the clean-profile gate and explicit menu/new/load/replay/multiplayer/level/completion/failure transitions; solo and multiplayer pause, nested focus/suspension and resume; profile lifecycle; separate input/gameplay, display/detail and audio/voice/haptic setting families; AppKit window and UIKit scene/orientation/safe-area/drawable lifecycle; files and app-owned storage; Mac import-helper invocation; both native package libraries; level loading; audio routes; movies; physical and touch controllers; haptics; chat, host presets and commands when present; delivered orderly teardown; abrupt mobile process death and relaunch recovery; signing; and failure recovery. Each category applies only at the phase that owns its product claim.

Operational-diagnostic evidence verifies severity and subsystem categories, OSLog public/private classification, bounded retention when durable logs exist, source-linked importer/editor/host failures and the user-visible fatal-error outcome. Fixtures containing credentials, local paths, player addresses and other private values prove they are not emitted as public log fields or automatic uploads. The product has no telemetry requirement.

Mac archives prove the expected signed D3Import helper is bundled and launched successfully under Gatekeeper. Complete Mac releases prove signed and notarized player and editor apps on a clean account. Mobile archives prove signing, entitlements, privacy declarations, clean-device installation and update preservation on the supported iPhone and iPad, absence of bundled retail content, GPL/source delivery and acceptance through the selected lawful distribution channel. The release record verifies that channel's enabled device/platform availability. App Store availability is not assumed; if it is selected, unapproved visionOS availability and iPhone/iPad-app execution on Apple Silicon Macs are disabled.

## Reference environment

The pre-product environment snapshot used for current archaeology and documentation checks is:

- Mac mini Mac16,10;
- Apple M4 with 10 CPU and 10 GPU cores;
- 16 GB unified memory;
- macOS 26.5.2;
- Xcode 26.6 and Apple Swift 6.3.3;
- Metal 4;
- 1920 by 1080 at 60 Hz on the current display.

Phase 1 product builds and optimized measurements use Xcode 27 and the Swift 6.4 compiler in Swift 6 language mode: the current beta until the stable release, then stable Xcode 27. Xcode 26.6 and Swift 6.3.3 are not a supported product lane. Record toolchain, OS, display, content hash, build configuration, and settings beside every result. Do not record local identifiers or serial numbers.

Apple GPU family 7 is the candidate mobile feature floor. The earlier audit identified A14-generation examples at that floor, but published specifications and an arbitrarily selected old model do not prove the product's physical memory, drawable, lifecycle, thermal, audio, input, package-intake, or performance behavior. No exact old device is a prerequisite for starting or continuing the rewrite.

Use the available physical development devices recorded in the [current implementation plan](current-plan.md) when the required Phase 8 mobile integration lane begins. Record their exact model, OS, toolchain, drawable, content, and settings with the resulting evidence; do not infer those details from a chip family or planning label. Before then, simulator launch, target builds, and unsigned generic-device builds may prove compilation and focused composition but cannot prove device effects—and the missing device proof is deferred, not a Phase 1–7 blocker. Before public beta or release claims Apple GPU family 7 as the support floor, run the accepted representative floor-device matrix. If suitable floor hardware is unavailable or fails the matrix, raise the released floor to the oldest hardware actually verified and update every deployment, distribution, and support record together.

The [current implementation plan](current-plan.md) alone records whether the product-toolchain gate is still open and which packet is next. Before Phase 1 production code, select Xcode 27, verify its Swift 6.4 compiler and SDKs, and record that evidence there. Mobile hardware availability does not block D3Import, shared Core/Metal, RevivalMac, RevivalEditor, or later Mac/shared dependency islands.

## Performance method

Before starting a nontrivial trace, profile, repeated lifecycle campaign, soak, or terminal-evidence run, state the hypothesis, current accepted claim, production path, content and optimized build, bounded duration or cycle count, comparison or threshold, and code, product, support, or next-evidence decision that the result will change. If those facts are absent, use the completion gate to classify the work as later or unnecessary instead of collecting evidence because a tool or broad checklist exists.

One bounded lifecycle exercise may falsify new ownership and release behavior. It does not prove indefinite absence of leaks or growth. A clean bounded result ends that check unless a reproducible signal, ratified budget, or later accepted milestone requires more.

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
- repeated load/restart and long-session stability;
- mobile lifecycle, memory-warning, thermal-state, route-change and orientation cycles where applicable.

These symbols and compiler constructs are diagnostic leads, not failures by themselves. The Swift 6.4 `PerformanceHints` diagnostics may be enabled as warnings for a focused performance investigation; they are not a project-wide error policy or a reason to ban protocols, generics, collections, or classes outside a measured path. Attribute a missed budget or regression to the responsible function, allocation, copy, pass, transfer, or wait before changing code.

The first source-sensitive profiles cover the paths recorded in [Swift engine-code feasibility evidence](discovery.md#swift-engine-code-feasibility-evidence): collision and FVI, object and behavior update, room/portal and terrain extraction, dynamic lighting when reached, and the editor-to-play world-copy boundary. Compare the same accepted observable path before and after a change. Do not substitute a language headline or unrelated microbenchmark for product evidence.

The selected acceptance room within the complete resident `Level` records a baseline, not a global budget. The connected cluster and flight slice expand it. The complete playable Training Mission establishes the first credible product budgets and the resident-resource decision.

An optimization starts with a reproducible missed budget or regression. Keep it only when before/after measurements support it. Zero steady-state project allocations may become a targeted hot-loop contract; it is not a Phase 1 requirement.

## Milestone gates

### Phase 1: complete Level with selected-room acceptance

The Mac/shared Phase 1 checkpoint below authorizes Phase 2. Full Phase 1 product establishment additionally requires the bounded Slice 4 universal UIKit target, an unsigned generic-device or simulator build, and focused shared-path wiring evidence. Neither checkpoint requires physical-device visibility, trust, signing, or development-team setup, and an open Slice 4 does not block the next Mac/shared island.

The checkpoint passes when:

1. D3Import converts the complete owned Training Level topology through production parsers and emits the current reachable dependency manifest, distinguishing the eager dependencies reached by `PageInAllData` from later canonical preparations;
2. RevivalMac and RevivalEditor each construct separately owned complete resident canonical `Level` values from the package with no retail archive mounted;
3. both applications render the same selected lightmapped room through the one direct Metal path;
4. the editor derives a project value from the read-only base, changes one real value, undoes, redoes, saves, and reopens it;
5. editor preview creates a disposable play-session copy, enters the shared shipping paths, and returns;
6. the eager working set is ready at activation, later reachable assets resolve only from the canonical package, replacement follows the pre-commit/post-commit failure contract before final-use release, every reached source and functional row records the state its evidence supports, and focused red/green, affected-suite, clean Metal validation, and optimized M4 evidence are recorded.

The early mobile packet must prove that the universal UIKit target builds and wires the accepted Core, Metal, and package paths without another implementation. It advances mobile rows only as far as its focused automation, simulator, or unsigned generic-device evidence supports. It does not require or claim physical picker, presentation, lifecycle, touch, audio, memory, or thermal behavior.

The Mac/shared Phase 1 checkpoint passes when the requirements above close through one production path and releases Phase 2. The Phase 1 product-establishment record closes when the early mobile target/build packet also passes. `P-090`, `P-091`, `T-019`, and other physical mobile rows may remain open for Phase 8; `P-093` support-floor certification remains a Phase 10/public-release concern.

### Phase 8: accumulated mobile integration

The first required physical mobile gate passes when:

1. RevivalMobile constructs its own complete resident canonical `Level`, presents the accumulated campaign through the accepted Core/Metal path, and introduces no second loader, renderer, scheduler, input model, package schema, or lifetime path;
2. it acquires a Mac-produced canonical package through the system picker and shared `T-016`/`T-017` validation, staging, promotion, and activation path;
3. one selected direct native touch-control mechanism and physical controllers deliver every reachable action through the shared input snapshot without stuck state or a touch-only simulation path;
4. recorded available physical development iPhone and iPad runs prove applicable landscape/drawable/safe-area, package failure, suspension, audio interruption, abrupt-death/relaunch, abandoned-staging cleanup, prior-content preservation, backup, save/profile, memory, thermal, and lifecycle contracts;
5. affected mobile rows advance only as far as their focused red/green, affected-suite, clean Metal validation, application, and physical-device evidence supports.

Candidate-floor certification remains a Phase 10/public-beta or release claim and is not part of this development-device gate.

### First playable combat slice

Phase 4 passes when the selected connected Training cluster supports:

- flight and collision through the selected final scheduler;
- one door and trigger;
- one robot route and AI chain;
- one weapon, projectile, damage path, and pickup;
- required HUD, cockpit, sound, messaging, difficulty, save, and reload;
- complete generated and handwritten behavior accounting;
- authoring, validation, playtest, save/reopen, and package proof for the interaction;
- clean tests, Metal validation and optimized M4 profiles; the accumulated physical mobile combat and performance proof joins at Phase 8.

### Complete playable Training Mission

Training passes on the Mac/shared lane when every required runtime, behavior, presentation, save, replay, editor, validation, and publishing path works. It also closes the M4 resident-level evidence gate with a recorded keep-or-amend decision. Phase 8 repeats the applicable player, lifetime, input, and presentation outcomes on physical mobile development devices.

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
- signed and notarized Mac applications pass clean-account and Gatekeeper checks, and the signed universal mobile application passes clean-device, update and selected-distribution-channel checks on supported iPhone and iPad hardware;
- no product path requires a legacy executable, editor, format reader, ABI, or protocol.

## Documentation gate

Before Phase 1 production begins, active documents must agree on:

- the Swift 6.4 compiler toolchain in Swift 6 language mode, using Xcode 27 beta until stable Xcode 27 replaces it, plus MSL, direct Metal 4, arm64 macOS 26+, iOS 26+ and iPadOS 26+ player targets, Apple GPU family 7 as the candidate mobile feature floor pending representative release evidence, and macOS-only editor, importer and dedicated host targets;
- source-accounted semantic translation with recorded differences;
- no shipping C++, OpenGL, SDL, MFC, native module, or compatibility backend;
- one-way import and retail-data isolation;
- one complete resident Level world, source-accounted eager working-set preparation, and canonical lazy paging added with each reachable translated path as the current implementation;
- no speculative stream cells, stream blobs, spatial demand, or resident/streaming switch;
- one explicit source-faithful old/new variable-time scheduler followed by a single Phase 3 timing decision;
- macOS-leading Phase 1–7 implementation in which D3Import, shared Core/Metal, RevivalMac and RevivalEditor establish each slice while the shared contracts remain directly mobile-composable; early RevivalMobile target/build work is nonblocking, and Phase 8 performs the required direct mobile integration behind the one UIKit shell;
- complete human creator, campaign, replay, multiplayer, and mod-SDK scope through the evidenced shipped-game and creator-tool capability;
- version 1.0 retail ownership and the one supported prepared-installation profile, with additional profiles and replacement assets left to later decisions;
- affordable native Internet multiplayer as a required outcome, with the operational topology held as a Phase 0 research question rather than a preselected project-operated service;
- focused red-first shipping implementation plus bounded disposable research;
- evidence-driven modernization that deletes the superseded production path.

The Phase 1 environment check must also show Xcode 27 selected, Swift 6.4 in Swift 6 language mode, the recorded macOS and iOS SDKs, the macOS deployment target, the universal mobile target's iOS/iPadOS floor, the candidate Apple GPU family 7 feature floor, and no Swift 6.3 compatibility branch. During the beta window it records the exact beta build; after release it records stable Xcode 27 and deletes any beta-only workaround. Exact physical mobile development environments are recorded at Phase 8; representative floor-device evidence is required only before the public beta or release claims that floor. Neither requirement can be used as an earlier blocker.

The roadmap and accepted contracts point to [Current implementation plan](current-plan.md) as the single living record for current state, active slice, lane ownership, and real blockers. No active document maintains a competing current-work queue.

A consistency search must find no active instruction that makes fixed-cell streaming, fixed 120 Hz, exact target counts, a complete speculative behavior VM, a generic platform layer, a mobile-only lifetime mode, a fixed editor overlay protocol, or a provisional lightmap atlas a Phase 1 prerequisite.
