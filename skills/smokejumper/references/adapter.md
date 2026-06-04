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

| Role | Detect by keyword in filename | If absent |
|---|---|---|
| Engineering lead | `engineering-lead` | Use bundled `smokejumper-engineering-lead` |
| Product lead | `product-lead` | Use bundled `smokejumper-product-lead` |
| Design lead | `design-lead` | Use bundled `smokejumper-design-lead` |
| Design reviewer (gate) | `design-reviewer` or project-specific design-gating role | Skip design gate |
| Product-thesis guardian (gate) | `thesis` + `guardian` or `product-thesis` variant | Skip thesis gate |
| Review-integrity gate | `review-integrity` or `sycophancy` variant | Skip review-integrity gate |
| First-impression / first-use critic | `first-impression`, `first-use`, or equivalent | Skip first-use gate |
| Quality control | `quality-control` or `qc` | Use basic self-review checklist |

**Resolution priority:**
1. Project-specific agent in target `.claude/agents/` (most specific)
2. Globally installed project-specific agent in `~/.claude/agents/` with matching pattern
3. Bundled SmokeJumper generic agent
4. Skip / degrade gracefully (for gates only — leads always have a bundled fallback)

Record every resolution in `## Lead mapping` in `repo-knowledge.md` and emit an
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
- [ ] Resolve gate roles (adapter-conditional; only if found)
- [ ] Check for async loop tool
- [ ] Check for Codex CLI
- [ ] Check for issue tracker (bd → gh → none)
- [ ] Check for any project-specific deploy tooling
- [ ] Write `## Lead mapping` + `## Capabilities` in `repo-knowledge.md`
- [ ] Emit `agent_resolved` and `capability_detected/absent` events to `sprint-log.jsonl`
