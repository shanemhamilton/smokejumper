#!/usr/bin/env bash
# sj-adapter-scan.sh — deterministic lead / gate / capability detection for a target repo.
#
# This is the executable implementation of the adapter scan specified in prose in
# references/adapter.md. RECON (Phase 1) runs it so that "establishing the leads" is a
# concrete, reproducible action — not a step an orchestrator has to remember to perform.
# Any runtime that can run a shell command (Claude Code, a Codex agent, plain CI) gets the
# same visible result: a resolved lead/gate/capability mapping written to
# repo-knowledge.md, events appended to sprint-log.jsonl, and a banner printed to stdout.
#
# Usage: sj-adapter-scan.sh <target-repo-root>
#
# Resolution: a role resolves to the FIRST matching agent file found in the target repo's
# .claude/agents/ (most specific), then ~/.claude/agents/ (globally installed). If none
# matches, leads fall back to the BUNDLED smokejumper-*-lead persona; gates resolve to
# null (a gate is skipped, never fabricated with a bundled generic — per adapter.md).
set -euo pipefail

TARGET="${1:?usage: sj-adapter-scan.sh <target-repo-root>}"
SJ_DIR="$TARGET/.smokejumper"
RK="$SJ_DIR/repo-knowledge.md"
LOG="$SJ_DIR/sprint-log.jsonl"
SPRINT="${SJ_SPRINT:-sprint-$(date -u +%Y-%m-%d)}"
TS() { date -u +%Y-%m-%dT%H:%M:%SZ; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Ensure state dir exists (reuse sj-init.sh if present; else scaffold the minimum) ----
if [ ! -f "$RK" ]; then
  if [ -x "$SCRIPT_DIR/sj-init.sh" ]; then
    "$SCRIPT_DIR/sj-init.sh" "$TARGET" >/dev/null
  else
    mkdir -p "$SJ_DIR"
    printf '# Repo Knowledge (SmokeJumper)\n\n## Lead & gate mapping\n\n## Capabilities\n' > "$RK"
    touch "$LOG" "$SJ_DIR/gaps.jsonl"
  fi
fi

# --- Agent search roots (only those that exist) ------------------------------------------
ROOTS=()
[ -d "$TARGET/.claude/agents" ] && ROOTS+=("$TARGET/.claude/agents")
[ -d "$HOME/.claude/agents" ] && ROOTS+=("$HOME/.claude/agents")

# resolve_role <case-insensitive extended-regex over the filename>
# Echoes the resolved agent name (the file's basename without .md) of the first match,
# searching target agents before global agents. Echoes nothing if no match.
resolve_role() {
  local pattern="$1" root f base
  for root in "${ROOTS[@]:-}"; do
    [ -d "$root" ] || continue
    for f in "$root"/*.md; do
      [ -e "$f" ] || continue
      base="$(basename "$f" .md)"
      if printf '%s' "$base" | grep -Eiq "$pattern"; then
        printf '%s' "$base"
        return 0
      fi
    done
  done
  return 0
}

# JSON string escaper (backslash + double-quote only; details are kept simple by design).
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# emit <phase> <event> <detail> [outcome] [ref]
emit() {
  local phase="$1" event="$2" detail="$3" outcome="${4:-}" ref="${5:-}"
  {
    printf '{"ts":"%s","sprint":"%s","phase":"%s","event":"%s","detail":"%s"' \
      "$(TS)" "$SPRINT" "$phase" "$event" "$(json_escape "$detail")"
    [ -n "$outcome" ] && printf ',"outcome":"%s"' "$outcome"
    [ -n "$ref" ] && printf ',"ref":"%s"' "$(json_escape "$ref")"
    printf '}\n'
  } >> "$LOG"
}

# --- Resolve leads (always have a bundled fallback) --------------------------------------
PRODUCT_MATCH="$(resolve_role 'product-lead')"
ENG_MATCH="$(resolve_role 'engineering-lead')"
DESIGN_MATCH="$(resolve_role 'design-lead')"

PRODUCT_LEAD="${PRODUCT_MATCH:-smokejumper-product-lead}"
ENG_LEAD="${ENG_MATCH:-smokejumper-engineering-lead}"
DESIGN_LEAD="${DESIGN_MATCH:-smokejumper-design-lead}"
[ -n "$PRODUCT_MATCH" ] && PRODUCT_SRC="project-specific" || PRODUCT_SRC="BUNDLED"
[ -n "$ENG_MATCH" ] && ENG_SRC="project-specific" || ENG_SRC="BUNDLED"
[ -n "$DESIGN_MATCH" ] && DESIGN_SRC="project-specific" || DESIGN_SRC="BUNDLED"

emit RECON agent_resolved "product lead: $PRODUCT_LEAD ($PRODUCT_SRC)"
emit RECON agent_resolved "engineering lead: $ENG_LEAD ($ENG_SRC)"
emit RECON agent_resolved "design lead: $DESIGN_LEAD ($DESIGN_SRC)"

# --- Resolve implementation / specialist agents (bundled-generic fallback) ---------------
UI_IMPL="$(resolve_role 'ios|frontend|(^|-)ui(-|$)|web')"
BACKEND_IMPL="$(resolve_role 'backend|api|server')"
SAFETY_GUARD="$(resolve_role 'safety|guardian|invariant')"
DATA_AUDIT="$(resolve_role 'audit|catalog|(^|-)data(-|$)')"
L10N_REVIEW="$(resolve_role 'localization|l10n|translation')"

# --- Resolve gate roles (null = skip; gates are never fabricated) ------------------------
GATE_DESIGN="$(resolve_role 'design-reviewer')"
GATE_THESIS="$(resolve_role 'thesis')"
GATE_INTEGRITY="$(resolve_role 'review-integrity|sycophancy')"
GATE_FIRSTUSE="$(resolve_role 'first-impression|first-use')"
GATE_QC="$(resolve_role 'quality-control|(^|-)qc(-|$)')"

for pair in "designReviewer:$GATE_DESIGN" "thesisGuardian:$GATE_THESIS" \
            "reviewIntegrity:$GATE_INTEGRITY" "firstUseCritic:$GATE_FIRSTUSE" \
            "qualityControl:$GATE_QC"; do
  role="${pair%%:*}"; val="${pair#*:}"
  if [ -n "$val" ]; then emit RECON agent_resolved "gate.$role: $val" present
  else emit RECON agent_resolved "gate.$role: null (skipped)" skipped; fi
done

# --- Capability probes -------------------------------------------------------------------
cap() { # cap <label> <test-cmd...> ; sets CAP_RESULT=yes|no and emits an event
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then CAP_RESULT=yes; emit RECON capability_detected "$label"
  else CAP_RESULT=no; emit RECON capability_absent "$label"; fi
}
has_ralph() { command -v ralph || command -v choo-choo-ralph || ls "$HOME/.claude/skills/choo-choo-ralph" 2>/dev/null; }
cap "async loop tool (choo-choo-ralph)" has_ralph;      ASYNC_LOOP="$CAP_RESULT"
cap "Codex CLI"                          command -v codex; CODEX="$CAP_RESULT"
cap "issue tracker: beads (bd)"          command -v bd;    BD="$CAP_RESULT"
TRACKER="none"
[ "$BD" = "yes" ] && TRACKER="beads"
if [ "$TRACKER" = "none" ] && command -v gh >/dev/null 2>&1 && gh issue list >/dev/null 2>&1; then
  TRACKER="github"; emit RECON capability_detected "issue tracker: GitHub Issues"
fi

# --- Write the ## Lead & gate mapping and ## Capabilities sections in repo-knowledge.md ---
# replace_section <file> <header> <body-text>
# Splices <body-text> in under <header>, replacing the existing section body up to the next
# "## " heading. The body is passed via a file (not awk -v) because BSD/macOS awk rejects
# newlines in a -v assignment.
replace_section() {
  local file="$1" header="$2" body="$3" tmp bodyfile
  tmp="$(mktemp)"; bodyfile="$(mktemp)"
  printf '%s\n' "$body" > "$bodyfile"
  if grep -Fxq "$header" "$file"; then
    awk -v hdr="$header" -v bf="$bodyfile" '
      $0==hdr {
        print; print "";
        while ((getline line < bf) > 0) print line;
        close(bf);
        skip=1; next
      }
      skip && /^## / { skip=0 }
      skip { next }
      { print }
    ' "$file" > "$tmp"
  else
    cp "$file" "$tmp"
    printf '\n%s\n\n' "$header" >> "$tmp"
    cat "$bodyfile" >> "$tmp"
  fi
  mv "$tmp" "$file"
  rm -f "$bodyfile"
}

MAPPING="$(cat <<EOF
- Product lead: \`$PRODUCT_LEAD\` ($PRODUCT_SRC)
- Engineering lead: \`$ENG_LEAD\` ($ENG_SRC)
- Design lead: \`$DESIGN_LEAD\` ($DESIGN_SRC)
- adapter.agents.uiImplementer: ${UI_IMPL:-null (bundled generic)}
- adapter.agents.backendImplementer: ${BACKEND_IMPL:-null (bundled generic)}
- adapter.agents.safetyGuardian: ${SAFETY_GUARD:-null (none — route safety-critical to human + log gap)}
- adapter.agents.dataAuditor: ${DATA_AUDIT:-null (bundled generic)}
- adapter.agents.localizationReviewer: ${L10N_REVIEW:-null (skip l10n gate)}
- adapter.gate.designReviewer: ${GATE_DESIGN:-null (skip)}
- adapter.gate.thesisGuardian: ${GATE_THESIS:-null (skip)}
- adapter.gate.reviewIntegrity: ${GATE_INTEGRITY:-null (skip)}
- adapter.gate.firstUseCritic: ${GATE_FIRSTUSE:-null (skip)}
- adapter.gate.qualityControl: ${GATE_QC:-null (basic self-review checklist)}
- _Resolved by sj-adapter-scan.sh on $(TS). Model tier (\`adapter.model.*\`) is read from the target CLAUDE.md by RECON, not by this script._
EOF
)"

CAPABILITIES="$(cat <<EOF
- adapter.capabilities.asyncLoop: $ASYNC_LOOP (Lane A $([ "$ASYNC_LOOP" = yes ] && echo available || echo unavailable → all work Lane B))
- adapter.capabilities.codex: $CODEX
- adapter.capabilities.tracker: $TRACKER
EOF
)"

replace_section "$RK" "## Lead & gate mapping" "$MAPPING"
replace_section "$RK" "## Capabilities" "$CAPABILITIES"

emit RECON leads_established "product=$PRODUCT_LEAD eng=$ENG_LEAD design=$DESIGN_LEAD ($PRODUCT_SRC/$ENG_SRC/$DESIGN_SRC)" success

# --- Banner (visible signal — the point of this script) ----------------------------------
cat <<EOF

=== SmokeJumper — Leads Established ===
  Product lead:      $PRODUCT_LEAD   [$PRODUCT_SRC]
  Engineering lead:  $ENG_LEAD   [$ENG_SRC]
  Design lead:       $DESIGN_LEAD   [$DESIGN_SRC]
  Gates resolved:    designReviewer=${GATE_DESIGN:-null} thesisGuardian=${GATE_THESIS:-null} reviewIntegrity=${GATE_INTEGRITY:-null} firstUseCritic=${GATE_FIRSTUSE:-null} qualityControl=${GATE_QC:-null}
  Capabilities:      asyncLoop=$ASYNC_LOOP codex=$CODEX tracker=$TRACKER
  Mapping written →  $RK  (## Lead & gate mapping)
=======================================

How leads are run: these names are PERSONAS. Adopt a lead by reading its definition file
and acting as that role for the phase (see references/runtime.md). If your runtime supports
subagent dispatch you MAY dispatch instead — either way, a lead is not "established" until
its definition has been read. BUNDLED leads load from the plugin's agents/ directory.
EOF
