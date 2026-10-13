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

    It 'keeps every literal FindName reference backed by its receiver schema' {
        # Map receivers, not whole files: dialogs also look up controls on their owners.
        $receiverSchemas = @{
            'Show-MainWindow.ps1' = @{ window = 'MainWindow.xaml' }
            'MainWindow-AppSelection.ps1' = @{ window = 'MainWindow.xaml'; w = 'MainWindow.xaml' }
            'MainWindow-Deployment.ps1' = @{ window = 'MainWindow.xaml' }
            'MainWindow-Localization.ps1' = @{ window = 'MainWindow.xaml' }
            'MainWindow-Navigation.ps1' = @{ window = 'MainWindow.xaml' }
            'MainWindow-TweaksBuilder.ps1' = @{ window = 'MainWindow.xaml' }
            'Show-AboutDialog.ps1' = @{ aboutWindow = 'AboutWindow.xaml'; ownerWindow = 'MainWindow.xaml' }
            'Show-AppSelectionWindow.ps1' = @{ window = 'AppSelectionWindow.xaml'; 'script:GuiWindow' = 'MainWindow.xaml' }
            'Show-ApplyModal.ps1' = @{ applyWindow = 'ApplyChangesWindow.xaml'; ownerWindow = 'MainWindow.xaml' }
            'Show-SettingsDialog.ps1' = @{ dialog = 'SettingsWindow.xaml'; Owner = 'MainWindow.xaml' }
            'Show-MessageBox.ps1' = @{
                msgWindow = 'MessageBox.xaml'
                ownerWindow = @('MainWindow.xaml', 'AppSelectionWindow.xaml', 'RestoreBackupWindow.xaml')
            }
            'Show-ImportExportConfigWindow.ps1' = @{ dlg = 'ImportExportConfigWindow.xaml'; owner = 'MainWindow.xaml' }
            'Show-RestoreBackupDialog.ps1' = @{ window = 'RestoreBackupWindow.xaml'; ownerWindow = 'MainWindow.xaml' }
            'Show-Bubble.ps1' = @{ bubblePanel = 'BubbleHint.xaml' }
        }
        $schemaNames = @{}
        foreach ($xamlFile in $script:XamlFiles) {
            $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            [xml]$xml = Get-Content -LiteralPath $xamlFile.FullName -Raw
            $namespaces = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
            $namespaces.AddNamespace('p', 'http://schemas.microsoft.com/winfx/2006/xaml/presentation')
            # Template children belong to separate namescopes and cannot satisfy window lookups.
            $attributes = $xml.SelectNodes(
                '//@*[not(ancestor::p:ControlTemplate or ancestor::p:DataTemplate or ancestor::p:ItemsPanelTemplate)]',
                $namespaces)
            foreach ($attribute in $attributes) {
                if ($attribute.LocalName -eq 'Name' -and
                    $attribute.NamespaceURI -in @('', 'http://schemas.microsoft.com/winfx/2006/xaml')) {
                    [void]$names.Add($attribute.Value)
                }
            }
            $schemaNames[$xamlFile.Name] = $names
        }

        $failures = @()
        foreach ($guiFile in Get-ChildItem -LiteralPath $script:GuiPath -Filter '*.ps1' -File -Recurse) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $guiFile.FullName, [ref]$tokens, [ref]$parseErrors)
            $parseErrors | Should -BeNullOrEmpty
            $calls = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $node.Member.Value -eq 'FindName' -and $node.Arguments.Count -eq 1 -and
                $node.Arguments[0] -is [System.Management.Automation.Language.StringConstantExpressionAst]
            }, $true)
            foreach ($call in $calls) {
                $name = $call.Arguments[0].Value
                $receiver = $call.Expression.Extent.Text
                $location = '{0}:{1} {2}.FindName({3})' -f
                    $guiFile.Name, $call.Extent.StartLineNumber, $receiver, $name
                if ($call.Expression -isnot [System.Management.Automation.Language.VariableExpressionAst]) {
                    $failures += "$location has no receiver mapping"
                    continue
                }
                $receiver = $call.Expression.VariablePath.UserPath
                $mapping = $receiverSchemas[$guiFile.Name]
                $schemas = if ($mapping) { $mapping[$receiver] } else { $null }
                if (-not $schemas) {
                    $failures += "$location has no receiver mapping"
                    continue
                }
                foreach ($schema in @($schemas)) {
                    if (-not $schemaNames.ContainsKey($schema)) {
                        $failures += "$location maps to missing schema '$schema'"
                    }
                    elseif (-not $schemaNames[$schema].Contains($name)) {
                        # Only the restore dialog owner may omit the message box overlay.
                        if ($guiFile.Name -eq 'Show-MessageBox.ps1' -and $receiver -eq 'ownerWindow' -and
                            $schema -eq 'RestoreBackupWindow.xaml' -and $name -ceq 'ModalOverlay') {
                            continue
                        }
                        $failures += "$location is missing from '$schema'"
                    }
                }
            }
        }

        $failures | Should -BeNullOrEmpty
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
