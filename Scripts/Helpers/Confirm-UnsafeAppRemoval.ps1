<#
    .SYNOPSIS
        Confirms removal of applications that require an extra safety warning.
#>
function Confirm-UnsafeAppRemoval {
    param (
        [string[]]$SelectedApps,
        $Owner = $null
    )

    # Skip all warnings in Silent mode
    if ($Silent) {
        return $true
    }

    # Microsoft Store warning
    if ($SelectedApps -contains "Microsoft.WindowsStore") {
        $result = Show-MessageBox -Message 'Are you sure that you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.' -Title 'Are you sure?' -Button 'YesNo' -Icon 'Warning' -Owner $Owner

        if ($result -ne 'Yes') {
            return $false
        }
    }

    # Windows Terminal warning
    if ($SelectedApps -contains "Microsoft.WindowsTerminal") {
        $result = Show-MessageBox -Message 'Are you sure that you wish to remove Windows Terminal? Windows Terminal is the default command-line app for Windows. Ensure you are not running Win11Debloat via Windows Terminal before proceeding to avoid a mid-process failure.' -Title 'Are you sure?' -Button 'YesNo' -Icon 'Warning' -Owner $Owner

        if ($result -ne 'Yes') {
            return $false
        }
    }

    return $true
}
