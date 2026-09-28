<#
    .SYNOPSIS
        Imports a JSON file, optionally validates its version, and returns $null on failure.
#>
function Import-JsonFile {
    param (
        [string]$filePath,
        [string]$expectedVersion = $null,
        [switch]$optionalFile
    )
    
    if (-not (Test-Path $filePath)) {
        if (-not $optionalFile) {
            Write-Error "未找到文件：$filePath"
        }
        return $null
    }
    
    try {
        $jsonContent = Get-Content -Path $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Validate version if specified
        if ($expectedVersion -and $jsonContent.Version -and $jsonContent.Version -ne $expectedVersion) {
            Write-Error "$(Split-Path $filePath -Leaf) 版本不匹配（需要 $expectedVersion，实际为 $($jsonContent.Version)）。"
            return $null
        }
        
        return $jsonContent
    }
    catch {
        Write-Error "解析 JSON 文件失败：$filePath"
        return $null
    }
}
