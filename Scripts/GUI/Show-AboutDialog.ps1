function Show-AboutDialog {
    param (
        [Parameter(Mandatory=$false)]
        [System.Windows.Window]$Owner = $null
    )
    
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null
    
    $usesDarkMode = GetSystemUsesDarkMode
    
    # Determine owner window
    $ownerWindow = if ($Owner) { $Owner } else { $script:GuiWindow }
    
    # Show overlay if owner window exists
    $overlay = $null
    if ($ownerWindow) {
        try {
            $overlay = $ownerWindow.FindName('ModalOverlay')
            if ($overlay) {
                $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Visible' })
            }
        }
        catch { }
    }
    
    # Load XAML from file
    $xaml = Get-Content -Path $script:AboutWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $aboutWindow = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }
    
    # Set owner to owner window if it exists
    if ($ownerWindow) {
        try {
            $aboutWindow.Owner = $ownerWindow
        }
        catch { }
    }
    
    # Apply theme resources
    SetWindowThemeResources -window $aboutWindow -usesDarkMode $usesDarkMode
    
    # Get UI elements
    $titleBar = $aboutWindow.FindName('TitleBar')
    $versionText = $aboutWindow.FindName('VersionText')
    $projectLink = $aboutWindow.FindName('ProjectLink')
    $kofiLink = $aboutWindow.FindName('KofiLink')
    $closeButton = $aboutWindow.FindName('CloseButton')
    
    # Set version
    $versionText.Text = $script:Version
    
    # Title bar drag to move window
    $titleBar.Add_MouseLeftButtonDown({
        $aboutWindow.DragMove()
    })
    
    # Project link click handler
    $projectLink.Add_MouseLeftButtonDown({
        Start-Process "https://github.com/Raphire/Win11Debloat"
    })
    
    # Ko-fi link click handler
    $kofiLink.Add_MouseLeftButtonDown({
        Start-Process "https://ko-fi.com/raphire"
    })
    
    # Close button handler
    $closeButton.Add_Click({
        $aboutWindow.Close()
    })
    
    # Handle Escape key to close
    $aboutWindow.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -eq 'Escape') {
            $aboutWindow.Close()
        }
    })
    
    # Show dialog
    $aboutWindow.ShowDialog() | Out-Null
    
    # Hide overlay after dialog closes
    if ($overlay) {
        try {
            $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
        }
        catch { }
    }
}