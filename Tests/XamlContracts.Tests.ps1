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

    It 'keeps destructive modal actions accessible by automation name' {
        $applyWindow = Get-Content -LiteralPath (Join-Path $script:SchemaPath 'ApplyChangesWindow.xaml') -Raw
        $appWindow = Get-Content -LiteralPath (Join-Path $script:SchemaPath 'AppSelectionWindow.xaml') -Raw

        $applyWindow | Should -Match 'AutomationProperties.Name="Cancel"'
        $applyWindow | Should -Match 'AutomationProperties.Name="Close"'
        $appWindow | Should -Match 'AutomationProperties.Name="Confirm"'
        $appWindow | Should -Match 'AutomationProperties.Name="Cancel"'
    }
}
