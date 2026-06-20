# Disables Microsoft Store search suggestions in the start menu for all users by denying access to the Store app database file for each user
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
    DisableStoreSearchSuggestions -StoreAppsDatabase $defaultStoreDbPath
}


# Disables Microsoft Store search suggestions in the start menu by denying access to the Store app database file
function DisableStoreSearchSuggestions {
    param (
        [Parameter(Mandatory)]
        [string]$StoreAppsDatabase
    )

    $userName = [regex]::Match($StoreAppsDatabase, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value
    if (-not $userName) { $userName = '<unknown>' }

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
    EnableStoreSearchSuggestions -StoreAppsDatabase $defaultStoreDbPath
}

function EnableStoreSearchSuggestions {
    param (
        [Parameter(Mandatory)]
        [string]$StoreAppsDatabase
    )

    $userName = [regex]::Match($StoreAppsDatabase, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value
    if (-not $userName) { $userName = '<unknown>' }

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
                $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
                (($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0) -and
                (try { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]) -eq $everyoneSid } catch { $false })
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

function GetStoreAppsDatabasePathForUser {
    param(
        [string]$UserName
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
    }

    return (GetUserDirectory -userName $UserName -fileName "AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db" -exitIfPathNotFound $false)
}

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
        } catch { }

        if ($isEveryone) {
            return $true
        }
    }

    return $false
}

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