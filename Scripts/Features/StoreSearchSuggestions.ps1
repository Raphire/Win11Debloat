<#
    .SYNOPSIS
    Disables Microsoft Store search suggestions in the start menu for all user profiles.

    .DESCRIPTION
    Iterates over every existing user profile and the Default user profile,
    denying the EVERYONE group FullControl access to each user's Store app
    database file (store.db). This prevents Windows from showing Store search
    suggestions in the start menu search pane.

    .EXAMPLE
    DisableStoreSearchSuggestionsForAllUsers
#>
function DisableStoreSearchSuggestionsForAllUsers {
    # Get path to Store app database for all users
    $userPathString = GetUserDirectory -userName "*" -fileName "AppData\Local\Packages"
    $usersStoreDbPaths = Get-ChildItem -Path $userPathString -ErrorAction SilentlyContinue

    # Go through all users and disable start search suggestions
    foreach ($storeDbPath in $usersStoreDbPaths) {
        DisableStoreSearchSuggestions -StoreAppsDatabase ($storeDbPath.FullName + "\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db")
    }

    # Also disable start search suggestions for the default user profile
    $defaultStoreDbPath = GetStoreAppsDatabasePathForUser -UserName "Default"
    if ($defaultStoreDbPath) {
        DisableStoreSearchSuggestions -StoreAppsDatabase $defaultStoreDbPath
    }
}


<#
    .SYNOPSIS
    Disables Microsoft Store search suggestions for a single user.

    .DESCRIPTION
    Denies the EVERYONE group FullControl access to the specified Store app
    database file (store.db). If the file does not exist (e.g. on EEA systems
    where Store app suggestions are absent by default), it creates the file
    and its parent directory first to prevent Windows from recreating it later.

    .PARAMETER StoreAppsDatabase
    The full path to the user's store.db file.

    .EXAMPLE
    DisableStoreSearchSuggestions -StoreAppsDatabase "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
#>
function DisableStoreSearchSuggestions {
    param (
        [Parameter(Mandatory)]
        [string]$StoreAppsDatabase
    )

    $userName = [regex]::Match($StoreAppsDatabase, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value
    if (-not $userName) { $userName = '<unknown>' }

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Disable Microsoft Store search suggestions for user $userName by restricting access to ${StoreAppsDatabase}" -ForegroundColor Cyan
        return
    }

    # This file doesn't exist in EEA (No Store app suggestions).
    if (-not (Test-Path -Path $StoreAppsDatabase))
    {
        Write-Host "Unable to find Store app database for user $userName, creating it now to prevent Windows from creating it later..." -ForegroundColor Yellow

        $storeDbDir = Split-Path -Path $StoreAppsDatabase -Parent

        if (-not (Test-Path -Path $storeDbDir)) {
            New-Item -Path $storeDbDir -ItemType Directory -Force | Out-Null
        }

        New-Item -Path $StoreAppsDatabase -ItemType File -Force | Out-Null
    }
    
    $AccountSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-1-0') # 'EVERYONE' group
    $Acl = Get-Acl -Path $StoreAppsDatabase
    $Ace = [System.Security.AccessControl.FileSystemAccessRule]::new($AccountSid, 'FullControl', 'Deny')
    $Acl.SetAccessRule($Ace) | Out-Null
    Set-Acl -Path $StoreAppsDatabase -AclObject $Acl | Out-Null

    Write-Host "Disabled Microsoft Store search suggestions for user $userName"
}

<#
    .SYNOPSIS
    Re-enables Microsoft Store search suggestions in the start menu for all user profiles.

    .DESCRIPTION
    Iterates over every existing user profile and the Default user profile,
    removing the deny ACL from each user's Store app database file (store.db)
    and then deleting the file. This restores the default Windows behavior
    where Store search suggestions appear in the start menu.

    .EXAMPLE
    EnableStoreSearchSuggestionsForAllUsers
#>
function EnableStoreSearchSuggestionsForAllUsers {
    # Get path to Store app database for all users
    $userPathString = GetUserDirectory -userName "*" -fileName "AppData\Local\Packages"
    $usersStoreDbPaths = Get-ChildItem -Path $userPathString -ErrorAction SilentlyContinue

    # Go through all users and re-enable start search suggestions
    foreach ($storeDbPath in $usersStoreDbPaths) {
        EnableStoreSearchSuggestions -StoreAppsDatabase ($storeDbPath.FullName + "\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db")
    }

    # Also re-enable for the default user profile
    $defaultStoreDbPath = GetStoreAppsDatabasePathForUser -UserName "Default"
    if ($defaultStoreDbPath) {
        EnableStoreSearchSuggestions -StoreAppsDatabase $defaultStoreDbPath
    }
}

<#
    .SYNOPSIS
    Re-enables Microsoft Store search suggestions for a single user.

    .DESCRIPTION
    Takes ownership of the specified Store app database file, removes any
    EVERYONE deny FullControl ACL entries, and deletes the file. If the file
    does not exist, no action is taken. Callers should handle the case where
    the file is absent gracefully.

    .PARAMETER StoreAppsDatabase
    The full path to the user's store.db file.

    .EXAMPLE
    EnableStoreSearchSuggestions -StoreAppsDatabase "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
#>
function EnableStoreSearchSuggestions {
    param (
        [Parameter(Mandatory)]
        [string]$StoreAppsDatabase
    )

    $userName = [regex]::Match($StoreAppsDatabase, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value
    if (-not $userName) { $userName = '<unknown>' }

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Re-enable Microsoft Store search suggestions for user $userName by restoring access to ${StoreAppsDatabase}" -ForegroundColor Cyan
        return
    }

    if (-not (Test-Path -Path $StoreAppsDatabase)) {
        Write-Host "Store app database not found for user $userName, nothing to undo"
        return
    }

    # Ensure we can modify/delete the file even if restrictive ACLs were set.
    $global:LASTEXITCODE = 0
    takeown /F "$StoreAppsDatabase" /A | Out-Null
    icacls "$StoreAppsDatabase" /grant *S-1-5-32-544:F /C | Out-Null

    $everyoneSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-1-0') # 'EVERYONE' group

    try {
        $acl = Get-Acl -Path $StoreAppsDatabase
        $denyRules = @(
            $acl.Access | Where-Object {
                if ($_.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Deny) { return $false }
                if (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq 0) { return $false }
                try {
                    return ($_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]) -eq $everyoneSid)
                }
                catch {
                    return $false
                }
            }
        )

        foreach ($denyRule in $denyRules) {
            $null = $acl.RemoveAccessRuleSpecific($denyRule)
        }

        Set-Acl -Path $StoreAppsDatabase -AclObject $acl | Out-Null
    }
    catch {
        Write-Warning "Failed to normalize ACL for store database '$StoreAppsDatabase': $($_.Exception.Message)"
    }

    try {
        Remove-Item -Path $StoreAppsDatabase -Force -ErrorAction Stop
        Write-Host "Re-enabled Microsoft Store search suggestions for user $userName"
    }
    catch {
        throw "Failed to remove '$StoreAppsDatabase' while undoing Microsoft Store search suggestions for user $userName. $($_.Exception.Message)"
    }
}

<#
    .SYNOPSIS
    Returns the full path to the Store app database file for a given user.

    .DESCRIPTION
    Resolves the path to the Microsoft Store app database (store.db) for the
    specified username. When no username is provided or the value is empty,
    falls back to the current user's local app data path via $env:LOCALAPPDATA.

    .PARAMETER UserName
    The target username. Pass an empty string or omit to resolve for the current user.

    .EXAMPLE
    GetStoreAppsDatabasePathForUser -UserName "Jeff"

    .EXAMPLE
    GetStoreAppsDatabasePathForUser -UserName "Default"
#>
function GetStoreAppsDatabasePathForUser {
    param(
        [string]$UserName
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
    }

    return (GetUserDirectory -userName $UserName -fileName "AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db" -exitIfPathNotFound $false)
}

<#
    .SYNOPSIS
    Tests whether Store search suggestions are disabled for a single user.

    .DESCRIPTION
    Checks whether the specified store.db file has an EVERYONE deny
    FullControl ACL entry applied. Returns $true if the deny rule is present,
    $false otherwise (including when the file or directory does not exist).

    .PARAMETER StoreAppsDatabase
    The full path to the user's store.db file.

    .EXAMPLE
    Test-StoreSearchSuggestionsDisabled -StoreAppsDatabase "C:\Users\Jeff\AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
#>
function Test-StoreSearchSuggestionsDisabled {
    param(
        [Parameter(Mandatory)]
        [string]$StoreAppsDatabase
    )

    if (-not (Test-Path -Path $StoreAppsDatabase)) {
        return $false
    }

    try {
        $acl = Get-Acl -Path $StoreAppsDatabase
    }
    catch {
        return $false
    }

    $everyoneSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-1-0')

    foreach ($accessRule in @($acl.Access)) {
        $isDenyFullControl = $accessRule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
            (($accessRule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0)
        if (-not $isDenyFullControl) { continue }

        $isEveryone = $false
        try {
            $isEveryone = $accessRule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]) -eq $everyoneSid
        }
        catch { }

        if ($isEveryone) {
            return $true
        }
    }

    return $false
}

<#
    .SYNOPSIS
    Tests whether Store search suggestions are disabled for all user profiles.

    .DESCRIPTION
    Collects the store.db paths for all existing user profiles and the Default
    user profile, then verifies that every one of them has the EVERYONE deny
    FullControl ACL applied. Returns $true only if ALL paths pass the check.
    Returns $false immediately if any user's store.db is not disabled.

    .EXAMPLE
    Test-StoreSearchSuggestionsDisabledForAllUsers
#>
function Test-StoreSearchSuggestionsDisabledForAllUsers {
    $paths = @()

    $userPathString = GetUserDirectory -userName "*" -fileName "AppData\Local\Packages"
    $usersStoreDbPaths = Get-ChildItem -Path $userPathString -ErrorAction SilentlyContinue
    foreach ($storeDbPath in $usersStoreDbPaths) {
        $paths += ($storeDbPath.FullName + "\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db")
    }

    $defaultStoreDbPath = GetStoreAppsDatabasePathForUser -UserName "Default"
    if ($defaultStoreDbPath) {
        $paths += $defaultStoreDbPath
    }

    if ($paths.Count -eq 0) {
        return $false
    }

    foreach ($path in $paths) {
        if (-not (Test-StoreSearchSuggestionsDisabled -StoreAppsDatabase $path)) {
            return $false
        }
    }

    return $true
}