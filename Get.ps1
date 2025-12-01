<#
.SYNOPSIS
    Downloads and executes the latest Win11Debloat script with comprehensive Windows 11 optimization capabilities.

.DESCRIPTION
    The Get.ps1 script serves as an automated downloader and launcher for the Win11Debloat toolkit,
    providing enterprise-grade Windows 11 system optimization and debloating functionality. This script
    handles the complete workflow of downloading, extracting, and executing the latest version of
    Win11Debloat from the official GitHub repository.

    Key Features:
    ? Automatic download and execution of the latest Win11Debloat version
    ? Comprehensive parameter passthrough for all debloating options
    ? Built-in cleanup and temporary file management
    ? Administrative privilege escalation for system-level modifications
    ? Preservation of custom configurations and settings between updates
    ? Enterprise-ready execution with full parameter support

    The script supports all Win11Debloat parameters including app removal, telemetry disabling,
    UI customization, privacy enhancements, and system performance optimizations. It automatically
    handles version management, temporary file cleanup, and maintains user customizations across updates.

.PARAMETER Silent
    Runs Win11Debloat in silent mode without interactive prompts.
    Enables unattended execution for enterprise deployment scenarios.

.PARAMETER Verbose
    Enables verbose logging and detailed output during Win11Debloat execution.
    Provides comprehensive diagnostic information for troubleshooting.

.PARAMETER Sysprep
    Prepares the system for imaging by applying sysprep-compatible optimizations.
    Essential for enterprise image deployment workflows.

.PARAMETER LogPath
    Specifies custom path for Win11Debloat log file storage.
    Enables centralized logging for enterprise monitoring and compliance.

.PARAMETER User
    Targets specific user account for user-specific optimizations.
    Allows granular control over per-user settings and configurations.

.PARAMETER CreateRestorePoint
    Creates system restore point before applying modifications.
    Provides rollback capability for system recovery scenarios.

.PARAMETER RunAppsListGenerator
    Generates comprehensive list of installed applications for custom removal.
    Enables targeted app removal strategies for specific environments.

.PARAMETER RunAppConfigurator
    Launches interactive application configuration utility.
    Provides guided interface for complex app management scenarios.

.PARAMETER RunDefaults
    Applies standard Win11Debloat optimization defaults.
    Recommended setting for general enterprise deployments.

.PARAMETER RunDefaultsLite
    Applies conservative optimization settings for sensitive environments.
    Minimal modifications suitable for compliance-restricted environments.

.PARAMETER RunSavedSettings
    Applies previously saved Win11Debloat configuration settings.
    Enables consistent deployment across multiple systems.

.PARAMETER RemoveApps
    Removes standard set of unnecessary Windows 11 applications.
    Reduces system bloat and improves performance.

.PARAMETER RemoveAppsCustom
    Removes applications based on custom-defined removal list.
    Provides granular control over application removal strategies.

.PARAMETER RemoveGamingApps
    Specifically targets gaming-related applications for removal.
    Optimizes systems for business-focused environments.

.PARAMETER RemoveCommApps
    Removes communication applications (Teams, Skype, etc.).
    Suitable for environments with standardized communication tools.

.PARAMETER RemoveHPApps
    Removes HP-specific bloatware and utilities.
    Optimizes HP hardware for clean enterprise deployment.

.PARAMETER RemoveW11Outlook
    Removes Windows 11 integrated Outlook application.
    Prevents conflicts with enterprise Outlook deployments.

.PARAMETER ForceRemoveEdge
    Forcibly removes Microsoft Edge browser.
    For environments requiring alternative browser standards.

.PARAMETER DisableDVR
    Disables Windows Game DVR functionality.
    Improves system performance in business environments.

.PARAMETER DisableGameBarIntegration
    Disables Windows Game Bar and related gaming features.
    Reduces resource consumption for business-focused systems.

.PARAMETER DisableTelemetry
    Disables Windows telemetry and data collection features.
    Enhances privacy and reduces network traffic.

.PARAMETER DisableFastStartup
    Disables Windows Fast Startup feature.
    Resolves compatibility issues with enterprise hardware and software.

.PARAMETER DisableModernStandbyNetworking
    Disables modern standby network connectivity.
    Improves power management and security in enterprise environments.

.PARAMETER DisableBingSearches
    Disables Bing integration in Windows Search.
    Prevents external search queries and improves privacy.

.PARAMETER DisableBing
    Alias for DisableBingSearches parameter.

.PARAMETER DisableDesktopSpotlight
    Disables Windows Spotlight desktop backgrounds.
    Maintains consistent desktop appearance for enterprise branding.

.PARAMETER DisableLockscrTips
    Disables lock screen tips and suggestions.
    Reduces distractions and maintains professional appearance.

.PARAMETER DisableLockscreenTips
    Alias for DisableLockscrTips parameter.

.PARAMETER DisableWindowsSuggestions
    Disables Windows suggestions and recommendations.
    Reduces unwanted notifications and improves user focus.

.PARAMETER DisableSuggestions
    Alias for DisableWindowsSuggestions parameter.

.PARAMETER DisableEdgeAds
    Disables advertising and promotional content in Microsoft Edge.
    Improves browsing experience and reduces distractions.

.PARAMETER DisableSettings365Ads
    Disables Microsoft 365 advertisements in Windows Settings.
    Reduces commercial content in system interfaces.

.PARAMETER DisableSettingsHome
    Disables Settings Home page with promotional content.
    Streamlines Settings application for business use.

.PARAMETER ShowHiddenFolders
    Configures File Explorer to show hidden files and folders.
    Enables advanced file management for technical users.

.PARAMETER ShowKnownFileExt
    Shows file extensions for known file types.
    Improves file management and security awareness.

.PARAMETER HideDupliDrive
    Hides duplicate drive entries in File Explorer.
    Simplifies navigation interface for users.

.PARAMETER EnableDarkMode
    Enables Windows dark mode theme.
    Provides modern appearance and reduced eye strain.

.PARAMETER DisableTransparency
    Disables Windows transparency effects.
    Improves performance on lower-end hardware.

.PARAMETER DisableAnimations
    Disables Windows UI animations.
    Significantly improves performance and responsiveness.

.PARAMETER TaskbarAlignLeft
    Aligns taskbar icons to the left side.
    Provides familiar Windows 10-style taskbar layout.

.PARAMETER CombineTaskbarAlways
    Always combines taskbar buttons for the same application.

.PARAMETER CombineTaskbarWhenFull
    Combines taskbar buttons only when taskbar is full.

.PARAMETER CombineTaskbarNever
    Never combines taskbar buttons, showing individual windows.

.PARAMETER CombineMMTaskbarAlways
    Always combines multi-monitor taskbar buttons.

.PARAMETER CombineMMTaskbarWhenFull
    Combines multi-monitor taskbar buttons when full.

.PARAMETER CombineMMTaskbarNever
    Never combines multi-monitor taskbar buttons.

.PARAMETER MMTaskbarModeAll
    Shows taskbar on all monitors.

.PARAMETER MMTaskbarModeMainActive
    Shows taskbar on main monitor and where window is active.

.PARAMETER MMTaskbarModeActive
    Shows taskbar only where window is active.

.PARAMETER HideSearchTb
    Hides search button from taskbar.

.PARAMETER ShowSearchIconTb
    Shows search icon on taskbar.

.PARAMETER ShowSearchLabelTb
    Shows search label on taskbar.

.PARAMETER ShowSearchBoxTb
    Shows full search box on taskbar.

.PARAMETER HideTaskview
    Hides Task View button from taskbar.
    Simplifies taskbar interface for business users.

.PARAMETER DisableStartRecommended
    Disables recommended items in Start Menu.
    Maintains clean Start Menu appearance.

.PARAMETER DisableStartPhoneLink
    Disables Phone Link integration in Start Menu.
    Removes unnecessary mobile integration features.

.PARAMETER DisableCopilot
    Disables Windows Copilot AI assistant.
    Removes AI features for privacy or policy compliance.

.PARAMETER DisableRecall
    Disables Windows Recall feature.
    Addresses privacy concerns with activity tracking.

.PARAMETER DisableClickToDo
    Disables Click to Do functionality.
    Removes AI-powered productivity suggestions.

.PARAMETER DisablePaintAI
    Disables AI features in Paint application.
    Maintains traditional Paint functionality.

.PARAMETER DisableNotepadAI
    Disables AI features in Notepad application.
    Preserves simple text editing experience.

.PARAMETER DisableEdgeAI
    Disables AI features in Microsoft Edge browser.
    Reduces AI-powered browsing features.

.PARAMETER DisableWidgets
    Disables Windows Widgets panel.
    Removes widget functionality from taskbar.

.PARAMETER HideWidgets
    Alias for DisableWidgets parameter.

.PARAMETER DisableChat
    Disables Chat integration in taskbar.
    Removes Microsoft Teams consumer chat features.

.PARAMETER HideChat
    Alias for DisableChat parameter.

.PARAMETER EnableEndTask
    Enables End Task option in taskbar context menu.
    Provides quick access to task termination.

.PARAMETER EnableLastActiveClick
    Enables last active click behavior for taskbar.
    Improves taskbar interaction efficiency.

.PARAMETER ClearStart
    Clears Start Menu pinned items for current user.
    Provides clean Start Menu configuration.

.PARAMETER ReplaceStart
    Replaces Start Menu layout with specified configuration file.
    Enables standardized Start Menu deployment.

.PARAMETER ClearStartAllUsers
    Clears Start Menu pinned items for all users.
    System-wide Start Menu cleanup.

.PARAMETER ReplaceStartAllUsers
    Replaces Start Menu layout for all users with specified configuration.
    Enterprise-wide Start Menu standardization.

.PARAMETER RevertContextMenu
    Reverts to Windows 10-style context menus.
    Provides familiar right-click menu experience.

.PARAMETER DisableMouseAcceleration
    Disables mouse pointer acceleration.
    Improves mouse precision for professional use.

.PARAMETER DisableStickyKeys
    Disables Sticky Keys accessibility feature.
    Prevents accidental activation during normal use.

.PARAMETER HideHome
    Hides Home folder from File Explorer sidebar.
    Simplifies File Explorer navigation.

.PARAMETER HideGallery
    Hides Gallery from File Explorer sidebar.
    Removes multimedia-focused navigation options.

.PARAMETER ExplorerToHome
    Sets File Explorer default location to Home.

.PARAMETER ExplorerToThisPC
    Sets File Explorer default location to This PC.
    Provides traditional computer-focused view.

.PARAMETER ExplorerToDownloads
    Sets File Explorer default location to Downloads folder.

.PARAMETER ExplorerToOneDrive
    Sets File Explorer default location to OneDrive folder.

.PARAMETER NoRestartExplorer
    Prevents automatic File Explorer restart after modifications.
    Allows manual restart timing control.

.PARAMETER DisableOnedrive
    Completely disables OneDrive integration.
    Removes cloud storage integration for offline environments.

.PARAMETER HideOnedrive
    Alias for DisableOnedrive parameter.

.PARAMETER Disable3dObjects
    Disables 3D Objects folder integration.
    Removes unnecessary navigation options.

.PARAMETER Hide3dObjects
    Alias for Disable3dObjects parameter.

.PARAMETER DisableMusic
    Disables Music library integration.
    Simplifies File Explorer for business use.

.PARAMETER HideMusic
    Alias for DisableMusic parameter.

.PARAMETER DisableIncludeInLibrary
    Disables "Include in Library" context menu option.
    Simplifies right-click menu interface.

.PARAMETER HideIncludeInLibrary
    Alias for DisableIncludeInLibrary parameter.

.PARAMETER DisableGiveAccessTo
    Disables "Give Access To" sharing options.
    Removes sharing features for security compliance.

.PARAMETER HideGiveAccessTo
    Alias for DisableGiveAccessTo parameter.

.PARAMETER DisableShare
    Disables sharing context menu options.
    Comprehensive sharing feature removal.

.PARAMETER HideShare
    Alias for DisableShare parameter.

.OUTPUTS
    System.String (Console Output)
    Win11Debloat.log (Log File in Temp Directory)

.EXAMPLE
    PS> .\Get.ps1 -RunDefaults -CreateRestorePoint -Silent

    Downloads and runs Win11Debloat with default optimizations, creates restore point,
    and executes silently without user interaction.

.EXAMPLE
    PS> .\Get.ps1 -RemoveApps -DisableTelemetry -EnableDarkMode -TaskbarAlignLeft

    Downloads and runs Win11Debloat with app removal, telemetry disabling, dark mode,
    and left-aligned taskbar configuration.

.EXAMPLE
    PS> .\Get.ps1 -Sysprep -RunDefaultsLite -LogPath "C:\Logs\Win11Debloat.log"

    Prepares system for imaging with conservative optimizations and custom log location.

.NOTES
    Script Name    : Get.ps1
    Author         : Win11Debloat Project / Enterprise Infrastructure Team
    Version        : 2.0
    Last Modified  : 2025.11.30

    Prerequisites  :
    ? PowerShell 5.1 or higher with FullLanguage execution mode
    ? Administrative privileges for system modifications
    ? Internet connectivity for downloading latest Win11Debloat version
    ? Windows 11 operating system

    Source Repository: https://github.com/Raphire/Win11Debloat
    Latest Version: 2025.11.29

    Temporary Files:
    ? Download Location: %TEMP%\win11debloat.zip
    ? Extraction Location: %TEMP%\Win11Debloat\
    ? Preserved Files: CustomAppsList, SavedSettings, Win11Debloat.log

.COMPONENT
    Windows 11 System Optimization
    Enterprise Desktop Management
    System Debloating and Performance

.ROLE
    Administrator
    Desktop Engineer
    System Administrator
    IT Professional

.FUNCTIONALITY
    ? Automated Win11Debloat script download and execution
    ? Comprehensive Windows 11 optimization and debloating
    ? Enterprise-grade system customization and performance tuning
    ? Privacy enhancement and telemetry management
    ? UI customization and user experience optimization
    ? Application removal and system cleanup
    ? Administrative privilege handling and execution management

.SECURITY
    Security Considerations:
    ? Requires administrative privileges for system-level modifications
    ? Downloads executable content from external GitHub repository
    ? Validates PowerShell execution environment before proceeding
    ? Creates system restore points for rollback capability
    ? Preserves user configurations and custom settings
    ? Executes with elevated permissions for system modifications

.COMPLIANCE
    Regulatory Compliance:
    ? Supports enterprise privacy requirements through telemetry disabling
    ? Enables standardized desktop configurations for compliance frameworks
    ? Provides logging capabilities for audit trail requirements
    ? Supports system preparation for compliance-ready imaging
    ? Facilitates removal of non-compliant applications and features
    ? Enables consistent security posture across enterprise deployments

.PERFORMANCE
    Performance Characteristics:
    ? Minimal local processing - primarily download and execution wrapper
    ? Network-dependent download time based on repository availability
    ? Automatic cleanup of temporary files and archives
    ? Efficient parameter passthrough with minimal overhead
    ? Administrative privilege escalation handled transparently

.LINK
    Win11Debloat Repository: https://github.com/Raphire/Win11Debloat
    Windows 11 Enterprise Management: https://docs.microsoft.com/windows/deployment/

.CHANGELOG
    Version 1.0 - Initial Win11Debloat download and execution script
    Version 2.0 - Enterprise documentation, enhanced parameter support, and security validation
#>

param (
    [switch]$Silent,
    [switch]$Verbose,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator,
    [switch]$RunAppConfigurator,
    [switch]$RunDefaults,
    [switch]$RunDefaultsLite,
    [switch]$RunSavedSettings,
    [switch]$RemoveApps,
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveHPApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableGameBarIntegration,
    [switch]$DisableTelemetry,
    [switch]$DisableFastStartup,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$DisableEdgeAds,
    [switch]$DisableSettings365Ads,
    [switch]$DisableSettingsHome,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$EnableDarkMode,
    [switch]$DisableTransparency,
    [switch]$DisableAnimations,
    [switch]$TaskbarAlignLeft,
    [switch]$CombineTaskbarAlways, [switch]$CombineTaskbarWhenFull, [switch]$CombineTaskbarNever,
    [switch]$CombineMMTaskbarAlways, [switch]$CombineMMTaskbarWhenFull, [switch]$CombineMMTaskbarNever,
    [switch]$MMTaskbarModeAll, [switch]$MMTaskbarModeMainActive, [switch]$MMTaskbarModeActive,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableStartRecommended,
    [switch]$DisableStartPhoneLink,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableClickToDo,
    [switch]$DisablePaintAI,
    [switch]$DisableNotepadAI,
    [switch]$DisableEdgeAI,
    [switch]$DisableWidgets, [switch]$HideWidgets,
    [switch]$DisableChat, [switch]$HideChat,
    [switch]$EnableEndTask,
    [switch]$EnableLastActiveClick,
    [switch]$ClearStart,
    [string]$ReplaceStart,
    [switch]$ClearStartAllUsers,
    [string]$ReplaceStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$DisableMouseAcceleration,
    [switch]$DisableStickyKeys,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$NoRestartExplorer,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)

# Show error if current powershell environment does not have LanguageMode set to FullLanguage
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host 'Error: Win11Debloat is unable to run on your system. PowerShell execution is restricted by security policies' -ForegroundColor Red
    Write-Output ''
    Write-Output 'Press enter to exit...'
    Read-Host | Out-Null
    exit
}

Clear-Host
Write-Output '-------------------------------------------------------------------------------------------'
Write-Output ' Win11Debloat Script - Get'
Write-Output '-------------------------------------------------------------------------------------------'

Write-Output '> Downloading Win11Debloat...'

# Download latest version of Win11Debloat from github as zip archive
Invoke-RestMethod https://api.github.com/repos/Raphire/Win11Debloat/zipball/2025.11.30 -OutFile "$env:TEMP/win11debloat.zip"

# Remove old script folder if it exists, except for CustomAppsList and SavedSettings files
if (Test-Path "$env:TEMP/Win11Debloat") {
    Write-Output ''
    Write-Output '> Cleaning up old Win11Debloat folder...'
    Get-ChildItem -Path "$env:TEMP/Win11Debloat" -Exclude CustomAppsList, SavedSettings, Win11Debloat.log | Remove-Item -Recurse -Force
}

Write-Output ''
Write-Output '> Unpacking...'

# Unzip archive to Win11Debloat folder
Expand-Archive "$env:TEMP/win11debloat.zip" "$env:TEMP/Win11Debloat"

# Remove archive
Remove-Item "$env:TEMP/win11debloat.zip"

# Move files
Get-ChildItem -Path "$env:TEMP/Win11Debloat/Raphire-Win11Debloat-*" -Recurse | Move-Item -Destination "$env:TEMP/Win11Debloat"

# Make list of arguments to pass on to the script
$arguments = $($PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -eq $true) {
            "-$($_.Key)"
        } else {
            "-$($_.Key) ""$($_.Value)"""
        }
    })

Write-Output ''
Write-Output '> Running Win11Debloat...'

# Run Win11Debloat script with the provided arguments
$debloatProcess = Start-Process powershell.exe -PassThru -ArgumentList "-executionpolicy bypass -File $env:TEMP\Win11Debloat\Win11Debloat.ps1 $arguments" -Verb RunAs

# Wait for the process to finish before continuing
if ($null -ne $debloatProcess) {
    $debloatProcess.WaitForExit()
}

# Remove all remaining script files, except for CustomAppsList and SavedSettings files
if (Test-Path "$env:TEMP/Win11Debloat") {
    Write-Output ''
    Write-Output '> Cleaning up...'

    # Cleanup, remove Win11Debloat directory
    Get-ChildItem -Path "$env:TEMP/Win11Debloat" -Exclude CustomAppsList, SavedSettings, Win11Debloat.log | Remove-Item -Recurse -Force
}

Write-Output ''
