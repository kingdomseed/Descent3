# Architecture decision: native semantic translation

- Status: accepted, amended
- Date: July 18, 2026
- Authority: binding product architecture

## Decision

Build a complete Apple-native Descent 3 game and creator suite with the Swift 6.4 compiler toolchain in Swift 6 language mode and with MSL and direct Metal 4. Use the current Xcode 27 beta for initial product work and move to stable Xcode 27 when released without retaining a Swift 6.3 compatibility path. Reach that product through dependency-ordered semantic translation of the pinned released source, keeping the native player and editor runnable together as capability moves across.

The player targets arm64 Macs running macOS 26 or later and Metal 4-capable iPhone and iPad devices running iOS or iPadOS 26 or later. Apple GPU family 7 or newer is the candidate mobile release floor pending representative floor evidence. RevivalEditor, D3Import, and dedicated no-window hosting remain macOS-only. The concrete shells use AppKit or UIKit, and the product uses MetalKit, GameController, AVFoundation, AVAudioEngine, AVAudioSession, Model I/O, Network, CryptoKit, Foundation, and OSLog directly where applicable. UIKit owns the RevivalMobile application lifecycle and is its default UI framework. SwiftUI may host a bounded current view only when it has a concrete technical or product advantage and does not introduce another `@main`, lifecycle, navigation stack, state owner, renderer path, or unnecessary bridge around the Metal game view.

Shipping targets contain no C or C++ engine code, Objective-C++ bridge, Rust runtime, OpenGL renderer, SDL layer, Wine or Game Porting Toolkit runtime, Vulkan translation layer, Metal-cpp host, or native legacy module.

That shipping boundary does not make the source incidental. The C++ tree is the default translation specification for original data flow, ordering, formulas, resource dependency discovery and lifetime, gameplay, rendering, and editor workflows until the native counterpart is verified. [Source translation discipline](source-translation.md) defines file-level accountability and deliberate modernization.

The [roadmap](roadmap.md) and accepted contracts govern scope and phase order. The [current implementation plan](current-plan.md) is the single living execution-state record beneath them: it names the active slice, current blockers, next work, and developer ownership. The integration owner updates it as work lands or the active sequence changes; it cannot amend this architecture or become a competing source of product scope.

## Approved iPhone and iPad amendment

The prior rule targeted only macOS and listed iOS outside the roadmap. The user approved a binding product amendment on July 15, 2026: version 1.0 now includes one universal iPhone and iPad player while preserving the native Mac player and macOS creator product.

The selected replacement is a concrete UIKit `RevivalMobile` shell over the same RevivalCore, RevivalMetal, canonical package, scheduler, resident `Level`, save, replay, and multiplayer state used by RevivalMac. It is landscape-first, supports safe-area and drawable-size changes, samples touch and physical-controller input into the same explicit input value, and owns iOS/iPadOS scene, storage, audio-session, signing, and distribution behavior directly. UIKit remains the simplest default for the shell and ordinary UI. A localized SwiftUI component is allowed only under the bounded advantage rule above; converting the root shell or duplicating app state is a binding architecture change, not ordinary view implementation. This does not authorize a platform protocol, renderer backend, second loader, mobile scheduler, mobile package schema, or resident-Mac/streaming-mobile split.

D3Import remains the sole legacy-format reader and remains a macOS signed helper. RevivalMobile imports only Mac-produced canonical packages through the system file picker, validates and atomically installs them through the same native-package rules as RevivalMac, and copies them into app-owned storage. The mobile version 1.0 product therefore requires access to a Mac that can perform retail conversion. RevivalEditor and dedicated no-window hosting also remain macOS-only; the mobile player still receives applicable campaign, replay, listen-host, join, and stock multiplayer capability.

The initial mobile deployment target is iOS and iPadOS 26 or later, with Apple GPU family 7 or newer as the candidate release floor. Early target, generic-device build, simulator, and shared-path composition may proceed whenever useful. Missing physical devices, signing, or development-team setup does not block D3Import, shared Core and Metal work, RevivalMac, RevivalEditor, or any Phase 1–7 slice or phase. Required direct mobile integration begins in Phase 8; applicable multiplayer and release evidence follows in Phases 9 and 10. Before public beta or release claims Apple GPU family 7 support, the project verifies a representative floor-device matrix or raises the released floor to the oldest hardware it can support with evidence. The public distribution channel remains an evidence-gated release decision because rights, GPL obligations, App Review access to functional content, signing, regional availability, and the channel's enabled device families must be resolved without redistributing proprietary retail data. If the App Store is selected, App Store Connect availability is restricted to the approved iPhone and iPad boundary; visionOS and running the iPhone/iPad app on Apple Silicon Macs remain disabled unless separately approved and tested.

## Decision levels

Three kinds of statement must not be confused:

1. Product decisions define the Apple-native platform, complete game and creator scope, one-way retail boundary, rights rules, and absence of a shipping legacy runtime.
2. Current implementation decisions select one concrete path for the next phase. They remain binding while implemented and change through a recorded amendment, not through parallel options.
3. Research hypotheses identify questions to measure. They do not constrain production types, package schemas, or tests before evidence promotes them.

The resident authoritative world with source-faithful asset paging, the explicit old/new variable-time handoff, and the early shared editor/player loop are current implementation decisions. Spatial streaming and a fixed simulation tick are later hypotheses, not hidden Phase 1 requirements. The public Internet multiplayer topology is also a current research hypothesis: the product requires an affordable native Internet outcome, but no project-operated relay or service executable is preselected.

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

Call Apple frameworks directly. RevivalMac and RevivalEditor own AppKit; RevivalMobile owns UIKit and AVAudioSession. A bounded SwiftUI component, when justified by a current advantage, remains hosted by that UIKit shell and receives only the state it needs. Shared code receives canonical domain values such as the input snapshot and application transition, not a generic interface whose only purpose is hiding AppKit, UIKit, SwiftUI, Metal, GameController, AVFoundation, or Network.

## Rendering

Metal is the only renderer. There is no backend interface or fallback renderer. RevivalMac, RevivalMobile, and RevivalEditor all use RevivalMetal.

Start by translating the original visible result and traversal through a small explicit forward pass sequence:

1. lightmapped opaque world and models;
2. alpha and additive effects;
3. HUD, cockpit, and interface;
4. presentation.

Add mirrors, specular faces, scorch decals, procedural fire and water, volumetric lighting, declared blend modes, animated textures, UV sliding, destroyable surfaces, and other ledgered paths when the first source dependency and scene requires them. A complete effect inventory does not justify a render graph, generic material framework, deferred renderer, or second visibility architecture.

Indoor rendering begins with the released room-and-portal traversal and observable clipping rules. When the first outdoor island arrives, outdoor rendering begins with the released terrain representation, geometry LOD, and texture-segment selection with its UV, tile, and rotation behavior. Megacells are editor texture-pattern data, not an evidenced runtime LOD mechanism. Through Phase 7, representative native images and M4 profiles may support an explicit simplification while retaining the corresponding physical mobile validation for Phase 8; a missing device cannot hold the earlier island open.

## World loading and lifetime

The production load unit is one complete canonical `Level`, matching the original D3L world boundary. In Phase 1, D3Import converts the complete Training D3L and RevivalMac and RevivalEditor first load the resulting complete canonical `Level`; RevivalMobile may compile and compose that same proven path early, while Phase 8 supplies the required direct mobile integration evidence. One selected room is only the first visible and editable acceptance slice. A synthetic one-room level may be a focused fixture but never becomes a second package or runtime mode.

The current implementation keeps that authoritative level world resident until exit. It starts presentation preparation with the source-evidenced `PageInAllData` working set, then permits later source-reachable assets to be prepared directly from canonical content and retained for the rest of the level. The current package contains the complete level topology and every dependency reachable through the currently translated product path. It expands when a later phase makes another path executable, rather than analyzing all Osiris, matcen, and dynamic-spawn possibilities before their work begins. The runtime never reopens retail formats, and the design does not claim that every GPU resource existed before original level activation.

Both player shells and the editor use the same dependency rules and resident presentation path. For replacement, validate the successor's canonical CPU content while the current world remains active. At the commit boundary, stop new submissions, wait for final GPU use, and release the old presentation owner before preparing the successor. Failure before commit preserves the old world; failure afterward enters a clear unloaded error state. The design does not silently require two complete GPU level sets. An iOS or iPadOS memory warning may trigger this ordinary drain-and-release path and an explicit unloaded or recoverable error; it does not create partial eviction or a second mobile lifetime mode.

Do not add world cells, camera-demand envelopes, prefetch shells, stream blobs, LRU policy, or a resident/streaming switch. [World loading and residency](world-loading.md) defines the M4 and applicable mobile-development evidence gate after the complete playable Training Mission and its amendment rule. Before public beta or release claims the candidate Apple GPU family 7 floor, the selected lifetime path must pass representative floor evidence or the released floor must be raised. Streaming remains possible only as a measured replacement that leaves one path across platforms.

## Initial product and ownership graph

Phase 1 establishes four executable products around two required code-ownership boundaries. Work begins with D3Import, the shared ownership areas, RevivalMac, and RevivalEditor; RevivalMobile may compose proven shared work early and remains required for version 1.0, but direct physical mobile closure is deferred to Phase 8:

    D3Import
    RevivalMac     -> RevivalCore ownership + RevivalMetal ownership
    RevivalMobile  -> RevivalCore ownership + RevivalMetal ownership
    RevivalEditor  -> RevivalCore ownership + RevivalMetal ownership

D3Import is a separate signed macOS command-line helper launched for explicit retail import. `RevivalCore` and `RevivalMetal` name dependency directions and framework exclusions; the first real code decides whether either deserves a separate build target. Phase 0 researches an affordable 2026 Internet-multiplayer topology in parallel without shaping Phase 1 code. A later service target is added only if the accepted direction requires an operable public-service boundary. Target count is an execution result, not constitutional law; RevivalMobile exists because UIKit lifecycle, touch input, sandboxed storage, audio-session, signing, and distribution form a concrete application boundary, not to host another game implementation.

Each executable shell emits its own platform diagnostics directly and presents or reports structured source-linked failures returned by RevivalCore. RevivalCore may define domain error values, but it owns no logger, retained-log store, telemetry path, or upload service.

### D3Import

D3Import is the only shipping component that reads the supported owned retail containers and formats. It translates legacy naming, precedence, HOG, level, model, texture, lightmap, font, sound, score, movie, and related semantics into canonical native content as required by the current campaign slice.

It traces the original eager `PageInAllData` working set and the lazy-page paths reached by the currently translated product path, including object initialization and later matcen or behavior-driven spawns when those paths enter the product. It writes ordinary checked canonical files for one complete `Level` and its current reachable dependency manifest; it does not mislabel the historical eager pass as complete closure, invent a room-scope production package, or require future behavior analysis early.

### RevivalCore

RevivalCore contains canonical content, complete level-world values, simulation, collision, objects, AI, weapons, goals, behavior state, validation, saves, replay, multiplayer state, and package rules. It imports no AppKit, UIKit, Metal, AVFoundation, or retail-format code.

Start with concrete domain types and contiguous collections. The original file and global layout informs ordering and dependencies but does not dictate Swift module or type boundaries.

### RevivalMetal

RevivalMetal contains the concrete direct Metal renderer, resource creation, level-owned presentation lifetime, and MSL. It renders the same canonical world model for separately owned player, editor, and play-session values. It has no renderer protocol, general asset manager, or knowledge of retail formats.

### RevivalMac

RevivalMac owns the player application and its explicit session transitions, NSWindow and MTKView, display loop, input sampling, audio and adaptive-score presentation, movies, haptics, text input, profile and settings UI, file locations, signing, import UX, native-package intake and local-library lifecycle, operational-diagnostic presentation and retention, and level-load presentation. RevivalCore validates canonical package identity, revision, dependency and content relationships; RevivalMac stages, promotes, activates, disables, replaces, or removes packages and preserves the prior active set when intake fails. It composes RevivalCore and RevivalMetal directly.

A later no-window dedicated-host mode reuses RevivalCore without initializing rendering, audio, or player UI. It is not a second simulation framework.

### RevivalMobile

RevivalMobile is one universal UIKit player application for iPhone and iPad. It owns `UIWindowScene` lifecycle, `MTKView`, display callbacks, safe areas and supported drawable sizes, landscape presentation, touch and physical-controller sampling, AVAudioSession configuration and interruption or route handling, mobile profile and settings UI, app-owned file locations, canonical-package selection and intake, local-library lifecycle, operational-diagnostic presentation and retention, signing, and the accepted distribution channel. It composes RevivalCore and RevivalMetal directly.

The mobile shell never launches D3Import or reads a prepared retail installation. The user selects a Mac-produced canonical package through the system document picker; RevivalMobile copies it into destination-adjacent app-owned staging, applies the same hostile native-package validation and activation rules as RevivalMac, and preserves the prior active set on failure. Cancellation, revoked file-provider access, insufficient storage, background suspension, and orderly teardown have explicit outcomes. Durable install state is committed atomically before suspension; because abrupt process death may arrive without a cleanup callback, the next launch discards abandoned staging and recovers the prior active set. None of these cases creates a cloud service or second package mechanism.

Touch gameplay is mandatory for the mobile version. The Phase 8 mobile input packet selects one direct native mechanism against the then-current UIKit, GameController, Metal 4, and shared `InputSnapshot` paths; `GCVirtualController` is a candidate, not a pre-implementation architecture requirement. Ordinary UIKit touch remains responsible for interface interaction unless a bounded SwiftUI component has an independently justified current role. Touch and physical-controller values feed the same explicit input snapshot. UIKit scene transitions call the same typed Core pause, resume, load, play, failure, and completion transitions as the Mac shell. Suspension clears transient input, stops presentation work, coordinates audio, and rebases time on resume without catch-up. Platform adaptations remain concrete; there is no `Platform`, `Window`, `Audio`, `FileSystem`, or `InputBackend` abstraction whose only purpose is hiding Apple frameworks.

### RevivalEditor

RevivalEditor begins in Phase 1 as the permanent native AppKit document application. Its first world slice derives an editable project value from the read-only canonical base, displays it with the shared Metal path, supports selection and one real edit with named undo/redo, saves and reopens, starts a disposable play-session copy through the shipping loader and simulation types, and returns to the document. “Shared world” means shared types and production paths, not one mutable instance simultaneously owned by editor and play.

The editor grows slice by slice into world, terrain, game-data, behavior, campaign, presentation, baking, validation, playtest, and publishing workspaces. AppKit owns document, window, menu, undo, and accessibility behavior. Do not recreate those services with a generic reactive store, command bus, service layer, preview package system, or job framework.

Add immutable snapshots and stale-result checks to the first real asynchronous editor operation that needs them. Do not prescribe a universal generation counter, fixed overlay allocation, or background-document resource protocol before the product exercises those cases.

### Public Internet multiplayer

The required product outcome is native LAN and Internet hosting, discovery, joining, security, and explicit failure behavior from both player products without requiring the project to operate an unaffordable always-on service. Phase 0 examines current direct, player-hosted, community-operated, platform-provided, and third-party-supported approaches, including their real reachability, privacy, abuse, deployment, continuity, and recurring-cost properties. That work is a bounded research record and creates no Phase 1 transport types.

Phase 9 selects one operable topology through the [Internet multiplayer study](internet-multiplayer-study.md), then ratifies its transport, record protection, authority, prediction, outage, and operational contracts against the final simulation. Bonjour and Network remain the direct native starting point for LAN; RevivalMobile also owns the required local-network usage description, Bonjour service declarations, permission-denial recovery, and physical-device verification. The Internet path uses the native or provider boundaries selected by current evidence; CryptoKit is used only when that topology needs project-owned record protection. A service executable, relay, rendezvous system, or external integration exists only if the accepted topology needs it. The released source's 32 network/player-slot infrastructure and listen/dedicated slot accounting remain scale capabilities, while each stock mode initially preserves its source-supported player limit, including four-player campaign co-op. Dedicated no-window hosting remains a Mac-only application capability.

## Execution model

The first runtime uses one main-owner game and display loop. It explicitly passes the old `Frametime` and pre-update `Gametime` through systems and `EVT_INTERVAL`. After frame-cap waiting, it measures and stores the new duration, advances `Gametime`, then performs the remaining source-ordered tail work. It preserves the static/`InitGame` 0.1-second initialization and nested pause clock rebasing. No Swift code reads mutable global timing state. Moving measurement to callback start or advancing game time earlier would be a recorded modernization, not fidelity by default.

This explicit-delta scheduler is the one current implementation, not a permanent compatibility mode. Phase 3 captures and compares flight, collision, input ramp, interval, animation, and timer behavior. Before behavior breadth or replay depends on timing, the project makes one formal decision:

- keep explicit variable delta with ratified bounds; or
- convert to one fixed tick, translate every elapsed-time consumer once, and delete the variable scheduler.

Do not maintain both. A fixed tick rate, catch-up policy, interpolation rule, and deterministic numeric contract become binding only in that amendment.

The main owner holds mutable game state. Each concrete player shell samples its Apple input sources into one explicit value passed into the translated step. Background work is limited to operations that actually block: import, file I/O, media conversion, resource preparation, and real editor bakes or publication. Do not add a simulation thread, actor graph, task per entity, work-stealing scheduler, or lock-free queue without a measured missed budget.

## World and behavior model

Use explicit domain types such as PlayerShip, Robot, Projectile, Door, Pickup, Room, Portal, and Terrain. This is not a generic ECS. Begin with the source-supported relationships and ordinary Swift functions; change layout only after a measured loop benefits.

Behavior implementation starts with canonical direct typed Swift functions for the actual Training dependency chain, including generated DALLAS ranges and handwritten code. Preserve events, order, timers, variables, persistence, and engine operations required by the slice. Working evidence across generated DALLAS, handwritten/custom, timer or persistent-state, and presentation-oriented behavior selects the required version 1.0 reusable human-authored representation and its one runtime path. It is not a complete speculative VM designed before the first script runs. Broader mechanics or a later replacement executor require a concrete limitation and a new evidence-led decision.

Shipping packages never contain native executable code. Creator-facing behavior authoring must provide the useful DALLAS and Osiris capabilities without their generated C++, compiler integration, DLL ABI, or unrestricted engine function table; it does not predetermine a second runtime representation.

Flying AI begins by translating the released room/portal, outdoor-region, node, path, clearance, steering, and recovery semantics used by the first robot. Simplify or replace them only after observable routes and failure cases exist.

## Content, saves, and compatibility

The only legacy-format boundary is the macOS one-way importer. The game and editor consume canonical native content and never reach back into the retail installation. RevivalMobile consumes only a transferred canonical package. Version 1.0 requires a user-owned supported prepared retail installation and a Mac for conversion; additional source profiles, raw-media preparation, mobile retail conversion, and project-owned replacement assets are later decisions.

The product writes new native projects, packages, saves, and replay. It does not import or export retail saves or demos, provide original multiplayer interoperability, load binary modules, or export D3L/HOG/editor data.

Use the simplest current schemas. Add public migrations and semantic revision machinery when a released user-authored format or persistent state creates that obligation, not before. The first public native-package workflow still has an explicit hostile boundary: validate identity, rights metadata, hashes, declared dependencies, paths and bounded media before canonical construction; stage beside the destination; and atomically promote or leave the prior installed set untouched. This is a local content-library contract, not a marketplace, cloud account, automatic updater, or mandatory package-signing platform.

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
- generic cross-platform abstractions or platform backends; the approved concrete AppKit and UIKit shells are product targets, not a portability framework.

## Consequences

The project accepts that the first native code may look closer to the source semantics than the final product. That traceability is deliberate. Once a working slice and measurements exist, refactoring can remove legacy-shaped complexity without guessing about what it did.

The result remains one native implementation and product suite: Swift host code, MSL shaders, direct Apple frameworks, one renderer, one current scheduler, one current resource-lifetime path, one canonical world model, and one human-first creator application.
