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
                    OperationType = 'DeleteKey'
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

    if ($valueData -eq '-') {
        return [PSCustomObject]@{
            OperationType = 'DeleteValue'
            ValueType = $null
            ValueData = $null
        }
    }

    if ($valueData -match '^dword:(?<value>[0-9a-fA-F]{1,8})$') {
        return [PSCustomObject]@{
            OperationType = 'SetValue'
            ValueType = 'DWord'
            ValueData = [uint32]::Parse($matches.value, [System.Globalization.NumberStyles]::HexNumber)
        }
    }

    if ($valueData -match '^qword:(?<value>[0-9a-fA-F]{1,16})$') {
        return [PSCustomObject]@{
            OperationType = 'SetValue'
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
            OperationType = 'SetValue'
            ValueType = $valueType
            ValueData = $value
        }
    }

    if ($valueData -match '^"(?<value>.*)"$') {
        return [PSCustomObject]@{
            OperationType = 'SetValue'
            ValueType = 'String'
            ValueData = $matches.value
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
    $bytes = New-Object byte[] $parts.Count

    for ($i = 0; $i -lt $parts.Count; $i++) {
        $bytes[$i] = [byte]::Parse($parts[$i], [System.Globalization.NumberStyles]::HexNumber)
    }

    return $bytes
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
