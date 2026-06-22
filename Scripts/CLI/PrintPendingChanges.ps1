<#
    .SYNOPSIS
        Prints a summary of all pending changes to the console for the user to review.

    .DESCRIPTION
        Iterates over every non-control parameter in $script:Params and emits a
        human-readable line for each change that will be applied. For the
        'RemoveApps' parameter the list of targeted app names is displayed
        inline. Feature labels are resolved from Features.json when available;
        otherwise the raw parameter name is used as a fallback.

        After printing the summary the function pauses until the user presses
        Enter, giving them an opportunity to review and cancel via Ctrl+C.
#>
function PrintPendingChanges {
    Write-Output "Win11Debloat will make the following changes:"

    if ($script:Params['CreateRestorePoint']) {
        Write-Output "- $($script:Features['CreateRestorePoint'].Label)"
    }
    foreach ($parameterName in $script:Params.Keys) {
        if ($script:ControlParams -contains $parameterName) {
            continue
        }

        # Print parameter description
        switch ($parameterName) {
            'Apps' {
                continue
            }
            'CreateRestorePoint' {
                continue
            }
            'RemoveApps' {
                $appsList = GenerateAppsList

                if ($appsList.Count -eq 0) {
                    Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                    Write-Output ""
                    continue
                }

                Write-Output "- Remove $($appsList.Count) apps:"
                Write-Host $appsList -ForegroundColor DarkGray
                continue
            }
            default {
                $message = $script:Features[$parameterName].Label
                Write-Output "- $message"
                continue
            }
        }
    }

    Write-Output ""
    Write-Output ""
    Write-Output "Press enter to execute the script or press CTRL+C to quit..."
    Read-Host | Out-Null
}