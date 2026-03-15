# Runs a scriptblock in a background PowerShell runspace while keeping the UI responsive.
# In GUI mode, the work executes on a separate thread and the UI thread pumps messages (~60fps).
# In CLI mode, the scriptblock runs directly in the current session.
function Invoke-NonBlocking {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @(),
        [int]$TimeoutSeconds = 0
    )

    # CLI mode without timeout: run directly in-process
    if (-not $script:GuiWindow -and $TimeoutSeconds -eq 0) {
        return (& $ScriptBlock @ArgumentList)
    }

    $ps = [powershell]::Create()
    try {
        $null = $ps.AddScript($ScriptBlock.ToString())
        foreach ($arg in $ArgumentList) {
            $null = $ps.AddArgument($arg)
        }

        $handle = $ps.BeginInvoke()

        if ($script:GuiWindow) {
            # GUI mode: pump UI messages while waiting
            $stopwatch = if ($TimeoutSeconds -gt 0) { [System.Diagnostics.Stopwatch]::StartNew() } else { $null }

            while (-not $handle.IsCompleted) {
                if ($stopwatch -and $stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                    $ps.Stop()
                    throw "Operation timed out after $TimeoutSeconds seconds"
                }
                DoEvents
                Start-Sleep -Milliseconds 16
            }
        }
        else {
            # CLI mode with timeout: block until completion or timeout
            if (-not $handle.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000)) {
                $ps.Stop()
                throw "Operation timed out after $TimeoutSeconds seconds"
            }
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
