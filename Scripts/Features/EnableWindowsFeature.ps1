# Enables a Windows optional feature and pipes its output to the console
function EnableWindowsFeature {
    param (
        [string]$FeatureName
    )

    $result = Invoke-NonBlocking -ScriptBlock {
        param($name)
        Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart
    } -ArgumentList $FeatureName

    $dismResult = @($result) | Where-Object { $_ -is [Microsoft.Dism.Commands.ImageObject] }
    if ($dismResult) {
        Write-Host ($dismResult | Out-String).Trim()
    }
}