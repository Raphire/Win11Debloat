<#
.SYNOPSIS
Escapes the data portion of a GitHub Actions workflow command.

.DESCRIPTION
Escapes percent signs, carriage returns and line feeds. Colons and commas are
left unchanged because they are not delimiters in workflow-command data.

.PARAMETER Value
The workflow-command data value to escape.
#>
function ConvertTo-GitHubWorkflowCommandData {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    $Value.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
}

<#
.SYNOPSIS
Escapes a property value in a GitHub Actions workflow command.

.DESCRIPTION
Applies workflow-command data escaping, then additionally escapes colons and
commas because they delimit command properties.

.PARAMETER Value
The workflow-command property value to escape.
#>
function ConvertTo-GitHubWorkflowCommandProperty {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    (ConvertTo-GitHubWorkflowCommandData $Value).Replace(':', '%3A').Replace(',', '%2C')
}
