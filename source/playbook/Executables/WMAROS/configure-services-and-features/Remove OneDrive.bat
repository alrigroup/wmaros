@echo off
SETLOCAL EnableDelayedExpansion EnableExtensions

:: ============================================
:: Administrator Check
:: ============================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script must be run as administrator.
    pause
    exit /b 1
)

:: ============================================
:: Check if OneDrive is actually installed
:: ============================================
set "OneDriveInstalled=0"

:: Check for OneDrive process
tasklist /FI "IMAGENAME eq OneDrive.exe" 2>nul | find /I "OneDrive.exe" >nul
if %errorlevel% equ 0 set "OneDriveInstalled=1"

:: Check for OneDrive.exe in user's local AppData
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe" set "OneDriveInstalled=1"

:: Check registry for OneDrive installation
reg query "HKCU\Software\Microsoft\OneDrive" /v "UserFolder" >nul 2>&1
if %errorlevel% equ 0 set "OneDriveInstalled=1"

:: Check for user OneDrive folders
if !OneDriveInstalled! equ 0 (
    for /f "usebackq delims=" %%a in (`dir /b /a:d "%SystemDrive%\Users" 2^>nul`) do (
        if exist "%SystemDrive%\Users\%%a\OneDrive\desktop.ini" set "OneDriveInstalled=1"
    )
)

if !OneDriveInstalled! equ 0 (
    cls
    echo ============================================
    echo ERROR: OneDrive is not installed!
    echo ============================================
    echo.
    echo OneDrive was not found on your system.
    echo.
    pause
    exit /b 1
)

:: ============================================
:: Check for OneDrive files and prompt user
:: ============================================
set "OneDriveFilesFound=0"
set "UsersWithOneDrive="

echo Checking for OneDrive files...
echo.
for /f "usebackq delims=" %%a in (`dir /b /a:d "%SystemDrive%\Users" 2^>nul`) do (
    if exist "%SystemDrive%\Users\%%a\OneDrive" (
        dir "%SystemDrive%\Users\%%a\OneDrive" /b 2>nul | findstr "." >nul
        if !errorlevel! equ 0 (
            set "OneDriveFilesFound=1"
            set "UsersWithOneDrive=!UsersWithOneDrive!%%a "
            echo Found OneDrive files in user: %%a
        )
    )
)

cls
if !OneDriveFilesFound! equ 1 (
    echo ============================================
    echo WARNING: OneDrive files found on your system!
    echo ============================================
    echo.
    echo Users with OneDrive files: !UsersWithOneDrive!
    echo.
    echo Debloating OneDrive will remove access to your synced folders
    echo Desktop, Documents, Pictures, etc. from File Explorer.
    echo.
    echo You can still access your files at: https://onedrive.live.com/
    echo.
    set "response="
    set /p "response=Do you want to continue? (Y/N): "
    
    if /i not "!response!"=="Y" (
        echo Operation cancelled by user.
        pause
        exit /b 0
    )
    echo.
    echo Continuing with OneDrive debloating...
    echo.
)

:: ============================================
:: Kill OneDrive processes
:: ============================================
echo Stopping OneDrive processes...
taskkill /f /im OneDrive.exe >nul 2>&1
timeout /t 2 /nobreak >nul

:: ============================================
:: Remove OneDrive from startup (CRITICAL)
:: ============================================
echo Removing OneDrive from startup...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f >nul 2>&1

:: Remove from all user registry hives
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" 2^>nul ^| findstr "S-1-5-21-"') do (
    reg delete "HKU\%%a\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f >nul 2>&1
    reg delete "HKU\%%a\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f >nul 2>&1
)

:: ============================================
:: Kill Explorer before making changes
:: ============================================
echo Stopping Explorer to prevent file locks...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 2 /nobreak >nul

:: ============================================
:: Uninstall OneDrive (FIXED)
:: ============================================
echo Uninstalling OneDrive...

:: 1. Try Local AppData Uninstaller (Modern/Per-User Install)
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\Update\OneDriveSetup.exe" (
    "%LOCALAPPDATA%\Microsoft\OneDrive\Update\OneDriveSetup.exe" /uninstall >nul 2>&1
    echo Attempted uninstall via AppData.
)

:: 2. Try System32 Uninstaller (Legacy/System-Wide)
if exist "%windir%\System32\OneDriveSetup.exe" (
    "%windir%\System32\OneDriveSetup.exe" /uninstall >nul 2>&1
)
if exist "%windir%\SysWOW64\OneDriveSetup.exe" (
    "%windir%\SysWOW64\OneDriveSetup.exe" /uninstall >nul 2>&1
)

timeout /t 3 /nobreak >nul

:: 3. Force Remove "Programs and Features" Entry (Registry Clean)
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDrive" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDrive" /f >nul 2>&1

:: ============================================
:: Disable OneDrive Policies
:: ============================================
echo Disabling OneDrive via system policies...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSync /t REG_DWORD /d 1 /f >nul 2>&1

:: ============================================
:: Remove OneDrive directories and links
:: ============================================
echo Removing OneDrive directories...

:: Remove system-wide OneDrive directories
if exist "%ProgramData%\Microsoft OneDrive" rmdir /q /s "%ProgramData%\Microsoft OneDrive" >nul 2>&1
if exist "%LOCALAPPDATA%\Microsoft\OneDrive" rmdir /q /s "%LOCALAPPDATA%\Microsoft\OneDrive" >nul 2>&1
if exist "%SYSTEMDRIVE%\OneDriveTemp" rmdir /q /s "%SYSTEMDRIVE%\OneDriveTemp" >nul 2>&1

:: Remove user-specific OneDrive directories
for /f "usebackq delims=" %%a in (`dir /b /a:d "%SystemDrive%\Users" 2^>nul`) do (
    if exist "%SystemDrive%\Users\%%a\AppData\Local\Microsoft\OneDrive" (
        rmdir /q /s "%SystemDrive%\Users\%%a\AppData\Local\Microsoft\OneDrive" >nul 2>&1
    )
    if exist "%SystemDrive%\Users\%%a\OneDrive" (
        rmdir /q /s "%SystemDrive%\Users\%%a\OneDrive" >nul 2>&1
    )
    
    :: Remove Shortcuts
    del /q /f "%SystemDrive%\Users\%%a\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" >nul 2>&1
    del /q /f "%SystemDrive%\Users\%%a\Links\OneDrive.lnk" >nul 2>&1
)

:: ============================================
:: Remove Registry Entries & Scheduled Tasks
:: ============================================
echo Cleaning registry and tasks...

:: Remove SyncRootManager entries
for /f "usebackq delims=" %%a in (`reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager" 2^>nul ^| findstr /i /c:"OneDrive"`) do (
    reg delete "%%a" /f >nul 2>&1
)

:: Remove scheduled tasks
schtasks /Change /TN "\OneDrive Reporting Task-*" /Disable >nul 2>&1
schtasks /Change /TN "\OneDrive Standalone Update Task-*" /Disable >nul 2>&1
schtasks /Change /TN "\OneDrive Per-Machine Standalone Update" /Disable >nul 2>&1

for /f "tokens=2 delims=\" %%a in ('schtasks /query /fo list /v 2^>nul ^| findstr /c:"\OneDrive"') do (
    schtasks /delete /tn "%%a" /f >nul 2>&1
)

:: ============================================
:: Process user registry hives (For other users)
:: ============================================
echo Processing user registry settings...
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" 2^>nul ^| findstr "S-1-5-21-"') do (
    call :CleanUserRegistry "%%a"
)

:: ============================================
:: FORCE REMOVE EXPLORER SIDEBAR (CURRENT USER)
:: ============================================
echo Removing OneDrive from Explorer Sidebar (Current User)...

:: 1. Remove the NameSpace key (The folder itself)
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1

:: 2. Remove the Class ID entirely from the user's registry (The icon definition)
reg delete "HKCU\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1

:: 3. 64-bit specific removal
reg delete "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1

:: ============================================
:: Restore default shell folders
:: ============================================
echo Restoring default shell folder locations...
set "BASE=%USERPROFILE%"

:: Create physical folders
if not exist "%BASE%\Desktop" mkdir "%BASE%\Desktop" 2>nul
if not exist "%BASE%\Documents" mkdir "%BASE%\Documents" 2>nul
if not exist "%BASE%\Pictures" mkdir "%BASE%\Pictures" 2>nul
if not exist "%BASE%\Music" mkdir "%BASE%\Music" 2>nul
if not exist "%BASE%\Videos" mkdir "%BASE%\Videos" 2>nul
if not exist "%BASE%\Favorites" mkdir "%BASE%\Favorites" 2>nul
if not exist "%BASE%\Downloads" mkdir "%BASE%\Downloads" 2>nul

:: Update Registry Keys (Shell Folders)
set "KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

reg add "%KEY%" /v "Desktop" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Desktop" /f >nul 2>&1
reg add "%KEY%" /v "Favorites" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Favorites" /f >nul 2>&1
reg add "%KEY%" /v "My Music"  /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Music" /f >nul 2>&1
reg add "%KEY%" /v "My Video"  /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Videos" /f >nul 2>&1
reg add "%KEY%" /v "Personal" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Documents" /f >nul 2>&1
reg add "%KEY%" /v "{F42EE2D3-909F-4907-8871-4C22FC0BF756}" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Documents" /f >nul 2>&1
reg add "%KEY%" /v "My Pictures" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Pictures" /f >nul 2>&1
reg add "%KEY%" /v "{0DDD015D-B06C-45D5-8C4C-F59713854639}" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Pictures" /f >nul 2>&1
reg add "%KEY%" /v "{374DE290-123F-4565-9164-39C4925E467B}" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Downloads" /f >nul 2>&1

:: Set attributes
attrib +r "%BASE%\Desktop" >nul 2>&1
attrib +r "%BASE%\Documents" >nul 2>&1
attrib +r "%BASE%\Pictures" >nul 2>&1

timeout /t 2 /nobreak >nul

:: Restart Explorer
echo Restarting Explorer...
start explorer.exe
timeout /t 3 /nobreak >nul

:: ============================================
:: Final message
:: ============================================
echo.
echo ============================================
echo OneDrive debloating completed successfully!
echo ============================================
echo.
echo Please restart your computer to ensure all changes take effect.
echo.
pause
exit /b 0

:: ============================================
:: Subroutine: CleanUserRegistry
:: ============================================
:CleanUserRegistry
setlocal
set "sid=%~1"
if "%sid%"=="" (
    endlocal
    exit /b
)

:: Attempt to remove OneDrive from other users' hives
reg delete "HKU\%sid%\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1
reg delete "HKU\%sid%\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f >nul 2>&1
reg delete "HKU\%sid%\Environment" /v "OneDrive" /f >nul 2>&1
reg delete "HKU\%sid%\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f >nul 2>&1

endlocal
exit /b