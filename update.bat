@echo off
REM FlutterForge CLI Update Script for Windows
REM This script updates the FlutterForge CLI tool to the latest version

echo 🔄 Updating FlutterForge CLI...

REM Check current version
echo 📋 Current version:
flutterforge --version

echo.
echo 📦 Updating to latest version...

REM Update to latest version
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

echo.
echo ✅ FlutterForge CLI updated successfully!
echo.
echo 📋 New version:
flutterforge --version

echo.
echo 🚀 Happy coding with Flutter!
pause 