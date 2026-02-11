$BASE_URL = "http://localhost:8081/api/v1"

Write-Host "=== Testing Ranks Module ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Testing GET /ranks (public endpoint)" -ForegroundColor Yellow
$response = Invoke-RestMethod -Uri "$BASE_URL/ranks" -Method Get
Write-Host "Status: OK" -ForegroundColor Green
Write-Host "Number of ranks: $($response.ranks.Count)" -ForegroundColor Green

Write-Host ""
Write-Host "Rank catalog:" -ForegroundColor White
foreach ($rank in $response.ranks) {
    Write-Host "  - $($rank.name) | $($rank.quality) ($($rank.min_seals)-$($rank.max_seals) seals)" -ForegroundColor White
    Write-Host "    Levels: $($rank.sub_levels.Count) (C, B, A, S)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "2. Testing GET /ranks/me (requires authentication)" -ForegroundColor Yellow

$loginBody = @{
    email = "test@example.com"
    password = "password123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$BASE_URL/auth/login-email" -Method Post -Body $loginBody -ContentType "application/json"
    $accessToken = $loginResponse.access_token
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }
    
    $myRankResponse = Invoke-RestMethod -Uri "$BASE_URL/ranks/me" -Method Get -Headers $headers
    Write-Host "Status: OK" -ForegroundColor Green
    Write-Host "Current rank: $($myRankResponse.full_title)" -ForegroundColor Green
    Write-Host "Current seals: $($myRankResponse.current_seals)" -ForegroundColor Green
    Write-Host "Progress in rank: $([math]::Round($myRankResponse.progress_in_rank, 2))%" -ForegroundColor Green
    Write-Host "Progress to next level: $([math]::Round($myRankResponse.progress_to_next_level, 2))%" -ForegroundColor Green
    
    if ($myRankResponse.next_level) {
        Write-Host "Next level: $($myRankResponse.next_level)" -ForegroundColor Cyan
    }
    if ($myRankResponse.next_rank) {
        Write-Host "Next rank: $($myRankResponse.next_rank)" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Note: Make sure to create a test user first or use valid credentials" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Ranks Module Tests Complete ===" -ForegroundColor Cyan
