# Retail data and provenance

- Status: verified evidence and active rights boundary
- Last verified: July 13, 2026
- Last reconciled: July 15, 2026
- Authority: hashes and rights are binding; legacy execution instructions are non-normative

## Rights boundary

The source release does not include original game data. Keep owned retail files and all converted proprietary media outside Git. The new game uses a local one-way importer; it does not redistribute, modify in place, or mount the retail installation at runtime.

Replacement assets enter the repository only when their rights and required attribution have been established independently.

## First supported source profile

The verified local source is an original two-disc Descent 3 set plus the Mercenary expansion:

| Image | Format | SHA-256 |
| --- | --- | --- |
| `Descent 3 Disc 1.iso` | ISO 9660, volume `D3_1` | `7f14425836de3465e36c167ffc0d9f2e71d860421118700689e5b953f7eb4abd` |
| `Descent 3 Disc 2.iso` | ISO 9660, volume `D3_2` | `3e8efecda0579144f740128073c1b4c35ce4254143dcbb9dd9f0d76b53d209f0` |
| `Descent 3 Mercenary.iso` | raw Mode 2/2352 image, volume `D3_MERCS` | `76054194a18cd6dc0762a9f8358b24f0ce08419e88d988f4ed34419f59f6fbaa` |

The Mercenary filename is misleading: it is a raw CD image rather than a normal cooked ISO. `bchunk` converts its single data track into a mountable 2048-byte-sector ISO. Its `d3merc.pkg` is an uncompressed Outrage OPKG archive. [`tools/extract_d3pkg.py`](../../tools/extract_d3pkg.py) extracts that format without executing the Windows installer.

The imported base and Mercenary files match hashes tracked by Debian's [game-data-packager](https://salsa.debian.org/games-team/game-data-packager/-/blob/master/data/descent3.yaml), including `d3.hog`, `ppics.hog`, `merc.hog`, campaign and expansion missions, voice archives, and MVE movies.

GOG and Steam, raw-disc preparation, other import sources, and project-owned replacement assets are not version 1.0 commitments. Any may become later work only after an explicit product decision and independent verification of the exact inputs, rights, and maintenance cost; no store layout is assumed to match the CD-derived profile.

## Official 1.4 update

The discs contain the 1.0 base game and the Mercenary-era 1.3 update. The official `dsc3v14u.zip` updater was applied to a disposable Windows-format staging copy assembled from the owned discs. The archive's published MD5 is `9fa6bfac3a18854635473c57c8b3b803`; its SHA-256 is `71ab361733b74258c694cb4925ffd5adc471065da07008986d5a66592c020d82`.

The promoted archives match Debian game-data-packager's [pinned Descent 3 manifest](https://salsa.debian.org/games-team/game-data-packager/-/blob/e29aab5e60e3bd02e2f3d7c295e9415a2b41ef9f/data/descent3.yaml):

| Archive | Size | MD5 | SHA-256 |
| --- | ---: | --- | --- |
| `extra.hog` | 476,566 bytes | `f85aeb616f6526abc3b69ede85b7635d` | `005f035b83d7523e883b4d1b4a103367ac3b7ef45977f18c1ffc89e2f8964df9` |
| `extra13.hog` | 278,329 bytes | `abd02761ac04fe9677c661d62dadc446` | `bd257272cbb436b78cacdc8e8ae8f8260922cd023bae88ff848ee89b90807187` |

Both are structurally valid `HOG2` archives: tables have sorted unique case-insensitive names, data offsets match table sizes, and payload extents end at EOF. There is no `extra14.hog`; version 1.4 retains the historical `extra.hog` and `extra13.hog` names. `extra13.hog` supplies `extra.gam` and the Black Pyro assets.

The updater ran in an isolated ignored prefix using a temporary Wine 11 bundle. Wine was never a product dependency or a runtime plan. The 1.3 staging tree was preserved, the updater touched only a cloned treatment tree, and only the two validated HOG archives were promoted. Historical Windows executables and readme files were not imported into the curated data tree.

## Verified retail fonts

The prepared source profile contains these seven bitmap-font entries:

| Exact source spelling | Flags | Historical role |
| --- | ---: | --- |
| `Briefing.fnt` | `0x17` | Briefing text |
| `bbriefing.fnt` | `0x17` | Bold briefing text |
| `hihud.fnt` | `0x17` | High-resolution HUD variant |
| `LARGEUI.FNT` | `0x13` | Large UI text |
| `Lohud.fnt` | `0x17` | Standard HUD variant |
| `Newmenu.fnt` | `0x17` | Menu text |
| `SMALLUI.FNT` | `0x17` | Small UI text |

The format flags in [`grtext/grtext.h`](../../grtext/grtext.h) and the loader in [`grtext/grfont.cpp`](../../grtext/grfont.cpp) show that all seven are proportional 4-4-4-4 color fonts. Six are kerned; `LARGEUI.FNT` is not. The mixed spelling confirms that retail HOG lookup must be ASCII case-insensitive. Import provenance retains the exact source spelling, while the one-way importer rejects case-fold collisions and emits profile-declared canonical keys.

These entries are proprietary local evidence. Their pixels and converted atlases remain outside Git.

## Current ignored layout

```text
retail-data/
  source/             converted images, patch archives, and extraction metadata
  staging/            complete uncurated extractor output
  descent3/           curated verified retail input
  revival-content/    future canonical output from D3Import

runtime-data/
  legacy reference-run configuration, logs, screenshots, and disposable caches
```

Both top-level directories are ignored by Git. The final application will place its canonical package in its own Application Support container. The repository layout is for development and provenance work.

Do not copy retail executables or native modules into `retail-data/descent3/`. Keep complete installer output under ignored staging only when an import question requires it.

## Historical extraction procedure

This procedure explains how the verified source profile was assembled. It is provenance, not the final customer importer:

1. mount both base-game images read-only;
2. use `unshield` on Disc 1's `data1.cab` to recover base archives, missions, menu movie, and optional pilot templates;
3. copy split campaign missions, voice archives, and MVE movies from both discs;
4. convert the Mercenary Mode 2/2352 track with `bchunk` and mount the result read-only;
5. extract `d3merc.pkg` and `eng_130.pkg` with `tools/extract_d3pkg.py`;
6. assemble required data under `retail-data/descent3/` and verify hashes;
7. apply the official 1.4 patch to a disposable staging copy;
8. promote only the validated `extra.hog` and `extra13.hog` outputs.

Version 1.0 `D3Import` begins with the resulting prepared 1.4-plus-Mercenary installation directory. This prepared directory is the user-selected release input, not merely a hidden developer intermediate. Version 1.0 is explicitly limited to users who already possess a supported prepared installation, obtained from their own installed and patched copy or the already verified local preparation. Raw images and installer media are not accepted by the version 1.0 product. `D3Import` does not replace or invoke ISO mounting, InstallShield or OPKG extraction, Mode 2 conversion, patch execution, `unshield`, `bchunk`, Wine, or the historical Python extractor. Those remain separately documented source-preparation provenance and move to the nonshipping support archive at the Phase 10 retirement gate. Its narrower checked import contract is specified in [One-way content pipeline](content-pipeline.md).

## Legacy reference execution

The old C++ reference can still mount the curated data for a focused research question:

```sh
rtk proxy tools/run-descent3-macos --check
rtk proxy tools/run-descent3-macos -windowed -width 1280 -height 720 -nointro
rtk proxy tools/run-descent3-macos -windowed -width 1280 -height 720 -nointro -nonetwork -nomousegrab -pilot codex -mission d3 -loadlevel 1 -tempdir "$PWD/runtime-data/v14-smoke/cache" -logfile -loglevel debug
```

This helper and the old engine's `-additionaldir` behavior are not part of the new runtime. The Swift game starts only from `retail-data/revival-content/` during development or the installed canonical package later.

## Verified legacy reference-execution evidence

The native arm64 reference build successfully:

- opened the retail archives and loaded 895 strings;
- extracted 55 current macOS Osiris script modules from `d3-osx.hog`;
- loaded 5,554 asset pages;
- loaded the base-game `fury.mn3` level to 100 percent and entered its server loop;
- recognized `merc.mn3`;
- created a 1280 by 720 OpenGL window with audio enabled and MVE data mounted;
- rendered the animated main menu, created a pilot, and accepted keyboard navigation;
- entered the original Training Mission and rendered its cockpit, HUD, textures, lightmaps, geometry, and GuideBot instruction overlay;
- loaded canonical 1.4 overrides and applied all 22 Black Pyro-related pages;
- entered rendered base campaign level 1 through briefing and ship selection on the M4.

The corresponding logs and screenshots remain under ignored `runtime-data/v14-smoke/`. They prove source authenticity and supply useful archaeological evidence. Mercenary graphical verification and exhaustive old-client input or audio testing are no longer roadmap gates.

## New importer contract

The first importer profile must accept the prepared verified 1.4-plus-Mercenary directory above, resolve overlay order, import each requested Level with complete topology, include its eager and currently reachable lazy dependencies, reject native code, and emit a deterministic provenance report. Development campaign packages may contain a subset of complete levels; they do not contain room-cut production levels. Release-complete campaign packages must contain every required movie, audio file, selected production font, briefing, level, and behavior-data record required by the one current canonical runtime, plus a production or superseded decision for every recognized font. Under the current direct typed Swift runtime, behavior data consists only of validated bindings, initial configuration and state, content references, revision, and provenance; packages contain no executable behavior. An evidence-ratified amendment may replace that form but may not retain it as a parallel path. Complete stock-multiplayer packages must contain every committed map, mode behavior, referenced asset, and matching completeness metadata. Schema changes reimport from this source rather than adding legacy readers or package migrations to the runtime. Reimport is atomic and must preserve the active package, saves, replays, projects, and native packages on failure.
