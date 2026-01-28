#!/usr/bin/env pwsh
# Firebase Phone Authentication Fix Helper Script

Write-Host "`n=== Firebase Phone Authentication Fix Helper ===" -ForegroundColor Cyan
Write-Host ""

# Display SHA Certificates
Write-Host "✅ STEP 1: Your SHA Certificates (Copy These)" -ForegroundColor Green
Write-Host ""
Write-Host "SHA-1:   " -NoNewline -ForegroundColor Yellow
Write-Host "60:6D:F7:67:92:A7:22:CD:C4:B4:0A:43:47:D4:49:25:0E:A6:B8:CF"
Write-Host "SHA-256: " -NoNewline -ForegroundColor Yellow
Write-Host "61:8E:73:67:0F:7E:0D:73:26:2C:E4:A7:C1:43:E8:0A:E8:9B:A2:4E:4E:D9:82:C7:16:C2:7A:12:1A:DC:EC:43"
Write-Host ""

# Step 2: Firebase Console Instructions
Write-Host "📋 STEP 2: Add SHA Certificates to Firebase" -ForegroundColor Green
Write-Host ""
Write-Host "1. Open Firebase Console:" -ForegroundColor White
Write-Host "   https://console.firebase.google.com/project/smsbb-6e583/settings/general" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Scroll to 'Your apps' → Find Android app (com.brightbund)" -ForegroundColor White
Write-Host ""
Write-Host "3. Click 'Add fingerprint' and paste SHA-1 (first one above)" -ForegroundColor White
Write-Host "   Then click 'Add fingerprint' again and paste SHA-256" -ForegroundColor White
Write-Host ""

$response = Read-Host "Have you added BOTH SHA certificates to Firebase? (y/n)"
if ($response -ne 'y') {
    Write-Host "❌ Please add the SHA certificates first, then run this script again." -ForegroundColor Red
    exit 1
}

# Step 3: Download google-services.json reminder
Write-Host ""
Write-Host "📥 STEP 3: Download google-services.json" -ForegroundColor Green
Write-Host ""
Write-Host "1. In Firebase Console → Project Settings → Your apps" -ForegroundColor White
Write-Host "2. Click 'Download google-services.json'" -ForegroundColor White
Write-Host "3. Save it to your Downloads folder" -ForegroundColor White
Write-Host ""

$response = Read-Host "Have you downloaded the NEW google-services.json? (y/n)"
if ($response -ne 'y') {
    Write-Host "❌ Please download google-services.json first, then run this script again." -ForegroundColor Red
    exit 1
}

# Step 4: Copy google-services.json
Write-Host ""
Write-Host "📁 STEP 4: Replacing google-services.json" -ForegroundColor Green
Write-Host ""

$downloadsPath = "$env:USERPROFILE\Downloads\google-services.json"
$targetPath = "d:\projects\test\brightbund\app\android\app\google-services.json"

if (Test-Path $downloadsPath) {
    Copy-Item -Path $downloadsPath -Destination $targetPath -Force
    Write-Host "✅ google-services.json copied successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️  google-services.json not found in Downloads folder." -ForegroundColor Yellow
    Write-Host "   Please manually copy it to:" -ForegroundColor Yellow
    Write-Host "   $targetPath" -ForegroundColor Cyan
    $response = Read-Host "   Have you copied it manually? (y/n)"
    if ($response -ne 'y') {
        Write-Host "❌ Please copy google-services.json, then run this script again." -ForegroundColor Red
        exit 1
    }
}

# Step 5: Test Phone Numbers
Write-Host ""
Write-Host "📞 STEP 5: Enable Test Phone Numbers" -ForegroundColor Green
Write-Host ""
Write-Host "1. Go to Firebase Console → Authentication → Sign-in method" -ForegroundColor White
Write-Host "   https://console.firebase.google.com/project/smsbb-6e583/authentication/providers" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Click 'Phone' provider" -ForegroundColor White
Write-Host ""
Write-Host "3. Scroll to 'Test phone numbers' section" -ForegroundColor White
Write-Host ""
Write-Host "4. Add test number:" -ForegroundColor White
Write-Host "   Phone: " -NoNewline
Write-Host "+77067119305" -ForegroundColor Cyan
Write-Host "   Code:  " -NoNewline
Write-Host "123456" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Click 'Save'" -ForegroundColor White
Write-Host ""

$response = Read-Host "Have you added the test phone number? (y/n)"
if ($response -ne 'y') {
    Write-Host "❌ Please add test phone number first, then run this script again." -ForegroundColor Red
    exit 1
}

# Step 6: Clean and Rebuild
Write-Host ""
Write-Host "🧹 STEP 6: Cleaning and Rebuilding" -ForegroundColor Green
Write-Host ""

Set-Location "d:\projects\test\brightbund\app"

Write-Host "Cleaning Flutter project..." -ForegroundColor Yellow
flutter clean | Out-Null

Write-Host "Removing Android build cache..." -ForegroundColor Yellow
if (Test-Path "android\build") { Remove-Item -Recurse -Force "android\build" }
if (Test-Path "android\app\build") { Remove-Item -Recurse -Force "android\app\build" }

Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get | Out-Null

Write-Host "✅ Project cleaned and ready!" -ForegroundColor Green

# Step 7: Run Instructions
Write-Host ""
Write-Host "🚀 STEP 7: Run Your App" -ForegroundColor Green
Write-Host ""
Write-Host "Run this command:" -ForegroundColor White
Write-Host "   flutter run --debug --flavor dev -t lib/main_dev.dart" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test with:" -ForegroundColor White
Write-Host "   Phone: +77067119305" -ForegroundColor Cyan
Write-Host "   Code:  123456" -ForegroundColor Cyan
Write-Host ""

$response = Read-Host "Do you want to run the app now? (y/n)"
if ($response -eq 'y') {
    Write-Host ""
    Write-Host "Starting app..." -ForegroundColor Yellow
    flutter run --debug --flavor dev -t lib/main_dev.dart
} else {
    Write-Host ""
    Write-Host "✅ Setup complete! Run the app when you're ready." -ForegroundColor Green
    Write-Host ""
}
