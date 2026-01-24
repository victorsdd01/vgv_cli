# FlutterForge CLI Installation Script for Windows PowerShell
# This script installs the FlutterForge CLI tool globally

Write-Host "🚀 Installing FlutterForge CLI..." -ForegroundColor Green

# Check if Dart is installed
try {
    $null = Get-Command dart -ErrorAction Stop
} catch {
    Write-Host "❌ Dart is not installed. Please install Dart first:" -ForegroundColor Red
    Write-Host "   https://dart.dev/get-dart" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if Flutter is installed
try {
    $null = Get-Command flutter -ErrorAction Stop
} catch {
    Write-Host "❌ Flutter is not installed. Please install Flutter first:" -ForegroundColor Red
    Write-Host "   https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Install the CLI globally
Write-Host "📦 Installing FlutterForge CLI..." -ForegroundColor Blue
dart pub global activate --source path .

# Add to PATH if not already there
$pubCacheBin = "$env:USERPROFILE\.pub-cache\bin"
if ($env:PATH -notlike "*$pubCacheBin*") {
    Write-Host "🔧 Adding to PATH..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$pubCacheBin", "User")
    Write-Host "Please restart your terminal or run: refreshenv" -ForegroundColor Yellow
}

Write-Host "✅ FlutterForge CLI installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Usage:" -ForegroundColor Cyan
Write-Host "  flutterforge" -ForegroundColor White
Write-Host ""
Write-Host "📚 For more information, visit:" -ForegroundColor Cyan
Write-Host "  https://github.com/victorsdd01/vgv_cli" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Happy coding with Flutter!" -ForegroundColor Green
Read-Host "Press Enter to continue" 