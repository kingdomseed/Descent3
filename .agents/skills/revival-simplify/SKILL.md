---
name: revival-simplify
description: Simplify changed Revival Swift or MSL while proving observable behavior, source fidelity, capability, and the single production path remain unchanged. Use for behavior-neutral refactoring, defensive-code removal, duplication cleanup, and dead-code deletion.
---

# Revival simplify

Make the native implementation smaller, clearer, and more direct without changing what the player, creator, importer, publisher, or supported tool observes.

## Authority

Read the current contract and the accepted documents that own it, especially:

- [`AGENTS.md`](../../../AGENTS.md)
- [`docs/revival/engineering-principles.md`](../../../docs/revival/engineering-principles.md)
- [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md)
- [`docs/revival/source-translation.md`](../../../docs/revival/source-translation.md)
- [`docs/revival/source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md)
- [`docs/revival/current-plan.md`](../../../docs/revival/current-plan.md)
- the current domain document

These documents decide scope and semantics. `current-plan.md` selects the active packet and checkpoint without changing those contracts. This skill cannot delete a ledgered capability, approve a deliberate behavior change, add a production path, or amend architecture.

Simplification is the refactor step of a green contract. If the proposed edit changes observable behavior, stop and begin a new red-green-refactor cycle. If the relevant behavior is unknown, resolve it with the smallest direct source trace or experiment; use `revival-wayfinding` only when multiple linked unknowns meet that skill's trigger gate.

## Establish the preservation claim

Before editing, state in the working record or pull request:

1. the exact diff, files, or dependency island in scope;
2. the observable contracts that must remain unchanged;
3. the source rows, deliberate differences, and accepted decisions that constrain the work;
4. the real RevivalMac, RevivalMobile, editor, importer, renderer, save, replay, network, or publishing entry points that reach it;
5. the existing evidence that protects it;
6. the concrete complexity expected to disappear.

These are the facts to establish, not a form quota. For a genuinely local cleanup reached by one known contract, one compact note naming the protected result, real caller, protecting evidence, and deletion is enough. A material ownership, source-order, lifetime, persistence, editor/player, or broad mechanical refactor records the full island and blast radius.

Do not create another ledger or refactor-artifact system. Put durable evidence in the existing source ledger, test record, commit, or pull request that already owns the change.

If a reachable contract lacks a sensitive test, follow the controlled-mutation procedure in the TDD document before refactoring. Dead or unreachable code instead requires proof that no supported production entry point reaches it. Do not invent a test route to keep dead code alive.

## Inspect the change

Look for concrete simplifications in five areas.

### Reuse and duplication

- Reuse an existing direct game operation when it already owns the same semantics.
- Collapse duplicated canonical conversion, validation, state transition, or rendering choice.
- Delete pass-through helpers, identity wrappers, mirrored state, and near-empty adapters.
- Consolidate repeated code only when the cases share one rule. Similar-looking source behavior with different ordering or ownership stays explicit.
- Do not introduce a generic abstraction merely to remove a few repeated lines.

### Structure and ownership

- Replace one-implementation protocols, managers, services, providers, registries, and factories with concrete ownership.
- Remove mode flags, broad optionals, fallback paths, and hidden mutable state when construction can express one valid state.
- Keep one mutable simulation owner and resident-level owner per application or play-session instance, one shared renderer implementation, and distinct editor-document and play-session values.
- Use direct AppKit or UIKit, Metal, MetalKit, GameController, AVFoundation, AVAudioSession, Network, and CryptoKit calls in the concrete target that owns each service. Do not consolidate the two shells into a generic platform, input, or filesystem abstraction.
- Keep canonical data free of renderer objects, framework workarounds, and legacy container knowledge.

### Control flow and defensive code

- Validate untrusted input once as it becomes canonical, then trust the canonical value.
- Remove repeated internal guards for states canonical construction excludes.
- Prefer a direct call, early return, exhaustive `switch`, small concrete value, or local function over callbacks and indirection.
- Delete catch-and-ignore behavior, placeholder defaults, speculative recovery branches, and comments that rationalize them.
- Preserve assertions that state a real trusted invariant and are backed by construction and evidence.

### Efficiency

- Remove work that is provably repeated, unused, or immediately overwritten.
- Keep observable iteration order, Float32 operation order, update order, eager preparation, reachable lazy dependency discovery, and final GPU-use lifetime intact.
- Do not add concurrency, caching, unsafe access, specialization, custom allocation, streaming, or a scheduler change as cleanup.
- Performance refactoring requires the accepted optimized M4 measurement gate and, when the claim includes a mobile path, applicable physical iPhone and iPad measurement. Exact support-floor certification is public-beta or release evidence and does not block an independent Mac/shared simplification. Line count and theoretical speed are not evidence.

### Blast radius

Trace consequences beyond the edited function:

- Mac-player, mobile-player, runtime, and editor callers;
- canonical package and save consumers, including mobile file-picker intake and app-owned storage;
- complete `Level` topology and dependency preparation;
- simulation timing, AppKit and UIKit lifecycle callbacks, suspension, resumption, and teardown;
- Metal submission and resource release;
- undo, save/reopen, disposable play, and publishing;
- source dispositions, deliberate differences, and applicable milestone checks.

Prove the facts that make the edit safe with source, a focused test, a controlled mutation, a real integration path, or a required measurement. Mark a material claim unproven rather than smoothing over missing evidence.

## Refactor in controlled steps

1. Make one coherent simplifying move.
2. Run the narrow protecting test and inspect the diff.
3. Run the directly affected suite.
4. Continue only while the preservation claim still holds.
5. Re-run the applicable integrated player or creator checkpoint when ownership or composition changed.

For a repeated mechanical pattern, prove one representative case before widening the edit. Inspect every changed site afterward. A bulk rewrite does not waive file and symbol accounting.

If cleanup exposes a defect, stop the behavior-neutral refactor. Record the defect, write and observe the focused red test, then fix it as its own contract. Do not hide a behavior change inside cleanup.

## Completion evidence

Record:

- the preservation claim;
- the complexity removed and why no capability was lost;
- the exact focused and affected-suite commands and results;
- any integrated checkpoint or optimized M4 and physical mobile-device measurement required by the owning contract;
- source-led or architecture-sensitive blast-radius facts checked;
- any rejected suggestion and the evidence for rejecting it.

Keep the record proportional. A small cleanup may combine these into the compact preservation note above; a material refactor keeps the evidence separate enough to audit.

No protecting test may be skipped, weakened, deleted, or replaced with a mock path. Run at minimum:

```sh
rtk git diff --check
```

Use `revival-review` for a material simplification. Fidelity review remains required when source-supported order, ownership, lifetime, or editor/runtime relationships were touched, even if the intended behavior is unchanged.

## Prohibited outcomes

Reject a simplification that:

- removes runtime, authoring, validation, playtest, publishing, multiplayer, replay, or mod capability;
- replaces readable direct Swift with a framework, macro system, protocol graph, or type maze;
- preserves a legacy API, ABI, generic platform, input, or filesystem layer, or defensive branch merely because it existed in C++ or appears to unify the concrete AppKit and UIKit shells;
- creates a second loader, renderer, scheduler, content reader, simulation mode, or resource-lifetime path;
- optimizes for file size, line count, abstraction purity, or reviewer taste;
- reports build success as proof of behavior preservation.

## Method provenance

This is original project-specific prose derived from the accepted Revival documents. Its review lenses were informed by an audit of the MIT-licensed Deslop, Thermos, and pstack blast-radius methods in `cursor/plugins` at commit `3fe2823ce17c1656c222d4b7c59d3f82fbf20143`. Factory `simplify` at commit `e8801fa1020fbcd332c48aa068a80833bbe53e2e` supplied only the reuse, quality, and efficiency lens because no license was declared. The isomorphic principle is limited to proving the protected behavior before deletion. No premium or unlicensed skill text, scripts, or assets were imported.
