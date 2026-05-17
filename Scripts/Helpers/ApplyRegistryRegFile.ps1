function Convert-RegOperationToValueKind {
    param(
        [Parameter(Mandatory)]
        $Operation
    )

    $valueName = if ([string]::IsNullOrEmpty([string]$Operation.ValueName)) { '' } else { [string]$Operation.ValueName }
    $valueType = [string]$Operation.ValueType

    switch ($valueType) {
        'DWord' {
            $unsigned = [uint32]$Operation.ValueData
            $value = [BitConverter]::ToInt32([BitConverter]::GetBytes($unsigned), 0)
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::DWord; Value = $value }
        }
        'QWord' {
            $unsigned = [uint64]$Operation.ValueData
            $value = [BitConverter]::ToInt64([BitConverter]::GetBytes($unsigned), 0)
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::QWord; Value = $value }
        }
        'String' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::String; Value = [string]$Operation.ValueData }
        }
        'Binary' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Value = [byte[]]$Operation.ValueData }
        }
        'Hex0' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::None; Value = [byte[]]$Operation.ValueData }
        }
        'Hex1' {
            $stringValue = ([System.Text.Encoding]::Unicode.GetString([byte[]]$Operation.ValueData)).TrimEnd([char]0)
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::String; Value = $stringValue }
        }
        'Hex2' {
            $expandStringValue = if ($Operation.ValueData -is [byte[]]) {
                ([System.Text.Encoding]::Unicode.GetString([byte[]]$Operation.ValueData)).TrimEnd([char]0)
            }
            else {
                [string]$Operation.ValueData
            }
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::ExpandString; Value = $expandStringValue }
        }
        'Hex7' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::MultiString; Value = [string[]]$Operation.ValueData }
        }
        { $valueType -in @('Hex3', 'Hex4', 'Hex5') } {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Value = [byte[]]$Operation.ValueData }
        }
        'HexB' {
            $qwordBytes = [byte[]]$Operation.ValueData
            if ($qwordBytes.Count -gt 8) {
                throw "Unsupported hex value type '$valueType' with invalid byte count '$($qwordBytes.Count)' while applying reg operation for '$($Operation.KeyPath)'."
            }

            if ($qwordBytes.Count -lt 8) {
                $paddedBytes = New-Object byte[] 8
                [Array]::Copy($qwordBytes, $paddedBytes, $qwordBytes.Count)
                $qwordBytes = $paddedBytes
            }

            $unsigned = [BitConverter]::ToUInt64($qwordBytes, 0)
            $signed = [BitConverter]::ToInt64([BitConverter]::GetBytes($unsigned), 0)
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::QWord; Value = $signed }
        }
        default {
            if ($valueType -like 'Hex*') {
                throw "Unsupported hex value type '$valueType' while applying reg operation for '$($Operation.KeyPath)'."
            }

            throw "Unsupported value type '$valueType' while applying reg operation for '$($Operation.KeyPath)'"
        }
    }
}

function Remove-RegistrySubKeyTreeIfExists {
    param(
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryKey]$RootKey,
        [Parameter(Mandatory)]
        [string]$SubKeyPath
    )

    try {
        $RootKey.DeleteSubKeyTree($SubKeyPath, $false)
    }
    catch [System.UnauthorizedAccessException], [System.Security.SecurityException] {
        throw
    }
    catch {
        # Best-effort cleanup only; missing keys are fine.
    }
}

function Get-RegistryKeyForOperation {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,
        [switch]$CreateIfMissing,
        [bool]$OpenKey = $true
    )

    $parts = Split-RegistryPath -path $RegistryPath
    if (-not $parts) {
        throw "Unsupported registry path: $RegistryPath"
    }

    $rootKey = Get-RegistryRootKey -hiveName $parts.Hive
    if (-not $rootKey) {
        throw "Unsupported registry hive '$($parts.Hive)' in path '$RegistryPath'"
    }

    $subKeyPath = $parts.SubKey
    if ([string]::IsNullOrWhiteSpace($subKeyPath)) {
        return [PSCustomObject]@{ RootKey = $rootKey; SubKeyPath = $null; Key = $rootKey }
    }

    if (-not $OpenKey) {
        return [PSCustomObject]@{ RootKey = $rootKey; SubKeyPath = $subKeyPath; Key = $null }
    }

    $key = if ($CreateIfMissing) {
        $rootKey.CreateSubKey($subKeyPath)
    }
    else {
        $rootKey.OpenSubKey($subKeyPath, $true)
    }

    return [PSCustomObject]@{ RootKey = $rootKey; SubKeyPath = $subKeyPath; Key = $key }
}

function Invoke-RegistryOperationsFromRegFile {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath
    )

    $accessDeniedCount = 0

    foreach ($operation in @(Get-RegFileOperations -regFilePath $RegFilePath)) {
        try {
            $keyInfo = Get-RegistryKeyForOperation -RegistryPath $operation.KeyPath -CreateIfMissing:($operation.OperationType -eq 'SetValue') -OpenKey:($operation.OperationType -ne 'DeleteKey')

            switch ($operation.OperationType) {
                'DeleteKey' {
                    if ($null -ne $keyInfo.SubKeyPath) {
                        Remove-RegistrySubKeyTreeIfExists -RootKey $keyInfo.RootKey -SubKeyPath $keyInfo.SubKeyPath
                    }
                }
                'DeleteValue' {
                    if ($null -ne $keyInfo.Key) {
                        try {
                            $valueName = if ([string]::IsNullOrEmpty([string]$operation.ValueName)) { '' } else { [string]$operation.ValueName }
                            $keyInfo.Key.DeleteValue($valueName, $false)
                        }
                        finally {
                            $keyInfo.Key.Close()
                        }
                    }
                }
                'SetValue' {
                    if ($null -eq $keyInfo.Key) {
                        throw [System.UnauthorizedAccessException]::new("Unable to open or create registry key '$($operation.KeyPath)'")
                    }

                    try {
                        $setArgs = Convert-RegOperationToValueKind -Operation $operation
                        $keyInfo.Key.SetValue($setArgs.Name, $setArgs.Value, $setArgs.Kind)
                    }
                    finally {
                        $keyInfo.Key.Close()
                    }
                }
                default {
                    throw "Unsupported reg operation type '$($operation.OperationType)' in '$RegFilePath'"
                }
            }
        }
        catch [System.UnauthorizedAccessException], [System.Security.SecurityException] {
            $accessDeniedCount++
            $keyPath = [string]$operation.KeyPath
            $opType = [string]$operation.OperationType
            $valueName = [string]$operation.ValueName

            if ($opType -eq 'SetValue' -or $opType -eq 'DeleteValue') {
                $display = if ([string]::IsNullOrEmpty($valueName)) { '(Default)' } else { $valueName }
                Write-Warning "Skipping operation '$opType' on key '$keyPath' value '$display' due to access restrictions: $($_.Exception.Message)"
            }
            else {
                Write-Warning "Skipping operation '$opType' on key '$keyPath' due to access restrictions: $($_.Exception.Message)"
            }

            continue
        }
    }

    if ($accessDeniedCount -gt 0) {
        Write-Warning "Registry fallback import completed with $accessDeniedCount access-restricted operation(s) skipped in '$RegFilePath'."
    }
}

function Invoke-RegistryImportViaPowerShell {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath,
        [switch]$UseOfflineHive,
        [string]$OfflineHiveDatPath,
        [switch]$HiveAlreadyLoaded
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

        if (-not $HiveAlreadyLoaded) {
            $global:LASTEXITCODE = 0
            reg load "HKU\Default" $OfflineHiveDatPath | Out-Null
            $loadExitCode = $LASTEXITCODE
            if ($loadExitCode -ne 0) {
                throw "Failed to load user hive at '$OfflineHiveDatPath' for fallback import (exit code: $loadExitCode)"
            }
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