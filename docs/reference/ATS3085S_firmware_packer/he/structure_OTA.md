מקור: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). זהו תרגום לא רשמי.

# מפרט פורמט קושחת OTA (Actions Semiconductor AOTA)

**פלטפורמה:** Actions Semiconductor ATS3085S
**מערכת הפעלה:** Glyphix / Zephyr RTOS
**מכשיר יעד:** שעונים חכמים DT NO.1 ודומיהם

בהתבסס על ניתוח סטטי ודינמי של hex dumps, וכן על פיצוח (brute-force) מוצלח של אלגוריתם הגיבוב, להלן תיאור מבנה מכולת ה-OTA. בגרסה זו נוספו כתובות הכיסוי המדויקות של סכומי הביקורת וקבועי החומרה.

---

## 1. ארכיטקטורת המכולה הכללית

הפורמט `AOTA` (Actions OTA) הוא ארכיון רב-שכבתי לא מוצפן, ללא חתימה קריפטוגרפית (RSA/ECC). האבטחה והשלמות מבוססות אך ורק על האלגוריתם **CRC32 (IEEE 802.3 / zlib)** המופעל במפל.

הקובץ מורכב מארבעה אזורים לוגיים:
1. **Root Header (כותרת ראשית)** - 512 בתים (0x0200).
2. **FAT (טבלת הקצאת קבצים)** - 512 בתים (0x0200), מתחילה מיד אחרי הכותרת (מכילה עד 16 קבצים).
3. **Data Payload (מטען נתונים)** - הקבצים עצמם, מיושרים בקפדנות לגבולות מקטעים (sectors).
4. **Tail Padding (ריפוד סוף)** - בתים אפסיים עד גבול המקטע.

---

## 2. מבני נתונים בינאריים

כל הערכים רב-הבתיים נכתבים בפורמט **Little-Endian** (אלא אם צוין אחרת במפורש).

### 2.1. הכותרת הראשית (AOTA Header)

הכותרת תופסת תמיד בדיוק מקטע אחד (512 בתים, `0x0200`).

```c
struct aota_header_t {
    char     magic[4];          // 0x000: Magic number "AOTA" (0x41 0x4F 0x54 0x41)
    uint32_t header_checksum;   // 0x004: CRC32 of the header and FAT (calculation range: 0x0008 - 0x03FF)
    uint32_t flags;             // 0x008: Container flags (In the dump: 00 01 00 04)
    uint32_t file_count;        // 0x00C: Number of files in the FAT table (for example, 4)
    uint16_t fat_offset;        // 0x010: Absolute offset of the FAT table (always 0x0200)
    uint16_t data_offset;       // 0x012: Absolute offset of the payload (always 0x0400)
    uint32_t total_file_size;   // 0x014: Total size of the AOTA file including all sector paddings
    uint32_t payload_checksum;  // 0x018: CRC32 of the payload (calculation range: 0x0400 - EOF)
    uint32_t reserved1;         // 0x01C: Reserved (0x00000000)
    uint8_t  padding1[32];      // 0x020: Zero padding up to 0x040
    char     build_ver[32];     // 0x040: Build version and timestamp (null-terminated, max 32 bytes)
    char     platform_id[30];   // 0x060: Platform identifier (null-terminated, max 30 bytes)
    uint16_t hardware_rev;      // 0x07E: Hardware revision of the board (in the dump: 01 00)
    uint8_t  slot_protection[4];// 0x080: System flags for slot A/B or protection (in the dump: 00 00 00 01)
    uint8_t  padding2[380];     // 0x084 - 0x01FF: Zero padding up to the end of the header sector
};
```

### 2.2. טבלת הקצאת קבצים (File Allocation Table)

ממוקמת בהיסטה (offset) שצוינה ב-`fat_offset` (כברירת מחדל `0x0200`). זהו מערך של מבנים. מספר איברי המערך שווה ל-`file_count`. גודל רשומה אחת הוא 32 בתים (`0x20`).

```c
struct aota_fat_entry_t {
    char     filename[16]; // 0x00: File name (null-terminated ASCII). Max 15 characters.
    uint32_t offset;       // 0x10: Absolute offset of the start of the file from the start of the container (0x00000000)
    uint32_t size;         // 0x14: True physical size of the file (excluding sector padding)
    uint32_t reserved;     // 0x18: Reserved (0x00000000)
    uint32_t file_crc32;   // 0x1C: CRC32 (zlib) of the binary data of the current file
};
```

---

## 3. חישובי יישור (Sector Alignment)

מטען האתחול החומרתי של Actions Semiconductor עובד עם זיכרון flash בבלוקים (מקטעים) של 512 בתים. הדבר מציב דרישות מחמירות על פריסת הקובץ:

1. **Data Offset (היסט הנתונים):** הקובץ הראשון (בדרך כלל `ota.xml`) מתחיל תמיד בהיסט `0x0400` (1024 בתים), שכן המקטעים `0x0000` ו-`0x0200` תפוסים בידי הכותרת וטבלת ה-FAT.
2. **ריפוד בין קבצים:** כל קובץ עוקב בתוך הארכיון חייב להתחיל בגבול חדש של מקטע בן 512 בתים.
3. **ריפוד סוף:** סוף הקובץ האחרון מרופד באפסים עד גבול של 512 בתים, וכך נקבע גודל המכולה הסופי (`total_file_size`).

**נוסחה לחישוב ההיסט הבא ב-Python / C:**

```python
# SECTOR_SIZE = 512
next_offset = (current_offset + file_size + 511) & ~511
```

המרווח הריק בין סוף `file_size` לבין `next_offset` שחושב **חייב** להתמלא באפסים (`0x00`).

---

## 4. אלגוריתמי סכומי ביקורת (CRC)

נעשה שימוש באלגוריתם גיבוב סטנדרטי עם הפרמטרים הבאים:
* **אלגוריתם:** `CRC-32 (IEEE 802.3 / zlib)`
* **פולינום:** `0x04C11DB7`
* **Init (ערך התחלתי):** `0xFFFFFFFF`
* **XorOut (XOR סופי):** `0xFFFFFFFF`
* **Reflect In / Out:** `True / True`

### שרשרת האמון (Trust Chain) ואזורי כיסוי הזיכרון:

1. **`file_crc32` (FAT):** מחושב ישירות על `file_size` בתים של מטען הקובץ (בהחלט ללא ריפוד המקטע בן 512 הבתים).
2. **`payload_checksum` (היסט 0x018):** מחושב מההיסט `0x0400` ועד סוף הקובץ (כולל כל הקבצים וכל הריפודים). זהו הגיבוב של כל המטען.
3. **`header_checksum` (היסט 0x004):** מחושב מההיסט `0x0008` עד `0x03FF`. גיבוב זה מכסה:
   * את הדגלים והמטא-דאטה של הכותרת (כולל `payload_checksum` הכתוב בתוכה).
   * את כל טבלת ה-FAT (`0x0200` - `0x03FF`).
   * 8 הבתים הראשונים של הקובץ (החתימה ושדה הגיבוב עצמו) אינם נכללים בחישוב זה.

---

## 5. היררכיית הקבצים הפנימית (מטריושקה)

עבור פלטפורמת ATS3085S (DT NO.1) למכולת ה-`AOTA` יש ארכיטקטורה מקוננת.
הרמה החיצונית (`ota_...bin`) מכילה:

* `ota.xml` - מטא-דאטה עבור המנתח (מזהה תצוגה, גרסאות בנייה).
* `TEMP.bin` - הוא **ארכיון מקונן**. מתואר במסמך נפרד`).
* `sdfs_a.bin` ו-`sdfs_k.bin` - תמונות System Data File System (משאבים, גופנים, רכיבי UI בסיסיים).

### הוראות אריזה מחדש (Workflow):

1. לפרק את ה-`AOTA` החיצוני לפי היסטי ה-FAT. לייצא את `version.txt`.
2. לחלץ את `TEMP.bin`, למצוא את חתימת ה-LZMA (`FD 37 7A 58 5A 00`).
3. לפרוס את ה-LZMA -> לקבל את ה-`AOTA` הפנימי.
4. לפרק את ה-`AOTA` הפנימי, לחלץ את `app.bin`.
5. לבצע שינויים באסמבלר (טלאים / שינוי משאבים).
6. להרכיב את ה-`AOTA` הפנימי (לחשב מחדש את יישור המקטעים, `Payload CRC` ו-`Header CRC`).
7. לדחוס את ה-`AOTA` הפנימי חזרה באלגוריתם LZMA/XZ.
8. להרכיב את ה-`AOTA` החיצוני (להטמיע את `TEMP.bin` החדש, ליישר מקטעים, לחשב מחדש את ה-FAT, `Payload CRC` ו-`Header CRC`, תוך שמירת קבועי החומרה והגרסה).
