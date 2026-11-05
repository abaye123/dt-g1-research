> מקור: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). זהו תרגום לא רשמי.

# מדריך מלא לפיתוח אפליקציות Glyphix ול-sideloading
### פלטפורמת יעד: OPPO Watch S (OWW262) · Glyphix OS · מסך עגול 466×466
> 2026-10-11 · מבוסס על מסקנות שנמדדו בחלונות 10~20 · נלווה: `docs/findings/` (ארכיון reverse engineering של הפרוטוקול), `docs/SOURCES.md` (מקור ויחוס של משאבים חיצוניים)
> כל מסקנה המסומנת ב-✅ אומתה על מכשיר אמיתי; ⚠️ מסמן מלכודת שנפלנו בה.

---

## 0. רוצים רק להתקין אפליקציה על השעון

```bash
npm install -g glyphix-cli             # once
python tools/ows.py install qrwatch    # every time: build + push to the phone
```

בסיום פשוט לוחצים "安装应用" (Install app) בטלפון. אם נתקעתם, קודם הריצו `python tools/ows.py doctor` (בודק את הסביבה פריט אחר פריט ונותן תיקון לכל מה שחסר).

> **אם אתם ממהרים, קראו רק §0 + §6 (פתרון תקלות).**
> §1~§4 הם העקרונות והתהליך הידני; **§5.3 (אייקון שולחן העבודה) ו-§8 (reverse engineering של פרוטוקול החנות) הם מתקדמים, האפליקציה עובדת מצוין גם בלעדיהם**.

---

## 1. ארכיטקטורת הפלטפורמה: מי עושה מה

```
┌─────────────┐  adb drive/push files  ┌──────────────┐                  ┌──────────────┐
│ PC (this repo) │ ──────────────→ │ Phone PJD110   │ ── BT/PTC protocol──→ │ Watch OWW262  │
│ gx toolchain    │                 │ com.heytap.  │   (official channel)       │ Glyphix      │
│ Python tools    │                 │ health       │                  │ nucleus 0.7  │
└─────────────┘                 │ com.glyphix. │── debug channel (whitelist)─→│ runtime 0.7  │
                                │ assistant    │   ★ sideloading uses this    └──────────────┘
                                │ (Guiyuan Assistant)    │
                                └──────────────┘
```

- **Glyphix OS**: מערכת אפליקציות JS קלה של OPPO (בסגנון quick-app: תבניות UX + ממשקי @system.*). התיעוד הפתוח נמצא ב-github.com/glyphix-os/web-docs (**בדקו אותו לפני שכותבים קוד**; מומלץ לשכפל עותק מקומי).
- **יש שני ערוצי התקנה**:
  - **ערוץ debug** (Guiyuan Assistant "Install app") → ✅ הדרך הסטנדרטית במדריך הזה. לא מאמת חתימות ולא מבצע אימות חזק של תוכן החבילה (דורש רק manifest תקין + כל שדות החובה קיימים).
  - **ערוץ החנות** (אפליקציית Health / דחיפה ישירה בפרוטוקול PTC) → בחלונות R10~R18 שכבת ההעברה נפרצה לגמרי בהנדסה לאחור (העברת קבצים אומתה ברמת MD5 יותר מ-8 פעמים), אבל בצד השעון אימות ההתקנה אף פעם לא מאשר חבילות שנבנו בעצמנו (cid=5 הוא "staging" ולא InstallDone). **שוקלים אותו רק כשאין Guiyuan Assistant; הארכיון בסעיף 8.**

---

## 2. רשימת סביבה והערות

### 2.1 מחשב (PC)
| פריט | מיקום/ערך |
|---|---|
| gx toolchain | `npm i -g glyphix-cli` (ה-latest ב-npm הוא 0.8.0-rc, גרסת ה-`gx` שמותקנת היא **v0.11.0**); את המיקום בפועל מוצאים עם `where gx` |
| הגדרת מכשיר | `%APPDATA%\glyphix\devices\oppo-rtos-watch.yml` - פשוט מעתיקים לשם את `devices/oppo-rtos-watch.yml` של המאגר (vendorID/productID קבועים ל-0x0000/0x0000, אל תחזירו לערכי ה-probe 0x1234/0x5678) |
| כלי פורמט החבילה | `tools/pkg_tool.py` של המאגר (info/list/manifest/extract/pack/setdevice; לפורמט הקונטיינר CR ראו PKG_FORMAT.md) |
| תיעוד רשמי | אונליין ב-github.com/glyphix-os/web-docs (אפשר לשכפל לכל תיקייה; api/ components/ framework/ tutorials/) |
| Python | 3.x + Pillow (לייצור אייקונים) |

**התקנת הגדרת המכשיר (חובה בפעם הראשונה)**: את `devices/oppo-rtos-watch.yml` של המאגר צריך להעתיק לתיקיית הנתונים של gx:
```bash
gx list path        # shows the data= line, i.e. <data-dir>
cp devices/oppo-rtos-watch.yml <data-dir>/devices/
gx list device      # oppo-rtos-watch appearing means success
```

⚠️ Git Bash ממיר את `/sdcard/...` לנתיב מקומי: **לפני כל פעולת קבצים של adb מריצים `export MSYS_NO_PATHCONV=1`**.

### 2.2 טלפון (מכשיר adb <adb-serial>, PJD110)
| חבילה | תפקיד |
|---|---|
| com.glyphix.assistant | **Guiyuan Assistant v1.2**: מתקין ה-sideload (ב-upstream כבר יצאה v1.3, לא אומתה; דף ההפצה ב-§10). ששה כפתורים בממשק: Connect / Device info / Check install / Install app / Launch app / Device log |
| com.heytap.health | OPPO Health: מארח ה-bridge + חנות האפליקציות של השעון |

### 2.3 שעון (OWW262)
- vendorId=17170433(0x01060001), nucleus 0.7.0-44 / runtime 0.7.0-68, מסך עגול 466×466
- **תנאי חיבור**: עונדים את השעון / מרימים יד כדי לשמור אותו פעיל; שינה עמוקה מנתקת אותו והמחשב לא יכול להעיר אותו
- **יומן RPC** (Guiyuan Assistant "Device log") = זרם היומן בזמן אמת מצד השעון, המקום הראשון לחפש בו בפתרון תקלות (ראו סעיף 6)

---

## 3. מוסכמות פרויקט אפליקציה

### 3.1 מבנה תיקיות
```
<project>/
├─ src/
│  ├─ app.js               # app lifecycle
│  ├─ manifest.json        # app manifest (icon is required! see 3.2)
│  ├─ assets/icon.png      # icon (192×192 PNG measured to pass)
│  └─ main/
│     ├─ index.ux          # page = <template> + <style> + <script>
│     └─ <data>.js         # data module used by the page (ES import)
```
פרויקטי ייחוס: `apps/qrwatch/src/` (אפליקציית קוד QR, הפרויקט המינימלי העובד) ו-`apps/purrlaunch-ows/` (ה-delta של ההתאמה של PurrLaunch ל-OWS).

### 3.2 כל שדות manifest.json (★=חובה)
```json
{
  "package":    "com.example.app",
  "name":       "应用名",
  "icon":       "/assets/icon.png",
  "versionName":"1.0.0",
  "versionCode": 1,
  "features":   [],
  "router": {
    "entry": "main",
    "pages": { "main": { "component": "index" } }
  },
  "config":  { "designWidth": 466 },
  "permissions": [ { "name": "watch.permission.XXX" } ],
  "display": {}, "dial": {}, "widgets": []
}
```
- `package` ★ ייחודי גלובלית, מומלץ com.xxx.yyy; להימנע מ-`-` `_` `.`
- `name` ★ לכל היותר 6 תווים סיניים, משמש להצגה בשולחן העבודה
- `icon` ★ **חובה! אם חסר → 5005 invalid package בשעון (המלכודת הגדולה ביותר בפרויקט הזה, ראו סעיף 5)**
- `versionCode` ★ מספר שלם, +1 בכל שחרור (הבסיס להחלטות שדרוג)
- `router` ★ ניתוב דפים; `config.designWidth` ב-OWS הוא 466
- ⚠️ התבנית הרשמית רצה באמולטור גם בלי icon, אבל **בהתקנה על מכשיר אמיתי חייבים להוסיף**

### 3.3 סקירה מהירה של קובץ הדף index.ux
- הנחיות תבנית: `for="{{(idx, item) in items}}"`, `if="{{cond}}"`, אירוע `on:click="fn"`, קישור תכונה `:value="{{expr}}"`, אינטרפולציה `{{expr}}`
- עיצוב: תת-קבוצה של CSS; מומלץ להגדיר במפורש `width:466px; height:466px` על שורש הדף
- רשימת רכיבים (web-docs components/): div/p/stack/scroll/button/image/canvas/**qrcode**/barcode/input/slider/progress/marquee/picker… (qrcode תומך עד QR v12 ≈ 300 בייט של payload)
- **מחזור החיים של דף** (הסדר שנמדד ביומן RPC של מכשיר אמיתי): `onInit → onReady → onShow → (onHide → onShow…) → onDestroy`
- **מחזור החיים של אפליקציה** (app.js): `onCreate/onShow/onHide/onDestroy/onError/onPageNotFound`
- טיימרים: `setInterval/clearInterval` גלובליים (זכרו לנקות אותם ב-onHide בדף)

### 3.4 ממשקי API נפוצים (בסגנון `import pkg from '@system.package'`)
| מודול | שימוש שאומת בפרויקט הזה |
|---|---|
| @system.package | `list('app')→array of package names`, `getInfo(pkg)→{name,versionName,icon…}`, `install({src})`, `remove` |
| @system.launch | `launch(pkg)→Promise<bool>` הפעלה והעלאה לחזית, `getRunning()`, `exit()` |
| @system.file | readText/writeText/list/copy/mkdir/stat… (לשימוש בהמשך בדפדפן קבצים / בבדיקת מטמון אייקונים) |
| @system.devtools | `command(cmd, fn)` רושם פקודת טרמינל מסוג `dev` |
| אחרים | ble/geolocation/media/notification/schedule/battery/cipher/fetch/i18n… ראו web-docs api/ |

---

## 4. SOP לבנייה והתקנה (✅ התהליך כולו ניתן להעתקה)
> סקריפט בשורה אחת: `python tools/ows.py install <app>` (= בנייה + push + הפעלת media scan). להלן התהליך הידני.

### 4.1 בנייה
```bash
cd <project>
../.toolchain/node_modules/@glyphix/cli-win32-x64/bin/gx.exe build -d oppo-rtos-watch -f
```
- `-d` מכשיר יעד; **`-f` בנייה מלאה** (⚠️ בנייה אינקרמנטלית לא "צורבת" מחדש את מזהה המכשיר ב-manifest - אחרי שינוי הגדרת המכשיר חובה להשתמש ב-`-f`)
- תוצרים: `.glyphix-work/dist/oppo-rtos-watch/<package>/` → **bundle.pkg (זו חבילת ההתקנה)** + icon.png + manifest.json (שלישיית ההגשה לחנות; ל-sideloading מספיק bundle.pkg)
- המרת תמונות תלויה ב-pngquant (נדרש בהגדרות generic-*; נמדד שלא נדרש בהגדרת oppo-rtos-watch)

### 4.2 התקנה (Guiyuan Assistant)
```bash
export MSYS_NO_PATHCONV=1
adb push <project>/.glyphix-work/dist/oppo-rtos-watch/<pkg>/bundle.pkg /sdcard/Download/xxx.rpk
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/xxx.rpk
```
אחר כך: Guiyuan Assistant → Install app → לשונית Files → Download → בוחרים את החבילה → ביומן מופיע `安装应用 成功 {"code":200}`.
- כל שם קובץ מתאים (התוכן קובע הכול); אחרי ההצלחה אפשר מיד ללחוץ "Launch app" (מזינים שם חבילה, 200 = הופעלה)
- **שדרוג**: פשוט מתקינים מחדש, ה-versionCode חייב להיות גדול מזה של הגרסה המותקנת
- **דריסת אפליקציית חנות**: ✅ נמדד שעובד (purrlaunch-lite דרס את גרסת החנות של Wooden Fish, ערוץ ה-debug לא חוסם על בסיס חתימות)

### 4.3 קריטריוני קבלה
- קריטריון התקנה = **קוד ההחזרה של install / launch** (לממשק "check install" סמנטיקה לא אמינה, אל תשתמשו בו)
- קריטריון הרצה = ביומן RPC מופיע `app.life: call onInit/onReady in pkg://<package name>/main/index.uo` + `eventLoop refresh`

---

## 5. אייקונים ומנגנון שולחן העבודה (✅ נפתר: שיטת הרישום `icon_<package name>`)

### 5.1 משאבי אייקון
- **com.rtos.qrwatch (אפליקציית קוד QR)**: רקע לבן + דוגמת קוד QR שחורה, PNG בגודל 192×192 (843B)
- **purrlaunch / PurrLaunch (launcher, שם חבילה com.xfaith.woodenfish)**: דוגמת כפת חתול (הגרסה הרשמית) / רשת של ארבעה צבעים (גרסת lite)
- כל האייקונים נמצאים בתוך החבילה (`assets/icon.png` + שדה `icon` ב-manifest) - נראים בזמן ריצה; **התצוגה בשולחן העבודה עוברת במנגנון רישום נפרד (ראו 5.3)**

### 5.2 שורש תופעת גלגל השיניים (שרשרת סיבתית מלאה, הוכחה)
1. שולחן העבודה של OWS מציג גלגל שיניים (אייקון בסגנון הגדרות Android) לאפליקציות שהותקנו ב-sideload = ברישום האייקונים חסרה רשומת אייקון לחבילה הזו → רינדור ברירת מחדל
2. רישום האייקונים **מונע נתונים**: כשהחנות מתקינה אפליקציה, אפליקציית Health **מעבירה קובץ אייקון בנפרד** מחוץ לקובץ החבילה ורושמת אותו
   (יומן חנות ממכשיר אמיתי 08:26: ~120ms אחרי שהעברת `pkg_com.xfaith.woodenfish` הסתיימה, נשלח `icon_com.xfaith.woodenfish`, קובץ PNG בגודל 11294B)
3. ערוץ ה-debug של Guiyuan Assistant שולח רק bundle.pkg → אין אייקון ברישום → גלגל שיניים
4. לא האייקון שבתוך החבילה ולא האייקון המוצהר ב-manifest **יכולים** לגרום לשולחן העבודה להציג אותו - שולחן העבודה מזהה רק את הרישום
5. שולחן העבודה של מחבר PurrLaunch (DT NO.1 G1) הוא "תפריט hardcoded + אייקונים אפויים ב-OS", לא איזומורפי ל-OWS; את המנגנון של OWS אפשר לתקן מצד החבילה / מצד הקבצים

### 5.3 ★ SOP סטנדרטי: רישום/החלפת אייקון שולחן עבודה לאפליקציה שהותקנה ב-sideload (✅ אומת, **פריט מתקדם**)
> אי ביצוע לא משפיע על ההתקנה או ההרצה; שולחן העבודה פשוט יציג גלגל שיניים. נדרש לבנות probe עם Android SDK, הצעד המסובך ביותר בכל המאגר.
> רשומות אימות: R21b (com.rtos.qrwatch, המשתמש אישר בעיניו שאייקון שולחן העבודה הפך לדוגמת קוד QR) + R21c (שני אייקונים נרשמו באותה אצווה, ה-wire הושלם)

**תנאים מקדימים**
- ה-probe `tools/ftprobe` (נבנה ב-R21c ואילך) מותקן בטלפון; השעון התחבר מחדש (אונליין)
- הטלפון במצב **מסך דלוק + פתוח** (Android 14 הורג בכוח את ה-Activity של ה-probe כשהטלפון נעול / לא גלוי: `did not call finish`)

**צעדים**
1. מניחים את ה-PNG של האייקון ב-`tools/ftprobe/assets/`, עם שם עבודה = `icon_<target package name>` (בלי סיומת; 192×192 843B נמדד שעובד)
2. ב-`src/com/rtos/ftprobe/MainService.java` → בסוף `fireOp4AndUnlock()`, מוסיפים את הזוג
   `{asset name, "icon_<target package name>"}` למערך `icons[][]`
3. `python build_probe.py` → `adb install -r build/FtProbe18.apk`
4. `adb shell settings put secure authentication_state 1` (נדרש כדי שה-probe יתחזה לסוכן Health ויעבור את אימות ה-framework; **בסיום חובה להחזיר ל-0**)
5. מסך דלוק ופתוח → `adb shell am start -n com.rtos.ftprobe/.MainActivity` → keepalive: חוזרים על WAKEUP+am start כל 15 שניות,
   בסך הכול כ-3 דקות (מונע ColorOS virtualFreeze; ה-probe משלים אוטומטית את כל השרשרת cid=10 → pkg×3 → icon_<package name> → cid=3)
6. אימות ב-wire: `adb logcat` תופס `[sfcmd]FT_SETUP_REQ sent,...fileName:icon_<package name>` +
   `handleTransferComplete: Completed :icon_<package name>`
7. **מפעילים מחדש את השעון** → אייקון שולחן העבודה נכנס לתוקף ✅

**העיקרון**: רישום האייקונים בצד השעון מנתב לפי שם קובץ - `icon_<package name>` + `FileInfo=appstore_uri_icon` שנשלחים בערוץ
`wear:watchappservice_file:1.0` (sid=272) נרשמים עם ההגעה; אותו ערוץ כמו קובץ החבילה (`pkg_<package name>`+`appstore_uri_package`)
אבל מפתח ניתוב אחר. באפליקציה **שכבר מותקנת** אפשר פשוט לשלוח בדיעבד, בלי צורך להתקין מחדש את האפליקציה; נשמר גם אחרי הפעלה מחדש.

### 5.4 גבולות ושאריות
- השיטה תלויה ב-probe (עקיפת אימות); ההתקנה של Guiyuan Assistant v1.2 לא כוללת רישום אייקון (v1.3 לא ידוע - אם v1.3 מצרפת אוטומטית icon.png זה יהיה פשוט יותר)
- תוכן האייקון יכול להיות כל PNG (192×192/843B עד 432×432/1.7KB כולם עובדים); התמונה המקורית של החנות היא 11294B (לא רגישה לגודל)
- רשומות תפריט שולחן העבודה עצמן עדיין hardcoded (אפליקציית צד שלישי ש"צריכה להופיע בשולחן העבודה" עדיין צריכה לתפוס את חריץ Wooden Fish - נפתר על ידי PurrLaunch);
  רישום אייקון פותר את השאלה "איזו תמונה מוצגת"

---

## 6. דיבוג ופתרון תקלות

### 6.1 קריאת שורות היומן של Guiyuan Assistant
| יומן | משמעות |
|---|---|
| `连接服务: com.heytap.health → 连接成功` | ה-bridge מוכן |
| `安装应用 进度 {cur_size,total_size}` | החבילה בהעברה |
| `安装应用 成功 {"code":200}` | הותקן |
| `安装应用 失败 {"code":5005,"msg":"invalid package"}` | manifest לא תקין (בתשעה מתוך עשרה מקרים חסר icon) או קונטיינר שבור |
| `启动应用 成功/失败 {"code":5001,"msg":"The package was not found"}` | שם החבילה לא קיים (לא הותקנה / שגיאת כתיב) |
| `切换 rpc 日志 成功` | זרם יומן השעון הופעל/כובה |

### 6.2 שורות מפתח ביומן ה-RPC בצד השעון
| שורה | משמעות |
|---|---|
| `mas.ffi: exec ffi fun app_launch` | פקודת ההפעלה הגיעה לשעון |
| `app.life: call onShow in pkg://<package name>` | onShow ברמת האפליקציה |
| `app.life: call onInit/onReady in pkg://<package name>/main/index.uo` | אתחול דף / מוכנות |
| `lvgl: exit application <package name> success` | האפליקציה יצאה (דריסה בשדרוג / exit) |
| `lvgl: eventLoop refresh N … stop it` | לולאת הרינדור תקינה (הרענון נעצר אחרי 5 פריימים כשהמסך סטטי) |
| `gx_on_screen_on/off` | מסך השעון דלוק/כבוי (כשמפעילים כשהמסך כבוי, לא לראות כלום זה נורמלי) |
| `query network status / mas network … online` | מצב הרשת של השעון |

### 6.3 טבלת קודי שגיאה מהירה
| קוד | מקור | משמעות |
|---|---|---|
| 200 | פעולות ה-assistant | הצלחה |
| 5001 | Launch app | החבילה לא קיימת |
| 5005 | Install app | חבילה לא תקינה (חסר icon / קונטיינר שבור) |
| 10002 | שרשרת הפרוטוקול R17 | ה-urn ללא מספר גרסה → שגיאת פענוח profileId |
| 10110 | שרשרת הפרוטוקול R17 | מאגר הפריימים של sendMessage לא מספיק (ייחודי לשרשרת הפרוטוקול) |

### 6.4 רשימה מהירה של עשר המלכודות
icon חובה / ערוץ החנות לא מתקין חבילות שנבנו בעצמנו / אייקון גלגל שיניים בשולחן העבודה / שינה עמוקה של השעון מנתקת / ColorOS מקפיא את ה-probe / באמולטור חסר launcher / ה-CDN דורש חתימות / חלונות קופצים של אוטומציית UI מפריעים + סיבוב מסך / MSYS_NO_PATHCONV / מאגר logcat קטן.

ארבע הראשונות מטופלות בהתאמה ב-§3.2 (icon), §1 (ערוץ), §5 (אייקון), §2.3 (ניתוק בשינה עמוקה); השאר הן מלכודות סביבה מתקופת ה-reverse engineering שלא תיתקלו בהן בפיתוח יומיומי.

---

## 7. Launcher: ההתאמה של PurrLaunch ל-OWS (כבר רץ על השעון)
- מיקום במאגר: `apps/purrlaunch-ows/` (ה-delta המינימלי של התאמת ה-upstream purrrock/PurrLaunch v1.2.2, MIT, פרטים ב-OWS-ADAPTATION.md באותה תיקייה)
- שם חבילה `com.xfaith.woodenfish` (תופס את Wooden Fish המקורי)
- הערה: קודם היה גם purrlaunch-lite שנבנה בעצמנו (versionCode 8), שלאחר מכן נדרס על ידי PurrLaunch הרשמי, **ולא פורסם עם המאגר**
- פונקציונליות: רשימה דינמית של `pkg.list('app')` (חבילות מערכת בסוף, הוא עצמו מוסתר) → לחיצה מפעילה `launch()`
- אומת: דריסת גרסת החנות של Wooden Fish ✅; מחזור חיי הדף/הרינדור עובדים במלואם ✅; אפליקציות חדשות שהותקנו מופיעות ברשימה אוטומטית
- כדי לחזור ל-Wooden Fish: מתקינים מחדש מחנות האפליקציות של השעון (זה בתורו דורס את ה-launcher); כדי לשנות את ה-launcher: עורכים את src ומתקינים מחדש לפי סעיף 4

---

## 8. אינדקס ארכיון "המעמקים" (reverse engineering של פרוטוקול החנות - נדרש רק כדי "לעקוף את Guiyuan Assistant")
| קובץ | תוכן |
|---|---|
| docs/findings/findings_R14_transfer_success.md | העברת קבצים מקצה לקצה + חמשת התיקונים שחייבים להיות נכונים בו זמנית |
| docs/findings/findings_R15_cid10_protocol.md | שחזור פרוטוקול ה-protobuf של בדיקת ההתקנה המקדימה cid=10 |
| docs/findings/findings_R16_cid10_live.md | cid=10 באש חיה |
| docs/findings/findings_R17_wireformat.md | חוזה פריים MEX (header של 15B, offset=15, המסלול הראשי הבר-קיימא היחיד) |
| docs/findings/findings_R18_final.md | שחזור 1:1 של שרשרת ההתקנה המלאה + טבלה מוסמכת של מספרי שדות MsgBody |
| docs/findings/findings_R19_sideload_success.md | שורש הבעיה של 5005 + כל התהליך המוצלח של ערוץ ה-debug |
| docs/findings/findings_R20_launcher.md | launcher שנבנה בעצמנו + דריסה בשדרוג של אפליקציית חנות |
| tools/ftprobe/ (versionCode 18) | probe לפרוטוקול: cid=10 + דחיפת קובץ Op4 + רשימת cid=3, ניתן להרצה חוזרת בלחיצה אחת |
| (לא פורסם עם המאגר) auto_verify.sh | לולאת אימות לא מאוישת (נעצרה, נשמרה לעיון) |

מתי נדרש: כשרוצים להתקין בשקט / להפיץ המוני אפליקציות **בלי שום אינטראקציה עם ממשק הטלפון**, או לחקור את פרוטוקול ההורדה של החנות. פיתוח יומיומי **לא צריך** את זה.

---

## 9. מיפוי תיקיות: מאגר ↔ ספריית העבודה המקורית

המאגר הזה הוא **תת-קבוצה ציבורית** של ספריית העבודה המקורית: כלים, קוד ותיעוד הניתנים לשחזור נמצאים כולם במאגר;
בחלקים שכוללים תוצרי decompile של היצרן נשמרות רק המסקנות והקבצים הגולמיים לא מפורסמים (ראו הצהרת האחריות בסוף).

| נתיב במאגר | תוכן | המקביל בספריית העבודה המקורית |
|---|---|---|
| `README.md` | התחלה מהירה בשלושה צעדים (התהליך הידני מקופל ב-details) | - |
| `docs/DEV_GUIDE.md` | המסמך הזה | `DEV_GUIDE.md` |
| `docs/PKG_FORMAT.md` | מפרט פורמט הקונטיינר CR | `pkg_tools/PKG_FORMAT.md` |
| `docs/findings/findings_R14~R21*.md` | דוחות קרב לפי חלון (reverse engineering של פרוטוקול החנות) | `work/findings_R1x*.md` |
| `docs/findings/findings_master.md` | סיכום מלא | סיכום ב-`work/` |
| `docs/SOURCES.md` | מקור / יחוס / תאריכי אימות של משאבים חיצוניים | חדש |
| `apps/qrwatch/` | אפליקציית קוד QR (v2: קרוסלה אוטומטית של 10 שניות) | `com.rtos.qrwatch/` |
| `apps/library-qr/` | קוד דינמי של כרטיס קורא בספרייה (דוגמה למערכת האקולוגית) | - |
| `apps/purrlaunch-ows/` | delta של ההתאמה של PurrLaunch ל-OWS | `PurrLaunch/` |
| `tools/guiyuan-assistant/` | מראה של APK של Guiyuan Assistant + הערות | `work/glyphix_assistant/` |
| `tools/ftprobe/` | probe לפרוטוקול (כולל רישום אייקון שולחן עבודה) | `work/ftprobe*/` |
| `tools/ows.py` | סקריפט one-stop (doctor/setup/build/push/install) | חדש |
| `tools/pkg_tool.py` | קורא/כותב פורמט חבילה | `pkg_tools/pkg_tool.py` |
| `devices/oppo-rtos-watch.yml` | הגדרת מכשיר ל-gx | `%APPDATA%\glyphix\devices\` |

**מקומי בלבד, לא פורסם עם המאגר**: `HANDOFF.md` (פתק מסירה), `purrlaunch-lite/` (הוחלף על ידי PurrLaunch הרשמי),
`com.rtos.pkg` (חבילה ישנה בפורמט חנות, בלי icon היא נותנת 5005, אל תשתמשו בה שוב להתקנה), `.toolchain/` (ספריית ההתקנה של gx),
`work/oafsrc/` ו-`work/routesrc/` (שברי decompile של אפליקציית Health), `work/store_catalog.json` (מטא-דאטה של החנות), `work/auto_verify.sh`.
תוצרי decompile לא מפורסמים לפי הצהרת האחריות; נשמרות רק המסקנות ההתנהגותיות ב-`docs/findings/`.

> דוחות הקרב תחת `docs/findings/` הם יומני העבודה המקוריים של אותה תקופה; ה-`G:/oppo/...` וה-`work/...` שמופיעים בטקסט שלהם הם **נתיבים מקומיים של אותה תקופה**,
> המיפוי בטבלה שלמעלה; כדי לשמור על הרשומה המקורית הם לא תוקנו, ולכן בזמן הקריאה ממירים אותם לפי הטבלה.

## 10. קישורי הפניה

- **התיעוד הרשמי של Glyphix**: [github.com/glyphix-os/web-docs](https://github.com/glyphix-os/web-docs) (בדקו אותו לפני שכותבים קוד; אפשר לשכפל מקומית לכל תיקייה)
- **מדריך Mitan**: [bandbbs.cn/threads/29508](https://www.bandbbs.cn/threads/29508/) - המחבר libiao0418, **רק מחבר המדריך**.
  ב-2026-10-10 נוסף בפוסט קישור לכונן ענן עם הכלים ששימשו במדריך (הסיסמה בפוסט המקורי); אם צריך קבצים מצורפים כמו ה-rpk של Purrlaunch, משיגים אותם לפי ההנחיות בפוסט המקורי.
- **דף ההפצה המקורי של Guiyuan Assistant**: [pgyer.com/glyphix-assistant](https://www.pgyer.com/glyphix-assistant) - מופץ דרך Pgyer, שם חבילה `com.glyphix.assistant`;
  הדף **לא מציין יוצר**, אל תמלאו שם (רשומת האימות ב-`docs/SOURCES.md`).
- **PurrLaunch**: ה-upstream [github.com/purrrock/PurrLaunch](https://github.com/purrrock/PurrLaunch) (MIT, v1.2.2), ללא קשר יחוס למחבר המדריך שלמעלה.
- **glyphix-cli**: חבילת npm, ה-latest כרגע = 0.8.0-rc, ה-`gx` שמותקן הוא v0.11.0.

> המקור המלא של משאבים חיצוניים, תאריכי אימות ו"אילו שדות ניתן לאמת / אילו לא ניתן למצוא" מתועדים כולם ב-`docs/SOURCES.md`.
