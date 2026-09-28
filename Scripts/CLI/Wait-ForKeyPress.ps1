<#
    .SYNOPSIS
    Waits for user acknowledgement, then exits the script.

    .PARAMETER ExitCode
    Process exit code to return after acknowledgement. Defaults to 0.
#>
function Wait-ForKeyPress {
    param(
        [int]$ExitCode = 0
    )

    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "按任意键退出……"
        $null = [System.Console]::ReadKey()
    }

    Stop-Transcript
    Exit $ExitCode
}
