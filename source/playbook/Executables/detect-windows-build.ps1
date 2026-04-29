# ==========================================
# Windows Optimization Script (Win10/Win11/Server)
# ==========================================

# 1. Admin Privilege Check
						 
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please right-click and 'Run as Administrator'."
    Break
}

# 2. Helper Function: Set-RegistryBatch
									
function Set-RegistryBatch {
    param (
        [string]$Path,
        [hashtable]$Properties,
        [string]$Hive = "HKCU"
    )
    
    $fullPath = "$Hive`:$Path"
    
						 
    if (!(Test-Path $fullPath)) {
        New-Item -Path $fullPath -Force | Out-Null
    }

    foreach ($name in $Properties.Keys) {
        $data = $Properties[$name]
        $value = $data
        $type = "DWord"

					
									  
        if ($data -is [Array] -and $data.Count -eq 2 -and $data[1] -in @("String","DWord","Binary","ExpandString","MultiString","QWord")) {
            $value = $data[0]
            $type = $data[1]
        } 
								   
        elseif ($data -is [byte[]]) {
            $type = "Binary"
        }
        elseif ($data -is [String]) {
            $type = "String"
        }

	  
        Set-ItemProperty -Path $fullPath -Name $name -Value $value -Type $type -Force | Out-Null
    }
}

# 3. Detect Windows Build & Server Status
				
$currentBuild = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
$isWin11 = $currentBuild -gt 22000

# Server Detection
$isServer = $false
$serverCheckValues = @("CompositionEditionID", "EditionID", "InstallationType", "ProductName", "SoftwareType", "System")
$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

foreach ($value in $serverCheckValues) {
    try {
        $regValue = Get-ItemPropertyValue -Path $regPath -Name $value -ErrorAction SilentlyContinue
        if ($regValue -and $regValue.ToString().ToLower().Contains("server")) {
            $isServer = $true
            Write-Host "Detected Windows Server ($value = $regValue)" -ForegroundColor Yellow
            break
        }
    } catch {
        # Value doesn't exist, continue checking
        continue
    }
}

# 4. Server-Specific Optimizations
if ($isServer) {
    Write-Host "Applying Windows Server optimizations..." -ForegroundColor Green
    
    # Suppress Initial Configuration Tasks at logon
    Set-RegistryBatch -Hive "HKLM" -Path "\Software\Policies\Microsoft\Windows\Server\InitialConfigurationTasks" -Properties @{
        "DoNotOpenAtLogon" = 1
    }
    Write-Host "  - Disabled Initial Configuration Tasks at logon" -ForegroundColor Gray
    
    # Disable Server Manager scheduled task
    try {
        Disable-ScheduledTask -TaskName "ServerManager" -TaskPath "\Microsoft\Windows\Server Manager\" -ErrorAction Stop
        Write-Host "  - Disabled Server Manager scheduled task" -ForegroundColor Gray
    } catch {
        Write-Warning "  Could not disable Server Manager task: $_"
    }
    
    # Disable MSDTC service
    try {
        $trkService = Get-Service -Name "MSDTC" -ErrorAction SilentlyContinue
        if ($trkService) {
            if ($trkService.Status -eq "Running") {
                Stop-Service -Name "MSDTC" -Force -ErrorAction SilentlyContinue
            }
            Set-Service -Name "MSDTC" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  - Disabled MSDTC service" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "  Could not disable MSDTC service: $_"
    }
    
    # Uninstall Azure Arc Setup
    $azureArcPath = "C:\Windows\AzureArcSetup\Systray"
    if (Test-Path $azureArcPath) {
        try {
            # Look for uninstaller
            $uninstaller = Get-ChildItem -Path $azureArcPath -Filter "*.exe" -Recurse | 
                          Where-Object { $_.Name -match "uninstall|remove" -or $_.FullName -match "uninstall" } |
                          Select-Object -First 1
            
            if ($uninstaller) {
                Write-Host "  - Found Azure Arc uninstaller: $($uninstaller.FullName)" -ForegroundColor Gray
                Start-Process -FilePath $uninstaller.FullName -ArgumentList "/quiet /norestart" -Wait -NoNewWindow
                Write-Host "  - Azure Arc uninstallation initiated" -ForegroundColor Gray
            }
            
            # Remove AzureArcSetup from HKLM Run registry
            $runRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            if (Test-Path $runRegPath) {
                $azureRunValue = Get-ItemProperty -Path $runRegPath -Name "AzureArcSetup" -ErrorAction SilentlyContinue
                if ($azureRunValue) {
                    Remove-ItemProperty -Path $runRegPath -Name "AzureArcSetup" -Force -ErrorAction SilentlyContinue
                    Write-Host "  - Removed AzureArcSetup from HKLM Run registry" -ForegroundColor Gray
                }
            }
            
            # Remove directory after uninstallation attempt
            Start-Sleep -Seconds 2
            Remove-Item -Path $azureArcPath -Recurse -Force -ErrorAction SilentlyContinue
            
            # Also check for scheduled task
            $azureArcTask = Get-ScheduledTask -TaskName "*Azure*Arc*" -ErrorAction SilentlyContinue
            if ($azureArcTask) {
                Unregister-ScheduledTask -TaskName $azureArcTask.TaskName -Confirm:$false -ErrorAction SilentlyContinue
            }
            
            Write-Host "  - Removed Azure Arc Setup components" -ForegroundColor Gray
        } catch {
            Write-Warning "  Could not fully remove Azure Arc Setup: $_"
        }
    } else {
        Write-Host "  - Azure Arc Setup not found at $azureArcPath" -ForegroundColor Gray
        
        # Still try to remove the registry entry even if directory doesn't exist
        try {
            $runRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            if (Test-Path $runRegPath) {
                $azureRunValue = Get-ItemProperty -Path $runRegPath -Name "AzureArcSetup" -ErrorAction SilentlyContinue
                if ($azureRunValue) {
                    Remove-ItemProperty -Path $runRegPath -Name "AzureArcSetup" -Force -ErrorAction SilentlyContinue
                    Write-Host "  - Removed AzureArcSetup from HKLM Run registry" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Warning "  Could not remove AzureArcSetup registry entry: $_"
        }
    }
    
    Write-Host "Windows Server optimizations completed." -ForegroundColor Green
    Write-Host ""
}

# ==========================================
# SHARED SETTINGS (Applied to both OS)
# ==========================================
Write-Host "Applying common Windows settings..." -ForegroundColor Cyan

# Desktop & Window Metrics
Set-RegistryBatch -Path "\Control Panel\Desktop" -Properties @{
    "DragFullWindows"     = @("0", "String")
    "UserPreferencesMask" = @([byte[]](0x90, 0x12, 0x03, 0x80, 0x12, 0x00, 0x00, 0x00), "Binary")
}

Set-RegistryBatch -Path "\Control Panel\Desktop\WindowMetrics" -Properties @{
    "MinAnimate" = @("0", "String")
}

# Explorer Advanced Settings
Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Properties @{
    "ListviewAlphaSelect" = 0
    "ListviewShadow"      = 0
    "TaskbarAnimations"   = 0
}

# Explorer Visual Effects (3 = Custom)
Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Properties @{
    "VisualFXSetting" = 3
}

# Personalization (Dark Mode preference foundations)
Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Properties @{
    "SystemUsesLightTheme" = 0
    "AppsUseLightTheme"    = 0
}

# Desktop Window Manager
Set-RegistryBatch -Path "\Software\Microsoft\Windows\DWM" -Properties @{
    "EnableAeroPeek" = 0
}

# Workspace / Pen
Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\PenWorkspace" -Properties @{
    "PenWorkspaceButtonDesiredVisibility" = 0
}

# ==========================================
# VERSION SPECIFIC SETTINGS
# ==========================================
if ($isWin11) {
    Write-Host "Applying Windows 11 specific settings..." -ForegroundColor Cyan

    # Restore Classic Context Menu (CLSID Overrides)
						 
    Set-RegistryBatch -Path "\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Properties @{ "(Default)" = @("", "String") }
    Set-RegistryBatch -Path "\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Properties @{ "(Default)" = @("", "String") }

    # GPU Scheduling & DirectX
    Set-RegistryBatch -Path "\Software\Microsoft\DirectX\UserGpuPreferences" -Properties @{
        "DirectXUserGlobalSettings" = @("SwapEffectUpgradeEnable=1;", "String")
    }
    Set-RegistryBatch -Hive "HKLM" -Path "\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Properties @{
        "HwSchMode" = 1
    }

    # Taskbar Alignment (0 = Left) & Widgets
    Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Properties @{
        "TaskbarAl"          = 0
        "ShowTaskViewButton" = 0
    }

    # Search Box (Icon Only)
    Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Search" -Properties @{
        "SearchboxTaskbarMode" = 1
    }

    # Additional Win11 Visuals
    Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Properties @{ "EnableTransparency" = 0 }
    Set-RegistryBatch -Path "\Software\Microsoft\Windows\DWM" -Properties @{ "AlwaysHibernateThumbnails" = 0 }

    # Enable Taskbar End Task (Build 22631+)
    if ($currentBuild -ge 22631) {
        Write-Host "Enabling Taskbar End Task feature (Build $currentBuild)..." -ForegroundColor Yellow
        Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" -Properties @{
            "TaskbarEndTask" = 1
        }
        Write-Host "  - Taskbar End Task enabled (right-click taskbar icons to end tasks)" -ForegroundColor Gray
    }

    # Clean Start Menu Experience (Requires Process Stop)
    if (-not $isServer) {  # Skip on server as these components may not exist
        Write-Host "Resetting Start Menu layout..." -ForegroundColor Yellow
        Stop-Process -Name "StartMenuExperienceHost" -Force -ErrorAction SilentlyContinue
        
        # Remove CloudStore Cache
        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Remove LocalState bins
        $localState = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
        Remove-Item -Path "$localState\start.bin" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$localState\start2.bin" -Force -ErrorAction SilentlyContinue
    }

    # Restart Explorer safely to apply Taskbar/Start Menu changes
    if (-not $isServer) {  # Optional: skip on server if not needed
        Write-Host "Restarting Windows Explorer..." -ForegroundColor Yellow
        try {
            Stop-Process -Name "explorer" -Force -ErrorAction Stop
        } catch {
            # Ignore if explorer wasn't running
        } finally {
			   
            Start-Sleep -Seconds 1
            if (!(Get-Process explorer -ErrorAction SilentlyContinue)) {
                Start-Process explorer
            }
        }
    }

} else {
    Write-Host "Applying Windows 10 specific settings..." -ForegroundColor Cyan

    # Tablet Mode & People Band
    Set-RegistryBatch -Path "\SOFTWARE\Microsoft\TabletTip\1.7" -Properties @{ "TipbandDesiredVisibility" = 0 }
    Set-RegistryBatch -Path "\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Properties @{ "PeopleBand" = 0 }

    # Hide "Meet Now" (User & Machine Policy)
    Set-RegistryBatch -Path "\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Properties @{ "HideSCAMeetNow" = 1 }
    Set-RegistryBatch -Hive "HKLM" -Path "\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Properties @{ "HideSCAMeetNow" = 1 }
}

Write-Host "Script completed successfully." -ForegroundColor Green