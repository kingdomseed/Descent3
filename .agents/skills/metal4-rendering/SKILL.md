---
name: metal4-rendering
description: Implement, review, and verify the one direct Swift and MSL Metal 4 renderer, complete-Level presentation lifetime, source-faithful visibility, and final-GPU-use release for RevivalMac, RevivalMobile, and RevivalEditor.
---

# Metal 4 rendering

Build the smallest real Metal 4 path that transfers the current Descent 3 visual contract into the Mac player, universal iPhone and iPad player, and editor. Preserve source-evidenced results and lifetime; do not preserve a legacy graphics API or prebuild a modern engine framework.

## Authority and required reading

This skill implements, and cannot amend:

- [`AGENTS.md`](../../../AGENTS.md)
- [`docs/revival/architecture.md`](../../../docs/revival/architecture.md)
- [`docs/revival/source-translation.md`](../../../docs/revival/source-translation.md)
- [`docs/revival/source-translation-ledger.md`](../../../docs/revival/source-translation-ledger.md)
- [`docs/revival/engineering-principles.md`](../../../docs/revival/engineering-principles.md)
- [`docs/revival/test-driven-development.md`](../../../docs/revival/test-driven-development.md)
- [`docs/revival/world-loading.md`](../../../docs/revival/world-loading.md)
- [`docs/revival/roadmap.md`](../../../docs/revival/roadmap.md)
- [`docs/revival/verification.md`](../../../docs/revival/verification.md)

The current direction is an arm64 macOS 26+ player and editor plus a Metal 4 iOS/iPadOS 26+ player on Apple GPU family 7 or newer, using direct Swift 6.4 and MSL from Xcode 27. Use the current beta until stable Xcode 27 replaces it. A conflicting skill, sample, or available API does not change that baseline.

## Start from an observable render island

Before production code:

1. Name the player and editor image or lifetime result that will become real.
2. Trace the legacy visibility, draw extraction, state, asset preparation, and teardown path; add every involved file and important symbol to the source-translation ledger.
3. Capture the source or reference image, ordering, material state, and eager-versus-lazy dependency evidence.
4. Write one focused project-owned test and observe the intended red before implementation. Test extraction, visibility, material choice, pass order, bounds, a controlled shader result, or a controlled image—not Metal itself.
5. Translate only the passes and resources required by that result.

Phase 1 loads one complete canonical `Level` and renders one selected room in RevivalMac, RevivalMobile, and RevivalEditor as its acceptance view. The selected room never becomes a partial production `Level`, room package, alternate loader, platform-specific loader, or editor-only renderer.

## Smallest real frame path

Use one concrete RevivalMetal implementation shared by separately owned Mac-player, mobile-player, editor-document, and editor-play-session values:

1. Concrete AppKit and UIKit shells each own their window or scene, `MTKView`, drawable sizing, and presentation callback. Do not insert a generic platform, view, input, or filesystem layer between those shells and RevivalMetal.
2. Direct Swift functions extract the current visible draw values from the canonical resident `Level` using the source-evidenced room/portal traversal.
3. Begin a reusable `MTL4CommandBuffer` with an eligible `MTL4CommandAllocator`.
4. Encode the current explicit forward pass with project MSL and the smallest known pipeline set.
5. Bind only resources the pass uses, satisfy their Metal 4 residency contract, present the drawable, end encoding, and commit through the direct `MTL4CommandQueue`.
6. Reuse command buffers as the API permits. Reset or reuse an allocator and its frame storage only after the GPU has finished the work backed by them.

Add alpha/additive, HUD/cockpit, presentation, mirrors, specular faces, decals, procedural surfaces, volumetric lighting, animation, and terrain only when the current source dependency island reaches them. Preserve observable blend, UV, lightmap, clipping, and draw order before deliberate modernization.

## Ownership, residency, and synchronization

- One loaded-level presentation owner strongly owns every referenced Metal resource because `MTL4CommandBuffer` does not retain resource references.
- Attach the smallest residency set required by the resources referenced by the current command buffer or queue. Do not turn residency into an asset database, graph, cache hierarchy, or simulation-visible state.
- Use rotating allocators or frame values only for work that can actually remain in flight. Derive the count from the submission contract; do not install an arbitrary triple-buffer framework.
- Same-queue ordering is enough unless the current producer/consumer relationship crosses that guarantee. Add a barrier, event, wait, or another synchronization primitive only with the exact hazard it resolves.
- Do not wait every frame merely because GPU work is asynchronous. Wait at a real CPU/GPU ownership boundary or measured hazard.
- For level replacement, validate successor CPU content before commit. Then stop old submissions, wait for final old-world GPU use, release the old presentation owner, and prepare the successor. Pre-commit failure preserves the old world; post-commit failure leaves the explicit unloaded state.
- Later source-reachable assets prepare only from canonical content and remain owned by the level until exit. They never reopen retail formats.

Metal API Validation's unretained-resource check covers `MTLCommandBuffer`, not `MTL4CommandBuffer`. Do not cite a clean validation log as proof of Metal 4 lifetime. Prove lifetime with direct ownership, the drain-and-release contract, repeated replacement tests, and captures.

## Keep one direct renderer

Reject:

- C, C++, Objective-C++, metal-cpp, HLSL, Direct3D, Vulkan, Metal Shader Converter, OpenGL, SDL, GPTK runtime code, or a backend interface;
- a render graph, generic renderer protocol, resource manager, asset manager, bindless scene framework, ECS, job system, or multithreaded encoder plan;
- a second editor renderer, compatibility renderer, fallback renderer, or resident/streaming flag;
- speculative world cells, sparse resources, virtual textures, LRU policy, heaps, upload or pipeline caches, binary archives, pipeline datasets, or background task per asset;
- speculative MetalFX, ray tracing, GPU-driven culling, deferred lighting, frame interpolation, or a second visibility path;
- a fixed frame-resource count, synchronization primitive, residency taxonomy, or memory-pressure mechanism without the current API contract or measured problem.

The `gpucapture` and `gpudebug` command-line tools require macOS 27 and are not baseline verification for a macOS 26+ product. Use Xcode GPU capture, the Metal debugger, `MTLCaptureManager` when a real automated capture needs it, and Instruments Metal System Trace; those command-line tools may supply supplementary evidence on a recorded macOS 27 machine without raising the deployment target.

## Verification

For each render contract:

- record focused red, focused green, and the directly affected suite using exact direct commands;
- run with Metal API Validation and Shader Validation as applicable, and report every warning or error;
- capture the controlled frame in Xcode and inspect pass order, pipelines, bindings, residency, output, and the resource lifetime relevant to the claim;
- record fixed-image environment, content identity, resolution, settings, SDK, compiler, GPU, and threshold; never regenerate baselines automatically;
- repeat load, editor play/return, replacement, and shutdown to expose unbounded CPU/GPU memory or final-use faults;
- exercise RevivalMobile on the recorded physical minimum supported iPhone and iPad across drawable resize, safe-area and landscape layout, scene interruption and resume, memory pressure, and thermal changes that apply to the current contract; a simulator does not close those claims;
- profile optimized builds on the recorded M4 and applicable physical minimum supported iPhone and iPad with validation and capture overhead disabled, recording CPU extraction, encoding, GPU time, allocation, unified-memory evidence, device state, and thermal conditions.

Run `rtk git diff --check` for every change. Once targets exist, use the exact focused `rtk swift test` or `rtk xcodebuild` invocation and record what it proves; do not invent a generic scheme or hide results behind an automation summary.

## Primary sources and advisory upstream

- Apple, [Understanding the Metal 4 core API](https://developer.apple.com/documentation/metal/understanding-the-metal-4-core-api)
- Apple, [Drawing a triangle with Metal 4](https://developer.apple.com/documentation/metal/drawing-a-triangle-with-metal-4)
- Apple, [Metal Feature Set Tables](https://developer.apple.com/metal/capabilities/)
- Apple, [Validating your app's Metal API usage](https://developer.apple.com/documentation/xcode/validating-your-apps-metal-api-usage) and [shader usage](https://developer.apple.com/documentation/xcode/validating-your-apps-metal-shader-usage)
- Apple, [Capturing](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-in-xcode) and [analyzing](https://developer.apple.com/documentation/xcode/analyzing-your-metal-workload) a Metal workload
- Apple, [Discover Metal 4](https://developer.apple.com/videos/play/wwdc2025/205/)
- Apple Game Porting Toolkit commit [`4f42344c90be22112f46becc3fb9687f423f2f88`](https://github.com/apple/game-porting-toolkit/commit/4f42344c90be22112f46becc3fb9687f423f2f88) is pinned advisory upstream for Metal 4 API, validation, capture, GameController, and debugging research. Its Markdown/JSON skill bundle is installed and may be read. No upstream executable, sample, runtime source, metal-cpp code, Shader Converter path, D3D/Vulkan mapping, cache, heap, or MetalFX path is imported into the repository or run as part of production. macOS 27 GPU command-line tools may provide separately recorded supplementary evidence as described above; they are not baseline execution.
