#!/bin/bash

AUTH_URL="http://localhost:8081/api/v1/auth"
PROFILE_URL="http://localhost:8081/api/v1/profiles"

# Create test user
TEST_EMAIL="quicktest_${RANDOM}@example.com"
TEST_PASSWORD="SecurePass123!"

REGISTER_BODY="{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"first_name\":\"TestFirst\",\"last_name\":\"TestLast\",\"date_of_birth\":\"2000-01-01\",\"device_id\":\"test-device\",\"app_version\":\"1.0.0\"}"

RESPONSE=$(curl -s -X POST "$AUTH_URL/register-email" -H "Content-Type: application/json" -d "$REGISTER_BODY")
echo "Registration Response:"
echo "$RESPONSE" | python -m json.tool 2>/dev/null || echo "$RESPONSE"

USER_ID=$(echo "$RESPONSE" | grep -o '"id": *"[^"]*"' | head -1 | cut -d'"' -f4)
USERNAME=$(echo "$RESPONSE" | grep -o '"username": *"[^"]*"' | head -1 | cut -d'"' -f4)

echo ""
echo "User ID: $USER_ID"
echo "Username: $USERNAME"

# Login
LOGIN_BODY="{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"device_id\":\"test-device\"}"
RESPONSE=$(curl -s -X POST "$AUTH_URL/login-email" -H "Content-Type: application/json" -d "$LOGIN_BODY")
ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token": *"[^"]*"' | head -1 | cut -d'"' -f4)

# Update profile
UPDATE_BODY="{\"display_name\":\"Test User\",\"bio\":\"Test bio\",\"location_city\":\"Tokyo\",\"location_country\":\"Japan\",\"is_location_public\":true,\"is_profile_public\":true}"
RESPONSE=$(curl -s -X PUT "$PROFILE_URL/me" -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "$UPDATE_BODY")
echo ""
echo "Update Profile Response:"
echo "$RESPONSE" | python -m json.tool 2>/dev/null || echo "$RESPONSE"

# Get profile
RESPONSE=$(curl -s -X GET "$PROFILE_URL/$USERNAME")
echo ""
echo "Get Profile Response:"
echo "$RESPONSE" | python -m json.tool 2>/dev/null || echo "$RESPONSE"
