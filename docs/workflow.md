# Development Workflow

This document describes the agent-driven development workflow. Every feature or bug fix follows this sequence without exception.

---

## The Flow

```
📥 Request / Feature / Bug
        │
        ▼
    Tech Lead (claude-opus-4-6)
        ├── Phase 1: Investigate source directories
        ├── Phase 2: Define end user workflow → writes UW-{id}.md
        ├── ⏸️  PAUSE — engineer confirms UW doc
        ├── Phase 3: Design technical solution → writes TECH-{id}.md
        ├── Phase 4: Update ROADMAP.md
        └── ⏸️  PAUSE — engineer confirms TECH spec
                │ confirmed
                ▼
        Designer (claude-sonnet-4-6)     ← only if UI changes involved
                ├── Reads confirmed UW + TECH docs
                ├── Produces wireframes + DESIGN-{id}.md
                └── ⏸️  PAUSE — engineer confirms DESIGN doc
                        │ confirmed
                        ▼
                Scrum Master (claude-haiku-4-5-20251001)
                        ├── Reads confirmed UW + TECH + DESIGN docs
                        ├── Creates TICKETS-{id}.md with AC + DoD
                        └── ⏸️  PAUSE — engineer confirms tickets
                                │ confirmed
                                ▼
                    Backend (claude-sonnet-4-6) ──┬── implement in parallel
                    Frontend (claude-sonnet-4-6) ─┘   (after their tickets are confirmed)
                                │
                                ▼
                            QA (claude-sonnet-4-6)
                                ├── Tests against UW + TECH + DESIGN
                                ├── Produces QA-{id}.md report
                                └── ⏸️  PAUSE — engineer confirms QA sign-off
                                        │ signed off
                                        ▼
                                Scrum Master updates ROADMAP to Done
```

---

## Gate Rules

| Gate | Who confirms | What they review | Block if missing |
|------|-------------|-----------------|-----------------|
| UW Confirmation | Engineer | End user workflow accuracy | Tech Lead stops at Phase 2 |
| TECH Sign-Off | Engineer | Architecture, contracts, risks | Designer and Scrum Master blocked |
| DESIGN Sign-Off | Engineer | Wireframes, component specs | Scrum Master blocked (for UI tickets) |
| Tickets Confirmation | Engineer | AC, DoD, dependencies | Backend and Frontend blocked |
| QA Sign-Off | Engineer | Test report, bugs found | Feature cannot be marked Done |

---

## Document Artifacts

Every feature produces a living document set in `.AI-DOC/`:

```
.AI-DOC/
├── roadmap/
│   └── ROADMAP.md                           ← master living roadmap
├── workflows/
│   └── UW-{id}-{slug}.md                   ← end user workflow
├── specs/
│   ├── TECH-{id}-{slug}.md                 ← technical spec
│   ├── DESIGN-{id}-{slug}.md               ← UI/UX spec
│   └── wireframes/
│       └── DESIGN-{id}-{screen}.html       ← HTML wireframes
├── tickets/
│   └── TICKETS-{id}-{slug}.md              ← tickets + status
└── qa/
    └── QA-{id}-{slug}.md                   ← QA report
```

These documents persist across sessions and team members. Any engineer can pick up where another left off by reading the `.AI-DOC/` directory.

---

## ID Convention

Use a sequential ID for each feature/bug:
- `001`, `002`, `003`, ...
- Slug: lowercase, hyphen-separated title, max 5 words
- Example: `UW-003-backup-restore-flow.md`

---

## Agent Invocation

In Claude Code, invoke agents using `@agent-name` or by selecting them from the agent picker.

| Agent | When to invoke |
|-------|---------------|
| `@tech-lead` | Any new request — always first |
| `@designer` | After Tech Lead sign-off, if UI is involved |
| `@scrum-master` | After Tech Lead + Designer sign-offs |
| `@backend` | After Scrum Master confirmation, for backend tickets |
| `@frontend` | After Scrum Master confirmation, for frontend tickets |
| `@qa` | After Backend + Frontend complete their tickets |

---

## Skipping the Designer

If the request has no UI changes (e.g., a backend-only API change, a data migration, a cron job), skip the Designer step. The Scrum Master reads only UW + TECH docs and proceeds.

Tech Lead should note in the TECH spec: `UI Changes: None — Designer step skipped.`
