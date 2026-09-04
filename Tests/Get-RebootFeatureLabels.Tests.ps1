BeforeAll {
    $rebootFeatureLabelsScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RebootFeatureLabels.ps1'
    . $rebootFeatureLabelsScriptPath
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')

    # Builds a $script:Lang fixture whose Features section mirrors $script:Features exactly,
    # so Get-Translation resolves the same Label/UndoLabel text the test's fake FeatureIds expect.
    function Sync-TestLangFeatures {
        $langFeatures = @{}
        foreach ($featureId in $script:Features.Keys) {
            $feature = $script:Features[$featureId]
            $entry = @{}
            foreach ($field in 'Label', 'UndoLabel') {
                if ($null -ne $feature.$field) { $entry[$field] = [string]$feature.$field }
            }
            $langFeatures[$featureId] = [PSCustomObject]$entry
        }

        $script:Lang = [PSCustomObject]@{
            LanguageCode = 'en-US'
            Chrome       = [PSCustomObject]@{}
            Features     = [PSCustomObject]$langFeatures
            UiGroups     = [PSCustomObject]@{}
            Categories   = [PSCustomObject]@{}
        }
    }
}

Describe 'Get-RebootFeatureLabels' {
    BeforeEach {
        $script:Params = @{
            ApplyFeature = $true
            NoRebootFeature = $true
        }
        $script:UndoParams = @{
            UndoFeature = $true
            ApplyFeature = $true
        }
        $script:Features = @{
            ApplyFeature = [PSCustomObject]@{ RequiresReboot = $true; Label = 'Apply feature'; UndoLabel = 'Undo apply feature' }
            UndoFeature = [PSCustomObject]@{ RequiresReboot = $true; Label = 'Undoable feature'; UndoLabel = 'Undo feature' }
            NoRebootFeature = [PSCustomObject]@{ RequiresReboot = $false; Label = 'No reboot'; UndoLabel = 'Undo no reboot' }
        }
        Sync-TestLangFeatures
    }

    It 'includes reboot-required selections once and uses undo labels for undo operations' {
        $result = @(Get-RebootFeatureLabels)

        $result | Should -HaveCount 2
        $result | Should -Contain 'Undo apply feature'
        $result | Should -Contain 'Undo feature'
        $result | Should -Not -Contain 'No reboot'
    }

    It 'uses the regular label for a forward-only selection' {
        $script:Params = @{ ApplyFeature = $true }
        $script:UndoParams = @{}

        $result = @(Get-RebootFeatureLabels)

        $result | Should -HaveCount 1
        $result | Should -Contain 'Apply feature'
    }

    It 'falls back to the regular label when an undo selection has no undo label' {
        $script:Params = @{}
        $script:UndoParams = @{ ApplyFeature = $true }
        $script:Features.ApplyFeature.UndoLabel = $null
        Sync-TestLangFeatures

        $result = @(Get-RebootFeatureLabels)

        $result | Should -HaveCount 1
        $result | Should -Contain 'Apply feature'
    }

    It 'falls back to the regular label when the feature has no UndoLabel property' {
        $script:Params = @{}
        $script:UndoParams = @{ MissingUndoLabelFeature = $true }
        $script:Features.MissingUndoLabelFeature = [PSCustomObject]@{
            RequiresReboot = $true
            Label = 'Feature without undo label'
        }
        Sync-TestLangFeatures

        $result = @(Get-RebootFeatureLabels)

        $result | Should -HaveCount 1
        $result | Should -Contain 'Feature without undo label'
    }

    It 'returns no labels when there are no selected parameters' {
        $script:Params = @{}
        $script:UndoParams = @{}

        @(Get-RebootFeatureLabels).Count | Should -Be 0
    }

    It 'keeps one label for each distinct reboot feature when their labels match' {
        $script:Params = @{
            FirstMatchingLabelFeature = $true
            SecondMatchingLabelFeature = $true
        }
        $script:UndoParams = @{}
        $script:Features.FirstMatchingLabelFeature = [PSCustomObject]@{
            RequiresReboot = $true
            Label = 'Shared label'
            UndoLabel = 'Undo first shared label'
        }
        $script:Features.SecondMatchingLabelFeature = [PSCustomObject]@{
            RequiresReboot = $true
            Label = 'Shared label'
            UndoLabel = 'Undo second shared label'
        }
        Sync-TestLangFeatures

        $result = @(Get-RebootFeatureLabels)

        $result | Should -HaveCount 2
        @($result | Where-Object { $_ -eq 'Shared label' }).Count | Should -Be 2
    }

    It 'accepts truthy reboot flags' {
        $script:Params = @{
            StringRebootFeature = $true
            NumericRebootFeature = $true
        }
        $script:UndoParams = @{}
        $script:Features.StringRebootFeature = [PSCustomObject]@{
            RequiresReboot = 'true'
            Label = 'String reboot'
            UndoLabel = 'Undo string reboot'
        }
        $script:Features.NumericRebootFeature = [PSCustomObject]@{
            RequiresReboot = 1
            Label = 'Numeric reboot'
            UndoLabel = 'Undo numeric reboot'
        }
        Sync-TestLangFeatures

        $result = @(Get-RebootFeatureLabels)

        $result | Should -HaveCount 2
        $result | Should -Contain 'String reboot'
        $result | Should -Contain 'Numeric reboot'
    }

    It 'excludes unknown, non-reboot, and blank-label selections' {
        $script:Params = @{
            UnknownFeature = $true
            NoRebootFeature = $true
            BlankLabelFeature = $true
        }
        $script:UndoParams = @{}
        $script:Features.BlankLabelFeature = [PSCustomObject]@{
            RequiresReboot = $true
            Label = ' '
            UndoLabel = $null
        }
        Sync-TestLangFeatures

        @(Get-RebootFeatureLabels).Count | Should -Be 0
    }
}
