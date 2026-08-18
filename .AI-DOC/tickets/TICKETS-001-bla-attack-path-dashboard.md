# TICKETS-001-PRM-970: BLA v2 — Attack-Path Dashboard & Scoring Redesign

**Date:** 2026-08-18
**References:** UW-001-bla-attack-path-dashboard.md | TECH-001-bla-attack-path-dashboard.md | DESIGN-001-bla-attack-path-dashboard.md
**Status:** PENDING CONFIRMATION

---

## Sprint Overview

This is a **three-phase, multi-sprint delivery** of BLA v2 with 19 core tickets grouped by priority and execution order. Phase 1 (P0) ships independently to fix confirmed bugs before the next sales demo. Phase 2 (P1) adds correctness fixes and required metadata tagging (MITRE + framework). Phase 3 (P2) delivers the complete v2 scoring engine, attack-path graph, dashboard UI, and redesigned PDF.

**Total tickets:** 19
**Phases:**
- **Phase 1 (P0):** Tickets DELA-BLA-1 through DELA-BLA-6 — Bug fixes (2 weeks)
- **Phase 2 (P1):** Tickets DELA-BLA-7 through DELA-BLA-13 — Correctness + tagging (3 weeks)
- **Phase 3 (P2):** Tickets DELA-BLA-14 through DELA-BLA-19 — v2 build (5 weeks)

---

## Ticket List

---

### DELA-BLA-1: Fix High/Critical Label Swap

**Phase:** P0
**Type:** Bug
**Owner:** Backend + Frontend
**Depends on:** None
**Gates:** DELA-BLA-2
**Status:** To Do

#### Description

The BLA risk label mapping currently swaps "High" and "Critical" labels. Scores in the 50–74 range (which should be "High") are displayed as "Critical," and scores in the 75–100 range are displayed as "High." This is a data presentation bug with no impact on score calculation, but it directly undermines sales credibility in live demos and must be fixed before the next prospect presentation.

The fix requires:
1. Backend: Verify the band-to-label assignment in `backend/src/aws/lambdas/bl_handler.py` lines 609–616. Ensure `RiskRating` bands are: 75–100=CRITICAL, 50–74=HIGH, 25–49=MEDIUM, 0–24=LOW.
2. Frontend: Check `frontend/src/core/constants/constants.ts` for the `RiskLevelText` map and ensure it maps numeric levels correctly (level 4 = "High", level 5 = "Critical").

Both backend and frontend fixes must ship together in the same release.

#### Acceptance Criteria

- [ ] Given a tenant with a BLA score of 65, when the dashboard loads, then the label displayed is "High" (not "Critical")
- [ ] Given a tenant with a BLA score of 80, when the dashboard loads, then the label displayed is "Critical" (not "High")
- [ ] Given a tenant with a BLA score of 50, when the dashboard loads, then the label displayed is "High"
- [ ] Given a tenant with a BLA score of 75, when the dashboard loads, then the label displayed is "Critical"
- [ ] Both backend and frontend code changes are deployed simultaneously — no label swap can occur in production at any point

#### Definition of Done

- [ ] Code reviewed by Tech Lead
- [ ] Backend score band mapping verified in `bl_handler.py` (TECH spec Section 2.1, label assignment)
- [ ] Frontend `RiskLevelText` constants verified/corrected in `constants.ts`
- [ ] Manual QA: test a live tenant with a score in each band (50–74, 75–100) and verify label
- [ ] No regressions in existing BLA functionality
- [ ] Backend and frontend deployed to staging in same deployment window
- [ ] ROADMAP.md status updated

---

### DELA-BLA-2: Regression Tests for Score Bands

**Phase:** P0
**Type:** Test
**Owner:** Backend
**Depends on:** DELA-BLA-1
**Gates:** None
**Status:** To Do

#### Description

Add comprehensive unit tests to the backend CI pipeline to catch any regression of the label-swap bug. The test suite must validate the band-to-label mapping and the two-tenant divergence requirement (tenant with 1 Critical must score lower than tenant with 1 Critical + 500 High).

Tests will be added to the existing test suite in `backend/tests/` covering:
- Band boundary cases (49, 50, 74, 75, 100)
- Two-tenant divergence: `score(1 Critical) < score(1 Critical + 500 High)`
- CI gate: the build must block if either test fails

Reference: TECH spec Section 2.1, Success Criteria SC-001 and SC-002.

#### Acceptance Criteria

- [ ] Unit test exists for band-to-label mapping: scores 50–74 → "High", 75–100 → "Critical", etc.
- [ ] Unit test validates two-tenant divergence: identical worst-severity but different counts produce different scores
- [ ] Test is part of the standard CI pipeline and runs on every commit
- [ ] CI build blocks (fails) if either test fails — cannot merge without passing both
- [ ] Test passes after DELA-BLA-1 is merged
- [ ] Test fails before DELA-BLA-1 (to prove it catches the regression)

#### Definition of Done

- [ ] Test code written and reviewed by Tech Lead
- [ ] Tests added to `.github/workflows/test.yml` or equivalent CI config
- [ ] Tests pass on staging with DELA-BLA-1 deployed
- [ ] CI configuration verified to block merge on test failure
- [ ] No regressions in existing test suite
- [ ] ROADMAP.md status updated

---

### DELA-BLA-3: IH005 Duplicate-Account False Pass (GATE)

**Phase:** P0
**Type:** Bug
**Owner:** Backend
**Depends on:** None
**Gates:** None (blocks sales builds until fixed)
**Status:** To Do

#### Description

The IH005 (Duplicate Accounts) rule produces a false-green (pass) on some tenants due to a renamed collector field. The rule attempts to access a field that no longer exists in the current collector output, causing an exception that is silently caught and returned as a pass instead of an error state.

The fix involves:
1. Identify the renamed field in the collector output (likely in `IHResults` table)
2. Update the rule to use the correct field name
3. Add a gate flag (`GATED = True`) to the rule's `TASK_META` dict
4. Document the gate status and removal date

The rule will be excluded from prospect-facing scans (sales builds) until this ticket is closed and verified by QA. The gate flag must be removed once the fix is merged and deployed.

Reference: TECH spec Section 5.1, IH005 bug investigation.

#### Acceptance Criteria

- [ ] Given the IH005 rule and a renamed collector field, when the rule runs, then it correctly reads from the renamed field (not the old field name)
- [ ] Given the IH005 rule encounters a missing field, when the rule runs, then it returns an explicit error state (not a pass)
- [ ] Given a tenant with actual duplicate accounts, when IH005 runs, then the rule correctly identifies and reports the duplicates
- [ ] The rule's `TASK_META` dict contains `GATED = True` before this ticket closes
- [ ] The `GATED` flag is removed in a follow-up commit once QA signs off
- [ ] QA verifies the fix on staging with a test tenant containing known duplicate accounts

#### Definition of Done

- [ ] Root cause (renamed field) identified and documented
- [ ] Rule code updated to use correct field name
- [ ] Error handling changed from silent pass to explicit error state
- [ ] `TASK_META` includes `GATED = True` flag
- [ ] Unit test added: rule correctly processes renamed field + returns error on exception
- [ ] Manual QA sign-off: test tenant with duplicate accounts verifies correct detection
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in other IH rules
- [ ] ROADMAP.md status updated

---

### DELA-BLA-4: IH008 JIT False-Pass on Empty PIM Data (GATE)

**Phase:** P0
**Type:** Bug
**Owner:** Backend
**Depends on:** None
**Gates:** None (blocks sales builds until fixed)
**Status:** To Do

#### Description

The IH008 (Just-in-Time activation) rule produces a false-green when PIM policy data is unavailable. The rule's outer `except` block catches all exceptions and returns an empty list `[]`, which is incorrectly interpreted as "no users failed" (pass) instead of "data unavailable" (error).

The fix involves:
1. Locate the outer `except` in `backend/src/ih_rules/org_rules/ih_check_just_in_time_for_priviledge_users.py`
2. Change the exception handler to return a proper error-state result dict instead of `[]`
3. Add a gate flag (`GATED = True`) to the rule's `TASK_META`
4. Document the gate status and removal date

Reference: TECH spec Section 1, "IH008 JIT false-pass on empty PIM data" bug.

#### Acceptance Criteria

- [ ] Given the IH008 rule and PIM policy data is unavailable, when the rule runs, then it returns an explicit error state (not a pass)
- [ ] Given the IH008 rule and valid PIM data, when the rule runs, then it correctly evaluates JIT activation status
- [ ] Given the IH008 rule with an exception during execution, when the rule runs, then it returns an error result dict (not an empty list)
- [ ] The rule's `TASK_META` dict contains `GATED = True` before this ticket closes
- [ ] The `GATED` flag is removed in a follow-up commit once QA signs off

#### Definition of Done

- [ ] Outer `except` block in `ih_check_just_in_time_for_priviledge_users.py` identified and reviewed
- [ ] Exception handler changed to return error result dict with appropriate error message
- [ ] `TASK_META` includes `GATED = True` flag
- [ ] Unit test added: exception in rule returns error state, not empty list
- [ ] Manual QA sign-off: test tenant with unavailable PIM data verifies error state returned
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in other IH rules
- [ ] ROADMAP.md status updated

---

### DELA-BLA-5: MT011 Intune Compliance Count & Pagination (GATE)

**Phase:** P0
**Type:** Bug
**Owner:** Backend
**Depends on:** None
**Gates:** None (blocks sales builds until fixed)
**Status:** To Do

#### Description

The MT011 (Intune device compliance) rule has two bugs:
1. Uses the wrong variable for the `@odata.nextLink` token — uses `policies_beta_data` instead of `devices_not_compliance_data`, so pagination fails silently and only the first page of non-compliant devices is counted
2. Missing `$count=true` parameter on the non-compliant devices filter request, so the count is inaccurate

The fix involves:
1. In `backend/src/m365_rules/MT011_intune_device_compliance.py`, locate the pagination loop
2. Change `policies_beta_data` → `devices_not_compliance_data` for the `@odata.nextLink` reference
3. Add `$count=true` to the filter request URL
4. Add a gate flag (`GATED = True`) to the rule's `TASK_META`

Reference: TECH spec Section 1, "MT011 Intune compliance count & pagination" bug.

#### Acceptance Criteria

- [ ] Given the MT011 rule and non-compliant devices span multiple pages, when the rule runs, then all pages are retrieved and counted (not just page 1)
- [ ] Given the MT011 rule, when the rule runs, then the `@odata.nextLink` pagination token is read from the correct response object (`devices_not_compliance_data`)
- [ ] Given the MT011 rule, when the rule runs, then the count parameter includes `$count=true` in the request URL
- [ ] Given a test tenant with >50 non-compliant devices, when MT011 runs, then the actual count is reported (not truncated at page boundary)

#### Definition of Done

- [ ] Bug locations identified in `MT011_intune_device_compliance.py`
- [ ] Pagination variable corrected (`policies_beta_data` → `devices_not_compliance_data`)
- [ ] `$count=true` added to the non-compliant devices filter request
- [ ] `TASK_META` includes `GATED = True` flag
- [ ] Unit test added: rule correctly paginates through multiple pages and counts all non-compliant devices
- [ ] Manual QA sign-off: test tenant with >50 non-compliant devices verifies full count
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in other M365 rules
- [ ] ROADMAP.md status updated

---

### DELA-BLA-6: Org-Level Rules: Empty-on-Exception → Error State (GATE)

**Phase:** P0
**Type:** Bug
**Owner:** Backend
**Depends on:** None
**Gates:** None (blocks sales builds until fixed)
**Status:** To Do

#### Description

All 8 organization-level Identity Hygiene rules (IH002–IH009) have a critical exception-handling flaw: when an exception occurs, the outer `except` block returns an empty list `[]`, which the aggregator treats as "no failures" (pass). This produces false-greens for any tenant where the org-level API call fails.

The fix involves:
1. Audit all 8 org-level rules in `backend/src/ih_rules/org_rules/`
2. For each rule, change the outer `except` block to return a proper error-state result dict instead of `[]`
3. Add a gate flag (`GATED = True`) to each rule's `TASK_META`
4. Document which rules are gated

Rules affected: (verify against the codebase)
- IH002 (or equivalent org-level)
- IH003
- ...etc (8 total)

Reference: TECH spec Section 1, "Org-level rules: empty-on-exception → error state" bug.

#### Acceptance Criteria

- [ ] Given any of the 8 org-level rules and an exception occurs, when the rule runs, then it returns an explicit error state (not an empty list or pass)
- [ ] Given all 8 org-level rules in a normal execution path, when the rules run, then they complete without exception
- [ ] Each of the 8 rules has `GATED = True` in `TASK_META` before this ticket closes

#### Definition of Done

- [ ] All 8 org-level rule files identified in `backend/src/ih_rules/org_rules/`
- [ ] Outer `except` block in each rule changed to return error result dict
- [ ] `TASK_META` in each rule updated to include `GATED = True` flag
- [ ] Unit test added for each rule: exception returns error state, not empty list
- [ ] Manual QA sign-off: verify all 8 rules return error state when an exception is triggered (e.g., via mock API timeout)
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in other rules
- [ ] Documentation updated with gate status per rule
- [ ] ROADMAP.md status updated

---

### DELA-BLA-7: IH001 MFA: Pagination + Capability Flag

**Phase:** P1
**Type:** Bug
**Owner:** Backend
**Depends on:** DELA-BLA-13
**Gates:** None
**Status:** To Do

#### Description

The IH001 (MFA coverage) rule has multiple correctness issues:
1. Does not paginate through all users — only evaluates users on the first page
2. Uses "registration" capability instead of the correct "capability" flag
3. Does not exclude account types that cannot register for MFA (e.g., guest accounts, service principals)
4. Does not score by privilege level — treats all MFA-missing users equally instead of weighting admin MFA enforcement more heavily

The fix requires updating `backend/src/ih_rules/user_rules/ih_check_mfa_coverage.py` (or equivalent) to:
1. Implement pagination via `@odata.nextLink` to retrieve all users
2. Use the correct capability flag (reference: TECH spec Section 2.1)
3. Filter out non-registerable account types (guest, external, service-account types)
4. Score findings by privilege level: admin missing MFA is higher severity than non-admin missing MFA
5. Tag findings with MITRE T1078.004 and framework tags

Reference: UW-001 Story 1, Step 5; TECH spec Section 2.1 P1 fixes.

#### Acceptance Criteria

- [ ] Given a tenant with >500 users, when IH001 runs, then all users are evaluated (not just page 1)
- [ ] Given the IH001 rule, when it checks user MFA capability, then it uses the correct capability flag (verified against Microsoft Graph docs)
- [ ] Given a tenant with guest accounts and service accounts, when IH001 runs, then non-registerable account types are excluded from the evaluation
- [ ] Given a tenant with 1 admin missing MFA and 10 non-admin users missing MFA, when IH001 runs, then the admin finding has higher severity (Critical/High) than non-admin findings (Medium/Low)
- [ ] Given IH001 findings, when they are recorded, then each carries MITRE tag `T1078.004` and framework tags from the mapping

#### Definition of Done

- [ ] Pagination implemented using `@odata.nextLink` loop
- [ ] Capability flag corrected (reference: TECH spec or Microsoft Graph docs)
- [ ] Account type filtering added (exclude guest, external, service-account types)
- [ ] Privilege-level scoring implemented (admin vs. non-admin weighting)
- [ ] MITRE and framework tags added to findings
- [ ] Unit test added: rule evaluates all users across pages
- [ ] Unit test added: rule correctly weights admin MFA enforcement
- [ ] Manual QA sign-off: test tenant with >500 users and mixed account types
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in existing MFA functionality
- [ ] ROADMAP.md status updated

---

### DELA-BLA-8: MT005/MT006/MT010 Severity & Direction

**Phase:** P1
**Type:** Bug
**Owner:** Backend
**Depends on:** DELA-BLA-13
**Gates:** None
**Status:** To Do

#### Description

Rules MT005, MT006, and MT010 (Delegated Admin, Scoped Admin, Service Admin) incorrectly assign severity to the ABSENCE of scoped admin roles. When scoped admin roles are not assigned (which is actually a security gap — admins should be scoped to limit blast radius), these rules mark it as HIGH severity and recommend creating scoped roles. This is backwards: the absence of scoped roles is a configuration gap (MEDIUM severity at most), not an urgent finding.

The fix involves:
1. Redefine the severity direction in each rule: absence of scoped admin = delegation gap (LOW-MEDIUM), not a blocker
2. Ensure assignments are counted across direct + group + eligible assignment types
3. De-duplicate findings (if the same principal appears in multiple assignment paths, count only once)
4. Add MITRE and framework tags to findings

Reference: TECH spec Section 2.1, P1 fixes for MT005/MT006/MT010.

#### Acceptance Criteria

- [ ] Given a tenant with zero scoped admin role assignments, when MT005/MT006/MT010 run, then the rules report this as a delegation gap (MEDIUM/LOW severity, not HIGH)
- [ ] Given a tenant where a principal has both direct and group-based admin assignments, when the rules run, then the principal is counted once (de-duplicated)
- [ ] Given a tenant with eligible (PIM-eligible) admin assignments, when the rules run, then those assignments are included in the count alongside direct and group assignments
- [ ] Given MT005/MT006/MT010 findings, when they are recorded, then each carries appropriate MITRE tag and framework tags

#### Definition of Done

- [ ] Severity direction corrected in all three rules (absence = gap, not blocker)
- [ ] De-duplication logic added to count unique principals across assignment types
- [ ] Eligible assignment queries added (if not already present)
- [ ] MITRE and framework tags added
- [ ] Unit test added: absence of scoped role produces MEDIUM/LOW severity finding, not HIGH
- [ ] Unit test added: duplicate assignments de-duplicated correctly
- [ ] Manual QA sign-off: test tenant with direct + group + eligible admin assignments
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in existing M365 admin assignment logic
- [ ] ROADMAP.md status updated

---

### DELA-BLA-9: MT002/MT003/MT004 Licence Substring Matching

**Phase:** P1
**Type:** Bug
**Owner:** Backend
**Depends on:** None
**Gates:** None
**Status:** To Do

#### Description

Rules MT002, MT003, and MT004 (License checks for M365) use substring matching to identify license plans, which produces false positives and false negatives. For example, a substring match on "Administrator" incorrectly matches both "Global Administrator" (not a license) and "Teams Administrator" (a role, not a license).

The fix involves:
1. Replace substring matching with exact service-plan-ID matching against a validated list of service-plan IDs
2. Obtain the canonical list of M365 service-plan IDs from Microsoft documentation or the tenant's own license data
3. Update the rules to query by exact service-plan ID, not license display name
4. Add MITRE and framework tags to findings

Reference: TECH spec Section 2.1, P1 fixes for MT002/MT003/MT004.

#### Acceptance Criteria

- [ ] Given the MT002/MT003/MT004 rules and a license plan list, when the rules run, then they match licenses by exact service-plan ID (not substring)
- [ ] Given a tenant with both "Global Administrator" role and "Teams Administrator" role, when license-checking rules run, then they do not incorrectly match these roles as licenses
- [ ] Given MT002/MT003/MT004 findings, when they are recorded, then each carries appropriate MITRE tag and framework tags

#### Definition of Done

- [ ] Service-plan-ID reference list compiled and documented (source: Microsoft or tenant data validation)
- [ ] Rules updated to use exact service-plan ID matching (not substring)
- [ ] Old substring matching code removed
- [ ] MITRE and framework tags added to findings
- [ ] Unit test added: license checks use exact service-plan ID matching
- [ ] Manual QA sign-off: test tenant with various license and role combinations
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in existing license validation logic
- [ ] ROADMAP.md status updated

---

### DELA-BLA-10: Add MITRE ATT&CK Tags to All Rule Metadata

**Phase:** P1
**Type:** Feature
**Owner:** Backend (Security Engineering)
**Depends on:** None
**Gates:** DELA-BLA-16
**Status:** To Do

#### Description

Every BLA check/rule must carry static MITRE ATT&CK metadata. This metadata is inherited by every finding generated by that rule and is used to:
1. Label edges in the attack-path graph with MITRE technique IDs
2. Provide the MITRE reference in the node/edge detail panels
3. Display MITRE tactics in the engine matrix and PDF

The task involves:
1. Creating a new static mapping table `backend/src/bl_rules/mitre_mapping.py` with check-ID-to-MITRE-technique-ID mappings
2. Adding `attack: { tactic_ids: [], technique_ids: [] }` to the `TASK_META` dict in every BLA rule
3. Validating the mappings against the TECH spec Section 2.2 and the original stakeholder spec
4. Adding unit tests to verify all rules have non-empty MITRE tags

The mapping table structure:
```python
MITRE_MAPPING = {
    "IH001": {"tactic_ids": ["TA0004"], "technique_ids": ["T1078.004"]},
    "IH002": {"tactic_ids": ["TA0004"], "technique_ids": ["T1078.004"]},
    ...
    "MT011": {"tactic_ids": ["TA0007"], "technique_ids": ["T1003.xxx"]},
}
```

Reference: UW-001 Step 9; TECH spec Section 2.2 edge types; TECH spec Section 3.1 attack response format.

#### Acceptance Criteria

- [ ] A new `mitre_mapping.py` module exists in `backend/src/bl_rules/`
- [ ] The mapping table includes all BLA rules (IH001–IH009, MT001–MT011, PH001–PH005, II001–II005, plus any others)
- [ ] Every rule's `TASK_META` includes `attack: { tactic_ids: [...], technique_ids: [...] }` (non-empty)
- [ ] Mapping table is documented with source (MITRE ATT&CK framework + stakeholder spec)
- [ ] Unit test verifies all rules have non-empty MITRE tags
- [ ] Unit test verifies all technique IDs are valid MITRE technique IDs (e.g., start with T followed by digits)

#### Definition of Done

- [ ] `mitre_mapping.py` created with all rule-to-MITRE mappings
- [ ] All rule files updated with `attack` metadata in `TASK_META`
- [ ] Mapping table validated against TECH spec Section 2.2 and stakeholder spec
- [ ] Unit test: all rules have non-empty MITRE tags
- [ ] Unit test: all technique IDs are valid format
- [ ] Code reviewed by Tech Lead and Security Engineer
- [ ] No regressions in existing rule execution
- [ ] ROADMAP.md status updated

---

### DELA-BLA-11: Add NIST/ISO/Essential-Eight Tags to Findings

**Phase:** P1
**Type:** Feature
**Owner:** Backend (Compliance Engineering)
**Depends on:** None
**Gates:** DELA-BLA-18 (Posture View), DELA-BLA-19 (PDF Appendix B)
**Status:** To Do

#### Description

Every BLA finding must carry static framework compliance tags that map the finding to NIST CSF 2.0, ISO 27001 Annex A, and Essential Eight. These tags are used to:
1. Aggregate findings into framework compliance roll-ups for the Posture View
2. Display framework context in the PDF Appendix B
3. Provide compliance mapping in individual finding records

The task involves:
1. Creating a new static mapping table `backend/src/bl_rules/framework_mapping.py` with check-ID-to-framework-tag mappings
2. Adding `framework: { nist_csf_subcategory, iso27001_annex_a, essential8_mitigation, maturity_level }` to the `TASK_META` dict in every BLA rule
3. Validating mappings against NIST CSF 2.0, ISO 27001:2022 Annex A, and Essential Eight documentation
4. Adding unit tests to verify all rules have framework tags

The mapping table structure:
```python
FRAMEWORK_MAPPING = {
    "IH001": {
        "nist_csf_subcategory": "PR.AC-1",
        "iso27001_annex_a": "A.9.2.3",
        "essential8_mitigation": "Restrict administrative privileges",
        "maturity_level": 1
    },
    ...
}
```

Some checks may not map to all frameworks (e.g., "Not assessed by BLA"). Those fields can be null or omitted.

Reference: UW-001 Step 10; TECH spec Section 2.2, Section 3.4 posture response format.

#### Acceptance Criteria

- [ ] A new `framework_mapping.py` module exists in `backend/src/bl_rules/`
- [ ] The mapping table includes all BLA rules with at least one framework tag per rule
- [ ] Every rule's `TASK_META` includes `framework: { ... }` with applicable tags (non-null fields)
- [ ] Mapping table is validated against NIST CSF 2.0, ISO 27001:2022, and Essential Eight official documentation
- [ ] Unit test verifies all rules have at least one framework tag
- [ ] Unit test verifies framework tag formats (e.g., NIST subcategory is "PR.AC-1" not "PR-AC-1")

#### Definition of Done

- [ ] `framework_mapping.py` created with all rule-to-framework mappings
- [ ] All rule files updated with `framework` metadata in `TASK_META`
- [ ] Mapping table validated against framework documentation
- [ ] Unit test: all rules have at least one non-null framework tag
- [ ] Unit test: framework tag formats are correct (subcategory, annex section, mitigation name, maturity level)
- [ ] Code reviewed by Tech Lead and Compliance Engineer
- [ ] No regressions in existing rule execution
- [ ] ROADMAP.md status updated

---

### DELA-BLA-12: Remove Live Threat Detection from BLA

**Phase:** P1
**Type:** Change
**Owner:** Backend + Frontend (MSSP)
**Depends on:** None
**Gates:** None
**Status:** To Do

#### Description

The BLA currently includes a "Threat Detection" engine that attempts to detect live attack behavior. Per CEO decision, this engine is out of scope for the one-off BLA scan (which is a static assessment) and is reserved for the paid continuous-monitoring product. The Threat Detection engine must be removed from:
1. BLA scoring logic in `backend/src/aws/lambdas/bl_handler.py` (remove any Threat Detection contribution to the headline score)
2. Engine matrix display in frontend BLA dashboard
3. MSSP Partner Portal engine list in `mssp_partner/src/pages/reports/ReportsPage.tsx` (remove "Threat Detection" from ENGINE_ORDER array)
4. PDF report in both client portal and MSSP portal (remove Threat Detection section)

No new code is written; this is a deletion/removal task.

Reference: UW-001 Out of Scope; TECH spec Section 2.1, v1 removal; spec Section 1, "Live Threat Detection is **removed** from BLA".

#### Acceptance Criteria

- [ ] Threat Detection engine is no longer referenced in BLA scoring
- [ ] Threat Detection engine is removed from the engine matrix in the frontend BLA component
- [ ] Threat Detection is removed from the MSSP portal's ENGINE_ORDER array
- [ ] Threat Detection is removed from both client portal and MSSP portal PDF reports
- [ ] BLA tests do not reference Threat Detection
- [ ] No orphaned code or constants remain for Threat Detection in BLA

#### Definition of Done

- [ ] Backend scoring code audited and all Threat Detection references removed
- [ ] Frontend engine matrix code updated to exclude Threat Detection
- [ ] MSSP portal ReportsPage.tsx updated (ENGINE_ORDER and sanitizeEngineDetails)
- [ ] PDF report components updated (both client and MSSP)
- [ ] Test suite updated (no tests reference Threat Detection for BLA)
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in remaining 5 engines (IH, PH, II, M365, AD)
- [ ] ROADMAP.md status updated

---

### DELA-BLA-13: Prerequisite — Role-Template-ID Privilege Resolution

**Phase:** P1
**Type:** Feature
**Owner:** Backend
**Depends on:** None
**Gates:** DELA-BLA-7, DELA-BLA-8
**Status:** To Do

#### Description

Several IH rules (IH004, IH007, IH009, IH010, IH011, IH013, and others) detect privileged roles by matching against display-name substrings (e.g., "admin" substring matches "Global Administrator", "Helpdesk Administrator", "Printer Administrator", etc.). This produces false positives and false negatives.

The fix involves:
1. Creating a new module `backend/src/bl_rules/role_template_ids.py` containing the authoritative list of privileged role template IDs from Azure/Microsoft
2. Exporting constants for Tier-0 roles (Global Admin, Exchange Admin, SharePoint Admin, etc.) and Tier-1 roles (Helpdesk, Password Admin, etc.)
3. Updating all affected rules to use role template ID matching instead of substring matching
4. Validating the role template ID list against Microsoft documentation

The module structure:
```python
# Tier-0 Roles (full tenant control)
TIER_0_ROLE_IDS = {
    "62e90394-69f5-4237-9190-012177145e10": "Global Administrator",
    "00a0a200-00a0-00a0-00a0-00a0a0a0a0a0": "Exchange Administrator",
    ...
}

# Tier-1 Roles (limited admin)
TIER_1_ROLE_IDS = {
    "729827e3-9c14-49f7-bb1b-9cd0d2dd3370": "Helpdesk Administrator",
    ...
}
```

Reference: TECH spec Section 1, "role template IDs (not display-name substring matching)"; TECH spec Section 2.1, Module boundaries.

#### Acceptance Criteria

- [ ] A new `role_template_ids.py` module exists in `backend/src/bl_rules/`
- [ ] Tier-0 and Tier-1 role constants are defined with authoritative Microsoft role template IDs
- [ ] The constants are validated against Microsoft Azure AD documentation
- [ ] Rules IH004, IH007, IH009, IH010, IH011, IH013 are updated to use template ID matching (separate from this ticket, but gates depend on this one)
- [ ] Unit test verifies role template IDs are correctly formatted UUIDs

#### Definition of Done

- [ ] `role_template_ids.py` created with Tier-0 and Tier-1 role definitions
- [ ] Role template IDs sourced from Microsoft official documentation and validated
- [ ] Module includes docstring explaining the source of role IDs
- [ ] Unit test: role template IDs are valid UUID format
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in existing role detection logic
- [ ] ROADMAP.md status updated

---

### DELA-BLA-14: Extract Shared Helpers (Tech Debt)

**Phase:** P2
**Type:** Refactor
**Owner:** Backend
**Depends on:** None
**Gates:** DELA-BLA-15
**Status:** To Do

#### Description

The BLA rule modules contain duplicated code for retry logic, pagination (handling `@odata.nextLink`), group-expansion traversal, and consumer-domain list generation. These helpers must be consolidated into a single shared module before the v2 scoring work begins to avoid duplicating the same fixes across divergent code paths.

The task involves:
1. Creating a new module `backend/src/bl_rules/shared_helpers.py` containing:
   - `retry_with_backoff(func, max_retries=3, backoff_factor=2)` — exponential backoff wrapper
   - `paginate_graph_api(initial_response, client)` — handles `@odata.nextLink` iteration
   - `expand_group_membership(group_id, client)` — recursive group traversal
   - `get_consumer_domains()` — returns list of non-tenant consumer domains to exclude (outlook.com, gmail.com, etc.)
2. Refactoring existing rules to import and use these helpers instead of duplicating code
3. Adding unit tests for each helper function

Reference: TECH spec Section 2.1, Module boundaries; TECH spec Section 5.1, `shared_helpers.py` new file.

#### Acceptance Criteria

- [ ] A new `shared_helpers.py` module exists in `backend/src/bl_rules/`
- [ ] Retry, pagination, group-expansion, and consumer-domain helpers are implemented
- [ ] At least 3 existing rules are refactored to use the shared helpers (proof of consolidation)
- [ ] Unit test added for each helper function covering normal case and error cases
- [ ] Pagination helper correctly follows `@odata.nextLink` chains
- [ ] Group-expansion helper prevents infinite loops (cycle detection)

#### Definition of Done

- [ ] `shared_helpers.py` created with all four helper functions
- [ ] Helpers extracted from existing rules (at least 3 rules refactored)
- [ ] Unit test: retry logic performs backoff correctly
- [ ] Unit test: pagination follows @odata.nextLink correctly
- [ ] Unit test: group expansion traverses nested groups without infinite loops
- [ ] Unit test: consumer domain list is non-empty and contains expected entries
- [ ] Code reviewed by Tech Lead
- [ ] All existing tests still pass after refactoring
- [ ] No regressions in rule behavior
- [ ] ROADMAP.md status updated

---

### DELA-BLA-15: v2 Scoring Engine — Full Replacement

**Phase:** P2
**Type:** Feature
**Owner:** Backend
**Depends on:** DELA-BLA-1, DELA-BLA-2, DELA-BLA-3, DELA-BLA-4, DELA-BLA-5, DELA-BLA-6, DELA-BLA-7, DELA-BLA-8, DELA-BLA-9, DELA-BLA-10, DELA-BLA-11, DELA-BLA-14
**Gates:** DELA-BLA-16, DELA-BLA-17
**Status:** To Do

#### Description

This is the core of Phase 3: a complete replacement of the v1 scoring engine with the v2 noisy-OR probabilistic model. The v1 scoring block (lines 565–616 in `bl_handler.py`) is deleted and replaced entirely. No shadow mode, no dual-write, no feature flag — v2 is the only scoring path for all new scans.

The task involves:
1. Creating a new module `backend/src/aws/lambdas/bl_scoring_v2.py` containing:
   - `compute_finding_weight(severity, ease_of_exploit, impact, reachability_premium) -> float` — computes r_f per TECH spec Section 2.1
   - `compute_engine_score(finding_weights: list[float], severity_cap=50) -> float` — noisy-OR formula
   - `compute_headline_score(engine_scores: dict[str, float], engine_weights: dict[str, int]) -> float` — weighted headline
   - `assign_risk_label(headline_score: float) -> RiskRating` — band-to-label mapping
   - Helper: `compute_risk_delta(findings, excluded_finding_id) -> float` — for remediation roadmap

2. Updating `backend/src/aws/lambdas/bl_handler.py`:
   - Remove the entire v1 scoring block (lines 565–616)
   - Add a two-pass orchestration:
     - Pass 1: Call DELA-BLA-16 graph engine to compute P(f) reachability premiums
     - Pass 2: Call v2 scoring functions with P(f) values
   - Persist results to `BLRiskInfo` with new fields: `scoringModelVersion: "v2"`, `riskLabel`, `verdictText`, `engineSubScores[]`, `enginesActive[]`, `kpis`, `adIntegrationState`

3. Creating comprehensive unit tests for all scoring functions with known input/output pairs

4. Adding the new `BLAttackGraph` DynamoDB table to `serverless.yml` with TTL set to 90 days

Reference: TECH spec Section 2.1 v2 Scoring Engine; TECH spec Section 4 Data Model; spec Section 3.1 GET /portal/bl/identities response format.

#### Acceptance Criteria

- [ ] New `bl_scoring_v2.py` module created with pure functions for finding weight, engine score, headline, label
- [ ] v1 scoring block removed from `bl_handler.py` entirely
- [ ] Handler orchestrates two-pass execution: graph engine (Pass 1) → scoring engine (Pass 2)
- [ ] All findings from `BLResult`, `IHResults`, `M365Result` are read and aggregated
- [ ] `BLRiskInfo` record persisted with v2 fields (scoringModelVersion, riskLabel, verdictText, engineSubScores, enginesActive, kpis, adIntegrationState)
- [ ] Per-engine sub-score computed using noisy-OR formula: `EngineScore_e = 100 * [1 - Product(1 - r_f)]`
- [ ] Headline score computed as weighted average over connected engines only
- [ ] Label assignment follows corrected bands: 75–100=Critical, 50–74=High, 25–49=Medium, 0–24=Low
- [ ] Given Tenant A (1 Critical finding) and Tenant B (1 Critical + 500 High findings), Tenant B scores higher (v2 is monotonic)
- [ ] `BLAttackGraph` table created in serverless.yml with TTL attribute

#### Definition of Done

- [ ] `bl_scoring_v2.py` module created with all required functions
- [ ] v1 scoring code removed from `bl_handler.py`
- [ ] Handler updated for two-pass orchestration (graph → scoring)
- [ ] `BLRiskInfo` schema updated with v2 fields
- [ ] `BLAttackGraph` table added to serverless.yml (HASH: orgId, TTL: 90 days)
- [ ] Unit test: finding weight formula with known values (Critical, Medium, Low severity cases)
- [ ] Unit test: engine score formula (noisy-OR) with known finding weights
- [ ] Unit test: headline score formula (weighted average) with known engine scores
- [ ] Unit test: label assignment (score → label) for all bands
- [ ] Unit test: risk delta computation (remediation impact)
- [ ] Integration test: full v2 pipeline on a synthetic tenant dataset
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in existing BLA functionality
- [ ] Deployed to staging for regression testing before production release
- [ ] ROADMAP.md status updated

---

### DELA-BLA-16: Attack-Path Graph Engine

**Phase:** P2
**Type:** Feature
**Owner:** Backend
**Depends on:** DELA-BLA-10, DELA-BLA-15
**Gates:** DELA-BLA-18
**Status:** To Do

#### Description

The attack-path graph engine is the core of the v2 feature. It builds a directed graph from all findings across all engines, identifies paths from entry points (leaked credentials, misconfigured accounts) to Tier-0 targets (Global Admin, Domain Admin), and computes the reachability premium P(f) that feeds back into v2 scoring.

The task involves:
1. Creating a new module `backend/src/aws/lambdas/bl_graph_engine.py` containing:
   - `build_graph(findings_list) -> Graph` — directed graph with typed nodes and edges
   - `find_paths_to_tier0(graph) -> List[Path]` — reverse-BFS from Tier-0 targets, capped at 4 hops
   - `extract_kpis(paths) -> AttackKPIs` — compute TTGA, leaked admin passwords, standing GAs, admins with MFA, path count
   - `compute_blast_radius(target_node) -> BlastRadius` — reachable resources from Global Admin takeover
   - `rank_paths(paths) -> List[Path]` — rank by shortest hops, then highest cumulative risk delta

2. Node types: User, Group, DirectoryRole, AppRegistration, ServicePrincipal, ManagedIdentity, Device, DomainDC, CertificateTemplate, Mailbox

3. Edge types with MITRE tags: MemberOf (T1078.004), HasRole (T1078.004), CanAddCredential (T1098.001), OwnsApp (T1098.001), GrantsHighRiskPermission (T1098.003), LeakedCredential (T1589.001), GenericAll/WriteDACL/ForceChangePassword (T1098), ADCS ESC1–8 (T1649), FederatesWith (T1606.002)

4. Persisting results to `BLAttackGraph` table with structure: `{orgId, assessmentDate, totalPathCount, primaryPath, additionalPaths[], blastRadius, kpis, remediation, posture}`

5. Adding comprehensive unit tests with synthetic graph data

Reference: TECH spec Section 2.2 Attack-Path Graph Engine; TECH spec Section 4.3 `BLAttackGraph` table; TECH spec Section 3.2 GET /portal/bl/attack-path response format.

#### Acceptance Criteria

- [ ] Graph engine module created with graph construction and pathfinding functions
- [ ] Directed graph built from findings with correct node types and edge types
- [ ] Reverse-BFS pathfinding implemented, capped at 4 hops
- [ ] Reachability premium P(f) computed for edges on confirmed paths (range 0–1.2)
- [ ] KPI extraction computes: TTGA (minimum hops), leaked admin passwords count, standing Global Admin count, admins with MFA count, total path count
- [ ] Paths ranked by shortest hops, then highest cumulative risk delta
- [ ] Blast radius computed entirely from existing DynamoDB scan data (no new Graph API calls)
- [ ] Graph data persisted to `BLAttackGraph` with correct schema
- [ ] Primary path selected (most critical path by default)
- [ ] Additional paths stored for later retrieval
- [ ] Given a tenant with 10 paths to Tier-0, when graph engine runs, then all 10 are found and ranked (totalPathCount = 10)

#### Definition of Done

- [ ] `bl_graph_engine.py` module created with all required functions
- [ ] Graph construction validates node and edge types match TECH spec Section 2.2
- [ ] Reverse-BFS implementation includes 4-hop cap and cycle detection
- [ ] KPI extraction computes all 5 KPIs correctly
- [ ] Blast radius returned for Tier-0 targets (no new Graph API calls)
- [ ] Unit test: graph construction with synthetic findings
- [ ] Unit test: reverse-BFS finds paths to Tier-0, respects 4-hop cap
- [ ] Unit test: reachability premium P(f) set to 0 for non-path edges, >0 for path edges
- [ ] Unit test: KPI extraction (TTGA, leaked passwords, GAs, MFA, path count)
- [ ] Unit test: path ranking (shortest hops first, then highest risk delta)
- [ ] Unit test: blast radius computed without additional Graph API calls
- [ ] Integration test: full graph engine on a synthetic multi-engine tenant
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in scoring or rule execution
- [ ] Graph persist to `BLAttackGraph` verified
- [ ] ROADMAP.md status updated

---

### DELA-BLA-17: Conditional-AD Scoring Contract

**Phase:** P2
**Type:** Feature
**Owner:** Backend
**Depends on:** DELA-BLA-15
**Gates:** None
**Status:** To Do

#### Description

When AD is not integrated, the AD engine must be entirely absent from the scoring calculation — not null, not zero, not an error state. This requires updating the aggregator logic in the v2 scoring pipeline to conditionally include/exclude the AD engine and its weight based on whether AD findings exist for the tenant.

The task involves:
1. In the v2 scoring orchestrator (`bl_handler.py`), after reading all findings from the three result tables (BLResult, IHResults, M365Result), check if any AD findings exist
2. Set `adIntegrationState` in the `BLRiskInfo` record: `"integrated"` (AD findings exist), `"not_integrated"` (no AD findings), or `"hybrid_signals_detected"` (Entra Connect present but no AD findings)
3. When computing the headline score, iterate only over `enginesActive` (IH, PH, II, M365, AD if integrated). Do not include AD weight if `adIntegrationState !== "integrated"`
4. Store `enginesActive[]` and `scoringModelVersion` in the `BLRiskInfo` record so historical PDFs can be reproduced (same engines that ran at scan time are documented)
5. Update the `/portal/bl/identities` API response to include `adIntegrationState` and `enginesActive` fields

Reference: TECH spec Section 2.1 v2 Scoring Engine; TECH spec Section 2.3 Aggregator Cross-Table Read Pattern; TECH spec Section 3.1 /portal/bl/identities response.

#### Acceptance Criteria

- [ ] Given a tenant with no AD findings, when v2 scoring runs, then `adIntegrationState = "not_integrated"` and AD engine is absent from `enginesActive`
- [ ] Given a tenant with AD findings, when v2 scoring runs, then `adIntegrationState = "integrated"` and AD engine is included in `enginesActive` with weight 25
- [ ] Given Entra Connect detected but no AD findings, when v2 scoring runs, then `adIntegrationState = "hybrid_signals_detected"` and AD engine is absent from scoring
- [ ] When computing headline score, AD weight is only included if AD is integrated
- [ ] `BLRiskInfo` record includes `enginesActive[]` and `scoringModelVersion` for historical reproducibility
- [ ] API response includes `adIntegrationState` and `enginesActive` fields

#### Definition of Done

- [ ] Aggregator logic updated to conditionally include/exclude AD engine
- [ ] `adIntegrationState` computed and stored in `BLRiskInfo`
- [ ] `enginesActive[]` populated with only engines that ran
- [ ] Headline score formula checks `enginesActive` list, not a hardcoded engine set
- [ ] `scoringModelVersion` stored for historical tracking
- [ ] Unit test: AD missing → `adIntegrationState = "not_integrated"`, AD absent from scoring
- [ ] Unit test: AD present → `adIntegrationState = "integrated"`, AD weight included
- [ ] Unit test: Entra Connect detected, no AD findings → `hybrid_signals_detected`, AD absent from scoring
- [ ] Unit test: headline score reproduces using `enginesActive` weights only
- [ ] API response verified to include new fields
- [ ] Code reviewed by Tech Lead
- [ ] No regressions in non-AD scoring paths
- [ ] ROADMAP.md status updated

---

### DELA-BLA-18: Attack-Path Dashboard UI

**Phase:** P2
**Type:** Feature
**Owner:** Frontend
**Depends on:** DELA-BLA-16
**Gates:** None
**Status:** To Do

#### Description

This is the major frontend feature: a complete rewrite of the BLA section in the Dela client portal (`frontend/`) to implement the new attack-path dashboard design. The component tree is large and is split into sub-tickets (18a–18f) per the TECH spec Section 6, Phase 3 implementation order.

**DELA-BLA-18a: Attack-Path SVG Graph Component**
- Location: `frontend/src/pages/dashboard/components/BreachLikelihood/BreachLikelihoodV2/components/AttackPath/AttackPathGraph.tsx`
- Renders the directed graph using `reagraph` v4.21.5 with `layoutType="left-right"`
- Custom node shapes (circle, rounded rect, hexagon, etc.) based on entity type
- Node border colors encode severity (Critical red, High orange, etc.)
- Edge labels show relationship type (MemberOf, HasRole, etc.)
- Hot edges (on attack path) pulse with glow animation
- Supports node/edge click handlers for detail panels
- Supports filtering (AD toggle hides AD-tagged nodes/edges)
- Responsive layout, minimum 360px height

**DELA-BLA-18b: Node/Edge Detail Panels, Walk Animation, Blast Radius**
- `NodeDetailPanel.tsx` / `EdgeDetailPanel.tsx` — antd Drawer (right-side, mask=false)
- `WalkAnimation.tsx` — step-by-step animator using requestAnimationFrame
- `BlastRadiusOverlay.tsx` — motion.div slide-up overlay with reachable resources
- `PathCycler.tsx` — count chip + chevron buttons to navigate additional paths
- Auto-play walk animation when Critical score on load

**DELA-BLA-18c: Engine Matrix with Drill-Down, AD Upsell**
- `EngineMatrix.tsx` — custom HTML table (not antd Table) with severity count chips
- `EngineMatrixRow.tsx` — per-engine row with sub-score and weights
- `DrillDownPanel.tsx` — antd Collapse showing findings when cell clicked
- `ADUpsellBanner.tsx` — full-weight banner when AD not integrated
- Conditional rendering: AD row when integrated, upsell when not

**DELA-BLA-18d: Remediation List**
- `RemediationList.tsx` + `RemediationItem.tsx` — ranked items with risk delta
- Expandable items showing description, MITRE reference, paths severed
- No network call; data already fetched on mount

**DELA-BLA-18e: Posture View**
- `PostureView.tsx` — toggle wrapper for Attack/Posture views
- `NISTCSFPanel.tsx` — NIST CSF 2.0 progress bars per function
- `ISO27001Panel.tsx` — ISO 27001 Annex A progress bars
- `EssentialEightPanel.tsx` — Essential Eight maturity dots
- Uses antd Progress for bars, custom dots for maturity levels
- Client-side toggle (no network call)

**DELA-BLA-18f: Wiring to Live API**
- Replace stub/mock data with calls to real API endpoints: `/portal/bl/identities`, `/portal/bl/attack-path`, `/portal/bl/remediation`, `/portal/bl/posture`
- Create react-query hooks: `useBreachLikelihood`, `useAttackPath`, `useRemediation`, `usePosture`
- Hero section with animated score ring (ECharts), verdict text, KPI cluster
- Severity chips (color + shape + text) consistent across all surfaces

Reference: TECH spec Section 2.5 Frontend Dashboard Architecture; TECH spec Section 3 API Contracts; DESIGN spec Section 4 Component Architecture; DESIGN spec Section 5 Component Specifications.

#### Acceptance Criteria (High-Level)

- [ ] All sub-components rendered correctly with live API data
- [ ] Score ring animates on load (count-up over 1.2 seconds)
- [ ] Attack-path graph renders with correct node shapes and edge labels
- [ ] Walk animation auto-plays once on load (Critical score only)
- [ ] Node click reveals detail panel within 300ms (SC-005)
- [ ] Engine matrix displays correct severity count chips
- [ ] Drill-down panel shows findings for clicked cell
- [ ] AD toggle updates graph, matrix, and headline within 1 second (SC-009)
- [ ] Attack/Posture toggle completes in under 200ms (SC-008)
- [ ] Posture view shows NIST, ISO, Essential Eight panels
- [ ] All severity chips use color + shape + text (no color-only encoding)
- [ ] PDF download available from dashboard
- [ ] No console errors or regressions in dashboard functionality

#### Definition of Done (All Sub-Tickets)

Each sub-ticket will have its own DoD, but collectively:
- [ ] All new components built per DESIGN spec Section 4
- [ ] All components use correct Ant Design base components (antd v5.20.5)
- [ ] Graph uses `reagraph` v4.21.5 (confirmed installed)
- [ ] Animations use `motion` v12 (confirmed installed)
- [ ] Score ring uses ECharts v6.1.0 (confirmed installed)
- [ ] All TypeScript types defined in `bla-types.ts`
- [ ] React-query hooks created for all 4 API endpoints
- [ ] Code reviewed by Frontend Tech Lead
- [ ] All components tested (component tests, integration tests)
- [ ] Accessibility verified (keyboard nav, ARIA labels, color contrast)
- [ ] Responsive layout verified (desktop, tablet, mobile)
- [ ] Live API integration tested against staging backend
- [ ] PDF generation verified to include new data
- [ ] ROADMAP.md status updated

---

### DELA-BLA-19: Redesigned PDF (Story + Roadmap + Framework)

**Phase:** P2
**Type:** Feature
**Owner:** Frontend + Backend
**Depends on:** DELA-BLA-16, DELA-BLA-11
**Gates:** None
**Status:** To Do

#### Description

The BLA PDF is redesigned from a simple score-and-evidence dump to a fear-first, actionable report with 10 pages + conditional appendices. This is split into sub-tickets (19a–19d) per the TECH spec Section 6, Phase 4 implementation order.

**DELA-BLA-19a: PDF Cover + Engine Summary Pages**
- Page 1: Cover with animated score ring, verdict text, TTGA headline stat, tenant metadata
- Page 3: Engine Summary matrix with MITRE tactic tags per engine, per-engine sparklines (mini trend lines)
- Uses existing PDF utilities (`@react-pdf/renderer` v4.3.0, already installed)

**DELA-BLA-19b: PDF Attack-Path Story Page**
- Page 2: Executive narrative with static SVG-to-image render of primary attack path
- 3-step caption narrative naming real accounts (fear-first, non-technical)
- Fallback: if image render fails, text-based step list
- Image captured via `html-to-image` library or equivalent

**DELA-BLA-19c: PDF Remediation Roadmap + Framework Appendix**
- Page 6: Prioritized Remediation Roadmap with ranked actions, risk delta per action, paths severed
- Page 10: Appendix B with NIST CSF / ISO 27001 / Essential Eight roll-up in board-forwardable format
- Uses posture data from API response

**DELA-BLA-19d: PDF Conditional-AD Appendix + Severity Pattern Fills**
- Appendix C: Shows AD hybrid findings if integrated; full-weight upsell card if not (never "0" score)
- All severity chips in all PDF pages use color + shape + text + pattern fill (Critical=crosshatch, High=diagonal, Medium=dots, Low=empty)
- Pattern fills enable black-and-white printing accessibility

Reference: TECH spec Section 2.6 PDF Redesign; DESIGN spec Section 7 PDF Structure; spec Section 9 Accessibility & Printing.

#### Acceptance Criteria (High-Level)

- [ ] PDF generates within 15 seconds (SC-010)
- [ ] All 10 pages + appendices render with correct content
- [ ] Attack-path story page includes static graph image (or fallback text)
- [ ] Remediation roadmap shows ranked actions with risk delta
- [ ] Framework appendix shows NIST CSF, ISO 27001, Essential Eight
- [ ] AD appendix shows findings if integrated, upsell if not (never "0")
- [ ] All severity chips use color + shape + text + pattern fill
- [ ] PDF is accessible (no color-only encoding, readable in B&W)
- [ ] Score trend chart annotates v2 cutover date
- [ ] PDF download available from both client portal and MSSP portal

#### Definition of Done (All Sub-Tickets)

Each sub-ticket will have its own DoD, but collectively:
- [ ] All PDF pages implemented using `@react-pdf/renderer` v4.3.0
- [ ] Attack-path image capture working (html-to-image or equivalent)
- [ ] Fallback text-based path rendering implemented if image fails
- [ ] Severity pattern fills applied to all chips (PDF only, not web)
- [ ] Font family (Inter) configured for PDF generation
- [ ] Header and footer applied to all pages
- [ ] Page numbering correct (1–10 + appendices)
- [ ] Code reviewed by Frontend Tech Lead
- [ ] PDF tested on staging: generate, download, open in multiple PDF readers
- [ ] Accessibility verified: Deuteranopia color-blind simulation review (SC-011)
- [ ] B&W printing test: pattern fills render correctly in grayscale
- [ ] MSSP portal PDF download updated (same structure)
- [ ] ROADMAP.md status updated

---

## Dependency Map

```
P0 Bug Fixes (DELA-BLA-1–6)
  │
  ├─→ DELA-BLA-2 (regression tests)
  │
P1 Correctness + Tagging
  │
  ├─ DELA-BLA-13 (role template IDs) ──┬──→ DELA-BLA-7 (IH001 MFA)
  │                                     ├──→ DELA-BLA-8 (MT severity)
  │
  ├─ DELA-BLA-10 (MITRE tags) ──────────────→ DELA-BLA-16 (graph engine)
  │
  ├─ DELA-BLA-11 (framework tags) ────────────→ DELA-BLA-18e (posture view)
  │                                            DELA-BLA-19c (PDF framework)
  │
  ├─ DELA-BLA-12 (remove Threat Detection)
  │
  ├─ DELA-BLA-9 (license matching)
  │
P2 v2 Build
  │
  ├─ DELA-BLA-14 (shared helpers) ────→ DELA-BLA-15 (v2 scoring)
  │                                          │
  │                                          ├──→ DELA-BLA-16 (graph engine)
  │                                          ├──→ DELA-BLA-17 (conditional AD)
  │                                          ├──→ DELA-BLA-18 (dashboard UI)
  │                                          └──→ DELA-BLA-19 (PDF redesign)
  │
  └─ DELA-BLA-16 (graph engine) ──────────────→ DELA-BLA-18a (graph component)
                                               DELA-BLA-19b (PDF story page)
```

## Recommended Implementation Order

**Phase 1 — P0 Bug Fixes (2 weeks)**
1. DELA-BLA-1 — Label-swap fix (backend + frontend)
2. DELA-BLA-2 — Regression tests (depends on DELA-BLA-1)
3. DELA-BLA-3, DELA-BLA-4, DELA-BLA-5, DELA-BLA-6 — Bug fixes (parallel)

**Phase 2 — P1 Correctness + Tagging (3 weeks)**
4. DELA-BLA-13 — Role template IDs (independent)
5. DELA-BLA-10, DELA-BLA-11 — MITRE + framework tagging (parallel, independent)
6. DELA-BLA-7, DELA-BLA-8 — IH rules (depend on DELA-BLA-13)
7. DELA-BLA-9 — License matching (independent)
8. DELA-BLA-12 — Remove Threat Detection (independent)

**Phase 3 — P2 v2 Build (5 weeks, can parallelize)**
9. DELA-BLA-14 — Shared helpers (independent)
10. **Backend (parallel):**
    - DELA-BLA-15 — v2 scoring (depends on DELA-BLA-14)
    - DELA-BLA-16 — Graph engine (depends on DELA-BLA-10, DELA-BLA-15)
    - DELA-BLA-17 — Conditional AD (depends on DELA-BLA-15)
11. **Frontend (parallel, after DELA-BLA-16):**
    - DELA-BLA-18a — Graph component
    - DELA-BLA-18b — Detail panels + walk animation
    - DELA-BLA-18c — Engine matrix
    - DELA-BLA-18d — Remediation list
    - DELA-BLA-18e — Posture view (depends on DELA-BLA-11)
    - DELA-BLA-18f — Live API wiring
12. DELA-BLA-19a–19d — PDF redesign (parallel, depends on DELA-BLA-16, DELA-BLA-11)

---

## Ticket Status Summary

| Ticket | Title | Phase | Owner | Status |
|--------|-------|-------|-------|--------|
| DELA-BLA-1 | Fix High/Critical label swap | P0 | Backend + Frontend | To Do |
| DELA-BLA-2 | Regression tests for score bands | P0 | Backend | To Do |
| DELA-BLA-3 | IH005 duplicate-account false pass (GATE) | P0 | Backend | To Do |
| DELA-BLA-4 | IH008 JIT false-pass on empty PIM data (GATE) | P0 | Backend | To Do |
| DELA-BLA-5 | MT011 Intune compliance count & pagination (GATE) | P0 | Backend | To Do |
| DELA-BLA-6 | Org-level rules: empty-on-exception → error state (GATE) | P0 | Backend | To Do |
| DELA-BLA-7 | IH001 MFA: pagination + capability flag | P1 | Backend | To Do |
| DELA-BLA-8 | MT005/MT006/MT010 severity & direction | P1 | Backend | To Do |
| DELA-BLA-9 | MT002/MT003/MT004 licence substring matching | P1 | Backend | To Do |
| DELA-BLA-10 | Add MITRE ATT&CK tags to all rule metadata | P1 | Backend | To Do |
| DELA-BLA-11 | Add NIST/ISO/Essential-Eight tags to findings | P1 | Backend | To Do |
| DELA-BLA-12 | Remove live Threat Detection from BLA | P1 | Backend + Frontend | To Do |
| DELA-BLA-13 | Prerequisite — role-template-ID privilege resolution | P1 | Backend | To Do |
| DELA-BLA-14 | Extract shared helpers (tech debt) | P2 | Backend | To Do |
| DELA-BLA-15 | v2 scoring engine — full replacement | P2 | Backend | To Do |
| DELA-BLA-16 | Attack-path graph engine | P2 | Backend | To Do |
| DELA-BLA-17 | Conditional-AD scoring contract | P2 | Backend | To Do |
| DELA-BLA-18 | Attack-path dashboard UI (sub: 18a–18f) | P2 | Frontend | To Do |
| DELA-BLA-19 | Redesigned PDF (sub: 19a–19d) | P2 | Frontend + Backend | To Do |

---

## Notes for Engineers

### Phase 1 Execution (P0 Bug Fixes)
- All 6 P0 tickets must pass QA before Phase 2 begins
- Tickets DELA-BLA-3, DELA-BLA-4, DELA-BLA-5, DELA-BLA-6 add `GATED = True` flags to rules; gates removed after QA sign-off
- Label-swap fix (DELA-BLA-1) ships simultaneously on backend and frontend

### Phase 2 Execution (P1 Correctness + Tagging)
- DELA-BLA-10 and DELA-BLA-11 are security/compliance engineering tasks; can run in parallel
- DELA-BLA-13 must complete before DELA-BLA-7 and DELA-BLA-8 start
- Threat Detection removal (DELA-BLA-12) is independent; no timeline dependency

### Phase 3 Execution (P2 v2 Build)
- DELA-BLA-15 is the critical path: v2 scoring must be complete before graph engine can validate reachability premium
- DELA-BLA-16 depends on both DELA-BLA-10 (MITRE tags) and DELA-BLA-15 (finding weights)
- Frontend (DELA-BLA-18) can start component development in parallel once DELA-BLA-16 API schema is agreed
- PDF (DELA-BLA-19) should not start until DELA-BLA-16 is ready for API integration testing

### Release Coordination
- **Deployment order is critical:** DynamoDB table (`BLAttackGraph`) → Backend Lambda → Frontend → MSSP Portal
- No feature flags or shadow mode — v2 is the only path after release
- Score trend chart must annotate v2 cutover date
- Sales/CS briefing MANDATORY before production release

---

## File Paths for Reference

- UW doc: `/Users/eson/Documents/Dela/.AI-DOC/workflows/UW-001-bla-attack-path-dashboard.md`
- TECH spec: `/Users/eson/Documents/Dela/.AI-DOC/specs/TECH-001-bla-attack-path-dashboard.md`
- DESIGN spec: `/Users/eson/Documents/Dela/.AI-DOC/specs/DESIGN-001-bla-attack-path-dashboard.md`
- Original spec: `/Users/eson/Documents/Dela/specs/001-bla-attack-path-dashboard/spec.md`
- Roadmap: `/Users/eson/Documents/Dela/.AI-DOC/roadmap/ROADMAP.md`

---

**Awaiting engineer confirmation to proceed with backend and frontend implementation.**
