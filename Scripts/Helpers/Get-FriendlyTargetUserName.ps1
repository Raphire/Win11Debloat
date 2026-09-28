<#
    .SYNOPSIS
        Returns a readable description of the current app-removal target.
#>
function Get-FriendlyTargetUserName {
    $target = Get-TargetUserForAppRemoval

    switch ($target) {
        "AllUsers" { return "所有用户" }
        "CurrentUser" { return "当前用户" }
        default { return "用户 $target" }
    }
}
