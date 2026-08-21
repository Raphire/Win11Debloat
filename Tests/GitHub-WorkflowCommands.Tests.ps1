BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\CI\GitHub-WorkflowCommands.ps1')
}

Describe 'GitHub workflow command escaping' {
    It 'escapes property delimiters and control characters' {
        ConvertTo-GitHubWorkflowCommandProperty "Scripts\one,two:three%`r`n.ps1" |
            Should -Be 'Scripts\one%2Ctwo%3Athree%25%0D%0A.ps1'
    }

    It 'escapes data control characters without changing commas or colons' {
        ConvertTo-GitHubWorkflowCommandData "Rule%Name: bad, value`r`nnext" |
            Should -Be 'Rule%25Name: bad, value%0D%0Anext'
    }
}
