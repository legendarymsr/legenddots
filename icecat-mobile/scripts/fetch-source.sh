#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source config/branding.env

if [ -d src ]; then
  echo "==> src/ already exists — delete it to re-fetch a clean checkout"
  exit 0
fi

echo "==> Cloning ${MULL_REPO_URL} @ ${MULL_REF}"
git clone --recurse-submodules "$MULL_REPO_URL" src
git -C src checkout "$MULL_REF"
git -C src submodule update --init --recursive

echo "==> Source ready in src/"
