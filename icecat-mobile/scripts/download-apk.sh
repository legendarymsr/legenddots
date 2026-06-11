#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

mkdir -p "$WORK_DIR"

echo "==> Downloading ${MULL_APK_URL}"
curl -fL -o "$WORK_DIR/mull.apk" "$MULL_APK_URL"
echo "==> Saved to $WORK_DIR/mull.apk ($(du -h "$WORK_DIR/mull.apk" | cut -f1))"
