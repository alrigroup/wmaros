@echo off
setlocal

:: Define Variables
set "KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
set "BASE=%USERPROFILE%"

:: 1. Kill Explorer to unlock files/registry
taskkill /f /im explorer.exe >nul 2>&1

:: 2. Re-create missing physical folders
:: If these don't exist, Windows will throw the "Location not available" error.
if not exist "%BASE%\Desktop" mkdir "%BASE%\Desktop"
if not exist "%BASE%\Documents" mkdir "%BASE%\Documents"
if not exist "%BASE%\Pictures" mkdir "%BASE%\Pictures"
if not exist "%BASE%\Music" mkdir "%BASE%\Music"
if not exist "%BASE%\Videos" mkdir "%BASE%\Videos"
if not exist "%BASE%\Favorites" mkdir "%BASE%\Favorites"
if not exist "%BASE%\Downloads" mkdir "%BASE%\Downloads"
if not exist "%BASE%\Pictures\Screenshots" mkdir "%BASE%\Pictures\Screenshots"

:: 3. Restore Registry Keys (Shell Folders)
:: Desktop
reg add "%KEY%" /v "Desktop" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Desktop" /f

:: Favorites, Music, Video
reg add "%KEY%" /v "Favorites" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Favorites" /f
reg add "%KEY%" /v "My Music"  /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Music" /f
reg add "%KEY%" /v "My Video"  /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Videos" /f

:: Documents (Legacy + GUID)
reg add "%KEY%" /v "Personal" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Documents" /f
reg add "%KEY%" /v "{F42EE2D3-909F-4907-8871-4C22FC0BF756}" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Documents" /f

:: Pictures (Legacy + GUID)
reg add "%KEY%" /v "My Pictures" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Pictures" /f
reg add "%KEY%" /v "{0DDD015D-B06C-45D5-8C4C-F59713854639}" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Pictures" /f

:: Downloads (GUID)
reg add "%KEY%" /v "{374DE290-123F-4565-9164-39C4925E467B}" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Downloads" /f

:: Screenshots (GUID)
reg add "%KEY%" /v "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\Pictures\Screenshots" /f

:: 4. Restart Explorer
start explorer.exe
endlocal