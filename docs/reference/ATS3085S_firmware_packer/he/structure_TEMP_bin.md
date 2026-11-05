מקור: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). זהו תרגום לא רשמי.

# מפרט הפורמט הבינארי של `TEMP.bin`
**פלטפורמה:** Actions Semiconductor ATS3085S  
**פלטפורמת תוכנה:** Glyphix OS / Zephyr RTOS  
**מכשיר יעד:** שעונים חכמים DT NO.1 G1 ותואמים  
**גרסת המפרט:** 1.6 (סופית ומאומתת)

---

## 1. ארכיטקטורת המכולה הכללית

הקובץ הבינארי `TEMP.bin` הוא מכולת אתחול קניינית מדרגה שנייה (Stage-2 Bootable Image Container). הקובץ מיועד להרצה בידי מטען האתחול הראשוני של השבב Actions ATS3085S, לאתחול ציוד היקפי חומרתי / בקר הזיכרון ולאחר מכן לפריסת מחיצות המערכת של הקושחה אל ה-RAM.

המכולה מורכבת מחמישה אזורים לוגיים מרכזיים:
1. **Actions Boot Header (`ACTHHTCA`)** - 40 בתים (`0x00000000`-`0x00000027`).
2. **Alignment Padding** - 472 בתים אפסיים (`0x00000028`-`0x000001FF`), יישור ה-IVT לגבול של 512 בתים.
3. **Interrupt Vector Table (IVT)** - 320 בתים (`0x00000200`-`0x0000033F`), טבלת וקטורי ההפסקות החומרתית של ARM Cortex-M.
4. **Boot Stub Code & Padding Gap** - קוד Thumb-2 בר-הרצה לאתחול החומרה הראשוני ומרווח יישור עד הבלוק הדחוס הראשון.
5. **Compressed Payload Chunks** - רצף של זרמי XZ דחוסים המייצגים את התמונה המונוליטית של המכולה הפנימית `inner_aota_container.bin`, חתוכה למנות של **2 MiB (`0x200000`)**.

---

## 2. מפת הזיכרון הגלובלית של הקובץ (Memory Map)

| היסט (Hex) | סוף הבלוק | גודל (בתים) | תיאור / תוכן |
| :--- | :--- | :--- | :--- |
| `0x00000000` | `0x00000027` | 40 | **כותרת האתחול הראשית** (`ACTHHTCA`) |
| `0x00000028` | `0x000001FF` | 472 | **מילוי יישור** (בתים `0x00`) |
| `0x00000200` | `0x0000033F` | 320 | **טבלת וקטורי הפסקות (IVT)** של ARM Cortex-M |
| `0x00000340` | `entry_point - 1` | משתנה | **Boot Stub Engine**: קוד מכונה Thumb-2 לאתחול החומרה |
| `entry_point` | `first_lzma - 1` | משתנה | **Padding Gap**: מרווח יישור טכני עד מקטע ה-LZMA |
| `first_lzma` | `chunk2_start - 1` | משתנה | **נתח #1**: כותרת `LZMA` (16b) + זרם XZ (בלוק #1 של המונוליט, 2 MiB / `0x200000`) |
| `chunk2_start` | `EOF` | משתנה | **נתח #2**: כותרת `LZMA` (16b) + זרם XZ (בלוק #2 של המונוליט, יתרת הבתים) |

---

## 3. מבני C של הכותרות (Little-Endian)

### 3.1. כותרת Actions Boot Header הראשית (40 בתים / 0x28)
מתחילה בהיסט אפס של הקובץ (`0x00000000`).

```c
struct actions_boot_header_t {
    char     magic[8];       // "ACTHHTCA" (0x41 0x43 0x54 0x48 0x48 0x54 0x43 0x41)
    uint32_t load_addr;      // Load address of the Reset Vector in XIP Flash (for example, 0x1000246D or 0x100024B1)
    uint32_t block_size;     // 0x00000062 (Size of the header service block, 98 bytes)
    uint32_t padding;        // 0x00000000 (Zero filler)
    uint32_t exec_addr;      // Execution entry point in memory (matches load_addr)
    uint32_t entry_point;    // Absolute offset of the boundary of the executable Boot Stub code (for example, 0x00011028)
    uint32_t header_sig;     // Factory static header signature (for example, 0xCA99494D)
    uint32_t payload_sig;    // Factory static payload signature (for example, 0x8BCDC3C5)
    uint32_t ivt_offset;     // 0x00000200 (Offset of the start of the IVT vector table = 512 bytes)
};
```

#### ייעוד השדות המרכזיים:
* **`load_addr` / `exec_addr` (`0x0008`, `0x0014`):** קובעים את כתובת ההתחלה הפיזית של מעבד ARM Cortex-M במצב Thumb (הסיבית הנמוכה שווה `1`). הכתובת ייחודית לכל בניית קושחה.
* **`entry_point` (`0x0018`):** מסמן את סוף מקטע ה-Boot Stub בר-ההרצה. בין `entry_point` לבין נתח ה-`LZMA` הדחוס הראשון יש מילוי (Padding Gap).
* **`header_sig` / `payload_sig` (`0x001C`, `0x0020`):** חתימות סטטיות של היצרן עבור הבנייה הנוכחית. אינן כפופות לחישוב מחדש דינמי דרך zlib/SUM32, ונשמרות ללא שינוי בעת אריזה מחדש.

---

### 3.2. כותרת נתח דחוס Actions LZMA Header (16 בתים / 0x10)
ממוקמת לפני כל בלוק דחוס.

```c
struct actions_lzma_header_t {
    char     magic[4];       // Magic bytes "LZMA" (0x4C 0x5A 0x4D 0x41)
    uint32_t header_size;    // Fixed header size: 0x00000010 (16 bytes)
    uint32_t comp_size;      // Physical size of the packed XZ stream in bytes
    uint32_t uncomp_size;    // Declared size after decompressing the block in RAM (limit 0x200000)
};
```

---

## 4. טבלת הווקטורים החומרתית (IVT)

טבלת הווקטורים ממוקמת בהחלט בהיסט **`0x00000200`** (`ivt_offset = 0x200`):

* **`0x00000200` (Initial MSP):** מצביע מחסנית באזור ה-SRAM הפנימי של ATS3085S.
* **`0x00000204` (Reset Vector):** וקטור איפוס (מצביע על `load_addr`).
* **`0x00000208`-`0x0000023F`:** מטפלי הפסקות מערכתיים של ARM Cortex-M (NMI, HardFault, SVC, SysTick).
* **`0x00000240`-`0x0000033F`:** מטפלי ברירת מחדל להפסקות הציוד ההיקפי של השבב.

---

## 5. מנגנון פיצול המטען (2 MiB Chunking)

המכולה `TEMP.bin` מאחסנת **תמונה בינארית רציפה אחת (`inner_aota_container.bin`)**, שבזמן ההרכבה נחתכת למנות בגודל של לא יותר מ-**2 MiB (`0x200000` בתים / 2 097 152 בתים)**.

### הוכחה לחיתוך בין הבלוקים:
* **תמונה מונוליטית:** מכילה את מכולת ה-AOTA הפנימית עם הקבצים `ota.xml`, `app.bin` (בגודל של יותר מ-3 MB) ו-`sdfs.bin`.
* **Chunk #1:** דוחס את `0x200000` הבתים הראשונים של המונוליט. בשל כך גוף `app.bin` נחתך: `0x001FF800` הבתים הראשונים של הליבה נכנסים לנתח #1.
* **Chunk #2:** דוחס את יתרת המונוליט (`0xFD600` בתים), המכילה את זנב `app.bin` ואת `sdfs.bin`.

---

## 6. תקנון עבודת הכלים (Protocol Standard)

1. **פירוק (`unpack_temp.py` v1.3):**
   - קורא את `actions_boot_header.bin` בן 40 הבתים.
   - מחלץ את `boot_stub.bin` (מ-`0x28` ועד לסמן ההדוק הראשון `LZMA\x10\x00\x00\x00`).
   - פורס את כל זרמי ה-XZ בזיכרון (In-Memory) ומדביק אותם למונוליט אחד `inner_aota_container.bin`.
   - נתחי הביניים `chunk_*.*` נשמרים בדיסק רק בהעברת הדגל האופציונלי `-s` (`--save-chunks`).

2. **הרכבה (`compress_and_pack_temp.py` v1.6):**
   - משתמש ב-`actions_boot_header.bin` המקורי בן 40 הבתים, ושומר את כתובות היצרן והחתימות.
   - כותב את `boot_stub.bin`.
   - חותך את `inner_aota_container.bin` ששונה לחתיכות של `0x200000` בתים, דוחס כל אחת ל-XZ ועוטף בכותרת `actions_lzma_header_t`.
   - מייצר את `TEMP_new.bin` הסופי.
