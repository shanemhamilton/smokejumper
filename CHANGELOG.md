# Changelog

All notable changes to SmokeJumper are documented here. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

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
