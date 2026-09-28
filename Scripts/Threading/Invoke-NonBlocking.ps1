. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

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
        # 后台线程使用独立会话，需要显式传入语言和翻译函数。
        $translationScript = Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1'
        $languageCode = if ($script:ConsoleLanguageCode) { $script:ConsoleLanguageCode } elseif ($script:Lang) { $script:Lang.LanguageCode } else { 'en-US' }
        $worker = {
            param($translationScript, $languageCode, $body, $arguments)
            . $translationScript
            $script:ConsoleLanguageCode = $languageCode
            & ([scriptblock]::Create($body)) @arguments
        }
        $null = $ps.AddScript($worker.ToString()).AddArgument($translationScript).AddArgument($languageCode).AddArgument($ScriptBlock.ToString()).AddArgument($ArgumentList)

        $handle = $ps.BeginInvoke()

        if ($script:GuiWindow) {
            # GUI mode: pump UI messages while waiting
            $stopwatch = if ($TimeoutSeconds -gt 0) { [System.Diagnostics.Stopwatch]::StartNew() } else { $null }

            while (-not $handle.IsCompleted) {
                if ($stopwatch -and $stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                    $ps.Stop()
                    throw (Get-ConsoleTranslation -Text 'Operation timed out after {0} seconds' -FormatArgs @($TimeoutSeconds))
                }
                Invoke-DoEvents
                Start-Sleep -Milliseconds 16
            }
        }
        else {
            # CLI mode with timeout: block until completion or timeout
            if (-not $handle.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000)) {
                $ps.Stop()
                throw (Get-ConsoleTranslation -Text 'Operation timed out after {0} seconds' -FormatArgs @($TimeoutSeconds))
            }
        }

        $result = $ps.EndInvoke($handle)

        # Surface non-terminating errors raised inside the runspace so GUI-mode operations
        # (e.g. failed app removals) don't fail silently - the runspace keeps its own error
        # stream that is otherwise discarded on Dispose.
        if ($ps.HadErrors) {
            foreach ($runspaceError in $ps.Streams.Error) {
                Write-Error -ErrorRecord $runspaceError
            }
        }

        if ($result.Count -eq 0) { return $null }
        if ($result.Count -eq 1) { return $result[0] }
        return @($result)
    }
    finally {
        $ps.Dispose()
    }
}
