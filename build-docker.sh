#!/usr/bin/env bash
# Build the firmware on machines the ESP-IDF toolchain doesn't support natively
# (e.g. Mac ARM) by running PlatformIO inside a linux/amd64 container.
# Docker Desktop on Apple Silicon executes it via Rosetta.
#
# Usage: ./build-docker.sh [pio args...]   (default: run)
#   ./build-docker.sh                # plain build
#   ./build-docker.sh check          # cppcheck static analysis
#
# Toolchains and packages are cached in the named volume
# `microslate-pio-cache`, so only the first build is slow.
set -euo pipefail
cd "$(dirname "$0")"

docker run --rm --platform linux/amd64 \
  -v "$PWD":/project \
  -v microslate-pio-cache:/root/.platformio \
  -w /project \
  python:3.11-slim \
  bash -c "apt-get update -qq >/dev/null && apt-get install -y -qq git >/dev/null && pip install -q platformio && pio ${*:-run}"
