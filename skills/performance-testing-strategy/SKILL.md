---
name: performance-testing-strategy
description: >
  Guides QA engineers and performance testers in designing a complete performance
  testing strategy by asking the right questions and applying best practices.
  Use this skill whenever the user asks how to plan performance tests, which test
  types to run (Smoke, Load, Stress, Spike, Endurance/Soak), how to define SLAs,
  what metrics to collect, how to size their test, or how to sequence test execution.
  Trigger on phrases like "performance test plan", "load test strategy", "how many
  users should I use", "what kind of performance test do I need", "where do I start
  with performance testing", or "help me design my perf tests".
license: MIT
compatibility: "Claude Code, Cursor, Windsurf"
model: sonnet
metadata:
  author: rcampos
  version: "1.1"
---

# Performance Testing Strategy Designer

Guides QA engineers through designing a **complete, structured performance testing strategy** by gathering context through targeted questions and applying industry best practices.

**Important:** Always gather context first (Step 1) before producing any output. Do not skip to recommendations without understanding the system and its constraints.

## Output Format

After completing Step 1, deliver a strategy document with these sections:

1. **System Under Test (SUT) summary** — what you understood about the application
2. **Recommended test sequence** — which test types to run and in what order, with rationale
3. **Per-test definition** — for each type: goal, user load, duration, ramp-up, success criteria
4. **Metrics to collect** — response times, throughput, error rates, infrastructure metrics
5. **Risks and prerequisites** — what must be in place before testing starts

---

## Step 1 — Gather Context

Ask only what you don't know yet. Work through these categories; stop when you have enough to design the strategy. **Do not ask all questions at once** — group them naturally and wait for answers before continuing.

### A. Application Profile
- What type of application is it? (web app, mobile backend, microservice, batch job, streaming pipeline)
- What protocol does it use? (HTTP/REST, GraphQL, WebSocket, gRPC, message queue)
- Is it stateful (sessions, auth tokens) or stateless?
- Does it have external dependencies? (third-party APIs, databases, caches, message brokers)
- Does the infrastructure auto-scale, or is capacity fixed?

### B. Traffic and Usage Patterns
- What is the **current or expected peak load**? (requests/second, concurrent users, transactions/day)
- Is traffic **steady** (e.g., internal tool) or **spiky** (e.g., flash sale, marketing campaign, scheduled batch)?
- Are there **known peak windows**? (time of day, day of week, seasonal events)
- What does a **typical user flow** look like? (sequence of actions, not just a single endpoint)

### C. SLAs and Acceptance Criteria
- Is there a **response time target**? (e.g., p95 < 1s, p99 < 2s)
- Is there a **throughput target**? (e.g., must handle 500 RPS)
- What is the **acceptable error rate**? (e.g., < 0.1% errors under load)
- Are SLAs defined per endpoint, globally, or both?

### D. Environment and Constraints
- What **environment** will tests run against? (production-clone, staging, dedicated perf env)
- Is the environment **isolated** from production traffic?
- Are there **data constraints**? (test users, sanitized data, data volume)
- Are there **infrastructure limits** to be aware of? (shared DB, rate limiters, WAF, CDN)
- What is the **available test window**? (hours or days available to run tests)

### E. Scope and Goals
- Is this a **first-time** performance test or a **regression** run before a release?
- Is there a specific **concern or risk** driving this? (new feature, peak event prep, incident post-mortem, capacity planning)
- What **load testing tool** will be used? (ask without suggesting — the strategy is tool-agnostic)

---

## Step 2 — Select Test Types

Recommend only the test types that match the stated goals and risks. **Do not recommend all five by default** — justify each one based on the context gathered.

**Load [references/TEST-TYPES.md](references/TEST-TYPES.md) when the user needs detailed definitions, parameters, and decision criteria for each test type.**

### Quick selection guide

| Situation | Recommended tests |
|---|---|
| First time testing, no baseline | Smoke → Load |
| Pre-release regression check | Smoke → Load |
| Preparing for a peak event (Black Friday, launch) | Smoke → Load → Spike |
| Investigating slowdown under sustained traffic | Smoke → Load → Endurance |
| Finding the system's breaking point | Smoke → Load → Stress |
| Full strategy for a production-grade system | Smoke → Load → Stress → Spike → Endurance |
| Time-constrained (< 4 hours) | Smoke → Load only |

### Sequencing rule
**Always run Smoke first.** Never jump straight to Stress or Spike — a broken baseline wastes time and produces misleading results.

---

## Step 3 — Define Each Test

For every recommended test type, produce a precise definition. Use the templates below. Express load in **users or RPS** — never in tool-specific syntax.

### Smoke Test
```
Goal:          Verify the test setup works and the system handles minimal load
Users:         2–5 virtual users
Duration:      2–5 minutes
Ramp-up:       None (inject all users at once) or 30 seconds
Success:       0 errors, all responses within 2× the SLA threshold
When to skip:  Never — always run smoke first
```

### Load Test
```
Goal:          Measure behavior under expected production load
Users:         Peak load × 1.0 (baseline) and peak load × 1.2 (safety buffer)
Duration:      30–60 minutes of steady state (after ramp-up)
Ramp-up:       10–20% of total duration (e.g., 10 min ramp for a 60 min test)
Success:       Error rate < 0.1%, p95 within SLA, p99 within 2× SLA
When to skip:  Only if a load test was run recently with no system changes
```

### Stress Test
```
Goal:          Find the maximum load before degradation or failure
Users:         Start at peak load; increase by 20–25% each step until breaking point
Duration:      Until failure or throughput plateaus — typically 30–90 minutes
Ramp-up:       Staircase: add load increments every 5–10 minutes
Success:       Identify the breaking point; confirm graceful degradation and recovery
When to skip:  When the only goal is SLA validation (not capacity exploration)
```

### Spike Test
```
Goal:          Verify behavior during sudden, large traffic bursts
Users:         Baseline load → sudden jump to 2–5× peak → return to baseline
Duration:      10–20 minutes total (the spike itself: 2–5 minutes)
Ramp-up:       Instantaneous spike; gradual recovery back to baseline
Success:       System survives without crashing; recovers to baseline SLA within a defined window
When to skip:  When traffic is inherently steady with no burst patterns
```

### Endurance / Soak Test
```
Goal:          Detect issues that only appear over time: memory leaks, connection exhaustion, resource drift
Users:         70–80% of peak load (sustainable, not maximum)
Duration:      2 hours minimum; 8–24 hours for critical or long-running systems
Ramp-up:       Standard ramp (10–15 min)
Success:       Response times and error rates at the end are within 10% of values at the start of steady state
When to skip:  Short-term regression only — note the risk and schedule a soak test later
```

---

## Step 4 — Define Metrics

**Load [references/METRICS-AND-SLAS.md](references/METRICS-AND-SLAS.md) when the user asks about which metrics to collect, how to set SLA thresholds, or what to monitor on the infrastructure side.**

### Minimum metrics for every test

**Application-level (collected by the load testing tool):**
- Response time: p50, p90, p95, p99 — never rely on mean alone
- Throughput: requests/second or transactions/second
- Error rate: percentage of failed requests (timeouts + error responses)
- Concurrent users / active sessions over time

**Infrastructure-level (collected via monitoring — APM, metrics platform, cloud dashboards):**
- CPU utilization (investigate if sustained > 70%)
- Memory utilization (watch for upward drift in Endurance tests)
- Network I/O (saturation indicates infrastructure bottleneck, not application bottleneck)
- Database: connection pool usage, slow query rate, lock waits
- Runtime-specific (if applicable): heap usage, garbage collection frequency and pause duration

---

## Step 5 — Prerequisites Checklist

Before running any test, verify:

- [ ] **Test environment is isolated** — test traffic will not affect real users or production data
- [ ] **Test data is prepared** — realistic volume of users, products, orders, or domain entities
- [ ] **Data strategy is defined** — how test data is consumed: cycled, randomized, or unique per run
- [ ] **Monitoring is active** — metrics collection is running *before* the test starts
- [ ] **Baseline metrics exist** — at minimum, a smoke test result to compare against
- [ ] **Team is available** — someone can monitor and stop the test if needed
- [ ] **Rollback plan exists** — for tests that could cause data corruption or service interruption
- [ ] **Third-party services are stubbed or rate-limited** — avoid generating real charges or hitting partner quotas
- [ ] **Rate limiters / WAF are configured for testing** — or bypassed in the test environment
- [ ] **Alerts are suppressed** — to avoid on-call noise during intentional stress or spike tests

---

## Common Strategy Mistakes

### 1. Starting with Stress before Load
Running a stress test without a load test baseline means you cannot distinguish "the system breaks at 500 users" from "the system was already broken at 100 users."

### 2. Testing in production without isolation
Even read-only load tests can cause production incidents (DB CPU spikes, cache eviction, rate limiter triggers). Always use an isolated environment.

### 3. Using unrealistic user flows
Testing only a single endpoint (e.g., a health check) tells you nothing about real user behavior. Model the top 2–3 user journeys from analytics or business requirements.

### 4. Ignoring think time between requests
Zero think time between requests generates 10–100× more load than real users produce. Every scenario must include realistic pauses that reflect actual user behavior.

### 5. No infrastructure monitoring
Knowing response times without knowing CPU/memory/DB state means you cannot diagnose *why* the system degraded. Always run infrastructure monitoring in parallel with the load test.

### 6. Short endurance tests
A 5-minute soak test finds nothing. Memory leaks and connection exhaustion typically appear after 30–120 minutes of sustained load. Minimum viable soak: 2 hours.

### 7. Treating test results as absolute truth
Results are only valid for the environment, data volume, and configuration tested. Always document these conditions alongside the results — a test in staging with 10% of production data is not a production capacity test.

### 8. Testing the wrong workload model
Concurrent users and arrival rate (RPS) are not interchangeable. Understand whether your system should be tested with a fixed number of concurrent users (closed model) or a fixed arrival rate of new requests (open model). Using the wrong model produces misleading throughput numbers.

---

## References

- [Test Types — Detailed Parameters and Decision Criteria](references/TEST-TYPES.md)
- [Metrics, SLAs, and Monitoring Guide](references/METRICS-AND-SLAS.md)
