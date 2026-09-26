#!/bin/bash
#
# End-to-end tests for the native messaging host.
#
# Builds host.c (or uses HOST_BIN=/path/to/host), points it at a stand-in app
# (probe.swift) through a throwaway HOME, sends it native messages exactly as
# Chrome frames them (4-byte little-endian length + JSON), and checks the URL
# the stand-in app actually receives through `open -a`.
#
# Usage: native-host/tests/run.sh
#
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
PROBE="$WORK/ChooserProbe.app"
RECEIVED="$WORK/received.txt"
MARKER="$WORK/injected"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
fail=0

cleanup() {
  pkill -f "$PROBE/Contents/MacOS/ChooserProbe" 2>/dev/null
  "$LSREGISTER" -u "$PROBE" >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

# --- build the host under test
if [ -n "${HOST_BIN:-}" ]; then
  HOST="$HOST_BIN"
  echo "==> Testing prebuilt host: $HOST"
else
  HOST="$WORK/host"
  cc -O2 -Wall -o "$HOST" "$DIR/../host.c" || { echo "FAIL: host.c does not compile"; exit 1; }
fi

# --- build the stand-in app. The explicit target matters on macOS 27: without
# it the binary is stamped for macOS 28 and Launch Services refuses to open it.
mkdir -p "$PROBE/Contents/MacOS"
swiftc -O -target "$(uname -m)-apple-macosx14.0" -o "$PROBE/Contents/MacOS/ChooserProbe" \
  "$DIR/probe.swift" -framework AppKit || { echo "FAIL: probe does not compile"; exit 1; }
cat > "$PROBE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>ChooserProbe</string>
  <key>CFBundleIdentifier</key><string>com.whatsapp.chooser.test-probe</string>
  <key>CFBundleName</key><string>ChooserProbe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSBackgroundOnly</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$PROBE" >/dev/null 2>&1

# --- throwaway HOME: the host reads ~/.config/whatsapp-chooser/config.json first.
# Both buttons go to the stand-in app.
# whatsapp_app comes first in plain form on purpose: if parsing ever broke, the
# host would fall back to the real "WhatsApp" app. The rest is written the way a
# person might edit it: a long comment that pushes the next key past the first
# 4 KB, tabs around the colon.
export HOME="$WORK/home"
mkdir -p "$HOME/.config/whatsapp-chooser"
{
  printf '{\n  "whatsapp_app": "%s",\n' "$PROBE"
  printf '  "_comment": "%s",\n' "$(printf 'x%.0s' $(seq 1 5000))"
  printf '  "business_app"\t:\n    "%s"\n}\n' "$PROBE"
} > "$HOME/.config/whatsapp-chooser/config.json"

# One JSON \u escape, built at run time so no editor or tool can turn it into
# the character itself.
u() { printf '\\u%s' "$1"; }

# Send one framed message, print the host's JSON response. The response's own
# 4-byte length prefix must match its body, or the output says so.
send() {
  local raw="$WORK/response.bin"
  perl -e 'print pack("V", length($ARGV[0])), $ARGV[0]' "$1" | "$HOST" > "$raw"
  perl -e 'local $/; open(my $f, "<", $ARGV[0]) or die; binmode $f; my $d = <$f>;
    my $n = unpack("V", substr($d, 0, 4)); my $body = substr($d, 4);
    print length($body) == $n ? $body : "BAD LENGTH PREFIX $n for " . length($body) . " bytes"' "$raw"
}

# Send a message and wait for the stand-in app to write the URL it received.
received_for() {
  rm -f "$RECEIVED"
  local response
  response="$(send "$1")"
  if [ "$response" != '{"success":true}' ]; then
    echo "HOST ERROR: $response"
    return
  fi
  for _ in $(seq 1 150); do
    [ -s "$RECEIVED" ] && break
    sleep 0.1
  done
  cat "$RECEIVED" 2>/dev/null | head -1
}

check() { # name expected actual
  if [ "$2" == "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    echo "       expected: $(printf '%s' "$2" | cut -c1-200)"
    echo "       got:      $(printf '%s' "$3" | cut -c1-200)"
    fail=1
  fi
}

# Literal JSON goes in single quotes. Anything built from variables goes through
# a variable first: macOS bash 3.2 brace-expands "{...,...}" when it sits in a
# "$(...)" that is itself an argument.

check "WhatsApp button opens whatsapp://send with phone and text" \
  "whatsapp://send?phone=393331234567&text=Ciao%20Marco" \
  "$(received_for '{"app":"WhatsApp","phone":"393331234567","text":"Ciao Marco"}')"

check "Business button opens its own app (config key past 4 KB, tab and line break)" \
  "whatsapp://send?phone=393331234567&text=Ciao%20Marco" \
  "$(received_for '{"app":"WhatsApp Business","phone":"393331234567","text":"Ciao Marco"}')"

# Escapes as Chrome writes them: \" \n and \uXXXX for 1-, 2- and 3-byte UTF-8, a
# surrogate pair, a lone surrogate (replacement character), plus raw UTF-8.
esc_json='{"app":"WhatsApp Business","phone":"393331234567","text":"He said \"hi\" '"$(u 003C)"'3\nok è '"$(u 00e8)$(u 20ac)$(u d83d)$(u de00)$(u d800)"'x"}'
esc_received="$(received_for "$esc_json")"
check "JSON escapes are decoded, then everything is percent-encoded" \
  "whatsapp://send?phone=393331234567&text=He%20said%20%22hi%22%20%3C3%0Aok%20%C3%A8%20%C3%A8%E2%82%AC%F0%9F%98%80%EF%BF%BDx" \
  "$esc_received"

nul_json='{"app":"WhatsApp","phone":"1","text":"A'"$(u 0000)"'B"}'
nul_received="$(received_for "$nul_json")"
check "a NUL in the text is dropped, the rest of the text survives" \
  "whatsapp://send?phone=1&text=AB" "$nul_received"

check "the number goes out as digits only; + and & in the text stay text" \
  "whatsapp://send?phone=393331234567&text=1%2B1%3D2%20%26%20more%3F" \
  "$(received_for '{"app":"WhatsApp","phone":"+39 (333) 123-4567","text":"1+1=2 & more?"}')"

check "a 00 international prefix becomes plain digits" \
  "whatsapp://send?phone=393331234567" \
  "$(received_for '{"app":"WhatsApp","phone":"0039 333 1234567","text":""}')"

check "a wa.me/message short-link code is not a number: no phone at all" \
  "whatsapp://send?text=Hi" \
  "$(received_for '{"app":"WhatsApp","phone":"message/AB12CD34","text":"Hi"}')"

check "more than 15 digits is not a phone number" \
  "whatsapp://send?text=Hi" \
  "$(received_for '{"app":"WhatsApp","phone":"1234567890123456","text":"Hi"}')"

check "no phone and no text: just whatsapp://send" \
  "whatsapp://send" \
  "$(received_for '{"app":"WhatsApp Business","phone":"","text":""}')"

# Shell injection regression (fixed 2026-07-10): a quote in the text must never
# reach a shell.
injected="$(received_for "{\"app\":\"WhatsApp\",\"phone\":\"1\",\"text\":\"'; touch $MARKER; '\"}")"
check "a quote in the text runs nothing" "absent" "$([ -e "$MARKER" ] && echo present || echo absent)"
check "a quote in the text is passed as text" \
  "whatsapp://send?phone=1&text=%27%3B%20touch%20$(printf '%s' "$MARKER" | sed 's|/|%2F|g')%3B%20%27" \
  "$injected"

# Long values used to overflow fixed stack buffers (phone 1024 + text 512).
long_phone="$(printf '1%.0s' $(seq 1 3000))"
long_text="$(printf 'a%.0s' $(seq 1 6000))"
long_json="{\"app\":\"WhatsApp Business\",\"phone\":\"$long_phone\",\"text\":\"$long_text\"}"
long_received="$(received_for "$long_json")"
check "very long values: no crash, the text arrives whole, the bogus number is dropped" \
  "whatsapp://send?text=$long_text" \
  "$long_received"

check "unknown app is refused" \
  '{"success":false,"error":"Unknown app"}' \
  "$(send '{"app":"Telegram","phone":"1","text":""}')"

echo
[ "$fail" -eq 0 ] && echo "ALL HOST TESTS PASS" || echo "SOME HOST TESTS FAIL"
exit "$fail"
