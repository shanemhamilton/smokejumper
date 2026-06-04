# Changelog

All notable changes to SmokeJumper are documented here. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

## [0.5.0] - 2026-06-04
### Added
- **Update check at sprint start** (`skills/smokejumper/scripts/sj-version-check.sh`, wired into `SKILL.md`'s "Before You Start"). The first action of every sprint compares the installed `VERSION` against the latest published GitHub release and, if behind, prints a one-line notice with the per-runtime upgrade command (`claude`/`codex plugin marketplace upgrade smokejumper`). Notify-only — it never auto-applies an upgrade and never gates the sprint. Fail-silent and time-boxed (5s): missing `curl`, no network, API errors, or rate limits produce no output, so a sprint never stalls on the check.

## [0.4.0] - 2026-06-04
### Added
- **Codex runtime support.** SmokeJumper installs in OpenAI Codex CLI from the same `.claude-plugin/marketplace.json` it uses for Claude Code — verified against `codex plugin marketplace add` (Codex 0.130). README now documents install for both runtimes.
- **Codex skill-discovery metadata** (`skills/smokejumper/agents/openai.yaml`): `display_name`, `short_description`, and `default_prompt` for Codex's plugin UI, mirroring the convention used by sibling dual-runtime skills.

### Changed
- **Marketplace renamed `smokejumper-local` → `smokejumper`** (`.claude-plugin/marketplace.json`). The manifest name is the registered marketplace name in both runtimes, so the GitHub install is now consistently `smokejumper@smokejumper` (the previous `smokejumper@smokejumper-local` in the README's "Latest" path never matched the manifest). Local and GitHub installs differ only by the `marketplace add` source.
- **Generalized the engineering-lead's dispatch wording** (`agents/smokejumper-engineering-lead.md`): "Team Mode / Task Mode" is now framed as runtime-neutral parallel-vs-sequential dispatch, with Claude Code's Team Mode and Codex's `codex exec` named as examples rather than requirements. Sibling-skill references in `SKILL.md` already degrade gracefully, so no functional change was needed there.
- Added `claude-code` to plugin keywords.

## [0.3.0] - 2026-06-04
### Added
- **Contributor write-back path in LESSONS LEARNED** (`skills/smokejumper/SKILL.md`, `references/lessons-learned.md`). Phase 7's framework write-back now branches on whether the sprint runs inside the canonical plugin repo. Inside it, portable improvements are committed directly (existing behavior, now "Mode A"). Anywhere else — the common case, where the plugin is installed rather than a pushable git checkout — the improvement is generalized, **scrubbed of all target-repo specifics**, and the user is encouraged to open an upstream pull request so every deployment benefits ("Mode B"). Mode B never auto-forks, auto-commits, or auto-opens a PR: it prepares the materials and hands over the commands. Adds the `plugin_pr_suggested` sprint-log event.
- **`CONTRIBUTING.md` learnings-contribution guidance**: how to generalize/scrub and open a learning PR, plus the rule that external PRs add an `## Unreleased` entry rather than bumping `VERSION` (the maintainer assigns the version at merge).

## [0.2.0] - 2026-06-04
### Added
- **Concurrent-session detection in RECON** (`references/recon.md`). Deployment #1 (MySkinIQ) ran in a shared working tree where parallel Claude sessions advanced the branch and tripped a "docs N commits stale" pre-commit guard, blocking the sprint's own commits and entangling another session's commit into the branch. RECON now detects concurrent-session signals (unstaged files you didn't touch, unauthored HEAD advancement, running loops) and isolates the sprint in a dedicated `git worktree` before INTEGRATE.

### Validated (Deployment #1 — MySkinIQ, the building dogfood)
- Adapter naming-convention scan correctly resolved all three project-specific leads (`myskiniq-*-lead`) and the full gate lineup over the bundled generics — zero config.
- Two-lane execution: a Lane B unit (M1 telemetry validation event set) was implemented and passed the real detected gate (`thesis-guardian` → ALIGNED, surfaced 4 doc-precision defects, fixed); the deferred batch poured into a well-formed 4-child Lane A molecule (`bd ready --parent` resolves), ready to launch.
- Front-loaded gate + safety exclusion held: no scoring/allergen/ED logic touched.

### Notes
- Deployment #1's Lane B push remains blocked by the target repo's shared-tree freshness guard pending the operator's call (`--no-verify` bypass vs Pilot refresh) — captured in the sprint handoff, not a framework defect.

## [0.1.0] - 2026-06-04
### Added
- Initial SmokeJumper plugin: portable Product/Design/Engineering lead agents, the `/smokejumper` 8-phase orchestrator skill, six reference files (recon, repo-knowledge-schema, adapter, gated-pour, self-healing, lessons-learned), the `sj-init.sh` state-scaffolding script, manifests, and README. Validates + installs via the local marketplace.
