#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")"

./download-apk.sh
./download-extensions.sh
./rebrand-apk.sh
./sign-apk.sh
