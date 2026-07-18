BeforeAll {
    $userProfileScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\ResolveUserProfilePath.ps1'
    . $userProfileScriptPath
}

Describe 'user lookup normalization helpers' {
    It 'removes zero-width characters and collapses whitespace' {
        NormalizeUserLookupValue -Value "  domain\u$([char]0x200B)ser   name  " | Should -Be 'domain\user name'
    }

    It 'uses normalized, case-insensitive cache keys' {
        GetUserLookupCacheKey -Value '  DOMAIN\Alice  ' | Should -Be 'domain\alice'
        GetUserLookupCacheKey -Value ' ' | Should -Be ''
    }

    It 'normalizes, filters, and de-duplicates lookup candidates' {
        $result = GetNormalizedLookupCandidates -Candidates @(' Alice ', '', 'alice', "Bob$([char]0x200B)")

        $result | Should -HaveCount 3
        $result[0] | Should -Be 'Alice'
        $result[1] | Should -Be 'alice'
        $result[2] | Should -Be 'Bob'
    }

    It 'escapes WQL literals and extracts local user-name segments' {
        EscapeWqlString -Value "O'Brian" | Should -Be "O''Brian"
        GetLocalUserNameSegment -UserName 'CONTOSO\Alice' | Should -Be 'Alice'
        GetLocalUserNameSegment -UserName 'alice@contoso.com' | Should -Be 'alice'
        GetLocalUserNameSegment -UserName '  Alice  ' | Should -Be 'Alice'
    }
}
