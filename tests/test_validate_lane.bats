#!/usr/bin/env bats
# sj validate-state and sj lane-check.

load helpers

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  make_fixture_repo "$REPO"
  "$SJ" init "$REPO" >/dev/null
  LOG="$REPO/.smokejumper/sprint-log.jsonl"
}

@test "validate-state passes on empty fresh state" {
  run "$SJ" validate-state "$REPO"
  [ "$status" -eq 0 ]
}

@test "validate-state passes on well-formed events" {
  printf '{"ts":"2026-06-09T10:00:00Z","sprint":"s1","phase":"RECON","event":"leads_established","detail":"ok"}\n' >> "$LOG"
  run "$SJ" validate-state "$REPO"
  [ "$status" -eq 0 ]
}

@test "validate-state fails on malformed JSON line" {
  echo '{not json' >> "$LOG"
  run "$SJ" validate-state "$REPO"
  [ "$status" -ne 0 ]
}

@test "validate-state fails on a line missing required fields" {
  printf '{"ts":"2026-06-09T10:00:00Z","event":"orphan"}\n' >> "$LOG"
  run "$SJ" validate-state "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing"* ]]
}

@test "validate-state --phase RECON fails without leads_established" {
  run "$SJ" validate-state "$REPO" --phase RECON
  [ "$status" -ne 0 ]
  [[ "$output" == *"leads_established"* ]]
}

@test "validate-state --phase RECON passes after the required event" {
  printf '{"ts":"2026-06-09T10:00:00Z","sprint":"s1","phase":"RECON","event":"leads_established","detail":"ok"}\n' >> "$LOG"
  run "$SJ" validate-state "$REPO" --phase RECON
  [ "$status" -eq 0 ]
}

@test "validate-state rejects unknown phase" {
  run "$SJ" validate-state "$REPO" --phase BOGUS
  [ "$status" -ne 0 ]
}

@test "lane-check is clear for innocuous work" {
  unit="$BATS_TEST_TMPDIR/unit.md"
  printf 'Refactor the README table of contents and tidy markdown lint warnings.\n' > "$unit"
  run "$SJ" lane-check "$REPO" "$unit"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLEAR"* ]]
  grep -q '"event":"lane_check"' "$LOG"
}

@test "lane-check trips on safety-critical patterns" {
  unit="$BATS_TEST_TMPDIR/unit.md"
  printf 'Add a database migration that alters the payments table and rotates the auth token.\n' > "$unit"
  run "$SJ" lane-check "$REPO" "$unit"
  [ "$status" -eq 2 ]
  [[ "$output" == *"DENY-ADVISORY"* ]]
}

@test "lane-check trips on paths listed under Gate locations" {
  cat >> "$REPO/.smokejumper/repo-knowledge.md" <<'EOF'
EOF
  # insert a gate location into the existing section
  awk '/^## Gate locations$/{print; print ""; print "- src/scoring/verdict.ts"; next} {print}' \
    "$REPO/.smokejumper/repo-knowledge.md" > "$REPO/.smokejumper/rk.tmp"
  mv "$REPO/.smokejumper/rk.tmp" "$REPO/.smokejumper/repo-knowledge.md"
  unit="$BATS_TEST_TMPDIR/unit.md"
  printf 'Tweak formatting in src/scoring/verdict.ts for readability.\n' > "$unit"
  run "$SJ" lane-check "$REPO" "$unit"
  [ "$status" -eq 2 ]
  [[ "$output" == *"gate locations"* ]]
}
