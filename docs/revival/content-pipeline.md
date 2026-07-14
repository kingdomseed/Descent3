# One-way content pipeline

- Status: accepted
- Date: July 13, 2026
- Authority: binding content and import contract

## Boundary

`D3Import` is the only shipping component that understands the supported prepared-installation containers, naming rules, precedence, and legacy file layouts. It reads verified, owned retail data and writes an immutable canonical Revival package. Nonshipping source-preparation scripts are support evidence, not another importer or runtime path.

```text
verified owned retail input
            |
            v
        D3Import
            |
            v
 read-only canonical base package

 native creator project -- RevivalEditor publisher -- immutable native package

 base package + ordered native packages
            |
            v
 RevivalCore / RevivalMetal / RevivalMac / RevivalEditor
```

The game and editor do not mount HOG archives, open MN3 or D3L files, extract scripts, load retail DLLs, apply retail override order, or search the original installation. They consume only canonical content. `RevivalEditor` may import documented modern media and interchange formats into native projects; it never becomes a second legacy reader.

## Initial source profile

The first supported importer input is a prepared Descent 3 1.4-plus-Mercenary installation directory. The user selects that directory explicitly; `D3Import` accepts it only when the required files match a known source profile. The first profile is the already verified local data set assembled from:

- canonical base-game files extracted from the original two discs;
- canonical Mercenary files extracted from the expansion disc;
- the official 1.4 `extra.hog` and `extra13.hog` overlays;
- the seven recognized retail bitmap-font entries whose six historical roles receive explicit native role decisions;
- the OMF themes, referenced score streams, in-level mission-voice stream archives, and stock pilot pictures selected from the recognized retail archives;
- Windows MVE movies from the owned discs, required for a release-complete campaign import and optional only for a partial development import.

Version 1 `D3Import` does not mount ISO or raw Mode 2 images, read InstallShield cabinets or OPKG installers, run the 1.4 patch, or automate Windows installation layouts. It does not invoke `unshield`, `bchunk`, Wine, Python extractors, or any other legacy preparation tool. Those completed extraction steps are provenance and source preparation. Keeping them outside the product avoids an installer framework before a second source layout exists. Reproducible owned-media preparation scripts and instructions remain in a clearly marked nonshipping support archive so original-disc owners retain a documented path to the supported input.

Support for GOG, Steam, or raw-disc preparation begins only after those exact layouts receive their own verified fingerprints and tests and a real user need justifies the extra code. A source profile describes recognized files and hashes; it is not a promise to accept every installation that resembles the game.

The importer never executes or copies retail executables, installers, `.dll`, `.so`, `.dylib`, multiplayer modules, native Osiris modules, legacy pilot-profile or save files, or unrelated community missions. Recognized stock picture media from `ppics.hog` is content rather than a pilot profile and may be normalized when its import scope requires it.

## Import operation

Import is read-only toward the retail source and atomic toward its destination:

1. discover a recognized source profile;
2. hash and fingerprint relevant files;
3. validate source endianness, container and field bounds, names, case collisions, duplicates, sizes, and references before decoding values;
4. select the dependency closure required by the requested partial or release-complete import scope;
5. resolve retail patch and archive precedence once;
6. decode and normalize the selected levels, models, textures, lightmaps, production font roles, audio (OSF streams and WAV SFX), adaptive-score definitions, mission-voice streams, stock pilot pictures, movies, strings, and tables;
7. bind durable canonical content keys, resolve every reference, and assign dense package-local integer IDs;
8. build the bounded resident `WorldSpine`, map each indoor room and positive-multiple-of-32 terrain grid to fixed cells, prove conservative presentation-demand bounds contain every assigned static drawable, emit the aligned global and per-level presentation records with closed descriptors, and compute every ordinary simultaneous-camera and discontinuous-destination envelope plus the demand-interval-aware movement lead-time proof;
9. select every required entry from the bundled stock behavior catalog, validate its bindings, and attach compiled `BehaviorProgram` data for level, campaign, module-role, package-default, owner, object-archetype, game-mode, and session scopes;
10. write a temporary package and complete import report;
11. atomically promote the package only after all validation succeeds.

An unknown format feature, missing dependency, unresolved reference, or malformed payload fails the affected import with a specific diagnostic. The importer does not silently substitute a retail runtime fallback.

`RevivalMac` supplies the explicit import UI and launches the bundled signed `D3Import` helper as a separate process. The app creates a uniquely named empty staging directory beside the destination and passes all three paths to the helper. The helper writes only inside that staging directory and returns a versioned report plus exit status. The app switches to the new package only after successful atomic promotion. This boundary needs no daemon, XPC service, plugin interface, or in-process legacy parser.

### Helper contract version 1

The complete command shape is:

```text
D3Import --contract 1 --source <directory> --staging <directory> --destination <directory> --scope <training-cluster|training|base|mercenary|stock-multiplayer|all> --report <json-path>
```

`RevivalMac` passes each value as a separate `Process` argument. Standard output is not a machine protocol. On normal completion, the sorted-key JSON report contains the contract and report-schema versions, status, requested scope, recognized source profile and hashes, stock behavior catalog version and hash, destination manifest hash, diagnostics, and whether atomic promotion occurred.

`D3Import` carries one project-owned, versioned `StockBehaviorCatalog` as a signed bundled resource. The catalog contains the reviewed `BehaviorGraph` sources and binding declarations translated from GPL-released generated, handwritten, reusable/default-object, campaign, and multiplayer modules. Its sorted manifest records baseline commit `156cba8aafd997d27deb0902ba6026bcdcc1cfaf`, every source path and hash, translation revision, graph hash, scope identity, expected `ContentKey` binding, and each approved semantic deviation. The helper selects entries by import scope, rejects an incomplete or mismatched catalog, resolves bindings against the imported content, compiles the graphs, and records the catalog manifest hash in its report and output package. No command-line behavior-source path or untrusted code-generation input exists.

A required nonshipping source-analysis tool recovers draft graphs and unresolved-operation reports from the pinned GPL DALLAS sources before human review. That tool is upstream of the catalog, never runs inside `D3Import`, and cannot promote, sign, or mark a translation reviewed. `RevivalCore` and `RevivalEditor` own the reviewed graph source and translation ledger; `D3Import` only validates and consumes the signed catalog resource.

Exit status `0` means a validated package was promoted. Status `2` means invalid arguments or unsupported contract version, `3` means an unrecognized or incomplete source, `4` means decode, validation, or promotion failure, and `70` means an unexpected internal failure. `RevivalMac` maps termination by `SIGTERM` to cancellation.

The helper rejects a staging path that is not an empty sibling of the destination. Because `RevivalMac` chose that path, it can remove it even when termination prevents a report. Cancellation or a nonzero exit leaves the current destination package untouched and the app removes staging. Before promotion, package intake verifies the structured tables and every contributed `global.stream` and `world.stream` whole-blob hash with CryptoKit. If cancellation races with a completed atomic promotion, the app validates that same intake contract and treats the promoted manifest as completed rather than rolling back a valid package. A missing or malformed report is failure unless a newly promoted destination independently passes full intake validation.

Installation of any external canonical package uses the same no-TOCTOU sequence: require every declared path to remain beneath the package root and be a regular file or directory; reject symbolic links, Finder aliases, special files, escaping paths, and multiply linked staged files; materialize every accepted file as newly owned bytes in a unique app-controlled staging directory; close the external source; validate the staged structured data and whole-blob hashes; then atomically rename that exact verified directory into immutable Application Support storage. `D3Import` and `RevivalEditor` publishers write directly into equivalent controlled staging. Runtime file handles never reopen the untrusted source path.

## Package shape

The initial package is an ordinary directory. APFS and Foundation provide its file behavior. ImageIO, Model I/O, and AVFoundation serve import and authoring; AVFoundation plays canonical audio and movies. `WorldStreamer` and Metal I/O exclusively load GPU presentation records from verified stream blobs.

```text
Descent3Revival.content/
  content.json
  global.stream
  campaigns/
  behaviors/
  levels/
    <level-key>/
      level.json
      world.stream
  definitions/
  fonts/
  authoring/
    campaigns/
    levels/
    behaviors/
    definitions/
    assets/
    presentations/
    localization/
  audio/
  scores/
  movies/
  player-media/
  presentations/
  localization/
```

`content.json` records:

- package schema and importer versions;
- stock behavior catalog version, manifest hash, and translation provenance;
- the `simulationSemanticRevision` targeted by compiled behavior and canonical state;
- developer-controlled semantic revisions for each campaign, level, behavior graph, multiplayer mode, and session-definition family;
- the recognized retail profile;
- OS, SDK, media-codec path, and encoder settings used for the import;
- SHA-256 values for accepted source files;
- source-to-output provenance;
- byte-integrity hashes for generated outputs, including each complete stream blob;
- normalized decoded-content hashes for transcoded images, audio, and movies;
- package-layer identity; per-level resident-spine counts and bytes; deterministic room and 32-by-32 terrain cells; conservative presentation-demand bounds; stack-global, level-pinned and cell-referenced record classes; resolved layer/blob locators; checked stream-record ranges, alignments, closed buffer or texture descriptors, and construction hashes; stack-global, level-pinned and per-cell GPU costs; fixed render-radius, maximum-demand-interval and lead-time constants; maximum game-camera and conservative four-viewport envelopes; discontinuous-destination peaks; `LoadWave`, queue, command-buffer and submitted-stale limits; and the supported-envelope results;
- imported, ignored, and rejected entries;
- production and superseded role decisions for every recognized retail bitmap font;
- campaign, stock-multiplayer, and optional-media completeness.

Use `Codable` JSON with sorted keys for manifests, projects, and behavior data and standard Apple-readable media where practical. Each package layer has one raw indexed `global.stream` plus one `world.stream` for each level to which it contributes presentation. The blobs contain aligned GPU-ready records addressed only by checked resolved tables; they have no filenames, runtime override order, compression, executable entries, or general archive API. A resolved locator names its package layer, global or level blob, checked range, and closed project-owned whole-buffer or two-dimensional-texture descriptor. Do not add a general archive, database, virtual filesystem, compression framework, asset graph, or plugin system.

All runtime GPU presentation bytes live only in those stream blobs. Runtime `definitions/` and `fonts/` contain structured metadata; they do not create a second GPU payload or loader path. An imported base also contains a local read-only `authoring/` snapshot in the same canonical source schemas used by `.revival` projects, including derivable structured documents and ordinary decoded geometry, texture, lightmap, glyph-atlas, and other source media. `RevivalEditor` uses that snapshot for inspection and **Derive editable source**; `RevivalMac` never opens it, and the editor never reverse-engineers stream records. Modern source media remains in `.revival` projects. Blob records bind the exact authoring-source and derived-data hashes used to create them, so stale GPU output cannot coexist with newer canonical source. The imported authoring snapshot is converted retail data and remains local and outside Git.

Initial normalization favors runtime simplicity:

| Retail input | Canonical output |
| --- | --- |
| HOG, MN3, and related containers | Removed after their selected entries are resolved into the directory package |
| D3L rooms, portals, terrain, paths, and object placement | Read-only canonical authoring documents, resident typed `WorldSpine`, one indoor cell per room, positive-multiple-of-32 terrain dimensions, fixed 32-by-32-quad outdoor cells, and raw indexed layer blobs |
| Legacy texture encodings | Read-only canonical source pixels plus GPU-ready published texture records referenced by resolved cell tables; no runtime retail or standard-image decode in the streaming path |
| Legacy lightmaps and secondary UVs | Deterministically repacked per room into a provisional single nonmipmapped 1024-square `rgba8Unorm` atlas with two-texel dilated chart gutters and rewritten canonical UV2, then stored with that room cell's presentation records. The historical engine packed unbounded chains of padded 128-square pages with no per-room cap; a Phase 2 whole-retail measurement of packed per-room lightmap area must ratify the atlas dimension and the import overflow rule before either becomes publisher-binding. Until that measurement, overflow is a diagnostic that blocks promotion of the affected room, not an automatic rejection of the entire source profile |
| Legacy models and animation | Read-only canonical authoring geometry and animation, structured runtime definitions, and GPU-ready records referenced by demanded cells and render items |
| Retail bitmap `.fnt` files | Checked one-way decode into canonical glyph metrics, kerning and texture atlases for production font roles; no runtime `.fnt` reader or legacy resolution switch |
| OSF streams (ACM payload) and WAV SFX | OSF (`OSF1`) containers with ACM-compressed payloads for adaptive-score beds, in-level mission voice, and audio taunts; ordinary SFX are PCM WAV. Narrow checked Swift import decode of the OSF/ACM variants proven in the verified profile, then Apple-native PCM or compressed audio through AVFoundation. No standalone `.acm` runtime format |
| OMF adaptive themes | Checked one-way parse into canonical regions, roles, loops, stream references, and transition rules; the active role-request surface is established from the retail themes at import rather than assumed from the library vocabulary; no runtime OMF reader |
| MVE movies | Narrow checked Swift import decode and AVFoundation transcode to a native movie; no MVE decoder in the game |
| Stock pilot pictures | Bounded decode into canonical static profile media; no legacy pilot-profile reader |
| String tables and messages | UTF-8 canonical text |
| Native Osiris mission modules | Rejected; stock behavior comes from project-supplied compiled `BehaviorProgram` data |

The source profile recognizes the logical names `lohud.fnt`, `hihud.fnt`, `briefing.fnt`, `bbriefing.fnt`, `newmenu.fnt`, `smallui.fnt`, and `largeui.fnt`; the verified HOG entries use mixed case. Legacy container matching is ASCII case-insensitive. `D3Import` forms one lowercase ASCII lookup key, rejects two entries with the same folded key, preserves exact source spelling in provenance, and assigns profile-declared canonical `ContentKey` values that do not inherit source-case variants.

All seven verified fonts are proportional 4-4-4-4 color fonts; six carry kerning data and the large-UI font does not. The native product does not recreate the historical low/high-resolution font switch or use retail fonts for ordinary AppKit chrome. Each file receives a recorded production role or an explicit superseded decision. Only fonts with a real stock HUD, briefing, TelCom, or other imported-presentation consumer enter the package; unused legacy roles do not become orphan assets.

Choose the exact standard media encodings during the Training Mission import. Prefer formats that Apple frameworks read directly. `D3Import` implements only the `.fnt`, OSF-with-ACM, WAV, and MVE variants proven present in the verified content and rejects unknown variants. Storage efficiency does not justify a retail decoder or a general transcoding framework in the runtime.

### W-018 lightmap measurement gate

Before Phase 2 freezes the canonical cell and lightmap tables, `D3Import` reports packed per-room lightmap area across the full verified 1.4-plus-Mercenary profile under the historical packing rules. That report either ratifies the provisional one-1024-square atlas and a concrete import overflow policy, or amends the atlas dimension with evidence. Native creator rooms that later overflow the ratified atlas still require a room split; import of owned retail content must not invent a silent second atlas or reject an otherwise valid source profile without that measured policy.

## Content identity

`ContentKey` is a durable namespaced identifier used by behavior graphs, saves, replays, multiplayer configuration, editor documents, and replacement content. It describes game meaning rather than package position, for example a campaign, level, behavior, multiplayer mode, session definition, object definition, placed object, texture, or sound within a known namespace.

The importer resolves keys to dense package-local `ContentID` integers for runtime arrays. Reimporting, sorting files differently, or supporting a second source profile may change `ContentID` values without changing `ContentKey`.

Package hashes prove byte integrity. They do not define save compatibility. The manifest distinguishes its schema version, the global `simulationSemanticRevision`, and separate semantic revisions for each campaign, level, behavior graph, multiplayer mode, and session-definition family. Encoding or layout-only changes keep semantic revisions. A change that invalidates global authoritative rules increments the simulation revision. A change that invalidates campaign transitions, level and world meaning, behavior, or multiplayer rules increments only the affected content revision.

The importer and publisher compare canonical semantic fields with the prior valid package or project product. A save-relevant field change without the corresponding revision bump is a release-blocking diagnostic. The author must increment the affected revision or record a reviewed, explicit semantic-equivalence assertion that explains why existing state remains valid. Byte hashes never auto-bump a revision and never substitute for this decision.

Canonical structured data is byte-deterministic for the same source profile, importer version, and package schema. Apple media container bytes are not assumed to be stable across OS or codec revisions. For transcoded media, determinism means the same normalized decoded pixels, PCM samples, frame timing, and project metadata. The output-file hash proves integrity for that particular import; the normalized-content hash proves semantic equivalence across valid encoder changes.

## Version policy

The importer and runtime support the current canonical package schema. When that schema changes during development, reimport from the curated owned retail source. Do not maintain runtime readers or migration layers for obsolete retail-derived package schemas.

Once a public release makes a new save or editor format user-authored, those formats receive deliberate versioning. Reimport remains the migration strategy for content that can always be regenerated from retail sources.

Reimport writes and validates a complete replacement package before atomic promotion. Failure leaves the active package, saves, replays, projects, and native packages untouched. Successful encoding-only reimports retain all semantic revisions so compatible state continues to resolve through `ContentKey`. A declared simulation, campaign, level, behavior, multiplayer-mode, or session-definition revision change may invalidate only state that binds that scope, with a clear diagnostic or an explicit supported migration.

## Native projects and replacement content

`RevivalEditor` writes inspectable source projects using the layout in [Native creator suite](creator-suite.md):

```text
MyProject.revival/
  project.json
  campaigns/
  levels/
  behaviors/
  definitions/
  assets/
  presentations/
  localization/
```

A project may create a standalone game package or layer new content and replacements over a read-only imported base package. It never mutates or copies untouched base bytes. Ordered layers address durable `ContentKey` values through one typed content catalog. The layer order is declared and deterministic; duplicate ownership and unresolved references are validation errors unless an explicit replacement declares them. Resolution produces one immutable table whose presentation locators name the contributing layer and its global or per-level blob. A replacement package contains only project-owned replacement records; unchanged locators continue to reference the installed base package.

Canonical source contains only authored product state. Open tabs, pane sizes, current selection, transient camera demand, viewport cameras, and other local interface state live in `RevivalEditor` restoration or recovery storage, not in the project. Saves use AppKit's document lifecycle and deterministic canonical encodings so unrelated documents are not rewritten. Recovery remains outside project sources until the creator previews and accepts it. Long-running USD or native-media ingress, preview-record generation, validation, baking, and publishing consume immutable project snapshots and may install a result only when its transient `ProjectEditGeneration` still matches. This generation is not a persisted semantic or compatibility revision.

Modern player pictures, ship logos, and audio taunts enter through native profile or project media validation, never through `D3Import`. Accepted formats are an explicit whitelist. Import caps encoded bytes, decoded dimensions, sample rate, duration, and aggregate storage; strips active metadata; writes only to app-controlled paths; and identifies media by content hash. Published projects also require rights metadata. Multiplayer adds negotiated limits, cooldowns, mute and disable controls, consent where capture or playback requires it, and host policy.

The publisher validates dependency closure, compiles behaviors, builds stale lighting and navigation products, emits the resident `WorldSpine` and immutable presentation records, computes every cell and shared-resource closure, proves each finite presentation-demand bound contains its assigned static drawables, verifies all stream locators, ranges, alignments, closed resource descriptors, construction hashes, and whole-blob hashes, and measures each spatial camera envelope. It validates the stack-global and level-pinned caps, every supported simultaneous game-camera profile, the conservative four-viewport editor bound, every authored discontinuous destination, the maximum incoming `LoadWave`, queue and command-buffer bounds, submitted-stale cap, active high-water, and maximum-demand-interval-aware movement lead-time inequality. It copies canonical nongraphic media, records provenance, and emits one immutable package layer.

Publication rejects an oversized stack-global set, resident spine or schema count, level-pinned set, indoor or terrain cell, malformed or nonfinite presentation-demand bound, uncontained static drawable, simultaneous-camera envelope, teleport, spawn, cinematic, mirror or auxiliary-view destination, `LoadWave`, queue bound, submitted-stale cap, active high-water, or movement lead-time violation. It also rejects terrain dimensions that are not positive multiples of 32 quads. Transient editor viewport positions are local state; publication validates the fixed four-viewport envelope instead of saved editor demand. It does not reject a finite level solely because aggregate streamed presentation bytes exceed active memory. A creator splits an oversized room or mission-scale authoritative world, while ordinary high-resolution presentation remains in the same continuous level. The game-team workflow and mod SDK use this same path. There is no privileged internal package format, HOG export, native plugin payload, or hand-edited generated file. [World streaming](world-streaming.md) defines the only runtime lifetime model.

Every replacement asset records author, source, license, and attribution requirements. Project sources or published packages may enter Git only when their rights permit it. Publicly released creator formats receive explicit version migrations because creator-owned work cannot always be regenerated.

## Rights and local storage

Original and converted retail media remain proprietary and outside Git. Conversion changes representation, not ownership. Public tests use synthetic or independently licensed fixtures.

The importer should eventually store the canonical package under the app's Application Support directory. During development, both retail input and generated packages remain in ignored local directories. Build products, import reports containing local paths, and media captures also remain untracked.

## Incremental implementation

Implement legacy import coverage only as the next playable stock slice uses it:

1. the small room cluster selected from the Training Mission;
2. the complete Training Mission;
3. base campaign level 1;
4. each remaining base level in campaign-graph order, including each secret branch when its entry becomes reachable;
5. each Mercenary level in campaign-graph order, including any secret branch.
6. stock multiplayer maps and their retail dependency closures when Phase 9 begins.

This order keeps legacy format work tied to visible game progress and prevents a general historical parser library from becoming an accidental second engine. It does not limit native project or editor functionality. Every slice adds the matching authoring surface for its canonical types, and the functional-completeness ledger drives the creator work that has no stock-import trigger.

Development imports may be intentionally partial and must say so in `content.json`. A release-complete base or Mercenary import requires every campaign level, behavior program, referenced asset, selected production font role, required audio file, adaptive-score definition and referenced stream, briefing, and movie declared by that verified source profile. The import report records a production or superseded decision for every recognized retail font even when the font is not packaged. A complete stock-multiplayer import requires every committed map and its referenced assets. The release gate fails if required media is absent; only explicitly optional language or bonus content may be omitted. A future GOG or Steam profile defines and verifies its own complete required-media set rather than weakening this gate.
