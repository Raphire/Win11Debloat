function Get-FeatureId {
    param(
        [Parameter(Mandatory)]
        $Feature
    )

    $featureId = [string]$Feature.FeatureId
    if ([string]::IsNullOrWhiteSpace($featureId)) {
        throw 'Selected feature is missing required FeatureId.'
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
