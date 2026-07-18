---
name: revival-verification
description: Falsify Descent 3 revival evidence claims and coordinate milestone or terminal-state acceptance. Use to audit what a result actually proves, ledger closure, and release evidence without inventing a generic test framework.
---

# Revival verification

Name the claim, try to disprove it with the cheapest relevant evidence, and report the exact rung that survives. This skill coordinates proof; it does not replace domain rules or author a test architecture.

## Authority and required reading

This skill implements accepted documents; it cannot amend them. Read [`AGENTS.md`](../../../AGENTS.md) and every global prerequisite it names, [`current-plan.md`](../../../docs/revival/current-plan.md), then the owning domain document, current ledger rows, and applicable project skill. The plan selects the active packet and checkpoint under those contracts; their acceptance rules define the claim, and this skill does not restate or weaken them.

Before first milestone use, compare this skill with the current evidence contract and amend it if stale.

## Evidence claims

Keep these claims distinct:

| Claim | Establishes |
| --- | --- |
| Source baseline | Historical ownership, order, reachability, dependency, or observable result |
| Focused red | The test detects the missing or incorrect contract for the intended reason |
| Build and link | The named target compiles and links in the recorded configuration |
| Entry-point execution | The executable reaches a named product boundary |
| Focused green | The named contract works through its production path |
| Affected suite | Directly affected contracts remain green |
| Integrated checkpoint | The named Mac/shared path or the Phase 8+ mobile, multiplayer, or release path composes |
| Optimized device measurement | The recorded representative workload meets or misses its stated budget on the named M4, iPhone, or iPad |
| Milestone matrix | The explicitly listed milestone scope passes |

These are evidence categories, not new ledger states or a mandatory sequence. A source baseline does not prove native correctness; a build does not prove launch; launch does not prove behavior; a focused test does not prove integration; and one device, workload, shell, simulator, or M4 run does not prove another.

## Falsification workflow

1. Restate one exact, observable claim and name its accepted contract, roadmap milestone, `current-plan.md` packet and checkpoint, functional rows, source rows, and production entry point.
2. Identify the cheapest evidence layer that could disprove it: source trace, focused fixture, local retail capture, controlled image, editor round trip, application composition, optimized M4 or physical mobile-device profile, or milestone matrix.
3. For new or changed production behavior, inspect the recorded focused red command and salient intended failure. A broken environment, fixture error, or unrelated failure is not red evidence.
4. Re-run or inspect the exact focused green and directly affected suite through the production path. Record input, configuration, result, and executed/failed/skipped counts when exposed.
5. Exercise composition only where ownership, serialization, concrete AppKit or UIKit adaptation, process, GPU, application, physical-device lifecycle, or milestone behavior can fail independently. Do not add a generic platform, input, or filesystem abstraction to make a matrix easier to run.
6. Compare source-supported behavior and native behavior. Record tolerances and every deliberate difference instead of blending modernization into a fidelity claim.
7. Audit skipped, disabled, quarantined, deleted, weakened, and replaced cases. A test protecting the claimed current contract must execute and pass.
8. Check source and functional ledger transitions against the exact scope being claimed; do not advance a row on prose or build success alone.
9. For a material slice, require the completed [`revival-review`](../revival-review/SKILL.md) report and confirm every concrete finding changed the diff or received evidence-backed resolution.
10. Issue a bounded evidence verdict: supported at a named evidence rung, or unsupported with the concrete missing or contradictory evidence. For material closure, pass that result to [`revival-completion-gate`](../revival-completion-gate/SKILL.md) rather than deciding that every unexecuted broader evidence category blocks the packet.

Documentation-only work uses link, consistency, and evidence checks. It does not manufacture a red product test. Performance changes start from a reproducible optimized measurement that misses an accepted budget or demonstrates a regression. Through Phase 7, RevivalMobile target builds and focused simulator or unsigned generic-device checks are compatibility evidence only; unavailable hardware, signing, or development-team setup cannot return `HOLD` or block the next Mac/shared packet. Beginning with Phase 8, claims that cover mobile presentation, input, package intake, lifecycle, memory, thermal, or audio behavior require applicable physical iPhone and iPad evidence; simulator evidence alone cannot close them. Representative support-floor evidence is required for a public-beta or release-floor claim, and missing floor hardware leaves only that claim open.

## Proportional evidence authorization

Before requesting a nontrivial terminal trace, profile, repeated lifecycle campaign, soak, additional full-suite rerun, or evidence-only `HOLD`, invoke the completion gate once on the consolidated review and current claim. Name the hypothesis, supported production path, content and configuration, bounded duration or cycle count, comparison or threshold, and product or implementation decision the result can change.

Do not authorize evidence merely because it appears in a broad verification catalog. A selected-room baseline does not require complete-mission budgets; a Mac/shared checkpoint does not require mobile or release-floor certification; a bounded lifecycle exercise does not prove indefinite absence of growth. Existing evidence remains applicable when a later change cannot affect its path.

## Ledger discipline

For source rows, `translating` includes build, link, and entry-point evidence. `native-running` requires focused green through the applicable real shipping or creator path. Island closure requires `verified`, `replaced`, `excluded`, or a justified current-claim `deferred` state as defined by the source ledger.

Functional rows may remain intermediate when the current milestone does not claim complete capability. When a row is claimed complete, every applicable runtime, authoring, validation, playtest, and publishing path must work; an inapplicable path needs a recorded reason.

Record the Phase 1–7 Mac/shared result and early mobile compatibility evidence without inventing a second closure checkpoint. A supported Mac/shared verdict releases the next Mac/shared packet while accumulated physical mobile integration remains owned by Phase 8, provided one mobile-composable production path remains. Do not translate an early target build or simulator result into physical mobile, milestone, or version 1.0 completion.

An explanation alone never turns a skip, stub, placeholder, or named replacement into proof. Do not create a new verification state machine, duplicate either ledger, or require fields irrelevant to the claim.

## Verification record

Keep the result compact and auditable:

- **Claim and authority:** observable scope, owning document, rows, and milestone.
- **Evidence rung:** the exact category being established.
- **Execution:** command or procedure, input or content identity, configuration, environment, concrete target shell, and physical device when applicable.
- **Observed result:** values, images, counts, diagnostics, timings, or failure state that bear on the claim.
- **Nonexecuted cases:** every relevant skip, disablement, deletion, weakening, replacement, and approved disposition.
- **Differences and provenance:** source comparison, tolerances, intentional changes, hashes, and rights boundary.
- **Review and ledger state:** independent findings, resolution, and exact row transitions.
- **Verdict:** supported scope and limits, or the next concrete evidence needed.

This is a reporting shape, not a schema or new required artifact when an existing ledger, commit body, or pull request can hold the same evidence.

## Prohibited verification theatre

Reject:

- “smoke test passed,” “looks good,” a version banner, or a green build used as a broader claim;
- generic coverage targets, one test per C++ function, speculative matrices, or duplicated assertions at every layer;
- a test framework, mock architecture, protocol, wrapper, alternate path, public setter, or debug mode created only for verification;
- source parity CI, retail data in Git, automatic image-baseline regeneration, or permanent dependence on the reference executable;
- preserving obsolete APIs, defensive branches, literal file shape, or historical bugs in the name of fidelity;
- deleting ledgered capability in the name of maintainability;
- invented performance budgets, unrecorded environments, or optimization conclusions from debug builds;
- unlimited negative proof, repeated passing commands, recursive review, or profiling without a predeclared decision;
- domain checklists copied into this skill instead of following the owning accepted document.

## Milestone or terminal closure

Accept a claimed island or milestone only when:

- the exact claim and evidence rung are stated, with reproducible commands or procedures and observed results;
- focused red-first history exists for every new or changed production behavior and required current tests execute and pass;
- source comparisons, deliberate differences, provenance, and evidence applicable to the exact Phase 1–7 Mac/shared, early mobile target/build, Phase 8+ mobile, or overall milestone claim are recorded;
- source rows satisfy the island's closure rule; functional rows carry the evidence and state supported by the current slice and satisfy their terminal rule when complete capability or milestone closure is claimed, with no unexplained file, range, capability path, or nonexecuted case;
- temporary research and scaffolding are removed or archived outside product targets;
- independent fidelity, architecture, evidence, and simplicity findings are resolved;
- one independent completion-gate verdict classifies every proposed remainder and provides the bounded stop condition;
- the verdict names what remains unproven and never expands beyond the executed evidence.

Run the exact commands required by the owning domain and milestone. At minimum:

```sh
rtk git diff --check
```

If evidence is missing, stop the affected closure claim and name the missing proof. Do not turn evidence missing from one lane into a global block, and do not invent a test, abstraction, or alternate path merely to fill a matrix cell.
