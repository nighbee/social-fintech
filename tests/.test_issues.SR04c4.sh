#!/bin/bash

# Test script to replicate Flutter profile request

echo "=== Test 1: Using the exact token from Flutter (may be expired) ==="
curl -X GET "http://localhost/api/v1/profiles/5ff12d77-0c81-4b73-b168-855155d5180" \
  -H "Accept-Language: ru" \
  -H "content-type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzaWQiOiIwN2MzNjUyNC1lY2MyLTQ4M2MtODI2My03ZTRkM2EzMDU5MWYiLCJ0eXAiOiJhY2Nlc3MiLCJzdWIiOiI1ZmYxMmQ3Ny0wYzgxLTRiNzMtYjE2OC04NTUxNWI1ZDUxODAiLCJleHAiOjE3NzA2MjQ5MzEsImlhdCI6MTc3MDYyNDAzMX0.v_h_KqRcWTb4U_IyJGyANQLpyaDXTyTMtlr1BRW6pFk" \
  -v 2>&1 | tee /tmp/profile_test.log

echo -e "\n\n=== Test 2: First login to get a fresh token ==="
read -p "Enter email: " EMAIL
read -p "Enter password: " PASSWORD

echo -e "\nLogging in..."
TOKEN_RESPONSE=$(curl -s -X POST "http://localhost/api/v1/auth/login-email" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

echo "Login response: $TOKEN_RESPONSE"

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
USER_ID=$(echo $TOKEN_RESPONSE | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Failed to get access token. Check credentials."
  exit 1
fi

echo -e "\n=== Test 3: Get your own profile ==="
curl -X GET "http://localhost/api/v1/profiles/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json"

echo -e "\n\n=== Test 4: Get public profile (using your user_id) ==="
echo "USER_ID: $USER_ID"
curl -X GET "http://localhost/api/v1/profiles/$USER_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -v

echo -e "\n\n=== Test 5: Search profiles ==="
curl -X GET "http://localhost/api/v1/profiles/search?query=bob&limit=5" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json"

echo -e "\n\n=== Note: The UUID in Flutter logs appears truncated ==="
echo "Expected: 36 characters (with hyphens)"
echo "Actual:   5ff12d77-0c81-4b73-b168-855155d5180 (35 characters)"
echo "This might be causing the 500 error if the UUID is malformed."
