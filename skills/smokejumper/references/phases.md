# Phase detail — SmokeJumper sprint lifecycle

Detailed procedure per phase. `SKILL.md` holds the skeleton, invariants, and exit
conditions; this file holds the how-to. Load the section for the phase you are entering.

---

## Phase 1 — RECON (detail)

**Runtime preflight (first).** Per `runtime.md`, self-identify your runtime and pick the
execution mode: can you dispatch subagents, and can you invoke the Skill tool? If not —
e.g. a Codex agent is the top-level orchestrator — run in **inline-adoption mode**: adopt
lead and reviewer personas by reading their definition files, and use the embedded
reference files directly. Record the runtime in the RECON summary and `sprint-log.jsonl`.
Never block on a subagent dispatch or Skill-tool call your runtime cannot make.

Build a compact repo model using the whole-repo architecture approach defined in
`recon.md`. Read `CLAUDE.md` or `AGENTS.md` and any equivalent project-memory files,
product docs, and the issue tracker (if present). Load
`<target>/.smokejumper/repo-knowledge.md` if a prior drop left one.

**Run the adapter scan:** `scripts/sj scan <target>`. It implements the detection in
`adapter.md`, scaffolds `.smokejumper/`, resolves leads/gates/capabilities, writes
`## Lead & gate mapping` + `## Capabilities` into `repo-knowledge.md`, writes the
machine-readable `adapter-scan.json` (parse THIS for `adapter.*` values downstream — not
the markdown), emits events, and prints the "Leads established" banner. The scan resolves:

- Project-specific leads (patterns: `*-product-lead`, `*-engineering-lead`, `*-design-*`).
  A project-specific match is preferred; the bundled generic stands down.
- Gate-review agents (`adapter.gate.*`) — adapter-conditional; a gate role exists only if
  the target repo declares it. Never fabricate a gate with a bundled generic.
- Capabilities (`adapter.capabilities.*`): choo-choo-ralph (Lane A), Codex CLI, metaswarm,
  bugsweep, issue tracker.
- Design-system candidate paths (`adapter.designSystem`) — hints only; the design lead
  does the authoritative search and owns `## Design system` in `repo-knowledge.md`.
- Design skills (`adapter.skills.design.*`) and the windowed
  `functionalHealth` → `designPosture` derivation (`adapter.health.*`). RECON may adjust
  the derived health one level for live test/build status it gathers, and surfaces
  previously-proven design skills from the `## Design skills` tally as recommendations.

Items the scan does NOT resolve — RECON reads these from the target itself:
- Model-tier rules from the target's CLAUDE.md (`adapter.model.*`).
- Git discipline: submodule layout, branch conventions, merge policy, merge command.
- Coverage thresholds file.

**Establish the leads.** Resolving names is not establishing leads. A lead is established
only when its resolved definition file has been read and adopted (or dispatched, if your
runtime supports it). Read the resolved product / engineering / design lead definitions
before DECIDE, and surface the banner the scan printed.

**Bootstrap product context.** The scan reports `productContext` (banner, `## Capabilities`,
and `adapter-scan.json`). If present, read it (Context mode per `product-context.md`); if
MISSING, establish one (Setup mode) before DECIDE, write the durable artifact, and record
its path under `## Capabilities`. On a greenfield repo this is the most important RECON
output. **Do not advance to DECIDE with `productContext: MISSING` unresolved.**

Record everything as a compact repo model. Do not read every source file; read CLAUDE.md,
key architecture docs, and the adapter scan output.

---

## Phase 2 — DECIDE (detail)

The product lead drives. Inputs: RECON's repo model, the product-context artifact
(authoritative — read it and quote it; do not re-infer product direction), the issue
tracker, `repo-knowledge.md`, and `designPosture` from `adapter-scan.json`. If the
product-context artifact is marked `unverified` (generated without a human interview),
treat it as provisional and weight its `[TODO]` gaps accordingly.

**Autonomy scope:** the leads decide *what to build*, in what order, and why. Escalate to
the human **only** for product strategy / budget / release authority. Everything within
that mandate is decided with explicit reasoning and a kill condition — never punted as a
clarifying question.

Decision outputs: the chosen objective in one sentence; the rationale (which metric it
moves, which bet it validates, why this and not something else); an explicit kill
condition (threshold, metric, window); a preliminary lane signal (batch → Lane A
candidate; ongoing judgment → Lane B). Formal lane assignment happens in PLAN.

Emit an `objective_chosen` event to `sprint-log.jsonl` (this is what
`sj validate-state --phase DECIDE` checks). If a tracker is present, record it there too.

---

## Phase 3 — PLAN (detail)

The leads produce the design and implementation plan:

- The **design lead** produces design direction, flows, component patterns, states, and
  microcopy (for user-facing work). It reads the detected design system before touching
  anything — never invents tokens or hue values. If RECON found no design system, it
  documents the baseline it establishes. When it invokes a resolved design skill, it
  appends a `design_skill_invoked` event (per `smokejumper-design-lead.md` §3.1) —
  the producer side of the effectiveness loop LESSONS LEARNED scores.
- The **product lead** produces the feature spec (problem, goals, non-goals, requirements,
  tracking plan, acceptance criteria, kill condition).
- The **engineering lead** decomposes work into units, assigning each a lane and a
  safety flag. Run `sj lane-check <target> <unit-spec-file>` on every unit headed for
  Lane A — a `DENY-ADVISORY` verdict bars it from Lane A regardless of judgment; a
  `CLEAR` verdict does not replace judgment.

**The authorizing gate.** After the plan is drafted, run the full adversarial flow on the
design and plan using gate roles from `adapter.gate.*`. Gate precedence: **project gates →
metaswarm (if detected, Claude Code runtime) → bundled fallback** (three parallel
reviewers: Feasibility, Completeness, Scope & Alignment). ALL must PASS before any code is
written and before any pour is launched. For user-facing work, the design adversarial flow
runs in parallel: design reviewer → first-impression critic → product-thesis guardian →
review-integrity gate (each only if present in `adapter.gate.*`).

When the gate passes, the engineering lead records it:
`sj gate record plan-vetted --target <target> --reviewers <reviewers-that-ran>`.
Biased toward momentum: the gate catches bad assumptions and unsafe decomposition; it does
not re-architect vetted work.

---

## Phase 4 — EXECUTE (detail)

### Lane A — async pour (hours to days)

For large, decomposable, plan-vetted, non-safety-critical bulk. Requires choo-choo-ralph
(detected in RECON); if absent, offer to install it or fall back to Lane B and record the
gap in `gaps.jsonl`. **Before launching any pour:** `sj gate check plan-vetted --target
<target>` must pass, and every poured unit must have a CLEAR `sj lane-check` verdict.

Follow `gated-pour.md` for spec→pour→formula→launch→monitor→harvest:
1. `choo-choo-ralph:spec` → `choo-choo-ralph:pour` into a molecule whose children run
   Codex at `model_reasoning_effort="high"` (never `xhigh`) plus per-child mechanical
   gates (tests, build, type-check/lint, coverage thresholds).
2. Launch `nohup ./ralph.sh &` loops grinding `bd ready --parent <mol-id>` (or tracker
   equivalent).
3. Record molecule IDs in `sprint-log.jsonl` so a context reset can resume monitoring.

### Lane B — synchronous crew (in-session)

For novel, architectural, design-sensitive, or safety-critical units. The engineering
lead dispatches Claude + Codex agents directly; safety-critical units route to guardians
(`adapter.agents.safetyGuardian` / `invariantGuardian`; if null → route to the human and
log a gap). Build flow per unit: Plan → TDD (red→green) → implement → `/simplify` (or
detected equivalent) → adversarial review (Phase 5) → cross-model Codex review → PR
review → push.

### Self-healing, framework selection, model tier

- Missing specialist agent → author one per `self-healing.md` into
  `<target>/.claude/agents/`, use it, record the gap in `gaps.jsonl`.
- More than one synchronous execution framework detected → **ask the human which to use**;
  state the tradeoff. Never auto-select.
- Model tier per `adapter.model.*`: Sonnet floor for all Claude work (sessions AND API
  calls); Opus only on the target CLAUDE.md's escalation triggers; Codex for large
  self-contained context-free work; never `xhigh` reasoning effort.

---

## Phase 5 — REVIEW (detail)

**Lane B units — full adversarial review before push.** Run the per-change flow resolved
from `adapter.gate.*`. With metaswarm (Claude Code runtime) you MAY run the unit loop via
`metaswarm:orchestrated-execution`. If the repo defines no flow and metaswarm is absent,
the bundled flow applies: quality/correctness reviewer → review-integrity gate; for
user-facing changes, prepend design reviewer → first-impression critic.

**Optional deep bug-hunt.** If bugsweep is present you MAY run it before push; treat its
*confirmed* findings as blockers to fix before recording the gate. Additive, never a
replacement.

**Recording the gate.** Only the engineering lead runs
`sj gate record adversarial-review --target <target> --reviewers <gate-agents-that-ran>`,
and only after every applicable gate obligation is met. Sub-agents never record gates on
their own work. Before any push: `sj gate check adversarial-review --target <target>`
must pass — it verifies the marker's cited events exist in the log, the reviewed commit
is an ancestor of HEAD, and no EXECUTE work postdates the review.

**Lane A children — mechanical gates only.** Tests green, build passes, type-check/lint
clean, coverage at thresholds. A child that cannot pass parks or files a blocker. The
heavy adversarial review was spent at the Phase 3 plan gate (`plan-vetted` marker); it is
not re-run per child. Milestone spot-checks sample 10–20% of completed children.

---

## Phase 6 — INTEGRATE (detail)

Commit and push with standing authority, honoring the git discipline detected in RECON:
submodule-first when applicable; stage specific files by name (never `git add -A`/`.`);
read `git status` before every `git add`; no `--amend` on shared commits; no
`--no-verify`; no force-push to shared branches; admin-merge only if that is the repo's
detected policy. With metaswarm (Claude Code) and a PR flow, `metaswarm:pr-shepherd` MAY
drive the PR to merge.

After the push succeeds, emit a `push_completed` event to `sprint-log.jsonl` (checked by
`sj validate-state --phase INTEGRATE`).

---

## Phase 7 — LESSONS LEARNED (detail)

Follow `lessons-learned.md` for the dual write-back. Two streams, both required:

**(a) Per-repo enrichment.** Synthesize learnings; enrich `repo-knowledge.md` in place
(schema: `repo-knowledge-schema.md`); commit to the target repo.
- **(a.1)** Update the product context (Update mode per `product-context.md`): check off
  milestones, advance `← ACTIVE`, add Recent Shipped entries (real hashes from `git log`),
  update headers, commit alongside `repo-knowledge.md`.
- **(a.2)** Score design-skill effectiveness: for each `design_skill_invoked` event, apply
  the gate-or-ship proxy from `lessons-learned.md`, update the `## Design skills` tally
  (owned by this phase — the scan never writes it), emit `design_skill_outcome`, and
  persist `functionalHealth`/`designPosture` for the sprint.
- For Lane A, run `choo-choo-ralph:harvest` (if present) before synthesizing.

**(b) Framework improvement** (when a portable improvement surfaced):
- Inside the canonical plugin repo → versioned commit: bump `VERSION` + `plugin.json`
  per SemVer, CHANGELOG entry, optional tag.
- Anywhere else → generalize, scrub every target-repo specific, and prepare an upstream-PR
  suggestion for the user. Never auto-fork or auto-PR.
- If the write-back can't complete, record it under "Framework improvements pending" in
  `repo-knowledge.md` and surface it in the handoff.

Emit `write_back_completed` when stream (a) is committed (checked by
`sj validate-state --phase LESSONS`). If no portable improvement surfaced, record stream
(b) as N/A in `sprint-log.jsonl`.

---

## Phase 8 — HANDOFF (detail)

Invoke `anthropic-skills:handoff-prompt`; if not installed, write
`<target>/.smokejumper/HANDOFF.md` covering the same content.

If Lane A loops are still running, the handoff explicitly carries: pouring molecules and
their monitor commands, per-child gate status, spot-check state, when/how to harvest, and
any parked blocker children. It also carries the sprint objective, open follow-ups in the
tracker, the current `sprint-log.jsonl` state, gate marker status (`sj gate check` output),
and any pending deploy/release greenlight.
