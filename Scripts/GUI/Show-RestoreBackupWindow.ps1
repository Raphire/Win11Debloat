function Show-RestoreBackupWindow {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner = $null
    )

    try {
        Write-Host 'Opening restore backup dialog.'

        $dialogResult = Show-RestoreBackupDialog -Owner $Owner
        if (-not $dialogResult -or $dialogResult.Result -eq 'Cancel') {
            Write-Host 'Restore canceled by user.'
            return
        }

        try {
            if ($dialogResult.Result -eq 'RestoreRegistry') {
                $backup = $dialogResult.Backup
                if (-not $backup) {
                    Write-Warning 'Registry backup restore requested without a selected backup.'
                    return
                }

                Write-Host "User confirmed registry restore for $($backup.Target)."
                Restore-RegistryBackupState -Backup $backup
                Show-MessageBox -Title 'Backup Restored' -Message 'Registry backup restored successfully.' -Icon Success
            }
            elseif ($dialogResult.Result -eq 'RestoreStartMenu') {
                $scope = $dialogResult.StartMenuScope
                $useManualBackupFile = ($dialogResult.UseManualBackupFile -eq $true)
                $backupFilePath = $null

                if ($useManualBackupFile) {
                    $openDialog = New-Object Microsoft.Win32.OpenFileDialog
                    $openDialog.Title = 'Select Start Menu backup file'
                    $openDialog.Filter = 'Start Menu backup (*.bak)|*.bak'
                    $openDialog.InitialDirectory = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
                    $openDialog.DefaultExt = '.bak'

                    $dialogSelection = if ($Owner) {
                        $openDialog.ShowDialog($Owner)
                    }
                    else {
                        $openDialog.ShowDialog()
                    }

                    if ($dialogSelection -ne $true) {
                        Write-Host 'Start Menu restore canceled: no backup file selected.'
                        return
                    }

                    $backupFilePath = $openDialog.FileName
                    Write-Host "Selected Start Menu backup file: $backupFilePath"
                }

                $result = if ($scope -eq 'AllUsers') {
                    RestoreStartMenuForAllUsers -BackupFilePath $backupFilePath
                }
                else {
                    RestoreStartMenu -BackupFilePath $backupFilePath
                }

                $resultEntries = @($result)
                $successCount = @($resultEntries | Where-Object { $_.Result -eq $true }).Count
                $failedEntries = @($resultEntries | Where-Object { $_.Result -ne $true })

                if ($successCount -gt 0) {
                    if ($failedEntries.Count -gt 0) {
                        $failureSummary = ($failedEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                        Show-MessageBox -Title 'Backup Partially Restored' -Message "The Start Menu backup was successfully restored for $successCount user(s).`n`nSome users could not be restored:`n$failureSummary" -Icon Warning
                    }
                    else {
                        if ($scope -eq 'AllUsers') {
                             Show-MessageBox -Title 'Backup Restored' -Message "The Start Menu backup was successfully restored for all users. The changes will apply the next time users sign in." -Icon Success
                        }
                        else {
                            Show-MessageBox -Title 'Backup Restored' -Message "The Start Menu backup was successfully restored for the current user. The changes will apply the next time you sign in." -Icon Success
                        }
                    }
                }
                else {
                    $errorSummary = ($resultEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                    Show-MessageBox -Title 'Error' -Message "Failed to restore the Start Menu backup.`n`n$errorSummary" -Icon Error
                }
            }
        }
        catch {
            Write-Error "Restore operation failed: $($_.Exception.Message)"
            Show-MessageBox -Title 'Error' -Message "Restore failed: $($_.Exception.Message)" -Icon Error
        }
    }
    catch {
        Write-Warning "Restore backup dialog failed: $($_.Exception.Message)"
    }
}
