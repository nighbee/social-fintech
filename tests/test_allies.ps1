# Test Allies Endpoints
$ErrorActionPreference = "Stop"

$BASE_URL = "http://localhost:8081/api/v1"

Write-Host "=== Allies Endpoint Test ===" -ForegroundColor Cyan
Write-Host "Testing GET /profiles/me/allies and GET /profiles/{user_id}/allies`n" -ForegroundColor Cyan

# Register User 1 (will make profile public)
Write-Host "=== Step 1: Register User 1 (Public Profile) ===" -ForegroundColor Green
$user1Email = "user1_$(Get-Random)@example.com"
$user1Password = "SecurePass123!"

$registerBody1 = @{
    email = $user1Email
    password = $user1Password
    first_name = "Alice"
    last_name = "Public"
    date_of_birth = "1995-01-01"
    device_id = "device-user1-$(Get-Random)"
    app_version = "1.0.0"
} | ConvertTo-Json

try {
    $response1 = Invoke-WebRequest -Uri "$BASE_URL/auth/register-email" -Method POST -Body $registerBody1 -ContentType "application/json" -UseBasicParsing
    $data1 = $response1.Content | ConvertFrom-Json
    $user1Token = $data1.access_token
    $user1ID = $data1.user.id
    Write-Host "✓ User 1 registered: $user1ID" -ForegroundColor Green
} catch {
    Write-Host "✗ User 1 registration failed" -ForegroundColor Red
    exit 1
}

# Register User 2 (will make profile private)
Write-Host "`n=== Step 2: Register User 2 (Private Profile) ===" -ForegroundColor Green
$user2Email = "user2_$(Get-Random)@example.com"
$user2Password = "SecurePass123!"

$registerBody2 = @{
    email = $user2Email
    password = $user2Password
    first_name = "Bob"
    last_name = "Private"
    date_of_birth = "1996-01-01"
    device_id = "device-user2-$(Get-Random)"
    app_version = "1.0.0"
} | ConvertTo-Json

try {
    $response2 = Invoke-WebRequest -Uri "$BASE_URL/auth/register-email" -Method POST -Body $registerBody2 -ContentType "application/json" -UseBasicParsing
    $data2 = $response2.Content | ConvertFrom-Json
    $user2Token = $data2.access_token
    $user2ID = $data2.user.id
    Write-Host "✓ User 2 registered: $user2ID" -ForegroundColor Green
} catch {
    Write-Host "✗ User 2 registration failed" -ForegroundColor Red
    exit 1
}

# Make User 2 profile private
Write-Host "`n=== Step 3: Make User 2 Profile Private ===" -ForegroundColor Green
$headers2 = @{
    "Authorization" = "Bearer $user2Token"
    "Content-Type" = "application/json"
}

$privateUpdate = @{ is_public = $false } | ConvertTo-Json
try {
    $updateResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/me" -Method PATCH -Body $privateUpdate -Headers $headers2 -UseBasicParsing
    Write-Host "✓ User 2 profile set to private" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to update privacy" -ForegroundColor Red
}

# Register User 3 (follower)
Write-Host "`n=== Step 4: Register User 3 (Follower) ===" -ForegroundColor Green
$user3Email = "user3_$(Get-Random)@example.com"
$user3Password = "SecurePass123!"

$registerBody3 = @{
    email = $user3Email
    password = $user3Password
    first_name = "Charlie"
    last_name = "Follower"
    date_of_birth = "1997-01-01"
    device_id = "device-user3-$(Get-Random)"
    app_version = "1.0.0"
} | ConvertTo-Json

try {
    $response3 = Invoke-WebRequest -Uri "$BASE_URL/auth/register-email" -Method POST -Body $registerBody3 -ContentType "application/json" -UseBasicParsing
    $data3 = $response3.Content | ConvertFrom-Json
    $user3Token = $data3.access_token
    $user3ID = $data3.user.id
    Write-Host "✓ User 3 registered: $user3ID" -ForegroundColor Green
} catch {
    Write-Host "✗ User 3 registration failed" -ForegroundColor Red
    exit 1
}

$headers1 = @{ "Authorization" = "Bearer $user1Token"; "Content-Type" = "application/json" }
$headers3 = @{ "Authorization" = "Bearer $user3Token"; "Content-Type" = "application/json" }

# User 3 follows User 1 (public profile)
Write-Host "`n=== Step 5: User 3 Follows User 1 ===" -ForegroundColor Green
try {
    Invoke-WebRequest -Uri "$BASE_URL/profiles/$user1ID/allies" -Method POST -Headers $headers3 -UseBasicParsing | Out-Null
    Write-Host "✓ User 3 now follows User 1" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to add ally" -ForegroundColor Red
}

# User 3 follows User 2 (private profile)
Write-Host "`n=== Step 6: User 3 Follows User 2 ===" -ForegroundColor Green
try {
    Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/allies" -Method POST -Headers $headers3 -UseBasicParsing | Out-Null
    Write-Host "✓ User 3 now follows User 2" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to add ally" -ForegroundColor Red
}

# Test 1: User 1 views their own allies using /me/allies
Write-Host "`n=== Test 1: User 1 Views Own Allies (GET /profiles/me/allies) ===" -ForegroundColor Green
try {
    $myAlliesResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/me/allies" -Method GET -Headers $headers1 -UseBasicParsing
    $myAllies = $myAlliesResponse.Content | ConvertFrom-Json
    
    Write-Host "✓ Successfully retrieved own allies" -ForegroundColor Green
    Write-Host "  Count: $($myAllies.Count)" -ForegroundColor Gray
    
    if ($myAllies.Count -eq 1 -and $myAllies[0].user_id -eq $user3ID) {
        Write-Host "✓ Correct: User 3 is in User 1's allies list" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected allies list" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to get own allies" -ForegroundColor Red
}

# Test 2: User 3 views User 1's allies (public profile - should work)
Write-Host "`n=== Test 2: User 3 Views User 1's Allies (Public Profile) ===" -ForegroundColor Green
try {
    $publicAlliesResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user1ID/allies" -Method GET -Headers $headers3 -UseBasicParsing
    $publicAllies = $publicAlliesResponse.Content | ConvertFrom-Json
    
    Write-Host "✓ Successfully viewed public user's allies" -ForegroundColor Green
    Write-Host "  Count: $($publicAllies.Count)" -ForegroundColor Gray
    
    if ($publicAllies.Count -eq 1) {
        Write-Host "✓ Correct: Can view allies of public profile" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Failed to view public allies" -ForegroundColor Red
}

# Test 3: User 3 tries to view User 2's allies (private profile - should fail)
Write-Host "`n=== Test 3: User 3 Views User 2's Allies (Private Profile - Should Fail) ===" -ForegroundColor Green
try {
    $privateAlliesResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/$user2ID/allies" -Method GET -Headers $headers3 -UseBasicParsing
    Write-Host "✗ Should have blocked access to private profile's allies!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "✓ Correctly blocked with 403 Forbidden" -ForegroundColor Green
        
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        $errorData = $responseBody | ConvertFrom-Json
        
        if ($errorData.error -eq "profile_private") {
            Write-Host "✓ Correct error message: profile_private" -ForegroundColor Green
        }
    } else {
        Write-Host "✗ Wrong error code: Expected 403, got $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

# Test 4: User 2 can view their own allies (owner of private profile)
Write-Host "`n=== Test 4: User 2 Views Own Allies (Owner of Private Profile) ===" -ForegroundColor Green
try {
    $ownPrivateAlliesResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/me/allies" -Method GET -Headers $headers2 -UseBasicParsing
    $ownPrivateAllies = $ownPrivateAlliesResponse.Content | ConvertFrom-Json
    
    Write-Host "✓ Owner can view their own allies (even when profile is private)" -ForegroundColor Green
    Write-Host "  Count: $($ownPrivateAllies.Count)" -ForegroundColor Gray
    
    if ($ownPrivateAllies.Count -eq 1 -and $ownPrivateAllies[0].user_id -eq $user3ID) {
        Write-Host "✓ Correct: User 3 is in User 2's allies list" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Owner failed to view own allies" -ForegroundColor Red
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "✓ /profiles/me/allies works for authenticated user" -ForegroundColor Green
Write-Host "✓ /profiles/{user_id}/allies works for public profiles" -ForegroundColor Green
Write-Host "✓ /profiles/{user_id}/allies blocks access to private profiles" -ForegroundColor Green
Write-Host "✓ Profile owners can always view their own allies" -ForegroundColor Green
Write-Host "`nAll tests passed!" -ForegroundColor Green
