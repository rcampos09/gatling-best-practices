# performance-testing-skills

A collection of [Claude Code](https://claude.ai/code) skills for performance testing.
Currently includes **gatling-best-practices** — for writing, fixing, and structuring
professional Gatling load test simulations across all five officially supported languages.

## Install

```bash
npx skills add rcampos09/performance-testing-skills
```

## What it does

Once installed, Claude automatically activates this skill when you mention load
testing, performance testing, Gatling, virtual users, ramp-up, injection profiles,
JMeter migration, throughput, or response time SLAs — even if you don't say
"Gatling" explicitly.

Every response delivers:

1. **A complete, runnable simulation file** — never a partial snippet
2. **The exact run command** with environment parameters (`baseUrl`, `users`, etc.)
3. **A one-line explanation** of the injection profile chosen and why it fits your load goal

## Languages and build tools

| Language | Build tool |
|---|---|
| Java | Maven · Gradle |
| Kotlin | Maven · Gradle |
| Scala | Maven · SBT |
| TypeScript | npm |
| JavaScript | npm |

## What's covered

### 5-Block Pattern
Every simulation is structured in the same consistent order:
`Protocol → Feeders → Scenario → Injection → Assertions`

### 7 Common Mistakes — checked on every simulation
1. Missing `pause()` between requests
2. Hardcoded dynamic tokens
3. `atOnceUsers` for load tests
4. No assertions
5. `.queue()` feeder for long tests
6. Check failure silently marking requests as FAILED
7. Missing `Content-Type` when sending a request body

### Injection profiles
Both open model (`injectOpen`) and closed model (`injectClosed`) with correct
profiles for: ramp, steady rate, stress peak, stairs, throttling, and concurrent users.

### Modular design patterns
Layered architecture (Config → Requests → Scenarios → Simulations) for scalable,
maintainable test suites in Java, Kotlin, Scala, and TypeScript.

### Protocols
- **HTTP/REST** — full DSL coverage
- **WebSocket** — included in Community Edition
- **MQTT / JMS** — Gatling Enterprise Edition only

### Scaffold and validation scripts
- `scripts/scaffold.sh` / `scaffold.ps1` — interactive project generator for all
  language and build-tool combinations
- `scripts/validate.sh` — catches the five most common configuration errors before
  running a test

## Requirements

| Runtime | Version |
|---|---|
| Java (JVM languages) | 11+ |
| Maven | 3.8+ |
| Gradle | 7+ |
| Node.js (JS/TS) | 18+ |

Compatible with **Claude Code**, **Cursor**, and **Windsurf**.

## Example prompts

```
I need a Gatling load test in Java with Maven for POST /api/v1/auth/login.
50 concurrent users, SLA p95 under 800ms. I have a CSV with test users.
```

```
My simulation fails with "No attribute named token is defined". Here is my scenario: ...
```

```
Migrate our JMeter test to Gatling TypeScript. 200 users, 2-minute ramp,
5-minute hold. E-commerce checkout flow. SLA p95 under 2s.
```

```
How should I structure a Gatling project with multiple flows in Java so it's
maintainable as the test suite grows?
```

## Author

**Rodrigo Campos Tapia**
- Email: [rcampos.tapia@gmail.com](mailto:rcampos.tapia@gmail.com)
- Web: [rodrigo-campos.dev](https://rodrigo-campos.dev/)
- LinkedIn: [linkedin.com/in/rcampostapia](https://www.linkedin.com/in/rcampostapia/)

## License

MIT
