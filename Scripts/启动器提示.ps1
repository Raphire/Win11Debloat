param([Parameter(Mandatory)][string]$Text, [string]$Value)
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'FileIO/获取控制台翻译.ps1')
$script:ConsoleLanguageCode = $PSUICulture
if ($PSBoundParameters.ContainsKey('Value')) {
    $translatedValue = Get-ConsoleTranslation -Text $Value
    Write-Output (Get-ConsoleTranslation -Text $Text -FormatArgs @($translatedValue))
} else {
    Write-Output (Get-ConsoleTranslation -Text $Text)
}
