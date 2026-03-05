Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ProgressPreference = 'SilentlyContinue'

# --- Settings ---
$RepoApiUrl = "https://api.github.com/repos/smartcmd/MinecraftConsoles/releases/tags/nightly"
$UrlDownload = "https://github.com/smartcmd/MinecraftConsoles/releases/download/nightly/LCEWindows64.zip"
$ExeName = "Minecraft.Client.exe"

# Target folders
$Destino = Join-Path $env:APPDATA "LCE"
$TempZip = "$env:TEMP\lce_update.zip"
$VersionFile = Join-Path $Destino "version.txt"
$PrefsFile = Join-Path $Destino "launcher_prefs.txt" 

# --- Interface Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "LCE (Legacy Console Edition) Launcher"
$Form.Size = New-Object System.Drawing.Size(400, 360)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.BackColor = [System.Drawing.Color]::White
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# 1. Username Section (Moved to Top)
$LblUser = New-Object System.Windows.Forms.Label
$LblUser.Text = "In-Game Username:"
$LblUser.Location = New-Object System.Drawing.Point(30, 20)
$LblUser.AutoSize = $true
$Form.Controls.Add($LblUser)

$TxtUser = New-Object System.Windows.Forms.TextBox
$TxtUser.Location = New-Object System.Drawing.Point(30, 45)
$TxtUser.Size = New-Object System.Drawing.Size(320, 25)
$Form.Controls.Add($TxtUser)

# 2. Connection Section (IP & Port)
$LblIP = New-Object System.Windows.Forms.Label
$LblIP.Text = "Server IP (Optional):"
$LblIP.Location = New-Object System.Drawing.Point(30, 80)
$LblIP.AutoSize = $true
$Form.Controls.Add($LblIP)

$TxtIP = New-Object System.Windows.Forms.TextBox
$TxtIP.Location = New-Object System.Drawing.Point(30, 105)
$TxtIP.Size = New-Object System.Drawing.Size(200, 25)
$Form.Controls.Add($TxtIP)

$LblPort = New-Object System.Windows.Forms.Label
$LblPort.Text = "Port:"
$LblPort.Location = New-Object System.Drawing.Point(240, 80)
$LblPort.AutoSize = $true
$Form.Controls.Add($LblPort)

$TxtPort = New-Object System.Windows.Forms.TextBox
$TxtPort.Location = New-Object System.Drawing.Point(240, 105)
$TxtPort.Size = New-Object System.Drawing.Size(110, 25)
$Form.Controls.Add($TxtPort)

# 3. Server Mode Toggle
$ChkServer = New-Object System.Windows.Forms.CheckBox
$ChkServer.Text = "Run as Headless Server (-server)"
$ChkServer.Location = New-Object System.Drawing.Point(30, 140)
$ChkServer.Size = New-Object System.Drawing.Size(320, 25)
$Form.Controls.Add($ChkServer)

# 4. Update Button (Moved Below Server Mode)
$BtnUpdate = New-Object System.Windows.Forms.Button
$BtnUpdate.Text = "Check for Updates"
$BtnUpdate.Location = New-Object System.Drawing.Point(30, 175)
$BtnUpdate.Size = New-Object System.Drawing.Size(320, 40)
$BtnUpdate.FlatStyle = "Flat"
$Form.Controls.Add($BtnUpdate)

# 5. Status and Launch Section
$Status = New-Object System.Windows.Forms.Label
$Status.Text = "Ready."
$Status.Location = New-Object System.Drawing.Point(30, 225)
$Status.Size = New-Object System.Drawing.Size(320, 20)
$Status.TextAlign = "MiddleCenter"
$Form.Controls.Add($Status)

$BtnLaunch = New-Object System.Windows.Forms.Button
$BtnLaunch.Text = "Launch LCE"
$BtnLaunch.Location = New-Object System.Drawing.Point(30, 255)
$BtnLaunch.Size = New-Object System.Drawing.Size(320, 45)
$BtnLaunch.FlatStyle = "Flat"
$BtnLaunch.BackColor = [System.Drawing.Color]::LightGray
$Form.Controls.Add($BtnLaunch)

# --- Logic block for Checking Updates ---
$Script:CheckAndUpdate = {
    $BtnUpdate.Enabled = $false
    $BtnLaunch.Enabled = $false
    $Status.Text = "Checking for new versions..."
    $Status.ForeColor = [System.Drawing.Color]::Black
    $Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $ReleaseData = Invoke-RestMethod -Uri $RepoApiUrl -UseBasicParsing
        $LatestDate = $ReleaseData.assets | Where-Object { $_.name -eq "LCEWindows64.zip" } | Select-Object -ExpandProperty updated_at

        $CurrentDate = ""
        if (Test-Path $VersionFile) { $CurrentDate = Get-Content $VersionFile }

        if ($CurrentDate -eq $LatestDate -and (Test-Path (Join-Path $Destino $ExeName))) {
            $Status.Text = "You are already up to date!"
            $Status.ForeColor = [System.Drawing.Color]::DarkBlue
        } else {
            $AskUser = [System.Windows.Forms.MessageBox]::Show("A new update was found!`n`nDo you want to download and install it now?", "Update Available", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            
            if ($AskUser -eq [System.Windows.Forms.DialogResult]::Yes) {
                $Status.Text = "Downloading update..."
                $Form.Refresh()
                [System.Windows.Forms.Application]::DoEvents()

                Invoke-WebRequest -Uri $UrlDownload -OutFile $TempZip -UseBasicParsing
                
                $Status.Text = "Extracting files..."
                $Form.Refresh()
                [System.Windows.Forms.Application]::DoEvents()
                
                if (!(Test-Path $Destino)) { New-Item -ItemType Directory -Path $Destino | Out-Null }
                Expand-Archive -Path $TempZip -DestinationPath $Destino -Force
                Remove-Item $TempZip -Force
                
                $LatestDate | Out-File -FilePath $VersionFile -Encoding UTF8
                
                $Status.Text = "Successfully updated!"
                $Status.ForeColor = [System.Drawing.Color]::DarkGreen
            } else {
                $Status.Text = "Update skipped."
                $Status.ForeColor = [System.Drawing.Color]::Orange
            }
        }
    } catch {
        $Status.Text = "Error checking or downloading update."
        $Status.ForeColor = [System.Drawing.Color]::Red
    }
    
    $BtnUpdate.Enabled = $true
    $BtnLaunch.Enabled = $true
}

# --- Event Triggers ---

# Load preferences when app opens
$Form.Add_Load({
    if (!(Test-Path $Destino)) { New-Item -ItemType Directory -Path $Destino | Out-Null }
    
    if (Test-Path $PrefsFile) {
        $Prefs = Get-Content $PrefsFile
        if ($Prefs.Count -ge 1) { $TxtUser.Text = $Prefs[0] }
        if ($Prefs.Count -ge 2) { $TxtIP.Text = $Prefs[1] }
        if ($Prefs.Count -ge 3) { $TxtPort.Text = $Prefs[2] }
        if ($Prefs.Count -ge 4 -and $Prefs[3] -eq "True") { $ChkServer.Checked = $true }
    } else {
        $TxtUser.Text = "Player"
    }
})

# Run the auto-check logic after UI loads
$Form.Add_Shown({
    $Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    Invoke-Command -ScriptBlock $Script:CheckAndUpdate
})

# Manual Update Button
$BtnUpdate.Add_Click({
    Invoke-Command -ScriptBlock $Script:CheckAndUpdate
})

# Launch Button
$BtnLaunch.Add_Click({
    $Path = Join-Path $Destino $ExeName
    
    if (Test-Path $Path) {
        # 1. Save preferences locally for next time
        $Prefs = @(
            $TxtUser.Text.Trim(),
            $TxtIP.Text.Trim(),
            $TxtPort.Text.Trim(),
            $ChkServer.Checked.ToString()
        )
        $Prefs | Out-File -FilePath $PrefsFile -Encoding UTF8

        # 2. Build the Arguments String
        $ArgsList = ""
        
        if ($ChkServer.Checked) {
            $ArgsList += "-server "
        } else {
            $UserName = $TxtUser.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($UserName)) { $UserName = "Player" }
            $ArgsList += "-name `"$UserName`" "
        }

        $IP = $TxtIP.Text.Trim()
        if (![string]::IsNullOrWhiteSpace($IP)) {
            $ArgsList += "-ip `"$IP`" "
        }

        $Port = $TxtPort.Text.Trim()
        if (![string]::IsNullOrWhiteSpace($Port)) {
            $ArgsList += "-port `"$Port`" "
        }
        
        # 3. Launch the game with arguments
        $Status.Text = "Launching game..."
        $Form.Refresh()
        
        Start-Process -FilePath $Path -ArgumentList $ArgsList
        $Form.Close()
    } else {
        [System.Windows.Forms.MessageBox]::Show("Minecraft.Client.exe not found! Please check for updates first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

$Form.ShowDialog() | Out-Null
