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
        Write-Host "[模拟运行] 将启用 Windows 功能：$FeatureName" -ForegroundColor Cyan
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
        Write-Warning "启用 Windows 功能 '$FeatureName' 失败：$($_.Exception.Message)"
        return $false
    }

    if (-not $result -or -not $result.Success) {
        $details = if ($result -and $result.Error) { ": $($result.Error)" } else { '' }
        Write-Warning "启用 Windows 功能 '$FeatureName' 失败。$details"
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
        Write-Host "[模拟运行] 将禁用 Windows 功能：$FeatureName" -ForegroundColor Cyan
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
        Write-Warning "禁用 Windows 功能 '$FeatureName' 失败：$($_.Exception.Message)"
        return $false
    }

    if (-not $result -or -not $result.Success) {
        $details = if ($result -and $result.Error) { ": $($result.Error)" } else { '' }
        Write-Warning "禁用 Windows 功能 '$FeatureName' 失败。$details"
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
