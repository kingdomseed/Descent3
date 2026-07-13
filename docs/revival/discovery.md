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

### Legacy working-set machinery is not a native subsystem

The historical `mem/` layer chiefly wraps allocation for accounting and diagnostics. The `manage/` page system is a typed content database with network locks, while level startup separately loads the selected dependency set and level exit releases it. The renderer also contains texture remap and upload caches, triangle-fan paths, and aggressive portal-era clipping. The 256 by 256 terrain carries a large generated LOD implementation.

These findings do not define the native resource model. The accepted architecture keeps the complete authoritative gameplay spine resident but streams immutable GPU presentation payloads through fixed cells: one indoor room or one 32-by-32-quad terrain block. It uses orientation-independent spatial camera envelopes, a fixed lead-time-derived prefetch shell, direct Metal I/O, one dynamic world residency set, and full authored-resolution terrain cells; current room/portal/frustum traversal decides drawing rather than residency. It does not preserve the legacy page database, upload cache, terrain LOD, or memory wrappers and does not replace them with a general pager or cache framework. [World streaming](world-streaming.md) records the native decision.

### Original timing is variable

`Descent3/GameLoop.cpp` derives global `Frametime` from elapsed wall-clock milliseconds and feeds that value through gameplay systems once per frame. The new project intentionally replaces this with one fixed 120 Hz simulation. There is no variable-time compatibility mode.

`EVT_INTERVAL` is also delivered once per historical frame with elapsed-time data. Stock translation therefore needs one project-wide mapping rule rather than a per-level guess. Simulation work becomes fixed-tick logic with tick-native rates and timers; equivalent polling becomes typed events; presentation-only work stays outside authoritative state. The pinned reference engine defaults to a 60 frames-per-second cap, so a 120 Hz simulation is approximately twice its default interval dispatch rate. Generated source size alone does not establish the operation cost of an interval handler.

### Flight feel is distributed across input, physics, and collision

The historical 6DOF response is not one acceleration constant. Keyboard input ramps over time, simultaneous translational and rotational axes combine, controller and mouse paths apply their own scaling and drag, and collision response includes slide and bounce behavior. [`Descent3/Controls.cpp`](../../Descent3/Controls.cpp), [`physics/physics.cpp`](../../physics/physics.cpp), and [`physics/collide.cpp`](../../physics/collide.cpp) are the primary evidence.

The native flight contract therefore specifies ramp curves, trichording, drag, rotational drag, thrust, collision slide, and bounce as observable rules. It does not copy the variable-time loop, but it does capture bounded reference traces from the old executable and turns accepted behavior into fixed-tick tests before implementing the native path.

### Music is an adaptive scripted score

OMF themes contain regions, stream selections, loops, branches, theme roles, and clean transitions. [`music/omflex.cpp`](../../music/omflex.cpp) parses the format and [`music/sequencer.cpp`](../../music/sequencer.cpp) schedules it. Gameplay and DALLAS request region changes through [`Descent3/d3music.cpp`](../../Descent3/d3music.cpp) and [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp); saves preserve logical region state in [`Descent3/gamesave.cpp`](../../Descent3/gamesave.cpp).

The declared `tMusicSeqInfo` surface is broader than the active loop: several damage, shield, kill, and mood paths are inactive or commented out. Translation records proven behavior and resolves ambiguity instead of copying dormant fields. The native design is specified in [Adaptive music](adaptive-music.md).

### Retail fonts and difficulty are independent systems

The stock game names seven bitmap `.fnt` files across six simultaneous runtime roles. `hihud.fnt` replaces `lohud.fnt` above the historical resolution threshold; briefing, bold briefing, menu, small UI, and large UI use the other five files. [`Descent3/gamefont.cpp`](../../Descent3/gamefont.cpp), [`Descent3/gamefont.h`](../../Descent3/gamefont.h), and [`grtext/grfont.cpp`](../../grtext/grfont.cpp) provide the loading, metrics, kerning, and glyph-pixel evidence. The native importer therefore makes a production or superseded decision for all seven files and converts only selected stock presentation consumers. It does not recreate the resolution switch or use retail fonts for ordinary AppKit chrome.

Difficulty has five named values from Trainee through Insane. The active setting affects specific AI motion and aim, weapon behavior, energy and shield pickup amounts, AI energy drops, and non-scripted generic-object damage; it is not a universal damage multiplier. Solo profiles default to Rookie, multiplayer hosts select the session value, and stock behaviors query it. See [`Descent3/difficulty_external.h`](../../Descent3/difficulty_external.h), [`Descent3/difficulty.h`](../../Descent3/difficulty.h), [`Descent3/AImain.cpp`](../../Descent3/AImain.cpp), [`Descent3/WeaponFire.cpp`](../../Descent3/WeaponFire.cpp), [`Descent3/multisafe.cpp`](../../Descent3/multisafe.cpp), and [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp).

The DALLAS `aObjApplyDamage` comment says damage is difficulty-scaled, but its implementation selects scripted damage while the generic-object damage path excludes scripted damage from scaling. The native translation ledger treats that as an ambiguity to resolve. Unread historical difficulty fields do not become native state merely because they exist in the source.

### Osiris and DALLAS were separate parts of one behavior workflow

Osiris was a native compiled-module runtime, not an editor or bytecode virtual machine. It loaded game, mission, and level modules; bound scripts to objects; dispatched custom, level, mission, and default object events; delivered trigger and level events; managed timers; exposed a large engine function table; and persisted script-owned state. The core contract is visible in [`Descent3/osiris_dll.h`](../../Descent3/osiris_dll.h), the module loader in [`Descent3/OsirisLoadandBind.cpp`](../../Descent3/OsirisLoadandBind.cpp), and the imported engine surface in [`scripts/osiris_import.h`](../../scripts/osiris_import.h).

DALLAS was the graphical event, condition, and action authoring layer. Its schema covered level, object, and trigger ownership with typed references and broad action categories for world objects, players, doors, rooms, triggers, weather, AI, audio, timers, goals, variables, cinematics, and custom behavior. On save, DALLAS generated C++ and message tables, then invoked a compiler to create a native module. The schema and generator live in [`editor/DallasMainDlg.h`](../../editor/DallasMainDlg.h) and [`editor/DallasMainDlg.cpp`](../../editor/DallasMainDlg.cpp). Some campaign sources also contain handwritten code outside the generated tree.

All 48 retained generated campaign sources include a versioned `$$SCRIPT_BLOCK` tree delimited inside the file, and the DALLAS editor can load that structured description back into its visual tree. `DallasFuncs.cpp` declares 166 global `$$ACTION`, 68 `$$QUERY`, and 25 `$$ENUM` metadata entries; tagged aliases in `DallasFuncs.h` and level-local custom declarations extend that vocabulary. This is stronger translation evidence than reverse-engineering generated control flow alone, but it is not complete authority because custom script blocks and handwritten code may sit outside the generated tree.

A nonshipping draft extractor reads those structured blocks and metadata and emits noncanonical draft graphs plus unresolved-evidence reports. A human reviews generated, custom, handwritten, authority, timing, and interval semantics before accepting typed stock source into `StockBehaviorCatalog`. The extractor is a bounded research tool upstream of the product; it is not part of `D3Import`, the editor, or any shipping target.

The new typed [`BehaviorGraph`](behavior-system.md) and compiled `BehaviorProgram` replace this complete workflow. They retain events, values, conditions, queries, commands, timers, state, functions, debugging, and creator extensibility without loading DLLs, preserving the Osiris ABI, generating C++, or permitting native code in packages.

The pinned GPL community commit is the normative baseline for stock behavior because it is inspectable and supplied the 55 native reference modules used by the successful M4 smoke run. Retail 1.4 content supplies media, identifiers, and comparison evidence. Retail DLL behavior is ambiguity evidence only, and the new product never imports or executes those DLLs. Known defects are not preserved automatically; each deliberate semantic correction is recorded in the translation ledger.

### In-game cinematics are behavior-driven gameplay

The runtime cinematic system is separate from briefing screens and movie playback. It drives camera and target paths, level intros and endings, text, letterboxing, fades, player-control policy, AI policy, interruption, and completion. Stock behaviors invoke it through cinematic start and stop actions, so campaign translation, save and replay, rendering, application input, and creator authoring all depend on one logical sequence contract. [`Descent3/gamecinematics.cpp`](../../Descent3/gamecinematics.cpp), [`Descent3/gamecinematics_external.h`](../../Descent3/gamecinematics_external.h), and [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp) provide the primary evidence.

The native counterpart is a purpose-built typed cinematic sequence, not a general timeline engine and not a legacy canned-cinematic interpreter.

### Player presentation extends beyond HUD and TelCom

The released game has a separate three-dimensional automap with discovery state, full-map effects, and marker display in [`Descent3/TelComAutoMap.cpp`](../../Descent3/TelComAutoMap.cpp). [`Descent3/cockpit.cpp`](../../Descent3/cockpit.cpp) implements an animated cockpit distinct from the HUD. [`Descent3/SmallViews.cpp`](../../Descent3/SmallViews.cpp) and [`Descent3/GameLoop.cpp`](../../Descent3/GameLoop.cpp) cover rear, GuideBot, guided-weapon, marker, and related auxiliary views.

Player markers persist messages and positions. The gameplay-level force-feedback system in [`Descent3/D3ForceFeedback.cpp`](../../Descent3/D3ForceFeedback.cpp) shows intended effects even though the retained POSIX backend is a stub. Multiplayer also exchanges player-selected pictures, ship logos, and compressed audio taunts. These are functional and security requirements for native counterparts, not reasons to preserve legacy media files, codecs, or packet layouts.

Rooms also carry functional roles beyond geometry. [`Descent3/room_external.h`](../../Descent3/room_external.h) declares fuel-center, goal, secret, external, waypoint, and other special-purpose flags; [`Descent3/object.cpp`](../../Descent3/object.cpp) applies refueling, capping, sound, AI notification, secret, and waypoint behavior. The native world model represents intended roles as typed data rather than preserving a legacy bitmask API.

[`Descent3/GameCheat.cpp`](../../Descent3/GameCheat.cpp) implements intended cheat, easter-egg, and diagnostic effects with different policies. Several presentation and diagnostic commands remain available in multiplayer; gameplay cheats below the multiplayer guard are rejected, and only some commands mark the profile as cheated or zero score. Functional completeness therefore requires a per-command native effect or explicit user-approved exclusion, solo/multiplayer policy, cheated-state consequence, and authoritative replay decision. It does not require the old encrypted input strings or a general shell or console. A renderer-specific command receives an equivalent native diagnostic or an explicit user-approved exclusion; it does not force preservation of a dead rendering mechanism.

### Original saves expose implementation layout

Historical save code mixes explicit fields with raw structure bytes and `sizeof` checks for players, objects, AI, effects, and other state. Osiris modules append their own state.

The new engine writes a new canonical snapshot and does not import or export historical saves.

### Original multiplayer is a separate old architecture

The source implements server and client roles, reliable and unreliable packet paths, custom reliability, game-time exchange, object updates, and native game modules. These mechanisms are evidence for functional behavior, game modes, lifecycle, presentation, and failure cases. They are not the native design.

The functional surface also includes public, team, and private HUD text chat; game-mode commands entered through a bounded message path; and local and remote dedicated-host administration. [`Descent3/hudmessage.cpp`](../../Descent3/hudmessage.cpp), [`Descent3/multi.cpp`](../../Descent3/multi.cpp), and [`Descent3/dedicated_server.cpp`](../../Descent3/dedicated_server.cpp) provide that evidence. The native product separates ordinary chat from typed game-affecting commands and exposes one typed host-command set through local and authenticated encrypted administration. It does not preserve Telnet, raw chat execution, a shell, or arbitrary process execution.

[`lib/d3events.h`](../../lib/d3events.h) also separates historical game-side and client-side behavior events. Translation must classify each required event as authoritative simulation, replicated presentation, local application input or UI, or an explicitly excluded obsolete mechanism. The `CLIENT` name alone does not decide authority, persistence, replay, or network safety, and the native product does not preserve the historical numeric event IDs.

The retained source declares 32 connected human slots. Live roam and piggyback observer modes remain connected and consume one of those slots. The historical dedicated server also consumed a slot, but the native no-window authority and relay do not. A listen host remains one of the connected humans. On the recorded SDK, GameKit reports a 16-participant maximum for both peer-to-peer and hosted `GKMatch` sessions, and it does not solve reachability for this project's custom dedicated host. GameKit is therefore not the product transport or matchmaking layer.

The selected native design uses Network-framework QUIC for 2–32 connected humans. Bonjour discovers direct LAN hosts using the same session messages. Public Internet hosts and clients make outbound connections to a project-operated discovery, authorization, and opaque-relay service; there is no direct-IP Internet path, ICE, STUN, TURN, or inbound-router workflow. Reliable control uses QUIC streams and time-sensitive state uses QUIC datagrams. Because those QUIC legs terminate at the relay, one inner CryptoKit record protocol supplies authority proof, pairwise key agreement, authenticated encryption, sequence and replay rules, and the same payload contract on LAN. `RevivalRelay` receives no session key and never owns simulation or content.

Multiplayer, dedicated hosting, multiplayer authoring, replay, and relay operation are committed revival capabilities. Phase 9 implements this fixed design against the deterministic simulation, security rules, and verification matrices. It does not inherit the original protocol, packet layouts, reliability layer, module ABI, or live interoperability.

### The original creator surface was much larger than a level viewer

The released `editor/` application is Windows-only and tightly coupled to the old engine, level representation, page database, native scripting workflow, and MFC UI. Porting it would restore the wrong architecture. Its functional inventory is still mandatory evidence.

The world editor covered rooms, faces, vertices, portals, bridges, joining, attaching, snapping, combining, triangulation, indoor and terrain workflows, reusable rooms, materials and UVs, objects, starts, cameras, waypoints, sounds, doors, triggers, paths, navigation, matcens, goals, ambient life, lighting, fog, validation, repair, statistics, and 3DS room import. It also exposed textured and wireframe views, navigation and focus commands, view cameras, autosave, and crash restoration. The command surface begins in [`editor/editor.rc`](../../editor/editor.rc); serialized level coverage is visible in [`Descent3/LoadLevel.h`](../../Descent3/LoadLevel.h).

Navigation was not merely a list of editor waypoints. The source contains room-and-terrain connectivity plus a three-dimensional node-and-edge graph with clearance, runtime routing, hand-authored paths, and editing tools. The native counterpart is one purpose-built two-level volumetric graph: stable region connectivity and bounded sparse 3D nodes, deterministic CPU baking and A*, local steering, dynamic edge invalidation, and bounded replanning. Hand-authored paths remain separate for cinematics, patrols, set pieces, and exact orientation.

The old lighting tools projected secondary UVs for editor faces and packed padded 128-by-128 lightmap atlases. The native editor uses deterministic planar charts for native planar faces and exactly one nonmipmapped 1024-by-1024 room-local atlas with a two-texel dilated gutter between charts. Arbitrary USD room geometry must arrive with UV2 that passes the same normalized-bounds, overlap, and fixed-atlas gutter rules; invalid input is rejected instead of invoking a general unwrap system. One deterministic CPU publish solve emits exact canonical texels for the pinned bake toolchain and revision.

The historical 3DS route is not retained. Blender is the recommended bulk-geometry authoring tool, and Model I/O USD is the sole planned-product DCC ingress. USD import and reimport normalize units, axes, winding, room and portal semantics, UVs, and provenance into canonical editable geometry. The editor never carries USD as its runtime world model and does not export the canonical world back to legacy formats. A second DCC format requires an explicit architecture amendment.

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
