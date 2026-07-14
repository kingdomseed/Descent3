# Descent 3 revival

This project is building a complete Apple-native revival of Descent 3: the game, its campaigns and multiplayer capabilities, and the tools needed to create new levels, systems, behaviors, presentation, and campaigns.

The route is a source-led native translation, not a greenfield design exercise and not a shipping C++ port. We translate the pinned released source in coherent dependency order, keep every relevant file accounted for, and preserve observable game and creator semantics before deliberately modernizing them. The finished product contains no legacy runtime.

## Product direction

The shipping product uses:

- Swift 6.3 for project-owned host code;
- MSL and direct Metal 4 for graphics;
- AppKit and MetalKit for game and editor windows;
- GameController for controller input;
- AVFoundation and AVAudioEngine for media and sound;
- Model I/O for the first native USD creator ingress;
- Network and CryptoKit for native multiplayer;
- Apple Silicon arm64 and macOS 26 or later;
- one canonical content model shared by runtime, editor, saves, replay, multiplayer, and publishing.

There is one renderer, one active simulation scheduler, one active level-lifetime path, and one shared editor/player world. OpenGL, SDL, MFC, DLL interfaces, original saves and packets, and retail runtime formats do not survive as product layers.

## Translation before redesign

The released C++ source is the initial specification for:

- update order, elapsed-time use, input, physics, collision, AI, weapons, and objects;
- room, portal, terrain, visibility, lighting, effects, and presentation;
- per-level dependency discovery, eager working-set paging, reachable lazy paging, activation, and release;
- D3Edit inspection, mutation, level I/O, rendering, and play-from-editor;
- DALLAS, Osiris, campaign, multiplayer, replay, and utility capability.

Every relevant source file receives a disposition, but native files and types follow clear Swift ownership rather than legacy file boundaries. Platform APIs, global mode switching, duplicated compilation, page-database locks, defensive branch forests, dead code, and historical workarounds are replaced or excluded with evidence.

[Source translation discipline](docs/revival/source-translation.md) defines the loop: trace, capture, test, translate, run, record differences, simplify, and close the file accounting.

## First implementation

The first native world starts from the original game's operational baseline:

- D3Import converts the complete Training D3L world plus every asset reachable by the currently translated path into checked canonical content;
- RevivalCore constructs the complete resident level world;
- a direct PageInAllData-style pass eagerly prepares the evidenced working set, while later source-reachable presentation assets load only from the canonical package and then remain resident;
- the player and editor use the same world types, loader, simulation, and renderer, with separate owned document and play-session values;
- exit waits for final GPU use and releases the level resources through one owner.

The released engine did not prove a complete GPU-ready dependency closure at activation: bitmap, object, matcen, and Osiris paths could page additional assets later, and the retained GPU pre-upload hook is a no-op. The canonical-only runtime is a deliberate one-way-content strengthening. Its package contains the complete level topology and every dependency reachable through the currently translated product path, then expands when a new behavior path becomes real; eager-versus-lazy preparation still follows the source until measurement supports a change.

This is the concrete current implementation. It is not “no streaming ever.” Spatial streaming is considered only after complete Training and representative large indoor, outdoor, editor, and higher-resolution workloads are measured on the M4. A later amendment must replace the resident mechanism rather than add a permanent second mode. [World loading and residency](docs/revival/world-streaming.md) defines that gate.

The first scheduler preserves the historical old/new timing handoff explicitly. Frame systems and `EVT_INTERVAL` consume the previous `Frametime` and pre-update `Gametime`; after cap waiting, `CalcFrameTime` stores the new duration, then `GameFrame` advances `Gametime` before the remaining tail work. It preserves the static/`InitGame` 0.1-second initialization and nested pause/rebase behavior without retaining mutable globals. After flight, collision, interval events, and animation have native reference evidence, Phase 3 chooses and completes one final timing model. Fixed 120 Hz remains a candidate, not a Phase 1 fact, and the product will not keep variable and fixed modes in parallel.

## Editor and runtime together

RevivalEditor begins in Phase 1, not after an engine foundation is designed in isolation. The first integrated slice loads the complete imported Training Level in both applications, focuses one acceptance room, derives an editable complete-level project value from the read-only base, renders it through the same Metal path, performs one real mutation with undo, saves and reopens, enters the shipping simulation with a disposable play-session copy, and returns to the document.

This does not claim that Descent 3 was historically built by completing its editor first. The evidence shows editor and runtime co-development around shared initialization entry points with editor branches, production world and level functions, low-level rendering, and the actual runtime loop during editor-hosted play. We are following that useful integration pattern while replacing the Windows and MFC machinery.

The editor grows with the game into a human-first AppKit creator suite. MCP, headless authoring, training capture, telemetry, and agent-only workflows remain outside the current roadmap until the complete human product ships.

## Functional completeness

The revival preserves capability without blindly preserving machinery. Every required player-facing and creator-facing feature receives a modern native counterpart. KISS means fewer concepts and paths, not fewer tools or a smaller game.

A gameplay feature is complete when the runtime can execute it, the editor can author it where applicable, validation can reject broken forms, play-in-editor can test it, and the publisher can ship it. Campaign-first milestones decide implementation order; stock campaigns do not cap the behavior or creator surface.

The complete revival includes:

- Training, the base campaign and secrets, and Mercenary;
- full six-degree-of-freedom gameplay, AI, weapons, goals, difficulty, room roles, GuideBot, cockpit, HUD, automap, markers, cameras, cinematics, adaptive music, voice, results, menus, movies, haptics, saves, replay, and ledgered presentation and command behavior;
- native multiplayer for 2–32 connected humans, dedicated hosting, public discovery and relay, observers, prediction and reconciliation, chat, host operations, stock modes including co-op, player media, and multiplayer authoring;
- the full native world, terrain, content-definition, behavior, campaign, briefing, cinematic, media, localization, lighting, navigation, validation, playtest, and publishing workflow;
- a native mod SDK using the same projects and packages as first-party content;
- the ability to create and publish a complete independent campaign and multiplayer package without legacy tools or hand-edited generated files.

[Functional completeness](docs/revival/functional-completeness.md) and its [ledger](docs/revival/functional-completeness-ledger.md) are the binding inventory.

## One-way conversion

    Owned Descent 3 retail data
                |
                v
          Swift D3Import
                |
                v
     Canonical Revival content
                |
                v
     Swift/Metal game and editor

Only D3Import reads supported prepared-installation containers and legacy formats. The game and editor never mount retail HOG archives, open D3L at runtime, or load native mission modules. Import and reimport are explicit, checked, repeatable, and one-way. Converted retail media stays local because conversion does not change ownership.

Stock behavior is translated from generated and handwritten source one actual dependency chain at a time as canonical direct typed Swift. Shipping packages contain safe native data or project-owned instructions, never native executable modules. Creator authoring grows from working generated, handwritten, timed/persistent, and presentation-oriented chains; it does not force a replacement executor before those cases prove one necessary.

## Product shape

The initial workspace has three executable products and two named code-ownership areas:

| Product or ownership area | Responsibility |
| --- | --- |
| D3Import | One-way conversion of the current owned retail slice |
| RevivalCore | Canonical world, simulation, behaviors, validation, saves, replay, and multiplayer state |
| RevivalMetal | Direct Metal rendering for game and editor |
| RevivalMac | Player application, input, audio, media, import UX, and later no-window hosting |
| RevivalEditor | Native editing, validation, playtest, baking, and publishing |

`D3Import`, `RevivalMac`, and `RevivalEditor` are executable products. `RevivalCore` and `RevivalMetal` are required ownership boundaries, but the first working code decides whether they are separate targets, source groups, or one of each. RevivalRelay is added when public multiplayer reaches implementation. Target count is not a product feature; a new target must own a real isolation boundary and remove more complexity than it introduces.

The project has no generic ECS, job system, render graph, dependency-injection framework, binary plugin system, general asset manager, speculative streaming framework, or cross-platform abstraction. Required mechanisms grow from working campaign and creator slices and stay purpose-built.

## Evidence and measurements

The pinned source builds natively as arm64 on the local M4 after a small header correction, all 12 upstream tests pass, owned base and Mercenary data has been verified, and the reference executable reaches Training and base campaign level 1. Those results make the source and data useful translation evidence; no production target depends on the reference engine.

Reference captures answer specific behavioral questions. Product tests then protect the accepted native contract. Optimized M4 profiles decide modernizations. We do not maintain permanent cross-engine parity CI or optimize hypothetical bottlenecks.

## Documentation

- [Architecture](docs/revival/architecture.md) records the native semantic-translation decision.
- [Source translation discipline](docs/revival/source-translation.md) defines file accounting and modernization.
- [Source translation ledger](docs/revival/source-translation-ledger.md) records the initial file-by-file dispositions and closure status.
- [World loading and residency](docs/revival/world-streaming.md) defines the resident baseline and measured amendment gate.
- [Roadmap](docs/revival/roadmap.md) gives the concrete vertical-slice sequence.
- [Functional completeness](docs/revival/functional-completeness.md) and the [ledger](docs/revival/functional-completeness-ledger.md) define complete scope.
- [Engineering principles](docs/revival/engineering-principles.md) defines the minimal-code rules.
- [Test-driven development](docs/revival/test-driven-development.md) defines production red-green-refactor and the test-value gate.
- [Content pipeline](docs/revival/content-pipeline.md) defines one-way retail conversion and native packages.
- [Behavior system](docs/revival/behavior-system.md) records the evolving safe replacement for Osiris and DALLAS.
- [Adaptive music](docs/revival/adaptive-music.md) defines score translation and native playback.
- [Creator suite](docs/revival/creator-suite.md) defines the human-first editor.
- [Verification](docs/revival/verification.md) defines translation, product, and M4 evidence.
- [Skills and agents](docs/revival/skills-and-agents.md) defines workstream playbooks and roles.
- [Discovery](docs/revival/discovery.md) records historical source and development evidence.

Command & Conquer and FreeSpace 2 remain future projects. This repository is focused on Descent 3.
