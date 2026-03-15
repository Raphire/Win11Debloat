# Processes all pending WPF window messages (input, render, etc.) to keep the UI responsive
# during long-running operations on the UI thread. Equivalent to Application.DoEvents().
function DoEvents {
    if (-not $script:GuiWindow) { return }
    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    $null = [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [System.Windows.Threading.DispatcherOperationCallback]{
            param($f)
            $f.Continue = $false
            return $null
        },
        $frame
    )
    $null = [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}
