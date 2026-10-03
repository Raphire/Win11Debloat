# Project Map

Win11Debloat is a Windows 11 PowerShell/WPF debloating tool. The USB workflow in this change keeps the existing apply, registry-backup, restore-point, and app-validation pipeline.

## Entry points

- `Run.bat` → `Scripts/CLI/Start-UsbWorkflow.ps1` — Polish USB menu, same-account UAC elevation and per-run logs.
- `Win11Debloat.ps1` — main Windows PowerShell 5.1 entry point.
- `Scripts/Get.ps1` — existing download-and-launch entry point.
- `Scripts/Run-Tests.ps1` — Pester 5 test runner.

## Changed modules

- `Config/UsbPresets.json` — data definitions for Normal, Aggressive, and Gaming.
- `Scripts/Helpers/Import-UsbPreset.ps1` — validates preset settings and app IDs before adding active parameters.
- `Scripts/Features/Set-Wallpaper.ps1` — applies the current-user wallpaper and stores local rollback manifests.
- `Scripts/Helpers/Usb-WorkflowHelpers.ps1` — menu mapping, wallpaper enumeration, Win32 argument quoting and exit-status reporting.
- `Config/Languages/` — GUI resources. The USB menu requests `pl-PL` from the separate Polish localization contribution; existing English fallback remains available if those resources are absent.
- `Tests/Import-UsbPreset.Tests.ps1` and `Tests/Set-Wallpaper.Tests.ps1` — focused preset and wallpaper contracts.

## Data flow

`Run.bat` → `Start-UsbWorkflow.ps1` → elevated `Win11Debloat.ps1` → `Import-UsbPreset` → existing `Invoke-AllChanges` → local backups and USB logs.

`Set-WallpaperFromPath` converts the selected image (or built-in black) to a unique local BMP, saves the previous image and desktop settings, then refreshes through `SystemParametersInfo`. `Restore-WallpaperFromBackup` validates the computer/account manifest and uses the newest local backup. Wallpaper data lives in LocalAppData; USB-mode registry backups and saved settings live in ProgramData. Wallpaper actions are excluded from saved settings.

## Verification

- JSON: `jq empty <file>` on macOS.
- Full tests: `.\Scripts\Run-Tests.ps1 -Bootstrap` on Windows PowerShell 5.1.
- Release acceptance: a Windows 11 VM or physical laptop must verify UAC, Appx/WinGet removal, registry backup/restore, wallpaper application, and all USB menu paths.
- Existing architecture: [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md#architecture--design). USB operation and acceptance: [README.pl-PL.md](README.pl-PL.md).

## Conventions

- Existing repository code comments and documentation remain English unless user-facing Polish text is required.
- New user-facing USB and GUI text is Polish; stable parameter names, feature IDs, and JSON keys remain unchanged.
- `@uses`/`@used_by` tags are not added where the repository has no existing tag convention; file-level relationships are documented here.
