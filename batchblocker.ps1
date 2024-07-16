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
$ErrorActionPreference = 'SilentlyContinue'
#Mutes uncritical errors. Used for the deletion as it always throws failures, because its trying to get something that doesnt exist to check if it still exists.
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
    return "Blocks $type traffic for $nameDesc Created at: $formattedTime Rule generated with a tool from github.com/mwFrozenDEV"
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
                $rulename = createRuleDisplayName -direction $direction -name $_.FullName
                $ruledesc = createRuleDescription -nameDesc $_.Name -type $direction
                New-NetFirewallRule -DisplayName $rulename `
                    -Description $ruledesc `
                    -Direction $direction `
                    -Program $_.FullName `
                    -Action Block `
                    -Profile Any `
                    -Enabled True
                Write-Host "Created Rule: $rulename"
            }
        } else {
            Write-Host "Cancelled."
        }
    }
}

function addBothFirewallRules {
    addFirewallRule -direction "Outbound"
    addFirewallRule -direction "Inbound"
}

function deleteCreatedFirewallRules {
    param (
        $direction
    )
    $result = [System.Windows.Forms.MessageBox]::Show("ATTENTION! This is going to try to delete Firewall rules based on their names. It only works with Rules that where created using this script. Press OK to continue.", "ATTENTION!", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Information)
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        #Checks if selectedPath is not empty
        if([string]::IsNullOrEmpty($filebrowserwindow.SelectedPath)) {
            OpenCurrentPath
        } else {
            $toBeDeleted = searchDirectory
            $result = [System.Windows.Forms.MessageBox]::Show("WARNING! This is going to try to DELETE $toBeDeleted $direction Firewall Rules", "Going to delete: $toBeDeleted", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Host "User accepted. Attempting to delete $toBeAdded $direction Rules."
                Get-ChildItem -Path $filebrowserwindow.SelectedPath -Recurse -Filter *.exe |
                ForEach-Object {
                    $rulename = createRuleDisplayName -direction $direction -name $_.FullName
                    if (Get-NetfirewallRule -DisplayName $rulename) {
                        Write-Host "Rule $rulename exists. Attempting to delete."
                        Remove-NetFirewallRule -DisplayName $rulename
                        if (-not (Get-NetFirewallRule -DisplayName $rulename)) {
                            Write-Host "Successfully deleted $rulename"
                        } else {
                            Write-Host "Something went wrong. Couldnt delete. Skipping."
                        }
                        
                    } else {
                        Write-Host "$rulename does not exist. Skipping."
                    }
                } 
            } else {
                Write-Host "Cancelled deletion."
            }
        } 
    } else {
        Write-Host "Cancelled deletion."
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

function Style-DelButton {
    param (
        [System.Windows.Forms.Button]$button
    )
    $button.BackColor = Convert-HexToColor "#A60103" #Background Color
    $button.ForeColor = Convert-HexToColor "#F1F6F9" #Text Color
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)
    $button.FlatStyle = "Flat"  #Button Style
    $button.FlatAppearance.BorderSize = 0  #No Border
    $button.FlatAppearance.MouseOverBackColor = Convert-HexToColor "#F50003"  #Color on hover
    $button.FlatAppearance.MouseDownBackColor = Convert-HexToColor "#750204"  #Color on click
}

function Style-Text {
    param (
        [System.Windows.Forms.Label]$label
    )
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Regular) #Font and Size
    $label.ForeColor = Convert-HexToColor "#F4EEE0" #Text Color
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
}

#GUI Functions -----------------------------------------------------------------
function createButton {
    param (
        $width,
        $height,
        $textOnButton,
        [scriptblock]$onClick,
        [bool]$normal
    )
    $newButton = New-Object System.Windows.Forms.Button
    $newButton.Text = $textOnButton
    $newButton.Size = New-Object System.Drawing.Size($width,$height)
    $newButton.Add_Click($onClick)
    if ($normal) {
    Style-Button -button $newButton
    } else {
        Style-DelButton -button $newButton
    }
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

function Build-GUI {
    param (
        [System.Windows.Forms.Form]$forms,
        [System.Collections.ArrayList]$objectsToAdd
    )

    foreach ($object in $objectsToAdd) {
        $forms.Controls.Add($object)
    }
}

function newPosXY {
    param (
        $xPos,
        $yPos
    )
    return New-Object System.Drawing.Point($xPos, $yPos)
}


#Objects -----------------------------------------------------------------
$gui = New-Object System.Windows.Forms.Form
$filebrowserwindow = New-Object System.Windows.Forms.FolderBrowserDialog


#GUI -----------------------------------------------------------------
$gui.Text = "Batch firewall rule adder - by github.com/mwFrozenDEV"
$gui.Size = New-Object System.Drawing.Size(500,400)
$gui.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$gui.StartPosition = "CenterScreen"
$gui.BackColor = Convert-HexToColor "#002457"


#Labels -----------------------------------------------------------------
$topTitle = createLabel -width 300 -height 20 -text "Batch Firewall Rule adder"

$botTitle = createLabel -width 300 -height 20 -text "by github.com/mwFrozenDEV"
$botTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)

$currentpathLabel = createLabel -width 20 -height 300 -text "Select a Path (Double Click to open Path in Explorer)"
$currentpathLabel.BackColor = Convert-HexToColor "#0C0C0C"
$currentpathLabel.ForeColor = Convert-HexToColor "#F1F6F9"
$currentpathLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$currentpathLabel.add_DoubleClick({OpenCurrentPath}) #DoubleClick opens your currently selected Path in the Fileexplorer


#Buttons -----------------------------------------------------------------
$buttonWidth = 190
$buttonHeight = 80
$button_SelectPath = createButton -width 150 -height 45 -textOnButton "Choose Path" -onClick { ChoosePath } -normal $true
$button_Inbound = createButton -width $buttonWidth -height $buttonHeight -textOnButton "Create Inbound Rules" -onClick { addFirewallRule -direction "Inbound" } -normal $true
$button_Outbound = createButton -width $buttonWidth -height $buttonHeight -textOnButton "Create Outbound Rules" -onClick { addFirewallRule -direction "Outbound" } -normal $true
$button_Both = createButton -width $buttonWidth -height $buttonHeight -textOnButton "Create Both Rules" -Onclick { addBothFirewallRules } -normal $true
$button_DelInbound = createButton -width 140 -height 40 -textOnButton "Delete Inbound Rules" -Onclick { deleteCreatedFirewallRules -direction "Inbound" } -normal $false
$button_DelOutbound = createButton -width 140 -height 40 -textOnButton "Delete Outbound Rules" -Onclick { deleteCreatedFirewallRules -direction "Outbound" } -normal $false
$button_DelInbound.Visible = $false
$button_DelOutbound.Visible = $false

#Checkbox -----------------------------------------------------------------
$checkbox = New-Object System.Windows.Forms.CheckBox
$checkbox.Text = "Enable Deletion"
$checkbox.Size = New-Object System.Drawing.Size(200,30)
$checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$checkbox.ForeColor = Convert-HexToColor "#F1F6F9"
$checkbox.add_CheckedChanged({
    if ($checkbox.Checked) {
        $button_DelInbound.Visible = $true
        $button_DelOutbound.Visible = $true
        $gui.Size = New-Object System.Drawing.Size(500,500)
    } else {
        $button_DelInbound.Visible = $false
        $button_DelOutbound.Visible = $false
        $gui.Size = New-Object System.Drawing.Size(500,400)
    }
})

#Locations -----------------------------------------------------------------
$topTitle.Location = newPosXY -xPos 15 -yPos 5
$botTitle.Location = newPosXY -xPos 15 -yPos 40
$button_SelectPath.Location = newPosXY -xPos 15 -yPos 70
$button_Inbound.Location = newPosXY -xPos 15 -yPos 180
$button_Outbound.Location = newPosXY -xPos 250 -yPos 180
$button_Both.Location = newPosXY -xPos 135 -yPos 270
$currentpathLabel.Location = newPosXY -xPos 15 -yPos 135
$checkbox.Location = newPosXY -xPos 15 -yPos 300
$button_DelInbound.Location = newPosXY -xPos 65 -yPos 380
$button_DelOutbound.Location = newPosXY -xPos 250 -yPos 380


#Building the gui -----------------------------------------------------------------
$addToGUI = @( #Array that holds all elements of the GUI
    $topTitle,
    $botTitle,
    $button_SelectPath,
    $currentPathLabel,
    $button_Inbound,
    $button_Outbound,
    $button_Both,
    $button_DelInbound,
    $button_DelOutbound,
    $checkbox
)

Build-GUI -forms $gui -objectsToAdd $addToGUI
$botTitle.BringToFront()
#Show the gui -----------------------------------------------------------------
$gui.Add_Shown({ $gui.Activate() })
[void] $gui.ShowDialog()

#                                              ,                                                                       
#                                              Et                     :                                                
#                                              E#t                   t#,                               ,;L.            
#                                              E##t     j.          ;##W.                            f#i EW:        ,ft
#             ..       :           ;           E#W#t    EW,        :#L:WE                          .E#t  E##;       t#E
#            ,W,     .Et         .DL           E#tfL.   E##j      .KG  ,#D   ,##############Wf.   i#W,   E###t      t#E
#           t##,    ,W#t f.     :K#L     LWL   E#t      E###D.    EE    ;#f   ........jW##Wt     L#D.    E#fE#f     t#E
#          L###,   j###t EW:   ;W##L   .E#f ,ffW#Dffj.  E#jG#W;  f#.     t#i        tW##Kt     :K#Wfff;  E#t D#G    t#E
#        .E#j##,  G#fE#t E#t  t#KE#L  ,W#;   ;LW#ELLLf. E#t t##f :#G     GK       tW##E;       i##WLLLLt E#t  f#E.  t#E
#       ;WW; ##,:K#i E#t E#t f#D.L#L t#K:      E#t      E#t  :K#E:;#L   LW.     tW##E;          .E#L     E#t   t#K: t#E
#      j#E.  ##f#W,  E#t E#jG#f  L#LL#G        E#t      E#KDDDD###it#f f#:   .fW##D,              f#E:   E#t    ;#W,t#E
#    .D#L    ###K:   E#t E###;   L###j         E#t      E#f,t#Wi,,, f#D#;  .f###D,                 ,WW;  E#t     :K#D#E
#   :K#t     ##D.    E#t E#K:    L#W;          E#t      E#t  ;#W:    G#t .f####Gfffffffffff;        .D#; E#t      .E##E
#   ...      #G      ..  EG      LE.           E#t      DWi   ,KK:    t .fLLLLLLLLLLLLLLLLLi          tt ..         G#E
#            j           ;       ;@            ;#t                                                                   fE
#                                              :;                                                                    ,
# made by github.com/mwFrozenDEV