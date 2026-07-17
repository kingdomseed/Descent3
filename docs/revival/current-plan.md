# Current implementation plan

- Status: active
- Date: July 17, 2026
- Authority: living execution record under the accepted [roadmap](roadmap.md) and binding revival contracts

## Purpose and authority

This is the single place to find and update the revival's current implementation state, active integration slice, next work packets, lane-specific blockers, and near-term developer ownership.

The [roadmap](roadmap.md) remains the binding phase sequence and the accepted architecture, scope, content, source-translation, testing, and verification documents remain the product contracts. This file selects and orders the current work inside those boundaries; it cannot amend them. If this file and an accepted document disagree, stop at the conflict, reconcile the accepted documents through the required amendment, and then update this file. Do not create a second current-work plan, sprint document, or competing backlog under `docs/revival/`.

Every contributor reads this file before selecting work. The integration owner updates it in the same change that lands a completed work packet or changes the active sequence. Detailed source dispositions and proof stay in the source and functional ledgers, commit or pull-request record, and owning verification artifact; this file links or summarizes them without duplicating their full history.

At the start or resumption of a material packet and at its handoff or closure, apply the project-local [`revival-documentation-steward`](../../.agents/skills/revival-documentation-steward/SKILL.md) workflow. It restores execution context from this file and the actual tree, routes durable facts to their existing owners, and prepares an exact state-change proposal. It does not create another planning file, and it does not change the rule that only the integration owner edits live state here.

## Current state

| Field | State |
| --- | --- |
| Active roadmap phase | Phase 1 macOS/shared product entry is active after the reviewed Slice 2 landing. Remaining Phase 0 inventory work continues independently and does not block the next Mac/shared packet. |
| Active integration slice | Slice 2 — complete Training topology — is the latest landed baseline after additional HOLD remediation, full verification, owned-content proof, final independent re-review, and user-authorized landing. No implementation slice is active; Slice 3 is next and remains inactive until its packet-entry preflight and explicit kickoff. |
| Active-packet preflight | The bounded remediation preflight traced and closed all eight accepted findings across promotion cancellation/report failure, dormant F-001 ownership, source identity ceilings, canonical JSON allocation claims, production/test fixture ownership, exact hostile-boundary assertions, terminal loader/source ranges, and unused validation seams. Re-review then exposed same-destination writer interleaving, incomplete reachable precommit-restoration/final-commit coverage, source-accounting omissions in post-load proxy ownership and reached writer helpers, broad wrong-reason hostile assertions, and retention of every prepared archive's bytes through the import. A final simplification audit removed repeated trusted-state validation, the exact-Training recoverable-error forest, redundant serialized object slots, impossible signal errors, internal decoder defenses, C++-width overflow branches, duplicate canonical resource validation, contrived rollback tests, broad or redundant error assertions, and about 413 MB (394 MiB) of non-Training archive retention. The additional review then found the practical unrelated-destination collision, missing player-ID trust constraint, insensitive package-loader proof, omitted successor-reset range, and stale executable skills; each has a concrete correction and current verification below. No several-linked-unknown wayfinding block emerged. |
| Active implementation lanes | No implementation lane is active. Slice 2's focused red-green corrections, loader-path sensitivity proof, source and skill reconciliation, full verification, consumer builds, owned-content proof, and bounded re-review are landed. Slice 3 remains inactive until its packet-entry preflight and explicit kickoff. |
| Packet owner | `Codex task 019f6bb6-e5dd-75b3-9cee-278cd978ac2b` owned the Slice 2 implementation, corrections, verification, and reviewed handoff. `Codex task 019f66e3-9777-7a82-83c4-ca01c025a4e8` performed the final merge-gate review and user-authorized landing. |
| Integration owner | Slice 2 integration and ledger reconciliation are complete. No Slice 3 integration owner is assigned until that packet begins. |
| Product code | The landed Slice 2 workspace contains the helper CLI, mission and D3LV-127 readers, typed complete `Level`, canonical package loader/writer, and a same-directory, directory-locked publication sequence. Before touching the report, promotion requires an existing destination to pass the shared canonical loader; an unrelated occupant is rejected and preserved. It prepares and promotes the report, restores the prior report on supported precommit cancellation or package-rename failure, and makes the package rename the final commit. Only best-effort replaced-artifact cleanup remains afterward, and cleanup failure can warn but cannot turn publication into failure. Shared validation rejects malformed handles, serialized object types, stored identifiers, out-of-range or duplicate player IDs, resource/category indices, and external-room object placement once at the D3L or canonical-package boundary; trusted code does not repeat those checks. Canonical source resources validate once through the dependency manifest and exact closure. HOG and D3LV extents use widened Swift `Int` arithmetic plus direct data bounds rather than reproduced C++ fixed-width overflow states. Object slot identity is derived from the handle rather than serialized twice. Each non-Training prepared archive's bytes are released after its inventory is recorded; only `training.mn3` remains resident for mission and level decode. Production test sentinels, the unused validation wrapper, exact-Training runtime assertions, and contrived arbitrary-failure recovery branches are removed. Shared source ownership and the one-way retail boundary remain unchanged; no renderer, editor document loop, mobile target, behavior runtime, navigation runtime, or presentation payload was added during remediation. |
| Source readiness | Slice 2 source accounting is landed. The ledger records the `OBJ_PLAYER` `0..<32` unique/sparse-ID constraint, its runtime/editor callers, owned Training IDs 0 and 2, and the `LoadLevel.cpp:3731–3783` successor-reset disposition. Prior terminal-range, writer-helper, and JSON-boundary accounting remains intact. |
| Prerequisite skill gate | READY. `d3-content-import`, `revival-review`, and `revival-simplify` now encode the accepted report-first/package-final commit contract and require a supported event, practical plausibility, and an accepted violated outcome before failure or recovery logic is retained or reported. `revival-constitution` and `revival-source-translation` remain reconciled. |
| Current local toolchain | Slice 0 commands select `/Applications/Xcode-27-Beta-3.app/Contents/Developer` per invocation through `DEVELOPER_DIR`; the global `/Applications/Xcode.app/Contents/Developer` selection remains unchanged. Verified July 17, 2026: Xcode 27.0 build `27A5218g`, Swift 6.4 (`swiftlang-6.4.0.25.4`), Metal `32023.918`, macOS 27.0 SDK, iOS 27.0 device and simulator SDKs, and arm64 macOS 26.5.2 build `25F84`. Product settings use Swift 6 language mode (`SWIFT_VERSION = 6.0`) and macOS 26.0 deployment; there is no Xcode 26 or Swift 6.3 compatibility lane. |
| Product start blocker | No known Slice 2 technical or review blocker remains. Slice 3 is the next accepted packet and remains inactive until its own entry preflight and kickoff. Independent Mac/shared work outside this dependency island remains governed by its own gate; no broader roadmap block is claimed. |
| Slice 0 packet evidence | The focused Debug test command with the Xcode 27 `DEVELOPER_DIR`, macOS SDK, arm64 destination, and `CODE_SIGNING_ALLOWED=NO` copied the tracked fixture, then exited 65 at `Cannot find 'parseHOG2' in scope`; compilation cancelled testing with 0 tests executed. Separate D3Import, RevivalMac, and RevivalEditor Debug and Release builds all exited 0; effective settings report macOS 27.0 SDK, macOS 26.0 deployment, arm64, `SWIFT_VERSION = 6.0`, and complete strict concurrency. The three Release products are arm64 Mach-O executables; both app plists record minimum system version 26.0. No GUI or legacy application was launched. |
| Slice 1 packet evidence | The exact initial command exited 65 at the intended missing `parseHOG2(_:)` compile contract. Thirteen subsequent malformed contracts were each observed red before their production branch and then green. The final focused command executed 17 tests with 0 failures. D3Import, RevivalMac, and RevivalEditor each build and link in Debug and Release with isolated `/tmp` DerivedData; Release binaries are arm64 with macOS 26.0 minimum and macOS 27.0 SDK load commands. Release D3Import with no arguments prints only its usage contract and exits 64. The Slice 0+1 landing commit owns the exact red, green, suite, and build transcript; the source ledger retains only durable source-accounting facts and evidence level. No GUI, legacy application, retail import, generated package, or network path ran. |
| Slice 2 packet evidence | The final Xcode 27 Debug and Release suites each execute 86 retained tests with 0 failures and 0 skips; the refreshed focused HOG, D3LV, and canonical-boundary run executes 67 with 0 failures and 0 skips. The additional destination red reproduced deletion of the tracked `test.hog` occupant and report mutation before one destination-ownership check made it green. The player-ID red failed at the two missing exact validation cases, and the controlled loader mutation made the complete-provenance hostile test fail before restoration made it green. Earlier focused reds proved the missing hostile-identity contracts, external-room object rejection, same-destination writer race, and package-final commit ordering. Focused greens cover actual blocked-signal cancellation, replacement and first-install cancellation before final package commit, report-promotion failure before package commit, package-promotion failure with prior-report restoration, the final package commit point, serialized two-writer publication, unrelated-destination preservation, player-ID range/uniqueness, and semantic validation through the package loader. D3Import, RevivalMac, and RevivalEditor build in both configurations with signing disabled; all three Release products are arm64, use macOS 26.0 minimum and the macOS 27.0 SDK. Two fresh owned Release imports and a same-destination replacement are byte-identical: `content.json` SHA-256 `3bda83a12d6a0161698e85c0d3eeb624ce0215aebceb8cf2781efc9ece3f5784`, `level.json` `6e01df10c3b2eaf24ce8f3f85e8974f1a7d363af5ce50b48517fca77d103a4e5`, and report `094a7d86b8aae712316738cd984643fca68aa9c67bdd6f30474323a06df675a3`. The complete level has 48 sparse rooms, 4,558 room vertices, 3,485 faces, 14,112 face vertices, 112 directed portals, 40 objects with player IDs 0 and 2, 65,536 terrain cells, 2 paths, 1 goal, 3 triggers, 20 lightmap pages, and 2,531 lightmap infos; `LIFE` is evidence-only F-001. The real Release CLI collision exits 65 with `invalidPackageDirectory`; the tracked fixture, unrelated destination, and prior report retain SHA-256 `2b620319af6013e477f0f32630ac665cd4bcf13d786eebe5883c694c23c63edc`, and the fully written staging package remains intact. A preexisting staging candidate still exits 65, preserves its sentinel hash, and creates no package or report. No GUI, legacy application, network path, or tracked retail/generated artifact ran. |
| Independent review | Final promotion/simplicity, hostile package-loader/player-ID test-value, and source/document reviews are READY. They confirmed the practical destination-ownership check, exact canonical errors and loader sensitivity, complete source ranges, current evidence, and anti-contrivance skill rules. Requests based only on arbitrary failure, a mathematical rollback guarantee, or coverage in the abstract remain rejected. |
| Integration blocker | None. Slice 2 is landed, and no new integration packet is active. |
| Next packets | Slice 3 is the first direct Metal Mac/editor selected-room result and native document loop; Slice 4 is the first mobile composition. Neither is active, and each begins with its own bounded preflight. |
| Mobile development hardware | An iPhone 14 and an M2 iPad are available. Record their exact model, OS, drawable, and toolchain details when the mobile composition lane begins. They are development references, not automatic proof of the candidate Apple GPU family 7 release floor. |
| Mobile support-floor evidence | Apple GPU family 7 remains the candidate minimum feature floor. Lack of an exact representative floor device does not block product scaffolding, D3Import, shared Core/Metal, RevivalMac, RevivalEditor, later Mac dependency islands, or ordinary mobile development. Before public beta or release claims that floor, run the accepted representative floor-device matrix or raise the released floor to the oldest hardware actually verified. |
| Internet multiplayer study | May continue as bounded research in parallel. It blocks Phase 9 transport selection, not Phase 1 product work. |
| Relationship-map trial | Research packet R0 remains optional and non-blocking. It may be assigned beside a later nonconflicting implementation or review packet; it is not part of combined Slice 0+1 closure, a commitment to a knowledge graph, or a prerequisite for product code. |

## Sequencing rule

macOS is the leading implementation lane. D3Import, the shared canonical/Core and Metal paths, RevivalMac, and RevivalEditor establish each source-led product slice first. RevivalMobile then composes the proven shared slice through its concrete UIKit, storage, input, audio-session, and lifecycle boundaries. This is implementation order, not reduced scope: RevivalMobile remains required for version 1.0 and uses the same canonical world, renderer, scheduler, package, save, replay, and applicable multiplayer paths.

Roadmap phases are dependency groupings, not global barriers for every developer. Each material slice has separate applicable checkpoints:

1. **Mac/shared checkpoint:** the current source contract works through D3Import or the canonical boundary, shared Core/Metal where applicable, RevivalMac, and RevivalEditor where the slice has a creator path.
2. **Mobile composition checkpoint:** the same accepted shared contract is composed through RevivalMobile, with the mobile-only lifecycle, input, presentation, audio, storage, and package evidence applicable to that slice.
3. **Overall milestone checkpoint:** every required Mac/shared, editor, mobile, source-accounting, and functional result for the roadmap milestone is complete.

An open mobile checkpoint does not block the next Mac/shared dependency island. It does block any claim that the shared slice is complete on mobile, that the overall roadmap milestone is closed, or that version 1.0 is ready. A Mac/shared lane may not introduce a temporary Mac-only Core, renderer, package schema, scheduler, or resource-lifetime path while mobile composition catches up.

## Work-packet entry gate

Every new phase, milestone checkpoint, dependency island, subsystem, or material code group begins with the bounded [fog-of-war preflight](source-translation.md#fog-of-war-preflight). The packet owner challenges the proposed boundary against accepted contracts, pinned source, real callers, ledgers, current code, and observable evidence before locking the packet. This does not assert that the plan is wrong. A recorded `no new gap found` result is sufficient when the named evidence was checked.

Confirmed gaps update their canonical document, ledger row, packet, or verification need. A single answerable edge stays in ordinary tracing. Only several linked unknowns that prevent a concrete contract invoke `revival-wayfinding`. The preflight has a named stopping condition and may not become an indefinite phase before implementation.

## Near-term slices

The outcomes and binding constraints below are accepted. Each exact packet boundary remains provisional until its named owner completes the entry preflight; discovery may refine dependencies and sequence without silently changing the accepted product contract.

### Slice 0 — toolchain and minimal workspace

Outcome: a reproducible Xcode 27/Swift 6.4 workspace can run the first focused red test and build the first direct native application shell without a compatibility lane.

The owner completed the packet-entry preflight. The fixed boundary is one shared workspace and project; D3Import, RevivalMac, RevivalEditor, and `D3ImportTests` targets; concrete AppKit shells; direct RevivalCore and RevivalMetal source-ownership groups; no RevivalMobile target; and no production HOG2 parser in this packet.

- select the installed Xcode 27 beta 3 for this packet without treating the existing system Xcode 26.6 selection as a product compatibility path;
- record `xcodebuild -version`, `swift --version`, SDKs, deployment targets, and Swift 6 language mode;
- create only the test and product scaffolding required by the first HOG2 and Mac-shell contracts;
- establish the named D3Import, RevivalMac, and RevivalEditor products plus explicit RevivalCore and RevivalMetal ownership areas; add the RevivalMobile target when its UIKit composition work begins, unless creating the empty universal target at workspace setup is strictly simpler and adds no placeholder product behavior;
- record the focused first test command and expected missing-contract failure.

Exit: the selected toolchain and minimal workspace are reproducible, the first test fails for the intended missing HOG2 contract, and no placeholder implementation or generic platform layer exists.

### Slice 1 — checked HOG2 import boundary

Outcome: production D3Import code reads the traced HOG2 header and index semantics through a checked one-way boundary.

- begin with the tracked `cfile/tests/TestDir/test.hog` fixture and the source contract recorded in `source-translation-ledger.md`;
- cover the tag, entry count, fixed index position, ordered payload offsets, name termination and folding, collision, widened offset arithmetic, and file-extent failures required by the traced row;
- validate once before constructing trusted canonical archive entries;
- record red, green, affected-suite, provenance, and only the source-row state supported by the actual shipping-path evidence; direct parser unit tests do not automatically earn `verified`.

Exit: the first real parser contract is green and reviewable in production D3Import code; no player or editor reads HOG, and the source row remains nonterminal if the fail-closed helper entry point has not yet exercised it.

Implementation result: the landed Slice 1 parser and 17-test boundary suite satisfied this exit while its source row remained `translating`. Landed Slice 2 exercises that same parser through the shipping helper across all six exact Training-scope prepared archives and advances the bounded HOG2 capability to `verified`.

### Slice 2 — complete Training topology

Outcome: D3Import converts the complete Training mission level into one validated canonical resident `Level` value with the recorded rooms, portals, terrain, objects, paths, goals, identity, provenance, and current dependency manifest.

- add MN3/HOG selection and the D3L structures in source dependency order;
- keep visual acceptance focused on source room 3 without producing a partial level or room package;
- compare the owned local result with the recorded complete-level counts, identities, checksum, and source-room-3 relationships;
- keep presentation preparation out of simulation and retail-format knowledge out of Core, Metal, players, and editor.

Exit: the complete canonical Training topology validates and can be loaded through the shared world model without a renderer or editor-only alternate.

Implementation result: the landed Slice 2 packet satisfies this exit. D3Import fingerprints the six accepted archives from the same byte snapshots, then treats any parse failure of those exact known hashes as a programming defect rather than a recoverable user error. It selects the Training descriptor's sole `MINE`, decodes and validates the complete D3LV-127 level, writes and reloads the binding canonical-package subset, and publishes through the report-first/package-final sequence recorded above. The D3L boundary rejects nonfinite serialized floats, source ceilings, malformed topology, and unresolved source identities before constructing canonical content. The native JSON reader bounds file size before `JSONDecoder`; Foundation rejects nonfinite JSON numbers, and exact canonical validation then enforces reciprocal and combined portals, object/handle/resource identity, spatial assignment, lightmap relationships, trigger flags, dependency closure, provenance, rights, hashes, paths, regular files, and package layout. Owned deterministic, replacement, reachable precommit restoration, final-commit, concurrency, and failure evidence is recorded in the current-state table above; rendering and editor-document behavior remain Slice 3.

### Slice 3 — first Mac and editor result

Outcome: source room 3 from the complete Training `Level` renders through one direct Metal path in RevivalMac and RevivalEditor, and the editor completes its first meaningful document loop.

- compile MSL and submit the smallest direct Metal 4 forward path through the concrete AppKit/MetalKit shells;
- translate the room/portal visibility and lightmapped face dependencies required by the acceptance room;
- derive an editable complete-level project value from the read-only canonical base;
- select and perform the smallest source-informed real edit with named undo and redo;
- save, close, reopen, create a disposable play-session copy, render through the shipping path, and return to useful document state;
- prove final-GPU-use release and the pre-commit/post-commit replacement failure contract.

Exit: the first imported room is visible in RevivalMac and RevivalEditor, the editor round trip works, and both use the same separately owned canonical values and Metal implementation.

### Slice 4 — first mobile composition

Outcome: RevivalMobile composes the already working canonical load and direct Metal room path without introducing another game implementation.

- add the universal UIKit player target if Slice 0 did not create it;
- render the same acceptance room through RevivalMetal;
- prove supported landscape, safe-area, and drawable changes;
- receive the Mac-produced canonical package through the system picker, copy it into app-owned staging, and use the shared native-package validation and activation path;
- map the initial UIKit lifecycle into the shared pause, unload, release, and recovery ownership rules;
- run physical-device development checks on the available iPhone and iPad recorded in the current-state table after recording their exact environment.

Exit: the initial mobile composition checkpoint passes on available development hardware. Candidate minimum-floor certification remains a later public-beta/release gate and does not retroactively block the completed Mac/shared slices.

### Research packet R0 — deterministic relationship-map trial

Outcome: decide whether a machine-derived relationship view materially improves source discovery or review for the HOG2 and complete Training-load island.

- reproduce the ignored CMake `builds/mac/compile_commands.json` input, then pin the released source revision, extractor version, compilation configuration, and exact command;
- normalize stable symbol and relationship records into sorted, hashable output, using compiler identities where available;
- normalize machine-specific roots without removing semantic source locations, then require two equivalent clean runs to produce byte-identical output;
- report indexed and unindexed translation units and build configurations, including editor or platform variants absent from the Mac compilation database;
- compare file/include, declaration/definition/reference, statically resolved call, and proven global-access edges with the existing manual trace and ledger;
- label absent translation units or build variants and unresolved macro, generated, function-pointer, virtual-dispatch, registration, aliasing, ownership, and lifetime edges as unknown rather than inferring them;
- record actionable unique findings, false or unresolved edges, reproducibility, run time, artifact size, and maintenance cost;
- evaluate existing compiler-index inputs first. Any third-party executable must pass the skill-supply-chain pin, license, and audit rules before it runs.

Exit: accept one small derived evidence artifact only if the trial finds useful missed relationships or measurably improves review at acceptable cost; otherwise record the rejection. Either outcome closes R0. It does not block Slice 0, HOG2 production work, or any later dependency island, and it creates no graph database, hand-maintained knowledge graph, native architecture rule, or product dependency.

### Following work

After the Mac/shared Slice 3 checkpoint, begin the connected-room dependency island without waiting for unavailable floor hardware. After Slice 4, keep RevivalMobile close to proven shared contracts while Mac/shared and editor work continue through connected rooms, flight, collision, and the later campaign-first roadmap. Update this file to name only the next two or three concrete slices once the first integration result changes what is known.

## One-or-two-developer capacity and integration ownership

`Codex task 019f6ad9-5966-7f43-98f6-f5b8965a8f9d` owned the Slice 0 scaffold, Slice 1 parser work, shared Xcode workspace/project/target/scheme/resource metadata, affected documentation, and internal review through handoff. `Codex task 019f66e3-9777-7a82-83c4-ca01c025a4e8` performed the final merge-gate review, resolved the documentation findings, reran verification, and landed the combined packet under explicit user authorization. `Codex task 019f6bb6-e5dd-75b3-9cee-278cd978ac2b` owned the Slice 2 implementation, independent-review corrections, verification, ledger closure, and reviewed handoff; `Codex task 019f66e3-9777-7a82-83c4-ca01c025a4e8` performed its final merge-gate review and user-authorized landing. No Slice 3 implementation or consumer lane is active.

The project plans for one or two implementation developers, not for a permanent pair. One developer follows the dependency order below without creating placeholder work for an absent second lane. A second developer is assigned only when the current preflight exposes a useful packet with non-overlapping write ownership; capacity alone does not justify speculative protocols, fixtures, adapters, or parallel implementations. Read-only source tracing and independent review may still run concurrently.

| Execution point | Required primary lane | Optional second lane when staffed and independent | Join boundary |
| --- | --- | --- | --- |
| Combined Slice 0+1 landing | The recorded integration owner lands the workspace, parser, ledgers, and shared project metadata as one packet | None; review remains read-only | One reviewed commit and remote branch state |
| Slice 2 landing — complete | The recorded integration owner landed the reviewed complete-level, package, test, and ledger packet together | None; the handoff and landing were serial | One user-authorized landing keeps code, package schema, source accounting, and functional states together |
| Slice 3 — next after kickoff | D3Import extends only the presentation payloads and dependencies reached by selected-room rendering | RevivalMetal, RevivalMac, and RevivalEditor consume the landed types for room-3 rendering and the document loop | One complete imported `Level` and package contract feeds the single Mac/editor path; no adapter or alternate schema survives |
| After the Mac/shared Slice 3 checkpoint | The next Mac/shared connected-room dependency island advances in source order | Slice 4 composes the already accepted Core, Metal, package, and lifetime path through RevivalMobile | Mobile joins only on landed shared contracts while Mac/shared work may continue independently |

Only the integration owner edits this live plan. Shared Xcode metadata, canonical types, package schema, source-ledger rows, and functional-ledger rows each have one writer at a time and a named merge order. If only one developer is available, that developer executes the same table sequentially. If the optional lane stops being independent, it waits rather than forcing concurrency.

## Updating this file

The documentation steward supplies the evidence-backed reconciliation described below at material packet entry, resumption, handoff, or closure. `No documentation change required` is valid when the active state remains accurate. The integration owner alone updates this file whenever a work packet lands or a verified result changes the next sequence:

1. update the date and the `Current state` table;
2. record the bounded fog-of-war preflight outcome for a new packet and any resulting boundary, dependency, owner, blocker, or sequence correction; keep detailed inspected paths and evidence in the owning ledger or change record, and accept `no new gap found` when applicable;
3. mark the active integration slice and name the next two or three concrete slices;
4. record lane ownership and only real blockers, labeled `Mac/shared`, `Mobile`, `Release`, or `Research` so one lane's missing evidence is not mistaken for a global stop;
5. move detailed completed evidence into the owning ledger and change record rather than growing a permanent diary here;
6. remove or rewrite stale next-step prose in active documents and skills in the same change;
7. run document-link, consistency, and `git diff --check` verification;
8. obtain independent review for any change to product scope, phase gates, cross-lane ownership, or production protocol.

When no work is active, this file still names the next accepted slice and its true prerequisite. It must never say merely “continue Phase 1.”
