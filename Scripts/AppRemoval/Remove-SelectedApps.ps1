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

    .OUTPUTS
    System.Boolean. $true when all removals can be confirmed; otherwise $false.
#>
function Remove-SelectedApps {
    param (
        $appslist
    )

    if ($script:Params.ContainsKey("WhatIf")) {
        foreach ($app in $appslist) {
            Write-Host "[WhatIf] Remove App Package: $app" -ForegroundColor Cyan
        }

        return $true
    }

    $failuresBefore = $script:AppRemovalFailures
    $targetUser = Get-TargetUserForAppRemoval
    $appCount = @($appsList).Count
    $appIndex = 0

    $edgeIds = @('Microsoft.Edge', 'XPFFTQ037JWMHS')
    $wingetRemovedApps = @()
    $wingetRemovalFailures = @{}

    Foreach ($app in $appsList) {
        if ($script:CancelRequested) { return $false }

        $appIndex++

        if ($script:ApplySubStepCallback -and $appCount -gt 1) {
            & $script:ApplySubStepCallback (Get-Translation -Key 'RemovingAppsSubStep' -FormatArgs @($appIndex, $appCount)) $appIndex $appCount
        }

        Write-Host "Removing $app"

        if ((Get-AppRemovalMethod $app) -eq 'WinGet') {
            $removalSucceeded = Remove-WinGetApp -app $app
            $wingetRemovedApps += $app
            if (($script:Params.ContainsKey('User') -or $script:Params.ContainsKey('Sysprep')) -and -not $removalSucceeded) {
                $wingetRemovalFailures[$app] = $true
            }
        }
        else {
            if (-not (Remove-AppxApp -app $app -targetUser $targetUser)) {
                $script:AppRemovalFailures++
            }
        }
    }

    if ($script:CancelRequested) {
        return $false
    }

    # Check whether any winget-removed apps are still present, and report errors for each one.
    if ($wingetRemovedApps.Count -gt 0) {
        $postRemovalList = if ($script:WingetInstalled) { Get-WingetInstalledApps -TimeOut 10 -NonBlocking } else { $null }
        $edgeForceRemoveRequested = $false
        $edgeForceRemoveSucceeded = $false

        if ($null -eq $postRemovalList) {
            $script:AppRemovalVerificationUnavailable = $true
            foreach ($app in $wingetRemovedApps) {
                $wingetRemovalFailures[$app] = $true
            }
        }
        else {
            foreach ($app in $wingetRemovedApps) {
                if (-not (Test-AppInWingetList -appId $app -InstalledList $postRemovalList)) {
                    continue
                }

                if ($edgeIds -contains $app) {
                    Write-Host "Unable to uninstall Microsoft Edge via WinGet" -ForegroundColor Red
                    if (-not $edgeForceRemoveRequested) {
                        $edgeForceRemoveRequested = $true
                        $edgeForceRemoveSucceeded = Request-EdgeForceRemove
                    }
                    if ($edgeForceRemoveSucceeded) {
                        continue
                    }
                }
                else {
                    Write-Host "Unable to uninstall $app via WinGet" -ForegroundColor Red
                }
                $wingetRemovalFailures[$app] = $true
            }
        }
    }

    $script:AppRemovalFailures += $wingetRemovalFailures.Count

    return ($script:AppRemovalFailures -eq $failuresBefore)
}

<#
    .SYNOPSIS
    Uninstalls an app via WinGet and/or schedules its removal.

    .DESCRIPTION
    Runs winget uninstall for a single app, with a bounded execution time.
    WinGet's own exit code/success reporting is unreliable and is only logged
    for diagnostics; it never causes this function to report failure. Callers
    verify removal with a post-removal inventory check instead. This function
    only reports failure when the winget invocation itself throws a terminating
    error (e.g. it times out or cannot be started). If the User or Sysprep
    parameter was passed, also schedules removal for future logins.

    .PARAMETER app
    The WinGet package ID to uninstall (e.g. 'Microsoft.BingNews').

    .PARAMETER TimeoutSeconds
    Maximum time to allow the foreground WinGet uninstall to run. Defaults
    to 120 seconds.

    .OUTPUTS
    System.Boolean. $true unless the winget invocation threw a terminating error
    or any required RunOnce scheduling failed; otherwise $false.
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

    $uninstallCommandSucceeded = $true
    $exitCode = $null
    try {
        $uninstallResult = Invoke-NonBlocking -ScriptBlock {
            param($appId)
            $output = @(& winget uninstall --accept-source-agreements --disable-interactivity --id $appId 2>&1)
            return [PSCustomObject]@{
                ExitCode = $LASTEXITCODE
                Output = $output
            }
        } -ArgumentList $app -TimeoutSeconds $TimeoutSeconds
        Write-WinGetUninstallOutput -Output $(if ($uninstallResult) { $uninstallResult.Output } else { $null })
        $exitCode = if ($uninstallResult) { $uninstallResult.ExitCode } else { 'unknown' }
        Write-Verbose "WinGet uninstall for $app returned exit code $exitCode."
    }
    catch {
        $uninstallCommandSucceeded = $false
        if ($_.Exception.Message -like 'Operation timed out after *') {
            Write-Verbose "WinGet uninstall for $app did not complete within $TimeoutSeconds seconds: $_"
        }
        else {
            Write-Verbose "WinGet uninstall for $app failed: $_"
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

    return ($uninstallCommandSucceeded -and $scheduleSucceeded)
}

<#
    .SYNOPSIS
    Writes captured WinGet uninstall output to the verbose stream.

    .OUTPUTS
    None.
#>
function Write-WinGetUninstallOutput {
    param(
        [object[]]$Output
    )

    foreach ($line in @($Output)) {
        if ($null -eq $line) { continue }

        $lineText = if ($line -is [System.Management.Automation.ErrorRecord]) { $line.Exception.Message } else { $line.ToString() }
        if ([string]::IsNullOrWhiteSpace($lineText)) { continue }

        Write-Verbose $lineText
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

    .OUTPUTS
    System.Boolean. $true when Edge is forcefully removed; otherwise $false.
#>
function Request-EdgeForceRemove {
    if ($script:GuiWindow) {
        $result = Show-MessageBox -Message (Get-Translation -Key 'ForceRemoveEdgeMessage') -Title (Get-Translation -Key 'ForceRemoveEdgeTitle') -Button 'YesNo' -Icon 'Warning'
        if ($result -eq 'Yes') {
            Write-Host ""
            return (Invoke-ForceRemoveEdge)
        }
    }
    elseif ($(Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)") -eq 'y') {
        Write-Host ""
        return (Invoke-ForceRemoveEdge)
    }

    return $false
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
