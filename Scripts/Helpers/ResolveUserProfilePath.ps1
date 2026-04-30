function NormalizeUserLookupValue {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    # Remove zero-width characters and normalize whitespace for robust comparisons.
    $normalized = $Value -replace '[\u200B-\u200D\uFEFF]', ''
    $normalized = $normalized.Trim() -replace '\s+', ' '
    return $normalized
}

if (-not $script:ResolvedUserSidCache) {
    $script:ResolvedUserSidCache = @{}
}

function GetUserLookupCacheKey {
    param(
        [string]$Value
    )

    $normalizedValue = NormalizeUserLookupValue -Value $Value
    if ([string]::IsNullOrWhiteSpace($normalizedValue)) {
        return ''
    }

    return $normalizedValue.ToLowerInvariant()
}

function EscapeWqlString {
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return $Value -replace "'", "''"
}

function GetLocalUserNameSegment {
    param(
        [string]$UserName
    )

    $normalizedName = NormalizeUserLookupValue -Value $UserName
    if ([string]::IsNullOrWhiteSpace($normalizedName)) {
        return ''
    }

    if ($normalizedName.Contains('\')) {
        return NormalizeUserLookupValue -Value (($normalizedName -split '\\')[-1])
    }

    if ($normalizedName.Contains('@')) {
        return NormalizeUserLookupValue -Value (($normalizedName -split '@')[0])
    }

    return $normalizedName
}

function SetResolvedUserSidCache {
    param(
        [string[]]$Candidates,
        [string]$Sid
    )

    if ([string]::IsNullOrWhiteSpace($Sid)) {
        return
    }

    foreach ($candidate in @($Candidates)) {
        $cacheKey = GetUserLookupCacheKey -Value $candidate
        if ($cacheKey) {
            $script:ResolvedUserSidCache[$cacheKey] = $Sid
        }
    }
}

function GetCachedResolvedUserSid {
    param(
        [string[]]$Candidates
    )

    foreach ($candidate in @($Candidates)) {
        $cacheKey = GetUserLookupCacheKey -Value $candidate
        if ($cacheKey -and $script:ResolvedUserSidCache.ContainsKey($cacheKey)) {
            return $script:ResolvedUserSidCache[$cacheKey]
        }
    }

    return $null
}

function TryResolveSidByNtAccount {
    param(
        [string]$UserName
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return $null
    }

    try {
        $ntAccount = [System.Security.Principal.NTAccount]::new($UserName)
        $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
        if ($sid) {
            return $sid.Value
        }
    }
    catch {
        # Fallback handled by caller.
    }

    return $null
}

function TryResolveSidByLocalLookup {
    param(
        [string[]]$Candidates
    )

    $lookupCandidates = @($Candidates) | ForEach-Object { NormalizeUserLookupValue -Value $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    if ($lookupCandidates.Count -eq 0) {
        return $null
    }

    if (Get-Command -Name Get-LocalUser -ErrorAction SilentlyContinue) {
        foreach ($candidate in $lookupCandidates) {
            try {
                $matchingLocalUser = Get-LocalUser -Name $candidate -ErrorAction Stop | Select-Object -First 1
                if ($matchingLocalUser -and $matchingLocalUser.SID) {
                    return $matchingLocalUser.SID.Value
                }
            }
            catch {
                # Continue to next lookup strategy.
            }
        }
    }

    foreach ($candidate in $lookupCandidates) {
        try {
            $escapedCandidate = EscapeWqlString -Value $candidate
            $escapedComputerName = EscapeWqlString -Value $env:COMPUTERNAME
            $filter = "LocalAccount=True AND (Name='$escapedCandidate' OR FullName='$escapedCandidate' OR Caption='$escapedComputerName\$escapedCandidate')"
            $matchingAccount = Get-CimInstance -ClassName Win32_UserAccount -Filter $filter -ErrorAction Stop | Select-Object -First 1

            if ($matchingAccount -and $matchingAccount.SID) {
                return $matchingAccount.SID
            }
        }
        catch {
            # Continue to next lookup strategy.
        }
    }

    return $null
}

function TryResolveSidFromProfileList {
    param(
        [string[]]$Candidates
    )

    $lookupCandidates = @($Candidates) | ForEach-Object { NormalizeUserLookupValue -Value $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    if ($lookupCandidates.Count -eq 0) {
        return $null
    }

    try {
        $profileListPath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
        foreach ($sidKey in @(Get-ChildItem -LiteralPath $profileListPath -ErrorAction Stop)) {
            try {
                $imagePath = Get-ItemPropertyValue -LiteralPath $sidKey.PSPath -Name 'ProfileImagePath' -ErrorAction Stop
                if ([string]::IsNullOrWhiteSpace($imagePath)) { continue }

                $expandedPath = [System.Environment]::ExpandEnvironmentVariables($imagePath)
                $leafName = NormalizeUserLookupValue -Value (Split-Path -Leaf $expandedPath)

                foreach ($candidate in $lookupCandidates) {
                    if ($leafName -ieq $candidate) {
                        return $sidKey.PSChildName
                    }
                }
            }
            catch {
                continue
            }
        }
    }
    catch {
        # Fallback handled by caller.
    }

    return $null
}

function NewResolvedUserContext {
    param(
        [string]$UserName,
        [string]$UserSid,
        [string]$ProfilePath
    )

    return [PSCustomObject]@{
        UserName = $UserName
        UserSid = $UserSid
        ProfilePath = $ProfilePath
    }
}

function ResolveUserSid {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )

    $candidateUserName = NormalizeUserLookupValue -Value $UserName
    if ([string]::IsNullOrWhiteSpace($candidateUserName)) {
        return $null
    }

    $hasQualifiedIdentity = $candidateUserName.Contains('\') -or $candidateUserName.Contains('@')
    $localNameSegment = GetLocalUserNameSegment -UserName $candidateUserName
    $leafNameCandidates = @()
    if ($hasQualifiedIdentity -and -not [string]::IsNullOrWhiteSpace($localNameSegment) -and $localNameSegment -ine $candidateUserName) {
        $leafNameCandidates = @($localNameSegment)
    }

    $cacheCandidates = if ($hasQualifiedIdentity) {
        @($candidateUserName)
    }
    else {
        @($candidateUserName) + $leafNameCandidates | Select-Object -Unique
    }

    $localLookupCandidates = if ($hasQualifiedIdentity) {
        @()
    }
    else {
        @($candidateUserName) + $leafNameCandidates | Select-Object -Unique
    }

    $profileHeuristicCandidates = if ($leafNameCandidates.Count -gt 0) {
        $leafNameCandidates
    }
    else {
        @($candidateUserName)
    }

    $cachedSid = GetCachedResolvedUserSid -Candidates $cacheCandidates
    if ($cachedSid) {
        return $cachedSid
    }

    # Resolve fully-qualified identities first to avoid accidentally matching a local leaf account.
    if ($hasQualifiedIdentity) {
        $resolvedSid = TryResolveSidByNtAccount -UserName $candidateUserName
        if ($resolvedSid) {
            SetResolvedUserSidCache -Candidates $cacheCandidates -Sid $resolvedSid
            return $resolvedSid
        }
    }

    $resolvedSid = TryResolveSidByLocalLookup -Candidates $localLookupCandidates
    if ($resolvedSid) {
        SetResolvedUserSidCache -Candidates $cacheCandidates -Sid $resolvedSid
        return $resolvedSid
    }

    # Last-ditch NTAccount translation for non-qualified names.
    if (-not $hasQualifiedIdentity) {
        $resolvedSid = TryResolveSidByNtAccount -UserName $candidateUserName
        if ($resolvedSid) {
            SetResolvedUserSidCache -Candidates $cacheCandidates -Sid $resolvedSid
            return $resolvedSid
        }
    }

    $resolvedSid = TryResolveSidFromProfileList -Candidates $profileHeuristicCandidates
    if ($resolvedSid) {
        SetResolvedUserSidCache -Candidates $cacheCandidates -Sid $resolvedSid
        return $resolvedSid
    }

    return $null
}

function ResolveUserProfilePath {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )

    $userContext = ResolveUserProfileContext -UserName $UserName
    if ($userContext) {
        return $userContext.ProfilePath
    }

    return $null
}

function ResolveUserProfileContext {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return $null
    }

    $candidateUserName = NormalizeUserLookupValue -Value $UserName
    $rootPaths = @(
        (Join-Path $env:SystemDrive 'Users')
        (Split-Path -Path $env:USERPROFILE -Parent)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    if ($candidateUserName -ieq 'Default') {
        foreach ($rootPath in $rootPaths) {
            if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
                continue
            }

            $defaultProfilePath = Join-Path $rootPath 'Default'
            if (Test-Path -LiteralPath $defaultProfilePath -PathType Container) {
                return (NewResolvedUserContext -UserName $candidateUserName -UserSid $null -ProfilePath $defaultProfilePath)
            }
        }

        return $null
    }

    $userSid = ResolveUserSid -UserName $candidateUserName

    if ($userSid) {
        $sidRegistryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSid"
        try {
            if (Test-Path -LiteralPath $sidRegistryPath) {
                $registryImagePath = Get-ItemPropertyValue -LiteralPath $sidRegistryPath -Name 'ProfileImagePath' -ErrorAction Stop
                if (-not [string]::IsNullOrWhiteSpace($registryImagePath)) {
                    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($registryImagePath)
                    if (Test-Path -LiteralPath $expandedPath -PathType Container) {
                        return (NewResolvedUserContext -UserName $candidateUserName -UserSid $userSid -ProfilePath $expandedPath)
                    }
                }
            }
        }
        catch {
            # Try Win32_UserProfile fallback.
        }

        try {
            $matchingProfiles = @(Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$userSid'" -ErrorAction Stop)
            $resolvedProfile = $matchingProfiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LocalPath) } | Select-Object -First 1
            if ($resolvedProfile -and (Test-Path -LiteralPath $resolvedProfile.LocalPath -PathType Container)) {
                return (NewResolvedUserContext -UserName $candidateUserName -UserSid $userSid -ProfilePath $resolvedProfile.LocalPath)
            }
        }
        catch {
            # Fall through to legacy path probing.
        }
    }

    foreach ($rootPath in $rootPaths) {
        if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
            continue
        }

        $candidateUserPath = Join-Path $rootPath $candidateUserName
        if (Test-Path -LiteralPath $candidateUserPath -PathType Container) {
            return (NewResolvedUserContext -UserName $candidateUserName -UserSid $userSid -ProfilePath $candidateUserPath)
        }
    }

    return $null
}