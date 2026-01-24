@echo off
REM VGV CLI Uninstall Script for Windows
REM This script removes the VGV CLI tool from your system

echo 🗑️  Uninstalling VGV CLI...

REM Check if CLI is installed
where vgv >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ VGV CLI is not installed.
    pause
    exit /b 1
)

REM Show current version before uninstalling
echo 📋 Current version:
vgv --version 2>nul || echo Version check failed

echo.
echo ⚠️  Are you sure you want to uninstall VGV CLI? (Y/N)
set /p response=

if /i "%response%"=="Y" (
    echo 🗑️  Removing VGV CLI...
    
    REM Deactivate the package
    dart pub global deactivate vgv
    
    REM Remove from PATH if it was added
    echo %PATH% | findstr /C:"%USERPROFILE%\.pub-cache\bin" >nul
    if %errorlevel% equ 0 (
        echo 🔧 Removing from PATH...
        REM Note: Manual removal from PATH may be needed
        echo Please manually remove %USERPROFILE%\.pub-cache\bin from your PATH if needed
    )
    
    echo ✅ VGV CLI uninstalled successfully!
    echo.
    echo 💡 To reinstall later, run:
    echo    dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git
) else (
    echo ❌ Uninstallation cancelled.
)

pause 