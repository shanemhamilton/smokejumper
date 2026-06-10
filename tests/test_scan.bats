#!/usr/bin/env bats
# sj scan — adapter scan: fixture run, JSON output, plugin-detection precision,
# and the adapter.md <-> adapter-scan.json contract.

load helpers

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  make_fixture_repo "$REPO"
  # Isolated HOME so the host machine's installed skills/plugins don't leak in.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
}

@test "scan runs cold on a fresh repo and writes all outputs" {
  run "$SJ" scan "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Leads Established"* ]]
  [ -f "$REPO/.smokejumper/repo-knowledge.md" ]
  [ -f "$REPO/.smokejumper/adapter-scan.json" ]
  grep -q '"event":"leads_established"' "$REPO/.smokejumper/sprint-log.jsonl"
  grep -q 'Product lead: `smokejumper-product-lead` (BUNDLED)' "$REPO/.smokejumper/repo-knowledge.md"
}

@test "adapter-scan.json is valid JSON with bundled leads" {
  command -v jq >/dev/null || skip "jq required"
  "$SJ" scan "$REPO" >/dev/null
  json="$REPO/.smokejumper/adapter-scan.json"
  jq -e . "$json" >/dev/null
  [ "$(jq -r .leads.productLead "$json")" = "smokejumper-product-lead" ]
  [ "$(jq -r .leads.productLeadSource "$json")" = "BUNDLED" ]
  [ "$(jq -r .health.designPosture "$json")" = "ADVISORY" ]
  [ "$(jq -r .productContext "$json")" = "null" ]
}

@test "scan resolves a project-specific lead over the bundled one" {
  mkdir -p "$REPO/.claude/agents"
  echo "# my lead" > "$REPO/.claude/agents/acme-product-lead.md"
  run "$SJ" scan "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"acme-product-lead"* ]]
  [[ "$output" == *"project-specific"* ]]
}

@test "stale plugin dirs (metaswarm-old) do NOT count as the metaswarm capability" {
  command -v jq >/dev/null || skip "jq required"
  mkdir -p "$HOME/.claude/plugins/marketplace/metaswarm-old"
  "$SJ" scan "$REPO" >/dev/null
  [ "$(jq -r .capabilities.metaswarm "$REPO/.smokejumper/adapter-scan.json")" = "false" ]
}

@test "exact plugin dir match DOES count as the metaswarm capability" {
  command -v jq >/dev/null || skip "jq required"
  mkdir -p "$HOME/.claude/plugins/marketplace/metaswarm"
  "$SJ" scan "$REPO" >/dev/null
  [ "$(jq -r .capabilities.metaswarm "$REPO/.smokejumper/adapter-scan.json")" = "true" ]
}

@test "scan handles a target path containing regex metacharacters" {
  WEIRD="$BATS_TEST_TMPDIR/repo (v2).+x"
  make_fixture_repo "$WEIRD"
  mkdir -p "$WEIRD/src"
  echo "module.exports = {}" > "$WEIRD/tailwind.config.js"
  run "$SJ" scan "$WEIRD"
  [ "$status" -eq 0 ]
  # design-system candidate path must be repo-relative, not mangled by the regex chars
  grep -q 'tailwind.config.js' "$WEIRD/.smokejumper/repo-knowledge.md"
}

@test "scan detects product context when present" {
  command -v jq >/dev/null || skip "jq required"
  mkdir -p "$REPO/docs/product"
  echo "# Product Pilot" > "$REPO/docs/product/PRODUCT_PILOT.md"
  "$SJ" scan "$REPO" >/dev/null
  [ "$(jq -r .productContext "$REPO/.smokejumper/adapter-scan.json")" = "docs/product/PRODUCT_PILOT.md" ]
}

@test "contract: every adapter.* key documented in adapter.md exists in adapter-scan.json" {
  command -v jq >/dev/null || skip "jq required"
  "$SJ" scan "$REPO" >/dev/null
  json="$REPO/.smokejumper/adapter-scan.json"
  spec="$BATS_TEST_DIRNAME/../skills/smokejumper/references/adapter.md"
  keys="$(grep -oE 'adapter\.(agents|gate|capabilities|model|skills)\.[a-zA-Z]+' "$spec" | sort -u)"
  [ -n "$keys" ]
  missing=""
  while IFS= read -r key; do
    path="${key#adapter.}"                       # agents.uiImplementer
    group="${path%%.*}"; leaf="${path#*.}"
    if ! jq -e --arg g "$group" --arg l "$leaf" '.[$g] | has($l)' "$json" >/dev/null 2>&1; then
      missing="$missing $key"
    fi
  done <<< "$keys"
  if [ -n "$missing" ]; then
    echo "keys documented in adapter.md but absent from adapter-scan.json:$missing"
    false
  fi
}

@test "scan state validates against the event schema" {
  "$SJ" scan "$REPO" >/dev/null
  run "$SJ" validate-state "$REPO" --phase RECON
  [ "$status" -eq 0 ]
}
