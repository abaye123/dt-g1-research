> מקור: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). זהו תרגום לא רשמי.

# OPPO Watch S Sideload Toolchain (Glyphix OS)

התקנת אפליקציות JavaScript שכתבתם בעצמכם על **OPPO Watch S (OWW262, Glyphix OS, לא Android)**.
כל התהליך אומת על שעון אמיתי מדגם OWW262 (nucleus 0.7.0-44 / runtime 0.7.0-68).

**רוצים רק להתקין אפליקציה על השעון? שלושת הצעדים למטה מספיקים, את שאר התיקיות אפשר להתעלם מהן בינתיים.**

נדרש: OPPO Watch S + טלפון Android (עם OPPO Health מותקן, מחובר למחשב בכבל ועם "USB debugging" פעיל) + מחשב (Node.js, Python 3).

## שלושה צעדים להתקנה

```bash
# 1) PC, once: install the build toolchain
npm install -g glyphix-cli

# 2) Phone, once: install Guiyuan Assistant (use the copy in this repo, or download the latest from the release page)
#    tools/guiyuan-assistant/glyphix-assistant-v1.2.apk
#    https://www.pgyer.com/glyphix-assistant

# 3) PC, every time: build + push to the phone, in one step
python tools/ows.py install qrwatch
```

בסיום צעד 3 הסקריפט מדפיס את שתי הנגיעות שצריך לבצע בטלפון:

1. פותחים את "瑰元助手" (Guiyuan Assistant) -> לוחצים "连接" (Connect) -> ביומן מופיע `连接成功` (התחבר)
2. לוחצים "安装应用" (Install app) -> Files -> Download -> בוחרים את `qrwatch.rpk`

כשביומן מופיע `安装应用 成功 {"code":200}` (ההתקנה הצליחה), האפליקציה מותקנת. כדי להפעיל אותה לוחצים "启动应用" (Launch app) ומזינים את שם החבילה.

**אם נתקעתם, הריצו `python tools/ows.py doctor`.** הוא בודק אחד אחד את Node / gx / הגדרת המכשיר / adb / החיבור לטלפון,
ונותן פקודת תיקון לכל מה שחסר - אין צורך לנחש איזה שלב הוא הבעיה.

> המטרה של `tools/ows.py` היא לסתום ארבע מלכודות שבוודאות תיפלו בהן:
> אין הגדרת מכשיר ב-gx, Git Bash ממיר את `/sdcard/...` לנתיב מקומי, אין media scan אחרי ה-push
> (החבילה לא נראית ברשימת "Download" של ה-assistant), ולא זוכרים את נתיב תוצר הבנייה.

<details>
<summary>לא רוצים להשתמש בסקריפט? גם ידנית זה רק שלוש פקודות</summary>

```bash
export MSYS_NO_PATHCONV=1          # required in Git Bash
cd apps/qrwatch && gx build -d oppo-rtos-watch -f
adb push .glyphix-work/dist/oppo-rtos-watch/*/bundle.pkg /sdcard/Download/qrwatch.rpk
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Download/qrwatch.rpk
```

אם אין לכם את הגדרת המכשיר `oppo-rtos-watch`, העתיקו את `devices/oppo-rtos-watch.yml` אל
`%APPDATA%\glyphix\devices\` (או פשוט השתמשו ב-`python tools/ows.py setup`).

</details>

## כתיבת אפליקציה משלכם

כדי לשנות את תוכן קוד ה-QR: ערכו את `apps/qrwatch/src/main/qr-data.js`.
לפרויקט חדש: העתיקו את `apps/qrwatch/` ושנו את `package` / `name` ב-manifest.

```json
{
  "package": "com.yourname.app",
  "name": "你的应用",
  "icon": "/assets/icon.png",
  "versionName": "1.0.0",
  "versionCode": 1,
  "router": { "entry": "main", "pages": { "main": { "component": "index" } } }
}
```

⚠️ `icon` הוא **שדה חובה להתקנה על שעון OWS אמיתי**; בלעדיו מתקבלת שגיאה 5005 `invalid package` (התבנית הרשמית רצה באמולטור גם בלי זה, אל תתנו לזה להטעות אתכם).
לתחביר דפים, רכיבים ו-API של `@system.*` ראו את [התיעוד הרשמי](https://github.com/glyphix-os/web-docs) ואת
[docs/DEV_GUIDE.md](docs/DEV_GUIDE.md) §3. לשדרוג פשוט מתקינים מחדש; `versionCode` חייב להיות גדול מזה של הגרסה המותקנת.

## מתקדם (האפליקציה עובדת מצוין גם בלי זה)

המשיכו לקרוא רק אם אתם רוצים את הדברים האלה אחרי שהאפליקציה כבר מותקנת. **אם לא תעשו אף אחד מהם, האפליקציה עדיין תותקן, תרוץ ותופעל מה-assistant.**

| מה רוצים | איך | מחיר |
|---|---|---|
| כניסה עם אייקון בתפריט שולחן העבודה של השעון (כברירת מחדל אין, התפריט hardcoded) | מתקינים את PurrLaunch כדי לתפוס את החריץ "Wooden Fish" (木鱼) | התקנת חבילה אחת, 5 דקות |
| אייקון בשולחן העבודה שאינו גלגל שיניים | משתמשים ב-`tools/ftprobe/` כדי לדחוף `icon_<package name>` ומפעילים מחדש את השעון | דורש Android SDK כדי לבנות את ה-probe, הצעד הכי מסובך |
| התקנה שקטה בלי לגעת בממשק הטלפון / מחקר של פרוטוקול החנות | קוראים את ארכיון ה-reverse engineering ב-`docs/findings/` | קריאה בלבד |

למנגנון המלא של שולחן העבודה והאייקונים ראו [DEV_GUIDE §5](docs/DEV_GUIDE.md); אינדקס ארכיון הפרוטוקול נמצא ב-§8.

## מבנה התיקיות

```
tools/ows.py          one-stop script (doctor / setup / build / push / install)
docs/DEV_GUIDE.md     ★ full development guide (platform architecture, manifest, build and install, icon mechanism, troubleshooting)
docs/SOURCES.md       provenance / attribution / verification dates of external resources (read before citing)
docs/findings/        store protocol reverse-engineering archive (advanced, not needed day to day)
apps/qrwatch/         QR code app: source + prebuilt bundle.pkg
apps/library-qr/      ecosystem example: library reader card dynamic code (generated offline)
apps/purrlaunch-ows/  OWS adaptation delta for PurrLaunch (advanced: desktop entry)
devices/              gx device configs (466×466 round screen)
tools/guiyuan-assistant/  Guiyuan Assistant APK mirror + notes (release page, version, checksum)
tools/ftprobe/        protocol probe (advanced: desktop icon registration)
tools/pkg_tool.py     .pkg container format reader/writer
```

## מסקנות מפתח (המלכודות בקיצור)

1. **`icon` ב-manifest הוא חובה** - בלעדיו השעון האמיתי מחזיר 5005, בעוד שהאמולטור מריץ בכל זאת
2. **תפריט שולחן העבודה הוא hardcoded** - כדי שאפליקציית צד שלישי תופיע בשולחן העבודה, היא יכולה רק לתפוס חריץ קיים (PurrLaunch מחופש ל-Wooden Fish)
3. **אייקוני שולחן העבודה מונעי נתונים** - החנות שולחת `icon_<package name>` נפרד בזמן ההתקנה; ב-sideloading צריך להוסיף את הצעד הזה
4. **ערוץ פרוטוקול החנות לא יכול להתקין חבילות שנבנו בעצמכם** - גם אם שכבת ההעברה עובדת במלואה זה לא עוזר; ה-sideloading עובר בערוץ ה-debug של ה-assistant
5. **ממשק "check install" בעל סמנטיקה לא אמינה** - סומכים רק על קודי ההחזרה של install / launch

## שאלות נפוצות

- **מקבלים 5005 invalid package?** בתשעה מתוך עשרה מקרים ב-manifest חסר `icon`.
- **מקבלים 5001 The package was not found?** החבילה לא הותקנה או ששם החבילה כתוב לא נכון (תוצאת "check install" של true לא נחשבת).
- **שולחן העבודה מציג גלגל שיניים?** רישום האייקון חסר; זה פריט מתקדם ואינו משפיע על ההרצה.
- **`adb push` הצליח אבל החבילה לא מופיעה ב-"Download" של ה-assistant?** צעד ה-media scan דולג - `ows.py install` עושה אותו אוטומטית.
- **הטלפון לא מתחבר לשעון?** השעון מתנתק בשינה עמוקה; מעירים אותו פיזית, פותחים מחדש את ה-assistant ולוחצים "连接" (Connect).
- **ה-assistant מודיע על גרסה חדשה 1.3, לשדרג?** המאגר הזה אומת מקצה לקצה על **1.2**; בגרסה 1.3 כתוב רק "supports OHealth" והיא לא נבדקה ב-regression, ולכן ההתנהגות אחרי השדרוג לא ידועה.

## תודות והפניות

- [purrrock/PurrLaunch](https://github.com/purrrock/PurrLaunch) (MIT) - היוצר המקורי של ה-launcher התופס-חריץ; `apps/purrlaunch-ows/` הוא ה-delta של ההתאמה שלו ל-OWS
- [pgyer.com/glyphix-assistant](https://www.pgyer.com/glyphix-assistant) - **דף ההפצה המקורי** של Guiyuan Assistant (מופץ דרך Pgyer, שם חבילה `com.glyphix.assistant`; הדף לא מציין יוצר)
- [bandbbs.cn/threads/29508](https://www.bandbbs.cn/threads/29508/) - מדריך sideloading ל-OWS (מחבר המדריך libiao0418)
  > מחבר הפוסט הזה הוא **מחבר המדריך**, לא מחבר Guiyuan Assistant (הוא רק משתמש בכלי). לדף ההפצה של Guiyuan Assistant ראו את הפריט הקודם.
- [glyphix-os/web-docs](https://github.com/glyphix-os/web-docs) - התיעוד הרשמי של Glyphix

> המקור ותאריך האימות של כל משאב חיצוני, וכן "אילו שדות ניתן לאמת ואילו לא ניתן למצוא", מתועדים ב-[docs/SOURCES.md](docs/SOURCES.md).

## רישיון ומשאבי צד שלישי

- **החלקים המקוריים** של המאגר (תיעוד, `tools/ows.py`, `apps/qrwatch`, `apps/library-qr`, `tools/pkg_tool.py`, `tools/ftprobe`, `devices/`):
  [MIT](LICENSE), Copyright (c) 2026 chengchengking.
- `apps/purrlaunch-ows/`: ה-upstream [purrrock/PurrLaunch](https://github.com/purrrock/PurrLaunch) הוא MIT; התיקייה הזו היא ה-delta של ההתאמה שלו, ונעשה בה שימוש גם כן לפי MIT.
- ה-APK ב-`tools/guiyuan-assistant/`: **זכויות היוצרים שייכות ליוצר הכלי** ורישיון ה-MIT של המאגר אינו חל עליו. המאגר רק משקף (mirror) אותו לצורך שחזור,
  דף ההפצה המקורי הוא [pgyer.com/glyphix-assistant](https://www.pgyer.com/glyphix-assistant); אם היוצר יבקש הסרה, פנו למתחזק המאגר והוא יוסר.
- סימנים מסחריים ורכיבי מערכת של OPPO / Glyphix שייכים לבעליהם בהתאמה; המאגר הזה אינו כולל קוד קנייני שלהם.

## הצהרת אחריות

לשימוש מחקרי ולצורכי interoperability במכשירים שבבעלותכם בלבד. הערות ה-reverse engineering מתארות התנהגות שנצפתה במכשיר אישי ואינן כוללות קוד קנייני;
ה-APK של Guiyuan Assistant מוגן בזכויות יוצרים של יוצרו ומשוקף במאגר הזה רק לצורך שחזור; כל סיכון הנובע משימוש בתוכן המאגר הוא על אחריות המשתמש.
