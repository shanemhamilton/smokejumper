# Reference: Product Context — embedded bootstrap

Loaded in RECON (Phase 1), after the repo model + adapter scan. Read in DECIDE (Phase 2) and
updated in LESSONS LEARNED (Phase 7).

**Why this exists.** SmokeJumper's leads decide *what to build next*. That decision is only as
good as the product context behind it. Reading the README and inferring from the codebase is
enough on a mature repo with product docs — but on a **brand-new / greenfield repo there is
almost nothing to infer from**, and "infer from the README" silently degrades to guessing.
This reference makes product context a **bootstrapped artifact**, not an inference: if no
product context layer exists, SmokeJumper establishes one before DECIDE.

**Self-contained by design.** This bootstrap depends on **no external skill** — not
`product-pilot`, not the Skill tool. It works identically under a Claude Code session and a
Codex orchestrator. The template lives at `templates/product-context.md`. (If a richer
product-doc skill *is* installed and your runtime can invoke it, you may use it instead — but
never block on one; this file is always sufficient.)

---

## The artifact

A single durable file: the **Product Context** (a compact PRODUCT_PILOT-style brief).

**Location (resolve in this order):**
1. An existing product context layer if one is found (see Detect) — use it in place.
2. Else, if the target repo has a `docs/` tree (or it is acceptable to create one):
   `<target>/docs/product/PRODUCT_PILOT.md`.
3. Else (do not want to touch `docs/`, or a doc-free repo):
   `<target>/.smokejumper/product-context.md`.

Whichever path is used, record it in `repo-knowledge.md` under `## Capabilities` as
`productContext: <path>` so later phases and future sprints find it without re-searching.

---

## Mode detection

Run these checks at the start of the product-context step:

| Signal | Mode |
|---|---|
| A product context layer already exists (`docs/product/PRODUCT_PILOT.md`, `docs/product/*`, `PRODUCT.md`, or `<target>/.smokejumper/product-context.md`) | **Context** |
| Called from LESSONS LEARNED after shipping | **Update** |
| No product context layer found anywhere | **Setup** |

---

## Context mode (artifact exists — the common case after sprint 1)

1. Read the artifact (and any sister docs it references).
2. Produce a ≤150-word orientation for DECIDE: current phase + goal; the active milestone and
   its unchecked tasks; the top blocker; metrics at or below target; any decision pending >30
   days old.
3. Freshness check: if the artifact names a "last commit captured" hash that is >10 commits
   behind `git rev-parse --short HEAD`, flag the "Recent Shipped" section as stale.
4. Hand the orientation to DECIDE. Do **not** re-run Setup.

---

## Setup mode (no artifact — the brand-new-repo case)

This is the path the greenfield scenario hits. Establish the product context layer **before**
DECIDE so the leads decide from grounded context, not a near-empty repo.

### Step 1 — Pre-fill from what exists
Before asking the human anything, mine the repo for answers: README, any `docs/`, package
manifests, the issue tracker, and git history. For each interview question below, mark the
pre-filled answer HIGH / MEDIUM / LOW confidence. Never reference a file that does not exist.

### Step 2 — Compact discovery interview
Ask only what the pre-fill did not resolve at HIGH confidence. Batch the questions in one pass
(do not dribble them one at a time). Keep it to these ten:

1. **What is the product?** (2–3 sentences: what it does, who it's for, what's different.)
2. **Who are the target users?** (2–3 segments, each with its main pain point.)
3. **What phase?** (Ideation / MVP / Launch / Validate / Monetize / Grow / Mature.)
4. **What's the single biggest blocker right now?**
5. **Core product principles** (3–5 rules that guide every decision).
6. **Top metrics + targets** (up to 5; pre-launch values are "Pre-launch").
7. **Current-phase milestones** (2–4, in order; each with a completion signal).
8. **What triggers moving to the next phase?** (a data-driven condition, not a date).
9. **Top 2–3 competitors / alternatives** (incl. "the status quo / doing nothing").
10. **Key differentiator** (one sentence).

**Autonomous-run fallback (no human available to interview).** If the sprint is running fully
autonomously and there is no human to answer, do **not** fabricate. Infer what the codebase and
README support, mark every unknown as `[TODO: ...]`, and stamp the artifact header
`<!-- status: unverified — generated without human interview -->`. Surface in the RECON summary
that product context is unverified so DECIDE weights it accordingly.

### Step 3 — Write the artifact
Fill `templates/product-context.md` with the answers and save it to the resolved location.
Replace every `[PLACEHOLDER: ...]` with real content or a `[TODO: ...]` marker. **No
`[PLACEHOLDER: ...]` may survive into the saved file** — only `[TODO: ...]` is allowed.

Commit the artifact to the target repo as part of the sprint (not a standalone cleanup
commit). Record its path under `## Capabilities` in `repo-knowledge.md`.

---

## Update mode (LESSONS LEARNED, Phase 7)

After the sprint ships, reflect reality back into the artifact:

| What changed | Update |
|---|---|
| A milestone's tasks completed | Check them off; if all done, advance the `← ACTIVE` marker to the next milestone |
| Phase transitioned | Move `← ACTIVE` to the first milestone of the new phase; update "Current phase" |
| Work shipped | Add a line to "Recent Shipped" (`<short_hash> <one-line summary>` — hash from `git log`, never invented) |
| A metric got a real measurement | Replace Pre-launch/TBD with the measured value |
| A new blocker / unblock | Update "What's Blocking Ship" (bulleted: blocker / unblock condition / owner / since-date) |

Update the artifact's `<!-- Last updated: -->` and `<!-- Last commit captured: -->` headers.
Commit alongside the `repo-knowledge.md` enrichment.

---

## Anti-fabrication rules (non-negotiable)

These are the same standards the product lead operates under — they apply to every word of the
artifact:

- **Never invent a metric value, target, conversion rate, or revenue figure.** Unknown → `[TODO: add target]` or "Pre-launch".
- **Never invent competitor facts** (pricing, user counts, feature status, funding) → `[TODO: research]`.
- **Never invent commit hashes** for "Last commit captured" or "Recent Shipped" — derive from `git log` / `git rev-parse`.
- **Never invent product names, persona names, or milestone names.** Use only what the human gave you or what the codebase verifies.
- **Don't round or approximate** ("28% retention", not "~30%").
- All phase-transition triggers are **data-driven, not calendar-driven**.
- A completion signal must be observable (a passing test, a metric threshold, a deploy, a user count) — never "feels done".
