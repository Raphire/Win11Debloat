function Wait-ForKeyPress {
    param(
        [int]$ExitCode = 0
    )

    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = [System.Console]::ReadKey()
    }

    Stop-Transcript
    Exit $ExitCode
}
