# Native creator suite

- Status: accepted
- Date: July 13, 2026
- Authority: binding creator-product contract

## Decision

Build one integrated macOS application, `RevivalEditor`, for the complete creation workflow. It shares canonical content types, simulation, and Metal rendering with the game. It does not port the Windows editor, reproduce its dialog layout, or export original Descent 3 files.

The editor starts in Phase 2 as soon as canonical world data exists. Every later gameplay slice adds its matching authoring and validation surface. Phase 8 completes campaign and content creation; Phase 9 completes multiplayer creation and the full suite. Neither phase is the moment when editor work begins.

## Product shape

The complete product has five production targets:

| Target | Responsibility |
| --- | --- |
| `D3Import` | One-way retail conversion into canonical content |
| `RevivalCore` | Content types, simulation, behaviors, validation, saves, replay, and package rules |
| `RevivalMetal` | Direct Metal rendering for game and editor viewports |
| `RevivalMac` | Player application, input, audio, presentation, import UX, release packaging, and no-window dedicated hosting |
| `RevivalEditor` | Native project editing, baking, validation, playtest, and publishing |

Do not split each historical dialog or utility into a new target. Editor features are views and commands over one canonical project model. Tests live beside the owning target.

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

Imported retail content is a read-only base package. A project can reference or replace its canonical keys without mutating it. New projects can also stand alone and contain no retail dependency. The editor resolves the base package plus project sources through one content catalog and one deterministic layer order.

An explicit **Derive editable source** command copies a selected canonical document into the project, preserves its durable key and provenance, and declares a project-owned replacement. Unchanged media remains a reference to the read-only base. The base bytes never change. A creator can therefore modify an owned childhood level locally without turning the imported package into an editor database. Publication checks the derived document and media rights like any other project source.

Publicly released project formats receive deliberate migrations because they contain creator-owned work that cannot always be regenerated. This versioning policy does not create D3L, HOG, DALLAS, or legacy-page compatibility.

## Editing surfaces

### World workspace

The world workspace covers indoor room and portal geometry, outdoor terrain, reusable room components and prefabs, faces and vertices, materials and UVs, mirror surfaces, specular response, scorch receivers, procedural textures, volumetric surfaces, objects and starts, triggers, paths and navigation, goals, matcens, ambient systems, lighting, animated lighting, fog, weather, sky and horizon, stars, satellites, halos, atmosphere, terrain environment audio, automap visibility and secret metadata, markers, camera points, and typed room roles for refueling, goals, secrets, special-purpose spaces, external spaces, and waypoints.

It provides selection, snapping, transform tools, joining and splitting, duplication, grouping, naming, search, inspection, undo and redo, validation, repair, statistics, and live Metal previews. Viewports support textured, wireframe, collision, portal, navigation, and lighting diagnostics; focus, fly, orbit, and orthographic navigation; and saved views or camera bookmarks. A modern operation may replace several historical commands if it preserves their useful results.

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

The suite imports and inspects supported modern room geometry, models, animation, textures, fonts, audio, movies, player pictures, ship logos, and audio taunts; records source and license metadata; enforces media dimensions, duration, size, and decoded bounds; builds font atlases and previews glyph coverage; binds animation states, sound events, and haptic events; bakes lighting and navigation; audits dependencies and orphans; and publishes packages. Retail bitmap fonts are read-only canonical base content produced by `D3Import`; the editor never reads `.fnt` files. Native projects use supported modern font inputs and the same canonical atlas and metrics model.

One publisher validates the complete dependency closure, compiles behavior graphs, produces immutable canonical content, records provenance, compares save-relevant canonical fields with the previous product, and refuses broken references or an unacknowledged semantic change without the required revision bump. It shows the affected scope, prior and current semantic fingerprints, and the author's explicit compatibility decision. It does not infer compatibility from byte hashes, emit HOG files, or write original editor formats.

## Authoring loop

The default loop is direct:

1. edit canonical project data;
2. validate the changed dependency closure;
3. compile affected behaviors and bake only stale derived data;
4. launch the current level or scenario at an explicitly selected difficulty in-process through `RevivalCore` and `RevivalMetal`;
5. return to the same editor state with logs, traces, and failing references attached to their source documents.

Play-in-editor uses the shipping simulation. It does not maintain an editor-only gameplay fork. A packaged standalone build passes through the same validator and publisher with release checks enabled.

## Undo, commands, and testability

Editor mutations are small typed commands over canonical documents. The same command describes undo and redo where practical. Do not build a general command framework before the first real operations exist; extract shared machinery only after repeated commands establish it.

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
