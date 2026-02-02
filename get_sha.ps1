#!/usr/bin/env pwsh

Write-Host "=== Debug Keystore SHA Certificates ===" -ForegroundColor Cyan
Write-Host ""

$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (-not (Test-Path $debugKeystore)) {
    Write-Host "Debug keystore not found at: $debugKeystore" -ForegroundColor Red
    Write-Host "Creating debug keystore..." -ForegroundColor Yellow
    
    $androidDir = "$env:USERPROFILE\.android"
    if (-not (Test-Path $androidDir)) {
        New-Item -ItemType Directory -Path $androidDir | Out-Null
    }
    
    keytool -genkey -v -keystore $debugKeystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
    Write-Host ""
}

Write-Host "Extracting SHA certificates from debug keystore..." -ForegroundColor Yellow
Write-Host ""

$output = keytool -list -v -alias androiddebugkey -keystore $debugKeystore -storepass android -keypass android 2>&1

$sha1 = ($output | Select-String "SHA1:").ToString().Split(":")[1].Trim()
$sha256 = ($output | Select-String "SHA256:").ToString().Split(":")[1].Trim()

Write-Host "SHA-1:   " -NoNewline -ForegroundColor Green
Write-Host $sha1
Write-Host "SHA-256: " -NoNewline -ForegroundColor Green  
Write-Host $sha256
Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Go to Firebase Console: https://console.firebase.google.com"
Write-Host "2. Select your project"
Write-Host "3. Go to Project Settings > Your apps > Android app"
Write-Host "4. Click 'Add fingerprint' and paste the SHA-1 and SHA-256 above"
Write-Host "5. Download the updated google-services.json"
Write-Host "6. Replace app/android/app/google-services.json with the new file"
Write-Host ""
Write-Host "=== Enable Phone Authentication ===" -ForegroundColor Cyan
Write-Host "1. Go to Firebase Console > Authentication > Sign-in method"
Write-Host "2. Enable 'Phone' provider"
Write-Host "3. Add Kazakhstan (+7) to allowed regions or enable 'Test phone numbers'"
Write-Host ""
