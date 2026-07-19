<#
    .SYNOPSIS
        Builds the validated application-removal list from the Apps parameter.
#>
function Generate-AppsList {
    if (-not ($script:Params["Apps"] -and $script:Params["Apps"] -is [string])) {
        return @()
    }

    $appMode = $script:Params["Apps"].toLower()

    switch ($appMode) {
        'default' {
            $appsList = Import-AppsFromFile $script:AppsListFilePath
            return $appsList
        }
        default {
            $appsList = $script:Params["Apps"].Split(',') | ForEach-Object { $_.Trim() }
            $validatedAppsList = Get-ValidatedAppList $appsList
            return $validatedAppsList
        }
    }
}
