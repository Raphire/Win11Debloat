BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-TargetUserForAppRemoval.ps1')
}

Describe 'Get-TargetUserForAppRemoval' {
    It '<Case>' -ForEach @(
        @{ Case = 'defaults to all users'; Params = @{}; Expected = 'AllUsers' }
        @{ Case = 'returns an explicit target unchanged'; Params = @{ AppRemovalTarget = 'Alice' }; Expected = 'Alice' }
    ) {
        $script:Params = $Params
        Get-TargetUserForAppRemoval | Should -Be $Expected
    }
}
