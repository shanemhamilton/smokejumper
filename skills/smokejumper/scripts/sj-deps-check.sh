#!/usr/bin/env bash
# sj-deps-check.sh — notify-only check that SmokeJumper's declared dependencies are current.
#
# Reads references/dependencies.json (the single source of truth) and, for every dependency
# with a `github-release` source, compares the pinned/tested version against the latest
# upstream tag. Prints a one-line notice per dependency that has moved ahead of its pin.
#
# Discipline (same as sj-version-check.sh): NEVER fails the caller and NEVER auto-upgrades.
# Missing python3/curl, no network, API errors, rate limits, or `manual` sources all exit 0
# silently. Safe to run at the start of every sprint.
#
# Usage:
#   sj-deps-check.sh            # notify-only: report dependencies behind their pin
#   sj-deps-check.sh --update   # opt-in: bump pins to the detected latest + print upgrade cmds
#   sj-deps-check.sh --verbose  # also report up-to-date and manually-tracked dependencies
set -uo pipefail

MODE="check"; VERBOSE=0
for a in "$@"; do
  case "$a" in
    --update) MODE="update" ;;
    --verbose|-v) VERBOSE=1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/../references/dependencies.json"
[ -f "$MANIFEST" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
command -v curl    >/dev/null 2>&1 || exit 0
PY="$(command -v python3)"

CACHE_DIR="${TMPDIR:-/tmp}/sj-deps-cache"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Emit one TSV row per dependency: id \t kind \t source.type \t source.repo \t pin
deps_tsv() {
  "$PY" - "$MANIFEST" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for x in d.get("dependencies", []):
    s = x.get("source", {}) or {}
    print("\t".join([
        x.get("id", ""), x.get("kind", ""),
        s.get("type", ""), s.get("repo", ""),
        str(x.get("pin") or ""),
    ]))
PYEOF
}

# Normalize a tag to a trailing semver: "v1.2.3" / "smokejumper--v0.4.0" / "1.2" -> "1.2.3" / "1.2"
semver_of() { printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | tail -1; }

# Latest upstream version for a github repo (releases/latest, then tags). 12h cache; fail-open.
gh_latest() {
  local repo="$1" cache="$CACHE_DIR/${1//\//_}" tag now
  if [ -f "$cache" ]; then
    now="$(date +%s 2>/dev/null || echo 0)"
    # GNU first: on Linux `stat -f %m` succeeds with filesystem info (mount point),
    # not an mtime — BSD `stat -c` fails cleanly, so this order is safe on both.
    local mtime; mtime="$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)"
    case "$mtime" in (*[!0-9]*) mtime=0 ;; esac
    if [ "$((now - mtime))" -lt 43200 ]; then cat "$cache"; return 0; fi
  fi
  tag="$(curl -fsS --max-time 5 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  [ -z "$tag" ] && tag="$(curl -fsS --max-time 5 "https://api.github.com/repos/$repo/tags" 2>/dev/null \
        | grep -m1 '"name"' | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  local v; v="$(semver_of "$tag")"
  [ -n "$v" ] && printf '%s' "$v" > "$cache" 2>/dev/null
  printf '%s' "$v"
}

# Is $2 strictly newer than $1 (SemVer)? returns 0 (true) / 1 (false).
is_newer() {
  [ -n "$2" ] || return 1
  [ "$1" = "$2" ] && return 1
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ]
}

upgrade_hint() { # upgrade_hint <id> <kind>
  case "$2" in
    backend|skill|vendored) printf '    claude plugin marketplace upgrade %s   (or: codex plugin marketplace upgrade %s)' "$1" "$1" ;;
    tracker)                printf '    upgrade %s via its own installer / package manager' "$1" ;;
    *)                      printf '    upgrade %s via its usual channel' "$1" ;;
  esac
}

behind_lines=""; update_pins=""

while IFS=$'\t' read -r id kind stype repo pin; do
  [ -n "$id" ] || continue
  if [ "$stype" != "github-release" ] || [ -z "$repo" ]; then
    [ "$VERBOSE" = 1 ] && echo "  · $id — manually tracked (no auto version-check)"
    continue
  fi
  latest="$(gh_latest "$repo")"
  [ -z "$latest" ] && continue   # network/API hiccup — stay silent
  if [ -z "$pin" ]; then
    behind_lines+="  ⬆️  $id — not pinned yet (latest upstream v$latest). Pin with: sj-deps-check.sh --update"$'\n'
    update_pins+="$id=$latest"$'\n'
  elif is_newer "$pin" "$latest"; then
    behind_lines+="  ⬆️  $id — v$pin → v$latest available"$'\n'"$(upgrade_hint "$id" "$kind")"$'\n'
    update_pins+="$id=$latest"$'\n'
  elif [ "$VERBOSE" = 1 ]; then
    echo "  ✓ $id — v$pin (current)"
  fi
done < <(deps_tsv)

if [ "$MODE" = "update" ]; then
  [ -z "$update_pins" ] && { echo "All pinned dependencies are current."; exit 0; }
  # Rewrite the manifest: set pin + tested to the detected latest for the listed ids.
  # Pins are passed via $SJ_PINS (env), NOT stdin — stdin here is the heredoc program.
  SJ_PINS="$update_pins" "$PY" - "$MANIFEST" <<'PYEOF'
import json, os, sys
manifest = sys.argv[1]
pins = {}
for line in os.environ.get("SJ_PINS", "").splitlines():
    line = line.strip()
    if "=" in line:
        k, v = line.split("=", 1); pins[k] = v
d = json.load(open(manifest))
changed = []
for x in d.get("dependencies", []):
    v = pins.get(x.get("id"))
    if v and str(x.get("pin") or "") != v:
        x["pin"] = v; x["tested"] = v; changed.append(f"{x['id']} -> {v}")
json.dump(d, open(manifest, "w"), indent=2)
open(manifest, "a").write("\n")
print("Pinned:", ", ".join(changed) if changed else "(none)")
PYEOF
  echo
  echo "Pins updated in references/dependencies.json. Upgrade the installed copies when ready:"
  printf '%s' "$behind_lines" | grep -E '^\s+(claude|upgrade)' || true
  exit 0
fi

if [ -n "$behind_lines" ]; then
  echo "SmokeJumper dependencies behind their pin:"
  printf '%s' "$behind_lines"
  echo "    Review + bump: sj-deps-check.sh --update   (notify-only; nothing was changed)"
fi
exit 0
