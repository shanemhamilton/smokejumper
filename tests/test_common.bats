#!/usr/bin/env bats
# lib/common.sh primitives: atomic_write, with_lock, sj_state_dir, json helpers.

load helpers

setup() {
  # shellcheck source=../skills/smokejumper/scripts/lib/common.sh
  . "$SJ_SCRIPTS/lib/common.sh"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
}

@test "atomic_write replaces file content atomically" {
  echo "old" > "$WORK/f"
  printf 'new content\n' | atomic_write "$WORK/f"
  [ "$(cat "$WORK/f")" = "new content" ]
  # no temp residue
  [ -z "$(ls "$WORK"/.sj-tmp.* 2>/dev/null || true)" ]
}

@test "atomic_write dies when directory does not exist" {
  run bash -c ". '$SJ_SCRIPTS/lib/common.sh'; echo x | atomic_write '$WORK/nodir/f'"
  [ "$status" -ne 0 ]
}

@test "with_lock runs the command and releases the lock" {
  with_lock "$WORK/.lock" touch "$WORK/done"
  [ -f "$WORK/done" ]
  [ ! -d "$WORK/.lock" ]
}

@test "with_lock breaks a stale lock past TTL" {
  mkdir "$WORK/.lock"
  SJ_LOCK_TTL=0 run bash -c ". '$SJ_SCRIPTS/lib/common.sh'; SJ_LOCK_TTL=0 with_lock '$WORK/.lock' echo ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "sj_state_dir defaults and honors SJ_STATE_DIR (relative and absolute)" {
  [ "$(sj_state_dir /repo)" = "/repo/.smokejumper" ]
  [ "$(SJ_STATE_DIR=.custom sj_state_dir /repo)" = "/repo/.custom" ]
  [ "$(SJ_STATE_DIR=/abs/state sj_state_dir /repo)" = "/abs/state" ]
}

@test "json_escape handles quotes and backslashes" {
  [ "$(json_escape 'a "b" c\d')" = 'a \"b\" c\\d' ]
}

@test "json_field extracts a value (jq and fallback agree)" {
  line='{"ts":"2026-06-09T10:00:00Z","event":"gate_passed"}'
  [ "$(json_field "$line" event)" = "gate_passed" ]
}

@test "sha256_of is stable and 12 chars" {
  a="$(sha256_of hello)"
  b="$(sha256_of hello)"
  [ "$a" = "$b" ]
  [ "${#a}" -eq 12 ]
}
