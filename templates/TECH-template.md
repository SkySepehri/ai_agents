# TECH-{id}: {Feature Title}
**Date:** {YYYY-MM-DD}
**Author:** Tech Lead
**References:** [UW-{id}: {title}](../workflows/UW-{id}-{slug}.md)
**Status:** PENDING SIGN-OFF

---

## Affected Sources
Which directories and files are impacted:
- `./backend/src/...` — [why]
- `./frontend/src/...` — [why]
- `./dela_agent/...` — [why]

---

## Technical Approach
High-level design decision and rationale. Explain the "why" behind the approach, not just the "what". Include any alternatives considered and why they were rejected.

---

## API Contracts

### POST /api/v1/{resource}
**Auth:** Required — Cognito JWT
**Request Body:**
```json
{
  "field1": "string",
  "field2": 123
}
```
**Response 200:**
```json
{
  "id": "string",
  "status": "string"
}
```
**Error Responses:**
- `400` — Invalid input: `{ "error": "message" }`
- `401` — Unauthorized
- `404` — Resource not found: `{ "error": "message" }`
- `500` — Server error: `{ "error": "Internal server error" }`

*(Repeat for each new or modified endpoint)*

---

## WebSocket Message Contracts (if applicable)

### Message Type: `{message_type}`
**Direction:** Backend → Agent | Agent → Backend | Backend → Frontend
**Payload:**
```json
{
  "type": "{message_type}",
  "data": {}
}
```

---

## Data Model Changes

### Table: {TableName}-{stage}
**Change type:** New table | New attributes | New GSI | Modified existing

| Attribute | Type | Key | Description |
|-----------|------|-----|-------------|
| PK | String | Partition Key | |
| SK | String | Sort Key | |
| field1 | String | - | |

**GSI changes:** (if any)
**Migration needed:** Yes / No — (if yes, describe steps)

---

## Component Boundaries
What each service/module owns and how they communicate:

| Component | Owns | Communicates Via |
|-----------|------|-----------------|
| Backend | Business logic, data persistence | REST, WebSocket |
| Frontend | UI, user interaction | REST calls to Backend |
| Dela Agent | Local DC operations | WebSocket to Backend |

---

## Implementation Order
Recommended sequence to avoid blocking:
1. Backend: DynamoDB model changes
2. Backend: API endpoint(s)
3. Frontend: UI component(s) (can start in parallel with step 2)
4. Frontend: API integration
5. Integration testing

---

## Risks & Constraints

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Breaking change to existing endpoint | High | Version the endpoint |
| DynamoDB schema change affects existing records | Medium | Migration script |
| WebSocket message format change | High | Coordinate backend + agent deploy |

---

## Security Considerations
- Auth: How is this feature protected?
- Data scoping: How is cross-tenant access prevented?
- Input validation: What is validated at the API boundary?
- Any new IAM permissions required?

---

## Tech Lead Sign-Off
- [ ] Approved — proceed to Designer (if UI involved) or directly to Scrum Master
- **Signed by:** Tech Lead
- **Date:** {YYYY-MM-DD}
- **Notes:** -
