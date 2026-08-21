function ConvertTo-GitHubWorkflowCommandData {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    $Value.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
}

function ConvertTo-GitHubWorkflowCommandProperty {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    (ConvertTo-GitHubWorkflowCommandData $Value).Replace(':', '%3A').Replace(',', '%2C')
}
