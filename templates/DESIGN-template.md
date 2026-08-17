# DESIGN-{id}: {Feature Title}
**Date:** {YYYY-MM-DD}
**Author:** Designer
**References:** [UW-{id}](../workflows/UW-{id}-{slug}.md) | [TECH-{id}](../specs/TECH-{id}-{slug}.md)
**Status:** PENDING CONFIRMATION

---

## Screens / Views Affected
List each screen or view involved, and which portal it belongs to:
- `./frontend` — `/backup-restore` — BackupAndRestore page (modified)
- `./admin_dashboard` — `/users` — UserList page (new)

---

## UX Flow
Step-by-step navigation matching the UW doc:

```
[Dashboard]
    → User clicks "Create Backup"
    → [Backup Form Modal] opens
        → User fills form
        → Clicks "Start"
    → [Progress View] replaces modal
        → Shows real-time progress
    → [Success State] on completion
        → "View Backup" CTA
```

---

## Component Specifications

### ComponentName
- **Location:** `./frontend/src/pages/.../ComponentName.tsx`
- **Type:** Page | Modal | Form | Table | Card | Drawer | Inline
- **Ant Design base:** `Modal` | `Table` | `Form` | `Card` | custom
- **Reuses existing:** Yes — `./frontend/src/components/...` | No — new component

**Props:**
```typescript
interface ComponentNameProps {
  prop1: string;
  prop2?: number;
  onAction: (data: DataType) => void;
}
```

**States:**

| State | Description | Visual |
|-------|-------------|--------|
| Default | Normal loaded state | Show data in table |
| Loading | Async operation in progress | Ant Design Skeleton or Spin |
| Error | API failed | Error alert with retry button |
| Empty | No data to display | Empty state illustration + CTA |
| Success | Operation completed | Success alert or confirmation |

**Responsive behavior:**
- Desktop (>1024px): [layout description]
- Tablet (768-1024px): [layout description]
- Mobile (<768px): [layout description or "not required for this portal"]

*(Repeat for each component)*

---

## Wireframes
See wireframe files at `./wireframes/`:
- `DESIGN-{id}-{screen-name}.html` — [Screen description]
- `DESIGN-{id}-{screen-name}-error.html` — [Error state]

Open in any browser to preview.

---

## Accessibility Requirements

| Requirement | Implementation |
|-------------|----------------|
| Keyboard navigation | Tab order: field1 → field2 → submit button |
| Focus management | Modal focus trap, return focus on close |
| ARIA labels | All icon buttons have aria-label |
| Color contrast | Primary text #262626 on #fff — 16:1 ratio (AAA) |
| Error identification | Errors use icon + color + text (not color alone) |

---

## Reuse Check
Components found in the codebase that can be reused instead of building new:
- `./frontend/src/components/StatusBadge.tsx` — reuse as-is
- `./frontend/src/components/ConfirmModal.tsx` — extend with new prop `warningText`

---

## Design Sign-Off
- [ ] Confirmed by engineer: _______________
- **Date confirmed:** {YYYY-MM-DD}
- **Notes from review:** -
