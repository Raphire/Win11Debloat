BeforeAll {
    if (-not ('LauncherArgvNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LauncherArgvNative {
    [DllImport("shell32.dll", SetLastError = true)]
    private static extern IntPtr CommandLineToArgvW([MarshalAs(UnmanagedType.LPWStr)] string commandLine, out int argc);

    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr handle);

    public static string[] Split(string commandLine) {
        int argc;
        IntPtr argv = CommandLineToArgvW(commandLine, out argc);
        string[] result = new string[argc];
        for (int i = 0; i < argc; i++) {
            result[i] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(argv, i * IntPtr.Size));
        }
        LocalFree(argv);
        return result;
    }
}
'@
    }

    # Load only Format-LauncherArg from the launcher; dot-sourcing Get.ps1 would download and run the script.
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\Scripts\Get.ps1'), [ref]$tokens, [ref]$parseErrors)
    $parseErrors | Should -BeNullOrEmpty
    $function = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Format-LauncherArg'
    }, $true)
    $function | Should -Not -BeNullOrEmpty
    . ([scriptblock]::Create($function.Extent.Text))
}

Describe 'Format-LauncherArg' {
    It 'round-trips <Value> through CommandLineToArgvW as a single argument' -ForEach @(
        @{ Value = 'plain' }
        @{ Value = 'C:\Log Files\' }
        @{ Value = 'C:\Log Files\\' }
        @{ Value = 'say "hi"' }
        @{ Value = 'Microsoft.A, "B"' }
        @{ Value = 'tail\"quote' }
        @{ Value = 'C:\a b\c d' }
        @{ Value = '' }
    ) {
        $parsed = [LauncherArgvNative]::Split('launcher.exe -Param ' + (Format-LauncherArg $Value))

        $parsed | Should -HaveCount 3
        $parsed[1] | Should -BeExactly '-Param'
        $parsed[2] | Should -BeExactly $Value
    }
}
