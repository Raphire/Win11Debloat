<#
    .SYNOPSIS
        Returns a list of app IDs from the specified JSON file.

    .DESCRIPTION
        Reads an Apps.json file and returns the AppIds for every entry where
        SelectedByDefault is $true. Each app entry may declare a single AppId
        or an array of AppIds; both forms are handled transparently.

    .PARAMETER appsFilePath
        Path to a JSON file in the Config/Apps.json format.

    .OUTPUTS
        System.String[]. An array of app ID strings, or an empty array if the
        file does not exist or contains no selected-by-default apps.
#>
function LoadAppsFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    if (-not (Test-Path $appsFilePath)) {
        return $appsList
    }

    try {
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

        return $appsList
    } 
    catch {
        Write-Error "Unable to read apps list from file: $appsFilePath"
        AwaitKeyToExit
    }
}
