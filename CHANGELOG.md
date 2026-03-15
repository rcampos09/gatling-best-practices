# Changelog

All notable improvements to performance-testing-skills are documented here.
Entries are grouped by skill and ordered from newest to oldest.
Benchmark data comes from [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) iterations.

Format: `[version] — date | benchmark results | key findings | what was fixed`

---

## locust-best-practices

### [1.1] — 2026-03-15 (iteration 1 — fixes applied)

**Benchmark (iteration 1):**

| Config | Pass Rate | Time | Tokens |
|---|---|---|---|
| with_skill | 95.1% | 77.8s | 19,383 |
| without_skill | 91.4% | 70.0s | 12,193 |
| Delta | **+3.7pp** | +7.8s | +7,190 |

**Key findings:**
- Eval 7 (WebSocket) is the biggest win: with_skill 100% vs. without_skill 60%. Skill correctly enforces `abstract=True` on the base WebSocket user class — baseline missed this entirely.
- Eval 5 (CSV parameterization) showed a regression: with_skill 75% vs. without_skill 100%. Skill-guided agent stored `self.username` but forgot `self.password`. Guidance was not explicit enough.
- Evals 2, 3, 4, 6, 8 tie at 100% — `catch_response`, `LoadTestShape`, `name=`, `weight`, and `quitting` event are well-known enough that baseline handles them without the skill.
- Eval 1 assertion was too strict: penalized a correct `LoadTestShape` response that properly omits `-u`/`-r` flags.

**Fixes applied:**

| Issue | Fix |
|---|---|
| Eval 5 regression — only `self.username` stored | Added explicit instruction: store **all** CSV fields as instance attributes (`self.username` AND `self.password`) |
| Eval 1 assertion too strict | Reworded to accept LoadTestShape responses without `-u`/`-r` |

### [1.0] — 2026-03-15 (initial release)

---

## k6-best-practices

### [1.4] — 2026-03-15 (iteration 2 — structural improvement confirmed)

**Benchmark (iteration 2 — v1.4 vs v1.3):**

| Config | Pass Rate | Time | Tokens |
|---|---|---|---|
| with_skill (v1.4) | **100%** | 79.6s | 20,064 |
| old_skill (v1.3) | **100%** | 74.5s | 19,479 |
| Delta | 0pp | +5.1s | +585 |

**Key finding:** Both versions scored 100% — the `clarifies_open_is_init_only` failure in iteration 1 was **statistical noise** (N=1 per eval), not a systematic gap. Deltas under ~20pp are unreliable with a single run per eval.

**What this means for the skill:** v1.4 moves the `open()` dual-error instruction to the Output Format section (more prominent placement) — a structural improvement that cannot be measured at N=1 but follows best practices for instruction visibility.

**Statistical note:** To reliably detect gaps < 20pp, run each eval N ≥ 3 times. This applies to all skills in this repo.

---

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

### [1.3] — 2026-03-14 (iteration 2 — fixes confirmed)

**Benchmark (iteration 2):**

| Config | Pass Rate | Time | Tokens |
|---|---|---|---|
| with_skill | **100% (5/5 perfect)** | 179.8s | 26,948 |
| without_skill | 73.4% | 176.3s | 20,301 |
| Delta | **+26.6pp** | +3.5s | +6,647 (+33%) |

**Fixes confirmed:**
- `resource-leak-investigation`: `no_tool_specific_syntax` now passes — JVM flags, Node.js APIs, and Go metric names no longer appear in prerequisites
- `no-sla-defined`: `recommends_smoke_then_load` now passes — skill correctly stops at Smoke → Load for low-risk internal systems

**Improvement vs. iteration 1:** 89.8% → 100% (+10.2pp). Delta grew from +19pp to +26.6pp.

---

### [1.3] — 2026-03-14 (iteration 1)

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

_Final baseline after all skill-creator iterations (2026-03-15)._

| Skill | Version | Iteration | With skill | Without skill | Delta |
|---|---|---|---|---|---|
| `k6-best-practices` | v1.4 | 2 | **100%** | 78.8% ± 5% | — |
| `gatling-best-practices` | v1.1 | 1 | 95.8% ± 8% | 59.8% ± 31% | +36pp |
| `performance-testing-strategy` | v1.3 | 2 | **100%** | 73.4% | +26.6pp |

> ⚠️ **Statistical note:** Pass rate deltas under ~20pp require N ≥ 3 runs per eval to be reliable. Results with high variance (±10%+) should be interpreted with caution.
