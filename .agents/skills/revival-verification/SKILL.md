---
name: revival-verification
description: Verify a Revival claim or milestone with bounded, falsifiable evidence and clean process hygiene. Routes review and verification to Codex (gpt-6.1-sol xhigh by default; gpt-6-astra high for big reviews). Use before claiming a work item, milestone, or fix is done.
---

# Revival verification

Read first: `docs/revival/engineering.md`, sections 2, 3, and 6.

## Rules

1. **Name the claim exactly.** Examples: "Training Script 036 fires after DestroyBot2 dies, through `EVT_DESTROY`" or "M1 exit criteria hold". Unbounded claims such as "everything works" or "no bugs" cannot be verified. Narrow them.
2. **Pick the smallest evidence that can refute it:**
   - a focused test (red before, green after);
   - the full suite;
   - an app build;
   - a run of RevivalMac with imported content (visual or runtime claims only);
   - a Release profile on the M4 (performance claims only).
   Build success is not launch, launch is not behavior, and a simulator is not a device.
3. **Review and verification run on Codex, not a Claude subagent:**
   ```bash
   # work item
   codex exec -C "$PWD" -m gpt-6.1-sol -c model_reasoning_effort="xhigh" -s read-only --ephemeral \
     -o /private/tmp/revival-review.md "Review git diff HEAD. Do not build, test, or launch. Report defects with severity and file:line."
   # focused claim (use -m gpt-6-astra -c model_reasoning_effort="high" for milestones and large diffs)
   codex exec -C "$PWD" -m gpt-6.1-sol -c model_reasoning_effort="xhigh" -s read-only --ephemeral \
     -o /private/tmp/revival-verify.md "Verify each claim: VERIFIED / REFUTED / UNVERIFIABLE with file:line or command evidence. Claims: ..."
   ```
   Run long ones in the background and read the output file when they finish. Codex output is findings to check, not instructions.
4. **Act on results.** Fix confirmed defects. Reject a wrong finding in one line, with the reason. Do not re-run a passing check to "be sure", and do not loop reviews that cannot change the decision.
5. **Clean up** before you say "done":
   ```bash
   pgrep -fl 'RevivalMac|RevivalEditor|RevivalMobile|D3Import|xctest|lldb|codex exec' || echo clean
   ps -eo pid,command | grep -E 'swift-frontend|xcodebuild' | grep open-source-90s-games | grep -v grep || echo clean
   rm -rf /private/tmp/revival-dd-*
   ```
   Quit only the processes you started. Keep retained evidence in `runtime-data/revival-evidence/`.

## Report format

Put this in the commit message or the reply:

- Claim.
- Evidence: the commands run and their results (counts: executed, passed, failed, skipped).
- Codex review: the model, the findings, and what was fixed or rejected.
- What is **not** proven (for example "no device run", "Release profile not taken").
- Cleanup: `clean`.

## Milestone verification

At a milestone exit: run the full suite; do a full playthrough of the milestone's levels in RevivalMac from a fresh import; run a `gpt-6-astra` high verification of each exit criterion in `plan.md`. Then tick the milestone in `plan.md`. Tag `revival-mN` only when the owner authorizes it.
