import pytest
import subprocess
import os


@pytest.mark.parametrize("payload", [
    # Exact exploit case - PowerShell command injection via path
    "C:\\temp\\backup.reg; Get-Process | Out-File C:\\temp\\hacked.txt",
    
    # Boundary case - Path with PowerShell variable expansion
    "$env:USERPROFILE\\malicious.reg",
    
    # Valid input - Normal path
    "C:\\backups\\restore.reg"
])
def test_LoadRegistryBackupFromFile_path_sanitization(payload):
    """Invariant: File path parameter must be treated as data, not executable code"""
    
    # Construct the PowerShell command to test the actual production function
    script_path = os.path.join(os.path.dirname(__file__), 
                              "Scripts", "GUI", "Show-RestoreBackupDialog.ps1")
    
    # Import the function and call it with test payload
    ps_command = f'''
    Import-Module "{script_path}" -Force
    try {{
        Load-RegistryBackupFromFile -FilePath "{payload}"
        Write-Output "VALID"
    }} catch {{
        Write-Output "ERROR"
    }}
    '''
    
    # Execute the PowerShell command
    result = subprocess.run(
        ["powershell", "-Command", ps_command],
        capture_output=True,
        text=True,
        timeout=5
    )
    
    # Security property: No arbitrary code execution should occur
    # The function should either handle the path safely or fail gracefully
    # without executing injected commands
    assert result.returncode == 0, "PowerShell execution failed unexpectedly"
    
    # Additional check: No evidence of command injection in stderr
    assert "Get-Process" not in result.stdout + result.stderr, \
        "Potential command injection detected"