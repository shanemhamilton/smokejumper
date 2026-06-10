#!/usr/bin/env bash
# sj-init.sh — DEPRECATED shim. Use: sj init <target-repo-root>
# Kept for back-compat with pre-1.0 callers; delegates to the sj CLI.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/sj" init "$@"
