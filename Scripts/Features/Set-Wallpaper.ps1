function Initialize-WallpaperNativeMethods {
    if (-not ('Win11Debloat.WallpaperNativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace Win11Debloat {
    public static class WallpaperNativeMethods {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool SystemParametersInfo(uint action, uint parameter, string value, uint flags);
        [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool GetWallpaper(uint action, uint parameter, StringBuilder value, uint flags);
    }
}
'@ -ErrorAction Stop
    }
}

function Get-WallpaperUserSid {
    return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Get-CurrentWallpaperState {
    Initialize-WallpaperNativeMethods
    $buffer = New-Object System.Text.StringBuilder 32768
    if (-not [Win11Debloat.WallpaperNativeMethods]::GetWallpaper(115, $buffer.Capacity, $buffer, 0)) {
        throw 'Nie udało się odczytać bieżącej tapety.'
    }
    $desktop = Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction Stop
    return [PSCustomObject]@{
        Wallpaper = $buffer.ToString()
        WallpaperStyle = if ($null -ne $desktop.WallpaperStyle) { [string]$desktop.WallpaperStyle } else { '10' }
        TileWallpaper = if ($null -ne $desktop.TileWallpaper) { [string]$desktop.TileWallpaper } else { '0' }
    }
}

function Save-LocalWallpaperImage {
    param([string]$SourcePath, [string]$DestinationPath)

    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $image = $null
    try {
        if ($SourcePath -eq 'Black') {
            $image = New-Object System.Drawing.Bitmap 1, 1
            $image.SetPixel(0, 0, [System.Drawing.Color]::Black)
        }
        else {
            $image = [System.Drawing.Image]::FromFile($SourcePath)
        }
        $image.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
    }
    finally {
        if ($image) { $image.Dispose() }
    }
}

function Save-WallpaperBackup {
    param([Parameter(Mandatory)][object]$WallpaperState)

    $ErrorActionPreference = 'Stop'
    New-Item -ItemType Directory -Path $script:WallpaperBackupsPath -Force | Out-Null
    $backupId = (Get-Date -Format 'yyyyMMdd_HHmmss_fffffff') + '_' + [guid]::NewGuid().ToString('N')
    $backupImageName = ''
    if (-not [string]::IsNullOrWhiteSpace($WallpaperState.Wallpaper)) {
        $backupImageName = $backupId + '.bmp'
        Save-LocalWallpaperImage -SourcePath $WallpaperState.Wallpaper -DestinationPath (Join-Path $script:WallpaperBackupsPath $backupImageName)
    }
    $manifest = @{
        Version = '1.0'
        BackupType = 'WallpaperState'
        CreatedAt = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        UserSid = Get-WallpaperUserSid
        ImageName = $backupImageName
        WallpaperStyle = [string]$WallpaperState.WallpaperStyle
        TileWallpaper = [string]$WallpaperState.TileWallpaper
    }
    $manifestPath = Join-Path $script:WallpaperBackupsPath ('Win11Debloat-WallpaperBackup-' + $backupId + '.json')
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    return $manifestPath
}

function Invoke-WallpaperRefresh {
    param([AllowEmptyString()][string]$WallpaperPath)

    Initialize-WallpaperNativeMethods
    if (-not [Win11Debloat.WallpaperNativeMethods]::SystemParametersInfo(20, 0, $WallpaperPath, 3)) {
        throw "Nie udało się odświeżyć tapety. Błąd Win32: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())."
    }
}

function Set-WallpaperDesktopState {
    param([string]$WallpaperPath, [string]$WallpaperStyle, [string]$TileWallpaper)

    Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value $WallpaperStyle -ErrorAction Stop
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value $TileWallpaper -ErrorAction Stop
    Invoke-WallpaperRefresh -WallpaperPath $WallpaperPath
}

function Set-WallpaperFromPath {
    param([Parameter(Mandatory)][string]$WallpaperPath)

    $ErrorActionPreference = 'Stop'
    if ($script:Params.ContainsKey('User') -or $script:Params.ContainsKey('Sysprep')) {
        Write-Warning 'Zmiana tapety dotyczy wyłącznie bieżącego użytkownika.'
        return $false
    }
    if ($WallpaperPath -ne 'Black' -and -not (Test-Path -LiteralPath $WallpaperPath -PathType Leaf)) {
        Write-Warning "Nie znaleziono tapety: $WallpaperPath. Pozostałe zmiany będą kontynuowane."
        return $false
    }
    if ($WallpaperPath -ne 'Black' -and [System.IO.Path]::GetExtension($WallpaperPath).ToLowerInvariant() -notin @('.bmp', '.jpg', '.jpeg', '.png')) {
        Write-Warning 'Nieobsługiwany format tapety. Użyj BMP, JPG, JPEG lub PNG.'
        return $false
    }
    if ($script:Params.ContainsKey('WhatIf')) {
        Write-Host "[WhatIf] Tapeta: $WallpaperPath"
        return $true
    }

    $backupPath = $null
    try {
        $currentState = Get-CurrentWallpaperState
        New-Item -ItemType Directory -Path $script:WallpaperDataPath -Force | Out-Null
        $localImage = Join-Path $script:WallpaperDataPath ([guid]::NewGuid().ToString('N') + '.bmp')
        Save-LocalWallpaperImage -SourcePath $WallpaperPath -DestinationPath $localImage
        $backupPath = Save-WallpaperBackup -WallpaperState $currentState
        Set-WallpaperDesktopState -WallpaperPath $localImage -WallpaperStyle '10' -TileWallpaper '0'
        Write-Host "Ustawiono tapetę. Kopia zapasowa: $backupPath"
        return $true
    }
    catch {
        Write-Warning "Nie udało się ustawić tapety: $($_.Exception.Message)"
        if ($backupPath) { Restore-WallpaperFromBackup -BackupPath $backupPath | Out-Null }
        return $false
    }
}

function Restore-WallpaperFromBackup {
    param([string]$BackupPath)

    $ErrorActionPreference = 'Stop'
    if ($script:Params.ContainsKey('User') -or $script:Params.ContainsKey('Sysprep')) {
        Write-Warning 'Przywracanie tapety dotyczy wyłącznie bieżącego użytkownika.'
        return $false
    }
    if ($script:Params.ContainsKey('WhatIf')) {
        Write-Host '[WhatIf] Przywróć ostatnią kopię tapety'
        return $true
    }
    $previousState = $null
    $restoreStarted = $false
    try {
        if ([string]::IsNullOrWhiteSpace($BackupPath)) {
            $BackupPath = Get-ChildItem -LiteralPath $script:WallpaperBackupsPath -Filter 'Win11Debloat-WallpaperBackup-*.json' -File -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
        }
        if ([string]::IsNullOrWhiteSpace($BackupPath)) { throw 'Nie znaleziono lokalnej kopii tapety.' }
        $manifest = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.Version -ne '1.0' -or $manifest.BackupType -ne 'WallpaperState' -or
            $manifest.UserSid -ne (Get-WallpaperUserSid) -or $manifest.ComputerName -ne $env:COMPUTERNAME -or
            $manifest.WallpaperStyle -notin @('0', '2', '6', '10', '22') -or $manifest.TileWallpaper -notin @('0', '1') -or
            $null -eq $manifest.PSObject.Properties['ImageName']) {
            throw 'Kopia tapety ma nieprawidłowy format albo pochodzi z innego komputera lub konta.'
        }
        $imagePath = ''
        if ($manifest.ImageName) {
            if ([string]$manifest.ImageName -notmatch '^[a-zA-Z0-9_]+\.bmp$') { throw 'Nieprawidłowa nazwa obrazu w kopii.' }
            $imagePath = Join-Path (Split-Path -Parent $BackupPath) $manifest.ImageName
            if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw 'Brakuje obrazu z kopii tapety.' }
        }
        $previousState = Get-CurrentWallpaperState
        $restoreStarted = $true
        Set-WallpaperDesktopState -WallpaperPath $imagePath -WallpaperStyle $manifest.WallpaperStyle -TileWallpaper $manifest.TileWallpaper
        Write-Host "Przywrócono tapetę z kopii: $BackupPath"
        return $true
    }
    catch {
        Write-Warning "Nie udało się przywrócić tapety: $($_.Exception.Message)"
        if ($restoreStarted) {
            try {
                Set-WallpaperDesktopState -WallpaperPath $previousState.Wallpaper -WallpaperStyle $previousState.WallpaperStyle -TileWallpaper $previousState.TileWallpaper
            }
            catch {
                Write-Warning "Nie udało się cofnąć nieudanego przywracania tapety: $($_.Exception.Message)"
            }
        }
        return $false
    }
}
