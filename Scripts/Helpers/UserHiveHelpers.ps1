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
        [bool]$WasLoadedByScript = $false,
        [bool]$RequiresRegFileRewrite = $false
    )

    $effectiveMountName = if ([string]::IsNullOrWhiteSpace($MountName)) { 'Default' } else { $MountName }

    return [PSCustomObject]@{
        TargetUserName = $TargetUserName
        UserSid = if ($UserContext) { $UserContext.UserSid } else { $null }
        ProfilePath = if ($UserContext) { $UserContext.ProfilePath } else { $null }
        HiveDatPath = $HiveDatPath
        MountName = $effectiveMountName
        HiveRoot = "HKEY_USERS\$effectiveMountName"
        RegistryProviderRoot = "Registry::HKEY_USERS\$effectiveMountName"
        WasAlreadyLoaded = $WasAlreadyLoaded
        WasLoadedByScript = $WasLoadedByScript
        RequiresRegFileRewrite = $RequiresRegFileRewrite
    }
}

function Resolve-TargetUserHiveContext {
    param(
        [Parameter(Mandatory)]
        [string]$TargetUserName
    )

    $normalizedTargetUserName = NormalizeUserLookupValue -Value $TargetUserName
    if ([string]::IsNullOrWhiteSpace($normalizedTargetUserName)) {
        throw 'Target user name for registry hive resolution is empty.'
    }

    $userContext = ResolveUserProfileContext -UserName $normalizedTargetUserName
    if (-not $userContext -or [string]::IsNullOrWhiteSpace([string]$userContext.ProfilePath)) {
        throw "Unable to resolve profile path for target user '$normalizedTargetUserName'."
    }

    $hiveDatPath = Join-Path $userContext.ProfilePath 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $hiveDatPath)) {
        throw "Unable to find target user hive at '$hiveDatPath'."
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
                -WasLoadedByScript $false `
                -RequiresRegFileRewrite $true)
        }
    }

    return (New-TargetUserHiveContext `
        -TargetUserName $normalizedTargetUserName `
        -UserContext $userContext `
        -HiveDatPath $hiveDatPath `
        -MountName 'Default' `
        -WasAlreadyLoaded $false `
        -WasLoadedByScript $false `
        -RequiresRegFileRewrite $false)
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
        -WasLoadedByScript $false `
        -RequiresRegFileRewrite $true)
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
    $previousHiveRoot = $script:RegistryTargetHiveRoot

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
                    throw "Failed to load target user hive '$($hiveContext.HiveDatPath)' (exit code: $loadExitCode)."
                }
            }
            else {
                $hiveContext.WasLoadedByScript = $true
            }
        }

        $script:RegistryTargetHiveMountName = [string]$hiveContext.MountName
        $script:RegistryTargetHiveRoot = [string]$hiveContext.HiveRoot

        if ($PassHiveContext) {
            return & $ScriptBlock $ArgumentObject $hiveContext
        }

        return & $ScriptBlock $ArgumentObject
    }
    finally {
        $script:RegistryTargetHiveMountName = $previousHiveMountName
        $script:RegistryTargetHiveRoot = $previousHiveRoot

        if ($hiveContext -and $hiveContext.WasLoadedByScript) {
            $global:LASTEXITCODE = 0
            reg unload "HKU\$($hiveContext.MountName)" | Out-Null
            $unloadExitCode = $LASTEXITCODE
            if ($unloadExitCode -ne 0) {
                throw "Failed to unload registry hive 'HKU\$($hiveContext.MountName)' (exit code: $unloadExitCode)"
            }
        }
    }
}

function Convert-RegFileForTargetHive {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath,
        [AllowNull()]
        $HiveContext
    )

    if (-not $HiveContext -or -not [bool]$HiveContext.RequiresRegFileRewrite) {
        return [PSCustomObject]@{
            Path = $RegFilePath
            IsTemporary = $false
        }
    }

    $targetHiveRoot = [string]$HiveContext.HiveRoot
    if ([string]::IsNullOrWhiteSpace($targetHiveRoot)) {
        throw 'Unable to rewrite registry file because the target hive root is empty.'
    }

    $content = Get-Content -LiteralPath $RegFilePath -Raw -ErrorAction Stop
    $replaceWithTargetHive = [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $targetHiveRoot }

    $content = [regex]::Replace(
        $content,
        'HKEY_USERS\\\.DEFAULT(?=\\|\])',
        $replaceWithTargetHive,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    $content = [regex]::Replace(
        $content,
        'HKEY_USERS\\Default(?=\\|\])',
        $replaceWithTargetHive,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    $tempFileName = 'Win11Debloat_{0}.reg' -f ([guid]::NewGuid().ToString('N'))
    $tempRegFilePath = Join-Path ([System.IO.Path]::GetTempPath()) $tempFileName
    Set-Content -LiteralPath $tempRegFilePath -Value $content -Encoding Unicode -Force

    return [PSCustomObject]@{
        Path = $tempRegFilePath
        IsTemporary = $true
    }
}
