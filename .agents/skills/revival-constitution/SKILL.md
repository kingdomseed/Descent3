---
name: revival-constitution
description: Guard the Descent 3 revival's Apple-native scope, complete capability, one-way import boundary, human-first creator product, resident-world baseline, evidence-driven amendments, and single production path. Use when starting a workstream or reviewing a proposal that may change product direction.
---

# Revival constitution

Keep implementation decisions inside the accepted product contract without turning that contract into speculative architecture or a blanket ban on future evidence-led change.

## Authority and required reading

This skill implements accepted documents; it cannot amend them. Read before using it:

- [`AGENTS.md`](../../../AGENTS.md)
- [`REVIVAL.md`](../../../REVIVAL.md)
- [`docs/revival/architecture.md`](../../../docs/revival/architecture.md)
- [`docs/revival/functional-completeness.md`](../../../docs/revival/functional-completeness.md)
- [`docs/revival/functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md)
- [`docs/revival/future-opportunities.md`](../../../docs/revival/future-opportunities.md)
- [`docs/revival/content-pipeline.md`](../../../docs/revival/content-pipeline.md)
- [`docs/revival/world-loading.md`](../../../docs/revival/world-loading.md)
- [`docs/revival/engineering-principles.md`](../../../docs/revival/engineering-principles.md)
- [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md)
- [`docs/revival/roadmap.md`](../../../docs/revival/roadmap.md)
- [`docs/revival/verification.md`](../../../docs/revival/verification.md)
- [`docs/revival/skills-and-agents.md`](../../../docs/revival/skills-and-agents.md)

Read the current domain document and ledger rows for the proposed work. Before this skill's first production use in a workstream, compare it with the current accepted documents and source evidence; amend the skill if it is stale. The documents still win.

## Constitutional invariants

- Ship one Apple Silicon, macOS 26+ implementation with the Swift 6.4 compiler in Swift 6 language mode and with MSL using direct Apple frameworks and Metal 4. Use Xcode 27 beta until stable Xcode 27 replaces it; keep no Swift 6.3 compatibility path.
- Ship no legacy C or C++ engine, Objective-C++ bridge, Rust runtime, OpenGL or SDL runtime, Wine or Game Porting Toolkit layer, or native Osiris module.
- Transfer behavior through dependency-ordered source translation and record every relevant legacy file's disposition.
- Deliver the complete player and human creator capability inventory. KISS reduces mechanisms, not scope.
- Treat the evidenced shipped game and creator tools as the version 1.0 capability ceiling. Preserve nonworking historical ideas for later consideration without turning them into current requirements or silently losing them.
- Keep D3Import as the sole shipping legacy-format reader. The game and editor consume canonical content only.
- Require version 1.0 users to own and import the one supported prepared retail profile. Additional sources and project-owned replacement assets require later explicit decisions.
- Start from one complete resident `Level`, source-evidenced eager preparation, and current reachable canonical lazy preparation. This is the current implementation, not “no streaming ever.”
- Start RevivalEditor with the first world slice and share world types, loading rules, simulation, and rendering while owning separate document and play-session values.
- Keep one renderer, one scheduler, one level-lifetime path, one canonical world model, and one production path at a time.
- Keep the product human-first. MCP, headless authoring, telemetry, training capture, and agent-only paths wait until the complete human creator suite ships.
- Require affordable native Internet multiplayer while leaving its 2026 topology to accepted evidence. Do not assume a project-operated service, relay, or recurring cost without a viable owner and explicit approval.

## Classify the proposal

Before changing code or an accepted document, state which kind of change is proposed:

1. **Faithful transfer:** preserves the source-supported observable contract in native ownership.
2. **Local native structure:** changes private decomposition without changing a product contract.
3. **Deliberate semantic difference:** changes an observable result and records old behavior, new behavior, and evidence.
4. **Binding amendment:** changes product scope, platform, interoperability, a cross-workstream architecture, or the production protocol.
5. **Research hypothesis:** asks a bounded question and does not enter a product target.

Do not promote a hypothesis into architecture. Ordinary local structure does not need a constitution amendment. A binding amendment requires explicit user approval and coordinated updates to every affected accepted document and ledger.

## Decision workflow

1. Name the current observable result, owning accepted contract, functional rows, and source rows.
2. Trace the pinned source and current product path before proposing redesign.
3. Identify the concrete limitation. For performance or lifetime claims, capture an optimized representative M4 measurement.
4. Choose one smallest direct design that preserves complete scope. Do not average incompatible options into a permanent abstraction.
5. State what will be deleted or superseded and how one production path remains.
6. For new or changed production behavior, write and run one focused automated test first; confirm it fails for the intended missing contract.
7. Implement the smallest direct green change, refactor while green, then run the owning domain's integration checks.
8. Record deliberate differences, ledger transitions, source provenance, evidence, and any temporary-harness deletion.

Documentation-only amendments use link, consistency, and evidence checks rather than a fake product test. Changing the red-first protocol or another binding production rule requires an explicit user-approved amendment.

## Amendment discipline

A valid amendment names the current rule, the falsifying evidence or new product decision, the selected replacement, affected capabilities, migration or reimport consequences, and deletion of the superseded path. It updates active documents together so no stale alternative remains.

Future streaming, a fixed scheduler, another platform, another legacy source profile, another DCC ingress, or a post-1.0 expansion of the authored behavior representation are possible only through their accepted evidence gates. Do not install their frameworks, flags, adapters, or parallel modes in advance.

## Prohibited complexity and scope drift

Reject:

- cross-platform wrappers and legacy-shaped compatibility layers;
- generic ECS, job, render-graph, event-bus, dependency-injection, asset-database, allocator, resource-manager, or service frameworks without accepted evidence;
- resident/streaming switches, dual schedulers, alternate loaders or renderers, and “temporary” production fallbacks;
- defensive branch forests after canonical boundary validation;
- backward legacy export, original-save output, original-server interoperability, or binary community-module loading without an approved constitution change;
- silent removal of multiplayer, replay, creator, presentation, baking, publishing, or mod-SDK capability;
- exact target counts, fixed tick rates, atlas layouts, behavior VMs, editor overlay protocols, or performance budgets selected before real evidence.

## Verification and closure

The constitutional review closes only when:

- the proposal is classified and its authority, affected rows, and current source evidence are named;
- every affected active document expresses the same chosen direction and no historical document is treated as authority;
- any binding amendment has explicit user approval and leaves one production mechanism;
- applicable production behavior has recorded focused red, focused green, affected-suite, and integration evidence;
- superseded product code, tests, flags, scaffolds, and prose are removed or receive an approved ledger disposition;
- functional scope remains complete and source accounting remains explicit;
- independent fidelity, architecture, evidence, and simplicity findings are resolved.

Search active documents for superseded terminology and inspect every hit in context; a mention that rejects or archives an idea is not a conflict. Run at minimum:

```sh
rtk git diff --check
```

Record the exact additional commands, inputs, configuration, and results used. Do not close with “docs updated,” “build passed,” or “smoke test passed.”
