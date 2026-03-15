
# Run winget list and return installed apps.
# Use -NonBlocking to keep the UI responsive (GUI mode) via Invoke-NonBlocking.
function GetInstalledAppsViaWinget {
    param (
        [int]$TimeOut = 10,
        [switch]$NonBlocking
    )

    if (-not $script:WingetInstalled) { return $null }

    $fetchBlock = {
        param($timeOut)
        $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
        $done = $job | Wait-Job -Timeout $timeOut
        if ($done) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job -ErrorAction SilentlyContinue
            return $result
        }
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return $null
    }

    if ($NonBlocking) {
        return Invoke-NonBlocking -ScriptBlock $fetchBlock -ArgumentList $TimeOut
    }
    else {
        return & $fetchBlock $TimeOut
    }
}