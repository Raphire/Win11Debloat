<#
    .SYNOPSIS
    Removes one or more Windows app packages based on the target scope.

    .DESCRIPTION
    Iterates over the provided list of app identifiers and removes each one.
    The removal method (winget vs. Appx cmdlets) is determined per-app from
    Apps.json. Microsoft Edge is deferred to the end of the loop so that all
    winget attempts run before any force-remove prompt. A scheduled task is
    only created when the User or Sysprep parameter was passed.
    After each winget removal, the system is checked to confirm whether the
    app is still installed before reporting an error.

    .PARAMETER appsList
    An array of app package identifiers to remove (e.g. 'Microsoft.BingNews').

    .EXAMPLE
    RemoveApps @('Microsoft.BingNews', 'Microsoft.BingWeather')

    .EXAMPLE
    RemoveApps -appsList (GenerateAppsList)
#>
function RemoveApps {
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

    $targetUser = GetTargetUserForAppRemoval
    $appCount = @($appsList).Count
    $appIndex = 0

    $edgeIds = @('Microsoft.Edge', 'XPFFTQ037JWMHS')
    $edgeAppsInList = @()
    $wingetRemovedApps = @()

    Foreach ($app in $appsList) {
        if ($script:CancelRequested) { return }

        $appIndex++

        if ($script:ApplySubStepCallback -and $appCount -gt 1) {
            & $script:ApplySubStepCallback "Removing apps ($appIndex/$appCount)" $appIndex $appCount
        }

        # Microsoft Edge is handled after the loop to avoid duplicate scheduled tasks and allow fallback if winget fails
        if ($edgeIds -contains $app) {
            $edgeAppsInList += $app
            continue
        }

        Write-Host "Removing $app"

        if ((Get-AppRemovalMethod $app) -eq 'WinGet') {
            Remove-WinGetApp -app $app
            $wingetRemovedApps += $app
        }
        else {
            Remove-AppxApp -app $app -targetUser $targetUser
        }
    }

    # Remove Microsoft Edge
    if ($edgeAppsInList.Count -gt 0) {
        Remove-EdgeApp -edgeAppsInList $edgeAppsInList
    }

    # Check whether any winget-removed apps are still present, and report errors for each one.
    if ($wingetRemovedApps.Count -gt 0 -or $edgeAppsInList.Count -gt 0) {
        $postRemovalList = if ($script:WingetInstalled) { GetInstalledAppsViaWinget -TimeOut 10 -NonBlocking } else { $null }
        foreach ($app in $wingetRemovedApps) {
            if (Test-AppStillInstalled -appId $app -InstalledList $postRemovalList) {
                Write-Host "Unable to uninstall $app via WinGet" -ForegroundColor Red
            }
        }

        # Verify Edge separately (triggers its own force-remove path if still installed)
        $edgeStillInstalled = $false
        foreach ($edgeApp in $edgeAppsInList) {
            if (Test-AppStillInstalled -appId $edgeApp -InstalledList $postRemovalList) {
                $edgeStillInstalled = $true
                break
            }
        }
        if ($edgeStillInstalled) {
            Write-Host "Unable to uninstall Microsoft Edge via WinGet" -ForegroundColor Red
            Request-EdgeForceRemove
        }
    }

    Write-Host ""
}

<#
    .SYNOPSIS
    Uninstalls a non-Edge app via WinGet and/or schedules its removal.

    .DESCRIPTION
    Runs winget uninstall for a single app. If the User or Sysprep
    parameter was passed, also schedules removal for future logins.
    After uninstall, the system is checked to confirm whether the app
    is still present — winget output is not trusted on its
    own, as it sometimes reports failure after a successful removal.
    Edge apps are handled separately after the main loop.

    .PARAMETER app
    The WinGet package ID to uninstall (e.g. 'Microsoft.BingNews').
#>
function Remove-WinGetApp {
    param([string]$app)

    if (-not $script:WingetInstalled) {
        Write-Host "ERROR: WinGet is either not installed or is outdated, $app could not be removed" -ForegroundColor Red
        return
    }

    if ($script:Params.ContainsKey("User")) {
        Write-Host "Adding scheduled task to uninstall $app for user $(GetUserName)..."
        Set-RunOnceWingetTask -appId $app
    }
    elseif ($script:Params.ContainsKey("Sysprep")) {
        Write-Host "Adding scheduled task to uninstall $app for new users..."
        Set-RunOnceWingetTask -appId $app
    }

    Invoke-NonBlocking -ScriptBlock {
        param($appId)
        winget uninstall --accept-source-agreements --disable-interactivity --id $appId
    } -ArgumentList $app
}

<#
    .SYNOPSIS
    Removes Microsoft Edge via WinGet (both AppIds), with fallback to force-remove.

    .DESCRIPTION
    Edge has multiple package IDs. Runs winget uninstall for each one,
    then creates a single scheduled task if the User or Sysprep parameter
    was passed. After all attempts, the system is checked to confirm
    whether Edge is still present. The force-remove prompt only
    appears if Edge remains installed — winget false positives are ignored.

    .PARAMETER edgeAppsInList
    The Edge AppIds that appear in the removal list (one or both).
#>
function Remove-EdgeApp {
    param([string[]]$edgeAppsInList)

    if (-not $script:WingetInstalled) {
        Write-Host "ERROR: WinGet is either not installed or is outdated, Microsoft Edge could not be removed" -ForegroundColor Red
        return
    }

    if ($script:Params.ContainsKey("User")) {
        Write-Host "Adding scheduled task to uninstall Microsoft Edge for user $(GetUserName)..."
        Set-RunOnceWingetTask -appId 'Microsoft.Edge'
    }
    elseif ($script:Params.ContainsKey("Sysprep")) {
        Write-Host "Adding scheduled task to uninstall Microsoft Edge for new users..."
        Set-RunOnceWingetTask -appId 'Microsoft.Edge'
    }

    foreach ($edgeApp in $edgeAppsInList) {
        Write-Host "Removing $edgeApp"
        Invoke-NonBlocking -ScriptBlock {
            param($appId)
            winget uninstall --accept-source-agreements --disable-interactivity --id $appId
        } -ArgumentList $edgeApp
    }
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
        switch ($targetUser) {
            "AllUsers" {
                Invoke-NonBlocking -ScriptBlock {
                    param($pattern)
                    Get-AppxPackage -Name $pattern -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
                    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $pattern } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
                } -ArgumentList $appPattern
            }
            "CurrentUser" {
                Invoke-NonBlocking -ScriptBlock {
                    param($pattern)
                    Get-AppxPackage -Name $pattern | Remove-AppxPackage -ErrorAction Continue
                } -ArgumentList $appPattern
            }
            default {
                Invoke-NonBlocking -ScriptBlock {
                    param($pattern, $user)
                    $userAccount = New-Object System.Security.Principal.NTAccount($user)
                    $userSid = $userAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
                    Get-AppxPackage -Name $pattern -User $userSid | Remove-AppxPackage -User $userSid -ErrorAction Continue
                } -ArgumentList @($appPattern, $targetUser)
            }
        }
    }
    catch {
        Write-Verbose "Something went wrong while trying to remove $($app): $_"
    }
}

<#
    .SYNOPSIS
    Checks whether an app package is still installed after a removal attempt.

    .DESCRIPTION
    Checks Get-AppxPackage across all users first (fast, no process launch),
    then falls back to a pre-fetched or live winget list for non-Appx packages.
    Uses Test-AppInWingetList which provides exact-match-first with substring
    fallback against the parsed winget objects.
    Returns $true if the app is still present, $false otherwise.

    .PARAMETER appId
    The package identifier to check (e.g. 'Microsoft.BingNews').

    .PARAMETER InstalledList
    Optional pre-fetched array of winget objects from GetInstalledAppsViaWinget.
    When provided, used directly; otherwise a live winget call is made.
#>
function Test-AppStillInstalled {
    param(
        [string]$appId,
        [object[]]$InstalledList
    )

    # Check Get-AppxPackage for all users first (fast, covers all Store apps).
    if (Get-AppxPackage -Name "$appId" -AllUsers -ErrorAction SilentlyContinue) {
        return $true
    }

    # Use the pre-fetched list if provided; otherwise fall back to a live winget call.
    if ($InstalledList) {
        return (Test-AppInWingetList -appId $appId -InstalledList $InstalledList)
    }

    if ($script:WingetInstalled) {
        $liveList = GetInstalledAppsViaWinget -TimeOut 10 -NonBlocking
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
                    if ($appData.AppId -is [array]) {
                        foreach ($id in $appData.AppId) { $script:AppRemovalMethodCache[$id.Trim()] = $method }
                    }
                    else {
                        $script:AppRemovalMethodCache[$appData.AppId.Trim()] = $method
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
            ForceRemoveEdge
        }
    }
    elseif ($(Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)") -eq 'y') {
        Write-Host ""
        ForceRemoveEdge
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
    }
    catch {
        Write-Host "Failed to schedule uninstall task for $($appId): $_" -ForegroundColor Red
    }
}