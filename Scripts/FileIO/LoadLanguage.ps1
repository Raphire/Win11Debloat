# LoadLanguage.ps1
# Detects the system UI language, loads the matching language file from Config/Languages/,
# and provides a helper to substitute %LANG:Key% markers in XAML strings.

function LoadLanguage {
    param ([string]$LanguageCode = "")

    if ([string]::IsNullOrEmpty($LanguageCode)) {
        $LanguageCode = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    }

    $langDir = $script:LanguagesPath
    $langPrefix = if ($LanguageCode.Length -ge 2) { $LanguageCode.Substring(0, 2) } else { $LanguageCode }

    # Try: exact match (e.g. "es-ES"), language prefix glob (e.g. "es-*.json"), then "en-US" fallback
    $candidates = @(
        @{ Exact = "$LanguageCode.json" ; Glob = $null }
        @{ Exact = $null               ; Glob = "$langPrefix-*.json" }
        @{ Exact = "en-US.json"        ; Glob = $null }
    )

    foreach ($candidate in $candidates) {
        $filePath = $null

        if ($candidate.Exact) {
            $path = Join-Path $langDir $candidate.Exact
            if (Test-Path $path) { $filePath = $path }
        }
        elseif ($candidate.Glob) {
            $match = Get-ChildItem -Path $langDir -Filter $candidate.Glob -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) { $filePath = $match.FullName }
        }

        if ($filePath) {
            try {
                $lang = Get-Content -Path $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
                Write-Verbose "Win11Debloat: loaded language '$($lang.LanguageName)' from '$filePath'"
                return $lang
            }
            catch {
                Write-Warning "Win11Debloat: failed to load language file '$filePath': $_"
            }
        }
    }

    Write-Warning "Win11Debloat: no language file found in '$langDir', UI will show placeholder keys"
    return $null
}

function ConvertTo-LocalizedXaml {
    param (
        [string]$Xaml,
        [object]$Lang
    )

    if ($null -eq $Lang) { return $Xaml }

    $skipKeys = @('Version', 'LanguageName', 'NativeName', 'LanguageCode')

    foreach ($prop in $Lang.PSObject.Properties) {
        if ($prop.Name -in $skipKeys) { continue }
        # XML-escape the value so characters like & < > are safe in XAML attributes
        $escaped = [System.Security.SecurityElement]::Escape([string]$prop.Value)
        $Xaml = $Xaml.Replace("%LANG:$($prop.Name)%", $escaped)
    }

    # Safety net: remove any leftover unmatched markers so they don't appear as literal text
    $Xaml = [System.Text.RegularExpressions.Regex]::Replace($Xaml, '%LANG:[^%]+%', '')

    return $Xaml
}

# Shorthand used throughout PowerShell scripts: returns the translated string or the key itself as fallback
function L {
    param ([string]$Key)
    if ($null -ne $script:Lang) {
        $val = $script:Lang.$Key
        if ($null -ne $val) { return [string]$val }
    }
    return $Key
}
