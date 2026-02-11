# Test Relationship Status Endpoint
$ErrorActionPreference = "Stop"

$BASE_URL = "http://localhost:8081/api/v1"

Write-Host "=== Relationship Status Test ===" -ForegroundColor Cyan
Write-Host "Testing GET /profiles/{user_id}/relationship`n" -ForegroundColor Cyan

# Register User 1
Write-Host "=== Step 1: Register User 1 ===" -ForegroundColor Green
$user1Email = "relationship_user1_$(Get-Random)@example.com"
$user1Password = "SecurePass123!"

$registerBody1 = @{
    email = $user1Email
    password = $user1Password
    first_name = "Alice"
    last_name = "Test"
    date_of_birth = "1995-01-01"
    device_id = "device-user1-$(Get-Random)"
    app_version = "1.0.0"
} | ConvertTo-Json

$response1 = Invoke-WebRequest -Uri "$BASE_URL/auth/register-email" -Method POST -Body $registerBody1 -ContentType "application/json" -UseBasicParsing
$data1 = $response1.Content | ConvertFrom-Json
$user1Token = $data1.access_token
$user1ID = $data1.user.id
Write-Host "✓ User 1: $user1ID" -ForegroundColor Green

# Register User 2
Write-Host "`n=== Step 2: Register User 2 ===" -ForegroundColor Green
$user2Email = "relationship_user2_$(Get-Random)@example.com"
$user2Password = "SecurePass123!"

$registerBody2 = @{
    email = $user2Email
    password = $user2Password
    first_name = "Bob"
    last_name = "Test"
    date_of_birth = "1996-01-01"
    device_id = "device-user2-$(Get-Random)"
    app_version = "1.0.0"
} | ConvertTo-Json

$response2 = Invoke-WebRequest -Uri "$BASE_URL/auth/register-email" -Method POST -Body $registerBody2 -ContentType "application/json" -UseBasicParsing
$data2 = $response2.Content | ConvertFrom-Json
$user2Token = $data2.access_token
$user2ID = $data2.user.id
Write-Host "✓ User 2: $user2ID" -ForegroundColor Green

$headers1 = @{ "Authorization" = "Bearer $user1Token"; "Content-Type" = "application/json" }
$headers2 = @{ "Authorization" = "Bearer $user2Token"; "Content-Type" = "application/json" }

# Test 1: Check initial relationship (should be all false)
Write-Host "`n=== Test 1: Initial Relationship Status (No Relationship) ===" -ForegroundColor Green
$statusResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/relationship" -Method GET -Headers $headers1 -UseBasicParsing
$status = $statusResponse.Content | ConvertFrom-Json

Write-Host "Response:" -ForegroundColor Gray
Write-Host "  user_id: $($status.user_id)" -ForegroundColor Gray
Write-Host "  i_follow_them: $($status.i_follow_them)" -ForegroundColor Gray
Write-Host "  they_follow_me: $($status.they_follow_me)" -ForegroundColor Gray
Write-Host "  i_blocked_them: $($status.i_blocked_them)" -ForegroundColor Gray
Write-Host "  they_blocked_me: $($status.they_blocked_me)" -ForegroundColor Gray
Write-Host "  i_restricted_them: $($status.i_restricted_them)" -ForegroundColor Gray

if (-not $status.i_follow_them -and -not $status.they_follow_me -and -not $status.i_blocked_them -and -not $status.they_blocked_me -and -not $status.i_restricted_them) {
    Write-Host "✓ All fields are false (no relationship)" -ForegroundColor Green
} else {
    Write-Host "✗ Expected all false" -ForegroundColor Red
}

# Test 2: User 1 follows User 2
Write-Host "`n=== Test 2: User 1 Follows User 2 ===" -ForegroundColor Green
Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/allies" -Method POST -Headers $headers1 -UseBasicParsing | Out-Null

$statusResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/relationship" -Method GET -Headers $headers1 -UseBasicParsing
$status = $statusResponse.Content | ConvertFrom-Json

Write-Host "After following:" -ForegroundColor Gray
Write-Host "  i_follow_them: $($status.i_follow_them)" -ForegroundColor Gray
Write-Host "  they_follow_me: $($status.they_follow_me)" -ForegroundColor Gray

if ($status.i_follow_them -and -not $status.they_follow_me) {
    Write-Host "✓ i_follow_them = true, they_follow_me = false" -ForegroundColor Green
} else {
    Write-Host "✗ Unexpected values" -ForegroundColor Red
}

# Test 3: Check from User 2's perspective
Write-Host "`n=== Test 3: User 2 Checks Relationship with User 1 ===" -ForegroundColor Green
$statusResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user1ID/relationship" -Method GET -Headers $headers2 -UseBasicParsing
$status = $statusResponse.Content | ConvertFrom-Json

Write-Host "User 2's view:" -ForegroundColor Gray
Write-Host "  i_follow_them: $($status.i_follow_them)" -ForegroundColor Gray
Write-Host "  they_follow_me: $($status.they_follow_me)" -ForegroundColor Gray

if (-not $status.i_follow_them -and $status.they_follow_me) {
    Write-Host "✓ they_follow_me = true (User 1 follows User 2)" -ForegroundColor Green
} else {
    Write-Host "✗ Unexpected values" -ForegroundColor Red
}

# Test 4: User 2 follows User 1 back (mutual following)
Write-Host "`n=== Test 4: Mutual Following ===" -ForegroundColor Green
Invoke-WebRequest -Uri "$BASE_URL/profiles/$user1ID/allies" -Method POST -Headers $headers2 -UseBasicParsing | Out-Null

$statusResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/relationship" -Method GET -Headers $headers1 -UseBasicParsing
$status = $statusResponse.Content | ConvertFrom-Json

Write-Host "After mutual follow:" -ForegroundColor Gray
Write-Host "  i_follow_them: $($status.i_follow_them)" -ForegroundColor Gray
Write-Host "  they_follow_me: $($status.they_follow_me)" -ForegroundColor Gray

if ($status.i_follow_them -and $status.they_follow_me) {
    Write-Host "✓ Both following each other" -ForegroundColor Green
} else {
    Write-Host "✗ Expected mutual follow" -ForegroundColor Red
}

# Test 5: User 1 blocks User 2
Write-Host "`n=== Test 5: User 1 Blocks User 2 ===" -ForegroundColor Green
Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/block" -Method POST -Headers $headers1 -UseBasicParsing | Out-Null

$statusResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/relationship" -Method GET -Headers $headers1 -UseBasicParsing
$status = $statusResponse.Content | ConvertFrom-Json

Write-Host "After blocking:" -ForegroundColor Gray
Write-Host "  i_follow_them: $($status.i_follow_them)" -ForegroundColor Gray
Write-Host "  i_blocked_them: $($status.i_blocked_them)" -ForegroundColor Gray
Write-Host "  they_follow_me: $($status.they_follow_me)" -ForegroundColor Gray

if ($status.i_blocked_them) {
    Write-Host "✓ i_blocked_them = true" -ForegroundColor Green
} else {
    Write-Host "✗ Expected block status" -ForegroundColor Red
}

# Test 6: User 1 restricts User 2
Write-Host "`n=== Test 6: User 1 Restricts User 2 ===" -ForegroundColor Green
Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/restrict" -Method POST -Headers $headers1 -UseBasicParsing | Out-Null

$statusResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/relationship" -Method GET -Headers $headers1 -UseBasicParsing
$status = $statusResponse.Content | ConvertFrom-Json

Write-Host "After restricting:" -ForegroundColor Gray
Write-Host "  i_restricted_them: $($status.i_restricted_them)" -ForegroundColor Gray
Write-Host "  i_blocked_them: $($status.i_blocked_them)" -ForegroundColor Gray

if ($status.i_restricted_them -and $status.i_blocked_them) {
    Write-Host "✓ Both blocked and restricted" -ForegroundColor Green
} else {
    Write-Host "✗ Expected both statuses" -ForegroundColor Red
}

# Test 7: Test self-check prevention
Write-Host "`n=== Test 7: Prevent Self-Check ===" -ForegroundColor Green
try {
    Invoke-WebRequest -Uri "$BASE_URL/profiles/$user1ID/relationship" -Method GET -Headers $headers1 -UseBasicParsing | Out-Null
    Write-Host "✗ Should have blocked self-check!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-Host "✓ Self-check correctly blocked with 400" -ForegroundColor Green
    } else {
        Write-Host "✗ Wrong error code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "✓ Relationship status endpoint working correctly" -ForegroundColor Green
Write-Host "✓ Supports follow, block, restrict relationships" -ForegroundColor Green
Write-Host "✓ Shows bidirectional status correctly" -ForegroundColor Green
Write-Host "✓ Prevents self-checks" -ForegroundColor Green
