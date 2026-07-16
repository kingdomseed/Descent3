# Source translation ledger

- Status: Phase 0 seed
- Date: July 16, 2026
- Authority: execution record under [Source translation discipline](source-translation.md)

## Use

This ledger accounts for source ownership and disposition. It is separate from the functional-completeness ledger, which accounts for product capabilities.

The active packet, checkpoint, lane, owner, blocker, and next work live only in the [current implementation plan](current-plan.md). This ledger records source evidence and row state; do not turn it into a competing task queue or current-state diary.

Seed likely source owners as provisional hypotheses. Before an island boundary is fixed, run the bounded [fog-of-war preflight](source-translation.md#fog-of-war-preflight), record the inspected entry points and source or code areas in the affected row text or change record, and add every dependency the pass exposes. Continue tracing real include, call, data, and editor paths while the island is working. Before it closes, replace provisional notes with exact relevant symbols, tests or captures, deliberate differences, native files, and final dispositions.

No `discovery complete` column or graph identifier is added: a bounded pass cannot prove that no edge remains. A deterministic generated relationship view may support a row only with recorded source, tool, configuration, and output provenance. It does not replace a source-verified relationship, disposition, observable contract, or the manual accounting required at closure.

Allowed dispositions are translate, platform replacement, import only, superseded mechanism, evidence only, exclude, and deferred. A mixed legacy file may have more than one disposition with named ranges or symbols.

States are seed, traced, translating, native-running, verified, replaced, excluded, or deferred. `traced` requires exact relevant symbols, callers, ordering, and attached evidence; a high-level file summary remains `seed`.

Record only translation hazards actually present in the current island inside the existing role or contract text: observable evaluation order and side effects; build-mode, macro, or compile-variant behavior; numeric conversion, truncation, overflow, or sentinel handling; index and capacity assumptions; and ownership, aliasing, reentrancy, or teardown order. Do not add empty checklist fields or create a project-wide lifetime inventory. When review finds a repeatable source-to-Swift error, record the concrete rule and audit previously translated rows for the same pattern.

`translating` includes code that only builds, links, or reaches an entry point. `native-running` requires the row's observable contract to execute through the applicable real shipping or creator path with focused green evidence. `verified` is the terminal state for translate, import-only, and evidence-only work after its source or reference comparison, deliberate differences, and applicable island evidence close. `replaced` requires the named platform replacement or superseding native mechanism to satisfy the row's observable contract with the same applicable evidence; naming a replacement is not enough. `excluded` requires approved reachability or scope evidence. `deferred` requires a named roadmap phase or missing dependency and proof that the deferred behavior is not required by the current claimed result.

Named ranges in a mixed-disposition file may share one state only while every range has reached that state. Split the row when their states diverge. A stub, stand-in constant, disabled production branch, reduced placeholder limit, or skipped test protecting the current contract cannot advance a row. Any other nonexecuted test must be inapplicable under an approved terminal disposition with replacement or removal evidence; an explanation alone is insufficient.

## Phase 1 level and acceptance-room record

This record was completed from full-build source plus a bounded run of the owned local retail Training data before import production began. The capture observed the complete reference `LoadLevel` result before `StartLevel`; it did not create a partial level or select a room during loading. Retail data, converted data, and the detailed capture remain local and ignored. The acceptance room narrows visual and editor proof; it does not cut the imported `Level`.

| Field | Recorded decision |
| --- | --- |
| Mission and level key | Full-build `Descent3/menu.cpp` identifies `Pilot Training` and loads `training.mn3`; `LoadMission` then exposes its sole level, `TrainingMission.d3l`, to `LoadMissionLevel` and `LoadLevel`. The project-owned canonical keys are mission `descent3.mission.pilot-training` and level `descent3.level.training-mission`. Filename spelling and case are import evidence, not canonical identity. |
| Complete-level evidence | The owned local `training.mn3` capture is 5,059,244 bytes with SHA-256 `fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54`; its 39-entry HOG2 table places the 1,106,008-byte `TrainingMission.d3l` at offset 3,557,737 with SHA-256 `915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41`. The unfiltered reference load produced 48 used rooms across source indices 0 through 50, 112 directed portal records, 40 used objects, 65,536 terrain cells, two paths, and one goal. The reference loader reported level checksum `6db74a2eb0c563de4eb11e6d4e91e59c`. These identify this owned capture; they do not promise that every retail release has identical bytes. |
| Acceptance-room identity | Source room index 3. The room has no authored name, so diagnostics and evidence call it `source-room-3`; the canonical model does not invent a stock-content name. |
| Selection reason | Room 3 is a small but substantive first island: 18 faces, two real portal boundaries, 17 faces with lightmap-info records, four referenced texture handles, and one placed `OBJ_POWERUP`. Its D3L record stores generic-table index 67 (`Invisiblepowerup`) and instance name `StartCourse`; `ReadObject` maps that through `generic_xlate` to reference-runtime object-info ID 68. Import must preserve the stored identity and perform the evidenced translation rather than reading raw ID 68, which names a different GNNM entry. The room exercises topology, material/lightmap data, and object representation without making the acceptance surface large. |
| Connected portal neighbors | Room 3 portal 0 is on face 0 and connects to room 2 (`PortalRoom1`) portal 1 with source flags 1. Room 3 portal 1 is on face 17 and connects to unnamed room 4 portal 0 with source flags 0. Room 2 also connects to room 1; room 4 also connects to room 5. All of those rooms remain in the complete resident `Level`; the first acceptance proves only room 3's two edges. |
| Dependency capture | With reference player ship index 0, the reference `PageInAllData` pass marked 232 unique texture handles, 115 unique sound handles, and 88 unique model handles; the loaded level held 2,531 used non-dynamic lightmap-info records. Room 3 reaches texture handles 908, 793, 1332, and 985, the 17 lightmap-info handles recorded below, and the stored `StartCourse` object identity above. This is the historical eager baseline, not a claim that the canonical importer already exists or that later lazy closure is complete. Object initialization and every later matcen, spawn, behavior, effect, and media dependency are added when the translated product path can reach them. Runtime preparation will consume the resulting canonical manifest, never these retail handles directly. |

### Source-room-3 face dependency baseline

The handle values below are local source identities used to compare the first import; they are not proposed canonical handles. Source value 65,535 is the no-lightmap-info sentinel observed on face 0.

| Face | Texture handle | Lightmap-info handle |
| ---: | ---: | ---: |
| 0 | 908 | 65,535 (none) |
| 1 | 793 | 2,141 |
| 2 | 1,332 | 926 |
| 3 | 793 | 1,082 |
| 4 | 1,332 | 823 |
| 5 | 793 | 28 |
| 6 | 1,332 | 1,211 |
| 7 | 793 | 657 |
| 8 | 1,332 | 1,795 |
| 9 | 985 | 389 |
| 10 | 1,332 | 291 |
| 11 | 985 | 1,745 |
| 12 | 1,332 | 2,348 |
| 13 | 985 | 1,295 |
| 14 | 1,332 | 1,592 |
| 15 | 985 | 149 |
| 16 | 1,332 | 177 |
| 17 | 793 | 1,373 |

### Archived bounded research record

Commit `73f3cce41871fb28d67a7fc0b467b55bad81d26e` archives the GPL-3.0-or-later evidence-only `tools/research/training_d3l_audit.rb`, `training_reference_runtime_trace.patch`, `training_reference_dependency_trace.patch`, and their `README.md` replay procedure. The parser mirrored only the released field order needed to audit the HOG table, D3LV-127 chunk walk, rooms, faces, portals, stored objects, paths, and goals. Its deterministic ignored output `runtime-data/revival-evidence/training-d3l-audit.txt` has SHA-256 `d20d6c34a5ac9f20eee3c500648d9a4514de668ad6af9984f7f8ce1e534e6ea4`. The two patches observed the complete post-`LoadLevel` state, the completed `PageInAllData` mark sets, and room-3 faces; their archived procedure records the applied/reversed patch, Debug build, absolute `-additionaldir` order, local pilot, private trace flag, ignored output, clean-source check, and required ship index 0.

Those four tracked artifacts were deleted from the live checkout at their accepted gate before production import implementation. Their exact contents and reproduction procedure remain recoverable from the archived commit; no live document links to deleted paths.

The ignored `runtime-data/revival-evidence/training-room-runtime-trace.log` capture has SHA-256 `349e68ed340e8f18cd4a8b86193ea11b4b54b4dcffa38b648f154525f9b737dd`; its instrumented reference binary has SHA-256 `269cd2250124fed581938e651063db631cb1f0e5da885aded480496cc3ed4a44`. The ignored ship-index-0 `runtime-data/revival-evidence/training-dependency-trace.log` capture has SHA-256 `32aada64f1ccdbdc9f37289806ab986edb91b3c2c342b885a9ae22e09a8ac2aa`; its instrumented reference binary has SHA-256 `49be8216c866304d4d4a98c03e627cf16d0c05ed3644f8596aa5bdfb277d98b9`. Both probes built and exited only as bounded historical research. No diagnostic patch is applied, and no retail artifact, converted asset, research flag, or second runtime path enters a product target.

## Phase 1 complete-level and acceptance-room seed

### Slice 1 HOG2 bounded preflight

The preflight inspected the active reader (`ReadHogHeader`, `ReadHogEntry`, `cf_OpenLibrary`, `cf_OpenFileInLibrary`, and `open_file_in_lib`), active CMake writer (`HogHeader`, `HogFileEntry`, `HogFormat::AddEntry`, `SortEntries`, and both stream operators), source tests and tracked fixture, creator-facing HOG editor load/sort/rewrite path, and obsolete legacy duplicate. The confirmed ledger gap was missing accounting for the active writer, source tests, creator path, and excluded duplicate; the rows below correct it. No linked unknown prevents the direct parser contract.

The checked boundary treats 68 as the absolute header size and table start, computes `68 + count * 48` and every ordered payload extent with checked arithmetic, and permits a first-payload offset after the table so header-to-payload padding remains source-compatible. A zero-entry archive is valid when its declared first-payload offset reaches EOF. The parser rejects short headers/tables/payloads, table overlap, payload-offset overflow, payload extents beyond EOF, and unexplained bytes after the final payload. Names preserve exact spelling but must contain a NUL within the 36-byte field and contain only ASCII bytes before it; the active writer's exactly-36-byte unterminated output is deliberately rejected because all active and creator readers assume a C terminator. Folded ASCII keys must be strictly increasing, so out-of-order records and exact or case-folded duplicates/collisions fail instead of entering the source reader's ambiguous binary lookup.

#### Slice 1 implementation evidence

The production-contract red failed at compile time because `parseHOG2(_:)` did not exist, so testing was cancelled with 0 tests executed. The tracked source fixture then passed through the new production parser, and thirteen independently failing malformed-boundary contracts were each observed red before their production correction and then green. Three source-supported positive edge cases — zero entries, zero-length payloads, and header-to-payload padding — passed as characterizations of the generic parser path.

The final affected suite executed all 17 HOG2 tests with 0 failures and no skipped case. D3Import, RevivalMac, and RevivalEditor each built and linked in Debug and Release; every Release executable is arm64 with macOS 26.0 minimum and macOS 27.0 SDK load commands. Release D3Import prints only its usage contract and exits 64 when invoked without arguments, so the checked parser is deliberately not claimed as a complete shipping retail-processing path. The Slice 0+1 landing commit owns the exact red, green, suite, build, and entry-point commands and results.

| Legacy path | Historical role and dependency | Native owner | Provisional disposition and contract | State |
| --- | --- | --- | --- | --- |
| Descent3/descent.cpp | Game entry, global mode selection, main-loop and editor-game integration | RevivalMac, RevivalMobile, RevivalCore | Translate startup and game-loop order once; replace platform/window ownership through concrete AppKit and UIKit entry points; exclude global Function_mode and compile variants | seed |
| Descent3/init.cpp | Shared initialization entry points with editor-specific branches | RevivalCore, RevivalMac, RevivalMobile, RevivalEditor | Translate required initialization dependencies into explicit ownership; replace platform and legacy manager setup | seed |
| logger/log.cpp | Console and rolling-file logger initialization and severity routing | D3Import, RevivalMac, RevivalMobile, RevivalEditor | Platform replacement with direct OSLog categories and private fields; retain only bounded local evidence the real support workflow needs; exclude automatic upload and legacy logger machinery | seed |
| Descent3/gamesequence.cpp | `StartLevel`, `PageInAllData`, activation, `FreeThisLevel`, and cache flush | RevivalCore, RevivalMetal, RevivalMac, RevivalMobile | Translate the eager working-set walk, activation order, and single-owner release; trace rather than assume complete closure; supersede page/cache machinery | seed |
| Descent3/LoadLevel.cpp | D3L decode and encode, room/terrain/object/path/goal construction, editor-linked helpers | D3Import, RevivalCore, RevivalEditor | Import legacy decode semantics in D3Import; translate canonical relationships; replace legacy save with native project save; split accidental editor include dependency | seed |
| `cfile/hogfile.{h,cpp}`; HOG ranges of `cfile/cfile.cpp` | `ReadHogHeader` decodes the tag, little-endian count, and first-payload offset; `cf_OpenLibrary` seeks to absolute offset 68, reads 48-byte records with `ReadHogEntry`, publishes the library globally before validation completes, asserts only nondecreasing `stricmp` order, copies assumed-NUL names, and accumulates `uint32_t` payload offsets unchecked. `cf_OpenFileInLibrary` and `open_file_in_lib` binary-search that ordered table, making folded collisions ambiguous; a zero-entry mount can later index an empty table. The active reader ignores reserved header bytes, permits a gap before the first payload, and never proves payload EOF or rejects trailing bytes | D3Import — `Revival/Sources/D3Import/HOG2Archive.swift` | GPL-derived import-only Swift translation through one direct checked parser; preserve exact entry spelling, flags, timestamps, table order, and declared ordered payload offsets while deliberately hardening termination, ASCII folding, collisions, arithmetic, complete extents, and trailing-byte rejection. `Revival/Tests/D3ImportTests/HOG2ArchiveTests.swift` proves the tracked source fixture and focused boundary contracts. No global mount state, virtual filesystem, runtime archive reader, or partial publication. The row remains nonterminal because the fail-closed D3Import entry point does not yet exercise a complete shipping import path | translating |
| `tools/HogMaker/HogFormat.{h,cpp}`; `tools/HogMaker/HogMaker.cpp` | Active CMake writer: emits `HOG2`, little-endian count and first-payload offset, 56 `0xff` reserved bytes for a 68-byte header, sorted 48-byte records, then contiguous payloads in table order. `HogFormat::AddEntry` increments count and offset unchecked; `SortEntries` folds all 36 raw bytes with `tolower` and rejects no equal key. The CLI accepts an empty/all-skipped list as a header-only archive, writes no padding or trailing bytes, and accepts exactly 36 bytes, producing no NUL while `GetName()` assumes one. Non-ASCII UTF-8 bytes are accepted with locale-sensitive sorting | D3Import | Evidence only for the live writer contract; D3Import reads but never emits HOG. The native parser accepts header-to-payload padding and zero entries, rejects trailing bytes, uses explicit ASCII folding, rejects folded collisions, and records the 36-byte case as deliberate boundary hardening | traced |
| `cfile/tests/cfile_tests.cpp`; `cfile/tests/TestDir/test.hog` | `D3.CFileIO` and `D3.CFileLibrary` mount the tracked HOG, look up `lowercase.txt` case-insensitively, read its four-byte payload, and compare length and CRC. The 120-byte fixture has SHA-256 `2b620319af6013e477f0f32630ac665cd4bcf13d786eebe5883c694c23c63edc`: one record at 68, first payload at 116, flags 0, timestamp `0x667f1e91`, bytes `TEST` | D3Import tests | Evidence only for the valid source checkpoint and lookup outcome; the tracked fixture is bundled into `D3ImportTests`, while small in-test builders cover malformed boundaries without retail data | traced |
| `legacy/hogedit/HogEditDoc.cpp`; `legacy/hogedit/HogEditView.cpp` | Creator-facing MFC tool expresses load, extract, add, delete, sort, and rewrite workflow intent; `AddFile` rejects case-insensitive duplicates and the view sorts before rewrite. Its binary path is not valid active HOG2 evidence: it adds the four-byte tag to absolute `HOG_HDR_SIZE` when loading and declaring/seeking rewritten data, creating a deterministic 68-versus-72 conflict even though its filler places the physical table at 68. Active-writer archives therefore open with names shifted by four bytes, and rewrites declare payload four bytes late while using the wrong table position. It also inherits unchecked lengths, assumed-NUL names, and legacy UI/file replacement machinery | D3Import, RevivalEditor | Evidence only for creator workflow intent, case-insensitive sorting, and duplicate rejection. Explicitly exclude HogEdit's current binary read/rewrite behavior, MFC UI, mutable archive editing, backward HOG export, and temporary-file handoff; RevivalEditor publishes canonical native packages rather than HOG | traced |
| `legacy/hogmaker/hog.cpp` | Obsolete duplicate reader/writer outside active CMake: `ReadHogHeader` writes while nominally reading, name I/O uses `strlen` on uninitialized or fixed fields, its table positioning conflicts with the active 68-byte layout, and `NewHogFile` rejects zero entries | None | Exclude as defective, duplicated, and unreachable from the active build. The active reader/writer and fixture above provide the format evidence; no native counterpart or compatibility path | excluded |
| `cfile/cfile.cpp` remaining directory, precedence, and virtual-file ranges | File lookup, mounted-library precedence, case handling, and reads outside the bounded HOG table path above | D3Import | Trace later import precedence semantics once; exclude runtime virtual filesystem and global library state | seed |
| Descent3/Mission.cpp | MN3 mission metadata, HOG selection, level paths and campaign declarations | D3Import, RevivalCore | Import current Training scope; translate campaign meaning later; exclude runtime HOG mounting | seed |
| manage/manage.cpp | Page database, lookup, network locks, paging and dependency access | D3Import, RevivalCore | Translate used definition, eager and lazy dependency meaning into direct canonical lookup; exclude network lock/check-out machinery | seed |
| manage/texpage.cpp | Texture page decoding and definition fields | D3Import, RevivalCore | Import only for retail fields; translate canonical texture/material meaning | seed |
| Descent3/room_external.h | Room, face, portal, UV, lightmap and role data contracts | D3Import, RevivalCore, RevivalMetal, RevivalEditor | Translate reachable field meaning; replace bitmask/API shape with explicit native values where evidence is complete | seed |
| Descent3/room.cpp | Room allocation, topology and lifecycle operations | RevivalCore, RevivalEditor | Translate current room/portal behavior and editor operations; omit memory wrapper and fixed-array accidents | seed |
| Descent3/terrain.cpp | Terrain world data and update helpers | D3Import, RevivalCore, RevivalEditor | Translate source representation needed by first outdoor slice; retain historical grouping meaning without inventing stream cells | seed |
| Descent3/terrainrender.cpp | Terrain visibility, LOD, sky and environment rendering | RevivalMetal | Translate observable terrain presentation before a measured cross-device simplification decision; replace renderer API calls with Metal | seed |
| Descent3/object.cpp | Placed object lifecycle, room ownership, roles and level dependency paging | D3Import, RevivalCore | Translate object values and current lifecycle; account for eager and reachable lazy dependencies in the canonical manifest | seed |
| Descent3/render.cpp | Room/portal traversal, face rendering, lightmaps, mirrors and special paths | RevivalMetal, RevivalCore | Translate visibility and the selected acceptance room's current material semantics; replace rend/OpenGL API; defer unused effects to their first scene | seed |
| renderer/HardwareOpenGL.cpp | Concrete blend, texture, fog and raster behavior | RevivalMetal | Evidence only for observable render states and reference images; no API or backend translation layer | seed |
| Descent3/gametexture.cpp | Texture animation, flags, UV sliding and definition use | D3Import, RevivalCore, RevivalMetal | Translate fields and current behavior reached by the room; defer unused families explicitly | seed |
| Descent3/lightmap_info.cpp | Lightmap-info handles, UV metadata, and sampling relationships | D3Import, RevivalMetal, RevivalEditor | Translate source-faithful imported metadata first; do not assign atlas packing to this file | seed |
| editor/editor_lighting.cpp | `SqueezeLightmaps`, padded 128-by-128 page packing, UV2 rewrite, and lighting tools | D3Import, RevivalEditor | Preserve imported page and UV2 meaning; record the global handle bound; defer native bake layout until measured | seed |
| bitmap/lightmap.cpp | Lightmap allocation and global handle guards | D3Import, RevivalMetal | Translate used allocation and format semantics; replace global tables with direct ownership | seed |
| lib/lightmap.h | `MAX_LIGHTMAPS` and lightmap data contracts | D3Import, RevivalMetal | Evidence and translated limits where the selected format requires them; do not call the page sequence unbounded | seed |
| bitmap/bitmain.cpp | Bitmap residency accessors and reachable lazy loading | D3Import, RevivalMetal | Import bitmap semantics and translate direct canonical preparation; exclude legacy global cache mechanics | seed |
| model/polymodel.cpp | Model paging and dependency expansion | D3Import, RevivalMetal | Account for model, texture, and animation dependencies reached by the complete level's current translated path | seed |
| Descent3/ObjInit.cpp | Object initialization and model paging | RevivalCore, RevivalMetal | Preserve reachable initialization order and canonical lazy resource request | seed |
| Descent3/matcen.cpp | Matcen production definitions and later model paging | D3Import, RevivalCore, RevivalMetal | Add produced-object dependencies when the matcen path is translated and preserve source timing of preparation | seed |
| Descent3/osiris_predefs.cpp | Behavior-driven object/model changes and paging calls | RevivalCore, RevivalMetal | Trace selected behavior calls and translate typed canonical resource requests; never load native modules | seed |
| manage/shippage.cpp | Ship definitions and dependencies reached by eager paging | D3Import, RevivalCore, RevivalMetal | Import selected ship fields and dependency meaning | seed |
| manage/weaponpage.cpp | Weapon definitions and model/effect/sound dependencies | D3Import, RevivalCore, RevivalMetal | Import only the first reached definitions, expanding in campaign order | seed |
| manage/doorpage.cpp | Door definitions and model/sound dependencies | D3Import, RevivalCore, RevivalMetal | Import selected door fields and dependency meaning | seed |
| manage/soundpage.cpp | Sound definitions reached by static and object dependencies | D3Import, RevivalCore | Import selected sound metadata; canonical media only at runtime | seed |
| sndlib/soundload.cpp | Sound-file loading and allocation behavior | D3Import | Format evidence for checked one-way decode; no runtime legacy loader | seed |
| Descent3/GameLoop.cpp | `GameFrame`, `CalcFrameTime`, `InitFrameTime`, `StopTime`, `StartTime`, `Min_allowed_frametime`, `Frametime`, `Gametime`, world update, rendering | RevivalCore, RevivalMac, RevivalMobile | Preserve old `Frametime`/`Gametime` consumption, post-cap new-delta storage and `Gametime` advance before tail work, static/`InitGame` 0.1-second initialization, and nested pause rebasing; feed Phase 3 one-scheduler decision and attach shell-specific lifecycle evidence without duplicating the scheduler | seed |
| editor/CMakeLists.txt | Evidence that editor compiles almost the complete runtime plus editor sources | Architecture evidence | Evidence only; preserve sharing through code ownership, not duplicated source or EDITOR conditionals | seed |
| editor/editor.cpp | Editor initialization and global editor state | RevivalEditor | Platform replacement with AppKit document/application ownership; translate required workflow state | seed |
| editor/MainFrm.cpp | MFC window commands, shared initialization entry, play-from-editor entry | RevivalEditor | Replace MFC UI; translate command outcomes and editor-to-game transition; exclude sleep/window teardown workarounds | seed |
| editor/editorDoc.cpp | Document open/save integration with production level I/O | RevivalEditor, RevivalCore | Replace with NSDocument while preserving canonical open/save and world ownership | seed |
| editor/HFile.cpp | Editor save/load delegation to production level functions | RevivalEditor, RevivalCore | Translate shared native project I/O; exclude D3L backward output | seed |
| editor/TextureGrWnd.cpp | Textured editor viewport through shared low-level world rendering | RevivalEditor, RevivalMetal | Translate render extraction and selection/view behavior; no editor-only renderer | seed |
| editor/gameeditor.cpp | `RunGameFromEditor`, game/editor state handoff, actual `MainLoop`, and return | RevivalEditor, RevivalCore, RevivalMetal | Translate play and return semantics in process; exclude temporary D3L bridge, mode globals, sleeps and platform reinitialization | seed |

## Closure requirements for the Phase 1 level island

The level and acceptance-room record closes before Training import production begins. The remaining trace can advance alongside the running dependency island, but before that island closes:

1. expand this seed from the complete Training Level call and data trace;
2. add relevant headers only when they carry product semantics not already captured by their implementation owner;
3. name exact functions or ranges for every mixed-disposition file;
4. identify the complete level's eager working set and the acceptance room's renderer dependencies;
5. attach a focused reference capture, fixture, or source checkpoint to each translated contract;
6. record the planned native file or type only after the first red test makes that ownership concrete.

Phase 1 closes only when every row reached by the complete-level load and acceptance-room result is `verified`, `replaced`, `excluded` with evidence, or deliberately `deferred` behind a named later behavior. `seed`, `translating`, and `native-running` are interim states.
