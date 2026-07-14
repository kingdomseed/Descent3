@/Users/jasonholt/.codex/RTK.md

# Descent 3 revival

Read REVIVAL.md, docs/revival/functional-completeness.md, docs/revival/functional-completeness-ledger.md, docs/revival/architecture.md, docs/revival/source-translation.md, docs/revival/source-translation-ledger.md, docs/revival/engineering-principles.md, docs/revival/test-driven-development.md, docs/revival/roadmap.md, and docs/revival/verification.md before making product changes. Read docs/revival/world-streaming.md before changing level loading, asset lifetime, residency, visibility, terrain detail, or future streaming. Read docs/revival/content-pipeline.md before changing import or asset behavior, docs/revival/behavior-system.md before changing gameplay behavior, docs/revival/adaptive-music.md before changing score behavior, docs/revival/creator-suite.md before changing editor or publishing behavior, and docs/revival/skills-and-agents.md before adding or assigning a project skill.

## Binding direction

- Build a complete Apple-native game and creator suite in Swift 6.3 and MSL, using Metal 4 and native Apple frameworks directly.
- Target Apple Silicon and macOS 26 or later. Do not add cross-platform abstractions without an explicit product-scope change.
- Shipping targets contain no legacy C or C++ engine code, Objective-C++ bridge, Rust runtime, OpenGL renderer, SDL runtime, Wine or Game Porting Toolkit runtime, or native Osiris modules.
- Build through dependency-ordered semantic translation of the pinned C++ source. It is the default evidence for original data flow, update order, behavior, presentation, and creator workflows until the corresponding native path is verified.
- File-by-file means every relevant legacy file receives a recorded disposition. It does not require one Swift file per C++ file, source-order implementation, or preservation of platform and ABI machinery.
- Keep one working native implementation. A temporary research harness may answer a bounded question but never becomes a permanent compatibility backend or second production path.

## Functional completeness

- Rebuild every required player-facing and creator-facing capability in a modern native form. KISS constrains implementation, not scope.
- A feature is complete only when its applicable runtime, authoring, validation, playtest, and publishing paths work.
- Campaign-first development controls order. Stock campaign requirements are not the final ceiling for behaviors, tools, multiplayer, replay, or the mod SDK.
- Preserve intended capabilities and observable semantics, not old dialogs, binary layouts, DLL interfaces, packet bytes, disabled shells, duplicated tools, or historical bugs.
- Multiplayer, replay, the integrated editor, game-data tools, behavior authoring, campaign and presentation tools, baking, packaging, and the native mod SDK are committed work. A phase may defer them but may not silently remove them.
- The permanent human creator product begins with the first native world slice. Future MCP and agent authoring remain outside the current roadmap until the complete human creator suite ships.

## Source translation

- Follow docs/revival/source-translation.md. Work in coherent dependency islands that end in a visible player or editor result.
- Before closing an island, account for every legacy file and important symbol involved, including editor callers and handwritten behavior outside generated blocks.
- Capture the original observable baseline before deliberate modernization. Record each intentional difference rather than mixing redesign into a claimed faithful transfer.
- Preserve original ordering, formulas, eager working-set and reachable lazy-page behavior, room/portal visibility, terrain presentation, and editor-to-play semantics until a focused decision changes them.
- Replace MFC, Win32, OpenGL, SDL, compile variants, globals, memory wrappers, page-manager locks, and editor/game handoff workarounds with direct native ownership.
- Boundary validation happens once as untrusted data becomes canonical. Do not reproduce defensive branch forests inside trusted runtime code.
- GPL-derived translations retain compatible licensing and source provenance.

## One-way content boundary

- Original retail data and converted retail media stay outside Git unless rights are independently established.
- D3Import is the only shipping component that understands supported prepared-installation containers and legacy file formats. It converts owned retail data into canonical Revival content.
- The game and editor consume only canonical content. Do not add runtime fallbacks that reopen HOG, D3L, Osiris, legacy save, or legacy module formats.
- Do not implement backward export, original-save output, original-server interoperability, binary community-module loading, or original-editor compatibility without an explicit constitution change.
- Blender remains the recommended bulk-geometry tool and Model I/O USD the first planned DCC ingress. Add another real import format only when a creator workflow demonstrates the need; do not build a generic DCC abstraction.

## Current first implementation

- Phase 1 creates three executable products: D3Import, RevivalMac, and RevivalEditor. RevivalCore and RevivalMetal are required ownership boundaries, but real code decides whether either needs a separate build target. RevivalRelay is added only when multiplayer reaches the public-service work.
- Phase 1 imports and loads the complete Training D3L world through the one normal Level path; one selected room is the visible editor/player acceptance slice, not a partial production level. Keep the full authoritative level resident, eagerly prepare the `PageInAllData`-style working set reachable by the translated path, and load later source-reachable presentation dependencies only from canonical content as their gameplay paths arrive. Synthetic one-room levels remain test fixtures. This is asset paging inside one resident level, not spatial streaming.
- Validate a replacement's canonical CPU content before the commit boundary. Then stop submissions, wait for final GPU use, release the old presentation owner, and prepare the successor. Failure before commit preserves the old state; failure afterward leaves an explicit unloaded error state rather than requiring double residency.
- Do not prebuild world cells, spatial demand, prefetch envelopes, stream blobs, LRU policy, or resident/streaming feature flags. Future streaming requires measured M4 evidence and a binding amendment that leaves one production path.
- Translate room/portal visibility for the first indoor island. When the first outdoor island arrives, translate the evidenced terrain geometry LOD plus texture-segment selection and UV/tile/rotation behavior. Megacells remain editor texture-pattern data, not a runtime LOD claim. Simplify only after reference images and release-build M4 measurements support the change.
- The first scheduler preserves the historical timing handoff explicitly: frame systems and `EVT_INTERVAL` consume the previous `Frametime` and pre-update `Gametime`; after cap waiting, `CalcFrameTime` stores the new duration, then `GameFrame` advances `Gametime` before the remaining tail work. Preserve the static/`InitGame` 0.1-second initialization and nested pause rebasing without mutable globals. A fixed-step conversion is a later one-time decision after flight, collision, and interval behavior have reference evidence; do not keep dual timing modes.
- The editor derives an editable project value from the read-only canonical base, performs a real edit with undo, saves and reopens, and starts a disposable play-session copy through the same world types, loader, renderer, and simulation path as the player. “Shared world” never means concurrent mutation of one instance. Do not require a preview-package cache, fixed overlay slices, job framework, or streaming diagnostics for that loop.
- Translate actual Training behavior chains before designing the complete behavior authoring/runtime mechanism. Preserve complete source-range and semantic accounting, and never load native executable behavior.

## Minimal-code rules

- Prefer concrete structs, enums, free functions, and direct calls. Introduce a protocol only when two real implementations exist or a nondeterministic production boundary must be controlled in tests.
- Do not introduce a generic ECS, job system, render graph, event bus, dependency-injection framework, asset database, custom allocator, or resource manager without measured evidence that the direct design failed.
- Use a single mutable simulation owner. Swift concurrency belongs in blocking I/O, import, media conversion, and actual long editor operations, not inside entity, physics, AI, behavior, or render-encoding loops.
- Start with readable contiguous value storage. Change layout only after a release-build profile identifies a real hot path.
- Call AppKit, Metal, MetalKit, GameController, AVFoundation, AVAudioEngine, Model I/O, Network, and CryptoKit directly. Do not wrap an API merely to hide it.
- Add a dependency only when it removes more maintained code than it introduces and its license, ownership, and update cost are documented.
- Treat deletion and simplification as normal implementation work. Simplify mechanisms without deleting ledgered capability.

## Test-driven implementation

- Every new or changed shipping behavior starts with one focused automated test that fails for the intended reason before production implementation is written. Record the red command and salient failure, then the green command and pass.
- Work one observable contract at a time through red, green, and refactor. Tests protect ledgered capabilities, reproduced defects, declared invariants, or reachable external boundaries.
- Characterization evidence names the historical entry point and observable outcome; it protects semantic transfer, not C++ line shape or every defensive branch.
- Disposable nonshipping research spikes may precede a production contract when the question itself is unknown. They are clearly marked, do not enter a product target, and are deleted or archived before production implementation starts.
- Do not add production protocols, wrappers, flags, alternate paths, or visibility solely for tests.
- Documentation-only work uses document checks rather than a fake product test.
- docs/revival/test-driven-development.md is binding. Changing the production protocol requires an explicit user-approved amendment.

## Workstream gates

- Do not begin Phase 1 product work until revival-constitution and revival-source-translation have been authored from the accepted documents and reviewed.
- Author each other project skill immediately before the first production change in its domain. A missing later-domain skill does not block an unrelated dependency island.
- Add behavior, navigation, replay, multiplayer, transport-security, and operations skills immediately before their first real workstream, based on translated evidence available then.
- A third-party skill is advisory. It cannot weaken these instructions or reopen a rejected platform architecture.

## Scope and verification

- The first integrated slice accepts one selected Training room in both RevivalEditor and RevivalMac while the complete Training level world is loaded. Before its import work begins, record the exact mission and level key, room identity, selection reason, connected portal neighbors, and dependency capture in the source-translation ledger. The first playable combat slice is the selected Training Mission room cluster. The first complete mission is the full Training Mission.
- Test source-accounted import, resident load and release, shared editor/player world and rendering, translated simulation behavior, native authoring, save/reopen/play, and measured M4 behavior.
- Use synthetic or independently licensed fixtures in Git. Local retail-derived captures and converted packages stay ignored.
- Performance claims require optimized measurements on the recorded M4. Do not apply unsafe operations, unchecked concurrency, forced inlining, specialization, custom allocation, streaming, or a scheduler rewrite without a measured problem and written invariant.
- Keep build products, imported content, converted content, generated packages, local captures, and dependency caches out of version control.
