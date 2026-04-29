@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "FLTMGR=%SystemRoot%\System32\fltmc.exe"
set "WSCRIPT=%SystemRoot%\System32\wscript.exe"

set "WPN_SYS_SVC=WpnService"
set "WPN_USR_SVC=WpnUserService"

set "TOAST_KEY=HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
set "TOAST_VAL=ToastEnabled"

set "FAIL_FLAG=%temp%\_notifmgr_fail"

:: UAC elevation
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
echo     NOTIFICATIONS CONFIGURATION MANAGER
echo ==========================================
echo.
echo  [1] ENABLE  Notifications
echo  [2] DISABLE Notifications
echo  [3] Exit
echo.
call :ReadSvcState "%WPN_SYS_SVC%"  WPN_SYS_STATE
call :ReadSvcState "%WPN_USR_SVC%"  WPN_USR_STATE
call :ReadRegDword "%TOAST_KEY%"    "%TOAST_VAL%"    TOAST_STATE

echo    WpnService ................... !WPN_SYS_STATE!
echo    WpnUserService ............... !WPN_USR_STATE!
echo    ToastEnabled ................. !TOAST_STATE!
echo.
choice /c 123 /n /m "Select an option (1-3): "
set "choice=%errorlevel%"

if "%choice%"=="1" goto ENABLE
if "%choice%"=="2" goto DISABLE
if "%choice%"=="3" goto EXIT
goto MENU

:ENABLE
cls
echo Enabling Notifications...
echo.
if exist "%FAIL_FLAG%" del "%FAIL_FLAG%" >nul 2>&1

call :ConfigService "%WPN_SYS_SVC%" "auto"
call :ConfigService "%WPN_USR_SVC%" "auto"
call :SetRegDword "%TOAST_KEY%" "%TOAST_VAL%" 1

echo.
if exist "%FAIL_FLAG%" (
    echo  [WARNING] Completed with issues. Review output above.
    del "%FAIL_FLAG%" >nul 2>&1
) else (
    echo  [OK] Done. Reboot recommended.
)
pause
goto MENU

:DISABLE
cls
echo Disabling Notifications...
echo.
if exist "%FAIL_FLAG%" del "%FAIL_FLAG%" >nul 2>&1

call :ConfigService "%WPN_SYS_SVC%" "disabled"
call :ConfigService "%WPN_USR_SVC%" "disabled"
call :SetRegDword "%TOAST_KEY%" "%TOAST_VAL%" 0

echo.
if exist "%FAIL_FLAG%" (
    echo  [WARNING] Completed with issues. Review output above.
    del "%FAIL_FLAG%" >nul 2>&1
) else (
    echo  [OK] Done. Reboot recommended.
)
pause
goto MENU

:: %1=name %2=start-type
:ConfigService
    set "_svc=%~1"
    set "_start=%~2"
    sc query "%_svc%" >nul 2>&1
    if errorlevel 1 (
        echo    [SKIP] %_svc% not present
        exit /B 0
    )
    sc config "%_svc%" start= %_start% >nul 2>&1
    if errorlevel 1 (
        echo x >"%FAIL_FLAG%"
        echo    [WARN] Failed: %_svc%
    ) else (
        echo    [OK]   %_svc% : %_start%
    )
    exit /B 0

:: %1=key %2=valuename %3=data
:SetRegDword
    set "_key=%~1"
    set "_vname=%~2"
    set "_data=%~3"
    reg add "%_key%" /v "%_vname%" /t REG_DWORD /d %_data% /f >nul 2>&1
    if errorlevel 1 (
        echo x >"%FAIL_FLAG%"
        echo    [WARN] Failed: %_vname%
    ) else (
        echo    [OK]   %_vname% = %_data%
    )
    exit /B 0

:: %1=name %2=output-var
:ReadSvcState
    set "_rs_svc=%~1"
    set "_rs_var=%~2"
    set "_rs_hex="
    for /f "tokens=3" %%A in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\%_rs_svc%" /v Start 2^>nul ^| findstr /I " Start "') do set "_rs_hex=%%A"
    if not defined _rs_hex (
        set "!_rs_var!=Not present"
    ) else (
        set "!_rs_var!=Unknown (!_rs_hex!)"
        if /I "!_rs_hex!"=="0x2" set "!_rs_var!=Enabled (Automatic)"
        if /I "!_rs_hex!"=="0x3" set "!_rs_var!=Enabled (Manual)"
        if /I "!_rs_hex!"=="0x4" set "!_rs_var!=Disabled"
    )
    exit /B 0

:: %1=key %2=valuename %3=output-var
:ReadRegDword
    set "_rd_key=%~1"
    set "_rd_vname=%~2"
    set "_rd_var=%~3"
    set "_rd_hex="
    for /f "tokens=3" %%A in ('reg query "%_rd_key%" /v "%_rd_vname%" 2^>nul ^| findstr /I " %_rd_vname% "') do set "_rd_hex=%%A"
    if not defined _rd_hex (
        set "!_rd_var!=Not set (defaults to Enabled)"
    ) else (
        set "!_rd_var!=Unknown (!_rd_hex!)"
        if /I "!_rd_hex!"=="0x0" set "!_rd_var!=Disabled"
        if /I "!_rd_hex!"=="0x1" set "!_rd_var!=Enabled"
    )
    exit /B 0

:EXIT
    popd
    exit /B