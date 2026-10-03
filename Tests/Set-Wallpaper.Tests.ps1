BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Set-Wallpaper.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Invoke-Changes.ps1')
}

Describe 'Wallpaper operations' {
    BeforeEach {
        $script:Params = @{}
        $testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:WallpaperBackupsPath = Join-Path $testRoot 'Backups'
        $script:WallpaperDataPath = Join-Path $testRoot 'Wallpapers'
        $wallpaperPath = Join-Path $TestDrive "obraz & test's!.jpg"
        'image fixture' | Set-Content -LiteralPath $wallpaperPath
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Get-WallpaperUserSid { 'S-1-5-21-test' }
        Mock Get-CurrentWallpaperState {
            [PSCustomObject]@{ Wallpaper = ''; WallpaperStyle = '2'; TileWallpaper = '0' }
        }
        Mock Save-LocalWallpaperImage {
            param($SourcePath, $DestinationPath)
            'converted image' | Set-Content -LiteralPath $DestinationPath
        }
        Mock Set-ItemProperty {}
        Mock Invoke-WallpaperRefresh {}
    }

    It 'reports missing or unsupported files without changing the desktop' -ForEach @(
        @{ PathName = 'missing.jpg' }
        @{ PathName = 'unsupported.gif' }
    ) {
        $inputPath = Join-Path $TestDrive $PathName
        if ($PathName -eq 'unsupported.gif') { 'fixture' | Set-Content -LiteralPath $inputPath }
        Set-WallpaperFromPath -WallpaperPath $inputPath | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -Exactly
        Should -Invoke Set-ItemProperty -Times 0 -Exactly
        Should -Invoke Invoke-WallpaperRefresh -Times 0 -Exactly
    }

    It 'copies the selected image locally and records a restore manifest before applying it' {
        Set-WallpaperFromPath -WallpaperPath $wallpaperPath | Should -BeTrue
        Should -Invoke Save-LocalWallpaperImage -Times 1 -Exactly -ParameterFilter {
            $SourcePath -eq $wallpaperPath -and $DestinationPath.StartsWith($script:WallpaperDataPath)
        }
        Should -Invoke Set-ItemProperty -Times 2 -Exactly
        Should -Invoke Invoke-WallpaperRefresh -Times 1 -Exactly -ParameterFilter {
            $WallpaperPath.StartsWith($script:WallpaperDataPath)
        }
        $manifestPath = Get-ChildItem -LiteralPath $script:WallpaperBackupsPath -Filter '*.json' | Select-Object -ExpandProperty FullName
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifest.UserSid | Should -Be 'S-1-5-21-test'
        $manifest.ImageName | Should -Be ''
        $manifest.WallpaperStyle | Should -Be '2'
    }

    It 'supports the built-in black wallpaper without an image asset' {
        Set-WallpaperFromPath -WallpaperPath Black | Should -BeTrue
        Should -Invoke Save-LocalWallpaperImage -Times 1 -Exactly -ParameterFilter { $SourcePath -eq 'Black' }
    }

    It 'does not overwrite previous local images or manifests across repeated runs' {
        Set-WallpaperFromPath -WallpaperPath Black | Should -BeTrue
        Set-WallpaperFromPath -WallpaperPath $wallpaperPath | Should -BeTrue
        @(Get-ChildItem -LiteralPath $script:WallpaperDataPath -Filter '*.bmp') | Should -HaveCount 2
        @(Get-ChildItem -LiteralPath $script:WallpaperBackupsPath -Filter '*.json') | Should -HaveCount 2
    }

    It 'refuses other-user and Sysprep targets for set and restore' -ForEach @(
        @{ Target = 'User' }
        @{ Target = 'Sysprep' }
    ) {
        $script:Params[$Target] = $true
        Set-WallpaperFromPath -WallpaperPath Black | Should -BeFalse
        Restore-WallpaperFromBackup | Should -BeFalse
        Should -Invoke Get-CurrentWallpaperState -Times 0 -Exactly
        Should -Invoke Set-ItemProperty -Times 0 -Exactly
    }

    It 'makes no wallpaper or backup writes in WhatIf mode' {
        $script:Params.WhatIf = $true
        Mock New-Item {}
        Set-WallpaperFromPath -WallpaperPath Black | Should -BeTrue
        Restore-WallpaperFromBackup | Should -BeTrue
        Should -Invoke New-Item -Times 0 -Exactly
        Should -Invoke Save-LocalWallpaperImage -Times 0 -Exactly
        Should -Invoke Set-ItemProperty -Times 0 -Exactly
        Should -Invoke Invoke-WallpaperRefresh -Times 0 -Exactly
    }

    It 'does not touch the registry when image decoding fails' {
        Mock Save-LocalWallpaperImage { throw 'Invalid image' }
        Set-WallpaperFromPath -WallpaperPath $wallpaperPath | Should -BeFalse
        Should -Invoke Set-ItemProperty -Times 0 -Exactly
    }

    It 'does not touch the registry when the backup cannot be written' {
        Mock Save-WallpaperBackup { throw 'Disk full' }
        Set-WallpaperFromPath -WallpaperPath Black | Should -BeFalse
        Should -Invoke Set-ItemProperty -Times 0 -Exactly
        Should -Invoke Invoke-WallpaperRefresh -Times 0 -Exactly
    }

    It 'rolls back the desktop state if the native wallpaper refresh fails' {
        $script:RefreshAttempts = 0
        Mock Invoke-WallpaperRefresh {
            $script:RefreshAttempts++
            if ($script:RefreshAttempts -eq 1) { throw 'Native failure' }
        }
        Set-WallpaperFromPath -WallpaperPath Black | Should -BeFalse
        Should -Invoke Invoke-WallpaperRefresh -Times 2 -Exactly
        Should -Invoke Invoke-WallpaperRefresh -Times 1 -Exactly -ParameterFilter { $WallpaperPath -eq '' }
        Should -Invoke Set-ItemProperty -Times 1 -Exactly -ParameterFilter { $Name -eq 'WallpaperStyle' -and $Value -eq '2' }
    }

    It 'restores the previous image from a local backup even if the original is gone' {
        $previousImage = Join-Path $TestDrive 'previous.jpg'
        'previous image fixture' | Set-Content -LiteralPath $previousImage
        Mock Get-CurrentWallpaperState {
            [PSCustomObject]@{ Wallpaper = $previousImage; WallpaperStyle = '6'; TileWallpaper = '0' }
        }
        Set-WallpaperFromPath -WallpaperPath Black | Should -BeTrue
        Remove-Item -LiteralPath $previousImage
        Restore-WallpaperFromBackup | Should -BeTrue
        Should -Invoke Invoke-WallpaperRefresh -Times 1 -Exactly -ParameterFilter {
            $WallpaperPath.StartsWith($script:WallpaperBackupsPath)
        }
    }

    It 'rolls back a failed restore to the state that preceded the restore' {
        $backupPath = Save-WallpaperBackup -WallpaperState ([PSCustomObject]@{
            Wallpaper = ''; WallpaperStyle = '6'; TileWallpaper = '1'
        })
        $script:RefreshAttempts = 0
        Mock Invoke-WallpaperRefresh {
            $script:RefreshAttempts++
            if ($script:RefreshAttempts -eq 1) { throw 'Native restore failure' }
        }
        Restore-WallpaperFromBackup -BackupPath $backupPath | Should -BeFalse
        Should -Invoke Invoke-WallpaperRefresh -Times 2 -Exactly
        Should -Invoke Set-ItemProperty -Times 1 -Exactly -ParameterFilter { $Name -eq 'WallpaperStyle' -and $Value -eq '2' }
        Should -Invoke Set-ItemProperty -Times 1 -Exactly -ParameterFilter { $Name -eq 'TileWallpaper' -and $Value -eq '0' }
    }

    It 'reports both restore and rollback failures without throwing or claiming success' {
        $backupPath = Save-WallpaperBackup -WallpaperState (Get-CurrentWallpaperState)
        Mock Invoke-WallpaperRefresh { throw 'Persistent native failure' }
        Restore-WallpaperFromBackup -BackupPath $backupPath | Should -BeFalse
        Should -Invoke Invoke-WallpaperRefresh -Times 2 -Exactly
        Should -Invoke Write-Warning -Times 2 -Exactly
    }

    It 'rejects a foreign or invalid manifest before changing the registry' -ForEach @(
        @{ Property = 'UserSid'; Value = 'S-1-5-21-other' }
        @{ Property = 'ComputerName'; Value = 'other-computer' }
        @{ Property = 'Version'; Value = '2.0' }
        @{ Property = 'BackupType'; Value = 'Other' }
        @{ Property = 'ImageName'; Value = '../escape.bmp' }
        @{ Property = 'ImageName'; Value = 'missing.bmp' }
        @{ Property = 'WallpaperStyle'; Value = 'invalid' }
        @{ Property = 'TileWallpaper'; Value = '2' }
    ) {
        $state = Get-CurrentWallpaperState
        $backupPath = Save-WallpaperBackup -WallpaperState $state
        $manifest = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
        $manifest.$Property = $Value
        $manifest | ConvertTo-Json | Set-Content -LiteralPath $backupPath
        Restore-WallpaperFromBackup -BackupPath $backupPath | Should -BeFalse
        Should -Invoke Set-ItemProperty -Times 0 -Exactly
    }

    It 'reports missing backups without changing the registry' {
        Restore-WallpaperFromBackup | Should -BeFalse
        Should -Invoke Set-ItemProperty -Times 0 -Exactly
    }

    It 'routes both wallpaper actions through the existing feature engine' {
        $script:Params.WallpaperPath = 'Black'
        $script:Features = @{
            SetWallpaper = [PSCustomObject]@{ ApplyText = 'Set wallpaper' }
            RestoreWallpaper = [PSCustomObject]@{ ApplyText = 'Restore wallpaper' }
        }
        Mock Set-WallpaperFromPath { $true }
        Mock Restore-WallpaperFromBackup { $false }
        Invoke-FeatureApply -FeatureId SetWallpaper | Should -BeTrue
        Invoke-FeatureApply -FeatureId RestoreWallpaper | Should -BeFalse
        Should -Invoke Set-WallpaperFromPath -Times 1 -Exactly -ParameterFilter { $WallpaperPath -eq 'Black' }
        Should -Invoke Restore-WallpaperFromBackup -Times 1 -Exactly
    }
}

Describe 'Windows wallpaper image conversion' -Skip:($env:OS -ne 'Windows_NT') {
    BeforeAll {
        Add-Type -AssemblyName System.Drawing
    }

    It 'creates a genuinely black BMP without a source file' {
        $destination = Join-Path $TestDrive 'black.bmp'
        Save-LocalWallpaperImage -SourcePath Black -DestinationPath $destination
        $image = [System.Drawing.Bitmap]::FromFile($destination)
        try {
            $image.Width | Should -Be 1
            $image.Height | Should -Be 1
            $image.GetPixel(0, 0).ToArgb() | Should -Be ([System.Drawing.Color]::Black.ToArgb())
        }
        finally { $image.Dispose() }
    }

    It 'converts <Extension> to a readable local BMP' -ForEach @(
        @{ Extension = 'jpg'; ImageFormat = 'Jpeg' }
        @{ Extension = 'jpeg'; ImageFormat = 'Jpeg' }
        @{ Extension = 'png'; ImageFormat = 'Png' }
        @{ Extension = 'bmp'; ImageFormat = 'Bmp' }
    ) {
        $sourcePath = Join-Path $TestDrive ('source.' + $Extension)
        $destination = Join-Path $TestDrive ('converted-' + $Extension + '.bmp')
        $sourceImage = New-Object System.Drawing.Bitmap 2, 2
        try {
            $sourceImage.Save($sourcePath, [System.Drawing.Imaging.ImageFormat]::$ImageFormat)
        }
        finally { $sourceImage.Dispose() }
        Save-LocalWallpaperImage -SourcePath $sourcePath -DestinationPath $destination
        $bytes = [IO.File]::ReadAllBytes($destination)
        ($bytes[0..1] -join ',') | Should -Be '66,77'
        $convertedImage = [System.Drawing.Image]::FromFile($destination)
        try {
            $convertedImage.Width | Should -Be 2
            $convertedImage.Height | Should -Be 2
        }
        finally { $convertedImage.Dispose() }
    }

    It 'rejects corrupt image contents' {
        $sourcePath = Join-Path $TestDrive 'corrupt.jpg'
        'not an image' | Set-Content -LiteralPath $sourcePath
        { Save-LocalWallpaperImage -SourcePath $sourcePath -DestinationPath (Join-Path $TestDrive 'corrupt.bmp') } | Should -Throw
    }
}
