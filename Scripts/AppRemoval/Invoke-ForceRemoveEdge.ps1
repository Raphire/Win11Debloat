<#
    .SYNOPSIS
        Forcefully uninstalls Microsoft Edge and removes its leftover shortcuts and autostart entries.
#>
function Invoke-ForceRemoveEdge {
    Write-Host "> Forcefully uninstalling Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)

    # Locate the uninstaller first, before making any changes to the system
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    $uninstallString = if ($null -ne $uninstallRegKey) { [string]$uninstallRegKey.GetValue('UninstallString') } else { $null }

    if ([string]::IsNullOrWhiteSpace($uninstallString)) {
        Write-Host "Unable to forcefully uninstall Microsoft Edge, uninstaller could not be found" -ForegroundColor Red
        return
    }

    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (This somehow allows uninstalling Edge)
    # Only create it when the folder doesn't exist yet: on Windows 10 this path is the REAL
    # legacy Edge (EdgeHTML) system package, which must never be created over or deleted.
    # The stub is only removed later if this script created it.
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    $stubCreatedByScript = $false

    if (-not (Test-Path -LiteralPath $edgeStub)) {
        New-Item $edgeStub -ItemType Directory | Out-Null
        New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null
        $stubCreatedByScript = $true
    }

    try {
        Write-Host "Running uninstaller..."

        # Split the UninstallString into executable and arguments and invoke it directly,
        # instead of interpolating the raw registry value into a cmd.exe command line
        if ($uninstallString -match '^\s*"(?<exe>[^"]+)"\s*(?<args>.*)$') {
            $uninstallExe = $Matches.exe
            $uninstallArgs = $Matches.args
        }
        else {
            $splitParts = $uninstallString.Trim() -split '\s+', 2
            $uninstallExe = $splitParts[0]
            $uninstallArgs = if ($splitParts.Count -gt 1) { $splitParts[1] } else { '' }
        }

        $uninstallArgs = ($uninstallArgs + ' --force-uninstall').Trim()

        Invoke-NonBlocking -ScriptBlock {
            param($exe, $arguments)
            Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -Wait
        } -ArgumentList $uninstallExe, $uninstallArgs

        Write-Host "Removing leftover files..."

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk"
        )

        foreach ($path in $edgePaths) {
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  Removed $path" -ForegroundColor DarkGray
            }
        }

        Write-Host "Cleaning up registry..."

        # Remove MS Edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Host "Microsoft Edge was uninstalled"
    }
    finally {
        # Always remove the stub if this script created it, even when the uninstall failed,
        # so no fake MicrosoftEdge.exe is left behind in SystemApps
        if ($stubCreatedByScript -and (Test-Path -LiteralPath $edgeStub)) {
            Remove-Item -Path $edgeStub -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}
