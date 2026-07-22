---
name: revival-source-translation
description: Trace, translate, account for, and close a Descent 3 C++ source dependency island in native Swift or MSL. Use for baseline capture, file and symbol disposition, compiler-error repair, direct semantic transfer, deliberate modernization, and source-led island accounting.
---

# Revival source translation

Translate the pinned Descent 3 source into one direct Apple-native product path shared by the concrete Mac, iPhone, iPad, and editor shells without losing observable behavior or carrying obsolete machinery into Swift.

## Authority and required reading

This skill implements the repository's accepted rules. It cannot amend them. Read these files before changing production code:

- [`AGENTS.md`](../../../AGENTS.md)
- [`docs/revival/source-translation.md`](../../../docs/revival/source-translation.md)
- [`docs/revival/source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md)
- [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md)
- [`docs/revival/engineering-principles.md`](../../../docs/revival/engineering-principles.md)
- [`docs/revival/roadmap.md`](../../../docs/revival/roadmap.md)
- [`docs/revival/current-plan.md`](../../../docs/revival/current-plan.md)
- [`docs/revival/verification.md`](../../../docs/revival/verification.md)
- [`docs/revival/skills-and-agents.md`](../../../docs/revival/skills-and-agents.md)
- [`docs/revival/primary-source-index.md`](../../../docs/revival/primary-source-index.md) and every exact maintained-source delta already mapped to the current island

Read the current domain document before touching its behavior, and use `current-plan.md` to select the active packet, owner, lane, and checkpoint inside the roadmap. Loading and residency work also requires [`world-loading.md`](../../../docs/revival/world-loading.md); import work requires [`content-pipeline.md`](../../../docs/revival/content-pipeline.md); editor work requires [`creator-suite.md`](../../../docs/revival/creator-suite.md); gameplay behavior requires [`behavior-system.md`](../../../docs/revival/behavior-system.md); music requires [`adaptive-music.md`](../../../docs/revival/adaptive-music.md).

If this skill conflicts with an accepted document, follow the document and report the conflict. Do not silently reinterpret it.

## Units of work and proof

- A legacy file is a source-accounting unit. Every relevant implementation file receives a disposition.
- A dependency island is the implementation and cutover unit. It contains the smallest complete source path that can produce a real result through the applicable Mac player, mobile player, or editor entry point.
- An observable contract is the verification unit. It states what the native product must do, not how the C++ happened to be arranged.
- A roadmap phase is a product milestone. File count, translated line count, compiler-error count, and target count are not product progress.
- A `current-plan.md` work packet is the near-term ownership and integration unit. Through Phase 7, it closes on its applicable Mac/shared contract; early mobile build and simulator composition is compatibility evidence rather than a second closure checkpoint. Phase 8 owns required physical mobile integration.

Do not translate files alphabetically or require one Swift file per C++ file. Do not translate the whole repository before running the product. Complete one observable island at a time and leave one production path.

## Uncover the fog before fixing the island

At every new phase, milestone checkpoint, dependency island, subsystem, or material code group, perform the bounded [fog-of-war preflight](../../../docs/revival/source-translation.md#fog-of-war-preflight). Treat the selected packet and seeded ledger rows as a proposed boundary. Inspect enough pinned source, current native code, callers, state, ordering, ownership, lifetime, editor and runtime paths, fixtures, and evidence to validate or correct that boundary.

Record the inspected roots, newly exposed dependencies or unknowns, and any canonical plan or ledger correction. A clean pass is valid and does not imply that a defect should have existed. Stop when the next observable contract is safe to state. One direct question stays in ordinary tracing; several linked unknowns that block the contract hand off to [`revival-wayfinding`](../revival-wayfinding/SKILL.md).

A deterministic relationship view may direct this pass only under the provenance and uncertainty rules in the accepted document. Treat its compiler-derived edges, manually evidenced edges, and inferences as different categories. Never turn generated output into a second ledger, infer missing calls with a model, or require a whole-program graph before implementation.

## Use maintained descendants as work already investigated

When an R1 or later pinned PiccuEngine or DESCENT 3MASTERED change intersects the current roots or dependencies, inspect its exact before/after diff before writing the native implementation. The useful unit is not the descendant's C++ shape; it is the investigation embodied by the change.

For each mapped delta, determine:

1. what defect, limitation, ambiguity, or improvement prompted it;
2. what observable result, invariant, ordering, formula, dependency, ownership, or lifetime changed;
3. what focused input or regression case distinguishes the corrected result;
4. how to express that result directly with Swift values, canonical content, MSL, or the concrete Apple framework owner; and
5. whether the exact revision is a stable correction, restored behavior, quality-of-life change, deliberate-modernization candidate, or experiment.

Implement a clear reached defect correction or restored intended result directly; do not intentionally reproduce the known bad behavior and schedule a later cleanup. Route a deliberate product change through its existing owner and evidence gate. If the delta is inapplicable, state the concrete reason and provenance. A platform-only carrier may still contain a transferable semantic result or test, so rejecting Win32, OpenGL, OpenAL, SDL, legacy Osiris, ABI, cache, or compatibility machinery is the final mechanism decision—not a substitute for understanding the change.

## Prove a repeated mapping before parallelizing it

Before parallelizing a repeated source-to-Swift mapping, take a small representative case through the island loop and its real product checkpoint. If the source contains meaningfully different variants, include enough cases to expose those differences. Evidence determines the trial size; there is no file or reviewer quota.

Use the trial's failures to correct this skill, the island trace, or the shared mapping rule before assigning the wider work. A trial does not justify a partial production `Level`, a temporary compatibility backend, or a second loader or renderer.

## Trace the island

Before production implementation:

1. Name the next observable player or editor result, its `current-plan.md` packet and checkpoint, pinned released-source revision, mapped maintained-source revisions, runtime and editor entry symbols, applicable build variants, refined preflight boundary, native owners, and every concrete shipping shell applicable to that checkpoint.
2. Build a sorted bounded source census: trace forward through definitions, calls, data flow, important globals, ordering, dependency discovery, initialization, teardown, and editor consumers; search backward across the pinned tree for callers and registrations of the island entry symbols and state or types the island defines, mutates, or owns; and inspect callbacks, virtual dispatch, function pointers, macros, generated blocks, and handwritten behavior when actually present. Classify and stop at an outside caller that cannot reach the named contract instead of recursively reverse-tracing every shared helper.
3. Continue until every discovered semantic dependency and outward edge is included, evidenced as irrelevant, excluded, or deferred to a named roadmap phase and missing dependency. Add or split ledger rows for every census file and relevant symbol or range; do not treat the original row list as proof that discovery is complete. Persist one compact census block in the source ledger with the revision, claim, roots, variants, native owners, sorted row anchors, deferred outward edges, and later independent-review result.
4. Capture the historical baseline with source evidence, a synthetic fixture, the reference executable, or owned local retail content.
5. Record the difficult native ownership boundary. Do not design a project-wide lifetime framework.
6. Identify only the semantic hazards present in this island.
7. Write the focused failing production test once the contract is known, then record the red command and intended failure.

Deepen the trace as real code exposes additional dependencies. Iterative discovery is expected. An incomplete trace is never completion.

### Semantic hazards

Look for concrete hazards rather than filling out an empty checklist:

- evaluation order, side effects, callbacks, and reentrancy;
- debug versus release behavior, macros, compile variants, and assertions with side effects;
- integer conversion, truncation, overflow, signedness, Float32 operation order, and sentinels;
- eager versus lazy evaluation or dependency discovery;
- stable indices, fixed capacities, malformed tails, and out-of-range behavior;
- ownership, aliasing, destruction order, file lifetime, and final GPU use;
- iteration order where the result is observable.

Record the hazard and its evidence in the existing ledger text. Do not create a global lifetime inventory or speculative semantic framework.

## Translate directly

Preserve source-supported data flow, formulas, update order, dependency discovery, lifetime, and observable results until evidence supports a deliberate change. When a pinned maintained delta supplies a clear correction for a reached path, the corrected semantics are the source-supported target; keep the released and corrected forms recognizable enough for side-by-side review without implementing the known defect first.

Use native ownership immediately when the replacement is clear:

- Swift values instead of manual allocation and fixed-array accidents;
- one explicit mutable simulation owner instead of globals;
- direct Apple frameworks in the concrete AppKit or UIKit target instead of wrappers shaped like Win32, MFC, OpenGL, SDL, DirectX, or a generic platform, input, or filesystem layer;
- canonical package values instead of a runtime legacy archive or page manager;
- one editor document value and a separate disposable play-session value instead of global mode switching.

The UIKit player shell, mobile file-picker handoff, touch gameplay, safe-area and orientation policy, audio-session behavior, and scene lifecycle are deliberate native platform contracts, not source-faithful translations of a missing legacy mobile implementation. UIKit remains the default lifecycle and UI toolkit; use a bounded SwiftUI component only for a recorded current advantage and keep it inside the same UIKit lifecycle, navigation, state, and game-view path. Preserve source-supported simulation, world, scheduler, input-snapshot, renderer, and canonical-package semantics on the same shared path as RevivalMac, and record mobile-only observable requirements in the functional ledger rather than inventing legacy source rows for them.

Defer behavioral redesign, not obvious removal of platform, ABI, allocation, and defensive baggage. Record every deliberate semantic difference. Never describe a redesign as a faithful transfer.

Work one focused red-green-refactor contract at a time. Compiler diagnostics may order the mechanical work inside the island, but a compiler error is resolved only by implementing the current contract or by recording an approved non-production disposition. Do not silence it with a stub or stand-in.

## Name the evidence claim; do not say “smoke test passed”

Follow [`revival-verification`](../revival-verification/SKILL.md) for evidence categories, falsification, nonexecuted tests, and milestone claims. Build, launch, focused behavior, integration, and performance checks answer different questions. Name the exact claim, command, input, configuration, and observed result; never substitute “smoke test passed.”

For source translation specifically, a baseline establishes historical behavior, not native correctness; build and entry-point execution do not close semantics; a fixture does not prove the owned Training path; and an optimized measurement covers only its recorded workload and device. Through Phase 7, early mobile target, generic-device, and simulator checks prove only their compatibility wiring; unavailable devices, signing, or development-team setup cannot block the island. Beginning with Phase 8, mobile performance or lifetime claims require applicable physical iPhone and iPad evidence as well as Mac/shared M4 evidence where that path is also claimed. Exact support-floor certification belongs to public-beta or release evidence. No test protecting the claimed contract may be skipped, weakened, or diverted through a nonproduction path.

## Treat workaround comments as a stop signal

A paragraph-long comment arguing that a workaround is acceptable is a blocking review signal, not a character-count violation.

This adapts [Bun's rejection of comments that rationalized compilation workarounds](https://bun.com/blog/bun-in-rust#compiler-errors-as-a-work-queue); it is not a general ban on detailed comments.

When a comment has to defend unusual code:

1. Recheck the source path and observable contract.
2. Ask whether direct types, ownership, control flow, or a smaller function can express the invariant.
3. Remove placeholders, duplicated paths, and speculative defensive handling.
4. If the unusual code remains necessary, state the invariant and its evidence in the shortest clear comment.

Long comments are legitimate when they preserve source or license provenance, a deliberate semantic difference, non-obvious ordering or arithmetic, or a real safety invariant around `unsafe`, `Unmanaged`, Metal final use, callbacks, or asynchronous framework behavior. When the claim is testable, point to the protecting test, capture, or measurement.

A comment cannot legitimize a stub, placeholder constant, broad optional state, parallel fallback, avoidable unsafe access, duplicated defensive path, speculative abstraction, or temporary production mechanism without a deletion gate. Correct comments explain why correct code must look unusual. Suspicious comments explain why tangled or incomplete code is supposedly acceptable.

## Independent review

Use [`revival-review`](../revival-review/SKILL.md) before closing a material island. The translator supplies the pinned source, native diff, accepted documents, ledger rows, baseline, deliberate differences, and claimed evidence but does not review their own work. The four review concerns and deterministic consolidation live in that skill, not here.

After that review is consolidated, use [`revival-completion-gate`](../revival-completion-gate/SKILL.md) once before holding or closing the island, collecting more terminal evidence, or authorizing expensive profiling. The gate cannot waive source accounting or observable fidelity. It prevents a translation packet from expanding into later-milestone proof, unsupported failure engineering, repeated verification, or an unlimited negative after its current checkpoint is satisfied.

A source-specific finding must name observable drift, missing file or range accounting, a mapped maintained-source correction whose useful semantics were not extracted, a false deliberate-difference claim, or an obsolete mechanism mistaken for semantics. Literal C++ shape, personal style, and hypothetical future needs are not defects.

## Repair the process when the pattern is wrong

When review or testing exposes a repeatable source-to-Swift defect:

1. state the concrete mistaken pattern and correct mapping;
2. update this skill or the narrow owning rule;
3. search every previously translated site that may contain the same mistake;
4. write a focused regression test and observe the intended failure before repair; for already-correct behavior under refactor, use the controlled-mutation sensitivity check required by the TDD document;
5. repair all confirmed occurrences before closing the island.

Do not turn an isolated error into a global rule. The process itself must remain smaller than the failure it prevents.

## Prohibited shortcuts

Reject:

- empty bodies, default-value returns, catch-and-ignore paths, placeholder switches, reduced stand-in limits, and `fatalError("TODO")` used to make a target compile;
- tests skipped, deleted, weakened, or feature-gated merely to reach green;
- permanent C++ bridges, legacy runtime readers, alternate loaders, alternate renderers, or compatibility feature flags;
- a generic cross-platform, platform-service, input, or filesystem abstraction between the concrete AppKit and UIKit shells and their shared native paths;
- speculative protocols, managers, services, ECSs, job systems, render graphs, resource managers, custom allocators, or broad package graphs;
- defensive checks inside trusted runtime code for states canonical construction already excludes;
- preservation of MFC, Win32, OpenGL, SDL, native Osiris, ABI, packet, binary-layout, or editor/game handoff machinery;
- dismissal of a mapped maintained-source change solely because its carrier uses one of those obsolete mechanisms, without first extracting any corrected behavior, invariant, dependency, lifetime lesson, or regression case;
- optimization or scheduler changes without the accepted evidence gate;
- file-count or compiler-error burndown presented as product completion.

An assertion for a genuinely impossible trusted state is not a stub when canonical construction establishes the invariant and focused evidence protects it.

## Close the island

Use [`revival-verification`](../revival-verification/SKILL.md) to falsify the closure claim. Build or launch success leaves a source row `translating`; `native-running` requires its observable contract through the applicable real shipping or creator path. A row reaches `verified` only after its source comparison, deliberate differences, and applicable evidence close.

Source accounting for the island closes only when:

- the bounded source census has reached a classified fixed point from its declared runtime and editor roots, and an independent source-fidelity reviewer has reconstructed it rather than merely reading the implementer's row list;
- every census implementation file, important symbol, editor caller, generated block, handwritten range, and outward edge has a final disposition or a named justified deferral;
- the source or reference comparison and every deliberate difference are recorded;
- temporary research and scaffolding are deleted or archived outside product targets;
- license and provenance are complete;
- every current-census range is `verified`, `replaced`, or `excluded`, while any separately split `deferred` range names its roadmap phase and missing dependency and is not required by the current observable contract;
- every relevant native-owner empty body, placeholder return or switch, disabled production branch, catch-and-ignore path, reduced stand-in limit, `fatalError("TODO")`, or equivalent compilation-stub hit is classified as implemented, a source-evidenced no-op, excluded, deferred, or an unresolved placeholder; no unresolved placeholder remains for the claimed contract;
- one direct native production path remains.

Stop at that bounded island claim. Do not require a whole-repository graph, folder-completion percentage, generic TODO purge, one test per function, or unlimited negative proof. Phase 10 performs the whole-project terminal ledger check.

For a player island shared by Mac and mobile, close its Phase 1–7 packet after the applicable D3Import, RevivalMac, RevivalEditor, source, and evidence contracts pass, provided it leaves one mobile-composable Core, Metal, package, scheduler, input, and lifetime path. RevivalMobile may compile or compose that landed contract early through its concrete UIKit shell, but this is compatibility evidence rather than a separate closure checkpoint. Unavailable devices, signing, or development-team setup cannot block the packet or next Mac/shared island. Phase 8 then exercises the accumulated mobile-only functional requirements on physical devices; simulator execution does not replace evidence required by that Phase 8+ claim.

The verification skill owns red/green, affected-suite, Mac/mobile/editor composition, nonexecuted-test, review-resolution evidence, and milestone closure; `revival-review` owns the review itself. At minimum, every documentation or production change also runs:

```sh
rtk git diff --check
```

Use direct `rtk swift test` and `rtk xcodebuild` commands once their real targets and schemes exist. Record the exact invocation; do not invent a generic scheme or hide the result behind an automation summary.

## Method sources

The pinned Descent 3 source and accepted revival documents remain the authority. These external sources inform the operating method only:

- Jarred Sumner, [“Rewriting Bun in Rust”](https://bun.com/blog/bun-in-rust), especially the preparation, representative trial, compiler-error queue, evidence progression, adversarial review, workflow correction, and post-port regression sections.
- Bun's reviewed [`PORTING.md`](https://github.com/oven-sh/bun/blob/3157cb14b5970b69532a47800504a28ef5963e22/docs/PORTING.md), [`LIFETIMES.tsv`](https://github.com/oven-sh/bun/blob/eeb4d9fdf6e9a7bdd45388d7f3a03dcf570839ad/docs/LIFETIMES.tsv), and [verified-claims record](https://github.com/oven-sh/bun/blob/eeb4d9fdf6e9a7bdd45388d7f3a03dcf570839ad/docs/.rust-rewrite-verified-claims.md), as examples of source-cited mapping and structured review evidence rather than an authoritative knowledge graph.
- Bun commit [`46d3bc29f270fa881dd5730ef1549e88407701a5`](https://github.com/oven-sh/bun/commit/46d3bc29f270fa881dd5730ef1549e88407701a5), containing the concrete Phase-A porting guide and batch-selection script.
- Bun PR [#30224](https://github.com/oven-sh/bun/pull/30224), useful evidence for separating source reorganization from behavior changes and for treating proposed module boundaries as hypotheses.

Do not copy Bun's whole-repository batch size, agent count, platform matrix, noncompiling Phase-A draft, `TODO(port)` placeholders, unsafe allowance, or performance conclusions. The documented Bun method did not use a knowledge graph as its control mechanism. This project changes the platform, renderer, editor, and content boundary and therefore requires observable dependency islands rather than a whole-program draft.
