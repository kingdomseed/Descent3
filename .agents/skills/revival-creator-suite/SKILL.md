---
name: revival-creator-suite
description: Build, review, and close RevivalEditor slices through the human-first AppKit document, canonical edit, named undo, save and reopen, shared player paths, disposable play session, validation, and publishing workflow.
---

# Revival creator suite

Grow one permanent native creator application alongside the game, one working authoring contract at a time, without creating an editor framework or a second engine path.

## Authority and required reading

This skill implements accepted documents; it cannot amend them. Read [`AGENTS.md`](../../../AGENTS.md) and every global prerequisite it names. Creator work additionally requires:

- [`creator-suite.md`](../../../docs/revival/creator-suite.md)
- [`content-pipeline.md`](../../../docs/revival/content-pipeline.md)
- [`world-loading.md`](../../../docs/revival/world-loading.md)
- [`current-plan.md`](../../../docs/revival/current-plan.md)
- the current feature's source callers and functional rows

Before first production use for a workspace, compare this skill with the current editor/runtime evidence and amend it if stale.

## Ownership and first slice

- RevivalEditor is one AppKit application using one `NSDocument`, one main-actor editing owner, one canonical project value, one `UndoManager` history, and one primary window per project.
- AppKit owns document lifecycle, edited state, file coordination, menus, restoration, keyboard behavior, and accessibility integration.
- The imported canonical base is read-only. Editing derives a separately owned complete-Level project value and preserves provenance.
- Play creates a disposable session copy. It uses the same world types, loader, simulation, dependency rules, and RevivalMetal path as RevivalMac and RevivalMobile.
- Shared world means shared code and semantics, never concurrent mutation of one instance.
- Phase 1 opens the complete Training `Level`, focuses the selected room, performs the smallest meaningful edit selected from traced historical workflow evidence without foreclosing later creator work, undoes, redoes, saves, reopens, plays, and returns.

## Slice workflow

1. Name one creator-visible outcome and its `current-plan.md` packet and Mac/shared checkpoint, owning functional row, source callers, runtime contract, validation rule, and publishing consequence.
2. Trace useful D3Edit or tool behavior and the corresponding runtime path. Preserve outcomes, not MFC dialogs, global modes, or temporary D3L handoff machinery.
3. Choose the smallest concrete edit over canonical values. Add stable identity only where selection, references, or save/reopen require it.
4. Write one focused automated test before production implementation. Run it and confirm the intended missing editor behavior or reproduced defect.
5. Implement a direct view action and concrete edit operation. Keep game rules and serialization out of view code.
6. Register a named inverse with `UndoManager`; coalesce continuous samples into one completed action.
7. Validate changed references and current reachable dependencies, update only actually stale derived data, and link diagnostics to their owners.
8. Save, close, and reopen through the production document format. Confirm the read-only base is unchanged.
9. Create a disposable play-session copy and execute the real shipping simulation and renderer; return to useful document, selection, and camera state.
10. Run the affected suite and the applicable authoring, validation, playtest, publishing, accessibility, resource-release, and optimized M4 checks. Through Phase 7, an editor packet never waits on mobile hardware, signing, development-team setup, or physical-device evidence. Phase 8 owns accumulated cross-player physical mobile integration; later publishing or certification claims add the applicable player and device evidence at their owning phase.
11. Record red and green commands, source comparison, deliberate differences, ledger transitions, and exact observable results.

Add a surface only when the current slice has real content and operations for it. A modern operation may replace several historical commands when it preserves their useful capability.

## Long operations

Use Swift concurrency only for a real blocking import, conversion, bake, validation, publication, or other measured long operation. It consumes immutable input, reports useful progress, supports cancellation where the underlying work can stop safely, and cannot overwrite newer source.

Add the smallest local stale-result check when the first real operation can race with editing. Share a mechanism only after two real operations need the same form. Failure preserves the current document and links diagnostics to the owning source value.

## Red-first and test value

Every new or changed editor command, document behavior, validation rule, play transition, publisher behavior, or background-operation contract begins with a focused automated red through its production path. “Add tests when the workspace matures” does not waive red-first implementation.

Test project-owned document, edit, reference, validation, serialization, composition, and framework-adaptation behavior. Do not unit-test AppKit, Metal, or `UndoManager` themselves, and do not introduce a protocol, store, service, public setter, alternate initializer, or mock mode solely for tests.

Documentation-only creator changes use link and consistency checks rather than a fake application test.

## Prohibited complexity and drift

Reject:

- a reactive store, view-model graph, generic command protocol or bus, service layer, dependency-injection container, or editor-wide event bus;
- an editor-only loader, renderer, simulation, game fork, or mutable world shared with play;
- a preview-package cache, last-good/candidate package layers, universal generation protocol, fixed overlay slices, job framework, or background-document residency system;
- empty panes, fixed workspace diagrams, speculative four-viewport budgets, cloud collaboration, source-control client, marketplace, or attempt to replace Blender;
- legacy D3L, HOG, OMF, or native-plugin export; runtime USD live links; a generic DCC abstraction;
- a predesigned behavior graph or second executor before the accepted behavior evidence gate;
- MCP, headless authoring, public command schemas, telemetry, training capture, or agent-only paths before the complete human suite ships;
- defensive checks inside trusted canonical editing code for states boundary validation excludes.

## Verification and closure

A creator slice closes only when:

- the real `NSDocument` path executes the claimed operation over canonical project values;
- the read-only base remains unchanged and separate document and disposable play values are proven;
- the edit has a user-facing name, undo, redo, validation, save, close, reopen, and useful post-reopen state as applicable;
- play enters and returns through the shared shipping world, loading, simulation, and Metal paths with no second implementation;
- the applicable runtime, authoring, validation, playtest, and publishing paths required by the functional row work, or an inapplicable path has a recorded reason;
- background work, when present, proves immutable input, supported cancellation, stale-result rejection, and failure preservation;
- required keyboard, focus, VoiceOver, diagnostics, and M4 responsiveness evidence exists for the surface's milestone;
- when Phase 8 cross-player integration or later publishing or certification is claimed, the package installs and completes through both RevivalMac and RevivalMobile with the applicable physical-device evidence; a Phase 1–7 editor slice closes without manufacturing or waiting on that later mobile evidence and does not claim cross-player completion;
- involved source rows reach allowed terminal states for the claimed island, and claimed functional rows carry their required evidence;
- focused red, focused green, affected-suite, integration, and resource-release evidence have no required skip;
- independent fidelity, architecture, evidence, and simplicity findings are resolved.

An empty native project and independently authored campaign or multiplayer package are non-bundled creator-suite certification. They do not supply replacement retail content or waive the version 1.0 ownership and import requirement.

Run exact focused and integrated commands for the real targets. At minimum:

```sh
rtk git diff --check
```

Do not call a viewer an editor slice, a serialized value a save/reopen workflow, or an editor-only preview a shared product path.
