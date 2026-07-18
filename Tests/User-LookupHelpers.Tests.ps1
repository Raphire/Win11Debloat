BeforeAll {
    $userProfileScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\Resolve-UserProfilePath.ps1'
    . $userProfileScriptPath
}

Describe 'Normalize-UserLookupValue' {
    It 'removes zero-width characters and collapses whitespace' {
        Normalize-UserLookupValue -Value "  domain\u$([char]0x200B)ser   name  " | Should -Be 'domain\user name'
    }

    It 'uses normalized, case-insensitive cache keys' {
        Get-UserLookupCacheKey -Value '  DOMAIN\Alice  ' | Should -Be 'domain\alice'
        Get-UserLookupCacheKey -Value ' ' | Should -Be ''
    }

    It 'normalizes, filters, and de-duplicates lookup candidates' {
        $result = Get-NormalizedLookupCandidates -Candidates @(' Alice ', '', 'alice', "Bob$([char]0x200B)")

        $result | Should -HaveCount 3
        $result[0] | Should -Be 'Alice'
        $result[1] | Should -Be 'alice'
        $result[2] | Should -Be 'Bob'
    }

    It 'escapes WQL literals and extracts local user-name segments' {
        Escape-WqlString -Value "O'Brian" | Should -Be "O''Brian"
        Get-LocalUserNameSegment -UserName 'CONTOSO\Alice' | Should -Be 'Alice'
        Get-LocalUserNameSegment -UserName 'alice@contoso.com' | Should -Be 'alice'
        Get-LocalUserNameSegment -UserName '  Alice  ' | Should -Be 'Alice'
    }
}
