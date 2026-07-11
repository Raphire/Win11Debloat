# MainWindow-Deployment.ps1
# Overview generation, pending tweak actions, feature labels, tweak preset maps, apply logic, user mode state, user selection, and validation.

function Get-UndoFeatureLabel {
    param([string]$FeatureId)

    $undoLabel = $script:UndoFeatureLabelLookup[$FeatureId]
    if (-not [string]::IsNullOrWhiteSpace([string]$undoLabel)) {
        return [string]$undoLabel
    }

    # Fall back to the regular label (prefixed for undo context)
    return [string]$script:FeatureLabelLookup[$FeatureId]
}

<#
    .SYNOPSIS
    Returns the tweak actions that are pending based on the current UI state.

    .OUTPUTS
    [PSCustomObject[]] Objects with Action, FeatureId, and Label properties.
#>
function Get-PendingTweakActions {
    param(
        [System.Windows.Window]$Window,
        [bool]$ShowAppliedTweaksMode
    )

    $actions = New-Object System.Collections.Generic.List[object]

    if (-not $script:UiControlMappings) {
        return @($actions.ToArray())
    }

    foreach ($mappingKey in $script:UiControlMappings.Keys) {
        $control = $Window.FindName($mappingKey)
        if (-not $control) { continue }
        $mapping = $script:UiControlMappings[$mappingKey]

        if ($control -is [System.Windows.Controls.CheckBox] -and $mapping.Type -eq 'feature') {
            $wasApplied = $false
            if ($ShowAppliedTweaksMode -and $null -ne $control.PSObject.Properties['SystemState']) {
                $wasApplied = [bool]$control.SystemState
            }
            elseif ($null -ne $control.PSObject.Properties['InitialState']) {
                $wasApplied = [bool]$control.InitialState
            }
            elseif ($null -ne $control.PSObject.Properties['SystemState']) {
                $wasApplied = [bool]$control.SystemState
            }
            $isNowChecked = $control.IsChecked -eq $true

            if (-not $wasApplied -and $isNowChecked) {
                $actions.Add([PSCustomObject]@{
                        Action    = 'Apply'
                        FeatureId = [string]$mapping.FeatureId
                        Label     = [string]$script:FeatureLabelLookup[$mapping.FeatureId]
                    })
            }
            elseif ($wasApplied -and -not $isNowChecked) {
                $actions.Add([PSCustomObject]@{
                        Action    = 'Undo'
                        FeatureId = [string]$mapping.FeatureId
                        Label     = [string](Get-UndoFeatureLabel -FeatureId $mapping.FeatureId)
                    })
            }
        }
        elseif ($control -is [System.Windows.Controls.ComboBox] -and $mapping.Type -eq 'group') {
            $wasIndex = 0
            if ($ShowAppliedTweaksMode -and $null -ne $control.PSObject.Properties['SystemIndex']) {
                $wasIndex = [int]$control.SystemIndex
            }
            elseif ($null -ne $control.PSObject.Properties['InitialIndex']) {
                $wasIndex = [int]$control.InitialIndex
            }
            elseif ($null -ne $control.PSObject.Properties['SystemIndex']) {
                $wasIndex = [int]$control.SystemIndex
            }
            $isNowIndex = $control.SelectedIndex

            if ($wasIndex -eq $isNowIndex) { continue }

            if ($isNowIndex -gt 0 -and $isNowIndex -le $mapping.Values.Count) {
                $selectedValue = $mapping.Values[$isNowIndex - 1]
                foreach ($fid in $selectedValue.FeatureIds) {
                    $actions.Add([PSCustomObject]@{
                            Action    = 'Apply'
                            FeatureId = [string]$fid
                            Label     = [string]$script:FeatureLabelLookup[$fid]
                        })
                }
            }
        }
    }

    return @($actions.ToArray())
}

function New-Overview {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.StackPanel]$AppsPanel,
        $ShowCurrentlyAppliedTweaksCheckBox
    )

    $changesList = @()
    $showAppliedTweaksMode = ($ShowCurrentlyAppliedTweaksCheckBox -and $ShowCurrentlyAppliedTweaksCheckBox.IsChecked -eq $true)

    # Collect selected apps
    $selectedAppsCount = 0
    foreach ($child in $AppsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
            $selectedAppsCount++
        }
    }
    if ($selectedAppsCount -gt 0) {
        $changesList += "Remove $selectedAppsCount application(s)"
    }

    foreach ($tweakAction in @(Get-PendingTweakActions -Window $Window -ShowAppliedTweaksMode:$showAppliedTweaksMode)) {
        if ($tweakAction.Action -eq 'Undo') {
            $changesList += "Undo: $($tweakAction.Label)"
        }
        else {
            $changesList += $tweakAction.Label
        }
    }

    return $changesList
}

function Invoke-ShowChangesOverview {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.StackPanel]$AppsPanel,
        $ShowCurrentlyAppliedTweaksCheckBox
    )

    $changesList = New-Overview -Window $Window -AppsPanel $AppsPanel -ShowCurrentlyAppliedTweaksCheckBox $ShowCurrentlyAppliedTweaksCheckBox

    if ($changesList.Count -eq 0) {
        Show-MessageBox -Message 'No changes have been selected.' -Title 'Selected Changes' -Button 'OK' -Icon 'Information'
        return
    }

    $message = ($changesList | ForEach-Object { "$([char]0x2022) $_" }) -join "`n"
    Show-MessageBox -Message $message -Title 'Selected Changes' -Button 'OK' -Icon 'None' -Width 600
}

function Build-TweakPresetControlMap {
    param(
        [System.Windows.Window]$Window,
        $SettingsJson
    )

    $presetMap = @{}
    if (-not $SettingsJson -or -not $SettingsJson.Settings -or -not $script:UiControlMappings) {
        return $presetMap
    }

    # FeatureId -> control metadata, similar to ApplySettingsToUiControls lookup.
    $featureIdIndex = @{}
    foreach ($controlName in $script:UiControlMappings.Keys) {
        $control = $Window.FindName($controlName)
        if (-not $control -or $control.Visibility -ne 'Visible') { continue }

        $mapping = $script:UiControlMappings[$controlName]
        if ($mapping.Type -eq 'group') {
            $i = 1
            foreach ($val in $mapping.Values) {
                foreach ($fid in $val.FeatureIds) {
                    $featureIdIndex[$fid] = @{ ControlName = $controlName; Control = $control; MappingType = 'group'; Index = $i }
                }
                $i++
            }
        }
        elseif ($mapping.Type -eq 'feature') {
            $featureIdIndex[$mapping.FeatureId] = @{ ControlName = $controlName; Control = $control; MappingType = 'feature' }
        }
    }

    foreach ($setting in $SettingsJson.Settings) {
        if ($setting.Value -ne $true) { continue }
        if ($setting.Name -eq 'CreateRestorePoint') { continue }

        $entry = $featureIdIndex[$setting.Name]
        if (-not $entry) { continue }
        if ($presetMap.ContainsKey($entry.ControlName)) { continue }

        $controlType = if ($entry.Control -is [System.Windows.Controls.CheckBox]) { 'CheckBox' } else { 'ComboBox' }
        $desiredValue = switch ($entry.MappingType) {
            'group' { $entry.Index }
            default { if ($controlType -eq 'CheckBox') { $true } else { 1 } }
        }

        $presetMap[$entry.ControlName] = @{ Control = $entry.Control; ControlType = $controlType; DesiredValue = $desiredValue }
    }

    return $presetMap
}

function Build-CategoryTweakPresetMap {
    param(
        [System.Windows.Window]$Window,
        [string]$Category
    )

    $presetMap = @{}
    if (-not $script:UiControlMappings) { return $presetMap }

    foreach ($controlName in $script:UiControlMappings.Keys) {
        $mapping = $script:UiControlMappings[$controlName]
        if ($mapping.Category -ne $Category) { continue }

        $control = $Window.FindName($controlName)
        if (-not $control -or $control.Visibility -ne 'Visible') { continue }

        $controlType = if ($control -is [System.Windows.Controls.CheckBox]) { 'CheckBox' } else { 'ComboBox' }
        $desiredValue = if ($controlType -eq 'CheckBox') { $true } else { 1 }
        $presetMap[$controlName] = @{ Control = $control; ControlType = $controlType; DesiredValue = $desiredValue }
    }

    return $presetMap
}

function Get-SavedAppIdsFromSettingsJson {
    param($SettingsJson)

    if (-not $SettingsJson -or -not $SettingsJson.Settings) {
        return $null
    }

    $appsValue = $null
    foreach ($setting in $SettingsJson.Settings) {
        if ($setting.Name -eq 'Apps' -and $setting.Value) {
            $appsValue = $setting.Value
            break
        }
    }

    if (-not $appsValue) {
        return $null
    }

    $savedAppIds = @()
    if ($appsValue -is [string]) {
        $savedAppIds = $appsValue.Split(',')
    }
    elseif ($appsValue -is [array]) {
        $savedAppIds = $appsValue
    }

    $savedAppIds = $savedAppIds | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    if ($savedAppIds.Count -eq 0) {
        return $null
    }

    return $savedAppIds
}

function Invoke-ApplyTweakPresetMap {
    param(
        [hashtable]$PresetMap,
        [bool]$Check
    )

    if (-not $PresetMap) {
        $PresetMap = @{}
    }

    $wasUpdatingTweakPresets = [bool]$script:UpdatingTweakPresets
    $script:UpdatingTweakPresets = $true
    try {
        foreach ($target in $PresetMap.Values) {
            $control = $target.Control
            if (-not $control) { continue }

            if ($target.ControlType -eq 'CheckBox') {
                $control.IsChecked = $Check
            }
            elseif ($target.ControlType -eq 'ComboBox') {
                $desiredIndex = [int]$target.DesiredValue
                if ($Check) {
                    $control.SelectedIndex = $desiredIndex
                }
                elseif ($control.SelectedIndex -eq $desiredIndex) {
                    $control.SelectedIndex = 0
                }
            }
        }
    }
    finally {
        $script:UpdatingTweakPresets = $wasUpdatingTweakPresets
    }

    if (-not $wasUpdatingTweakPresets) {
        Update-TweakPresetStates -Window $script:MainWindow
    }
}

function Set-TweakPresetCheckBoxState {
    param(
        [System.Windows.Controls.CheckBox]$PresetCheckBox,
        [hashtable]$PresetMap
    )

    if (-not $PresetCheckBox) { return }
    if (-not $PresetMap) {
        $PresetMap = @{}
    }

    $total = $PresetMap.Count
    $selected = 0

    foreach ($target in $PresetMap.Values) {
        $control = $target.Control
        if (-not $control) { continue }

        if ($target.ControlType -eq 'CheckBox' -and $control.IsChecked -eq $true) {
            $selected++
        }
        elseif ($target.ControlType -eq 'ComboBox' -and $control.SelectedIndex -eq [int]$target.DesiredValue) {
            $selected++
        }
    }

    Set-TriStatePresetCheckBoxState -CheckBox $PresetCheckBox -Total $total -Selected $selected
}

function Update-TweakPresetStates {
    param([System.Windows.Window]$Window)

    $script:UpdatingTweakPresets = $true
    try {
        $presetDefaultTweaksBtn = $Window.FindName('PresetDefaultTweaksBtn')
        $presetLastUsedTweaksBtn = $Window.FindName('PresetLastUsedTweaksBtn')
        $presetPrivacyTweaksBtn = $Window.FindName('PresetPrivacyTweaksBtn')
        $presetAITweaksBtn = $Window.FindName('PresetAITweaksBtn')

        Set-TweakPresetCheckBoxState -PresetCheckBox $presetDefaultTweaksBtn -PresetMap $script:DefaultTweakPresetMap
        if ($presetLastUsedTweaksBtn -and $presetLastUsedTweaksBtn.Visibility -ne 'Collapsed') {
            Set-TweakPresetCheckBoxState -PresetCheckBox $presetLastUsedTweaksBtn -PresetMap $script:LastUsedTweakPresetMap
        }
        Set-TweakPresetCheckBoxState -PresetCheckBox $presetPrivacyTweaksBtn -PresetMap $script:PrivacyTweakPresetMap
        Set-TweakPresetCheckBoxState -PresetCheckBox $presetAITweaksBtn -PresetMap $script:AITweakPresetMap
    }
    finally {
        $script:UpdatingTweakPresets = $false
    }
}

function Register-TweakPresetControlStateHandlers {
    param([System.Windows.Window]$Window)

    if (-not $script:UiControlMappings) { return }

    foreach ($controlName in $script:UiControlMappings.Keys) {
        $control = $Window.FindName($controlName)
        if (-not $control) { continue }

        if ($control -is [System.Windows.Controls.CheckBox]) {
            $control.Add_Checked({ if (-not $script:UpdatingTweakPresets) { Update-TweakPresetStates -Window $script:MainWindow } })
            $control.Add_Unchecked({ if (-not $script:UpdatingTweakPresets) { Update-TweakPresetStates -Window $script:MainWindow } })
        }
        elseif ($control -is [System.Windows.Controls.ComboBox]) {
            $control.Add_SelectionChanged({ if (-not $script:UpdatingTweakPresets) { Update-TweakPresetStates -Window $script:MainWindow } })
        }
    }
}

function Initialize-TweakPresetSources {
    param(
        [System.Windows.Window]$Window,
        $DefaultSettingsJson,
        $LastUsedSettingsJson
    )

    $script:DefaultTweakPresetMap = Build-TweakPresetControlMap -Window $Window -SettingsJson $DefaultSettingsJson
    $script:LastUsedTweakPresetMap = Build-TweakPresetControlMap -Window $Window -SettingsJson $LastUsedSettingsJson
    $script:PrivacyTweakPresetMap = Build-CategoryTweakPresetMap -Window $Window -Category 'Privacy & Suggested Content'
    $script:AITweakPresetMap = Build-CategoryTweakPresetMap -Window $Window -Category 'AI'

    $presetLastUsedTweaksBtn = $Window.FindName('PresetLastUsedTweaksBtn')
    if ($presetLastUsedTweaksBtn) {
        $presetLastUsedTweaksBtn.Visibility = if ($script:LastUsedTweakPresetMap.Count -gt 0) { 'Visible' } else { 'Collapsed' }
    }
}

function Update-AppliedTweaksUserModeState {
    param(
        [System.Windows.Controls.CheckBox]$ShowCurrentlyAppliedTweaksCheckBox,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo
    )

    # Show/hide detect applied tweaks checkbox based on user mode
    if ($ShowCurrentlyAppliedTweaksCheckBox) {
        if ($UserSelectionCombo.SelectedIndex -eq 0) {
            $ShowCurrentlyAppliedTweaksCheckBox.Visibility = 'Visible'
        }
        else {
            $ShowCurrentlyAppliedTweaksCheckBox.Visibility = 'Collapsed'
        }
    }

    # Enable/disable user mode combo based on params only (not checkbox)
    if ($script:Params.ContainsKey('Sysprep') -or $script:Params.ContainsKey('User')) {
        $UserSelectionCombo.IsEnabled = $false
    }
    else {
        $UserSelectionCombo.IsEnabled = $true
    }
}

function Update-UserSelectionDescription {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo,
        [System.Windows.Controls.TextBox]$OtherUsernameTextBox,
        [System.Windows.Controls.TextBlock]$UserSelectionDescription
    )

    switch ($UserSelectionCombo.SelectedIndex) {
        0 {
            $currentUserName = GetUserName
            if ([string]::IsNullOrWhiteSpace($currentUserName)) {
                $UserSelectionDescription.Text = "The currently logged-in user profile"
            }
            else {
                $UserSelectionDescription.Text = "The currently logged-in user profile: $currentUserName"
            }
        }
        1 {
            $targetUserName = $OtherUsernameTextBox.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($targetUserName)) {
                $UserSelectionDescription.Text = "A different user profile on this system"
            }
            else {
                $UserSelectionDescription.Text = "A different user profile on this system: $targetUserName"
            }
        }
        default {
            $UserSelectionDescription.Text = "The default user template, affecting all new users created after this point. Useful for Sysprep deployment."
        }
    }

    # Mirror the description text on the combo's tooltip so the same context is shown on hover.
    $UserSelectionCombo.ToolTip = $UserSelectionDescription.Text
}

function Test-OtherUsername {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo,
        [System.Windows.Controls.TextBox]$OtherUsernameTextBox,
        [System.Windows.Controls.TextBlock]$UsernameValidationMessage
    )

    # Only validate if "Other User" is selected
    if ($UserSelectionCombo.SelectedIndex -ne 1) {
        return $true
    }

    $errorBrush = $Window.Resources['ValidationErrorColor']
    $successBrush = $Window.Resources['ValidationSuccessColor']
    $validationResult = Test-TargetUserName -UserName $OtherUsernameTextBox.Text

    $UsernameValidationMessage.Text = $validationResult.Message
    if ($validationResult.IsValid) {
        $UsernameValidationMessage.Foreground = $successBrush
        return $true
    }

    $UsernameValidationMessage.Foreground = $errorBrush
    return $false
}
