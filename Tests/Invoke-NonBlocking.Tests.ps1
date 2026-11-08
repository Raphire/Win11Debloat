BeforeAll {
    function Invoke-DoEvents {}
    . (Join-Path $PSScriptRoot '..\Scripts\Threading\Invoke-NonBlocking.ps1')
}

Describe 'Invoke-NonBlocking' {
    BeforeEach { $script:GuiWindow = $null }

    It 'runs directly in CLI mode without a timeout and preserves a scalar result' {
        Invoke-NonBlocking -ScriptBlock { param($Value) "result-$Value" } -ArgumentList 'one' | Should -Be 'result-one'
    }

    It 'runs directly in CLI mode without a timeout and preserves multiple results' {
        $result = @(Invoke-NonBlocking -ScriptBlock { 1; 2; 3 })
        $result | Should -Be @(1, 2, 3)
    }

    It 'stops a timed GUI operation and reports a timeout' {
        $script:GuiWindow = [PSCustomObject]@{}
        Mock Invoke-DoEvents {}

        { Invoke-NonBlocking -ScriptBlock { Start-Sleep -Seconds 3 } -TimeoutSeconds 1 } |
            Should -Throw 'Operation timed out after 1 seconds'
    }

    It 'uses a runspace and pumps UI events when a GUI window is present' {
        $script:GuiWindow = [PSCustomObject]@{}
        $gate = [System.Threading.ManualResetEventSlim]::new($false)
        Mock Invoke-DoEvents { $gate.Set() }

        try {
            $result = Invoke-NonBlocking -ScriptBlock {
                param($Event)
                if (-not $Event.Wait(5000)) { throw 'UI events were not pumped' }
                [System.Threading.Thread]::CurrentThread.ManagedThreadId
            } -ArgumentList @($gate) -TimeoutSeconds 5

            $result | Should -BeOfType ([int])
            $result | Should -Not -Be ([System.Threading.Thread]::CurrentThread.ManagedThreadId)
            Should -Invoke Invoke-DoEvents -Times 1
        }
        finally {
            $gate.Dispose()
        }
    }

    It 'surfaces non-terminating errors from a runspace' {
        $script:GuiWindow = [PSCustomObject]@{}
        Mock Invoke-DoEvents {}
        Mock Write-Error {}

        Invoke-NonBlocking -ScriptBlock { Write-Error 'runspace failure' }

        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter { $ErrorRecord.Exception.Message -match 'runspace failure' }
    }

    It 'stops a timed CLI operation, reports a timeout, and remains usable afterward' {
        { Invoke-NonBlocking -ScriptBlock { Start-Sleep -Seconds 3 } -TimeoutSeconds 1 } |
            Should -Throw 'Operation timed out after 1 seconds'

        Invoke-NonBlocking -ScriptBlock { 'next operation' } -TimeoutSeconds 5 | Should -Be 'next operation'
    }
}
