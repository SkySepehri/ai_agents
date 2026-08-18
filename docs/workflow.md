# Development Workflow

This document describes the agent-driven development workflow. Every feature or bug fix follows this sequence without exception.

---

## The Flow

```
📥 Request / Feature / Bug
        │
        ▼
  [OPTIONAL] spec-kit — run before Tech Lead for richer input
        ├── /speckit.specify  → creates specs/NNN-slug/spec.md
        │     (user stories + FR-001 requirements + SC-001 success criteria)
        └── /speckit.clarify  → surfaces ambiguities, updates spec.md
        │
        ▼
    Tech Lead (claude-opus-4-6)
        ├── Phase 0: Check for spec.md → reads it if found
        ├── Phase 1: Investigate source directories
        ├── Phase 2: Define end user workflow → writes UW-{id}.md
        │             (uses spec.md user stories + FR + SC as input when available)
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
                  [OPTIONAL] /speckit.converge — checks code against original spec.md
                                        │
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

## Agent & Command Invocation

In Claude Code, invoke agents using `@agent-name` and spec-kit commands using `/speckit.*`.

| Step | Command / Agent | When |
|------|----------------|------|
| 0a (optional) | `/speckit.specify` | Before Tech Lead — creates structured spec.md |
| 0b (optional) | `/speckit.clarify` | After specify — removes spec ambiguities |
| 1 | `@tech-lead` | Always first — reads spec.md if present |
| 2 | `@designer` | After Tech Lead sign-off, if UI is involved |
| 3 | `@scrum-master` | After Tech Lead + Designer sign-offs |
| 4 | `@backend` | After Scrum Master confirmation, backend tickets |
| 5 | `@frontend` | After Scrum Master confirmation, frontend tickets |
| 6 | `@qa` | After Backend + Frontend complete their tickets |
| 7 (optional) | `/speckit.converge` | After QA — validates code against original spec.md |

---

## spec-kit Commands Reference

| Command | What it produces | Required? |
|---------|-----------------|-----------|
| `/speckit.specify <description>` | `specs/NNN-slug/spec.md` with user stories, FR, SC | No — but improves UW quality |
| `/speckit.clarify` | Updates spec.md with answers to ambiguity questions | No — use when spec has unclear areas |
| `/speckit.constitution` | `.specify/memory/constitution.md` — project principles | No — run once per project |
| `/speckit.converge` | Appends remaining work to tasks if code doesn't match spec | No — useful for gap checking |

---

## Skipping the Designer

If the request has no UI changes (e.g., a backend-only API change, a data migration, a cron job), skip the Designer step. The Scrum Master reads only UW + TECH docs and proceeds.

Tech Lead should note in the TECH spec: `UI Changes: None — Designer step skipped.`
