# Saves configuration JSON to a file.
# Returns $true on success, $false on failure.
function SaveToFile {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,

        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    try {
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath -Encoding UTF8
        return $true
    }
    catch {
        return $false
    }
}
