# 控制台可能先于图形界面启动，按需读取独立资源；缺失或损坏时保留英文提示。
function Get-ConsoleTranslation {
<#
    .SYNOPSIS
        获取控制台提示译文，缺失时保留英文模板。
    .DESCRIPTION
        优先使用传入的 LanguageCode，默认取脚本控制台语言，再取界面语言或 en-US。
        英文直接使用 Text；其他语言按完整代码、语言前缀查找并缓存 Console.json。
        文件缺失、无法读取或对应译文为空时使用 Text。
        提供格式参数时替换占位符；译文格式化失败则尝试格式化英文模板。
    .PARAMETER Text
        同时作为资源键和回退文本的英文提示模板。
    .PARAMETER FormatArgs
        按顺序填入模板占位符的参数；为空时不执行格式化。
    .PARAMETER LanguageCode
        要使用的语言代码，例如 zh-CN 或 en-US。
    .OUTPUTS
        System.String。译文或英文回退文本，可包含已替换的参数。
#>
    param(
        [Parameter(Mandatory)][string]$Text,
        [object[]]$FormatArgs = $null,
        [string]$LanguageCode = $script:ConsoleLanguageCode
    )

    if (-not $LanguageCode) {
        $LanguageCode = if ($script:Lang) { $script:Lang.LanguageCode } else { 'en-US' }
    }
    $translated = $Text
    if ($LanguageCode -notlike 'en*') {
        if ($script:ConsoleTranslationCacheCode -ne $LanguageCode) {
            $script:ConsoleTranslationCache = $null
            $script:ConsoleTranslationCacheCode = $LanguageCode
            $languages = Join-Path $PSScriptRoot '../../Config/Languages'
            $folder = Join-Path $languages $LanguageCode
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
                $prefix = ($LanguageCode -split '-')[0]
                $match = Get-ChildItem -LiteralPath $languages -Directory -Filter "$prefix-*" -ErrorAction SilentlyContinue | Select-Object -First 1
                $folder = if ($match) { $match.FullName } else { $null }
            }
            if ($folder) {
                try {
                    $script:ConsoleTranslationCache = Get-Content -LiteralPath (Join-Path $folder 'Console.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                }
                catch { }
            }
        }
        if ($script:ConsoleTranslationCache) {
            $entry = $script:ConsoleTranslationCache.PSObject.Properties[$Text]
            if ($entry -and -not [string]::IsNullOrWhiteSpace([string]$entry.Value)) { $translated = [string]$entry.Value }
        }
    }
    if ($null -ne $FormatArgs -and $FormatArgs.Count -gt 0) {
        try { return $translated -f $FormatArgs }
        catch { return $Text -f $FormatArgs }
    }
    return $translated
}
