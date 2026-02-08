#!/bin/bash
# Test automatic geolocation feature for profile updates

API_URL="http://localhost:8080"

# Color codes
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Testing Automatic Geolocation Feature ===${NC}"

# Step 1: Login to get token (replace with your test credentials)
echo -e "\n${YELLOW}1. Login to get auth token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test@example.com",
        "password": "testpassword"
    }')

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "Error: Failed to obtain token"
    echo "$LOGIN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Token obtained${NC}"

# Step 2: Update profile WITHOUT location (should auto-detect)
echo -e "\n${YELLOW}2. Update profile without location (auto-detect from IP)...${NC}"
UPDATE_RESPONSE=$(curl -s -X PATCH "$API_URL/api/v1/profiles/me" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 8.8.8.8" \
    -d '{
        "first_name": "John",
        "last_name": "Doe",
        "bio": "Testing automatic geolocation"
    }')

COUNTRY=$(echo "$UPDATE_RESPONSE" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
REGION=$(echo "$UPDATE_RESPONSE" | grep -o '"region":"[^"]*' | cut -d'"' -f4)
CITY=$(echo "$UPDATE_RESPONSE" | grep -o '"city":"[^"]*' | cut -d'"' -f4)

echo -e "${GREEN}✓ Profile updated with auto-detected location:${NC}"
echo -e "${WHITE}  Country: $COUNTRY${NC}"
echo -e "${WHITE}  Region:  $REGION${NC}"
echo -e "${WHITE}  City:    $CITY${NC}"

# Step 3: Update profile WITH location (manual override)
echo -e "\n${YELLOW}3. Update profile with manual location (override auto-detect)...${NC}"
MANUAL_RESPONSE=$(curl -s -X PATCH "$API_URL/api/v1/profiles/me" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: 8.8.8.8" \
    -d '{
        "country": "Canada",
        "region": "Ontario",
        "city": "Toronto"
    }')

COUNTRY=$(echo "$MANUAL_RESPONSE" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
REGION=$(echo "$MANUAL_RESPONSE" | grep -o '"region":"[^"]*' | cut -d'"' -f4)
CITY=$(echo "$MANUAL_RESPONSE" | grep -o '"city":"[^"]*' | cut -d'"' -f4)

echo -e "${GREEN}✓ Profile updated with manual location:${NC}"
echo -e "${WHITE}  Country: $COUNTRY${NC}"
echo -e "${WHITE}  Region:  $REGION${NC}"
echo -e "${WHITE}  City:    $CITY${NC}"

# Step 4: Get current profile
echo -e "\n${YELLOW}4. Retrieve current profile...${NC}"
PROFILE_RESPONSE=$(curl -s -X GET "$API_URL/api/v1/profiles/me" \
    -H "Authorization: Bearer $TOKEN")

echo -e "${GREEN}✓ Current profile:${NC}"
# Pretty print JSON if jq is available, otherwise just print raw
if command -v jq &> /dev/null; then
    echo "$PROFILE_RESPONSE" | jq .
else
    echo "$PROFILE_RESPONSE"
fi

echo -e "\n${CYAN}=== Test Complete ===${NC}"
