@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "FLTMGR=%SystemRoot%\System32\fltmc.exe"
set "WSCRIPT=%SystemRoot%\System32\wscript.exe"

set "TASK_EDU=\Microsoft\Windows\Printing\EduPrintProv"
set "TASK_CLEANUP=\Microsoft\Windows\Printing\PrinterCleanupTask"
set "TASK_JOBCLEAN=\Microsoft\Windows\Printing\PrintJobCleanupTask"

set "FAIL_FLAG=%temp%\_printmgr_fail"

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
echo      PRINTING CONFIGURATION MANAGER
echo ==========================================
echo.
echo  [1] ENABLE  Printing
echo  [2] DISABLE Printing
echo  [3] Exit
echo.
call :ReadSvcState "Spooler"          SPOOLER_STATE
call :ReadSvcState "PrintWorkFlowUserSvc" PWFSVC_STATE
call :ReadSvcState "StiSvc"           STISVC_STATE
call :ReadTaskState "%TASK_EDU%"      TASK_EDU_STATE
call :ReadTaskState "%TASK_CLEANUP%"  TASK_CLEANUP_STATE
call :ReadTaskState "%TASK_JOBCLEAN%" TASK_JOBCLEAN_STATE
call :ReadFeatureState "Printing-Foundation-Features" FEAT_FOUND_STATE

echo  --- Services ---
echo    Spooler ........................ !SPOOLER_STATE!
echo    PrintWorkFlowUserSvc ........... !PWFSVC_STATE!
echo    StiSvc ......................... !STISVC_STATE!
echo  --- Scheduled Tasks ---
echo    EduPrintProv ................... !TASK_EDU_STATE!
echo    PrinterCleanupTask ............. !TASK_CLEANUP_STATE!
echo    PrintJobCleanupTask ............ !TASK_JOBCLEAN_STATE!
echo  --- Windows Features ---
echo    Printing-Foundation-Features ... !FEAT_FOUND_STATE!
echo.
choice /c 123 /n /m "Select an option (1-3): "
set "choice=%errorlevel%"

if "%choice%"=="1" goto ENABLE
if "%choice%"=="2" goto DISABLE
if "%choice%"=="3" goto EXIT
goto MENU

:ENABLE
cls
echo Enabling Printing...
echo.
if exist "%FAIL_FLAG%" del "%FAIL_FLAG%" >nul 2>&1

echo  [*] Services ...
call :ConfigService "Spooler"              auto
call :ConfigService "PrintWorkFlowUserSvc" demand
call :ConfigService "StiSvc"               demand
call :StartService  "Spooler"
call :StartService  "PrintWorkFlowUserSvc"
call :StartService  "StiSvc"

echo.
echo  [*] Scheduled Tasks ...
call :ConfigTask "%TASK_EDU%"      ENABLE
call :ConfigTask "%TASK_CLEANUP%"  ENABLE
call :ConfigTask "%TASK_JOBCLEAN%" ENABLE

echo.
echo  [*] Windows Features ...
call :ConfigFeature "Printing-Foundation-Features"                  ENABLE
call :ConfigFeature "Printing-Foundation-InternetPrinting-Client"   ENABLE
call :ConfigFeature "Printing-Foundation-LPDPrintService"           ENABLE
call :ConfigFeature "Printing-Foundation-LPRPortMonitor"            ENABLE
call :ConfigFeature "Printing-PrintToPDFServices-Features"          ENABLE
call :ConfigFeature "Printing-XPSServices-Features"                 ENABLE

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
echo Disabling Printing...
echo.
if exist "%FAIL_FLAG%" del "%FAIL_FLAG%" >nul 2>&1

echo  [*] Services ...
call :StopService  "Spooler"
call :StopService  "PrintWorkFlowUserSvc"
call :StopService  "StiSvc"
call :ConfigService "Spooler"              disabled
call :ConfigService "PrintWorkFlowUserSvc" disabled
call :ConfigService "StiSvc"               disabled

echo.
echo  [*] Scheduled Tasks ...
call :ConfigTask "%TASK_EDU%"      DISABLE
call :ConfigTask "%TASK_CLEANUP%"  DISABLE
call :ConfigTask "%TASK_JOBCLEAN%" DISABLE

echo.
echo  [*] Windows Features ...
call :ConfigFeature "Printing-Foundation-Features"                  DISABLE
call :ConfigFeature "Printing-Foundation-InternetPrinting-Client"   DISABLE
call :ConfigFeature "Printing-Foundation-LPDPrintService"           DISABLE
call :ConfigFeature "Printing-Foundation-LPRPortMonitor"            DISABLE
call :ConfigFeature "Printing-PrintToPDFServices-Features"          DISABLE
call :ConfigFeature "Printing-XPSServices-Features"                 DISABLE

echo.
if exist "%FAIL_FLAG%" (
    echo  [WARNING] Completed with issues. Review output above.
    del "%FAIL_FLAG%" >nul 2>&1
) else (
    echo  [OK] Done. Reboot recommended.
)
pause
goto MENU

:: ==============================
::   SUBROUTINES
:: ==============================

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
        echo    [WARN] Failed to configure: %_svc%
    ) else (
        echo    [OK]   %_svc% : %_start%
    )
    exit /B 0

:: %1=name
:StartService
    set "_svc=%~1"
    sc query "%_svc%" >nul 2>&1
    if errorlevel 1 ( exit /B 0 )
    sc start "%_svc%" >nul 2>&1
    if errorlevel 1 (
        echo    [WARN] Could not start: %_svc%
    ) else (
        echo    [OK]   Started: %_svc%
    )
    exit /B 0

:: %1=name
:StopService
    set "_svc=%~1"
    sc query "%_svc%" >nul 2>&1
    if errorlevel 1 ( exit /B 0 )
    sc stop "%_svc%" >nul 2>&1
    if errorlevel 1 (
        echo    [WARN] Could not stop: %_svc%
    ) else (
        echo    [OK]   Stopped: %_svc%
    )
    exit /B 0

:: %1=task path %2=ENABLE|DISABLE
:ConfigTask
    set "_task=%~1"
    set "_action=%~2"
    schtasks /Query /TN "%_task%" >nul 2>&1
    if errorlevel 1 (
        echo    [SKIP] Task not present: %_task%
        exit /B 0
    )
    schtasks /Change /TN "%_task%" /%_action% >nul 2>&1
    if errorlevel 1 (
        echo x >"%FAIL_FLAG%"
        echo    [WARN] Failed to %_action%: %_task%
    ) else (
        echo    [OK]   %_task% : %_action%
    )
    exit /B 0

:: %1=feature name %2=ENABLE|DISABLE
:ConfigFeature
    set "_feat=%~1"
    set "_action=%~2"
    set "_feat_state="
    for /f "tokens=3 delims=: " %%A in ('dism /Online /Get-FeatureInfo /FeatureName:%_feat% 2^>nul ^| findstr /I "State"') do set "_feat_state=%%A"
    if /I "!_feat_state!"=="%_action%D" (
        echo    [SKIP] %_feat% already !_feat_state!
        exit /B 0
    )
    if /I "%_action%"=="ENABLE" ( goto _feat_enable ) else ( goto _feat_disable )
:_feat_enable
    dism /Online /Enable-Feature /FeatureName:%_feat% /NoRestart >nul 2>&1
    goto _feat_check
:_feat_disable
    dism /Online /Disable-Feature /FeatureName:%_feat% /NoRestart >nul 2>&1
:_feat_check
    if errorlevel 1 (
        echo x >"%FAIL_FLAG%"
        echo    [WARN] Failed to %_action%: %_feat%
    ) else (
        echo    [OK]   %_feat% : %_action%
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
        if /I "!_rs_hex!"=="0x3" set "!_rs_var!=Enabled (Manual/Demand)"
        if /I "!_rs_hex!"=="0x4" set "!_rs_var!=Disabled"
    )
    exit /B 0

:: %1=task path %2=output-var
:ReadTaskState
    set "_rt_task=%~1"
    set "_rt_var=%~2"
    set "!_rt_var!=Not present"
    for /f "tokens=2 delims=: " %%A in ('schtasks /Query /TN "%_rt_task%" /FO LIST 2^>nul ^| findstr /I "Status"') do (
        if /I "%%A"=="Ready"    set "!_rt_var!=Enabled"
        if /I "%%A"=="Running"  set "!_rt_var!=Enabled"
        if /I "%%A"=="Disabled" set "!_rt_var!=Disabled"
    )
    exit /B 0

:: %1=feature name %2=output-var
:ReadFeatureState
    set "_rf_feat=%~1"
    set "_rf_var=%~2"
    set "!_rf_var!=Unknown"
    for /f "tokens=3 delims=: " %%A in ('dism /Online /Get-FeatureInfo /FeatureName:%_rf_feat% 2^>nul ^| findstr /I "State"') do (
        if /I "%%A"=="Enabled"  set "!_rf_var!=Enabled"
        if /I "%%A"=="Disabled" set "!_rf_var!=Disabled"
    )
    exit /B 0

:EXIT
    popd
    exit /B