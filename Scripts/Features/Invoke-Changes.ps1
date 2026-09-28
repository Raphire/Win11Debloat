<#
    .SYNOPSIS
        Applies a single feature/debloat operation.

    .DESCRIPTION
        Handles two categories of features:
        - Registry-backed: imports the .reg file via Import-RegistryFile, then runs
        any post-import side effects (e.g., removing companion app packages).
        - Custom logic: app removal, Windows optional features, start menu
        replacement, and other special-case features. Returns $true when the
        feature completes successfully; otherwise writes a warning and returns
        $false.
#>
function Invoke-FeatureApply {
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    try {
        # Resolve feature metadata from Features.json
        $feature = $script:Features[$FeatureId]
        $applyText = $feature.ApplyText

    # ---- Registry-backed features: import .reg file, then handle additional tasks ----
    if ($feature.RegistryKey) {
        if (-not (Import-RegistryFile "> $applyText..." $feature.RegistryKey)) {
            return $false
        }

        switch ($FeatureId) {
            'DisableBing' {
                # Also remove the app package for Bing search
                return (Remove-SelectedApps @('Microsoft.BingSearch'))
            }
            'DisableCopilot' {
                # Also remove the app packages for Copilot
                return (Remove-SelectedApps @('Microsoft.Copilot', 'XP9CXNGPPJ97XX'))
            }
            'DisableTelemetry' {
                # Also disable telemetry scheduled tasks
                return (Disable-TelemetryScheduledTasks)
            }
        }
        return $true
    }

    # ---- Custom features (no registry backing, or special handling required) ----
    switch ($FeatureId) {
        'RemoveApps' {
            Write-Host "> 为 $(Get-FriendlyTargetUserName) 执行：$applyText……"
            $appsList = Generate-AppsList

            if ($appsList.Count -eq 0) {
                Write-Host "未选择任何可移除的有效应用。" -ForegroundColor Yellow
                return $true
            }

            Write-Host "已选择移除 $($appsList.Count) 个应用。"
            return (Remove-SelectedApps $appsList)
        }
        'RemoveGamingApps' {
            $appsList = @('Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay')
            Write-Host "> $applyText..."
            return (Remove-SelectedApps $appsList)
        }
        'RemoveHPApps' {
            $appsList = @('AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl')
            Write-Host "> $applyText..."
            return (Remove-SelectedApps $appsList)
        }
        'ForceRemoveEdge' {
            Write-Host "> $applyText..."
            return (Invoke-ForceRemoveEdge)
        }
        'DisableWidgets' {
            Write-Host "> $applyText..."
            # Stop widgets related processes before removing the app packages to prevent potential issues
            if (-not $script:Params.ContainsKey("WhatIf")) {
                Get-Process *Widget* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }

            return (Remove-SelectedApps @('Microsoft.StartExperiencesApp','MicrosoftWindows.Client.WebExperience','Microsoft.WidgetsPlatformRuntime'))
        }
        'EnableWindowsSandbox' {
            Write-Host "> $applyText..."
            return (Enable-WindowsFeature "Containers-DisposableClientVM")
        }
        'EnableWindowsSubsystemForLinux' {
            Write-Host "> $applyText..."
            if (-not (Enable-WindowsFeature "VirtualMachinePlatform")) { return $false }
            return (Enable-WindowsFeature "Microsoft-Windows-Subsystem-Linux")
        }
        'ClearStart' {
            Write-Host "> 为用户 $(Get-UserName) 执行：$applyText……"
            $startMenuBinFile = Get-StartMenuBinPathForUser -UserName (Get-UserName)
            if (-not [string]::IsNullOrWhiteSpace($startMenuBinFile)) {
                return (Replace-StartMenu -startMenuBinFile $startMenuBinFile)
            }
            Write-Warning "无法应用 '$applyText'：未找到用户 $(Get-UserName) 的开始菜单路径。"
            return $false
        }
        'ReplaceStart' {
            Write-Host "> 为用户 $(Get-UserName) 执行：$applyText……"
            $startMenuBinFile = Get-StartMenuBinPathForUser -UserName (Get-UserName)
            if (-not [string]::IsNullOrWhiteSpace($startMenuBinFile)) {
                return (Replace-StartMenu -startMenuBinFile $startMenuBinFile -startMenuTemplate $script:Params.Item("ReplaceStart"))
            }
            Write-Warning "无法应用 '$applyText'：未找到用户 $(Get-UserName) 的开始菜单路径。"
            return $false
        }
        'ClearStartAllUsers' {
            return (Replace-StartMenuForAllUsers)
        }
        'ReplaceStartAllUsers' {
            return (Replace-StartMenuForAllUsers -startMenuTemplate $script:Params.Item("ReplaceStartAllUsers"))
        }
        'DisableStoreSearchSuggestions' {
            if ($script:Params.ContainsKey("Sysprep")) {
                Write-Host "> 正在为所有用户禁用开始菜单中的 Microsoft Store 搜索建议……"
                return (Set-StoreSearchSuggestionsDisabledForAllUsers)
            }

            Write-Host "> 正在为用户 $(Get-UserName) 禁用 Microsoft Store 搜索建议……"
            $storeDb = Get-StoreAppsDatabasePathForUser -UserName (Get-UserName)
            if ($storeDb) {
                return (Set-StoreSearchSuggestionsDisabled -StoreAppsDatabase $storeDb)
            }
            Write-Warning "未找到用户 $(Get-UserName) 的商店数据库，无法禁用 Microsoft Store 搜索建议。"
            return $false
        }
    }
    }
    catch {
        Write-Warning "应用 '$applyText' 失败：$($_.Exception.Message)"
        return $false
    }

    Write-Warning "无法应用未知功能 '$FeatureId'。"
    return $false
}


<#
    .SYNOPSIS
        Undoes a single feature.

    .DESCRIPTION
        Handles registry-backed undo imports and custom undo logic. Returns
        $true when the requested undo succeeds; otherwise writes a warning and
        returns $false.
#>
function Invoke-FeatureUndo {
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    $feature = if ($script:Features.ContainsKey($FeatureId)) { $script:Features[$FeatureId] } else { $null }
    if (-not $feature) {
        Write-Warning "无法撤销未知功能 '$FeatureId'。"
        return $false
    }

    $undoText = if ($feature.ApplyUndoText) { $feature.ApplyUndoText } elseif ($feature.UndoLabel) { $feature.UndoLabel } else { $FeatureId }

    try {
        # ---- Registry-backed features: import undo data, then handle additional tasks ----
        if ($feature.RegistryUndoKey) {
            if (-not (Import-RegistryFile "> $undoText" (Resolve-UndoRegFilePath $feature.RegistryUndoKey))) {
                return $false
            }

            switch ($FeatureId) {
                'DisableTelemetry' {
                    # Also re-enable telemetry scheduled tasks.
                    return (Enable-TelemetryScheduledTasks)
                }
            }

            return $true
        }

        # ---- Custom undo features (no registry backing) ----
        switch ($FeatureId) {
            'DisableStoreSearchSuggestions' {
                if ($script:Params.ContainsKey('Sysprep')) {
                    Write-Host "> 正在为所有用户重新启用开始菜单中的 Microsoft Store 搜索建议……"
                    return (Set-StoreSearchSuggestionsEnabledForAllUsers)
                }

                Write-Host "> 正在为用户 $(Get-UserName) 重新启用 Microsoft Store 搜索建议……"
                $storeDb = Get-StoreAppsDatabasePathForUser -UserName (Get-UserName)
                if ($storeDb) {
                    return (Set-StoreSearchSuggestionsEnabled -StoreAppsDatabase $storeDb)
                }
                Write-Warning "未找到用户 $(Get-UserName) 的商店数据库，无法重新启用 Microsoft Store 搜索建议。"
                return $false
            }
            'EnableWindowsSandbox' {
                Write-Host "> $undoText..."
                return (Disable-WindowsFeature 'Containers-DisposableClientVM')
            }
            'EnableWindowsSubsystemForLinux' {
                Write-Host "> $undoText..."
                if (-not (Disable-WindowsFeature 'Microsoft-Windows-Subsystem-Linux')) { return $false }
                return (Disable-WindowsFeature 'VirtualMachinePlatform')
            }
        }
    }

    catch {
        Write-Warning "撤销 '$undoText' 失败：$($_.Exception.Message)"
        return $false
    }

    Write-Warning "功能 '$FeatureId' 不支持撤销。"
    return $false
}


<#
    .SYNOPSIS
        Resolves the path of an undo .reg file relative to $script:RegfilesPath.

    .DESCRIPTION
        Checks the Undo/ subfolder first, then falls back to the root Regfiles/
        folder. This allows undo files to be organized separately from apply files.
#>
function Resolve-UndoRegFilePath {
    param([string]$FileName)

    $undoSubPath = Join-Path 'Undo' $FileName
    if (Test-Path (Join-Path $script:RegfilesPath $undoSubPath)) {
        return $undoSubPath
    }
    return $FileName
}


<#
.SYNOPSIS
    Applies a list of features, reporting progress for each.

.DESCRIPTION
    Iterates through the provided feature IDs and calls Invoke-FeatureApply
    for each. Handles progress callbacks (GUI mode) and cancellation checks.
    This is called by Invoke-AllChanges during the apply phase.
#>
function Invoke-ApplyFeatures {
    param(
        [Parameter(Mandatory)]
        [string[]]$FeatureIds,
        [Parameter(Mandatory)]
        [int]$StartStep,
        [Parameter(Mandatory)]
        [int]$TotalSteps
    )

    if ($FeatureIds.Count -eq 0) { return }

    $step = $StartStep
    foreach ($featureId in $FeatureIds) {
        if ($script:CancelRequested) { return }

        # Resolve display name for the progress indicator
        $f = $script:Features[$featureId]
        $displayName = Get-Translation -Key $featureId -Field 'ApplyText' -Section 'Features'

        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $TotalSteps $displayName
        }

        # Compare app-removal failure counts so a feature that only fails due to
        # app removal isn't also double-reported as a feature failure.
        $appRemovalFailuresBefore = $script:AppRemovalFailures
        if ((-not (Invoke-FeatureApply -FeatureId $featureId)) -and ($script:AppRemovalFailures -eq $appRemovalFailuresBefore)) {
            $script:FeatureFailures++
        }
        Write-Host ""
        $step++
    }
}


<#
    .SYNOPSIS
        Undoes a list of features, reporting progress for each.

    .DESCRIPTION
    Iterates through the provided feature IDs and delegates each to
    Invoke-FeatureUndo, which handles registry-backed and custom undo logic.
        This is called by Invoke-AllChanges during the undo phase.
#>
function Invoke-UndoFeatures {
    param(
        [Parameter(Mandatory)]
        [string[]]$FeatureIds,
        [Parameter(Mandatory)]
        [int]$StartStep,
        [Parameter(Mandatory)]
        [int]$TotalSteps
    )

    if ($FeatureIds.Count -eq 0) { return }

    $step = $StartStep
    foreach ($featureId in $FeatureIds) {
        if ($script:CancelRequested) { return }

        $f = if ($script:Features.ContainsKey($featureId)) { $script:Features[$featureId] } else { $null }
        $undoLabel = if ($f -and $f.UndoLabel) { Get-Translation -Key $featureId -Field 'UndoLabel' -Section 'Features' } else { $featureId }
        $undoText = if ($f -and $f.ApplyUndoText) { Get-Translation -Key $featureId -Field 'ApplyUndoText' -Section 'Features' } else { $undoLabel }

        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $TotalSteps $undoText
        }

        if (-not (Invoke-FeatureUndo -FeatureId $featureId)) {
            $script:FeatureFailures++
        }
        Write-Host ""
        $step++
    }
}


<#
    .SYNOPSIS
        Main orchestrator: applies and undoes all selected features.

    .DESCRIPTION
        Sequenced in four phases:
        1. Registry backup (skipped when SkipRegistryBackup is present)
        2. System restore point (skipped when CreateRestorePoint is absent)
        3. Apply phase - applies all selected features via Invoke-ApplyFeatures
        4. Undo phase - undoes selected features via Invoke-UndoFeatures

        Progress is reported through $script:ApplyProgressCallback when set
        (used by the GUI modal). Cancellation is checked between each step.
#>
function Invoke-AllChanges {
    if ($script:CancelRequested) { return }

    # Guard: prevent running as SYSTEM account without explicit target user
    $isSystem = Test-RunningAsSystem
    if ($isSystem -and -not $script:Params.ContainsKey("User") -and -not $script:Params.ContainsKey("Sysprep")) {
        throw "Win11Debloat 正以 SYSTEM 账户运行，请使用 '-User' 或 '-Sysprep' 参数指定目标用户。"
    }

    $script:AppRemovalFailures = 0
    $script:FeatureFailures = 0
    $script:AppRemovalVerificationUnavailable = $false

    # ---- Gather work items ----
    $applyIds = @()
    foreach ($key in $script:Params.Keys) {
        if ($script:ControlParams -contains $key) { continue }
        if ($key -eq 'Apps') { continue }
        if ($key -eq 'CreateRestorePoint') { continue }
        $applyIds += $key
    }
    $undoIds = @($script:UndoParams.Keys)

    # ---- Determine if registry backup is needed ----
    $needsBackup = $false
    foreach ($id in $applyIds) {
        $f = $script:Features[$id]
        if ($f -and -not [string]::IsNullOrWhiteSpace([string]$f.RegistryKey)) {
            $needsBackup = $true
            break
        }
    }
    if (-not $needsBackup) {
        foreach ($id in $undoIds) {
            $f = if ($script:Features.ContainsKey($id)) { $script:Features[$id] } else { $null }
            if ($f -and $f.RegistryUndoKey) { $needsBackup = $true; break }
        }
    }

    # ---- Calculate total progress steps ----
    $totalSteps = $applyIds.Count + $undoIds.Count
    if ($needsBackup -and -not $script:Params.ContainsKey('SkipRegistryBackup')) { $totalSteps++ }
    if ($script:Params.ContainsKey("CreateRestorePoint")) { $totalSteps++ }
    $step = 0

    # ================================================================
    # Phase 1: Registry backup
    # ================================================================
    if ($needsBackup -and -not $script:Params.ContainsKey('SkipRegistryBackup')) {
        if ($script:CancelRequested) { return }
        $step++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $totalSteps (Get-Translation -Key 'ApplyCreatingRegistryBackup')
        }

        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host "[模拟运行] 将创建注册表备份。" -ForegroundColor Cyan
        }
        else {
            Write-Host "> 正在创建注册表备份……"
            try {
                $undoSyntheticFeatures = @($undoIds | ForEach-Object {
                    $f = if ($script:Features.ContainsKey($_)) { $script:Features[$_] } else { $null }
                    if ($f -and $f.RegistryUndoKey) {
                        [PSCustomObject]@{ FeatureId = $_; RegistryKey = (Resolve-UndoRegFilePath $f.RegistryUndoKey) }
                    }
                } | Where-Object { $_ })
                New-RegistrySettingsBackup -ActionableKeys $applyIds -ExtraFeatures $undoSyntheticFeatures | Out-Null
            }
            catch {
                throw "应用更改前，注册表备份失败。$($_.Exception.Message)"
            }
        }
    }

    # ================================================================
    # Phase 2: System restore point
    # ================================================================
    if ($script:Params.ContainsKey("CreateRestorePoint")) {
        if ($script:CancelRequested) { return }
        $step++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $totalSteps (Get-Translation -Key 'ApplyCreatingRestorePoint')
        }
        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host "[模拟运行] 将创建系统还原点。" -ForegroundColor Cyan
            Write-Host ""
        }
        else {
            Write-Host "> 正在创建系统还原点……"
            $restorePointSucceeded = Invoke-SystemRestorePoint
            if (-not $restorePointSucceeded) {
                if ($script:CancelRequested) { return }
                $script:FeatureFailures++
            }
            Write-Host ""
        }
    }

    # ================================================================
    # Phase 3: Apply features
    # ================================================================
    if ($applyIds.Count -gt 0) {
        Invoke-ApplyFeatures -FeatureIds $applyIds -StartStep ($step + 1) -TotalSteps $totalSteps
        $step += $applyIds.Count
    }

    if ($script:CancelRequested) { return }

    # ================================================================
    # Phase 4: Undo features
    # ================================================================
    if ($undoIds.Count -gt 0) {
        Invoke-UndoFeatures -FeatureIds $undoIds -StartStep ($step + 1) -TotalSteps $totalSteps
        $step += $undoIds.Count
    }

    # ================================================================
    # Final: Report failures
    # ================================================================
    if ($script:AppRemovalFailures -gt 0) {
        Write-Host ""
        Write-Warning "有 $($script:AppRemovalFailures) 个应用移除失败，详情请查看上方输出。"
    }

    if ($script:FeatureFailures -gt 0) {
        Write-Host ""
        Write-Warning "有 $($script:FeatureFailures) 项功能更改失败，详情请查看上方输出。"
    }

    if ($script:AppRemovalVerificationUnavailable) {
        Write-Host ""
        Write-Warning "无法确认所有应用是否均已成功卸载。"
    }

}

<#
    .SYNOPSIS
        Tests whether Win11Debloat is running under the SYSTEM account.

    .DESCRIPTION
        Compares the current Windows identity's security identifier (SID) with
        the well-known Local System SID (S-1-5-18).

    .OUTPUTS
        System.Boolean
        Returns $true when the current process runs as SYSTEM; otherwise, $false.
#>
function Test-RunningAsSystem {
    return ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18')
}
