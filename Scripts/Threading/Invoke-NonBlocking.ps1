# Runs a scriptblock in a background PowerShell runspace while keeping the UI responsive.
# In GUI mode, the work executes on a separate thread and the UI thread pumps messages (~60fps).
# In CLI mode, the scriptblock runs directly in the current session.
function Invoke-NonBlocking {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @()
    )

    if (-not $script:GuiWindow) {
        return (& $ScriptBlock @ArgumentList)
    }

    $ps = [powershell]::Create()
    try {
        $null = $ps.AddScript($ScriptBlock.ToString())
        foreach ($arg in $ArgumentList) {
            $null = $ps.AddArgument($arg)
        }

        $handle = $ps.BeginInvoke()

        while (-not $handle.IsCompleted) {
            DoEvents
            Start-Sleep -Milliseconds 16
        }

        $result = $ps.EndInvoke($handle)

        if ($result.Count -eq 0) { return $null }
        if ($result.Count -eq 1) { return $result[0] }
        return @($result)
    }
    finally {
        $ps.Dispose()
    }
}
