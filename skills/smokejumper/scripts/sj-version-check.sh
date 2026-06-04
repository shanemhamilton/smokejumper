#!/usr/bin/env bash
# sj-version-check.sh — non-blocking check for a newer published SmokeJumper release.
#
# Prints a short update notice to stdout when a newer version exists; prints nothing
# otherwise. NEVER fails the caller: missing curl, no network, API errors, rate limits,
# or unparseable output all exit 0 silently. Safe to run at the start of every sprint.
#
# Usage: sj-version-check.sh
set -uo pipefail

REPO="shanemhamilton/smokejumper"

# Plugin root holds VERSION; this script lives at <root>/skills/smokejumper/scripts/.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

local_version="$(cat "$PLUGIN_ROOT/VERSION" 2>/dev/null || true)"
[ -z "$local_version" ] && exit 0
command -v curl >/dev/null 2>&1 || exit 0

# Latest published release tag, e.g. "smokejumper--v0.4.0". Time-boxed so a slow or
# unreachable network never stalls the sprint.
latest_tag="$(curl -fsS --max-time 5 \
  "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  | grep -m1 '"tag_name"' \
  | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
[ -z "$latest_tag" ] && exit 0

latest_version="${latest_tag#smokejumper--v}"
latest_version="${latest_version#v}"

# Behind only when local != latest AND latest sorts strictly newer (SemVer-aware).
[ "$local_version" = "$latest_version" ] && exit 0
newer="$(printf '%s\n%s\n' "$local_version" "$latest_version" | sort -V | tail -1)"
[ "$newer" = "$latest_version" ] || exit 0

cat <<EOF
⬆️  SmokeJumper update available: v$local_version → v$latest_version
    Claude Code: claude plugin marketplace upgrade smokejumper
    Codex:       codex plugin marketplace upgrade smokejumper
EOF
exit 0
