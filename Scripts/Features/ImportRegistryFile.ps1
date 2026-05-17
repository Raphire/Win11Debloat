# Import & execute regfile
function ImportRegistryFile {
    param (
        $message,
        $path
    )

    Write-Host $message

    $usesOfflineHive = $script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")
    $hiveDatPath = $null
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
                FailureStage = $null
                HiveLeftLoaded = $false
            }
            $hiveLoaded = $false

            try {
                $global:LASTEXITCODE = 0
                reg load "HKU\Default" $hivePath | Out-Null
                $loadExitCode = $LASTEXITCODE

                if ($loadExitCode -ne 0) {
                    $result.FailureStage = 'load'
                    throw "Failed to load user hive at '$hivePath' (exit code: $loadExitCode)"
                }

                $hiveLoaded = $true

                $output = reg import $targetRegFilePath 2>&1
                $importExitCode = $LASTEXITCODE

                if ($output) {
                    $result.Output = @($output)
                }
                $result.ExitCode = $importExitCode

                if ($importExitCode -ne 0) {
                    $result.FailureStage = 'import'
                    throw "Registry import failed with exit code $importExitCode for '$targetRegFilePath'"
                }
            }
            catch {
                if (-not $result.FailureStage) {
                    $result.FailureStage = 'unknown'
                }
                $result.Error = $_.Exception.Message
                $result.ExitCode = if ($LASTEXITCODE -ne 0) { $LASTEXITCODE } else { 1 }
            }
            finally {
                # When import failed the hive stays mounted so the PowerShell
                # fallback can reuse it immediately without a load/unload race.
                if ($hiveLoaded -and $result.FailureStage -eq 'import') {
                    $result.HiveLeftLoaded = $true
                }
                elseif ($hiveLoaded) {
                    $global:LASTEXITCODE = 0
                    reg unload "HKU\Default" | Out-Null
                    $unloadExitCode = $LASTEXITCODE
                    if ($unloadExitCode -ne 0 -and -not $result.Error) {
                        $result.FailureStage = 'unload'
                        $result.Error = "Failed to unload registry hive HKU\Default (exit code: $unloadExitCode)"
                        $result.ExitCode = $unloadExitCode
                    }
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

        # Fallback only helps when the import step failed. If load/unload failed,
        # retrying fallback will hit the same hive-state problem and adds noisy errors.
        if ($usesOfflineHive -and ($regResult.FailureStage -eq 'load' -or $regResult.FailureStage -eq 'unload')) {
            $errorMessage = "Failed importing registry file '$path'. Offline hive $($regResult.FailureStage) failed: $details. Skipping PowerShell fallback because it requires loading the same hive state."
            Write-Host $errorMessage -ForegroundColor Red
            Write-Host ""
            throw $errorMessage
        }

        Write-Warning "reg import failed for '$path'. Falling back to PowerShell registry writer. Details: $details"

        try {
            Invoke-RegistryImportViaPowerShell -RegFilePath $regFilePath -UseOfflineHive:$usesOfflineHive -OfflineHiveDatPath $hiveDatPath -HiveAlreadyLoaded:([bool]$regResult.HiveLeftLoaded)

            Write-Host "Fallback import succeeded for '$path'." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        catch {
            $errorMessage = "Failed importing registry file '$path'. reg import error: $details. PowerShell fallback error: $($_.Exception.Message)"
            Write-Host $errorMessage -ForegroundColor Red
            Write-Host ""
            throw $errorMessage
        }
    }

    Write-Host ""
}