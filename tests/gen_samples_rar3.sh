#!/usr/bin/env bash
# Generate encrypted RAR 3.x sample archives (RAR 3.00, 3.41, 3.50) with
# executables supplied by the user. This script never downloads or installs
# RAR. The executables are run with networking cut off and never decompiled.
#
# Usage: tests/gen_samples_rar3.sh /path/to/rar-3.00 /path/to/rar-3.41 /path/to/rar-3.50
#        (needs unshare from util-linux)
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
in="$root/samples/input"
out="$root/samples/rar3"
long="ramjet-a-much-longer-password-for-the-bug"

[ -d "$in" ] || { echo "run tests/gen_samples.sh first" >&2; exit 1; }
[ "$#" -eq 3 ] || {
    echo "usage: $0 /path/to/rar-3.00 /path/to/rar-3.41 /path/to/rar-3.50" >&2
    exit 1
}

bins=()
for supplied in "$@"; do
    case "$supplied" in
        /*) bin="$supplied" ;;
        *)  bin="$PWD/$supplied" ;;
    esac
    [ -x "$bin" ] || { echo "RAR executable not found: $supplied" >&2; exit 1; }
    bins+=("$bin")
done

rm -rf "$out"
mkdir -p "$out"
cd "$in"
versions=(3.0 3.4.1 3.5.0)
for i in 0 1 2; do
    v="${versions[$i]}"
    bin="${bins[$i]}"
    tag="$(echo "$v" | tr -d .)"
    run() { unshare -r -n "$bin" a -idq -m3 "$@" text.txt hello.txt >/dev/null; }
    run -pramjet "$out/p_short_$tag.rar"
    run -p"$long" "$out/p_long_$tag.rar"
    run -hpramjet "$out/hp_short_$tag.rar"
    run -hp"$long" "$out/hp_long_$tag.rar"
done
printf 'short password: ramjet\nlong password: %s\n' "$long" > "$out/PASSWORD.txt"
ls -1 "$out"/*.rar | wc -l | xargs echo "archives written:"
