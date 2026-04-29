@echo off
setlocal EnableExtensions

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

set "PolWU=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
set "PolDr=HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
set "SysDr=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
set "Meta=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata"
set "Svcs=wuauserv bits dosvc UsoSvc WaaSMedicSvc uhssvc"
set "Tasks="\Microsoft\Windows\WindowsUpdate\Scheduled Start" "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan" "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task" "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker" "\Microsoft\Windows\WaaSMedic\PerformRemediation""

:MENU
cls
echo ==========================================
echo      WINDOWS UPDATE CONFIGURATION MANAGER
echo ==========================================
echo/
echo  [1] Hard Disable (No Store, No Drivers, No Metadata)
echo  [2] Moderate (Manual Updates)
echo  [3] Enable All
echo  [4] Manage Drivers ^& Devices Only
echo  [5] Exit
echo/
call :GetUpdateState
echo  Current update state: %UPDATE_STATE_TEXT%
echo/
choice /c 12345 /n /m "Select an option (1-5): "
set "choice=%errorlevel%"

if "%choice%"=="1" goto HARDDISABLE
if "%choice%"=="2" goto MODERATE
if "%choice%"=="3" goto ENABLEALL
if "%choice%"=="4" goto DRIVERSONLY
if "%choice%"=="5" goto EXIT
goto MENU

:HARDDISABLE
cls
echo Hard Disabling Windows Update...
echo/
set "FAIL_COUNT=0"

for %%s in (%Svcs%) do call :ConfigService %%s disabled
for %%t in (%Tasks%) do call :SetTaskState %%t DISABLE

call :SetRegValue "%PolWU%" DoNotConnectToWindowsUpdateInternetLocations 1
call :SetRegValue "%PolWU%" DisableWindowsUpdateAccess 1
call :SetRegValue "%PolWU%\AU" NoAutoUpdate 1
call :SetRegValue "%PolWU%" ExcludeWUDriversInQualityUpdate 1
call :SetRegValue "%PolDr%" SearchOrderConfig 0
call :SetRegValue "%SysDr%" SearchOrderConfig 0
call :SetRegValue "%Meta%" PreventDeviceMetadataFromNetwork 1

echo/
if "%FAIL_COUNT%"=="0" (
    echo [OK] Windows Update Hard Disabled. Please reboot your system.
) else (
    echo [WARNING] Windows Update Hard Disabled with %FAIL_COUNT% issue^(s^). Please review output and reboot your system.
)
pause
goto MENU

:MODERATE
cls
echo Configuring Moderate Updates (Manual)...
echo/
set "FAIL_COUNT=0"

for %%s in (%Svcs%) do call :ConfigService %%s demand
for %%t in (%Tasks%) do call :SetTaskState %%t ENABLE

call :DeleteRegValue "%PolWU%" DoNotConnectToWindowsUpdateInternetLocations
call :DeleteRegValue "%PolWU%" ExcludeWUDriversInQualityUpdate
call :DeleteRegValue "%PolWU%" DisableWindowsUpdateAccess
call :SetRegValue "%PolWU%\AU" NoAutoUpdate 1
call :SetRegValue "%PolWU%" DisableDualScan 1
call :SetRegValue "%PolDr%" SearchOrderConfig 1

echo/
if "%FAIL_COUNT%"=="0" (
    echo [OK] Windows Update set to Moderate (Manual). Please reboot your system.
) else (
    echo [WARNING] Windows Update set to Moderate with %FAIL_COUNT% issue^(s^). Please review output and reboot your system.
)
pause
goto MENU

:ENABLEALL
cls
echo Enabling All Windows Update Features...
echo/
set "FAIL_COUNT=0"

for %%s in (%Svcs%) do call :ConfigService %%s auto
for %%t in (%Tasks%) do call :SetTaskState %%t ENABLE

call :DeleteRegKey "%PolWU%"
call :DeleteRegKey "%PolDr%"
call :SetRegValue "%SysDr%" SearchOrderConfig 1
call :DeleteRegValue "%Meta%" PreventDeviceMetadataFromNetwork

echo/
if "%FAIL_COUNT%"=="0" (
    echo [OK] Windows Update Fully Enabled. Please reboot your system.
) else (
    echo [WARNING] Windows Update Enabled with %FAIL_COUNT% issue^(s^). Please review output and reboot your system.
)
pause
goto MENU

:DRIVERSONLY
cls
echo ==========================================
echo      DRIVERS ^& DEVICES CONFIGURATION
echo ==========================================
echo/
echo  [1] Block Drivers ^& Metadata
echo  [2] Allow Drivers ^& Metadata
echo  [3] Back to Main Menu
echo/
call :GetDriverState
echo  Current driver state: %DRIVER_STATE_TEXT%
echo/
choice /c 123 /n /m "Select an option (1-3): "
set "driver_choice=%errorlevel%"

if "%driver_choice%"=="1" goto BLOCKDRIVERS
if "%driver_choice%"=="2" goto ALLOWDRIVERS
if "%driver_choice%"=="3" goto MENU
goto DRIVERSONLY

:BLOCKDRIVERS
cls
echo Blocking Drivers ^& Metadata...
echo/
set "FAIL_COUNT=0"

call :SetRegValue "%PolWU%" ExcludeWUDriversInQualityUpdate 1
call :SetRegValue "%PolDr%" SearchOrderConfig 0
call :SetRegValue "%SysDr%" SearchOrderConfig 0
call :SetRegValue "%Meta%" PreventDeviceMetadataFromNetwork 1

echo/
if "%FAIL_COUNT%"=="0" (
    echo [OK] Drivers ^& Metadata Blocked.
) else (
    echo [WARNING] Drivers ^& Metadata Blocked with %FAIL_COUNT% issue^(s^).
)
pause
goto DRIVERSONLY

:ALLOWDRIVERS
cls
echo Allowing Drivers ^& Metadata...
echo/
set "FAIL_COUNT=0"

call :DeleteRegValue "%PolWU%" ExcludeWUDriversInQualityUpdate
call :DeleteRegKey "%PolDr%"
call :SetRegValue "%SysDr%" SearchOrderConfig 1
call :DeleteRegValue "%Meta%" PreventDeviceMetadataFromNetwork

echo/
if "%FAIL_COUNT%"=="0" (
    echo [OK] Drivers ^& Metadata Allowed.
) else (
    echo [WARNING] Drivers ^& Metadata Allowed with %FAIL_COUNT% issue^(s^).
)
pause
goto DRIVERSONLY

:GetDriverState
    set "DRIVER_STATE_TEXT=Unknown"
    
    set "DRIVERS_BLOCKED="
    reg query "%PolWU%" /v ExcludeWUDriversInQualityUpdate >nul 2>&1
    if not errorlevel 1 (
        for /f "tokens=3" %%A in ('reg query "%PolWU%" /v ExcludeWUDriversInQualityUpdate 2^>nul ^| findstr /I " ExcludeWUDriversInQualityUpdate "') do (
            if "%%A"=="0x1" set "DRIVERS_BLOCKED=1"
        )
    )
    
    if defined DRIVERS_BLOCKED (
        set "DRIVER_STATE_TEXT=Blocked"
    ) else (
        set "DRIVER_STATE_TEXT=Allowed"
    )
    exit /B 0

:GetUpdateState
    set "UPDATE_STATE_TEXT=Unknown"
    
    set "WU_DISABLED="
    reg query "%PolWU%" /v DisableWindowsUpdateAccess >nul 2>&1
    if not errorlevel 1 set "WU_DISABLED=1"
    
    set "WU_NO_AUTO="
    reg query "%PolWU%\AU" /v NoAutoUpdate >nul 2>&1
    if not errorlevel 1 set "WU_NO_AUTO=1"
    
    if defined WU_DISABLED (
        set "UPDATE_STATE_TEXT=Hard Disabled"
    ) else if defined WU_NO_AUTO (
        set "UPDATE_STATE_TEXT=Moderate (Manual)"
    ) else (
        set "UPDATE_STATE_TEXT=Fully Enabled"
    )
    exit /B 0

:ConfigService
    set "svc=%~1"
    set "start=%~2"
    sc query "%svc%" >nul 2>&1
    if errorlevel 1 (
        echo [SKIP] Service not present: %svc%
        exit /B 0
    )
    sc config "%svc%" start= %start% >nul 2>&1
    if "%start%"=="auto" (
        sc start "%svc%" >nul 2>&1
    )
    if errorlevel 1 (
        set /a FAIL_COUNT+=1
        echo [WARN] Failed to configure service: %svc%
    )
    exit /B 0

:SetTaskState
    set "task=%~1"
    set "state=%~2"
    schtasks /Query /TN "%task%" >nul 2>&1
    if errorlevel 1 (
        echo [SKIP] Scheduled task not present: %task%
        exit /B 0
    )
    schtasks /Change /TN "%task%" /%state% >nul 2>&1
    if errorlevel 1 (
        set /a FAIL_COUNT+=1
        echo [WARN] Failed to change scheduled task: %task%
    )
    exit /B 0

:SetRegValue
    set "key=%~1"
    set "value=%~2"
    set "data=%~3"
    reg add "%key%" /v "%value%" /t REG_DWORD /d "%data%" /f >nul 2>&1
    if errorlevel 1 (
        set /a FAIL_COUNT+=1
        echo [WARN] Failed to set registry value: %key%\\%value%
    )
    exit /B 0

:DeleteRegValue
    set "key=%~1"
    set "value=%~2"
    reg delete "%key%" /v "%value%" /f >nul 2>&1
    exit /B 0

:DeleteRegKey
    set "key=%~1"
    reg delete "%key%" /f >nul 2>&1
    exit /B 0