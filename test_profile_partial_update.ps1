# Test Partial Profile Update (PATCH semantics)
# This script tests updating only one field without affecting others
$ErrorActionPreference = "Stop"

$BASE_URL = "http://localhost:8081/api/v1"

Write-Host "=== Profile Partial Update Test ===" -ForegroundColor Cyan
Write-Host "Testing PATCH /profiles/me with single field update`n" -ForegroundColor Cyan

# Step 1: Register a new user
Write-Host "=== Step 1: Register New User ===" -ForegroundColor Green
$testEmail = "testuser$(Get-Random)@example.com"
$testPassword = "SecurePass123!"

$registerBody = @{
    email = $testEmail
    password = $testPassword
    first_name = "John"
    last_name = "Doe"
    date_of_birth = "2000-01-01"
    device_id = "test-device-partial-$(Get-Random)"
    app_version = "1.0.0-test"
} | ConvertTo-Json

try {
    $registerResponse = Invoke-WebRequest -Uri "$BASE_URL/auth/register-email" -Method POST -Body $registerBody -ContentType "application/json" -UseBasicParsing
    $registerData = $registerResponse.Content | ConvertFrom-Json
    Write-Host "✓ Registration successful!" -ForegroundColor Green
    Write-Host "  User ID: $($registerData.user.id)" -ForegroundColor Gray
    Write-Host "  Email: $($registerData.user.email)" -ForegroundColor Gray
    $accessToken = $registerData.access_token
    $userId = $registerData.user.id
} catch {
    Write-Host "✗ Registration failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "  Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

# Step 2: Get initial profile
Write-Host "`n=== Step 2: Get Initial Profile ===" -ForegroundColor Green
try {
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }
    
    $profileResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/me" -Method GET -Headers $headers -UseBasicParsing
    $initialProfile = $profileResponse.Content | ConvertFrom-Json
    
    Write-Host "✓ Initial profile retrieved!" -ForegroundColor Green
    Write-Host "  Display Name: '$($initialProfile.display_name)'" -ForegroundColor Gray
    Write-Host "  First Name: '$($initialProfile.first_name)'" -ForegroundColor Gray
    Write-Host "  Last Name: '$($initialProfile.last_name)'" -ForegroundColor Gray
    Write-Host "  Bio: '$($initialProfile.bio)'" -ForegroundColor Gray
    Write-Host "  Country: '$($initialProfile.country)'" -ForegroundColor Gray
    Write-Host "  City: '$($initialProfile.city)'" -ForegroundColor Gray
} catch {
    Write-Host "✗ Failed to get initial profile: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Update ONLY display_name (partial update)
Write-Host "`n=== Step 3: Update ONLY Display Name ===" -ForegroundColor Green
Write-Host "Sending JSON: { `"display_name`": `"Alice Wonder`" }" -ForegroundColor Yellow

$updateBody = @{
    display_name = "Alice Wonder"
} | ConvertTo-Json

try {
    $updateResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/me" -Method PATCH -Body $updateBody -Headers $headers -UseBasicParsing
    $updatedProfile = $updateResponse.Content | ConvertFrom-Json
    
    Write-Host "✓ Profile updated successfully!" -ForegroundColor Green
    Write-Host "  Display Name: '$($updatedProfile.display_name)'" -ForegroundColor Gray
    Write-Host "  First Name: '$($updatedProfile.first_name)'" -ForegroundColor Gray
    Write-Host "  Last Name: '$($updatedProfile.last_name)'" -ForegroundColor Gray
    Write-Host "  Bio: '$($updatedProfile.bio)'" -ForegroundColor Gray
    Write-Host "  Country: '$($updatedProfile.country)'" -ForegroundColor Gray
    Write-Host "  City: '$($updatedProfile.city)'" -ForegroundColor Gray
} catch {
    Write-Host "✗ Profile update failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "  Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

# Step 4: Verify only display_name was updated
Write-Host "`n=== Step 4: Verification ===" -ForegroundColor Green

$allTestsPassed = $true

if ($updatedProfile.display_name -eq "Alice Wonder") {
    Write-Host "✓ Display Name updated correctly: '$($updatedProfile.display_name)'" -ForegroundColor Green
} else {
    Write-Host "✗ Display Name NOT updated! Expected 'Alice Wonder', got '$($updatedProfile.display_name)'" -ForegroundColor Red
    $allTestsPassed = $false
}

if ($updatedProfile.first_name -eq $initialProfile.first_name) {
    Write-Host "✓ First Name unchanged (correct): '$($updatedProfile.first_name)'" -ForegroundColor Green
} else {
    Write-Host "✗ First Name was changed! Expected '$($initialProfile.first_name)', got '$($updatedProfile.first_name)'" -ForegroundColor Red
    $allTestsPassed = $false
}

if ($updatedProfile.last_name -eq $initialProfile.last_name) {
    Write-Host "✓ Last Name unchanged (correct): '$($updatedProfile.last_name)'" -ForegroundColor Green
} else {
    Write-Host "✗ Last Name was changed! Expected '$($initialProfile.last_name)', got '$($updatedProfile.last_name)'" -ForegroundColor Red
    $allTestsPassed = $false
}

if ($updatedProfile.bio -eq $initialProfile.bio) {
    Write-Host "✓ Bio unchanged (correct): '$($updatedProfile.bio)'" -ForegroundColor Green
} else {
    Write-Host "✗ Bio was changed! Expected '$($initialProfile.bio)', got '$($updatedProfile.bio)'" -ForegroundColor Red
    $allTestsPassed = $false
}

# Step 5: Test updating another single field (bio)
Write-Host "`n=== Step 5: Update ONLY Bio ===" -ForegroundColor Green
Write-Host "Sending JSON: { `"bio`": `"I love adventure!`" }" -ForegroundColor Yellow

$updateBioBody = @{
    bio = "I love adventure!"
} | ConvertTo-Json

try {
    $updateBioResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/me" -Method PATCH -Body $updateBioBody -Headers $headers -UseBasicParsing
    $bioUpdatedProfile = $updateBioResponse.Content | ConvertFrom-Json
    
    Write-Host "✓ Bio updated successfully!" -ForegroundColor Green
    Write-Host "  Display Name: '$($bioUpdatedProfile.display_name)'" -ForegroundColor Gray
    Write-Host "  Bio: '$($bioUpdatedProfile.bio)'" -ForegroundColor Gray
    
    if ($bioUpdatedProfile.bio -eq "I love adventure!") {
        Write-Host "✓ Bio updated correctly" -ForegroundColor Green
    } else {
        Write-Host "✗ Bio NOT updated correctly!" -ForegroundColor Red
        $allTestsPassed = $false
    }
    
    if ($bioUpdatedProfile.display_name -eq "Alice Wonder") {
        Write-Host "✓ Display Name still preserved from previous update" -ForegroundColor Green
    } else {
        Write-Host "✗ Display Name was lost!" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "✗ Bio update failed: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# Step 6: Test invalid JSON (trailing comma)
Write-Host "`n=== Step 6: Test Invalid JSON (trailing comma) ===" -ForegroundColor Green
Write-Host "Sending invalid JSON with trailing comma..." -ForegroundColor Yellow

$invalidJson = '{"display_name": "Test Name",}'

try {
    $invalidResponse = Invoke-WebRequest -Uri "$BASE_URL/profiles/me" -Method PATCH -Body $invalidJson -Headers $headers -UseBasicParsing
    Write-Host "✗ Should have rejected invalid JSON!" -ForegroundColor Red
    $allTestsPassed = $false
} catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-Host "✓ Invalid JSON correctly rejected with 400 Bad Request" -ForegroundColor Green
    } else {
        Write-Host "✗ Wrong error code! Expected 400, got $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        $allTestsPassed = $false
    }
}

# Final Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
if ($allTestsPassed) {
    Write-Host "✓ ALL TESTS PASSED! Partial update works correctly." -ForegroundColor Green
} else {
    Write-Host "✗ SOME TESTS FAILED! Check output above." -ForegroundColor Red
    exit 1
}
