> מקור: https://github.com/chengchengking/oppo-watch-s-sideload (MIT). זהו תרגום לא רשמי.

# מפרט פורמט הקונטיינר `.pkg` של Glyphix

> כל המסקנות במסמך הזה מגיעות מניתוח בייט אחר בייט של **חבילות אמיתיות שהופקו על ידי ה-toolchain הרשמי**, והסיבתיות אומתה ב**ניסויים מבוקרים**.
> Toolchain האימות: `glyphix-cli` 0.8.0-rc → `gx v0.11.0` (npm, בנוי מראש ל-Windows x64).
> פקודות השחזור נמצאות בסוף.

---

## 0. מסקנה במשפט אחד

`.pkg` הוא **ארכיון שטוח מינימלי**: מספר קסם `CR` + header של 32 בייט + טבלת רשומות בגודל קבוע + אזור שמות + אזור נתונים מיושר ל-32 בייט.
**אין חתימה, אין checksum של התוכן, אין הצפנה, אין דחיסה.** מפתח האינדקס של הרשומה הוא hash מסוג FNV-1a של שם הקובץ.

---

## 1. פריסה כללית

```
offset          content
────────────────────────────────────────────────────────────
0x00            header (32 bytes)
0x20            entry table (16 bytes × entry count)
                name area  (entry names concatenated back to back, no separators, no NUL)
                padding    (zero fill, aligned to 0x20)
data_start      data area  (each entry's data aligned independently to 0x20)
```

`data_start = align_up(0x20 + count*16 + len(all names), 0x20)`

---

## 2. Header (32 בייט)

| Offset | טיפוס | משמעות | ערך שנמדד |
|------|------|------|--------|
| 0x00 | `char[2]` | מספר קסם, קבוע `"CR"` (0x43 0x52) | `43 52` |
| 0x02 | `u16 LE` | גרסת header, נמדד תמיד 0 | `00 00` |
| 0x04 | `u32 LE` | מספר הרשומות | `05 00 00 00` = 5 |
| 0x08 | `byte[24]` | אזור שמור, נמדד כולו 0 | 24 × `00` |

> הערה: `"CR"` כנראה מייצג **C**ontainer **R**esource. שדה גרסת ה-header קיים אבל תמיד 0;
> לא ידוע אם ייעשה בו שימוש בגרסאות עתידיות - בפריקה יש לשמור את הערך המקורי כדי שאפשר יהיה לשחזר את החבילה.

---

## 3. Entry Table (16 בייט לכל רשומה, little endian)

| Offset | טיפוס | משמעות |
|------|------|------|
| +0x0 | `u32 LE` | **FNV-1a(שם הקובץ)** - מפתח האינדקס |
| +0x4 | `u32 LE` | offset מוחלט של הנתונים בקובץ |
| +0x8 | `u32 LE` | אורך הנתונים (בבייטים) |
| +0xC | `u32 LE` | אורך שם הקובץ בבייטים (ללא NUL) |

**אלגוריתם ה-hash אומת אחד אחד**:

```python
def fnv1a32(data: bytes) -> int:
    h = 0x811C9DC5
    for b in data:
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h
```

השוואה שנמדדה (`bundle.pkg`, 5 רשומות, כולן תאמו):

| שם קובץ | hash בטבלה | FNV-1a מחושב |
|--------|----------|-------------|
| `main/index.js` | `0x53374834` | `0x53374834` ✅ |
| `main/index.uo` | `0x571b7803` | `0x571b7803` ✅ |
| `main/qr-data.js` | `0x632fdbf6` | `0x632fdbf6` ✅ |
| `manifest.json` | `0x704e7b48` | `0x704e7b48` ✅ |
| `app.js` | `0xb4f94375` | `0xb4f94375` ✅ |

> ⚠️ זהו **אינדקס שמות**, לא checksum של תוכן. שינוי הנתונים לא מבטל את ה-hash -
> כלומר **לשכבת הקונטיינר אין שום הגנת שלמות**.

---

## 4. אזור השמות ויישור

- השמות משורשרים צמוד זה לזה לפי **סדר טבלת הרשומות**, ללא מפרידים וללא NUL בסוף; מפצלים אותם לפי `name_len`.
- אחרי אזור השמות מוסיפים ריפוד של `0x00` עד לגבול 0x20 הבא, וזהו `data_start`.
- הנתונים של כל רשומה מתחילים ב-`offset` שלה ותופסים `size` בייטים; **ה-`offset` של הרשומה הבאה הוא
  `align_up(offset + size)`**. גם אחרי הרשומה האחרונה מוסיפים ריפוד אפסים עד גבול 0x20.

שרשרת שנמדדה (`bundle.pkg`, אורך קובץ כולל 2240 = 0x8C0):

```
names:  0x70 .. 0xac   (13+13+15+13+6 = 60 = 0x3C)
pad →   data_start = 0xc0
0xc0 + 0xf0 (240)  = 0x1b0 → align → 0x1c0   ✅ entry 1 offset
0x1c0 + 0x1f6(502) = 0x3b6 → align → 0x3c0   ✅ entry 2 offset
0x3c0 + 0x2cc(716) = 0x68c → align → 0x6a0   ✅ entry 3 offset
0x6a0 + 0x4d (77)  = 0x6ed → align → 0x700   ✅ entry 4 offset
0x700 + 0x1b3(435) = 0x8b3 → align → 0x8c0   ✅ = file length
```

---

## 5. סדר הרשומות

**לא ממוין**. הסדר שנמדד ש-`gx build` מפיק הוא תוצר לוואי של תהליך הבנייה:

```
main/index.js → main/index.uo → main/qr-data.js → manifest.json → app.js
```

סדר טבלת האינדקס תואם לסדר הפיזי באזור הנתונים (ה-offsets עולים מונוטונית).
**לשחזור ברמת בייט חובה לשמור על הסדר המקורי** - וזו בדיוק הסיבה ש-`pkg_tool.py` רושם את הסדר בקובץ צד
`.pkg-index.json`.

---

## 6. קידוד ה-`manifest.json` המוטמע

ה-`manifest.json` שבתוך החבילה **אינו JSON טקסטואלי** אלא בינארי מקומפל. הפריסה שנמדדה, 77 בייט:

| Offset | טיפוס | משמעות |
|------|------|------|
| 0x00 | `u32 LE` | מספר קסם `0x0168B5AE` (קבוע) |
| 0x04 | `u32 LE` | 0 |
| **0x08** | `u32 LE` | **`(vendorID << 16) \| productID`** ← קישור למכשיר |
| 0x0C | `u32 LE` | 1 |
| מ-0x10 | רצף | כמה מחרוזות מסוג `קידומת אורך u16 + UTF-8` |

רצף המחרוזות שנמדד: `package` → `name` → `versionName` → `""` (מחרוזת ריקה) → כמה שדות בגודל קבוע בסוף.

מפוענח מהדגימה הזו:

```
magic       0x0168b5ae
device_id   0x00000025   → vendorID=0x0000 productID=0x0025
package     com.rtos.qrwatch
name        扫码卡片
versionName 1.0.0
consumed    0x39 / 0x4d
tail        0b 00 00 00 | 01 00 00 00 | 04 00 "main" | 01 00 00 00 | 00 00 00 00
            (semantics not confirmed, kept as is)
```

### 6.1 אימות מבוקר של מזהה המכשיר (מפתח)

`vendorID` / `productID` מגיעים מ**הגדרת המכשיר שנבחרה בזמן הבנייה** (`gx build -d <name>`),
והם כתובים קשיח ב-`share/glyphix/devices/<name>.yml`:

```yaml
vendorID: 0x0000
productID: 0x0025     # default-watch-466x466.yml
```

בונים את אותה אפליקציה עם ארבע הגדרות שונות וקוראים את `u32@0x08` של ה-manifest:

| הגדרת מכשיר | vendorID ב-yml | productID ב-yml | `u32@0x08` שנמדד | מסקנה |
|----------|-----------------|------------------|-----------------|------|
| `default-watch-466x466` | 0x0000 | 0x0025 | `0x00000025` | ✅ |
| `default-watch-360x360` | 0x0000 | 0x0026 | `0x00000026` | ✅ |
| `generic-watch-466x466` | 0x0000 | 0x0000 | `0x00000000` | ✅ |
| **`oppo-rtos-watch` (נבנתה בעצמנו)** | **0x1234** | **0x5678** | **`0x12345678`** | ✅ הסיבתיות הוכחה |

קובץ yml של מכשיר שנבנה בעצמנו ומונח בתיקיית המשתמש מזוהה על ידי ה-toolchain:

```
%APPDATA%\glyphix\devices\<name>.yml     ← the device search path in the gx list path
```

**מסקנה**: כדי להפיק חבילה ל-vendor/product מסוים אין צורך "קודם ללכוד חבילה מקורית ואז למלא את ה-ID" -
פשוט כותבים yml של מכשיר ואפשר "לצרוב" כל ID. ולהפך, בחבילה מקורית שנלכדה, קריאה עם
`pkg_tool.py manifest` מגלה לאיזה מכשיר היא קשורה.

> עדיין יש לשים לב: **לדעת את ה-ID ≠ להצליח להתקין**. האם ה-firmware של השעון באמת מאמת את זוג ה-ID הזה,
> ואיך נראית כשלון באימות (`InvalidDevice`? דחייה שקטה?) - את הצעד הזה חייבים לאמת על מכשיר אמיתי.

---

## 7. סיכום אבטחה

| ממד | מסקנה | בסיס |
|------|------|------|
| חתימה | **אין** | לקונטיינר אין שדה חתימה; ה-hash של האינדקס נשאר תקף גם אחרי שינוי הנתונים |
| checksum של תוכן | **אין** | ה-hash של האינדקס מחושב על **שם הקובץ**, ללא קשר לתוכן |
| הצפנה | **אין** | אזור הנתונים הוא טקסט גלוי, אפשר לקרוא ישירות את קוד ה-JS |
| דחיסה | **אין** | `main/qr-data.js` נשמר כטקסט גולמי |
| קישור למכשיר | **יש, אבל רק הצהרתי** | `u32@0x08` ב-manifest; האימות נעשה בצד ה-firmware, לא אומת |

זה עקבי עם התיעוד הרשמי: שכבת ה-framework, `installPackage()`, לא מאמתת חתימה, ומדיניות אימות החתימה מתווספת על ידי היצרן.

---

## 8. פקודות שחזור

```bash
# 1. Install the toolchain (Windows)
npm install glyphix-cli

# 2. Create a project + build the package
gx new -t simple com.example.app
cd com.example.app
gx build -d default-watch-466x466
#   → .glyphix-work/dist/<device>/com.example.app/bundle.pkg

# 3. Verify with this tool
python pkg_tool.py info      bundle.pkg
python pkg_tool.py manifest  bundle.pkg
python pkg_tool.py extract   bundle.pkg ./out
python pkg_tool.py verify    bundle.pkg      # must print "字节级一致: YES" (byte-level identical: YES)
```

---

## 9. אומת / לא אומת

**אומת בייט אחר בייט**
- מבנה ה-header, משמעות שדות טבלת הרשומות, hash האינדקס FNV-1a, אזור השמות, כלל היישור ל-0x20
- נוסחת הגזירה של `data_start`, ריפוד אחרי הרשומה האחרונה, אורך הקובץ הכולל
- מספר הקסם של ה-`manifest`, `device_id = (vendorID<<16)|productID` (ניסוי מבוקר)
- תוצאת הפריקה **זהה לחלוטין** לפלט הרשמי של `gx pack -x`
- פריקה → אריזה מחדש: **מעגל שלם זהה ברמת בייט**

**לא אומת (אין להשתמש כמסקנות)**
- משמעות שדות ה-manifest אחרי `0x39` בזנב (`0b 00 00 00`, `01 00 00 00`, ה-`01` אחרי `"main"` וכו')
- מתי ייעשה שימוש בשדה גרסת ה-header
- האם סדר הרשומות יציב בכל גרסאות/הגדרות `gx` (הכלי הזה נמנע מהסתמכות על ההנחה באמצעות קובץ צד)
- ההתנהגות בפועל של ה-firmware באימות `vendorID/productID`
