# Removes apps specified during function call based on the target scope.
function RemoveApps {
    param (
        $appslist
    )

    # Determine target from script-level params, defaulting to AllUsers
    $targetUser = GetTargetUserForAppRemoval

    $appIndex = 0
    $appCount = @($appsList).Count
    $edgeIds = @('Microsoft.Edge', 'XPFFTQ037JWMHS')
    $edgeUninstallSucceeded = $false
    $edgeScheduledTaskAdded = $false

    Foreach ($app in $appsList) {
        if ($script:CancelRequested) {
            return
        }

        $appIndex++

        # Update step name and sub-progress to show which app is being removed (only for bulk removal)
        if ($script:ApplySubStepCallback -and $appCount -gt 1) {
            & $script:ApplySubStepCallback "Removing apps ($appIndex/$appCount)" $appIndex $appCount
        }

        Write-Host "Attempting to remove $app..."

        # Use WinGet only to remove OneDrive and Edge
        if (($app -eq "Microsoft.OneDrive") -or ($edgeIds -contains $app)) {
            if ($script:WingetInstalled -eq $false) {
                Write-Host "WinGet is either not installed or is outdated, $app could not be removed" -ForegroundColor Red
                continue
            }

            $isEdgeId = $edgeIds -contains $app
            $appName = if ($isEdgeId) { 'Microsoft_Edge' } else { $app -replace '\.', '_' }

            # Uninstall app via WinGet, or create a scheduled task to uninstall it later
            if ($script:Params.ContainsKey("User")) {
                if (-not ($isEdgeId -and $edgeScheduledTaskAdded)) {
                    ImportRegistryFile "Adding scheduled task to uninstall $app for user $(GetUserName)..." "Uninstall_$($appName).reg"
                    if ($isEdgeId) { $edgeScheduledTaskAdded = $true }
                }
            }
            elseif ($script:Params.ContainsKey("Sysprep")) {
                if (-not ($isEdgeId -and $edgeScheduledTaskAdded)) {
                    ImportRegistryFile "Adding scheduled task to uninstall $app after for new users..." "Uninstall_$($appName).reg"
                    if ($isEdgeId) { $edgeScheduledTaskAdded = $true }
                }
            }
            else {
                # Uninstall app via WinGet
                $wingetOutput = Invoke-NonBlocking -ScriptBlock {
                    param($appId)
                    winget uninstall --accept-source-agreements --disable-interactivity --id $appId
                } -ArgumentList $app

                $wingetFailed = Select-String -InputObject $wingetOutput -Pattern "Uninstall failed with exit code|No installed package found matching input criteria|No package found matching input criteria" -SimpleMatch:$false
                if ($isEdgeId) {
                    if (-not $wingetFailed) {
                        $edgeUninstallSucceeded = $true
                    }

                    # Prompt immediately after the final selected Edge ID attempt (if all attempts failed)
                    $hasRemainingEdgeIds = $false
                    if ($appIndex -lt $appCount) {
                        $remainingApps = @($appsList)[($appIndex)..($appCount - 1)]
                        $hasRemainingEdgeIds = @($remainingApps | Where-Object { $edgeIds -contains $_ }).Count -gt 0
                    }

                    if (-not $hasRemainingEdgeIds -and -not $edgeUninstallSucceeded) {
                        Write-Host "Unable to uninstall Microsoft Edge via WinGet" -ForegroundColor Red

                        if ($script:GuiWindow) {
                            $result = Show-MessageBox -Message 'Unable to uninstall Microsoft Edge via WinGet. Would you like to forcefully uninstall it? NOT RECOMMENDED!' -Title 'Force Uninstall Microsoft Edge?' -Button 'YesNo' -Icon 'Warning'

                            if ($result -eq 'Yes') {
                                Write-Host ""
                                ForceRemoveEdge
                            }
                        }
                        elseif ($( Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)" ) -eq 'y') {
                            Write-Host ""
                            ForceRemoveEdge
                        }
                    }
                }
            }

            continue
        }

        # Use Remove-AppxPackage to remove all other apps
        $appPattern = '*' + $app + '*'

        try {
            switch ($targetUser) {
                "AllUsers" {
                    # Remove installed app for all existing users, and from OS image
                    Invoke-NonBlocking -ScriptBlock {
                        param($pattern)
                        Get-AppxPackage -Name $pattern -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
                        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $pattern } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
                    } -ArgumentList $appPattern
                }
                "CurrentUser" {
                    # Remove installed app for current user only
                    Invoke-NonBlocking -ScriptBlock {
                        param($pattern)
                        Get-AppxPackage -Name $pattern | Remove-AppxPackage -ErrorAction Continue
                    } -ArgumentList $appPattern
                }
                default {
                    # Target is a specific username - remove app for that user only
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
            if ($DebugPreference -ne "SilentlyContinue") {
                Write-Host "Something went wrong while trying to remove $app" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }
    }

    Write-Host ""
}