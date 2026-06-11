#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

./scripts/fetch-source.sh
./scripts/apply-branding.sh

echo "==> Building ${GRADLE_TASK}"
cd src
chmod +x ./gradlew
./gradlew "${GRADLE_TASK}" --no-daemon

cd ..
mkdir -p "$DIST_DIR"
find src -path '*/outputs/apk/*' -name '*.apk' -exec cp -v {} "$DIST_DIR/" \;
echo "==> APK(s) copied to ${DIST_DIR}/"
