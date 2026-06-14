function CreateSystemRestorePoint {
    # Check if System Restore is disabled by reading the DisableSR registry value.
    # DisableSR = 1 means disabled. If the value is missing or 0, System Restore is enabled.
    $disableSR = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "DisableSR" -ErrorAction SilentlyContinue).DisableSR
    $failed = $false

    if ($disableSR -eq 1) {
        # In GUI mode, skip the prompt and just try to enable it
        if ($script:GuiWindow -or $Silent -or $( Read-Host -Prompt "System restore is disabled, would you like to enable it and create a restore point? (y/n)") -eq 'y') {
            try {
                $enableResult = Invoke-NonBlocking -TimeoutSeconds 90 -ScriptBlock {
                    try {
                        Enable-ComputerRestore -Drive "$env:SystemDrive"
                        return $null
                    }
                    catch {
                        return "Error: Failed to enable System Restore: $_"
                    }
                }
            }
            catch {
                $enableResult = "Error: Failed to enable System Restore: $_"
            }

            if ($enableResult) {
                Write-Host $enableResult -ForegroundColor Red
                $failed = $true
            }
        }
        else {
            Write-Host ""
            $failed = $true
        }
    }

    if (-not $failed) {
        try {
            $result = Invoke-NonBlocking -TimeoutSeconds 90 -ScriptBlock {
                # Ensure the module is loaded in case this runs in a separate runspace
                Import-Module Microsoft.PowerShell.Management -ErrorAction SilentlyContinue

                try {
                    # Use SilentlyContinue so that the common "no restore points exist" case
                    # simply returns $null instead of throwing. This avoids relying on fragile
                    # exception-message matching for a benign condition.
                    $recentRestorePoints = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) })
                }
                catch {
                    return [PSCustomObject]@{ Success = $false; Message = "Error: Unable to retrieve existing restore points: $($_.Exception.Message)" }
                }

                if ($recentRestorePoints.Count -eq 0) {
                    try {
                        Checkpoint-Computer -Description "Restore point created by Win11Debloat" -RestorePointType "MODIFY_SETTINGS"
                        return [PSCustomObject]@{ Success = $true; Message = "System restore point created successfully" }
                    }
                    catch {
                        return [PSCustomObject]@{ Success = $false; Message = "Error: Unable to create restore point: $_" }
                    }
                }
                else {
                    return [PSCustomObject]@{ Success = $true; Message = "A recent restore point already exists, no new restore point was created" }
                }
            }
        }
        catch {
            $result = [PSCustomObject]@{ Success = $false; Message = "Error: Failed to create system restore point: $_" }
        }

        if ($result -and $result.Success) {
            Write-Host $result.Message
        }
        elseif ($result) {
            Write-Host $result.Message -ForegroundColor Red
            $failed = $true
        }
        else {
            Write-Host "Error: Failed to create system restore point" -ForegroundColor Red
            $failed = $true
        }
    }

    # Ensure that the user is aware if creating a restore point failed, and give them the option to continue without a restore point or cancel the script
    if ($failed) {
        if ($script:GuiWindow) {
            $result = Show-MessageBox "Failed to create a system restore point. Do you want to continue without a restore point?" "Restore Point Creation Failed" "YesNo" "Warning"

            if ($result -ne "Yes") {
                $script:CancelRequested = $true
                return
            }
        }
        elseif (-not $Silent) {
            Write-Host "Failed to create a system restore point. Do you want to continue without a restore point? (y/n)" -ForegroundColor Yellow
            if ($( Read-Host ) -ne 'y') {
                $script:CancelRequested = $true
                return
            }
        }

        Write-Host "Warning: Continuing without restore point" -ForegroundColor Yellow
    }
}
