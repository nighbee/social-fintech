#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

AUTH_URL="http://localhost:8081/api/v1/auth"
PROFILE_URL="http://localhost:8081/api/v1/profiles"

# Helper functions
get_json_string() {
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_json_number() {
    echo "$1" | grep -o "\"$2\": *[0-9.]*" | head -1 | grep -o "[0-9.]*"
}

get_json_bool() {
    echo "$1" | grep -o "\"$2\": *[a-z]*" | head -1 | awk -F': ' '{print $2}' | tr -d ' '
}

pretty_json() {
    echo "$1" | python3 -m json.tool 2>/dev/null || echo "$1"
}

log_request() {
    local test_name="$1"
    local method="$2"
    local url="$3"
    local body="$4"
    local response_body="$5"
    local http_code="$6"
    local auth_header="$7"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}REQUEST:${NC}"
    echo -e "  Method: ${CYAN}$method${NC}"
    echo -e "  URL: ${CYAN}$url${NC}"
    if [[ -n "$auth_header" ]]; then
        echo -e "  Auth: ${CYAN}$auth_header${NC}"
    fi
    if [[ -n "$body" ]]; then
        echo -e "  Body:"
        pretty_json "$body" | sed 's/^/    /'
    fi
    echo ""
    echo -e "${YELLOW}RESPONSE:${NC}"
    echo -e "  HTTP Status: ${CYAN}$http_code${NC}"
    if [[ -n "$response_body" ]]; then
        echo -e "  Body:"
        pretty_json "$response_body" | sed 's/^/    /'
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}   Profile Module Test Suite${NC}"
echo -e "${CYAN}======================================${NC}\n"

# SETUP: Create Test Users

echo -e "${GREEN}=== SETUP: Creating Test Users ===${NC}"

# User 1 (Main test user)
USER1_EMAIL="prof_user1_${RANDOM}@example.com"
USER1_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"first_name\":\"Alice\",\"last_name\":\"Smith\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"device1\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    USER1_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ User 1 created: $USER1_ID${NC}"
else
    echo -e "${RED}✗ User 1 creation failed: HTTP $HTTP_CODE${NC}"
    log_request "User 1 Registration" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"
    exit 1
fi

# Login User 1
LOGIN_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"device_id\":\"device1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER1_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ User 1 logged in${NC}"

# User 2 (Observer)
USER2_EMAIL="prof_user2_${RANDOM}@example.com"
USER2_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"first_name\":\"Bob\",\"last_name\":\"Jones\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"device2\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER2_ID=$(get_json_string "$HTTP_BODY" "id")
echo -e "${GREEN}✓ User 2 created: $USER2_ID${NC}"

# Login User 2
LOGIN_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"device_id\":\"device2\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER2_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ User 2 logged in${NC}"

echo ""

# TEST 1: Get My Profile (Should auto-create)
echo -e "${GREEN}=== TEST 1: Get My Profile (Auto-create) ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 1" "GET" "$PROFILE_URL/me" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get profile successful${NC}"
    DISPLAY_NAME=$(get_json_string "$HTTP_BODY" "display_name")
    FIRST_NAME=$(get_json_string "$HTTP_BODY" "first_name")
    LAST_NAME=$(get_json_string "$HTTP_BODY" "last_name")
    DOB=$(get_json_string "$HTTP_BODY" "date_of_birth")
    IS_PUBLIC=$(get_json_bool "$HTTP_BODY" "is_public")
    echo -e "${CYAN}  Display Name: $DISPLAY_NAME${NC}"
    echo -e "${CYAN}  First Name: $FIRST_NAME${NC}"
    echo -e "${CYAN}  Last Name: $LAST_NAME${NC}"
    echo -e "${CYAN}  DOB: $DOB${NC}"
    echo -e "${CYAN}  Is Public: $IS_PUBLIC${NC}"
else
    echo -e "${RED}✗ Get profile failed: HTTP $HTTP_CODE${NC}"
    exit 1
fi

echo ""

# TEST 2: Update Profile
echo -e "${GREEN}=== TEST 2: Update Profile ===${NC}"
UPDATE_BODY="{\"first_name\":\"Alice\",\"last_name\":\"Wonderland\",\"bio\":\"Explorer\",\"is_public\":true}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "$PROFILE_URL/me" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 2" "PATCH" "$PROFILE_URL/me" "$UPDATE_BODY" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Update profile successful${NC}"
    BIO=$(get_json_string "$HTTP_BODY" "bio")
    DISPLAY_NAME=$(get_json_string "$HTTP_BODY" "display_name")
    FIRST_NAME=$(get_json_string "$HTTP_BODY" "first_name")
    LAST_NAME=$(get_json_string "$HTTP_BODY" "last_name")
    echo -e "${CYAN}  Display Name: $DISPLAY_NAME${NC}"
    echo -e "${CYAN}  First Name: $FIRST_NAME${NC}"
    echo -e "${CYAN}  Last Name: $LAST_NAME${NC}"
    echo -e "${CYAN}  Bio: $BIO${NC}"
else
    echo -e "${RED}✗ Update profile failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 3: Get Public Profile (User 2 views User 1)
echo -e "${GREEN}=== TEST 3: Get Public Profile (User 2 -> User 1) ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USER1_ID" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 3" "GET" "$PROFILE_URL/$USER1_ID" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER2_TOKEN"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Public profile view successful${NC}"
    DISPLAY_NAME=$(get_json_string "$HTTP_BODY" "display_name")
    BIO=$(get_json_string "$HTTP_BODY" "bio")
    echo -e "${CYAN}  Viewed User: $USER1_ID${NC}"
    echo -e "${CYAN}  Display Name: $DISPLAY_NAME${NC}"
    echo -e "${CYAN}  Bio: $BIO${NC}"
else
    echo -e "${RED}✗ Public profile view failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 4: Get Stats
echo -e "${GREEN}=== TEST 4: Get My Stats ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me/stats" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 4" "GET" "$PROFILE_URL/me/stats" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Stats retrieval successful${NC}"
    SILVER=$(get_json_number "$HTTP_BODY" "silver_balance")
    GOLD=$(get_json_number "$HTTP_BODY" "gold_balance")
    SENT=$(get_json_number "$HTTP_BODY" "total_sent")
    RECEIVED=$(get_json_number "$HTTP_BODY" "total_received")
    echo -e "${CYAN}  Silver Balance: $SILVER${NC}"
    echo -e "${CYAN}  Gold Balance: $GOLD${NC}"
    echo -e "${CYAN}  Total Sent: $SENT${NC}"
    echo -e "${CYAN}  Total Received: $RECEIVED${NC}"
else
    echo -e "${RED}✗ Stats retrieval failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 5: Set Private
echo -e "${GREEN}=== TEST 5: Set Profile Private ===${NC}"
UPDATE_BODY="{\"is_public\":false}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "$PROFILE_URL/me" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 5" "PATCH" "$PROFILE_URL/me" "$UPDATE_BODY" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Set private successful${NC}"
    IS_PUBLIC=$(get_json_bool "$HTTP_BODY" "is_public")
    echo -e "${CYAN}  Is Public: $IS_PUBLIC${NC}"
else
    echo -e "${RED}✗ Set private failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 6: Verify Privacy Block
echo -e "${GREEN}=== TEST 6: Verify Privacy (User 2 -> User 1 Denied) ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USER1_ID" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 6" "GET" "$PROFILE_URL/$USER1_ID" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER2_TOKEN"

if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ CORRECT: Access denied (HTTP 403)${NC}"
    ERROR_MSG=$(get_json_string "$HTTP_BODY" "error")
    echo -e "${CYAN}  Error Message: $ERROR_MSG${NC}"
else
    echo -e "${RED}✗ FAIL: Expected 403, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 7: Delete Profile
echo -e "${GREEN}=== TEST 7: Delete Profile ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$PROFILE_URL/me" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 7" "DELETE" "$PROFILE_URL/me" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -eq 204 ]]; then
    echo -e "${GREEN}✓ Profile deleted successfully${NC}"
else
    echo -e "${RED}✗ Delete profile failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 8: Verify Deletion (Public)
echo -e "${GREEN}=== TEST 8: Verify Deletion (Public View) ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USER1_ID" -H "Authorization: Bearer $USER2_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 8" "GET" "$PROFILE_URL/$USER1_ID" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER2_TOKEN"

if [[ "$HTTP_CODE" -eq 404 ]]; then
    echo -e "${GREEN}✓ CORRECT: Profile not found (HTTP 404)${NC}"
    ERROR_MSG=$(get_json_string "$HTTP_BODY" "error")
    echo -e "${CYAN}  Error Message: $ERROR_MSG${NC}"
else
    echo -e "${RED}✗ FAIL: Expected 404, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 9: Auto-Recreation
echo -e "${GREEN}=== TEST 9: Auto-Recreation after Deletion ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 9" "GET" "$PROFILE_URL/me" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Profile recreated successfully${NC}"
    DISPLAY_NAME=$(get_json_string "$HTTP_BODY" "display_name")
    IS_PUBLIC=$(get_json_bool "$HTTP_BODY" "is_public")
    echo -e "${CYAN}  Display Name: $DISPLAY_NAME${NC}"
    echo -e "${CYAN}  Is Public: $IS_PUBLIC${NC}"
else
    echo -e "${RED}✗ Recreation failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 10: Add Ally (User 1 adds User 2)
echo -e "${GREEN}=== TEST 10: Add Ally (User 1 -> User 2) ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/$USER2_ID/allies" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 10" "POST" "$PROFILE_URL/$USER2_ID/allies" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -eq 204 ]]; then
    echo -e "${GREEN}✓ Ally added successfully${NC}"
else
    echo -e "${RED}✗ Add ally failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 11: Get Allies (Check User 2's allies, should find User 1)
echo -e "${GREEN}=== TEST 11: Get Allies of User 2 ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USER2_ID/allies" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 11" "GET" "$PROFILE_URL/$USER2_ID/allies" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    # Check if array is not empty and contains User 1
    COUNT=$(echo "$HTTP_BODY" | grep -o "$USER1_ID" | wc -l)
    if [[ "$COUNT" -gt 0 ]]; then
        echo -e "${GREEN}✓ Allies list correct (Found User 1)${NC}"
    else
        echo -e "${RED}✗ User 1 NOT found in allies list${NC}"
    fi
else
    echo -e "${RED}✗ Get allies failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 12: Remove Ally (User 1 removes User 2)
echo -e "${GREEN}=== TEST 12: Remove Ally ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$PROFILE_URL/$USER2_ID/allies" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 12" "DELETE" "$PROFILE_URL/$USER2_ID/allies" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"

if [[ "$HTTP_CODE" -eq 204 ]]; then
    echo -e "${GREEN}✓ Ally removed successfully${NC}"
else
    echo -e "${RED}✗ Remove ally failed: HTTP $HTTP_CODE${NC}"
fi

	echo ""
	
	# TEST 13: Block User (User 1 blocks User 2)
	echo -e "${GREEN}=== TEST 13: Block User ===${NC}"
	RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/$USER2_ID/block" -H "Authorization: Bearer $USER1_TOKEN")
	HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
	HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
	
	log_request "TEST 13" "POST" "$PROFILE_URL/$USER2_ID/block" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"
	
	if [[ "$HTTP_CODE" -eq 204 ]]; then
		echo -e "${GREEN}✓ User blocked successfully${NC}"
	else
		echo -e "${RED}✗ Block user failed: HTTP $HTTP_CODE${NC}"
	fi
	
	echo ""
	
	# TEST 14: Unblock User
	echo -e "${GREEN}=== TEST 14: Unblock User ===${NC}"
	RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$PROFILE_URL/$USER2_ID/block" -H "Authorization: Bearer $USER1_TOKEN")
	HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
	HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
	
	log_request "TEST 14" "DELETE" "$PROFILE_URL/$USER2_ID/block" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"
	
	if [[ "$HTTP_CODE" -eq 204 ]]; then
		echo -e "${GREEN}✓ User unblocked successfully${NC}"
	else
		echo -e "${RED}✗ Unblock user failed: HTTP $HTTP_CODE${NC}"
	fi
	
	echo ""
	
	# TEST 15: Restrict User
	echo -e "${GREEN}=== TEST 15: Restrict User ===${NC}"
	RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/$USER2_ID/restrict" -H "Authorization: Bearer $USER1_TOKEN")
	HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
	HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
	
	log_request "TEST 15" "POST" "$PROFILE_URL/$USER2_ID/restrict" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"
	
	if [[ "$HTTP_CODE" -eq 204 ]]; then
		echo -e "${GREEN}✓ User restricted successfully${NC}"
	else
		echo -e "${RED}✗ Restrict user failed: HTTP $HTTP_CODE${NC}"
	fi
	
	echo ""
	
	# TEST 16: Unrestrict User
	echo -e "${GREEN}=== TEST 16: Unrestrict User ===${NC}"
	RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$PROFILE_URL/$USER2_ID/restrict" -H "Authorization: Bearer $USER1_TOKEN")
	HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
	HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
	
	log_request "TEST 16" "DELETE" "$PROFILE_URL/$USER2_ID/restrict" "" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"
	
	if [[ "$HTTP_CODE" -eq 204 ]]; then
		echo -e "${GREEN}✓ User unrestricted successfully${NC}"
	else
		echo -e "${RED}✗ Unrestrict user failed: HTTP $HTTP_CODE${NC}"
	fi
	
	echo ""
	
	# TEST 17: Report User (Valid)
	echo -e "${GREEN}=== TEST 17: Report User (Valid) ===${NC}"
	REPORT_BODY="{\"reason\":\"spam\",\"description\":\"Sending unwanted messages\"}"
	RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/$USER2_ID/report" \
		-H "Authorization: Bearer $USER1_TOKEN" \
		-H "Content-Type: application/json" \
		-d "$REPORT_BODY")
	HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
	HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
	
	log_request "TEST 17" "POST" "$PROFILE_URL/$USER2_ID/report" "$REPORT_BODY" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"
	
	if [[ "$HTTP_CODE" -eq 202 ]]; then
		echo -e "${GREEN}✓ Report submitted successfully${NC}"
	else
		echo -e "${RED}✗ Report failed: HTTP $HTTP_CODE${NC}"
	fi

	echo ""
	
	# TEST 18: Report User (Invalid Reason)
	echo -e "${GREEN}=== TEST 18: Report User (Invalid Reason) ===${NC}"
	REPORT_BODY="{\"reason\":\"invalid_reason\",\"description\":\"Should fail\"}"
	RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/$USER2_ID/report" \
		-H "Authorization: Bearer $USER1_TOKEN" \
		-H "Content-Type: application/json" \
		-d "$REPORT_BODY")
	HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
	HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
	
	log_request "TEST 18" "POST" "$PROFILE_URL/$USER2_ID/report" "$REPORT_BODY" "$HTTP_BODY" "$HTTP_CODE" "Bearer $USER1_TOKEN"
	
	if [[ "$HTTP_CODE" -eq 400 ]]; then
		echo -e "${GREEN}✓ Invalid report correctly rejected${NC}"
	else
		echo -e "${RED}✗ Expected 400 for invalid report, got $HTTP_CODE${NC}"
	fi

	echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${GREEN}✓ All Profile Tests Complete!${NC}"
	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

