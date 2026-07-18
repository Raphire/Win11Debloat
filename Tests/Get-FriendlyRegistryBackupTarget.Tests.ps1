BeforeAll {
    $friendlyTargetScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-FriendlyRegistryBackupTarget.ps1'
    . $friendlyTargetScriptPath
}

Describe 'Get-FriendlyRegistryBackupTarget' {
    It 'formats <Case> as <Expected>' -ForEach @(
        @{ Case = 'a null target'; Target = $null; Expected = 'Unknown' }
        @{ Case = 'the default profile'; Target = 'DefaultUserProfile'; Expected = 'Default user profile' }
        @{ Case = 'the current-user marker'; Target = 'CurrentUser'; Expected = 'Current user' }
        @{ Case = 'the all-users marker'; Target = 'AllUsers'; Expected = 'All users' }
        @{ Case = 'a named current user'; Target = 'CurrentUser:Alice'; Expected = 'Current user (Alice)' }
        @{ Case = 'a named target user'; Target = 'User:Bob'; Expected = 'User (Bob)' }
    ) {
        Get-FriendlyRegistryBackupTarget -Target $Target | Should -Be $Expected
    }

    It 'keeps unrecognized target text visible to the user' {
        Get-FriendlyRegistryBackupTarget -Target 'Custom:Value' | Should -Be 'Custom:Value'
    }
}
