---
name: d3-content-import
description: Trace, implement, review, and close macOS D3Import work for the verified retail profile, checked legacy parsing, complete Level conversion, dependency evidence, deterministic provenance, atomic promotion, and strict Mac and mobile runtime isolation.
---

# D3 content import

Convert owned prepared retail data once into checked canonical Revival content. Keep every legacy format and lookup rule on the D3Import side of the boundary.

## Authority and required reading

This skill implements accepted documents; it cannot amend them. Read [`AGENTS.md`](../../../AGENTS.md) and every global prerequisite it names. Import work additionally requires:

- [`content-pipeline.md`](../../../docs/revival/content-pipeline.md)
- [`retail-data.md`](../../../docs/revival/retail-data.md)
- [`world-loading.md`](../../../docs/revival/world-loading.md)
- [`current-plan.md`](../../../docs/revival/current-plan.md)
- the current import rows in the source and functional ledgers

Before first production use for a new format or campaign slice, retrace the current legacy reader and dependency path, compare this skill with the accepted documents, and amend the skill if the evidence changed.

## Current boundary

- Version 1.0 accepts only the exact recognized prepared Descent 3 1.4-plus-Mercenary installation profile.
- Raw discs, installers, patch execution, Wine, extraction utilities, and historical preparation scripts remain nonshipping provenance work.
- D3Import is a macOS-only helper that reads supported HOG, MN3, D3L, and reached media formats. RevivalMac, RevivalMobile, RevivalCore, RevivalMetal, and RevivalEditor never do.
- RevivalMobile accepts only a Mac-produced canonical package through the platform file picker, validates it through the same native-package boundary as RevivalMac, and copies it into app-owned storage. D3Import does not gain a mobile target, mobile retail reader, generic filesystem layer, or platform-transfer service.
- Every included production `Level` has complete topology. The selected Training room narrows acceptance evidence, not package scope.
- Record source-evidenced eager `PageInAllData` dependencies separately from lazy dependencies reached by the currently translated product path.
- The canonical manifest grows with real behavior, matcen, spawn, presentation, and campaign paths. Do not pretend Phase 1 knows later reachability.
- Retail and converted proprietary media, local paths, reports, captures, and generated packages remain ignored and outside Git.

## Source-led import workflow

1. Name the `current-plan.md` import packet and checkpoint, requested complete level or campaign slice, accepted source profile, owning capability rows, and canonical consumers applicable to that checkpoint. Preserve RevivalMobile as a later consumer even when the active packet is Mac/shared.
2. Trace the legacy entry point, container precedence, case rules, field layout, ordering, references, dependency discovery, and failure behavior.
3. Add or deepen source-ledger rows for every parser, lookup path, definition reader, dependency expansion, and relevant editor or runtime caller.
4. Capture a source checkpoint or owned local baseline. Separate verified fact, inference, current decision, and deferred reachability.
5. Define the smallest production parser or conversion contract and one valid or malformed case that can falsify it.
6. Write the focused automated test first and run it through the real production parser. Confirm the intended failure before implementation.
7. Implement checked little-endian reads, bounds, names, folded-key collision handling, duplicates, sizes, variants, and references directly.
8. Preserve source-supported order and relationships in simple canonical values; validate once before constructing trusted values.
9. Integrate through the real D3Import operation, not a test-only parser or in-process runtime shortcut.
10. Fully write and validate the destination-adjacent staging package and a destination-adjacent report candidate. Under the destination-parent lock, require the destination to be absent or to load as a valid Revival package, promote the report first, perform the last supported cancellation check, and rename the staging package as the final commit. Restore the prior report only when supported cancellation or package-rename failure occurs before that commit; propagate a report-restoration syscall error directly. After commit, removal of replaced artifacts is best-effort cleanup.
11. Run the affected suite and applicable complete-Level, Mac-player, editor-isolation, failure-preservation, and local-retail evidence. At a claimed mobile composition checkpoint, run the production file-picker-to-app-storage path for the package schema, promotion, handoff, and consumer behavior it exercises. A parser-only or Mac/shared checkpoint leaves that later mobile evidence open, does not duplicate unrelated `T-019` evidence, and never exposes a retail source to the mobile target.
12. Record exact red and green commands, source comparison, deliberate differences, hashes, provenance, coverage, ignored entries, and ledger states.

## Canonical and failure rules

Use deterministic Codable JSON and ordinary Apple-readable files until a real consumer proves a narrower change. Durable content keys exist only where identity crosses project, package, save, behavior, or runtime ownership.

An unknown used feature, missing current dependency, malformed payload, truncated level, unresolved reference, case collision, or destination failure produces a source-linked diagnostic and a nonzero result. Before the package commit, supported failure or cancellation leaves the active package untouched; after commit, cleanup failure is reported without pretending the completed publication rolled back. Never invent missing values or fall back to the retail installation.

Once exact profile fingerprints establish the accepted bytes, an impossible contradiction in the trusted exact-profile lookup or parse path is a programming error. Do not add recovery branches or user diagnostics for it.

The helper's current product boundary is the explicit `D3Import --contract 1` process contract documented in the content pipeline. Pass source, staging, destination, scope, and report as separate arguments. A scope selects complete levels or campaign slices, never a production room cut.

## Red-first and test value

Every new or changed parser, validator, normalization rule, manifest rule, promotion behavior, or helper contract starts with a focused automated red through the production path. A missing fixture, unavailable retail file, broken target, or unrelated failure is not red evidence.

Synthetic and independently licensed fixtures may enter Git. Owned retail evidence stays local and ignored. A failure seam may schedule only a supported production event and must prove the exact accepted error or preservation outcome. It may not use callbacks to fabricate arbitrary permission, flag, ownership, or trusted-state corruption. Do not add a protocol, virtual filesystem, mock importer, public setter, alternate initializer, or process wrapper only for tests.

## Prohibited complexity

Reject:

- a runtime HOG, MN3, D3L, FNT, OSF, OMF, MVE, legacy-save, or native-module reader;
- an in-process legacy parser in the game or editor, compatibility fallback, backward export, or retail installation search;
- a mobile D3Import target, mobile retail reader, platform-neutral filesystem or picker abstraction, or project-operated package-transfer service;
- a daemon, XPC service, plugin API, generic process protocol, general archive, virtual filesystem, database, asset graph, or compression framework;
- heuristic acceptance of unknown installations or speculative second profiles;
- room-cut production packages, synthetic portal cuts, precomputed stream cells, stream blobs, spatial demand tables, or package-layer locators;
- executable behavior, Swift source, bytecode, retail DLLs, native Osiris modules, installers, or unrelated user data in canonical packages;
- defensive revalidation throughout trusted runtime code after canonical construction.

## Verification and closure

An import slice closes only when:

- the production parser and helper path execute for every claimed construct;
- every requested `Level` has complete rooms, portals, terrain, objects, paths, goals, and current bindings, with no topology trimmed;
- archive precedence, naming, hashes, source identity, and deterministic provenance are recorded;
- eager working-set evidence and currently reachable lazy dependencies are distinct and complete for the claimed path;
- malformed and unknown-used-feature cases fail diagnostically; an unrelated destination occupant is preserved and rejected; and supported precommit cancellation or destination failure preserves the previous valid package;
- the promoted canonical package validates and the consumers applicable to the claimed checkpoint prove no retail format is opened; a parser-only checkpoint closes through production D3Import, a Mac/shared integration checkpoint adds RevivalMac and RevivalEditor, and the separate mobile composition checkpoint proves file-picker intake, copy into app-owned storage, and shared native-package validation when package or handoff behavior is reached;
- involved source rows reach `verified`, `replaced`, `excluded`, or justified current-claim `deferred`; claimed functional rows have the applicable evidence;
- focused red, focused green, affected-suite, complete-Level, and applicable integrated evidence are recorded with no required skip;
- temporary research code is removed or archived outside product targets, and proprietary outputs remain ignored;
- independent fidelity, architecture, evidence, and simplicity findings are resolved.

Run exact focused and integration commands for the real targets. At minimum:

```sh
rtk git diff --check
```

A parser-only or Mac/shared import packet does not wait on unrelated mobile hardware. It also does not claim mobile intake, overall milestone completion, or version 1.0 readiness. Do not report a synthetic parser pass as Training import, a package write as atomic-promotion proof, a simulator-only picker exercise as physical mobile package-intake proof, or a build as import correctness.
