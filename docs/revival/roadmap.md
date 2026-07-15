# Roadmap

- Status: accepted, amended
- Date: July 15, 2026
- Authority: concrete execution sequence; cannot reduce product scope

Every phase ends in a runnable, visible, or objectively verified product result. Campaign-first development orders the work; it does not reduce the [functional-completeness contract](functional-completeness.md).

The phases are broad dependency groupings, not promises that every listed capability lands in one monolithic change. Phase 10 is the complete version 1.0 release. Phase 11 is post-1.0 visual and experiential development.

The player and editor advance together from the first canonical world. A phase does not need the complete creator suite, but every new canonical type and runtime behavior gains the authoring, validation, playtest, and publishing path that is applicable at that maturity.

Production work follows [Test-driven development](test-driven-development.md). Bounded disposable research may answer an unknown source question before a production contract is stated; it is never shipped or retained as a second path.

## Phase 0: reconcile the product and map the source

Status: in progress

Amend the active documents so they agree on:

- Apple Silicon player targets on macOS 26+, iOS 26+ and iPadOS 26+, initially limited to Metal 4 devices in Apple GPU family 7 or later; macOS-only editor, importer and dedicated host; the Swift 6.4 compiler toolchain in Swift 6 language mode, MSL and direct Metal 4, using Xcode 27 beta until stable Xcode 27 replaces it;
- dependency-ordered semantic translation of the pinned source;
- no shipping legacy engine, ABI, renderer, platform layer, or native module;
- complete functional scope and one-way retail conversion;
- one complete resident level world with source-faithful eager and lazy asset paging as the first loading implementation;
- the explicit source-faithful old/new variable-time handoff as the first scheduler;
- one shared Mac player, mobile player and editor world model, renderer, level I/O and play path from Phase 1, with separately owned worlds, document and play-session values behind concrete AppKit and UIKit shells;
- evidence-driven modernization with one surviving production path.

Before Phase 1 production code, install the current Xcode 27 beta, select it for the workspace, and record `xcodebuild -version`, `swift --version`, the macOS and iOS SDKs, the macOS deployment target, and the universal mobile target's iOS/iPadOS deployment floor. Select and record the exact minimum-reference iPhone and iPad models that satisfy the initial Metal 4 hardware floor. Replace the beta with stable Xcode 27 when released and remove any beta-only workaround; do not preserve Xcode 26 or Swift 6.3 as a compatibility lane.

Current gate state on July 15, 2026: the canonical Training keys, full-level reference counts, source room 3 acceptance choice, connected portals, eager dependency baseline, and exact iPhone 12 mini and iPad Air (4th generation) minimum-device contracts are recorded. Phase 0 remains in progress because this machine still has Xcode 26.6 and Swift 6.3.3 and neither exact minimum device is attached for physical proof. Phase 1 product scaffolding has therefore not begun; the later paired iPhone's developer-image failure is non-gating audit context.

Seed and then expand the checked-in source-translation ledger with:

- the runtime and editor files required for initialization, HOG and level loading, rooms, portals, terrain, objects, dependency paging, rendering, and editor-hosted play;
- each file's responsibility, callers, globals, observable contracts, native owner, disposition, evidence, license, and status;
- a dependency-island graph for the complete Training-level load and first acceptance-room result;
- the exact mission and level key, acceptance-room identity, selection reason, connected portal neighbors, and dependency capture for that room within the complete level;
- a register of temporary research tools or scaffolds with a deletion or archive gate.

Finish the functional-completeness audit without turning chosen architecture into fake historical capabilities. Split application/session, pause, save workflow, profile/settings, audio environment, advanced weapon and inventory families, TelCom, rendering composition, runtime attachments, creator definitions, package intake, font authoring, host configuration and operational diagnostics wherever their state or failure can vary independently. Preserve incomplete subtitle, briefing, pickup, room-metadata and HUD ideas without promoting them into version 1.0. `revival-constitution` and `revival-source-translation` are authored and reviewed against the accepted documents. The full current skill set is installed; review and amend each applicable domain skill against real translated source immediately before its first production change. A later-domain review does not block an unrelated island.

Begin the bounded 2026 [Internet multiplayer study](internet-multiplayer-study.md) in parallel. Its named comparison record covers direct, player-hosted, community-operated, platform-provided, and third-party-supported approaches using current reachability, security, privacy, abuse, continuity, deployment, and recurring-cost evidence. The required outcome is affordable native Internet multiplayer, not a preselected project-operated relay. The study names an evidence owner, sources, assumptions, rejection reasons, operating owner and cost, and the decision criteria for `N-014`, `N-016`, `N-018`, and `N-019`. It does not add production networking types or block unrelated Phase 1 work, but an accepted decision record is mandatory before Phase 9 production transport work.

Exit: no active document requires fixed-cell streaming, fixed 120 Hz, exact target counts, a complete speculative behavior VM, generic platform machinery, or editor preview machinery before contact with real translated code. The complete Training Level and exact acceptance room, deployment floors and minimum-reference mobile devices are recorded, their initial source/dependency seed exists, and the two prerequisite skills agree with the amended documents. Exact symbols, transitive files, captures, and native owners may close alongside the working Phase 1 island, but must be complete before that island exits. The lawful mobile distribution direction need not block Phase 1, but it must be selected before public beta and close through `P-094` before release.

## Phase 1: complete Training Level with selected-room acceptance

Create four executable products:

- D3Import;
- RevivalMac;
- RevivalMobile, as one universal iPhone and iPad player;
- RevivalEditor.

Keep `RevivalCore` and `RevivalMetal` as explicit code-ownership boundaries. Split either into a separate build target only when the first code makes that separation useful.

Implement one end-to-end source dependency island:

1. make the workspace green with the Swift 6.4 compiler toolchain in Swift 6 language mode and strict concurrency, using Xcode 27 beta until the stable release replaces it without a Swift 6.3 compatibility mode;
2. make minimal concrete AppKit player and document-based editor shells plus a concrete UIKit scene for the landscape-first universal mobile player;
3. compile MSL and submit one direct Metal 4 forward pipeline through MTKView from all three applications, without a renderer or platform interface;
4. translate the HOG and D3L structures required to read the complete Training level world into D3Import;
5. emit one normal checked canonical Level containing all Training rooms, faces, portals, terrain, paths, goals, objects, and the assets reachable through the currently translated product path;
6. validate the level, construct its resident authoritative world, and prepare the source-evidenced eager working set; later reachable assets load directly from canonical content added with the translated product path that needs them and remain owned by the level;
7. render it through the translated room visibility path in RevivalMac, RevivalMobile and RevivalEditor; prove mobile drawable resize, supported orientation and safe-area composition without changing renderer ownership;
8. derive an editable complete-level project value from the read-only imported base, then use the traced historical editor/runtime workflow to choose the smallest real canonical edit that proves stable ownership without a disposable path; select it, perform it with named undo and redo, save, close, and reopen;
9. create a disposable play-session copy and enter free-camera play through the same world types, loader, simulation, and Metal code used by both player applications, then return to the document;
10. on replacement, validate successor CPU content first, then commit by stopping submissions, waiting for final GPU use, releasing the old presentation owner, and preparing the successor; expose a clear unloaded error if post-commit preparation fails;
11. let RevivalMobile receive the Mac-produced canonical package through the system document picker, copy it into app-owned staging and run the first shared validation, promotion and activation slice without reading retail data; exclude the reimportable package from backup while keeping saves and profiles under their separate durable policy;
12. map UIKit inactive/background/foreground transitions into the same explicit unloaded or paused ownership rules; release each world during delivered orderly teardown, and prove that abrupt process death needs no cleanup callback because relaunch removes abandoned staging and recovers the prior durable state.

The production package contains the complete Training level world. Phase 1 accepts only one selected room's rendering and editing, but it does not create a room-scope package, synthetic portal cut, partial `Level`, or migration path that Phase 2 must remove. Tiny one-room worlds are test fixtures only.

Use a tiny synthetic fixture for focused parser and renderer tests, but the phase exit uses the owned local Training data. Bring every source row reached by the result to the terminal state required by the source-translation ledger, then record red/green evidence, clean Metal validation, and optimized startup, memory, shutdown and lifecycle measurements on the recorded M4 Mac and physical minimum-reference iPhone and iPad. Simulator launch is not device-performance proof. Do not add world cells, stream blobs, a job system, fixed-tick simulation, a mobile-only residency path or a zero-allocation mandate.

Exit: the first real imported room is visible in RevivalMac, RevivalMobile and RevivalEditor; the editor can change and persist something meaningful; editor preview and both players use the same resident-world model, loading rules and renderer with separate owned values; the mobile package handoff and lifecycle cycle pass on the recorded physical devices; working builds launch repeatedly without the legacy runtime.

## Phase 2: connected-room acceptance in the complete Level

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

Exit: both player applications and the editor open the complete Training `Level` with no retail archive mounted and render, traverse, edit, and play the same selected connected cluster. A creator can modify, validate, save, reopen, and play that cluster without a temporary export or a second world path.

## Phase 3: flight, collision, terrain evidence, and timing decision

Translate:

- keyboard, mouse and physical-controller input mapping plus `GCVirtualController` as the initial mobile touch-gameplay mechanism, all delivered through the same explicit input snapshot; ordinary UIKit touch remains interface input, and the selected path preserves ramps, simultaneous axes, mouselook and autoleveling;
- Pyro position, orientation, linear and angular velocity, thrust, mass, drag, turn roll, afterburner, ship wiggle, and camera behavior;
- swept collision, wall slide, bounce, corner response, portal crossing, room ownership, and restart;
- any outdoor terrain representation, visibility, and LOD needed by the first chosen outdoor reference scene.

Pass the historical timing state explicitly through the translated order. Systems and `EVT_INTERVAL` receive the previous `Frametime` and pre-update `Gametime`; after cap waiting, `CalcFrameTime` stores the new duration, then `GameFrame` advances `Gametime` before the remaining tail work. Preserve the static/`InitGame` 0.1-second initialization and nested `StopTime`/`StartTime` rebasing. Capture scripted reference traces from the native C++ build for input, pose, velocity, collision contacts, portal ownership, interval events, animations, and this old/new time handoff. Compare native results with declared tolerances and explain each difference. Moving measurement to callback start is a modernization and must be recorded as such.

Then make one timing amendment before behavior breadth spreads:

- retain bounded variable delta and ratify its pause/cap/replay rules; or
- select one fixed tick, translate every current elapsed-time consumer, define catch-up/interpolation/input rules, and delete the variable scheduler.

Do not retain a compatibility mode. The timing decision is complete only when flight, collision, current animation, editor play, and current tests use one scheduler.

Editor work adds geometry and object transforms, numeric editing, snapping, structural validation, collision diagnostics, and play-in-editor return.

Exit: a player can fly the imported cluster with the intended feel on Mac, iPhone and iPad using each applicable input surface, and a creator can change the spaces and immediately fly them. One measured timing model remains.

## Phase 4: first combat and behavior chain

Before implementation, review and amend the installed behavior and volumetric-navigation skills from the actual translated Training dependencies.

Translate one complete source call chain for:

- one animated door;
- one trigger and its event order;
- one robot's AI state, room/portal or node route, steering, blockage, and recovery;
- one weapon, projectile, collision, damage, death, and effect path;
- one pickup;
- the difficulty rules, room role, any source-traced environmental hazard reached by the slice, the Training-required headlight, sound, message, HUD, and cockpit behavior exercised by the slice;
- new native save and reload.

Account for the generated DALLAS block and every handwritten range used by the selected interaction. Implement only the behavior operations the chain needs as canonical direct typed Swift behavior. Before selecting the reusable version 1.0 authored representation or replacing the direct executor, the working evidence must cover at least one generated DALLAS chain, one handwritten or custom range, one timer or persistent-state chain, and one presentation-oriented chain; one chain may cover several categories. Version 1.0 must let people compose the evidenced behavior and creator capability of the shipped game and tools without Swift or generated-file editing. Evidence selects the representation and one runtime path; broader mechanics remain a later decision. Never load native code.

The editor can place and configure the door, trigger, robot, weapon, pickup, sound, message, route, and current behavior state; validate them; play the full interaction; and navigate a runtime failure back to its source.

Exit: the selected Training combat slice is playable and can be reconstructed in a new native project without hand-editing generated files.

## Phase 5: complete the playable Training Mission and measure the architecture

After the Phase 3 timing decision and before replay production work, review and amend the installed replay skill against the selected scheduler and working save/simulation model.

Complete every runtime and creator dependency of the Training Mission:

- behaviors, goals, failure/restart, difficulty branches, room roles, any Training-reached hazards established by the source trace, headlight, AI, Training-reached ordinary and advanced weapon and pickup-effect families, Training-reached Seeker, Betty, Chaff, Gunboy and Proximity Mine countermeasures, GuideBot, instructional presentation, selected stock fonts, cockpit, automap, markers, cinematics, independently ledgered audio environments, adaptive music, save-state and player save-slot workflows, replay and authoritative-randomness evidence;
- matching campaign, behavior-message, path, navigation, presentation, score, localization-matrix, validation, playtest, publishing, native-package intake and activation operations;
- complete source-file and behavior-range dispositions for the mission.

Run the resident-level evidence gate in [World loading and residency](world-loading.md) on the recorded M4 Mac and physical minimum-reference iPhone and iPad, using the complete playable Training Mission, the largest imported indoor and outdoor levels then available, repeated editor/player and mobile lifecycle transitions, and a representative higher-resolution replacement experiment.

If resident loading meets ratified startup, responsiveness, and memory budgets, ratify it for the following phases and stop speculative streaming work. A later representative workload may reopen the decision only by demonstrating a missed budget and following the amendment gate. If it misses a current budget, compare simpler encoding, duplicate-removal, and load-order fixes before proposing one narrow resource-lifetime amendment. No phase automatically creates a streamer.

Also establish the first credible optimized CPU, GPU, allocation, memory, import, load, and editor responsiveness budgets. Optimize only measured hot paths.

Exit: a new player can complete Training from canonical content on Mac, iPhone and iPad, and a creator can inspect, change, validate, play, package, reinstall in both players, and complete the native Training project. The resource-lifetime architecture has a recorded cross-device decision.

## Phase 6: base campaign, level by level

Bring up level 1 end to end, then follow the campaign graph. Implement each secret when its entry becomes reachable. For every level:

1. close its source-file and import dependency accounting;
2. close its generated and handwritten behavior accounting;
3. add the next missing runtime contract through red, green, and refactor;
4. add the matching authoring, validation, playtest, and publishing operation;
5. play, save, replay, reload, and complete the level;
6. record intentional differences and keep the applicable Mac and mobile-device budgets green.

This phase grows terrain and environment, reusable rooms, geometry tools, materials, mirrors, specular response, decals, procedural surfaces, volumetric lighting, blend semantics, robots, bosses, weapons including player-triggered timeout/detonation, inventory and pickup families including the afterburner cooler and timed RapidFire effect, GuideBot, doors, triggers, paths, navigation, matcens, goals, ambient sound systems and patterns, weather, lighting, music, cinematics, briefings, movies, TelCom-style presentation, cockpit, automap, cameras, haptics, effects, campaign state, and approved command effects as real levels require them.

Exit: the complete base campaign and every stock secret pass player gates, and every introduced capability has its native creator path.

## Phase 7: Mercenary

Apply the same level-by-level process to Mercenary. Reuse verified native systems and add expansion-specific behavior, content, presentation, and editor work only where source and content require it.

Exit: Mercenary completes with no legacy runtime component and complete source accounting for the expansion track.

## Phase 8: complete campaign and content creation

Close every remaining non-multiplayer creator row:

- world and terrain construction, materials, lighting, navigation, reusable content, diagnostics, and repair;
- game definitions for ships, robots, ordinary and advanced weapons, powerups, countermeasures, doors, lights, buildings, clutter, physics, animation, death, effects, sound, ambient patterns, room reverb, terrain ambience, cockpit, HUD, and source-supported haptic parameters;
- behavior including inventory add/remove/use and item-lifecycle operations, localized message catalogs, campaign and goal rules, adaptive-score, briefing, TelCom, cinematic, modern-font, localization, and presentation authoring;
- deterministic builds, dependency and orphan audits, recovery, templates, validation, play-in-editor, and publishing;
- a non-bundled independently authored certification campaign beginning from an empty native project;
- task-based human editor workflow, keyboard, VoiceOver, undo, diagnostics, recovery and M4 responsiveness review, plus installation and completion proof for the published package in both player applications.

Add asynchronous snapshot/revision machinery only for operations that are now genuinely long-running, and keep it local to the smallest useful ownership boundary.

Exit: every non-multiplayer creator row passes and the non-bundled certification campaign installs and completes in RevivalMac and RevivalMobile. This proves the creator suite; it does not supply replacement retail content or remove the version 1.0 ownership requirement.

## Phase 9: multiplayer, replay, hosting, and multiplayer creation

Review and amend the installed networked-simulation, transport-security-operations, multiplayer, and replay skills against the working final simulation model. Use the installed verification skill to falsify the declared Phase 9 evidence claims and matrices; it does not define a second test architecture.

Ratify and implement one affordable native direction from the Phase 0 Internet-multiplayer study against the final simulation and current Apple APIs:

- direct Network/Bonjour LAN hosting and discovery;
- iOS and iPadOS local-network declarations, permission denial and recovery, and explicit background/suspension limits for mobile listen hosts and clients;
- host-authoritative simulation with the released 32 network/player-slot infrastructure and historical listen/dedicated slot accounting, each stock mode's source-supported player limit, and live observers;
- the transport, trust, record-protection, reachability, discovery, join, privacy, abuse, deployment, recurring-cost, and outage contracts required by the selected Internet topology;
- no mandatory project-operated service; add a rendezvous, relay, service executable, or external integration only when the accepted topology requires it and has a viable operator;
- interactive listen hosting and joining through both player applications, plus dedicated no-window hosting only through RevivalMac using RevivalCore;
- content and simulation agreement, prediction, reconciliation, interpolation, replay, desync evidence, chat, moderation, host commands, interactive and dedicated host presets, and safe custom media with modern local ingress and preview;
- the enumerated stock modes including campaign co-op;
- multiplayer map, mode, behavior, validation, test, and publishing tools;
- evidence-backed decisions for the modern counterparts of historical lobby chat, rankings, persistent pilot stats, and join-time package acquisition, preserving unselected ideas for later rather than silently losing them.

Detailed security and packet contracts are fixed immediately before their implementation and tested at the untrusted boundary. They do not create defensive branches inside trusted simulation code.

Exit: local, LAN, and selected-Internet-topology matrices pass at the source-supported count for each stock mode, the 32-slot infrastructure proof passes, four-player campaign co-op passes, dedicated hosting and outage behavior are proven, and a new multiplayer package can be authored, hosted, joined, completed, and replayed through native tools.

## Phase 10: version 1.0 complete revival release

- close every functional-completeness row or record a user-approved scope amendment;
- bring every relevant source file and behavior range to `verified`, `replaced`, or `excluded` with the evidence required by its disposition; no `seed`, `traced`, `translating`, `native-running`, or `deferred` row survives complete-revival closure;
- delete or archive every temporary research harness, adapter, and reference-only build artifact from product paths;
- finalize import, project, package publishing, local package-library intake/activation/removal, player save-slot/quicksave, replay, multiplayer, application-session, pause/resume, and privacy-bounded diagnostic UX;
- verify compatible and incompatible public data revisions and add only the migrations real released formats require;
- complete settings, source-supported player-accessibility and localization, controller, display, audio, movie, long-session, native-editor accessibility, and clean-account matrices, plus every deliberate improvement accepted during the preceding slices;
- sign, notarize, staple and Gatekeeper-test RevivalMac, RevivalEditor and the bundled importer;
- sign RevivalMobile and prove clean-device install, update preservation, entitlements, privacy declarations, GPL/source delivery and acceptance through the selected lawful distribution channel without bundling retail content; verify that channel's enabled device/platform availability, and if the App Store is selected, disable unapproved visionOS availability and iPhone/iPad-app execution on Apple Silicon Macs;
- run complete campaign, non-bundled certification campaign, creator, multiplayer, replay, lifecycle, memory, thermal and performance matrices on the applicable Mac, iPhone and iPad devices.

The released C++ tree may leave the active checkout only after no ledger row, source disposition, or unresolved product question depends on it. Repository history, pinned upstream identity, provenance, and hashes remain evidence.

Exit: signed and notarized native macOS player and editor applications plus the signed universal iPhone/iPad player deliver the complete revival through their selected channels with no legacy source or executable in a product path.

## Phase 11: post-1.0 visual and experiential development

Improve the stable product with higher-resolution art, models, animation, lighting, materials, effects, spatial audio, replacement music, interface work, accessibility, campaigns, multiplayer content, and creator workflows where rights permit.

Each engine change begins from a measured limitation in the completed product, chooses one design, and deletes the superseded path. MetalFX, spatial streaming, sparse resources, a different terrain strategy, or another DCC ingress are possible amendments; none is preinstalled as a framework or permanent alternate.

Only after Phase 10 certifies the complete human creator suite may a later amendment design MCP or agent authoring. It must reuse the mature human operations and may not create a second document, validation, playtest, or publishing model.

## Outside the current platform boundary

Intel Mac, visionOS, Windows, Linux, consoles and web are outside the roadmap. RevivalEditor, D3Import and dedicated hosting on iPhone or iPad are also outside the current boundary. Adding one requires an explicit product amendment. Current code carries no portability layer for a hypothetical target.

## Immediate next step

Install and select the current Xcode 27 beta, record the Swift 6.4 compiler and SDK environment, and attach the recorded iPhone 12 mini and iPad Air (4th generation) so their physical baseline can be captured. Then start the first red test for the HOG2 import boundary and create the Xcode 27-native D3Import, RevivalMac, RevivalMobile, and RevivalEditor products around the recorded complete Training/source-room-3 island. Expand the level-load and renderer trace only as that working island reaches each dependency. In parallel, begin the bounded 2026 Internet-multiplayer study without blocking the slice or adding production transport machinery. Review and amend each installed domain skill against the real source immediately before its first production change.
