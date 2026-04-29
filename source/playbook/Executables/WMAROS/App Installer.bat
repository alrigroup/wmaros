<# :
@echo off & setlocal
fltmc >nul 2>&1 || (powershell start -verb runas '%~0' & exit /b)
powershell -noprofile -ep bypass -command "iex (${%~f0} | out-string)"
goto :eof
#>

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Configuration ---
$Apps = @(
    @{ N="7 zip"; C="7zip.install" }
    @{ N="DirectX"; C="directx" }; @{ N="Microsoft Visual Runtimes"; C="vcredist-all" }
    @{ N="Google Chrome"; C="googlechrome" }; @{ N="Mozilla Firefox"; C="firefox" }
    @{ N="Brave"; C="brave" }; @{ N="Opera"; C="opera" }; @{ N="Opera GX"; C="opera-gx" }
    @{ N="Chromium"; C="chromium" }; @{ N="Zen Browser"; C="zen-browser" }
    @{ N="Librewolf"; C="librewolf" }; @{ N="Microsoft Edge"; C="microsoft-edge" }
    @{ N="Steam"; C="steam" }; @{ N="Epic Games"; C="epicgameslauncher" }
    @{ N="EA App"; C="ea-app" }; @{ N="Ubisoft Connect"; C="ubisoft-connect" }
    @{ N="OBS Studio"; C="obs-studio.install" }; @{ N="qBittorrent"; C="qbittorrent" }
    @{ N="RustDesk"; C="rustdesk" }; @{ N="AnyDesk"; C="anydesk.portable" }
    @{ N="TeamViewer"; C="teamviewer" }; @{ N="Python"; C="python" }; @{ N="Cloudflare WARP"; C="warp" }
    @{ N="VLC"; C="vlc" }; @{ N="Spotify"; C="spotify" }
    @{ N="HWiNFO"; C="hwinfo.portable" }; @{ N="CPU-Z"; C="cpu-z.portable" }
    @{ N="GPU-Z"; C="gpu-z" }; @{ N="OCCT"; C="occt" }
    @{ N="Notepad++"; C="notepadplusplus.install" }; @{ N="AMD Chipset"; C="amd-ryzen-chipset" }
    @{ N="AMD Ryzen Master"; C="amd-ryzen-master" }; @{ N="Bulk Crap Uninstaller"; C="bulk-crap-uninstaller" }
    @{ N="Malwarebytes"; C="malwarebytes" }; @{ N="ShareX"; C="sharex" }
    @{ N="Google Drive"; C="googledrive" }; @{ N="DevManView"; C="devmanview" }
    @{ N="Autoruns"; C="autoruns" }; @{ N="Serviwin"; C="serviwin" }
)
$Global:SelectionState = [System.Collections.Generic.HashSet[string]]::new()
$Global:InstalledApps = @{}

# --- Choco Check ---
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    $r = [System.Windows.Forms.MessageBox]::Show("Chocolatey missing. Install now?", "Setup", "YesNo", "Question")
    if ($r -ne 'Yes') { exit }
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# --- Get Installed ---
$RefreshInstalled = {
    $Global:InstalledApps.Clear()
    $chocoList = choco list --local-only --limit-output
    foreach ($line in $chocoList) {
        $pkg = ($line -split '\|')[0]
        $InstalledApps[$pkg] = $true
    }
}
&$RefreshInstalled

# --- GUI Setup ---
$Form = New-Object System.Windows.Forms.Form -Property @{
    Text = "WMAROS Installer"; Size = "340,390"; StartPosition = "CenterScreen"
    MaximizeBox = $false; FormBorderStyle = "FixedDialog"; Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
}

$TxtSearch = New-Object System.Windows.Forms.TextBox -Property @{
    Location = "12,12"; Size = "300,23"; Text = "Search..."; ForeColor = "Gray"
}

$List = New-Object System.Windows.Forms.CheckedListBox -Property @{
    Location = "12,45"; Size = "300,230"; CheckOnClick = $true
}

$BtnInstall = New-Object System.Windows.Forms.Button -Property @{
    Location = "12,285"; Size = "145,30"; Text = "Install"; BackColor = "LightGreen"
}

$BtnUninstall = New-Object System.Windows.Forms.Button -Property @{
    Location = "167,285"; Size = "145,30"; Text = "Uninstall"; BackColor = "LightCoral"
}

$LblStatus = New-Object System.Windows.Forms.Label -Property @{
    Location = "12,320"; Size = "300,20"; Text = ""; ForeColor = "DarkBlue"
}

$Form.Controls.AddRange(@($TxtSearch, $List, $BtnInstall, $BtnUninstall, $LblStatus))

# --- Logic ---
$List.Add_ItemCheck({
    param($s, $e)
    $name = $s.Items[$e.Index] -replace ' - Installed$', ''
    if ($e.NewValue -eq 'Checked') { [void]$SelectionState.Add($name) } else { [void]$SelectionState.Remove($name) }
})

$UpdateList = {
    $filter = if ($TxtSearch.Text -eq "Search...") { "" } else { $TxtSearch.Text.ToLower() }
    $List.BeginUpdate()
    $List.Items.Clear()
    foreach ($app in $Apps) {
        if ($app.N.ToLower().Contains($filter)) {
            $installed = $InstalledApps.ContainsKey($app.C)
            $displayName = if ($installed) { "$($app.N) - Installed" } else { $app.N }
            $idx = $List.Items.Add($displayName)
            if ($SelectionState.Contains($app.N)) { $List.SetItemChecked($idx, $true) }
        }
    }
    $List.EndUpdate()
}

$TxtSearch.Add_GotFocus({ if ($this.Text -eq "Search...") { $this.Text=""; $this.ForeColor="Black" } })
$TxtSearch.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text="Search..."; $this.ForeColor="Gray" } })
$TxtSearch.Add_TextChanged($UpdateList)

$BtnInstall.Add_Click({
    if ($SelectionState.Count -eq 0) { return }
    $Form.Enabled = $false; $Form.Cursor = "WaitCursor"
    
    $jobs = @()
    $toInstall = @($SelectionState | ?{
        $n = $_; $app = $Apps | ?{$_.N -eq $n}
        -not $InstalledApps.ContainsKey($app.C)
    })
    
    if ($toInstall.Count -eq 0) {
        $LblStatus.Text = ""; $Form.Enabled = $true; $Form.Cursor = "Default"
        [System.Windows.Forms.MessageBox]::Show($Form, "All selected apps already installed.", "Info")
        return
    }
    
    foreach ($name in $toInstall) {
        $app = $Apps | ?{$_.N -eq $name}
        $jobs += Start-Job -ScriptBlock {
            param($cmd)
            choco install $cmd -y --ignore-checksums
        } -ArgumentList $app.C
    }
    
    while ($jobs | ?{$_.State -eq 'Running'}) {
        $completed = ($jobs | ?{$_.State -ne 'Running'}).Count
        $LblStatus.Text = "Installing... ($completed/$($jobs.Count) done)"
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 500
    }
    
    $jobs | Remove-Job -Force
    
    $LblStatus.Text = "Refreshing list..."
    [System.Windows.Forms.Application]::DoEvents()
    &$RefreshInstalled
    
    $LblStatus.Text = ""; $Form.Enabled = $true; $Form.Cursor = "Default"
    &$UpdateList
    $Form.Refresh()
    [System.Windows.Forms.MessageBox]::Show($Form, "Installation Complete.", "Done")
})

$BtnUninstall.Add_Click({
    if ($SelectionState.Count -eq 0) { return }
    
    $toUninstall = @($SelectionState | ?{
        $n = $_; $app = $Apps | ?{$_.N -eq $n}
        $app.C -ne "directx" -and $app.C -ne "vcredist-all" -and $InstalledApps.ContainsKey($app.C)
    })
    
    if ($toUninstall.Count -eq 0) { 
        [System.Windows.Forms.MessageBox]::Show($Form, "No installed apps selected for removal.", "Info")
        return 
    }
    
    $r = [System.Windows.Forms.MessageBox]::Show($Form, "Uninstall $($toUninstall.Count) app(s)?", "Confirm", "YesNo", "Warning")
    if ($r -ne 'Yes') { return }
    
    $Form.Enabled = $false; $Form.Cursor = "WaitCursor"
    
    $jobs = @()
    foreach ($name in $toUninstall) {
        $app = $Apps | ?{$_.N -eq $name}
        $jobs += Start-Job -ScriptBlock {
            param($cmd)
            choco uninstall $cmd -y
        } -ArgumentList $app.C
    }
    
    while ($jobs | ?{$_.State -eq 'Running'}) {
        $completed = ($jobs | ?{$_.State -ne 'Running'}).Count
        $LblStatus.Text = "Uninstalling... ($completed/$($jobs.Count) done)"
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 500
    }
    
    $jobs | Remove-Job -Force
    
    $LblStatus.Text = "Refreshing list..."
    [System.Windows.Forms.Application]::DoEvents()
    &$RefreshInstalled
    
    $LblStatus.Text = ""; $Form.Enabled = $true; $Form.Cursor = "Default"
    &$UpdateList
    $Form.Refresh()
    [System.Windows.Forms.MessageBox]::Show($Form, "Uninstallation Complete.", "Done")
})

# --- Init ---
&$UpdateList
[void]$Form.ShowDialog()