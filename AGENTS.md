@/Users/jasonholt/.codex/RTK.md

# Descent 3 Revival: agent rules

A native Swift 6.4 and Metal 4 rewrite of Descent 3, translated from the GPL C++ source in this repo. Write in plain, simple English (ASD-STE100 style).

## Read

| When | Read |
|---|---|
| Always, before work | `docs/revival/plan.md` (current state and next step) |
| Scope questions | `docs/revival/product.md` |
| Design, runtime, scripts, saves | `docs/revival/architecture.md` |
| Build, test, review, cleanup, model routing | `docs/revival/engineering.md` |
| Source pins, fork fixes, retail data, rights | `docs/revival/sources.md` |

Skills are in `.agents/skills/`: `revival-source-translation`, `revival-game-runtime`, `d3-content-import`, `metal4-rendering`, `swift-realtime-systems`, and `revival-verification`.

## Hard rules

1. **1.0 is the single-player Mac game** (Training, base campaign, Mercenary). Mobile, editor, multiplayer, replay, and enhanced graphics are post-1.0. Keep the RevivalMobile and RevivalEditor targets compiling.
2. **Translate the general mechanism, not the specific case.** Level logic lives only in `RevivalCore/Scripts/Levels/<Level>.swift`, against the translated Osiris/DALLAS API. Generic code never names a level, script number, or named object. The only exception is the behavior-free `LevelModule`/`DefaultScript` case lists and dispatch switch.
3. **Faithful first.** Keep the original order, formulas, timing, and RNG draws. Adopt only the corrections listed in `sources.md`. Record other differences in `architecture.md` section 9.
4. **Swift, MSL, and Apple frameworks only** in product targets. No C, C++, Objective-C++, OpenGL, SDL, or runtime loading of retail formats or native code.
5. **No retail data in Git.** Tests use synthetic fixtures. Real-content tests are opt-in by environment variable.
6. **Simple code:** concrete types, one simulation owner (`GameWorld`), no ECS, event bus, job system, or single-implementation protocols. Files: 4,000-line soft stop, 5,000 hard maximum.
7. **Test first** for behavior changes. Full suite green before commit.
8. **Review and verification run on Codex:** `gpt-6.1-sol` at xhigh by default; `gpt-6-astra` at high only for big reviews (large diffs, milestone exits). Commands are in `engineering.md` section 6. Use Claude Sonnet for retrieval, and Claude Opus for design and implementation.
9. **Clean up every process you start.** A task is not done until the `pgrep` check in `engineering.md` section 3 prints `clean`.
10. **One plan.** Update `docs/revival/plan.md` in place (tick the item, and edit "Current state" in a few lines). Do not create other plan, status, or diary files.

## Toolchain

Xcode 27.0 release (`/Applications/Xcode.app`), Swift 6.4 in Swift 6 language mode, macOS 27 dev machine. The deployment floor is macOS/iOS 26. Prefix shell commands with `rtk`.

## Commit and push

Commit only when asked. Commit messages name the legacy source translated and the test evidence. Do not push or tag without being asked.
