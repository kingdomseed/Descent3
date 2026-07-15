---
name: revival-volumetric-navigation
description: Translate Descent 3 volumetric navigation from real route and movement evidence. Use for nodes, routes, clearance, steering, blockage, recovery, AI movement, and editor navigation diagnostics.
---

# Revival volumetric navigation

Reproduce the navigation behavior required by working creatures and levels before choosing a more general native representation.

## Authority and activation

Read [`AGENTS.md`](../../../AGENTS.md), [`behavior-system.md`](../../../docs/revival/behavior-system.md), [`source-translation.md`](../../../docs/revival/source-translation.md), [`source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md), [`test-driven-development.md`](../../../docs/revival/test-driven-development.md), and [`creator-suite.md`](../../../docs/revival/creator-suite.md).

This skill is installed now but activates only after the relevant Training routes, node data, AI callers, collision rules, and editor operations have been traced. Review and amend it against that evidence immediately before the first production navigation change.

## Work one observable route

1. Name the creature, start, destination, level state, and observable success or failure.
2. Trace route construction, node ownership, room and portal relationships, clearance, movement constraints, steering, blockage detection, recovery, invalidation, and teardown.
3. Record all participating runtime and editor source rows.
4. Capture a reference route and movement trace, including deterministic inputs and failure cases.
5. Write the focused red contract.
6. Implement direct Swift storage and calls through the existing simulation owner.
7. Add only the editor inspection, validation, and authoring operations required by the represented data.
8. Run the route in editor play, RevivalMac and RevivalMobile where the player path applies, record differences, and close the rows.

Preserve source-supported selection order, cost and clearance formulas, stable identity, recovery behavior, and the point at which route state is recomputed. Navigation must agree with the translated collision and movement models rather than inventing a parallel geometric truth.

## Direct native shape

Begin with readable contiguous values, concrete IDs where durable identity is required, and ordinary functions owned by the simulation or canonical level. Use exhaustive state for real route outcomes. Validate imported or authored topology once before trusted use.

Profile representative indoor and outdoor routes in an optimized build before changing layout, adding concurrency, or replacing an algorithm. A faster result is not faithful if it changes reachable behavior or recovery.

## Creator path

As each representation becomes real, RevivalEditor must be able to show the relevant nodes, links, clearances, ownership, invalid references, and route failure. Editing, baking, validation, save/reopen, play, and publishing are added when that data becomes creator-owned; a runtime-only hidden format is not complete.

## Prohibited complexity

Do not begin with a generic navmesh framework, graph protocol family, pathfinding service, spatial database, job system, actor-per-agent model, cache hierarchy, alternate navigation mode, or speculative outdoor solution. Do not keep the legacy editor/runtime split, fixed capacities, pointer ownership, or defensive checks already excluded by canonical construction.

Do not simplify away node, clearance, steering, blockage, or recovery semantics merely because a stock Training case does not exercise their complete creator-facing ceiling.

## Verification

Record source and reference traces, focused red/green commands, affected route tests, collision agreement, editor diagnostics, save/reopen/play evidence, optimized measurements on every affected recorded M4, iPhone, or iPad reference device where performance is claimed, deliberate differences, and terminal source rows for the closed island. Functional rows carry the evidence and state supported by the current slice and become terminal only when complete capability or milestone closure is claimed. Material changes pass the four concerns in [`revival-review`](../revival-review/SKILL.md).
