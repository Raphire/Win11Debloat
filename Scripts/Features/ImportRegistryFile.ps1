function Convert-RegOperationKeyToProviderPath {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath
    )

    $parts = Split-RegistryPath -path $RegistryPath
    if (-not $parts) {
        throw "Unsupported registry path: $RegistryPath"
    }

    $driveRoot = switch ($parts.Hive.ToUpperInvariant()) {
        'HKEY_LOCAL_MACHINE' { 'HKLM:' }
        'HKEY_CURRENT_USER' { 'HKCU:' }
        'HKEY_CLASSES_ROOT' { 'HKCR:' }
        'HKEY_USERS' { 'HKU:' }
        'HKEY_CURRENT_CONFIG' { 'HKCC:' }
        default { throw "Unsupported registry hive '$($parts.Hive)' in path '$RegistryPath'" }
    }

    if ([string]::IsNullOrWhiteSpace($parts.SubKey)) {
        return $driveRoot
    }

    return "$driveRoot\$($parts.SubKey)"
}

function Convert-RegOperationToSetItemPropertyArguments {
    param(
        [Parameter(Mandatory)]
        $Operation
    )

    $valueName = if ([string]::IsNullOrEmpty([string]$Operation.ValueName)) { '(default)' } else { [string]$Operation.ValueName }
    $valueType = [string]$Operation.ValueType

    switch ($valueType) {
        'DWord' {
            $unsigned = [uint32]$Operation.ValueData
            $value = [BitConverter]::ToInt32([BitConverter]::GetBytes($unsigned), 0)
            return @{ Name = $valueName; Type = 'DWord'; Value = $value }
        }
        'QWord' {
            $unsigned = [uint64]$Operation.ValueData
            $value = [BitConverter]::ToInt64([BitConverter]::GetBytes($unsigned), 0)
            return @{ Name = $valueName; Type = 'QWord'; Value = $value }
        }
        'String' {
            return @{ Name = $valueName; Type = 'String'; Value = [string]$Operation.ValueData }
        }
        'Hex2' {
            return @{ Name = $valueName; Type = 'ExpandString'; Value = [string]$Operation.ValueData }
        }
        'Hex1' {
            $stringValue = ([System.Text.Encoding]::Unicode.GetString([byte[]]$Operation.ValueData)).TrimEnd([char]0)
            return @{ Name = $valueName; Type = 'String'; Value = $stringValue }
        }
        'Hex7' {
            return @{ Name = $valueName; Type = 'MultiString'; Value = @($Operation.ValueData) }
        }
        'Binary' {
            return @{ Name = $valueName; Type = 'Binary'; Value = [byte[]]$Operation.ValueData }
        }
        default {
            if ($valueType -like 'Hex*') {
                throw "Unsupported hex value type '$valueType' while applying reg operation for '$($Operation.KeyPath)'."
            }

            throw "Unsupported value type '$valueType' while applying reg operation for '$($Operation.KeyPath)'"
        }
    }
}

function Invoke-RegistryOperationsFromRegFile {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath
    )

    foreach ($operation in @(Get-RegFileOperations -regFilePath $RegFilePath)) {
        $providerPath = Convert-RegOperationKeyToProviderPath -RegistryPath $operation.KeyPath

        switch ($operation.OperationType) {
            'DeleteKey' {
                if (Test-Path -LiteralPath $providerPath) {
                    Remove-Item -LiteralPath $providerPath -Recurse -Force -ErrorAction Stop
                }
            }
            'DeleteValue' {
                if (Test-Path -LiteralPath $providerPath) {
                    $valueName = if ([string]::IsNullOrEmpty([string]$operation.ValueName)) { '(default)' } else { [string]$operation.ValueName }
                    Remove-ItemProperty -Path $providerPath -Name $valueName -ErrorAction SilentlyContinue
                }
            }
            'SetValue' {
                if (-not (Test-Path -LiteralPath $providerPath)) {
                    New-Item -Path $providerPath -Force -ErrorAction Stop | Out-Null
                }
                $setArgs = Convert-RegOperationToSetItemPropertyArguments -Operation $operation
                Set-ItemProperty -Path $providerPath -Name $setArgs.Name -Value $setArgs.Value -Type $setArgs.Type -Force -ErrorAction Stop
            }
            default {
                throw "Unsupported reg operation type '$($operation.OperationType)' in '$RegFilePath'"
            }
        }
    }
}

function Invoke-RegistryImportViaPowerShell {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath,
        [switch]$UseOfflineHive,
        [string]$OfflineHiveDatPath
    )

    $applyScript = {
        param($targetRegFilePath)
        Invoke-RegistryOperationsFromRegFile -RegFilePath $targetRegFilePath
    }

    if ($UseOfflineHive) {
        if (Get-Command -Name Invoke-WithLoadedBackupHive -ErrorAction SilentlyContinue) {
            return Invoke-WithLoadedBackupHive -ScriptBlock $applyScript -ArgumentObject $RegFilePath
        }

        if ([string]::IsNullOrWhiteSpace($OfflineHiveDatPath)) {
            throw "Offline hive path was not provided for fallback import of '$RegFilePath'"
        }

        $global:LASTEXITCODE = 0
        reg load "HKU\Default" $OfflineHiveDatPath | Out-Null
        $loadExitCode = $LASTEXITCODE
        if ($loadExitCode -ne 0) {
            throw "Failed to load user hive at '$OfflineHiveDatPath' for fallback import (exit code: $loadExitCode)"
        }

        try {
            return & $applyScript $RegFilePath
        }
        finally {
            $global:LASTEXITCODE = 0
            reg unload "HKU\Default" | Out-Null
            $unloadExitCode = $LASTEXITCODE
            if ($unloadExitCode -ne 0) {
                Write-Warning "Fallback import completed, but unloading HKU\Default failed (exit code: $unloadExitCode)."
            }
        }
    }

    return & $applyScript $RegFilePath
}

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
                FailureStage = $null
            }

            try {
                $global:LASTEXITCODE = 0
                reg load "HKU\Default" $hivePath | Out-Null
                $loadExitCode = $LASTEXITCODE

                if ($loadExitCode -ne 0) {
                    $result.FailureStage = 'load'
                    throw "Failed to load user hive at '$hivePath' (exit code: $loadExitCode)"
                }

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
                $global:LASTEXITCODE = 0
                reg unload "HKU\Default" | Out-Null
                $unloadExitCode = $LASTEXITCODE
                if ($unloadExitCode -ne 0 -and -not $result.Error) {
                    $result.FailureStage = 'unload'
                    $result.Error = "Failed to unload registry hive HKU\Default (exit code: $unloadExitCode)"
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
            if ($script:GuiWindow) {
                $repoRootPath = Split-Path -Path $script:RegfilesPath -Parent
                $registryPathHelpersScript = Join-Path $repoRootPath 'Scripts\Helpers\RegistryPathHelpers.ps1'
                $regFileOperationsScript = Join-Path $repoRootPath 'Scripts\Helpers\Get-RegFileOperations.ps1'
                $importRegistryScript = Join-Path $repoRootPath 'Scripts\Features\ImportRegistryFile.ps1'

                Invoke-NonBlocking -ScriptBlock {
                    param(
                        $registryPathHelpersScriptPath,
                        $regFileOperationsScriptPath,
                        $importRegistryScriptPath,
                        $targetRegFilePath,
                        $useOfflineHive,
                        $offlineHiveDatPath
                    )

                    . $registryPathHelpersScriptPath
                    . $regFileOperationsScriptPath
                    . $importRegistryScriptPath

                    Invoke-RegistryImportViaPowerShell -RegFilePath $targetRegFilePath -UseOfflineHive:$useOfflineHive -OfflineHiveDatPath $offlineHiveDatPath
                } -ArgumentList @(
                    $registryPathHelpersScript,
                    $regFileOperationsScript,
                    $importRegistryScript,
                    $regFilePath,
                    $usesOfflineHive,
                    $hiveDatPath
                )
            }
            else {
                Invoke-RegistryImportViaPowerShell -RegFilePath $regFilePath -UseOfflineHive:$usesOfflineHive -OfflineHiveDatPath $hiveDatPath
            }

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