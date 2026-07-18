<#
    .SYNOPSIS
        Filters a list of features to those that have a non-empty RegistryKey.

    .PARAMETER Features
        An array of feature objects to filter.
#>
function Get-RegistryBackedFeatures {
    param(
        [object[]]$Features = @()
    )

    return @($Features | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.RegistryKey) })
}
