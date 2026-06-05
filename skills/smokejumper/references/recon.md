# Reference: RECON — Repo-Architecture Modeling

RECON runs once per sprint (Phase 1). Goal: build a compact, durable model of the target
repo so every later phase can make decisions grounded in the actual codebase, not
assumptions. You do **not** start planning or writing code here. You read and record.

---

## Inputs

Before doing any file scanning, load prior knowledge:

1. **Read `<target>/.smokejumper/repo-knowledge.md`** if it exists — prior sprint context
   is authoritative. Note any `## Known traps` or `## Framework improvements pending`.
2. **Read `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`** at the repo root — these are the
   project's standing instructions and are the highest-priority source of conventions.
3. **Read primary product docs** (`README.md`, `docs/product/`, `docs/specs/`, or
   equivalent). Capture what the product IS in one sentence. The deeper product-context
   layer (phase, milestones, metrics, blockers) is established by the product-context step
   in the Scanning Protocol below, per `references/product-context.md` — not inferred here.
4. **Check the issue tracker** if one is present: `bd ready` (beads), or a `TODO.md`, or
   open GitHub issues. Note any unresolved blockers or in-flight work that could conflict.
5. **Detect concurrent sessions (shared-working-tree hazard).** Before committing to the
   target's working tree, check for signs that another agent/session is editing it
   concurrently: a dirty index with files you did not stage, the branch HEAD advancing with
   commits you did not author, recently-modified files, or running background loops. If
   detected, **isolate this sprint in a dedicated git worktree** (`git worktree add`) rather
   than sharing the live tree — otherwise INTEGRATE will entangle another session's commits
   into your branch and freshness/staleness pre-commit guards (e.g. a "docs are N commits
   behind" guard) can block your commits for reasons unrelated to your change. Record the
   finding under `## Known traps`.

---

## What to Build

Produce one compact artifact — `repo-knowledge.md` (or update the existing one). Keep it
distilled, not exhaustive. A good entry is 1–3 lines. Entries that span paragraphs are
a sign you are copying, not modeling.

### Sections to populate (match these section names exactly)

**`## Stack`** — language(s), runtime version(s), framework(s), primary database/storage,
key external services. One line each.

**`## Conventions`** — naming conventions (file naming, function naming, branch naming),
indentation / formatter, import ordering rules, test file location pattern. These come from
`CLAUDE.md` + actual file inspection. Do NOT invent conventions — only record what you
observe or what is explicitly declared.

**`## Build / test / lint commands`** — the exact commands needed to build, run tests, run
the linter, and (if applicable) deploy to a preview or staging environment. Verify by
reading `package.json`, `Makefile`, `justfile`, CI configs, or equivalent. Do not
hallucinate commands; if a command is unclear, mark it `# UNVERIFIED`.

**`## Gate locations`** — where quality gates live: CI file paths, pre-commit hook scripts,
coverage config, test threshold files. If safety-critical logic is present (auth/authz,
payments, health/safety verdicts, crypto), note its location with one line — e.g.,
`payments: src/billing/charge.ts`. This is a location note, not a security audit.

**`## Lead & gate mapping`** (populated by the adapter scan — see `adapter.md`):
- Project-specific lead + implementation agents found (`adapter.agents.*`)
- Project-specific gate/review roles found (`adapter.gate.*`)
- Bundled fallbacks that will substitute (and any safety-guardian gap routed to the human)

**`## Model tier`** (populated by the adapter scan):
- Resolved `adapter.model.*` — default tier, escalation tier, model floor

**`## Capabilities`** (populated by the adapter scan):
- Async loop tool (choo-choo-ralph or equivalent): present / absent
- Codex CLI: present / absent
- Issue tracker: type + commands
- Any other orchestration or tooling detected

**`## Known traps`** — gotchas learned in prior sprints (e.g., "deploy requires `--force`
for memory changes", "nested git repo at `backend/` — do not nest commits"). Starts empty
on first sprint; accumulates across sprints.

**`## What worked / What to avoid`** — execution patterns from prior sprints. Starts empty.

**`## Framework improvements pending`** — portable insights queued for the next
lessons-learned write-back to the plugin repo. Starts empty.

---

## Scanning Protocol

Read broadly but record concisely. You are modeling, not auditing.

1. **Start with the root** — `ls` the root, read `CLAUDE.md` / `AGENTS.md`, read `README`.
2. **Identify entry points** — where does the app start? (main function, server listen,
   CLI entrypoint, build script, cloud function exports). List these, do not read them
   fully unless needed to understand the stack.
3. **Identify module structure** — how are source files organized? Feature-by-feature?
   Layer-by-layer? Monorepo packages? One paragraph.
4. **Sample tests** — read one test file to confirm the testing pattern (framework, mock
   style, file naming). Do not read all tests.
5. **Read the CI/CD config** (`.github/workflows/`, `Makefile`, `cloudbuild.yaml`, etc.)
   to confirm the build + test + deploy pipeline. Extract the commands; note any
   environment variable requirements.
6. **Run the deterministic adapter scan** — `scripts/sj-adapter-scan.sh <target>` (the
   executable implementation of `adapter.md`). It writes `## Lead & gate mapping` +
   `## Capabilities` and prints the "Leads established" banner. Then **establish the leads**:
   read the resolved lead definition files (or dispatch them, if your runtime can) per
   `references/runtime.md` — resolving a name is not establishing a lead.
7. **Establish product context** per `references/product-context.md`: read an existing
   product context layer, or — if none exists (the greenfield case) — bootstrap one before
   DECIDE. Record its path under `## Capabilities`.
8. **Stop when you can answer these questions without looking anything up:**
   - What is this product?
   - What language / runtime?
   - How do I run tests?
   - Who are the lead agents for this sprint, and have their definitions been read/adopted?
   - Is a product-context artifact in place (read or bootstrapped)?
   - Are any async loop tools available?
   - Where does safety-critical logic live, if anywhere?

If prior `repo-knowledge.md` already answers a question and nothing in the codebase
contradicts it, trust the prior knowledge — do not re-derive it.

---

## Greenfield / brand-new repo branch

When the target is a brand-new or near-empty repo — little or no source code, no product
docs, no `.claude/agents/` — RECON inverts its priorities. There is nothing to model
architecturally, so do not spin on architecture:

1. The deterministic scan still runs and still resolves the **bundled** leads (visible in the
   banner). For an empty repo that is the expected, correct result — not a failure. Read the
   bundled lead definitions to establish them.
2. **Product context becomes the primary RECON deliverable.** Run the product-context Setup
   path (`references/product-context.md`) and establish the artifact before DECIDE — that is
   what the leads will actually decide from. Do not let DECIDE proceed on a guess inferred
   from an empty README.
3. Record `## Stack` / `## Build / test / lint commands` as "greenfield — none yet" where
   honestly empty rather than inventing commands. Never fabricate a test command for a repo
   that has no tests.

---

## Output

Write (or update) `<target>/.smokejumper/repo-knowledge.md` with the populated sections.
Preserve any prior `## Known traps`, `## What worked / What to avoid`, and
`## Framework improvements pending` entries — never overwrite them; only append.

Emit a short RECON summary to the conversation:
- Runtime + execution mode (subagent dispatch vs. inline-adoption)
- What the product is (one sentence)
- Stack (or "greenfield — none yet")
- Test command
- Lane-A (async) capable: yes / no
- Lead agents resolved AND established (definitions read/adopted) — surface the "Leads established" banner
- Product-context artifact: path + whether read (Context) or bootstrapped (Setup), and verified vs. unverified
- Any blockers or traps found

Then proceed to Phase 2 (DECIDE).
