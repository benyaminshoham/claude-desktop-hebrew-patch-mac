#!/bin/bash
set -euo pipefail

APP_PATH="${1:-/Applications/Claude.app}"
RESOURCES="$APP_PATH/Contents/Resources"
ASAR="$RESOURCES/app.asar"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/ClaudeRTLBackups/$STAMP"
WORKDIR="$(mktemp -d /tmp/claude-rtl-patch.XXXXXX)"
UNPACKED="$WORKDIR/app"
NEW_ASAR="$WORKDIR/app.asar"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

fail() {
  echo "ERROR: $1"
  exit 1
}

echo "Claude path: $APP_PATH"

[ -d "$APP_PATH" ] || fail "Claude.app not found"
[ -f "$ASAR" ] || fail "app.asar not found"

command -v node >/dev/null 2>&1 || fail "node is required"
command -v npm >/dev/null 2>&1 || fail "npm is required"
command -v npx >/dev/null 2>&1 || fail "npx is required"

echo "Quitting Claude..."
osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
pkill -x "Claude" 2>/dev/null || true
sleep 2

echo "Creating backup in:"
echo "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
sudo cp "$ASAR" "$BACKUP_DIR/app.asar"

find "$APP_PATH" -name "Info.plist" -print0 | while IFS= read -r -d '' PLIST; do
  REL="${PLIST#$APP_PATH/}"
  mkdir -p "$BACKUP_DIR/$(dirname "$REL")"
  sudo cp "$PLIST" "$BACKUP_DIR/$REL"
done

echo "$BACKUP_DIR" > "$HOME/ClaudeRTLBackups/latest"

echo "Installing local @electron/asar helper..."
cd "$WORKDIR"
npm init -y >/dev/null 2>&1
npm install @electron/asar >/dev/null 2>&1

echo "Extracting app.asar..."
npx asar extract "$ASAR" "$UNPACKED"

# ─── RTL patch JavaScript ────────────────────────────────────────────────────
RTL_JS_SNIPPET=$(cat <<'JS'
// CLAUDE_RTL_HEBREW_PATCH_START
(function () {
  if (typeof document === "undefined") return;
  if (window.__claudeRtlHebrewPatchInstalled) return;
  window.__claudeRtlHebrewPatchInstalled = true;

  function hasRTL(text) {
    return /[֐-׿؀-ۿݐ-ݿࢠ-ࣿ]/.test(text || "");
  }

  function firstStrongDirection(text) {
    text = text || "";
    for (var i = 0; i < text.length; i++) {
      var ch = text[i];
      if (/[֐-׿؀-ۿݐ-ݿࢠ-ࣿ]/.test(ch)) return "rtl";
      if (/[A-Za-z]/.test(ch)) return "ltr";
    }
    return null;
  }

  function setDir(el, dir) {
    if (!el || !dir) return;
    el.setAttribute("dir", dir);
    el.style.direction = dir;
    el.style.textAlign = dir === "rtl" ? "right" : "left";
    el.style.unicodeBidi = "plaintext";
  }

  function forceCodeLTR(root) {
    root.querySelectorAll("pre, code, .cm-editor, [class*='code'], [class*='Code']").forEach(function (el) {
      el.setAttribute("dir", "ltr");
      el.style.direction = "ltr";
      el.style.textAlign = "left";
      el.style.unicodeBidi = "embed";
    });
  }

  function processText(root) {
    root = root || document.body;
    if (!root || !root.querySelectorAll) return;

    root.querySelectorAll("p, li, blockquote, td, th, h1, h2, h3, h4, h5, h6").forEach(function (el) {
      if (el.closest("pre, code, .cm-editor, [class*='code'], [class*='Code']")) return;

      var text = el.innerText || el.textContent || "";
      if (!hasRTL(text)) return;

      setDir(el, "rtl");

      var list = el.closest("ul, ol");
      if (list) {
        list.setAttribute("dir", "rtl");
        list.style.direction = "rtl";
        list.style.textAlign = "right";
      }
    });

    root.querySelectorAll("textarea, [contenteditable='true'], [role='textbox']").forEach(function (el) {
      var text = el.value || el.innerText || el.textContent || "";
      var dir = firstStrongDirection(text);
      if (dir) setDir(el, dir);
    });

    forceCodeLTR(root);
  }

  function injectStyles() {
    if (document.getElementById("claude-rtl-hebrew-style")) return;

    var style = document.createElement("style");
    style.id = "claude-rtl-hebrew-style";
    style.textContent = [
      '[dir="rtl"] { direction: rtl !important; text-align: right !important; }',
      '[dir="ltr"], pre, code, .cm-editor, [class*="code"], [class*="Code"] { direction: ltr !important; text-align: left !important; }',
      'p, li, blockquote, td, th { unicode-bidi: plaintext !important; }',
      'pre, code { unicode-bidi: embed !important; }'
    ].join("\n");
    document.head.appendChild(style);
  }

  function run() {
    injectStyles();
    processText(document.body);
  }

  function init() {
    run();

    document.addEventListener("input", function (e) {
      var el = e.target;
      if (!el) return;
      if (!(el.matches && el.matches("textarea, [contenteditable='true'], [role='textbox']"))) return;

      var text = el.value || el.innerText || el.textContent || "";
      var dir = firstStrongDirection(text);
      if (dir) setDir(el, dir);
    }, true);

    var timer = null;
    var body = document.body;
    if (!body) return;

    var observer = new MutationObserver(function () {
      clearTimeout(timer);
      timer = setTimeout(run, 80);
    });

    observer.observe(body, {
      childList: true,
      subtree: true,
      characterData: true
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
// CLAUDE_RTL_HEBREW_PATCH_END
JS
)

# ─── Target 1: mainView.js (Electron preload for the claude.ai webview) ──────
#
# This script runs inside the WebView that loads claude.ai (the conversation
# pane). Patching it here fixes RTL in actual chat messages and input fields.
# We deliberately do NOT touch the renderer JS bundles (main-*.js,
# MainWindowPage-*.js) because those power the co-work shell and sidebar —
# modifying them breaks co-work.

PRELOAD="$UNPACKED/.vite/build/mainView.js"
PRELOAD_PATCHED=0

if [ -f "$PRELOAD" ]; then
  if grep -q "CLAUDE_RTL_HEBREW_PATCH_START" "$PRELOAD"; then
    echo "mainView.js: already patched, skipping"
    PRELOAD_PATCHED=1
  else
    TMP_JS="$WORKDIR/tmp-preload.js"
    printf '%s\n' "$RTL_JS_SNIPPET" > "$TMP_JS"
    cat "$PRELOAD" >> "$TMP_JS"
    mv "$TMP_JS" "$PRELOAD"
    echo "Patched preload: $PRELOAD"
    PRELOAD_PATCHED=1
  fi
else
  echo "WARNING: mainView.js not found — skipping preload patch"
fi

# ─── Target 2: index.html (shell app — co-work sidebar & local UI) ────────────
#
# The shell UI (co-work panel, history, sidebar) is served from app://localhost
# and renders from index.html + main-*.js. Instead of patching the large JS
# bundle (which would break co-work), we inject a tiny inline <script> into
# the HTML <head>. The script is deferred until DOMContentLoaded so it runs
# safely after the shell framework has initialized.

INDEX_HTML="$UNPACKED/.vite/renderer/main_window/index.html"
HTML_PATCHED=0

if [ -f "$INDEX_HTML" ]; then
  if grep -q "CLAUDE_RTL_HEBREW_PATCH_START" "$INDEX_HTML"; then
    echo "index.html: already patched, skipping"
    HTML_PATCHED=1
  else
    # Build the inline script block (no backtick template literals so it
    # embeds cleanly inside double-quoted HTML attributes if needed).
    INLINE_SCRIPT="<script id=\"claude-rtl-inject\">/* CLAUDE_RTL_HEBREW_PATCH_START */${RTL_JS_SNIPPET}/* CLAUDE_RTL_HEBREW_PATCH_END */</script>"

    # Insert the inline script just before </head>
    perl -0pi -e 's|</head>|'"$(printf '%s' "$INLINE_SCRIPT" | perl -pe 's|[/\\]|\\$&|g')"'\n</head>|' "$INDEX_HTML" 2>/dev/null || true

    # Verify injection worked
    if grep -q "CLAUDE_RTL_HEBREW_PATCH_START" "$INDEX_HTML"; then
      echo "Patched shell HTML: $INDEX_HTML"
      HTML_PATCHED=1
    else
      echo "WARNING: HTML injection failed — falling back to safe append"
      # Safe fallback: append before </body> instead
      sed -i '' "s|</body>|<script id=\"claude-rtl-inject-fb\">/* CLAUDE_RTL_HEBREW_PATCH_START */${RTL_JS_SNIPPET}/* CLAUDE_RTL_HEBREW_PATCH_END */</script></body>|" "$INDEX_HTML" || true
      grep -q "CLAUDE_RTL_HEBREW_PATCH_START" "$INDEX_HTML" && HTML_PATCHED=1
    fi
  fi
else
  echo "WARNING: index.html not found — skipping shell HTML patch"
fi

[ "$PRELOAD_PATCHED" -gt 0 ] || [ "$HTML_PATCHED" -gt 0 ] || fail "Nothing was patched"

echo "Packing new app.asar..."
npx asar pack "$UNPACKED" "$NEW_ASAR" --unpack "{*.node,spawn-helper}"

echo "Computing old and new ASAR header hashes..."

OLD_HASH="$(node - "$ASAR" <<'NODE'
const crypto = require("crypto");
const asar = require("@electron/asar");
const file = process.argv[2];
const raw = asar.getRawHeader(file);
const header = raw.headerString || raw.header;
process.stdout.write(crypto.createHash("sha256").update(header).digest("hex"));
NODE
)"

NEW_HASH="$(node - "$NEW_ASAR" <<'NODE'
const crypto = require("crypto");
const asar = require("@electron/asar");
const file = process.argv[2];
const raw = asar.getRawHeader(file);
const header = raw.headerString || raw.header;
process.stdout.write(crypto.createHash("sha256").update(header).digest("hex"));
NODE
)"

echo "Old hash: $OLD_HASH"
echo "New hash: $NEW_HASH"

echo "Replacing app.asar..."
sudo cp "$NEW_ASAR" "$ASAR"

echo "Updating ElectronAsarIntegrity in Info.plist files..."

find "$APP_PATH" -name "Info.plist" -print0 | while IFS= read -r -d '' PLIST; do
  if sudo /usr/libexec/PlistBuddy -c "Print :ElectronAsarIntegrity:Resources/app.asar:hash" "$PLIST" >/dev/null 2>&1; then
    sudo /usr/libexec/PlistBuddy -c "Set :ElectronAsarIntegrity:Resources/app.asar:hash $NEW_HASH" "$PLIST"
    echo "Updated: $PLIST"
  elif sudo grep -q "$OLD_HASH" "$PLIST" 2>/dev/null; then
    sudo perl -0pi -e "s/$OLD_HASH/$NEW_HASH/g" "$PLIST"
    echo "Updated by replace: $PLIST"
  fi
done

echo "Re-signing Claude.app deeply..."
sudo codesign --force --deep --sign - "$APP_PATH"

echo "Validating signature..."
codesign -v "$APP_PATH" 2>/dev/null || true

echo "Launching Claude..."
open -a Claude
sleep 8

if pgrep -x "Claude" >/dev/null; then
  echo "Claude launched successfully."
  echo "Patch complete."
  echo "Backup saved at:"
  echo "$BACKUP_DIR"
else
  echo "Claude did not stay open."
  echo "Restoring backup..."
  sudo cp "$BACKUP_DIR/app.asar" "$ASAR"

  find "$BACKUP_DIR" -name "Info.plist" -print0 | while IFS= read -r -d '' BACKUP_PLIST; do
    REL="${BACKUP_PLIST#$BACKUP_DIR/}"
    DEST="$APP_PATH/$REL"
    [ -f "$DEST" ] && sudo cp "$BACKUP_PLIST" "$DEST"
  done

  sudo codesign --force --deep --sign - "$APP_PATH"
  echo "Restored backup."
  exit 1
fi
