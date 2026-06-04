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
   equivalent). Capture what the product IS in one sentence.
4. **Check the issue tracker** if one is present: `bd ready` (beads), or a `TODO.md`, or
   open GitHub issues. Note any unresolved blockers or in-flight work that could conflict.

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

**`## Lead mapping`** (populated by the adapter scan — see `adapter.md`):
- Project-specific lead agents found (engineering, design, product, etc.)
- Project-specific gate/review roles found
- Bundled fallbacks that will substitute

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
6. **Run the adapter scan** per `adapter.md`. Record results in `## Lead mapping` and
   `## Capabilities`.
7. **Stop when you can answer these questions without looking anything up:**
   - What is this product?
   - What language / runtime?
   - How do I run tests?
   - Who are the lead agents for this sprint?
   - Are any async loop tools available?
   - Where does safety-critical logic live, if anywhere?

If prior `repo-knowledge.md` already answers a question and nothing in the codebase
contradicts it, trust the prior knowledge — do not re-derive it.

---

## Output

Write (or update) `<target>/.smokejumper/repo-knowledge.md` with the populated sections.
Preserve any prior `## Known traps`, `## What worked / What to avoid`, and
`## Framework improvements pending` entries — never overwrite them; only append.

Emit a short RECON summary to the conversation:
- What the product is (one sentence)
- Stack
- Test command
- Lane-A (async) capable: yes / no
- Lead agents resolved (project-specific or bundled fallback)
- Any blockers or traps found

Then proceed to Phase 2 (DECIDE).
