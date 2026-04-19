#!/bin/bash

# Simple sanity checks for smart feed cursor + allies visibility.

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

AUTH_URL="http://127.0.0.1:8081/api/v1/auth"
FEED_URL="http://127.0.0.1:8081/api/v1/feed"
POSTS_URL="http://127.0.0.1:8081/api/v1/posts"

# Prefer Windows curl.exe when running in Git Bash on Windows
if command -v curl.exe >/dev/null 2>&1; then
    CURL_BIN="curl.exe"
else
    CURL_BIN="curl"
fi

CURL_OPTS=(-sS --connect-timeout 5 --max-time 15)

PASS=0
FAIL=0

get_json_string() {
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

log_request() {
    local label="$1"
    local method="$2"
    local url="$3"
    local body="$4"
    local resp_body="$5"
    local http_code="$6"
    echo -e "${CYAN}${label}${NC}"
    echo -e "${CYAN}${method} ${url}${NC}"
    if [[ -n "$body" ]]; then
        echo -e "${CYAN}Body: ${body}${NC}"
    fi
    echo -e "${CYAN}HTTP: ${http_code}${NC}"
    echo -e "${CYAN}Resp: ${resp_body}${NC}"
    echo ""
}

assert_ok() {
    local label="$1"
    local code="$2"
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        echo -e "${GREEN}PASS: ${label}${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL: ${label} (HTTP ${code})${NC}"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1"
    local hay="$2"
    local needle="$3"
    if echo "$hay" | grep -q "$needle"; then
        echo -e "${GREEN}PASS: ${label}${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL: ${label} (missing ${needle})${NC}"
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${CYAN}=== SETUP USERS ===${NC}"

USER1_EMAIL="smart_user1_${RANDOM}@example.com"
USER1_PASSWORD="Pass123!"
USER2_EMAIL="smart_user2_${RANDOM}@example.com"
USER2_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"first_name\":\"User\",\"last_name\":\"One\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"dev1\",\"app_version\":\"1.0.0\"}"
RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Register User1" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"
assert_ok "Register User1" "$HTTP_CODE"
USER1_ID=$(get_json_string "$HTTP_BODY" "id")

REGISTER_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"first_name\":\"User\",\"last_name\":\"Two\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"dev2\",\"app_version\":\"1.0.0\"}"
RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Register User2" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"
assert_ok "Register User2" "$HTTP_CODE"
USER2_ID=$(get_json_string "$HTTP_BODY" "id")

LOGIN_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"device_id\":\"dev1\"}"
RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Login User1" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
USER1_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")

LOGIN_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"device_id\":\"dev2\"}"
RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Login User2" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
USER2_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")

echo -e "${CYAN}=== SET ALLY RELATION (User1 -> User2) ===${NC}"
ALLY_SQL="INSERT INTO user_relationships (user_id, target_user_id, relationship_type) VALUES ('$USER1_ID', '$USER2_ID', 'ally') ON CONFLICT DO NOTHING;"

ALLY_SET=false
if command -v docker >/dev/null 2>&1; then
    docker exec brightbund-db psql -U user -d brightbund -c "$ALLY_SQL" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        ALLY_SET=true
    fi
fi

if [[ "$ALLY_SET" = false ]] && command -v psql >/dev/null 2>&1; then
    PGPASSWORD="password" psql -h localhost -p 5434 -U user -d brightbund -c "$ALLY_SQL" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        ALLY_SET=true
    fi
fi

if [[ "$ALLY_SET" = false ]] && command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -Command "\$env:PGPASSWORD='password'; psql -h localhost -p 5434 -U user -d brightbund -c \"$ALLY_SQL\"" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        ALLY_SET=true
    fi
fi

if [[ "$ALLY_SET" = false ]]; then
    echo -e "${RED}FAIL: Could not insert ally relation (docker/psql)${NC}"
    exit 1
fi

echo -e "${CYAN}=== CREATE POSTS ===${NC}"

POST_BODY="{\"caption\":\"ally-only post\",\"media_attachments\":[],\"visibility\":\"ALLIES_ONLY\",\"comment_permission\":\"ANYONE\",\"location_lat\":40.0,\"location_lon\":-74.0}"
RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "$POSTS_URL" -H "Authorization: Bearer $USER2_TOKEN" -H "Content-Type: application/json" -d "$POST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create Post (User2)" "POST" "$POSTS_URL" "$POST_BODY" "$HTTP_BODY" "$HTTP_CODE"
assert_ok "Create Post (User2)" "$HTTP_CODE"
POST_ID_1=$(get_json_string "$HTTP_BODY" "post_id")

sleep 1

POST_BODY="{\"caption\":\"second post\",\"media_attachments\":[],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\"}"
RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "$POSTS_URL" -H "Authorization: Bearer $USER2_TOKEN" -H "Content-Type: application/json" -d "$POST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create Post 2 (User2)" "POST" "$POSTS_URL" "$POST_BODY" "$HTTP_BODY" "$HTTP_CODE"
assert_ok "Create Post 2 (User2)" "$HTTP_CODE"
POST_ID_2=$(get_json_string "$HTTP_BODY" "post_id")

echo -e "${CYAN}=== FETCH FEED (cursor pagination) ===${NC}"

RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X GET "$FEED_URL?limit=1&lat=40.0&lon=-74.0" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Feed page 1" "GET" "$FEED_URL?limit=1&lat=40.0&lon=-74.0" "" "$HTTP_BODY" "$HTTP_CODE"
assert_ok "Get Feed page 1" "$HTTP_CODE"
NEXT_CURSOR=$(get_json_string "$HTTP_BODY" "next_cursor")

assert_contains "Feed includes newest post" "$HTTP_BODY" "$POST_ID_2"

RESPONSE=$($CURL_BIN "${CURL_OPTS[@]}" -w "\n%{http_code}" -X GET "$FEED_URL?limit=1&cursor=$NEXT_CURSOR" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY2=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE2=$(echo "$RESPONSE" | tail -n 1)
log_request "Get Feed page 2" "GET" "$FEED_URL?limit=1&cursor=$NEXT_CURSOR" "" "$HTTP_BODY2" "$HTTP_CODE2"
assert_ok "Get Feed page 2" "$HTTP_CODE2"

if echo "$HTTP_BODY2" | grep -q "$POST_ID_1"; then
    echo -e "${GREEN}PASS: Cursor returned older ally-only post${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL: Cursor did not return expected ally-only post${NC}"
    FAIL=$((FAIL + 1))
fi

echo ""
echo -e "${CYAN}=== SUMMARY ===${NC}"
echo -e "${GREEN}PASS: ${PASS}${NC}"
echo -e "${RED}FAIL: ${FAIL}${NC}"

if [[ "$FAIL" -ne 0 ]]; then
    exit 1
fi
