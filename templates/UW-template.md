# UW-{id}: {Feature Title}
**Date:** {YYYY-MM-DD}
**Author:** Tech Lead
**Status:** PENDING CONFIRMATION

---

## User Role
Who performs this workflow (e.g., Admin, End User, MSSP Partner, System)

## Trigger
What event or user action starts this workflow (e.g., clicks "Create Backup", receives a notification, logs in for the first time)

## Preconditions
What must be true before this workflow can start:
- User must be authenticated
- Feature flag X must be enabled
- Data Y must exist

---

## Step-by-Step Flow

| Step | Actor | Action | System Response |
|------|-------|--------|-----------------|
| 1 | User | Clicks "..." | System shows ... |
| 2 | System | Validates ... | Displays ... |
| 3 | User | Fills in form | - |
| 4 | User | Submits | System processes and shows result |

---

## Decision Points
- **If** user has no existing records **then** show empty state with CTA
- **If** user has pending action **then** prompt to complete before proceeding
- **If** X **then** Y, **else** Z

---

## Error States

| Scenario | User Sees | User Can Do |
|----------|-----------|-------------|
| Network failure | "Unable to connect. Try again." | Retry button |
| Auth expired | Redirect to login | Re-authenticate |
| Validation error | Inline field errors | Correct and resubmit |
| Server error | "Something went wrong. Contact support." | Retry or dismiss |

---

## Success State
What the user sees and can do when the workflow completes successfully:
- Confirmation message: "..."
- Next available actions: [...]
- Any data updated or created

---

## Out of Scope
What this workflow explicitly does NOT cover (prevents scope creep):
- Feature X is handled by workflow UW-{other-id}
- Edge case Y is deferred to a future iteration

---

## Open Questions
Questions that need answering before this workflow is fully defined:
- [ ] Question 1?
- [ ] Question 2?

---

## Confirmation
- [ ] Confirmed by engineer: _______________
- **Date confirmed:** {YYYY-MM-DD}
- **Notes from review:** -
