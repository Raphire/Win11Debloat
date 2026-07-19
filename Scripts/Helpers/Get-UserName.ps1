<#
    .SYNOPSIS
        Returns the explicitly targeted user name or the current process user name.
#>
function Get-UserName {
    if ($script:Params.ContainsKey("User")) {
        return $script:Params.Item("User")
    }

    return $env:USERNAME
}
