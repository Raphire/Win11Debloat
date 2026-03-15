function Show-ApplyModal {
    param (
        [Parameter(Mandatory=$false)]
        [System.Windows.Window]$Owner = $null,
        [Parameter(Mandatory=$false)]
        [bool]$RestartExplorer = $false
    )
    
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    # P/Invoke helpers for forcing focus back after Explorer restart
    if (-not ([System.Management.Automation.PSTypeName]'Win11Debloat.FocusHelper').Type) {
        Add-Type -Namespace Win11Debloat -Name FocusHelper -MemberDefinition @'
            [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
            [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
            [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
            [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
            [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();

            public static void ForceActivate(IntPtr hwnd) {
                IntPtr fg = GetForegroundWindow();
                uint fgThread = GetWindowThreadProcessId(fg, IntPtr.Zero);
                uint myThread = GetCurrentThreadId();
                if (fgThread != myThread) AttachThreadInput(myThread, fgThread, true);
                SetForegroundWindow(hwnd);
                if (fgThread != myThread) AttachThreadInput(myThread, fgThread, false);
            }
'@
    }
    
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
    $xaml = Get-Content -Path $script:ApplyChangesWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $applyWindow = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }
    
    # Set owner to owner window if it exists
    if ($ownerWindow) {
        try {
            $applyWindow.Owner = $ownerWindow
        }
        catch { }
    }
    
    # Apply theme resources
    SetWindowThemeResources -window $applyWindow -usesDarkMode $usesDarkMode
    
    # Get UI elements
    $script:ApplyInProgressPanel = $applyWindow.FindName('ApplyInProgressPanel')
    $script:ApplyCompletionPanel = $applyWindow.FindName('ApplyCompletionPanel')
    $script:ApplyStepNameEl = $applyWindow.FindName('ApplyStepName')
    $script:ApplyStepCounterEl = $applyWindow.FindName('ApplyStepCounter')
    $script:ApplyProgressBarEl = $applyWindow.FindName('ApplyProgressBar')
    $script:ApplyCompletionTitleEl = $applyWindow.FindName('ApplyCompletionTitle')
    $script:ApplyCompletionMessageEl = $applyWindow.FindName('ApplyCompletionMessage')
    $script:ApplyCompletionIconEl = $applyWindow.FindName('ApplyCompletionIcon')
    $applyRebootPanel = $applyWindow.FindName('ApplyRebootPanel')
    $applyRebootList = $applyWindow.FindName('ApplyRebootList')
    $applyCloseBtn = $applyWindow.FindName('ApplyCloseBtn')
    $applyKofiBtn = $applyWindow.FindName('ApplyKofiBtn')
    $applyCancelBtn = $applyWindow.FindName('ApplyCancelBtn')
    
    # Initialize in-progress state
    $script:ApplyInProgressPanel.Visibility = 'Visible'
    $script:ApplyCompletionPanel.Visibility = 'Collapsed'
    $script:ApplyStepNameEl.Text = "Preparing..."
    $script:ApplyStepCounterEl.Text = "Preparing..."
    $script:ApplyProgressBarEl.Value = 0
    $script:ApplyModalInErrorState = $false
    
    # Set up progress callback for ExecuteAllChanges
    $script:ApplyProgressCallback = {
        param($currentStep, $totalSteps, $stepName)
        $script:ApplyStepNameEl.Text = $stepName
        $script:ApplyStepCounterEl.Text = "Step $currentStep of $totalSteps"
        # Store current step/total in Tag properties for sub-step interpolation
        $script:ApplyStepCounterEl.Tag = $currentStep
        $script:ApplyProgressBarEl.Tag = $totalSteps
        # Show progress at the start of each step (empty at step 1, full after last step completes)
        $pct = if ($totalSteps -gt 0) { [math]::Round((($currentStep - 1) / $totalSteps) * 100) } else { 0 }
        $script:ApplyProgressBarEl.Value = $pct
        # Process pending window messages to keep UI responsive
        DoEvents
    }

    # Sub-step callback updates step name and interpolates progress bar within the current step
    $script:ApplySubStepCallback = {
        param($subStepName, $subIndex, $subCount)
        $script:ApplyStepNameEl.Text = $subStepName
        # Interpolate progress bar between previous step and current step
        $currentStep = [int]($script:ApplyStepCounterEl.Tag)
        $totalSteps = [int]($script:ApplyProgressBarEl.Tag)
        if ($totalSteps -gt 0 -and $subCount -gt 0) {
            $baseProgress = ($currentStep - 1) / $totalSteps
            $stepFraction = ($subIndex / $subCount) / $totalSteps
            $script:ApplyProgressBarEl.Value = [math]::Round(($baseProgress + $stepFraction) * 100)
        }
        DoEvents
    }
    
    # Run changes in background to keep UI responsive
    $applyWindow.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
        try {
            ExecuteAllChanges
            
            # Restart explorer if requested
            if ($RestartExplorer -and -not $script:CancelRequested) {
                RestartExplorer
                
                # Wait for Explorer to finish relaunching, then reclaim focus.
                Start-Sleep -Milliseconds 800
                $applyWindow.Dispatcher.Invoke([action]{
                    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($applyWindow)).Handle
                    [Win11Debloat.FocusHelper]::ForceActivate($hwnd)
                })
            }
            
            Write-Host ""
            if ($script:CancelRequested) {
                Write-Host "Script execution was cancelled by the user. Some changes may not have been applied."
            } else {
                Write-Host "All changes have been applied successfully!"
            }
            
            # Show completion state
            $script:ApplyProgressBarEl.Value = 100
            $script:ApplyInProgressPanel.Visibility = 'Collapsed'
            $script:ApplyCompletionPanel.Visibility = 'Visible'
            
            if ($script:CancelRequested) {
                $script:ApplyCompletionIconEl.Text = [char]0xE7BA
                $script:ApplyCompletionIconEl.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#e8912d"))
                $script:ApplyCompletionTitleEl.Text = "Cancelled"
                $script:ApplyCompletionMessageEl.Text = "Script execution was cancelled by the user."
            } else {
                $script:ApplyCompletionTitleEl.Text = "Changes Applied"

                # Show completion message with reboot instructions if any applied features require reboot
                if ($RestartExplorer) {
                    $rebootFeatures = @()
                    foreach ($paramKey in $script:Params.Keys) {
                        if ($script:Features.ContainsKey($paramKey) -and $script:Features[$paramKey].RequiresReboot -eq $true) {
                            $feature = $script:Features[$paramKey]
                            $rebootFeatures += "$($feature.Action) $($feature.Label)"
                        }
                    }

                    if ($rebootFeatures.Count -gt 0) {
                        foreach ($featureName in $rebootFeatures) {
                            $tb = [System.Windows.Controls.TextBlock]::new()
                            $tb.Text = "$([char]0x2022) $featureName"
                            $tb.FontSize = 12
                            $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'FgColor')
                            $tb.Opacity = 0.85
                            $tb.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)
                            $applyRebootList.Children.Add($tb) | Out-Null
                        }
                        $applyRebootPanel.Visibility = 'Visible'
                    }
                    else {
                        $script:ApplyCompletionMessageEl.Text = "Your clean system is ready. Thanks for using Win11Debloat!"
                    }
                }
            }
            $applyWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [action]{})
        }
        catch {
            Write-Host "Error: $($_.Exception.Message)"
            $script:ApplyInProgressPanel.Visibility = 'Collapsed'
            $script:ApplyCompletionPanel.Visibility = 'Visible'
            $script:ApplyCompletionIconEl.Text = [char]0xEA39
            $script:ApplyCompletionIconEl.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c"))
            $script:ApplyCompletionTitleEl.Text = "Error"
            $script:ApplyCompletionMessageEl.Text = "An error occurred while applying changes: $($_.Exception.Message)"
            
            # Set error state to change Kofi button to report link
            $script:ApplyModalInErrorState = $true

            # Update Kofi button to be a report issue button
            $applyKofiBtn.Content = $null
            
            $reportText = [System.Windows.Controls.TextBlock]::new()
            $reportText.Text = 'Report a bug'
            $reportText.VerticalAlignment = 'Center'
            $reportText.FontSize = 14
            $reportText.Margin = [System.Windows.Thickness]::new(0, 0, 0, 1)

            $applyKofiBtn.Content = $reportText
            
            [System.Windows.Automation.AutomationProperties]::SetName($applyKofiBtn, 'Report a bug')
            
            $applyWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [action]{})
        }
        finally {
            $script:ApplyProgressCallback = $null
            $script:ApplySubStepCallback = $null
        }
    }) | Out-Null
    
    # Button handlers
    $applyCloseBtn.Add_Click({
        $applyWindow.Close()
    })

    $applyKofiBtn.Add_Click({
        if ($script:ApplyModalInErrorState) {
            Start-Process "https://github.com/Raphire/Win11Debloat/issues/new"
        } else {
            Start-Process "https://ko-fi.com/raphire"
        }
    })

    $applyCancelBtn.Add_Click({
        if ($script:ApplyCompletionPanel.Visibility -eq 'Visible') {
            # Completion state - just close
            $applyWindow.Close()
        } else {
            # In-progress state - request cancellation
            $script:CancelRequested = $true
        }
    })
    
    # Show dialog
    $applyWindow.ShowDialog() | Out-Null
    
    # Hide overlay after dialog closes
    if ($overlay) {
        try {
            $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
        }
        catch { }
    }
}
