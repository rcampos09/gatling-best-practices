# Metrics, SLAs, and Monitoring Guide

This file is loaded on demand when the user needs help defining SLA thresholds, selecting which metrics to collect, or setting up infrastructure monitoring. All guidance is tool-agnostic.

---

## Response Time Metrics — Use Percentiles, Not Mean

**Never use mean (average) as a primary SLA metric.** Mean hides the tail: a p99 of 10 seconds is invisible when the mean is 200ms because 99% of fast requests pull the average down.

| Metric | What it tells you | When to use |
|---|---|---|
| p50 (median) | What a typical user experiences | Baseline reference |
| p90 | 90% of users are faster than this | General health indicator |
| p95 | Standard SLA anchor | Use in production SLAs |
| p99 | 1 in 100 requests is slower than this | Checkout, payment, login |
| p99.9 | 1 in 1000 requests | Financial systems, SLAs with penalties |
| Max | The single worst request | Debugging outliers only — not an SLA metric |

**Recommendation:** Define SLAs at p95 and p99. Monitor p50 as a trend indicator. Ignore max for SLA purposes — it will always be an outlier.

---

## Response Time Thresholds — Industry Benchmarks

Use these as starting points when the team has no existing SLA targets:

| Response time | User perception | Recommendation |
|---|---|---|
| < 100ms | Instantaneous | Target for backend API calls with no rendering |
| 100ms – 500ms | Fast | Acceptable for interactive web requests |
| 500ms – 1s | Noticeable | Borderline for user-facing endpoints |
| 1s – 3s | Slow | Users may abandon; investigate before release |
| > 3s | Unacceptable | High abandonment rate; must fix before production |

**Common SLA starting points by system type:**

| System type | p95 SLA | p99 SLA |
|---|---|---|
| Public REST API (CRUD) | 500ms | 1000ms |
| Authentication / Login | 300ms | 500ms |
| Search / autocomplete | 200ms | 400ms |
| E-commerce checkout | 1000ms | 2000ms |
| Report / data export | 5000ms | 10000ms |
| Background job status poll | 200ms | 500ms |

---

## Error Rate Thresholds

| Error rate | Classification | Action |
|---|---|---|
| 0% | Perfect | Continue |
| < 0.01% | Acceptable | Monitor — may be infrastructure noise |
| 0.01% – 0.1% | Warning | Investigate before releasing to production |
| 0.1% – 1% | Degraded | Fail the test — do not release |
| > 1% | Critical | Stop the test — the system is actively failing |

**What counts as an error:**
- Server error responses (5xx for HTTP; equivalent error codes for other protocols)
- Connection timeouts or refused connections
- Response body validation failures (expected field missing or malformed)
- Response time exceeding the configured timeout threshold
- Protocol-level errors (e.g., WebSocket disconnect, gRPC status != OK, message queue nack)

---

## Throughput (Requests or Transactions per Second)

**Throughput ≠ Users.** Throughput depends on concurrent users, requests per user flow, and think time.

**Formula:**
```
RPS = (concurrent users × requests per scenario) / (scenario duration including think time in seconds)
```

**Example:** 100 users, each flow has 5 requests with 2 seconds of think time per step:
```
RPS = (100 × 5) / (5 steps × 2s) = 500 / 10 = 50 RPS
```

**Define throughput goals based on:**
- Business transactions per day ÷ seconds in peak window
- Analytics data showing current production RPS at peak
- Growth projections — add a 20–50% buffer for future capacity headroom

---

## Infrastructure Metrics to Collect

Always collect infrastructure metrics in parallel with the load test. Application-level response times without infrastructure context are insufficient for root-cause analysis.

### CPU
| Level | Status | Action |
|---|---|---|
| < 50% | Healthy | No action needed |
| 50–70% | Normal | Monitor trend |
| 70–85% | Warning | Investigate — response times may degrade |
| > 85% | Critical | System is CPU-bound; optimization or scaling needed |

CPU should be measured as a sustained average, not instantaneous peak. Brief spikes during connection setup are normal.

### Memory
| Signal | Interpretation |
|---|---|
| Stable plateau after warmup | Healthy — runtime memory management is working |
| Continuous upward trend over time | Memory leak — investigate heap dumps or process profiling |
| Sudden drop + spike pattern | Aggressive garbage collection — investigate allocation rate |
| Approaching 90% of available limit | Risk of out-of-memory crash |

**Runtime-specific notes:**
- **JVM (.java, .kt, .scala):** Monitor heap and non-heap separately. Sustained GC pause duration > 200ms is a warning sign.
- **.NET CLR:** Monitor managed heap generations (Gen 0/1/2) and LOH pressure.
- **Node.js (V8):** Monitor V8 heap used vs. heap total; RSS growth outside the heap indicates native memory leaks.
- **Go:** Monitor `runtime.MemStats` — particularly `HeapInuse` and `Sys` for OS-level retention.
- **Non-managed runtimes (C, C++, Rust):** Monitor OS-level RSS and virtual memory; no GC to rely on.

### Database
| Metric | Warning threshold | Critical threshold |
|---|---|---|
| Connection pool usage | > 70% of pool size | > 90% — connection starvation |
| Active connections | > 80% of max connections | > 95% |
| Slow query rate | > 1% of queries | > 5% |
| Lock wait time | > 100ms average | > 500ms |
| Deadlock rate | Any occurrence | Any — investigate immediately |

### Network
| Metric | What to watch |
|---|---|
| Network I/O (bytes/sec) | Saturation means bandwidth is the bottleneck, not application code |
| Connection state distribution | Too many connections in a waiting/closing state indicate pooling or timeout issues |
| Packet loss | Any packet loss during a controlled test indicates an infrastructure problem |

---

## SLA Definition Template

Use this template to document SLAs *before* starting any performance test. Agreeing on thresholds before running avoids disputes about results afterward.

```
System: <name>
Environment: <staging | perf-dedicated | prod-clone>
Test date: <YYYY-MM-DD>
Tester: <name>

Response Time SLAs:
  Global p95:                  < _____ ms
  Global p99:                  < _____ ms
  Critical endpoint (<name>):  p99 < _____ ms

Throughput SLA:
  Minimum throughput:          _____ requests/second

Error Rate SLA:
  Maximum error rate:          < _____ %

Infrastructure SLAs:
  Max CPU sustained:           < _____%
  Max memory utilization:      < _____%
  DB connection pool usage:    < _____%

Test will FAIL if any of the above thresholds are breached.
```

---

## How to Set SLAs When You Have No Historical Data

If there is no production baseline, use this process:

1. **Run a smoke test** — record response times under 2–5 users. This is the unconstrained system baseline.
2. **Set initial SLAs at 2× smoke test p95** — this gives headroom for load-induced latency increase.
3. **Run a load test** — measure actual p95/p99 under expected production load.
4. **Negotiate thresholds with the product team** — what is the business impact of a 1s vs 2s response time for this specific flow?
5. **Tighten SLAs incrementally** — optimize, re-test, reduce thresholds each sprint until they reflect the business requirement.

---

## Monitoring Tooling — Categories and Options

These are observability and monitoring tools, not load testing tools. Choose based on your stack and infrastructure.

| Category | Common options |
|---|---|
| APM (Application Performance Monitoring) | Datadog, New Relic, Dynatrace, Elastic APM, Instana |
| Metrics collection + dashboards | Prometheus + Grafana, InfluxDB + Grafana, VictoriaMetrics |
| Cloud-native monitoring | AWS CloudWatch, GCP Cloud Monitoring, Azure Monitor |
| Distributed tracing | Jaeger, Zipkin, AWS X-Ray, Honeycomb |
| Database monitoring | Per-database query analyzers (most databases provide built-in slow query logs) |
| Runtime profiling | Language and runtime-specific profilers — use when you need to identify hot code paths |

**Minimum requirement:** Have CPU, memory, and request error rate visible on a dashboard and actively recording *before* the first test run starts.
