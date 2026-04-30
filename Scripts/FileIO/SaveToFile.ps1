# Saves configuration JSON to a file.
# Returns $true on success, $false on failure.
function SaveToFile {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,

        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [int]$MaxDepth = 10
    )

    try {
        $Config | ConvertTo-Json -Depth $MaxDepth | Set-Content -Path $FilePath -Encoding UTF8
        return $true
    }
    catch {
        return $false
    }
}
