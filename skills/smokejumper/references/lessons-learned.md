# Reference: Lessons Learned — Dual Write-Back and SemVer Versioning

Phase 7 (LESSONS LEARNED) is the mechanism by which SmokeJumper accumulates intelligence
across sprints. It has two distinct write paths:

1. **Intra-project write-back** — enrich the target repo's `.smokejumper/repo-knowledge.md`
   with what this sprint revealed about this codebase.
2. **Plugin write-back** — commit a portable improvement to the plugin repo (Repo A) when
   a finding is applicable across projects.

The crew gets better every drop — a plugin version bump, never a mutation of loose files.

---

## Write-back 1: Intra-project (always runs)

After every sprint, update `<target>/.smokejumper/repo-knowledge.md`:

### What to update

**`## Known traps`** — append any new gotchas discovered this sprint. Never delete prior
entries. Examples of trap-worthy findings:
- A command that behaves differently than its name suggests
- A dependency that requires a specific version lock for reasons not documented elsewhere
- A silent failure mode that produces misleading output
- A gate that fires inconsistently under certain conditions
- A naming convention exception that overrides the general rule

**`## What worked / What to avoid`** — append execution patterns that proved effective or
harmful this sprint. Never delete prior entries. Examples:
- "Lane A pour on data-migration tasks completed in 4h unattended — good candidate for
  future automation"
- "Parallel agent dispatch on UI + backend simultaneously caused merge conflicts — route
  sequentially on this repo"
- "Codex review caught 2 real bugs the in-session review missed — always run it"

**`## Framework improvements pending`** — append any portable insight that is not
yet written back to the plugin. This is a staging area. Cleared after each successful
plugin write-back. If no plugin write-back happens this sprint, entries persist and carry
forward to the next sprint.

### Harvesting from completed molecule children

If a Lane A pour ran this sprint, use `choo-choo-ralph:harvest` (or equivalent) to
collect learnings from completed children before writing the lessons-learned section.
Do not reconstruct learnings from memory — harvest from the actual completed work items.

If no async loop tool is available (a Lane-B-only sprint), synthesize learnings directly
from `sprint-log.jsonl` and the session instead of `choo-choo-ralph:harvest`.

### Commit discipline

Update `repo-knowledge.md` as a commit in the target repo — not as a standalone cleanup
commit, but appended to the nearest logical sprint-closing commit. The update must be
in version control before the sprint is closed.

---

## Write-back 2: Plugin (conditional — runs when a portable improvement exists)

A plugin write-back happens when `## Framework improvements pending` contains at least
one entry that passes the portability test:

**Portability test:**
- Would this make sense in a B2B SaaS project?
- Would this make sense in a CLI tool?
- Would this make sense in a consumer app?

All three must be YES. If any is NO, the finding stays in the target repo's
`repo-knowledge.md` as a project-specific trap — it does not graduate to the plugin.

### Determine the write-back mode

The portability test decides *whether* an improvement should reach the plugin. The mode
decides *how* — and it turns on whether this sprint is running inside the canonical plugin
repo or inside some other target repo that merely has the plugin installed.

- **Mode A — maintainer (direct commit).** The current working tree is a git checkout of
  the canonical plugin repo: a remote matches `plugin.json.repository` and a push to it
  would succeed. Commit the improvement directly (Mode A procedure below).
- **Mode B — contributor (prepare an upstream PR).** Anything else — most commonly the
  plugin is installed as a read-only package and is not a pushable checkout at all. The
  improvement cannot be committed here. Prepare it for contribution and **encourage the
  user to open a pull request** to the canonical repo, so every other deployment benefits
  from the learning.

When in doubt, use Mode B. Encouraging an upstream contribution is always safe; committing
to a repo you don't own is not.

### Mode A procedure — direct commit (maintainer)

1. **Read `## Framework improvements pending`** in `repo-knowledge.md`.
2. **For each portable entry**, determine the improvement type:
   - New bundled agent → MINOR bump
   - New reference file or substantial reference update → MINOR bump
   - Bug fix in an existing skill/agent → PATCH bump
   - Breaking change to the plugin contract (SKILL.md phase API, schema fields) → MAJOR bump
3. **Draft the change** to the plugin repo:
   - New agent → write to `<plugin>/agents/` in generalized form (no repo-specific data)
   - Reference update → edit or create the relevant `<plugin>/skills/smokejumper/references/` file
   - SKILL.md change → edit `<plugin>/skills/smokejumper/SKILL.md`
4. **Bump the SemVer** in `<plugin>/VERSION` (or equivalent manifest):
   - MAJOR.MINOR.PATCH following semantic versioning
   - Pre-1.0: stay on `0.x`; breaking changes bump MINOR, not MAJOR
5. **Update `CHANGELOG.md`** in the plugin repo:
   - Move `## Unreleased` entries into a new version section `## vX.Y.Z — YYYY-MM-DD`
   - Add the new improvement under the correct heading (Added / Changed / Fixed / Removed)
   - Keep format consistent with prior entries (Keep a Changelog standard)
6. **Commit to the plugin repo** with a clear message:
   ```
   chore(release): bump vX.Y.Z — <one-line description of the improvement>
   ```
7. **Clear `## Framework improvements pending`** in `repo-knowledge.md` after the
   successful plugin commit. The next sprint starts with an empty queue.
8. **Emit `plugin_bump_committed` event** to `sprint-log.jsonl`.

### Mode B procedure — prepare an upstream PR (contributor)

Mode B never auto-forks, auto-commits, or auto-opens a PR. A fork creates a public repo
under the user's account and a PR publishes the learning — both are outward-facing acts the
human must trigger. The orchestrator prepares the materials and hands over ready-to-run
commands; the user decides whether to send them.

1. **Generalize AND scrub — mandatory before anything leaves the machine.** The portability
   test already confirmed the insight applies elsewhere; this step confirms the *text* is
   safe to publish. Rewrite the improvement so it carries zero target-repo specifics: no
   repo or product names, file paths, domain/business logic, identifiers, credentials, or
   internal URLs. If a finding can't be expressed generically without leaking, it does not
   graduate — keep it local. When the target repo is private or proprietary, treat this as a
   hard gate.
2. **Prepare the change** in generalized form — the new agent file content, the reference
   edit, or the SKILL.md edit — as a diff or a precisely described patch. Do not apply it to
   any repo you can't push to.
3. **Stage a CHANGELOG entry; do not bump VERSION.** The contribution adds an entry under
   `## Unreleased` describing the learning. The maintainer assigns the version at merge —
   external PRs never bump `VERSION` or `plugin.json`.
4. **Hand the user ready-to-run contribution steps.** Resolve the upstream URL from
   `plugin.json.repository` (never hardcode it). Provide both paths:
   - With the GitHub CLI:
     ```
     gh repo fork <plugin.json.repository> --clone
     # apply the prepared change on a new branch, commit, then:
     gh pr create --title "<learning>" --body "<why it is portable>"
     ```
   - Without `gh`: fork via the repository's web page, push the branch to the fork, and open
     the PR from the GitHub UI.
5. **Record locally regardless.** Keep the improvement in
   `<target>/.smokejumper/repo-knowledge.md` under `## Framework improvements pending` so it
   survives if the user declines, and surface the PR suggestion in the HANDOFF. Contribution
   is encouraged, never forced — a user in a private context may decline, and that is fine.
6. **Emit `plugin_pr_suggested` event** to `sprint-log.jsonl`.

---

## SemVer versioning rules

| Change type | Version component | Example |
|---|---|---|
| Breaking change to SKILL.md phase API, schema fields, or required inputs | MAJOR | `1.0.0 → 2.0.0` |
| New bundled agent, new reference file, new capability | MINOR | `0.3.0 → 0.4.0` |
| Bug fix, clarification, non-breaking reference update | PATCH | `0.3.0 → 0.3.1` |

**Pre-1.0 convention:** While the plugin is pre-1.0, breaking changes bump MINOR (not
MAJOR). The plugin reaches 1.0 when its phase API and schema are considered stable for
external consumers.

**Never skip a version.** If two improvements landed in the same sprint — one PATCH, one
MINOR — bump to the MINOR version. The PATCH is subsumed.

---

## Sprint-log events for this phase

Emit these events to `sprint-log.jsonl` during LESSONS LEARNED:

- `lessons_written` — when `repo-knowledge.md` is updated
- `plugin_bump_queued` — when a portable improvement is identified but not yet committed
  (e.g., if the plugin write-back is deferred to the next sprint)
- `plugin_bump_committed` — when the plugin repo commit succeeds (Mode A)
- `plugin_pr_suggested` — when a generalized improvement is prepared and an upstream PR is
  encouraged because this sprint isn't running in the canonical plugin repo (Mode B)

---

## What LESSONS LEARNED is NOT

- Not a place to restate what was done this sprint (the ledger has that).
- Not optional. Every sprint runs this phase, even a short one. A 10-minute sprint that
  revealed one new trap still appends it to `## Known traps`.
- Not a place to smooth over failures. If a gate failed, if a lane routing decision was
  wrong, if an agent produced low-quality output — record it honestly in
  `## What worked / What to avoid`. The next sprint crew depends on that honesty.
