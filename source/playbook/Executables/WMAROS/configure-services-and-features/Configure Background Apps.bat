@echo off
setlocal EnableExtensions

set "REG_KEY=HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
set "FLTMGR=%SystemRoot%\System32\fltmc.exe"
set "WSCRIPT=%SystemRoot%\System32\wscript.exe"

if exist "%FLTMGR%" (
    "%FLTMGR%" >nul 2>&1
) else (
    net session >nul 2>&1
)
if errorlevel 1 (
    echo Requesting Administrator privileges...
    goto UACPrompt
)
goto gotAdmin

:UACPrompt
    set "vbs=%temp%\getadmin.vbs"
    > "%vbs%" echo Set UAC = CreateObject^("Shell.Application"^)
    >>"%vbs%" echo UAC.ShellExecute "%~f0", "", "", "runas", 1
    if exist "%WSCRIPT%" (
        "%WSCRIPT%" "%vbs%"
    ) else (
        "%vbs%"
    )
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" >nul 2>&1
    pushd "%~dp0"

:MENU
cls
echo ==========================================
echo    BACKGROUND APPS CONFIGURATION MANAGER
echo ==========================================
echo.
echo.
echo      Manage the "Let apps run in the background" policy.
echo.
call :GetBackgroundAppsState
echo  Current policy state: %BACKGROUND_APPS_STATE_TEXT%
echo.
echo  [1] ENABLE Background Apps (More resource usage, necessary for some apps like WhatsApp Desktop)
echo  [2] DISABLE Background Apps
echo  [3] Exit
echo.
choice /c 123 /n /m "Select an option (1-3): "
set "choice=%errorlevel%"

if "%choice%"=="1" goto ENABLE
if "%choice%"=="2" goto DISABLE
if "%choice%"=="3" goto EXIT
goto MENU

:ENABLE
cls
echo Enabling Background Apps...
echo.
call :SetBackgroundApps 1
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to enable Background Apps.
    pause
    goto MENU
)

echo.
echo [OK] Background Apps have been ENABLED.
pause
goto MENU

:DISABLE
cls
echo Disabling Background Apps...
echo.
call :SetBackgroundApps 2
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to disable Background Apps.
    pause
    goto MENU
)

echo.
echo [OK] Background Apps have been DISABLED.
pause
goto MENU

:SetBackgroundApps
    set "mode=%~1"
    if not "%mode%"=="1" if not "%mode%"=="2" exit /B 2

    reg add "%REG_KEY%" /v "LetAppsRunInBackground" /t REG_DWORD /d "%mode%" /f >nul
    if errorlevel 1 exit /B 1

    reg delete "%REG_KEY%" /v "LetAppsRunInBackground_UserInControlOfTheseApps" /f >nul 2>&1
    reg delete "%REG_KEY%" /v "LetAppsRunInBackground_ForceAllowTheseApps" /f >nul 2>&1
    reg delete "%REG_KEY%" /v "LetAppsRunInBackground_ForceDenyTheseApps" /f >nul 2>&1

    call :GetBackgroundAppsState
    if "%mode%"=="1" if /I not "%BACKGROUND_APPS_STATE_HEX%"=="0x1" exit /B 1
    if "%mode%"=="2" if /I not "%BACKGROUND_APPS_STATE_HEX%"=="0x2" exit /B 1
    exit /B 0

:GetBackgroundAppsState
    set "BACKGROUND_APPS_STATE_HEX="
    set "BACKGROUND_APPS_STATE_TEXT=Not configured"
    for /f "tokens=2,3" %%A in ('reg query "%REG_KEY%" /v "LetAppsRunInBackground" 2^>nul ^| find /I "LetAppsRunInBackground"') do (
        set "BACKGROUND_APPS_STATE_HEX=%%B"
    )
    if not defined BACKGROUND_APPS_STATE_HEX exit /B 0

    if /I "%BACKGROUND_APPS_STATE_HEX%"=="0x1" set "BACKGROUND_APPS_STATE_TEXT=Enabled"
    if /I "%BACKGROUND_APPS_STATE_HEX%"=="0x2" set "BACKGROUND_APPS_STATE_TEXT=Disabled"
    if /I not "%BACKGROUND_APPS_STATE_HEX%"=="0x1" if /I not "%BACKGROUND_APPS_STATE_HEX%"=="0x2" set "BACKGROUND_APPS_STATE_TEXT=Unknown (%BACKGROUND_APPS_STATE_HEX%)"
    exit /B 0

:EXIT
    popd
    exit /B