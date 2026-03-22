#!/bin/bash

# ======================================================================
#  Full System Capabilities – End-to-End Test Suite
#  Modules covered:
#    Health/Auth      – health, register, login, email check, auth guard
#    Economy          – admin adjust, balance, transfer, referral stats
#    Profiles         – get me, patch me, public profile
#    Relationships    – add ally, relationship status
#    Feed             – create post, get feed, comment, like, seal, get seals
#    Map/Tasks        – set region, H3 admin lookup, task lifecycle
#    Ranks            – public ranks catalog + my rank
#    Settings         – read feed settings
#    Admin Feed       – moderation queue visibility for admin
# ======================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

BASE_URL="http://localhost:8081/api/v1"
AUTH_URL="${BASE_URL}/auth"
ECO_URL="${BASE_URL}/economy"
PROFILE_URL="${BASE_URL}/profiles"
FEED_URL="${BASE_URL}/feed"
POSTS_URL="${BASE_URL}/posts"
TASK_URL="${BASE_URL}/tasks"
MAP_URL="${BASE_URL}/map"
SETTINGS_URL="${BASE_URL}/settings"
ADMIN_URL="${BASE_URL}/admin"

if command -v curl.exe >/dev/null 2>&1; then
    CURL_BIN="curl.exe"
else
    CURL_BIN="curl"
fi

PASS=0
FAIL=0

# ── helpers ────────────────────────────────────────────────────────────

get_json_string() {
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_json_number() {
    echo "$1" | grep -o "\"$2\": *[0-9.]*" | head -1 | grep -o "[0-9.]*"
}

get_json_bool() {
    echo "$1" | grep -o "\"$2\": *[a-z]*" | head -1 | awk -F': ' '{print $2}' | tr -d ' '
}

assert_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓ PASS: ${label}${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ FAIL: ${label} — missing '${needle}'${NC}"
        FAIL=$((FAIL + 1))
    fi
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

assert_status() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓ PASS: ${label} (HTTP ${actual})${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ FAIL: ${label} — expected HTTP ${expected}, got HTTP ${actual}${NC}"
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

log_request() {
    local label="$1"
    local method="$2"
    local url="$3"
    local body="$4"
    local resp_body="$5"
    local http_code="$6"
    local token_hint="$7"

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

run_sql() {
    local sql="$1"

    if command -v docker >/dev/null 2>&1; then
        docker exec brightbund-db psql -U user -d brightbund -c "$sql" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    fi

    if command -v psql >/dev/null 2>&1; then
        PGPASSWORD="password" psql -h localhost -p 5434 -U user -d brightbund -c "$sql" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    fi

    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -Command "\$env:PGPASSWORD='password'; psql -h localhost -p 5434 -U user -d brightbund -c \"$sql\"" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    fi

    return 1
}

# ── banner ─────────────────────────────────────────────────────────────

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}      Full System Capabilities – End-to-End Test Suite      ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# ======================================================================
# TEST 1 – Health endpoint
# ======================================================================

echo -e "${GREEN}=== TEST 1: Health Check ===${NC}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "http://localhost:8081/health")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Health" "GET" "http://localhost:8081/health" "" "$HTTP_BODY" "$HTTP_CODE" ""
assert_ok "Health endpoint is reachable" "$HTTP_CODE"
assert_contains "Health response contains ok status" "$HTTP_BODY" '"status":"ok"'
echo ""

# ======================================================================
# SETUP – Create users (admin + 3 regular users)
# ======================================================================

echo -e "${GREEN}=== SETUP: Creating Users ===${NC}"
echo ""

ADMIN_EMAIL="sys_admin_${RANDOM}@example.com"
ADMIN_PASSWORD="AdminPass123!"

USER1_EMAIL="sys_user1_${RANDOM}@example.com"
USER1_PASSWORD="Pass123!"

USER2_EMAIL="sys_user2_${RANDOM}@example.com"
USER2_PASSWORD="Pass123!"

USER3_EMAIL="sys_user3_${RANDOM}@example.com"
USER3_PASSWORD="Pass123!"

register_user() {
    local email="$1"
    local password="$2"
    local first_name="$3"
    local last_name="$4"
    local device_id="$5"

    local body="{\"email\":\"$email\",\"password\":\"$password\",\"first_name\":\"$first_name\",\"last_name\":\"$last_name\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"$device_id\",\"app_version\":\"1.0.0\"}"
    local response=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$body")
    local http_body=$(echo "$response" | head -n -1)
    local http_code=$(echo "$response" | tail -n 1)

    log_request "Register ${first_name}" "POST" "$AUTH_URL/register-email" "$body" "$http_body" "$http_code"
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        echo "$http_body"
        return 0
    fi
    return 1
}

login_user() {
    local email="$1"
    local password="$2"
    local device_id="$3"

    local body="{\"email\":\"$email\",\"password\":\"$password\",\"device_id\":\"$device_id\"}"
    local response=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$body")
    local http_body=$(echo "$response" | head -n -1)
    local http_code=$(echo "$response" | tail -n 1)

    log_request "Login ${email}" "POST" "$AUTH_URL/login-email" "$body" "$http_body" "$http_code"
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        echo "$http_body"
        return 0
    fi
    return 1
}

# Admin
ADMIN_REGISTER=$(register_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "Admin" "System" "sys-admin-device")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed to create admin user${NC}"
    exit 1
fi
ADMIN_ID=$(get_json_string "$ADMIN_REGISTER" "id")

if run_sql "UPDATE users SET is_admin = true WHERE id = '$ADMIN_ID';"; then
    echo -e "${GREEN}✓ PASS: Admin privileges granted via SQL${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: Could not grant admin privileges via SQL${NC}"
    FAIL=$((FAIL + 1))
    exit 1
fi

ADMIN_LOGIN=$(login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "sys-admin-device")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed admin login${NC}"
    exit 1
fi
ADMIN_TOKEN=$(get_json_string "$ADMIN_LOGIN" "access_token")

# User1
USER1_REGISTER=$(register_user "$USER1_EMAIL" "$USER1_PASSWORD" "Alice" "Creator" "sys-device-1")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed to create user1${NC}"
    exit 1
fi
USER1_ID=$(get_json_string "$USER1_REGISTER" "id")

USER1_LOGIN=$(login_user "$USER1_EMAIL" "$USER1_PASSWORD" "sys-device-1")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed user1 login${NC}"
    exit 1
fi
USER1_TOKEN=$(get_json_string "$USER1_LOGIN" "access_token")

# User2
USER2_REGISTER=$(register_user "$USER2_EMAIL" "$USER2_PASSWORD" "Bob" "Consumer" "sys-device-2")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed to create user2${NC}"
    exit 1
fi
USER2_ID=$(get_json_string "$USER2_REGISTER" "id")

USER2_LOGIN=$(login_user "$USER2_EMAIL" "$USER2_PASSWORD" "sys-device-2")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed user2 login${NC}"
    exit 1
fi
USER2_TOKEN=$(get_json_string "$USER2_LOGIN" "access_token")

# User3
USER3_REGISTER=$(register_user "$USER3_EMAIL" "$USER3_PASSWORD" "Charlie" "Observer" "sys-device-3")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed to create user3${NC}"
    exit 1
fi
USER3_ID=$(get_json_string "$USER3_REGISTER" "id")

USER3_LOGIN=$(login_user "$USER3_EMAIL" "$USER3_PASSWORD" "sys-device-3")
if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Failed user3 login${NC}"
    exit 1
fi
USER3_TOKEN=$(get_json_string "$USER3_LOGIN" "access_token")

echo -e "${GREEN}✓ PASS: Setup completed (admin + 3 users)${NC}"
PASS=$((PASS + 1))
echo ""

# ======================================================================
# TEST 2 – Auth utilities and guard
# ======================================================================

echo -e "${GREEN}=== TEST 2: Auth Check-Email + Guard ===${NC}"

CHECK_EMAIL_BODY="{\"email\":\"$USER1_EMAIL\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/check-email" -H "Content-Type: application/json" -d "$CHECK_EMAIL_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Check Email" "POST" "$AUTH_URL/check-email" "$CHECK_EMAIL_BODY" "$HTTP_BODY" "$HTTP_CODE"
assert_ok "Auth check-email works" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$ECO_URL/balance")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Unauthorized Economy Access" "GET" "$ECO_URL/balance" "" "$HTTP_BODY" "$HTTP_CODE"
assert_status "Protected endpoint rejects missing token" "401" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 3 – Economy core flows
# ======================================================================

echo -e "${GREEN}=== TEST 3: Economy (Adjust / Balance / Transfer / Referral Stats) ===${NC}"

ADJUST1_BODY="{\"user_id\":\"$USER1_ID\",\"amount\":5.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"System E2E funding user1\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$ADJUST1_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Admin Adjust User1" "POST" "$ECO_URL/admin/adjust" "$ADJUST1_BODY" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
assert_ok "Admin funds user1 (silver)" "$HTTP_CODE"

ADJUST2_BODY="{\"user_id\":\"$USER2_ID\",\"amount\":5.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"System E2E funding user2\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$ADJUST2_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Admin Adjust User2" "POST" "$ECO_URL/admin/adjust" "$ADJUST2_BODY" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
assert_ok "Admin funds user2 (silver)" "$HTTP_CODE"

ADJUST3_BODY="{\"user_id\":\"$USER3_ID\",\"amount\":5.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"System E2E funding user3\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$ADJUST3_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Admin Adjust User3" "POST" "$ECO_URL/admin/adjust" "$ADJUST3_BODY" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
assert_ok "Admin funds user3 (silver)" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "User2 Balance" "GET" "$ECO_URL/balance" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 reads wallet balance" "$HTTP_CODE"

TRANSFER_IDEMPOTENCY_KEY="123e4567-e89b-12d3-a456-426614174111"
TRANSFER_BODY="{\"recipient_user_id\":\"$USER1_ID\",\"amount\":1,\"currency\":\"SILVER_SEAL\",\"reason\":\"system capability transfer\",\"idempotency_key\":\"$TRANSFER_IDEMPOTENCY_KEY\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $USER2_TOKEN" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "User2 Transfer Seal" "POST" "$ECO_URL/transfer" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Seal transfer endpoint works" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$ECO_URL/referral/stats" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Referral Stats" "GET" "$ECO_URL/referral/stats" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Referral stats endpoint works" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 4 – Profiles + Relationships
# ======================================================================

echo -e "${GREEN}=== TEST 4: Profiles + Relationships ===${NC}"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get My Profile" "GET" "$PROFILE_URL/me" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Get my profile works" "$HTTP_CODE"

PATCH_PROFILE_BODY="{\"first_name\":\"Alice\",\"last_name\":\"System\",\"bio\":\"Full-system E2E profile update\",\"is_public\":true}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X PATCH "$PROFILE_URL/me" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$PATCH_PROFILE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Patch My Profile" "PATCH" "$PROFILE_URL/me" "$PATCH_PROFILE_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Patch profile works" "$HTTP_CODE"
assert_contains "Bio updated" "$HTTP_BODY" 'Full-system E2E profile update'

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USER1_ID" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Public Profile" "GET" "$PROFILE_URL/$USER1_ID" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Public profile view works" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$PROFILE_URL/$USER2_ID/allies" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Add Ally" "POST" "$PROFILE_URL/$USER2_ID/allies" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Add ally works" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USER2_ID/relationship" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Relationship Status" "GET" "$PROFILE_URL/$USER2_ID/relationship" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Relationship status endpoint works" "$HTTP_CODE"
assert_contains "Relationship reflects ally state" "$HTTP_BODY" '"i_follow_them":true'
echo ""

# ======================================================================
# TEST 5 – Feed interactions (post/comment/like/seal)
# ======================================================================

echo -e "${GREEN}=== TEST 5: Feed (Create Post / Feed / Comment / Like / Seal) ===${NC}"

CREATE_POST_BODY="{\"caption\":\"System capability post\",\"media_attachments\":[{\"type\":\"image\",\"url\":\"http://minio/bucket/system.jpg\"}],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$CREATE_POST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create Post" "POST" "$POSTS_URL" "$CREATE_POST_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Create post works" "$HTTP_CODE"
POST_ID=$(get_json_string "$HTTP_BODY" "post_id")

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$FEED_URL/?limit=20" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Feed" "GET" "$FEED_URL/?limit=20" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Get feed works" "$HTTP_CODE"

COMMENT_BODY="{\"content_text\":\"system comment\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL/$POST_ID/comments" -H "Authorization: Bearer $USER2_TOKEN" -H "Content-Type: application/json" -d "$COMMENT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create Comment" "POST" "$POSTS_URL/$POST_ID/comments" "$COMMENT_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Create comment works" "$HTTP_CODE"
COMMENT_ID=$(get_json_string "$HTTP_BODY" "comment_id")

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL/$POST_ID/likes" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Toggle Like" "POST" "$POSTS_URL/$POST_ID/likes" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Toggle like works" "$HTTP_CODE"

SEAL_BODY="{\"amount\":1,\"comment\":\"system seal\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL/$POST_ID/seals" -H "Authorization: Bearer $USER3_TOKEN" -H "Content-Type: application/json" -d "$SEAL_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Send Seal" "POST" "$POSTS_URL/$POST_ID/seals" "$SEAL_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER3"
assert_ok "Send seal works" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$POSTS_URL/$POST_ID/seals?limit=10" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Seals" "GET" "$POSTS_URL/$POST_ID/seals?limit=10" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Get seals works" "$HTTP_CODE"

echo ""

# ======================================================================
# TEST 6 – Map & task lifecycle
# ======================================================================

echo -e "${GREEN}=== TEST 6: Map/Tasks (Region + Task Lifecycle) ===${NC}"

SET_REGION_BODY="{\"latitude\":43.2389,\"longitude\":76.8897,\"participate_district\":true,\"location_opt_in\":true}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$MAP_URL/region" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$SET_REGION_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Set User Region" "POST" "$MAP_URL/region" "$SET_REGION_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Set user region works" "$HTTP_CODE"
H3_RES5=$(get_json_string "$HTTP_BODY" "h3_res5")

if [[ -n "$H3_RES5" ]]; then
    RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$MAP_URL/h3/$H3_RES5/admin" -H "Authorization: Bearer $USER1_TOKEN")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    log_request "H3 Admin Lookup" "GET" "$MAP_URL/h3/$H3_RES5/admin" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "404" ]]; then
        echo -e "${GREEN}✓ PASS: H3 admin lookup endpoint reachable (HTTP ${HTTP_CODE})${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}✗ FAIL: H3 admin lookup unexpected code ${HTTP_CODE}${NC}"
        FAIL=$((FAIL + 1))
    fi
fi

TASK_BODY="{\"title\":\"System capability task\",\"description\":\"End-to-end task lifecycle\",\"reward\":1,\"workers_needed\":1,\"latitude\":40.7128,\"longitude\":-74.0060,\"auto_shutdown\":false}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$TASK_URL" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TASK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create Task" "POST" "$TASK_URL" "$TASK_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Create task works" "$HTTP_CODE"
TASK_ID=$(get_json_string "$HTTP_BODY" "id")
VERIFICATION_CODE=$(get_json_string "$HTTP_BODY" "verification_code")

APPLY_URL="$TASK_URL/$TASK_ID/apply"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$APPLY_URL" -H "Authorization: Bearer $USER2_TOKEN" -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Apply To Task" "POST" "$APPLY_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Apply to task works" "$HTTP_CODE"
APPLICATION_ID=$(get_json_string "$HTTP_BODY" "application_id")

ACCEPT_URL="$TASK_URL/$TASK_ID/applications/$APPLICATION_ID/accept"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$ACCEPT_URL" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Accept Application" "POST" "$ACCEPT_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Accept application works" "$HTTP_CODE"

VERIFY_URL="$TASK_URL/$TASK_ID/applications/$APPLICATION_ID/verify-code"
VERIFY_BODY="{\"code\":\"$VERIFICATION_CODE\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$VERIFY_URL" -H "Authorization: Bearer $USER2_TOKEN" -H "Content-Type: application/json" -d "$VERIFY_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Verify Task Code" "POST" "$VERIFY_URL" "$VERIFY_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Verify code works" "$HTTP_CODE"

CONFIRM_URL="$TASK_URL/$TASK_ID/applications/$APPLICATION_ID/confirm"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$CONFIRM_URL" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Confirm Completion" "POST" "$CONFIRM_URL" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Confirm completion works" "$HTTP_CODE"

echo ""

# ======================================================================
# TEST 7 – Ranks + Settings + Admin reports
# ======================================================================

echo -e "${GREEN}=== TEST 7: Ranks + Settings + Admin Reports ===${NC}"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$BASE_URL/profiles/ranks")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Rank Catalog" "GET" "$BASE_URL/profiles/ranks" "" "$HTTP_BODY" "$HTTP_CODE" ""
assert_ok "Public rank catalog works" "$HTTP_CODE"
assert_contains "Rank catalog contains rank list" "$HTTP_BODY" '"ranks"'

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me/rank" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get My Rank" "GET" "$PROFILE_URL/me/rank" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Get my rank works" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$SETTINGS_URL/feed" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Feed Settings" "GET" "$SETTINGS_URL/feed" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Settings feed endpoint works" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$ADMIN_URL/reports?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Admin Reports" "GET" "$ADMIN_URL/reports?limit=10" "" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
assert_ok "Admin reports endpoint works for admin" "$HTTP_CODE"

echo ""

# ======================================================================
# TEST 8 – Final relationship sanity from User2 perspective
# ======================================================================

echo -e "${GREEN}=== TEST 8: Relationship Sanity (User2 perspective) ===${NC}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USER1_ID/relationship" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Relationship Reverse Check" "GET" "$PROFILE_URL/$USER1_ID/relationship" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "Relationship endpoint works in reverse" "$HTTP_CODE"
assert_contains "Reverse relationship reflects they_follow_me" "$HTTP_BODY" '"they_follow_me":true'
echo ""

# ======================================================================
# SUMMARY
# ======================================================================

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  Full system capability test finished.${NC}"
echo -e "${GREEN}  PASS : ${PASS}${NC}"
if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}  FAIL : ${FAIL}${NC}"
    echo -e "${CYAN}============================================================${NC}"
    exit 1
else
    echo -e "${CYAN}  FAIL : ${FAIL}${NC}"
    echo -e "${CYAN}============================================================${NC}"
    exit 0
fi
