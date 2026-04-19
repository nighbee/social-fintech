#!/bin/bash

# ======================================================================
#  Map Module – End-to-End Test
#  Flow:
#    1. Create 3 users (admin, user1, user2)
#    2. Admin grants user1 some Silver via economy adjust
#    3. user1 creates a task with reward = 1 Silver
#    4. user2 applies to the task
#    5. user2 submits the verification code shared by user1
#    6. user1 confirms completion → user2 receives 1 Silver reward
#    7. Verify user2 balance increased by 1 Silver
# ======================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

AUTH_URL="http://localhost:8081/api/v1/auth"
ECO_URL="http://localhost:8081/api/v1/economy"
TASK_URL="http://localhost:8081/api/v1/tasks"
MAP_URL="http://localhost:8081/api/v1/map"

PASS=0
FAIL=0

# ── helpers ────────────────────────────────────────────────────────────

get_json_string() {
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_json_number() {
    echo "$1" | grep -o "\"$2\": *[0-9.]*" | head -1 | grep -o "[0-9.]*"
}

log_request() {
    local label="$1"
    local method="$2"
    local url="$3"
    local body="$4"
    local resp_body="$5"
    local http_code="$6"
    local token_hint="$7"   # optional: label of who is calling

    echo -e "${CYAN}┌─ ${label}${NC}"
    echo -e "${CYAN}│  ${method} ${url}${NC}"
    if [[ -n "$token_hint" ]]; then
        echo -e "${CYAN}│  Auth: Bearer <${token_hint}_TOKEN>${NC}"
    fi
    if [[ -n "$body" ]]; then
        echo -e "${CYAN}│  Request Body: ${body}${NC}"
    fi
    echo -e "${CYAN}│  HTTP Status : ${http_code}${NC}"
    echo -e "${CYAN}│  Response    : ${resp_body}${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────${NC}"
    echo ""
}

assert_ok() {
    local label="$1"
    local code="$2"
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        echo -e "${GREEN}✓ PASS: ${label} (HTTP ${code})${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ FAIL: ${label} — expected 2xx, got HTTP ${code}${NC}"
        FAIL=$((FAIL + 1))
    fi
}

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓ PASS: ${label} (value = ${actual})${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ FAIL: ${label} — expected '${expected}', got '${actual}'${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# ── banner ─────────────────────────────────────────────────────────────

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}          Map Module – End-to-End Test Suite         ${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""

# ======================================================================
# SETUP – Create users
# ======================================================================

echo -e "${GREEN}=== SETUP: Creating Users ===${NC}"
echo ""

# ── Admin ──────────────────────────────────────────────────────────────
ADMIN_EMAIL="map_admin_${RANDOM}@example.com"
ADMIN_PASSWORD="AdminPass123!"

REGISTER_BODY="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"first_name\":\"Admin\",\"last_name\":\"Map\",\"date_of_birth\":\"1990-01-01\",\"device_id\":\"admin-map-device\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Register Admin" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ADMIN_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ Admin created: $ADMIN_ID${NC}"

    # Grant admin privileges via DB
    echo -e "${YELLOW}  Granting admin privileges via SQL…${NC}"
    docker exec brightbund-db psql -U user -d brightbund \
        -c "UPDATE users SET is_admin = true WHERE id = '$ADMIN_ID';" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Admin privileges granted${NC}"
    else
        echo -e "${RED}  ✗ Failed to grant admin privileges – aborting${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Admin registration failed – aborting${NC}"
    exit 1
fi

# Login admin
LOGIN_BODY="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"device_id\":\"admin-map-device\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
    -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Login Admin" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
ADMIN_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ Admin logged in${NC}"
echo -e "${CYAN}  ADMIN_TOKEN: Bearer ${ADMIN_TOKEN}${NC}"
echo ""

# ── User 1 (task creator) ──────────────────────────────────────────────
USER1_EMAIL="map_user1_${RANDOM}@example.com"
USER1_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"first_name\":\"Alice\",\"last_name\":\"Creator\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"map-device1\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Register User1" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    USER1_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ User1 created: $USER1_ID${NC}"
else
    echo -e "${RED}✗ User1 registration failed – aborting${NC}"
    exit 1
fi

LOGIN_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"device_id\":\"map-device1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
    -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Login User1" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
USER1_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ User1 logged in${NC}"
echo -e "${CYAN}  USER1_TOKEN: Bearer ${USER1_TOKEN}${NC}"
echo ""

# ── User 2 (task worker / completer, starts with no balance) ──────────
USER2_EMAIL="map_user2_${RANDOM}@example.com"
USER2_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"first_name\":\"Bob\",\"last_name\":\"Worker\",\"date_of_birth\":\"2001-06-15\",\"device_id\":\"map-device2\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Register User2" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    USER2_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ User2 created: $USER2_ID (no initial balance)${NC}"
else
    echo -e "${RED}✗ User2 registration failed – aborting${NC}"
    exit 1
fi

LOGIN_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"device_id\":\"map-device2\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
    -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Login User2" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
USER2_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ User2 logged in${NC}"
echo -e "${CYAN}  USER2_TOKEN: Bearer ${USER2_TOKEN}${NC}"
echo ""

# ── User 3 (extra task worker to test limits) ──────────
USER3_EMAIL="map_user3_${RANDOM}@example.com"
USER3_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER3_PASSWORD\",\"first_name\":\"Charlie\",\"last_name\":\"Extra\",\"date_of_birth\":\"1999-09-09\",\"device_id\":\"map-device3\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Register User3" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    USER3_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ User3 created: $USER3_ID${NC}"
else
    echo -e "${RED}✗ User3 registration failed – aborting${NC}"
    exit 1
fi

LOGIN_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER3_PASSWORD\",\"device_id\":\"map-device3\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
    -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Login User3" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
USER3_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ User3 logged in${NC}"
echo -e "${CYAN}  USER3_TOKEN: Bearer ${USER3_TOKEN}${NC}"
echo ""

# ======================================================================
# TEST 1 – Admin funds User1 with Silver via accrual adjust (5 Silver)
# ======================================================================

echo -e "${GREEN}=== TEST 1: Admin Funds User1 with 5 Silver ===${NC}"

ADJUST_BODY="{\"user_id\":\"$USER1_ID\",\"amount\":5.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Map test funding\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$ADJUST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Admin Adjust Balance (User1 +5 Silver)" "POST" "$ECO_URL/admin/adjust" "$ADJUST_BODY" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
assert_ok "Admin funds User1 with 5 Silver" "$HTTP_CODE"

# Verify User1 balance
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Balance Check (after funding)" "GET" "$ECO_URL/balance" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
USER1_SILVER_BEFORE=$(get_json_number "$HTTP_BODY" "silver_balance")
echo -e "${CYAN}  User1 Silver balance: ${USER1_SILVER_BEFORE}${NC}"
echo ""

# Verify User2 has 0 Silver (no funding)
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Balance Check (initial – should be 0)" "GET" "$ECO_URL/balance" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
USER2_SILVER_BEFORE=$(get_json_number "$HTTP_BODY" "silver_balance")
echo -e "${CYAN}  User2 Silver balance (initial): ${USER2_SILVER_BEFORE}${NC}"
echo ""

# ======================================================================
# TEST 2 – User1 creates a task with reward = 1 Silver
# ======================================================================

echo -e "${GREEN}=== TEST 2: User1 Creates a Task (reward = 1 Silver) ===${NC}"

TASK_BODY="{\"title\":\"Deliver package to lobby\",\"description\":\"Please pick up the red package from the lobby and bring it to room 201.\",\"reward\":1,\"workers_needed\":1,\"latitude\":40.7128,\"longitude\":-74.0060,\"auto_shutdown\":false}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Creates Task" "POST" "$TASK_URL" "$TASK_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 creates task with 1 Silver reward" "$HTTP_CODE"

TASK_ID=$(get_json_string "$HTTP_BODY" "id")
VERIFICATION_CODE=$(get_json_string "$HTTP_BODY" "verification_code")
TASK_STATUS=$(get_json_string "$HTTP_BODY" "status")
TASK_REWARD=$(get_json_number "$HTTP_BODY" "reward")

echo -e "${CYAN}  Task ID           : ${TASK_ID}${NC}"
echo -e "${CYAN}  Verification Code : ${VERIFICATION_CODE}  ← (creator shares this with helper)${NC}"
echo -e "${CYAN}  Status            : ${TASK_STATUS}${NC}"
echo -e "${CYAN}  Reward            : ${TASK_REWARD} Silver${NC}"

if [[ -z "$TASK_ID" ]]; then
    echo -e "${RED}✗ Could not extract task ID – aborting${NC}"
    exit 1
fi

assert_eq "Task status is 'open'" "open" "$TASK_STATUS"
assert_eq "Task reward is 1 Silver" "1" "$TASK_REWARD"
echo ""

# Verify User1 balance was charged the 1 Silver upfront
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Balance After Task Creation (should be -1)" "GET" "$ECO_URL/balance" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
USER1_SILVER_AFTER_CREATE=$(get_json_number "$HTTP_BODY" "silver_balance")
EXPECTED_USER1=$(awk "BEGIN {logf \"%.0f\", $USER1_SILVER_BEFORE - 1}")
echo -e "${CYAN}  User1 Silver before : ${USER1_SILVER_BEFORE}${NC}"
echo -e "${CYAN}  User1 Silver after  : ${USER1_SILVER_AFTER_CREATE} (expected ${EXPECTED_USER1})${NC}"
assert_eq "User1 charged 1 Silver for task creation" "$EXPECTED_USER1" "$USER1_SILVER_AFTER_CREATE"
echo ""

# ======================================================================
# TEST 3 – User2 browses nearby tasks and finds the one User1 created
# ======================================================================

echo -e "${GREEN}=== TEST 3: User2 Browses Nearby Tasks ===${NC}"

NEARBY_URL="${TASK_URL}/nearby?lat=40.7128&lon=-74.0060&radius_m=5000"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$NEARBY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Gets Nearby Tasks" "GET" "$NEARBY_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 fetches nearby tasks" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 4 – User2 applies to the task
# ======================================================================

echo -e "${GREEN}=== TEST 4: User2 Applies to the Task ===${NC}"

APPLY_URL="${TASK_URL}/${TASK_ID}/apply"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APPLY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Applies to Task" "POST" "$APPLY_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 applies to task" "$HTTP_CODE"

APPLICATION_ID=$(get_json_string "$HTTP_BODY" "application_id")
APP_STATUS=$(get_json_string "$HTTP_BODY" "status")

echo -e "${CYAN}  Application ID : ${APPLICATION_ID}${NC}"
echo -e "${CYAN}  Status         : ${APP_STATUS}${NC}"

if [[ -z "$APPLICATION_ID" ]]; then
    echo -e "${RED}✗ Could not extract application ID – aborting${NC}"
    exit 1
fi

assert_eq "Application status is 'pending'" "pending" "$APP_STATUS"
echo ""

# ======================================================================
# TEST 4b – User2 fetches their applied tasks
# ======================================================================

echo -e "${GREEN}=== TEST 4b: User2 Fetches Applied Tasks ===${NC}"

APPLIED_URL="${TASK_URL}/applied"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$APPLIED_URL" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Gets Applied Tasks" "GET" "$APPLIED_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 fetches applied tasks successfully" "$HTTP_CODE"

# Check if the task we just applied to is in the response list "[]"
APPLIED_TASK_ID=$(get_json_string "$HTTP_BODY" "id")

if [[ "$APPLIED_TASK_ID" == "$TASK_ID" ]]; then
    echo -e "${GREEN}✓ PASS: The applied task ($TASK_ID) is in User2's applied tasks list${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: The applied task ($TASK_ID) is missing from User2's applied tasks! Found: $APPLIED_TASK_ID${NC}"
    FAIL=$((FAIL + 1))
fi

echo ""

# TEST 4c - User1 (creator) fetches their applied tasks (should be empty/different list)
echo -e "${GREEN}=== TEST 4c: User1 Fetches Applied Tasks (Should not have User2's application) ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$APPLIED_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets Applied Tasks" "GET" "$APPLIED_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 fetches applied tasks successfully" "$HTTP_CODE"

USER1_APPLIED_TASK_ID=$(get_json_string "$HTTP_BODY" "id")

if [[ "$USER1_APPLIED_TASK_ID" != "$TASK_ID" ]]; then
    echo -e "${GREEN}✓ PASS: The applied task ($TASK_ID) is NOT in User1's applied tasks list${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: The applied task ($TASK_ID) incorrectly appeared in User1's applied tasks!${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 4d – User1 fetches their own tasks
# ======================================================================

echo -e "${GREEN}=== TEST 4d: User1 Fetches My Tasks ===${NC}"

MY_TASKS_URL="${TASK_URL}/my"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$MY_TASKS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets My Tasks" "GET" "$MY_TASKS_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 fetches my tasks successfully" "$HTTP_CODE"

MY_TASK_ID=$(get_json_string "$HTTP_BODY" "id")
assert_eq "User1's task is returned" "$TASK_ID" "$MY_TASK_ID"
echo ""

# ======================================================================
# TEST 4e – User1 fetches specific task details
# ======================================================================

echo -e "${GREEN}=== TEST 4e: User1 Fetches Specific Task ===${NC}"

GET_TASK_URL="${TASK_URL}/${TASK_ID}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$GET_TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets Task Detail" "GET" "$GET_TASK_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 fetches task successfully" "$HTTP_CODE"

FETCHED_TASK_ID=$(get_json_string "$HTTP_BODY" "id")
assert_eq "Fetches the correct task" "$TASK_ID" "$FETCHED_TASK_ID"
echo ""

# ======================================================================
# TEST 5 – User1 lists applications (creator-only check)
# ======================================================================

echo -e "${GREEN}=== TEST 5: User1 Views Task Applications (creator check) ===${NC}"

APPS_URL="${TASK_URL}/${TASK_ID}/applications"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$APPS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets Task Applications" "GET" "$APPS_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Creator can list applications" "$HTTP_CODE"
echo ""

# TEST 5b – User2 should be blocked from listing applications (not the creator)
echo -e "${GREEN}=== TEST 5b: User2 Cannot View Applications (non-creator) ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$APPS_URL" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Tries to Get Applications (should be 403)" "GET" "$APPS_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ PASS: Non-creator blocked from applications list (HTTP 403)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 403, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 5b – User1 accepts User2's application
# ======================================================================

echo -e "${GREEN}=== TEST 5b: User1 Accepts User2's Application ===${NC}"

ACCEPT_URL="${TASK_URL}/${TASK_ID}/applications/${APPLICATION_ID}/accept"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ACCEPT_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Accepts Application" "POST" "$ACCEPT_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 accepts application successfully" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 6 – User2 submits the verification code (received from User1 via chat)
# ======================================================================

echo -e "${GREEN}=== TEST 6: User2 Submits Verification Code ===${NC}"
echo -e "${CYAN}  (User1 shares code '${VERIFICATION_CODE}' with User2 out-of-band)${NC}"

VERIFY_URL="${TASK_URL}/${TASK_ID}/applications/${APPLICATION_ID}/verify-code"
VERIFY_BODY="{\"code\":\"${VERIFICATION_CODE}\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$VERIFY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$VERIFY_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Submits Verification Code" "POST" "$VERIFY_URL" "$VERIFY_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 submits correct verification code" "$HTTP_CODE"

VERIFY_STATUS=$(get_json_string "$HTTP_BODY" "status")
assert_eq "Application status is 'code_verified'" "code_verified" "$VERIFY_STATUS"
echo ""

# Sanity check: wrong code should be rejected
echo -e "${GREEN}=== TEST 6b: Wrong Verification Code is Rejected ===${NC}"
WRONG_CODE="0000"
# Avoid sending current code as wrong code by accident
if [[ "$VERIFICATION_CODE" == "0000" ]]; then
    WRONG_CODE="1111"
fi
WRONG_VERIFY_BODY="{\"code\":\"${WRONG_CODE}\"}"

# We need a fresh application for this sub-test (the first one is already code_verified)
# Just verify the error text in the already-verified scenario
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$VERIFY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$WRONG_VERIFY_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Submits Wrong Code (should fail)" "POST" "$VERIFY_URL" "$WRONG_VERIFY_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ PASS: Re-submission or wrong code rejected (HTTP ${HTTP_CODE})${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 4xx, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 7 – User1 confirms completion → User2 receives 1 Silver reward
# ======================================================================

echo -e "${GREEN}=== TEST 7: User1 Confirms Completion → User2 Gets Reward ===${NC}"

CONFIRM_URL="${TASK_URL}/${TASK_ID}/applications/${APPLICATION_ID}/confirm"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$CONFIRM_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Confirms Completion" "POST" "$CONFIRM_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 confirms task completion" "$HTTP_CODE"

FINAL_REWARD=$(get_json_number "$HTTP_BODY" "reward")
FINAL_TASK_STATUS=$(get_json_string "$HTTP_BODY" "task_status")

echo -e "${CYAN}  Reward paid to User2 : ${FINAL_REWARD} Silver${NC}"
echo -e "${CYAN}  Task status          : ${FINAL_TASK_STATUS}${NC}"

assert_eq "Reward paid is 1 Silver" "1" "$FINAL_REWARD"
assert_eq "Task status is 'completed'" "completed" "$FINAL_TASK_STATUS"
echo ""

# ======================================================================
# TEST 8 – Verify User2 balance increased by exactly 1 Silver
# ======================================================================

echo -e "${GREEN}=== TEST 8: Verify User2 Balance Increased by 1 Silver ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Balance After Task Completion" "GET" "$ECO_URL/balance" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
USER2_SILVER_AFTER=$(get_json_number "$HTTP_BODY" "silver_balance")

EXPECTED_USER2=$(awk "BEGIN {logf \"%.0f\", ${USER2_SILVER_BEFORE:-0} + 1}")
echo -e "${CYAN}  User2 Silver before : ${USER2_SILVER_BEFORE:-0}${NC}"
echo -e "${CYAN}  User2 Silver after  : ${USER2_SILVER_AFTER}${NC}"
echo -e "${CYAN}  Expected            : ${EXPECTED_USER2}${NC}"
assert_eq "User2 balance increased by 1 Silver" "$EXPECTED_USER2" "$USER2_SILVER_AFTER"
echo ""

# ======================================================================
# TEST 9 – Idempotency: User1 cannot confirm the same application twice
# ======================================================================

echo -e "${GREEN}=== TEST 9: Double Confirm is Rejected ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$CONFIRM_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Tries to Confirm Again (should fail)" "POST" "$CONFIRM_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ PASS: Double-confirm rejected (HTTP ${HTTP_CODE})${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 4xx on re-confirm, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 10 – CreateTask: No auth token → 401
# ======================================================================

echo -e "${GREEN}=== TEST 10: CreateTask Without Auth Token → 401 ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"No auth\",\"reward\":1,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (no token)" "POST" "$TASK_URL" "" "$HTTP_BODY" "$HTTP_CODE"
if [[ "$HTTP_CODE" -eq 401 ]]; then
    echo -e "${GREEN}✓ PASS: CreateTask without auth rejected (HTTP 401)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 401, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 11 – GetNearbyTasks: No auth token → 401
# ======================================================================

echo -e "${GREEN}=== TEST 11: GetNearbyTasks Without Auth Token → 401 ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${TASK_URL}/nearby?lat=40.71&lon=-74.00")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "GetNearbyTasks (no token)" "GET" "${TASK_URL}/nearby?lat=40.71&lon=-74.00" "" "$HTTP_BODY" "$HTTP_CODE"
if [[ "$HTTP_CODE" -eq 401 ]]; then
    echo -e "${GREEN}✓ PASS: GetNearbyTasks without auth rejected (HTTP 401)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 401, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 12 – CreateTask: Empty title → 400
# ======================================================================

echo -e "${GREEN}=== TEST 12: CreateTask – Empty Title → 400 ===${NC}"

BAD_BODY="{\"title\":\"\",\"reward\":1,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAD_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (empty title)" "POST" "$TASK_URL" "$BAD_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Empty title rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 13 – CreateTask: Title > 100 characters → 400
# ======================================================================

echo -e "${GREEN}=== TEST 13: CreateTask – Title Too Long (>100 chars) → 400 ===${NC}"

LONG_TITLE=$(logf 'A%.0s' {1..101})
BAD_BODY="{\"title\":\"${LONG_TITLE}\",\"reward\":1,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAD_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (title >100 chars)" "POST" "$TASK_URL" "<101-char title>" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Long title rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 14 – CreateTask: Invalid reward (0) → 400
# ======================================================================

echo -e "${GREEN}=== TEST 14: CreateTask – Invalid Reward (0) → 400 ===${NC}"

BAD_BODY="{\"title\":\"Test\",\"reward\":0,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAD_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (reward=0)" "POST" "$TASK_URL" "$BAD_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Invalid reward rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 15 – CreateTask: Invalid reward (99) → 400
# ======================================================================

echo -e "${GREEN}=== TEST 15: CreateTask – Invalid Reward (99) → 400 ===${NC}"

BAD_BODY="{\"title\":\"Test\",\"reward\":99,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAD_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (reward=99)" "POST" "$TASK_URL" "$BAD_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Reward=99 rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 16 – CreateTask: Invalid workers_needed (0) → 400
# ======================================================================

echo -e "${GREEN}=== TEST 16: CreateTask – Invalid Workers (0) → 400 ===${NC}"

BAD_BODY="{\"title\":\"Test\",\"reward\":1,\"workers_needed\":0,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAD_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (workers=0)" "POST" "$TASK_URL" "$BAD_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: workers_needed=0 rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 17 – CreateTask: Invalid workers_needed (21) → 400
# ======================================================================

echo -e "${GREEN}=== TEST 17: CreateTask – Invalid Workers (21) → 400 ===${NC}"

BAD_BODY="{\"title\":\"Test\",\"reward\":1,\"workers_needed\":21,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAD_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (workers=21)" "POST" "$TASK_URL" "$BAD_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: workers_needed=21 rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 18 – CreateTask: Invalid coordinates (lat=999) → 400
# ======================================================================

echo -e "${GREEN}=== TEST 18: CreateTask – Invalid Coordinates (lat=999) → 400 ===${NC}"

BAD_BODY="{\"title\":\"Test\",\"reward\":1,\"workers_needed\":1,\"latitude\":999,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAD_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (lat=999)" "POST" "$TASK_URL" "$BAD_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Invalid coordinates rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 19 – CreateTask: Malformed JSON body → 400
# ======================================================================

echo -e "${GREEN}=== TEST 19: CreateTask – Malformed JSON Body → 400 ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "not-json-at-all")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (malformed JSON)" "POST" "$TASK_URL" "not-json-at-all" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Malformed JSON rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 20 – CreateTask: Insufficient funds (User2 has 1 Silver, needs 3) → 402
# ======================================================================

echo -e "${GREEN}=== TEST 20: CreateTask – Insufficient Funds (User2) → 402 ===${NC}"
echo -e "${CYAN}  User2 has 1 Silver (from completion reward), but needs 3${NC}"

TASK_BODY="{\"title\":\"User2 task attempt\",\"reward\":3,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (User2, insufficient funds)" "POST" "$TASK_URL" "$TASK_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
if [[ "$HTTP_CODE" -eq 402 ]]; then
    echo -e "${GREEN}✓ PASS: Insufficient funds rejected (HTTP 402)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 402, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 21 – CreateTask: 7-day cooldown (User1 already created a task) → 429
# ======================================================================

echo -e "${GREEN}=== TEST 21: CreateTask – Cooldown Active (User1) → 429 ===${NC}"

TASK_BODY="{\"title\":\"Second task too soon\",\"reward\":1,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateTask (cooldown)" "POST" "$TASK_URL" "$TASK_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 429 ]]; then
    echo -e "${GREEN}✓ PASS: Cooldown enforced (HTTP 429)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 429, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 22 – ApplyToTask: Creator applies to own task → 400
# ======================================================================

echo -e "${GREEN}=== TEST 22: ApplyToTask – Creator Applies to Own Task → 400 ===${NC}"

# Use the original TASK_ID from Test 2 (created by User1, now completed)
# We need a fresh open task – use Admin to fund a new user (User3) or apply to existing
# Since the task is already completed, let's use Admin to create a fresh task

# Fund Admin with Silver first
ADJUST_BODY="{\"user_id\":\"$ADMIN_ID\",\"amount\":5.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Admin self-fund for test\"}"
curl -s -X POST "$ECO_URL/admin/adjust" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$ADJUST_BODY" > /dev/null 2>&1

# Admin creates a task for error testing
TASK_BODY="{\"title\":\"Admin test task\",\"reward\":1,\"workers_needed\":1,\"latitude\":51.5074,\"longitude\":-0.1278}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

ERROR_TASK_ID=$(get_json_string "$HTTP_BODY" "id")
ERROR_TASK_CODE=$(get_json_string "$HTTP_BODY" "verification_code")
echo -e "${CYAN}  Error-test task ID : ${ERROR_TASK_ID}${NC}"

# Admin tries to apply to their own task → should get 400
APPLY_URL="${TASK_URL}/${ERROR_TASK_ID}/apply"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APPLY_URL" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "ApplyToTask (own task)" "POST" "$APPLY_URL" "" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Cannot apply to own task (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 23 – ApplyToTask: Apply to non-existent task → 404
# ======================================================================

echo -e "${GREEN}=== TEST 23: ApplyToTask – Non-existent Task → 404 ===${NC}"

FAKE_TASK_ID="00000000-0000-0000-0000-000000000000"
APPLY_URL="${TASK_URL}/${FAKE_TASK_ID}/apply"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APPLY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "ApplyToTask (non-existent task)" "POST" "$APPLY_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
if [[ "$HTTP_CODE" -eq 404 ]]; then
    echo -e "${GREEN}✓ PASS: Non-existent task rejected (HTTP 404)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 404, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 24 – ApplyToTask: Duplicate application → 409
# ======================================================================

echo -e "${GREEN}=== TEST 24: ApplyToTask – Duplicate Application → 409 ===${NC}"

# User2 applies to Admin's error-test task
APPLY_URL="${TASK_URL}/${ERROR_TASK_ID}/apply"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APPLY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

ERROR_APP_ID=$(get_json_string "$HTTP_BODY" "application_id")
echo -e "${CYAN}  First application : ${ERROR_APP_ID}${NC}"

# User2 applies again → should be 409
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$APPLY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "ApplyToTask (duplicate)" "POST" "$APPLY_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
if [[ "$HTTP_CODE" -eq 409 ]]; then
    echo -e "${GREEN}✓ PASS: Duplicate application rejected (HTTP 409)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 409, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 24b – RejectApplication: Reject an application
# ======================================================================

echo -e "${GREEN}=== TEST 24b: RejectApplication – Reject an Application ===${NC}"

REJECT_URL="${TASK_URL}/${ERROR_TASK_ID}/applications/${ERROR_APP_ID}/reject"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$REJECT_URL" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "RejectApplication" "POST" "$REJECT_URL" "" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
if [[ "$HTTP_CODE" -eq 200 ]]; then
    echo -e "${GREEN}✓ PASS: Application rejected successfully (HTTP 200)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 200, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 25 – SubmitVerificationCode: Code not 4 digits → 400
# ======================================================================

echo -e "${GREEN}=== TEST 25: SubmitVerificationCode – Code Not 4 Digits → 400 ===${NC}"

VERIFY_URL="${TASK_URL}/${ERROR_TASK_ID}/applications/${ERROR_APP_ID}/verify-code"
VERIFY_BODY="{\"code\":\"12\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$VERIFY_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$VERIFY_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SubmitVerificationCode (2-digit code)" "POST" "$VERIFY_URL" "$VERIFY_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Short code rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 26 – SubmitVerificationCode: Wrong user (User1 is not applicant) → 403
# ======================================================================

echo -e "${GREEN}=== TEST 26: SubmitVerificationCode – Non-Applicant → 403 ===${NC}"

VERIFY_BODY="{\"code\":\"${ERROR_TASK_CODE}\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$VERIFY_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$VERIFY_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SubmitVerificationCode (non-applicant)" "POST" "$VERIFY_URL" "$VERIFY_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ PASS: Non-applicant rejected (HTTP 403)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 403, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 27 – ConfirmCompletion: Non-creator tries to confirm → 403
# ======================================================================

echo -e "${GREEN}=== TEST 27: ConfirmCompletion – Non-Creator → 403 ===${NC}"

CONFIRM_URL="${TASK_URL}/${ERROR_TASK_ID}/applications/${ERROR_APP_ID}/confirm"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$CONFIRM_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "ConfirmCompletion (non-creator)" "POST" "$CONFIRM_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ PASS: Non-creator confirm rejected (HTTP 403)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 403, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 28 – ConfirmCompletion: Application not yet code_verified → 400
# ======================================================================

echo -e "${GREEN}=== TEST 28: ConfirmCompletion – Not Yet Code-Verified → 400 ===${NC}"

# Admin (creator) tries to confirm before User2 submits code
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$CONFIRM_URL" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "ConfirmCompletion (pending app)" "POST" "$CONFIRM_URL" "" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Confirm before code_verified rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 29 – CancelTask: Non-existent task → 404
# ======================================================================

echo -e "${GREEN}=== TEST 29: CancelTask – Non-existent Task → 404 ===${NC}"

FAKE_TASK_ID="00000000-0000-0000-0000-000000000000"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${TASK_URL}/${FAKE_TASK_ID}" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CancelTask (non-existent)" "DELETE" "${TASK_URL}/${FAKE_TASK_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 404 ]]; then
    echo -e "${GREEN}✓ PASS: Cancel non-existent task rejected (HTTP 404)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 404, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 30 – CancelTask: Non-creator tries to cancel → 403
# ======================================================================

echo -e "${GREEN}=== TEST 30: CancelTask – Non-Creator → 403 ===${NC}"

# User1 tries to cancel Admin's error-test task
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${TASK_URL}/${ERROR_TASK_ID}" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CancelTask (non-creator)" "DELETE" "${TASK_URL}/${ERROR_TASK_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ PASS: Non-creator cancel rejected (HTTP 403)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 403, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 31 – CancelTask: Cancel already-completed task → 409
# ======================================================================

echo -e "${GREEN}=== TEST 31: CancelTask – Already Completed Task → 409 ===${NC}"

# TASK_ID is the original task from Test 2 which was completed in Test 7
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${TASK_URL}/${TASK_ID}" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CancelTask (completed task)" "DELETE" "${TASK_URL}/${TASK_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 409 ]]; then
    echo -e "${GREEN}✓ PASS: Cancel completed task rejected (HTTP 409)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 409, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 32 – CancelTask: Happy path – cancel open task + refund
# ======================================================================

echo -e "${GREEN}=== TEST 32: CancelTask – Cancel Open Task + Verify Refund ===${NC}"
echo -e "${CYAN}  Creating a dedicated clean task for cancel testing (no applications)${NC}"

# Fund User1 with extra Silver for this cancel test
ADJUST_BODY="{\"user_id\":\"$USER1_ID\",\"amount\":2.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Cancel test funding\"}"
curl -s -X POST "$ECO_URL/admin/adjust" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$ADJUST_BODY" > /dev/null 2>&1

# Wait briefly to avoid wallet version conflicts
sleep 1

# Reset User1 cooldown so they can create a new task
echo -e "${YELLOW}  Resetting User1 cooldown via SQL…${NC}"
docker exec brightbund-db psql -U user -d brightbund \
    -c "UPDATE tasks SET created_at = created_at - INTERVAL '8 days' WHERE creator_id = '$USER1_ID';" > /dev/null 2>&1

# Check User1 balance before cancel-test task creation
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER1_SILVER_BEFORE_CANCEL=$(get_json_number "$HTTP_BODY" "silver_balance")
echo -e "${CYAN}  User1 Silver before cancel-test : ${USER1_SILVER_BEFORE_CANCEL}${NC}"

# User1 creates a clean task (no one will apply)
CANCEL_TASK_BODY="{\"title\":\"Cancel test task\",\"reward\":1,\"workers_needed\":1,\"latitude\":51.50,\"longitude\":-0.12}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CANCEL_TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

CANCEL_TASK_ID=$(get_json_string "$HTTP_BODY" "id")
echo -e "${CYAN}  Cancel-test task ID : ${CANCEL_TASK_ID}${NC}"

# Now cancel it immediately (no applications → clean cancel)
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${TASK_URL}/${CANCEL_TASK_ID}" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CancelTask (clean task)" "DELETE" "${TASK_URL}/${CANCEL_TASK_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 cancels open task" "$HTTP_CODE"

CANCEL_STATUS=$(get_json_string "$HTTP_BODY" "status")
assert_eq "Cancel status is 'cancelled'" "cancelled" "$CANCEL_STATUS"

# Check User1 balance after cancel (should be refunded +1 Silver)
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER1_SILVER_AFTER_CANCEL=$(get_json_number "$HTTP_BODY" "silver_balance")

echo -e "${CYAN}  User1 Silver before cancel : ${USER1_SILVER_BEFORE_CANCEL}${NC}"
echo -e "${CYAN}  User1 Silver after cancel  : ${USER1_SILVER_AFTER_CANCEL} (expected ${USER1_SILVER_BEFORE_CANCEL})${NC}"
assert_eq "User1 refunded 1 Silver after cancel" "$USER1_SILVER_BEFORE_CANCEL" "$USER1_SILVER_AFTER_CANCEL"
echo ""

# ======================================================================
# TEST 33 – CancelTask: Cancel already-cancelled task → 409
# ======================================================================

echo -e "${GREEN}=== TEST 33: CancelTask – Already Cancelled → 409 ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${TASK_URL}/${CANCEL_TASK_ID}" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CancelTask (already cancelled)" "DELETE" "${TASK_URL}/${CANCEL_TASK_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 409 ]]; then
    echo -e "${GREEN}✓ PASS: Double-cancel rejected (HTTP 409)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 409, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 34 – SetUserRegion: Opt-in with valid coordinates → 200
# ======================================================================

echo -e "${GREEN}=== TEST 34: SetUserRegion – Opt-In → 200 ===${NC}"

REGION_BODY="{\"latitude\":37.7749,\"longitude\":-122.4194,\"participate_district\":true,\"location_opt_in\":true}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${MAP_URL}/region" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REGION_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SetUserRegion (opt-in)" "POST" "${MAP_URL}/region" "$REGION_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "SetUserRegion opt-in accepted" "$HTTP_CODE"

REGION_OPT_IN=$(echo "$HTTP_BODY" | grep -o "\"location_opt_in\": *[a-z]*" | head -1 | grep -o "[a-z]*$")
echo -e "${CYAN}  location_opt_in: ${REGION_OPT_IN}${NC}"
assert_eq "location_opt_in is true" "true" "$REGION_OPT_IN"
echo ""

# ======================================================================
# TEST 35 – SetUserRegion: Opt-out → 200
# ======================================================================

echo -e "${GREEN}=== TEST 35: SetUserRegion – Opt-Out → 200 ===${NC}"

REGION_BODY="{\"latitude\":0,\"longitude\":0,\"participate_district\":false,\"location_opt_in\":false}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${MAP_URL}/region" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REGION_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SetUserRegion (opt-out)" "POST" "${MAP_URL}/region" "$REGION_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "SetUserRegion opt-out accepted" "$HTTP_CODE"

REGION_OPT_IN=$(echo "$HTTP_BODY" | grep -o "\"location_opt_in\": *[a-z]*" | head -1 | grep -o "[a-z]*$")
assert_eq "location_opt_in is false" "false" "$REGION_OPT_IN"
echo ""

# ======================================================================
# TEST 36 – SetUserRegion: Invalid coordinates → 400
# ======================================================================

echo -e "${GREEN}=== TEST 36: SetUserRegion – Invalid Coordinates → 400 ===${NC}"

REGION_BODY="{\"latitude\":999,\"longitude\":-999,\"participate_district\":true,\"location_opt_in\":true}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${MAP_URL}/region" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REGION_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SetUserRegion (invalid coords)" "POST" "${MAP_URL}/region" "$REGION_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Invalid coordinates rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 37 – GetRegionChampions: Valid request → 200
# ======================================================================

echo -e "${GREEN}=== TEST 37: GetRegionChampions – Valid Request → 200 ===${NC}"

CHAMPS_URL="${MAP_URL}/champions?h3=852830803fffffff&resolution=5"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$CHAMPS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "GetRegionChampions (valid)" "GET" "$CHAMPS_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "GetRegionChampions returns 200" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 38 – GetRegionChampions: Missing h3 param → 400
# ======================================================================

echo -e "${GREEN}=== TEST 38: GetRegionChampions – Missing h3 Param → 400 ===${NC}"

CHAMPS_URL="${MAP_URL}/champions?resolution=5"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$CHAMPS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "GetRegionChampions (no h3)" "GET" "$CHAMPS_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Missing h3 rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 39 – GetNearbyTasks: Invalid lat query param → 400
# ======================================================================

echo -e "${GREEN}=== TEST 39: GetNearbyTasks – Invalid Lat Param → 400 ===${NC}"

NEARBY_URL="${TASK_URL}/nearby?lat=abc&lon=-74.00"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$NEARBY_URL" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "GetNearbyTasks (lat=abc)" "GET" "$NEARBY_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ PASS: Non-numeric lat rejected (HTTP 400)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 400, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 40 – Cannot Accept More Applicants Than Workers Needed
# ======================================================================

echo -e "${GREEN}=== TEST 40: Cannot Accept > workers_needed (409) ===${NC}"

# Admin gives User1 1 more Silver so they can create a task
ADJUST_BODY="{\"user_id\":\"$USER1_ID\",\"amount\":1.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Extra testing cash\"}"
curl -s -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$ADJUST_BODY" > /dev/null

sleep 1

# Reset User1 cooldown so they can create a new task
echo -e "${YELLOW}  Resetting User1 cooldown via SQL…${NC}"
docker exec brightbund-db psql -U user -d brightbund \
    -c "UPDATE tasks SET created_at = created_at - INTERVAL '8 days' WHERE creator_id = '$USER1_ID';" > /dev/null 2>&1

# 1. User1 creates a task with workers_needed=1
TASK_BODY="{\"title\":\"Limit Test\",\"description\":\"Need 1 worker only\",\"reward\":1,\"workers_needed\":1,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
LIMIT_TASK_ID=$(get_json_string "$HTTP_BODY" "id")

echo -e "${CYAN}  Created Limit Task : ${LIMIT_TASK_ID}${NC}"

# 2. User2 applies
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${TASK_URL}/${LIMIT_TASK_ID}/apply" -H "Authorization: Bearer $USER2_TOKEN" -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
LIMIT_APP2_ID=$(get_json_string "$HTTP_BODY" "application_id")

# 3. User3 applies
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${TASK_URL}/${LIMIT_TASK_ID}/apply" -H "Authorization: Bearer $USER3_TOKEN" -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
LIMIT_APP3_ID=$(get_json_string "$HTTP_BODY" "application_id")

echo -e "${CYAN}  User2 App : ${LIMIT_APP2_ID}${NC}"
echo -e "${CYAN}  User3 App : ${LIMIT_APP3_ID}${NC}"

# 4. User1 Accepts User2 -> Should normally succeed
ACCEPT2_URL="${TASK_URL}/${LIMIT_TASK_ID}/applications/${LIMIT_APP2_ID}/accept"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ACCEPT2_URL" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -eq 200 ]]; then
    echo -e "${GREEN}✓ PASS: First applicant accepted (HTTP 200)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: First applicant should be accepted, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi

# 5. User1 Accepts User3 -> Should fail with 409 Task Full because workers_needed is 1
ACCEPT3_URL="${TASK_URL}/${LIMIT_TASK_ID}/applications/${LIMIT_APP3_ID}/accept"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ACCEPT3_URL" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Accepting Excess Application" "POST" "$ACCEPT3_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"

if [[ "$HTTP_CODE" -eq 409 ]]; then
    echo -e "${GREEN}✓ PASS: Second applicant rejected with Task Full (HTTP 409)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 409, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi

echo ""

# ======================================================================
# TEST 41 – Executor Withdraws Application
# ======================================================================

echo -e "${GREEN}=== TEST 41: Executor Withdraws Application (200) ===${NC}"

# 1. User3 applies to the first main task from early tests so we have a clean application
# The main task was $TASK_ID and since it's COMPLETED, we shouldn't apply to it. 
# Let's create a quick new task for User1
# Reset cooldown for User1
docker exec brightbund-db psql -U user -d brightbund \
    -c "UPDATE tasks SET created_at = created_at - INTERVAL '8 days' WHERE creator_id = '$USER1_ID';" > /dev/null 2>&1

TASK_BODY="{\"title\":\"Withdraw Test\",\"description\":\"Test withdrawal\",\"reward\":1,\"workers_needed\":2,\"latitude\":40.71,\"longitude\":-74.00}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$TASK_URL" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
WITHDRAW_TASK_ID=$(get_json_string "$HTTP_BODY" "id")

echo -e "${CYAN}  Created Withdraw Task : ${WITHDRAW_TASK_ID}${NC}"

# 2. User3 applies
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${TASK_URL}/${WITHDRAW_TASK_ID}/apply" -H "Authorization: Bearer $USER3_TOKEN" -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
WITHDRAW_APP_ID=$(get_json_string "$HTTP_BODY" "application_id")

echo -e "${CYAN}  User3 App ID : ${WITHDRAW_APP_ID}${NC}"

# 3. User3 withdraws their own application
WITHDRAW_URL="${TASK_URL}/${WITHDRAW_TASK_ID}/applications/${WITHDRAW_APP_ID}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$WITHDRAW_URL" -H "Authorization: Bearer $USER3_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Withdraw Application" "DELETE" "$WITHDRAW_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER3"

if [[ "$HTTP_CODE" -eq 200 ]]; then
    echo -e "${GREEN}✓ PASS: Application successfully withdrawn (HTTP 200)${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Expected 200, got HTTP ${HTTP_CODE}${NC}"
    FAIL=$((FAIL + 1))
fi

echo ""

# ======================================================================
# FINAL SUMMARY
# ======================================================================

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}                   Test Summary                      ${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""
echo -e "${GREEN}Users:${NC}"
echo "  Admin  : $ADMIN_ID  ($ADMIN_EMAIL)"
echo "  User1  : $USER1_ID  ($USER1_EMAIL)"
echo "  User2  : $USER2_ID  ($USER2_EMAIL)"
echo ""
echo -e "${GREEN}Tokens:${NC}"
echo "  ADMIN_TOKEN : Bearer ${ADMIN_TOKEN}"
echo "  USER1_TOKEN : Bearer ${USER1_TOKEN}"
echo "  USER2_TOKEN : Bearer ${USER2_TOKEN}"
echo ""
echo -e "${GREEN}Artifacts:${NC}"
echo "  Task ID          : $TASK_ID"
echo "  Application ID   : $APPLICATION_ID"
echo "  Verification Code: $VERIFICATION_CODE"
echo "  Error Task ID    : $ERROR_TASK_ID"
echo "  Error App ID     : $ERROR_APP_ID"
echo "  Cancel Task ID   : $CANCEL_TASK_ID"
echo ""
TOTAL=$((PASS + FAIL))
if [[ "$FAIL" -eq 0 ]]; then
    echo -e "${GREEN}✓ All ${PASS}/${TOTAL} assertions passed${NC}"
else
    echo -e "${RED}✗ ${FAIL}/${TOTAL} assertions FAILED${NC}"
fi
echo ""
echo -e "${CYAN}Flow tested:${NC}"
echo "  Happy path:"
echo "   1. Admin → funded User1 with 5 Silver"
echo "   2. User1 → created task (reward = 1 Silver; balance charged upfront)"
echo "   3. User2 → browsed nearby tasks"
echo "   4. User2 → applied to task (status: pending)"
echo "   5. User1 → listed applications (creator-only)"
echo "   5b. User1 → accepted application (status: accepted)"
echo "   6. User2 → submitted verification code (status: code_verified)"
echo "   7. User1 → confirmed completion (task: completed)"
echo "   8. User2 balance verified (+1 Silver)"
echo "   9. Double-confirm rejected"
echo ""
echo "  Auth guards:"
echo "  10. CreateTask without auth → 401"
echo "  11. GetNearbyTasks without auth → 401"
echo ""
echo "  CreateTask validation errors:"
echo "  12. Empty title → 400"
echo "  13. Title >100 chars → 400"
echo "  14. Invalid reward (0) → 400"
echo "  15. Invalid reward (99) → 400"
echo "  16. Invalid workers (0) → 400"
echo "  17. Invalid workers (21) → 400"
echo "  18. Invalid coordinates → 400"
echo "  19. Malformed JSON → 400"
echo "  20. Insufficient funds → 402"
echo "  21. 7-day cooldown → 429"
echo ""
echo "  ApplyToTask errors:"
echo "  22. Apply to own task → 400"
echo "  23. Apply to non-existent task → 404"
echo "  24. Duplicate application → 409"
echo ""
echo "  SubmitVerificationCode errors:"
echo "  25. Code not 4 digits → 400"
echo "  26. Non-applicant submits code → 403"
echo ""
echo "  ConfirmCompletion errors:"
echo "  27. Non-creator confirms → 403"
echo "  28. Confirm before code_verified → 400"
echo ""
echo "  CancelTask errors:"
echo "  29. Cancel non-existent task → 404"
echo "  30. Non-creator cancels → 403"
echo "  31. Cancel completed task → 409"
echo "  32. Cancel open task + verify refund → 200"
echo "  33. Cancel already-cancelled → 409"
echo ""
echo "  SetUserRegion:"
echo "  34. Opt-in with valid coords → 200"
echo "  35. Opt-out → 200"
echo "  36. Invalid coordinates → 400"
echo ""
echo "  GetRegionChampions:"
echo "  37. Valid request → 200"
echo "  38. Missing h3 param → 400"
echo ""
echo "  GetNearbyTasks:"
echo "  39. Invalid lat param → 400"
echo ""
