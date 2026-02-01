#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

AUTH_URL="http://localhost:8081/api/v1/auth"
PROFILE_URL="http://localhost:8081/api/v1/profiles"

# --- Helper function to extract values from JSON using grep/sed ---
get_json_string() {
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_json_number() {
    echo "$1" | grep -o "\"$2\": *[0-9.]*" | head -1 | grep -o "[0-9.]*"
}

get_json_boolean() {
    echo "$1" | grep -o "\"$2\": *[a-z]*" | head -1 | grep -o "[a-z]*$"
}
# ------------------------------------------------------------------

echo -e "${CYAN}=== Profile Module Test Suite ===${NC}\n"

# Setup: Create three test users
echo -e "${GREEN}=== Setup: Creating Test Users ===${NC}"

# User 1 (Alice)
TEST_EMAIL_1="profileuser1_${RANDOM}@example.com"
TEST_PASSWORD="SecurePass123!"

REGISTER_BODY="{\"email\":\"$TEST_EMAIL_1\",\"password\":\"$TEST_PASSWORD\",\"first_name\":\"Alice\",\"last_name\":\"Smith\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"test-device-1\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ User 1 (Alice) created${NC}"
    USER_ID_1=$(get_json_string "$HTTP_BODY" "id")
    USERNAME_1=$(get_json_string "$HTTP_BODY" "username")
    echo "  User 1 ID: $USER_ID_1"
    echo "  Username: $USERNAME_1"
else
    echo -e "${RED}✗ User 1 creation failed: HTTP $HTTP_CODE${NC}"
    exit 1
fi

# Login User 1
LOGIN_BODY="{\"email\":\"$TEST_EMAIL_1\",\"password\":\"$TEST_PASSWORD\",\"device_id\":\"test-device-1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ACCESS_TOKEN_1=$(get_json_string "$HTTP_BODY" "access_token")
    echo -e "${GREEN}✓ User 1 logged in${NC}"
else
    echo -e "${RED}✗ User 1 login failed${NC}"
    exit 1
fi

# User 2 (Bob)
TEST_EMAIL_2="profileuser2_${RANDOM}@example.com"
REGISTER_BODY="{\"email\":\"$TEST_EMAIL_2\",\"password\":\"$TEST_PASSWORD\",\"first_name\":\"Bob\",\"last_name\":\"Jones\",\"date_of_birth\":\"1995-05-15\",\"device_id\":\"test-device-2\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ User 2 (Bob) created${NC}"
    USER_ID_2=$(get_json_string "$HTTP_BODY" "id")
    USERNAME_2=$(get_json_string "$HTTP_BODY" "username")
    echo "  User 2 ID: $USER_ID_2"
    echo "  Username: $USERNAME_2"
else
    echo -e "${RED}✗ User 2 creation failed${NC}"
    exit 1
fi

# Login User 2
LOGIN_BODY="{\"email\":\"$TEST_EMAIL_2\",\"password\":\"$TEST_PASSWORD\",\"device_id\":\"test-device-2\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ACCESS_TOKEN_2=$(get_json_string "$HTTP_BODY" "access_token")
    echo -e "${GREEN}✓ User 2 logged in${NC}"
else
    echo -e "${RED}✗ User 2 login failed${NC}"
    exit 1
fi

# User 3 (Charlie)
TEST_EMAIL_3="profileuser3_${RANDOM}@example.com"
REGISTER_BODY="{\"email\":\"$TEST_EMAIL_3\",\"password\":\"$TEST_PASSWORD\",\"first_name\":\"Charlie\",\"last_name\":\"Brown\",\"date_of_birth\":\"1998-08-20\",\"device_id\":\"test-device-3\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ User 3 (Charlie) created${NC}"
    USER_ID_3=$(get_json_string "$HTTP_BODY" "id")
    USERNAME_3=$(get_json_string "$HTTP_BODY" "username")
    echo "  User 3 ID: $USER_ID_3"
    echo "  Username: $USERNAME_3"
else
    echo -e "${RED}✗ User 3 creation failed${NC}"
    exit 1
fi

# Login User 3
LOGIN_BODY="{\"email\":\"$TEST_EMAIL_3\",\"password\":\"$TEST_PASSWORD\",\"device_id\":\"test-device-3\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ACCESS_TOKEN_3=$(get_json_string "$HTTP_BODY" "access_token")
    echo -e "${GREEN}✓ User 3 logged in${NC}"
else
    echo -e "${RED}✗ User 3 login failed${NC}"
    exit 1
fi

echo ""

# Test 1: Get Own Profile
echo -e "${GREEN}=== 1. Testing Get Own Profile ===${NC}"
echo -e "${CYAN}Request: GET $PROFILE_URL/me${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get own profile successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    DISPLAY_NAME=$(get_json_string "$HTTP_BODY" "display_name")
    RANK_TIER=$(get_json_string "$HTTP_BODY" "current_rank_tier")
    REP_SCORE=$(get_json_number "$HTTP_BODY" "reputation_score")
    echo "  Display Name: $DISPLAY_NAME"
    echo "  Rank Tier: $RANK_TIER"
    echo "  Reputation Score: $REP_SCORE"
else
    echo -e "${RED}✗ Get own profile failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 2: Update Profile
echo -e "${GREEN}=== 2. Testing Update Profile ===${NC}"
UPDATE_BODY="{\"display_name\":\"Alice The Great\",\"bio\":\"Software engineer and tech enthusiast. Love hiking and photography!\",\"location_city\":\"San Francisco\",\"location_country\":\"USA\",\"location_lat\":37.7749,\"location_lon\":-122.4194,\"is_location_public\":true,\"is_profile_public\":true}"
echo -e "${CYAN}Request: PUT $PROFILE_URL/me${NC}"
echo -e "${YELLOW}Request Body:${NC} $UPDATE_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$PROFILE_URL/me" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$UPDATE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Profile updated successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    DISPLAY_NAME=$(get_json_string "$HTTP_BODY" "display_name")
    BIO=$(get_json_string "$HTTP_BODY" "bio")
    LOCATION=$(get_json_string "$HTTP_BODY" "location")
    echo "  Display Name: $DISPLAY_NAME"
    echo "  Bio: $BIO"
    echo "  Location: $LOCATION"
else
    echo -e "${RED}✗ Profile update failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 3: Get Profile by Username
echo -e "${GREEN}=== 3. Testing Get Profile by Username ===${NC}"
echo -e "${CYAN}Request: GET $PROFILE_URL/$USERNAME_1${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USERNAME_1" -H "Authorization: Bearer $ACCESS_TOKEN_2")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get profile by username successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    USERNAME=$(get_json_string "$HTTP_BODY" "username")
    DISPLAY_NAME=$(get_json_string "$HTTP_BODY" "display_name")
    echo "  Username: $USERNAME"
    echo "  Display Name: $DISPLAY_NAME"
else
    echo -e "${RED}✗ Get profile by username failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 4: Update User 2 Profile (for search testing)
echo -e "${GREEN}=== 4. Setting Up User 2 Profile for Search ===${NC}"
UPDATE_BODY="{\"display_name\":\"Bob The Builder\",\"bio\":\"Construction and engineering professional\",\"location_city\":\"San Francisco\",\"location_country\":\"USA\",\"location_lat\":37.7849,\"location_lon\":-122.4094,\"is_location_public\":true,\"is_profile_public\":true}"
echo -e "${CYAN}Request: PUT $PROFILE_URL/me${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$PROFILE_URL/me" -H "Authorization: Bearer $ACCESS_TOKEN_2" -H "Content-Type: application/json" -d "$UPDATE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ User 2 profile updated (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}⚠ User 2 profile update warning: HTTP $HTTP_CODE${NC}"
fi

echo ""

# Test 5: Search Profiles
echo -e "${GREEN}=== 5. Testing Search Profiles ===${NC}"
echo -e "${CYAN}Request: GET $PROFILE_URL/search?q=Builder&limit=10&offset=0${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/search?q=Builder&limit=10&offset=0")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Search profiles successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Search profiles failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 6: Get Nearby Profiles
echo -e "${GREEN}=== 6. Testing Get Nearby Profiles ===${NC}"
echo -e "${CYAN}Request: GET $PROFILE_URL/nearby?lat=37.7749&lon=-122.4194&radius=10&limit=10${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/nearby?lat=37.7749&lon=-122.4194&radius=10&limit=10")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get nearby profiles successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Get nearby profiles failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 7: Create Ally Relationship
echo -e "${GREEN}=== 7. Testing Create Ally Relationship ===${NC}"
RELATIONSHIP_BODY="{\"target_user_id\":\"$USER_ID_2\",\"relationship_type\":\"ally\"}"
echo -e "${CYAN}Request: POST $PROFILE_URL/relationships${NC}"
echo -e "${YELLOW}Request Body:${NC} $RELATIONSHIP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/relationships" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$RELATIONSHIP_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Ally relationship created successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Create ally relationship failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 8: Create Favorite Relationship
echo -e "${GREEN}=== 8. Testing Create Favorite Relationship ===${NC}"
RELATIONSHIP_BODY="{\"target_user_id\":\"$USER_ID_3\",\"relationship_type\":\"favorite\"}"
echo -e "${CYAN}Request: POST $PROFILE_URL/relationships${NC}"
echo -e "${YELLOW}Request Body:${NC} $RELATIONSHIP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/relationships" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$RELATIONSHIP_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Favorite relationship created successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Create favorite relationship failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 9: Get Allies List
echo -e "${GREEN}=== 9. Testing Get Allies List ===${NC}"
echo -e "${CYAN}Request: GET $PROFILE_URL/me/allies?limit=20&offset=0${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me/allies?limit=20&offset=0" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get allies list successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    TOTAL=$(get_json_number "$HTTP_BODY" "total")
    echo "  Total Allies: $TOTAL"
else
    echo -e "${RED}✗ Get allies list failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 10: Get Favorites List
echo -e "${GREEN}=== 10. Testing Get Favorites List ===${NC}"
echo -e "${CYAN}Request: GET $PROFILE_URL/me/favorites?limit=20&offset=0${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me/favorites?limit=20&offset=0" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get favorites list successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    TOTAL=$(get_json_number "$HTTP_BODY" "total")
    echo "  Total Favorites: $TOTAL"
else
    echo -e "${RED}✗ Get favorites list failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 11: Create Block Relationship
echo -e "${GREEN}=== 11. Testing Create Block Relationship ===${NC}"
RELATIONSHIP_BODY="{\"target_user_id\":\"$USER_ID_3\",\"relationship_type\":\"block\"}"
echo -e "${CYAN}Request: POST $PROFILE_URL/relationships${NC}"
echo -e "${YELLOW}Request Body:${NC} $RELATIONSHIP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/relationships" -H "Authorization: Bearer $ACCESS_TOKEN_2" -H "Content-Type: application/json" -d "$RELATIONSHIP_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Block relationship created successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Create block relationship failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 12: Remove Relationship
echo -e "${GREEN}=== 12. Testing Remove Relationship ===${NC}"
REMOVE_BODY="{\"target_user_id\":\"$USER_ID_3\",\"relationship_type\":\"favorite\"}"
echo -e "${CYAN}Request: DELETE $PROFILE_URL/relationships${NC}"
echo -e "${YELLOW}Request Body:${NC} $REMOVE_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$PROFILE_URL/relationships" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$REMOVE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Relationship removed successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
elif [[ "$HTTP_CODE" -eq 204 ]]; then
    echo -e "${GREEN}✓ Relationship removed successfully (HTTP $HTTP_CODE - No Content)${NC}"
else
    echo -e "${RED}✗ Remove relationship failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 13: Report User
echo -e "${GREEN}=== 13. Testing Report User ===${NC}"
REPORT_BODY="{\"reported_user_id\":\"$USER_ID_3\",\"reason\":\"spam\",\"description\":\"User is posting spam content repeatedly\"}"
echo -e "${CYAN}Request: POST $PROFILE_URL/reports${NC}"
echo -e "${YELLOW}Request Body:${NC} $REPORT_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/reports" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$REPORT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ User reported successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    REPORT_ID=$(get_json_string "$HTTP_BODY" "report_id")
    echo "  Report ID: $REPORT_ID"
else
    echo -e "${RED}✗ Report user failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 14: Get My Reports
echo -e "${GREEN}=== 14. Testing Get My Reports ===${NC}"
echo -e "${CYAN}Request: GET $PROFILE_URL/me/reports?limit=10&offset=0${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/me/reports?limit=10&offset=0" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get my reports successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Get my reports failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 15: Test Self-Relationship Prevention
echo -e "${GREEN}=== 15. Testing Self-Relationship Prevention ===${NC}"
RELATIONSHIP_BODY="{\"target_user_id\":\"$USER_ID_1\",\"relationship_type\":\"ally\"}"
echo -e "${CYAN}Request: POST $PROFILE_URL/relationships${NC}"
echo -e "${YELLOW}Request Body:${NC} $RELATIONSHIP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/relationships" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$RELATIONSHIP_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ Correctly prevented self-relationship: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Self-relationship should have been rejected${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 16: Test Duplicate Report Prevention
echo -e "${GREEN}=== 16. Testing Duplicate Report Prevention ===${NC}"
REPORT_BODY="{\"reported_user_id\":\"$USER_ID_3\",\"reason\":\"spam\",\"description\":\"Duplicate report should fail\"}"
echo -e "${CYAN}Request: POST $PROFILE_URL/reports${NC}"
echo -e "${YELLOW}Request Body:${NC} $REPORT_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/reports" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$REPORT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ Correctly prevented duplicate report: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${YELLOW}⚠ Duplicate report was allowed: HTTP $HTTP_CODE${NC}"
    echo -e "${YELLOW}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 17: Test Private Profile Access
echo -e "${GREEN}=== 17. Testing Private Profile Access ===${NC}"
# First, make User 3's profile private
UPDATE_BODY="{\"is_profile_public\":false}"
echo -e "${CYAN}Making User 3's profile private${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$PROFILE_URL/me" -H "Authorization: Bearer $ACCESS_TOKEN_3" -H "Content-Type: application/json" -d "$UPDATE_BODY")

# Now try to access it from User 1 (who is not an ally)
echo -e "${CYAN}Request: GET $PROFILE_URL/$USERNAME_3${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/$USERNAME_3" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ Correctly denied access to private profile: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
elif [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ Access to private profile restricted: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${YELLOW}⚠ Private profile access returned: HTTP $HTTP_CODE${NC}"
    echo -e "${YELLOW}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 18: Test Invalid Relationship Type
echo -e "${GREEN}=== 18. Testing Invalid Relationship Type ===${NC}"
RELATIONSHIP_BODY="{\"target_user_id\":\"$USER_ID_2\",\"relationship_type\":\"invalid_type\"}"
echo -e "${CYAN}Request: POST $PROFILE_URL/relationships${NC}"
echo -e "${YELLOW}Request Body:${NC} $RELATIONSHIP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$PROFILE_URL/relationships" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$RELATIONSHIP_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ Correctly rejected invalid relationship type: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Invalid relationship type should have been rejected${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 19: Test Profile Update Validation
echo -e "${GREEN}=== 19. Testing Profile Update Validation (Too Long Display Name) ===${NC}"
LONG_NAME="ThisIsAnExtremelyLongDisplayNameThatExceedsTheMaximumAllowedLengthAndShouldBeRejected"
UPDATE_BODY="{\"display_name\":\"$LONG_NAME\"}"
echo -e "${CYAN}Request: PUT $PROFILE_URL/me${NC}"
echo -e "${YELLOW}Request Body:${NC} $UPDATE_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$PROFILE_URL/me" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$UPDATE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ Correctly rejected invalid display name: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${YELLOW}⚠ Invalid display name was accepted: HTTP $HTTP_CODE${NC}"
    echo -e "${YELLOW}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 20: Test Non-existent User Profile
echo -e "${GREEN}=== 20. Testing Non-existent User Profile ===${NC}"
FAKE_UUID="00000000-0000-0000-0000-000000000000"
echo -e "${CYAN}Request: GET $PROFILE_URL/nonexistentuser${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$PROFILE_URL/nonexistentuser")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -eq 404 ]]; then
    echo -e "${GREEN}✓ Correctly returned 404 for non-existent profile: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Expected 404 for non-existent profile, got: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""
echo -e "${CYAN}=== All Profile Tests Complete ===${NC}"
echo -e "${CYAN}Summary:${NC}"
echo "  - User 1 (Alice) ID: $USER_ID_1"
echo "  - User 1 Username: $USERNAME_1"
echo "  - User 2 (Bob) ID: $USER_ID_2"
echo "  - User 2 Username: $USERNAME_2"
echo "  - User 3 (Charlie) ID: $USER_ID_3"
echo "  - User 3 Username: $USERNAME_3"
echo "  - All core profile features tested"
echo "  - Relationships: allies, favorites, blocks tested"
echo "  - Report system tested"
echo "  - Privacy controls tested"
echo "  - Validation and error handling tested"
