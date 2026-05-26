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

RTL_JS_FILE="$WORKDIR/rtl-patch.js"

cat > "$RTL_JS_FILE" <<'JS'
// CLAUDE_RTL_HEBREW_PATCH_START
(function () {
  if (typeof document === "undefined") return;
  if (window.__claudeRtlHebrewPatchInstalled) return;
  window.__claudeRtlHebrewPatchInstalled = true;

  function hasRTL(text) {
    return /[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/.test(text || "");
  }

  function firstStrongDirection(text) {
    text = text || "";
    for (var i = 0; i < text.length; i++) {
      var ch = text[i];
      if (/[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/.test(ch)) return "rtl";
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
    style.textContent = `
      [dir="rtl"] {
        direction: rtl !important;
        text-align: right !important;
      }

      [dir="ltr"],
      pre,
      code,
      .cm-editor,
      [class*="code"],
      [class*="Code"] {
        direction: ltr !important;
        text-align: left !important;
      }

      p, li, blockquote, td, th {
        unicode-bidi: plaintext !important;
      }

      pre, code {
        unicode-bidi: embed !important;
      }
    `;
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
    var observer = new MutationObserver(function () {
      clearTimeout(timer);
      timer = setTimeout(run, 80);
    });

    observer.observe(document.body, {
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

echo "Finding JavaScript injection targets..."

TARGETS=()

if [ -f "$UNPACKED/.vite/build/mainView.js" ]; then
  TARGETS+=("$UNPACKED/.vite/build/mainView.js")
fi

while IFS= read -r JS_FILE; do
  TARGETS+=("$JS_FILE")
done < <(
  find "$UNPACKED/.vite/renderer/main_window" -type f -name "*.js" 2>/dev/null \
  | grep -E 'MainWindowPage|main|index' \
  | head -n 5
)

if [ "${#TARGETS[@]}" -eq 0 ]; then
  fail "No JavaScript targets found"
fi

echo "Targets:"
printf '%s\n' "${TARGETS[@]}"

PATCHED=0

for JS_FILE in "${TARGETS[@]}"; do
  if grep -q "CLAUDE_RTL_HEBREW_PATCH_START" "$JS_FILE"; then
    echo "Already patched: $JS_FILE"
    continue
  fi

  TMP_JS="$WORKDIR/tmp-js"
  cat "$RTL_JS_FILE" "$JS_FILE" > "$TMP_JS"
  mv "$TMP_JS" "$JS_FILE"
  echo "Patched: $JS_FILE"
  PATCHED=$((PATCHED + 1))
done

[ "$PATCHED" -gt 0 ] || fail "No files were patched"

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

UPDATED=0

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