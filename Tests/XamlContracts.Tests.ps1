Describe 'XAML UI contracts' {
    BeforeAll {
        $script:SchemaPath = Join-Path $PSScriptRoot '..\Schemas'
        $script:GuiPath = Join-Path $PSScriptRoot '..\Scripts\GUI'
        $script:XamlFiles = @(Get-ChildItem -LiteralPath $script:SchemaPath -Filter '*.xaml' -File)
    }

    It 'keeps every schema well-formed XML' {
        foreach ($xamlFile in $script:XamlFiles) {
            { [xml](Get-Content -LiteralPath $xamlFile.FullName -Raw) } |
                Should -Not -Throw "XAML schema '$($xamlFile.Name)' must remain well-formed."
        }
    }

    It 'keeps every literal FindName reference backed by an XAML control' {
        $xamlNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($xamlFile in $script:XamlFiles) {
            $content = Get-Content -LiteralPath $xamlFile.FullName -Raw
            foreach ($match in [regex]::Matches($content, '(?:x:Name|\bName)\s*=\s*"([^"]+)"')) {
                [void]$xamlNames.Add($match.Groups[1].Value)
            }
        }

        $references = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($guiFile in Get-ChildItem -LiteralPath $script:GuiPath -Filter '*.ps1' -File -Recurse) {
            $content = Get-Content -LiteralPath $guiFile.FullName -Raw
            foreach ($match in [regex]::Matches($content, "\.FindName\(\s*'([^']+)'\s*\)")) {
                [void]$references.Add($match.Groups[1].Value)
            }
        }

        $missing = @($references | Where-Object { -not $xamlNames.Contains($_) } | Sort-Object)
        $missing | Should -BeNullOrEmpty
    }

    It 'keeps the main window navigation and deployment controls available' {
        $mainWindow = Get-Content -LiteralPath (Join-Path $script:SchemaPath 'MainWindow.xaml') -Raw
        $requiredNames = @(
            'MainTabControl'
            'HomeTab'
            'DeploymentSettingsTab'
            'DeploymentApplyBtn'
            'UserSelectionCombo'
            'AppSelectionPanel'
            'AppSelectionStatus'
        )

        foreach ($name in $requiredNames) {
            $mainWindow | Should -Match ('(?:x:Name|\bName)\s*=\s*"{0}"' -f [regex]::Escape($name))
        }
    }

    It 'exposes <Schema> links as keyboard-accessible hyperlinks with automation names' -TestCases @(
        @{ Schema = 'AboutWindow.xaml'; LinkNames = @('ProjectLink', 'KofiLink') }
        @{ Schema = 'RestoreBackupWindow.xaml'; LinkNames = @('NonRevertibleWikiLink') }
    ) {
        param($Schema, $LinkNames)

        Add-Type -AssemblyName PresentationFramework
        $styles = [System.Windows.Markup.XamlReader]::Parse(
            (Get-Content -LiteralPath (Join-Path $script:SchemaPath 'SharedStyles.xaml') -Raw))
        $window = [System.Windows.Markup.XamlReader]::Parse(
            (Get-Content -LiteralPath (Join-Path $script:SchemaPath $Schema) -Raw))
        try {
            $window.Resources.MergedDictionaries.Add($styles)
            foreach ($name in $LinkNames) {
                $link = $window.FindName($name)
                $link | Should -BeOfType ([System.Windows.Documents.Hyperlink])
                $link.Focusable | Should -BeTrue
                [System.Windows.Input.KeyboardNavigation]::GetIsTabStop($link) | Should -BeTrue
                $peer = [System.Windows.Automation.Peers.HyperlinkAutomationPeer]::new($link)
                $peer.GetAutomationControlType() | Should -Be ([System.Windows.Automation.Peers.AutomationControlType]::Hyperlink)
                $peer.GetName() | Should -Not -BeNullOrEmpty
                $peer.GetPattern([System.Windows.Automation.Peers.PatternInterface]::Invoke) | Should -Not -BeNullOrEmpty
            }
            if ($Schema -eq 'AboutWindow.xaml') {
                [System.Windows.Automation.AutomationProperties]::GetName($window.FindName('CloseButton')) |
                    Should -Be '%LANG:TitleBarClose%'
            }
        }
        finally {
            $window.Close()
        }
    }

    It 'keeps read-only restore feature lists out of keyboard focus' {
        Add-Type -AssemblyName PresentationFramework
        $window = [System.Windows.Markup.XamlReader]::Parse(
            (Get-Content -LiteralPath (Join-Path $script:SchemaPath 'RestoreBackupWindow.xaml') -Raw))
        try {
            foreach ($name in @('FeaturesItemsControl', 'ReappliedFeaturesItemsControl', 'NonRevertibleFeaturesItemsControl')) {
                $list = $window.FindName($name)
                $list.Focusable | Should -BeFalse
                $list.IsTabStop | Should -BeFalse
            }
        }
        finally {
            $window.Close()
        }
    }

    It 'keeps destructive modal actions accessible by automation name' {
        $applyWindow = Get-Content -LiteralPath (Join-Path $script:SchemaPath 'ApplyChangesWindow.xaml') -Raw
        $appWindow = Get-Content -LiteralPath (Join-Path $script:SchemaPath 'AppSelectionWindow.xaml') -Raw

        $applyWindow | Should -Match 'AutomationProperties.Name="%LANG:ApplyCancelTooltip%"'
        $applyWindow | Should -Match 'AutomationProperties.Name="%LANG:TitleBarClose%"'
        $appWindow | Should -Match 'AutomationProperties.Name="%LANG:AppSelectionWindowConfirm%"'
        $appWindow | Should -Match 'AutomationProperties.Name="%LANG:AppSelectionWindowCancel%"'
    }
}
