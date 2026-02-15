# Prints all pending changes that will be made by the script
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
            'RemoveAppsCustom' {
                $appsList = LoadAppsFromFile $script:CustomAppsListFilePath

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
                if ($script:Features -and $script:Features.ContainsKey($parameterName)) {
                    $action = $script:Features[$parameterName].Action
                    $message = $script:Features[$parameterName].Label
                    Write-Output "- $action $message"
                }
                else {
                    # Fallback: show the parameter name if no feature description is available
                    Write-Output "- $parameterName"
                }
                continue
            }
        }
    }

    Write-Output ""
    Write-Output ""
    Write-Output "Press enter to execute the script or press CTRL+C to quit..."
    Read-Host | Out-Null
}