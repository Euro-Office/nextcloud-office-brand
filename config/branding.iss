; -- Nextcloud Office brand overrides --
;
; Included by package/inno/common.iss right after defines.iss, but only when
; the file exists. A default (Euro-Office) build ships no branding.iss and is
; therefore untouched.
;
; ISPP assigns #define values at the point of definition, not lazily, so
; redefining sCompanyName alone does NOT update sAppName, sPackageName,
; APP_PATH or APP_REG_UNINST_KEY - they were already computed from the old
; value in defines.iss. Every derived name has to be redefined here too.

#define sCompanyName                    "Nextcloud Office"
#define sIntCompanyName                 "Nextcloud"
#define sProductName                    "Desktop Editors"
#define sIntProductName                 "DesktopEditors"

#define sAppName                        str(sCompanyName)
#define sPackageName                    str(sIntCompanyName + "-" + sIntProductName)

#define sAppPublisher                   "Nextcloud GmbH"
#define sAppPublisherURL                "https://nextcloud.com/"
#define sAppSupportURL                  "https://nextcloud.com/support/"
#define sAppCopyright                   str("© " + sAppPublisher + " " + GetDateTimeString("yyyy",,) + ". All rights reserved.")

#define sAppIconName                    "Nextcloud Office"
#define sOldAppIconName                 "Nextcloud Office Editors"

; Install path, Start menu group and uninstall entry
#define APP_PATH                        str(sIntCompanyName + "\" + sIntProductName)
#define UPD_PATH                        str(sIntProductName + "Updates")
#define APP_REG_PATH                    str("Software\" + APP_PATH)
#define APP_REG_UNINST_KEY              str(sCompanyName + " " + sProductName)

; File-association display names
#define ASSC_APP_NAME                   str(sCompanyName)
#define ASCC_REG_REGISTERED_APP_NAME    str(sCompanyName + " Editors")
#define ASSOC_APP_FRIENDLY_NAME         str(sCompanyName + " Editors")

; Left alone on purpose - changing these breaks upgrades from installed builds:
;   sUpgradeCode, APP_USER_MODEL_ID, APP_MUTEX_NAME, APPWND_CLASS_NAME,
;   ASCC_REG_PREFIX, ASSOC_PROG_ID, iconsExe, NAME_EXE_OUT
