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

    It 'filters correctly when the names cross into a background runspace' {
        . (Join-Path $PSScriptRoot '..\Scripts\Threading\Invoke-NonBlocking.ps1')

        $script:AppsListFilePath = Join-Path $TestDrive 'Apps.json'
        $script:LoaderPath = Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppDetailsFromJson.ps1'
        $script:WingetHelperPath = Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Test-AppInWingetList.ps1'
        $script:LanguagePath = Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1'
        $script:Lang = Import-LanguageFile -LanguageCode 'en-US'

        # The async path hands the names to a fresh runspace, where the array must
        # survive intact instead of collapsing to its first element.
        $apps = @(Invoke-AppDetailsFromJsonAsync -OnlyInstalled -LoaderScriptPath $script:LoaderPath `
            -HelperScriptPath $script:WingetHelperPath -LanguageFileScriptPath $script:LanguagePath `
            -AppsFilePath $script:AppsListFilePath -Lang $script:Lang)

        @($apps | Where-Object { $_.AppIdDisplay -eq 'Contoso.Example.One' }).Count |
            Should -Be 1 -Because 'the name set reaches the runspace intact'
        @($apps | Where-Object { $_.AppIdDisplay -eq 'Contoso.Example.Two' }).Count |
            Should -Be 1 -Because 'the second enumerated name also arrives intact'
        @($apps).Count | Should -Be 2 -Because 'both enumerated names are installed'
    }
}
