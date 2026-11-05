> מקור: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). זהו תרגום לא רשמי.

# מקור ויחוס של משאבים חיצוניים (SOURCES)

> **עיקרון**: כותבים רק שדות שאפשר לאמת במקום. מה שלא נמצא מסומן "לא צוין"; **לעולם לא ממלאים שם בשם מישהו אחר**.
> לכל פריט יש תאריך אימות; אם יש סתירה מול ה-upstream, ה-upstream קובע, ופתיחת issue שמצביע על כך מתקבלת בברכה.

---

## 1. Guiyuan Assistant (Glyphix Assistant)

| פריט | ערך | איך לאמת |
|---|---|---|
| שם חבילה | `com.glyphix.assistant` | דף ההפצה / APK |
| **דף הפצה מקורי** | https://www.pgyer.com/glyphix-assistant | פותחים ישירות |
| הגרסה העדכנית ב-upstream | **v1.3 (build 3, 2026-10-08)**, הערת גרסה "supports OHealth" | דף ההפצה |
| משוקף במאגר הזה | **v1.2 (build 2, 2026-08-21)** | היסטוריית הגרסאות בדף ההפצה |
| יוצר / מפתח | **לא צוין בדף ההפצה; המאגר הזה לא ממלא אותו** | לא בדף האינטרנט ולא ב-API של Pgyer יש שדה כזה |
| שושלת | לפי נוסח המדריך: מאז 2.5.0 `glyphixdebug` הפריד את "bridge mode" ל-Guiyuan Assistant | פוסט 29508 ב-Mitan (bandbbs) |
| GitHub | אין מאגר או קוד מקור קשורים | חיפושים של "瑰元助手", "com.glyphix.assistant", "glyphix assistant" ב-2026-10-21 החזירו כולם ריק |

**איך נקבע דף ההפצה הזה** (ניתן לשחזור, לא רק חיפוש):

```bash
# 1) Extract the app's built-in update check URL from the mirrored APK
unzip -p glyphix-assistant-v1.2.apk classes.dex | strings \
  | grep -o 'pgyer.com/apiv2/app/check[^"]*'
# 2) Query the Pgyer app info with the same appKey
curl 'https://www.pgyer.com/apiv2/app/view?_api_key=<api_key from step 1>&appKey=<appKey from step 1>'
```

ב-JSON שמוחזר בצעד 2: `buildName` = 瑰元助手, `buildIdentifier` = com.glyphix.assistant,
`buildShortcutUrl` = glyphix-assistant -> כתובת דף ההפצה שלמעלה; `buildVersion` / `buildCreated` תואמים לגרסה ולתאריך שבטבלה.

> ה-`api_key` הוא מפתח קריאה בלבד שמובנה באפליקציה; המאגר הזה לא מפרסם אותו מחדש, כדי למנוע ניצול לרעה.

---

## 2. מדריך ב-Mitan: `[教程]OPPO WatchS 如何侧载应用` (מדריך: איך לעשות sideload של אפליקציות ל-OPPO Watch S)

- קישור: https://www.bandbbs.cn/threads/29508/
- מחבר: **libiao0418** (Mitan UID 3485823, גלוי בעמוד הפוסט)
- **רק מחבר המדריך**, לא מחבר Guiyuan Assistant, אלא רק משתמש בכלי - הובהר על ידי המחבר עצמו ב-issue #1
- ב-2026-10-10 נוסף בפוסט קישור לכונן ענן עם הכלים ששימשו במדריך (הסיסמה בפוסט המקורי); קבצים מצורפים כמו ה-rpk של Purrlaunch מושגים לפי ההנחיות בפוסט המקורי

---

## 3. PurrLaunch

- Upstream: https://github.com/purrrock/PurrLaunch (MIT, v1.2.2)
- מחבר: **purrrock** (מוצג ב-GitHub כ-PurrRock CatsBand)
- הקשר למאגר הזה: `apps/purrlaunch-ows/` הוא ה-delta המינימלי שגורם לו להתקין על OWW262; לא יצירה מקורית
- **אין** קשר יחוס למחבר המדריך מפריט 2 שלמעלה

---

## 4. התיעוד הרשמי של Glyphix

- https://github.com/glyphix-os/web-docs
- שימוש: המקור המוסמך לתחביר דפים, רשימת הרכיבים וה-API של `@system.*`

---

## 5. glyphix-cli (toolchain הבנייה)

- חבילת npm: `glyphix-cli`, ה-registry מציג latest = **0.8.0-rc** (עודכן ב-2026-03-24)
- גרסת ה-`gx` שמותקנת היא **v0.11.0** (שני המספרים אינם אותו דבר; README ו-DEV_GUIDE מנוסחים בהתאם)

---

## 6. יחוס שגוי שהופיע בעבר (נשמר ברשומה כדי לא לחזור עליו)

- "מחבר המדריך" נכתב פעם כ"מחבר Guiyuan Assistant", ועל גבי זה הוצמד חשבון בפלטפורמת צד שלישי **ללא כל ביסוס**
  (שום דבר ב-GitHub, בפוסט ב-Mitan או במאגר Purrlaunch לא קשור אליו; שם החשבון לא חוזר כאן, כדי לא להפיץ אותו בשנית).
- הכול נמחק ב-2026-10-21 בעקבות issue #1. מלבד "מחבר המדריך libiao0418", המאגר כעת אינו כולל שום יחוס אישי.

---

**כלל תחזוקה**: לכל כלי/משאב צד שלישי חדש, קודם רושמים בטבלה הזו את המקור ואת תאריך האימות, ורק אחר כך כותבים אותו בגוף הטקסט;
אם אי אפשר להשיג מקור, כותבים רק את הקישור + "לא צוין", ולא כותבים שם.
