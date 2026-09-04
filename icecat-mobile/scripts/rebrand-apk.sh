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
# Register-agnostic: apktool 3.x reallocates registers vs 2.x, so match any vN.
AMO_FILE=$(grep -rlE 'const-string v[0-9]+, "Extensions-for-Android"' "$WORK_DIR"/src/smali*/ 2>/dev/null | head -1)
[ -n "$AMO_FILE" ] || { echo "ERROR: could not locate the Recommended add-ons AMO collection reference (Fenix internals may have changed)"; exit 1; }
sed -i -E \
    -e "s|(const-string v[0-9]+, \")Extensions-for-Android(\")|\1${AMO_COLLECTION_NAME}\2|" \
    -e "s|(const-string v[0-9]+, \")mozilla(\")|\1${AMO_COLLECTION_USER}\2|" \
    "$AMO_FILE"

echo "==> Exposing the 'Custom extension collection' setting (Settings -> Advanced)"
FEATUREFLAGS_FILE=$(grep -rlE 'sput-boolean v[0-9]+, Lorg/mozilla/fenix/FeatureFlags;->customExtensionCollectionFeature:Z' "$WORK_DIR"/src/smali*/ 2>/dev/null | head -1)
[ -n "$FEATUREFLAGS_FILE" ] || { echo "ERROR: could not locate customExtensionCollectionFeature (Fenix internals may have changed)"; exit 1; }
# capture the actual register (apktool 3.x may not use v1) so the override matches
FF_REG=$(grep -oP 'sput-boolean \Kv[0-9]+(?=, Lorg/mozilla/fenix/FeatureFlags;->customExtensionCollectionFeature:Z)' "$FEATUREFLAGS_FILE" | head -1)
[ -n "$FF_REG" ] || { echo "ERROR: could not read customExtensionCollectionFeature register"; exit 1; }
awk -v reg="$FF_REG" '
  index($0, "Lorg/mozilla/fenix/FeatureFlags;->customExtensionCollectionFeature:Z") && index($0, "sput-boolean") && !done {
    print "    const/4 " reg ", 0x1"
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

# Newer Fennec ships a dark-mode-only VECTOR wordmark (drawable-night/ic_logo_wordmark_*.xml)
# that the raster copy above can't replace, so in dark mode the upstream "Fennec F-Droid"
# wordmark survives. Drop the night variant(s) so night mode falls back to our rebranded
# density rasters. Safe: the resource still exists via the drawable-<density>/ webps.
if find branding/icons -type f -name 'ic_logo_wordmark*' 2>/dev/null | grep -q .; then
  NIGHT_WM=$(find "$WORK_DIR/src/res" -path '*-night*' -name 'ic_logo_wordmark*.xml' 2>/dev/null)
  if [ -n "$NIGHT_WM" ]; then
    echo "==> Removing dark-mode vector wordmark(s) so the rebrand applies in night mode:"
    echo "$NIGHT_WM" | sed 's/^/     /'
    echo "$NIGHT_WM" | xargs -r rm -f
  fi
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

  for ext in ublock0 privacy-badger darkreader librejs jshelter; do
    echo "==> Copying $ext into assets/extensions/"
    rm -rf "$WORK_DIR/src/assets/extensions/$ext"
    cp -r "$WORK_DIR/extensions/$ext" "$WORK_DIR/src/assets/extensions/$ext"
  done

  # Clone Fenix's OWN built-in install (browser-icons) for each bundled extension,
  # reusing that call's exact runtime + callback registers. No separate class and
  # no hand-built callbacks — R8 merges/renames those, which is what silently broke
  # the old approach across Fennec updates. Register-agnostic by construction.
  echo "==> Registering built-in extensions alongside Fenix's own (browser-icons)"
  LAMBDA_FILE=$(grep -rl 'assets/extensions/browser-icons/' "$WORK_DIR"/src/smali*/ 2>/dev/null | head -1)
  [ -n "$LAMBDA_FILE" ] || { echo "ERROR: could not locate Core's built-in-extension installer (Fenix internals may have changed)"; exit 1; }

  # the browser-icons install: invoke-interface {vRuntime, vId, vUrl, vSucc, vErr}, ...installBuiltInWebExtension(...)
  BICALL=$(awk '/assets\/extensions\/browser-icons\// {f=1} f && /installBuiltInWebExtension\(/ {print; exit}' "$LAMBDA_FILE")
  REGS=$(printf '%s' "$BICALL" | grep -oP '\{\K[^}]+')
  R=$(printf   '%s' "$REGS" | awk -F', *' '{print $1}')   # WebExtensionRuntime
  ID=$(printf  '%s' "$REGS" | awk -F', *' '{print $2}')   # id string (scratch)
  URL=$(printf '%s' "$REGS" | awk -F', *' '{print $3}')   # url string (scratch)
  SUCC=$(printf '%s' "$REGS" | awk -F', *' '{print $4}')  # onSuccess callback
  ERR=$(printf '%s' "$REGS" | awk -F', *' '{print $5}')   # onError callback
  { [ -n "$R" ] && [ -n "$ID" ] && [ -n "$URL" ] && [ -n "$SUCC" ] && [ -n "$ERR" ]; } \
    || { echo "ERROR: could not parse install registers from: $BICALL"; exit 1; }
  IFACE='Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;->installBuiltInWebExtension(Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function1;)V'

  BLOCK=$(mktemp)
  for pair in \
    "uBlock0@raymondhill.net:ublock0" \
    "jid1-MnnxcxisBPnSXQ@jetpack:privacy-badger" \
    "addon@darkreader.org:darkreader" \
    "jid1-KtlZuoiikVfFew@jetpack:librejs" \
    "jsr@javascriptrestrictor:jshelter"; do
    guid="${pair%%:*}"; dir="${pair##*:}"
    printf '    const-string %s, "%s"\n    const-string %s, "resource://android/assets/extensions/%s/"\n    invoke-interface {%s, %s, %s, %s, %s}, %s\n' \
      "$ID" "$guid" "$URL" "$dir" "$R" "$ID" "$URL" "$SUCC" "$ERR" "$IFACE" >> "$BLOCK"
  done

  awk -v block="$BLOCK" '
    { print }
    /assets\/extensions\/browser-icons\// { seen = 1 }
    seen && /installBuiltInWebExtension\(/ && !done {
      while ((getline line < block) > 0) print line
      close(block); done = 1
    }
  ' "$LAMBDA_FILE" > "$LAMBDA_FILE.tmp" && mv "$LAMBDA_FILE.tmp" "$LAMBDA_FILE"
  rm -f "$BLOCK"
  echo "==> injected 5 built-in extensions after browser-icons (runtime=$R onSuccess=$SUCC onError=$ERR)"
else
  echo "==> BUNDLE_EXTENSIONS=false, skipping built-in extension bundling"
fi

echo "==> Rebuilding APK"
apktool b "$WORK_DIR/src" -o "$WORK_DIR/icecat-unsigned.apk"
echo "==> Unsigned APK at $WORK_DIR/icecat-unsigned.apk"
