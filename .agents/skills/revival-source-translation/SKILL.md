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

Read the current domain document before touching its behavior, and use `current-plan.md` to select the active packet, owner, lane, and checkpoint inside the roadmap. Loading and residency work also requires [`world-loading.md`](../../../docs/revival/world-loading.md); import work requires [`content-pipeline.md`](../../../docs/revival/content-pipeline.md); editor work requires [`creator-suite.md`](../../../docs/revival/creator-suite.md); gameplay behavior requires [`behavior-system.md`](../../../docs/revival/behavior-system.md); music requires [`adaptive-music.md`](../../../docs/revival/adaptive-music.md).

If this skill conflicts with an accepted document, follow the document and report the conflict. Do not silently reinterpret it.

## Units of work and proof

- A legacy file is a source-accounting unit. Every relevant implementation file receives a disposition.
- A dependency island is the implementation and cutover unit. It contains the smallest complete source path that can produce a real result through the applicable Mac player, mobile player, or editor entry point.
- An observable contract is the verification unit. It states what the native product must do, not how the C++ happened to be arranged.
- A roadmap phase is a product milestone. File count, translated line count, compiler-error count, and target count are not product progress.
- A `current-plan.md` work packet is the near-term ownership and integration unit. It may close a Mac/shared checkpoint before its mobile composition checkpoint without closing the overall roadmap milestone.

Do not translate files alphabetically or require one Swift file per C++ file. Do not translate the whole repository before running the product. Complete one observable island at a time and leave one production path.

## Uncover the fog before fixing the island

At every new phase, milestone checkpoint, dependency island, subsystem, or material code group, perform the bounded [fog-of-war preflight](../../../docs/revival/source-translation.md#fog-of-war-preflight). Treat the selected packet and seeded ledger rows as a proposed boundary. Inspect enough pinned source, current native code, callers, state, ordering, ownership, lifetime, editor and runtime paths, fixtures, and evidence to validate or correct that boundary.

Record the inspected roots, newly exposed dependencies or unknowns, and any canonical plan or ledger correction. A clean pass is valid and does not imply that a defect should have existed. Stop when the next observable contract is safe to state. One direct question stays in ordinary tracing; several linked unknowns that block the contract hand off to [`revival-wayfinding`](../revival-wayfinding/SKILL.md).

A deterministic relationship view may direct this pass only under the provenance and uncertainty rules in the accepted document. Treat its compiler-derived edges, manually evidenced edges, and inferences as different categories. Never turn generated output into a second ledger, infer missing calls with a model, or require a whole-program graph before implementation.

## Prove a repeated mapping before parallelizing it

Before parallelizing a repeated source-to-Swift mapping, take a small representative case through the island loop and its real product checkpoint. If the source contains meaningfully different variants, include enough cases to expose those differences. Evidence determines the trial size; there is no file or reviewer quota.

Use the trial's failures to correct this skill, the island trace, or the shared mapping rule before assigning the wider work. A trial does not justify a partial production `Level`, a temporary compatibility backend, or a second loader or renderer.

## Trace the island

Before production implementation:

1. Name the next observable player or editor result, its `current-plan.md` packet and checkpoint, the refined preflight boundary and result, and every concrete shipping shell applicable to that checkpoint.
2. Trace the legacy entry point, callees, data flow, editor callers, important globals, ordering, dependency discovery, and teardown.
3. Add provisional ledger rows for every implementation file already known to participate.
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

Preserve source-supported data flow, formulas, update order, dependency discovery, lifetime, and observable results until evidence supports a deliberate change. Keep those semantics recognizable enough for side-by-side review.

Use native ownership immediately when the replacement is clear:

- Swift values instead of manual allocation and fixed-array accidents;
- one explicit mutable simulation owner instead of globals;
- direct Apple frameworks in the concrete AppKit or UIKit target instead of wrappers shaped like Win32, MFC, OpenGL, SDL, DirectX, or a generic platform, input, or filesystem layer;
- canonical package values instead of a runtime legacy archive or page manager;
- one editor document value and a separate disposable play-session value instead of global mode switching.

The UIKit player shell, mobile file-picker handoff, virtual controls, safe-area and orientation policy, audio-session behavior, and scene lifecycle are deliberate native platform contracts, not source-faithful translations of a missing legacy mobile implementation. Keep source-supported simulation, world, scheduler, input-snapshot, renderer, and canonical-package semantics on the same shared path as RevivalMac, and record mobile-only observable requirements in the functional ledger rather than inventing legacy source rows for them.

Defer behavioral redesign, not obvious removal of platform, ABI, allocation, and defensive baggage. Record every deliberate semantic difference. Never describe a redesign as a faithful transfer.

Work one focused red-green-refactor contract at a time. Compiler diagnostics may order the mechanical work inside the island, but a compiler error is resolved only by implementing the current contract or by recording an approved non-production disposition. Do not silence it with a stub or stand-in.

## Name the evidence claim; do not say “smoke test passed”

Follow [`revival-verification`](../revival-verification/SKILL.md) for evidence categories, falsification, nonexecuted tests, and milestone claims. Build, launch, focused behavior, integration, and performance checks answer different questions. Name the exact claim, command, input, configuration, and observed result; never substitute “smoke test passed.”

For source translation specifically, a baseline establishes historical behavior, not native correctness; build and entry-point execution do not close semantics; a fixture does not prove the owned Training path; and an optimized measurement covers only its recorded workload and device. Mobile performance or lifetime claims require applicable physical iPhone and iPad evidence as well as the Mac/shared M4 evidence where that path is also claimed. Exact support-floor certification belongs to public-beta or release evidence; its absence leaves that release claim open without blocking the next Mac/shared dependency island. No test protecting the claimed contract may be skipped, weakened, or diverted through a nonproduction path.

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

A source-specific finding must name observable drift, missing file or range accounting, a false deliberate-difference claim, or an obsolete mechanism mistaken for semantics. Literal C++ shape, personal style, and hypothetical future needs are not defects.

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
- optimization or scheduler changes without the accepted evidence gate;
- file-count or compiler-error burndown presented as product completion.

An assertion for a genuinely impossible trusted state is not a stub when canonical construction establishes the invariant and focused evidence protects it.

## Close the island

Use [`revival-verification`](../revival-verification/SKILL.md) to falsify the closure claim. Build or launch success leaves a source row `translating`; `native-running` requires its observable contract through the applicable real shipping or creator path. A row reaches `verified` only after its source comparison, deliberate differences, and applicable evidence close.

Source accounting for the island closes only when:

- every involved implementation file, important symbol, editor caller, generated block, and handwritten range has a final disposition;
- the source or reference comparison and every deliberate difference are recorded;
- temporary research and scaffolding are deleted or archived outside product targets;
- license and provenance are complete;
- every involved source row has the terminal state required by its disposition and current claim;
- one direct native production path remains.

For a player island shared by Mac and mobile, record the Mac/shared and mobile composition checkpoints separately. A Mac/shared packet may close and release the next Mac/shared dependency island after its applicable D3Import, RevivalMac, RevivalEditor, source, and evidence contracts pass, provided it leaves the one shared Core, Metal, package, scheduler, and lifetime path intact. RevivalMobile then composes that landed contract through its concrete shell and records mobile-only functional requirements separately from source-parity evidence. An open mobile checkpoint prevents mobile, overall-milestone, and version 1.0 closure; it does not retroactively invalidate the Mac/shared checkpoint. Simulator execution does not replace physical-device evidence required by a mobile claim.

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
