#!/usr/bin/env bash
# sj-init.sh — scaffold a target repo's .smokejumper/ state directory (idempotent).
# Usage: sj-init.sh <target-repo-root>
set -euo pipefail

TARGET="${1:?usage: sj-init.sh <target-repo-root>}"
SJ_DIR="$TARGET/.smokejumper"

mkdir -p "$SJ_DIR"

if [ ! -f "$SJ_DIR/repo-knowledge.md" ]; then
  cat > "$SJ_DIR/repo-knowledge.md" <<'EOF'
# Repo Knowledge (SmokeJumper)

Durable, accumulative knowledge for this repo. RECON loads this on arrival; LESSONS-LEARNED enriches it on departure.

## Stack

## Conventions

## Build / test / lint commands

## Gate locations

## Design system

## Lead & gate mapping

## Model tier

## Capabilities

## Design skills

## Known traps

## What worked / What to avoid

## Framework improvements pending
EOF
fi

touch "$SJ_DIR/sprint-log.jsonl" "$SJ_DIR/gaps.jsonl"

echo "Initialized $SJ_DIR"
