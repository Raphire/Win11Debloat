function Show-RestoreBackupDialog {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner = $null
    )

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    $usesDarkMode = GetSystemUsesDarkMode
    $ownerWindow = if ($Owner) { $Owner } else { $script:GuiWindow }

    $overlay = $null
    $overlayWasAlreadyVisible = $false
    if ($ownerWindow) {
        try {
            $overlay = $ownerWindow.FindName('ModalOverlay')
            if ($overlay) {
                $overlayWasAlreadyVisible = ($overlay.Visibility -eq 'Visible')
                if (-not $overlayWasAlreadyVisible) {
                    $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Visible' })
                }
            }
        }
        catch { }
    }

    $schemaPath = $script:RestoreBackupWindowSchema
    if (-not $schemaPath -or -not (Test-Path $schemaPath)) {
        throw 'Restore backup window schema file could not be found.'
    }

    $xaml = Get-Content -Path $schemaPath -Raw

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    if ($ownerWindow) {
        try {
            $window.Owner = $ownerWindow
        }
        catch { }
    }

    try {
        SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode
    }
    catch { }

    $titleBar = $window.FindName('TitleBar')
    $cancelBtn = $window.FindName('CancelBtn')
    $selectFileBtn = $window.FindName('SelectFileBtn')
    $restoreBtn = $window.FindName('RestoreBtn')
    $introInfoPanel = $window.FindName('IntroInfoPanel')
    $overviewPanel = $window.FindName('OverviewPanel')
    $backupFileText = $window.FindName('BackupFileText')
    $backupCreatedText = $window.FindName('BackupCreatedText')
    $backupTargetText = $window.FindName('BackupTargetText')
    $featuresItemsControl = $window.FindName('FeaturesItemsControl')

    if (-not $cancelBtn -or -not $selectFileBtn -or -not $restoreBtn) {
        throw 'Restore dialog failed to initialize action buttons.'
    }

    $newDialogState = {
        param(
            [string]$Result = 'Cancel',
            [string]$SelectedFile = $null,
            $Backup = $null
        )

        return @{ Result = $Result; SelectedFile = $SelectedFile; Backup = $Backup }
    }

    $titleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
    $window.Tag = & $newDialogState
    $cancelBtn.IsCancel = $true
    $selectFileBtn.IsDefault = $true

    if ($introInfoPanel) { $introInfoPanel.Visibility = 'Visible' }
    if ($overviewPanel) { $overviewPanel.Visibility = 'Collapsed' }
    $restoreBtn.Visibility = 'Collapsed'

    $cancelBtn.Add_Click({
        $window.Tag = & $newDialogState
        $window.DialogResult = $false
        $window.Close()
    })

    $restoreBtn.Add_Click({
        if (-not $window.Tag.Backup) {
            return
        }

        $window.Tag.Result = 'Restore'
        $window.DialogResult = $true
        $window.Close()
    })

    $selectFileBtn.Add_Click({
        $openDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openDialog.Title = 'Select registry backup file'
        $openDialog.Filter = 'Registry backup (*.json)|*.json|All files (*.*)|*.*'
        $openDialog.DefaultExt = '.json'
        $openDialog.InitialDirectory = $script:RegistryBackupsPath

        if ($openDialog.ShowDialog($window) -eq $true) {
            try {
                $selectedBackup = Load-RegistryBackupFromFile -FilePath $openDialog.FileName
            }
            catch {
                Write-Error "Failed to load registry backup from file '$($openDialog.FileName)': $($_.Exception.Message)"
                Show-MessageBox -Owner $window -Message 'The selected file is not a valid registry backup.' -Title 'Invalid Backup' -Button 'OK' -Icon 'Error' | Out-Null
                return
            }

            $createdText = if ([string]::IsNullOrWhiteSpace($selectedBackup.CreatedAt)) {
                'Unknown'
            }
            else {
                try {
                    [DateTime]::Parse($selectedBackup.CreatedAt).ToString('g')
                }
                catch {
                    $selectedBackup.CreatedAt
                }
            }

            $featuresList = @(
                foreach ($feature in @($selectedBackup.SelectedFeatures)) {
                    $labelText = [string]$feature.Label
                    if ([string]::IsNullOrWhiteSpace($labelText)) {
                        $labelText = [string]$feature.Name
                    }
                    if ([string]::IsNullOrWhiteSpace($labelText)) {
                        $labelText = 'Unknown feature'
                    }

                    [PSCustomObject]@{
                        DisplayText = "- $labelText"
                    }
                }
            )
            if ($featuresList.Count -eq 0) {
                $featuresList = @([PSCustomObject]@{ DisplayText = '- (Metadata unavailable) This backup contains registry snapshots but no SelectedFeatures list.' })
            }

            $backupFileText.Text = Split-Path $openDialog.FileName -Leaf
            $backupCreatedText.Text = $createdText
            $backupTargetText.Text = [string]$selectedBackup.Target
            $featuresItemsControl.ItemsSource = $featuresList
            if ($introInfoPanel) { $introInfoPanel.Visibility = 'Collapsed' }
            if ($overviewPanel) { $overviewPanel.Visibility = 'Visible' }

            $window.Tag = & $newDialogState -Result 'Preview' -SelectedFile $openDialog.FileName -Backup $selectedBackup
            $restoreBtn.Visibility = 'Visible'
            $restoreBtn.IsDefault = $true
            $selectFileBtn.Content = 'Select different file'
        }
    })

    $window.Add_KeyDown({
        param($source, $e)
        if ($e.Key -eq 'Escape') {
            $window.Tag = & $newDialogState
            $window.DialogResult = $false
            $window.Close()
        }
    })

    try {
        $null = $window.ShowDialog()
    }
    finally {
        if ($overlay -and -not $overlayWasAlreadyVisible) {
            try {
                $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
            }
            catch { }
        }
    }

    return $window.Tag
}
