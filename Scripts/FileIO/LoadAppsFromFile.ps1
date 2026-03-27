# Returns list of apps from the specified file, it trims the app names and removes any comments
function LoadAppsFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    if (-not (Test-Path $appsFilePath)) {
        return $appsList
    }

    try {
        # Check if file is JSON or text format
        if ($appsFilePath -like "*.json") {
            # JSON file format
            $jsonContent = Get-Content -Path $appsFilePath -Raw | ConvertFrom-Json
            Foreach ($appData in $jsonContent.Apps) {
                # Handle AppId as array (could be single or multiple IDs)
                $appIdArray = if ($appData.AppId -is [array]) { $appData.AppId } else { @($appData.AppId) }
                $appIdArray = $appIdArray | ForEach-Object { $_.Trim() } | Where-Object { $_.length -gt 0 }
                $selectedByDefault = $appData.SelectedByDefault
                if ($selectedByDefault -and $appIdArray.Count -gt 0) {
                    $appsList += $appIdArray
                }
            }
        }
        else {
            # Legacy text file format
            Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) { 
                if (-not ($app.IndexOf('#') -eq -1)) {
                    $app = $app.Substring(0, $app.IndexOf('#'))
                }

                $app = $app.Trim()
                $appString = $app.Trim('*')
                $appsList += $appString
            }
        }

        return $appsList
    } 
    catch {
        Write-Error "Unable to read apps list from file: $appsFilePath"
        AwaitKeyToExit
    }
}
