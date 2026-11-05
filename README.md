# DT G1 smartwatch customization

Reverse-engineering notes, tools, and a sample app for the DT G1 smartwatch (model C175R, Actions Semiconductor ATS3085S, Glyphix OS on Zephyr). The goal was a fitness watch with an audio player only: no video, no games, and removal of preloaded images.

תיעוד, כלים ואפליקציית דוגמה לשעון DT G1 (דגם C175R, שבב Actions ATS3085S, מערכת Glyphix על Zephyr). המטרה: שעון כושר עם נגן אודיו בלבד, בלי וידאו, בלי משחקים, ובלי התמונות המובנות.

## What was achieved / מה הושג

- 12 menu items hidden (video, games, images, and more) by editing `menu_list.cfg`. Survives a factory reset.
- A custom app ("Whose watch?") built with the official Glyphix toolchain and running on the watch.
- Full understanding of the storage layout, the `.pkg` and OTA formats, and the debug command table.
- The firmware dump over ADFU was mapped out and attempted; it is blocked on Windows (see the notes) and would need native Linux.

- 12 פריטים הוסתרו מהתפריט (וידאו, משחקים, תמונות ועוד) דרך עריכת `menu_list.cfg`. שורד איפוס יצרן.
- אפליקציה משלנו ("למי זה שייך?") נבנתה עם כלי הפיתוח הרשמי ורצה על השעון.
- הבנה מלאה של מבנה האחסון, פורמטי `.pkg` ו-OTA, וטבלת פקודות הדיבאג.
- שאיבת הקושחה דרך ADFU מופתה ונוסתה; היא חסומה ב-Windows (ראו ההערות) ותדרוש Linux אמיתי.

## Start here / נקודת התחלה

- Main notes (English): [docs/DT-G1-notes.en.md](docs/DT-G1-notes.en.md)
- הערות ראשיות (עברית): [docs/DT-G1-notes.he.md](docs/DT-G1-notes.he.md)

## Documentation map / מפת התיעוד

- `docs/DT-G1-notes.en.md` / `.he.md` - the complete notes and work log (device, storage, apps, menu editing, firmware, tools, how to build an app, how to continue).
- `docs/firmware-analysis/` - deep technical analysis (English, with `.he.md` Hebrew copies):
  - `debug-command-table.md` - the full debug command table and handler addresses.
  - `dump-commands-analysis.md` - per-handler disassembly of the dump commands.
  - `adfu-dump-attempt.md` - the ADFU dump journey and why it is blocked on Windows.
- `docs/reference/` - unofficial English and Hebrew translations of the third-party community docs this project relied on (each under `en/`, `he/`, and the `original/`), from these MIT-licensed repos:
  - purrrock/dtg1-menu-editor, purrrock/PurrLaunch, purrrock/ATS3085S_firmware_packer, purrrock/dtg1-glyphix-docs
  - chengchengking/oppo-watch-s-sideload

## Tools / כלים

See the "Full tools inventory" section in the main notes. In short: PowerShell scripts for the watch serial channel, Python tools for the menu and `.pkg` files, the Glyphix CLI (local), and the ADFU reader.

## Safety / בטיחות

Every command sent to the watch here was read-only or a mode change. No write or erase command was ever sent. Removing the preloaded images would require reflashing, which is unsafe without a recovery image for build 88318.

כל פקודה שנשלחה לשעון כאן הייתה קריאה בלבד או מעבר-מצב. שום פקודת כתיבה או מחיקה לא נשלחה. מחיקת התמונות המובנות דורשת צריבה מחדש, שאינה בטוחה בלי קובץ שחזור לגרסה 88318.
