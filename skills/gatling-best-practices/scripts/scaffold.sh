#!/usr/bin/env bash
# scaffold.sh — Scaffolds a new Gatling project from scratch.
# Usage: bash scaffold.sh
# Compatible with macOS and Linux.

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
ask()     { echo -e "${BOLD}$*${RESET}"; }

# ── Prompts ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Gatling Project Scaffold           ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# Project name
ask "Project name (e.g. my-perf-tests):"
read -r PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-my-perf-tests}"
[[ "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]] || error "Invalid project name. Use letters, numbers, hyphens, underscores."

# Language
echo ""
ask "Language:"
echo "  1) Java       (recommended)"
echo "  2) Kotlin"
echo "  3) Scala"
echo "  4) TypeScript"
echo "  5) JavaScript"
read -rp "Choice [1]: " LANG_CHOICE
LANG_CHOICE="${LANG_CHOICE:-1}"

case "$LANG_CHOICE" in
  1) LANG="java"       ;;
  2) LANG="kotlin"     ;;
  3) LANG="scala"      ;;
  4) LANG="typescript" ;;
  5) LANG="javascript" ;;
  *) error "Invalid choice." ;;
esac

# Build tool (JS/TS always uses npm)
if [[ "$LANG" == "typescript" || "$LANG" == "javascript" ]]; then
  BUILD_TOOL="npm"
else
  echo ""
  ask "Build tool:"
  echo "  1) Maven      (recommended)"
  echo "  2) Gradle"
  read -rp "Choice [1]: " BUILD_CHOICE
  BUILD_CHOICE="${BUILD_CHOICE:-1}"
  case "$BUILD_CHOICE" in
    1) BUILD_TOOL="maven"  ;;
    2) BUILD_TOOL="gradle" ;;
    *) error "Invalid choice." ;;
  esac
fi

# Package / simulation name
echo ""
ask "Base package (e.g. com.example.perf):"
read -r BASE_PACKAGE
BASE_PACKAGE="${BASE_PACKAGE:-perf}"

ask "Simulation class name (e.g. ApiSimulation):"
read -r SIM_CLASS
SIM_CLASS="${SIM_CLASS:-ApiSimulation}"

ask "Target base URL (e.g. https://api.example.com):"
read -r BASE_URL
BASE_URL="${BASE_URL:-https://api.example.com}"

# ── Create project structure ──────────────────────────────────────────────────
TARGET_DIR="./${PROJECT_NAME}"
info "Creating project at ${TARGET_DIR}/"

mkdir -p "${TARGET_DIR}"

# ── JVM languages ─────────────────────────────────────────────────────────────
if [[ "$LANG" != "typescript" && "$LANG" != "javascript" ]]; then
  PACKAGE_PATH="${BASE_PACKAGE//./\/}"

  case "$LANG" in
    java|kotlin) SRC_EXT="${LANG}"; FILE_EXT=$([ "$LANG" == "java" ] && echo "java" || echo "kt") ;;
    scala)        SRC_EXT="scala";  FILE_EXT="scala" ;;
  esac

  SIM_DIR="${TARGET_DIR}/src/test/${SRC_EXT}/${PACKAGE_PATH}"
  RES_DIR="${TARGET_DIR}/src/test/resources"

  mkdir -p "${SIM_DIR}"
  mkdir -p "${RES_DIR}/data"

  # ── pom.xml (Maven) ──────────────────────────────────────────────────────
  if [[ "$BUILD_TOOL" == "maven" ]]; then
    info "Writing pom.xml..."
    ARTIFACT_ID="${PROJECT_NAME}"

    SCALA_PLUGIN=""
    KOTLIN_PLUGIN=""
    LANG_COMPILER_PLUGIN=""

    if [[ "$LANG" == "scala" ]]; then
      SCALA_PLUGIN=$(cat <<'EOF'
    <plugin>
      <groupId>net.alchim31.maven</groupId>
      <artifactId>scala-maven-plugin</artifactId>
      <version>4.9.2</version>
      <executions>
        <execution>
          <goals><goal>testCompile</goal></goals>
        </execution>
      </executions>
    </plugin>
EOF
)
    elif [[ "$LANG" == "kotlin" ]]; then
      KOTLIN_PLUGIN=$(cat <<'EOF'
    <plugin>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-maven-plugin</artifactId>
      <version>2.0.0</version>
      <executions>
        <execution>
          <id>test-compile</id>
          <goals><goal>test-compile</goal></goals>
        </execution>
      </executions>
    </plugin>
EOF
)
    fi

    cat > "${TARGET_DIR}/pom.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
           http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>${BASE_PACKAGE}</groupId>
  <artifactId>${ARTIFACT_ID}</artifactId>
  <version>1.0.0-SNAPSHOT</version>

  <properties>
    <maven.compiler.release>17</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <gatling.version>3.14.5</gatling.version>
    <gatling-maven-plugin.version>4.14.0</gatling-maven-plugin.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>io.gatling.highcharts</groupId>
      <artifactId>gatling-charts-highcharts</artifactId>
      <version>\${gatling.version}</version>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
${SCALA_PLUGIN}${KOTLIN_PLUGIN}
      <plugin>
        <groupId>io.gatling</groupId>
        <artifactId>gatling-maven-plugin</artifactId>
        <version>\${gatling-maven-plugin.version}</version>
      </plugin>
    </plugins>
  </build>
</project>
EOF

  # ── build.gradle (Gradle) ─────────────────────────────────────────────
  else
    info "Writing build.gradle..."
    cat > "${TARGET_DIR}/build.gradle" <<EOF
plugins {
  id 'io.gatling.gradle' version '4.14.0'
}

group = '${BASE_PACKAGE}'
version = '1.0.0-SNAPSHOT'

gatling {
  jvmArgs = ['-Xms512m', '-Xmx2g']
}

dependencies {
  gatling 'io.gatling.highcharts:gatling-charts-highcharts:3.14.5'
}
EOF
  fi

  # ── gatling.conf ─────────────────────────────────────────────────────────
  info "Writing gatling.conf..."
  cp "$(dirname "$0")/../assets/config/gatling.conf" "${RES_DIR}/gatling.conf" 2>/dev/null || \
  cat > "${RES_DIR}/gatling.conf" <<'EOF'
gatling {
  core {
    encoding = "utf-8"
    shutdownTimeout = 5000
  }
  http {
    requestTimeout = 60000
    connectTimeout = 10000
    pooledConnectionIdleTimeout = 60000
  }
}
EOF

  # ── logback-test.xml ─────────────────────────────────────────────────────
  info "Writing logback-test.xml..."
  cat > "${RES_DIR}/logback-test.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <encoder>
      <pattern>%d{HH:mm:ss.SSS} [%-5level] %logger{15} - %msg%n</pattern>
    </encoder>
  </appender>
  <!-- Uncomment to enable HTTP request/response logging -->
  <!-- <logger name="io.gatling.http.engine.response" level="DEBUG" /> -->
  <root level="WARN">
    <appender-ref ref="CONSOLE" />
  </root>
</configuration>
EOF

  # ── Sample feeder ────────────────────────────────────────────────────────
  info "Writing sample feeder data..."
  cat > "${RES_DIR}/data/users.csv" <<'EOF'
username,password
user01,pass01
user02,pass02
user03,pass03
user04,pass04
user05,pass05
EOF

  # ── Simulation class ─────────────────────────────────────────────────────
  info "Writing ${SIM_CLASS}.${FILE_EXT}..."

  if [[ "$LANG" == "java" ]]; then
    cat > "${SIM_DIR}/${SIM_CLASS}.java" <<EOF
package ${BASE_PACKAGE};

import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;
import java.time.Duration;
import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

public class ${SIM_CLASS} extends Simulation {

  // ── 1. Protocol ───────────────────────────────────────────────────────────
  private final HttpProtocolBuilder httpProtocol = http
      .baseUrl(System.getProperty("baseUrl", "${BASE_URL}"))
      .acceptHeader("application/json")
      .contentTypeHeader("application/json");

  // ── 2. Feeders ────────────────────────────────────────────────────────────
  private final FeederBuilder<String> userFeeder = csv("data/users.csv").circular();

  // ── 3. Scenario ───────────────────────────────────────────────────────────
  private final ScenarioBuilder scn = scenario("${SIM_CLASS}")
      .feed(userFeeder)
      .exec(http("GET Home")
          .get("/")
          .check(status().is(200)))
      .pause(1, 3);
      // TODO: add your requests here

  // ── 4. Injection + 5. Assertions ──────────────────────────────────────────
  private static final int USERS = Integer.getInteger("users", 10);

  {
    setUp(
        scn.injectOpen(
            rampUsers(USERS).during(Duration.ofSeconds(60))
        ).protocols(httpProtocol)
    ).assertions(
        global().successfulRequests().percent().gt(99.0),
        global().responseTime().percentile(95).lt(1000)
    );
  }
}
EOF

  elif [[ "$LANG" == "kotlin" ]]; then
    cat > "${SIM_DIR}/${SIM_CLASS}.kt" <<EOF
package ${BASE_PACKAGE}

import io.gatling.javaapi.core.*
import io.gatling.javaapi.http.*
import io.gatling.javaapi.core.CoreDsl.*
import io.gatling.javaapi.http.HttpDsl.*
import java.time.Duration

class ${SIM_CLASS} : Simulation() {

  // ── 1. Protocol ───────────────────────────────────────────────────────────
  private val httpProtocol = http
      .baseUrl(System.getProperty("baseUrl", "${BASE_URL}"))
      .acceptHeader("application/json")
      .contentTypeHeader("application/json")

  // ── 2. Feeders ────────────────────────────────────────────────────────────
  private val userFeeder = csv("data/users.csv").circular()

  // ── 3. Scenario ───────────────────────────────────────────────────────────
  private val scn = scenario("${SIM_CLASS}")
      .feed(userFeeder)
      .exec(http("GET Home")
          .get("/")
          .check(status().`is`(200)))
      .pause(1, 3)
      // TODO: add your requests here

  // ── 4. Injection + 5. Assertions ──────────────────────────────────────────
  private val users = System.getProperty("users", "10").toInt()

  init {
    setUp(
        scn.injectOpen(
            rampUsers(users).during(Duration.ofSeconds(60))
        ).protocols(httpProtocol)
    ).assertions(
        global().successfulRequests().percent().gt(99.0),
        global().responseTime().percentile(95).lt(1000)
    )
  }
}
EOF

  elif [[ "$LANG" == "scala" ]]; then
    cat > "${SIM_DIR}/${SIM_CLASS}.scala" <<EOF
package ${BASE_PACKAGE}

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._

class ${SIM_CLASS} extends Simulation {

  // ── 1. Protocol ───────────────────────────────────────────────────────────
  val httpProtocol = http
    .baseUrl(sys.props.getOrElse("baseUrl", "${BASE_URL}"))
    .acceptHeader("application/json")
    .contentTypeHeader("application/json")

  // ── 2. Feeders ────────────────────────────────────────────────────────────
  val userFeeder = csv("data/users.csv").circular

  // ── 3. Scenario ───────────────────────────────────────────────────────────
  val scn = scenario("${SIM_CLASS}")
    .feed(userFeeder)
    .exec(http("GET Home")
      .get("/")
      .check(status.is(200)))
    .pause(1, 3)
    // TODO: add your requests here

  // ── 4. Injection + 5. Assertions ──────────────────────────────────────────
  val users = sys.props.getOrElse("users", "10").toInt

  setUp(
    scn.inject(
      rampUsers(users).during(60.seconds)
    ).protocols(httpProtocol)
  ).assertions(
    global.successfulRequests.percent.gt(99.0),
    global.responseTime.percentile(95).lt(1000)
  )
}
EOF
  fi

# ── JS / TS ───────────────────────────────────────────────────────────────────
else
  SIM_DIR="${TARGET_DIR}/src"
  RES_DIR="${TARGET_DIR}/src/resources/data"
  mkdir -p "${SIM_DIR}" "${RES_DIR}"

  info "Writing package.json..."
  cat > "${TARGET_DIR}/package.json" <<EOF
{
  "name": "${PROJECT_NAME}",
  "version": "1.0.0",
  "description": "Gatling performance tests",
  "type": "module",
  "scripts": {
    "test": "gatling run --simulation ${SIM_CLASS}",
    "test:all": "gatling run"
  },
  "devDependencies": {
    "@gatling.io/cli": "^3.15.0",
    "@gatling.io/core": "^3.15.0",
    "@gatling.io/http": "^3.15.0"
  }
}
EOF

  info "Writing sample feeder..."
  cat > "${RES_DIR}/users.csv" <<'EOF'
username,password
user01,pass01
user02,pass02
user03,pass03
EOF

  if [[ "$LANG" == "typescript" ]]; then
    info "Writing ${SIM_CLASS}.gatling.ts..."
    cat > "${SIM_DIR}/${SIM_CLASS}.gatling.ts" <<EOF
import { simulation, scenario, rampUsers, csv, global } from "@gatling.io/core";
import { http, status } from "@gatling.io/http";

export default simulation((setUp) => {
  // ── 1. Protocol ─────────────────────────────────────────────────────────
  const httpProtocol = http
    .baseUrl(process.env.BASE_URL ?? "${BASE_URL}")
    .acceptHeader("application/json")
    .contentTypeHeader("application/json");

  // ── 2. Feeders ──────────────────────────────────────────────────────────
  const userFeeder = csv("data/users.csv").circular();

  // ── 3. Scenario ─────────────────────────────────────────────────────────
  const scn = scenario("${SIM_CLASS}")
    .feed(userFeeder)
    .exec(
      http("GET Home").get("/")
        .check(status().is(200))
    )
    .pause(1, 3);
    // TODO: add your requests here

  // ── 4. Injection + 5. Assertions ────────────────────────────────────────
  const users = parseInt(process.env.USERS ?? "10");

  setUp(
    scn.injectOpen(rampUsers(users).during(60)).protocols(httpProtocol)
  ).assertions(
    global().successfulRequests().percent().gt(99.0),
    global().responseTime().percentile(95).lt(1000)
  );
});
EOF
  else
    info "Writing ${SIM_CLASS}.gatling.js..."
    cat > "${SIM_DIR}/${SIM_CLASS}.gatling.js" <<EOF
import { simulation, scenario, rampUsers, csv, global } from "@gatling.io/core";
import { http, status } from "@gatling.io/http";

export default simulation((setUp) => {
  const httpProtocol = http
    .baseUrl(process.env.BASE_URL ?? "${BASE_URL}")
    .acceptHeader("application/json");

  const userFeeder = csv("data/users.csv").circular();

  const scn = scenario("${SIM_CLASS}")
    .feed(userFeeder)
    .exec(http("GET Home").get("/").check(status().is(200)))
    .pause(1, 3);

  const users = parseInt(process.env.USERS ?? "10");

  setUp(
    scn.injectOpen(rampUsers(users).during(60)).protocols(httpProtocol)
  ).assertions(
    global().successfulRequests().percent().gt(99.0)
  );
});
EOF
  fi

  info "Writing tsconfig.json..."
  if [[ "$LANG" == "typescript" ]]; then
    cat > "${TARGET_DIR}/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["src/**/*"]
}
EOF
  fi
fi

# ── .gitignore ────────────────────────────────────────────────────────────────
info "Writing .gitignore..."
cat > "${TARGET_DIR}/.gitignore" <<'EOF'
# Build output
target/
build/
node_modules/

# Gatling reports (generated)
target/gatling/

# IDE
.idea/
*.iml
.vscode/
.classpath
.project
.settings/

# OS
.DS_Store
Thumbs.db
EOF

# ── README.md ────────────────────────────────────────────────────────────────
info "Writing README.md..."
cat > "${TARGET_DIR}/README.md" <<EOF
# ${PROJECT_NAME}

Gatling performance tests — language: **${LANG}**, build: **${BUILD_TOOL}**.

## Run

\`\`\`bash
$(if [[ "$BUILD_TOOL" == "maven" ]]; then
  echo "mvn gatling:test -Dgatling.simulationClass=${BASE_PACKAGE}.${SIM_CLASS} -DbaseUrl=${BASE_URL} -Dusers=10"
elif [[ "$BUILD_TOOL" == "gradle" ]]; then
  echo "gradle gatlingRun-${BASE_PACKAGE}.${SIM_CLASS} -DbaseUrl=${BASE_URL} -Dusers=10"
else
  echo "BASE_URL=${BASE_URL} USERS=10 npx gatling run --simulation ${SIM_CLASS}"
fi)
\`\`\`

## Reports

Open \`target/gatling/<simulation>-<timestamp>/index.html\` after a run.
EOF

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Project created at ${TARGET_DIR}/"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo "  1. cd ${PROJECT_NAME}"
if [[ "$BUILD_TOOL" == "maven" ]]; then
  echo "  2. mvn gatling:test -Dgatling.simulationClass=${BASE_PACKAGE}.${SIM_CLASS}"
elif [[ "$BUILD_TOOL" == "gradle" ]]; then
  echo "  2. gradle gatlingRun-${BASE_PACKAGE}.${SIM_CLASS}"
else
  echo "  2. npm install"
  echo "  3. npm test"
fi
echo ""
