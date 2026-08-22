<#
    .SYNOPSIS
        Forcefully uninstalls Microsoft Edge and removes its leftover shortcuts and autostart entries.

    .OUTPUTS
        System.Boolean. $true when Edge is uninstalled and cleanup succeeds; otherwise $false.
#>
function Invoke-ForceRemoveEdge {
    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Forcefully uninstall Microsoft Edge" -ForegroundColor Cyan
        return $true
    }

    try {
        Write-Host "> Forcefully uninstalling Microsoft Edge..."

        $regView = [Microsoft.Win32.RegistryView]::Registry32
        $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
        $edgeUpdateKey = $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev')
        $edgeUpdateKey.SetValue('AllowUninstall', '')

        # Create stub (This somehow allows uninstalling Edge)
        $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
        New-Item $edgeStub -ItemType Directory -Force -ErrorAction Stop | Out-Null
        New-Item "$edgeStub\MicrosoftEdge.exe" -ItemType File -Force -ErrorAction Stop | Out-Null

    # Remove edge
        $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
        if ($null -eq $uninstallRegKey) {
            Write-Host "Unable to forcefully uninstall Microsoft Edge, uninstaller could not be found" -ForegroundColor Red
            return $false
        }

        Write-Host "Running uninstaller..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        $exitCode = Invoke-NonBlocking -ScriptBlock {
            param($cmd)
            $process = Start-Process cmd.exe "/c $cmd" -WindowStyle Hidden -Wait -PassThru
            return $process.ExitCode
        } -ArgumentList $uninstallString
        if ($exitCode -ne 0) {
            Write-Warning "Microsoft Edge uninstaller failed with exit code $exitCode."
            return $false
        }

        Write-Host "Removing leftover files..."
        $cleanupSucceeded = $true

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$edgeStub"
        )

        foreach ($path in $edgePaths) {
            if (Test-Path -Path $path) {
                try {
                    Remove-Item -Path $path -Force -Recurse -ErrorAction Stop
                    Write-Host "  Removed $path" -ForegroundColor DarkGray
                }
                catch {
                    Write-Warning "Failed to remove Edge leftover '$path': $($_.Exception.Message)"
                    $cleanupSucceeded = $false
                }
            }
        }

        Write-Host "Cleaning up registry..."
        $registryCleanupSucceeded = $true

        # Remove MS Edge from autostart. Missing values are already-clean state,
        # while failures to inspect or remove an existing value are reported.
        $autostartValues = @(
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C' },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'Microsoft Edge Update' },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C' },
            @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Microsoft Edge Update' }
        )
        foreach ($autostartValue in $autostartValues) {
            if (-not (Remove-EdgeAutostartValue -Path $autostartValue.Path -Name $autostartValue.Name)) {
                $registryCleanupSucceeded = $false
            }
        }

        if (-not $cleanupSucceeded -or -not $registryCleanupSucceeded) {
            Write-Warning "Microsoft Edge was uninstalled, but some leftover files or autostart entries could not be removed."
            return $false
        }

        Write-Host "Microsoft Edge was uninstalled"
        return $true
    }
    catch {
        Write-Warning "Failed to forcefully uninstall Microsoft Edge: $($_.Exception.Message)"
        return $false
    }
    finally {
        if ($edgeUpdateKey) { $edgeUpdateKey.Dispose() }
        if ($uninstallRegKey) { $uninstallRegKey.Dispose() }
        if ($hklm) { $hklm.Dispose() }
    }
}

<#
    .SYNOPSIS
        Removes an Edge autostart registry value when it exists.

    .OUTPUTS
        System.Boolean. $true when the value is absent or removed; $false when inspection or removal fails.
#>
function Remove-EdgeAutostartValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        $properties = Get-ItemProperty -Path $Path -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        return $true
    }
    catch {
        Write-Warning "Failed to inspect Edge autostart entry '$Path\$Name': $($_.Exception.Message)"
        return $false
    }

    if (-not $properties.PSObject.Properties[$Name]) {
        return $true
    }

    try {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Failed to remove Edge autostart entry '$Path\$Name': $($_.Exception.Message)"
        return $false
    }
}
