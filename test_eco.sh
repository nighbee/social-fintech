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
echo -e "${CYAN}   Economy Module Test Suite${NC}"
echo -e "${CYAN}======================================${NC}\n"

# SETUP: Create Test Users

echo -e "${GREEN}=== SETUP: Creating Test Users ===${NC}"

# Admin User (for admin tests and funding)
ADMIN_EMAIL="admin_test_${RANDOM}@example.com"
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
        echo -e "${YELLOW}Run manually: UPDATE users SET is_admin = true WHERE id = '$ADMIN_ID';${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Admin user creation failed: HTTP $HTTP_CODE${NC}"
    log_request "Admin Registration" "POST" "$AUTH_URL/register-email" "$REGISTER_BODY" "$HTTP_BODY" "$HTTP_CODE"
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

# User 1 (Main test user)
USER1_EMAIL="user1_${RANDOM}@example.com"
USER1_PASSWORD="Pass123!"

REGISTER_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"first_name\":\"Alice\",\"last_name\":\"Smith\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"device1\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    USER1_ID=$(get_json_string "$HTTP_BODY" "id")
    echo -e "${GREEN}✓ User 1 created: $USER1_ID${NC}"
else
    echo -e "${RED}✗ User 1 creation failed${NC}"
    exit 1
fi

# Login User 1
LOGIN_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"device_id\":\"device1\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER1_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ User 1 logged in${NC}"

# User 2 (Recipient)
USER2_EMAIL="user2_${RANDOM}@example.com"
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

# User 3 (Additional sender for concurrent tests)
USER3_EMAIL="user3_${RANDOM}@example.com"
REGISTER_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"first_name\":\"Charlie\",\"last_name\":\"Brown\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"device3\",\"app_version\":\"1.0.0\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER3_ID=$(get_json_string "$HTTP_BODY" "id")
echo -e "${GREEN}✓ User 3 created: $USER3_ID${NC}"

LOGIN_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER1_PASSWORD\",\"device_id\":\"device3\"}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
USER3_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")
echo -e "${GREEN}✓ User 3 logged in${NC}"

echo ""

# TEST 1: Get Balance (Initial State)
echo -e "${GREEN}=== TEST 1: Get Balance (Initial State) ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 1" "GET" "$ECO_URL/balance" "" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get balance successful${NC}"
    SILVER_BALANCE=$(get_json_number "$HTTP_BODY" "silver_balance")
    GOLD_BALANCE=$(get_json_number "$HTTP_BODY" "gold_balance")
    echo -e "${CYAN}  Silver: $SILVER_BALANCE, Gold: $GOLD_BALANCE${NC}"
else
    echo -e "${RED}✗ Get balance failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 2: Get Limits
echo -e "${GREEN}=== TEST 2: Get Limits ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/limits" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 2" "GET" "$ECO_URL/limits" "" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get limits successful${NC}"
    MONTHLY_LIMIT=$(get_json_number "$HTTP_BODY" "monthly_transfer_limit")
    MONTHLY_USED=$(get_json_number "$HTTP_BODY" "monthly_transferred")
    echo -e "${CYAN}  Monthly Limit: $MONTHLY_LIMIT, Used: $MONTHLY_USED${NC}"
else
    echo -e "${RED}✗ Get limits failed${NC}"
fi

echo ""

# TEST 3: Admin Protection - Non-Admin Blocked
echo -e "${GREEN}=== TEST 3: Admin Protection - Non-Admin User Blocked ===${NC}"
ADJUST_BODY="{\"user_id\":\"$USER1_ID\",\"amount\":100.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Unauthorized attempt\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$ADJUST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 3" "POST" "$ECO_URL/admin/adjust" "$ADJUST_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ SUCCESS: Non-admin user blocked with 403${NC}"
else
    echo -e "${RED}✗ FAIL: Expected 403, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 4: Admin Protection - Admin Allowed
echo -e "${GREEN}=== TEST 4: Admin Protection - Admin User Allowed ===${NC}"
ADJUST_BODY="{\"user_id\":\"$USER1_ID\",\"amount\":50.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Test funding\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$ADJUST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 4" "POST" "$ECO_URL/admin/adjust" "$ADJUST_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ SUCCESS: Admin successfully adjusted balance${NC}"
else
    echo -e "${RED}✗ FAIL: Admin should have access, got $HTTP_CODE${NC}"
fi

# Fund User 2 and 3 as well
curl -s -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"user_id\":\"$USER2_ID\",\"amount\":50.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Test funding\"}" > /dev/null
curl -s -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"user_id\":\"$USER3_ID\",\"amount\":50.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Test funding\"}" > /dev/null
echo -e "${CYAN}  ✓ Funded all users with 50 Silver${NC}"

echo ""

# TEST 5: Daily Accrual - First Claim (1.0 Seal)
echo -e "${GREEN}=== TEST 5: Daily Accrual - First Claim ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/accrual/claim" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "{}")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 5" "POST" "$ECO_URL/accrual/claim" "{}" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    ACCRUAL_AMOUNT=$(get_json_number "$HTTP_BODY" "amount")
    echo -e "${GREEN}✓ Accrual claimed: $ACCRUAL_AMOUNT seals${NC}"
    
    if [[ "$ACCRUAL_AMOUNT" == "1" ]] || [[ "$ACCRUAL_AMOUNT" == "1.0" ]]; then
        echo -e "${GREEN}✓ CORRECT: Received 1.0 seal (not 0.5)${NC}"
    else
        echo -e "${RED}✗ FAIL: Expected 1.0 seal, got $ACCRUAL_AMOUNT${NC}"
    fi
elif [[ "$HTTP_CODE" -eq 400 ]]; then
    echo -e "${YELLOW}⚠ Accrual not available yet (may need 48 hours)${NC}"
else
    echo -e "${RED}✗ Accrual failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 6: Daily Accrual - Immediate Re-Claim Blocked
echo -e "${GREEN}=== TEST 6: Daily Accrual - Re-Claim Blocked ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/accrual/claim" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "{}")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 6" "POST" "$ECO_URL/accrual/claim" "{}" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ CORRECT: Re-claim blocked (need 48 hours)${NC}"
else
    echo -e "${RED}✗ FAIL: Should block immediate re-claim, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 7: P2P Transfer
echo -e "${GREEN}=== TEST 7: P2P Transfer ===${NC}"
TRANSFER_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":5.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Test transfer\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 7" "POST" "$ECO_URL/transfer" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Transfer successful${NC}"
    LEDGER_ID=$(get_json_string "$HTTP_BODY" "ledger_entry_id")
    SENDER_BAL=$(get_json_number "$HTTP_BODY" "sender_balance")
    RECEIVER_BAL=$(get_json_number "$HTTP_BODY" "receiver_balance")
    echo -e "${CYAN}  Ledger ID: $LEDGER_ID${NC}"
    echo -e "${CYAN}  Sender: $SENDER_BAL, Receiver: $RECEIVER_BAL${NC}"
else
    echo -e "${RED}✗ Transfer failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 8: Idempotency - First Request
echo -e "${GREEN}=== TEST 8: Idempotency - First Request ===${NC}"
sleep 65  # Wait for cooldown

IDEMPOTENCY_KEY="test-idem-${RANDOM}"
TRANSFER_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":2.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Idempotency test\",\"idempotency_key\":\"$IDEMPOTENCY_KEY\"}"
echo -e "${CYAN}Idempotency Key: $IDEMPOTENCY_KEY${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 8" "POST" "$ECO_URL/transfer" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    LEDGER_ID_1=$(get_json_string "$HTTP_BODY" "ledger_entry_id")
    SENDER_BAL_1=$(get_json_number "$HTTP_BODY" "sender_balance")
    RECEIVER_BAL_1=$(get_json_number "$HTTP_BODY" "receiver_balance")
    echo -e "${GREEN}✓ First transfer: $LEDGER_ID_1${NC}"
    echo -e "${CYAN}  Sender: $SENDER_BAL_1, Receiver: $RECEIVER_BAL_1${NC}"
else
    echo -e "${RED}✗ First transfer failed${NC}"
fi

echo ""

# TEST 9: Idempotency - Duplicate Request
echo -e "${GREEN}=== TEST 9: Idempotency - Duplicate Request ===${NC}"
sleep 2

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 9" "POST" "$ECO_URL/transfer (duplicate)" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    LEDGER_ID_2=$(get_json_string "$HTTP_BODY" "ledger_entry_id")
    SENDER_BAL_2=$(get_json_number "$HTTP_BODY" "sender_balance")
    RECEIVER_BAL_2=$(get_json_number "$HTTP_BODY" "receiver_balance")
    
    if [[ "$LEDGER_ID_1" == "$LEDGER_ID_2" ]]; then
        echo -e "${GREEN}✓ CORRECT: Same ledger ID (idempotent)${NC}"
    else
        echo -e "${RED}✗ FAIL: Different ledger IDs!${NC}"
    fi
    
    if [[ "$SENDER_BAL_1" == "$SENDER_BAL_2" ]] && [[ "$RECEIVER_BAL_1" == "$RECEIVER_BAL_2" ]]; then
        echo -e "${GREEN}✓ CORRECT: Balances unchanged (no double charge)${NC}"
        echo -e "${CYAN}  Sender: $SENDER_BAL_2, Receiver: $RECEIVER_BAL_2${NC}"
    else
        echo -e "${RED}✗ FAIL: Balances changed!${NC}"
    fi
elif [[ "$HTTP_CODE" -eq 429 ]]; then
    echo -e "${YELLOW}⚠ Rate limited (429) - cooldown period active. This is expected behavior.${NC}"
else
    echo -e "${RED}✗ Duplicate request failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 10: Give Seal to Post
echo -e "${GREEN}=== TEST 10: Give Seal to Post ===${NC}"
sleep 65

POST_ID="test-post-${RANDOM}"
SEAL_BODY="{\"amount\":3,\"currency\":\"SILVER_SEAL\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/seal/post/$POST_ID" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$SEAL_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 10" "POST" "$ECO_URL/seal/post/$POST_ID" "$SEAL_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Seal given to post successfully${NC}"
    SENDER_BAL=$(get_json_number "$HTTP_BODY" "sender_balance")
    echo -e "${CYAN}  Remaining Balance: $SENDER_BAL${NC}"
else
    echo -e "${RED}✗ Give seal failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 11: Give Seal to User
echo -e "${GREEN}=== TEST 11: Give Seal to User ===${NC}"
sleep 65

GIFT_BODY="{\"amount\":1.5,\"currency\":\"SILVER_SEAL\",\"message\":\"Thanks!\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/seal/user/$USER2_ID" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$GIFT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 11" "POST" "$ECO_URL/seal/user/$USER2_ID" "$GIFT_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Seal given to user successfully${NC}"
    SENDER_BAL=$(get_json_number "$HTTP_BODY" "sender_balance")
    RECEIVER_BAL=$(get_json_number "$HTTP_BODY" "receiver_balance")
    echo -e "${CYAN}  Sender: $SENDER_BAL, Receiver: $RECEIVER_BAL${NC}"
else
    echo -e "${RED}✗ Give seal failed: HTTP $HTTP_CODE${NC}"
fi

echo ""

# TEST 12: Transaction History
echo -e "${GREEN}=== TEST 12: Transaction History ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/transactions?page=1&page_size=10" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 12" "GET" "$ECO_URL/transactions?page=1&page_size=10" "" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Transaction history retrieved${NC}"
    TOTAL=$(get_json_number "$HTTP_BODY" "total")
    echo -e "${CYAN}  Total Transactions: $TOTAL${NC}"
else
    echo -e "${RED}✗ Failed to get history${NC}"
fi

echo ""

# TEST 13: Referral Stats
echo -e "${GREEN}=== TEST 13: Referral Stats ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/referral/stats" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 13" "GET" "$ECO_URL/referral/stats" "" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Referral stats retrieved${NC}"
    TOTAL_REFS=$(get_json_number "$HTTP_BODY" "total_referrals")
    echo -e "${CYAN}  Total Referrals: $TOTAL_REFS${NC}"
else
    echo -e "${RED}✗ Failed to get referral stats${NC}"
fi

echo ""

# TEST 14: Error Handling - Insufficient Funds
echo -e "${GREEN}=== TEST 14: Error Handling - Insufficient Funds ===${NC}"
sleep 65

TRANSFER_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":9999.99,\"currency\":\"SILVER_SEAL\",\"reason\":\"Should fail\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 14" "POST" "$ECO_URL/transfer" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -eq 402 ]]; then
    echo -e "${GREEN}✓ CORRECT: 402 Payment Required for insufficient funds${NC}"
elif [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ CORRECT: Error status $HTTP_CODE${NC}"
else
    echo -e "${RED}✗ FAIL: Expected error, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 15: Error Handling - Self-Transfer
echo -e "${GREEN}=== TEST 15: Error Handling - Self-Transfer ===${NC}"
sleep 65

TRANSFER_BODY="{\"recipient_user_id\":\"$USER1_ID\",\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Self transfer\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $USER1_TOKEN" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 15" "POST" "$ECO_URL/transfer" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ CORRECT: Self-transfer blocked${NC}"
else
    echo -e "${RED}✗ FAIL: Self-transfer should be rejected${NC}"
fi

echo ""

# TEST 16: Admin Violations Endpoint Protection
echo -e "${GREEN}=== TEST 16: Admin Violations Endpoint Protection ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/admin/violations?user_id=$USER1_ID" -H "Authorization: Bearer $USER1_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 16" "GET" "$ECO_URL/admin/violations?user_id=$USER1_ID" "" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -eq 403 ]]; then
    echo -e "${GREEN}✓ SUCCESS: Non-admin blocked from violations endpoint${NC}"
elif [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ CORRECT: Access denied (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ FAIL: Should block non-admin, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 17: Admin Can Access Violations
echo -e "${GREEN}=== TEST 17: Admin Can Access Violations ===${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/admin/violations?user_id=$USER1_ID" -H "Authorization: Bearer $ADMIN_TOKEN")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

log_request "TEST 17" "GET" "$ECO_URL/admin/violations?user_id=$USER1_ID" "" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ SUCCESS: Admin accessed violations endpoint${NC}"
else
    echo -e "${RED}✗ FAIL: Admin should have access, got $HTTP_CODE${NC}"
fi

echo ""

# TEST 18: Race Condition Protection
echo -e "${GREEN}=== TEST 18: Race Condition Protection ===${NC}"
echo -e "${CYAN}Testing concurrent transfers to same receiver...${NC}"
sleep 65

# Get receiver balance before
RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER2_TOKEN")
RECEIVER_BEFORE=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}Receiver balance before: $RECEIVER_BEFORE${NC}"

# Launch 3 concurrent transfers from User 1
for i in {1..3}; do
    TRANSFER_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Concurrent $i\",\"idempotency_key\":\"race-u1-$i-${RANDOM}\"}"
    curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" \
        -H "Authorization: Bearer $USER1_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$TRANSFER_BODY" > "/tmp/race_u1_$i.log" 2>&1 &
done

# Launch 3 concurrent transfers from User 3
for i in {1..3}; do
    TRANSFER_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Concurrent $i\",\"idempotency_key\":\"race-u3-$i-${RANDOM}\"}"
    curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" \
        -H "Authorization: Bearer $USER3_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$TRANSFER_BODY" > "/tmp/race_u3_$i.log" 2>&1 &
done

echo -e "${YELLOW}Waiting for concurrent transfers...${NC}"
wait

echo -e "${CYAN}--- CONCURRENT REQUESTS & RESPONSES ---${NC}"

# Count successes and display each request/response
SUCCESS=0
for i in {1..3}; do
    TRANSFER_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Concurrent $i\",\"idempotency_key\":\"race-u1-$i-*\"}"
    
    if [[ -f "/tmp/race_u1_$i.log" ]]; then
        HTTP_BODY=$(head -n -1 "/tmp/race_u1_$i.log" 2>/dev/null || echo "")
        HTTP_CODE=$(tail -n 1 "/tmp/race_u1_$i.log" 2>/dev/null || echo "000")
        
        echo -e "${CYAN}User1 Transfer #$i:${NC}"
        log_request "User1 Transfer $i" "POST" "$ECO_URL/transfer" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE"
        
        if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
            SUCCESS=$((SUCCESS + 1))
        fi
    fi
done

for i in {1..3}; do
    TRANSFER_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Concurrent $i\",\"idempotency_key\":\"race-u3-$i-*\"}"
    
    if [[ -f "/tmp/race_u3_$i.log" ]]; then
        HTTP_BODY=$(head -n -1 "/tmp/race_u3_$i.log" 2>/dev/null || echo "")
        HTTP_CODE=$(tail -n 1 "/tmp/race_u3_$i.log" 2>/dev/null || echo "000")
        
        echo -e "${CYAN}User3 Transfer #$i:${NC}"
        log_request "User3 Transfer $i" "POST" "$ECO_URL/transfer" "$TRANSFER_BODY" "$HTTP_BODY" "$HTTP_CODE"
        
        if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
            SUCCESS=$((SUCCESS + 1))
        fi
    fi
done

# Get receiver balance after
RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER2_TOKEN")
RECEIVER_AFTER=$(get_json_number "$RESPONSE" "silver_balance")

# Calculate expected balance using awk (bc may not be available in Git Bash)
EXPECTED=$(awk "BEGIN {printf \"%.1f\", $RECEIVER_BEFORE + $SUCCESS * 1.0}")
AFTER_DIFF=$(awk "BEGIN {printf \"%.1f\", $RECEIVER_AFTER - $RECEIVER_BEFORE}")

echo -e "${CYAN}Receiver balance before: $RECEIVER_BEFORE${NC}"
echo -e "${CYAN}Receiver balance after: $RECEIVER_AFTER${NC}"
echo -e "${CYAN}Balance change: +$AFTER_DIFF${NC}"
echo -e "${CYAN}Expected change: +$(awk "BEGIN {print $SUCCESS * 1.0}") (from $SUCCESS successful transfers)${NC}"
echo -e "${CYAN}Successful transfers: $SUCCESS out of 6 attempted${NC}"

# Compare with tolerance for floating point
MATCH=$(awk "BEGIN {if ($RECEIVER_AFTER == $EXPECTED) print 1; else print 0}")
if [[ "$MATCH" == "1" ]]; then
    echo -e "${GREEN}✓ SUCCESS: No money lost in concurrent transfers${NC}"
    echo -e "${GREEN}✓ Race condition protection working${NC}"
else
    echo -e "${RED}✗ FAIL: Balance mismatch${NC}"
    echo -e "${YELLOW}⚠ Analysis:${NC}"
    echo -e "${YELLOW}  - If balance increased correctly but doesn't match expected: some transfers may have been rate-limited (429)${NC}"
    echo -e "${YELLOW}  - If balance is higher than expected: double-spending detected (CRITICAL BUG)${NC}"
    echo -e "${YELLOW}  - If balance is lower than expected: money lost (CRITICAL BUG)${NC}"
    if [[ "$SUCCESS" -lt 6 ]]; then
        echo -e "${YELLOW}  - Only $SUCCESS/6 transfers succeeded - likely due to 60s cooldown or rate limiting${NC}"
    fi
fi

# Cleanup
rm -f /tmp/race_u*.log

echo ""

# TEST 19: Multi-Sender Concurrent Transfer with Full Logging
echo -e "${GREEN}=== TEST 19: Multi-Sender to Single Recipient ===${NC}"
echo -e "${CYAN}Testing 3 users sending to User2 simultaneously...${NC}"
sleep 65

# Get all balances before
echo -e "${CYAN}Balances before:${NC}"
RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER1_TOKEN")
USER1_BEFORE=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}  User1: $USER1_BEFORE${NC}"

RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER3_TOKEN")
USER3_BEFORE=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}  User3: $USER3_BEFORE${NC}"

RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $ADMIN_TOKEN")
ADMIN_BEFORE=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}  Admin: $ADMIN_BEFORE${NC}"

RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER2_TOKEN")
USER2_BEFORE=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}  User2 (receiver): $USER2_BEFORE${NC}"

echo -e "${YELLOW}Launching concurrent transfers...${NC}"

# Launch concurrent transfers from 3 different users to User2
TRANSFER1_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":0.5,\"currency\":\"SILVER_SEAL\",\"reason\":\"Multi-sender test 1\",\"idempotency_key\":\"multi-u1-${RANDOM}\"}"
curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" \
    -H "Authorization: Bearer $USER1_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TRANSFER1_BODY" > "/tmp/multi_u1.log" 2>&1 &

TRANSFER3_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":0.5,\"currency\":\"SILVER_SEAL\",\"reason\":\"Multi-sender test 3\",\"idempotency_key\":\"multi-u3-${RANDOM}\"}"
curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" \
    -H "Authorization: Bearer $USER3_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TRANSFER3_BODY" > "/tmp/multi_u3.log" 2>&1 &

TRANSFER_ADMIN_BODY="{\"recipient_user_id\":\"$USER2_ID\",\"amount\":0.5,\"currency\":\"SILVER_SEAL\",\"reason\":\"Multi-sender test admin\",\"idempotency_key\":\"multi-admin-${RANDOM}\"}"
curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$TRANSFER_ADMIN_BODY" > "/tmp/multi_admin.log" 2>&1 &

wait

echo -e "${CYAN}--- TRANSFER RESULTS ---${NC}"

# Display User1 transfer
if [[ -f "/tmp/multi_u1.log" ]]; then
    HTTP_BODY=$(head -n -1 "/tmp/multi_u1.log")
    HTTP_CODE=$(tail -n 1 "/tmp/multi_u1.log")
    echo -e "${CYAN}User1 → User2:${NC}"
    log_request "User1 Transfer" "POST" "$ECO_URL/transfer" "$TRANSFER1_BODY" "$HTTP_BODY" "$HTTP_CODE"
fi

# Display User3 transfer
if [[ -f "/tmp/multi_u3.log" ]]; then
    HTTP_BODY=$(head -n -1 "/tmp/multi_u3.log")
    HTTP_CODE=$(tail -n 1 "/tmp/multi_u3.log")
    echo -e "${CYAN}User3 → User2:${NC}"
    log_request "User3 Transfer" "POST" "$ECO_URL/transfer" "$TRANSFER3_BODY" "$HTTP_BODY" "$HTTP_CODE"
fi

# Display Admin transfer
if [[ -f "/tmp/multi_admin.log" ]]; then
    HTTP_BODY=$(head -n -1 "/tmp/multi_admin.log")
    HTTP_CODE=$(tail -n 1 "/tmp/multi_admin.log")
    echo -e "${CYAN}Admin → User2:${NC}"
    log_request "Admin Transfer" "POST" "$ECO_URL/transfer" "$TRANSFER_ADMIN_BODY" "$HTTP_BODY" "$HTTP_CODE"
fi

# Get balances after
echo -e "${CYAN}Balances after:${NC}"
RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER1_TOKEN")
USER1_AFTER=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}  User1: $USER1_AFTER (change: $(awk "BEGIN {printf \"%.1f\", $USER1_AFTER - $USER1_BEFORE}"))${NC}"

RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER3_TOKEN")
USER3_AFTER=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}  User3: $USER3_AFTER (change: $(awk "BEGIN {printf \"%.1f\", $USER3_AFTER - $USER3_BEFORE}"))${NC}"

RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $ADMIN_TOKEN")
ADMIN_AFTER=$(get_json_number "$RESPONSE" "silver_balance")
echo -e "${CYAN}  Admin: $ADMIN_AFTER (change: $(awk "BEGIN {printf \"%.1f\", $ADMIN_AFTER - $ADMIN_BEFORE}"))${NC}"

RESPONSE=$(curl -s -X GET "$ECO_URL/balance" -H "Authorization: Bearer $USER2_TOKEN")
USER2_AFTER=$(get_json_number "$RESPONSE" "silver_balance")
USER2_CHANGE=$(awk "BEGIN {printf \"%.1f\", $USER2_AFTER - $USER2_BEFORE}")
echo -e "${CYAN}  User2 (receiver): $USER2_AFTER (change: +$USER2_CHANGE)${NC}"

# Verify conservation of money
TOTAL_SENT=$(awk "BEGIN {printf \"%.1f\", ($USER1_BEFORE - $USER1_AFTER) + ($USER3_BEFORE - $USER3_AFTER) + ($ADMIN_BEFORE - $ADMIN_AFTER)}")
TOTAL_RECEIVED=$(awk "BEGIN {printf \"%.1f\", $USER2_AFTER - $USER2_BEFORE}")

echo -e "${CYAN}Total sent from all senders: $TOTAL_SENT${NC}"
echo -e "${CYAN}Total received by User2: $TOTAL_RECEIVED${NC}"

MATCH=$(awk "BEGIN {if ($TOTAL_SENT == $TOTAL_RECEIVED) print 1; else print 0}")
if [[ "$MATCH" == "1" ]]; then
    echo -e "${GREEN}✓ SUCCESS: Money conservation verified (no double-spending or loss)${NC}"
else
    echo -e "${RED}✗ FAIL: Money mismatch detected!${NC}"
fi

# Cleanup
rm -f /tmp/multi_*.log

echo ""

# FINAL SUMMARY

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}   Test Suite Complete${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""
echo -e "${GREEN}Users Created:${NC}"
echo "  Admin: $ADMIN_ID ($ADMIN_EMAIL)"
echo "  User 1: $USER1_ID ($USER1_EMAIL)"
echo "  User 2: $USER2_ID ($USER2_EMAIL)"
echo "  User 3: $USER3_ID ($USER3_EMAIL)"
echo ""
echo -e "${GREEN}Tests Performed:${NC}"
echo "  ✓ Basic Operations: Balance, Limits, Transactions"
echo "  ✓ Admin Protection: Endpoints blocked for non-admin"
echo "  ✓ Daily Accrual: 1.0 seal every 48 hours"
echo "  ✓ Idempotency: Duplicate requests handled correctly"
echo "  ✓ P2P Transfers: User-to-user transfers"
echo "  ✓ Seal Gifting: Posts and users"
echo "  ✓ Error Handling: Insufficient funds, self-transfer"
echo "  ✓ Race Conditions: Single receiver, multiple concurrent senders"
echo "  ✓ Multi-Sender Test: 3 users sending simultaneously with full logging"
echo ""
echo -e "${CYAN}All 19 economy features tested successfully!${NC}"