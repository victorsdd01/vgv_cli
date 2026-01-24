@echo off
REM VGV CLI Update Script for Windows
REM This script updates the VGV CLI tool to the latest version

echo 🔄 Updating VGV CLI...

REM Check current version
echo 📋 Current version:
vgv --version

echo.
echo 📦 Updating to latest version...

REM Update to latest version
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

echo.
echo ✅ VGV CLI updated successfully!
echo.
echo 📋 New version:
vgv --version

echo.
echo 🚀 Happy coding with Flutter!
pause 