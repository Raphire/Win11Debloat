<#
    .SYNOPSIS
    Applies light or dark theme colors to a WPF window's resource dictionary.

    .DESCRIPTION
    Iterates over a predefined set of theme color categories and
    populates the window's Resources with SolidColorBrush entries keyed by
    category and resource name (e.g. "AppAccentColor"). Additionally loads and
    merges shared XAML styles from the script's SharedStylesSchema path if
    available. Also resolves the icon font: Segoe Fluent Icons on Windows 11
    and Segoe MDL2 Assets on Windows 10.

    .PARAMETER window
    The WPF Window whose resource dictionary will be populated.

    .PARAMETER usesDarkMode
    When $true, dark theme colors are applied; when $false, light theme colors.

    .EXAMPLE
    SetWindowThemeResources -window $MainWindow -usesDarkMode $true

    .EXAMPLE
    SetWindowThemeResources -window $Dialog -usesDarkMode $false
#>
# Sets resource colors for a WPF window based on dark mode preference
function SetWindowThemeResources {
    param (
        $window,
        [bool]$usesDarkMode
    )

    $ThemeColor = @{
        App = @{
            AccentColor = @{ Light = '#ffae00'; Dark = '#ffd700' }
            BorderColor = @{ Light = '#ededed'; Dark = '#404040' }
            BgColor     = @{ Light = '#f3f3f3'; Dark = '#202020' }
            FgColor     = @{ Light = '#000000'; Dark = '#ffffff' }
            IdColor     = @{ Light = '#666666'; Dark = '#afafaf' }
        }

        Card = @{
            BgColor = @{ Light = '#fbfbfb'; Dark = '#2b2b2b' }
        }

        Button = @{
            BorderColor       = @{ Light = '#d3d3d3'; Dark = '#404040' }
            BgColor           = @{ Light = '#0067c0'; Dark = '#0067c0' }
            DisabledColor     = @{ Light = '#bfbfbf'; Dark = '#434343' }
            HoverColor        = @{ Light = '#1975c5'; Dark = '#1975c5' }
            PressedColor      = @{ Light = '#3183ca'; Dark = '#3183ca' }
            TextDisabledColor = @{ Light = '#ffffff'; Dark = '#989898' }
        }

        SecondaryButton = @{
            BgColor           = @{ Light = '#fbfbfb'; Dark = '#393939' }
            DisabledColor     = @{ Light = '#f7f7f7'; Dark = '#3b3b3b' }
            HoverColor        = @{ Light = '#f6f6f6'; Dark = '#2a2a2a' }
            PressedColor      = @{ Light = '#f0f0f0'; Dark = '#1e1e1e' }
            TextDisabledColor = @{ Light = '#b7b7b7'; Dark = '#787878' }
        }

        CheckBox = @{
            BgColor     = @{ Light = '#f5f5f5'; Dark = '#272727' }
            BorderColor = @{ Light = '#898989'; Dark = '#808080' }
            HoverColor  = @{ Light = '#ececec'; Dark = '#343434' }
        }

        ComboBox = @{
            BgColor           = @{ Light = '#ffffff'; Dark = '#373737' }
            HoverColor        = @{ Light = '#f8f8f8'; Dark = '#434343' }
            ItemBgColor       = @{ Light = '#f9f9f9'; Dark = '#2c2c2c' }
            ItemHoverColor    = @{ Light = '#f0f0f0'; Dark = '#383838' }
            ItemSelectedColor = @{ Light = '#f3f3f3'; Dark = '#343434' }
        }

        TextBox = @{
            BorderColor     = @{ Light = '#bdbdbd'; Dark = '#989a9d' }
            BgColor         = @{ Light = '#fbfbfb'; Dark = '#2d2d2d' }
            FocusColor      = @{ Light = '#ffffff'; Dark = '#1f1f1f' }
            HoverColor      = @{ Light = '#f6f6f6'; Dark = '#323232' }
            SideBorderColor = @{ Light = '#ececec'; Dark = '#343434' }
        }

        ScrollBar = @{
            ThumbColor      = @{ Light = '#b9b9b9'; Dark = '#3d3d3d' }
            ThumbHoverColor = @{ Light = '#8b8b8b'; Dark = '#4b4b4b' }
        }

        TitleBar = @{
            ButtonHoverColor   = @{ Light = '#dcdcdc'; Dark = '#353535' }
            ButtonPressedColor = @{ Light = '#cccccc'; Dark = '#333333' }
            CloseHoverColor    = @{ Light = '#e81123'; Dark = '#e81123' }
            ClosePressedColor  = @{ Light = '#f1707a'; Dark = '#f1707a' }
            UnfocusedFgColor   = @{ Light = '#868686'; Dark = '#969696' }
        }

        Search = @{
            HighlightActiveColor = @{ Light = '#ffd966'; Dark = '#8a7000' }
            HighlightColor       = @{ Light = '#fff4ce'; Dark = '#4a4a2a' }
        }

        Table = @{
            HeaderColor = @{ Light = '#ffffff'; Dark = '#303030' }
        }

        Icon = @{
            ErrorColor       = @{ Light = '#e81123'; Dark = '#e81123' }
            InformationColor = @{ Light = '#0078d4'; Dark = '#0078d4' }
            QuestionColor    = @{ Light = '#0078d4'; Dark = '#0078d4' }
            SuccessColor     = @{ Light = '#107c10'; Dark = '#107c10' }
            WarningColor     = @{ Light = '#ffb900'; Dark = '#ffb900' }
        }
    }

    $Theme = if ($usesDarkMode) { 'Dark' } else { 'Light' }

    foreach ($Group in $ThemeColor.GetEnumerator()) {
        foreach ($Resource in $Group.Value.GetEnumerator()) {
            $ResourceName = $Group.Key + $Resource.Key
            $window.Resources[$ResourceName] = [System.Windows.Media.SolidColorBrush]::new(
                [System.Windows.Media.ColorConverter]::ConvertFromString($Resource.Value[$Theme])
            )
        }
    }

    # Segoe Fluent Icons ships only on Windows 11 (build >= 22000). 
    # On Windows 10, fall back to Segoe MDL2 Assets.
    $winBuild = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
    $iconFontName = if ($winBuild -ge 22000) { 'Segoe Fluent Icons' } else { 'Segoe MDL2 Assets' }
    $window.Resources['AppIconFontFamily'] = [System.Windows.Media.FontFamily]::new($iconFontName)

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
}
