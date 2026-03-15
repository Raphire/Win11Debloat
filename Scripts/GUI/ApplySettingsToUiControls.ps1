# Applies settings from a JSON object to UI controls (checkboxes and comboboxes)
# Used by LoadDefaultsBtn and LoadLastUsedBtn in the UI
function ApplySettingsToUiControls {
    param (
        $window,
        $settingsJson,
        $uiControlMappings
    )
    
    if (-not $settingsJson -or -not $settingsJson.Settings) {
        return $false
    }
    
    if (-not $uiControlMappings) {
        return $true
    }

    # Build control cache and reverse index (featureId -> control info) in a single pass
    $controlCache = @{}
    $featureIdIndex = @{}

    foreach ($comboName in $uiControlMappings.Keys) {
        $control = $window.FindName($comboName)
        if (-not $control) { continue }
        $controlCache[$comboName] = $control

        $mapping = $uiControlMappings[$comboName]
        if ($mapping.Type -eq 'group') {
            $i = 1
            foreach ($val in $mapping.Values) {
                foreach ($fid in $val.FeatureIds) {
                    $featureIdIndex[$fid] = @{ ComboName = $comboName; Control = $control; Index = $i; MappingType = 'group' }
                }
                $i++
            }
        }
        elseif ($mapping.Type -eq 'feature') {
            $featureIdIndex[$mapping.FeatureId] = @{ ComboName = $comboName; Control = $control; MappingType = 'feature' }
        }

        # Reset control to default state
        if ($control -is [System.Windows.Controls.CheckBox]) {
            $control.IsChecked = $false
        }
        elseif ($control -is [System.Windows.Controls.ComboBox]) {
            $control.SelectedIndex = 0
        }
    }
    
    # Apply settings using O(1) lookups
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -ne $true) { continue }
        if ($setting.Name -eq 'CreateRestorePoint') { continue }

        $entry = $featureIdIndex[$setting.Name]
        if (-not $entry) { continue }

        $control = $entry.Control
        if (-not $control -or $control.Visibility -ne 'Visible') { continue }

        if ($entry.MappingType -eq 'group') {
            if ($control -is [System.Windows.Controls.ComboBox]) {
                $control.SelectedIndex = $entry.Index
            }
        }
        else {
            if ($control -is [System.Windows.Controls.CheckBox]) {
                $control.IsChecked = $true
            }
            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                $control.SelectedIndex = 1
            }
        }
    }
    
    return $true
}
