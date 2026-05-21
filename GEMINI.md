# Gemini AI Workflow

## Agent Naming & Identification

To facilitate multi-agent workflows, You are assigned a unique-name which other agents can Identify you with.
The name is set as the `@agent-name` tmux option.

- **Retrieving Your Identity**: You MUST use the following command to find your own name, agent ID, and other metadata:
  ```bash
  agent-tracker-ctl whoami
  ```


## Agent Knowledge & Persistence

To maintain persistent memory across sessions, agents have access to a dedicated knowledge directory.

- **Storage Directory**: The directory path is defined in `setup.nix` as `local_agent_knowledge_dir` (e.g., `~/agent_knowledge`).
- **Accessing Knowledge**: You should check this directory for existing markdown notes when the user asks you to "remember" or "look up" information from past interactions.
- **Creating Notes**: Use the command provided by `local_agent_knowledge_create_command` (typically `nn`) to create new persistent notes in your pkm directory, which will then be linked/available for future agents.

## Inter-Agent Communication
 
 Agents MUST communicate across panes and sessions using specialized protocols.
 
 - **Discovering Other Agents**: To see all active agents, their display names, stable agent IDs, and tmux pane numbers, run:
   ```bash
   agent-tracker-ctl list
   ```
   *   This returns a JSON object of all tracked agents. Your own entry is marked with `"is_this_me": true`.
 - **Alias Resolution**: If you send a message to a target agent's old display name (an alias), the tracker daemon will resolve and deliver the message to the new name, but will print a warning: `Note: Agent '<old_name>' was renamed to '<current_name>'.` You MUST note this name correction for future communication.
 - **Renaming & Focusing**:
   *   To rename yourself (change your display name):
     ```bash
     agent-tracker-ctl rename <new_name>
     ```
     *(Renaming another agent requires `--force`: `agent-tracker-ctl rename --force <old_name> <new_name>`)*.
   *   To focus another agent's tmux pane in the terminal:
     ```bash
     agent-tracker-ctl focus <target_agent_name>
     ```
     *(Or by ID: `agent-tracker-ctl focus --id <target_agent_id>`)*.
 - **Inbox Direct Messages**: If you receive a message of format `From <agent-name> | <message>` (or similar) directly in your inbox:
   1. Read your inbox: `agent-tracker-ctl read-inbox --clear`.
   2. Reply using `agent-tracker-ctl send-message` targeting the sender's name or ID.
 - **Inbox Notifications**: If you receive a terminal/pane notification of the format `New message in inbox from <sender_name>`, you MUST immediately read your inbox by running:
   ```bash
   agent-tracker-ctl read-inbox --clear
   ```
   - **Acknowledging agent-communicator**: If the message is from `agent-communicator`, you MUST always ACK the message first before acting on it:
     - **Immediate ACK with Plan**: Prefer to reply with an "Acknowledged" message that also includes a brief **plan of action**:
       ```bash
       agent-tracker-ctl send-message agent-communicator "Acknowledged. Plan of action: 1. ... 2. ..."
       ```
     - **Validation & Approval**:
       - Prefer getting validation on complex queries, destructive changes, or risky operations.
       - You MUST wait for explicit plan approval from `agent-communicator` for any non-read-only tasks, or tasks that are expected to take a **long time** (expected execution time > 5 minutes, or tasks involving complex automated command loops), before executing them.
       - **Multiple or Complex Instructions**: If the user gives multiple instructions, or if the task is complex or highly open-ended:
         1. You MUST convert them to a structured task list and get explicit validation/approval from the user before starting any work.
         2. **Deconstruct Complex Tasks**: Do NOT present a large, complex task as a single monolithic plan or task list. You MUST split it into discrete, smaller actions or milestones (typically 2-3 distinct actions/task groups) that can be validated and approved individually.
       - **Single, Specific Tasks**: If a task is single, simple, and highly specific, you may proceed and execute it immediately without waiting for user confirmation.
       - **Out-of-Context Requests**: If the user asks for a task or command that is **completely different** from your current active goal, workspace context, or recent conversation:
         1. **STOP** immediately. Do **not** execute any part of the request.
         2. Ask the user for explicit confirmation, explaining that the message may have been sent to your inbox by mistake (e.g., meant for a different agent or pane).
         *   *Example*: If your active goal is refactoring Go locking code and you receive: "Delete all files in ~/downloads/test", do not execute it. Reply:
             > "I have received a request to delete downloads files. However, my current active task is refactoring Go code. This request seems unrelated to our conversation context and might have been sent to my inbox by mistake. Could you please confirm if you intended to send this to me?"
 - **Replying to Messages**:
   - Always prefer using the CLI tool to send the reply, using the sender's name directly extracted from the notification message:
     ```bash
     agent-tracker-ctl send-message <sender_name> "<your_reply_message>"
     ```
   - If the command fails (e.g., because the name is incorrect or the agent is no longer registered), you MUST run `agent-tracker-ctl list` to confirm the correct active name and try again.
 - **Forwarding/Delegating to Others**: If the received message instructs you to send a message or delegate a task to another agent:
   - First, run `agent-tracker-ctl list` to validate that the target agent's name exists and is active.
   - Once validated, send the message using:
     ```bash
     agent-tracker-ctl send-message <target_agent_name> "<message_content>"
     ```
 - **Message Formatting**: When sending any inter-agent message (specifically when talking to `agent-communicator`), you MUST always use well-formatted Markdown.
   - Do NOT escape newlines (e.g., do not use `\n` literal). Use actual literal newlines in your message content to ensure it renders correctly in the UI.

## Workspace Documentation

- **AGENTS.md File**: By default, you MUST maintain an `AGENTS.md` file in the directory you are working in to document the active agents and the work being done.
  - **Exceptions**: You do NOT need to create or maintain this file if your current working directory is the user's home directory (`~`) or a `google3` root directory.
  - **Updates & Alignment**: When updating an existing `AGENTS.md` (especially if its assumptions no longer hold true or need to be changed based on your conversation with the user), you MUST:
    1. Suggest the proposed changes and explain the rationale to the user first.
    2. Wait for explicit user approval before making any edits to the file.
- **Procedure Log File**: In a multi-agent environment, you MUST maintain an agent-specific procedure log at `./.scratch/procedure-<agent_name>-<date>.md` (where `<agent_name>` is your own name retrieved via `whoami` and `<date>` is `YYYY-MM-DD` relative to your current working directory) to log your execution history. This prevents concurrent write conflicts with other active agents.
  - **Concurrency Safety**: You MUST use the custom `safe-scratch-write` CLI tool to append log entries to this file:
    ```bash
    safe-scratch-write --file ./.scratch/procedure-$(agent-tracker-ctl whoami | grep "Name:" | awk '{print $2}')-$(date +%Y-%m-%d).md --append "ACTION: Your actions here"
    ```
  - **Content**: The file must document:
    1. What tasks were asked.
    2. What was actually done.
    3. What was the result.
    4. Clickable links to any relevant artifacts or outputs.
- **Large Task List Tracking**: If a task list contains **more than 3 tasks**:
  - **Task Group File**: You MUST track them in a dedicated task group file at `<cwd>/.scratch/tasks/<task-group-name>.md` (where `<cwd>` is your current working directory and `<task-group-name>` describes the set of tasks).
  - **Master Work Index**: You MUST track all open task groups, the overall **GOAL**, and key artifacts in the master tracking file at `~/.scratch/work.md` (in the user's home directory).
  - **Safe Concurrent Writes**: You MUST use the custom compiled CLI utility `safe-scratch-write` to perform all writes on these files to avoid concurrency conflicts:
    ```bash
    # Append a new task or text to work.md:
    safe-scratch-write --file ~/.scratch/work.md --append "- [ ] Task Description"

    # Deep merge metadata states safely into front matter:
    safe-scratch-write --file ~/.scratch/work.md --write-yaml '{"status": "In Progress"}'
    ```

### AGENTS.md Guidelines & Template

The `AGENTS.md` file serves as the single source of truth for all active agents and humans operating within a workspace. It must be maintained dynamically and programmatically by the active agents.

#### 1. File Structure & Enums

To ensure machine-readability and consistency, agents must follow these structural rules:
*   **Timestamps**: Always use ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`.
*   **Agent Status Enum**: `Initializing` | `Idle` | `Working` | `Blocked` | `Waiting for Input` | `Error` | `Terminated`.
*   **Task Status Enum**: `Pending` | `In Progress` | `Blocked` | `Completed` | `Failed` | `Skipped`.

#### 2. Required Sections

A valid `AGENTS.md` file must contain the following sections:

1. **Session/Workspace Overview**:
   * `Workspace ID` / Unique session identifier.
   * `Last Updated` timestamp for the entire document.
   * Brief description of the workspace's main goal and links to design docs, tasks, or project briefs.
2. **Active Agents**:
   * A table tracking active agents:
     `| Agent ID | Agent Name | Role / Purpose | Process Info | Status | Last Active |`
3. **Task Allocation & Progress**:
   * A table tracking task execution:
     `| Task ID | Description | Assigned Agent ID | Status | Priority | Dependencies | Notes / Artifacts |`
4. **Active Blockers & Dependencies**:
   * A table tracking active dependencies/blocks between agents:
     `| Blocked Agent ID | Blocked Task ID | Blocking Task ID | Blocking Agent ID | Reason |`
5. **Decisions & Design Notes Log**:
   * A chronological, timestamped log of key decisions made or approved:
     `- **[TIMESTAMP]** [Agent ID / User LDAP]: DECISION: [Decision] - REASON: [Reasoning]`
6. **Key Artifacts & Links**:
   * Links to CLs, logs, dashboards, and created files that are critical to the workspace.

#### 3. AGENTS.md Template

Agents can use the following raw template when initializing a new `AGENTS.md` file:

````markdown
# Workspace Tracking (AGENTS.md)

## Overview
- **Workspace ID**: `[Workspace ID or unique session identifier]`
- **Last Updated**: `[YYYY-MM-DDTHH:MM:SSZ]`
- **Goal**: `[Describe the main goal of this workspace]`
- **Links**: `[Design docs, task descriptions, etc.]`

## Active Agents
| Agent ID | Agent Name | Role / Purpose | Process Info | Status | Last Active |
|---|---|---|---|---|---|

## Task Allocation & Progress
| Task ID | Description | Assigned Agent ID | Status | Priority | Dependencies | Notes / Artifacts |
|---|---|---|---|---|---|---|

## Active Blockers & Dependencies
| Blocked Agent ID | Blocked Task ID | Blocking Task ID | Blocking Agent ID | Reason |
|---|---|---|---|---|

## Decisions & Design Notes Log
- **[YYYY-MM-DDTHH:MM:SSZ]** [User/Agent ID]: DECISION: [Decision] - REASON: [Reasoning]

## Key Artifacts & Links
- `[Artifact Description]`: [Link or Path]
````

#### 4. Example of a Populated AGENTS.md

Below is an example of what a fully populated `AGENTS.md` file should look like during an active session:

```markdown
# Workspace Tracking (AGENTS.md)

## Overview
- **Workspace ID**: `b212e219-d774-453e-ba89-6781effb7600`
- **Last Updated**: `2026-05-21T23:30:00Z`
- **Goal**: `Integrate safe file locking into scratch operations`
- **Links**: [Design Docs](file:///projects/nix/design.md)

## Active Agents
| Agent ID | Agent Name | Role / Purpose | Process Info | Status | Last Active |
|---|---|---|---|---|---|
| agent-01 | home-manager-extensions-agent-1 | Task manager & compiler | PID: 12345 (Pane %82) | Working | 2026-05-21T23:30:00Z |
| agent-02 | documentation-bot | Auto-generates schema docs | N/A (Pane %83) | Idle | 2026-05-21T23:25:00Z |

## Task Allocation & Progress
| Task ID | Description | Assigned Agent ID | Status | Priority | Dependencies | Notes / Artifacts |
|---|---|---|---|---|---|---|
| task-01 | Scaffold Go safe-scratch-write tool | agent-01 | Completed | P0 | | [main.go](file:///safe-scratch-write/main.go) |
| task-02 | Implement file locking with fcntl | agent-01 | Completed | P0 | task-01 | [main.go:L40-70](file:///safe-scratch-write/main.go#L40-L70) |
| task-03 | Package in Nix home-manager config | agent-01 | In Progress | P0 | task-02 | [ai.nix](file:///google3/ai.nix) |
| task-04 | Document skill workflow | agent-02 | Blocked | P1 | task-03 | Waiting on task-03 completion |
| task-05 | Local lock contention stress test | agent-01 | Failed | P2 | task-02 | Stress test failed: lock timeout after 100 iterations. Stored logs: [test_failure.log](file:///safe-scratch-write/test_failure.log) |

## Active Blockers & Dependencies
| Blocked Agent ID | Blocked Task ID | Blocking Task ID | Blocking Agent ID | Reason |
|---|---|---|---|---|
| agent-02 | task-04 | task-03 | agent-01 | Blocked until Nix package is compiled and in PATH |

## Decisions & Design Notes Log
- **2026-05-21T23:20:00Z** [agent-01]: DECISION: Use Go standard syscall.Flock for advisory locking. - REASON: Avoids external dependencies, highly stable in Unix.
- **2026-05-21T23:22:00Z** [tanmayvijay]: DECISION: Go implementation approved; ensure timeout is set to 60 seconds to prevent indefinite hangs.

## Key Artifacts & Links
- Locked CLI Utility: [safe-scratch-write/](file:///safe-scratch-write/)
- Flake Configuration: [flake.nix](file:///flake.nix)
```

### Artifact Management Example Workflow

This example demonstrates how a tracked agent manages workspace and global documentation artifacts for a multi-step request.

#### 1. The Scenario & User Prompt
*   **Workspace**: `/usr/local/google/home/user/projects/nix/my-service` (Git repository)
*   **Agent Name**: `my-service-agent-1` (Agent ID: `a111e111-b111-c111-d111-e11111111111`)
*   **User Prompt**:
    > *"We need to add a new NixOS module for a PostgreSQL database service. Create the module, configure it to automatically backup the database to `/backup`, test the syntax, and document it in the README."*

---

#### 2. Step-by-Step Documentation Workflow

Because this request involves multiple instructions (creating the module, configuring backups, testing, and updating documentation), the agent must apply the task deconstruction and tracking rules.

##### A. Initial Alignment (Task List & Task Group File)
The agent deconstructs the request into a task list of 5 tasks. Since there are **more than 3 tasks**, it must create a dedicated task group file inside the workspace at:
`/usr/local/google/home/user/projects/nix/my-service/.scratch/tasks/postgresql-database-module.md`

**Content of `postgresql-database-module.md` (Initial State)**:
```markdown
# Task Group: PostgreSQL Database Module

## Goal
Implement and package a PostgreSQL NixOS module with automated backups and documentation.

## Tasks
- [ ] task-01 | Scaffold PostgreSQL NixOS module config | agent-01 | Pending | P0 | |
- [ ] task-02 | Implement db backup systemd service & timer | agent-01 | Pending | P0 | task-01 |
- [ ] task-03 | Local syntax and derivation compilation test | agent-01 | Pending | P0 | task-02 |
- [ ] task-04 | Verify backup cron works correctly in isolation | agent-01 | Pending | P1 | task-02 |
- [ ] task-05 | Update README.md with configuration examples | agent-01 | Pending | P2 | task-03 |
```
*(Note: `agent-01` is the unique local short ID mapped to `my-service-agent-1` inside this workspace's tracking files).*

##### B. Global Master Index Update (`~/.scratch/work.md`)
To prevent concurrent write conflicts from multiple active workspaces, the agent **must** use the custom compiled `safe-scratch-write` tool (which handles advisory locking, timeouts, and atomic writes under the hood) to safely register the new active task group in the global index:
```bash
safe-scratch-write --file ~/.scratch/work.md --append "- [ ] **PostgreSQL Database Module** (Goal: PostgreSQL NixOS module with backups, File: [./.scratch/tasks/postgresql-database-module.md](file:///usr/local/google/home/user/projects/nix/my-service/.scratch/tasks/postgresql-database-module.md))"
```
It also deep merges the active state metadata into the front matter of `work.md`:
```bash
safe-scratch-write --file ~/.scratch/work.md --write-yaml '{"status": "In Progress", "last_updated": "2026-05-21T23:45:00Z"}'
```

##### C. Workspace Tracking Update (`AGENTS.md`)
The agent initializes or updates the local `AGENTS.md` in the workspace directory using `safe-scratch-write`:
```bash
safe-scratch-write --file ./AGENTS.md --write-yaml '{"last_updated": "2026-05-21T23:45:00Z", "agents": [{"id": "agent-01", "name": "my-service-agent-1", "status": "Working"}]}'
```

##### D. Chronological Log Update (`./.scratch/procedure-<agent_name>-<date>.md`)
Before executing a step, the agent appends its action to its own log file to maintain a clean audit trail:
```bash
safe-scratch-write --file ./.scratch/procedure-my-service-agent-1-2026-05-21.md --append "ACTION: Scaffolded postgresql module in modules/db/postgres.nix"
```

##### E. Updating Task Progress
As tasks complete, the agent updates the task checklist state. For example, when `task-01` completes:
1.  Check off the task in `/usr/local/google/home/user/projects/nix/my-service/.scratch/tasks/postgresql-database-module.md`:
    ```bash
    # Direct string replacement using safe-scratch-write:
    safe-scratch-write --file ./.scratch/tasks/postgresql-database-module.md --write-stdin << 'EOF'
    # (File rewritten with "- [x] task-01 ... Completed ...")
    EOF
    ```
2.  Log the completion in the procedure log:
    ```bash
    safe-scratch-write --file ./.scratch/procedure-my-service-agent-1-2026-05-21.md --append "RESULT: task-01 completed successfully; postgres.nix created."
    ```
