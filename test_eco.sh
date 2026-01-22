#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

AUTH_URL="http://localhost:8081/api/v1/auth"
ECO_URL="http://localhost:8081/api/v1/economy"

# --- Helper function to extract values from JSON using grep/sed ---
get_json_string() {
    echo "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | cut -d'"' -f4
}

get_json_number() {
    echo "$1" | grep -o "\"$2\": *[0-9.]*" | head -1 | grep -o "[0-9.]*"
}
# ------------------------------------------------------------------

echo -e "${CYAN}=== Economy Module Test Suite ===${NC}\n"

# Setup: Create two test users
echo -e "${GREEN}=== Setup: Creating Test Users ===${NC}"

# User 1
TEST_EMAIL_1="ecouser1_${RANDOM}@example.com"
TEST_PASSWORD="SecurePass123!"

REGISTER_BODY="{\"email\":\"$TEST_EMAIL_1\",\"password\":\"$TEST_PASSWORD\",\"first_name\":\"Alice\",\"last_name\":\"Smith\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"test-device-1\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ User 1 created${NC}"
    USER_ID_1=$(get_json_string "$HTTP_BODY" "id")
    echo "  User 1 ID: $USER_ID_1"
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

# User 2
TEST_EMAIL_2="ecouser2_${RANDOM}@example.com"
REGISTER_BODY="{\"email\":\"$TEST_EMAIL_2\",\"password\":\"$TEST_PASSWORD\",\"first_name\":\"Bob\",\"last_name\":\"Jones\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"test-device-2\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ User 2 created${NC}"
    USER_ID_2=$(get_json_string "$HTTP_BODY" "id")
    echo "  User 2 ID: $USER_ID_2"
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

echo ""

# Test 1: Get Balance (should show initial wallets)
echo -e "${GREEN}=== 1. Testing Get Balance (User 1) ===${NC}"
echo -e "${CYAN}Request: GET $ECO_URL/balance${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get balance successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    SILVER_BALANCE=$(get_json_number "$HTTP_BODY" "silver_balance")
    GOLD_BALANCE=$(get_json_number "$HTTP_BODY" "gold_balance")
    FREE_SILVER=$(get_json_number "$HTTP_BODY" "free_silver_balance")
    echo "  Silver Balance: $SILVER_BALANCE seals"
    echo "  Gold Balance: $GOLD_BALANCE seals"
    echo "  Free Silver: $FREE_SILVER seals"
else
    echo -e "${RED}✗ Get balance failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 2: Get Limits
echo -e "${GREEN}=== 2. Testing Get Limits ===${NC}"
echo -e "${CYAN}Request: GET $ECO_URL/limits${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/limits" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get limits successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    MONTHLY_LIMIT=$(get_json_number "$HTTP_BODY" "monthly_transfer_limit")
    MONTHLY_USED=$(get_json_number "$HTTP_BODY" "monthly_transferred")
    REMAINING=$(get_json_number "$HTTP_BODY" "remaining")
    echo "  Monthly Limit: $MONTHLY_LIMIT transfers"
    echo "  Used: $MONTHLY_USED"
    echo "  Remaining: $REMAINING"
else
    echo -e "${RED}✗ Get limits failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 3: Admin Adjust Balance (add some silver to test with)
echo -e "${GREEN}=== 3. Testing Admin Adjust Balance ===${NC}"
ADJUST_BODY="{\"user_id\":\"$USER_ID_1\",\"amount\":10.00,\"currency\":\"SILVER_SEAL\",\"reason\":\"Test funding\"}"
echo -e "${CYAN}Request: POST $ECO_URL/admin/adjust${NC}"
echo -e "${YELLOW}Request Body:${NC} $ADJUST_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/admin/adjust" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$ADJUST_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Balance adjusted successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${YELLOW}⚠ Admin adjust may require special permissions: HTTP $HTTP_CODE${NC}"
    echo -e "${YELLOW}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 4: Get Balance After Adjustment
echo -e "${GREEN}=== 4. Testing Get Balance After Adjustment ===${NC}"
echo -e "${CYAN}Request: GET $ECO_URL/balance${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get balance successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    SILVER_BALANCE=$(get_json_number "$HTTP_BODY" "silver_balance")
    echo "  Silver Balance: $SILVER_BALANCE seals"
else
    echo -e "${RED}✗ Get balance failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 5: Transfer Seals (P2P)
echo -e "${GREEN}=== 5. Testing Transfer Seals (P2P) ===${NC}"
TRANSFER_BODY="{\"recipient_user_id\":\"$USER_ID_2\",\"amount\":2.5,\"currency\":\"SILVER_SEAL\",\"reason\":\"Test transfer\"}"
echo -e "${CYAN}Request: POST $ECO_URL/transfer${NC}"
echo -e "${YELLOW}Request Body:${NC} $TRANSFER_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Transfer successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    LEDGER_ID=$(get_json_string "$HTTP_BODY" "ledger_entry_id")
    SENDER_BAL=$(get_json_number "$HTTP_BODY" "sender_balance")
    RECEIVER_BAL=$(get_json_number "$HTTP_BODY" "receiver_balance")
    echo "  Ledger Entry ID: $LEDGER_ID"
    echo "  Sender Balance: $SENDER_BAL seals"
    echo "  Receiver Balance: $RECEIVER_BAL seals"
else
    echo -e "${RED}✗ Transfer failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 6: Give Seal to Post
echo -e "${GREEN}=== 6. Testing Give Seal to Post ===${NC}"
POST_ID="test-post-${RANDOM}"
SEAL_BODY="{\"amount\":3,\"currency\":\"SILVER_SEAL\"}"
echo -e "${CYAN}Request: POST $ECO_URL/seal/post/$POST_ID${NC}"
echo -e "${YELLOW}Request Body:${NC} $SEAL_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/seal/post/$POST_ID" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$SEAL_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Seal given to post successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    SENDER_BAL=$(get_json_number "$HTTP_BODY" "sender_balance")
    echo "  Remaining Balance: $SENDER_BAL seals"
else
    echo -e "${RED}✗ Give seal to post failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 7: Give Seal to User
echo -e "${GREEN}=== 7. Testing Give Seal to User ===${NC}"
GIFT_BODY="{\"amount\":1.5,\"currency\":\"SILVER_SEAL\",\"message\":\"Thanks for the help!\"}"
echo -e "${CYAN}Request: POST $ECO_URL/seal/user/$USER_ID_2${NC}"
echo -e "${YELLOW}Request Body:${NC} $GIFT_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/seal/user/$USER_ID_2" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$GIFT_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Seal given to user successfully (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    SENDER_BAL=$(get_json_number "$HTTP_BODY" "sender_balance")
    RECEIVER_BAL=$(get_json_number "$HTTP_BODY" "receiver_balance")
    echo "  Sender Balance: $SENDER_BAL seals"
    echo "  Receiver Balance: $RECEIVER_BAL seals"
else
    echo -e "${RED}✗ Give seal to user failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 8: Get Transaction History
echo -e "${GREEN}=== 8. Testing Get Transaction History ===${NC}"
echo -e "${CYAN}Request: GET $ECO_URL/transactions?page=1&page_size=10${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/transactions?page=1&page_size=10" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Transaction history retrieved (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    TOTAL=$(get_json_number "$HTTP_BODY" "total")
    PAGE=$(get_json_number "$HTTP_BODY" "page")
    echo "  Total Transactions: $TOTAL"
    echo "  Current Page: $PAGE"
else
    echo -e "${RED}✗ Get transaction history failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 9: Get Referral Stats
echo -e "${GREEN}=== 9. Testing Get Referral Stats ===${NC}"
echo -e "${CYAN}Request: GET $ECO_URL/referral/stats${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/referral/stats" -H "Authorization: Bearer $ACCESS_TOKEN_1")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Referral stats retrieved (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    TOTAL_REFS=$(get_json_number "$HTTP_BODY" "total_referrals")
    ACTIVE_REFS=$(get_json_number "$HTTP_BODY" "active_referrals")
    TOTAL_EARNED=$(get_json_number "$HTTP_BODY" "total_earned")
    echo "  Total Referrals: $TOTAL_REFS"
    echo "  Active Referrals: $ACTIVE_REFS"
    echo "  Total Earned: $TOTAL_EARNED seals"
else
    echo -e "${RED}✗ Get referral stats failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 10: Check User 2 Balance (should have received transfers)
echo -e "${GREEN}=== 10. Testing User 2 Balance (Recipient) ===${NC}"
echo -e "${CYAN}Request: GET $ECO_URL/balance${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$ECO_URL/balance" -H "Authorization: Bearer $ACCESS_TOKEN_2")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo -e "${GREEN}✓ Get balance successful (HTTP $HTTP_CODE)${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
    SILVER_BALANCE=$(get_json_number "$HTTP_BODY" "silver_balance")
    echo "  Silver Balance: $SILVER_BALANCE seals (should include received transfers)"
else
    echo -e "${RED}✗ Get balance failed: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 11: Test Insufficient Funds Error
echo -e "${GREEN}=== 11. Testing Insufficient Funds Error ===${NC}"
TRANSFER_BODY="{\"recipient_user_id\":\"$USER_ID_2\",\"amount\":9999.99,\"currency\":\"SILVER_SEAL\",\"reason\":\"This should fail\"}"
echo -e "${CYAN}Request: POST $ECO_URL/transfer${NC}"
echo -e "${YELLOW}Request Body:${NC} $TRANSFER_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -eq 402 ]]; then
    echo -e "${GREEN}✓ Correctly returned 402 Payment Required for insufficient funds${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
elif [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ Correctly returned error status: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Expected error status, got: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""

# Test 12: Test Self-Transfer Error
echo -e "${GREEN}=== 12. Testing Self-Transfer Prevention ===${NC}"
TRANSFER_BODY="{\"recipient_user_id\":\"$USER_ID_1\",\"amount\":1.0,\"currency\":\"SILVER_SEAL\",\"reason\":\"Self transfer should fail\"}"
echo -e "${CYAN}Request: POST $ECO_URL/transfer${NC}"
echo -e "${YELLOW}Request Body:${NC} $TRANSFER_BODY"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ECO_URL/transfer" -H "Authorization: Bearer $ACCESS_TOKEN_1" -H "Content-Type: application/json" -d "$TRANSFER_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" -ge 400 && "$HTTP_CODE" -lt 500 ]]; then
    echo -e "${GREEN}✓ Correctly prevented self-transfer: HTTP $HTTP_CODE${NC}"
    echo -e "${CYAN}Response Body:${NC}"
    echo "$HTTP_BODY"
else
    echo -e "${RED}✗ Self-transfer should have been rejected${NC}"
    echo -e "${RED}Response Body:${NC}"
    echo "$HTTP_BODY"
fi

echo ""
echo -e "${CYAN}=== All Economy Tests Complete ===${NC}"
echo -e "${CYAN}Summary:${NC}"
echo "  - User 1 ID: $USER_ID_1"
echo "  - User 2 ID: $USER_ID_2"
echo "  - All core economy features tested"
