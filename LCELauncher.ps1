Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$ProgressPreference = 'SilentlyContinue'

# --- Configuration ---
$RepoApiUrl = "https://api.github.com/repos/smartcmd/MinecraftConsoles/releases/tags/nightly"
$UrlDownload = "https://github.com/smartcmd/MinecraftConsoles/releases/download/nightly/LCEWindows64.zip"
$ExeName = "Minecraft.Client.exe"

$Destino = Join-Path $env:APPDATA "LCE"
$TempZip = "$env:TEMP\lce_update.zip"
$VersionFile = Join-Path $Destino "version.txt"
$PrefsFile = Join-Path $Destino "launcher_prefs.txt" 

# --- Theme ---
$ColorBg = [System.Drawing.Color]::FromArgb(30, 30, 30)
$ColorInput = [System.Drawing.Color]::FromArgb(45, 45, 48)
$ColorBtn = [System.Drawing.Color]::FromArgb(60, 60, 65)
$ColorLaunchBtn = [System.Drawing.Color]::FromArgb(0, 120, 215)
$ColorText = [System.Drawing.Color]::White
$ColorStatusMineGreen = [System.Drawing.Color]::FromArgb(85, 255, 85) 

# --- UI Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "LCE Launcher"
$Form.Size = New-Object System.Drawing.Size(400, 360) 
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.BackColor = $ColorBg
$Form.ForeColor = $ColorText
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

try {
    $ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $Form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($ExePath)
} catch {}

$LblUser = New-Object System.Windows.Forms.Label
$LblUser.Text = "In-Game Username:"
$LblUser.Location = New-Object System.Drawing.Point(30, 20)
$LblUser.AutoSize = $true
$Form.Controls.Add($LblUser)

$TxtUser = New-Object System.Windows.Forms.TextBox
$TxtUser.Location = New-Object System.Drawing.Point(30, 45)
$TxtUser.Size = New-Object System.Drawing.Size(320, 25)
$TxtUser.BackColor = $ColorInput
$TxtUser.ForeColor = $ColorText
$TxtUser.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($TxtUser)

$LblIP = New-Object System.Windows.Forms.Label
$LblIP.Text = "Server IP (Optional):"
$LblIP.Location = New-Object System.Drawing.Point(30, 80)
$LblIP.AutoSize = $true
$Form.Controls.Add($LblIP)

$TxtIP = New-Object System.Windows.Forms.TextBox
$TxtIP.Location = New-Object System.Drawing.Point(30, 105)
$TxtIP.Size = New-Object System.Drawing.Size(200, 25)
$TxtIP.BackColor = $ColorInput
$TxtIP.ForeColor = $ColorText
$TxtIP.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($TxtIP)

$LblPort = New-Object System.Windows.Forms.Label
$LblPort.Text = "Port:"
$LblPort.Location = New-Object System.Drawing.Point(240, 80)
$LblPort.AutoSize = $true
$Form.Controls.Add($LblPort)

$TxtPort = New-Object System.Windows.Forms.TextBox
$TxtPort.Location = New-Object System.Drawing.Point(240, 105)
$TxtPort.Size = New-Object System.Drawing.Size(110, 25)
$TxtPort.BackColor = $ColorInput
$TxtPort.ForeColor = $ColorText
$TxtPort.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Form.Controls.Add($TxtPort)

$ChkServer = New-Object System.Windows.Forms.CheckBox
$ChkServer.Text = "Run as Headless Server (-server)"
$ChkServer.Location = New-Object System.Drawing.Point(30, 140)
$ChkServer.Size = New-Object System.Drawing.Size(320, 25)
$Form.Controls.Add($ChkServer)

$BtnUpdate = New-Object System.Windows.Forms.Button
$BtnUpdate.Text = "Check for Updates"
$BtnUpdate.Location = New-Object System.Drawing.Point(30, 175)
$BtnUpdate.Size = New-Object System.Drawing.Size(320, 40)
$BtnUpdate.FlatStyle = "Flat"
$BtnUpdate.BackColor = $ColorBtn
$BtnUpdate.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
$Form.Controls.Add($BtnUpdate)

$BtnLaunch = New-Object System.Windows.Forms.Button
$BtnLaunch.Text = "Launch LCE"
$BtnLaunch.Location = New-Object System.Drawing.Point(30, 225)
$BtnLaunch.Size = New-Object System.Drawing.Size(220, 45)
$BtnLaunch.FlatStyle = "Flat"
$BtnLaunch.BackColor = $ColorLaunchBtn
$BtnLaunch.ForeColor = [System.Drawing.Color]::White
$BtnLaunch.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 100, 190)
$Form.Controls.Add($BtnLaunch)

$BtnFolder = New-Object System.Windows.Forms.Button
$BtnFolder.Text = "Game Files"
$BtnFolder.Location = New-Object System.Drawing.Point(260, 225)
$BtnFolder.Size = New-Object System.Drawing.Size(90, 45)
$BtnFolder.FlatStyle = "Flat"
$BtnFolder.BackColor = $ColorBtn
$BtnFolder.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
$Form.Controls.Add($BtnFolder)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(30, 275)
$ProgressBar.Size = New-Object System.Drawing.Size(320, 10)
$ProgressBar.Style = "Continuous"
$ProgressBar.Visible = $false
$Form.Controls.Add($ProgressBar)

$Status = New-Object System.Windows.Forms.Label
$Status.Text = "Waiting for command..." 
$Status.Location = New-Object System.Drawing.Point(30, 290)
$Status.Size = New-Object System.Drawing.Size(320, 20)
$Status.TextAlign = "MiddleCenter"
$Status.ForeColor = $ColorStatusMineGreen 
$Form.Controls.Add($Status)

# --- Core Logic ---
$Script:CheckAndUpdate = {
    $BtnUpdate.Enabled = $false
    $BtnLaunch.Enabled = $false
    $Status.Text = "Checking for new versions..."
    $Status.ForeColor = $ColorText
    $Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $ReleaseData = Invoke-RestMethod -Uri $RepoApiUrl -UseBasicParsing
        $LatestDate = $ReleaseData.assets | Where-Object { $_.name -eq "LCEWindows64.zip" } | Select-Object -ExpandProperty updated_at

        $CurrentDate = ""
        if (Test-Path $VersionFile) { $CurrentDate = Get-Content $VersionFile }

        if ($CurrentDate -eq $LatestDate -and (Test-Path (Join-Path $Destino $ExeName))) {
            $Status.Text = "You are already up to date!"
            $Status.ForeColor = $ColorStatusMineGreen
        } else {
            $AskUser = [System.Windows.Forms.MessageBox]::Show(
                "A new update was found!`n`nDo you want to download and install it now?", 
                "Update Available", 
                [System.Windows.Forms.MessageBoxButtons]::YesNo, 
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            
            if ($AskUser -eq [System.Windows.Forms.DialogResult]::Yes) {
                $Status.Text = "Connecting..."
                $Status.ForeColor = $ColorText
                $ProgressBar.Value = 0
                $ProgressBar.Visible = $true
                $ProgressBar.Style = "Continuous"
                $Form.Refresh()
                
                $Request = [System.Net.WebRequest]::Create($UrlDownload)
                $Request.UserAgent = "LCELauncher/1.0"
                $Response = $Request.GetResponse()
                $TotalBytes = $Response.ContentLength
                $ResponseStream = $Response.GetResponseStream()
                
                $FileStream = New-Object System.IO.FileStream($TempZip, [System.IO.FileMode]::Create)
                $Buffer = New-Object byte[] 65536 
                $TotalRead = 0

                do {
                    $Read = $ResponseStream.Read($Buffer, 0, $Buffer.Length)
                    if ($Read -gt 0) {
                        $FileStream.Write($Buffer, 0, $Read)
                        $TotalRead += $Read
                        if ($TotalBytes -gt 0) {
                            $Percent = [math]::Floor(($TotalRead / $TotalBytes) * 100)
                            if ($ProgressBar.Value -ne $Percent) {
                                $ProgressBar.Value = $Percent
                                $Status.Text = "Downloading update... ($Percent%)"
                                [System.Windows.Forms.Application]::DoEvents()
                            }
                        }
                    }
                } while ($Read -gt 0)

                $FileStream.Close()
                $ResponseStream.Close()
                $Response.Close()
                
                $Status.Text = "Extracting files... (0%)"
                $ProgressBar.Value = 0
                $Form.Refresh()
                [System.Windows.Forms.Application]::DoEvents()
                
                if (!(Test-Path $Destino)) { New-Item -ItemType Directory -Path $Destino | Out-Null }
                
                try {
                    $ZipArchive = [System.IO.Compression.ZipFile]::OpenRead($TempZip)
                    $Entries = $ZipArchive.Entries
                    $TotalEntries = $Entries.Count
                    $CurrentEntry = 0

                    foreach ($Entry in $Entries) {
                        $CurrentEntry++
                        
                        if ($CurrentEntry % 5 -eq 0 -or $CurrentEntry -eq $TotalEntries) {
                            $Percent = [math]::Floor(($CurrentEntry / $TotalEntries) * 100)
                            $ProgressBar.Value = $Percent
                            $Status.Text = "Extracting files... ($Percent%)"
                            [System.Windows.Forms.Application]::DoEvents()
                        }

                        $DestFilePath = [System.IO.Path]::Combine($Destino, $Entry.FullName)
                        $DestDirPath = [System.IO.Path]::GetDirectoryName($DestFilePath)

                        if (!(Test-Path $DestDirPath)) {
                            New-Item -ItemType Directory -Path $DestDirPath | Out-Null
                        }

                        if ($Entry.Name -ne "") {
                            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($Entry, $DestFilePath, $true)
                        }
                    }
                    $ZipArchive.Dispose()
                } catch {
                    Expand-Archive -Path $TempZip -DestinationPath $Destino -Force | Out-Null
                }
                
                Remove-Item $TempZip -Force
                $LatestDate | Out-File -FilePath $VersionFile -Encoding UTF8
                
                $ProgressBar.Visible = $false
                $Status.Text = "Successfully updated!"
                $Status.ForeColor = $ColorStatusMineGreen 
            } else {
                $Status.Text = "Update skipped."
                $Status.ForeColor = [System.Drawing.Color]::Gold 
            }
        }
    } catch {
        $ProgressBar.Visible = $false
        $Status.Text = "Update failed!"
        $Status.ForeColor = [System.Drawing.Color]::LightCoral 
        
        [System.Windows.Forms.MessageBox]::Show(
            "Details: " + $_.Exception.Message, 
            "Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    
    $BtnUpdate.Enabled = $true
    $BtnLaunch.Enabled = $true
}

# --- Event Triggers ---
$Form.Add_Load({
    if (!(Test-Path $Destino)) { New-Item -ItemType Directory -Path $Destino | Out-Null }
    
    if (Test-Path $PrefsFile) {
        $Prefs = Get-Content $PrefsFile
        if ($Prefs.Count -ge 1) { $TxtUser.Text = $Prefs[0] }
        if ($Prefs.Count -ge 2) { $TxtIP.Text = $Prefs[1] }
        if ($Prefs.Count -ge 3) { $TxtPort.Text = $Prefs[2] }
        if ($Prefs.Count -ge 4 -and $Prefs[3] -eq "True") { $ChkServer.Checked = $true }
    } else {
        $TxtUser.Text = "Steve"
    }
})

$Form.Add_Shown({
    $Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    Invoke-Command -ScriptBlock $Script:CheckAndUpdate
})

$BtnUpdate.Add_Click({ Invoke-Command -ScriptBlock $Script:CheckAndUpdate })

$BtnFolder.Add_Click({
    if (!(Test-Path $Destino)) { New-Item -ItemType Directory -Path $Destino | Out-Null }
    Start-Process "explorer.exe" $Destino
})

$BtnLaunch.Add_Click({
    $Path = Join-Path $Destino $ExeName
    
    if (Test-Path $Path) {
        $Prefs = @(
            $TxtUser.Text.Trim(),
            $TxtIP.Text.Trim(),
            $TxtPort.Text.Trim(),
            $ChkServer.Checked.ToString()
        )
        $Prefs | Out-File -FilePath $PrefsFile -Encoding UTF8

        $ArgsList = ""
        
        if ($ChkServer.Checked) {
            $ArgsList += "-server "
        } else {
            $UserName = $TxtUser.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($UserName)) { $UserName = "Steve" }
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
        
        $Form.Hide()
        Start-Process -FilePath $Path -ArgumentList $ArgsList -Wait
        $Form.Show()
        
        $Status.Text = "" 
        $Status.ForeColor = $ColorStatusMineGreen
        
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Minecraft.Client.exe not found! Please check for updates first.", 
            "Warning", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
})

$Form.ShowDialog() | Out-Null
