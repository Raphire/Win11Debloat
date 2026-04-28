function Get-FeatureIdOrFallback {
    param(
        [Parameter(Mandatory)]
        $Feature,
        [Parameter(Mandatory)]
        [string]$FallbackFeatureId
    )

    $featureId = [string]$Feature.FeatureId
    if ([string]::IsNullOrWhiteSpace($featureId)) {
        return $FallbackFeatureId
    }

    return $featureId
}

function Get-RegistryBackedFeatures {
    param(
        [Parameter(Mandatory)]
        [object[]]$Features
    )

    return @($Features | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.RegistryKey) })
}
