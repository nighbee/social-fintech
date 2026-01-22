#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

BASE_URL="http://localhost:8081/api/v1/auth"

# --- Helper function to extract values from JSON using grep/sed ---
get_json_string() {
    # Usage: get_json_string "json_blob" "key"
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_json_number() {
    # Usage: get_json_number "json_blob" "key"
    echo "$1" | grep -o "\"$2\": *[0-9]*" | head -1 | grep -o "[0-9]*"
}
# ------------------------------------------------------------------

echo -e "${GREEN}=== 1. Testing Email Registration ===${NC}"

TEST_EMAIL="testuser${RANDOM}@example.com"
TEST_PASSWORD="SecurePass123!"

# Manually construct JSON string
REGISTER_BODY="{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"first_name\":\"John\",\"last_name\":\"Doe\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"test-device-12345\",\"app_version\":\"1.0.0-dev\"}"

# Print Request Body
echo -e "${YELLOW}Request Body:${NC} $REGISTER_BODY"

# Request
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Registration successful!${NC}"
    
    # Extract Data without jq
    USER_ID=$(get_json_number "$HTTP_BODY" "id")
    USERNAME=$(get_json_string "$HTTP_BODY" "username")
    EMAIL=$(get_json_string "$HTTP_BODY" "email")
    
    echo "  User ID: $USER_ID"
    echo "  Username: $USERNAME"
    echo "  Email: $EMAIL"
else
    echo -e "${RED}✗ Registration failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
    exit 1
fi

echo -e "\n${GREEN}=== 2. Testing Email Login ===${NC}"

LOGIN_BODY="{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"device_id\":\"test-device-12345\"}"

# Print Request Body
echo -e "${YELLOW}Request Body:${NC} $LOGIN_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Login successful!${NC}"
    
    ACCESS_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
    REFRESH_TOKEN=$(get_json_string "$HTTP_BODY" "refresh_token")
    USER_ID=$(get_json_number "$HTTP_BODY" "id")

    echo "  Access Token: ${ACCESS_TOKEN:0:50}..."
    echo "  Refresh Token: ${REFRESH_TOKEN:0:50}..."
    echo "  User ID: $USER_ID"
else
    echo -e "${RED}✗ Login failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
    exit 1
fi

echo -e "\n${GREEN}=== 3. Testing Refresh Token ===${NC}"

REFRESH_BODY="{\"refresh_token\":\"$REFRESH_TOKEN\"}"

# Print Request Body
echo -e "${YELLOW}Request Body:${NC} $REFRESH_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/refresh" -H "Content-Type: application/json" -d "$REFRESH_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Token refresh successful!${NC}"
    ACCESS_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
    echo "  New Access Token: ${ACCESS_TOKEN:0:50}..."
else
    echo -e "${RED}✗ Token refresh failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
fi

echo -e "\n${GREEN}=== 4. Testing Logout ===${NC}"

# No JSON body for logout, but we print the header info just for consistency
echo -e "${YELLOW}Request Body:${NC} (Empty - using Authorization Header)"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/logout" -H "Authorization: Bearer $ACCESS_TOKEN")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Logout successful!${NC}"
else
    echo -e "${RED}✗ Logout failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
fi

echo -e "\n${CYAN}=== All Tests Complete ===${NC}"