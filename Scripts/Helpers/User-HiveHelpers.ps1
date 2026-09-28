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
