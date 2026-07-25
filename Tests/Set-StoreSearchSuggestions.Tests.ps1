BeforeAll {
    function Get-UserDirectory { param($userName, $fileName) }
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) }
    function takeown { param([Parameter(ValueFromRemainingArguments)]$Arguments) }
    function icacls { param([Parameter(ValueFromRemainingArguments)]$Arguments) }
    function New-TestStoreDatabaseAcl {
        param([object[]]$Access = @())

        $acl = [PSCustomObject]@{
            Access = $Access
            AddedRules = [System.Collections.Generic.List[object]]::new()
            RemovedRules = [System.Collections.Generic.List[object]]::new()
        }
        $acl | Add-Member -MemberType ScriptMethod -Name SetAccessRule -Value {
            param($Rule)
            $this.AddedRules.Add($Rule)
        }
        $acl | Add-Member -MemberType ScriptMethod -Name RemoveAccessRuleSpecific -Value {
            param($Rule)
            $this.RemovedRules.Add($Rule)
            return $true
        }
        return $acl
    }

    . (Join-Path $PSScriptRoot '..\Scripts\Features\Set-StoreSearchSuggestions.ps1')
}

Describe 'Store-search suggestion all-user operations' {
    BeforeEach {
        $script:Params = @{}
        Mock Get-UserDirectory { 'C:\Users\*\AppData\Local\Packages' }
        Mock Get-ChildItem {
            @(
                [PSCustomObject]@{ FullName = 'C:\Users\Alice\AppData\Local\Packages' }
                [PSCustomObject]@{ FullName = 'C:\Users\Bob\AppData\Local\Packages' }
            )
        }
        Mock Get-StoreAppsDatabasePathForUser { 'C:\Users\Default\AppData\Local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db' }
        Mock Set-StoreSearchSuggestionsDisabled {}
        Mock Set-StoreSearchSuggestionsEnabled {}
        Mock Write-Warning {}
    }

    It 'disables suggestions for every discovered and Default profile' {
        Set-StoreSearchSuggestionsDisabledForAllUsers

        Should -Invoke Set-StoreSearchSuggestionsDisabled -Times 3 -Exactly
        Should -Invoke Set-StoreSearchSuggestionsDisabled -Times 1 -Exactly -ParameterFilter { $StoreAppsDatabase -match 'Users\\Default\\' }
    }

    It 'enables suggestions for every discovered and Default profile' {
        Set-StoreSearchSuggestionsEnabledForAllUsers

        Should -Invoke Set-StoreSearchSuggestionsEnabled -Times 3 -Exactly
        Should -Invoke Set-StoreSearchSuggestionsEnabled -Times 1 -Exactly -ParameterFilter { $StoreAppsDatabase -match 'Users\\Default\\' }
    }

    It 'does not add a Default profile disable operation when its Store database path cannot be resolved' {
        Mock Get-StoreAppsDatabasePathForUser { $null }

        Set-StoreSearchSuggestionsDisabledForAllUsers

        Should -Invoke Set-StoreSearchSuggestionsDisabled -Times 2 -Exactly
    }

    It 'does not add a Default profile enable operation when its Store database path cannot be resolved' {
        Mock Get-StoreAppsDatabasePathForUser { $null }

        Set-StoreSearchSuggestionsEnabledForAllUsers

        Should -Invoke Set-StoreSearchSuggestionsEnabled -Times 2 -Exactly
    }

}

Describe 'Set-StoreSearchSuggestionsDisabled' {
    BeforeEach {
        $script:Params = @{ WhatIf = $true }
        Mock Test-Path { throw 'WhatIf should return before filesystem access.' }
        Mock Get-Acl { throw 'WhatIf should return before ACL access.' }
        Mock Set-Acl { throw 'WhatIf should return before ACL access.' }
        Mock Write-Host {}
    }

    It 'does not touch the filesystem in WhatIf mode' {
        Set-StoreSearchSuggestionsDisabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'

        Should -Invoke Test-Path -Times 0 -Exactly
        Should -Invoke Get-Acl -Times 0 -Exactly
        Should -Invoke Set-Acl -Times 0 -Exactly
    }

    It 'creates a missing database and parent directory before applying the deny rule' {
        $script:Params = @{}
        $acl = New-TestStoreDatabaseAcl
        Mock Test-Path { $false }
        Mock New-Item {}
        Mock Get-Acl { $acl }
        Mock Set-Acl {}

        Set-StoreSearchSuggestionsDisabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'

        Should -Invoke New-Item -Times 2 -Exactly
        Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $ItemType -eq 'Directory' }
        Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $ItemType -eq 'File' }
        Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'C:\Users\Alice\AppData\Local\Packages' -and $ItemType -eq 'Directory' -and $Force }
        Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'C:\Users\Alice\AppData\Local\Packages\store.db' -and $ItemType -eq 'File' -and $Force }
        Should -Invoke Set-Acl -Times 1 -Exactly -ParameterFilter { $Path -eq 'C:\Users\Alice\AppData\Local\Packages\store.db' -and $AclObject -eq $acl }
        $acl.AddedRules | Should -HaveCount 1
    }

    It 'updates the ACL without creating anything when the database already exists' {
        $script:Params = @{}
        $acl = New-TestStoreDatabaseAcl
        Mock Test-Path { $true }
        Mock New-Item { throw 'Existing database must not be recreated.' }
        Mock Get-Acl { $acl }
        Mock Set-Acl {}

        Set-StoreSearchSuggestionsDisabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'

        Should -Invoke New-Item -Times 0 -Exactly
        Should -Invoke Get-Acl -Times 1 -Exactly
        Should -Invoke Set-Acl -Times 1 -Exactly
        $acl.AddedRules | Should -HaveCount 1
    }

    It 'surfaces ACL failures instead of reporting the database as disabled' {
        $script:Params = @{}
        Mock Test-Path { $true }
        Mock Get-Acl { throw 'access denied' }
        Mock Set-Acl { throw 'ACL must not be written after a read failure.' }

        {
            Set-StoreSearchSuggestionsDisabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'
        } | Should -Throw '*access denied*'

        Should -Invoke Set-Acl -Times 0 -Exactly
    }
}

Describe 'Set-StoreSearchSuggestionsEnabled' {
    BeforeEach {
        $script:Params = @{}
        Mock Test-Path { $false }
        Mock Get-Acl { throw 'A missing database should return before ACL access.' }
        Mock Remove-Item { throw 'A missing database should not be removed.' }
        Mock Write-Host {}
    }

    It 'does nothing when the Store database does not exist' {
        Set-StoreSearchSuggestionsEnabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'

        Should -Invoke Get-Acl -Times 0 -Exactly
        Should -Invoke Remove-Item -Times 0 -Exactly
    }

    It 'does not touch an existing database in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }
        Mock Test-Path { throw 'WhatIf should return before filesystem access.' }
        Mock takeown { throw 'WhatIf should not take ownership.' }
        Mock icacls { throw 'WhatIf should not change ACLs.' }

        Set-StoreSearchSuggestionsEnabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'

        Should -Invoke Test-Path -Times 0 -Exactly
        Should -Invoke takeown -Times 0 -Exactly
        Should -Invoke icacls -Times 0 -Exactly
    }

    It 'normalizes the ACL and removes an existing database' {
        $acl = New-TestStoreDatabaseAcl
        Mock Test-Path { $true }
        Mock takeown {}
        Mock icacls {}
        Mock Get-Acl { $acl }
        Mock Set-Acl {}
        Mock Remove-Item {}

        Set-StoreSearchSuggestionsEnabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'

        Should -Invoke takeown -Times 1 -Exactly
        Should -Invoke icacls -Times 1 -Exactly
        Should -Invoke Get-Acl -Times 1 -Exactly
        Should -Invoke Set-Acl -Times 1 -Exactly
        Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'C:\Users\Alice\AppData\Local\Packages\store.db' -and $Force -and $ErrorAction -eq 'Stop' }
    }

    It 'continues removing an existing database when ACL normalization fails' {
        Mock Test-Path { $true }
        Mock takeown {}
        Mock icacls {}
        Mock Get-Acl { throw 'access denied' }
        Mock Set-Acl { throw 'Set-Acl must not run after Get-Acl fails.' }
        Mock Remove-Item {}
        Mock Write-Warning {}

        Set-StoreSearchSuggestionsEnabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'

        Should -Invoke Write-Warning -Times 1 -Exactly
        Should -Invoke Set-Acl -Times 0 -Exactly
        Should -Invoke Remove-Item -Times 1 -Exactly
    }

    It 'throws a contextual error when the database cannot be removed' {
        $acl = New-TestStoreDatabaseAcl
        Mock Test-Path { $true }
        Mock takeown {}
        Mock icacls {}
        Mock Get-Acl { $acl }
        Mock Set-Acl {}
        Mock Remove-Item { throw 'database is locked' }

        {
            Set-StoreSearchSuggestionsEnabled -StoreAppsDatabase 'C:\Users\Alice\AppData\Local\Packages\store.db'
        } | Should -Throw '*Failed to remove*database is locked*'
    }
}
