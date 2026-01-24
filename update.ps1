# VGV CLI Update Script for Windows PowerShell
# This script updates the VGV CLI tool to the latest version

Write-Host "🔄 Updating VGV CLI..." -ForegroundColor Green

# Check current version
Write-Host "📋 Current version:" -ForegroundColor Cyan
vgv --version

Write-Host ""
Write-Host "📦 Updating to latest version..." -ForegroundColor Blue

# Update to latest version
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

Write-Host ""
Write-Host "✅ VGV CLI updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 New version:" -ForegroundColor Cyan
vgv --version

Write-Host ""
Write-Host "🚀 Happy coding with Flutter!" -ForegroundColor Green
Read-Host "Press Enter to continue" 