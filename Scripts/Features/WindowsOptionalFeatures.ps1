# Enables a Windows optional feature and pipes its output to the console
function EnableWindowsFeature {
    param (
        [string]$FeatureName
    )

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Enable Windows feature: $FeatureName" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    $result = Invoke-NonBlocking -ScriptBlock {
        param($name)
        Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart
    } -ArgumentList $FeatureName

    $dismResult = @($result) | Where-Object { $_ -is [Microsoft.Dism.Commands.ImageObject] }
    if ($dismResult) {
        Write-Host ($dismResult | Out-String).Trim()
    }
}

# Disables a Windows optional feature and pipes its output to the console
function DisableWindowsFeature {
    param (
        [string]$FeatureName
    )

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Disable Windows feature: $FeatureName" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    $result = Invoke-NonBlocking -ScriptBlock {
        param($name)
        Disable-WindowsOptionalFeature -Online -FeatureName $name -NoRestart
    } -ArgumentList $FeatureName

    $dismResult = @($result) | Where-Object { $_ -is [Microsoft.Dism.Commands.ImageObject] }
    if ($dismResult) {
        Write-Host ($dismResult | Out-String).Trim()
    }
}

function Test-WindowsOptionalFeatureEnabled {
    param (
        [Parameter(Mandatory)]
        [string]$FeatureName
    )

    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    }
    catch {
        return $false
    }

    return ($feature.State -eq 'Enabled')
}