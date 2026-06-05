# Reference: Runtime & Roles — adopt vs. dispatch

Loaded first in RECON (Phase 1), before any other work. This file resolves a single
ambiguity that otherwise silently breaks SmokeJumper outside a Claude Code session: **what
does it mean to "establish" or "run" a lead?**

SmokeJumper hard-requires only a git repo and the bundled agents + skill + scripts. It does
**not** require a specific agent runtime. It runs under:

- **Claude Code** (the reference runtime) — can dispatch subagents and invoke skills.
- **A Codex agent as the top-level orchestrator** — reads `SKILL.md` and drives the sprint
  itself; **cannot** invoke the Claude Code Skill tool and **cannot** dispatch
  `.claude/agents/*.md` personas as subagents.
- **Any other agent or plain automation** that can read files and run shell commands.

---

## The role model: leads are personas, not mandatory subagents

A "lead" (product / engineering / design) is a **persona defined by a markdown file** in the
plugin's `agents/` directory (or a project-specific override resolved by the adapter). The
persona is a set of operating instructions for one phase — it is not, in itself, a process
that must be spawned.

**To establish a lead, the orchestrator READS the resolved lead's definition file and adopts
it as its operating instructions for that phase.** Concretely:

| Your runtime | How to run a lead |
|---|---|
| Supports subagent dispatch (Claude Code Task tool) | You MAY dispatch the resolved agent as a subagent, OR adopt it inline. Both are valid. |
| No subagent dispatch (Codex orchestrator, plain automation) | **Adopt inline:** read the resolved lead's definition file and act as that role for the phase. When adopted inline, the orchestrator IS that lead for the phase. |

**A lead is not "established" until its definition file has been read and its resolved name
recorded + announced.** Dispatching a subagent is an optimization, not a requirement. Never
block the sprint waiting for a dispatch mechanism your runtime does not have — adopt inline
instead.

This is why lead establishment must be *visible*: `scripts/sj-adapter-scan.sh` resolves the
names and prints the banner, and the orchestrator then reads the resolved definition files.
"I resolved BUNDLED leads but never read their definitions" is **not** established.

---

## Orchestrator preflight (run once, at the top of RECON)

Before Phase 1 work, self-identify the runtime and pick the execution mode:

1. **Can you dispatch subagents?** (Claude Code Task tool, or equivalent.)
   - Yes → dispatch-or-adopt, your choice per phase.
   - No → **inline-adoption mode** for all leads and reviewers.
2. **Can you invoke the Skill tool** (e.g. `anthropic-skills:handoff-prompt`, `choo-choo-ralph:*`)?
   - Yes → skill invocations in `SKILL.md` resolve normally.
   - No → use the **embedded reference files directly**. Every skill the lifecycle names has
     a file-based fallback:
     | Named skill | File-based fallback |
     |---|---|
     | (lead/gate dispatch) | Adopt `agents/*.md` inline |
     | `metaswarm:*` gate routing | Use the bundled adversarial review flow (metaswarm needs the Skill tool) |
     | product context bootstrap | `references/product-context.md` + `templates/product-context.md` (already file-based — no skill needed) |
     | `choo-choo-ralph:*` (Lane A) | If the `ralph`/`bd` CLIs are absent, Lane A is unavailable → route all work to Lane B (`references/gated-pour.md` degradation) |
     | `anthropic-skills:handoff-prompt` (Phase 8) | Write `<target>/.smokejumper/HANDOFF.md` directly (already specified in `SKILL.md` Phase 8) |
3. **Record the runtime** in the RECON summary and emit it to `sprint-log.jsonl` so the
   handoff and any resuming session know which mode was used.

The rule of thumb: **never wait on a Skill-tool call or a subagent dispatch that will not
resolve in your runtime.** Read the file, do the work inline, keep moving.

---

## What does NOT change across runtimes

The runtime affects *how* a role is run, never *whether* a gate or safety rule applies:

- The adversarial review gate is still mandatory; inline-adoption does not waive it. A single
  orchestrator adopting both the creator persona and the reviewer persona must run them as
  **separate, adversarial passes** — never self-certify in one breath.
- Safety-critical work still routes to a guardian. If no guardian agent is resolved, it still
  goes to the human + a logged gap — inline adoption does not authorize an orchestrator to
  edit safety-critical logic itself.
- `.adversarial-review-passed` is still created only after the gate passes, by the engineering
  lead / orchestrator — never by a creator persona for its own output.
