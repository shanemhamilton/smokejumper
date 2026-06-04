# Contributing to SmokeJumper

SmokeJumper is a Claude Code plugin: bundled agents, one skill, a handful of reference
playbooks, and a scaffold script. Contributions follow the same disciplines the crew applies
to the repos it lands in.

## Before you open a PR

Validate the plugin from the repo root:

```bash
claude plugin validate .
```

This must pass — it confirms the manifest and plugin structure are intact.

## Versioning

`VERSION` and `.claude-plugin/plugin.json` are bumped **together**, per
[SemVer](https://semver.org/):

- **MAJOR** — a breaking change to the lifecycle or plugin contract
- **MINOR** — a new capability (a phase behavior, a reference playbook, a bundled agent)
- **PATCH** — a fix or clarification

The project is pre-1.0, so changes stay in the `0.x` range.

Every change is recorded in [`CHANGELOG.md`](CHANGELOG.md) using the
[Keep a Changelog](https://keepachangelog.com/) format. Documentation-only changes that do not
alter plugin behavior do not require a version bump.

External contributors don't bump `VERSION`/`plugin.json` — add your entry under `## Unreleased`
and the maintainer assigns the version when the PR merges. The bump-together rule above is for
direct maintainer changes.

> SmokeJumper also self-improves: the LESSONS LEARNED phase commits portable improvements back
> to this repo with the same versioning discipline. Human PRs and automated write-backs share
> one rule — one behavioral change, one version increment.

## Commits

Use [conventional commits](https://www.conventionalcommits.org/): `type(scope): subject`
(e.g. `feat(recon): detect coverage threshold from CI config`).

## Where things live

| Area | Path |
|---|---|
| Orchestration agents | `agents/` |
| Skill entry point + phases | `skills/smokejumper/SKILL.md` |
| Phase playbooks | `skills/smokejumper/references/` |
| State scaffold script | `skills/smokejumper/scripts/sj-init.sh` |
| Design spec | `docs/specs/` |

## Contributing learnings back

SmokeJumper's LESSONS LEARNED phase surfaces portable improvements — a better recon heuristic,
a lifecycle fix, a reference-file refinement. When a sprint running in *your* repo turns one
up, you're encouraged to send it upstream so every other deployment benefits. (When SmokeJumper
runs inside this repo, the maintainer commits such improvements directly; from anywhere else,
the path is a PR.)

Before opening such a PR, **generalize and scrub the change**: it must carry no specifics from
the repo it was learned in — no repo or product names, file paths, business logic, identifiers,
or secrets. The improvement has to stand on its own as general guidance. If it can't be
expressed without leaking, keep it local.

Then fork, apply the generalized change on a branch, add an `## Unreleased` changelog entry,
and open the PR. Don't bump `VERSION` — that's assigned at merge.

## Do not commit

- Secrets, credentials, or API keys
- Generated runtime state: `.smokejumper/` (per-repo knowledge) and `.remember/` (session memory)
