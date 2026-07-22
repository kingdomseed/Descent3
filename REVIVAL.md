# Descent 3 revival

This project is building a complete Apple-native revival of Descent 3: the game, its campaigns and multiplayer capabilities, and the tools needed to create new levels, systems, behaviors, presentation, and campaigns.

The route is a source-led native translation, not a greenfield design exercise and not a shipping C++ port. We translate the pinned released source in coherent dependency order, keep every relevant file accounted for, and preserve observable game and creator semantics before deliberately modernizing them. The finished product contains no legacy runtime.

The roadmap phases are broad dependency groupings, not promises that every capability inside a phase lands at once. Phase 10 is the complete version 1.0 release. Phase 11 is explicitly post-1.0 visual and experiential development. [The current implementation plan](docs/revival/current-plan.md) is the single living record of active state, near-term work, and ownership beneath that roadmap and the accepted contracts; contributors read it and the integration owner updates it instead of maintaining another current-work plan. The project-local [documentation steward](.agents/skills/revival-documentation-steward/SKILL.md) restores that state at material packet boundaries and routes durable changes to their existing owners without creating another plan or journal.

One guiding light applies whenever the work enters a new phase, milestone checkpoint, dependency island, subsystem, or material code group: **uncover the fog of war**. Before implementation, challenge the current plan against the accepted contracts, pinned source, real callers, ledgers, code, and observable evidence. Do not assume that planning has already found every dependency or nuance. Do not assume that a defect exists either. The bounded preflight may conclude that no new gap was found; deeper wayfinding begins only when it exposes linked unknowns that block a concrete contract. [Source translation discipline](docs/revival/source-translation.md#fog-of-war-preflight) defines the procedure.

A paired guiding light applies at closure: **prove the need to continue**. After ordinary review is consolidated, the independent [Revival completion gate](.agents/skills/revival-completion-gate/SKILL.md) challenges every remaining guard, test, profile, rerun, and blocker against the current accepted checkpoint, a practically reachable shipping event, and a bounded decision it can change. It preserves real fidelity, boundary, lifetime, security, creator, player, and performance obligations while rejecting ceremonial proof, unsupported failure engineering, later-milestone work, and unlimited negatives. Once the checkpoint is satisfied and no reachable P1/P2 defect remains, it orders the implementer to stop.

## Product direction

The shipping product uses:

- the Swift 6.4 compiler toolchain in Swift 6 language mode for project-owned host code, using Xcode 27 beta until the stable Xcode 27 release;
- MSL and direct Metal 4 for graphics;
- AppKit for the macOS player and editor shells, UIKit as the default iPhone and iPad player application and UI framework, and MetalKit for every viewport; a bounded SwiftUI view is allowed only for a concrete current advantage without creating another shell, lifecycle, state owner, or renderer path;
- GameController for physical-controller input; the Phase 8 mobile-input packet selects any additional native touch-gameplay mechanism against the working UIKit and shared input path;
- AVFoundation and AVAudioEngine for media and sound;
- Model I/O for the first native USD creator ingress;
- Network and Bonjour for native LAN multiplayer, with the Internet transport and security boundaries selected from current evidence;
- arm64 Macs on macOS 26 or later and Metal 4-capable iPhone and iPad devices on iOS or iPadOS 26 or later, with Apple GPU family 7 as the candidate mobile feature floor pending representative release evidence;
- one canonical content model shared by runtime, editor, saves, replay, multiplayer, and publishing.

There is one renderer, one active simulation scheduler, one active level-lifetime path, and one canonical world model and production path. Player, editor document, and editor play session own separate values; OpenGL, SDL, MFC, DLL interfaces, original saves and packets, and retail runtime formats do not survive as product layers.

## Mobile platform amendment

The original accepted direction limited the product to macOS and explicitly left iOS outside the roadmap. On July 15, 2026, the user approved replacing that boundary with a version 1.0 player for iPhone and iPad while retaining the native Mac player and macOS creator suite.

The replacement adds one universal UIKit executable, `RevivalMobile`. It composes the same RevivalCore and RevivalMetal code, canonical packages, saves, replay, simulation, campaign behavior, and applicable multiplayer capability as RevivalMac. The two concrete player shells call AppKit or UIKit directly; there is no generic platform layer, renderer protocol, alternate scheduler, mobile package format, or mobile resource-lifetime mode. The mobile player is landscape-first but must respond correctly to safe areas and every supported drawable size.

UIKit remains the simple default for the application shell, game view, navigation, and ordinary interface work. SwiftUI is neither prohibited nor a target architecture: use it only for a bounded current screen or component when it removes more project-owned code or provides a concrete product benefit that direct UIKit does not, and host it without duplicating application lifecycle, navigation state, game state, or the `MTKView` presentation path. Framework novelty alone is not a reason to refactor the shell.

RevivalEditor, D3Import, and dedicated no-window hosting remain macOS-only. D3Import remains the only legacy-format reader. RevivalMobile accepts only a Mac-produced canonical package through the system file picker, validates and atomically installs it through the same native-package contract, and copies it into app-owned storage. Version 1.0 mobile use therefore requires access to a Mac that can run D3Import. There is no existing native implementation or released canonical package to migrate; the superseded macOS-only target wording is deleted in this amendment.

The first mobile deployment target is iOS and iPadOS 26 or later, with Metal 4 Apple GPU family 7 or newer as the candidate release floor. Early target, build, simulator, and shared-path work may proceed whenever useful, but missing physical devices, signing, or development-team setup cannot block a Phase 1–7 slice or phase. Required direct mobile integration begins in Phase 8, with applicable multiplayer and release evidence continuing through Phases 9 and 10. Before public beta or release claims Apple GPU family 7 support, the project verifies a representative floor-device matrix or raises the released floor to the oldest hardware it can support with evidence. Public mobile distribution also requires a separate accepted rights, GPL, review-content, signing, channel, and enabled-device-family record before release; App Store availability is not assumed merely because the player target exists. If the App Store is selected, unapproved visionOS availability and iPhone/iPad-app execution on Apple Silicon Macs remain disabled unless those targets receive their own amendment and evidence.

## Translation before redesign

The released C++ source is the initial specification for:

- update order, elapsed-time use, input, physics, collision, AI, weapons, and objects;
- room, portal, terrain, visibility, lighting, effects, and presentation;
- per-level dependency discovery, eager working-set paging, reachable lazy paging, activation, and release;
- D3Edit inspection, mutation, level I/O, rendering, and play-from-editor;
- DALLAS, Osiris, campaign, multiplayer, replay, and utility capability.

Pinned maintained descendants are an interpretation and correction layer over that baseline. Their exact commits often contain work the Revival team should not repeat: a diagnosed defect, a clarified ordering or lifetime invariant, a restored result, a quality-of-life improvement, and a compact before/after diff that makes the older path easier to understand. When one of those changes maps to the current dependency island, read it before implementing the corresponding released-source path, extract the corrected behavior and regression case, and express that result directly through native Swift, MSL, canonical data, and Apple-framework ownership. Do not implement a known historical defect first merely to rediscover and repair it later. The descendant's platform mechanism is neither the product design nor a reason to discard the semantic work it reveals.

Every relevant source file receives a disposition, but native files and types follow clear Swift ownership rather than legacy file boundaries. Platform APIs, global mode switching, duplicated compilation, page-database locks, defensive branch forests, dead code, and historical workarounds are replaced or excluded with evidence.

[Source translation discipline](docs/revival/source-translation.md) defines the loop: trace, capture, test, translate, run, record differences, simplify, and close the file accounting.

## First implementation

The first native world starts from the original game's operational baseline:

- D3Import converts the complete Training D3L world plus every asset reachable by the currently translated path into checked canonical content;
- RevivalCore constructs the complete resident level world;
- a direct PageInAllData-style pass eagerly prepares the evidenced working set, while later source-reachable presentation assets load only from the canonical package and then remain resident;
- RevivalMac and RevivalEditor first establish the same world types, loader, simulation, and renderer with separately owned player, document, and play-session values; RevivalMobile then composes the proven shared path without creating another implementation;
- exit waits for final GPU use and releases the level resources through one owner.

The released engine did not prove a complete GPU-ready dependency closure at activation: bitmap, object, matcen, and Osiris paths could page additional assets later, and the retained GPU pre-upload hook is a no-op. The canonical-only runtime is a deliberate one-way-content strengthening. Its package contains the complete level topology and every dependency reachable through the currently translated product path, then expands when a new product path becomes real; eager-versus-lazy preparation still follows the source until measurement supports a change.

This is the concrete current implementation. It is not “no streaming ever.” Spatial streaming is considered only after the complete playable Training Mission and representative large indoor, outdoor, editor, and higher-resolution workloads are measured on the recorded M4 and applicable mobile development hardware. Before the supported mobile floor is claimed at public beta or release, the chosen lifetime path must also pass representative floor-device evidence or the floor must be raised. A later amendment must replace the resident mechanism across platforms rather than add permanent Mac and mobile modes. [World loading and residency](docs/revival/world-loading.md) defines that gate.

The first scheduler preserves the historical old/new timing handoff explicitly. Frame systems and `EVT_INTERVAL` consume the previous `Frametime` and pre-update `Gametime`; after cap waiting, `CalcFrameTime` stores the new duration, then `GameFrame` advances `Gametime` before the remaining tail work. It preserves the static/`InitGame` 0.1-second initialization and nested pause/rebase behavior without retaining mutable globals. After flight, collision, interval events, and animation have native reference evidence, Phase 3 chooses and completes one final timing model. Fixed 120 Hz remains a candidate, not a Phase 1 fact, and the product will not keep variable and fixed modes in parallel.

## Editor and runtime together

RevivalEditor begins in Phase 1, not after an engine foundation is designed in isolation. The first Mac/shared integrated checkpoint loads the complete imported Training Level in RevivalMac and RevivalEditor, focuses one acceptance room, derives an editable complete-level project value from the read-only base, renders both viewports through the same Metal path, performs one real editor mutation with undo, saves and reopens, enters the shipping simulation with a disposable play-session copy, and returns to the document. RevivalMobile may compose that proven result early through its concrete UIKit and storage boundaries, but Phase 1–7 closure never waits on physical mobile evidence. Phase 8 integrates the accumulated player through UIKit lifecycle, package intake, touch, physical controllers, presentation, and audio-session behavior on available devices; Phases 9 and 10 close mobile multiplayer and release obligations.

This does not claim that Descent 3 was historically built by completing its editor first. The evidence shows editor and runtime co-development around shared initialization entry points with editor branches, production world and level functions, low-level rendering, and the actual runtime loop during editor-hosted play. We are following that useful integration pattern while replacing the Windows and MFC machinery.

The editor grows with the game into a human-first AppKit creator suite. MCP, headless authoring, training capture, telemetry, and agent-only workflows remain outside the current roadmap until the complete human product ships.

## Functional completeness

The revival preserves capability without blindly preserving machinery. Every required player-facing and creator-facing feature receives a modern native counterpart. KISS means fewer concepts and paths, not fewer tools or a smaller game.

A gameplay feature is complete when the runtime can execute it, the editor can author it where applicable, validation can reject broken forms, play-in-editor can test it, and the publisher can ship it. Campaign-first milestones decide implementation order; stock campaigns do not cap the behavior or creator surface.

The complete revival includes:

- Training, the base campaign and secrets, and Mercenary;
- full six-degree-of-freedom gameplay, AI, ordinary and advanced weapons, inventory and countermeasures, environmental hazards, the Training-required headlight, goals, difficulty, room roles, GuideBot, cockpit, HUD, automap, markers, cameras, cinematics, independently ledgered audio environments, adaptive music, voice, results, application/session and pause transitions, profiles and settings, player save-slot and quicksave workflows, menus, movies, haptics, saves, replay, and ledgered presentation and command behavior;
- native multiplayer for the source-supported player counts of each stock mode, preserving the released 32 network/player-slot infrastructure and its listen/dedicated accounting, dedicated hosting, LAN and Internet discovery and joining through one evidence-selected 2026 topology, observers, prediction and reconciliation, chat, host operations, player media, and multiplayer authoring;
- the full native world, terrain, content-definition, behavior, campaign, goal, briefing, TelCom, cinematic, message-catalog, modern-font, audio, adaptive-score, media, localization, lighting, navigation, validation, playtest, publishing, and native-package install workflow;
- a native mod SDK using the same projects and packages as first-party content;
- certification that the creator suite can create and publish a complete independent campaign and multiplayer package without legacy tools or hand-edited generated files. These proof packages are not bundled replacement content and do not remove the version 1.0 retail-ownership requirement.

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

Only D3Import reads supported prepared-installation containers and legacy formats. The game and editor never mount retail HOG archives, open D3L at runtime, or load native mission modules. Import and reimport are explicit, checked, repeatable, and one-way. Converted retail media stays local because conversion does not change ownership. RevivalMobile receives only the canonical result and never links the legacy readers. Version 1.0 requires a user-owned supported prepared retail installation and a Mac for conversion; direct raw-disc preparation, mobile retail conversion, additional store layouts, other import sources, and project-owned replacement assets require later evidence and decisions.

Stock behavior is translated from generated and handwritten source one actual dependency chain at a time as canonical direct typed Swift. Under that current runtime, packages contain validated bindings, initial configuration and state, content references, revision, and provenance—not Swift, bytecode, executable instructions, or native modules. Version 1.0 provides a reusable human-authored native model for the evidenced behavior and creator capability of the shipped game and tools without requiring Swift or generated-file editing. Creator authoring grows from working generated, handwritten, timed/persistent, and presentation-oriented chains; evidence selects its graph, text, or other representation and one runtime path, while broader mechanics remain later decisions.

## Product shape

The product has four executable products and two named code-ownership areas. Initial workspace work establishes D3Import, the shared ownership areas, RevivalMac, and RevivalEditor first; RevivalMobile joins when the first proven shared slice is ready for UIKit composition:

| Product or ownership area | Responsibility |
| --- | --- |
| D3Import | One-way conversion of the current owned retail slice |
| RevivalCore | Canonical world, simulation, behaviors, validation, saves, replay, and multiplayer state |
| RevivalMetal | Direct Metal rendering for game and editor |
| RevivalMac | Player application and session shell, input, profiles and settings, audio, media, import UX, native-package library and activation, operational diagnostics, and later no-window hosting |
| RevivalMobile | Universal iPhone and iPad player shell, touch and physical-controller input, UIKit lifecycle, AVAudioSession, canonical-package intake, mobile storage, and applicable campaign, replay, and multiplayer presentation |
| RevivalEditor | Native editing, validation, playtest, baking, and publishing |

`D3Import`, `RevivalMac`, `RevivalMobile`, and `RevivalEditor` are executable products. `RevivalCore` and `RevivalMetal` are required ownership boundaries, but the first working code decides whether they are separate targets, source groups, or one of each. Phase 0 researches an affordable 2026 Internet-multiplayer direction without shaping Phase 1 code; a later public-service executable exists only if that accepted direction needs one. Target count is not a product feature; the approved mobile target owns the real UIKit, lifecycle, input, storage, and distribution boundary without creating a second game implementation.

The project has no generic ECS, job system, render graph, dependency-injection framework, binary plugin system, general asset manager, speculative streaming framework, or generic cross-platform abstraction. Required mechanisms grow from working campaign and creator slices and stay purpose-built.

## Evidence and measurements

The pinned source builds natively as arm64 on the local M4 after a small header correction, all 12 upstream tests pass, owned base and Mercenary data has been verified, and the reference executable reaches Training and base campaign level 1. Those results make the source and data useful translation evidence; no production target depends on the reference engine.

Reference captures answer specific behavioral questions. Product tests then protect the accepted native contract. Optimized M4 profiles guide Phase 1–7 implementation modernizations. Applicable physical development-device profiles join at the Phase 8 mobile integration gate; representative floor-device evidence certifies the published mobile floor at public beta or release. Neither is a prerequisite for earlier slices. We do not maintain permanent cross-engine parity CI or optimize hypothetical bottlenecks.

## Documentation

- [Architecture](docs/revival/architecture.md) records the native semantic-translation decision.
- [Source translation discipline](docs/revival/source-translation.md) defines file accounting and modernization.
- [Source translation ledger](docs/revival/source-translation-ledger.md) records the initial file-by-file dispositions and closure status.
- [World loading and residency](docs/revival/world-loading.md) defines the resident baseline and measured amendment gate.
- [Roadmap](docs/revival/roadmap.md) gives the concrete vertical-slice sequence.
- [Current implementation plan](docs/revival/current-plan.md) is the single living record of active state, near-term work, and developer ownership beneath the roadmap and accepted contracts.
- [Functional completeness](docs/revival/functional-completeness.md) and the [ledger](docs/revival/functional-completeness-ledger.md) define complete scope.
- [Future opportunities](docs/revival/future-opportunities.md) preserves source-evidenced dormant or incomplete ideas without making them false 1.0 requirements.
- [Internet multiplayer study](docs/revival/internet-multiplayer-study.md) defines the bounded Phase 0 evidence record and decision gate for an affordable 2026 topology.
- [Engineering principles](docs/revival/engineering-principles.md) defines the minimal-code rules.
- [Test-driven development](docs/revival/test-driven-development.md) defines production red-green-refactor and the test-value gate.
- [Content pipeline](docs/revival/content-pipeline.md) defines one-way retail conversion and native packages.
- [Retail data and provenance](docs/revival/retail-data.md) records verified local source profiles, hashes, and the active rights boundary.
- [Behavior system](docs/revival/behavior-system.md) records the evolving safe replacement for Osiris and DALLAS.
- [Adaptive music](docs/revival/adaptive-music.md) defines score translation and native playback.
- [Creator suite](docs/revival/creator-suite.md) defines the human-first editor.
- [Verification](docs/revival/verification.md) defines translation, product, Mac, and physical-mobile-device evidence.
- [Skills and agents](docs/revival/skills-and-agents.md) defines workstream playbooks, bounded roles, and documentation continuity.
- [Skill supply chain](docs/revival/skill-supply-chain.md) records external pins, licenses, allowed advice, and project overrides.
- [Primary technical source index](docs/revival/primary-source-index.md) preserves the key web documentation, the question each source answers, and its limits.
- [Discovery](docs/revival/discovery.md) records historical source and development evidence.
- [Legacy M4 reference build](docs/revival/macos-arm64-build.md) preserves the archived non-product build procedure used for focused comparisons.

Command & Conquer and FreeSpace 2 remain future projects. This repository is focused on Descent 3.
