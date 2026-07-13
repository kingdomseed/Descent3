# Native creator suite

- Status: accepted
- Date: July 13, 2026
- Authority: binding creator-product contract

## Decision

Build one integrated macOS application, `RevivalEditor`, for the complete creation workflow. It shares canonical content types, simulation, and Metal rendering with the game. It does not port the Windows editor, reproduce its dialog layout, or export original Descent 3 files.

The editor starts in Phase 2 as soon as canonical world data exists. Every later gameplay slice adds its matching authoring and validation surface. Phase 8 completes campaign and content creation; Phase 9 completes multiplayer creation and the full suite. Neither phase is the moment when editor work begins.

The editor is a top-tier human creation product before it is an automation surface. Phase 2 begins the real application shell and document lifecycle, not a disposable debug viewer. MCP, headless authoring, agent tools, training capture, telemetry, and a public command wire format are not Phase 1–10 work.

## Product shape

The complete product has exactly six targets: five game-and-creator targets plus the isolated Phase 9 relay service.

| Target | Responsibility |
| --- | --- |
| `D3Import` | One-way retail conversion into canonical content |
| `RevivalCore` | Content types, simulation, behaviors, validation, saves, replay, and package rules |
| `RevivalMetal` | Direct Metal rendering for game and editor viewports |
| `RevivalMac` | Player application, input, audio, presentation, import UX, release packaging, and no-window dedicated hosting |
| `RevivalEditor` | Native project editing, baking, validation, playtest, and publishing |
| `RevivalRelay` | Public session discovery, expiring registration, join authorization, and opaque QUIC relay |

Do not split each historical dialog or utility into a new target. Editor features are views and commands over one canonical project model. Tests live beside the owning target.

## Native application shell

Each open `.revival` directory package is one `NSDocument`, one `@MainActor EditorSession`, one canonical project value, one `UndoManager` history, and one primary project window. AppKit owns document open, save, revert, close, edited state, file coordination, window restoration, and standard menu routing. Crash recovery uses `NSDocument` autosave-elsewhere storage outside the source package, not autosave-in-place; the creator previews and accepts it before source changes. Multiple projects may remain open, but only the key project window owns the one live `WorldStreamer` and dynamic world residency set. Background-document viewports pause and release presentation residency until their window becomes key. The project does not recreate those services in a custom editor framework. Apple's [`NSDocument` documentation](https://developer.apple.com/documentation/appkit/nsdocument/) defines the platform behavior used here.

The project window has one consistent layout:

- a leading Project Navigator and active-level Outliner;
- central tabbed canvases for world, definitions, behaviors, campaigns, scores, briefings, cinematics, and other authored documents;
- a trailing contextual Inspector;
- a bottom Problems, Activity, Playtest, and Trace pane;
- one contextual `NSToolbar`, standard menu-bar commands, and conventional shortcuts.

The level canvas supports one-, two-, and four-viewport layouts through `RevivalMetal`. Perspective, orthographic, fly, orbit, focus, textured, wireframe, collision, portal, navigation, lighting, and streaming views are modes of the same world canvas, not separate utilities. Selection and focus remain synchronized across the Outliner, every viewport, the Inspector, reference navigation, and Problems. Opening a diagnostic or reference selects and frames the exact owning element.

Ordinary property editing is nonmodal. Spatial gestures have numeric Inspector and keyboard alternatives. Continuous drags and scrubbing coalesce into one named undo action. Standard commands live in menus and expose shortcuts; the toolbar holds only frequent contextual actions. Navigator, Inspector, Problems, forms, and commands support Full Keyboard Access and VoiceOver, and spatial manipulation always has a nonvisual Outliner or numeric path.

This shell stays direct. There is no generic reactive store, view model graph, command bus, editor service layer, cloud collaboration system, source-control client, marketplace, or attempt to replace Blender.

## Canonical authoring project

The editor writes source projects, not imported package internals. A project is an ordinary inspectable directory:

```text
MyProject.revival/
  project.json
  campaigns/
  levels/
  behaviors/
  definitions/
  assets/
  presentations/
  localization/
```

The exact file split follows real authoring and merge needs. Structured source uses deterministic, versioned encodings. Large media remains in ordinary files. Durable `ContentKey` references connect documents; generated package-local IDs never appear in source projects.

Imported retail content is a read-only base package. Its local `authoring/` snapshot uses the same canonical source schemas as a native project, while its GPU stream records remain generated runtime products that the editor never decodes. A project can reference or replace its canonical keys without mutating the base. New projects can also stand alone and contain no retail dependency. The editor resolves the base package plus project sources through one content catalog and one deterministic layer order.

An explicit **Derive editable source** command copies a selected canonical document and required editable media from the base package's read-only `authoring/` snapshot into the project, preserves durable keys and provenance, and declares a project-owned replacement. Unchanged media remains a reference to the read-only base. The base bytes never change. A creator can therefore modify an owned childhood level locally without turning the imported package into an editor database or reverse-engineering GPU records. Publication checks the derived document and media rights like any other project source.

Publicly released project formats receive deliberate migrations because they contain creator-owned work that cannot always be regenerated. This versioning policy does not create D3L, HOG, DALLAS, or legacy-page compatibility.

Local interface state is not canonical source. Open tabs, pane sizes, transient selection, active tool, current camera demand, and viewport cameras use AppKit restoration or recovery storage. Authored camera bookmarks remain project content. This separation keeps project diffs deterministic and prevents one creator's window layout from rewriting shared source.

Each edit, undo, redo, revert, accepted recovery, or source-changing asynchronous result advances one transient monotonic `ProjectEditGeneration` owned by the open `EditorSession`. It identifies the exact unsaved snapshot consumed by validation, USD or native-media ingress, preview-record generation, baking, playtest, and publishing. It is local authoring concurrency state, not a persisted package schema, semantic revision, `simulationSemanticRevision`, or save-compatibility decision.

## Editing surfaces

### World workspace

The world workspace covers indoor room and portal geometry, outdoor terrain, reusable room components and prefabs, faces and vertices, materials and UVs, mirror surfaces, specular response, scorch receivers, procedural textures, volumetric surfaces, objects and starts, triggers, paths and navigation, goals, matcens, ambient systems, lighting, animated lighting, fog, weather, sky and horizon, stars, satellites, halos, atmosphere, terrain environment audio, automap visibility and secret metadata, markers, camera points, and typed room roles for refueling, goals, secrets, special-purpose spaces, external spaces, and waypoints.

It provides selection, snapping, transform tools, joining and splitting, duplication, grouping, naming, search, inspection, undo and redo, validation, repair, statistics, and live Metal previews. Viewports support textured, wireframe, collision, portal, navigation, and lighting diagnostics; focus, fly, orbit, and orthographic navigation; and saved views or camera bookmarks. A modern operation may replace several historical commands if it preserves their useful results.

### Geometry exchange

Blender is the recommended bulk-geometry workflow. The sole planned-product DCC interchange is USD loaded through Model I/O; direct glTF, 3DS, FBX, and OBJ readers are not part of the product. A creator may convert another format in Blender, then explicitly import or reimport USD into a native project. A second DCC format requires an explicit architecture amendment.

USD ingestion is one-way into canonical editable geometry. The contract fixes units, axes, transforms, winding, stable prim identity, room partitioning, portal assignment, material slots, primary and secondary UVs, collision ownership, and rejection of unsupported topology. Reimport matches stable source identities, previews every destructive change, and records source and toolchain provenance; it never live-links the runtime to a DCC file. Revival-specific roles, navigation, behavior, and gameplay metadata remain canonical editor data.

This workflow changes priority, not scope. Broad room, portal, bridge, join, attach, snap, split, triangulate, terrain, repair, and diagnostic tools remain required in the native editor. USD lands before the broad construction-tool closure so creators can build large geometry in a DCC immediately, while the integrated editor remains able to construct and repair a complete level without Blender.

### Navigation and lightmaps

Navigation baking produces the purpose-built room, portal, outdoor-region, clearance, and sparse three-dimensional waypoint graph defined by the architecture. Hand-authored paths remain separate source data. Diagnostics show disconnected regions, insufficient clearance, blocked dynamic edges, unstable ties, unreachable goals, and stuck-recovery traces. The bake is deterministic background work in `RevivalCore` and `RevivalEditor`; there is no generic navmesh, voxel-navigation library, or runtime path bake.

Lightmap coordinates use one explicit policy. Every room owns exactly one nonmipmapped 1024-by-1024 `rgba8Unorm` lightmap. Editor-built planar faces receive deterministic planar charts; the packer reserves a two-texel dilated gutter around every chart for bilinear sampling. Initial USD room geometry must provide UV2 whose normalized bounds, nonoverlap, and chart separation satisfy that same fixed atlas and gutter; import rejects invalid UV2 instead of invoking a general automatic unwrap. A room whose charts do not fit is split by the creator; the baker never adds another atlas or changes resolution.

The lighting solver is one deterministic background CPU publish path over canonical geometry. For the same source, bake revision, macOS, Swift, and SDK toolchain, it emits byte-identical canonical texels. A toolchain change must pass the bake corpus; changed texels require visual review and a bake-revision bump rather than an automatic baseline update. Incremental invalidation reruns the same solver for affected rooms. There is no quality-mode fork, general charting library, cross-level atlas, mip chain, or GPU-compute baking path.

### Streaming cells and budgets

The level remains one continuous creative document. One indoor room is automatically one stream cell. Terrain creation and resize use positive multiples of 32 quads and automatically partition the result into fixed 32-by-32-quad cells; creators do not draw a second streaming graph. Every live world viewport and play-in-editor session uses the shipping `WorldStreamer`.

The world canvas can overlay cell boundaries and cross-cell edges; display desired, loading, ready, active, and retiring state; and inspect exact cell, shared-resource, spatial-envelope, prefetch-shell, simultaneous-camera, destination, and lead-time costs. Selecting a camera anchor, portal, terrain transition, teleport, spawn, cinematic, mirror, or auxiliary camera shows its resolved envelope. Problems navigate an oversized cell, seam, missing dependency, envelope, batch, or lead-time violation to the responsible room, terrain cell, asset, object, behavior command, or camera path. A saved publication report records the same values. [World streaming](world-streaming.md) defines partition and runtime semantics.

Preview rendering keeps exactly one last-good generated package layer and one candidate in app-controlled derived storage outside the `.revival` source package. The normal record builder repacks the active level's complete project-owned GPU records and resolved table through the shipping `world.stream` schema. It repacks the complete project-owned `global.stream` when a global input changed and otherwise copies that immutable blob byte-for-byte into the self-contained candidate. Untouched base records remain external locators. Each candidate carries its exact `ProjectEditGeneration`; only a matching successful candidate may replace the last-good layer. After final GPU use the old layer is deleted. There is no generation chain, compactor, preview cache hierarchy, editor-only stream format, loader, renderer, or generated file inside canonical source.

Immediate spatial feedback uses one logical fixed-capacity render-owner-owned `DraftOverlay` backed by exactly three preallocated slices aligned with the renderer's frame-resource slots. Each slice fits the conservative maximum visible dirty-geometry union across all four supported editor viewports; invisible portions of a large dirty selection consume no overlay capacity, and all three physical slices count in the fixed editor high-water. It is resident only for the key editor document in the dynamic world set. On an edit or camera change, the editor rebuilds canonical values and transient gesture state into the next available slice, never overwrites an in-flight slice, and retains that slice through its final render use. Stable IDs suppress matching last-good streamed records, and the shipping renderer draws the draft through its normal passes. It is noncanonical, unpersisted, contains no texture payload, and is not a second renderer, loader, residency path, cache, or extra frame allocation.

Pointer, drag, and scrub samples modify transient gesture state and `DraftOverlay` only. Commit performs exactly one typed project edit, named undo registration, `ProjectEditGeneration` advance, and candidate build; cancellation performs none. Dirty geometry stays overlaid until a matching-generation preview installs, while any newer dirty records remain visible. A continuous gesture therefore never launches per-sample package work.

### Content-definition workspace

Typed inspectors edit materials, procedural surfaces, mirrors, blend semantics, robots, powerups, buildings, clutter, ships, weapons, doors, lights, sounds, ambient patterns, physics, animation, AI, death behavior, inventory behavior, effects, cockpit and monitor bindings, haptic event mappings, and object archetypes. They expose only difficulty-scaling opt-outs backed by active runtime rules; they do not invent a generalized difficulty-tuning framework.

All references use the shared content catalog. Changes report affected documents before destructive edits. The old network-page database, file locks, check-in/check-out workflow, and local-versus-network overlays do not return.

### Behavior workspace

The behavior workspace is the authoring front end for [BehaviorGraph](behavior-system.md). It supports typed nodes and ports, expressions, variables, functions and subgraphs, event ownership and authoritative or client-presentation execution roles, difficulty queries, cinematic commands, bounded game-mode command events, search, validation, execution tracing, breakpoints, inspection of persistent state, and deterministic replay of a test scenario.

It never generates C++, invokes a compiler, or emits a native plugin.

### Campaign workspace

The campaign workspace edits level order, branches, secret entry and return paths, training and multiplayer declarations, default and allowed ships, per-level ship selection, progress presentation, intros and endings, briefings, adaptive-score assignments and initial regions, per-level dependencies, and completion rules. A graph view and a direct ordered view operate on the same campaign document.

This workspace is a deliberate improvement over the original hand-authored mission manifest workflow.

### Audio and adaptive-score workspace

The audio surface imports supported modern audio, edits positional and ambient sound definitions, and authors canonical adaptive scores. A score defines regions, intro, idle, combat, transition and death roles, stream bindings, loop ranges, transition rules, and musical alignment. Creators can preview gameplay-state and behavior-command changes, interruption and resume policy, and region transitions without starting a packaged game.

Validation rejects missing streams, invalid loops, unreachable regions, transition dead ends, unsupported encodings, and incomplete rights metadata. Imported retail OMF is read-only canonical evidence; the editor neither reads nor writes OMF. [Adaptive music](adaptive-music.md) defines runtime ownership and persistence.

### Presentation workspace

The presentation workspace edits briefings, TelCom-style screens, HUD and animated cockpit presentation, automap presentation, bounded rear and auxiliary-view layouts, marker presentation, and purpose-built in-game cinematic sequences. Cinematics bind camera and target paths, duration, text, letterbox, fades, player-control and AI policy, completion or interruption, and behavior commands without becoming a general timeline engine. The workspace also supports text, images, movies, sounds, buttons, positions, fonts, colors, timing, effects, navigation, conditional display, localization keys, and preview.

It uses canonical media and behavior references. Imported proprietary media remains local and read-only unless the user supplies replacement media with independent rights.

### Asset and build workspace

The suite imports and inspects USD room geometry, models and animation plus supported modern textures, fonts, audio, movies, player pictures, ship logos, and audio taunts; records source and license metadata; enforces media dimensions, duration, size, and decoded bounds; builds font atlases and previews glyph coverage; binds animation states, sound events, and haptic events; bakes lighting and navigation; audits dependencies and orphans; and publishes packages. Retail bitmap fonts are read-only canonical base content produced by `D3Import`; the editor never reads `.fnt` files. Native projects use supported modern font inputs and the same canonical atlas and metrics model.

One publisher validates the complete dependency closure, compiles behavior graphs, produces immutable canonical content, records provenance, compares save-relevant canonical fields with the previous product, and refuses broken references or an unacknowledged semantic change without the required revision bump. It shows the affected scope, prior and current semantic fingerprints, and the author's explicit compatibility decision. It does not infer compatibility from byte hashes, emit HOG files, or write original editor formats.

## Authoring loop

The default loop is direct:

1. edit canonical project data;
2. validate the changed dependency closure;
3. compile affected behaviors and bake only stale derived data;
4. launch the current level or scenario at an explicitly selected difficulty in-process through `RevivalCore` and `RevivalMetal`;
5. return to the exact document, selection, viewport, and workspace state with logs, traces, and failing references attached to their source documents.

Play-in-editor uses the shipping simulation. It does not maintain an editor-only gameplay fork. A packaged standalone build passes through the same validator and publisher with release checks enabled.

Entering play-in-editor suspends every edit viewport and replaces the four-viewport demand profile with the supported game-camera profile on the same streamer. It never budgets a mixed game-plus-editor union. Exit restores the exact document selection, cameras, layout, and workspace state, waits for the restored editor envelope, then reveals the viewports.

## Undo, commands, and testability

Editor mutations use concrete typed edit families over canonical documents. Stable element IDs address rooms, portals, vertices, faces, objects, graph nodes, campaign nodes, and presentation elements; names and array positions do not identify edit targets. `EditorSession` is the only mutation owner. Each completed human action registers a named inverse with the document's `UndoManager`; continuous samples remain transient and the committed gesture is exactly one action. Do not build a generic command protocol, command bus, service layer, or public wire format.

USD and native-media import or reimport, preview-record generation, validation, lighting and navigation baking, and publishing consume immutable project snapshots. Each result carries the exact `ProjectEditGeneration` it used. A stale or cancelled result remains visibly marked in Activity for diagnosis but cannot enter or clear the active Problems set, report publish success, become playable, or replace the last good derived product. Cancellation and failure leave project source and every last-good derived product unchanged. One cancellable task owns each user-requested long operation; Activity shows progress and source-linked failure while unrelated inspection remains responsive. There is no editor job scheduler.

Each workspace has document-level tests, reference-integrity tests, validation fixtures, and at least one save-reopen-play round trip. Dirty projects autosave atomically to recovery storage outside the source project. After a crash, the editor offers the recovered state and does not overwrite project sources until the creator accepts it. View code does not own game rules or serialization.

## Creator completeness gate

The suite is complete when a creator can start with an empty project and, without hand-editing generated files or invoking a legacy tool:

- build indoor and outdoor levels;
- define the objects, combat systems, AI, audio, materials, lighting, goals, and behaviors they use;
- assemble a branching campaign with difficulty-aware behavior, room roles, adaptive music, in-game cinematics, briefings, cockpit, automap, auxiliary views, markers, and presentation;
- create multiplayer maps and modes with declared authoritative and client-presentation behavior, bounded game-mode commands, chat policy, and host-operator configuration supported by the game;
- validate, debug, play, replay, package, reopen, and publish the project;
- install the resulting package in the player application and complete its declared play paths.

Stock import is one proof case. An independently authored campaign proves the campaign and content workflow. An independently authored multiplayer package proves the multiplayer workflow. Both must pass for full creator-suite completion.

## Future automation boundary

Stable IDs, typed edits, structured diagnostics, deterministic validation, and playtest operations exist because the human editor needs reliable selection, undo, repair, testing, and maintenance. They deliberately leave a clean future automation seam without making it a current product interface.

Only after Phase 10 ships the complete human creator suite, including the independently authored campaign and multiplayer package, may the project design an MCP adapter or training and evaluation system. Phase 1–10 add no MCP server, automation target, headless editor, public command-schema stability promise, agent permission model, training recorder, telemetry, or agent-only operation. Future automation must invoke the same stabilized editing session, validators, playtest, and publisher used by people. It cannot create a parallel document model or mutation path, and proprietary retail or converted media cannot enter a training corpus without independently established rights.
