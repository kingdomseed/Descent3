---
name: d3-content-import
description: Implement, review, and debug D3Import, the macOS-only one-way converter from a prepared retail Descent 3 installation into the canonical Revival content package (levels, models, textures, sounds, music, movies, fonts, scripts data, campaigns). Use for any parser, package format, or import change.
---

# D3 content import

Read first: `docs/revival/sources.md` (retail profile and rights), `docs/revival/architecture.md` (package format and schemas), `docs/revival/engineering.md`.

## Boundary

- D3Import is the **only** code that reads legacy formats: HOG2, MN3, D3L, OOF/OAF, OGF and bitmaps, pages/tables, FNT, OSF/ACM, OMF, WAV, MVE, and `.msg` string tables.
- Players and the editor read only canonical content. They never open retail files, never search for a retail install, and never fall back to one.
- Input: a prepared Descent 3 1.4 + Mercenary directory that matches the known profile exactly (see `sources.md`).
- Output: one canonical directory package. It is written to staging, validated, and promoted atomically.

```bash
D3Import --contract 1 --source <prepared dir> --staging <dir> --destination <pkg> \
  --scope <level-or-mission-key> --report <report.json>
```

- A failure before promotion leaves the old package untouched. Exit 0 means the package was promoted. With no arguments, D3Import prints usage and exits 64.

### Publication safety (keep exactly)

- Staging, the destination package, the report candidate, and the final report are distinct siblings in one existing output folder. Staging must not exist at entry. The report is never inside a package.
- Lock the shared parent. The destination must be absent, or must load as a valid Revival package through the shared canonical loader. An unrelated item at the destination is rejected and left untouched, before the report is written.
- Order: promote the report first → do the final cancellation check → rename the package (this rename is the commit).
- A failure or cancellation before the commit restores the prior report. If the restore itself fails, surface the raw OS error, with no recursive rollback. After the commit, removal of the replaced items is best-effort.

### Installed packages (in the apps)

- Validate every package through the same Core validator. It checks identity and revision, rights metadata, hashes, dependencies, path escapes and special files, and media bounds.
- Stage next to the destination, then promote atomically. If validation or promotion fails, the prior package set stays active. If activation fails after promotion, the new package is installed but inactive, and the prior set stays active.
- Serialize install requests. At launch, remove abandoned staging. If that recovery fails, block new installs.

## Package format

```
<name>.revival/
  content.json                 manifest: schema, importer version, profile, hashes, provenance
  campaigns/  levels/<key>/{level.json, geometry/, lightmaps/}
  definitions/ models/ textures/ fonts/ audio/ scores/ movies/ scripts/ presentations/ localization/
```

- Deterministic `Codable` JSON plus ordinary Apple-readable media.
- Each level is complete: all rooms, portals, terrain, objects, paths, goals, and triggers. There are no room-cut or streaming packages.
- Record the eager `PageInAllData` working set, and record the dependencies that later translated paths reach.
- During development, the only migration is **reimport**. There are no runtime migrations until a public release creates a compatibility promise.

### Change from M1: level scripts are data plus a named Swift script

Before M1, each Training script had its own bespoke `Level` field (package schema 7–11). From M1 (see `plan.md`), the importer emits general data only:

- The level's script **name** (for example `TrainingMission`), which binds to a compiled Swift level script in RevivalCore.
- The level's object script names and custom data from the D3L (`OBJ_SCRIPT` names, level-script name, trigger and goal data).
- String tables (`.msg`), used by the scripts' `Message` lookups.
- The sound, voice, and model references the scripts use, resolved to canonical keys.

It no longer emits per-script structs such as `trainingRASBot1DeathChain`. Bump the package schema once for this change, and delete the old fields and validators in the same milestone.

## Workflow

1. Read the legacy reader and its callers (`cfile/`, `Descent3/LoadLevel.cpp`, `manage/*page.cpp`, `bitmap/`, `model/`, `sndlib/`, `libmve/`, `grtext/`), plus any fork correction in `sources.md`.
2. Write a failing test with a **synthetic** fixture. No retail bytes go in Git. Test the parser through the production entry point.
3. Implement checked reads: little-endian, bounds, counts, names, case-folded collisions, duplicates, and references. Validate once, then produce trusted canonical values.
4. For real-content checks, import the owned retail copy locally, and point opt-in tests at the result (`engineering.md`, section 2).

## Rules

- A malformed file, unknown used feature, missing dependency, unresolved reference, or case collision gives a source-linked diagnostic and a nonzero exit. Never invent data.
- Never copy or execute retail executables, installers, DLLs, or Osiris modules. Scripts are translated Swift, compiled into the app. The package holds only data.
- No virtual file system, asset database, plugin system, daemon, XPC service, or general archive layer.
- Mobile never runs D3Import. It installs a package made on a Mac.

## Verify

- Focused parser test red then green, then the import test group.
- A full local import of the scope you changed, succeeding with a clean report. Record the package hashes in `runtime-data/revival-evidence/`.
- A consumer test proving the app loads the package without opening a retail format.
- Review by Codex (see `engineering.md`, section 6). Delete staging and DerivedData folders after the run.
