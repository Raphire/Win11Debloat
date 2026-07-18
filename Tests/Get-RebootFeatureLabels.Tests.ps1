BeforeAll {
    $rebootFeatureLabelsScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RebootFeatureLabels.ps1'
    . $rebootFeatureLabelsScriptPath
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
    }

    It 'includes reboot-required selections once and uses undo labels for undo operations' {
        $result = @(Get-RebootFeatureLabels)

        $result | Should -HaveCount 2
        $result | Should -Contain 'Undo apply feature'
        $result | Should -Contain 'Undo feature'
        $result | Should -Not -Contain 'No reboot'
    }
}
