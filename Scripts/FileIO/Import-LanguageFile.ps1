<#
    .SYNOPSIS
        Resolves a language code to an available Config/Languages folder, or falls back to en-US.
#>
function Resolve-LanguageFolder {
    param(
        [Parameter(Mandatory)]
        [string]$LanguageCode,
        [string]$LanguagesPath = $script:LanguagesPath
    )

    $exactPath = Join-Path $LanguagesPath $LanguageCode
    if (Test-Path $exactPath -PathType Container) {
        return $LanguageCode
    }

    $languagePrefix = ($LanguageCode -split '-')[0]
    $prefixMatch = Get-ChildItem -Path $LanguagesPath -Directory -Filter "$languagePrefix-*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($prefixMatch) {
        return $prefixMatch.Name
    }

    return 'en-US'
}

<#
    .SYNOPSIS
        Loads Chrome/Features/Categories JSON for a language folder, or returns $null on failure.
#>
function Import-LanguageContent {
    param(
        [Parameter(Mandatory)]
        [string]$LanguageFolder,
        [string]$LanguagesPath = $script:LanguagesPath
    )

    $folderPath = Join-Path $LanguagesPath $LanguageFolder
    $chrome = Import-JsonFile -filePath (Join-Path $folderPath 'Chrome.json')
    $features = Import-JsonFile -filePath (Join-Path $folderPath 'Features.json')
    $categories = Import-JsonFile -filePath (Join-Path $folderPath 'Categories.json')

    if (-not $chrome -or -not $features -or -not $categories) {
        return $null
    }

    return [PSCustomObject]@{
        LanguageCode = $LanguageFolder
        Chrome       = $chrome
        Features     = $features.Features
        UiGroups     = $features.UiGroups
        Categories   = $categories
    }
}

<#
    .SYNOPSIS
        Loads the active language content, falling back to en-US when the requested language fails to load.
#>
function Import-LanguageFile {
    param(
        [string]$LanguageCode = ([System.Globalization.CultureInfo]::CurrentUICulture.Name),
        [string]$LanguagesPath = $script:LanguagesPath
    )

    $resolvedFolder = Resolve-LanguageFolder -LanguageCode $LanguageCode -LanguagesPath $LanguagesPath
    $content = Import-LanguageContent -LanguageFolder $resolvedFolder -LanguagesPath $LanguagesPath

    if (-not $content -and $resolvedFolder -ne 'en-US') {
        Write-Warning "Failed to load language '$resolvedFolder', falling back to en-US."
        $content = Import-LanguageContent -LanguageFolder 'en-US' -LanguagesPath $LanguagesPath
    }

    if (-not $content) {
        Write-Error "Unable to load the en-US language files. The GUI cannot continue without them."
        return $null
    }

    if ($content.LanguageCode -ne 'en-US') {
        $content | Add-Member -MemberType NoteProperty -Name 'Fallback' -Value (Import-LanguageContent -LanguageFolder 'en-US' -LanguagesPath $LanguagesPath)
    }

    return $content
}

<#
    .SYNOPSIS
        Returns the CLDR plural category ('one', 'other', etc.) for a count in the given language.

    .DESCRIPTION
        Each language's CLDR plural rule is its own case, keyed by language prefix ('en' matches
        both 'en-US' and 'en-GB'). A language without a case falls back to the English rule, which
        is also correct for Dutch and German but wrong for languages with 3+ plural categories or
        a different singular/plural split.
#>
function Get-PluralCategory {
    param(
        [Parameter(Mandatory)]
        [string]$LanguageCode,
        [Parameter(Mandatory)]
        [int]$Count
    )

    $languagePrefix = ($LanguageCode -split '-')[0].ToLowerInvariant()

    switch ($languagePrefix) {
        # English CLDR rule: singular only for exactly 1, plural otherwise. Also correct for Dutch/German.
        default {
            if ($Count -eq 1) {
                return 'one'
            }

            return 'other'
        }
    }
}

<#
    .SYNOPSIS
        Returns a language and its Fallback (if any) as an ordered lookup chain, skipping nulls.
#>
function Get-LanguageFallbackChain {
    param(
        [object]$Lang
    )

    return @($Lang, $Lang.Fallback) | Where-Object { $_ }
}

<#
    .SYNOPSIS
        Finds the named section object (Chrome, Features, UiGroups, or Categories) that owns a key.

    .DESCRIPTION
        A FeatureId, GroupId, and CategoryId aren't guaranteed to be disjoint (Config/Features.json
        can and does reuse the same string as both a GroupId and a FeatureId), so the default search
        order below is only a fallback for callers who don't know which section their key belongs to.
        Pass -Section to look in exactly one section instead of guessing from the order.
#>
function Find-TranslationSection {
    param(
        [Parameter(Mandatory)]
        [object]$Lang,
        [Parameter(Mandatory)]
        [string]$Key,
        [ValidateSet('', 'Chrome', 'Features', 'UiGroups', 'Categories')]
        [string]$Section = ''
    )

    if ($Section) {
        $sectionObject = $Lang.$Section
        if ($sectionObject -and $sectionObject.PSObject.Properties[$Key]) {
            return $sectionObject
        }
        return $null
    }

    foreach ($sectionName in 'Chrome', 'Features', 'UiGroups', 'Categories') {
        $sectionObject = $Lang.$sectionName
        if ($sectionObject -and $sectionObject.PSObject.Properties[$Key]) {
            return $sectionObject
        }
    }

    return $null
}

<#
    .SYNOPSIS
        Looks up a translated value from the active language, falling back to en-US, then to the key itself.

    .DESCRIPTION
        Chrome.json keys are flat strings, so -Field is omitted for those. Features/UiGroups/Categories
        keys (FeatureId/GroupId/CategoryId) resolve to an object, so -Field picks the property on it
        (Label, ToolTip, ApplyText, UndoLabel, ApplyUndoText). One generic lookup covers every section
        instead of a separate function per section.

        A FeatureId and a GroupId aren't guaranteed to be distinct strings, so pass -Section
        ('Features', 'UiGroups', or 'Categories') whenever the caller knows which one it means,
        rather than relying on Find-TranslationSection's search order to guess correctly.

        When -Count is supplied, tries the plural-suffixed key ("$Key`_$category") before the bare key,
        so callers don't need to add a plural variant for every string, only the ones that need one.
    .OUTPUTS
        System.String. The translated string, or the original Key if no language has it.
#>
function Get-Translation {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [string]$Field = $null,
        [object]$Lang = $script:Lang,
        [Nullable[int]]$Count = $null,
        [object[]]$FormatArgs = $null,
        [ValidateSet('', 'Chrome', 'Features', 'UiGroups', 'Categories')]
        [string]$Section = ''
    )

    if (-not $Lang) {
        return $Key
    }

    $lookupKeys = @($Key)
    if ($null -ne $Count) {
        $category = Get-PluralCategory -LanguageCode $Lang.LanguageCode -Count $Count
        $lookupKeys = @("${Key}_$category", $Key)
    }

    $resolved = $Key
    :langLoop foreach ($candidateLang in (Get-LanguageFallbackChain -Lang $Lang)) {
        foreach ($lookupKey in $lookupKeys) {
            $sectionObject = Find-TranslationSection -Lang $candidateLang -Key $lookupKey -Section $Section
            if (-not $sectionObject) { continue }

            $entry = $sectionObject.$lookupKey
            if ($Field) {
                if ($entry.PSObject.Properties[$Field]) {
                    $resolved = [string]$entry.$Field
                    break langLoop
                }
                continue
            }

            $resolved = [string]$entry
            break langLoop
        }
    }

    if ($null -ne $FormatArgs -and $FormatArgs.Count -gt 0) {
        try {
            return $resolved -f $FormatArgs
        }
        catch {
            Write-Warning "Translation '$Key' has a placeholder mismatch with its format arguments: $($_.Exception.Message)"
            return $resolved
        }
    }

    return $resolved
}

<#
    .SYNOPSIS
        Looks up a translated label for one value of a UiGroup, falling back to en-US, then to the raw label.

    .DESCRIPTION
        UiGroups[GroupId].Values in the language files is a FeatureId -> Label map, one level deeper
        than Get-Translation's -Field lookup handles, so this has its own small fallback walk instead
        of overloading Get-Translation's flat-field shape.
#>
function Get-GroupValueTranslation {
    param(
        [Parameter(Mandatory)]
        [string]$GroupId,
        [Parameter(Mandatory)]
        [string]$FeatureId,
        [Parameter(Mandatory)]
        [string]$FallbackLabel,
        [object]$Lang = $script:Lang
    )

    if (-not $Lang) {
        return $FallbackLabel
    }

    foreach ($candidateLang in (Get-LanguageFallbackChain -Lang $Lang)) {
        if (-not $candidateLang.UiGroups) { continue }

        $group = $candidateLang.UiGroups.$GroupId
        if (-not $group -or -not $group.Values) { continue }

        $valueEntry = $group.Values.PSObject.Properties[$FeatureId]
        if ($valueEntry) {
            return [string]$valueEntry.Value
        }
    }

    return $FallbackLabel
}

<#
    .SYNOPSIS
        Flattens a loaded language object into a sorted set of dotted key paths.

    .DESCRIPTION
        Chrome.json keys are already flat and are used as-is. Features/UiGroups/Categories
        keys are one level deeper (EntryId -> {Field: value}), so each field becomes its own
        "Section.EntryId.Field" path (e.g. "Features.DisableTelemetry.Label"). UiGroups' nested
        Values map becomes "UiGroups.GroupId.Values.FeatureId". Used by Test-LanguageKeyCoverage
        to diff one language's key set against another's.
#>
function Get-LanguageKeyPaths {
    param(
        [Parameter(Mandatory)]
        [object]$Lang
    )

    $paths = New-Object System.Collections.Generic.List[string]

    foreach ($chromeKey in @($Lang.Chrome.PSObject.Properties.Name)) {
        if ([string]::IsNullOrEmpty($chromeKey)) { continue }
        $paths.Add($chromeKey)
    }

    foreach ($sectionName in 'Features', 'Categories') {
        $section = $Lang.$sectionName
        if (-not $section) { continue }

        foreach ($entryId in @($section.PSObject.Properties.Name)) {
            if ([string]::IsNullOrEmpty($entryId)) { continue }
            foreach ($field in @($section.$entryId.PSObject.Properties.Name)) {
                if ([string]::IsNullOrEmpty($field)) { continue }
                $paths.Add("$sectionName.$entryId.$field")
            }
        }
    }

    foreach ($groupId in @($Lang.UiGroups.PSObject.Properties.Name)) {
        if ([string]::IsNullOrEmpty($groupId)) { continue }
        $group = $Lang.UiGroups.$groupId
        foreach ($field in @($group.PSObject.Properties.Name)) {
            if ([string]::IsNullOrEmpty($field)) { continue }
            if ($field -eq 'Values') {
                foreach ($featureId in @($group.Values.PSObject.Properties.Name)) {
                    if ([string]::IsNullOrEmpty($featureId)) { continue }
                    $paths.Add("UiGroups.$groupId.Values.$featureId")
                }
                continue
            }
            $paths.Add("UiGroups.$groupId.$field")
        }
    }

    return @($paths | Sort-Object -Unique)
}

<#
    .SYNOPSIS
        Diffs a language's key set against a baseline language, reporting missing and extra keys.

    .DESCRIPTION
        Loads both languages fresh from disk (independent of any already-cached $script:Lang),
        flattens each with Get-LanguageKeyPaths, and compares the two sets. Intended to run
        against en-US as the baseline; useful today (catches a key present in one en-US file but
        not another) and becomes the real translation-completeness check once non-English
        language folders are contributed.

    .OUTPUTS
        PSCustomObject with ResolvedLanguageCode (the folder actually compared, after the same
        exact/prefix/en-US resolution Import-LanguageFile applies), MissingKeys (present in
        Baseline, absent from LanguageCode), and ExtraKeys (present in LanguageCode, absent from
        Baseline) properties, the latter two sorted arrays.
#>
function Test-LanguageKeyCoverage {
    param(
        [Parameter(Mandatory)]
        [string]$LanguageCode,
        [string]$BaselineLanguageCode = 'en-US',
        [string]$LanguagesPath = $script:LanguagesPath
    )

    $resolvedLanguageCode = Resolve-LanguageFolder -LanguageCode $LanguageCode -LanguagesPath $LanguagesPath
    $baseline = Import-LanguageContent -LanguageFolder $BaselineLanguageCode -LanguagesPath $LanguagesPath
    $target = Import-LanguageContent -LanguageFolder $resolvedLanguageCode -LanguagesPath $LanguagesPath

    if (-not $baseline -or -not $target) {
        Write-Error "Unable to load language content for coverage comparison ('$BaselineLanguageCode' vs '$resolvedLanguageCode')."
        return $null
    }

    $baselineKeys = [System.Collections.Generic.HashSet[string]]::new([string[]](Get-LanguageKeyPaths -Lang $baseline))
    $targetKeys = [System.Collections.Generic.HashSet[string]]::new([string[]](Get-LanguageKeyPaths -Lang $target))

    $missingKeys = @($baselineKeys | Where-Object { -not $targetKeys.Contains($_) } | Sort-Object)
    $extraKeys = @($targetKeys | Where-Object { -not $baselineKeys.Contains($_) } | Sort-Object)

    return [PSCustomObject]@{
        ResolvedLanguageCode = $resolvedLanguageCode
        MissingKeys          = $missingKeys
        ExtraKeys            = $extraKeys
    }
}

<#
    .SYNOPSIS
        Substitutes %LANG:Key% markers in XAML text with translated, XML-escaped values.

    .DESCRIPTION
        Only resolves flat Chrome.json keys, since XAML markers never reference a Feature/Category/
        UiGroup field directly (those get their text from Get-Translation calls in the GUI scripts
        that build dynamic controls). Runs a single pass over every marker rather than sequential
        .Replace() calls, so an already-substituted value can't be re-matched by a later key.

        After substitution, scans for any %LANG:...% text that survived unresolved and throws,
        since Get-Translation's key-as-fallback behavior means a missing key would otherwise render
        as plain, un-marked text (e.g. "TitleBarClose" instead of a visible error) rather than being
        caught here. Checks both the active language and its Fallback before flagging a key missing,
        so a partially-translated language degrades to en-US text instead of failing to load.
#>
function ConvertTo-LocalizedXaml {
    param(
        [Parameter(Mandatory)]
        [string]$Xaml,
        [object]$Lang = $script:Lang
    )

    $missingKeys = New-Object System.Collections.Generic.List[string]

    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $key = $match.Groups[1].Value
        $resolvesSomewhere = @(Get-LanguageFallbackChain -Lang $Lang) | Where-Object { $_.Chrome -and $_.Chrome.PSObject.Properties[$key] }
        if (-not $resolvesSomewhere) { $missingKeys.Add($key) }
        $value = if ($resolvesSomewhere) { Get-Translation -Key $key -Lang $Lang } else { $key }
        return [System.Security.SecurityElement]::Escape($value)
    }

    $result = [System.Text.RegularExpressions.Regex]::Replace($Xaml, '%LANG:([A-Za-z0-9_]+)%', $evaluator)

    if ($missingKeys.Count -gt 0) {
        throw "Unresolved localization marker(s) in XAML, key(s) not found in any language: $($missingKeys -join ', ')"
    }

    return $result
}
