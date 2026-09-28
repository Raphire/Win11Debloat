. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        Serializes a configuration hashtable to a UTF-8 JSON file.

    .PARAMETER Config
        The configuration data to serialize.

    .PARAMETER FilePath
        The destination file path.

    .PARAMETER MaxDepth
        The maximum object depth passed to ConvertTo-Json.

    .OUTPUTS
        System.Boolean. $true when the file is written; otherwise $false.
#>
function Save-ToFile {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,

        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [int]$MaxDepth = 10
    )

    try {
        $Config | ConvertTo-Json -Depth $MaxDepth | Set-Content -Path $FilePath -Encoding UTF8 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error (Get-ConsoleTranslation -Text 'Failed to write ''{0}'': {1}' -FormatArgs @($FilePath, $($_.Exception.Message)))
        return $false
    }
}
