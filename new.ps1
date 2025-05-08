# Remove Microsoft Store from Taskbar
$appname = "Microsoft Store" 
((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq $appname}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} | %{$_.DoIt(); $exec = $true}
write-host
Write-Host 'Removed Microsoft Store from Taskbar.'

### Turn Off OneDrive in Settings>Apps>Startup ###

# By default, StartupApproved does not exist
$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved"
if (-Not (Test-Path -Path $key)){
    New-Item $key | Out-Null
}

# By default, Run does not exist
$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
if (-Not (Test-Path -Path $key)){
    New-Item $key | Out-Null
}

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name "OneDrive" -Value ([byte[]](0x01,0x00,0x00,0x00,0xcd,0xc0,0x1c,0xdc,0x9e,0x00,0xdb,0x01))
write-host
Write-Host 'Turned Off OneDrive in Settings>Apps>Startup.'
