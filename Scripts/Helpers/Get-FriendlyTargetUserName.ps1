<#
    .SYNOPSIS
        Returns a readable description of the current app-removal target.
#>
function Get-FriendlyTargetUserName {
    $target = Get-TargetUserForAppRemoval

    switch ($target) {
        "AllUsers" { return "all users" }
        "CurrentUser" { return "the current user" }
        default { return "user $target" }
    }
}
