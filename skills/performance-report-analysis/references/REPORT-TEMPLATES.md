# Performance Report Templates

## When to load this file

Load when you are ready to produce the final technical or business report draft.
Contains ready-to-fill templates with field-by-field guidance.

---

## Template 1 — Technical Report (Full)

For: engineers, QA leads, architects, DevOps/SRE teams.
Tone: precise, data-driven, actionable.
Length: 1–3 pages typical.

```markdown
# Performance Test Technical Report

| Field | Value |
|---|---|
| Date | [YYYY-MM-DD] |
| Test type | [Smoke / Load / Stress / Spike / Endurance] |
| Tool | [k6 / Gatling / Locust / JMeter / Artillery / other] |
| Environment | [staging / perf / production-clone] |
| Tester | [name or team] |
| Test duration | [X minutes] |
| Peak load | [X concurrent users / X RPS] |
| Baseline available | Yes — [date of baseline] / No |

---

## Executive Summary

[3 sentences maximum. State: (1) what was tested and at what load, (2) whether SLAs
were met overall, (3) the single most important finding or recommendation.]

---

## Load Profile

| Stage | Users | Duration | Ramp rate |
|---|---|---|---|
| Warm-up | [X] | [Xm] | [X users/sec] |
| Steady state | [X] | [Xm] | — |
| Ramp-down | — | [Xm] | — |

---

## SLA Compliance

| Metric | Target | Actual (p50) | Actual (p95) | Actual (p99) | Result |
|---|---|---|---|---|---|
| [endpoint or global] | [X ms] | [Y ms] | [Y ms] | [Y ms] | PASS / FAIL |
| Error rate | < [X]% | — | — | [Y]% | PASS / FAIL |
| Throughput | ≥ [X] RPS | — | — | [Y] RPS | PASS / FAIL |

---

## Findings

### [CRITICAL | HIGH | MEDIUM | LOW | INFO] — [Short descriptive title]

**Observed:**
[Exact numbers. What metric, at what load level, at what time in the test.]

**Root cause hypothesis:**
[What likely caused this — code, infrastructure, configuration. State as hypothesis
unless confirmed by infra data or profiler.]

**Supporting evidence:**
[Reference to specific metric, trace, log line, or graph. Be specific.]

**Impact:**
[What happens to users or the system if this is not fixed.]

**Recommended action:**
[Concrete next step. Reference BOTTLENECK-PATTERNS.md if needed for detailed options.]

**Owner:** [Team or role]
**Effort estimate:** [Low / Medium / High]
**Retest required:** Yes / No

---
[Repeat Finding section for each issue]

---

## Regression vs. Baseline

[Include only if a baseline exists. Otherwise omit section.]

| Metric | Baseline ([date]) | Current | Delta | Status |
|---|---|---|---|---|
| p95 global | [X ms] | [Y ms] | [+/-Z%] | OK / REGRESSION |
| p99 global | [X ms] | [Y ms] | [+/-Z%] | OK / REGRESSION |
| Error rate | [X%] | [Y%] | [+/-Z pp] | OK / REGRESSION |
| Peak throughput | [X RPS] | [Y RPS] | [+/-Z%] | OK / REGRESSION |

**Regression thresholds used:** p95/p99 > 20% increase = regression; error rate any increase = regression.

---

## Infrastructure Observations

| Resource | Peak value | Threshold | Status |
|---|---|---|---|
| CPU (app servers) | [X%] | 70% | OK / HIGH |
| Memory (app servers) | [X GB / X%] | — | OK / GROWING |
| DB CPU | [X%] | 70% | OK / HIGH |
| DB connections (active/max) | [X/Y] | [Y×80%] | OK / NEAR LIMIT |
| Network I/O | [X MB/s] | — | OK / SATURATED |

**Notes:** [Any observations not captured in the table — GC pause events, auto-scale
triggers, external dependency slowness, alerts fired during the test.]

---

## Recommendations

| Priority | Action | Owner | Status |
|---|---|---|---|
| P1 (block release) | [action] | [team] | Open |
| P2 (fix before next cycle) | [action] | [team] | Open |
| P3 (monitor in production) | [action] | [team] | Open |

---

## Test Conditions and Limitations

[Document anything that limits result validity:]
- Environment differences from production (size, data volume, third-party stubs)
- Known issues during the test (infrastructure events, test interruptions)
- What this test does and does not prove
```

---

## Template 2 — Business Report (Stakeholder Summary)

For: product managers, engineering directors, C-level, sales, customer success.
Tone: plain language, outcome-focused, no raw technical numbers.
Length: 1 page maximum.

```markdown
# Performance Test — Business Summary

| | |
|---|---|
| System tested | [Product or service name, not technical component names] |
| Test conducted | [Month YYYY] |
| Prepared by | [Team name] |

---

## What We Tested

[One paragraph. Describe the scenario in business terms. Example:
"We simulated [X] customers using [feature] simultaneously — representing the expected
traffic during [event, launch, or normal peak]. The test ran for [X] minutes at peak load."]

---

## Is It Ready?

**Verdict:** [One of: Ready to deploy | Not ready — action required | Ready with conditions]

[One to two sentences explaining the verdict in plain language.]

---

## Risks

| Risk | Business impact | Urgency |
|---|---|---|
| [plain-language description of the issue] | [what users or revenue would be affected] | Must fix before launch / Fix within [X weeks] / Monitor |

[Guidance for writing risk descriptions:
- BAD: "p95 response time exceeds SLA by 240ms"
- GOOD: "Approximately 1 in 20 customers experiences checkout delays during peak traffic"]

---

## What Happens If We Launch Now

[Honest, specific prediction of user impact if the system goes live as-is.
Be direct. If there are no blocking issues, say so clearly.
Examples:
- "The system can handle the expected launch traffic with acceptable performance."
- "During peak load, approximately 3% of transactions will fail, resulting in error
  screens for those customers."
- "The service will require a manual restart every 4–6 hours under sustained load,
  causing brief downtime."]

---

## What Needs to Happen Before Launch

[Bullet list. Each item must be in plain language and explain the business reason.]

- **[Action]** — [why this matters to users or the business]
- **[Action]** — [why this matters to users or the business]

[If nothing blocks launch, write: "No blocking issues were identified. The system
meets its performance targets at the expected load."]

---

## What Can Wait

[Optional section. Low-priority items that don't block launch but should be addressed.]

- [Item] — [when to address: post-launch, next sprint, next quarter]

---

## Decision Required

[Include only if a go/no-go decision is pending.]

**Question:** [The decision to be made — typically: launch as scheduled / delay / launch with conditions]

**Options:**

| Option | Benefit | Risk |
|---|---|---|
| [Option A] | [benefit] | [risk] |
| [Option B] | [benefit] | [risk] |

**Recommendation:** [Team's recommended option and one-sentence rationale.]
```

---

## Template 3 — Regression Comparison (Release Gate)

For: QA leads, release managers, engineering leads.
Use when: comparing current release to a previous test result before approving a deployment.

```markdown
# Performance Regression Report — Release [version] vs. [baseline version]

| | |
|---|---|
| Current release | [version / commit] |
| Baseline | [version / date] |
| Date | [YYYY-MM-DD] |
| Environment | [staging / perf] |
| Load profile | Same as baseline: [X users, Y minutes] |

---

## Regression Summary

| Metric | Baseline | Current | Delta | Status |
|---|---|---|---|---|
| p50 global | — | — | — | OK / WARN / FAIL |
| p95 global | — | — | — | OK / WARN / FAIL |
| p99 global | — | — | — | OK / WARN / FAIL |
| Error rate | — | — | — | OK / WARN / FAIL |
| Throughput | — | — | — | OK / WARN / FAIL |

**Status key:**
- OK: within threshold (< 20% for latency, 0 pp for errors)
- WARN: 10–20% regression — monitor; flag for review
- FAIL: > 20% regression or any error rate increase — block release

---

## Release Gate Decision

| | |
|---|---|
| **Gate result** | PASS / FAIL |
| **Blocking findings** | [list or "None"] |
| **Approved by** | [name / role] |
| **Date** | [YYYY-MM-DD] |

---

## Notes

[Document any known differences between baseline and current test run that could
affect comparability: environment changes, dataset differences, test script changes.]
```

---

## Percentile Reference Card

Use when translating percentiles to stakeholder language:

| Percentile | What it means in plain language |
|---|---|
| p50 (median) | Half of users experienced this response time or faster |
| p90 | 9 out of 10 users experienced this or faster |
| p95 | 19 out of 20 users experienced this or faster — most common SLA target |
| p99 | 99 out of 100 users experienced this or faster — used for high-reliability SLAs |
| p99.9 | 999 out of 1000 users — used for financial or safety-critical systems |

**Business translation formula:**
> "p95 = [X ms] (SLA = [Y ms])" → "1 in 20 users waits [X ms] — [X/Y - 1]% [over/under] our target"

**Error rate business translation:**
> "[Z]% error rate" → "approximately [Z] out of every 100 [transactions/requests/checkouts] fail"
