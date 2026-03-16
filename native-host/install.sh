#!/bin/bash
#
# Installa il native messaging host per WhatsApp Chooser.
#
# Uso:
#   ./install.sh EXTENSION_ID
#
# L'EXTENSION_ID lo trovi in chrome://extensions dopo aver caricato l'estensione.
#

set -e

if [ -z "$1" ]; then
  echo ""
  echo "  Uso: ./install.sh EXTENSION_ID"
  echo ""
  echo "  Per trovare l'EXTENSION_ID:"
  echo "  1. Apri chrome://extensions"
  echo "  2. Attiva 'Modalita sviluppatore' in alto a destra"
  echo "  3. Carica l'estensione con 'Carica estensione non pacchettizzata'"
  echo "  4. Copia l'ID mostrato sotto il nome dell'estensione"
  echo ""
  exit 1
fi

EXTENSION_ID="$1"
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

# Write the native messaging host manifest
cat > "$TARGET_DIR/$MANIFEST_NAME.json" <<EOF
{
  "name": "$MANIFEST_NAME",
  "description": "WhatsApp Chooser - opens WhatsApp or WhatsApp Business",
  "path": "$HOST_BIN",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF

echo ""
echo "  Installazione completata!"
echo ""
echo "  Manifest:  $TARGET_DIR/$MANIFEST_NAME.json"
echo "  Host:      $HOST_BIN"
echo "  Extension: $EXTENSION_ID"
echo ""
echo "  Riavvia Chrome per attivare il native messaging."
echo ""
