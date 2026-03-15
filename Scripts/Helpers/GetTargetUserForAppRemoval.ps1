# Target is determined from $script:Params["AppRemovalTarget"] or defaults to "AllUsers"
# Target values: "AllUsers" (removes for all users + from image), "CurrentUser", or a specific username
function GetTargetUserForAppRemoval {
    if ($script:Params.ContainsKey("AppRemovalTarget")) {
        return $script:Params["AppRemovalTarget"]
    }
    
    return "AllUsers"
}
