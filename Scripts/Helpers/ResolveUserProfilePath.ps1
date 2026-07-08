<#
    .SYNOPSIS
        Normalize a user-name string for lookup and comparison.

    .DESCRIPTION
        Strips zero-width chars and collapses whitespace so cosmetic input
        differences don't break downstream lookups. Returns '' for blank input.

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
        Normalized + lower-cased so the same identity hits regardless of
        case, whitespace, or qualifier form. Returns '' for blank input.

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
        Normalize and de-duplicate a set of user-name candidates.

    .DESCRIPTION
        Centralizes the normalize/filter/dedupe step shared by the SID
        resolution fallbacks so the dedupe semantic lives in one place.
        Returns @() for empty or all-blank input.

    .PARAMETER Candidates
        Equivalent name forms to normalize.

    .OUTPUTS
        System.String[]
#>
function GetNormalizedLookupCandidates {
    param(
        [string[]]$Candidates
    )

    $normalized = @($Candidates) |
        ForEach-Object { NormalizeUserLookupValue -Value $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    # The unary comma prevents PowerShell from unwrapping a single-element array.
    return ,@($normalized)
}

<#
    .SYNOPSIS
        Escape a string for safe embedding in a WQL single-quoted literal.

    .DESCRIPTION
        Doubles embedded single quotes; without this a user name containing
        an apostrophe could break the WQL filter.

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
        Reduces DOMAIN\user or user@domain to the bare leaf, since profile
        folder leafs never carry the domain prefix. Returns '' for blank input.

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
        Reduce a Win32_ComputerSystem.Domain value to a NetBIOS label.

    .DESCRIPTION
        Win32_ComputerSystem.Domain may be DNS-style (e.g. contoso.com);
        prefer Win32_NTDomain.DomainName and fall back to the first DNS label
        so cached suffixes stay single-label (user.CONTOSO, not
        user.contoso.com). Returns the trimmed value as-is when already a
        single label. Falls back safely (no match) for FQDNs like
        corp.contoso.com whose NetBIOS label is CONTOSO.

    .PARAMETER RawDomain
        Value reported by Win32_ComputerSystem.Domain.

    .OUTPUTS
        System.String
#>
function ResolveNetBiosDomainName {
    param(
        [string]$RawDomain
    )

    $trimmed = NormalizeUserLookupValue -Value $RawDomain
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return ''
    }

    try {
        # Prefer the joined-domain instance over the local SAM shadow
        # (DomainName == COMPUTERNAME); DomainControllerName may be $null.
        $computerName = $env:COMPUTERNAME
        $ntDomainInstances = @(Get-CimInstance -ClassName Win32_NTDomain -OperationTimeoutSec 5 -ErrorAction Stop |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.DomainName) -and
                $_.DomainName -ine 'WORKGROUP' -and
                $_.DomainName -ine $computerName
            })

        $ntDomainInstance = $ntDomainInstances |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.DomainControllerName) } |
            Select-Object -First 1
        if (-not $ntDomainInstance -and $ntDomainInstances.Count -gt 0) {
            $ntDomainInstance = $ntDomainInstances | Select-Object -First 1
        }

        if ($ntDomainInstance -and -not [string]::IsNullOrWhiteSpace($ntDomainInstance.DomainName)) {
            $fromNtDomain = NormalizeUserLookupValue -Value $ntDomainInstance.DomainName
            if (-not [string]::IsNullOrWhiteSpace($fromNtDomain)) {
                return $fromNtDomain
            }
        }
    }
    catch {
        # Fall through to DNS-label derivation.
    }

    if ($trimmed.Contains('.')) {
        $leaf = NormalizeUserLookupValue -Value (($trimmed -split '\.')[0])
        if (-not [string]::IsNullOrWhiteSpace($leaf)) {
            return $leaf
        }
    }

    return $trimmed
}

<#
    .SYNOPSIS
        Determine whether the local machine is joined to a domain.

    .DESCRIPTION
        Cached in script scope for the process lifetime. Returns $false on
        error or workgroup. When joined, also caches the NetBIOS domain label
        (ResolveNetBiosDomainName) for use as a profile-folder suffix.

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
            $script:MachineNetBiosDomain = ResolveNetBiosDomainName -RawDomain ([string]$computerSystem.Domain)
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
        user.CONTOSO; knowing the suffix lets a bare name match that folder.
        Excluded on workgroup (USERDOMAIN == COMPUTERNAME) to avoid false
        matches. Returns '' when not applicable.

    .OUTPUTS
        System.String
#>
function GetProfileFolderDomainSuffix {
    if (-not (Test-MachineIsDomainJoined)) {
        return ''
    }

    $domain = $env:USERDOMAIN
    if ([string]::IsNullOrWhiteSpace($domain)) {
        # USERDOMAIN can be empty in restricted contexts; fall back to the
        # cached NetBIOS label (single-label, safe as a folder suffix).
        $domain = $script:MachineNetBiosDomain
    }
    if ([string]::IsNullOrWhiteSpace($domain)) {
        return ''
    }

    # USERDOMAIN == COMPUTERNAME means effectively standalone; a suffix here
    # would produce false matches instead of disambiguation.
    if ($domain -ieq $env:COMPUTERNAME) {
        return ''
    }

    return $domain.Trim()
}

<#
    .SYNOPSIS
        Enumerate the name forms equivalent to a given identity.

    .DESCRIPTION
        One identity surfaces in different forms (bare, qualified,
        domain-suffixed); enumerating equivalents lets cross-source matching
        succeed without broadening workgroup validation. Returns @() for blank.

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

    # Domain-suffixed forms only apply where Windows writes them.
    $domainSuffix = GetProfileFolderDomainSuffix
    if (-not [string]::IsNullOrWhiteSpace($domainSuffix)) {
        # Prefer the local segment as the stem so DOMAIN\user still yields
        # user.CONTOSO rather than the fully qualified string.
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
        Compares candidate sets (via GetUserNameMatchCandidates) instead of
        raw strings, so different forms of the same account still match.

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
        Accepts any equivalent candidate form so restore works across
        sessions and join states. Workgroup stays a strict normalized equality
        check to avoid broadening validation where suffixes aren't meaningful.

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

    # Workgroup: strict equality (no suffix disambiguation available).
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
        Keyed under all equivalent forms so later lookups short-circuit
        regardless of which variant the caller holds. No-op on blank SID.

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
        Probes every equivalent form; returns $null on a miss.

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
        Most authoritative name->SID source; only resolves names reachable
        through standard security APIs. Returns $null on failure.

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
        Prefers Get-LocalUser (typed, fast), falls back to Win32_UserAccount
        CIM for older hosts or unavailable cmdlet. Returns $null if no match.

    .PARAMETER Candidates
        Equivalent name forms to try.

    .OUTPUTS
        System.String
#>
function TryResolveSidByLocalLookup {
    param(
        [string[]]$Candidates
    )

    $lookupCandidates = GetNormalizedLookupCandidates -Candidates $Candidates
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
        Last-resort heuristic: matches the profile folder leaf to recover a
        SID when name-resolution APIs fail. Returns $null on failure.

    .PARAMETER Candidates
        Equivalent name forms to match against profile folder leafs.

    .OUTPUTS
        System.String
#>
function TryResolveSidFromProfileList {
    param(
        [string[]]$Candidates
    )

    $lookupCandidates = GetNormalizedLookupCandidates -Candidates $Candidates
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
        Bundles UserName/UserSid/ProfilePath so callers don't re-derive or
        thread three loose values.

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
        Return the qualified (DOMAIN\user) name of the current process when it matches the input.

    .DESCRIPTION
        Used to qualify a bare name on domain-joined boxes; returns $null when
        the input doesn't match the current process identity.

    .PARAMETER Candidate
        Bare user name to compare against the current process identity.

    .OUTPUTS
        System.String
#>
function GetQualifiedProcessIdentityName {
    param(
        [string]$Candidate
    )

    $normalizedCandidate = NormalizeUserLookupValue -Value $Candidate
    if ([string]::IsNullOrWhiteSpace($normalizedCandidate)) {
        return $null
    }

    try {
        $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($null -eq $currentIdentity) {
            return $null
        }

        # Skip service/SYSTEM identities (no user profile).
        $currentSidString = [string]$currentIdentity.User.Value
        if ($currentSidString -in @('S-1-5-18', 'S-1-5-19', 'S-1-5-20')) {
            return $null
        }

        $currentName = [string]$currentIdentity.Name
        if ([string]::IsNullOrWhiteSpace($currentName)) {
            return $null
        }

        $currentLocalSegment = GetLocalUserNameSegment -UserName $currentName
        if (-not [string]::IsNullOrWhiteSpace($currentLocalSegment) -and $currentLocalSegment -ieq $normalizedCandidate) {
            return $currentName
        }
    }
    catch {
        # Fall through to name-based resolution.
    }

    return $null
}

<#
    .SYNOPSIS
        Resolve a user name to its SID.

    .DESCRIPTION
        Always qualifies the input first (DOMAIN\user) and resolves that form;
        never guesses from a bare name on domain-joined boxes to avoid
        same-named local SAM shadowing.

    .PARAMETER UserName
        User name to resolve. May be bare, DOMAIN\user, or user@domain.

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

    # Unqualified inputs probe both the bare name and (for qualified inputs) the
    # local leaf segment; qualified inputs pin to the caller's full form only.
    $lookupCandidates = if ($hasQualifiedIdentity) {
        @($candidateUserName)
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

    $cachedSid = GetCachedResolvedUserSid -Candidates $lookupCandidates
    if ($cachedSid) {
        return $cachedSid
    }

    # Step 1: derive the qualified form(s) to resolve; never guess from a bare
    # name on domain-joined boxes (local SAM nameshare risk).
    $qualifiedNamesToTry = New-Object 'System.Collections.Generic.List[string]'

    if ($hasQualifiedIdentity) {
        # Caller already qualified; honor verbatim.
        [void]$qualifiedNamesToTry.Add($candidateUserName)
    }
    elseif (Test-MachineIsDomainJoined) {
        # Prefer process identity (authoritative), then USERDOMAIN\input.
        $processQualifiedName = GetQualifiedProcessIdentityName -Candidate $candidateUserName
        if (-not [string]::IsNullOrWhiteSpace($processQualifiedName)) {
            [void]$qualifiedNamesToTry.Add($processQualifiedName)
        }

        $domainSuffix = GetProfileFolderDomainSuffix
        if (-not [string]::IsNullOrWhiteSpace($domainSuffix)) {
            $domainQualifiedName = "$domainSuffix\$candidateUserName"
            if (-not ($qualifiedNamesToTry -contains $domainQualifiedName)) {
                [void]$qualifiedNamesToTry.Add($domainQualifiedName)
            }
        }
    }
    else {
        # Workgroup: bare name is unambiguous.
        [void]$qualifiedNamesToTry.Add($candidateUserName)
    }

    # Step 2: resolve qualified form(s) via NTAccount.Translate.
    foreach ($qualifiedName in $qualifiedNamesToTry) {
        $resolvedSid = TryResolveSidByNtAccount -UserName $qualifiedName
        if ($resolvedSid) {
            $allCacheKeys = @($candidateUserName) + $qualifiedNamesToTry | Select-Object -Unique
            SetResolvedUserSidCache -Candidates $allCacheKeys -Sid $resolvedSid
            return $resolvedSid
        }
    }

    # Step 3: local SAM fallback (workgroup only; skipped on domain to avoid
    # nameshare shadowing).
    if (-not (Test-MachineIsDomainJoined)) {
        $resolvedSid = TryResolveSidByLocalLookup -Candidates $lookupCandidates
        if ($resolvedSid) {
            $allCacheKeys = @($candidateUserName) + $qualifiedNamesToTry | Select-Object -Unique
            SetResolvedUserSidCache -Candidates $allCacheKeys -Sid $resolvedSid
            return $resolvedSid
        }
    }

    # Step 4: ProfileList leaf heuristic (last resort; disambiguates by
    # on-disk folder name, suffix-aware on domain boxes).
    $resolvedSid = TryResolveSidFromProfileList -Candidates $profileHeuristicCandidates
    if ($resolvedSid) {
        $allCacheKeys = @($candidateUserName) + $qualifiedNamesToTry | Select-Object -Unique
        SetResolvedUserSidCache -Candidates $allCacheKeys -Sid $resolvedSid
        return $resolvedSid
    }

    return $null
}

<#
    .SYNOPSIS
        Resolve a user name to a full profile context (name, SID, path).

    .DESCRIPTION
        SID-keyed registry data first (authoritative), then on-disk path
        probing so resolution still succeeds when the account or SID can't be
        looked up (deleted account, restricted context). Returns $null if not
        found.

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

    $candidateUserName = NormalizeUserLookupValue -Value $UserName
    if ([string]::IsNullOrWhiteSpace($candidateUserName)) {
        return $null
    }

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

        # Exact leaf match first (common case; avoids an unnecessary scan).
        $candidateUserPath = Join-Path $rootPath $candidateUserName
        if (Test-Path -LiteralPath $candidateUserPath -PathType Container) {
            return (NewResolvedUserContext -UserName $candidateUserName -UserSid $userSid -ProfilePath $candidateUserPath)
        }

        # Only domain-joined boxes write suffixed folders; scanning workgroup
        # roots would risk matching the wrong account.
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