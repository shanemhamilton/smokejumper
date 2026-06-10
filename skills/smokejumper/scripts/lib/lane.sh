#!/usr/bin/env bash
# lib/lane.sh — advisory deterministic Lane A safety pre-check.
#
# Reads a unit description file (the work-unit spec the engineering lead wrote)
# and trips on deny-list patterns that mark work as safety-critical: such work
# must never go to the unattended async pour lane (Lane A). Also trips on any
# path listed under "## Gate locations" in repo-knowledge.md.
#
# This does NOT replace the engineering lead's judgment — the classification is
# irreducibly semantic. It converts "purely definitional" into "definitional
# plus a tripwire", and logs its verdict so HANDOFF can audit it.
#
# Exit codes: 0 = no tripwire matched; 2 = matched (route to Lane B / human).

lane_usage() {
  cat <<'EOF'
usage: sj lane-check <target-repo-root> <unit-description-file>
EOF
}

# Patterns that indicate safety-critical or irreversible work.
_LANE_DENY_PATTERNS='migration|migrate|schema change|auth|oauth|jwt|session|password|credential|secret|token|payment|billing|stripe|charge|refund|payout|\.github/workflows|deploy|release script|force.push|prod(uction)? (db|database|data)|drop table|delete.*(user|account)|health.*(verdict|score)|safety'

lane_main() {
  local target="${1:-}" unit_file="${2:-}"
  if [ -z "$target" ] || [ -z "$unit_file" ]; then lane_usage; exit 1; fi
  [ -f "$unit_file" ] || die "unit file not found: $unit_file"

  local sj_dir log rk hits gate_hits="" verdict
  sj_dir="$(sj_state_dir "$target")"
  log="$sj_dir/sprint-log.jsonl"
  rk="$sj_dir/repo-knowledge.md"

  hits="$(grep -Eio "$_LANE_DENY_PATTERNS" "$unit_file" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u | paste -sd, - || true)"

  # Paths recorded under "## Gate locations" in repo-knowledge.md are
  # repo-specific safety surfaces; mentioning one in a unit spec trips the wire.
  if [ -f "$rk" ]; then
    local gate_paths p
    gate_paths="$(awk '/^## Gate locations$/{f=1;next} /^## /{f=0} f' "$rk" \
      | grep -oE '[A-Za-z0-9_./-]+\.[A-Za-z0-9]+|[A-Za-z0-9_./-]+/' | sort -u || true)"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if grep -Fq "$p" "$unit_file" 2>/dev/null; then
        gate_hits="${gate_hits:+$gate_hits,}$p"
      fi
    done <<< "$gate_paths"
  fi

  if [ -n "$hits" ] || [ -n "$gate_hits" ]; then
    verdict="DENY-ADVISORY"
    echo "LANE-CHECK: $verdict — unit touches safety-critical surface; route to Lane B (or human)."
    [ -n "$hits" ] && echo "  matched patterns: $hits"
    [ -n "$gate_hits" ] && echo "  matched gate locations: $gate_hits"
  else
    verdict="CLEAR"
    echo "LANE-CHECK: CLEAR — no safety tripwire matched (engineering lead judgment still applies)."
  fi

  [ -f "$log" ] && emit_event "$log" "${SJ_SPRINT:-sprint-$(date -u +%Y-%m-%d)}" PLAN lane_check \
    "unit $(basename "$unit_file"): $verdict${hits:+ patterns=$hits}${gate_hits:+ gates=$gate_hits}"

  [ "$verdict" = "CLEAR" ] || return 2
}
