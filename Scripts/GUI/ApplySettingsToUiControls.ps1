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
    
    # First, reset all tweaks to "No Change" (index 0) or unchecked
    if ($uiControlMappings) {
        foreach ($comboName in $uiControlMappings.Keys) {
            $control = $window.FindName($comboName)
            if ($control -is [System.Windows.Controls.CheckBox]) {
                $control.IsChecked = $false
            }
            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                $control.SelectedIndex = 0
            }
        }
    }
    
    # Apply settings from JSON
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -ne $true) { continue }
        $paramName = $setting.Name

        # Skip RestorePointCheckBox, this is always checked by default
        if ($paramName -eq 'CreateRestorePoint') {
            continue
        }

        if ($uiControlMappings) {
            foreach ($comboName in $uiControlMappings.Keys) {
                $mapping = $uiControlMappings[$comboName]
                if ($mapping.Type -eq 'group') {
                    $i = 1
                    foreach ($val in $mapping.Values) {
                        if ($val.FeatureIds -contains $paramName) {
                            $control = $window.FindName($comboName)
                            if ($control -and $control.Visibility -eq 'Visible') {
                                if ($control -is [System.Windows.Controls.ComboBox]) {
                                    $control.SelectedIndex = $i
                                }
                            }
                            break
                        }
                        $i++
                    }
                }
                elseif ($mapping.Type -eq 'feature') {
                    if ($mapping.FeatureId -eq $paramName) {
                        $control = $window.FindName($comboName)
                        if ($control -and $control.Visibility -eq 'Visible') {
                            if ($control -is [System.Windows.Controls.CheckBox]) {
                                $control.IsChecked = $true
                            }
                            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                                $control.SelectedIndex = 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $true
}
