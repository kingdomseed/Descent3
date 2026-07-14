# Source translation discipline

- Status: accepted
- Date: July 14, 2026
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

## Dependency-island loop

Each island is the smallest end-to-end path that can become observable in both the player and editor where applicable:

1. trace the complete legacy call and data path, including editor use;
2. record the involved files and their provisional dispositions;
3. capture the observable baseline with source, fixtures, the reference executable, or a local retail level;
4. write one focused failing test for the next native contract when production behavior is about to be added;
5. translate the smallest coherent path into Swift and MSL;
6. render, play, save, or inspect it through the real product path;
7. record every intentional difference;
8. simplify the native implementation while the behavior remains protected;
9. update every involved file disposition before the island closes.

Temporary research code may be used to learn an unknown format or behavior. It does not enter a shipping target, does not become a second product path, and is deleted or archived as evidence when the question is answered.

## Initial fidelity baseline

The production load unit is one complete canonical level, matching the source D3L world boundary. Phase 1 imports and loads the complete Training level while using one selected room as its first visible and editable acceptance slice. Synthetic one-room levels are focused fixtures, not a production package or alternate world type.

The first implementation reproduces these source-supported relationships:

- one complete resident authoritative level world containing its rooms, portals, terrain, objects, paths, goals, and behavior state;
- one eager `PageInAllData`-style working-set pass, reachable later asset paging, and one level-owned release at exit;
- the same canonical world model, dependency rules, and direct Metal renderer in `RevivalMac` and `RevivalEditor`, without concurrent mutation of one instance;
- one editor-hosted open, inspect, edit, save, play, and return loop;
- room-and-portal visibility in the first indoor island, followed by terrain geometry LOD and texture-segment selection with UV/tile/rotation behavior when the first outdoor island arrives;
- the source timing handoff made explicit: systems and `EVT_INTERVAL` consume the old `Frametime` and `Gametime`, then after cap waiting `CalcFrameTime` stores the new duration and `GameFrame` advances `Gametime` before remaining tail work; static/`InitGame` initialization is 0.1 seconds and nested pauses rebase the clock;
- campaign-ordered translation of the real Training dependencies rather than a speculative engine framework.

The canonical package contains the complete level topology and every dependency reachable through the currently translated product path. When a later phase makes a matcen, dynamic spawn, or behavior path executable, the importer and manifest expand with that same island. This preserves the one-way content boundary without demanding Phase 4 behavior reachability analysis in Phase 1. Source inspection still shows reachable lazy paging, and the retained GPU pre-upload hook does not establish complete GPU readiness before activation.

This baseline is resident per complete level. Phase 5 completes Training as a playable and editable mission; it does not introduce a second, fuller Level type. The baseline is neither a claim that streaming will never be useful nor permission to implement streaming in parallel. The current product has one resident loading path. A different resource-lifetime design requires the measured amendment described in [World loading and residency](world-streaming.md), and the replacement must leave one production path.

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
2. measure it in an optimized build on the recorded M4 with representative content;
3. identify the specific missed budget, maintenance problem, or Apple-platform opportunity;
4. record a local structural change in the translation ledger, or amend the binding documents when changing a product decision, persistent semantic contract, or cross-workstream architecture;
5. add the focused contract or measurement that fails;
6. replace the old mechanism and delete the superseded production path;
7. remeasure and retain the change only when the evidence supports it.

Do not mix a redesign into a translation and then describe the result as fidelity. Do not retain permanent legacy and modern modes. Future hypotheses do not justify current machinery, but canonical semantics must not encode an unnecessary assumption about presentation lifetime or editor implementation.

## Historical process lesson

Descent 3 was not built by finishing an editor and then implementing the game. The editor and runtime were co-developed, and designers built rooms to exercise an evolving room engine. The practical lesson is an early shared editor/runtime loop, representative content as design evidence, and stabilization of each proven slice before content scales—not literal reenactment of the 1997 source order.
