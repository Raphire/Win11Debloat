<#
    .SYNOPSIS
        Shows the backup-restore dialog and performs the selected restore.
#>
function Show-RestoreBackupWindow {
    param(
        [System.Windows.Window]$Owner = $null
    )

    try {
        Write-Host '正在打开备份恢复窗口。'

        $restoreResult = [PSCustomObject]@{
            RestoredRegistry = $false
            RestoredStartMenu = $false
        }

        $dialogResult = Show-RestoreBackupDialog -Owner $Owner
        if (-not $dialogResult -or $dialogResult.Result -eq 'Cancel') {
            Write-Host '用户已取消恢复。'
            return $restoreResult
        }

        $successMessage = $null
        $warningMessage = $null

        if ($dialogResult.Result -eq 'RestoreRegistry') {
            $backup = $dialogResult.Backup
            if (-not $backup) {
                throw '未选择备份文件，无法恢复注册表备份。'
            }

            Write-Host "用户已确认恢复 $($backup.Target) 的注册表备份。"
            $restoreOpResult = Restore-RegistryBackupState -Backup $backup
            if ($restoreOpResult -and $restoreOpResult.Result) {
                $restoreResult.RestoredRegistry = $true
                if ($script:Params.ContainsKey("WhatIf")) {
                    $successMessage = Get-Translation -Key 'RestoreRegistryWhatIfMessage'
                }
                else {
                    $successMessage = Get-Translation -Key 'RestoreRegistrySuccessMessage'
                }
            }
        }
        elseif ($dialogResult.Result -eq 'Restore-StartMenu') {
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
                throw '未选择备份文件，已取消开始菜单恢复。'
            }

            $result = if ($scope -eq 'AllUsers') {
                Restore-StartMenuForAllUsers -BackupFilePath $backupFilePath
            }
            else {
                Restore-StartMenu -BackupFilePath $backupFilePath
            }

            $resultEntries = @($result)
            $successCount = @($resultEntries | Where-Object { $_.Result -eq $true }).Count
            $failedEntries = @($resultEntries | Where-Object { $_.Result -ne $true })

            if ($successCount -eq 0) {
                $errorSummary = ($resultEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                throw (Get-Translation -Key 'RestoreStartMenuFailedMessage' -FormatArgs @($errorSummary))
            }

            if ($failedEntries.Count -gt 0) {
                $failureSummary = ($failedEntries | ForEach-Object { $_.Message }) -join [Environment]::NewLine
                $warningMessage = Get-Translation -Key 'RestoreStartMenuPartialSuccessMessage' -FormatArgs @($successCount, $failureSummary)
            }
            else {
                if ($script:Params.ContainsKey("WhatIf")) {
                    $successMessage = Get-Translation -Key 'RestoreStartMenuWhatIfMessage'
                }
                elseif ($scope -eq 'AllUsers') {
                    $successMessage = Get-Translation -Key 'RestoreStartMenuAllUsersSuccessMessage'
                }
                else {
                    $successMessage = Get-Translation -Key 'RestoreStartMenuCurrentUserSuccessMessage'
                }
            }

            $restoreResult.RestoredStartMenu = $true
        }

        if ($warningMessage) {
            Write-Host "$warningMessage"
            Show-MessageBox -Title (Get-Translation -Key 'RestoreBackupRestoredTitle') -Message $warningMessage -Icon Warning
        }
        elseif ($successMessage) {
            Write-Host "$successMessage"
            Show-MessageBox -Title (Get-Translation -Key 'RestoreBackupRestoredTitle') -Message $successMessage -Icon Success
        }

        return $restoreResult
    }
    catch {
        $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { Get-Translation -Key 'RestoreUnexpectedError' }
        Write-Error "恢复操作失败：$errorMessage"
        Show-MessageBox -Title (Get-Translation -Key 'ErrorTitle') -Message (Get-Translation -Key 'RestoreOperationFailedMessage' -FormatArgs @($errorMessage)) -Icon Error
        return [PSCustomObject]@{
            RestoredRegistry = $false
            RestoredStartMenu = $false
        }
    }
}
