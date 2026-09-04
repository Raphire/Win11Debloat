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
        $result = Show-MessageBox -Message (Get-Translation -Key 'ConfirmRemoveStoreMessage') -Title (Get-Translation -Key 'ConfirmTitle') -Button 'YesNo' -Icon 'Warning' -Owner $Owner

        if ($result -ne 'Yes') {
            return $false
        }
    }

    # Windows Terminal warning
    if ($SelectedApps -contains "Microsoft.WindowsTerminal") {
        $result = Show-MessageBox -Message (Get-Translation -Key 'ConfirmRemoveTerminalMessage') -Title (Get-Translation -Key 'ConfirmTitle') -Button 'YesNo' -Icon 'Warning' -Owner $Owner

        if ($result -ne 'Yes') {
            return $false
        }
    }

    return $true
}
