# World loading and residency

- Status: accepted, amended
- Date: July 16, 2026
- Authority: binding current resource-lifetime decision and modernization gate

## Current decision

The production load unit is one complete canonical `Level`, matching the source D3L world boundary. In Phase 1, D3Import converts the complete Training D3L; RevivalMac and RevivalEditor first load the resulting complete canonical `Level`, and RevivalMobile then composes that same proven load path. One selected room is the first visible and editable acceptance slice, not a partial production level. Synthetic one-room levels remain focused test fixtures.

This document owns the lifetime contract. The active slice, checkpoint state and developer ownership live in the [current implementation plan](current-plan.md) and are updated there. Mac/shared loading and editor work leads; an open mobile composition checkpoint does not block the next Mac/shared dependency island, but it does block the applicable overall milestone and version 1.0. The shared canonical, renderer and lifetime contracts must remain mobile-composable while that checkpoint is open.

The initial native products keep each authoritative level world resident until exit. Startup eagerly prepares the source-evidenced `PageInAllData` working set. If object initialization, a matcen, translated behavior, or another reachable source path later needs a canonical presentation asset, the product prepares it directly from canonical content and retains it for the rest of the level. RevivalMac and RevivalMobile each own a separate player world. RevivalEditor owns a separate document value and creates a separate disposable play-session value. All three applications use the same model, dependency rules, renderer and resource-loading path.

This reproduces the useful shape of the released engine without overstating it. `PageInAllData` walks the ship, static effects and sounds, room textures, terrain presentation, and placed-object dependencies, but bitmap access, object initialization, matcens, and Osiris paths can page more data later. The retained GPU pre-upload hook is a no-op, so the original did not prove complete GPU readiness before activation. The native package contains the complete level topology and every dependency reachable through the currently translated product path; it expands with later dependency islands rather than pretending future behavior reachability is known in Phase 1. The preparation schedule remains source-faithful until evidence supports changing it.

Streaming is neither prohibited forever nor implemented now. The project does not add cells, prefetch envelopes, a residency graph, a streaming schema, or alternate resident and streamed modes in anticipation of a future problem.

## Resident world contract

Loading follows one direct lifecycle:

1. D3Import or the native publisher produces one checked complete canonical Level plus the assets reachable through the currently translated product path.
2. The application validates the successor's manifest and structural CPU content while the current world, if any, remains active. This validation does not create a second complete Metal set.
3. At the commit boundary, new submissions stop, the last old-world GPU use completes, and one owner releases the old presentation resources and file handles.
4. RevivalCore constructs the successor's simulation or authoring values.
5. RevivalMetal prepares the source-evidenced eager working set, and the application activates the world.
6. Later source-reachable presentation requests resolve directly from canonical content included when that product path was translated and remain owned by that level until exit. They do not reopen retail formats or change authoritative simulation state.
7. Player and editor viewports draw through the same path. Room/portal and terrain visibility decide what is drawn, not which authoritative world values exist.
8. Exit and document replacement use the same drain-and-release boundary.

A failure before the commit boundary leaves the prior stable state intact. A failure after commit leaves an explicit unloaded/error state with a source-linked diagnostic; the loader does not keep two complete GPU worlds resident merely to make replacement transactional. There is no fallback to retail data, another renderer, or a partially activated level.

Loading may use one bounded background operation when measured I/O latency would otherwise make the application unresponsive. Do not create a task per asset, a general loader framework, or partial authoritative-world activation.

## Visibility and terrain

Loading, visibility, and geometric detail are separate questions.

- Indoor rendering initially translates the released room-and-portal traversal and its observable clipping behavior into direct Metal.
- When the first outdoor dependency island arrives, outdoor rendering translates released geometry LOD plus texture-segment selection and UV/tile/rotation behavior closely enough to establish reference images and measurements on the recorded Mac and mobile devices.
- Editor viewports use those same paths.

The source has a 32-by-32 `Terrain_tex_seg` grid whose entries each cover an 8-by-8 terrain-cell block. Do not reinterpret that texture grouping as proof of a modern streaming partition or call editor megacells a runtime LOD system. Do not remove geometry LOD merely because modern Apple devices are faster; first reproduce the visual and performance baseline, then record a deliberate simplification if full authored resolution is measurably safe and visually accepted on every affected target.

## Editor contract

The first editor world path is deliberately small:

- derive an editable complete-level project value from the read-only canonical base and load it through the same world model as the player;
- inspect and select rooms, faces, portals, terrain, and objects;
- make one canonical edit with named undo and redo;
- save, close, and reopen the native project;
- enter the shipping simulation and renderer with a disposable play-session copy rather than sharing one mutable instance;
- return to the same document and useful view state.

The editor may update changed preview geometry directly while editing. It does not require a generated preview package, fixed overlay-slice count, streaming diagnostics, background-document residency handoff, or candidate-cache protocol before real editing demonstrates that need.

When a real background bake, import, or publish operation first appears, its immutable input and stale-result rule are specified for that operation. Do not build a universal job or revision framework in advance.

## Mac, mobile-development and release-floor evidence gate

After the complete Training Mission is playable and editable, measure the Mac/shared path in an optimized build on the recorded M4 Mac. When the corresponding mobile composition exists, run the applicable development matrix on the physical iPhone and iPad recorded in the [current implementation plan](current-plan.md). Before a public beta or release claims the candidate Apple GPU family 7 floor, repeat the applicable matrix on selected representative floor iPhone and iPad devices; if those devices are unavailable or fail, raise the released floor to the oldest hardware actually verified. The absence of exact floor devices does not hold later Mac/shared islands open.

Use:

- startup and level-transition time;
- peak and steady CPU, GPU, and unified memory;
- the complete Training Mission and the largest imported indoor and outdoor levels then available;
- repeated load, restart, editor play, and return cycles;
- repeated mobile foreground, background, interruption, memory-warning and resume cycles;
- one representative high-resolution replacement-content experiment;
- one-, two-, and four-viewport editor use if those layouts have shipped by the gate.

Record content hashes, build settings, OS, Xcode and exact device models, presentation settings, thermal state, and Instruments or Metal evidence. The result must distinguish aggregate level size, eager working-set size, later lazy preparations, temporary load duplication, Metal allocation cost, decoding time, visibility cost and mobile lifecycle cost.

The resident design remains the implementation when it meets ratified startup, responsiveness, and memory budgets. Missing a budget does not automatically authorize a general streamer.

## Amendment rule

A resource-lifetime amendment must name:

- the measured scenario and missed budget;
- the smallest resource class that must stop being resident;
- why simpler changes such as encoding, duplicate removal, load ordering, or level-boundary preparation are insufficient;
- the proposed ownership, failure, editor, and verification contracts;
- the native data that remains unchanged;
- the resident mechanism and tests that will be deleted when the replacement ships.

The amendment chooses one implementation. It may introduce coarse spatial streaming, but it may not preserve both a resident and streamed production path, generalize into an asset manager, or expose presentation residency to simulation, behaviors, saves, replay, or multiplayer authority.

## Verification

The resident path proves:

- complete level topology plus every dependency reachable through the currently translated product path;
- source-accounted eager working-set preparation plus reachable canonical lazy preparation;
- identical Mac player, mobile player and editor resource resolution;
- room/portal and terrain visibility independent of load order;
- pre-commit failure preserves the current world and post-commit failure enters an explicit unloaded state;
- no partially activated authoritative world;
- repeated load, restart, editor play, return, and level replacement without unbounded memory growth;
- final-GPU-use safety before release;
- no retail-format reads outside D3Import;
- no second renderer or resource-lifetime path;
- release-build M4 Mac evidence for each applicable Mac/shared checkpoint, recorded available physical-device evidence for mobile development checkpoints, and selected floor-device startup and memory evidence before a public beta or release claims that floor.

These checks protect the current product. They do not add tests for a hypothetical streamer.

## Rejected current mechanisms

Until the evidence gate produces an accepted amendment, do not add:

- world stream cells, camera-demand envelopes, prefetch shells, or LoadWave calculations;
- global.stream / world.stream schemas or stack-global, level-pinned, and cell-referenced lifetime classes;
- an LRU, partial-eviction memory-pressure policy, sparse resources, virtual texturing, or mip streaming;
- a general asset manager, cache hierarchy, or resource graph;
- GPU-driven visibility or a second culling architecture;
- a resident/streaming feature flag or parallel loader;
- editor-only loading or rendering machinery.

These are current exclusions against speculative complexity, not claims that no future measurement could justify a focused replacement.

An iOS or iPadOS memory warning does not authorize partial eviction or an alternate mobile residency mode. If the ordinary resident world cannot remain valid, the application uses the same drain-and-release boundary and enters an explicit unloaded or recoverable error state; an evidence-backed amendment is required to introduce any narrower resource release.
