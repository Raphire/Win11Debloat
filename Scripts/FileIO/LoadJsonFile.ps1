# Loads a JSON file from the specified path and returns the parsed object
# Returns $null if the file doesn't exist or if parsing fails
function LoadJsonFile {
    param (
        [string]$filePath,
        [string]$expectedVersion = $null,
        [switch]$optionalFile
    )
    
    if (-not (Test-Path $filePath)) {
        if (-not $optionalFile) {
            Write-Error "File not found: $filePath"
        }
        return $null
    }
    
    try {
        $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        
        # Validate version if specified
        if ($expectedVersion -and $jsonContent.Version -and $jsonContent.Version -ne $expectedVersion) {
            Write-Error "$(Split-Path $filePath -Leaf) version mismatch (expected $expectedVersion, found $($jsonContent.Version))"
            return $null
        }
        
        return $jsonContent
    }
    catch {
        Write-Error "Failed to parse JSON file: $filePath"
        return $null
    }
}
