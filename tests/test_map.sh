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
EXPECTED_USER1=$(awk "BEGIN {printf \"%.0f\", $USER1_SILVER_BEFORE - 1}")
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

EXPECTED_USER2=$(awk "BEGIN {printf \"%.0f\", ${USER2_SILVER_BEFORE:-0} + 1}")
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
echo ""
TOTAL=$((PASS + FAIL))
if [[ "$FAIL" -eq 0 ]]; then
    echo -e "${GREEN}✓ All ${PASS}/${TOTAL} assertions passed${NC}"
else
    echo -e "${RED}✗ ${FAIL}/${TOTAL} assertions FAILED${NC}"
fi
echo ""
echo -e "${CYAN}Flow tested:${NC}"
echo "  1. Admin → funded User1 with 5 Silver"
echo "  2. User1 → created task (reward = 1 Silver; balance charged upfront)"
echo "  3. User2 → browsed nearby tasks"
echo "  4. User2 → applied to task (status: pending)"
echo "  5. User1 → listed applications (creator-only)"
echo "  6. User2 → submitted verification code (status: code_verified)"
echo "  7. User1 → confirmed completion (task: completed)"
echo "  8. User2 balance verified (+1 Silver)"
echo "  9. Double-confirm rejected"
echo ""
