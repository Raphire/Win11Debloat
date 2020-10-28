$remove_apps = Read-Host "Do you want to remove the pre-installed apps? (y/n)"

$disable_onedrive = Read-Host "Do you want to disable the onedrive folder in windows explorer? (y/n)"

$disable_3d_objects = Read-Host "Do you want to disable the 3D objects folder in windows explorer? (y/n)"

$disable_music = Read-Host "Do you want to disable the music folder in windows explorer? (y/n)"

$disable_context = Read-Host "Do you want to remove the contextmenu entries for: Share, Give access to and Include in library? (y/n)"

Write-Output ""

if ($remove_apps -eq 'y') {
    Write-Output "Uninstalling pre-installed applications..."

    $apps = @(
        "*Microsoft.GetHelp*"
        "*Microsoft.Getstarted*"
        "*Microsoft.WindowsFeedbackHub*"
        "*Microsoft.MicrosoftOfficeHub*"
        "*Microsoft.Office.OneNote*"
        "*Microsoft.OneConnect*"
        "*Microsoft.Messaging*"
        "*Microsoft.SkypeApp*"
        "*Microsoft.MixedReality.Portal*"
        "*Microsoft.3DBuilder*"
        "*Microsoft.Microsoft3DViewer*"
        "*Microsoft.Print3D*"
        "*Microsoft.MicrosoftStickyNotes*"
        "*Microsoft.WindowsSoundRecorder*"
        "*Microsoft.ZuneMusic*"
        "*Microsoft.ZuneVideo*"
        "*Microsoft.BingNews*"
        "*Microsoft.BingFinance*"
        "*Microsoft.BingSports*"
        "*Microsoft.BingWeather*"
        "*Microsoft.549981C3F5F10*"
        "*Microsoft.MicrosoftSolitaireCollection*"
        "*king.com.BubbleWitch3Saga*"
        "*king.com.CandyCrushSodaSaga*"
        "*king.com.CandyCrushSaga*"
        "*Microsoft.Asphalt8Airborne*"
    )

    foreach ($app in $apps) {
        Write-Output "Attempting to remove $app"

        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage
    }
}

if ($disable_onedrive -eq 'y') {
    Write-Output "Disabling the onedrive folder in windows explorer..."

    regedit /s $PSScriptRoot\Regfiles\Disable_Onedrive_Folder.reg
}


if ($disable_3d_objects -eq 'y') {
    Write-Output "Disabling the 3D objects folder in windows explorer..."

    regedit /s $PSScriptRoot\Regfiles\Disable_3D_Objects_Folder.reg
}

if ($disable_music -eq 'y') {
    Write-Output "Disabling the music folder in windows explorer..."

    regedit /s $PSScriptRoot\Regfiles\Disable_Music_folder.reg
}

if ($disable_context -eq 'y') {
    Write-Output "Removing contextmenu entries for: Share, Include in library & Give access..."

    regedit /s $PSScriptRoot\Regfiles\Remove_Share_from_context_menu.reg
    regedit /s $PSScriptRoot\Regfiles\Remove_Include_in_library_from_context_menu.reg
    regedit /s $PSScriptRoot\Regfiles\Remove_Give_access_to_context_menu.reg
}

Write-Output ""
Write-Output "Script completed! You may need to restart to apply all changes."
Write-Output "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")