# Source translation ledger

- Status: Phase 0 seed
- Date: July 15, 2026
- Authority: execution record under [Source translation discipline](source-translation.md)

## Use

This ledger accounts for source ownership and disposition. It is separate from the functional-completeness ledger, which accounts for product capabilities.

Seed the likely source owners before a dependency island begins. Trace its real include, call, data, and editor paths while the island is working, and add every involved implementation file. Before it closes, replace provisional notes with exact relevant symbols, tests or captures, deliberate differences, native files, and final dispositions.

Allowed dispositions are translate, platform replacement, import only, superseded mechanism, evidence only, exclude, and deferred. A mixed legacy file may have more than one disposition with named ranges or symbols.

States are seed, traced, translating, native-running, verified, replaced, excluded, or deferred. `traced` requires exact relevant symbols, callers, ordering, and attached evidence; a high-level file summary remains `seed`.

Record only translation hazards actually present in the current island inside the existing role or contract text: observable evaluation order and side effects; build-mode, macro, or compile-variant behavior; numeric conversion, truncation, overflow, or sentinel handling; index and capacity assumptions; and ownership, aliasing, reentrancy, or teardown order. Do not add empty checklist fields or create a project-wide lifetime inventory. When review finds a repeatable source-to-Swift error, record the concrete rule and audit previously translated rows for the same pattern.

`translating` includes code that only builds, links, or reaches an entry point. `native-running` requires the row's observable contract to execute through the applicable real shipping or creator path with focused green evidence. `verified` is the terminal state for translate, import-only, and evidence-only work after its source or reference comparison, deliberate differences, and applicable island evidence close. `replaced` requires the named platform replacement or superseding native mechanism to satisfy the row's observable contract with the same applicable evidence; naming a replacement is not enough. `excluded` requires approved reachability or scope evidence. `deferred` requires a named roadmap phase or missing dependency and proof that the deferred behavior is not required by the current claimed result.

Named ranges in a mixed-disposition file may share one state only while every range has reached that state. Split the row when their states diverge. A stub, stand-in constant, disabled production branch, reduced placeholder limit, or skipped test protecting the current contract cannot advance a row. Any other nonexecuted test must be inapplicable under an approved terminal disposition with replacement or removal evidence; an explanation alone is insufficient.

## Phase 1 level and acceptance-room record

Complete this record before Training import production begins. Full-build source establishes the Training mission name and archive, and the owned local retail HOG2 table confirms the inner D3L filename. The project-owned canonical keys and acceptance-room fields remain unresolved. The acceptance room narrows visual and editor proof; it does not cut the imported `Level`.

| Field | Recorded decision |
| --- | --- |
| Mission and level key | Full-build `Descent3/menu.cpp` identifies `Pilot Training` and loads `training.mn3`. An ignored, owned local trace of that retail HOG2 table confirms `TrainingMission.d3l`, consistent with the OEM fallback in `Descent3/Mission.cpp`. The retail data and trace stay outside Git. Record project-owned canonical mission and `Level` keys before production import. |
| Complete-level evidence | Record D3L identity, room/portal/terrain/object/path/goal counts, and proof that no topology was trimmed |
| Acceptance-room identity | Not yet selected |
| Selection reason | Must exercise a useful portal boundary, real lightmap/material data, at least one placed object, and a manageable first dependency island |
| Connected portal neighbors | Record the room's actual connected edges used by traversal proof; all connected rooms remain in the complete Level |
| Dependency capture | Attach the full-level `PageInAllData` trace plus every lazy dependency reachable through the Phase 1 product path, including object initialization, with owned local evidence for textures, lightmaps, models, objects, effects, and sounds. Add later matcen, spawn, and behavior dependencies with the islands that make those paths executable. |

## Phase 1 complete-level and acceptance-room seed

| Legacy path | Historical role and dependency | Native owner | Provisional disposition and contract | State |
| --- | --- | --- | --- | --- |
| Descent3/descent.cpp | Game entry, global mode selection, main-loop and editor-game integration | RevivalMac, RevivalMobile, RevivalCore | Translate startup and game-loop order once; replace platform/window ownership through concrete AppKit and UIKit entry points; exclude global Function_mode and compile variants | seed |
| Descent3/init.cpp | Shared initialization entry points with editor-specific branches | RevivalCore, RevivalMac, RevivalMobile, RevivalEditor | Translate required initialization dependencies into explicit ownership; replace platform and legacy manager setup | seed |
| logger/log.cpp | Console and rolling-file logger initialization and severity routing | D3Import, RevivalMac, RevivalMobile, RevivalEditor | Platform replacement with direct OSLog categories and private fields; retain only bounded local evidence the real support workflow needs; exclude automatic upload and legacy logger machinery | seed |
| Descent3/gamesequence.cpp | `StartLevel`, `PageInAllData`, activation, `FreeThisLevel`, and cache flush | RevivalCore, RevivalMetal, RevivalMac, RevivalMobile | Translate the eager working-set walk, activation order, and single-owner release; trace rather than assume complete closure; supersede page/cache machinery | seed |
| Descent3/LoadLevel.cpp | D3L decode and encode, room/terrain/object/path/goal construction, editor-linked helpers | D3Import, RevivalCore, RevivalEditor | Import legacy decode semantics in D3Import; translate canonical relationships; replace legacy save with native project save; split accidental editor include dependency | seed |
| cfile/hogfile.cpp | HOG index and entry parsing | D3Import | Import only; checked Swift parser for used variants, no runtime archive reader | seed |
| cfile/cfile.cpp | File lookup, mounted-library precedence, case handling, reads | D3Import | Import naming and precedence semantics once; exclude runtime virtual filesystem and global library state | seed |
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
