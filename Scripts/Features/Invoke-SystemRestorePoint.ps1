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
        Write-Host "错误：无法判断系统还原是否已启用：$($_.Exception.Message)" -ForegroundColor Red
        $failed = $true
    }

    if (-not $failed -and $SysRestore.RPSessionInterval -eq 0) {
        # In GUI mode, skip the prompt and just try to enable it
        if ($script:GuiWindow -or $isSilent -or $( Read-Host -Prompt "系统还原已禁用，是否启用并创建还原点？（输入 y 确认，n 取消）") -eq 'y') {
            try {
                $enableResult = Invoke-NonBlocking -TimeoutSeconds 90 -ScriptBlock {
                    try {
                        Enable-ComputerRestore -Drive "$env:SystemDrive"
                        return $null
                    }
                    catch {
                        return "错误：启用系统还原失败：$_"
                    }
                }
            }
            catch {
                $enableResult = "错误：启用系统还原失败：$_"
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
                    return [PSCustomObject]@{ Success = $false; Message = "错误：无法获取现有还原点：$_" }
                }

                if ($recentRestorePoints.Count -eq 0) {
                    try {
                        Checkpoint-Computer -Description "Win11Debloat 创建的系统还原点" -RestorePointType "MODIFY_SETTINGS"
                        return [PSCustomObject]@{ Success = $true; Message = "系统还原点已成功创建。" }
                    }
                    catch {
                        return [PSCustomObject]@{ Success = $false; Message = "错误：无法创建还原点：$_" }
                    }
                }
                else {
                    return [PSCustomObject]@{ Success = $true; Message = "近期已有还原点，未创建新的还原点。" }
                }
            }
        }
        catch {
            $result = [PSCustomObject]@{ Success = $false; Message = "错误：创建系统还原点失败：$_" }
        }

        if ($result -and $result.Success) {
            Write-Host $result.Message
        }
        elseif ($result) {
            Write-Host $result.Message -ForegroundColor Red
            $failed = $true
        }
        else {
            Write-Host "错误：创建系统还原点失败。" -ForegroundColor Red
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
            Write-Host "创建系统还原点失败，是否在没有还原点的情况下继续？（输入 y 确认，n 取消）" -ForegroundColor Yellow
            if ($( Read-Host ) -ne 'y') {
                $script:CancelRequested = $true
                return $false
            }
        }

        Write-Host "警告：将在没有还原点的情况下继续。" -ForegroundColor Yellow
        return $false
    }

    return $true
}
