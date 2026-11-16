BeforeAll {
    # Count how many times the enumeration actually runs, so the cache can be
    # asserted rather than assumed.
    $script:AppxEnumerationCount = 0

    function Get-AppxPackage {
        [CmdletBinding()]
        param (
            [string]$Name,
            [switch]$AllUsers
        )

        $script:AppxEnumerationCount++

        if ($script:AppxEnumerationThrows) {
            throw 'enumeration failed'
        }

        return @(
            [PSCustomObject]@{ Name = 'Contoso.Example.One' }
            [PSCustomObject]@{ Name = 'Contoso.Example.Two' }
            [PSCustomObject]@{ Name = $null }
            [PSCustomObject]@{ Name = '' }
        )
    }

    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppDetailsFromJson.ps1')

    $script:LanguagesPath = Join-Path $PSScriptRoot '..\Config\Languages'
    $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
}

Describe 'Get-InstalledAppxNameSet' {
    BeforeEach {
        Reset-InstalledAppxNameCache
        $script:AppxEnumerationCount = 0
        $script:AppxEnumerationThrows = $false
    }

    It 'enumerates the packages once and caches the result' {
        $first = Get-InstalledAppxNameSet
        $countAfterFirst = $script:AppxEnumerationCount

        $second = Get-InstalledAppxNameSet

        $countAfterFirst | Should -Be 1 -Because 'the first call enumerates'
        $script:AppxEnumerationCount | Should -Be 1 -Because 'the second call reuses the cache'
        $second | Should -Contain 'Contoso.Example.One' -Because 'the cache hands back the same names'
        $second.Count | Should -Be $first.Count
    }

    It 'returns the package names and skips entries without a usable name' {
        $names = Get-InstalledAppxNameSet

        $names | Should -Contain 'Contoso.Example.One'
        $names | Should -Contain 'Contoso.Example.Two'
        $names.Count | Should -Be 2 -Because 'null and empty names are not package names'
    }

    It 're-enumerates after the cache is reset' {
        $null = Get-InstalledAppxNameSet
        $script:AppxEnumerationCount | Should -Be 1

        Reset-InstalledAppxNameCache
        $null = Get-InstalledAppxNameSet

        $script:AppxEnumerationCount | Should -Be 2 -Because 'a reset discards the cached enumeration'
    }

    It 'returns an empty set when the enumeration fails' {
        $script:AppxEnumerationThrows = $true

        $names = Get-InstalledAppxNameSet -WarningAction SilentlyContinue

        @($names).Count | Should -Be 0 -Because 'a failed enumeration yields no names'
    }

    It 'does not cache a failed enumeration, so the next call retries' {
        $script:AppxEnumerationThrows = $true
        $null = Get-InstalledAppxNameSet -WarningAction SilentlyContinue
        $script:AppxEnumerationCount | Should -Be 1

        # Recover, then ask again: the failure must not have been remembered.
        $script:AppxEnumerationThrows = $false
        $names = Get-InstalledAppxNameSet

        $script:AppxEnumerationCount | Should -Be 2 -Because 'a failure is retried rather than cached'
        $names | Should -Contain 'Contoso.Example.One'
    }
}

Describe 'Import-AppDetailsFromJson with a pre-fetched Appx name set' {
    BeforeEach {
        Reset-InstalledAppxNameCache
        $script:AppxEnumerationCount = 0
        $script:AppxEnumerationThrows = $false
        $script:AppsListFilePath = Join-Path $TestDrive 'Apps.json'
        '{"Apps":[{"AppId":"Contoso.Example.One"},{"AppId":"Contoso.Example.Two"}]}' |
            Set-Content -LiteralPath $script:AppsListFilePath -Encoding UTF8
    }

    It 'does not enumerate when the caller supplies the names' {
        $supplied = [string[]]@('Contoso.Example.One')

        $null = Import-AppDetailsFromJson -OnlyInstalled -InstalledAppxNames $supplied

        $script:AppxEnumerationCount | Should -Be 0 -Because 'the caller already did the enumeration'
    }

    It 'filters against the supplied names' {
        $supplied = [string[]]@('Contoso.Example.One')

        $apps = @(Import-AppDetailsFromJson -OnlyInstalled -InstalledAppxNames $supplied)

        @($apps | Where-Object { $_.AppIdDisplay -eq 'Contoso.Example.One' }).Count |
            Should -Be 1 -Because 'the supplied name marks the app as installed'
        @($apps | Where-Object { $_.AppIdDisplay -eq 'Contoso.Example.Two' }).Count |
            Should -Be 0 -Because 'a name absent from the supplied set is not installed'
    }

    It 'enumerates itself when no set is supplied' {
        $apps = @(Import-AppDetailsFromJson -OnlyInstalled)

        $script:AppxEnumerationCount | Should -Be 1 -Because 'the function falls back to its own enumeration'
        @($apps | Where-Object { $_.AppIdDisplay -eq 'Contoso.Example.One' }).Count |
            Should -Be 1 -Because 'the enumerated name marks the app as installed'
    }

    It 'filters correctly on the inline CLI path' {
        . (Join-Path $PSScriptRoot '..\Scripts\Threading\Invoke-NonBlocking.ps1')

        $script:AppsListFilePath = Join-Path $TestDrive 'Apps.json'
        $script:LoaderPath = Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppDetailsFromJson.ps1'
        $script:WingetHelperPath = Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Test-AppInWingetList.ps1'
        $script:LanguagePath = Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1'
        $script:Lang = Import-LanguageFile -LanguageCode 'en-US'

        # Without a GUI window, Invoke-NonBlocking runs the scriptblock in-process, so
        # the session's Get-AppxPackage mock is visible to the worker here. The real
        # out-of-process runscape is covered by the GUI-path Describe below.
        $apps = @(Invoke-AppDetailsFromJsonAsync -OnlyInstalled -LoaderScriptPath $script:LoaderPath `
            -HelperScriptPath $script:WingetHelperPath -LanguageFileScriptPath $script:LanguagePath `
            -AppsFilePath $script:AppsListFilePath -Lang $script:Lang)

        @($apps | Where-Object { $_.AppIdDisplay -eq 'Contoso.Example.One' }).Count |
            Should -Be 1 -Because 'the name set reaches the loader intact'
        @($apps | Where-Object { $_.AppIdDisplay -eq 'Contoso.Example.Two' }).Count |
            Should -Be 1 -Because 'the second enumerated name also arrives intact'
        @($apps).Count | Should -Be 2 -Because 'both enumerated names are installed'
    }
}

Describe 'Invoke-AppDetailsFromJsonAsync GUI-path runscape' {
    BeforeAll {
        # Force Invoke-NonBlocking down its real background-runscape branch. That branch
        # only pumps the UI through Invoke-DoEvents while waiting for the runspace, so the
        # test mocks the pump (same pattern as Invoke-NonBlocking.Tests.ps1) and needs no
        # real WPF dispatcher. The runspace itself still hands the cache hashtable to the
        # worker by reference across [powershell]::Create(), which is what this Describe
        # actually verifies.
        . (Join-Path $PSScriptRoot '..\Scripts\Threading\Invoke-NonBlocking.ps1')
        . (Join-Path $PSScriptRoot '..\Scripts\Threading\Invoke-DoEvents.ps1')
        $script:GuiWindow = [pscustomobject]@{ Title = 'test window' }

        $script:AppsListFilePath = Join-Path $TestDrive 'Apps.json'
        '{"Apps":[{"AppId":"Contoso.Example.One"},{"AppId":"Contoso.Example.Two"}]}' |
            Set-Content -LiteralPath $script:AppsListFilePath -Encoding UTF8
        $script:LoaderPath = Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppDetailsFromJson.ps1'
        $script:RealHelperPath = Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Test-AppInWingetList.ps1'
        $script:LanguagePath = Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1'
        $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
    }

    BeforeEach {
        Reset-InstalledAppxNameCache
    }

    AfterAll {
        # Don't leak the fake window into other Describes, which rely on the inline path.
        $script:GuiWindow = $null
    }

    It 'enumerates inside the runscape and backfills the shared cache by reference' {
        Mock Invoke-DoEvents {}

        # A mock Get-AppxPackage defined in this session cannot cross into the worker's
        # fresh runscape, so inject one through the helper script the worker dot-sources.
        $helper = Join-Path $TestDrive 'MockAppxHelper.ps1'
        $lines = @(
            'function Get-AppxPackage {'
            '    return @('
            '        [PSCustomObject]@{ Name = ''Contoso.Example.One'' }'
            '        [PSCustomObject]@{ Name = ''Contoso.Example.Two'' }'
            '    )'
            '}'
            ". '$script:RealHelperPath'"
        )
        Set-Content -LiteralPath $helper -Value $lines -Encoding UTF8

        $apps = @(Invoke-AppDetailsFromJsonAsync -OnlyInstalled `
            -LoaderScriptPath $script:LoaderPath -HelperScriptPath $helper `
            -LanguageFileScriptPath $script:LanguagePath -AppsFilePath $script:AppsListFilePath `
            -Lang $script:Lang)

        @($apps).Count | Should -Be 2 -Because 'both enumerated names reach the UI through the real runscape'
        # The caller-side cache is the same hashtable the worker filled by reference.
        $script:InstalledAppxNameCache['Contoso.Example.One'] | Should -Be $true
        $script:InstalledAppxNameCache['Contoso.Example.Two'] | Should -Be $true
    }

    It 'leaves the shared cache empty when the runscape enumeration fails' {
        Mock Invoke-DoEvents {}

        $helper = Join-Path $TestDrive 'FailingAppxHelper.ps1'
        $lines = @(
            'function Get-AppxPackage { throw ''enumeration failed'' }'
            ". '$script:RealHelperPath'"
        )
        Set-Content -LiteralPath $helper -Value $lines -Encoding UTF8

        # Invoke-NonBlocking returns $null when the worker emits no apps, the same empty
        # result the GUI handles by filtering falsy entries before display
        # (MainWindow-AppSelection.ps1); mirror that consumption here.
        $apps = @(Invoke-AppDetailsFromJsonAsync -OnlyInstalled `
            -LoaderScriptPath $script:LoaderPath -HelperScriptPath $helper `
            -LanguageFileScriptPath $script:LanguagePath -AppsFilePath $script:AppsListFilePath `
            -Lang $script:Lang | Where-Object { $_ -and $_.AppId })

        $apps.Count | Should -Be 0 -Because 'a failed enumeration matches no installed apps'
        $script:InstalledAppxNameCache.Count | Should -Be 0 -Because 'a failure is not cached, so the next refresh retries'
    }
}
