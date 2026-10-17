---
name: metal4-rendering
description: Implement, review, and debug the one direct Swift + MSL Metal 4 renderer (RevivalMetal) that draws Descent 3 levels, objects, effects, terrain, and HUD for RevivalMac (and later RevivalMobile and RevivalEditor). Use for any render, shader, visibility, or GPU-lifetime work.
---

# Metal 4 rendering

Read first: `docs/revival/architecture.md` (rendering and level lifetime), `docs/revival/engineering.md`, and `docs/revival/sources.md` section 2 (visual corrections).

## Toolchain

- Xcode 27.1 release, Swift 6.4, SDK 27, and **Metal 4** (WWDC26 calls the 27-SDK additions "Metal 4.1").
- Deployment floor: macOS 26 and iOS 26. Everything in the Metal 4 core API is available on 26. Guard any 27-only API with `#available`.
- Development Mac: macOS 27 on M4. `gpucapture`, `gpudebug`, and `metalperftrace` are available here. Use them as extra evidence, and do not make them a requirement for a 26 target.
- The clamp-to-edge sampler bug (edge reads return zero) is fixed only in the 27 OS releases. Keep a test of sampler edge behavior that also runs on 26.

## Translate the original look first

1. Name the image or lifetime result you want (for example: "robots in room 3 draw with lightmap and correct blend").
2. Read the legacy path: `renderer/`, `Descent3/render.cpp`, `Descent3/postrender.cpp`, `Descent3/TerrainRender.cpp`, `model/polymodel.cpp`, the effects code, and the matching fork diffs in `sources.md`.
3. Write one failing CPU-side test for the render extraction: visibility, draw list, material choice, blend mode, sort order, or UV. Do not test Metal itself.
4. Translate the extraction faithfully, then encode it in Metal.
5. Check the frame with an Xcode GPU capture and Metal API and shader validation. On Xcode 27.1, use separate launches for capture and shader validation; `gpucapture` rejects capture while shader validation is enabled.

Keep the original order, blend modes, UVs, lightmaps, fog, clipping, and post-render sort. Adopt the corrected post-render sort: sort **all** N items by depth.

## Frame path

- AppKit (later UIKit) shells own the window, `MTKView`, and drawable. There is no platform abstraction layer.
- Core produces draw values from the resident `Level` and the live object table. The indoor path is room/portal traversal. The outdoor path is terrain LOD plus texture-segment selection.
- Use reusable `MTL4CommandBuffer` objects with an `MTL4CommandAllocator`. Submit on one `MTL4CommandQueue`.
- Pass order is a small explicit forward list: (1) lightmapped opaque world and models; (2) alpha and additive effects; (3) HUD, cockpit, and interface; (4) presentation.
- Reset an allocator only after the GPU has finished its work. Rotate frame storage only for work that is really in flight.
- Same-queue ordering is enough. Add a barrier or event only for a named hazard. Do not wait every frame.

## Ownership and lifetime

- `MTL4CommandBuffer` does **not** retain resources. The level presentation owner holds a strong reference to every resource it references.
- Attach only the residency sets the current work needs.
- Level replacement: validate the new content on the CPU, stop submissions, wait for the last GPU use of the old world, release it, then prepare the new one. A failure before that point keeps the old world. A failure after it leaves an explicit "unloaded" error state.
- Metal validation does not check retention for `MTL4CommandBuffer`. Prove lifetime with ownership, repeated load/unload tests, and captures.

## Do not add

- C++, metal-cpp, OpenGL, SDL, Shader Converter, D3D or Vulkan layers, or a backend interface.
- A render graph, resource manager, asset cache, bindless framework, ECS, or multithreaded encoding.
- Streaming, sparse or virtual textures, heaps, pipeline caches, or binary archives, unless a measured problem needs them.
- MetalFX, ray tracing, deferred lighting, bloom, or per-pixel lighting for 1.0. These are post-1.0 enhanced options (plan P5), and the original look stays the default.

## Verify

- Focused test red then green, then the render test group (commands in `engineering.md`).
- Metal API and shader validation clean for the scene you touched.
- A GPU capture of the scene: pass order, pipelines, bindings, residency, output.
- For a visual correction from a fork, compare against a retail reference capture. Record the case in a test.
- Performance claims: Release build on the M4, with validation and capture off. Record CPU extraction, encode, and GPU time. Tools: Instruments Metal System Trace, the Metal Performance HUD, and `metalperftrace` (macOS 27).
- Review by Codex, not Claude (see `engineering.md`, section 6).
- Quit any app you launched.

## Sources

- [Understanding the Metal 4 core API](https://developer.apple.com/documentation/metal/understanding-the-metal-4-core-api)
- [Metal feature set tables](https://developer.apple.com/metal/capabilities/)
- [Validating Metal API usage](https://developer.apple.com/documentation/xcode/validating-your-apps-metal-api-usage)
- [Capturing a Metal workload](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-in-xcode)
- WWDC25 [Discover Metal 4](https://developer.apple.com/videos/play/wwdc2025/205/), WWDC26 [games guide](https://developer.apple.com/wwdc26/guides/games/), and WWDC26 session 388 (performance tooling)
- [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- Apple Game Porting Toolkit `4f42344c`: advisory only (see `sources.md`).
