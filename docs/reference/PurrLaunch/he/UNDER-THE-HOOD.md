> תרגום לא רשמי לעברית של מסמך מתוך https://github.com/purrrock/PurrLaunch (רישיון MIT).

# מאחורי הקלעים: הארכיטקטורה וההנדסה לאחור של PurrLaunch

מסמך זה מתאר את הפנימיות של המשגר **PurrLaunch** לשעון החכם DT NO.1 G1 (שבב Actions Semiconductor ATS3085S, Glyphix OS). האפליקציה נוצרה באמצעות הנדסה לאחור של הפלטפורמה הסגורה של היצרן, והיא מנצלת סדרה של מאפיינים ארכיטקטוניים וממשקי API לא מתועדים.

---

## 1. וקטור תקיפה: התחזות למשבצת מערכת (App Spoofing)

ממשק המשתמש הגרפי (GUI) של השעון נשען על רשימה קשיחה של אפליקציות. מערכת ההפעלה אינה סורקת באופן דינמי את תיקיית החבילות כדי לבנות את התפריט הראשי.

כדי להשיג נקודת כניסה (Entry Point), PurrLaunch משתמש בהתחזות באמצעות manifest. הקובץ `manifest.json` של המשגר דורס את ה-ID מסוג `package` של המערכת, השייך לאחת האפליקציות המותקנות מראש (במקרה זה "Wooden Fish"):

```json
{
  "package": "com.xfaith.woodenfish",
  "name": "PurrLaunch",
  "permissions": [
    { "name": "watch.permission.SYSTEM" }
  ]
}
```

כשהמשתמש מקיש על הסמל "Wooden Fish" בתפריט הראשי, דימון ה-`AppletKit` ב-C++ מחפש את ה-ID `com.xfaith.woodenfish` במסד הנתונים `ADBT_Applet` ומעביר את השליטה לקוד ה-JavaScript שלנו, ובכך מעניק לו הרשאות מערכת.

---

## 2. בידוד ארגז חול (VFS מול POSIX)

האתגר הטכני המורכב ביותר היה מימוש התקנת חבילות חדשות (`pkg.install()`) ישירות מכונן USB.

השעון החכם משתמש ב-**Virtual File System (VFS)** מעל מערכת הקבצים הפיזית (FatFS). אזור ה-USB של המשתמש מעוגן כ-`internal://mass/`. לאפליקציית ה-JS יש הרשאת קריאה לתיקייה זו דרך העטיפה `@system.file`.

עם זאת, מתקין המערכת (`AppletKit`), הכתוב ב-C++, רץ בהקשר מבודד וניגש לקבצים ישירות באמצעות קריאות בסגנון POSIX. אם נעביר לו את הנתיב הווירטואלי `internal://mass/app.pkg`, המנתח אינו מצליח לפענח את הנתיב וזורק שגיאה `package file is not exist`.

### הפתרון: תבנית "Staging Cache"
כדי לעקוף את בידוד ארגז החול, PurrLaunch מבצע התקנה דו-שלבית:
1. באמצעות מודול ה-VFS של JS, החבילה מועתקת באופן אסינכרוני מאזור ה-USB הציבורי (`internal://mass/`) לתיקיית ארגז החול הפרטית של האפליקציה (`internal://files/`).
2. הנתיב לקובץ שהועתק מועבר אז למתקין ה-C++. מכיוון שהתיקייה הזו בבעלות האפליקציה עצמה, מערכת ההפעלה מפענחת נכון את הנתיב הפיזי ומעניקה למתקין הרשאות קריאה.
3. לאחר שהמערכת מחלצת את הארכיון, הקובץ הזמני נמחק.

---

## 3. מחסום קלט/פלט בחומרה (Race Condition)

למיקרו-בקר ATS3085S אין מנגנוני מטמון מורכבים למערכת הקבצים, כמו אלה שבמערכות הפעלה מלאות כגון Linux או Android.

במהלך הפיתוח התגלה Race Condition קריטי בקלט/פלט: ה-promise של `file.copy()` הסתיים מיד לאחר שחוצץ ה-RAM התמלא, *לפני* ששבב בקר זיכרון ה-flash ב-SPI כתב פיזית את הנתונים לאחסון וסגר את ה-file descriptor. קריאה ל-`pkg.install()` מיד אחרי שה-promise הסתיים הובילה לשגיאת קריאה (דימון ה-C++ ראה את הקובץ כריק או נעול).

**הפתרון:** מימוש מחסום קלט/פלט (I/O Barrier) חומרתי מלאכותי.

```javascript
// 1. Start copying
await file.copy({ srcUri: vfsUri, dstUri: targetUri });

// 2. I/O Barrier: Freeze the JS thread with a macro-task, 
// giving the RTOS CPU time to flush flash memory buffers.
await new Promise(resolve => setTimeout(resolve, 800));

// 3. Now it is safe to call the C++ API
await pkg.install(config);
```

---

## 4. חריגות OEM בקישור C++ (ניתוח JSI)

למרות שפלטפורמת Glyphix מתקננת את ה-API שלה, יצרן החומרה (Actions Semiconductor) הכניס שינויים קריטיים בחתימות הקישור של C++ (JSI - JavaScript Interface) במודול `@system.package`.

1. **טיפוסי ארגומנטים קפדניים:** מנתח ה-C++ זורק קריאות אם מועבר פרימיטיב (מחרוזת) במקום אובייקט תצורה. לדוגמה, הרצת `pkg.remove("com.app")` גורמת ל-*Silent Crash* (התהליך מת בלי לזרוק חריגת JS).
2. **מפתחות לא סטנדרטיים:** התיעוד הסטנדרטי מציע להעביר את המפתח `uri` או `path` להתקנה. סקריפט brute-force אנליטי חשף שהיצרן קבע בקוד המנתח של C++ שיצפה אך ורק למפתח **`src`**.

החתימה הסופית שעובדת להתקנה:
```json
{
  "src": "internal://files/app.pkg",
  "force": true,
  "verify": false
}
```

חתימת "Fat Object" סופית להסרה בטוחה:
```json
{
  "package": "com.target.app",
  "id": "com.target.app",
  "app": "com.target.app",
  "pkg": "com.target.app"
}
```

---

## 5. הידרדרות מסגרת ה-UI

כדי להפחית את צריכת ה-RAM, היצרן קיצץ באגרסיביות את מנוע הגרפיקה המובנה של השעון:

* **צמתים וירטואליים אסורים:** התג `<block>`, שהוא סטנדרטי ב-QuickApp/Glyphix, גורם לקריסת מנתח ה-XML (`unsupported component: Block`). יש להשתמש בתגי `<div>` קלאסיים במקום.
* **דיאלוגי מערכת נמחקו:** המודול `@system.prompt` מנוטרל. קריאה ל-`prompt.showDialog()` זורקת `TypeError`.
