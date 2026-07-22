BeforeAll {
    function Get-UserDirectory { param($userName, $fileName, $exitIfPathNotFound) }

    . (Join-Path $PSScriptRoot '..\Scripts\Features\Replace-StartMenu.ps1')
}

Describe 'Get-StartMenuUserNameFromPath' {
    It 'extracts a user name from a start-menu path and falls back for unknown paths' {
        Get-StartMenuUserNameFromPath -StartMenuBinFile 'C:\Users\Alice\AppData\Local\Packages\Start\start2.bin' | Should -Be 'Alice'
        Get-StartMenuUserNameFromPath -StartMenuBinFile 'C:\Temp\start2.bin' | Should -Be 'unknown'
    }

    It 'returns the latest current-user start-menu backup' {
        Mock Get-ChildItem {
            @(
                [PSCustomObject]@{ Name = 'Win11Debloat-StartBackup-20260101_120000.bak'; FullName = 'C:\Backups\older.bak' }
                [PSCustomObject]@{ Name = 'Win11Debloat-StartBackup-20260102_120000.bak'; FullName = 'C:\Backups\newer.bak' }
            )
        }

        Get-StartMenuBackupPath -Scope CurrentUser | Should -Be 'C:\Backups\newer.bak'
    }

    It 'returns the first available all-users start-menu backup' {
        $script:allUsersPath = 'C:\Users\*\AppData\Local\Packages\Start\LocalState'
        Mock Get-UserDirectory { $script:allUsersPath }
        Mock Get-ChildItem {
            param($Path)
            if ($Path -eq $script:allUsersPath) {
                return [PSCustomObject]@{ FullName = 'C:\Users\Alice\AppData\Local\Packages\Start\LocalState' }
            }

            return [PSCustomObject]@{ Name = 'Win11Debloat-StartBackup-20260103_120000.bak'; FullName = 'C:\Users\Alice\backup.bak' }
        }

        Get-StartMenuBackupPath -Scope AllUsers | Should -Be 'C:\Users\Alice\backup.bak'
    }

    It 'restores a start menu backup and preserves the replaced file' {
        $script:Params = @{}
        $startMenuFile = Join-Path $TestDrive 'start2.bin'
        $backupFile = Join-Path $TestDrive 'Win11Debloat-StartBackup-20260101_120000.bak'
        Set-Content -LiteralPath $startMenuFile -Value 'current'
        Set-Content -LiteralPath $backupFile -Value 'backup'

        $result = Restore-StartMenuFromBackup -StartMenuBinFile $startMenuFile -BackupFilePath $backupFile

        $result.Result | Should -BeTrue
        Get-Content -LiteralPath $startMenuFile -Raw | Should -Match 'backup'
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'Win11Debloat-StartRestore-*.bak').Count | Should -Be 1
    }

    It 'reports a missing backup without changing the start-menu file' {
        $script:Params = @{}
        $startMenuFile = Join-Path $TestDrive 'start2.bin'
        Set-Content -LiteralPath $startMenuFile -Value 'current'

        $result = Restore-StartMenuFromBackup -StartMenuBinFile $startMenuFile -BackupFilePath (Join-Path $TestDrive 'missing.bak')

        $result.Result | Should -BeFalse
        Get-Content -LiteralPath $startMenuFile -Raw | Should -Match 'current'
    }

    It 'preserves a recoverable copy of the current layout when restoring fails' {
        $script:Params = @{}
        $startMenuFile = Join-Path $TestDrive 'start2.bin'
        $backupFile = Join-Path $TestDrive 'Win11Debloat-StartBackup-20260101_120000.bak'
        Set-Content -LiteralPath $startMenuFile -Value 'current'
        Set-Content -LiteralPath $backupFile -Value 'backup'
        Mock Copy-Item { throw 'disk full' }

        $result = Restore-StartMenuFromBackup -StartMenuBinFile $startMenuFile -BackupFilePath $backupFile

        $result.Result | Should -BeFalse
        $result.Message | Should -Match 'disk full'
        $restoreCopies = @(Get-ChildItem -LiteralPath $TestDrive -Filter 'Win11Debloat-StartRestore-*.bak')
        $restoreCopies.Count | Should -Be 1
        Get-Content -LiteralPath $restoreCopies[0].FullName -Raw | Should -Match 'current'
    }

    It 'leaves the original layout in place when it cannot be moved for restore' {
        $script:Params = @{}
        $startMenuFile = Join-Path $TestDrive 'start2.bin'
        $backupFile = Join-Path $TestDrive 'Win11Debloat-StartBackup-20260101_120000.bak'
        Set-Content -LiteralPath $startMenuFile -Value 'current'
        Set-Content -LiteralPath $backupFile -Value 'backup'
        Mock Move-Item { throw 'locked' }

        $result = Restore-StartMenuFromBackup -StartMenuBinFile $startMenuFile -BackupFilePath $backupFile

        $result.Result | Should -BeFalse
        $result.Message | Should -Match 'locked'
        Get-Content -LiteralPath $startMenuFile -Raw | Should -Match 'current'
    }

    It 'delegates current-user restore to the common backup operation' {
        $script:Params = @{}
        Mock Restore-StartMenuFromBackup { [PSCustomObject]@{ Result = $true } }

        Restore-StartMenu -BackupFilePath 'C:\Backups\backup.bak' | Should -Not -BeNullOrEmpty
        Should -Invoke Restore-StartMenuFromBackup -Times 1 -Exactly -ParameterFilter { $BackupFilePath -eq 'C:\Backups\backup.bak' }
    }

    It 'restores every discovered user and removes the default-profile start menu' {
        $script:Params = @{}
        $script:allUsersStartPath = 'C:\Users\*\LocalState'
        $script:defaultStartPath = Join-Path $TestDrive 'DefaultLocalState'
        $defaultBin = Join-Path $script:defaultStartPath 'start2.bin'
        New-Item -ItemType Directory -Path $script:defaultStartPath | Out-Null
        Set-Content -LiteralPath $defaultBin -Value 'template'
        Mock Get-UserDirectory { param($userName) if ($userName -eq '*') { $script:allUsersStartPath } else { $script:defaultStartPath } }
        Mock Get-ChildItem { param($Path) if ($Path -eq $script:allUsersStartPath) { [PSCustomObject]@{ FullName = 'C:\Users\Alice\LocalState' } } }
        Mock Restore-StartMenuFromBackup { [PSCustomObject]@{ UserName = 'Alice'; Result = $true; Message = 'Restored' } }

        $result = @(Restore-StartMenuForAllUsers -BackupFilePath 'C:\Backups\backup.bak')

        $result.Count | Should -Be 2
        Should -Invoke Restore-StartMenuFromBackup -Times 1 -Exactly
        Test-Path -LiteralPath $defaultBin | Should -BeFalse
    }
}
Describe 'Replace-StartMenu' {
    BeforeEach {
        $script:Params = @{}
        Mock Write-Host {}
    }

    It 'backs up and replaces an existing start-menu file' {
        $startMenuFile = Join-Path $TestDrive 'start2.bin'
        $templateFile = Join-Path $TestDrive 'template.bin'
        Set-Content -LiteralPath $startMenuFile -Value 'current layout'
        Set-Content -LiteralPath $templateFile -Value 'replacement layout'

        Replace-StartMenu -startMenuBinFile $startMenuFile -startMenuTemplate $templateFile

        Get-Content -LiteralPath $startMenuFile -Raw | Should -Match 'replacement layout'
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'Win11Debloat-StartBackup-*.bak').Count | Should -Be 1
    }

    It 'creates and replaces a missing start-menu file without a backup' {
        $testDirectory = Join-Path $TestDrive 'missing-layout'
        New-Item -ItemType Directory -Path $testDirectory | Out-Null
        $startMenuFile = Join-Path $testDirectory 'start2.bin'
        $templateFile = Join-Path $testDirectory 'template.bin'
        $backupCountBefore = @(Get-ChildItem -LiteralPath $testDirectory -Filter 'Win11Debloat-StartBackup-*.bak').Count
        Set-Content -LiteralPath $templateFile -Value 'replacement layout'

        Replace-StartMenu -startMenuBinFile $startMenuFile -startMenuTemplate $templateFile

        Get-Content -LiteralPath $startMenuFile -Raw | Should -Match 'replacement layout'
        @(Get-ChildItem -LiteralPath $testDirectory -Filter 'Win11Debloat-StartBackup-*.bak').Count | Should -Be $backupCountBefore
    }

    It 'does not change a start-menu file in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }
        $testDirectory = Join-Path $TestDrive 'whatif-layout'
        New-Item -ItemType Directory -Path $testDirectory | Out-Null
        $startMenuFile = Join-Path $testDirectory 'start2.bin'
        $templateFile = Join-Path $testDirectory 'template.bin'
        $backupCountBefore = @(Get-ChildItem -LiteralPath $testDirectory -Filter 'Win11Debloat-StartBackup-*.bak').Count
        Set-Content -LiteralPath $startMenuFile -Value 'current layout'
        Set-Content -LiteralPath $templateFile -Value 'replacement layout'

        Replace-StartMenu -startMenuBinFile $startMenuFile -startMenuTemplate $templateFile

        Get-Content -LiteralPath $startMenuFile -Raw | Should -Match 'current layout'
        @(Get-ChildItem -LiteralPath $testDirectory -Filter 'Win11Debloat-StartBackup-*.bak').Count | Should -Be $backupCountBefore
    }
}

Describe 'Replace-StartMenuForAllUsers guard paths' {
    BeforeEach {
        $script:Params = @{}
        $script:AssetsPath = $TestDrive
        Mock Get-UserDirectory { Join-Path $TestDrive 'Users' }
        Mock Get-ChildItem { @() }
        Mock Replace-StartMenu {}
        Mock New-Item {}
        Mock Write-Host {}
    }

    It 'does not touch profiles when the template is missing' {
        Replace-StartMenuForAllUsers -startMenuTemplate (Join-Path $TestDrive 'missing.bin')

        Should -Invoke Get-UserDirectory -Times 0 -Exactly
        Should -Invoke Replace-StartMenu -Times 0 -Exactly
    }

    It 'does not create or replace the Default profile in WhatIf mode' {
        $template = Join-Path $TestDrive 'template.bin'
        Set-Content -LiteralPath $template -Value 'template'
        $script:Params = @{ WhatIf = $true }
        Mock Test-Path { param($Path) $Path -eq $template }

        Replace-StartMenuForAllUsers -startMenuTemplate $template

        Should -Invoke New-Item -Times 0 -Exactly
        Should -Invoke Replace-StartMenu -Times 0 -Exactly
    }

}
