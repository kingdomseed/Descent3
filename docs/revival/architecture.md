# Architecture decision: native Swift and Metal

- Status: accepted
- Date: July 13, 2026
- Authority: binding product architecture

## Decision

Build a complete new game and creator suite for Apple Silicon with Swift 6.3 host code and MSL shaders using the Metal 4 API directly. The product runs content converted from an owned Descent 3 installation and native creator projects, but it does not preserve the original engine architecture or executable interfaces.

The product targets `arm64` Macs running macOS 26 or later. It uses AppKit, `MTKView`, GameController, AVFoundation, AVAudioEngine, Model I/O, Network, CryptoKit, Foundation, and OSLog directly. Swift Package Manager owns reusable targets. `RevivalMac` and `RevivalEditor` are thin Xcode application targets for player and creator application packaging and signing.

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

The renderer uses `MTKView` so project code does not reimplement drawable and display-surface management that MetalKit already supplies. `RevivalMac` still owns the AppKit window and lifecycle. The renderer uses `MTL4CommandQueue`, device-owned `MTL4CommandBuffer` values, rotating `MTL4CommandAllocator` values, `MTL4ArgumentTable`, and `MTLResidencySet` directly from Swift. MSL shaders are compiled into a metallib for release builds. Metal-cpp supplies C++ bindings to these APIs; it adds no capability to a Swift host.

The initial renderer is a direct forward renderer with a small fixed pass sequence:

1. lightmapped opaque world and models;
2. alpha and additive effects;
3. HUD and interface;
4. presentation.

This initial sequence is not the final material or effect inventory. Imported and native content also require direct support for reflected room views, specular faces, scorch decals, procedural fire and water textures, volumetric surfaces and lighting, and the historical alpha-weighted additive and other declared blend semantics. Add each as the smallest explicit pass, material state, or update path that produces the required image. Their existence does not justify a render graph, deferred renderer, physically based material framework, multithreaded command encoding, MetalFX, ray tracing, or general shader system.

### World cells, streaming, and visibility

Every presentation-capable level uses one purpose-built presentation-streaming path. A no-window authority loads only `WorldSpine` because it creates no presentation resources. `RevivalCore` retains that complete finite spine containing durable identities, topology, portal and terrain adjacency, bounds, collision, navigation, authoritative objects, behaviors, objectives, and simulation state. Streaming state is not visible to simulation, saves, replay hashes, behavior, or multiplayer authority.

One indoor room is one stream cell. Outdoor terrain dimensions are positive multiples of 32 quads and divide into fixed 32-by-32-quad cells at authored resolution. Resident presentation-demand bounds conservatively contain each cell's room or terrain geometry plus every assigned static drawable. Each package layer emits one immutable raw indexed global blob plus a per-level blob where it contributes GPU-ready geometry, lightmaps, terrain, textures, or static presentation. Resolved locators name the package layer, blob, checked range, and closed project-owned buffer or two-dimensional-texture descriptor without copying untouched base bytes. Stack-global resources live for the current resolved player or key-editor content stack, dynamically spawnable or moving presentation resources are level-pinned, and static world records follow cell demand. The app residency-set object persists, but every level, content-stack, or key-document handoff cuts off old submissions, drains committed old-generation Metal I/O and final render use, retires the dynamic world, overlay, spine, allocations, and file handles, and only then replaces stack-global membership or begins loading a successor. The partition has no arbitrary streaming volumes, runtime LOD, mip streaming, or sparse-resource path.

`WorldStreamer` derives one desired set from the union of fixed orientation-independent spatial envelopes around every live camera plus complete destination envelopes for declared discontinuities. Dynamic doors and current orientation do not change residency. Demand runs once per active display callback. One prefetch shell is sized from maximum continuous camera speed times the maximum demand-evaluation interval plus certified worst-case completion of the entire maximum incoming `LoadWave` through render-frame installation. One asynchronous coordinator submits bounded `loadBuffer` and `loadTexture` work through one concurrent `MTLIOCommandQueue`; a completion handler transfers each successful command-buffer batch to the render owner for next-frame installation. The render owner retires outgoing allocations only after their last GPU use. Metal uses one app-lifetime residency set and one dynamically updated world residency set. There is no resident-only alternative, CPU presentation loader, LRU, memory-pressure policy, general resource manager, texture cache, or second visibility architecture.

The publisher bounds the complete resident spine, schema counts, each cell, every supported simultaneous game-camera profile, a conservative four-viewport editor envelope, each authored teleport, spawn, cinematic, mirror, or auxiliary-view destination, the load queue, and the movement lead-time inequality. Transient viewport positions and demand are local editor state, not published destinations. A room that exceeds the cell limit is split and an oversized authoritative mission is divided at a mission boundary. A finite level is not rejected solely because all of its streamed presentation bytes would not fit in active memory.

Indoor drawing still uses one CPU room-and-portal traversal with room-frustum rejection inside the fixed render radius, and Metal performs ordinary triangle backface rejection. That current-view traversal does not own residency. The product does not reproduce legacy face-by-face portal clipping, software occlusion, or renderer-specific survival heuristics. Outdoor cells render their full authored resolution without a terrain LOD hierarchy. [World streaming](world-streaming.md) fixes the package, lifecycle, failure, editor, and verification contracts. Changing that model requires an explicit architecture amendment.

## Target graph

Phase 1 creates the four runtime and import targets. Phase 2 adds `RevivalEditor`. Phase 9 adds the bounded `RevivalRelay` service required for complete Internet multiplayer; the complete product has six production and operational targets.

```text
target dependencies

D3Import ───────> RevivalCore
RevivalMetal ───> RevivalCore
RevivalMac ─────> RevivalCore
RevivalMac ─────> RevivalMetal
RevivalEditor ──> RevivalCore
RevivalEditor ──> RevivalMetal
RevivalRelay ───> Network + CryptoKit + Foundation only

process integration: Xcode package dependency, no module link

RevivalMac - - explicit import - -> bundled signed D3Import
```

`D3Import` writes canonical content. `RevivalMac` loads it through `RevivalCore` and presents it through `RevivalMetal`. `RevivalEditor` edits canonical project data and uses the same core and renderer for validation and playtest. `RevivalRelay` contains no game, content, renderer, audio, or editor code. Solid arrows are direct target dependencies; the dashed line is a small versioned command-line process contract, not a link dependency or general plugin protocol.

### `D3Import`

This is a signed Swift command-line helper bundled inside `RevivalMac`. It reads only the original formats required by the supported owned retail content and writes a canonical directory package. It depends on canonical content types from `RevivalCore`. No gameplay library links it. The `RevivalMac` Xcode target has an explicit build dependency on the helper, copies it into `Contents/Helpers`, and includes it in nested-code signing and archive verification. During an explicit import, `RevivalMac` launches the helper as a separate process, passes selected input and destination paths, and consumes its final report and exit status.

Legacy bitmap fonts, audio, and movie input require narrow project-owned Swift decoders for the exact `.fnt`, ACM, and MVE features present in the verified retail source profile. `D3Import` writes canonical glyph metrics, kerning and atlases for selected production font roles; Apple media frameworks encode and play canonical audio and movie outputs. The decoders exist only in `D3Import`, have bounded synthetic tests, and never enter the game process.

### `RevivalCore`

Contains canonical content and project types, the resident `WorldSpine`, immutable authoritative difficulty configuration, world state, fixed-step simulation, collision, objects, AI, weapons, logical cinematic and adaptive-score state, the behavior compiler and executor, validation, save and replay snapshots, multiplayer and chat policy state, and package rules. It computes pure spatial cell-demand, simultaneous-camera envelope, discontinuous-destination, and lead-time-validation values from canonical topology but imports no AppKit, Metal, AVFoundation, or legacy-format code.

### `RevivalMetal`

Contains the concrete renderer, `WorldStreamer`, Metal I/O and residency lifetime, and MSL. It consumes compact render snapshots and pure cell-demand values from `RevivalCore` for player and editor viewports. The same renderer encodes the main view plus the small bounded set of cockpit, rear, GuideBot, guided-weapon, marker, mirror, and editor views required by current content; there is no second renderer or general camera framework. It has no renderer protocol and no knowledge of original file formats.

### `RevivalMac`

Owns the player application, `NSWindow`, `MTKView`, display loop, input sampling, solo difficulty default, audio, adaptive-score scheduling, cinematic presentation, movies, GameController haptics, text-chat and operator input, player-selected media, file locations, settings, signing, packaging, explicit import UX, and explicit initial or discontinuous streaming progress and failure presentation. It composes `RevivalCore` and `RevivalMetal` directly and launches the bundled `D3Import` helper only when the user requests import or reimport. [Adaptive music](adaptive-music.md) fixes the boundary between deterministic score decisions and sample-clock presentation.

Dedicated hosting is a no-window launch mode of the same `RevivalMac` executable. That mode constructs `RevivalCore` session and network ownership, skips renderer, audio, and player UI setup, and emits structured server logs. Local input and authenticated encrypted remote administration invoke the same bounded typed `HostCommand` set; no Telnet service, shell, or arbitrary process execution exists. It is not a second simulation or a separate server framework.

### `RevivalEditor`

Phase 2 adds the native editor as a document-based content IDE, beginning with polished inspection and level navigation. Each `.revival` project is one `NSDocument` with one `@MainActor EditorSession`, one primary project window, one canonical project value, and one undo history. The shell uses a synchronized project navigator and world outliner, tabbed canvases, contextual inspector, and Problems, Activity, Playtest, and Trace pane. Each later gameplay slice adds its matching creation, validation, debugging, and playtest operations.

Concrete typed edit families are the only mutation route. Stable element IDs address rooms, portals, faces, objects, graph nodes, campaign nodes, and presentation elements. Each edit, undo, redo, revert, accepted recovery, or source-changing asynchronous result advances one transient monotonic `ProjectEditGeneration` for the open document. That value identifies an exact unsaved authoring snapshot; it is not a package schema, content semantic revision, `simulationSemanticRevision`, or compatibility promise. Completed human actions register named inverse operations with the document's `UndoManager`; continuous gestures coalesce into one undo action. Background USD or native-media ingress, preview-record generation, validation, baking, and publishing consume immutable snapshots and install results only when their generation still matches. Structured diagnostics carry stable codes, document and element identities, and source locations so selecting one opens and frames its owner.

The editor owns AppKit views, the session, and edit commands while `RevivalCore` owns canonical values, game rules, behavior semantics, validation, and publishing rules. `RevivalMetal` supplies the shipping streamer and renderer to every live viewport and playtest. Only the key project document owns world residency; background-document viewports pause. Generation-bound preview layers use the shipping package and blob schemas outside project source. One logical fixed-capacity noncanonical `DraftOverlay`, stored in exactly three frame-safe slices, lets the same renderer show the visible dirty-geometry union across all four supported editor viewports while stable IDs suppress corresponding last-good records. Gesture samples update only transient state and the next available slice; one commit produces one canonical edit, undo action, generation advance, and background preview candidate. There is no in-flight slice overwrite, editor-only stream format or resident renderer, reactive store, command bus, service layer, or legacy export mode.

One integrated application covers world and terrain editing, game-data definitions, `BehaviorGraph`, campaign and presentation authoring, asset inspection, lighting and navigation baking, dependency audits, play-in-editor, and package publishing. It is human-first. MCP transport, a headless editor, a public automation wire format, agent permission policy, training traces, telemetry, and agent-specific workflows are deferred until Phase 10 ships the complete human creator suite. A future adapter must reuse the same stabilized edits, validation, playtest, and publisher rather than create a second product path. [Native creator suite](creator-suite.md) defines the complete contract.

### `RevivalRelay`

Phase 9 adds one small no-window Swift service for public session discovery, expiring session registration, join authorization, and opaque packet relay. It runs on Apple Silicon and macOS 26 or later, imports no game content, renderer, audio, editor, or simulation code, and never becomes session authority. Separating this public attack surface from the signed player application removes more lifecycle and security risk than the sixth target introduces. Registration requires authority proof of possession, an unguessable route handle, a short lease, and bounded metadata. A single-use join token binds the session, client key, route, and expiry. The service enforces pre-allocation envelope limits plus per-source, per-session, connection, byte-rate, and amplification limits; the authority still makes gameplay-admission decisions.

Public Internet hosts and clients make separate outbound Network-framework QUIC connections to the project-operated relay. QUIC protects each hop. Above it, every authority-client pair uses one inner CryptoKit record protocol: ephemeral X25519 key agreement, a per-session Ed25519 authority key bound into the expiring registration, a signed handshake transcript, HKDF-SHA256, and separate directional ChaChaPoly keys. Each directional key has one global monotonic sequence across every stream, datagram, and logical channel in its connection epoch. Each bounded record's visible version, route, sender, recipient, channel, epoch, sequence, and length header is authenticated as associated data; the nonce derives uniquely from epoch and that global sequence. The receiver binds the key to its expected session, route, sender, recipient, and allowed channel roles and rejects a mismatched identity or authority-only channel, wrong-session, wrong-route, oversized, duplicate, stale, or unauthenticated record. Reconnect performs a new key exchange and epoch. The relay receives no session key and sees only connection metadata, opaque routes, lengths, and timing. Host and client surface the session-key fingerprint for explicit verification.

Reliable control traffic uses QUIC streams; time-sensitive input and state traffic uses QUIC datagrams. Bonjour-discovered LAN sessions use the same handshake, inner records, session messages, and authority path over a direct host QUIC listener. This is one gameplay protocol over two fixed routes, not a fallback transport. The design deliberately excludes ICE, STUN, TURN, inbound router configuration, direct-IP Internet hosting, and Game Center.

Every resolved local `InputFrame` receives a monotonically increasing sequence and intended simulation tick. Authority snapshots name their authoritative tick, highest processed input sequence, and the complete future-affecting predicted ship state: pose, linear and angular velocity, room or outdoor-region ownership, collision attachment and movement flags, and physics accumulators. Reconciliation restores that state and replays every later unacknowledged `InputFrame` through the production movement path. Each client retains exactly 256 input frames; an acknowledgment older than that window triggers a hard authoritative resync. Correction smoothing affects presentation only. Remote ships interpolate authoritative snapshots and use only the bounded extrapolation declared by the networked-simulation skill.

The service owns an operational budget, regional deployment, certificate and key rotation, privacy and retention rules, traffic-metadata abuse controls, health monitoring, and a tested outage contract. Encrypted chat and media moderation remain with hosts and clients. Loss of the discovery control plane blocks new registration, browse, and join while established relay data connections continue. Loss of one client-to-relay leg disconnects only that human and invokes the bounded session reconnect policy. Loss of the authority-to-relay leg or the relay worker carrying the route ends the Internet match with an explicit reason; there is no automatic regional migration or hidden transport fallback. LAN sessions are unaffected. Commodity Linux deployment is outside the platform boundary; operators use an eligible physical or cloud Mac.

The capacity contract is 2–32 connected human slots. Active combat and live observer modes each consume one slot; a listen host consumes one, while a no-window dedicated authority and `RevivalRelay` consume none. Supporting 32 combatants plus additional observers is outside this scope. Game Center is not the multiplayer transport or matchmaking layer: `GKMatch` is capped at 16 participants on the recorded SDK and does not make a custom dedicated host reachable.

Tests live beside these targets and follow the binding [red-green-refactor protocol](test-driven-development.md). A separate package, test-only product path, or test architecture is not needed.

## Execution model

The initial runtime uses one `@MainActor` game and display loop. `MTKView` drives presentation. A small accumulator uses a monotonic elapsed-time source and runs the simulation at a fixed 120 Hz; rendering follows the display and may interpolate camera and object transforms between simulation states.

Catch-up is bounded to eight simulation ticks per display callback. Excess elapsed time is discarded and recorded with a counter and signpost instead of creating an unbounded backlog. Pause, application suspension, occlusion-driven display suspension, window live-resize suspension, streaming stall, and resume clear the accumulator, pending input impulses, relative deltas, and held-key ramp state and rebase the clock. While stalled no tick or input frame is produced; readiness resumes from the controls currently held and never replays wall-clock time or pre-stall impulses.

This intentionally replaces the original variable-`Frametime` loop. There is no legacy timing mode.

The main owner holds mutable game state. One five-case difficulty value is immutable authoritative session configuration: the profile supplies the solo default and the multiplayer host supplies the session value. Input is sampled into one value-type `InputFrame` per simulation tick. Held keys, buttons, and controller axes are copied into every tick while held. Press/release edges and accumulated relative mouse or scroll deltas are ordered pending impulses and are consumed exactly once by the next simulation tick, even when one display callback runs multiple ticks. Background work is limited to importing, world-cell I/O, media decoding, immutable asset preparation, and editor builds. Complete streaming batches and editor results are installed only at their declared frame or matching-revision boundary.

The profile persists the keyboard ramp-duration setting. Live held-key ramp accumulators belong to `RevivalMac`, reset on focus loss, pause/resume, load, and control remapping, and never enter saves, authoritative hashes, or network state. Replay and multiplayer record or transmit the already resolved per-tick `InputFrame`, so the same movement path does not need a second ramp-state protocol.

Do not add a dedicated simulation thread, actor graph, task per entity, work-stealing scheduler, or lock-free queue until Instruments shows that the single loop misses its budget because of CPU work.

## World and simulation model

Use explicit domain types such as `PlayerShip`, `Robot`, `Projectile`, `Door`, and `Pickup`, stored in contiguous collections with small stable integer IDs. This is not a general ECS. The data may move toward struct-of-arrays storage only when a measured loop benefits.

Simulation rules are ordinary Swift functions and small state machines. The behavior system compiles typed visual graphs into compact ordered instructions executed by the simulation owner. Randomness comes from one seeded generator owned by the simulation. Simulation time is expressed in integer ticks wherever practical.

There is no general event bus. Behavior events use one ordered FIFO owned by `RevivalCore`; audio and presentation receive small typed command lists at frame boundaries.

### Volumetric navigation

Flying AI uses a purpose-built two-level graph, not a floor navmesh, voxel world, or general navigation framework. The first level is deterministic room, portal, and outdoor-region connectivity with traversability, dynamic blockage, and clearance. The second is a bounded sparse three-dimensional waypoint graph inside each region, with node clearance and swept-volume-valid edges. A stable A* order chooses a route; local steering follows its segments; blocked doors and forcefields invalidate edges; one bounded stuck-recovery path requests a replan.

Hand-authored spatial paths remain a separate canonical tool for cinematics, set pieces, patrols, and exact orientation. The editor owns both path authoring and navigation diagnostics, but it does not expose the graph implementation as a generic engine subsystem.

## Numeric semantics

Authoritative scalar, vector, and orientation state uses Swift `Float`, which is IEEE-754 binary32 on the supported architecture. Import, authoring, behavior, save, replay, and network boundaries reject NaN and infinity. Each domain declares its valid magnitude and clamp or failure rule. Values smaller than `Float.leastNormalMagnitude` normalize to positive zero when committed to canonical persistent or hashed state, and negative zero also normalizes to positive zero.

Authoritative operations execute in declared order without fast-math transformations. Every authoritative multiply-add site declares fused `addingProduct` semantics or separately rounded multiply-then-add semantics; exact release-build vectors protect that choice. System and SIMD transcendental functions do not feed authoritative state directly. When a required rule needs one, the project adds only the smallest versioned approximation or table for that named operation and protects it with exact bit vectors. A replay under the same `simulationSemanticRevision` compares canonical normalized Float32 bit patterns exactly. The project does not add fixed-point arithmetic or a general deterministic-math library.

An OS, Swift compiler, SDK, optimization-setting, or supported Apple-Silicon change must pass the authoritative arithmetic corpus and same-revision replay hashes before adoption. A changed result is rejected or receives an explicit `simulationSemanticRevision`; it is never accepted as incidental compiler drift.

## Saves and settings

The game writes new versioned snapshots for saves and replay. Each binds a simulation semantic revision, the authoritative difficulty value, and the content revisions it uses. Snapshots carry logical cinematic state when a sequence is active but no renderer or framework objects. They do not contain live object pointers, Swift memory layouts, renderer resources, audio-engine state, interpreter addresses, or legacy bytes. Schema changes inside the new project use explicit version handling when an existing public save, replay, or creator project requires it.

The product does not import or export retail saves or demos. Settings use native Foundation storage unless a concrete need requires another format.

## Licensing and data rights

Project code derived from or translated from the released source remains compatible with GPL-3.0-or-later. The original source files state that license choice. New code should use GPL-3.0-or-later unless a later legal review establishes another valid boundary.

Retail art, audio, movies, maps, and related media remain proprietary. Neither original nor converted retail media enters Git. Replacement content needs its own documented rights.

## Rejected directions

### Incremental C++ and OpenGL port

This is the fastest route to a conventional port, but it preserves the architecture the project wants to replace. It also makes the old renderer and native modules permanent constraints. The completed native OpenGL build remains useful evidence, not the product base.

### C++ with Metal-cpp

Metal-cpp is a header-only C++ binding over Metal's Objective-C interfaces. It is appropriate for a C++ host but supplies no Metal feature that Swift lacks. Retaining it would require a C++ core, a second ownership model, and a bridge to the native application and editor solely to preserve implementation the project has rejected.

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

Xcode currently resolves the separately installed Metal toolchain, and `metal --version` reports `32023.883`. Phase 1 still begins with a minimal MSL compile, metallib link, `MTL4CommandQueue` submission, argument-table binding, residency-set use, rendered triangle, capture, and validation smoke. Tool presence alone does not close that preflight.

## Consequences

The new product can be much smaller and easier to reason about than the original while still restoring the complete game and creator capability set. Binary community missions, old saves and demos, original editor files, and original multiplayer interoperability do not work. Native replacements provide behavior authoring, saves, replay, multiplayer, editing, and publishing without those contracts.

The result has no hidden legacy runtime: one host language, one renderer, one simulation model, one behavior system, one content representation, and one native platform.
