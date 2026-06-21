# Import & execute regfile
function ImportRegistryFile {
    param (
        $message,
        $path
    )

    Write-Host $message

    $usesOfflineHive = $script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")
    $regFilePath = Get-RegistryFilePathForFeature -RegistryKey $path

    if (-not (Test-Path $regFilePath)) {
        $errorMessage = "Unable to find registry file: $path ($regFilePath)"
        $script:RegistryImportFailures++
        Write-Host "Error: $errorMessage" -ForegroundColor Red
        Write-Host ""
        throw $errorMessage
    }

    $importScript = {
        param($targetRegFilePath, $hiveContext)

        if ($script:Params.ContainsKey("WhatIf")) {
            Invoke-RegistryOperationsFromRegFile -RegFilePath $targetRegFilePath
            Write-Host ""
            return
        }

        # When the target user's hive is already loaded under their SID, the .reg file's
        # HKEY_USERS\Default paths won't match. Use the PowerShell registry writer instead,
        # which remaps Default → SID via Split-RegistryPath.
        $usePowerShellFallbackOnly = $hiveContext -and [bool]$hiveContext.WasAlreadyLoaded

        if ($usePowerShellFallbackOnly) {
            Invoke-RegistryOperationsFromRegFile -RegFilePath $targetRegFilePath
            Write-Host "The operation completed successfully via PowerShell registry writer."
            Write-Host ""
            return
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
        } -ArgumentList $targetRegFilePath

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
            Invoke-RegistryOperationsFromRegFile -RegFilePath $targetRegFilePath
            Write-Host "The operation completed successfully via PowerShell registry writer."
        }

        Write-Host ""
    }

    try {
        if ($usesOfflineHive) {
            # Sysprep targets Default user, User targets the specified user. Logged-in users already have their hive mounted under HKU\<SID>.
            $targetUserName = if ($script:Params.ContainsKey("Sysprep")) { "Default" } else { $script:Params.Item("User") }
            Invoke-WithTargetUserHive -TargetUserName $targetUserName -ScriptBlock $importScript -ArgumentObject $regFilePath -PassHiveContext
        }
        else {
            & $importScript $regFilePath $null
        }
    }
    catch {
        $script:RegistryImportFailures++
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
    }
}
