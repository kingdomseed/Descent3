# Roadmap

- Status: accepted
- Date: July 13, 2026
- Authority: execution sequence; cannot redefine architecture or product scope

Every phase ends in a visible or objectively verifiable result. Campaign-first development orders the work; it does not reduce the [functional-completeness contract](functional-completeness.md).

Starting in Phase 2, every gameplay slice advances the matching authoring track. A feature is finished only when its applicable runtime, editor, validation, playtest, and publishing paths work.

Every production slice in every phase follows the binding [red-green-refactor protocol](test-driven-development.md). Phase gates and completion matrices supplement that focused cycle; they do not replace red-first evidence or justify tests for paths the product never runs.

## Phase 0: lock the complete product definition

Status: in progress

- accept the Swift 6.3 and direct Metal 4 architecture;
- define one-way retail import, canonical projects and packages, new saves and replay, the behavior system, creator suite, multiplayer commitment, verification, and minimal-code rules;
- define the pinned community source as the stock behavior baseline, the historical interval-to-fixed-tick translation rule, authoritative Float32 semantics, and one `simulationSemanticRevision` policy;
- lock one purpose-built streaming path for every presentation-capable level: a resident authoritative `WorldSpine`, one room per indoor cell, positive-multiple-of-32 terrain dimensions and fixed 32-by-32-quad cells, package-layer global and level blobs, direct Metal I/O, one dynamic world residency set, orientation-independent spatial camera envelopes, one `LoadWave`-timed prefetch shell, and publication limits on stack-global resources, spine, counts, level-pinned resources, cells, simultaneous cameras, discontinuous destinations, load waves, queue depth, stale work, and movement lead time;
- lock USD through Model I/O as the sole planned-product DCC interchange, the two-level volumetric navigation model, and the room-local lightmap policy;
- lock Network-framework QUIC, the inner CryptoKit record protocol, the project-operated public rendezvous and relay, Bonjour LAN discovery, 2–32 connected human slots, live observer slot semantics, and the complete six-degree-of-freedom prediction and reconciliation contract;
- complete the working functional-completeness ledger with one row for every required runtime, editor, behavior, campaign, multiplayer, replay, presentation, data-editing, baking, packaging, and mod-SDK capability;
- inventory adaptive music, automap, animated cockpit, haptics, player markers, auxiliary camera views, player-selected multiplayer media, mirrors, specular response, scorch decals, procedural textures, volumetrics, and blend semantics as explicit capabilities rather than umbrella terms;
- inventory retail bitmap-font roles, the five difficulty values and their active rules, in-game camera-path cinematics, typed room roles and refueling, per-command cheat, easter-egg, and diagnostic policy, public/team/private chat, host operator commands, and authoritative versus client-presentation behavior roles as separate capabilities;
- record for each row its historical evidence, native counterpart, milestone, owner, acceptance evidence, and current state;
- separate intended capabilities from dead menu shells, duplicated dialogs, and historical bugs;
- preserve verified retail hashes and the legacy M4 smoke run as non-normative evidence;
- audit active documents for stale compatibility requirements and hidden scope deletion;
- accept red-first TDD, the test-value gate, and the anti-dilution review rules as project law;
- author and review `revival-constitution`, `revival-verification`, `swift-realtime-systems`, `metal4-rendering`, and `revival-world-streaming`.

Exit: every active document describes the same complete product, the ledger covers the known historical capability surface, the five Phase 1 skills are installed and pinned with the TDD contract intact, and no production code begins without a focused red test or under conflicting instructions.

## Phase 1: create the smallest native shell

Create four targets:

- `D3Import`;
- `RevivalCore`;
- `RevivalMetal`;
- `RevivalMac`.

Prove the foundations needed by the next slice:

- advance each foundation one observable contract at a time through red, green, and refactor;
- Swift 6.3 strict-concurrency build;
- AppKit application with `MTKView`;
- installed Metal-toolchain compile and metallib-link smoke followed by direct `MTL4CommandQueue`, command-buffer, command-allocator, argument-table and app/dynamic-world residency-set submission of one MSL pipeline;
- a synthetic branching room graph and positive-multiple-of-32 terrain grid with small capped stack-global and level-pinned sets, a cell-referenced `world.stream` portion at least three times larger than the maximum resident cell-demand portion, and total GPU bytes above the active high-water, loaded through one bounded concurrent `MTLIOCommandQueue` directly into final private buffers and textures;
- whole-blob CryptoKit verification before package intake; full locator and buffer/texture descriptor validation; fixed orientation-independent camera envelopes and lead-time shell; simultaneous-camera and discontinuous-destination demand; bounded out-of-order and stale completion; atomic next-frame installation; last-use retirement; repeated traversal with a bounded memory plateau; intake-corruption, I/O, and late-envelope failure; clean Metal validation; and authoritative-hash independence from completion order;
- release-build M4 calibration of the stack-global, resident-spine, schema-count, level-pinned, cell, camera-envelope, simultaneous-camera, transition-overlap, render-radius, maximum-continuous-speed, demand-evaluation interval, `LoadWave`, `T_wave`, shell, queue, command-buffer, submitted-stale, I/O-latency, and active-memory constants before Phase 2 freezes the canonical cell tables;
- explicit streaming-stall accumulator/input reset and clock-rebase proof plus old-world teardown before new-world activation with no dual-level residency overlap;
- explicit Xcode build and copy dependency that places `D3Import` in `RevivalMac.app/Contents/Helpers` for nested-code signing;
- fixed 120 Hz accumulator with monotonic time, eight-tick catch-up ceiling, lifecycle reset, drop accounting, and deterministic tests;
- canonical Float32 boundary, normalization, encoding, fused-versus-separate multiply-add, required named arithmetic, and hash conformance vectors for the initial simulation semantic revision;
- one keyboard, mouse, and controller input snapshot;
- held-state and exactly-once input-impulse tests across zero, one, and multiple ticks per display callback;
- one AVAudioEngine sound;
- an automated release-build allocation-budget command that first fails on a warmed production-path allocation, then proves zero project-owned heap-allocation events inside the warmed-up fixed-step and render-extraction boundaries; retain the supplementary Instruments trace;
- clean shutdown, native file locations, release-build logging, and signposts.

Exit: a native player application displays a controlled streamed Metal scene, churns a presentation set larger than active residency through the one shipping lifetime path, advances a tested fixed-step world independently of completion order, accepts input, and plays sound. No legacy file is involved.

## Phase 2: canonical room cluster and editor foundation

Before this phase, author and review `d3-content-import` and `revival-creator-suite`.

Select a small connected cluster from the Training Mission. Implement its dependency closure:

- recognized prepared-installation-directory 1.4-plus-Mercenary source profile;
- minimal HOG and level decoding inside `D3Import`;
- canonical room, typed room-role, portal, face, UV, texture, lightmap, model, object, and player-start values;
- canonical resident `WorldSpine`, one room per indoor cell, deterministic resolved layer/blob locators, checked raw presentation ranges, complete resource descriptors and hashes, cell dependencies, spatial envelopes, and simultaneous-camera accounting;
- atomic base-package output and native package loading;
- lightmapped opaque rendering, portal traversal, prefetch, Metal I/O, residency installation, and retirement through `RevivalMetal`.

Add `RevivalEditor` as the fifth production target and the real human editor foundation. It provides:

- one AppKit `NSDocument`, one `@MainActor EditorSession`, and one primary project window per project;
- a Project Navigator and active-level Outliner, central tabbed canvas, contextual Inspector, and Problems/Activity pane;
- a polished inspection-first Metal level canvas with selection synchronized across hierarchy, viewport, Inspector, references, and diagnostics;
- one-, two-, and four-viewport layouts, standard menus and shortcuts, local layout restoration, keyboard access, and the first VoiceOver evidence;
- cell boundaries and load-state overlays, camera-envelope, prefetch-shell, destination and lead-time inspection, exact byte diagnostics, and the same shipping streamer used by the player;
- exactly one last-good and one candidate generation-bound preview layer outside project source, with the active level's complete project-owned GPU blob repacked through the shipping schema, atomic matching-generation replacement, final-GPU-use retirement, and no layer chain;
- one logical preallocated `DraftOverlay` with exactly three frame-safe slices, each capped to the maximum visible dirty-geometry union across all four supported viewports, that suppresses matching last-good stable IDs and turns a complete drag or scrub into exactly one canonical edit, undo action, generation advance, and candidate build;
- stable element IDs, the first concrete property edit with named undo and redo, structured source-linked diagnostics, and source-project creation, save, close, reopen, recovery, and deterministic diff behavior for canonical types already present;
- one synthetic Blender-exported USD room import and reimport through Model I/O with coordinate, topology, UV and provenance diagnostics.

Exit: the player and editor open the same canonical package with no retail archive mounted. Both stream and render the selected rooms and objects through the shared Metal path, and the editor foundation already behaves as a native document application rather than a temporary viewer.

## Phase 3: flight, collision, and first world editing

Add runtime support for:

- Pyro position, orientation, velocity, thrust, drag, and camera;
- the profile-persisted keyboard ramp-duration setting, transient held-key ramp and reset rules, simultaneous translation axes and trichording, and mouse and controller six-degree-of-freedom mappings;
- separately ratified mass, thrust, linear drag, rotational thrust and drag, turn roll and buffet curves at 120 Hz;
- swept movement against room faces with explicit wall slide, bounce, tangential and corner response;
- portal crossing, room ownership, repeated cross-cell churn, and maximum-speed spatial-envelope readiness under the fixed lead-time inequality;
- restart, pause, and render interpolation.

Add editor support for:

- deriving an imported canonical document into an editable project replacement without changing the base package;
- creating and changing rooms, typed room roles, vertices, faces, portals, materials, UVs, objects, and player starts needed by the slice;
- transforms, snapping, duplication, naming, undo, redo, and structural validation;
- synchronized selection and focus, direct and numeric edits, gesture-coalesced named undo, reference navigation, and streaming budget repair diagnostics;
- play-in-editor with return to the same selection and document state.

Run a nonshipping reference-capture pass with scripted input sequences against the old executable where the evidence path is practical. Plot input, position, orientation, linear and angular velocity, and collision points. The comparison has no parity threshold: each intentional native curve is ratified once and becomes the automated contract, then the old capture leaves the active test path.

Exit: the player can fly through the imported cluster, and a creator can modify that cluster or build a small new connected room set, validate it, save it, reopen it, and fly it through the shipping simulation.

## Phase 4: first playable combat and behavior slice

Before this phase, author and review `revival-behavior-system` and `revival-volumetric-navigation`.

Add runtime support for:

- one animated door;
- one trigger and the first `BehaviorProgram` executor;
- one robot with a small explicit state machine;
- the first deterministic room/portal and sparse 3D-node route, including clearance, one dynamic blockage and bounded replan;
- one weapon, projectile, collision, damage, and death path;
- one pickup;
- the five-value difficulty selection and each active difficulty-owned rule exercised by this slice;
- the first required room-role behavior, including fixed-tick refueling if the selected cluster contains an energy center;
- animated cockpit, HUD, instructional messaging, positional sound, and the narrow ACM import decoder if required;
- one-way retail bitmap-font conversion when the first selected stock HUD, briefing, or TelCom consumer requires it;
- new-format save and reload.

Add editor support for:

- placing and configuring the door, trigger, robot, weapon, pickup, HUD message, and sound source;
- the first typed `BehaviorGraph` event, conditions, queries, commands, variables, timer, compiler diagnostics, trace, and breakpoint;
- validation and play-in-editor for the complete combat interaction.

Exit: the Training combat slice passes every Phase 4 item in `verification.md`. A creator can rebuild the interaction in a new project without hand-editing generated files. Record the first Instruments and Metal baseline profiles.

## Phase 5: complete Training Mission

Before this phase, author and review `revival-replay`.

Expand import, renderer, simulation, AI, weapons, behaviors, messages, audio, adaptive music, difficulty, typed room roles, refueling, in-game cinematics, cockpit, automap, markers, required rear or GuideBot views, selected production fonts, and content to complete Training. Add the narrow OMF importer and canonical adaptive-score conversion when its first stock theme is required. Add the narrow MVE importer and AVFoundation transcode here if Training requires it; otherwise add it with the first level that does.

Complete the matching authoring surfaces for Training:

- goals, hand-authored paths, volumetric navigation topology and diagnostics, GuideBot configuration, failure and restart rules, and mission transition;
- behavior functions, subgraphs, persistent state, debugging, and operation-limit evidence;
- Training campaign metadata, briefing, instructional presentation, adaptive-score regions and transitions, audio, and localization;
- dependency closure, package publishing, install, and replay of the completed mission.

Ratify gameplay and editor responsiveness budgets from this finished workload and confirm or tighten the Phase 1 streaming constants against the complete mission without changing the streaming architecture.

Exit: a new player can start and complete Training using canonical content. A creator can inspect, change, validate, play, package, reinstall, and complete the native Training project through the integrated tools.

## Phase 6: base campaign and matching authoring coverage

Bring up level 1 end to end, then proceed through the campaign graph. Implement each secret branch when its entry first becomes reachable. For every level:

1. close the import dependency graph;
2. complete its behavior translation ledger;
3. write and run the focused failing test for the next missing observable contract;
4. add the smallest production change that turns it green;
5. add the matching creator operation, inspector, validation, and playtest path through its own red-green slices;
6. play, save, replay, reload, and complete the level;
7. keep performance and regression evidence green.

This phase adds streamed fixed 32-by-32-quad authored-resolution outdoor terrain and seam, spatial-envelope and lead-time evidence, reusable rooms, complete typed room roles and refueling behavior, broader geometry tools, materials, mirrors, specular response, scorch decals, procedural textures, volumetrics, required blend semantics, more robots and AI, weapons, inventory, GuideBot, doors, triggers, paths, navigation, matcens, goals, ambient systems, weather, lighting, adaptive music, in-game cinematics, briefings, movies, TelCom-style presentation, complete cockpit and automap behavior, remaining rear and auxiliary views including guided-weapon and marker cameras, broader native haptics, effects, bosses, campaign state, approved cheat, easter-egg, and diagnostic effects as their dependencies and per-command policies are established, and their required game-data editors as content reaches them.

Exit: the complete base campaign and every stock secret level pass their player gates. Every runtime capability introduced by the base campaign can be authored and tested in `RevivalEditor`.

## Phase 7: Mercenary and expansion authoring coverage

Apply the same level-by-level process to Mercenary. Reuse base systems and add expansion-specific runtime, behavior, content, and editor capabilities only where its evidence requires them.

Exit: Mercenary can be played through its ending with no legacy runtime component. All expansion-specific features have matching native authoring, validation, and playtest paths.

The old source remains available because editor, multiplayer, replay, and utility capabilities are not yet implemented and verified and may still require historical answers. Campaign completion alone does not trigger its retirement.

## Phase 8: complete campaign and content creation

Close every remaining non-multiplayer creator row through six execution work packages. They may overlap, but each closes named ledger rows with editor save, reopen, validation, playtest, and publishing evidence. They are groupings inside the existing `RevivalEditor`, not new targets or a second workspace architecture.

### 8A. World construction closure

Land the Blender-to-USD import and stable reimport workflow first. Then complete indoor geometry operations, outdoor terrain, reusable-room workflows, typed room-role and functional-metadata editing, native room and portal construction, primary UVs, validated secondary lightmap UVs, materials, mirrors, specular response, declared blend semantics, procedural surfaces, water, fog, volumetrics, scorch behavior, sky and environment, animated lighting, diagnostic views, viewport bookmarks, and complete object placement.

### 8B. Game definitions and player presentation closure

Complete robots, powerups, buildings, clutter, ships, weapons, doors, lights, sounds, ambient patterns, physics, animation, AI, death, inventory, effects, archetype definitions, difficulty-scaling opt-outs, difficulty-selectable playtest, adaptive-score authoring, cockpit and HUD definitions, automap metadata, auxiliary-view layouts, marker presentation, haptic bindings, and non-multiplayer media.

### 8C. Behavior, campaign, and presentation closure

Complete typed behavior authoring, functions, subgraphs, scopes, authority and presentation-role declarations, difficulty queries, debugging, tests, documentation, campaign graphs, secrets and returns, ship-selection rules, progress presentation, adaptive-score assignments, briefings, TelCom-style screens, purpose-built cinematic sequences, messages, canonical fonts, localization, media import, and preview. Phase 9 adds the multiplayer command-event declarations to this same workspace.

### 8D. Build and iteration closure

Complete the deterministic CPU lighting solve, room-local lightmap products, deterministic room/portal/clearance/3D-node navigation bake, validation and repair, statistics, dependency and orphan audits, streaming-cell, spatial-envelope, lead-time and simultaneous-camera reports and refusal, autosave and crash recovery, project templates, semantic-revision comparison and release-blocking diagnostics, package publishing, play-in-editor, and the campaign and content portion of the native mod SDK using the same projects, behaviors, packages, validation, and publisher as first-party content.

### 8E. Independent campaign certification

Build an independently authored campaign that starts from an empty project and uses indoor and outdoor spaces, custom content definitions, behavior, presentation, saves, and replay. Do not use hand-edited generated data or legacy tools.

### 8F. Human creator experience certification

Certify the complete non-multiplayer workflow as a native Mac product: predictable selection and focus across navigator, Outliner, canvases, Inspector and Problems; direct, numeric, keyboard and VoiceOver edit paths; named undo and redo; source-linked diagnostics and repair; responsive viewports and commands; cancellable revision-safe background work; source-control-safe saves; crash recovery; streaming overlays and budget repair; and exact return from play-in-editor. Run task-based reviews from empty project to playable room cluster, derived imported level to published replacement, broken reference to source repair, behavior failure to trace and fix, and interrupted edit to accepted recovery.

These work packages do not include the Phase 9 multiplayer authoring closure and do not weaken the Phase 8 exit gate.

Exit: every non-multiplayer creator row in the [functional-completeness ledger](functional-completeness-ledger.md) passes, every applicable imported campaign capability has an authoring counterpart, and the independent campaign installs and completes in `RevivalMac`. The full creator-completeness gate remains open until Phase 9 adds multiplayer maps and modes.

## Phase 9: native multiplayer, relay service, dedicated hosting, and multiplayer creation

Before this phase, author and review `revival-networked-simulation`, `revival-transport-security-operations`, `revival-multiplayer`, `revival-replay`, and `revival-verification` against the fixed transport, security, authority, replay, and operations contracts.

The transport and availability design is already fixed: Network-framework QUIC, Bonjour LAN discovery, a project-operated public rendezvous and relay service, host-authoritative simulation, and no legacy packet or server compatibility. Phase 9 implements that contract; it does not reopen Game Center, direct-IP Internet hosting, ICE/STUN/TURN, the original reliability layer, native game modules, or the server ABI.

Add the sixth and final target, `RevivalRelay`, as a no-window Apple-Silicon/macOS service containing only registration, discovery, join authorization, QUIC envelope routing, health and abuse controls, and operations. It never loads content or runs simulation.

Implement and verify:

- import and canonicalize the stock multiplayer maps and their required retail dependency closures;
- authoritative session ownership and state replication appropriate to the selected game modes;
- Bonjour LAN discovery plus public registration, browse, join, outbound relay connection, authority proof of possession, unguessable routes, short leases, single-use client-bound join tokens, bounded pre-allocation and traffic, registration expiry, fail-closed control-plane outage, terminal relay-data outage, version and content negotiation, failure recovery, and abuse-resistant input validation;
- ephemeral X25519 agreement, per-session Ed25519 authority proof, HKDF-SHA256 directional ChaChaPoly keys, authenticated visible routing headers, monotonic sequence and epoch nonce rules, replay rejection, rekey, and the same inner record codec on LAN and relay routes;
- exact `simulationSemanticRevision` agreement and content-revision negotiation before authoritative participation;
- host-selected five-value difficulty as immutable authoritative session configuration;
- bounded UTF-8 public, team, and private text chat with identity, rate limits, mute, block, moderation, privacy policy, and no raw command execution;
- one typed host-operator command set exposed through local input and authenticated encrypted remote administration, with authorization and audit but no Telnet, shell, or arbitrary process execution;
- classification and translation of every required historical server-side and client-presentation behavior event, with declared authority, replication, persistence, and replay treatment;
- secure player pictures, ship logos, and audio taunts with hash identity, format and decoded-data bounds, transfer and cooldown limits, app-controlled storage, malformed and active-payload rejection, mute and disable controls, consent where required, and host policy;
- no-window dedicated hosting through the `RevivalMac` executable, using the same `RevivalCore` simulation and network ownership as graphical sessions;
- the declared 2–32 connected human slots without reducing the historical maximum to Game Center's 16-participant ceiling; live observers consume a human slot, listen hosts consume one, and no-window authorities and relays consume none;
- complete local-ship prediction from tick- and sequence-numbered resolved six-degree-of-freedom inputs, authoritative snapshots with the acknowledged input and complete future-affecting movement state, replay of all remaining unacknowledged inputs, a fixed 256-input history with hard resync, presentation-only correction smoothing, remote interpolation, bounded loss extrapolation, and separate weapon-family latency policy;
- the original functional game-mode set or explicit modern counterparts recorded in the completeness ledger;
- deterministic recording, replay, diagnosis, and desync evidence for authoritative session state, plus explicitly declared observer, client, transport, and presentation evidence without a second replay engine;
- multiplayer maps, starts, teams, mode rules, session behaviors, validation, local multi-instance testing, package dependencies, and publishing in `RevivalEditor`;
- multiplayer mod-SDK documentation and synthetic examples, completing the native SDK.

Exit: supported modes complete repeatable local and network test matrices; one 32-connected-human-slot session including live observer transitions joins, plays, and completes within measured authority and relay budgets; the project-operated relay passes deployment, cryptographic-opacity and exact outage tests; dedicated hosting passes its lifecycle tests; replay reproduces declared session evidence; and a newly authored multiplayer package can be created, validated, hosted, joined, completed, and replayed using only native tools. The complete creator-suite gate now passes.

## Phase 10: complete revival release

- close every remaining functional-completeness ledger row or record an approved scope amendment;
- finalize import, project, package, save, replay, multiplayer, and diagnostics UX;
- prove atomic reimport and package publication failure safety;
- verify compatible and incompatible simulation and content revision handling, explicit migrations where supported, and narrowly scoped rejection diagnostics;
- complete settings and accessibility required by the product;
- verify controllers, displays, audio, movies, editor lifecycle, multiplayer lifecycle, and long sessions;
- sign, notarize, staple, and test Gatekeeper for both applications and the bundled importer;
- run full campaign, independent-campaign, creator-suite, multiplayer, replay, memory, performance, and clean-account matrices;
- document retail selection, local converted-content storage, project backup, package installation, hosting, and mod creation.

Retirement gate: remove the released C++ engine, old build workflow, and legacy launcher from the active product checkout only after every game, editor, Osiris and DALLAS, briefing, multiplayer, replay, and utility row is implemented and verified, replaced, or explicitly excluded, and no unresolved product question depends on the active tree. Move the reproducible owned-media preparation scripts and provenance documents into a clearly marked nonshipping support archive; no product target invokes them. Repository history, the pinned upstream commit, provenance, and hashes remain as evidence.

Exit: signed and notarized native macOS player and editor applications deliver the complete ledgered revival with no legacy source or build workflow in the active product tree.

## Phase 11: visual and experiential development

Continue improving the stable native product:

- higher-resolution textures and interface art;
- higher-detail models and animation;
- new lighting, materials, particles, fog, weapon effects, and post-processing;
- spatial audio and replacement music where rights permit;
- UI and accessibility improvements;
- new campaigns, multiplayer content, and creator workflows;
- replacement-content packages with complete provenance.

Visual work stays inside the accepted direct forward renderer and fixed-cell world-streaming model. MetalFX, a render graph, sparse resources, mip streaming, runtime terrain LOD, a second resident path, an OpenGL reference mode, and legacy asset-editing paths require an explicit architecture amendment rather than entering as opportunistic upgrades.

Only after Phase 10 certifies the complete human creator suite may a later product amendment design local automation, MCP tools, or agent training and evaluation. That future work must adapt the stabilized human edit, validation, playtest, and publishing operations. The current roadmap makes no MCP transport, process, schema, permission, telemetry, or training-corpus decision.

## Outside the current platform boundary

Intel Mac, iOS, visionOS, Windows, Linux, consoles, and web targets are outside the current roadmap. Adding one requires an explicit architecture amendment. No current code carries portability layers for a hypothetical second platform.

## Immediate next step

Finish the documentation consistency audit. Then complete the functional-completeness ledger and author and review the five Phase 1 project skills. Production code begins only after those gates pass.
