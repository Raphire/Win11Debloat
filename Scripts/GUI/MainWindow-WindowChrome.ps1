# MainWindow-WindowChrome.ps1
# Window sizing, DPI-aware coordinate conversion, and UI animations.

# Convert screen-pixel coordinates to WPF device-independent pixels (DIP)
function ConvertTo-ScreenPointToDip {
    param(
        [System.Windows.Window]$Window,
        [double]$X,
        [double]$Y
    )

    $source = [System.Windows.PresentationSource]::FromVisual($Window)
    if ($null -eq $source -or $null -eq $source.CompositionTarget) {
        return [System.Windows.Point]::new($X, $Y)
    }

    return $source.CompositionTarget.TransformFromDevice.Transform([System.Windows.Point]::new($X, $Y))
}

# Convert screen-pixel size to WPF device-independent size
function ConvertTo-ScreenPixelsToDip {
    param(
        [System.Windows.Window]$Window,
        [double]$Width,
        [double]$Height
    )

    $topLeft = ConvertTo-ScreenPointToDip -Window $Window -X 0 -Y 0
    $bottomRight = ConvertTo-ScreenPointToDip -Window $Window -X $Width -Y $Height
    return [System.Windows.Size]::new($bottomRight.X - $topLeft.X, $bottomRight.Y - $topLeft.Y)
}

# Get the screen that currently contains the window
function Get-WindowScreen {
    param([System.Windows.Window]$Window)

    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
    if ($hwnd -eq [IntPtr]::Zero) {
        return $null
    }

    return [System.Windows.Forms.Screen]::FromHandle($hwnd)
}

# Update window border/corner chrome when transitioning between Normal and Maximized
function Update-MainWindowChrome {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.Border]$MainBorder,
        [System.Windows.Controls.Border]$TitleBarBackground,
        [object]$NormalWindowShadow
    )

    $windowStateMaximized = [System.Windows.WindowState]::Maximized

    if ($Window.WindowState -eq $windowStateMaximized) {
        $chrome = [System.Windows.Shell.WindowChrome]::GetWindowChrome($Window)
        $resizeBorder = if ($chrome) { $chrome.ResizeBorderThickness } else { [System.Windows.SystemParameters]::WindowResizeBorderThickness }

        # Compute margins using screen bounds vs working area
        $marginLeft = $resizeBorder.Left
        $marginTop = $resizeBorder.Top
        $marginRight = $resizeBorder.Right
        $marginBottom = $resizeBorder.Bottom

        $screen = Get-WindowScreen -Window $Window
        if ($screen) {
            $workTL = ConvertTo-ScreenPointToDip -Window $Window -X $screen.WorkingArea.Left -Y $screen.WorkingArea.Top
            $workSize = ConvertTo-ScreenPixelsToDip -Window $Window -Width $screen.WorkingArea.Width -Height $screen.WorkingArea.Height
            $screenTL = ConvertTo-ScreenPointToDip -Window $Window -X $screen.Bounds.Left -Y $screen.Bounds.Top
            $screenSize = ConvertTo-ScreenPixelsToDip -Window $Window -Width $screen.Bounds.Width -Height $screen.Bounds.Height

            $marginLeft += ($workTL.X - $screenTL.X)
            $marginTop += ($workTL.Y - $screenTL.Y)
            $marginRight += ($screenTL.X + $screenSize.Width) - ($workTL.X + $workSize.Width)
            $marginBottom += ($screenTL.Y + $screenSize.Height) - ($workTL.Y + $workSize.Height)
        }

        $MainBorder.Margin = [System.Windows.Thickness]::new($marginLeft, $marginTop, $marginRight, $marginBottom)
        $MainBorder.BorderThickness = [System.Windows.Thickness]::new(0)
        $MainBorder.CornerRadius = [System.Windows.CornerRadius]::new(0)
        $MainBorder.Effect = $null
        $TitleBarBackground.CornerRadius = [System.Windows.CornerRadius]::new(0)
    }
    else {
        $MainBorder.Margin = [System.Windows.Thickness]::new(0)
        $MainBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        $MainBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $MainBorder.Effect = $NormalWindowShadow
        $TitleBarBackground.CornerRadius = [System.Windows.CornerRadius]::new(8, 8, 0, 0)
    }
}

# Set the initial window size and center on screen (normal state only)
function Set-MainWindowInitialSize {
    param(
        [System.Windows.Window]$Window,
        [double]$InitialNormalMaxWidth = 1400.0
    )

    if ($Window.WindowState -ne [System.Windows.WindowState]::Normal) {
        return
    }

    $screen = Get-WindowScreen -Window $Window
    if ($null -eq $screen) {
        return
    }

    $workingAreaTopLeftDip = ConvertTo-ScreenPointToDip -Window $Window -X $screen.WorkingArea.Left -Y $screen.WorkingArea.Top
    $workingAreaDip = ConvertTo-ScreenPixelsToDip -Window $Window -Width $screen.WorkingArea.Width -Height $screen.WorkingArea.Height
    $Window.Width = [Math]::Min($InitialNormalMaxWidth, $workingAreaDip.Width)
    $Window.Left = $workingAreaTopLeftDip.X + (($workingAreaDip.Width - $Window.Width) / 2)
}

# Update the content grid margin to constrain max content width
function Update-MainWindowContentMargin {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.Grid]$ContentGrid,
        [double]$MaxContentWidth = 1600.0
    )

    $w = $Window.ActualWidth
    if ($w -gt $MaxContentWidth) {
        $gutter = [Math]::Floor(($w - $MaxContentWidth) / 2)
        $ContentGrid.Margin = [System.Windows.Thickness]::new($gutter, 0, $gutter, 0)
    }
    else {
        $ContentGrid.Margin = [System.Windows.Thickness]::new(0)
    }
}

# Vertically center the home content panel
function Update-MainWindowHomeContentPosition {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.Panel]$HomeContentPanel
    )

    if ($HomeContentPanel) {
        $availableHeight = $Window.ActualHeight - 32  # subtract title bar height
        if ($availableHeight -gt 0) {
            $topMargin = ($availableHeight - 584) * 0.5
            $HomeContentPanel.Margin = [System.Windows.Thickness]::new(0, $topMargin, 0, 0)
        }
    }
}

function Start-DropdownArrowAnimation {
    param(
        [System.Windows.Controls.TextBlock]$Arrow,
        [double]$Angle
    )

    if (-not $Arrow) { return }

    $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $animation.To = $Angle
    $animation.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))

    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = 'EaseOut'
    $animation.EasingFunction = $ease

    $Arrow.RenderTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $animation)
}
