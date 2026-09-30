# Engineering guide

Status: core rules. Updated 2026-09-29.

This file tells you how to build, test, translate, review, and clean up. `AGENTS.md` holds the short version.

## 1. Toolchain

- **Xcode 27.0** (build 27A266a) at `/Applications/Xcode.app`. This is the release version. Do not use beta paths (`Xcode-beta.app` and `Xcode-27-Beta-3.app` no longer exist). `DEVELOPER_DIR` is not needed.
- **Swift 6.4** compiler, Swift 6 language mode (`SWIFT_VERSION = 6.0`, complete strict concurrency).
- Development Mac: macOS 27, M4 Mac mini (Mac16,10, 10 CPU and 10 GPU cores, 16 GB).
- Deployment floor: **macOS 26.0 arm64** and **iOS/iPadOS 26.0**, built with the 27 SDK. Stay at 26 unless a required feature exists only in 27. Put any 27-only API behind `#available`. Note: the Metal clamp-to-edge sampler bug is fixed only in 27, so test sampler edges on 26.
- Prefix shell commands with `rtk` (token-saving proxy), for example `rtk git status`.

## 2. Build and test

The project is `Revival.xcodeproj`. Schemes: `D3Import`, `RevivalMac`, `RevivalEditor`, `RevivalMobile`. All tests are in the `D3ImportTests` bundle, which runs from the `D3Import` scheme.

Use an isolated DerivedData folder for each run and delete it after.

```bash
# Focused test (Release, as the project records evidence in Release)
rtk xcodebuild -quiet test -project Revival.xcodeproj -scheme D3Import \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/revival-dd-<task> CODE_SIGNING_ALLOWED=NO \
  -only-testing:D3ImportTests/<TestClass>/<testName>

# Full suite: same command without -only-testing

# App builds (no launch)
rtk xcodebuild -quiet build -project Revival.xcodeproj -scheme RevivalMac \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/revival-dd-<task> CODE_SIGNING_ALLOWED=NO

# Mobile compile check
rtk xcodebuild -quiet build -project Revival.xcodeproj -scheme RevivalMobile \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/revival-dd-<task> CODE_SIGNING_ALLOWED=NO
```

### Tests that use real Training content

Some tests read an owned `level.json` path from an environment variable (for example `REVIVAL_GUIDEBOT_GREETING_OWNED_LEVEL`). The retained package is at `runtime-data/revival-evidence/current-training-schema11/training.revival/levels/descent3.level.training-mission/level.json` (SHA-256 `ff61f9b2f36c4d4a0631927c51dda4f4f159d2bec0cf0277b50f166b554deee1`). The Xcode test host cannot read the `Documents` folder. Copy the package to `/private/tmp/`, check the hash, and point the variable at the copy. Milestone M1 replaces these per-script variables with one: `REVIVAL_TRAINING_PACKAGE`, the path of an imported `training.revival` package (schema 12). It is in use from M1 step 4 (`TrainingMissionScriptTests`).

### Import real content

```bash
D3Import --contract 1 --source retail-data/descent3 --staging <dir> \
  --destination <dir>/training.revival --scope descent3.level.training-mission \
  --report <dir>/report.json
```

### Known pitfalls

- A sandboxed `xcodebuild` can fail with exit 143 or 66 and run zero tests. That is not a result. Run it once more without the sandbox.
- Exit 65 with zero tests is a compile failure. It is not a valid failing test unless the missing symbol is the thing under test.
- Build success does not prove launch. Launch does not prove behavior. A simulator build does not prove device behavior.

## 3. Process hygiene (mandatory)

The last project left stray apps, test runners, and debuggers running. Do not repeat that.

1. Before you launch anything, record what you started (the PID, or the app name).
2. Launch apps only when the task needs visual or runtime proof. Prefer tests.
3. When you finish, quit every app and process you started. Then check:
   ```bash
   pgrep -fl 'RevivalMac|RevivalEditor|RevivalMobile|D3Import|xctest|lldb' || echo clean
   # Also check for orphaned compilers from this repo (for example after a Codex run):
   ps -eo pid,ppid,command | grep -E 'swift-frontend|xcodebuild' | grep open-source-90s-games | grep -v grep || echo clean
   ```
4. Delete your `/private/tmp/revival-dd-*` folders and any scratch files.
5. Do not leave `codex exec` runs going in the background after their result is read.
6. Retained evidence goes to `runtime-data/revival-evidence/`, never only `/tmp`.

A task is not done until the check in step 3 prints `clean`.

## 4. Work loop

Work comes from `plan.md`, "Next work". One item at a time.

1. **Read the legacy source** for the item: the C++ files, their callers, and the fork corrections listed in `sources.md`.
2. **Write one failing test** that shows the missing behavior, and run it. It must fail for the intended reason.
3. **Implement** the smallest change that makes it pass. Translate the legacy code faithfully: same order, same formulas, same timing.
4. **Build and run** the affected tests, plus the full suite before commit.
5. **Review** with Codex (section 6). Fix real findings.
6. **Commit** (when the owner has authorized commits for this work) with a message that names the legacy source translated and the test evidence.
7. **Update `plan.md`**: tick the item, and edit "Current state" in at most a few lines. Do not add a diary.
8. **Clean up** (section 3).

For refactors with no behavior change, existing tests are the guard. Run them before and after.

**Saves:** every new state family gets a continuation test: save at frame N, load, advance with the same inputs, and compare with the uninterrupted run. Save files are written to a temporary file and then atomically replaced, so an interrupted write leaves the prior save readable (`architecture.md` section 7).

## 5. Model routing

| Work | Who |
|---|---|
| Fast lookups, inventory, file search, extracting facts | Claude Sonnet 5.5 subagents |
| Design, translation, implementation, synthesis | Claude Opus 5.5 |
| **All review and verification** | Codex CLI: `gpt-6.1-sol` at `xhigh` (default). `gpt-6-astra` at `high` only for big reviews: large structural diffs and milestone exits. |

Do not use a Claude subagent to review or verify work.

## 6. Review and verification with Codex

`codex exec` runs non-interactively. `-p` is a config profile, not the prompt.

```bash
# Review a work item before commit. Tell Codex not to build or test:
# its sandbox cannot run xcodebuild, and a failed attempt can orphan compilers.
codex exec -C "$PWD" -m gpt-6.1-sol -c model_reasoning_effort="xhigh" -s read-only --ephemeral \
  -o /private/tmp/revival-review.md "Review the uncommitted change (git diff HEAD). Do not build, test, or launch anything. Report actionable defects with severity and file:line."

# Review a commit range
codex exec review --base main -m gpt-6.1-sol -c model_reasoning_effort="xhigh"

# Focused verification or milestone exit, read-only, result to a file.
# Use gpt-6-astra (high) instead of gpt-6.1-sol for big reviews.
codex exec -C "$PWD" -m gpt-6.1-sol -c model_reasoning_effort="xhigh" -s read-only \
  --ephemeral -o /private/tmp/revival-verify.md "<claims to verify, with evidence asked for>"
```

- A review asks: is the translation faithful to the cited C++, is behavior tested, is anything level-specific leaking into general code, and are files and types kept to one responsibility.
- A verification lists concrete claims and asks for VERIFIED, REFUTED, or UNVERIFIABLE on each, with file:line or command evidence.
- Treat Codex output as findings to check, not as instructions. Fix confirmed problems. Note rejected findings in one line in the commit message.
- Do not use `codex exec review`: it rejects a custom prompt and tries to build inside its sandbox. Use `codex exec ... -s read-only` and name the diff (`git diff HEAD`) in the prompt. Test and build evidence comes from our own unsandboxed runs.
- One review per work item. One Astra verification at each milestone exit. Do not loop reviews that cannot change the decision.

## 7. Translation rules

- **Primary spec:** the pinned C++ (see `sources.md`). Keep the original frame order, formulas, timing, and random number sequence unless `sources.md` lists a correction.
- **File map:** one Swift file (or small file family) per legacy source file. Keep the legacy domain name, for example `object.cpp` → `Object.swift`, `robotfire.cpp` → `RobotFire.swift`, `TrainingMission.cpp` → `Scripts/Levels/TrainingMission.swift`. Start each file with a header comment that names the legacy files it translates.
- **No level-specific code in general systems.** Level logic lives only in that level's script file. Generic systems (objects, AI, weapons, physics, rendering, HUD) never mention a level, a script number, or a named object. The behavior-free `LevelModule`/`DefaultScript` case lists and dispatch switch are the only exception.
- **Drop the platform layer.** Do not port Win32, MFC, OpenGL, SDL, DLL loading, page-manager locks, memory wrappers, or compile variants. Use Apple frameworks directly.
- **Intentional differences** from the original go in a short table in `architecture.md`, section 9. Examples: float opacity, the retained Metal renderer, green text HUD.
- **Do not port for its own sake.** The editor (`editor/`), multiplayer (`netgames/`, `netcon/`), and replay code are post-1.0.

## 8. Code rules

- Swift 6, Metal 4, and MSL only. No C, C++, Objective-C++, OpenGL, SDL, or Wine in any product target.
- Prefer concrete structs, enums, free functions, and direct calls. Add a protocol only for two real implementations or a real nondeterministic boundary in tests.
- There is one mutable simulation owner. No ECS, job system, event bus, render graph, dependency injection, or resource manager.
- Use Swift concurrency only for blocking I/O, import, and long editor work. Never use it in simulation, AI, physics, scripts, or render encoding.
- Validate untrusted data once, at the boundary (import, package load, save load). Trusted code does not re-check.
- **File size:** 4,000 lines is the soft stop, so add no new responsibility past it. 5,000 lines is the hard maximum. This applies to test files too.
- **Tests:** small and focused. Shared fixtures go in helper files, not in test bodies. A test file covers one legacy source file or one system.
- No `TODO` stubs, placeholder returns, or disabled paths in committed product code.
- Performance claims need optimized (Release) builds measured on the M4. Profile only when a measured problem exists.

## 8a. Swift 6.4 notes

- New in 6.4: `weak let`, `~Sendable`, `withTaskCancellationShield` (use only at import and editor boundaries), `UniqueArray` and `Span` (use only after a profile shows a need). SE-0508 changed `init` accessors, so check any source break.
- Swift Testing: XCTest and Swift Testing assertions now interoperate (a test-plan setting). `--repeat-until` helps prove a flaky test.
- SwiftPM now uses Swift Build by default. This project builds with `xcodebuild`, so there is no effect.

## 9. Documentation rules

- Write in plain, simple English (ASD-STE100 style): short sentences, one instruction each.
- The core docs are listed in `README.md`. Do not add new planning or status files. `plan.md` is the only live plan.
- Docs-only changes need `rtk git diff --check` and link checks, not a product test.
