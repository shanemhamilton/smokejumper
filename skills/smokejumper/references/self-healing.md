# Reference: Self-Healing — Authoring a Missing Agent

When the adapter (RECON phase) scans the target repo and finds that a needed specialist
agent is absent, SmokeJumper authors one on the fly rather than failing or falling silent.
This is "self-healing": the framework fills the capability gap within this sprint.

Self-healed agents land in the target repo, never auto-graduate into the plugin.
Promotion to the plugin requires a deliberate decision in the LESSONS LEARNED phase, a
portable applicability check, and a versioned SemVer bump.

---

## When to self-heal vs fall back to bundled generic

| Gap type | Action |
|---|---|
| Needed **lead** agent is absent | Always use bundled generic (self-heal optional if domain is clear) |
| Needed **gate/review role** is absent | Skip the gate (adapter-conditional); do NOT self-heal a gate |
| Needed **domain specialist** is absent and the sprint depends on it | Self-heal if domain is well-understood and scoped |
| Needed **tool wrapper agent** is absent (e.g. a specific deploy wrapper) | Self-heal — these are mechanical and low-risk |

**Gate roles are never self-healed.** A fabricated challenger is weaker than no challenge
at all — it creates false confidence. If a gate role is absent, skip that gate and note
the gap. The sprint proceeds without it.

Lead roles are always filled — either by a bundled generic or a self-healed specialist.
A sprint never starts without an engineering lead.

---

## How to author a missing agent

### 1. Assess necessity

Before authoring, confirm:
- The adapter scan confirmed the agent is absent (not just in an unexpected path).
- The sprint genuinely requires this specialization — not just "nice to have."
- The domain is well-understood enough to write an accurate, non-fabricated agent.
- It is not a gate/review role (those are never self-healed).

If any condition fails, fall back to the closest bundled generic and note the limitation
in the sprint summary.

### 2. Draft the agent

Write the agent in the Claude Code agent format:

```markdown
---
name: <project-prefix>-<role>
description: <one sentence: what it is and when to use it>
model: sonnet          # or opus for accuracy-critical roles
---

# Role statement
[What this agent does and what it is responsible for]

# Operating constraints
[What it owns, what it defers, when to escalate]

# Domain context
[Repo-specific context loaded from CLAUDE.md / repo-knowledge.md]
```

Agent authoring rules:
- Scope tightly — one responsibility, one domain. Broad agents degrade into generic.
- Pull domain context from `CLAUDE.md` / `repo-knowledge.md` — do not invent facts about
  the target repo.
- Use the same model tier as the equivalent bundled SmokeJumper agent unless there is a
  specific reason for a different tier.
- Write only what you can verify from the target repo's actual conventions and context.
- The agent must declare any safety-critical escalation paths explicitly (e.g., "if this
  touches payments, stop and escalate to the guardian").

### 3. Write to the target repo

Place the authored agent at `<target>/.claude/agents/<name>.md`.

Verify it is in the target repo's `.claude/agents/`, not the plugin's.

### 4. Use it in this sprint

Invoke the authored agent as you would any other detected agent. It is now available for
this sprint and all future sprints that run against this repo.

### 5. Log the gap

Append an entry to `<target>/.smokejumper/gaps.jsonl`:

```json
{
  "ts": "<ISO-8601>",
  "sprint": "<sprint-id>",
  "gap_type": "missing_agent",
  "description": "<what was absent and why it was needed>",
  "resolution": "self_healed",
  "authored_path": "<target>/.claude/agents/<name>.md",
  "portable": <true|false>,
  "notes": "<why portable true/false; if true, describe the improvement>"
}
```

Set `portable: true` if the authored agent captures a capability that would be useful in
other repos of the same type (e.g., a generic "localization reviewer" agent). Set
`portable: false` if the agent is tightly coupled to this specific repo's domain.

Also emit a `self_heal_authored` event to `sprint-log.jsonl`.

---

## Graduation to the plugin — the deliberate step

Self-healed agents are per-repo assets. Promotion to the plugin is a LESSONS LEARNED
decision, not automatic.

**Never auto-graduate.** The criteria for graduation:

1. **Portable:** The agent's logic applies to a range of repos (not just this project's
   specific domain data or toolchain).
2. **Verified:** The agent performed successfully in at least one sprint — confirmed in
   the sprint summary, not inferred.
3. **Non-redundant:** It fills a gap not already covered by the bundled generics.
4. **SemVer bump required:** Adding a new bundled agent is a MINOR version bump to the
   plugin. The LESSONS LEARNED phase handles the commit and CHANGELOG entry.

To graduate: in LESSONS LEARNED, copy the agent to `<plugin>/agents/`, generalize any
repo-specific context, bump the plugin's SemVer (MINOR), update `CHANGELOG.md`, and
commit to the plugin repo. The per-repo copy in `<target>/.claude/agents/` can remain
(it is not deleted — deletion could break running sprints on that repo).

---

## Self-healing checklist

- [ ] Adapter confirmed the agent is absent (not just misplaced)
- [ ] Sprint requires this specialization
- [ ] Not a gate/review role (those are skipped, not self-healed)
- [ ] Domain is well-understood; no facts will be invented
- [ ] Agent drafted per format above
- [ ] Written to `<target>/.claude/agents/<name>.md`
- [ ] Used in this sprint
- [ ] Gap logged to `gaps.jsonl` with `resolution: "self_healed"`
- [ ] `self_heal_authored` event emitted to `sprint-log.jsonl`
- [ ] `portable` field set correctly (honest assessment)
