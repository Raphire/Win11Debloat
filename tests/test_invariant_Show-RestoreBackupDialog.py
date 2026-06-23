import pytest
import subprocess
import os
import shutil
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT_PATH = os.path.join(REPO_ROOT, "Scripts", "Features", "RestoreRegistryBackup.ps1")
POWERSHELL = shutil.which("powershell") or r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

PS_TEMPLATE = '''
param([string]$TestPath)
Import-Module "{script_path}" -Force
try {{
    Load-RegistryBackupFromFile -FilePath $TestPath
    Write-Output "VALID"
}} catch {{
    Write-Output "ERROR: $_"
}}
'''.format(script_path=SCRIPT_PATH.replace("\\", "\\\\"))


@pytest.mark.parametrize("payload,expect_error,check_no_file", [
    # Exact exploit case - PowerShell command injection via path
    ("C:\\temp\\backup.reg; Get-Process | Out-File C:\\temp\\hacked.txt", True, "C:\\temp\\hacked.txt"),

    # Boundary case - Path with PowerShell variable expansion
    ("$env:USERPROFILE\\malicious.reg", True, None),

    # Valid input - Normal path (file won't exist, so expect graceful failure)
    ("C:\\backups\\restore.reg", True, None),
])
def test_LoadRegistryBackupFromFile_path_sanitization(payload, expect_error, check_no_file):
    """Invariant: File path parameter must be treated as data, not executable code."""
    with tempfile.NamedTemporaryFile(suffix=".ps1", mode="w", delete=False) as f:
        f.write(PS_TEMPLATE)
        temp_script = f.name

    try:
        result = subprocess.run(
            [POWERSHELL, "-ExecutionPolicy", "Bypass", "-File", temp_script, payload],
            capture_output=True,
            text=True,
            timeout=10
        )
        output = result.stdout + result.stderr

        if expect_error:
            assert "ERROR" in output, \
                f"Expected graceful failure for payload {payload!r}, got: {output!r}"

        if check_no_file:
            assert not os.path.exists(check_no_file), \
                f"Command injection detected: {check_no_file} was created by payload {payload!r}"
    finally:
        os.unlink(temp_script)
