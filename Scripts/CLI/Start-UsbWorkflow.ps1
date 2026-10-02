[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repositoryRoot 'Scripts\Helpers\Usb-WorkflowHelpers.ps1')

try {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw 'Uruchom Run.bat w Windows 11. Ten tryb wymaga Windows PowerShell 5.1.'
    }
    $build = [int](Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild)
    if ($build -lt 22000) {
        throw 'Tryb przygotowania komputerów obsługuje wyłącznie Windows 11.'
    }

    do {
        Clear-Host
        Write-Host 'Win11Debloat — przygotowanie Windows 11' -ForegroundColor Cyan
        Write-Host '1. Normalny'
        Write-Host '2. Agresywny (również aplikacje producenta)'
        Write-Host '3. Gaming (zachowuje aplikacje Xbox)'
        Write-Host '4. Tryb własny — pełny interfejs'
        Write-Host '5. Tylko tapeta'
        Write-Host '6. Przywróć kopię rejestru lub menu Start'
        Write-Host '7. Przywróć ostatnią kopię tapety'
        Write-Host '0. Wyjście'
        $menuChoice = Read-Host 'Wybierz opcję (Enter = Normalny)'
        if ([string]::IsNullOrWhiteSpace($menuChoice)) { $menuChoice = '1' }
        $selection = Get-UsbWorkflowSelection -Choice $menuChoice
    } while ($null -eq $selection)

    if ($selection.ContainsKey('Exit')) { exit 0 }

    if ($selection['Preset'] -eq 'Aggressive') {
        Write-Warning 'Ten preset wyłącza lokalizację, powiadomienia i dodatkowe funkcje interfejsu oraz usuwa aplikacje OEM, także narzędzia zasilania i wsparcia producenta.'
        if ((Read-Host 'Aby kontynuować, wpisz TAK') -ine 'TAK') { exit 3 }
        $selection['ConfirmAggressive'] = $true
    }

    if ($selection.ContainsKey('Preset') -or $selection.ContainsKey('SetWallpaper')) {
        $wallpapers = @(Get-UsbWallpaperChoices -Directory (Join-Path $repositoryRoot 'Assets\Wallpapers'))
        Write-Host '0. Bez zmiany tapety'
        for ($index = 0; $index -lt $wallpapers.Count; $index++) {
            Write-Host ("{0}. {1}" -f ($index + 1), $wallpapers[$index].Name)
        }
        $defaultIndex = 1
        for ($index = 0; $index -lt $wallpapers.Count; $index++) {
            if ($wallpapers[$index].Name -ieq 'default.jpg') { $defaultIndex = $index + 1 }
        }
        do {
            $answer = Read-Host "Tapeta (Enter = $defaultIndex)"
            if ([string]::IsNullOrWhiteSpace($answer)) { $answer = [string]$defaultIndex }
            $wallpaperIndex = -1
            $valid = [int]::TryParse($answer, [ref]$wallpaperIndex) -and
                $wallpaperIndex -ge 0 -and $wallpaperIndex -le $wallpapers.Count
        } while (-not $valid)
        if ($wallpaperIndex -gt 0) {
            $selection['WallpaperPath'] = $wallpapers[$wallpaperIndex - 1].Path
        }
        elseif ($selection.ContainsKey('SetWallpaper')) { exit 3 }
    }

    $logDirectory = Join-Path (Join-Path $repositoryRoot 'Logs') $env:COMPUTERNAME
    $logDirectory = Join-Path $logDirectory ((Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $selection['LogPath'] = $logDirectory
    $selection['Language'] = 'pl-PL'
    $selection['UsbMode'] = $true
    $selection['UsbUserSid'] = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value

    $arguments = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File',
        (ConvertTo-UsbProcessArgument (Join-Path $repositoryRoot 'Win11Debloat.ps1')))
    foreach ($parameterName in $selection.Keys) {
        $arguments += "-$parameterName"
        if ($selection[$parameterName] -isnot [bool]) {
            $arguments += ConvertTo-UsbProcessArgument ([string]$selection[$parameterName])
        }
    }
    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $process = Start-Process -FilePath $powerShellPath -ArgumentList ($arguments -join ' ') -Verb RunAs -Wait -PassThru
    Write-Host "Logi: $logDirectory"
    if ($process.ExitCode -eq 0) {
        Write-Host 'Zakończono. Sprawdź podsumowanie zmian i uruchom komputer ponownie przed kontrolą.' -ForegroundColor Green
    }
    elseif ($process.ExitCode -eq 3) {
        Write-Host 'Anulowano. Nie traktuj tego uruchomienia jako ukończonego przygotowania.' -ForegroundColor Yellow
    }
    else {
        Write-Warning "Uruchomienie zakończone kodem $($process.ExitCode). Sprawdź log przed przygotowaniem kolejnego komputera."
    }
    exit $process.ExitCode
}
catch {
    Write-Host "Nie udało się uruchomić Win11Debloat: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
