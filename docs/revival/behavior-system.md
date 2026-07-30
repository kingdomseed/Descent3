# Behavior translation and authoring

- Status: accepted, amended
- Date: July 15, 2026
- Authority: binding current behavior-transfer and eventual creator contract

## Historical boundary

Osiris was Descent 3's native compiled-module behavior runtime. It loaded game, mission, level, and object modules; dispatched events; exposed engine functions; managed timers; and persisted module-owned state.

DALLAS was the visual event, condition, and action editor layered over Osiris. It stored a structured tree, generated C++ and message tables, invoked a compiler, and permitted handwritten code around generated ranges.

The revival must preserve useful event, condition, action, timer, state, debugging, persistence, and authoring capability. It does not preserve DLL loading, native package code, ABI tables, generated C++, compiler invocation, or unrestricted engine access.

## Current decision

Do not design the complete replacement interpreter before a real stock behavior runs. Version 1.0 must reproduce the evidenced behavior and creator capability of the shipped game and tools; it does not promise broader mechanics or a particular visual or textual authoring form before translated evidence makes that bridge real.

Phase 4 proceeds through separately censed chronological Training chains. The opening chain creates the welcome timer and handles first ForwardGoal contact. The gallery chain consumes the one-shot player-center `Portal2` pass-through, closes both sides of the `PortalRoom4` force field, presents `GoodJob` then `GBIntro`, and disables controls. The robot/Guidebot chain reaches exact primary-laser death, Script 036's barrier/timer result, F4 birth, same-update Script 060 and one concrete route/movement result. The Camera Monitor chain collides with handle 6167, completes the exact enabled object item and goal status, holds and uses its object-backed inventory identity, then presents the ten-second SecurityCamera gunpoint view and reached completion no-op. Its return and Portal3 continuations preserve the separately censed Script 058 and Script 042 → timer-14 Script 039 results. Scripts 043–046 independently remove the four exact RASBot death targets through the existing primary-laser carrier. Script 047 independently collides with and consumes exact `InvulnPowerup2`, persists its mission one-shot, runs the stock 30-second invulnerability state on the historical variable delta, and presents activation, remaining state, the released aspect-correct ship-monitor ring and expiry. Script 048 similarly preserves a separate mission one-shot and default `CloakPowerup2` consumption, then runs the released 1-second fade-out, 30-second fully cloaked and 1-second fade-in phases with exact alpha reaching the existing auxiliary Camera Monitor observer; the fully cloaked observer draw also applies the released 0.1 radial deformation. The existing AppKit owner presents HUD/audio plus complementary native vector ship-monitor/`CLK` opacity during the released last-three-second cosine cross-fade. The released AI/headlight visibility formula remains source-accounted and deferred until a real live perception carrier reaches it, rather than surviving as a test-only helper. Because Script 048 can be the sixth producer, the same interval frame runs Script 034 in exact portal `[1,0]`, marker-distance-50, timer-9 order; the two-second timer then runs Script 049's two HUD messages and `proceed5.osf` once. Script 050 is the next separate island: the first player-center `Portal4` pass-through after Script 034 sets FlashLight-4 to zero, presents `GoodJob`, closes PortalRoom6 portals `[1,0]` on both sides behind the player, starts exact `intro7.osf`, presents `FinalSessionIntro`, and persists without replay. Script 049 need not have presented and its pending timer continues. Scripts 051–055 then independently remove exact `LastBot1` handle 4127 in room 14, `LastBot2` handle 2080 in room 46, `LastBot3` handle 2081 in room 47, `LastBot4` handle 2082 in room 47 and `LastBot5` handle 2083 in room 48 through the existing nearest-hit primary-laser carrier; each latches only its own dying producer and persists its absence without implementing the conditional all-five aggregate. Pickup and use feedback remain ordered voice/sound/HUD effects, and audio-start failure cannot suppress later DALLAS effects. Training contains no `RoomDoor`; these concrete chains do not claim the general door, combat, live AI, inventory, effect or auxiliary-view families. Ordinary typed Swift functions and small explicit state values inside RevivalCore remain the canonical current runtime form. The source ledger retains each finite generated, custom, handwritten, initialization, persistence, producer and editor-play census; Script 035 → timer-10 Script 056, Script 057, later Training and broader families remain separate evidence-led islands.

The later maneuver-and-follow lesson remains another concrete typed chain rather than selecting the permanent behavior representation. Scripts 021, 022, 024 and 023 preserve their released marker and timer order while enabling heading, pitch, bank and then all rotational controls. Script 023 powers and reteams stock `FollowBot1`, assigns the existing 13-node `FollowLoop1` static path and starts its object timer. Script 025 runs on every eligible level interval and applies only the released strict 90-degree player-forward cone (`dot > cos(45°)`), restarting the full timer when false without an occlusion query. Timer Script 026 unions weapon controls, redirects the same carrier to the one-node `GoToDie` path and ends at the destroy-the-bot instruction. One direct variable-delta simulation state preserves authored node progression, source velocity/turn limits, room-local collision, orientation, timer coincidence and silent continuation. It does not use the dynamic Guidebot route, add general AI/pathfinding or make stock paths creator-owned.

The current independently censed Phase 5 chain reuses the sole primary-fire and indoor-contact owner only after Script 027 has made DestroyBot1 visible and moving. One fixed volley spends `0.15` energy no more often than every `0.25` seconds and visibly presents two exact Level 2 Blue bolts through retained object draws; each applies `7.5` damage until the strict-below-zero real dying event. DestroyBot1's dying-only Script 028 preserves the exact predicate `counter028 < 1 && counter027 > 0` and exact order: unghost DestroyBot2, assign the existing FollowLoop1 path 0 with flags `0x801100`, goal `-1` and priority `3`, then increment counter 028 last. Only after that callback has completed, DestroyBot1 is dead and DestroyBot2 is visible, present and moving may the same normal carrier target DestroyBot2. Four two-bolt volleys cross its 55 shields below zero. Custom ordinal 12 ignores teardown and non-dying dispatch; real death invokes unconditional Script 036 in exact order: create level timer 12 at two seconds, set FlashLight-2 distance 50, clear PortalRoom4 portals `[1,0]` and both reciprocals, enable every player control and increment counter 036 last. Timer 12 begins consuming old `Frametime` on the next update, and timer-only Script 029 presents `Excellent!`, then `Now go through the open doorway, and into the next room.`, hides enabled-control help, starts exact `proceed5.osf` and increments counter 029 last. The next normal player-center pass through `Portal2` executes exact Script 032: attempt `GuideBotA.osf`, extinguish FlashLight-2, re-close PortalRoom4 in `[1,0]` order on both sides, present `Excellent!` then the F4 Guidebot instruction, disable every flight control and consume the one-shot last. Script 032 clears the existing current-state controls-restored latch so this later action wins immediately and during silent restore; the coherent earlier gallery → later Script-036 ordering remains valid. Existing marker distance distinguishes the two supported histories after an already landed F4/Script-060 result: a still-later Script 036 is open/light 50, while Script 032 followed by Script 060 remains closed/light 0. Contradictory light/barrier/control combinations fail closed. Guidebot remains hidden and undeployed and Script 060 remains unpresented at this packet boundary. The existing top-level robot/Guidebot state remains the sole death/timer/feedback owner; the nested maneuver value retains only Script-028 visibility and authored motion and is reconciled to hidden, stopped and absent when the top-level death becomes true. Optional schema-7 restore accepts the absent object only for a coherent reached ordering, restores the matching reciprocal barrier/light/control state without replay and rejects impossible cross-state combinations. Older packages with no destruction handoff retain the landed robot behavior and no schema or canonical field changes.

The separately censed first Phase 5 Guidebot command and return-completion path now extends that same deployed object through the exact first active primary goal, physical goal-1 arrival, live-player return and physical goal-2 circle-30 completion. `PlayerSimulation` directly owns the first authoritative random stream: a new session begins from one explicit seed, advances the released wrapping `state * 214013 + 2531011` transition and persists its current state in continuation schema 7. F4 birth consumes the released flare and visibility draws; the normal active-primary command remains unavailable throughout birth and becomes available only after the strict transition to ambient; the real variable-delta mode and due-timer path then consumes only the ambient, powerup, visibility and flare draws it actually reaches. On goal-2 completion, the existing goal-1-used proof consumes one draw for exact `GB: Come on!` or `GB: Let's go!`, routes `GBotGreetB1` through the existing low-priority message cooldown/audio owner, and always consumes the immediately following draw for the persisted next-flare delay. The persisted cooldown timestamp cannot exceed saved game time; coherent older deployed and entered-ship continuations still normalize silently, while partial new timing without the stream fails closed. The packet stops with the same visible Guidebot escorting the live player and no flare fired. This preserves the released greeting-to-later-flare coupling. A presentation-only random split is recorded only as a potential future opt-in amendment requiring before/after checkpoints plus save, replay and network-hash decisions; it is not implemented, selectable or retained as a second mode or stream.

The direct translation is tracked in the source-translation ledger and remains the current runtime while concrete human-authoring cases select the required version 1.0 model and its one executor. Before selecting that representation or changing the executor, working translated evidence must cover:

- at least one generated DALLAS chain;
- at least one handwritten or custom range;
- at least one timer or persistent-state chain;
- at least one presentation-oriented chain.

One chain may cover several categories. By version 1.0, that evidence selects the smallest reusable human-authored native model and single runtime path that can:

- express the verified stock chains without special cases;
- be authored and debugged by people;
- serialize safely in native projects and packages;
- cover source-evidenced creator-tool operations beyond those exercised by the current stock chains;
- execute without native code or unrestricted platform access;
- preserve the current tests and observable checkpoints.

The accepted model lets people compose the evidenced DALLAS capability without editing Swift or generated files. Its representation is not preselected. If it replaces the early direct-chain runtime, it migrates the working chains and removes the superseded path; the project never keeps direct and interpreted execution as permanent parallel modes.

Any later source or executor types are named only when an evidence-backed amendment selects their real responsibilities. Possible future names are not current architecture.

## Translation unit

Translate one complete behavior dependency chain at a time:

1. identify its module, DALLAS block, custom ranges, handwritten ranges, messages, bindings, and engine functions;
2. trace event producers, dispatch order, conditions, state, timers, and side effects;
3. capture observable checkpoints in the reference engine or source;
4. write one focused automated contract and observe its intended failure;
5. implement the smallest typed Swift state and functions that make that contract pass;
6. expose the current configuration and diagnostics in RevivalEditor;
7. save, reload, play, and verify it through the applicable integrated paths;
8. refactor without changing the protected result, record every deliberate difference, and close the involved source ranges.

Do not translate generated DALLAS control flow while ignoring handwritten code outside the block. Do not add an operation merely because it exists in the global function table; add it when a real translated or creator scenario needs it.

## Current semantics

The first translated chains use:

- explicit typed events for the events they actually consume;
- ordinary Swift values for booleans, integers, finite Float32 values, vectors, content references, entity references, and current timers;
- direct validated RevivalCore queries and commands;
- explicit stable dispatch order copied from the source path;
- one simulation owner and no task, actor, or thread inside behavior execution;
- an explicitly accounted simulation-owned random source when the original chain uses randomness; the historical process-global `ps_rand` stream, including presentation reseeds and consumption, is traced before any call site is separated, so a native authoritative/presentation split is a recorded deliberate semantic difference rather than an invisible cleanup;
- explicit state included in new saves when that state affects continuation.

Do not prebuild:

- a universal event bus or complete event enumeration;
- synchronous request and reply machinery;
- a general stable collection value;
- entity generations for references that do not need them;
- a 4,096-operation ceiling or speculative call, loop, timer, and storage budgets;
- a complete multiplayer authority type system;
- a bytecode optimizer or generalized compiler pipeline.

Add a bound when an actual untrusted creator construct or reproduced cycle needs one. The bound protects the reachable operation and receives a focused test.

## Timing

Historical interval handlers run once per historical frame and receive the old `Frametime` and pre-update `Gametime` through the surrounding engine. Phase 3 captures that ordering, rate multiplication, timer boundaries, frame-count behavior, and observable drift before selecting the one final scheduler.

The first Phase 4 behavior chain implements the selected sole variable-delta scheduler directly. Its timer consumes the previous stored `Frametime` and pre-update `Gametime`; after the already-ratified cap/sample handoff, the new duration is stored and `Gametime` advances. A one-second timer therefore fires only after ten initial 0.1-second historical deltas. The disposable Phase 3 harness is absent, no fixed-step or dual behavior timing path exists, and presentation-only HUD/audio remains outside authoritative state.

## First native chains

Schema 9 carries one typed `TrainingOpeningLesson`, one concrete `TrainingGalleryBarrier`, one concrete `TrainingRobotGuidebotChain`, the stable ForwardGoal, exact marker, robot, stock laser and Guidebot identities, exact English message bindings, the reached verified indoor boundary-node graph, and five canonical PCM clips with HOG entry, archive, source SHA and PCM SHA provenance plus matching dependency-manifest records. D3Import alone reads the released `.msg`, OSF/ACM, OOF/page and D3L `NODE` forms. It promotes retired D3L handle 6164 into the one hidden canonical `GuideBotB`/`Buddybot.oof` identity required by the source's existing-buddy birth, so retained Metal preparation includes that identity before F4. RevivalCore owns the hidden-but-collidable ForwardGoal presentation state, level-start and destruction timers, swept nonblocking contact, one-shot states, zero-radius center trigger passage, two-sided primary-and-reciprocal portal/force-field mutation, marker distance, robot shields/removal, two-shot laser volleys, Guidebot deployment and movement, enabled-control transitions, control-help visibility and Codable continuation. Independent collision and timer results survive a same-frame coincidence in source order. The gallery trigger executes after movement and room transfer and before the existing level-timer tail. A normal primary-fire request is consumed before object and level interval work; the exact Pyro gunpoints launch two Level 2 Blue bolts at 225 units/second, costing 0.15 energy per volley with a 0.25-second wait. Radius-aware indoor traces and segment-sphere contact apply 7.5 shields per bolt; strict shields below zero produces the dying destruction event, removes `DestroyBot2`, opens the barrier, restores marker distance 50 and controls immediately, then the two-second timer consumes the previous systems duration before presenting `GoodJob`, `ExitManuveur`, hiding the enabled-controls help and playing `proceed5.osf`. The same retained renderer presents the reached `gyro.OOF` robot with its source `$rotate=`/`RANI` axis evaluated from pre-update `Gametime`, plus the exact `SecFlyLit-Flashers000` texture slot, before removal. F4 moves and unhides canonical handle 6164 at its released pre-object point, so Script 060 observes the deployed type-2 Guidebot in that same update, replaces the active stream with `GuideBotB.osf`, restores controls, and presents `GetCameraMonitor` once. RevivalAppKit renders the ordered Core messages in a dynamically sized virtual-4:3 region and uses one direct AVFoundation player in both RevivalMac and disposable RevivalEditor play. That single owner preserves the released `StreamPlay` replacement rule for coincident calls; a failed voice start remains nonfatal.

The reached creator path uses the existing stable object handle and portal identities. ForwardGoal retains object placement/configuration and named `Move Object` undo. Selecting any gallery-barrier portal uses one concrete atomic two-sided edit with source-linked `TrainingMission.cpp Scripts 036 + 060 / DestroyBot2 + Guidebot` diagnostics, its verified `NODE`/BOA route status and Guidebot clearance, named `Set Training Gallery Barrier` undo, deterministic save/reopen and disposable play/return. Triggered play mutates only its copy, including robot shields/removal, projectile state, Guidebot deployment/movement and their continuation state. These concrete bindings do not preselect the permanent authored-behavior representation. Guidebot birth copies the live player room, pose and orientation, inherits player velocity plus forward times 40, unghosts the existing buddy, removes its inventory identity, and installs the player-forward-times-200 goal with circle distance 1. Route allocation first uses a radius-aware direct indoor trace; when blocked it deterministically uses verified boundary nodes and reciprocal-portal room connectivity. The accepted correction deliberately consumes that blocked same-room allocation instead of preserving the released `AISR_SEES_GOAL`/B-line shortcut that could bypass it and stall against the obstruction. Movement steers toward each ordered route point, advances its persistent point index after passing the source path-node plane, and continues through the existing radius-aware collision and room owner before returning to the final goal. Steering changes velocity by at most `maximumDeltaVelocity * old Frametime`, does not clamp inherited overspeed after that delta, and uses the same bounded delta toward zero after circle completion. Continuation validates the saved route against the closed barrier allocation state before applying the later destruction/open-barrier mutation to the restored world, and a mid-route save resumes point-for-point deterministically. This is one concrete dependency through the existing level, collision and simulation owners, not an AI executor, generic navigation service, bake framework or broader robot family.

## Engine queries and commands

Queries read typed RevivalCore state. Commands request named validated state changes. Start with the operations required by the current chain: objects, players, rooms, doors, triggers, AI, paths, goals, inventory, weapons, sound, messages, cameras, cinematics, score state, campaign flow, and difficulty as they appear.

Prefer composition from existing operations. Add a direct domain operation when composition would obscure source behavior, duplicate substantial logic, or prevent useful validation. Never add arbitrary Swift, file, socket, process, pointer, reflection, framework, or native-module access to project content.

Presentation loading and residency are not behavior state. Behaviors may request a teleport, spawn, camera, or cinematic once those are real domain commands; they never inspect resource readiness or memory.

## Stock evidence

The pinned GPL source is the default stock behavior baseline. Retail execution is comparison evidence for ambiguities.

The retained tree includes 48 generated campaign sources with reloadable SCRIPT_BLOCK structure among 55 built modules, plus custom and handwritten ranges. DallasFuncs metadata describes a broad action, query, and enum vocabulary, but metadata presence does not prove a reachable stock use.

A nonshipping extractor may recover DALLAS structure and source ranges into a review report. Its output is draft evidence, not canonical product behavior. It does not run inside D3Import or RevivalEditor, mark translations approved, or generate shipping code.

Every translated chain records:

| Field | Purpose |
| --- | --- |
| Scope and owner | Level, campaign, object, trigger, game, or mode responsibility |
| Source paths and hashes | Generated, custom, and handwritten provenance |
| Baseline commit | Default inspectable semantics |
| Events and order | Producers, handlers, default behavior, and ordering |
| State and timers | Values that affect continuation |
| Queries and commands | Actual engine surface used |
| Content bindings | Durable references required by the chain |
| Observable checkpoints | Runtime and editor evidence |
| Deliberate differences | Approved correction or modernization |
| Native form | Direct typed functions in the current slice and the evidence-ratified version 1.0 authored representation when selected |
| Ledger state | Use the source-translation ledger states: seed, traced, translating, native-running, verified, replaced, excluded, or deferred |

Known defects and dormant fields do not transfer automatically. Each correction records a decision and checkpoint.

## Authoring evolution

The first editor behavior surface configures the bindings, parameters, and explicit state consumed by the translated Swift chain and provides source-linked inspection, trace, and failure navigation. Its control flow remains canonical direct typed Swift. It does not introduce a graph canvas or claim a complete authored language.

As working human-authoring cases establish the representation and responsibilities of the required version 1.0 model, RevivalEditor adds:

- typed events, values, conditions, actions, variables, timers, functions, and composition as real needs establish them;
- source and content reference validation;
- search, documentation, traces, breakpoints, watched values, and source-linked errors;
- save, reopen, playtest, publishing, and deterministic scenario evidence;
- explicit authoritative and presentation roles when multiplayer work reaches those chains.

Behavior message catalogs are part of that authoring surface rather than incidental generated text. Creators can add, delete, rename and edit named messages; references update safely or fail with source-linked diagnostics; the exact supported locale and English-fallback matrix is explicit; and save/reopen, preview and package validation prove that displayed text remains attached to the intended behavior. Historical import/export buttons are workflow evidence, not a requirement to preserve the old message-file format.

When an authored form is accepted, it is the truth. If that design has compiled or generated data, the output is derived and never hand-edited; authors do not invoke a native compiler.

## Persistence, replay, and multiplayer

Save the smallest behavior state required to continue the current translated world: relevant variables, execution counts, timers, durable operation state, and content identity. Do not store interpreter pointers, call stacks, framework objects, or opaque legacy payloads.

Replay and multiplayer semantics are ratified after the final timing and behavior models exist. The host remains authoritative for game-changing behavior; clients may later execute explicitly presentation-only work. Historical game-side and client-side events are classified one by one rather than inherited from their names or numeric IDs.

The historical RNG is one shared process-global stream used by gameplay, replay, multiplayer and some presentation code. Translation records seed ownership and observable consumption order for every current chain. If presentation consumption changes later authoritative choices, preserve that coupling until an approved deliberate difference supplies before/after checkpoints; if evidence supports separating presentation randomness, the final model has one authoritative stream included in save/replay/network evidence and presentation randomness excluded from authoritative hashes. Do not silently substitute a platform RNG or add a general random-service abstraction.

Add compatibility revisions when a released save, replay, behavior project, or package creates a real promise. During development, reimport or republish may replace unreleased formats.

## Extensibility

The version 1.0 mod SDK documents the canonical behavior source, safe domain surface, validation, debugging, packages, and publishing required by the evidenced shipped-game and creator-tool capability.

If a later creator capability cannot be expressed safely, extend the typed domain model when that capability becomes accepted scope. Do not speculate beyond the current game merely to advertise extensibility, restore native modules, or create a privileged project-only escape hatch.

## Verification

For each current chain, tests and evidence cover:

- complete generated and handwritten source-range accounting;
- event order, conditions, state changes, timers, random choices, and engine effects;
- authoritative seed and consumption order, plus the recorded disposition of every presentation random call that could perturb the historical shared stream;
- behavior under the selected final scheduler, with the historical explicit-delta result retained as characterization evidence and every deliberate timing difference recorded;
- save/load continuation and source-linked failure;
- editor configuration, trace, playtest, and package closure;
- the exact checkpoint that justifies each deliberate difference;
- migration and deletion evidence if an accepted authored executor replaces direct typed functions.

Tests for the required version 1.0 authored representation and executor arrive when working evidence selects those production mechanisms. Later limits, authority rules, and debugging extensions arrive with the mechanisms they protect, not as speculative coverage of an imagined complete language.
