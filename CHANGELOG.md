# Changelog

All notable improvements to performance-testing-skills are documented here.
Entries are grouped by skill and ordered from newest to oldest.
Benchmark data comes from [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) iterations.

Format: `[version] — date | benchmark results | key findings | what was fixed`

---

## k6-best-practices

### [1.3] — 2026-03-14

**Benchmark (iteration 1):**

| Config | Pass Rate | Time | Tokens |
|---|---|---|---|
| with_skill | 95% ± 11% | 61.4s | 19,557 |
| without_skill | 78.8% ± 5% | 43.5s | 10,616 |
| Delta | **+16pp** | +17.9s | +8,941 |

**Key findings:**
- Skill excels at enforcing explicit executor patterns, p95×1.2 VU sizing formula, and all 3 failure mechanisms (`check()` / threshold / `fail()`)
- `clarifies_open_is_init_only` failed in both configs — skill had the information but no instruction to surface it when fixing OOM issues. Baseline already knows this, so the assertion doesn't discriminate

**Fix:** Added explicit instruction: when fixing any `open()` or OOM issue, always clarify both error variants (OOM from plain variable vs. runtime error from `open()` inside `default()`).

### [1.2] — 2026-03-07 _(prior to skill-creator benchmarking)_
Improved `open()` error distinction, import ordering, TS setup, and modular trigger.

### [1.1] — initial release

---

## gatling-best-practices

### [1.1] — 2026-03-14

**Benchmark (iteration 1):**

| Config | Pass Rate | Time | Tokens |
|---|---|---|---|
| with_skill | 95.8% ± 8% | 71.4s | 18,676 |
| without_skill | 59.8% ± 31% | 59.5s | 11,266 |
| Delta | **+36pp** | +11.9s | +7,410 |

**Key findings:**
- Biggest win: Kotlin+Gradle eval — skill scores 7/7 vs. baseline's 1/7. Kotlin-specific gotchas (Double literals for `percentile()`, `gatlingRun-<Class>` task format, feeder pattern) are exactly what the skill was built to capture
- `without_skill` has very high variance (±31%) — baseline performance is unpredictable by eval type, confirming the skill's consistency value
- `uses_ramp_not_atOnce` assertion was too strict — penalized `rampConcurrentUsers()` even though it is valid and often more correct than `rampUsers()`

**Fix:** Updated eval assertion to accept any ramp-based strategy (`rampUsers`, `rampConcurrentUsers`, `rampUsersPerSec`).

### [1.0] — initial release

---

## performance-testing-strategy

### [1.3] — 2026-03-14

**Benchmark (iteration 1):**

| Config | Pass Rate | Time | Tokens |
|---|---|---|---|
| with_skill | 89.8% ± 9.5% | 144.2s | 23,535 |
| without_skill | 70.6% ± 8.7% | 100.2s | 12,264 |
| Delta | **+19pp** | +44.0s | +11,271 |

**Key findings:**
1. `no-sla-defined` is the skill's Achilles heel — both configs over-engineer test selection for a 20-user internal system. The quick-selection guide lacked a strong "steady + low-concurrency + internal = Smoke → Load only, stop there" rule. Baseline recommended 5 test types; skill still added Stress.
2. `resource-leak-investigation` had a skill bug — skill injected JVM flags (`-XX:+HeapDumpOnOutOfMemoryError`), Node.js API calls (`process.on()`), and Go metric names into its prerequisites section, causing `no_tool_specific_syntax` to fail — the skill's own content, not Claude going rogue.
3. `no_tool_specific_syntax` is the strongest discriminator — baseline fails it in 4 of 5 evals (always slips into k6 code or tool names). Skill passes 4 of 5 (only failed because of bug above).
4. `full-production-readiness` had an assertion design issue — `load_at_launch_and_year1` rewarded putting Year-1 growth in Load test. The skill correctly assigned it to Stress.
5. Smoke-first enforcement — baseline skips it in 3 of 5 evals. Skill enforces it perfectly in all 5.

**Fixes applied:**

| Eval | Finding | Fix |
|---|---|---|
| `no-sla-defined` | Skill added Stress for a 20-user internal tool | Added row to quick-selection table: "Low-risk internal (≤50 users) → Smoke → Load only, stop here" |
| `resource-leak-investigation` | Skill output included JVM flags and Node.js API calls in metrics section | Added instruction in Step 4: always express metrics in generic terms — never include runtime flags, API calls, or platform-specific names |
| `full-production-readiness` | Eval penalized skill for correctly placing Year-1 growth in Stress | Reworded assertion to accept any test type that addresses both launch and Year-1 horizons |

### [1.2] — 2026-03-07 _(prior to skill-creator benchmarking)_
Added test type tags to metadata.

### [1.0] — initial release

---

## Benchmark Baseline (as of 2026-03-14)

| Skill | Version | With skill | Without skill | Delta |
|---|---|---|---|---|
| `k6-best-practices` | v1.3 | 95% ± 11% | 78.8% ± 5% | +16pp |
| `gatling-best-practices` | v1.1 | 95.8% ± 8% | 59.8% ± 31% | +36pp |
| `performance-testing-strategy` | v1.3 | 89.8% ± 9.5% | 70.6% ± 8.7% | +19pp |
