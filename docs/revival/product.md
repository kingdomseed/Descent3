# Product

Status: core definition. Updated 2026-09-29. It replaces `REVIVAL.md` and `functional-completeness.md`.

## What we are building

**Descent 3 Revival** is a native Apple version of Descent 3 (1999). It is a semantic translation of the GPL C++ source into Swift 6 and Metal 4. It is not a wrapper, emulator, or C++ port. The player supplies an owned retail copy. A one-way importer converts it into our own canonical content format.

## Products

| Product | Platform | Role | Release |
|---|---|---|---|
| **D3Import** | macOS | The only code that reads retail formats (HOG, D3L, OOF, OSF, OMF, MVE, FNT). Writes a canonical content package. | 1.0 |
| **RevivalMac** | macOS 26+, arm64 | The player app (AppKit and MetalKit). Launches D3Import for first-run import. | 1.0 |
| **RevivalMobile** | iOS/iPadOS 26+ | A universal UIKit player. Imports a package made on a Mac. | Post-1.0 (P1) |
| **RevivalEditor** | macOS | Creator tool: edit levels, play-test, publish. | Post-1.0 (P2) |

All players and the editor share one Core (world, simulation, scripts) and one Metal renderer. Mobile and the editor stay compiling so the shared code does not become Mac-only. Their feature work waits until after 1.0.

## Version 1.0

1.0 is the **complete single-player game on Mac**:

- Pilot Training, the full base campaign including secret levels, and the Mercenary campaign.
- All robots, bosses, weapons, countermeasures, pickups, and difficulty levels.
- Indoor and outdoor (terrain) levels, with lighting and effects equal to the original.
- Sound, streamed voice, and the original music system.
- HUD, cockpit, automap, Guide-Bot, and auxiliary views.
- Menus, pilots, settings, controls (keyboard, mouse, game controller), briefings, movies, and saves.
- First-run import from a supported retail installation.
- A signed and notarized Mac app.

### 1.0 acceptance list

Every item must work in RevivalMac from imported content before 1.0. `plan.md` milestones M2–M7 deliver them.

- **Campaigns:** campaign order, branches, secret levels and returns, level warp, and ship carry-over between levels.
- **Flight:** 6DOF, afterburner and cooler, wiggle, auto-level, mouselook, gravity and forces, drag, and headlight.
- **World:** collision, doors, keys and locks, blastable doors, triggers, matcens, level goals, terrain, weather, fuel/refuel rooms, force fields, and destroyable faces.
- **Hazards:** room damage, lava and acid, and environmental damage.
- **Robots:** all robots and bosses, general AI, the thief, navigation, and all five difficulty levels.
- **Weapons:** all primaries and secondaries, including homing, guided, charge, spray, electrical, zoom, child-spawn, and persistent effects.
- **Countermeasures:** Seeker, Betty, Chaff, Gunboy, and Proximity Mine.
- **Pickups and inventory:** cloak, invulnerability, quad, rapid fire, energy-to-shield converter, and keys.
- **Guide-Bot:** the full command menu.
- **Damage and death:** the death sequence and camera, respawn at waypoints, and failure and restart.
- **HUD:** cockpit and HUD modes, gauges, monitors, reticle, warnings, messages, and goal display.
- **Views:** automap and markers, rear view, auxiliary and guided-missile views.
- **Screens:** briefings, TelCom (goals, ship status), movies, in-game cinematics, post-level results, credits, and the intro.
- **Audio:** 2D and 3D sound, ambient, reverb, terrain ambience, streamed mission voice, and the original music region system.
- **Rendering:** lightmaps, blend modes, specular, mirrors, scorch marks, procedural fire and water, coronas, particles, animated textures, dynamic and per-face light, and object attachments.
- **Shell:** main menu, pilots, settings (input, display, audio), control remapping, keyboard, mouse, and game controller with haptics.
- **Saves:** named save slots, quicksave, load across levels, and thumbnails.
- **Other:** pause and focus handling, an accessibility baseline, English text with the localization tables imported, and first-run import.

## After 1.0 (kept, not dropped)

| ID | Work |
|---|---|
| P1 | iPhone and iPad: touch controls, lifecycle, audio session, package import through the file picker, and device certification. Candidate GPU floor: Apple GPU family 7. Certify it on real devices, or raise it, before release. Dev devices: iPhone 14 and M2 iPad. |
| P2 | Creator suite (RevivalEditor): level editing, behavior (script) authoring without Swift, publishing native packages, and a mod SDK. |
| P3 | Multiplayer: stock modes, LAN and Internet play, and a dedicated host. There is no compatibility with the original servers. |
| P4 | Replay and demo recording, using the corrected `DT_ATTACH_RAD` record type. |
| P5 | Enhanced graphics options, for example per-pixel lighting, bloom, MetalFX upscaling, and ultrawide. The original look remains the default. |

## Non-goals

- Retail data in Git, or any redistribution of it.
- Reading original save files, demos, HOG, or D3L at runtime.
- Loading native code (DLLs or Osiris modules) at runtime.
- Compatibility with the original multiplayer protocol.
- Windows, Linux, Intel Macs, OpenGL, or SDL.
- Streaming worlds. One complete level is loaded at a time, as in the original.

## Definition of done for a feature

A feature is done when it behaves like the original (or like a listed correction in `sources.md`), is covered by tests, runs in RevivalMac from imported content, and passes a Codex review. The level-by-level checklist is in `plan.md`.
