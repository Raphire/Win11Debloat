<#
    .SYNOPSIS
        Saves active feature settings, excluding control parameters, unless running in WhatIf mode.
#>
function Save-Settings {
    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[模拟运行] 将设置保存到 LastUsedSettings.json。" -ForegroundColor Cyan
        return
    }

    $settings = @{
        "Version" = "1.0"
        "Settings" = @()
    }
    
    foreach ($param in $script:Params.Keys) {
        if ($script:ControlParams -notcontains $param -and $script:Features.ContainsKey($param)) {
            $value = $script:Params[$param]

            $settings.Settings += @{
                "Name" = $param
                "Value" = $value
            }
        }
    }

    if (-not (Save-ToFile -Config $settings -FilePath $script:SavedSettingsFilePath)) {
        Write-Output ""
        Write-Host "错误：无法将设置保存到 LastUsedSettings.json 文件。" -ForegroundColor Red
    }
}
