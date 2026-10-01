#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

[ -f "$WORK_DIR/icecat-unsigned.apk" ] || { echo "Run scripts/rebrand-apk.sh first"; exit 1; }
mkdir -p "$DIST_DIR"

echo "==> Aligning APK"
zipalign -p -f 4 "$WORK_DIR/icecat-unsigned.apk" "$WORK_DIR/icecat-aligned.apk"

echo "==> Signing APK"
apksigner sign \
  --ks "$KEYSTORE" --ks-pass "pass:${KEYSTORE_PASS}" \
  --ks-key-alias "$KEYSTORE_ALIAS" \
  --out "$DIST_DIR/icecat.apk" \
  "$WORK_DIR/icecat-aligned.apk"

echo "==> Installable APK ready at $DIST_DIR/icecat.apk"
