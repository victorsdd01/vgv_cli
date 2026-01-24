@echo off
REM FlutterForge CLI Uninstall Script for Windows
REM This script removes the FlutterForge CLI tool from your system

echo 🗑️  Uninstalling FlutterForge CLI...

REM Check if CLI is installed
where flutterforge >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ FlutterForge CLI is not installed.
    pause
    exit /b 1
)

REM Show current version before uninstalling
echo 📋 Current version:
flutterforge --version 2>nul || echo Version check failed

echo.
echo ⚠️  Are you sure you want to uninstall FlutterForge CLI? (Y/N)
set /p response=

if /i "%response%"=="Y" (
    echo 🗑️  Removing FlutterForge CLI...
    
    REM Deactivate the package
    dart pub global deactivate flutterforge
    
    REM Remove from PATH if it was added
    echo %PATH% | findstr /C:"%USERPROFILE%\.pub-cache\bin" >nul
    if %errorlevel% equ 0 (
        echo 🔧 Removing from PATH...
        REM Note: Manual removal from PATH may be needed
        echo Please manually remove %USERPROFILE%\.pub-cache\bin from your PATH if needed
    )
    
    echo ✅ FlutterForge CLI uninstalled successfully!
    echo.
    echo 💡 To reinstall later, run:
    echo    dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git
) else (
    echo ❌ Uninstallation cancelled.
)

pause 