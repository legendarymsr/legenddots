#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

./download-apk.sh
./rebrand-apk.sh
./sign-apk.sh
