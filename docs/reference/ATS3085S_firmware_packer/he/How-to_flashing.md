מקור: https://github.com/purrrock/ATS3085S_firmware_packer (MIT). זהו תרגום לא רשמי.

##  מדריך שלב אחר שלב: שינוי וצריבה

### שלב 0.

איך להוריד את קושחת ה-OTA של היצרן עבור השעון שלכם.
יש קישור: https://dt1pro.wanruxia.com/xky-api/firmware/checkUpdate?devicePlan=10&number=88265
במקום המספר 88265 בסוף יש להציב את המספר שלכם. אפשר לראות אותו בשעון בתפריט 'Settings - About watch' (הגדרות - אודות השעון).
תופיע שורה בצורה Version1.73.21-88265R, והספרות האחרונות הן מה שאנחנו צריכים.
מציבים את המספר שלכם בקישור ורואים JSON. בשדה "file": יש קישור לקושחת ה-OTA שלכם:
```json
{
  "code": 200,
  "message": "Request successful",
  "success": true,
  "data": {
    "id": 1161,
    "createTime": "2026-01-31 16:49:30",
    "updateTime": "2026-03-04 10:34:54",
    "name": "C175C1",
    "adapterId": 1108,
    "limitationId": null,
    "version": "V1.73.21",
    "versionNum": 830021,
    "file": "https://assets2.dt1pro.cn/fw/26/03/02/1772439053925.bin",
    "fileSize": 4274688,
    "originFileName": "ota_A5S10GLY_C175G_A3-2026-02-28-17-03_V1_73_21.bin",
    "forceUpdate": false,
    "description": null,
    "prodType": true
  },
  "fail": false
}
```


### שלב 1. פירוק קושחת ה-OTA המקורית
[README.md](README.md)

---

### שלב 2. החלפת קובץ הליבה (`app.bin`)

החליפו את `app.bin` המקורי בקובץ `app.bin` ששיניתם.

---

### שלב 3. הרכבה הפוכה של הקושחה המותאמת
[README.md](README.md)
---

### שלב 4. התקנת הקושחה בשעון

אפשר להתקין את הקובץ שהתקבל `ota_patched_custom.bin` באחת משתי דרכים.

---

#### שיטה A. צריבה ישירות מהמחשב (`dt_ota_flasher.py`) (עדיין לא עובד!)

שיטה זו אינה דורשת סמארטפון, אפליקציית WearPro או זיוף תשובות של שרתים.

1. טענו את השעון לפחות עד 50%.
2. נתקו את השעון מאפליקציית WearPro בסמארטפון (וכבו את ה-Bluetooth בסמארטפון כדי לשחרר את שרת ה-GATT של השעון).
3.  גלו את כתובת ה-MAC של השעון:
   * **בשעון:** בתפריט ההגדרות - 'About watch' (אודות השעון)
   * **Windows / Linux:** כתובת MAC בצורה `AA:BB:CC:DD:EE:FF` (אפשר לראות במאפייני המכשיר או בעזרת כלי סריקת BLE, למשל `nRF Connect`).
4. הריצו את כלי הצריבה בקונסולה:

```bash
python dt_ota_flasher.py AA:BB:CC:DD:EE:FF ota_patched_custom.bin
```

דוגמה לתהליך העברה מוצלח:

```text
[*] Подготовка данных: 4274688 байт...
[*] Файл разбит на 18586 BLE-пакетов.
[*] Подключение к часам (MAC: AA:BB:CC:DD:EE:FF)...
[+] Подключено. Инициализация AOTA сессии...
[*] Текущий размер MTU соединения: 247 байт
[+] Инициализация успешна. Начинаем заливку прошивки...
    Прогресс: 1000/18586 пакетов (5.4%)
    ...
    Прогресс: 18586/18586 пакетов (100.0%)
[+] Передача завершена. Отправка команды Reboot...
[*] Успешно! Часы уходят в перезагрузку.
```

(תרגום הפלט לעיל, לעיון: מכין נתונים: 4274688 בתים... / הקובץ פוצל ל-18586 חבילות BLE. / מתחבר לשעון (MAC: AA:BB:CC:DD:EE:FF)... / מחובר. מאתחל סשן AOTA... / גודל ה-MTU הנוכחי של החיבור: 247 בתים / האתחול הצליח. מתחיל להעלות את הקושחה... / התקדמות: 1000/18586 חבילות (5.4%) / התקדמות: 18586/18586 חבילות (100.0%) / ההעברה הסתיימה. שולח פקודת Reboot... / הצלחה! השעון עובר לאתחול מחדש.)

---

#### שיטה B. צריבה דרך אפליקציית WearPro (HTTP Mocking)

אם ברצונכם להשתמש באפליקציית WearPro הסטנדרטית בנייד, אפשר לכפות שליחת קושחה על ידי יירוט בקשת ה-HTTP של בדיקת העדכונים.

**כלי היירוט:** [HTTP Toolkit](https://httptoolkit.com/) (עם יירוט ADB מופעל בסמארטפון Android עם Root או דרך אמולטור).

##### 1. הגדרת תשובת Mock לשרת העדכונים

ב-HTTP Toolkit צרו כלל (**Mock Rule**) ליירוט בקשת בדיקת הגרסאות:
* **Match Request:** `URL` -> `Contains` -> `/xky-api/firmware/checkUpdate`
* **Action:** `Provide response`
* **Status:** `200`
* **Headers:** `Content-Type: application/json`
* **Body (JSON):**
  ```json
    {
    "code": 200,
    "message": "Request successful",
    "success": true,
    "data": {
      "id": 1182,
      "createTime": "2026-03-02 16:12:11",
      "updateTime": "2026-03-04 10:35:00",
      "name": "C175GA3",
      "adapterId": 1203,
      "limitationId": null,
      "version": "V1.73.23",
      "versionNum": 830023,
      "file": "https://ota.local/firmware.bin",
      "fileSize": 6438400,
      "originFileName": "ota_A5S10GLY_C175G_A3-2026-02-28-17-03_V1_73_23.bin",
      "forceUpdate": true,
      "description": "null",
      "prodType": true
    },
    "fail": false
  }
  
  ```
  *(הערך `fileSize` חייב להתאים בדיוק לגודל הבתים של `ota_patched_custom.bin` שלכם)*.

##### 2. הגדרת הכלל שמגיש את הקובץ הבינארי
הוסיפו כלל שני ב-HTTP Toolkit ליירוט הורדת הקושחה:
* **Match Request:** `URL` -> `Equals` -> `https://ota.local/firmware.bin`
* **Action:** `Provide response`
* **Status:** `200`
* **Headers:** `Content-Type: application/octet-stream`
* **Body:** בחרו `From File` וציינו את הנתיב אל `ota_patched_custom.bin` במחשב שלכם.

##### 3. הפעלת העדכון
1. סגרו בכוח את אפליקציית WearPro בסמארטפון כדי לנקות את המטמון.
2. פתחו את WearPro -> הסעיף **Device** (מכשיר) -> **Firmware update** (עדכון קושחה).
3. האפליקציה תזהה "גרסה V1.73.23", תוריד את הקובץ שנוצר מ-`ota.local` ותעלה אותו אל השעון דרך Bluetooth.

---

## 🔧 אבחון ופתרון תקלות

1. **אפליקציית WearPro נעצרת ב-"Preparing firmware 0%" (הכנת הקושחה 0%):**
   * **סיבה:** אי-התאמה בין גודל הבתים של הקובץ `TEMP.bin` או `app.bin` לנתונים הרשומים בתגיות `<file_size>` בקובצי `ota.xml`.
   * **פתרון:** ודאו שהשתמשתם בסקריפט האריזה העדכני של הקושחה, שמעדכן אוטומטית את מטא-דאטה ה-XML.

2. **הסקריפט `dt_ota_flasher.py` מציג `BleakError` או מנתק את החיבור ב-1-2%:**
   * **סיבה:** מתאם ה-Bluetooth של המחשב אינו תומך בהרחבת אורך המסגרת DLE או שמפיל מאגרי MTU גדולים.
   * **פתרון:** הוסיפו השהיה קטנה בין שליחות המסגרות בסקריפט (הגדילו את הערך של `asyncio.sleep` ל-`0.01` שניות) או השתמשו במתאם Bluetooth 5.0+ חיצוני ב-USB.
