# Functional completeness

- Status: accepted
- Date: July 13, 2026
- Authority: binding product-scope contract

## Governing rule

The revival rebuilds every required player-facing and creator-facing capability in a modern native form. Legacy ABIs, file formats, protocols, UI structures, and implementation details are not product requirements except at the one-way retail import boundary.

KISS constrains implementation, never product scope. A smaller implementation must deliver the same capability. Removing the capability is not simplification.

Campaign-first development controls sequence. It does not define the final feature ceiling.

## What compatibility means here

The project distinguishes functional continuity from technical interoperability:

| Historical mechanism | Required modern capability | Compatibility requirement |
| --- | --- | --- |
| Descent 3 runtime | Complete native game behavior | No original executable or engine ABI |
| Osiris native modules | Safe, expressive, deterministic gameplay behavior | No DLL loading or Osiris ABI |
| DALLAS | Visual behavior authoring and debugging | No generated C++ or compiler pipeline |
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
5. the publisher can include it in a dependency-closed native package, either standalone or with explicit canonical base-package dependencies.

For example, a door is incomplete if an imported door works but a creator cannot place, configure, validate, and test a new one. This rule applies to geometry, terrain, materials, objects, AI, weapons, triggers, paths, goals, lighting, audio, presentation, campaign flow, multiplayer modes, and behaviors.

Pure runtime concerns such as controller input do not need an editor panel. Pure editor concerns such as selection history do not need a gameplay representation. The team records why a path is inapplicable instead of silently omitting it.

Creator completeness includes the quality of the human workflow, not only the presence of data types. `RevivalEditor` must provide a native document lifecycle, predictable synchronized selection and focus, direct and numeric editing, discoverable menu and keyboard commands, named undo and redo, source-linked diagnostics, cancellable revision-safe background work, playtest state restoration, crash recovery, source-control-safe saves, Full Keyboard Access, VoiceOver coverage, and measured responsiveness on the M4. A modal dialog or hand-edited file does not close a creator row when the integrated workflow remains incomplete.

Every new or changed production behavior used to close a completeness row follows the binding [red-green-refactor protocol](test-driven-development.md). Completion evidence records the focused test that failed for the intended reason before implementation and passed afterward. An inapplicable path receives no manufactured test; the ledger records why it is inapplicable.

## Committed product inventory

The working [functional-completeness ledger](functional-completeness-ledger.md) covers these categories. Phase 0 verifies and expands it into testable rows with a source reference, native counterpart, owner, milestone, and evidence state. Umbrella names do not count as complete rows. Door rows distinguish keys, locks, automatic behavior, and blastable health. Trigger rows distinguish placement forms, activator masks, and one-shot behavior. Matcen rows distinguish production types, rates, priorities, limits, effects, sounds, and attachments. Ambient and sound rows distinguish probabilities, timing ranges, loop points, event bindings, and terrain-altitude bands. Fonts, difficulty, cinematics, multiplayer messaging, client-presentation events, host commands, room roles, refueling, and cheat, easter-egg, or diagnostic commands each receive explicit treatment.

### Player experience

- Training, base, secret, and Mercenary campaign content;
- six-degree-of-freedom flight, five named difficulty levels and their declared AI, weapon, energy-and-shield-pickup, AI energy-drop, generic-damage, profile, session, and behavior-query rules, collision, objects, doors, triggers, AI, purpose-built volumetric navigation, weapons, inventory, GuideBot, matcens, goals, terrain, weather, effects, damage, death, refueling rooms, and progression;
- briefings, movies, runtime camera-path cinematics with player-control and presentation transitions, TelCom-style presentation, HUD, animated three-dimensional cockpit, three-dimensional automap and discovery state, player markers and messages, rear view and auxiliary camera views for GuideBot, guided weapons and markers, audio, adaptive music, localization, profiles, settings, saves, accessibility, controller support, native haptics, and the intended cheat, easter-egg, and diagnostic command surface with per-command availability and consequences;
- pilot pictures, ship logos, audio taunts, and other supported player-selected media, including local preview, network negotiation, bounds, mute and privacy controls, host policy, and safe failure;
- stock multiplayer maps and game-mode capabilities, 2–32 connected human slots over Network-framework QUIC and inner CryptoKit records, live observer mode as a per-slot state, Bonjour LAN discovery, project-operated public discovery and opaque relay, local prediction and authoritative reconciliation, public, team, and private text chat with mute, block, rate, and host-policy controls, dedicated hosting with local and authenticated remote operator commands, multiplayer level and mode configuration, joining, leaving, fail-closed outage behavior, failure recovery, and result presentation;
- deterministic replay and recording for testing, diagnosis, desync evidence, observer or spectator behavior, and the player-facing replay experience, with each historical capability ledgered explicitly.

### World and level creation

- indoor room, vertex, face, portal, bridge, join, attach, snap, combine, and triangulation workflows;
- outdoor terrain and reusable-room workflows;
- UV, material, texture, procedural surface, water, fog, lighting, lightmap, volumetric, radiosity, mirror-surface, specular-response, scorch-receiver, and blend-mode capabilities, each with a ledgered native counterpart or an approved explicit exclusion;
- sky and horizon colors, stars, satellites, rotation, halos, atmosphere, terrain environment audio, and animated-light effects such as pulses, strobes, flicker, and coronas;
- object, player start, camera, waypoint, sound source, door, trigger, path, navigation, matcen, goal, ambient-life, and weather placement, plus typed room roles for refueling, goals, secrets, special-purpose spaces, external spaces, and waypoints;
- textured, wireframe, collision, portal, navigation, and lighting diagnostic views; focus and viewport navigation; saved views and camera bookmarks;
- selection, grouping, reusable groups or prefabs, duplication, naming, search, undo, redo, autosave, crash recovery, inspection, statistics, repair, validation, and explicit one-way Model I/O USD import and reimport into canonical editable geometry.

### Game-data creation

- textures and materials;
- robots, powerups, buildings, clutter, ships, weapons, doors, lights, sounds, and ambient patterns;
- physics, animation, AI, death, inventory, effect, and object-archetype definitions;
- terrain groupings and other canonical content definitions required to build a complete new game package.

### Behavior and campaign creation

- typed event, condition, query, action, variable, timer, function, and subgraph authoring, including difficulty queries, cinematic commands, bounded multiplayer command input, and explicit authoritative or client-presentation execution roles;
- object, trigger, level, campaign, and game-mode behavior scopes;
- behavior validation, tracing, breakpoints, deterministic replay, and persistent state;
- campaign sequencing, branches, secrets, returns, training and multiplayer declarations, default and allowed ships, per-level ship selection, progress presentation, intros, endings, briefings, adaptive-score assignment and region control, and per-level dependencies.

### Presentation and media creation

- multi-screen briefings and TelCom-style layouts;
- text, images, movies, sound, buttons, timing, effects, fonts, colors, navigation, and conditional display;
- cinematic sequencing, message and string management, localization, preview, and validation;
- inspection and use of canonical retail bitmap fonts produced one-way by `D3Import`, with no retail font reader or conversion path in the editor;
- model, room geometry, animation, texture, modern font, audio, adaptive-score, movie, player-picture, ship-logo, and audio-taunt import, inspection, conversion, bounds, and rights metadata;
- font glyph coverage, atlas generation, localization preview, and animation-state and sound-event bindings.

### Build and iteration tools

- project creation from an empty native template;
- content catalog and reference inspection;
- deterministic room-local lighting and purpose-built volumetric-navigation baking;
- automatic room and fixed positive-multiple-of-32 terrain-cell partitioning, streamed-payload inspection, stack-global, level-pinned, per-cell and spatial-envelope GPU accounting, simultaneous-camera and discontinuous-destination validation, movement-lead-time proof, and publication refusal for an oversized authoritative spine, cell, envelope, `LoadWave`, or declared destination;
- dependency closure, orphan detection, validation, and diagnostics;
- instant play-in-editor, deterministic test scenarios, and capture support;
- package publishing, provenance, signing where required, and distribution;
- a native mod SDK built from the same project, package, behavior, and validation contracts used by the game team.

The current completion gate is human-first. Stable element identity, concrete typed edits, structured diagnostics, and deterministic playtest operations are required for a reliable native editor. They may later support automation, but an MCP server, headless authoring mode, public command schema, training-data capture, telemetry, and agent-specific workflows are outside the current committed gate and do not justify early product machinery.

## Historical evidence policy

The released source is a capability inventory and behavioral reference. It is not a requirement to reproduce every menu entry or defect.

Intended, functioning capabilities belong in the ledger. Partially implemented historical features belong there when the intended capability is clear and useful, even when one retained platform backend is a stub. Empty callbacks, disabled menu shells, commented-out tools, duplicated dialogs, accidental quirks, and bugs do not become requirements by existing in the tree.

When evidence is ambiguous, record the uncertainty in the ledger and make an explicit product decision. Do not resolve ambiguity by deleting the feature silently.

## Sequencing and scope control

The roadmap may defer implementation of a committed capability to a later phase. It may not relabel that capability as optional without changing this contract.

Each implementation phase closes a vertical slice through runtime and authoring. The stock campaigns prove imported-content coverage. A new native campaign proves creator coverage. Multiplayer and replay prove that the simulation and behavior models extend beyond the stock single-player scripts.

Complete revival status requires all ledger rows to be either:

- verified with named evidence;
- explicitly replaced by a documented modern counterpart; or
- excluded by an approved product-scope amendment.

“Not needed by the current stock level” is a sequencing note, not an exclusion reason.
