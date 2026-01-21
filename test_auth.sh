#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:8081/api/v1}

EMAIL=${EMAIL:-test2@example.com}
PASSWORD=${PASSWORD:-TestPass123!}
FIRST_NAME=${FIRST_NAME:-John}
LAST_NAME=${LAST_NAME:-Doe}
DOB=${DOB:-2000-01-01}
REFERRAL=${REFERRAL:-}
DEVICE_ID=${DEVICE_ID:-test-device}
USER_AGENT=${USER_AGENT:-test-auth-script}
APP_VERSION=${APP_VERSION:-1.0.0}

COUNTRY_CODE=${COUNTRY_CODE:-}
PHONE_NUMBER=${PHONE_NUMBER:-}
SMS_CODE=${SMS_CODE:-}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log() { printf "\n==> %s\n" "$*"; }

request() {
  local method="$1"
  local path="$2"
  local data="$3"
  local auth_header="${4:-}"

  local resp
  if [[ -n "$auth_header" ]]; then
    resp=$(curl -sS -w "\n%{http_code}" -X "$method" \
      -H "Content-Type: application/json" \
      -H "User-Agent: $USER_AGENT" \
      -H "X-App-Version: $APP_VERSION" \
      -H "Authorization: Bearer $auth_header" \
      -d "$data" \
      "$BASE_URL$path")
  else
    resp=$(curl -sS -w "\n%{http_code}" -X "$method" \
      -H "Content-Type: application/json" \
      -H "User-Agent: $USER_AGENT" \
      -H "X-App-Version: $APP_VERSION" \
      -d "$data" \
      "$BASE_URL$path")
  fi

  HTTP_STATUS=$(echo "$resp" | tail -n1)
  HTTP_BODY=$(echo "$resp" | sed '$d')
}

json_get() {
  local key="$1"
  python - <<PY
import json, sys
try:
    data=json.load(sys.stdin)
    val=data.get("$key", "")
    if isinstance(val, (dict, list)):
        print(json.dumps(val))
    else:
        print(val)
except Exception:
    print("")
PY
}

log "Register email"
register_payload=$(cat <<JSON
{"email":"$EMAIL","password":"$PASSWORD","first_name":"$FIRST_NAME","last_name":"$LAST_NAME","date_of_birth":"$DOB","referral":"$REFERRAL","device_id":"$DEVICE_ID","user_agent":"$USER_AGENT","app_version":"$APP_VERSION"}
JSON
)
request POST "/auth/register-email" "$register_payload"

echo "Status: $HTTP_STATUS"
if [[ "$HTTP_STATUS" == "200" ]]; then
  ACCESS_TOKEN=$(echo "$HTTP_BODY" | json_get access_token)
  REFRESH_TOKEN=$(echo "$HTTP_BODY" | json_get refresh_token)
  log "Registered OK"
else
  echo "$HTTP_BODY"
  log "Login email"
  login_payload=$(cat <<JSON
{"email":"$EMAIL","password":"$PASSWORD","device_id":"$DEVICE_ID","user_agent":"$USER_AGENT","app_version":"$APP_VERSION"}
JSON
)
  request POST "/auth/login-email" "$login_payload"
  echo "Status: $HTTP_STATUS"
  if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "$HTTP_BODY"
    exit 1
  fi
  ACCESS_TOKEN=$(echo "$HTTP_BODY" | json_get access_token)
  REFRESH_TOKEN=$(echo "$HTTP_BODY" | json_get refresh_token)
  log "Login OK"
fi

log "Refresh token"
refresh_payload=$(cat <<JSON
{"refresh_token":"$REFRESH_TOKEN"}
JSON
)
request POST "/auth/refresh" "$refresh_payload"

echo "Status: $HTTP_STATUS"
if [[ "$HTTP_STATUS" == "200" ]]; then
  NEW_ACCESS_TOKEN=$(echo "$HTTP_BODY" | json_get access_token)
  NEW_REFRESH_TOKEN=$(echo "$HTTP_BODY" | json_get refresh_token)
  ACCESS_TOKEN=$NEW_ACCESS_TOKEN
  REFRESH_TOKEN=$NEW_REFRESH_TOKEN
  log "Refresh OK"
else
  echo "$HTTP_BODY"
fi

log "Logout"
request POST "/auth/logout" "{}" "$ACCESS_TOKEN"

echo "Status: $HTTP_STATUS"
if [[ "$HTTP_STATUS" != "204" ]]; then
  echo "$HTTP_BODY"
fi

if [[ -n "$COUNTRY_CODE" && -n "$PHONE_NUMBER" ]]; then
  log "Phone code request (register)"
  phone_req=$(cat <<JSON
{"country_code":"$COUNTRY_CODE","phone_number":"$PHONE_NUMBER","purpose":"register"}
JSON
)
  request POST "/auth/phone/request" "$phone_req"
  echo "Status: $HTTP_STATUS"

  PURPOSE="register"
  if [[ "$HTTP_STATUS" == "409" ]]; then
    log "Phone already exists, switching to login"
    phone_req=$(cat <<JSON
{"country_code":"$COUNTRY_CODE","phone_number":"$PHONE_NUMBER","purpose":"login"}
JSON
)
    request POST "/auth/phone/request" "$phone_req"
    echo "Status: $HTTP_STATUS"
    PURPOSE="login"
  fi

  if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "$HTTP_BODY"
    exit 1
  fi

  VERIFICATION_ID=$(echo "$HTTP_BODY" | json_get verification_id)

  if [[ -z "$SMS_CODE" ]]; then
    if command -v docker >/dev/null 2>&1; then
      log "Fetching SMS code from docker logs"
      SMS_CODE=$(docker compose -f "$SCRIPT_DIR/docker-compose.yml" logs api --since 5m 2>/dev/null | grep -oE 'sms_placeholder.*' | tail -n1 | grep -oE '[0-9]{6}' || true)
    fi
  fi

  if [[ -z "$SMS_CODE" ]]; then
    echo "SMS_CODE is empty. Set SMS_CODE env var or ensure docker logs contain sms_placeholder."
    exit 1
  fi

  log "Verify phone code"
  phone_verify=$(cat <<JSON
{"verification_id":"$VERIFICATION_ID","code":"$SMS_CODE","device_id":"$DEVICE_ID","user_agent":"$USER_AGENT","app_version":"$APP_VERSION"}
JSON
)
  request POST "/auth/phone/verify" "$phone_verify"
  echo "Status: $HTTP_STATUS"
  if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "$HTTP_BODY"
    exit 1
  fi

  if [[ "$PURPOSE" == "register" ]]; then
    log "Complete phone registration"
    phone_register=$(cat <<JSON
{"verification_id":"$VERIFICATION_ID","first_name":"$FIRST_NAME","last_name":"$LAST_NAME","date_of_birth":"$DOB","referral":"$REFERRAL","device_id":"$DEVICE_ID","user_agent":"$USER_AGENT","app_version":"$APP_VERSION"}
JSON
)
    request POST "/auth/register-phone" "$phone_register"
    echo "Status: $HTTP_STATUS"
    if [[ "$HTTP_STATUS" != "200" ]]; then
      echo "$HTTP_BODY"
      exit 1
    fi
  fi

  ACCESS_TOKEN=$(echo "$HTTP_BODY" | json_get access_token)
  if [[ -n "$ACCESS_TOKEN" ]]; then
    log "Logout (phone flow)"
    request POST "/auth/logout" "{}" "$ACCESS_TOKEN"
    echo "Status: $HTTP_STATUS"
  fi
else
  log "Skipping phone flow (set COUNTRY_CODE and PHONE_NUMBER to enable)"
fi

log "Done"
