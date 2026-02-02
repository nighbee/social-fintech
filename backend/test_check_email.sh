#!/bin/bash

# Test check-email endpoint

echo "Testing email that exists..."
curl -X POST http://localhost:8081/api/v1/auth/check-email \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'

echo -e "\n\nTesting email that doesn't exist..."
curl -X POST http://localhost:8081/api/v1/auth/check-email \
  -H "Content-Type: application/json" \
  -d '{"email":"nonexistent@example.com"}'

echo -e "\n\nTesting with empty email..."
curl -X POST http://localhost:8081/api/v1/auth/check-email \
  -H "Content-Type: application/json" \
  -d '{"email":""}'
