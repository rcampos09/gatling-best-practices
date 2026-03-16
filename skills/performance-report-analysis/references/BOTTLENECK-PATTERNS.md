# Performance Bottleneck Patterns

## When to load this file

Load when the user asks to diagnose *why* a metric is degraded — CPU spikes, memory
growth, slow queries, connection exhaustion, or third-party dependency slowness.

---

## How to use this file

Match the observed symptom pattern to a bottleneck type. Each pattern includes:
- **Signatures** — what you see in the data
- **Confirmation steps** — how to verify the hypothesis
- **Remediation** — options ranked from lowest to highest impact

---

## Pattern 1 — CPU Saturation

**Signatures:**
- Latency (p95, p99) rises gradually and consistently as concurrency increases
- Throughput (RPS) plateaus and does not increase despite adding more users
- CPU utilization sustained above 70–80% during the test
- No memory growth, no error spikes at low load

**Confirmation:**
- CPU utilization graph shows correlation with latency increase
- Thread dump shows high CPU threads in compute (serialization, regex, encryption)
- Profiler shows hot methods consuming > 20% of CPU

**Remediation (lowest to highest effort):**
1. Reduce serialization overhead — switch to a lighter JSON library or format
2. Move CPU-intensive work off the request path (async queue, background worker)
3. Horizontal scaling — add instances behind a load balancer
4. Code-level optimization — algorithmic improvements in hot paths
5. Hardware upgrade — larger CPU, more cores per instance

---

## Pattern 2 — Memory Leak / Heap Exhaustion

**Signatures (Endurance / Soak tests):**
- Response times are acceptable for the first 30–60 minutes, then degrade steadily
- Memory utilization grows monotonically over the test duration
- Garbage collection frequency increases; GC pause duration grows
- System eventually restarts or produces OOM errors

**Signatures (short tests):**
- Memory grows but GC temporarily reclaims it (sawtooth pattern)
- Heap utilization trend is upward even after GC cycles

**Confirmation:**
- Heap dump at multiple intervals shows growing retained objects
- Memory profiler identifies objects not being released (listener registrations, caches without eviction, static collections)
- RSS/virtual memory grows even after GC

**Remediation:**
1. Add cache eviction policies (TTL, LRU, max-size) on unbounded caches
2. Remove static collection accumulators (event listeners, request logs)
3. Fix connection or resource leaks (close streams, release DB connections in finally blocks)
4. Tune GC settings — increase heap size as a temporary measure, not a fix
5. Refactor to streaming or lazy loading for large data sets

---

## Pattern 3 — Database Bottleneck

**Signatures:**
- Application p95 latency spikes correlate with DB slow query metrics
- DB CPU or I/O utilization is high while application CPU is low
- Connection pool metrics show threads waiting for a connection
- Error pattern: connection timeout, statement timeout, lock wait timeout

**Sub-patterns:**

| Sub-pattern | Indicator | Root cause |
|---|---|---|
| Slow queries | DB CPU high, specific queries in slow query log | Missing index, full table scan |
| N+1 queries | Request count grows faster than user count | ORM fetching related records one by one |
| Lock contention | Lock wait timeouts under concurrent writes | Long transactions, missing optimistic locking |
| Connection pool exhaustion | Connection acquire timeout | Pool too small, connections not released |
| Replication lag | Reads returning stale data, read replica CPU high | Write volume exceeds replica capacity |

**Confirmation:**
- Enable slow query log during the test; identify queries > 100ms
- Count database round-trips per business transaction (should be ≤ 5 for simple flows)
- Check connection pool metrics: active, idle, waiting, timeout count
- Check for lock wait events in DB performance schema

**Remediation:**
1. Add indexes on columns used in WHERE, JOIN, ORDER BY for slow queries
2. Batch N+1 queries using eager loading or IN() queries
3. Reduce transaction scope — commit early, avoid holding locks while doing application logic
4. Increase connection pool size (with caution — DB has a max connections limit)
5. Introduce read replicas for read-heavy workloads
6. Add a cache layer (Redis, Memcached) for frequently-read, rarely-changed data

---

## Pattern 4 — Thread / Worker Pool Exhaustion

**Signatures:**
- Application p95 is fine at moderate load; jumps sharply above a concurrency threshold
- Errors are 503 Service Unavailable or "connection refused" from the app server
- Request queue depth grows under load
- Server CPU and memory are low — the application is not compute-bound

**Confirmation:**
- App server thread pool metrics: active threads at or near max
- Request queuing time visible in APM traces (time before the first byte is processed)
- Increase thread pool size → throughput increases → confirms pool was the bottleneck

**Remediation:**
1. Increase thread pool / worker pool size (first step — quick to validate)
2. Identify blocking I/O on threads (sync HTTP calls to external services, file I/O)
3. Convert synchronous I/O to async to free threads during waiting
4. Add a non-blocking event loop for I/O-bound services (move from thread-per-request to async model)
5. Horizontal scaling to distribute incoming connections

---

## Pattern 5 — Network / Bandwidth Saturation

**Signatures:**
- Latency is high even for small payloads
- Throughput (bytes/sec) plateaus at a fixed ceiling regardless of user count
- Network I/O utilization on the server or load balancer is at 100%
- Errors are connection timeouts, not application errors

**Confirmation:**
- Network I/O graph shows saturation correlated with latency spike
- Payload sizes are large (images, reports, uncompressed JSON)
- Network throughput = bandwidth limit ÷ average payload size = max achievable RPS

**Remediation:**
1. Enable HTTP compression (gzip/brotli) for text responses — reduces payload 60–80%
2. Reduce payload size — paginate large lists, remove unused fields from API responses
3. Enable CDN for static assets — offloads bandwidth from the origin server
4. Upgrade network bandwidth (NIC, load balancer tier, peering capacity)
5. Move to binary protocols (gRPC/Protobuf) for high-throughput internal services

---

## Pattern 6 — Third-Party / External Dependency Degradation

**Signatures:**
- Latency of a specific endpoint is high; all others are normal
- Error pattern matches timeouts to an external host
- Application CPU and memory are healthy
- APM traces show time spent waiting for an outbound HTTP call

**Confirmation:**
- Trace waterfall: identify which downstream call is slow
- Check if external service has its own SLA and whether it is being met
- Reproduce with a synthetic call to the external service from the same network

**Remediation:**
1. Add a timeout on outbound calls — prevent slow external services from holding threads indefinitely
2. Add a circuit breaker — fail fast when the dependency is degraded (prevents cascade failure)
3. Cache responses from the external service where TTL is acceptable
4. Stub the dependency in performance tests to isolate it from the measurement
5. Negotiate SLA with the vendor or evaluate alternatives

---

## Pattern 7 — Cold Start / Warm-Up Effect

**Signatures:**
- First requests in a test have significantly higher latency than steady-state
- JVM or runtime language with JIT compilation shows this most prominently
- After 2–5 minutes, latency stabilizes at a lower level
- Results from short tests include warm-up in the percentiles, inflating numbers

**Confirmation:**
- Plot latency over time — downward trend at the start, then plateau
- Compare p95 during first 2 minutes vs. steady state
- Identify if infrastructure uses lazy initialization (connection pools, JIT, DNS caches)

**Remediation:**
1. Exclude warm-up period from SLA evaluation — use a ramp-up phase and only evaluate steady state
2. Add warm-up steps to the load test (low traffic for 2–5 minutes before ramping to peak)
3. Pre-warm instances before deploying behind a load balancer (readiness probe)
4. Use AOT compilation or pre-warming scripts in the deployment process

---

## Multi-Bottleneck Scenarios

When more than one pattern is present, follow this resolution order:

1. Fix bugs first — errors at any load level mask capacity measurements
2. Fix the primary bottleneck — the one that appears at the lowest load
3. Retest — secondary bottlenecks often reveal themselves only after the primary is fixed
4. Never tune performance parameters (pool sizes, thread counts) before fixing root causes

> **Important:** All root causes in this document are hypotheses until confirmed with
> infrastructure data, traces, or profiler output. State hypotheses as hypotheses
> in reports — never present unconfirmed root causes as facts.
