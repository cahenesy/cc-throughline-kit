#!/usr/bin/env bash
# bounded-rework-loop.test.sh — eval for the bounded automatic rework loop
# (TDD 0019 / FR-61, FR-62, FR-65, FR-66, FR-67, FR-68; ADR 0007).
#
# The contract under test (function-level; the runtime-verify gate re-drives the
# same observable surface against a real /implement run):
#   - run.json carries a config.rework_config snapshot of the four §6 knobs
#     (model, max, scope_floor, scope_factor) so any halt citing them is
#     reproducible from run-state alone (ADR 0006).
#   - the per-TDD fragment gains rework_attempts (object), rework_log (array),
#     and build_attempt.token_spend, threaded through _write_tdd_fragment and
#     carried forward by every fragment writer.
#   - _extract_token_spend reads a session JSONL's token usage (or null).
#   - _rework_attempt_count increments the per-(gate,step) counter.
#   - _rework_scope_cap = max(floor, factor × region).
#   - _rework_pre_pass enforces FR-66 scope cap + FR-67(a) touched-file set +
#     FR-67(b) per-file bound against a rework commit's diff, with the §5
#     build-start-SHA fallback when no cleared SHA is supplied.
#   - the gate_one review gate drives the bounded loop: structural(c) tag →
#     immediate BLOCK; budget exhaustion → rework-budget-exhausted BLOCK;
#     oversized/out-of-set/over-bound rework → reset + structural/scope BLOCK.
#
# Run: bash tests/bounded-rework-loop.test.sh
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
IMPL="$REPO/scripts/implement.sh"
RESULTS="$(mktemp)"; export RESULTS
ok()   { printf 'ok\n'   >>"$RESULTS"; printf '  ok   — %s\n' "$1"; }
bad()  { printf 'fail\n' >>"$RESULTS"; printf '  FAIL — %s\n' "$1"; }

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT

# --- §6 / FR-65, FR-66: rework_config snapshot in run.json -------------------
echo "[A1] _rework_config_json emits the four §6 knobs with defaults"
( D="$ROOT/A1"; mkdir -p "$D/state.d"
  export STATE_DIR="$D/state.d" STATE_STARTED_AT=1000 STATE_MODE="sequential"
  export INTEGRATION="master" CHANGE="ci" LOGDIR="$D"
  TDDS=()
  THROUGHLINE_SOURCE_ONLY=1 source "$IMPL" || { bad "source guard missing"; exit 0; }
  out="$(_rework_config_json)"
  printf '%s' "$out" | grep -q '"model":"sonnet"' \
    && ok "default model=sonnet" || bad "default rework model should be sonnet (got: $out)"
  printf '%s' "$out" | grep -q '"max":3' \
    && ok "default max=3" || bad "default rework max should be 3 (got: $out)"
  printf '%s' "$out" | grep -q '"scope_floor":60' \
    && ok "default scope_floor=60" || bad "default scope_floor should be 60 (got: $out)"
  printf '%s' "$out" | grep -q '"scope_factor":3' \
    && ok "default scope_factor=3" || bad "default scope_factor should be 3 (got: $out)"
) || true

echo "[A2] _rework_config_json honors env overrides"
( D="$ROOT/A2"; mkdir -p "$D/state.d"
  export STATE_DIR="$D/state.d" STATE_STARTED_AT=1000 STATE_MODE="sequential"
  export INTEGRATION="master" CHANGE="ci" LOGDIR="$D"
  export THROUGHLINE_REWORK_MODEL="opus" THROUGHLINE_REWORK_MAX="5"
  export THROUGHLINE_REWORK_SCOPE_FLOOR="100" THROUGHLINE_REWORK_SCOPE_FACTOR="2"
  TDDS=()
  THROUGHLINE_SOURCE_ONLY=1 source "$IMPL" || { bad "source guard missing"; exit 0; }
  out="$(_rework_config_json)"
  printf '%s' "$out" | grep -q '"model":"opus"' \
    && ok "model override honored" || bad "model override should be opus (got: $out)"
  printf '%s' "$out" | grep -q '"max":5' \
    && ok "max override honored" || bad "max override should be 5 (got: $out)"
  printf '%s' "$out" | grep -q '"scope_floor":100' \
    && ok "scope_floor override honored" || bad "scope_floor override should be 100 (got: $out)"
  printf '%s' "$out" | grep -q '"scope_factor":2' \
    && ok "scope_factor override honored" || bad "scope_factor override should be 2 (got: $out)"
) || true

echo "[A3] _write_run_fragment embeds config.rework_config in run.json"
( D="$ROOT/A3"; mkdir -p "$D/state.d"
  export STATE_DIR="$D/state.d" STATE_STARTED_AT=1000 STATE_MODE="sequential"
  export INTEGRATION="master" CHANGE="ci" LOGDIR="$D"
  TDDS=()
  THROUGHLINE_SOURCE_ONLY=1 source "$IMPL" || { bad "source guard missing"; exit 0; }
  _write_run_fragment running
  R="$D/state.d/run.json"
  grep -q '"config":{"rework_config":{' "$R" 2>/dev/null \
    && ok "run.json carries config.rework_config" \
    || bad "run.json should carry config.rework_config (got: $(cat "$R"))"
  grep -q '"scope_factor":3' "$R" 2>/dev/null \
    && ok "rework_config values present in run.json" \
    || bad "run.json rework_config should carry the knob values"
) || true

echo
PASS="$(grep -c '^ok$'   "$RESULTS" 2>/dev/null)"; PASS="${PASS:-0}"
FAIL="$(grep -c '^fail$' "$RESULTS" 2>/dev/null)"; FAIL="${FAIL:-0}"
rm -f "$RESULTS"
echo "=== bounded-rework-loop eval: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
