@echo off
setlocal EnableDelayedExpansion
title Network Reset
color 0f

:: ==================================================================================
:: ADMIN PRIVILEGE CHECK
:: ==================================================================================
fltmc >nul 2>&1 || (
    echo [ERROR] Administrator privileges required.
    echo Please right-click and select "Run as administrator".
    pause
    exit /b
)

cls
echo [WMAROS] Initializing Network Reset Sequence...
echo.

echo [*] Reverting global network parameter adjustments...

:: Revert DNS Coalescing
reg delete "HKLM\System\CurrentControlSet\Services\Dnscache\Parameters" /v "DisableCoalescing" /f >nul 2>&1

:: Revert WcmSvc Power Policies
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\Local" /v "fDisablePowerManagement" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy" /v "fDisablePowerManagement" /f >nul 2>&1

echo [*] Reverting adapter-specific configurations...
set "NetKey=HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"

for /f "tokens=*" %%A in ('reg query "%NetKey%" /s /v "*SpeedDuplex" ^| findstr "HKEY"') do (
    
    reg delete "%%A" /v "*EEE" /f >nul 2>&1
    reg delete "%%A" /v "AdvancedEEE" /f >nul 2>&1
    reg delete "%%A" /v "EEELinkAdvertisement" /f >nul 2>&1
    reg delete "%%A" /v "EeePhyEnable" /f >nul 2>&1
    reg delete "%%A" /v "EnableGreenEthernet" /f >nul 2>&1
    reg delete "%%A" /v "EnableGigaLite" /f >nul 2>&1
    reg delete "%%A" /v "GigaLite" /f >nul 2>&1
    
    reg delete "%%A" /v "EnablePME" /f >nul 2>&1
    reg delete "%%A" /v "*DeviceSleepOnDisconnect" /f >nul 2>&1
    reg delete "%%A" /v "*SipsEnabled" /f >nul 2>&1
    reg delete "%%A" /v "AutoPowerSaveModeEnabled" /f >nul 2>&1
    reg delete "%%A" /v "*NicAutoPowerSaver" /f >nul 2>&1
    reg delete "%%A" /v "PowerSaveEnable" /f >nul 2>&1
    reg delete "%%A" /v "EnablePowerManagement" /f >nul 2>&1
    reg delete "%%A" /v "EnableSavePowerNow" /f >nul 2>&1
    reg delete "%%A" /v "PowerSavingMode" /f >nul 2>&1
    reg delete "%%A" /v "SavePowerNowEnabled" /f >nul 2>&1
    reg delete "%%A" /v "ReduceSpeedOnPowerDown" /f >nul 2>&1
    
    reg delete "%%A" /v "*ModernStandbyWoLMagicPacket" /f >nul 2>&1
    reg delete "%%A" /v "*WakeOnMagicPacket" /f >nul 2>&1
    reg delete "%%A" /v "*WakeOnPattern" /f >nul 2>&1
    reg delete "%%A" /v "WakeOnLink" /f >nul 2>&1
    reg delete "%%A" /v "WakeOnSlot" /f >nul 2>&1
    reg delete "%%A" /v "WakeOnLinkChg" /f >nul 2>&1
    reg delete "%%A" /v "WakeOnLinkUp" /f >nul 2>&1
    reg delete "%%A" /v "WakeUpModeCap" /f >nul 2>&1
    reg delete "%%A" /v "WakeFromS5" /f >nul 2>&1
    reg delete "%%A" /v "WakeOn" /f >nul 2>&1
    reg delete "%%A" /v "WakeFromPowerOff" /f >nul 2>&1
    reg delete "%%A" /v "ForceWakeFromMagicPacketOnModernStandby" /f >nul 2>&1
    
    reg delete "%%A" /v "WolShutdownLinkSpeed" /f >nul 2>&1
    reg delete "%%A" /v "WakeOnMagicPacketFromS5" /f >nul 2>&1
    
    reg delete "%%A" /v "EnableAspm" /f >nul 2>&1
    reg delete "%%A" /v "ASPM" /f >nul 2>&1
    reg delete "%%A" /v "EnableD3ColdInS0" /f >nul 2>&1
    reg delete "%%A" /v "*SelectiveSuspend" /f >nul 2>&1
    reg delete "%%A" /v "PnPCapabilities" /f >nul 2>&1
    reg delete "%%A" /v "PowerDownPll" /f >nul 2>&1
    reg delete "%%A" /v "ULPMode" /f >nul 2>&1
    reg delete "%%A" /v "*EnableDynamicPowerGating" /f >nul 2>&1
    reg delete "%%A" /v "DynamicPowerGating" /f >nul 2>&1
    reg delete "%%A" /v "LogLinkStateEvent" /f >nul 2>&1
)

echo [*] Resetting TCP/IP Stack and Winsock...

ipconfig /flushdns >nul
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1
netsh winsock reset >nul
netsh int ip reset >nul
netsh int ipv6 reset >nul
netsh advfirewall reset >nul
arp -d * >nul 2>&1

echo.
echo [OK] Network reset complete. System reboot is required.
echo Rebooting in 5 seconds...
timeout /t 5 /nobreak >nul
shutdown /r /t 0