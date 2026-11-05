> תרגום לעברית של הקובץ adfu-dump-attempt.md (באנגלית), לעיון בלבד.

# ADFU firmware dump: attempt log and conclusion (2026-11-05)

מטרה: dump לקריאה בלבד של ה-flash של השעון (build 88318) כדי להשיג את ה-firmware המדויק, מכיוון ששרת היצרן אינו מספק אותו. dump מלא היה הדרך היחידה לקראת הסרת התמונות הטעונות מראש (preloaded images) מה-firmware.

## What works

(מה עובד)

- השעון נכנס למצב הורדה ADFU boot-ROM באמצעות `AT+WRX=adfu` דרך ערוץ ה-serial (Charging mode). הוא מופיע כ-USB `10d6:10d6`.
- פרוטוקול ה-boot ROM של Actions (מתוך sonigeez/actions-adfu, אומת) כולל פקודת קריאת זיכרון לקריאה בלבד: CBW `0xCD 0x93` read-RAM(address, length), וכן `0xCC` inquiry. ה-flash ממופה ב-XIP בכתובת 0x10000000, ולכן קריאה שלו לקריאה בלבד אפשרית באופן עקרוני.
- כלים שהוכנו תחת `tools/adfu-dump/`: `adfu_read.py`, `adfu_dump_win.py` (שולח adfu, ואז תופס את ההתקן דרך WinUSB/libusb וקורא זיכרון לקריאה בלבד). pyusb + libusb-package + pyserial הותקנו ב-`tools/adfu-dump/pylibs`.
- דרייבר WinUSB עבור `USB\VID_10D6&PID_10D6` הוכן מראש (pre-staged) עם Zadig "Device -> Create New Device" (והתעודה של Zadig מהימנה).

## The wall (Windows)

(החסם ב-Windows)

1. התקן ה-USB של ADFU נשאר ניתן לזיהוי רק כ-6 שניות, ואז ה-boot ROM מנתק את ה-USB אם לא מגיעה פקודה מה-host.
2. כדי לדבר איתו, Windows צריך ש-WinUSB יהיה קשור (bound) למופע ההתקן. גם כשהדרייבר הוכן מראש, ה-registry הראה Service ריק עבור מופע ההתקן: Windows לא מסיים לקשור את WinUSB בתוך חלון ה-6 שניות.
3. אחרי שה-ADFU פוקע, השעון לא חוזר ל-Charging mode מעצמו; הוא יורד מה-USB וצריך חיבור פיזי מחדש. לכן ניסיון חוזר אוטומטי בין ניסיונות אינו אפשרי.

סיכום: ב-Windows אי אפשר להספיק את קשירת ה-WinUSB החד-פעמית בתוך חלון ה-6 שניות, ואי אפשר לנסות שוב אוטומטית. Windows חסום.

## Viable path (not done)

(נתיב אפשרי, לא בוצע)

Linux נייטיב (live USB או מחשב רזרבי): libusb יכול לפתוח את ההתקן ישירות מ-usbfs ברגע שהוא מופיע (בלי דרייבר שנקשר מראש), כך שסקריפט עצמאי אחד יכול לשלוח `AT+WRX=adfu` דרך ה-serial port ולתפוס את ההתקן תוך אלפיות שנייה, ולהקדים את "הפתיל" של 6 השניות. WSL לא עוזר, כי usbipd עדיין צריך bind בצד של Windows שנתקל באותו race.

## Even with a dump

(גם עם dump)

הסרת התמונות הטעונות מראש דורשת שינוי וצריבה מחדש של ה-firmware. נתיב ה-flash היחיד בתוכנה (ADFU flash) מוחק את ה-flash, ואין recovery image של 88318, ולכן צריבה כושלת תהפוך את השעון ללבנה (brick). לכן dump ישמש למחקר/ארכיון, ולא כדרך בטוחה להסרת התמונות.

## Commands never to send (from the firmware analysis)

(פקודות שאסור לשלוח לעולם, מתוך ניתוח ה-firmware)

partUpan, mergeUpan, testWrite, testReplaceData, delClock, clearInfo, ota, ramdump, adfu-flash with erase. קריאה בלבד.
