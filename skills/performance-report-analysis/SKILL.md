---
name: performance-report-analysis
description: >
  Guides engineers and QA professionals in interpreting performance test results,
  identifying bottlenecks, and producing two types of reports: a technical report
  (for engineers and QA) and a business report (for stakeholders and executives).
  Use this skill whenever the user shares load test results, CSV stats, HTML reports,
  percentile data, or test output from k6, Gatling, Locust, JMeter, Artillery, or
  any other tool — and wants to understand what the numbers mean, diagnose problems,
  or communicate findings. Trigger on phrases like "analyze my test results",
  "what do these numbers mean", "my p95 is high", "error rate under load",
  "write a performance report", "explain the results to my manager",
  "how do I present this to stakeholders", or "I found a bottleneck".
license: MIT
compatibility: "Claude Code, Cursor, Windsurf. Tool-agnostic: works with output from k6, Gatling, Locust, JMeter, Artillery, and custom tools."
model: sonnet
metadata:
  author: rcampos
  version: "1.1"
  tags: [performance-testing, load-testing, reporting, bottleneck-analysis, stakeholder-communication]
---

# Performance Report Analyzer

Interprets performance test results, identifies bottlenecks, classifies findings
by severity, and produces two structured reports — one technical, one for business
stakeholders. **This skill starts where testing ends.**

**Scope boundary:** This skill covers analysis and communication of results *after*
a test has run. For planning which tests to run, sizing VUs, or setting SLAs, use
`performance-testing-strategy` instead.

## Output Format

After completing Steps 1–3, deliver two artifacts:

1. **Technical Report** — for engineers and QA: raw findings, root cause analysis,
   severity classification, and concrete remediation steps.
2. **Business Report** — for stakeholders: business impact framing, risk rating,
   and recommended decisions — no raw percentile numbers.

---

## Step 1 — Gather the Results

Ask only what you don't have yet. You need at minimum:

- **Test type run:** Smoke / Load / Stress / Spike / Endurance
- **Tool used:** (to interpret format correctly — k6, Gatling, Locust, JMeter, Artillery, other)
- **Raw numbers:** response time percentiles (p50, p90, p95, p99), throughput (RPS),
  error rate (%), concurrent users at peak
- **SLA targets:** what the system was supposed to meet (p95 < Xms, error rate < Y%)
- **Baseline:** previous test results or expected values to compare against (if any)
- **Infrastructure observations:** any CPU, memory, DB, or network metrics collected
  during the test

If the user pastes raw output, extract the numbers yourself. If critical fields are
missing, ask specifically for them — do not proceed with incomplete data.

**Only load [references/TOOL-REPORT-FORMATS.md](references/TOOL-REPORT-FORMATS.md)
when the user pastes raw output from k6, Gatling, Locust, JMeter, or Artillery and
needs help reading or interpreting the specific fields, charts, or sections of that tool's report.**

**Only load [references/BOTTLENECK-PATTERNS.md](references/BOTTLENECK-PATTERNS.md)
when the user asks to diagnose *why* a metric is degraded — CPU spikes, memory growth,
slow queries, connection pool exhaustion, or third-party dependency slowness.**

**Only load [references/REPORT-TEMPLATES.md](references/REPORT-TEMPLATES.md) when
you are ready to produce the final technical or business report draft.**

---

## Step 2 — Analyze the Findings

### 2.0 Triage order — always start here

When results arrive, evaluate in this order. Stop and report if you find a blocker at any step:

1. **Error rate first** — if errors exist at baseline load, it is a bug, not a capacity issue. Capacity numbers are invalid until the bug is fixed.
2. **Did the test reach its target load?** — if VU count or RPS never reached the configured peak, the results are partial. State this limitation explicitly.
3. **Global p95 vs. SLA** — is the most important SLA met or breached at steady state?
4. **Latency trend over time** — was performance stable throughout the test, or did it degrade mid-run? (memory leak, warm-up, resource exhaustion)
5. **Per-endpoint breakdown** — which specific endpoint is the source of the problem? Never report only global metrics if per-endpoint data is available.

### 2.1 SLA compliance check

For each metric, compare actual vs. target:

| Metric | Target | Actual | Status |
|---|---|---|---|
| p95 response time | < X ms | Y ms | PASS / FAIL |
| p99 response time | < X ms | Y ms | PASS / FAIL |
| Error rate | < X% | Y% | PASS / FAIL |
| Throughput | ≥ X RPS | Y RPS | PASS / FAIL |

**Never average percentiles.** p95 = 95th percentile of all requests — a 1.2s p95
means 5% of users experienced ≥ 1.2s. This is a precision number, not an average.

### 2.2 Latency distribution analysis

Healthy vs. degraded signatures:

| Pattern | What it indicates |
|---|---|
| p50 ≈ p95 (tight spread) | Consistent, predictable performance |
| p95 >> p50 (wide spread, long tail) | Outliers — GC pauses, lock contention, cold cache, DB spikes |
| p50 rises with load | Saturation — system is queuing requests |
| p99 >> p95 | Occasional severe stalls — investigate retries, timeouts, external deps |
| p95 rises linearly as users scale | Expected — not a bug; validate it stays within SLA |
| p95 rises exponentially above a threshold | Breaking point — find the knee of the curve |

### 2.3 Error rate analysis

Classify errors before diagnosing:

- **Timeout errors** — requests that never completed: indicates saturation or slow downstream
- **4xx errors** — client errors under load: often test data issues (expired tokens, missing data)
- **5xx errors** — server-side failures: overload, unhandled exceptions, OOM crashes
- **Connection errors** — refused or reset: infrastructure limit (connection pool, firewall, max threads)

> An error rate that grows with load (not present at baseline) is a capacity signal,
> not a bug signal. An error rate present even at low load is a bug — fix it before
> interpreting capacity numbers.

### 2.4 Regression detection

When a baseline exists, always compute delta:

| Metric | Baseline | Current | Delta | Flag? |
|---|---|---|---|---|
| p95 | A ms | B ms | +X% | Flag if > 20% regression |
| Error rate | A% | B% | +X pp | Flag if any increase |
| Throughput | A RPS | B RPS | -X% | Flag if > 10% drop |

**Regression thresholds (default, adjust to SLA):**
- p95 or p99 regression > 20% → flag as degradation
- Error rate increase > 0.1 pp (from near-zero) → flag immediately
- Throughput drop > 10% at same load → flag as capacity regression

### 2.5 Per-endpoint analysis

Global metrics hide which endpoint is causing the problem. When per-endpoint data is available:

1. Sort endpoints by p95 descending — the top 3 are your investigation targets
2. Check whether failing endpoints share a pattern (same DB table, same external dep, same service)
3. Distinguish: is one slow endpoint dragging up the global p95, or is the problem widespread?
4. Report SLA compliance per endpoint when SLAs are defined per endpoint, not just globally

| Situation | What to report |
|---|---|
| 1 of 10 endpoints causes the SLA breach | Flag that endpoint specifically — global SLA breach is misleading without this context |
| All endpoints degrade together | Shared resource bottleneck — investigate DB, network, or infra |
| Only POST endpoints fail | Investigate write path: DB locks, validation, downstream writes |
| Only authenticated endpoints fail | Investigate auth middleware, token validation, session store |

### 2.6 Chart and graph interpretation

When the user shares or references visual reports (Gatling HTML, k6 dashboard, Locust charts):

| Chart type | What to look for | Red flags |
|---|---|---|
| Response time over time | Should be flat during steady state | Upward trend = leak or saturation; spikes = GC or retry storms |
| Active users / VUs over time | Should match the configured ramp profile | Plateau below target = test runner bottleneck or too-strict rate limiter |
| Requests per second | Should track with VU count | RPS plateaus while VUs increase = system saturated |
| Error rate over time | Should be near zero | Spike then recover = transient; growing = capacity limit approaching |
| Response time distribution | Should be right-skewed (few slow outliers) | Bimodal distribution = two distinct user populations or cache hit/miss split |

### 2.7 Spike test and warm-up analysis

**Spike tests — three things to verify:**
1. Did the system reach the configured spike peak? (check VU/RPS chart)
2. What was the error rate and p95 *at peak*? (the stress moment)
3. How long did recovery take after load dropped? (recovery time = time to return to baseline p95 ± 10%)

**Warm-up / cold start — when to exclude from SLA evaluation:**
- If latency is high in the first 2–5 minutes then stabilizes → exclude warm-up window from SLA measurement
- Evaluate SLA only during steady-state (after the ramp-up phase completes)
- Note the warm-up duration in the report — it matters for autoscaling and readiness probe configuration

---

## Step 3 — Classify Severity

Assign a severity to each finding before writing either report.

| Severity | Definition | Example |
|---|---|---|
| **Critical** | SLA breach; system unavailable or degraded for users in production | p95 > SLA × 2, error rate > 5% |
| **High** | SLA breach; significant user impact if deployed | p95 > SLA, error rate 1–5% |
| **Medium** | SLA met but trend is concerning; risk of future breach | p95 at 90% of SLA, rising with load |
| **Low** | Within SLA; minor optimization opportunity | p95 at 60% of SLA, no trend |
| **Informational** | Notable observation, no action required | Latency spike during GC, recovered immediately |

Every finding in the reports must carry a severity label.

---

## Step 4 — Technical Report

Structure the technical report as follows. Be specific: include actual numbers,
tool output excerpts, and concrete next steps with owners.

```
## Performance Test Technical Report
**Date:** [date]
**Test type:** [Smoke / Load / Stress / Spike / Endurance]
**Tool:** [k6 / Gatling / Locust / JMeter / other]
**Environment:** [staging / perf / prod-clone]
**Load profile:** [X users, Y RPS, Z minutes duration]

---

### Executive Summary (3 sentences max)
[What was tested. Whether SLAs were met. Top finding in plain language.]

---

### SLA Compliance

| Metric | Target | Actual | Result |
|---|---|---|---|
| p95 response time | ... | ... | PASS/FAIL |
| p99 response time | ... | ... | PASS/FAIL |
| Error rate | ... | ... | PASS/FAIL |
| Throughput | ... | ... | PASS/FAIL |

---

### Findings

#### [CRITICAL/HIGH/MEDIUM/LOW] Finding 1 — [Short title]
**Observed:** [What the data shows, with exact numbers]
**Root cause hypothesis:** [Why this likely happened — infrastructure, code, config]
**Evidence:** [Specific metric, timestamp, or tool output that supports this]
**Recommended action:** [Concrete next step — code change, config tuning, infra scaling]
**Owner:** [Team or role responsible]
**Retest required:** Yes / No

#### [severity] Finding 2 — ...
[repeat for each finding]

---

### Regression vs. Baseline

| Metric | Baseline | Current | Delta | Status |
|---|---|---|---|---|
| p95 | — | — | — | — |
| Error rate | — | — | — | — |

[Note: omit section if no baseline exists]

---

### Infrastructure Observations
[CPU, memory, DB, network observations during the test. Flag any resource that peaked
above safe thresholds (CPU > 70%, memory upward drift, connection pool saturation).]

---

### Recommendations Summary

| Priority | Action | Owner | Target date |
|---|---|---|---|
| P1 | ... | ... | ... |
| P2 | ... | ... | ... |

---

### Test Conditions
[Document: environment, dataset size, any known limitations that affect validity of results]
```

---

## Step 5 — Business Report

The business report translates technical findings into decisions and risk. **Never
include raw percentile numbers, tool names, or technical jargon.** Translate every
metric into user or business impact.

### Translation table — metrics to business language

| Technical metric | Business translation |
|---|---|
| p95 = 1.8s (SLA: < 1s) | 1 in 20 users waits nearly 2× longer than acceptable |
| Error rate = 3% at peak | 3 out of every 100 transactions fail during busy periods |
| System breaks at 800 users | Current capacity is 60% of the expected peak of 1,300 users |
| p95 regression +40% vs. last release | The recent release made the slowest user experience significantly worse |
| Endurance: memory grows 2GB over 4h | If deployed, the service will require a restart every few hours to avoid outages |

```
## Performance Test — Business Summary
**Date:** [date]
**System:** [product or service name]
**Test conducted by:** [team]

---

### What Was Tested
[One paragraph. What system, what scenario, what load level — in plain language.
No tool names. Example: "We simulated 500 users purchasing products simultaneously,
representing the expected traffic during the upcoming sale."]

---

### Key Question: Is It Ready?

**Overall verdict:** [Ready to deploy / Not ready — risks identified / Ready with conditions]

[One paragraph summary of what this means for the business.]

---

### Risk Summary

| Risk | Impact | Likelihood | Recommended action |
|---|---|---|---|
| [plain-language risk] | High/Med/Low | High/Med/Low | [decision recommendation] |

---

### What Happens If We Deploy Now
[Honest assessment of the user-facing impact if the system goes live as-is.
Focus on conversion, user experience, or revenue impact where applicable.]

---

### What Needs to Happen Before Go-Live
[Bullet list of must-fix items in plain language. Each bullet should say what needs
to happen and why it matters to users or the business — not how to fix it technically.]

---

### What We Can Defer
[Low/informational findings that do not block launch but should be addressed post-launch.]

---

### Decision Required
[If there is a go/no-go decision pending, state it explicitly with a recommendation
and the tradeoff of each option.]
```

---

## Common Mistakes in Result Interpretation

### 1. Using mean response time instead of percentiles
The mean hides outliers. A mean of 200ms is meaningless if p99 = 8s. Always lead
with p95 and p99 for user-perceived performance.

### 2. Ignoring error rate growth pattern
An error rate that jumps from 0% at 100 users to 5% at 200 users is a capacity
signal. An error rate of 5% at every load level is a bug. These require different fixes.

### 3. Declaring success because SLAs are met "on average"
SLAs must be evaluated per percentile, not as averages. "p95 is fine" and "average is fine"
are not the same statement.

### 4. Comparing results across different environments
A staging result and a production-sized environment result are not comparable. Always
document environment differences and state explicitly what the result does and does not prove.

### 5. Writing a business report with technical numbers
Saying "p95 = 1,240ms exceeds our SLA of 800ms" to a business stakeholder produces
no action. Say "1 in 20 users experiences a delay 55% longer than our target."

### 6. No baseline — calling first run a pass
Without a baseline, you can only say "SLAs are met." You cannot say performance has not
regressed. Always capture and store first-run results as the baseline for future comparisons.

### 7. Stress test breaking point declared without recovery verification
Finding the breaking point is only half the stress test. Confirm the system *recovers*
after load is removed. A system that crashes and stays crashed is far more dangerous
than one that degrades gracefully.

### 8. Analyzing warm-up period as steady state
High p95 values in the first 2–5 minutes of a test are often JIT compilation, lazy
connection initialization, or DNS resolution — not application performance. Always
exclude the ramp-up/warm-up window when evaluating SLA compliance.

### 9. Reporting only global metrics when per-endpoint data is available
A global p95 of 900ms could mean all 10 endpoints are slow (infrastructure problem)
or one endpoint is returning 9,000ms (specific bug). Always break down to endpoint
level before drawing conclusions or making recommendations.
