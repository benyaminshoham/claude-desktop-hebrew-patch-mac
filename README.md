# תיקון עברית ב-Claude Desktop (Mac) · Hebrew RTL Fix for Claude Desktop (macOS)

---

## 🇮🇱 הוראות בעברית

### מה זה עושה?

Claude Desktop לא מציג עברית נכון — הטקסט מיושר לשמאל ומעורבב עם אנגלית בצורה מבולגנת.  
הסקריפט הזה מתקן את זה: עברית תוצג מימין לשמאל, כולל ברשימות, בטבלאות ובשדות הקלדה.  
בלוקי קוד נשארים LTR כמו שצריך.

> **חשוב:** הפאץ' מתקנת את השיחות **וגם** את ממשק ה-Co-Work (סרגל הצד, ההיסטוריה, ה-Agents).

---

### דרישות מוקדמות

לפני שמתחילים, צריך שיהיה מותקן על המחשב:

| מה | בשביל מה |
|----|-----------|
| **Node.js** | הסקריפט משתמש בו כדי לפתוח את הקובץ הפנימי של Claude |
| **macOS** | הסקריפט עובד רק על Mac |
| **Claude Desktop** | בנתיב הרגיל: `/Applications/Claude.app` |

**לבדוק אם Node.js מותקן:** פותחים Terminal ומקלידים:
```
node --version
```
אם מופיעה מספר גרסה (למשל `v20.11.0`) — הכל טוב.  
אם לא — מורידים מ-[nodejs.org](https://nodejs.org) ומתקינים.

---

### שיטה קלה — לתת ל-Claude לעשות הכל

1. פותחים Claude Desktop
2. מתחילים שיחה חדשה
3. מעלים את הקובץ `patch-claude-rtl.sh` לצ'אט (גוררים לתוך החלון)
4. כותבים לקלוד:

> "הרץ את הסקריפט הזה כדי לתקן את העברית באפליקציה"

Claude יריץ את הסקריפט אוטומטית, יבקש סיסמה אם צריך, ויסיים את הפאץ'.

---

### שיטה ידנית — Terminal

1. **פותחים Terminal** (מחפשים "Terminal" ב-Spotlight עם Cmd+Space)

2. **מנווטים לתיקייה עם הקבצים:**
   ```bash
   cd /path/to/claude-desktop-hebrew-patch-mac
   ```
   (אפשר גם לגרור את התיקייה לחלון ה-Terminal אחרי `cd ` ולחיצה Enter)

3. **מריצים את הסקריפט:**
   ```bash
   ./patch-claude-rtl.sh
   ```

4. **מזינים סיסמת Mac** כשמבקשים (הסקריפט צריך הרשאות לשנות את קבצי האפליקציה)

5. **מחכים** — הסקריפט יסגור את Claude, יתקן, ויפתח אותו מחדש. תהליך שלם לוקח כ-30–60 שניות.

6. **סיימנו!** Claude יפתח עם תמיכה נכונה בעברית.

---

### שחזור — איך מחזירים למצב המקורי

אם משהו לא עובד כמו שצריך, מריצים:

```bash
./restore-claude-rtl.sh
```

הסקריפט ישחזר את הגרסה המקורית של Claude אוטומטית.

---

### שאלות נפוצות

**שאלה: האם זה בטוח?**  
כן. הסקריפט יוצר גיבוי לפני כל שינוי, ומשחזר אוטומטית אם Claude לא נפתח אחרי הפאץ'.

**שאלה: אחרי עדכון של Claude הסקריפט מפסיק לעבוד?**  
נכון. עדכון של Claude מחליף את הקבצים הפנימיים. פשוט מריצים שוב את הסקריפט אחרי כל עדכון.

**שאלה: Co-Work הפסיק לעבוד אחרי הפאץ'?**  
בגרסה החדשה זה לא אמור לקרות. אם בכל זאת קורה — מריצים `./restore-claude-rtl.sh` ומדווחים ב-[Issues](../../issues).

---

---

## 🇺🇸 English Instructions

### What does this do?

Claude Desktop doesn't render Hebrew text correctly — it's left-aligned and mixed awkwardly with English.  
These scripts fix that: Hebrew paragraphs, lists, and input fields will display right-to-left, while code blocks stay LTR.

> **Note:** The patch fixes both the **conversation view** and the **Co-Work shell** (sidebar, history, agents panel).

---

### Requirements

| Tool | Purpose |
|------|---------|
| **Node.js** | Used to unpack/repack Claude's internal bundle |
| **macOS** | Uses macOS-only tools (`codesign`, `PlistBuddy`) |
| **Claude Desktop** | Expected at `/Applications/Claude.app` |

**Check if Node.js is installed:** Open Terminal and run:
```
node --version
```
If you see a version number (e.g. `v20.11.0`) you're good.  
If not, download it from [nodejs.org](https://nodejs.org) and install.

---

### Easy method — let Claude do it

1. Open Claude Desktop
2. Start a new conversation
3. Upload `patch-claude-rtl.sh` into the chat (drag and drop it)
4. Type:

> "Run this script to fix Hebrew text direction in the app"

Claude will run the script, prompt for your password if needed, and complete the patch.

---

### Manual method — Terminal

1. **Open Terminal** (search "Terminal" in Spotlight with Cmd+Space)

2. **Navigate to the folder containing the scripts:**
   ```bash
   cd /path/to/claude-desktop-hebrew-patch-mac
   ```
   (You can also drag the folder into the Terminal window after typing `cd ` then press Enter)

3. **Run the patch:**
   ```bash
   ./patch-claude-rtl.sh
   ```

4. **Enter your Mac password** when prompted (the script needs permission to modify app files)

5. **Wait** — the script closes Claude, applies the patch, and relaunches it. Takes ~30–60 seconds.

6. **Done!** Claude reopens with proper Hebrew RTL support.

---

### Restore — undo the patch

If anything doesn't work as expected, run:

```bash
./restore-claude-rtl.sh
```

This restores the original Claude files from the backup that was made before patching.

---

### FAQ

**Is this safe?**  
Yes. The script creates a backup before touching anything, and auto-restores if Claude fails to launch after patching.

**Does this break after Claude updates?**  
Yes — updates overwrite the internal files. Re-run the patch script after each Claude update.

**Will Co-Work break?**  
No — this version of the patch was specifically fixed to avoid touching the co-work shell bundle. If you experience any issues, run `./restore-claude-rtl.sh` and open an [Issue](../../issues).

---

## How it works (technical)

Claude Desktop is an Electron app. The patch modifies two locations inside `app.asar` (Claude's internal bundle):

| Target | What it is | Why |
|--------|-----------|-----|
| `.vite/build/mainView.js` | Electron preload script for the claude.ai WebView | Fixes RTL in the conversation pane |
| `.vite/renderer/main_window/index.html` | Shell app HTML entry point | Fixes RTL in the Co-Work sidebar and local UI |

The large JS bundles (`main-*.js`, `MainWindowPage-*.js`) that power Co-Work are deliberately **not modified**.  
After patching, `Info.plist` is updated with the new ASAR hash, and the app is re-signed with an ad-hoc local signature.

Backups are saved to `~/ClaudeRTLBackups/<timestamp>/` before every patch run.

---

## License

MIT
