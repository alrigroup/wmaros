@echo off
setlocal EnableExtensions

set "FLTMGR=%SystemRoot%\System32\fltmc.exe"
set "WSCRIPT=%SystemRoot%\System32\wscript.exe"
set "BT_TASK=\Microsoft\Windows\Bluetooth\UninstallDeviceTask"

if exist "%FLTMGR%" (
    "%FLTMGR%" >nul 2>&1
) else (
    net session >nul 2>&1
)

if errorlevel 1 (
    echo Requesting Administrator privileges...
    goto UACPrompt
) else ( goto gotAdmin )

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
echo      BLUETOOTH CONFIGURATION MANAGER
echo ==========================================
echo.
echo  [1] ENABLE Bluetooth (Services + Task)
echo  [2] DISABLE Bluetooth (Services + Task)
echo  [3] Exit
echo.
call :GetBluetoothState
echo  Current service state: %BT_SERVICE_STATE_TEXT%
echo  Current task state:    %BT_TASK_STATE_TEXT%
echo.
choice /c 123 /n /m "Select an option (1-3): "
set "choice=%errorlevel%"

if "%choice%"=="1" goto ENABLE
if "%choice%"=="2" goto DISABLE
if "%choice%"=="3" goto EXIT
goto MENU

:ENABLE
cls
echo Enabling Bluetooth Services...
echo.
set "FAIL_COUNT=0"

call :ConfigService RFCOMM demand
call :ConfigService BthEnum demand
call :ConfigService bthleenum demand
call :ConfigService BTHMODEM demand
call :ConfigService BthA2dp demand
call :ConfigService microsoft_bluetooth_avrcptransport demand
call :ConfigService BthHFEnum demand
call :ConfigService BTAGService demand
call :ConfigService bthserv demand
call :ConfigService BluetoothUserService demand
call :ConfigService BthAvctpSvc demand
call :ConfigService BthMini demand
call :ConfigService BthPan demand
call :ConfigService BTHPORT demand
call :ConfigService BTHUSB demand
call :ConfigService HidBth demand

echo Enabling Scheduled Task: UninstallDeviceTask...
call :SetTaskState ENABLE

echo.
if "%FAIL_COUNT%"=="0" (
    echo [OK] Bluetooth Enabled. Please reboot your system.
) else (
    echo [WARNING] Bluetooth Enabled with %FAIL_COUNT% issue^(s^). Please review output and reboot your system.
)
pause
goto MENU

:DISABLE
cls
echo Disabling Bluetooth Services...
echo.
set "FAIL_COUNT=0"

call :ConfigService RFCOMM disabled
call :ConfigService BthEnum disabled
call :ConfigService bthleenum disabled
call :ConfigService BTHMODEM disabled
call :ConfigService BthA2dp disabled
call :ConfigService microsoft_bluetooth_avrcptransport disabled
call :ConfigService BthHFEnum disabled
call :ConfigService BTAGService disabled
call :ConfigService bthserv disabled
call :ConfigService BluetoothUserService disabled
call :ConfigService BthAvctpSvc disabled
call :ConfigService BthMini disabled
call :ConfigService BthPan disabled
call :ConfigService BTHPORT disabled
call :ConfigService BTHUSB disabled
call :ConfigService HidBth disabled

echo Disabling Scheduled Task: UninstallDeviceTask...
call :SetTaskState DISABLE

echo.
if "%FAIL_COUNT%"=="0" (
    echo [OK] Bluetooth Disabled. Please reboot your system.
) else (
    echo [WARNING] Bluetooth Disabled with %FAIL_COUNT% issue^(s^). Please review output and reboot your system.
)
pause
goto MENU

:ConfigService
    set "svc=%~1"
    set "start=%~2"
    sc query "%svc%" >nul 2>&1
    if errorlevel 1 (
        echo [SKIP] Service not present: %svc%
        exit /B 0
    )
    sc config "%svc%" start= %start% >nul 2>&1
    if errorlevel 1 (
        set /a FAIL_COUNT+=1
        echo [WARN] Failed to configure service: %svc%
    )
    exit /B 0

:SetTaskState
    set "state=%~1"
    schtasks /Query /TN "%BT_TASK%" >nul 2>&1
    if errorlevel 1 (
        echo [SKIP] Scheduled task not present: %BT_TASK%
        exit /B 0
    )
    schtasks /Change /TN "%BT_TASK%" /%state% >nul 2>&1
    if errorlevel 1 (
        set /a FAIL_COUNT+=1
        echo [WARN] Failed to change scheduled task: %BT_TASK%
    )
    exit /B 0

:GetBluetoothState
    set "BT_SERVICE_STATE_TEXT=Not present"
    set "BT_TASK_STATE_TEXT=Not present"

    set "BT_SERVICE_START_HEX="
    for /f "tokens=3" %%A in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\bthserv" /v Start 2^>nul ^| findstr /I " Start "') do set "BT_SERVICE_START_HEX=%%A"

    if defined BT_SERVICE_START_HEX (
        set "BT_SERVICE_STATE_TEXT=Unknown (%BT_SERVICE_START_HEX%)"
        if /I "%BT_SERVICE_START_HEX%"=="0x2" set "BT_SERVICE_STATE_TEXT=Enabled"
        if /I "%BT_SERVICE_START_HEX%"=="0x3" set "BT_SERVICE_STATE_TEXT=Enabled"
        if /I "%BT_SERVICE_START_HEX%"=="0x4" set "BT_SERVICE_STATE_TEXT=Disabled"
    )

    for /f "tokens=2 delims=: " %%A in ('schtasks /Query /TN "%BT_TASK%" /FO LIST 2^>nul ^| findstr /I "Status"') do (
        if /I "%%A"=="Ready"    set "BT_TASK_STATE_TEXT=Enabled"
        if /I "%%A"=="Running"  set "BT_TASK_STATE_TEXT=Enabled"
        if /I "%%A"=="Disabled" set "BT_TASK_STATE_TEXT=Disabled"
    )
    exit /B 0

:EXIT
    popd
    exit /B