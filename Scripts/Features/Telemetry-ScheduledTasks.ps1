. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

# List of known Windows telemetry-related scheduled tasks
<#
    .SYNOPSIS
    Returns the list of known Windows telemetry-related scheduled tasks.

    .DESCRIPTION
    Returns an array of hashtables, each with a Path and Name key, representing
    scheduled tasks that collect or report telemetry data on Windows.

    .EXAMPLE
    Get-TelemetryScheduledTasks
#>
function Get-TelemetryScheduledTasks {
    return @(
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" },
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser Exp" },
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" },
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "StartupAppTask" },
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" },
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "UsbCeip" },
        @{ Path = "\Microsoft\Windows\DiskDiagnostic\"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" },
        @{ Path = "\Microsoft\Windows\Autochk\"; Name = "Proxy" }
    )
}

<#
    .SYNOPSIS
    Disables known Windows telemetry-related scheduled tasks.

    .DESCRIPTION
    Iterates over a predefined list of Windows scheduled tasks associated with
    telemetry and disables each one that exists and is not already disabled.
    Supports -WhatIf to preview changes without applying them.

    .EXAMPLE
    Disable-TelemetryScheduledTasks

    .OUTPUTS
    System.Boolean. $true when every task is disabled, absent, already disabled, or previewed; otherwise $false.
#>
function Disable-TelemetryScheduledTasks {
    Write-Host (Get-ConsoleTranslation -Text '> Disabling telemetry scheduled tasks...')
    $tasks = Get-TelemetryScheduledTasks

    $success = $true
    foreach ($task in $tasks) {
        if ($script:CancelRequested) { return $false }

        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host (Get-ConsoleTranslation -Text '[WhatIf] Disable Scheduled Task: {0}{1}' -FormatArgs @($($task.Path), $($task.Name))) -ForegroundColor Cyan
            continue
        }

        try {
            $result = Invoke-NonBlocking -ScriptBlock {
                param($path, $name)
                try {
                    Import-Module ScheduledTasks -ErrorAction Stop
                    $taskObj = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop
                }
                catch {
                    if ($_.Exception -isnot [System.Management.Automation.CommandNotFoundException] -and $_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ObjectNotFound) {
                        return @{ Success = $true; Status = 'NotFound' }
                    }
                    return @{ Success = $false; Status = 'Error'; Error = $_.Exception.Message }
                }
                if (-not $taskObj) {
                    return @{ Success = $true; Status = 'NotFound' }
                }
                if ($taskObj.State -ne 'Disabled') {
                    try {
                        Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
                        return @{ Success = $true; Status = 'Disabled' }
                    }
                    catch {
                        return @{ Success = $false; Status = 'Error'; Error = $_.Exception.Message }
                    }
                }
                return @{ Success = $true; Status = 'AlreadyDisabled' }
            } -ArgumentList @($task.Path, $task.Name)
        }
        catch {
            Write-Warning (Get-ConsoleTranslation -Text 'Failed to disable Scheduled Task: {0}{1} - {2}' -FormatArgs @($($task.Path), $($task.Name), $($_.Exception.Message)))
            $success = $false
            continue
        }

        switch ($result.Status) {
            'Disabled'        { Write-Host (Get-ConsoleTranslation -Text 'Disabled Scheduled Task: {0}{1}' -FormatArgs @($($task.Path), $($task.Name))) }
            'AlreadyDisabled' { Write-Host (Get-ConsoleTranslation -Text 'Scheduled Task {0}{1} is already disabled' -FormatArgs @($($task.Path), $($task.Name))) -ForegroundColor DarkGray }
            'NotFound'        { Write-Host (Get-ConsoleTranslation -Text 'Scheduled Task {0}{1} not found' -FormatArgs @($($task.Path), $($task.Name))) -ForegroundColor DarkGray }
            'Error'           { Write-Host (Get-ConsoleTranslation -Text 'Failed to disable Scheduled Task: {0}{1} - {2}' -FormatArgs @($($task.Path), $($task.Name), $($result.Error))) -ForegroundColor Yellow; $success = $false }
            default           { Write-Warning (Get-ConsoleTranslation -Text 'Unable to determine the result of disabling Scheduled Task: {0}{1}.' -FormatArgs @($($task.Path), $($task.Name))); $success = $false }
        }
    }

    return $success
}

<#
    .SYNOPSIS
    Enables known Windows telemetry-related scheduled tasks.

    .DESCRIPTION
    Iterates over a predefined list of Windows scheduled tasks associated with
    telemetry and enables each one that exists and is currently disabled.
    Supports -WhatIf to preview changes without applying them.

    .EXAMPLE
    Enable-TelemetryScheduledTasks

    .OUTPUTS
    System.Boolean. $true when every task is enabled, absent, already enabled, or previewed; otherwise $false.
#>
function Enable-TelemetryScheduledTasks {
    Write-Host (Get-ConsoleTranslation -Text '> Enabling telemetry scheduled tasks...')
    $tasks = Get-TelemetryScheduledTasks

    $success = $true
    foreach ($task in $tasks) {
        if ($script:CancelRequested) { return $false }

        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host (Get-ConsoleTranslation -Text '[WhatIf] Enable Scheduled Task: {0}{1}' -FormatArgs @($($task.Path), $($task.Name))) -ForegroundColor Cyan
            continue
        }

        try {
            $result = Invoke-NonBlocking -ScriptBlock {
                param($path, $name)
                try {
                    Import-Module ScheduledTasks -ErrorAction Stop
                    $taskObj = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop
                }
                catch {
                    if ($_.Exception -isnot [System.Management.Automation.CommandNotFoundException] -and $_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::ObjectNotFound) {
                        return @{ Success = $true; Status = 'NotFound' }
                    }
                    return @{ Success = $false; Status = 'Error'; Error = $_.Exception.Message }
                }
                if (-not $taskObj) {
                    return @{ Success = $true; Status = 'NotFound' }
                }
                if ($taskObj.State -eq 'Disabled') {
                    try {
                        Enable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
                        return @{ Success = $true; Status = 'Enabled' }
                    }
                    catch {
                        return @{ Success = $false; Status = 'Error'; Error = $_.Exception.Message }
                    }
                }
            return @{ Success = $true; Status = 'AlreadyEnabled' }
            } -ArgumentList @($task.Path, $task.Name)
        }
        catch {
            Write-Warning (Get-ConsoleTranslation -Text 'Failed to enable Scheduled Task: {0}{1} - {2}' -FormatArgs @($($task.Path), $($task.Name), $($_.Exception.Message)))
            $success = $false
            continue
        }

        switch ($result.Status) {
            'Enabled'        { Write-Host (Get-ConsoleTranslation -Text 'Enabled Scheduled Task: {0}{1}' -FormatArgs @($($task.Path), $($task.Name))) }
            'AlreadyEnabled' { Write-Host (Get-ConsoleTranslation -Text 'Scheduled Task {0}{1} is already enabled.' -FormatArgs @($($task.Path), $($task.Name))) -ForegroundColor DarkGray }
            'NotFound'       { Write-Host (Get-ConsoleTranslation -Text 'Scheduled Task {0}{1} not found.' -FormatArgs @($($task.Path), $($task.Name))) -ForegroundColor DarkGray }
            'Error'          { Write-Host (Get-ConsoleTranslation -Text 'Failed to enable Scheduled Task: {0}{1} - {2}' -FormatArgs @($($task.Path), $($task.Name), $($result.Error))) -ForegroundColor Yellow; $success = $false }
            default          { Write-Warning (Get-ConsoleTranslation -Text 'Unable to determine the result of enabling Scheduled Task: {0}{1}.' -FormatArgs @($($task.Path), $($task.Name))); $success = $false }
        }
    }

    return $success
}
