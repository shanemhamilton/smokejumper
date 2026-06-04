# SmokeJumper Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build SmokeJumper — a portable, marketplace-installable Claude Code plugin (a drop-in autonomous product-development crew) — then validate it by running Deployment #1 against MySkinIQ.

**Architecture:** ~90% markdown. A plugin repo (`~/Documents/SmokeJumper/`) bundles three portable lead agents + one `/smokejumper` orchestrator skill (8-phase lifecycle) + six reference files + one scaffolding script. Execution forks into a synchronous Claude+Codex crew lane and an async choo-choo-ralph "big pour" (Codex) lane; the adversarial review gate is front-loaded onto the design+plan so authorized pours can run unattended. State persists per-repo in `<target>/.smokejumper/`.

**Tech Stack:** Claude Code plugin system (`claude plugin` CLI, v2.1.156 verified), markdown agent/skill definitions, choo-choo-ralph (beads molecules + `nohup ./ralph.sh &`), Codex CLI (`model_reasoning_effort="high"`), bugsweep-derived recon/persistence patterns.

**Verification model (read before executing):** This plan replaces code-TDD with artifact-appropriate verification gates:
- **Manifests** → `claude plugin validate <path>` must pass.
- **Generic leads** → `grep` must find ZERO project-specific tokens (`myskiniq`, `firebase`, `firestore`, `digital atelier`, `allergen`).
- **Skill/agents discoverable** → `claude plugin details smokejumper` lists them; `/smokejumper` resolves after install.
- **Script** → real shell test against a temp dir asserting created structure.
- **Whole framework** → the Deployment #1 dogfood is the integration test, with five explicit in-session gates (Task 14).

For large prose artifacts (agents, SKILL.md, references) each task gives a complete **content specification** — verbatim frontmatter, section-by-section requirements, the source file to generalize from, and rules that MUST appear verbatim — not a full ghost-written file. This is a deliberate adaptation, not a placeholder.

**Source files to generalize from (read these during the relevant tasks):**
- `~/Documents/myskiniq-workspace/.claude/agents/myskiniq-product-lead.md`
- `~/Documents/myskiniq-workspace/.claude/agents/myskiniq-design-lead.md`
- `~/Documents/myskiniq-workspace/.claude/agents/myskiniq-engineering-lead.md`
- `~/Documents/bugsweep/bugsweep/SKILL.md` + `references/context-and-continuity.md` + `prompts/context-build.md`
- Spec: `~/Documents/SmokeJumper/docs/specs/2026-06-04-smokejumper-framework-design.md`

**All paths below are absolute. All `git` commands run inside `~/Documents/SmokeJumper/` unless stated otherwise.**

---

## File Structure (decomposition lock-in)

| Path (under `~/Documents/SmokeJumper/`) | Responsibility |
|---|---|
| `.claude-plugin/plugin.json` | Plugin identity + version (SemVer source of truth alongside VERSION) |
| `.claude-plugin/marketplace.json` | Local marketplace entry → makes it installable |
| `VERSION` | Human-readable version mirror |
| `.gitignore` | Exclude OS/editor cruft |
| `agents/smokejumper-engineering-lead.md` | ORCHESTRATOR lead: decompose → route lanes → dispatch → gate → push |
| `agents/smokejumper-product-lead.md` | Decides WHAT (assess → prioritize → spec) |
| `agents/smokejumper-design-lead.md` | UX/design direction for user-facing work |
| `skills/smokejumper/SKILL.md` | The 8-phase orchestrator spine; the `/smokejumper` entry point |
| `skills/smokejumper/references/recon.md` | Repo-architecture-modeling + load repo-knowledge |
| `skills/smokejumper/references/repo-knowledge-schema.md` | Schema for `<target>/.smokejumper/*` |
| `skills/smokejumper/references/adapter.md` | Lead + capability naming-convention detection |
| `skills/smokejumper/references/gated-pour.md` | Two-lane routing + Codex pour + front-loaded gate |
| `skills/smokejumper/references/self-healing.md` | Author-a-missing-agent protocol |
| `skills/smokejumper/references/lessons-learned.md` | Dual write-back + SemVer bump rules |
| `skills/smokejumper/scripts/sj-init.sh` | Deterministic scaffolding of `<target>/.smokejumper/` |
| `README.md` | Lifecycle, install (latest + pinned), self-improvement |
| `CHANGELOG.md` | One entry per deployment |

---

## Task 1: Plugin scaffold + manifests (validation gate)

**Files:**
- Create: `~/Documents/SmokeJumper/.claude-plugin/plugin.json`
- Create: `~/Documents/SmokeJumper/.claude-plugin/marketplace.json`
- Create: `~/Documents/SmokeJumper/VERSION`
- Create: `~/Documents/SmokeJumper/.gitignore`
- Create: `~/Documents/SmokeJumper/README.md` (stub — fleshed out in Task 12)
- Create: `~/Documents/SmokeJumper/CHANGELOG.md` (stub — fleshed out in Task 15)

- [ ] **Step 1: Write `plugin.json`**

```json
{
  "name": "smokejumper",
  "version": "0.1.0",
  "description": "Drop-in autonomous product-development crew — lands cold in any repo, assesses, decides the highest-leverage move, executes via Claude+Codex agents and multi-day Ralph pours, gates every push through adversarial review, and compounds its own intelligence each deployment.",
  "author": { "name": "Shane Hamilton" },
  "homepage": "https://github.com/shanemhamilton/smokejumper",
  "repository": "https://github.com/shanemhamilton/smokejumper",
  "license": "MIT",
  "keywords": ["orchestration", "agents", "autonomous", "ralph", "codex", "adversarial-review", "product-development", "portable"]
}
```

- [ ] **Step 2: Write `marketplace.json`**

```json
{
  "name": "smokejumper-local",
  "owner": { "name": "Shane Hamilton" },
  "metadata": {
    "description": "Local marketplace for the SmokeJumper plugin",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "smokejumper",
      "source": ".",
      "description": "Drop-in autonomous product-development crew.",
      "version": "0.1.0"
    }
  ]
}
```

- [ ] **Step 3: Write `VERSION`, `.gitignore`, and doc stubs**

`VERSION`:
```
0.1.0
```

`.gitignore`:
```
.DS_Store
*.log
node_modules/
tmp/
```

`README.md` (stub):
```markdown
# SmokeJumper

Drop-in autonomous product-development crew for Claude Code. See `docs/specs/` for the design. Full docs added in v0.1.0 finalization.
```

`CHANGELOG.md` (stub):
```markdown
# Changelog

All notable changes to SmokeJumper are documented here. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]
```

- [ ] **Step 4: Validate the manifests**

Run: `claude plugin validate ~/Documents/SmokeJumper`
Expected: PASS (valid plugin + marketplace manifest).
**If it fails on the `source: "."` field:** try `"source": {"source": "directory", "path": "."}` or consult `claude plugin validate` output; the source must resolve to the repo root where `plugin.json` lives. Re-run until PASS. Record the working form — it's the one uncertain mechanism in the build.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/SmokeJumper
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json VERSION .gitignore README.md CHANGELOG.md
git commit -m "feat: plugin scaffold + manifests (validate green)"
```

---

## Task 2: Portable engineering-lead agent

**Files:**
- Create: `~/Documents/SmokeJumper/agents/smokejumper-engineering-lead.md`
- Read first: `~/Documents/myskiniq-workspace/.claude/agents/myskiniq-engineering-lead.md`

- [ ] **Step 1: Read the source agent** to internalize its 5-stage flow, dispatch roster, 7-step gate sequence, git discipline, and prohibitions.

- [ ] **Step 2: Write the generalized agent.** Frontmatter (verbatim):

```yaml
---
name: smokejumper-engineering-lead
description: Portable autonomous Engineering Lead. OWNS builds end-to-end inside a SmokeJumper sprint — decomposes work, ROUTES each unit to the synchronous crew lane or the async Ralph big-pour lane, dispatches Claude + Codex agents, drives every quality gate to merged+pushed. Prefers a project-specific engineering lead when the SmokeJumper adapter detects one. Never edits safety-critical logic directly (routes to guardian agents); never deploys/releases without explicit human greenlight (merging ≠ deploying); never bypasses a gate.
model: opus
---
```

Body MUST contain these sections, generalized from the source (replace every MySkinIQ/Firebase/beads-specific reference with detected-at-runtime equivalents from RECON):
1. **Operating model** — DRIVER not CREATOR; takes vetted design+plan from product/design leads.
2. **Five-stage flow** — Plan → Decompose → **Route lanes** (NEW: apply the gated-pour decision table) → Dispatch → Gate → Integrate → Push.
3. **Lane routing** — embed the decision table from the spec §5 Phase 4 (Lane A pour vs Lane B synchronous; safety-critical NEVER poured).
4. **Dispatch roster** — generic roles (implementation agent, reviewer, domain guardian) resolved from the adapter, not hardcoded names; Codex for bulk/self-contained (`model_reasoning_effort="high"`); Sonnet floor for Claude work, escalate to Opus per detected conventions; never Haiku.
5. **Gate sequence** — Plan-review (front-loaded, authorizes pours) → per-child mechanical gates (Lane A) → full adversarial flow (Lane B) → milestone spot-check → `.adversarial-review-passed` only when obligations met.
6. **Git discipline** — honor target-repo conventions detected in RECON (e.g., submodule-first); "not done until `git push` succeeds"; merging ≠ deploying.
7. **Prohibitions** — no direct edits to safety-critical logic; no deploy without greenlight; no `--no-verify`; no bypassing gates.

Rules that MUST appear verbatim:
- "Merging is not deploying. Never run a deploy or release without explicit human greenlight."
- "Safety-critical units are never poured. They run in the synchronous lane and route to guardian agents."

- [ ] **Step 3: Verify zero project leakage**

Run: `grep -riE 'myskiniq|firebase|firestore|digital atelier|allergen|\.beads' ~/Documents/SmokeJumper/agents/smokejumper-engineering-lead.md`
Expected: NO matches (exit 1 / empty output). If any match, generalize it and re-run.

- [ ] **Step 4: Verify frontmatter parses**

Run: `head -5 ~/Documents/SmokeJumper/agents/smokejumper-engineering-lead.md`
Expected: valid YAML frontmatter with `name:` and `description:` and `model: opus`.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/SmokeJumper
git add agents/smokejumper-engineering-lead.md
git commit -m "feat: portable engineering-lead orchestrator agent"
```

---

## Task 3: Portable product-lead agent

**Files:**
- Create: `~/Documents/SmokeJumper/agents/smokejumper-product-lead.md`
- Read first: `~/Documents/myskiniq-workspace/.claude/agents/myskiniq-product-lead.md`

- [ ] **Step 1: Read the source agent** (outcome-driven philosophy, creator-not-certifier, anti-hallucination gates, handoff protocol).

- [ ] **Step 2: Write the generalized agent.** Frontmatter (verbatim):

```yaml
---
name: smokejumper-product-lead
description: Portable autonomous Lead Product Manager. Inside a SmokeJumper sprint, decides WHAT to build next — assesses product state, prioritizes by leverage, writes the spec/plan. CREATOR, not certifier: hands finished work to the adversarial review gate and never self-certifies. Prefers a project-specific product lead when the SmokeJumper adapter detects one. Escalates to the human only for product strategy / budget / release authority. Never edits safety-critical logic.
model: opus
---
```

Body MUST contain (generalized — read product-doc locations from RECON, never hardcode):
1. **Operating principle** — separation of duties: produces strategy work, self-checks, hands to the gate; never self-certifies/commits.
2. **Decide protocol** — read whatever product docs + issue tracker + `.smokejumper/repo-knowledge.md` RECON surfaced; pick the highest-leverage move; autonomy to choose *what*, escalate only strategy/budget/release.
3. **Anti-hallucination gates** — never invent metric values, competitor facts, product names, or counts; trace every claim to a doc read this session or mark "TBD — needs measurement."
4. **Handoff protocol** — state "Ready for review gate — applicable reviewers: [list]" and stop.

Rule that MUST appear verbatim:
- "Escalate to the human only for product strategy, budget, or release authority. Everything else, decide or delegate."

- [ ] **Step 3: Verify zero project leakage**

Run: `grep -riE 'myskiniq|firebase|firestore|digital atelier|allergen|4\.3%' ~/Documents/SmokeJumper/agents/smokejumper-product-lead.md`
Expected: NO matches.

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/SmokeJumper
git add agents/smokejumper-product-lead.md
git commit -m "feat: portable product-lead agent"
```

---

## Task 4: Portable design-lead agent

**Files:**
- Create: `~/Documents/SmokeJumper/agents/smokejumper-design-lead.md`
- Read first: `~/Documents/myskiniq-workspace/.claude/agents/myskiniq-design-lead.md`

- [ ] **Step 1: Read the source agent.**

- [ ] **Step 2: Write the generalized agent.** Frontmatter (verbatim):

```yaml
---
name: smokejumper-design-lead
description: Portable autonomous Design Lead. Inside a SmokeJumper sprint, produces UX/design direction for user-facing work — flows, component patterns, microcopy, states, research synthesis. CREATOR, not certifier: hands finished work to the design review gate and never self-certifies. Prefers a project-specific design lead/director when the SmokeJumper adapter detects one. Reads the target's design system from RECON; never assumes a specific design language.
model: opus
---
```

Body MUST contain (generalized — design-system tokens come from RECON, never hardcode "Digital Atelier"):
1. **Operating principle** — produces design work, hands to the design gate, never self-certifies.
2. **Design protocol** — apply detected design system + WCAG 2.2 AA defaults (from the global accessibility rules); cover empty/loading/error states.
3. **Handoff protocol** — name the applicable design review gate and stop.

- [ ] **Step 3: Verify zero project leakage**

Run: `grep -riE 'myskiniq|digital atelier|--atelier|--sage|--terracotta' ~/Documents/SmokeJumper/agents/smokejumper-design-lead.md`
Expected: NO matches.

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/SmokeJumper
git add agents/smokejumper-design-lead.md
git commit -m "feat: portable design-lead agent"
```

---

## Task 5: The `/smokejumper` orchestrator SKILL.md

**Files:**
- Create: `~/Documents/SmokeJumper/skills/smokejumper/SKILL.md`
- Read first: spec §5 (the 8-phase lifecycle) + `~/Documents/bugsweep/bugsweep/SKILL.md` (structure model)

- [ ] **Step 1: Write the skill frontmatter (verbatim):**

```yaml
---
name: smokejumper
description: Run a SmokeJumper sprint — land in this repo, assess it, decide the highest-leverage next move, execute it through Claude+Codex agents and (when work decomposes) async Ralph pours, gate every push through adversarial review, push, run lessons-learned, and hand off. Use when the user says "smokejumper", "run a sprint", "deploy the crew", "what should we build next and build it", or wants autonomous end-to-end product development on this repo.
---
```

- [ ] **Step 2: Write the body** as the 8-phase spine. Each phase = a section with: what it does, which reference file to load, the exit condition. Phases (from spec §5): RECON (load `references/recon.md` + `references/adapter.md`), DECIDE (leads choose; load detected leads), PLAN (front-loaded adversarial gate; load `references/gated-pour.md` for lane marking), EXECUTE (two lanes; `references/gated-pour.md` + `references/self-healing.md`), REVIEW (layered), INTEGRATE (commit+push; merging≠deploying), LESSONS LEARNED (load `references/lessons-learned.md`), HANDOFF (`anthropic-skills:handoff-prompt`).

MUST include near the top a **"Checklist" block** instructing the worker to create one TodoWrite/tracker item per phase, and a **"State durability"** note pointing at `<target>/.smokejumper/sprint-log.jsonl` for resume-after-compaction.

MUST include verbatim: "The adversarial review gate is non-negotiable and is never a formality. `.adversarial-review-passed` must exist before any push of reviewed work."

- [ ] **Step 3: Verify structure**

Run: `grep -cE '^## ' ~/Documents/SmokeJumper/skills/smokejumper/SKILL.md`
Expected: ≥ 8 (one heading per phase, plus checklist/state sections).
Run: `grep -iE 'recon|decide|plan|execute|review|integrate|lessons|handoff' ~/Documents/SmokeJumper/skills/smokejumper/SKILL.md | wc -l`
Expected: all 8 phase names present.

- [ ] **Step 4: Verify zero project leakage**

Run: `grep -riE 'myskiniq|firebase|firestore' ~/Documents/SmokeJumper/skills/smokejumper/SKILL.md`
Expected: NO matches (examples may reference "a target repo", never MySkinIQ by name).

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/SmokeJumper
git add skills/smokejumper/SKILL.md
git commit -m "feat: /smokejumper 8-phase orchestrator skill"
```

---

## Task 6: Reference — recon + repo-knowledge schema

**Files:**
- Create: `~/Documents/SmokeJumper/skills/smokejumper/references/recon.md`
- Create: `~/Documents/SmokeJumper/skills/smokejumper/references/repo-knowledge-schema.md`
- Read first: `~/Documents/bugsweep/bugsweep/references/context-and-continuity.md` + `prompts/context-build.md`

- [ ] **Step 1: Write `recon.md`** — generalize bugsweep's repo-architecture-modeling: produce a compact repo model (entry points, stack, conventions, where safety/quality gates live, git discipline, available capabilities). MUST instruct: read existing `CLAUDE.md`/`AGENTS.md`, product docs, issue tracker, and load `<target>/.smokejumper/repo-knowledge.md` if present. MUST instruct running the adapter scan (Task 7) and the capability scan.

- [ ] **Step 2: Write `repo-knowledge-schema.md`** — define the three files (verbatim schema):

```
<target>/.smokejumper/
├── repo-knowledge.md   # durable markdown: ## Stack, ## Conventions, ## Gate locations,
│                       #   ## Lead mapping, ## Capabilities, ## Known traps, ## What worked / avoid
├── sprint-log.jsonl    # {"ts","phase","event","detail","molecule_id"} append-only
└── gaps.jsonl          # {"ts","kind":"missing-agent|missing-capability","name","resolution"}
```

- [ ] **Step 3: Verify**

Run: `ls ~/Documents/SmokeJumper/skills/smokejumper/references/recon.md ~/Documents/SmokeJumper/skills/smokejumper/references/repo-knowledge-schema.md`
Expected: both exist.
Run: `grep -c 'repo-knowledge.md' ~/Documents/SmokeJumper/skills/smokejumper/references/recon.md`
Expected: ≥ 1 (recon references loading the knowledge file).

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/SmokeJumper
git add skills/smokejumper/references/recon.md skills/smokejumper/references/repo-knowledge-schema.md
git commit -m "feat: recon + repo-knowledge schema references"
```

---

## Task 7: Reference — adapter (lead + capability detection)

**Files:**
- Create: `~/Documents/SmokeJumper/skills/smokejumper/references/adapter.md`

- [ ] **Step 1: Write `adapter.md`.** MUST specify:
  - **Lead detection:** scan `<target>/.claude/agents/*.md` for filename/`name:` patterns `*-product-lead`, `*-engineering-lead`, `*-design-*` (and design `*director*`/`*reviewer*` gate patterns). On match → prefer that agent for the role; else use the bundled `smokejumper-*-lead`.
  - **Capability detection:** check for `choo-choo-ralph` (look for `ralph.sh` / the plugin / `bd` beads), `metaswarm`, Codex CLI (`which codex`), issue tracker (`bd`/`.beads/`). Record results to `repo-knowledge.md` ## Capabilities.
  - **Degradation matrix** (verbatim from spec §8): map each present/absent condition to behavior. choo-choo-ralph absent → offer `choo-choo-ralph:install` else Lane-B-only + log gap. No tracker → state in `.smokejumper/` only.
  - **Hard requirements** (verbatim): "SmokeJumper hard-requires only a git repo, the Claude Code runtime, and the bundled agents + skill. Everything else is detected and adapted to."

- [ ] **Step 2: Verify**

Run: `grep -iE '\-product-lead|\-engineering-lead|\-design' ~/Documents/SmokeJumper/skills/smokejumper/references/adapter.md`
Expected: all three role patterns present.
Run: `grep -i 'choo-choo-ralph' ~/Documents/SmokeJumper/skills/smokejumper/references/adapter.md`
Expected: ≥ 1 match.

- [ ] **Step 3: Commit**

```bash
cd ~/Documents/SmokeJumper
git add skills/smokejumper/references/adapter.md
git commit -m "feat: adapter reference (lead + capability detection)"
```

---

## Task 8: Reference — gated-pour (two-lane execution)

**Files:**
- Create: `~/Documents/SmokeJumper/skills/smokejumper/references/gated-pour.md`

- [ ] **Step 1: Write `gated-pour.md`.** MUST specify:
  - **The decision table** (verbatim from spec §5 Phase 4) routing each unit to Lane A (pour) or Lane B (synchronous).
  - **Front-loaded gate rule** (verbatim): "PASS at the plan-time adversarial gate authorizes execution, including authorizing autonomous pours. The gate is never waived; it is relocated to the design and plan."
  - **Lane A protocol:** `choo-choo-ralph:spec` → `choo-choo-ralph:pour` → molecule whose child formula = Codex (`model_reasoning_effort="high"`) + per-child mechanical gates (tests/build/tsc/lint/coverage) → launch `nohup ./ralph.sh &` loop(s) on `bd ready --parent <mol-id>`.
  - **Lane B protocol:** Engineering Lead dispatches Claude+Codex through the full adversarial flow to merged+pushed.
  - **Safety exclusion** (verbatim): "Safety-critical units (scoring/allergen/ED/child-safety equivalents) are NEVER poured. No plan-review substitutes for a guardian reading the actual diff."
  - **Milestone spot-check:** at molecule milestones, a Claude adversarial spot-check samples completed children.

- [ ] **Step 2: Verify**

Run: `grep -iE 'lane a|lane b|nohup|model_reasoning_effort|never (be )?poured|safety' ~/Documents/SmokeJumper/skills/smokejumper/references/gated-pour.md | wc -l`
Expected: ≥ 5 (the load-bearing concepts are all present).

- [ ] **Step 3: Commit**

```bash
cd ~/Documents/SmokeJumper
git add skills/smokejumper/references/gated-pour.md
git commit -m "feat: gated-pour reference (two-lane execution + front-loaded gate)"
```

---

## Task 9: Reference — self-healing

**Files:**
- Create: `~/Documents/SmokeJumper/skills/smokejumper/references/self-healing.md`

- [ ] **Step 1: Write `self-healing.md`.** MUST specify: when a needed specialist agent is missing → author it (markdown frontmatter `name`/`description`/`tools`/`model`, Sonnet+ floor) → write to `<target>/.claude/agents/` → register + use this sprint → append the gap to `<target>/.smokejumper/gaps.jsonl`. MUST state (verbatim): "Self-healed agents land in the target repo, never auto-graduate into the plugin. Graduation is a deliberate, versioned framework decision when a gap recurs across repos."

- [ ] **Step 2: Verify**

Run: `grep -iE 'gaps.jsonl|\.claude/agents|never auto-graduate|graduat' ~/Documents/SmokeJumper/skills/smokejumper/references/self-healing.md | wc -l`
Expected: ≥ 3.

- [ ] **Step 3: Commit**

```bash
cd ~/Documents/SmokeJumper
git add skills/smokejumper/references/self-healing.md
git commit -m "feat: self-healing reference (author missing agents)"
```

---

## Task 10: Reference — lessons-learned

**Files:**
- Create: `~/Documents/SmokeJumper/skills/smokejumper/references/lessons-learned.md`

- [ ] **Step 1: Write `lessons-learned.md`.** MUST specify the dual write-back:
  - **(a) Per-repo:** enrich `<target>/.smokejumper/repo-knowledge.md`; use `choo-choo-ralph:harvest` when present to harvest from completed molecule children; commit to the target.
  - **(b) Framework:** if a portable improvement surfaced → versioned commit to the SmokeJumper repo: bump `VERSION` + `plugin.json` (SemVer) + add a `CHANGELOG.md` entry naming the deployment + optional `claude plugin tag`.
  - MUST state (verbatim): "The crew gets better every drop = a plugin version bump, never a mutation of loose files."

- [ ] **Step 2: Verify**

Run: `grep -iE 'repo-knowledge|harvest|CHANGELOG|SemVer|version bump' ~/Documents/SmokeJumper/skills/smokejumper/references/lessons-learned.md | wc -l`
Expected: ≥ 4.

- [ ] **Step 3: Commit**

```bash
cd ~/Documents/SmokeJumper
git add skills/smokejumper/references/lessons-learned.md
git commit -m "feat: lessons-learned reference (dual write-back + SemVer)"
```

---

## Task 11: Scaffolding script `sj-init.sh`

**Files:**
- Create: `~/Documents/SmokeJumper/skills/smokejumper/scripts/sj-init.sh`

- [ ] **Step 1: Write the script**

```bash
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

## Gate locations

## Lead mapping

## Capabilities

## Known traps

## What worked / What to avoid
EOF
fi

touch "$SJ_DIR/sprint-log.jsonl" "$SJ_DIR/gaps.jsonl"

echo "Initialized $SJ_DIR"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x ~/Documents/SmokeJumper/skills/smokejumper/scripts/sj-init.sh`

- [ ] **Step 3: Real shell test (temp dir)**

Run:
```bash
TMPD=$(mktemp -d)
bash ~/Documents/SmokeJumper/skills/smokejumper/scripts/sj-init.sh "$TMPD"
test -f "$TMPD/.smokejumper/repo-knowledge.md" && \
test -f "$TMPD/.smokejumper/sprint-log.jsonl" && \
test -f "$TMPD/.smokejumper/gaps.jsonl" && \
grep -q "## Capabilities" "$TMPD/.smokejumper/repo-knowledge.md" && \
echo "SJ-INIT-OK" || echo "SJ-INIT-FAIL"
# idempotency: second run must not error and must not clobber
echo "edit" >> "$TMPD/.smokejumper/repo-knowledge.md"
bash ~/Documents/SmokeJumper/skills/smokejumper/scripts/sj-init.sh "$TMPD"
grep -q "edit" "$TMPD/.smokejumper/repo-knowledge.md" && echo "SJ-IDEMPOTENT-OK" || echo "SJ-IDEMPOTENT-FAIL"
rm -rf "$TMPD"
```
Expected: `SJ-INIT-OK` and `SJ-IDEMPOTENT-OK`.

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/SmokeJumper
git add skills/smokejumper/scripts/sj-init.sh
git commit -m "feat: sj-init.sh state scaffolding script (tested + idempotent)"
```

---

## Task 12: Finalize README

**Files:**
- Modify: `~/Documents/SmokeJumper/README.md`

- [ ] **Step 1: Write the full README** with sections: (1) one-line description; (2) Install — **latest** (`claude plugin marketplace add <github-url>` → `claude plugin install smokejumper@<marketplace>`) and **pinned** (the working source form from Task 1 Step 4, with a version ref); (3) the 8-phase lifecycle (link to spec); (4) Portability contract (the degradation matrix); (5) How it self-improves (dual write-back + version bump). Use the working install form recorded in Task 1.

- [ ] **Step 2: Verify**

Run: `grep -iE 'install|lifecycle|portab|self-improv' ~/Documents/SmokeJumper/README.md | wc -l`
Expected: ≥ 4.

- [ ] **Step 3: Commit**

```bash
cd ~/Documents/SmokeJumper
git add README.md
git commit -m "docs: full README (lifecycle, install, self-improvement)"
```

---

## Task 13: Local install + discovery smoke test (framework integration test)

**Files:** none created; this exercises the real install path.

- [ ] **Step 1: Register the local marketplace**

Run: `claude plugin marketplace add ~/Documents/SmokeJumper`
Expected: marketplace `smokejumper-local` added. (If already added: `claude plugin marketplace update smokejumper-local`.)

- [ ] **Step 2: Install the plugin**

Run: `claude plugin install smokejumper@smokejumper-local`
Expected: installs without error.

- [ ] **Step 3: Verify component discovery**

Run: `claude plugin details smokejumper`
Expected: inventory lists the `smokejumper` skill and the three `smokejumper-*-lead` agents.

- [ ] **Step 4: Verify slash-command resolution**

In a Claude Code session (or via `claude plugin details`), confirm `/smokejumper` resolves to the skill and the three agents are available as `subagent_type`.
Expected: `/smokejumper` present; agents loadable.
**If discovery fails:** the most likely cause is the `marketplace.json` `source` form — return to Task 1 Step 4, fix, `claude plugin marketplace update`, reinstall.

- [ ] **Step 5: Commit any fixes** (if Steps 1–4 forced manifest changes)

```bash
cd ~/Documents/SmokeJumper
git add -A && git commit -m "fix: manifest adjustments for local install + discovery"
```

---

## Task 14: Deployment #1 — dogfood sprint on MySkinIQ (integration test)

**This task is executed BY the framework.** Run `/smokejumper` in a Claude Code session rooted at `~/Documents/myskiniq-workspace/`. The leads decide the target at runtime (that is the dogfood). This task documents the **in-session validation gates** — all five MUST hold for the deployment to count as validated. Writes land in **Repo B** (MySkinIQ), not Repo A.

- [ ] **Step 1: Pre-flight** — confirm `/smokejumper` is installed (Task 13) and the MySkinIQ session has the adversarial review gate active (SessionStart hook clears `.adversarial-review-passed`).

- [ ] **Step 2: Run the sprint** — invoke `/smokejumper`. RECON runs `sj-init.sh` on the target and the adapter scan (MUST detect `myskiniq-product-lead`/`-engineering-lead`/`-design-lead` and prefer them — this proves the adapter). DECIDE picks a **substantial, decomposable, non-safety-critical** target. PLAN passes through the real adversarial gate.

- [ ] **Step 3: Validate gate 1 — adapter** — confirm the sprint log shows the three MySkinIQ leads detected and preferred over the generics.
Run: `grep -i 'lead' ~/Documents/myskiniq-workspace/.smokejumper/sprint-log.jsonl`
Expected: entries naming the `myskiniq-*-lead` agents.

- [ ] **Step 4: Validate gate 2 — plan gated** — confirm the design+plan passed the adversarial flow (antisycophancy-gate PASS) before any execution.

- [ ] **Step 5: Validate gate 3 — pour well-formed** — confirm a beads molecule was poured and resolves.
Run: `bd ready --parent <mol-id>` (mol-id from the sprint log)
Expected: child steps listed.

- [ ] **Step 6: Validate gate 4 — Lane A child lands** — confirm at least one poured child passed its mechanical gates (tests/build/coverage) and pushed.

- [ ] **Step 7: Validate gate 5 — Lane B unit ships** — confirm at least one synchronous-lane unit passed the full adversarial flow and pushed; and `<target>/.smokejumper/repo-knowledge.md` was enriched.

- [ ] **Step 8: Handoff** — confirm the sprint ended with an `anthropic-skills:handoff-prompt` that carries the running Ralph loop(s): molecule id, how to monitor (`bd ready --parent`), mechanical-gate status, when to harvest.

- [ ] **Step 9: Record** — the sprint's own INTEGRATE phase commits/pushes MySkinIQ changes (honoring submodule-first). Verify `git -C ~/Documents/myskiniq-workspace status` reflects committed work.

---

## Task 15: Framework lessons-learned → v0.2.0 + push both repos

**Files:**
- Modify: `~/Documents/SmokeJumper/VERSION`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`

- [ ] **Step 1: Synthesize portable learnings** from the dogfood (what RECON missed, adapter edge cases, gate friction, a roster gap worth bundling). Write them as concrete changes or a `CHANGELOG.md` v0.2.0 entry.

- [ ] **Step 2: Bump version** — set `VERSION` → `0.2.0`; update `version` in `plugin.json` and the plugin entry in `marketplace.json` to `0.2.0`.

- [ ] **Step 3: Write the CHANGELOG entry**

```markdown
## [0.2.0] - 2026-06-04
### Added
- Deployment #1 (MySkinIQ) learnings: <specific portable improvements>.
### Changed
- <recon/adapter/gate refinements derived from the dogfood>.
```

- [ ] **Step 4: Validate + tag**

Run: `claude plugin validate ~/Documents/SmokeJumper`
Expected: PASS.
Run: `cd ~/Documents/SmokeJumper && claude plugin tag .`
Expected: creates `smokejumper--v0.2.0` tag with manifests in agreement.

- [ ] **Step 5: Commit + push Repo A**

```bash
cd ~/Documents/SmokeJumper
git add VERSION .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "chore(release): v0.2.0 — Deployment #1 (MySkinIQ) learnings"
# Create the GitHub remote if it does not exist, then push:
gh repo create shanemhamilton/smokejumper --private --source=. --remote=origin --push 2>/dev/null || git push -u origin HEAD
git push --tags
```

- [ ] **Step 6: Confirm Repo B pushed** — the dogfood's INTEGRATE already pushed MySkinIQ; verify:
Run: `git -C ~/Documents/myskiniq-workspace status`
Expected: "up to date with origin".

---

## Self-Review (run before execution)

**Spec coverage:** Every spec section maps to a task — §3 layout→T1/T12, §4 leads+adapter→T2/T3/T4/T7, §5 lifecycle→T5+T6–T10, §6 repo-knowledge→T6/T11, §7 self-healing→T9, §8 portability→T7, §9 dogfood→T14, §10 build sequence→T1–T15, §11 YAGNI→honored (no engine, beads optional), §12 risks→install risk gated at T1/T13, pour-correctness at T8/T14.
**Placeholders:** none — large prose artifacts use explicit content specs with verbatim must-appear rules + verification greps; the only intentional runtime-filled blanks are the dogfood's leads-decide target and the v0.2.0 learnings (both genuinely unknowable until execution).
**Type/name consistency:** `.smokejumper/` schema (`repo-knowledge.md`, `sprint-log.jsonl`, `gaps.jsonl`) consistent across T6/T11/T14; agent names `smokejumper-{product,design,engineering}-lead` consistent across T2–T5, T13; `source` manifest form resolved once in T1 and reused in T12/T13.
