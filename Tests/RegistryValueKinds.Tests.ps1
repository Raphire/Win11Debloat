BeforeAll {
    $currentTweakStateScriptPath = Join-Path $PSScriptRoot '..\Scripts\Features\GetCurrentTweakState.ps1'
    . $currentTweakStateScriptPath
}

Describe 'Get-ExpectedRegistryValueKind' {
    It 'maps <ValueType> to <Expected>' -ForEach @(
        @{ ValueType = 'DWord'; Expected = [Microsoft.Win32.RegistryValueKind]::DWord }
        @{ ValueType = 'QWord'; Expected = [Microsoft.Win32.RegistryValueKind]::QWord }
        @{ ValueType = 'String'; Expected = [Microsoft.Win32.RegistryValueKind]::String }
        @{ ValueType = 'Binary'; Expected = [Microsoft.Win32.RegistryValueKind]::Binary }
        @{ ValueType = 'Hex2'; Expected = [Microsoft.Win32.RegistryValueKind]::ExpandString }
        @{ ValueType = 'Hex7'; Expected = [Microsoft.Win32.RegistryValueKind]::MultiString }
    ) {
        $operation = [PSCustomObject]@{ ValueType = $ValueType }

        Get-ExpectedRegistryValueKind -Operation $operation | Should -Be $Expected
    }

    It 'returns null for unsupported operation types' {
        Get-ExpectedRegistryValueKind -Operation ([PSCustomObject]@{ ValueType = 'Hex11' }) | Should -BeNullOrEmpty
    }
}
