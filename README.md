# Claude Desktop — Hebrew RTL Patch (macOS)

Bash scripts that fix mixed Hebrew/English text direction in the **Claude Desktop** app on macOS.  
The patch injects a small JavaScript shim into Claude's bundled `app.asar` so that paragraphs, list items, and input fields detect RTL content (Hebrew / Arabic) and render it correctly — without breaking code blocks or LTR content.

---

## What it does

- Detects RTL characters (Hebrew `֐–׿`, Arabic `؀–ۿ`, …) in rendered text nodes
- Sets `dir="rtl"` and `text-align: right` on affected elements
- Keeps `<pre>`, `<code>`, and editor widgets forcibly LTR
- Listens for input events and DOM mutations so newly streamed text is corrected in real-time
- Backs up the original `app.asar` and all `Info.plist` files before touching anything
- Auto-restores the backup if Claude fails to launch after patching

---

## Requirements

| Tool | Why |
|------|-----|
| **macOS** | `codesign`, `osascript`, `PlistBuddy` are macOS-only |
| **Node.js + npm** | Used to install `@electron/asar` and repack the bundle |
| **Claude Desktop** | Tested against `/Applications/Claude.app` |

---

## Usage

### Apply the patch

```bash
./patch-claude-rtl.sh                         # uses /Applications/Claude.app
./patch-claude-rtl.sh /path/to/Claude.app     # custom path
```

The script will:
1. Quit Claude
2. Back up `app.asar` + `Info.plist` files to `~/ClaudeRTLBackups/<timestamp>/`
3. Unpack → patch → repack the asar
4. Update `ElectronAsarIntegrity` hashes in every `Info.plist`
5. Re-sign the app with an ad-hoc signature (`codesign --force --deep --sign -`)
6. Launch Claude and verify it stayed open; restores backup automatically on failure

### Restore the original

```bash
./restore-claude-rtl.sh                       # restores the most recent backup
./restore-claude-rtl.sh /path/to/Claude.app   # custom path
```

---

## Notes

- **Re-run after every Claude update** — app updates overwrite `app.asar`.
- The ad-hoc re-sign (`--sign -`) satisfies Gatekeeper for locally-modified apps but the bundle will no longer match Anthropic's original signature.
- Backups accumulate in `~/ClaudeRTLBackups/`. Clean them up manually when no longer needed.

---

## License

MIT
