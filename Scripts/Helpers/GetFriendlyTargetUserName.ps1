function GetFriendlyTargetUserName {
    $target = GetTargetUserForAppRemoval

    switch ($target) {
        "AllUsers" { return "all users" }
        "CurrentUser" { return "the current user" }
        default { return "user $target" }
    }
}
