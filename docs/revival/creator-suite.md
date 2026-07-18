# Native creator suite

- Status: accepted, amended
- Date: July 18, 2026
- Authority: binding creator-product contract

## Decision

Build one integrated macOS application, RevivalEditor, for the complete creation workflow. It shares canonical world values, level I/O, simulation and Metal rendering with RevivalMac and RevivalMobile. The editor remains Mac-only in version 1.0.

The editor translates useful D3Edit, game-data, DALLAS, briefing, baking, validation, playtest, and publishing semantics. It does not reproduce the MFC dialog layout, Win32 ownership, page-database locks, generated C++ workflow, temporary GameSave.D3L bridge, or original output formats.

RevivalEditor begins in Phase 1 with the first canonical resident world and Metal viewport. It grows with each gameplay slice. This is an editor/runtime co-development decision, not a claim that the historical editor was completed before the game.

The [current implementation plan](current-plan.md) is the sole live record of the active editor/player slice, current lane and evidence boundary, and one-or-two-developer capacity and ownership. Update it as work moves; this contract defines the required creator result rather than duplicating its task queue.

The editor is a top-tier human creation product before it becomes an automation surface. MCP, headless authoring, agent tools, training capture, telemetry, and a public command protocol are outside the current roadmap.

## First integrated slice

The Phase 1 editor must:

- at the Phase 1 Mac/shared checkpoint, open the same read-only complete Training Level as RevivalMac, focus the selected acceptance room, and derive one editable complete-level project value from it; early RevivalMobile compatibility work may consume that same level contract without creating a separate Phase 1–7 closure gate, and Phase 8 owns required physical mobile integration;
- render it through RevivalMetal;
- inspect and select a room, face, portal boundary, or object;
- after tracing the historical editor/runtime workflow, choose and perform the smallest real canonical edit that proves durable ownership without creating a disposable path or mutating the imported base;
- name, undo, and redo that edit through UndoManager;
- save, close, and reopen the native project;
- enter the shipping simulation and renderer with a disposable play-session copy built through the same loader and world types;
- return to the document with useful selection and camera state;
- release the resident level safely on document replacement and shutdown.

This is the permanent application and data path, not a disposable viewer. It intentionally omits speculative preview packages, stream-cell overlays, fixed buffer-slice rules, background-document residency protocols, a job scheduler, and a complete workspace framework.

## Native application shell

Each open project is one NSDocument, one main-actor editing owner, one canonical project value, one UndoManager history, and one primary project window. AppKit owns document open, save, revert, close, edited state, file coordination, autosave, menu routing, and window restoration.

The shell grows toward:

- a Project Navigator and active-level Outliner;
- central canvases for world, definitions, behaviors, campaigns, scores, briefings, and cinematics;
- a contextual Inspector;
- Problems, Activity, Playtest, and Trace surfaces;
- standard menus, shortcuts, Full Keyboard Access, and VoiceOver.

Add each surface when a real slice has content for it. Do not build empty panes merely to satisfy a final-layout diagram.

Selection and focus remain synchronized across the current hierarchy, viewport, inspector, references, and diagnostics. Spatial gestures have numeric and keyboard alternatives. Continuous gestures coalesce into one named undo action.

This shell has no generic reactive store, view-model graph, command bus, editor service layer, cloud collaboration system, source-control client, marketplace, or attempt to replace Blender.

## Canonical authoring project

The editor writes ordinary inspectable source projects. The Phase 1 package contains only `project.json`; the named subdirectories appear when a reached authoring operation owns content for them:

    MyProject.revivalproject/
      project.json
      campaigns/
      levels/
      behaviors/
      definitions/
      assets/
      presentations/
      localization/

The file split follows real authoring and merge needs. Structured source uses deterministic versioned encodings once a format is public. Large media remains in ordinary files. Durable content keys connect values that need stable references; generated runtime indices never enter source.

Imported retail content is a read-only canonical base installed in RevivalEditor's own local base library. The Phase 1 `project.json` stores its immutable canonical package reference plus a deterministic, source-index-sorted room-name edit delta. On open, RevivalEditor validates and resolves that reference and derives a separately owned complete editable `Level`; unchanged topology and presentation media are neither copied into the project nor mutable through the base. When a later real media edit requires project ownership, copy only that media, preserve its provenance, and declare the replacement without mutating the base.

Local tabs, pane positions, selection, active tool, and viewport cameras are not canonical source. Authored camera bookmarks are content.

Add immutable snapshots and stale-result rejection to the first long-running USD import, media conversion, lighting bake, navigation bake, validation, or publication operation that can race with editing. Keep the mechanism local to that operation until two real operations need a common form.

## Shared world and rendering

The editor and player use the same complete `Level` world model, dependency rules, room/portal and terrain visibility, render extraction, Metal passes, and simulation. The editor owns an editable project value and play owns a disposable session copy; “shared world” does not mean concurrent mutation of one instance. Play-in-editor is not an editor-only game fork.

Immediate edits update canonical in-memory values and the smallest affected preview resource directly. Use ordinary rotating frame resources where Metal safety requires them. Do not predefine:

- one last-good and one candidate generated package layer;
- a universal project-generation protocol;
- exactly three DraftOverlay slices;
- a fixed four-viewport memory envelope;
- an editor-only loader or renderer;
- a streaming cell and budget diagnostic workspace.

If actual edit latency or GPU lifetime proves that a derived preview mechanism is required, measure the operation and specify the smallest replacement. The editor still shares the product renderer and leaves one preview path.

## Editing surfaces

### World workspace

The complete world workspace covers indoor rooms, faces, vertices, portals, bridges, joins, attachments, snapping, splitting, triangulation, outdoor terrain, reusable rooms, materials and UVs, mirrors, specular response, decals, procedural and volumetric surfaces, objects and starts, triggers, paths, navigation, goals, matcens, ambient sound systems and patterns, lighting, fog, weather, sky, automap metadata, markers, cameras, and typed room roles.

It provides selection, transform, duplication, grouping, naming, search, inspection, undo/redo, validation, repair, statistics, and live Metal preview. A modern operation may replace several historical commands when it preserves their useful outcomes.

### Geometry exchange

Blender is the recommended bulk-geometry workflow. USD through Model I/O is the first native DCC ingress. Import and reimport normalize units, axes, transforms, winding, stable source identity, room and portal assignment, materials, UVs, collision ownership, and provenance into canonical editable geometry.

The runtime never live-links to USD. Revival-specific gameplay, navigation, behavior, and presentation remain native project data.

Another real interchange format may be added when a demonstrated creator workflow justifies its parser and maintenance cost. It does not require a generic DCC abstraction and does not authorize backward legacy export.

### Navigation and lightmaps

Begin by translating the room/portal, outdoor, node, path, clearance, steering, and diagnostic semantics required by the current source slice. The native navigation model is ratified after several real AI routes work; hand-authored cinematic and patrol paths remain distinct.

Import the released lightmap pages, UV2, and sampling meaning faithfully enough to reproduce source images. Measure the whole retail set and actual editor operations before choosing a new atlas or bake representation. A simpler room-local layout may replace it with image, capacity, and migration evidence; it is not a Phase 1 precondition.

The eventual native lighting bake is deterministic enough for reproducible creator output and incremental enough for productive editing. Do not preselect a general unwrap library, GPU compute bake, exact atlas count, or permanent toolchain-byte identity before the first real bake.

### Content definitions

Typed inspectors eventually edit materials, robots, powerups, buildings, clutter, ships, weapons, doors, lights, sounds, ambient patterns, physics, animation, AI, death, effects, cockpit, HUD, cameras, and source-supported haptic parameters. Inventory add/remove/use and item-lifecycle bindings belong to the behavior workspace; there is no invented general inventory-definition inspector.

References use the canonical content catalog and report affected owners before destructive changes. The historical network-page database, check-in/check-out workflow, and local/network overlays do not return.

### Behavior

Behavior authoring grows from translated source behavior. Version 1.0 must provide a reusable human-authored native model capable of composing the evidenced DALLAS event, condition, action, value, function and reference surface without editing Swift or generated files. That requirement does not preselect a graph, textual language, or executor. The first surface places and configures the bindings, parameters, and explicit state used by the Training door, trigger, robot, goal, and presentation chains, while inspecting and tracing their source-linked typed Swift control flow. It provides validation and failure navigation without prematurely selecting the final representation.

Direct typed Swift remains the canonical runtime while early slices expose the smallest useful configuration and trace surface. Working generated DALLAS, handwritten/custom, timer or persistent-state, and presentation-oriented evidence selects the version 1.0 authored representation and its one runtime path; it does not decide whether reusable human authoring is required. Any accepted form never generates C++, invokes a native compiler, or emits executable plugins. Mechanics beyond the shipped game and tools remain later decisions.

### Campaign, audio, and presentation

The campaign workspace covers level order, branches, secrets, returns, allowed ships, progress, intros, endings, briefing and TelCom assignment, adaptive scores, goal identity and target/completion rules, and campaign completion rules.

The audio and score workspace separately covers sound definitions, UI and placed/object sound sources, room and portal propagation, ambient pattern elements with probability and timing ranges, per-room reverb, terrain altitude/volume bands, and adaptive-score regions, roles, loops, transitions and gameplay bindings. Each applicable family has its own preview, validation, save/reopen/play and package proof. It never writes OMF or reopens retail archives.

The presentation workspace covers briefing screen creation, ordering, navigation, buttons, conditions and independently failing text/image/movie/sound effects; the working TelCom goal, ship-status and ship-selection surfaces; HUD, cockpit, automap, auxiliary views, markers, in-game cinematics, controls, timing, colors and preview. It also owns behavior-message catalog editing and reference-safe renaming, exact locale/fallback authoring, and modern-font ingress with glyph coverage, metrics, kerning, atlas generation and localization preview. Dormant historical presentation ideas remain in the future-opportunities register until contrary evidence or a later product decision makes them real scope.

### Asset and build

The suite imports and inspects supported geometry, models, animation, textures, modern fonts, audio, movies, and player media; records rights; enforces bounds at import; bakes fonts, lighting and navigation; audits dependencies and orphans; and publishes packages. Retail bitmap-font conversion remains exclusive to D3Import; RevivalEditor consumes its canonical result but never becomes a second retail font reader.

One publisher validates complete level topology and the dependencies reachable through the project's current behavior surface, then produces canonical native content. It does not emit HOG, D3L, original editor files, or native plugins. The publisher's output proof is distinct from RevivalMac's and RevivalMobile's hostile package-intake, local-library, activation, rollback and removal proof. Security, signing, layering, and migration grow with those real distribution boundaries rather than being simulated during the first local editor loop.

## Authoring loop

The default loop is:

1. edit canonical project data;
2. validate changed references and the dependencies reachable through the project's current behavior surface;
3. update only derived data that is actually stale;
4. run the current level or scenario in-process through RevivalCore and RevivalMetal;
5. return to the document with logs and failing references linked to their owners.

Play-in-editor uses the shipping simulation and one selected timing model. A standalone package passes through the same validator and publisher with release checks enabled.

## Undo and testability

Editor mutations are concrete typed edits over canonical documents. Stable IDs address values whose identity must survive editing, references, or save/reopen. Names and array positions do not substitute where durable identity is required.

Each completed action registers a named inverse with UndoManager. Continuous samples stay transient and commit as one action. Do not build a generic command protocol, command bus, service layer, or public wire format.

Every new or changed editor behavior starts with one focused automated test that fails for the intended reason before production implementation. As a workspace matures, it also accumulates document-composition, reference, validation, and save-reopen-play tests for its actual production path. Recovery remains outside source until the creator accepts it. View code does not own game rules or serialization.

## Creator completeness gate

The suite is complete when a creator can start with an empty project and, without hand-editing generated files or invoking a legacy tool, build a non-bundled certification package that proves the toolchain:

- build indoor and outdoor levels;
- define their objects, combat systems, AI, audio, materials, lighting, goals, and behaviors;
- assemble a branching campaign with difficulty, room roles, music, cinematics, briefings, cockpit, automap, cameras, markers, and presentation;
- create multiplayer maps and modes with the supported authority and communication rules;
- validate, debug, play, replay, package, reopen, and publish;
- install the package in RevivalMac and RevivalMobile and complete its declared play paths in both.

Installation at this gate uses both real player libraries: validate and stage the package, resolve its explicit base and replacement relationships, activate it, enumerate its campaign, and preserve the prior active set under a failed replacement. RevivalMobile receives the canonical package through its system-picker handoff before the shared validation path; it never imports retail data. The certification case also proves disable and removal behavior. It does not require a marketplace, account, automatic updater, cloud transfer or project-operated distribution service.

Imported stock content, a non-bundled independent certification campaign, and a non-bundled independent multiplayer package are separate proof cases. All are required for complete creator status. They do not supply version 1.0 replacement assets, ship as included campaigns, or remove the requirement that users own and import supported retail content.

## Future automation

Human selection, undo, diagnostics, validation, and playtest operations may later provide a clean automation seam. They are not designed as a wire protocol now.

Only after the complete human creator suite ships may the project design an MCP adapter or training system. It must reuse the stabilized human document, validation, playtest, and publisher paths and cannot introduce a parallel model or use proprietary media without independent rights.
