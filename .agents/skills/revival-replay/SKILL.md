---
name: revival-replay
description: Implement one native replay path after the scheduler decision. Use for recording, playback, checkpoints, continuation, diagnosis, observers, replay authoring, and replay verification.
---

# Revival replay

Make replay a first-class record of the selected native simulation, not a compatibility reader or a second scheduler.

## Authority and activation

Read [`AGENTS.md`](../../../AGENTS.md), [`roadmap.md`](../../../docs/revival/roadmap.md), [`current-plan.md`](../../../docs/revival/current-plan.md), [`verification.md`](../../../docs/revival/verification.md), [`source-translation.md`](../../../docs/revival/source-translation.md), [`test-driven-development.md`](../../../docs/revival/test-driven-development.md), and the replay rows in [`functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md).

This skill is installed now. Review and amend it after Phase 3 selects the one scheduler and before the first Phase 5 replay production change. Phase 9 reviews it again against the final networked simulation; that review does not create a second replay design.

## Establish the contract

1. Trace original demo/replay entry points, recorded inputs or state, ordering, checkpoints, seeking, end conditions, UI, editor callers, multiplayer use, and failure behavior.
2. Name the native observation being protected: faithful playback, continuation, diagnosis, observer evidence, or creator workflow.
3. Record the canonical revision, selected scheduler, authoritative state, nondeterministic inputs, content identity, and compatibility decision needed for that observation.
4. Write a focused red test before production implementation.
5. Implement the smallest native record and playback path through the shipping simulation.
6. Save, reopen, seek or continue where applicable, and compare declared checkpoints.
7. Add the current editor inspection, validation, and publishing path.

Replay records the information the selected simulation actually needs. Preserve source-supported observable outcomes and useful capability, not original packets, memory layouts, demo bytes, platform timing workarounds, or historical defects.

## One path and clear revisions

- RevivalMac, RevivalMobile, RevivalEditor, diagnostics, observers, and multiplayer consume the same canonical replay model.
- A public replay revision is explicit and validated at intake. Add a migration only for a real released native revision.
- An incompatible revision fails with an actionable diagnostic; it does not trigger a legacy reader or hidden fallback.
- Checkpoints and hashes describe exactly which authoritative state they cover. They are evidence, not a claim that every platform float is magically deterministic.
- Playback uses the selected scheduler and simulation ownership. Do not retain variable and fixed replay modes.

## Prohibited complexity

Do not build a generic event-sourcing framework, dual input/state recording engines, packet-compatible demo layer, speculative rollback architecture, replay-only simulation seam, hidden compatibility backend, or universal serialization abstraction. Do not force deterministic math, custom allocation, or tick conversion without the accepted scheduler evidence.

## Verification

Record focused red/green commands and affected tests for recording, playback, end conditions, corruption, revision mismatch, save/reopen, checkpoint comparison, and continuation where promised. Record the Mac/shared and mobile composition checkpoints separately while exercising the same record in RevivalMac, RevivalMobile and RevivalEditor; use applicable physical iPhone and iPad hardware where mobile composition, lifecycle, or performance is claimed. A Mac/shared replay packet need not wait on unavailable support-floor hardware, while overall milestone and release-floor claims retain their mobile evidence requirements. Phase 9 adds authority, observer, desync, reconnect, and published multiplayer replay matrices to this path.

Close the relevant source and capability rows only when the promised runtime, creator, validation, playtest, and publishing routes pass. Material replay changes pass [`revival-review`](../revival-review/SKILL.md).
