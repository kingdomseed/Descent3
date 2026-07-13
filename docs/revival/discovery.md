# Historical discovery and retained evidence

- Status: historical evidence
- Date investigated: July 12-13, 2026
- Authority: non-normative; `architecture.md` supersedes all design recommendations from the original discovery

## Purpose

This document records what the source and retail-data investigation established before the project chose a complete Swift/Metal rewrite. It can answer bounded questions about source provenance, original content, formats, gameplay behavior, multiplayer, replay, editor capability, and tool intent.

It is not an instruction to extend the C++ engine, preserve OpenGL, extract a renderer interface, maintain SDL, keep an ABI, or seek upstream parity. Current product decisions live in [Architecture](architecture.md), [Content pipeline](content-pipeline.md), and [Roadmap](roadmap.md).

## Source baseline

- Repository: [`DescentDevelopers/Descent3`](https://github.com/DescentDevelopers/Descent3)
- Pinned source commit: `156cba8aafd997d27deb0902ba6026bcdcc1cfaf`
- License: GPL-3.0-or-later in source headers
- Historical release context: community v1.5.0 plus later work on `main`

The source tree contains the game, renderer, platform code, audio, networking, editor source, DALLAS utilities, base campaign scripts, secret and Training scripts, Mercenary scripts, and multiplayer modules. Retail media is not included.

The pinned tree remains available while ledgered game and creator capabilities are reconstructed and verified. It does not compile into or link with any new product target.

It is not a permanent product component. It may move to an archival branch or leave the active checkout only after Phase 10 has implemented and verified, replaced, or explicitly excluded every ledger row and no unresolved product question still depends on the active tree.

## Verified M4 reference build

The pinned source initially failed on AppleClang 21 because `fix/fix.h` used global `size_t` without including its defining standard header. The local correction added `<cstddef>` and used `std::size_t`.

After that correction:

- all 532 native arm64 Debug build steps completed;
- all 12 existing CTest tests passed;
- installation completed to `builds/mac/installed/Descent3.app`;
- the executable was a thin arm64 Mach-O;
- the POSIX signal handler was corrected to avoid recursive logger deadlock and exited with status 143 after `SIGTERM`;
- the local application remained a development artifact rather than a signed release.

The reproducible procedure is preserved in [Legacy M4 reference build](macos-arm64-build.md).

## Verified retail evidence

Owned original base-game and Mercenary disc images were extracted locally. The 1.0/1.3-era base data was updated through the official 1.4 updater in an isolated disposable environment. The promoted `extra.hog` and `extra13.hog` archives match canonical preservation hashes.

The native reference executable:

- read the retail archives and recognized the base and Mercenary missions;
- loaded all expected asset pages and the 1.4 Black Pyro overrides;
- rendered the animated menu and accepted pilot creation and keyboard input;
- entered and rendered the original Training Mission;
- entered base campaign level 1 through its briefing and ship selection.

These observations prove that the owned inputs are authentic and sufficient for the new importer. They do not make the reference executable part of the new runtime.

Full hashes, extraction provenance, and local layout are recorded in [Retail data](retail-data.md).

## Facts carried into the new design

### Legacy content is layered

The original engine resolves loose files and mounted HOG archives through a precedence order. Patch archives override earlier data. `D3Import` must resolve that order once and emit one unambiguous canonical asset for each ID. The runtime will not reproduce the virtual filesystem.

### The renderer has a compact core and several required special paths

The common world paths are flat polygons, base-textured polygons, and base-plus-lightmap polygons with vertex color, fog, alpha, and gamma. They are not the complete rendering surface. The released engine also renders specular faces, reflected room views, scorch decals, procedural fire and water textures, volumetric faces and lighting, and several declared blend semantics. [`Descent3/render.cpp`](../../Descent3/render.cpp), [`Descent3/procedurals.cpp`](../../Descent3/procedurals.cpp), [`Descent3/room_external.h`](../../Descent3/room_external.h), and [`renderer/HardwareOpenGL.cpp`](../../renderer/HardwareOpenGL.cpp) provide the primary evidence.

Original textures include 1555, 4444, and lightmap representations. Metal can express the common path with a small pipeline set and add the special paths directly as their first verified scenes require them. This inventory does not require a render graph or a general material framework.

The old OpenGL path, `rend_*` API, `gpu_*` seam, SDL window ownership, triangle fans, framebuffer scaling, and GLSL shaders are clues for decoding and presentation. None is a product interface.

### Original timing is variable

`Descent3/GameLoop.cpp` derives global `Frametime` from elapsed wall-clock milliseconds and feeds that value through gameplay systems once per frame. The new project intentionally replaces this with one fixed 120 Hz simulation. There is no variable-time compatibility mode.

`EVT_INTERVAL` is also delivered once per historical frame with elapsed-time data. Stock translation therefore needs one project-wide mapping rule rather than a per-level guess. Simulation work becomes fixed-tick logic with tick-native rates and timers; equivalent polling becomes typed events; presentation-only work stays outside authoritative state. The pinned reference engine defaults to a 60 frames-per-second cap, so a 120 Hz simulation is approximately twice its default interval dispatch rate. Generated source size alone does not establish the operation cost of an interval handler.

### Music is an adaptive scripted score

OMF themes contain regions, stream selections, loops, branches, theme roles, and clean transitions. [`music/omflex.cpp`](../../music/omflex.cpp) parses the format and [`music/sequencer.cpp`](../../music/sequencer.cpp) schedules it. Gameplay and DALLAS request region changes through [`Descent3/d3music.cpp`](../../Descent3/d3music.cpp) and [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp); saves preserve logical region state in [`Descent3/gamesave.cpp`](../../Descent3/gamesave.cpp).

The declared `tMusicSeqInfo` surface is broader than the active loop: several damage, shield, kill, and mood paths are inactive or commented out. Translation records proven behavior and resolves ambiguity instead of copying dormant fields. The native design is specified in [Adaptive music](adaptive-music.md).

### Osiris and DALLAS were separate parts of one behavior workflow

Osiris was a native compiled-module runtime, not an editor or bytecode virtual machine. It loaded game, mission, and level modules; bound scripts to objects; dispatched custom, level, mission, and default object events; delivered trigger and level events; managed timers; exposed a large engine function table; and persisted script-owned state. The core contract is visible in [`Descent3/osiris_dll.h`](../../Descent3/osiris_dll.h), the module loader in [`Descent3/OsirisLoadandBind.cpp`](../../Descent3/OsirisLoadandBind.cpp), and the imported engine surface in [`scripts/osiris_import.h`](../../scripts/osiris_import.h).

DALLAS was the graphical event, condition, and action authoring layer. Its schema covered level, object, and trigger ownership with typed references and broad action categories for world objects, players, doors, rooms, triggers, weather, AI, audio, timers, goals, variables, cinematics, and custom behavior. On save, DALLAS generated C++ and message tables, then invoked a compiler to create a native module. The schema and generator live in [`editor/DallasMainDlg.h`](../../editor/DallasMainDlg.h) and [`editor/DallasMainDlg.cpp`](../../editor/DallasMainDlg.cpp). Some campaign sources also contain handwritten code outside the generated tree.

The new typed [`BehaviorGraph`](behavior-system.md) and compiled `BehaviorProgram` replace this complete workflow. They retain events, values, conditions, queries, commands, timers, state, functions, debugging, and creator extensibility without loading DLLs, preserving the Osiris ABI, generating C++, or permitting native code in packages.

The pinned GPL community commit is the normative baseline for stock behavior because it is inspectable and supplied the 55 native reference modules used by the successful M4 smoke run. Retail 1.4 content supplies media, identifiers, and comparison evidence. Retail DLL behavior is ambiguity evidence only, and the new product never imports or executes those DLLs. Known defects are not preserved automatically; each deliberate semantic correction is recorded in the translation ledger.

### Player presentation extends beyond HUD and TelCom

The released game has a separate three-dimensional automap with discovery state, full-map effects, and marker display in [`Descent3/TelComAutoMap.cpp`](../../Descent3/TelComAutoMap.cpp). [`Descent3/cockpit.cpp`](../../Descent3/cockpit.cpp) implements an animated cockpit distinct from the HUD. [`Descent3/SmallViews.cpp`](../../Descent3/SmallViews.cpp) and [`Descent3/GameLoop.cpp`](../../Descent3/GameLoop.cpp) cover rear, GuideBot, guided-weapon, marker, and related auxiliary views.

Player markers persist messages and positions. The gameplay-level force-feedback system in [`Descent3/D3ForceFeedback.cpp`](../../Descent3/D3ForceFeedback.cpp) shows intended effects even though the retained POSIX backend is a stub. Multiplayer also exchanges player-selected pictures, ship logos, and compressed audio taunts. These are functional and security requirements for native counterparts, not reasons to preserve legacy media files, codecs, or packet layouts.

### Original saves expose implementation layout

Historical save code mixes explicit fields with raw structure bytes and `sizeof` checks for players, objects, AI, effects, and other state. Osiris modules append their own state.

The new engine writes a new canonical snapshot and does not import or export historical saves.

### Original multiplayer is a separate old architecture

The source implements server and client roles, reliable and unreliable packet paths, custom reliability, game-time exchange, object updates, and native game modules. These mechanisms are evidence for functional behavior, game modes, lifecycle, presentation, and failure cases. They are not the native design.

Multiplayer, dedicated hosting, multiplayer authoring, and replay are committed revival capabilities. Phase 9 selects a modern design against the deterministic simulation, current Apple networking APIs, security requirements, and measured behavior. It does not inherit the original protocol, packet layouts, reliability layer, module ABI, or live interoperability.

### The original creator surface was much larger than a level viewer

The released `editor/` application is Windows-only and tightly coupled to the old engine, level representation, page database, native scripting workflow, and MFC UI. Porting it would restore the wrong architecture. Its functional inventory is still mandatory evidence.

The world editor covered rooms, faces, vertices, portals, bridges, joining, attaching, snapping, combining, triangulation, indoor and terrain workflows, reusable rooms, materials and UVs, objects, starts, cameras, waypoints, sounds, doors, triggers, paths, navigation, matcens, goals, ambient life, lighting, fog, validation, repair, statistics, and 3DS room import. It also exposed textured and wireframe views, navigation and focus commands, view cameras, autosave, and crash restoration. The command surface begins in [`editor/editor.rc`](../../editor/editor.rc); serialized level coverage is visible in [`Descent3/LoadLevel.h`](../../Descent3/LoadLevel.h).

Dedicated gameplay tools handled triggers, paths and navigation graphs, goals, matcens, indoor and terrain radiosity, lightmaps, volumetrics, fog, coronas, and animated lighting. Terrain controls included sky and horizon colors, stars, satellites, rotation, halos, atmosphere, and environmental audio. The suite also edited textures and procedural materials, robots, powerups, buildings, clutter, ships, weapons, doors, sounds, ambient patterns, lights, physics, animation, AI, death, inventory, effects, object archetypes, fonts, terrain groupings, and generic content references. [`editor/CMakeLists.txt`](../../editor/CMakeLists.txt) and [`manage/CMakeLists.txt`](../../manage/CMakeLists.txt) provide category-level inventories.

The Briefing Editor authored multi-screen layouts with text, bitmaps, movies, sound, buttons, timing, effects, colors, fonts, navigation, conditional mission flags, preview, and save and load. Campaign manifests carried levels, branches, secrets, intro and ending presentation, briefings, music, progress screens, training and multiplayer declarations, default and allowed ships, per-level ship selection, dependencies, and final markers. See [`editor/BriefEdit.cpp`](../../editor/BriefEdit.cpp), [`Descent3/Mission.h`](../../Descent3/Mission.h), and [`Descent3/Mission.cpp`](../../Descent3/Mission.cpp).

The workflow also had HOG packaging, dependency and orphan checks, script compilation, and play-from-editor. The integrated HOG dialog, an empty briefing voice callback, disabled menu items, and terrain stubs show that source presence alone does not prove working capability. Intended useful functions enter the completeness ledger; historical defects and duplicated interactions do not.

[`RevivalEditor`](creator-suite.md) starts in Phase 2 against canonical project data and grows with each runtime slice. One native application replaces the old dialogs and utilities with world, game-data, behavior, campaign, presentation, asset, baking, validation, playtest, and publishing workspaces. It has no original-format export or native-module compiler.

## Discarded port plan

The initial plan proposed preserving the C++ gameplay core, retaining OpenGL as a reference and fallback, extracting the existing renderer seam, adding Metal behind `rend_*`, keeping SDL input and audio, and sending portable work upstream.

That plan was coherent for a faithful port and has been rejected for this project. It would make legacy compatibility the permanent organizing principle and create far more maintained code than the selected native rewrite.

The useful output of the historical investigation includes verified retail data, format clues, gameplay and timing behavior, campaign and object scripts, multiplayer and replay semantics, editor and tool inventories, presentation workflows, and evidence that the reference content runs. None of those findings requires retaining the old architecture.

## Use of historical evidence

Consult the old source or executable when a current ledger row has an unanswered question. Record the answer in the importer, behavior translation ledger, functional-completeness ledger, or current design, then return to the Swift product.

Do not create ongoing OpenGL comparisons, dual-engine CI, a compatibility backend, or a second maintained architecture. Local reference screenshots and logs remain ignored and may be discarded after the corresponding native feature has its own tests.
