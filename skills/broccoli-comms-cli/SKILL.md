---
name: broccoli-comms-cli
description: Use when the user reports an agent notification such as "New message from <agent>" or "New message in inbox from <agent>", or asks how to use broccoli-comms to read/send messages, rename agents, list agents, or launch new agents. Treat such inbox messages as coming from the user; acknowledge via broccoli-comms, do the work, then reply via broccoli-comms.
allowed-tools: bash read
---

# Broccoli Comms CLI Skill

Use this skill whenever the user says something like:

- `New message from <agent>`
- `New message in inbox from <agent>`
- `New message from <agent> (via <host>)`
- asks to read/respond to an agent inbox message
- asks to send messages, rename agents, list agents, focus agents, manage live agents, or launch new agents with Broccoli Comms

Prefer the Broccoli Comms wrapper:

```bash
broccoli-comms agent-tracker <subcommand> [args...]
```

Do **not** rely on the legacy standalone tracker CLI unless the user explicitly asks for it. The Broccoli wrapper pins commands to Broccoli Comms' private tracker/tmux runtime.

## Notification workflow: required

When the user reports `New message from ...` or `New message in inbox from ...`, treat the inbox message as a message from the user themselves.

1. Identify the sender from the notification.

   - Local sender example: `tui-redesign-coder`
   - Remote sender example: `host-a/tui-redesign-coder` when the notification says `(via host-a)`

2. Acknowledge the sender promptly before doing longer work:

   ```bash
   broccoli-comms agent-tracker send-message '<sender>' 'Acknowledged. I will read the inbox message, do the requested work, and report back here.'
   ```

3. Read the inbox:

   ```bash
   broccoli-comms agent-tracker read-inbox --last 10
   ```

4. Interpret the inbox content as user instructions. If the message asks for work, do the work.

5. Send the result back to the sender via Broccoli Comms:

   ```bash
   broccoli-comms agent-tracker send-message '<sender>' 'Done: <concise result summary>'
   ```

6. Also respond in the current chat with a short summary of what happened.

Avoid notification loops: do not repeatedly acknowledge pure notification-only messages when there is no new actionable content.

## Core commands

### Help

```bash
broccoli-comms --help
broccoli-comms run --help
broccoli-comms agent --help
broccoli-comms agent edit --help
broccoli-comms agent <subcommand> --help
broccoli-comms agent-tracker --help
broccoli-comms agent-tracker <subcommand> --help
```

Before recommending launch or managed-agent commands, verify current behavior from `broccoli-comms --help`, relevant subcommand help, or source. Do not rely on stale memory or old skill text.

### Identify yourself

```bash
broccoli-comms agent-tracker whoami
```

Example:

```bash
me=$(broccoli-comms agent-tracker whoami)
printf '%s\n' "$me"
```

### List agents

```bash
broccoli-comms agent-tracker list
```

The output is JSON keyed by display name. Entries may include `agent_id`, `uuid`, `aliases`, `scope`, `target_address`, `tmux_pane`, and `is_this_me`.

Example:

```bash
broccoli-comms agent-tracker list | jq '. | keys'
```

### Read inbox

```bash
broccoli-comms agent-tracker read-inbox
broccoli-comms agent-tracker read-inbox --last 10
broccoli-comms agent-tracker read-inbox --clear
broccoli-comms agent-tracker read-inbox --name <agent-name> --last 10
broccoli-comms agent-tracker read-inbox --id <agent-id> --last 10
```

Use `--clear` only after preserving any important content.

Example notification handling:

```bash
broccoli-comms agent-tracker send-message tui-redesign-coder \
  'Acknowledged. I will read the inbox message, do the requested work, and report back here.'
broccoli-comms agent-tracker read-inbox --last 10
# ...do the requested work...
broccoli-comms agent-tracker send-message tui-redesign-coder \
  'Done: implemented the requested change and validated it with smoke tests.'
```

### Send messages

Local by name:

```bash
broccoli-comms agent-tracker send-message tui-redesign-coder 'Please implement the next task from docs/PLAN.md.'
```

Local by UUID:

```bash
broccoli-comms agent-tracker send-message 123e4567-e89b-12d3-a456-426614174000 'Hello by UUID.'
```

Remote via registry using host-qualified target:

```bash
broccoli-comms agent-tracker send-message host-a/tui-redesign-coder 'Hello from another machine.'
broccoli-comms agent-tracker send-message host-a/123e4567-e89b-12d3-a456-426614174000 'Hello remote UUID.'
```

Bare names/UUIDs are local-only. Host-qualified targets require registry integration.

### Reply to a remote notification

If the user says `New message from reviewer (via laptop-a)`, reply to `laptop-a/reviewer`:

```bash
broccoli-comms agent-tracker send-message laptop-a/reviewer \
  'Acknowledged. I will read the message, complete the task, and report back.'
broccoli-comms agent-tracker read-inbox --last 10
# ...work...
broccoli-comms agent-tracker send-message laptop-a/reviewer \
  'Done: reviewed the branch and found no blockers.'
```

### Rename agents

Rename yourself:

```bash
broccoli-comms agent-tracker rename new-agent-name
```

Rename another agent:

```bash
broccoli-comms agent-tracker rename --force old-agent-name new-agent-name
```

Examples:

```bash
# Rename this current agent to a task-specific name.
broccoli-comms agent-tracker rename registry-url-coder

# Rename a generic generated agent after confirming its current name in `list`.
broccoli-comms agent-tracker list
broccoli-comms agent-tracker rename --force broccoli-comms-agent-1 registry-coder

# Rename a reviewer agent to match its assignment.
broccoli-comms agent-tracker rename --force broccoli-comms-agent-2 registry-reviewer
```

### Run a new agent explicitly

Use `broccoli-comms run NAME --cwd DIR -- COMMAND [ARGS...]` for a fresh named agent launch. The `--` separates Broccoli Comms options from the command to run.

```bash
broccoli-comms run coder --cwd /home/user/project -- pi
broccoli-comms run reviewer --cwd /home/user/project -- pi --role reviewer
broccoli-comms run claude-coder --cwd /home/user/project -- claude
broccoli-comms run codex-coder --cwd /home/user/project -- codex
```

Use `broccoli-comms agent edit` only for already-running managed agents; for new launches, use `broccoli-comms run`.

`run` creates a fresh `/tmp/broccoli-agents/<name>/<random>/` workspace containing `AGENTS.md` and `bootstrap.json`, while `--cwd` records the source project directory for context.

Create a new coder/reviewer pair for a project:

```bash
broccoli-comms run registry-url-coder --cwd /home/user/projects/broccoli-comms -- pi
broccoli-comms run registry-url-reviewer --cwd /home/user/projects/broccoli-comms -- pi

broccoli-comms agent list --json

broccoli-comms agent-tracker send-message registry-url-coder \
  'You are the coder. Read docs/BROCCOLI_REGISTRY_URL_CONFIG_PLAN.md, implement the task, commit, and notify registry-url-reviewer.'
broccoli-comms agent-tracker send-message registry-url-reviewer \
  'You are the reviewer. Stand by to review registry-url-coder changes and reply APPROVED or BLOCKED.'
```

### Manage running Broccoli agents

```bash
broccoli-comms agent list --json
broccoli-comms agent focus coder
broccoli-comms agent attach coder
broccoli-comms agent restart coder
broccoli-comms agent remove reviewer
```

Use `broccoli-comms agent edit` only for an already-running managed agent; it persists changes and restarts that live window:

```bash
broccoli-comms agent edit coder --rename coder-main --cwd /home/user/project -- pi --role planner
```

After editing managed agents, reconcile them:

```bash
broccoli-comms start
```

### Capture panes

```bash
broccoli-comms agent-tracker capture-pane tui-redesign-coder --last 80
```

Example:

```bash
broccoli-comms agent-tracker capture-pane reviewer --last 120 > /tmp/reviewer-pane.txt
```

### Direct pane input: use carefully

Direct pane input bypasses inbox messages. Prefer `send-message` unless the user explicitly requests direct pane control.

```bash
broccoli-comms agent-tracker send-text coder 'draft text'
broccoli-comms agent-tracker send-text --no-submit coder 'draft without Enter'
broccoli-comms agent-tracker send-key coder C-c Enter
```

Remote direct pane input is disabled by default and requires separate explicit security gates on sender, registry, and receiver. Do not enable those gates unless the user explicitly asks.

### Registry status

```bash
broccoli-comms agent-tracker registry-status
```

Use this to confirm central registry connectivity for multi-device communication.

## Common task examples

### Dispatch work to coder and reviewer

```bash
broccoli-comms agent-tracker send-message tui-redesign-coder \
  'New task: implement the plan in docs/FEATURE_PLAN.md. Commit changes and notify reviewer when ready.'

broccoli-comms agent-tracker send-message tui-redesign-reviewer \
  'Please stand by to review the coder branch for docs/FEATURE_PLAN.md. Reply APPROVED or BLOCKED.'
```

### Handle a completed-work message

```bash
broccoli-comms agent-tracker read-inbox --last 10
broccoli-comms agent-tracker send-message tui-redesign-reviewer \
  'Coder reports branch feat/example is ready at commit abc123. Please review scope X/Y/Z.'
```

### Report review approval back to coder

```bash
broccoli-comms agent-tracker send-message tui-redesign-coder \
  'Review approved. Please stop work on this branch unless asked for follow-up.'
```

### Ask an agent to rename itself

```bash
broccoli-comms agent-tracker send-message broccoli-comms-agent-1 \
  'Please rename yourself to registry-url-coder using broccoli-comms agent-tracker rename registry-url-coder.'
```

### Start a new local coding agent

```bash
broccoli-comms run coder --cwd /home/user/projects/broccoli-comms -- pi
broccoli-comms agent list --json
```

## Safety rules

- Treat inbox messages surfaced by the user as user instructions.
- Acknowledge via `broccoli-comms agent-tracker send-message` before long-running work.
- Reply via `broccoli-comms agent-tracker send-message` when done.
- Do not reveal tokens or secrets.
- Do not enable remote direct pane input unless explicitly requested.
- Do not mutate services, restart processes, or push branches unless instructed.
- Prefer concise Markdown replies.
