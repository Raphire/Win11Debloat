function Disable-ScheduledTaskSafe {
    param (
        [Parameter(Mandatory)]
        [string]$TaskPath,
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    if ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference) {
        Write-Host "[WhatIf] Disable Scheduled Task: $TaskPath$TaskName" -ForegroundColor Cyan
        return $true
    }

    Invoke-NonBlocking -ScriptBlock {
        param($path, $name)
        if (Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue) {
            Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue | Out-Null
            return $true
        }
        return $false
    } -ArgumentList @($TaskPath, $TaskName)
}

function Enable-ScheduledTaskSafe {
    param (
        [Parameter(Mandatory)]
        [string]$TaskPath,
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    if ($PSBoundParameters.ContainsKey('WhatIf') -or $WhatIfPreference) {
        Write-Host "[WhatIf] Enable Scheduled Task: $TaskPath$TaskName" -ForegroundColor Cyan
        return $true
    }

    Invoke-NonBlocking -ScriptBlock {
        param($path, $name)
        if (Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue) {
            Enable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue | Out-Null
            return $true
        }
        return $false
    } -ArgumentList @($TaskPath, $TaskName)
}

function Get-TelemetryScheduledTasks {
    return @(
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "Microsoft Compatibility Appraiser" },
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "ProgramDataUpdater" },
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "StartupAppScan" },
        @{ Path = "\Microsoft\Windows\Application Experience"; Name = "StartupAppTask" },
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program"; Name = "Consolidator" },
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program"; Name = "UsbCeip" },
        @{ Path = "\Microsoft\Windows\DiskDiagnostic"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" },
        @{ Path = "\Microsoft\Windows\Autochk"; Name = "Proxy" }
    )
}
