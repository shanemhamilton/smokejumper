# Reference: Per-Repo State Schema

SmokeJumper writes durable state into the target repo at `.smokejumper/`. This directory
is created by the plugin on first sprint and is committed to the target repo's version
control — it is the project's accumulating record of sprint history and framework
learnings.

---

## Directory layout

```
<target>/.smokejumper/
  repo-knowledge.md      # Durable, human-readable architecture model (accumulative)
  sprint-log.jsonl       # Append-only event ledger (one JSON object per line)
  gaps.jsonl             # Missing-agent / missing-capability gaps (one JSON object per line)
```

---

## `repo-knowledge.md` — Architecture model

One Markdown file. Updated in place each sprint (never replaced wholesale). Structure:

```markdown
# Repo Knowledge

## Stack
# language, runtime, framework, primary storage, key external services — one line each

## Conventions
# naming conventions, formatter, branch naming, test file location — from CLAUDE.md + observation

## Build / test / lint commands
# exact commands; mark UNVERIFIED if uncertain

## Gate locations
# CI file paths, pre-commit hooks, coverage config, safety-critical logic locations

## Lead mapping
# resolved lead agents for most recent sprint (project-specific or bundled fallback)

## Capabilities
# async loop tool: present/absent, Codex CLI: present/absent, issue tracker: type + commands

## Known traps
# per-sprint accumulated gotchas — never deleted, only appended

## What worked / What to avoid
# execution patterns that proved effective or problematic — never deleted, only appended

## Framework improvements pending
# portable insights queued for lessons-learned write-back — cleared after each successful
# write-back to the plugin repo; a new entry starts the queue again
```

**Write discipline:**
- `## Known traps`, `## What worked / What to avoid`, and `## Framework improvements pending`
  are append-only. Prior entries survive every sprint.
- Other sections are refreshed each RECON, but only when the observed reality has changed.
  If prior content is still accurate, leave it.
- Never truncate this file to save space. It is the project's institutional memory.

---

## `sprint-log.jsonl` — Event ledger

One JSON object per line. Append-only. Never edit existing lines.

### Schema

```json
{
  "ts": "<ISO-8601 timestamp>",
  "sprint": "<sprint-id, e.g. sprint-2026-06-04>",
  "phase": "<RECON|DECIDE|PLAN|EXECUTE|REVIEW|INTEGRATE|LESSONS_LEARNED|HANDOFF>",
  "event": "<event type — see event vocabulary below>",
  "detail": "<human-readable description of what happened>",
  "outcome": "<success|skipped|blocked|failed — optional>",
  "ref": "<bead ID, PR number, commit SHA, or other external reference — optional>"
}
```

### Event vocabulary

| `event` value | When to emit |
|---|---|
| `phase_start` | Beginning of each phase |
| `phase_complete` | Successful completion of each phase |
| `gate_passed` | Any review gate passed (plan gate, adversarial review, coverage gate) |
| `gate_failed` | Any review gate failed — include blocker detail |
| `lane_selected` | A (pour/async) or B (synchronous) chosen, with rationale |
| `agent_resolved` | Lead or gate agent resolved (project-specific or bundled fallback) |
| `capability_detected` | A tool or capability found in the target repo |
| `capability_absent` | A tool or capability not found; degradation noted |
| `work_item_created` | Issue/bead created in the tracker |
| `work_item_closed` | Issue/bead closed |
| `pr_created` | Pull request opened |
| `pr_merged` | Pull request merged |
| `gap_logged` | A missing-agent gap written to gaps.jsonl |
| `self_heal_authored` | A missing agent was authored and written to .claude/agents/ |
| `lessons_written` | repo-knowledge.md updated (LESSONS LEARNED phase) |
| `plugin_bump_queued` | A portable improvement queued for plugin write-back |
| `plugin_bump_committed` | Plugin version bump committed to plugin repo |
| `sprint_complete` | Sprint closed out |

---

## `gaps.jsonl` — Missing-agent gaps

One JSON object per line. Append-only. Tracks every specialist agent or capability that
was absent in the target repo and either blocked work or was self-healed.

### Schema

```json
{
  "ts": "<ISO-8601 timestamp>",
  "sprint": "<sprint-id>",
  "gap_type": "<missing_agent|missing_capability>",
  "description": "<what was absent and why it was needed>",
  "resolution": "<self_healed|degraded_gracefully|blocked_lane_a|none>",
  "authored_path": "<path to authored agent file, if self_healed — else omit>",
  "portable": "<true if this gap + resolution is worth surfacing to the plugin — else false>",
  "notes": "<optional free-text — e.g. suggested plugin improvement>"
}
```

**`gap_type` values:**

- `missing_agent` — a needed specialist (review role, domain expert) was absent in
  `.claude/agents/`; SmokeJumper either self-healed or fell back to a bundled generic
- `missing_capability` — a tool (async loop, Codex CLI, issue tracker) was absent;
  execution degraded gracefully per the portability table in `adapter.md`

---

## Initialization (first sprint)

On first sprint, the RECON phase creates `.smokejumper/` and writes empty (header-only)
versions of all three files. The `sprint-log.jsonl` gets its first `phase_start` entry.
No prior knowledge is assumed.

---

## Git discipline for `.smokejumper/`

The `.smokejumper/` directory is committed to the target repo's version control, not
gitignored. This makes sprint history auditable and portable across machines.

Commit these files alongside sprint work — not as a separate cleanup commit at the end.
Each phase that modifies `.smokejumper/` should include those file updates in the same
commit or the nearest logical commit.
