# Modular Design Patterns for Gatling

Apply these patterns from day one. A flat, monolithic simulation works for a
single script — it becomes unmaintainable the moment a second engineer touches
it or the test suite grows beyond one flow.

---

## The Core Principle: Separation of Responsibilities

| Layer      | Owns                                      | Never contains              |
|------------|-------------------------------------------|-----------------------------|
| Simulation | Load profile, injection, assertions        | Business logic, requests    |
| Scenario   | Ordered user flow (what a user does)       | HTTP details, raw JSON       |
| Requests   | Individual HTTP calls, checks, extractions | Injection, scenario ordering |
| Feeders    | Test data supply                           | Assertions, HTTP config      |
| Config     | Base URL, headers, environment params      | Scenario logic               |

---

## Recommended Folder Structure

### Java / Kotlin (Maven or Gradle)

```
src/test/java/
├── simulations/
│   └── CheckoutSimulation.java       ← load profile only
├── scenarios/
│   ├── CheckoutScenario.java         ← full user flow
│   └── BrowseScenario.java
├── requests/
│   ├── LoginRequests.java            ← reusable chains
│   ├── ProductRequests.java
│   └── CheckoutRequests.java
├── feeders/
│   └── UserFeeder.java               ← programmatic feeders
└── config/
    ├── Environment.java              ← base URL, timeouts
    └── Protocols.java                ← HttpProtocolBuilder

src/test/resources/
└── data/
    └── users.csv                     ← CSV feeders
```

### Scala (Maven or SBT)

```
src/test/scala/
├── simulations/
│   └── CheckoutSimulation.scala
├── scenarios/
│   ├── CheckoutScenario.scala
│   └── LoginScenario.scala
├── requests/
│   ├── LoginRequests.scala
│   ├── ProductRequests.scala
│   └── CheckoutRequests.scala
├── feeders/
│   └── UserFeeder.scala
└── config/
    ├── Environment.scala
    └── Protocols.scala
```

### TypeScript / JavaScript (npm)

```
src/
├── checkoutSimulation.gatling.ts       ← simulation file must be in src/ directly
├── scenarios/
│   ├── checkoutScenario.ts
│   └── browseScenario.ts
├── requests/
│   ├── loginRequests.ts
│   ├── productRequests.ts
│   └── checkoutRequests.ts
└── config/
    ├── environment.ts
    └── protocols.ts

src/resources/data/
└── users.csv
```

---

## Layer Examples

### Config layer — centralize environment and protocol

**Java:**
```java
// config/Environment.java
public class Environment {
    public static final String BASE_URL =
        System.getProperty("baseUrl", "https://dev.example.com");
}

// config/Protocols.java
public class Protocols {
    public static final HttpProtocolBuilder HTTP = http
        .baseUrl(Environment.BASE_URL)
        .acceptHeader("application/json")
        .contentTypeHeader("application/json");
}
```

**Scala:**
```scala
// config/Environment.scala
object Environment {
  val baseUrl: String = sys.props.getOrElse("baseUrl", "https://dev.example.com")
}

// config/Protocols.scala
object Protocols {
  val http: HttpProtocolBuilder = HttpDsl.http
    .baseUrl(Environment.baseUrl)
    .acceptHeader("application/json")
}
```

**TypeScript:**
```typescript
// config/environment.ts
export const BASE_URL = process.env.BASE_URL ?? "https://dev.example.com";

// config/protocols.ts
import { http } from "@gatling.io/http";
import { BASE_URL } from "./environment";
export const httpProtocol = http.baseUrl(BASE_URL).acceptHeader("application/json");
```

---

### Requests layer — reusable chains, not full scenarios

**Java:**
```java
// requests/LoginRequests.java
public class LoginRequests {

    public static ChainBuilder login() {
        return exec(http("POST Login")
            .post("/auth/login")
            .body(StringBody("{\"username\":\"#{username}\",\"password\":\"#{password}\"}"))
            .check(status().is(200))
            .check(jsonPath("$.token").saveAs("token")));
    }

    // Compose fine-grained chains into a flow
    public static ChainBuilder loginAndVerify() {
        return login()
            .pause(1)
            .exec(http("GET Profile")
                .get("/me")
                .header("Authorization", "Bearer #{token}")
                .check(status().is(200)));
    }
}
```

**Scala:**
```scala
// requests/LoginRequests.scala
object LoginRequests {

  val login: ChainBuilder =
    exec(http("POST Login")
      .post("/auth/login")
      .body(StringBody("""{"username":"#{username}","password":"#{password}"}"""))
      .check(status.is(200))
      .check(jsonPath("$.token").saveAs("token")))

  val loginAndVerify: ChainBuilder =
    login.pause(1)
      .exec(http("GET Profile")
        .get("/me")
        .header("Authorization", "Bearer #{token}")
        .check(status.is(200)))
}
```

**TypeScript:**
```typescript
// requests/loginRequests.ts
import { exec } from "@gatling.io/core";
import { http, status, jsonPath } from "@gatling.io/http";

export const login = exec(
  http("POST Login").post("/auth/login")
    .body(`{"username":"#{username}","password":"#{password}"}`)
    .check(status().is(200))
    .check(jsonPath("$.token").saveAs("token"))
);
```

---

### Scenarios layer — compose requests into user flows

**Java:**
```java
// scenarios/CheckoutScenario.java
public class CheckoutScenario {

    public static ScenarioBuilder build() {
        return scenario("User Checkout Flow")
            .feed(csv("data/users.csv").circular())
            .exec(LoginRequests.login())
            .pause(1, 3)
            .exec(ProductRequests.search())
            .pause(1, 2)
            .exec(ProductRequests.viewDetail())
            .pause(1)
            .exec(CheckoutRequests.addToCart())
            .pause(1)
            .exec(CheckoutRequests.pay());
    }
}
```

**Scala:**
```scala
// scenarios/CheckoutScenario.scala
object CheckoutScenario {

  val checkoutFlow: ScenarioBuilder =
    scenario("User Checkout Flow")
      .feed(csv("data/users.csv").circular())
      .exec(LoginRequests.login)
      .pause(1, 3)
      .exec(ProductRequests.search)
      .pause(1, 2)
      .exec(ProductRequests.viewDetail)
      .pause(1)
      .exec(CheckoutRequests.addToCart)
      .pause(1)
      .exec(CheckoutRequests.pay)
}
```

---

### Simulation layer — load profile only, no business logic

**Java:**
```java
// simulations/CheckoutSimulation.java
public class CheckoutSimulation extends Simulation {
    {
        setUp(
            CheckoutScenario.build()
                .injectOpen(rampUsers(100).during(Duration.ofSeconds(60)))
        ).protocols(Protocols.HTTP)
         .assertions(
             global().successfulRequests().percent().gt(99.0),
             global().responseTime().percentile(95).lt(2000)
         );
    }
}
```

**Scala:**
```scala
// simulations/CheckoutSimulation.scala
class CheckoutSimulation extends Simulation {
  setUp(
    CheckoutScenario.checkoutFlow.inject(rampUsers(100).during(60))
  ).protocols(Protocols.http)
   .assertions(
     global().successfulRequests().percent().gt(99.0),
     global().responseTime().percentile(95).lt(2000)
   )
}
```

---

## Advanced: Scenario Builder Pattern

When you need the same flow at different load levels (smoke → load → stress),
build a factory function instead of duplicating scenarios:

**Java:**
```java
// scenarios/UserFlows.java
public class UserFlows {

    public static ScenarioBuilder basicUser(String name) {
        return scenario(name)
            .feed(csv("data/users.csv").circular())
            .exec(LoginRequests.login())
            .pause(1, 3)
            .exec(ProductRequests.browse());
    }

    public static ScenarioBuilder powerUser(String name) {
        return scenario(name)
            .feed(csv("data/users.csv").circular())
            .exec(LoginRequests.login())
            .pause(1, 2)
            .exec(ProductRequests.search())
            .pause(1, 2)
            .exec(CheckoutRequests.pay());
    }
}

// In the simulation — mix user types with weighted injection
setUp(
    UserFlows.basicUser("Browsers").injectOpen(rampUsers(80).during(60)),
    UserFlows.powerUser("Buyers").injectOpen(rampUsers(20).during(60))
).protocols(Protocols.HTTP);
```

---

## Separate by Domain, Not by HTTP Method

**Wrong — groups by technical type:**
```
requests/
  GetRequests.java
  PostRequests.java
  PutRequests.java
```

**Right — groups by business domain:**
```
requests/
  LoginRequests.java
  ProductRequests.java
  CheckoutRequests.java
  SearchRequests.java
```

Each domain file owns all HTTP methods for that feature. This mirrors how
product teams are organized and makes it easy to find and change related code.

---

## Anti-Patterns to Avoid

| Anti-pattern | Impact | Fix |
|---|---|---|
| Simulation with 500+ lines | Unmaintainable, merge conflicts | Extract to Scenario + Request layers |
| Login copy-pasted across scenarios | Changes break multiple files | Move to `LoginRequests`, import everywhere |
| Hardcoded `baseUrl` in simulation | Can't switch environments | Use `System.getProperty` / `process.env` in Config |
| No feeders — same user for all VUs | Server sees one session, not many | Add CSV feeder with `.circular()` |
| One scenario for all user types | Can't vary load per persona | Builder pattern: one factory, many scenarios |
| `atOnceUsers` for load tests | Unrealistic spike, meaningless data | Use `rampUsers` + `constantUsersPerSec` |
