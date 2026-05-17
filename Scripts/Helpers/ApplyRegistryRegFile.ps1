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
        'Hex2' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::ExpandString; Value = [string]$Operation.ValueData }
        }
        'Hex1' {
            $stringValue = ([System.Text.Encoding]::Unicode.GetString([byte[]]$Operation.ValueData)).TrimEnd([char]0)
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::String; Value = $stringValue }
        }
        'Hex7' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::MultiString; Value = [string[]]@($Operation.ValueData | ForEach-Object { [string]$_ }) }
        }
        'Binary' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Value = [byte[]]$Operation.ValueData }
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

    $existingKey = $RootKey.OpenSubKey($SubKeyPath, $true)
    if ($null -eq $existingKey) {
        return
    }

    $existingKey.Close()

    try {
        $RootKey.DeleteSubKeyTree($SubKeyPath, $false)
    }
    catch {
        # Best-effort cleanup only; missing keys are fine.
    }
}

function Get-RegistryKeyForOperation {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,
        [switch]$CreateIfMissing
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

    foreach ($operation in @(Get-RegFileOperations -regFilePath $RegFilePath)) {
        $keyInfo = Get-RegistryKeyForOperation -RegistryPath $operation.KeyPath -CreateIfMissing:($operation.OperationType -eq 'SetValue')

        switch ($operation.OperationType) {
            'DeleteKey' {
                if ($null -ne $keyInfo.Key) {
                    try {
                        if ($null -ne $keyInfo.SubKeyPath) {
                            Remove-RegistrySubKeyTreeIfExists -RootKey $keyInfo.RootKey -SubKeyPath $keyInfo.SubKeyPath
                        }
                    }
                    finally {
                        $keyInfo.Key.Close()
                    }
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
                    throw "Unable to open or create registry key '$($operation.KeyPath)'"
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