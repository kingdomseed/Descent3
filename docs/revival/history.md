# History

Status: record only. Written 2026-09-29.

## First attempt (2026-07-12 to 2026-08-12)

- The first attempt ran as an experiment with OpenAI Codex (mainly GPT-5.6 Sol). One root orchestrator session (`019f66e3…`) drove about 1,400 Codex sessions: selectors, writers, reviewers, and helpers. Transcripts are in `~/.codex/sessions/2026/07–08/` and `~/.codex/archived_sessions/`.
- The result was 112 commits on top of upstream `156cba8a`, on branch `codex/macos-metal-discovery`. The last product commit is `24701a09`. The last commit overall is `e73d4408` (an `AGENTS.md` cleanup, 2026-09-12).
- It closed old phases 0–4 and part of phase 5:
  - D3Import: the HOG2 parser, complete Training D3L import, and an atomic package.
  - The Metal 4 indoor renderer.
  - Flight, collision, and the ratified timing contract.
  - A playable Training mission with Guide-Bot.
  - Pause, a text HUD, quicksave, F1 help, and pilot profiles.
  - Editor undo, save and reopen, and disposable play.
  - A RevivalMobile shell.

### What went wrong

1. **Bespoke per-script code.** Each Training script became its own Swift type, `Level` field, validator, and update function. Examples: 9 near-duplicate death-chain types, and `TrainingGuidebotSimulation.swift` mixing routing, AI, and particles. No general object, AI, or script runtime existed. About 70% of the 93k Swift lines are Training-specific. This could not scale to the 27 level scripts.
2. **Monolith files.** `WorldRendering.swift` grew to 13.9k lines and its tests to 27.5k before it was caught. That led to the 5,000-line cap.
3. **Process weight.** Every packet ran a selector, a writer, four review concerns, and a completion gate. The docs grew to 1.94 MB (about 484k tokens): a 1.1 MB source ledger, a 214 KB feature ledger, and a 169 KB "current plan" that had become a diary.
4. **Verification hygiene.** Agents often lost track, left apps, test runners, and debuggers running, and re-ran passing checks.
5. **Scope.** 1.0 promised the game, mobile, a full creator suite with a mod SDK, multiplayer, and replay together.

### What the reset changed (M0)

- 1.0 is now the Mac single-player game. The rest moved to post-1.0.
- Scripts: the Osiris/DALLAS API is translated once, and each level script is translated against it (`architecture.md` section 6).
- The existing code is kept and refactored (`plan.md`, M1).
- The process is now light: one plan, Codex reviews, and mandatory cleanup (`engineering.md`).
- The toolchain moved to the Xcode 27.0 release.

## Retired documents

The old documents are preserved at git tag **`revival-docs-v1`** (commit `e73d4408`). To read one:

```bash
git show revival-docs-v1:docs/revival/<file>.md
```

| Old doc | Useful content moved to |
|---|---|
| `REVIVAL.md`, `functional-completeness.md` | `product.md` |
| `roadmap.md`, `current-plan.md` | `plan.md` |
| `architecture.md`, `world-loading.md`, `behavior-system.md`, `content-pipeline.md`, `creator-suite.md` | `architecture.md`, and the `d3-content-import` skill |
| `engineering-principles.md`, `test-driven-development.md`, `verification.md`, `source-translation.md`, `skills-and-agents.md` | `engineering.md`, and the skills |
| `retail-data.md`, `primary-source-index.md`, `skill-supply-chain.md` | `sources.md` |
| `source-translation-ledger.md`, `functional-completeness-ledger.md` | Not carried forward. Per-symbol ledgers are dropped. The feature list is in `product.md` and the level checklist is in `plan.md`. |
| `discovery.md`, `macos-arm64-build.md`, `future-opportunities.md`, `adaptive-music.md`, `internet-multiplayer-study.md` | Tag only. Reopen when the post-1.0 work (P1–P5) starts. |
| 13 retired skills (constitution, documentation-steward, completion-gate, wayfinding, simplify, review, behavior-system, volumetric-navigation, creator-suite, replay, multiplayer, networked-simulation, transport-security-operations) | Tag only. Their useful rules are in `engineering.md`, `revival-game-runtime`, and `revival-verification`. Recreate the post-1.0 ones when their work starts. |

## Last selected packet (not started)

The final Codex selector (`019ff344`, 2026-08-12) chose "full RASBot1 hostile attack" as the next packet. It is now part of M2, through the general AI and weapon code. Its source facts still apply:

- Robot generic page v27, weapon `Laser Level 1 - Red` (page v8), model data `GPNT`/`WBAT`.
- A battery of four masks with fire waits `[2.4, 0.2, 0.2, 0.2]`.
- EVADER1 steering.
- 6.75 shields damage per hit, so the player's shields go negative after 15 hits.
- Adopt 3MASTERED `dbd611e4` (inclusive readiness, fire-time overshoot).
