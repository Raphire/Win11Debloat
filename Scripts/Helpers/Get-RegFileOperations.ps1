# Operation type constants, used to indicate the type of operation for each registry entry
$script:OpType_RemoveKey = 'DeleteKey'
$script:OpType_RemoveValue = 'DeleteValue'
$script:OpType_Store = 'SetValue'

function Get-RegFileOperations {
    param(
        [Parameter(Mandatory)]
        [string]$regFilePath
    )

    $content = Get-Content -Path $regFilePath -Raw -ErrorAction Stop
    $rawLines = $content -split "`r?`n"
    
    # Join continuation lines (lines ending with \)
    $lines = @()
    $i = 0
    while ($i -lt $rawLines.Count) {
        $line = $rawLines[$i]
        
        # Join lines that end with backslash to the next line(s)
        while ($line.EndsWith("\") -and $i + 1 -lt $rawLines.Count) {
            $line = $line.Substring(0, $line.Length - 1) + $rawLines[$i + 1]
            $i++
        }
        
        $lines += $line
        $i++
    }
    
    $operations = @()
    $currentKeyPath = $null
    $isDeletedKey = $false
    $opRef = $script:OpType_RemoveKey

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith(';')) {
            continue
        }

        if ($line -match '^Windows Registry Editor Version') {
            continue
        }

        if ($line -match '^\[(?<deleted>-)?(?<keyPath>[^\]]+)\]$') {
            $currentKeyPath = $matches.keyPath.Trim()
            $isDeletedKey = $matches.deleted -eq '-'

            if ($isDeletedKey) {
                $operations += [PSCustomObject]@{
                    OperationType = $opRef
                    KeyPath = $currentKeyPath
                }
            }

            continue
        }

        if (-not $currentKeyPath -or $isDeletedKey) {
            continue
        }

        if ($line -notmatch '^(?<valueName>@|"[^"]+")=(?<valueData>.*)$') {
            continue
        }

        $valueNameToken = $matches.valueName
        $valueName = if ($valueNameToken -eq '@') {
            ''
        }
        else {
            $valueNameToken.Trim('"')
        }

        $parsedValue = Convert-RegValueData -valueData $matches.valueData.Trim()
        if (-not $parsedValue) { continue }

        $operations += [PSCustomObject]@{
            OperationType = $parsedValue.OperationType
            KeyPath = $currentKeyPath
            ValueName = $valueName
            ValueType = $parsedValue.ValueType
            ValueData = $parsedValue.ValueData
        }
    }

    return $operations
}

function Convert-RegValueData {
    param(
        [Parameter(Mandatory)]
        [string]$valueData
    )
    $opStore = $script:OpType_Store
    $opRemove = $script:OpType_RemoveValue

    if ($valueData -eq '-') {
        return [PSCustomObject]@{
            OperationType = $opRemove
            ValueType = $null
            ValueData = $null
        }
    }

    if ($valueData -match '^dword:(?<value>[0-9a-fA-F]{1,8})$') {
        return [PSCustomObject]@{
            OperationType = $opStore
            ValueType = 'DWord'
            ValueData = [uint32]::Parse($matches.value, [System.Globalization.NumberStyles]::HexNumber)
        }
    }

    if ($valueData -match '^qword:(?<value>[0-9a-fA-F]{1,16})$') {
        return [PSCustomObject]@{
            OperationType = $opStore
            ValueType = 'QWord'
            ValueData = [uint64]::Parse($matches.value, [System.Globalization.NumberStyles]::HexNumber)
        }
    }

    if ($valueData -match '^hex(?:\((?<kind>[0-9a-fA-F]+)\))?:(?<bytes>[0-9a-fA-F,\s]+)$') {
        $bytes = Convert-HexStringToByteArray -hexValue $matches.bytes
        $valueType = if ($matches.kind) { "Hex$($matches.kind)" } else { 'Binary' }
        $value = switch ($matches.kind) {
            '2' { Convert-RegistryByteArrayToString -byteData $bytes }
            '7' { Convert-RegistryByteArrayToMultiString -byteData $bytes }
            default { $bytes }
        }

        return [PSCustomObject]@{
            OperationType = $opStore
            ValueType = $valueType
            ValueData = $value
        }
    }

    if ($valueData -match '^"(?<value>.*)"$') {
        $stringValue = $matches.value
        # Unescape registry string escape sequences
        $stringValue = $stringValue -replace '\\"', '"' -replace '\\\\', '\'
        return [PSCustomObject]@{
            OperationType = $opStore
            ValueType = 'String'
            ValueData = $stringValue
        }
    }

    return $null
}

function Convert-HexStringToByteArray {
    param(
        [Parameter(Mandatory)]
        [string]$hexValue
    )

    $parts = $hexValue.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    return [System.Linq.Enumerable]::Select($parts, [Func[object, byte]] {
            param($h) [System.Convert]::ToByte($h, 16)
        }) -as [byte[]]
}

function Convert-RegistryByteArrayToString {
    param(
        [Parameter(Mandatory)]
        [byte[]]$byteData
    )

    return ([System.Text.Encoding]::Unicode.GetString($byteData)).TrimEnd([char]0)
}

function Convert-RegistryByteArrayToMultiString {
    param(
        [Parameter(Mandatory)]
        [byte[]]$byteData
    )

    return @(([System.Text.Encoding]::Unicode.GetString($byteData)).TrimEnd([char]0) -split "`0" | Where-Object { $_ -ne '' })
}
