#!/usr/bin/env bash
# releases-manifest.test.sh — eval for TDD 0009 / FR-35:
# .claude-plugin/releases.json is the append-only release-metadata manifest the
# SessionStart reconcile hook reads to decide whether to surface the local
# notice. This pins its contract so the hook (and a maintainer appending a new
# release) can rely on its shape:
#   - it exists and is valid JSON (an array);
#   - every entry is {version: string, local_impacting: bool};
#   - it carries an entry for the CURRENT plugin.json version (the hook's
#     baseline — a missing current entry would make every fresh install read
#     "version unknown");
#   - the SEED is entirely local_impacting:false (TDD: prior releases were pure
#     governance/runner changes; a manifest that defaults a notice on would spam
#     every consumer on the very first post-update session).
#
# Run: bash tests/releases-manifest.test.sh
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO/.claude-plugin/releases.json"
PLUGIN_JSON="$REPO/.claude-plugin/plugin.json"
RESULTS="$(mktemp)"; export RESULTS
ok()  { printf 'ok\n'   >>"$RESULTS"; printf '  ok   — %s\n' "$1"; }
bad() { printf 'fail\n' >>"$RESULTS"; printf '  FAIL — %s\n' "$1"; }

ver="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -n1)"

echo "[A] the manifest exists and is valid JSON"
if [ -f "$MANIFEST" ]; then
  ok "releases.json exists"
  if python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then ok "releases.json is valid JSON"
  else bad "releases.json is not valid JSON"; fi
else
  bad "releases.json is missing"
fi

# Everything below depends on a parseable manifest; guard so the suite still
# tallies rather than crashing when [A] already failed.
echo "[B] manifest is an array of {version:string, local_impacting:bool}"
if [ -f "$MANIFEST" ] && python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then
  python3 - "$MANIFEST" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
assert isinstance(m, list), "top level must be a JSON array"
assert len(m) >= 1, "manifest must seed at least the current version"
for e in m:
    assert isinstance(e, dict), f"entry not an object: {e!r}"
    assert isinstance(e.get("version"), str) and e["version"], f"bad version field: {e!r}"
    assert isinstance(e.get("local_impacting"), bool), f"local_impacting must be a bool: {e!r}"
PY
  if [ $? -eq 0 ]; then ok "every entry is {version:string, local_impacting:bool}"
  else bad "an entry violates the {version:string, local_impacting:bool} shape"; fi
else
  bad "[B] cannot validate entry shape — manifest absent or unparseable"
fi

echo "[C] manifest carries an entry for the current plugin.json version ($ver)"
if [ -f "$MANIFEST" ] && python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then
  if python3 - "$MANIFEST" "$ver" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
sys.exit(0 if any(e.get("version") == sys.argv[2] for e in m) else 1)
PY
  then ok "current version $ver is present"
  else bad "current version $ver is absent — hook has no baseline for a fresh install"; fi
else
  bad "[C] cannot check current version — manifest absent or unparseable"
fi

echo "[D] the seed is entirely local_impacting:false (no spurious notice)"
if [ -f "$MANIFEST" ] && python3 -m json.tool "$MANIFEST" >/dev/null 2>&1; then
  if python3 - "$MANIFEST" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
sys.exit(0 if all(e.get("local_impacting") is False for e in m) else 1)
PY
  then ok "no seeded release is flagged local_impacting"
  else bad "a seeded release is local_impacting:true — would spam consumers on first post-update session"; fi
else
  bad "[D] cannot check seed flags — manifest absent or unparseable"
fi

echo
PASS="$(grep -c '^ok$'   "$RESULTS" 2>/dev/null)"; PASS="${PASS:-0}"
FAIL="$(grep -c '^fail$' "$RESULTS" 2>/dev/null)"; FAIL="${FAIL:-0}"
rm -f "$RESULTS"
echo "=== releases-manifest eval: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
