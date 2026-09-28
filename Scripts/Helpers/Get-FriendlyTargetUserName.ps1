. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        Returns a readable description of the current app-removal target.
#>
function Get-FriendlyTargetUserName {
    $target = Get-TargetUserForAppRemoval

    switch ($target) {
        "AllUsers" { return (Get-ConsoleTranslation -Text 'all users') }
        "CurrentUser" { return (Get-ConsoleTranslation -Text 'the current user') }
        default { return (Get-ConsoleTranslation -Text 'user {0}' -FormatArgs @($target)) }
    }
}
