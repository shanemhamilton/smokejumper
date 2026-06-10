# tests/helpers.bash — shared setup for the sj bats suite.

SJ_SCRIPTS="$BATS_TEST_DIRNAME/../skills/smokejumper/scripts"
SJ="$SJ_SCRIPTS/sj"

# make_fixture_repo <dir> — minimal git repo with one commit and a package.json.
make_fixture_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email sj-test@example.com
  git -C "$dir" config user.name "sj test"
  echo '{"name":"fixture","version":"1.0.0"}' > "$dir/package.json"
  git -C "$dir" add -A
  git -C "$dir" commit -qm "fixture: initial commit"
}

# make_non_repo <dir> — a plain directory that is NOT a git repo.
make_non_repo() {
  mkdir -p "$1"
  echo "not a repo" > "$1/file.txt"
}

# commit_in <dir> <msg> — add a throwaway commit.
commit_in() {
  echo "$RANDOM" >> "$1/churn.txt"
  git -C "$1" add -A
  git -C "$1" commit -qm "$2"
}
