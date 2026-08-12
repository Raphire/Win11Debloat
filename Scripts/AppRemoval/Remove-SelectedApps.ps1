<#
    .SYNOPSIS
    Removes one or more Windows app packages based on the target scope.

    .DESCRIPTION
    Iterates over the provided list of app identifiers and removes each one.
    The removal method (winget vs. Appx cmdlets) is determined per-app from
    Apps.json. A scheduled task is only created when the User or Sysprep
    parameter was passed. After winget removal, the system is checked to 
    confirm whether the app is still installed before reporting an error.
    Returns early if the CancelRequested flag is set.

    .PARAMETER appsList
    An array of app package identifiers to remove (e.g. 'Microsoft.BingNews').

    .EXAMPLE
    Remove-SelectedApps @('Microsoft.BingNews', 'Microsoft.BingWeather')

    .EXAMPLE
    Remove-SelectedApps -appsList (Generate-AppsList)
#>
function Remove-SelectedApps {
    param (
        $appslist
    )

    if ($script:Params.ContainsKey("WhatIf")) {
        foreach ($app in $appslist) {
            Write-Host "[WhatIf] Remove App Package: $app" -ForegroundColor Cyan
        }

        Write-Host ""
        return
    }

    $targetUser = Get-TargetUserForAppRemoval
    $appCount = @($appsList).Count
    $appIndex = 0

    $edgeIds = @('Microsoft.Edge', 'XPFFTQ037JWMHS')
    $wingetRemovedApps = @()
    $wingetRemovalFailures = @{}

    Foreach ($app in $appsList) {
        if ($script:CancelRequested) { return }

        $appIndex++

        if ($script:ApplySubStepCallback -and $appCount -gt 1) {
            & $script:ApplySubStepCallback "Removing apps ($appIndex/$appCount)" $appIndex $appCount
        }

        Write-Host "Removing $app"

        if ((Get-AppRemovalMethod $app) -eq 'WinGet') {
            if (-not (Remove-WinGetApp -app $app)) {
                $wingetRemovalFailures[$app] = $true
            }
            $wingetRemovedApps += $app
        }
        else {
            if (-not (Remove-AppxApp -app $app -targetUser $targetUser)) {
                $script:AppRemovalFailures++
            }
        }
    }

    if ($script:CancelRequested) {
        Write-Host ""
        return
    }

    # Check whether any winget-removed apps are still present, and report errors for each one.
    if ($wingetRemovedApps.Count -gt 0) {
        $target = $targetUser
        if ($targetUser -notin @('AllUsers', 'CurrentUser')) {
            try {
                $userContext = Resolve-UserProfileContext -UserName $targetUser
                if ($userContext -and -not [string]::IsNullOrWhiteSpace([string]$userContext.UserSid)) {
                    $target = $userContext.UserSid
                }
                else {
                    $target = 'AllUsers'
                    Write-Warning "Unable to resolve a SID for target user '$targetUser'; falling back to all-user Appx verification."
                }
            }
            catch {
                $target = 'AllUsers'
                Write-Warning "Unable to resolve target user '$targetUser' for Appx verification; falling back to all users: $_"
            }
        }

        $postRemovalList = if ($script:WingetInstalled) { Get-WingetInstalledApps -TimeOut 10 -NonBlocking } else { $null }
        $edgeForceRemoveRequested = $false

        foreach ($app in $wingetRemovedApps) {
            if (-not (Test-AppStillInstalled -appId $app -target $target -InstalledList $postRemovalList)) {
                continue
            }

            if ($edgeIds -contains $app) {
                Write-Host "Unable to uninstall Microsoft Edge via WinGet" -ForegroundColor Red
                if (-not $edgeForceRemoveRequested) {
                    Request-EdgeForceRemove
                    $edgeForceRemoveRequested = $true
                }
            }
            else {
                Write-Host "Unable to uninstall $app via WinGet" -ForegroundColor Red
            }
            $wingetRemovalFailures[$app] = $true
        }
    }

    $script:AppRemovalFailures += $wingetRemovalFailures.Count

    Write-Host ""
}

<#
    .SYNOPSIS
    Uninstalls an app via WinGet and/or schedules its removal.

    .DESCRIPTION
    Runs winget uninstall for a single app, with a bounded execution time.
    If the User or Sysprep parameter was passed, also schedules removal for
    future logins.

    .PARAMETER app
    The WinGet package ID to uninstall (e.g. 'Microsoft.BingNews').

    .PARAMETER TimeoutSeconds
    Maximum time to allow the foreground WinGet uninstall to run. Defaults
    to 120 seconds.
#>
function Remove-WinGetApp {
    param(
        [string]$app,
        [int]$TimeoutSeconds = 120
    )

    if (-not $script:WingetInstalled) {
        Write-Error "WinGet is either not installed or is outdated; $app could not be removed"
        return $false
    }

    $uninstallSucceeded = $true
    try {
        $uninstallSucceeded = Invoke-NonBlocking -ScriptBlock {
            param($appId)
            $null = & winget uninstall --accept-source-agreements --disable-interactivity --id $appId 2>&1
            return $true
        } -ArgumentList $app -TimeoutSeconds $TimeoutSeconds
        $uninstallSucceeded = [bool]$uninstallSucceeded
    }
    catch {
        $uninstallSucceeded = $false
        if ($_.Exception.Message -like 'Operation timed out after *') {
            Write-Error "WinGet uninstall for $app did not complete within $TimeoutSeconds seconds: $_"
        }
        else {
            Write-Error "WinGet uninstall for $app failed: $_"
        }
    }

    $scheduleSucceeded = $true
    if ($script:Params.ContainsKey("User")) {
        Write-Host "Adding scheduled task to uninstall $app for user $(Get-UserName)..."
        $scheduleSucceeded = Set-RunOnceWingetTask -appId $app
    }
    elseif ($script:Params.ContainsKey("Sysprep")) {
        Write-Host "Adding scheduled task to uninstall $app for new users..."
        $scheduleSucceeded = Set-RunOnceWingetTask -appId $app
    }

    return ($uninstallSucceeded -and $scheduleSucceeded)
}

<#
    .SYNOPSIS
    Removes an app via Remove-AppxPackage / Remove-ProvisionedAppxPackage.

    .PARAMETER app
    The package identifier to remove (e.g. 'Clipchamp.Clipchamp').

    .PARAMETER targetUser
    Target scope: "AllUsers", "CurrentUser", or a specific username.
#>
function Remove-AppxApp {
    param([string]$app, [string]$targetUser)

    $appPattern = '*' + $app + '*'

    try {
        $removalResult = Invoke-NonBlocking -ScriptBlock {
            param($pattern, $target)

            $removalErrors = @()
            $getPackageParams = @{ Name = $pattern; ErrorAction = 'Continue'; ErrorVariable = '+removalErrors' }
            $removePackageParams = @{ ErrorAction = 'Continue'; ErrorVariable = '+removalErrors' }

            switch ($target) {
                'AllUsers' {
                    $getPackageParams.AllUsers = $true
                    $removePackageParams.AllUsers = $true
                }
                'CurrentUser' { }
                default {
                    $userAccount = New-Object System.Security.Principal.NTAccount($target)
                    $userSid = $userAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
                    $getPackageParams.User = $userSid
                    $removePackageParams.User = $userSid
                }
            }

            foreach ($package in @(Get-AppxPackage @getPackageParams)) {
                $removePackageParams.Package = $package.PackageFullName
                $null = Remove-AppxPackage @removePackageParams
            }

            if ($target -eq 'AllUsers') {
                $provisionedPackages = @(Get-AppxProvisionedPackage -Online -ErrorAction Continue -ErrorVariable +removalErrors | Where-Object { $_.PackageName -like $pattern })
                foreach ($package in $provisionedPackages) {
                    $null = Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $package.PackageName -ErrorAction Continue -ErrorVariable +removalErrors
                }
            }

            return [PSCustomObject]@{ Success = ($removalErrors.Count -eq 0) }
        } -ArgumentList @($appPattern, $targetUser)
    }
    catch {
        Write-Error "Unable to remove $app via Appx: $_"
        return $false
    }

    return [bool]($removalResult -and $removalResult.Success)
}

<#
    .SYNOPSIS
    Checks whether an app package is still installed after a removal attempt.

    .DESCRIPTION
    Checks Get-AppxPackage in the requested removal scope first, then falls
    back to a pre-fetched or live winget list for non-Appx packages.
    Uses Test-AppInWingetList which provides exact-match-first with substring
    fallback against the parsed winget objects.
    Returns $true if the app is still present, $false otherwise.

    .PARAMETER appId
    The package identifier to check (e.g. 'Microsoft.BingNews').

    .PARAMETER target
    Appx verification scope: "AllUsers", "CurrentUser", or a resolved user SID.

    .PARAMETER InstalledList
    Optional pre-fetched array of winget objects from Get-WingetInstalledApps.
    When provided, used directly; otherwise a live winget call is made.
#>
function Test-AppStillInstalled {
    param(
        [string]$appId,
        [string]$target = 'AllUsers',
        [object[]]$InstalledList
    )

    try {
        # Check Get-AppxPackage in the requested removal scope first.
        $appxPackage = if ($target -eq 'AllUsers') {
            Get-AppxPackage -Name $appId -AllUsers -ErrorAction SilentlyContinue
        }
        elseif ($target -eq 'CurrentUser') {
            Get-AppxPackage -Name $appId -ErrorAction SilentlyContinue
        }
        elseif (-not [string]::IsNullOrWhiteSpace($target)) {
            Get-AppxPackage -Name $appId -User $target -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Warning "Unable to check if '$appId' is still installed via Get-AppxPackage for '$target': $_"
    }

    if ($appxPackage) {
        return $true
    }

    # Use the pre-fetched list if provided; otherwise fall back to a live winget call.
    if ($InstalledList) {
        return (Test-AppInWingetList -appId $appId -InstalledList $InstalledList)
    }

    if ($script:WingetInstalled) {
        $liveList = Get-WingetInstalledApps -TimeOut 10 -NonBlocking
        if (Test-AppInWingetList -appId $appId -InstalledList $liveList) {
            return $true
        }
    }
    else {
        Write-Warning "Unable to verify whether '$appId' is still installed (WinGet is unavailable)"
    }

    return $false
}

<#
    .SYNOPSIS
    Returns the removal method for an app identifier.

    .DESCRIPTION
    Parses Apps.json once (cached in script scope) to build a lookup of
    AppId -> RemovalMethod. Returns 'WinGet' if the app should be removed
    via winget, or 'Appx' if via Remove-AppxPackage. Defaults to 'Appx'
    for unknown IDs.

    .PARAMETER appId
    The package identifier (e.g. 'Clipchamp.Clipchamp').
#>
function Get-AppRemovalMethod {
    param([string]$appId)

    if (-not $script:AppRemovalMethodCache) {
        $script:AppRemovalMethodCache = @{}
        try {
            if (Test-Path $script:AppsListFilePath) {
                $appsJson = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
                foreach ($appData in $appsJson.Apps) {
                    $rawMethod = $appData.RemovalMethod
                    $method = if ($rawMethod -and $rawMethod -eq 'WinGet') { 'WinGet' } else { 'Appx' }
                    foreach ($id in @($appData.AppId)) {
                        if ($id -isnot [string]) { continue }
                        $normalizedId = $id.Trim()
                        if (-not [string]::IsNullOrWhiteSpace($normalizedId)) {
                            $script:AppRemovalMethodCache[$normalizedId] = $method
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to load app removal methods from '$script:AppsListFilePath'. Defaulting unknown apps to Appx. Error: $_"
        }
    }

    if ($script:AppRemovalMethodCache.ContainsKey($appId)) {
        return $script:AppRemovalMethodCache[$appId]
    }
    return 'Appx'
}

<#
    .SYNOPSIS
    Prompts the user to forcefully remove Microsoft Edge when winget cannot uninstall it.

    .DESCRIPTION
    Only invoked after it has been confirmed that Edge is still present
    following all winget uninstall attempts. In GUI mode, displays a
    warning message box; in CLI mode, prompts via Read-Host. On
    confirmation, performs a force-remove of the Edge package.
#>
function Request-EdgeForceRemove {
    if ($script:GuiWindow) {
        $result = Show-MessageBox -Message 'Unable to uninstall Microsoft Edge via WinGet. Would you like to forcefully uninstall it? NOT RECOMMENDED!' -Title 'Force Uninstall Microsoft Edge?' -Button 'YesNo' -Icon 'Warning'
        if ($result -eq 'Yes') {
            Write-Host ""
            Invoke-ForceRemoveEdge
        }
    }
    elseif ($(Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)") -eq 'y') {
        Write-Host ""
        Invoke-ForceRemoveEdge
    }
}

<#
    .SYNOPSIS
    Dynamically sets a RunOnce registry key to schedule a winget uninstall.

    .DESCRIPTION
    Writes directly to HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
    via the PowerShell registry API within Invoke-WithTargetUserHive,
    which handles hive loading and HKEY_USERS\Default → SID remapping.
    Used instead of static .reg files to avoid file dependency for each WinGet app.

    The winget command is Base64-encoded and invoked via powershell.exe -EncodedCommand
    rather than interpolated directly into cmd.exe /c. This prevents shell metacharacters
    (such as &, |, <, >, ^, ") in the app ID from being interpreted as command syntax,
    even if future catalog updates introduce IDs containing those characters.

    .PARAMETER appId
    The winget package ID to schedule for uninstall (e.g. 'XP9CXNGPPJ97XX').
#>
function Set-RunOnceWingetTask {
    param([string]$appId)

    $targetUserName = if ($script:Params.ContainsKey("Sysprep")) { "Default" } else { $script:Params.Item("User") }

    # Sanitize appId for use in registry value names (backslashes are path separators)
    $safeAppId = $appId.Replace('\', '_')

    $taskName = "Uninstall_$safeAppId"

    # Escape single quotes in appId, then wrap in single quotes so cmd/pwsh metacharacters
    # like & | < > ^ " are treated as literals. Base64-encode the whole command so the
    # RunOnce value contains only [A-Za-z0-9+/=] — safe in any shell parser.
    $escapedAppId = $appId.Replace("'", "''")
    $wingetCommand = "winget uninstall --accept-source-agreements --disable-interactivity --id '$escapedAppId'"
    $encodedWingetCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($wingetCommand))

    $operation = [PSCustomObject]@{
        KeyPath       = 'HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        ValueName     = $taskName
        ValueType     = 'String'
        ValueData     = "powershell.exe -NoProfile -EncodedCommand $encodedWingetCommand"
        OperationType = 'SetValue'
    }

    try {
        Invoke-WithTargetUserHive -TargetUserName $targetUserName -ScriptBlock {
            param($op)
            Invoke-RegistryOperation -Operation $op -RegFilePath '<dynamic>'
        } -ArgumentObject $operation
        return $true
    }
    catch {
        Write-Error "Failed to schedule uninstall task for $($appId): $_"
        return $false
    }
}
