#!/bin/bash

# Test Partial Profile Update (PATCH semantics)
# This script tests updating only one field without affecting others

set -e

BASE_URL="http://localhost:8081/api/v1"

echo -e "\033[1;36m=== Profile Partial Update Test ===\033[0m"
echo -e "\033[1;36mTesting PATCH /profiles/me with single field update\n\033[0m"

# Step 1: Register a new user
echo -e "\033[1;32m=== Step 1: Register New User ===\033[0m"
TEST_EMAIL="testuser$RANDOM@example.com"
TEST_PASSWORD="SecurePass123!"

REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register-email" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\",
    \"first_name\": \"John\",
    \"last_name\": \"Doe\",
    \"date_of_birth\": \"2000-01-01\",
    \"device_id\": \"test-device-partial-$RANDOM\",
    \"app_version\": \"1.0.0-test\"
  }")

ACCESS_TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
USER_ID=$(echo $REGISTER_RESPONSE | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo -e "\033[0;31m✗ Registration failed!\033[0m"
  echo "Response: $REGISTER_RESPONSE"
  exit 1
fi

echo -e "\033[0;32m✓ Registration successful!\033[0m"
echo -e "\033[0;90m  User ID: $USER_ID\033[0m"
echo -e "\033[0;90m  Email: $TEST_EMAIL\033[0m"

# Step 2: Get initial profile
echo -e "\n\033[1;32m=== Step 2: Get Initial Profile ===\033[0m"
INITIAL_PROFILE=$(curl -s -X GET "$BASE_URL/profiles/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json")

echo -e "\033[0;32m✓ Initial profile retrieved!\033[0m"
echo "Initial Profile: $INITIAL_PROFILE" | jq '.'

INITIAL_DISPLAY_NAME=$(echo $INITIAL_PROFILE | jq -r '.display_name')
INITIAL_FIRST_NAME=$(echo $INITIAL_PROFILE | jq -r '.first_name')
INITIAL_LAST_NAME=$(echo $INITIAL_PROFILE | jq -r '.last_name')
INITIAL_BIO=$(echo $INITIAL_PROFILE | jq -r '.bio')

echo -e "\033[0;90m  Display Name: '$INITIAL_DISPLAY_NAME'\033[0m"
echo -e "\033[0;90m  First Name: '$INITIAL_FIRST_NAME'\033[0m"
echo -e "\033[0;90m  Last Name: '$INITIAL_LAST_NAME'\033[0m"
echo -e "\033[0;90m  Bio: '$INITIAL_BIO'\033[0m"

# Step 3: Update ONLY display_name (partial update)
echo -e "\n\033[1;32m=== Step 3: Update ONLY Display Name ===\033[0m"
echo -e "\033[1;33mSending JSON: { \"display_name\": \"Alice Wonder\" }\033[0m"

UPDATED_PROFILE=$(curl -s -X PATCH "$BASE_URL/profiles/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"display_name": "Alice Wonder"}')

echo -e "\033[0;32m✓ Profile updated successfully!\033[0m"
echo "Updated Profile: $UPDATED_PROFILE" | jq '.'

UPDATED_DISPLAY_NAME=$(echo $UPDATED_PROFILE | jq -r '.display_name')
UPDATED_FIRST_NAME=$(echo $UPDATED_PROFILE | jq -r '.first_name')
UPDATED_LAST_NAME=$(echo $UPDATED_PROFILE | jq -r '.last_name')
UPDATED_BIO=$(echo $UPDATED_PROFILE | jq -r '.bio')

# Step 4: Verify only display_name was updated
echo -e "\n\033[1;32m=== Step 4: Verification ===\033[0m"

ALL_TESTS_PASSED=true

if [ "$UPDATED_DISPLAY_NAME" = "Alice Wonder" ]; then
  echo -e "\033[0;32m✓ Display Name updated correctly: '$UPDATED_DISPLAY_NAME'\033[0m"
else
  echo -e "\033[0;31m✗ Display Name NOT updated! Expected 'Alice Wonder', got '$UPDATED_DISPLAY_NAME'\033[0m"
  ALL_TESTS_PASSED=false
fi

if [ "$UPDATED_FIRST_NAME" = "$INITIAL_FIRST_NAME" ]; then
  echo -e "\033[0;32m✓ First Name unchanged (correct): '$UPDATED_FIRST_NAME'\033[0m"
else
  echo -e "\033[0;31m✗ First Name was changed! Expected '$INITIAL_FIRST_NAME', got '$UPDATED_FIRST_NAME'\033[0m"
  ALL_TESTS_PASSED=false
fi

if [ "$UPDATED_LAST_NAME" = "$INITIAL_LAST_NAME" ]; then
  echo -e "\033[0;32m✓ Last Name unchanged (correct): '$UPDATED_LAST_NAME'\033[0m"
else
  echo -e "\033[0;31m✗ Last Name was changed! Expected '$INITIAL_LAST_NAME', got '$UPDATED_LAST_NAME'\033[0m"
  ALL_TESTS_PASSED=false
fi

if [ "$UPDATED_BIO" = "$INITIAL_BIO" ]; then
  echo -e "\033[0;32m✓ Bio unchanged (correct): '$UPDATED_BIO'\033[0m"
else
  echo -e "\033[0;31m✗ Bio was changed! Expected '$INITIAL_BIO', got '$UPDATED_BIO'\033[0m"
  ALL_TESTS_PASSED=false
fi

# Step 5: Test updating another single field (bio)
echo -e "\n\033[1;32m=== Step 5: Update ONLY Bio ===\033[0m"
echo -e "\033[1;33mSending JSON: { \"bio\": \"I love adventure!\" }\033[0m"

BIO_UPDATED_PROFILE=$(curl -s -X PATCH "$BASE_URL/profiles/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"bio": "I love adventure!"}')

echo -e "\033[0;32m✓ Bio updated successfully!\033[0m"
echo "Bio Updated Profile: $BIO_UPDATED_PROFILE" | jq '.'

BIO_UPDATED_BIO=$(echo $BIO_UPDATED_PROFILE | jq -r '.bio')
BIO_UPDATED_DISPLAY_NAME=$(echo $BIO_UPDATED_PROFILE | jq -r '.display_name')

if [ "$BIO_UPDATED_BIO" = "I love adventure!" ]; then
  echo -e "\033[0;32m✓ Bio updated correctly\033[0m"
else
  echo -e "\033[0;31m✗ Bio NOT updated correctly!\033[0m"
  ALL_TESTS_PASSED=false
fi

if [ "$BIO_UPDATED_DISPLAY_NAME" = "Alice Wonder" ]; then
  echo -e "\033[0;32m✓ Display Name still preserved from previous update\033[0m"
else
  echo -e "\033[0;31m✗ Display Name was lost!\033[0m"
  ALL_TESTS_PASSED=false
fi

# Step 6: Test invalid JSON (trailing comma)
echo -e "\n\033[1;32m=== Step 6: Test Invalid JSON (trailing comma) ===\033[0m"
echo -e "\033[1;33mSending invalid JSON with trailing comma...\033[0m"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/profiles/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"display_name": "Test Name",}')

if [ "$HTTP_CODE" = "400" ]; then
  echo -e "\033[0;32m✓ Invalid JSON correctly rejected with 400 Bad Request\033[0m"
else
  echo -e "\033[0;31m✗ Wrong error code! Expected 400, got $HTTP_CODE\033[0m"
  ALL_TESTS_PASSED=false
fi

# Final Summary
echo -e "\n\033[1;36m=== Test Summary ===\033[0m"
if [ "$ALL_TESTS_PASSED" = true ]; then
  echo -e "\033[0;32m✓ ALL TESTS PASSED! Partial update works correctly.\033[0m"
else
  echo -e "\033[0;31m✗ SOME TESTS FAILED! Check output above.\033[0m"
  exit 1
fi
