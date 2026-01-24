# FlutterForge CLI Uninstall Script for Windows PowerShell
# This script removes the FlutterForge CLI tool from your system

Write-Host "🗑️  Uninstalling FlutterForge CLI..." -ForegroundColor Red

# Check if CLI is installed
try {
    $null = Get-Command flutterforge -ErrorAction Stop
} catch {
    Write-Host "❌ FlutterForge CLI is not installed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Show current version before uninstalling
Write-Host "📋 Current version:" -ForegroundColor Cyan
try {
    flutterforge --version
} catch {
    Write-Host "Version check failed" -ForegroundColor Yellow
}

Write-Host ""
$response = Read-Host "⚠️  Are you sure you want to uninstall FlutterForge CLI? (Y/N)"

if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "🗑️  Removing FlutterForge CLI..." -ForegroundColor Red
    
    # Deactivate the package
    dart pub global deactivate flutterforge
    
    # Remove from PATH if it was added
    $pubCacheBin = "$env:USERPROFILE\.pub-cache\bin"
    if ($env:PATH -like "*$pubCacheBin*") {
        Write-Host "🔧 Removing from PATH..." -ForegroundColor Yellow
        $newPath = ($env:PATH -split ';' | Where-Object { $_ -ne $pubCacheBin }) -join ';'
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "Removed from user PATH" -ForegroundColor Green
    }
    
    Write-Host "✅ FlutterForge CLI uninstalled successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 To reinstall later, run:" -ForegroundColor Cyan
    Write-Host "   dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git" -ForegroundColor White
} else {
    Write-Host "❌ Uninstallation cancelled." -ForegroundColor Yellow
}

Read-Host "Press Enter to continue" 