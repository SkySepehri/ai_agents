# DESIGN-001: BLA v2 -- Attack-Path Dashboard & Scoring Redesign

**Date:** 2026-08-18
**References:** UW-001-bla-attack-path-dashboard.md, TECH-001-bla-attack-path-dashboard.md
**Status:** PENDING CONFIRMATION

---

## Table of Contents

1. Screens / Views Affected
2. Severity Encoding -- Canonical Table
3. UX Flows
4. Component Architecture
5. Component Specifications
6. Wireframes (index)
7. PDF Structure -- Page-by-Page
8. MSSP Portal Changes
9. Accessibility & Printing
10. Reuse Check
11. Design Sign-Off

---

## 1. Screens / Views Affected

| Portal | Screen | Change Type |
|--------|--------|-------------|
| Client Portal (`frontend/`) | Dashboard -- BreachLikelihood section | Major rewrite: hero + graph + matrix + posture |
| Client Portal (`frontend/`) | PDF download (BLA report) | Major rewrite: 10-page + appendix structure |
| MSSP Partner Portal (`mssp_partner/`) | Reports page -- engine list + score display | Surgical edits only |
| MSSP Partner Portal (`mssp_partner/`) | PDF download (BLAMainContent) | Major rewrite: same 10-page structure |

No new routes are added. The BLA section is embedded inside the existing Dashboard route. Admin Dashboard is explicitly out of scope.

---

## 2. Severity Encoding -- Canonical Table

This table governs every surface where severity is represented: web dashboard, PDF, engine matrix, graph nodes, detail panels, legend.

| Severity | Color | Shape | Text Label | PDF Pattern Fill | CSS Background | Border Color |
|----------|-------|-------|------------|-----------------|----------------|--------------|
| Critical | #DC2626 (red) | Filled square | "Critical" | Crosshatch (45deg lines, 3px gap) | rgba(220,38,38,0.15) | #DC2626 |
| High | #E17036 (orange) | Filled triangle (up) | "High" | Diagonal lines (45deg, 6px gap) | rgba(225,112,54,0.15) | #E17036 |
| Medium | #FFDC00 (yellow) | Filled circle | "Medium" | Dots (4px radius, 8px gap) | rgba(255,220,0,0.15) | #FFDC00 |
| Low | #52C41A (green) | Outline circle (no fill) | "Low" | Empty (no fill) | rgba(82,196,26,0.10) | #52C41A |
| No Issue / Pass | #A3A3A3 (gray) | Checkmark | "Pass" | n/a | rgba(163,163,163,0.10) | #A3A3A3 |

Rules:
- No surface may use color alone. Every severity indicator must show color + shape + text.
- In the SVG graph: node border color and border width encode severity; node shape encodes entity type (see Section 5, AttackNode).
- In PDF: every chip carries color + shape + text + pattern fill. Pattern fills are the B&W fallback.
- Deuteranopia simulation review is required at QA before release (SC-011).

---

## 3. UX Flows

### Flow A: Initial Page Load

1. User navigates to the Dashboard. The existing `DashboardV3.tsx` renders the `BreachLikelihoodV2` container.
2. Container fires all four react-query hooks in parallel on mount:
   - `useBreachLikelihood` -- GET /portal/bl/identities
   - `useAttackPath` -- GET /portal/bl/attack-path
   - `useRemediation` -- GET /portal/bl/remediation
   - `usePosture` -- GET /portal/bl/posture
3. While all four are loading: the hero section renders skeleton placeholders (score ring skeleton, KPI card skeletons, graph area spinner).
4. When `useBreachLikelihood` resolves first: the score ring begins its count-up animation (0 to actual score over 1.2 seconds). Verdict text and KPI cluster fade in simultaneously.
5. When `useAttackPath` resolves: the SVG graph renders. If `riskLabel === "Critical"`, the Walk-the-path animation auto-plays once immediately (no user action required). The path cycler shows "N more paths found" if `totalPathCount > 1`.
6. When `useRemediation` resolves: the remediation list renders below the engine matrix.
7. When `usePosture` resolves: data is cached silently; no UI change until user switches to Posture view.
8. Default view on load is Attack view. The view toggle shows "Attack" as active.

**Error states during load:**
- If `/identities` returns 404: entire section shows "Assessing your Entra ID for breach likelihood. Expect result in a few minutes." -- preserving current behavior.
- If `/attack-path` returns 404: graph area shows informational empty state: "No critical attack paths identified." KPI cluster still renders.
- If `/remediation` returns 404 or 500: remediation panel shows "Unable to load remediation data."
- If `/posture` returns 404 or 500: posture panels individually show "Data unavailable."

---

### Flow B: Node Click -- Detail Panel Opens

1. User clicks a node in the attack-path SVG graph.
2. Node border highlights (2px -> 4px, brightness increased). Selection is immediate (no animation delay).
3. Right-side detail panel slides in from the right (200ms ease-out transition). Any previously open panel closes.
4. Panel shows: entity name, entity type, severity chip (color + shape + text), kill-chain stage chip, MITRE tactic IDs, MITRE technique IDs, finding description, "Fix this -- -N pts" remediation hint with risk delta.
5. If MITRE technique is not mapped: MITRE field shows "Unmapped" in gray italics. Panel does not break.
6. User clicks elsewhere on the graph background or presses Escape: panel closes (slides out right). Node returns to normal highlight.
7. Response time requirement: panel visible within 300ms of click (SC-005). Data is already in client state -- no network call.

---

### Flow C: Edge Click -- Detail Panel Opens

1. User clicks an edge (arrow) in the SVG graph.
2. Edge strokes to a thicker highlight state (1.5px -> 3px). Color shifts to the edge's severity color.
3. Right-side detail panel opens (same slide-in as node click). Panel shows: edge label (e.g. "MemberOf"), source entity name -> target entity name, MITRE technique ID, source engine, remediation guidance text.
4. User closes panel same as node flow.

---

### Flow D: "Show Blast Radius" -- Overlay

1. User clicks the "Show blast radius" button (appears below the Tier-0 target node label in the graph).
2. An overlay panel slides up from the bottom of the graph container (not a modal -- stays within the graph area). The overlay shows a list of reachable resources with their type icons and counts: Mailboxes, SharePoint sites, Teams channels, Connected apps, Conditional Access policies.
3. If `blastRadius.reachableResources` is empty: overlay shows "No downstream resources identified."
4. User closes the overlay by clicking the "X" button in the overlay header, or by clicking outside the overlay within the graph area, or by pressing Escape.

---

### Flow E: "N More Paths" -- Path Cycle Control

1. When `totalPathCount > 1`, a count chip appears in the top-right corner of the graph area: "5 paths found -- showing 1 of 5" with left/right chevron buttons.
2. Clicking the right chevron loads the next path from the already-fetched `additionalPaths` array. The graph re-renders with the new path's nodes and edges highlighted. The cycle chip updates: "showing 2 of 5."
3. Clicking the left chevron cycles back. No network request is made (all paths are in client state from the initial `/attack-path` response).
4. Transition: the current path fades out (150ms), the new path fades in (150ms).
5. The detail panel (if open) closes when the active path changes.

---

### Flow F: Attack/Posture View Toggle

1. Two segmented toggle buttons appear above the graph/posture section: "Attack" and "Posture." Default active: "Attack."
2. User clicks "Posture": the Attack view section (graph + engine matrix + remediation list) is hidden via CSS (`display: none`, not unmounted). The Posture view section (NIST CSF, ISO 27001, Essential Eight panels) is shown. Transition: none (instant CSS swap).
3. User clicks "Attack": the Posture view section is hidden; the Attack view section is shown. Transition: instant.
4. No network request is triggered by toggling. All posture data was fetched on mount.
5. SC-008 requirement: toggle must complete in under 200ms. Since it is a CSS visibility swap with pre-fetched data, this is guaranteed.
6. The toggle preserves its state across re-renders of parent components (state lives in `BreachLikelihoodV2/index.tsx`).

---

### Flow G: AD Integrated Toggle

1. When `adIntegrationState === "not_integrated"`: the engine matrix shows an ADUpsellBanner row in place of the AD engine row. The banner is full card weight (same height as a normal engine row). A read-only note near the graph: "Active Directory not assessed. Graph shows cloud paths only."
2. When `adIntegrationState === "hybrid_signals_detected"`: a teaser banner appears at the top of the engine matrix: "Signals of on-premises AD detected -- not assessed." No upsell card. No AD engine row.
3. When `adIntegrationState === "integrated"`: the AD engine row appears in the matrix. An "AD integrated" toggle switch appears in the graph toolbar. Toggle defaults to ON.
4. User flips the AD integrated toggle to OFF: the graph re-renders using only the cloud-path nodes and edges (already in client state -- `primaryPath` was computed with AD; the toggle filters out nodes/edges tagged with `engineId === "active_directory"`). The engine matrix hides the AD row. The score ring re-animates to the headline score without AD weight. The KPI cluster updates to reflect cloud-only values.
5. User flips toggle back to ON: graph, matrix, and score restore the AD view.
6. SC-009 requirement: all UI changes within 1 second. Since this is a client-side filter operation on already-fetched data, there is no network dependency.

---

## 4. Component Architecture

### Library Decisions (corrected — no new packages)

**Graph renderer: `reagraph` v4.21.5**

Justification: The attack-path graph is a shallow, left-to-right DAG of 3-12 nodes. `reagraph` is the appropriate choice for this use case because:
- It is a React-first component library (`<GraphCanvas>`) -- no imperative DOM manipulation required.
- It handles layout automatically via its built-in layout engine (`layoutType="left-right"` covers the LR DAG case).
- It supports custom node and edge rendering via `renderNode` / `renderEdge` callback props, which is required for the entity-type shapes and severity border encoding.
- Its API surface is small and data-driven: pass `nodes: NodePositionArgs[]` and `edges: EdgePositionArgs[]` arrays and it handles positioning.
- It does not require `@dagrejs/dagre` or any D3 dependency.

`@react-sigma/core` + `graphology` (also installed) is better suited for large, force-directed, multi-thousand-node graphs such as the APA (Attack Path Analysis) feature page. It is NOT used here.

**Score ring gauge: `echarts` v6.1.0**

Confirmed correct. ECharts is already in use in the codebase per CLAUDE.md ("Using Chart.js or echarts.apache.org for charts and gauge"). The `ScoreRing.tsx` component uses ECharts' `gauge` series with `type: "gauge"` to produce a full-circle animated ring. No new package required.

**Animations: `motion` v12.38.0**

The `motion` package (Framer Motion v12 rebranded) is already installed. It is used for:
- Path fade transitions in `PathCycler` (fade out current path nodes/edges, fade in next set via `<AnimatePresence>` + `<motion.div>`).
- The blast radius overlay slide-up animation (`motion.div` with `initial={{ y: "100%" }}` / `animate={{ y: 0 }}`).
- Any other entrance/exit animations previously described as D3-based transitions.

No D3 animation APIs are used anywhere in this feature.

**antd v5.20.5 components confirmed:**
- `Drawer` (placement="right", mask=false) -- NodeDetailPanel, EdgeDetailPanel
- `Switch` -- AD integrated toggle in GraphToolbar; Attack/Posture toggle uses `Segmented`
- `Table` -- NOT used for EngineMatrix (custom HTML table for precise cell layout); IS used elsewhere if needed
- `Badge` / `Tag` -- available; `SeverityChip` is a custom component but may use `Tag` internally
- `Progress` -- PostureView framework bars (NISTCSFPanel, ISO27001Panel)
- `Spin` -- loading states
- `Skeleton` -- loading placeholders
- `Collapse` -- DrillDownPanel
- `Tooltip` -- KPI card tooltips, MITRE tag hover
- `Segmented` -- ViewToggle (Attack/Posture)

**MSSP portal: TailwindCSS v4 tokens + `@tabler/icons-react` v3.44.0**

The MSSP portal (`mssp_partner/`) uses NO antd. All styling uses TailwindCSS v4 with the design tokens from `mssp_partner/src/styles/globals.css`:
- `--bg0` through `--bg4` for backgrounds
- `--txt0` through `--txt3` for text
- `--dred`, `--damber`, `--dblue`, `--dgreen`, `--dpurple`, `--dteal`, `--dorange` for semantic colors

Icons in the MSSP portal use `@tabler/icons-react` (e.g. `<IconDownload />`, `<IconChevronRight />`). No antd icon imports in the MSSP portal.

---

The complete new component tree for `frontend/src/pages/dashboard/components/BreachLikelihood/`:

```
BreachLikelihoodV2/
  index.tsx                       Container: data fetching, Attack/Posture toggle state, AD toggle state
  components/
    HeroSection/
      index.tsx                   Composes ScoreRing + VerdictText + KPICluster
      ScoreRing.tsx               ECharts (echarts v6.1.0) animated ring gauge (replaces GaugeChart.tsx)
      VerdictText.tsx             Fear-first narrative text block
      KPICluster.tsx              5 KPI stat cards
      KPICard.tsx                 Single KPI card (label + value + alarm coloring)
    AttackPath/
      index.tsx                   Composes graph + detail panel + path cycler + toolbar
      AttackPathGraph.tsx         reagraph v4.21.5 <GraphCanvas> with custom node/edge renderers
      AttackNode.tsx              Custom reagraph renderNode: SVG shape encodes entity type, border encodes severity
      AttackEdge.tsx              Custom reagraph renderEdge: MITRE label, hot-path pulse animation (CSS keyframe)
      NodeDetailPanel.tsx         Right-panel for node selection (antd Drawer, mask=false)
      EdgeDetailPanel.tsx         Right-panel for edge selection (antd Drawer, mask=false)
      WalkAnimation.tsx           requestAnimationFrame step-by-step animator (no D3 dependency)
      BlastRadiusOverlay.tsx      Bottom overlay within graph area (motion.div slide-up animation)
      PathCycler.tsx              "N paths found -- showing X of N" control (motion AnimatePresence for path transitions)
      GraphToolbar.tsx            AD toggle (antd Switch) + Walk replay button + Show blast radius button
    EngineMatrix/
      index.tsx                   Composes engine rows + drill-down panel
      EngineMatrix.tsx            Severity count grid with sub-scores (custom HTML table)
      EngineMatrixRow.tsx         Per-engine row (engine name, severity count chips, sub-score, weight)
      DrillDownPanel.tsx          Finding list shown when a matrix cell is clicked (antd Collapse)
      ADUpsellBanner.tsx          Full-weight banner row when AD not integrated
      ADTeaserBanner.tsx          Slim teaser when hybrid signals detected
    Remediation/
      index.tsx                   Composes remediation list
      RemediationList.tsx         Ranked remediation items
      RemediationItem.tsx         Single item card (rank, title, MITRE ref, risk delta, paths severed)
    Posture/
      index.tsx                   Composes the three framework panels
      PostureView.tsx             Wrapper with header + three panels
      NISTCSFPanel.tsx            NIST CSF 2.0 -- antd Progress bars per function
      ISO27001Panel.tsx           ISO 27001 Annex A -- antd Progress bars per section (A.5-A.8)
      EssentialEightPanel.tsx     Essential Eight maturity dot indicators per strategy
    Shared/
      SeverityChip.tsx            Color + shape + text severity badge (reusable across all surfaces)
      SeverityLegend.tsx          Inline legend for severity encoding (shape + label)
      KillChainChip.tsx           Stage label chip (INITIAL ACCESS, PRIVILEGE ESCALATION, TAKEOVER)
      MITRETag.tsx                Tactic/technique ID display tag (antd Tag)
      ViewToggle.tsx              Attack/Posture segmented button toggle (antd Segmented)
  hooks/
    useBreachLikelihood.ts        react-query for GET /portal/bl/identities
    useAttackPath.ts              react-query for GET /portal/bl/attack-path
    useRemediation.ts             react-query for GET /portal/bl/remediation
    usePosture.ts                 react-query for GET /portal/bl/posture
  types/
    bla-types.ts                  All BLA v2 TypeScript types (mirrors API contracts from TECH spec)
```

The old `BreachLikelihood.tsx` and `GaugeChart.tsx` are removed entirely and replaced by the above. The `PDFReportRenderer.tsx` is rewritten in place (not moved).

---

## 5. Component Specifications

### 5.1 BreachLikelihoodV2/index.tsx

- **Location:** `frontend/src/pages/dashboard/components/BreachLikelihood/BreachLikelihoodV2/index.tsx`
- **Type:** Container / Page section
- **Ant Design base:** None (layout only)
- **Props:** `className?: string`
- **State managed here:**
  - `activeView: "attack" | "posture"` -- controls Attack/Posture toggle
  - `adIntegratedEnabled: boolean` -- controls AD engine visibility
  - All data state via react-query hooks (not local useState)
- **States:**
  - Loading: renders skeleton layout (score ring placeholder, KPI card skeletons, graph area spinner). Uses `antd` Skeleton components.
  - Error (identities 404): renders "Assessing your Entra ID" message -- preserves current v1 behavior text.
  - Error (identities 500): renders "Unable to load assessment data. Please try again." with a retry button.
  - Success: renders full layout.
- **Behavior:** Fires all 4 hooks simultaneously on mount. Passes data down as props to child sections. Does not contain layout chrome (no headers, no tabs from this level -- those are in child components).

---

### 5.2 ScoreRing.tsx

- **Location:** `frontend/src/pages/dashboard/components/BreachLikelihood/BreachLikelihoodV2/components/HeroSection/ScoreRing.tsx`
- **Type:** Chart component
- **Ant Design base:** None (ECharts)
- **Library:** `echarts` v6.1.0 (confirmed installed in `frontend/package.json`). Uses ECharts `gauge` series (`type: "gauge"`) configured as a full-circle ring. The `echarts-for-react` wrapper may be used if already present in the codebase, otherwise instantiate via `echarts.init()` in a `useEffect` on a `<div ref>`. No new package required -- `echarts` is already a direct dependency per CLAUDE.md guidance ("Using Chart.js or echarts.apache.org for charts and gauge").
- **Props:**
  ```typescript
  type ScoreRingProps = {
    score: number;                     // 0-100
    riskLabel: "Critical" | "High" | "Medium" | "Low";
    animationDuration?: number;        // default 1200ms
  };
  ```
- **Visual:** Full-circle ring gauge (not half-circle). Inner text shows the numeric score. Below the score: risk label with severity color. Ring arc color matches the severity color from the canonical encoding table.
- **States:**
  - Default: ring fully rendered, score and label visible.
  - Animating: count-up from 0 to score value over `animationDuration` ms on mount. Animation runs once.
  - Skeleton: ring shape as a gray placeholder circle.
- **Accessibility:** `role="img"`, `aria-label="Breach likelihood score: {score} out of 100, rated {riskLabel}"`.
- **Note:** This replaces `GaugeChart.tsx` which used Chart.js Doughnut (half-circle, no animation).

---

### 5.3 KPICluster.tsx + KPICard.tsx

- **Location:** `HeroSection/KPICluster.tsx`, `HeroSection/KPICard.tsx`
- **Type:** Display cards
- **Ant Design base:** None (Tailwind grid layout)
- **Props (KPICluster):**
  ```typescript
  type KPIClusterProps = {
    kpis: {
      ttgaHops: number;
      leakedAdminPasswords: number;
      standingGlobalAdmins: number;
      adminsWithMfa: number;
      pathsToTakeover: number;
    };
    riskLabel: string;
  };
  ```
- **Props (KPICard):**
  ```typescript
  type KPICardProps = {
    label: string;
    value: number | string;
    unit?: string;
    isAlarm: boolean;        // true = value displayed in severity red
    tooltip?: string;
  };
  ```
- **5 KPI cards (left to right):**
  1. "Time to Global Admin" -- value: `{ttgaHops} hops` -- alarm when `ttgaHops <= 4`
  2. "Leaked Admin Passwords" -- value: `leakedAdminPasswords` -- alarm when `> 0`
  3. "Standing Global Admins" -- value: `standingGlobalAdmins` -- alarm when `> 2`
  4. "Admins with MFA" -- value: `adminsWithMfa` -- no alarm coloring (informational)
  5. "Paths to Takeover" -- value: `pathsToTakeover` -- alarm when `> 0`
- **States:**
  - Default: neutral gray styling.
  - Alarm: value text turns severity red (#DC2626). Card background gets a subtle red tint (rgba(220,38,38,0.08)).
  - Zero alarm: "Given all admins have MFA and no leaked credentials" -- no alarm color on any card.
  - Skeleton: placeholder bar 80px wide, 24px tall.

---

### 5.4 VerdictText.tsx

- **Location:** `HeroSection/VerdictText.tsx`
- **Type:** Display text block
- **Props:**
  ```typescript
  type VerdictTextProps = {
    verdictText: string;   // pre-generated fear-first narrative from API
    riskLabel: string;
  };
  ```
- **Visual:** 2-3 line paragraph. Font size 14px, line height 1.6. Italic styling. Color: neutral-5 (#A3A3A3) at default; risk-colored accent words are NOT bolded in the web view (kept readable). The full string comes from the API `verdictText` field -- no client-side generation.
- **States:**
  - Skeleton: two placeholder lines.
  - Empty: if `verdictText` is empty string, renders nothing (does not show a blank box).

---

### 5.5 AttackPathGraph.tsx

- **Location:** `AttackPath/AttackPathGraph.tsx`
- **Type:** Directed graph component
- **Library:** `reagraph` v4.21.5. Uses `<GraphCanvas>` with `layoutType="left-right"` for the LR DAG layout. Custom node and edge renderers are supplied via the `renderNode` and `renderEdge` props. NOT `@dagrejs/dagre` (not installed). NOT Sigma.js (`@react-sigma/core` is reserved for the APA page which handles large force-directed graphs).
- **Props:**
  ```typescript
  type AttackPathGraphProps = {
    path: AttackPath;                       // current path being displayed
    onNodeClick: (node: AttackNode) => void;
    onEdgeClick: (edge: AttackEdge) => void;
    isAnimating: boolean;
    animationStep: number;                  // which node/edge is highlighted in walk animation
    adFilterEnabled: boolean;               // when false, filters out AD nodes/edges
  };
  ```
- **reagraph data mapping:** The component maps `path.nodes` to `reagraph`'s `NodePositionArgs[]` and `path.edges` to `EdgePositionArgs[]`. Node ids must be strings (use `node.id`). Edge source/target reference node ids.
- **Custom node rendering:** `renderNode` prop receives `{ node, ... }`. Returns an SVG `<g>` group containing the entity-type shape (circle, rounded rect, hexagon, etc.) plus the severity border color. The kill-chain stage chip and entity label are rendered as absolutely-positioned HTML overlays via `reagraph`'s `labelType` or via a `<foreignObject>` within the SVG. The simpler approach is to render labels as HTML elements positioned relative to the `<GraphCanvas>` container using `reagraph`'s `onNodePointerEnter` coordinates.
- **Layout:** Left-to-right directed graph (`layoutType="left-right"`). Entry nodes on the left, Tier-0 target on the right.
- **Node appearance by entity type:**
  | Entity Type | SVG Shape | Example |
  |-------------|-----------|---------|
  | User | Circle | admin@contoso.com |
  | Group | Rounded rectangle | IT-Admins |
  | Directory Role | Hexagon | Global Administrator |
  | App Registration | Diamond | App |
  | Service Principal | Diamond with inner dot | SPN |
  | Managed Identity | Shield shape | MI |
  | Device | Rectangle | DC01 |
  | Domain / DC | Double rectangle | contoso.com |
  | Certificate Template | Document shape | CertTemplate |
  | Mailbox | Envelope shape | mailbox@contoso.com |
- **Node border encoding:** Severity from the `severity` field on each node. Uses the canonical color table. Critical: 3px red border. High: 2px orange border. Medium: 2px yellow border. Low: 1px green border.
- **Edge appearance:** Directed arrow (SVG arrowhead marker). Hot edges (`isHot: true`) pulse with a subtle glow animation (CSS keyframe, not JS-driven). Edge label shows the `label` field (e.g. "MemberOf"). MITRE technique ID shown in a small tag on the edge midpoint.
- **Kill-chain stage chips:** Rendered above each node (not on the node itself). Stage labels: "INITIAL ACCESS", "PRIVILEGE ESCALATION", "LATERAL MOVEMENT", "TAKEOVER". Uses `KillChainChip` component.
- **States:**
  - Default: static graph, hot-path edges glowing.
  - Walk animation: nodes and edges highlight in sequence order (`edge.sequence`). Each step highlights for 800ms then proceeds. Auto-plays once on load when Critical.
  - No paths: "No critical attack paths identified." centered in the graph area with an informational icon.
  - AD filtered: nodes/edges with `engineId === "active_directory"` are hidden; graph re-layouts.
  - Loading: centered spinner (antd `Spin`).
- **Responsive:** Graph area has a minimum height of 360px. On smaller screens, horizontal scroll is enabled. Graph does not collapse.
- **Accessibility:** Graph container has `role="img"` with `aria-label="Attack path graph from entry node to Global Administrator"`. Individual nodes are focusable via keyboard (`tabIndex={0}`, `onKeyDown` for Enter/Space triggers click handler).

---

### 5.6 AttackNode.tsx

- **Location:** `AttackPath/AttackNode.tsx`
- **Type:** SVG child component
- **Props:**
  ```typescript
  type AttackNodeProps = {
    node: AttackNode;
    isSelected: boolean;
    isAnimationActive: boolean;  // current step in walk animation
    onClick: () => void;
    onKeyDown: (e: React.KeyboardEvent) => void;
  };
  ```
- **Visual:** Renders the SVG shape for the entity type (see shape table in 5.5). Selected state: thicker border + drop shadow. Animation active: glow pulse.

---

### 5.7 NodeDetailPanel.tsx + EdgeDetailPanel.tsx

- **Location:** `AttackPath/NodeDetailPanel.tsx`, `AttackPath/EdgeDetailPanel.tsx`
- **Type:** Slide-in side panel
- **Ant Design base:** `antd Drawer` (placement="right") with `mask={false}` so the graph remains visible.
- **Props (NodeDetailPanel):**
  ```typescript
  type NodeDetailPanelProps = {
    node: AttackNode | null;
    onClose: () => void;
  };
  ```
- **Content (node):**
  - Header: entity label (large, bold) + entity type badge
  - SeverityChip (color + shape + text)
  - KillChainChip (stage label)
  - Section: "MITRE ATT&CK" -- tactic IDs as MITRETag components + technique IDs as MITRETag components. If unmapped: "Unmapped" in gray italics.
  - Section: "Finding" -- `node.detail.description`
  - Section: "Remediation" -- `node.detail.fixText` in a highlighted box. Shows "Fix this: -N pts" with the risk delta number in severity color.
  - If `node.detail.fixText === null` (e.g. the Tier-0 target node itself): "No remediation available for target nodes."
- **Content (edge):**
  - Header: "Relationship: {edge.label}"
  - Source -> Target identity names
  - SeverityChip
  - MITRE technique ID as MITRETag
  - Source engine label
  - Remediation guidance text (`edge.remediation`)
- **States:**
  - Null node/edge: panel is closed (not rendered).
  - Open: slides in from right.
  - Closing: slides out right (Drawer handles this).
- **Width:** 380px on desktop. On screens below 768px: 100vw.

---

### 5.8 WalkAnimation.tsx

- **Location:** `AttackPath/WalkAnimation.tsx`
- **Type:** Animation controller (no visible UI of its own)
- **Props:**
  ```typescript
  type WalkAnimationProps = {
    path: AttackPath;
    onStepChange: (step: number) => void;   // notifies parent of current animation step
    onComplete: () => void;
    autoPlay: boolean;                       // true when riskLabel === "Critical"
  };
  ```
- **Behavior:** Uses `requestAnimationFrame` + a timeout sequence. Each step highlights one node then the outgoing edge (800ms per step). At completion: all nodes remain highlighted. User can replay via "Replay walk" button in `GraphToolbar`. No D3 or external animation library is used -- plain `setTimeout` chain with React state updates.
- **States:**
  - Idle: no animation.
  - Playing: firing step callbacks.
  - Complete: final state persisted.

---

### 5.9 BlastRadiusOverlay.tsx

- **Location:** `AttackPath/BlastRadiusOverlay.tsx`
- **Type:** In-graph overlay panel
- **Props:**
  ```typescript
  type BlastRadiusOverlayProps = {
    blastRadius: BlastRadius;
    onClose: () => void;
    isVisible: boolean;
  };
  ```
- **Visual:** Slides up from the bottom of the graph container using `motion` v12 (`motion.div` with `initial={{ y: "100%" }}`, `animate={{ y: 0 }}`, `exit={{ y: "100%" }}`, transition duration 200ms). Wrapped in `<AnimatePresence>` so the exit animation plays on close. Dark background (rgba(0,0,0,0.85)), full-width of graph container. Header: "Blast Radius -- What an attacker controls" + close X button. Body: a list of resource types with count. Each resource type has a small type icon (SVG inline, no external CDN).
- **Empty state:** "No downstream resources identified."
- **Accessibility:** `role="dialog"`, `aria-label="Blast radius overlay"`, focus trapped while open (Tab cycles through resource list and close button). Escape closes.

---

### 5.10 PathCycler.tsx

- **Location:** `AttackPath/PathCycler.tsx`
- **Type:** Control chip
- **Props:**
  ```typescript
  type PathCyclerProps = {
    totalPathCount: number;
    currentPathIndex: number;
    onPrevious: () => void;
    onNext: () => void;
  };
  ```
- **Visual:** Positioned at top-right of graph area. Pill-shaped chip: "{N} paths found -- showing {X} of {N}" with left/right chevron icon buttons. Hidden when `totalPathCount <= 1`.
- **Path transition animation:** When the user cycles to a new path, the `AttackPathGraph` is wrapped in `<AnimatePresence mode="wait">`. The outgoing path graph fades out (`motion.div` with `exit={{ opacity: 0 }}`, 150ms) and the incoming path fades in (`initial={{ opacity: 0 }}`, `animate={{ opacity: 1 }}`, 150ms). Uses `motion` v12 (already installed). No D3 transitions.
- **Accessibility:** `aria-label="Path navigation: showing path {X} of {N}"`. Chevron buttons: `aria-label="Previous path"`, `aria-label="Next path"`.

---

### 5.11 GraphToolbar.tsx

- **Location:** `AttackPath/GraphToolbar.tsx`
- **Type:** Toolbar strip
- **Props:**
  ```typescript
  type GraphToolbarProps = {
    adIntegrationState: "integrated" | "not_integrated" | "hybrid_signals_detected";
    adEnabled: boolean;
    onADToggle: (enabled: boolean) => void;
    onReplayWalk: () => void;
    onShowBlastRadius: () => void;
  };
  ```
- **Visual:** Horizontal strip above the graph area (or alongside the PathCycler on the same line). Contains:
  - "AD integrated" toggle switch (antd Switch) -- only visible when `adIntegrationState === "integrated"`. Label: "AD integrated."
  - "Replay walk" button (antd Button, secondary style). Only visible after the walk animation has completed at least once.
  - "Show blast radius" button (antd Button, secondary style). Always visible when attack path data exists.
- **Accessibility:** Toggle has `aria-label="Toggle Active Directory integration in graph."` Buttons have descriptive labels.

---

### 5.12 EngineMatrix.tsx + EngineMatrixRow.tsx

- **Location:** `EngineMatrix/EngineMatrix.tsx`, `EngineMatrix/EngineMatrixRow.tsx`
- **Type:** Data table / matrix
- **Ant Design base:** Custom HTML table (not antd Table -- for precise cell layout control with severity chips).
- **Props (EngineMatrix):**
  ```typescript
  type EngineMatrixProps = {
    engineSubScores: EngineSubScore[];
    details: RiskDetailV2[];
    adIntegrationState: string;
    adEnabled: boolean;
  };
  ```
- **Columns:** Engine Name | Critical | High | Medium | Pass | Sub-Score | Weight
- **Engine rows (order from TECH spec, Threat Detection removed):**
  1. Identity Hygiene (IH=25)
  2. Platform Hygiene (PH=20)
  3. Identity Intelligence (II=20)
  4. Microsoft 365 (M365=15)
  5. Active Directory (AD=25, conditional)
- **Severity count cells:** Each cell contains a SeverityChip (color + shape + text) if count > 0, else a dash. Cells are clickable to open the DrillDownPanel for that engine + severity combination.
- **Sub-score cell:** Number from 0-100, colored by severity range (same color rules as the score ring).
- **AD row states:**
  - `adIntegrationState === "integrated"` and `adEnabled`: AD row renders normally.
  - `adIntegrationState === "integrated"` and `!adEnabled`: AD row is hidden (toggled out).
  - `adIntegrationState === "not_integrated"`: AD row is replaced by ADUpsellBanner (full row height).
  - `adIntegrationState === "hybrid_signals_detected"`: ADTeaserBanner renders above the table (not as a row).
- **States:**
  - Loading: skeleton rows.
  - Empty drill-down: "No findings in this category."

---

### 5.13 DrillDownPanel.tsx

- **Location:** `EngineMatrix/DrillDownPanel.tsx`
- **Type:** Expandable panel below selected matrix row
- **Ant Design base:** antd Collapse (accordion-like, inline below the row).
- **Props:**
  ```typescript
  type DrillDownPanelProps = {
    engineId: string;
    severity: "critical" | "high" | "medium" | "low";
    findings: RiskDetailV2[];
    onClose: () => void;
  };
  ```
- **Content:** List of findings for the selected engine + severity combination. Each finding: finding name, description snippet (2 lines, truncated), MITRE technique tag, risk delta if available.
- **Empty state:** "No findings in this category."

---

### 5.14 ADUpsellBanner.tsx

- **Location:** `EngineMatrix/ADUpsellBanner.tsx`
- **Type:** Banner / call-to-action
- **Props:** None (static content)
- **Visual:** Full table-row height card (min-height: 56px, same as normal engine rows). Background: dark gradient (same as existing card gradients in `BreachLikelihood.tsx`: `linear-gradient(-170deg, #3B3544 0%, #151517 50%, #26222E 100%)`). Contains:
  - Left: "Active Directory" label + "Not assessed" badge.
  - Right: "Add on-premises AD visibility" text + "Learn more" button (links to Dela upsell page, external).
- **Constraint from UW doc:** Must NEVER be greyed out, NEVER shrunk, NEVER show a "0" sub-score. The banner must be full-weight (same visual prominence as a real engine row).

---

### 5.15 RemediationList.tsx + RemediationItem.tsx

- **Location:** `Remediation/RemediationList.tsx`, `Remediation/RemediationItem.tsx`
- **Type:** Ranked list
- **Props (RemediationList):**
  ```typescript
  type RemediationListProps = {
    items: RemediationItem[];
    currentScore: number;
  };
  ```
- **Props (RemediationItem):**
  ```typescript
  type RemediationItemProps = {
    item: RemediationItem;
    isExpanded: boolean;
    onToggle: () => void;
  };
  ```
- **Visual per item (collapsed):** Rank badge (circular number) | SeverityChip | Action title | Risk delta chip ("-N pts" in severity red) | Expand chevron.
- **Visual per item (expanded):** Adds: description paragraph, MITRE reference as MITRETag, "Paths severed" list (path IDs as badges), affected identity label, engine source label, "Score after fix: {scoreAfterFix}" stat.
- **Ordering:** Items are pre-sorted by the API (highest risk delta first). The frontend renders in received order without re-sorting.
- **States:**
  - Loading: skeleton items (3 placeholder rows).
  - Empty: "No remediation actions identified."

---

### 5.16 PostureView.tsx + Framework Panels

- **Location:** `Posture/PostureView.tsx`, `Posture/NISTCSFPanel.tsx`, `Posture/ISO27001Panel.tsx`, `Posture/EssentialEightPanel.tsx`
- **Type:** Compliance display panels
- **Ant Design base:** antd Card for each panel; antd Progress for bar indicators.
- **Props (PostureView):**
  ```typescript
  type PostureViewProps = {
    posture: PostureCompliance;
  };
  ```

**NISTCSFPanel -- NIST CSF 2.0:**
- 5 function bars: Govern, Identify, Protect, Detect, Respond.
- Each bar: antd Progress (`percent={coveragePercent}`), colored by coverage level (>=70%: green, 40-69%: yellow, <40%: red). Subcategory count shown: "{met}/{totalSubcategories} subcategories met".
- If `coveragePercent === null` or data missing: bar shows "Data unavailable" in gray text.

**ISO27001Panel -- ISO/IEC 27001:2022:**
- Sections A.5, A.6, A.7, A.8.
- Same progress bar format. If section marked "Not assessed by BLA": shows informational note rather than a bar.

**EssentialEightPanel -- Essential Eight:**
- 8 strategy rows.
- Each row: strategy name | maturity dots (4 dots: ML0 through ML3, filled up to `currentMaturityLevel`, target ring on `targetMaturityLevel`) | maturity label text.
- If `assessed === false`: row shows strategy name + "Not assessed by BLA" note. Dots are not rendered.

**States:**
- Loading: skeleton bars/dots.
- Data unavailable on individual item: "Data unavailable" label.

---

### 5.17 SeverityChip.tsx

- **Location:** `Shared/SeverityChip.tsx`
- **Type:** Badge / chip (most reused component in the system)
- **Props:**
  ```typescript
  type SeverityChipProps = {
    severity: "critical" | "high" | "medium" | "low" | "pass";
    size?: "sm" | "md" | "lg";   // default "md"
    showShape?: boolean;          // default true
    showText?: boolean;           // default true
    className?: string;
  };
  ```
- **Rendering (by severity):**
  - Critical: red background chip containing a small filled square SVG + "Critical" text.
  - High: orange background chip containing a small filled triangle SVG + "High" text.
  - Medium: yellow background chip containing a small filled circle SVG + "Medium" text.
  - Low: green background chip containing a small outline circle SVG + "Low" text.
  - Pass: gray background chip containing a small checkmark SVG + "Pass" text.
- **Rule:** `showShape` and `showText` can be false independently for special cases (e.g., compact table cells) but both must NEVER be false simultaneously -- the spec requires at minimum one non-color signal always present.
- **Accessibility:** `role="status"` or `role="img"` with `aria-label="{Severity} severity"` when used standalone.

---

### 5.18 SeverityLegend.tsx

- **Location:** `Shared/SeverityLegend.tsx`
- **Type:** Legend display
- **Props:** `className?: string`
- **Visual:** Horizontal inline list of all 4 severity levels (Critical, High, Medium, Low). Each entry: SeverityChip (shape only, no text in the chip) + label text next to it. Used in the engine matrix header and the graph area.

---

### 5.19 ViewToggle.tsx

- **Location:** `Shared/ViewToggle.tsx`
- **Type:** Segmented button
- **Ant Design base:** antd Segmented
- **Props:**
  ```typescript
  type ViewToggleProps = {
    activeView: "attack" | "posture";
    onChange: (view: "attack" | "posture") => void;
  };
  ```
- **Visual:** "Attack" | "Posture" segmented control. Active segment uses primary brand color (#1890ff or dteal from the existing codebase theme).
- **Accessibility:** `role="tablist"` semantics via antd Segmented. `aria-selected` on active option.

---

## 6. Wireframes Index

Wireframe HTML files are located at:
`/Users/eson/Documents/Dela/.AI-DOC/specs/wireframes/`

| Wireframe File | Screens Covered |
|----------------|-----------------|
| `DESIGN-001-hero-section.html` | Score ring + verdict text + KPI cluster (all 3 states: critical, low, loading) |
| `DESIGN-001-attack-graph.html` | Full attack-path graph with nodes, edges, MITRE tags, kill-chain chips, toolbar, path cycler |
| `DESIGN-001-detail-panels.html` | Node detail panel + edge detail panel + blast radius overlay |
| `DESIGN-001-engine-matrix.html` | Engine matrix (all states: normal, AD upsell, AD teaser, drill-down open) |
| `DESIGN-001-remediation-posture.html` | Remediation list (expanded + collapsed items) + Posture view (all 3 panels) |
| `DESIGN-001-pdf-pages.html` | All 10 PDF pages + appendices (static mockup) |
| `DESIGN-001-mssp-changes.html` | MSSP Reports page (before + after Threat Detection removal + v2 score display) |

---

## 7. PDF Structure -- Page-by-Page

The PDF is generated using `@react-pdf/renderer` (already in use). The attack-path graph image on Page 2 is captured via `html-to-image` from the rendered SVG, then embedded as a PNG in the PDF. Fallback: text-based step list.

**Continuing to use the same `HeaderReport` + `FooterReport` pattern** found in `MainContentV2.tsx` (Dela logo, page number, copyright line). Inter font already registered in the existing PDF code.

---

### Page 1: Cover

**Purpose:** Immediate fear/urgency at a glance for any executive.

| Element | Content | Style |
|---------|---------|-------|
| Dela logo | Top-left | Existing header pattern |
| Report title | "Entra ID Breach Likelihood Assessment" | 24pt bold |
| Organization name | `organization` field | 16pt |
| Assessment date | `assessmentDate` formatted | 12pt gray |
| Score ring (static) | Large ring with score number and risk label | 120px diameter, severity color |
| Verdict text | `verdictText` (fear-first narrative) | 14pt italic, 2-3 lines |
| TTGA hero stat | "{ttgaHops} hops to Global Admin" | 40pt bold, severity red if >0 |
| Tenant metadata row | Tenant ID, License, Number of Accounts | Small, gray, 10pt |
| "Powered by Dela Security" | Bottom | 9pt gray |

---

### Page 2: Executive Attack-Path Story

**Purpose:** Show named accounts and the chain to Global Admin. Fear-first narrative for C-suite.

| Element | Content | Style |
|---------|---------|-------|
| Section title | "How {entryNodeLabel} Becomes Your Global Administrator -- In {hopCount} Steps" | 18pt bold |
| Attack-path graph image | Static PNG render of primary path SVG | Full-width, max 400px height |
| Fallback (if image fails) | Text-based step list: Node 1 -> Edge label -> Node 2 -> ... | Monospaced, bordered box |
| Caption 1 | Step 1 description (entry node finding, named account) | 12pt |
| Caption 2 | Step 2 description (escalation mechanism, group or role name) | 12pt |
| Caption 3 | Step 3 description (Tier-0 target reached, consequences) | 12pt, severity red |
| MITRE tactic labels | Tactic IDs for each caption | 9pt badge |

**Note:** Real identity names (email, group name) are used in the heading and captions. This is intentional -- it is the "fear-first" element that makes the PDF persuasive to executives. Names come from the `nodes[].label` field in the primaryPath response.

---

### Page 3: Engine Summary Matrix

**Purpose:** Per-engine breakdown for security technical leads.

| Element | Content | Style |
|---------|---------|-------|
| Section title | "Assessment Engine Summary" | 16pt bold |
| Matrix table | Columns: Engine | Critical | High | Medium | Pass | Sub-Score | Weight | 10pt table |
| Severity chips (PDF version) | Color + shape + text + pattern fill | SVG embedded in PDF cell |
| Per-engine sparkline | 3-4 data point trend line (most recent scans) | SVG inline, 60px wide |
| MITRE tactic column | Tactic IDs covered by that engine | 8pt gray tags below engine name |
| Footnote | "Score computed using noisy-OR formula v2. Threat Detection excluded." | 8pt italic |

**Engine ordering (Threat Detection absent):**
1. Identity Hygiene
2. Platform Hygiene
3. Identity Intelligence
4. Microsoft 365
5. Active Directory (conditional: only if `adIntegrationState === "integrated"`)

---

### Pages 4-5: Per-Engine Detail Cards

**Purpose:** One card per engine with top findings, issue summary, and recommendations.

Each engine gets a card containing:

| Element | Content |
|---------|---------|
| Engine name + sub-score badge | Large heading |
| Summary paragraph | `engineEntry.summary` (from API `details[].description`) |
| Top findings list | Up to 5 findings sorted by `findingWeight` descending. Each: finding name, SeverityChip, MITRE technique ID, brief description |
| Recommendation | `engineEntry.remediation` paragraph |
| Framework tags | NIST CSF subcategory, ISO 27001 Annex A, Essential Eight mitigation -- shown as small gray tags below each finding |
| Conditional AD card | If `adIntegrationState !== "integrated"` AND this is the end of page 5, an AD upsell card is appended: same size as a normal engine card, full-weight styling. Text: "Extend your assessment to on-premises Active Directory. Dela's AD collector discovers hybrid attack paths invisible to cloud-only tools." Never greyed out, never a "0" score shown. |

---

### Page 6: Prioritized Remediation Roadmap

**Purpose:** Tell the security team exactly what to fix, in what order, and what score improvement they get.

| Element | Content |
|---------|---------|
| Section title | "Prioritized Remediation Roadmap" |
| Sub-heading | "Current score: {currentScore}. Implementing all items below reduces your score by {totalDelta} points." |
| Ranked list | Up to 10 items. Each item: rank number | action title | risk delta ("-N pts", severity red) | paths severed badges | MITRE technique | score after fix |
| Roadmap visual | Horizontal risk reduction bar: starting score, then each item's reduction plotted as a step-down bar chart. SVG embedded in PDF. |

---

### Pages 7-9: Appendix A -- Evidence

**Purpose:** Technical backup for the security engineering team.

| Element | Content |
|---------|---------|
| Appendix A header | "Appendix A: Detailed Evidence" |
| Per-engine sections | One section per engine |
| Top-5 evidence per engine | Finding name, usecaseId, evidence field (raw finding data), severity chip |
| Attack-path flag | If the finding is on the primary attack path (its edge/node is in `primaryPath`), a red "ON ATTACK PATH" badge appears next to the finding name |

---

### Page 10: Appendix B -- Framework Alignment

**Purpose:** Board-forwardable compliance evidence.

| Element | Content |
|---------|---------|
| Appendix B header | "Appendix B: Compliance Framework Alignment" |
| NIST CSF 2.0 section | One row per function (Govern, Identify, Protect, Detect, Respond) with a horizontal progress bar and met/total count |
| ISO 27001 section | One row per assessed Annex A section. Rows marked "Not assessed by BLA" show a neutral gray bar |
| Essential Eight section | One row per strategy. Maturity level shown as dot scale (ML0-ML3). "Not assessed" rows shown with gray dots |
| Footer note | "Framework alignment is derived from tagged BLA findings. Controls not covered by BLA are noted as 'Not assessed.'" |

---

### Appendix C (Conditional): Active Directory

**When `adIntegrationState === "integrated"`:** Shows the hybrid AD findings if any, and the additional attack paths that include on-premises nodes. Titled "Appendix C: Active Directory Hybrid Path Analysis."

**When `adIntegrationState !== "integrated"`:** Shows the AD upsell card. Full-weight, same visual prominence as any appendix section. Text: headline value proposition + contact CTA. NEVER shows a "0" score for AD. The word "0" and any numeric AD score must not appear on this page.

**When `adIntegrationState === "hybrid_signals_detected"`:** Shows a teaser: "Entra Connect signals detected. Your on-premises environment may introduce additional attack paths not visible in this report. Contact Dela to extend your assessment."

---

## 8. MSSP Partner Portal Changes

### 8.1 ReportsPage.tsx -- Engine Order Fix

**File:** `mssp_partner/src/pages/reports/ReportsPage.tsx`

**Change:** Remove `"Threat Detection"` from the `ENGINE_ORDER` array.

Current (line 26-32):
```
const ENGINE_ORDER = [
  "Identity Hygiene",
  "Identity Intelligence",
  "Microsoft 365",
  "Platform Hygiene",
  "Threat Detection",   // <-- REMOVE THIS
];
```

New:
```
const ENGINE_ORDER = [
  "Identity Hygiene",
  "Identity Intelligence",
  "Microsoft 365",
  "Platform Hygiene",
];
```

Additionally, remove the `THREAT_DETECTION_MAPPING` constant and the `"Threat Detection"` case from the `sanitizeEngineDetails` switch statement, since the engine is no longer present.

---

### 8.2 Score Display -- v2 Fields

**File:** `mssp_partner/src/pages/reports/ReportsPage.tsx` and any score display components.

**Changes:**
- The `RISK_LEVEL_TO_STR` and `RISK_LEVEL_TEXT` maps in `ReportsPage.tsx` (lines 34-48) currently use a 4-level scale (1=low, 2=medium, 3=high, 4=critical). The v2 API returns `riskLabel` as a pre-computed string ("Critical", "High", "Medium", "Low"). Where the MSSP portal displays a score, it should prefer the API's `riskLabel` field directly rather than mapping from a numeric `riskLevel`.
- The `riskScore` field in the v2 response is the headline score (0-100). Where the MSSP portal displays a score number, it should use `riskScore` from the v2 response. No formula change needed in the frontend.
- The `GlowCard` showing "Avg breach score" in `ReportsContent` uses `client.score` from the `useClients` hook. Once the backend is live (replacing `mockResolve()`), this field will reflect the v2 score. No UI change needed beyond ensuring the data source is the real API.

---

### 8.3 PDF Download -- BLAMainContent.tsx

**File:** `mssp_partner/src/pages/reports/pdf/BLAMainContent.tsx`

**Change:** Major rewrite to implement the same 10-page + appendix structure defined in Section 7. The component receives the same data shape as the client portal's `PDFReportRenderer.tsx`. The MSSP portal does NOT receive attack-path graph data, posture data, or remediation data in the current phase (limited to what is available from the existing MSSP download flow). For v2, the MSSP portal PDF will use the same `/portal/bl/identities` response for pages 1, 3, 4-5, and the same `/portal/bl/remediation`, `/portal/bl/attack-path`, `/portal/bl/posture` endpoints once the real API integration (MSSP-2) is complete.

The `mapDashboardToRiskInfo` function in `ReportsPage.tsx` will need to be updated to map v2 API fields (engineSubScores, kpis, verdictText, riskLabel) to the shape consumed by `BLAMainContent.tsx`.

---

## 9. Accessibility & Printing

### 9.1 Web Dashboard Accessibility

- **Keyboard navigation:** Tab order flows top-to-bottom, left-to-right through the dashboard. Score ring is not keyboard-focusable (decorative, aria-hidden=false with aria-label). KPI cards are not interactive (aria-live="polite" for when values update after AD toggle). Attack graph nodes are focusable (tabIndex=0). Detail panels trap focus while open. Toggle buttons are standard keyboard-accessible antd components.
- **ARIA requirements:**
  - Graph area: `role="img"` with descriptive `aria-label`
  - SeverityChip: `aria-label="{severity} severity"` on the wrapper
  - Detail panel: `role="dialog"`, `aria-labelledby` pointing to the entity name heading
  - Blast radius overlay: `role="dialog"`, `aria-label`
  - Path cycler: `aria-live="polite"` so screen readers announce path changes
  - Engine matrix: standard `<table>` with `<thead>` and proper column headers via `scope="col"`
  - Posture progress bars: `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-label`
- **Color contrast:** All text on colored backgrounds must meet WCAG 2.1 AA (4.5:1 for normal text, 3:1 for large text). The existing severity colors:
  - #DC2626 (Critical) on dark background #151517: passes AA for large text. Use at 14pt minimum.
  - #FFDC00 (Medium) on dark background: contrast ratio ~9:1 -- passes.
  - #52C41A (Low) on dark: passes.
  - White text on severity-colored backgrounds: check each chip in implementation.
- **Color-blind simulation:** Deuteranopia filter review required at QA (SC-011). Shape encoding (square/triangle/circle) is the primary non-color signal.

### 9.2 PDF Accessibility & B&W Printing

- **Severity encoding in PDF:** Every severity chip uses color + shape + text + pattern fill. Pattern fills are SVG-based (embedded in `@react-pdf/renderer` View elements):
  - Critical: crosshatch (two sets of diagonal lines, 3px spacing)
  - High: diagonal lines (45 degrees, 6px spacing)
  - Medium: dots (4px diameter circles, 8px grid)
  - Low: empty (no pattern)
- **Print CSS:** `@page` rule sets size to A4. The PDF is generated as a proper PDF (not print-to-PDF from browser), so browser print CSS does not apply. The `@react-pdf/renderer` output is inherently print-ready.
- **No color-only encoding anywhere in the PDF.** Every severity indicator must pass visual interpretation without color. Pattern fills make chips readable in black-and-white photocopies.
- **Font:** Inter (already registered in `MainContentV2.tsx`). Body: 10pt, section headers: 14-16pt, cover hero: 24pt. No external CDN font calls -- fonts are self-hosted via fontsource URLs that are fetched at PDF generation time.

---

## 10. Reuse Check

### Existing Components That Can Be Reused (Do Not Rebuild)

| Existing Component | Location | Reuse in BLA v2 |
|--------------------|----------|-----------------|
| `PDFDownloadLink` / `Document` / `Page` | `@react-pdf/renderer` v4.3.0 (frontend), v4.5.1 (mssp_partner) | Reused directly in new `PDFReportRenderer.tsx` |
| `HeaderReport` + `FooterReport` inner components | `MainContentV2.tsx` | Extract to shared PDF utility or copy pattern (same styling) |
| `ReportFooterImageDataString` | `frontend/src/core/utils/imageAsDataString.ts` | Reused unchanged |
| `generateHeadlessScoreTrendBase64` | `frontend/src/core/utils/generateChartInBase64.ts` | Reused for score trend chart in PDF page 3 sparklines |
| `reagraph` `<GraphCanvas>` | `reagraph` v4.21.5 | Attack-path graph rendering with `layoutType="left-right"`, `renderNode`, `renderEdge` |
| `motion` / `AnimatePresence` | `motion` v12.38.0 | Path fade transitions (PathCycler), blast radius slide-up (BlastRadiusOverlay) |
| `echarts` | `echarts` v6.1.0 | ScoreRing animated gauge |
| antd `Spin` | antd | Loading states throughout |
| antd `Drawer` | antd | Node/edge detail panels (placement="right", mask=false) |
| antd `Switch` | antd | AD integrated toggle in GraphToolbar |
| antd `Segmented` | antd | ViewToggle (Attack/Posture) |
| antd `Progress` | antd | Posture view framework bars |
| antd `Collapse` | antd | DrillDownPanel (inline expanding panel) |
| antd `Skeleton` | antd | Loading state placeholders |
| antd `Tooltip` | antd | KPI card tooltips, MITRE tag hover explanation |
| `useAuthContext` | `frontend/src/pages/auth/hooks/useAuthContext.ts` | Reused in all 4 new hooks |
| `getToken` | `frontend/src/core/utils/awsAmplifyStorage.ts` | Reused in all 4 new hooks |
| `config.API_URL` | `frontend/src/core/config/config.ts` | Reused in all 4 new hooks |
| Tailwind CSS tokens | `src/core/css/` | Reused throughout new components |
| `RiskLevelColor` | `frontend/src/core/config/constants.ts` | Referenced for severity color values (new SeverityChip will use the same hex values) |

### Existing Components Being Removed / Replaced

| Component | Location | Action |
|-----------|----------|--------|
| `BreachLikelihood.tsx` | `frontend/src/pages/dashboard/components/BreachLikelihood/` | Replaced by `BreachLikelihoodV2/index.tsx` |
| `GaugeChart.tsx` | Same directory (inferred from investigation) | Replaced by `ScoreRing.tsx` (ECharts) |
| `MainContentV2.tsx` (frontend PDF) | `ReportContent/MainContentV2.tsx` | Replaced by new 10-page structure in `PDFReportRenderer.tsx` |
| `MainContent.tsx` (frontend PDF) | `ReportContent/MainContent.tsx` | Dead code -- remove |
| `BLAMainContent.tsx` (MSSP PDF) | `mssp_partner/src/pages/reports/pdf/BLAMainContent.tsx` | Major rewrite in place |

### Components That Do Not Exist Yet (Must Be Built)

All components listed in Section 4 (Component Architecture) that are not in the Reuse Check table above do not exist in the codebase and must be built from scratch. This is the full new build for the BLA v2 feature.

---

## 11. Design Sign-Off

- [ ] Confirmed by engineer
