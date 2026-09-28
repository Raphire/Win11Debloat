. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        执行脚本块，并在图形界面模式保持窗口响应。
    .DESCRIPTION
        命令行模式且未设置超时时在当前会话执行；图形界面模式或设置超时时
        使用独立后台会话，加载控制台翻译并传入当前控制台语言或界面语言，
        未设置语言时使用 en-US。图形界面等待期间持续处理窗口事件。
        超时会停止后台任务并抛出异常；后台非终止错误转发至调用方错误流，
        独立会话在 finally 中释放。
    .PARAMETER ScriptBlock
        要执行的脚本块；后台执行时需要显式传入所需参数或自行加载依赖。
    .PARAMETER ArgumentList
        按位置传入脚本块的参数数组。
    .PARAMETER TimeoutSeconds
        超时秒数，0 表示不设置超时；设置超时时应使用正整数。
    .OUTPUTS
        System.Object。脚本块结果；后台无输出时为 null，单个结果直接返回，
        多个结果作为集合返回。
#>
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
