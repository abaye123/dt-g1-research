מקור: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). זהו תרגום לא רשמי.

# ATS3085S Firmware Packer / Unpacker

אוסף כלי Python להנדסה לאחור, פירוק, שינוי והרכבה מחדש של קושחות OTA של שעונים חכמים המבוססים על פלטפורמת החומרה **Actions Semiconductor ATS3085S** (מערכת ההפעלה Glyphix / Zephyr RTOS), כגון **DT NO.1 G1** ודומיו.

הכלים מאפשרים לעקוף את מבנה ה"מטריושקה" הקנייני של מכולות `AOTA`, לחלץ משאבי מערכת (VFS) ואת הליבה (`app.bin`), להחיל טלאים וליצור תמונת OTA תקפה ב-100% לצריבה דרך Bluetooth (BLE).

---

## ⚠️ הצהרת אחריות
**הכלי מיועד אך ורק למטרות מחקר והשכלה.** שינוי שגוי של ליבת מערכת ההפעלה, של דגלי מערכת או של טבלת וקטורי ההפסקות (IVT) עלול להוביל ל"הפיכת המכשיר ללבנה" (hard-brick). השימוש על אחריותך בלבד.

---

## מאפייני הארכיטקטורה

עדכונים לפלטפורמת ATS3085S מסופקים כמכולות לא מוצפנות. ההגנה על השלמות מבוססת אך ורק על מפל של סכומי ביקורת **CRC32 (zlib)**.

הקושחה היא מטריושקה בת שלוש רמות:
* **Layer 1 (AOTA חיצוני):** המכולה הראשית (`.bin`) המכילה את המטא-דאטה `ota.xml`, משאבי ממשק (`sdfs_a.bin`, `sdfs_k.bin`) ותמונת מטען האתחול (bootloader).
* **Layer 2 (מטען האתחול TEMP.bin):** קובץ בינארי המורכב מכותרת אתחול (`ACTHHTCA`), Boot Stub חומרתי וזרם רציף של נתחים (chunks) דחוסי XZ (2 MiB כל אחד).
* **Layer 3 (AOTA פנימי):** תמונה מונוליטית המתקבלת לאחר פריסת כל נתחי ה-XZ. היא מכילה את הליבה ההרצה `app.bin` (Zephyr + Glyphix) ואת קובצי התצורה של המערכת.

> מידע טכני מפורט על הפורמטים והאלגוריתמים זמין בתיקייה `docs/`.

---

## מבנה המאגר

* `aota_full_unpack.py` - צינור העבודה הראשי לפירוק רקורסיבי מלא של הקושחה עד שכבת הליבה.
* `aota_full_pack.py` - צינור העבודה הראשי להרכבה מפלית הפוכה של קבצים ששונו לתמונת OTA מוכנה.
* `BT_ota_flasher.py` - סקריפט לצריבת קובץ ה-`.bin` שהורכב אל השעון דרך Bluetooth Low Energy (BLE). עדיין לא עובד, בתהליך ניפוי שגיאות.
* `tools/` - כלי עזר ברמה נמוכה לניפוי שגיאות ידני של כל שכבה (מפרקי FAT, מפרסי XZ).
* `docs/` - תיעוד הנדסה לאחור.

---

## הוראות שימוש

### דרישות
* Python 3.8+
* אין תלויות חיצוניות לבנייה (נעשה שימוש רק בספריות הסטנדרטיות `struct`, `lzma`, `zlib`).

### 1. פירוק הקושחה המקורית
העבירו את קובץ העדכון המקורי (איך להוריד את קושחת ה-OTA של היצרן מתואר ב-How-to_flashing.md) למפרק הראשי:

```bash
python aota_full_unpack.py original_firmware.bin
```

הסקריפט ייצור את מבנה התיקיות הבא:
```text
original_firmware_extracted/                  <-- Layer 1
├── ota.xml
├── version.txt
├── sdfs_a.bin
├── sdfs_k.bin
└── TEMP_extracted/                           <-- Layer 2
    ├── actions_boot_header.bin
    ├── boot_stub.bin
    └── inner_aota_extracted/                 <-- Layer 3 (Target folder for modding)
        ├── ota.xml
        ├── app.bin                           <-- Executable kernel (ARM Thumb-2)
        └── sdfs.bin
```

### 2. שינוי (Modding)
אפשר לערוך קבצים של מערכת הקבצים או לבצע דיסאסמבלי של `app.bin` (Ghidra / IDA Pro), להחיל טלאי ARM Thumb-2 ולשמור את app.bin בחזרה בתיקייה `inner_aota_extracted/`.

*הערה: אם ברצונכם לשנות את גרסת הקושחה כדי שהשעון יקבל גרסה ישנה יותר (downgrade) או גרסה מותאמת, ערכו את הערך `build_ver` בקובץ `version.txt` (בשורש `original_firmware_extracted/`). כלי הבנייה יטלא אוטומטית את כל קובצי `ota.xml`.*

### 3. בניית הקושחה ששונתה
ציינו את תיקיית השורש של הקושחה שחולצה ואת שם קובץ הפלט:

```bash
python aota_full_pack.py original_firmware_extracted/ custom_firmware.bin
```

הסקריפט יבצע אוטומטית:
1. יישור גודל `app.bin` למקטעים של 512 בתים.
2. הרכבת המונוליט של Layer 3.
3. חיתוך המונוליט לבלוקים של 2 MiB ודחיסתם לפורמט XZ.
4. הדבקת ה-Boot Stub והרכבת `TEMP.bin` תקף (Layer 2).
5. עדכון כל הגדלים וערכי ה-CRC32 בתוך `ota.xml`.
6. יצירת מכולת ה-AOTA הסופית (Layer 1).

### 4. צריבת המכשיר
הוראות לטעינת `custom_firmware.bin` המוכן אל השעון נמצאות בקובץ [How-to_flashing.md](How-to_flashing.md).

---

## תיעוד (Docs)

* [מבנה מכולת ה-AOTA הראשית](docs/structure_OTA.md)
* [הארכיטקטורה הפנימית של מטען האתחול TEMP.bin (Stage-2)](docs/structure_TEMP_bin.md)
* [ניתוח פרוטוקול ה-Bluetooth OTA של WearPro](docs/Bluetooth_OTA_protocol.md)

---

## רישיון
הפרויקט מופץ תחת רישיון MIT. לפרטים ראו את הקובץ [LICENSE](LICENSE).
