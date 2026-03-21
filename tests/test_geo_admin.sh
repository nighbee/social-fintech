#!/bin/bash
# Test Geo-Administrative Layer Resolution

API_URL="http://localhost:8081/api/v1"
AUTH_TOKEN=""

# 1. Register/Login to get token (Helper function)
login_user() {
    # Stub: assumes a user exists or creates one
    # For now, we expect the caller to provide a token or use an existing test user flow
    echo "Using provided token or existing session..."
}

# 2. Insert Test boundary data (Requires direct DB access or admin API)
# For this test, we assume Almaty boundary is loaded in the DB.
# SQL to run manually if needed:
# INSERT INTO administrative_boundaries (name, level, boundary) VALUES ('Almaty', 2, ST_GeomFromText('POLYGON((...))', 4326));

# 3. Set User Region (Coordinates in Almaty)
echo "Setting user region to Almaty coordinates..."
curl -s -X POST "$API_URL/map/region" \
     -H "Authorization: Bearer $AUTH_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "latitude": 43.2389,
       "longitude": 76.8897,
       "participate_district": true,
       "location_opt_in": true
     }' | jq .

# 4. Verify Champion resolution (After worker snapshot)
echo "Checking if champions have administrative names..."
# We query a res 4 hex in Almaty
curl -s -X GET "$API_URL/map/champions?h3=842d59bffffffff&resolution=4" \
     -H "Authorization: Bearer $AUTH_TOKEN" | jq .

echo "Test completed."
