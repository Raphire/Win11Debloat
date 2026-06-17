[CmdletBinding()]
param()

# Scans the system for Scheduled Tasks pointing to non-existent executables.
# Bypasses Microsoft/Windows system tasks and standard interpreters.
function Get-OrphanedScheduledTasks {
    $orphanedTasks = @()
    
    # Query all scheduled tasks. Silently continue if we hit permission blocks on certain protected tasks.
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    
    foreach ($task in $tasks) {
        # Whitelist Guard: Skip native Microsoft / Windows system tasks
        if ($task.TaskPath -like "\Microsoft*" -or $task.TaskPath -like "\Microsoft\Windows*") {
            continue
        }
        
        # Check task Actions
        $actions = $task.Actions
        foreach ($action in $actions) {
            $cmd = $action.Execute
            if ([string]::IsNullOrEmpty($cmd)) {
                continue
            }
            
            $cmd = $cmd.Trim()
            
            # Extract executable path (strip quotes)
            $exePath = ""
            if ($cmd.StartsWith('"')) {
                $endQuote = $cmd.IndexOf('"', 1)
                $exePath = if ($endQuote -gt 0) { $cmd.Substring(1, $endQuote - 1) } else { $cmd.Trim('"') }
            } elseif ($cmd.StartsWith("'")) {
                $endQuote = $cmd.IndexOf("'", 1)
                $exePath = if ($endQuote -gt 0) { $cmd.Substring(1, $endQuote - 1) } else { $cmd.Trim("'") }
            } else {
                # No quotes, might contain arguments separated by spaces.
                $tokens = $cmd -split "\s+"
                $exePath = $tokens[0]
                
                # If the first token doesn't exist, try checking combinations if path has spaces but no quotes.
                if (-not (Test-Path -Path $exePath -ErrorAction SilentlyContinue) -and ($cmd -like "* *")) {
                    $found = $false
                    $currentPath = ""
                    foreach ($token in $tokens) {
                        $currentPath = if ($currentPath -eq "") { $token } else { "$currentPath $token" }
                        if (Test-Path -Path $currentPath -PathType Leaf -ErrorAction SilentlyContinue) {
                            $exePath = $currentPath
                            $found = $true
                            break
                        }
                    }
                    
                    # If we couldn't find an existing file, split at the first token ending in a known executable extension.
                    if (-not $found) {
                        $currentPath = ""
                        foreach ($token in $tokens) {
                            $currentPath = if ($currentPath -eq "") { $token } else { "$currentPath $token" }
                            if ($token -match '\.(exe|bat|cmd|ps1|vbs|lnk)$') {
                                $exePath = $currentPath
                                $found = $true
                                break
                            }
                        }
                    }
                    
                    # Fallback: if still not resolved, default to the first token
                    if (-not $found) {
                        $exePath = $tokens[0]
                    }
                }
            }
            
            # Skip empty or null parsed paths
            if ([string]::IsNullOrEmpty($exePath)) {
                continue
            }
            
            # Expand environment variables (e.g. %windir%, %APPDATA%, etc.)
            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($exePath)
            
            # Verify if the target file exists or if it's a standard system command in PATH
            $exists = $false
            if (Test-Path -Path $expandedPath -PathType Leaf -ErrorAction SilentlyContinue) {
                $exists = $true
            } elseif (Get-Command -Name $expandedPath -ErrorAction SilentlyContinue) {
                $exists = $true
            }
            
            # If the executable does not exist, it's flagged as an orphaned task
            if (-not $exists) {
                $orphanedTasks += [PSCustomObject]@{
                    TaskName = $task.TaskName
                    TaskPath = $task.TaskPath
                    Execute  = $action.Execute
                    Resolved = $expandedPath
                    Task     = $task
                }
                # Break action loop to avoid duplicate task registrations
                break
            }
        }
    }
    
    return $orphanedTasks
}

# Scans and removes orphaned third-party scheduled tasks.
function RemoveOrphanedTasks {
    Write-Host "Scanning for orphaned scheduled tasks..."
    $orphanedTasks = Get-OrphanedScheduledTasks
    
    if ($orphanedTasks.Count -eq 0) {
        Write-Host "No orphaned scheduled tasks were found."
        return
    }
    
    Write-Host "Found $($orphanedTasks.Count) orphaned scheduled task(s):"
    foreach ($item in $orphanedTasks) {
        Write-Host " - '$($item.TaskPath)$($item.TaskName)' -> Missing: '$($item.Resolved)'" -ForegroundColor DarkGray
    }
    
    # If WhatIf mode is active, display the dry-run output and exit
    if ($WhatIfPreference) {
        foreach ($item in $orphanedTasks) {
            Write-Host "[WhatIf] Would remove orphaned scheduled task '$($item.TaskPath)$($item.TaskName)' pointing to '$($item.Resolved)'" -ForegroundColor Cyan
        }
        return
    }
    
    # Ask for user confirmation if not running in Silent mode and not in GUI mode
    $shouldDelete = $true
    if (-not $Silent -and -not $script:GuiWindow) {
        $confirm = Read-Host -Prompt "Do you want to remove all detected orphaned scheduled tasks? (y/n)"
        if ($confirm -ne 'y' -and $confirm -ne 'yes') {
            $shouldDelete = $false
            Write-Host "Operation cancelled. No tasks were removed."
        }
    }
    
    if ($shouldDelete) {
        foreach ($item in $orphanedTasks) {
            try {
                Write-Host "Removing scheduled task: $($item.TaskPath)$($item.TaskName)..."
                Unregister-ScheduledTask -TaskName $item.TaskName -TaskPath $item.TaskPath -Confirm:$false -ErrorAction Stop
                Write-Host "Successfully removed task: $($item.TaskPath)$($item.TaskName)"
            }
            catch {
                Write-Warning "Failed to remove task '$($item.TaskPath)$($item.TaskName)': $_"
            }
        }
    }
}
