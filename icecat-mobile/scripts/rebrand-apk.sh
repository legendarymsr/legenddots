#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

[ -f "$WORK_DIR/mull.apk" ] || { echo "Run scripts/download-apk.sh first"; exit 1; }

echo "==> Decompiling $WORK_DIR/mull.apk"
rm -rf "$WORK_DIR/src"
apktool d -f -o "$WORK_DIR/src" "$WORK_DIR/mull.apk"

echo "==> Setting app_name to '${APP_NAME}'"
find "$WORK_DIR/src/res" -path '*/values*/strings.xml' -print0 \
  | xargs -0 -r sed -i -E "s#(<string name=\"app_name\"[^>]*>).*(</string>)#\1${APP_NAME}\2#"

if find branding/icons -type f \( -name '*.png' -o -name '*.webp' \) 2>/dev/null | grep -q .; then
  echo "==> Copying custom launcher icons"
  while IFS= read -r icon; do
    rel="${icon#branding/icons/}"
    find "$WORK_DIR/src/res" -path "*/$(dirname "$rel")/$(basename "$rel")" -exec cp -v "$icon" {} \;
  done < <(find branding/icons -type f \( -name '*.png' -o -name '*.webp' \))
else
  echo "==> No custom icons in branding/icons/, keeping upstream icons"
fi

echo "==> Rebuilding APK"
apktool b "$WORK_DIR/src" -o "$WORK_DIR/icecat-unsigned.apk"
echo "==> Unsigned APK at $WORK_DIR/icecat-unsigned.apk"
