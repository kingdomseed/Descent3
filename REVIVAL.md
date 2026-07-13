# Descent 3 revival

This project is building a complete Apple-native revival of Descent 3: the game, its campaigns and multiplayer capabilities, and the tools needed to create entirely new levels, systems, behaviors, presentation, and campaigns. It imports legally owned retail content, but its architecture moves forward without the original runtime.

The old C++ engine, OpenGL renderer, SDL platform layer, Osiris native-module ABI, Windows editor, legacy saves, original network protocol, and retail file formats are research material. They do not survive as product layers.

## Product decision

The shipping product uses:

- Swift 6.3 for project-owned host code;
- MSL and direct Metal 4 for graphics;
- AppKit and MetalKit for game and editor windows;
- GameController for controller input;
- AVFoundation and AVAudioEngine for media and sound;
- Model I/O for one-way USD creator ingress;
- Network and CryptoKit for QUIC sessions, authentication, and encryption;
- Apple Silicon `arm64` and macOS 26 or later;
- a fixed 120 Hz simulation with display-rate rendering;
- one complete resident level working set, fixed room-and-portal visibility, and full-resolution terrain without runtime streaming or LOD;
- one canonical content model shared by runtime, editor, behaviors, saves, replay, multiplayer, and publishing.

There is one renderer, one simulation model, one behavior language, and one forward-moving content format. The project does not carry compatibility backends or export paths for the old world.

## Functional completeness

The revival preserves capability without preserving machinery. Every required player-facing and creator-facing feature receives a modern native counterpart. KISS means fewer concepts and less code, not fewer tools or a smaller game.

A gameplay feature is complete when the runtime can execute it, the editor can author it, validation can reject broken forms, play-in-editor can test it, and the publisher can ship it. Campaign-first milestones decide implementation order; stock campaigns do not cap the behavior language or creator suite.

Every production behavior is developed through a focused red-green-refactor cycle. Tests protect reachable product contracts rather than speculative branches or test-only architecture. [Test-driven development](docs/revival/test-driven-development.md) defines the binding implementation and review protocol.

The binding inventory and completion rules live in [Functional completeness](docs/revival/functional-completeness.md).

## One-way conversion

Owned retail files are source material for an importer:

```text
Owned Descent 3 retail data
            |
            v
      Swift D3Import
            |
            v
 Canonical Revival package
            |
            v
 Swift/Metal game and editor
```

Only the shipping `D3Import` helper reads supported prepared-installation containers and legacy formats. The game never mounts retail HOG archives or loads native mission DLLs. Import and reimport are explicit, checked, repeatable, and one-way. Converted retail media remains local because conversion does not change its ownership. Separate source-preparation evidence may explain how an owner produces the supported input from original media; no product target executes it.

Stock behavior is translated into typed `BehaviorGraph` source and compiled into deterministic `BehaviorProgram` data. The new system replaces Osiris and DALLAS functionality without emulating their binary ABI or generating native code.

## Committed scope

The complete revival includes:

- the Training, base, secret, and Mercenary campaign content;
- six-degree-of-freedom flight, five-level difficulty and its real scaling rules, collision, AI, weapons, objectives, refueling rooms, HUD and selected one-way-converted stock fonts, animated cockpit, automap, markers, rear and auxiliary camera views, in-game camera-path cinematics, adaptive music, audio, movies, cheat, easter-egg, and diagnostic commands with explicit per-command policy, native controller haptics, modern saves, and replay;
- native multiplayer for 2–32 connected human slots over Network-framework QUIC and inner CryptoKit records, dedicated hosting, public discovery and opaque relay, live observer mode, prediction and reconciliation, text chat and moderation, authenticated host operator commands, explicit authoritative and client-presentation behavior roles, supported game modes, secure player pictures, ship logos and audio taunts, and multiplayer authoring;
- a direct Metal renderer with a resident level working set, room-and-portal visibility, and full-resolution terrain for imported content and replacement visuals;
- a native macOS player application with keyboard, mouse, and controller support;
- one integrated native creator suite for world geometry, terrain, objects, game data, behaviors, campaigns, briefings, cinematics, USD asset ingress, localization, lighting, purpose-built volumetric navigation, validation, playtesting, and publishing;
- a native mod SDK that uses the same project and package contracts as first-party content;
- the ability to create and publish a complete new campaign without legacy tools or hand-edited generated files.

The product does not include:

- original save, demo, level, HOG, or editor-format import or export except the deliberate retail-content import boundary;
- live interoperability with original multiplayer clients or servers;
- binary Osiris or game-module loading;
- original community DLL compatibility;
- Intel Mac, Windows, Linux, iOS, or visionOS targets unless scope changes later;
- an OpenGL, SDL GPU, Metal-cpp, or translation-layer fallback.

## Product shape

Phase 1 starts with four targets. Phase 2 adds the editor. Phase 9 adds one isolated operational service, so the complete product has six targets:

| Target | Responsibility |
| --- | --- |
| `D3Import` | One-way conversion from owned retail data into canonical content |
| `RevivalCore` | Content, simulation, collision, AI, behaviors, saves, replay, multiplayer state, and validation |
| `RevivalMetal` | Direct Metal 4 rendering for the game and editor |
| `RevivalMac` | Player application, input, audio, media, files, import UX, presentation, and no-window dedicated hosting |
| `RevivalEditor` | Native project authoring, baking, debugging, playtest, and publishing |
| `RevivalRelay` | Public session discovery, expiring registration, join authorization, and opaque QUIC relay; no game content or simulation |

This is smaller than a general game engine. It has no generic ECS, job system, render graph, dependency-injection framework, binary plugin system, runtime streaming system, terrain LOD system, or cross-platform abstraction. Required mechanisms such as the behavior executor, content catalog, navigation graph, and relay protocol stay narrow and product-specific.

## First playable and creator slices

The first playable combat slice converts a connected Training Mission room cluster and proves flight, collision, a door and trigger, one robot following a baked volumetric route, one weapon, one pickup, HUD, positional audio, and new-format save and reload. The editor opens the same canonical cluster and can inspect it in Phase 2. By Phase 4 it can edit and play the geometry, door, trigger, robot, navigation topology, weapon, pickup, and first behavior graph used by that slice.

The next milestone completes the full Training Mission and its matching campaign, behavior, briefing, and content-authoring paths. Work then expands campaign level by level. Every runtime capability gains its authoring, validation, and playtest path in the same phase.

Campaign completion proves the imported game. An independently authored campaign proves the depth of the campaign-creation workflow. Full creator-suite completion also requires native multiplayer maps and modes to pass their authoring and publishing gates. Multiplayer and replay prove that the new simulation and behavior contracts extend beyond the stock single-player path.

## Current evidence

The repository still contains the released Descent 3 C++ source and completed exploratory work. That work established that:

- source commit `156cba8aafd997d27deb0902ba6026bcdcc1cfaf` builds as native `arm64` on the local M4 after a small header correction;
- all 12 existing upstream tests pass;
- the owned two-disc base game and Mercenary images were extracted and verified;
- the official 1.4 update produced canonical `extra.hog` and `extra13.hog` archives;
- the native reference executable entered the Training Mission and base campaign level 1 with the original OpenGL renderer.

These results validate the source material and local retail data. The released tree also supplies behavioral and creator-tool evidence for Osiris, DALLAS, D3Edit, the Briefing Editor, multiplayer, replay, and packaging. No production target depends on it.

The old source remains through Phase 10. It can move to an archival branch or leave the active checkout only after every ledger row is implemented and verified, replaced, or explicitly excluded, and no unresolved product question still depends on the active tree.

## Documentation

- [Functional completeness](docs/revival/functional-completeness.md) defines the full player and creator capability contract.
- [Functional-completeness ledger](docs/revival/functional-completeness-ledger.md) records the Phase 0 capability inventory, owners, milestones, and evidence state.
- [Architecture](docs/revival/architecture.md) records the binding Swift/Metal decision and rejected directions.
- [Engineering principles](docs/revival/engineering-principles.md) defines the minimal-code rules.
- [Test-driven development](docs/revival/test-driven-development.md) defines red-first implementation, the test-value gate, and anti-dilution review rules.
- [Content pipeline](docs/revival/content-pipeline.md) defines one-way retail conversion, native projects, and canonical packages.
- [Behavior system](docs/revival/behavior-system.md) defines the replacement for Osiris and DALLAS.
- [Adaptive music](docs/revival/adaptive-music.md) defines score import, logical state, native playback, persistence, and authoring.
- [Creator suite](docs/revival/creator-suite.md) defines the integrated native editor and publishing workflow.
- [Verification](docs/revival/verification.md) defines tests, measurements, and product acceptance.
- [Skills and agents](docs/revival/skills-and-agents.md) records expert sources, project skills, and team roles.
- [Roadmap](docs/revival/roadmap.md) orders the work from planning through the complete revival and later visual upgrades.
- [Discovery](docs/revival/discovery.md) records historical source evidence carried into the new design.
- [Legacy M4 build](docs/revival/macos-arm64-build.md) preserves the reference-build procedure.
- [Retail data](docs/revival/retail-data.md) records acquisition, hashes, local storage, and the importer boundary.

Command & Conquer and FreeSpace 2 remain future projects. This repository is focused on Descent 3.
