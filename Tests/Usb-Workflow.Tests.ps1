BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Usb-WorkflowHelpers.ps1')
}

Describe 'USB workflow selection' {
    It 'selects <ExpectedPreset> for menu option <Choice>' -ForEach @(
        @{ Choice = '1'; ExpectedPreset = 'Normal' }
        @{ Choice = '2'; ExpectedPreset = 'Aggressive' }
        @{ Choice = '3'; ExpectedPreset = 'Gaming' }
    ) {
        (Get-UsbWorkflowSelection -Choice $Choice).Preset | Should -Be $ExpectedPreset
    }

    It 'maps the custom GUI, wallpaper, restore and exit options' {
        (Get-UsbWorkflowSelection -Choice '4').Count | Should -Be 0
        (Get-UsbWorkflowSelection -Choice '5').SetWallpaper | Should -BeTrue
        (Get-UsbWorkflowSelection -Choice '6').RestoreBackup | Should -BeTrue
        (Get-UsbWorkflowSelection -Choice '7').RestoreWallpaper | Should -BeTrue
        (Get-UsbWorkflowSelection -Choice '0').Exit | Should -BeTrue
        Get-UsbWorkflowSelection -Choice 'invalid' | Should -BeNullOrEmpty
    }

    It 'offers built-in black even when the wallpaper directory is missing' {
        $choices = @(Get-UsbWallpaperChoices -Directory (Join-Path $TestDrive 'missing'))
        $choices | Should -HaveCount 1
        $choices[0].Path | Should -Be 'Black'
    }

    It 'offers only supported image files, sorted by name, after black' {
        foreach ($filename in @('z.jpg', 'a.png', 'b.bmp', 'c.jpeg', 'readme.md', 'x.gif')) {
            '' | Set-Content -LiteralPath (Join-Path $TestDrive $filename)
        }
        $choices = @(Get-UsbWallpaperChoices -Directory $TestDrive)
        @($choices.Path | Select-Object -First 1) | Should -Be @('Black')
        @($choices.Name | Select-Object -Skip 1) | Should -Be @('a.png', 'b.bmp', 'c.jpeg', 'z.jpg')
    }
}

Describe 'USB process argument quoting' {
    It 'quotes spaces, apostrophes and batch metacharacters literally' {
        ConvertTo-UsbProcessArgument "D:\Nowy USB\obraz & test's!.jpg" | Should -Be """D:\Nowy USB\obraz & test's!.jpg"""
    }

    It 'escapes embedded quotes and doubles trailing backslashes' {
        ConvertTo-UsbProcessArgument 'a"b' | Should -Be '"a\"b"'
        ConvertTo-UsbProcessArgument 'D:\folder\' | Should -Be '"D:\folder\\"'
        ConvertTo-UsbProcessArgument '' | Should -Be '""'
    }
}

Describe 'USB exit status' {
    BeforeEach {
        $script:UsbApplyStarted = $true
        $script:CancelRequested = $false
        $script:ApplyModalInErrorState = $false
        $script:FeatureFailures = 0
        $script:AppRemovalFailures = 0
        $script:RegistryImportFailures = 0
        $script:AppRemovalVerificationUnavailable = $false
    }

    It 'reports successful application as zero' {
        Get-UsbWorkflowExitCode | Should -Be 0
    }

    It 'reports cancellation or closing the GUI without applying as three' {
        $script:UsbApplyStarted = $false
        Get-UsbWorkflowExitCode | Should -Be 3
        $script:UsbApplyStarted = $true
        $script:CancelRequested = $true
        Get-UsbWorkflowExitCode | Should -Be 3
    }

    It 'reports each kind of failure as one' -ForEach @(
        @{ FailureVariable = 'FeatureFailures' }
        @{ FailureVariable = 'AppRemovalFailures' }
        @{ FailureVariable = 'RegistryImportFailures' }
        @{ FailureVariable = 'ApplyModalInErrorState' }
    ) {
        Set-Variable -Name $FailureVariable -Value 1 -Scope Script
        $script:AppRemovalVerificationUnavailable = $true
        Get-UsbWorkflowExitCode | Should -Be 1
    }

    It 'reports unverifiable app removal as two instead of success' {
        $script:AppRemovalVerificationUnavailable = $true
        Get-UsbWorkflowExitCode | Should -Be 2
    }
}

Describe 'USB launcher contracts' {
    It 'loads WPF before binding the standalone restore window parameters' {
        $mainPath = Join-Path $PSScriptRoot '..\Win11Debloat.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($mainPath, [ref]$tokens, [ref]$parseErrors)
        $restoreBranch = $ast.Find({ param($node)
            $node -is [Management.Automation.Language.IfStatementAst] -and $node.Clauses[0].Item1.Extent.Text -eq '$RestoreBackup'
        }, $true)
        $restoreBranch | Should -Not -BeNullOrEmpty
        $restoreBranch.Extent.Text | Should -Match 'Add-Type -AssemblyName PresentationFramework -ErrorAction Stop\s+\$restoreResult = Show-RestoreBackupWindow'
    }

    It 'removes explicitly false action switches before the feature pipeline sees them' {
        $mainPath = Join-Path $PSScriptRoot '..\Win11Debloat.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($mainPath, [ref]$tokens, [ref]$parseErrors)
        $normalization = $ast.Find({ param($node)
            $node -is [Management.Automation.Language.ForEachStatementAst] -and $node.Variable.VariablePath.UserPath -eq 'usbSwitchName'
        }, $true)
        $normalization | Should -Not -BeNullOrEmpty
        $testFunction = [scriptblock]::Create('param([switch]$SetWallpaper, [switch]$RestoreWallpaper, [switch]$RestoreBackup, [switch]$UsbMode, [switch]$ConfirmAggressive)' + "`n" + $normalization.Extent.Text + "`n" + 'return $PSBoundParameters')
        $parameters = & $testFunction -SetWallpaper:$false -RestoreWallpaper:$false -RestoreBackup:$false -UsbMode -ConfirmAggressive:$false
        $parameters.Count | Should -Be 1
        $parameters.ContainsKey('UsbMode') | Should -BeTrue
    }

    It 'uses local files, native Windows PowerShell and no downloaded-code evaluation' {
        $repoRoot = Join-Path $PSScriptRoot '..'
        $batch = Get-Content -LiteralPath (Join-Path $repoRoot 'Run.bat') -Raw
        $batch | Should -Match 'DisableDelayedExpansion'
        $batch | Should -Match 'Sysnative'
        $batch | Should -Match '-NoProfile -STA -ExecutionPolicy Bypass -File'
        $batch | Should -Match '%~dp0Scripts\\CLI\\Start-UsbWorkflow.ps1'
        $batch | Should -Not -Match 'Invoke-Expression|iex|Get.ps1|https?://'
        $launcher = Get-Content -LiteralPath (Join-Path $repoRoot 'Scripts\CLI\Start-UsbWorkflow.ps1') -Raw
        $launcher | Should -Match "'Win11Debloat.ps1'"
        $launcher | Should -Match '-Verb RunAs -Wait -PassThru'
        $launcher | Should -Match "'UsbUserSid'"
    }

    It 'preserves Polish script text in Windows PowerShell 5.1 using a UTF-8 BOM' {
        $repoRoot = Join-Path $PSScriptRoot '..'
        foreach ($relativePath in @('Win11Debloat.ps1', 'Scripts\CLI\Start-UsbWorkflow.ps1', 'Scripts\Features\Set-Wallpaper.ps1', 'Scripts\Helpers\Usb-WorkflowHelpers.ps1')) {
            $bytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot $relativePath))
            ($bytes[0..2] -join ',') | Should -Be '239,187,191' -Because "$relativePath contains Polish text"
        }
    }
}

Describe 'USB saved-settings isolation' {
    BeforeAll {
        function Save-ToFile { param($Config, $FilePath) }
        . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Save-Settings.ps1')
    }

    It 'does not carry a wallpaper action or machine-specific path to the next run' {
        $script:Features = @{
            DisableTelemetry = [PSCustomObject]@{}
            SetWallpaper = [PSCustomObject]@{}
            RestoreWallpaper = [PSCustomObject]@{}
        }
        $script:ControlParams = @('UsbMode', 'WallpaperPath')
        $script:Params = @{ DisableTelemetry = $true; SetWallpaper = $true; RestoreWallpaper = $true; WallpaperPath = 'Black'; UsbMode = $true }
        $script:SavedSettingsFilePath = Join-Path $TestDrive 'settings.json'
        Mock Save-ToFile { $true }
        Save-Settings
        Should -Invoke Save-ToFile -Times 1 -Exactly -ParameterFilter {
            @($Config.Settings).Count -eq 1 -and $Config.Settings[0].Name -eq 'DisableTelemetry'
        }
    }
}
