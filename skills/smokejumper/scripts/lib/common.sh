#!/usr/bin/env bash
# lib/common.sh — shared helpers for the sj CLI and its subcommands.
#
# Source this file; do not execute it. Everything here is bash + standard unix
# tools, portable across macOS and Linux. jq is optional: callers test have_jq
# and fall back to grep/sed parsing when it is absent.

# --- Output ------------------------------------------------------------------

warn() { printf 'sj: warning: %s\n' "$*" >&2; }
die()  { printf 'sj: error: %s\n' "$*" >&2; exit 1; }

# --- Capability probes -------------------------------------------------------

have_jq() { command -v jq >/dev/null 2>&1; }

# sha256_of <string> — prints a 12-char truncated sha256. Uses shasum (macOS)
# or sha256sum (Linux); falls back to cksum if neither exists (CRC, but unique
# enough for event IDs in a single log).
sha256_of() {
  local input="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$input" | shasum -a 256 | cut -c1-12
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$input" | sha256sum | cut -c1-12
  else
    printf '%s' "$input" | cksum | tr -d ' \t' | cut -c1-12
  fi
}

# --- State directory ---------------------------------------------------------

# sj_state_dir <target-repo-root> — prints the state dir for a target repo.
# Honors SJ_STATE_DIR (absolute, or relative to the target root).
sj_state_dir() {
  local target="$1"
  if [ -n "${SJ_STATE_DIR:-}" ]; then
    case "$SJ_STATE_DIR" in
      /*) printf '%s' "$SJ_STATE_DIR" ;;
      *)  printf '%s/%s' "$target" "$SJ_STATE_DIR" ;;
    esac
  else
    printf '%s/.smokejumper' "$target"
  fi
}

# require_git_repo <dir> — dies unless <dir> is inside a git work tree.
require_git_repo() {
  local dir="$1"
  [ -d "$dir" ] || die "target directory does not exist: $dir"
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "target is not a git repository: $dir (sj state belongs in a repo; pass a repo root)"
}

# --- Temp files with guaranteed cleanup --------------------------------------

# mktemp_traced — prints a temp file path registered for cleanup on EXIT.
# Uses a single accumulated trap so multiple calls compose.
_SJ_TMPFILES=""
_sj_cleanup_tmp() {
  local f
  for f in $_SJ_TMPFILES; do rm -f "$f" 2>/dev/null || true; done
}
mktemp_traced() {
  local t
  t="$(mktemp)" || die "mktemp failed"
  if [ -z "$_SJ_TMPFILES" ]; then trap _sj_cleanup_tmp EXIT; fi
  _SJ_TMPFILES="$_SJ_TMPFILES $t"
  printf '%s' "$t"
}

# --- Atomic writes & locking -------------------------------------------------

# atomic_write <dest-file> — reads stdin, writes to a temp file in the SAME
# directory as dest (so mv is an atomic rename, not a cross-device copy),
# then renames into place.
atomic_write() {
  local dest="$1" dir tmp
  dir="$(dirname "$dest")"
  [ -d "$dir" ] || die "atomic_write: directory does not exist: $dir"
  tmp="$(mktemp "$dir/.sj-tmp.XXXXXX")" || die "atomic_write: mktemp failed in $dir"
  cat > "$tmp" || { rm -f "$tmp"; die "atomic_write: write failed for $dest"; }
  mv "$tmp" "$dest" || { rm -f "$tmp"; die "atomic_write: rename failed for $dest"; }
}

# with_lock <lock-dir> <cmd...> — runs <cmd> while holding a mkdir-based lock.
# flock(1) is absent on macOS, so mkdir (atomic on POSIX filesystems) is the
# portable primitive. A lock older than SJ_LOCK_TTL seconds (default 300) is
# considered stale (crashed holder) and is broken with a warning.
with_lock() {
  local lockdir="$1"; shift
  local ttl="${SJ_LOCK_TTL:-300}" waited=0 age now mtime rc
  while ! mkdir "$lockdir" 2>/dev/null; do
    now="$(date +%s)"
    mtime="$(stat -f %m "$lockdir" 2>/dev/null || stat -c %Y "$lockdir" 2>/dev/null || echo "$now")"
    age=$(( now - mtime ))
    if [ "$age" -ge "$ttl" ]; then
      warn "breaking stale lock (${age}s old): $lockdir"
      rm -rf "$lockdir" 2>/dev/null || true
      continue
    fi
    [ "$waited" -ge 30 ] && die "could not acquire lock after ${waited}s: $lockdir (another sprint running? remove it manually if not)"
    sleep 1; waited=$(( waited + 1 ))
  done
  rc=0
  "$@" || rc=$?
  rmdir "$lockdir" 2>/dev/null || rm -rf "$lockdir" 2>/dev/null || true
  return "$rc"
}

# --- JSON helpers (jq-optional) ----------------------------------------------

# json_escape <string> — escape backslash, double-quote, and newlines for
# embedding in a JSON string value.
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'NR>1{printf "\\n"} {printf "%s", $0} END{print ""}' | tr -d '\n'
}

# json_field <json-line> <key> — prints the string value of a top-level key
# from a single-line JSON object. jq when available; grep/sed fallback that is
# adequate for sj's own well-formed single-line events.
json_field() {
  local line="$1" key="$2"
  if have_jq; then
    printf '%s' "$line" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
  else
    printf '%s' "$line" | grep -o "\"$key\":\"[^\"]*\"" | head -1 | sed "s/\"$key\":\"//; s/\"\$//"
  fi
}

# --- Event log ---------------------------------------------------------------

sj_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# emit_event <log-file> <sprint> <phase> <event> <detail> [outcome] [ref]
# Appends one schema-conformant line to sprint-log.jsonl.
emit_event() {
  local log="$1" sprint="$2" phase="$3" event="$4" detail="$5" outcome="${6:-}" ref="${7:-}"
  {
    printf '{"ts":"%s","sprint":"%s","phase":"%s","event":"%s","detail":"%s"' \
      "$(sj_ts)" "$sprint" "$phase" "$event" "$(json_escape "$detail")"
    [ -n "$outcome" ] && printf ',"outcome":"%s"' "$outcome"
    [ -n "$ref" ] && printf ',"ref":"%s"' "$(json_escape "$ref")"
    printf '}\n'
  } >> "$log"
}
