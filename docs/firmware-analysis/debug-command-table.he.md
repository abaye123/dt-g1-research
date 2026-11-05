> תרגום לעברית של הקובץ debug-command-table.md (באנגלית), לעיון בלבד.

# DT G1 firmware: debug shell command table

מקור: reference firmware 88265 (C175G), הקובץ `app.bin`, נותח כנתונים בלבד. מעולם לא נצרב (flashed). ייתכן שהערכים שונים ב-build 88318.

Load base: 0x10000000 (אושר על ידי 8069 התאמות של string-pointer). Virtual address = file offset + 0x10000000.

יש שתי קבוצות פקודות:

1. טבלת `AT+WRX=...` החיצונית (מחרוזות ליד file offset 0x30bf00-0x30c400): always, realUpan, hideUpan, partUpan, mergeUpan, mass, reboot, adfu, jtag, dump, coreDump, showlog, hidelog, saveMenu, clearInfo, nvram, getNvram, screenShot, setLocation, gpsCWTest ועוד. `AT+WRX=dump` ו-`AT+WRX=coreDump` נמצאות כאן. ה-parser החיצוני מסיר את `AT+WRX=` ומבצע dispatch.

2. טבלת ה-shell הפנימית ב-file offset 0x28eeac, 31 רשומות, כל אחת 20 בתים: {name ptr, help ptr, 0, handler ptr, 0}. המפה המלאה מופיעה למטה. הטבלה הזו מכילה את `memDump` ("cust memory dump"), ולא את `dump`/`coreDump`.

נצפה בשעון האמיתי: שליחת `AT+WRX=dump` לא החזירה נתוני serial והעבירה את השעון למצב USB mass-storage, בלי קובץ חדש בפרטישן המשתמש. לא חד-משמעי עד שיבוצע disassembly של ה-handler.

## Inner shell table (handlers are Thumb, so the real address is the value with bit 0 cleared)

(ה-handlers הם Thumb, ולכן הכתובת האמיתית היא הערך עם bit 0 מאופס.)

| name | help text | handler vaddr | file offset | note |
|---|---|---|---|---|
| mass | enter usb mass mode | 0x102169c3 | 0x2169c3 | עובר ל-mass storage |
| clockTest | enter usb clock test | 0x100ab6e9 | 0xab6e9 | |
| bright | set lcd brightness | 0x100abe2d | 0xabe2d | |
| showFlash | show real flash | 0x102169a1 | 0x2169a1 | קריאה, verify |
| showLog | show log | 0x1021697f | 0x21697f | |
| partUpan | part flash | 0x100abb55 | 0xabb55 | RISK, partition |
| mergeUpan | merge flash | 0x100abadd | 0xabadd | RISK, partition |
| reboot | reboot device | 0x10216941 | 0x216941 | מבצע reboot |
| delClock | delete clock | 0x100abac9 | 0xabac9 | RISK, מוחק |
| showClock | show all clock | 0x100ab871 | 0xab871 | |
| testWrite | test write file | 0x102169e5 | 0x2169e5 | RISK, כותב |
| testRead | test read file | 0x100ab9a5 | 0xab9a5 | |
| testReplaceData | test replace data | 0x100aba2d | 0xaba2d | RISK, כותב |
| gpio_get | get gpio status | 0x100ab911 | 0xab911 | |
| pbap | get pbap | 0x100abde5 | 0xabde5 | |
| ota | ota test | 0x102169e9 | 0x2169e9 | RISK |
| send_call | send call cmd | 0x100abdc5 | 0xabdc5 | |
| wakeLock | get wake lock count | 0x100ab979 | 0xab979 | |
| setAppTest | set app test item | 0x100abc91 | 0xabc91 | |
| sleepData | test sleep data | 0x10216965 | 0x216965 | |
| switchLang | switch lang idx+1 | 0x102169dd | 0x2169dd | |
| memDump | cust memory dump | 0x10216937 | 0x216937 | DUMP, בניתוח |
| a2dp | handle a2dp con or dis | 0x102169e1 | 0x2169e1 | |
| uiEffect | handle ui effect | 0x1021694f | 0x21694f | |
| screenShot | handle screen shot | 0x100ab6fd | 0xab6fd | |
| mpu | handle mpu set | 0x100abcbd | 0xabcbd | |
| quart | quart test | 0x10216927 | 0x216927 | |
| memEnable | mem enable | 0x100abc41 | 0xabc41 | |
| clearInfo | clear custom info | 0x1021692b | 0x21692b | RISK, מנקה |
| saveMenu | save menu | 0x100ab8ed | 0xab8ed | ידוע כבטוח, כותב menu_list.cfg |
| enterSleep | fast enter sleep mode | 0x100ab8b9 | 0xab8b9 | |

## Do not send without disassembly

(לא לשלוח בלי disassembly)

partUpan, mergeUpan ("part flash" / "merge flash"), testWrite, testReplaceData, delClock, clearInfo, ota, adfu, jtag. השמות וטקסטי ה-help מצביעים על כתיבה ל-flash, חלוקה מחדש לפרטישנים (repartitioning), או מחיקה.

disassembly מעמיק יותר לכל handler (מה memDump, dump ו-coreDump קוראות בפועל ולאן הפלט הולך) נמצא ב-`dump-commands-analysis.md`.

## Real-watch test result (2026-11-05)

(תוצאת בדיקה בשעון האמיתי)

נשלח דרך ערוץ ה-serial של AT+WRX בשעון האמיתי (build 88318):
- `AT+WRX=dumpbuf 0x10000000 0x1000 /0:/fwtest.bin` -> אין תשובת serial, אין קובץ ב-D:, השעון התחבר מחדש (re-enumerated) כ-USB mass storage.
- `AT+WRX=dump` קודם לכן -> אותה התנהגות.

מסקנה: קבוצת הפקודות `dbg` (שמכילה את `dumpbuf`, `fread spi_flash`) אינה נגישה דרך ערוץ AT+WRX. הערוץ הזה מגיע רק לקבוצת `xky` (שבה נמצאות `saveMenu`, `mass`, `realUpan`, `showlog`). פקודת AT+WRX שהערוץ לא מזהה מחזירה את השעון למצב mass-storage ולא עושה דבר. לכן dump של ה-firmware דרך נתיב ה-serial הזה לא עובד עם ה-framing הנוכחי. לא נגרם נזק לשעון.
