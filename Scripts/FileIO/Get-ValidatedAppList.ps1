. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        根据应用目录校验输入列表并返回受支持的应用 ID。
    .DESCRIPTION
        去除每项两端空白和星号后，与 Apps.json 中的应用 ID 比较。
        不支持的项显示提示后跳过；保留有效项的输入顺序和重复项。
    .PARAMETER appsList
        待校验的应用 ID 列表，每项应为可调用 Trim 的字符串。
    .OUTPUTS
        System.String。受支持的应用 ID 集合，不包含被去除的星号。
#>
function Get-ValidatedAppList {
    param (
        $appsList
    )

    $supportedAppsList = @(Import-AppDetailsFromJson | ForEach-Object { @($_.AppId) }) | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
    $validatedAppsList = @()

    # Validate provided appsList against supportedAppsList
    Foreach ($app in $appsList) {
        $app = $app.Trim()
        $appString = $app.Trim('*')

        if ($supportedAppsList -notcontains $appString) {
            Write-Host (Get-ConsoleTranslation -Text 'Removal of app ''{0}'' is not supported and will be skipped' -FormatArgs @($appString)) -ForegroundColor Yellow
            continue
        }

        $validatedAppsList += $appString
    }

    return $validatedAppsList
}
