---
name: smokejumper
description: Run a SmokeJumper sprint — land in this repo, assess it, decide the highest-leverage next move, execute it through Claude+Codex agents and (when work decomposes) async Ralph pours, gate every push through adversarial review, push, run lessons-learned, and hand off. Use when the user says "smokejumper", "run a sprint", "deploy the crew", "what should we build next and build it", or wants autonomous end-to-end product development on this repo.
---

# SmokeJumper

A portable autonomous product-development crew. Drop it into any repo: it lands cold,
assesses what exists, decides the highest-leverage next move itself, executes under an
Engineering Lead's supervision via Claude + Codex agents (and, when the work decomposes,
async Ralph pours), passes every push through a non-negotiable adversarial review gate,
pushes, runs a lessons-learned pass that makes the crew smarter, and hands off cleanly.

**Two compounding effects per deployment:** the target repo gets better (shipped work +
enriched per-repo knowledge), and the crew gets sharper (a versioned improvement to the
plugin itself).

---

## Before You Start

**Checklist:** Create one tracker item per phase in the detected issue tracker and work
them in order. If no issue tracker is present, track phases in
`<target>/.smokejumper/sprint-log.jsonl` (the durable state file) rather than an ephemeral
list. Close each item when its exit condition is satisfied. Do not advance to the next
phase until the current one's exit condition is met.

**State durability:** All progress and phase decisions append to
`<target>/.smokejumper/sprint-log.jsonl` in real time. If context is compacted or the
session resets mid-sprint, read `sprint-log.jsonl` and `<target>/.smokejumper/repo-knowledge.md`
to fully restore state before continuing. Long sprints are designed to survive interruption;
the ledger is the ground truth.

**Two-repo discipline:** SmokeJumper lives in its own plugin repo. The sprint's code
commits to the **target** repo. Never mix them. Framework improvements go to the plugin
repo; per-repo learnings and `.smokejumper/` files go to the target repo.

---

## Phase 1 — RECON

**Load:** `references/recon.md`, `references/adapter.md`, `references/repo-knowledge-schema.md`

Build a compact repo model using the whole-repo architecture approach defined in
`references/recon.md`. Read `CLAUDE.md` or `AGENTS.md` and any equivalent project-memory
files, product docs, and the issue tracker (if present). Load
`<target>/.smokejumper/repo-knowledge.md` if a prior drop left one — this is the
accumulated institutional knowledge from all previous sprints on this repo.

Run the adapter scan defined in `references/adapter.md`:

- Detect project-specific leads (patterns: `*-product-lead`, `*-engineering-lead`,
  `*-design-*`, design reviewer or director gate patterns). When a project-specific lead
  matches a role, **it is preferred** and the bundled generic stands down.
- Detect gate-review agents: quality/correctness reviewer, first-impression/first-use
  critic, product-thesis guardian, review-integrity (anti-sycophancy) gate, localization
  reviewer, safety/invariant guardians, and any other roles declared in the target's
  CLAUDE.md. Record as `adapter.gate.*`. Gate roles are **adapter-conditional** — a role
  exists only if the target repo declares it; never assume a role is present.
- Detect capabilities: `choo-choo-ralph` (Lane A available?), an execution framework
  (heavier orchestrated vs. lighter execution-skills — record both if present), Codex CLI,
  issue tracker (beads or equivalent). Record as `adapter.capabilities.*`.
- Detect model-tier rules from the target's CLAUDE.md (default tier, escalation triggers,
  any model floor). Record as `adapter.model.*`.
- Detect git discipline: submodule layout, branch conventions, merge policy (CI-enforced
  vs. local-green + admin-merge), merge command.
- Detect design system source of truth: token file, component library, style guide.
- Detect coverage thresholds file.

Run `scripts/sj-init.sh <target>` to scaffold `<target>/.smokejumper/` if it does not
already exist. The schema for `repo-knowledge.md` is defined in
`references/repo-knowledge-schema.md`.

Record everything as a compact repo model — enough to inform DECIDE and to route gates
and lanes in EXECUTE. Do not read every source file; read CLAUDE.md, key architecture
docs, and the adapter scan output.

**Exit condition:** Compact repo model recorded + detected lead mapping (project-specific
vs. generic bundled) + `adapter.gate.*` + `adapter.capabilities.*` + `adapter.model.*` +
git discipline + design system location + coverage thresholds all documented. If
`repo-knowledge.md` was present, any prior context from it is loaded.

---

## Phase 2 — DECIDE

*(No reference file — DECIDE draws on the RECON output and the leads' judgment.)*

The detected (or generic bundled) leads autonomously choose the highest-leverage next move
for the product. The product lead drives this phase. Inputs: RECON's repo model, the
product docs, the issue tracker, and `repo-knowledge.md`. If no product docs exist, infer
product direction from RECON's architectural model, the README, and the issue tracker.

**Autonomy scope:** The leads decide *what to build*, in what order, and why. Escalate to
the human **only** for product strategy / budget / release authority — per the
"make decisions or delegate — never punt" rule. Everything within that mandate is decided
with explicit reasoning and a kill condition; never punted as a clarifying question.

**Decision outputs:**
- The chosen objective, stated in one sentence
- The rationale (which metric it moves, which bet it validates, why this and not something
  else)
- An explicit kill condition (the threshold, the metric, the window)
- Preliminary lane signal: does the work decompose into a batch (candidate for Lane A)
  or require ongoing judgment (Lane B)? (Formal lane assignment happens in PLAN.)

If the capability scan found no issue tracker, the chosen objective is recorded in
`sprint-log.jsonl`.

**Exit condition:** A chosen objective with rationale, kill condition, and preliminary
lane signal recorded in `sprint-log.jsonl`.

---

## Phase 3 — PLAN (the authorizing adversarial gate)

*(No reference file — PLAN runs the adversarial flow on the design and plan.)*

First, ensure no stale `.adversarial-review-passed` marker exists from a prior sprint — if
one is present, delete it. The marker may ONLY be created by THIS sprint's gate after it
passes. Never treat a pre-existing marker as authorization.

The leads produce the design and implementation plan:

- The design lead produces design direction, flows, component patterns, states, and
  microcopy (for user-facing work). Reads the detected design system before touching
  anything — never invents tokens or hue values. If RECON found no design system, the
  design lead documents what baseline it is establishing and records it as a new
  design-system artifact.
- The product lead produces the feature spec (problem, goals, non-goals, requirements,
  tracking plan, acceptance criteria, kill condition).
- The engineering lead decomposes the work into units and assigns each unit a lane and
  a safety flag:
  - **Lane** — A (async pour, if `choo-choo-ralph` is available) or B (synchronous crew).
  - **Safety-critical flag** — any unit touching health/safety verdicts, scoring, payments,
    auth, or logic the target repo's CLAUDE.md designates as guardian-owned is flagged
    safety-critical and barred from Lane A.

After the plan is drafted, **run the full adversarial flow on the design and plan** using
the gate roles resolved from `adapter.gate.*`. This is the FRONT-LOADED gate that
authorizes execution — including authorizing any autonomous pour. If the repo defines no
plan-review gate, the bundled SmokeJumper three-reviewer parallel gate applies:
Feasibility reviewer, Completeness reviewer, Scope & Alignment reviewer. **ALL must PASS
before any code is written and before any pour is launched.**

For user-facing work, the design adversarial flow runs in parallel:
design reviewer → first-impression/first-use critic (if present in `adapter.gate.*`) →
product-thesis guardian (if present) → review-integrity gate.

Biased toward momentum: the gate catches bad assumptions and unsafe decomposition; it does
not re-architect vetted work.

**Exit condition:** Plan PASSED the adversarial gate for both the design and the
implementation plan. All work units have lane + safety-flag assignments. The gate verdict
(PASS, with which reviewers) is appended to `<target>/.smokejumper/sprint-log.jsonl` before
advancing to EXECUTE.

---

## Phase 4 — EXECUTE (two lanes)

**Load:** `references/gated-pour.md`, `references/self-healing.md`

The engineering lead routes each work unit to its assigned lane and launches execution.

### Lane A — Async pour (hours to days)

For large, decomposable, plan-vetted, non-safety-critical bulk. Requires
`choo-choo-ralph` to be present (detected in RECON). If absent, offer to install it
or fall back to Lane B; record the gap in `<target>/.smokejumper/gaps.jsonl`.

Follow `references/gated-pour.md` for the full spec→pour→formula→launch→monitor→harvest
flow:

1. Convert the approved plan via `choo-choo-ralph:spec` → `choo-choo-ralph:pour` into a
   molecule whose children's formula runs **Codex** at `model_reasoning_effort="high"`
   (never `xhigh` — causes hangs), plus per-child mechanical gates (tests green, build
   passes, type-check/lint clean, coverage at or above detected thresholds).
2. Launch one or more `nohup ./ralph.sh &` loops grinding
   `bd ready --parent <mol-id>` (or the equivalent for the detected tracker).
3. Record molecule IDs in `sprint-log.jsonl` so a context reset can resume monitoring.
4. State lives in the tracker and `.smokejumper/` — not in session context.

### Lane B — Synchronous crew (in-session)

For novel, architectural, design-sensitive, or safety-critical units. The engineering lead
dispatches Claude + Codex agents directly. Safety-critical units route to guardian agents
(resolved from `adapter.agents.safetyGuardian` and `adapter.agents.invariantGuardian`).

Build flow per unit: Plan → TDD (red→green) → implement → `/simplify` (or detected
equivalent) → adversarial review (§ Phase 5) → cross-model Codex review → PR review →
push.

### Self-healing missing agents

When a unit needs a specialist agent that does not exist in the target repo, follow
`references/self-healing.md` to author the agent on the fly: write it to
`<target>/.claude/agents/`, register it, use it, and record the gap in
`<target>/.smokejumper/gaps.jsonl`. Self-healed agents are repo-specific by default;
graduation to the plugin is a deliberate LESSONS LEARNED decision.

**Execution framework selection:** If the RECON detected more than one synchronous
execution framework (e.g., a heavier orchestrated framework and a lighter execution-skills
framework), **ask the human which to use** before dispatching Lane B work. State the
tradeoff (heavier orchestration = more thorough + more tokens + full gates; lighter
execution = faster + fewer gates). If only one framework is present, use it; if none,
direct dispatch. Never auto-select.

**Model tier:** Follow `adapter.model.*` (detected in RECON). Sonnet is the minimum floor
for all Claude work — applies in Claude Code sessions and in any Anthropic API calls the
build makes. Never use a model below that floor. Escalate to Opus only on triggers the
target repo's CLAUDE.md identifies. Use Codex for large, self-contained, context-free
work; zero Claude tokens. Never `xhigh` reasoning effort.

**Exit condition:** Lane B units are merged (per §Phase 6); Lane A loops are launched and
molecule IDs are recorded. Any self-healed agents are committed to the target.

---

## Phase 5 — REVIEW (layered, heavy gate is front-loaded)

*(No reference file — REVIEW uses gate roles resolved from `adapter.gate.*` in RECON.)*

The adversarial review gate is non-negotiable and is never a formality. `.adversarial-review-passed` must exist before any push of reviewed work.

Review is layered:

**Lane B units — full adversarial review before push:**

Run the full per-change adversarial flow resolved from `adapter.gate.*`. If the repo
defines no flow, the bundled SmokeJumper flow applies: quality/correctness reviewer →
review-integrity (anti-sycophancy) gate. For user-facing changes, prepend: design
reviewer → first-impression/first-use critic (if `adapter.gate.*` declares one).

The engineering lead creates the `.adversarial-review-passed` marker (or the project's
equivalent) only after confirming every applicable gate obligation is met. No other agent
or sub-agent creates it for their own work.

**Lane A children — per-child mechanical gates:**

Each formula child must pass: tests green, build passes, type-check/lint clean, coverage
at or above thresholds. A child that cannot pass parks for the next loop or files a
blocker issue in the detected tracker. The heavy adversarial review was already spent at
the front-loaded Plan gate in Phase 3 — it is not re-run per child. For a poured molecule,
the `.adversarial-review-passed` authorization is established ONCE at plan-time (Phase 3),
not per child; Lane A children run only their mechanical gates.

**Milestone spot-check:**

At molecule milestones (and at harvest), a Claude adversarial spot-check samples completed
Lane A children — cheap insurance over the autonomous batch. The engineering lead decides
the sampling rate; a 10–20% sample at each milestone is the default.

**Exit condition:** Every Lane B unit has a `.adversarial-review-passed` marker and all
applicable gate obligations met. Every Lane A child that has landed passed its mechanical
gates. Milestone spot-checks have been run where applicable.

---

## Phase 6 — INTEGRATE

*(No reference file — INTEGRATE follows git discipline detected in RECON.)*

Commit and push with standing authority. Honor target-repo git discipline exactly as
detected in RECON:

- **Submodule-first** (if the repo has submodules): commit + push inside each submodule
  first, then bump the pointer from the root.
- Stage specific files by name. Never `git add -A` or `git add .` — they can capture
  secrets, generated artifacts, or another session's staged work.
- Read `git status` before every `git add`; re-verify staged scope before committing.
- No `--amend` on shared or pushed commits. Always create a new commit.
- No `--no-verify`. Never skip hooks.
- No force-push to any shared branch.
- If the repo uses admin-merge (CI retired), use the detected merge command once
  local-green + adversarial review pass.

**Merging is not deploying.** Never run a deploy, release, or publish without explicit
human greenlight. This is absolute. Record the push in `sprint-log.jsonl`.

**Exit condition:** `git push` succeeded. `git status` shows "up to date with origin."

---

## Phase 7 — LESSONS LEARNED

**Load:** `references/lessons-learned.md`

Follow `references/lessons-learned.md` for the full dual write-back mechanism. Two
streams, both required:

**(a) Per-repo enrichment.** Synthesize learnings from this sprint: what was confirmed,
what was discovered, what traps were found, what gate patterns apply to this repo,
`adapter.*` updates if the scan should change next time. Enrich
`<target>/.smokejumper/repo-knowledge.md` in place (schema:
`references/repo-knowledge-schema.md`). Commit the enriched file to the target repo.

For Lane A, use `choo-choo-ralph:harvest` (if present) to harvest learnings from
completed molecule children before synthesizing. The orchestrator also synthesizes
synchronous-lane learnings.

**(b) Framework versioned improvement (when a portable improvement surfaced).** If the
sprint revealed a portable fix — a better recon heuristic, a lifecycle gap, a roster gap
worth bundling, a reference file improvement — make a **versioned commit to the SmokeJumper
plugin repo**: bump `VERSION` and `plugin.json` per SemVer (MAJOR breaking, MINOR
features, PATCH fixes), add a `CHANGELOG.md` entry naming the deployment, optionally
`claude plugin tag`. Record the version bump in `sprint-log.jsonl`.

If a portable improvement was identified but the plugin-repo (Repo A) version bump/commit
can't complete (no remote, tag conflict, etc.), record the intended improvement in
`<target>/.smokejumper/repo-knowledge.md` under a "Framework improvements pending" note and
surface it in the handoff — never leave the sprint half-finished.

If no portable improvement surfaced, record that stream as N/A in `sprint-log.jsonl`.

"The crew gets better every drop" = a plugin version bump with a CHANGELOG entry, never
a mutation of loose files.

**Exit condition:** (a) `repo-knowledge.md` enriched and committed to the target repo.
(b) Plugin repo has a versioned commit — or N/A is explicitly recorded.

---

## Phase 8 — HANDOFF

*(No reference file — HANDOFF invokes `anthropic-skills:handoff-prompt`.)*

Invoke `anthropic-skills:handoff-prompt` to produce a high-fidelity handoff so the next
session resumes with zero lost context and no hallucinated state. If
`anthropic-skills:handoff-prompt` is not installed, write an equivalent handoff document to
`<target>/.smokejumper/HANDOFF.md` covering the same content (state, running loops, next
steps).

**If Lane A loops are still running**, the handoff explicitly carries the running loops:

- What molecules are pouring (`bd ready --parent <mol-id>` or equivalent)
- How to monitor progress in the detected tracker
- Per-child mechanical gate status
- Current milestone spot-check state
- When and how to harvest (which `choo-choo-ralph:harvest` command to run)
- Any blocker children that parked and need human intervention

The handoff also carries: the sprint objective, any open follow-up issues filed in the
detected tracker, the current state of `<target>/.smokejumper/sprint-log.jsonl`, and any
deploy/release greenlight that is still pending.

**Exit condition:** Handoff produced and confirmed complete. If Lane A loops are running,
the handoff verifiably carries enough context for the next session to monitor and harvest
without re-running RECON.

---

## Portability contract

SmokeJumper hard-requires only: a git repo, the Claude Code runtime, and the bundled
agents + skill. Everything else is detected in RECON and adapted to.

| Target condition | SmokeJumper behavior |
|---|---|
| Has project-specific leads | Adapter prefers them; bundled generics stand down |
| No project leads | Bundled generic leads run |
| `choo-choo-ralph` installed | Lane A (big pour) available |
| `choo-choo-ralph` absent | Offer install; else Lane-B-only; record gap |
| Issue tracker present | Use it for durable state (tracker item per phase) |
| No issue tracker | State lives in `<target>/.smokejumper/` only |
| Missing specialist agent | Self-heal: author into target `.claude/agents/` + log gap |
| Has `CLAUDE.md` / `AGENTS.md` | RECON honors its rules as defaults |
| Multiple execution frameworks detected | Ask human which to use — never auto-select |

---

## References

- `references/recon.md` — whole-repo architecture modeling (used in RECON)
- `references/adapter.md` — naming-convention lead + capability detection (used in RECON)
- `references/repo-knowledge-schema.md` — schema for `<target>/.smokejumper/repo-knowledge.md` (used in RECON + LESSONS LEARNED)
- `references/gated-pour.md` — spec→pour→formula→launch→monitor→harvest flow (used in EXECUTE)
- `references/self-healing.md` — author-a-missing-agent protocol (used in EXECUTE)
- `references/lessons-learned.md` — dual write-back + version-bump rules (used in LESSONS LEARNED)
