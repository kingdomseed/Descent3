# Current implementation plan

- Status: active
- Date: July 16, 2026
- Authority: living execution record under the accepted [roadmap](roadmap.md) and binding revival contracts

## Purpose and authority

This is the single place to find and update the revival's current implementation state, active integration slice, next work packets, lane-specific blockers, and near-term developer ownership.

The [roadmap](roadmap.md) remains the binding phase sequence and the accepted architecture, scope, content, source-translation, testing, and verification documents remain the product contracts. This file selects and orders the current work inside those boundaries; it cannot amend them. If this file and an accepted document disagree, stop at the conflict, reconcile the accepted documents through the required amendment, and then update this file. Do not create a second current-work plan, sprint document, or competing backlog under `docs/revival/`.

Every contributor reads this file before selecting work. The integration owner updates it in the same change that lands a completed work packet or changes the active sequence. Detailed source dispositions and proof stay in the source and functional ledgers, commit or pull-request record, and owning verification artifact; this file links or summarizes them without duplicating their full history.

At the start or resumption of a material packet and at its handoff or closure, apply the project-local [`revival-documentation-steward`](../../.agents/skills/revival-documentation-steward/SKILL.md) workflow. It restores execution context from this file and the actual tree, routes durable facts to their existing owners, and prepares an exact state-change proposal. It does not create another planning file, and it does not change the rule that only the integration owner edits live state here.

## Current state

| Field | State |
| --- | --- |
| Active roadmap phase | Phase 0 evidence work is still being reconciled; Phase 1 macOS/shared product entry begins as soon as the required product toolchain is selected. Remaining full-product inventory work continues alongside the first dependency islands and does not block unrelated Mac/shared implementation. |
| Active integration slice | Provisional Slice 0 — select the Swift 6.4/Xcode 27 toolchain and create the minimal native workspace and focused test entry point. The accepted outcome and toolchain gate are fixed; its exact scaffolding boundary is not locked until the preflight passes. |
| Active-packet preflight | Pending before Slice 0 production work. Its owner records the checked boundary and either the evidence-backed corrections or `no new gap found`; R0 is separate and cannot delay this gate. Until then, Slice 0 remains provisional. |
| Active two-developer wave | Wave 0 is planned but is not concurrently active. Before solo Slice 0 work starts, its owner must record themself as the interim integration owner. Concurrent work starts only after Developer A, Developer B, and the integration owner are named. |
| Developer A | Unassigned — planned owner of the HOG2 evidence, parser, and canonical-import lane after the shared workspace/test seam lands. |
| Developer B | Unassigned — planned owner of Slice 0, the application/Metal/creator lane, and shared Xcode project metadata through Wave 1. |
| Integration owner | Unassigned — name this owner before any product packet starts, including solo work. For a solo packet, its owner may serve as the recorded interim integration owner. This is the sole owner who reconciles landed state into this file. |
| Product code | No production Swift, MSL, package, Xcode workspace, or application target exists yet. |
| Source readiness | The complete Training identity, source-room-3 acceptance result, HOG2 layout checkpoint, eager dependency capture, and initial Phase 1 source rows are recorded in the [source-translation ledger](source-translation-ledger.md). |
| Prerequisite skill gate | `revival-constitution` and `revival-source-translation` were reconciled with the accepted documents on July 16, 2026. Each applicable domain skill is still reviewed against real translated source immediately before its first production change. |
| Current local toolchain | Xcode 27 beta 3 build `27A5218g` is installed side by side at `/Applications/Xcode-27-Beta-3.app` with Swift 6.4, macOS/iOS 27.0 SDKs, and the installed Metal Toolchain build `27A5218h`. The system `xcode-select` remains on Xcode 26.6 and Swift 6.3.3 so unrelated work is undisturbed; that older selection is not a product compatibility lane. |
| Product start blocker | Select the installed Xcode 27 beta 3 for the Slice 0 packet, then record Swift 6 language mode and the deployment environment. Toolchain and Metal compiler installation are complete; packet ownership and the bounded preflight remain open above. |
| Mobile development hardware | An iPhone 14 and an M2 iPad are available. Record their exact model, OS, drawable, and toolchain details when the mobile composition lane begins. They are development references, not automatic proof of the candidate Apple GPU family 7 release floor. |
| Mobile support-floor evidence | Apple GPU family 7 remains the candidate minimum feature floor. Lack of an exact representative floor device does not block product scaffolding, D3Import, shared Core/Metal, RevivalMac, RevivalEditor, later Mac dependency islands, or ordinary mobile development. Before public beta or release claims that floor, run the accepted representative floor-device matrix or raise the released floor to the oldest hardware actually verified. |
| Internet multiplayer study | May continue as bounded research in parallel. It blocks Phase 9 transport selection, not Phase 1 product work. |
| Relationship-map trial | Research packet R0 is ready to run in parallel with Slice 0. It is a non-blocking evaluation of deterministic compiler-derived source relationships for the HOG2 and Training-load island, not a commitment to a knowledge graph or a prerequisite for product code. |

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

### Provisional Slice 0 — toolchain and minimal workspace

Outcome: a reproducible Xcode 27/Swift 6.4 workspace can run the first focused red test and build the first direct native application shell without a compatibility lane.

The outcome and binding constraints are accepted. The exact scaffold, target, and test boundary remains provisional until the named owner completes the packet-entry preflight.

- select the installed Xcode 27 beta 3 for this packet without treating the existing system Xcode 26.6 selection as a product compatibility path;
- record `xcodebuild -version`, `swift --version`, SDKs, deployment targets, and Swift 6 language mode;
- create only the test and product scaffolding required by the first HOG2 and Mac-shell contracts;
- establish the named D3Import, RevivalMac, and RevivalEditor products plus explicit RevivalCore and RevivalMetal ownership areas; add the RevivalMobile target when its UIKit composition work begins, unless creating the empty universal target at workspace setup is strictly simpler and adds no placeholder product behavior;
- record the focused first test command and expected missing-contract failure.

Exit: the selected toolchain and minimal workspace are reproducible, the first test fails for the intended missing HOG2 contract, and no placeholder implementation or generic platform layer exists.

### Slice 1 — checked HOG2 import boundary

Outcome: production D3Import code reads the traced HOG2 header and index semantics through a checked one-way boundary.

- begin with the tracked `cfile/tests/TestDir/test.hog` fixture and the source contract recorded in `source-translation-ledger.md`;
- cover the tag, entry count, fixed index position, ordered payload offsets, name termination and folding, collision, integer accumulation, and extent failures required by the traced row;
- validate once before constructing trusted canonical archive entries;
- record red, green, affected-suite, provenance, and the terminal state earned by the `cfile/hogfile.{h,cpp}` row.

Exit: the first real importer contract is green and reviewable through production D3Import code; no player or editor reads HOG.

### Slice 2 — complete Training topology

Outcome: D3Import converts the complete Training mission level into one validated canonical resident `Level` value with the recorded rooms, portals, terrain, objects, paths, goals, identity, provenance, and current dependency manifest.

- add MN3/HOG selection and the D3L structures in source dependency order;
- keep visual acceptance focused on source room 3 without producing a partial level or room package;
- compare the owned local result with the recorded complete-level counts, identities, checksum, and source-room-3 relationships;
- keep presentation preparation out of simulation and retail-format knowledge out of Core, Metal, players, and editor.

Exit: the complete canonical Training topology validates and can be loaded through the shared world model without a renderer or editor-only alternate.

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

## Two-developer work map

Two developers should parallelize independent evidence-producing paths, not create competing implementations. One developer owns each shared contract until it lands; the other consumes that landed contract after rebasing. Each lane ends in a focused green, independently reviewable change with non-overlapping file ownership where practical.

| Wave | Developer A — import and canonical ownership | Developer B — applications, Metal, and creator ownership | Join point |
| --- | --- | --- | --- |
| 0 | Prepare the exact HOG2 test vector, manual source map, and expected missing-contract result without editing project metadata or claiming an executed red. Run non-blocking research packet R0 against the same bounded island if assigned. After Developer B lands the workspace/test seam, rebase and run the intended red. | Select the installed Xcode 27 beta 3 for the packet; own and land the minimal workspace, focused test target, concrete Mac/editor shells, and shared project metadata. | Developer B's workspace lands first. Developer A rebases, executes the intended HOG2 red through that real target, and records it; no production parser exists yet. R0 may finish before or after this join and cannot delay it. |
| 1 | Implement the checked HOG2 production parser and malformed-boundary cases; update the source row and import evidence. | Establish the direct Mac/editor MTKView plus MSL submission path with a tiny independently licensed or synthetic render fixture; do not invent canonical `Level` structure. | HOG2 is green and the direct Metal application path is real; review each contract separately before integration. |
| 2 | Own MN3/D3L translation and the smallest canonical `Level` types required by complete Training topology. Land shared type changes before consumers depend on them. | Continue the concrete renderer/application work that does not require unfinished canonical types; after Developer A lands the canonical schema, rebase and add controlled canonical-room extraction tests. | Complete Training topology loads through the one canonical model, and the renderer consumes that landed model without adapters. |
| 3 | Own dependency-manifest growth, eager-working-set evidence, import validation, and package provenance for the reached presentation path. | Own room-3 Metal output and the AppKit editor select/edit/undo/save/reopen/play-session loop. | Integrate the real imported package into RevivalMac and RevivalEditor; resolve source, ownership, and final-use findings together. |
| 4 | Advance the next Mac/shared connected-room import and canonical dependency island. | Compose the stable room slice into RevivalMobile and run the available-device development matrix recorded above. | Mobile catches the proven shared slice while Mac/shared work continues; neither lane forks Core, Metal, package, or lifetime behavior. |

### Parallelization boundaries

- Do not have both developers edit the same canonical types, package schema, source-ledger rows, or plan state concurrently. Name an owner and a merge order.
- Developer B owns shared Xcode workspace, project, target, scheme, and build-resource metadata through Waves 0 and 1. Before a dependent Developer A packet begins, Developer B lands its required metadata, Developer A rebases, and both treat that seam as frozen until the packet joins. Reassign this ownership only through an explicit update here.
- Do not divide early work into separate Mac and mobile engines. Share landed Core/Metal contracts and keep platform adaptations in the concrete shell that owns them.
- Do not parallelize a repeated source-to-Swift mapping until one representative case has completed the real product loop and exposed the mapping rule.
- Do not create speculative protocols or placeholder values so a consumer can start before the producer's real contract exists. The consumer can advance shell, renderer, fixture, or editor work that is genuinely independent.
- Keep each work packet small enough to review and merge independently. Rebase the dependent lane after the shared owner lands instead of maintaining a long-lived integration branch or compatibility adapter.
- Use one integration owner for cross-lane reconciliation, ledger transitions, review disposition, and this file's state update. The other developer includes the proposed state change in the handoff rather than editing the live plan concurrently.
- Run the four revival review concerns independently for each material join. A developer does not approve their own lane's closure.

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
