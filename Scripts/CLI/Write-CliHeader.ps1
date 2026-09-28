. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        清空控制台并显示带运行模式信息的标题。
    .DESCRIPTION
        标题包含 Win11Debloat 和传入的页面标题；Sysprep 模式追加模式标识，
        其他模式追加当前目标用户名。使用当前控制台语言显示固定文本。
    .PARAMETER title
        显示在程序名称之后的页面标题。
#>
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
