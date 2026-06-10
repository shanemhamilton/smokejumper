---
name: smokejumper
description: Run a SmokeJumper sprint — land in this repo, assess it, decide the highest-leverage next move, execute it through Claude+Codex agents and (when work decomposes) async Ralph pours, gate every push through adversarial review, push, run lessons-learned, and hand off. Use when the user says "smokejumper", "run a sprint", "deploy the crew", "what should we build next and build it", or wants autonomous end-to-end product development on this repo.
---

# SmokeJumper

A portable autonomous product-development crew. It lands cold in any repo, assesses what
exists, decides the highest-leverage next move itself, executes under an Engineering
Lead's supervision via Claude + Codex agents (and, when the work decomposes, async Ralph
pours), passes every push through a non-negotiable adversarial review gate, pushes, runs
a lessons-learned pass, and hands off cleanly.

**Two compounding effects per deployment:** the target repo gets better (shipped work +
enriched per-repo knowledge), and the crew gets sharper (a versioned plugin improvement).

This file is the skeleton: phase order, invariants, state contract, exit conditions.
**Load `references/phases.md` for the detailed procedure of each phase as you enter it.**
The deterministic actions live in the `sj` CLI (`scripts/sj`) — prefer running an `sj`
command over re-implementing its check in prose.

---

## Before You Start

- **Update check (non-blocking):** run `scripts/sj version --check` and `scripts/sj deps`.
  Relay any notice to the user once, then continue — informational, never a gate, never
  auto-upgrades.
- **Checklist:** one tracker item per phase in the detected issue tracker; no tracker →
  phases tracked in `sprint-log.jsonl`. Do not advance past an unmet exit condition.
- **State durability:** all progress appends to `<target>/.smokejumper/sprint-log.jsonl`
  in real time. After a context reset, read `sprint-log.jsonl` + `repo-knowledge.md` +
  `adapter-scan.json` to restore state; run `sj validate-state <target>` to confirm the
  ledger is intact. The ledger is the ground truth.
- **Two-repo discipline:** the sprint's code commits to the **target** repo; framework
  improvements commit to the **plugin** repo. Never mix them.

---

## Non-negotiable invariants

1. **No push of reviewed work without a verified gate.**
   `sj gate check adversarial-review --target <target>` must pass before pushing. The
   marker is created ONLY by the engineering lead via `sj gate record adversarial-review
   --reviewers <agents-that-actually-ran>`, only after the gate genuinely passed. At
   sprint start, clear any stale marker: `sj gate clear adversarial-review --target <target>`.
   A pre-existing marker is never authorization — `sj gate check` enforces this
   (ancestry + recency), but do not rely on being caught.

2. **No pour without a vetted plan.** Lane A launches require
   `sj gate check plan-vetted --target <target>` to pass AND a CLEAR
   `sj lane-check <target> <unit-file>` verdict per poured unit. Safety-critical work is
   never poured; when in doubt, it is safety-critical.

3. **`designPosture` is a prioritization hint ONLY.** When `WEIGHTED`, the product lead
   ranks design-debt/polish/UX objectives higher in DECIDE. **It never makes any gate
   blocking, never forces a design-skill invocation, and never gates a push.** Other files
   that mention designPosture defer to this paragraph.

4. **Merging is not deploying.** Never deploy, release, or publish without explicit human
   greenlight. Absolute.

5. **Escalate to the human only** for product strategy / budget / release authority — and
   when multiple synchronous execution frameworks are detected (ask which; never
   auto-select). Everything else is decided with explicit reasoning and a kill condition.

6. **No sub-agent self-certification.** A sub-agent never runs `sj gate record` on its
   own work. No `--no-verify`, no `--amend` on shared commits, no force-push, no
   `git add -A`.

---

## State artifacts per phase

Every "record X" obligation in one place. Emit events with the exact names below (the
`sj` commands emit theirs automatically); `sj validate-state <target> --phase <P>` checks
each row.

| Phase | Required events in `sprint-log.jsonl` | Files / markers | Verified by |
|---|---|---|---|
| RECON | `leads_established` (+ `agent_resolved`, `capability_*`, `design_posture_set` — all emitted by `sj scan`) | `repo-knowledge.md` sections, `adapter-scan.json`, product-context artifact path recorded | `sj validate-state --phase RECON` |
| DECIDE | `objective_chosen` (emit manually: objective, rationale, kill condition, lane signal) | — | `sj validate-state --phase DECIDE` |
| PLAN | `gate_review` + `gate_passed` (emitted by `sj gate record plan-vetted`), `lane_check` per Lane A unit, `design_skill_invoked` when used | `.smokejumper/.plan-vetted` | `sj gate check plan-vetted` |
| EXECUTE | molecule IDs / unit progress (recommended, free-form) | self-healed agents committed; gaps in `gaps.jsonl` | `sj validate-state` |
| REVIEW | `gate_review` + `gate_passed` (emitted by `sj gate record adversarial-review`) | `.smokejumper/.adversarial-review-passed` | `sj gate check adversarial-review` |
| INTEGRATE | `push_completed` (emit manually after `git push` succeeds) | — | `sj validate-state --phase INTEGRATE` |
| LESSONS | `write_back_completed`, `design_skill_outcome` per scored skill | `repo-knowledge.md` enriched + committed; product context updated | `sj validate-state --phase LESSONS` |
| HANDOFF | — | handoff document (skill output or `.smokejumper/HANDOFF.md`) | manual |

Schemas: `schemas/sprint-event.schema.json`, `schemas/gap.schema.json`.

---

## Phase 1 — RECON

**Load:** `references/phases.md` §Phase 1, `references/runtime.md`, `references/recon.md`
(deep detail on demand: `references/adapter.md`, `references/repo-knowledge-schema.md`,
`references/product-context.md`)

Runtime preflight (dispatch vs inline-adoption) → build the compact repo model → run
`scripts/sj scan <target>` (mandatory; resolves leads/gates/capabilities, writes
`adapter-scan.json` — parse that JSON for `adapter.*` values, not prose) → read the
resolved lead definitions (a lead is established only once its definition is read) →
resolve product context (read it, or bootstrap via Setup mode if MISSING).

**Exit:** repo model recorded; `sj scan` ran and its banner was surfaced; leads
established; `adapter.model.*` + git discipline + coverage thresholds read from the
target; product-context artifact exists and its path is recorded. **Never advance with
`productContext: MISSING`.** `sj validate-state <target> --phase RECON` passes.

---

## Phase 2 — DECIDE

**Load:** `references/phases.md` §Phase 2

The product lead chooses the highest-leverage objective from RECON's model + the
product-context artifact (authoritative — quote it, don't re-infer). Apply invariant 3
for `designPosture` weighting. Output: objective (one sentence), rationale, kill
condition, preliminary lane signal — emitted as an `objective_chosen` event.

**Exit:** `sj validate-state <target> --phase DECIDE` passes.

---

## Phase 3 — PLAN (the authorizing adversarial gate)

**Load:** `references/phases.md` §Phase 3

Start clean: `sj gate clear adversarial-review --target <target>` (and `plan-vetted`).
Design lead produces design (reads the detected design system — never invents tokens);
product lead produces the spec; engineering lead decomposes into units with lane +
safety-flag assignments and runs `sj lane-check` on every Lane A candidate. Then run the
full adversarial flow (precedence: project gates → metaswarm → bundled three-reviewer
gate). ALL must PASS before any code or any pour. Record:
`sj gate record plan-vetted --target <target> --reviewers <reviewers>`.

**Exit:** `sj gate check plan-vetted --target <target>` passes; all units have lane +
safety assignments; design/spec artifacts exist.

---

## Phase 4 — EXECUTE (two lanes)

**Load:** `references/phases.md` §Phase 4, `references/gated-pour.md` (Lane A),
`references/self-healing.md` (missing agents)

- **Lane A (async pour):** only after invariant 2 is satisfied. Spec → pour → formula
  (Codex `model_reasoning_effort="high"`, never `xhigh`) → launch loops → record molecule
  IDs in `sprint-log.jsonl`.
- **Lane B (synchronous crew):** novel/architectural/design-sensitive/safety-critical
  units. Per unit: Plan → TDD → implement → `/simplify` → adversarial review → cross-model
  Codex review → PR review → push.
- Self-heal missing agents per `self-healing.md`; log gaps to `gaps.jsonl`.
- Model tier per `adapter.model.*`; Sonnet floor, Opus on the target's triggers.

**Exit:** Lane B units merged (Phase 6); Lane A loops launched with molecule IDs
recorded; self-healed agents committed.

---

## Phase 5 — REVIEW (layered; heavy gate was front-loaded)

**Load:** `references/phases.md` §Phase 5

Lane B: full per-change adversarial flow from `adapter.gate.*` (bundled fallback:
quality reviewer → review-integrity gate; UI work prepends design reviewer →
first-impression critic). Optional bugsweep pass — confirmed findings are blockers.
Then the engineering lead records: `sj gate record adversarial-review --target <target>
--reviewers <gate-agents-that-ran>`.

Lane A children: mechanical gates only (tests/build/lint/coverage); milestone spot-checks
sample 10–20%.

**Exit:** `sj gate check adversarial-review --target <target>` passes; Lane A children
green; spot-checks done where applicable.

---

## Phase 6 — INTEGRATE

**Load:** `references/phases.md` §Phase 6

Commit + push per the target's detected git discipline (invariant 6). Optional
`metaswarm:pr-shepherd` for PR flows. After `git push` succeeds and `git status` shows
"up to date with origin", emit `push_completed`.

**Exit:** push succeeded; `sj validate-state <target> --phase INTEGRATE` passes.

---

## Phase 7 — LESSONS LEARNED

**Load:** `references/phases.md` §Phase 7, `references/lessons-learned.md`

Dual write-back: (a) enrich `repo-knowledge.md` + update product context + score design
skills (`design_skill_outcome` per invocation; gate-or-ship proxy) → commit to target;
(b) portable improvements → versioned plugin commit (canonical repo) or prepared
upstream-PR suggestion (anywhere else); can't complete → "Framework improvements pending".
Emit `write_back_completed`.

**Exit:** (a) committed; (b) committed / prepared / explicitly N/A;
`sj validate-state <target> --phase LESSONS` passes.

---

## Phase 8 — HANDOFF

**Load:** `references/phases.md` §Phase 8

Invoke `anthropic-skills:handoff-prompt` (fallback: write `.smokejumper/HANDOFF.md`).
Carry: running Lane A loops + monitor/harvest commands, sprint objective, open
follow-ups, ledger state, gate marker status (`sj gate check` output), pending
greenlights.

**Exit:** handoff produced; if loops are running, it verifiably carries enough to monitor
and harvest without re-running RECON.

---

## Portability contract

SmokeJumper hard-requires only: a git repo and the bundled agents + skill + scripts. It
runs best under Claude Code (subagent dispatch + skills) and degrades to inline persona
adoption under any other orchestrator, including Codex (`references/runtime.md`). The
`sj` CLI is runtime-agnostic — any orchestrator that can run a shell command gets the
same gates and state checks.

| Target condition | Behavior |
|---|---|
| Project-specific leads | Preferred; bundled generics stand down |
| No project leads | Bundled generic leads run |
| choo-choo-ralph present / absent | Lane A available / offer install, else Lane-B-only + gap |
| metaswarm present (Claude Code) | Gates may route through metaswarm (project → metaswarm → bundled) |
| bugsweep present / absent | Optional deep bug-hunt in REVIEW / skip |
| Tracker present / absent | Tracker item per phase / state in `.smokejumper/` only |
| Missing specialist agent | Self-heal + log gap |
| `CLAUDE.md`/`AGENTS.md` present | RECON honors its rules as defaults |
| Multiple exec frameworks | Ask the human — never auto-select |
| Non-Claude orchestrator | Inline-adoption mode; embedded references; same `sj` CLI |
| Product context absent / present | Bootstrap before DECIDE / read (Context mode), update in LESSONS |

---

## References

- `references/phases.md` — detailed per-phase procedure (load per phase)
- `references/runtime.md` — adopt-vs-dispatch + runtime preflight
- `references/recon.md` — whole-repo architecture modeling
- `references/adapter.md` — lead/gate/capability detection spec, implemented by `scripts/sj scan` (contract-tested against `adapter-scan.json`)
- `references/product-context.md` + `templates/product-context.md` — product-context bootstrap (Context/Setup/Update)
- `references/repo-knowledge-schema.md` — `repo-knowledge.md` schema
- `references/gated-pour.md` — Lane A pour mechanics
- `references/self-healing.md` — author-a-missing-agent protocol
- `references/lessons-learned.md` — dual write-back + version-bump rules
- `references/dependencies.md` + `references/dependencies.json` — dependency manifest + pin policy (used by `sj deps`)
- `schemas/` — JSON Schemas for `sprint-log.jsonl` and `gaps.jsonl`
