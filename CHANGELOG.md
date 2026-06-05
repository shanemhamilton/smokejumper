# Changelog

All notable changes to SmokeJumper are documented here. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]
### Changed
- Pinned `anthropic-skills:handoff-prompt` to `0.1.0` in the dependency manifest now that its upstream ([shanemhamilton/handoff-prompt-skill](https://github.com/shanemhamilton/handoff-prompt-skill)) published its first release. The drift check now tracks it instead of treating it as unpinned.

## [0.8.0] - 2026-06-04
### Added
- **bugsweep wired in as an optional REVIEW-phase backend** ([shanemhamilton/bugsweep](https://github.com/shanemhamilton/bugsweep), pinned 0.3.1). When detected (`adapter.capabilities.bugsweep`), Phase 5 REVIEW may run a deep adversarial bug-hunt (Hunter → Skeptic → Referee) over the change before push; confirmed findings are blockers to fix, additive to the gate, never a replacement. Absent → skipped, no functional loss. Added to the dependency manifest, adapter detection, and portability contract.

### Changed
- **`anthropic-skills:handoff-prompt` now tracks its real upstream** ([shanemhamilton/handoff-prompt-skill](https://github.com/shanemhamilton/handoff-prompt-skill)) instead of being marked `manual` in the dependency manifest. It tracks silently until the repo cuts its first release/tag.

## [0.7.0] - 2026-06-04
### Added
- **Declared dependency manifest** (`skills/smokejumper/references/dependencies.json` + `dependencies.md`). The projects SmokeJumper composes — choo-choo-ralph, metaswarm, product-pilot (vendored), anthropic-skills:handoff-prompt, Beads, Codex, gh — are now explicit and trackable, each with `kind` / `source` / `detect` / `pin` / `absentBehavior`. Adding a dependency is one JSON entry; the adapter and the dependency check both read this single source of truth.
- **Dependency drift check** (`skills/smokejumper/scripts/sj-deps-check.sh`), wired into "Before You Start" beside the self version check. **Pin → notify → opt-in:** at sprint start it notifies (fail-silent, time-boxed, 12h-cached) when an upstream has moved past its pinned/tested version; `--update` bumps the pins and prints the upgrade commands. It never auto-upgrades and never overwrites the vendored product-context copy — matching the project's "pin exact, test first" dependency rules.
- **Scheduled upstream scan** (`.github/workflows/dependency-scan.yml`): weekly + manual; runs the drift check in this repo and opens/updates an issue when an upstream moves — the "scan for stability" lane that keeps the plugin current without touching anyone's sprint.
- **metaswarm wired in as an optional adversarial-gate backend.** When detected (`adapter.capabilities.metaswarm`, Claude Code runtime), the PLAN / REVIEW / INTEGRATE gates may route through `metaswarm:plan-review-gate` / `design-review-gate` / `orchestrated-execution` / `pr-shepherd`. Gate precedence is **project-specific gates → metaswarm → bundled fallback**; absent or under a non-Claude runtime, the bundled flow applies with no functional loss.

### Changed
- `sj-adapter-scan.sh` capability detection now finds skills installed as **plugins** (under `~/.claude/plugins/`), not only `~/.claude/skills/` dirs — fixing false negatives for choo-choo-ralph and metaswarm. Adds `adapter.capabilities.metaswarm`.

## [0.6.0] - 2026-06-04
### Added
- **Runtime portability for non-Claude orchestrators** (`skills/smokejumper/references/runtime.md`, `SKILL.md`). Where v0.4.0 made SmokeJumper *installable* under Codex, this makes it *behave correctly* when a Codex agent **orchestrates** the sprint. A runtime preflight in RECON self-identifies the orchestrator. When subagent dispatch and the Skill tool are unavailable, leads and reviewers are *adopted inline* by reading their definition files, and the embedded reference files are used directly. The three lead agents and the portability contract now state the adopt-vs-dispatch model explicitly. Fixes the silent no-op where lead establishment never happened under a Codex orchestrator.
- **Deterministic, visible lead establishment** (`skills/smokejumper/scripts/sj-adapter-scan.sh`). The adapter scan previously existed only as prose in `references/adapter.md`; it is now an executable script that resolves leads/gates/capabilities by filename pattern, writes `## Lead & gate mapping` + `## Capabilities` into `repo-knowledge.md`, emits `agent_resolved` / `capability_*` / `leads_established` events to `sprint-log.jsonl`, and prints a **"Leads established" banner**. On a brand-new repo it prints the resolved BUNDLED fallback set — a visible artifact instead of a silent no-op.
- **Embedded product-context bootstrap** (`skills/smokejumper/references/product-context.md`, `templates/product-context.md`). RECON now establishes a PRODUCT_PILOT-style product-context brief **before DECIDE** — reading an existing one (Context mode) or bootstrapping one via a compact discovery interview when none exists (Setup mode, the greenfield case). DECIDE reads it as authoritative instead of "inferring from the README + tracker"; LESSONS LEARNED updates it (Update mode). Self-contained — **no dependency on any external skill** or the Skill tool. Anti-fabrication rules mark unknowns `[TODO]` and never invent metrics, competitors, or commit hashes.
- **Greenfield RECON branch** (`skills/smokejumper/references/recon.md`). On a near-empty repo, RECON inverts priorities: bundled leads are the expected result (not a failure), product context becomes the primary deliverable, and empty stack/build sections are recorded honestly rather than fabricated.

### Changed
- SmokeJumper's portability contract no longer hard-requires the Claude Code runtime. It hard-requires a git repo + the bundled agents/skill/scripts, runs best under Claude Code, and degrades to inline persona adoption under any other orchestrator (`SKILL.md`, `README.md`, `references/adapter.md`).
- **Gate roles and safety/invariant guardians resolve from the target repo's `.claude/agents/` only** (`scripts/sj-adapter-scan.sh`, `references/adapter.md`), never the global dir — a foreign project's gate is misleading and a foreign guardian is unsafe. Leads and generic implementers keep the global fallback.

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
