# TICKETS-{id}: {Feature Title}
**Date:** {YYYY-MM-DD}
**Author:** Scrum Master
**References:** [UW-{id}](../workflows/UW-{id}-{slug}.md) | [TECH-{id}](../specs/TECH-{id}-{slug}.md) | [DESIGN-{id}](../specs/DESIGN-{id}-{slug}.md)
**Status:** PENDING CONFIRMATION

---

## Sprint Overview
Brief summary of what this sprint delivers and the business value it provides.

---

## Ticket List

---

### TICKET-{id}-001: {Title}
**Type:** Story | Task | Bug | Chore
**Assigned to:** Backend | Frontend | Both
**Priority:** High | Medium | Low
**Depends on:** None | TICKET-{id}-00X
**Complexity:** S | M | L | XL

**Description:**
Clear, implementation-ready description. Reference the exact TECH spec section or DESIGN doc component this ticket implements. Leave no ambiguity about scope.

**Acceptance Criteria:**
- Given [context / precondition], when [user action or system event], then [expected result]
- Given [context], when [edge case action], then [expected error or fallback result]
- Given [authenticated user], when [action on their own data], then [correct scoped result]

**Definition of Done:**
- [ ] Code written and self-reviewed by implementer
- [ ] Unit tests written covering all AC items above
- [ ] Tech Lead code review completed
- [ ] Integrated with all dependent tickets
- [ ] Deployed to staging environment
- [ ] QA agent sign-off received
- [ ] ROADMAP.md status updated

**Status:** To Do

---

### TICKET-{id}-002: {Title}
**Type:** Story | Task | Bug | Chore
**Assigned to:** Backend | Frontend | Both
**Priority:** High | Medium | Low
**Depends on:** TICKET-{id}-001
**Complexity:** S | M | L | XL

**Description:**
...

**Acceptance Criteria:**
- Given ..., when ..., then ...

**Definition of Done:**
- [ ] Code written and self-reviewed
- [ ] Unit tests written covering all AC items
- [ ] Tech Lead code review completed
- [ ] Integrated with dependent tickets
- [ ] Deployed to staging
- [ ] QA agent sign-off received
- [ ] ROADMAP.md updated

**Status:** To Do

---

*(Add more tickets as needed)*

---

## Dependency Map

```
TICKET-{id}-001 (Backend: data model)
    └── TICKET-{id}-002 (Backend: API endpoint)
            └── TICKET-{id}-004 (Frontend: API integration)

TICKET-{id}-003 (Frontend: UI component)
    └── TICKET-{id}-004 (Frontend: API integration)

TICKET-{id}-004 → TICKET-{id}-005 (QA validation)
```

## Recommended Implementation Order
1. TICKET-{id}-001 — [reason]
2. TICKET-{id}-002 — [reason, can run in parallel with X]
3. TICKET-{id}-003 — [reason]
4. TICKET-{id}-004 — [reason, blocked by 001 and 003]
5. TICKET-{id}-005 — [QA, blocked by all above]

---

## Scrum Master Sign-Off
- [ ] Confirmed by engineer: _______________
- **Date confirmed:** {YYYY-MM-DD}
- **Notes:** -

---

## Status History
| Date | Ticket | From | To | Updated by |
|------|--------|------|----|------------|
| {date} | TICKET-{id}-001 | To Do | In Progress | {engineer} |
