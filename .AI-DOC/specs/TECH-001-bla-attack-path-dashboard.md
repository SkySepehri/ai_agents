# TECH-001: BLA v2 -- Attack-Path Dashboard & Scoring Redesign

**Date:** 2026-08-18
**References:** UW-001-bla-attack-path-dashboard.md
**Input Spec:** specs/001-bla-attack-path-dashboard/spec.md
**Status:** APPROVED

---

## 1. Affected Sources

### Backend (`backend/`)

| File / Directory | Change Type | Scope |
|-----------------|-------------|-------|
| `src/aws/lambdas/bl_handler.py` | **Major rewrite** | `bl_update_risk_info_handler()` replaced entirely with v2 scoring engine; graph engine added; new SQS consumer for graph compute |
| `src/bl_rules/identities/*.py` | **Modified** | Every rule receives `attack` (MITRE) and `framework` (NIST/ISO/E8) static metadata in `TASK_META`; error-on-exception enforcement |
| `src/bl_rules/identities_app/*.py` | **Modified** | Same MITRE + framework tagging |
| `src/ih_rules/org_rules/*.py` | **Modified (P0)** | 8 org-level rules: exception handling changed from `return []` to error state |
| `src/ih_rules/org_rules/ih_check_just_in_time_for_priviledge_users.py` | **Bug fix (P0)** | IH008: return error state when PIM data unavailable |
| `src/ih_rules/user_rules/ih_check_mfa_coverage.py` (or equivalent BL MFA rule) | **Bug fix (P1)** | IH001: pagination, capability flag, privilege-level scoring |
| `src/m365_rules/MT011_intune_device_compliance.py` | **Bug fix (P0)** | Correct count variable + pagination fix |
| `src/m365_rules/MT005*.py`, `MT006*.py`, `MT010*.py` | **Bug fix (P1)** | Severity direction + de-duplication |
| `src/m365_rules/MT002*.py`, `MT003*.py`, `MT004*.py` | **Bug fix (P1)** | Service-plan ID matching |
| `src/portal/bl/bl_routers.py` | **Extended** | Existing `/identities` updated; 3 new endpoints added |
| `src/aws/lambdas/utils/ih/enum.py` | **No change** | `RiskRating` IntEnum stays as-is |
| `src/aws/lambdas/bl_graph_engine.py` | **New file** | Attack-path graph builder + reverse-BFS pathfinder |
| `src/aws/lambdas/bl_scoring_v2.py` | **New file** | v2 scoring functions (noisy-OR, per-finding weight, headline aggregation) |
| `src/bl_rules/mitre_mapping.py` | **New file** | Static MITRE ATT&CK mapping table (check ID -> tactic/technique IDs) |
| `src/bl_rules/framework_mapping.py` | **New file** | Static framework tag mapping table (check ID -> NIST/ISO/E8 tags) |
| `src/bl_rules/shared_helpers.py` | **New file** | Consolidated retry, pagination, group-expansion, consumer-domain helpers |
| `src/bl_rules/role_template_ids.py` | **New file** | Privileged role template ID constants (replaces display-name matching) |
| `serverless.yml` | **Modified** | New DynamoDB table (`BLAttackGraph`), new Lambda for graph compute, IAM permissions |

### Frontend -- Client Portal (`frontend/`)

| File / Directory | Change Type | Scope |
|-----------------|-------------|-------|
| `src/pages/dashboard/components/BreachLikelihood/BreachLikelihood.tsx` | **Major rewrite** | Replaced with v2 dashboard: hero, KPIs, graph, matrix, remediation, posture toggle |
| `src/pages/dashboard/components/BreachLikelihood/GaugeChart.tsx` | **Replaced** | Static half-circle gauge replaced with animated ring gauge |
| `src/pages/dashboard/components/BreachLikelihood/` | **New components** | `AttackPathGraph.tsx`, `EngineMatrix.tsx`, `RemediationList.tsx`, `PostureView.tsx`, `KPICluster.tsx`, `ScoreRing.tsx`, `BlastRadiusOverlay.tsx`, `SeverityChip.tsx`, `VerdictText.tsx` |
| `src/core/types/CommonTypes.ts` | **Extended** | New types: `RiskInfoTypeV2`, `AttackPathData`, `AttackNode`, `AttackEdge`, `EngineSubScore`, `RemediationItem`, `PostureCompliance`, `AttackKPIs`, `BlastRadius` |
| `src/core/constants/constants.ts` | **Modified** | Label-swap fix (P0); severity shape/color map added |
| `src/pages/dashboard/components/BreachLikelihood/PDFReportRenderer.tsx` | **Major rewrite** | 10-page + appendix PDF structure |
| `src/core/routes/routes.tsx` | **No change expected** | BLA is already part of the dashboard route |
| `src/core/config/authorization.ts` | **No change expected** | Existing roles already have dashboard access |

### MSSP Partner Portal (`mssp_partner/`)

| File / Directory | Change Type | Scope |
|-----------------|-------------|-------|
| `src/pages/reports/ReportsPage.tsx` | **Modified** | Remove "Threat Detection" from `ENGINE_ORDER`; consume v2 score fields |
| `src/pages/reports/pdf/BLAMainContent.tsx` | **Major rewrite** | Redesigned PDF per v2 structure |
| Score constants files | **Modified** | `RISK_LEVEL_TO_STR`, `RISK_LEVEL_TEXT` updated if needed; consume v2 sub-scores |

---

## 2. Technical Approach

### 2.1 v2 Scoring Engine

**Rationale:** The v1 formula discards all findings below the worst severity level, making finding count cosmetic. Two tenants with vastly different exposure produce identical scores. The noisy-OR model is monotonic (more findings always raise the score), decomposable (each engine's contribution is independently verifiable), and gives every finding a voice.

**Design:**

1. **Per-finding weight** -- computed at scan time, stored on each finding record in `BLResult`:
   ```
   r_f = S(f) * X(f) * B(f) * (1 + P(f))   capped at 0.95
   ```
   Where:
   - `S(f)` = severity base rate: Critical=0.60, High=0.30, Medium=0.12, Low=0.03
   - `X(f)` = exploitability multiplier [0.6 - 1.4], derived from rule's `easeOfExploit` field (normalized from current 1-5 scale)
   - `B(f)` = blast radius multiplier [0.4 - 1.8], derived from rule's `impact` field (normalized from current 1-5 scale)
   - `P(f)` = reachability premium [0 - 1.2], set by the graph engine if the finding's edge/node lies on a confirmed path to Tier-0

2. **Per-engine sub-score** -- computed from all findings tagged to that engine:
   ```
   EngineScore_e = 100 * [1 - Product(1 - r_f)]   for all findings in engine e
   ```
   Finding count per severity band is capped at 50 for score contribution (additional findings still display in the UI but do not further raise the engine score).

3. **Headline score** -- weighted average over connected engines only:
   ```
   Headline = Sum(W_e * EngineScore_e) / Sum(W_e)
   ```
   Engine weights: IH=25, PH=20, II=20, M365=15, AD=25 (conditional -- absent when AD not integrated).

4. **Label assignment** (fixed):
   - 75-100 = Critical
   - 50-74 = High
   - 25-49 = Medium
   - 0-24 = Low

**Implementation:** New module `backend/src/aws/lambdas/bl_scoring_v2.py` containing pure functions:
- `compute_finding_weight(severity, ease_of_exploit, impact, reachability_premium) -> float`
- `compute_engine_score(finding_weights: list[float], severity_cap=50) -> float`
- `compute_headline_score(engine_scores: dict[str, float], engine_weights: dict[str, int]) -> float`
- `assign_risk_label(headline_score: int) -> RiskRating`

These are pure, stateless functions with comprehensive unit tests. The handler (`bl_update_risk_info_handler`) orchestrates: read all findings, call scoring functions, call graph engine, persist results.

**v1 removal:** The entire scoring block in `bl_handler.py` lines 565-616 is deleted at the same release as v2. No feature flag.

### 2.2 Attack-Path Graph Engine

**Rationale:** The attack path is the primary fear/visibility artifact. It must be computed at scan time (not on-demand) because: (a) it feeds the reachability premium `P(f)` back into scoring, and (b) on-demand computation would add unacceptable latency to the dashboard API.

**Design:**

1. **Graph construction** -- New module `backend/src/aws/lambdas/bl_graph_engine.py`:
   - Reads all findings from `BLResult`, `IHResults`, and `M365Result` for the org+DC
   - Builds an in-memory directed graph with typed nodes and edges
   - **Node types:** User, Group, DirectoryRole, AppRegistration, ServicePrincipal, ManagedIdentity, Device, DomainDC, CertificateTemplate, Mailbox
   - **Edge types** with MITRE tags (from `mitre_mapping.py`): MemberOf (T1078.004), HasRole (T1078.004), CanAddCredential (T1098.001), OwnsApp (T1098.001), GrantsHighRiskPermission (T1098.003), LeakedCredential (T1589.001), GenericAll/WriteDACL/ForceChangePassword (T1098), ADCS ESC1-ESC8 (T1649), FederatesWith (T1606.002)

2. **Pathfinding** -- Reverse-BFS from Tier-0 targets:
   - Tier-0 targets: Global Admin members, Domain Admins, PKI CAs, hybrid-sync accounts
   - BFS traverses edges in reverse direction (from target back to entry points)
   - Capped at 4 hops maximum
   - Each confirmed path sets `P(f)` on every edge in that path
   - Paths ranked: shortest hop count first, then highest cumulative risk delta

3. **KPI extraction** from the graph:
   - `ttga_hops`: minimum hop count across all confirmed paths
   - `leaked_admin_passwords`: count of LeakedCredential edges where the source node has a privileged role
   - `standing_global_admins`: count of User nodes with active (not PIM-eligible) Global Admin role
   - `admins_with_mfa`: count of admin User nodes with MFA enforced (from IH findings)
   - `paths_to_takeover`: total distinct path count

4. **Blast radius** -- for each Tier-0 target node:
   - Derived from existing DynamoDB data (no new Graph API calls)
   - User count -> mailbox count
   - M365 configuration -> SharePoint sites, Teams
   - App registrations -> connected third-party apps
   - Conditional Access policies -> scope of enforcement gaps

5. **Output:** Serialized as JSON, stored in `BLAttackGraph` DynamoDB table (see Section 4).

### 2.3 Aggregator Cross-Table Read Pattern

**Problem:** BLA findings are in `BLResult`, but IH findings are in `IHResults` and M365 findings are in `M365Result`. The v2 aggregator must read all three tables to build the complete graph and score.

**Solution:** The `bl_update_risk_info_handler` Lambda already runs after the BL scan completes. It will be extended to:
1. Query `BLResult-{stage}` for BL rule findings (partition: orgId, sort: begins_with(dcId))
2. Query `IHResults-{stage}` for IH rule findings (same key pattern)
3. Query `M365Result-{stage}` for M365 rule findings (partition: orgId, sort: begins_with(dcId))
4. Merge all findings into a unified list with normalized schema
5. Feed the unified list into the scoring engine and graph engine

**Execution order guarantee:** BLA scan is triggered last (after IH and M365 scans complete). This is already the case in the current pipeline -- `bl_update_risk_info_handler` is invoked via SQS after all BL rules finish. The handler must verify IH and M365 results exist for the DC before proceeding; if missing, it logs a warning and scores with available data only.

### 2.4 Multi-DC Organization Handling

**Problem:** `bl_routers.py` currently returns `bl_risk_info[0]` -- only the first `BLRiskInfo` record. Organizations with multiple Entra ID tenants will have multiple records.

**Solution:** The API will continue to return a single consolidated record per org. The scoring handler will aggregate across all DCs for the org at compute time (it already queries by `orgId`). The `BLRiskInfo` record uses `orgId` as the partition key with no sort key -- there is one record per org, not per DC. Each DC's findings contribute to the single org-level score. This is confirmed by the DynamoDB schema: `BLRiskInfo` has only `orgId` as the hash key.

If multiple Entra ID tenants exist, the graph engine builds a unified graph across all of them (a user in Tenant A with a path to Global Admin in Tenant B via cross-tenant trust is a valid attack path). Per-DC breakdowns are available via the engine matrix drill-down.

### 2.5 Frontend Dashboard Architecture

**Rationale:** The BLA section of the dashboard is a self-contained feature module within the existing `DashboardV3` page. It does not require new routes or layout changes.

**Design:**

The BreachLikelihood component tree becomes:

```
BreachLikelihoodV2/
  index.tsx                    -- Container: fetches data, manages Attack/Posture toggle state
  components/
    HeroSection/
      ScoreRing.tsx            -- ECharts animated ring gauge (replaces Chart.js Doughnut)
      VerdictText.tsx          -- Fear-first narrative generator
      KPICluster.tsx           -- 5 KPI stat cards (TTGA, leaked passwords, standing GAs, MFA, paths)
    AttackPath/
      AttackPathGraph.tsx      -- SVG-based directed graph renderer (D3.js for layout, React for rendering)
      AttackNode.tsx           -- Individual node component (shape encodes type, border encodes severity)
      AttackEdge.tsx           -- Edge with MITRE label, hot-path highlighting
      NodeDetailPanel.tsx      -- Right-side detail panel (MITRE tags, severity, fix hint, risk delta)
      EdgeDetailPanel.tsx      -- Right-side edge detail panel
      WalkAnimation.tsx        -- Step-by-step path animation controller
      BlastRadiusOverlay.tsx   -- Overlay showing downstream assets
      PathCycler.tsx           -- "N more paths" indicator + cycle control
    EngineMatrix/
      EngineMatrix.tsx         -- Severity count grid with sub-scores
      EngineMatrixRow.tsx      -- Per-engine row
      DrillDownPanel.tsx       -- Finding list on cell click
      ADUpsellBanner.tsx       -- Shown when AD is not integrated
    Remediation/
      RemediationList.tsx      -- Ranked remediation items with risk delta
      RemediationItem.tsx      -- Individual item card
    Posture/
      PostureView.tsx          -- Container for all three framework panels
      NISTCSFPanel.tsx         -- NIST CSF 2.0 progress bars per function
      ISO27001Panel.tsx        -- ISO 27001 Annex A progress bars
      EssentialEightPanel.tsx  -- Essential Eight maturity dots
    Shared/
      SeverityChip.tsx         -- Color + shape + text severity badge (Critical=square, High=triangle, etc.)
      SeverityLegend.tsx       -- Inline legend for severity encoding
  hooks/
    useBreachLikelihood.ts     -- react-query hook for GET /portal/bl/identities (v2)
    useAttackPath.ts           -- react-query hook for GET /portal/bl/attack-path
    useRemediation.ts          -- react-query hook for GET /portal/bl/remediation
    usePosture.ts              -- react-query hook for GET /portal/bl/posture
  types/
    bla-types.ts               -- All BLA v2 TypeScript types (mirrors API contracts)
```

**Key decisions:**
- **Graph renderer: D3.js for layout, React SVG for rendering** -- not Sigma.js (which is used for the separate APA feature). D3 provides the dagre layout algorithm for directed graphs; React handles SVG node/edge rendering for interactivity. This avoids a canvas dependency and enables CSS-based animations.
- **Attack/Posture toggle**: Client-side state only. Both views' data is fetched on mount. Toggling swaps which component tree renders -- no network round-trip (SC-008: <200ms).
- **Animation**: `requestAnimationFrame`-based for "Walk the path". Auto-plays once on load when score is Critical. User can replay via button.
- **Chart library**: ECharts for the animated ring gauge (per the codebase CLAUDE.md recommendation of Chart.js or ECharts). ECharts provides built-in count-up animation and ring gauge type.

### 2.6 PDF Redesign

**Rationale:** The PDF is a leave-behind for C-suite. It must lead with fear (attack path story) and close with credibility (framework compliance).

**Structure (10 pages + appendices):**

| Page | Content | Data Source |
|------|---------|-------------|
| 1 | Cover: score ring, risk label, TTGA hops, tenant metadata, verdict text | `/portal/bl/identities` |
| 2 | Executive Attack-Path Story: static SVG-to-image render of primary path + 3-caption narrative | `/portal/bl/attack-path` |
| 3 | Engine Summary Matrix: severity counts per engine + per-engine sparklines | `/portal/bl/identities` |
| 4-5 | Per-engine detail cards: issue/recommendation with MITRE + framework tags; AD card conditional | `/portal/bl/identities` |
| 6 | Prioritized Remediation Roadmap: ranked actions with risk delta + paths severed | `/portal/bl/remediation` |
| 7-9 | Appendix A: Top-5 evidence per engine (existing); flag items on attack path | `/portal/bl/identities` |
| 10 | Appendix B: Framework alignment (NIST CSF / ISO 27001 / Essential Eight) | `/portal/bl/posture` |
| Conditional | Appendix C: AD hybrid path (findings if integrated; full-weight upsell card if not) | `/portal/bl/attack-path` |

**Implementation:** Continue using `@react-pdf/renderer` (already in use). The attack-path graph on Page 2 is rendered as an SVG, converted to a PNG image via `html-to-image` or equivalent, then embedded in the PDF. Fallback: if headless render fails, a text-based step list replaces the graph image.

**Severity encoding in PDF:** Every chip uses color + shape + text + pattern fill (for B&W printing). Pattern fills: Critical=crosshatch, High=diagonal lines, Medium=dots, Low=empty.

### 2.7 MSSP Partner Portal Updates

**Scope is intentionally limited:**
1. Remove "Threat Detection" from `ENGINE_ORDER` in `ReportsPage.tsx`
2. Consume v2 score fields (`riskScore`, `riskLevel`, per-engine sub-scores) from the real API (replace `mockResolve()` calls)
3. Update `BLAMainContent.tsx` to render the v2 PDF structure (same 10-page + appendix layout)
4. No attack-path graph, no posture view, no remediation list in the MSSP portal UI

---

## 3. API Contracts

All endpoints require JWT authentication via AWS Cognito. Allowed roles: `SECURITY_MANAGER`, `SECURITY_ENGINEER`, `SOC_ANALYST`, `TRIAL_USER`.

### 3.1 GET `/portal/bl/identities` (Updated)

Returns the consolidated BLA v2 score, per-engine sub-scores, KPIs, verdict text, and engine details for the authenticated user's organization.

**Request:**
```
GET /portal/bl/identities
Authorization: Bearer <JWT>
```

No query parameters required (page/size params from v1 are removed -- this endpoint returns a single org-level record, not a paginated list).

**Response (200):**
```json
{
  "orgId": "string",
  "domainControllerId": "string",
  "organization": "string",
  "tenant": "string",
  "domainName": "string",
  "license": "string",
  "numberOfAccounts": 0,
  "assessmentDate": "2026-08-18T00:00:00Z",
  "poweredBy": "Dela Security",
  "scoringModelVersion": "v2",

  "riskScore": 82,
  "riskLevel": 5,
  "riskLabel": "Critical",
  "verdictText": "Your tenant is 3 hops from full takeover. 2 admin passwords are already circulating on criminal marketplaces.",

  "engineSubScores": [
    {
      "engineId": "identity_hygiene",
      "engineName": "Identity Hygiene",
      "subScore": 78,
      "weight": 25,
      "criticalCount": 3,
      "highCount": 12,
      "mediumCount": 8,
      "passCount": 5,
      "isConditional": false
    },
    {
      "engineId": "platform_hygiene",
      "engineName": "Platform Hygiene",
      "subScore": 65,
      "weight": 20,
      "criticalCount": 1,
      "highCount": 7,
      "mediumCount": 15,
      "passCount": 10,
      "isConditional": false
    },
    {
      "engineId": "identity_intelligence",
      "engineName": "Identity Intelligence",
      "subScore": 90,
      "weight": 20,
      "criticalCount": 5,
      "highCount": 20,
      "mediumCount": 3,
      "passCount": 2,
      "isConditional": false
    },
    {
      "engineId": "microsoft_365",
      "engineName": "Microsoft 365",
      "subScore": 45,
      "weight": 15,
      "criticalCount": 0,
      "highCount": 5,
      "mediumCount": 12,
      "passCount": 20,
      "isConditional": false
    }
  ],

  "enginesActive": ["identity_hygiene", "platform_hygiene", "identity_intelligence", "microsoft_365"],

  "kpis": {
    "ttgaHops": 3,
    "leakedAdminPasswords": 2,
    "standingGlobalAdmins": 4,
    "adminsWithMfa": 18,
    "pathsToTakeover": 5
  },

  "details": [
    {
      "name": "string",
      "usecaseId": "BL007",
      "engineId": "identity_hygiene",
      "easeOfExploit": 3,
      "impact": 4,
      "exposure": 2,
      "description": "string",
      "remediation": "string",
      "riskRating": 5,
      "evidence": "string",
      "findingWeight": 0.72,
      "attack": {
        "tacticIds": ["TA0004"],
        "techniqueIds": ["T1078.004"]
      },
      "framework": {
        "nistCsfSubcategory": "PR.AC-1",
        "iso27001AnnexA": "A.9.2.3",
        "essential8Mitigation": "Restrict administrative privileges",
        "maturityLevel": 1
      }
    }
  ],

  "scoreTrend": [
    {
      "date": "2026-08-01T00:00:00Z",
      "score": 75,
      "scoringModelVersion": "v1"
    },
    {
      "date": "2026-08-18T00:00:00Z",
      "score": 82,
      "scoringModelVersion": "v2"
    }
  ],

  "adIntegrationState": "not_integrated",
  "hybridSignalsDetected": false
}
```

**`adIntegrationState` enum values:**
- `"integrated"` -- AD collector deployed, findings available, AD engine in `enginesActive`
- `"not_integrated"` -- No AD collector; show upsell banner
- `"hybrid_signals_detected"` -- Entra Connect present but AD not formally integrated; show teaser

**Error Responses:**
- `401` -- Missing or invalid JWT
- `403` -- User role not authorized
- `404` -- No BLRiskInfo record found (scan not yet run); body: `{"detail": "No BLA assessment found for this organization."}`
- `500` -- Internal server error

### 3.2 GET `/portal/bl/attack-path` (New)

Returns the attack-path graph data for the authenticated user's organization.

**Request:**
```
GET /portal/bl/attack-path
Authorization: Bearer <JWT>
```

**Response (200):**
```json
{
  "orgId": "string",
  "assessmentDate": "2026-08-18T00:00:00Z",
  "totalPathCount": 5,

  "primaryPath": {
    "pathId": "path-001",
    "hopCount": 3,
    "cumulativeRiskDelta": 28.5,
    "nodes": [
      {
        "id": "node-001",
        "type": "user",
        "label": "admin@contoso.com",
        "subLabel": "Cloud Application Administrator",
        "stageLabel": "INITIAL ACCESS",
        "severity": "critical",
        "engineId": "identity_intelligence",
        "detail": {
          "description": "Leaked credential found on dark web marketplace",
          "fixText": "Reset password and enable phishing-resistant MFA",
          "riskDelta": 12.3,
          "attack": {
            "tacticIds": ["TA0001"],
            "techniqueIds": ["T1589.001"]
          }
        }
      },
      {
        "id": "node-002",
        "type": "group",
        "label": "IT-Admins",
        "subLabel": "Security Group (42 members)",
        "stageLabel": "PRIVILEGE ESCALATION",
        "severity": "high",
        "engineId": "identity_hygiene",
        "detail": {
          "description": "Nested group grants transitive Global Admin access",
          "fixText": "Remove nested admin group membership",
          "riskDelta": 8.1,
          "attack": {
            "tacticIds": ["TA0004"],
            "techniqueIds": ["T1078.004"]
          }
        }
      },
      {
        "id": "node-003",
        "type": "directory_role",
        "label": "Global Administrator",
        "subLabel": "Tier-0 Target",
        "stageLabel": "TAKEOVER",
        "severity": "critical",
        "engineId": "identity_hygiene",
        "detail": {
          "description": "Full tenant control achieved",
          "fixText": null,
          "riskDelta": 0,
          "attack": {
            "tacticIds": ["TA0004"],
            "techniqueIds": ["T1078.004"]
          }
        }
      }
    ],
    "edges": [
      {
        "id": "edge-001",
        "from": "node-001",
        "to": "node-002",
        "sequence": 1,
        "label": "MemberOf",
        "mitreTechiqueId": "T1078.004",
        "engineId": "identity_hygiene",
        "isHot": true,
        "remediation": "Remove admin@contoso.com from IT-Admins group"
      },
      {
        "id": "edge-002",
        "from": "node-002",
        "to": "node-003",
        "sequence": 2,
        "label": "HasRole (active)",
        "mitreTechiqueId": "T1078.004",
        "engineId": "identity_hygiene",
        "isHot": true,
        "remediation": "Convert standing role to PIM-eligible assignment"
      }
    ]
  },

  "additionalPaths": [
    {
      "pathId": "path-002",
      "hopCount": 4,
      "cumulativeRiskDelta": 22.1,
      "nodes": [],
      "edges": []
    }
  ],

  "blastRadius": {
    "targetNodeId": "node-003",
    "reachableResources": [
      {"label": "All mailboxes (1,247)", "type": "mailbox"},
      {"label": "SharePoint sites (89)", "type": "sharepoint"},
      {"label": "Teams channels (156)", "type": "teams"},
      {"label": "Connected apps (12)", "type": "app"},
      {"label": "Conditional Access policies (8)", "type": "conditional_access"}
    ]
  }
}
```

**Error Responses:**
- `401` -- Missing or invalid JWT
- `403` -- User role not authorized
- `404` -- No attack-path data found; body: `{"detail": "No attack path data available. A BLA scan may not have completed yet."}`
- `500` -- Internal server error

### 3.3 GET `/portal/bl/remediation` (New)

Returns the prioritized remediation list ranked by risk delta.

**Request:**
```
GET /portal/bl/remediation
Authorization: Bearer <JWT>
```

**Response (200):**
```json
{
  "orgId": "string",
  "assessmentDate": "2026-08-18T00:00:00Z",
  "currentScore": 82,
  "items": [
    {
      "rank": 1,
      "title": "Reset leaked admin credential and enforce phishing-resistant MFA",
      "description": "admin@contoso.com credentials found on dark web marketplace. This account has a direct path to Global Admin.",
      "mitreReference": "T1589.001",
      "riskDeltaPts": -15,
      "scoreAfterFix": 67,
      "pathsSevered": ["path-001", "path-003"],
      "engineId": "identity_intelligence",
      "severity": "critical",
      "affectedIdentity": "admin@contoso.com",
      "findingId": "string"
    },
    {
      "rank": 2,
      "title": "Remove nested admin group membership for IT-Admins",
      "description": "IT-Admins security group grants transitive Global Admin access to 42 members.",
      "mitreReference": "T1078.004",
      "riskDeltaPts": -8,
      "scoreAfterFix": 74,
      "pathsSevered": ["path-001"],
      "engineId": "identity_hygiene",
      "severity": "high",
      "affectedIdentity": "IT-Admins group",
      "findingId": "string"
    }
  ]
}
```

**Risk delta computation:** For each finding, the delta is computed by removing the finding's `r_f` from the noisy-OR product for its engine, recomputing the engine score, and then recomputing the headline. This is done at scan time and stored, not on-demand.

**Error Responses:**
- `401` / `403` / `404` / `500` -- same pattern as above

### 3.4 GET `/portal/bl/posture` (New)

Returns framework compliance data derived from tagged findings.

**Request:**
```
GET /portal/bl/posture
Authorization: Bearer <JWT>
```

**Response (200):**
```json
{
  "orgId": "string",
  "assessmentDate": "2026-08-18T00:00:00Z",

  "nistCsf": {
    "govern": {"totalSubcategories": 6, "met": 4, "coveragePercent": 66.7},
    "identify": {"totalSubcategories": 12, "met": 8, "coveragePercent": 66.7},
    "protect": {"totalSubcategories": 15, "met": 10, "coveragePercent": 66.7},
    "detect": {"totalSubcategories": 8, "met": 3, "coveragePercent": 37.5},
    "respond": {"totalSubcategories": 6, "met": 2, "coveragePercent": 33.3}
  },

  "iso27001": {
    "A.5": {"name": "Organizational controls", "totalControls": 10, "met": 7, "coveragePercent": 70.0},
    "A.6": {"name": "People controls", "totalControls": 5, "met": 3, "coveragePercent": 60.0},
    "A.7": {"name": "Physical controls", "totalControls": 4, "met": 0, "coveragePercent": 0.0, "note": "Not assessed by BLA"},
    "A.8": {"name": "Technological controls", "totalControls": 15, "met": 9, "coveragePercent": 60.0}
  },

  "essentialEight": [
    {
      "strategy": "Application control",
      "currentMaturityLevel": 0,
      "targetMaturityLevel": 1,
      "assessed": false,
      "note": "Not assessed by BLA"
    },
    {
      "strategy": "Patch applications",
      "currentMaturityLevel": 1,
      "targetMaturityLevel": 2,
      "assessed": true
    },
    {
      "strategy": "Configure Microsoft Office macro settings",
      "currentMaturityLevel": 2,
      "targetMaturityLevel": 3,
      "assessed": true
    },
    {
      "strategy": "User application hardening",
      "currentMaturityLevel": 1,
      "targetMaturityLevel": 2,
      "assessed": true
    },
    {
      "strategy": "Restrict administrative privileges",
      "currentMaturityLevel": 1,
      "targetMaturityLevel": 3,
      "assessed": true
    },
    {
      "strategy": "Patch operating systems",
      "currentMaturityLevel": 0,
      "targetMaturityLevel": 2,
      "assessed": false,
      "note": "Not assessed by BLA"
    },
    {
      "strategy": "Multi-factor authentication",
      "currentMaturityLevel": 2,
      "targetMaturityLevel": 3,
      "assessed": true
    },
    {
      "strategy": "Regular backups",
      "currentMaturityLevel": 0,
      "targetMaturityLevel": 1,
      "assessed": false,
      "note": "Not assessed by BLA"
    }
  ]
}
```

**Error Responses:**
- `401` / `403` / `404` / `500` -- same pattern

---

## 4. Data Model Changes

### 4.1 `BLRiskInfo-{stage}` (Updated)

**Key structure:** Unchanged -- `orgId` (HASH), no sort key.

**New attributes added to the existing record:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `scoringModelVersion` | `S` | `"v2"` -- enables trend chart annotation |
| `riskLabel` | `S` | `"Critical"` / `"High"` / `"Medium"` / `"Low"` -- pre-computed label (eliminates frontend mapping bugs) |
| `verdictText` | `S` | Pre-generated fear-first narrative string |
| `engineSubScores` | `L` (list of maps) | Per-engine sub-score objects (engineId, subScore, weight, severity counts, isConditional) |
| `enginesActive` | `L` (list of strings) | Engine IDs that ran for this scan |
| `kpis` | `M` (map) | `{ttgaHops, leakedAdminPasswords, standingGlobalAdmins, adminsWithMfa, pathsToTakeover}` |
| `adIntegrationState` | `S` | `"integrated"` / `"not_integrated"` / `"hybrid_signals_detected"` |
| `hybridSignalsDetected` | `BOOL` | Whether Entra Connect was detected |
| `scoreTrend` | `L` (list of maps) | Historical score entries with `{date, score, scoringModelVersion}` |

**Removed attributes** (v1 artifacts, cleaned up at v2 release):
- `description` -- replaced by `verdictText`
- `remediationActions` -- moved to separate remediation endpoint

**Backward compatibility:** The v1 `details` array is replaced by the v2 `details` array with additional fields (`findingWeight`, `attack`, `framework`, `usecaseId`, `engineId`). Old v1 records in DynamoDB are not modified. The API endpoint must handle both v1 and v2 records gracefully during the transition window (first scan after v2 release overwrites the record).

### 4.2 `BLResult-{stage}` (Extended)

**Key structure:** Unchanged -- `orgId` (HASH), `idpObjectSID` (RANGE).

**New attributes added to each finding record:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `engineId` | `S` | Which engine this finding belongs to (`identity_hygiene`, `platform_hygiene`, `identity_intelligence`, `microsoft_365`, `active_directory`) |
| `findingWeight` | `N` | Computed `r_f` value (0.0 - 0.95) |
| `reachabilityPremium` | `N` | `P(f)` value set by graph engine (0.0 - 1.2); 0 if not on a confirmed path |
| `attack` | `M` | `{tacticIds: [S], techniqueIds: [S]}` -- MITRE ATT&CK metadata (inherited from check's static mapping) |
| `framework` | `M` | `{nistCsfSubcategory: S, iso27001AnnexA: S, essential8Mitigation: S, maturityLevel: N}` -- compliance tags |
| `severityBand` | `S` | Normalized severity: `"critical"` / `"high"` / `"medium"` / `"low"` -- derived from the finding's score using v2 bands |

**No new GSI required.** The handler queries by `orgId` + sort key prefix (DC ID), which is the existing access pattern.

### 4.3 `BLAttackGraph-{stage}` (New Table)

**Decision: DynamoDB, not S3.**

**Rationale:** The graph JSON for a single org is expected to be under 200KB even for large tenants (4-hop cap, 50 findings/severity cap). DynamoDB's 400KB item limit is sufficient. DynamoDB provides consistent read latency (~5ms) vs S3's ~50-100ms GET latency. The graph is read on every dashboard load, so latency matters. If a future tenant exceeds 400KB, the `additionalPaths` array can be moved to a separate item with a sort key.

**Table definition:**

```yaml
BLAttackGraph:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: BLAttackGraph-${self:provider.stage}
    AttributeDefinitions:
      - AttributeName: orgId
        AttributeType: S
    KeySchema:
      - AttributeName: orgId
        KeyType: HASH
    BillingMode: PAY_PER_REQUEST
```

**Record shape:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `orgId` | `S` (PK) | Organization ID |
| `assessmentDate` | `S` | ISO 8601 timestamp |
| `totalPathCount` | `N` | Total distinct paths to Tier-0 |
| `primaryPath` | `M` | `{pathId, hopCount, cumulativeRiskDelta, nodes: [M], edges: [M]}` |
| `additionalPaths` | `L` | List of path objects (same shape as primaryPath) |
| `blastRadius` | `M` | `{targetNodeId, reachableResources: [{label, type}]}` |
| `kpis` | `M` | `{ttgaHops, leakedAdminPasswords, standingGlobalAdmins, adminsWithMfa, pathsToTakeover}` |
| `remediation` | `L` | List of remediation items with rank, title, delta, paths severed |
| `posture` | `M` | Framework compliance roll-ups (NIST, ISO, E8) |
| `ttl` | `N` | TTL attribute -- set to 90 days after assessment date (graph data is regenerated on each scan) |

**Why store remediation and posture in the graph table?** All three (graph, remediation, posture) are computed together at scan time from the same unified finding set. Storing them together avoids a second write and keeps the scan-time computation atomic. The API endpoints (`/remediation`, `/posture`) read from this same table and return the relevant subset.

### 4.4 Framework Tag Storage

**Decision:** Framework tags are stored as attributes on each finding in `BLResult` (not a separate table).

**Rationale:** The tags are static per-check (inherited from `TASK_META`). They are written once at scan time alongside the finding. No separate lookup is needed. The posture view aggregates them at scan time and stores the roll-up in `BLAttackGraph.posture`.

### 4.5 MITRE Tag Storage

**Decision:** Same as framework tags -- stored as `attack` attribute on each finding in `BLResult`.

**Rationale:** The MITRE tags are static per-check. They are needed both for the graph edge labels and for the remediation list's MITRE reference. Storing on the finding avoids a join at read time.

### 4.6 Score Trend Storage

**Decision:** The `scoreTrend` array is stored on the `BLRiskInfo` record. Each scan appends a new entry.

**Concern:** Unbounded growth. **Mitigation:** Cap at 24 entries (6 months of weekly scans). Oldest entries are dropped on append.

---

## 5. Component Boundaries

### 5.1 Backend Module Ownership

| Module | Owns | Communicates With |
|--------|------|-------------------|
| `bl_handler.py` | Orchestrates BLA scan lifecycle: triggers rules, invokes scoring, invokes graph engine, writes `BLRiskInfo` and `BLAttackGraph` | Reads from `BLResult`, `IHResults`, `M365Result`. Writes to `BLRiskInfo`, `BLAttackGraph`. |
| `bl_scoring_v2.py` | Pure scoring functions (finding weight, engine score, headline, label) | Called by `bl_handler.py`. No I/O. |
| `bl_graph_engine.py` | Graph construction, reverse-BFS pathfinding, KPI extraction, blast radius, remediation ranking | Called by `bl_handler.py`. Reads unified finding list (passed as argument, not direct DynamoDB access). |
| `mitre_mapping.py` | Static check-ID-to-MITRE-tags mapping | Imported by rule modules at `TASK_META` init time. |
| `framework_mapping.py` | Static check-ID-to-framework-tags mapping | Imported by rule modules at `TASK_META` init time. |
| `shared_helpers.py` | Retry, pagination, group expansion, consumer domain list | Imported by individual rule modules. |
| `role_template_ids.py` | Privileged role template ID constants | Imported by IH rules that detect privileged roles. |
| `bl_routers.py` | API layer: reads from `BLRiskInfo` and `BLAttackGraph`, returns shaped responses | No business logic. Pure read + shape. |
| Individual rule files (`bl_rules/`, `ih_rules/`, `m365_rules/`) | Per-check scan logic. Each rule writes its findings to its respective result table. | Write to `BLResult` / `IHResults` / `M365Result`. Import from `shared_helpers`, `mitre_mapping`, `framework_mapping`. |

### 5.2 Frontend Module Ownership

| Module | Owns | Communicates With |
|--------|------|-------------------|
| `BreachLikelihoodV2/index.tsx` | Container: fetches all 4 API endpoints on mount, manages toggle state, passes data to child components | 4 react-query hooks |
| `HeroSection/` | Score ring, verdict text, KPI cluster | Receives props from container |
| `AttackPath/` | SVG graph, node/edge detail panels, walk animation, blast radius, path cycler | Receives graph data as props; manages internal interaction state (selected node, animation state) |
| `EngineMatrix/` | Severity grid, drill-down panel, AD upsell | Receives engine sub-scores and details as props |
| `Remediation/` | Ranked list | Receives remediation items as props |
| `Posture/` | NIST, ISO, E8 panels | Receives posture data as props |
| `PDFReportRenderer.tsx` | PDF generation | Fetches same 4 API endpoints; renders to `@react-pdf/renderer` document |

### 5.3 Inter-Portal Communication

The MSSP Partner Portal does NOT call different endpoints. It calls the same `/portal/bl/identities` endpoint (authenticated as the MSSP user with the client's orgId context) and generates the PDF client-side using the same data. The MSSP portal's real API integration (replacing `mockResolve()`) is a separate task that requires backend support for MSSP-to-client-org data access (existing pattern in other MSSP features).

---

## 6. Implementation Order

### Phase 0: P0 Bug Fixes (Sprint 1 -- ship before next demo)

| Order | Ticket | Work | Dependency |
|-------|--------|------|------------|
| 0.1 | DELA-BLA-1 | Fix label-swap in `bl_handler.py` lines 609-616 (bands 75-100=CRITICAL, 50-74=HIGH) and frontend `RiskLevelText` constant if needed | None |
| 0.2 | DELA-BLA-2 | Unit tests for band-to-label mapping; CI gate | DELA-BLA-1 |
| 0.3 | DELA-BLA-4 | IH008 JIT false-pass fix | None |
| 0.4 | DELA-BLA-5 | MT011 pagination + count variable fix | None |
| 0.5 | DELA-BLA-6 | 8 org-level IH rules: exception -> error state | None |
| 0.6 | DELA-BLA-3 | IH005 duplicate-account false-pass fix | None |

**Gate:** All P0 items must pass QA before any P1 work begins.

### Phase 1: P1 Correctness + Tagging (Sprint 2-3)

| Order | Ticket | Work | Dependency |
|-------|--------|------|------------|
| 1.1 | DELA-BLA-13 | `role_template_ids.py` -- privileged role template ID module | None |
| 1.2 | DELA-BLA-7 | IH001 MFA fix (pagination, capability flag, privilege scoring) | DELA-BLA-13 |
| 1.3 | DELA-BLA-8 | MT005/MT006/MT010 severity + de-duplication fix | DELA-BLA-13 |
| 1.4 | DELA-BLA-9 | MT002/MT003/MT004 service-plan ID matching fix | None |
| 1.5 | DELA-BLA-10 | `mitre_mapping.py` + tag all rules with MITRE metadata | None (can parallelize with 1.1-1.4) |
| 1.6 | DELA-BLA-11 | `framework_mapping.py` + tag all rules with NIST/ISO/E8 metadata | None (can parallelize) |
| 1.7 | DELA-BLA-12 | Remove Threat Detection from BLA scoring + engine matrix + PDF | None |

**Gate:** DELA-BLA-10 must be complete before DELA-BLA-16 (graph engine) can start. DELA-BLA-11 must be complete before posture view can start.

**Frontend can start in parallel during Phase 1:**
- Hero section, score ring (ECharts), KPI cluster -- using mock/stub data matching the v2 API contract
- SeverityChip component (color + shape + text encoding)
- Engine matrix shell (without real data)

### Phase 2: P2 v2 Build -- Backend (Sprint 3-5)

| Order | Ticket | Work | Dependency |
|-------|--------|------|------------|
| 2.1 | DELA-BLA-14 | `shared_helpers.py` -- consolidate retry, pagination, group-expansion | None |
| 2.2 | DELA-BLA-15 | `bl_scoring_v2.py` + replace v1 scoring in handler + delete v1 code | DELA-BLA-14, all P0+P1 bug fixes |
| 2.3 | DELA-BLA-16 | `bl_graph_engine.py` + `BLAttackGraph` table + graph compute in handler | DELA-BLA-10 (MITRE tags), DELA-BLA-15 (finding weights for reachability) |
| 2.4 | DELA-BLA-17 | Conditional-AD scoring contract (engine map, aggregator, `adIntegrationState`) | DELA-BLA-15 |
| 2.5 | -- | Update `bl_routers.py` with 4 API endpoints | DELA-BLA-15, DELA-BLA-16 |

**Note on DELA-BLA-15 and DELA-BLA-16 coupling:** The graph engine sets `P(f)` (reachability premium) which feeds back into `r_f`. Implementation order: (1) build scoring module with `P(f)=0` default, (2) build graph engine that computes `P(f)`, (3) handler calls graph engine first to get `P(f)` values, then calls scoring with those values. This means a two-pass approach within the handler:
- Pass 1: Build graph, run BFS, extract `P(f)` for each finding
- Pass 2: Compute `r_f` with `P(f)`, compute engine scores, compute headline

### Phase 3: P2 v2 Build -- Frontend (Sprint 4-6)

| Order | Ticket | Work | Dependency |
|-------|--------|------|------------|
| 3.1 | DELA-BLA-18a | Attack-path SVG graph component (D3 dagre layout + React SVG) | API contract agreed (Section 3.2) |
| 3.2 | DELA-BLA-18b | Node/edge detail panels, walk animation, blast radius overlay | 3.1 |
| 3.3 | DELA-BLA-18c | Engine matrix with drill-down + AD upsell/teaser | API contract agreed (Section 3.1) |
| 3.4 | DELA-BLA-18d | Remediation list | API contract agreed (Section 3.3) |
| 3.5 | DELA-BLA-18e | Posture view (NIST, ISO, E8 panels) + Attack/Posture toggle | API contract agreed (Section 3.4), DELA-BLA-11 |
| 3.6 | DELA-BLA-18f | Wire all components to live API (replace stubs) | Backend Phase 2 complete |

### Phase 4: PDF + MSSP (Sprint 5-7)

| Order | Ticket | Work | Dependency |
|-------|--------|------|------------|
| 4.1 | DELA-BLA-19a | PDF cover + engine summary pages | Backend APIs live |
| 4.2 | DELA-BLA-19b | PDF attack-path story page (SVG-to-image render) | 3.1 (graph component), Backend APIs live |
| 4.3 | DELA-BLA-19c | PDF remediation roadmap + framework appendix | Backend APIs live |
| 4.4 | DELA-BLA-19d | PDF conditional-AD appendix + severity pattern fills for B&W | 4.1 |
| 4.5 | MSSP-1 | Remove Threat Detection from MSSP ENGINE_ORDER | None |
| 4.6 | MSSP-2 | MSSP portal: consume real v2 API (replace mockResolve) | Backend APIs live |
| 4.7 | MSSP-3 | MSSP portal: updated PDF download | 4.1-4.4 |

### Dependency Graph (Critical Path)

```
P0 bugs  ──────────────────────────────────────────────────────────────>  GATE
                                                                            |
DELA-BLA-13 (role IDs) ──> DELA-BLA-7, DELA-BLA-8                          |
DELA-BLA-10 (MITRE tags) ──────────────────────> DELA-BLA-16 (graph) ──>   |
DELA-BLA-11 (framework tags) ────────────────────────────> Posture view    |
DELA-BLA-14 (helpers) ──> DELA-BLA-15 (v2 scoring) ──> DELA-BLA-16 ──>    |
                                                  |                        |
                                                  └──> DELA-BLA-17 (AD)   |
                                                  |                        |
                                                  └──> API endpoints ──>   |
                                                          |                |
                                                   Frontend wiring ──> PDF |
                                                                     |     |
                                                               MSSP ──> RELEASE
```

---

## 7. Risks & Constraints

### 7.1 Cross-Table Aggregation (HIGH risk)

**Risk:** IH and M365 results are stored in separate DynamoDB tables (`IHResults`, `M365Result`) from BL results (`BLResult`). The v2 aggregator must read all three tables to build the unified graph and score.

**Mitigation:**
- The `bl_update_risk_info_handler` Lambda already has IAM permissions to read these tables (confirmed in `serverless.yml`).
- Lambda timeout is 900s -- sufficient for cross-table reads.
- If IH or M365 results are missing for a DC (scan not yet complete), log a warning and compute with available data only. Do NOT block on missing data.

### 7.2 Multi-DC Organization Handling (MEDIUM risk)

**Risk:** `bl_routers.py` returns `bl_risk_info[0]` -- only the first record. If multiple records somehow exist, the API silently ignores others.

**Mitigation:** The `BLRiskInfo` table schema has `orgId` as the sole partition key with no sort key -- DynamoDB enforces one record per org. The handler overwrites on each scan. No multi-record scenario exists. However, the handler's `orgId` query does return a list; the router must handle the empty-list case (return 404) and single-item case (return `[0]`). This is already the existing behavior and is correct.

### 7.3 v2 Hard Cutover -- No Rollback (HIGH risk)

**Risk:** v2 replaces v1 entirely. If v2 scoring produces unexpected results (e.g., all tenants suddenly score 95+), there is no rollback path.

**Mitigation:**
- All P0 and P1 bug fixes MUST ship in the same release as v2 scoring. v2 math on top of false-green detections would be worse than v1.
- Comprehensive unit tests for `bl_scoring_v2.py` with known input/output pairs.
- Score trend chart annotates the v2 cutover date so score jumps are explained.
- Sales/CS brief is MANDATORY before release. Prepare messaging for clients whose score changes significantly.
- Run v2 scoring on 3-5 real tenant datasets in a staging environment before production deployment.

### 7.4 Graph Compute Must Happen at Scan Time (HIGH risk)

**Risk:** On-demand graph computation on each dashboard load would add 5-15 seconds of latency, violating SC-004 (10s page load) and SC-005 (300ms node click).

**Mitigation:** Graph is computed and stored in `BLAttackGraph` during the scan handler. The API endpoint performs a single DynamoDB read. Dashboard load latency for graph data is ~5ms.

### 7.5 Pathfinder at Scale (MEDIUM risk)

**Risk:** Large tenants with complex group structures could produce exponential path combinations.

**Mitigation:**
- 4-hop cap on reverse-BFS
- 50-finding cap per severity band for score contribution
- Total path count stored but only primary path + up to 10 additional paths serialized
- Graph compute has a 30-second timeout (within the 900s Lambda); if exceeded, the graph is stored with whatever paths were found and a `graphComputePartial: true` flag

### 7.6 DynamoDB Item Size for Attack Graph (LOW risk)

**Risk:** The `BLAttackGraph` record could exceed DynamoDB's 400KB item limit for very large tenants.

**Mitigation:**
- 4-hop cap + 50-finding cap naturally limit graph size
- Additional paths beyond the top 10 are not serialized (only `totalPathCount` is stored)
- If an item exceeds 350KB at write time, truncate `additionalPaths` to fit
- Monitoring alert on items exceeding 300KB -- if triggered, consider S3 overflow for `additionalPaths`

### 7.7 PDF Attack-Path Image Render (MEDIUM risk)

**Risk:** The SVG-to-image conversion for Page 2 of the PDF may produce inconsistent results across environments (local dev vs Lambda).

**Mitigation:**
- Use `html-to-image` library with a fixed viewport size
- Fallback: if image render fails or times out (3s), replace with a text-based step list (Finding 1 -> Finding 2 -> Target)
- PDF generation has a 15s total budget (SC-010)

### 7.8 Framework Tag Accuracy (MEDIUM risk)

**Risk:** The NIST CSF / ISO 27001 / Essential Eight mappings are manually authored and may contain errors or gaps.

**Mitigation:**
- Framework mapping table (`framework_mapping.py`) is a separate module reviewed by security engineering
- Posture view shows "Not assessed by BLA" for strategies/controls that no check maps to (rather than showing 0%)
- Essential Eight strategies that BLA cannot assess (e.g., "Application control", "Patch operating systems", "Regular backups") are explicitly marked `assessed: false`

### 7.9 MSSP Portal Real API Integration (MEDIUM risk)

**Risk:** The MSSP portal currently uses `mockResolve()`. Replacing with real API calls requires backend support for MSSP-to-client-org data access.

**Mitigation:** This is a known prerequisite. The MSSP portal's API integration is scoped as a separate sub-ticket (MSSP-2) and depends on existing cross-org access patterns used by other MSSP features.

### 7.10 Deployment Order (CRITICAL)

The release must be deployed in this exact order:
1. **DynamoDB table creation** (`BLAttackGraph` table via CloudFormation/Serverless)
2. **Backend Lambda deployment** (v2 scoring + graph engine + updated API endpoints)
3. **Frontend deployment** (v2 dashboard)
4. **MSSP portal deployment** (v2 score display + PDF)

Backend must be deployed first because the frontend will immediately call the new API endpoints. If frontend deploys before backend, the `/attack-path`, `/remediation`, and `/posture` endpoints will 404.

---

## 8. Tech Lead Sign-Off

- [x] Approved -- proceed to Designer and Scrum Master
**Approved by:** Engineer -- 2026-08-18

---

**Notes for Designer:**
- The HTML mock at `Downloads/bla_attack_path_dashboard 2.html` is the reference design
- All severity encoding must use color + shape + text (no color-only)
- PDF severity chips additionally need pattern fills for B&W printing
- The score ring replaces the current half-circle gauge -- animated count-up on load
- Attack/Posture toggle must feel instant (client-side state swap)
- AD upsell banner must be full-weight (same card size as the AD engine row, not greyed out or shrunk)

**Notes for Scrum Master:**
- 19 tickets pre-defined in the spec (DELA-BLA-1 through DELA-BLA-19)
- MSSP tickets (MSSP-1 through MSSP-3) are additional
- Frontend DELA-BLA-18 should be split into sub-tickets (18a-18f) per Phase 3 order
- PDF DELA-BLA-19 should be split into sub-tickets (19a-19d) per Phase 4 order
