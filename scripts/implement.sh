#!/usr/bin/env bash
# implement.sh — build TDDs unattended. Run detached (tmux/nohup) so it survives
# the session closing and keeps the interactive context clean.
#
#   ./scripts/implement.sh                  # all `ready` TDDs, sequential
#   ./scripts/implement.sh docs/tdd/0003-x.md   # just one TDD
#   ./scripts/implement.sh --parallel       # independent features, one PR each
#
# Each TDD is built in a FRESH `claude -p` process (clean context per feature)
# under auto permission mode. The build flips its TDD to `Status: implemented`,
# which is the done-signal: a no-arg re-run skips implemented TDDs and resumes
# whatever is still `ready`. Failures are logged and never stop the batch.
#
# Branches/PRs (the runner owns these; it never merges — merging is your gate):
#   sequential → one `build/<change>` branch, ONE PR to base.
#   parallel   → a `feat/<slug>` worktree + branch + PR per feature.
set -uo pipefail

PARALLEL=0; MODEL=""; CHANGE=""; ONE=""
BASE="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
while [ $# -gt 0 ]; do case "$1" in
  --parallel) PARALLEL=1; shift ;;
  --model)    MODEL="$2";  shift 2 ;;
  --change)   CHANGE="$2"; shift 2 ;;
  --base)     BASE="$2";   shift 2 ;;
  -*) echo "unknown arg: $1"; exit 2 ;;
  *)  ONE="$1"; shift ;;
esac; done
[ -z "$CHANGE" ] && CHANGE="build/$(date +%Y%m%d-%H%M%S)"

command -v claude >/dev/null 2>&1 || { echo "claude CLI not found on PATH"; exit 1; }
HASGH=0; command -v gh >/dev/null 2>&1 && HASGH=1
SDIR="$(cd "$(dirname "$0")" && pwd)"
TMPL="$SDIR/build-prompt.md"; [ -f "$TMPL" ] || { echo "missing $TMPL"; exit 1; }

LOGDIR="docs/tdd/.implement-logs/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$LOGDIR"
REPORT="$LOGDIR/report.md"; { echo "# Implement report — $(date)"; echo; } > "$REPORT"

if [ -n "$ONE" ]; then TDDS=("$ONE")
else mapfile -t TDDS < <(grep -lE '^Status:[[:space:]]*ready' docs/tdd/*.md 2>/dev/null | sort); fi
[ "${#TDDS[@]}" -eq 0 ] && { echo "No `ready` TDDs to build." | tee -a "$REPORT"; exit 0; }
echo "Queue (${#TDDS[@]}):"; printf '  %s\n' "${TDDS[@]}"; echo "Report: $REPORT"; echo

build_one() {  # <tdd> <log>  (cwd = repo or worktree; commits, no PR)
  local tdd="$1" log="$2" prompt
  prompt="$(sed "s#{{TDD}}#${tdd}#g" "$TMPL")"
  local args=(-p "$prompt" --permission-mode auto); [ -n "$MODEL" ] && args+=(--model "$MODEL")
  claude "${args[@]}" >"$log" 2>&1
}
status_of(){ grep -aoE 'BATCH_RESULT: (OK|FAIL.*)' "$1" 2>/dev/null | tail -1; }

if [ "$PARALLEL" -eq 1 ]; then
  pids=()
  for tdd in "${TDDS[@]}"; do
    slug="$(basename "$tdd" .md)"; log="$LOGDIR/$slug.log"; wt="../$(basename "$PWD")-wt-$slug"
    if ! git worktree add -b "feat/$slug" "$wt" "$BASE" >>"$log" 2>&1; then
      echo "worktree failed for $slug" >>"$log"; continue; fi
    ( cd "$wt" && build_one "$tdd" "$OLDPWD/$log"
      if [ "$HASGH" = 1 ] && status_of "$OLDPWD/$log" | grep -q OK; then
        git push -u origin "feat/$slug" >>"$OLDPWD/$log" 2>&1 \
          && gh pr create --base "$BASE" --head "feat/$slug" --fill >>"$OLDPWD/$log" 2>&1; fi ) &
    pids+=("$!")
  done
  [ "${#pids[@]}" -gt 0 ] && wait "${pids[@]}" 2>/dev/null
  for tdd in "${TDDS[@]}"; do slug="$(basename "$tdd" .md)"; log="$LOGDIR/$slug.log"
    echo "- $slug — $(status_of "$log" || echo 'UNKNOWN — see log') (branch feat/$slug, log: $log)" >>"$REPORT"; done
  { echo; echo "Parallel: one PR per feat/* branch (if gh+remote). Review & merge, then 'git worktree remove' each."; } >>"$REPORT"
else
  git checkout -b "$CHANGE" "$BASE" >>"$REPORT" 2>&1 || git checkout "$CHANGE" >>"$REPORT" 2>&1
  for tdd in "${TDDS[@]}"; do slug="$(basename "$tdd" .md)"; log="$LOGDIR/$slug.log"
    echo ">>> $slug"; build_one "$tdd" "$log"; res="$(status_of "$log" || echo 'UNKNOWN — see log')"
    echo "  $res"; echo "- $slug — $res (log: $log)" >>"$REPORT"; done
  if [ "$HASGH" = 1 ]; then
    if git push -u origin "$CHANGE" >>"$REPORT" 2>&1 && gh pr create --base "$BASE" --head "$CHANGE" --fill >>"$REPORT" 2>&1; then
      echo "Opened PR: $CHANGE -> $BASE (not merged — merging is your gate)." >>"$REPORT"; fi
  else echo "gh/remote not available: commits are on branch '$CHANGE'; open a PR manually." >>"$REPORT"; fi
fi
echo; echo "=== Done. Report: $REPORT ==="; cat "$REPORT"
