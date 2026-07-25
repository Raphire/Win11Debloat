BeforeAll {
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) }

    . (Join-Path $PSScriptRoot '..\Scripts\Features\Telemetry-ScheduledTasks.ps1')
}

Describe 'Get-TelemetryScheduledTasks' {
    It 'returns the expected telemetry task catalog' {
        $tasks = @(Get-TelemetryScheduledTasks)

        $tasks.Count | Should -Be 8
        @($tasks | ForEach-Object { "$($_.Path)|$($_.Name)" }) | Should -Be @(
            '\Microsoft\Windows\Application Experience\|Microsoft Compatibility Appraiser'
            '\Microsoft\Windows\Application Experience\|Microsoft Compatibility Appraiser Exp'
            '\Microsoft\Windows\Application Experience\|ProgramDataUpdater'
            '\Microsoft\Windows\Application Experience\|StartupAppTask'
            '\Microsoft\Windows\Customer Experience Improvement Program\|Consolidator'
            '\Microsoft\Windows\Customer Experience Improvement Program\|UsbCeip'
            '\Microsoft\Windows\DiskDiagnostic\|Microsoft-Windows-DiskDiagnosticDataCollector'
            '\Microsoft\Windows\Autochk\|Proxy'
        )
    }
}

Describe 'Disable-TelemetryScheduledTasks' {
    BeforeEach {
        $script:Params = @{}
        $script:CancelRequested = $false
        Mock Get-TelemetryScheduledTasks {
            @(
                @{ Path = '\Microsoft\Windows\Test\'; Name = 'First' }
                @{ Path = '\Microsoft\Windows\Test\'; Name = 'Second' }
            )
        }
        Mock Invoke-NonBlocking { @{ Success = $true; Status = 'Disabled' } }
        Mock Write-Host {}
    }

    It 'dispatches every task to the non-blocking scheduler' {
        Disable-TelemetryScheduledTasks

        Should -Invoke Invoke-NonBlocking -Times 2 -Exactly
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter {
            $ArgumentList[0] -eq '\Microsoft\Windows\Test\' -and $ArgumentList[1] -eq 'First'
        }
    }

    It 'does not schedule work after cancellation' {
        $script:CancelRequested = $true

        Disable-TelemetryScheduledTasks

        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'does not schedule task changes in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }

        Disable-TelemetryScheduledTasks

        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'disables an enabled task inside the scheduled script block' {
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:taskBlock = $ScriptBlock
            $script:taskArguments = $ArgumentList
        }
        Mock Import-Module {}
        Mock Get-ScheduledTask { [PSCustomObject]@{ State = 'Ready' } }
        Mock Disable-ScheduledTask {}

        Disable-TelemetryScheduledTasks
        $result = & $script:taskBlock @script:taskArguments

        $result.Status | Should -Be 'Disabled'
        Should -Invoke Disable-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskPath -eq '\Microsoft\Windows\Test\' -and $TaskName -eq 'Second' }
    }

    It 'reports an error returned by the scheduled script block' {
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:taskBlock = $ScriptBlock
            $script:taskArguments = $ArgumentList
        }
        Mock Import-Module {}
        Mock Get-ScheduledTask { [PSCustomObject]@{ State = 'Ready' } }
        Mock Disable-ScheduledTask { throw 'access denied' }

        Disable-TelemetryScheduledTasks
        $result = & $script:taskBlock @script:taskArguments

        $result.Status | Should -Be 'Error'
        $result.Error | Should -Match 'access denied'
    }

    It 'reports <Status> task results' -ForEach @(
        @{ Status = 'Disabled'; Expected = 'Disabled Scheduled Task' }
        @{ Status = 'AlreadyDisabled'; Expected = 'already disabled' }
        @{ Status = 'NotFound'; Expected = 'not found' }
        @{ Status = 'Error'; Expected = 'Failed to disable Scheduled Task' }
    ) {
        Mock Get-TelemetryScheduledTasks { @(@{ Path = '\Microsoft\Windows\Test\'; Name = 'Telemetry' }) }
        Mock Invoke-NonBlocking { @{ Success = $Status -ne 'Error'; Status = $Status; Error = 'denied' } }

        Disable-TelemetryScheduledTasks

        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like "*$Expected*" }
    }
}

Describe 'Enable-TelemetryScheduledTasks' {
    BeforeEach {
        $script:Params = @{}
        $script:CancelRequested = $false
        Mock Get-TelemetryScheduledTasks {
            @(
                @{ Path = '\Microsoft\Windows\Test\'; Name = 'First' }
                @{ Path = '\Microsoft\Windows\Test\'; Name = 'Second' }
            )
        }
        Mock Invoke-NonBlocking { @{ Success = $true; Status = 'Enabled' } }
        Mock Write-Host {}
    }

    It 'dispatches every task to the non-blocking scheduler' {
        Enable-TelemetryScheduledTasks

        Should -Invoke Invoke-NonBlocking -Times 2 -Exactly
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter {
            $ArgumentList[0] -eq '\Microsoft\Windows\Test\' -and $ArgumentList[1] -eq 'First'
        }
    }

    It 'does not schedule work after cancellation' {
        $script:CancelRequested = $true

        Enable-TelemetryScheduledTasks

        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'does not schedule task changes in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }

        Enable-TelemetryScheduledTasks

        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'enables a disabled task inside the scheduled script block' {
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:taskBlock = $ScriptBlock
            $script:taskArguments = $ArgumentList
        }
        Mock Import-Module {}
        Mock Get-ScheduledTask { [PSCustomObject]@{ State = 'Disabled' } }
        Mock Enable-ScheduledTask {}

        Enable-TelemetryScheduledTasks
        $result = & $script:taskBlock @script:taskArguments

        $result.Status | Should -Be 'Enabled'
        Should -Invoke Enable-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskPath -eq '\Microsoft\Windows\Test\' -and $TaskName -eq 'Second' }
    }

    It 'reports <Status> task results' -ForEach @(
        @{ Status = 'Enabled'; Expected = 'Enabled Scheduled Task' }
        @{ Status = 'AlreadyEnabled'; Expected = 'already enabled' }
        @{ Status = 'NotFound'; Expected = 'not found' }
        @{ Status = 'Error'; Expected = 'Failed to enable Scheduled Task' }
    ) {
        Mock Get-TelemetryScheduledTasks { @(@{ Path = '\Microsoft\Windows\Test\'; Name = 'Telemetry' }) }
        Mock Invoke-NonBlocking { @{ Success = $Status -ne 'Error'; Status = $Status; Error = 'denied' } }

        Enable-TelemetryScheduledTasks

        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like "*$Expected*" }
    }
}
