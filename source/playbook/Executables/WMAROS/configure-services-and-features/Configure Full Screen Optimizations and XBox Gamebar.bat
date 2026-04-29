@echo off

setlocal EnableExtensions

set "FLTMGR=%SystemRoot%\System32\fltmc.exe"
set "WSCRIPT=%SystemRoot%\System32\wscript.exe"
set "KEY_GAMEBAR=HKCU\Software\Microsoft\GameBar"
set "KEY_GAMEDVR=HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"
set "KEY_GAMECFG=HKCU\System\GameConfigStore"
set "KEY_POLICY=HKLM\Software\Policies\Microsoft\Windows\GameDVR"

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
echo GAME MODE ^& FSE/FSO MANAGER
echo ==========================================
echo.
echo FSE = Full Screen Exclusive (Legacy)
echo FSO = Full Screen Optimizations (Windows 10/11 Default)
echo.
echo Some games run better with FSO, some with FSE.
echo Please do your own testing.
echo.
call :GetGamingState
echo Current Game Bar/DVR: %STATE_GAMEDVR%
echo Current FSO/FSE:      %STATE_FSO%
echo HKLM Policy:          %STATE_POLICY%
echo.
echo --- COMBINED SETTINGS ---
echo [1] OPTIMIZE: Enable FSE ^& Disable Game Bar
echo (Forces FSE, Disables Game Mode/Overlay)
echo.
echo [2] RESTORE: Enable FSO ^& Game Bar (Windows Default)
echo (Restores Default Windows 11 Behavior)
echo.
echo --- GAME BAR/GAME MODE ONLY ---
echo [3] DISABLE Game Bar ^& Game Mode
echo [4] ENABLE Game Bar ^& Game Mode
echo.
echo --- FSE/FSO ONLY ---
echo [5] FORCE FSE (Disable FSO)
echo [6] ENABLE FSO (Windows Default)
echo.
echo [7] Exit
echo.
choice /c 1234567 /n /m "Select an option (1-7): "
set "choice=%errorlevel%"

if "%choice%"=="1" goto OPTIMIZE
if "%choice%"=="2" goto RESTORE
if "%choice%"=="3" goto DISABLE_BAR_ONLY
if "%choice%"=="4" goto ENABLE_BAR_ONLY
if "%choice%"=="5" goto FORCE_FSE
if "%choice%"=="6" goto ENABLE_FSO
if "%choice%"=="7" goto EXIT

goto MENU

:OPTIMIZE
cls
echo Applying Gaming Optimizations (FSE ON, GameBar OFF)...
echo.
set "FAIL_COUNT=0"

:: --- Disable Game Bar ---
call :RegAddDword "%KEY_GAMEBAR%" "AllowAutoGameMode" 0
call :RegAddDword "%KEY_GAMEBAR%" "AutoGameModeEnabled" 0
call :RegAddDword "%KEY_GAMEBAR%" "ShowStartupPanel" 0

:: --- Disable Game DVR ---
call :RegAddDword "%KEY_GAMEDVR%" "AppCaptureEnabled" 0
call :RegAddDword "%KEY_GAMEDVR%" "AudioCaptureEnabled" 0
call :RegAddDword "%KEY_GAMEDVR%" "CursorCaptureEnabled" 0
call :RegAddDword "%KEY_GAMEDVR%" "GameDVR_Enabled" 0

:: --- Force FSE (Disable FSO) ---
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_DSEBehavior" 2
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_FSEBehavior" 2
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_FSEBehaviorMode" 2
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_DXGIHonorFSEWindowsCompatible" 1
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_EFSEFeatureFlags" 0
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_HonorUserFSEBehaviorMode" 1
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_Enabled" 0

:: --- Disable Game Mode ---
call :RegAddDword "%KEY_GAMEBAR%" "UseNexusForGameBarEnabled" 0

:: --- HKLM Policies (System-wide) ---
call :RegAddDword "%KEY_POLICY%" "AllowGameDVR" 0

echo.
echo FSE Enabled and Game Bar/Game Mode Disabled.
echo Some changes may require a game restart or system reboot.
if "%FAIL_COUNT%"=="0" (
    echo.
    echo [OK] All requested changes were applied.
) else (
    echo.
    echo [WARNING] Applied with %FAIL_COUNT% issue^(s^).
)
pause
goto MENU

:RESTORE
cls
echo Restoring Windows Defaults (FSO ON, GameBar ON)...
echo.
set "FAIL_COUNT=0"

:: --- Enable Game Bar ---
call :RegDelValueIfExists "%KEY_GAMEBAR%" "AllowAutoGameMode"
call :RegDelValueIfExists "%KEY_GAMEBAR%" "AutoGameModeEnabled"
call :RegDelValueIfExists "%KEY_GAMEBAR%" "ShowStartupPanel"

:: --- Enable Game DVR ---
call :RegAddDword "%KEY_GAMEDVR%" "AppCaptureEnabled" 1
call :RegAddDword "%KEY_GAMEDVR%" "GameDVR_Enabled" 1

:: --- Enable FSO (Windows Default) ---
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_DSEBehavior"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_FSEBehavior"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_FSEBehaviorMode"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_DXGIHonorFSEWindowsCompatible"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_EFSEFeatureFlags"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_HonorUserFSEBehaviorMode"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_Enabled"

:: --- Enable Game Mode ---
call :RegDelValueIfExists "%KEY_GAMEBAR%" "UseNexusForGameBarEnabled"

:: --- HKLM Policies ---
call :RegDelValueIfExists "%KEY_POLICY%" "AllowGameDVR"

echo.
echo Windows Default Settings Restored.
echo Some changes may require a game restart.
if "%FAIL_COUNT%"=="0" (
    echo.
    echo [OK] All requested changes were applied.
) else (
    echo.
    echo [WARNING] Applied with %FAIL_COUNT% issue^(s^).
)
pause
goto MENU

:DISABLE_BAR_ONLY
cls
echo Disabling Game Bar ^& Game Mode...
echo.
set "FAIL_COUNT=0"

call :RegAddDword "%KEY_GAMEBAR%" "AllowAutoGameMode" 0
call :RegAddDword "%KEY_GAMEBAR%" "AutoGameModeEnabled" 0
call :RegAddDword "%KEY_GAMEDVR%" "AppCaptureEnabled" 0
call :RegAddDword "%KEY_GAMEDVR%" "GameDVR_Enabled" 0
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_Enabled" 0
call :RegAddDword "%KEY_POLICY%" "AllowGameDVR" 0

echo.
echo Game Bar ^& Game Mode Disabled.
if "%FAIL_COUNT%"=="0" (
    echo.
    echo [OK] All requested changes were applied.
) else (
    echo.
    echo [WARNING] Applied with %FAIL_COUNT% issue^(s^).
)
pause
goto MENU

:ENABLE_BAR_ONLY
cls
echo Enabling Game Bar ^& Game Mode...
echo.
set "FAIL_COUNT=0"

call :RegDelValueIfExists "%KEY_GAMEBAR%" "AllowAutoGameMode"
call :RegDelValueIfExists "%KEY_GAMEBAR%" "AutoGameModeEnabled"
call :RegAddDword "%KEY_GAMEDVR%" "AppCaptureEnabled" 1
call :RegAddDword "%KEY_GAMEDVR%" "GameDVR_Enabled" 1
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_Enabled"
call :RegDelValueIfExists "%KEY_POLICY%" "AllowGameDVR"

echo.
echo Game Bar ^& Game Mode Enabled.
if "%FAIL_COUNT%"=="0" (
    echo.
    echo [OK] All requested changes were applied.
) else (
    echo.
    echo [WARNING] Applied with %FAIL_COUNT% issue^(s^).
)
pause
goto MENU

:FORCE_FSE
cls
echo Forcing FSE Mode (Disabling FSO)...
echo.
set "FAIL_COUNT=0"

call :RegAddDword "%KEY_GAMECFG%" "GameDVR_DSEBehavior" 2
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_FSEBehavior" 2
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_FSEBehaviorMode" 2
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_DXGIHonorFSEWindowsCompatible" 1
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_EFSEFeatureFlags" 0
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_HonorUserFSEBehaviorMode" 1
call :RegAddDword "%KEY_GAMECFG%" "GameDVR_Enabled" 0

echo.
echo FSE Forced (FSO Disabled).
echo Apply to games via: Game exe ^> Properties ^> Compatibility ^> Disable fullscreen optimizations
if "%FAIL_COUNT%"=="0" (
    echo.
    echo [OK] All requested changes were applied.
) else (
    echo.
    echo [WARNING] Applied with %FAIL_COUNT% issue^(s^).
)
pause
goto MENU

:ENABLE_FSO
cls
echo Enabling FSO (Windows Default)...
echo.
set "FAIL_COUNT=0"

call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_DSEBehavior"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_FSEBehavior"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_FSEBehaviorMode"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_DXGIHonorFSEWindowsCompatible"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_EFSEFeatureFlags"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_HonorUserFSEBehaviorMode"
call :RegDelValueIfExists "%KEY_GAMECFG%" "GameDVR_Enabled"

echo.
echo FSO Enabled (Windows Default).
echo Disable via: Game exe ^> Properties ^> Compatibility ^> Disable fullscreen optimizations
if "%FAIL_COUNT%"=="0" (
    echo.
    echo [OK] All requested changes were applied.
) else (
    echo.
    echo [WARNING] Applied with %FAIL_COUNT% issue^(s^).
)
pause
goto MENU

:GetRegDwordHex
    set "%~3="
    for /f "tokens=3" %%A in ('reg query "%~1" /v "%~2" 2^>nul ^| findstr /I "%~2"') do set "%~3=%%A"
    exit /B 0

:RegAddDword
    reg add "%~1" /v "%~2" /t REG_DWORD /d "%~3" /f >nul 2>&1
    if errorlevel 1 (
        set /a FAIL_COUNT+=1
    )
    exit /B 0

:RegDelValueIfExists
    reg query "%~1" /v "%~2" >nul 2>&1
    if errorlevel 1 exit /B 0
    reg delete "%~1" /v "%~2" /f >nul 2>&1
    if errorlevel 1 (
        set /a FAIL_COUNT+=1
    )
    exit /B 0

:GetGamingState
    set "STATE_GAMEDVR=Default"
    set "STATE_FSO=Default FSO"
    set "STATE_POLICY=Not set"

    set "_dvr="
    call :GetRegDwordHex "%KEY_GAMEDVR%" "GameDVR_Enabled" _dvr
    if defined _dvr (
        if /I "%_dvr%"=="0x0" set "STATE_GAMEDVR=Disabled"
        if /I "%_dvr%"=="0x1" set "STATE_GAMEDVR=Enabled"
        if /I not "%_dvr%"=="0x0" if /I not "%_dvr%"=="0x1" set "STATE_GAMEDVR=Unknown (%_dvr%)"
    )

    set "_fse="
    call :GetRegDwordHex "%KEY_GAMECFG%" "GameDVR_FSEBehavior" _fse
    if defined _fse (
        if /I "%_fse%"=="0x2" set "STATE_FSO=Forced FSE"
        if /I not "%_fse%"=="0x2" set "STATE_FSO=Unknown (%_fse%)"
    )

    set "_pol="
    call :GetRegDwordHex "%KEY_POLICY%" "AllowGameDVR" _pol
    if defined _pol (
        if /I "%_pol%"=="0x0" set "STATE_POLICY=Policy Disabled"
        if /I "%_pol%"=="0x1" set "STATE_POLICY=Policy Enabled"
        if /I not "%_pol%"=="0x0" if /I not "%_pol%"=="0x1" set "STATE_POLICY=Unknown (%_pol%)"
    )
    exit /B 0

:EXIT
    popd
    exit /B
