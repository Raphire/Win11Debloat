#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Silent,
    [switch]$Sysprep,
    [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RemoveApps,
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$TaskbarAlignLeft,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableWidgets,
    [switch]$HideWidgets,
    [switch]$DisableChat,
    [switch]$HideChat,
    [switch]$ClearStart,
    [switch]$ClearStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)


# Show error if current powershell environment does not have LanguageMode set to FullLanguage
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "Erro: Win11Debloat nao pode ser executado em seu sistema, a execucao do PowerShell eh restrita por politicas de seguranca" -ForegroundColor Red
    Write-Output ""
    Write-Output "Pressione enter para sair..."
    Read-Host | Out-Null
    Exit
}


# Shows application selection form that allows the user to select what apps they want to remove or keep
function ShowAppSelectionForm {
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

    # Initialise form objects
    $form = New-Object System.Windows.Forms.Form
    $label = New-Object System.Windows.Forms.Label
    $button1 = New-Object System.Windows.Forms.Button
    $button2 = New-Object System.Windows.Forms.Button
    $selectionBox = New-Object System.Windows.Forms.CheckedListBox
    $loadingLabel = New-Object System.Windows.Forms.Label
    $onlyInstalledCheckBox = New-Object System.Windows.Forms.CheckBox
    $checkUncheckCheckBox = New-Object System.Windows.Forms.CheckBox
    $initialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    $global:selectionBoxIndex = -1

    # saveButton eventHandler
    $handler_saveButton_Click=
    {
        if ($selectionBox.CheckedItems -contains "Microsoft.WindowsStore" -and -not $Silent) {
            $warningSelection = [System.Windows.Forms.Messagebox]::Show('Tem certeza de que deseja desinstalar a Microsoft Store? Este aplicativo nao pode ser reinstalado facilmente.', 'Tem certeza?', 'YesNo', 'Warning')

            if ($warningSelection -eq 'No') {
                return
            }
        }

        $global:SelectedApps = $selectionBox.CheckedItems

        # Create file that stores selected apps if it doesn't exist
        if (!(Test-Path "$PSScriptRoot/CustomAppsList")) {
            $null = New-Item "$PSScriptRoot/CustomAppsList"
        }

        Set-Content -Path "$PSScriptRoot/CustomAppsList" -Value $global:SelectedApps

        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }

    # cancelButton eventHandler
    $handler_cancelButton_Click=
    {
        $form.Close()
    }

    $selectionBox_SelectedIndexChanged=
    {
        $global:selectionBoxIndex = $selectionBox.SelectedIndex
    }

    $selectionBox_MouseDown=
    {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if ([System.Windows.Forms.Control]::ModifierKeys -eq [System.Windows.Forms.Keys]::Shift) {
                if ($global:selectionBoxIndex -ne -1) {
                    $topIndex = $global:selectionBoxIndex

                    if ($selectionBox.SelectedIndex -gt $topIndex) {
                        for (($i = ($topIndex)); $i -le $selectionBox.SelectedIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                    elseif ($topIndex -gt $selectionBox.SelectedIndex) {
                        for (($i = ($selectionBox.SelectedIndex)); $i -le $topIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                }
            }
            elseif ($global:selectionBoxIndex -ne $selectionBox.SelectedIndex) {
                $selectionBox.SetItemChecked($selectionBox.SelectedIndex, -not $selectionBox.GetItemChecked($selectionBox.SelectedIndex))
            }
        }
    }

    $check_All=
    {
        for (($i = 0); $i -lt $selectionBox.Items.Count; $i++){
            $selectionBox.SetItemChecked($i, $checkUncheckCheckBox.Checked)
        }
    }

    $load_Apps=
    {
        # Correct the initial state of the form to prevent the .Net maximized form issue
        $form.WindowState = $initialFormWindowState

        # Reset state to default before loading appslist again
        $global:selectionBoxIndex = -1
        $checkUncheckCheckBox.Checked = $False

        # Show loading indicator
        $loadingLabel.Visible = $true
        $form.Refresh()

        # Clear selectionBox before adding any new items
        $selectionBox.Items.Clear()

        # Set filePath where Appslist can be found
        $appsFile = "$PSScriptRoot/Appslist.txt"
        $listOfApps = ""

        if ($onlyInstalledCheckBox.Checked -and ($global:wingetInstalled -eq $true)) {
            # Attempt to get a list of installed apps via winget, times out after 10 seconds
            $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
            $jobDone = $job | Wait-Job -TimeOut 10

            if (-not $jobDone) {
                # Show error that the script was unable to get list of apps from winget
                [System.Windows.MessageBox]::Show('Nao eh possivel carregar a lista de aplicativos instalados via winget, alguns aplicativos podem nao ser exibidos na lista.', 'Error', 'Ok', 'Error')
            }
            else {
                # Add output of job (list of apps) to $listOfApps
                $listOfApps = Receive-Job -Job $job
            }
        }

        # Go through appslist and add items one by one to the selectionBox
        Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^#  .*' -and $_ -notmatch '^# -* #' } )) {
            $appChecked = $true

            # Remove first # if it exists and set appChecked to false
            if ($app.StartsWith('#')) {
                $app = $app.TrimStart("#")
                $appChecked = $false
            }

            # Remove any comments from the Appname
            if (-not ($app.IndexOf('#') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf('#'))
            }

            # Remove leading and trailing spaces and `*` characters from Appname
            $app = $app.Trim()
            $appString = $app.Trim('*')

            # Make sure appString is not empty
            if ($appString.length -gt 0) {
                if ($onlyInstalledCheckBox.Checked) {
                    # onlyInstalledCheckBox is checked, check if app is installed before adding it to selectionBox
                    if (-not ($listOfApps -like ("*$appString*")) -and -not (Get-AppxPackage -Name $app)) {
                        # App is not installed, continue with next item
                        continue
                    }
                    if (($appString -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        # App is not installed, continue with next item
                        continue
                    }
                }

                # Add the app to the selectionBox and set it's checked status
                $selectionBox.Items.Add($appString, $appChecked) | Out-Null
            }
        }

        # Hide loading indicator
        $loadingLabel.Visible = $False

        # Sort selectionBox alphabetically
        $selectionBox.Sorted = $True
    }

    $form.Text = "Selecao de aplicativos Win11Debloat"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,502)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $False

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "Confirmar"
    $button1.Location = New-Object System.Drawing.Point(27,472)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "Cancelar"
    $button2.Location = New-Object System.Drawing.Point(129,472)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,14)
    $Label.Font = 'Microsoft Sans Serif,8'
    $label.Text = 'Marque os aplicativos que deseja remover, desmarque os aplicativos que deseja manter'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,46)
    $loadingLabel.Size = New-Object System.Drawing.Size(300,418)
    $loadingLabel.Text = 'Carregando aplicativos...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,474)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = 'Mostrar apenas aplicativos instalados'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $checkUncheckCheckBox.TabIndex = 7
    $checkUncheckCheckBox.Location = New-Object System.Drawing.Point(16,22)
    $checkUncheckCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $checkUncheckCheckBox.Text = 'Marcar/Desmarcar tudo'
    $checkUncheckCheckBox.add_CheckedChanged($check_All)

    $form.Controls.Add($checkUncheckCheckBox)

    $selectionBox.FormattingEnabled = $True
    $selectionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $selectionBox.Name = "selectionBox"
    $selectionBox.Location = New-Object System.Drawing.Point(13,43)
    $selectionBox.Size = New-Object System.Drawing.Size(374,424)
    $selectionBox.TabIndex = 3
    $selectionBox.add_SelectedIndexChanged($selectionBox_SelectedIndexChanged)
    $selectionBox.add_Click($selectionBox_MouseDown)

    $form.Controls.Add($selectionBox)

    # Save the initial state of the form
    $initialFormWindowState = $form.WindowState

    # Load apps into selectionBox
    $form.add_Load($load_Apps)

    # Focus selectionBox when form opens
    $form.Add_Shown({$form.Activate(); $selectionBox.Focus()})

    # Show the Form
    return $form.ShowDialog()
}


# Returns list of apps from the specified file, it trims the app names and removes any comments
function ReadAppslistFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    # Get list of apps from file at the path provided, and remove them one by one
    Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) {
        # Remove any comments from the Appname
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

        # Remove any spaces before and after the Appname
        $app = $app.Trim()

        $appString = $app.Trim('*')
        $appsList += $appString
    }

    return $appsList
}


# Removes apps specified during function call from all user accounts and from the OS image.
function RemoveApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) {
        Write-Output "Tentando remover $app..."

        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            # Use winget to remove OneDrive and Edge
            if ($global:wingetInstalled -eq $false) {
                Write-Host "Erro: WinGet nao esta instalado ou esta desatualizado, $app nao pode ser removido" -ForegroundColor Red
            }
            else {
                # Uninstall app via winget
                Strip-Progress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "93")) {
                    Write-Host "Nao eh possivel desinstalar o Microsoft Edge via Winget" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "Voce gostaria de forcar a desinstalacao do Edge? NAO RECOMENDADO! (s/n)" ) -eq 's') {
                        Write-Output ""
                        ForceRemoveEdge
                    }
                }
            }
        }
        else {
            # Use Remove-AppxPackage to remove all other apps
            $app = '*' + $app + '*'

            # Remove installed app for all existing users
            if ($WinVersion -ge 22000){
                # Windows 11 build 22000 or later
                try {
                    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
                }
                catch {
                    Write-Host "Nao eh possivel remover $app para todos os usuarios" -ForegroundColor Yellow
                    Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                }
            }
            else {
                # Windows 10
                try {
                    Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "Nao eh possivel remover $app para o usuario atual" -ForegroundColor Yellow
                    Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                }

                try {
                    Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "Nao eh possivel remover $app para todos os usuarios" -ForegroundColor Yellow
                    Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                }
            }

            # Remove provisioned app from OS image, so the app won't be installed for any new users
            try {
                Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
            }
            catch {
                Write-Host "Nao eh possivel remover $app da imagem do Windows" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }
    }

    Write-Output ""
}


# Forcefully removes Microsoft Edge using it's uninstaller
function ForceRemoveEdge {
    # Based on work from loadstring1 & ave9858
    Write-Output "> Desinstalando a forca o Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (Creating this somehow allows uninstalling edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # Remove edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if ($null -ne $uninstallRegKey) {
        Write-Output "Executando o desinstalador..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "Removendo arquivos restantes..."

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$edgeStub"
        )

        foreach ($path in $edgePaths){
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  $path removido" -ForegroundColor DarkGray
            }
        }

        Write-Output "Limpando o registro..."

        # Remove ms edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "O Microsoft Edge foi desinstalado"
    }
    else {
        Write-Output ""
        Write-Host "Erro: Nao eh possivel desinstalar o Microsoft Edge a forca, o desinstalador nao foi encontrado" -ForegroundColor Red
    }

    Write-Output ""
}


# Execute provided command and strips progress spinners/bars from console output
function Strip-Progress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = 'Γû[Æê]|^\s+[-\\|/]\s+$'

    # Corrected regex pattern for size formatting, ensuring proper capture groups are utilized
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "ERRO: $($_.Exception.Message)"
        } else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, ''
            if (-not ([string]::IsNullOrWhiteSpace($line)) -and -not ($line.StartsWith('  '))) {
                $line
            }
        }
    }
}


# Import & execute regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-Output $message


    if (!$global:Params.ContainsKey("Sysprep")) {
        reg import "$PSScriptRoot\Regfiles\$path"
    }
    else {
        $defaultUserPath = $env:USERPROFILE.Replace($env:USERNAME, 'Default\NTUSER.DAT')

        reg load "HKU\Default" $defaultUserPath | Out-Null
        reg import "$PSScriptRoot\Regfiles\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
    }

    Write-Output ""
}


# Restart the Windows Explorer process
function RestartExplorer {
    Write-Output "> Reiniciando o processo do Windows Explorer para aplicar todas as alteracoes... (Isso pode causar alguma oscilacao)"

    # Only restart if the powershell process matches the OS architecture
    # Restarting explorer from a 32bit Powershell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem)
    {
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Warning "Nao eh possivel reiniciar o processo do Windows Explorer. Reinicie manualmente o seu PC para aplicar todas as alteracoes."
    }
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$PSScriptRoot/Start/start2.bin"
    )

    Write-Output "> Removendo todos os aplicativos fixados do menu iniciar para todos os usuarios..."

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Erro: Nao eh possivel limpar o menu iniciar, arquivo start2.bin ausente da pasta de script" -ForegroundColor Red
        Write-Output ""
        return
    }

    # Get path to start menu file for all users
    $userPathString = $env:USERPROFILE.Replace($env:USERNAME, "*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState")
    $usersStartMenuPaths = get-childitem -path $userPathString

    # Go through all users and replace the start menu file
    ForEach ($startMenuPath in $usersStartMenuPaths) {
        ReplaceStartMenu "$($startMenuPath.Fullname)\start2.bin" $startMenuTemplate
    }

    # Also replace the start menu file for the default user profile
    $defaultStartMenuPath = $env:USERPROFILE.Replace($env:USERNAME, 'Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState')

    # Create folder if it doesn't exist
    if (-not(Test-Path $defaultStartMenuPath)) {
        new-item $defaultStartMenuPath -ItemType Directory -Force | Out-Null
        Write-Output "Criou pasta LocalState para perfil de usuario padrao"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-Output "Menu iniciar substituido para o perfil de usuario padrao"
    Write-Output ""
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenu {
    param (
        $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin",
        $startMenuTemplate = "$PSScriptRoot/Start/start2.bin"
    )

    $userName = $startMenuBinFile.Split("\")[2]

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Erro: Nao eh possivel limpar o menu iniciar, arquivo start2.bin ausente da pasta de script" -ForegroundColor Red
        return
    }

    # Check if bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuBinFile)) {
        Write-Host "Erro: Nao eh possivel limpar o menu iniciar para o usuario $userName, o arquivo start2.bin nao foi encontrado" -ForegroundColor Red
        return
    }

    $backupBinFile = $startMenuBinFile + ".bak"

    # Backup current start menu file
    Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Output "Menu iniciar substituido para o usuario $userName"
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $message
    )

    # Add key if it doesn't already exist
    if (-not $global:Params.ContainsKey($parameterName)) {
        $global:Params.Add($parameterName, $true)
    }

    # Create or clear file that stores last used settings
    if (!(Test-Path "$PSScriptRoot/SavedSettings")) {
        $null = New-Item "$PSScriptRoot/SavedSettings"
    }
    elseif ($global:FirstSelection) {
        $null = Clear-Content "$PSScriptRoot/SavedSettings"
    }

    $global:FirstSelection = $false

    # Create entry and add it to the file
    $entry = "$parameterName#- $message"
    Add-Content -Path "$PSScriptRoot/SavedSettings" -Value $entry
}


function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat Script - $title"

    if ($global:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle (Modo Sysprep)"
    }
    else {
        $fullTitle = "$fullTitle (Usuario: $Env:UserName)"
    }

    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output $fullTitle
    Write-Output "-------------------------------------------------------------------------------------------"
}


function PrintFromFile {
    param (
        $path
    )

    Clear-Host

    # Get & print script menu from file
    Foreach ($line in (Get-Content -Path $path )) {
        Write-Output $line
    }
}


function AwaitKeyToExit {
    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Pressione qualquer tecla para sair..."
        $null = [System.Console]::ReadKey()
    }
}



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ((winget -v) -replace 'v','' -gt 1.4)) {
    $global:wingetInstalled = $true
}
else {
    $global:wingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "O Winget nao esta instalado ou esta desatualizado. Isso pode impedir que o Win11Debloat remova certos apps."
        Write-Output ""
        Write-Output "Pressione qualquer tecla para continuar mesmo assim..."
        $null = [System.Console]::ReadKey()
    }
}

# Get current Windows build version to compare against features
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

$global:Params = $PSBoundParameters
$global:FirstSelection = $true
$SPParams = 'WhatIf', 'Confirm', 'Verbose', 'Silent', 'Sysprep'
$SPParamCount = 0

# Count how many SPParams exist within Params
# This is later used to check if any options were selected
foreach ($Param in $SPParams) {
    if ($global:Params.ContainsKey($Param)) {
        $SPParamCount++
    }
}

# Hide progress bars for app removal, as they block Win11Debloat's output
if (-not ($global:Params.ContainsKey("Verbose"))) {
    $ProgressPreference = 'SilentlyContinue'
}
else {
    Read-Host "O modo detalhado esta habilitado, pressione Enter para continuar"
    $ProgressPreference = 'Continue'
}

if ($global:Params.ContainsKey("Sysprep")) {
    $defaultUserPath = $env:USERPROFILE.Replace($env:USERNAME, 'Default\NTUSER.DAT')

    # Exit script if default user directory or NTUSER.DAT file cannot be found
    if (-not (Test-Path "$defaultUserPath")) {
        Write-Host "Erro: Nao eh possivel iniciar o Win11Debloat no modo Sysprep, nao eh possivel encontrar a pasta de usuario padrao em '$defaultUserPath'" -ForegroundColor Red
        AwaitKeyToExit
        Exit
    }
    # Exit script if run in Sysprep mode on Windows 10
    if ($WinVersion -lt 22000) {
        Write-Host "Erro: O modo Sysprep do Win11Debloat nao eh compativel com o Windows 10" -ForegroundColor Red
        AwaitKeyToExit
        Exit
    }
}

# Remove SavedSettings file if it exists and is empty
if ((Test-Path "$PSScriptRoot/SavedSettings") -and ([String]::IsNullOrWhiteSpace((Get-content "$PSScriptRoot/SavedSettings")))) {
    Remove-Item -Path "$PSScriptRoot/SavedSettings" -recurse
}

# Only run the app selection form if the 'RunAppConfigurator' parameter was passed to the script
if ($RunAppConfigurator) {
    PrintHeader "Configurador de aplicativos"

    $result = ShowAppSelectionForm

    # Show different message based on whether the app selection was saved or cancelled
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "O configurador de aplicativos foi fechado sem salvar." -ForegroundColor Red
    }
    else {
        Write-Output "Sua selecao de aplicativo foi salva no arquivo 'CustomAppsList' na pasta raiz do script."
    }

    AwaitKeyToExit

    Exit
}

# Change script execution based on provided parameters or user input
if ((-not $global:Params.Count) -or $RunDefaults -or $RunWin11Defaults -or ($SPParamCount -eq $global:Params.Count)) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1'
    }
    else {
        # Show menu and wait for user input, loops until valid input is provided
        Do {
            $ModeSelectionMessage = "Selecione uma opcao (1/2/3/0)"

            PrintHeader 'Menu'

            Write-Output "(1) Modo Padrao: Aplique as configuracoes padrao"
            Write-Output "(2) Modo Personalizado: Modifique o script de acordo com suas necessidades"
            Write-Output "(3) Modo de remocao de aplicativo: Selecione e remova aplicativos, sem fazer outras alteracoes"

            # Only show this option if SavedSettings file exists
            if (Test-Path "$PSScriptRoot/SavedSettings") {
                Write-Output "(4) Aplicar configuracoes personalizadas salvas da ultima vez"

                $ModeSelectionMessage = "Selecione uma opcao (1/2/3/4/0)"
            }

            Write-Output ""
            Write-Output "(0) Mostrar mais informacoes"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            # Show information based on user input, Suppress user prompt if Silent parameter was passed
            if ($Mode -eq '0') {
                # Get & print script information from file
                PrintFromFile "$PSScriptRoot/Menus/Info"

                Write-Output ""
                Write-Output "Pressione qualquer tecla para voltar..."
                $null = [System.Console]::ReadKey()
            }
            elseif (($Mode -eq '4')-and -not (Test-Path "$PSScriptRoot/SavedSettings")) {
                $Mode = $null
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3' -and $Mode -ne '4')
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults after confirmation
        '1' {
            # Print the default settings & require userconfirmation, unless Silent parameter was passed
            if (-not $Silent) {
                PrintFromFile "$PSScriptRoot/Menus/DefaultSettings"

                Write-Output ""
                Write-Output "Pressione Enter para executar o script ou pressione CTRL+C para sair..."
                Read-Host | Out-Null
            }

            $DefaultParameterNames = 'RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','ShowKnownFileExt','DisableWidgets','HideChat','DisableCopilot'

            PrintHeader 'Default Mode'

            # Add default parameters if they don't already exist
            foreach ($ParameterName in $DefaultParameterNames) {
                if (-not $global:Params.ContainsKey($ParameterName)){
                    $global:Params.Add($ParameterName, $true)
                }
            }

            # Only add this option for Windows 10 users, if it doesn't already exist
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -and (-not $global:Params.ContainsKey('Hide3dObjects'))) {
                $global:Params.Add('Hide3dObjects', $Hide3dObjects)
            }
        }

        # Custom mode, show & add options based on user input
        '2' {
            # Get current Windows build version to compare against features
            $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

            PrintHeader 'Modo personalizado'

            # Show options for removing apps, only continue on valid input
            Do {
                Write-Host "Options:" -ForegroundColor Yellow
                Write-Host " (n) Nao remova nenhum aplicativo" -ForegroundColor Yellow
                Write-Host " (1) Remover apenas a selecao padrao de aplicativos de bloatware de 'Appslist.txt'" -ForegroundColor Yellow
                Write-Host " (2) Remover a selecao padrao de aplicativos de bloatware, bem como aplicativos de e-mail e calendario, aplicativos de desenvolvedor e aplicativos de jogos"  -ForegroundColor Yellow
                Write-Host " (3) Selecione quais aplicativos remover e quais manter" -ForegroundColor Yellow
                $RemoveAppsInput = Read-Host "Remover algum aplicativo pre-instalado? (n/1/2/3)"

                # Show app selection form if user entered option 3
                if ($RemoveAppsInput -eq '3') {
                    $result = ShowAppSelectionForm

                    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                        # User cancelled or closed app selection, show error and change RemoveAppsInput so the menu will be shown again
                        Write-Output ""
                        Write-Host "Selecao de aplicativo cancelada, tente novamente" -ForegroundColor Red

                        $RemoveAppsInput = 'c'
                    }

                    Write-Output ""
                }
            }
            while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2' -and $RemoveAppsInput -ne '3')

            # Select correct option based on user input
            switch ($RemoveAppsInput) {
                '1' {
                    AddParameter 'RemoveApps' 'Remover selecao padrao de aplicativos de bloatware'
                }
                '2' {
                    AddParameter 'RemoveApps' 'Remover selecao padrao de aplicativos de bloatware'
                    AddParameter 'RemoveCommApps' 'Remova os aplicativos Email, Calendararop e Pessoas'
                    AddParameter 'RemoveW11Outlook' 'Remover o novo aplicativo Outlook para Windows'
                    AddParameter 'RemoveDevApps' 'Remover aplicativos relacionados ao desenvolvedor'
                    AddParameter 'RemoveGamingApps' 'Remover o aplicativo Xbox e a barra de jogos Xbox'
                    AddParameter 'DisableDVR' 'Desativar gravacao de tela/jogo do Xbox'
                }
                '3' {
                    Write-Output "Voce selecionou $($global:SelectedApps.Count) aplicativos para remocao"

                    AddParameter 'RemoveAppsCustom' "Remover $($global:SelectedApps.Count) aplicativos:"

                    Write-Output ""

                    if ($( Read-Host -Prompt "Desativar gravacao de tela/jogo do Xbox? Tambem interrompe pop-ups de sobreposicao de jogos (s/n)" ) -eq 's') {
                        AddParameter 'DisableDVR' 'Desativar gravacao de tela/jogo do Xbox'
                    }
                }
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($global:Params.ContainsKey("Sysprep")) {
                    if ($( Read-Host -Prompt "Remover todos os aplicativos fixados do menu iniciar para todos os usuarios existentes e novos? (s/n)" ) -eq 's') {
                        AddParameter 'ClearStartAllUsers' 'Remover todos os aplicativos fixados do menu iniciar para usuarios existentes e novos'
                    }
                }
                else {
                    Do {
                        Write-Host "Opcoes:" -ForegroundColor Yellow
                        Write-Host " (n) Nao remova nenhum aplicativo fixado do menu iniciar" -ForegroundColor Yellow
                        Write-Host " (1) Remover todos os aplicativos fixados do menu iniciar somente para este usuario ($env:USERNAME)" -ForegroundColor Yellow
                        Write-Host " (2) Remover todos os aplicativos fixados do menu iniciar para todos os usuarios existentes e novos"  -ForegroundColor Yellow
                        $ClearStartInput = Read-Host "Remover todos os aplicativos fixados do menu iniciar? (n/1/2)"
                    }
                    while ($ClearStartInput -ne 'n' -and $ClearStartInput -ne '0' -and $ClearStartInput -ne '1' -and $ClearStartInput -ne '2')

                    # Select correct option based on user input
                    switch ($ClearStartInput) {
                        '1' {
                            AddParameter 'ClearStart' "Remover todos os aplicativos fixados do menu iniciar somente para este usuario"
                        }
                        '2' {
                            AddParameter 'ClearStartAllUsers' "Remover todos os aplicativos fixados do menu iniciar para todos os usuarios existentes e novos"
                        }
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Desativar telemetria, dados de diagnostico, historico de atividades, rastreamento de inicializacao de aplicativos e anuncios segmentados? (s/n)" ) -eq 's') {
                AddParameter 'DisableTelemetry' 'Desabilitar telemetria, dados de diagnostico, historico de atividades, rastreamento de inicializacao de aplicativos e anuncios segmentados'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Desativar dicas, truques, sugestoes e anuncios em iniciar, configuracoes, notificacoes, explorador e tela de bloqueio? (s/n)" ) -eq 's') {
                AddParameter 'DisableSuggestions' 'Desabilite dicas, truques, sugestoes e anuncios em iniciar, configuracoes, notificacoes e Explorador de Arquivos'
                AddParameter 'DisableLockscreenTips' 'Desativar dicas e truques na tela de bloqueio'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Desabilitar e remover a pesquisa na web do Bing, Bing AI e Cortana na pesquisa do Windows? (s/n)" ) -eq 's') {
                AddParameter 'DisableBing' 'Desabilitar e remover a pesquisa na web do Bing, Bing AI e Cortana na pesquisa do Windows'
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($( Read-Host -Prompt "Desabilitar e remover o Windows Copilot? Isso se aplica a todos os usuarios (s/n)" ) -eq 's') {
                    AddParameter 'DisableCopilot' 'Desabilitar e remover o Windows Copilot'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "Desabilitar snapshots do Windows Recall? Isso se aplica a todos os usuarios (s/n)" ) -eq 's') {
                    AddParameter 'DisableRecall' 'Desabilitar snapshots do Windows Recall'
                }
            }

            # Only show this option for Windows 11 users running build 22000 or later
            if ($WinVersion -ge 22000){
                Write-Output ""

                if ($( Read-Host -Prompt "Restaurar o antigo menu de contexto no estilo do Windows 10? (s/n)" ) -eq 's') {
                    AddParameter 'RevertContextMenu' 'Restaurar o antigo menu de contexto no estilo do Windows 10'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Deseja fazer alguma alteracao na barra de tarefas e nos servicos relacionados? (s/n)" ) -eq 's') {
                # Only show these specific options for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Alinhar os botoes da barra de tarefas para o lado esquerdo? (s/n)" ) -eq 's') {
                        AddParameter 'TaskbarAlignLeft' 'Alinhar icones da barra de tarefas a esquerda'
                    }

                    # Show options for search icon on taskbar, only continue on valid input
                    Do {
                        Write-Output ""
                        Write-Host "   Opcoes:" -ForegroundColor Yellow
                        Write-Host "    (n) Nao alterar" -ForegroundColor Yellow
                        Write-Host "    (1) Ocultar icone de pesquisa da barra de tarefas" -ForegroundColor Yellow
                        Write-Host "    (2) Mostrar icone de pesquisa na barra de tarefas" -ForegroundColor Yellow
                        Write-Host "    (3) Mostrar icone de pesquisa com rotulo na barra de tarefas" -ForegroundColor Yellow
                        Write-Host "    (4) Mostrar caixa de pesquisa na barra de tarefas" -ForegroundColor Yellow
                        $TbSearchInput = Read-Host "   Ocultar ou alterar o icone de pesquisa na barra de tarefas? (n/1/2/3/4)"
                    }
                    while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4')

                    # Select correct taskbar search option based on user input
                    switch ($TbSearchInput) {
                        '1' {
                            AddParameter 'HideSearchTb' 'Ocultar icone de pesquisa da barra de tarefas'
                        }
                        '2' {
                            AddParameter 'ShowSearchIconTb' 'Mostrar icone de pesquisa na barra de tarefas'
                        }
                        '3' {
                            AddParameter 'ShowSearchLabelTb' 'Mostrar icone de pesquisa com rotulo na barra de tarefas'
                        }
                        '4' {
                            AddParameter 'ShowSearchBoxTb' 'Mostrar caixa de pesquisa na barra de tarefas'
                        }
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Ocultar o botao taskview da barra de tarefas? (s/n)" ) -eq 's') {
                        AddParameter 'HideTaskview' 'Ocultar o botao taskview da barra de tarefas'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Desativar o servico de widgets e ocultar o icone da barra de tarefas? (s/n)" ) -eq 's') {
                    AddParameter 'DisableWidgets' 'Desabilite o servico de widget e oculte o icone do widget (noticias e interesses) da barra de tarefas'
                }

                # Only show this options for Windows users running build 22621 or earlier
                if ($WinVersion -le 22621){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Ocultar o icone de bate-papo (reunir-se agora) da barra de tarefas? (s/n)" ) -eq 's') {
                        AddParameter 'HideChat' 'Ocultar o icone de bate-papo (reunir-se agora) da barra de tarefas?'
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Deseja fazer alguma alteracao no Explorador de Arquivos? (s/n)" ) -eq 's') {
                # Show options for changing the File Explorer default location
                Do {
                    Write-Output ""
                    Write-Host "   Opcoes:" -ForegroundColor Yellow
                    Write-Host "    (n) Nao alterar" -ForegroundColor Yellow
                    Write-Host "    (1) Abra o Explorador de Arquivos em 'Inicio'" -ForegroundColor Yellow
                    Write-Host "    (2) Abra o Explorador de Arquivos em 'Este Computador'" -ForegroundColor Yellow
                    Write-Host "    (3) Abra o Explorador de Arquivos em 'Downloads'" -ForegroundColor Yellow
                    Write-Host "    (4) Abra o Explorador de Arquivos em 'OneDrive'" -ForegroundColor Yellow
                    $ExplSearchInput = Read-Host "   Alterar o local padrao de abertura do Explorador de Arquivos? (n/1/2/3/4)"
                }
                while ($ExplSearchInput -ne 'n' -and $ExplSearchInput -ne '0' -and $ExplSearchInput -ne '1' -and $ExplSearchInput -ne '2' -and $ExplSearchInput -ne '3' -and $ExplSearchInput -ne '4')

                # Select correct taskbar search option based on user input
                switch ($ExplSearchInput) {
                    '1' {
                        AddParameter 'ExplorerToHome' "Alterar o local padrao de abertura do Explorador de Arquivos para 'Inicio'"
                    }
                    '2' {
                        AddParameter 'ExplorerToThisPC' "Alterar o local padrao de abertura do Explorador de Arquivos para 'Este Computador'"
                    }
                    '3' {
                        AddParameter 'ExplorerToDownloads' "Alterar o local padrao de abertura do Explorador de Arquivos para 'Downloads'"
                    }
                    '4' {
                        AddParameter 'ExplorerToOneDrive' "Alterar o local padrao de abertura do Explorador de Arquivos para 'OneDrive'"
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Mostrar arquivos, pastas e unidades ocultas? (s/n)" ) -eq 's') {
                    AddParameter 'ShowHiddenFolders' 'Mostrar arquivos, pastas e unidades ocultas'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Mostrar extensoes de arquivo para tipos de arquivo conhecidos? (s/n)" ) -eq 's') {
                    AddParameter 'ShowKnownFileExt' 'Mostrar extensoes de arquivo para tipos de arquivo conhecidos'
                }

                # Only show this option for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Ocultar a secao Inicio do painel lateral do Explorador de Arquivos? (s/n)" ) -eq 's') {
                        AddParameter 'HideHome' 'Ocultar a secao Inicio do painel lateral do Explorador de Arquivos'
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Ocultar a secao Galeria do painel lateral do Explorador de Arquivos? (s/n)" ) -eq 's') {
                        AddParameter 'HideGallery' 'Ocultar a secao Galeria do painel lateral do Explorador de Arquivos'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Ocultar entradas duplicadas de unidades removiveis no painel lateral do Explorador de Arquivos para que elas sejam exibidas somente em Este Computador? (s/n)" ) -eq 's') {
                    AddParameter 'HideDupliDrive' 'Ocultar entradas duplicadas de unidades removiveis no painel lateral do Explorador de Arquivos'
                }

                # Only show option for disabling these specific folders for Windows 10 users
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                    Write-Output ""

                    if ($( Read-Host -Prompt "Deseja ocultar alguma pasta do painel lateral do Explorador de Arquivos? (s/n)" ) -eq 's') {
                        Write-Output ""

                        if ($( Read-Host -Prompt "   Ocultar a pasta OneDrive do painel lateral do Explorador de Arquivos? (s/n)" ) -eq 's') {
                            AddParameter 'HideOnedrive' 'Ocultar a pasta OneDrive no painel lateral do Explorador de Arquivos'
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   Ocultar a pasta de objetos 3D do painel lateral do Explorador de Arquivos? (s/n)" ) -eq 's') {
                            AddParameter 'Hide3dObjects' "Oculte a pasta de objetos 3D em 'Este Computador' no Explorador de Arquivos"
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   Ocultar a pasta de musica do painel lateral do Explorador de Arquivos? (s/n)" ) -eq 's') {
                            AddParameter 'HideMusic' "Ocultar a pasta de musica em 'Este Computador' no Explorador de Arquivos"
                        }
                    }
                }
            }

            # Only show option for disabling context menu items for Windows 10 users or if the user opted to restore the Windows 10 context menu
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $global:Params.ContainsKey('RevertContextMenu')){
                Write-Output ""

                if ($( Read-Host -Prompt "Voce deseja desabilitar alguma opcao do menu de contexto? (s/n)" ) -eq 's') {
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Ocultar a opcao 'Incluir na biblioteca' no menu de contexto? (s/n)" ) -eq 's') {
                        AddParameter 'HideIncludeInLibrary' "Ocultar a opcao 'Incluir na biblioteca' no menu de contexto"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Ocultar a opcao 'Dar acesso a' no menu de contexto? (s/n)" ) -eq 's') {
                        AddParameter 'HideGiveAccessTo' "Ocultar a opcao 'Dar acesso a' no menu de contexto"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Ocultar a opcao 'Compartilhar' no menu de contexto? (s/n)" ) -eq 's') {
                        AddParameter 'HideShare' "Ocultar a opcao 'Compartilhar' no menu de contexto"
                    }
                }
            }

            # Suppress prompt if Silent parameter was passed
            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output ""
                Write-Output "Pressione Enter para confirmar suas escolhas e executar o script ou pressione CTRL+C para sair..."
                Read-Host | Out-Null
            }

            PrintHeader 'Modo personalizado'
        }

        # App removal, remove apps based on user selection
        '3' {
            PrintHeader "Remocao de aplicativo"

            $result = ShowAppSelectionForm

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Output "Voce selecionou $($global:SelectedApps.Count) aplicativos para remover"
                AddParameter 'RemoveAppsCustom' "Remover $($global:SelectedApps.Count) aplicativos:"

                # Suppress prompt if Silent parameter was passed
                if (-not $Silent) {
                    Write-Output ""
                    Write-Output "Pressione Enter para remover os aplicativos selecionados ou pressione CTRL+C para sair..."
                    Read-Host | Out-Null
                    PrintHeader "Remocao de aplicativo"
                }
            }
            else {
                Write-Host "A selecao foi cancelada, nenhum aplicativo foi removido" -ForegroundColor Red
                Write-Output ""
            }
        }

        # Load custom options selection from the "SavedSettings" file
        '4' {
            if (-not $Silent) {
                PrintHeader 'Modo Personalizado'
                Write-Output "O Win11Debloat fara as seguintes alteracoes:"

                # Get & print default settings info from file
                Foreach ($line in (Get-Content -Path "$PSScriptRoot/SavedSettings" )) {
                    # Remove any spaces before and after the line
                    $line = $line.Trim()

                    # Check if the line contains a comment
                    if (-not ($line.IndexOf('#') -eq -1)) {
                        $parameterName = $line.Substring(0, $line.IndexOf('#'))

                        # Print parameter description and add parameter to Params list
                        if ($parameterName -eq "RemoveAppsCustom") {
                            if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                                # Apps file does not exist, skip
                                continue
                            }

                            $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
                            Write-Output "- Remove $($appsList.Count) apps:"
                            Write-Host $appsList -ForegroundColor DarkGray
                        }
                        else {
                            Write-Output $line.Substring(($line.IndexOf('#') + 1), ($line.Length - $line.IndexOf('#') - 1))
                        }

                        if (-not $global:Params.ContainsKey($parameterName)){
                            $global:Params.Add($parameterName, $true)
                        }
                    }
                }

                Write-Output ""
                Write-Output ""
                Write-Output "Pressione Enter para executar o script ou pressione CTRL+C para sair..."
                Read-Host | Out-Null
            }

            PrintHeader 'Modo Personalizado'
        }
    }
}
else {
    PrintHeader 'Modo Personalizado'
}


# If the number of keys in SPParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if ($SPParamCount -eq $global:Params.Keys.Count) {
    Write-Output "O script foi concluido sem fazer nenhuma alteracao."

    AwaitKeyToExit
}
else {
    # Execute all selected/provided parameters
    switch ($global:Params.Keys) {
        'RemoveApps' {
            $appsList = ReadAppslistFromFile "$PSScriptRoot/Appslist.txt"
            Write-Output "> Removendo a selecao padrao de $($appsList.Count) aplicativos..."
            RemoveApps $appsList
            continue
        }
        'RemoveAppsCustom' {
            if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                Write-Host "> Erro: Nao foi possivel carregar a lista de aplicativos personalizados do arquivo, nenhum aplicativo foi removido" -ForegroundColor Red
                Write-Output ""
                continue
            }

            $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
            Write-Output "> Removendo $($appsList.Count) aplicativos..."
            RemoveApps $appsList
            continue
        }
        'RemoveCommApps' {
            Write-Output "> Removendo os aplicativos Email, Calendario e Pessoas..."

            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            RemoveApps $appsList
            continue
        }
        'RemoveW11Outlook' {
            $appsList = 'Microsoft.OutlookForWindows'
            Write-Output "> Removendo o novo aplicativo do Outlook para Windows..."
            RemoveApps $appsList
            continue
        }
        'RemoveDevApps' {
            $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
            Write-Output "> Removendo aplicativos relacionados ao desenvolvedor..."
            RemoveApps $appsList
            continue
        }
        'RemoveGamingApps' {
            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            Write-Output "> Removendo aplicativos relacionados a jogos..."
            RemoveApps $appsList
            continue
        }
        "ForceRemoveEdge" {
            ForceRemoveEdge
            continue
        }
        'DisableDVR' {
            RegImport "> Desabilitando gravacao de tela/jogo do Xbox..." "Disable_DVR.reg"
            continue
        }
        'ClearStart' {
            Write-Output "> Removendo todos os aplicativos fixados do menu iniciar para o usuario $env:USERNAME..."
            ReplaceStartMenu
            Write-Output ""
            continue
        }
        'ClearStartAllUsers' {
            ReplaceStartMenuForAllUsers
            continue
        }
        'DisableTelemetry' {
            RegImport "> Desativando telemetria, dados de diagnostico, historico de atividades, rastreamento de inicializacao de aplicativos e anuncios segmentados..." "Disable_Telemetry.reg"
            continue
        }
        {$_ -in "DisableBingSearches", "DisableBing"} {
            RegImport "> Desabilitando a pesquisa na web do Bing, Bing AI e Cortana na pesquisa do Windows..." "Disable_Bing_Cortana_In_Search.reg"

            # Also remove the app package for bing search
            $appsList = 'Microsoft.BingSearch'
            RemoveApps $appsList
            continue
        }
        {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
            RegImport "> Desativando dicas e truques na tela de bloqueio..." "Disable_Lockscreen_Tips.reg"
            continue
        }
        {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
            RegImport "> Desativando dicas, truques, sugestoes e anuncios no Windows..." "Disable_Windows_Suggestions.reg"
            continue
        }
        'RevertContextMenu' {
            RegImport "> Restaurando o antigo menu de contexto no estilo do Windows 10..." "Disable_Show_More_Options_Context_Menu.reg"
            continue
        }
        'TaskbarAlignLeft' {
            RegImport "> Alinhando os botoes da barra de tarefas a esquerda..." "Align_Taskbar_Left.reg"

            continue
        }
        'HideSearchTb' {
            RegImport "> Ocultando o icone de pesquisa da barra de tarefas..." "Hide_Search_Taskbar.reg"
            continue
        }
        'ShowSearchIconTb' {
            RegImport "> Alterando a pesquisa da barra de tarefas para somente icones..." "Show_Search_Icon.reg"
            continue
        }
        'ShowSearchLabelTb' {
            RegImport "> Alterando a pesquisa da barra de tarefas para um icone com rotulo..." "Show_Search_Icon_And_Label.reg"
            continue
        }
        'ShowSearchBoxTb' {
            RegImport "> Alterando a pesquisa da barra de tarefas para a caixa de pesquisa..." "Show_Search_Box.reg"
            continue
        }
        'HideTaskview' {
            RegImport "> Ocultando o botao taskview da barra de tarefas..." "Hide_Taskview_Taskbar.reg"
            continue
        }
        'DisableCopilot' {
            RegImport "> Desabilitando e removendo o Windows Copilot..." "Disable_Copilot.reg"

            # Also remove the app package for bing search
            $appsList = 'Microsoft.Copilot'
            RemoveApps $appsList
            continue
        }
        'DisableRecall' {
            RegImport "> Desabilitando snapshots do Windows Recall..." "Disable_AI_Recall.reg"
            continue
        }
        {$_ -in "HideWidgets", "DisableWidgets"} {
            RegImport "> Desabilitando o servico de widget e ocultando o icone do widget da barra de tarefas..." "Disable_Widgets_Taskbar.reg"
            continue
        }
        {$_ -in "HideChat", "DisableChat"} {
            RegImport "> Ocultando o icone de bate-papo da barra de tarefas..." "Disable_Chat_Taskbar.reg"
            continue
        }
        'ShowHiddenFolders' {
            RegImport "> Exibindo arquivos, pastas e unidades ocultas..." "Show_Hidden_Folders.reg"
            continue
        }
        'ShowKnownFileExt' {
            RegImport "> Habilitando extensoes de arquivo para tipos de arquivo conhecidos..." "Show_Extensions_For_Known_File_Types.reg"
            continue
        }
        'HideHome' {
            RegImport "> Ocultando a secao inicial do painel de navegacao do Explorador de Arquivos..." "Hide_Home_from_Explorer.reg"
            continue
        }
        'HideGallery' {
            RegImport "> Ocultando a secao da galeria do painel de navegacao do Explorador de Arquivos..." "Hide_Gallery_from_Explorer.reg"
            continue
        }
        'ExplorerToHome' {
            RegImport "> Alterando o local padrao de abertura do Explorador de Arquivos para `Inicio`..." "Launch_File_Explorer_To_Home.reg"
            continue
        }
        'ExplorerToThisPC' {
            RegImport "> Alterando o local padrao de abertura do Explorador de Arquivos para `Este Computador`..." "Launch_File_Explorer_To_This_PC.reg"
            continue
        }
        'ExplorerToDownloads' {
            RegImport "> Alterando o local padrao de abertura do Explorador de Arquivos para `Downloads`..." "Launch_File_Explorer_To_Downloads.reg"
            continue
        }
        'ExplorerToOneDrive' {
            RegImport "> Alterando o local padrao de abertura do Explorador de Arquivos para `OneDrive`..." "Launch_File_Explorer_To_OneDrive.reg"
            continue
        }
        'HideDupliDrive' {
            RegImport "> Ocultando entradas duplicadas de unidades removiveis no painel de navegacao do Explorador de Arquivos..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
            continue
        }
        {$_ -in "HideOnedrive", "DisableOnedrive"} {
            RegImport "> Ocultando a pasta OneDrive do painel de navegacao do Explorador de Arquivos..." "Hide_Onedrive_Folder.reg"
            continue
        }
        {$_ -in "Hide3dObjects", "Disable3dObjects"} {
            RegImport "> Ocultando a pasta de objetos 3D do painel de navegacao do Explorador de Arquivos..." "Hide_3D_Objects_Folder.reg"
            continue
        }
        {$_ -in "HideMusic", "DisableMusic"} {
            RegImport "> Ocultando a pasta de musica do painel de navegacao do Explorador de Arquivos..." "Hide_Music_folder.reg"
            continue
        }
        {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
            RegImport "> Ocultando 'Incluir na biblioteca' no menu de contexto..." "Disable_Include_in_library_from_context_menu.reg"
            continue
        }
        {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
            RegImport "> 'Ocultando 'Dar acesso a' no menu de contexto...'" "Disable_Give_access_to_context_menu.reg"
            continue
        }
        {$_ -in "HideShare", "DisableShare"} {
            RegImport "> Ocultando 'Compartilhar' no menu de contexto..." "Disable_Share_from_context_menu.reg"
            continue
        }
    }

    RestartExplorer

    Write-Output ""
    Write-Output ""
    Write-Output ""
    Write-Output "Script concluido com sucesso!"

    AwaitKeyToExit
}
