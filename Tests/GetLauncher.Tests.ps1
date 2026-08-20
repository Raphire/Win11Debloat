BeforeAll {
    $getScriptPath = Join-Path $PSScriptRoot '..\Scripts\Get.ps1'
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($getScriptPath, [ref]$tokens, [ref]$parseErrors)
    $parseErrors | Should -BeNullOrEmpty

    $functionAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Get-GitHubDownloadFailureMessage'
        }, $true) | Select-Object -First 1

    $functionAst | Should -Not -BeNullOrEmpty
    . ([scriptblock]::Create($functionAst.Extent.Text))
}

Describe 'Get-GitHubDownloadFailureMessage' {
    It 'keeps the original user-facing error and appends the exception message' {
        $errorRecord = $null
        try {
            throw 'Response status code does not indicate success: 403 (Forbidden).'
        }
        catch {
            $errorRecord = $_
        }

        $message = Get-GitHubDownloadFailureMessage -ErrorRecord $errorRecord

        $message | Should -Match 'Unable to fetch required files from GitHub'
        $message | Should -Match '403 \(Forbidden\)'
    }

    It 'appends GitHub ErrorDetails when they differ from the exception message' {
        $errorRecord = $null
        try {
            throw 'The remote server returned an error: (403) Forbidden.'
        }
        catch {
            $errorRecord = $_
        }

        $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('API rate limit exceeded for 1.2.3.4')
        $message = Get-GitHubDownloadFailureMessage -ErrorRecord $errorRecord

        $message | Should -Match 'The remote server returned an error'
        $message | Should -Match 'API rate limit exceeded'
    }
}
