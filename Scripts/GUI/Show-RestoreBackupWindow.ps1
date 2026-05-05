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

        $successMessage = $null
        $warningMessage = $null

        if ($dialogResult.Result -eq 'RestoreRegistry') {
            $backup = $dialogResult.Backup
            if (-not $backup) {
                throw 'Registry backup restore requested without a selected backup.'
            }

            Write-Host "User confirmed registry restore for $($backup.Target)."
            Restore-RegistryBackupState -Backup $backup
            $successMessage = 'Registry backup restored successfully.'
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
                if ($scope -eq 'AllUsers') {
                    $successMessage = "The Start Menu backup was successfully restored for all users. The changes will apply the next time users sign in."
                }
                else {
                    $successMessage = "The Start Menu backup was successfully restored for the current user. The changes will apply the next time you sign in."
                }
            }
        }

        if ($warningMessage) {
            Write-Host "$warningMessage"
            Show-MessageBox -Title 'Backup Restored' -Message $warningMessage -Icon Warning
        }
        elseif ($successMessage) {
            Write-Host "$successMessage"
            Show-MessageBox -Title 'Backup Restored' -Message $successMessage -Icon Success
        }
    }
    catch {
        $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { 'An unexpected error occurred.' }
        Write-Error "Restore operation failed: $errorMessage"
        Show-MessageBox -Title 'Error' -Message "Restore failed: $errorMessage" -Icon Error
    }
}
