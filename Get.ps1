param (
    [switch]$Silent,
    [switch]$Verbose,
    [switch]$Sysprep,
    [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RemoveApps, 
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$TaskbarAlignLeft,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableWidgets,
    [switch]$HideWidgets,
    [switch]$DisableChat,
    [switch]$HideChat,
    [switch]$ClearStart,
    [switch]$ClearStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)

# Show error if current powershell environment does not have LanguageMode set to FullLanguage 
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
   Write-Host "Erro: Win11Debloat nao pode ser executado em seu sistema. A execucao do Powershell eh restrita por politicas de seguranca" -ForegroundColor Red
   Write-Output ""
   Write-Output "Pressione enter para sair..."
   Read-Host | Out-Null
   Exit
}

Clear-Host
Write-Output "-------------------------------------------------------------------------------------------"
Write-Output " Win11Debloat Script - Obter"
Write-Output "-------------------------------------------------------------------------------------------"

Write-Output "> Baixando Win11Debloat..."

# Download latest version of Win11Debloat from github as zip archive
Invoke-WebRequest https://github.com/JoaoCapoAlm/Win11Debloat_ptBR/archive/master.zip -OutFile "$env:TEMP/win11debloat-temp.zip"

# Remove old script folder if it exists, except for CustomAppsList and SavedSettings files
if (Test-Path "$env:TEMP/Win11Debloat_ptBR/Win11Debloat-master") {
    Write-Output ""
    Write-Output "> Limpando a pasta Win11Debloat antiga..."
    Get-ChildItem -Path "$env:TEMP/Win11Debloat_ptBR/Win11Debloat-master" -Exclude CustomAppsList,SavedSettings | Remove-Item -Recurse -Force
}

Write-Output ""
Write-Output "> Desempacotando..."

# Unzip archive to Win11Debloat folder
Expand-Archive "$env:TEMP/win11debloat-temp.zip" "$env:TEMP/Win11Debloat_ptBR"

# Remove archive
Remove-Item "$env:TEMP/win11debloat-temp.zip"

# Make list of arguments to pass on to the script
$arguments = $($PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key)"})

Write-Output ""
Write-Output "> Executando Win11Debloat_ptBR..."

# Run Win11Debloat script with the provided arguments
$debloatProcess = Start-Process powershell.exe -PassThru -ArgumentList "-executionpolicy bypass -File $env:TEMP\Win11Debloat_ptBR\Win11Debloat-master\Win11Debloat.ps1 $arguments" -Verb RunAs

# Wait for the process to finish before continuing
if ($null -ne $debloatProcess) {
    $debloatProcess.WaitForExit()
}

# Remove all remaining script files, except for CustomAppsList and SavedSettings files
if (Test-Path "$env:TEMP/Win11Debloat_ptBR/Win11Debloat-master") {
    Write-Output ""
    Write-Output "> Limpando..."

    # Cleanup, remove Win11Debloat directory
    Get-ChildItem -Path "$env:TEMP/Win11Debloat_ptBR/Win11Debloat-master" -Exclude CustomAppsList,SavedSettings | Remove-Item -Recurse -Force
}

Write-Output ""
