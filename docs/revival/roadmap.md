# Roadmap

- Status: accepted
- Date: July 13, 2026
- Authority: execution sequence; cannot redefine architecture or product scope

Every phase ends in a visible or objectively verifiable result. Campaign-first development orders the work; it does not reduce the [functional-completeness contract](functional-completeness.md).

Starting in Phase 2, every gameplay slice advances the matching authoring track. A feature is finished only when its applicable runtime, editor, validation, playtest, and publishing paths work.

## Phase 0: lock the complete product definition

Status: in progress

- accept the Swift 6.3 and direct Metal 4 architecture;
- define one-way retail import, canonical projects and packages, new saves and replay, the behavior system, creator suite, multiplayer commitment, verification, and minimal-code rules;
- define the pinned community source as the stock behavior baseline, the historical interval-to-fixed-tick translation rule, authoritative Float32 semantics, and one `simulationSemanticRevision` policy;
- complete the working functional-completeness ledger with one row for every required runtime, editor, behavior, campaign, multiplayer, replay, presentation, data-editing, baking, packaging, and mod-SDK capability;
- inventory adaptive music, automap, animated cockpit, haptics, player markers, auxiliary camera views, player-selected multiplayer media, mirrors, specular response, scorch decals, procedural textures, volumetrics, and blend semantics as explicit capabilities rather than umbrella terms;
- record for each row its historical evidence, native counterpart, milestone, owner, acceptance evidence, and current state;
- separate intended capabilities from dead menu shells, duplicated dialogs, and historical bugs;
- preserve verified retail hashes and the legacy M4 smoke run as non-normative evidence;
- audit active documents for stale compatibility requirements and hidden scope deletion;
- author and review `revival-constitution`, `revival-verification`, `swift-realtime-systems`, and `metal4-rendering`.

Exit: every active document describes the same complete product, the ledger covers the known historical capability surface, the four Phase 1 skills are installed and pinned, and no production code has begun under conflicting instructions.

## Phase 1: create the smallest native shell

Create four targets:

- `D3Import`;
- `RevivalCore`;
- `RevivalMetal`;
- `RevivalMac`.

Prove the foundations needed by the next slice:

- Swift 6.3 strict-concurrency build;
- AppKit application with `MTKView`;
- direct Metal 4 command submission and one MSL pipeline;
- explicit Xcode build and copy dependency that places `D3Import` in `RevivalMac.app/Contents/Helpers` for nested-code signing;
- fixed 120 Hz accumulator with monotonic time, eight-tick catch-up ceiling, lifecycle reset, drop accounting, and deterministic tests;
- canonical Float32 boundary, normalization, encoding, and hash tests for the initial simulation semantic revision;
- one keyboard, mouse, and controller input snapshot;
- held-state and exactly-once input-impulse tests across zero, one, and multiple ticks per display callback;
- one AVAudioEngine sound;
- clean shutdown, native file locations, release-build logging, and signposts.

Exit: a native player application displays a controlled Metal scene, advances a tested fixed-step world, accepts input, and plays sound. No legacy file is involved.

## Phase 2: canonical room cluster and editor foundation

Before this phase, author and review `d3-content-import` and `revival-creator-suite`.

Select a small connected cluster from the Training Mission. Implement its dependency closure:

- recognized prepared-installation-directory 1.4-plus-Mercenary source profile;
- minimal HOG and level decoding inside `D3Import`;
- canonical room, portal, face, UV, texture, lightmap, model, object, and player-start values;
- atomic base-package output and native package loading;
- lightmapped opaque rendering and portal traversal through `RevivalMetal`.

Add `RevivalEditor` as the fifth production target. It provides:

- a canonical content inspector;
- a read-only level hierarchy and Metal viewport;
- selection, property inspection, reference navigation, and diagnostics;
- source-project creation, save, close, and reopen for the canonical types already present.

Exit: the player and editor open the same canonical package with no retail archive mounted. Both render the selected rooms and objects through the shared Metal renderer.

## Phase 3: flight, collision, and first world editing

Add runtime support for:

- Pyro position, orientation, velocity, thrust, drag, and camera;
- keyboard, mouse, and controller six-degree-of-freedom mappings;
- swept movement against room faces;
- portal crossing and room ownership;
- restart, pause, and render interpolation.

Add editor support for:

- deriving an imported canonical document into an editable project replacement without changing the base package;
- creating and changing rooms, vertices, faces, portals, materials, UVs, objects, and player starts needed by the slice;
- transforms, snapping, duplication, naming, undo, redo, and structural validation;
- play-in-editor with return to the same selection and document state.

Exit: the player can fly through the imported cluster, and a creator can modify that cluster or build a small new connected room set, validate it, save it, reopen it, and fly it through the shipping simulation.

## Phase 4: first playable combat and behavior slice

Before this phase, author and review `revival-behavior-system`.

Add runtime support for:

- one animated door;
- one trigger and the first `BehaviorProgram` executor;
- one robot with a small explicit state machine;
- one weapon, projectile, collision, damage, and death path;
- one pickup;
- animated cockpit, HUD, instructional messaging, positional sound, and the narrow ACM import decoder if required;
- new-format save and reload.

Add editor support for:

- placing and configuring the door, trigger, robot, weapon, pickup, HUD message, and sound source;
- the first typed `BehaviorGraph` event, conditions, queries, commands, variables, timer, compiler diagnostics, trace, and breakpoint;
- validation and play-in-editor for the complete combat interaction.

Exit: the Training combat slice passes every Phase 4 item in `verification.md`. A creator can rebuild the interaction in a new project without hand-editing generated files. Record the first Instruments and Metal baseline profiles.

## Phase 5: complete Training Mission

Before this phase, author and review `revival-replay`.

Expand import, renderer, simulation, AI, weapons, behaviors, messages, audio, adaptive music, cockpit, automap, markers, required rear or GuideBot views, and content to complete Training. Add the narrow OMF importer and canonical adaptive-score conversion when its first stock theme is required. Add the narrow MVE importer and AVFoundation transcode here if Training requires it; otherwise add it with the first level that does.

Complete the matching authoring surfaces for Training:

- goals, paths, GuideBot configuration, failure and restart rules, and mission transition;
- behavior functions, subgraphs, persistent state, debugging, and operation-limit evidence;
- Training campaign metadata, briefing, instructional presentation, adaptive-score regions and transitions, audio, and localization;
- dependency closure, package publishing, install, and replay of the completed mission.

Establish numeric performance budgets from this finished workload.

Exit: a new player can start and complete Training using canonical content. A creator can inspect, change, validate, play, package, reinstall, and complete the native Training project through the integrated tools.

## Phase 6: base campaign and matching authoring coverage

Bring up level 1 end to end, then proceed through the campaign graph. Implement each secret branch when its entry first becomes reachable. For every level:

1. close the import dependency graph;
2. complete its behavior translation ledger;
3. add the smallest missing runtime capability;
4. add the matching creator operation, inspector, validation, and playtest path;
5. play, save, replay, reload, and complete the level;
6. keep performance and regression evidence green.

This phase adds outdoor terrain, reusable rooms, broader geometry tools, materials, mirrors, specular response, scorch decals, procedural textures, volumetrics, required blend semantics, more robots and AI, weapons, inventory, GuideBot, doors, triggers, paths, navigation, matcens, goals, ambient systems, weather, lighting, adaptive music, briefings, movies, TelCom-style presentation, complete cockpit and automap behavior, remaining rear and auxiliary views including guided-weapon and marker cameras, broader native haptics, effects, bosses, campaign state, and their required game-data editors as content reaches them.

Exit: the complete base campaign and every stock secret level pass their player gates. Every runtime capability introduced by the base campaign can be authored and tested in `RevivalEditor`.

## Phase 7: Mercenary and expansion authoring coverage

Apply the same level-by-level process to Mercenary. Reuse base systems and add expansion-specific runtime, behavior, content, and editor capabilities only where its evidence requires them.

Exit: Mercenary can be played through its ending with no legacy runtime component. All expansion-specific features have matching native authoring, validation, and playtest paths.

The old source remains available because editor, multiplayer, replay, and utility capabilities are not yet implemented and verified and may still require historical answers. Campaign completion alone does not trigger its retirement.

## Phase 8: complete campaign and content creation

Close every remaining non-multiplayer creator row through five execution work packages. They may overlap, but each closes named ledger rows with editor save, reopen, validation, playtest, and publishing evidence. They are groupings inside the existing `RevivalEditor`, not new targets or a second workspace architecture.

### 8A. World construction closure

Complete indoor geometry operations, outdoor terrain, reusable-room workflows, native geometry import, UVs, materials, mirrors, specular response, declared blend semantics, procedural surfaces, water, fog, volumetrics, scorch behavior, sky and environment, animated lighting, diagnostic views, viewport bookmarks, and complete object placement.

### 8B. Game definitions and player presentation closure

Complete robots, powerups, buildings, clutter, ships, weapons, doors, lights, sounds, ambient patterns, physics, animation, AI, death, inventory, effects, archetype definitions, adaptive-score authoring, cockpit and HUD definitions, automap metadata, auxiliary-view layouts, marker presentation, haptic bindings, and non-multiplayer media.

### 8C. Behavior, campaign, and presentation closure

Complete typed behavior authoring, functions, subgraphs, scopes, debugging, tests, documentation, campaign graphs, secrets and returns, ship-selection rules, progress presentation, adaptive-score assignments, briefings, TelCom-style screens, cinematics, messages, fonts, localization, media import, and preview.

### 8D. Build and iteration closure

Complete lighting and navigation baking, validation and repair, statistics, dependency and orphan audits, autosave and crash recovery, project templates, semantic-revision comparison and release-blocking diagnostics, package publishing, play-in-editor, and the campaign and content portion of the native mod SDK using the same projects, behaviors, packages, validation, and publisher as first-party content.

### 8E. Independent campaign certification

Build an independently authored campaign that starts from an empty project and uses indoor and outdoor spaces, custom content definitions, behavior, presentation, saves, and replay. Do not use hand-edited generated data or legacy tools.

These work packages do not include the Phase 9 multiplayer authoring closure and do not weaken the Phase 8 exit gate.

Exit: every non-multiplayer creator row in the [functional-completeness ledger](functional-completeness-ledger.md) passes, every applicable imported campaign capability has an authoring counterpart, and the independent campaign installs and completes in `RevivalMac`. The full creator-completeness gate remains open until Phase 9 adds multiplayer maps and modes.

## Phase 9: native multiplayer, dedicated hosting, and multiplayer creation

The feature commitment is fixed; the precise transport and session design is selected here from current Apple networking APIs, security requirements, and deterministic-core measurements. It does not inherit the original packets, reliability layer, native game modules, or server ABI.

Implement and verify:

- import and canonicalize the stock multiplayer maps and their required retail dependency closures;
- authoritative session ownership and state replication appropriate to the selected game modes;
- joining, leaving, discovery or direct connection as selected, version and content negotiation, failure recovery, and abuse-resistant input validation;
- exact `simulationSemanticRevision` agreement and content-revision negotiation before authoritative participation;
- secure player pictures, ship logos, and audio taunts with hash identity, format and decoded-data bounds, transfer and cooldown limits, app-controlled storage, malformed and active-payload rejection, mute and disable controls, consent where required, and host policy;
- no-window dedicated hosting through the `RevivalMac` executable, using the same `RevivalCore` simulation and network ownership as graphical sessions;
- the original functional game-mode set or explicit modern counterparts recorded in the completeness ledger;
- deterministic recording, replay, diagnosis, and desync evidence for authoritative session state, plus explicitly declared observer, client, transport, and presentation evidence without a second replay engine;
- multiplayer maps, starts, teams, mode rules, session behaviors, validation, local multi-instance testing, package dependencies, and publishing in `RevivalEditor`;
- multiplayer mod-SDK documentation and synthetic examples, completing the native SDK.

Exit: supported modes complete repeatable local and network test matrices, dedicated hosting passes its lifecycle tests, replay reproduces declared session evidence, and a newly authored multiplayer package can be created, validated, hosted, joined, completed, and replayed using only native tools. The complete creator-suite gate now passes.

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

MetalFX or other advanced Metal techniques require a visible benefit or measured need. Visual work does not introduce an OpenGL reference mode or legacy asset-editing path.

## Outside the current platform boundary

Intel Mac, iOS, visionOS, Windows, Linux, consoles, and web targets are outside the current roadmap. Adding one requires an explicit architecture amendment. No current code carries portability layers for a hypothetical second platform.

## Immediate next step

Finish the documentation consistency audit. Then complete the functional-completeness ledger and author and review the four Phase 1 project skills. Production code begins only after those gates pass.
