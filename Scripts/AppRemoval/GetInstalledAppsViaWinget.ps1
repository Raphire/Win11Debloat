<#
    .SYNOPSIS
    Returns a list of installed apps from winget as structured objects.

    .DESCRIPTION
    Runs `winget list` and parses the output into PSCustomObject arrays.
    Use -NonBlocking to keep the UI responsive in GUI mode; otherwise
    runs synchronously with an optional timeout.

    .PARAMETER TimeOut
    Maximum seconds to wait for winget to complete. Default is 10.

    .PARAMETER NonBlocking
    When set, runs via Invoke-NonBlocking so the GUI thread stays responsive.

    .OUTPUTS
    PSCustomObject[] with Name and Id properties. Returns $null on
    failure, or an empty array when winget succeeds but lists no apps.
#>
function GetInstalledAppsViaWinget {
    param (
        [int]$TimeOut = 10,
        [switch]$NonBlocking
    )

    if (-not $script:WingetInstalled) { return $null }

    $fetchBlock = {
        param($timeOut)
        $job = Start-Job {
            $rawOutput = $null
            try {
                $originalEncoding = [Console]::OutputEncoding
                [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
                try {
                    $rawOutput = winget list --accept-source-agreements --disable-interactivity
                }
                finally {
                    [Console]::OutputEncoding = $originalEncoding
                }
                return $rawOutput
            }
            catch {
                return $null
            }
        }

        $done = $job | Wait-Job -Timeout $timeOut
        if ($done) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job -ErrorAction SilentlyContinue

            if (-not $result) { return $null }

            # winget list outputs:
            #   [progress line] / [blank] / header / --- separator / data rows
            $textOutput = $result -join "`n"
            $lines = $textOutput -split "`r`n|`n"

            # Find the separator line to know where data starts
            $dataStart = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '^-{3,}') {
                    $dataStart = $i + 1
                    break
                }
            }

            if ($dataStart -lt 0 -or $dataStart -ge $lines.Count) { return @() }

            $apps = [System.Collections.Generic.List[object]]::new()

            for ($i = $dataStart; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line.Trim() -eq '') { continue }

                try {
                    # Split on 2+ spaces; extract Name and Id columns.
                    $fields = [regex]::Split($line.Trim(), '\s{2,}')
                    if ($fields.Count -lt 2) { continue }

                    $name = $fields[0].Trim()
                    $id   = $fields[1].Trim()

                    if (-not $id) { continue }

                    $null = $apps.Add([PSCustomObject]@{
                        Name = $name
                        Id   = $id
                    })
                }
                catch {
                    # Skip lines that can't be parsed
                }
            }

            return @($apps)
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