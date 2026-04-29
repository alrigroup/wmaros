@echo off
SETLOCAL EnableDelayedExpansion

for /F "tokens=*" %%c in ('powershell -Command " (Get-CimInstance -ClassName Win32_SystemEnclosure).ChassisTypes -join ',' "') do set "ChassisTypeString=%%c"
for /F "tokens=1 delims=," %%t in ("%ChassisTypeString%") do set "PrimaryChassisType=%%t"
set /A ChassisType=%PrimaryChassisType% 2>NUL

if not defined ChassisType (
    echo Error: Could not determine chassis type.
    goto :EOF
)

echo Detected Chassis Type: %ChassisType%

if %ChassisType% LEQ 7 (
    goto DESKTOP
) else (
    goto LAPTOP
)

:DESKTOP

Reg.exe add "HKLM\System\CurrentControlSet\Services\Dnscache\Parameters" /v "DisableCoalescing" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\Local" /v "fDisablePowerManagement" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy" /v "fDisablePowerManagement" /t REG_DWORD /d "1" /f

for /f %%a in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" /v "*SpeedDuplex" /s ^| findstr "HKEY"') do (
    
    reg query "%%a" /v "*PhyType" >nul 2>&1
    if !errorlevel! equ 0 (
        echo Skipping Wi-Fi adapter: %%a
    ) else (
        echo Applying tweaks to Ethernet adapter: %%a
        
        for /f %%i in ('reg query "%%a" /v "EnablePME" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnablePME" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*DeviceSleepOnDisconnect" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*DeviceSleepOnDisconnect" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*EEE" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*EEE" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "AdvancedEEE" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "AdvancedEEE" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*SipsEnabled" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*SipsEnabled" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EnableAspm" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnableAspm" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "ASPM" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "ASPM" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*ModernStandbyWoLMagicPacket" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*ModernStandbyWoLMagicPacket" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*SelectiveSuspend" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*SelectiveSuspend" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EnableGigaLite" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnableGigaLite" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "GigaLite" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "GigaLite" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*WakeOnMagicPacket" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*WakeOnMagicPacket" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*WakeOnPattern" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*WakeOnPattern" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "AutoPowerSaveModeEnabled" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "AutoPowerSaveModeEnabled" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*DeviceSleepOnDisconnect" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*DeviceSleepOnDisconnect" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EEELinkAdvertisement" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EEELinkAdvertisement" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EeePhyEnable" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EeePhyEnable" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EnableGreenEthernet" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnableGreenEthernet" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EnableModernStandby" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnableModernStandby" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "PnPCapabilities" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "PnPCapabilities" /t REG_DWORD /d "24" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "PowerDownPll" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "PowerDownPll" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "PowerSavingMode" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "PowerSavingMode" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "ReduceSpeedOnPowerDown" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "ReduceSpeedOnPowerDown" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "S5WakeOnLan" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "S5WakeOnLan" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "SavePowerNowEnabled" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "SavePowerNowEnabled" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "ULPMode" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "ULPMode" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeOnLink" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeOnLink" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeOnSlot" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeOnSlot" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeOnLinkChg" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeOnLinkChg" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeOnLinkUp" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeOnLinkUp" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeUpModeCap" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeUpModeCap" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeOnMagicPacketFromS5" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeOnMagicPacketFromS5" /t REG_SZ /d "2" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WolShutdownLinkSpeed" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WolShutdownLinkSpeed" /t REG_SZ /d "2" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*NicAutoPowerSaver" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*NicAutoPowerSaver" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "PowerSaveEnable" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "PowerSaveEnable" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EnablePowerManagement" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnablePowerManagement" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "ForceWakeFromMagicPacketOnModernStandby" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "ForceWakeFromMagicPacketOnModernStandby" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeFromS5" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeFromS5" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeOn" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeOn" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EnableSavePowerNow" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnableSavePowerNow" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "*EnableDynamicPowerGating" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "*EnableDynamicPowerGating" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "DynamicPowerGating" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "DynamicPowerGating" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "EnableD3ColdInS0" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "EnableD3ColdInS0" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "WakeFromPowerOff" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "WakeFromPowerOff" /t REG_SZ /d "0" /f >nul 2>&1
        )
        for /f %%i in ('reg query "%%a" /v "LogLinkStateEvent" ^| findstr "HKEY"') do (
            Reg.exe add "%%i" /v "LogLinkStateEvent" /t REG_SZ /d "0" /f >nul 2>&1
        )
    )
) >nul 2>&1

echo Network tweaks applied successfully for desktop Ethernet adapters.
goto :END

:LAPTOP
echo Laptop detected - no network tweaks applied.
goto :END

:END
exit