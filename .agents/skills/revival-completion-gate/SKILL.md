---
name: revival-completion-gate
description: Decide whether a Revival work packet is genuinely blocked, needs one bounded correction, or is already complete. Use after consolidated review and before READY, HOLD, further terminal evidence, expensive profiling, repeated verification, or handoff; also use whenever remaining work may be ceremonial, speculative, unreachable, unbounded, or owned by a later checkpoint.
---

# Revival completion gate

Act as the independent senior engineer whose burden of proof is on continuing work. Prevent speculative defensive code, redundant tests, recursive review, and open-ended evidence collection from delaying a satisfied checkpoint.

This is one bounded read-only decision after ordinary review consolidation. It replaces a separate terminal-evidence applicability review; it is not a fifth concern review, another implementation lane, or permission to launch more reviewers.

## Authority

Read:

- [`AGENTS.md`](../../../AGENTS.md);
- [`docs/revival/current-plan.md`](../../../docs/revival/current-plan.md);
- the current checkpoint in [`docs/revival/roadmap.md`](../../../docs/revival/roadmap.md) and its owning accepted contract;
- [`docs/revival/engineering-principles.md`](../../../docs/revival/engineering-principles.md);
- [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md);
- [`docs/revival/verification.md`](../../../docs/revival/verification.md);
- the consolidated [`revival-review`](../revival-review/SKILL.md) result, actual diff, and existing evidence.

Accepted contracts govern. A prompt or `current-plan.md` entry cannot silently enlarge them. Do not waive an explicit current-checkpoint contract, source-supported observable behavior, security boundary, required creator/player path, or concrete reachable P1/P2 defect. If an accepted contract itself requires contradictory, unsupported, or unlimited proof, return `CONTRACT CONFLICT`. The integration owner routes that conflict to the document's owning authority; only the user may approve an amendment where the accepted protocol requires user approval. Do not send the implementer into an endless investigation while that decision is open.

Resolve timing and applicability by specificity. The named roadmap checkpoint and the current evidence state of its functional or source row control when a general complete-product capability or verification catalog does not explicitly assign that evidence to the current slice. Language such as `as surfaces arrive`, `where applicable`, or a list of eventual evidence categories does not make every category an immediate gate. Preserve the broader obligation in its named later checkpoint. If two equally specific accepted requirements genuinely disagree, return `CONTRACT CONFLICT`; do not choose the larger workload by default.

## Central question

Ask of every proposed guard, catch, rollback path, abstraction, test, trace, profile, rerun, review, blocker, or remaining action:

> What real shipping event requires this now, and what useful product action or decision occurs because it exists?

Continuing work is justified only when all applicable facts can be named:

1. the accepted current-checkpoint sentence requiring it;
2. the supported production entry point reaching it;
3. a practically plausible event during supported use;
4. the observable fidelity, ownership, recovery, security, performance, creator, or player outcome it protects;
5. the distinct defect or regression it can detect;
6. why existing evidence does not already answer it;
7. the smallest bounded correction or pass/fail check and its stopping condition;
8. the implementation or product decision that changes when it passes or fails.

`Technically possible`, `defensive`, `coverage`, `best practice`, `arbitrary machine failure`, `we cannot prove it never happens`, and `more evidence would be reassuring` do not satisfy this burden.

## Classify remaining work

Place every proposed remaining item in exactly one class:

- `REQUIRED NOW`: the current checkpoint is not satisfied and a concrete reachable blocker remains.
- `DEFER`: legitimate work owned by a named later checkpoint or broader claim.
- `DELETE / REJECT`: speculative, redundant, unreachable, ceremonial, incapable of changing a decision, or already answered by existing evidence.

Do not turn a `DEFER` item into an active backlog in another file. Route durable later scope only to its existing accepted owner.

## Apply proportional engineering judgment

### Code and error handling

- Retain validation where untrusted retail data, native packages, projects, saves, network input, user input, or fallible OS/framework results become trusted.
- Reject a validation test that merely narrows source-supported values or manufactures danger that the production algorithm already handles.
- Inside trusted canonical code, reject duplicate guards, recovery forests, manufactured error cases, and tests for impossible state. Use concrete types, preconditions, or ordinary traps for programming errors.
- Retain a `catch` only when it performs required recovery or adds actionable user-facing context.
- Reject callbacks, protocols, flags, mocks, sabotage hooks, alternate paths, or rollback layers created solely to manufacture a failure.

### Tests and repeated verification

- Require a test only when it protects a reachable boundary, reproduced defect, declared invariant, or distinct observable contract.
- Reuse valid existing evidence when the later change cannot affect that path.
- After a substantive correction, require the narrow affected check, the smallest final-tree suite or integration check that can falsify regression, and one independent recheck limited to the affected ordinary review concern. Do not rerun the other concerns or the completion gate.
- Do not repeat a passing command, rerun an unchanged build matrix after prose-only edits, or demand independent reviewers recursively.

### Memory and performance

- Require profiling when a ratified budget is missed, an observed regression or growth signal exists, or the current checkpoint explicitly requires a baseline.
- Before authorizing a trace, name the hypothesis, content, build, duration or cycle count, threshold or comparison, and decision that the result will change.
- Allow a small representative lifecycle exercise for new ownership or resource-lifetime code. It can expose crashes, stale state, failure to release, or monotonic growth; it cannot prove `no growth forever`.
- Reject unlimited negative proof, enormous traces without a decision, repeated profiling after a clean bounded result, and complete-mission, soak, floor-device, or release-certification evidence at an earlier selected-room or Mac/shared checkpoint.

### Scope and uncertainty

- An unproven item blocks only the claim to which it actually applies.
- Apply general complete-product, accessibility, performance, mobile, soak, and release evidence only when the specific current checkpoint or row makes that evidence current. Do not infer timing merely because the eventual capability now has an early scaffold.
- Missing mobile evidence does not block the next independent Mac/shared island; missing release-floor evidence does not block ordinary development.
- Uncertainty alone is not a blocker. Use bounded fog-of-war discovery for the next island and `revival-wayfinding` only for several linked unknowns that prevent a concrete contract.
- Continued work can be riskier and less valuable than landing a satisfied slice. Account for that cost explicitly.

## Decide once

Return one verdict:

- `STOP - READY`: the checkpoint is satisfied, required evidence exists, and no reachable P1/P2 defect remains.
- `FIX THEN READY`: every `REQUIRED NOW` item has a known smallest correction within the authorized packet; list those corrections, the exact final-tree affected-concern recheck and verification, and the condition after which the implementer must stop without running the gate again.
- `HOLD - REAL BLOCKER`: the current checkpoint has a concrete reachable defect, required evidence gap, external dependency, or missing authority that cannot be resolved by a known bounded correction inside the authorized packet. Name the exact blocker and the next evidence, authority, or packet needed.
- `CONTRACT CONFLICT`: identify the contradictory, unsupported, or unlimited accepted requirement that the integration owner must route to its owning authority or, when required, the user.

Never return `HOLD` for generalized risk, arbitrary failure, later-phase work, an unlimited negative, reviewer discomfort, or missing evidence that cannot change the current product decision.

## Output contract

Return exactly these sections:

```text
VERDICT: STOP - READY | FIX THEN READY | HOLD - REAL BLOCKER | CONTRACT CONFLICT

CHECKPOINT SATISFIED
- Observable outcomes already proven.

REQUIRED NOW
- For each real blocker: accepted current requirement, production entry point, plausible event, violated outcome, smallest correction, and bounded verification.
- Write `None` when none exist.

STOP / DELETE
- Code, tests, reviews, measurements, or evidence requests to remove or abandon, with the reason.

DEFER
- Legitimate later work and its named owning checkpoint.

STOP INSTRUCTION
- The exact condition after which work must cease and the tree must be handed back.
```

Do not edit the tree, update `current-plan.md`, implement a correction, commission another review, or collect the missing evidence. The implementer and integration owner act on the verdict. Apply [`revival-documentation-steward`](../revival-documentation-steward/SKILL.md) afterward to route the accepted result without creating an evidence diary.

## Method provenance

This is original project-specific prose derived from Revival's accepted boundary, testing, verification, and review rules and from the observed Slice 3 failure in which later-milestone profiling, unlimited negative proof, and unsupported failure events became self-created terminal blockers. It imports no external text, scripts, hooks, or automated stop mechanism.
