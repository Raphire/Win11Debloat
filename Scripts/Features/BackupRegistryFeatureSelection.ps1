function Get-RegistryBackedFeatures {
    param(
        [object[]]$Features = @()
    )

    return @($Features | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.RegistryKey) })
}
