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
            Write-Host "[模拟运行] 将移除应用包：$app" -ForegroundColor Cyan
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

        Write-Host "正在移除 $app"

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
                    Write-Host "无法通过 WinGet 卸载 Microsoft Edge。" -ForegroundColor Red
                    if (-not $edgeForceRemoveRequested) {
                        $edgeForceRemoveRequested = $true
                        $edgeForceRemoveSucceeded = Request-EdgeForceRemove
                    }
                    if ($edgeForceRemoveSucceeded) {
                        continue
                    }
                }
                else {
                    Write-Host "无法通过 WinGet 卸载 $app" -ForegroundColor Red
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
        Write-Error "WinGet 未安装或版本过旧，无法移除 $app"
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
        Write-Verbose "WinGet 卸载 $app 时返回了退出代码 $exitCode。"
    }
    catch {
        $uninstallCommandSucceeded = $false
        if ($_.Exception.Message -like '操作已超时，等待时间为 *') {
            Write-Verbose "WinGet 未能在 $TimeoutSeconds 秒内完成 $app 的卸载：$_"
        }
        else {
            Write-Verbose "WinGet 卸载 $app 失败：$_"
        }
    }

    $scheduleSucceeded = $true
    if ($script:Params.ContainsKey("User")) {
        Write-Host "正在添加计划任务，为用户 $(Get-UserName) 卸载 $app……"
        $scheduleSucceeded = Set-RunOnceWingetTask -appId $app
    }
    elseif ($script:Params.ContainsKey("Sysprep")) {
        Write-Host "正在添加计划任务，为新用户卸载 $app……"
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
        Write-Error "无法通过 Appx 移除 $app：$_"
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
            Write-Warning "无法从 '$script:AppsListFilePath' 加载应用卸载方式，未知应用将默认使用 Appx。错误：$_"
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
    elseif ($(Read-Host -Prompt "是否强制卸载 Microsoft Edge？不建议这样做！（输入 y 确认，n 取消）") -eq 'y') {
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
        Write-Error "为 $($appId) 创建卸载计划任务失败：$_"
        return $false
    }
}
