#!/usr/bin/env bash
# Build a combined dual-boot flash image: a blank otadata region (0xe000),
# MicroSlate in OTA slot 0 (0x10000) and CrossInk (or another companion
# firmware) in OTA slot 1 (0x650000), per the CrossPoint-standard partition
# table in partitions.csv.
#
# Usage: ./build-dualboot.sh [companion-firmware.bin]
#   default companion: ../crossink/.pio/build/tiny/firmware-tiny.bin
#
# The image starts with blank (0xFF) otadata, so flashing it also resets the
# boot selector — the device boots MicroSlate first regardless of which slot
# it was running before.
#
# Flash with the CLI:
#   esptool.py --chip esp32c3 --port /dev/cu.usbmodem* --baud 921600 \
#     write_flash 0xe000 dualboot.bin
# or in the browser (Chrome/Edge) with Adafruit WebSerial ESPTool
# (https://adafruit.github.io/Adafruit_WebSerial_ESPTool/):
#   offset 0xe000, file dualboot.bin, Program.
#
# The merged image is padded with 0xFF between the two apps (harmless — that
# range lies inside the app partitions) and MUST be flashed at 0xe000: it
# deliberately excludes the bootloader, partition table and NVS, so device
# settings survive the flash.
set -euo pipefail
cd "$(dirname "$0")"

MICROSLATE_BIN=".pio/build/xteink_x4/firmware.bin"
COMPANION_BIN="${1:-../crossink/.pio/build/tiny/firmware-tiny.bin}"
OUT="dualboot.bin"
OTADATA_BLANK=".pio/otadata-blank.bin"

[ -f "$MICROSLATE_BIN" ] || { echo "Missing $MICROSLATE_BIN — run ./build-docker.sh first"; exit 1; }
[ -f "$COMPANION_BIN" ] || { echo "Missing companion firmware: $COMPANION_BIN"; exit 1; }

# 8 KiB of 0xFF = erased otadata -> bootloader selects the first OTA slot
mkdir -p .pio
python3 -c "open('$OTADATA_BLANK','wb').write(b'\xff' * 0x2000)"

merge() {
  "$@" --chip esp32c3 merge_bin --target-offset 0xe000 -o "$OUT" \
    0xe000 "$OTADATA_BLANK" \
    0x10000 "$MICROSLATE_BIN" \
    0x650000 "$COMPANION_BIN"
}

if command -v esptool.py >/dev/null 2>&1; then
  merge esptool.py
elif python3 -c 'import esptool' >/dev/null 2>&1; then
  merge python3 -m esptool
else
  docker run --rm --platform linux/amd64 \
    -v "$PWD":/project -v "$(cd "$(dirname "$COMPANION_BIN")" && pwd)":/companion \
    -w /project python:3.11-slim \
    bash -c "pip install -q esptool && python3 -m esptool --chip esp32c3 merge_bin \
      --target-offset 0xe000 -o $OUT \
      0xe000 $OTADATA_BLANK \
      0x10000 $MICROSLATE_BIN \
      0x650000 /companion/$(basename "$COMPANION_BIN")"
fi

ls -la "$OUT"
echo "Flash at offset 0xe000 — CLI: esptool.py --chip esp32c3 --port /dev/cu.usbmodem* --baud 921600 write_flash 0xe000 $OUT"
echo "            — Browser: https://adafruit.github.io/Adafruit_WebSerial_ESPTool/ (offset 0xe000)"
