#!/bin/bash

BASE_URL="http://localhost:8081/api/v1"
TIMESTAMP=$(date +%s)

echo "============================================"
echo "=== Ranks Module Integration Test ==="
echo "============================================"
echo ""

USER1_EMAIL="ranktest1_${TIMESTAMP}@example.com"
USER1_PASS="Password123!"
USER1_FIRST="Alice"
USER1_LAST="Pearl"

USER2_EMAIL="ranktest2_${TIMESTAMP}@example.com"
USER2_PASS="Password123!"
USER2_FIRST="Bob"
USER2_LAST="Moonstone"

USER3_EMAIL="ranktest3_${TIMESTAMP}@example.com"
USER3_PASS="Password123!"
USER3_FIRST="Charlie"
USER3_LAST="Jade"

ADMIN_EMAIL="admin@brightbund.com"
ADMIN_PASS="admin123"

echo "=== Step 1: Register User 1 (Alice) ==="
echo "Request Body:"
REGISTER1_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASS\",\"first_name\":\"$USER1_FIRST\",\"last_name\":\"$USER1_LAST\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"device1\",\"app_version\":\"1.0.0\"}"
echo "$REGISTER1_BODY"
echo ""
echo "Response:"
REGISTER1_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "$REGISTER1_BODY")
echo "$REGISTER1_RESPONSE"
echo ""
echo "---"
echo ""

echo "=== Step 2: Register User 2 (Bob) ==="
echo "Request Body:"
REGISTER2_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASS\",\"first_name\":\"$USER2_FIRST\",\"last_name\":\"$USER2_LAST\",\"date_of_birth\":\"1999-05-15\",\"device_id\":\"device2\",\"app_version\":\"1.0.0\"}"
echo "$REGISTER2_BODY"
echo ""
echo "Response:"
REGISTER2_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "$REGISTER2_BODY")
echo "$REGISTER2_RESPONSE"
echo ""
echo "---"
echo ""

echo "=== Step 3: Register User 3 (Charlie) ==="
echo "Request Body:"
REGISTER3_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER3_PASS\",\"first_name\":\"$USER3_FIRST\",\"last_name\":\"$USER3_LAST\",\"date_of_birth\":\"1998-12-25\",\"device_id\":\"device3\",\"app_version\":\"1.0.0\"}"
echo "$REGISTER3_BODY"
echo ""
echo "Response:"
REGISTER3_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "$REGISTER3_BODY")
echo "$REGISTER3_RESPONSE"
echo ""
echo "---"
echo ""

echo "=== Step 4: Login User 1 (Alice) ==="
echo "Request Body:"
LOGIN1_BODY="{\"email\":\"$USER1_EMAIL\",\"password\":\"$USER1_PASS\",\"device_id\":\"device1\"}"
echo "$LOGIN1_BODY"
echo ""
echo "Response:"
LOGIN1_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login-email" \
  -H "Content-Type: application/json" \
  -d "$LOGIN1_BODY")
echo "$LOGIN1_RESPONSE"
echo ""
USER1_TOKEN=$(echo "$LOGIN1_RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
USER1_ID=$(echo "$LOGIN1_RESPONSE" | grep -o '"user_id":"[^"]*' | sed 's/"user_id":"//')
echo "Extracted Token: Bearer $USER1_TOKEN"
echo "Extracted User ID: $USER1_ID"
echo ""
echo "---"
echo ""

echo "=== Step 5: Login User 2 (Bob) ==="
echo "Request Body:"
LOGIN2_BODY="{\"email\":\"$USER2_EMAIL\",\"password\":\"$USER2_PASS\",\"device_id\":\"device2\"}"
echo "$LOGIN2_BODY"
echo ""
echo "Response:"
LOGIN2_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login-email" \
  -H "Content-Type: application/json" \
  -d "$LOGIN2_BODY")
echo "$LOGIN2_RESPONSE"
echo ""
USER2_TOKEN=$(echo "$LOGIN2_RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
USER2_ID=$(echo "$LOGIN2_RESPONSE" | grep -o '"user_id":"[^"]*' | sed 's/"user_id":"//')
echo "Extracted Token: Bearer $USER2_TOKEN"
echo "Extracted User ID: $USER2_ID"
echo ""
echo "---"
echo ""

echo "=== Step 6: Login User 3 (Charlie) ==="
echo "Request Body:"
LOGIN3_BODY="{\"email\":\"$USER3_EMAIL\",\"password\":\"$USER3_PASS\",\"device_id\":\"device3\"}"
echo "$LOGIN3_BODY"
echo ""
echo "Response:"
LOGIN3_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login-email" \
  -H "Content-Type: application/json" \
  -d "$LOGIN3_BODY")
echo "$LOGIN3_RESPONSE"
echo ""
USER3_TOKEN=$(echo "$LOGIN3_RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
USER3_ID=$(echo "$LOGIN3_RESPONSE" | grep -o '"user_id":"[^"]*' | sed 's/"user_id":"//')
echo "Extracted Token: Bearer $USER3_TOKEN"
echo "Extracted User ID: $USER3_ID"
echo ""
echo "---"
echo ""

echo "=== Step 7: Login Admin ==="
echo "Request Body:"
ADMIN_LOGIN_BODY="{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\",\"device_id\":\"admin_device\"}"
echo "$ADMIN_LOGIN_BODY"
echo ""
echo "Response:"
ADMIN_LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login-email" \
  -H "Content-Type: application/json" \
  -d "$ADMIN_LOGIN_BODY")
echo "$ADMIN_LOGIN_RESPONSE"
echo ""
ADMIN_TOKEN=$(echo "$ADMIN_LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*' | sed 's/"access_token":"//')
echo "Extracted Admin Token: Bearer $ADMIN_TOKEN"
echo ""
echo "---"
echo ""

echo "=== Step 8: Give User 1 (Alice) 1500 Gold Seals (150 seals after division) ==="
echo "Request Body:"
ADJUST1_BODY="{\"user_id\":\"$USER1_ID\",\"currency\":\"GOLD_SEAL\",\"amount\":150000,\"reason\":\"Test - Ammolite rank\"}"
echo "$ADJUST1_BODY"
echo ""
echo "Auth Header:"
echo "Authorization: Bearer $ADMIN_TOKEN"
echo ""
echo "Response:"
curl -s -X POST "$BASE_URL/economy/admin/adjust" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d "$ADJUST1_BODY"
echo ""
echo ""
echo "---"
echo ""

echo "=== Step 9: Give User 2 (Bob) 5000 Gold Seals (50 seals after division) ==="
echo "Request Body:"
ADJUST2_BODY="{\"user_id\":\"$USER2_ID\",\"currency\":\"GOLD_SEAL\",\"amount\":5000,\"reason\":\"Test - Jade rank\"}"
echo "$ADJUST2_BODY"
echo ""
echo "Auth Header:"
echo "Authorization: Bearer $ADMIN_TOKEN"
echo ""
echo "Response:"
curl -s -X POST "$BASE_URL/economy/admin/adjust" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d "$ADJUST2_BODY"
echo ""
echo ""
echo "---"
echo ""

echo "=== Step 10: Test GET /profiles/ranks (Public Endpoint) ==="
echo "Auth Header: None (public)"
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/profiles/ranks"
echo ""
echo ""
echo "---"
echo ""

echo "=== Step 11: Get User 1 (Alice) Rank - Should be Ammolite | Fortitude | A ==="
echo "Auth Header:"
echo "Authorization: Bearer $USER1_TOKEN"
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/profiles/me/rank" \
  -H "Authorization: Bearer $USER1_TOKEN"
echo ""
echo ""
echo "---"
echo ""

echo "=== Step 12: Get User 2 (Bob) Rank - Should be Jade | Integrity | A ==="
echo "Auth Header:"
echo "Authorization: Bearer $USER2_TOKEN"
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/profiles/me/rank" \
  -H "Authorization: Bearer $USER2_TOKEN"
echo ""
echo ""
echo "---"
echo ""

echo "=== Step 13: Get User 3 (Charlie) Rank - Should be Pearl | Origin | C (0 seals) ==="
echo "Auth Header:"
echo "Authorization: Bearer $USER3_TOKEN"
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/profiles/me/rank" \
  -H "Authorization: Bearer $USER3_TOKEN"
echo ""
echo ""
echo "---"
echo ""

echo "=== Step 14: Get User 1 Profile - Verify rank_tier field ==="
echo "Auth Header:"
echo "Authorization: Bearer $USER1_TOKEN"
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/profiles/me" \
  -H "Authorization: Bearer $USER1_TOKEN"
echo ""
echo ""
echo "---"
echo ""

echo "============================================"
echo "=== Ranks Module Integration Test Complete ==="
echo "============================================"
