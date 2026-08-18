# UW-001: BLA v2 -- Attack-Path Dashboard & Scoring Redesign
**Date:** 2026-08-18
**Status:** PENDING CONFIRMATION
**Input Spec:** specs/001-bla-attack-path-dashboard/spec.md

---

## User Roles

| Role | Portal | Description |
|------|--------|-------------|
| Client IT Admin / Security Engineer | Dela Client Portal (`frontend/`) | The prospect's own IT/security team. Primary consumer of the full attack-path dashboard, KPIs, posture view, remediation list, and PDF download. |
| MSSP Partner / Dela Consultant | MSSP Partner Portal (`mssp_partner/`) | Views score summary per client, generates/downloads the BLA PDF report on behalf of each client. Does NOT see the attack-path graph, posture view, or interactive remediation list. |

---

## Trigger

A BLA scan completes for a client's Entra ID tenant. The system computes a v2 breach likelihood score and persists the scan results (findings, graph data, framework tags) to DynamoDB. The client or MSSP partner then navigates to the BLA section of their respective portal.

---

## User Stories

### Story 0 -- Fix Label Swap and Critical Bugs Before Next Demo (Priority: P0)

A Dela sales engineer runs a live demo for a prospect. The system currently swaps "High" and "Critical" labels in the 50-74 and 75-100 score bands, and several rules produce false-green results (IH005 duplicate accounts, IH008 JIT false-pass, MT011 Intune compliance, org-level rules silently passing on exception). These bugs undermine sales credibility and must ship independently of any v2 work.

**Acceptance Scenarios:**
- Given a tenant with a BLA score of 65, when the dashboard loads, then the label reads "High" (not "Critical").
- Given a tenant with a BLA score of 80, when the dashboard loads, then the label reads "Critical" (not "High").
- Given the IH005 rule encounters a renamed collector field, when the rule runs, then it returns an error state (not a pass).
- Given the IH008 rule and PIM policy data is unavailable, when the rule runs, then it returns an error state (not a pass).
- Given the MT011 rule, when counting non-compliant devices, then it uses the correct count parameter and paginates through all result pages.
- Given any of the 8 org-level Identity Hygiene rules throws an exception, when the rule runs, then it returns an error rating (not a silent pass).
- Given a CI pipeline run, when the band-to-label mapping test suite executes, then it blocks the build on any regression.

---

### Story 1 -- Client's Security Team Views the Attack Path (Priority: P1 backend graph engine, P2 frontend UI)

The client's IT admin or security engineer logs into the Dela client portal and sees the complete attack chain for their Entra ID tenant -- from a leaked admin credential or misconfigured account (entry node) through groups, roles, and privilege escalation steps to Global Admin (Tier-0 target). They can click any node or edge to understand the specific finding, its MITRE ATT&CK technique, and how much risk is removed by fixing it.

**Acceptance Scenarios:**
- Given a tenant with a Critical BLA score, when the BLA dashboard loads, then the attack path graph renders with at least one complete path from an entry node to a Tier-0 target, and the score ring animates to the current value.
- Given the graph is rendered, when the user clicks a node, then the detail panel shows: MITRE ATT&CK technique ID(s), severity, affected identity, finding description, and "Fix -> -N pts" remediation hint.
- Given the graph is rendered, when the user clicks an edge, then the detail panel shows: the exploitable relationship label, source-to-target identity names, MITRE technique, source engine, and remediation guidance.
- Given a Critical score, when the page loads, then the "Walk the path" animation auto-plays once, highlighting each node and edge in sequence order.
- Given the graph is rendered, when the user clicks "Show blast radius", then an overlay appears on the target node listing the reachable assets post-compromise (mailboxes, SharePoint, Teams, connected apps, Conditional Access).
- Given multiple paths exist to Global Admin, when the graph renders, then only the most critical path is shown by default, with a count indicator ("N more paths found") and a control to cycle through additional paths.

---

### Story 2 -- KPIs and Fear-First Verdict Text (Priority: P1)

The client's IT admin or security manager opens the Dela portal and reads the verdict at a glance: "Your tenant is three hops from Global Admin, and two admin passwords are already circulating on criminal marketplaces." They see quantified urgency without digging into technical details.

**Acceptance Scenarios:**
- Given a completed BLA scan, when the hero section renders, then it shows: overall score + label, Time to Global Admin (hops), leaked admin passwords in paths, standing Global Admin count, admins with MFA enforced count, paths to takeover count.
- Given a Critical score where TTGA = 3 and 2 leaked admin passwords exist, when the verdict text renders, then it accurately states the hop count and references the leaked credential situation.
- Given all admins have MFA enforced and no leaked credentials exist in paths, when the verdict renders, then none of the KPIs show alarm coloring.

---

### Story 3 -- AD Integration Toggle for Hybrid Path (Priority: P2)

A prospect has on-premises Active Directory connected to Entra ID via Entra Connect. The Dela agent's AD collector is deployed. The analyst enables the "AD integrated" switch and the graph expands to show the full hybrid chain.

**Acceptance Scenarios:**
- Given AD is not integrated, when the dashboard renders, then the AD engine row is replaced by an upsell banner, the graph shows only the cloud path, and AD does NOT contribute to the headline score.
- Given AD is integrated, when the user enables "AD integrated", then the graph expands to show on-prem nodes (with distinct visual encoding), the AD engine row appears in the matrix with its sub-score, and the headline recalculates to include the AD weight.
- Given hybrid signals are detected (Entra Connect present) but AD is not formally integrated, when the dashboard renders, then a teaser is shown ("Signals of on-premises AD detected -- not assessed"), not the full upsell and not a "0" AD score.
- Given AD is integrated and produces Domain Admin to Global Admin path findings, when the scan runs, then the TTGA KPI reflects the shorter hybrid path if it is fewer hops than the cloud-only path.

---

### Story 4 -- Prioritized Remediation List (Priority: P2)

The client's security engineer or IT manager reviews the remediation list in the Dela client portal and knows exactly what to fix first and how much their breach likelihood score drops with each action.

**Acceptance Scenarios:**
- Given a completed BLA scan, when the remediation panel renders, then actions are ranked highest-to-lowest risk delta.
- Given a remediation item, when the user reads it, then it shows: action title, MITRE technique reference, risk delta (minus N pts), and which attack path(s) the action severs.
- Given fixing a finding would reduce the score from 86 to 71, when the item renders, then it shows "-15 pts" and specifies the severed path endpoint.

---

### Story 5 -- Posture View (Priority: P2)

The client's security or compliance manager switches to Posture view in the Dela client portal to see how their environment maps to NIST CSF 2.0, ISO 27001, and Essential Eight -- giving them board-forwardable evidence alongside the attack-path fear narrative.

**Acceptance Scenarios:**
- Given the user clicks "Posture view", then the attack-path section hides and three compliance panels appear: NIST CSF 2.0, ISO/IEC 27001:2022 Annex A, Essential Eight.
- Given a tenant with multiple findings tagged with `nist_csf_subcategory`, when NIST CSF bars render, then each bar shows the percentage of subcategories currently met per CSF function.
- Given Essential Eight data, when the maturity panel renders, then each strategy shows ML0-ML3 dot indicators with the target level stated.
- Given the user switches back to "Attack view", then the graph and engine matrix are immediately visible without a page reload or additional network request.

---

### Story 6 -- Download Fear-First PDF Report (Priority: P2)

The MSSP partner logs into the MSSP Partner Portal, locates the client, and generates/downloads the BLA PDF report. The client can also download directly from their own Dela portal. Page 2 shows the attack path with named accounts and a headline like "How [account]@[domain] Becomes Your Global Administrator -- In 3 Steps." The C-suite can read it without technical background.

**Acceptance Scenarios:**
- Given a completed BLA scan, when the PDF is generated, then Page 2 contains a static render of the attack path graph (as an image) with a 3-step narrative naming real accounts.
- Given the PDF Page 6 renders, then it shows the prioritized remediation roadmap with risk delta per action and the path(s) each action severs.
- Given Appendix B renders, then it shows NIST CSF / ISO 27001 / Essential Eight roll-up in a board-forwardable format (no jargon, pass/fail per domain).
- Given AD is not integrated, when the PDF renders, then Appendix C shows a same-weight upsell card (never greyed out, never a "0" score, never shrunk).
- Given PDF severity chips, then every chip carries color + shape + text (no color-only encoding) for accessibility and black-and-white printing.

---

## Step-by-Step Flow

### Phase A: P0 Bug Fixes (Ship Before Next Demo)

1. Engineer fixes the label-swap mapping in the backend scoring handler (`bl_handler.py` lines 609-616 where `RiskRating` bands are assigned) and any frontend constants (`RiskLevelText` in `constants.ts`).
2. Engineer fixes IH005, IH008, MT011, and the 8 org-level IH rules to return error states on exception instead of silent pass.
3. CI regression tests are added covering band-to-label mapping and the two-tenant divergence case.
4. Changes ship independently of v2 work.

### Phase B: P1 Correctness and Tagging Prerequisites

5. IH001 MFA rule is fixed to paginate all users, use the capability flag, exclude non-registerable account types, and score by privilege level.
6. MT005/MT006/MT010 rules are corrected for absence-of-scoped-admin handling and de-duplication.
7. MT002/MT003/MT004 license checks switch to exact service-plan ID matching.
8. Privileged role detection switches to role template IDs (not display-name substring matching).
9. Every BLA check/rule receives static MITRE ATT&CK metadata (`attack.tactic_ids[]`, `attack.technique_ids[]`).
10. Every BLA finding receives framework compliance tags (`nist_csf_subcategory`, `iso27001_annex_a`, `essential8_mitigation`, `maturity_level`).
11. Live Threat Detection engine is removed from BLA scoring, engine matrix, and PDF.

### Phase C: P2 v2 Build

12. Shared retry, pagination, group-expansion helpers are consolidated (tech debt refactor).
13. v2 scoring engine replaces v1 entirely: noisy-OR per-finding formula, per-engine sub-scores, weighted headline score over connected engines only. v1 code is removed at the same release.
14. Attack-path graph engine is built: directed graph per scan, node types (User, Group, Directory Role, App Registration, Service Principal, Managed Identity, Device, Domain/DC, Certificate Template, Mailbox), edges with MITRE technique tags, reachability via reverse-BFS from Tier-0 targets capped at 4 hops.
15. Conditional-AD scoring contract is implemented: AD engine absent from engine map when not integrated; aggregator iterates only over engines that actually ran.
16. Dashboard UI is built in the client portal (`frontend/`): animated score ring, TTGA stat, KPI cluster, attack-path SVG graph, "Walk the path" animation, MITRE-tagged edges, blast radius overlay, engine matrix with drill-down, Attack/Posture toggle, AD-integrated state, prioritized remediation list.
17. PDF is redesigned per the 10-page + appendix structure: attack-path story page, remediation roadmap with risk-bought-down, framework compliance appendix, fear+visibility copy, conditional-AD display.

### Phase D: MSSP Partner Portal Updates

18. MSSP Partner Portal (`mssp_partner/`) is updated to consume the new v2 API score fields (v2 score + risk label in client list/summary view).
19. MSSP Partner Portal PDF download is updated to generate the redesigned PDF on behalf of each client.

---

## Decision Points

- **AD toggle state**: If AD is not integrated, AD engine is absent from all calculations, the graph shows only cloud paths, and the engine matrix shows an upsell banner instead of an AD row. If hybrid signals are detected but AD is not formally integrated, a teaser message is shown (not upsell, not "0").
- **Attack/Posture toggle**: Client-side state toggle. Attack view shows the graph, engine matrix, KPIs, remediation list. Posture view shows NIST CSF 2.0, ISO 27001, Essential Eight compliance panels. Switching must be under 200ms with no network round-trip.
- **Multiple paths**: The most critical path (shortest hop count, then highest cumulative risk delta) is shown by default. Additional paths are accessible via a count indicator and cycle control.
- **v2 cutover**: No shadow mode, no dual-write, no feature flag. All new scans after v2 release use v2 exclusively. Historical scan data and already-generated PDFs remain as-is (v1 artifacts). The score trend chart must annotate the v2 cutover date.

---

## Error States

| Scenario | User Experience |
|----------|----------------|
| BLA scan has not completed yet | Dashboard shows "Assessing your Entra ID for breach likelihood. Expect result in a few minutes." (current behavior preserved) |
| Zero attack paths found (no Critical or High findings) | Graph area shows an informational message: "No critical attack paths identified." KPI cluster still renders with zeroes for TTGA and leaked credentials. |
| A node/edge has no MITRE technique assigned (tagging incomplete) | Node/edge renders normally but the MITRE field in the detail panel shows "Unmapped" or is absent. The graph does not break. |
| AD is integrated but returns zero findings (clean on-prem) | AD engine row appears in the matrix with a sub-score of 0 and a "No Issues" label. The graph shows only cloud paths. Headline score includes AD weight (which contributes 0). |
| Blast radius returns no downstream resources (minimal permissions tenant) | Blast radius overlay shows "No downstream resources identified." |
| First scan (no score trend history) | Score trend chart shows a single data point. No sparklines for per-engine trends. |
| PDF attack-path graph image fails to render headlessly | PDF falls back to a table-format attack chain (text-based step list) instead of the graph image. |
| MITRE tag for a finding is missing from the static mapping table | Finding appears in the remediation list and engine matrix without a MITRE reference. A warning is logged server-side. |
| Engine matrix cell drill-down shows zero findings | Drill-down panel shows "No findings in this category." |
| Posture view engine returned an error or is not connected | Affected framework bar shows "Data unavailable" instead of a percentage. |

---

## Success Criteria

- **SC-001**: The High/Critical label swap is fixed and CI regression tests pass, blocking re-introduction. Measured by: zero label swap occurrences in automated test suite.
- **SC-002**: Two tenants with identical worst-severity findings but different total finding counts produce different v2 scores. Measured by: test case `Tenant A (1 Critical) < Tenant B (1 Critical + 500 High)`.
- **SC-003**: The headline score is fully explainable engine-by-engine: `Sum(W_e * EngineScore_e) / Sum(W_e)` matches the displayed headline. Measured by: API response includes per-engine sub-scores and weights that reproduce the headline.
- **SC-004**: Security analysts can identify the full attack chain from entry to Tier-0 within 10 seconds of page load.
- **SC-005**: Clicking any node or edge reveals accurate finding details in under 300ms.
- **SC-006**: The "Walk the path" animation traverses the attack chain in correct sequence order for all supported path configurations (cloud-only, hybrid).
- **SC-007**: The prioritized remediation list ranks correctly: items are ordered by risk delta descending, and each item's stated delta is verifiable against the v2 score formula.
- **SC-008**: Switching between Attack view and Posture view takes under 200ms (client-side state, no network round-trip).
- **SC-009**: The AD toggle updates the graph, engine matrix, and headline score within 1 second.
- **SC-010**: The PDF generates within 15 seconds and includes: attack-path story page, remediation roadmap, framework compliance appendix.
- **SC-011**: Zero color-only severity representations in either the web dashboard or the PDF -- all severity chips, graph node borders, and matrix badges carry color + shape + text. Verifiable by color-blind simulation review (Deuteranopia filter) at QA.

---

## Functional Requirements

### P0 -- Bug Fixes (Ship Before Next Demo)

- **FR-P0-001**: The system MUST correctly assign the "High" label to scores in the 50-74 range and "Critical" to scores in the 75-100 range. (DELA-BLA-1)
- **FR-P0-002**: The system MUST have automated regression tests covering the band-to-label mapping and the two-tenant divergence case. CI MUST block on failure. (DELA-BLA-2)
- **FR-P0-003**: IH005 duplicate-account rule MUST correctly identify duplicate accounts; MUST NOT pass on every tenant due to a renamed collector field. MUST be gated from sales builds until fixed. (DELA-BLA-3)
- **FR-P0-004**: IH008 JIT-activation rule MUST NOT mark users as compliant when PIM policy data is unavailable. MUST return an explicit error state, not a pass. (DELA-BLA-4)
- **FR-P0-005**: MT011 Intune compliance rule MUST correctly count non-compliant devices using the correct count parameter and MUST paginate through all pages. (DELA-BLA-5)
- **FR-P0-006**: All 8 org-level Identity Hygiene rules MUST return an error rating on exception -- an empty result on exception MUST NOT be treated as "Pass". (DELA-BLA-6)

### P1 -- Correctness, MITRE Tagging, Framework Tags

- **FR-P1-001**: IH001 MFA rule MUST paginate through all users, use the capability flag, exclude account types that cannot register MFA, and score by privilege level. (DELA-BLA-7)
- **FR-P1-002**: MT005/MT006/MT010 rules MUST treat absence of scoped admin roles as a low-severity delegation gap. Assignments MUST be counted across direct + group + eligible and de-duplicated. (DELA-BLA-8)
- **FR-P1-003**: MT002/MT003/MT004 license checks MUST use exact service-plan ID matching. (DELA-BLA-9)
- **FR-P1-004**: Every BLA check/rule MUST carry static MITRE ATT&CK metadata: `attack.tactic_ids[]` and `attack.technique_ids[]`. Gate for attack-path graph. (DELA-BLA-10)
- **FR-P1-005**: Every BLA finding MUST carry framework compliance tags: `nist_csf_subcategory`, `iso27001_annex_a`, `essential8_mitigation`, `maturity_level`. Gate for posture view. (DELA-BLA-11)
- **FR-P1-006**: Live Threat Detection MUST be removed from BLA scoring, engine matrix, and PDF. (DELA-BLA-12)
- **FR-P1-007**: Privileged role detection MUST use role template IDs, not display-name substring matching. (DELA-BLA-13)

### P2 -- v2 Build

- **FR-P2-001**: Shared retry, pagination, group-expansion helpers MUST be consolidated before per-rule v2 fixes begin. (DELA-BLA-14)
- **FR-P2-002**: The v2 scoring engine MUST replace v1 entirely. No shadow mode, no dual-write, no feature flag. v1 code removed at same release. (DELA-BLA-15)
- **FR-P2-003**: Per-finding weight: `r_f = S(f) * X(f) * B(f) * (1 + P(f))`, capped at 0.95. (DELA-BLA-15)
- **FR-P2-004**: Per-engine sub-score: `EngineScore_e = 100 * [1 - Product(1 - r_f)]` (noisy-OR). Finding count per severity band capped at 50 for score contribution. (DELA-BLA-15)
- **FR-P2-005**: Headline score: `Headline = Sum(W_e * EngineScore_e) / Sum(W_e)` over connected engines only. Weights: IH=25, PH=20, II=20, M365=15, AD=25 (conditional). (DELA-BLA-15)
- **FR-P2-006**: Attack-path graph engine MUST build a directed graph per scan. Node types: User, Group, Directory Role, App Registration, Service Principal, Managed Identity, Device, Domain/DC, Certificate Template, Mailbox. (DELA-BLA-16)
- **FR-P2-007**: Edge types MUST each carry a MITRE technique tag (enumerated in spec). (DELA-BLA-16)
- **FR-P2-008**: Reachability via reverse-BFS from Tier-0 targets, capped at 4 hops. Confirmed path sets Reachability factor P(f) for every edge on that path. (DELA-BLA-16)
- **FR-P2-008a**: Graph displays single most critical path by default (shortest hop count, then highest cumulative risk delta). Count indicator and cycle control for additional paths. (DELA-BLA-16)
- **FR-P2-009**: When AD is not integrated, AD engine MUST be absent from engine map entirely (not null, not zero, not error). Aggregator iterates only over engines that actually ran. UI MUST never render "0" for AD. (DELA-BLA-17)
- **FR-P2-010**: Each assessment MUST be versioned with engines active at scan time, so historical PDFs remain reproducible. (DELA-BLA-17)
- **FR-P2-011**: Dashboard UI MUST implement the attack-path design: animated score ring, TTGA stat, Walk-the-path animation, MITRE-tagged edges, blast radius overlay, Attack/Posture toggle, AD-integrated state. (DELA-BLA-18)
- **FR-P2-012**: PDF MUST be redesigned per the 10-page + appendix structure. (DELA-BLA-19)
- **FR-P2-013**: Every severity representation MUST encode severity using color + shape + text. Canonical encoding: Critical=filled square, High=filled triangle, Medium=filled circle, Low=outline circle. PDF charts MUST additionally include pattern fills for B&W printing. (DELA-BLA-18, DELA-BLA-19)

---

## Out of Scope

- **Live Threat Detection**: Entirely removed from BLA. Reserved for the paid continuous-monitoring product. Per CEO decision, no partial inclusion.
- **New Microsoft Graph API calls or scopes**: The attack-path graph and blast radius are derived entirely from existing DynamoDB scan data. No new Graph API calls, no new scopes, no re-consent required.
- **Historical data recomputation**: v2 score changes affect new scans only. Historical scan records and already-generated PDFs remain as v1 artifacts and are not recomputed.
- **Shadow mode / dual-write / feature flags**: v2 replaces v1 directly. No gradual rollout mechanism.
- **MSSP Partner Portal attack-path graph**: The MSSP portal does NOT get the interactive attack-path graph, posture view, or remediation list. Those are client-portal-only features. MSSP scope is limited to v2 score display and PDF download.
- **Admin Dashboard**: No BLA changes scoped for the admin dashboard in this feature.
- **On-premises AD data collection**: AD collector output format investigation is a prerequisite but the actual AD data collection pipeline is not part of this feature's build scope.

---

## Constraints and Assumptions

- The existing BL assessment pipeline produces per-finding structured data sufficient to build the attack-path graph without a new data collection pass.
- The MITRE technique IDs in the spec are accurate and will form the basis of the static mapping table (DELA-BLA-10).
- Historical PDFs are immutable.
- Risk-bought-down delta values require a formal definition (delivered as part of DELA-BLA-15 spec work) before display.
- Blast radius is populated entirely from existing tenant metadata in DynamoDB.
- The score trend chart MUST annotate the v2 cutover date so score jumps are explained to clients.
- Sales and CS teams MUST be briefed before v2 ships (no gradual rollout = hard cutover).
- The `BLA-report-client.html` files in `/docs/` represent the client-facing BLA dashboard reference design.

---

## Investigation Findings (Current State)

### Backend
- **Scoring logic**: Lives in `backend/src/aws/lambdas/bl_handler.py` function `bl_update_risk_info_handler()` (lines 544-676). Current v1 scoring: takes the highest-score result per category, assigns `riskRating` based on score thresholds (>=95 Critical, 62-94 High, 31-61 Medium, <31 Low), then computes an overall `riskScore` using a formula that maps to 0-100 with a floor of 76 if any category hits Critical. This is the code that must be entirely replaced by the noisy-OR v2 formula.
- **Risk rating enum**: `RiskRating` IntEnum in `bl_handler.py` -- CRITICAL=5, HIGH=4, MEDIUM=3, LOW=2, NORISK=1. Current label assignment at lines 609-616 uses bands 76-100=CRITICAL, 51-75=HIGH, 26-50=MEDIUM, else LOW. The spec confirms this is correct but the bug is likely in how these map to display labels downstream.
- **BL API**: Single endpoint `GET /portal/bl/identities` returns the entire `BLRiskInfo` record for the org. Returns fields: `riskScore`, `riskLevel` (int), `description`, `organization`, `tenant`, `assessmentDate`, `poweredBy`, `remediationActions`, `details[]` (each with `name`, `easeOfExploit`, `impact`, `exposure`, `description`, `remediation`, `riskRating`, `evidence`). No per-engine sub-scores, no MITRE tags, no graph data, no framework tags.
- **BL rules**: Located in `backend/src/bl_rules/identities/` and `backend/src/bl_rules/identities_app/`. Each rule has a `TASK_META` dict and a `run(ctx)` function. Rules currently produce: `category`, `usecase`, `usecaseId`, `score` (easeOfExploit * impact * exposure), `status` (Pass/Fail/Error), `remediation`, `message`, `description`, `evidence`. No MITRE tags, no framework tags.
- **DynamoDB tables involved**: `BLRiskInfo-{stage}` (final aggregated score), `BLResult-{stage}` (per-rule scan results), `BLUserInfo-{stage}` (user identity data), `BLAppsInfo-{stage}` (app registration data).
- **New endpoints needed**: `GET /portal/bl/attack-path`, `GET /portal/bl/remediation`, `GET /portal/bl/posture`, and the existing `/portal/bl/identities` must be updated with per-engine sub-scores, weights, and verdict text.

### Frontend (Client Portal)
- **Current BLA component**: `frontend/src/pages/dashboard/components/BreachLikelihood/BreachLikelihood.tsx` -- displays risk score, risk label (using `RiskLevelText` map), tenant metadata (tenant, organization, domain, license, assessment date, user count), and a "Score Breakdown" table with columns: name, easeOfExploit, impact, exposure.
- **Current gauge**: `GaugeChart.tsx` -- uses Chart.js Doughnut (half-circle), static, no animation.
- **Current PDF**: `PDFReportRenderer.tsx` uses `@react-pdf/renderer` with `MainContentV2` component. Fetches score trend data for chart. Current PDF structure does not include attack-path story, remediation roadmap, or framework compliance.
- **Dashboard routing**: `DashboardV3.tsx` is the active dashboard (confirmed via investigation). Fetches from `/portal/new-dashboard`.
- **Type system**: `RiskInfoType` and `RiskDetailType` in `core/types/CommonTypes.ts` must be significantly extended for v2 data (sub-scores, graph data, KPIs, etc.).
- **Constants**: `RiskLevelText` map in `constants.ts` maps numeric levels to labels (1=No Issue, 2=Low, 3=Medium, 4=High, 5=Critical). `RiskLevelColor` provides styling per label.
- **No existing attack-path graph component**: The `attack-path-analysis/` page exists but uses Sigma.js for a different feature (APA, not BLA). BLA attack-path graph will be a new SVG-based component.

### MSSP Partner Portal
- **Reports page**: `mssp_partner/src/pages/reports/ReportsPage.tsx` -- includes `ENGINE_ORDER` list (Identity Hygiene, Identity Intelligence, Microsoft 365, Platform Hygiene, Threat Detection). Threat Detection must be removed. PDF components are in `mssp_partner/src/pages/reports/pdf/`.
- **BLA PDF**: `BLAMainContent.tsx` -- current PDF layout with engine types, severity mapping, header/footer. Must be redesigned for v2 structure.
- **Score display**: Uses `RISK_LEVEL_TO_STR` (1=low, 2=medium, 3=high, 4=critical) and `RISK_LEVEL_TEXT` (1=No Issue, 2=Low, 3=Medium, 4=High, 5=Critical). These must consume v2 score fields.
- **No backend yet**: MSSP partner portal currently uses mock/seed data (`mockResolve()`). Will need to consume real backend API for v2 score and PDF generation.

---

## Confirmation
- [ ] Confirmed by engineer
