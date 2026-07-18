BeforeAll {
    function Show-MessageBox { param($Message, $Title, $Button, $Icon, $Owner) 'Yes' }
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\ConfirmUnsafeAppRemoval.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\GetTargetUserForAppRemoval.ps1')
}

Describe 'ConfirmUnsafeAppRemoval' {
    BeforeEach {
        $global:Silent = $false
        Mock Show-MessageBox { 'Yes' }
    }

    AfterEach { Remove-Variable -Name Silent -Scope Global -ErrorAction SilentlyContinue }

    It 'returns true without prompting for ordinary applications' {
        ConfirmUnsafeAppRemoval -SelectedApps @('Contoso.App') | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 0 -Exactly
    }

    It 'skips all prompts in silent mode' {
        $global:Silent = $true

        ConfirmUnsafeAppRemoval -SelectedApps @('Microsoft.WindowsStore', 'Microsoft.WindowsTerminal') | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 0 -Exactly
    }

    It 'stops when Microsoft Store removal is declined' {
        Mock Show-MessageBox { 'No' }

        ConfirmUnsafeAppRemoval -SelectedApps @('Microsoft.WindowsStore', 'Microsoft.WindowsTerminal') | Should -BeFalse
        Should -Invoke Show-MessageBox -Times 1 -Exactly
    }

    It 'requires confirmation for both dangerous applications' {
        ConfirmUnsafeAppRemoval -SelectedApps @('Microsoft.WindowsStore', 'Microsoft.WindowsTerminal') | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 2 -Exactly
    }
}

Describe 'GetTargetUserForAppRemoval' {
    It '<Case>' -ForEach @(
        @{ Case = 'defaults to all users'; Params = @{}; Expected = 'AllUsers' }
        @{ Case = 'returns an explicit target unchanged'; Params = @{ AppRemovalTarget = 'Alice' }; Expected = 'Alice' }
    ) {
        $script:Params = $Params
        GetTargetUserForAppRemoval | Should -Be $Expected
    }
}
