# MainWindow-Navigation.ps1
# Wizard navigation helpers: tab navigation buttons and progress indicators.

function Update-NavigationButtons {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.TabControl]$TabControl
    )

    $currentIndex = $TabControl.SelectedIndex
    $totalTabs = $TabControl.Items.Count

    $previousBtn = $Window.FindName('PreviousBtn')
    $nextBtn = $Window.FindName('NextBtn')

    $homeIndex = 0
    $overviewIndex = $totalTabs - 1

    # Navigation button visibility
    if ($currentIndex -eq $homeIndex) {
        $nextBtn.Visibility = 'Collapsed'
        $previousBtn.Visibility = 'Collapsed'
    }
    elseif ($currentIndex -eq $overviewIndex) {
        $nextBtn.Visibility = 'Collapsed'
        $previousBtn.Visibility = 'Visible'
    }
    else {
        $nextBtn.Visibility = 'Visible'
        $previousBtn.Visibility = 'Visible'
    }

    # Update progress indicators
    # Tab indices: 0=Home, 1=App Removal, 2=Tweaks, 3=Deployment Settings
    $progressIndicator1 = $Window.FindName('ProgressIndicator1') # App Removal
    $progressIndicator2 = $Window.FindName('ProgressIndicator2') # Tweaks
    $progressIndicator3 = $Window.FindName('ProgressIndicator3') # Deployment Settings
    $bottomNavGrid = $Window.FindName('BottomNavGrid')

    # Hide bottom navigation on home page
    if ($currentIndex -eq 0) {
        $bottomNavGrid.Visibility = 'Collapsed'
    }
    else {
        $bottomNavGrid.Visibility = 'Visible'
    }

    # Update indicator colors based on current tab
    # Indicator 1 (App Removal) - tab index 1
    if ($currentIndex -ge 1) {
        $progressIndicator1.Fill = $Window.Resources['ProgressActiveColor']
    }
    else {
        $progressIndicator1.Fill = $Window.Resources['ProgressInactiveColor']
    }

    # Indicator 2 (Tweaks) - tab index 2
    if ($currentIndex -ge 2) {
        $progressIndicator2.Fill = $Window.Resources['ProgressActiveColor']
    }
    else {
        $progressIndicator2.Fill = $Window.Resources['ProgressInactiveColor']
    }

    # Indicator 3 (Deployment Settings) - tab index 3
    if ($currentIndex -ge 3) {
        $progressIndicator3.Fill = $Window.Resources['ProgressActiveColor']
    }
    else {
        $progressIndicator3.Fill = $Window.Resources['ProgressInactiveColor']
    }
}
