BeforeAll {
    function NormalizeUserLookupValue { param($Value) ([string]$Value).Trim() }
    function ResolveUserProfileContext { param($UserName) $null }
    function reg { param($Action, $Mount, $Path) $global:LASTEXITCODE = 0 }
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\UserHiveHelpers.ps1')
}

Describe 'New-TargetUserHiveContext' {
    It 'projects user information and defaults an empty mount name' {
        $result = New-TargetUserHiveContext -TargetUserName 'Alice' -UserContext ([PSCustomObject]@{ UserSid = 'S-1'; ProfilePath = 'C:\Users\Alice' }) -HiveDatPath 'C:\Users\Alice\NTUSER.DAT' -MountName ''

        $result.TargetUserName | Should -Be 'Alice'
        $result.UserSid | Should -Be 'S-1'
        $result.MountName | Should -Be 'Default'
        $result.WasAlreadyLoaded | Should -BeFalse
    }
}

Describe 'Resolve-TargetUserHiveContext' {
    BeforeEach {
        Mock NormalizeUserLookupValue { param($Value) ([string]$Value).Trim() }
        Mock ResolveUserProfileContext { [PSCustomObject]@{ UserSid = 'S-1-5-21-123'; ProfilePath = $TestDrive } }
        Mock Test-Path { $true }
    }

    It 'uses an already loaded SID hive for a normal user' {
        $result = Resolve-TargetUserHiveContext -TargetUserName ' Alice '

        $result.MountName | Should -Be 'S-1-5-21-123'
        $result.WasAlreadyLoaded | Should -BeTrue
        $result.WasLoadedByScript | Should -BeFalse
    }

    It 'uses the temporary Default mount for <Case>' -ForEach @(
        @{ Case = 'an unloaded user'; User = 'Alice'; Sid = '' }
        @{ Case = 'the default profile'; User = 'Default'; Sid = 'S-1-5-21-123' }
    ) {
        Mock ResolveUserProfileContext { [PSCustomObject]@{ UserSid = $Sid; ProfilePath = $TestDrive } }
        Mock Test-Path { param($LiteralPath) $LiteralPath -like '*NTUSER.DAT' }

        $result = Resolve-TargetUserHiveContext -TargetUserName $User

        $result.MountName | Should -Be 'Default'
        $result.WasAlreadyLoaded | Should -BeFalse
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an empty user name'; UserName = ' '; Setup = 'None'; ExpectedError = 'Target user name for registry hive resolution is empty.' }
        @{ Case = 'an unresolved profile'; UserName = 'Missing'; Setup = 'MissingProfile'; ExpectedError = "Unable to resolve profile path for target user 'Missing'." }
        @{ Case = 'a missing hive file'; UserName = 'Alice'; Setup = 'MissingHive'; ExpectedError = 'Unable to find target user hive at *' }
    ) {
        if ($Setup -eq 'MissingProfile') {
            Mock ResolveUserProfileContext { $null }
        }
        elseif ($Setup -eq 'MissingHive') {
            Mock ResolveUserProfileContext { [PSCustomObject]@{ UserSid = 'S-1'; ProfilePath = $TestDrive } }
            Mock Test-Path { $false }
        }

        { Resolve-TargetUserHiveContext -TargetUserName $UserName } | Should -Throw $ExpectedError
    }
}

Describe 'Resolve-LoadedTargetUserHiveContext' {
    It '<Case>' -ForEach @(
        @{ Case = 'returns a loaded context when a SID hive is mounted'; Sid = 'S-1'; HiveMounted = $true; ExpectedLoaded = $true }
        @{ Case = 'returns null when the SID is empty'; Sid = ''; HiveMounted = $true; ExpectedLoaded = $false }
        @{ Case = 'returns null when the SID hive is not mounted'; Sid = 'S-1'; HiveMounted = $false; ExpectedLoaded = $false }
    ) {
        $input = [PSCustomObject]@{ TargetUserName = 'Alice'; UserSid = $Sid; ProfilePath = 'C:\Users\Alice'; HiveDatPath = 'C:\Users\Alice\NTUSER.DAT' }
        Mock Test-Path { $HiveMounted }

        $result = Resolve-LoadedTargetUserHiveContext -HiveContext $input
        if ($ExpectedLoaded) {
            $result.WasAlreadyLoaded | Should -BeTrue
        }
        else {
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-WithTargetUserHive' {
    BeforeEach {
        $script:RegistryTargetHiveMountName = 'Previous'
        $script:context = [PSCustomObject]@{
            TargetUserName = 'Alice'; UserSid = 'S-1'; ProfilePath = 'C:\Users\Alice'; HiveDatPath = 'C:\Users\Alice\NTUSER.DAT'
            MountName = 'Temporary'; WasAlreadyLoaded = $false; WasLoadedByScript = $false
        }
        Mock Resolve-TargetUserHiveContext { $script:context }
        Mock Resolve-LoadedTargetUserHiveContext { $null }
        Mock reg { $global:LASTEXITCODE = 0 }
        Mock Write-Warning {}
    }

    It 'loads, executes, passes context, unloads, and restores the previous mount name' {
        $result = Invoke-WithTargetUserHive -TargetUserName 'Alice' -ArgumentObject 'payload' -PassHiveContext -ScriptBlock {
            param($Argument, $Context)
            "$Argument|$($Context.MountName)|$script:RegistryTargetHiveMountName"
        }

        $result | Should -Be 'payload|Temporary|Temporary'
        Should -Invoke reg -Times 1 -Exactly -ParameterFilter { $Action -eq 'load' }
        Should -Invoke reg -Times 1 -Exactly -ParameterFilter { $Action -eq 'unload' }
        $script:RegistryTargetHiveMountName | Should -Be 'Previous'
    }

    It 'does not load or unload a hive that was already mounted' {
        $script:context.WasAlreadyLoaded = $true

        Invoke-WithTargetUserHive -TargetUserName 'Alice' -ScriptBlock { 'done' } | Should -Be 'done'
        Should -Invoke reg -Times 0 -Exactly
    }

    It 'unloads and restores state when the scriptblock throws' {
        { Invoke-WithTargetUserHive -TargetUserName 'Alice' -ScriptBlock { throw 'script failed' } } | Should -Throw 'script failed'

        Should -Invoke reg -Times 1 -Exactly -ParameterFilter { $Action -eq 'unload' }
        $script:RegistryTargetHiveMountName | Should -Be 'Previous'
    }

    It 'throws when loading fails without an already-loaded SID fallback' {
        Mock reg { if ($Action -eq 'load') { $global:LASTEXITCODE = 5 } }

        { Invoke-WithTargetUserHive -TargetUserName 'Alice' -ScriptBlock { 'never' } } |
            Should -Throw "Failed to load target user hive 'C:\Users\Alice\NTUSER.DAT' (exit code: 5)."
        Should -Invoke reg -Times 0 -Exactly -ParameterFilter { $Action -eq 'unload' }
    }

    It 'uses a loaded SID fallback after a load race' {
        Mock reg { if ($Action -eq 'load') { $global:LASTEXITCODE = 5 } }
        Mock Resolve-LoadedTargetUserHiveContext {
            [PSCustomObject]@{ TargetUserName = 'Alice'; UserSid = 'S-1'; ProfilePath = 'C:\Users\Alice'; HiveDatPath = 'C:\Users\Alice\NTUSER.DAT'; MountName = 'S-1'; WasAlreadyLoaded = $true; WasLoadedByScript = $false }
        }

        Invoke-WithTargetUserHive -TargetUserName 'Alice' -ScriptBlock { $script:RegistryTargetHiveMountName } | Should -Be 'S-1'
        Should -Invoke reg -Times 0 -Exactly -ParameterFilter { $Action -eq 'unload' }
    }

    It 'warns on unload failure without discarding the scriptblock result' {
        Mock reg {
            if ($Action -eq 'load') { $global:LASTEXITCODE = 0 }
            if ($Action -eq 'unload') { $global:LASTEXITCODE = 5 }
        }

        Invoke-WithTargetUserHive -TargetUserName 'Alice' -ScriptBlock { 'result' } | Should -Be 'result'
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "Failed to unload registry hive*" }
    }
}
