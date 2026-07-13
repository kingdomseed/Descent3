# Functional-completeness ledger

- Status: Phase 0 working inventory
- Date: July 13, 2026
- Authority: execution record under the binding [functional-completeness contract](functional-completeness.md)

## How to use this ledger

Each row names one useful capability, its current historical evidence, the native owner and planned phase, and the proof needed to close it. Phase 0 must inspect the cited source, add missing evidence, and split any row that still hides independently testable behavior. A row closes only when every applicable runtime, authoring, validation, playtest, and publishing path works. `N/A` is allowed only with a recorded reason.

States are `inventory`, `researched`, `specified`, `implemented`, or `verified`. No row is verified yet. Owners are product targets, not extra teams or modules.

## Player, simulation, and presentation

| ID | Capability | Historical evidence | Native owner / phase | Completion proof | State |
| --- | --- | --- | --- | --- | --- |
| P-001 | Six-degree-of-freedom input and flight | `Descent3/Controls.cpp`, `Descent3/Player.cpp` | Core, Mac / 3 | Keyboard, mouse and controller flight; fixed-tick tests and authored playtest | inventory |
| P-002 | Room collision, portal crossing and ownership | `physics/collide.cpp`, `physics/findintersection.cpp` | Core, Editor / 3 | Swept collision and portal fixtures; editor geometry round trip | inventory |
| P-003 | Player ship physics, damage and death | `Descent3/Player.cpp` | Core / 4–6 | Reference checkpoints, save/replay and creator definitions | inventory |
| P-004 | Weapons, projectiles and impacts | `Descent3/weapon.cpp` | Core / 4–8 | Fire, collision, damage, effects and authored weapon package | inventory |
| P-005 | Inventory, powerups and countermeasures | `Descent3/Inventory.cpp`, `Descent3/powerup.h`, `editor/PowerupPropDialog.cpp` | Core, Editor / 4–8 | Acquire/use/drop/save paths and creator validation | inventory |
| P-006 | Robot AI and bosses | `scripts/AIGame.cpp`, `Descent3/AImain.cpp` | Core, Editor / 4–8 | State, navigation, combat and boss checkpoints plus new authored AI | inventory |
| P-007 | GuideBot behavior and commands | `scripts/AIGame.cpp`, `Descent3/robotfire.cpp` | Core, Editor / 5–8 | Training and campaign checkpoints; authorable configuration | inventory |
| P-008 | Doors, keys, locks, automatic behavior and blastable health | `Descent3/door.cpp` | Core, Editor / 4–8 | Each door family executes, validates, saves and publishes | inventory |
| P-009 | Triggers and activator rules | `Descent3/trigger.cpp` | Core, Editor / 4–8 | Placement forms, masks and one-shot behavior tested | inventory |
| P-010 | Matcens | `Descent3/matcen.cpp` | Core, Editor / 6–8 | Production types, timing, limits, effects and attachments tested | inventory |
| P-011 | Goals, objectives and campaign progression | `Descent3/levelgoal.cpp`, `Descent3/Mission.cpp` | Core, Editor / 5–8 | Goal state, failure, completion, save and campaign branch proof | inventory |
| P-012 | HUD modes and instructional messages | `Descent3/hud.cpp` | Metal, Mac, Editor / 4–8 | Runtime layouts, localization, preview and package evidence | inventory |
| P-013 | Animated three-dimensional cockpit and monitors | `Descent3/cockpit.cpp` | Core, Metal, Editor / 4–8 | Open/close, buffet, monitor bindings and image tests | researched |
| P-014 | Three-dimensional automap and discovery state | `Descent3/TelComAutoMap.cpp`, `Descent3/gamesave.cpp` | Core, Metal, Editor / 5–8 | Explore/save/load/full-map/secret/marker and authored metadata tests | researched |
| P-015 | Player markers and messages | `Descent3/marker.cpp`, `Descent3/gamesave.cpp` | Core, Metal, Editor / 5–9 | Drop, name, view, persist, replicate and validate | researched |
| P-016 | Rear view | `Descent3/GameLoop.cpp`, `Descent3/SmallViews.cpp` | Core, Metal, Mac / 5–6 | Input, camera, cockpit layout and image tests | researched |
| P-017 | GuideBot auxiliary view | `Descent3/GameLoop.cpp`, `Descent3/SmallViews.cpp` | Core, Metal, Editor / 5–8 | Camera ownership, loss behavior, layout and preview | researched |
| P-018 | Guided-weapon auxiliary view | `Descent3/SmallViews.cpp` | Core, Metal, Editor / 6–8 | Weapon lifecycle, camera selection and image evidence | researched |
| P-019 | Marker and other supported auxiliary views | `Descent3/GameLoop.cpp`, `Descent3/SmallViews.cpp` | Core, Metal, Editor / 6–8 | Every declared view has state, layout and image evidence | researched |
| P-020 | Native controller haptics | `Descent3/D3ForceFeedback.cpp`, `ddio/lnxforcefeedback.cpp` | Mac, Editor / 5–8 | Effect mapping, gain/disable, device loss and unsupported fallback | researched |
| P-021 | Positional sound and ambient audio | `sndlib/soundload.cpp`, `Descent3/ambient.cpp` | Core, Mac, Editor / 4–8 | Spatial playback, loops, ranges, events and authoring proof | inventory |
| P-022 | Adaptive score runtime and transitions | `music/`, `Descent3/d3music.cpp` | Import, Core, Mac, Editor / 5–8 | OMF conversion, logical state, musical transitions and save/replay | specified |
| P-023 | Briefings, TelCom and movies | `Descent3/TelCom.cpp`, `editor/BriefEdit.cpp` | Mac, Editor / 5–8 | Full campaign presentation and empty-project authoring | inventory |
| P-024 | Profiles, settings and accessibility | `Descent3/pilot.cpp`, `Descent3/config.cpp` | Mac / 4–10 | Native persistence, clean-account, control and accessibility matrix | inventory |

## Rendering and visual effects

| ID | Capability | Historical evidence | Native owner / phase | Completion proof | State |
| --- | --- | --- | --- | --- | --- |
| R-001 | Portal traversal and visible-room selection | `Descent3/render.cpp` | Core, Metal / 2–6 | CPU visibility fixtures and fixed-scene images | inventory |
| R-002 | Flat and base-textured faces | `Descent3/render.cpp` | Metal / 2–6 | Material-state tests and images | inventory |
| R-003 | Base plus lightmap faces | `Descent3/render.cpp` | Metal, Editor / 2–8 | Lightmap binding, bake and image evidence | inventory |
| R-004 | Vertex color, alpha, fog and gamma semantics | `Descent3/render.cpp` | Metal, Editor / 2–8 | Synthetic state cases and live preview | inventory |
| R-005 | Declared additive and saturating blend semantics | `renderer/HardwareOpenGL.cpp` | Metal, Editor / 6–8 | Pipeline-state tests and reference scenes | researched |
| R-006 | Specular faces | `Descent3/render.cpp`, `Descent3/room_external.h` | Metal, Editor / 6–8 | Visibility, material authoring and images | researched |
| R-007 | Reflected room views and mirrors | `Descent3/render.cpp` | Core, Metal, Editor / 6–8 | Reflection transform, visibility/recursion bounds and images | researched |
| R-008 | Scorch decals | `Descent3/render.cpp`, `Descent3/room_external.h` | Core, Metal, Editor / 6–8 | Placement, lifetime, receiver rules and images | researched |
| R-009 | Procedural fire and water textures | `Descent3/procedurals.cpp` | Core, Metal, Editor / 6–8 | Deterministic update, authoring, preview and images | researched |
| R-010 | Volumetric surfaces and lighting | `Descent3/room_external.h`, `Descent3/render.cpp` | Metal, Editor / 6–8 | Geometry/material validation and images | researched |
| R-011 | Models, animation and attachments | `Descent3/object.cpp`, `model/` | Core, Metal, Editor / 2–8 | Import, animation, binding and authored package proof | inventory |
| R-012 | Terrain, sky, stars, satellites and atmosphere | `Descent3/terrainrender.cpp`, `editor/` | Core, Metal, Editor / 6–8 | Outdoor scenes and complete environment authoring | inventory |
| R-013 | Effects, particles, coronas and weather | `Descent3/fireball.cpp`, `Descent3/weather.cpp` | Core, Metal, Editor / 6–8 | Lifecycle, state, authoring and image tests | inventory |

## World and content creation

| ID | Capability | Historical evidence | Native owner / phase | Completion proof | State |
| --- | --- | --- | --- | --- | --- |
| W-001 | Room, vertex and face construction | `editor/`, `Descent3/LoadLevel.h` | Editor, Core / 3–8 | Create/edit/undo/save/reopen/play/publish | inventory |
| W-002 | Portal, bridge, join, attach and snap workflows | `editor/editor.rc` | Editor, Core / 3–8 | Each operation validates topology and round-trips | inventory |
| W-003 | Combine, split and triangulation workflows | `editor/editor.rc` | Editor, Core / 3–8 | Geometry fixtures, undo and playtest | inventory |
| W-004 | Outdoor terrain editing | `editor/TerrainDialog.cpp`, `Descent3/terrain.cpp` | Editor, Core / 6–8 | Create, sculpt, texture, validate and play | inventory |
| W-005 | Reusable rooms, groups and prefabs | `editor/` | Editor, Core / 6–8 | Create, instantiate, update, validate and publish | inventory |
| W-006 | Materials, textures and UV editing | `editor/`, `manage/` | Editor, Metal / 3–8 | Edit, preview, validate and package every declared family | inventory |
| W-007 | Object and player-start placement | `editor/ObjectDialog.cpp` | Editor, Core / 2–8 | Place/configure/search/duplicate/play/package | inventory |
| W-008 | Paths and navigation | `editor/`, `Descent3/BOA.cpp` | Editor, Core / 5–8 | Author, bake, diagnose, play and publish | inventory |
| W-009 | Lighting, lightmaps and radiosity | `editor/`, `lighting/` | Editor, Metal / 6–8 | Author, bake, invalidate, preview and package | inventory |
| W-010 | Fog, weather and ambient environment | `editor/`, `Descent3/weather.cpp` | Editor, Core, Metal / 6–8 | Edit, preview, validate and play | inventory |
| W-011 | Diagnostic views and camera bookmarks | `editor/` | Editor, Metal / 2–8 | Textured/wire/collision/portal/navigation/light views persist | inventory |
| W-012 | Selection, grouping, search and naming | `editor/` | Editor / 2–8 | Command tests, undo/redo and save/reopen | inventory |
| W-013 | Validation, repair and statistics | `editor/` | Core, Editor / 3–8 | Broken fixtures, repair preview and refusal rules | inventory |
| W-014 | Autosave and crash recovery | `editor/` | Editor / 3–8 | Crash simulation and explicit recovery acceptance | inventory |
| D-001 | Robot and AI definitions | `manage/robotpage.h`, `editor/WorldObjectsRobotDialog.cpp` | Core, Editor / 4–8 | Full typed definition, reference and authored-play proof | inventory |
| D-002 | Weapon and projectile definitions | `manage/weaponpage.cpp` | Core, Editor / 4–8 | Full typed definition and authored combat proof | inventory |
| D-003 | Ship and physics definitions | `manage/shippage.cpp` | Core, Editor / 3–8 | Movement, bounds and authored ship proof | inventory |
| D-004 | Powerup, building and clutter definitions | `manage/` | Core, Editor / 4–8 | Lifecycle, placement and package proof | inventory |
| D-005 | Door and light definitions | `manage/` | Core, Editor / 4–8 | Runtime families, preview and validation | inventory |
| D-006 | Sound, ambient and adaptive-score definitions | `manage/soundpage.cpp`, `music/` | Core, Mac, Editor / 4–8 | Import/author/preview/save/publish | inventory |
| D-007 | Animation, death, inventory and effect bindings | `manage/` | Core, Editor / 4–8 | Binding validation and end-to-end lifecycle | inventory |
| D-008 | Cockpit, monitor, HUD and haptic bindings | `Descent3/cockpit.cpp`, `Descent3/D3ForceFeedback.cpp` | Core, Mac, Editor / 4–8 | Typed definitions, preview and device/image proof | researched |

## Behavior, campaign, and persistence

| ID | Capability | Historical evidence | Native owner / phase | Completion proof | State |
| --- | --- | --- | --- | --- | --- |
| B-001 | Typed behavior values, expressions and references | `editor/DallasMainDlg.cpp`, `editor/DallasMainDlg.h`, `scripts/` | Core, Editor / 4–8 | Compiler, invalid graph, authoring and package tests | inventory |
| B-002 | Events, handler order and default interception | `Descent3/osiris_dll.h` | Core, Editor / 4–8 | Ordered dispatch and disposition tests | inventory |
| B-003 | Queries, commands and targeted requests | `scripts/osiris_import.h` | Core, Editor / 4–8 | Full ledger coverage and authority tests | inventory |
| B-004 | Timers, schedules and owner lifetime | `Descent3/OsirisLoadandBind.cpp` | Core, Editor / 4–8 | Tick boundaries, cancellation and persistence | inventory |
| B-005 | Functions, subgraphs and bounded iteration | `editor/DallasMainDlg.cpp`, `editor/DallasMainDlg.h` | Core, Editor / 5–8 | Compile/debug/limit and reuse proof | inventory |
| B-006 | Historical interval translation | `scripts/osiris_common.h`, `Descent3/GameLoop.cpp` | Core, Import / 4–8 | Rate, drift, timer and operation-budget evidence | specified |
| B-007 | Adaptive-score behavior commands | `scripts/DallasFuncs.cpp`, `Descent3/multisafe.cpp` | Core, Editor / 5–8 | Region/role authority, ambiguity decision and replay | specified |
| B-008 | Persistent behavior state and durable operations | `Descent3/gamesave.cpp` | Core, Editor / 4–8 | Save/load/replay and incompatible-revision tests | inventory |
| B-009 | Visual debugging, traces and breakpoints | `editor/DallasMainDlg.cpp`, `editor/DallasMainDlg.h` | Core, Editor / 4–8 | Source maps, stepping, watch and error navigation | inventory |
| B-010 | Stock behavior catalog and translation ledger | `scripts/`, `d3-osx.hog` build inputs | Import, Core / 4–9 | Complete scope manifest and approved divergence checkpoints | specified |
| C-001 | Campaign order, branches, secrets and returns | `Descent3/Mission.cpp`, `Descent3/Mission.h` | Core, Editor / 5–8 | Base/Mercenary and independent campaign proof | inventory |
| C-002 | Ship selection and campaign declarations | `Descent3/Mission.cpp`, `Descent3/Mission.h` | Core, Editor / 5–8 | Import, author, validate and replay | inventory |
| C-003 | Briefing, intro, ending and progress presentation | `editor/BriefEdit.cpp`, `Descent3/Mission.cpp` | Mac, Editor / 5–8 | Full campaign and empty-project authoring | inventory |
| C-004 | Adaptive-score campaign assignment | `Descent3/Mission.cpp`, `music/` | Core, Mac, Editor / 5–8 | Defaults, regions, preview and package closure | specified |
| S-001 | Canonical saves | `Descent3/gamesave.cpp`, `Descent3/loadstate.cpp` | Core, Mac / 4–10 | Round trip every durable ledgered state family | inventory |
| S-002 | Simulation and scoped semantic revisions | New native contract | Core, Import, Editor / 1–10 | Missed-bump, compatibility, migration and rejection matrices | specified |
| S-003 | Authoritative replay and state hashes | `Descent3/demofile.cpp` as capability evidence | Core, Mac / 5–10 | Exact same-revision hashes and hostile-input tests | inventory |
| S-004 | Player-facing replay and observer evidence | `Descent3/demofile.cpp`, multiplayer source | Core, Mac / 5–10 | Controls, presentation and declared checkpoint proof | inventory |

## Multiplayer and player-selected media

| ID | Capability | Historical evidence | Native owner / phase | Completion proof | State |
| --- | --- | --- | --- | --- | --- |
| N-001 | Authoritative session lifecycle | `Descent3/multi.cpp` | Core, Mac / 9 | Host/join/leave/recover/finish matrices | inventory |
| N-002 | Content and simulation-revision negotiation | `Descent3/multi.cpp` as capability evidence | Core, Mac / 9 | Exact agreement, mismatch diagnostics and clean failure | specified |
| N-003 | Dedicated no-window hosting | `Descent3/dedicated_server.cpp` as capability evidence | Core, Mac / 9 | Lifecycle tests without renderer/audio/UI initialization | inventory |
| N-004 | Stock game modes and scoring | multiplayer modules and `Descent3/multi.cpp` | Core, Editor / 9 | Mode ledger, results, replay and authored counterpart | inventory |
| N-005 | Multiplayer map and mode authoring | `editor/`, multiplayer modules | Core, Editor / 9 | New package create/validate/host/join/complete | inventory |
| N-006 | Marker replication and authority | `Descent3/marker.cpp`, `Descent3/multi.cpp` | Core, Editor / 9 | Ownership, bounds, persistence and network tests | researched |
| N-007 | Stock and custom pilot pictures | `Descent3/PilotPicsAPI.cpp`, `ppics.hog` | Import, Mac / 9 | Bounded decode, selection, hash transfer and policy tests | researched |
| N-008 | Custom ship logos | `Descent3/multi.cpp`, pilot UI | Mac / 9 | Format/dimension/size limits, preview, transfer and mute policy | researched |
| N-009 | Audio taunts | `Descent3/audiotaunts.cpp`, `Descent3/multi.cpp` | Mac / 9 | Duration/rate/cooldown bounds, mute, malformed data and playback | researched |
| N-010 | Hostile input and media resistance | Original networking as threat evidence | Core, Mac / 9 | Fuzz, rate, storage, path and active-payload rejection | inventory |
| N-011 | Multiplayer replay and desync evidence | `Descent3/multi.cpp`, demo capability | Core, Mac / 9 | Authoritative hashes plus declared client/observer evidence | specified |

## Import, iteration, and publishing

| ID | Capability | Historical evidence | Native owner / phase | Completion proof | State |
| --- | --- | --- | --- | --- | --- |
| T-001 | Recognized source profiles and one-way import | Retail provenance and released loaders | Import / 2–9 | Fingerprints, malformed data and atomic promotion | specified |
| T-002 | HOG, level, model, texture and lightmap conversion | Released format loaders | Import / 2–7 | Synthetic parser tests and local closed imports | inventory |
| T-003 | ACM audio conversion | `stream_audio/`, `third_party/libacm` | Import / 4–6 | Exact supported variants and malformed corpus | inventory |
| T-004 | OMF adaptive-score conversion | `music/omflex.cpp` | Import / 5–6 | Exact source constructs and malformed graphs | specified |
| T-005 | MVE movie conversion | Released movie path | Import / 5–7 | Exact supported variants, timing and malformed corpus | inventory |
| T-006 | Canonical project creation and migration | New native contract | Core, Editor / 2–10 | Empty project, save/reopen and public migration tests | inventory |
| T-007 | Lighting and navigation baking | `editor/`, released runtime data | Core, Editor / 5–8 | Incremental invalidation, failure safety and package proof | inventory |
| T-008 | Dependency closure and orphan audit | Historical HOG/editor tools | Core, Editor / 2–8 | Missing/duplicate/orphan/destructive-change fixtures | inventory |
| T-009 | Play-in-editor | Historical editor play workflow | Core, Metal, Editor / 3–9 | Shipping simulation and return-to-document state | inventory |
| T-010 | Atomic package publishing | Historical HOG tools as capability evidence | Core, Editor / 4–10 | Failure safety, semantic-revision checks and install proof | inventory |
| T-011 | Rights and provenance metadata | Retail and replacement-content policy | Import, Editor / 2–10 | Required metadata and public-package refusal tests | inventory |
| T-012 | Native mod SDK and documentation | DALLAS/editor/tool capability evidence | Core, Editor / 4–9 | Independent campaign and multiplayer package certification | inventory |

## Phase 0 closure work

The next ledger pass must:

1. inspect every released editor command family, game-data page family, Osiris/DALLAS operation family, game mode, replay path, and utility;
2. link each intended capability to a row or add a new row;
3. split rows whose variants have independent state or failure behavior;
4. record why runtime, authoring, validation, playtest, or publishing is not applicable where needed;
5. assign a phase owner and concrete evidence artifact;
6. confirm that no umbrella word such as “audio,” “music,” “HUD,” “TelCom,” “renderer,” or “multiplayer” hides a subsystem.

Phase 0 does not close until that audit finds no unexplained intended capability.
