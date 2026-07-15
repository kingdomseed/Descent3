---
name: revival-behavior-system
description: Translate and extend Descent 3 behavior chains without inventing a speculative VM. Use for DALLAS, Osiris, event, state, behavior-authoring, debugging, save, and play-in-editor work.
---

# Revival behavior system

Build the behavior model from complete working chains. Preserve the intended capability while replacing generated C++, native modules, global dispatch, and ABI machinery with direct typed Swift.

## Authority and activation

Read:

- [`AGENTS.md`](../../../AGENTS.md)
- [`behavior-system.md`](../../../docs/revival/behavior-system.md)
- [`source-translation.md`](../../../docs/revival/source-translation.md)
- [`source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md)
- [`test-driven-development.md`](../../../docs/revival/test-driven-development.md)
- [`functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md)

This skill is installed before implementation so the workflow is visible. Immediately before its first production use, review it against the actual translated Training chains and amend any assumption that the source disproves. An amendment cannot silently reduce ledgered behavior or creator scope.

## Translate one complete chain

1. Name the observable gameplay and creator result.
2. Trace the module, generated block, handwritten ranges, messages, bindings, event producers, conditions, state, timers, engine calls, ordering, and teardown.
3. Seed source-ledger rows for every involved file and range.
4. Capture the historical checkpoints and deliberate native differences.
5. Write one focused failing test for the known contract.
6. Implement the smallest typed Swift state and direct functions that make it pass.
7. Expose only the current authoring values and diagnostics in RevivalEditor.
8. Save, reopen, play through the shipping simulation, and close the involved rows.

Use ordinary structs, enums, arrays, and exhaustive switches. Keep event order, timer semantics, side effects, simulation-owned randomness, entity references, and continuation state explicit. Add an operation when a translated chain or real creator scenario needs it, not because it appears in a global legacy table.

## Grow from evidence

- Start with the actual Training chains; do not predeclare the final event or operation universe.
- When a second real chain exposes repetition, extract only the smallest shared concept that makes both clearer.
- A direct typed executor may later be replaced by a richer authoring model only after working chains prove the required responsibilities.
- Migrate every working chain and remove the superseded path in the same accepted cutover. Never keep direct and interpreted production modes as permanent alternatives.
- Creator tools grow with executable behavior: edit, validate, inspect state, diagnose a failure, save, reopen, play, and publish through the canonical model.

## Boundaries

Validate authored or imported values as they become canonical. Trusted simulation code then consumes valid typed state without repeating format checks or building defensive branch forests. Framework failures and genuinely fallible lookups remain explicit at their real boundaries.

Never load native executable behavior, preserve an Osiris ABI, reopen legacy modules at runtime, or export backward-compatible modules. New saves persist the native state needed for continuation, not legacy memory layouts.

## Prohibited complexity

Do not introduce a universal event bus, generic VM, bytecode format, reflection registry, dependency-injection layer, task-per-behavior concurrency, complete operation catalog, or speculative network behavior protocol. Do not translate generated control flow while ignoring handwritten code outside it. Do not use placeholder cases, ignored errors, or default returns to make a chain appear complete.

## Verification and review

For each chain record:

- source files and exact generated and handwritten ranges;
- historical checkpoints, order, state, and side effects;
- focused red and green commands plus affected tests;
- editor edit, validation, save/reopen, play, and diagnostic evidence applicable now;
- persistence, replay, or network evidence when the chain reaches those domains;
- deliberate differences and terminal source-row transitions for the closed island;
- functional rows carrying the evidence and state supported by the current slice, becoming terminal only when complete capability or milestone closure is claimed.

Run [`revival-review`](../revival-review/SKILL.md) for a material chain. Fidelity review protects semantics, architecture review protects the canonical one-path boundary, evidence review checks the contract and ledger closure, and simplicity review rejects machinery not earned by the working chains.
