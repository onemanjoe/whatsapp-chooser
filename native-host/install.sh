#!/bin/bash
#
# Installa il native messaging host per WhatsApp Chooser.
#
# Uso:
#   ./install.sh [EXTENSION_ID]
#
# Se non specifichi l'ID, usa quello ufficiale del Chrome Web Store.
#

set -e

# Official Chrome Web Store extension ID — same for all users who install from the store.
STORE_EXTENSION_ID="fcpdhjmkmoodeapmnfbiofoibpklaicn"
# Extra ID passed as an argument (e.g. an unpacked dev install with a different ID).
EXTRA_EXTENSION_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_SRC="$SCRIPT_DIR/host.c"
HOST_BIN="$SCRIPT_DIR/host"
CONFIG_FILE="$SCRIPT_DIR/config.json"
MANIFEST_NAME="com.whatsapp.chooser"
TARGET_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"

# Configure app names if config.json doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
  echo ""
  echo "  Configurazione app WhatsApp"
  echo "  --------------------------"
  echo ""
  echo "  Come si chiama l'app WhatsApp sul tuo Mac?"
  echo "  (es. WhatsApp, WhatsApp 2 — premi Invio per 'WhatsApp')"
  read -r -p "  > " WA_APP
  WA_APP="${WA_APP:-WhatsApp}"
  echo ""
  echo "  Come si chiama l'app WhatsApp Business sul tuo Mac?"
  echo "  (es. WhatsApp Business, ChatMate Pro for WhatsApp — premi Invio per 'WhatsApp Business')"
  read -r -p "  > " WA_BIZ
  WA_BIZ="${WA_BIZ:-WhatsApp Business}"
  echo ""

  cat > "$CONFIG_FILE" <<CONF
{
  "whatsapp_app": "$WA_APP",
  "business_app": "$WA_BIZ"
}
CONF
  echo "  Configurazione salvata in config.json"
else
  echo ""
  echo "  config.json trovato, uso configurazione esistente."
fi

# Compile the native host
echo "  Compilazione native host..."
if ! cc -o "$HOST_BIN" "$HOST_SRC" -O2 2>&1; then
  echo "  ERRORE: compilazione fallita. Assicurati di avere Xcode Command Line Tools."
  echo "  Installali con: xcode-select --install"
  exit 1
fi
chmod +x "$HOST_BIN"
xattr -cr "$HOST_BIN" 2>/dev/null || true

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Build allowed_origins entries — always include the store ID, plus any extra dev ID.
ALLOWED_ORIGINS="    \"chrome-extension://$STORE_EXTENSION_ID/\""
if [ -n "$EXTRA_EXTENSION_ID" ] && [ "$EXTRA_EXTENSION_ID" != "$STORE_EXTENSION_ID" ]; then
  ALLOWED_ORIGINS="$ALLOWED_ORIGINS,
    \"chrome-extension://$EXTRA_EXTENSION_ID/\""
fi

# Write the native messaging host manifest
cat > "$TARGET_DIR/$MANIFEST_NAME.json" <<EOF
{
  "name": "$MANIFEST_NAME",
  "description": "WhatsApp Chooser - opens WhatsApp or WhatsApp Business",
  "path": "$HOST_BIN",
  "type": "stdio",
  "allowed_origins": [
$ALLOWED_ORIGINS
  ]
}
EOF

echo ""
echo "  Installazione completata!"
echo ""
echo "  Manifest:    $TARGET_DIR/$MANIFEST_NAME.json"
echo "  Host:        $HOST_BIN"
echo "  Store ID:    $STORE_EXTENSION_ID"
if [ -n "$EXTRA_EXTENSION_ID" ] && [ "$EXTRA_EXTENSION_ID" != "$STORE_EXTENSION_ID" ]; then
  echo "  Extra ID:    $EXTRA_EXTENSION_ID"
fi
echo ""
echo "  Riavvia Chrome per attivare il native messaging."
echo ""
