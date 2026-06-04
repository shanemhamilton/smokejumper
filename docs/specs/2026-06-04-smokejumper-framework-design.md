# SmokeJumper — Framework Design Spec

- **Status:** Approved (brainstorming complete 2026-06-04)
- **Author:** Shane Hamilton + Claude (Opus 4.8)
- **Repo A (this repo, the deliverable):** `~/Documents/SmokeJumper/`
- **Repo B (Deployment #1 dogfood target):** `~/Documents/myskiniq-workspace/`
- **Next step after spec approval:** `superpowers:writing-plans` → implementation plan

---

## 1. What SmokeJumper is

SmokeJumper is a **drop-in, autonomous product-development crew** packaged as a standalone,
marketplace-installable Claude Code plugin. It deploys into *any* repository, lands cold,
assesses what exists, decides the highest-leverage next move itself, executes it under an
Engineering Lead's supervision using a mix of Claude and Codex agents (and, when the work
decomposes, multi-day autonomous Ralph loops), passes the work through a non-negotiable
adversarial review gate, pushes it, runs a lessons-learned pass that makes the framework
itself smarter, and hands off cleanly.

**Two compounding effects per deployment:** the target repo gets better (shipped work +
enriched per-repo knowledge), and the crew gets sharper (a versioned improvement to the
plugin itself).

**Design ethos:** ~90% markdown — portable lead agents + one orchestrator skill whose
instructions encode the lifecycle — plus a small on-disk state convention and at most a
couple of tiny helper scripts. It mirrors the lightness of the `bugsweep` skill. There is
**no bespoke orchestration engine**; the skill's instructions plus existing agents and
plugins (choo-choo-ralph, metaswarm, Codex) do the work.

---

## 2. Architecture at a glance

Two repos, two commit streams, one session:

- **Repo A — `~/Documents/SmokeJumper/`** (the deliverable): its own git repo + GitHub
  remote, structured as an installable Claude Code plugin + a local marketplace manifest.
  *Framework improvements* are SemVer version-bump commits here.
- **Repo B — the target** (Deployment #1 = MySkinIQ): the sprint's *code changes* and the
  *per-repo knowledge file* commit here.

```
Build plugin v0.1.0 in A  →  claude plugin validate (framework "unit test")  →
add A as local marketplace  →  claude plugin install smokejumper@<local>  →
run /smokejumper sprint on B  →  sprint code commits to B
   + repo-knowledge enriches B/.smokejumper/  →
lessons-learned bumps A to vNext (CHANGELOG commit)  →  handoff prompt
```

The dual-write at the end is the compounding mechanism. The two repos are intentionally
separate so per-repo learning never pollutes the portable core, and portable learning never
assumes any one repo's shape.

### Verified mechanism facts (checked 2026-06-04, Claude Code 2.1.156)

- `claude plugin marketplace add <source>` accepts a **local path** → local-marketplace
  install works directly from `~/Documents/SmokeJumper/`.
- `claude plugin validate <path>` validates a plugin/marketplace manifest → free framework
  "unit test" before the expensive sprint.
- `claude plugin install <plugin>@<marketplace>` installs from a named marketplace.
- `claude plugin tag [path]` creates a `{name}--v{version}` git tag, validating that
  `plugin.json` and the marketplace entry agree → maps onto "framework improvement =
  versioned release."

---

## 3. Plugin repo layout (Repo A)

```
~/Documents/SmokeJumper/
├── .claude-plugin/
│   ├── plugin.json              # name: smokejumper, version (SemVer), author, keywords
│   └── marketplace.json         # marketplace entry; source: "." (local) → GitHub URL later
├── agents/                      # PORTABLE generic leads (zero MySkinIQ references)
│   ├── smokejumper-product-lead.md
│   ├── smokejumper-design-lead.md
│   └── smokejumper-engineering-lead.md
├── skills/
│   └── smokejumper/
│       ├── SKILL.md             # the 8-phase orchestrator (the /smokejumper entry point)
│       ├── references/
│       │   ├── recon.md             # repo-architecture-modeling (bugsweep-derived)
│       │   ├── adapter.md           # naming-convention lead + capability detection
│       │   ├── gated-pour.md        # spec→pour→Codex formula→launch→monitor→harvest
│       │   ├── self-healing.md      # author-a-missing-agent protocol
│       │   ├── repo-knowledge-schema.md
│       │   └── lessons-learned.md   # dual write-back + version-bump rules
│       └── scripts/
│           └── sj-init.sh       # scaffolds <target>/.smokejumper/ (only if it earns its place)
├── docs/
│   └── specs/
│       └── 2026-06-04-smokejumper-framework-design.md   # this file
├── CHANGELOG.md                 # one entry per deployment = the crew getting smarter
├── README.md                    # lifecycle, install (latest + pinned), self-improvement
└── VERSION
```

A plugin may bundle agents + a skill together (verified against metaswarm and
claude-code-toolkit plugins on this machine). The plugin system auto-discovers agents
(`agents/*.md`) and skills (`skills/*/SKILL.md`) — no per-component manifest listing needed.

---

## 4. The portable lead agents

Generalized from the MySkinIQ `myskiniq-*-lead` agents by stripping project-specific bindings
(Firestore, `docs/product/` paths, hardcoded reviewer names, numeric baselines) and replacing
them with **role contracts** the orchestrator fills at runtime.

| Generic agent | Role | Keeps from MySkinIQ original | Becomes runtime-detected |
|---|---|---|---|
| `smokejumper-product-lead` | Decides WHAT (assess → prioritize → spec) | Outcome-driven philosophy; "creator, not certifier"; anti-hallucination gates | product-doc paths, metrics, named reviewers |
| `smokejumper-design-lead` | UX/design direction for user-facing work | Hands off; never self-certifies | design-system tokens, named design gate |
| `smokejumper-engineering-lead` | ORCHESTRATOR: decompose → route lanes → dispatch Claude+Codex → drive gates → merged+pushed | 5-stage flow; Codex-for-bulk; submodule-first git discipline; "not done until pushed"; never-edit-safety-logic | tracker commands, deploy tooling, project agent roster |

All three agents are `model: opus` — these are judgment-heavy roles (the MySkinIQ
product-lead and engineering-lead originals are opus; verified 2026-06-04). They obey the
global model floor (Sonnet minimum for dispatched Claude work; never Haiku) and the Codex
token-conservation rules. Model tier is tunable per target-repo conventions detected in RECON.

### Adapter layer (the key portability move)

On arrival, RECON scans the target's `.claude/agents/` for role patterns:
`*-product-lead`, `*-engineering-lead`, `*-design-*` (and design *director/reviewer* gate
patterns). If a project-specific lead matches a role, **it is preferred** and the bundled
generic stands down. On MySkinIQ this means the real `myskiniq-product-lead` /
`-engineering-lead` / `-design-lead` drive the sprint — proving the adapter on drop #1. On a
bare repo, the generics run.

Capability detection extends to plugins: RECON also checks whether `choo-choo-ralph`,
`metaswarm`, Codex CLI, and an issue tracker (beads etc.) are present, and records what's
available so EXECUTE can choose lanes accordingly. SmokeJumper **never hard-requires** any of
these — it degrades gracefully and records the gap.

---

## 5. The `/smokejumper` orchestrator — 8-phase lifecycle

The SKILL.md is the spine. Each phase maps to a concrete mechanism.

### Phase 1 — RECON
Build a repo model using bugsweep's repo-architecture-modeling (whole-repo structure, stack,
conventions, where the safety/quality gates live). Read existing `CLAUDE.md`/`AGENTS.md`,
product docs, the issue tracker, **and** `<target>/.smokejumper/repo-knowledge.md` if a prior
drop left one. Run the adapter + capability scan here. Output: a compact repo model + the
detected lead mapping + available-capabilities list.

### Phase 2 — DECIDE
The detected (or generic) leads autonomously choose the highest-leverage next move for the
product. **More autonomy than metaswarm:** the leads decide *what to do*, not a fixed
pipeline. Escalate to the human **only** for product strategy / budget / release authority
(per the "make decisions or delegate — never punt" rule).

### Phase 3 — PLAN (the authorizing adversarial gate)
The leads produce the design + implementation plan (a lightweight, momentum-biased planning
step). That design and plan are then **put through the full adversarial flow** (quality-control
→ domain guardians → antisycophancy-gate; plus design/first-impression/thesis reviewers for
user-facing work). Creation and review are distinct: the leads create, the adversarial flow
reviews. This is where human-grade judgment is spent. **PASS here authorizes execution — including
authorizing any autonomous pour.** Biased toward momentum: the gate catches bad assumptions
and unsafe decomposition; it does not re-architect vetted work.

The plan explicitly marks, per work unit, which **lane** it belongs to (see Phase 4) and
flags any **safety-critical** units (which are barred from the pour).

### Phase 4 — EXECUTE (two lanes)
The Engineering Lead's decompose step routes each work unit using the **generalized
Ralph-vs-synchronous decision table** (portable version of the table in MySkinIQ's CLAUDE.md):

- **Lane A — the "big pour" (async, hours→days).** For large, decomposable, plan-vetted,
  non-safety bulk. Convert the approved plan via `choo-choo-ralph:spec` →
  `choo-choo-ralph:pour` into a beads molecule whose children's formula runs **Codex**
  (`model_reasoning_effort="high"`, zero Claude tokens) **plus per-child mechanical gates**
  (tests-green, build, `tsc`/lint, coverage). Launch **one or more** `nohup ./ralph.sh &`
  loops grinding `bd ready --parent <mol-id>`. State lives in beads → survives every context
  reset. This is the "go bigger" engine.
- **Lane B — synchronous crew (in-session).** For novel/architectural/design-sensitive/
  safety-critical units. The Engineering Lead dispatches Claude + Codex agents directly
  through the full adversarial flow to merged+pushed.

Lane selection heuristic (the portable decision table):

| Signal | Lane A (pour / Ralph) | Lane B (synchronous crew) |
|---|---|---|
| Work style | Async, unattended, walk away | Sync, human present |
| State lives in | Beads (survives reset) | Session context |
| Duration | Hours / days | Minutes / one session |
| Shape | Batch over N items, repeatable | Novel, architectural decisions |
| Safety-critical? | **Never** (barred) | Yes — routed to guardians |
| Plan already vetted? | Required | Required |

### Phase 5 — REVIEW (layered, because the heavy gate is front-loaded)
1. **Lane B units:** full adversarial flow before push, exactly as the originals.
2. **Lane A children:** the **per-child mechanical gates** baked into the formula prevent a
   *buggy implementation of a vetted plan* from pushing. A child that can't pass parks for
   the next loop or files a blocker bead.
3. **Milestone spot-check:** at molecule milestones (and at harvest), a Claude adversarial
   spot-check samples completed children — cheap insurance over the autonomous batch.

`.adversarial-review-passed` is created only when the cycle's gate obligations are met. The
SessionStart hook clears it each session so it can never go stale; the gate is never a
formality. **Hard exclusion:** safety-critical units (scoring/allergen/ED/child-safety) are
never poured — no plan-review substitutes for a guardian reading the actual diff.

### Phase 6 — INTEGRATE
Commit and push (standing push authority granted). **Merging ≠ deploying:** never run a
deploy/release without explicit human greenlight. Honor target-repo git discipline detected
in RECON (e.g., submodule-first on MySkinIQ).

### Phase 7 — LESSONS LEARNED (dual write-back)
Mechanism: `choo-choo-ralph:harvest` (when present) harvests learnings + gaps from completed
molecule children; the orchestrator also synthesizes synchronous-lane learnings. Two streams:
- **(a) Per-repo:** enrich `<target>/.smokejumper/repo-knowledge.md`. Commits to the target.
- **(b) Framework:** if the sprint surfaced a *portable* improvement (a better recon
  heuristic, a roster gap worth bundling, a lifecycle fix), make a **versioned commit to
  Repo A**: bump `VERSION`/`plugin.json` per SemVer, add a `CHANGELOG.md` entry naming the
  deployment, optionally `claude plugin tag`. "The crew gets better every drop" = a plugin
  version bump, never a mutation of loose files.

### Phase 8 — HANDOFF
Finish with `anthropic-skills:handoff-prompt` so the next session resumes with zero lost
context and no hallucinated state. When Lane A loops are still running, the handoff explicitly
hands off the **running loops**: what's pouring, how to monitor (`bd ready --parent <mol-id>`),
mechanical-gate status, and when/how to harvest.

---

## 6. Recon + compounding repo-knowledge

A persisted per-repo store in the **target** repo (bugsweep's `.bugsweep/` is the model),
committed so it survives context resets and benefits the next drop:

```
<target>/.smokejumper/
├── repo-knowledge.md     # durable, accumulative: stack, conventions, gate locations,
│                         #   lead mapping, available capabilities, known traps,
│                         #   "what worked / what to avoid here"
├── sprint-log.jsonl      # append-only event ledger (phases, decisions, gate outcomes,
│                         #   pour molecule IDs) — generalizes bugsweep's intra-run ledger
└── gaps.jsonl            # missing-agent / missing-capability gaps for later graduation
```

RECON **loads** `repo-knowledge.md` on arrival; LESSONS-LEARNED **enriches** it on departure.
The core is decoupled from any tracker — beads is an *optional adapter*, not a dependency, so
SmokeJumper still works on a repo with no issue tracker (state then lives only in
`.smokejumper/`).

---

## 7. Self-healing crew

When a sprint needs a specialist agent that doesn't exist: the framework authors a new agent
on the fly (skill-creator / agent-definition conventions — markdown with `name`/`description`/
`tools`/`model` frontmatter), writes it to the **target repo's `.claude/agents/`** (available
this sprint, committed to the target), registers it, uses it, and records the gap in
`<target>/.smokejumper/gaps.jsonl`. Repo-specific by default — no premature generalization.
A gap that **recurs across repos** becomes a candidate to graduate into the plugin during a
*framework* lessons-learned pass (a versioned commit to Repo A).

---

## 8. Portability & graceful degradation (the "drop into any repo" contract)

| Target condition | SmokeJumper behavior |
|---|---|
| Has project-specific leads | Adapter prefers them; generics stand down |
| No project leads | Bundled generic leads run |
| `choo-choo-ralph` installed | Lane A (big pour) available |
| `choo-choo-ralph` absent | Offer `choo-choo-ralph:install`, else Lane-B-only; record gap |
| Issue tracker present (beads etc.) | Use it for durable state |
| No issue tracker | State lives in `<target>/.smokejumper/` only |
| Missing specialist agent | Self-heal: author into target `.claude/agents/` + log gap |
| Has `CLAUDE.md`/`AGENTS.md` | RECON honors its rules as defaults (model floor, git discipline, gates) |

SmokeJumper hard-requires only: a git repo, the Claude Code runtime, and the bundled agents +
skill. Everything else is detected and adapted to.

---

## 9. Dogfood — Deployment #1 (on MySkinIQ)

The leads DECIDE the target during Phase 2 — that *is* the dogfood. Because we want to
exercise the big-pour lane, Sprint #1 targets something **substantial and decomposable**
(pours into many children), not a single bounded item. End-to-end validation, in one session,
with the grind continuing async:

1. RECON + DECIDE + PLAN on a substantial, decomposable MySkinIQ target.
2. Pass the **plan** through the real adversarial gate (authorize the pour).
3. `pour` the molecule + launch the Ralph loop(s) on Codex.
4. **In-session validation gates (all must hold):**
   - The plan passed the adversarial gate.
   - The pour generated a well-formed molecule (`bd ready --parent <mol-id>` resolves).
   - At least **one Lane-A child lands through its mechanical gates** (proves the formula).
   - The synchronous lane ships **at least one unit** through the full adversarial flow + push.
   - Repo-knowledge file written to `<target>/.smokejumper/`.
5. **Handoff prompt hands off the running loops** so the days-long grind continues cleanly.
6. **Framework lessons-learned:** bump Repo A to vNext from what the dogfood taught; push
   both repos.

Safety-critical MySkinIQ logic (scoring/allergen/ED/child-safety) is excluded from the pour by
policy; if the leads' chosen work touches it, those units route synchronously to the guardian
agents.

---

## 10. Build sequence (input to writing-plans)

1. Scaffold Repo A: `plugin.json`, `marketplace.json`, `VERSION`, `README.md`, `CHANGELOG.md`;
   `claude plugin validate` green.
2. Write the 3 portable lead agents (generalized from the MySkinIQ originals).
3. Write `skills/smokejumper/SKILL.md` + the 6 reference files.
4. Add the local marketplace; `claude plugin install smokejumper@<local>`; confirm
   `/smokejumper` resolves and the agents load.
5. Run Sprint #1 on MySkinIQ end-to-end → in-session validation gates → handoff.
6. Framework lessons-learned: bump Repo A to v0.2.0 from the dogfood; push A and B.

---

## 11. Explicitly out of scope (YAGNI)

- A heavy bespoke orchestration engine. The skill's instructions + existing agents/plugins
  (choo-choo-ralph, metaswarm, Codex) are the engine.
- Tracker-coupled core logic. Beads stays an optional adapter; the portable core uses
  `.smokejumper/` files.
- Auto-deploy / auto-release. Merging ≠ deploying; releases need explicit human greenlight.
- Auto-graduating self-healed agents into the plugin. Graduation is a deliberate, versioned
  framework decision, not an automatic side effect of one sprint.

---

## 12. Open risks & mitigations

| Risk | Mitigation |
|---|---|
| Local plugin install path differs from assumption | Verified `marketplace add <path>` + `install <plugin>@<marketplace>` exist (2026-06-04); step 4 confirms `/smokejumper` resolves before the sprint |
| Autonomous Codex pour ships a subtly wrong implementation of a vetted plan | Per-child mechanical gates + milestone adversarial spot-check; safety logic barred from pour |
| Days-long loops can't finish in-session, dogfood looks "incomplete" | In-session validation proves the *mechanism* (one child through gates); handoff explicitly carries the running loops |
| Generic leads drift back toward MySkinIQ specifics | Generics carry zero project references; adapter injects project context at runtime; framework lessons-learned reviews for leakage |
| SmokeJumper files leak into MySkinIQ commits | Repo A is a sibling repo; `.smokejumper/` is the only thing written into the target, deliberately and committed there |
```

