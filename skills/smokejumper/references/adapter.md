# Reference: Adapter — Lead, Gate, and Capability Detection

The adapter layer runs during RECON (Phase 1) and resolves two things:
1. **Lead agents and gate roles** — who runs each phase and each review gate
2. **Capabilities** — which tools and orchestration primitives are available

SmokeJumper hard-requires only a git repo and the bundled agents + skill + scripts. It runs
best under the Claude Code runtime (subagent dispatch + skills) but degrades to inline
persona adoption under any other orchestrator (e.g. a Codex agent) — see
`references/runtime.md`. Everything else is detected and adapted to.

**Executable implementation.** The detection described in this file is implemented by
`scripts/sj-adapter-scan.sh`, which RECON runs. Running the script — rather than performing
the scan from memory — is what makes lead establishment a *visible, durable* artifact: it
writes the resolved mapping into `repo-knowledge.md`, emits `agent_resolved` /
`capability_*` / `leads_established` events to `sprint-log.jsonl`, and prints a "Leads
established" banner. This file is the human-readable spec the script implements; keep the
two in sync.

**Leads are personas, not mandatory subagents.** Resolving a lead name is step one;
*establishing* it means reading its definition file and adopting it (or dispatching it as a
subagent, where the runtime supports that) — see `references/runtime.md`. The adapter
resolves names; the orchestrator establishes the roles.

---

## Why the adapter exists

Every repo is different. A target repo may have its own specialist lead agents tuned to
its domain. It may have an async loop tool installed, or not. It may use beads (bd) as
its issue tracker, or GitHub Issues, or nothing at all.

The adapter makes the plugin behave correctly in all cases without requiring configuration
files or setup steps from the project owner.

---

## Lead agent resolution

During RECON, scan the target repo's `.claude/agents/` directory (and `~/.claude/agents/`
for globally installed agents) for the following patterns:

| Role | Detect by keyword in filename | Resolved key | If absent |
|---|---|---|---|
| Engineering lead | `engineering-lead` | (lead) | Use bundled `smokejumper-engineering-lead` |
| Product lead | `product-lead` | (lead) | Use bundled `smokejumper-product-lead` |
| Design lead | `design-lead` | (lead) | Use bundled `smokejumper-design-lead` |
| UI / frontend implementer | `ios`, `frontend`, `ui`, `web`, or equivalent | `adapter.agents.uiImplementer` | Use bundled generic implementer |
| Backend / API implementer | `backend`, `api`, `server`, or equivalent | `adapter.agents.backendImplementer` | Use bundled generic implementer |
| Safety / invariant guardian | filename/name contains `safety`, `guardian`, `invariant`, or equivalent | `adapter.agents.safetyGuardian` / `adapter.agents.invariantGuardian` | **If none detected: route safety-critical work to the human and log a missing-capability gap. NEVER auto-proceed on safety-critical without a guardian.** |
| Data audit / catalog | `audit`, `catalog`, `data`, or equivalent | `adapter.agents.dataAuditor` | Use bundled generic reviewer |
| Localization reviewer | `localization`, `l10n`, `translation`, or equivalent | `adapter.agents.localizationReviewer` | Skip localization gate |
| Design reviewer (gate) | `design-reviewer` or project-specific design-gating role | `adapter.gate.designReviewer` | Skip design gate |
| Product-thesis guardian (gate) | `thesis` + `guardian` or `product-thesis` variant | `adapter.gate.thesisGuardian` | Skip thesis gate |
| Review-integrity gate | `review-integrity` or `sycophancy` variant | `adapter.gate.reviewIntegrity` | Skip review-integrity gate |
| First-impression / first-use critic | `first-impression`, `first-use`, or equivalent | `adapter.gate.firstUseCritic` | Skip first-use gate |
| Quality control | `quality-control` or `qc` | `adapter.gate.qualityControl` | Use basic self-review checklist |

**Resolution priority:**
1. Project-specific agent in target `.claude/agents/` (most specific)
2. Globally installed project-specific agent in `~/.claude/agents/` with matching pattern
3. Bundled SmokeJumper generic agent
4. Skip / degrade gracefully (for gates only — leads always have a bundled fallback)

**Global dir scope (important correctness rule).** Leads and generic implementers (UI,
backend, data, localization) may resolve from `~/.claude/agents/` — a globally installed
agent there is plausibly intentional and a safe bundled/generic fallback exists if the match
is wrong. **Gate roles (`adapter.gate.*`) and the safety/invariant guardians resolve from the
target repo's `.claude/agents/` ONLY.** A gate or guardian pulled from the global dir is
almost always a *foreign* project's named agent, which is misleading in the banner and — for
a guardian — unsafe: absent must mean "route safety-critical work to the human", never
"borrow a stranger's guardian". `scripts/sj-adapter-scan.sh` enforces this split.

Record every resolution in `## Lead & gate mapping` in `repo-knowledge.md` and emit an
`agent_resolved` event to `sprint-log.jsonl`.

**Gate roles are adapter-conditional.** A gate exists in the sprint plan ONLY if the
corresponding agent was resolved. Never fabricate a gate role with a bundled agent —
gates exist to challenge output, and a generic challenger is weaker than nothing if the
context it needs (product thesis, design system, first-user experience) is not present.
Leads always have a bundled fallback; gates do not.

---

## Capability detection

| Capability | How to detect | If absent |
|---|---|---|
| Async loop tool (choo-choo-ralph or equivalent) | `which ralph`, or installed as a skill/plugin (`sj scan` checks `~/.claude/skills/` and `~/.claude/plugins/`) | Lane A (async pour) not available; all work routes to Lane B |
| Codex CLI | `which codex` | Async formula steps use Claude directly (slower); token budget impact noted |
| metaswarm (adversarial-gate backend) | installed as a skill dir or plugin under `~/.claude/plugins/` | Use SmokeJumper's bundled adversarial review flow — no functional loss |
| bugsweep (deep bug-hunt backend) | installed as a skill dir (`~/.claude/skills/bugsweep`) or plugin | Skip the optional bug-hunt pass in REVIEW — no functional loss |
| Issue tracker — beads/bd | `which bd` | State lives in `.smokejumper/` only; no bead IDs in sprint-log |
| Issue tracker — GitHub Issues | `gh issue list` exits 0 | Use gh for issue tracking |
| Issue tracker — none | Neither above found | Create a `sprint-plan.md` scratch tracker in `.smokejumper/` |
| Cloud/platform deploy config | `deploy.json`, platform config, or CI deploy job present | Deploy gate uses project-specific deploy command |
| Docker / container | `Dockerfile` present | Treat as containerized; note in capabilities |
| Product context layer | `docs/product/PRODUCT_PILOT.md`, `docs/product/*.md`, `PRODUCT.md`, or `.smokejumper/product-context.md` present | Recorded as `productContext: MISSING`; RECON runs Setup (`references/product-context.md`) before DECIDE |
| Design skills / plugins | `sj scan` scans `~/.claude/skills/*/SKILL.md`, `~/.claude/skills/gstack/*/SKILL.md`, and `frontend-design` in `~/.claude/plugins/installed_plugins.json` for design-review / design-consultation / accessibility / frontend-design skills | Recorded as `adapter.skills.design.*` (null per key); the design lead proceeds analytically — manual critique + a WCAG 2.2 AA check by hand |

Record all capability detections in `## Capabilities` in `repo-knowledge.md` and emit
`capability_detected` or `capability_absent` events to `sprint-log.jsonl`.

**Design skills resolve globally, not target-only.** Unlike gate roles (`adapter.gate.*`), design
skills are *capabilities* — installed tooling in `~/.claude/skills/` and `~/.claude/plugins/`, not
a target project's named agents. The target-only correctness rule does not apply: a globally
installed design skill is the intended, shared tool. The scan records which design skills exist;
the per-repo *effectiveness* of each (which to prefer next sprint) lives in the `## Design skills`
tally, written by LESSONS LEARNED — see `repo-knowledge-schema.md` and `lessons-learned.md`.

**Functional health → design posture.** The scan also derives a windowed `functionalHealth`
(POOR | FAIR | HEALTHY) from recent sprints and maps it to a `designPosture` (ADVISORY | WEIGHTED),
written into `## Capabilities` and emitted as a `design_posture_set` event. DECIDE reads
`designPosture` to weight design-debt objectives — prioritization only, never gating. See
`SKILL.md` Phase 2 and `smokejumper-product-lead.md`.

---

## Output schema

The adapter scan produces a single `adapter` object. It is recorded in
`repo-knowledge.md` (under `## Lead & gate mapping`, `## Capabilities`, and
`## Model tier`) and is what the SKILL.md orchestrator and the lead agents read at runtime
to resolve every agent name, gate, capability, and model tier. Consumers NEVER hardcode
project-specific agent names — they read from this object.

### `adapter.agents.*` — resolved implementation / specialist agent names

Each value is the resolved agent name (string), or `null`. `null` means: use the bundled
fallback, or — for `safetyGuardian` / `invariantGuardian` — route the work to the human
and log a gap (never auto-proceed on safety-critical without a guardian).

| Key | Role |
|---|---|
| `adapter.agents.uiImplementer` | UI / frontend implementation agent |
| `adapter.agents.backendImplementer` | Backend / API implementation agent |
| `adapter.agents.safetyGuardian` | Safety-critical logic guardian (null → human + gap) |
| `adapter.agents.invariantGuardian` | Scoring / invariant guardian (null → human + gap) |
| `adapter.agents.dataAuditor` | Data audit / catalog agent |
| `adapter.agents.localizationReviewer` | Localization / translation reviewer |

### `adapter.gate.*` — resolved gate-role agent names (each conditional / nullable)

Each value is the resolved gate-role agent name (string), or `null`. `null` means the gate
is skipped — a gate is never fabricated with a bundled generic.

| Key | Gate role |
|---|---|
| `adapter.gate.designReviewer` | Design review gate |
| `adapter.gate.thesisGuardian` | Product-thesis (positioning) guardian gate |
| `adapter.gate.reviewIntegrity` | Review-integrity (anti-sycophancy) gate |
| `adapter.gate.firstUseCritic` | First-impression / first-use critic gate |
| `adapter.gate.qualityControl` | Quality / correctness review gate |

### `adapter.capabilities.*` — booleans + list

| Key | Type | Meaning |
|---|---|---|
| `adapter.capabilities.tracker` | string \| null | Detected issue tracker (`"beads"`, `"github"`, or `null`) |
| `adapter.capabilities.asyncLoop` | boolean | Async loop tool present → Lane A available |
| `adapter.capabilities.codex` | boolean | Codex CLI present → cross-model review available |
| `adapter.capabilities.metaswarm` | boolean | metaswarm present → gate phases may route through it (Claude Code runtime); else bundled flow |
| `adapter.capabilities.bugsweep` | boolean | bugsweep present → may run a deep bug-hunt pass in REVIEW; else skip |
| `adapter.capabilities.syncFrameworks` | string[] | Detected synchronous execution frameworks (ask human if length > 1) |

### `adapter.model.*` — detected model-tier conventions

| Key | Type | Meaning |
|---|---|---|
| `adapter.model.defaultTier` | string | Default Claude tier per the target's CLAUDE.md (e.g., the detected Sonnet version) |
| `adapter.model.escalationTier` | string | Tier used on escalation triggers (e.g., the detected Opus version) |
| `adapter.model.floor` | string | Minimum allowed tier (never below — applies to Claude Code AND any Anthropic API calls) |

### `adapter.skills.*` — resolved skill names

| Key | Type | Meaning |
|---|---|---|
| `adapter.skills.simplify` | string \| null | Resolved simplify / complexity-reduction skill (`null` → use a manual simplify pass) |
| `adapter.skills.design.review` | string \| null | Resolved designer's-eye QA / design-review skill (`null` → manual critique) |
| `adapter.skills.design.consult` | string \| null | Resolved design-consultation / design-system / design-html skill (`null` → analytical) |
| `adapter.skills.design.a11y` | string \| null | Resolved accessibility-review skill (`null` → WCAG 2.2 AA checks by hand) |
| `adapter.skills.design.frontend` | string \| null | Resolved frontend-design plugin/skill (`null` → no production-UI generator) |

### `adapter.health.*` — windowed functional-health signal

| Key | Type | Meaning |
|---|---|---|
| `adapter.health.functionalHealth` | string | `POOR` \| `FAIR` \| `HEALTHY` — derived from gate/outcome failures over the last 2 sprints |
| `adapter.health.designPosture` | string | `ADVISORY` (health POOR/FAIR) \| `WEIGHTED` (health HEALTHY) — read by DECIDE for objective prioritization only |

---

## Portability degradation table

| Missing capability | Impact | Degradation behavior |
|---|---|---|
| Async loop tool absent | Lane A unavailable | All work in Lane B (synchronous crew) |
| Codex CLI absent | No cross-model review | Single-model review only; note in sprint summary |
| Issue tracker absent | No structured bead/issue IDs | State in `.smokejumper/sprint-plan.md`; sprint-log uses sequential IDs |
| Gate role absent | That gate skipped | Noted in sprint summary; no fabricated challenger |
| No project-specific lead | Fall back to bundled generic | Noted in lead mapping; generic lead disclaims domain knowledge |

The plugin always delivers a sprint. Absent capabilities reduce quality or require Lane-B
routing but never cause a hard stop.

---

## Adapter scan checklist

Run this during Phase 1 (RECON). Check each item; record results.

- [ ] List `.claude/agents/` in target repo
- [ ] List `~/.claude/agents/` for globally installed agents
- [ ] Resolve engineering / product / design leads (project-specific or bundled)
- [ ] Resolve implementation agents → `adapter.agents.uiImplementer` / `.backendImplementer` / `.dataAuditor` / `.localizationReviewer`
- [ ] Resolve safety / invariant guardians → `adapter.agents.safetyGuardian` / `.invariantGuardian` (if none: safety-critical work routes to human + gap logged)
- [ ] Resolve gate roles → `adapter.gate.*` (adapter-conditional; only if found)
- [ ] Check for async loop tool → `adapter.capabilities.asyncLoop`
- [ ] Check for Codex CLI → `adapter.capabilities.codex`
- [ ] Check for issue tracker (bd → gh → none) → `adapter.capabilities.tracker`
- [ ] Check for synchronous execution frameworks → `adapter.capabilities.syncFrameworks[]`
- [ ] Resolve simplify skill → `adapter.skills.simplify`
- [ ] Detect available design skills/plugins → `adapter.skills.design.review|consult|a11y|frontend`
- [ ] Derive windowed functional health → `adapter.health.functionalHealth` / `.designPosture` (emit `design_posture_set`)
- [ ] Detect model-tier conventions → `adapter.model.*`
- [ ] Check for any project-specific deploy tooling
- [ ] Write `## Lead & gate mapping` + `## Capabilities` + `## Model tier` in `repo-knowledge.md`
- [ ] Emit `agent_resolved` and `capability_detected/absent` events to `sprint-log.jsonl`
