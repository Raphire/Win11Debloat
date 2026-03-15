function Hide-Bubble {
    param (
        [Parameter(Mandatory=$false)]
        [switch]$Immediate
    )

    if ($script:BubbleTimer) {
        $script:BubbleTimer.Stop()
        $script:BubbleTimer = $null
    }

    if (-not $script:BubblePopup) { return }

    if ($Immediate -or -not $script:BubblePopup.Child) {
        $script:BubblePopup.IsOpen = $false
        $script:BubblePopup = $null
        $script:BubbleIsClosing = $false
        return
    }

    if ($script:BubbleIsClosing) { return }
    $script:BubbleIsClosing = $true

    $bubblePanel = $script:BubblePopup.Child
    $fadeOut = New-Object System.Windows.Media.Animation.DoubleAnimation
    $fadeOut.From = [double]$bubblePanel.Opacity
    $fadeOut.To = 0
    $fadeOut.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(220))
    $fadeOut.Add_Completed({
        if ($script:BubblePopup) {
            $script:BubblePopup.IsOpen = $false
            $script:BubblePopup = $null
        }
        $script:BubbleIsClosing = $false
    })

    $bubblePanel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeOut)
}

function Show-Bubble {
    param (
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.Control]$TargetControl,

        [Parameter(Mandatory=$false)]
        [string]$Message = 'View the selected changes here',

        [Parameter(Mandatory=$false)]
        [int]$DurationSeconds = 5
    )

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    if (-not $TargetControl) { return }

    Hide-Bubble -Immediate

    $xaml = Get-Content -Path $script:BubbleHintSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $bubblePanel = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    $bubbleText = $bubblePanel.FindName('BubbleText')
    if ($bubbleText) {
        $bubbleText.Text = $Message
    }

    $bubblePanel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $bubblePanel.Opacity = 0

    $popup = New-Object System.Windows.Controls.Primitives.Popup
    $popup.AllowsTransparency = $true
    $popup.PopupAnimation = 'None'
    $popup.StaysOpen = $true
    $popup.PlacementTarget = $TargetControl
    $popup.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Top
    $popup.VerticalOffset = -1
    $popup.Child = $bubblePanel

    $popup.Add_Opened({
        param($sender, $e)

        if (-not $sender) { return }
        $panel = $sender.Child
        $target = $sender.PlacementTarget
        if (-not $panel -or -not $target) { return }

        $panel.Measure([System.Windows.Size]::new([double]::PositiveInfinity, [double]::PositiveInfinity))
        $bubbleWidth = $panel.DesiredSize.Width
        $targetWidth = $target.ActualWidth
        $sender.HorizontalOffset = ($targetWidth - $bubbleWidth) / 2

        $fadeIn = New-Object System.Windows.Media.Animation.DoubleAnimation
        $fadeIn.From = 0
        $fadeIn.To = 1
        $fadeIn.BeginTime = [TimeSpan]::FromMilliseconds(30)
        $fadeIn.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(320))
        $panel.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeIn)
    })

    $script:BubbleIsClosing = $false
    $script:BubblePopup = $popup
    $script:BubblePopup.IsOpen = $true

    $script:BubbleTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:BubbleTimer.Interval = [TimeSpan]::FromSeconds([Math]::Max(1, $DurationSeconds))
    $script:BubbleTimer.Add_Tick({
        Hide-Bubble
    })
    $script:BubbleTimer.Start()
}
