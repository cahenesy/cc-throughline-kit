#!/usr/bin/env bash
# format-and-lint.sh — Claude Code PostToolUse hook
#
# Formats then lints the file Claude just edited, but ONLY if the relevant
# tool is available. On a repo with no linter configured it exits 0 silently,
# so it never forces tooling onto a brownfield project. On a lint failure it
# exits 2, which feeds the error back to Claude to fix at the root cause.
#
# Hook input arrives as JSON on stdin (tool_input.file_path).
set -uo pipefail

input="$(cat)"
file="$(printf '%s' "$input" | python3 -c \
  'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' \
  2>/dev/null)"

[ -z "${file}" ] && exit 0
[ ! -f "${file}" ] && exit 0

ext="${file##*.}"
have() { command -v "$1" >/dev/null 2>&1; }
fail() { echo "format-and-lint: $1" >&2; exit 2; }

case "${ext}" in
  js|jsx|ts|tsx|mjs|cjs)
    have npx || exit 0
    npx --no-install prettier --write "${file}" >/dev/null 2>&1 || true
    if ls .eslintrc* eslint.config.* >/dev/null 2>&1 \
       || grep -q '"eslintConfig"' package.json 2>/dev/null; then
      npx --no-install eslint --fix "${file}" 2>&1 \
        || fail "eslint reported errors in ${file}. Fix the root cause; do not suppress."
    fi
    ;;
  py)
    have ruff || exit 0
    ruff format "${file}" >/dev/null 2>&1 || true
    ruff check --fix "${file}" 2>&1 \
      || fail "ruff reported errors in ${file}. Fix the root cause; do not suppress."
    ;;
  rs)
    have rustfmt && rustfmt "${file}" >/dev/null 2>&1 || true
    if have cargo && [ -f Cargo.toml ]; then
      cargo clippy --quiet 2>&1 \
        || fail "clippy reported errors. Fix the root cause; do not suppress."
    fi
    ;;
  go)
    have gofmt && gofmt -w "${file}" >/dev/null 2>&1 || true
    if have golangci-lint; then
      golangci-lint run "$(dirname "${file}")/..." 2>&1 \
        || fail "golangci-lint reported errors. Fix the root cause; do not suppress."
    fi
    ;;
  *) exit 0 ;;
esac
exit 0
