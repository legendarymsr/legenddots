#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

SRC_DIR="src"
[ -d "$SRC_DIR" ] || { echo "Run scripts/fetch-source.sh first"; exit 1; }

echo "==> Setting applicationId to ${PACKAGE_ID}"
grep -rl --include='build.gradle*' -E '^\s*applicationId\b' "$SRC_DIR" | while read -r f; do
  sed -i -E "s/applicationId[[:space:]]*=?[[:space:]]*\"[^\"]+\"/applicationId \"${PACKAGE_ID}\"/" "$f"
  echo "    patched $f"
done

echo "==> Setting app_name to '${APP_NAME}'"
grep -rl --include='strings*.xml' '"app_name"' "$SRC_DIR" | while read -r f; do
  sed -i -E "s#(<string name=\"app_name\"[^>]*>).*(</string>)#\1${APP_NAME}\2#" "$f"
  echo "    patched $f"
done

if find branding/icons -type f \( -name '*.png' -o -name '*.webp' \) 2>/dev/null | grep -q .; then
  echo "==> Copying custom launcher icons"
  while IFS= read -r icon; do
    rel="${icon#branding/icons/}"
    find "$SRC_DIR" -path "*res/$(dirname "$rel")/$(basename "$rel")" -print0 \
      | xargs -0 -r -I{} cp -v "$icon" "{}"
  done < <(find branding/icons -type f \( -name '*.png' -o -name '*.webp' \))
else
  echo "==> No custom icons in branding/icons/, keeping upstream icons"
fi

if [ -f branding/strings/overrides.xml ]; then
  echo "==> NOTE: branding/strings/overrides.xml lists additional strings worth"
  echo "    reviewing manually — not merged automatically to avoid corrupting"
  echo "    upstream resource files. Grep src/**/res/values*/strings.xml for"
  echo "    remaining 'Mull'/'Fenix' mentions (about screen, update URLs, etc.)."
fi

echo "==> Branding applied. Review with: git -C src diff"
