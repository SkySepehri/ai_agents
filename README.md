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
