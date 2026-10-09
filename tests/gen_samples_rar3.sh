#!/usr/bin/env bash
# Generate encrypted RAR 3.x sample archives (RAR 3.00, 3.41, 3.50).
#
# RARLAB no longer hosts these versions; the packages come from the
# github.com/dryes/rarlinux mirror of the unmodified Linux trial packages,
# pinned by SHA-256 below (their documentation files match RARLAB's own
# packages byte for byte). They are downloaded into tests/rar3 (git-ignored),
# run with networking cut off, only to make samples; never decompiled.
#
# Usage: tests/gen_samples_rar3.sh       (needs unshare from util-linux)
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
r3="$root/rar3"
in="$root/samples/input"
out="$root/samples/rar3"
mirror="https://raw.githubusercontent.com/dryes/rarlinux/master"
long="ramjet-a-much-longer-password-for-the-bug"

[ -d "$in" ] || { echo "run tests/gen_samples.sh first" >&2; exit 1; }
mkdir -p "$r3"
cd "$r3"
while read -r sum file; do
    [ -f "$file" ] || curl -sSfL -m 120 -o "$file" "$mirror/$file"
    echo "$sum  $file" | sha256sum -c --quiet - || { echo "checksum mismatch: $file" >&2; exit 1; }
done <<'EOF'
9b819e09505f06fe806590a112056b32917b80165037d0a96be9d09a8c589ce9 rarlinux-3.0.tar.gz
eb1bbd707bb7186df7971ee0006e16cd1a2a2238da6084038fc7c68597bbbb22 rarlinux-3.4.1.tar.gz
d612ba810ed9ae1a0f40fe07a4219467ba5ece59adcc9b8b6dcf567e188ee585 rarlinux-3.5.0.tar.gz
EOF

rm -rf "$out"
mkdir -p "$out"
cp "$in/text.txt" "$in/hello.txt" "$r3/"
for v in 3.0 3.4.1 3.5.0; do
    mkdir -p "$r3/$v"
    [ -d "$r3/$v/rar" ] || tar xzf "$r3/rarlinux-$v.tar.gz" -C "$r3/$v"
    bin="$r3/$v/rar/rar_static"
    [ -f "$bin" ] || bin="$r3/$v/rar/rar"
    tag="$(echo "$v" | tr -d .)"
    run() { unshare -r -n "$bin" a -idq -m3 "$@" text.txt hello.txt >/dev/null; }
    run -pramjet "$out/p_short_$tag.rar"
    run -p"$long" "$out/p_long_$tag.rar"
    run -hpramjet "$out/hp_short_$tag.rar"
    run -hp"$long" "$out/hp_long_$tag.rar"
done
printf 'short password: ramjet\nlong password: %s\n' "$long" > "$out/PASSWORD.txt"
ls -1 "$out"/*.rar | wc -l | xargs echo "archives written:"
