# Dela Agents

A set of Claude Code sub-agents for structured, AI-driven software development. Each agent has a defined role, specific source directory access, and a mandatory confirmation gate before passing work downstream.

---

## Agents

| Agent | Model | Role | Gate |
|-------|-------|------|------|
| `tech-lead` | claude-opus-4-6 | Investigates sources, defines end user workflow, designs technical solution | Gate 1 — UW + TECH sign-off |
| `designer` | claude-sonnet-4-6 | Wireframes, component specs, UX flows | Gate 2 — DESIGN sign-off |
| `scrum-master` | claude-haiku-4-5-20251001 | Tickets with AC + DoD, status tracking | Gate 3 — Tickets sign-off |
| `backend` | claude-sonnet-4-6 | FastAPI, DynamoDB, Lambda, WebSocket | Implements after Gate 3 |
| `frontend` | claude-sonnet-4-6 | React, TypeScript, Ant Design | Implements after Gate 3 |
| `qa` | claude-sonnet-4-6 | Tests against UW + specs, final sign-off | Gate 4 — QA sign-off |

---

## Setup

### 1. Clone this repo

```bash
git clone git@github-sky:SkySepehri/ai_agents.git
```

### 2. Run setup from your project root

Pick the script for your OS:

**macOS / Linux (bash)**
```bash
cd /path/to/your/project
bash /path/to/ai_agents/setup.sh
```

**Windows (PowerShell)**
```powershell
cd C:\path\to\your\project
# Allow script execution for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& "C:\path\to\ai_agents\setup.ps1"
```

**Any OS (Python 3.8+) — recommended if unsure**
```bash
cd /path/to/your/project
python /path/to/ai_agents/setup.py
```

The setup script will:
- Copy all agents to `.claude/agents/` in your project
- Create the `.AI-DOC/` directory structure for documentation artifacts
- Check if spec-kit is installed and provide guidance

### 3. (Optional but recommended) Install spec-kit

spec-kit adds `/speckit.clarify` and `/speckit.specify` as native Claude Code skills — useful for clarifying requirements before invoking `@tech-lead`.

```bash
# Install uv (if not already installed)
# macOS/Linux:
curl -LsSf https://astral.sh/uv/install.sh | sh
# Windows (PowerShell):
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"

# Install specify-cli
uv tool install specify-cli

# Initialize spec-kit in your project (run from your project root)
specify init . --integration claude --script py
```

See [spec-kit integration](#spec-kit-integration) section below for how it fits into the workflow.

### 4. Open your project in Claude Code

```bash
cd /path/to/your/project
claude
```

---

## How to Use

Every request follows this order. Do not skip steps.

```
@tech-lead → @designer (if UI) → @scrum-master → @backend / @frontend → @qa
```

### Starting a new feature or bug fix

Always start with Tech Lead:

```
@tech-lead We need to add a download progress indicator to the backup restore flow.
           Users currently have no feedback while a large backup is downloading.
```

The Tech Lead will:
1. Investigate the relevant source code
2. Define the end user workflow (and ask you to confirm it)
3. Design the technical solution (and ask you to confirm it)
4. Update the ROADMAP

### After Tech Lead sign-off — Designer (if UI changes)

```
@designer TECH-003 has been approved. Please produce the design spec.
```

The Designer will read the confirmed docs and produce wireframes + a DESIGN doc, then ask for your confirmation.

### After Designer sign-off — Scrum Master

```
@scrum-master TECH-003 and DESIGN-003 are confirmed. Please create the tickets.
```

The Scrum Master will read all approved docs and produce a TICKETS doc with AC and DoD, then ask for your confirmation.

### After Tickets confirmation — Backend and Frontend

```
@backend TICKETS-003 is confirmed. Please implement TICKET-003-001 and TICKET-003-002.

@frontend TICKETS-003 is confirmed. Please implement TICKET-003-003.
```

Backend and Frontend can work in parallel. They will read the TECH spec and implement exactly what is defined.

### After implementation — QA

```
@qa TICKET-003-001, 002, and 003 are marked complete. Please run QA on feature 003.
```

QA will validate against the UW doc, TECH spec, DESIGN doc, and all ticket AC items, then produce a QA report.

---

## Document Structure

All artifacts live in `.AI-DOC/` in your project:

```
.AI-DOC/
├── roadmap/
│   └── ROADMAP.md                       ← Master living roadmap (all features)
├── workflows/
│   └── UW-003-backup-download.md        ← End user workflow
├── specs/
│   ├── TECH-003-backup-download.md      ← Technical spec
│   ├── DESIGN-003-backup-download.md    ← UI/UX spec
│   └── wireframes/
│       └── DESIGN-003-progress-bar.html ← HTML wireframe (open in browser)
├── tickets/
│   └── TICKETS-003-backup-download.md   ← Tickets with AC + DoD + status
└── qa/
    └── QA-003-backup-download.md        ← QA test report
```

These documents persist across sessions and team members. Any engineer can continue work from where another left off by reading the `.AI-DOC/` directory.

---

## ID Convention

Use a sequential 3-digit ID for each feature:
- `001`, `002`, `003`, ...
- File slug: lowercase, hyphen-separated, max 5 words
- Example: `UW-003-backup-download-progress.md`

Keep the same ID across all documents for the same feature (`UW-003`, `TECH-003`, `DESIGN-003`, `TICKETS-003`, `QA-003`).

---

## Project Source Directories

The agents are configured for projects with this structure:

```
your-project/
├── backend/           ← FastAPI, Lambda, DynamoDB (Backend agent primary)
├── frontend/          ← React + TypeScript + Ant Design (Frontend agent primary)
├── admin_dashboard/   ← Admin portal (Frontend agent primary)
├── mssp_partner/      ← MSSP partner portal (Frontend agent primary)
└── dela_agent/        ← Windows service + DC tool (Backend agent primary)
```

If your project has a different structure, update the directory references in each agent file under `.claude/agents/`.

---

## Confirmation Gates

No agent starts work without the upstream gate being confirmed.

| Gate | Required by |
|------|------------|
| Engineer confirms UW doc | Tech Lead stops and waits before writing TECH spec |
| Engineer confirms TECH spec | Designer and Scrum Master blocked |
| Engineer confirms DESIGN doc | Scrum Master blocked (for UI features) |
| Engineer confirms Tickets | Backend and Frontend blocked |
| QA signs off | Feature cannot be marked Done in ROADMAP |

---

## Templates

Blank templates for each document type are in `templates/`. These are used by the agents automatically, but you can also use them to manually create or review docs.

- `templates/UW-template.md`
- `templates/TECH-template.md`
- `templates/DESIGN-template.md`
- `templates/TICKETS-template.md`
- `templates/ROADMAP-template.md`

---

## spec-kit Integration

[spec-kit](https://github.com/github/spec-kit) is an optional but recommended companion. It adds native Claude Code skills for structured spec writing that complement the `@tech-lead` agent.

### How it fits into the workflow

```
Engineer describes the request
        │
        ▼
/speckit.clarify          ← spec-kit: surfaces ambiguous details BEFORE writing anything
        │
        ▼
/speckit.specify          ← spec-kit: produces a structured spec.md with user stories + FR + SC
        │
        ▼
@tech-lead                ← reads the spec.md, investigates sources, writes UW doc + TECH spec
        │
        ▼
(rest of agent workflow...)
```

### What spec-kit adds

| spec-kit Command | Value |
|---|---|
| `/speckit.clarify` | AI asks clarifying questions — surfaces gaps before the Tech Lead starts |
| `/speckit.specify` | Structured spec with prioritized user stories, FR-001 requirements, SC-001 success criteria |
| `/speckit.constitution` | Project-level principles file (complements CLAUDE.md) |
| `/speckit.converge` | After implementation, checks what was built against the original spec |

### What we do NOT use from spec-kit

- `/speckit.plan` — replaced by `@tech-lead` TECH spec (richer, codebase-aware)
- `/speckit.tasks` — replaced by `@scrum-master` (richer AC + DoD + dependency tracking)
- `/speckit.implement` — replaced by `@backend` and `@frontend` agents (gated, role-separated)

---

## Detailed Workflow

See `docs/workflow.md` for the complete workflow diagram and gate rules.

---

## Worked Example: Real-Time Backup Progress

This is a full end-to-end example using the feature:
> "Users have no visibility into how a backup is progressing. They start a backup and see nothing until it finishes or fails. We need a real-time progress indicator."

This feature touches backend (WebSocket), frontend (progress UI), and the Dela Agent (progress reporting). It's a good example because it crosses all system boundaries.

---

### Step 0a — Engineer runs `/speckit.specify`

The engineer opens Claude Code and types:

```
/speckit.specify Users need real-time progress updates during backup operations.
Currently the UI shows nothing after clicking "Start Backup" until the operation
completes or fails. We need a progress bar and status messages that update live
as the backup agent reports progress.
```

**spec-kit creates `specs/001-backup-progress/spec.md`:**

```markdown
# Feature Specification: Backup Progress Visibility

**Feature Branch**: `001-backup-progress`
**Status**: Draft

## User Stories & Testing

### User Story 1 — Live Progress Bar (Priority: P1)
As a user who has started a backup, I want to see a progress bar with
percentage and current status so I know the operation is running and
approximately how long it will take.

**Independent Test**: Start a backup — progress bar appears and increments
from 0% to 100% without page refresh.

**Acceptance Scenarios**:
1. Given a backup has been started, when the agent sends a progress update,
   then the UI shows the percentage and a status message within 1 second.
2. Given the progress bar is at 100%, when the backup completes,
   then the bar turns green and a success message is shown.
3. Given a backup is in progress, when the agent reports a failure,
   then the bar turns red and the error reason is displayed.

### User Story 2 — Progress Persists on Refresh (Priority: P2)
As a user who refreshes the page mid-backup, I want to see the current
progress state so I don't think the backup stopped.

**Acceptance Scenarios**:
1. Given a backup is at 60%, when the user refreshes the page,
   then the progress bar loads at 60% within 2 seconds.

## Functional Requirements

- **FR-001**: System MUST display a progress bar on the backup page when
  a backup is active.
- **FR-002**: Progress MUST update in real-time without manual refresh.
- **FR-003**: System MUST show the current step label (e.g., "Scanning files",
  "Transferring data", "Verifying integrity").
- **FR-004**: System MUST persist the last known progress state so a page
  refresh shows current progress.
- **FR-005**: System MUST display error details if the backup fails mid-progress.

## Success Criteria

- **SC-001**: Progress updates appear within 1 second of the agent reporting them.
- **SC-002**: A user can determine backup status without contacting support.
- **SC-003**: 0% of active backups show a blank/empty state to the user.
```

---

### Step 0b — Engineer runs `/speckit.clarify`

```
/speckit.clarify
```

**spec-kit asks one targeted question:**

```
Question: Should progress percentage be calculated by file count or by data volume (bytes transferred)?

Why it matters: This determines what the Dela Agent measures and reports — choosing
the wrong unit means the progress bar won't feel accurate for large or small files.

Recommended: Option B — bytes transferred
  More accurate for backups with mixed file sizes; users care about data volume, not count.

| Option | Description |
|--------|-------------|
| A | File count (files processed / total files) |
| B | Bytes transferred (MB transferred / total MB) |
| C | Both — show files and bytes side by side |
```

**Engineer replies:** `B`

spec-kit updates `spec.md` FR-001 to include "bytes transferred" and adds to Success Criteria.

---

### Step 1 — Engineer invokes `@tech-lead`

```
@tech-lead Feature 001: real-time backup progress. spec is at specs/001-backup-progress/spec.md
```

**Tech Lead — Phase 0: Reads spec.md**

```
Found spec-kit spec at specs/001-backup-progress/spec.md
Extracting:
  - User Stories: P1 (live progress bar), P2 (persist on refresh)
  - FR-001 to FR-005 (progress display, real-time, step labels, persistence, errors)
  - SC-001: updates within 1 second
  - Clarification already resolved: bytes transferred
I will use these as the foundation for the UW doc.
```

**Tech Lead — Phase 1: Investigates sources**

Reads:
- `backend/src/websocket/websocket_router.py` — existing WS message routing
- `backend/src/portal/backup/backup_routers.py` — backup start/status endpoints
- `DelaAgent/tool/python_tool.py` — how the agent currently reports completion
- `frontend/src/pages/backup-restore/BackupAndRestore.tsx` — current backup UI
- `.AI-DOC/roadmap/ROADMAP.md` — checks existing feature IDs

Findings: Agent currently sends only a single completion message. No intermediate
progress messages exist. BackupState DynamoDB table has `status` and `completedAt`
fields but no `progressPercent` or `currentStep` fields.

**Tech Lead — Phase 2: Writes UW doc, then pauses**

Creates `.AI-DOC/workflows/UW-001-backup-progress.md`:

```markdown
# UW-001: Real-Time Backup Progress
**Date:** 2026-08-18
**Status:** PENDING CONFIRMATION
**Input Spec:** specs/001-backup-progress/spec.md

## User Role
End User (any authenticated user who has started a backup)

## Trigger
User clicks "Start Backup" on the Backup & Restore page.

## User Stories
### Story 1 — Live Progress Bar (P1)
As a user, I see a progress bar that increments in real-time.
**Acceptance Scenarios:**
- Given backup is active, when agent sends update, then % and step label
  appear within 1 second.
- Given backup reaches 100%, then bar turns green with success message.
- Given backup fails, then bar turns red with error reason.

### Story 2 — Progress Persists on Refresh (P2)
**Acceptance Scenarios:**
- Given backup is at 60% and user refreshes, then page loads showing 60%.

## Step-by-Step Flow
1. User clicks "Start Backup" — button becomes disabled, progress bar appears at 0%
2. System displays: "Backup starting..." with a step label
3. Dela Agent begins operation, sends progress events over WebSocket every ~2 seconds
4. Progress bar increments, step label updates (Scanning → Transferring → Verifying)
5. On completion: bar fills to 100%, turns green, "Backup complete" shown, button re-enables
6. On failure: bar turns red, error message shown, "Retry" button appears

## Decision Points
- If user navigates away and returns: load current progress from BackupState table
- If WebSocket disconnects mid-backup: show "Reconnecting..." banner, resume on reconnect

## Error States
| Scenario | User Sees |
|----------|-----------|
| Agent connection lost | "Connection interrupted — reconnecting" banner |
| Backup fails mid-progress | Red progress bar + error message + Retry button |
| Backup state not found on refresh | "Unable to load status" + manual refresh link |

## Success State
Progress bar at 100% (green). "Backup completed successfully" message.
Timestamp of completion shown. Download button (if applicable) re-enabled.

## Out of Scope
- Estimated time remaining (deferred)
- Email/push notifications on completion (separate feature)
- Progress for restore operations (separate feature)

## Functional Requirements
- FR-001: Display progress bar when backup is active (bytes-based %)
- FR-002: Real-time updates via WebSocket, no manual refresh
- FR-003: Show current step label per agent phase
- FR-004: Persist progress in BackupState DynamoDB for refresh recovery
- FR-005: Display error detail on failure

## Success Criteria
- SC-001: Progress updates visible within 1 second of agent reporting
- SC-002: User never sees blank state during an active backup
- SC-003: Page refresh during active backup shows current progress within 2 seconds

## Confirmation
- [ ] Confirmed by engineer
```

**Tech Lead asks:**
> "I've created the end user workflow at `.AI-DOC/workflows/UW-001-backup-progress.md`.
> Key finding: the Dela Agent currently sends no intermediate progress events —
> this is a new capability. BackupState table needs new fields.
> Does this match the business intent? Reply YES to confirm."

**Engineer replies:** `YES`

---

**Tech Lead — Phase 3: Writes TECH spec, then pauses**

Creates `.AI-DOC/specs/TECH-001-backup-progress.md` (abbreviated):

```markdown
# TECH-001: Real-Time Backup Progress
**References:** UW-001-backup-progress.md
**Status:** PENDING SIGN-OFF

## Affected Sources
- `DelaAgent/tool/python_tool.py` — add progress event emission
- `backend/src/websocket/websocket_router.py` — add backup_progress message handler
- `backend/src/portal/backup/backup_routers.py` — add GET /backup/{id}/progress
- `frontend/src/pages/backup-restore/BackupAndRestore.tsx` — add progress UI

## Technical Approach
The Dela Agent will emit a new `backup_progress` WebSocket message every ~2 seconds
during an active backup. The backend forwards this to the frontend via the existing
API Gateway WebSocket connection. Progress state is also written to DynamoDB so
page refreshes can recover current state.

## API Contracts

### GET /backup/{backupId}/progress
**Auth:** Cognito JWT required
**Response 200:**
{
  "backupId": "string",
  "progressPercent": 45,
  "currentStep": "Transferring data",
  "bytesTransferred": 1073741824,
  "totalBytes": 2415919104,
  "status": "IN_PROGRESS"
}
**Error:** 404 if backupId not found

## WebSocket Message Contracts

### backup_progress (Agent → Backend → Frontend)
{
  "type": "backup_progress",
  "backupId": "string",
  "progressPercent": 45,
  "currentStep": "Transferring data",
  "bytesTransferred": 1073741824,
  "totalBytes": 2415919104
}

## Data Model Changes — BackupState-{stage}
New attributes:
| Attribute | Type | Description |
|-----------|------|-------------|
| progressPercent | Number | 0-100 |
| currentStep | String | Human-readable step label |
| bytesTransferred | Number | Bytes processed so far |
| totalBytes | Number | Total bytes to process |

## Implementation Order
1. Backend: DynamoDB model (new fields)
2. DelaAgent: emit backup_progress WebSocket events
3. Backend: handle backup_progress, write to DynamoDB
4. Backend: GET /backup/{id}/progress endpoint
5. Frontend: subscribe to WS events + load from REST on mount
6. Frontend: progress bar + step label UI

## Risks
- Agent sends high-frequency events — throttle to max 1 per 2 seconds to avoid WS overload
- BackupState writes on every event — use conditional writes to avoid race conditions

## Tech Lead Sign-Off
- [ ] Approved
```

**Tech Lead asks:**
> "TECH spec ready at `.AI-DOC/specs/TECH-001-backup-progress.md`.
> Main risk: Agent event throttling to avoid WebSocket overload — I've noted this.
> UI changes are involved so Designer is next. Reply YES to approve."

**Engineer replies:** `YES`

---

### Step 2 — Engineer invokes `@designer`

```
@designer TECH-001 is approved. Please produce the design spec for the backup progress UI.
```

Designer reads `UW-001` + `TECH-001`, checks existing components in `frontend/src/`.

Finds: `frontend/src/components/StatusBadge.tsx` can be reused. No existing progress
bar component — needs new one using Ant Design `Progress`.

Produces `DESIGN-001-backup-progress.md` + wireframe HTML at
`.AI-DOC/specs/wireframes/DESIGN-001-progress-bar.html`.

**Designer asks for confirmation. Engineer replies:** `YES`

---

### Step 3 — Engineer invokes `@scrum-master`

```
@scrum-master UW-001, TECH-001, and DESIGN-001 are all confirmed. Please create tickets.
```

Scrum Master produces `TICKETS-001-backup-progress.md`:

```markdown
# TICKETS-001: Real-Time Backup Progress

## Tickets

### TICKET-001-001: Add progress fields to BackupState DynamoDB table
**Assigned to:** Backend | **Priority:** High | **Depends on:** None
**AC:**
- Given a backup_progress event is received, when written to DynamoDB,
  then progressPercent, currentStep, bytesTransferred, totalBytes are persisted
**DoD:** Code reviewed, unit tests written, deployed to staging, QA sign-off

### TICKET-001-002: Emit backup_progress WebSocket events from Dela Agent
**Assigned to:** Backend | **Priority:** High | **Depends on:** TICKET-001-001
**AC:**
- Given an active backup, when 2 seconds have passed since last event,
  then agent emits backup_progress with current bytes and step label
- Given event frequency exceeds 1/2s, then agent throttles to 1 per 2 seconds

### TICKET-001-003: Backend WebSocket handler for backup_progress
**Assigned to:** Backend | **Priority:** High | **Depends on:** TICKET-001-001
**AC:**
- Given backup_progress message received, when forwarded to frontend WS,
  then message arrives within 500ms
- Given DynamoDB write, when concurrent update received,
  then conditional write prevents race condition

### TICKET-001-004: GET /backup/{id}/progress API endpoint
**Assigned to:** Backend | **Priority:** Medium | **Depends on:** TICKET-001-001
**AC:**
- Given valid backupId, when called, then returns current progress fields
- Given invalid backupId, when called, then returns 404

### TICKET-001-005: Frontend progress bar component and WS integration
**Assigned to:** Frontend | **Priority:** High | **Depends on:** TICKET-001-004
**AC:**
- Given backup starts, when WS event received, then progress bar updates < 1s
- Given page loads during active backup, when component mounts,
  then GET /progress is called and bar shows current %
- Given backup completes, then bar shows 100% green + success message
- Given backup fails, then bar shows red + error reason + Retry button
- Given WS disconnects, then "Reconnecting..." banner appears

## Dependency Map
TICKET-001-001 → TICKET-001-002, 003, 004
TICKET-001-004 → TICKET-001-005
All complete → QA
```

**Scrum Master asks for confirmation. Engineer replies:** `YES`

---

### Step 4 — Backend and Frontend implement in parallel

```
@backend TICKETS-001 confirmed. Please implement TICKET-001-001, 002, 003, and 004.

@frontend TICKETS-001 confirmed. Please implement TICKET-001-005.
```

Each agent reads the TECH spec and DESIGN spec, implements only what is defined,
and reports completion using the standard output format.

---

### Step 5 — Engineer invokes `@qa`

```
@qa All TICKET-001 tickets are marked complete. Please run QA on feature 001.
```

QA reads `UW-001` + `TECH-001` + `DESIGN-001` + `TICKETS-001`, checks the
implementation, and produces `QA-001-backup-progress.md`.

Validates all 5 AC items across 5 tickets. If all pass, produces sign-off:

```
QA Report: QA-001-backup-progress.md
Result: APPROVED
- 12/12 AC items passed
- No critical or high severity bugs
- Security check: auth on GET /progress endpoint confirmed
- Regression check: existing backup start/stop flow unaffected
```

**Engineer confirms QA sign-off. Scrum Master updates ROADMAP to Done.**

---

### Step 6 (Optional) — Engineer runs `/speckit.converge`

```
/speckit.converge
```

spec-kit reads `specs/001-backup-progress/spec.md` and compares against the
implementation. If SC-001 (updates within 1 second) and FR-004 (persist on refresh)
are satisfied in code, it reports:

```
Converged — the implementation satisfies the spec, plan, and tasks.
Checked: 5 FRs, 3 SCs, 2 user stories / 5 acceptance scenarios.
```

If a gap is found, it appends a remediation task to `tasks.md` for the next
`/speckit.implement` pass.

---

### Resulting Document Set

After this feature is complete, your `.AI-DOC/` contains:

```
.AI-DOC/
├── roadmap/
│   └── ROADMAP.md                              ← 001 marked Done
├── workflows/
│   └── UW-001-backup-progress.md              ← confirmed user workflow
├── specs/
│   ├── TECH-001-backup-progress.md            ← confirmed technical spec
│   ├── DESIGN-001-backup-progress.md          ← confirmed UI spec
│   └── wireframes/
│       └── DESIGN-001-progress-bar.html       ← open in browser
├── tickets/
│   └── TICKETS-001-backup-progress.md         ← all tickets Done
└── qa/
    └── QA-001-backup-progress.md              ← QA approved

specs/
└── 001-backup-progress/
    └── spec.md                                ← spec-kit input spec
```

Any engineer who joins later can read these files and immediately understand
what was built, why, and how — without asking anyone.
