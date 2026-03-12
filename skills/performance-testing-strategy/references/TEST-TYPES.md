# Performance Test Types — Detailed Reference

This file is loaded on demand when the user needs detailed parameters, decision criteria, or conceptual definitions for each test type. All guidance is tool-agnostic — parameters are expressed in users, RPS, and durations, not in any tool's DSL.

---

## Smoke Test

**Purpose:** Confirm the test harness works and the system is alive under minimal load. This is not a performance measurement — it is a sanity check.

**When to use:**
- Before every other test type, always
- After any code or infrastructure change
- When setting up a new test environment for the first time

**Parameters:**
| Parameter | Value |
|---|---|
| Virtual users | 2–5 |
| Duration | 2–5 minutes |
| Load shape | All users start simultaneously, or ramp over 30 seconds |
| Think time | Same pauses as the production scenario |

**Pass criteria:**
- Zero errors (connection errors, timeouts, error responses)
- Response times within 2× the production SLA
- All scenario steps complete successfully end-to-end

**Red flags that must be fixed before proceeding to any other test:**
- Any server error responses
- Authentication or authorization failures
- Test data exhausted before the scenario completes
- Timeouts on basic requests that succeed at zero load

---

## Load Test

**Purpose:** Measure system behavior under the expected production load. Establishes the performance baseline against which all other tests are compared.

**When to use:**
- Pre-release regression testing
- After any significant backend, database, or infrastructure change
- To validate that infrastructure sizing is correct
- To measure SLA compliance

**Parameters:**
| Parameter | Value |
|---|---|
| Virtual users | Peak expected concurrent users × 1.0 to × 1.2 |
| Duration | 30–60 minutes of steady state |
| Ramp-up | 10–20% of total duration (e.g., 10 min ramp for a 60 min test) |
| Think time | Realistic — model from user analytics or business requirements if available |

**Load shape:** Ramp users gradually to the target level, then hold steady. The steady-state phase must be long enough to identify latency drift — at least 20–30 minutes.

**Pass criteria:**
- Error rate < 0.1%
- p95 response time ≤ SLA
- p99 response time ≤ 2× SLA
- Throughput ≥ required RPS
- CPU sustained below 70%, memory stable

**What to look for in results:**
- Response time percentiles over time — should be flat during steady state; upward trend means saturation
- Error rate over time — any increase during steady state indicates a capacity ceiling was reached
- Throughput over time — should match the injection rate; if it lags, the system cannot keep up

---

## Stress Test

**Purpose:** Find the system's breaking point. Determine the maximum load the system can handle before failures or unacceptable degradation begin.

**When to use:**
- Capacity planning for future growth
- Before a major scaling event (infrastructure migration, architectural change)
- Post-incident investigation ("how close were we to the limit?")
- Validating auto-scaling policies and thresholds

**Parameters:**
| Parameter | Value |
|---|---|
| Starting users | Same as the load test target |
| Increment | +20–25% of peak load per step |
| Duration per step | 5–10 minutes (enough to reach steady state at each level) |
| Total duration | Until system breaks or throughput plateaus — typically 30–90 minutes |

**Load shape (staircase):** Start at the load test level. Every 5–10 minutes, add another increment of users. Continue until the system fails, throughput stops increasing, or response times become unacceptable. After reaching the peak, reduce load to verify recovery.

**What to look for:**
- The **knee of the curve** — the point where adding more users stops increasing throughput (the system is saturated)
- **Failure mode** — does it return graceful error responses (503), queue requests, or crash outright?
- **Recovery** — after reducing load to baseline, does the system recover automatically and within an acceptable time?

**Pass criteria (stress tests are exploratory — the goal is information, not pass/fail):**
- Document the breaking point: users, RPS, and response time at the point of failure
- Confirm graceful degradation: no data corruption, service restarts cleanly
- Confirm recovery time after load is reduced

---

## Spike Test

**Purpose:** Simulate a sudden, extreme burst of traffic. Validates that the system survives flash events without crashing and recovers to normal performance afterward.

**When to use:**
- Before promotional events (flash sales, product launches, marketing email blasts)
- When the traffic pattern has known burst characteristics (scheduled jobs, batch triggers)
- To test auto-scaling reaction time — does scaling kick in fast enough?
- To validate circuit breakers and backpressure mechanisms

**Parameters:**
| Parameter | Value |
|---|---|
| Baseline load | Normal operating load |
| Spike load | 2–5× peak load, injected instantly or near-instantly |
| Spike duration | 2–5 minutes |
| Recovery period | 10–15 minutes back to baseline |

**Load shape:** Run at baseline for a few minutes, then inject the full spike volume all at once (no ramp-up). Hold the spike briefly, then drop back to baseline and observe recovery.

**What to look for:**
- How quickly does performance degrade when the spike hits?
- Does the system return graceful errors (shed excess load) or crash?
- How long does it take to recover to baseline SLA after the spike ends?
- Are there any lasting side effects — memory not released, connections not returned to the pool, queues not drained?

**Pass criteria:**
- System survives the spike without a hard crash or data loss
- Recovery to baseline response times within a defined window (e.g., 60 seconds after spike ends)
- No data loss or corruption during or after the spike

---

## Endurance / Soak Test

**Purpose:** Detect issues that only appear after sustained load over time: memory leaks, connection pool exhaustion, file handle leaks, thread accumulation, log rotation problems, slow database table bloat.

**When to use:**
- Before any system goes to production for the first time
- Quarterly baseline, or after major architectural changes
- When investigating intermittent degradation in production ("it gets slow after a few hours")
- For any system with long-running sessions, stateful connections, or large in-memory caches

**Parameters:**
| Parameter | Value |
|---|---|
| Virtual users | 70–80% of peak load (sustainable, not maximum) |
| Duration | 2 hours minimum; 8–24 hours for critical or long-running systems |
| Ramp-up | Standard ramp (10–15 minutes) |
| Think time | Realistic — keep it sustainable over the full duration |

**Load shape:** Standard gradual ramp to a moderate steady state. The key is duration, not intensity.

**What to monitor over time — look for drift:**
- Response time percentiles — should remain flat throughout; upward drift means degradation is accumulating
- Process memory usage — should plateau after warmup; continuous growth indicates a memory leak
- Connection pool utilization — should stay below pool capacity; gradual growth indicates connections are not being returned
- Thread count — should stay within configured limits
- Disk I/O — unbounded log growth can exhaust disk and crash the service
- Garbage collection (for managed runtimes like JVM, .NET CLR, Node.js V8) — pause frequency and duration should remain stable

**Pass criteria:**
- Response time and error rate at the **end** of the test are within 10% of values at the **start** of steady state
- No service restarts or crashes during the test
- All infrastructure metrics (CPU, memory, connections) remain stable — not trending upward

**Minimum viable soak test:**
If a full 8-hour run is not possible, run for at least 2 hours. Tests shorter than 2 hours rarely surface time-based degradation. Document the shorter duration as a known limitation and schedule a longer run before the next production release.

---

## Workload Models: Open vs. Closed

Understanding the workload model is essential for designing realistic tests regardless of the tool used.

**Open model (arrival rate):** New users arrive at a fixed rate regardless of how many are already active. This matches real-world web traffic — users arrive whether or not the system is ready. Use this for public APIs, web apps, and any system with unpredictable incoming traffic.
- Parameter: users arriving per second (arrival rate)
- Behavior under saturation: queue depth grows, response times increase

**Closed model (concurrency):** A fixed number of users are always active. A new request is sent only after the previous one completes. This matches connection pools, queues, and batch workers. Use this for systems with strict concurrency limits.
- Parameter: concurrent users (concurrency level)
- Behavior under saturation: throughput is capped by concurrency × (1/response time)

**Rule of thumb:** Use the open model for user-facing systems. Use the closed model for backend worker systems, database connection pools, or systems with strict connection limits.

---

## Test Type Decision Matrix

| Question | Answer | Add to strategy |
|---|---|---|
| Have we ever tested this system? | No | Smoke → Load |
| Is there a release this week? | Yes | Smoke → Load |
| Are we preparing for a peak event? | Yes | + Spike |
| Is there a suspected memory or resource leak? | Yes | + Endurance |
| Do we need to know the capacity ceiling? | Yes | + Stress |
| Is traffic pattern bursty by nature? | Yes | + Spike |
| System runs for days/weeks without restart? | Yes | + Endurance |
| Full production readiness assessment? | Yes | All five, in order |
| Time-constrained (< 4 hours available)? | Yes | Smoke → Load only; note gaps |
