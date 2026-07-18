# Source translation discipline

- Status: accepted, amended
- Date: July 18, 2026
- Authority: binding source-accounting and modernization protocol

## Decision

Build the native Swift and Metal product by translating the pinned Descent 3 source in dependency order, keeping a working editor-and-player path throughout. The released C++ tree is the default evidence for data flow, update order, resource dependencies, gameplay, rendering, tools, and creator workflows until the corresponding native path is understood and verified.

This is not a linked C++ migration and it is not a mechanical line-for-line rewrite. A Swift file may combine several legacy files, split one mixed-responsibility file, replace platform code with an Apple framework, or omit unreachable code. What must be complete is the accounting: no relevant source file or behavior silently disappears.

## What file-by-file means

Every legacy implementation file receives one disposition before its workstream closes:

| Disposition | Meaning |
| --- | --- |
| Translate | Preserve its reachable product semantics in native Swift or MSL. |
| Platform replacement | Preserve the capability through a named Apple framework or native application path. |
| Import only | Preserve format knowledge inside `D3Import`; do not carry the reader into the game or editor. |
| Superseded mechanism | Preserve the useful result through a smaller named native mechanism. |
| Evidence only | Keep it available to answer a bounded historical question; no production counterpart is required. |
| Exclude | Omit a dead, defective, duplicated, or out-of-scope path with recorded evidence and approval. |
| Deferred | Name the roadmap phase and dependency that prevents a current decision. Deferred is not excluded. |

The checked-in [source-translation ledger](source-translation-ledger.md) records:

- legacy path and relevant symbols;
- historical responsibility and callers;
- important global state, ordering, and dependencies;
- observable runtime or editor contracts;
- native owner and disposition;
- reference capture, fixture, or source evidence;
- deliberate semantic differences;
- focused test or other verification;
- license and provenance;
- current status.

The ledger follows the source tree, but implementation follows coherent dependency islands. Porting arbitrary files in alphabetical order would create stubs and adapters without producing a runnable system.

## Fog-of-war preflight

At the start of every roadmap phase, milestone checkpoint, dependency island, subsystem, or material code group, uncover the fog of war before finalizing the work packet or writing production code. This is a bounded attempt to falsify the plan's completeness. It is not a claim that the plan is defective and not permission for open-ended analysis.

1. Name the next observable result, fixed accepted constraints, active `current-plan.md` packet and checkpoint, source entry points, native owners, and applicable player and creator paths.
2. Trace outward through the pinned source and current native code far enough to test the proposed boundary: includes, declarations and definitions, statically resolvable calls, data and global-state access, initialization and teardown, editor callers, generated and handwritten behavior, canonical consumers, tests, and observable reference behavior.
3. Compare the result with the source ledger, functional ledger, accepted domain contract, current plan, baseline evidence, and affected verification surface.
4. Classify each candidate as a confirmed gap, a linked unknown, a risk cleared by named evidence, or irrelevant to the current result. Write confirmed facts into their existing canonical owner. Do not create a second ledger.
5. Stop when the named entry paths and evidence sources have been checked and the next observable contract is stable. Record the result, including `no new gap found` when that is what the evidence supports.

The preflight repeats when new evidence changes the known boundary, not after every file edit. One direct trace is handled in the island. Several dependent unknowns that prevent a safe contract trigger the bounded [`revival-wayfinding`](../../.agents/skills/revival-wayfinding/SKILL.md) process. A large or unfamiliar task does not trigger indefinite research by itself.

### Deterministic relationship evidence

A machine-derived relationship map may support this preflight, but it is an evidence view rather than a product subsystem, source of truth, or proof of behavioral completeness. The pinned source, accepted documents, current native code, observable evidence, and ledgers remain authoritative.

For an adopted extractor, record the pinned source revision, tool and version, compilation database or equivalent configuration, exact command, normalized output hash, and indexed versus unindexed translation-unit and build-configuration coverage. Normalize machine-specific roots without erasing semantic source locations, use compiler identities such as Clang USRs where available, and emit stable, sorted records. Two equivalent clean runs must produce byte-identical normalized output. Include only relationships the extractor can substantiate, such as file inclusion, declaration, definition, reference, statically resolved call, and proven global read or write. Mark absent translation units or build variants, macros, generated control flow, function pointers, virtual dispatch, runtime registration, aliasing, ownership, and lifetime as unknown unless the chosen analysis proves the edge. Never let a model guess a missing edge and then label it machine-derived.

Legacy-to-native edges come only from explicit ledger dispositions and named native owners. A legacy-only map can expose callers, blast radius, and missing questions; it cannot decide the Swift design or show that semantics were preserved.

Phase 0 runs one non-blocking trial on the HOG2 and Training-load island. Compare its actionable unique findings, false or unresolved edges, reproducibility, review value, run time, and maintenance cost with the existing manual trace and ledger. Keep the smallest useful normalized artifact only if it materially improves discovery or review. Otherwise record the rejection and continue with direct source tracing. Do not add a graph database, hand-maintained knowledge graph, project-wide graph-completion gate, production dependency, or requirement to map the whole legacy tree before product work.

## Dependency-island loop

Each island is the smallest end-to-end path that can become observable in every applicable shipping player shell and, where applicable, the editor:

1. perform the bounded fog-of-war preflight and refine the proposed island boundary;
2. trace the complete legacy call and data path, including editor use;
3. record the involved files and their provisional dispositions;
4. capture the observable baseline with source, fixtures, the reference executable, or a local retail level;
5. write one focused failing test for the next native contract when production behavior is about to be added;
6. translate the smallest coherent path into Swift and MSL;
7. render, play, save, or inspect it through the real product path;
8. record every intentional difference;
9. simplify the native implementation while the behavior remains protected;
10. update every involved file disposition before the island closes;
11. consolidate ordinary review, then apply the independent [`revival-completion-gate`](../../.agents/skills/revival-completion-gate/SKILL.md) once before closure, `HOLD`, additional terminal evidence, or expensive profiling.

Temporary research code may be used to learn an unknown format or behavior. It does not enter a shipping target, does not become a second product path, and is deleted or archived as evidence when the question is answered.

The project-local [revival-source-translation skill](../../.agents/skills/revival-source-translation/SKILL.md) supplies the operational trace, evidence, compiler-diagnostic, review, and closure procedure for this loop. It implements this document and cannot override it.

The [current implementation plan](current-plan.md) is the sole live record of the active island, checkpoint state and developer ownership. Update it as work advances; do not turn this source-accounting contract or its ledger into a competing task queue.

An island may reach its Mac/shared checkpoint through D3Import, shared Core and Metal, RevivalMac, and RevivalEditor where applicable before its RevivalMobile composition checkpoint closes. That open mobile checkpoint does not block starting the next Mac/shared dependency island. It does prevent any claim that the island is complete on mobile, that its overall roadmap milestone is closed, or that version 1.0 is complete. The lead work may not create a temporary Mac-only canonical model, renderer, scheduler, package schema, or lifetime path.

## Initial fidelity baseline

The production load unit is one complete canonical `Level`, matching the source D3L world boundary. In Phase 1, D3Import converts the complete Training D3L; RevivalMac and RevivalEditor first load the resulting complete canonical `Level`, and RevivalMobile then composes that same proven load path. One selected room remains the first visible and editable acceptance slice. Synthetic one-room levels are focused fixtures, not a production package or alternate world type.

The first implementation preserves the source-derived world, loading, visibility, timing, and campaign relationships below. It composes them through the approved native player and editor shells without treating that shell composition as historical evidence:

- one complete resident authoritative level world containing its rooms, portals, terrain, objects, paths, goals, and behavior state;
- one eager `PageInAllData`-style working-set pass, reachable later asset paging, and one level-owned release at exit;
- the same canonical world model, dependency rules and direct Metal renderer in `RevivalMac`, `RevivalMobile` and `RevivalEditor`, without concurrent mutation of one instance;
- one editor-hosted open, inspect, edit, save, play, and return loop;
- room-and-portal visibility in the first indoor island, followed by terrain geometry LOD and texture-segment selection with UV/tile/rotation behavior when the first outdoor island arrives;
- the source timing handoff made explicit: systems and `EVT_INTERVAL` consume the old `Frametime` and pre-update `Gametime`, then after cap waiting `CalcFrameTime` stores the new duration and `GameFrame` advances `Gametime` before remaining tail work; static/`InitGame` initialization is 0.1 seconds and nested pauses rebase the clock;
- campaign-ordered translation of the real Training dependencies rather than a speculative engine framework.

The canonical package contains the complete level topology and every dependency reachable through the currently translated product path. When a later phase makes a matcen, dynamic spawn, or behavior path executable, the importer and manifest expand with that same island. This preserves the one-way content boundary without demanding Phase 4 behavior reachability analysis in Phase 1. Source inspection still shows reachable lazy paging, and the retained GPU pre-upload hook does not establish complete GPU readiness before activation.

UIKit scene composition, mobile document-picker intake, virtual controls, audio-session handling and mobile lifecycle recovery are deliberate platform replacements with no legacy-file fidelity claim. They attach target-specific evidence to the applicable functional contract while the underlying source-derived world, simulation, renderer, scheduler and package semantics remain one implementation. AppKit and UIKit entry points do not create separate source-disposition tracks or justify a generic platform layer.

This baseline is resident per complete level. Phase 5 completes Training as a playable and editable mission; it does not introduce a second, fuller Level type. The baseline is neither a claim that streaming will never be useful nor permission to implement streaming in parallel. The current product has one resident loading path. A different resource-lifetime design requires the measured amendment described in [World loading and residency](world-loading.md), and the replacement must leave one production path.

## What does not transfer

Do not preserve a mechanism solely because it exists in the tree. In particular:

- MFC, Win32, DirectX, SDL, OpenGL, DLL loading, and native Osiris ABI;
- editor and game compile variants, global `Function_mode` ownership, or duplicated compilation of runtime files;
- the page database's network locks and check-in/check-out UI;
- legacy memory wrappers, fixed-array accidents, upload caches, and platform-specific defensive branches;
- original save, demo, packet, HOG output, D3L output, or backward editor compatibility;
- editor-to-game sleep, window teardown, or temporary-file workarounds;
- unreachable stubs, abandoned backends, historical bugs, and duplicated tools.

Boundary validation happens once when untrusted retail, project, package, save, or network data becomes canonical. Trusted internal code should not repeat defensive checks that canonical construction already guarantees.

## Modernization rule

Modernization is a separate, explicit step:

1. get the translated path working;
2. measure it in an optimized build on every recorded development device affected by the change, with representative content, and add selected release-floor devices only when the change supports a public floor claim;
3. identify the specific missed budget, maintenance problem, or Apple-platform opportunity;
4. record a local structural change in the translation ledger, or amend the binding documents when changing a product decision, persistent semantic contract, or cross-workstream architecture;
5. add the focused contract or measurement that fails;
6. replace the old mechanism and delete the superseded production path;
7. remeasure and retain the change only when the evidence supports it.

Do not mix a redesign into a translation and then describe the result as fidelity. Do not retain permanent legacy and modern modes. Future hypotheses do not justify current machinery, but canonical semantics must not encode an unnecessary assumption about presentation lifetime or editor implementation.

## Historical process lesson

Descent 3 was not built by finishing an editor and then implementing the game. The editor and runtime were co-developed, and designers built rooms to exercise an evolving room engine. The practical lesson is an early shared editor/runtime loop, representative content as design evidence, and stabilization of each proven slice before content scales—not literal reenactment of the 1997 source order.
