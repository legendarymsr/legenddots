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

echo "==> Setting 'Recommended' add-ons collection to ${AMO_COLLECTION_USER}/${AMO_COLLECTION_NAME}"
AMO_FILE=$(grep -rl 'const-string v5, "Extensions-for-Android"' "$WORK_DIR"/src/smali*/ 2>/dev/null | head -1)
[ -n "$AMO_FILE" ] || { echo "ERROR: could not locate the Recommended add-ons AMO collection reference (Fenix internals may have changed)"; exit 1; }
sed -i -E \
    -e "s|(const-string v5, \")Extensions-for-Android(\")|\1${AMO_COLLECTION_NAME}\2|" \
    -e "s|(const-string v4, \")mozilla(\")|\1${AMO_COLLECTION_USER}\2|" \
    "$AMO_FILE"

echo "==> Exposing the 'Custom Add-on collection' setting (Settings -> Add-ons)"
FEATUREFLAGS_FILE=$(grep -rl 'sput-boolean v1, Lorg/mozilla/fenix/FeatureFlags;->customExtensionCollectionFeature:Z' "$WORK_DIR"/src/smali*/ 2>/dev/null | head -1)
[ -n "$FEATUREFLAGS_FILE" ] || { echo "ERROR: could not locate customExtensionCollectionFeature (Fenix internals may have changed)"; exit 1; }
awk '
  /sput-boolean v1, Lorg\/mozilla\/fenix\/FeatureFlags;->customExtensionCollectionFeature:Z/ && !done {
    print "    const/4 v1, 0x1"
    print ""
    done = 1
  }
  { print }
' "$FEATUREFLAGS_FILE" > "$FEATUREFLAGS_FILE.tmp"
mv "$FEATUREFLAGS_FILE.tmp" "$FEATUREFLAGS_FILE"

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

if [ "$BUNDLE_EXTENSIONS" = "true" ]; then
  echo "==> [EXPERIMENTAL] Bundling built-in extensions (BUNDLE_EXTENSIONS=true)"
  [ -d "$WORK_DIR/extensions" ] || { echo "Run scripts/download-extensions.sh first"; exit 1; }

  for ext in ublock0 privacy-badger darkreader librejs; do
    echo "==> Copying $ext into assets/extensions/"
    rm -rf "$WORK_DIR/src/assets/extensions/$ext"
    cp -r "$WORK_DIR/extensions/$ext" "$WORK_DIR/src/assets/extensions/$ext"
  done

  echo "==> Adding IcecatExtensions smali class"
  mkdir -p "$WORK_DIR/src/smali_classes2/org/mozilla/fenix/icecat"
  cp branding/smali/IcecatExtensions.smali "$WORK_DIR/src/smali_classes2/org/mozilla/fenix/icecat/IcecatExtensions.smali"

  echo "==> Registering built-in extensions alongside Fenix's own (browser-icons)"
  LAMBDA_FILE=$(grep -rl 'resource://android/assets/extensions/browser-icons/' "$WORK_DIR"/src/smali*/ 2>/dev/null | head -1)
  [ -n "$LAMBDA_FILE" ] || { echo "ERROR: could not locate Core's built-in-extension installer (Fenix internals may have changed)"; exit 1; }

  MARKER='Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;->installBuiltInWebExtension'
  CALL_LINE=$(grep -m1 "$MARKER" "$LAMBDA_FILE")
  REG=$(echo "$CALL_LINE" | grep -oP '(?<=\{)v[0-9]+' | head -1)
  [ -n "$REG" ] || { echo "ERROR: could not find installBuiltInWebExtension call in $LAMBDA_FILE"; exit 1; }

  awk -v reg="$REG" -v marker="$MARKER" '
    { print }
    index($0, marker) && !done {
      print ""
      print "    invoke-static {" reg "}, Lorg/mozilla/fenix/icecat/IcecatExtensions;->installAll(Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;)V"
      done = 1
    }
  ' "$LAMBDA_FILE" > "$LAMBDA_FILE.tmp"
  mv "$LAMBDA_FILE.tmp" "$LAMBDA_FILE"
else
  echo "==> BUNDLE_EXTENSIONS=false, skipping built-in extension bundling"
fi

echo "==> Rebuilding APK"
apktool b "$WORK_DIR/src" -o "$WORK_DIR/icecat-unsigned.apk"
echo "==> Unsigned APK at $WORK_DIR/icecat-unsigned.apk"
