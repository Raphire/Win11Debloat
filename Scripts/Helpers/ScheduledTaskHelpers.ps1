function Disable-ScheduledTaskSafe {
    param (
        [Parameter(Mandatory)]
        [string]$TaskPath,
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    Invoke-NonBlocking -ScriptBlock {
        param($path, $name)
        if (Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue) {
            Disable-ScheduledTask -TaskPath $path -TaskName $name | Out-Null
            return $true
        }
        return $false
    } -ArgumentList @($TaskPath, $TaskName)
}

function Enable-ScheduledTaskSafe {
    param (
        [Parameter(Mandatory)]
        [string]$TaskPath,
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    Invoke-NonBlocking -ScriptBlock {
        param($path, $name)
        if (Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue) {
            Enable-ScheduledTask -TaskPath $path -TaskName $name | Out-Null
            return $true
        }
        return $false
    } -ArgumentList @($TaskPath, $TaskName)
}
