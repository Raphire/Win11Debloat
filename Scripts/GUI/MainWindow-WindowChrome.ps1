# MainWindow-WindowChrome.ps1
# Window sizing, DPI-aware coordinate conversion, maximized-window taskbar-constraint helpers, and UI animations.

function Register-MaximizedWindowHelper {
    if (-not ([System.Management.Automation.PSTypeName]'Win11Debloat.MaximizedWindowHelper').Type) {
        Add-Type -Namespace Win11Debloat -Name MaximizedWindowHelper `
            -ReferencedAssemblies 'PresentationFramework','System.Windows.Forms','System.Drawing' `
            -MemberDefinition @'
            [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
            private struct MINMAXINFO {
                public POINT ptReserved, ptMaxSize, ptMaxPosition, ptMinTrackSize, ptMaxTrackSize;
            }
            [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
            private struct POINT { public int x, y; }

            [System.Runtime.InteropServices.DllImport("user32.dll")]
            private static extern System.IntPtr MonitorFromWindow(System.IntPtr hwnd, uint dwFlags);

            [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto)]
            private static extern bool GetMonitorInfo(System.IntPtr hMonitor, ref MONITORINFO lpmi);

            [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
            private struct RECT {
                public int Left, Top, Right, Bottom;
            }

            [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
            private struct MONITORINFO {
                public int cbSize;
                public RECT rcMonitor;
                public RECT rcWork;
                public uint dwFlags;
            }

            public static System.IntPtr WmGetMinMaxInfoHook(
                System.IntPtr hwnd, int msg, System.IntPtr wParam, System.IntPtr lParam, ref bool handled) {
                if (msg == 0x0024) { // WM_GETMINMAXINFO
                    var mmi = (MINMAXINFO)System.Runtime.InteropServices.Marshal.PtrToStructure(
                        lParam, typeof(MINMAXINFO));

                    const uint MONITOR_DEFAULTTONEAREST = 0x00000002;
                    var monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
                    var monitorInfo = new MONITORINFO();
                    monitorInfo.cbSize = System.Runtime.InteropServices.Marshal.SizeOf(typeof(MONITORINFO));

                    if (monitor != System.IntPtr.Zero && GetMonitorInfo(monitor, ref monitorInfo)) {
                        mmi.ptMaxPosition.x = monitorInfo.rcWork.Left - monitorInfo.rcMonitor.Left;
                        mmi.ptMaxPosition.y = monitorInfo.rcWork.Top - monitorInfo.rcMonitor.Top;
                        mmi.ptMaxSize.x     = monitorInfo.rcWork.Right - monitorInfo.rcWork.Left;
                        mmi.ptMaxSize.y     = monitorInfo.rcWork.Bottom - monitorInfo.rcWork.Top;
                    }
                    else {
                        var screen = System.Windows.Forms.Screen.FromHandle(hwnd);
                        var wa = screen.WorkingArea;
                        var bounds = screen.Bounds;
                        mmi.ptMaxPosition.x = wa.Left - bounds.Left;
                        mmi.ptMaxPosition.y = wa.Top - bounds.Top;
                        mmi.ptMaxSize.x     = wa.Width;
                        mmi.ptMaxSize.y     = wa.Height;
                    }

                    System.Runtime.InteropServices.Marshal.StructureToPtr(mmi, lParam, true);
                }
                return System.IntPtr.Zero;
            }
'@
    }
}

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
    $chrome = [System.Windows.Shell.WindowChrome]::GetWindowChrome($Window)

    if ($Window.WindowState -eq $windowStateMaximized) {
        $MainBorder.Margin = [System.Windows.Thickness]::new(0)
        $MainBorder.BorderThickness = [System.Windows.Thickness]::new(0)
        $MainBorder.CornerRadius = [System.Windows.CornerRadius]::new(0)
        $MainBorder.Effect = $null
        $TitleBarBackground.CornerRadius = [System.Windows.CornerRadius]::new(0)
        # Zero out resize borders when maximized so the entire title bar row is draggable
        if ($chrome) { $chrome.ResizeBorderThickness = [System.Windows.Thickness]::new(0) }
    }
    else {
        $MainBorder.Margin = [System.Windows.Thickness]::new(0)
        $MainBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        $MainBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $MainBorder.Effect = $NormalWindowShadow
        $TitleBarBackground.CornerRadius = [System.Windows.CornerRadius]::new(8, 8, 0, 0)
        if ($chrome) { $chrome.ResizeBorderThickness = [System.Windows.Thickness]::new(5) }
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
