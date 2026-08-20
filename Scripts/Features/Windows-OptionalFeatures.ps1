# Enables a Windows optional feature and pipes its output to the console
function Enable-WindowsFeature {
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
function Disable-WindowsFeature {
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
        return $feature.State -eq 'Enabled'
    }
    catch {
        return $false
    }
}

function Set-WindowsHibernate {
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    $state = if ($Enabled) { 'on' } else { 'off' }

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] powercfg /hibernate $state" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    $null = Invoke-NonBlocking -ScriptBlock {
        param($hibernateState)
        $powerCfg = Join-Path $env:SystemRoot 'System32\powercfg.exe'
        $process = Start-Process -FilePath $powerCfg -ArgumentList @('/hibernate', $hibernateState) -Wait -PassThru -WindowStyle Hidden
        if ($null -eq $process -or $process.ExitCode -ne 0) {
            $exitCode = if ($process) { $process.ExitCode } else { 'unknown' }
            throw "powercfg /hibernate $hibernateState failed with exit code $exitCode"
        }
    } -ArgumentList $state
}

function Test-WindowsHibernateDisabled {
    try {
        $value = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -ErrorAction Stop
        return ([int]$value -eq 0)
    }
    catch {
        return $false
    }
}
