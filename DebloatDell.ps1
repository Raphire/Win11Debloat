# Powershell script to remove:

# uninstall msi packages

Write-Host "Uninstalling MSI Packages..."

Uninstall-package -name "Dell SupportAssist" 
Uninstall-package -name "Dell Optimizer"
Uninstall-package -name "Dell Digital Delivery Services"
Uninstall-package -name "MyDell Application Management"
Uninstall-package -name "Dell SupportAssist Remediation"
Uninstall-package -name "Dell SupportAssist OS Recovery Plugin for Dell Update"
Uninstall-package -name "MyDell Customer Connect"
Uninstall-package -name "MyDell Components Installer"
Uninstall-package -name "Dell Core Services"

# uninstall AppxPackages
# to get list of packages, use "Get-AppxPackage | ft name, PackageFullName -AutoSize" and then remove the PackageFullName 

Write-Host ""
Write-Host "Uninstalling AppxPackages Packages..."
Write-Host ""

Write-Host "Removing Dell Digital Delivery."
Remove-AppxPackage -allusers -package "DellInc.DellDigitalDelivery_5.2.0.0_x64__htrsf667h5kn2"
Write-Host "Removing Dell Digital SupportAssist."
Remove-AppxPackage -allusers -package "DellInc.DellSupportAssistforPCs_4.0.15.0_x64__htrsf667h5kn2"

# uninstall program packages
#
#	Microsoft Office 365 - es-es and fr-fr
#	Microsoft OneNote - es-es and fr-fr
#	MyDell, Dell Optimizer, Dell SupportAssist Remediation, Dell SupportAssist OS Recovery Plugin for Del Update

Write-Host "Uninstalling Program Packages..."

# Uninstall MyDell
$DellProduct = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "MyDell" } | Select-Object -Property DisplayName,UninstallString
# Add the parameter "-silent"  which makes a silent uninstall
if ($DellProduct -ne $null)
{
	$uninst = $DellProduct.uninstallstring + " -silent"
	# Start a hidden process (-WindowStyle Hidden) that calls cmd.exe to execute the uninstall command.
	Write-Host "Uninstalling MyDell..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "MyDell not found. No need to uninstall."
}

# Uninstall Dell Optimizer - Note, there is an msi and program version that need to be uninstalled
$DellProduct = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Dell Optimizer" } | Select-Object -Property DisplayName,UninstallString

if ($DellProduct -ne $null)
{
	$uninst = $DellProduct.uninstallstring + " -silent"
	write-host "Uninstalling Dell Optimizer..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Dell Optimizer not found. No need to uninstall."
}

# Uninstall Dell SupportAssist Remediation - Note, there is an msi and program version that need to be uninstalled
$DellProduct = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Dell SupportAssist Remediation" } | Select-Object -Property DisplayName,UninstallString
if ($DellProduct -ne $null)
{
	$uninst = $DellProduct.uninstallstring + " -silent"
	write-host "Uninstalling Dell SupportAssist Remediation..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Dell SupportAssist Remediation not found. No need to uninstall."
}

# Uninstall Dell SupportAssist - Note, there is an msi and program version that need to be uninstalled
$DellProduct = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Dell SupportAssist" } | Select-Object -Property DisplayName,UninstallString
if ($DellProduct -ne $null)
{
	$uninst = $DellProduct.uninstallstring + " -silent"
	write-host "Uninstalling Dell SupportAssist..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Dell SupportAssist not found. No need to uninstall."
}

# Uninstall Dell SupportAssist OS Recovery Plugin for Dell Update - Note, there is an msi and program version that need to be uninstalled
$DellProduct = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Dell SupportAssist OS Recovery Plugin for Dell Update" } | Select-Object -Property DisplayName,UninstallString
if ($DellProduct -ne $null)
{
	$uninst = $DellProduct.uninstallstring + " -silent"
	write-host "Uninstalling Dell SupportAssist OS Recovery Plugin for Dell Update..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Dell SupportAssist OS Recovery Plugin for Dell Update not found. No need to uninstall."
}

# Uninstall Microsoft OneNote - fr-fr
$OneNote = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Microsoft OneNote - fr-fr" } | Select-Object -Property DisplayName,UninstallString
if ($OneNote -ne $null)
{
	$uninst = $OneNote.uninstallstring + " displaylevel=false"
	Write-Host ""
	write-host "Uninstalling Microsoft OneNote fr-fr..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Microsoft OneNote fr-fr not found. No need to uninstall."
}

# Uninstall Microsoft OneNote - es-es
$OneNote = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Microsoft OneNote - es-es" } | Select-Object -Property DisplayName,UninstallString
if ($OneNote -ne $null)
{
	$uninst = $OneNote.uninstallstring + " displaylevel=false"
	Write-Host ""
	write-host "Uninstalling Microsoft OneNote es-es..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Microsoft OneNote es-es not found. No need to uninstall."
}

# Uninstall Microsoft 365 - fr-fr
$M365 = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Microsoft 365 - fr-fr" } | Select-Object -Property DisplayName,UninstallString
if ($M365 -ne $null)
{
	$uninst = $M365.uninstallstring + " displaylevel=false"
	Write-Host ""
	write-host "Uninstalling Microsoft 365 fr-fr..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Microsoft 365 fr-fr not found. No need to uninstall."
}

# Uninstall Microsoft 365 - es-es

$M365 = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -eq "Microsoft 365 - es-es" } | Select-Object -Property DisplayName,UninstallString
if ($M365 -ne $null)
{
	$uninst = $M365.uninstallstring + " displaylevel=false"
	Write-Host ""
	write-host "Uninstalling Microsoft 365 es-es..."
	start-process -WindowStyle Hidden cmd.exe -ArgumentList '/c', $uninst -Wait -PassThru
}
else
{
	Write-Host "Microsoft 365 es-es not found. No need to uninstall."
}


Write-Host -NoNewLine 'Script finished. Press any key to exit...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
