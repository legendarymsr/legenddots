#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

mkdir -p "$WORK_DIR"

echo "==> Fetching ${MULL_FDROID_REPO}/index-v1.json"
curl -fL -o "$WORK_DIR/index-v1.json" "${MULL_FDROID_REPO}/index-v1.json"

APK_NAME=$(jq -r --arg pkg "$MULL_PACKAGE_ID" --arg abi "$MULL_ABI" '
  .packages[$pkg]
  | map(select((.nativecode // [$abi]) | index($abi)))
  | sort_by(.versionCode)
  | last
  | .apkName
' "$WORK_DIR/index-v1.json")

[ -n "$APK_NAME" ] && [ "$APK_NAME" != "null" ] \
  || { echo "Could not find $MULL_PACKAGE_ID ($MULL_ABI) in ${MULL_FDROID_REPO}/index-v1.json"; exit 1; }

echo "==> Downloading ${MULL_FDROID_REPO}/${APK_NAME}"
curl -fL -o "$WORK_DIR/mull.apk" "${MULL_FDROID_REPO}/${APK_NAME}"
echo "==> Saved to $WORK_DIR/mull.apk ($(du -h "$WORK_DIR/mull.apk" | cut -f1)), from $APK_NAME"
