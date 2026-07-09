#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

if [ "$BUNDLE_EXTENSIONS" != "true" ]; then
  echo "==> BUNDLE_EXTENSIONS=false, skipping extension downloads"
  exit 0
fi

mkdir -p "$WORK_DIR/extensions"

# Downloads the latest Android-compatible XPI for an addons.mozilla.org
# listing and unpacks it to $WORK_DIR/extensions/<name>/, ready to be copied
# into assets/extensions/<name>/ by rebrand-apk.sh.
download_extension() {
  local name="$1" slug="$2"

  echo "==> Fetching AMO metadata for '${slug}'"
  local url
  url=$(curl -fsL "https://addons.mozilla.org/api/v5/addons/addon/${slug}/" | jq -r '.current_version.file.url')
  [ -n "$url" ] && [ "$url" != "null" ] \
    || { echo "Could not find a download URL for '${slug}' on AMO"; exit 1; }

  echo "==> Downloading ${name} (${slug}) from ${url}"
  local xpi="$WORK_DIR/extensions/${name}.xpi"
  curl -fL -o "$xpi" "$url"

  rm -rf "$WORK_DIR/extensions/${name}"
  mkdir -p "$WORK_DIR/extensions/${name}"
  unzip -oq "$xpi" -d "$WORK_DIR/extensions/${name}"
  rm -f "$xpi"
}

download_extension ublock0        ublock-origin
download_extension privacy-badger privacy-badger17
download_extension darkreader      darkreader
download_extension librejs         librejs

echo "==> Extensions downloaded to $WORK_DIR/extensions/"
