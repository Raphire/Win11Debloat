. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

function New-TargetUserHiveContext {
    param(
        [Parameter(Mandatory)]
        [string]$TargetUserName,
        [AllowNull()]
        [object]$UserContext,
        [Parameter(Mandatory)]
        [string]$HiveDatPath,
        [AllowNull()]
        [string]$MountName,
        [bool]$WasAlreadyLoaded = $false,
        [bool]$WasLoadedByScript = $false
    )

    $effectiveMountName = if ([string]::IsNullOrWhiteSpace($MountName)) { 'Default' } else { $MountName }

    return [PSCustomObject]@{
        TargetUserName = $TargetUserName
        UserSid = if ($UserContext) { $UserContext.UserSid } else { $null }
        ProfilePath = if ($UserContext) { $UserContext.ProfilePath } else { $null }
        HiveDatPath = $HiveDatPath
        MountName = $effectiveMountName
        WasAlreadyLoaded = $WasAlreadyLoaded
        WasLoadedByScript = $WasLoadedByScript
    }
}

<#
    .SYNOPSIS
        解析目标用户的注册表配置单元上下文，不执行加载操作。
    .DESCRIPTION
        规范化用户名，解析配置文件并确认 NTUSER.DAT 存在；缺失时抛出异常。
        普通用户的 SID 配置单元已加载时复用该挂载点，否则返回 Default 挂载名。
    .PARAMETER TargetUserName
        目标用户名，包括 Default 配置文件。
    .OUTPUTS
        System.Management.Automation.PSCustomObject。包含用户名、SID、配置文件路径、
        HiveDatPath、MountName、WasAlreadyLoaded 和 WasLoadedByScript。
#>
function Resolve-TargetUserHiveContext {
    param(
        [Parameter(Mandatory)]
        [string]$TargetUserName
    )

    $normalizedTargetUserName = Normalize-UserLookupValue -Value $TargetUserName
    if ([string]::IsNullOrWhiteSpace($normalizedTargetUserName)) {
        throw (Get-ConsoleTranslation -Text 'Target user name for registry hive resolution is empty.')
    }

    $userContext = Resolve-UserProfileContext -UserName $normalizedTargetUserName
    if (-not $userContext -or [string]::IsNullOrWhiteSpace([string]$userContext.ProfilePath)) {
        throw (Get-ConsoleTranslation -Text 'Unable to resolve profile path for target user ''{0}''.' -FormatArgs @($normalizedTargetUserName))
    }

    $hiveDatPath = Join-Path $userContext.ProfilePath 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $hiveDatPath)) {
        throw (Get-ConsoleTranslation -Text 'Unable to find target user hive at ''{0}''.' -FormatArgs @($hiveDatPath))
    }

    $isDefaultProfile = $normalizedTargetUserName.Equals('Default', [System.StringComparison]::OrdinalIgnoreCase)
    $userSid = if ($userContext) { [string]$userContext.UserSid } else { '' }

    if ((-not $isDefaultProfile) -and (-not [string]::IsNullOrWhiteSpace($userSid))) {
        $loadedHivePath = "Registry::HKEY_USERS\$userSid"
        if (Test-Path -LiteralPath $loadedHivePath) {
            return (New-TargetUserHiveContext `
                -TargetUserName $normalizedTargetUserName `
                -UserContext $userContext `
                -HiveDatPath $hiveDatPath `
                -MountName $userSid `
                -WasAlreadyLoaded $true `
                -WasLoadedByScript $false)
        }
    }

    return (New-TargetUserHiveContext `
        -TargetUserName $normalizedTargetUserName `
        -UserContext $userContext `
        -HiveDatPath $hiveDatPath `
        -MountName 'Default' `
        -WasAlreadyLoaded $false `
        -WasLoadedByScript $false)
}

function Resolve-LoadedTargetUserHiveContext {
    param(
        [Parameter(Mandatory)]
        $HiveContext
    )

    $userSid = [string]$HiveContext.UserSid
    if ([string]::IsNullOrWhiteSpace($userSid)) {
        return $null
    }

    $loadedHivePath = "Registry::HKEY_USERS\$userSid"
    if (-not (Test-Path -LiteralPath $loadedHivePath)) {
        return $null
    }

    return (New-TargetUserHiveContext `
        -TargetUserName $HiveContext.TargetUserName `
        -UserContext ([PSCustomObject]@{ UserSid = $HiveContext.UserSid; ProfilePath = $HiveContext.ProfilePath }) `
        -HiveDatPath $HiveContext.HiveDatPath `
        -MountName $userSid `
        -WasAlreadyLoaded $true `
        -WasLoadedByScript $false)
}

<#
    .SYNOPSIS
        在目标用户的注册表配置单元上下文中执行脚本块。
    .DESCRIPTION
        复用已加载的配置单元，否则调用 reg load；加载失败时再检查 SID 挂载点，
        仍不可用则抛出异常。执行期间设置脚本的目标挂载名，结束时恢复原值。
        finally 中只卸载本函数加载的配置单元，卸载失败发出警告。
    .PARAMETER TargetUserName
        要操作其注册表配置单元的目标用户名。
    .PARAMETER ScriptBlock
        配置单元就绪后执行的脚本块，异常向上传递。
    .PARAMETER ArgumentObject
        作为脚本块第一个位置参数传入的对象。
    .PARAMETER PassHiveContext
        将配置单元上下文作为第二个位置参数传入脚本块。
    .OUTPUTS
        System.Object。脚本块产生的输出。
#>
function Invoke-WithTargetUserHive {
    param(
        [Parameter(Mandatory)]
        [string]$TargetUserName,
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        $ArgumentObject = $null,
        [switch]$PassHiveContext
    )

    $hiveContext = Resolve-TargetUserHiveContext -TargetUserName $TargetUserName
    $previousHiveMountName = $script:RegistryTargetHiveMountName

    try {
        if (-not $hiveContext.WasAlreadyLoaded) {
            $global:LASTEXITCODE = 0
            reg load "HKU\$($hiveContext.MountName)" "$($hiveContext.HiveDatPath)" | Out-Null
            $loadExitCode = $LASTEXITCODE

            if ($loadExitCode -ne 0) {
                $loadedSidContext = Resolve-LoadedTargetUserHiveContext -HiveContext $hiveContext
                if ($loadedSidContext) {
                    $hiveContext = $loadedSidContext
                }
                else {
                    throw (Get-ConsoleTranslation -Text 'Failed to load target user hive ''{0}'' (exit code: {1}).' -FormatArgs @($($hiveContext.HiveDatPath), $loadExitCode))
                }
            }
            else {
                $hiveContext.WasLoadedByScript = $true
            }
        }

        $script:RegistryTargetHiveMountName = [string]$hiveContext.MountName

        if ($PassHiveContext) {
            return & $ScriptBlock $ArgumentObject $hiveContext
        }

        return & $ScriptBlock $ArgumentObject
    }
    finally {
        $script:RegistryTargetHiveMountName = $previousHiveMountName

        if ($hiveContext -and $hiveContext.WasLoadedByScript) {
            $global:LASTEXITCODE = 0
            reg unload "HKU\$($hiveContext.MountName)" | Out-Null
            $unloadExitCode = $LASTEXITCODE
            if ($unloadExitCode -ne 0) {
                Write-Warning (Get-ConsoleTranslation -Text 'Failed to unload registry hive ''HKU\{0}'' (exit code: {1})' -FormatArgs @($($hiveContext.MountName), $unloadExitCode))
            }
        }
    }
}
