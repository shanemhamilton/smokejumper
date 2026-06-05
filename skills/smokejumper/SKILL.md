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

**Update check (non-blocking):** As the first action, run `scripts/sj-version-check.sh`
(SmokeJumper itself) and `scripts/sj-deps-check.sh` (its declared dependencies — see
`references/dependencies.md`). If either prints a notice, relay it to the user once, then
continue the sprint — both are informational, never a gate. Both are fail-silent (no
network, no `curl`/`python3`, or an API error produces no output) and notify-only: they
never auto-upgrade and never overwrite the vendored product-context copy. Surface the
command (`… --update`, or the printed upgrade line) and let the user decide.

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

**Load:** `references/runtime.md`, `references/recon.md`, `references/adapter.md`, `references/repo-knowledge-schema.md`, `references/product-context.md`

**Runtime preflight (first).** Per `references/runtime.md`, self-identify your runtime and
pick the execution mode: can you dispatch subagents, and can you invoke the Skill tool? If
not — e.g. a Codex agent is the top-level orchestrator — run in **inline-adoption mode**:
adopt lead and reviewer personas by reading their definition files, and use the embedded
reference files directly. Record the runtime in the RECON summary and `sprint-log.jsonl`.
Never block on a subagent dispatch or Skill-tool call your runtime cannot make.

Build a compact repo model using the whole-repo architecture approach defined in
`references/recon.md`. Read `CLAUDE.md` or `AGENTS.md` and any equivalent project-memory
files, product docs, and the issue tracker (if present). Load
`<target>/.smokejumper/repo-knowledge.md` if a prior drop left one — this is the
accumulated institutional knowledge from all previous sprints on this repo.

Run the deterministic adapter scan — `scripts/sj-adapter-scan.sh <target>` — which
implements the detection specified in `references/adapter.md`. It resolves the items below,
writes `## Lead & gate mapping` + `## Capabilities` into `repo-knowledge.md`, emits
`agent_resolved` / `capability_*` / `leads_established` events to `sprint-log.jsonl`, and
prints a **"Leads established" banner**. Running the script is mandatory — it converts lead
resolution from a remembered step into a visible, durable artifact (critical when a Codex
orchestrator drives the sprint). It also scaffolds `<target>/.smokejumper/`, so a separate
`sj-init.sh` run is not required. The scan resolves:

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

The schema for `repo-knowledge.md` is defined in `references/repo-knowledge-schema.md`.
(`scripts/sj-init.sh` remains a standalone way to scaffold `<target>/.smokejumper/`.)

**Establish the leads.** Resolving names is not the same as establishing leads. Per
`references/runtime.md`, a lead is not established until its resolved definition file has
been read and adopted (or dispatched as a subagent, if your runtime supports it). Read the
resolved product / engineering / design lead definitions before DECIDE, and surface the
"Leads established" banner the scan printed.

**Bootstrap product context.** The adapter scan already reports `productContext: present | MISSING`
in its banner and in `## Capabilities` — a deterministic cue, not a prose-only step you can
skim past. Act on it per `references/product-context.md`: if **present**, read it (Context
mode); if **MISSING** — the brand-new-repo case — establish one (Setup mode) before DECIDE,
write the durable artifact, and update its path under `## Capabilities` in
`repo-knowledge.md`. On a greenfield repo this is the most important RECON output: there is
little code to model, so product context is what DECIDE runs on. **Do not advance to DECIDE
with `productContext: MISSING` still unresolved.**

Record everything as a compact repo model — enough to inform DECIDE and to route gates
and lanes in EXECUTE. Do not read every source file; read CLAUDE.md, key architecture
docs, and the adapter scan output.

**Exit condition:** Compact repo model recorded + detected lead mapping (project-specific
vs. generic bundled) + `adapter.gate.*` + `adapter.capabilities.*` + `adapter.model.*` +
git discipline + design system location + coverage thresholds all documented. **The leads
are established (resolved definitions read/adopted), the "Leads established" banner was
surfaced, and a `leads_established` event is in `sprint-log.jsonl`. A product-context
artifact exists (read in Context mode or bootstrapped in Setup mode) and its path is
recorded under `## Capabilities`.** If `repo-knowledge.md` was present, any prior context
from it is loaded.

---

## Phase 2 — DECIDE

*(No reference file — DECIDE draws on the RECON output and the leads' judgment.)*

The detected (or generic bundled) leads autonomously choose the highest-leverage next move
for the product. The product lead drives this phase. Inputs: RECON's repo model, the
**product-context artifact established in RECON** (authoritative — read it and quote it; do
not re-infer product direction from scratch), the issue tracker, and `repo-knowledge.md`. If
that artifact was generated without a human interview (its header is marked `unverified`),
treat it as provisional and weight its `[TODO]` gaps accordingly rather than building on
fabricated certainty.

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
authorizes execution — including authorizing any autonomous pour. Gate precedence:
**project-specific gates (`adapter.gate.*`) → metaswarm (if detected) → bundled fallback.**
If `adapter.capabilities.metaswarm` is `yes` and your runtime can invoke skills (Claude
Code), you MAY route this gate through `metaswarm:plan-review-gate` and (for design)
`metaswarm:design-review-gate` — its cross-model parallel reviewers are a stronger gate than
the bundled flow. If neither a project gate nor metaswarm applies (or you are under a
non-Claude runtime with no Skill tool), the bundled SmokeJumper three-reviewer parallel gate
applies: Feasibility reviewer, Completeness reviewer, Scope & Alignment reviewer. **ALL must
PASS before any code is written and before any pour is launched.**

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

Run the full per-change adversarial flow resolved from `adapter.gate.*`. If
`adapter.capabilities.metaswarm` is `yes` (Claude Code runtime), you MAY run the per-unit
loop via `metaswarm:orchestrated-execution` (IMPLEMENT → VALIDATE → ADVERSARIAL REVIEW →
COMMIT) — its different-model reviewer is the cross-model gate. If the repo defines no flow
and metaswarm is absent, the bundled SmokeJumper flow applies: quality/correctness reviewer
→ review-integrity (anti-sycophancy) gate. For user-facing changes, prepend: design
reviewer → first-impression/first-use critic (if `adapter.gate.*` declares one).

**Optional deep bug-hunt.** If `adapter.capabilities.bugsweep` is `yes`, you MAY run a
`bugsweep` pass over the change before push — a deep adversarial bug-hunt (Hunter → Skeptic →
Referee) that complements the correctness reviewer by finding runtime behavioral bugs. Treat
its *confirmed* findings as blockers to fix before the marker is created; it is additive,
never a replacement for the gate. Absent → skip, no functional loss.

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

If `adapter.capabilities.metaswarm` is `yes` (Claude Code runtime) and the change goes
through a pull request, you MAY use `metaswarm:pr-shepherd` to drive the PR through CI and
review-thread resolution to merge; otherwise integrate directly per the discipline above.

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

**(a.1) Update the product context.** Per `references/product-context.md` (Update mode),
reflect what shipped back into the product-context artifact established/read in RECON: check
off completed milestone tasks, advance the `← ACTIVE` marker if a milestone closed, add
shipped items to "Recent Shipped" (hashes from `git log`, never invented), and replace any
metric value that got a real measurement. Update its `Last updated` / `Last commit captured`
headers and commit it to the target repo alongside `repo-knowledge.md`.

For Lane A, use `choo-choo-ralph:harvest` (if present) to harvest learnings from
completed molecule children before synthesizing. The orchestrator also synthesizes
synchronous-lane learnings.

**(b) Framework improvement (when a portable improvement surfaced).** If the sprint
revealed a portable fix — a better recon heuristic, a lifecycle gap, a roster gap worth
bundling, a reference file improvement — the write-back *mode* depends on where this sprint
is running (`references/lessons-learned.md` has the full procedure for both):

- **Inside the canonical plugin repo** (a remote matches `plugin.json.repository` and a push
  would succeed) → **versioned commit**: bump `VERSION` and `plugin.json` per SemVer (MAJOR
  breaking, MINOR features, PATCH fixes), add a `CHANGELOG.md` entry naming the deployment,
  optionally `claude plugin tag`. Record the bump in `sprint-log.jsonl`.
- **Anywhere else** (the common case — the plugin is installed, not a pushable checkout) →
  the improvement can't be committed here. **Generalize and scrub it of every target-repo
  specific** (names, paths, business logic, secrets), then **encourage the user to open a
  pull request** to `plugin.json.repository` so every other deployment benefits. Never
  auto-fork or auto-PR — prepare the materials and hand over the commands; the user pulls
  the trigger.

Either way, if the write-back can't complete (no remote, tag conflict, or the user declines
the PR), record the improvement in `<target>/.smokejumper/repo-knowledge.md` under
"Framework improvements pending" and surface it in the handoff — never leave the sprint
half-finished.

If no portable improvement surfaced, record that stream as N/A in `sprint-log.jsonl`.

"The crew gets better every drop" — directly when SmokeJumper runs on itself, and through
contributed PRs when it runs anywhere else.

**Exit condition:** (a) `repo-knowledge.md` enriched and committed to the target repo.
(b) The portable improvement is either committed (canonical repo), prepared with an
upstream-PR suggestion surfaced in the handoff (anywhere else), or N/A is explicitly
recorded.

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

SmokeJumper hard-requires only: a git repo and the bundled agents + skill + scripts. It runs
best under the Claude Code runtime (subagent dispatch + skills) and degrades to inline persona
adoption under any other orchestrator — including a Codex agent driving the sprint
(`references/runtime.md`). Everything else is detected in RECON and adapted to.

| Target condition | SmokeJumper behavior |
|---|---|
| Has project-specific leads | Adapter prefers them; bundled generics stand down |
| No project leads | Bundled generic leads run |
| `choo-choo-ralph` installed | Lane A (big pour) available |
| `choo-choo-ralph` absent | Offer install; else Lane-B-only; record gap |
| `metaswarm` installed (Claude Code) | Adversarial gate may route through metaswarm (precedence: project gates → metaswarm → bundled) |
| `metaswarm` absent or non-Claude runtime | Bundled adversarial review flow — no functional loss |
| `bugsweep` installed | Optional deep bug-hunt pass in REVIEW before push |
| `bugsweep` absent | Skip the bug-hunt pass — no functional loss |
| Issue tracker present | Use it for durable state (tracker item per phase) |
| No issue tracker | State lives in `<target>/.smokejumper/` only |
| Missing specialist agent | Self-heal: author into target `.claude/agents/` + log gap |
| Has `CLAUDE.md` / `AGENTS.md` | RECON honors its rules as defaults |
| Multiple execution frameworks detected | Ask human which to use — never auto-select |
| Codex agent (or non-Claude) is the orchestrator | Inline-adoption mode: leads + reviewers adopted by reading their definition files; embedded references used directly (`references/runtime.md`) |
| No product context layer | RECON bootstraps one before DECIDE (`references/product-context.md`) |
| Product context layer present | RECON reads it (Context mode); LESSONS LEARNED updates it |

---

## References

- `references/runtime.md` — adopt-vs-dispatch role model + runtime preflight (loaded first in RECON)
- `references/dependencies.md` + `references/dependencies.json` — declared dependency manifest + pin/notify/opt-in update policy (used by `sj-deps-check.sh` and the adapter)
- `references/recon.md` — whole-repo architecture modeling (used in RECON)
- `references/adapter.md` — naming-convention lead + capability detection, implemented by `scripts/sj-adapter-scan.sh` (used in RECON)
- `references/product-context.md` — embedded product-context bootstrap (Context/Setup/Update), with `templates/product-context.md` (used in RECON, DECIDE, LESSONS LEARNED)
- `references/repo-knowledge-schema.md` — schema for `<target>/.smokejumper/repo-knowledge.md` (used in RECON + LESSONS LEARNED)
- `references/gated-pour.md` — spec→pour→formula→launch→monitor→harvest flow (used in EXECUTE)
- `references/self-healing.md` — author-a-missing-agent protocol (used in EXECUTE)
- `references/lessons-learned.md` — dual write-back + version-bump rules (used in LESSONS LEARNED)
