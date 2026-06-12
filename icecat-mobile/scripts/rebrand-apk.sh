#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

[ -f "$WORK_DIR/upstream.apk" ] || { echo "Run scripts/download-apk.sh first"; exit 1; }

echo "==> Decompiling $WORK_DIR/upstream.apk"
rm -rf "$WORK_DIR/src"
apktool d -f -o "$WORK_DIR/src" "$WORK_DIR/upstream.apk"

echo "==> Setting app_name to '${APP_NAME}'"
find "$WORK_DIR/src/res" -path '*/values*/strings.xml' -print0 \
  | xargs -0 -r sed -i -E "s#(<string name=\"app_name\"[^>]*>).*(</string>)#\1${APP_NAME}\2#"

echo "==> Removing Fennec/Firefox branding from strings (-> '${APP_NAME}')"
EXCLUDE_NAMES=$(sed -n 's/.*<string name="\([^"]*\)".*/\1/p' branding/strings/overrides.xml | paste -sd'|' -)
find "$WORK_DIR/src/res" -path '*/values*/strings.xml' -print0 \
  | xargs -0 -r sed -i -E \
      -e "/<string name=\"(${EXCLUDE_NAMES})\"/!s/Fennec/${APP_NAME}/g" \
      -e "/<string name=\"(${EXCLUDE_NAMES})\"/!s/Firefox/${APP_NAME}/g"

echo "==> Setting default search engine to '${DEFAULT_SEARCH_ENGINE}'"
SEARCH_LIST="$WORK_DIR/src/assets/search/list.json"
jq --arg engine "$DEFAULT_SEARCH_ENGINE" '.default.searchDefault = $engine' "$SEARCH_LIST" > "$SEARCH_LIST.tmp"
mv "$SEARCH_LIST.tmp" "$SEARCH_LIST"

echo "==> Applying IceCat accent color (#${ICECAT_ACCENT_COLOR})"
find "$WORK_DIR/src/res" -path '*/values*/colors.xml' -print0 \
  | xargs -0 -r sed -i -E \
      -e "s|(<color name=\"photonInk20\">)[^<]*(</color>)|\1#ff${ICECAT_ACCENT_COLOR}\2|" \
      -e "s|(<color name=\"photonInk20A20\">)[^<]*(</color>)|\1#33${ICECAT_ACCENT_COLOR}\2|"

if find branding/icons -type f \( -name '*.png' -o -name '*.webp' \) 2>/dev/null | grep -q .; then
  echo "==> Copying custom launcher icons"
  while IFS= read -r icon; do
    rel="${icon#branding/icons/}"
    find "$WORK_DIR/src/res" -path "*/$(dirname "$rel")/$(basename "$rel")" -exec cp -v "$icon" {} \;
  done < <(find branding/icons -type f \( -name '*.png' -o -name '*.webp' \))
else
  echo "==> No custom icons in branding/icons/, keeping upstream icons"
fi

if [ "$ENABLE_HARDENING" = "true" ]; then
  echo "==> Applying hardening prefs from branding/hardening-prefs.js"
  OMNI="$(realpath "$WORK_DIR/src/assets/omni.ja")"
  PREFS_REL="defaults/pref/${UPSTREAM_ABI}/geckoview-prefs.js"
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  unzip -oq "$OMNI" "$PREFS_REL" -d "$TMP_DIR"
  cat branding/hardening-prefs.js >> "$TMP_DIR/$PREFS_REL"
  (cd "$TMP_DIR" && zip -q "$OMNI" "$PREFS_REL")
  rm -rf "$TMP_DIR"
  trap - EXIT
else
  echo "==> ENABLE_HARDENING=false, skipping hardening prefs"
fi

echo "==> Rebuilding APK"
apktool b "$WORK_DIR/src" -o "$WORK_DIR/icecat-unsigned.apk"
echo "==> Unsigned APK at $WORK_DIR/icecat-unsigned.apk"
