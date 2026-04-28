function Show-RestoreBackupWindow {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner = $null
    )

    try {
        Write-Host 'Opening restore backup dialog.'
        $dialogResult = Show-RestoreBackupDialog -Owner $Owner
        if ($dialogResult.Result -ne 'Restore' -or -not $dialogResult.Backup) {
            Write-Host 'Restore canceled by user or no backup selected.'
            return
        }

        $backup = $dialogResult.Backup
        $backupTarget = [string]$backup.Target

        if ($backupTarget -like 'CurrentUser:*') {
            $targetCurrentUserName = $backupTarget.Substring(12)
            $activeUserName = [string](GetUserName)

            if (-not [string]::Equals($targetCurrentUserName, $activeUserName, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "Backup target '$backupTarget' does not match active account '$activeUserName'."
                $confirmationResult = Show-MessageBox -Owner $Owner -Message "This backup was created for user '$targetCurrentUserName', but you are signed in as '$activeUserName'. Do you want to continue restoring anyway?" -Title 'Confirm Restore Target' -Button 'YesNo' -Icon 'Warning'
                if ($confirmationResult -ne 'Yes') {
                    Write-Host 'Restore canceled by user after CurrentUser target mismatch prompt.'
                    return
                }
            }
        }

        try {
            Write-Host "User confirmed restore. Target='$($backup.Target)', RootKeys=$(@($backup.RegistryKeys).Count)"
            Restore-RegistryBackupState -Backup $backup
            Write-Host 'Registry backup restore completed successfully.'
            Show-MessageBox -Owner $Owner -Message 'Registry backup was restored successfully.' -Title 'Restore Completed' -Button 'OK' -Icon 'Information' | Out-Null
        }
        catch {
            Write-Error "Registry backup restore failed: $($_.Exception.Message)"
            Show-MessageBox -Owner $Owner -Message "Failed to restore registry backup: $($_.Exception.Message)" -Title 'Restore Failed' -Button 'OK' -Icon 'Error' | Out-Null
        }
    }
    catch {
        Write-Warning "Restore backup dialog failed: $($_.Exception.Message)"
        try {
            Show-MessageBox -Owner $Owner -Message "Unable to open restore backup dialog: $($_.Exception.Message)" -Title 'Restore Backup' -Button 'OK' -Icon 'Error' | Out-Null
        }
        catch {
            # Last-resort: avoid rethrowing from UI error handling.
        }
    }
}
