> מקור: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). זהו תרגום לא רשמי.

# findings_R19 - ✅✅✅ הצלחת sideload: com.rtos.qrwatch הותקנה ורצה על ה-OWW262 (2026-10-11 10:15-10:24)

> חלון 19. שרשרת ההעברה שנבנתה ב-18 החלונות הקודמים + תיקון הפורמט של החלון הזה = מסירה מלאה.

## התוצאה הסופית (מוכחת ביומן ה-assistant)
```
10:15:51.842  安装应用 成功  {"code":200,"msg":"success"}   ← v1 (3136B, with icon)
10:16:45.985  启动应用 成功                                   ← com.rtos.qrwatch
10:23:24.491  安装应用 成功  (total_size:3488)                ← v2 (10-second auto carousel)
10:24:02.366  启动应用 成功
```
המשתמש אישר בעיניו: **מסך קוד ה-QR הופיע על השעון** (הכניסה בשולחן העבודה מציגה את חריץ האייקון Wooden Fish, ראו הבעיות הידועות בהמשך).
אישוש מיומן ה-RPC בצד השעון: `mas.ffi: exec ffi fun app_launch` + `lvgl: eventLoop refresh startup` (לולאת אירועי ה-UI התחילה, בלי שום שגיאה).

## שורש הבעיה של 5005 "invalid package" (הממצא המרכזי של החלון הזה)
- זו **לא** בעיית ערוץ, לא בעיית חתימה, לא בעיית שם קובץ (שינוי הסיומת ל-.rpk לא עזר)
- **שורש הבעיה = בחבילה חסר אייקון אפליקציה**:
  - התיעוד הרשמי (github.com/glyphix-os/web-docs -> framework/application/manifest.md)
    חתימת הטיפוס של Manifest, `icon: string`, היא **חובה** ("נתיב אייקון האפליקציה, למשל /assets/icon.png")
  - חבילה ישנה: אין קובץ icon, אין שדה icon ב-manifest -> ה-runtime בצד השעון (nucleus) מדווח invalid package or manifest
  - התיקון: src/assets/icon.png + manifest `"icon": "/assets/icon.png"` + בנייה מחדש של החבילה עם gx build -> עבר בניסיון הראשון
- תיקון משני: בהגדרת המכשיר המותאמת oppo-rtos-watch.yml הוחזרו vendorID/productID מ-0x1234/0x5678 ל-0x0000/0x0000 (מוסכמת משפחת generic, כדי להימנע מסיכון באימות מכשיר)

## נוהל ה-sideloading הנכון (חלונות עתידיים יכולים להעתיק אותו כמו שהוא)
1. ה-src/manifest.json של הפרויקט חייב לכלול: package/name/**icon**/versionName/versionCode/router
2. `gx build -d oppo-rtos-watch` (עם -f לבנייה מלאה; בנייה אינקרמנטלית לא "צורבת" מחדש את מזהה המכשיר)
3. התוצר `.glyphix-work/dist/oppo-rtos-watch/<pkg>/bundle.pkg` ניתן להתקנה כמו שהוא
   (תיעוד רשמי: שלישיית ה-dist היא bundle.pkg+icon.png+manifest.json, "מתקינים על המכשיר דרך אפליקציית ה-debug בטלפון")
4. Guiyuan Assistant -> Install app -> בוחרים את קובץ החבילה -> הצלחה; Launch app -> com.rtos.qrwatch
5. שדרוג: פשוט מתקינים מחדש (סמנטיקת pkg.install, אפליקציה רצה יוצאת קודם ואז משודרגת); versionCode+1

## בעיות ידועות (לא חוסמות)
- **אייקון שולחן העבודה מוצג כ-Wooden Fish**: שולחן העבודה של OWS לא קורא שמות חבילה של צד שלישי וחריץ האייקון משותף (באג ידוע בפוסט 29508 ב-bandbbs);
  אחרי התקנת אפליקציית צד שלישי צריך **להפעיל מחדש את השעון** כדי שתופיע נכון בשולחן העבודה. הפתרון המלא = להתקין את Purrlaunch (מחופש ל-com.xfaith.woodenfish,
  צריך קודם להסיר את Wooden Fish) - ה-rpk נמצא בקובץ המצורף 10856.webp בפוסט ב-bandbbs, חשבון הפורום ממתין לאישור מנהל וצריך להגיב בפוסט, ולכן כרגע אי אפשר להשיג אותו.
- הפקודה "Launch app" של ה-assistant מצליחה אך ייתכן שלא מעלה את האפליקציה לחזית (פתיחה משולחן העבודה עובדת כרגיל).
- לממשק "check install" סמנטיקה לא אמינה (הוא החזיר פעם true עבור חבילה שלא מותקנת) ואי אפשר להשתמש בו כקריטריון להתקנה; סומכים על קודי ההחזרה של install / launch.

## סיכום הסביבה
- ✅ authentication_state הוחזר ל-0 (בוצע בסביבות 10:38, 1->0)
- ✅ לולאת auto_verify הלא מאוישת נעצרה (היומן מסתיים ב-07:47 round=30)
- Toolchain: G:/oppo/.toolchain (gx v0.11.0); שכפול התיעוד הרשמי: work/glyphix_os/web-docs
- קוד האפליקציה: G:/oppo/com.rtos.qrwatch/src (v2: קרוסלה אוטומטית של 10 שניות + לחיצה למעבר ידני, qr-data.js מחזיק את תוכן הקוד)
