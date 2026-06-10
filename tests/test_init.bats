#!/usr/bin/env bats
# sj init — scaffolding, idempotency, git-repo validation, SJ_STATE_DIR override.

load helpers

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  NONREPO="$BATS_TEST_TMPDIR/nonrepo"
  make_fixture_repo "$REPO"
  make_non_repo "$NONREPO"
}

@test "init scaffolds state dir with all files" {
  run "$SJ" init "$REPO"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.smokejumper/repo-knowledge.md" ]
  [ -f "$REPO/.smokejumper/sprint-log.jsonl" ]
  [ -f "$REPO/.smokejumper/gaps.jsonl" ]
  grep -q '## Lead & gate mapping' "$REPO/.smokejumper/repo-knowledge.md"
}

@test "init is idempotent (does not clobber existing knowledge)" {
  "$SJ" init "$REPO"
  echo "- custom note" >> "$REPO/.smokejumper/repo-knowledge.md"
  run "$SJ" init "$REPO"
  [ "$status" -eq 0 ]
  grep -q "custom note" "$REPO/.smokejumper/repo-knowledge.md"
}

@test "init refuses a non-git directory" {
  run "$SJ" init "$NONREPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a git repository"* ]]
}

@test "init refuses a missing directory" {
  run "$SJ" init "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -ne 0 ]
}

@test "init honors SJ_STATE_DIR override" {
  SJ_STATE_DIR=".sj-custom" run "$SJ" init "$REPO"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.sj-custom/repo-knowledge.md" ]
  [ ! -d "$REPO/.smokejumper" ]
}

@test "deprecated sj-init.sh shim still works" {
  run "$SJ_SCRIPTS/sj-init.sh" "$REPO"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.smokejumper/repo-knowledge.md" ]
}
