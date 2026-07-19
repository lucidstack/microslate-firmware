#!/usr/bin/env bash
# Build a combined dual-boot flash image: MicroSlate in OTA slot 0 (0x10000)
# and CrossInk (or another companion firmware) in OTA slot 1 (0x650000), per
# the CrossPoint-standard partition table in partitions.csv.
#
# Usage: ./build-dualboot.sh [companion-firmware.bin]
#   default companion: ../crossink/.pio/build/tiny/firmware-tiny.bin
#
# Flash the result with a single command (device in download mode):
#   esptool.py --chip esp32c3 --port /dev/cu.usbmodem* --baud 921600 \
#     write_flash 0x10000 dualboot.bin
# On a device that previously booted the second slot, also reset the boot
# selector so it starts in MicroSlate:
#   esptool.py --chip esp32c3 --port /dev/cu.usbmodem* erase_region 0xe000 0x2000
#
# The merged image is padded with 0xFF between the two apps (harmless — that
# range lies inside the app partitions) and MUST be flashed at 0x10000: it
# deliberately excludes the bootloader, partition table, NVS and otadata.
set -euo pipefail
cd "$(dirname "$0")"

MICROSLATE_BIN=".pio/build/xteink_x4/firmware.bin"
COMPANION_BIN="${1:-../crossink/.pio/build/tiny/firmware-tiny.bin}"
OUT="dualboot.bin"

[ -f "$MICROSLATE_BIN" ] || { echo "Missing $MICROSLATE_BIN — run ./build-docker.sh first"; exit 1; }
[ -f "$COMPANION_BIN" ] || { echo "Missing companion firmware: $COMPANION_BIN"; exit 1; }

merge() {
  "$@" --chip esp32c3 merge_bin --target-offset 0x10000 -o "$OUT" \
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
      --target-offset 0x10000 -o $OUT \
      0x10000 $MICROSLATE_BIN \
      0x650000 /companion/$(basename "$COMPANION_BIN")"
fi

ls -la "$OUT"
echo "Flash with: esptool.py --chip esp32c3 --port /dev/cu.usbmodem* --baud 921600 write_flash 0x10000 $OUT"
