#!/usr/bin/env bash
# lib/gate.sh — gate evidence chain: record / check / clear.
#
# A gate marker is a claim with provenance, not an empty touch file. `record`
# writes reviewer events into sprint-log.jsonl and a marker citing them;
# `check` validates the marker against the log and git history. A stale or
# fabricated claim fails the ancestry/recency checks.
#
# Markers live in the state dir:
#   adversarial-review -> .adversarial-review-passed
#   plan-vetted        -> .plan-vetted
#   <other>            -> .gate-<name>-passed

gate_usage() {
  cat <<'EOF'
usage:
  sj gate record <gate-name> [--target <dir>] --reviewers <a,b,c>
  sj gate check  <gate-name> [--target <dir>]
  sj gate clear  <gate-name> [--target <dir>]
EOF
}

_gate_marker_path() {
  local sj_dir="$1" gate="$2"
  case "$gate" in
    adversarial-review) printf '%s/.adversarial-review-passed' "$sj_dir" ;;
    plan-vetted)        printf '%s/.plan-vetted' "$sj_dir" ;;
    *)                  printf '%s/.gate-%s-passed' "$sj_dir" "$gate" ;;
  esac
}

_gate_field() { # _gate_field <marker-file> <key>
  sed -n "s/^$2: //p" "$1" | head -1
}

gate_record() {
  local gate="$1" target="$2" reviewers="$3"
  [ -n "$reviewers" ] || die "gate record requires --reviewers <a,b,c> (who reviewed? evidence needs identities)"
  require_git_repo "$target"
  local sj_dir log head ts sprint marker event_ids="" r id
  sj_dir="$(sj_state_dir "$target")"
  log="$sj_dir/sprint-log.jsonl"
  [ -f "$log" ] || die "no sprint log at $log — run: sj init $target"
  head="$(git -C "$target" rev-parse HEAD)" || die "cannot resolve git HEAD in $target"
  ts="$(sj_ts)"
  sprint="${SJ_SPRINT:-sprint-$(date -u +%Y-%m-%d)}"
  marker="$(_gate_marker_path "$sj_dir" "$gate")"

  local IFS=','
  for r in $reviewers; do
    [ -n "$r" ] || continue
    id="$(sha256_of "$ts|$gate|$head|$r")"
    printf '{"ts":"%s","sprint":"%s","phase":"REVIEW","event":"gate_review","detail":"%s reviewed gate %s","id":"%s","ref":"%s"}\n' \
      "$ts" "$sprint" "$(json_escape "$r")" "$gate" "$id" "$head" >> "$log"
    event_ids="${event_ids:+$event_ids,}$id"
  done
  unset IFS
  [ -n "$event_ids" ] || die "no reviewers parsed from: $reviewers"

  id="$(sha256_of "$ts|$gate|$head|passed")"
  printf '{"ts":"%s","sprint":"%s","phase":"REVIEW","event":"gate_passed","detail":"gate %s passed","id":"%s","ref":"%s"}\n' \
    "$ts" "$sprint" "$gate" "$id" "$head" >> "$log"
  event_ids="$event_ids,$id"

  atomic_write "$marker" <<EOF
gate: $gate
recorded: $ts
sprint: $sprint
head: $head
reviewers: $reviewers
events: $event_ids
EOF
  echo "Gate '$gate' recorded → $marker (head ${head:0:12}, reviewers: $reviewers)"
}

gate_check() {
  local gate="$1" target="$2"
  require_git_repo "$target"
  local sj_dir log marker head rec_head rec_ts ids id fail=0
  sj_dir="$(sj_state_dir "$target")"
  log="$sj_dir/sprint-log.jsonl"
  marker="$(_gate_marker_path "$sj_dir" "$gate")"

  [ -f "$marker" ] || { echo "FAIL: no marker for gate '$gate' ($marker). Run the gate, then: sj gate record $gate --reviewers ..."; return 1; }
  [ -f "$log" ] || { echo "FAIL: marker exists but sprint log is missing ($log)"; return 1; }

  rec_head="$(_gate_field "$marker" head)"
  rec_ts="$(_gate_field "$marker" recorded)"
  ids="$(_gate_field "$marker" events)"
  if [ -z "$rec_head" ] || [ -z "$rec_ts" ] || [ -z "$ids" ]; then
    echo "FAIL: marker is malformed (missing head/recorded/events): $marker"; return 1
  fi

  # 1. Every cited event ID must resolve to a real log entry.
  local IFS=','
  for id in $ids; do
    grep -q "\"id\":\"$id\"" "$log" || { echo "FAIL: cited event $id not found in sprint log — marker does not match the evidence"; fail=1; }
  done
  unset IFS

  # 2. The reviewed commit must be an ancestor of (or equal to) current HEAD.
  if ! git -C "$target" merge-base --is-ancestor "$rec_head" HEAD 2>/dev/null; then
    echo "FAIL: reviewed commit ${rec_head:0:12} is not an ancestor of HEAD — history rewritten or marker imported from elsewhere"
    fail=1
  fi

  # 3. The marker must postdate the newest EXECUTE-phase event (no reviewing
  #    yesterday's gate against today's code). ISO-8601 UTC sorts lexically.
  local last_exec
  last_exec="$(grep '"phase":"EXECUTE"' "$log" 2>/dev/null | tail -1 | grep -o '"ts":"[^"]*"' | sed 's/"ts":"//; s/"$//' || true)"
  if [ -n "$last_exec" ] && [ "$(printf '%s\n%s\n' "$rec_ts" "$last_exec" | sort | tail -1)" = "$last_exec" ] && [ "$rec_ts" != "$last_exec" ]; then
    echo "FAIL: gate recorded at $rec_ts but EXECUTE work continued until $last_exec — stale gate; re-run review and: sj gate record $gate"
    fail=1
  fi

  # 4. New commits after the reviewed head are a warning (the gate reviewed an
  #    ancestor, not this exact tree) unless the only commits are the gate's own.
  head="$(git -C "$target" rev-parse HEAD)"
  if [ "$head" != "$rec_head" ]; then
    local ahead
    ahead="$(git -C "$target" rev-list --count "$rec_head"..HEAD 2>/dev/null || echo '?')"
    warn "HEAD is $ahead commit(s) past the reviewed commit ${rec_head:0:12} — confirm those commits are gate-exempt (docs/log-only) or re-record"
  fi

  if [ "$fail" -eq 0 ]; then
    echo "OK: gate '$gate' verified (recorded $rec_ts, head ${rec_head:0:12}, events: $ids)"
    return 0
  fi
  return 1
}

gate_clear() {
  local gate="$1" target="$2"
  local sj_dir marker
  sj_dir="$(sj_state_dir "$target")"
  marker="$(_gate_marker_path "$sj_dir" "$gate")"
  if [ -f "$marker" ]; then
    rm -f "$marker"
    [ -f "$sj_dir/sprint-log.jsonl" ] && emit_event "$sj_dir/sprint-log.jsonl" \
      "${SJ_SPRINT:-sprint-$(date -u +%Y-%m-%d)}" REVIEW gate_cleared "marker for gate $gate removed"
    echo "Cleared gate marker: $marker"
  else
    echo "No marker to clear for gate '$gate'"
  fi
}

gate_main() {
  local action="${1:-}" gate="${2:-}" target="$PWD" reviewers=""
  if [ -z "$action" ] || [ -z "$gate" ]; then gate_usage; exit 1; fi
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --target)    target="${2:?--target needs a value}"; shift 2 ;;
      --reviewers) reviewers="${2:?--reviewers needs a value}"; shift 2 ;;
      *) die "unknown gate option: $1" ;;
    esac
  done
  case "$action" in
    record) gate_record "$gate" "$target" "$reviewers" ;;
    check)  gate_check "$gate" "$target" ;;
    clear)  gate_clear "$gate" "$target" ;;
    *)      gate_usage; exit 1 ;;
  esac
}
