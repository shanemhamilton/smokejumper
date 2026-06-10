#!/usr/bin/env bash
# lib/validate.sh — validate .smokejumper state files against their schemas.
#
# With jq: full structural validation (required fields + types) per
# schemas/sprint-event.schema.json and schemas/gap.schema.json.
# Without jq: required-field grep checks (degraded but still catches the
# common failure: an orchestrator inventing its own event shape).
#
# --phase <PHASE> additionally asserts the events that phase is required to
# have emitted (the "state artifacts per phase" contract in SKILL.md).

validate_usage() {
  cat <<'EOF'
usage: sj validate-state <target-repo-root> [--phase RECON|DECIDE|PLAN|EXECUTE|REVIEW|INTEGRATE|LESSONS]
EOF
}

# Required events per phase. Single source of the event vocabulary contract.
_phase_required_events() {
  case "$1" in
    RECON)     echo "leads_established" ;;
    DECIDE)    echo "objective_chosen" ;;
    PLAN)      echo "gate_passed" ;;
    EXECUTE)   echo "" ;;                      # unit events are optional
    REVIEW)    echo "gate_passed" ;;
    INTEGRATE) echo "push_completed" ;;
    LESSONS)   echo "write_back_completed" ;;
    *) return 1 ;;
  esac
}

_validate_jsonl() { # _validate_jsonl <file> <required-fields-csv> <label>
  local file="$1" required="$2" label="$3" lineno=0 errors=0 line f
  [ -f "$file" ] || { echo "FAIL: missing $label: $file"; return 1; }
  while IFS= read -r line; do
    lineno=$(( lineno + 1 ))
    [ -n "$line" ] || continue
    if have_jq; then
      if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
        echo "FAIL: $label line $lineno is not valid JSON"
        errors=$(( errors + 1 )); continue
      fi
      local IFS=','
      for f in $required; do
        if ! printf '%s' "$line" | jq -e --arg k "$f" 'has($k) and (.[$k] | type == "string")' >/dev/null 2>&1; then
          echo "FAIL: $label line $lineno missing/invalid required field: $f"
          errors=$(( errors + 1 ))
        fi
      done
      unset IFS
    else
      local IFS=','
      for f in $required; do
        if ! printf '%s' "$line" | grep -q "\"$f\":"; then
          echo "FAIL: $label line $lineno missing required field: $f"
          errors=$(( errors + 1 ))
        fi
      done
      unset IFS
    fi
  done < "$file"
  [ "$errors" -eq 0 ]
}

validate_main() {
  local target="${1:-}" phase=""
  [ -n "$target" ] || { validate_usage; exit 1; }
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --phase) phase="${2:?--phase needs a value}"; shift 2 ;;
      *) die "unknown validate-state option: $1" ;;
    esac
  done

  local sj_dir log gaps rc=0
  sj_dir="$(sj_state_dir "$target")"
  log="$sj_dir/sprint-log.jsonl"
  gaps="$sj_dir/gaps.jsonl"

  _validate_jsonl "$log" "ts,sprint,phase,event,detail" "sprint-log.jsonl" || rc=1
  if [ -s "$gaps" ]; then
    _validate_jsonl "$gaps" "ts,detail" "gaps.jsonl" || rc=1
  fi

  if [ -n "$phase" ]; then
    local required ev
    required="$(_phase_required_events "$phase")" || die "unknown phase: $phase"
    local IFS=','
    for ev in $required; do
      [ -n "$ev" ] || continue
      if ! grep -q "\"event\":\"$ev\"" "$log" 2>/dev/null; then
        echo "FAIL: phase $phase requires a '$ev' event in sprint-log.jsonl — none found"
        rc=1
      fi
    done
    unset IFS
  fi

  if [ "$rc" -eq 0 ]; then
    echo "OK: state valid${phase:+ for phase $phase} ($sj_dir)"
  fi
  return "$rc"
}
