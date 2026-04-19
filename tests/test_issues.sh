#!/bin/bash

# ======================================================================
#  BrightBund Issue Test Runner
#  Purpose:
#    Runs the existing shell test suites for the project in sequence and
#    reports a single pass/fail summary.
#  Notes:
#    - Uses the same colorized, banner-style output as the feature test
#      scripts in this folder.
#    - By default, discovers every `test_*.sh` file in `tests/` except
#      itself and runs them in sorted order.
#    - You can pass specific script names or paths as arguments to limit
#      execution, e.g. `bash tests/test_issues.sh test_map.sh test_feed.sh`.
# ======================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0
RUN=0
DETECTED_BASE_URL=""

normalize_script_path() {
    local script_ref="$1"

    if [[ "$script_ref" = /* || "$script_ref" =~ ^[A-Za-z]:[\\/] ]]; then
        echo "$script_ref"
        return 0
    fi

    echo "${SCRIPT_DIR}/${script_ref}"
}

discover_scripts() {
    find "$SCRIPT_DIR" -maxdepth 1 -type f -name 'test_*.sh' ! -name "$(basename "$0")" | sort
}

detect_base_url() {
    local candidate
    for candidate in "http://localhost:8081" "http://127.0.0.1:8081" "http://localhost" "http://127.0.0.1"; do
        if curl -fsS "$candidate/health" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

prepare_script_copy() {
    local script_path="$1"

    if [[ -z "$DETECTED_BASE_URL" || "$DETECTED_BASE_URL" == "http://localhost:8081" || "$DETECTED_BASE_URL" == "http://127.0.0.1:8081" ]]; then
        echo "$script_path"
        return 0
    fi

    local script_copy
    script_copy="$(mktemp "${SCRIPT_DIR}/.test_issues.XXXXXX.sh")"
    sed \
        -e "s|http://localhost:8081|${DETECTED_BASE_URL}|g" \
        -e "s|http://127.0.0.1:8081|${DETECTED_BASE_URL}|g" \
        "$script_path" > "$script_copy"
    chmod +x "$script_copy" 2>/dev/null || true
    echo "$script_copy"
}

run_script() {
    local script_path="$1"
    local script_name
    script_name="$(basename "$script_path")"
    local runnable_script_path

    runnable_script_path="$(prepare_script_copy "$script_path")"

    echo -e "${GREEN}=== RUNNING: ${script_name} ===${NC}"
    echo -e "${CYAN}  Script: ${script_path}${NC}"
    if [[ "$runnable_script_path" != "$script_path" ]]; then
        echo -e "${CYAN}  Rewritten for base URL: ${DETECTED_BASE_URL}${NC}"
    fi

    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}✗ FAIL: ${script_name} — script not found${NC}"
        FAIL=$((FAIL + 1))
        RUN=$((RUN + 1))
        echo ""
        return 1
    fi

    RUN=$((RUN + 1))
    if bash "$runnable_script_path"; then
        echo -e "${GREEN}✓ PASS: ${script_name}${NC}"
        PASS=$((PASS + 1))
        echo ""

        if [[ "$runnable_script_path" != "$script_path" ]]; then
            rm -f "$runnable_script_path" 2>/dev/null || true
        fi
        return 0
    fi

    echo -e "${RED}✗ FAIL: ${script_name}${NC}"
    FAIL=$((FAIL + 1))
    echo ""

    if [[ "$runnable_script_path" != "$script_path" ]]; then
        rm -f "$runnable_script_path" 2>/dev/null || true
    fi
    return 1
}

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}           BrightBund Issue Test Runner (Bash)             ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}Working directory: ${ROOT_DIR}${NC}"
echo ""

if DETECTED_BASE_URL="$(detect_base_url)"; then
    echo -e "${CYAN}Detected reachable base URL: ${DETECTED_BASE_URL}${NC}"
else
    echo -e "${YELLOW}! Could not auto-detect a reachable base URL; scripts will run as-written.${NC}"
fi
echo ""

if [[ $# -gt 0 ]]; then
    TEST_SCRIPTS=()
    for ref in "$@"; do
        TEST_SCRIPTS+=("$(normalize_script_path "$ref")")
    done
else
    mapfile -t TEST_SCRIPTS < <(discover_scripts)
fi

if [[ ${#TEST_SCRIPTS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}! No test scripts found to run.${NC}"
    exit 1
fi

for script_path in "${TEST_SCRIPTS[@]}"; do
    run_script "$script_path"
done

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Issue test run finished.${NC}"
echo -e "${GREEN}  PASS : ${PASS}${NC}"
echo -e "${RED}  FAIL : ${FAIL}${NC}"
echo -e "${CYAN}  RUN  : ${RUN}${NC}"
echo -e "${CYAN}============================================================${NC}"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi

exit 0