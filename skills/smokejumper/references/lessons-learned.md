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

### Plugin write-back procedure

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
- `plugin_bump_committed` — when the plugin repo commit succeeds

---

## What LESSONS LEARNED is NOT

- Not a place to restate what was done this sprint (the ledger has that).
- Not optional. Every sprint runs this phase, even a short one. A 10-minute sprint that
  revealed one new trap still appends it to `## Known traps`.
- Not a place to smooth over failures. If a gate failed, if a lane routing decision was
  wrong, if an agent produced low-quality output — record it honestly in
  `## What worked / What to avoid`. The next sprint crew depends on that honesty.
