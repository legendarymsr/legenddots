#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

mkdir -p "$WORK_DIR"

echo "==> Fetching ${UPSTREAM_FDROID_REPO}/index-v1.json"
curl -fL -o "$WORK_DIR/index-v1.json" "${UPSTREAM_FDROID_REPO}/index-v1.json"

APK_NAME=$(jq -r --arg pkg "$UPSTREAM_PACKAGE_ID" --arg abi "$UPSTREAM_ABI" '
  .packages[$pkg]
  | map(select((.nativecode // [$abi]) | index($abi)))
  | sort_by(.versionCode)
  | last
  | .apkName
' "$WORK_DIR/index-v1.json")

[ -n "$APK_NAME" ] && [ "$APK_NAME" != "null" ] \
  || { echo "Could not find $UPSTREAM_PACKAGE_ID ($UPSTREAM_ABI) in ${UPSTREAM_FDROID_REPO}/index-v1.json"; exit 1; }

echo "==> Downloading ${UPSTREAM_FDROID_REPO}/${APK_NAME}"
curl -fL -o "$WORK_DIR/upstream.apk" "${UPSTREAM_FDROID_REPO}/${APK_NAME}"
echo "==> Saved to $WORK_DIR/upstream.apk ($(du -h "$WORK_DIR/upstream.apk" | cut -f1)), from $APK_NAME"
