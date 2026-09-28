# 控制台可能先于图形界面启动，按需读取独立资源；缺失或损坏时保留英文提示。
function Get-ConsoleTranslation {
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
