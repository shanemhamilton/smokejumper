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

## Do not commit

- Secrets, credentials, or API keys
- Generated runtime state: `.smokejumper/` (per-repo knowledge) and `.remember/` (session memory)
