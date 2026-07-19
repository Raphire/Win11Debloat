BeforeAll {
    function Show-MessageBox { param($Message, $Title, $Button, $Icon, $Owner) 'Yes' }
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Confirm-UnsafeAppRemoval.ps1')
}

Describe 'Confirm-UnsafeAppRemoval' {
    BeforeEach {
        $global:Silent = $false
        Mock Show-MessageBox { 'Yes' }
    }

    AfterEach { Remove-Variable -Name Silent -Scope Global -ErrorAction SilentlyContinue }

    It 'returns true without prompting for ordinary applications' {
        Confirm-UnsafeAppRemoval -SelectedApps @('Contoso.App') | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 0 -Exactly
    }

    It 'skips all prompts in silent mode' {
        $global:Silent = $true

        Confirm-UnsafeAppRemoval -SelectedApps @('Microsoft.WindowsStore', 'Microsoft.WindowsTerminal') | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 0 -Exactly
    }

    It 'stops when Microsoft Store removal is declined' {
        Mock Show-MessageBox { 'No' }

        Confirm-UnsafeAppRemoval -SelectedApps @('Microsoft.WindowsStore', 'Microsoft.WindowsTerminal') | Should -BeFalse
        Should -Invoke Show-MessageBox -Times 1 -Exactly
    }

    It 'requires confirmation for both dangerous applications' {
        Confirm-UnsafeAppRemoval -SelectedApps @('Microsoft.WindowsStore', 'Microsoft.WindowsTerminal') | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 2 -Exactly
    }
}
