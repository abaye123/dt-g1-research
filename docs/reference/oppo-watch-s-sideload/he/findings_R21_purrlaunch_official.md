> מקור: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). זהו תרגום לא רשמי.

# findings_R21 - PurrLaunch הרשמי (נבנה מקוד המקור ב-GitHub) הותקן בהצלחה על השעון (2026-10-11 11:24-11:29)

## מקור
- אותר בעקבות רמז מהמשתמש: github.com/purrrock/PurrLaunch (MIT, "Launcher PKG for smartwatchs")
- ל-release v1.2.2 יש com.xfaith.woodenfish.pkg בנוי מראש, אבל ההורדה מ-github.com חסומה
- -> משכנו את עץ הקוד המלא (17 קבצים) דרך api.github.com, בנינו מקומית עם gx, עם שתי התאמות ל-OWS:
  1. הוספנו ל-manifest את `icon: /assets/icon.png` (תמונת כפת חתול, אימות חובה של OWS)
  2. versionCode 1 -> **9** (כדי לדרוס את purrlaunch-lite v8 שהתקנו בעצמנו קודם בחלון הזה)

## יכולות (כפי שהמחבר מצהיר ב-UNDER-THE-HOOD.md, בהנדסה לאחור על ה-DT NO.1 G1)
- **תפריט שולחן העבודה הוא hardcoded, ה-OS לא סורק דינמית את ספריית החבילות** -> הדרך היחידה של אפליקציית צד שלישי להגיע לשולחן העבודה = לתפוס חריץ hardcoded (Wooden Fish)
- לחיצה על החריץ -> AppletKit (C++) מחפש בספריית ADBT_Applet -> מעביר את השליטה לאפליקציית ה-JS עם שם החבילה הזה
- מובנה: רשימת אפליקציות (pkg.list+getInfo, בלי עצמו/אמולטורים), **התקנת pkg ישירה דרך USB** (staging ב-VFS עם מחסום I/O של 800ms ->
  pkg.install({src,force:true,verify:false}), עוקף את ה-sandbox), מנהל קבצים, דף הסרה, מידע מערכת, מציג טקסט
- חתימת ההתקנה: `{src:"internal://files/app.pkg", force:true, verify:false}` (ה-JSI של היצרן מזהה רק את המפתח src;
  העברת מחרוזת ל-pkg.remove קורסת בשקט - חריגת JSI של ATS3085S, ב-OWS ייתכן שזה שונה אבל כדאי להתייחס לזה)

## אימות
```
11:28:01.594  安装应用 成功 (36512B, upgrade-overwriting lite v8)
11:29:29.092  启动应用 成功
```
- קוד המקור (גרסה מותאמת ל-OWS): G:/oppo/PurrLaunch/ (כולל נכסי אייקון כפת החתול)
- התגלה גם שהמשתמש התקין בעצמו את com.rtos.libraryqr (7104B, הותקנה ב-11:18, הופעלה ב-11:21) - הצנרת כבר שימשה שוב ✓

## מסקנה סופית לגבי בעיית האייקון
- אייקון חריץ שולחן העבודה = משאב בצד ה-OS (תפריט hardcoded + רישום נפרד של `icon_<pkg>` כשהחנות מתקינה)
- חבילות שהותקנו ב-sideload (בין אם דרך ערוץ ה-debug ובין אם עם אייקון בתוך החבילה) תמיד חוזרות בשולחן העבודה לגלגל שיניים - **אין פתרון בצד החבילה**, זהו פגם בשולחן העבודה של OWS
- השימושיות לא נפגעת: רשימת ה-launcher מציגה שמות ושמות חבילה, ולחיצה מפעילה את האפליקציה
- כדי לתקן מהשורש בעתיד: ל-probe כבר יש יכולת לדחוף קבצי `icon_<pkg>` (שינוי ftprobe18 R20b, לא אומת הפעם -
  הפעלת ה-probe נחסמה על ידי Android 14 "did not call finish", וצריך להריץ אותו כשהטלפון פתוח), או לחכות ל-Guiyuan Assistant v1.3

---

## נספח: ניסוי דחיפת `icon_<package name>` (R21b, 2026-10-11 11:55) - ממתין לאישור אחרי הפעלה מחדש

**השערה**: אייקון שולחן העבודה של OWS מונע נתונים (ל-Wooden Fish היה אייקון אחרי התקנה מהחנות -> הפך לגלגל שיניים אחרי הדריסה שלנו דרך ה-debug = הרישום אבד),
ומוסכמת רישום האייקון של החנות = קובץ `icon_<package name>` שנשלח בנפרד בערוץ הקבצים sid=272 (FileInfo=appstore_uri_icon).

**ניסוי** (שינוי ftprobe18 R20b, עם PNG של אייקון 432px מובנה ב-assets):
```
handleAuthentication -> 1001 (needs the authentication_state=1 bypass; set back to 0 after the run)
peerFound=true liveAccId=9486
cid=10 precheck → pkg push ×3 candidates (transId 2102272838/1876337960/288563888, all handleTransferComplete)
icon push: transId 291786294, FT_SETUP_REQ fileName:icon_com.rtos.qrwatch,
           Total 843 Read 843 ✓ → handleTransferComplete: Completed :icon_com.rtos.qrwatch ✓
           md5:49d7136194c8c411f003343a5e88a8b7
```
**על ה-wire זה משחזר 1:1 את רצף החנות (pkg→icon, אותו ערוץ, אותה מוסכמה), בלי אף שגיאה.**

**אישור**: מפעילים מחדש את השעון -> בודקים אם אייקון חריץ "启动器" (Launcher) בשולחן העבודה הופך לדוגמת קוד QR.
- אם משתנה -> בעיית האייקון נפתרה (דחיפת `icon_<package name>` = שיטת רישום האייקון, אפשר לכתוב ב-DEV_GUIDE)
- אם עדיין גלגל שיניים -> מקור האייקון בשולחן העבודה של OWS (nucleus 0.7.0-68) אינו המוסכמה הזו (לא איזומורפי ל-G1),
  אין עוד אחיזה בצד החבילה, והדרכים שנותרו הן רק: Guiyuan Assistant v1.3 / להשלים עם גלגל השיניים

**הערות הנדסיות**: ה-probe חייב authentication_state=1 כדי לעבור את אימות ה-framework (1001), זכרו להחזיר ל-0 אחרי כל הרצה;
אם ה-Activity של ה-probe מופעל כשהטלפון נעול / המסך כבוי, Android 14 הורג אותו בכוח ("did not call finish"), ולכן מריצים כשהמסך דלוק והטלפון פתוח.

---

## ✅ תוצאת אישור R21b (2026-10-11 12:2x): **שיטת רישום האייקון עובדת**
המשתמש אישר בעיניו: אחרי הפעלה מחדש של השעון, אייקון "扫码卡片" (QR Card) (com.rtos.qrwatch) בשולחן העבודה הפך לדוגמת קוד QR.
שיטת דחיפת `icon_<package name>` קודמה רשמית ל-SOP הסטנדרטי (DEV_GUIDE.md 5.3).

## R21c רישום אצווה של שני אייקונים (12:19)
```
12:19:11  FT_SETUP_REQ fileName:icon_com.rtos.qrwatch      (843B)  → handleTransferComplete ✅
12:19:23  FT_SETUP_REQ fileName:icon_com.xfaith.woodenfish (1364B) → handleTransferComplete ✅
```
- ftprobe18 שונה ללולאה על מערך icons[][] של מספר אייקונים (fireIconPush(acc, peer, assetName, wireName))
- ממתין שהמשתמש יפעיל מחדש ויאשר את אייקון חריץ ה-launcher (כפת חתול)
- אחרי ההרצה authentication_state הוחזר ל-0 ✓
