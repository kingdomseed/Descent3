# Functional completeness

- Status: accepted, amended
- Date: July 15, 2026
- Authority: binding product-scope contract

## Governing rule

The revival rebuilds every required player-facing and creator-facing capability in a modern native form. The released source is the initial semantic transfer map: reachable behavior, data flow, update order, and creator outcomes are preserved or deliberately changed with evidence. Legacy ABIs, platform APIs, file formats, protocols, UI structures, and incidental implementation details are not permanent product requirements except at the one-way retail import boundary.

KISS constrains implementation, never product scope. A smaller implementation must deliver the same capability. Removing the capability is not simplification.

Campaign-first development controls sequence. The evidenced shipped game and creator tools define the required version 1.0 capability. Broader mechanics, import sources, replacement content, and creator power remain possible later decisions rather than speculative 1.0 scope.

## What compatibility means here

The project distinguishes functional continuity from technical interoperability:

| Historical mechanism | Required modern capability | Compatibility requirement |
| --- | --- | --- |
| Descent 3 runtime | Complete native game behavior | No original executable or engine ABI |
| Osiris native modules | Safe, expressive, deterministic gameplay behavior | No DLL loading or Osiris ABI |
| DALLAS | Reusable human-authored native behavior composition and debugging sufficient to reproduce the evidenced shipped-game and creator-tool capability without Swift or generated-file editing | No generated C++ or compiler pipeline; no premature graph, text language, or second executor |
| D3Edit | Complete world and level creation | No MFC UI or D3L export |
| Game-data dialogs and page database | Typed content-definition editing with reference integrity | No check-in/check-out page system |
| Briefing Editor and TelCom tools | Briefing, cinematic, and presentation authoring | No original editor format required |
| HOG tools | Validated dependency closure and deterministic publishing | No HOG output |
| Original multiplayer | Native multiplayer and dedicated hosting | No original packet or server interoperability |
| Original demos | Native replay and recording | No legacy demo-byte compatibility |
| Original saves | Complete save and resume behavior | No legacy save import or export |

One-way import may preserve enough historical meaning to reconstruct owned content. Nothing flows back into the original formats.

## Definition of a complete feature

A game feature is complete only when all applicable paths exist:

1. the runtime can execute it;
2. `RevivalEditor` can create and configure it;
3. validators catch invalid state and broken references;
4. play-in-editor can exercise it without a packaging detour;
5. the publisher can include it in a dependency-closed native package, either with explicit canonical base-package dependencies or, when every asset is independently supplied, as a standalone package.

For example, a door is incomplete if an imported door works but a creator cannot place, configure, validate, and test a new one. This rule applies to geometry, terrain, materials, objects, AI, weapons, triggers, paths, goals, lighting, audio, presentation, campaign flow, multiplayer modes, and behaviors.

Pure runtime concerns such as controller input do not need an editor panel. Pure editor concerns such as selection history do not need a gameplay representation. The team records why a path is inapplicable instead of silently omitting it.

Creator completeness includes the quality of the human workflow, not only the presence of data types. `RevivalEditor` must provide a native document lifecycle, predictable synchronized selection and focus, direct and numeric editing, discoverable menu and keyboard commands, named undo and redo, source-linked diagnostics, revision-safe background work with cancellation where supported, playtest state restoration, crash recovery, source-control-safe saves, Full Keyboard Access, VoiceOver coverage, and measured responsiveness on the M4. A modal dialog or hand-edited file does not close a creator row when the integrated workflow remains incomplete.

Every new or changed production behavior used to close a completeness row follows the binding [red-green-refactor protocol](test-driven-development.md). Completion evidence records the focused test that failed for the intended reason before implementation and passed afterward. An inapplicable path receives no manufactured test; the ledger records why it is inapplicable.

## Committed product inventory

The working [functional-completeness ledger](functional-completeness-ledger.md) covers these categories. Phase 0 verifies and expands it into testable rows with a source reference, native counterpart, owner, milestone, and evidence state. Umbrella names do not count as complete rows. Door rows distinguish keys, locks, automatic behavior, and blastable health. Trigger rows distinguish placement forms, activator masks, and one-shot behavior. Matcen rows distinguish production types, rates, priorities, limits, effects, sounds, and attachments. Ambient and sound rows distinguish probabilities, timing ranges, loop points, event bindings, and terrain-altitude bands. Fonts, difficulty, cinematics, multiplayer messaging, client-presentation events, host commands, room roles, refueling, and cheat, easter-egg, or diagnostic commands each receive explicit treatment.

### Player experience

- Training, base, secret, and Mercenary campaign content;
- six-degree-of-freedom flight including afterburner boost with fuel and recharge, ship wiggle/bob and its explicit authoritative-or-presentation decision, autoleveling and mouselook control modes, environmental and impulse forces, and the declared exponential drag integration; five named difficulty levels and their declared AI, weapon, energy-and-shield-pickup, AI energy-drop, generic-damage, profile, session, and behavior-query rules, collision, objects, doors, triggers, AI, purpose-built volumetric navigation, weapons, inventory, GuideBot and its command menu, matcens, goals, terrain, weather, effects, damage, death and the death camera, refueling rooms, and progression;
- briefings, movies, runtime camera-path cinematics with player-control and presentation transitions, TelCom-style presentation, HUD, animated three-dimensional cockpit, three-dimensional automap and discovery state, player markers and messages, rear view and auxiliary camera views for GuideBot, guided weapons and markers, audio, in-level streamed mission voice, adaptive music, post-level results screens, menu, credits, intro, and loading presentation, the source-supported localization, profiles, settings, control configuration, difficulty and other player-accessibility affordances, saves with thumbnails, screenshots, campaign level-warp, controller support, native haptics, and the intended cheat, easter-egg, and diagnostic command surface with per-command availability and consequences; accessibility and localization improvements are adopted explicitly as their slices arrive rather than assumed as an undefined 1.0 umbrella;
- pilot pictures, ship logos, audio taunts, and other supported player-selected media, including local preview, network negotiation, bounds, mute and privacy controls, host policy, and safe failure;
- stock multiplayer maps and the enumerated stock game modes — Anarchy, Team Anarchy, Hyper-Anarchy, Robo-Anarchy, CTF, Entropy, Hoard, Monsterball, and four-player campaign co-op with robots, GuideBot, and campaign scripts under the multiplayer authority — using the source-supported player count for each mode and preserving the released 32 network/player-slot infrastructure, including its listen-host and dedicated-server slot accounting; live observer mode as a per-slot state; native LAN and Internet discovery and joining through one affordable evidence-selected 2026 topology; local prediction and authoritative reconciliation; public, team, and private text chat with mute, block, rate, and host-policy controls; dedicated hosting with local and authenticated remote operator commands; multiplayer level and mode configuration, per-mode scoring and results presentation, joining, leaving, explicit outage behavior, and failure recovery. The Phase 0 Internet-multiplayer study must resolve operational ownership and give historical lobby chat, rankings, persistent pilot stats, and join-time mission acquisition either a version 1.0 owner and proof or an explicitly approved future disposition before Phase 9 production transport work;
- deterministic replay and recording for testing, diagnosis, desync evidence, observer or spectator behavior, and the player-facing replay experience, with each historical capability ledgered explicitly.

### World and level creation

- indoor room, vertex, face, portal, bridge, join, attach, snap, combine, and triangulation workflows;
- outdoor terrain and reusable-room workflows;
- UV, material, texture, procedural surface, water, fog, lighting, lightmap, volumetric, radiosity, mirror-surface, specular-response, scorch-receiver, and blend-mode capabilities, each with a ledgered native counterpart or an approved explicit exclusion;
- sky and horizon colors, stars, satellites, rotation, halos, atmosphere, terrain environment audio, and animated-light effects such as pulses, strobes, flicker, and coronas;
- object, player start, camera, waypoint, sound source, door, trigger, path, navigation, matcen, goal, and weather placement, plus typed room roles for refueling, goals, secrets, special-purpose spaces, external spaces, and waypoints; the dormant ambient-life idea is preserved separately rather than mislabeled as working 1.0 scope;
- textured, wireframe, collision, portal, navigation, and lighting diagnostic views; focus and viewport navigation; saved views and camera bookmarks;
- selection, grouping, reusable groups or prefabs, duplication, naming, search, undo, redo, autosave, crash recovery, inspection, statistics, repair, validation, and explicit one-way Model I/O USD import and reimport into canonical editable geometry.

### Game-data creation

- textures and materials;
- robots, powerups, buildings, clutter, ships, weapons, doors, lights, sounds, and ambient patterns;
- physics, animation, AI, death, inventory, effect, and object-archetype definitions;
- terrain groupings and other canonical content definitions required to build a complete new game package.

### Behavior and campaign creation

- a reusable human-authored native model for the event, condition, query, action, variable, timer, function, composition, difficulty-query, cinematic-command, multiplayer-command, and authoritative/client-presentation behavior capabilities evidenced by the shipped game and creator tools, without requiring Swift or generated-file editing and without preselecting its eventual visual, textual, or other representation;
- object, trigger, level, campaign, and game-mode behavior scopes;
- behavior validation, tracing, breakpoints, deterministic replay, and persistent state;
- campaign sequencing, branches, secrets, returns, training and multiplayer declarations, mission-wide default and allowed ships, progress presentation, intros, endings, briefings, and adaptive-score assignment and region control. The dead `LVLFLAG_SHIPSELECT` per-level idea is preserved in [Future opportunities](future-opportunities.md), not asserted as a version 1.0 capability. Per-level dependencies are the new package dependency model, not a historical manifest field.

### Presentation and media creation

- multi-screen briefings and TelCom-style layouts;
- text, images, movies, sound, buttons, timing, effects, fonts, colors, navigation, and conditional display;
- cinematic sequencing, message and string management, localization, preview, and validation;
- inspection and use of canonical retail bitmap fonts produced one-way by `D3Import`, with no retail font reader or conversion path in the editor;
- model, room geometry, animation, texture, modern font, audio, adaptive-score, movie, player-picture, ship-logo, and audio-taunt import, inspection, conversion, bounds, and rights metadata;
- font glyph coverage, atlas generation, localization preview, and animation-state and sound-event bindings.

### Build and iteration tools

- project creation from an empty native template as creator-suite certification, not bundled replacement content or a waiver of the version 1.0 retail requirement;
- content catalog and reference inspection;
- deterministic native lighting and purpose-built volumetric-navigation baking;
- complete level dependency inspection, resident CPU and GPU cost reporting, load and release diagnostics, and later resource-budget tools for whichever single lifetime design the measured architecture adopts;
- dependency closure, orphan detection, validation, and diagnostics;
- instant play-in-editor, deterministic test scenarios, and capture support;
- package publishing, provenance, signing where required, and distribution;
- a native mod SDK built from the same project, package, behavior, and validation contracts used by the game team, covering the evidenced shipped-game and creator-tool capability before any broader post-1.0 extension.

The current completion gate is human-first. Stable element identity, concrete typed edits, structured diagnostics, and deterministic playtest operations are required for a reliable native editor. They may later support automation, but an MCP server, headless authoring mode, public command schema, training-data capture, telemetry, and agent-specific workflows are outside the current committed gate and do not justify early product machinery.

## Historical evidence policy

The released source is both the capability inventory and the initial semantic translation reference. Every relevant file is accounted for, but that does not require reproducing every private decomposition, menu entry, defensive branch, or defect.

Intended, functioning capabilities and reachable behavior belong in the ledger and native baseline. A partially implemented historical feature belongs there only when source or retail evidence proves a useful working product capability. Empty callbacks, disabled menu shells, commented-out tools, and dead backend concepts are excluded from the version 1.0 baseline while their intent and provenance remain in [Future opportunities](future-opportunities.md). Duplicated dialogs, accidental quirks, and bugs receive an evidence-only or exclusion disposition rather than product code.

When evidence is ambiguous, record the uncertainty in the ledger and make an explicit product decision. Do not resolve ambiguity by deleting the feature silently.

## Sequencing and scope control

The roadmap may defer implementation of a committed capability to a later phase. It may not relabel that capability as optional without changing this contract.

Each implementation phase closes a vertical slice through runtime and authoring. The stock campaigns prove imported-content coverage. A non-bundled independently authored campaign proves creator coverage; it is certification evidence, not replacement retail content. Multiplayer and replay prove that the simulation and behavior models extend beyond the stock single-player scripts.

Complete revival status requires all ledger rows to be either:

- verified with named evidence;
- explicitly replaced by a documented modern counterpart; or
- excluded by an approved product-scope amendment.

“Not needed by the current stock level” is a sequencing note, not an exclusion reason.

The future-opportunities register is not part of this closure set and cannot substitute for a functional row. Its dormant or incomplete entries are not currently evidenced as working historical capabilities. A working historical capability appears there only after an explicit user-approved scope amendment gives its functional row an excluded disposition. Both categories preserve evidence and reconsideration triggers for later product decisions.
