# ==============================================================================
#  Localize.ps1  -  Optional UI localization layer for Win11Debloat (Hebrew)
# ==============================================================================
#  This is an OPT-IN, ADD-ON layer. By default the UI language is English and
#  every function here is a no-op, so the script behaves exactly like upstream.
#  A translation is only applied when the user opts in, either with:
#      .\Win11Debloat.ps1 -Language he
#  or by setting the environment variable WIN11DEBLOAT_LANG=he
#
#  When active it provides:
#    * A single English -> translation dictionary ($script:HeStrings).
#    * Get-LocalizedString / Format-Localized helpers used at dynamic call sites.
#    * Invoke-WindowLocalization, which walks a loaded WPF window, sets the
#      window to right-to-left (RTL) and replaces every visible string with its
#      translation via the dictionary.
#    * Localize-FeaturesData, which translates the display fields of the parsed
#      Features.json object at runtime (labels, tooltips, apply text, etc.).
#
#  Strings that are read back by program logic (e.g. TabItem.Header identifiers
#  such as "App Removal"/"Tweaks") are intentionally NOT translated here so the
#  original control flow keeps working. The few visible-but-logic-coupled values
#  (the app-removal scope combo) are decoupled in their own scripts to compare
#  on SelectedIndex instead of on the displayed text.
#
#  Adding another language only requires a second dictionary keyed on the same
#  English source strings; no other changes are needed.
# ==============================================================================

# Active UI language. Defaults to English (no-op). Set via the -Language script
# parameter (shared scope) or the WIN11DEBLOAT_LANG environment variable.
$script:UILanguage = 'en'
try {
    if ($Language) {
        $script:UILanguage = ([string]$Language).Trim().ToLowerInvariant()
    }
    elseif ($env:WIN11DEBLOAT_LANG) {
        $script:UILanguage = ([string]$env:WIN11DEBLOAT_LANG).Trim().ToLowerInvariant()
    }
}
catch { $script:UILanguage = 'en' }

# Returns $true only when a non-English translation is active. All localization
# entry points below short-circuit to no-ops when this is $false.
function Test-LocalizationActive {
    return ($script:UILanguage -eq 'he')
}

# Case-sensitive dictionary so keys that differ only by case (e.g. "Current User"
# vs "Current user") stay distinct and exact-match lookups are predictable.
$script:HeStrings = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)

# Merge a block of translations. Duplicate keys across blocks are tolerated
# (last definition wins) so the same phrase can safely appear in more than one
# section without breaking dot-sourcing.
function Add-LocStrings {
    param([hashtable]$Map)
    foreach ($k in $Map.Keys) { $script:HeStrings[$k] = $Map[$k] }
}

# Merge a flat list of alternating key,value pairs. Unlike a hashtable literal,
# an array tolerates repeated keys (last wins), which is convenient for the
# large Features/Apps blocks where the same English phrase recurs many times.
function Add-LocPairs {
    param([object[]]$Pairs)
    for ($i = 0; $i -lt $Pairs.Count - 1; $i += 2) {
        $script:HeStrings[[string]$Pairs[$i]] = [string]$Pairs[$i + 1]
    }
}

# ------------------------------------------------------------------------------
#  Common buttons, navigation, titlebar & menu
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'OK'                         = 'אישור'
    'Cancel'                     = 'ביטול'
    'Yes'                        = 'כן'
    'No'                         = 'לא'
    'Close'                      = 'סגירה'
    'Confirm'                    = 'אישור'
    'Back'                       = 'הקודם'
    'Next'                       = 'הבא'
    'Options'                    = 'אפשרויות'
    'Loading apps...'            = 'טוען אפליקציות...'
    'Quick Select'               = 'בחירה מהירה'
    'Clear Selection'            = 'ניקוי הבחירה'
    'Search app'                 = 'חיפוש אפליקציה'
    'Search setting'             = 'חיפוש הגדרה'
    'Support the creator'        = 'תמיכה ביוצר'
    'Import config'              = 'ייבוא תצורה'
    'Export config'              = 'ייצוא תצורה'
    'Restore backup'             = 'שחזור גיבוי'
    'Documentation'              = 'תיעוד'
    'Report a bug'               = 'דיווח על תקלה'
    'Logs'                       = 'יומנים'
    'About'                      = 'אודות'
    'Import configuration'       = 'ייבוא תצורה'
    'Export configuration'       = 'ייצוא תצורה'
    'Restore registry backup'    = 'שחזור גיבוי רישום'
}

# ------------------------------------------------------------------------------
#  Home tab
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Welcome to Win11Debloat'                                  = 'ברוכים הבאים ל-Win11Debloat'
    'Your clean Windows experience is just a few clicks away!' = 'חוויית Windows נקייה במרחק כמה הקלקות בלבד!'
    'What user do you want to apply changes to?'               = 'על איזה משתמש להחיל את השינויים?'
    'Apply Changes To'                                         = 'החלת שינויים על'
    'Current User'                                             = 'המשתמש הנוכחי'
    'Current User ({0})'                                       = 'המשתמש הנוכחי ({0})'
    'Other User'                                               = 'משתמש אחר'
    'Windows Default User (Sysprep)'                           = 'משתמש ברירת המחדל של Windows ‏(Sysprep)'
    'Enter username'                                           = 'הזן שם משתמש'
    'Default Mode'                                             = 'מצב ברירת מחדל'
    'Quickly select the recommended settings'                  = 'בחירה מהירה של ההגדרות המומלצות'
    'Custom Setup'                                             = 'התקנה מותאמת אישית'
    'Manually select your preferred settings'                  = 'בחירה ידנית של ההגדרות המועדפות עליך'
}

# ------------------------------------------------------------------------------
#  App Removal tab
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'App Removal'                                                = 'הסרת אפליקציות'
    'Select which apps you want to remove from your system'     = 'בחר אילו אפליקציות להסיר מהמערכת'
    'Select or clear app presets'                               = 'בחירה או ניקוי של ערכות אפליקציות'
    'App Presets'                                               = 'ערכות אפליקציות'
    'Clear all selected apps'                                   = 'ניקוי כל האפליקציות שנבחרו'
    'Default apps'                                              = 'אפליקציות ברירת מחדל'
    'Select the apps that are safe to remove for most users'   = 'בחירת האפליקציות שבטוח להסיר עבור רוב המשתמשים'
    'Default selection'                                         = 'בחירת ברירת מחדל'
    'Last used apps'                                            = 'אפליקציות בשימוש אחרון'
    'Select the apps that were removed the last time Win11Debloat was run' = 'בחירת האפליקציות שהוסרו בפעם האחרונה שבה Win11Debloat הופעל'
    'Last used selection'                                       = 'הבחירה האחרונה בשימוש'
    'Only show installed apps'                                  = 'הצג רק אפליקציות מותקנות'
    'Name'                                                      = 'שם'
    'Description'                                               = 'תיאור'
    'App ID'                                                    = 'מזהה אפליקציה'
}

# ------------------------------------------------------------------------------
#  Tweaks tab
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'System Tweaks'                                                                         = 'התאמות מערכת'
    'Select which tweaks you want to apply to your system, hover over settings for more information' = 'בחר אילו התאמות להחיל על המערכת; רחף מעל ההגדרות לקבלת מידע נוסף'
    'Select tweak presets'                                                                  = 'בחירת ערכות התאמות'
    'Tweak Presets'                                                                         = 'ערכות התאמות'
    'Clear all selected tweaks'                                                             = 'ניקוי כל ההתאמות שנבחרו'
    'Default settings'                                                                      = 'הגדרות ברירת מחדל'
    'Select the settings that are recommended for most people'                              = 'בחירת ההגדרות המומלצות עבור רוב המשתמשים'
    'Last used settings'                                                                    = 'הגדרות בשימוש אחרון'
    'Select the settings that were used the last time Win11Debloat was run'                 = 'בחירת ההגדרות ששימשו בפעם האחרונה שבה Win11Debloat הופעל'
    'Privacy & Suggested Content'                                                           = 'פרטיות ותוכן מוצע'
    'Select all Privacy & Suggested Content tweaks'                                         = 'בחירת כל ההתאמות של פרטיות ותוכן מוצע'
    'All Privacy and Suggested Content'                                                     = 'כל הפרטיות והתוכן המוצע'
    'AI features'                                                                           = 'תכונות בינה מלאכותית'
    'Select all AI feature tweaks'                                                          = 'בחירת כל ההתאמות של תכונות הבינה המלאכותית'
    'All AI features'                                                                       = 'כל תכונות הבינה המלאכותית'
    'Detect applied tweaks'                                                                 = 'זיהוי התאמות שהוחלו'
    'Detect all tweaks currently applied for the current user.'                             = 'זהה את כל ההתאמות שמוחלות כעת עבור המשתמש הנוכחי.'
    'No Change'                                                                             = 'ללא שינוי'
    'This tweak is already applied and cannot be undone automatically. Visit the Win11Debloat wiki for instructions on how to manually revert this change.' = 'התאמה זו כבר הוחלה ולא ניתן לבטל אותה באופן אוטומטי. בקר בוויקי של Win11Debloat לקבלת הוראות כיצד לבטל שינוי זה ידנית.'
}

# ------------------------------------------------------------------------------
#  Deployment Settings tab
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Deployment Settings'                              = 'הגדרות פריסה'
    'Configure how your changes will be applied and more' = 'הגדר כיצד השינויים שלך יוחלו, ועוד'
    'Changes will be applied to'                       = 'השינויים יוחלו על'
    'The currently logged-in user profile.'            = 'פרופיל המשתמש המחובר כעת.'
    'Apps will be removed for'                          = 'האפליקציות יוסרו עבור'
    'App Removal Scope'                                 = 'היקף הסרת האפליקציות'
    'All users'                                         = 'כל המשתמשים'
    'Current user only'                                 = 'המשתמש הנוכחי בלבד'
    'Target user only'                                  = 'משתמש היעד בלבד'
    'Apps will be removed for all users and from the Windows image to prevent reinstallation for new users.' = 'האפליקציות יוסרו עבור כל המשתמשים וכן מתמונת Windows, כדי למנוע התקנה מחדש עבור משתמשים חדשים.'
    'Options'                                           = 'אפשרויות'
    'Create a system restore point (Recommended)'       = 'צור נקודת שחזור מערכת (מומלץ)'
    'Restart the Windows Explorer process to apply all changes immediately' = 'הפעל מחדש את תהליך סייר Windows כדי להחיל את כל השינויים באופן מיידי'
    'Review selected changes'                           = 'סקירת השינויים שנבחרו'
    'Apply Changes'                                     = 'החל שינויים'
}

# ------------------------------------------------------------------------------
#  Dynamic strings: user-selection & app-removal scope descriptions, status,
#  overview, validation messages, bubbles. Templated strings use {0}/{1}.
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'The currently logged-in user profile'                      = 'פרופיל המשתמש המחובר כעת'
    'The currently logged-in user profile: {0}'                 = 'פרופיל המשתמש המחובר כעת: {0}'
    'A different user profile on this system'                   = 'פרופיל משתמש אחר במערכת זו'
    'A different user profile on this system: {0}'              = 'פרופיל משתמש אחר במערכת זו: {0}'
    'The default user template, affecting all new users created after this point. Useful for Sysprep deployment.' = 'תבנית משתמש ברירת המחדל, המשפיעה על כל המשתמשים החדשים שייווצרו מנקודה זו ואילך. שימושי לפריסת Sysprep.'
    'Apps will only be removed for the current user.'           = 'האפליקציות יוסרו עבור המשתמש הנוכחי בלבד.'
    'Apps will only be removed for the specified target user.'  = 'האפליקציות יוסרו עבור משתמש היעד שצוין בלבד.'
    '[Recommended] Safe to remove for most users'               = '[מומלץ] בטוח להסרה עבור רוב המשתמשים'
    '[Not Recommended] Only remove if you know what you are doing' = '[לא מומלץ] הסר רק אם אתה יודע מה אתה עושה'
    "[Optional] Remove if you don't need this app"              = '[אופציונלי] הסר אם אינך זקוק לאפליקציה זו'
    '{0} app(s) selected for removal'                           = '{0} אפליקציות נבחרו להסרה'
    'Remove {0} application(s)'                                 = 'הסרת {0} אפליקציות'
    'Undo: {0}'                                                 = 'ביטול: {0}'
    'No changes have been selected.'                            = 'לא נבחרו שינויים.'
    'Selected Changes'                                          = 'השינויים שנבחרו'
    "Open wiki for more info on '{0}' tweaks"                   = 'פתח את הוויקי למידע נוסף על ההתאמות של {0}'
    # username validation
    'Please enter a valid username.'                            = 'אנא הזן שם משתמש תקין.'
    'Invalid Username'                                          = 'שם משתמש לא תקין'
    'Please enter a username'                                   = 'אנא הזן שם משתמש'
    "Cannot enter your own username, use 'Current User' option instead" = 'לא ניתן להזין את שם המשתמש שלך; השתמש באפשרות "המשתמש הנוכחי" במקום זאת'
    'User not found, please enter a valid username'             = 'המשתמש לא נמצא; אנא הזן שם משתמש תקין'
    'User found: {0}'                                           = 'המשתמש נמצא: {0}'
    # bubble hint
    'View the selected changes here'                            = 'צפה כאן בשינויים שנבחרו'
}

# ------------------------------------------------------------------------------
#  Message boxes (titles & messages), incl. logs/import/export/restore errors
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'No changes have been selected, please select at least one option to proceed.' = 'לא נבחרו שינויים. אנא בחר לפחות אפשרות אחת כדי להמשיך.'
    'No Changes Selected'                                       = 'לא נבחרו שינויים'
    'Error'                                                     = 'שגיאה'
    'Logs'                                                      = 'יומנים'
    'No logs folder found at: {0}'                              = 'לא נמצאה תיקיית יומנים בנתיב: {0}'
    'Unable to open export configuration dialog: {0}'           = 'לא ניתן לפתוח את חלון ייצוא התצורה: {0}'
    'Export Configuration Failed'                               = 'ייצוא התצורה נכשל'
    'Unable to open import configuration dialog: {0}'           = 'לא ניתן לפתוח את חלון ייבוא התצורה: {0}'
    'Import Configuration Failed'                               = 'ייבוא התצורה נכשל'
    'Unable to open restore backup dialog: {0}'                 = 'לא ניתן לפתוח את חלון שחזור הגיבוי: {0}'
    'Restore Backup Failed'                                     = 'שחזור הגיבוי נכשל'
    'An error occurred during initialization: {0}'              = 'אירעה שגיאה במהלך האתחול: {0}'
    'Initialization Error'                                      = 'שגיאת אתחול'
    'Unable to load list of installed apps via WinGet.'         = 'לא ניתן לטעון את רשימת האפליקציות המותקנות באמצעות WinGet.'
    'Configuration exported successfully.'                      = 'התצורה יוצאה בהצלחה.'
    'Configuration imported successfully.'                      = 'התצורה יובאה בהצלחה.'
    'Failed to export configuration'                            = 'ייצוא התצורה נכשל'
    'Failed to read configuration file'                         = 'קריאת קובץ התצורה נכשלה'
    'Invalid configuration file format.'                        = 'תבנית קובץ התצורה אינה תקינה.'
    'The selected file contains no importable data.'            = 'הקובץ שנבחר אינו מכיל נתונים הניתנים לייבוא.'
    'Invalid Config'                                            = 'תצורה לא תקינה'
    'Import/Export window schema file could not be found.'      = 'לא נמצא קובץ הסכמה של חלון הייבוא/ייצוא.'
}

# ------------------------------------------------------------------------------
#  Apply Changes modal
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Applying Changes'                                                          = 'מחיל שינויים'
    'Preparing...'                                                              = 'בהכנה...'
    'Step {0} of {1}'                                                           = 'שלב {0} מתוך {1}'
    'Changes Applied'                                                           = 'השינויים הוחלו'
    'Changes Applied with Errors'                                               = 'השינויים הוחלו עם שגיאות'
    'Cancelled'                                                                 = 'בוטל'
    'Script execution was cancelled by the user.'                              = 'הרצת הסקריפט בוטלה על ידי המשתמש.'
    '{0} registry change(s) failed. See console for details.'                  = '{0} שינויי רישום נכשלו. ראה פרטים במסוף.'
    'Your system is ready. Thanks for using Win11Debloat!'                     = 'המערכת שלך מוכנה. תודה שהשתמשת ב-Win11Debloat!'
    'An error occurred while applying changes: {0}'                            = 'אירעה שגיאה במהלך החלת השינויים: {0}'
    'Please note that some changes will only take effect after a reboot. Thanks for using Win11Debloat!' = 'שים לב שחלק מהשינויים ייכנסו לתוקף רק לאחר אתחול. תודה שהשתמשת ב-Win11Debloat!'
    'A reboot is required for these changes to take effect:'                   = 'נדרש אתחול כדי שהשינויים הבאים ייכנסו לתוקף:'
}

# ------------------------------------------------------------------------------
#  About dialog
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'About Win11Debloat' = 'אודות Win11Debloat'
    'Version:'           = 'גרסה:'
    'Author:'            = 'מחבר:'
    'Project:'           = 'פרויקט:'
    "Win11Debloat is a passion project that I maintain in my free time. If you've found this tool useful, please consider making a small donation to support its development. I really appreciate it!" = 'Win11Debloat הוא פרויקט שאני מתחזק באהבה בזמני הפנוי. אם מצאת את הכלי הזה שימושי, אשמח אם תשקול לתרום תרומה קטנה כדי לתמוך בפיתוחו. אני באמת מעריך זאת!'
    'Support me on Ko-fi' = 'תמכו בי ב-Ko-fi'
}

# ------------------------------------------------------------------------------
#  App Selection window (custom apps list generator)
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Win11Debloat Application Selection'                                  = 'בחירת אפליקציות של Win11Debloat'
    'Check apps that you wish to remove, uncheck apps that you wish to keep' = 'סמן אפליקציות שברצונך להסיר, בטל סימון של אפליקציות שברצונך לשמור'
    'Check/Uncheck all'                                                   = 'סימון/ביטול סימון של הכול'
    'Check or Uncheck all'                                                = 'סימון או ביטול סימון של הכול'
}

# ------------------------------------------------------------------------------
#  Import / Export configuration dialog (incl. dynamic detail strings)
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Select Settings to Import/Export'                          = 'בחר הגדרות לייבוא/ייצוא'
    'Export Configuration'                                      = 'ייצוא תצורה'
    'Import Configuration'                                      = 'ייבוא תצורה'
    'Export Settings'                                           = 'ייצוא הגדרות'
    'Import Settings'                                           = 'ייבוא הגדרות'
    'Applications'                                              = 'אפליקציות'
    'Create a configuration file based on the currently selected settings. You can choose which settings categories you wish to include in the export.' = 'צור קובץ תצורה המבוסס על ההגדרות שנבחרו כעת. ניתן לבחור אילו קטגוריות הגדרות לכלול בייצוא.'
    'Choose the settings categories that you wish to import. You can review and modify the imported settings before they are applied.' = 'בחר את קטגוריות ההגדרות שברצונך לייבא. ניתן לסקור ולשנות את ההגדרות המיובאות לפני החלתן.'
    'No selected settings available in this category.'          = 'אין הגדרות נבחרות זמינות בקטגוריה זו.'
    'Default deployment settings'                               = 'הגדרות פריסת ברירת מחדל'
    'Restore Point'                                             = 'נקודת שחזור'
    'Restart Explorer'                                          = 'הפעלה מחדש של הסייר'
    'User: Current User'                                        = 'משתמש: המשתמש הנוכחי'
    'User: Sysprep'                                             = 'משתמש: Sysprep'
    'User: {0}'                                                 = 'משתמש: {0}'
    'App Removal: All Users'                                    = 'הסרת אפליקציות: כל המשתמשים'
    'App Removal: Current User'                                 = 'הסרת אפליקציות: המשתמש הנוכחי'
    'App Removal: {0}'                                          = 'הסרת אפליקציות: {0}'
    'Options: {0}'                                              = 'אפשרויות: {0}'
    'Other User'                                                = 'משתמש אחר'
    '{0} app'                                                   = 'אפליקציה אחת'
    '{0} apps'                                                  = '{0} אפליקציות'
    '{0} tweak'                                                 = 'התאמה אחת'
    '{0} tweaks'                                                = '{0} התאמות'
}

# ------------------------------------------------------------------------------
#  Restore Backup window & wizard
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Restore Backup'                                            = 'שחזור גיבוי'
    'Choose what changes you want to restore.'                  = 'בחר אילו שינויים ברצונך לשחזר.'
    'Restore Registry Backup'                                   = 'שחזור גיבוי רישום'
    'Restore system registry configuration from a backup'       = 'שחזר את תצורת רישום המערכת מתוך גיבוי'
    'Restore Start Menu Backup'                                 = 'שחזור גיבוי תפריט התחל'
    'Restore the Start Menu pinned apps layout from a backup'    = 'שחזר את פריסת האפליקציות המוצמדות בתפריט התחל מתוך גיבוי'
    'This will restore any system registry changes made by Win11Debloat to their previous state. You can review the changes after selecting a backup file. Apps will need to be reinstalled manually.' = 'פעולה זו תשחזר את כל שינויי רישום המערכת שבוצעו על ידי Win11Debloat למצבם הקודם. ניתן לסקור את השינויים לאחר בחירת קובץ גיבוי. אפליקציות יהיה צורך להתקין מחדש ידנית.'
    'Warning: Only use backup files generated by Win11Debloat.' = 'אזהרה: השתמש אך ורק בקבצי גיבוי שנוצרו על ידי Win11Debloat.'
    'File:'                                                     = 'קובץ:'
    'Not selected'                                              = 'לא נבחר'
    'Created:'                                                  = 'נוצר:'
    'N/A'                                                       = 'לא זמין'
    'Target:'                                                   = 'יעד:'
    'The following changes will be reverted:'                   = 'השינויים הבאים יבוטלו:'
    'This will restore the Start Menu pinned apps layout for the current user.' = 'פעולה זו תשחזר את פריסת האפליקציות המוצמדות בתפריט התחל עבור המשתמש הנוכחי.'
    'The following changes will be re-applied:'                 = 'השינויים הבאים יוחלו מחדש:'
    "The following changes won't be reverted:"                  = 'השינויים הבאים לא יבוטלו:'
    'Visit the wiki for more information'                       = 'בקר בוויקי לקבלת מידע נוסף'
    'This will restore the Start Menu pinned apps layout for the selected user(s) using a backup that is automatically created by Win11Debloat. Manually created backups can also be used.' = 'פעולה זו תשחזר את פריסת האפליקציות המוצמדות בתפריט התחל עבור המשתמשים שנבחרו, באמצעות גיבוי שנוצר אוטומטית על ידי Win11Debloat. ניתן להשתמש גם בגיבויים שנוצרו ידנית.'
    'Current user'                                              = 'המשתמש הנוכחי'
    'all users'                                                 = 'כל המשתמשים'
    'the current user'                                          = 'המשתמש הנוכחי'
    'Unknown'                                                   = 'לא ידוע'
    'Unknown feature'                                           = 'תכונה לא ידועה'
    'Automatically find Start Menu backup'                      = 'מצא אוטומטית גיבוי של תפריט התחל'
    'Select backup file'                                        = 'בחר קובץ גיבוי'
    'Restore from backup'                                       = 'שחזר מגיבוי'
    "No Start Menu backup file was found. You can uncheck the 'Automatically find Start Menu backup' option to select a backup file manually." = 'לא נמצא קובץ גיבוי של תפריט התחל. ניתן לבטל את הסימון של האפשרות "מצא אוטומטית גיבוי של תפריט התחל" כדי לבחור קובץ גיבוי ידנית.'
    'No Backup Found'                                           = 'לא נמצא גיבוי'
    'Registry backup restored successfully. Some changes may require a restart to take effect.' = 'גיבוי הרישום שוחזר בהצלחה. ייתכן שחלק מהשינויים יחייבו הפעלה מחדש כדי להיכנס לתוקף.'
    'The Start Menu backup was successfully restored for all users. The changes will apply the next time users sign in.' = 'גיבוי תפריט התחל שוחזר בהצלחה עבור כל המשתמשים. השינויים יוחלו בפעם הבאה שהמשתמשים יתחברו.'
    'The Start Menu backup was successfully restored for the current user. The changes will apply the next time you sign in.' = 'גיבוי תפריט התחל שוחזר בהצלחה עבור המשתמש הנוכחי. השינויים יוחלו בפעם הבאה שתתחבר.'
    'Backup Restored'                                           = 'הגיבוי שוחזר'
    'This will replace the current Start Menu pinned apps layout for {0} with the selected backup.' = 'פעולה זו תחליף את פריסת האפליקציות המוצמדות הנוכחית בתפריט התחל עבור {0} בגיבוי שנבחר.'
}

# ------------------------------------------------------------------------------
#  Confirmation dialogs & restore-point failure
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Are you sure?'                                             = 'האם אתה בטוח?'
    'Are you sure that you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.' = 'האם אתה בטוח שברצונך להסיר את Microsoft Store? לא ניתן להתקין אפליקציה זו מחדש בקלות.'
    'Are you sure that you wish to remove Windows Terminal? Windows Terminal is the default command-line app for Windows. Ensure you are not running Win11Debloat via Windows Terminal before proceeding to avoid a mid-process failure.' = 'האם אתה בטוח שברצונך להסיר את Windows Terminal? ‏Windows Terminal הוא אפליקציית שורת הפקודה המוגדרת כברירת מחדל ב-Windows. ודא שאינך מריץ את Win11Debloat דרך Windows Terminal לפני שתמשיך, כדי למנוע כשל באמצע התהליך.'
    'Force Uninstall Microsoft Edge?'                           = 'להסיר את Microsoft Edge בכפייה?'
    'Unable to uninstall Microsoft Edge via WinGet. Would you like to forcefully uninstall it? NOT RECOMMENDED!' = 'לא ניתן להסיר את Microsoft Edge באמצעות WinGet. האם ברצונך להסיר אותו בכפייה? לא מומלץ!'
    'Failed to create a system restore point. Do you want to continue without a restore point?' = 'יצירת נקודת שחזור מערכת נכשלה. האם ברצונך להמשיך ללא נקודת שחזור?'
    'Restore Point Creation Failed'                             = 'יצירת נקודת השחזור נכשלה'
}

# ------------------------------------------------------------------------------
#  Features.json category names (kept English in logic; localized for display)
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Privacy & Suggested Content' = 'פרטיות ותוכן מוצע'
    'System'                      = 'מערכת'
    'Start Menu & Search'         = 'תפריט התחל וחיפוש'
    'AI'                          = 'בינה מלאכותית'
    'Windows Update'              = 'Windows Update'
    'Taskbar'                     = 'שורת המשימות'
    'Appearance'                  = 'מראה'
    'File Explorer'               = 'סייר הקבצים'
    'Gaming'                      = 'משחקים'
    'Multi-tasking'               = 'ריבוי משימות'
    'Optional Windows Features'   = 'תכונות Windows אופציונליות'
    'Other'                       = 'אחר'
}

# ------------------------------------------------------------------------------
#  Features.json UI groups (labels, tooltips, value labels)
# ------------------------------------------------------------------------------
Add-LocStrings @{
    'Taskbar search style'                                      = 'סגנון החיפוש בשורת המשימות'
    'This setting allows you to customize the appearance of the search box on the taskbar.' = 'הגדרה זו מאפשרת להתאים אישית את מראה תיבת החיפוש בשורת המשימות.'
    'Show search box (Default)'                                  = 'הצג תיבת חיפוש (ברירת מחדל)'
    'Show search icon and label'                                = 'הצג סמל חיפוש ותווית'
    'Show search icon only'                                     = 'הצג סמל חיפוש בלבד'
    'Hide'                                                      = 'הסתר'
    'Show taskbar apps on'                                       = 'הצג את אפליקציות שורת המשימות על'
    'This setting allows you to choose where taskbar app buttons are shown when using multiple monitors.' = 'הגדרה זו מאפשרת לבחור היכן יוצגו לחצני האפליקציות בשורת המשימות בעת שימוש בכמה צגים.'
    'All taskbars (Default)'                                     = 'כל שורות המשימות (ברירת מחדל)'
    'Main taskbar and taskbar where window is open'             = 'שורת המשימות הראשית ושורת המשימות שבה החלון פתוח'
    'Taskbar where window is open'                              = 'שורת המשימות שבה החלון פתוח'
    'Combine taskbar buttons on the main display'               = 'אחד את לחצני שורת המשימות בצג הראשי'
    'This setting allows you to choose how taskbar buttons are combined on the main display.' = 'הגדרה זו מאפשרת לבחור כיצד לאחד את לחצני שורת המשימות בצג הראשי.'
    'Always (Default)'                                           = 'תמיד (ברירת מחדל)'
    'When taskbar is full'                                       = 'כאשר שורת המשימות מלאה'
    'Never'                                                     = 'אף פעם'
    'Combine taskbar buttons on secondary displays'             = 'אחד את לחצני שורת המשימות בצגים משניים'
    'This setting allows you to choose how taskbar buttons are combined on secondary displays.' = 'הגדרה זו מאפשרת לבחור כיצד לאחד את לחצני שורת המשימות בצגים משניים.'
    'Remove pinned apps from the start menu'                     = 'הסר אפליקציות מוצמדות מתפריט התחל'
    'This setting allows you to quickly remove all pinned apps from the start menu.' = 'הגדרה זו מאפשרת להסיר במהירות את כל האפליקציות המוצמדות מתפריט התחל.'
    'Remove for the selected user'                              = 'הסר עבור המשתמש שנבחר'
    'Remove for all users'                                      = 'הסר עבור כל המשתמשים'
    'Open File Explorer to'                                      = 'פתח את סייר הקבצים אל'
    'This setting allows you to choose the default location that File Explorer opens to.' = 'הגדרה זו מאפשרת לבחור את מיקום ברירת המחדל שאליו נפתח סייר הקבצים.'
    'Home (Default)'                                             = 'בית (ברירת מחדל)'
    'This PC'                                                   = 'מחשב זה'
    'Downloads'                                                 = 'הורדות'
    'OneDrive'                                                  = 'OneDrive'
    'Drive letter position'                                      = 'מיקום אות הכונן'
    'This setting allows you to choose where drive letters are shown in File Explorer.' = 'הגדרה זו מאפשרת לבחור היכן יוצגו אותיות הכוננים בסייר הקבצים.'
    'Show drive letters after drive label (Default)'            = 'הצג את אותיות הכונן אחרי תווית הכונן (ברירת מחדל)'
    'Show drive letters before drive label'                     = 'הצג את אותיות הכונן לפני תווית הכונן'
    'Show network drive letters before drive label'             = 'הצג את אותיות כונני הרשת לפני תווית הכונן'
    'Hide all drive letters'                                     = 'הסתר את כל אותיות הכוננים'
    'Show tabs from apps when snapping or pressing Alt+Tab'     = 'הצג כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab'
    'This setting allows you to choose whether to show tabs from apps (such as Edge browser tabs) when snapping windows or pressing Alt+Tab.' = 'הגדרה זו מאפשרת לבחור האם להציג כרטיסיות מאפליקציות (כגון כרטיסיות הדפדפן Edge) בעת הצמדת חלונות או לחיצה על Alt+Tab.'
    "Don't show tabs"                                           = 'אל תציג כרטיסיות'
    'Show 3 most recent tabs (Default)'                         = 'הצג את 3 הכרטיסיות האחרונות (ברירת מחדל)'
    'Show 5 most recent tabs'                                    = 'הצג את 5 הכרטיסיות האחרונות'
    'Show 20 most recent tabs'                                   = 'הצג את 20 הכרטיסיות האחרונות'
    "Start menu 'All Apps' view"                                = 'תצוגת "כל האפליקציות" בתפריט התחל'
    "This setting allows you to change the layout of the 'All Apps' section in the start menu, or hide it entirely. Hiding this section may make it harder to find installed apps on your system. This feature uses policies, which will lock down certain settings." = 'הגדרה זו מאפשרת לשנות את פריסת המקטע "כל האפליקציות" בתפריט התחל, או להסתיר אותו לחלוטין. הסתרת מקטע זה עלולה להקשות על מציאת אפליקציות מותקנות במערכת. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.'
    'Category (Default)'                                         = 'קטגוריה (ברירת מחדל)'
    'Grid'                                                      = 'רשת'
    'List'                                                      = 'רשימה'
}

# ------------------------------------------------------------------------------
#  Features.json - feature labels, tooltips, apply text & undo labels.
#  Passed as flat pairs because many phrases recur across features (last wins).
# ------------------------------------------------------------------------------
Add-LocPairs @(
    # --- App removal related (mostly CLI, but ApplyText shows during apply) ---
    "Remove the apps specified with the 'Apps' parameter", "הסר את האפליקציות שצוינו בפרמטר 'Apps'",
    "The selection of apps to remove, specified as a comma separated list. Use 'Default' (or omit) to use the default apps list", "בחירת האפליקציות להסרה, מצוינת כרשימה מופרדת בפסיקים. השתמש ב-'Default' (או השמט) כדי להשתמש ברשימת האפליקציות המוגדרת כברירת מחדל",
    'Remove custom selection of apps', 'הסר בחירה מותאמת אישית של אפליקציות',
    'Removing selected apps', 'מסיר את האפליקציות שנבחרו',
    'Remove the Xbox App and Xbox Gamebar', 'הסר את אפליקציית Xbox ואת Xbox Game Bar',
    'Removing gaming related apps', 'מסיר אפליקציות הקשורות למשחקים',
    'Remove HP OEM applications', 'הסר אפליקציות יצרן של HP',
    'Removing HP apps', 'מסיר אפליקציות של HP',
    'Create a system restore point', 'צור נקודת שחזור מערכת',

    # --- Privacy & Suggested Content ---
    'Disable telemetry, tracking & targeted ads', 'השבת טלמטריה, מעקב ופרסומות מותאמות',
    'This setting disables telemetry, diagnostic data collection, activity history, app-launch tracking, targeted ads and more. It limits the data that is sent to Microsoft about your device and usage. If you are a Windows Insider, updates may be blocked until optional diagnostic data collection is turned back on.', 'הגדרה זו משביתה טלמטריה, איסוף נתוני אבחון, היסטוריית פעילות, מעקב אחר הפעלת אפליקציות, פרסומות מותאמות ועוד. היא מגבילה את הנתונים הנשלחים ל-Microsoft אודות המכשיר והשימוש שלך. אם אתה חבר בתוכנית Windows Insider, ייתכן שעדכונים ייחסמו עד שאיסוף נתוני האבחון האופציונליים יופעל מחדש.',
    'Disabling telemetry, diagnostic data, activity history, app-launch tracking and targeted ads', 'משבית טלמטריה, נתוני אבחון, היסטוריית פעילות, מעקב אחר הפעלת אפליקציות ופרסומות מותאמות',
    'Enable telemetry, tracking & targeted ads', 'הפעל טלמטריה, מעקב ופרסומות מותאמות',
    'Enabling telemetry, diagnostic data, activity history, app-launch tracking and targeted ads', 'מפעיל טלמטריה, נתוני אבחון, היסטוריית פעילות, מעקב אחר הפעלת אפליקציות ופרסומות מותאמות',
    'Disable tips, tricks & suggested content throughout Windows', 'השבת טיפים, עצות ותוכן מוצע ברחבי Windows',
    'This setting removes many annoying distractions from Windows. This includes things like notifications, reminders and sync provider ads. It also prevents automated installation of suggested apps.', 'הגדרה זו מסירה הסחות דעת מעצבנות רבות מ-Windows. זה כולל דברים כמו התראות, תזכורות ופרסומות של ספקי סנכרון. היא גם מונעת התקנה אוטומטית של אפליקציות מוצעות.',
    'Disabling tips, tricks, suggestions and ads throughout Windows', 'משבית טיפים, עצות, הצעות ופרסומות ברחבי Windows',
    'Enable tips, tricks & suggested content throughout Windows', 'הפעל טיפים, עצות ותוכן מוצע ברחבי Windows',
    'Enabling tips, tricks, suggestions and ads throughout Windows', 'מפעיל טיפים, עצות, הצעות ופרסומות ברחבי Windows',
    'Disable Windows location services & app location access', 'השבת את שירותי המיקום של Windows וגישת אפליקציות למיקום',
    'This will turn off Windows Location Services and deny apps access to your location. This feature uses policies, which will lock down certain settings.', 'פעולה זו תכבה את שירותי המיקום של Windows ותמנע מאפליקציות גישה למיקום שלך. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling Windows location services and app location access', 'משבית את שירותי המיקום של Windows ואת גישת האפליקציות למיקום',
    'Enable Windows location services & app location access', 'הפעל את שירותי המיקום של Windows וגישת אפליקציות למיקום',
    'Enabling Windows location services and app location access', 'מפעיל את שירותי המיקום של Windows ואת גישת האפליקציות למיקום',
    'Disable Find My Device location tracking', 'השבת את מעקב המיקום של "מצא את המכשיר שלי"',
    "This will turn off the 'Find My Device' feature, which periodically sends your device's location to Microsoft. This feature uses policies, which will lock down certain settings.", 'פעולה זו תכבה את התכונה "מצא את המכשיר שלי", השולחת מעת לעת את מיקום המכשיר שלך ל-Microsoft. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling Find My Device location tracking', 'משבית את מעקב המיקום של "מצא את המכשיר שלי"',
    'Enable Find My Device location tracking', 'הפעל את מעקב המיקום של "מצא את המכשיר שלי"',
    'Enabling Find My Device location tracking', 'מפעיל את מעקב המיקום של "מצא את המכשיר שלי"',
    'Disable tips & tricks on the lock screen', 'השבת טיפים ועצות במסך הנעילה',
    'This will turn off the lockscreen spotlight option and disable the tips, tricks and fun facts that appear on the lock screen.', 'פעולה זו תכבה את אפשרות ה-Spotlight במסך הנעילה ותשבית את הטיפים, העצות והעובדות המעניינות המופיעים במסך הנעילה.',
    'Disabling tips & tricks on the lock screen', 'משבית טיפים ועצות במסך הנעילה',
    'Enable tips & tricks on the lock screen', 'הפעל טיפים ועצות במסך הנעילה',
    'Enabling tips & tricks on the lock screen', 'מפעיל טיפים ועצות במסך הנעילה',
    'Disable Windows Spotlight for desktop', 'השבת את Windows Spotlight עבור שולחן העבודה',
    "This will turn off the 'Windows Spotlight' feature for the desktop background, which shows different background images and occasionally tips and fun facts on the desktop. This feature uses policies, which will lock down certain settings.", 'פעולה זו תכבה את התכונה "Windows Spotlight" עבור רקע שולחן העבודה, המציגה תמונות רקע משתנות ולעיתים טיפים ועובדות מעניינות על שולחן העבודה. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    "Disabling the 'Windows Spotlight' desktop background option", 'משבית את אפשרות רקע שולחן העבודה "Windows Spotlight"',
    'Enable Windows Spotlight for desktop', 'הפעל את Windows Spotlight עבור שולחן העבודה',
    "Enabling the 'Windows Spotlight' desktop background option", 'מפעיל את אפשרות רקע שולחן העבודה "Windows Spotlight"',
    'Disable ads, suggestions and newsfeed in Edge', 'השבת פרסומות, הצעות ועדכוני חדשות ב-Edge',
    'This will turn off various distractions from Microsoft Edge such as ads, suggestions and the MSN news feed. This feature uses policies, which will lock down certain settings.', 'פעולה זו תכבה הסחות דעת שונות ב-Microsoft Edge, כגון פרסומות, הצעות והזנת החדשות של MSN. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling ads, suggestions and the MSN news feed in Microsoft Edge', 'משבית פרסומות, הצעות ואת הזנת החדשות של MSN ב-Microsoft Edge',
    'Enable ads, suggestions and newsfeed in Edge', 'הפעל פרסומות, הצעות ועדכוני חדשות ב-Edge',
    'Enabling ads, suggestions and the MSN news feed in Microsoft Edge', 'מפעיל פרסומות, הצעות ואת הזנת החדשות של MSN ב-Microsoft Edge',
    'Hide Microsoft 365 Copilot ads in Settings Home', 'הסתר פרסומות Microsoft 365 Copilot בדף הבית של ההגדרות',
    'This will turn off the Microsoft 365 Copilot ads that appear in the Settings Home page.', 'פעולה זו תכבה את פרסומות Microsoft 365 Copilot המופיעות בדף הבית של אפליקציית ההגדרות.',
    'Disabling Microsoft 365 Copilot ads in Settings Home', 'משבית פרסומות Microsoft 365 Copilot בדף הבית של ההגדרות',
    'Show Microsoft 365 Copilot ads in Settings Home', 'הצג פרסומות Microsoft 365 Copilot בדף הבית של ההגדרות',
    'Enabling Microsoft 365 Copilot ads in Settings Home', 'מפעיל פרסומות Microsoft 365 Copilot בדף הבית של ההגדרות',

    # --- AI ---
    'Disable Microsoft Copilot', 'השבת את Microsoft Copilot',
    "This will disable and uninstall Microsoft Copilot, Windows' built-in AI assistant.", 'פעולה זו תשבית ותסיר את Microsoft Copilot, עוזר הבינה המלאכותית המובנה של Windows.',
    'Disabling Microsoft Copilot', 'משבית את Microsoft Copilot',
    'Enable Microsoft Copilot', 'הפעל את Microsoft Copilot',
    'Enabling Microsoft Copilot', 'מפעיל את Microsoft Copilot',
    'Disable Windows Recall', 'השבת את Windows Recall',
    'This will disable Windows Recall, an AI-powered feature that provides quick access to recently used files, apps and activities. This feature uses policies, which will lock down certain settings.', 'פעולה זו תשבית את Windows Recall, תכונה מבוססת בינה מלאכותית המספקת גישה מהירה לקבצים, אפליקציות ופעילויות שהיו בשימוש לאחרונה. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling Windows Recall', 'משבית את Windows Recall',
    'Enable Windows Recall', 'הפעל את Windows Recall',
    'Enabling Windows Recall', 'מפעיל את Windows Recall',
    'Disable Click To Do, AI text & image analysis', 'השבת את Click To Do וניתוח טקסט ותמונות מבוסס בינה מלאכותית',
    'This will disable Click To Do, which provides AI-powered text and image analysis features in Windows. This feature uses policies, which will lock down certain settings.', 'פעולה זו תשבית את Click To Do, המספק תכונות ניתוח טקסט ותמונות מבוססות בינה מלאכותית ב-Windows. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling Click to Do', 'משבית את Click To Do',
    'Enable Click To Do, AI text & image analysis', 'הפעל את Click To Do וניתוח טקסט ותמונות מבוסס בינה מלאכותית',
    'Enabling Click to Do', 'מפעיל את Click To Do',
    'Prevent AI service from starting automatically', 'מנע משירות הבינה המלאכותית להיפתח אוטומטית',
    'This will set the WSAIFabricSvc service to manual startup, preventing the service from starting automatically with Windows.', 'פעולה זו תגדיר את השירות WSAIFabricSvc להפעלה ידנית, וכך תמנע מהשירות להיפתח אוטומטית יחד עם Windows.',
    'Preventing AI service from starting automatically', 'מונע משירות הבינה המלאכותית להיפתח אוטומטית',
    'Allow AI service to start automatically', 'אפשר לשירות הבינה המלאכותית להיפתח אוטומטית',
    'Allowing AI service to start automatically', 'מאפשר לשירות הבינה המלאכותית להיפתח אוטומטית',
    'Disable AI features in Microsoft Edge', 'השבת תכונות בינה מלאכותית ב-Microsoft Edge',
    'This will turn off AI features in Microsoft Edge, such as the AI-powered sidebar and Copilot features. This feature uses policies, which will lock down certain settings.', 'פעולה זו תכבה תכונות בינה מלאכותית ב-Microsoft Edge, כגון סרגל הצד מבוסס הבינה המלאכותית ותכונות Copilot. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling AI features in Microsoft Edge', 'משבית תכונות בינה מלאכותית ב-Microsoft Edge',
    'Enable AI features in Microsoft Edge', 'הפעל תכונות בינה מלאכותית ב-Microsoft Edge',
    'Enabling AI features in Microsoft Edge', 'מפעיל תכונות בינה מלאכותית ב-Microsoft Edge',
    'Disable AI features in Paint', 'השבת תכונות בינה מלאכותית ב-Paint',
    'This will turn off AI features in Paint, such as the AI-powered image generation and editing tools. This feature uses policies, which will lock down certain settings.', 'פעולה זו תכבה תכונות בינה מלאכותית ב-Paint, כגון כלי יצירת ועריכת התמונות מבוססי הבינה המלאכותית. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling AI features in Paint', 'משבית תכונות בינה מלאכותית ב-Paint',
    'Enable AI features in Paint', 'הפעל תכונות בינה מלאכותית ב-Paint',
    'Enabling AI features in Paint', 'מפעיל תכונות בינה מלאכותית ב-Paint',
    'Disable AI features in Notepad', 'השבת תכונות בינה מלאכותית ב-Notepad',
    'This will turn off AI features in Notepad, such as the AI-powered writing suggestions. This feature uses policies, which will lock down certain settings.', 'פעולה זו תכבה תכונות בינה מלאכותית ב-Notepad, כגון הצעות הכתיבה מבוססות הבינה המלאכותית. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling AI features in Notepad', 'משבית תכונות בינה מלאכותית ב-Notepad',
    'Enable AI features in Notepad', 'הפעל תכונות בינה מלאכותית ב-Notepad',
    'Enabling AI features in Notepad', 'מפעיל תכונות בינה מלאכותית ב-Notepad',

    # --- Gaming ---
    'Disable Xbox game/screen recording', 'השבת הקלטת משחק/מסך של Xbox',
    'This will disable the Xbox game/screen recording features included with the Game Bar app. This feature uses policies, which will lock down certain settings.', 'פעולה זו תשבית את תכונות הקלטת המשחק/מסך של Xbox הכלולות באפליקציית Game Bar. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling Xbox game/screen recording', 'משבית הקלטת משחק/מסך של Xbox',
    'Enable Xbox game/screen recording', 'הפעל הקלטת משחק/מסך של Xbox',
    'Enabling Xbox game/screen recording', 'מפעיל הקלטת משחק/מסך של Xbox',
    'Disable Game Bar integration', 'השבת את שילוב ה-Game Bar',
    'This will disable the Game Bar integration with games and controllers. This stops annoying ms-gamebar popups when launching games or connecting a controller.', 'פעולה זו תשבית את שילוב ה-Game Bar עם משחקים ובקרים. הדבר מפסיק את חלונות הקופצים המעצבנים (ms-gamebar) בעת הפעלת משחקים או חיבור בקר.',
    'Disabling Game Bar integration', 'משבית את שילוב ה-Game Bar',
    'Enable Game Bar integration', 'הפעל את שילוב ה-Game Bar',
    'Enabling Game Bar integration', 'מפעיל את שילוב ה-Game Bar',

    # --- Start Menu & Search ---
    'Remove all pinned apps from the start menu for this user only', 'הסר את כל האפליקציות המוצמדות מתפריט התחל עבור משתמש זה בלבד',
    'Removing all pinned apps from the start menu', 'מסיר את כל האפליקציות המוצמדות מתפריט התחל',
    'Remove all pinned apps from the start menu for all existing and new users', 'הסר את כל האפליקציות המוצמדות מתפריט התחל עבור כל המשתמשים הקיימים והחדשים',
    'Removing all pinned apps from the start menu for all users', 'מסיר את כל האפליקציות המוצמדות מתפריט התחל עבור כל המשתמשים',
    'Replace the start menu layout for this user only with the provided template file', 'החלף את פריסת תפריט התחל עבור משתמש זה בלבד בקובץ התבנית שסופק',
    'Replacing the start menu', 'מחליף את תפריט התחל',
    'Replace the start menu layout for all existing and new users with the provided template file', 'החלף את פריסת תפריט התחל עבור כל המשתמשים הקיימים והחדשים בקובץ התבנית שסופק',
    'Replacing the start menu for all users', 'מחליף את תפריט התחל עבור כל המשתמשים',
    'Hide recommended section in the start menu', 'הסתר את מקטע "מומלץ" בתפריט התחל',
    'This will hide the recommended section in the start menu, which shows recently added apps, recently opened files and app recommendations. This feature uses policies, which will lock down certain settings.', 'פעולה זו תסתיר את מקטע "מומלץ" בתפריט התחל, המציג אפליקציות שנוספו לאחרונה, קבצים שנפתחו לאחרונה והמלצות אפליקציות. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling the start menu recommended section', 'משבית את מקטע "מומלץ" בתפריט התחל',
    'Show recommended section in the start menu', 'הצג את מקטע "מומלץ" בתפריט התחל',
    'Enabling the start menu recommended section', 'מפעיל את מקטע "מומלץ" בתפריט התחל',
    "Hide 'All Apps' section in the start menu", 'הסתר את מקטע "כל האפליקציות" בתפריט התחל',
    "This will hide the 'All Apps' section in the start menu, which shows all installed apps. WARNING: Hiding this section may make it harder to find installed apps on your system. This feature uses policies, which will lock down certain settings.", 'פעולה זו תסתיר את מקטע "כל האפליקציות" בתפריט התחל, המציג את כל האפליקציות המותקנות. אזהרה: הסתרת מקטע זה עלולה להקשות על מציאת אפליקציות מותקנות במערכת. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    "Disabling the 'All Apps' section in the start menu", 'משבית את מקטע "כל האפליקציות" בתפריט התחל',
    "Show 'All Apps' section in the start menu", 'הצג את מקטע "כל האפליקציות" בתפריט התחל',
    "Enabling the 'All Apps' section in the start menu", 'מפעיל את מקטע "כל האפליקציות" בתפריט התחל',
    'Disable Phone Link integration in the start menu', 'השבת את שילוב Phone Link בתפריט התחל',
    'This will remove the Phone Link integration in the start menu when you have a mobile device linked to your PC.', 'פעולה זו תסיר את שילוב Phone Link בתפריט התחל כאשר יש לך מכשיר נייד המקושר למחשב.',
    'Disabling the Phone Link mobile devices integration in the start menu', 'משבית את שילוב המכשירים הניידים של Phone Link בתפריט התחל',
    'Enable Phone Link integration in the start menu', 'הפעל את שילוב Phone Link בתפריט התחל',
    'Enabling the Phone Link mobile devices integration in the start menu', 'מפעיל את שילוב המכשירים הניידים של Phone Link בתפריט התחל',
    'Disable Bing web search & Copilot integration in search', 'השבת חיפוש אינטרנט של Bing ושילוב Copilot בחיפוש',
    'This will turn off Bing web search results and Copilot integration in the Windows search experience. This feature uses policies, which will lock down certain settings.', 'פעולה זו תכבה את תוצאות חיפוש האינטרנט של Bing ואת שילוב Copilot בחוויית החיפוש של Windows. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling Bing web search & Copilot integration in Windows search', 'משבית חיפוש אינטרנט של Bing ושילוב Copilot בחיפוש של Windows',
    'Enable Bing web search & Copilot integration in search', 'הפעל חיפוש אינטרנט של Bing ושילוב Copilot בחיפוש',
    'Enabling Bing web search & Copilot integration in Windows search', 'מפעיל חיפוש אינטרנט של Bing ושילוב Copilot בחיפוש של Windows',
    'Disable Microsoft Store app suggestions in search', 'השבת הצעות אפליקציות מ-Microsoft Store בחיפוש',
    'This will disable the Microsoft Store app suggestions in Windows search.', 'פעולה זו תשבית את הצעות האפליקציות מ-Microsoft Store בחיפוש של Windows.',
    'Disabling Microsoft Store app suggestions in search', 'משבית הצעות אפליקציות מ-Microsoft Store בחיפוש',
    'Enable Microsoft Store app suggestions in search', 'הפעל הצעות אפליקציות מ-Microsoft Store בחיפוש',
    'Enabling Microsoft Store app suggestions in search', 'מפעיל הצעות אפליקציות מ-Microsoft Store בחיפוש',
    "Show All Apps in Category view (Default)", 'הצג את "כל האפליקציות" בתצוגת קטגוריות (ברירת מחדל)',
    'This will set the All Apps section in the start menu to show apps grouped by category.', 'פעולה זו תגדיר את מקטע "כל האפליקציות" בתפריט התחל להצגת אפליקציות מקובצות לפי קטגוריה.',
    'Setting All Apps view to Category', 'מגדיר את תצוגת "כל האפליקציות" לקטגוריות',
    'Show All Apps in Grid view', 'הצג את "כל האפליקציות" בתצוגת רשת',
    'This will set the All Apps section in the start menu to show apps in an alphabetical grid layout.', 'פעולה זו תגדיר את מקטע "כל האפליקציות" בתפריט התחל להצגת אפליקציות בפריסת רשת לפי סדר אלפביתי.',
    'Setting All Apps view to Grid', 'מגדיר את תצוגת "כל האפליקציות" לרשת',
    'Show All Apps in Category view', 'הצג את "כל האפליקציות" בתצוגת קטגוריות',
    'Show All Apps in List view', 'הצג את "כל האפליקציות" בתצוגת רשימה',
    'This will set the All Apps section in the start menu to show apps in an alphabetical list layout.', 'פעולה זו תגדיר את מקטע "כל האפליקציות" בתפריט התחל להצגת אפליקציות בפריסת רשימה לפי סדר אלפביתי.',
    'Setting All Apps view to List', 'מגדיר את תצוגת "כל האפליקציות" לרשימה',

    # --- Settings / Other ---
    "Hide Settings 'Home' page", 'הסתר את דף "הבית" של ההגדרות',
    "Removes the 'Home' page from the Settings app.", 'מסיר את דף "הבית" מאפליקציית ההגדרות.',
    'Disabling the Settings Home page', 'משבית את דף הבית של ההגדרות',
    "Show Settings 'Home' page", 'הצג את דף "הבית" של ההגדרות',
    'Enabling the Settings Home page', 'מפעיל את דף הבית של ההגדרות',
    'Disable bloat in Brave browser (AI, Crypto, etc.)', 'השבת רכיבים מיותרים בדפדפן Brave (בינה מלאכותית, קריפטו ועוד)',
    "This will disable Brave's built-in AI features, Crypto wallet, News, Rewards, Talk and VPN. This feature uses policies, which will lock down certain settings.", 'פעולה זו תשבית את תכונות הבינה המלאכותית המובנות של Brave, ארנק הקריפטו, החדשות, התגמולים, Talk וה-VPN. תכונה זו משתמשת במדיניות (Policies), שתנעל הגדרות מסוימות.',
    'Disabling Brave AI, Crypto, News, Rewards, Talk and VPN in Brave browser', 'משבית את הבינה המלאכותית, הקריפטו, החדשות, התגמולים, Talk וה-VPN בדפדפן Brave',
    'Enable Brave browser features (AI, Crypto, etc.)', 'הפעל תכונות של דפדפן Brave (בינה מלאכותית, קריפטו ועוד)',
    'Enabling Brave AI, Crypto, News, Rewards, Talk and VPN in Brave browser', 'מפעיל את הבינה המלאכותית, הקריפטו, החדשות, התגמולים, Talk וה-VPN בדפדפן Brave',
    'Forcefully uninstall Microsoft Edge. NOT RECOMMENDED!', 'הסר את Microsoft Edge בכפייה. לא מומלץ!',
    'Forcefully uninstalling Microsoft Edge', 'מסיר את Microsoft Edge בכפייה',

    # --- System ---
    "Disable 'Drag Tray' for sharing & moving files", 'השבת את "מגש הגרירה" לשיתוף והעברת קבצים',
    'The Drag Tray is a new feature for sharing & moving files in Windows 11, it appears at the top of the screen when dragging files.', 'מגש הגרירה (Drag Tray) הוא תכונה חדשה לשיתוף והעברת קבצים ב-Windows 11, המופיעה בראש המסך בעת גרירת קבצים.',
    'Disabling Drag Tray', 'משבית את מגש הגרירה',
    "Enable 'Drag Tray' for sharing & moving files", 'הפעל את "מגש הגרירה" לשיתוף והעברת קבצים',
    'Enabling Drag Tray', 'מפעיל את מגש הגרירה',
    'Use classic Windows 10 context menu style', 'השתמש בסגנון תפריט ההקשר הקלאסי של Windows 10',
    "This will restore the classic Windows 10 style context menu, which is normally hidden behind the 'Show more options' entry in the new Windows 11 context menu.", 'פעולה זו תשחזר את תפריט ההקשר בסגנון הקלאסי של Windows 10, המוסתר בדרך כלל מאחורי הפריט "הצג אפשרויות נוספות" בתפריט ההקשר החדש של Windows 11.',
    'Restoring the classic Windows 10 style context menu', 'משחזר את תפריט ההקשר בסגנון הקלאסי של Windows 10',
    'Use Windows 11 context menu style', 'השתמש בסגנון תפריט ההקשר של Windows 11',
    'Restoring the Windows 11 style context menu', 'משחזר את תפריט ההקשר בסגנון Windows 11',
    'Disable Enhance Pointer Precision (mouse acceleration)', 'השבת את שיפור דיוק הסמן (האצת עכבר)',
    'This will disable mouse acceleration which is enabled by default in Windows. This makes mouse movement more consistent and predictable.', 'פעולה זו תשבית את האצת העכבר, המופעלת כברירת מחדל ב-Windows. הדבר הופך את תנועת העכבר לעקבית וצפויה יותר.',
    'Turning off Enhanced Pointer Precision', 'מכבה את שיפור דיוק הסמן',
    'Enable Enhance Pointer Precision (mouse acceleration)', 'הפעל את שיפור דיוק הסמן (האצת עכבר)',
    'Turning on Enhanced Pointer Precision', 'מפעיל את שיפור דיוק הסמן',
    'Disable Sticky Keys keyboard shortcut (5x shift)', 'השבת את קיצור המקלדת של מקשים דביקים (5 לחיצות Shift)',
    'This will prevent the Sticky Keys dialog from appearing when you press the Shift key 5 times in a row.', 'פעולה זו תמנע את הופעת תיבת הדו-שיח של מקשים דביקים בעת לחיצה על מקש Shift חמש פעמים ברצף.',
    'Disabling the Sticky Keys keyboard shortcut', 'משבית את קיצור המקלדת של מקשים דביקים',
    'Enable Sticky Keys keyboard shortcut (5x shift)', 'הפעל את קיצור המקלדת של מקשים דביקים (5 לחיצות Shift)',
    'Enabling the Sticky Keys keyboard shortcut', 'מפעיל את קיצור המקלדת של מקשים דביקים',
    'Disable Storage Sense automatic disk cleanup', 'השבת את ניקוי הדיסק האוטומטי של Storage Sense',
    'This will disable Storage Sense, which automatically frees up disk space by deleting temporary files, emptying the recycle bin and cleaning up files in the Downloads folder.', 'פעולה זו תשבית את Storage Sense, המפנה אוטומטית מקום בדיסק על ידי מחיקת קבצים זמניים, ריקון סל המיחזור וניקוי קבצים בתיקיית ההורדות.',
    'Disabling Storage Sense automatic disk cleanup', 'משבית את ניקוי הדיסק האוטומטי של Storage Sense',
    'Enable Storage Sense automatic disk cleanup', 'הפעל את ניקוי הדיסק האוטומטי של Storage Sense',
    'Enabling Storage Sense automatic disk cleanup', 'מפעיל את ניקוי הדיסק האוטומטי של Storage Sense',
    'Disable fast start-up', 'השבת הפעלה מהירה',
    'Fast Start-up helps your PC start faster after shutdown by saving a system image to disk. Disabling Fast Start-up can help with certain issues, but may result in slightly longer boot times.', 'הפעלה מהירה (Fast Start-up) מסייעת למחשב להיפתח מהר יותר לאחר כיבוי, על ידי שמירת תמונת מערכת בדיסק. השבתת ההפעלה המהירה עשויה לסייע בבעיות מסוימות, אך עלולה לגרום לזמני אתחול ארוכים מעט יותר.',
    'Disabling Fast Start-up', 'משבית הפעלה מהירה',
    'Enable fast start-up', 'הפעל הפעלה מהירה',
    'Enabling Fast Start-up', 'מפעיל הפעלה מהירה',
    'Disable BitLocker automatic device encryption', 'השבת הצפנת מכשיר אוטומטית של BitLocker',
    'For devices that support it, Windows 11 automatically enables BitLocker device encryption. Disabling this will turn off automatic encryption of the device, but you can still manually enable BitLocker encryption if desired. Drives that are already encrypted with BitLocker will remain encrypted when this setting is applied.', 'במכשירים התומכים בכך, Windows 11 מפעיל אוטומטית הצפנת מכשיר של BitLocker. השבתת אפשרות זו תכבה את ההצפנה האוטומטית של המכשיר, אך עדיין ניתן להפעיל ידנית הצפנת BitLocker אם תרצה. כוננים שכבר מוצפנים באמצעות BitLocker יישארו מוצפנים לאחר החלת הגדרה זו.',
    'Disabling BitLocker automatic device encryption', 'משבית הצפנת מכשיר אוטומטית של BitLocker',
    'Enable BitLocker automatic device encryption', 'הפעל הצפנת מכשיר אוטומטית של BitLocker',
    'Enabling BitLocker automatic device encryption', 'מפעיל הצפנת מכשיר אוטומטית של BitLocker',
    'Disable Modern Standby network connectivity', 'השבת קישוריות רשת במצב Modern Standby',
    'By default, devices that support Modern Standby maintain network connectivity while in sleep mode. Disabling network connectivity during Modern Standby can help save battery life.', 'כברירת מחדל, מכשירים התומכים ב-Modern Standby שומרים על קישוריות רשת במצב שינה. השבתת קישוריות הרשת במצב Modern Standby עשויה לסייע בחיסכון בחיי הסוללה.',
    'Disabling network connectivity during Modern Standby', 'משבית קישוריות רשת במצב Modern Standby',
    'Enable Modern Standby network connectivity', 'הפעל קישוריות רשת במצב Modern Standby',
    'Enabling network connectivity during Modern Standby', 'מפעיל קישוריות רשת במצב Modern Standby',

    # --- Appearance ---
    'Enable dark theme for system and apps', 'הפעל ערכת נושא כהה למערכת ולאפליקציות',
    'This will set the app and system theme to dark mode.', 'פעולה זו תגדיר את ערכת הנושא של האפליקציות והמערכת למצב כהה.',
    'Enabling dark mode for system and apps', 'מפעיל מצב כהה למערכת ולאפליקציות',
    'Disable dark theme for system and apps', 'השבת ערכת נושא כהה למערכת ולאפליקציות',
    'Disabling dark mode for system and apps', 'משבית מצב כהה למערכת ולאפליקציות',
    'Disable transparency effects', 'השבת אפקטי שקיפות',
    'This will disable transparency effects on Windows and interfaces. Which can help improve performance on older hardware.', 'פעולה זו תשבית אפקטי שקיפות ב-Windows ובממשקים, מה שעשוי לשפר את הביצועים בחומרה ישנה יותר.',
    'Disabling transparency effects', 'משבית אפקטי שקיפות',
    'Enable transparency effects', 'הפעל אפקטי שקיפות',
    'Enabling transparency effects', 'מפעיל אפקטי שקיפות',
    'Disable animations and visual effects', 'השבת אנימציות ואפקטים חזותיים',
    'This will disable animations and some visual effects in Windows, which can make the interface feel snappier, especially on older hardware.', 'פעולה זו תשבית אנימציות וחלק מהאפקטים החזותיים ב-Windows, מה שעשוי לגרום לממשק להרגיש מהיר יותר, במיוחד בחומרה ישנה יותר.',
    'Disabling animations and visual effects', 'משבית אנימציות ואפקטים חזותיים',
    'Enable animations and visual effects', 'הפעל אנימציות ואפקטים חזותיים',
    'Enabling animations and visual effects', 'מפעיל אנימציות ואפקטים חזותיים',

    # --- Windows Update ---
    "Prevent getting updates as soon as they're available", 'מנע קבלת עדכונים ברגע שהם זמינים',
    'This will prevent your PC from being among the first to receive new non-security updates. Your PC will still receive these updates eventually.', 'פעולה זו תמנע מהמחשב שלך להיות בין הראשונים לקבל עדכונים חדשים שאינם עדכוני אבטחה. המחשב עדיין יקבל עדכונים אלו בסופו של דבר.',
    'Preventing Windows from getting updates as soon as they are available', 'מונע מ-Windows לקבל עדכונים ברגע שהם זמינים',
    "Allow getting updates as soon as they're available", 'אפשר קבלת עדכונים ברגע שהם זמינים',
    'Allowing Windows to get updates as soon as they are available', 'מאפשר ל-Windows לקבל עדכונים ברגע שהם זמינים',
    'Prevent automatic restarts after updates while signed in', 'מנע הפעלות מחדש אוטומטיות לאחר עדכונים בזמן שמשתמש מחובר',
    'This will prevent your PC from automatically restarting after updates while any user is signed in.', 'פעולה זו תמנע מהמחשב להתחיל מחדש אוטומטית לאחר עדכונים בזמן שמשתמש כלשהו מחובר.',
    'Preventing automatic restarts after updates while signed in', 'מונע הפעלות מחדש אוטומטיות לאחר עדכונים בזמן שמשתמש מחובר',
    'Allow automatic restarts after updates while signed in', 'אפשר הפעלות מחדש אוטומטיות לאחר עדכונים בזמן שמשתמש מחובר',
    'Allowing automatic restarts after updates while signed in', 'מאפשר הפעלות מחדש אוטומטיות לאחר עדכונים בזמן שמשתמש מחובר',
    'Disable sharing downloaded updates with other PCs', 'השבת שיתוף עדכונים שהורדו עם מחשבים אחרים',
    'This will prevent your PC from sharing downloaded updates with other PCs on the local network or on the internet. This also prevents your PC from downloading updates from other PCs.', 'פעולה זו תמנע מהמחשב שלך לשתף עדכונים שהורדו עם מחשבים אחרים ברשת המקומית או באינטרנט. כמו כן היא מונעת מהמחשב להוריד עדכונים ממחשבים אחרים.',
    'Disabling sharing of downloaded updates with other PCs', 'משבית שיתוף עדכונים שהורדו עם מחשבים אחרים',
    'Enable sharing downloaded updates with other PCs', 'הפעל שיתוף עדכונים שהורדו עם מחשבים אחרים',
    'Enabling sharing of downloaded updates with other PCs', 'מפעיל שיתוף עדכונים שהורדו עם מחשבים אחרים',

    # --- Taskbar ---
    'Align taskbar to the left', 'יישר את שורת המשימות לשמאל',
    'By default, Windows 11 has the taskbar buttons centered. Enabling this setting will move the taskbar buttons to the left, similar to previous versions of Windows.', 'כברירת מחדל, ב-Windows 11 לחצני שורת המשימות ממורכזים. הפעלת הגדרה זו תזיז את לחצני שורת המשימות לשמאל, בדומה לגרסאות קודמות של Windows.',
    'Aligning taskbar buttons to the left', 'מיישר את לחצני שורת המשימות לשמאל',
    'Align taskbar to the center', 'יישר את שורת המשימות למרכז',
    'Aligning taskbar buttons to the center', 'מיישר את לחצני שורת המשימות למרכז',
    'Hide search icon from the taskbar', 'הסתר את סמל החיפוש משורת המשימות',
    'Hiding the search icon from the taskbar', 'מסתיר את סמל החיפוש משורת המשימות',
    'Show search box on the taskbar', 'הצג תיבת חיפוש בשורת המשימות',
    'Changing taskbar search to search box', 'משנה את החיפוש בשורת המשימות לתיבת חיפוש',
    'Show search icon on the taskbar', 'הצג סמל חיפוש בשורת המשימות',
    'Changing taskbar search to icon only', 'משנה את החיפוש בשורת המשימות לסמל בלבד',
    'Show search icon with label on the taskbar', 'הצג סמל חיפוש עם תווית בשורת המשימות',
    'Changing taskbar search to icon with label', 'משנה את החיפוש בשורת המשימות לסמל עם תווית',
    "Hide 'Task view' button on the taskbar", 'הסתר את לחצן "תצוגת משימות" בשורת המשימות',
    "This will disable the 'Task view' button on the taskbar, which allows you to see all your open windows and virtual desktops.", 'פעולה זו תשבית את לחצן "תצוגת משימות" בשורת המשימות, המאפשר לראות את כל החלונות הפתוחים ושולחנות העבודה הווירטואליים שלך.',
    'Hiding the taskview button from the taskbar', 'מסתיר את לחצן תצוגת המשימות משורת המשימות',
    "Show 'Task view' button on the taskbar", 'הצג את לחצן "תצוגת משימות" בשורת המשימות',
    'Showing the taskview button from the taskbar', 'מציג את לחצן תצוגת המשימות בשורת המשימות',
    'Disable widgets on the taskbar & lock screen', 'השבת יישומונים בשורת המשימות ובמסך הנעילה',
    'This will disable the widgets features in Windows, including the widgets button on the taskbar and the widgets that can appear on the lock screen.', 'פעולה זו תשבית את תכונות היישומונים ב-Windows, כולל לחצן היישומונים בשורת המשימות והיישומונים שיכולים להופיע במסך הנעילה.',
    'Disabling widgets on the taskbar & lock screen', 'משבית יישומונים בשורת המשימות ובמסך הנעילה',
    'Hide Chat (meet now) icon on the taskbar', 'הסתר את סמל הצ׳אט (Meet Now) בשורת המשימות',
    'This will disable the Chat (meet now) icon on the taskbar.', 'פעולה זו תשבית את סמל הצ׳אט (Meet Now) בשורת המשימות.',
    'Hiding the chat icon from the taskbar', 'מסתיר את סמל הצ׳אט משורת המשימות',
    'Show Chat (meet now) icon on the taskbar', 'הצג את סמל הצ׳אט (Meet Now) בשורת המשימות',
    'Showing the chat icon from the taskbar', 'מציג את סמל הצ׳אט בשורת המשימות',
    "Show 'End Task' option in taskbar context menu", 'הצג את האפשרות "סיים משימה" בתפריט ההקשר של שורת המשימות',
    "When enabled, adds an 'End Task' option to the right-click context menu for apps in the taskbar, allowing you to quickly force close apps.", 'כשמופעל, מוסיף אפשרות "סיים משימה" לתפריט ההקשר (לחיצה ימנית) של אפליקציות בשורת המשימות, ומאפשר לסגור אפליקציות בכפייה במהירות.',
    "Enabling the 'End Task' option in the taskbar right click menu", 'מפעיל את האפשרות "סיים משימה" בתפריט הלחיצה הימנית של שורת המשימות',
    "Hide 'End Task' option in taskbar context menu", 'הסתר את האפשרות "סיים משימה" בתפריט ההקשר של שורת המשימות',
    "Disabling the 'End Task' option in the taskbar right click menu", 'משבית את האפשרות "סיים משימה" בתפריט הלחיצה הימנית של שורת המשימות',
    "Enable 'Last Active Click' behavior for taskbar apps", 'הפעל התנהגות "לחיצה על החלון הפעיל האחרון" עבור אפליקציות שורת המשימות',
    'When enabled, clicking on an app in the taskbar will switch to the last active window of that app, instead of only showing the thumbnail preview.', 'כשמופעל, לחיצה על אפליקציה בשורת המשימות תעבור לחלון הפעיל האחרון של אותה אפליקציה, במקום להציג רק את התצוגה המקדימה הממוזערת.',
    "Enabling the 'Last Active Click' behavior in the taskbar app area", 'מפעיל את התנהגות "לחיצה על החלון הפעיל האחרון" באזור האפליקציות של שורת המשימות',
    "Disable 'Last Active Click' behavior for taskbar apps", 'השבת התנהגות "לחיצה על החלון הפעיל האחרון" עבור אפליקציות שורת המשימות',
    "Disabling the 'Last Active Click' behavior in the taskbar app area", 'משבית את התנהגות "לחיצה על החלון הפעיל האחרון" באזור האפליקציות של שורת המשימות',
    'Always combine taskbar buttons and hide labels for the main display', 'תמיד אחד את לחצני שורת המשימות והסתר תוויות בצג הראשי',
    'Setting the taskbar on the main display to always combine buttons and hide labels', 'מגדיר את שורת המשימות בצג הראשי לאחד תמיד לחצנים ולהסתיר תוויות',
    'Use default taskbar combine behavior', 'השתמש בהתנהגות איחוד ברירת המחדל של שורת המשימות',
    'Always combine taskbar buttons and hide labels for secondary displays', 'תמיד אחד את לחצני שורת המשימות והסתר תוויות בצגים משניים',
    'Setting the taskbar on secondary displays to always combine buttons and hide labels', 'מגדיר את שורת המשימות בצגים משניים לאחד תמיד לחצנים ולהסתיר תוויות',
    'Combine taskbar buttons and hide labels when taskbar is full for the main display', 'אחד לחצני שורת משימות והסתר תוויות כששורת המשימות מלאה בצג הראשי',
    'Setting the taskbar on the main display to only combine buttons and hide labels when the taskbar is full', 'מגדיר את שורת המשימות בצג הראשי לאחד לחצנים ולהסתיר תוויות רק כששורת המשימות מלאה',
    'Combine taskbar buttons and hide labels when taskbar is full for secondary displays', 'אחד לחצני שורת משימות והסתר תוויות כששורת המשימות מלאה בצגים משניים',
    'Setting the taskbar on secondary displays to only combine buttons and hide labels when the taskbar is full', 'מגדיר את שורת המשימות בצגים משניים לאחד לחצנים ולהסתיר תוויות רק כששורת המשימות מלאה',
    'Never combine taskbar buttons and show labels for the main display', 'אף פעם אל תאחד לחצני שורת משימות והצג תוויות בצג הראשי',
    'Setting the taskbar on the main display to never combine buttons or hide labels', 'מגדיר את שורת המשימות בצג הראשי לעולם לא לאחד לחצנים או להסתיר תוויות',
    'Never combine taskbar buttons and show labels for secondary displays', 'אף פעם אל תאחד לחצני שורת משימות והצג תוויות בצגים משניים',
    'Setting the taskbar on secondary displays to never combine buttons or hide labels', 'מגדיר את שורת המשימות בצגים משניים לעולם לא לאחד לחצנים או להסתיר תוויות',
    'Show app icons on all taskbars', 'הצג סמלי אפליקציות בכל שורות המשימות',
    'Setting the taskbar to show app icons on all taskbars', 'מגדיר את שורת המשימות להציג סמלי אפליקציות בכל שורות המשימות',
    'Show app icons on main taskbar and on taskbar where the windows is open', 'הצג סמלי אפליקציות בשורת המשימות הראשית ובשורה שבה החלון פתוח',
    'Setting the taskbar to show app icons on main taskbar and on taskbar where the windows is open', 'מגדיר את שורת המשימות להציג סמלי אפליקציות בשורה הראשית ובשורה שבה החלון פתוח',
    'Show app icons only on taskbar where the window is open', 'הצג סמלי אפליקציות רק בשורת המשימות שבה החלון פתוח',
    'Setting the taskbar to only show app icons on the taskbar where the window is open', 'מגדיר את שורת המשימות להציג סמלי אפליקציות רק בשורה שבה החלון פתוח',

    # --- Multi-tasking ---
    'Disable window snapping', 'השבת הצמדת חלונות',
    'This will turn off the ability to snap windows to the sides or corners of the screen.', 'פעולה זו תכבה את היכולת להצמיד חלונות לצדי המסך או לפינותיו.',
    'Disabling window snapping', 'משבית הצמדת חלונות',
    'Enable window snapping', 'הפעל הצמדת חלונות',
    'Enabling window snapping', 'מפעיל הצמדת חלונות',
    'Disable showing app suggestions when snapping windows', 'השבת הצגת הצעות אפליקציות בעת הצמדת חלונות',
    'This will turn off app suggestions when you snap windows to the sides or corners of the screen.', 'פעולה זו תכבה את הצעות האפליקציות בעת הצמדת חלונות לצדי המסך או לפינותיו.',
    'Disabling the Snap Assist suggestions', 'משבית את הצעות Snap Assist',
    'Enable showing app suggestions when snapping windows', 'הפעל הצגת הצעות אפליקציות בעת הצמדת חלונות',
    'Enabling the Snap Assist suggestions', 'מפעיל את הצעות Snap Assist',
    'Hide snap layout flyout at top of screen and on maximize button', 'הסתר את חלונית פריסות ההצמדה בראש המסך ועל לחצן ההגדלה',
    'This will turn off the snap layout flyout that appears when you hover over the maximize button or drag windows to the top of the screen.', 'פעולה זו תכבה את חלונית פריסות ההצמדה המופיעה בעת ריחוף מעל לחצן ההגדלה או גרירת חלונות לראש המסך.',
    'Hiding snap layouts when dragging windows to top of the screen and on maximize button', 'מסתיר את פריסות ההצמדה בעת גרירת חלונות לראש המסך ועל לחצן ההגדלה',
    'Show snap layout flyout at top of screen and on maximize button', 'הצג את חלונית פריסות ההצמדה בראש המסך ועל לחצן ההגדלה',
    'Showing snap layouts when dragging windows to top of the screen and on maximize button', 'מציג את פריסות ההצמדה בעת גרירת חלונות לראש המסך ועל לחצן ההגדלה',
    'Hide tabs from apps when snapping or pressing Alt+Tab', 'הסתר כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',
    'Disable showing tabs from apps when snapping or pressing Alt+Tab', 'משבית הצגת כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',
    'Show 3 tabs from apps when snapping or pressing Alt+Tab', 'הצג 3 כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',
    'Enable showing 3 tabs from apps when snapping or pressing Alt+Tab', 'מפעיל הצגת 3 כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',
    'Show 5 tabs from apps when snapping or pressing Alt+Tab', 'הצג 5 כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',
    'Enable showing 5 tabs from apps when snapping or pressing Alt+Tab', 'מפעיל הצגת 5 כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',
    'Show 20 tabs from apps when snapping or pressing Alt+Tab', 'הצג 20 כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',
    'Enable showing 20 tabs from apps when snapping or pressing Alt+Tab', 'מפעיל הצגת 20 כרטיסיות מאפליקציות בעת הצמדה או לחיצה על Alt+Tab',

    # --- File Explorer ---
    "Change the default location that File Explorer opens to 'Home'", 'שנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל"בית"',
    "Changing the default location that File Explorer opens to, to 'Home'", 'משנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל"בית"',
    "Change the default location that File Explorer opens to 'This PC'", 'שנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל"מחשב זה"',
    "Changing the default location that File Explorer opens to, to 'This PC'", 'משנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל"מחשב זה"',
    "Change the default location that File Explorer opens to 'Downloads'", 'שנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל"הורדות"',
    "Changing the default location that File Explorer opens to, to 'Downloads'", 'משנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל"הורדות"',
    "Change the default location that File Explorer opens to 'OneDrive'", 'שנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל-OneDrive',
    "Changing the default location that File Explorer opens to, to 'OneDrive'", 'משנה את מיקום ברירת המחדל שאליו נפתח סייר הקבצים ל-OneDrive',
    'Show file extensions for known file types', 'הצג סיומות קבצים עבור סוגי קבצים מוכרים',
    'This will show file extensions for known file types. By default, Windows hides file extensions for known file types which can lead to confusion and security risks.', 'פעולה זו תציג סיומות קבצים עבור סוגי קבצים מוכרים. כברירת מחדל, Windows מסתיר סיומות קבצים עבור סוגי קבצים מוכרים, מה שעלול לגרום לבלבול ולסיכוני אבטחה.',
    'Enabling file extensions for known file types', 'מפעיל הצגת סיומות קבצים עבור סוגי קבצים מוכרים',
    'Hide file extensions for known file types', 'הסתר סיומות קבצים עבור סוגי קבצים מוכרים',
    'Disabling file extensions for known file types', 'משבית הצגת סיומות קבצים עבור סוגי קבצים מוכרים',
    'Show hidden files, folders and drives', 'הצג קבצים, תיקיות וכוננים מוסתרים',
    'By default, Windows hides certain files, folders and drives to prevent accidental modification or deletion. Turn this on to show all files in File Explorer.', 'כברירת מחדל, Windows מסתיר קבצים, תיקיות וכוננים מסוימים כדי למנוע שינוי או מחיקה בטעות. הפעל אפשרות זו כדי להציג את כל הקבצים בסייר הקבצים.',
    'Unhiding hidden files, folders and drives', 'מבטל הסתרה של קבצים, תיקיות וכוננים מוסתרים',
    'Hide hidden files, folders and drives', 'הסתר קבצים, תיקיות וכוננים מוסתרים',
    'Hiding hidden files, folders and drives', 'מסתיר קבצים, תיקיות וכוננים מוסתרים',
    'Hide duplicate removable drive entries', 'הסתר רשומות כפולות של כוננים נשלפים',
    "By default, Windows shows removable drives both under 'This PC' and in the navigation pane with its own entry. Enable this setting to only show removable drives under 'This PC'.", 'כברירת מחדל, Windows מציג כוננים נשלפים גם תחת "מחשב זה" וגם בחלונית הניווט עם רשומה נפרדת. הפעל הגדרה זו כדי להציג כוננים נשלפים תחת "מחשב זה" בלבד.',
    'Hiding duplicate removable drive entries from the File Explorer navigation pane', 'מסתיר רשומות כפולות של כוננים נשלפים מחלונית הניווט של סייר הקבצים',
    'Show duplicate removable drive entries', 'הצג רשומות כפולות של כוננים נשלפים',
    'Showing duplicate removable drive entries from the File Explorer navigation pane', 'מציג רשומות כפולות של כוננים נשלפים בחלונית הניווט של סייר הקבצים',
    "Hide 'Home' from navigation pane", 'הסתר את "בית" מחלונית הניווט',
    "Hides the 'Home' section from the File Explorer navigation pane.", 'מסתיר את מקטע "בית" מחלונית הניווט של סייר הקבצים.',
    "Hiding the 'Home' section from the File Explorer navigation pane", 'מסתיר את מקטע "בית" מחלונית הניווט של סייר הקבצים',
    "Show 'Home' from navigation pane", 'הצג את "בית" בחלונית הניווט',
    "Showing the 'Home' section from the File Explorer navigation pane", 'מציג את מקטע "בית" בחלונית הניווט של סייר הקבצים',
    "Hide 'Gallery' from navigation pane", 'הסתר את "גלריה" מחלונית הניווט',
    "Hides the 'Gallery' section from the File Explorer navigation pane.", 'מסתיר את מקטע "גלריה" מחלונית הניווט של סייר הקבצים.',
    "Hiding the 'Gallery' section from the File Explorer navigation pane", 'מסתיר את מקטע "גלריה" מחלונית הניווט של סייר הקבצים',
    "Show 'Gallery' from navigation pane", 'הצג את "גלריה" בחלונית הניווט',
    "Showing the 'Gallery' section from the File Explorer navigation pane", 'מציג את מקטע "גלריה" בחלונית הניווט של סייר הקבצים',
    "Hide 'OneDrive' from navigation pane", 'הסתר את "OneDrive" מחלונית הניווט',
    "Hides the 'OneDrive' section from the File Explorer navigation pane.", 'מסתיר את מקטע "OneDrive" מחלונית הניווט של סייר הקבצים.',
    "Hiding the 'OneDrive' section from the File Explorer navigation pane", 'מסתיר את מקטע "OneDrive" מחלונית הניווט של סייר הקבצים',
    "Show 'OneDrive' from navigation pane", 'הצג את "OneDrive" בחלונית הניווט',
    "Showing the 'OneDrive' section from the File Explorer navigation pane", 'מציג את מקטע "OneDrive" בחלונית הניווט של סייר הקבצים',
    "Hide '3D objects' folder under 'This PC'", 'הסתר את התיקייה "אובייקטים תלת-ממדיים" תחת "מחשב זה"',
    "Hides the '3D objects' folder from the File Explorer navigation pane.", 'מסתיר את התיקייה "אובייקטים תלת-ממדיים" מחלונית הניווט של סייר הקבצים.',
    "Hiding the '3D objects' folder from the File Explorer navigation pane", 'מסתיר את התיקייה "אובייקטים תלת-ממדיים" מחלונית הניווט של סייר הקבצים',
    "Show '3D objects' folder under 'This PC'", 'הצג את התיקייה "אובייקטים תלת-ממדיים" תחת "מחשב זה"',
    "Showing the '3D objects' folder from the File Explorer navigation pane", 'מציג את התיקייה "אובייקטים תלת-ממדיים" בחלונית הניווט של סייר הקבצים',
    "Hide 'Music' folder under 'This PC'", 'הסתר את התיקייה "מוזיקה" תחת "מחשב זה"',
    "Hides the 'Music' folder from the File Explorer navigation pane.", 'מסתיר את התיקייה "מוזיקה" מחלונית הניווט של סייר הקבצים.',
    "Hiding the 'Music' folder from the File Explorer navigation pane", 'מסתיר את התיקייה "מוזיקה" מחלונית הניווט של סייר הקבצים',
    "Show 'Music' folder under 'This PC'", 'הצג את התיקייה "מוזיקה" תחת "מחשב זה"',
    "Showing the 'Music' folder from the File Explorer navigation pane", 'מציג את התיקייה "מוזיקה" בחלונית הניווט של סייר הקבצים',
    "Add common folders back to 'This PC' page", 'הוסף בחזרה תיקיות נפוצות לעמוד "מחשב זה"',
    "This setting will add common folders like Desktop, Documents, Downloads, Music, Pictures and Videos back to the 'This PC' page in File Explorer.", 'הגדרה זו תוסיף בחזרה תיקיות נפוצות כמו שולחן העבודה, מסמכים, הורדות, מוזיקה, תמונות וסרטונים לעמוד "מחשב זה" בסייר הקבצים.',
    "Adding all common folders (Desktop, Downloads, etc.) back to 'This PC' in File Explorer", 'מוסיף בחזרה את כל התיקיות הנפוצות (שולחן העבודה, הורדות וכו׳) לעמוד "מחשב זה" בסייר הקבצים',
    "Remove common folders back to 'This PC' page", 'הסר תיקיות נפוצות מעמוד "מחשב זה"',
    "Removing all common folders (Desktop, Downloads, etc.) back to 'This PC' in File Explorer", 'מסיר את כל התיקיות הנפוצות (שולחן העבודה, הורדות וכו׳) מעמוד "מחשב זה" בסייר הקבצים',
    "Hide 'Include in library' option in the context menu", 'הסתר את האפשרות "כלול בספרייה" בתפריט ההקשר',
    "Hides the 'Include in library' option from the File Explorer context menu.", 'מסתיר את האפשרות "כלול בספרייה" מתפריט ההקשר של סייר הקבצים.',
    "Hiding 'Include in library' in the context menu", 'מסתיר את "כלול בספרייה" בתפריט ההקשר',
    "Show 'Include in library' option in the context menu", 'הצג את האפשרות "כלול בספרייה" בתפריט ההקשר',
    "Showing 'Include in library' in the context menu", 'מציג את "כלול בספרייה" בתפריט ההקשר',
    "Hide 'Give access to' option in the context menu", 'הסתר את האפשרות "תן גישה אל" בתפריט ההקשר',
    "Hides the 'Give access to' option from the File Explorer context menu.", 'מסתיר את האפשרות "תן גישה אל" מתפריט ההקשר של סייר הקבצים.',
    "Hiding 'Give access to' in the context menu", 'מסתיר את "תן גישה אל" בתפריט ההקשר',
    "Show 'Give access to' option in the context menu", 'הצג את האפשרות "תן גישה אל" בתפריט ההקשר',
    "Showing 'Give access to' in the context menu", 'מציג את "תן גישה אל" בתפריט ההקשר',
    "Hide 'Share' option in the context menu", 'הסתר את האפשרות "שתף" בתפריט ההקשר',
    "Hides the 'Share' option from the File Explorer context menu.", 'מסתיר את האפשרות "שתף" מתפריט ההקשר של סייר הקבצים.',
    "Hiding 'Share' in the context menu", 'מסתיר את "שתף" בתפריט ההקשר',
    "Show 'Share' option in the context menu", 'הצג את האפשרות "שתף" בתפריט ההקשר',
    "Showing 'Share' in the context menu", 'מציג את "שתף" בתפריט ההקשר',
    'Show drive letters before drive label', 'הצג את אותיות הכונן לפני תווית הכונן',
    'This setting will show drive letters before the drive label in File Explorer.', 'הגדרה זו תציג את אותיות הכונן לפני תווית הכונן בסייר הקבצים.',
    'Showing drive letters before drive label', 'מציג את אותיות הכונן לפני תווית הכונן',
    'Show drive letters after drive label', 'הצג את אותיות הכונן אחרי תווית הכונן',
    'This setting will show drive letters after the drive label in File Explorer (Default Windows behavior).', 'הגדרה זו תציג את אותיות הכונן אחרי תווית הכונן בסייר הקבצים (התנהגות ברירת המחדל של Windows).',
    'Showing drive letters after drive label', 'מציג את אותיות הכונן אחרי תווית הכונן',
    'Show network drive letters before drive label', 'הצג את אותיות כונני הרשת לפני תווית הכונן',
    'This setting will show only network drive letters before the drive label in File Explorer.', 'הגדרה זו תציג רק את אותיות כונני הרשת לפני תווית הכונן בסייר הקבצים.',
    'Showing network drive letters before drive label', 'מציג את אותיות כונני הרשת לפני תווית הכונן',
    "This setting will hide all drive letters from the File Explorer navigation pane and 'This PC'.", 'הגדרה זו תסתיר את כל אותיות הכוננים מחלונית הניווט של סייר הקבצים ומ"מחשב זה".',
    'Hiding all drive letters', 'מסתיר את כל אותיות הכוננים',

    # --- Optional Windows Features ---
    'Enable Windows Sandbox', 'הפעל את Windows Sandbox',
    "Windows Sandbox is a lightweight desktop environment for safely running applications in isolation. Software installed inside the Windows Sandbox environment remains 'sandboxed' and runs separately from the host machine. Only supported on Windows 11 Pro, Workstation, and Enterprise editions.", 'Windows Sandbox היא סביבת שולחן עבודה קלת משקל להרצת אפליקציות בבידוד בצורה בטוחה. תוכנה המותקנת בתוך סביבת Windows Sandbox נשארת מבודדת ("sandboxed") ופועלת בנפרד ממחשב המארח. נתמך רק במהדורות Windows 11 Pro, Workstation ו-Enterprise.',
    'Enabling Windows Sandbox', 'מפעיל את Windows Sandbox',
    'Disable Windows Sandbox', 'השבת את Windows Sandbox',
    'Disabling Windows Sandbox', 'משבית את Windows Sandbox',
    'Enable Windows Subsystem for Linux', 'הפעל את Windows Subsystem for Linux',
    'Windows Subsystem for Linux allows you to run a Linux environment directly on Windows without the need for a virtual machine.', 'Windows Subsystem for Linux מאפשר להריץ סביבת Linux ישירות על Windows ללא צורך במכונה וירטואלית.',
    'Enabling Windows Subsystem for Linux', 'מפעיל את Windows Subsystem for Linux',
    'Disable Windows Subsystem for Linux', 'השבת את Windows Subsystem for Linux',
    'Disabling Windows Subsystem for Linux', 'משבית את Windows Subsystem for Linux'
)

# ------------------------------------------------------------------------------
#  Apps.json - app descriptions (friendly product names are kept as-is) and
#  preset names. Passed as flat pairs (several descriptions repeat verbatim).
# ------------------------------------------------------------------------------
Add-LocPairs @(
    'Video editor from Microsoft', 'עורך וידאו של Microsoft',
    'Basic 3D modeling software', 'תוכנת מידול תלת-ממד בסיסית',
    'Microsoft Cortana voice assistant (Discontinued)', 'העוזר הקולי Cortana של Microsoft (הופסק)',
    'Finance news and tracking via Bing (Discontinued)', 'חדשות ומעקב פיננסי באמצעות Bing (הופסק)',
    'Recipes and food news via Bing (Discontinued)', 'מתכונים וחדשות אוכל באמצעות Bing (הופסק)',
    'Health and fitness tracking/news via Bing (Discontinued)', 'מעקב וחדשות בתחום הבריאות והכושר באמצעות Bing (הופסק)',
    'News aggregator via Bing (Replaced by Microsoft News/Start)', 'מאגד חדשות באמצעות Bing (הוחלף ב-Microsoft News/Start)',
    'Sports news and scores via Bing (Discontinued)', 'חדשות ותוצאות ספורט באמצעות Bing (הופסק)',
    'Translation service via Bing', 'שירות תרגום באמצעות Bing',
    'Travel planning and news via Bing (Discontinued)', 'תכנון נסיעות וחדשות באמצעות Bing (הופסק)',
    'Weather forecast via Bing', 'תחזית מזג אוויר באמצעות Bing',
    'AI assistant integrated into Windows', 'עוזר בינה מלאכותית המשולב ב-Windows',
    'Copilot+ AI Hub app (Windows 11 24H2+)', 'אפליקציית Copilot+ AI Hub ‏(Windows 11 24H2 ומעלה)',
    'Microsoft PC Manager system cleanup and optimization tool (often preinstalled)', 'כלי ניקוי ואופטימיזציה של המערכת Microsoft PC Manager (לרוב מותקן מראש)',
    'Tips and introductory guide for Windows (Cannot be uninstalled in Windows 11)', 'טיפים ומדריך היכרות ל-Windows (לא ניתן להסרה ב-Windows 11)',
    'Messaging app, often integrates with Skype (Largely discontinued)', 'אפליקציית הודעות, לרוב משתלבת עם Skype (הופסקה ברובה)',
    'Viewer for 3D models', 'מציג למודלים תלת-ממדיים',
    'Digital note-taking app optimized for pen input', 'אפליקציית רישום דיגיטלי המותאמת לקלט עט',
    'Hub to access Microsoft Office apps and documents (Precursor to Microsoft 365 app)', 'מרכז גישה לאפליקציות ולמסמכים של Microsoft Office (קודמתה של אפליקציית Microsoft 365)',
    'Business analytics service client', 'לקוח שירות אנליטיקה עסקית',
    'Collection of solitaire card games', 'אוסף משחקי קלפים מסוג סוליטר',
    'Digital sticky notes app (Discontinued & replaced by OneNote)', 'אפליקציית פתקיות דיגיטליות (הופסקה והוחלפה ב-OneNote)',
    'Portal for Windows Mixed Reality headsets', 'פורטל לאוזניות Windows Mixed Reality',
    'Internet connection speed test utility', 'כלי לבדיקת מהירות חיבור האינטרנט',
    'News aggregator (Replaced Bing News, now part of Microsoft Start)', 'מאגד חדשות (החליף את Bing News, כיום חלק מ-Microsoft Start)',
    'Digital note-taking app (Universal Windows Platform version)', 'אפליקציית רישום דיגיטלי (גרסת Universal Windows Platform)',
    'Presentation and storytelling app', 'אפליקציה למצגות וסיפור סיפורים',
    'Mobile Operator management app (Replaced by Mobile Plans)', 'אפליקציה לניהול מפעיל סלולרי (הוחלפה ב-Mobile Plans)',
    '3D printing preparation software', 'תוכנה להכנת הדפסות תלת-ממד',
    'Desktop automation tool (RPA)', 'כלי אוטומציה לשולחן העבודה (RPA)',
    'Skype communication app, Universal Windows Platform version (Discontinued)', 'אפליקציית התקשורת Skype, גרסת Universal Windows Platform (הופסקה)',
    'To-do list and task management app', 'אפליקציה לרשימת מטלות וניהול משימות',
    'Developer dashboard and tool configuration utility (Discontinued)', 'לוח בקרה למפתחים וכלי להגדרת כלים (הופסק)',
    'Alarms & Clock app', 'אפליקציית שעונים מעוררים ושעון',
    'App for providing feedback to Microsoft on Windows', 'אפליקציה למתן משוב ל-Microsoft בנוגע ל-Windows',
    'Mapping and navigation app', 'אפליקציית מפות וניווט',
    'Basic audio recording app', 'אפליקציה בסיסית להקלטת שמע',
    'Old Xbox Console Companion App (Discontinued)', 'אפליקציית Xbox Console Companion הישנה (הופסקה)',
    'Movies & TV app for renting/buying/playing video content (Rebranded as "Films & TV")', 'אפליקציית סרטים וטלוויזיה להשכרה/קנייה/הפעלה של תוכן וידאו (מותגה מחדש בשם "Films & TV")',
    'Family Safety App for managing family accounts and settings', 'אפליקציית Family Safety לניהול חשבונות והגדרות משפחתיים',
    'Remote assistance tool', 'כלי לסיוע מרחוק',
    'Old Microsoft Teams personal (MS Store version)', 'Microsoft Teams האישי הישן (גרסת MS Store)',
    'New Microsoft Teams app (Work/School or Personal)', 'אפליקציית Microsoft Teams החדשה (עבודה/בית ספר או אישי)',
    'Media player app', 'אפליקציית נגן מדיה',
    'Potentially UI controls or software components, often bundled by OEMs', 'ככל הנראה פקדי ממשק משתמש או רכיבי תוכנה, לרוב נכללים על ידי יצרני ציוד',
    'Basic photo editing app from Adobe', 'אפליקציה בסיסית לעריכת תמונות של Adobe',
    'Amazon shopping app', 'אפליקציית הקניות של Amazon',
    'Amazon Prime Video streaming service app', 'אפליקציית שירות הסטרימינג Amazon Prime Video',
    'Racing game', 'משחק מירוצים',
    'Digital drawing and sketching app', 'אפליקציה לציור ורישום דיגיטלי',
    'Casino slot machine game', 'משחק מכונת מזל בקזינו',
    'Restaurant simulation game', 'משחק סימולציית מסעדה',
    'Multimedia software suite (often preinstalled by OEMs)', 'חבילת תוכנת מולטימדיה (לרוב מותקנת מראש על ידי יצרני ציוד)',
    'Disney theme park building game', 'משחק בניית פארק שעשועים של דיסני',
    'General Disney content app (may vary by region/OEM, often Disney+)', 'אפליקציית תוכן כללית של דיסני (עשויה להשתנות לפי אזור/יצרן, לרוב Disney+)',
    'PDF viewing and annotation app, often focused on pen input', 'אפליקציה להצגה והוספת הערות לקובצי PDF, לרוב ממוקדת בקלט עט',
    'Language learning app', 'אפליקציה ללימוד שפות',
    'Often related to specific OEM software or utilities (e.g. for managing screen settings)', 'לרוב קשורה לתוכנה או לכלים ספציפיים של יצרני ציוד (למשל לניהול הגדרות מסך)',
    'Facebook social media app', 'אפליקציית הרשת החברתית Facebook',
    'Farming simulation game', 'משחק סימולציית חקלאות',
    'Fitbit activity tracker companion app', 'אפליקציית לוויין לעוקב הפעילות Fitbit',
    'News and social network aggregator styled as a magazine', 'מאגד חדשות ורשתות חברתיות בעיצוב מגזין',
    'Hidden object puzzle adventure game', 'משחק הרפתקאות וחידות לחיפוש חפצים',
    'Hulu streaming service app', 'אפליקציית שירות הסטרימינג Hulu',
    'Internet radio streaming app', 'אפליקציית רדיו אינטרנטי',
    'Instagram social media app', 'אפליקציית הרשת החברתית Instagram',
    'Puzzle game from King', 'משחק חידות של King',
    'LinkedIn professional networking app', 'אפליקציית הרשת המקצועית LinkedIn',
    'Strategy game', 'משחק אסטרטגיה',
    'Netflix streaming service app', 'אפליקציית שירות הסטרימינג Netflix',
    'New York Times crossword puzzle app', 'אפליקציית התשבצים של New York Times',
    'Calendar aggregation app', 'אפליקציה לאיחוד יומנים',
    'Pandora music streaming app', 'אפליקציית הסטרימינג המוזיקלי Pandora',
    'Photo collage creation app', 'אפליקציה ליצירת קולאז׳ תמונות',
    'Photo editing and creative app', 'אפליקציה לעריכת תמונות ויצירה',
    'Media server and player app', 'אפליקציית שרת ונגן מדיה',
    'Photo editing app (Academic Edition)', 'אפליקציה לעריכת תמונות (מהדורה אקדמית)',
    'Tower defense / strategy game', 'משחק הגנת מגדלים / אסטרטגיה',
    'Music identification app', 'אפליקציה לזיהוי מוזיקה',
    'Live wallpaper app', 'אפליקציית טפט חי',
    'Live TV streaming service app', 'אפליקציית שירות סטרימינג של טלוויזיה בשידור חי',
    'Spotify music streaming app', 'אפליקציית הסטרימינג המוזיקלי Spotify',
    'TikTok short-form video app', 'אפליקציית הסרטונים הקצרים TikTok',
    'Twitter (now X) social media app', 'אפליקציית הרשת החברתית Twitter (כיום X)',
    'Messaging and calling app', 'אפליקציה להודעות ושיחות',
    'File compression and extraction utility (Universal Windows Platform version)', 'כלי לדחיסה וחילוץ קבצים (גרסת Universal Windows Platform)',
    'To-do list app (Acquired by Microsoft, functionality moved to Microsoft To Do)', 'אפליקציה לרשימת מטלות (נרכשה על ידי Microsoft, הפונקציונליות הועברה ל-Microsoft To Do)',
    'Professional networking platform popular in German-speaking countries', 'פלטפורמת רשת מקצועית הפופולרית במדינות דוברות גרמנית',
    'Web Search from Microsoft Bing (Integrates into Windows Search)', 'חיפוש אינטרנט של Microsoft Bing (משתלב בחיפוש של Windows)',
    "Windows' default browser, WARNING: Removing this app also removes the only browser from Windows Sandbox and could affect other apps", 'הדפדפן המוגדר כברירת מחדל ב-Windows. אזהרה: הסרת אפליקציה זו מסירה גם את הדפדפן היחיד מ-Windows Sandbox ועלולה להשפיע על אפליקציות אחרות',
    'Modern Xbox Gaming App, required for installing some PC games', 'אפליקציית המשחקים המודרנית של Xbox, נדרשת להתקנת חלק ממשחקי ה-PC',
    'Required for some Windows 11 Troubleshooters and support interactions', 'נדרש עבור חלק מפותרי הבעיות של Windows 11 ולאינטראקציות תמיכה',
    'Microsoft 365 (Business) Calendar, Files and People mini-apps, these apps may be reinstalled if enabled by your Microsoft 365 admin', 'אפליקציות מיני של Microsoft 365 (עסקי) ליומן, קבצים ואנשים. אפליקציות אלו עשויות להיות מותקנות מחדש אם מנהל ה-Microsoft 365 שלך יפעיל אותן',
    'Paint 3D (Modern paint application with 3D features)', 'Paint 3D (אפליקציית צייר מודרנית עם תכונות תלת-ממד)',
    'OneDrive consumer cloud storage client', 'לקוח אחסון הענן הצרכני OneDrive',
    'New Outlook for Windows mail client', 'לקוח הדואר Outlook החדש ל-Windows',
    'Classic Paint (Traditional 2D paint application)', 'צייר הקלאסי (אפליקציית צייר דו-ממדית מסורתית)',
    'Required for & included with Mail & Calendar (discontinued)', 'נדרש עבור וכלול באפליקציית דואר ויומן (הופסק)',
    'Remote Desktop client app', 'אפליקציית לקוח של שולחן עבודה מרוחק',
    'Snipping Tool (Screenshot and annotation tool)', 'כלי החיתוך (כלי לצילום מסך והוספת הערות)',
    'This app powers Windows Widgets My Feed', 'אפליקציה זו מפעילה את "ההזנה שלי" של יישומוני Windows',
    'Digital collaborative whiteboard app', 'אפליקציית לוח שיתופי דיגיטלי',
    'Default photo viewing and basic editing app', 'אפליקציית ברירת המחדל להצגת תמונות ועריכה בסיסית',
    'Calculator app', 'אפליקציית מחשבון',
    'Camera app for using built-in or connected cameras', 'אפליקציית מצלמה לשימוש במצלמות מובנות או מחוברות',
    'Mail & Calendar app suite (Discontinued)', 'חבילת אפליקציות דואר ויומן (הופסקה)',
    'Notepad text editor app', 'אפליקציית עורך הטקסט Notepad',
    'Microsoft Store, WARNING: This app cannot be reinstalled easily if removed!', 'Microsoft Store. אזהרה: לא ניתן להתקין אפליקציה זו מחדש בקלות אם תוסר!',
    'Default terminal app in windows 11 (Command Prompt, PowerShell, WSL), WARNING: Do not remove if you launched Win11Debloat from Windows Terminal, as this will cause the script to fail.', 'אפליקציית הטרמינל המוגדרת כברירת מחדל ב-Windows 11 ‏(Command Prompt, PowerShell, WSL). אזהרה: אל תסיר אם הפעלת את Win11Debloat דרך Windows Terminal, מכיוון שהדבר יגרום לכשל בסקריפט.',
    'UI framework, seems to be required for Microsoft Store, photos and certain games', 'תשתית ממשק משתמש; נראה שנדרשת עבור Microsoft Store, תמונות ומשחקים מסוימים',
    'Game overlay, required/useful for some games (Part of Xbox Game Bar)', 'שכבת-על למשחקים, נדרשת/שימושית עבור חלק מהמשחקים (חלק מ-Xbox Game Bar)',
    'Xbox sign-in framework, required for some games and Xbox services', 'תשתית התחברות של Xbox, נדרשת עבור חלק מהמשחקים ושירותי Xbox',
    'Accessibility feature required for some games, WARNING: This app cannot be reinstalled easily!', 'תכונת נגישות הנדרשת עבור חלק מהמשחקים. אזהרה: לא ניתן להתקין אפליקציה זו מחדש בקלות!',
    'Phone link (Connects Android/iOS phone to PC)', 'Phone Link (מחבר טלפון Android/iOS למחשב)',
    'Modern Media Player (Replaced Groove Music, plays local audio/video)', 'נגן מדיה מודרני (החליף את Groove Music, מנגן שמע/וידאו מקומי)',
    'Phone integration within File Explorer, Camera and more (Part of Phone Link features)', 'שילוב טלפון בתוך סייר הקבצים, מצלמה ועוד (חלק מתכונות Phone Link)',
    'Helps deliver and update certain features, like Widgets, through the Microsoft Store', 'מסייע לספק ולעדכן תכונות מסוימות, כמו יישומונים, דרך Microsoft Store',
    'Runtime required for Windows Widgets to function', 'סביבת ריצה הנדרשת לתפקוד יישומוני Windows',
    'HP OEM software, AI-enhanced features and support', 'תוכנת יצרן של HP, תכונות מבוססות בינה מלאכותית ותמיכה',
    'HP OEM software for music (Potentially discontinued)', 'תוכנת יצרן של HP למוזיקה (ייתכן שהופסקה)',
    'HP OEM software for photos, integrated with Snapfish (Potentially discontinued)', 'תוכנת יצרן של HP לתמונות, משולבת עם Snapfish (ייתכן שהופסקה)',
    'HP OEM software providing desktop support tools', 'תוכנת יצרן של HP המספקת כלי תמיכה לשולחן העבודה',
    'HP OEM software for system cleaning or optimization', 'תוכנת יצרן של HP לניקוי או אופטימיזציה של המערכת',
    'HP OEM software for viewing specific file types', 'תוכנת יצרן של HP להצגת סוגי קבצים מסוימים',
    'HP OEM software for tutorials, app discovery, or quick access to HP features', 'תוכנת יצרן של HP למדריכים, גילוי אפליקציות או גישה מהירה לתכונות HP',
    'HP OEM software for PC hardware diagnostics', 'תוכנת יצרן של HP לאבחון חומרת המחשב',
    'HP OEM software for managing power settings and battery', 'תוכנת יצרן של HP לניהול הגדרות צריכת חשמל וסוללה',
    'HP OEM software for managing HP printers', 'תוכנת יצרן של HP לניהול מדפסות HP',
    'HP OEM software for managing privacy settings', 'תוכנת יצרן של HP לניהול הגדרות פרטיות',
    'HP OEM software for quick file transfer between devices', 'תוכנת יצרן של HP להעברת קבצים מהירה בין מכשירים',
    'HP OEM software, possibly for touch-specific shortcuts or controls', 'תוכנת יצרן של HP, ככל הנראה לקיצורי דרך או פקדים ייעודיים למגע',
    'HP OEM software for product registration', 'תוכנת יצרן של HP לרישום מוצר',
    'HP OEM software for support, updates, and troubleshooting', 'תוכנת יצרן של HP לתמיכה, עדכונים ופתרון בעיות',
    'HP OEM security software, likely AI-based threat protection', 'תוכנת אבטחה של יצרן HP, ככל הנראה הגנה מפני איומים מבוססת בינה מלאכותית',
    'HP OEM software for displaying system information', 'תוכנת יצרן של HP להצגת מידע מערכת',
    'HP OEM software providing a welcome experience or initial setup help', 'תוכנת יצרן של HP המספקת חוויית קבלת פנים או סיוע בהתקנה ראשונית',
    'HP OEM software focused on well-being, possibly with break reminders or ergonomic tips', 'תוכנת יצרן של HP המתמקדת ברווחה, ייתכן עם תזכורות להפסקות או טיפים ארגונומיים',
    'HP OEM central hub app for device info, support, and services', 'אפליקציית מרכז של יצרן HP למידע על המכשיר, תמיכה ושירותים',
    'Lenovo OEM hub app for device settings, updates, and support', 'אפליקציית מרכז של יצרן Lenovo להגדרות מכשיר, עדכונים ותמיכה',
    'Background service component for Lenovo Vantage', 'רכיב שירות רקע עבור Lenovo Vantage',
    'Dell OEM support, diagnostic, and update tool', 'כלי תמיכה, אבחון ועדכון של יצרן Dell',
    'Dell OEM software for delivering pre-purchased software', 'תוכנת יצרן של Dell לאספקת תוכנה שנרכשה מראש',
    'Dell OEM app for linking Android/iOS phone to PC (superseded by Phone Link)', 'אפליקציית יצרן של Dell לקישור טלפון Android/iOS למחשב (הוחלפה ב-Phone Link)',
    # Apps.json preset names + the "Select <name>" tooltip template
    'Xbox Gaming apps', 'אפליקציות משחקים של Xbox',
    'OEM software (Dell, HP, Lenovo)', 'תוכנות יצרן (Dell, HP, Lenovo)',
    'Select {0}', 'בחר {0}'
)

# ==============================================================================
#  ENGINE
# ==============================================================================

# Look up a single string in the Hebrew dictionary. Returns the original text
# (unchanged) when there is no translation, so icon glyphs, product names,
# package IDs and user input pass through untouched.
function Get-LocalizedString {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
    if ($script:UILanguage -eq 'en') { return $Text }

    $key = $Text.Trim()
    if ($script:HeStrings.ContainsKey($key)) {
        return $script:HeStrings[$key]
    }
    return $Text
}

# Look up a format template and fill in the placeholders ({0}, {1}, ...).
function Format-Localized {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $false)]
        [object[]]$Values = @()
    )

    $template = Get-LocalizedString $Key
    try {
        return ($template -f $Values)
    }
    catch {
        return $template
    }
}

# Translate the display fields of the parsed Features.json object in place.
# Category names are intentionally left untouched because they are used as
# logic keys; their visible header is localized separately via Get-LocalizedString.
function Localize-FeaturesData {
    param($FeaturesJson)

    if (-not (Test-LocalizationActive)) { return $FeaturesJson }
    if (-not $FeaturesJson) { return $FeaturesJson }

    if ($FeaturesJson.UiGroups) {
        foreach ($group in $FeaturesJson.UiGroups) {
            if ($group.PSObject.Properties['Label'] -and $group.Label) { $group.Label = Get-LocalizedString $group.Label }
            if ($group.PSObject.Properties['ToolTip'] -and $group.ToolTip) { $group.ToolTip = Get-LocalizedString $group.ToolTip }
            if ($group.Values) {
                foreach ($value in $group.Values) {
                    if ($value.PSObject.Properties['Label'] -and $value.Label) { $value.Label = Get-LocalizedString $value.Label }
                }
            }
        }
    }

    if ($FeaturesJson.Features) {
        foreach ($feature in $FeaturesJson.Features) {
            foreach ($field in 'Label', 'ToolTip', 'ApplyText', 'UndoLabel', 'ApplyUndoText') {
                if ($feature.PSObject.Properties[$field] -and $feature.$field) {
                    $feature.$field = Get-LocalizedString $feature.$field
                }
            }
        }
    }

    return $FeaturesJson
}

# Translate the display fields of the $script:Features lookup (FeatureId -> object)
# that the apply modal and the restore-backup dialog read from. Only display text
# is touched; FeatureId/RegistryKey/version fields are left intact.
function Localize-ScriptFeatures {
    if (-not (Test-LocalizationActive)) { return }
    if (-not $script:Features) { return }
    foreach ($feature in $script:Features.Values) {
        if (-not $feature) { continue }
        foreach ($field in 'Label', 'ToolTip', 'ApplyText', 'UndoLabel', 'ApplyUndoText') {
            if ($feature.PSObject.Properties[$field] -and $feature.$field) {
                $feature.$field = Get-LocalizedString $feature.$field
            }
        }
    }
}

# Recursively translate a single WPF element's visible text properties.
function ConvertTo-LocalizedElement {
    param($Element)

    if ($null -eq $Element) { return }

    # ToolTip (string, TextBlock or ToolTip control) and accessibility name
    if ($Element -is [System.Windows.FrameworkElement]) {
        $tt = $Element.ToolTip
        if ($tt -is [string]) {
            $Element.ToolTip = Get-LocalizedString $tt
        }
        elseif ($tt -is [System.Windows.Controls.TextBlock]) {
            $tt.Text = Get-LocalizedString $tt.Text
        }
        elseif ($tt -is [System.Windows.Controls.ToolTip] -and $tt.Content -is [string]) {
            $tt.Content = Get-LocalizedString $tt.Content
        }

        $autoName = [System.Windows.Automation.AutomationProperties]::GetName($Element)
        if (-not [string]::IsNullOrEmpty($autoName)) {
            $Element.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, (Get-LocalizedString $autoName))
        }
    }

    # Type-specific text / content / header
    if ($Element -is [System.Windows.Controls.TextBlock]) {
        # The Text getter returns the full text (including a single <Run>), and the
        # setter replaces the content with the translation. This is more reliable
        # than mutating individual inlines. Skip empty placeholders.
        if (-not [string]::IsNullOrEmpty($Element.Text)) {
            $Element.Text = Get-LocalizedString $Element.Text
        }
    }
    elseif ($Element -is [System.Windows.Controls.TabItem]) {
        # TabItem headers are read by code as identifiers - never translate them.
    }
    elseif ($Element -is [System.Windows.Controls.HeaderedItemsControl]) {
        if ($Element.Header -is [string]) { $Element.Header = Get-LocalizedString $Element.Header }
    }
    elseif ($Element -is [System.Windows.Controls.HeaderedContentControl]) {
        if ($Element.Header -is [string]) { $Element.Header = Get-LocalizedString $Element.Header }
    }
    elseif ($Element -is [System.Windows.Controls.ContentControl]) {
        if ($Element.Content -is [string]) { $Element.Content = Get-LocalizedString $Element.Content }
    }

    # Recurse into logical children
    foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($Element)) {
        if ($child -is [System.Windows.DependencyObject]) {
            ConvertTo-LocalizedElement $child
        }
    }

    # Recurse into items of items-controls (combo boxes, menus) - items are not
    # always part of the logical tree until they are realized.
    if ($Element -is [System.Windows.Controls.ItemsControl]) {
        foreach ($item in @($Element.Items)) {
            if ($item -is [System.Windows.DependencyObject]) {
                ConvertTo-LocalizedElement $item
            }
        }
    }

    # A ContextMenu hangs off a property, not the logical tree - walk it too.
    if ($Element -is [System.Windows.FrameworkElement] -and $null -ne $Element.ContextMenu) {
        ConvertTo-LocalizedElement $Element.ContextMenu
    }

    # Popups (e.g. the preset fly-outs) expose their content via .Child.
    if ($Element -is [System.Windows.Controls.Primitives.Popup] -and $null -ne $Element.Child) {
        ConvertTo-LocalizedElement $Element.Child
    }
}

# Localize a whole window: switch it to right-to-left and translate every
# visible string. Safe to call more than once (translation is idempotent).
function Invoke-WindowLocalization {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Window
    )

    if ($null -eq $Window) { return }
    if (-not (Test-LocalizationActive)) { return }

    try { $Window.FlowDirection = [System.Windows.FlowDirection]::RightToLeft } catch { }

    if (-not [string]::IsNullOrEmpty($Window.Title)) {
        $Window.Title = Get-LocalizedString $Window.Title
    }

    ConvertTo-LocalizedElement $Window
}

# Localize the in-memory feature lookup as soon as this module is loaded, so the
# apply modal and restore dialog show Hebrew without any further wiring.
Localize-ScriptFeatures
