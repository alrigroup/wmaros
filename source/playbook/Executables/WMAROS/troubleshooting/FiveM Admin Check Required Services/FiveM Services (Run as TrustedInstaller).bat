@echo off
setlocal EnableDelayedExpansion

:: Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

:: If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting Administrator privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

:MENU
cls
echo ==========================================
echo      FIVEM CONFIGURATION MANAGER
echo ==========================================
echo.
echo  [1] ENABLE FiveM Services
echo  [2] DISABLE FiveM Services
echo  [3] Exit
echo.
set /p "choice=Select an option (1-3): "

if "%choice%"=="1" goto ENABLE
if "%choice%"=="2" goto DISABLE
if "%choice%"=="3" exit
goto MENU

:ENABLE
cls
echo Enabling FiveM Services...
echo.

sc config PcaSvc start= auto
sc config DPS start= auto
sc config DiagTrack start= auto
sc config SysMain start= auto
sc config EventLog start= auto


echo.
echo [OK] FiveM services are enabled. Please reboot your system.
pause
goto MENU

:DISABLE
cls
echo Disabling FiveM Services...
echo.

sc config PcaSvc start= disabled
sc config DPS start= disabled
sc config DiagTrack start= disabled
sc config SysMain start= disabled

echo.
echo [OK] FiveM services are disabled. Please reboot your system.
pause
goto MENU