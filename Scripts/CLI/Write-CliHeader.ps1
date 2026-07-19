# Prints the header for the script
function Write-CliHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat Script - $title"

    if ($script:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle (Sysprep mode)"
    }
    else {
        $fullTitle = "$fullTitle (User: $(Get-UserName))"
    }

    Clear-Host
    Write-Host "-------------------------------------------------------------------------------------------"
    Write-Host $fullTitle
    Write-Host "-------------------------------------------------------------------------------------------"
}
