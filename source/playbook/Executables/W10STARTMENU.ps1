<#
.SYNOPSIS
    Forcefully clears Windows 10 Start Menu by wiping the CloudStore Registry.
#>

$currentBuild = [System.Environment]::OSVersion.Version.Build

Write-Host "Detected Windows Build: $currentBuild" -ForegroundColor Gray

if ($currentBuild -gt 20000) {
    Write-Host "Windows 11 detected. This script is designed for Windows 10 only." -ForegroundColor Yellow
    Write-Host "Aborting script to prevent compatibility issues." -ForegroundColor Red
    exit
}

Write-Host "--- Windows 10 Start Menu Cleaner ---" -ForegroundColor Cyan
Write-Host "Killing Explorer..."
Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# Enforce the Blank XML Template
# We must put a blank template in place so when Windows rebuilds the menu, it rebuilds it EMPTY
# instead of restoring default ads/bloatware.
Write-Host "Setting blank template..."
$blankLayoutXml = @"
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6">
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
</LayoutModificationTemplate>
"@

$shellPath = "$env:LOCALAPPDATA\Microsoft\Windows\Shell"
if (-not (Test-Path $shellPath)) { New-Item -Path $shellPath -ItemType Directory -Force | Out-Null }
$blankLayoutXml | Out-File -FilePath "$shellPath\LayoutModification.xml" -Encoding UTF8 -Force

# Nuke the Registry CloudStore
# We delete the specific Registry keys holding the current layout.
Write-Host "Wiping Registry Pin Cache..."

$cloudStorePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"

# We use a wildcard to find the keys because the ID strings ($start.tilegrid$...) can vary slightly
if (Test-Path $cloudStorePath) {
    Get-ChildItem -Path $cloudStorePath | Where-Object { 
        $_.Name -like "*start.tilegrid`$windows.data.primarytilecollection*" -or 
        $_.Name -like "*start.tilegrid`$windows.data.curatedtilecollection*" 
    } | ForEach-Object {
        Write-Host "Removing Key: $($_.PSChildName)" -ForegroundColor DarkGray
        Remove-Item -Path $_.PSPath -Recurse -Force
    }
}

Write-Host "Deleting binary database..."
Get-ChildItem -Path "$shellPath\*.bin" -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "Restarting Explorer..."
Start-Process "explorer.exe"

Write-Host "--- SUCCESS ---" -ForegroundColor Green
Write-Host "Start Menu has been forced to reload from the blank template."