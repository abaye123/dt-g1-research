מקור: https://github.com/purrrock/dtg1-glyphix-docs (MIT). זהו תרגום לא רשמי.

# DT G1 Glyphix OS Documentation & RE Deltas (`dtg1-glyphix-docs`)

מאגר המכיל תיעוד מורחב, מתורגם ומובנה של מסגרת העבודה **Glyphix OS**, וכן ממצאי הנדסה לאחור של קושחת השעון החכם **DT NO.1** (פלטפורמת חומרה **Actions Semiconductor ATS3085S**, Zephyr RTOS).

הפרויקט פותר את משימת תרגום התיעוד ויצירת הקשר מצטבר (aggregated context) לטעינה במודלי רשתות נוירונים (LLM).

---

## 🎯 מטרות הפרויקט

1. **סנכרון עם Upstream:** הורדה בטוחה וניקוי של התיעוד המקורי מהמאגר [`glyphix-os/web-docs`](https://github.com/glyphix-os/web-docs).
2. **לוקליזציה:** תרגום מלא של התיעוד לאנגלית (`EN`) ולרוסית (`RU`).
3. **תיעוד עובדות הנדסה לאחור:** ניהול קטלוג עצמאי `src/re_deltas/` עם נתונים עובדתיים על מגבלות החומרה של ATS3085S, קריאות C++ API לא מתועדות, מבנה מכולות `.pkg` ותצורת ה-VFS.
4. **צינור בניית הקשר ל-LLM:** הידור אוטומטי של קובצי Markdown מפוזרים ל-7 מונוליטים מובנים לכל שפה, עם מפרידים מסוג `FILE_PATH:`.

---

## 📂 מבנה המאגר

```text
dtg1-glyphix-docs/
├── .gitignore
├── README.md
├── ai_context/                  # Ready aggregated files for LLMs
│   ├── EN/                      # English context (01_..._EN.md - 07_..._EN.md)
│   ├── RU/                      # Russian context (01_..._RU.md - 07_..._RU.md)
│   └── ZH/                      # Chinese context (01_..._ZH.md - 07_..._ZH.md)
├── scripts/                     # Automation tools
│   ├── build_ai_context.py      # Script that builds the aggregated context
│   └── sync_upstream.py         # Script for safely updating the sources from GitHub
└── src/                         # Source materials
    ├── original_docs/           # Cleaned snapshot of the original documentation (ZH)
    ├── re_deltas/               # Reverse engineering data (ATS3085S / DT G1)
    └── transl/                  # Localization files
        ├── EN/                  # English translation
        └── RU/                  # Russian translation
```

---

## 🛠️ הוראות שימוש

### 1. עדכון בטוח של המקורות הסיניים (Upstream Sync)

הסקריפט `scripts/sync_upstream.py` מוריד את הארכיון העדכני מ-GitHub, בודק את תקינות המבנה, מסיר זבל אינטרנטי (`.vuepress`, `i18n`, `package.json`) ומעדכן אטומית את התיקייה `src/original_docs/`.

הרצה:
```bash
python scripts/sync_upstream.py
```

*הערה: אם חיבור הרשת יופסק או שהארכיון יתברר כפגום, המקורות המקומיים ב-`src/original_docs/` לא ייפגעו.*

### 2. יצירת קובצי הקשר ל-AI

הסקריפט `scripts/build_ai_context.py` סורק את הקבצים מ-`original_docs/`, `transl/` ו-`re_deltas/`, מציב מפרידי מערכת ויוצר את הקבצים הסופיים בתיקייה `ai_context/`.

הרצה:
```bash
python scripts/build_ai_context.py
```

מבנה הקבצים שנוצרים ב-`ai_context/<LANG>/`:
* `01_glyphix_framework_core_<LANG>.md` - ליבת המסגרת, מניפסטים, מחזור חיים.
* `02_glyphix_ui_components_<LANG>.md` - רכיבי UI, Flexbox, סגנונות, אנימציות.
* `03_glyphix_system_api_<LANG>.md` - מודולי `@system.*` וקריאות מערכת.
* `04_glyphix_CxxDev_<LANG>.md` - מדריך לפיתוח נייטיב ב-C++.
* `05_glyphix_tutorials_<LANG>.md` - מדריכי לימוד ודוגמאות.
* `06_glyphix_hardware_deltas_and_undoc_funcs_<LANG>.md` - מגבלות החומרה של ATS3085S, dump של ה-API, הבדלים בין עובדות לתיעוד.
* `07_glyphix_toolchain_pkg_<LANG>.md` - מפרט הבנאי `gx build` ומבנה ה-`.pkg`.

---

## ⚠️ כללי תיעוד הנדסה לאחור (`src/re_deltas/`)

כל תוצאות ניתוח הקבצים הבינאריים של הקושחה, עבודה עם דיסאסמבלר, ניתוח dumps של RAM/Flash ופרוטוקולי Bluetooth נכנסות לתיקייה `src/re_deltas/`. 

נתונים מ-`src/re_deltas/` מוזרקים אוטומטית לקובץ `06_glyphix_hardware_deltas_and_undoc_funcs_*.md` עבור **כל** ענפי השפה (`EN`, `RU`, `ZH`). כך מובטח שמודל ה-LLM יהיה מעודכן במגבלות החומרה של השעון האמיתי, ללא תלות בשפת השיחה שנבחרה.

---

## ⚖️ רישיון וייחוס (Attribution)

* התיעוד המקורי של מסגרת Glyphix שייך ל-**XFaith Tech / Glyphix OS**.
* המאגר המקורי: [`glyphix-os/web-docs`](https://github.com/glyphix-os/web-docs)
* מאגר זה הוא מזלג (fork) מותאם, המיועד אך ורק למטרות מחקר, תאימות תוכנה והנדסה לאחור של אלקטרוניקה לבישה.
