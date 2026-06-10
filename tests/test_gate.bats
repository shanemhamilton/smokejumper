#!/usr/bin/env bats
# sj gate — evidence chain: record, check, staleness, ancestry, clear, hook.

load helpers

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  make_fixture_repo "$REPO"
  "$SJ" init "$REPO" >/dev/null
  LOG="$REPO/.smokejumper/sprint-log.jsonl"
}

@test "gate check fails before record" {
  run "$SJ" gate check adversarial-review --target "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no marker"* ]]
}

@test "gate record writes marker with provenance and reviewer events" {
  run "$SJ" gate record adversarial-review --target "$REPO" --reviewers "design-gate,thesis-guardian"
  [ "$status" -eq 0 ]
  marker="$REPO/.smokejumper/.adversarial-review-passed"
  [ -f "$marker" ]
  grep -q '^head: ' "$marker"
  grep -q '^reviewers: design-gate,thesis-guardian' "$marker"
  grep -q '^events: ' "$marker"
  # two reviewer events + one gate_passed event in the log
  [ "$(grep -c '"event":"gate_review"' "$LOG")" -eq 2 ]
  [ "$(grep -c '"event":"gate_passed"' "$LOG")" -eq 1 ]
}

@test "gate record requires reviewers" {
  run "$SJ" gate record adversarial-review --target "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--reviewers"* ]]
}

@test "gate check passes after record" {
  "$SJ" gate record adversarial-review --target "$REPO" --reviewers "qc"
  run "$SJ" gate check adversarial-review --target "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: gate"* ]]
}

@test "gate check fails when cited events are missing from the log (fabricated marker)" {
  "$SJ" gate record adversarial-review --target "$REPO" --reviewers "qc"
  : > "$LOG"   # wipe the evidence
  run "$SJ" gate check adversarial-review --target "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found in sprint log"* ]]
}

@test "gate check fails when EXECUTE work postdates the gate (stale gate)" {
  "$SJ" gate record adversarial-review --target "$REPO" --reviewers "qc"
  sleep 1
  printf '{"ts":"%s","sprint":"s","phase":"EXECUTE","event":"unit_done","detail":"more work"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
  run "$SJ" gate check adversarial-review --target "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stale gate"* ]]
}

@test "gate check fails when reviewed head is not an ancestor (foreign marker)" {
  "$SJ" gate record adversarial-review --target "$REPO" --reviewers "qc"
  marker="$REPO/.smokejumper/.adversarial-review-passed"
  sed -i.bak 's/^head: .*/head: 0000000000000000000000000000000000000000/' "$marker" && rm -f "$marker.bak"
  run "$SJ" gate check adversarial-review --target "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not an ancestor"* ]]
}

@test "gate check warns (but passes) when HEAD moved past reviewed commit without EXECUTE events" {
  "$SJ" gate record adversarial-review --target "$REPO" --reviewers "qc"
  commit_in "$REPO" "docs: log-only commit"
  run "$SJ" gate check adversarial-review --target "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"past the reviewed commit"* ]]
}

@test "gate clear removes the marker and logs the event" {
  "$SJ" gate record plan-vetted --target "$REPO" --reviewers "eng-lead"
  [ -f "$REPO/.smokejumper/.plan-vetted" ]
  run "$SJ" gate clear plan-vetted --target "$REPO"
  [ "$status" -eq 0 ]
  [ ! -f "$REPO/.smokejumper/.plan-vetted" ]
  grep -q '"event":"gate_cleared"' "$LOG"
}

@test "pre-push hook blocks push without a valid gate and allows it with one" {
  "$SJ" hooks install "$REPO"
  hook="$REPO/.git/hooks/pre-push"
  [ -x "$hook" ]
  run "$hook"
  [ "$status" -ne 0 ]
  "$SJ" gate record adversarial-review --target "$REPO" --reviewers "qc"
  cd "$REPO" && run "$hook"
  [ "$status" -eq 0 ]
}

@test "hooks install refuses to clobber a foreign pre-push hook" {
  hook="$REPO/.git/hooks/pre-push"
  mkdir -p "$(dirname "$hook")"
  printf '#!/bin/sh\nexit 0\n' > "$hook"; chmod +x "$hook"
  run "$SJ" hooks install "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not installed by sj"* ]]
  ! grep -q "installed-by: sj" "$hook"
}
