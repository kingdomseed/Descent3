# World streaming

- Status: accepted
- Date: July 13, 2026
- Authority: binding world-partition, resource-lifetime, and streaming contract

## Decision

Every presentation-capable player or editor level uses one purpose-built world-cell streaming path from the first native foundation. Small stock levels do not use a separate whole-level-resident path. A no-window dedicated authority loads only the resident `WorldSpine` because it has no presentation resources at all; that is not a second presentation path. Streaming is part of the canonical level model, renderer lifetime, editor diagnostics, publisher, and verification before retail import or public creator formats freeze those boundaries.

The complete authoritative gameplay spine remains resident for the life of the level. Only immutable presentation payloads stream. I/O timing, cell residency, load order, and eviction are presentation state and can never affect simulation, behavior, saves, replay hashes, or multiplayer authority.

This decision solves high-resolution replacement content and creator-authored worlds without creating an open-world engine. Levels remain finite, bounded mission spaces. Streaming removes aggregate presentation bytes from the active-memory requirement; it does not remove limits on topology, simulation state, cell size, simultaneous camera demand, discontinuous destinations, or the maximum load wave.

## Canonical partition

There is one `WorldCellID` space per level.

- One indoor room is one stream cell. The project does not add a second room-grouping or hand-authored streaming-volume system.
- Outdoor terrain is partitioned into fixed 32-by-32-quad cells at authored resolution. Native terrain dimensions are positive multiples of 32 quads; creation, resize, import, and publication reject any other dimensions. Adjacent cells derive their shared border from the same canonical heightfield so the publisher can prove a seam-free result.
- Portals and indoor/outdoor transitions form one resident adjacency graph across both cell kinds.
- Teleports, cinematic starts, respawn points, and remotely activated auxiliary cameras declare explicit destination envelopes because continuous movement cannot predict them. An editor viewport jump requests the same envelope as transient local state.

The partition is automatic and visible. Creators edit rooms and terrain, not an independent streaming graph. A room that exceeds the per-cell contract must be split. Terrain keeps its authored resolution inside each cell; there is no runtime terrain LOD hierarchy.

Every cell also stores conservative presentation-demand bounds in the resident spine. The publisher computes them as the union of the room or terrain geometry and every static cell-referenced drawable assigned to that cell, including overhanging models and decals. It proves every cell-referenced vertex or declared draw bound is finite and contained; a shared record may enlarge each referencing cell's demand bounds but still loads only once. Level-pinned dynamic items need no demand-bound expansion because they are already resident. Malformed bounds or an expansion that breaks a cell or camera-envelope cap rejects publication rather than allowing a drawable to pop in before its cell is requested.

The released source calls a room the level's basic building block and stores explicit connected-room and connected-portal identities in each portal ([room structure](../../Descent3/room_external.h)). Its terrain is a finite 256-by-256 grid and already declares a 32-by-32 texture grouping ([terrain constants](../../Descent3/terrain.h)). The native 32-by-32 stream cell is a new simple partition that divides that grid exactly; it does not preserve the historical four-level terrain LOD machinery. The historical 400-room array limit is evidence of finite mission scale, not a native constant.

## Resident gameplay spine

`RevivalCore` loads one compact `WorldSpine` before the level starts and retains it until exit. It contains:

- durable content and entity identities;
- canonical cell bounds, conservative presentation-demand bounds, room and portal topology, portal planes, and indoor/outdoor adjacency;
- collision surfaces and broad-phase data needed by authoritative movement;
- room roles, navigation connectivity, paths, spawn and transition declarations;
- object, behavior, objective, campaign, save, replay, and multiplayer state;
- the cell dependency and discontinuous-destination tables used to request presentation data.

The spine contains no Metal objects and no high-resolution presentation payloads. Its complete size and all authoritative object, behavior, timer, path, and topology counts are bounded package contracts. A creator cannot use streaming to construct an unbounded simulation.

## Streamed presentation payload

Each immutable package layer emits one raw indexed `global.stream` blob and one `levels/<level-key>/world.stream` blob for every level to which that layer contributes presentation records. `global.stream` holds stack-global records; a level blob holds its level-pinned and cell-referenced records. The blobs contain only GPU-ready buffers and texture subresources. Shared records are stored once within their scope. Structured canonical tables hold the resident spine, cells, dependencies, and resource locators; audio, movies, and other CPU-decoded media remain on their declared Apple-framework paths.

Package layering never copies untouched proprietary base bytes. Content-catalog resolution produces one immutable resolved level table. Each resolved resource locator names the contributing package layer, `global.stream` or a specific level blob, a checked byte range, and a closed project-owned buffer or two-dimensional-texture descriptor. A replacement layer contributes only its owned replacement records; unchanged locators continue to point at the read-only base layer. The runtime opens only the finite blob handles named by that resolved table. This is deterministic catalog resolution, not a virtual filesystem or runtime search path.

Each presentation record has exactly one lifetime class:

- stack-global records remain in the app residency set while their resolved player or editor content stack is active;
- level-pinned records remain in the dynamic world set for the level and include every model, animation, material, and effect that an authoritative moving or dynamically spawned render item can require;
- cell-referenced records remain while at least one desired room or terrain cell references them and cover static world and decorative presentation.

This classification is a publisher decision from complete canonical behavior and object dependencies, not a runtime guess. Behavior cannot trigger an asset request. Stack-global and level-pinned bytes and allocation counts have independent caps and are part of every active-envelope budget.

These blobs are not virtual filesystems or general archives. They have no legacy names, search path, override order, executable payload, plugin entries, or runtime format negotiation. Package data uses a closed project-owned resource descriptor rather than raw Metal option bits. One buffer record fills one whole private, hazard-tracked buffer at destination offset zero. One texture record creates one private, hazard-tracked, shader-read-only two-dimensional texture with array length and sample count equal to one; its pixel format comes from the versioned package whitelist. The descriptor declares dimensions and the complete mip count plus every level's source range, row stride, image stride, zero destination origin, and full extent. `RevivalMetal` maps these values to fixed Metal descriptors. All arithmetic and whitelist membership are checked before allocation or submission. A texture's complete mip chain installs atomically; there is no per-mip residency path, arbitrary resource option, render-target stream record, multisample record, sparse record, texture array, cube, or volume texture.

The importer or publisher computes per-record hashes and one whole-blob hash while producing each immutable blob. Intake of any external package layer first copies it into a unique app-controlled staging directory and closes the source. Every declared path must remain beneath the package root and be a regular file or directory; intake rejects symbolic links, Finder aliases, special files, escaping paths, and multiply linked staged files. It materializes each accepted file as newly owned staging bytes rather than preserving an external link. `D3Import` and editor publishers write directly to equivalent controlled staging. Intake then verifies the staged structured tables and every staged whole-blob hash with CryptoKit and atomically renames that exact verified directory into immutable storage. The bytes hashed are therefore the bytes later loaded. `WorldStreamer` verifies resolved ranges and descriptors and checks Metal I/O completion status; it does not reread final GPU payloads through the CPU or attempt a GPU hash. Per-record hashes remain deterministic construction and provenance evidence. Long-form movies and adaptive or ambient audio continue through their declared AVFoundation and AVAudioEngine paths; they do not create a second world-streaming system.

`WorldStreamer` is the one narrow runtime mechanism that owns these presentation records. It tracks the level-pinned set plus the union required by active cells, loads each shared record once, and retires a cell record after no desired cell references it and the last using GPU submission has completed. It is not an asset database, general resource manager, cache hierarchy, or public plugin API.

## Demand and lifecycle

Streaming demand is orientation-independent and uses the same spatial rule indoors and outdoors. The main owner evaluates it once per active display callback before simulation catch-up and render extraction; camera motion is suspended whenever display callbacks are suspended. Phase 1 ratifies that maximum demand-evaluation interval, one fixed render radius, one maximum supported continuous camera speed, and one prefetch-shell thickness. For every active camera anchor, `ActiveDemand` contains every cell whose conservative presentation-demand bounds intersect the render radius plus the outer prefetch shell. It ignores camera orientation and dynamic doors or occluders. The current frustum and room-and-portal traversal still decide what is drawn inside the loaded render radius; turning, rolling, or opening a door cannot create I/O demand.

The complete desired record set is:

1. the complete level-pinned presentation set;
2. the deduplicated `ActiveDemand` union for every currently live game or editor camera anchor;
3. the same complete destination envelope for each declared imminent teleport, respawn, cinematic, or remotely activated auxiliary camera.

Each authored mirror surface is a cell dependency. When its owning cell enters `ActiveDemand`, the desired set also includes that mirror camera's complete spatial envelope through the fixed supported reflection depth before the mirror can render. The publisher expands and validates this closure inside the applicable simultaneous game-camera profile, so a newly visible mirror never initiates an unbudgeted load.

An ordinary camera moves continuously. An editor viewport jump or declared remote-camera activation is a discontinuity and waits for its destination envelope. A `LoadWave` is the maximum previously nonresident record closure that can enter the outer shell between two demand evaluations for any supported simultaneous-camera profile. Let `T_wave` be the certified worst-case time for that entire wave to pass through the capped concurrent Metal I/O queue, reach the render owner, and install on the next frame. The fixed shell satisfies `prefetchShellDistance >= maximumContinuousCameraSpeed * (maximumDemandEvaluationInterval + T_wave)`. Publication rejects geometry, camera paths, or counts that violate that lead-time invariant; it never adapts the shell, changes quality, or silently stalls ordinary certified traversal.

The publisher computes a finite conservative envelope for each possible camera anchor cell. It validates every supported simultaneous game-camera profile and an editor bound equal to the level-pinned set plus the four largest independently anchored viewport envelopes plus the complete three-slice physical `DraftOverlay` allocation. Each overlay slice fits the conservative maximum visible dirty-geometry union across the supported four-viewport profile; invisible portions of a large dirty selection consume no overlay bytes. Counting cross-viewport stream-demand overlap more than once is intentional: every actual deduplicated one-, two-, or four-viewport union therefore fits. Runtime demand still deduplicates records. Play-in-editor never mixes these profiles: entering play suspends all edit viewports and replaces their demand with the supported game-camera profile on the same streamer; exit restores the exact editor viewport state and waits for its envelope before revealing it. This fixed rule is the only prefetch policy. There is no distance-quality ladder, LRU policy, memory-pressure heuristic, predictive learning, or alternate resident mode.

One asynchronous coordinator processes desired-set changes. It does not create a task per cell or asset. It owns one retained-reference `MTLIOCommandBuffer` stream from one concurrent `MTLIOCommandQueue`. Phase 1 fixes the queue's `maxCommandBufferCount`, `maxCommandsInFlight`, maximum records per command buffer, maximum bytes per command buffer, and resulting maximum submitted-stale bytes. Must-ready destination work is submitted before ordinary shell prefetch. Loading follows one lifecycle:

1. calculate the next desired cell and record union from a resident snapshot;
2. drop unsubmitted requests that no desired or pinned cell needs;
3. resolve a locator, validate its range and full descriptor, allocate its final private Metal resource, and encode `loadBuffer` or `loadTexture` on a retained command buffer;
4. commit the bounded command buffer;
5. use its completion handler and status to hand one complete success or failure result to the render owner;
6. install a complete successful batch at the next render-frame boundary;
7. retire outgoing allocations only after their final in-flight render command buffer completes.

Submitted Metal I/O command-buffer batches are not canceled. They may complete out of order; a stale completion whose desired reference count has reached zero retires without becoming render-visible. The fixed queue and command-buffer caps bound all stale submitted work. This single state transition is smaller than partial submitted-batch cancellation and retry logic.

The render owner alone changes Metal residency membership. The app residency-set object lives for the process and always contains the small fixed app-bundled loading/UI resources; its remaining membership is exactly the stack-global records of the current resolved player or key-editor content stack. The dynamic world residency set holds only the active level plus the key editor's `DraftOverlay` when applicable. `WorldStreamer` stages additions and removals, commits them at frame boundaries, and keeps resources referenced by in-flight frames alive. It does not use one residency set per cell.

Every level, content-stack, or key-document handoff uses one complete old-generation teardown. It switches to the app-bundled loading presentation, stops old presentation and simulation, closes the old generation to new submissions, and drops all queued or encoded-but-uncommitted work. It then waits for both the final old-generation render submission and every committed old-generation Metal I/O command buffer. Each delayed I/O completion is stale and installs nothing; only after it completes may the streamer retire its destination allocations and release its retained `MTLIOFileHandle`s. The render owner then clears and commits the dynamic world residency set and releases the `DraftOverlay`, level resources, `WorldSpine`, and streamer state. A content-stack switch next removes and releases the old stack-global records, loads and installs the verified new stack-global set, and only then permits a new level or key-editor viewport to activate. Old and new dynamic worlds or stack globals never overlap.

The initial level activation and every declared discontinuous transition wait for their complete required set before committing the new view. Ordinary traversal is certified by the shell lead-time inequality. Valid required work that is merely not ready makes solo, replay, or play-in-editor enter an explicit loading stall without advancing simulation ticks; a network client that cannot maintain its certified presentation envelope leaves the session with a specific streaming error rather than changing authority state.

A missing, short, unavailable, malformed, or Metal-I/O-failed required payload is terminal for that activation, never an indefinite stall. The streamer retires every partial allocation after safe final use, installs nothing from the failed batch, and presents the package layer, resource key, source-linked editor owner where available, and actionable error. An initial or staged discontinuity leaves the prior screen or stable state active because transition commit never occurred. Failure during ordinary solo or replay traversal ends that play session and returns to its prior stable application screen; play-in-editor returns to the unchanged document and last-good preview. A network client leaves with the same structured streaming error. No case falls back to legacy data, another renderer, or adaptive quality.

Stall entry clears the fixed-step accumulator, pending press and release impulses, accumulated relative mouse and scroll deltas, and held-key ramp state. While stalled, no simulation tick or input frame is produced. Readiness rebases the monotonic clock and resumes from the controls currently held; it never catches up wall-clock time or replays pre-stall impulses.

An inter-level transition uses that complete old-generation teardown, then loads the new spine and initial envelope. Only after the new required set installs does it rebase input and simulation and reveal the new level. The overlap budget below applies only to intra-level envelope changes and discontinuities; it never permits old-generation I/O, allocations, file handles, spine, overlay, or residency to survive a handoff.

## Metal implementation boundary

Metal I/O loads the publisher's raw records directly into final private Metal buffers and textures. The retained I/O command buffer's completion handler and successful status hand the batch to the render owner; only a later render frame may add it to the active world residency set, bind it, and submit first GPU use. There is no shared-event alternative and no Foundation presentation loader. Apple's [resource-loading documentation](https://developer.apple.com/documentation/metal/resource-loading) defines direct asynchronous file-to-buffer and file-to-texture loading. Apple's [`MTLResidencySet` documentation](https://developer.apple.com/documentation/metal/mtlresidencyset) defines changing a set's allocations and applying the set to a queue or command buffer.

The project deliberately does not use sparse textures or sparse heaps. They solve subtexture virtual-memory residency, while this product's natural unit is a room or fixed terrain cell; residency sets also do not support sparse resources. Coarse immutable cells require less code, keep resource failure atomic, and match the editor and portal topology.

## Finite scale and publication

Before Phase 2 freezes the canonical cell tables, the Phase 1 M4 proof ratifies versioned limits for:

- total resident `WorldSpine` bytes and topology, object, behavior, path, and cell counts;
- fixed app-bundled plus resolved stack-global GPU bytes and allocation count across the selected package layers;
- one level's level-pinned GPU bytes and allocation count;
- one indoor or terrain cell's GPU presentation bytes;
- one camera's outer spatial envelope and every supported simultaneous game-camera profile;
- the conservative four-viewport editor envelope plus all three physical `DraftOverlay` slices, each sized for that profile's maximum visible dirty-geometry union;
- one discontinuous destination envelope;
- temporary intra-level overlap while a ready envelope replaces the outgoing envelope;
- one maximum `LoadWave` record and byte closure;
- the render radius, maximum continuous camera speed, maximum demand-evaluation interval, certified `T_wave`, shell thickness, I/O queue and command-buffer caps, submitted-stale byte cap, and active-memory high-water mark on the recorded 16 GB M4.

Those numbers are measurement results, not an unresolved architecture choice. The mechanism, cell definitions, demand rule, ownership, and failure semantics are fixed now.

The player active-memory high-water calculation is fixed app-bundled plus current stack-global allocations, level-pinned allocations, supported simultaneous-game-camera demand, intra-level replacement overlap, and every in-flight I/O and submitted-stale allocation. The editor calculation substitutes its conservative four-viewport demand and adds the complete three-slice physical `DraftOverlay` allocation whether or not every byte is currently used. In the synthetic Phase 1 package, the resolved stack-global and level-pinned sets stay within their independent small caps, while the cell-referenced portion of `world.stream` is at least three times larger than the maximum resident cell-demand portion. Total package GPU bytes cannot fit under the active high-water. This prevents a false pass through whole-level retention. Publication or package intake rejects an oversized stack-global set, spine, count, level-pinned set, cell, ordinary camera envelope, simultaneous-camera profile, discontinuous destination, `LoadWave`, queue bound, or lead-time violation. It does not reject a finite level solely because aggregate on-disk presentation bytes exceed active memory.

## Editor contract

`RevivalEditor` presents a level as one continuous document. It uses the shipping `WorldStreamer` for Metal viewports and play-in-editor; it has no resident-only preview renderer. Only the key project document owns the one live streamer and dynamic world residency set. Other open documents keep their source and local UI state but pause their viewports and release presentation residency through the complete old-generation teardown before another document becomes key.

The editor's background record builder keeps exactly one last-good preview layer and one candidate in app-controlled ignored storage outside the `.revival` source package. It uses the shipping locator, table, `global.stream`, and `world.stream` schemas. A source change repacks the active level's complete project-owned GPU records and resolved table. It repacks the complete project-owned global blob when a global input changed and otherwise copies that immutable blob byte-for-byte into the self-contained candidate. Untouched proprietary base records remain external locators rather than copied bytes. The candidate carries its exact `ProjectEditGeneration` and may replace the last-good preview only when that generation still matches. The old layer remains only through final GPU use and is then deleted. Stale, cancelled, or failed candidates are deleted without changing viewports or the playable product. There is no generation chain, compactor, or preview cache hierarchy.

Live spatial editing uses one logical fixed-capacity render-owner-owned `DraftOverlay`. One preallocated Metal buffer divides it into exactly three fixed slices aligned with the renderer's three rotating frame-resource slots. Each slice fits the conservative maximum visible dirty-geometry union across all four supported editor viewports, and the complete three-slice allocation is a key-editor-only member of the dynamic world residency set and part of editor high-water and transition accounting. A slice contains only the visible portions of dirty cell or selection geometry across the live viewports; invisible portions of a large selection consume no capacity. On an edit or camera change, the render owner rebuilds the union directly from canonical values and transient gesture state into the next available slice and suppresses corresponding last-good streamed draw records by stable ID. It never writes an in-flight slice, and each slice remains immutable until its final referencing render command buffer completes. The shipping renderer draws the overlay through its normal passes; this is not a second renderer, loader, residency path, cache, or fourth frame allocation.

Pointer, drag, and scrub samples update only transient gesture state and the next available `DraftOverlay` slice; they do not mutate canonical project source, register undo, advance `ProjectEditGeneration`, or start a candidate build. Gesture commit performs exactly one concrete canonical edit, named undo registration, and generation advance, then starts one background candidate. The overlay continues to show every visible dirty record until a matching-generation candidate installs. If newer edits exist, their records remain overlaid. Gesture cancellation changes no canonical state or generation and removes only its transient draft. The overlay is noncanonical, unpersisted, contains no imported texture payload, and no slice exceeds the ratified four-viewport visible-dirty-union cap.

The editor can:

- display room and terrain cell boundaries without making them a separate authoring model;
- show desired, loading, ready, active, and retiring cells, resident-spine bytes, and exact GPU allocation costs;
- select a camera anchor, portal, outdoor transition, or discontinuity and inspect its computed render radius, prefetch shell, destination envelope, lead time, and byte cost;
- request and wait for a teleport, cinematic, auxiliary-camera, or viewport-jump destination;
- navigate a budget or seam diagnostic directly to the responsible room, terrain cell, portal, or asset;
- exercise repeated continuous motion and discontinuities at maximum supported camera speed before publication.

Current viewport positions and camera demand are local UI state. Authored gameplay or presentation transitions declare canonical destination envelopes. Streaming diagnostics never enter authoritative behavior state.

## Verification

Streaming work follows the binding red-green-refactor protocol. The production path proves:

- deterministic layered locators, cell tables, dependencies, offsets, descriptors, construction hashes, and spatial-envelope calculations;
- whole-blob CryptoKit verification before package intake plus range, descriptor, completion-status, and short-read or I/O-error checks on the direct Metal path;
- identical authoritative replay hashes under different legal I/O completion and stale-work orders;
- orientation- and dynamic-occluder-independent demand; initial load; portal and terrain traversal; teleport; cinematic; respawn; auxiliary-view; editor-viewport jump; and every supported simultaneous-camera envelope;
- batch installation only at frame boundaries and retirement only after final GPU use;
- old-generation submission cutoff and a complete committed-I/O drain whose delayed completions install nothing and whose allocations and file handles retire before any level, stack, or key-document successor begins loading;
- shared-record reference ownership without duplicate loads or early release;
- bounded out-of-order and stale completion, short read, unavailable resource, I/O error, and late-envelope failure behavior;
- package-intake corruption and hash-mismatch refusal before promotion;
- repeated churn across a synthetic package larger than the active envelope with bounded CPU/GPU memory and submitted-stale bytes;
- stall accumulator, pending-input, relative-delta, held-state, ramp, clock-rebase, and no-catch-up behavior;
- no-overlap level, content-stack, and key-document teardown, loading presentation, new-spine activation, and failure behavior;
- clean Metal validation and no use of a nonresident allocation;
- seamless fixed-resolution terrain-cell borders and no runtime LOD or sparse-resource path;
- generation-bound editor preview overlays; three-slice frame-safe reuse without in-flight overwrite; four-viewport visible-union capacity; key-document residency handoff; inspection; diagnostic navigation; playtest; and publisher refusal for each bounded failure.

Streaming completion requires release-build measurements on the recorded M4. A stock level fitting in memory is not proof because it could hide accidental whole-level retention.

## Rejected mechanisms

Do not add:

- a whole-level-resident runtime alternative;
- sparse textures, virtual texturing, mip streaming, or runtime terrain LOD;
- a general asset manager, resource graph, cache hierarchy, or memory-pressure policy;
- GPU-driven visibility or a second culling architecture;
- a CPU presentation loader, shared-event alternate path, or per-record runtime hash pass;
- streaming state queries or commands in `BehaviorGraph`;
- streaming state in saves, replays, authoritative hashes, or network messages;
- creator-authored arbitrary streaming volumes or a second cell hierarchy.

Changing one of those exclusions requires an explicit architecture amendment.
