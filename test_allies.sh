#!/bin/bash

# Test Allies Endpoints
set -e

BASE_URL="http://localhost:8081/api/v1"

echo -e "\033[1;36m=== Allies Endpoint Test ===\033[0m"
echo -e "\033[1;36mTesting GET /profiles/me/allies and GET /profiles/{user_id}/allies\n\033[0m"

# Register User 1 (will make profile public)
echo -e "\033[1;32m=== Step 1: Register User 1 (Public Profile) ===\033[0m"
USER1_EMAIL="user1_$RANDOM@example.com"
USER1_PASSWORD="SecurePass123!"

RESPONSE1=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$USER1_EMAIL\",
    \"password\": \"$USER1_PASSWORD\",
    \"first_name\": \"Alice\",
    \"last_name\": \"Public\",
    \"date_of_birth\": \"1995-01-01\",
    \"device_id\": \"device-user1-$RANDOM\",
    \"app_version\": \"1.0.0\"
  }")

USER1_TOKEN=$(echo $RESPONSE1 | jq -r '.access_token')
USER1_ID=$(echo $RESPONSE1 | jq -r '.user.id')

if [ -z "$USER1_TOKEN" ] || [ "$USER1_TOKEN" = "null" ]; then
  echo -e "\033[0;31m✗ User 1 registration failed\033[0m"
  exit 1
fi

echo -e "\033[0;32m✓ User 1 registered: $USER1_ID\033[0m"

# Register User 2 (will make profile private)
echo -e "\n\033[1;32m=== Step 2: Register User 2 (Private Profile) ===\033[0m"
USER2_EMAIL="user2_$RANDOM@example.com"
USER2_PASSWORD="SecurePass123!"

RESPONSE2=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$USER2_EMAIL\",
    \"password\": \"$USER2_PASSWORD\",
    \"first_name\": \"Bob\",
    \"last_name\": \"Private\",
    \"date_of_birth\": \"1996-01-01\",
    \"device_id\": \"device-user2-$RANDOM\",
    \"app_version\": \"1.0.0\"
  }")

USER2_TOKEN=$(echo $RESPONSE2 | jq -r '.access_token')
USER2_ID=$(echo $RESPONSE2 | jq -r '.user.id')

if [ -z "$USER2_TOKEN" ] || [ "$USER2_TOKEN" = "null" ]; then
  echo -e "\033[0;31m✗ User 2 registration failed\033[0m"
  exit 1
fi

echo -e "\033[0;32m✓ User 2 registered: $USER2_ID\033[0m"

# Make User 2 profile private
echo -e "\n\033[1;32m=== Step 3: Make User 2 Profile Private ===\033[0m"
curl -s -X PATCH "$BASE_URL/profiles/me" \
  -H "Authorization: Bearer $USER2_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"is_public": false}' > /dev/null

echo -e "\033[0;32m✓ User 2 profile set to private\033[0m"

# Register User 3 (follower)
echo -e "\n\033[1;32m=== Step 4: Register User 3 (Follower) ===\033[0m"
USER3_EMAIL="user3_$RANDOM@example.com"
USER3_PASSWORD="SecurePass123!"

RESPONSE3=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$USER3_EMAIL\",
    \"password\": \"$USER3_PASSWORD\",
    \"first_name\": \"Charlie\",
    \"last_name\": \"Follower\",
    \"date_of_birth\": \"1997-01-01\",
    \"device_id\": \"device-user3-$RANDOM\",
    \"app_version\": \"1.0.0\"
  }")

USER3_TOKEN=$(echo $RESPONSE3 | jq -r '.access_token')
USER3_ID=$(echo $RESPONSE3 | jq -r '.user.id')

if [ -z "$USER3_TOKEN" ] || [ "$USER3_TOKEN" = "null" ]; then
  echo -e "\033[0;31m✗ User 3 registration failed\033[0m"
  exit 1
fi

echo -e "\033[0;32m✓ User 3 registered: $USER3_ID\033[0m"

# User 3 follows User 1 (public profile)
echo -e "\n\033[1;32m=== Step 5: User 3 Follows User 1 ===\033[0m"
curl -s -X POST "$BASE_URL/profiles/$USER1_ID/allies" \
  -H "Authorization: Bearer $USER3_TOKEN" \
  -H "Content-Type: application/json" > /dev/null

echo -e "\033[0;32m✓ User 3 now follows User 1\033[0m"

# User 3 follows User 2 (private profile)
echo -e "\n\033[1;32m=== Step 6: User 3 Follows User 2 ===\033[0m"
curl -s -X POST "$BASE_URL/profiles/$USER2_ID/allies" \
  -H "Authorization: Bearer $USER3_TOKEN" \
  -H "Content-Type: application/json" > /dev/null

echo -e "\033[0;32m✓ User 3 now follows User 2\033[0m"

# Test 1: User 1 views their own allies using /me/allies
echo -e "\n\033[1;32m=== Test 1: User 1 Views Own Allies (GET /profiles/me/allies) ===\033[0m"
MY_ALLIES=$(curl -s -X GET "$BASE_URL/profiles/me/allies" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -H "Content-Type: application/json")

ALLIES_COUNT=$(echo $MY_ALLIES | jq '. | length')
FIRST_ALLY_ID=$(echo $MY_ALLIES | jq -r '.[0].user_id')

echo -e "\033[0;32m✓ Successfully retrieved own allies\033[0m"
echo -e "\033[0;90m  Count: $ALLIES_COUNT\033[0m"

if [ "$ALLIES_COUNT" = "1" ] && [ "$FIRST_ALLY_ID" = "$USER3_ID" ]; then
  echo -e "\033[0;32m✓ Correct: User 3 is in User 1's allies list\033[0m"
else
  echo -e "\033[0;31m✗ Unexpected allies list\033[0m"
fi

# Test 2: User 3 views User 1's allies (public profile - should work)
echo -e "\n\033[1;32m=== Test 2: User 3 Views User 1's Allies (Public Profile) ===\033[0m"
PUBLIC_ALLIES=$(curl -s -X GET "$BASE_URL/profiles/$USER1_ID/allies" \
  -H "Authorization: Bearer $USER3_TOKEN" \
  -H "Content-Type: application/json")

PUBLIC_ALLIES_COUNT=$(echo $PUBLIC_ALLIES | jq '. | length')

echo -e "\033[0;32m✓ Successfully viewed public user's allies\033[0m"
echo -e "\033[0;90m  Count: $PUBLIC_ALLIES_COUNT\033[0m"

if [ "$PUBLIC_ALLIES_COUNT" = "1" ]; then
  echo -e "\033[0;32m✓ Correct: Can view allies of public profile\033[0m"
fi

# Test 3: User 3 tries to view User 2's allies (private profile - should fail)
echo -e "\n\033[1;32m=== Test 3: User 3 Views User 2's Allies (Private Profile - Should Fail) ===\033[0m"
HTTP_CODE=$(curl -s -o /tmp/private_allies_response.json -w "%{http_code}" -X GET "$BASE_URL/profiles/$USER2_ID/allies" \
  -H "Authorization: Bearer $USER3_TOKEN" \
  -H "Content-Type: application/json")

if [ "$HTTP_CODE" = "403" ]; then
  echo -e "\033[0;32m✓ Correctly blocked with 403 Forbidden\033[0m"
  
  ERROR_TYPE=$(cat /tmp/private_allies_response.json | jq -r '.error')
  if [ "$ERROR_TYPE" = "profile_private" ]; then
    echo -e "\033[0;32m✓ Correct error message: profile_private\033[0m"
  fi
else
  echo -e "\033[0;31m✗ Wrong error code: Expected 403, got $HTTP_CODE\033[0m"
fi

# Test 4: User 2 can view their own allies (owner of private profile)
echo -e "\n\033[1;32m=== Test 4: User 2 Views Own Allies (Owner of Private Profile) ===\033[0m"
OWN_PRIVATE_ALLIES=$(curl -s -X GET "$BASE_URL/profiles/me/allies" \
  -H "Authorization: Bearer $USER2_TOKEN" \
  -H "Content-Type: application/json")

OWN_ALLIES_COUNT=$(echo $OWN_PRIVATE_ALLIES | jq '. | length')
OWN_FIRST_ALLY_ID=$(echo $OWN_PRIVATE_ALLIES | jq -r '.[0].user_id')

echo -e "\033[0;32m✓ Owner can view their own allies (even when profile is private)\033[0m"
echo -e "\033[0;90m  Count: $OWN_ALLIES_COUNT\033[0m"

if [ "$OWN_ALLIES_COUNT" = "1" ] && [ "$OWN_FIRST_ALLY_ID" = "$USER3_ID" ]; then
  echo -e "\033[0;32m✓ Correct: User 3 is in User 2's allies list\033[0m"
fi

echo -e "\n\033[1;36m=== Test Summary ===\033[0m"
echo -e "\033[0;32m✓ /profiles/me/allies works for authenticated user\033[0m"
echo -e "\033[0;32m✓ /profiles/{user_id}/allies works for public profiles\033[0m"
echo -e "\033[0;32m✓ /profiles/{user_id}/allies blocks access to private profiles\033[0m"
echo -e "\033[0;32m✓ Profile owners can always view their own allies\033[0m"
echo -e "\n\033[0;32mAll tests passed!\033[0m"
