---
name: revival-review
description: Run and consolidate independent source-fidelity, architecture, evidence-closure, and maintainability reviews for a Revival change, then hand the consolidated result to the completion gate. Use before closing a material dependency island or when a small change needs a scoped independent review.
---

# Revival review

Review the actual change against the pinned source, accepted product direction, executable evidence, and maintainability rules. Reviewer opinion does not override evidence, and agreement by vote does not make a finding true.

## Authority and scope

Read:

- [`AGENTS.md`](../../../AGENTS.md)
- [`docs/revival/source-translation.md`](../../../docs/revival/source-translation.md)
- [`docs/revival/source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md)
- [`docs/revival/engineering-principles.md`](../../../docs/revival/engineering-principles.md)
- [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md)
- [`docs/revival/verification.md`](../../../docs/revival/verification.md)
- [`docs/revival/skills-and-agents.md`](../../../docs/revival/skills-and-agents.md)
- [`docs/revival/current-plan.md`](../../../docs/revival/current-plan.md)
- the owning roadmap and domain documents

Resolve the exact base and review target. The target may be a commit, index, or uncommitted working tree; record its identity with the applicable commit, status, and diff rather than inventing a head revision. Gather the full changed-file contents, current observable contract, active plan packet and checkpoint, involved ledger rows, baseline, deliberate differences, and claimed evidence. Review reachable consequences outside the diff when the changed path calls or owns them.

Reviewers report findings and evidence. The island owner or root integrator changes the implementation and resolves findings.

## Material and small changes

A change is material when it affects production semantics, source disposition, canonical content, persistent data, ownership, resource lifetime, simulation order, target composition, player/editor identity, creator workflow, security, or an accepted product boundary. A wide behavior-neutral refactor is also material.

For a material slice, cover each concern below in a separate independent review context. Run them concurrently when capacity permits or in waves when it does not. The translator does not review their own work.

For a small local change, one independent reviewer may cover more than one concern when the report keeps all applicable concerns in separate labeled sections. Reviewer count is not a quality metric. Independence and complete concern coverage are.

Documentation-only changes apply the concerns that have a real document contract. They do not invent product tests or source obligations that the document does not claim.

## Concern 1: source fidelity

Give this reviewer the pinned source, native diff, relevant ledger rows, accepted documents, and baseline without the translator's rationale.

Check:

- the bounded fog-of-war preflight names the inspected boundary, records a disposition for each real discovery, and does not claim exhaustive knowledge from a clean result;
- every involved implementation file, important symbol, editor caller, generated block, and handwritten behavior range is accounted for;
- data flow, formulas, evaluation order, update order, dependency discovery, eager and lazy behavior, stable identity, and teardown remain source-supported;
- ownership and final GPU-use lifetime preserve observable results;
- the complete canonical `Level` and RevivalMac, RevivalMobile and RevivalEditor relationships are not reduced to a fixture or partial production model;
- every intentional difference is explicit and is not mislabeled as faithful transfer;
- any generated relationship evidence records its source, tool, configuration, normalized identity, and unresolved edge classes, and no generated edge is treated as proof of runtime behavior or semantic completeness;
- obsolete MFC, Win32, OpenGL, SDL, ABI, allocation, and defensive machinery was not preserved as semantics.

Literal C++ file shape and historical bugs are not fidelity requirements.

## Concern 2: architecture, scope, and one path

Give this reviewer the diff and the binding constitution, architecture, roadmap, loading, content, creator, and current domain decisions.

Check:

- shipping code remains direct Swift 6.4 in Swift 6 language mode and MSL on native Apple frameworks;
- D3Import alone understands supported legacy containers and formats;
- RevivalMac, RevivalMobile and RevivalEditor consume canonical content through shared world, renderer, and simulation types behind their concrete shells;
- the change leaves one loader, renderer, scheduler decision, behavior path, and resource-lifetime path;
- no compatibility bridge, runtime legacy reader, streaming flag, speculative framework, or alternate backend appeared;
- macOS-leading phase ordering may leave a separate mobile composition checkpoint open without silently deleting committed mobile capability, blocking the next independent Mac/shared island, or creating a temporary Mac-only shared path;
- human creator workflows remain first-class where the slice requires them;
- any binding product or cross-workstream change received the required amendment instead of entering through code.

Source evidence informs original semantics. It cannot reopen a product boundary that the accepted documents rejected.

## Concern 3: tests, evidence, and terminal closure

Give this reviewer the contract, red and green records, affected-suite result, applicable integration evidence, ledger state, and temporary-artifact disposition.

Check:

- new or changed behavior began with a focused test that failed for the intended project-owned reason;
- a behavior-neutral refactor had existing sensitive protection or the required controlled mutation;
- hostile and failure fixtures enter through the production-reachable boundary, remain otherwise valid, and assert the exact intended error rather than a convenient earlier failure;
- focused green, affected suite, build, launch, integration, image, device, security, and performance claims are not substituted for one another;
- exact commands, inputs, configurations, results, and exposed executed/failed/skipped counts are recorded;
- no protecting test is skipped, disabled, quarantined, deleted, weakened, or diverted through a test-only path;
- every checkpoint actually claimed by the change passes: Mac/shared evidence for a Mac/shared claim, physical iPhone and iPad evidence for a mobile composition claim, and both for overall milestone closure; unavailable support-floor hardware blocks only a public-beta or release-floor claim, which must remain open or raise the released floor;
- every involved source row has the state required to close the claimed island, and each functional row has evidence and the state appropriate to the current slice; a functional row must be terminal only when complete capability closure is claimed;
- the documentation-continuity handoff routes durable facts to their existing canonical owners, gives the integration owner an exact current-plan proposal or a justified no-change result, and creates no parallel plan or status diary;
- research code, scaffolding, generated local content, and temporary alternate paths are deleted or archived outside product targets.

Build success alone does not close an observable contract.

## Concern 4: simplicity and maintainability

Give this reviewer the native diff, current contract, relevant dispositions, and deliberate differences without the translator's design defense.

Check:

- validation occurs once at untrusted boundaries rather than through defensive internal branch forests;
- one concrete implementation was not wrapped in protocols, managers, services, providers, registries, factories, or dependency injection;
- flags, broad optionals, fallback modes, callbacks, and hidden state do not obscure one valid ownership model;
- direct structs, enums, functions, collections, and Apple APIs can replace indirection;
- duplicated paths, pass-through helpers, placeholder defaults, catch-and-ignore behavior, and workaround comments are absent;
- every retained recovery branch names a supported event and accepted outcome, and every `catch` performs required recovery or produces a user-visible diagnostic;
- the implementation honors its accepted commit point: supported precommit failure preserves the prior state, while postcommit cleanup is best effort and does not recursively attempt rollback;
- impossible states behind a trusted boundary terminate through ordinary Swift invariants, preconditions, or traps instead of speculative guards and recovery;
- test convenience did not add production seams;
- concurrency, caching, unsafe access, specialization, allocation machinery, or optimization has measured justification;
- a discovery aid did not become a hand-maintained knowledge graph, graph database, duplicate ledger, whole-program gate, or production dependency without accepted evidence;
- simplification preserves ledgered capability and source-supported observable behavior.

There is no line-count limit. A large file is a problem only when it causes a concrete ownership, comprehension, testing, or change-isolation failure.

## Finding contract

Every actionable finding states:

- priority: `P1` blocking, `P2` important, or `P3` non-blocking;
- concern;
- exact file and tight line range, or named missing ledger/evidence item;
- supported production entry point and practically plausible event, state, or caller;
- whether the event occurs before or after the accepted commit point, when one exists;
- violated source fact, accepted decision, observable contract, or maintenance consequence;
- the accepted user-visible, preservation, or termination outcome that is violated;
- the smallest credible correction or proof needed.

Do not report style preference, hypothetical future need, unsupported performance concern, literal source-shape mismatch, generic best practice, arbitrary failure, coverage in the abstract, or absence of a mathematical rollback guarantee as a defect. A recovery syscall failure is actionable only through its truthful propagated outcome unless an accepted supported event requires another layer of recovery.

## Deterministic consolidation

The root integrator consolidates reports as follows:

1. Normalize each finding by violated contract, path, and consequence.
2. Merge duplicates, retain every concern tag and the strongest concrete evidence, and use the highest supported priority.
3. Resolve conflicts by authority: accepted documents govern product scope and process; pinned source and baselines govern claimed original semantics; reproducible execution governs current behavior; unsupported inference loses.
4. Sort by priority, then repository path, first line, concern order, and title.
5. Give every finding one disposition: fixed; rejected with contrary evidence; accepted deliberate difference with recorded approval; or blocked on a named required decision.
6. Re-run the affected review concern and verification after fixes. Do not close on a prose promise.

No majority vote or averaged compromise decides a finding. If two reviewers disagree, inspect the evidence and choose the one direction the authority supports.

## Completion-gate handoff

`CLEAN` means the four ordinary review concerns have no actionable finding. It does not authorize an implementer to invent additional proof, and it does not make every broader evidence category a current blocker.

After corrections and deterministic consolidation, give one independent [`revival-completion-gate`](../revival-completion-gate/SKILL.md) reviewer:

- the actual base and target;
- the exact accepted current checkpoint;
- this consolidated report and dispositions;
- existing verification already applicable to the final tree;
- every proposed remaining correction, test, rerun, trace, profile, review, blocker, and deferred item.

The completion gate evaluates whether continuing work is proportional and applicable. It does not rerun these four concerns or commission another reviewer. The root integrator resolves only a concrete contrary fact or `CONTRACT CONFLICT`; do not recursively review the gate.

## Completion report

Return:

- reviewed base and target identity;
- one verdict for each applicable concern;
- the consolidated findings and dispositions;
- exact verification rerun after corrections;
- remaining uncertainty marked as unproven;
- proposed remaining actions in a form the completion gate can classify;
- `CLEAN` only when no actionable finding remains.

Run at minimum:

```sh
rtk git diff --check
```

## Method provenance

This skill is original project-specific prose implementing the accepted Revival review and closure rules. Structural-simplification prompts were informed by the audited MIT-licensed Thermos methods in `cursor/plugins` at commit `3fe2823ce17c1656c222d4b7c59d3f82fbf20143`. The four independent concerns and deterministic consolidation were informed by the MIT-licensed VGV Wingspan review process at commit `62b9eb07627f3f2bb9aba777e77ffe2a5729fd15`. No external agents, scripts, assets, or unlicensed text were imported.
