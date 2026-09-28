# Prints the header for the script
function Write-CliHeader {
    param (
        $title
    )

    $title = switch ($title) {
        'Menu' { '菜单' }
        'Configuration' { '配置' }
        default { $title }
    }
    $fullTitle = " Win11Debloat - $title"

    if ($script:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle（Sysprep 系统部署模式）"
    }
    else {
        $fullTitle = "$fullTitle（用户：$(Get-UserName)）"
    }

    Clear-Host
    Write-Host "-------------------------------------------------------------------------------------------"
    Write-Host $fullTitle
    Write-Host "-------------------------------------------------------------------------------------------"
}
