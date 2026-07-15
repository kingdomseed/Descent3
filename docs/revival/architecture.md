# Architecture decision: native semantic translation

- Status: accepted, amended
- Date: July 15, 2026
- Authority: binding product architecture

## Decision

Build a complete Apple-native Descent 3 game and creator suite with the Swift 6.4 compiler toolchain in Swift 6 language mode and with MSL and direct Metal 4. Use the current Xcode 27 beta for initial product work and move to stable Xcode 27 when released without retaining a Swift 6.3 compatibility path. Reach that product through dependency-ordered semantic translation of the pinned released source, keeping the native player and editor runnable together as capability moves across.

The shipping product targets arm64 Macs running macOS 26 or later. It uses AppKit, MetalKit, GameController, AVFoundation, AVAudioEngine, Model I/O, Network, CryptoKit, Foundation, and OSLog directly.

Shipping targets contain no C or C++ engine code, Objective-C++ bridge, Rust runtime, OpenGL renderer, SDL layer, Wine or Game Porting Toolkit runtime, Vulkan translation layer, Metal-cpp host, or native legacy module.

That shipping boundary does not make the source incidental. The C++ tree is the default translation specification for original data flow, ordering, formulas, resource dependency discovery and lifetime, gameplay, rendering, and editor workflows until the native counterpart is verified. [Source translation discipline](source-translation.md) defines file-level accountability and deliberate modernization.

## Decision levels

Three kinds of statement must not be confused:

1. Product decisions define the Apple-native platform, complete game and creator scope, one-way retail boundary, rights rules, and absence of a shipping legacy runtime.
2. Current implementation decisions select one concrete path for the next phase. They remain binding while implemented and change through a recorded amendment, not through parallel options.
3. Research hypotheses identify questions to measure. They do not constrain production types, package schemas, or tests before evidence promotes them.

The resident authoritative world with source-faithful asset paging, the explicit old/new variable-time handoff, and the early shared editor/player loop are current implementation decisions. Spatial streaming and a fixed simulation tick are later hypotheses, not hidden Phase 1 requirements.

## Product and fidelity boundary

The first content track reconstructs Training, the base campaign and secrets, and Mercenary. Multiplayer, replay, a complete native creator suite, and a native mod SDK remain committed. [Functional completeness](functional-completeness.md) defines the inventory and completion rule.

The initial translation preserves reachable behavior and structure that affect:

- controls, flight, collision, AI, weapons, objects, goals, and campaign flow;
- update and event order, elapsed-time use, and state transitions;
- room, portal, terrain, visibility, lighting, material, and presentation semantics;
- the resident level world, eager working-set paging, reachable lazy paging, and load/unload behavior;
- editor inspection, mutation, save, validation, play, and return workflows;
- multiplayer, replay, behavior, and utility capabilities as their phases arrive.

The translation does not preserve MFC or Win32 UI, OpenGL and SDL APIs, native module ABIs, raw memory layout, global mode switching, duplicated editor/runtime compilation, old saves or packets, page-database locks, historical defects, or backward export.

Every deliberate behavior change records the source baseline, observable evidence, native choice, and verification. A modernization cannot be smuggled into a “faithful” translation without that record.

## Swift and Apple frameworks

Swift gives the game, importer, tests, applications, and editor one language and one ownership model. Use value types and direct ownership first. Borrowing, spans, noncopyable values, explicit specialization, and small audited unsafe regions are available when release-build profiling demonstrates a need; they are not a reason to pre-optimize.

Apple's TrueType interpreter migration is useful evidence for a method—clear ownership, corpus tests, and profile-guided removal of overhead—not a performance prediction or engine template. [Primary technical sources](primary-source-index.md#swift-engine-code-and-performance) preserves that evidence and its limits.

Call Apple frameworks directly. A single platform and implementation do not need interfaces whose only purpose is hiding AppKit, Metal, GameController, AVFoundation, or Network.

## Rendering

Metal is the only renderer. There is no backend interface or fallback renderer. RevivalMac and RevivalEditor both use RevivalMetal.

Start by translating the original visible result and traversal through a small explicit forward pass sequence:

1. lightmapped opaque world and models;
2. alpha and additive effects;
3. HUD, cockpit, and interface;
4. presentation.

Add mirrors, specular faces, scorch decals, procedural fire and water, volumetric lighting, declared blend modes, animated textures, UV sliding, destroyable surfaces, and other ledgered paths when the first source dependency and scene requires them. A complete effect inventory does not justify a render graph, generic material framework, deferred renderer, or second visibility architecture.

Indoor rendering begins with the released room-and-portal traversal and observable clipping rules. When the first outdoor island arrives, outdoor rendering begins with the released terrain representation, geometry LOD, and texture-segment selection with its UV, tile, and rotation behavior. Megacells are editor texture-pattern data, not an evidenced runtime LOD mechanism. Once representative native images and M4 profiles exist, a simplification may be proposed as an explicit amendment.

## World loading and lifetime

The production load unit is one complete canonical `Level`, matching the original D3L world boundary. In Phase 1, D3Import converts the complete Training D3L and both applications load the resulting complete canonical `Level`; one selected room is only the first visible and editable acceptance slice. A synthetic one-room level may be a focused fixture but never becomes a second package or runtime mode.

The current implementation keeps that authoritative level world resident until exit. It starts presentation preparation with the source-evidenced `PageInAllData` working set, then permits later source-reachable assets to be prepared directly from canonical content and retained for the rest of the level. The current package contains the complete level topology and every dependency reachable through the currently translated product path. It expands when a later phase makes another path executable, rather than analyzing all Osiris, matcen, and dynamic-spawn possibilities before their work begins. The runtime never reopens retail formats, and the design does not claim that every GPU resource existed before original level activation.

Player and editor use the same dependency rules and resident presentation path. For replacement, validate the successor's canonical CPU content while the current world remains active. At the commit boundary, stop new submissions, wait for final GPU use, and release the old presentation owner before preparing the successor. Failure before commit preserves the old world; failure afterward enters a clear unloaded error state. The design does not silently require two complete GPU level sets.

Do not add world cells, camera-demand envelopes, prefetch shells, stream blobs, LRU policy, or a resident/streaming switch. [World loading and residency](world-loading.md) defines the M4 evidence gate after the complete playable Training Mission and its amendment rule. Streaming remains possible only as a measured replacement that leaves one path.

## Initial product and ownership graph

Phase 1 creates three executable products around two required code-ownership boundaries:

    D3Import
    RevivalMac    -> RevivalCore ownership + RevivalMetal ownership
    RevivalEditor -> RevivalCore ownership + RevivalMetal ownership

D3Import is a separate signed command-line helper launched for explicit import. `RevivalCore` and `RevivalMetal` name dependency directions and framework exclusions; the first real code decides whether either deserves a separate build target. RevivalRelay is a committed later operational service and is added when Phase 9 begins public multiplayer implementation. Target count is an execution result, not constitutional law; adding a target still requires a concrete ownership boundary that removes more complexity than it creates.

### D3Import

D3Import is the only shipping component that reads the supported owned retail containers and formats. It translates legacy naming, precedence, HOG, level, model, texture, lightmap, font, sound, score, movie, and related semantics into canonical native content as required by the current campaign slice.

It traces the original eager `PageInAllData` working set and the lazy-page paths reached by the currently translated product path, including object initialization and later matcen or behavior-driven spawns when those paths enter the product. It writes ordinary checked canonical files for one complete `Level` and its current reachable dependency manifest; it does not mislabel the historical eager pass as complete closure, invent a room-scope production package, or require future behavior analysis early.

### RevivalCore

RevivalCore contains canonical content, complete level-world values, simulation, collision, objects, AI, weapons, goals, behavior state, validation, saves, replay, multiplayer state, and package rules. It imports no AppKit, Metal, AVFoundation, or retail-format code.

Start with concrete domain types and contiguous collections. The original file and global layout informs ordering and dependencies but does not dictate Swift module or type boundaries.

### RevivalMetal

RevivalMetal contains the concrete direct Metal renderer, resource creation, level-owned presentation lifetime, and MSL. It renders the same canonical world model for separately owned player, editor, and play-session values. It has no renderer protocol, general asset manager, or knowledge of retail formats.

### RevivalMac

RevivalMac owns the player application, NSWindow and MTKView, display loop, input sampling, audio and adaptive-score presentation, movies, haptics, text input, settings, file locations, signing, import UX, and level-load presentation. It composes RevivalCore and RevivalMetal directly.

A later no-window dedicated-host mode reuses RevivalCore without initializing rendering, audio, or player UI. It is not a second simulation framework.

### RevivalEditor

RevivalEditor begins in Phase 1 as the permanent native AppKit document application. Its first world slice derives an editable project value from the read-only canonical base, displays it with the shared Metal path, supports selection and one real edit with named undo/redo, saves and reopens, starts a disposable play-session copy through the shipping loader and simulation types, and returns to the document. “Shared world” means shared types and production paths, not one mutable instance simultaneously owned by editor and play.

The editor grows slice by slice into world, terrain, game-data, behavior, campaign, presentation, baking, validation, playtest, and publishing workspaces. AppKit owns document, window, menu, undo, and accessibility behavior. Do not recreate those services with a generic reactive store, command bus, service layer, preview package system, or job framework.

Add immutable snapshots and stale-result checks to the first real asynchronous editor operation that needs them. Do not prescribe a universal generation counter, fixed overlay allocation, or background-document resource protocol before the product exercises those cases.

### RevivalRelay

Phase 9 adds a small no-window service for public session discovery, expiring registration, join authorization, and opaque packet relay. It imports no game content or simulation and never becomes session authority.

The selected multiplayer direction remains Network-framework QUIC, Bonjour for LAN discovery, inner CryptoKit protection across relay legs, host-authoritative simulation, and 2–32 connected human slots. Detailed record, prediction, abuse, deployment, and outage contracts are ratified immediately before implementation against the then-working simulation rather than shaping Phase 1 code.

## Execution model

The first runtime uses one main-owner game and display loop. It explicitly passes the old `Frametime` and pre-update `Gametime` through systems and `EVT_INTERVAL`. After frame-cap waiting, it measures and stores the new duration, advances `Gametime`, then performs the remaining source-ordered tail work. It preserves the static/`InitGame` 0.1-second initialization and nested pause clock rebasing. No Swift code reads mutable global timing state. Moving measurement to callback start or advancing game time earlier would be a recorded modernization, not fidelity by default.

This explicit-delta scheduler is the one current implementation, not a permanent compatibility mode. Phase 3 captures and compares flight, collision, input ramp, interval, animation, and timer behavior. Before behavior breadth or replay depends on timing, the project makes one formal decision:

- keep explicit variable delta with ratified bounds; or
- convert to one fixed tick, translate every elapsed-time consumer once, and delete the variable scheduler.

Do not maintain both. A fixed tick rate, catch-up policy, interpolation rule, and deterministic numeric contract become binding only in that amendment.

The main owner holds mutable game state. Input becomes one explicit value passed into the translated step. Background work is limited to operations that actually block: import, file I/O, media conversion, resource preparation, and real editor bakes or publication. Do not add a simulation thread, actor graph, task per entity, work-stealing scheduler, or lock-free queue without a measured missed budget.

## World and behavior model

Use explicit domain types such as PlayerShip, Robot, Projectile, Door, Pickup, Room, Portal, and Terrain. This is not a generic ECS. Begin with the source-supported relationships and ordinary Swift functions; change layout only after a measured loop benefits.

Behavior implementation starts with canonical direct typed Swift functions for the actual Training dependency chain, including generated DALLAS ranges and handwritten code. Preserve events, order, timers, variables, persistence, and engine operations required by the slice. A different authored representation or executor requires working evidence across generated DALLAS, handwritten/custom, timer or persistent-state, and presentation-oriented behavior plus a concrete human-authoring limitation. It is not a complete speculative VM designed before the first script runs or an inevitable rewrite.

Shipping packages never contain native executable code. Creator-facing behavior authoring must provide the useful DALLAS and Osiris capabilities without their generated C++, compiler integration, DLL ABI, or unrestricted engine function table; it does not predetermine a second runtime representation.

Flying AI begins by translating the released room/portal, outdoor-region, node, path, clearance, steering, and recovery semantics used by the first robot. Simplify or replace them only after observable routes and failure cases exist.

## Content, saves, and compatibility

The only legacy-format boundary is the one-way importer. The game and editor consume canonical native content and never reach back into the retail installation.

The product writes new native projects, packages, saves, and replay. It does not import or export retail saves or demos, provide original multiplayer interoperability, load binary modules, or export D3L/HOG/editor data.

Use the simplest current schemas. Add public migrations and semantic revision machinery when a released user-authored format or persistent state creates that obligation, not before.

## Licensing and data rights

Project code derived from or translated from the released source remains compatible with GPL-3.0-or-later and records provenance in the source-translation ledger.

Retail art, audio, movies, maps, fonts, and related media remain proprietary. Original and converted retail media stay outside Git. Replacement content requires independently established rights and provenance.

## Rejected directions

The project rejects:

- shipping or permanently linking the C++ engine;
- retaining OpenGL, SDL, Wine, GPTK, Metal-cpp, or an Objective-C++ bridge as a product layer;
- a literal one-to-one Swift file/class transcription that preserves legacy boundaries;
- a greenfield engine that ignores source ordering and behavior in favor of speculative abstractions;
- parallel legacy/modern schedulers, loaders, renderers, world models, or editor paths;
- prebuilding spatial streaming, a general behavior VM, a job system, ECS, render graph, asset manager, or package platform before a real slice demonstrates the need;
- cross-platform abstractions for hypothetical targets.

## Consequences

The project accepts that the first native code may look closer to the source semantics than the final product. That traceability is deliberate. Once a working slice and measurements exist, refactoring can remove legacy-shaped complexity without guessing about what it did.

The result remains one native implementation and product suite: Swift host code, MSL shaders, direct Apple frameworks, one renderer, one current scheduler, one current resource-lifetime path, one canonical world model, and one human-first creator application.
