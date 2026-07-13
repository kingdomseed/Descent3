# Architecture decision: native Swift and Metal

- Status: accepted
- Date: July 13, 2026
- Authority: binding product architecture

## Decision

Build a complete new game and creator suite for Apple Silicon with Swift 6.3 host code and MSL shaders using the Metal 4 API directly. The product runs content converted from an owned Descent 3 installation and native creator projects, but it does not preserve the original engine architecture or executable interfaces.

The product targets `arm64` Macs running macOS 26 or later. It uses AppKit, `MTKView`, GameController, AVFoundation, AVAudioEngine, Foundation, and OSLog directly. Swift Package Manager owns reusable targets. `RevivalMac` and `RevivalEditor` are thin Xcode application targets for player and creator application packaging and signing.

Shipping targets contain no C or C++ engine code, Objective-C++ bridge, Rust runtime, OpenGL renderer, SDL layer, Wine or Game Porting Toolkit runtime, Vulkan translation layer, Metal-cpp, or native legacy module.

## Product boundary

The project rebuilds Descent 3's required player and creator capabilities in a new engine. The first content track reconstructs Training, the base campaign and secrets, and Mercenary. The committed product also includes multiplayer, replay, a complete native creator suite, and a native mod SDK. [Functional completeness](functional-completeness.md) defines the inventory and completion rule.

Recognizable content, controls, pacing, objectives, and six-degree-of-freedom play remain important evidence for imported campaigns. Historical frame-dependent behavior, binary layouts, module calling conventions, save bytes, network packets, editor dialogs, and renderer quirks are not contracts.

The only legacy boundary is a one-way importer. Original files cross that boundary only during an explicit import or reimport and become canonical native content. No gameplay or editor component reaches back into the retail installation. Native projects and packages use the new canonical formats only.

## Why Swift 6.3

The project targets one operating-system family and depends heavily on Apple frameworks. Swift gives the game, importer, tests, applications, and editor one language and one ownership model.

[Swift 6.3](https://www.swift.org/blog/swift-6.3-released/) adds explicit specialization, guaranteed direct-call inlining, and greater implementation visibility for cases where release-build profiling proves they are useful. Swift 6.2 already supplied `Span`, `InlineArray`, noncopyable types, borrowing, and stricter memory-safety tools suitable for low-level data work.

Apple's [TrueType interpreter migration](https://www.swift.org/blog/migrating-truetype-hinting-to-swift/) is evidence that modern Swift can handle data-intensive systems code. That team used value types, borrowing, spans, a small audited unsafe boundary, corpus testing, and profile-guided removal of ARC and dynamic-dispatch costs. Its reported 13 percent average improvement over the old C implementation is not a performance prediction for this game. The useful lesson is to write clear ownership first and optimize measured hot paths.

Swift was not selected to translate the old source line by line. A direct translation would reproduce its size and assumptions. The released source is evidence for formats, gameplay, creator tools, multiplayer, replay, and presentation. The new implementation uses the smallest modern model that can deliver the complete capability ledger.

## Why direct Metal 4

Metal is the only renderer. There is no backend interface and no fallback renderer.

The renderer uses `MTKView` so project code does not reimplement drawable and display-surface management that MetalKit already supplies. `RevivalMac` still owns the AppKit window and lifecycle. The renderer uses Metal 4 command submission, resource management, pipeline creation, validation, and capture directly from Swift. MSL shaders are compiled into a metallib for release builds.

The initial renderer is a direct forward renderer with a small fixed pass sequence:

1. lightmapped opaque world and models;
2. alpha and additive effects;
3. HUD and interface;
4. presentation.

This initial sequence is not the final material or effect inventory. Imported and native content also require direct support for reflected room views, specular faces, scorch decals, procedural fire and water textures, volumetric surfaces and lighting, and the historical alpha-weighted additive and other declared blend semantics. Add each as the smallest explicit pass, material state, or update path that produces the required image. Their existence does not justify a render graph, deferred renderer, physically based material framework, multithreaded command encoding, MetalFX, ray tracing, or general shader system.

## Target graph

Phase 1 creates the four runtime and import targets. Phase 2 adds `RevivalEditor`; the complete product has five production targets.

```text
target dependencies

D3Import ───────> RevivalCore
RevivalMetal ───> RevivalCore
RevivalMac ─────> RevivalCore
RevivalMac ─────> RevivalMetal
RevivalEditor ──> RevivalCore
RevivalEditor ──> RevivalMetal

process integration: Xcode package dependency, no module link

RevivalMac - - explicit import - -> bundled signed D3Import
```

`D3Import` writes canonical content. `RevivalMac` loads it through `RevivalCore` and presents it through `RevivalMetal`. `RevivalEditor` edits canonical project data and uses the same core and renderer for validation and playtest. Solid arrows are direct target dependencies; the dashed line is a small versioned command-line process contract, not a link dependency or general plugin protocol.

### `D3Import`

This is a signed Swift command-line helper bundled inside `RevivalMac`. It reads only the original formats required by the supported owned retail content and writes a canonical directory package. It depends on canonical content types from `RevivalCore`. No gameplay library links it. The `RevivalMac` Xcode target has an explicit build dependency on the helper, copies it into `Contents/Helpers`, and includes it in nested-code signing and archive verification. During an explicit import, `RevivalMac` launches the helper as a separate process, passes selected input and destination paths, and consumes its final report and exit status.

Legacy audio and movie input requires narrow project-owned Swift decoders for the exact ACM and MVE features present in the verified retail source profile. AVFoundation encodes and plays the canonical outputs; it does not decode those retail formats. The decoders exist only in `D3Import`, have bounded synthetic tests, and never enter the game process.

### `RevivalCore`

Contains canonical content and project types, world state, fixed-step simulation, collision, objects, AI, weapons, logical adaptive-score state, the behavior compiler and executor, validation, save and replay snapshots, multiplayer state, and package rules. It imports no AppKit, Metal, AVFoundation, or legacy-format code.

### `RevivalMetal`

Contains the concrete renderer and MSL. It consumes compact render snapshots from `RevivalCore` for player and editor viewports. The same renderer encodes the main view plus the small bounded set of cockpit, rear, GuideBot, guided-weapon, marker, mirror, and editor views required by current content; there is no second renderer or general camera framework. It has no renderer protocol and no knowledge of original file formats.

### `RevivalMac`

Owns the player application, `NSWindow`, `MTKView`, display loop, input sampling, audio, adaptive-score scheduling, movies, GameController haptics, player-selected media, file locations, settings, signing, packaging, and explicit import UX. It composes `RevivalCore` and `RevivalMetal` directly and launches the bundled `D3Import` helper only when the user requests import or reimport. [Adaptive music](adaptive-music.md) fixes the boundary between deterministic score decisions and sample-clock presentation.

Dedicated hosting is a no-window launch mode of the same `RevivalMac` executable. That mode constructs `RevivalCore` session and network ownership, skips renderer, audio, and player UI setup, and emits structured server logs. It is not a second simulation or a separate server framework. This keeps the planned product at five targets while providing a headless host.

### `RevivalEditor`

Phase 2 adds the native editor as a read-only content inspector and level viewer. Each later gameplay slice adds its matching creation, validation, debugging, and playtest operations. The editor owns AppKit editing views and commands while `RevivalCore` owns documents, game rules, behavior semantics, validation, and publishing rules. It has no legacy export mode.

One integrated application covers world and terrain editing, game-data definitions, `BehaviorGraph`, campaign and presentation authoring, asset inspection, lighting and navigation baking, dependency audits, play-in-editor, and package publishing. [Native creator suite](creator-suite.md) defines its contract.

Tests live beside these targets. A separate package is not needed for test architecture.

## Execution model

The initial runtime uses one `@MainActor` game and display loop. `MTKView` drives presentation. A small accumulator uses a monotonic elapsed-time source and runs the simulation at a fixed 120 Hz; rendering follows the display and may interpolate camera and object transforms between simulation states.

Catch-up is bounded to eight simulation ticks per display callback. Excess elapsed time is discarded and recorded with a counter and signpost instead of creating an unbounded backlog. Pause, application suspension, occlusion-driven display suspension, window live-resize suspension, and resume clear the accumulator and rebase the clock; the simulation never tries to replay wall-clock time spent inactive.

This intentionally replaces the original variable-`Frametime` loop. There is no legacy timing mode.

The main owner holds mutable game state. Input is sampled into one value-type `InputFrame` per simulation tick. Held keys, buttons, and controller axes are copied into every tick while held. Press/release edges and accumulated relative mouse or scroll deltas are ordered pending impulses and are consumed exactly once by the next simulation tick, even when one display callback runs multiple ticks. Background work is limited to importing, disk I/O, media decoding, and immutable asset preparation. Completed assets are installed at a frame boundary.

Do not add a dedicated simulation thread, actor graph, task per entity, work-stealing scheduler, or lock-free queue until Instruments shows that the single loop misses its budget because of CPU work.

## World and simulation model

Use explicit domain types such as `PlayerShip`, `Robot`, `Projectile`, `Door`, and `Pickup`, stored in contiguous collections with small stable integer IDs. This is not a general ECS. The data may move toward struct-of-arrays storage only when a measured loop benefits.

Simulation rules are ordinary Swift functions and small state machines. The behavior system compiles typed visual graphs into compact ordered instructions executed by the simulation owner. Randomness comes from one seeded generator owned by the simulation. Simulation time is expressed in integer ticks wherever practical.

There is no general event bus. Behavior events use one ordered FIFO owned by `RevivalCore`; audio and presentation receive small typed command lists at frame boundaries.

## Numeric semantics

Authoritative scalar, vector, and orientation state uses Swift `Float`, which is IEEE-754 binary32 on the supported architecture. Import, authoring, behavior, save, replay, and network boundaries reject NaN and infinity. Each domain declares its valid magnitude and clamp or failure rule. Values smaller than `Float.leastNormalMagnitude` normalize to positive zero when committed to canonical persistent or hashed state, and negative zero also normalizes to positive zero.

Authoritative operations execute in declared order without fast-math transformations. A replay under the same `simulationSemanticRevision` compares canonical normalized Float32 bit patterns exactly. Transcendental or framework calculations that could vary across supported toolchains stay outside authoritative state or become a versioned, tested project operation. The project does not add fixed-point arithmetic or a general deterministic-math library without evidence that this direct contract fails.

## Saves and settings

The game writes new versioned snapshots for saves and replay. Each binds a simulation semantic revision in addition to the content revisions it uses. Snapshots do not contain live object pointers, Swift memory layouts, renderer resources, audio-engine state, interpreter addresses, or legacy bytes. Schema changes inside the new project use explicit version handling when an existing public save, replay, or creator project requires it.

The product does not import or export retail saves or demos. Settings use native Foundation storage unless a concrete need requires another format.

## Licensing and data rights

Project code derived from or translated from the released source remains compatible with GPL-3.0-or-later. The original source files state that license choice. New code should use GPL-3.0-or-later unless a later legal review establishes another valid boundary.

Retail art, audio, movies, maps, and related media remain proprietary. Neither original nor converted retail media enters Git. Replacement content needs its own documented rights.

## Rejected directions

### Incremental C++ and OpenGL port

This is the fastest route to a conventional port, but it preserves the architecture the project wants to replace. It also makes the old renderer and native modules permanent constraints. The completed native OpenGL build remains useful evidence, not the product base.

### C++ with Metal-cpp

Metal-cpp has an appropriate performance ceiling and would reuse more original code. Reuse and shortest time to parity are not the controlling goals. A C++ core would also require a second language or a nonnative UI strategy for the application and editor.

### Objective-C++ bridge

Objective-C++ is useful for staged migrations. This project is not staging a migration; it is starting a new engine. A bridge would create two ownership models and a boundary whose only purpose is to retain legacy implementation.

### Rust

Rust could implement the engine safely and quickly. It offers no compensating advantage for an Apple-only product that relies on Metal, AppKit, GameController, and AVFoundation, and it would add a language and framework boundary. It is outside the selected architecture.

### SDL, Vulkan, or a cross-platform renderer

Cross-platform portability is outside the accepted product boundary. An abstraction for hypothetical platforms would add code to every input, window, audio, and renderer path before a second platform is approved.

### Full source translation

Translating hundreds of thousands of lines would preserve implementation detail rather than game value. The project reconstructs each ledgered capability directly in the new model. Campaign content, editor source, multiplayer code, replay code, Osiris, DALLAS, and tools provide evidence and implementation order, not code structure.

## Local toolchain

The planning host is a base Mac mini with a 10-core Apple M4 CPU, 10-core GPU, and 16 GB of memory. It runs macOS 26.5.2, Xcode 26.6, and Apple Swift 6.3.3. The system reports Metal 4 support.

The separately downloadable Metal compiler component is not installed yet. Before the first shader build, install it through Xcode's supported component mechanism and record the resulting version. This is a future toolchain preflight, not a planning dependency.

## Consequences

The new product can be much smaller and easier to reason about than the original while still restoring the complete game and creator capability set. Binary community missions, old saves and demos, original editor files, and original multiplayer interoperability do not work. Native replacements provide behavior authoring, saves, replay, multiplayer, editing, and publishing without those contracts.

The result has no hidden legacy runtime: one host language, one renderer, one simulation model, one behavior system, one content representation, and one native platform.
