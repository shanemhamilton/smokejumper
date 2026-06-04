# Reference: Gated Pour — Two-Lane Execution and Safety Semantics

A "pour" is an async, unattended execution loop — a molecule of structured work items
dispatched to choo-choo-ralph (or equivalent), where each child runs autonomously and
reports results. A pour is powerful and fast, but it introduces a safety problem: if
every child runs its own heavy adversarial review, the cost blows up; if no child does,
quality is unchecked. This reference resolves that tension.

---

## The two execution lanes

Choose one lane per work unit before dispatching. Do not mix within a unit.

| Signal | Lane A (pour / async) | Lane B (synchronous crew) |
|---|---|---|
| Work style | Async, unattended, walk away | Sync, human present |
| State lives in | The persistent tracker (e.g. beads, if present) — survives reset | Session context |
| Duration | Hours / days | Minutes / one session |
| Shape | Batch over N items, repeatable | Novel, architectural decisions |
| Safety-critical? | **Never** (barred) | Yes — routed to guardians |
| Plan already vetted? | Yes — via the Plan Review Gate | Yes — via the Plan Review Gate |

**Lane A (pour)** — async loop tool required. If no async loop tool is detected by the
adapter, all work routes to Lane B.

**Lane B (synchronous crew)** — Claude + Codex in-session, full adversarial review per
unit. No async loop tool required.

---

## The front-loaded gate rule

The Plan Review Gate runs BEFORE any pour is authorized. It is a heavyweight adversarial
review of the sprint plan that covers every unit about to be poured.

This gate is relocated to the design and plan phase — not to each child, not to the
molecule's close. It authorizes the entire pour by vetting scope, sequencing, safety
classification, and success criteria up front. The gate is **never** waived, never
deferred to child execution time, and never replaced by a post-hoc spot check alone.

The Plan Review Gate runs for BOTH lanes. Lane A earns the `.adversarial-review-passed`
marker at plan-authorization time. Lane B earns it per unit (after the per-change
adversarial review flow). The marker is never created before the gate passes.

---

## Lane A gate model (per-child)

After the front-loaded Plan Review Gate authorizes the pour, each Lane A child runs ONLY
mechanical gates:

1. Tests pass (TDD: test written first, watched fail, then implementation)
2. Coverage gate (per `.coverage-thresholds.json` or equivalent in the target repo)
3. Build passes (no compile errors)
4. Lint / type-check passes

**Lane A children do NOT run:**
- Full adversarial review (already spent at plan-authorization time)
- Design-reviewer gate
- Product-thesis gate

**Milestone spot-check (mandatory):** After every N children complete (default: 25% of
molecule), the engineering lead samples completed work for quality drift. If drift is
found, the pour is paused and a Lane-B correction unit is dispatched before resuming.

---

## Lane B gate sequence (per unit)

1. **Plan Review Gate** — 3 adversarial reviewers in parallel (feasibility, completeness,
   scope alignment). All must PASS before any implementation begins.
2. **TDD** — test written first, watched fail, then implementation.
3. **Coverage gate** — per thresholds file; BLOCKING before PR creation.
4. **`/simplify`** — complexity reduction pass after implementation.
5. **Adversarial review by change type:**
   - UI changes: design reviewer (adapter-conditional) → product-thesis guardian
     (adapter-conditional) → review-integrity gate (adapter-conditional)
   - Backend / pipeline changes: quality control → product-thesis guardian
     (adapter-conditional) → review-integrity gate (adapter-conditional)
   - Safety-critical: guardian agents first → then standard chain
6. **Cross-model Codex review** — if Codex CLI is detected by the adapter.
7. **PR review** — before merge.

---

## Safety-critical rule (absolute)

Safety-critical work is **never** poured. No exceptions.

Safety-critical = logic governing health/safety verdicts, scoring, payments, auth, crypto,
data integrity, or anything the target repo's `CLAUDE.md` / `AGENTS.md` designates as
guardian-owned. When in doubt whether a unit is safety-critical, treat it as
safety-critical.

If a pour molecule is being structured and any child is safety-critical:
- Remove that child from the molecule
- Dispatch it separately as a Lane B unit
- Resume the pour without it

The `.adversarial-review-passed` marker from the pour's plan-authorization does NOT cover
safety-critical units removed from the molecule. Those units earn their own markers via the
full Lane B gate sequence.

---

## Routing heuristics

- Single-file edit or quick fix → neither lane; direct implementation + gate + push.
- Batch over N items with repeatable steps and unambiguous success criteria → **Lane A**.
  Structure as a molecule, launch as an unattended loop.
- Novel feature, architectural decisions, multi-file implementation → **Lane B**.
- Adjacent to safety-critical logic → treat as safety-critical, **Lane B** + guardian review.
- Rule of thumb: if it expresses as a molecule with clear children, Lane A; if it requires
  ongoing judgment, Lane B.

---

## Mandatory ask before any non-trivial Lane B build

Before drafting the plan for a non-trivial Lane B build, ask the human which execution
framework to use IF the adapter detects multiple synchronous frameworks. State the
tradeoff (more thorough + more tokens vs faster + lighter-weight). Never auto-select.
If only one framework is available, use it; if none, use direct dispatch.

The ask sequence: ask method → draft plan → Plan Review Gate → execution. Never skip the
gate by starting execution before the plan review passes.
