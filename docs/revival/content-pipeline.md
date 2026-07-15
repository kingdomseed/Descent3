# One-way content pipeline

- Status: accepted, amended
- Date: July 15, 2026
- Authority: binding content and import contract

## Boundary

D3Import is the only shipping component that understands the supported prepared-installation containers, naming rules, precedence, and legacy file layouts. It reads verified owned retail data and writes checked canonical Revival content.

    verified owned retail input
                |
                v
            D3Import
                |
                v
      canonical base content

    native project -- RevivalEditor publisher -- native package

    canonical content -> RevivalCore / RevivalMetal / RevivalMac / RevivalEditor

The game and editor do not mount HOG archives, open MN3 or D3L files, load retail DLLs, apply retail override order, or search the original installation. RevivalEditor may import supported modern media into native projects; it never becomes a second legacy reader.

The first importer favors traceability over premature normalization. It reproduces source naming, precedence, the complete Training D3L world boundary, the eager `PageInAllData` working set, and lazy-page dependencies reached by the currently translated product path in a canonical form traceable against the released loaders. Phase 1 accepts one room visually, but the production package contains the complete `Level`; one-room packages and synthetic portal cuts are fixtures only. The manifest expands when a later behavior, matcen, or dynamic-spawn path enters the product, so Phase 1 does not pretend to solve Phase 4 reachability. This is not evidence that the old renderer had every resource ready at activation.

## Initial source profile

The first supported input is the verified prepared Descent 3 1.4-plus-Mercenary installation directory assembled from:

- the original two-disc base game;
- the Mercenary expansion disc;
- official 1.4 extra.hog and extra13.hog overlays;
- the recognized retail bitmap fonts;
- required OMF themes, OSF score and voice streams, WAV sound effects, and pilot pictures;
- required Windows MVE movies.

The user selects that directory explicitly. D3Import accepts it only when required files match a known source profile.

Version 1 does not mount disc images, read installer cabinets, run the patch, automate Windows installation, or invoke Wine, Python extractors, or other preparation tools. Reproducible source-preparation scripts and provenance remain nonshipping support evidence.

Support for a second retail layout begins only when its exact files are verified and a real user need justifies the additional parser cases. A source profile is an exact recognized input, not a heuristic promise to accept every installation.

The importer never executes or copies retail executables, installers, libraries, multiplayer modules, native Osiris modules, pilot profiles, legacy saves, or unrelated community missions.

## Import operation

Import is read-only toward retail source and atomic toward its destination:

1. recognize and fingerprint the source profile;
2. validate container and field bounds, names, case collisions, duplicate entries, sizes, and references;
3. resolve retail archive and patch precedence once;
4. select the complete levels required by the current campaign slice and the dependencies reachable through the currently translated product path;
5. decode each complete level's rooms, portals, terrain, objects, paths, and goals plus the models, textures, lightmaps, fonts, audio, score, movies, strings, and definitions the current path uses;
6. preserve source-supported ordering and relationships in simple canonical values;
7. record durable content keys, source provenance, hashes, complete-level identity, eager working-set evidence, and the current reachable dependency manifest;
8. bind the validated behavior configuration required by the current slice to the compiled typed Swift behavior in RevivalCore;
9. write and validate a temporary canonical package and import report;
10. atomically promote the package only after every selected complete level and current reachable dependency succeeds.

An unknown used format feature, missing current dependency, unresolved reference, malformed payload, or truncated level fails with a source-linked diagnostic. The importer does not substitute a retail runtime fallback or invent missing data.

The first implementation covers the formats required to construct the complete Training `Level`, its source-evidenced eager working set, and the lazy dependencies reachable through the Phase 1 product path, while visual/editor acceptance remains focused on one selected room. Each parser is the real checked production parser. Later behavior-, matcen-, and spawn-driven coverage expands with the dependency island that makes each path executable.

## Helper boundary

RevivalMac supplies explicit import UI and launches the bundled signed D3Import helper as a separate process. The app passes source, staging, destination, scope, and report paths as separate Process arguments.

The initial command shape is:

    D3Import --contract 1 --source <directory> --staging <directory>
             --destination <directory> --scope <scope> --report <json-path>

`--scope` selects one or more complete levels or a campaign slice. It never selects a room-cut production world.

The helper writes only inside an empty destination-adjacent staging directory. Exit zero means a validated package was promoted; a nonzero exit or cancellation leaves the active package untouched. The report records the recognized source profile, accepted hashes, requested and completed level or campaign selection, source-to-content provenance, eager and currently reachable dependency evidence, diagnostics, destination manifest hash, and whether promotion occurred. Source-file dispositions live only in the checked-in source-translation ledger.

Do not add a daemon, XPC service, plugin API, in-process legacy parser, or general process protocol.

External package installation later receives security hardening proportionate to that actual public boundary. Phase 1 local import needs checked paths, destination ownership, atomic replacement, and integrity hashes; it does not prebuild a marketplace threat model or virtual filesystem.

## Initial canonical package

The package is an ordinary directory using deterministic Codable JSON for structured values and ordinary Apple-readable files for media where practical:

    Descent3Revival.content/
      content.json
      campaigns/
      levels/
        <level-key>/
          level.json
          geometry/
          lightmaps/
      definitions/
      models/
      textures/
      fonts/
      audio/
      scores/
      movies/
      behaviors/
      presentations/
      localization/

content.json records:

- package schema and importer versions;
- recognized retail profile and accepted source hashes;
- imported complete levels, campaign coverage, and translated-feature coverage;
- source-to-output provenance and byte-integrity hashes;
- durable content keys and the current reachable dependency manifest;
- retail format provenance and importer coverage relevant to the selected complete levels;
- behavior binding and configuration revision plus source provenance for the current slice;
- imported, ignored, rejected, and deferred entries;
- rights and local-only status for converted retail media.

Under the current direct-Swift runtime, `behaviors/` contains only validated bindings, initial configuration and state, content references, revision, and provenance consumed by RevivalCore. It contains no Swift source, bytecode, or executable instructions. An accepted behavior amendment may replace that schema, but it must also replace the superseded runtime path.

The initial package does not contain global.stream or world.stream blobs, stream cells, spatial demand tables, Metal descriptor encodings, package-layer locators, or resource-lifetime classes. RevivalMetal prepares the source-evidenced eager working set from the canonical package, then retains any later canonical presentation resources requested by the currently translated product path until the world exits.

Do not add a general archive, database, virtual filesystem, compression framework, asset graph, or plugin system.

## Initial normalization

Preserve enough source shape to make translation errors visible:

| Retail input | Initial canonical output |
| --- | --- |
| HOG, MN3, and related containers | Selected entries resolved once into the directory package; container precedence recorded in provenance |
| D3L rooms, portals, terrain, paths, goals, and objects | Typed canonical level values retaining source order and relationships needed by runtime and editor |
| Legacy textures | Checked decoded pixels plus source sampling, animation, blend, and material meaning |
| Legacy lightmaps and secondary UVs | Source-faithful canonical pages, dimensions, chart relationships, and UV2 sufficient to reproduce the original image before a repack decision |
| Legacy models and animation | Canonical geometry, hierarchy, animation, attachment, and render definitions used by the selected level |
| Retail bitmap fonts | Checked glyph metrics, kerning, and atlas pixels for selected stock roles; no runtime font reader |
| OSF streams and WAV sound | Checked one-way decode of the verified variants into Apple-readable canonical audio |
| OMF themes | Canonical regions, roles, loops, stream references, and transitions |
| MVE movies | Checked import decode and AVFoundation transcode |
| String tables and messages | UTF-8 canonical text |
| Native Osiris modules | Never imported or executed; behavior comes from reviewed source translation |

The verified font profile contains seven mixed-case names. Legacy container matching is ASCII case-insensitive; D3Import rejects folded-key collisions, records exact spelling in provenance, and assigns project-owned content keys. It makes an explicit production or superseded decision for every recognized role rather than carrying unused fonts.

Choose exact standard media encodings when the first real consumer needs them. Implement only verified FNT, OSF-with-ACM, WAV, OMF, and MVE variants; reject unknown variants.

## Lightmap and terrain decisions

The released lightmap representation and terrain LOD data are imported faithfully first. The editor and renderer establish reference images before changing either representation.

The whole-retail lightmap measurement still informs a later packing decision, but a provisional single 1024-square atlas is not a Phase 1 schema law. A replacement layout must demonstrate:

- that every imported room can be represented without losing required sampling behavior;
- stable editor UV and bake semantics;
- improved simplicity, memory, or rendering cost;
- accepted before/after images;
- a migration or reimport plan for current development content.

Likewise, the historical 32-by-32 terrain grouping is imported as historical terrain data, not promoted into a streaming partition. Terrain rendering and editing decisions follow the roadmap's source-faithful baseline and M4 evidence.

## Content identity and versioning

ContentKey is a durable namespaced identifier used where behavior, saves, editor references, or replacement content must survive package-local reordering. Dense package-local integers may be derived for runtime arrays.

Do not assign durable identity to every value merely because it may be useful later. Use it when an actual reference crosses a save, project, package, or runtime ownership boundary.

Package hashes prove byte integrity. During development, reimport is the migration for retail-derived content. Add semantic revisions and explicit migrations when a released save, replay, project, package, behavior, campaign, or multiplayer contract creates a real compatibility promise. Do not build the complete lifetime revision hierarchy in Phase 1.

## Native projects and replacement content

RevivalEditor writes inspectable source projects:

    MyProject.revival/
      project.json
      campaigns/
      levels/
      behaviors/
      definitions/
      assets/
      presentations/
      localization/

The Phase 1 project owns one editable complete `Level` document value derived from the read-only imported base. It references unchanged imported assets and copies only the media that a real edit must own, preserving provenance without mutating the base.

Ordered replacement-package layers and public migrations arrive with the first publishing workflow that needs them. Do not force locator tables, copy-on-write package graphs, or semantic revision machinery into the initial editor-to-play loop.

Canonical source contains authored product state. Open tabs, pane sizes, selection, and viewport cameras remain local UI state. When a real long-running import, bake, validation, or publish operation appears, it consumes an immutable snapshot and may not overwrite newer source. The operation owns the smallest revision check necessary; this is not part of the content format.

The publisher eventually validates dependency closure, behavior, lighting, navigation, references, provenance, rights, and current resource budgets, then emits an immutable native package. It does not emit HOG, D3L, native plugins, or hand-edited generated files.

## Rights and local storage

Original and converted retail media remain proprietary and outside Git. Conversion changes representation, not ownership. Public tests use synthetic or independently licensed fixtures.

Retail input, generated packages, import reports containing local paths, captures, and build products remain in ignored local directories. Public replacement assets require author, source, license, and attribution provenance.

## Incremental implementation

Expand legacy import only as the next playable stock slice uses it:

1. the complete Training Level topology, eager working set, and Phase 1 reachable dependency manifest, with one selected room as the acceptance view;
2. the additional materials, models, and definitions exercised by the connected Training cluster;
3. the remaining behavior, presentation, and mission dependencies required to complete Training;
4. base campaign level 1 and each remaining level in campaign order, including secrets;
5. Mercenary in campaign order;
6. stock multiplayer maps when multiplayer begins.

Each slice expands the current dependency manifest and closes the corresponding rows in the checked-in source-translation ledger, then gains its matching editor path. A development campaign import may contain a subset of campaign levels, but every included Level has complete topology and uses the one production world type. A release-complete campaign import includes every required level, behavior, font role, audio file, score, briefing, movie, and transition for the recognized profile.
