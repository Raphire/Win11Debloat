# Shows a Windows 11 styled custom message box
function Show-MessageBox {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$Title = "Win11Debloat",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('OK', 'OKCancel', 'YesNo', 'YesNoCancel')]
        [string]$Button = 'OK',
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('None', 'Information', 'Warning', 'Error', 'Question')]
        [string]$Icon = 'None',
        
        [Parameter(Mandatory=$false)]
        [System.Windows.Window]$Owner = $null
    )
    
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null
    
    $usesDarkMode = GetSystemUsesDarkMode
    
    # Determine owner window - use provided Owner, or fall back to main GUI window
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
    $xaml = Get-Content -Path $script:MessageBoxSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $msgWindow = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }
    
    # Set owner to owner window if it exists
    if ($ownerWindow) {
        try {
            $msgWindow.Owner = $ownerWindow
        }
        catch { }
    }
    
    # Apply theme resources
    SetWindowThemeResources -window $msgWindow -usesDarkMode $usesDarkMode
    
    # Get UI elements
    $titleText = $msgWindow.FindName('TitleText')
    $messageText = $msgWindow.FindName('MessageText')
    $iconText = $msgWindow.FindName('IconText')
    $button1 = $msgWindow.FindName('Button1')
    $button2 = $msgWindow.FindName('Button2')
    $titleBar = $msgWindow.FindName('TitleBar')
    
    # Set title and message
    $titleText.Text = $Title
    $messageText.Text = $Message
    
    # Configure icon
    switch ($Icon) {
        'Information' { 
            $iconText.Text = [char]0xE946
            $iconText.Foreground = $msgWindow.FindResource('InformationIconColor')
            $iconText.Visibility = 'Visible'
        }
        'Warning' { 
            $iconText.Text = [char]0xE7BA
            $iconText.Foreground = $msgWindow.FindResource('WarningIconColor')
            $iconText.Visibility = 'Visible'
        }
        'Error' { 
            $iconText.Text = [char]0xEA39
            $iconText.Foreground = $msgWindow.FindResource('ErrorIconColor')
            $iconText.Visibility = 'Visible'
        }
        'Question' { 
            $iconText.Text = [char]0xE897
            $iconText.Foreground = $msgWindow.FindResource('QuestionIconColor')
            $iconText.Visibility = 'Visible'
        }
        default {
            $iconText.Visibility = 'Collapsed'
        }
    }
    
    # Configure buttons - store result in window's Tag property
    switch ($Button) {
        'OK' {
            $button1.Content = 'OK'
            $button1.Add_Click({ $msgWindow.Tag = 'OK'; $msgWindow.Close() })
            $button2.Visibility = 'Collapsed'
        }
        'OKCancel' {
            $button1.Content = 'OK'
            $button2.Content = 'Cancel'
            $button1.Add_Click({ $msgWindow.Tag = 'OK'; $msgWindow.Close() })
            $button2.Add_Click({ $msgWindow.Tag = 'Cancel'; $msgWindow.Close() })
            $button2.Visibility = 'Visible'
        }
        'YesNo' {
            $button1.Content = 'Yes'
            $button2.Content = 'No'
            $button1.Add_Click({ $msgWindow.Tag = 'Yes'; $msgWindow.Close() })
            $button2.Add_Click({ $msgWindow.Tag = 'No'; $msgWindow.Close() })
            $button2.Visibility = 'Visible'
        }
        'YesNoCancel' {
            $button1.Content = 'Yes'
            $button2.Content = 'No'
            $button1.Add_Click({ $msgWindow.Tag = 'Yes'; $msgWindow.Close() })
            $button2.Add_Click({ $msgWindow.Tag = 'No'; $msgWindow.Close() })
            $button2.Visibility = 'Visible'
        }
    }
    
    # Title bar drag to move window
    $titleBar.Add_MouseLeftButtonDown({
        $msgWindow.DragMove()
    })
    
    # Handle Escape key to close
    $msgWindow.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -eq 'Escape') {
            if ($Button -eq 'OK') {
                $msgWindow.Tag = 'OK'
            } else {
                $msgWindow.Tag = 'Cancel'
            }
            $msgWindow.Close()
        }
    })
    
    # Show dialog and return result from Tag
    $msgWindow.ShowDialog() | Out-Null
    
    # Hide overlay after dialog closes
    if ($overlay) {
        try {
            $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
        }
        catch { }
    }
    
    return $msgWindow.Tag
}
