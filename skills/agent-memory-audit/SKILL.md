---
name: agent-memory-audit
description: Audit a Broccoli Comms agent's append-only task/event log and approved memory, then propose additions/removals for that agent's facts, habits, skills, episodes, and expertise. Use when asked to review or update an agent's memory from user feedback or event logs.
allowed-tools: bash read
---

# Agent Memory Audit Skill

Use this skill when the user asks to audit, refresh, improve, prune, or update an agent's durable memory based on Broccoli Comms tasks, validation, feedback, or append-only event logs.

The goal is to produce a conservative memory-maintenance report first. Do **not** mutate memory until the user explicitly approves the final report.

## Core principles

- Durable memory is in Broccoli Comms, not cwd files.
- The append-only event log is the evidence source.
- Active memory must remain concise, scoped, and useful at bootstrap.
- Do not store secrets, raw transcripts, full logs, or bulky evidence.
- Explicit user instructions override existing memory/habits/skills.
- Prefer validated-good evidence. Note weaker evidence clearly.
- Before changing memory, show the user exactly what will be added, edit-proposed, directly edited, approved, rejected, revoked, rolled back, or left unchanged.

## Audit workflow

### 1. Identify audit target

Determine:

- `AGENT`: stable agent/profile name to audit.
- Optional `SCOPE`: project/team/global scope.
- Optional time/window: task ids, event limit, or recent validated tasks.

If unclear, ask the user for the target agent and scope.

### 2. Gather current durable state

Use Broccoli Comms CLI:

```bash
broccoli-comms task list --agent AGENT --include-archived --json
broccoli-comms state list --agent AGENT --json
broccoli-comms memory list --agent AGENT --json
broccoli-comms memory budget --agent AGENT --json
```

For each relevant task, read its append-only events:

```bash
broccoli-comms events list --task TASK_ID --limit 200 --json
```

For important existing memories:

```bash
broccoli-comms memory show MEMORY_ID --json
```

### 3. Classify evidence

Review the relevant task chain for memory hints before drafting changes. Look across task descriptions, working-state checkpoints, completion submissions, reviewer decisions, `need_improvements` feedback loops, and user corrections/clarifications. Prefer validated-good evidence; treat reviewer blockers and user corrections as strong signals for reusable habits or pitfall episodes.

Look for:

- **User feedback**: `task_result_marked good|bad|need_improvements`, approval decisions, corrections, explicit preferences.
- **Repeated habits**: practices that were corrected or validated more than once.
- **Skills/playbooks**: repeatable procedures with triggers, steps, checks, and failure modes.
- **Episodes**: compact validated task summaries worth remembering.
- **Expertise**: validated areas of competence for the agent, without scores/ranks.
- **Stale memory**: active memory contradicted by later validation, obsolete tools/paths, duplicate records, or overly broad/unhelpful entries.

### 4. Draft candidate memory changes

Use these memory types:

- `fact`: stable project/user fact.
- `habit`: behavioral preference or recurring operating practice.
- `skill`: reusable procedure/playbook. Include when-to-use, steps, checks, and failure modes.
- `episode`: compact validated task summary.
- `expertise`: evidence-backed competence note for the agent; no numeric score or ranking.

Before proposing a new memory item, compare the candidate against existing active/pending memory. Prefer updating an existing memory when the new evidence refines, narrows, extends, or corrects an existing habit/skill/episode without changing its core meaning. Propose a new memory only when no existing item is a good semantic home, or when combining them would make the memory too broad or confusing.

For each candidate, include:

- action: `propose-edit`, `edit`, `propose`, `approve`, `revoke`, `reject`, `rollback`, or `no-op`
- type
- scope
- subject_agent
- title
- concise body
- evidence task ids / event seqs
- reason
- risk / confidence
- if editing: existing memory_id, current version, and why update is better than adding a new item

### 5. Prepare final report for user approval

Before running any memory mutation command, present a final report like:

```markdown
# Memory audit report for AGENT

## Evidence reviewed
- Tasks: ...
- Events: ...
- Existing active memory: ...

## Proposed edit proposals
1. target memory_id=...
   title: ...
   new body: ...
   evidence: task-..., events ...
   command that will be run: `broccoli-comms memory propose-edit ...`

## Proposed direct edits (trusted context only)
1. memory_id=...
   title: ...
   new body: ...
   evidence: task-..., events ...
   command that will be run: `broccoli-comms memory edit ...`

## Proposed additions
1. type=habit scope=... subject_agent=...
   title: ...
   body: ...
   evidence: task-..., events ...
   command that will be run: `broccoli-comms memory propose ...`

## Proposed revocations / rejections / rollbacks
1. memory_id=...
   reason: ...
   command that will be run: `broccoli-comms memory revoke ...` or `broccoli-comms memory reject ...` or `broccoli-comms memory rollback ...`

## No-op / keep
- ...

Please approve, edit, or reject this memory update plan.
```

Stop here and wait for explicit user approval.

## Applying approved changes

Only after approval, run the approved CLI commands.

### Propose an edit to existing memory when evidence refines it

Use this path for normal agent runtimes. It creates a pending edit proposal and does not require verified actor identity.

```bash
broccoli-comms memory propose-edit MEMORY_ID \
  --body 'UPDATED BODY' \
  --source-task TASK_ID \
  --tag memory-audit \
  --expected-version VERSION \
  --json
```

### Directly edit existing memory (trusted context only)

Use only when the user explicitly asked for direct application and the runtime is trusted/verified. If the current process is an unverified agent but the user explicitly asks to use the local trusted path for testing or applying, run the command with `AGENT_NAME`, `AGENT_ID`, and `AGENT_UUID` unset.

```bash
broccoli-comms memory edit MEMORY_ID \
  --body 'UPDATED BODY' \
  --source-task TASK_ID \
  --tag memory-audit \
  --expected-version VERSION \
  --json

# trusted local path when explicitly authorized:
env -u AGENT_NAME -u AGENT_ID -u AGENT_UUID broccoli-comms memory edit MEMORY_ID \
  --body 'UPDATED BODY' \
  --source-task TASK_ID \
  --tag memory-audit \
  --expected-version VERSION \
  --json
```

### Propose memory from a validated task

```bash
broccoli-comms memory propose \
  --type habit \
  --scope SCOPE \
  --subject-agent AGENT \
  --title 'TITLE' \
  --body 'BODY' \
  --source-task TASK_ID \
  --tag memory-audit \
  --json
```

For skills, use `--type skill` and make the body a compact playbook:

```markdown
When to use: ...
Steps:
1. ...
Validation checks:
- ...
Failure modes:
- ...
```

### Trusted manual path

If the user explicitly approves a memory that has no validated source task, use trusted manual only when your runtime identity is allowed to do so:

```bash
broccoli-comms memory propose \
  --type fact \
  --scope SCOPE \
  --subject-agent AGENT \
  --title 'TITLE' \
  --body 'BODY' \
  --trusted-manual \
  --tag memory-audit \
  --json
```

If the CLI reports `trusted memory actor required`, do not spoof identity. For proposals, leave the pending memory for a trusted approver. For direct actions, either tell the user/coordinator to approve/apply it from a trusted local context, or use `env -u AGENT_NAME -u AGENT_ID -u AGENT_UUID ...` only when the user explicitly authorizes the local trusted path.

### Approve pending proposals

If the user asks you to approve and your runtime is trusted:

```bash
broccoli-comms memory approve MEMORY_ID --expected-version VERSION --json
```

If the user explicitly authorizes using the local trusted path from an agent shell:

```bash
env -u AGENT_NAME -u AGENT_ID -u AGENT_UUID broccoli-comms memory approve MEMORY_ID --expected-version VERSION --json
```

If not trusted or authorized, leave the memory pending and report the approval command for the user/coordinator.

### Revoke stale active memory / reject pending stale proposals

There is no first-class `propose-revoke` or `propose-reject` workflow yet. Present these as direct trusted-context actions in the audit report and wait for approval. If the current agent runtime is untrusted, direct commands will fail with `verified memory actor required` unless the user explicitly authorizes the local trusted path.

```bash
broccoli-comms memory revoke MEMORY_ID \
  --reason 'Concise reason based on later validated evidence' \
  --expected-version VERSION \
  --json

broccoli-comms memory reject MEMORY_ID \
  --reason 'Concise reason' \
  --expected-version VERSION \
  --json

# trusted local path when explicitly authorized:
env -u AGENT_NAME -u AGENT_ID -u AGENT_UUID broccoli-comms memory revoke MEMORY_ID \
  --reason 'Concise reason based on later validated evidence' \
  --expected-version VERSION \
  --json
```

### Roll back active memory

Rollback restores an earlier memory version but creates a new current version. Use it only for explicit rollback requests or when the audit report is approved for rollback.

```bash
broccoli-comms memory rollback MEMORY_ID \
  --to-version PREVIOUS_VERSION \
  --expected-version CURRENT_VERSION \
  --json

# trusted local path when explicitly authorized:
env -u AGENT_NAME -u AGENT_ID -u AGENT_UUID broccoli-comms memory rollback MEMORY_ID \
  --to-version PREVIOUS_VERSION \
  --expected-version CURRENT_VERSION \
  --json
```

## Final response

After applying approved commands, report:

- commands run
- memory ids created/approved/revoked/rejected
- anything left pending for a trusted user/coordinator
- any skipped candidates and why

Keep the final summary concise.
