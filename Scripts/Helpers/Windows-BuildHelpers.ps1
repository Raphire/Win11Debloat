# Returns the build number of the running Windows version, or $null when it cannot be read.
function Get-CurrentWindowsBuild {
    $build = 0
    try {
        # Get-ItemPropertyValue reports a missing value as a terminating error, which -ErrorAction SilentlyContinue does not suppress
        $currentBuild = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild -ErrorAction Stop
    }
    catch {
        Write-Verbose "Unable to read the Windows build number: $($_.Exception.Message)"
        return $null
    }
    if ([int]::TryParse([string]$currentBuild, [ref]$build)) { return $build }
    return $null
}

# Checks a feature's MinVersion / MaxVersion (Windows build numbers from Features.json) against a build number.
# A feature without limits, or a build that is not known, is treated as supported.
function Test-FeatureSupportedOnBuild {
    param(
        $Feature,
        $Build
    )

    if ($null -eq $Feature -or $null -eq $Build) { return $true }
    if ($Feature.MinVersion -and [int]$Build -lt [int]$Feature.MinVersion) { return $false }
    if ($Feature.MaxVersion -and [int]$Build -gt [int]$Feature.MaxVersion) { return $false }
    return $true
}
