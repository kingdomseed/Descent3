# Skill supply chain

- Status: accepted execution record
- Date: July 16, 2026
- Authority: installed-skill provenance, audit boundaries, and project overrides

This record covers the external skill material evaluated for the Revival workflow. [`AGENTS.md`](../../AGENTS.md), accepted contracts, and project-authored skills remain authoritative. Installation makes advice available; it does not adopt an external architecture, runtime, dependency, or process wholesale.

## Installed Apple advisory bundle

| Field | Record |
| --- | --- |
| Source | Apple [`game-porting-toolkit`](https://github.com/apple/game-porting-toolkit) |
| Commit | [`4f42344c90be22112f46becc3fb9687f423f2f88`](https://github.com/apple/game-porting-toolkit/commit/4f42344c90be22112f46becc3fb9687f423f2f88) |
| Plugin | `game-porting-skills`, version `1.0.0-beta.1` |
| License | Apache-2.0 |
| Local source | `/Users/jasonholt/skill-repos/apple-game-porting-toolkit` |
| Installation | Codex marketplace `game-porting-toolkit`; installed and enabled from the pinned local checkout |
| Executables | None in the plugin bundle; its installed content is Markdown and JSON guidance |
| Audit | Reviewed July 15, 2026 |

Allowed advisory scope is Metal 4 API shape, direct resource ownership and residency, synchronization, presentation, shader pipelines, validation, capture, and debugging. Direct Swift GameController lifecycle, feature detection, input, and haptics facts are also usable after applying the project's one input-snapshot and simulation-owner rules. The upstream recommendation to omit in-app remapping does not override the ledgered Descent control-profile, per-axis, and slide/bank mapping capability. The project-authored [`metal4-rendering`](../../.agents/skills/metal4-rendering/SKILL.md) and [`swift-realtime-systems`](../../.agents/skills/swift-realtime-systems/SKILL.md) skills narrow that advice to this product.

The following upstream areas are prohibited for Revival production: the generic porting workflow; its Objective-C++ window scaffold, `Engine*` callback boundary, and dedicated engine-thread prescription; C++ or Metal-cpp host code; Direct3D or Vulkan translation layers; Metal Shader Converter; Game Porting Toolkit runtime use; dual render backends; compatibility stubs; generic resource-manager or render-graph architecture; speculative heaps or caches; automatic MetalFX adoption; and macOS 27-only command-line GPU tools as baseline verification. Apple samples remain examples, not requirements.

Apple does not publish a separate Swift game-engine agent-skill bundle in this pinned plugin. [`swift-realtime-systems`](../../.agents/skills/swift-realtime-systems/SKILL.md) is therefore project-authored from the Xcode support matrix and release notes, Swift compiler documentation, Apple concurrency and performance guidance, and the translated source. The chosen product direction is the Swift 6.4 compiler in Swift 6 language mode from Xcode 27: use the current beta for initial product work, then replace it with stable Xcode 27 without retaining a Swift 6.3 compatibility path. Xcode 26.6 and Swift 6.3.3 describe the currently installed pre-transition environment only.

Moving the Apple pin requires a new file audit and an update to this record. Do not auto-update the marketplace checkout.

## Adapted method sources

No source in this section is installed wholesale in the repository. The project skills use original Revival-specific wording and discard incompatible language, tooling, and assumptions.

| Source | Pin and license | Useful method | Project adaptation and exclusions |
| --- | --- | --- | --- |
| Cursor [`plugins`](https://github.com/cursor/plugins) | `3fe2823ce17c1656c222d4b7c59d3f82fbf20143`; relevant Cursor Team Kit, Thermos, PR Canvas, and pstack components are MIT | high-confidence maintainability findings, deslop, behavior-preserving simplification, evidence-backed blast-radius checks, understandable PR structure | Folded into [`revival-simplify`](../../.agents/skills/revival-simplify/SKILL.md), [`revival-review`](../../.agents/skills/revival-review/SKILL.md), the PR template, and the island workflow; no TypeScript examples, arbitrary line limits, abstraction quotas, history rewrite, Canvas runtime, or companion-skill stack |
| Very Good Ventures [`vgv-wingspan`](https://github.com/VeryGoodOpenSource/vgv-wingspan) | `62b9eb07627f3f2bb9aba777e77ffe2a5729fd15`; MIT | four independent review concerns and deterministic consolidation | Adapted to source fidelity, architecture and scope, tests and evidence, and simplicity and maintainability; no Flutter standards or redundant reviewer bureaucracy |
| Matt Pocock [`skills`](https://github.com/mattpocock/skills) Wayfinder | audited checkout `e9fcdf95b402d360f90f1db8d776d5dd450f9234`; Wayfinder file last changed at `260225724133c4a204489599f04642aa089259a0`; MIT | expose unknowns and choose the next evidence-producing step | [`revival-wayfinding`](../../.agents/skills/revival-wayfinding/SKILL.md) activates only for genuinely foggy work and writes decisions back to accepted documents and ledgers; it is not a parallel plan or daily ceremony |
| Factory [`factory-plugins`](https://github.com/Factory-AI/factory-plugins) `simplify` | `e8801fa1020fbcd332c48aa068a80833bbe53e2e`; no declared repository or core-plugin license found | reuse, code-quality, and efficiency review lenses | Method reference only; no copied text, Factory task calls, React/TypeScript assumptions, automatic fixes, or speculative concurrency |
| Local `simplify-code-isomorphically` copies and public description | provenance/license insufficient for redistribution; public premium version is all-rights-reserved | prove observable behavior before deleting complexity | Principle only; no copied or reconstructed premium text, isomorphism-card bureaucracy, line-count score, macro pressure, or non-Swift gates |
| Local HumanLayer-derived subagent orchestrator | no reusable-code license recorded | bounded context isolation and parallel independent review | Adapted in [`skills-and-agents.md`](skills-and-agents.md): the root owns authority and integration, agents receive non-overlapping evidence-producing tasks, and one implementer owns a red-green-refactor contract; no mandatory delegation of every nontrivial action |
| Bun [rewrite report](https://bun.com/blog/bun-in-rust), reviewed [`PORTING.md`](https://github.com/oven-sh/bun/blob/3157cb14b5970b69532a47800504a28ef5963e22/docs/PORTING.md), [`LIFETIMES.tsv`](https://github.com/oven-sh/bun/blob/eeb4d9fdf6e9a7bdd45388d7f3a03dcf570839ad/docs/LIFETIMES.tsv), [verified claims](https://github.com/oven-sh/bun/blob/eeb4d9fdf6e9a7bdd45388d7f3a03dcf570839ad/docs/.rust-rewrite-verified-claims.md), [`46d3bc29`](https://github.com/oven-sh/bun/commit/46d3bc29f270fa881dd5730ef1549e88407701a5), and [PR 30224](https://github.com/oven-sh/bun/pull/30224) | exact linked sources; Bun repository material is MIT, while the separately authored blog is method observation only | source-cited pattern and field-lifetime tables, representative trial, compiler-error work queue, evidence progression, suspicious-workaround comments, adversarial review, and correcting the process after repeated defects | Adapted in [`revival-source-translation`](../../.agents/skills/revival-source-translation/SKILL.md); no blog text or assets, source tables, whole-repository batch size, agent quota, noncompiling draft, placeholders, unsafe allowance, knowledge-graph claim, or scripts were copied |

## Review presentation and pull requests

The existing personal PR Review Canvas is a custom installation outside this repository whose full provenance and redistribution license were not established. It remains an optional user-requested presentation tool, not a project dependency or quality gate, and no renderer, JavaScript, CDN, font, or server asset is copied here. A review must remain reproducible from the exact local diff or pushed SHA, source and capability rows, focused red/green evidence, and player/editor checkpoints.

The useful “make the PR easy to review” rule lives in [the pull-request template](../../.github/pull_request_template.md): explain the observable island first, distinguish core logic from wiring and mechanical movement, identify risks and deliberate differences, and attach exact evidence. Rewriting or force-pushing history always requires explicit user authority and proof that the resulting tree is identical.

## Audit and update rules

- Pin external sources before review and record the license at the component that supplies the material.
- Inspect every executable script, binary, dependency, network call, and telemetry behavior before project installation.
- Prefer original project-authored adaptations when an external skill carries another language, framework, platform, or product architecture.
- Keep external tools advisory. A project skill may narrow them; an external skill may not weaken an accepted rule.
- Review a domain skill against real translated source immediately before its first production use. Update one existing skill rather than stacking overlapping doctrine.
- Record a new pin and audit date before adopting an upstream change.
