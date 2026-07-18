---
name: revival-documentation-steward
description: Keep Revival's accepted documents, ledgers, and current implementation plan coherent without creating a parallel plan. Use at material packet entry or resumption, when a fog-of-war preflight or verified result changes durable scope, state, ownership, blockers, or next work, at a material review join, handoff, pause, or closure, and when accepted documents, project skills, or documentation process change.
---

# Revival documentation steward

Preserve a durable, resumable project record while keeping each fact in its existing authoritative owner. This is a bounded maintenance role, not a new planning authority, backlog, decision maker, or standing writer persona.

## Authority and required reading

Always read:

- [`AGENTS.md`](../../../AGENTS.md)
- [`REVIVAL.md`](../../../REVIVAL.md)
- [`docs/revival/current-plan.md`](../../../docs/revival/current-plan.md)
- [`docs/revival/skills-and-agents.md`](../../../docs/revival/skills-and-agents.md)
- the current Git status, target diff, and latest landed change relevant to the packet

Then read the smallest applicable authority set:

- [`docs/revival/roadmap.md`](../../../docs/revival/roadmap.md) and the owning accepted domain document for phase outcomes or product and technical contracts;
- [`docs/revival/source-translation.md`](../../../docs/revival/source-translation.md) and [`docs/revival/source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md) for source paths, symbols, dispositions, provenance, and island state;
- [`docs/revival/functional-completeness.md`](../../../docs/revival/functional-completeness.md) and [`docs/revival/functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md) for capability scope, owners, evidence, and row state;
- [`docs/revival/verification.md`](../../../docs/revival/verification.md) and [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md) for evidence and closure claims;
- [`revival-completion-gate`](../revival-completion-gate/SKILL.md) and its one accepted verdict when reconciling a material `READY`, `HOLD`, terminal-evidence, or handoff decision;
- [`docs/revival/skill-supply-chain.md`](../../../docs/revival/skill-supply-chain.md) when a skill, external method, executable tool, pin, license, or audit boundary changes;
- [the pull-request template](../../../.github/pull_request_template.md) when preparing a reviewable handoff.

Accepted contracts govern. This skill may expose drift and route a proposed correction, but it cannot invent a product decision, reinterpret source evidence, advance a ledger row without proof, or amend scope on its own.

## Operating cadence

Reconcile only at the durable boundaries named in the skill description. Do not run a ceremony after every file edit or copy transient reasoning into the repository. `No documentation change required` is a valid result when no durable fact changed; name the checked owners and why they remain accurate.

## One fact, one canonical owner

Route each durable fact once:

| Fact | Canonical owner |
| --- | --- |
| Active packet, checkpoint, lane, named owners, current blocker, next two or three slices | [`current-plan.md`](../../../docs/revival/current-plan.md) |
| Durable phase order, phase outcome, and milestone exit | [`roadmap.md`](../../../docs/revival/roadmap.md) |
| Binding product, architecture, domain, testing, or verification rule | The owning accepted contract |
| Legacy path, symbol, caller, ordering, disposition, source provenance, deliberate difference, and island state | [`source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md) |
| Capability owner, completion proof, evidence state, or approved exclusion | [`functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md) |
| Preserved dormant or incomplete historical idea | [`future-opportunities.md`](../../../docs/revival/future-opportunities.md) |
| External technical source and its evidentiary limit | [`primary-source-index.md`](../../../docs/revival/primary-source-index.md) |
| External skill or tool pin, license, audit, allowed use, and exclusion | [`skill-supply-chain.md`](../../../docs/revival/skill-supply-chain.md) |
| Exact red, green, suite, build, launch, capture, device, performance, and review run for one change | Commit, pull-request, or named verification artifact |
| Completion-gate verdict, classifications, and stop instruction | Commit, pull-request, or named verification artifact; [`current-plan.md`](../../../docs/revival/current-plan.md) retains only the resulting active blocker or next state |
| Detailed reusable operating method | The narrow project skill |
| Skill selection, role boundaries, and orchestration | [`skills-and-agents.md`](../../../docs/revival/skills-and-agents.md) |

Do not duplicate full evidence in `current-plan.md`, turn a ledger into a current-work diary, put temporary command output into an accepted contract, or move a binding decision into a skill.

## Context restoration

At packet start or resumption:

1. Read `current-plan.md` before selecting work. Identify the active packet, checkpoint, packet owner, integration owner, next accepted slice, and lane-specific blockers.
2. Inspect the actual repository state and target identity. Do not treat a chat summary, stale handoff, or intended branch as proof of the current tree.
3. Read the owning contract and applicable source and functional rows. Compare their states with the last landed evidence rather than inferring completion from code presence or a green build.
4. Resolve any discrepancy before implementation. A stale current plan is corrected only by the integration owner; another agent supplies the exact proposed change and evidence.
5. State the restored execution context in the work packet or handoff. Do not create a recovery file.

A resumable packet can answer from canonical files and the actual tree:

- What observable result is active?
- Who owns the packet, shared files, and integration?
- What is proven, open, blocked, and next?
- Which source and capability rows are involved?
- Where does the detailed evidence live?

If one answer is missing, label it unproven or assign the existing owner that must be updated. Do not reconstruct certainty from memory.

## Reconciliation workflow

1. **Name the maintenance boundary.** Record the base and target, active packet and checkpoint, integration owner, affected contracts and rows, and whether the task is entry, resumption, evidence change, amendment, handoff, or closure.
2. **Compare claims with evidence.** Inspect the full changed-file contents and reachable consequences. Separate verified fact, accepted decision, inference, proposed update, and unresolved question.
3. **Run a bounded drift scan.** Check active documents for conflicting platform floors, toolchains, target counts, phase state, ownership, blockers, next-step prose, superseded mechanisms, duplicate queues, broken links, and claims that exceed the recorded checkpoint.
4. **Route the smallest durable update.** Change only the canonical owners whose facts changed. Preserve each document's status and authority header. Remove superseded active prose in the same change rather than leaving both directions.
5. **Reconcile the handoff.** Give the integration owner the one completion-gate verdict and dispositions, an exact `current-plan.md` proposal, affected ledger transitions, accepted-document changes, verification, open uncertainty, and next two or three slices. The integration owner accepts, adjusts, or rejects the proposal against the evidence.

The documentation steward does not replace the fog-of-war preflight, source translator, domain owner, reviewer, or integration owner. It ensures their durable results reach the right files.

## Concurrency and ownership

- Only the named integration owner edits live state in `current-plan.md`. A solo packet owner may do so only after recording themself as interim integration owner.
- A documentation steward may inspect in parallel with implementation and prepare a read-only drift report. It edits at a named join only after receiving ownership of the affected documents or rows.
- Two agents do not concurrently edit the same accepted document, ledger row, plan state, shared project metadata, or handoff record. Name the owner and merge order first.
- A lane owner includes proposed state and row changes in the handoff. The steward checks their routing and evidence; the integration owner performs final reconciliation.
- Reviewers report findings. They do not silently rewrite accepted decisions or live plan state.

This role is useful precisely because several files exist. It must reduce ambiguity, not create another coordinator or serial gate for otherwise independent Mac/shared work.

## Handoff contract

Return a concise documentation-continuity record containing:

- repository base and target identity;
- active packet, checkpoint, packet owner, and integration owner;
- durable facts that changed and the evidence supporting each one;
- canonical files and exact rows updated, or `no documentation change required` with the checked owners;
- proposed `current-plan.md` change and the integration owner's disposition;
- source and functional row transitions without overstating closure;
- exact document, test, build, launch, capture, or device verification relevant to the claims;
- the one completion-gate verdict, required-now items, deferred items, rejected ceremony, and stop instruction for a material closure;
- remaining uncertainty and lane-labeled blockers;
- the next two or three concrete slices when the active result changed them.

Put detailed command transcripts and ephemeral troubleshooting in the change record, not in accepted documents or a new progress journal.

## Prohibited planning sprawl

Do not create or maintain:

- `task_plan.md`, `findings.md`, `progress.md`, `.planning/`, per-agent journals, or another current-work backlog;
- automated prompt-injection, plan-recitation, attestation, loop, or recursive stop/completion hooks; the bounded read-only `revival-completion-gate` review is the accepted exception and creates no automation or parallel plan;
- a second decision log or evidence ledger beside the accepted documents and existing ledgers;
- an error quota, forced update after a fixed number of reads, or mandatory documentation touch when no durable fact changed;
- a hand-maintained knowledge graph or generated relationship artifact presented as project state.

Temporary local notes remain untracked and non-authoritative. If a fact deserves to survive a context reset, route it to its canonical owner or the commit, pull-request, or named evidence artifact that owns it.

## Verification

For documentation-only work:

1. inspect every new or changed relative link against its target;
2. search active documents for superseded or duplicated current-state language and inspect each hit in context;
3. confirm that status and authority headers still match the document's role;
4. confirm that current state appears only in `current-plan.md` and detailed evidence remains in its owning ledger or change record;
5. run:

```sh
rtk git diff --check
```

Run any additional project document checker that actually exists and record its exact result. Do not invent a product red test for prose. Do not close with only `docs updated`; name the routed facts, files, and checks.

## Method provenance

This skill is original Revival-specific prose implementing the accepted documentation authority and integration-owner rules. Its context-restoration, read-before-decision, phase-boundary writeback, and resumable-handoff ideas were informed by the MIT-licensed OthmanAdi `planning-with-files` skill at commit `f90780c92f0506d21c5f6c4865ce95517a8b1964`, audited July 16, 2026. No text, templates, hooks, scripts, commands, assets, or planning files from that source were copied into the repository, and none of its scripts or hooks were executed. The project's existing documents and ledgers replace the upstream `task_plan.md`, `findings.md`, `progress.md`, `.planning/`, hook, attestation, recitation, error-log, loop, ledger, and automated stop-gate mechanisms. The independent project-authored completion review is a single human-readable decision, not an upstream hook or planning system.
