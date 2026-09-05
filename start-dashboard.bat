@echo off
REM Dashboard starter for Windows with HTTPS support guidance

echo.
echo ========================================
echo YouTube Mission Control Dashboard
echo ========================================
echo.

setlocal enabledelayedexpansion

set PORT=8080
set SCRIPT_DIR=%~dp0
set CERT_DIR=%SCRIPT_DIR%.certs

echo Starting server on port %PORT%...
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python 3 is required but not installed.
    echo Please install Python from https://www.python.org/downloads/
    pause
    exit /b 1
)

REM Inform about HTTPS-Only mode
echo.
echo If using Safari with HTTPS-Only mode enabled:
echo - See SAFARI_HTTPS_ONLY_FIX.md for instructions
echo - The easiest fix: Disable HTTPS-Only in Safari Settings temporarily
echo - Or: Use a different browser (Chrome, Firefox, Edge all work fine)
echo.

REM Start the HTTP server
cd /d "%SCRIPT_DIR%"
python -m http.server %PORT%

pause
