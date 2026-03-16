# Tool-Specific Report Formats

## When to load this file

Load when the user pastes raw output from k6, Gatling, Locust, JMeter, or Artillery
and needs help reading or interpreting the specific fields, charts, or sections of
that tool's report.

---

## k6

### End-of-test stdout summary

```
scenarios: (100.00%) 1 scenario, 100 max VUs, 5m30s maximum duration ...
default: 100 looping VUs for 5m0s (gracefulStop: 30s)

✓ status was 200
✗ transaction time OK
  ↳ 73% — ✓ 2184 / ✗ 812

checks.........................: 86.57%  ✓ 2184  ✗ 812
data_received..................: 4.5 MB  15 kB/s
data_sent......................: 1.2 MB  4.0 kB/s
http_req_blocked...............: avg=1.2ms    min=1µs      med=4µs      max=248ms p(90)=8µs    p(95)=12µs
http_req_connecting............: avg=0.8ms    ...
http_req_duration..............: avg=320ms    min=120ms    med=290ms    max=4.5s  p(90)=620ms  p(95)=980ms  p(99)=2.1s
  { expected_response:true }...: avg=310ms    ...
http_req_failed................: 0.12%   ✓ 4     ✗ 3296
http_req_receiving.............: avg=1.3ms    ...
http_req_sending...............: avg=0.4ms    ...
http_req_tls_handshaking.......: avg=0ms      ...
http_req_waiting...............: avg=318ms    ...
http_reqs......................: 3300    11.0/s
iteration_duration.............: avg=1.32s    ...
iterations.....................: 3300    11.0/s
vus............................: 100     min=100    max=100
vus_max........................: 100     min=100    max=100

THRESHOLDS
http_req_duration.............: p(95)<1000 — PASS
http_req_failed...............: rate<0.01  — PASS
```

### Field-by-field guide

| Field | What it means | What to look for |
|---|---|---|
| `http_req_duration` p(95) | 95th percentile of total request time | Primary SLA metric — compare to target |
| `http_req_duration` p(99) | 99th percentile | Tail latency — high value = outlier problem |
| `http_req_waiting` | Time-to-first-byte (TTFB) — server processing time | If close to `http_req_duration`, network overhead is minimal |
| `http_req_blocked` | Time waiting for a TCP connection slot | High value = connection pool exhaustion or too many connections |
| `http_req_connecting` | TCP connection establishment time | High value = network latency or new connection overhead |
| `http_req_failed` | Requests where `response.ok` is false or `check()` failed | Primary error rate metric |
| `checks` | Percentage of manual `check()` assertions that passed | Business logic validation — not the same as HTTP success |
| `iterations` | Total number of complete VU iterations | Useful for throughput math: iterations ÷ duration = RPS |
| `vus` | Current active virtual users | Should match your configured peak |
| `THRESHOLDS` | Pass/fail evaluation of SLA rules | PASS = SLA met; FAIL = SLA breached — test may exit with code 1 |

### Common k6 interpretation mistakes

- **`http_req_failed` ≠ HTTP errors only.** By default, k6 marks a request as failed only if the response is not OK (non-2xx). If you use `check()` without `http_req_failed`, passing `checks` doesn't mean the request wasn't slow.
- **`checks` and `http_req_failed` are independent.** A request can have `http_req_failed=false` (HTTP 200) but `checks=fail` (wrong body content).
- **p(95) in `http_req_duration` includes blocked + connecting time.** For pure server processing time, look at `http_req_waiting` p(95).
- **Thresholds at the bottom = final verdict.** If a threshold shows FAIL, that assertion did not pass — look at the corresponding metric.

### k6 HTML/JSON output

When running with `--out json` or `--out influxdb`, the key metric names are:
- `http_req_duration` → response time
- `http_req_failed` → error rate
- `http_reqs` → throughput
- `http_req_waiting` → TTFB / server time

---

## Gatling

### HTML report structure

Gatling generates an `index.html` with multiple sections. Read them in this order:

**1. Global Information (top of report)**
- `Total requests` / `Failed requests` / `% of failed` → error rate
- `Min / Mean / Max / p50 / p75 / p95 / p99` response times → core SLA metrics
- Always use **p95** as primary; **Mean** is misleading in Gatling reports

**2. Response Time Distribution (histogram)**
- X-axis: response time buckets (ms)
- Y-axis: number of requests
- Healthy: right-skewed (most requests fast, few slow)
- Problem: bimodal (two humps) = two distinct user populations or cache hit/miss split
- Problem: flat/uniform = system under constant load, no variation

**3. Response Time Percentiles over Time (line chart)**
- X-axis: elapsed test time
- Y-axis: response time (ms) for p50, p75, p95, p99
- Healthy: flat horizontal lines during steady state
- Problem: upward trend = progressive degradation (memory leak, resource exhaustion)
- Problem: spike then recover = transient event (GC pause, retry storm, external dep blip)

**4. Number of Requests per Second (area chart)**
- X-axis: elapsed time
- Y-axis: RPS split by OK / KO (failed)
- Healthy: KO line near zero throughout
- Problem: KO area grows with time or at a concurrency threshold

**5. Number of Active Users over Time**
- Shows VU ramp-up profile
- If VU count never reaches configured peak = load generator bottleneck or ramp config issue

**6. Per-request breakdown (bottom table)**
- Shows stats for each named request in the simulation
- Sort by p95 descending to find the slowest endpoint
- Compare `% of failed` per request to identify which endpoint has the most errors

### Gatling field glossary

| Field | Meaning |
|---|---|
| `OK` | Requests that completed without failing the Gatling check |
| `KO` | Requests that failed a Gatling `check()` — NOT necessarily an HTTP error |
| `mean` / `stdDev` | Average and standard deviation — use only for context, not SLA eval |
| `min` / `max` | Extremes — max is often a single outlier; do not use for SLA |
| `p50` / `p75` / `p95` / `p99` | Percentile buckets — p95 is your primary metric |
| `throughput` | Requests per second in that time window |

### Common Gatling mistakes

- **KO ≠ HTTP error.** Gatling KO means a `check()` assertion failed. A 200 response with wrong body content = KO. Always check what your simulation's `check()` validates.
- **The "Mean" column dominates the table visually but is the least useful metric.** Focus on p95 column.
- **Warm-up spike at t=0.** Response time percentile chart often shows high values at the start before JVM warms up — exclude first 2–5 minutes from SLA evaluation.

---

## Locust

### HTML report sections

**Summary table (top)**

| Column | What it means |
|---|---|
| `Name` | Request name (endpoint or grouped name) |
| `# Requests` | Total requests made |
| `# Fails` | Requests where `response.failure()` was called or HTTP error |
| `Median (ms)` | p50 — half of requests faster than this |
| `90%ile (ms)` | p90 — 90% of requests faster |
| `95%ile (ms)` | p95 — primary SLA target |
| `99%ile (ms)` | p99 — tail latency |
| `Average (ms)` | Mean — misleading, use percentile columns instead |
| `Min (ms)` | Fastest single request |
| `Max (ms)` | Slowest single request — often an outlier |
| `Average size (bytes)` | Average response payload size |
| `Current RPS` | Requests per second at the time of snapshot |
| `Current Failures/s` | Failures per second at snapshot |

**Charts (HTML report)**

| Chart | What to look for |
|---|---|
| Response Times (ms) | Should be flat in steady state; distinguish p50 from p95 visually |
| Total Requests per Second | RPS + Failures per second; KO line should be near zero |
| Number of Users | VU ramp profile — verify peak reached |

### CSV files

Locust generates several CSV files with `--csv <prefix>`:
- `_stats.csv` → per-endpoint stats table (same as HTML summary)
- `_stats_history.csv` → time-series stats snapshot every ~2 seconds — use this for trend analysis
- `_failures.csv` → details of all failure messages — crucial for root cause
- `_exceptions.csv` → Python exceptions in user code — script errors, not load issues

**`_failures.csv` is the most important file for diagnosis.** It shows exactly what failed and why.

### Common Locust mistakes

- **`# Fails` counts `response.failure()` calls, not HTTP errors.** Without `catch_response=True`, HTTP 500s are counted as successes.
- **"Current RPS" in the web UI is a snapshot, not the test average.** Use CSV stats for accurate throughput.
- **Locust percentiles are computed from a rolling window, not all requests.** Very short tests may have imprecise percentiles.

---

## JMeter

### JTL file fields

JMeter writes results to a JTL file (CSV or XML). Key columns:

| Column | What it means |
|---|---|
| `elapsed` | Total response time in ms — this is your primary latency metric |
| `latency` | Time from request sent to first byte received (TTFB) |
| `connect` | TCP connection establishment time |
| `responseCode` | HTTP status code |
| `success` | true/false — based on JMeter's assertion rules |
| `bytes` | Response size in bytes |
| `sentBytes` | Request size in bytes |
| `threadName` | Which virtual user thread made the request |
| `label` | Request label / sampler name — equivalent to endpoint grouping |

**Key distinction:** `elapsed` = `connect` + `latency` + body download time. For server processing time, `latency` is the closest proxy (TTFB).

### HTML Dashboard Report

JMeter's Dashboard Report (`jmeter -g results.jtl -o dashboard/`) generates:

**Statistics panel:**
- Shows per-label (endpoint) breakdown with p50, p90, p95, p99, min, max, error rate
- Sort by `99th pct` to find slowest endpoints

**Charts to check in order:**
1. `Over Time > Response Times Over Time` — trend during the test
2. `Over Time > Transactions Per Second` — throughput trend
3. `Over Time > Response Codes Per Second` — error rate trend
4. `Throughput > Response Time Percentiles` — distribution shape

### Common JMeter mistakes

- **`elapsed` includes connection time.** If you want pure server processing, subtract `connect` from `elapsed`.
- **JMeter's "Average" in the Summary Report hides tail latency.** Always use the Aggregate Report or Dashboard for percentiles.
- **Assertions affect the `success` field, not `responseCode`.** A 200 response that fails a JMeter assertion shows `success=false`.
- **Think time (timers) is included in the test duration but NOT in `elapsed`.** Throughput math based on test duration may be wrong if timers are long.

---

## Artillery

### JSON report structure

Artillery generates a JSON report with `artillery run --output report.json`. Key sections:

```json
{
  "aggregate": {
    "counters": {
      "http.requests": 15000,
      "http.responses": 14980,
      "http.codes.200": 14850,
      "http.codes.500": 130,
      "errors.ECONNREFUSED": 20
    },
    "rates": {
      "http.request_rate": 50.2
    },
    "summaries": {
      "http.response_time": {
        "min": 45,
        "max": 8200,
        "mean": 310,
        "p50": 280,
        "p75": 420,
        "p95": 980,
        "p99": 2100
      }
    }
  },
  "intermediate": [...]
}
```

### Field guide

| Field | What it means |
|---|---|
| `http.requests` | Total requests sent |
| `http.responses` | Responses received (requests - responses = lost/timed out) |
| `http.codes.2xx` | Successful HTTP responses |
| `http.codes.5xx` | Server errors |
| `errors.ECONNREFUSED` | Connection refused — target unavailable or overloaded |
| `errors.ETIMEDOUT` | Request timed out — exceeds Artillery's timeout setting |
| `http.request_rate` | Requests per second (arrival rate) |
| `http.response_time` p95 | 95th percentile response time — primary SLA metric |
| `intermediate` | Array of per-interval stats snapshots — use for trend analysis |

### Error rate calculation in Artillery

```
error_rate = (http.codes.4xx + http.codes.5xx + errors.*) / http.requests × 100
```

Artillery does not compute error rate directly — calculate it from the counters above.

### Common Artillery mistakes

- **`http.requests` - `http.responses` = lost requests.** If this delta is non-zero, some requests timed out before receiving any response — a hard signal of saturation.
- **`mean` in `http.response_time` hides tail latency.** Use `p95` and `p99`.
- **Artillery uses an open arrival-rate model by default.** This means RPS is controlled, not VU count — different from Locust/JMeter closed models. A saturated system will queue requests, causing `response_time` to grow while `request_rate` stays constant.
- **Check `intermediate` array for time-series trends** — the aggregate hides ramp-up and degradation patterns.

---

## Cross-tool metric equivalence

| Concept | k6 | Gatling | Locust | JMeter | Artillery |
|---|---|---|---|---|---|
| Response time p95 | `http_req_duration p(95)` | `p95` in report | `95%ile` column | `95th pct` in dashboard | `http.response_time.p95` |
| Error rate | `http_req_failed` rate | `% of KO` | `# Fails / # Requests` | `Error %` in report | `(codes.4xx+5xx) / requests` |
| Throughput (RPS) | `http_reqs` count/duration | `throughput` | `Current RPS` | `Throughput` in report | `http.request_rate` |
| Server processing time | `http_req_waiting` | not directly available | not directly available | `latency` column | not directly available |
| Test passed / failed | Threshold PASS/FAIL | Overall OK/KO | Fail ratio | Assertion results | `ensure` conditions |
