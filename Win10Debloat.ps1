Write-Output "-------------------------------------------------------------------------------------------"
Write-Output "Win10Debloat Script"
Write-Output "-------------------------------------------------------------------------------------------"

$remove_apps = Read-Host "Remove the pre-installed windows 10 apps? (y/n)"

$disable_onedrive = Read-Host "Hide the onedrive folder in windows explorer? (y/n)"

$disable_3d_objects = Read-Host "Hide the 3D objects folder in windows explorer? (y/n)"

$disable_music = Read-Host "Hide the music folder in windows explorer? (y/n)"

$disable_bing_searches = Read-Host "Disable bing in windows search? (y/n)"

$disable_context = Read-Host "Disable the contextmenu entries for: Share, Give access to and Include in library? (y/n)"

Write-Output ""

if ($remove_apps -eq 'y') {
    Write-Output "> Removing pre-installed windows 10 apps..."

    $apps = @(
        # These apps will be uninstalled by default:
        #
        # If you wish to KEEP any of the apps below simply add a # character
        # in front of the specific app in the list below.
        "*Microsoft.GetHelp*"
        "*Microsoft.Getstarted*"
        "*Microsoft.WindowsFeedbackHub*"
        "*Microsoft.BingNews*"
        "*Microsoft.BingFinance*"
        "*Microsoft.BingSports*"
        "*Microsoft.BingWeather*"
        "*Microsoft.BingTranslator*"
        "*Microsoft.MicrosoftOfficeHub*"
        "*Microsoft.Office.OneNote*"
        "*Microsoft.MicrosoftStickyNotes*"
        "*Microsoft.SkypeApp*"
        "*Microsoft.OneConnect*"
        "*Microsoft.Messaging*"
        "*Microsoft.WindowsSoundRecorder*"
        "*Microsoft.ZuneMusic*"
        "*Microsoft.ZuneVideo*"
        "*Microsoft.MixedReality.Portal*"
        "*Microsoft.3DBuilder*"
        "*Microsoft.Microsoft3DViewer*"
        "*Microsoft.Print3D*"
        "*Microsoft.549981C3F5F10*"   #Cortana app
        "*Microsoft.MicrosoftSolitaireCollection*"
        "*Microsoft.Asphalt8Airborne*"
        "*king.com.BubbleWitch3Saga*"
        "*king.com.CandyCrushSodaSaga*"
        "*king.com.CandyCrushSaga*"
        


        # These apps will NOT be uninstalled by default:
        # 
        # If you wish to REMOVE any of the apps below simply remove the #
        # character in front of the specific app in the list below.
        #"*Microsoft.WindowsStore*"   # NOTE: This app cannot be reinstalled!
        #"*Microsoft.WindowsCalculator*"
        #"*Microsoft.Windows.Photos*"
        #"*Microsoft.WindowsCamera*"
        #"*Microsoft.WindowsAlarms*"
        #"*Microsoft.WindowsMaps*"
        #"*microsoft.windowscommunicationsapps*"   # Mail & Calendar
        #"*Microsoft.People*"
        #"*Microsoft.ScreenSketch*"
        #"*Microsoft.MSPaint*"   # Paint 3D
        #"*Microsoft.YourPhone*"
        #"*Microsoft.XboxApp*"
        #"*Microsoft.XboxGameOverlay*"
        #"*Microsoft.XboxGamingOverlay*"
        #"*Microsoft.XboxSpeechToTextOverlay*"
    )

    foreach ($app in $apps) {
        Write-Output "Attempting to remove $app"

        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage
    }
}

if ($disable_onedrive -eq 'y') {
    Write-Output "> Hiding the onedrive folder in windows explorer..."

    regedit /s $PSScriptRoot\Regfiles\Hide_Onedrive_Folder.reg
}


if ($disable_3d_objects -eq 'y') {
    Write-Output "> Hiding the 3D objects folder in windows explorer..."

    regedit /s $PSScriptRoot\Regfiles\Hide_3D_Objects_Folder.reg
}

if ($disable_music -eq 'y') {
    Write-Output "> Hiding the music folder in windows explorer..."

    regedit /s $PSScriptRoot\Regfiles\Hide_Music_folder.reg
}

if ($disable_bing_searches -eq 'y') {
    Write-Output "> Disabling bing in windows search..."

    regedit /s $PSScriptRoot\Regfiles\Disable_Bing_Searches.reg
}

if ($disable_context -eq 'y') {
    Write-Output "> Disabling contextmenu entries for: Share, Include in library & Give access..."

    regedit /s $PSScriptRoot\Regfiles\Disable_Share_from_context_menu.reg
    regedit /s $PSScriptRoot\Regfiles\Disable_Include_in_library_from_context_menu.reg
    regedit /s $PSScriptRoot\Regfiles\Disable_Give_access_to_context_menu.reg
}

Write-Output ""
Write-Output "Script completed! Please restart your PC to make sure all changes are properly applied."
Write-Output ""
Write-Output "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")