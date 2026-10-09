#!/usr/bin/env bash
# Download the official RAR 4.20 for Linux into tests/rar4 (git-ignored).
#
# It is only run as a program, to create RAR 4.x sample archives, and its
# technote.txt describes the RAR 1.5-4.x container. Neither is committed:
# the RAR license does not allow distributing parts of the package.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
dest="$root/rar4"
mkdir -p "$dest"
curl -sSfL https://www.rarlab.com/rar/rarlinux-x64-4.2.0.tar.gz -o "$dest/rarlinux-x64-4.2.0.tar.gz"
tar xzf "$dest/rarlinux-x64-4.2.0.tar.gz" -C "$dest"
("$dest/rar/rar" 2>&1 || true) | sed -n 1p
