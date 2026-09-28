function Get-NormalizedRegistryValueName {
    param(
        [AllowNull()]
        $ValueName
    )

    if ([string]::IsNullOrEmpty([string]$ValueName)) {
        return ''
    }

    return [string]$ValueName
}

<#
    .SYNOPSIS
        Converts a parsed .reg operation into a Name/Kind/Value set for RegistryKey.SetValue.
#>
function Convert-RegOperationToValueKind {
    param(
        [Parameter(Mandatory)]
        $Operation
    )

    $valueName = Get-NormalizedRegistryValueName -ValueName $Operation.ValueName
    $valueType = [string]$Operation.ValueType
    $operationKeyPath = [string]$Operation.KeyPath

    # ValueType here is whatever Get-RegFileOperations parsed it as.
    # Hex2/Hex7 are its names for REG_EXPAND_SZ/REG_MULTI_SZ, already decoded to string/string[].
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
        'Binary' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Value = [byte[]]$Operation.ValueData }
        }
        'Hex7' {
            return @{ Name = $valueName; Kind = [Microsoft.Win32.RegistryValueKind]::MultiString; Value = [string[]]@($Operation.ValueData) }
        }
        default {
            throw "对 '$operationKeyPath' 应用注册表操作时遇到不受支持的值类型 '$valueType'。"
        }
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
        throw "不支持的注册表路径：$RegistryPath"
    }

    $rootKey = Get-RegistryRootKey -hiveName $parts.Hive
    if (-not $rootKey) {
        throw "路径 '$RegistryPath' 中的注册表配置单元 '$($parts.Hive)' 不受支持。"
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

function Invoke-RegistryDeleteValueOperation {
    param(
        [Parameter(Mandatory)]
        $Operation,
        [Parameter(Mandatory)]
        $KeyInfo
    )

    if ($null -eq $KeyInfo.Key) {
        $valueName = Get-NormalizedRegistryValueName -ValueName $Operation.ValueName
        $displayValueName = if ([string]::IsNullOrEmpty($valueName)) { '（默认）' } else { $valueName }
        Write-Verbose "无法找到或打开注册表项 '$($Operation.KeyPath)' 及值 '$displayValueName'。"
        return
    }

    try {
        $valueName = Get-NormalizedRegistryValueName -ValueName $Operation.ValueName
        $KeyInfo.Key.DeleteValue($valueName, $false)
    }
    finally {
        $KeyInfo.Key.Close()
    }
}

function Invoke-RegistrySetValueOperation {
    param(
        [Parameter(Mandatory)]
        $Operation,
        [Parameter(Mandatory)]
        $KeyInfo
    )

    if ($null -eq $KeyInfo.Key) {
        throw [System.UnauthorizedAccessException]::new("无法打开或创建注册表项 '$($Operation.KeyPath)'。")
    }

    try {
        $setArgs = Convert-RegOperationToValueKind -Operation $Operation
        $KeyInfo.Key.SetValue($setArgs.Name, $setArgs.Value, $setArgs.Kind)
    }
    finally {
        $KeyInfo.Key.Close()
    }
}

function Write-RegistryOperationAccessDeniedWarning {
    param(
        [Parameter(Mandatory)]
        $Operation,
        [Parameter(Mandatory)]
        [string]$ExceptionMessage
    )

    $keyPath = [string]$Operation.KeyPath
    $operationType = [string]$Operation.OperationType

    if ($operationType -eq 'SetValue' -or $operationType -eq 'DeleteValue') {
        $valueName = Get-NormalizedRegistryValueName -ValueName $Operation.ValueName
        $displayValueName = if ([string]::IsNullOrEmpty($valueName)) { '（默认）' } else { $valueName }
        Write-Warning "访问权限受限，跳过注册表项 '$keyPath'、值 '$displayValueName' 的操作 '$operationType'：$ExceptionMessage"
        return
    }

    Write-Warning "访问权限受限，跳过注册表项 '$keyPath' 的操作 '$operationType'：$ExceptionMessage"
}

function Invoke-RegistryOperation {
    param(
        [Parameter(Mandatory)]
        $Operation,
        [Parameter(Mandatory)]
        [string]$RegFilePath
    )

    $operationType = [string]$Operation.OperationType
    $isSetValueOperation = $operationType -eq 'SetValue'
    $isDeleteKeyOperation = $operationType -eq 'DeleteKey'

    $keyInfo = Get-RegistryKeyForOperation -RegistryPath $Operation.KeyPath -CreateIfMissing:$isSetValueOperation -OpenKey:(-not $isDeleteKeyOperation)

    switch ($operationType) {
        'DeleteKey' {
            if ($null -ne $keyInfo.SubKeyPath) {
                Remove-RegistrySubKeyTreeIfExists -RootKey $keyInfo.RootKey -SubKeyPath $keyInfo.SubKeyPath
            }
        }
        'DeleteValue' {
            Invoke-RegistryDeleteValueOperation -Operation $Operation -KeyInfo $keyInfo
        }
        'SetValue' {
            Invoke-RegistrySetValueOperation -Operation $Operation -KeyInfo $keyInfo
        }
        default {
            throw "'$RegFilePath' 中的注册表操作类型 '$($Operation.OperationType)' 不受支持。"
        }
    }
}

<#
    .SYNOPSIS
    Applies all parsed operations from a registry file.

    .OUTPUTS
    System.Boolean. $true when all operations complete, including WhatIf; otherwise $false.
#>
function Invoke-RegistryOperationsFromRegFile {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath
    )

    $accessDeniedCount = 0
    $operations = @(Get-RegFileOperations -regFilePath $RegFilePath)
    $totalOperations = $operations.Count

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[模拟运行] 将从 '$RegFilePath' 应用 $totalOperations 项注册表更改。" -ForegroundColor Cyan
        return $true
    }

    foreach ($operation in $operations) {
        try {
            Invoke-RegistryOperation -Operation $operation -RegFilePath $RegFilePath
        }
        catch [System.UnauthorizedAccessException], [System.Security.SecurityException] {
            $accessDeniedCount++
            Write-RegistryOperationAccessDeniedWarning -Operation $operation -ExceptionMessage $_.Exception.Message
        }
    }

    if ($totalOperations -gt 0 -and $accessDeniedCount -eq $totalOperations) {
        throw "备用导入方式也无法应用 '$RegFilePath' 中的任何操作，全部 $accessDeniedCount 项操作均被访问权限限制阻止。"
    }

    if ($accessDeniedCount -gt 0) {
        Write-Warning "备用注册表导入已完成，已跳过 '$RegFilePath' 中因访问权限受限而无法执行的 $accessDeniedCount 项操作。"
        return $false
    }

    return $true
}
