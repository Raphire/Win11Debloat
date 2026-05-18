# Import & execute regfile
function ImportRegistryFile {
    param (
        $message,
        $path
    )

    Write-Host $message

    $usesOfflineHive = $script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")
    $regFileDirectory = if ($usesOfflineHive) {
        Join-Path $script:RegfilesPath "Sysprep"
    }
    else {
        $script:RegfilesPath
    }
    $regFilePath = Join-Path $regFileDirectory $path

    if (-not (Test-Path $regFilePath)) {
        $errorMessage = "Unable to find registry file: $path ($regFilePath)"
        Write-Host "Error: $errorMessage" -ForegroundColor Red
        Write-Host ""
        throw $errorMessage
    }

    $regResult = $null
    $offlineHiveLoaded = $false

    try {
        if ($usesOfflineHive) {
            # Sysprep targets Default user, User targets the specified user
            $targetUserName = if ($script:Params.ContainsKey("Sysprep")) { "Default" } else { $script:Params.Item("User") }
            $hiveDatPath = GetUserDirectory -userName $targetUserName -fileName "NTUSER.DAT"

            $global:LASTEXITCODE = 0
            reg load "HKU\Default" $hiveDatPath | Out-Null
            $loadExitCode = $LASTEXITCODE

            if ($loadExitCode -ne 0) {
                throw "Failed importing registry file '$path'. Offline hive load failed: Failed to load user hive at '$hiveDatPath' (exit code: $loadExitCode)"
            }

            $offlineHiveLoaded = $true
        }

        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($targetRegFilePath)
            $result = @{
                Output = @()
                ExitCode = 0
                Error = $null
            }

            try {
                $global:LASTEXITCODE = 0
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

            return $result
        } -ArgumentList $regFilePath

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
            Write-Warning "reg import failed for '$path'. Falling back to PowerShell registry writer. Details: $details"
            Invoke-RegistryOperationsFromRegFile -RegFilePath $regFilePath
            Write-Host "Fallback import succeeded for '$path'." -ForegroundColor Yellow
        }

        Write-Host ""
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        throw
    }
    finally {
        if ($offlineHiveLoaded) {
            $global:LASTEXITCODE = 0
            reg unload "HKU\Default" | Out-Null
            $unloadExitCode = $LASTEXITCODE

            if ($unloadExitCode -ne 0) {
                throw "Failed to unload registry hive HKU\Default after importing '$path' (exit code: $unloadExitCode)"
            }
        }
    }
}