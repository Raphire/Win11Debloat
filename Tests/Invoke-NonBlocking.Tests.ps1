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

    It 'stops a timed CLI operation and reports a timeout' {
        { Invoke-NonBlocking -ScriptBlock { Start-Sleep -Seconds 3 } -TimeoutSeconds 1 } |
            Should -Throw 'Operation timed out after 1 seconds'
    }

    It 'stops a timed GUI operation and reports a timeout' {
        $script:GuiWindow = [PSCustomObject]@{}
        Mock Invoke-DoEvents {}

        { Invoke-NonBlocking -ScriptBlock { Start-Sleep -Seconds 3 } -TimeoutSeconds 1 } |
            Should -Throw 'Operation timed out after 1 seconds'
    }

    It 'uses a runspace and pumps UI events when a GUI window is present' {
        $script:GuiWindow = [PSCustomObject]@{}
        Mock Invoke-DoEvents {}

        $result = Invoke-NonBlocking -ScriptBlock { 'done' }
        $result | Should -Be 'done'

    }

    It 'surfaces non-terminating errors from a runspace' {
        $script:GuiWindow = [PSCustomObject]@{}
        Mock Invoke-DoEvents {}
        Mock Write-Error {}

        Invoke-NonBlocking -ScriptBlock { Write-Error 'runspace failure' }

        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter { $ErrorRecord.Exception.Message -match 'runspace failure' }
    }

    It 'remains usable after a timed operation is stopped' {
        { Invoke-NonBlocking -ScriptBlock { Start-Sleep -Seconds 3 } -TimeoutSeconds 1 } |
            Should -Throw 'Operation timed out after 1 seconds'

        Invoke-NonBlocking -ScriptBlock { 'next operation' } | Should -Be 'next operation'
    }
}
