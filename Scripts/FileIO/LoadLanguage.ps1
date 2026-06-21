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

# Returns the translated category name, or the original English name if no translation exists
function Get-LangCategory {
    param ([string]$Name)
    if ($null -ne $script:Lang -and $null -ne $script:Lang.FeaturesCategories) {
        $val = $script:Lang.FeaturesCategories.$Name
        if ($null -ne $val) { return [string]$val }
    }
    return $Name
}

# Returns the translated feature label (keyed by FeatureId), falling back to the English label
function Get-LangFeature {
    param ([string]$FeatureId, [string]$Fallback = "")
    if ($null -ne $script:Lang -and $null -ne $script:Lang.FeaturesLabels) {
        $val = $script:Lang.FeaturesLabels.$FeatureId
        if ($null -ne $val) { return [string]$val }
    }
    return $Fallback
}

# Returns the translated group label (keyed by GroupId), falling back to the English label
function Get-LangGroupLabel {
    param ([string]$GroupId, [string]$Fallback = "")
    if ($null -ne $script:Lang -and $null -ne $script:Lang.FeaturesGroups) {
        $group = $script:Lang.FeaturesGroups.$GroupId
        if ($null -ne $group -and $null -ne $group.Label) { return [string]$group.Label }
    }
    return $Fallback
}

# Returns the translated tooltip for a feature (keyed by FeatureId), falling back to the English tooltip
function Get-LangFeatureTooltip {
    param ([string]$FeatureId, [string]$Fallback = "")
    if ($null -ne $script:Lang -and $null -ne $script:Lang.FeaturesToolTips) {
        $val = $script:Lang.FeaturesToolTips.$FeatureId
        if ($null -ne $val) { return [string]$val }
    }
    return $Fallback
}

# Returns the translated tooltip for a UI group (keyed by GroupId), falling back to the English tooltip
function Get-LangGroupTooltip {
    param ([string]$GroupId, [string]$Fallback = "")
    if ($null -ne $script:Lang -and $null -ne $script:Lang.GroupsToolTips) {
        $val = $script:Lang.GroupsToolTips.$GroupId
        if ($null -ne $val) { return [string]$val }
    }
    return $Fallback
}

# Returns the translated label for a group value, identified by its primary FeatureId
function Get-LangGroupValue {
    param ([string]$GroupId, [string[]]$FeatureIds, [string]$Fallback = "")
    if ($null -ne $script:Lang -and $null -ne $script:Lang.FeaturesGroups -and $FeatureIds.Count -gt 0) {
        $group = $script:Lang.FeaturesGroups.$GroupId
        if ($null -ne $group -and $null -ne $group.Values) {
            $primaryId = $FeatureIds[0]
            $val = $group.Values.$primaryId
            if ($null -ne $val) { return [string]$val }
        }
    }
    return $Fallback
}
