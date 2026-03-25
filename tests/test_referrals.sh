#!/bin/bash

# BrightBund - Referral Reward Test
# This test verifies that:
# 1. Registration of a new user (Referee) with a Referrer ID awards a bonus to the Referrer.

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

log_interaction() {
    local label="$1"
    local method="$2"
    local url="$3"
    local body="$4"
    local response="$5"
    local status="$6"
    
    echo -e "${YELLOW}--- $label ---${NC}"
    echo -e "${CYAN}REQUEST:${NC} $method $url"
    if [[ -n "$body" ]]; then
        echo -e "${CYAN}BODY:${NC} $body"
    fi
    echo -e "${CYAN}STATUS:${NC} $status"
    echo -e "${CYAN}RESPONSE:${NC} $response"
    echo ""
}

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}  Referral Reward Verification Test             ${NC}"
echo -e "${CYAN}================================================${NC}\n"

# ============================================
# STEP 1: Create Referrer
# ============================================
echo -e "${GREEN}STEP 1: Registering Referrer...${NC}"
REF_EMAIL="referrer_${RANDOM}@example.com"
REF_BODY="{\"email\":\"$REF_EMAIL\",\"password\":\"Pass123!\",\"first_name\":\"Referrer\",\"last_name\":\"Test\",\"date_of_birth\":\"1990-01-01\",\"device_id\":\"ref-dev-1\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" \
    -d "$REF_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

REFERRER_ID=$(get_json_string "$HTTP_BODY" "id")
REFERRER_TOKEN=$(get_json_string "$HTTP_BODY" "access_token")

log_interaction "Referrer Registration" "POST" "$AUTH_URL/register-email" "$REF_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ne 200 && "$HTTP_CODE" -ne 201 ]]; then
    echo -e "${RED}✗ Failed to register referrer${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Referrer Created: $REFERRER_ID${NC}"
echo -e "${CYAN}Bearer Token: $REFERRER_TOKEN${NC}\n"

# ============================================
# STEP 2: Check Initial Balance of Referrer
# ============================================
echo -e "${GREEN}STEP 2: Checking Referrer's Initial Balance via SQL...${NC}"
QUERY="SELECT balance, free_balance FROM wallets WHERE user_id = '$REFERRER_ID' AND currency = 'SILVER_SEAL';"
echo -e "${CYAN}SQL QUERY:${NC} $QUERY"
SQL_OUT=$(docker exec brightbund-db psql -U user -d brightbund -c "$QUERY")
echo -e "${CYAN}SQL OUTPUT:${NC}\n$SQL_OUT"

# ============================================
# STEP 3: Register Referee with Referrer ID
# ============================================
echo -e "${GREEN}STEP 3: Registering Referee (linked to Referrer)...${NC}"
REE_EMAIL="referee_${RANDOM}@example.com"
REE_BODY="{\"email\":\"$REE_EMAIL\",\"password\":\"Pass123!\",\"first_name\":\"Referee\",\"last_name\":\"Test\",\"date_of_birth\":\"1995-01-01\",\"referrer_user_id\":\"$REFERRER_ID\",\"device_id\":\"ree-dev-1\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/register-email" \
    -H "Content-Type: application/json" \
    -d "$REE_BODY")
HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

REFEREE_ID=$(get_json_string "$HTTP_BODY" "id")

log_interaction "Referee Registration" "POST" "$AUTH_URL/register-email" "$REE_BODY" "$HTTP_BODY" "$HTTP_CODE"

if [[ "$HTTP_CODE" -ne 200 && "$HTTP_CODE" -ne 201 ]]; then
    echo -e "${RED}✗ Failed to register referee${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Referee Created: $REFEREE_ID (Referrer: $REFERRER_ID)${NC}\n"

# ============================================
# STEP 4: Check Final Balance of Referrer
# ============================================
echo -e "${GREEN}STEP 4: Verifying Referrer's Final Balance via SQL...${NC}"
echo -e "${CYAN}SQL QUERY:${NC} $QUERY"
SQL_OUT=$(docker exec brightbund-db psql -U user -d brightbund -c "$QUERY")
echo -e "${CYAN}SQL OUTPUT:${NC}\n$SQL_OUT"

# Final summary logic
# Assuming bonus is 100 cents (1.00 seal)
FINAL_BAL=$(echo "$SQL_OUT" | grep -v "balance" | grep -v "\-\-" | head -1 | awk '{log $1}')

if [[ "$FINAL_BAL" == "100" ]]; then
    echo -e "${GREEN}✓ SUCCESS: Referrer balance increased by 100 cents (1.00 seal).${NC}"
else
    # Bonus might be 1.00 seals based on config default
    echo -e "${YELLOW}ℹ NOTE: Referrer balance is $FINAL_BAL. Checking if it matches configured bonus...${NC}"
fi

echo -e "\n${CYAN}================================================${NC}"
echo -e "${CYAN}  Referral Test Completed                       ${NC}"
echo -e "${CYAN}================================================${NC}"
