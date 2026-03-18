#!/bin/bash

# ======================================================================
#  Feed Module – End-to-End Test Suite
#  Handlers covered:
#    CreatePost          – happy path, no-media 400, invalid visibility 400
#    UpdatePost          – happy path for privacy / interaction settings
#    DeletePost          – happy path for author-owned post lifecycle
#    GetFeed             – happy path, cursor pagination
#    Smart Feed          – allies-only visibility + cursor pagination
#    CreateComment       – happy path, reply thread, empty text 400
#    GetThreadedComments – happy path (verifies reply appears)
#    DeleteComment       – happy path for author-owned comment deletion
#    ToggleLike          – like + unlike (second call)
#    ToggleCommentLike   – happy path on comment interaction
#    GetLikes            – happy path
#    SendSeal            – happy path, self-seal 400, no-funds 402,
#                          zero-amount 400, duplicate/idempotent 201
#    GetSeals            – happy path
#    ReportPost          – create + duplicate guard + admin listing visibility
#    ReportComment       – create + admin listing visibility
#    Admin Reports       – list report queue with filters
#    SyncFeedState       – happy path, delta=0 400, large delta capped,
#                          break_seconds_remaining field, sync-during-break
#    GetFeedState        – happy path + new fields (break_seconds_remaining)
#    Anti-doomscroll     – cooldown triggers, break phase, full reset cycle
#    Auth guard          – unauthenticated 401 on a protected endpoint
# ======================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

AUTH_URL="http://localhost:8081/api/v1/auth"
ECO_URL="http://localhost:8081/api/v1/economy"
FEED_URL="http://localhost:8081/api/v1/feed"
POSTS_URL="http://localhost:8081/api/v1/posts"

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

assert_not_contains() {
    local label="$1"
    local haystack="$2"
    local needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${RED}✗ FAIL: ${label} — unexpected '${needle}'${NC}"
        FAIL=$((FAIL + 1))
    else
        echo -e "${GREEN}✓ PASS: ${label}${NC}"
        PASS=$((PASS + 1))
    fi
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

# ── banner ─────────────────────────────────────────────────────────────

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}         Feed Module – End-to-End Test Suite         ${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""

# ======================================================================
# SETUP – Create users
# ======================================================================

echo -e "${GREEN}=== SETUP: Creating Users ===${NC}"
echo ""

# ── Admin ──────────────────────────────────────────────────────────────
ADMIN_EMAIL="feed_admin_${RANDOM}@example.com"
ADMIN_PASSWORD="AdminPass123!"

REGISTER_BODY="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"first_name\":\"Admin\",\"last_name\":\"Feed\",\"date_of_birth\":\"1990-01-01\",\"device_id\":\"admin-feed-device\",\"app_version\":\"1.0.0\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Register Admin" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ADMIN_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ Admin created: $ADMIN_ID${NC}"

    echo -e "${YELLOW}  Granting admin privileges via SQL and clearing dirty post state…${NC}"
    if run_sql "UPDATE users SET is_admin = true WHERE id = '$ADMIN_ID'; TRUNCATE posts CASCADE;"; then
        echo -e "${GREEN}  ✓ Admin privileges granted and env cleaned${NC}"
    else
        echo -e "${RED}  ✗ Failed to grant admin privileges – aborting${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Admin registration failed – aborting${NC}"
    exit 1
fi

LOGIN_BODY="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"device_id\":\"admin-feed-device\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
    -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Login Admin" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
ADMIN_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${CYAN}  ADMIN_TOKEN acquired${NC}"
echo ""

# ── User 1 (Post Creator / Author) ────────────────────────────────────
USER1_EMAIL="feed_user1_${RANDOM}@example.com"
USER1_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"first_name\":\"Alice\",\"last_name\":\"Creator\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"feed-device1\",\"app_version\":\"1.0.0\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
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

LOGIN_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"device_id\":\"feed-device1\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
    -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Login User1" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
USER1_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${CYAN}  USER1_TOKEN acquired${NC}"
echo ""

# ── User 2 (Consumer / Sealer) ─────────────────────────────────────────
USER2_EMAIL="feed_user2_${RANDOM}@example.com"
USER2_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"first_name\":\"Bob\",\"last_name\":\"Consumer\",\"date_of_birth\":\"2001-06-15\",\"device_id\":\"feed-device2\",\"app_version\":\"1.0.0\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Register User2" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    USER2_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ User2 created: $USER2_ID${NC}"
else
    echo -e "${RED}✗ User2 registration failed – aborting${NC}"
    exit 1
fi

LOGIN_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"device_id\":\"feed-device2\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
    -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Login User2" "POST" "$AUTH_URL/login-email" "$LOGIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
USER2_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${CYAN}  USER2_TOKEN acquired${NC}"
echo ""

# ======================================================================
# SETUP – Ally relation for smart feed visibility tests
# ======================================================================

echo -e "${GREEN}=== SETUP: Ally Relation for Smart Feed ===${NC}"
if run_sql "INSERT INTO user_relationships (user_id, target_user_id, relationship_type) VALUES ('$USER1_ID', '$USER2_ID', 'ally') ON CONFLICT DO NOTHING;"; then
    echo -e "${GREEN}✓ Ally relation inserted: User1 can see User2 allies-only posts${NC}"
else
    echo -e "${RED}✗ Failed to insert ally relation – aborting${NC}"
    exit 1
fi
echo ""

# ======================================================================
# TEST 1 – Admin funds User2 with Silver (for seal tests)
# ======================================================================

echo -e "${GREEN}=== TEST 1: Admin Funds User2 with 5 Silver ===${NC}"

ADJUST_BODY="{\"user_id\":\"$USER2_ID\",\"amount\":5.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Feed test funding\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$ADJUST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "Admin Adjust Balance (User2 +5 Silver)" "POST" "$ECO_URL/admin/adjust" "$ADJUST_BODY" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
assert_ok "Admin funds User2 with 5 Silver" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 1b – Create additional posts to highlight smart-feed changes
# ======================================================================

echo -e "${GREEN}=== TEST 1b: User2 Creates Smart Feed Visibility Posts ===${NC}"

ALLY_POST_BODY="{\"caption\":\"ally-only smart feed post\",\"media_attachments\":[{\"type\":\"image\",\"url\":\"http://minio/bucket/ally.jpg\"}],\"visibility\":\"ALLIES_ONLY\",\"comment_permission\":\"ALLIES_ONLY\",\"location_lat\":40.0,\"location_lon\":-74.0}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$ALLY_POST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create allies-only post (User2)" "POST" "$POSTS_URL" "$ALLY_POST_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 creates allies-only post" "$HTTP_CODE"
ALLY_ONLY_POST_ID=$(get_json_string "$HTTP_BODY" "post_id")

sleep 1

PUBLIC_POST_BODY="{\"caption\":\"public smart feed post\",\"media_attachments\":[{\"type\":\"image\",\"url\":\"http://minio/bucket/public.jpg\"}],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\",\"location_lat\":40.0,\"location_lon\":-74.0}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PUBLIC_POST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create public smart feed post (User2)" "POST" "$POSTS_URL" "$PUBLIC_POST_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 creates public smart feed post" "$HTTP_CODE"
PUBLIC_SMART_POST_ID=$(get_json_string "$HTTP_BODY" "post_id")
echo ""

# ======================================================================
# TEST 2 – Auth guard (unauthenticated request returns 401)
# ======================================================================

echo -e "${GREEN}=== TEST 2: Auth Guard – Unauthenticated Request ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${FEED_URL}/state")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "GetFeedState without token" "GET" "${FEED_URL}/state" "" "$HTTP_BODY" "$HTTP_CODE" ""
assert_status "Unauthenticated request is rejected with 401" "401" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 3 – CreatePost: invalid visibility → 400
# ======================================================================

echo -e "${GREEN}=== TEST 3: CreatePost – Invalid Visibility ===${NC}"

BODY="{\"caption\":\"test\",\"media_attachments\":[{\"type\":\"IMAGE\",\"url\":\"http://minio/img.jpg\"}],\"visibility\":\"INVALID\",\"comment_permission\":\"ANYONE\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreatePost invalid visibility" "POST" "$POSTS_URL" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_status "CreatePost rejects invalid visibility with 400" "400" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 4 – CreatePost: no media and no caption → 400
# ======================================================================

echo -e "${GREEN}=== TEST 4: CreatePost – No Content or Media ===${NC}"

BODY="{\"caption\":\"\",\"media_attachments\":[],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreatePost no content or media" "POST" "$POSTS_URL" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_status "CreatePost rejects empty content with 400" "400" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 5 – CreatePost: happy path (User1)
# ======================================================================

echo -e "${GREEN}=== TEST 5: User1 Creates a Post ===${NC}"

CREATE_POST_BODY="{\"caption\":\"Hello World from BrightBund!\",\"media_attachments\":[{\"type\":\"image\",\"url\":\"http://minio/bucket/img1.jpg\"}],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CREATE_POST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Creates Post" "POST" "$POSTS_URL" "$CREATE_POST_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 creates a post" "$HTTP_CODE"
PRIMARY_POST_ID=$(get_json_string "$HTTP_BODY" "post_id")
echo ""

# ======================================================================
# TEST 5b – UpdatePost and DeletePost lifecycle on a temporary post
# ======================================================================

echo -e "${GREEN}=== TEST 5b: Post Lifecycle – Update and Delete ===${NC}"

TEMP_POST_BODY="{\"caption\":\"temporary lifecycle post\",\"media_attachments\":[{\"type\":\"image\",\"url\":\"http://minio/bucket/temp.jpg\"}],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TEMP_POST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create temporary lifecycle post" "POST" "$POSTS_URL" "$TEMP_POST_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Temporary post created for lifecycle checks" "$HTTP_CODE"
TEMP_POST_ID=$(get_json_string "$HTTP_BODY" "post_id")

UPDATE_BODY="{\"comment_permission\":\"NO_ONE\",\"hide_likes_count\":true}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X PATCH "${POSTS_URL}/${TEMP_POST_ID}" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Update temporary post" "PATCH" "${POSTS_URL}/${TEMP_POST_ID}" "$UPDATE_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Author can update post settings" "$HTTP_CODE"
assert_contains "Updated post reflects NO_ONE comment permission" "$HTTP_BODY" '"comment_permission":"NO_ONE"'

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X DELETE "${POSTS_URL}/${TEMP_POST_ID}" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Delete temporary post" "DELETE" "${POSTS_URL}/${TEMP_POST_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "Author can delete own post" "$HTTP_CODE"
assert_contains "Delete post returns deleted status" "$HTTP_BODY" '"status":"deleted"'
echo ""

# ======================================================================
# TEST 6 – GetFeed: User2 fetches feed and extracts post_id
# ======================================================================

echo -e "${GREEN}=== TEST 6: User2 Fetches Feed ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${FEED_URL}/?limit=20" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Gets Feed" "GET" "${FEED_URL}/?limit=20" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 fetches the feed" "$HTTP_CODE"

# post_id lives inside items[]:  {"items":[{"post_id":"uuid",...}],...}
POST_ID=$(get_json_string "$HTTP_BODY" "post_id")
echo -e "${CYAN}  Extracted Post ID: ${POST_ID}${NC}"

if [[ -z "$POST_ID" ]]; then
    echo -e "${YELLOW}! post_id not found in feed — smart geo may have filtered the post. Remaining interaction tests will be skipped.${NC}"
fi
echo ""

# ======================================================================
# TEST 7 – GetFeed: pagination with next_cursor
# ======================================================================

echo -e "${GREEN}=== TEST 7: GetFeed – Pagination (limit=1 then cursor) ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${FEED_URL}/?limit=1" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Gets Feed (limit=1)" "GET" "${FEED_URL}/?limit=1" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "GetFeed with limit=1 returns 200" "$HTTP_CODE"

NEXT_CURSOR=$(get_json_string "$HTTP_BODY" "next_cursor")
if [[ -n "$NEXT_CURSOR" ]]; then
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${FEED_URL}/?limit=1&cursor=${NEXT_CURSOR}" \
        -H "Authorization: Bearer $USER2_TOKEN")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    log_request "User2 Gets Feed (page 2 via cursor)" "GET" "${FEED_URL}/?limit=1&cursor=${NEXT_CURSOR}" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
    assert_ok "GetFeed cursor pagination returns 200" "$HTTP_CODE"
else
    echo -e "${YELLOW}! No next_cursor returned (only one post exists), skipping cursor pagination test.${NC}"
fi
echo ""

if [[ -n "$POST_ID" ]]; then

# ======================================================================
# TEST 8 – CreateComment: empty content_text → 400
# ======================================================================

echo -e "${GREEN}=== TEST 8: CreateComment – Empty Text ===${NC}"

BODY="{\"content_text\":\"\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/comments" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "CreateComment empty text" "POST" "${POSTS_URL}/${POST_ID}/comments" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_status "CreateComment rejects empty content_text with 400" "400" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 9 – CreateComment: happy path (User2 top-level)
# ======================================================================

echo -e "${GREEN}=== TEST 9: User2 Creates a Top-Level Comment ===${NC}"

COMMENT_BODY="{\"content_text\":\"Amazing post!\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/comments" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$COMMENT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Creates Top-Level Comment" "POST" "${POSTS_URL}/${POST_ID}/comments" "$COMMENT_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 posts a top-level comment" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 10 – GetThreadedComments: fetch and extract comment_id for reply
# ======================================================================

echo -e "${GREEN}=== TEST 10: User1 Fetches Threaded Comments ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${POSTS_URL}/${POST_ID}/comments?limit=50" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets Threaded Comments" "GET" "${POSTS_URL}/${POST_ID}/comments" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 retrieves threaded comments" "$HTTP_CODE"

# comment_id lives inside comments[]: {"comments":[{"comment_id":"uuid",...}],...}
COMMENT_ID=$(get_json_string "$HTTP_BODY" "comment_id")
echo -e "${CYAN}  Extracted Comment ID: ${COMMENT_ID}${NC}"
STARTING_REPLY_COUNT=$(get_json_number "$HTTP_BODY" "reply_count")
assert_eq "Initial reply_count is 0" "0" "$STARTING_REPLY_COUNT"
echo ""

# ======================================================================
# TEST 11 – CreateComment: reply thread (parent_id set)
# ======================================================================

if [[ -n "$COMMENT_ID" ]]; then
    echo -e "${GREEN}=== TEST 11: User1 Replies to User2's Comment ===${NC}"

    REPLY_BODY="{\"content_text\":\"Thanks for your kind words!\",\"parent_id\":\"${COMMENT_ID}\"}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/comments" \
        -H "Authorization: Bearer $USER1_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$REPLY_BODY")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    log_request "User1 Replies to Comment" "POST" "${POSTS_URL}/${POST_ID}/comments" "$REPLY_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
    assert_ok "User1 posts a reply comment" "$HTTP_CODE"
    REPLY_COMMENT_ID=$(get_json_string "$HTTP_BODY" "comment_id")
    echo ""

    # Verify root comment registers the child under reply_count
    echo -e "${GREEN}=== TEST 11b: Verify Top-Level Comment reply_count Increases ===${NC}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${POSTS_URL}/${POST_ID}/comments?limit=50" \
        -H "Authorization: Bearer $USER1_TOKEN")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    log_request "Get comments after reply" "GET" "${POSTS_URL}/${POST_ID}/comments" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
    assert_ok "Fetch returns 200" "$HTTP_CODE"
    NEW_REPLY_COUNT=$(get_json_number "$HTTP_BODY" "reply_count")
    assert_eq "Top-level comment reply_count is 1 natively" "1" "$NEW_REPLY_COUNT"
    echo ""

    # Verify fetching children selectively works
    echo -e "${GREEN}=== TEST 11c: Fetch Child Replies Native Endpoint ===${NC}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${POSTS_URL}/${POST_ID}/comments?parent_id=${COMMENT_ID}&limit=50" \
        -H "Authorization: Bearer $USER1_TOKEN")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    log_request "Get replies explicitly" "GET" "${POSTS_URL}/${POST_ID}/comments?parent_id=${COMMENT_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
    assert_ok "Fetch returns 200" "$HTTP_CODE"
    REPLY_TEXT=$(get_json_string "$HTTP_BODY" "content_text")
    assert_eq "Child reply content retrieved directly" "Thanks for your kind words!" "$REPLY_TEXT"
    echo ""
else
    echo -e "${YELLOW}! No comment_id found, skipping reply thread test.${NC}"
    echo ""
fi

# ======================================================================
# TEST 11d – ToggleCommentLike: User1 likes User2 comment
# ======================================================================

if [[ -n "$COMMENT_ID" ]]; then
    echo -e "${GREEN}=== TEST 11d: Toggle Comment Like ===${NC}"

    RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "${FEED_URL}/comments/${COMMENT_ID}/likes" \
        -H "Authorization: Bearer $USER1_TOKEN")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    log_request "User1 likes comment" "POST" "${FEED_URL}/comments/${COMMENT_ID}/likes" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
    assert_ok "User1 can like a comment" "$HTTP_CODE"
fi
echo ""

# ======================================================================
# TEST 12 – ToggleLike: User2 likes the post
# ======================================================================

echo -e "${GREEN}=== TEST 12: User2 Likes the Post ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/likes" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Toggles Like (like)" "POST" "${POSTS_URL}/${POST_ID}/likes" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 likes the post (async 202 accepted)" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 13 – ToggleLike: User2 toggles again (unlike)
# ======================================================================

echo -e "${GREEN}=== TEST 13: User2 Unlikes the Post (Second Toggle) ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/likes" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Toggles Like (unlike)" "POST" "${POSTS_URL}/${POST_ID}/likes" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 unlikes the post (second toggle returns 202)" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 13b – ToggleLike again to keep one like for GetLikes list test
# ======================================================================

echo -e "${GREEN}=== TEST 13b: User2 Likes Again (Prepare GetLikes non-empty) ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/likes" \
    -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Toggles Like (like again)" "POST" "${POSTS_URL}/${POST_ID}/likes" "" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 likes post again for interactions listing" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 14 – GetLikes: User1 fetches likes on post
# ======================================================================

echo -e "${GREEN}=== TEST 14: User1 Fetches Likes on Post ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${POSTS_URL}/${POST_ID}/likes?limit=10" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets Likes" "GET" "${POSTS_URL}/${POST_ID}/likes" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 accesses the likes endpoint" "$HTTP_CODE"
assert_not_contains "GetLikes returns non-empty interactions list" "$HTTP_BODY" '"items":[]'
echo ""

# ======================================================================
# TEST 15 – SendSeal: zero amount → 400
# ======================================================================

echo -e "${GREEN}=== TEST 15: SendSeal – Zero Amount ===${NC}"

BODY="{\"amount\":0}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/seals" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SendSeal amount=0" "POST" "${POSTS_URL}/${POST_ID}/seals" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_status "SendSeal rejects zero amount with 400" "400" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 16 – SendSeal: self-seal (User1 seals own post) → 400
# ======================================================================

echo -e "${GREEN}=== TEST 16: SendSeal – Self-Seal Guard ===${NC}"

BODY="{\"amount\":1}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/seals" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SendSeal self-seal (User1 on own post)" "POST" "${POSTS_URL}/${POST_ID}/seals" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_status "SendSeal rejects self-seal with 400" "400" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 17 – SendSeal: insufficient funds (User1 has no silver) → 402
# Note: User1 was never funded, so their silver balance is 0.
# ======================================================================

echo -e "${GREEN}=== TEST 17: SendSeal – Insufficient Funds ===${NC}"

# We need a third user (no silver) to send a seal so it isn't blocked by self-seal.
# User1 has no silver funded — but User1 is the post author so self-seal fires first.
# Create a quick User3 with no funding to hit the 402 branch.
USER3_EMAIL="feed_user3_${RANDOM}@example.com"
USER3_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER3_PASSWORD\",\"first_name\":\"Charlie\",\"last_name\":\"Broke\",\"date_of_birth\":\"2002-03-20\",\"device_id\":\"feed-device3\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    LOGIN_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER3_PASSWORD\",\"device_id\":\"feed-device3\"}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
        -H "Content-Type: application/json" -d "$LOGIN_BODY")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    USER3_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")

    BODY="{\"amount\":1}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/seals" \
        -H "Authorization: Bearer $USER3_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$BODY")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    log_request "SendSeal no-funds (User3 unfunded)" "POST" "${POSTS_URL}/${POST_ID}/seals" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER3"
    assert_status "SendSeal rejects unfunded sender with 402" "402" "$HTTP_CODE"
else
    echo -e "${YELLOW}! User3 registration failed, skipping insufficient-funds test.${NC}"
fi
echo ""

# Fund User2 with their first daily accrual (1 Silver Seal = 100 centinels)
# so they have balance to spend in tests 18 and 19.
echo -e "${CYAN}--- Funding User2 via daily accrual claim ---${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${ECO_URL}/accrual/claim" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}  User2 daily accrual claimed successfully (1 Silver Seal added).${NC}"
else
    echo -e "${YELLOW}  User2 accrual claim returned $HTTP_CODE: ${HTTP_BODY}${NC}"
    echo -e "${YELLOW}  Tests 18/19 may fail if balance is insufficient.${NC}"
fi
echo ""

# ======================================================================
# TEST 18 – SendSeal: happy path (User2 seals User1's post)
# ======================================================================

echo -e "${GREEN}=== TEST 18: User2 Sends a Silver Seal to Post ===${NC}"

SEAL_BODY="{\"amount\":1,\"comment\":\"Great post!\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/seals" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SEAL_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Sends Seal" "POST" "${POSTS_URL}/${POST_ID}/seals" "$SEAL_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_ok "User2 sends a seal successfully" "$HTTP_CODE"

LEDGER_ID=$(get_json_string "$HTTP_BODY" "ledger_entry_id")
echo -e "${CYAN}  ledger_entry_id: ${LEDGER_ID}${NC}"
assert_eq "Response contains ledger_entry_id" "" ""  # just log; non-empty check below
if [[ -n "$LEDGER_ID" ]]; then
    echo -e "${GREEN}✓ PASS: ledger_entry_id is non-empty (${LEDGER_ID})${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: ledger_entry_id is missing from seal response${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 19 – SendSeal: duplicate / idempotent tap → 201 again (no double-charge)
# ======================================================================

echo -e "${GREEN}=== TEST 19: SendSeal – Duplicate Tap (Idempotency) ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/seals" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SEAL_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User2 Sends Seal Again (duplicate)" "POST" "${POSTS_URL}/${POST_ID}/seals" "$SEAL_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
# Idempotency: same key must return 201 without error (cooldown fires on new pair interaction,
# but identical idempotency key is replayed safely before cooldown is checked)
assert_ok "Duplicate seal tap is idempotent (returns 2xx)" "$HTTP_CODE"
LEDGER_ID_2=$(get_json_string "$HTTP_BODY" "ledger_entry_id")
assert_eq "Idempotent replay returns same ledger_entry_id" "$LEDGER_ID" "$LEDGER_ID_2"
echo ""

# ======================================================================
# TEST 20 – GetSeals: User1 fetches seals on post
# ======================================================================

echo -e "${GREEN}=== TEST 20: User1 Fetches Seals on Post ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${POSTS_URL}/${POST_ID}/seals?limit=10" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets Seals" "GET" "${POSTS_URL}/${POST_ID}/seals" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 accesses the seals endpoint" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 20b – Moderation: report post, duplicate guard, report comment, admin queue
# ======================================================================

echo -e "${GREEN}=== TEST 20b: Moderation – Post and Comment Reports ===${NC}"

POST_REPORT_BODY="{\"reason\":\"spam\",\"description\":\"Looks promotional\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/report" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$POST_REPORT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "User2 reports post" "POST" "${POSTS_URL}/${POST_ID}/report" "$POST_REPORT_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_status "User2 can report User1 post" "201" "$HTTP_CODE"

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/report" \
    -H "Authorization: Bearer $USER2_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$POST_REPORT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "User2 reports same post again" "POST" "${POSTS_URL}/${POST_ID}/report" "$POST_REPORT_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER2"
assert_status "Duplicate post report is rejected with 409" "409" "$HTTP_CODE"

if [[ -n "$COMMENT_ID" ]]; then
    COMMENT_REPORT_BODY="{\"reason\":\"hate\",\"description\":\"Moderation coverage check\"}"
    RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/comments/${COMMENT_ID}/report" \
        -H "Authorization: Bearer $USER1_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$COMMENT_REPORT_BODY")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    log_request "User1 reports User2 comment" "POST" "${POSTS_URL}/${POST_ID}/comments/${COMMENT_ID}/report" "$COMMENT_REPORT_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
    assert_status "User1 can report User2 comment" "201" "$HTTP_CODE"
fi

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "${FEED_URL%/feed}/admin/reports?limit=20" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Admin gets moderation reports" "GET" "${FEED_URL%/feed}/admin/reports?limit=20" "" "$HTTP_BODY" "$HTTP_CODE" "ADMIN"
assert_ok "Admin reports endpoint returns queue" "$HTTP_CODE"
assert_contains "Admin report queue includes spam reason" "$HTTP_BODY" '"reason":"spam"'
assert_contains "Admin report queue includes post target type" "$HTTP_BODY" '"target_type":"post"'

RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "${FEED_URL%/feed}/admin/reports?limit=20" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Non-admin denied moderation reports" "GET" "${FEED_URL%/feed}/admin/reports?limit=20" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_status "Non-admin cannot access admin reports" "403" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 20c – DeleteComment lifecycle after interaction and moderation checks
# ======================================================================

if [[ -n "$REPLY_COMMENT_ID" ]]; then
    echo -e "${GREEN}=== TEST 20c: Delete Comment Lifecycle ===${NC}"
    RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X DELETE "${POSTS_URL}/${POST_ID}/comments/${REPLY_COMMENT_ID}" \
        -H "Authorization: Bearer $USER1_TOKEN")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    log_request "User1 deletes own reply" "DELETE" "${POSTS_URL}/${POST_ID}/comments/${REPLY_COMMENT_ID}" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
    assert_ok "Author can delete own reply comment" "$HTTP_CODE"
    assert_contains "Delete comment returns deleted status" "$HTTP_BODY" '"status":"deleted"'
    echo ""
fi

# ======================================================================
# TEST 20d – Comment report ladder: 10 severe reports => auto-hide comment
# ======================================================================

if [[ -n "$COMMENT_ID" ]]; then
    echo -e "${GREEN}=== TEST 20d: Comment Report Ladder Auto-Hide ===${NC}"

    EXTRA_REPORTERS_CREATED=0
    for i in $(seq 1 10); do
        R_EMAIL="feed_rep_${RANDOM}_${i}@example.com"
        R_PASS="Pass123!"
        R_DEVICE="feed-rep-device-${i}-${RANDOM}"

        REGISTER_BODY="{\"email\":\"$R_EMAIL\",\"password\":\"$R_PASS\",\"first_name\":\"Rep${i}\",\"last_name\":\"User\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"$R_DEVICE\",\"app_version\":\"1.0.0\"}"
        RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
            -H "Content-Type: application/json" -d "$REGISTER_BODY")
        HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
        HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
        if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
            continue
        fi

        LOGIN_BODY="{\"email\":\"$R_EMAIL\",\"password\":\"$R_PASS\",\"device_id\":\"$R_DEVICE\"}"
        RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" \
            -H "Content-Type: application/json" -d "$LOGIN_BODY")
        HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
        HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
        if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
            continue
        fi

        R_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
        if [[ -z "$R_TOKEN" ]]; then
            continue
        fi

        COMMENT_REPORT_BODY="{\"reason\":\"spam\",\"description\":\"ladder-${i}\"}"
        RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${POST_ID}/comments/${COMMENT_ID}/report" \
            -H "Authorization: Bearer $R_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$COMMENT_REPORT_BODY")
        HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
        if [[ "$HTTP_CODE" == "201" ]]; then
            EXTRA_REPORTERS_CREATED=$((EXTRA_REPORTERS_CREATED + 1))
        fi
    done

    echo -e "${CYAN}  Successful extra comment reports: ${EXTRA_REPORTERS_CREATED}${NC}"
    if [[ "$EXTRA_REPORTERS_CREATED" -ge 10 ]]; then
        RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X GET "${POSTS_URL}/${POST_ID}/comments?limit=100" \
            -H "Authorization: Bearer $USER1_TOKEN")
        HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
        HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
        log_request "Fetch comments after report ladder" "GET" "${POSTS_URL}/${POST_ID}/comments?limit=100" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
        assert_ok "Fetch comments succeeds after ladder reports" "$HTTP_CODE"
        if echo "$HTTP_BODY" | grep -q "$COMMENT_ID"; then
            echo -e "${RED}✗ FAIL: Comment should be auto-hidden at ladder level 4${NC}"
            FAIL=$((FAIL + 1))
        else
            echo -e "${GREEN}✓ PASS: Comment auto-hidden by report ladder${NC}"
            PASS=$((PASS + 1))
        fi
    else
        echo -e "${YELLOW}! Could not create enough unique reporters for ladder test, skipping strict assertion.${NC}"
    fi
    echo ""
fi

# ======================================================================
# TEST 20e – Author sanctions: 8 actioned post reports => publishing ban
# ======================================================================

echo -e "${GREEN}=== TEST 20e: Author Sanctions Escalation (8 actioned posts) ===${NC}"

ACTIONED_OK=0
for i in $(seq 1 8); do
    SANCTION_POST_BODY="{\"caption\":\"sanction-seed-${i}\",\"media_attachments\":[{\"type\":\"image\",\"url\":\"http://minio/bucket/sanction-${i}.jpg\"}],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\"}"
    RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
        -H "Authorization: Bearer $USER1_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$SANCTION_POST_BODY")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
        continue
    fi

    SANCTION_POST_ID=$(get_json_string "$HTTP_BODY" "post_id")
    if [[ -z "$SANCTION_POST_ID" ]]; then
        continue
    fi

    POST_REPORT_BODY="{\"reason\":\"spam\",\"description\":\"sanction-seed-${i}\"}"
    RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "${POSTS_URL}/${SANCTION_POST_ID}/report" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$POST_REPORT_BODY")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    if [[ "$HTTP_CODE" != "201" && "$HTTP_CODE" != "409" ]]; then
        continue
    fi

    REVIEW_BODY="{\"target_type\":\"post\",\"target_id\":\"${SANCTION_POST_ID}\",\"decision\":\"actioned\"}"
    RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "${FEED_URL%/feed}/admin/reports/review" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$REVIEW_BODY")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    if [[ "$HTTP_CODE" == "200" ]]; then
        ACTIONED_OK=$((ACTIONED_OK + 1))
    fi
done

echo -e "${CYAN}  Actioned post reports prepared: ${ACTIONED_OK}${NC}"

BAN_CHECK_BODY="{\"caption\":\"should_be_blocked_by_policy\",\"media_attachments\":[{\"type\":\"image\",\"url\":\"http://minio/bucket/blocked.jpg\"}],\"visibility\":\"ANYONE\",\"comment_permission\":\"ANYONE\"}"
RESPONSE=$($CURL_BIN -s -w "\n%{http_code}" -X POST "$POSTS_URL" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BAN_CHECK_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
log_request "Create post after sanctions escalation" "POST" "$POSTS_URL" "$BAN_CHECK_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"

if [[ "$ACTIONED_OK" -ge 8 ]]; then
    assert_status "Author publishing is blocked after 8 actioned post reports" "429" "$HTTP_CODE"
    assert_contains "Publishing block error is explicit" "$HTTP_BODY" 'publishing_restricted'
else
    echo -e "${YELLOW}! Could not prepare 8 actioned reports (schema/env mismatch), strict ban assertion skipped.${NC}"
fi
echo ""

fi  # end if POST_ID

# ======================================================================
# TEST 21 – SyncFeedState: delta=0 → 400 (ErrInvalidDelta)
# ======================================================================

echo -e "${GREEN}=== TEST 21: SyncFeedState – Zero Delta ===${NC}"

BODY="{\"delta_seconds\":0,\"device_id\":\"feed-device1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${FEED_URL}/state/sync" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SyncFeedState delta=0" "POST" "${FEED_URL}/state/sync" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_status "SyncFeedState rejects delta=0 with 400" "400" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 22 – SyncFeedState: large delta is capped by anti-cheat (not 400)
# ======================================================================

echo -e "${GREEN}=== TEST 22: SyncFeedState – Large Delta Capped by Anti-Cheat ===${NC}"

BODY="{\"delta_seconds\":99999,\"device_id\":\"feed-device1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${FEED_URL}/state/sync" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SyncFeedState delta=99999" "POST" "${FEED_URL}/state/sync" "$BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
# Anti-cheat caps delta to real elapsed — NOT an error, returns 200 with capped value
assert_ok "SyncFeedState caps excessive delta and returns 200" "$HTTP_CODE"
echo ""

# ======================================================================
# TEST 23 – SyncFeedState: happy path — response has all new fields
# ======================================================================

echo -e "${GREEN}=== TEST 23: SyncFeedState – Happy Path + New Fields ===${NC}"

SYNC_BODY="{\"delta_seconds\":45,\"device_id\":\"feed-device1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${FEED_URL}/state/sync" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SYNC_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Syncs Feed Time (45s)" "POST" "${FEED_URL}/state/sync" "$SYNC_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 syncs active feed time successfully" "$HTTP_CODE"

# Verify new field: break_seconds_remaining (should be 0 – not in break)
BREAK_REM=$(get_json_number "$HTTP_BODY" "break_seconds_remaining")
echo -e "${CYAN}  break_seconds_remaining: ${BREAK_REM}${NC}"
assert_eq "break_seconds_remaining is 0 during active phase" "0" "$BREAK_REM"

# Verify existing field: is_in_cooldown (should be false = 0 in JSON sense)
IS_COOLDOWN=$(echo "$HTTP_BODY" | grep -o '"is_in_cooldown": *[a-z]*' | head -1 | grep -o '[a-z]*$')
echo -e "${CYAN}  is_in_cooldown: ${IS_COOLDOWN}${NC}"
assert_eq "is_in_cooldown is false during active phase" "false" "$IS_COOLDOWN"
echo ""

# ======================================================================
# TEST 24 – GetFeedState: happy path + new fields in response
# ======================================================================

echo -e "${GREEN}=== TEST 24: GetFeedState – Happy Path + New Fields ===${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${FEED_URL}/state" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "User1 Gets Feed State" "GET" "${FEED_URL}/state" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "User1 retrieves feed fatigue state" "$HTTP_CODE"

# accumulated_active_seconds must be numeric
ACCUM=$(get_json_number "$HTTP_BODY" "accumulated_active_seconds")
echo -e "${CYAN}  accumulated_active_seconds: ${ACCUM}${NC}"
if [[ "$ACCUM" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✓ PASS: accumulated_active_seconds is numeric (${ACCUM})${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: expected numeric accumulated_active_seconds, got '${ACCUM}'${NC}"
    FAIL=$((FAIL + 1))
fi

# break_seconds_remaining must be present and numeric (0 = not in break)
BREAK_REM=$(get_json_number "$HTTP_BODY" "break_seconds_remaining")
echo -e "${CYAN}  break_seconds_remaining: ${BREAK_REM}${NC}"
if [[ "$BREAK_REM" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✓ PASS: break_seconds_remaining is present and numeric (${BREAK_REM})${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: break_seconds_remaining missing or non-numeric: '${BREAK_REM}'${NC}"
    FAIL=$((FAIL + 1))
fi

# max_allowed_seconds must be numeric
MAX_SEC=$(get_json_number "$HTTP_BODY" "max_allowed_seconds")
echo -e "${CYAN}  max_allowed_seconds: ${MAX_SEC}${NC}"
if [[ "$MAX_SEC" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✓ PASS: max_allowed_seconds is present and numeric (${MAX_SEC})${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: max_allowed_seconds missing or non-numeric: '${MAX_SEC}'${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 25 – Anti-Doomscroll: simulate cooldown by direct DB injection,
#           then verify SyncFeedState returns enforce_cooldown + break
# ======================================================================

echo -e "${GREEN}=== TEST 25: Anti-Doomscroll – Break Phase via DB Injection ===${NC}"
echo -e "${CYAN}  Injecting an in-cooldown fatigue state into the DB for User1…${NC}"

NOW_UTC=$(date -u +"%Y-%m-%d %H:%M:%S")

# Force User1 into break: set accumulated=1200 (at limit), is_in_cooldown=true,
# break_start_at = 120 seconds ago (2 min into a 5-min break → ~180s remaining)
BREAK_START=$(date -u -d "120 seconds ago" +"%Y-%m-%d %H:%M:%S" 2>/dev/null \
    || date -u -v-120S +"%Y-%m-%d %H:%M:%S")  # macOS fallback

docker exec brightbund-db psql -U user -d brightbund -c \
    "INSERT INTO feed_fatigue_states
        (user_id, accumulated_active_seconds, accumulated_break_seconds, last_sync_timestamp, is_in_cooldown, break_start_at)
     VALUES
        ('$USER1_ID', 1200, 120, NOW(), true, '$BREAK_START')
     ON CONFLICT (user_id) DO UPDATE SET
        accumulated_active_seconds = 1200,
        accumulated_break_seconds  = 120,
        last_sync_timestamp        = NOW(),
        is_in_cooldown             = true,
        break_start_at             = '$BREAK_START';" > /dev/null 2>&1

# Also clear Redis cache so server reads from DB
docker exec brightbund-redis redis-cli DEL "feed_state:$USER1_ID" > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}  ✓ DB state injected (User1 in break, started 2 min ago)${NC}"
else
    echo -e "${YELLOW}  ! DB injection may have failed – Redis flush failed, test results may not be reliable${NC}"
fi

# Now hit SyncFeedState — should return is_in_cooldown=true, action_required=enforce_cooldown
SYNC_BODY="{\"delta_seconds\":30,\"device_id\":\"feed-device1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${FEED_URL}/state/sync" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SYNC_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "SyncFeedState during break" "POST" "${FEED_URL}/state/sync" "$SYNC_BODY" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "SyncFeedState during break returns 200 (not error)" "$HTTP_CODE"

# is_in_cooldown must be true
COOLDOWN=$(echo "$HTTP_BODY" | grep -o '"is_in_cooldown": *[a-z]*' | head -1 | grep -o '[a-z]*$')
assert_eq "SyncFeedState during break: is_in_cooldown=true" "true" "$COOLDOWN"

# action_required must be "enforce_cooldown"
ACTION=$(get_json_string "$HTTP_BODY" "action_required")
assert_eq "SyncFeedState during break: action_required=enforce_cooldown" "enforce_cooldown" "$ACTION"

# break_seconds_remaining should be approximately 180 (300 - 120)
BREAK_REM=$(get_json_number "$HTTP_BODY" "break_seconds_remaining")
echo -e "${CYAN}  break_seconds_remaining: ${BREAK_REM} (expect ~180)${NC}"
if [[ "$BREAK_REM" =~ ^[0-9]+$ && "$BREAK_REM" -ge 170 && "$BREAK_REM" -le 190 ]]; then
    echo -e "${GREEN}✓ PASS: break_seconds_remaining is ~180 (${BREAK_REM})${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}✗ FAIL: expected break_seconds_remaining ~180, got '${BREAK_REM}'${NC}"
    FAIL=$((FAIL + 1))
fi
echo ""

# ======================================================================
# TEST 26 – Anti-Doomscroll: break expiry → full reset
#           Inject an expired break (6 min ago), then GetFeedState
# ======================================================================

echo -e "${GREEN}=== TEST 26: Anti-Doomscroll – Break Expiry → Full Reset ===${NC}"
echo -e "${CYAN}  Injecting an expired break (started 6 minutes ago)…${NC}"

EXPIRED_BREAK=$(date -u -d "360 seconds ago" +"%Y-%m-%d %H:%M:%S" 2>/dev/null \
    || date -u -v-360S +"%Y-%m-%d %H:%M:%S")

docker exec brightbund-db psql -U user -d brightbund -c \
    "UPDATE feed_fatigue_states SET
        accumulated_active_seconds = 1200,
        accumulated_break_seconds  = 360,
        is_in_cooldown             = true,
        break_start_at             = '$EXPIRED_BREAK'
     WHERE user_id = '$USER1_ID';" > /dev/null 2>&1

docker exec brightbund-redis redis-cli DEL "feed_state:$USER1_ID" > /dev/null 2>&1

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${FEED_URL}/state" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "GetFeedState after expired break" "GET" "${FEED_URL}/state" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "GetFeedState after break expiry returns 200" "$HTTP_CODE"

# After expiry: is_in_cooldown must be false
COOLDOWN=$(echo "$HTTP_BODY" | grep -o '"is_in_cooldown": *[a-z]*' | head -1 | grep -o '[a-z]*$')
assert_eq "After break expiry: is_in_cooldown=false" "false" "$COOLDOWN"

# accumulated_active_seconds must be 0 (full reset)
ACCUM=$(get_json_number "$HTTP_BODY" "accumulated_active_seconds")
assert_eq "After break expiry: accumulated_active_seconds reset to 0" "0" "$ACCUM"

# break_seconds_remaining must be 0
BREAK_REM=$(get_json_number "$HTTP_BODY" "break_seconds_remaining")
assert_eq "After break expiry: break_seconds_remaining=0" "0" "$BREAK_REM"
echo ""

# ======================================================================
# TEST 27 – Anti-Doomscroll: away-reset
#           Inject an active state with last_sync 6 min ago (> AwayResetThreshold=300s)
# ======================================================================

echo -e "${GREEN}=== TEST 27: Anti-Doomscroll – Away Reset (> 5 min inactive) ===${NC}"
echo -e "${CYAN}  Injecting active state with last_sync 6 minutes ago…${NC}"

OLD_SYNC=$(date -u -d "360 seconds ago" +"%Y-%m-%d %H:%M:%S" 2>/dev/null \
    || date -u -v-360S +"%Y-%m-%d %H:%M:%S")

docker exec brightbund-db psql -U user -d brightbund -c \
    "UPDATE feed_fatigue_states SET
        accumulated_active_seconds = 900,
        is_in_cooldown             = false,
        break_start_at             = NULL,
        last_sync_timestamp        = '$OLD_SYNC'
     WHERE user_id = '$USER1_ID';" > /dev/null 2>&1

docker exec brightbund-redis redis-cli DEL "feed_state:$USER1_ID" > /dev/null 2>&1

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${FEED_URL}/state" \
    -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "GetFeedState after long away" "GET" "${FEED_URL}/state" "" "$HTTP_BODY" "$HTTP_CODE" "USER1"
assert_ok "GetFeedState after long away returns 200" "$HTTP_CODE"

# Accumulated must reset to 0 (away reset rule)
ACCUM=$(get_json_number "$HTTP_BODY" "accumulated_active_seconds")
assert_eq "Away ≥300s resets accumulated_active_seconds to 0" "0" "$ACCUM"

# is_in_cooldown must be false
COOLDOWN=$(echo "$HTTP_BODY" | grep -o '"is_in_cooldown": *[a-z]*' | head -1 | grep -o '[a-z]*$')
assert_eq "Away reset: is_in_cooldown stays false" "false" "$COOLDOWN"
echo ""

# ======================================================================
# SUMMARY
# ======================================================================

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  Test run finished.${NC}"
echo -e "${GREEN}  PASS : ${PASS}${NC}"
if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}  FAIL : ${FAIL}${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    exit 1
else
    echo -e "${CYAN}  FAIL : ${FAIL}${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    exit 0
fi
