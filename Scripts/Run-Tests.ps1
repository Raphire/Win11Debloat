<#
    .SYNOPSIS
        Runs the Win11Debloat Pester test suite locally.

    .PARAMETER Bootstrap
        Installs a compatible Pester 5 release for the current user when Pester is
        not already available.
#>
[CmdletBinding()]
param(
    [switch]$Bootstrap
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testPath = Join-Path $repositoryRoot 'Tests'

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -eq 5 })) {
    if (-not $Bootstrap) {
        Write-Error '需要 Pester 5。安装方法：.\Scripts\Run-Tests.ps1 -Bootstrap'
        exit 1
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false | Out-Null
        }

        Install-Module -Name Pester -RequiredVersion 5.9.0 -Scope CurrentUser -Force -AllowClobber -Confirm:$false
    }
    catch {
        Write-Error "无法安装 Pester 5：$($_.Exception.Message)"
        exit 1
    }

    if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -eq 5 })) {
        Write-Error 'Pester 5 未安装成功。请更新 PowerShellGet 或手动安装 Pester 5 后重新测试。'
        exit 1
    }
}

Import-Module Pester -MinimumVersion 5.0.0 -MaximumVersion 5.999.999 -Force
$result = Invoke-Pester -Path $testPath -Output Detailed -PassThru

if ($result.Result -ne 'Passed' -or $result.FailedContainersCount -gt 0 -or $result.TotalCount -eq 0) {
    exit 1
}
