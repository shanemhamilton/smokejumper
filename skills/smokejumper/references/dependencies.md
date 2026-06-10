# Reference: Dependencies

SmokeJumper is a thin orchestration layer — it composes a handful of other projects rather
than reimplementing them. This file (and the machine-readable `dependencies.json` beside it)
is the single source of truth for **what SmokeJumper stands on**, so the set is explicit,
trackable, and easy to extend.

`dependencies.json` is the data; this file explains the policy. The sprint-start check
`scripts/sj-deps-check.sh` reads the JSON; the adapter (`adapter.md` / `sj scan`)
reads the same `detect` rules to resolve capabilities. Add a dependency in one place (the
JSON) and every consumer picks it up.

---

## The dependency set

| id | kind | required | what it gives SmokeJumper |
|---|---|---|---|
| `choo-choo-ralph` | backend | no | Lane A async "big pour" engine |
| `metaswarm` | backend | no | optional cross-model adversarial gate + PR shepherd |
| `bugsweep` | backend | no | optional deep bug-hunt (Hunter→Skeptic→Referee) in REVIEW |
| `anthropic-skills:handoff-prompt` | skill | no | Phase 8 handoff (has built-in fallback) |
| `product-pilot` | vendored | no | product-context layer (embedded, re-synced from upstream) |
| `beads` (`bd`) | tracker | no | git-native issue tracker + choo-choo's store |
| `codex` | backend | no | cross-model execution + review |
| `gh` | tracker | no | GitHub issue-tracker fallback |

**Hard requirements** (not in the manifest because they are the substrate, not optional
dependencies): a **git** repo, and **one of** the Claude Code or Codex runtimes.

`metaswarm` and `product-pilot` are both authored elsewhere and are intentionally **optional**
— SmokeJumper has a built-in fallback for each, so it never hard-fails when they are absent.

---

## Update policy: pin → notify → opt-in (never silent auto-pull)

This matches the project's dependency rules (pin exact versions, test before updating, never
upgrade without review) and the existing notify-only version check.

- **Pin.** Each dependency carries a `pin` (the version SmokeJumper was last tested against)
  and `tested` (the version a maintainer confirmed works). A null pin means "not yet pinned"
  — the first `--update` records it.
- **Notify.** At sprint start, `sj deps` compares each pin against the latest
  upstream and prints a one-line notice when an upstream has moved ahead. It is **fail-silent
  and time-boxed** — no network, a slow API, or an unknown source produces no output and
  never stalls a sprint.
- **Opt-in upgrade.** `sj deps --update` bumps the pins to the detected latest and
  prints the per-runtime upgrade commands. It does **not** run plugin upgrades for you and
  does **not** overwrite the vendored `product-pilot` copy — those are deliberate, reviewed
  steps.

A **periodic upstream scan** (`.github/workflows/dependency-scan.yml`) runs the same check in
the plugin repo on a schedule and opens an issue when an upstream moves — so the maintainer
stays current without touching anyone's sprint. That is the "scan for stability" lane;
sprint-time stays pinned.

---

## Source types

`source.type` tells the check how to find "latest":

| type | how "latest" is resolved | when to use |
|---|---|---|
| `github-release` | latest release/tag via the GitHub API for `source.repo` | the dep has a GitHub repo with releases or tags |
| `manual` | not auto-checked; the check just notes it is manually tracked | repo unknown/unconfirmed — fill `source.repo` later to upgrade it to `github-release` |

Two entries are `manual` today on purpose, to avoid guessing a repo: `beads` and
`anthropic-skills:handoff-prompt`. Record their `source.repo` when confirmed and they become
auto-checked with no other change.

---

## Adding a new dependency (the extension point)

To make SmokeJumper depend on (or optionally use) something new, add ONE object to
`dependencies.json`:

```json
{
  "id": "your-tool",
  "kind": "backend | tracker | skill | vendored",
  "required": false,
  "purpose": "one line: what it gives SmokeJumper",
  "source": { "type": "github-release", "repo": "owner/repo" },
  "detect": { "skillDir": "your-tool", "bin": "your-tool", "skillPrefix": "your-tool:" },
  "pin": null,
  "tested": null,
  "absentBehavior": "what SmokeJumper does when it is missing (must degrade, never hard-fail)"
}
```

- `detect` keys are all optional; provide whichever apply (`bin` = a CLI on `PATH`,
  `skillDir` = a directory under `~/.claude/skills/`, `skillPrefix` = an installed skill
  namespace). The adapter uses these to set `adapter.capabilities.<id>`.
- If the new dependency replaces a phase's behavior (like metaswarm routes the gate), wire
  the routing in `SKILL.md` behind an "if detected" check, with the bundled flow as the
  fallback — consistent with the runtime model in `references/runtime.md`.
- Every optional dependency MUST define `absentBehavior`. SmokeJumper's contract is that a
  missing dependency degrades quality or routing, never blocks the sprint.
