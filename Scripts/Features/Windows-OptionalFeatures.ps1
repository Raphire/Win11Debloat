<#
    .SYNOPSIS
    Enables a Windows optional feature and pipes its output to the console.

    .OUTPUTS
    System.Boolean. $true when enabling succeeds or is previewed; otherwise $false.
#>
function Enable-WindowsFeature {
    param (
        [string]$FeatureName
    )

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Enable Windows feature: $FeatureName" -ForegroundColor Cyan
        return $true
    }

    try {
        $result = Invoke-NonBlocking -ScriptBlock {
            param($name)
            try {
                $output = Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart -ErrorAction Stop
                return [PSCustomObject]@{
                    Success = $true
                    Output = if ($output) { ($output | Out-String).Trim() } else { $null }
                    Error = $null
                }
            }
            catch {
                return [PSCustomObject]@{
                    Success = $false
                    Output = $null
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $FeatureName
    }
    catch {
        Write-Warning "Failed to enable Windows feature '$FeatureName': $($_.Exception.Message)"
        return $false
    }

    if (-not $result -or -not $result.Success) {
        $details = if ($result -and $result.Error) { ": $($result.Error)" } else { '' }
        Write-Warning "Failed to enable Windows feature '$FeatureName'$details"
        return $false
    }

    if ($result.Output) { Write-Host $result.Output }
    return $true
}

<#
    .SYNOPSIS
    Disables a Windows optional feature and pipes its output to the console.

    .OUTPUTS
    System.Boolean. $true when disabling succeeds or is previewed; otherwise $false.
#>
function Disable-WindowsFeature {
    param (
        [string]$FeatureName
    )

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Disable Windows feature: $FeatureName" -ForegroundColor Cyan
        return $true
    }

    try {
        $result = Invoke-NonBlocking -ScriptBlock {
            param($name)
            try {
                $output = Disable-WindowsOptionalFeature -Online -FeatureName $name -NoRestart -ErrorAction Stop
                return [PSCustomObject]@{
                    Success = $true
                    Output = if ($output) { ($output | Out-String).Trim() } else { $null }
                    Error = $null
                }
            }
            catch {
                return [PSCustomObject]@{
                    Success = $false
                    Output = $null
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $FeatureName
    }
    catch {
        Write-Warning "Failed to disable Windows feature '$FeatureName': $($_.Exception.Message)"
        return $false
    }

    if (-not $result -or -not $result.Success) {
        $details = if ($result -and $result.Error) { ": $($result.Error)" } else { '' }
        Write-Warning "Failed to disable Windows feature '$FeatureName'$details"
        return $false
    }

    if ($result.Output) { Write-Host $result.Output }
    return $true
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
