@echo off
setlocal EnableDelayedExpansion

:: Check for UAC permissions
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

:: List of devices to target
set "DEVICES="Communications Port (COM1)" "Communications Port (COM2)" "Communications Port (SER1)" "Communications Port (SER2)""

:: List of serial-related services
set "SERVICES=Serenum Serial sermouse usbser Parport"

:MENU
cls
echo ==========================================
echo       SERIAL PORT CONFIGURATION
echo ==========================================
echo.
echo  [1] ENABLE Serial Ports
echo.
echo  [2] DISABLE Serial Ports
echo      * WARNING: Most laptop touchpads and keyboards connect via Serial Port.
echo        Disabling this may cause your touchpad to stop working.
echo.
echo  [3] Exit
echo.
set /p "choice=Select an option (1-3): "

if "%choice%"=="1" goto ENABLE
if "%choice%"=="2" goto DISABLE
if "%choice%"=="3" exit
goto MENU

:ENABLE
cls
echo Enabling Serial Ports and Services...
echo.

:: Enable devices
for %%D in (%DEVICES%) do (
    call :EnableDevice "%%~D"
)

:: Enable services
for %%S in (%SERVICES%) do (
    call :EnableService "%%~S"
)

echo.
echo [OK] Serial Ports and Services Enabled.
pause
goto MENU

:DISABLE
cls
echo Disabling Serial Ports and Services...
echo.

:: Disable devices
for %%D in (%DEVICES%) do (
    call :DisableDevice "%%~D"
)

:: Disable services
for %%S in (%SERVICES%) do (
    call :DisableService "%%~S"
)

echo.
echo [OK] Serial Ports and Services Disabled.
pause
goto MENU

:EnableDevice
set "DEV_NAME=%~1"
:: PowerShell command to Enable PnP Device
powershell -NoProfile -Command "$obj = Get-PnpDevice -FriendlyName '%DEV_NAME%' -ErrorAction Ignore; if ($obj) { Write-Host 'Enabling Device: %DEV_NAME%'; $obj | Enable-PnpDevice -Confirm:$false } else { Write-Host 'Device Not Found: %DEV_NAME%' }"
goto :eof

:DisableDevice
set "DEV_NAME=%~1"
:: PowerShell command to Disable PnP Device
powershell -NoProfile -Command "$obj = Get-PnpDevice -FriendlyName '%DEV_NAME%' -ErrorAction Ignore; if ($obj) { Write-Host 'Disabling Device: %DEV_NAME%'; $obj | Disable-PnpDevice -Confirm:$false } else { Write-Host 'Device Not Found: %DEV_NAME%' }"
goto :eof

:EnableService
set "SVC_NAME=%~1"
:: PowerShell command to Enable Service (set to Automatic and start it)
powershell -NoProfile -Command "$service = Get-Service -Name '%SVC_NAME%' -ErrorAction SilentlyContinue; if ($service) { Write-Host 'Enabling Service: %SVC_NAME%'; Set-Service -Name '%SVC_NAME%' -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name '%SVC_NAME%' -ErrorAction SilentlyContinue } else { Write-Host 'Service Not Found: %SVC_NAME%' }"
goto :eof

:DisableService
set "SVC_NAME=%~1"
:: PowerShell command to Disable Service (stop it and set to Disabled)
powershell -NoProfile -Command "$service = Get-Service -Name '%SVC_NAME%' -ErrorAction SilentlyContinue; if ($service) { Write-Host 'Disabling Service: %SVC_NAME%'; Stop-Service -Name '%SVC_NAME%' -Force -ErrorAction SilentlyContinue; Set-Service -Name '%SVC_NAME%' -StartupType Disabled -ErrorAction SilentlyContinue } else { Write-Host 'Service Not Found: %SVC_NAME%' }"
goto :eof