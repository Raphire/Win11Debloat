. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

# Prints the header for the script
function Write-CliHeader {
    param (
        $title
    )

    $fullTitle = (Get-ConsoleTranslation -Text ' Win11Debloat Script - {0}' -FormatArgs @($title))

    if ($script:Params.ContainsKey("Sysprep")) {
        $fullTitle = (Get-ConsoleTranslation -Text '{0} (Sysprep mode)' -FormatArgs @($fullTitle))
    }
    else {
        $fullTitle = (Get-ConsoleTranslation -Text '{0} (User: {1})' -FormatArgs @($fullTitle, $(Get-UserName)))
    }

    Clear-Host
    Write-Host "-------------------------------------------------------------------------------------------"
    Write-Host $fullTitle
    Write-Host "-------------------------------------------------------------------------------------------"
}
