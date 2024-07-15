Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#Checks if PS has administrative privileges, if not starts a new PS Process with administrative privileges.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $messageBoxInput = [System.Windows.Forms.MessageBox]::Show("This script requires administrator privileges.`nClick OK to restart with elevated privileges.", "Administrator Privileges Required", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Information)
    if ($messageBoxInput -eq [System.Windows.Forms.DialogResult]::OK) {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    Exit
}

#Essential Functions ----------------------------------------------------------------

#This function sets the current Path.
function SetCurrentPath {
    $currentpathLabel.Text = $filebrowserwindow.SelectedPath
}

#This function opens the filebrowser window, and invokes the SetCurrentPath function to update the display in the GUI
function ChoosePath {
    if($filebrowserwindow.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
    {
        SetCurrentPath
    }
    else 
    {
        Write-Host Error.
    }
}

#This function checks if the current Path is null or not valid, displays error if true, else opens FileBrowser with current Path
function OpenCurrentPath {
    if ([string]::IsNullOrEmpty($filebrowserwindow.SelectedPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a Path first.", "No Path selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    } else {
        if (Test-Path $filebrowserwindow.SelectedPath -PathType Container) {
            Invoke-Item $filebrowserwindow.SelectedPath
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a valid Path first.", "Path Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
}

#This function searches the directory and its subdirectorys and returns how many .exe's it has found
function searchDirectory {
    $count = 0
    Get-ChildItem -Path $filebrowserwindow.SelectedPath -Recurse -Filter *.exe |
    ForEach-Object {
        $count += 1
    }
    return $count
}

function createRuleDisplayName {
    param (
        $direction,
        $name
    )
    return "Block $direction traffic: $name"
}

function createRuleDescription {
    param (
        $nameDesc,
        $type
    )
    $formattedTime = Get-Date -Format "HH:mm"
    return "Blocks $type traffic for $nameDesc Created at: $formattedTime Rule generated with XXX"
}

function addFirewallRule {
    param (
        $direction
    )
    #Checks if selectedPath is not empty
    if([string]::IsNullOrEmpty($filebrowserwindow.SelectedPath)) {
        OpenCurrentPath
    } else {
        #Checks how many rules its going to create and asks for a confirm on that change.
        $toBeAdded = searchDirectory
        $result = [System.Windows.Forms.MessageBox]::Show("WARNING! This is going to create $toBeAdded $direction Firewall Rules", "Going to add: $toBeAdded", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Write-Host "User accepted. Going to add $toBeAdded $direction Rules."
            Get-ChildItem -Path $filebrowserwindow.SelectedPath -Recurse -Filter *.exe |
            ForEach-Object {
                $rulename = createRuleDisplayName -direction $direction -name $_.Name
                $ruledesc = createRuleDescription -nameDesc $_.Name -type $direction
                New-NetFirewallRule -DisplayName $rulename `
                    -Description $ruledesc `
                    -Direction $direction `
                    -Program $_.FullName `
                    -Action Block `
                    -Profile Any `
                    -Enabled True
            }
        } else {
            Write-Host "Cancelled."
        }
    }
}


#Cosmetic Functions -----------------------------------------------------------------
function Convert-HexToColor {
    param (
        [string]$hex
    )
    $r = [Convert]::ToInt32($hex.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(5, 2), 16)
    return [System.Drawing.Color]::FromArgb($r, $g, $b)
}
function Style-Button {
    param (
        [System.Windows.Forms.Button]$button
    )
    $button.BackColor = Convert-HexToColor "#6D5D6E" #Background Color
    $button.ForeColor = Convert-HexToColor "#F4EEE0" #Text Color
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Regular)  #Font and Size
    $button.FlatStyle = "Flat"  #Button Style
    $button.FlatAppearance.BorderSize = 0  #No Border
    $button.FlatAppearance.MouseOverBackColor = Convert-HexToColor "#4F4557"  #Color on hover
    $button.FlatAppearance.MouseDownBackColor = Convert-HexToColor "#6D5D6E"  #Color on click
}

function Style-Text {
    param (
        [System.Windows.Forms.Label]$label
    )
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold) #Font and Size
    $label.ForeColor = Convert-HexToColor "#F4EEE0" #Text Color
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
}

function Calculate-Center {
    param (
        [System.Windows.Forms.Control]$control,
        [int]$yPos
    )
    $guiWidth = $gui.ClientSize.Width
    $Width = $control.Width
    $xPos = ($guiWidth - $Width) / 2
    return New-Object System.Drawing.Point($xPos, $yPos)
}

#Objects
$gui = New-Object System.Windows.Forms.Form
$topTitle = New-Object System.Windows.Forms.Label
$currentpathLabel = New-Object System.Windows.Forms.Label
$button_SelectPath = New-Object System.Windows.Forms.Button
$filebrowserwindow = New-Object System.Windows.Forms.FolderBrowserDialog
$buttonRunInbound = New-Object System.Windows.Forms.Button
$buttonRunOutbound = New-Object System.Windows.Forms.Button

#GUI
$gui.Text = "Advanced firewall batch blocker - by mwFrozen"
$gui.Size = New-Object System.Drawing.Size(800,500)
$gui.StartPosition = "CenterScreen"
$gui.BackColor = Convert-HexToColor "#393646"

#Title at the top
$topTitle.Location = New-Object System.Drawing.Point(0, 20)
$topTitle.Size = New-Object System.Drawing.Size(300,20)
$topTitle.Text = "Batch Firewall Blocker"
Style-Text $topTitle

#Button on $gui, opens FileBrowser
$button_SelectPath.Text = "Select Path"
$button_SelectPath.Size = New-Object System.Drawing.Size(150,45)
$button_SelectPath.Location = Calculate-Center -control $button_SelectPath -yPos 50
Style-Button $button_SelectPath
$button_SelectPath.Add_Click({ChoosePath})

#Path label
$currentpathLabel.Location = New-Object System.Drawing.Point(0, 120)
$currentpathLabel.Size = New-Object System.Drawing.Size(300,20)
$currentPathLabel.AutoSize = $true
$currentpathLabel.Text = "Path"
$currentpathLabel.add_DoubleClick({OpenCurrentPath}) #DoubleClick opens Filebrowser with the current location

#ButtonLoop
$buttonRunInbound.Text = "run inbound"
$buttonRunInbound.Size = New-Object System.Drawing.Size(150,45)
$buttonRunInbound.Location = Calculate-Center -control $buttonRunInbound -yPos 150
$buttonRunInbound.Add_Click({addFirewallRule -direction "Inbound"})

$buttonRunOutbound.Text = "run outbound"
$buttonRunOutbound.Size = New-Object System.Drawing.Size(150,45)
$buttonRunOutbound.Location = Calculate-Center -control $buttonRunOutbound -yPos 300
$buttonRunOutbound.Add_Click({addFirewallRule -direction "Outbound"})

#Building the gui
$gui.Controls.Add($topTitle)
$gui.Controls.Add($button_SelectPath)
$gui.Controls.Add($currentPathLabel)
$gui.Controls.Add($buttonRunInbound)
$gui.Controls.Add($buttonRunOutbound)

#Show the gui
$gui.Add_Shown({ $gui.Activate() })
[void] $gui.ShowDialog()


