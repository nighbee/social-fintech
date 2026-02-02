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

# ===============================================
# Phone Authentication Tests
# ===============================================

echo -e "\n${GREEN}=== 5. Testing Phone Registration Flow ===${NC}"

TEST_PHONE="+1555$(printf "%07d" $RANDOM)"
echo -e "${CYAN}Test Phone Number: $TEST_PHONE${NC}"

# Step 1: Request OTP for registration
echo -e "\n${YELLOW}Step 1: Requesting OTP for phone registration...${NC}"

REQUEST_OTP_BODY="{\"country_code\":\"+1\",\"phone_number\":\"555$(printf "%07d" $RANDOM)\",\"purpose\":\"register\"}"
echo -e "${YELLOW}Request Body:${NC} $REQUEST_OTP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/phone/request" -H "Content-Type: application/json" -d "$REQUEST_OTP_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ OTP request successful!${NC}"
    
    VERIFICATION_ID=$(get_json_string "$HTTP_BODY" "verification_id")
    echo "  Verification ID: $VERIFICATION_ID"
    
    # Extract OTP from docker logs
    echo -e "${YELLOW}Extracting OTP from container logs...${NC}"
    sleep 1
    
    # Get the last SMS log from the API container
    OTP_CODE=$(docker logs brightbund-api 2>&1 | grep "sms_placeholder" | tail -1 | grep -o "Your BrightBund code is [0-9]*" | grep -o "[0-9]*$")
    
    if [ -z "$OTP_CODE" ]; then
        echo -e "${RED}✗ Failed to extract OTP from logs${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}  OTP Code: $OTP_CODE${NC}"
else
    echo -e "${RED}✗ OTP request failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
    exit 1
fi

# Step 2: Verify OTP
echo -e "\n${YELLOW}Step 2: Verifying OTP...${NC}"

VERIFY_OTP_BODY="{\"verification_id\":\"$VERIFICATION_ID\",\"code\":\"$OTP_CODE\",\"device_id\":\"test-device-phone\"}"
echo -e "${YELLOW}Request Body:${NC} $VERIFY_OTP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/phone/verify" -H "Content-Type: application/json" -d "$VERIFY_OTP_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ OTP verification successful!${NC}"
    
    VERIFIED=$(get_json_string "$HTTP_BODY" "verified")
    echo "  Verified: $VERIFIED"
else
    echo -e "${RED}✗ OTP verification failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
    exit 1
fi

# Step 3: Complete registration
echo -e "\n${YELLOW}Step 3: Completing phone registration...${NC}"

REGISTER_PHONE_BODY="{\"verification_id\":\"$VERIFICATION_ID\",\"first_name\":\"Jane\",\"last_name\":\"Smith\",\"date_of_birth\":\"1995-05-15\",\"referral\":\"\",\"device_id\":\"test-device-phone\",\"app_version\":\"1.0.0\"}"
echo -e "${YELLOW}Request Body:${NC} $REGISTER_PHONE_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/register-phone" -H "Content-Type: application/json" -d "$REGISTER_PHONE_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Phone registration complete!${NC}"
    
    PHONE_ACCESS_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
    PHONE_USER_ID=$(get_json_number "$HTTP_BODY" "id")
    PHONE_USERNAME=$(get_json_string "$HTTP_BODY" "username")
    
    echo "  User ID: $PHONE_USER_ID"
    echo "  Username: $PHONE_USERNAME"
    echo "  Access Token: ${PHONE_ACCESS_TOKEN:0:50}..."
else
    echo -e "${RED}✗ Phone registration failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
    exit 1
fi

echo -e "\n${GREEN}=== 6. Testing Phone Login Flow ===${NC}"

# Extract country code and phone number from the test phone used in registration
PHONE_COUNTRY=$(echo "$REQUEST_OTP_BODY" | grep -o '"country_code":"[^"]*"' | cut -d'"' -f4)
PHONE_NUM=$(echo "$REQUEST_OTP_BODY" | grep -o '"phone_number":"[^"]*"' | cut -d'"' -f4)

echo -e "${CYAN}Test Phone: $PHONE_COUNTRY$PHONE_NUM${NC}"

# Step 1: Request OTP for login
echo -e "\n${YELLOW}Step 1: Requesting OTP for phone login...${NC}"

LOGIN_OTP_BODY="{\"country_code\":\"$PHONE_COUNTRY\",\"phone_number\":\"$PHONE_NUM\",\"purpose\":\"login\"}"
echo -e "${YELLOW}Request Body:${NC} $LOGIN_OTP_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/phone/request" -H "Content-Type: application/json" -d "$LOGIN_OTP_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Login OTP request successful!${NC}"
    
    LOGIN_VERIFICATION_ID=$(get_json_string "$HTTP_BODY" "verification_id")
    echo "  Verification ID: $LOGIN_VERIFICATION_ID"
    
    # Extract OTP from docker logs
    echo -e "${YELLOW}Extracting OTP from container logs...${NC}"
    sleep 1
    
    LOGIN_OTP_CODE=$(docker logs brightbund-api 2>&1 | grep "sms_placeholder" | tail -1 | grep -o "Your BrightBund code is [0-9]*" | grep -o "[0-9]*$")
    
    if [ -z "$LOGIN_OTP_CODE" ]; then
        echo -e "${RED}✗ Failed to extract OTP from logs${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}  OTP Code: $LOGIN_OTP_CODE${NC}"
else
    echo -e "${RED}✗ Login OTP request failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
    exit 1
fi

# Step 2: Verify OTP and login
echo -e "\n${YELLOW}Step 2: Verifying OTP and logging in...${NC}"

LOGIN_VERIFY_BODY="{\"verification_id\":\"$LOGIN_VERIFICATION_ID\",\"code\":\"$LOGIN_OTP_CODE\",\"device_id\":\"test-device-phone-2\"}"
echo -e "${YELLOW}Request Body:${NC} $LOGIN_VERIFY_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/phone/verify" -H "Content-Type: application/json" -d "$LOGIN_VERIFY_BODY")

HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Phone login successful!${NC}"
    
    LOGIN_ACCESS_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
    LOGIN_REFRESH_TOKEN=$(get_json_string "$HTTP_BODY" "refresh_token")
    
    echo "  Access Token: ${LOGIN_ACCESS_TOKEN:0:50}..."
    echo "  Refresh Token: ${LOGIN_REFRESH_TOKEN:0:50}..."
else
    echo -e "${RED}✗ Phone login failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}  Response: $HTTP_BODY${NC}"
    exit 1
fi

echo -e "\n${CYAN}=== All Auth Tests (Email + Phone) Complete ===${NC}"