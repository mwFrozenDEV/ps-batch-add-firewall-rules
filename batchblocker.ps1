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

#Creates the name for the Rule using the traffic direction and the name of the .exe
function createRuleDisplayName {
    param (
        $direction,
        $name
    )
    return "Block $direction traffic: $name"
}

#Creates the description for the Rule using the name of the .exe, the type aswell as a time stamp.
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
    $button.BackColor = Convert-HexToColor "#4477CE" #Background Color
    $button.ForeColor = Convert-HexToColor "#F1F6F9" #Text Color
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Regular)  #Font and Size
    $button.FlatStyle = "Flat"  #Button Style
    $button.FlatAppearance.BorderSize = 0  #No Border
    $button.FlatAppearance.MouseOverBackColor = Convert-HexToColor "#8CABFF"  #Color on hover
    $button.FlatAppearance.MouseDownBackColor = Convert-HexToColor "#6D5D6E"  #Color on click
}

function Style-Text {
    param (
        [System.Windows.Forms.Label]$label
    )
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Regular) #Font and Size
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

#GUI Functions
function createButton {
    param (
        $width,
        $height,
        $textOnButton,
        [scriptblock]$onClick
    )
    $newButton = New-Object System.Windows.Forms.Button
    $newButton.Text = $textOnButton
    $newButton.Size = New-Object System.Drawing.Size($width,$height)
    $newButton.Add_Click($onClick)
    Style-Button -button $newButton   
    return $newButton  
}

function createLabel {
    param (
        $width,
        $height,
        $text
    )
    $newLabel = New-Object System.Windows.Forms.Label
    $newLabel.Text = $text
    $newLabel.Size = New-Object System.Drawing.Size($width,$height)
    $newLabel.AutoSize = $true
    Style-Text $newLabel 
    
    return $newLabel
}


#Objects
$gui = New-Object System.Windows.Forms.Form
$currentpathLabel = New-Object System.Windows.Forms.Label
$filebrowserwindow = New-Object System.Windows.Forms.FolderBrowserDialog

#GUI
$gui.Text = "Advanced firewall batch blocker - by github.com/mwFrozenDEV"
$gui.Size = New-Object System.Drawing.Size(600,400)
$gui.StartPosition = "CenterScreen"
$gui.BackColor = Convert-HexToColor "#35155D"


#Labels
$topTitle = createLabel -width 300 -height 20 -text "Batch Firewall Blocker"

$currentpathLabel = createLabel -width 20 -height 300 -text "Select a Path (Double Click to open Path in Explorer)"
$currentpathLabel.BackColor = Convert-HexToColor "#0C0C0C"
$currentpathLabel.ForeColor = Convert-HexToColor "#F1F6F9"
$currentpathLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$currentpathLabel.add_DoubleClick({OpenCurrentPath}) #DoubleClick opens Filebrowser with the current location

#Buttons
$button_SelectPath = createButton -width 150 -height 45 -textOnButton "Choose Path" -onClick { ChoosePath }
$button_Inbound = createButton -width 190 -height 80 -textOnButton "Create Inbound Rules" -onClick { addFirewallRule -direction "Inbound" }
$button_Outbound = createButton -width 190 -height 80 -textOnButton "Create Outbound Rules" -onClick { addFirewallRule -direction "Outbound" }

#Locations
$button_SelectPath.Location = New-Object System.Drawing.Point(15, 70)
$button_Inbound.Location = New-Object System.Drawing.Point(15, 210)
$button_Outbound.Location = New-Object System.Drawing.Point(250, 210)
$currentpathLabel.Location = New-Object System.Drawing.Point(15, 145)
$topTitle.Location = New-Object System.Drawing.Point(15, 10)

#Building the gui
$gui.Controls.Add($topTitle)
$gui.Controls.Add($button_SelectPath)
$gui.Controls.Add($currentPathLabel)
$gui.Controls.Add($button_Inbound)
$gui.Controls.Add($button_Outbound)

#Show the gui
$gui.Add_Shown({ $gui.Activate() })
[void] $gui.ShowDialog()


