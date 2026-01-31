# BrightBund Storage Testing Script
# Tests profile picture and post media uploads

$baseUrl = "http://localhost:8081/api/v1"
$token = ""

Write-Host "=== BrightBund Storage Upload Tests ===" -ForegroundColor Cyan
Write-Host ""

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers,
        [hashtable]$Body,
        [hashtable]$Form
    )
    
    Write-Host "Testing: $Name" -ForegroundColor Yellow
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
        }
        
        if ($Form) {
            $params.Form = $Form
        } elseif ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-RestMethod @params
        Write-Host "✓ Success" -ForegroundColor Green
        $response | ConvertTo-Json -Depth 10 | Write-Host
        return $response
    }
    catch {
        Write-Host "✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            $_.ErrorDetails.Message | Write-Host
        }
        return $null
    }
    Write-Host ""
}

# Step 1: Login
Write-Host "Step 1: Login to get token" -ForegroundColor Cyan
$loginBody = @{
    email = "test@example.com"
    password = "password123"
    device_id = "test-device"
}

$loginResponse = Test-Endpoint `
    -Name "Email Login" `
    -Method "POST" `
    -Url "$baseUrl/auth/login-email" `
    -Body $loginBody

if ($loginResponse -and $loginResponse.access_token) {
    $token = $loginResponse.access_token
    Write-Host "Got token: $($token.Substring(0, 20))..." -ForegroundColor Green
} else {
    Write-Host "Failed to login. Please register first or check credentials." -ForegroundColor Red
    exit 1
}

$headers = @{
    Authorization = "Bearer $token"
}

Write-Host ""
Write-Host "=== Profile Picture Tests ===" -ForegroundColor Cyan

# Test 1: Upload Avatar
Write-Host "Test 1: Upload Avatar" -ForegroundColor Yellow

# Create a temporary test image
$tempImagePath = "$env:TEMP\test-avatar.jpg"
$testImageData = [byte[]]::new(1024)
(New-Object Random).NextBytes($testImageData)
[System.IO.File]::WriteAllBytes($tempImagePath, $testImageData)

if (Test-Path $tempImagePath) {
    $avatarForm = @{
        avatar = Get-Item -Path $tempImagePath
    }
    
    Test-Endpoint `
        -Name "Upload Avatar" `
        -Method "POST" `
        -Url "$baseUrl/profile/upload/avatar" `
        -Headers $headers `
        -Form $avatarForm
    
    Remove-Item $tempImagePath -Force
}

Write-Host ""

# Test 2: Upload Cover
Write-Host "Test 2: Upload Cover Photo" -ForegroundColor Yellow

$tempCoverPath = "$env:TEMP\test-cover.jpg"
$testCoverData = [byte[]]::new(2048)
(New-Object Random).NextBytes($testCoverData)
[System.IO.File]::WriteAllBytes($tempCoverPath, $testCoverData)

if (Test-Path $tempCoverPath) {
    $coverForm = @{
        cover = Get-Item -Path $tempCoverPath
    }
    
    Test-Endpoint `
        -Name "Upload Cover" `
        -Method "POST" `
        -Url "$baseUrl/profile/upload/cover" `
        -Headers $headers `
        -Form $coverForm
    
    Remove-Item $tempCoverPath -Force
}

Write-Host ""
Write-Host "=== Post Media Tests ===" -ForegroundColor Cyan

# Test 3: Upload Multiple Post Media
Write-Host "Test 3: Upload Multiple Post Media" -ForegroundColor Yellow

$postId = [guid]::NewGuid().ToString()
$mediaFiles = @()

# Create 3 test files
for ($i = 1; $i -le 3; $i++) {
    $tempFile = "$env:TEMP\test-media-$i.jpg"
    $testData = [byte[]]::new(1024 * $i)
    (New-Object Random).NextBytes($testData)
    [System.IO.File]::WriteAllBytes($tempFile, $testData)
    $mediaFiles += $tempFile
}

# Upload as multipart form
$boundary = [System.Guid]::NewGuid().ToString()
$multipartContent = New-Object System.Net.Http.MultipartFormDataContent -ArgumentList $boundary

# Add post_id
$stringContent = New-Object System.Net.Http.StringContent -ArgumentList $postId
$stringContent.Headers.ContentDisposition = 'form-data; name="post_id"'
$multipartContent.Add($stringContent)

# Add media files
foreach ($file in $mediaFiles) {
    $fileStream = [System.IO.File]::OpenRead($file)
    $fileContent = New-Object System.Net.Http.StreamContent -ArgumentList $fileStream
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/jpeg")
    $fileContent.Headers.ContentDisposition = "form-data; name=`"media`"; filename=`"$(Split-Path $file -Leaf)`""
    $multipartContent.Add($fileContent)
}

try {
    $httpClient = New-Object System.Net.Http.HttpClient
    $httpClient.DefaultRequestHeaders.Add("Authorization", "Bearer $token")
    
    $response = $httpClient.PostAsync("$baseUrl/profile/upload/post-media", $multipartContent).Result
    $content = $response.Content.ReadAsStringAsync().Result
    
    Write-Host "Response Status: $($response.StatusCode)" -ForegroundColor $(if ($response.IsSuccessStatusCode) { "Green" } else { "Red" })
    $content | Write-Host
    
    $httpClient.Dispose()
}
catch {
    Write-Host "✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    $multipartContent.Dispose()
    foreach ($file in $mediaFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
        }
    }
}

Write-Host ""

# Test 4: Get Presigned Upload URL
Write-Host "Test 4: Get Presigned Upload URL" -ForegroundColor Yellow

$presignedBody = @{
    filename = "test-upload.jpg"
    file_type = "avatar"
}

Test-Endpoint `
    -Name "Get Presigned Upload URL" `
    -Method "POST" `
    -Url "$baseUrl/profile/upload/presigned-url" `
    -Headers $headers `
    -Body $presignedBody

Write-Host ""
Write-Host "=== Profile Tests ===" -ForegroundColor Cyan

# Test 5: Get My Profile
Test-Endpoint `
    -Name "Get My Profile" `
    -Method "GET" `
    -Url "$baseUrl/profile/me" `
    -Headers $headers

Write-Host ""
Write-Host "=== Storage Tests Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: To view uploaded files, access MinIO Console at http://localhost:9001" -ForegroundColor Yellow
Write-Host "Credentials: minioadmin / minioadmin" -ForegroundColor Yellow
