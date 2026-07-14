# Roadmap

- Status: accepted, amended
- Date: July 14, 2026
- Authority: concrete execution sequence; cannot reduce product scope

Every phase ends in a runnable, visible, or objectively verified product result. Campaign-first development orders the work; it does not reduce the [functional-completeness contract](functional-completeness.md).

The player and editor advance together from the first canonical world. A phase does not need the complete creator suite, but every new canonical type and runtime behavior gains the authoring, validation, playtest, and publishing path that is applicable at that maturity.

Production work follows [Test-driven development](test-driven-development.md). Bounded disposable research may answer an unknown source question before a production contract is stated; it is never shipped or retained as a second path.

## Phase 0: reconcile the product and map the source

Status: in progress

Amend the active documents so they agree on:

- Apple Silicon, macOS 26+, Swift 6.3, MSL, and direct Metal 4;
- dependency-ordered semantic translation of the pinned source;
- no shipping legacy engine, ABI, renderer, platform layer, or native module;
- complete functional scope and one-way retail conversion;
- one complete resident level world with source-faithful eager and lazy asset paging as the first loading implementation;
- the explicit source-order old/new variable-time handoff as the first scheduler;
- one shared editor/player world model, renderer, level I/O, and play path from Phase 1, with separately owned document and play-session values;
- evidence-driven modernization with one surviving production path.

Seed and then expand the checked-in source-translation ledger with:

- the runtime and editor files required for initialization, HOG and level loading, rooms, portals, terrain, objects, dependency paging, rendering, and editor-hosted play;
- each file's responsibility, callers, globals, observable contracts, native owner, disposition, evidence, license, and status;
- a dependency-island graph for the complete Training-level load and first acceptance-room result;
- the exact mission and level key, acceptance-room identity, selection reason, connected portal neighbors, and dependency capture for that room within the complete level;
- a register of temporary research tools or scaffolds with a deletion or archive gate.

Finish the functional-completeness audit without turning chosen architecture into fake historical capabilities. Author and review revival-constitution and revival-source-translation. Author each domain skill immediately before the first production change that needs it; later-domain skills do not block an unrelated island.

Exit: no active document requires fixed-cell streaming, fixed 120 Hz, exact target counts, a complete speculative behavior VM, or editor preview machinery before contact with real translated code. The complete Training Level and exact acceptance room are recorded, their initial source/dependency seed exists, and the two prerequisite skills agree with the amended documents. Exact symbols, transitive files, captures, and native owners may close alongside the working Phase 1 island, but must be complete before that island exits.

## Phase 1: one native room in editor and player

Create three executable products:

- D3Import;
- RevivalMac;
- RevivalEditor.

Keep `RevivalCore` and `RevivalMetal` as explicit code-ownership boundaries. Split either into a separate build target only when the first code makes that separation useful.

Implement one end-to-end source dependency island:

1. make the Swift 6.3 workspace and strict-concurrency builds green;
2. make a minimal AppKit player window and document-based editor window;
3. compile MSL and submit one direct Metal 4 forward pipeline through MTKView;
4. translate the HOG and D3L structures required to read the complete Training level world into D3Import;
5. emit one normal checked canonical Level containing all Training rooms, faces, portals, terrain, paths, goals, objects, and the assets reachable through the currently translated product path;
6. validate the level, construct its resident authoritative world, and prepare the source-evidenced eager working set; later reachable assets load directly from canonical content added with the behavior path that needs them and remain owned by the level;
7. render it through the translated room visibility path in RevivalMac and RevivalEditor;
8. derive an editable complete-level project value from the read-only imported base, select the acceptance room, a face, or an object, make one real edit with named undo and redo, save, close, and reopen;
9. create a disposable play-session copy and enter free-camera play through the same world, loader, simulation, and Metal code used by RevivalMac, then return to the document;
10. on replacement, validate successor CPU content first, then commit by stopping submissions, waiting for final GPU use, releasing the old presentation owner, and preparing the successor; expose a clear unloaded error if post-commit preparation fails;
11. release the world cleanly on shutdown.

The production package contains the complete Training level world. Phase 1 accepts only one selected room's rendering and editing, but it does not create a room-scope package, synthetic portal cut, partial `Level`, or migration path that Phase 2 must remove. Tiny one-room worlds are test fixtures only.

Use a tiny synthetic fixture for focused parser and renderer tests, but the phase exit uses the owned local Training data. Record red/green evidence, the source-file dispositions, a clean Metal validation run, and optimized M4 startup, memory, and shutdown measurements. Do not add world cells, stream blobs, a job system, fixed-tick simulation, or a zero-allocation mandate.

Exit: the first real imported room is visible in both native applications; the editor can change and persist something meaningful; editor preview and player use the same resident-world model, loading rules, and renderer with separate owned values; a working build can be launched repeatedly without the legacy runtime.

## Phase 2: connected world and real editor-to-play loop

Extend the same complete-level path across a small connected Training cluster:

- render and traverse connected room/portal topology with face materials, lightmaps, models, objects, and the player start already represented by the complete Level;
- translate the original load ordering, eager `PageInAllData` working set, and reachable later asset paging into canonical import evidence;
- add room/portal traversal, selection across connected rooms, and useful reference navigation;
- add direct transforms and property editing for the canonical room, face, portal, object, and start values now present;
- add validation for malformed topology, broken references, and incomplete dependencies;
- extend editing of the Phase 1 complete-level project across the connected cluster;
- save, reopen, and deterministically diff the native project;
- launch the cluster through the shipping simulation and renderer from the editor and return to the same document, selection, and useful camera state;
- add the first Blender-exported USD room import only if it helps this concrete cluster workflow.

Measure the released lightmap representation across the selected rooms before choosing a new atlas layout. Preserve the working imported representation until that evidence supports a simpler canonical form.

Exit: player and editor open the same connected cluster with no retail archive mounted. A creator can modify, validate, save, reopen, and play it without a temporary export or a second world path.

## Phase 3: flight, collision, terrain evidence, and timing decision

Translate:

- keyboard, mouse, and controller input mapping, ramps, simultaneous axes, mouselook, and autoleveling used by the selected path;
- Pyro position, orientation, linear and angular velocity, thrust, mass, drag, turn roll, afterburner, ship wiggle, and camera behavior;
- swept collision, wall slide, bounce, corner response, portal crossing, room ownership, and restart;
- any outdoor terrain representation, visibility, and LOD needed by the first chosen outdoor reference scene.

Pass the historical timing state explicitly through the translated order. Systems and `EVT_INTERVAL` receive the previous `Frametime` and pre-update `Gametime`; after cap waiting, `CalcFrameTime` stores the new duration, then `GameFrame` advances `Gametime` before the remaining tail work. Preserve the static/`InitGame` 0.1-second initialization and nested `StopTime`/`StartTime` rebasing. Capture scripted reference traces from the native C++ build for input, pose, velocity, collision contacts, portal ownership, interval events, animations, and this old/new time handoff. Compare native results with declared tolerances and explain each difference. Moving measurement to callback start is a modernization and must be recorded as such.

Then make one timing amendment before behavior breadth spreads:

- retain bounded variable delta and ratify its pause/cap/replay rules; or
- select one fixed tick, translate every current elapsed-time consumer, define catch-up/interpolation/input rules, and delete the variable scheduler.

Do not retain a compatibility mode. The timing decision is complete only when flight, collision, current animation, editor play, and current tests use one scheduler.

Editor work adds geometry and object transforms, numeric editing, snapping, structural validation, collision diagnostics, and play-in-editor return.

Exit: a player can fly the imported cluster with the intended feel, and a creator can change the spaces and immediately fly them. One measured timing model remains.

## Phase 4: first combat and behavior chain

Before implementation, author and review the behavior and volumetric-navigation skills from the actual translated Training dependencies.

Translate one complete source call chain for:

- one animated door;
- one trigger and its event order;
- one robot's AI state, room/portal or node route, steering, blockage, and recovery;
- one weapon, projectile, collision, damage, death, and effect path;
- one pickup;
- the difficulty rules, room role, sound, message, HUD, and cockpit behavior exercised by the slice;
- new native save and reload.

Account for the generated DALLAS block and every handwritten range used by the selected interaction. Implement only the behavior operations the chain needs as canonical direct typed Swift behavior. Before proposing a different authored representation or executor, the working evidence must cover at least one generated DALLAS chain, one handwritten or custom range, one timer or persistent-state chain, and one presentation-oriented chain; one chain may cover several categories. Change the direct runtime only when concrete human-authoring cases prove it inadequate. Do not load native code or cap the eventual creator system at stock operations.

The editor can place and configure the door, trigger, robot, weapon, pickup, sound, message, route, and current behavior state; validate them; play the full interaction; and navigate a runtime failure back to its source.

Exit: the selected Training combat slice is playable and can be reconstructed in a new native project without hand-editing generated files.

## Phase 5: complete Training and measure the architecture

Complete every runtime and creator dependency of the Training Mission:

- behaviors, goals, failure/restart, difficulty branches, room roles, AI, weapons, GuideBot, instructional presentation, selected stock fonts, cockpit, automap, markers, cinematics, audio, adaptive music, saves, and replay;
- matching campaign, behavior, path, navigation, presentation, score, localization, validation, playtest, and publishing operations;
- complete source-file and behavior-range dispositions for the mission.

Run the resident-level evidence gate in [World loading and residency](world-streaming.md) using complete Training, the largest imported indoor and outdoor levels then available, repeated editor/player transitions, and a representative higher-resolution replacement experiment.

If resident loading meets ratified startup, responsiveness, and memory budgets, ratify it for the following phases and stop speculative streaming work. A later representative workload may reopen the decision only by demonstrating a missed budget and following the amendment gate. If it misses a current budget, compare simpler encoding, duplicate-removal, and load-order fixes before proposing one narrow resource-lifetime amendment. No phase automatically creates a streamer.

Also establish the first credible optimized CPU, GPU, allocation, memory, import, load, and editor responsiveness budgets. Optimize only measured hot paths.

Exit: a new player can complete Training from canonical content, and a creator can inspect, change, validate, play, package, reinstall, and complete the native Training project. The resource-lifetime architecture has a recorded M4 decision.

## Phase 6: base campaign, level by level

Bring up level 1 end to end, then follow the campaign graph. Implement each secret when its entry becomes reachable. For every level:

1. close its source-file and import dependency accounting;
2. close its generated and handwritten behavior accounting;
3. add the next missing runtime contract through red, green, and refactor;
4. add the matching authoring, validation, playtest, and publishing operation;
5. play, save, replay, reload, and complete the level;
6. record intentional differences and keep the M4 budgets green.

This phase grows terrain and environment, reusable rooms, geometry tools, materials, mirrors, specular response, decals, procedural surfaces, volumetric lighting, blend semantics, robots, bosses, weapons, inventory, GuideBot, doors, triggers, paths, navigation, matcens, goals, ambient systems, weather, lighting, music, cinematics, briefings, movies, TelCom-style presentation, cockpit, automap, cameras, haptics, effects, campaign state, and approved command effects as real levels require them.

Exit: the complete base campaign and every stock secret pass player gates, and every introduced capability has its native creator path.

## Phase 7: Mercenary

Apply the same level-by-level process to Mercenary. Reuse verified native systems and add expansion-specific behavior, content, presentation, and editor work only where source and content require it.

Exit: Mercenary completes with no legacy runtime component and complete source accounting for the expansion track.

## Phase 8: complete campaign and content creation

Close every remaining non-multiplayer creator row:

- world and terrain construction, materials, lighting, navigation, reusable content, diagnostics, and repair;
- game definitions for ships, robots, weapons, doors, objects, physics, AI, effects, audio, cockpit, HUD, and haptics;
- behavior, campaign, adaptive-score, briefing, cinematic, localization, and presentation authoring;
- deterministic builds, dependency and orphan audits, recovery, templates, validation, play-in-editor, and publishing;
- an independently authored campaign beginning from an empty native project;
- task-based human workflow, keyboard, VoiceOver, undo, diagnostics, recovery, and M4 responsiveness review.

Add asynchronous snapshot/revision machinery only for operations that are now genuinely long-running, and keep it local to the smallest useful ownership boundary.

Exit: every non-multiplayer creator row passes and the independent campaign installs and completes in RevivalMac.

## Phase 9: multiplayer, replay, hosting, and multiplayer creation

Author and review networked-simulation, transport-security-operations, multiplayer, replay, and verification skills against the working final simulation model.

Add RevivalRelay and implement the selected native direction:

- Network-framework QUIC for direct Bonjour LAN and outbound public relay connections;
- host-authoritative simulation for 2–32 connected humans, including live observers;
- CryptoKit-protected authority/client records across relay legs;
- public discovery, registration, join authorization, bounded opaque relay, operations, and explicit outage behavior;
- dedicated no-window hosting through RevivalMac using RevivalCore;
- content and simulation agreement, prediction, reconciliation, interpolation, replay, desync evidence, chat, moderation, host commands, and safe custom media;
- the enumerated stock modes including campaign co-op;
- multiplayer map, mode, behavior, validation, test, and publishing tools;
- explicit adopt-or-exclude decisions for historical lobby chat, rankings, persistent pilot stats, and join-time package acquisition.

Detailed security and packet contracts are fixed immediately before their implementation and tested at the untrusted boundary. They do not create defensive branches inside trusted simulation code.

Exit: local and relay-backed matrices pass through 32 connected human slots; dedicated hosting and outage behavior are proven; a new multiplayer package can be authored, hosted, joined, completed, and replayed through native tools.

## Phase 10: complete revival release

- close every functional-completeness row or record a user-approved scope amendment;
- close every relevant source file and behavior range with a final disposition;
- delete or archive every temporary research harness, adapter, and reference-only build artifact from product paths;
- finalize import, project, package, save, replay, multiplayer, and diagnostic UX;
- verify compatible and incompatible public data revisions and add only the migrations real released formats require;
- complete settings, accessibility, controller, display, audio, movie, long-session, and clean-account matrices;
- sign, notarize, staple, and Gatekeeper-test the player, editor, and bundled importer;
- run complete campaign, independent campaign, creator, multiplayer, replay, memory, and performance matrices.

The released C++ tree may leave the active checkout only after no ledger row, source disposition, or unresolved product question depends on it. Repository history, pinned upstream identity, provenance, and hashes remain evidence.

Exit: signed and notarized native macOS player and editor applications deliver the complete revival with no legacy source or executable in a product path.

## Phase 11: visual and experiential development

Improve the stable product with higher-resolution art, models, animation, lighting, materials, effects, spatial audio, replacement music, interface work, accessibility, campaigns, multiplayer content, and creator workflows where rights permit.

Each engine change begins from a measured limitation in the completed product, chooses one design, and deletes the superseded path. MetalFX, spatial streaming, sparse resources, a different terrain strategy, or another DCC ingress are possible amendments; none is preinstalled as a framework or permanent alternate.

Only after Phase 10 certifies the complete human creator suite may a later amendment design MCP or agent authoring. It must reuse the mature human operations and may not create a second document, validation, playtest, or publishing model.

## Outside the current platform boundary

Intel Mac, iOS, visionOS, Windows, Linux, consoles, and web are outside the roadmap. Adding one requires an explicit product amendment. Current code carries no portability layer for a hypothetical target.

## Immediate next step

Finish this documentation amendment and its independent reviews. Then record the exact Training Level and acceptance room, complete that level-load/render dependency trace while building it, author the constitution/source-translation prerequisites plus each just-in-time domain skill, and ship the first resident editor/player slice.
