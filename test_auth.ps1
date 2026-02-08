# Test Email Registration and Login
$ErrorActionPreference = "Stop"

Write-Host "=== 1. Testing Email Registration ===" -ForegroundColor Green

$testEmail = "testuser$(Get-Random)@example.com"
$testPassword = "SecurePass123!"

$registerBody = @{
    email = $testEmail
    password = $testPassword
    first_name = "John"
    last_name = "Doe"
    date_of_birth = "2000-01-01"
    device_id = "test-device-12345"
    app_version = "1.0.0-dev"
} | ConvertTo-Json

try {
    $registerResponse = Invoke-WebRequest -Uri "http://localhost:8081/api/v1/auth/register-email" -Method POST -Body $registerBody -ContentType "application/json" -UseBasicParsing
    $registerData = $registerResponse.Content | ConvertFrom-Json
    Write-Host "✓ Registration successful!" -ForegroundColor Green
    Write-Host "  User ID: $($registerData.user.id)"
    Write-Host "  Username: $($registerData.user.username)"
    Write-Host "  Email: $($registerData.user.email)"
} catch {
    Write-Host "✗ Registration failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "  Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`n=== 2. Testing Email Login ===" -ForegroundColor Green

$loginBody = @{
    email = $testEmail
    password = $testPassword
    device_id = "test-device-12345"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-WebRequest -Uri "http://localhost:8081/api/v1/auth/login-email" -Method POST -Body $loginBody -ContentType "application/json" -UseBasicParsing
    $loginData = $loginResponse.Content | ConvertFrom-Json
    Write-Host "✓ Login successful!" -ForegroundColor Green
    Write-Host "  Access Token: $($loginData.access_token.Substring(0,50))..."
    Write-Host "  Refresh Token: $($loginData.refresh_token.Substring(0,50))..."
    Write-Host "  User ID: $($loginData.user.id)"
    
    $accessToken = $loginData.access_token
    $refreshToken = $loginData.refresh_token
} catch {
    Write-Host "✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "  Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`n=== 3. Testing Refresh Token ===" -ForegroundColor Green

$refreshBody = @{
    refresh_token = $refreshToken
} | ConvertTo-Json

try {
    $refreshResponse = Invoke-WebRequest -Uri "http://localhost:8081/api/v1/auth/refresh" -Method POST -Body $refreshBody -ContentType "application/json" -UseBasicParsing
    $refreshData = $refreshResponse.Content | ConvertFrom-Json
    Write-Host "✓ Token refresh successful!" -ForegroundColor Green
    Write-Host "  New Access Token: $($refreshData.access_token.Substring(0,50))..."
    
    $accessToken = $refreshData.access_token
} catch {
    Write-Host "✗ Token refresh failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== 4. Testing Logout ===" -ForegroundColor Green

$headers = @{
    "Authorization" = "Bearer $accessToken"
}

try {
    Invoke-WebRequest -Uri "http://localhost:8081/api/v1/auth/logout" -Method POST -Headers $headers -UseBasicParsing | Out-Null
    Write-Host "✓ Logout successful!" -ForegroundColor Green
} catch {
    Write-Host "✗ Logout failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== All Tests Complete ===" -ForegroundColor Cyan