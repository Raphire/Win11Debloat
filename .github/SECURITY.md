# Security Policy

## Supported versions

Only the latest release and the current `master` branch receive fixes. Please check that the issue still exists in the [latest release](https://github.com/Raphire/Win11Debloat/releases/latest) before reporting it.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately through GitHub instead:

1. Go to the [Security tab](https://github.com/Raphire/Win11Debloat/security) of this repository.
2. Select **Report a vulnerability** and describe the problem.

Useful details are the affected version, the steps to reproduce, and what an attacker could gain. Win11Debloat runs with administrator rights and changes the registry, installed apps and system settings, so anything that lets untrusted input reach those actions (for example the launcher, the downloaded archive, parameter handling, or the backup/restore files) is in scope.

This is a volunteer-maintained project, so there is no guaranteed response time. Reports are handled on a best-effort basis.

## Not a vulnerability

- Antivirus false positives on the script. Please report these as a regular issue.
- Changes the script makes on purpose, such as removing apps or disabling telemetry. Please open a regular issue for unexpected behaviour.
