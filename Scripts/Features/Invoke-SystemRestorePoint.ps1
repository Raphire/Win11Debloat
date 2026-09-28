. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
    Creates a system restore point.

    .OUTPUTS
    System.Boolean. $true when a restore point is created; otherwise $false.
#>
function Invoke-SystemRestorePoint {
    $failed = $false
    $isSilent = ($script:Params -and $script:Params.ContainsKey('Silent')) -or $script:Silent

    try {
        $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction Stop
    }
    catch {
        Write-Host (Get-ConsoleTranslation -Text 'Error: Unable to determine whether System Restore is enabled: {0}' -FormatArgs @($($_.Exception.Message))) -ForegroundColor Red
        $failed = $true
    }

    if (-not $failed -and $SysRestore.RPSessionInterval -eq 0) {
        # In GUI mode, skip the prompt and just try to enable it
        if ($script:GuiWindow -or $isSilent -or $( Read-Host -Prompt (Get-ConsoleTranslation -Text 'System restore is disabled, would you like to enable it and create a restore point? (y/n)')) -eq 'y') {
            try {
                $enableResult = Invoke-NonBlocking -TimeoutSeconds 90 -ScriptBlock {
                    try {
                        Enable-ComputerRestore -Drive "$env:SystemDrive"
                        return $null
                    }
                    catch {
                        return (Get-ConsoleTranslation -Text 'Error: Failed to enable System Restore: {0}' -FormatArgs @($_))
                    }
                }
            }
            catch {
                $enableResult = (Get-ConsoleTranslation -Text 'Error: Failed to enable System Restore: {0}' -FormatArgs @($_))
            }

            if ($enableResult) {
                Write-Host $enableResult -ForegroundColor Red
                $failed = $true
            }
        }
        else {
            $failed = $true
        }
    }

    if (-not $failed) {
        try {
            $result = Invoke-NonBlocking -TimeoutSeconds 90 -ScriptBlock {
                try {
                    $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
                }
                catch {
                    return [PSCustomObject]@{ Success = $false; Message = (Get-ConsoleTranslation -Text 'Error: Unable to retrieve existing restore points: {0}' -FormatArgs @($_)) }
                }

                if ($recentRestorePoints.Count -eq 0) {
                    try {
                        Checkpoint-Computer -Description (Get-ConsoleTranslation -Text 'Restore point created by Win11Debloat') -RestorePointType "MODIFY_SETTINGS"
                        return [PSCustomObject]@{ Success = $true; Message = (Get-ConsoleTranslation -Text 'System restore point created successfully') }
                    }
                    catch {
                        return [PSCustomObject]@{ Success = $false; Message = (Get-ConsoleTranslation -Text 'Error: Unable to create restore point: {0}' -FormatArgs @($_)) }
                    }
                }
                else {
                    return [PSCustomObject]@{ Success = $true; Message = (Get-ConsoleTranslation -Text 'A recent restore point already exists, no new restore point was created') }
                }
            }
        }
        catch {
            $result = [PSCustomObject]@{ Success = $false; Message = (Get-ConsoleTranslation -Text 'Error: Failed to create system restore point: {0}' -FormatArgs @($_)) }
        }

        if ($result -and $result.Success) {
            Write-Host $result.Message
        }
        elseif ($result) {
            Write-Host $result.Message -ForegroundColor Red
            $failed = $true
        }
        else {
            Write-Host (Get-ConsoleTranslation -Text 'Error: Failed to create system restore point') -ForegroundColor Red
            $failed = $true
        }
    }

    # Ensure that the user is aware if creating a restore point failed, and give them the option to continue without a restore point or cancel the script
    if ($failed) {
        if ($script:GuiWindow) {
            $result = Show-MessageBox (Get-Translation -Key 'RestorePointFailedMessage') (Get-Translation -Key 'RestorePointFailedTitle') "YesNo" "Warning"

            if ($result -ne "Yes") {
                $script:CancelRequested = $true
                return $false
            }
        }
        elseif (-not $isSilent) {
            Write-Host (Get-ConsoleTranslation -Text 'Failed to create a system restore point. Do you want to continue without a restore point? (y/n)') -ForegroundColor Yellow
            if ($( Read-Host ) -ne 'y') {
                $script:CancelRequested = $true
                return $false
            }
        }

        Write-Host (Get-ConsoleTranslation -Text 'Warning: Continuing without restore point') -ForegroundColor Yellow
        return $false
    }

    return $true
}
