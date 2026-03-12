# How to Contribute?

We welcome contributions from the community. You can contribute to Win11Debloat by:
- Reporting issues and bugs [here](https://github.com/Raphire/Win11Debloat/issues/new?template=bug_report.yml)
- Submitting feature requests [here](https://github.com/Raphire/Win11Debloat/issues/new?template=feature_request.yml)
- Testing Win11Debloat
- Creating a pull request
- Improving the documentation

# Testing Win11Debloat

You can help us test the latest changes and additions to the script. If you encounter any issues, please report them [here](https://github.com/Raphire/Win11Debloat/issues/new?template=bug_report.yml).

> [!WARNING]
> The prerelease version of Win11Debloat is meant for developers to test the script. Don't use this in production environments!

You can launch the prerelease version of Win11Debloat by running this command:
```ps1
& ([scriptblock]::Create((irm "https://debloat.raphi.re/dev")))
```

# Contributing Code

## Getting Started

### Fork and Clone the Repository

1. **Fork the project** on GitHub by clicking the "Fork" button at the top right of the repository page.

2. **Clone the repository** to your local machine:
   ```powershell
   git clone https://github.com/YOUR-USERNAME/Win11Debloat.git
   cd Win11Debloat
   ```

3. **Create a new branch** for your contribution:
   ```powershell
   git checkout -b feature/your-feature-name
   ```

### Running the Script Locally

1. Open PowerShell as an administrator
2. Enable script execution if necessary:
   ```powershell
   Set-ExecutionPolicy Unrestricted -Scope Process -Force
   ```
3. Navigate to your Win11Debloat directory
4. Run the script:
   ```powershell
   .\Win11Debloat.ps1
   ```

## Implementation Guidelines

### Project Structure

Understanding the project structure is essential for contributing effectively:

```
Win11Debloat/
├── Win11Debloat.ps1             # Main PowerShell script
├── Scripts/                     # Additional PowerShell scripts and functions
│    └── Get.ps1                 # Script used for the quick launch method to automatically download and run Win11debloat
├── Config/
│   ├── Apps.json                # List of supported apps for removal
│   ├── DefaultSettings.json     # Default configuration preset
│   ├── Features.json            # All features with metadata
│   └── LastUsedSettings.json    # Last used configuration (generated during use)
├── Regfiles/                    # Registry files for each feature
└── Schemas/                     # XAML Schemas for GUI elements
```

### Best Practices

1. **Test Thoroughly**: Always test your changes on a Windows test environment before submitting. This includes undoing tweaks and running script as another user and in Sysprep mode.
2. **Document Changes**: Update the `README.md` and other relevant documentation. Wiki documentation will be generated/updated based on the `Features.json` and `Apps.json` files.
3. **Follow Existing Patterns**: Look at existing implementations for guidance.
4. **Use Clear Naming**: Choose descriptive names for features, IDs, and registry files.
5. **Minimal Changes**: Registry files should only modify what's necessary. Avoid using policies where possible.
6. **Comment Your Code**: Add comments explaining your reasoning for complex logic in PowerShell scripts.
7. **Version Constraints**: Use `MinVersion` and `MaxVersion` if a feature only applies to specific Windows versions.
8. **Limit pull requests to 1 feature**: Keep pull requests limited to just one feature, this makes it easier to review your changes.

### Code Style

- Use **4 spaces** for indentation in PowerShell scripts
- Use **2 spaces** for indentation in JSON files
- Follow existing naming conventions
- Keep lines reasonable in length
- Use descriptive variable names
- Try to limit your indentation to a max of 4-5 levels, if possible.
- Use [Segoe Fluent Icon Assets](https://learn.microsoft.com/en-us/windows/apps/design/iconography/segoe-fluent-icons-font) for icons.

### Common Pitfalls

Avoid these common mistakes when contributing:

1. **Forgetting Get.ps1**: When adding a new command-line parameter, contributors often remember to add it to `Win11Debloat.ps1` but forget to add the same parameter to `Scripts/Get.ps1`. Both files **must** have matching parameters.

2. **Missing Registry Files**: Always create an `Undo` registry file for reversibility, aswell as a `Sysprep` registry file for Sysprep mode.

3. **Incorrect Registry Hives for Sysprep**: Sysprep registry files apply changes to Windows' default user, registry keys in the `HKEY_CURRENT_USER` hive must use `hkey_users\default` instead. Ensure you update **all** registry keys in the file.

4. **Wrong Registry File Location**:
   - Main action files go in `Regfiles/`
   - Undo files go in `Regfiles/Undo/`
   - Sysprep files go in `Regfiles/Sysprep/`

   Placing files in the wrong directory will cause the script to fail when trying to apply or undo changes.

6. **Not Testing Undo Functionality**: Always test that your undo registry file properly reverts all changes. A feature that can't be undone will frustrate users.

7. **Not Testing User/Sysprep Functionality**: Always test that your feature works when applied to another user or to the Windows default user with Sysprep. Sysprep changes can be tested by creating new users after running the script.

7. **Missing Category**: Features without a `Category` field (set to `null`) won't appear in the GUI. This is intentional for command-line-only features, make sure this is what you want before submitting.

8. **Hardcoded Paths**: When writing PowerShell logic, use `$PSScriptRoot` and script variables instead of hardcoded paths. This ensures the script works regardless of where it's installed.

## Implementing New Features

### Adding Support for a New App

> [!NOTE]
> The script automatically generates the app options for the GUI from the app information in the Apps.json file.

To add a new app that can be removed via Win11Debloat:

1. **Find the AppId**: To find the correct AppId for an app:
   ```powershell
   Get-AppxPackage | Select-Object Name, PackageFullName
   ```

2. **Edit `Config/Apps.json`**: Add a new entry to the `"Apps"` array:
   ```json
   {
     "FriendlyName": "Display Name",
     "AppId": "AppPackageIdentifier",
     "Description": "Brief description of the app",
     "SelectedByDefault": true|false
   }
   ```

3. **Follow the Guidelines**:
- Use clear, user-friendly names for `FriendlyName`
- Set `SelectedByDefault` to `true` only for apps that are largely considered bloatware, otherwise set to `false`
- Provide a concise description explaining what the app does

### Adding a New Feature

Features are defined in `Config/Features.json` and can modify Windows settings via registry files or PowerShell commands.

> [!NOTE]
> For simple features that just include a registry change, no actual coding is required in the main script except for adding the corresponding command-line parameters. The GUI is automatically built using the information in the Features.json file.

#### 1a. Create the Registry File(s)

Create new registry files in the `Regfiles/` directory:

- **Disable file**: `Disable_YourFeature.reg`
- **Enable file**: `Undo/Enable_YourFeature.reg` (for reverting)
- **Sysprep file**: `Sysprep/Disable_YourFeature.reg` (for Sysprep mode)

Example registry file structure:
```reg
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\YourPath]
"SettingName"=dword:00000000
```

A Sysprep registry file should apply the same changes as the normal action. Replace the hive of registry keys that start with `HKEY_CURRENT_USER` with `hkey_users\default`. For example:
```reg
Windows Registry Editor Version 5.00

[hkey_users\default\Software\Microsoft\Windows\CurrentVersion\YourPath]
"SettingName"=dword:00000000
```

#### 1b. Implement the Feature Logic

If your feature requires more than just applying a registry file, add custom logic to the main script in the appropriate section. In most cases this will involve creating a new entry in the `ExecuteParameter` function for your new feature.

#### 2. Add Feature to Features.json

Add your feature to the `"Features"` array in `Config/Features.json`:

```json
{
  "FeatureId": "YourFeatureId",
  "Label": "Short label describing the feature",
  "ToolTip": "Detailed explanation of what this feature does and its impact.",
  "Category": "Privacy & Suggested Content",
  "Priority": 1,
  "Action": "Disable",
  "RegistryKey": "Disable_YourFeature.reg",
  "ApplyText": "Disabling your feature...",
  "UndoAction": "Enable",
  "RegistryUndoKey": "Enable_YourFeature.reg",
  "RequiresReboot": false,
  "MinVersion": null,
  "MaxVersion": null
}
```

**Field Descriptions**:
- `FeatureId`: Unique identifier (must match parameter name in Win11Debloat.ps1 and Get.ps1)
- `Label`: Short description shown in the UI, written in a way to fit with the Action or UndoAction prefixed
- `ToolTip`: Detailed explanation of what the feature does, used for tooltips in the GUI
- `Category`: One of the predefined categories (see Categories array in Features.json), features without a category won't be loaded into the GUI.
- `Priority`: Optional. The priority value (int) is used to sort features within a category. If this field is omitted the feature will be sorted based on the order in the Features.json file.
- `Action`: Action word for the feature (e.g., "Disable", "Enable", "Hide", "Show")
- `RegistryKey`: Filename of the registry file to apply (in Regfiles/ directory) or null if feature does not require registry changes
- `ApplyText`: Message shown when applying the feature
- `UndoAction`: Action word for reverting (e.g., "Enable", "Show")
- `RegistryUndoKey`: Filename of the registry file to revert changes or null if feature does not require registry changes
- `RequiresReboot`: Optional boolean. Set to `true` if the feature requires a system reboot to take effect
- `MinVersion`: Minimum Windows build version (e.g., "22000") or null
- `MaxVersion`: Maximum Windows version or null

#### 3. Add Command-Line Parameter

Add a corresponding parameter to both `Win11Debloat.ps1` AND `Scripts/Get.ps1`, the parameter name should match the FeatureId you have defined in `Features.json`. In most cases this will be a switch parameter, example:
```powershell
[switch]$YourFeatureId,
```

### Adding a Feature to the Default Preset

> [!IMPORTANT]
> The default preset is intentionally conservative. Features added to it should be thoroughly tested and widely beneficial. When in doubt, leave the feature out of the default preset.

The default preset (`Config/DefaultSettings.json`) defines which features are automatically applied when users run Win11Debloat in "Default Mode" or with the `-RunDefaults` parameter. This preset should include features that are widely considered to improve the Windows experience without breaking functionality.

**When to add a feature to the default preset:**
- The feature removes obvious bloatware or distractions
- The feature enhances privacy without breaking core functionality
- The feature is generally non-controversial and beneficial to most users
- The change can be easily reverted if needed

**When NOT to add a feature to the default preset:**
- The feature significantly changes core Windows behavior
- The feature might break applications or workflows for some users
- The feature is highly opinionated or preference-based
- The feature is experimental or not thoroughly tested

To add your feature to the default preset, edit `Config/DefaultSettings.json` and add a new entry to the `"Settings"` array:

```json
{
  "Name": "YourFeatureId",
  "Value": true
}
```

**Field Descriptions**:
- `Name`: Must exactly match the `FeatureId` from Features.json
- `Value`: Set to `true` to enable the feature in default mode

**Example:**
```json
{
  "Version": "1.0",
  "Settings": [
    {
      "Name": "CreateRestorePoint",
      "Value": true
    },
    {
      "Name": "DisableTelemetry",
      "Value": true
    },
    {
      "Name": "YourFeatureId",
      "Value": true
    }
  ]
}
```

### Adding a Category

To add a new category for organizing features:

- Add a new category entry to the `"Categories"` array in `Config/Features.json`:
   ```json
   {
     "Name": "Your Category Name",
     "Icon": "&#xE#### ;"
   }
   ```

> [!TIP]
> Use [Segoe Fluent Icon Assets](https://learn.microsoft.com/en-us/windows/apps/design/iconography/segoe-fluent-icons-font) for icon codes.

### Adding UI Groups

UI Groups allow features to be grouped together in the GUI with a combobox (dropdown) selection:

```json
{
  "GroupId": "UniqueGroupId",
  "Label": "Display label for the group",
  "ToolTip": "Explanation of what this group controls",
  "Category": "Category Name",
  "Priority": 1,
  "Values": [
    {
      "Label": "Option 1",
      "FeatureIds": ["FeatureId1"]
    },
    {
      "Label": "Option 2",
      "FeatureIds": ["FeatureId2"]
    }
  ]
}
```

## Submitting a Pull Request

1. **Commit your changes** with clear, descriptive commit messages:
   ```powershell
   git add .
   git commit -m "Add feature: Description of your changes"
   ```

2. **Push to your fork**:
   ```powershell
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** on GitHub:
   - Go to the original Win11Debloat repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Provide a clear description of your changes, include references to the registry keys used
   - Reference any related issues

4. **Respond to feedback**: Be prepared to make adjustments based on code review feedback.

# Questions?

If you have questions about contributing, feel free to:
- Open a [discussion](https://github.com/Raphire/Win11Debloat/discussions)
- Comment on an existing issue
- Ask in your pull request