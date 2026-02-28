#!/usr/bin/env bash
# validate.sh — Validates that a Gatling project is correctly configured.
# Usage: bash validate.sh [project-dir]
# Exits with code 0 if valid, 1 if issues found.

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

PASS=0; WARN_COUNT=0; FAIL_COUNT=0

pass()  { echo -e "  ${GREEN}✔${RESET}  $*"; PASS=$((PASS + 1)); }
warn()  { echo -e "  ${YELLOW}⚠${RESET}  $*"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail()  { echo -e "  ${RED}✘${RESET}  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
title() { echo -e "\n${BOLD}${CYAN}── $* ${RESET}"; }

PROJECT_DIR="${1:-.}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Gatling Project Validator          ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo -e "  Checking: ${PROJECT_DIR}"

# ── Detect project type ───────────────────────────────────────────────────────
HAS_POM=false; HAS_GRADLE=false; HAS_NPM=false
[[ -f "${PROJECT_DIR}/pom.xml" ]]          && HAS_POM=true
[[ -f "${PROJECT_DIR}/build.gradle" ]]     && HAS_GRADLE=true
[[ -f "${PROJECT_DIR}/build.gradle.kts" ]] && HAS_GRADLE=true
[[ -f "${PROJECT_DIR}/package.json" ]]     && HAS_NPM=true

# ── Maven checks ─────────────────────────────────────────────────────────────
if $HAS_POM; then
  title "Maven (pom.xml)"

  grep -q "gatling-charts-highcharts" "${PROJECT_DIR}/pom.xml" \
    && pass "gatling-charts-highcharts dependency found" \
    || fail "Missing dependency: io.gatling.highcharts:gatling-charts-highcharts"

  grep -q "gatling-maven-plugin" "${PROJECT_DIR}/pom.xml" \
    && pass "gatling-maven-plugin found" \
    || fail "Missing plugin: io.gatling:gatling-maven-plugin"

  grep -q "scope.*test" "${PROJECT_DIR}/pom.xml" \
    && pass "Gatling dependency scope is 'test'" \
    || warn "Gatling dependency scope may not be 'test' — check pom.xml"

  if grep -q "gatling.version" "${PROJECT_DIR}/pom.xml"; then
    VERSION=$(grep -oP '(?<=<gatling.version>)[^<]+' "${PROJECT_DIR}/pom.xml" | head -1)
    pass "Gatling version pinned: ${VERSION}"
  else
    warn "Gatling version not extracted to a property — consider using <gatling.version>"
  fi

  if grep -qP "maven.compiler.release|maven.compiler.source" "${PROJECT_DIR}/pom.xml"; then
    pass "Java compiler version configured"
  else
    warn "No maven.compiler.release found — add <maven.compiler.release>17</maven.compiler.release>"
  fi
fi

# ── Gradle checks ─────────────────────────────────────────────────────────────
if $HAS_GRADLE; then
  title "Gradle (build.gradle / build.gradle.kts)"
  GRADLE_FILE="${PROJECT_DIR}/build.gradle"
  [[ -f "${PROJECT_DIR}/build.gradle.kts" ]] && GRADLE_FILE="${PROJECT_DIR}/build.gradle.kts"

  grep -q "io.gatling.gradle" "${GRADLE_FILE}" \
    && pass "Gatling Gradle plugin found" \
    || fail "Missing plugin: id 'io.gatling.gradle'"

  grep -q "gatling-charts-highcharts" "${GRADLE_FILE}" \
    && pass "gatling-charts-highcharts dependency found" \
    || fail "Missing dependency: io.gatling.highcharts:gatling-charts-highcharts"
fi

# ── npm checks ────────────────────────────────────────────────────────────────
if $HAS_NPM; then
  title "npm (package.json)"

  grep -q "@gatling.io/core" "${PROJECT_DIR}/package.json" \
    && pass "@gatling.io/core found in package.json" \
    || fail "Missing dependency: @gatling.io/core"

  grep -q "@gatling.io/http" "${PROJECT_DIR}/package.json" \
    && pass "@gatling.io/http found in package.json" \
    || fail "Missing dependency: @gatling.io/http"

  grep -q "@gatling.io/cli" "${PROJECT_DIR}/package.json" \
    && pass "@gatling.io/cli found in package.json" \
    || warn "@gatling.io/cli not found — needed to run simulations locally"
fi

# ── No build file ─────────────────────────────────────────────────────────────
if ! $HAS_POM && ! $HAS_GRADLE && ! $HAS_NPM; then
  fail "No build file found (pom.xml, build.gradle, or package.json)"
fi

# ── Source structure checks ───────────────────────────────────────────────────
title "Source Structure"

JVM_SRC_FOUND=false
for lang in java kotlin scala; do
  DIR="${PROJECT_DIR}/src/test/${lang}"
  if [[ -d "$DIR" ]]; then
    COUNT=$(find "$DIR" -name "*.${lang}" -o -name "*.kt" -o -name "*.java" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$COUNT" -gt 0 ]]; then
      pass "Found ${COUNT} source file(s) in src/test/${lang}/"
      JVM_SRC_FOUND=true
    fi
  fi
done

JS_SRC_FOUND=false
if [[ -d "${PROJECT_DIR}/src" ]]; then
  COUNT=$(find "${PROJECT_DIR}/src" \( -name "*.gatling.ts" -o -name "*.gatling.js" \) -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$COUNT" -gt 0 ]]; then
    pass "Found ${COUNT} simulation(s) in src/ (*.gatling.js / *.gatling.ts)"
    JS_SRC_FOUND=true
  fi
fi

! $JVM_SRC_FOUND && ! $JS_SRC_FOUND && \
  warn "No simulation source files found. Create one in src/test/java (or scala/kotlin) or src/*.gatling.js (JS/TS)"

# ── Resource checks ───────────────────────────────────────────────────────────
title "Resources"

RES_DIRS=(
  "${PROJECT_DIR}/src/test/resources"
  "${PROJECT_DIR}/src/resources"
)
RES_FOUND=false
for dir in "${RES_DIRS[@]}"; do
  [[ -d "$dir" ]] && { RES_FOUND=true; pass "Resources directory: ${dir}/"; break; }
done
$RES_FOUND || warn "No resources directory found — create src/test/resources/ for gatling.conf and feeders"

DATA_FOUND=false
for dir in "${RES_DIRS[@]}"; do
  if [[ -d "${dir}/data" ]]; then
    COUNT=$(find "${dir}/data" \( -name "*.csv" -o -name "*.json" \) 2>/dev/null | wc -l | tr -d ' ')
    [[ "$COUNT" -gt 0 ]] && { pass "Found ${COUNT} feeder file(s) in ${dir}/data/"; DATA_FOUND=true; break; }
  fi
done
$DATA_FOUND || warn "No feeder files (CSV/JSON) found in resources/data/ — add test data files"

# ── Simulation content checks ─────────────────────────────────────────────────
title "Simulation Quality"

SIM_FILES=()
while IFS= read -r -d '' f; do SIM_FILES+=("$f"); done < <(
  find "${PROJECT_DIR}/src" \
    \( -name "*.java" -o -name "*.kt" -o -name "*.scala" -o -name "*.ts" -o -name "*.js" \) \
    -not -path "*/node_modules/*" \
    -print0 2>/dev/null
)

if [[ "${#SIM_FILES[@]}" -gt 0 ]]; then
  ALL_CONTENT=""
  for f in "${SIM_FILES[@]}"; do ALL_CONTENT+=$(cat "$f"); done

  echo "$ALL_CONTENT" | grep -q "assertions\|\.assertions(" \
    && pass "Assertions found in simulation(s)" \
    || warn "No assertions detected — add .assertions() to define pass/fail thresholds"

  echo "$ALL_CONTENT" | grep -q "pause\|\.pause(" \
    && pass "pause() calls found — good for realistic think time" \
    || warn "No pause() calls found — add pauses between requests to simulate real user behavior"

  echo "$ALL_CONTENT" | grep -q "saveAs\|\.saveAs(" \
    && pass "saveAs() found — dynamic value extraction in use" \
    || warn "No saveAs() calls found — consider extracting dynamic values (tokens, IDs) from responses"

  echo "$ALL_CONTENT" | grep -qiE "csv|jsonFile|arrayFeeder|listFeeder" \
    && pass "Feeders found — parameterized test data in use" \
    || warn "No feeders found — consider using csv() or jsonFile() for varied test data"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Summary ──────────────────────────────────────${RESET}"
echo -e "  ${GREEN}✔ Passed:${RESET}   ${PASS}"
echo -e "  ${YELLOW}⚠ Warnings:${RESET} ${WARN_COUNT}"
echo -e "  ${RED}✘ Errors:${RESET}   ${FAIL_COUNT}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "  ${RED}${BOLD}Validation FAILED — fix errors above before running tests.${RESET}"
  echo ""
  exit 1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
  echo -e "  ${YELLOW}${BOLD}Validation passed with warnings — consider addressing them.${RESET}"
  echo ""
  exit 0
else
  echo -e "  ${GREEN}${BOLD}Validation PASSED — project looks good!${RESET}"
  echo ""
  exit 0
fi
