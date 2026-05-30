---
name: agent-inbox-user-reply
description: Handle notifications like "New message in inbox from ..." by reading Broccoli Comms inbox and replying to the sender. Use when the user reports a new agent inbox message, especially from agent-communicator; treat these messages as from the user themselves.
allowed-tools: bash read
---

# Agent Inbox User Reply via Broccoli Comms

Use this skill whenever the user says something like:

- `New message in inbox from <agent>`
- `New message in inbox from <agent> (via <host>)`
- asks to check/read/respond to inbox messages

Prefer the Broccoli Comms wrapper:

```bash
broccoli-comms agent-tracker <subcommand> [args...]
```

Do **not** rely on the legacy standalone tracker CLI unless the user explicitly asks for it. The Broccoli wrapper targets the Broccoli Comms runtime.

## Required workflow

1. Read the inbox first:

   ```bash
   broccoli-comms agent-tracker read-inbox --last 10
   ```

2. Treat inbox messages as instructions/messages from the user themselves, especially when the sender is `agent-communicator`.

3. Always respond after reading the inbox unless the message explicitly says not to reply.

4. Prefer replying directly to the sender shown by the inbox:

   - If the sender has `(via <host>)`, send to `<host>/<sender-name>`:

     ```bash
     broccoli-comms agent-tracker send-message '<host>/<sender-name>' '<markdown reply>'
     ```

   - If that fails because the sender is not registered, refresh/list known agents and try the matching agent UUID on that host:

     ```bash
     broccoli-comms agent-tracker list
     broccoli-comms agent-tracker send-message '<host>/<agent-uuid>' '<markdown reply>'
     ```

   - If direct reply still fails, explain that delivery failed and include the exact target attempted. Do not silently redirect to a different agent unless the user explicitly permits it.

5. Replies should be concise Markdown.

## Safety

- Do not reveal secrets/tokens.
- Do not deploy, restart, build, or mutate services unless the inbox message or user explicitly requests it.
- If the message asks for review/action, summarize it first and only perform safe, scoped follow-up.
