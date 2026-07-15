# Historical discovery and retained evidence

- Status: historical evidence
- Date investigated: July 12-14, 2026
- Last reconciled: July 15, 2026
- Authority: non-normative; `architecture.md` supersedes all design recommendations from the original discovery

## Purpose

This document records what the source, retail-data, revision-history, and original-development investigation established for the Swift/Metal translation. It supports systematic mapping of source provenance, original content, formats, gameplay behavior, multiplayer, replay, editor capability, resource lifetime, and tool intent.

It is not an instruction to extend or link the C++ engine, preserve OpenGL, extract a renderer interface, maintain SDL, keep an ABI, or seek byte parity. Current product decisions live in [Architecture](architecture.md), [Source translation discipline](source-translation.md), [Content pipeline](content-pipeline.md), and [Roadmap](roadmap.md).

## Source baseline

- Repository: [`DescentDevelopers/Descent3`](https://github.com/DescentDevelopers/Descent3)
- Pinned source commit: `156cba8aafd997d27deb0902ba6026bcdcc1cfaf`
- License: GPL-3.0-or-later in source headers
- Historical release context: community v1.5.0 plus later work on `main`

The source tree contains the game, renderer, platform code, audio, networking, editor source, DALLAS utilities, base campaign scripts, secret and Training scripts, Mercenary scripts, and multiplayer modules. Retail media is not included.

The pinned tree remains available while every relevant file and ledgered game or creator capability is translated, deliberately replaced, or explicitly excluded. It does not compile into or link with any new product target.

It is not a permanent product component. It may move to an archival branch or leave the active checkout only after Phase 10 has closed every relevant source disposition and functional ledger row and no unresolved product question still depends on the active tree.

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

These observations authenticate the owned inputs and establish tested historical comparison paths. They do not prove complete native-import coverage or make the reference executable part of the new runtime.

Full hashes, extraction provenance, and local layout are recorded in [Retail data](retail-data.md).

## Historical development process evidence

The available evidence supports editor/runtime co-development, not the stronger slogan that Descent 3 was completed “editor first.”

The retained source history shows active editor work early, an editor-to-game bridge soon afterward, flight and collision following, and level load/save becoming shared infrastructure. The final editor target compiles almost the entire runtime and shares production mechanisms without using one identical top-level path:

- `Descent3/descent.cpp`, `Descent3/init.cpp`, and `editor/MainFrm.cpp` use shared initialization entry points with explicit editor branches;
- `editor/editorDoc.cpp`, `editor/HFile.cpp`, and `Descent3/LoadLevel.cpp` connect editor documents to the production level functions;
- `editor/TextureGrWnd.cpp` calls the shared low-level `RenderMine` and `RenderTerrain` paths rather than the game's complete top-level presentation function;
- `editor/gameeditor.cpp` and `Descent3/descent.cpp` enter the actual runtime `MainLoop` from the editor and return afterward.

That implementation also contains historical accidents: the editor recompiles runtime files under editor conditionals, switches global modes, tears down and recreates window/input state, sleeps, and uses a temporary GameSave.D3L handoff. The native design preserves shared production world structures, level functions, low-level rendering, and play-and-return outcomes while replacing those workarounds.

Original developer notes reinforce the role of representative content. [Sean Lynn described working with Matt Toschlog and Jason Leighton to build rooms that tested the new engine](https://web.archive.org/web/19990508003016/http://www.outrage.com/notes/sean.html). [Jason Leighton described rewriting terrain after designer use invalidated assumptions](https://web.archive.org/web/19990429214856/http://www.outrage.com/notes/Jason.html). [Luke Schneider described paper planning followed by room construction and the value of small tool investments](https://web.archive.org/web/19981201225823/http://www.outrage.com/notes/luke.html).

The [October 1999 Descent 3 postmortem](https://media.gdcvault.com/GD_Mag_Archives/GDM_October_1999.pdf) describes major engine and renderer replacement after content tools already existed, continued D3Edit/engine/content churn, fragmented external and custom tools, and programmer-centered usability costs. The postmortem explicitly recommends stabilizing the engine before full content production. Combined with the earlier editor/runtime churn and designer-built stress content, our process inference is to prototype the shared loop first, then freeze each proven slice before scaling content.

The project therefore follows this process:

1. translate a coherent source dependency island;
2. exercise it through the permanent player and editor;
3. measure it with representative content on the M4;
4. record one decision;
5. stabilize the slice before expanding campaign breadth.

## Swift engine-code feasibility evidence

The research question is whether Swift is credible for simulation, collision, AI, visibility, render extraction, and the other CPU engine code, not whether Swift wins a general language benchmark. The current evidence supports that use. Swift produces native machine code through its own ownership-aware optimizer and LLVM, and production C and C++ migrations show that low-level work can move to Swift without making the language an automatic bottleneck. Those cases establish feasibility and a method—protect outputs, use direct ownership, profile representative workloads, and optimize the measured path—not a Revival frame-rate prediction. The retained web sources and their limits are indexed in [Primary technical sources](primary-source-index.md#swift-engine-code-and-performance).

The pinned Descent 3 source identifies the first representative CPU risks:

- [`GameFrame`](../../Descent3/GameLoop.cpp) drives source-ordered AI, object, door, goal, player, behavior, audio, multiplayer, and presentation work, while [`ObjDoFrameAll`](../../Descent3/object.cpp) scans the live object set and its movement paths;
- [`do_physics_sim`](../../physics/physics.cpp) permits up to nine player or five non-player response iterations and repeatedly enters [`fvi_FindIntersection`](../../physics/findintersection.cpp), making collision and spatial queries the clearest early simulation hot path;
- room/portal traversal in [`render.cpp`](../../Descent3/render.cpp), terrain search and extraction in [`TerrainSearch.cpp`](../../Descent3/TerrainSearch.cpp) and [`terrainrender.cpp`](../../Descent3/terrainrender.cpp), and the historically marked slow paths in [`lighting.cpp`](../../Descent3/lighting.cpp) require separate CPU extraction and GPU measurements;
- the released limits—1,500 world objects, 400 rooms, and a 256-by-256 terrain grid—bound the stock workload without becoming permanent native creator limits.

The project-specific working assumption is that the original workload is tractable on the M4 with direct Swift value storage; that remains unproven until the native path is measured. The credible Swift risks are unintended copy-on-write of large world collections, ARC-heavy identity graphs, per-frame temporary allocation, runtime exclusivity checks, unspecialized generic or protocol dispatch, and large editor/play-session copies. [Verification](verification.md#performance-method) measures those costs in optimized product paths. A reproducible missed budget or regression earns the smallest local storage or ownership change that fixes it; it does not create a C++ fallback or a second engine.

## Facts carried into the new design

### Legacy content is layered

The original engine resolves loose files and mounted HOG archives through a precedence order. Patch archives override earlier data. `D3Import` must resolve that order once and emit one unambiguous canonical asset for each ID. The runtime will not reproduce the virtual filesystem.

### The renderer has a compact core and several required special paths

The common world paths are flat polygons, base-textured polygons, and base-plus-lightmap polygons with vertex color, fog, alpha, and gamma. They are not the complete rendering surface. The released engine also renders specular faces, reflected room views, scorch decals, procedural fire and water textures, volume-light sampling (not volumetric fog geometry), and several declared blend semantics including saturating blends. Additional stock paths that must not hide under “renderer” include animated textures/VClips and UV sliding, destroyable-face texture swaps, breakable glass and forcefields, per-face `light_multiple`, room pulse/strobe/flicker, light coronas, powerup glow disks, and an explicit keep-or-simplify decision for object lightmaps and dynamic lightmap updates. Historical face-vertex alpha exists in data and physics but the OpenGL render path does not consume it. Bumpmaps and ship environment mapping are dead D3D-only paths and are exclusion candidates. [`Descent3/render.cpp`](../../Descent3/render.cpp), [`Descent3/procedurals.cpp`](../../Descent3/procedurals.cpp), [`Descent3/room_external.h`](../../Descent3/room_external.h), and [`renderer/HardwareOpenGL.cpp`](../../renderer/HardwareOpenGL.cpp) provide the primary evidence.

Original textures include 1555, 4444, and lightmap representations. Metal can express the common path with a small pipeline set and add the special paths directly as their first verified scenes require them. This inventory does not require a render graph or a general material framework.

The old OpenGL path, `rend_*` API, `gpu_*` seam, SDL window ownership, triangle fans, framebuffer scaling, and GLSL shaders are clues for decoding and presentation. None is a product interface.

### The original level world is resident; an eager working set coexists with reachable lazy paging

The historical `mem/` layer chiefly wraps allocation for accounting and diagnostics. The `manage/` page system is a typed content database with network locks, but level activation uses a more concrete lifecycle.

`StartLevel` calls `PageInAllData()`. That path accounts for the player ship, static effects and sounds, every used room-face texture, terrain textures and sky presentation, and dependencies reached through currently placed level objects. The authoritative room, terrain, object, goal, and behavior world is already loaded for the selected level. Reachable bitmap accessors, object initialization, matcens, and Osiris operations can still page models or images later. `FreeThisLevel` and `FlushDataCache` release the level-specific set at exit. The retained GPU backend's pre-upload function is a no-op, so this path is not evidence of complete GPU readiness.

This is a resident authoritative level world with an eager working-set preload plus reachable lazy asset paging. It is not spatial world streaming and does not load the entire installation. The initial native baseline preserves that observable schedule while reading only from a validated canonical package and its current reachable dependency manifest. It does not preserve page locks, memory wrappers, renderer upload caches, legacy free lists, or a general cache hierarchy.

After the complete playable Training Mission and representative large indoor, outdoor, editor, and higher-resolution workloads run on the M4, the project measures startup, transition, memory, and viewport cost. Streaming remains a possible focused amendment if resident loading misses a ratified budget; it is neither banned forever nor prebuilt. [World loading and residency](world-loading.md) records the current decision.

### Original timing is variable

`Descent3/GameLoop.cpp` feeds gameplay systems and `EVT_INTERVAL` the previously measured global `Frametime` while `Gametime` still has its pre-update value. After simulation, rendering, normal events, and frame-cap waiting, `CalcFrameTime()` stores the newly measured duration; `GameFrame` then advances `Gametime` by that new value before later tail work such as sound-frame completion and destroyed-light processing. The static and `InitGame` initialization is 0.1 seconds; `InitFrameTime` is not a per-level 0.1 reset. Nested `StopTime`/`StartTime` calls rebase the clock around pauses. The first native scheduler preserves that handoff with explicit values rather than mutable globals.

`EVT_INTERVAL` is delivered once per historical frame with elapsed-time data. Input ramps, flight, physics, collision, animation, and timers mix rate-based and frame-count behavior, so converting them before a native reference slice works would hide translation errors.

Phase 3 captures those outcomes and chooses one final scheduler: retain bounded explicit variable delta, or translate all current consumers once to a selected fixed tick and delete the variable scheduler. Fixed 120 Hz remains a candidate modernization, not an original behavior or Phase 1 requirement. The product will not retain dual timing modes.

### Flight feel is distributed across input, physics, and collision

The historical 6DOF response is not one acceleration constant. Keyboard input ramps over time for translation and rotation (afterburner is excluded from ramping), simultaneous translational axes sum without normalization (trichording), controller and mouse paths apply their own scaling and deadzones, and collision response includes wall slide and bounce. Linear and rotational drag use per-axis exponential integration of the form `exp(-(drag/mass)·dt)`. [`Descent3/Controls.cpp`](../../Descent3/Controls.cpp), [`physics/physics.cpp`](../../physics/physics.cpp), and [`physics/collide.cpp`](../../physics/collide.cpp) are the primary evidence.

Additional feel-critical mechanisms that must be named in the native contract rather than hidden under “buffet” or “physics”:

- **Afterburner** — separate boost path with fuel drain and recharge ([`Descent3/object.cpp`](../../Descent3/object.cpp));
- **`PF_WIGGLE` ship bob** — sine offset along the ship up-vector that moves the authoritative object through collision checks, distinct from visual **cockpit buffet** ([`physics/physics.cpp`](../../physics/physics.cpp), [`Descent3/cockpit.cpp`](../../Descent3/cockpit.cpp));
- **Turn roll**, **autoleveling**, **mouselook**, **slide/bank remapping**, outdoor **1.3× thrust scalar**, fusion-charge self-kick, player slide speed-preservation, wind, gravity, and damage camera shake.

The native flight contract therefore specifies ramp curves, trichording, exponential drag, rotational drag, thrust, afterburner, turn roll, wiggle versus cockpit buffet with an explicit authority decision, collision slide and bounce, and the other forces above as observable rules. It first captures bounded reference traces through the explicit-delta translation and then converts those accepted contracts once if Phase 3 selects a fixed tick.

Legacy keyboard ramps reset in `InitControls()` and on key release; they do not reset in `SuspendControls()`/`ResumeControls()`. Resetting held-key ramp state on focus loss, pause/resume, load, and control remapping is a **new native rule**, not translated historical behavior.

### Music is an adaptive scripted score

OMF themes contain regions, stream selections, loops, branches, theme roles, and clean transitions. [`music/omflex.cpp`](../../music/omflex.cpp) parses the format and [`music/sequencer.cpp`](../../music/sequencer.cpp) schedules it. Gameplay and DALLAS request region changes through [`Descent3/d3music.cpp`](../../Descent3/d3music.cpp) and [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp); saves preserve a single logical region index in [`Descent3/gamesave.cpp`](../../Descent3/gamesave.cpp).

The declared `tMusicSeqInfo` surface is broader than the active loop: several damage, shield, kill, and mood paths are inactive or commented out. The active `D3MusicSongSelector` requests only idle and death roles; combat switching, where present, is driven by register logic inside the OMF themes. Stream beds are `.osf` containers with ACM payloads, not standalone ACM files. Translation records proven behavior and resolves ambiguity instead of copying dormant fields. The native design is specified in [Adaptive music](adaptive-music.md).

Streamed mission voice and audio taunts share the OSF/`StreamPlay` path ([`Descent3/voice.cpp`](../../Descent3/voice.cpp), [`Descent3/audiotaunts.cpp`](../../Descent3/audiotaunts.cpp)) and are separate capabilities from adaptive music. Ordinary SFX are PCM WAV through sndlib.

### Retail fonts and difficulty are independent systems

The stock game names seven bitmap `.fnt` files across six simultaneous runtime roles. `hihud.fnt` replaces `lohud.fnt` above the historical resolution threshold; briefing, bold briefing, menu, small UI, and large UI use the other five files. [`Descent3/gamefont.cpp`](../../Descent3/gamefont.cpp), [`Descent3/gamefont.h`](../../Descent3/gamefont.h), and [`grtext/grfont.cpp`](../../grtext/grfont.cpp) provide the loading, metrics, kerning, and glyph-pixel evidence. The native importer therefore makes a production or superseded decision for all seven files and converts only selected stock presentation consumers. It does not recreate the resolution switch or use retail fonts for ordinary AppKit chrome.

Difficulty has five named values from Trainee through Insane. The active setting affects specific AI motion and aim, weapon behavior, energy and shield pickup amounts, AI energy drops, and non-scripted generic-object damage; it is not a universal damage multiplier. Solo profiles default to Rookie, multiplayer hosts select the session value, and stock behaviors query it. See [`Descent3/difficulty_external.h`](../../Descent3/difficulty_external.h), [`Descent3/difficulty.h`](../../Descent3/difficulty.h), [`Descent3/AImain.cpp`](../../Descent3/AImain.cpp), [`Descent3/WeaponFire.cpp`](../../Descent3/WeaponFire.cpp), [`Descent3/multisafe.cpp`](../../Descent3/multisafe.cpp), and [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp).

The DALLAS `aObjApplyDamage` comment says damage is difficulty-scaled, but its implementation selects scripted damage while the generic-object damage path excludes scripted damage from scaling. The native translation ledger treats that as an ambiguity to resolve. Unread historical difficulty fields do not become native state merely because they exist in the source.

### Osiris and DALLAS were separate parts of one behavior workflow

Osiris was a native compiled-module runtime, not an editor or bytecode virtual machine. It loaded game, mission, and level modules; bound scripts to objects; dispatched custom, level, mission, and default object events; delivered trigger and level events; managed timers; exposed an engine import table of about 100 bound functions in [`scripts/osiris_import.h`](../../scripts/osiris_import.h); and persisted script-owned state. The core contract is visible in [`Descent3/osiris_dll.h`](../../Descent3/osiris_dll.h) and the module loader in [`Descent3/OsirisLoadandBind.cpp`](../../Descent3/OsirisLoadandBind.cpp).

DALLAS was the graphical event, condition, and action authoring layer. Its schema covered level, object, and trigger ownership with typed references and broad action categories for world objects, players, doors, rooms, triggers, weather, AI, audio, timers, goals, variables, cinematics, and custom behavior. On save, DALLAS generated C++ and message tables, then invoked a compiler to create a native module. The schema and generator live in [`editor/DallasMainDlg.h`](../../editor/DallasMainDlg.h) and [`editor/DallasMainDlg.cpp`](../../editor/DallasMainDlg.cpp). Some campaign sources also contain handwritten code outside the generated tree.

All 48 retained generated campaign sources include a versioned `$$SCRIPT_BLOCK` tree delimited inside the file, and the DALLAS editor can load that structured description back into its visual tree. The scripts CMake list builds 55 modules; the seven without `$$SCRIPT_BLOCK` are reference and utility modules (`AIGame`, `aigame2`, `AIGame3`, `aigame4`, `clutter`, `generic`, `testscript`), not missing campaign levels. `DallasFuncs.cpp` declares 166 global `$$ACTION`, 68 `$$QUERY`, and 25 `$$ENUM` metadata entries (counting `$$ACTION` tags, not only distinct `void a…()` implementations); tagged aliases in `DallasFuncs.h` and level-local custom declarations extend that vocabulary. Handwritten regions use `CUSTOM_SCRIPT_BLOCK_START` / `CUSTOM_SCRIPT_BLOCK_END` markers, not a `$$CUSTOM` tag. This is stronger translation evidence than reverse-engineering generated control flow alone, but it is not complete authority because those custom blocks and other handwritten code sit outside the generated tree.

A nonshipping draft extractor may read those structured blocks and metadata and emit recovered structure plus unresolved-evidence reports. A human reviews generated, custom, handwritten, authority, timing, and interval semantics before accepting a native translation. The extractor is bounded research upstream of the product; it is not part of D3Import, the editor, or any shipping target.

The native behavior replacement begins with working canonical direct typed Swift translations. Version 1.0 creator authoring must provide a reusable human-authored model for the evidenced DALLAS events, values, conditions, queries, commands, timers, state, functions, composition, and debugging without requiring Swift or generated-file editing, loading DLLs, preserving the Osiris ABI, generating C++, or permitting native code in packages. Working chains select its representation and one executor through the evidence gate in [Behavior translation and authoring](behavior-system.md).

The pinned GPL community commit is the normative baseline for stock behavior because it is inspectable and supplied the 55 native reference modules used by the successful M4 reference run. Retail 1.4 content supplies media, identifiers, and comparison evidence. Retail DLL behavior is ambiguity evidence only, and the new product never imports or executes those DLLs. Known defects are not preserved automatically; each deliberate semantic correction is recorded in the translation ledger.

### In-game cinematics are behavior-driven gameplay

The runtime cinematic system is separate from briefing screens and movie playback. It drives camera and target paths, level intros and endings, text, letterboxing, fades, player-control policy, AI policy, interruption, and completion. Stock behaviors invoke it through cinematic start and stop actions, so campaign translation, save and replay, rendering, application input, and creator authoring all depend on one logical sequence contract. [`Descent3/gamecinematics.cpp`](../../Descent3/gamecinematics.cpp), [`Descent3/gamecinematics_external.h`](../../Descent3/gamecinematics_external.h), and [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp) provide the primary evidence.

Hard-coded level intro and ending recipes appear as five `CANNED_*` types in [`Descent3/gamecinematics_external.h`](../../Descent3/gamecinematics_external.h) and dispatch through `Cinematic_StartCanned()` in C++. The native counterpart is a purpose-built typed cinematic sequence, not a general timeline engine and not a legacy canned-cinematic interpreter.

### Player presentation extends beyond HUD and TelCom

The released game has a separate three-dimensional automap with discovery state, full-map effects, and marker display in [`Descent3/TelComAutoMap.cpp`](../../Descent3/TelComAutoMap.cpp). [`Descent3/cockpit.cpp`](../../Descent3/cockpit.cpp) implements an animated cockpit distinct from the HUD. [`Descent3/SmallViews.cpp`](../../Descent3/SmallViews.cpp) and [`Descent3/GameLoop.cpp`](../../Descent3/GameLoop.cpp) cover rear, GuideBot, guided-weapon, marker, and related auxiliary views. The GuideBot command menu is its own UI shell with multiplayer round-trip ([`Descent3/buddymenu.cpp`](../../Descent3/buddymenu.cpp)).

Post-level Pilot Performance Review screens, credits with their own music, intro movies, per-level loading art, manual demo playback with a user-selected repeat loop, death-camera behavior, and savegame thumbnails are distinct presentation capabilities ([`Descent3/screens.cpp`](../../Descent3/screens.cpp), [`Descent3/credits.cpp`](../../Descent3/credits.cpp), [`Descent3/menu.cpp`](../../Descent3/menu.cpp), [`Descent3/demofile.cpp`](../../Descent3/demofile.cpp), [`Descent3/gamesave.cpp`](../../Descent3/gamesave.cpp)). The pinned source does not show an unattended menu-idle attract mode, so that related idea is preserved as `F-004` rather than folded into the working demo capability. Ambient sound patterns ([`Descent3/ambient.cpp`](../../Descent3/ambient.cpp)) are separate from ambient life; the pinned ambient-life runtime is an empty stub ([`Descent3/aiambient.cpp`](../../Descent3/aiambient.cpp) `DoFrame(void) {}`) while editor authoring still serializes data. That incomplete idea is preserved as `F-001` in [Future opportunities](future-opportunities.md) rather than mislabeled as working 1.0 behavior.

Player markers persist messages and positions. The gameplay-level force-feedback system in [`Descent3/D3ForceFeedback.cpp`](../../Descent3/D3ForceFeedback.cpp) shows intended effects even though the retained POSIX backend is a stub. Multiplayer also exchanges player-selected pictures (stock IDs only over the network), ship logos (file transfer, forced to 64×64), and four OSF audio taunts per player. These are functional and security requirements for native counterparts, not reasons to preserve legacy media files, codecs, or packet layouts.

Rooms also carry functional roles beyond geometry. [`Descent3/room_external.h`](../../Descent3/room_external.h) declares fuel-center, goal, secret, external, waypoint, and other special-purpose flags; [`Descent3/object.cpp`](../../Descent3/object.cpp) applies refueling, capping, sound, AI notification, secret, and waypoint behavior. The native world model represents intended roles as typed data rather than preserving a legacy bitmask API.

[`Descent3/GameCheat.cpp`](../../Descent3/GameCheat.cpp) implements intended cheat, easter-egg, and diagnostic effects with different policies: fifteen release cheat constants, twenty-four lamer/decoy passwords, and a few legacy demo/OEM diagnostic strings. Several presentation and diagnostic commands remain available in multiplayer; gameplay cheats below the multiplayer guard are rejected, and only some commands mark the profile as cheated or zero score. Functional completeness therefore requires a per-command native effect or explicit user-approved exclusion, solo/multiplayer policy, cheated-state consequence, and authoritative replay decision. It does not require the old encrypted input strings or a general shell or console. A renderer-specific command receives an equivalent native diagnostic or an explicit user-approved exclusion; it does not force preservation of a dead rendering mechanism.

### Original saves expose implementation layout

Historical save code mixes explicit fields with raw structure bytes and `sizeof` checks for players, objects, AI, effects, and other state. Osiris modules append their own state.

The new engine writes a new canonical snapshot and does not import or export historical saves.

### Original multiplayer is a separate old architecture

The source implements server and client roles, reliable and unreliable packet paths, custom reliability, game-time exchange, object updates, and native game modules. These mechanisms are evidence for functional behavior, game modes, lifecycle, presentation, and failure cases. They are not the native design.

Stock playable modes under [`netgames/`](../../netgames/) are Anarchy, Team Anarchy, Hyper-Anarchy, Robo-Anarchy, CTF, Entropy, Hoard, Monsterball, and **campaign co-op** ([`netgames/coop/coop.cpp`](../../netgames/coop/coop.cpp)): co-op runs campaign missions with robots, GuideBot allowed, waypoint respawn, and a historical 4-player hard cap under the multiplayer authority. DMFC supplies a large mode-owned HUD, stats, and admin surface that native mode scopes must replace deliberately.

Historical discovery stacks include Direct TCP/IP LAN ([`netcon/lanclient/`](../../netcon/lanclient/)), Parallax Online / mtclient lobby chat, game tracker, and pilot rankings ([`netcon/mtclient/`](../../netcon/mtclient/)), Descent3 Online ([`netcon/descent3onlineclient/`](../../netcon/descent3onlineclient/)), and GameSpy heartbeats ([`Descent3/gamespy.cpp`](../../Descent3/gamespy.cpp)). Join-time HTTP mission auto-download ([`Descent3/mission_download.cpp`](../../Descent3/mission_download.cpp)) is a distinct content-acquisition path. The Phase 0 study preserves these outcomes while determining which have an affordable native 2026 counterpart; it does not assume a project-operated relay, silently delete the ideas, or keep a legacy reader.

The host UI also exposed three sync models — strict client/server, pseudo peer-peer position broadcast (`NF_PEER_PEER`), and permissable server-authorized firing (`NF_PERMISSABLE`). The native prediction and reconciliation design supersedes all three; that replacement is a recorded semantic decision because it changes weapon feel under latency.

The functional surface also includes public, team, and private HUD text chat; game-mode commands entered through a bounded message path; and local and remote dedicated-host administration. [`Descent3/hudmessage.cpp`](../../Descent3/hudmessage.cpp), [`Descent3/multi.cpp`](../../Descent3/multi.cpp), and [`Descent3/dedicated_server.cpp`](../../Descent3/dedicated_server.cpp) provide that evidence. The native product separates ordinary chat from typed game-affecting commands and exposes one typed host-command set through local and authenticated encrypted administration. It does not preserve Telnet, raw chat execution, a shell, or arbitrary process execution.

[`lib/d3events.h`](../../lib/d3events.h) also separates historical game-side and client-side behavior events. Translation must classify each required event as authoritative simulation, replicated presentation, local application input or UI, or an explicitly excluded obsolete mechanism. The `CLIENT` name alone does not decide authority, persistence, replay, or network safety, and the native product does not preserve the historical numeric event IDs.

The retained source declares 32 network/player slots. Live roam and piggyback observer modes remain connected and consume one of those slots. A listen host occupies one human slot. The historical dedicated server occupies slot 0, leaving at most 31 human slots; removing that cost in a native no-window authority would be a deliberate modernization rather than a source claim. Individual modes may impose smaller limits; campaign co-op has a source-evidenced four-player hard cap. On the recorded SDK, GameKit reports a 16-participant maximum for both peer-to-peer and hosted `GKMatch` sessions, and it did not by itself solve reachability for this project's custom dedicated host. That snapshot is candidate evidence for the 2026 study, not a permanent transport rejection.

The earlier planning pass selected Network-framework QUIC, Bonjour, inner CryptoKit records, and a project-operated opaque relay. The approved July 15 amendment reclassifies that topology as a superseded research candidate because the project cannot assume the recurring cost and operational ownership of an always-on service. The required outcome remains affordable native LAN and Internet multiplayer. Phase 0 now compares current direct, player-hosted, community-operated, platform-provided, and third-party-supported approaches; Phase 9 selects one topology against the final simulation and then fixes the exact Network, CryptoKit, reachability, security, privacy, abuse, deployment, cost, and outage contracts it actually needs.

Multiplayer, dedicated hosting, multiplayer authoring, replay, and an affordable native Internet path are committed revival capabilities. Operating a project-owned relay is not. Phase 9 implements the one direction selected from the 2026 research against the working final simulation, security rules, and verification matrices. Any determinism requirement is fixed from the selected scheduler, replay, and network evidence rather than assumed in advance. The native route does not inherit the original protocol, packet layouts, reliability layer, module ABI, or live interoperability.

### The original creator surface was much larger than a level viewer

The released `editor/` application is Windows-only and tightly coupled to the old engine, level representation, page database, native scripting workflow, and MFC UI. A literal platform-shell port would restore the wrong ownership and APIs. Its shared production world structures, level functions, low-level renderer, actual runtime play path, and complete functional inventory are primary translation evidence.

The world editor covered rooms, faces, vertices, portals, bridges, joining, attaching, snapping, combining, triangulation, indoor and terrain workflows, reusable rooms and ORF palettes, materials and UVs, objects, starts, cameras, waypoints, sounds, doorways, triggers, paths, navigation, matcens, goals, megacells, ambient life, lighting and radiosity baking, fog, validation, repair, statistics, level notes, table-file and page lock/check-in UI, DALLAS and Osiris script compile, a standalone briefing editor, HOG tools, play-from-editor, and 3DS room import. It also exposed textured and wireframe views, navigation and focus commands, view cameras, autosave, and crash restoration. The command surface begins in [`editor/editor.rc`](../../editor/editor.rc) with IDs in [`editor/resource.h`](../../editor/resource.h); serialized level coverage is visible in [`Descent3/LoadLevel.h`](../../Descent3/LoadLevel.h). No historical “scale room” or general multi-object property-edit command is required evidence; object multi-edit is limited.

Navigation was not merely a list of editor waypoints. The source contains room-and-terrain connectivity plus a three-dimensional node-and-edge graph with clearance, runtime routing, hand-authored paths, and editing tools. The first native translation preserves the region, node, clearance, routing, steering, blockage, and recovery semantics exercised by real routes. The final native structure is ratified after those routes work rather than predesigned as a generic navigation framework. Hand-authored paths remain separate for cinematics, patrols, set pieces, and exact orientation.

The old lighting tools projected secondary UVs for editor faces and `SqueezeLightmaps()` packed a sequence of padded 128-by-128 pages, with no per-room cap beyond the global 65,534 lightmap and lightmap-info handle limits. The native importer first preserves that page, UV2, and sampling meaning closely enough to reproduce reference images. A whole-retail area report and real editor bake then inform one simpler native layout. A single 1024-square room atlas is a hypothesis to measure, not an early schema constraint.

The historical 3DS route is not retained. Blender is the recommended bulk-geometry authoring tool, and Model I/O USD is the first planned-product DCC ingress. USD import and reimport normalize units, axes, winding, room and portal semantics, UVs, and provenance into canonical editable geometry. The editor never carries USD as its runtime world model and does not export the canonical world back to legacy formats. A second real DCC input is added only for a demonstrated creator workflow and does not justify a generic interchange abstraction.

Dedicated gameplay tools handled triggers, paths and navigation graphs, goals, matcens, indoor and terrain radiosity, lightmaps, volumetrics, fog, coronas, and animated lighting. Terrain controls included sky and horizon colors, stars, satellites, rotation, halos, atmosphere, and environmental audio. The suite also edited textures and procedural materials, robots, powerups, buildings, clutter, ships, weapons, doors, sounds, ambient patterns, lights, physics, animation, AI, death, inventory, effects, object archetypes, fonts, terrain groupings, and generic content references. [`editor/CMakeLists.txt`](../../editor/CMakeLists.txt) and [`manage/CMakeLists.txt`](../../manage/CMakeLists.txt) provide category-level inventories.

The Briefing Editor authored multi-screen layouts with text, bitmaps, movies, sound, buttons, timing, effects, colors, fonts, navigation, conditional mission flags, preview, and save and load. Campaign manifests carried levels, branches, secrets, intro and ending presentation, briefings, music, progress screens, training and multiplayer declarations, default and allowed ships, and final markers. The historical `.msn` `SHIP` keyword is mission-wide only; `LVLFLAG_SHIPSELECT` is defined in [`Descent3/Mission.h`](../../Descent3/Mission.h) but never set or read, so per-level ship selection is not a working historical capability and is preserved as `F-002` rather than promoted into 1.0. Package-style per-level dependencies are likewise a new-native model, not a historical manifest field. See [`editor/BriefEdit.cpp`](../../editor/BriefEdit.cpp), [`Descent3/Mission.h`](../../Descent3/Mission.h), and [`Descent3/Mission.cpp`](../../Descent3/Mission.cpp).

The workflow also had HOG packaging, dependency and orphan checks, script compilation, and play-from-editor. The integrated HOG dialog, an empty briefing voice callback, disabled menu items, and terrain stubs show that source presence alone does not prove working capability. Intended useful functions enter the completeness ledger; historical defects and duplicated interactions do not.

[`RevivalEditor`](creator-suite.md) starts in Phase 1 with the complete canonical Training `Level` focused on one selected acceptance room and grows with every runtime slice. One native application translates the useful world, game-data, behavior, campaign, presentation, asset, baking, validation, playtest, and publishing semantics without original-format export or a native-module compiler.

## Discarded port plan

The initial plan proposed preserving the C++ gameplay core, retaining OpenGL as a reference and fallback, extracting the existing renderer seam, adding Metal behind `rend_*`, keeping SDL input and audio, and sending portable work upstream.

That plan was coherent for a permanent C++ source port and has been rejected for this project. It would make legacy APIs and compatibility the product architecture.

That rejection does not reject semantic translation into Swift. The useful output includes verified retail data, format knowledge, gameplay and timing behavior, campaign and object scripts, multiplayer and replay semantics, editor/runtime relationships, tool inventories, presentation workflows, and evidence that the reference content runs. Those findings now drive dependency-ordered native implementation while legacy APIs and binaries remain outside the product.

## Use of historical evidence

Use the old source systematically to map each current dependency island and consult the executable when an observable result remains ambiguous. Record file dispositions, answers, and deliberate differences in the source-translation ledger, importer, behavior record, functional-completeness ledger, or current design, then implement the Swift path.

Do not create permanent OpenGL comparisons, dual-engine CI, a compatibility backend, or a second maintained architecture. Local reference screenshots and logs remain ignored and may be archived or discarded after the corresponding native feature has accepted tests and evidence.
