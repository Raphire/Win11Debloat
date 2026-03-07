# Import & execute regfile
function ImportRegistryFile {
    param (
        $message,
        $path
    )

    Write-Host $message

    # Validate that the regfile exists in both locations
    if (-not (Test-Path "$script:RegfilesPath\$path") -or -not (Test-Path "$script:RegfilesPath\Sysprep\$path")) {
        Write-Host "Error: Unable to find registry file: $path" -ForegroundColor Red
        Write-Host ""
        return
    }

    # Reset exit code before running reg.exe for reliable success detection
    $global:LASTEXITCODE = 0

    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")) {
        # Sysprep targets Default user, User targets the specified user
        $hiveDatPath = if ($script:Params.ContainsKey("Sysprep")) {
            GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"
        } else {
            GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"
        }

        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($datPath, $regFilePath)
            $global:LASTEXITCODE = 0
            reg load "HKU\Default" $datPath | Out-Null
            $output = reg import $regFilePath 2>&1
            $code = $LASTEXITCODE
            reg unload "HKU\Default" | Out-Null
            return @{ Output = $output; ExitCode = $code }
        } -ArgumentList @($hiveDatPath, "$script:RegfilesPath\Sysprep\$path")
    }
    else {
        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($regFilePath)
            $global:LASTEXITCODE = 0
            $output = reg import $regFilePath 2>&1
            return @{ Output = $output; ExitCode = $LASTEXITCODE }
        } -ArgumentList "$script:RegfilesPath\$path"
    }

    $regOutput = $regResult.Output
    $hasSuccess = $regResult.ExitCode -eq 0
    
    if ($regOutput) {
        foreach ($line in $regOutput) {
            $lineText = if ($line -is [System.Management.Automation.ErrorRecord]) { $line.Exception.Message } else { $line.ToString() }
            if ($lineText -and $lineText.Length -gt 0) {
                if ($hasSuccess) {
                    Write-Host $lineText
                }
                else {
                    Write-Host $lineText -ForegroundColor Red
                }
            }
        }
    }

    if (-not $hasSuccess) {
        Write-Host "Failed importing registry file: $path" -ForegroundColor Red
    }

    Write-Host ""
}