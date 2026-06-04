# Reference: Adapter — Lead, Gate, and Capability Detection

The adapter layer runs during RECON (Phase 1) and resolves two things:
1. **Lead agents and gate roles** — who runs each phase and each review gate
2. **Capabilities** — which tools and orchestration primitives are available

SmokeJumper hard-requires only a git repo, the Claude Code runtime, and the bundled
agents + skill. Everything else is detected and adapted to.

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
| Async loop tool (choo-choo-ralph or equivalent) | `which ralph` or `ls ~/.claude/skills/choo-choo-ralph/` or `which choo-choo-ralph` | Lane A (async pour) not available; all work routes to Lane B |
| Codex CLI | `which codex` | Async formula steps use Claude directly (slower); token budget impact noted |
| Issue tracker — beads/bd | `which bd` | State lives in `.smokejumper/` only; no bead IDs in sprint-log |
| Issue tracker — GitHub Issues | `gh issue list` exits 0 | Use gh for issue tracking |
| Issue tracker — none | Neither above found | Create a `sprint-plan.md` scratch tracker in `.smokejumper/` |
| Cloud/platform deploy config | `deploy.json`, platform config, or CI deploy job present | Deploy gate uses project-specific deploy command |
| Docker / container | `Dockerfile` present | Treat as containerized; note in capabilities |

Record all capability detections in `## Capabilities` in `repo-knowledge.md` and emit
`capability_detected` or `capability_absent` events to `sprint-log.jsonl`.

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
- [ ] Detect model-tier conventions → `adapter.model.*`
- [ ] Check for any project-specific deploy tooling
- [ ] Write `## Lead & gate mapping` + `## Capabilities` + `## Model tier` in `repo-knowledge.md`
- [ ] Emit `agent_resolved` and `capability_detected/absent` events to `sprint-log.jsonl`
