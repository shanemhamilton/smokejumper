#!/usr/bin/env bash
# lib/hooks.sh — optional git pre-push hook that enforces the gate evidence chain.
#
# Never installed by default. Refuses politely when the hooks dir is unwritable
# or a foreign pre-push hook already exists (use --force to overwrite a hook
# that sj itself installed).

hooks_usage() {
  cat <<'EOF'
usage: sj hooks install <target-repo-root> [--force]
EOF
}

_SJ_HOOK_SENTINEL="# installed-by: sj hooks install"

hooks_install() {
  local target="$1" force="${2:-0}"
  require_git_repo "$target"
  local hooks_dir hook sj_bin
  hooks_dir="$(git -C "$target" rev-parse --git-path hooks)"
  case "$hooks_dir" in /*) : ;; *) hooks_dir="$target/$hooks_dir" ;; esac
  hook="$hooks_dir/pre-push"
  sj_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/sj"

  if [ ! -d "$hooks_dir" ] || [ ! -w "$hooks_dir" ]; then
    echo "Cannot install: hooks directory is missing or unwritable ($hooks_dir). Skipping — the gate still works via 'sj gate check'."
    return 0
  fi
  if [ -f "$hook" ] && ! grep -qF "$_SJ_HOOK_SENTINEL" "$hook"; then
    echo "Cannot install: a pre-push hook already exists and was not installed by sj ($hook). Chain it manually: sj gate check adversarial-review --target <repo>"
    return 0
  fi
  if [ -f "$hook" ] && [ "$force" != 1 ]; then
    echo "sj pre-push hook already installed ($hook). Use --force to reinstall."
    return 0
  fi

  cat > "$hook" <<EOF
#!/usr/bin/env bash
$_SJ_HOOK_SENTINEL
# Blocks push unless the adversarial-review gate marker verifies against the
# sprint log and git history. Bypass (emergencies only): SJ_SKIP_GATE=1 git push
[ "\${SJ_SKIP_GATE:-0}" = 1 ] && exit 0
repo_root="\$(git rev-parse --show-toplevel)"
exec "$sj_bin" gate check adversarial-review --target "\$repo_root"
EOF
  chmod +x "$hook"
  echo "Installed pre-push gate hook → $hook"
}

hooks_main() {
  local action="${1:-}" target="${2:-}" force=0
  [ "$action" = install ] && [ -n "$target" ] || { hooks_usage; exit 1; }
  [ "${3:-}" = "--force" ] && force=1
  hooks_install "$target" "$force"
}
