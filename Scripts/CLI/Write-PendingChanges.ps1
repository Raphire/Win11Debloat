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
function Write-PendingChanges {
    Write-Output "Win11Debloat 将执行以下更改："

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
                $appsList = Generate-AppsList

                if ($appsList.Count -eq 0) {
                    Write-Host "未选择任何可移除的有效应用。" -ForegroundColor Yellow
                    Write-Output ""
                    continue
                }

                Write-Output "- 移除 $($appsList.Count) 个应用："
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
    Write-Output "按回车键执行，或按 Ctrl+C 退出……"
    Read-Host | Out-Null
}
