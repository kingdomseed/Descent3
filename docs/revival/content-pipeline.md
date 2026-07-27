# One-way content pipeline

- Status: accepted, amended
- Date: July 22, 2026
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

    canonical content -> RevivalCore / RevivalMetal / RevivalMac / RevivalMobile / RevivalEditor

The player applications and editor do not mount HOG archives, open MN3 or D3L files, load retail DLLs, apply retail override order, or search the original installation. RevivalEditor may import supported modern media into native projects; it never becomes a second legacy reader.

The first importer favors traceability over premature normalization. It reproduces source naming, precedence, the complete Training D3L world boundary, the eager `PageInAllData` working set, and lazy-page dependencies reached by the currently translated product path in a canonical form traceable against the released loaders. Phase 1 accepts one room visually, but the production package contains the complete `Level`; one-room packages and synthetic portal cuts are fixtures only. The manifest expands when a later behavior, matcen, or dynamic-spawn path enters the product, so Phase 1 does not pretend to solve Phase 4 reachability. This is not evidence that the old renderer had every resource ready at activation.

This document owns the content contracts. The active import slice, Mac/shared progress, early mobile compatibility work, Phase 8 mobile integration gate, and developer ownership live in the [current implementation plan](current-plan.md); update that file when execution state changes rather than adding a second queue here.

## Initial source profile

The first supported input is the verified prepared Descent 3 1.4-plus-Mercenary installation directory assembled from:

- the original two-disc base game;
- the Mercenary expansion disc;
- official 1.4 extra.hog and extra13.hog overlays;
- the recognized retail bitmap fonts;
- required OMF themes, OSF score and voice streams, WAV sound effects, and pilot pictures;
- required Windows MVE movies.

The user selects that directory explicitly. D3Import accepts it only when required files match a known source profile.

Version 1.0 does not mount disc images, read installer cabinets, run the patch, automate Windows installation, or invoke Wine, Python extractors, or other preparation tools. Reproducible source-preparation scripts and provenance remain nonshipping support evidence.

Version 1.0 supports only this prepared retail profile and requires the user to own it. Support for a second retail layout, raw-disc preparation, another import source, or project-owned replacement assets is uncommitted later work that begins only after an explicit product decision, exact evidence, and a real user need justify the additional cases. A source profile is an exact recognized input, not a heuristic promise to accept every installation.

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

RevivalMac supplies explicit import UI and launches the bundled signed D3Import helper as a separate macOS process. The app passes source, staging, destination, scope, and report paths as separate Process arguments. RevivalMobile never launches D3Import or reads retail data; version 1.0 mobile use therefore requires access to a Mac that can produce the canonical package.

The initial command shape is:

    D3Import --contract 1 --source <directory> --staging <directory>
             --destination <directory> --scope <scope> --report <json-path>

`--scope` selects one or more complete levels or a campaign slice. It never selects a room-cut production world.

The staging path, destination package, and report are distinct siblings in one existing output directory. The staging path is absent at entry; the helper creates and writes package content only there. Its report candidate and final report live beside that package and destination, never inside either package. Publication locks that shared parent, then requires the destination to be absent or to pass the shared canonical package loader as a Revival-owned package. An unrelated file or directory at the requested output name is rejected and preserved before the report is touched. Publication prepares the report first and uses the package rename as the final commit. If supported cancellation or package-rename failure occurs after report promotion but before that commit, the helper restores the prior report; a restoration syscall failure surfaces its real OS error rather than starting recursive rollback. After commit, replaced-artifact removal is best-effort cleanup. Exit zero means a validated package was promoted; a nonzero exit or cancellation before that commit leaves the active package untouched. The report records the recognized source profile, accepted hashes, requested and completed level or campaign selection, source-to-content provenance, eager and currently reachable dependency evidence, diagnostics, destination manifest hash, and whether promotion occurred. Source-file dispositions live only in the checked-in source-translation ledger.

Do not add a daemon, XPC service, plugin API, in-process legacy parser, or general process protocol.

Phase 1 local retail import needs checked paths, destination ownership, atomic replacement, and integrity hashes. It does not prebuild a marketplace threat model or virtual filesystem. The Phase 1 Mac-to-mobile handoff creates the minimum separate native-package validation, staging, promotion and base-activation boundary described below; the first publishing workflow grows that same path in place. Retail import and native package installation do not share a legacy reader or a generic package framework.

## Native package intake and local library

RevivalEditor publishes immutable canonical native packages. RevivalMac and RevivalMobile each own explicit local installation and activation of those packages. RevivalEditor also owns a separate local base library so an authoring project can retain an immutable canonical package reference and reopen after the external import candidate is gone; this Phase 1 base role does not absorb the player library's later enable, disable, replacement, removal, or campaign UX. None of the three applications treats an arbitrary directory as trusted canonical content merely because the importer or publisher normally creates valid output.

Phase 1 implements the shared validation, destination-adjacent staging, atomic promotion, base activation and prior-set recovery needed by the Mac player and editor-base paths. RevivalMobile may wire the system-picker and app-owned-storage handoff to the same Core contract early, but target, simulator, or automated work does not create a physical mobile closure gate. Phase 8 proves the accumulated picker, storage, activation, lifecycle, and recovery path on available physical devices. An open mobile intake state cannot block a Phase 1–7 slice or phase, but it must close in Phase 8 and for version 1.0. Later publishing grows those same validators only with real new schema and adds replacement ordering; `T-018` adds complete player-library actions and campaign UX. No temporary mobile installer or full speculative library precedes them.

Each application serializes accepted package requests through one bounded install-and-activate operation so the presented world and durable active-base reference cannot be reordered by overlapping file-open events. Launch recovery removes abandoned destination-adjacent staging before new intake; if recovery fails, the application blocks new candidates while leaving the unchanged prior active-base record available for loading.

For each install, replacement, or activation:

1. copy or receive the candidate into destination-adjacent staging owned by the receiving application;
2. reject path escape, symlink or special-file surprises, duplicate canonical identities, unsupported revisions, missing rights metadata, invalid hashes, malformed or oversized media, and undeclared or unsatisfied dependencies;
3. construct and validate the candidate's canonical manifest and declared campaign, level, behavior and presentation relationships through RevivalCore;
4. compute the smallest explicit package order needed by the current base and replacement relationship and report conflicts before activation;
5. atomically promote the validated package, then activate the selected set;
6. if validation or promotion fails, preserve the previous installed and active set; if activation fails after promotion, leave the candidate installed but inactive with an actionable diagnostic and keep the prior active set;
7. allow the user to enumerate campaigns and packages, enable or disable an installed package, replace it with a compatible revision, or remove it after reporting any known installed-package dependency or save/profile association and requiring explicit confirmation when one would be orphaned.

Package and campaign identity follows saves, profiles and multiplayer agreement where those paths require it. A released revision promise gains only the migrations or rejection rules that promise needs. The initial library does not imply a marketplace, account, cloud synchronization, background updater, generic dependency solver, public repository, or mandatory signature scheme. Signing is required only where the accepted distribution boundary requires it.

### Mobile canonical-package handoff

RevivalMobile acquires an already canonical package through the system document picker. A security-scoped provider URL is a temporary acquisition boundary, not an installed-content root: the app copies the candidate promptly into app-owned, destination-adjacent staging, releases provider access, and then runs the same canonical validation, atomic promotion, activation and rollback rules used by RevivalMac.

Cancellation, provider revocation, insufficient storage, process suspension and copy failure leave the previous installed and active set unchanged. Durable install state is committed atomically before suspension. Because abrupt process death may provide no cleanup callback, the next launch detects and removes abandoned staging before accepting another candidate, then uses the unchanged prior active set. Reimportable retail-derived packages are marked as excluded from device backup; durable saves and profiles remain separately owned and are not deleted or excluded merely because a package can be recreated. The first implementation does not add mobile retail parsing, a provider-specific integration, cloud synchronization, background package transfer or a second package format.

## Initial canonical package

The package is an ordinary directory package using deterministic Codable JSON for structured values and ordinary Apple-readable files for media where practical. It declares one project-owned content type so the same directory package can cross the macOS and mobile system document-picker boundary; this is packaging metadata, not a second archive or schema. Schema 11 is the current behavior/presentation-usable boundary. It retains schema 3's canonical selected-view RGBA, typed material/procedural, reached lightmap requirements, object-presentation references and canonical OOF model hierarchy, geometry, material, submodel-presentation, provenance and LOD values; schema 4 adds complete resident surface physics; schema 5 adds model collision radii, the reached ship definition and default-player binding; schema 6 makes force-field texture state canonical; schemas 7–9 add the opening lesson, gallery barrier and robot/Guidebot chains with their exact voices, models, navigation and continuation state. Schema 10 adds the exact Camera Monitor/SecurityCamera identities, pickup radius/messages/timers, GPNT-derived camera position/forward, `GuideBotC.osf` and `GuideBotD.osf`, and `PupC1` → `PupC.wav` canonical PCM/provenance. Schema 11 adds the exact Script 043–046 `RASBot1`–`RASBot4` death identities and reused `gyro.OOF` presentations; Script 047's `InvulnPowerup2` handle 2076 / room 12 identity, `Invulnerability` model page and `Powerup pickup` → `Power03.wav`, `Invon.wav` and `Invoff.wav`; Script 048's `CloakPowerup2` handle 2073 / room 11 identity, `cloak.OOF` / `CloakMed.OOF` / `CloakLow.OOF` presentation, `ShpCloakOn.wav` / `ShpCloakOffBeep.wav`, plus the direct Script 034/049 PortalRoom6, FlashLight-4 and timer-tail contract; and Script 050's exact Portal4 room-44/face-1 trigger, final-room messages and `Intro7.osf` entry/format/frame/source/decoded-PCM identity while reusing that barrier and marker contract. This is a smallest forward extension of the unreleased schema rather than schema 12, a behavior catalog or a legacy script carrier. D3Import remains the only OSF/ACM, PCM16-WAV, OOF/page and D3L reader. Its bounded ACM decoder preserves the released one-zero-byte final refill rule; the reached sound path resolves only the selected retail sound pages and validates PCM16 WAV once at import. Reached WAV and OOF readers fail closed on checked PCM byte arithmetic, exact RIFF body/chunk padding and the expected OOF magic/version before accepting payloads. Its OOF boundary reads the reached GPNT parent-offset chain for SecurityCamera without turning the runtime into a model parser, alongside the existing `$facing`, `$rotate=` and `RANI` support. Core receives typed lesson/barrier/combat/Guidebot/Camera Monitor/RASBot/pickup/timed-effect/navigation/model/audio values and validates exact stock identity/digests; AppKit forms transient WAVE containers for AVFoundation. No player/editor legacy reader, runtime sound/page/model reader, second navigation representation or second package format is added. The shared validator accepts a landed schema-9 predecessor whose absent `soundClips` member decodes as the schema-9 empty default, while schemas 10 and 11 require that member and the Camera Monitor chain; earlier unsupported packages remain rejected.

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

Likewise, the historical 32-by-32 terrain grouping is imported as historical terrain data, not promoted into a streaming partition. Terrain rendering and editing decisions follow the roadmap's source-faithful baseline, applicable M4 evidence, and the Phase 8+ mobile-device evidence for an affected mobile claim.

## Content identity and versioning

ContentKey is a durable namespaced identifier used where behavior, saves, editor references, or replacement content must survive package-local reordering. Dense package-local integers may be derived for runtime arrays.

Do not assign durable identity to every value merely because it may be useful later. Use it when an actual reference crosses a save, project, package, or runtime ownership boundary.

Package hashes prove byte integrity. During development, reimport is the migration for retail-derived content. Add semantic revisions and explicit migrations when a released save, replay, project, package, behavior, campaign, or multiplayer contract creates a real compatibility promise. Do not build the complete lifetime revision hierarchy in Phase 1.

## Native projects and replacement content

RevivalEditor writes inspectable source projects:

    MyProject.revivalproject/
      project.json
      campaigns/
      levels/
      behaviors/
      definitions/
      assets/
      presentations/
      localization/

The Phase 1 project source stores the immutable installed-base reference and the sorted delta for its reached room-name edit. On open, the editor resolves and validates the base through its local canonical library and derives one separately owned editable complete `Level` value. Unchanged topology and imported media remain referenced by the base and do not enter `project.json`; only media that a later real edit must own is copied into project source, with provenance preserved and without mutating the base.

The first publishing workflow adds only the explicit base dependency, package order and replacement/conflict rules required by the certification package and the first real replacement relationship. Public migrations arrive with released compatibility promises. Do not force locator tables, copy-on-write package graphs, a general dependency solver, or a complete semantic revision hierarchy into the initial editor-to-play loop.

Canonical source contains authored product state. Open tabs, pane sizes, selection, and viewport cameras remain local UI state. When a real long-running import, bake, validation, or publish operation appears, it consumes an immutable snapshot and may not overwrite newer source. The operation owns the smallest revision check necessary; this is not part of the content format.

The publisher eventually validates dependency closure, behavior, lighting, navigation, references, provenance, rights, and current resource budgets, then emits an immutable native package. Publishing proof does not substitute for the separate RevivalMac and RevivalMobile intake, activation, rollback and removal evidence. An independently authored package certifies the creator suite but is not bundled version 1.0 replacement content and does not waive the retail requirement. The publisher does not emit HOG, D3L, native plugins, or hand-edited generated files.

## Rights and local storage

Original and converted retail media remain proprietary and outside Git. Conversion changes representation, not ownership. Public tests use synthetic or independently licensed fixtures.

Retail input, generated packages, import reports containing local paths, captures, and build products remain in ignored local directories. RevivalMobile stores only its app-owned copy of canonical packages plus its own profiles and saves; it never stores or receives the prepared retail source. Public replacement assets require author, source, license, and attribution provenance.

## Incremental implementation

Expand legacy import only as the next playable stock slice uses it:

1. the complete Training Level topology, eager working set, and Phase 1 reachable dependency manifest, with one selected room as the acceptance view;
2. the additional materials, models, and definitions exercised by the connected Training cluster;
3. the remaining behavior, presentation, and mission dependencies required to complete Training;
4. base campaign level 1 and each remaining level in campaign order, including secrets;
5. Mercenary in campaign order;
6. stock multiplayer maps when multiplayer begins.

Each slice expands the current dependency manifest and advances the corresponding rows in the checked-in source-translation ledger. Through Phase 7, its closure covers D3Import, shared Core and Metal, RevivalMac, and RevivalEditor where applicable. RevivalMobile may consume landed contracts early through target builds and focused automation, but there is no per-slice physical mobile gate. Phase 8 integrates the accumulated package and player paths on available physical devices before version 1.0. A development campaign import may contain a subset of campaign levels, but every included Level has complete topology and uses the one production world type. A release-complete campaign import includes every required level, behavior, font role, audio file, score, briefing, movie, and transition for the recognized profile.
