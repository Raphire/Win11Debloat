<#
    .SYNOPSIS
        Normalize a user-name string for lookup and comparison.

    .DESCRIPTION
        User input can carry zero-width characters or stray whitespace that
        would silently break lookups and matches. Normalizing once up front
        keeps every downstream comparison robust against purely cosmetic
        differences. Returns an empty string for blank input.

    .PARAMETER Value
        Raw user-supplied name to normalize.

    .OUTPUTS
        System.String
#>
function NormalizeUserLookupValue {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $normalized = $Value -replace '[\u200B-\u200D\uFEFF]', ''
    $normalized = $normalized.Trim() -replace '\s+', ' '
    return $normalized
}

if (-not $script:ResolvedUserSidCache) {
    $script:ResolvedUserSidCache = @{}
}

<#
    .SYNOPSIS
        Build a form-agnostic cache key for a user name.

    .DESCRIPTION
        SID resolution is expensive and called repeatedly for the same identity,
        so the cache must be keyed by something that survives cosmetic input
        differences. Normalizing and lower-casing ensures the same identity hits
        regardless of case, whitespace, or qualifier form. Returns an empty
        string for blank input.

    .PARAMETER Value
        User name to derive a key from.

    .OUTPUTS
        System.String
#>
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

<#
    .SYNOPSIS
        Escape a string for safe embedding in a WQL single-quoted literal.

    .DESCRIPTION
        WQL string literals are single-quoted, so any embedded quote must be
        doubled. Without this, a user-supplied name containing an apostrophe
        could break the filter or enable WQL injection.

    .PARAMETER Value
        String to escape.

    .OUTPUTS
        System.String
#>
function EscapeWqlString {
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return $Value -replace "'", "''"
}

<#
    .SYNOPSIS
        Extract the local name segment from a possibly domain-qualified identity.

    .DESCRIPTION
        Profile folder leafs never carry the domain prefix, so qualified
        identities (DOMAIN\user, user@domain) must be reduced to the local
        segment before any on-disk comparison can succeed. Returns an empty
        string for blank input.

    .PARAMETER UserName
        User name that may be domain-qualified.

    .OUTPUTS
        System.String
#>
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

<#
    .SYNOPSIS
        Determine whether the local machine is joined to a domain.

    .DESCRIPTION
        Domain vs. workgroup selects entirely different matching rules
        (suffix-aware vs. strict legacy), so every downstream decision needs
        one cheap, consistent answer. Cached in script scope to avoid repeated
        CIM round-trips. The cache is valid only for the current process
        lifetime; joining/unjoining while the script runs is not supported.
        Returns $false on any error or on workgroup machines, so callers
        safely fall back to legacy matching.

    .OUTPUTS
        System.Boolean
#>
function Test-MachineIsDomainJoined {
    if ($null -ne $script:MachineDomainJoinStateKnown) {
        return [bool]$script:MachineIsDomainJoined
    }

    $script:MachineDomainJoinStateKnown = $true
    $script:MachineIsDomainJoined = $false
    $script:MachineNetBiosDomain = ''

    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($null -ne $computerSystem -and $computerSystem.PartOfDomain) {
            $script:MachineIsDomainJoined = $true
            $script:MachineNetBiosDomain = [string]$computerSystem.Domain
        }
    }
    catch {
        # Leave as $false; callers fall back to legacy matching.
    }

    return [bool]$script:MachineIsDomainJoined
}

<#
    .SYNOPSIS
        Return the NetBIOS domain suffix Windows appends to profile folders.

    .DESCRIPTION
        On domain-joined machines Windows writes profile folders as
        user.CONTOSO; knowing the suffix lets a bare user name match that
        folder. Workgroup USERDOMAIN is just the computer name and would
        produce false matches, so it is excluded. Falls back to the NetBIOS
        domain captured by Test-MachineIsDomainJoined when USERDOMAIN is
        empty in restricted execution contexts.

    .OUTPUTS
        System.String
#>
function GetProfileFolderDomainSuffix {
    if (-not (Test-MachineIsDomainJoined)) {
        return ''
    }

    $domain = $env:USERDOMAIN
    if ([string]::IsNullOrWhiteSpace($domain)) {
        # Some restricted execution contexts leave USERDOMAIN empty even when
        # joined; the value captured by the Win32_ComputerSystem query is the
        # reliable alternative.
        $domain = $script:MachineNetBiosDomain
    }
    if ([string]::IsNullOrWhiteSpace($domain)) {
        return ''
    }

    # USERDOMAIN == COMPUTERNAME means the box is effectively standalone; a
    # suffix here would produce false matches instead of disambiguation.
    if ($domain -ieq $env:COMPUTERNAME) {
        return ''
    }

    return $domain.Trim()
}

<#
    .SYNOPSIS
        Enumerate the name forms equivalent to a given identity.

    .DESCRIPTION
        One identity surfaces in different forms depending on where it was
        captured (bare, qualified, domain-suffixed). Enumerating every
        equivalent form lets cross-source matching succeed without broadening
        workgroup validation. Duplicates are removed. Returns an empty array
        for blank input.

    .PARAMETER Value
        User name to expand into equivalent forms.

    .OUTPUTS
        System.String[]
#>
function GetUserNameMatchCandidates {
    param(
        [string]$Value
    )

    $normalized = NormalizeUserLookupValue -Value $Value
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return @()
    }

    $candidates = New-Object 'System.Collections.Generic.List[string]'
    [void]$candidates.Add($normalized)

    $localSegment = GetLocalUserNameSegment -UserName $normalized
    if (-not [string]::IsNullOrWhiteSpace($localSegment) -and ($localSegment -ine $normalized)) {
        [void]$candidates.Add($localSegment)
    }

    # Domain-suffixed forms only make sense where Windows actually writes them.
    $domainSuffix = GetProfileFolderDomainSuffix
    if (-not [string]::IsNullOrWhiteSpace($domainSuffix)) {
        # The base the suffix extends: prefer the local segment so qualified
        # identities (DOMAIN\user) still produce user.CONTOSO rather than the
        # fully qualified string.
        $stem = if (-not [string]::IsNullOrWhiteSpace($localSegment)) { $localSegment } else { $normalized }
        if (-not [string]::IsNullOrWhiteSpace($stem)) {
            $suffixedForm = "$stem.$domainSuffix"
            $alreadyPresent = $false
            foreach ($existing in $candidates) {
                if ($existing -ieq $suffixedForm) { $alreadyPresent = $true; break }
            }
            if (-not $alreadyPresent) {
                [void]$candidates.Add($suffixedForm)
            }
        }

        # A suffixed input can also be referenced by its bare stem elsewhere
        # (registry, backup metadata), so add that form too.
        $suffixWithDot = ".$domainSuffix"
        if ($normalized.Length -gt $suffixWithDot.Length -and $normalized.EndsWith($suffixWithDot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $bareStem = NormalizeUserLookupValue -Value ($normalized.Substring(0, $normalized.Length - $suffixWithDot.Length))
            if (-not [string]::IsNullOrWhiteSpace($bareStem)) {
                $alreadyPresent = $false
                foreach ($existing in $candidates) {
                    if ($existing -ieq $bareStem) { $alreadyPresent = $true; break }
                }
                if (-not $alreadyPresent) {
                    [void]$candidates.Add($bareStem)
                }
            }
        }
    }

    return $candidates.ToArray() | Select-Object -Unique
}

<#
    .SYNOPSIS
        Test whether a user name and a profile folder leaf share an account.

    .DESCRIPTION
        A profile leaf and a user input may describe the same account in
        different forms; comparing candidate sets instead of raw strings
        tolerates that. Domain-joined machines also accept suffixed forms via
        GetUserNameMatchCandidates.

    .PARAMETER UserName
        User-supplied name to compare.

    .PARAMETER ProfileLeaf
        On-disk profile folder leaf name to compare.

    .OUTPUTS
        System.Boolean
#>
function Test-UserNameMatchesProfileLeaf {
    param(
        [string]$UserName,
        [string]$ProfileLeaf
    )

    if ([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($ProfileLeaf)) {
        return $false
    }

    $leafCandidates = @(GetUserNameMatchCandidates -Value $ProfileLeaf)
    $userCandidates = @(GetUserNameMatchCandidates -Value $UserName)

    foreach ($leaf in $leafCandidates) {
        foreach ($user in $userCandidates) {
            if ($leaf -ieq $user) {
                return $true
            }
        }
    }

    return $false
}

<#
    .SYNOPSIS
        Test whether two user-name strings refer to the same account.

    .DESCRIPTION
        Backups record whatever name the running session reported, which may
        not match the restore session's form. Accepting any equivalent
        candidate makes restore work across sessions and machine join states.
        Workgroup stays a strict normalized equality check to avoid broadening
        validation where suffixes aren't meaningful.

    .PARAMETER UserNameA
        First user name to compare.

    .PARAMETER UserNameB
        Second user name to compare.

    .OUTPUTS
        System.Boolean
#>
function Test-UserNameMatch {
    param(
        [string]$UserNameA,
        [string]$UserNameB
    )

    if ([string]::IsNullOrWhiteSpace($UserNameA) -and [string]::IsNullOrWhiteSpace($UserNameB)) {
        return $true
    }
    if ([string]::IsNullOrWhiteSpace($UserNameA) -or [string]::IsNullOrWhiteSpace($UserNameB)) {
        return $false
    }

    # Keep workgroup strict to avoid silently broadening restore scope where no
    # suffix disambiguation exists to justify it.
    if (-not (Test-MachineIsDomainJoined)) {
        $normalizedA = NormalizeUserLookupValue -Value $UserNameA
        $normalizedB = NormalizeUserLookupValue -Value $UserNameB
        return ($normalizedA -ieq $normalizedB)
    }

    $candidatesA = @(GetUserNameMatchCandidates -Value $UserNameA)
    $candidatesB = @(GetUserNameMatchCandidates -Value $UserNameB)

    foreach ($a in $candidatesA) {
        foreach ($b in $candidatesB) {
            if ($a -ieq $b) {
                return $true
            }
        }
    }

    return $false
}

<#
    .SYNOPSIS
        Memoize a resolved SID under every equivalent name form.

    .DESCRIPTION
        SID resolution is expensive and called repeatedly for the same user.
        Memoizing under every equivalent form means later lookups short-circuit
        regardless of which variant the caller has in hand. No-op on blank SID.

    .PARAMETER Candidates
        Equivalent name forms to key the cache entry under.

    .PARAMETER Sid
        Resolved SID to cache.
#>
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

<#
    .SYNOPSIS
        Retrieve a previously cached resolved SID.

    .DESCRIPTION
        Companion to SetResolvedUserSidCache. Checks every equivalent form
        because the caller may only hold one of them, but a prior resolution
        under a different form should still hit. Returns $null on a miss.

    .PARAMETER Candidates
        Equivalent name forms to probe the cache with.

    .OUTPUTS
        System.String
#>
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

<#
    .SYNOPSIS
        Attempt SID resolution via NTAccount translation.

    .DESCRIPTION
        NTAccount.Translate is the most authoritative SID source, but only
        resolves when the name is reachable through standard security APIs.
        Failures fall through to cheaper, broader heuristics in the caller.
        Returns $null on failure.

    .PARAMETER UserName
        Name to translate.

    .OUTPUTS
        System.String
#>
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

<#
    .SYNOPSIS
        Attempt SID resolution against the local account database.

    .DESCRIPTION
        Local SAM and Win32_UserAccount are ground truth for local accounts.
        Prefers Get-LocalUser (typed, fast) and falls back to CIM for older
        hosts or contexts where the cmdlet is unavailable. Returns $null when
        no candidate resolves.

    .PARAMETER Candidates
        Equivalent name forms to try.

    .OUTPUTS
        System.String
#>
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

<#
    .SYNOPSIS
        Recover a SID from the ProfileList registry hive.

    .DESCRIPTION
        Last-resort heuristic: when name-resolution APIs fail, the ProfileList
        hive still links SIDs to on-disk profile folders, so matching the
        folder leaf can recover a SID that no other source would surface.
        Returns $null on failure.

    .PARAMETER Candidates
        Equivalent name forms to match against profile folder leafs.

    .OUTPUTS
        System.String
#>
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
                    if (Test-MachineIsDomainJoined) {
                        if (Test-UserNameMatchesProfileLeaf -UserName $candidate -ProfileLeaf $leafName) {
                            return $sidKey.PSChildName
                        }
                    }
                    elseif ($leafName -ieq $candidate) {
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

<#
    .SYNOPSIS
        Construct a resolved user context object.

    .DESCRIPTION
        Bundles the resolved fields so callers don't re-derive their
        relationship downstream or thread three loose values through every
        call site.

    .PARAMETER UserName
        Normalized user name.

    .PARAMETER UserSid
        Resolved SID, if available.

    .PARAMETER ProfilePath
        Resolved profile folder path.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
#>
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

<#
    .SYNOPSIS
        Resolve a user name to its SID with progressive fallbacks.

    .DESCRIPTION
        Tries the most authoritative sources first and degrades to heuristics
        so the common case is fast and the degenerate case still resolves.
        Qualified identities are pinned to their full form to avoid matching an
        unrelated local account that happens to share the leaf name. Returns
        $null if no source resolves.

    .PARAMETER UserName
        User name to resolve.

    .OUTPUTS
        System.String
#>
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

    # Resolve qualified identities via their full form first; using the bare
    # leaf here would risk matching an unrelated local account that shares it.
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

    # Last-ditch NTAccount translation for non-qualified names; qualified names
    # already tried this path above.
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

<#
    .SYNOPSIS
        Resolve a user name to its profile folder path.

    .DESCRIPTION
        Convenience wrapper around ResolveUserProfileContext: most callers
        need only the path and shouldn't have to unwrap the context object
        themselves. Returns $null if no profile is found.

    .PARAMETER UserName
        User name whose profile path is required.

    .OUTPUTS
        System.String
#>
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

<#
    .SYNOPSIS
        Resolve a user name to a full profile context (name, SID, path).

    .DESCRIPTION
        Resolves via SID-keyed registry data first (authoritative), then
        degrades to on-disk path probing so resolution still succeeds when the
        account or SID can't be looked up (e.g. deleted account, restricted
        execution context). Returns $null if no profile is found.

    .PARAMETER UserName
        User name whose profile context is required.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
#>
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

        # Exact leaf match is the common case and avoids an unnecessary scan.
        $candidateUserPath = Join-Path $rootPath $candidateUserName
        if (Test-Path -LiteralPath $candidateUserPath -PathType Container) {
            return (NewResolvedUserContext -UserName $candidateUserName -UserSid $userSid -ProfilePath $candidateUserPath)
        }

        # Only domain-joined boxes can write suffixed folders, so only scan there;
        # scanning workgroup roots would risk matching the wrong account.
        if (Test-MachineIsDomainJoined) {
            try {
                foreach ($child in @(Get-ChildItem -LiteralPath $rootPath -Directory -ErrorAction SilentlyContinue)) {
                    if (Test-UserNameMatchesProfileLeaf -UserName $candidateUserName -ProfileLeaf $child.Name) {
                        return (NewResolvedUserContext -UserName $candidateUserName -UserSid $userSid -ProfilePath $child.FullName)
                    }
                }
            }
            catch {
                # Fall through to the next root path.
            }
        }
    }

    return $null
}