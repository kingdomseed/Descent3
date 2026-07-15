# Primary technical source index

- Status: maintained reference index
- Last checked: July 15, 2026
- Authority: non-normative evidence routing; binding decisions remain in the accepted project documents

## Purpose

Start here before repeating web research for a technical question the project has already investigated. This index keeps the primary sources that materially informed current decisions, states what each source is useful for, and records the limit on what it proves.

This is not a general bibliography. Add a source when it answers a real project question or supports a current implementation method. Prefer an official specification, documentation page, release note, source repository, or first-person engineering account over summaries. A case study supplies evidence and method; it does not become a Revival performance target or architecture rule.

## Project-local evidence indexes

| Question | Start here |
| --- | --- |
| What did the released game and editor actually do? | [Historical discovery](discovery.md) and the pinned local source tree |
| Which legacy files and symbols remain unaccounted for? | [Source translation ledger](source-translation-ledger.md) |
| Which player and creator capabilities remain incomplete? | [Functional completeness ledger](functional-completeness-ledger.md) |
| Which external skills and process sources were installed or adapted? | [Skill supply chain](skill-supply-chain.md) |
| Which retail inputs and hashes were verified? | [Retail data and provenance](retail-data.md) |
| Which measurements can support a product claim? | [Verification](verification.md) |

## Apple toolchain baseline

| Primary source | Use in this project | Limit |
| --- | --- | --- |
| Apple [Xcode support matrix](https://developer.apple.com/support/xcode) | Map Xcode, SDK, Swift compiler, language mode, host OS, and deployment support | Recheck when the selected Xcode release changes |
| Apple [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes) | Identify toolchain and SDK changes that affect the current native baseline | Availability does not create a feature requirement |
| Apple [What's new in Swift 6.4](https://developer.apple.com/swift/whats-new/) | Locate current ownership, iteration, specialization, diagnostics, and language changes | Use a feature only when it simplifies a real contract or measured hot path |

## Swift engine code and performance

| Primary source | Use in this project | Limit |
| --- | --- | --- |
| Swift.org [Swift compiler architecture](https://www.swift.org/documentation/swift-compiler/) | Establish the native compilation path through Swift-specific SIL optimization and LLVM machine-code generation | A shared backend does not guarantee identical generated code or performance |
| Apple [Explore Swift performance](https://developer.apple.com/videos/play/wwdc2024/10217/) | Understand calls, representation, heap allocation, ownership, copying, closures, and generic specialization | Diagnose a measured path; do not ban a language feature globally |
| Apple [Improve memory usage and performance with Swift](https://developer.apple.com/videos/play/wwdc2025/312/) | Profile algorithms, allocations, exclusivity, reference counting, `InlineArray`, and `Span` in that order | The example parser and its gains are not a game-engine prediction |
| Swift compiler [PerformanceHints diagnostics](https://docs.swift.org/compiler/documentation/diagnostics/performance-hints/) | Find possible existential dispatch, implicit collection copies, and other hidden costs during focused investigation | Warnings are leads, not failures or project-wide style rules |
| Apple [Array](https://developer.apple.com/documentation/swift/array) and [ContiguousArray](https://developer.apple.com/documentation/swift/contiguousarray) documentation | Confirm copy-on-write and contiguous-storage behavior when selecting concrete storage | Documentation describes semantics; the optimized product path still requires measurement |
| Swift.org [Migrating the TrueType hinting interpreter to Swift](https://www.swift.org/blog/migrating-truetype-hinting-to-swift/) | Production evidence that source-equivalent, low-level C work can move to Swift through corpus tests, direct ownership, and profile-guided optimization | Method evidence only; its workload, bridge, unsafe regions, and result do not predict Revival |
| Swift.org [Porting Graphing Calculator from C++ to Swift](https://www.swift.org/blog/graphing-calculator/) | First-person evidence that a substantial C++ application can move to Swift while retaining useful performance, plus a concrete warning about ARC in tree traversal | One application account, not a controlled language benchmark or real-time game result |

The question these sources answer is whether Swift is credible for simulation, collision, AI, visibility, render extraction, and other CPU engine code. They support that feasibility. Only optimized Revival measurements on representative M4 workloads can establish this product's budgets.

## Metal 4 and game profiling

| Primary source | Use in this project | Limit |
| --- | --- | --- |
| Apple [Understanding the Metal 4 core API](https://developer.apple.com/documentation/metal/understanding-the-metal-4-core-api) and [Drawing a triangle with Metal 4](https://developer.apple.com/documentation/metal/drawing-a-triangle-with-metal-4) | Establish the direct queue, allocator, encoder, resource, submission, and presentation shape | API shape does not require a render graph, resource manager, or compatibility backend |
| Apple [Metal feature set tables](https://developer.apple.com/metal/capabilities/) | Verify hardware and OS availability before using a Metal feature | Capability is not evidence that the feature belongs in the design |
| Apple [Discover Metal 4](https://developer.apple.com/videos/play/wwdc2025/205/) | Understand the Metal 4 programming model and migration of direct API concepts | Do not import C++, Metal-cpp, or cross-API porting architecture |
| Apple [Analyzing the performance of a Metal app](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/) and [Metal developer tools](https://developer.apple.com/metal/tools/) | Separate CPU, GPU, scheduling, resource, and presentation causes with Instruments and Metal System Trace | Tool output supports a recorded workload; it does not supply universal budgets |
| Apple [Validating Metal API usage](https://developer.apple.com/documentation/xcode/validating-your-apps-metal-api-usage), [capturing a Metal workload](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-in-xcode), and [analyzing a Metal workload](https://developer.apple.com/documentation/xcode/analyzing-your-metal-workload) | Verify direct API correctness and inspect the submitted workload | A clean validation run proves API correctness, not image fidelity or frame-time headroom |
| Apple Game Porting Toolkit [`4f42344c`](https://github.com/apple/game-porting-toolkit/commit/4f42344c90be22112f46becc3fb9687f423f2f88) | Pinned advisory index for Metal 4, GameController, validation, capture, and debugging documentation | The project does not adopt its C++, Metal-cpp, Shader Converter, D3D/Vulkan, compatibility-runtime, or generic porting paths |

## Translation process and historical product evidence

| Primary source | Use in this project | Limit |
| --- | --- | --- |
| Descent Developers [Descent 3 source at `156cba8a`](https://github.com/DescentDevelopers/Descent3/commit/156cba8aafd997d27deb0902ba6026bcdcc1cfaf), pinned locally at the same commit | Default evidence for original data flow, ordering, behavior, presentation, and creator workflows | GPL source is a translation specification, not the native product architecture |
| [October 1999 Descent 3 postmortem](https://media.gdcvault.com/GD_Mag_Archives/GDM_October_1999.pdf) | Historical evidence for engine/editor/content churn, tool fragmentation, and stabilization lessons | A retrospective does not override verified source behavior or current product decisions |
| Jarred Sumner [Rewriting Bun in Rust](https://bun.com/blog/bun-in-rust), Bun [`46d3bc29`](https://github.com/oven-sh/bun/commit/46d3bc29f270fa881dd5730ef1549e88407701a5), and [PR 30224](https://github.com/oven-sh/bun/pull/30224) | Representative trial, compiler-error work queue, suspicious-workaround comments, evidence progression, and correcting process after defects | Process evidence only; no batch size, unsafe allowance, module layout, or whole-repository strategy transfers automatically |

## Maintenance

- Record the date when a link or its technical conclusion is rechecked.
- Link the stable source page or pinned commit, not a search result.
- State the project question and the source's limit; do not save a naked URL.
- Keep executable tools and skill bundles pinned in [Skill supply chain](skill-supply-chain.md).
- Add later networking, replay, behavior, media, security, and operations sources when those workstreams review them against working native code. Do not pre-decide those domains through an oversized Phase 0 bibliography.
