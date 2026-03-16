# performance-testing-skills

A collection of [Claude Code](https://claude.ai/code) skills for performance and load
testing. Install one or all — each skill activates automatically when you describe a
relevant task.

## Install

```bash
# Install all skills in this repo
npx skills add rcampos09/performance-testing-skills

# Install a specific skill
npx skills add rcampos09/performance-testing-skills --skill gatling-best-practices
```

Compatible with **Claude Code**, **Cursor**, and **Windsurf**.

## Available Skills

| Skill | Triggers on | Languages |
|---|---|---|
| [`gatling-best-practices`](skills/gatling-best-practices/SKILL.md) | load testing, performance testing, Gatling, virtual users, ramp-up, JMeter migration, throughput, response time SLAs | Java · Kotlin · Scala · TypeScript · JavaScript |
| [`performance-testing-strategy`](skills/performance-testing-strategy/SKILL.md) | performance test plan, test strategy, Smoke test, Load test, Stress test, Spike test, Endurance test, Soak test, SLA definition, how many users, where to start with performance testing | Tool-agnostic |
| [`k6-best-practices`](skills/k6-best-practices/SKILL.md) | k6, Grafana k6, load testing JavaScript, virtual users, VUs, scenarios, executors, thresholds, checks, SharedArray, arrival rate, open model, closed model, ramp-up stages, WebSocket, gRPC | JavaScript · TypeScript |
| [`locust-best-practices`](skills/locust-best-practices/SKILL.md) | Locust, locustfile, HttpUser, TaskSet, load testing Python, virtual users, spawn rate, wait_time, catch_response, LoadTestShape, ramp-up stages, spike test | Python |
| [`performance-report-analysis`](skills/performance-report-analysis/SKILL.md) | analyze test results, interpret load test output, p95 high, error rate under load, write performance report, explain results to manager, technical report, business report, stakeholder summary, bottleneck analysis | Tool-agnostic |

## How it works

Once installed, skills activate automatically — no slash command needed. Just describe
your task in natural language and Claude picks up the right skill.

Each skill delivers:
1. **A complete, runnable file** — never a partial snippet
2. **The exact run command** with environment parameters
3. **A one-line explanation** of the approach chosen and why

## Requirements

| Runtime | Version |
|---|---|
| Java (JVM languages) | 11+ |
| Maven | 3.8+ |
| Gradle | 8.x (Gradle 9 not yet supported by Gatling plugin) |
| Node.js (JS/TS) | 18+ |
| k6 | latest (`brew install k6` / `apt install k6` / `choco install k6`) |
| Python (Locust) | 3.8+ (`pip install locust`) |

## Author

**Rodrigo Campos Tapia**
- Email: [rcampos.tapia@gmail.com](mailto:rcampos.tapia@gmail.com)
- Web: [rodrigo-campos.dev](https://rodrigo-campos.dev/)
- LinkedIn: [linkedin.com/in/rcampostapia](https://www.linkedin.com/in/rcampostapia/)

## License

MIT
