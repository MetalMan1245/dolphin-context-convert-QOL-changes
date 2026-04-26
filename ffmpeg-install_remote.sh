#!/bin/bash
set -e

TMPDIR="$(mktemp -d /tmp/ffmpegconvert.XXXXXX)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

echo "[Remote Installer] Creating temp workspace..."
cd "$TMPDIR"

echo "[Remote Installer] Downloading repo..."
curl -fsSL \
  -o repo.zip \
  https://github.com/MetalMan1245/dolphin-context-convert-QOL-changes/archive/refs/heads/main.zip

echo "[Remote Installer] Extracting..."
unzip -q repo.zip
cd dolphin-context-convert-QOL-changes-main

echo "[Remote Installer] Running installer..."
chmod +x install_uninstall.sh
./install_uninstall.sh

echo "[Remote Installer] Done."
