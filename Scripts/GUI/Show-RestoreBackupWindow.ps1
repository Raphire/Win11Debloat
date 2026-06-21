function Show-RestoreBackupWindow {
    param(
        [System.Windows.Window]$Owner = $null
    )

    try {
        Write-Host 'Opening restore backup dialog.'

        $restoreResult = [PSCustomObject]@{
            RestoredRegistry = $false
            RestoredStartMenu = $false
        }

        $dialogResult = Show-RestoreBackupDialog -Owner $Owner
        if (-not $dialogResult -or $dialogResult.Result -eq 'Cancel') {
            Write-Host 'Restore canceled by user.'
            return $restoreResult
        }

        $successMessage = $null
        $warningMessage = $null

        if ($dialogResult.Result -eq 'RestoreRegistry') {
            $backup = $dialogResult.Backup
            if (-not $backup) {
                throw 'Registry backup restore requested without a selected backup.'
            }

            Write-Host "User confirmed registry restore for $($backup.Target)."
            $restoreOpResult = Restore-RegistryBackupState -Backup $backup
            if ($restoreOpResult -and $restoreOpResult.Result) {
                $restoreResult.RestoredRegistry = $true
                if ($script:Params.ContainsKey("WhatIf")) {
                    $successMessage = '[WhatIf] Registry backup would be restored (no changes made).'
                }
                else {
                    $successMessage = 'Registry backup restored successfully. Some changes may require a restart to take effect.'
                }
            }
        }
        elseif ($dialogResult.Result -eq 'RestoreStartMenu') {
            $scope = $dialogResult.StartMenuScope
            $useManualBackupFile = ($dialogResult.UseManualBackupFile -eq $true)
            $backupFilePath = $null
            if ($dialogResult -is [hashtable] -and $dialogResult.ContainsKey('BackupFilePath')) {
                $backupFilePath = $dialogResult['BackupFilePath']
            }
            elseif ($dialogResult.PSObject.Properties.Match('BackupFilePath').Count -gt 0) {
                $backupFilePath = $dialogResult.BackupFilePath
            }

            if ($useManualBackupFile -and [string]::IsNullOrWhiteSpace($backupFilePath)) {
                throw 'Start Menu restore canceled: no backup file selected.'
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

            if ($successCount -eq 0) {
                $errorSummary = ($resultEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                throw "Failed to restore the Start Menu backup.`n$errorSummary"
            }

            if ($failedEntries.Count -gt 0) {
                $failureSummary = ($failedEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                $warningMessage = "The Start Menu backup was successfully restored for $successCount user(s).`nSome users could not be restored:`n$failureSummary"
            }
            else {
                if ($script:Params.ContainsKey("WhatIf")) {
                    $successMessage = '[WhatIf] Start Menu backup would be restored (no changes made).'
                }
                elseif ($scope -eq 'AllUsers') {
                    $successMessage = "The Start Menu backup was successfully restored for all users. The changes will apply the next time users sign in."
                }
                else {
                    $successMessage = "The Start Menu backup was successfully restored for the current user. The changes will apply the next time you sign in."
                }
            }

            $restoreResult.RestoredStartMenu = $true
        }

        if ($warningMessage) {
            Write-Host "$warningMessage"
            Show-MessageBox -Title 'Backup Restored' -Message $warningMessage -Icon Warning
        }
        elseif ($successMessage) {
            Write-Host "$successMessage"
            Show-MessageBox -Title 'Backup Restored' -Message $successMessage -Icon Success
        }

        return $restoreResult
    }
    catch {
        $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { 'An unexpected error occurred.' }
        Write-Error "Restore operation failed: $errorMessage"
        Show-MessageBox -Title 'Error' -Message "Restore failed: $errorMessage" -Icon Error
        return [PSCustomObject]@{
            RestoredRegistry = $false
            RestoredStartMenu = $false
        }
    }
}
