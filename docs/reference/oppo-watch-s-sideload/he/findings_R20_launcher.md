> מקור: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). זהו תרגום לא רשמי.

# findings_R20 - בניית Purrlaunch-lite בעצמנו: launcher שתופס את חריץ Wooden Fish (2026-10-11 10:41-10:47)

## רקע
המשתמש ביקש לשנות את אייקון שולחן העבודה. הפתרון המקורי בפוסט = להתקין Purrlaunch (ה-rpk קיים רק כקובץ המצורף 10856.webp ב-Mitan, ולא ניתן להשיגו עם הרשאות החשבון).
אין מראה בשום מקום ברשת (GitHub/Gitee/Coolapk/כונני ענן) -> **בונים מקבילה בעצמנו**: מהותו של Purrlaunch = תפיסת com.xfaith.woodenfish
(חריץ של אפליקציית חנות ששולחן העבודה מציג נכון) + מתן רשימת אפליקציות צד שלישי / מפעיל.

## מימוש (הקוד ב-G:/oppo/purrlaunch-lite/)
- שם חבילה **com.xfaith.woodenfish**, versionCode **8** (> 7 של Wooden Fish מהחנות), name=启动器 (Launcher), icon=/assets/icon.png
- דף: `@system.package.list('app')` מציג את כל האפליקציות -> `pkg.getInfo(pkg)` מביא את השם -> `@system.launch.launch(pkg)` מפעיל בלחיצה
- מוציא את עצמו; חבילות מערכת (הקידומות com.heytap/oplus/coloros/android) ממוינות לסוף; רכיב scroll לרשימה הנגללת
- בנייה: gx build -d oppo-rtos-watch -f -> bundle.pkg 3200B

## התקנה ואימות
```
10:41:19.653  安装应用 成功 (total_size:3200)    ← the debug channel directly "upgrade-overwrites" the store Wooden Fish, no signature/version block
10:42:09.083  lvgl: exit application com.xfaith.woodenfish success   ← the old Wooden Fish was exited
10:42:39.166  app.life: call onDestroy in pkg://com.xfaith.woodenfish
10:47:11.509  app.life: call onShow in pkg://com.xfaith.woodenfish          ← the new launcher is running
10:47:11.514  app.life: call onInit / onReady in .../main/index.uo          ← full page lifecycle
10:47:11.612  gx_on_screen_on → eventLoop refresh 1-5 (rendering done, no errors)
```

## מסקנות
- **דריסה בשדרוג של אפליקציית חנות עובדת במלואה** (ערוץ ה-debug לא בודק חתימה; מספיק ש-versionCode גבוה מהגרסה המותקנת)
- מעתה כל אפליקציית צד שלישי חדשה שמותקנת תופיע ברשימת ה-launcher (list('app') סורק דינמית)
- כדי להחזיר את Wooden Fish: מתקינים אותה מחדש מחנות האפליקציות של השעון (זה בתורו דורס את ה-launcher, אחד או השני)
- ממתין לאישור המשתמש: האם שם/אייקון חריץ שולחן העבודה מציג כעת "启动器" (Launcher) (ייתכן שנדרשת הפעלה מחדש לרענון)
