# Sets resource colors for a WPF window based on dark mode preference
function GetIconFontFamilyName {
    if ($script:IconFontFamilyName) {
        return $script:IconFontFamilyName
    }

    $preferredFont = 'Segoe Fluent Icons'
    $fallbackFont = 'Segoe MDL2 Assets'

    try {
        $systemFonts = [System.Windows.Media.Fonts]::SystemFontFamilies | ForEach-Object { $_.Source }

        if ($systemFonts -contains $preferredFont) {
            $script:IconFontFamilyName = $preferredFont
        }
        elseif ($systemFonts -contains $fallbackFont) {
            $script:IconFontFamilyName = $fallbackFont
        }
        else {
            # Last resort fallback if the expected symbol fonts are unavailable.
            $script:IconFontFamilyName = 'Segoe UI Symbol'
        }
    }
    catch {
        $script:IconFontFamilyName = $fallbackFont
    }

    return $script:IconFontFamilyName
}

function SetIconFontFallback {
    param($window)

    if (-not $window) {
        return
    }

    $targetFontName = GetIconFontFamilyName
    if ($targetFontName -eq 'Segoe Fluent Icons') {
        return
    }

    $targetFontFamily = [System.Windows.Media.FontFamily]::new($targetFontName)
    $queue = [System.Collections.Queue]::new()
    $queue.Enqueue($window)

    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()

        if ($node -is [System.Windows.Controls.TextBlock]) {
            if ($node.FontFamily -and $node.FontFamily.Source -eq 'Segoe Fluent Icons') {
                $node.FontFamily = $targetFontFamily
            }
        }
        elseif ($node -is [System.Windows.Controls.Control]) {
            if ($node.FontFamily -and $node.FontFamily.Source -eq 'Segoe Fluent Icons') {
                $node.FontFamily = $targetFontFamily
            }
        }

        foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($node)) {
            if ($child -is [System.Windows.DependencyObject]) {
                $queue.Enqueue($child)
            }
        }
    }
}

function SetWindowThemeResources {
    param (
        $window,
        [bool]$usesDarkMode
    )

    if ($usesDarkMode) {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#202020")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("CardBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2b2b2b")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#404040")))
        $window.Resources.Add("ButtonBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#404040")))
        $window.Resources.Add("CheckBoxBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#272727")))
        $window.Resources.Add("CheckBoxBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#808080")))
        $window.Resources.Add("CheckBoxHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#343434")))
        $window.Resources.Add("ComboBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#373737")))
        $window.Resources.Add("ComboHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#434343")))
        $window.Resources.Add("ComboItemBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2c2c2c")))
        $window.Resources.Add("ComboItemHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#383838")))
        $window.Resources.Add("ComboItemSelectedColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#343434")))
        $window.Resources.Add("AccentColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFD700")))
        $window.Resources.Add("ButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#434343")))
        $window.Resources.Add("ButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#989898")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#393939")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2a2a2a")))
        $window.Resources.Add("SecondaryButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1e1e1e")))
        $window.Resources.Add("SecondaryButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3b3b3b")))
        $window.Resources.Add("SecondaryButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#787878")))
        $window.Resources.Add("InputFocusColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1f1f1f")))
        $window.Resources.Add("ScrollBarThumbColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3d3d3d")))
        $window.Resources.Add("ScrollBarThumbHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#4b4b4b")))
        $window.Resources.Add("TitlebarButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2d2d2d")))
        $window.Resources.Add("TitlebarButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#292929")))
        $window.Resources.Add("AppIdColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#afafaf")))
        $window.Resources.Add("SearchHighlightColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A2A")))
        $window.Resources.Add("SearchHighlightActiveColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#8A7000")))
        $window.Resources.Add("TableHeaderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#333333")))
    }
    else {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f3f3f3")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#000000")))
        $window.Resources.Add("CardBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fbfbfb")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ededed")))
        $window.Resources.Add("ButtonBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#d3d3d3")))
        $window.Resources.Add("CheckBoxBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f5f5f5")))
        $window.Resources.Add("CheckBoxBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#898989")))
        $window.Resources.Add("CheckBoxHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ececec")))
        $window.Resources.Add("ComboBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("ComboHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f8f8f8")))
        $window.Resources.Add("ComboItemBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f9f9f9")))
        $window.Resources.Add("ComboItemHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f0f0f0")))
        $window.Resources.Add("ComboItemSelectedColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f3f3f3")))
        $window.Resources.Add("AccentColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ffae00")))
        $window.Resources.Add("ButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#bfbfbf")))
        $window.Resources.Add("ButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ffffff")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fbfbfb")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f6f6f6")))
        $window.Resources.Add("SecondaryButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f0f0f0")))
        $window.Resources.Add("SecondaryButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f7f7f7")))
        $window.Resources.Add("SecondaryButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#b7b7b7")))
        $window.Resources.Add("InputFocusColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fbfbfb")))
        $window.Resources.Add("ScrollBarThumbColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#b9b9b9")))
        $window.Resources.Add("ScrollBarThumbHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#8b8b8b")))
        $window.Resources.Add("TitlebarButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#e1e1e1")))
        $window.Resources.Add("TitlebarButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#e6e6e6")))
        $window.Resources.Add("AppIdColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#666666")))
        $window.Resources.Add("SearchHighlightColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFF4CE")))
        $window.Resources.Add("SearchHighlightActiveColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFD966")))
        $window.Resources.Add("TableHeaderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ffffff")))
    }

    $window.Resources.Add("ButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#0067c0")))
    $window.Resources.Add("ButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1E88E5")))
    $window.Resources.Add("ButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3284cc")))
    $window.Resources.Add("CloseHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c")))
    $window.Resources.Add("InformationIconColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#0078D4")))
    $window.Resources.Add("SuccessIconColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#107C10")))
    $window.Resources.Add("WarningIconColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFB900")))
    $window.Resources.Add("ErrorIconColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#E81123")))
    $window.Resources.Add("QuestionIconColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#0078D4")))

    # Load and merge shared styles
    if ($script:SharedStylesSchema -and (Test-Path $script:SharedStylesSchema)) {
        $sharedXaml = Get-Content -Path $script:SharedStylesSchema -Raw
        $sharedReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($sharedXaml))
        try {
            $sharedDict = [System.Windows.Markup.XamlReader]::Load($sharedReader)
            $window.Resources.MergedDictionaries.Add($sharedDict)
        }
        finally {
            $sharedReader.Close()
        }
    }

    SetIconFontFallback -window $window
}
