. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

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
            throw (Get-ConsoleTranslation -Text 'Unsupported value type ''{0}'' while applying reg operation for ''{1}''' -FormatArgs @($valueType, $operationKeyPath))
        }
    }
}

<#
    .SYNOPSIS
        解析注册表路径并按需打开或创建目标键。
    .DESCRIPTION
        不支持的路径或根键抛出异常；路径只指向根键时直接返回根键对象。
        子键不存在且未要求创建时，返回对象的 Key 可以为空。
    .PARAMETER RegistryPath
        要解析的完整注册表路径。
    .PARAMETER CreateIfMissing
        打开子键时允许创建缺失的键。
    .PARAMETER OpenKey
        默认打开可写子键；为假时仅解析路径，不打开子键。
    .OUTPUTS
        System.Management.Automation.PSCustomObject。包含 RootKey、SubKeyPath 和 Key。
#>
function Get-RegistryKeyForOperation {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,
        [switch]$CreateIfMissing,
        [bool]$OpenKey = $true
    )

    $parts = Split-RegistryPath -path $RegistryPath
    if (-not $parts) {
        throw (Get-ConsoleTranslation -Text 'Unsupported registry path: {0}' -FormatArgs @($RegistryPath))
    }

    $rootKey = Get-RegistryRootKey -hiveName $parts.Hive
    if (-not $rootKey) {
        throw (Get-ConsoleTranslation -Text 'Unsupported registry hive ''{0}'' in path ''{1}''' -FormatArgs @($($parts.Hive), $RegistryPath))
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

<#
    .SYNOPSIS
        执行删除注册表值的操作，并关闭已打开的键。
    .DESCRIPTION
        目标键不存在时输出详细提示并返回；值不存在时忽略。其他删除错误向上传递，
        但仍会关闭键。空值名表示默认值。
    .PARAMETER Operation
        包含 KeyPath 和 ValueName 的删除操作。
    .PARAMETER KeyInfo
        包含已打开键 Key 的路径解析结果。
#>
function Invoke-RegistryDeleteValueOperation {
    param(
        [Parameter(Mandatory)]
        $Operation,
        [Parameter(Mandatory)]
        $KeyInfo
    )

    if ($null -eq $KeyInfo.Key) {
        $valueName = Get-NormalizedRegistryValueName -ValueName $Operation.ValueName
        $displayValueName = if ([string]::IsNullOrEmpty($valueName)) { (Get-ConsoleTranslation -Text '(Default)') } else { $valueName }
        Write-Verbose (Get-ConsoleTranslation -Text 'Unable to find or open key ''{0}'' and value ''{1}''' -FormatArgs @($($Operation.KeyPath), $displayValueName))
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

<#
    .SYNOPSIS
        将解析后的注册表值写入目标键。
    .DESCRIPTION
        先转换值名、数据和类型，再写入并在 finally 中关闭键。
        Key 为空时抛出访问被拒绝异常；其他转换或写入错误向上传递。
    .PARAMETER Operation
        包含 KeyPath、ValueName、ValueType 和 ValueData 的写入操作。
    .PARAMETER KeyInfo
        包含已打开可写键 Key 的路径解析结果。
#>
function Invoke-RegistrySetValueOperation {
    param(
        [Parameter(Mandatory)]
        $Operation,
        [Parameter(Mandatory)]
        $KeyInfo
    )

    if ($null -eq $KeyInfo.Key) {
        throw [System.UnauthorizedAccessException]::new((Get-ConsoleTranslation -Text 'Unable to open or create registry key ''{0}''' -FormatArgs @($($Operation.KeyPath))))
    }

    try {
        $setArgs = Convert-RegOperationToValueKind -Operation $Operation
        $KeyInfo.Key.SetValue($setArgs.Name, $setArgs.Value, $setArgs.Kind)
    }
    finally {
        $KeyInfo.Key.Close()
    }
}

<#
    .SYNOPSIS
        显示因访问权限不足而跳过注册表操作的本地化警告。
    .DESCRIPTION
        警告包含操作类型、键路径及异常消息；值操作还包含值名，空值名显示为默认值。
    .PARAMETER Operation
        包含 OperationType、KeyPath 及可选 ValueName 的操作。
    .PARAMETER ExceptionMessage
        访问权限异常的原始消息。
#>
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
        $displayValueName = if ([string]::IsNullOrEmpty($valueName)) { (Get-ConsoleTranslation -Text '(Default)') } else { $valueName }
        Write-Warning (Get-ConsoleTranslation -Text 'Skipping operation ''{0}'' on key ''{1}'' value ''{2}'' due to access restrictions: {3}' -FormatArgs @($operationType, $keyPath, $displayValueName, $ExceptionMessage))
        return
    }

    Write-Warning (Get-ConsoleTranslation -Text 'Skipping operation ''{0}'' on key ''{1}'' due to access restrictions: {2}' -FormatArgs @($operationType, $keyPath, $ExceptionMessage))
}

<#
    .SYNOPSIS
        分派单项注册表删除键、删除值或写入值操作。
    .DESCRIPTION
        写值时允许创建目标键，删除键时只解析路径；不删除整个根键。
        不支持的操作类型抛出包含来源文件路径的异常，底层操作错误向上传递。
    .PARAMETER Operation
        Get-RegFileOperations 返回的操作对象。
    .PARAMETER RegFilePath
        来源注册表文件路径，用于不支持的操作类型提示。
#>
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
            throw (Get-ConsoleTranslation -Text 'Unsupported reg operation type ''{0}'' in ''{1}''' -FormatArgs @($($Operation.OperationType), $RegFilePath))
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
        Write-Host (Get-ConsoleTranslation -Text '[WhatIf] Apply {0} registry changes from ''{1}''' -FormatArgs @($totalOperations, $RegFilePath)) -ForegroundColor Cyan
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
        throw (Get-ConsoleTranslation -Text 'Registry fallback import could not apply any operations in ''{0}'' because all {1} operation(s) were blocked by access restrictions.' -FormatArgs @($RegFilePath, $accessDeniedCount))
    }

    if ($accessDeniedCount -gt 0) {
        Write-Warning (Get-ConsoleTranslation -Text 'Registry fallback import completed with {0} access-restricted operation(s) skipped in ''{1}''.' -FormatArgs @($accessDeniedCount, $RegFilePath))
        return $false
    }

    return $true
}
