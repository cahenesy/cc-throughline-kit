---
name: implement
description: Build TDDs unattended. With no argument, implements every `ready` TDD not yet `implemented`, as a batch (a batch of one is fine). Pass a TDD path to build just that one. Confirms the queue, then launches the build itself as a detached background job so your session stays clean. Invoke with /implement.
disable-model-invocation: true
---

# Implement

The single entry point for turning TDDs into code. One ready TDD or seven — same
command, no manual batch/single distinction.

## Scope
- `/implement <tdd-path>` → build just that TDD.
- `/implement` (no argument) → build every `docs/tdd/*.md` with `Status: ready`,
  in numeric order. TDDs at `Status: implemented` are skipped — that flip is the
  done-signal, so a re-run resumes whatever is still `ready`.

## Prepare
1. Show the queue: the TDD(s) in scope and their Status. Confirm.
2. Confirm mode:
   - **Sequential (default):** one `build/<change>` branch; features build on
     each other; ONE PR. Use when features depend on each other or share files.
   - **`--parallel`:** a `feat/<slug>` worktree + PR per feature. INDEPENDENT
     features only. Multiplies token usage; may hit rate limits.
3. Ensure `scripts/implement.sh` and `scripts/build-prompt.md` exist in the repo;
   if absent, copy them from `${CLAUDE_PLUGIN_ROOT}/scripts/` and
   `chmod +x scripts/implement.sh`.

## Run (launch it yourself, detached)
Implementation runs in separate `claude -p` processes, never in this session —
fresh context per feature, and this session stays clean. After the user
confirms the queue and mode (step 1–2 above), LAUNCH the runner yourself as a
detached background job and return control immediately. Do not print a command
for the user to run.

Launch with a single Bash call (adjust flags for the confirmed mode/scope):

```
mkdir -p docs/tdd/.implement-logs
nohup ./scripts/implement.sh > docs/tdd/.implement-logs/nohup.out 2>&1 &
echo "launched pid $!"
```

`nohup … &` survives the session closing and does not block, so the build runs
unattended while the session stays free. Variants: append a TDD path to build
one; add `--parallel` for independent features.

After launching, report: the PID, that it is running detached, and the log
location. The user can watch with `tail -f docs/tdd/.implement-logs/<ts>/report.md`
or just wait.

What each process does (see `scripts/build-prompt.md`): loads the TDD + its PRD
refs + accepted ADRs, builds with tests written alongside, lint/typecheck
enforced, subagent review, updates any docs the change makes stale IN THE SAME
COMMIT (supersede accepted ADRs/design docs; edit evergreen docs in place),
commits, and flips the TDD to `Status: implemented`. The runner owns branches
and PRs and opens a PR per the mode — but NEVER merges. Merging is your approval
gate. Failures are logged and never stop the batch.

When the build finishes: a report at
`docs/tdd/.implement-logs/<timestamp>/report.md` lists OK/FAIL per feature with
log paths, and the PR(s) await review.

## Notes
- PRs need a git remote and the `gh` CLI; without them, commits stay on the
  branch to PR manually.
- The runner sets `--permission-mode auto` for unattended runs; for tighter
  control add a tool allowlist or use OS sandboxing.
- "skip git" → build and commit on the current branch with no branching/PRs.
