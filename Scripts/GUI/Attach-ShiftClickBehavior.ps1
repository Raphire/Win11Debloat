<#
    .SYNOPSIS
        Attaches shift-click range-selection behavior to an application checkbox.

    .PARAMETER Checkbox
        The checkbox that receives the mouse event handler.

    .PARAMETER AppsPanel
        The panel whose visible checkboxes participate in range selection.

    .PARAMETER LastSelectedCheckboxRef
        A reference that stores the previously clicked checkbox.

    .PARAMETER UpdateStatusCallback
        An optional callback invoked after a range selection changes.
#>
function Attach-ShiftClickBehavior {
    param (
        [System.Windows.Controls.CheckBox]$checkbox,
        [System.Windows.Controls.StackPanel]$appsPanel,
        [ref]$lastSelectedCheckboxRef,
        [scriptblock]$updateStatusCallback = $null
    )

    # Use a closure to capture the parameters
    $checkbox.Add_PreviewMouseLeftButtonDown({
        param(
            $sender,
            $e
        )
        
        $isShiftPressed = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or 
                          [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
        
        if ($isShiftPressed -and $null -ne $lastSelectedCheckboxRef.Value) {
            # Get all visible checkboxes in the panel
            $visibleCheckboxes = @()
            foreach ($child in $appsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') {
                    $visibleCheckboxes += $child
                }
            }

            # Find indices of the last selected and current checkbox
            $lastIndex = -1
            $currentIndex = -1

            for ($i = 0; $i -lt $visibleCheckboxes.Count; $i++) {
                if ($visibleCheckboxes[$i] -eq $lastSelectedCheckboxRef.Value) {
                    $lastIndex = $i
                }
                if ($visibleCheckboxes[$i] -eq $sender) {
                    $currentIndex = $i
                }
            }

            if ($lastIndex -ge 0 -and $currentIndex -ge 0 -and $lastIndex -ne $currentIndex) {
                $startIndex = [Math]::Min($lastIndex, $currentIndex)
                $endIndex = [Math]::Max($lastIndex, $currentIndex)

                $shouldDeselect = $sender.IsChecked

                # Set all checkboxes in the range to the appropriate state
                for ($i = $startIndex; $i -le $endIndex; $i++) {
                    $visibleCheckboxes[$i].IsChecked = -not $shouldDeselect
                }

                if ($updateStatusCallback) {
                    & $updateStatusCallback
                }

                # Mark the event as handled to prevent the default toggle behavior
                $e.Handled = $true
                return
            }
        }

        # Update the last selected checkbox reference for next time
        $lastSelectedCheckboxRef.Value = $sender
    }.GetNewClosure())
}
