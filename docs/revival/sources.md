# Sources, content rights, and corrections

Status: core reference. Updated 2026-09-30.

This file records what the port translates from, what content it may use, and which fixes from maintained forks it adopts.

## 1. Source pins

| Source | Pin | Role |
|---|---|---|
| [DescentDevelopers/Descent3](https://github.com/DescentDevelopers/Descent3) | `156cba8aafd997d27deb0902ba6026bcdcc1cfaf` (2026-01-21) | **Primary spec.** Original behavior, data flow, frame order, and formulas. GPL-3.0. |
| [InsanityBringer/PiccuEngine](https://github.com/InsanityBringer/PiccuEngine) | review snapshot `de4237abf67adc4eefded17bfcd09685ab311e87`; stable `v1.2.2` = `7c2535c4` | Evidence of community-diagnosed defects and fixes. GPL-3.0. |
| [hurleybird/DESCENT-3MASTERED](https://github.com/hurleybird/DESCENT-3MASTERED) | review snapshot `c3e7bf99873f224b2d74f4e02e7b792bb9c35db3` | Evidence of fixes, plus renderer experiments. GPL-3.0. Heavily AI-assisted, so treat its claims as leads to verify. |
| [btb/d2x](https://github.com/btb/d2x) | `c030c4531ad19f1658ea9635ff4ee6861e1d15e0` | Origin of the libmve movie decoder. GPL-3.0-or-later. |
| [apple/game-porting-toolkit](https://github.com/apple/game-porting-toolkit) | `4f42344c90be22112f46becc3fb9687f423f2f88` (plugin `game-porting-skills` 1.0.0-beta.1, Apache-2.0) | Advisory Metal 4 and GameController guidance only. Do not adopt its porting scaffold, C++ bridges, or dual backends. |
| [Debian game-data-packager](https://salsa.debian.org/games-team/game-data-packager/-/blob/e29aab5e60e3bd02e2f3d7c295e9415a2b41ef9f/data/descent3.yaml) | `e29aab5e` | Cross-check of retail file hashes only. |

### Upstream check 2026-09-29

- **Descent3** `upstream/main` is at `a3e82bc2` (2026-09-16). The only change after the pin is PR #733: `Descent3/demofile.cpp` `DemoWriteAttachObjRad` now writes `DT_ATTACH_RAD`, not `DT_ATTACH`. This matters only for demo/replay work, and the port must use the corrected record type there. Keep the pin at `156cba8a`. No release was tagged after `v1.5.0`.
- **PiccuEngine** master is at `4627d77e` (2026-08-27). The 15 commits after the snapshot are portability changes only (64-bit types, include fixes, registry). Nothing to adopt.
- **DESCENT 3MASTERED** master is at `664aefc7` (2026-08-19). The 134 commits after the snapshot and the tags `0.9-Pre-1` to `0.9.1-Pre` are mostly renderer work: per-pixel lighting, bloom, AO, MSAA, and a new terrain renderer. That work includes self-labeled regression checkpoints and reverts (for example `7fb4f60`, `74d2588`, `a7aeecc`, `0f8eff3`). The port adopts only the semantic corrections in section 2. The renderer features are post-1.0 options (see `plan.md`, milestone P5).

### Released-build behavior the source leaves open

- **Game module `rand()`.** The game module DLLs (for example `AIGame.dll`) call the C library `rand()`, not `ps_rand` (`misc/psrand.cpp:39`). The port uses the generator of the MSVC C library of the released Windows build: `holdrand = holdrand * 214013 + 2531011`, result `(holdrand >> 16) & 0x7fff`, on a state of its own that starts at 1 (the CRT default; the module calls `srand` only in its thief code, `AIGame.cpp:1851`). It is saved in `GameWorld.gameModuleRandomState`.

Recheck all three repos at the start of each milestone. Update this section with the new heads and any new corrections.

## 2. Corrections to adopt

Rule: when you translate a legacy path, first read the listed fork diff for that path. Implement the corrected behavior directly in Swift or MSL. Do not first reproduce the known bug. Record the commit in a comment at the translated function.

| Area | Correction | Evidence |
|---|---|---|
| Weapon fire cadence | A battery is ready when `last_fire_time + wait <= Gametime` (inclusive). During one continuous burst, advance `last_fire_time += wait` to keep sub-frame overshoot if the shot is overdue by no more than `max(wait, 1.5 * Frametime)`. Otherwise set `last_fire_time = Gametime`. A new press starts a new burst anchored at `Gametime`. A released button's leftover down-time is not a new activation. The end of a secondary burst resets `firing_time` and stops its sound. | 3MASTERED `dbd611e4`, `bd896ac`, `c47df2d` |
| Post-render sort | Sort **all** N post-render (transparent) items by depth. The original quicksort was buggy. PiccuEngine `c1d3532` drops the last item (off by one). | 3MASTERED fix of Piccu `c1d3532` |
| Look rate | Analog look and turn rate must not depend on frame rate. Divide accumulated axis displacement by the interval it was accumulated over. | 3MASTERED `8dc8714` |
| Input and UI | A key ramp time of 0 works. The homing-missile warning resets each level. The view zoom resets at level start. Weapon auto-select skips weapons with no ammo. | Piccu `f07dcb9`, `bead678`, `3c0b62d`, `e55c23c`, `f3121a8` |
| Sound | Looping sounds cannot be bumped. Bump scoring prefers close sounds. Collision and pain sounds are rate-limited. | Piccu `50ca88a`, `26e9fbc`, `c46f780`, `6442a8d` |
| Object use | Camera Monitor use copies its typed effect before it deletes the backing object (use-after-free fix). | maintained-fork fix, already adopted |
| Visual per-level fixes | Level 3 lava-room fog glow. Level 1 terrain gaps and tunnel clipping. Sky rendering. Level 12 sun/earth blend. Dark polymodel turrets. Blinking baked-light rooms. Invisible level 1 switches. Stray "C" glyph in the level 1 outro. | 3MASTERED `db74678`, `4500f84`, `0fe66a8`, `32a7b66`, `938db02`, `c730d46`, `3dc584a` |

For visual fixes, take the observable result and test it in our renderer. Do not copy shaders.

Do not adopt these platform mechanisms: SDL, xinput, OpenGL profile/FBO code, vsync and frame-pacing experiments, the Vulkan branch, the 32-bit Osiris bridge, or tracker code.

Known open issues in the forks to watch: Piccu #96 (napalm crash in multiplayer), #79 (mirror arc in mission 14), #80 (fast mouse turn tilt), #69 (level 1 "C" glyph). Upstream #732 and #685 (menus tiny at high resolution) apply to our UI scaling.

## 3. Content rights boundary

- The source release has no game data. The player must own a retail copy.
- Retail files and all converted media stay **outside Git**. `retail-data/` and `runtime-data/` are ignored.
- Tests in Git use synthetic or independently licensed fixtures only. Tests that need real content read an opt-in path from an environment variable and are skipped without it.
- A replacement asset may enter the repo only with a recorded author, source, license, and attribution.
- Converting a file does not change who owns it.
- Translated code keeps GPL-3.0 provenance. Cite the legacy file (and fork commit, if any) at the translated function.

## 4. Supported retail input (1.0)

Only one input is supported: a prepared **Descent 3 1.4 + Mercenary** installation directory that matches the known profile exactly. Raw discs, installers, GOG, and Steam layouts are later work.

| File | Hash |
|---|---|
| `Descent 3 Disc 1.iso` (vol `D3_1`) | SHA-256 `7f14425836de3465e36c167ffc0d9f2e71d860421118700689e5b953f7eb4abd` |
| `Descent 3 Disc 2.iso` (vol `D3_2`) | SHA-256 `3e8efecda0579144f740128073c1b4c35ce4254143dcbb9dd9f0d76b53d209f0` |
| `Descent 3 Mercenary.iso` (raw Mode 2/2352, vol `D3_MERCS`) | SHA-256 `76054194a18cd6dc0762a9f8358b24f0ce08419e88d988f4ed34419f59f6fbaa` |
| `dsc3v14u.zip` (1.4 patch) | MD5 `9fa6bfac3a18854635473c57c8b3b803`, SHA-256 `71ab361733b74258c694cb4925ffd5adc471065da07008986d5a66592c020d82` |
| `extra.hog` (476,566 B, from the patch) | SHA-256 `005f035b83d7523e883b4d1b4a103367ac3b7ef45977f18c1ffc89e2f8964df9` |
| `extra13.hog` (278,329 B, from the patch) | SHA-256 `bd257272cbb436b78cacdc8e8ae8f8260922cd023bae88ff848ee89b90807187` |

The other imported files match the Debian game-data-packager hashes. The seven retail fonts are `Briefing.fnt`, `bbriefing.fnt`, `hihud.fnt`, `LARGEUI.FNT`, `Lohud.fnt`, `Newmenu.fnt`, and `SMALLUI.FNT`. HOG name lookup is ASCII case-insensitive.

### How the prepared directory was made (provenance only)

1. Mount the base images read-only.
2. `unshield` Disc 1 `data1.cab`.
3. Copy the missions, voice archives, and MVE movies from both discs.
4. Convert the Mercenary track with `bchunk`, mount it, and extract `d3merc.pkg` and `eng_130.pkg` with `tools/extract_d3pkg.py`.
5. Apply the 1.4 patch to a disposable copy, and keep only `extra.hog` and `extra13.hog`.

### Local layout (all ignored)

```
retail-data/descent3/        curated, verified retail input (the D3Import --source)
retail-data/{source,staging,reference}/   conversion inputs and working files
runtime-data/revival-evidence/            retained local evidence (canonical packages, hashes)
~/Library/Application Support/Descent3Revival/   packages, pilots, and saves installed by the apps
```

## 5. Third-party code

See `THIRD_PARTY.md` (libacm, libmve, plog, stb). Those belong to the legacy C++ reference tree only. The Swift products have no third-party dependencies.
