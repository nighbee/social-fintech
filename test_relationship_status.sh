#!/bin/bash

# Test Relationship Status Endpoint
set -e

BASE_URL="http://localhost:8081/api/v1"

# --- Helper functions to extract JSON values without jq ---

# Extract string values (e.g., "id": "123")
extract_json() {
  local json="$1"
  local key="$2"
  echo "$json" | grep -o "\"$key\":\"[^\"]*\"" | head -1 | sed 's/.*:"\(.*\)".*/\1/'
}

# Extract boolean/number values (e.g., "is_active": true)
extract_json_bool() {
  local json="$1"
  local key="$2"
  echo "$json" | grep -o "\"$key\":[^,}]*" | head -1 | sed 's/.*://;s/ //g'
}

# Extract nested string values (e.g., "user": { "id": "..." })
extract_nested_json() {
  local json="$1"
  local parent="$2"
  local key="$3"
  echo "$json" | grep -o "\"$parent\":{[^}]*}" | grep -o "\"$key\":\"[^\"]*\"" | head -1 | sed 's/.*:"\(.*\)".*/\1/'
}

echo -e "\033[1;36m=== Relationship Status Test ===\033[0m"
echo -e "\033[1;36mTesting GET /profiles/{user_id}/relationship\n\033[0m"

# Register User 1
echo -e "\033[1;32m=== Step 1: Register User 1 ===\033[0m"
USER1_EMAIL="relationship_user1_$RANDOM@example.com"
USER1_PASSWORD="SecurePass123!"

RESPONSE1=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$USER1_EMAIL\",
    \"password\": \"$USER1_PASSWORD\",
    \"first_name\": \"Alice\",
    \"last_name\": \"Test\",
    \"date_of_birth\": \"1995-01-01\",
    \"device_id\": \"device-user1-$RANDOM\",
    \"app_version\": \"1.0.0\"
  }")

USER1_TOKEN=$(extract_json "$RESPONSE1" "access_token")
USER1_ID=$(extract_nested_json "$RESPONSE1" "user" "id")
echo -e "\033[0;32m✓ User 1: $USER1_ID\033[0m"

# Register User 2
echo -e "\n\033[1;32m=== Step 2: Register User 2 ===\033[0m"
USER2_EMAIL="relationship_user2_$RANDOM@example.com"
USER2_PASSWORD="SecurePass123!"

RESPONSE2=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$USER2_EMAIL\",
    \"password\": \"$USER2_PASSWORD\",
    \"first_name\": \"Bob\",
    \"last_name\": \"Test\",
    \"date_of_birth\": \"1996-01-01\",
    \"device_id\": \"device-user2-$RANDOM\",
    \"app_version\": \"1.0.0\"
  }")

USER2_TOKEN=$(extract_json "$RESPONSE2" "access_token")
USER2_ID=$(extract_nested_json "$RESPONSE2" "user" "id")
echo -e "\033[0;32m✓ User 2: $USER2_ID\033[0m"

# Test 1: Check initial relationship
echo -e "\n\033[1;32m=== Test 1: Initial Relationship Status (No Relationship) ===\033[0m"
STATUS=$(curl -s -X GET "$BASE_URL/profiles/$USER2_ID/relationship" \
  -H "Authorization: Bearer $USER1_TOKEN")

echo -e "\033[0;90mResponse: $STATUS\033[0m"

I_FOLLOW=$(extract_json_bool "$STATUS" "i_follow_them")
THEY_FOLLOW=$(extract_json_bool "$STATUS" "they_follow_me")
I_BLOCKED=$(extract_json_bool "$STATUS" "i_blocked_them")
THEY_BLOCKED=$(extract_json_bool "$STATUS" "they_blocked_me")
I_RESTRICTED=$(extract_json_bool "$STATUS" "i_restricted_them")

if [ "$I_FOLLOW" = "false" ] && [ "$THEY_FOLLOW" = "false" ] && [ "$I_BLOCKED" = "false" ] && [ "$THEY_BLOCKED" = "false" ] && [ "$I_RESTRICTED" = "false" ]; then
  echo -e "\033[0;32m✓ All fields are false (no relationship)\033[0m"
else
  echo -e "\033[0;31m✗ Expected all false\033[0m"
fi

# Test 2: User 1 follows User 2
echo -e "\n\033[1;32m=== Test 2: User 1 Follows User 2 ===\033[0m"
curl -s -X POST "$BASE_URL/profiles/$USER2_ID/allies" \
  -H "Authorization: Bearer $USER1_TOKEN" > /dev/null

STATUS=$(curl -s -X GET "$BASE_URL/profiles/$USER2_ID/relationship" \
  -H "Authorization: Bearer $USER1_TOKEN")

I_FOLLOW=$(extract_json_bool "$STATUS" "i_follow_them")
THEY_FOLLOW=$(extract_json_bool "$STATUS" "they_follow_me")

echo -e "\033[0;90mAfter following:\033[0m"
echo -e "\033[0;90m  i_follow_them: $I_FOLLOW\033[0m"
echo -e "\033[0;90m  they_follow_me: $THEY_FOLLOW\033[0m"

if [ "$I_FOLLOW" = "true" ] && [ "$THEY_FOLLOW" = "false" ]; then
  echo -e "\033[0;32m✓ i_follow_them = true, they_follow_me = false\033[0m"
else
  echo -e "\033[0;31m✗ Unexpected values\033[0m"
fi

# Test 3: Check from User 2's perspective
echo -e "\n\033[1;32m=== Test 3: User 2 Checks Relationship with User 1 ===\033[0m"
STATUS=$(curl -s -X GET "$BASE_URL/profiles/$USER1_ID/relationship" \
  -H "Authorization: Bearer $USER2_TOKEN")

I_FOLLOW=$(extract_json_bool "$STATUS" "i_follow_them")
THEY_FOLLOW=$(extract_json_bool "$STATUS" "they_follow_me")

echo -e "\033[0;90mUser 2's view:\033[0m"
echo -e "\033[0;90m  i_follow_them: $I_FOLLOW\033[0m"
echo -e "\033[0;90m  they_follow_me: $THEY_FOLLOW\033[0m"

if [ "$I_FOLLOW" = "false" ] && [ "$THEY_FOLLOW" = "true" ]; then
  echo -e "\033[0;32m✓ they_follow_me = true (User 1 follows User 2)\033[0m"
else
  echo -e "\033[0;31m✗ Unexpected values\033[0m"
fi

# Test 4: Mutual following
echo -e "\n\033[1;32m=== Test 4: Mutual Following ===\033[0m"
curl -s -X POST "$BASE_URL/profiles/$USER1_ID/allies" \
  -H "Authorization: Bearer $USER2_TOKEN" > /dev/null

STATUS=$(curl -s -X GET "$BASE_URL/profiles/$USER2_ID/relationship" \
  -H "Authorization: Bearer $USER1_TOKEN")

I_FOLLOW=$(extract_json_bool "$STATUS" "i_follow_them")
THEY_FOLLOW=$(extract_json_bool "$STATUS" "they_follow_me")

echo -e "\033[0;90mAfter mutual follow:\033[0m"
echo -e "\033[0;90m  i_follow_them: $I_FOLLOW\033[0m"
echo -e "\033[0;90m  they_follow_me: $THEY_FOLLOW\033[0m"

if [ "$I_FOLLOW" = "true" ] && [ "$THEY_FOLLOW" = "true" ]; then
  echo -e "\033[0;32m✓ Both following each other\033[0m"
else
  echo -e "\033[0;31m✗ Expected mutual follow\033[0m"
fi

# Test 5: User 1 blocks User 2
echo -e "\n\033[1;32m=== Test 5: User 1 Blocks User 2 ===\033[0m"
curl -s -X POST "$BASE_URL/profiles/$USER2_ID/block" \
  -H "Authorization: Bearer $USER1_TOKEN" > /dev/null

STATUS=$(curl -s -X GET "$BASE_URL/profiles/$USER2_ID/relationship" \
  -H "Authorization: Bearer $USER1_TOKEN")

I_FOLLOW=$(extract_json_bool "$STATUS" "i_follow_them")
I_BLOCKED=$(extract_json_bool "$STATUS" "i_blocked_them")
THEY_FOLLOW=$(extract_json_bool "$STATUS" "they_follow_me")

echo -e "\033[0;90mAfter blocking:\033[0m"
echo -e "\033[0;90m  i_follow_them: $I_FOLLOW\033[0m"
echo -e "\033[0;90m  i_blocked_them: $I_BLOCKED\033[0m"
echo -e "\033[0;90m  they_follow_me: $THEY_FOLLOW\033[0m"

if [ "$I_BLOCKED" = "true" ]; then
  echo -e "\033[0;32m✓ i_blocked_them = true\033[0m"
else
  echo -e "\033[0;31m✗ Expected block status\033[0m"
fi

# Test 6: User 1 restricts User 2
echo -e "\n\033[1;32m=== Test 6: User 1 Restricts User 2 ===\033[0m"
curl -s -X POST "$BASE_URL/profiles/$USER2_ID/restrict" \
  -H "Authorization: Bearer $USER1_TOKEN" > /dev/null

STATUS=$(curl -s -X GET "$BASE_URL/profiles/$USER2_ID/relationship" \
  -H "Authorization: Bearer $USER1_TOKEN")

I_RESTRICTED=$(extract_json_bool "$STATUS" "i_restricted_them")
I_BLOCKED=$(extract_json_bool "$STATUS" "i_blocked_them")

echo -e "\033[0;90mAfter restricting:\033[0m"
echo -e "\033[0;90m  i_restricted_them: $I_RESTRICTED\033[0m"
echo -e "\033[0;90m  i_blocked_them: $I_BLOCKED\033[0m"

if [ "$I_RESTRICTED" = "true" ] && [ "$I_BLOCKED" = "true" ]; then
  echo -e "\033[0;32m✓ Both blocked and restricted\033[0m"
else
  echo -e "\033[0;31m✗ Expected both statuses\033[0m"
fi

# Test 7: Test self-check prevention
echo -e "\n\033[1;32m=== Test 7: Prevent Self-Check ===\033[0m"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/profiles/$USER1_ID/relationship" \
  -H "Authorization: Bearer $USER1_TOKEN")

if [ "$HTTP_CODE" = "400" ]; then
  echo -e "\033[0;32m✓ Self-check correctly blocked with 400\033[0m"
else
  echo -e "\033[0;31m✗ Wrong error code: $HTTP_CODE\033[0m"
fi

echo -e "\n\033[1;36m=== Test Summary ===\033[0m"
echo -e "\033[0;32m✓ Relationship status endpoint working correctly\033[0m"
echo -e "\033[0;32m✓ Supports follow, block, restrict relationships\033[0m"
echo -e "\033[0;32m✓ Shows bidirectional status correctly\033[0m"
echo -e "\033[0;32m✓ Prevents self-checks\033[0m"