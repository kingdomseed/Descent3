---
name: revival-networked-simulation
description: Extend the final Revival simulation to host-authoritative multiplayer. Use for authority, prediction, reconciliation, interpolation, replication, latency policy, observers, desync evidence, and replay interaction.
---

# Revival networked simulation

Add networking to the working final simulation without forking its rules or inheriting the original wire protocol.

## Authority and activation

Read [`AGENTS.md`](../../../AGENTS.md), [`roadmap.md`](../../../docs/revival/roadmap.md), [`verification.md`](../../../docs/revival/verification.md), [`source-translation.md`](../../../docs/revival/source-translation.md), and the multiplayer rows in [`functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md).

This skill is installed now but must be reviewed and amended against the final scheduler, behavior model, replay path, collision model, and representative M4 measurements immediately before Phase 9 simulation work. Details not fixed by accepted documents remain open until that review.

## Derive the model from working behavior

1. Inventory every authoritative mutable state and player command exercised by the first multiplayer slice.
2. Trace the historical capability, ordering, host controls, latency behavior, correction, observer, co-op, and failure semantics without treating legacy packets as the design.
3. State the authority and observable convergence contract for one concrete scenario.
4. Write a focused failing test using the production simulation path.
5. Implement the smallest host-authoritative command, state, prediction, reconciliation, and remote-presentation flow needed by that scenario.
6. Add controlled latency, loss, reorder, reconnect, and desync evidence as each contract requires it.
7. Exercise the same rules in listen-host, dedicated-host, observer, replay, and editor play paths as they become applicable.

The host runs the same simulation owner as single-player. Local prediction and remote interpolation present that authoritative model; they do not become alternate game rules. Stable ordering, content and simulation identity, portal and collision correction, weapon-latency policy, difficulty, AI authority, and continuation behavior remain explicit.

## Scale only from evidence

Start with the smallest real end-to-end session and grow through each mode's source-supported player count. Measure bandwidth, history, send rate, resimulation, interpolation, and M4 CPU cost before selecting permanent bounds or layouts. Keep the released 32 network/player-slot infrastructure and historical listen/dedicated slot accounting without claiming that every mode supports 32 players; campaign co-op begins at its source-evidenced four-player cap. Record any native slot-accounting change as a deliberate modernization.

Use direct data values and functions. Isolate nondeterministic transport and clocks at their real boundaries; do not protocol-wrap the whole simulation merely for tests.

## Prohibited complexity

Do not import original packet layouts, direct-IP interoperability, DMFC/native module execution, a generic replication framework, distributed ECS, actor-per-entity design, speculative rollback engine, dual authority modes, deterministic-math rewrite, or network-only behavior implementation. Do not duplicate boundary validation inside trusted simulation code.

## Verification

Record source capability evidence, focused red/green commands, authoritative checkpoints, prediction and correction traces, declared latency/loss/reorder inputs, observer and replay results, optimized measurements for performance claims, deliberate differences, and source/capability state transitions. Phase 9 closes only with the full local, LAN, selected-Internet-topology, dedicated, observer, mode-specific-count, four-player-co-op, outage, creator, replay, and 32-slot-infrastructure matrices defined by the accepted documents.

Material changes pass the four independent concerns in [`revival-review`](../revival-review/SKILL.md).
