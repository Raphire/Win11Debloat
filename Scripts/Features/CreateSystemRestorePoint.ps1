function CreateSystemRestorePoint {
    $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval"
    $failed = $false

    if ($SysRestore.RPSessionInterval -eq 0) {
        # In GUI mode, skip the prompt and just try to enable it
        if ($script:GuiWindow -or $Silent -or $( Read-Host -Prompt "System restore is disabled, would you like to enable it and create a restore point? (y/n)") -eq 'y') {
            $enableSystemRestoreJob = Start-Job {
                try {
                    Enable-ComputerRestore -Drive "$env:SystemDrive"
                }
                catch {
                    return "Error: Failed to enable System Restore: $_"
                }
                return $null
            }

            $enableSystemRestoreJobDone = $enableSystemRestoreJob | Wait-Job -TimeOut 20

            if (-not $enableSystemRestoreJobDone) {
                Remove-Job -Job $enableSystemRestoreJob -Force -ErrorAction SilentlyContinue
                Write-Host "Error: Failed to enable system restore and create restore point, operation timed out" -ForegroundColor Red
                $failed = $true
            }
            else {
                $result = Receive-Job $enableSystemRestoreJob
                Remove-Job -Job $enableSystemRestoreJob -ErrorAction SilentlyContinue
                if ($result) {
                    Write-Host $result -ForegroundColor Red
                    $failed = $true
                }
            }
        }
        else {
            Write-Host ""
            $failed = $true
        }
    }

    if (-not $failed) {
        $createRestorePointJob = Start-Job {
            # Find existing restore points that are less than 24 hours old
            try {
                $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
            }
            catch {
                return @{ Success = $false; Message = "Error: Unable to retrieve existing restore points: $_" }
            }

            if ($recentRestorePoints.Count -eq 0) {
                try {
                    Checkpoint-Computer -Description "Restore point created by Win11Debloat" -RestorePointType "MODIFY_SETTINGS"
                    return @{ Success = $true; Message = "System restore point created successfully" }
                }
                catch {
                    return @{ Success = $false; Message = "Error: Unable to create restore point: $_" }
                }
            }
            else {
                return @{ Success = $true; Message = "A recent restore point already exists, no new restore point was created" }
            }
        }

        $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 20

        if (-not $createRestorePointJobDone) {
            Remove-Job -Job $createRestorePointJob -Force -ErrorAction SilentlyContinue
            Write-Host "Error: Failed to create system restore point, operation timed out" -ForegroundColor Red
            $failed = $true
        }
        else {
            $result = Receive-Job $createRestorePointJob
            Remove-Job -Job $createRestorePointJob -ErrorAction SilentlyContinue
            if ($result.Success) {
                Write-Host $result.Message
            }
            else {
                Write-Host $result.Message -ForegroundColor Red
                $failed = $true
            }
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