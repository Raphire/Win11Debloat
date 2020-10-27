Write-Output "Attempting to launch script with admin privileges..."

PowerShell -NoProfile -ExecutionPolicy Unrestricted -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Unrestricted -File ""$PSScriptRoot\Win10Debloat.ps1""' -Verb RunAs}";