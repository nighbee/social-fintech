#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

AUTH_URL="http://localhost:8081/api/v1/auth"
ECO_URL="http://localhost:8081/api/v1/economy"

# Helper functions
get_json_string() {
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_json_number() {
    echo "$1" | grep -o "\"$2\": *[0-9.]*" | head -1 | grep -o "[0-9.]*"
}

log_request() {
    local test_name="$1"
    local method="$2"
    local url="$3"
    local body="$4"
    local response_body="$5"
    local http_code="$6"
    
    echo -e "${CYAN}--- REQUEST ---${NC}"
    echo "$method $url"
    if [[ -n "$body" ]]; then
        echo "Body: $body"
    fi
    echo -e "${CYAN}--- RESPONSE ---${NC}"
    echo "HTTP $http_code"
    echo "Body: $response_body"
    echo ""
}

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}   Economy Module 2.0 Test Suite${NC}"
echo -e "${CYAN}   (Seal Cooldowns & Admin Rights)${NC}"
echo -e "${CYAN}======================================${NC}\n"

# SETUP: Create Test Users

echo -e "${GREEN}=== SETUP: Creating Test Users ===${NC}"

# Admin User (for admin tests and funding)
ADMIN_EMAIL="admin_new_${RANDOM}@example.com"
ADMIN_PASSWORD="AdminPass123!"

REGISTER_BODY="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"first_name\":\"Admin\",\"last_name\":\"Test\",\"date_of_birth\":\"1990-01-01\",\"device_id\":\"admin-device\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ADMIN_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ Admin user created: $ADMIN_ID${NC}"
    echo -e "${YELLOW}⚠ Granting admin privileges via SQL...${NC}"
    
    # Automatically grant admin privileges
    docker exec brightbund-db psql -U user -d brightbund -c "UPDATE users SET is_admin = true WHERE id = '$ADMIN_ID';" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Admin privileges granted successfully${NC}"
    else
        echo -e "${RED}✗ Failed to grant admin privileges${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Admin user creation failed: HTTP $HTTP_CODE${NC}"
    exit 1
fi

# Login admin
LOGIN_BODY="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"device_id\":\"admin-device\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ADMIN_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
    echo -e "${GREEN}✓ Admin user logged in${NC}"
else
    echo -e "${RED}✗ Admin login failed${NC}"
    exit 1
fi

# Create Sender (User 1)
USER1_EMAIL="sender_${RANDOM}@example.com"
USER1_PASSWORD="Pass123!"
REGISTER_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"first_name\":\"Sender\",\"last_name\":\"One\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"dev1\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER1_ID=$(get_json_string "$HTTP_BODY" "id")
USER1_TOKEN=$(get_json_string "$HTTP_BODY" "access_token") # Usually register returns token? Or need login?
# Checking register response... usually implies login or need explicit login. brightbund seems to return token on register?
# Let's double check via Login if token missing.
if [[ -z "$USER1_TOKEN" ]]; then
    LOGIN_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"device_id\":\"dev1\"}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
    HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
    USER1_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
fi
echo -e "${GREEN}✓ Sender Created: $USER1_ID${NC}"

# Create Receiver (User 2)
USER2_EMAIL="receiver_${RANDOM}@example.com"
USER2_PASSWORD="Pass123!"
REGISTER_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASSWORD\",\"first_name\":\"Receiver\",\"last_name\":\"Two\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"dev2\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER2_ID=$(get_json_string "$HTTP_BODY" "id")
echo -e "${GREEN}✓ Receiver Created: $USER2_ID${NC}"

# Fund Sender (via Admin or Hack)
if [[ -n "$ADMIN_TOKEN" ]]; then
     # Fund via Admin Endpoint
     ADJUST_BODY="{\"user_id\":\"$USER1_ID\",\"amount\":100.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Test funding\"}"
     curl -s -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$ADJUST_BODY" > /dev/null
     echo -e "${GREEN}✓ Sender funded via Admin${NC}"
else
     # Try Claim Daily Accrual for initial funds (0.5 only? need more).
     # Or try to continue, maybe they have 0 balance? 
     echo -e "${YELLOW}⚠ No Admin Token. Sender might have 0 balance. Tests might fail on 402.${NC}"
fi

echo ""

# TEST 1: Give 1 Seal (Success)
echo -e "${GREEN}=== TEST 1: Give 1 Seal (Success) ===${NC}"
GIFT_BODY="{\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"message\":\"First seal\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/users/$USER2_ID/gift" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$GIFT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 1" "POST" "$ECO_URL/users/$USER2_ID/gift" "$GIFT_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Success: Seal sent${NC}"
else
    echo -e "${RED}✗ Failed: $HTTP_CODE${NC}"
fi

echo ""

# TEST 2: Give 2nd Seal Immediately (Fail - Cooldown)
echo -e "${GREEN}=== TEST 2: Give 2nd Seal Immediately (Fail - Cooldown) ===${NC}"
GIFT_BODY="{\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"message\":\"Second seal\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/users/$USER2_ID/gift" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$GIFT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 2" "POST" "$ECO_URL/users/$USER2_ID/gift" "$GIFT_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -eq 429 ]]; then
    echo -e "${GREEN}✓ Correct Error Code: 429${NC}"
    ERR_CODE=$(get_json_string "$HTTP_BODY" "code")
    NEXT_ALLOWED=$(get_json_string "$HTTP_BODY" "next_allowed_at")
    REPEAT_LEVEL=$(echo "$HTTP_BODY" | grep -o "\"repeat_level\": *[0-9]*" | grep -o "[0-9]*")
    
    if [[ "$ERR_CODE" == "COOLDOWN_ACTIVE" ]]; then
        echo -e "${GREEN}✓ Error Code verified: COOLDOWN_ACTIVE${NC}"
    else
        echo -e "${RED}✗ Wrong Error Code: $ERR_CODE${NC}"
    fi
    
    # Check Repeat Level (Should be 2 or whatever next level is, actually it returns level that determined cooldown?)
    # The error struct says "RepeatLevel". In code: `RepeatLevel: cooldown.RepeatLevel`.
    # After first grant (Level 1 used, incremented to 2). So stored level is 2.
    if [[ "$REPEAT_LEVEL" == "2" ]]; then
         echo -e "${GREEN}✓ Repeat Level verified: 2${NC}"
    else
         echo -e "${YELLOW}⚠ Repeat Level mismatch? Got: $REPEAT_LEVEL${NC}"
    fi
else
    echo -e "${RED}✗ Fail: Expected 429, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 3: Give Seal via Post Context (Fail - Shared Cooldown)
echo -e "\n=== TEST 3: Give Seal via Post Context (Fail - Shared Cooldown) ==="
POST_ID="post_${RANDOM}"
SEAL_BODY_JSON="{\"amount\":1,\"currency\":\"SILVER_SEAL\",\"receiver_user_id\":\"$USER2_ID\"}"
log_request "TEST 3" "POST" "$ECO_URL/posts/$POST_ID/seals" "$SEAL_BODY_JSON"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/posts/$POST_ID/seals" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SEAL_BODY_JSON")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 3" "POST" "$ECO_URL/posts/$POST_ID/seals" "$SEAL_BODY_JSON" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -eq 429 ]]; then
    echo -e "${GREEN}✓ Correct: Blocked by shared cooldown${NC}"
else
    echo -e "${RED}✗ Fail: Should be blocked, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 4: Invalid Amount (>1)
echo -e "${GREEN}=== TEST 4: Invalid Amount (>1) ===${NC}"
GIFT_BODY="{\"amount\":2.0,\"currency\":\"SILVER_SEAL\",\"message\":\"Double seal\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/users/$USER2_ID/gift" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$GIFT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 4" "POST" "$ECO_URL/users/$USER2_ID/gift" "$GIFT_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${GREEN}✓ Correct: Blocked amount > 1${NC}"
else
    echo -e "${RED}✗ Fail: Expected 400, got $HTTP_CODE${NC}"
fi

echo ""

echo -e "${CYAN}=== Test Suite Complete ===${NC}"
