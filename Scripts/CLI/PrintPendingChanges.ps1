# Prints all pending changes that will be made by the script
function PrintPendingChanges {
    $skippedParams = @()
    $undoChanges = $script:Params.ContainsKey('Undo')

    if ($undoChanges) {
        Write-Output "Win11Debloat will make the following changes to revert the selected settings to Windows defaults:"
    }
    else {
        Write-Output "Win11Debloat will make the following changes:"
    }

    if ($script:Params['CreateRestorePoint']) {
        Write-Output "- $($script:Features['CreateRestorePoint'].Label)"
    }
    foreach ($parameterName in $script:Params.Keys) {
        if ($script:ControlParams -contains $parameterName) {
            continue
        }
        if ($parameterName -eq 'Apps' -or $parameterName -eq 'CreateRestorePoint') {
            continue
        }

        if ($undoChanges) {
            $undoFeature = GetUndoFeatureForParam -paramKey $parameterName
            if (-not $undoFeature) {
                $skippedParams += $parameterName
                continue
            }
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
                    $action = if ($undoChanges -and $script:Features[$parameterName].UndoAction) {
                        $script:Features[$parameterName].UndoAction
                    }
                    else {
                        $script:Features[$parameterName].Action
                    }
                    $message = $script:Features[$parameterName].Label
                    if ($action) {
                        Write-Output "- $action $message"
                    }
                    else {
                        Write-Output "- $message"
                    }
                }
                else {
                    # Fallback: show the parameter name if no feature description is available
                    Write-Output "- $parameterName"
                }
                continue
            }
        }
    }

    if ($undoChanges -and $skippedParams.Count -gt 0) {
        Write-Output ""
        Write-Output "The following changes cannot be automatically undone and will be skipped:"

        $uniqueSkipped = $skippedParams | Sort-Object -Unique
        foreach ($skippedParam in $uniqueSkipped) {
            $action = $script:Features[$skippedParam].Action
            $message = $script:Features[$skippedParam].Label
            Write-Output "- $action $message"
        }
    }

    Write-Output ""
    Write-Output ""
    Write-Output "Press enter to execute the script or press CTRL+C to quit..."
    Read-Host | Out-Null
}