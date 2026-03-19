# Import & execute regfile
function ImportRegistryFile {
    param (
        $message,
        $path
    )

    Write-Host $message

    $usesOfflineHive = $script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")
    $regFilePath = if ($usesOfflineHive) {
        "$script:RegfilesPath\Sysprep\$path"
    }
    else {
        "$script:RegfilesPath\$path"
    }

    if (-not (Test-Path $regFilePath)) {
        $errorMessage = "Unable to find registry file: $path ($regFilePath)"
        Write-Host "Error: $errorMessage" -ForegroundColor Red
        Write-Host ""
        throw $errorMessage
    }

    # Reset exit code before running reg.exe for reliable success detection
    $global:LASTEXITCODE = 0

    if ($usesOfflineHive) {
        # Sysprep targets Default user, User targets the specified user
        $hiveDatPath = if ($script:Params.ContainsKey("Sysprep")) {
            GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"
        } else {
            GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"
        }

        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($hivePath, $targetRegFilePath)
            $result = @{
                Output = @()
                ExitCode = 0
                Error = $null
            }

            try {
                $global:LASTEXITCODE = 0
                reg load "HKU\Default" $hivePath | Out-Null
                $loadExitCode = $LASTEXITCODE

                if ($loadExitCode -ne 0) {
                    throw "Failed to load user hive at '$hivePath' (exit code: $loadExitCode)"
                }

                $output = reg import $targetRegFilePath 2>&1
                $importExitCode = $LASTEXITCODE

                if ($output) {
                    $result.Output = @($output)
                }
                $result.ExitCode = $importExitCode

                if ($importExitCode -ne 0) {
                    throw "Registry import failed with exit code $importExitCode for '$targetRegFilePath'"
                }
            }
            catch {
                $result.Error = $_.Exception.Message
                $result.ExitCode = if ($LASTEXITCODE -ne 0) { $LASTEXITCODE } else { 1 }
            }
            finally {
                $global:LASTEXITCODE = 0
                reg unload "HKU\Default" | Out-Null
                $unloadExitCode = $LASTEXITCODE
                if ($unloadExitCode -ne 0 -and -not $result.Error) {
                    $result.Error = "Failed to unload temporary hive HKU\\Default (exit code: $unloadExitCode)"
                    $result.ExitCode = $unloadExitCode
                }
            }

            return $result
        } -ArgumentList @($hiveDatPath, $regFilePath)
    }
    else {
        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($targetRegFilePath)
            $global:LASTEXITCODE = 0
            $output = reg import $targetRegFilePath 2>&1
            return @{ Output = @($output); ExitCode = $LASTEXITCODE; Error = $null }
        } -ArgumentList $regFilePath
    }

    $regOutput = @($regResult.Output)
    $hasSuccess = ($regResult.ExitCode -eq 0) -and -not $regResult.Error
    
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
        $details = if ($regResult.Error) { $regResult.Error } else { "Exit code: $($regResult.ExitCode)" }
        $errorMessage = "Failed importing registry file '$path'. $details"
        Write-Host $errorMessage -ForegroundColor Red
        Write-Host ""
        throw $errorMessage
    }

    Write-Host ""
}