> תרגום לעברית של הקובץ dump-commands-analysis.md (באנגלית), לעיון בלבד.

# Firmware Analysis: AT+WRX Dump / Maintenance Commands

קובץ היעד: `ref_fw_88265_DO_NOT_FLASH/app.bin` (תמונת OTA לייחוס מהדגם C175G,
Actions Semiconductor ATS3085S, Zephyr RTOS + Glyphix C++ GUI, ARM Thumb-2, 3203712 בתים).

זהו ניתוח סטטי לקריאה בלבד של קובץ מקומי. לא נגענו בשום התקן, כונן USB או רשת.
כל ה-file offsets מצוינים כדי שאדם יוכל לאמת מחדש ב-Ghidra או ב-IDA.

Disassembler: capstone, CS_ARCH_ARM / CS_MODE_THUMB.

---

## 1. Load base B

**B = 0x10000000**, עם המיפוי `vaddr = file_offset + 0x10000000` (file offset 0 ממופה ל-0x10000000).

איך זה אושר:
- ה-header ב-offset 0 הוא `ACTHHTCA`; מילת ה-32-bit LE ב-offset 8 היא `0x100be7b1`
  (entry / reset pointer). `0x100be7b1 - 0x10000000 = 0xbe7b1`, שנופל בתוך הקובץ
  (גודל 0x30e280), בהתאם ל-entry point בתוך התמונה. אזור ה-XIP הוא 0x10000000+.
- בדיקת מתאם (correlation): חילצתי את כל 10758 ה-offsets של תחילת מחרוזות ASCII המסתיימות ב-null, ואת כל
  55449 מילות 32-bit LE שנופלות בטווח 0x0FFF0000-0x10400000. לכל base מועמד B, ספרתי
  כמה מילות pointer מקיימות ש-`(pointer - B)` שווה לתחילת מחרוזת ידועה. המנצח היה
  מובהק:

  | base B       | pointers landing on a string start |
  |--------------|------------------------------------|
  | 0x10000000   | 16230                              |
  | 0x10000880   | 2979                               |
  | 0x1000bfd8   | 2741                               |

  0x10000000 מנצח ביותר מפי 5 מכל base אחר. רמת ביטחון: **גבוהה**.

- אימות עצמאי: טבלאות ה-dispatch של ה-shell (ראו בהמשך) מחזיקות pointers מוחלטים כגון
  `0x102cbfb2`, שתחת B=0x10000000 נפתרים בדיוק לתחילת מחרוזות
  (`0x2cbfb2 = "screenShot"`). ה-pointers של ה-handlers אי-זוגיים (Thumb bit דלוק) ונפתרים ל-function prologues תקינים.
  זה מאשר את B הן עבור נתונים והן עבור קוד.

---

## 2. How the commands are actually dispatched (important structural finding)

(איך הפקודות מנותבות בפועל - ממצא מבני חשוב)

יש שני משטחי פקודות שונים בתמונה הזו, ואין לבלבל ביניהם:

**(a) קטלוג "AT+WRX=..." ב-file offset 0x30bfac.**
זהו מערך פשוט של slots קבועים של 30 בתים (0x1e) מסוג `char[30]`:
`AT+WRX=dump`, `AT+WRX=showlog`, `AT+WRX=hidelog`, `AT+WRX=always`, `AT+WRX=realUpan`,
`AT+WRX=hideUpan`, `AT+WRX=partUpan`, `AT+WRX=mergeUpan`, `AT+WRX=mass`, `AT+WRX=reboot`,
`AT+WRX=adfu`, `AT+WRX=jtag`, ... `AT+WRX=coreDump` (0x30c1e6), ... `AT+WRX=saveMenu` (0x30c38a).

תוצאה מרכזית: **אף אחת ממחרוזות הקטלוג האלה (ואף אחת מהסיומות `+7` שלהן) אינה מופנית
בשום מקום ב-app.bin.** בדקתי באופן ממצה:
  - מילות pointer מוחלטות של 32-bit השוות ל-vaddr של כל מחרוזת (literal pools) -> 0 התאמות;
  - זוגות immediate של `movw`/`movt` שבונים את ה-vaddr של כל מחרוזת -> 0 התאמות.

לכן בלוק 0x30bfac הוא **קטלוג תיעוד / help בלבד**. הקוד שמנתח שורת `AT+WRX=<x>` נכנסת
ומחליט מה להריץ **אינו נמצא ב-app.bin**. מחרוזות `AT+WRX=...` ש*כן* מופנות נמצאות במקום אחר (למשל `AT+WRX=screenShot` ב-0x2cbfab
מופנית ב-file offset 0xef6bc) והן משמשות **שולחים (senders)**: פונקציות ש*פולטות* הודעת `AT+WRX=...`
לשירות בשם `system_service` (dispatcher ב-0xfce10). הסמנים `WRX_CYFIT_BLE`,
`WRX_CYFIT_SPP`, `WRX_CYFIT_UART` (0x2ad3fb) מראים שערוץ ה-WRX נישא על BLE / SPP / UART,
ולכן מפרש ה-`AT+WRX` בפועל הוא רכיב נפרד (companion / צד BT / כלי host / ROM),
ולא תמונת ה-kernel הזו.

**(b) טבלאות פקודות ה-shell של Zephyr (ה-handlers האמיתיים בתמונה הזו).**
אלה `struct shell_static_entry { const char* syntax; const char* help; const void* subcmd;
shell_cmd_handler handler; u8 mand; u8 opt; }`. מניתי אותן בכל הקובץ. הקבוצה
הרלוונטית היא `xky` ("xky custom commands", מחרוזת השורש ב-0x2b7ec2), שרשומות העלים שלה
כוללות `memDump`, `showLog`, `screenShot`, `saveMenu`, `partUpan`, `mergeUpan`, `mass`,
`clearInfo`, `reboot`, `showFlash`. קבוצת `dbg` נפרדת (שורש ב-0x2b7804) מחזיקה את פעולות היסוד הגולמיות
של זיכרון/flash: `mdw/mdh/mdb` (קריאת זיכרון), `mww/mwh/mwb` (כתיבת זיכרון), `fread`
(קריאת flash), `dumpbuf` (dump של זיכרון לקובץ), `ramdump` (dump של ram ל-flash), `snort` (בדיקת nor).

השמות בקבוצת `xky` חופפים לקטלוג `AT+WRX=` (screenShot, saveMenu, partUpan, mass,
showlog/showLog, clearInfo), מה שמרמז בחוזקה שה-parser החיצוני מעביר
`AT+WRX=<x>` לפקודת ה-shell של Zephyr בשם `xky <x>`. לפי המודל הזה ה-handlers שלהלן הם מה
שרץ בפועל.

הערה על ארבעת השמות שהתבקשו:
- `memDump` -> handler אמיתי של `xky` (מנותח בהמשך).
- `showlog` -> ממופה ל-handler של `xky showLog` (מנותח בהמשך).
- `dump` -> **לא קיימת בתמונה הזו פקודת shell בשם `dump`** (הרשומות הקרובות הלא קשורות:
  `dumpbuf`, `dumpmsg`, `dumpmem`, `memory_dump`). ה-handler לא קיים. UNKNOWN.
- `coreDump` -> **לא קיימת בתמונה הזו פקודת shell בשם `coreDump`**. ה-handler לא קיים.
  UNKNOWN.

---

## 3. Command-by-command findings

(ממצאים לפי פקודה)

### 3.1 memDump  (AT+WRX=memDump -> xky memDump)

- רשומת shell: 0x28f050, שם `memDump`, help `cust memory dump`.
- Handler: va 0x10216937, **file offset 0x216936**. זהו wrapper דק:

```
216936  push {r3, lr}
216938  bl   0x102271ac        ; the worker
21693c  movs r0, #0
21693e  pop  {r3, pc}
```

- ה-Worker ב-**file offset 0x2271ac** קורא לארבע שגרות, מוקפות ב-0xad228(0) / 0xad228(1)
  (זוג suspend-resume של render/lock):

```
2271ac  push {r3, lr}
2271ae  movs r0, #0
2271b0  bl   0x100ad228        ; suspend/lock (arg 0)
2271b4  bl   0x100f3398        ; -> format string "gdi_img_data_list_dump"
2271b8  bl   0x10163838        ; -> prints "JsVM heap stats:" ...
2271bc  bl   0x10146114        ; -> "bitmap_font_cache_dump_info"
2271c0  pop.w {r3, lr}
2271c4  movs r0, #1
2271c6  b.w  0x100ad228        ; resume/unlock (arg 1)
```

- עדות לכוונה (הפניות למחרוזות שנפתרו מה-literal pools של שלושת ה-sub-workers):
  - 0xf3398 מפנה ל-`'gdi_img_data_list_dump'` (0x102ce830) וקורא ל-log-printf ב-0x1f392c עם level r0=3.
  - 0x163838 מפנה ל-`'JsVM heap stats:'` (0x102e7aa6) ול-`'  -- sizeLimit: '` (0x102e7ab7).
  - 0x146114 מפנה ל-`'bitmap_font_cache_dump_info'` (0x102e65a7), גם כן דרך 0x1f392c level 3.
- לא נפתח קובץ, לא ניגשים להתקן flash, ולא נקרא טווח כתובות החוצה. הפקודה רק מדפיסה
  סטטיסטיקות זיכרון של מסגרת ה-GUI של Glyphix (image cache, JS VM heap, font cache) ללוג דרך
  פונקציית ה-printf/log ב-0x1f392c.

**Verdict: SAFE-READONLY.** מדפיס ללוג סטטיסטיקות שימוש בזיכרון ה-GUI שב-RAM. אין קריאת flash,
אין כתיבת קובץ, אין שינוי מצב.

### 3.2 showlog  (AT+WRX=showlog -> xky showLog)

- רשומת shell: 0x28eefc, שם `showLog`, help `show log`.
- Handler: va 0x1021697f, **file offset 0x21697e**:

```
21697e  cmp  r1, #1            ; argc
216980  mov  r0, r1
216982  push {r3, lr}
216984  bne  0x2169 8e
216986  bl   0x100f906c        ; argc==1: enable-log path, r0 = 1
...
21698e  cmp  r1, #2            ; argc==2: level set via argv[1]
216992  ldr  r0, [r2, #4]
```

- ה-Worker 0xf906c פשוט שומר את הבית ב-flag ב-RAM:

```
0f906c  ldr  r3, =0x381e378c   ; SRAM control struct
0f906e  strb r0, [r3, #4]      ; log-enable flag
0f9070  bx   lr
```

(פונקציות גישה שכנות ב-0xf9078/0xf9084/0xf9094 קוראות/כותבות את אותם ביטים של הגדרות הלוג ב-SRAM.)
0x381e378c הוא SRAM (0x381xxxxx), לא flash.

**Verdict: MODE-CHANGE-ONLY.** קובע flag של log-enable / log-level ב-SRAM. אין flash, אין קובץ,
אין שינוי ב-USB.

### 3.3 dump  (AT+WRX=dump)

- מופיעה רק בקטלוג ה-help ב-0x30bfac (`AT+WRX=dump`). אין פקודת shell בשם `dump` ואין
  handler מופנה ב-app.bin.
- קיימות פקודות סמוכות שאינן קשורות (`dumpbuf`, `dumpmsg`, `dumpmem`, `memory_dump`) אך אף אחת אינה בשם
  `dump` בלבד, ורשומת הקטלוג אינה מחוברת לאף אחת מהן בתוך התמונה הזו.

**Verdict: UNKNOWN.** ה-handler של `AT+WRX=dump` אינו כלול בתמונת ה-kernel הזו; הוא
מטופל על ידי מפרש ה-`AT+WRX` החיצוני (BLE/SPP/UART companion או ROM). אי אפשר לאשר
מהקובץ הזה. אין להניח שהוא בטוח.

### 3.4 coreDump  (AT+WRX=coreDump)

- מופיעה רק בקטלוג ה-help ב-0x30bfac (`AT+WRX=coreDump` ב-0x30c1e6, הסיומת `coreDump` ב-
  0x30c1ed). אין פקודת shell בשם `coreDump`, והמחרוזת אינה מופנית בשום מקום ב-app.bin
  (אומת מול literal pools וזוגות movw/movt).

**Verdict: UNKNOWN.** אין handler בתמונה הזו. היא יושבת בקטלוג ליד `adfu` ו-`jtag`
(רשומות recovery ברמה נמוכה), מה שרומז שייתכן שהיא מפעילה dump של ליבת CPU / crash שמטופל על ידי
Actions BROM או fault handler מחוץ ל-app.bin, אבל זה **לא מאושר** וצריך להתייחס אליו
כאל לא ידוע. אין להריץ אותה "כדי לבדוק".

---

## 4. The real dump primitives (the `dbg` shell group)

(פעולות ה-dump האמיתיות - קבוצת ה-shell בשם `dbg`)

אלה קיימות במלואן ונותחו. מגיעים אליהן דרך ה-shell של Zephyr, לא דרך
ארבע פקודות ה-AT שלמעלה.

### dumpbuf  -  memory range to a file  (handler file offset 0xaa870)

Usage string: `'dumpbuf addr len path'` (0x2b7244). התנהגות:
- `0xc0ff8` = fs_open(path = argv[3], flags 0x12 = CREATE|WRITE) לאובייקט קובץ על ה-stack.
- `0x20c274` = strtoul על argv[1] (addr) ועל argv[2] (len).
- `0xc11ac` = fs_write(file, addr, len)  -> כותב את בתי הזיכרון הגולמיים לקובץ.
- `0xc1134` = fs_close.
- בהצלחה מדפיס `'done dumping to %s'` (0x2b7270); בכשל `'fail to open %s'` (0x2b725e).

מכיוון שה-flash ממופה ב-XIP בכתובת 0x10000000, הפניית `addr` אל ה-flash הממופה מבצעת dump של תוכן ה-flash
לקובץ. זו פעולת היסוד השימושית ביותר להשגת תמונה. **WRITES-A-FILE
(קריאת זיכרון, כתיבה למערכת הקבצים).**

### fread  -  raw flash sectors to the console  (handler file offset 0xab2a0)

Usage: `'fread dev_name(sd/spi_flash/spinand) offset'` (0x2b75ac). היא נקשרת להתקן `'spi_flash'`
(0x102a7bec) או spinand/sd, מנתחת את ה-offset, מקצה 0x200, קוראת סקטור אחד של 512 בתים ו-
מדפיסה `'fread 512b: offset=0x%x, buf=0x%x'` (0x2b7603). קוראת flash גולמי (עוקפת XIP) אל
פלט ה-shell, סקטור אחד לקריאה. **READS FLASH to console.**

### mdw / mdh / mdb  -  display memory  (mdw handler file offset 0x216898 -> 0xab1b0)

קוראות זיכרון לפי word/half/byte ומדפיסות לקונסולה. הצצה לזיכרון לקריאה בלבד.

### mww / mwh / mwb  -  memory write (fill)

כותבות ערכים לזיכרון. מסוכן אם מכוונים ל-MMIO או למבנים חיים. (אינה תכנות flash
כשלעצמה, אבל יכולה לפגוע במערכת רצה.)

### ramdump  -  "dump ram to flash"  (handler file offset 0xaab28)

כותבת אזור RAM לאזור dump שמור ב-flash. **WRITES FLASH.**

---

## 5. Supporting / adjacent handlers of note

(handlers תומכים / סמוכים ראויים לציון)

- `saveMenu` (xky, handler file offset 0xab8ec) - ה-handler המופת. פותח/כותב
  `'/1:/custom/menu_list.cfg'` (0x2b7c78): קורא ל-0xf67ac (remove/prepare) ואז ל-0xf5274
  (כתיבת 0x640 בתים מ-SRAM 0x380013d8). מאשר את תבנית עזר כתיבת הקבצים של ה-SDK ושה-
  `/1:/` הוא דיסק המשתמש הפנימי ו-`/0:/` הוא דיסק ה-(SD/mass). **WRITES-A-FILE.**
- `mass` (xky, handler file offset 0x2169c2) - `'enter usb mass mode'`. במסלול argc==1 קורא ל-0xf9048
  ואז ל-0x226490; אחרת ל-0x226448. מעביר את ההתקן ל**מצב USB mass-storage**. זה
  מה שגורם לשעון להתחבר מחדש (re-enumerate) ככונן דיסק ב-host. **USB MODE SWITCH.**
- `partUpan` (xky, handler file offset 0xabb54) - `'part flash'`. כותב ללוג דרך `shell_part_upan`
  (0x2b81a0), מפנה לכונן `'0:'` ולמחרוזות `PART_UPAN` / `USB_DISK_SIZE` (0x2b7d5e /
  0x2b7d68); קורא לעזרי partition/format (0x21e7f2, 0xd6d54 עם גודל 0x200).
  **WRITES-OR-ERASES-FLASH (re-partitions the user disk).**
- `mergeUpan` (xky, handler file offset 0xabadc) - `'merge flash'`, `MERGE_UPAN` (0x2b7d31).
  משלימה את partUpan. **WRITES-OR-ERASES-FLASH.**
- קבוצת actlog: `erase` (handler file offset 0x1021d8) - `'Erase stored actlog'`. מוחקת
  את אזור ה-action-log השמור. **ERASES FLASH (action-log partition only).**
- `nvram` / `getNvram` / `nvdump` - קריאה/כתיבה של אזור ה-NVRAM (factory/config). כתיבה ל-NVRAM יכולה
  לשנות נתוני כיול (calibration) וקישור (binding). מסלולי הקריאה (`nvdump`, `getNvram`) הם לקריאה בלבד.

---

## 6. Can we obtain a full firmware / flash dump, and how?

(האם אפשר להשיג dump מלא של ה-firmware / flash, ואיך?)

**כן - אבל רק דרך קבוצת ה-shell `dbg` של Zephyr, ולא דרך אף אחת מארבע פקודות ה-AT+WRX
שהתבקשו.** אף אחת מ-`AT+WRX=dump`, `AT+WRX=coreDump`, `AT+WRX=memDump`, `AT+WRX=showlog` לא קוראת
flash לקובץ או ל-serial; memDump רק מדפיסה סטטיסטיקות RAM, showlog רק מחליפה flag, וה-
handlers של dump/coreDump אפילו לא נמצאים בתמונה הזו.

היכולות ש*כן* מפיקות dump הן:

1. `dumpbuf <addr> <len> <path>` (handler file offset 0xaa870). מבצעת dump של טווח זיכרון לקובץ.
   ה-flash ממופה ב-XIP בכתובת 0x10000000, ולכן:
   - `dumpbuf 0x10000000 0x30e280 /0:/app.bin` תכתוב את אזור ה-app הממופה לדיסק `/0:`.
   - כדי ללכוד יותר מאזור ה-app הממופה, חוזרים על הפעולה עם טווחים ממופים אחרים.
   הפלט נוחת בנתיב מערכת הקבצים שמעבירים; `/0:/` הוא הדיסק החיצוני/mass, `/1:/` דיסק המשתמש
   הפנימי. אושר על ידי מחרוזת ההצלחה `'done dumping to %s'`.

2. `fread spi_flash <offset>` (handler file offset 0xab2a0). קוראת סקטור flash גולמי של 512 בתים ב-
   `offset` ומדפיסה אותו לפלט ה-shell (serial). אפשר גם לכוון ל-`spinand` או `sd`.
   זה קורא את ה-flash הגולמי (לא רק את תצוגת ה-XIP), 512 בתים לכל הפעלה, אל הקונסולה.

שתיהן דורשות גישה ל-shell של Zephyr. התמונה הזו מראה שה-shell קשור לתעבורת ה-WRX
(סמני UART/SPP/BLE) ושהשמות של `AT+WRX=` ממופים לפקודות shell `xky <name>`; קבוצת
`dbg` הייתה מושגת באותו אופן אם המפרש החיצוני חושף אותה. **האם ההתקן שנשלח אכן חושף את קבוצת `dbg`
לבעלים דרך התעבורה הזמינה אינו ניתן לקביעה מהתמונה הסטטית הזו - זו השאלה הפתוחה היחידה.** אם ה-shell
נגיש, `dumpbuf` לדיסק ה-SD/mass היא הדרך הנקייה להשיג dump של תמונה, ו-`fread` היא הגיבוי דרך serial.

---

## 7. Commands to avoid

(פקודות שיש להימנע מהן)

**אין** להריץ אותן על ההתקן האמיתי בלי נתיב recovery מאומת (ADFU):

- `AT+WRX=partUpan` / `partUpan` (handler 0xabb54) - מחלקת מחדש את דיסק ה-flash של המשתמש
  (`part flash`, `PART_UPAN`, `USB_DISK_SIZE`). עלולה להרוס את מבנה מערכת הקבצים.
- `AT+WRX=mergeUpan` / `mergeUpan` (handler 0xabadc) - `merge flash`, שינוי partition. אותו סיכון.
- `AT+WRX=adfu` / `AT+WRX=jtag` - מכריחות מצב הורדה ADFU / מפעילות JTAG. מכניסות את ההתקן
  למצב recovery/debug ברמה נמוכה (ה-handlers אינם ב-app.bin; ההתנהגות ברמת ROM).
- `AT+WRX=coreDump` ו-`AT+WRX=dump` - handlers לא ידועים (UNKNOWN, לא בתמונה הזו). אין להריץ כדי "לראות
  מה קורה"; `coreDump` יושבת ליד adfu/jtag בקטלוג.
- `ramdump` (handler 0xaab28) - כותבת RAM לאזור dump ב-flash (`dump ram to flash`).
- `mww` / `mwh` / `mwb` - כתיבות זיכרון שרירותיות; יכולות לפגוע במערכת רצה או ב-MMIO.
- actlog `erase` (handler 0x1021d8) - מוחקת את ה-action log השמור.
- כתיבות `nvram <name> <val>` (handler 0xab108) - יכולות לדרוס נתוני כיול / קישור.
- `AT+WRX=mass` / `mass` (handler 0x2169c2) - עוברת למצב USB mass-storage והשעון
  מתחבר מחדש כדיסק. לא הרסנית כשלעצמה, אבל זו הסיבה שההתקן הופיע ככונן.

בטוח להריץ (לקריאה בלבד או RAM בלבד), לפי הניתוח הזה:
- `memDump` (0x216936) - מדפיסה סטטיסטיקות זיכרון GUI ללוג.
- `showlog` / `showLog` (0x21697e) - מחליפה flag של פלט הלוג ב-SRAM.
- `mdw` / `mdh` / `mdb` (0x216898) - קריאת זיכרון לקונסולה.
- `fread ... <offset>` (0xab2a0) - קוראת flash לקונסולה (לקריאה בלבד).
- `nvdump` / `getNvram` - קוראות NVRAM לקונסולה.

---

## 8. Reproduction notes (offsets for Ghidra/IDA)

(הערות לשחזור - offsets עבור Ghidra/IDA)

- טענו את התמונה ב-base 0x10000000 (offset 0 -> 0x10000000).
- טבלת dispatch של ה-shell (`struct shell_static_entry`, stride של 20-24 בתים, מבנה
  `{syntax, help, subcmd, handler(odd Thumb), mand, opt}`): רשומות קבוצת xky ב-0x28e828-0x28f104,
  רשומות קבוצת dbg סביב 0x28ec10-0x28ee80.
- Handlers מרכזיים (file offsets): memDump 0x216936 (worker 0x2271ac), showLog 0x21697e
  (worker 0xf906c), dumpbuf 0xaa870, fread 0xab2a0, mdw 0x216898, ramdump 0xaab28,
  saveMenu 0xab8ec, mass 0x2169c2, partUpan 0xabb54, mergeUpan 0xabadc.
- פונקציית Log/printf: 0x1f392c (r0 = level). הדפסת shell: 0x216120.
- עזרי FS: fs_open 0xc0ff8 (flags 0x12 = CREATE|WRITE), fs_write 0xc11ac, fs_close 0xc1134,
  high-level write-file 0xf5274.
- strtoul: 0x20c274 ו-0x27852e.
- קטלוג AT+WRX (טקסט help בלבד, לא מופנה): 0x30bfac, slots של 30 בתים.
